// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>

namespace iptvxs {

class LogoCache : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(int failedRevision READ failedRevision NOTIFY failedRevisionChanged)

public:
    explicit LogoCache(QObject *parent = nullptr);

    void setCacheDir(const QString &path);
    Q_INVOKABLE QString resolve(const QString &url) const;
    Q_INVOKABLE void prefetch(const QStringList &urls);
    Q_INVOKABLE bool isBlocked(const QString &url) const;
    Q_INVOKABLE void markFailed(const QString &url);
    void clear();
    int cachedCount() const;
    int revision() const;
    int failedRevision() const;

signals:
    void logoReady(const QString &url, const QString &localPath);
    void revisionChanged();
    void failedRevisionChanged();

private:
    void downloadNext();
    QString urlToFilename(const QString &url) const;
    static QString hostForUrl(const QString &url);

    QString cacheDir_;
    QNetworkAccessManager *nam_;
    QHash<QString, QString> cache_; // url -> local path
    QSet<QString> pending_;
    QSet<QString> blockedHosts_;
    QStringList queue_;
    int activeDownloads_{0};
    int revision_{0};
    int failedRevision_{0};
    static constexpr int kMaxConcurrent = 4;
};

} // namespace iptvxs
