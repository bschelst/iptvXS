// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/database.h"

#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>
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
                     epg_url TEXT DEFAULT '',
                     epg_source_id INTEGER REFERENCES epg_sources(id) ON DELETE SET NULL,
                     enabled INTEGER NOT NULL DEFAULT 1,
                     is_primary INTEGER NOT NULL DEFAULT 0,
                     is_builtin_free INTEGER NOT NULL DEFAULT 0,
                     last_synced_at INTEGER,
                     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                 ))",
                 R"(CREATE TABLE IF NOT EXISTS epg_sources (
                     id INTEGER PRIMARY KEY,
                     name TEXT NOT NULL,
                     url TEXT NOT NULL UNIQUE,
                     enabled INTEGER NOT NULL DEFAULT 1,
                     is_primary INTEGER NOT NULL DEFAULT 0,
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

                 R"(CREATE TABLE IF NOT EXISTS category_settings (
                     category_id INTEGER PRIMARY KEY REFERENCES categories(id) ON DELETE CASCADE,
                     hidden INTEGER NOT NULL DEFAULT 0,
                     favorite INTEGER NOT NULL DEFAULT 0,
                     custom_name TEXT DEFAULT ''
                 ))",

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
                     first_seen_at INTEGER NOT NULL DEFAULT 0,
                     UNIQUE(server_id, external_id, type)
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_channels_server_cat ON channels(server_id, category_id)",
                 "CREATE INDEX IF NOT EXISTS idx_channels_name ON channels(name COLLATE NOCASE)",
                 "CREATE INDEX IF NOT EXISTS idx_channels_epg_id ON channels(epg_channel_id) WHERE epg_channel_id != ''",

                 R"(CREATE TABLE IF NOT EXISTS channel_groups (
                     id INTEGER PRIMARY KEY AUTOINCREMENT,
                     name TEXT NOT NULL,
                     position INTEGER NOT NULL DEFAULT 0,
                     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                 ))",

                 R"(CREATE TABLE IF NOT EXISTS group_members (
                     id INTEGER PRIMARY KEY AUTOINCREMENT,
                     group_id INTEGER NOT NULL REFERENCES channel_groups(id) ON DELETE CASCADE,
                     channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                     position INTEGER NOT NULL DEFAULT 0,
                     UNIQUE(group_id, channel_id)
                 ))",
                 "CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id)",

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
                     channel_id INTEGER DEFAULT 0,
                     name TEXT DEFAULT '',
                     logo_url TEXT DEFAULT '',
                     type TEXT DEFAULT 'live',
                     stream_url TEXT DEFAULT '',
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
                     gdrive_upload_url TEXT DEFAULT '',
                     error_message TEXT DEFAULT '',
                     pinned INTEGER NOT NULL DEFAULT 0,
                     thumbnail_url TEXT DEFAULT '',
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
        {12, "Add series_info_cache table", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             const QStringList statements = {
                 R"(CREATE TABLE IF NOT EXISTS series_info_cache (
                     server_id INTEGER NOT NULL,
                     series_id TEXT NOT NULL,
                     series_name TEXT NOT NULL,
                     logo_url TEXT DEFAULT '',
                     data TEXT NOT NULL,
                     updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
                     PRIMARY KEY (server_id, series_id)
                 ))",
             };

             for (const auto &sql : statements) {
                 if (!q.exec(sql)) {
                     return false;
                 }
             }
             return true;
         }},
        {13, "Add position tracking to history", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             return q.exec("ALTER TABLE history ADD COLUMN position_secs INTEGER DEFAULT 0")
                 && q.exec("ALTER TABLE history ADD COLUMN total_duration_secs INTEGER DEFAULT 0");
         }},
        {14, "Add dynamic group rules", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             const QStringList statements = {
                 "ALTER TABLE channel_groups ADD COLUMN kind TEXT NOT NULL DEFAULT 'static'",
                 "ALTER TABLE channel_groups ADD COLUMN filter_scope TEXT NOT NULL DEFAULT 'any'",
                 "ALTER TABLE channel_groups ADD COLUMN filter_field TEXT NOT NULL DEFAULT 'name'",
                 "ALTER TABLE channel_groups ADD COLUMN filter_operator TEXT NOT NULL DEFAULT 'contains'",
                 "ALTER TABLE channel_groups ADD COLUMN filter_value TEXT NOT NULL DEFAULT ''",
             };
             for (const auto &sql : statements) {
                 if (!q.exec(sql)) {
                     return false;
                 }
             }
             return true;
         }},
        {15, "Add built-in free server flag", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             q.exec("ALTER TABLE servers ADD COLUMN is_builtin_free INTEGER NOT NULL DEFAULT 0");
             if (!q.exec("UPDATE servers SET is_builtin_free = 1 "
                         "WHERE type = 'm3u' "
                         "AND name = 'iptvXS Free' "
                         "AND url = 'https://iptvxs.schelstraete.org/api/v1/playlist.m3u'")) {
                 return false;
             }
             return true;
         }},
        {16, "Split EPG sources from IPTV servers", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             if (!q.exec(R"(CREATE TABLE IF NOT EXISTS epg_sources (
                 id INTEGER PRIMARY KEY,
                 name TEXT NOT NULL,
                 url TEXT NOT NULL UNIQUE,
                 enabled INTEGER NOT NULL DEFAULT 1,
                 is_primary INTEGER NOT NULL DEFAULT 0,
                 last_synced_at INTEGER,
                 created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
             ))")) {
                 return false;
             }

             bool hasEpgSourceId = false;
             if (q.exec("PRAGMA table_info(servers)")) {
                 while (q.next()) {
                     if (q.value(1).toString() == QStringLiteral("epg_source_id")) {
                         hasEpgSourceId = true;
                         break;
                     }
                 }
             }
             if (!hasEpgSourceId) {
                 if (!q.exec("ALTER TABLE servers ADD COLUMN epg_source_id INTEGER REFERENCES epg_sources(id) ON DELETE SET NULL")) {
                     return false;
                 }
             }

             if (!q.exec("CREATE INDEX IF NOT EXISTS idx_epg_sources_primary ON epg_sources(is_primary, enabled)")) {
                 return false;
             }

             if (!q.exec("SELECT id, name, epg_url, is_primary FROM servers WHERE epg_url != ''")) {
                 return false;
             }

             QHash<QString, int64_t> sourceIds;
             while (q.next()) {
                 const auto serverName = q.value(1).toString();
                 const auto epgUrl = q.value(2).toString();
                 const auto isPrimary = q.value(3).toInt() != 0;
                 if (epgUrl.isEmpty()) {
                     continue;
                 }

                 if (!sourceIds.contains(epgUrl)) {
                     QSqlQuery insert(db);
                     insert.prepare("INSERT INTO epg_sources (name, url, enabled, is_primary) "
                                    "VALUES (?, ?, 1, ?)"
                                    " ON CONFLICT(url) DO UPDATE SET "
                                    "name = CASE WHEN epg_sources.name = '' THEN excluded.name ELSE epg_sources.name END");
                     insert.addBindValue(serverName + QStringLiteral(" EPG"));
                     insert.addBindValue(epgUrl);
                     insert.addBindValue(isPrimary ? 1 : 0);
                     if (!insert.exec()) {
                         return false;
                     }

                     QSqlQuery fetch(db);
                     fetch.prepare("SELECT id FROM epg_sources WHERE url = ?");
                     fetch.addBindValue(epgUrl);
                     if (!fetch.exec() || !fetch.next()) {
                         return false;
                     }
                     sourceIds.insert(epgUrl, fetch.value(0).toLongLong());
                 }
             }

             for (auto it = sourceIds.constBegin(); it != sourceIds.constEnd(); ++it) {
                 QSqlQuery upd(db);
                 upd.prepare("UPDATE servers SET epg_source_id = ? WHERE epg_url = ?");
                 upd.addBindValue(QVariant(static_cast<qlonglong>(it.value())));
                 upd.addBindValue(it.key());
                 if (!upd.exec()) {
                     return false;
                 }
             }

             return true;
         }},
        {17, "Add timeshift/catchup metadata to channels", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             bool hasArchive = false;
             bool hasArchiveDuration = false;
             if (q.exec("PRAGMA table_info(channels)")) {
                 while (q.next()) {
                     const auto col = q.value(1).toString();
                     if (col == QStringLiteral("tv_archive")) hasArchive = true;
                     if (col == QStringLiteral("tv_archive_duration")) hasArchiveDuration = true;
                 }
             }
             if (!hasArchive) {
                 if (!q.exec("ALTER TABLE channels ADD COLUMN tv_archive INTEGER NOT NULL DEFAULT 0")) {
                     return false;
                 }
             }
             if (!hasArchiveDuration) {
                 if (!q.exec("ALTER TABLE channels ADD COLUMN tv_archive_duration INTEGER NOT NULL DEFAULT 0")) {
                     return false;
                 }
             }
             return true;
         }},
        {18, "Sync metadata: updated_at + tombstones + sync_state", [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);

             // Helper: returns true if the column is already on the table.
             auto columnExists = [&](const QString &table, const QString &column) -> bool {
                 QSqlQuery probe(db);
                 if (!probe.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table))) {
                     return false;
                 }
                 while (probe.next()) {
                     if (probe.value(1).toString() == column) {
                         return true;
                     }
                 }
                 return false;
             };

             const QStringList syncTables = {
                 QStringLiteral("favorites"),
                 QStringLiteral("history"),
                 QStringLiteral("channel_groups"),
                 QStringLiteral("group_members"),
                 QStringLiteral("servers")
             };

             // SQLite restriction: ALTER TABLE ADD COLUMN may only use CONSTANT
             // default expressions. strftime('%s','now') is not constant, so we
             // ADD with DEFAULT 0 and then backfill every existing row in a
             // separate UPDATE. New inserts in the repos already write the real
             // timestamp inline.
             for (const auto &t : syncTables) {
                 if (!columnExists(t, QStringLiteral("updated_at"))) {
                     if (!q.exec(QStringLiteral(
                             "ALTER TABLE %1 ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0")
                             .arg(t))) {
                         return false;
                     }
                     if (!q.exec(QStringLiteral(
                             "UPDATE %1 SET updated_at = strftime('%s', 'now')")
                             .arg(t))) {
                         return false;
                     }
                 }
                 // deleted_at — nullable tombstone; rows with non-null values are
                 // hidden from the UI but kept around so the delete propagates.
                 if (!columnExists(t, QStringLiteral("deleted_at"))) {
                     if (!q.exec(QStringLiteral(
                             "ALTER TABLE %1 ADD COLUMN deleted_at INTEGER")
                             .arg(t))) {
                         return false;
                     }
                 }
             }

             // Per-device sync state (key/value).
             if (!q.exec("CREATE TABLE IF NOT EXISTS sync_state ("
                         "key TEXT PRIMARY KEY, "
                         "value TEXT NOT NULL)")) {
                 return false;
             }
             return true;
         }},
        {19, "Sync metadata: extend epg_sources with updated_at + tombstones",
         [](QSqlDatabase &db) -> bool {
             QSqlQuery q(db);
             auto columnExists = [&](const QString &table, const QString &column) -> bool {
                 QSqlQuery probe(db);
                 if (!probe.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table))) {
                     return false;
                 }
                 while (probe.next()) {
                     if (probe.value(1).toString() == column) return true;
                 }
                 return false;
             };
             if (!columnExists(QStringLiteral("epg_sources"), QStringLiteral("updated_at"))) {
                 if (!q.exec("ALTER TABLE epg_sources "
                             "ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0")) {
                     return false;
                 }
                 if (!q.exec("UPDATE epg_sources SET updated_at = strftime('%s', 'now')")) {
                     return false;
                 }
             }
             if (!columnExists(QStringLiteral("epg_sources"), QStringLiteral("deleted_at"))) {
                 if (!q.exec("ALTER TABLE epg_sources ADD COLUMN deleted_at INTEGER")) {
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
