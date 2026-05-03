#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/database.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/security/credential_vault.h"

class TestServerRepository : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        tmpDir_ = std::make_unique<QTemporaryDir>();
        QVERIFY(tmpDir_->isValid());
        vault_ = std::make_unique<iptvxs::CredentialVault>(QByteArray(32, '\x42'));
        db_ = std::make_unique<iptvxs::Database>();
        QVERIFY(db_->open(tmpDir_->filePath("test.db")));
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testCreateAndFindById() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        iptvxs::Server server;
        server.name = QStringLiteral("Test Server");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://example.com");
        server.username = QStringLiteral("user");
        server.password = QStringLiteral("pass");
        server.userAgent = QStringLiteral("custom");

        auto id = repo.create(server);
        QVERIFY(id > 0);

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->name, "Test Server");
        QCOMPARE(found->type, "xtream");
        QCOMPARE(found->url, "http://example.com");
        QCOMPARE(found->username, "user");
        QCOMPARE(found->password, "pass");
        QCOMPARE(found->userAgent, "custom");
        QVERIFY(found->createdAt > 0);

        QSqlQuery raw(db_->connection());
        raw.prepare("SELECT username, password FROM servers WHERE id = ?");
        raw.addBindValue(QVariant(static_cast<qlonglong>(id)));
        QVERIFY(raw.exec());
        QVERIFY(raw.next());
        const auto storedUser = raw.value(0).toString();
        const auto storedPass = raw.value(1).toString();
        QVERIFY(storedUser.startsWith("enc:v1:"));
        QVERIFY(storedPass.startsWith("enc:v1:"));
        QVERIFY(storedUser != "user");
        QVERIFY(storedPass != "pass");
    }

    void testFindAll() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        auto servers = repo.findAll();
        QVERIFY(servers.size() >= 1);
    }

    void testUpdate() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        iptvxs::Server server;
        server.name = QStringLiteral("Update Me");
        server.type = QStringLiteral("m3u");
        server.url = QStringLiteral("http://old.com");
        auto id = repo.create(server);

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        found->name = QStringLiteral("Updated");
        found->url = QStringLiteral("http://new.com");
        QVERIFY(repo.update(*found));

        auto updated = repo.findById(id);
        QCOMPARE(updated->name, "Updated");
        QCOMPARE(updated->url, "http://new.com");
    }

    void testRemove() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        iptvxs::Server server;
        server.name = QStringLiteral("Delete Me");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://delete.com");
        auto id = repo.create(server);

        QVERIFY(repo.findById(id).has_value());
        QVERIFY(repo.remove(id));
        QVERIFY(!repo.findById(id).has_value());
    }

    void testFindByIdNotFound() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        QVERIFY(!repo.findById(999999).has_value());
    }

    void testUpdateLastSynced() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        iptvxs::Server server;
        server.name = QStringLiteral("Sync Test");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://sync.com");
        auto id = repo.create(server);

        int64_t timestamp = 1713400000;
        QVERIFY(repo.updateLastSynced(id, timestamp));

        auto found = repo.findById(id);
        QCOMPARE(found->lastSyncedAt, timestamp);
    }

    void testCount() {
        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        auto countBefore = repo.count();
        iptvxs::Server server;
        server.name = QStringLiteral("Count Test");
        server.type = QStringLiteral("m3u");
        server.url = QStringLiteral("http://count.com");
        repo.create(server);
        QCOMPARE(repo.count(), countBefore + 1);
    }

    void testMigratesLegacyPlaintextRows() {
        QSqlQuery insert(db_->connection());
        QVERIFY(insert.exec(
            "INSERT INTO servers (name, type, url, username, password, user_agent, epg_url, epg_source_id, is_builtin_free) "
            "VALUES ('Legacy', 'xtream', 'http://legacy.example', 'legacy_user', 'legacy_pass', '', '', NULL, 0)"));
        auto legacyId = insert.lastInsertId().toLongLong();

        iptvxs::ServerRepository repo(db_->connection(), vault_.get());
        auto found = repo.findById(legacyId);
        QVERIFY(found.has_value());
        QCOMPARE(found->username, "legacy_user");
        QCOMPARE(found->password, "legacy_pass");

        QSqlQuery raw(db_->connection());
        raw.prepare("SELECT username, password FROM servers WHERE id = ?");
        raw.addBindValue(QVariant(static_cast<qlonglong>(legacyId)));
        QVERIFY(raw.exec());
        QVERIFY(raw.next());
        QVERIFY(raw.value(0).toString().startsWith("enc:v1:"));
        QVERIFY(raw.value(1).toString().startsWith("enc:v1:"));
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
    std::unique_ptr<iptvxs::CredentialVault> vault_;
};

QTEST_MAIN(TestServerRepository)
#include "test_server_repository.moc"
