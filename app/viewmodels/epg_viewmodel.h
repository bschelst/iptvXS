// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QFutureWatcher>
#include <QQmlEngine>
#include <QTimer>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/programme_repository.h"
#include "iptvxs/models/channel.h"
#include "iptvxs/models/programme.h"
#include "iptvxs/net/http_client.h"
#include "iptvxs/parser/xmltv_parser.h"

struct EpgChannelRow {
    iptvxs::Channel channel;
    QVector<iptvxs::Programme> programmes;
    bool isFavorite{false};
};

class EpgViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int64_t serverId READ serverId WRITE setServerId NOTIFY serverIdChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool syncing READ syncing NOTIFY syncingChanged)
    Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY syncStatusChanged)
    Q_PROPERTY(int64_t timeWindowStart READ timeWindowStart NOTIFY timeWindowChanged)
    Q_PROPERTY(int64_t timeWindowEnd READ timeWindowEnd NOTIFY timeWindowChanged)
    Q_PROPERTY(int64_t currentTime READ currentTime NOTIFY currentTimeChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)

public:
    enum Roles {
        ChannelIdRole = Qt::UserRole + 1,
        ChannelNameRole,
        ChannelLogoRole,
        StreamUrlRole,
        EpgChannelIdRole,
        ProgrammesRole,
        IsFavoriteRole,
        TvArchiveRole,
        TvArchiveDurationRole
    };

    explicit EpgViewModel(QObject *parent = nullptr);

    void setRepositories(iptvxs::ProgrammeRepository *progRepo,
                         iptvxs::ChannelRepository *channelRepo,
                         iptvxs::FavoriteRepository *favoriteRepo);
    void setHttpClient(iptvxs::HttpClient *http);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int64_t serverId() const;
    void setServerId(int64_t id);
    int count() const;
    bool syncing() const;
    QString syncStatus() const;
    int64_t timeWindowStart() const;
    int64_t timeWindowEnd() const;
    int64_t currentTime() const;

    QString searchQuery() const;
    void setSearchQuery(const QString &query);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void syncEpg(const QString &epgUrl);
    Q_INVOKABLE void shiftTime(int hours);
    Q_INVOKABLE QVariantList programmesForChannel(int row) const;
    Q_INVOKABLE QVariantMap rowData(int row) const;

signals:
    void serverIdChanged();
    void countChanged();
    void syncingChanged();
    void syncStatusChanged();
    void syncCompleted(bool ok, int programmeCount, const QString &message);
    void timeWindowChanged();
    void currentTimeChanged();
    void searchQueryChanged();

private:
    void handleDownloadedEpgData(const QByteArray &data);
    void startHttp10Download(const QString &epgUrl);
    static bool decodeChunkedBody(const QByteArray &chunked, QByteArray *decoded);
    void loadGrid();
    void startCurlFallbackDownload(const QString &epgUrl);
    void setSyncing(bool syncing);
    void setSyncStatus(const QString &status);

    iptvxs::ProgrammeRepository *progRepo_{nullptr};
    iptvxs::ChannelRepository *channelRepo_{nullptr};
    iptvxs::FavoriteRepository *favoriteRepo_{nullptr};
    iptvxs::HttpClient *http_{nullptr};
    iptvxs::XmltvParser parser_;

    QVector<EpgChannelRow> rows_;
    int64_t serverId_{0};
    int64_t timeWindowStart_{0};
    int64_t timeWindowEnd_{0};
    bool syncing_{false};
    QString syncStatus_;
    QString searchQuery_;
    QTimer clockTimer_;

    QFutureWatcher<QVector<iptvxs::Programme>> parseWatcher_;

    static constexpr int kTimeWindowHours = 4;
    static constexpr int kMaxEpgRows = 200;
};
