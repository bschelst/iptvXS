#include <QTemporaryDir>
#include <QtTest>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/database.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/security/credential_vault.h"

class TestFavoriteRepository : public QObject {
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

        iptvxs::ChannelRepository channelRepo(db_->connection());
        QVector<iptvxs::Channel> channels;
        for (int i = 0; i < 5; ++i) {
            iptvxs::Channel ch;
            ch.serverId = serverId_;
            ch.externalId = QStringLiteral("ch%1").arg(i);
            ch.name = QStringLiteral("Channel %1").arg(i);
            ch.streamUrl = QStringLiteral("http://stream/%1").arg(i);
            ch.type = QStringLiteral("live");
            channels.append(ch);
        }
        channelRepo.batchUpsert(channels);

        auto allChannels = channelRepo.findByServer(serverId_);
        QCOMPARE(allChannels.size(), 5);
        for (const auto &ch : allChannels) {
            channelIds_.append(ch.id);
        }
    }

    void cleanupTestCase() {
        db_.reset();
        tmpDir_.reset();
    }

    void testAddAndIsFavorite() {
        iptvxs::FavoriteRepository repo(db_->connection());
        QVERIFY(!repo.isFavorite(channelIds_[0]));

        QVERIFY(repo.add(channelIds_[0]));
        QVERIFY(repo.isFavorite(channelIds_[0]));
        QCOMPARE(repo.count(), 1);
    }

    void testAddDuplicate() {
        iptvxs::FavoriteRepository repo(db_->connection());
        QVERIFY(repo.add(channelIds_[0]));
        int countBefore = repo.count();
        QVERIFY(repo.add(channelIds_[0]));
        QCOMPARE(repo.count(), countBefore);
    }

    void testRemove() {
        iptvxs::FavoriteRepository repo(db_->connection());
        repo.add(channelIds_[1]);
        QVERIFY(repo.isFavorite(channelIds_[1]));

        QVERIFY(repo.remove(channelIds_[1]));
        QVERIFY(!repo.isFavorite(channelIds_[1]));
    }

    void testToggle() {
        iptvxs::FavoriteRepository repo(db_->connection());
        QVERIFY(!repo.isFavorite(channelIds_[2]));

        QVERIFY(repo.toggle(channelIds_[2]));
        QVERIFY(repo.isFavorite(channelIds_[2]));

        QVERIFY(repo.toggle(channelIds_[2]));
        QVERIFY(!repo.isFavorite(channelIds_[2]));
    }

    void testFindAllWithChannelData() {
        iptvxs::FavoriteRepository repo(db_->connection());
        repo.add(channelIds_[3]);
        repo.add(channelIds_[4]);

        auto favorites = repo.findAll();
        QVERIFY(favorites.size() >= 2);

        bool found = false;
        for (const auto &fav : favorites) {
            if (fav.channelId == channelIds_[3]) {
                QCOMPARE(fav.channel.name, QStringLiteral("Channel 3"));
                QCOMPARE(fav.channel.streamUrl, QStringLiteral("http://stream/3"));
                found = true;
                break;
            }
        }
        QVERIFY(found);
    }

    void testPositionOrdering() {
        iptvxs::FavoriteRepository repo(db_->connection());

        auto favorites = repo.findAll();
        for (int i = 1; i < favorites.size(); ++i) {
            QVERIFY(favorites[i].position >= favorites[i - 1].position);
        }
    }

    void testReorder() {
        iptvxs::FavoriteRepository repo(db_->connection());
        QVERIFY(repo.reorder(channelIds_[4], 99));

        auto favorites = repo.findAll();
        QVERIFY(!favorites.isEmpty());
        bool found = false;
        for (const auto &fav : favorites) {
            if (fav.channelId == channelIds_[4]) {
                QCOMPARE(fav.position, 99);
                found = true;
                break;
            }
        }
        QVERIFY(found);
    }

private:
    std::unique_ptr<QTemporaryDir> tmpDir_;
    std::unique_ptr<iptvxs::Database> db_;
    std::unique_ptr<iptvxs::CredentialVault> vault_;
    int64_t serverId_{0};
    QVector<int64_t> channelIds_;
};

QTEST_GUILESS_MAIN(TestFavoriteRepository)

#include "test_favorite_repository.moc"
