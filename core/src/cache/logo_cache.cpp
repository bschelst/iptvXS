#include "iptvxs/cache/logo_cache.h"

#include <QCryptographicHash>
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

    return url;
}

void LogoCache::prefetch(const QStringList &urls) {
    for (const auto &url : urls) {
        if (url.isEmpty() || cache_.contains(url) || pending_.contains(url)) {
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
    queue_.clear();
}

int LogoCache::cachedCount() const { return cache_.size(); }

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
                        emit logoReady(url, QStringLiteral("file://%1").arg(localPath));
                    }
                }
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

} // namespace iptvxs
