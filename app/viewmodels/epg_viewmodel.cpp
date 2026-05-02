// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "epg_viewmodel.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QTemporaryFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSet>
#include <QUrl>
#include <QtConcurrent>
#include <algorithm>

namespace {
QString sanitizeUrl(const QString &url) {
    static const QRegularExpression re(
        QStringLiteral("((?:username|password|user|pass)=)[^&]*"),
        QRegularExpression::CaseInsensitiveOption);
    QString masked = url;
    masked.replace(re, QStringLiteral("\\1***"));
    return masked;
}

QString normalizeHttpUrl(const QString &input) {
    QUrl url(input);
    if (!url.isValid() ||
        (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))) {
        return input;
    }

    QString path = url.path();
    while (path.startsWith(QStringLiteral("//"))) {
        path.remove(0, 1);
    }
    url.setPath(path);
    return url.toString(QUrl::FullyEncoded);
}

QByteArray hmacSha256Hex(const QByteArray &key, const QByteArray &message) {
    constexpr int blockSize = 64;
    QByteArray normalizedKey = key;
    if (normalizedKey.size() > blockSize) {
        normalizedKey = QCryptographicHash::hash(normalizedKey, QCryptographicHash::Sha256);
    }
    normalizedKey = normalizedKey.leftJustified(blockSize, '\0', true);

    QByteArray oKeyPad(blockSize, '\0');
    QByteArray iKeyPad(blockSize, '\0');
    for (int i = 0; i < blockSize; ++i) {
        const auto keyByte = static_cast<unsigned char>(normalizedKey.at(i));
        oKeyPad[i] = static_cast<char>(keyByte ^ 0x5c);
        iKeyPad[i] = static_cast<char>(keyByte ^ 0x36);
    }

    const QByteArray inner = QCryptographicHash::hash(iKeyPad + message, QCryptographicHash::Sha256);
    return QCryptographicHash::hash(oKeyPad + inner, QCryptographicHash::Sha256).toHex();
}

QNetworkRequest buildProtectedRequest(const QString &url) {
    QUrl qurl(url);
    QNetworkRequest request{qurl};
    request.setTransferTimeout(30000);
    request.setRawHeader("X-API-Key", QByteArrayLiteral(IPTVXS_GATEWAY_API_KEY));
    request.setRawHeader("User-Agent",
                         QStringLiteral("IPTVXs/%1")
                             .arg(QCoreApplication::applicationVersion().isEmpty()
                                      ? QStringLiteral("0.3.8")
                                      : QCoreApplication::applicationVersion())
                             .toUtf8());
    const auto timestamp = QByteArray::number(QDateTime::currentSecsSinceEpoch());
    request.setRawHeader("X-Timestamp", timestamp);
    const auto secret = QByteArray::fromBase64(QByteArray(
        "OWYzYTdjOGIyZDFlNmE0ZjVjMGI5ZDhlN2ExZjJjM2Q0ZTViNmE3YzhkOWUwZjFhMmIzYzRkNWU2"
        "ZjdhOGI5Yw=="));
    const auto message = timestamp + QByteArrayLiteral(":") + qurl.path().toUtf8();
    request.setRawHeader("X-Signature", hmacSha256Hex(secret, message));
    return request;
}
}

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
                    qInfo("EPG sync completed: no programmes parsed");
                    emit syncCompleted(true, 0, QStringLiteral("No EPG data found"));
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
                emit syncCompleted(true, programmes.size(),
                                   QStringLiteral("EPG synced: %1 programmes").arg(programmes.size()));
                setSyncing(false);
                loadGrid();
            });
}

void EpgViewModel::setRepositories(iptvxs::ProgrammeRepository *progRepo,
                                   iptvxs::ChannelRepository *channelRepo,
                                   iptvxs::FavoriteRepository *favoriteRepo) {
    progRepo_ = progRepo;
    channelRepo_ = channelRepo;
    favoriteRepo_ = favoriteRepo;
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
    case EpgChannelIdRole:
        return row.channel.epgChannelId;
    case IsFavoriteRole:
        return row.isFavorite;
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
        {EpgChannelIdRole, "epgChannelId"},
        {ProgrammesRole, "programmes"},
        {IsFavoriteRole, "isFavorite"},
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

void EpgViewModel::handleDownloadedEpgData(const QByteArray &data) {
    setSyncStatus("Parsing EPG data (background)...");

    auto future = QtConcurrent::run([data]() {
        iptvxs::XmltvParser parser;
        return parser.parse(data);
    });
    parseWatcher_.setFuture(future);
}

bool EpgViewModel::decodeChunkedBody(const QByteArray &chunked, QByteArray *decoded) {
    qsizetype pos = 0;
    while (true) {
        const qsizetype lineEnd = chunked.indexOf("\r\n", pos);
        if (lineEnd < 0) {
            return false;
        }

        QByteArray sizeLine = chunked.mid(pos, lineEnd - pos).trimmed();
        const int semicolon = sizeLine.indexOf(';');
        if (semicolon >= 0) {
            sizeLine = sizeLine.left(semicolon);
        }

        bool ok = false;
        const qsizetype size = sizeLine.toLongLong(&ok, 16);
        if (!ok) {
            return false;
        }

        pos = lineEnd + 2;
        if (size == 0) {
            return true;
        }
        if (pos + size + 2 > chunked.size()) {
            return false;
        }

        decoded->append(chunked.mid(pos, size));
        pos += size + 2;
    }
}

void EpgViewModel::syncEpg(const QString &epgUrl) {
    if (!http_ || epgUrl.isEmpty() || syncing_) {
        return;
    }

    const QString normalizedUrl = normalizeHttpUrl(epgUrl);
    setSyncing(true);
    qInfo("EPG sync started: %s", qPrintable(sanitizeUrl(normalizedUrl)));

    const QUrl url(normalizedUrl);
    if (qEnvironmentVariableIsSet("FLATPAK_ID") && url.scheme() == QStringLiteral("http")) {
        startCurlFallbackDownload(normalizedUrl);
        return;
    }

    setSyncStatus("Downloading EPG data...");
    auto *reply = http_->get(buildProtectedRequest(normalizedUrl));
    auto *buffer = new QByteArray();
    connect(reply, &QIODevice::readyRead, this, [reply, buffer]() {
        buffer->append(reply->readAll());
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, buffer]() {
        const int statusCode =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        buffer->append(reply->readAll());
        const QByteArray data = *buffer;
        const bool tolerateRemoteClose =
            reply->error() == QNetworkReply::RemoteHostClosedError &&
            !data.isEmpty();

        if (reply->error() != QNetworkReply::NoError && !tolerateRemoteClose) {
            qWarning("EPG sync failed: %s (code=%d http=%d bytes=%lld)",
                     qPrintable(reply->errorString()),
                     static_cast<int>(reply->error()),
                     statusCode,
                     static_cast<long long>(data.size()));
            setSyncStatus(
                QStringLiteral("EPG download failed: %1").arg(reply->errorString()));
            emit syncCompleted(false, 0,
                               QStringLiteral("EPG download failed: %1").arg(reply->errorString()));
            setSyncing(false);
            reply->deleteLater();
            delete buffer;
            return;
        }

        if (tolerateRemoteClose) {
            qWarning("EPG sync: accepting closed connection after %lld bytes with HTTP %d",
                     static_cast<long long>(data.size()), statusCode);
        }

        handleDownloadedEpgData(data);
        reply->deleteLater();
        delete buffer;
    });
}

void EpgViewModel::startCurlFallbackDownload(const QString &epgUrl) {
    auto *tempFile = new QTemporaryFile(QDir::tempPath() + QStringLiteral("/iptvxs-epg-XXXXXX.xml"), this);
    tempFile->setAutoRemove(false);
    if (!tempFile->open()) {
        qWarning("EPG curl fallback failed: cannot create temp file");
        setSyncStatus(QStringLiteral("EPG download failed: cannot create temp file"));
        setSyncing(false);
        delete tempFile;
        return;
    }
    const QString tempPath = tempFile->fileName();
    tempFile->close();

    auto *process = new QProcess(this);
    process->setProgram(QStringLiteral("curl"));
    process->setArguments({
        QStringLiteral("--fail"),
        QStringLiteral("--location"),
        QStringLiteral("--silent"),
        QStringLiteral("--show-error"),
        QStringLiteral("--connect-timeout"),
        QStringLiteral("20"),
        QStringLiteral("--max-time"),
        QStringLiteral("180"),
        QStringLiteral("--user-agent"),
        QStringLiteral("IPTVXs/%1")
            .arg(QCoreApplication::applicationVersion().isEmpty()
                     ? QStringLiteral("0.1.0")
                     : QCoreApplication::applicationVersion()),
        QStringLiteral("--header"),
        QStringLiteral("Accept-Encoding: identity"),
        QStringLiteral("--output"),
        tempPath,
        normalizeHttpUrl(epgUrl),
    });

    connect(process,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this,
            [this, process, tempFile, tempPath](int exitCode, QProcess::ExitStatus exitStatus) {
                const QByteArray stderrText = process->readAllStandardError();
                QByteArray data;
                QFile file(tempPath);
                if (file.open(QIODevice::ReadOnly)) {
                    data = file.readAll();
                    file.close();
                }
                QFile::remove(tempPath);
                tempFile->deleteLater();
                process->deleteLater();

                if (exitStatus != QProcess::NormalExit || exitCode != 0 ||
                    data.isEmpty()) {
                qWarning("EPG curl fallback failed: exit=%d status=%d bytes=%lld stderr=%s",
                             exitCode,
                             static_cast<int>(exitStatus),
                             static_cast<long long>(data.size()),
                             qPrintable(QString::fromUtf8(stderrText).trimmed()));
                    setSyncStatus(QStringLiteral("EPG download failed: %1")
                                      .arg(stderrText.isEmpty()
                                               ? QStringLiteral("curl fallback failed")
                                               : QString::fromUtf8(stderrText).trimmed()));
                    emit syncCompleted(false, 0,
                                       QStringLiteral("EPG download failed: %1")
                                           .arg(stderrText.isEmpty()
                                                    ? QStringLiteral("curl fallback failed")
                                                    : QString::fromUtf8(stderrText).trimmed()));
                    setSyncing(false);
                    return;
                }

                qWarning("EPG sync: curl fallback downloaded %lld bytes",
                         static_cast<long long>(data.size()));
                handleDownloadedEpgData(data);
            });

    connect(process, &QProcess::errorOccurred, this,
            [this, process, tempFile, tempPath](QProcess::ProcessError error) {
        qWarning("EPG curl fallback process error: %d", static_cast<int>(error));
        QFile::remove(tempPath);
        tempFile->deleteLater();
        setSyncStatus(QStringLiteral("EPG download failed: curl unavailable"));
        emit syncCompleted(false, 0, QStringLiteral("EPG download failed: curl unavailable"));
        setSyncing(false);
        process->deleteLater();
    });

    setSyncStatus("Retrying EPG download...");
    process->start();
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

QVariantMap EpgViewModel::rowData(int row) const {
    if (row < 0 || row >= rows_.size()) {
        return {};
    }

    const auto &r = rows_.at(row);
    QVariantMap m;
    m["channelId"] = QVariant::fromValue(static_cast<qlonglong>(r.channel.id));
    m["channelName"] = r.channel.name;
    m["channelLogo"] = r.channel.logoUrl;
    m["streamUrl"] = r.channel.streamUrl;
    m["epgChannelId"] = r.channel.epgChannelId;
    m["isFavorite"] = r.isFavorite;
    return m;
}

void EpgViewModel::loadGrid() {
    if (!progRepo_ || !channelRepo_ || serverId_ <= 0) {
        return;
    }

    auto progsByChannel =
        progRepo_->findByTimeWindow(timeWindowStart_, timeWindowEnd_);

    if (progsByChannel.isEmpty()) {
        qInfo("EPG loadGrid: no programmes in window [%lld..%lld]",
              static_cast<long long>(timeWindowStart_),
              static_cast<long long>(timeWindowEnd_));
        beginResetModel();
        rows_.clear();
        endResetModel();
        emit countChanged();
        return;
    }

    auto channels = channelRepo_->findByServerAndType(
        serverId_, QStringLiteral("live"), 0, 0);

    QSet<int64_t> favoriteIds;
    if (favoriteRepo_) {
        for (const auto &fav : favoriteRepo_->findAll()) {
            favoriteIds.insert(fav.channelId);
        }
    }

    std::sort(channels.begin(), channels.end(),
              [&favoriteIds](const iptvxs::Channel &a, const iptvxs::Channel &b) {
                  const bool favA = favoriteIds.contains(a.id);
                  const bool favB = favoriteIds.contains(b.id);
                  if (favA != favB) {
                      return favA;
                  }
                  return QString::localeAwareCompare(a.name, b.name) < 0;
              });

    QVector<EpgChannelRow> newRows;
    newRows.reserve(progsByChannel.size());

    int skippedBySearch = 0;
    int missingTvgId = 0;
    int noProgrammes = 0;
    int matched = 0;

    for (const auto &ch : channels) {
        if (!searchQuery_.isEmpty() &&
            !ch.name.contains(searchQuery_, Qt::CaseInsensitive)) {
            ++skippedBySearch;
            continue;
        }

        if (ch.epgChannelId.isEmpty()) {
            ++missingTvgId;
            continue;
        }

        const QString channelKey = ch.epgChannelId.trimmed().toLower();
        auto it = progsByChannel.find(channelKey);
        if (it == progsByChannel.end()) {
            ++noProgrammes;
            continue;
        }

        EpgChannelRow row;
        row.channel = ch;
        row.programmes = std::move(it.value());
        row.isFavorite = favoriteIds.contains(ch.id);
        newRows.append(std::move(row));
        ++matched;

        if (newRows.size() >= kMaxEpgRows) {
            break;
        }
    }

    qInfo("EPG loadGrid: totalChannels=%lld rows=%lld matched=%d noTvgId=%d "
          "noProgInWindow=%d skippedBySearch=%d xmltvChannels=%lld window=[%lld..%lld]",
          static_cast<long long>(channels.size()),
          static_cast<long long>(newRows.size()),
          matched, missingTvgId, noProgrammes, skippedBySearch,
          static_cast<long long>(progsByChannel.size()),
          static_cast<long long>(timeWindowStart_),
          static_cast<long long>(timeWindowEnd_));

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
