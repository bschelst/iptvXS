#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVector>

#include "iptvxs/api/xtream_response.h"

namespace iptvxs {

class HttpClient;

class XtreamClient : public QObject {
    Q_OBJECT

public:
    XtreamClient(HttpClient *http, const QString &serverUrl,
                 const QString &username, const QString &password,
                 QObject *parent = nullptr);

    void fetchServerInfo();
    void fetchLiveCategories();
    void fetchLiveStreams(const QString &categoryId = {});
    void fetchVodCategories();
    void fetchVodStreams(const QString &categoryId = {});
    void fetchSeriesCategories();
    void fetchSeries(const QString &categoryId = {});

    QUrl buildApiUrl(const QString &action, const QString &categoryId = {}) const;

signals:
    void serverInfoReady(const iptvxs::XtreamServerInfo &info);
    void liveCategoriesReady(const QVector<iptvxs::XtreamCategory> &categories);
    void liveStreamsReady(const QVector<iptvxs::XtreamStream> &streams);
    void vodCategoriesReady(const QVector<iptvxs::XtreamCategory> &categories);
    void vodStreamsReady(const QVector<iptvxs::XtreamStream> &streams);
    void seriesCategoriesReady(const QVector<iptvxs::XtreamCategory> &categories);
    void seriesReady(const QVector<iptvxs::XtreamStream> &streams);
    void errorOccurred(const QString &message);

private:
    void fetchCategories(const QString &action,
                         void (XtreamClient::*signal)(const QVector<XtreamCategory> &));
    void fetchStreams(const QString &action, const QString &categoryId,
                     void (XtreamClient::*signal)(const QVector<XtreamStream> &));
    void handleNetworkError(QObject *reply, const QString &context);

    HttpClient *http_;
    QString serverUrl_;
    QString username_;
    QString password_;
};

} // namespace iptvxs
