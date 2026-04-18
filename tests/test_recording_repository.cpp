#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/database.h"
#include "iptvxs/db/recording_repository.h"
#include "iptvxs/db/server_repository.h"

class TestRecordingRepository : public QObject {
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

        iptvxs::ChannelRepository channelRepo(db_->connection());
        iptvxs::Channel ch;
        ch.serverId = serverId_;
        ch.externalId = QStringLiteral("ch1");
        ch.name = QStringLiteral("Test Channel");
        ch.streamUrl = QStringLiteral("http://stream/1");
        ch.type = QStringLiteral("live");
        QVector<iptvxs::Channel> channels;
        channels.append(ch);
        channelRepo.batchUpsert(channels);

        auto allChannels = channelRepo.findByServer(serverId_);
        QCOMPARE(allChannels.size(), 1);
        channelId_ = allChannels[0].id;
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testCreateAndFindById() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("scheduled");
        rec.quality = QStringLiteral("original");
        rec.startTime = 1700000000;
        rec.endTime = 1700003600;

        auto id = repo.create(rec);
        QVERIFY(id > 0);

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->channelId, channelId_);
        QCOMPARE(found->status, QStringLiteral("scheduled"));
        QCOMPARE(found->quality, QStringLiteral("original"));
        QCOMPARE(found->startTime, static_cast<int64_t>(1700000000));
        QCOMPARE(found->endTime, static_cast<int64_t>(1700003600));
    }

    void testUpdateStatus() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("scheduled");
        rec.startTime = 1700010000;

        auto id = repo.create(rec);
        QVERIFY(id > 0);

        QVERIFY(repo.updateStatus(id, QStringLiteral("recording")));

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->status, QStringLiteral("recording"));
    }

    void testUpdateStatusWithError() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("recording");
        rec.startTime = 1700020000;

        auto id = repo.create(rec);
        QVERIFY(repo.updateStatus(id, QStringLiteral("failed"),
                                  QStringLiteral("Connection lost")));

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->status, QStringLiteral("failed"));
        QCOMPARE(found->errorMessage, QStringLiteral("Connection lost"));
    }

    void testFindByStatus() {
        iptvxs::RecordingRepository repo(db_->connection());

        auto scheduled = repo.findByStatus(QStringLiteral("scheduled"));
        int scheduledBefore = scheduled.size();

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("scheduled");
        rec.startTime = 1700030000;
        repo.create(rec);

        scheduled = repo.findByStatus(QStringLiteral("scheduled"));
        QCOMPARE(scheduled.size(), scheduledBefore + 1);
    }

    void testFindScheduledInTimeRange() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("scheduled");
        rec.startTime = 1800000000;
        rec.endTime = 1800003600;
        repo.create(rec);

        auto found = repo.findScheduled(1799999000, 1800001000);
        QVERIFY(!found.isEmpty());

        auto notFound = repo.findScheduled(1900000000, 1900001000);
        QVERIFY(notFound.isEmpty());
    }

    void testRemove() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("completed");
        rec.startTime = 1700040000;

        auto id = repo.create(rec);
        QVERIFY(id > 0);
        QVERIFY(repo.findById(id).has_value());

        QVERIFY(repo.remove(id));
        QVERIFY(!repo.findById(id).has_value());
    }

    void testUpdateFileSize() {
        iptvxs::RecordingRepository repo(db_->connection());

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("recording");
        rec.startTime = 1700050000;

        auto id = repo.create(rec);
        QVERIFY(repo.updateFileSize(id, 1024 * 1024 * 100));

        auto found = repo.findById(id);
        QVERIFY(found.has_value());
        QCOMPARE(found->fileSizeBytes, static_cast<int64_t>(1024 * 1024 * 100));
    }

    void testCount() {
        iptvxs::RecordingRepository repo(db_->connection());
        int totalBefore = repo.count();

        iptvxs::Recording rec;
        rec.channelId = channelId_;
        rec.status = QStringLiteral("completed");
        rec.startTime = 1700060000;
        repo.create(rec);

        QCOMPARE(repo.count(), totalBefore + 1);
        QVERIFY(repo.countByStatus(QStringLiteral("completed")) > 0);
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
    int64_t serverId_{0};
    int64_t channelId_{0};
};

QTEST_GUILESS_MAIN(TestRecordingRepository)

#include "test_recording_repository.moc"
