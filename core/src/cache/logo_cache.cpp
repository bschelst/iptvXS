// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/cache/logo_cache.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkReply>
#include <QUrl>

namespace iptvxs {

LogoCache::LogoCache(QObject *parent)
    : QObject(parent), nam_(new QNetworkAccessManager(this)) {}

void LogoCache::setCacheDir(const QString &path) {
    cacheDir_ = path;

    QDir dir(cacheDir_);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    // Scan existing cached files to populate the in-memory map.
    // File names are SHA1(url).ext — we cannot reverse the hash to recover
    // the original URL, so we store the mapping lazily at resolve() time.
    // Pre-populating from disk only tells us a file exists; the url->path
    // mapping is rebuilt as resolve() is called.
    cache_.clear();
}

QString LogoCache::resolve(const QString &url) const {
    if (url.isEmpty()) {
        return url;
    }

    if (isBlocked(url)) {
        return {};
    }

    // Already cached in memory?
    if (cache_.contains(url)) {
        return QStringLiteral("file://%1").arg(cache_.value(url));
    }

    // Check on disk (might have been downloaded in a previous session).
    const QString filename = urlToFilename(url);
    const QString localPath = QStringLiteral("%1/%2").arg(cacheDir_, filename);

    if (QFile::exists(localPath)) {
        // Populate the in-memory map and return the local path.
        const_cast<LogoCache *>(this)->cache_.insert(url, localPath);
        return QStringLiteral("file://%1").arg(localPath);
    }

    // Not cached — queue a download and return the original URL for now.
    if (!const_cast<LogoCache *>(this)->pending_.contains(url)) {
        const_cast<LogoCache *>(this)->pending_.insert(url);
        const_cast<LogoCache *>(this)->queue_.append(url);
        const_cast<LogoCache *>(this)->downloadNext();
    }

    return {};
}

void LogoCache::prefetch(const QStringList &urls) {
    for (const auto &url : urls) {
        if (url.isEmpty() || isBlocked(url) || cache_.contains(url) || pending_.contains(url)) {
            continue;
        }

        const QString filename = urlToFilename(url);
        const QString localPath = QStringLiteral("%1/%2").arg(cacheDir_, filename);
        if (QFile::exists(localPath)) {
            cache_.insert(url, localPath);
            continue;
        }

        pending_.insert(url);
        queue_.append(url);
    }

    downloadNext();
}

bool LogoCache::isBlocked(const QString &url) const {
    const QString host = hostForUrl(url);
    return !host.isEmpty() && blockedHosts_.contains(host);
}

void LogoCache::markFailed(const QString &url) {
    const QString host = hostForUrl(url);
    if (host.isEmpty() || blockedHosts_.contains(host)) {
        return;
    }

    blockedHosts_.insert(host);
    ++failedRevision_;
    emit failedRevisionChanged();
}

void LogoCache::clear() {
    QDir dir(cacheDir_);
    if (dir.exists()) {
        const auto entries = dir.entryList(QDir::Files);
        for (const auto &entry : entries) {
            dir.remove(entry);
        }
    }
    cache_.clear();
    pending_.clear();
    blockedHosts_.clear();
    queue_.clear();
    if (revision_ != 0) {
        revision_ = 0;
        emit revisionChanged();
    }
    if (failedRevision_ != 0) {
        failedRevision_ = 0;
        emit failedRevisionChanged();
    }
}

qint64 LogoCache::cacheSizeBytes() const {
    qint64 total = 0;
    QDir dir(cacheDir_);
    if (!dir.exists()) return 0;
    const auto entries = dir.entryInfoList(QDir::Files);
    for (const auto &fi : entries) {
        total += fi.size();
    }
    return total;
}

QString LogoCache::cacheSizeFormatted() const {
    auto bytes = cacheSizeBytes();
    if (bytes < 1024) return QStringLiteral("%1 B").arg(bytes);
    if (bytes < 1024 * 1024) return QStringLiteral("%1 KB").arg(bytes / 1024.0, 0, 'f', 1);
    if (bytes < 1024LL * 1024 * 1024) return QStringLiteral("%1 MB").arg(bytes / (1024.0 * 1024), 0, 'f', 1);
    return QStringLiteral("%1 GB").arg(bytes / (1024.0 * 1024 * 1024), 0, 'f', 2);
}

void LogoCache::pruneExpired(int maxAgeDays, qint64 maxSizeBytes) {
    QDir dir(cacheDir_);
    if (!dir.exists()) return;

    auto now = QDateTime::currentDateTime();
    auto entries = dir.entryInfoList(QDir::Files, QDir::Time | QDir::Reversed);
    int removed = 0;

    for (const auto &fi : entries) {
        if (fi.lastModified().daysTo(now) > maxAgeDays) {
            dir.remove(fi.fileName());
            ++removed;
        }
    }

    entries = dir.entryInfoList(QDir::Files, QDir::Time | QDir::Reversed);
    qint64 totalSize = 0;
    for (const auto &fi : entries) totalSize += fi.size();

    if (totalSize > maxSizeBytes) {
        for (const auto &fi : entries) {
            if (totalSize <= maxSizeBytes) break;
            totalSize -= fi.size();
            dir.remove(fi.fileName());
            ++removed;
        }
    }

    if (removed > 0) {
        qInfo("Logo cache pruned: %d files removed", removed);
        cache_.clear();
        ++revision_;
        emit revisionChanged();
    }
}

int LogoCache::cachedCount() const { return cache_.size(); }
int LogoCache::revision() const { return revision_; }
int LogoCache::failedRevision() const { return failedRevision_; }

void LogoCache::downloadNext() {
    while (activeDownloads_ < kMaxConcurrent && !queue_.isEmpty()) {
        const QString url = queue_.takeFirst();

        if (cache_.contains(url)) {
            pending_.remove(url);
            continue;
        }

        ++activeDownloads_;

        QUrl qurl(url);
        QNetworkRequest request(qurl);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                             QNetworkRequest::NoLessSafeRedirectPolicy);
        auto *reply = nam_->get(request);

        connect(reply, &QNetworkReply::finished, this, [this, reply, url]() {
            reply->deleteLater();
            --activeDownloads_;

            if (reply->error() == QNetworkReply::NoError) {
                const QByteArray data = reply->readAll();
                if (!data.isEmpty()) {
                    const QString filename = urlToFilename(url);
                    const QString localPath =
                        QStringLiteral("%1/%2").arg(cacheDir_, filename);

                    QFile file(localPath);
                    if (file.open(QIODevice::WriteOnly)) {
                        file.write(data);
                        file.close();
                        cache_.insert(url, localPath);
                        ++revision_;
                        emit revisionChanged();
                        emit logoReady(url, QStringLiteral("file://%1").arg(localPath));
                    }
                }
            } else {
                markFailed(url);
            }

            pending_.remove(url);
            downloadNext();
        });
    }
}

QString LogoCache::urlToFilename(const QString &url) const {
    const QByteArray hash =
        QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex();

    // Extract extension from URL, default to .png.
    QString ext = QStringLiteral(".png");
    const QUrl parsed(url);
    const QString path = parsed.path();
    const int dotIdx = path.lastIndexOf('.');
    if (dotIdx >= 0) {
        const QString urlExt = path.mid(dotIdx).toLower();
        if (urlExt == ".jpg" || urlExt == ".jpeg" || urlExt == ".png" ||
            urlExt == ".svg" || urlExt == ".webp" || urlExt == ".gif") {
            ext = urlExt;
        }
    }

    return QString::fromLatin1(hash) + ext;
}

QString LogoCache::hostForUrl(const QString &url) {
    const QUrl parsed(url);
    if (!parsed.isValid()) {
        return {};
    }
    return parsed.host().toLower();
}

} // namespace iptvxs
