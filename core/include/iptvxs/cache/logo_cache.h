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

public:
    explicit LogoCache(QObject *parent = nullptr);

    void setCacheDir(const QString &path);
    Q_INVOKABLE QString resolve(const QString &url) const;
    Q_INVOKABLE void prefetch(const QStringList &urls);
    void clear();
    int cachedCount() const;

signals:
    void logoReady(const QString &url, const QString &localPath);

private:
    void downloadNext();
    QString urlToFilename(const QString &url) const;

    QString cacheDir_;
    QNetworkAccessManager *nam_;
    QHash<QString, QString> cache_; // url -> local path
    QSet<QString> pending_;
    QStringList queue_;
    int activeDownloads_{0};
    static constexpr int kMaxConcurrent = 4;
};

} // namespace iptvxs
