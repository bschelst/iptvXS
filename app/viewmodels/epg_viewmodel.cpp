#include "epg_viewmodel.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkReply>
#include <QtConcurrent>

EpgViewModel::EpgViewModel(QObject *parent)
    : QAbstractListModel(parent) {
    int64_t now = QDateTime::currentSecsSinceEpoch();
    int64_t hourStart = (now / 3600) * 3600;
    timeWindowStart_ = hourStart;
    timeWindowEnd_ = hourStart + kTimeWindowHours * 3600;

    clockTimer_.setInterval(60000);
    connect(&clockTimer_, &QTimer::timeout, this, [this]() {
        emit currentTimeChanged();
    });
    clockTimer_.start();

    connect(&parseWatcher_, &QFutureWatcher<QVector<iptvxs::Programme>>::finished,
            this, [this]() {
                auto programmes = parseWatcher_.result();
                if (programmes.isEmpty()) {
                    setSyncStatus("No EPG data found");
                    setSyncing(false);
                    return;
                }

                setSyncStatus(
                    QStringLiteral("Storing %1 programmes...").arg(programmes.size()));

                if (progRepo_) {
                    int64_t yesterday = QDateTime::currentSecsSinceEpoch() - 86400;
                    progRepo_->deleteOlderThan(yesterday);
                    progRepo_->batchUpsert(programmes);
                }

                qInfo("EPG sync complete: %lld programmes stored",
                      static_cast<long long>(programmes.size()));
                setSyncStatus(
                    QStringLiteral("EPG synced: %1 programmes").arg(programmes.size()));
                setSyncing(false);
                loadGrid();
            });
}

void EpgViewModel::setRepositories(iptvxs::ProgrammeRepository *progRepo,
                                   iptvxs::ChannelRepository *channelRepo) {
    progRepo_ = progRepo;
    channelRepo_ = channelRepo;
}

void EpgViewModel::setHttpClient(iptvxs::HttpClient *http) {
    http_ = http;
}

int EpgViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(rows_.size());
}

QVariant EpgViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= rows_.size()) {
        return {};
    }

    const auto &row = rows_.at(index.row());

    switch (role) {
    case ChannelIdRole:
        return QVariant::fromValue(static_cast<qlonglong>(row.channel.id));
    case ChannelNameRole:
        return row.channel.name;
    case ChannelLogoRole:
        return row.channel.logoUrl;
    case StreamUrlRole:
        return row.channel.streamUrl;
    case ProgrammesRole: {
        QVariantList progs;
        for (const auto &p : row.programmes) {
            QVariantMap m;
            m["id"] = QVariant::fromValue(static_cast<qlonglong>(p.id));
            m["title"] = p.title;
            m["description"] = p.description;
            m["startTime"] = static_cast<qlonglong>(p.startTime);
            m["endTime"] = static_cast<qlonglong>(p.endTime);
            progs.append(m);
        }
        return progs;
    }
    default:
        return {};
    }
}

QHash<int, QByteArray> EpgViewModel::roleNames() const {
    return {
        {ChannelIdRole, "channelId"},
        {ChannelNameRole, "channelName"},
        {ChannelLogoRole, "channelLogo"},
        {StreamUrlRole, "streamUrl"},
        {ProgrammesRole, "programmes"},
    };
}

int64_t EpgViewModel::serverId() const { return serverId_; }

void EpgViewModel::setServerId(int64_t id) {
    if (serverId_ != id) {
        serverId_ = id;
        emit serverIdChanged();
        loadGrid();
    }
}

int EpgViewModel::count() const {
    return static_cast<int>(rows_.size());
}

bool EpgViewModel::syncing() const { return syncing_; }

QString EpgViewModel::syncStatus() const { return syncStatus_; }

int64_t EpgViewModel::timeWindowStart() const { return timeWindowStart_; }

int64_t EpgViewModel::timeWindowEnd() const { return timeWindowEnd_; }

int64_t EpgViewModel::currentTime() const {
    return QDateTime::currentSecsSinceEpoch();
}

QString EpgViewModel::searchQuery() const { return searchQuery_; }

void EpgViewModel::setSearchQuery(const QString &query) {
    if (searchQuery_ != query) {
        searchQuery_ = query;
        emit searchQueryChanged();
        loadGrid();
    }
}

void EpgViewModel::refresh() {
    loadGrid();
}

void EpgViewModel::syncEpg(const QString &epgUrl) {
    if (!http_ || epgUrl.isEmpty() || syncing_) {
        return;
    }

    setSyncing(true);
    setSyncStatus("Downloading EPG data...");
    qInfo("EPG sync started: %s", qPrintable(epgUrl));

    auto *reply = http_->get(QUrl(epgUrl));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning("EPG sync failed: %s", qPrintable(reply->errorString()));
            setSyncStatus(
                QStringLiteral("EPG download failed: %1").arg(reply->errorString()));
            setSyncing(false);
            return;
        }

        setSyncStatus("Parsing EPG data (background)...");
        QByteArray data = reply->readAll();

        auto future = QtConcurrent::run([data]() {
            iptvxs::XmltvParser parser;
            return parser.parse(data);
        });
        parseWatcher_.setFuture(future);
    });
}

void EpgViewModel::shiftTime(int hours) {
    timeWindowStart_ += hours * 3600;
    timeWindowEnd_ += hours * 3600;
    emit timeWindowChanged();
    loadGrid();
}

QVariantList EpgViewModel::programmesForChannel(int row) const {
    if (row < 0 || row >= rows_.size()) {
        return {};
    }

    QVariantList result;
    for (const auto &p : rows_.at(row).programmes) {
        QVariantMap m;
        m["id"] = QVariant::fromValue(static_cast<qlonglong>(p.id));
        m["title"] = p.title;
        m["description"] = p.description;
        m["startTime"] = static_cast<qlonglong>(p.startTime);
        m["endTime"] = static_cast<qlonglong>(p.endTime);
        result.append(m);
    }
    return result;
}

void EpgViewModel::loadGrid() {
    if (!progRepo_ || !channelRepo_ || serverId_ <= 0) {
        return;
    }

    auto progsByChannel =
        progRepo_->findByTimeWindow(timeWindowStart_, timeWindowEnd_);

    if (progsByChannel.isEmpty()) {
        beginResetModel();
        rows_.clear();
        endResetModel();
        emit countChanged();
        return;
    }

    auto channels = channelRepo_->findByServerAndType(
        serverId_, QStringLiteral("live"), 0, 0);

    QVector<EpgChannelRow> newRows;
    newRows.reserve(progsByChannel.size());

    for (const auto &ch : channels) {
        if (!searchQuery_.isEmpty() &&
            !ch.name.contains(searchQuery_, Qt::CaseInsensitive)) {
            continue;
        }

        auto it = progsByChannel.find(ch.epgChannelId);
        if (it == progsByChannel.end()) {
            continue;
        }

        EpgChannelRow row;
        row.channel = ch;
        row.programmes = std::move(it.value());
        newRows.append(std::move(row));

        if (newRows.size() >= kMaxEpgRows) {
            break;
        }
    }

    beginResetModel();
    rows_ = std::move(newRows);
    endResetModel();
    emit countChanged();
}

void EpgViewModel::setSyncing(bool syncing) {
    if (syncing_ != syncing) {
        syncing_ = syncing;
        emit syncingChanged();
    }
}

void EpgViewModel::setSyncStatus(const QString &status) {
    if (syncStatus_ != status) {
        syncStatus_ = status;
        emit syncStatusChanged();
    }
}
