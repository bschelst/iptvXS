#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/database.h"
#include "iptvxs/db/server_repository.h"

class TestCategoryRepository : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        tmpDir_ = std::make_unique<QTemporaryDir>();
        QVERIFY(tmpDir_->isValid());
        db_ = std::make_unique<iptvxs::Database>();
        QVERIFY(db_->open(tmpDir_->filePath("test.db")));

        iptvxs::ServerRepository serverRepo(db_->connection());
        iptvxs::Server server;
        server.name = QStringLiteral("Test Server");
        server.type = QStringLiteral("xtream");
        server.url = QStringLiteral("http://example.com");
        serverId_ = serverRepo.create(server);
        QVERIFY(serverId_ > 0);
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testUpsert() {
        iptvxs::CategoryRepository repo(db_->connection());
        iptvxs::Category cat;
        cat.serverId = serverId_;
        cat.externalId = QStringLiteral("ext1");
        cat.name = QStringLiteral("Sports");
        cat.type = QStringLiteral("live");

        auto id = repo.upsert(cat);
        QVERIFY(id > 0);

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->name, "Sports");
        QCOMPARE(found->type, "live");
    }

    void testUpsertDedup() {
        iptvxs::CategoryRepository repo(db_->connection());
        iptvxs::Category cat;
        cat.serverId = serverId_;
        cat.externalId = QStringLiteral("dedup1");
        cat.name = QStringLiteral("Original");
        cat.type = QStringLiteral("live");
        repo.upsert(cat);

        cat.name = QStringLiteral("Updated");
        repo.upsert(cat);

        auto categories = repo.findByServer(serverId_, QStringLiteral("live"));
        int count = 0;
        for (const auto &c : categories) {
            if (c.externalId == "dedup1") {
                ++count;
                QCOMPARE(c.name, "Updated");
            }
        }
        QCOMPARE(count, 1);
    }

    void testBatchUpsert() {
        iptvxs::CategoryRepository repo(db_->connection());
        QVector<iptvxs::Category> categories;
        for (int i = 0; i < 50; ++i) {
            iptvxs::Category cat;
            cat.serverId = serverId_;
            cat.externalId = QStringLiteral("batch%1").arg(i);
            cat.name = QStringLiteral("Category %1").arg(i);
            cat.type = QStringLiteral("vod");
            categories.append(cat);
        }

        repo.batchUpsert(categories);
        QVERIFY(repo.count(serverId_) >= 50);
    }

    void testFindByServerWithTypeFilter() {
        iptvxs::CategoryRepository repo(db_->connection());
        auto liveCategories = repo.findByServer(serverId_, QStringLiteral("live"));
        for (const auto &cat : liveCategories) {
            QCOMPARE(cat.type, "live");
        }

        auto vodCategories = repo.findByServer(serverId_, QStringLiteral("vod"));
        for (const auto &cat : vodCategories) {
            QCOMPARE(cat.type, "vod");
        }
    }

    void testFindByServerAll() {
        iptvxs::CategoryRepository repo(db_->connection());
        auto all = repo.findByServer(serverId_);
        QVERIFY(all.size() > 0);
    }

    void testDeleteByServer() {
        iptvxs::CategoryRepository repo(db_->connection());
        iptvxs::ServerRepository serverRepo(db_->connection());

        iptvxs::Server server;
        server.name = QStringLiteral("Delete Test");
        server.type = QStringLiteral("m3u");
        server.url = QStringLiteral("http://delete.com");
        auto sid = serverRepo.create(server);

        iptvxs::Category cat;
        cat.serverId = sid;
        cat.externalId = QStringLiteral("del1");
        cat.name = QStringLiteral("To Delete");
        cat.type = QStringLiteral("live");
        repo.upsert(cat);
        QVERIFY(repo.count(sid) > 0);

        repo.deleteByServer(sid);
        QCOMPARE(repo.count(sid), 0);
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
    int64_t serverId_{0};
};

QTEST_MAIN(TestCategoryRepository)
#include "test_category_repository.moc"
