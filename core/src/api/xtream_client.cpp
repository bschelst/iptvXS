// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/api/xtream_client.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QUrlQuery>

#include <QRegularExpression>

#include "iptvxs/net/http_client.h"

namespace {
QString sanitizeUrl(const QString &url) {
    static const QRegularExpression re(
        QStringLiteral("((?:username|password|user|pass)=)[^&]*"),
        QRegularExpression::CaseInsensitiveOption);
    QString masked = url;
    masked.replace(re, QStringLiteral("\\1***"));
    return masked;
}
}

namespace iptvxs {

XtreamClient::XtreamClient(HttpClient *http, const QString &serverUrl,
                           const QString &username, const QString &password,
                           QObject *parent)
    : QObject(parent),
      http_(http),
      serverUrl_(serverUrl),
      username_(username),
      password_(password) {}

QUrl XtreamClient::buildApiUrl(const QString &action, const QString &categoryId) const {
    QUrl url(serverUrl_);
    url.setPath("/player_api.php");

    QUrlQuery query;
    query.addQueryItem("username", username_);
    query.addQueryItem("password", password_);
    if (!action.isEmpty()) {
        query.addQueryItem("action", action);
    }
    if (!categoryId.isEmpty()) {
        query.addQueryItem("category_id", categoryId);
    }
    url.setQuery(query);
    return url;
}

void XtreamClient::fetchServerInfo() {
    auto *reply = http_->get(buildApiUrl({}));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("Server info request failed: %1").arg(reply->errorString()));
            return;
        }

        const auto doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            emit errorOccurred(QStringLiteral("Invalid server info response"));
            return;
        }

        auto info = XtreamServerInfo::fromJson(doc.object());
        if (info.userInfo.status != "Active") {
            emit errorOccurred(QStringLiteral("Account not active: %1").arg(info.userInfo.status));
            return;
        }

        emit serverInfoReady(info);
    });
}

void XtreamClient::fetchLiveCategories() {
    fetchCategories("get_live_categories", &XtreamClient::liveCategoriesReady);
}

void XtreamClient::fetchLiveStreams(const QString &categoryId) {
    fetchStreams("get_live_streams", categoryId, &XtreamClient::liveStreamsReady);
}

void XtreamClient::fetchVodCategories() {
    fetchCategories("get_vod_categories", &XtreamClient::vodCategoriesReady);
}

void XtreamClient::fetchVodStreams(const QString &categoryId) {
    fetchStreams("get_vod_streams", categoryId, &XtreamClient::vodStreamsReady);
}

void XtreamClient::fetchSeriesCategories() {
    fetchCategories("get_series_categories", &XtreamClient::seriesCategoriesReady);
}

void XtreamClient::fetchSeries(const QString &categoryId) {
    fetchStreams("get_series", categoryId, &XtreamClient::seriesReady);
}

void XtreamClient::fetchSeriesInfo(const QString &seriesId) {
    QUrl url = buildApiUrl(QStringLiteral("get_series_info"));
    QUrlQuery query(url.query());
    query.addQueryItem(QStringLiteral("series_id"), seriesId);
    url.setQuery(query);

    qInfo("Fetching series info: %s", qPrintable(sanitizeUrl(url.toString())));
    auto *reply = http_->get(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply, seriesId]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("Series info request failed: %1").arg(reply->errorString()));
            return;
        }

        auto data = reply->readAll();
        const auto doc = QJsonDocument::fromJson(data);
        qInfo("Series info response for %s: %d bytes, isObject=%d isArray=%d isNull=%d",
              qPrintable(seriesId), data.size(), doc.isObject(), doc.isArray(), doc.isNull());
        if (doc.isNull() || doc.isEmpty()) {
            qWarning("Series info raw response: %s", data.left(500).constData());
            emit errorOccurred(QStringLiteral("Invalid series info response"));
            return;
        }

        QJsonObject obj;
        if (doc.isObject()) {
            obj = doc.object();
        } else if (doc.isArray()) {
            obj[QStringLiteral("episodes")] = doc.array();
        }

        emit seriesInfoReady(seriesId, obj);
    });
}

void XtreamClient::fetchCategories(
    const QString &action,
    void (XtreamClient::*signal)(const QVector<XtreamCategory> &)) {
    auto *reply = http_->get(buildApiUrl(action));
    connect(reply, &QNetworkReply::finished, this, [this, reply, signal]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("Category request failed: %1").arg(reply->errorString()));
            return;
        }

        const auto doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isArray()) {
            emit errorOccurred(QStringLiteral("Invalid categories response"));
            return;
        }

        QVector<XtreamCategory> categories;
        const auto arr = doc.array();
        categories.reserve(arr.size());
        for (const auto &val : arr) {
            categories.append(XtreamCategory::fromJson(val.toObject()));
        }

        emit(this->*signal)(categories);
    });
}

void XtreamClient::fetchStreams(
    const QString &action, const QString &categoryId,
    void (XtreamClient::*signal)(const QVector<XtreamStream> &)) {
    auto *reply = http_->get(buildApiUrl(action, categoryId));
    connect(reply, &QNetworkReply::finished, this, [this, reply, signal]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QStringLiteral("Stream request failed: %1").arg(reply->errorString()));
            return;
        }

        const auto doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isArray()) {
            emit errorOccurred(QStringLiteral("Invalid streams response"));
            return;
        }

        QVector<XtreamStream> streams;
        const auto arr = doc.array();
        streams.reserve(arr.size());
        if (!arr.isEmpty()) {
            auto firstObj = arr.first().toObject();
            qInfo("First stream entry keys: %s", qPrintable(firstObj.keys().join(", ")));
        }
        for (const auto &val : arr) {
            streams.append(XtreamStream::fromJson(val.toObject()));
        }

        emit(this->*signal)(streams);
    });
}

} // namespace iptvxs
