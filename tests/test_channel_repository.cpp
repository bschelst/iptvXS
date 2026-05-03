#include <QElapsedTimer>
#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/database.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/security/credential_vault.h"

class TestChannelRepository : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        tmpDir_ = std::make_unique<QTemporaryDir>();
        QVERIFY(tmpDir_->isValid());
        db_ = std::make_unique<iptvxs::Database>();
        QVERIFY(db_->open(tmpDir_->filePath("test.db")));
        vault_ = std::make_unique<iptvxs::CredentialVault>(QByteArray(32, '\x42'));

        iptvxs::ServerRepository serverRepo(db_->connection(), vault_.get());
        iptvxs::Server server;
        server.name = QStringLiteral("Test Server");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://example.com");
        server.username = QStringLiteral("user");
        server.password = QStringLiteral("pass");
        serverId_ = serverRepo.create(server);
        QVERIFY(serverId_ > 0);

        iptvxs::CategoryRepository catRepo(db_->connection());
        iptvxs::Category cat;
        cat.serverId = serverId_;
        cat.externalId = QStringLiteral("cat1");
        cat.name = QStringLiteral("Sports");
        cat.type = QStringLiteral("live");
        categoryId_ = catRepo.upsert(cat);
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testBatchUpsertAndFind() {
        iptvxs::ChannelRepository repo(db_->connection());
        QVector<iptvxs::Channel> channels;
        for (int i = 0; i < 100; ++i) {
            iptvxs::Channel ch;
            ch.serverId = serverId_;
            ch.categoryId = categoryId_;
            ch.externalId = QStringLiteral("ch%1").arg(i);
            ch.name = QStringLiteral("Channel %1").arg(i, 4, 10, QChar('0'));
            ch.streamUrl = QStringLiteral("http://stream/%1").arg(i);
            ch.logoUrl = QStringLiteral("http://logo/%1.png").arg(i);
            ch.epgChannelId = QStringLiteral("epg%1").arg(i);
            ch.type = QStringLiteral("live");
            channels.append(ch);
        }

        repo.batchUpsert(channels);
        QCOMPARE(repo.count(serverId_), 100);
    }

    void testBatchUpsertDedup() {
        iptvxs::ChannelRepository repo(db_->connection());
        QVector<iptvxs::Channel> channels;
        iptvxs::Channel ch;
        ch.serverId = serverId_;
        ch.externalId = QStringLiteral("ch0");
        ch.name = QStringLiteral("Updated Channel 0");
        ch.streamUrl = QStringLiteral("http://new-stream/0");
        ch.type = QStringLiteral("live");
        channels.append(ch);

        repo.batchUpsert(channels);

        auto found = repo.search(serverId_, QStringLiteral("Updated Channel 0"));
        QVERIFY(found.size() >= 1);
        QCOMPARE(found[0].streamUrl, "http://new-stream/0");
    }

    void testFindByServer() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto page1 = repo.findByServer(serverId_, 50, 0);
        QCOMPARE(page1.size(), 50);

        auto page2 = repo.findByServer(serverId_, 50, 50);
        QCOMPARE(page2.size(), 50);

        QVERIFY(page1[0].name != page2[0].name);
    }

    void testFindByCategory() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto channels = repo.findByCategory(categoryId_, 200, 0);
        QVERIFY(channels.size() > 0);
        for (const auto &ch : channels) {
            QCOMPARE(ch.categoryId, categoryId_);
        }
    }

    void testFindByServerAndType() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto live = repo.findByServerAndType(serverId_, QStringLiteral("live"), 200, 0);
        for (const auto &ch : live) {
            QCOMPARE(ch.type, "live");
        }
    }

    void testSearch() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto results = repo.search(serverId_, QStringLiteral("Channel 00"));
        QVERIFY(results.size() > 0);
        for (const auto &ch : results) {
            QVERIFY(ch.name.contains("Channel 00", Qt::CaseInsensitive));
        }
    }

    void testSearchCaseInsensitive() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto lower = repo.search(serverId_, QStringLiteral("channel 00"));
        auto upper = repo.search(serverId_, QStringLiteral("CHANNEL 00"));
        QCOMPARE(lower.size(), upper.size());
    }

    void testCountByCategory() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto count = repo.countByCategory(categoryId_);
        QVERIFY(count > 0);
    }

    void testCountBySearch() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto count = repo.countBySearch(serverId_, QStringLiteral("Channel"));
        QCOMPARE(count, repo.count(serverId_));
    }

    void testFindById() {
        iptvxs::ChannelRepository repo(db_->connection());
        auto first = repo.findByServer(serverId_, 1, 0);
        QCOMPARE(first.size(), 1);

        auto found = repo.findById(first[0].id);
        QVERIFY(found.has_value());
        QCOMPARE(found->name, first[0].name);
    }

    void testDeleteByServer() {
        iptvxs::ServerRepository serverRepo(db_->connection(), vault_.get());
        iptvxs::ChannelRepository repo(db_->connection());

        iptvxs::Server server;
        server.name = QStringLiteral("Delete Test");
        server.type = QStringLiteral("m3u");
        server.url = QStringLiteral("http://delete.com");
        server.username = QStringLiteral("user");
        server.password = QStringLiteral("pass");
        auto sid = serverRepo.create(server);
        QVERIFY(sid > 0);

        QVector<iptvxs::Channel> channels;
        for (int i = 0; i < 10; ++i) {
            iptvxs::Channel ch;
            ch.serverId = sid;
            ch.externalId = QStringLiteral("del%1").arg(i);
            ch.name = QStringLiteral("Del Channel %1").arg(i);
            ch.streamUrl = QStringLiteral("http://del/%1").arg(i);
            ch.type = QStringLiteral("live");
            channels.append(ch);
        }
        repo.batchUpsert(channels);
        QCOMPARE(repo.count(sid), 10);

        repo.deleteByServer(sid);
        QCOMPARE(repo.count(sid), 0);
    }

    void testBatchPerformance() {
        iptvxs::ServerRepository serverRepo(db_->connection(), vault_.get());
        iptvxs::ChannelRepository repo(db_->connection());

        iptvxs::Server server;
        server.name = QStringLiteral("Perf Test");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://perf.com");
        server.username = QStringLiteral("user");
        server.password = QStringLiteral("pass");
        auto sid = serverRepo.create(server);
        QVERIFY(sid > 0);

        QVector<iptvxs::Channel> channels;
        channels.reserve(10000);
        for (int i = 0; i < 10000; ++i) {
            iptvxs::Channel ch;
            ch.serverId = sid;
            ch.externalId = QStringLiteral("perf%1").arg(i);
            ch.name = QStringLiteral("Perf Channel %1").arg(i);
            ch.streamUrl = QStringLiteral("http://perf/%1").arg(i);
            ch.type = QStringLiteral("live");
            channels.append(ch);
        }

        QElapsedTimer timer;
        timer.start();
        repo.batchUpsert(channels);
        auto elapsed = timer.elapsed();

        QCOMPARE(repo.count(sid), 10000);
        QVERIFY2(elapsed < 5000,
                 qPrintable(QStringLiteral("Batch upsert of 10k channels took %1ms").arg(elapsed)));
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
    std::unique_ptr<iptvxs::CredentialVault> vault_;
    int64_t serverId_{0};
    int64_t categoryId_{0};
};

QTEST_MAIN(TestChannelRepository)
#include "test_channel_repository.moc"
