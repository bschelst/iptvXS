#include "iptvxs/db/database.h"

#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace iptvxs {

Database::Database(QObject *parent)
    : QObject(parent),
      connectionName_(QUuid::createUuid().toString(QUuid::WithoutBraces)) {}

Database::~Database() { close(); }

bool Database::open(const QString &path) {
    QFileInfo info(path);
    QDir dir = info.absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    db_ = QSqlDatabase::addDatabase("QSQLITE", connectionName_);
    db_.setDatabaseName(path);

    if (!db_.open()) {
        emit errorOccurred(
            QStringLiteral("Failed to open database: %1").arg(db_.lastError().text()));
        return false;
    }

    if (!setPragmas()) {
        return false;
    }

    if (!applyMigrations()) {
        return false;
    }

    return true;
}

void Database::close() {
    if (db_.isOpen()) {
        db_.close();
    }
    if (QSqlDatabase::contains(connectionName_)) {
        QSqlDatabase::removeDatabase(connectionName_);
    }
}

bool Database::isOpen() const { return db_.isOpen(); }

QSqlDatabase Database::connection() const { return db_; }

bool Database::setPragmas() {
    QSqlQuery query(db_);
    const QStringList pragmas = {
        "PRAGMA journal_mode = WAL",
        "PRAGMA foreign_keys = ON",
        "PRAGMA cache_size = -64000",
        "PRAGMA busy_timeout = 5000",
        "PRAGMA synchronous = NORMAL",
        "PRAGMA temp_store = MEMORY",
    };

    for (const auto &pragma : pragmas) {
        if (!query.exec(pragma)) {
            emit errorOccurred(
                QStringLiteral("Failed to set pragma: %1").arg(query.lastError().text()));
            return false;
        }
    }
    return true;
}

int Database::currentSchemaVersion() const {
    QSqlQuery query(db_);
    if (!query.exec("SELECT MAX(version) FROM schema_version")) {
        return 0;
    }
    if (query.next()) {
        return query.value(0).toInt();
    }
    return 0;
}

std::vector<Database::Migration> Database::migrations() const {
    return {
        {1, "Initial schema", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             const QStringList statements = {
                 R"(CREATE TABLE IF NOT EXISTS schema_version (
                     version INTEGER PRIMARY KEY,
                     applied_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                 ))",

                 R"(CREATE TABLE IF NOT EXISTS servers (
                     id INTEGER PRIMARY KEY,
                     name TEXT NOT NULL,
                     type TEXT NOT NULL CHECK(type IN ('xtream', 'm3u')),
                     url TEXT NOT NULL,
                     username TEXT,
                     password TEXT,
                     user_agent TEXT DEFAULT '',
                     last_synced_at INTEGER,
                     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                 ))",

                 R"(CREATE TABLE IF NOT EXISTS categories (
                     id INTEGER PRIMARY KEY,
                     server_id INTEGER NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
                     external_id TEXT,
                     name TEXT NOT NULL,
                     type TEXT NOT NULL CHECK(type IN ('live', 'vod', 'series')),
                     UNIQUE(server_id, external_id, type)
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_categories_server ON categories(server_id, type)",

                 R"(CREATE TABLE IF NOT EXISTS channels (
                     id INTEGER PRIMARY KEY,
                     server_id INTEGER NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
                     category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
                     external_id TEXT,
                     name TEXT NOT NULL,
                     stream_url TEXT NOT NULL,
                     logo_url TEXT DEFAULT '',
                     epg_channel_id TEXT DEFAULT '',
                     type TEXT NOT NULL CHECK(type IN ('live', 'vod', 'series')),
                     added_at INTEGER,
                     UNIQUE(server_id, external_id, type)
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_channels_server_cat ON channels(server_id, category_id)",
                 "CREATE INDEX IF NOT EXISTS idx_channels_name ON channels(name COLLATE NOCASE)",
                 "CREATE INDEX IF NOT EXISTS idx_channels_epg_id ON channels(epg_channel_id) WHERE epg_channel_id != ''",

                 R"(CREATE TABLE IF NOT EXISTS programmes (
                     id INTEGER PRIMARY KEY,
                     epg_channel_id TEXT NOT NULL,
                     title TEXT NOT NULL,
                     description TEXT DEFAULT '',
                     start_time INTEGER NOT NULL,
                     end_time INTEGER NOT NULL,
                     UNIQUE(epg_channel_id, start_time)
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_programmes_channel_time ON programmes(epg_channel_id, start_time, end_time)",
                 "CREATE INDEX IF NOT EXISTS idx_programmes_time ON programmes(start_time)",

                 R"(CREATE TABLE IF NOT EXISTS favorites (
                     id INTEGER PRIMARY KEY,
                     channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                     position INTEGER NOT NULL DEFAULT 0,
                     added_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
                     UNIQUE(channel_id)
                 ))",

                 R"(CREATE TABLE IF NOT EXISTS history (
                     id INTEGER PRIMARY KEY,
                     channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                     watched_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
                     duration_secs INTEGER DEFAULT 0
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_history_channel ON history(channel_id)",
                 "CREATE INDEX IF NOT EXISTS idx_history_time ON history(watched_at DESC)",

                 R"(CREATE TABLE IF NOT EXISTS recordings (
                     id INTEGER PRIMARY KEY,
                     channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                     programme_id INTEGER REFERENCES programmes(id) ON DELETE SET NULL,
                     status TEXT NOT NULL CHECK(status IN ('scheduled', 'recording', 'completed', 'failed', 'uploading', 'uploaded')),
                     file_path TEXT DEFAULT '',
                     quality TEXT DEFAULT 'original',
                     start_time INTEGER NOT NULL,
                     end_time INTEGER,
                     file_size_bytes INTEGER DEFAULT 0,
                     gdrive_file_id TEXT DEFAULT '',
                     error_message TEXT DEFAULT '',
                     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status)",
                 "CREATE INDEX IF NOT EXISTS idx_recordings_start ON recordings(start_time)",

                 R"(CREATE TABLE IF NOT EXISTS settings (
                     key TEXT PRIMARY KEY,
                     value TEXT NOT NULL
                 ))",
             };

             for (const auto &sql : statements) {
                 if (!q.exec(sql)) {
                     return false;
                 }
             }
             return true;
         }},
    };
}

bool Database::applyMigrations() {
    QSqlQuery q(db_);
    q.exec(R"(CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    ))");

    const int current = currentSchemaVersion();
    const auto allMigrations = migrations();

    for (const auto &migration : allMigrations) {
        if (migration.version <= current) {
            continue;
        }

        if (!db_.transaction()) {
            emit errorOccurred(QStringLiteral("Failed to begin transaction for migration %1")
                                   .arg(migration.version));
            return false;
        }

        if (!migration.apply(db_)) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Migration %1 (%2) failed")
                                   .arg(migration.version)
                                   .arg(migration.description));
            return false;
        }

        QSqlQuery insertVersion(db_);
        insertVersion.prepare("INSERT INTO schema_version (version) VALUES (?)");
        insertVersion.addBindValue(migration.version);
        if (!insertVersion.exec()) {
            db_.rollback();
            return false;
        }

        if (!db_.commit()) {
            emit errorOccurred(QStringLiteral("Failed to commit migration %1")
                                   .arg(migration.version));
            return false;
        }

        emit migrationApplied(migration.version);
    }

    return true;
}

} // namespace iptvxs
