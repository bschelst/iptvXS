// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/gdrive/gdrive_sync_io.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

namespace iptvxs {

namespace {
constexpr const char *kListUrl = "https://www.googleapis.com/drive/v3/files";
constexpr const char *kCreateUrl =
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart";
constexpr const char *kUpdateUrlBase =
    "https://www.googleapis.com/upload/drive/v3/files/";
constexpr const char *kMediaUrlBase =
    "https://www.googleapis.com/drive/v3/files/";
} // namespace

GDriveSyncIO::GDriveSyncIO(GDriveAuth *auth, QObject *parent)
    : QObject(parent), auth_(auth) {}

void GDriveSyncIO::withToken(std::function<void(const QString &)> action,
                             std::function<void(const QString &)> onError) {
    if (!auth_ || !auth_->isAuthenticated()) {
        if (onError) onError(QStringLiteral("Not authenticated with Google Drive"));
        return;
    }
    if (!auth_->needsRefresh()) {
        action(auth_->accessToken());
        return;
    }
    auto conn = std::make_shared<QMetaObject::Connection>();
    auto errConn = std::make_shared<QMetaObject::Connection>();
    *conn = connect(auth_, &GDriveAuth::tokenRefreshed, this,
                    [this, action, conn, errConn]() {
                        disconnect(*conn);
                        disconnect(*errConn);
                        action(auth_->accessToken());
                    });
    *errConn = connect(auth_, &GDriveAuth::authenticationFailed, this,
                       [onError, conn, errConn](const QString &error) {
                           disconnect(*conn);
                           disconnect(*errConn);
                           if (onError) onError(error);
                       });
    auth_->refreshTokenIfNeeded();
}

void GDriveSyncIO::findFile(const QString &folderId, const QString &fileName,
                            FindCallback cb) {
    withToken(
        [this, folderId, fileName, cb](const QString &token) {
            QUrl url(QString::fromLatin1(kListUrl));
            QUrlQuery q;
            QString queryStr;
            const auto safeName = QString(fileName).replace('\'', "\\'");
            if (folderId.isEmpty()) {
                queryStr = QStringLiteral("name = '%1' and trashed = false").arg(safeName);
            } else {
                queryStr = QStringLiteral("name = '%1' and '%2' in parents and trashed = false")
                               .arg(safeName, folderId);
            }
            q.addQueryItem("q", queryStr);
            q.addQueryItem("fields", "files(id,name)");
            q.addQueryItem("pageSize", "1");
            url.setQuery(q);
            QNetworkRequest req(url);
            req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
            auto *reply = nam_.get(req);
            connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
                reply->deleteLater();
                if (reply->error() != QNetworkReply::NoError) {
                    cb({}, reply->errorString());
                    return;
                }
                const auto doc = QJsonDocument::fromJson(reply->readAll());
                const auto files = doc.object().value("files").toArray();
                if (files.isEmpty()) {
                    cb({}, {});
                    return;
                }
                cb(files.first().toObject().value("id").toString(), {});
            });
        },
        [cb](const QString &err) { cb({}, err); });
}

void GDriveSyncIO::downloadFile(const QString &fileId, DownloadCallback cb) {
    if (fileId.isEmpty()) {
        cb({}, QStringLiteral("downloadFile: empty fileId"));
        return;
    }
    withToken(
        [this, fileId, cb](const QString &token) {
            QUrl url(QString::fromLatin1(kMediaUrlBase) + fileId);
            QUrlQuery q;
            q.addQueryItem("alt", "media");
            url.setQuery(q);
            QNetworkRequest req(url);
            req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
            auto *reply = nam_.get(req);
            connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
                reply->deleteLater();
                if (reply->error() != QNetworkReply::NoError) {
                    cb({}, reply->errorString());
                    return;
                }
                cb(reply->readAll(), {});
            });
        },
        [cb](const QString &err) { cb({}, err); });
}

void GDriveSyncIO::uploadBytes(const QByteArray &data, const QString &fileName,
                               const QByteArray &mimeType, const QString &folderId,
                               const QString &existingFileId, UploadCallback cb) {
    withToken(
        [this, data, fileName, mimeType, folderId, existingFileId, cb](const QString &token) {
            // Build multipart/related body manually.
            QJsonObject metadata;
            metadata["name"] = fileName;
            if (!folderId.isEmpty() && existingFileId.isEmpty()) {
                metadata["parents"] = QJsonArray{ folderId };
            }
            const auto metaJson = QJsonDocument(metadata).toJson(QJsonDocument::Compact);

            const auto boundary = QString("iptvxs_sync_%1")
                                      .arg(QUuid::createUuid().toString(QUuid::WithoutBraces))
                                      .toUtf8();

            QByteArray body;
            body.append("--" + boundary + "\r\n");
            body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n");
            body.append(metaJson);
            body.append("\r\n--" + boundary + "\r\n");
            body.append("Content-Type: " + mimeType + "\r\n\r\n");
            body.append(data);
            body.append("\r\n--" + boundary + "--");

            QUrl url;
            QNetworkRequest req;
            QNetworkReply *reply = nullptr;
            const auto contentType = QByteArray("multipart/related; boundary=") + boundary;
            req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
            req.setRawHeader("Content-Type", contentType);
            req.setRawHeader("Content-Length", QByteArray::number(body.size()));

            if (existingFileId.isEmpty()) {
                url = QUrl(QString::fromLatin1(kCreateUrl));
                req.setUrl(url);
                reply = nam_.post(req, body);
            } else {
                url = QUrl(QString::fromLatin1(kUpdateUrlBase) + existingFileId
                            + "?uploadType=multipart");
                req.setUrl(url);
                // PATCH for update.
                reply = nam_.sendCustomRequest(req, "PATCH", body);
            }

            connect(reply, &QNetworkReply::finished, this, [reply, cb]() {
                reply->deleteLater();
                const auto body = reply->readAll();
                if (reply->error() != QNetworkReply::NoError) {
                    cb({}, QStringLiteral("%1 — %2").arg(reply->errorString(),
                                                          QString::fromUtf8(body.left(256))));
                    return;
                }
                const auto doc = QJsonDocument::fromJson(body);
                const auto fileId = doc.object().value("id").toString();
                if (fileId.isEmpty()) {
                    cb({}, QStringLiteral("upload returned no fileId: %1")
                              .arg(QString::fromUtf8(body.left(256))));
                    return;
                }
                cb(fileId, {});
            });
        },
        [cb](const QString &err) { cb({}, err); });
}

void GDriveSyncIO::ensureFolder(const QString &folderName, FolderCallback cb) {
    if (folderName.isEmpty()) {
        cb({}, QStringLiteral("ensureFolder: empty name"));
        return;
    }
    withToken(
        [this, folderName, cb](const QString &token) {
            QUrl url(QString::fromLatin1(kListUrl));
            QUrlQuery q;
            const auto safeName = QString(folderName).replace('\'', "\\'");
            q.addQueryItem("q",
                QStringLiteral("name = '%1' and mimeType = 'application/vnd.google-apps.folder' "
                               "and 'root' in parents and trashed = false").arg(safeName));
            q.addQueryItem("fields", "files(id,name)");
            q.addQueryItem("pageSize", "1");
            url.setQuery(q);
            QNetworkRequest req(url);
            req.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
            auto *reply = nam_.get(req);
            connect(reply, &QNetworkReply::finished, this,
                    [this, reply, folderName, token, cb]() {
                        reply->deleteLater();
                        if (reply->error() != QNetworkReply::NoError) {
                            cb({}, reply->errorString());
                            return;
                        }
                        const auto files = QJsonDocument::fromJson(reply->readAll())
                                              .object().value("files").toArray();
                        if (!files.isEmpty()) {
                            cb(files.first().toObject().value("id").toString(), {});
                            return;
                        }
                        // Create folder.
                        QNetworkRequest creq(QUrl(QStringLiteral("https://www.googleapis.com/drive/v3/files")));
                        creq.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
                        creq.setRawHeader("Content-Type", "application/json");
                        QJsonObject body;
                        body["name"] = folderName;
                        body["mimeType"] = "application/vnd.google-apps.folder";
                        auto *createReply = nam_.post(creq, QJsonDocument(body).toJson());
                        connect(createReply, &QNetworkReply::finished, this,
                                [createReply, cb]() {
                                    createReply->deleteLater();
                                    if (createReply->error() != QNetworkReply::NoError) {
                                        cb({}, createReply->errorString());
                                        return;
                                    }
                                    const auto fid = QJsonDocument::fromJson(createReply->readAll())
                                                       .object().value("id").toString();
                                    if (fid.isEmpty()) {
                                        cb({}, QStringLiteral("folder create returned no id"));
                                        return;
                                    }
                                    cb(fid, {});
                                });
                    });
        },
        [cb](const QString &err) { cb({}, err); });
}

} // namespace iptvxs
