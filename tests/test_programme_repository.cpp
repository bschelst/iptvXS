#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/database.h"
#include "iptvxs/db/programme_repository.h"

class TestProgrammeRepository : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        tmpDir_ = std::make_unique<QTemporaryDir>();
        QVERIFY(tmpDir_->isValid());
        db_ = std::make_unique<iptvxs::Database>();
        QVERIFY(db_->open(tmpDir_->filePath("test.db")));
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testBatchUpsertAndFind() {
        iptvxs::ProgrammeRepository repo(db_->connection());
        QVector<iptvxs::Programme> progs;
        for (int i = 0; i < 5; ++i) {
            iptvxs::Programme p;
            p.epgChannelId = "ch1";
            p.title = QStringLiteral("Show %1").arg(i);
            p.description = QStringLiteral("Desc %1").arg(i);
            p.startTime = 1000 + i * 3600;
            p.endTime = 1000 + (i + 1) * 3600;
            progs.append(p);
        }
        repo.batchUpsert(progs);
        QCOMPARE(repo.count(), 5);

        auto found = repo.findByChannel("ch1", 1000, 1000 + 5 * 3600);
        QCOMPARE(found.size(), 5);
        QCOMPARE(found[0].title, "Show 0");
    }

    void testUpsertConflict() {
        iptvxs::ProgrammeRepository repo(db_->connection());
        QVector<iptvxs::Programme> progs;
        iptvxs::Programme p;
        p.epgChannelId = "ch1";
        p.title = "Updated Show 0";
        p.startTime = 1000;
        p.endTime = 4600;
        progs.append(p);
        repo.batchUpsert(progs);

        auto found = repo.findByChannel("ch1", 1000, 4600);
        QVERIFY(!found.isEmpty());
        QCOMPARE(found[0].title, "Updated Show 0");
    }

    void testDeleteOlderThan() {
        iptvxs::ProgrammeRepository repo(db_->connection());
        int before = repo.count();
        repo.deleteOlderThan(2000);
        int after = repo.count();
        QVERIFY(after <= before);
    }

    void testFindById() {
        iptvxs::ProgrammeRepository repo(db_->connection());
        auto all = repo.findByChannel("ch1", 0, 999999);
        QVERIFY(!all.isEmpty());
        auto found = repo.findById(all[0].id);
        QVERIFY(found.has_value());
        QCOMPARE(found->epgChannelId, "ch1");
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
};

QTEST_GUILESS_MAIN(TestProgrammeRepository)

#include "test_programme_repository.moc"
