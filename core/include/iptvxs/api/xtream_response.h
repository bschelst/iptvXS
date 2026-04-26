// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QJsonObject>
#include <QString>
#include <QVector>
#include <cstdint>

namespace iptvxs {

struct XtreamUserInfo {
    QString username;
    QString password;
    QString status;
    int64_t expDate{0};
    bool isTrial{false};
    int activeCons{0};
    int64_t createdAt{0};
    int maxConnections{0};
    QStringList allowedOutputFormats;

    static XtreamUserInfo fromJson(const QJsonObject &obj);
};

struct XtreamServerInfo {
    QString url;
    int port{0};
    int httpsPort{0};
    QString serverProtocol;
    QString timezone;
    int64_t timestampNow{0};
    XtreamUserInfo userInfo;

    static XtreamServerInfo fromJson(const QJsonObject &obj);
};

struct XtreamCategory {
    QString categoryId;
    QString categoryName;
    int parentId{0};

    static XtreamCategory fromJson(const QJsonObject &obj);
};

struct XtreamStream {
    int64_t num{0};
    QString name;
    QString streamType;
    QString streamId;
    QString streamIcon;
    QString epgChannelId;
    int64_t added{0};
    QString categoryId;
    QString customSid;
    int tvArchive{0};
    QString directSource;
    int tvArchiveDuration{0};

    static XtreamStream fromJson(const QJsonObject &obj);
};

} // namespace iptvxs
