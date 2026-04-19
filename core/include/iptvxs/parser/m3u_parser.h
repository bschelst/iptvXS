#pragma once

#include <QIODevice>
#include <QObject>
#include <QSet>
#include <QString>
#include <QVector>

#include "iptvxs/models/channel.h"

namespace iptvxs {

class HttpClient;

class M3uParser : public QObject {
    Q_OBJECT

public:
    explicit M3uParser(QObject *parent = nullptr);

    void parse(QIODevice *device, int64_t serverId);
    QVector<Channel> parseAll(QIODevice *device, int64_t serverId);

    static void fromUrl(HttpClient *http, const QUrl &url, int64_t serverId,
                        std::function<void(QVector<Channel>, QSet<QString>)> onComplete,
                        std::function<void(QString)> onError,
                        QObject *context = nullptr);

signals:
    void channelParsed(const iptvxs::Channel &channel);
    void categoryDiscovered(const QString &groupTitle);
    void progressUpdated(int parsedCount);
    void finished(int totalCount);
    void errorOccurred(const QString &message, int lineNumber);

private:
    struct ExtInfData {
        QString name;
        QString tvgId;
        QString tvgLogo;
        QString groupTitle;
    };

    static ExtInfData parseExtInf(const QString &line);
    static QString extractAttribute(const QString &line, const QString &key);
    static QString detectChannelType(const QString &groupTitle, const QString &url);

    QSet<QString> discoveredGroups_;
};

} // namespace iptvxs
