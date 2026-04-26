// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/gdrive/gdrive_uploader.h"

#include <QBuffer>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeType>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>

namespace iptvxs {

GDriveUploader::GDriveUploader(GDriveAuth *auth, QObject *parent)
    : QObject(parent), auth_(auth) {}

void GDriveUploader::withFreshToken(std::function<void()> action,
                                    std::function<void(const QString &)> onError) {
    if (!auth_ || !auth_->isAuthenticated()) {
        if (onError)
            onError(QStringLiteral("Not authenticated with Google Drive"));
        return;
    }

    if (!auth_->needsRefresh()) {
        action();
        return;
    }

    qInfo("GDrive: access token expired, refreshing before API call");
    auto conn = std::make_shared<QMetaObject::Connection>();
    auto errConn = std::make_shared<QMetaObject::Connection>();

    *conn = connect(auth_, &GDriveAuth::tokenRefreshed, this,
                    [action, conn, errConn, this]() {
                        disconnect(*conn);
                        disconnect(*errConn);
                        qInfo("GDrive: token refreshed, proceeding");
                        action();
                    });
    *errConn = connect(auth_, &GDriveAuth::authenticationFailed, this,
                       [onError, conn, errConn, this](const QString &error) {
                           disconnect(*conn);
                           disconnect(*errConn);
                           qWarning("GDrive: token refresh failed: %s", qPrintable(error));
                           if (onError) onError(error);
                       });

    auth_->refreshTokenIfNeeded();
}

QByteArray GDriveUploader::mimeForFile(const QString &filePath) {
    QMimeDatabase db;
    auto mime = db.mimeTypeForFile(filePath);
    auto name = mime.name().toUtf8();
    if (name == "application/octet-stream") {
        if (filePath.endsWith(QStringLiteral(".ts"), Qt::CaseInsensitive))
            return "video/mp2t";
        if (filePath.endsWith(QStringLiteral(".mkv"), Qt::CaseInsensitive))
            return "video/x-matroska";
        return "video/mp4";
    }
    return name;
}

void GDriveUploader::uploadFile(int64_t recordingId, const QString &filePath,
                                const QString &fileName, const QString &folderId) {
    if (activeUploads_.contains(recordingId)) {
        return;
    }

    withFreshToken(
        [this, recordingId, filePath, fileName, folderId]() {
            initiateResumableUpload(recordingId, filePath, fileName, folderId);
        },
        [this, recordingId](const QString &error) {
            emit uploadFailed(recordingId, error);
        });
}

void GDriveUploader::cancelUpload(int64_t recordingId) {
    auto *reply = activeUploads_.take(recordingId);
    if (reply) {
        reply->abort();
        reply->deleteLater();
    }
}

bool GDriveUploader::isUploading(int64_t recordingId) const {
    return activeUploads_.contains(recordingId);
}

void GDriveUploader::ensureFolder(const QString &folderName) {
    withFreshToken(
        [this, folderName]() {
            QUrl listUrl(QStringLiteral("https://www.googleapis.com/drive/v3/files"));
            QUrlQuery q;
            QString escaped = folderName;
            escaped.replace(QLatin1Char('\''), QStringLiteral("\\'"));
            q.addQueryItem(QStringLiteral("q"),
                           QStringLiteral("mimeType='application/vnd.google-apps.folder' and "
                                          "trashed=false and name='%1'")
                               .arg(escaped));
            q.addQueryItem(QStringLiteral("fields"), QStringLiteral("files(id,name)"));
            q.addQueryItem(QStringLiteral("pageSize"), QStringLiteral("1"));
            listUrl.setQuery(q);

            QNetworkRequest listReq(listUrl);
            listReq.setRawHeader("Authorization",
                                 QByteArray("Bearer ") + auth_->accessToken().toUtf8());
            auto *listReply = nam_.get(listReq);

            connect(listReply, &QNetworkReply::finished, this,
                    [this, listReply, folderName]() {
                        listReply->deleteLater();
                        if (listReply->error() != QNetworkReply::NoError) {
                            qWarning("GDrive ensureFolder list failed: %s",
                                     qPrintable(listReply->errorString()));
                            emit folderResolveFailed(folderName, listReply->errorString());
                            return;
                        }
                        auto body = listReply->readAll();
                        qInfo("GDrive ensureFolder search response: %s", body.constData());
                        auto obj = QJsonDocument::fromJson(body).object();
                        auto arr = obj.value(QStringLiteral("files")).toArray();
                        if (!arr.isEmpty()) {
                            const auto id =
                                arr.first().toObject().value(QStringLiteral("id")).toString();
                            qInfo("GDrive folder '%s' found: %s", qPrintable(folderName),
                                  qPrintable(id));
                            emit folderResolved(folderName, id);
                            return;
                        }

                        QJsonObject bodyObj;
                        bodyObj[QStringLiteral("name")] = folderName;
                        bodyObj[QStringLiteral("mimeType")] =
                            QStringLiteral("application/vnd.google-apps.folder");

                        QNetworkRequest createReq(QUrl(QStringLiteral(
                            "https://www.googleapis.com/drive/v3/files?fields=id,name")));
                        createReq.setRawHeader(
                            "Authorization",
                            QByteArray("Bearer ") + auth_->accessToken().toUtf8());
                        createReq.setHeader(QNetworkRequest::ContentTypeHeader,
                                            QStringLiteral("application/json"));

                        auto *createReply = nam_.post(
                            createReq,
                            QJsonDocument(bodyObj).toJson(QJsonDocument::Compact));
                        connect(createReply, &QNetworkReply::finished, this,
                                [this, createReply, folderName]() {
                                    createReply->deleteLater();
                                    if (createReply->error() != QNetworkReply::NoError) {
                                        qWarning("GDrive create folder failed: %s — %s",
                                                 qPrintable(createReply->errorString()),
                                                 createReply->readAll().constData());
                                        emit folderResolveFailed(folderName,
                                                                 createReply->errorString());
                                        return;
                                    }
                                    auto o =
                                        QJsonDocument::fromJson(createReply->readAll()).object();
                                    const auto id =
                                        o.value(QStringLiteral("id")).toString();
                                    if (id.isEmpty()) {
                                        emit folderResolveFailed(
                                            folderName,
                                            QStringLiteral(
                                                "Create folder response missing id"));
                                        return;
                                    }
                                    qInfo("GDrive folder '%s' created: %s",
                                          qPrintable(folderName), qPrintable(id));
                                    emit folderResolved(folderName, id);
                                });
                    });
        },
        [this, folderName](const QString &error) {
            emit folderResolveFailed(folderName, error);
        });
}

void GDriveUploader::initiateResumableUpload(int64_t recordingId, const QString &filePath,
                                             const QString &fileName, const QString &folderId) {
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        emit uploadFailed(recordingId, QStringLiteral("File not found: %1").arg(filePath));
        return;
    }

    auto contentType = mimeForFile(filePath);
    qInfo("GDrive upload: file=%s size=%lld mime=%s folder=%s",
          qPrintable(filePath), static_cast<long long>(fileInfo.size()),
          contentType.constData(), qPrintable(folderId));

    QJsonObject metadata;
    metadata.insert(QStringLiteral("name"), fileName.isEmpty() ? fileInfo.fileName() : fileName);

    if (!folderId.isEmpty()) {
        QJsonArray parents;
        parents.append(folderId);
        metadata.insert(QStringLiteral("parents"), parents);
    }

    QNetworkRequest request{QUrl{QString::fromUtf8(kUploadUrl)}};
    request.setRawHeader("Authorization",
                         QStringLiteral("Bearer %1").arg(auth_->accessToken()).toUtf8());
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/json; charset=UTF-8"));
    request.setRawHeader("X-Upload-Content-Type", contentType);
    request.setRawHeader("X-Upload-Content-Length",
                         QByteArray::number(fileInfo.size()));

    auto body = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
    auto *reply = nam_.post(request, body);

    auto declaredSize = fileInfo.size();
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, recordingId, filePath, contentType, declaredSize]() {
                reply->deleteLater();

                auto initStatus = reply->attribute(
                    QNetworkRequest::HttpStatusCodeAttribute).toInt();
                qInfo("GDrive resumable init response: http=%d error=%d",
                      initStatus, static_cast<int>(reply->error()));

                if (reply->error() != QNetworkReply::NoError) {
                    auto body = reply->readAll();
                    qWarning("GDrive resumable init failed: %s — %s",
                             qPrintable(reply->errorString()), body.constData());
                    emit uploadFailed(recordingId, reply->errorString());
                    return;
                }

                auto location = QString::fromUtf8(reply->rawHeader("Location")).trimmed();
                if (location.isEmpty()) {
                    emit uploadFailed(recordingId,
                                      QStringLiteral("No upload URL in response"));
                    return;
                }

                qInfo("GDrive upload session started for recording %lld, url=%s",
                      static_cast<long long>(recordingId), qPrintable(location));
                emit uploadSessionCreated(recordingId, location);
                emit uploadStarted(recordingId);
                uploadChunk(recordingId, location, filePath, 0, contentType, declaredSize);
            });
}

void GDriveUploader::uploadChunk(int64_t recordingId, const QString &uploadUrl,
                                 const QString &filePath, int64_t offset,
                                 const QByteArray &contentType, int64_t declaredSize) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit uploadFailed(recordingId,
                          QStringLiteral("Cannot open file: %1").arg(filePath));
        return;
    }

    auto fileSize = declaredSize > 0 ? declaredSize : file.size();
    file.seek(offset);

    auto chunkSize = qMin(kChunkSize, fileSize - offset);
    auto chunk = file.read(chunkSize);
    file.close();

    auto endByte = offset + chunk.size() - 1;

    QUrl url{uploadUrl.trimmed()};
    qInfo("GDrive chunk: offset=%lld size=%lld url_scheme=%s url_valid=%d url_len=%d",
          static_cast<long long>(offset), static_cast<long long>(chunkSize),
          qPrintable(url.scheme()), url.isValid(), uploadUrl.length());
    if (!url.isValid() || url.scheme().isEmpty()) {
        emit uploadFailed(recordingId,
                          QStringLiteral("Invalid upload URL: %1").arg(uploadUrl.left(100)));
        return;
    }
    QNetworkRequest request{url};
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setRawHeader("Authorization",
                         QStringLiteral("Bearer %1").arg(auth_->accessToken()).toUtf8());
    request.setRawHeader("Content-Range",
                         QStringLiteral("bytes %1-%2/%3")
                             .arg(offset)
                             .arg(endByte)
                             .arg(fileSize)
                             .toUtf8());
    request.setHeader(QNetworkRequest::ContentLengthHeader, chunk.size());
    request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);

    auto *buf = new QBuffer();
    buf->setData(chunk);
    buf->open(QIODevice::ReadOnly);
    QNetworkReply *chunkReply = nam_.sendCustomRequest(request, "PUT", buf);
    buf->setParent(chunkReply);
    activeUploads_.insert(recordingId, chunkReply);

    connect(chunkReply, &QNetworkReply::uploadProgress, this,
            [this, recordingId, offset](int64_t bytesSent, int64_t /*bytesTotal*/) {
                emit uploadProgress(recordingId, offset + bytesSent, 0);
            });

    connect(chunkReply, &QNetworkReply::finished, this,
            [this, chunkReply, recordingId, uploadUrl, filePath, fileSize, endByte,
             contentType, declaredSize]() {
                activeUploads_.remove(recordingId);
                chunkReply->deleteLater();

                auto statusCode = chunkReply->attribute(
                    QNetworkRequest::HttpStatusCodeAttribute).toInt();

                if (statusCode == 200 || statusCode == 201) {
                    auto doc = QJsonDocument::fromJson(chunkReply->readAll());
                    auto fileId = doc.object().value(QStringLiteral("id")).toString();
                    qInfo("GDrive upload complete: recording=%lld fileId=%s",
                          static_cast<long long>(recordingId), qPrintable(fileId));
                    emit uploadCompleted(recordingId, fileId);
                    return;
                }

                if (statusCode == 308) {
                    auto nextOffset = endByte + 1;
                    emit uploadProgress(recordingId, nextOffset, fileSize);
                    uploadChunk(recordingId, uploadUrl, filePath, nextOffset,
                                contentType, declaredSize);
                    return;
                }

                auto body = chunkReply->readAll();
                qWarning("GDrive chunk upload failed: status=%d error=%s body=%s",
                         statusCode, qPrintable(chunkReply->errorString()),
                         body.constData());
                if (chunkReply->error() != QNetworkReply::NoError) {
                    emit uploadFailed(recordingId, chunkReply->errorString());
                } else {
                    emit uploadFailed(recordingId,
                                      QStringLiteral("Unexpected status: %1").arg(statusCode));
                }
            });
}

void GDriveUploader::resumeUpload(int64_t recordingId, const QString &filePath,
                                  const QString &uploadUrl) {
    if (activeUploads_.contains(recordingId)) return;
    if (uploadUrl.isEmpty() || filePath.isEmpty()) return;

    QFileInfo fi(filePath);
    if (!fi.exists()) {
        emit uploadFailed(recordingId, QStringLiteral("File not found: %1").arg(filePath));
        return;
    }

    auto contentType = mimeForFile(filePath);
    auto fileSize = fi.size();

    qInfo("GDrive resuming upload: recording=%lld file=%s size=%lld",
          static_cast<long long>(recordingId), qPrintable(filePath),
          static_cast<long long>(fileSize));

    withFreshToken(
        [this, recordingId, filePath, uploadUrl, contentType, fileSize]() {
            QNetworkRequest request{QUrl{uploadUrl}};
            request.setRawHeader("Content-Range",
                                 QStringLiteral("bytes */%1").arg(fileSize).toUtf8());
            request.setHeader(QNetworkRequest::ContentLengthHeader, 0);
            request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);

            auto *reply = nam_.put(request, QByteArray());
            connect(reply, &QNetworkReply::finished, this,
                    [this, reply, recordingId, filePath, uploadUrl, contentType,
                     fileSize]() {
                        reply->deleteLater();
                        auto status = reply->attribute(
                            QNetworkRequest::HttpStatusCodeAttribute).toInt();

                        if (status == 200 || status == 201) {
                            auto doc = QJsonDocument::fromJson(reply->readAll());
                            auto fileId =
                                doc.object().value(QStringLiteral("id")).toString();
                            qInfo("GDrive resume: already complete, fileId=%s",
                                  qPrintable(fileId));
                            emit uploadCompleted(recordingId, fileId);
                            return;
                        }

                        if (status == 308) {
                            auto rangeHeader =
                                QString::fromUtf8(reply->rawHeader("Range"));
                            int64_t nextOffset = 0;
                            if (rangeHeader.startsWith(QStringLiteral("bytes=0-"))) {
                                nextOffset =
                                    rangeHeader.mid(8).toLongLong() + 1;
                            }
                            qInfo("GDrive resume: continuing from byte %lld/%lld",
                                  static_cast<long long>(nextOffset),
                                  static_cast<long long>(fileSize));
                            emit uploadStarted(recordingId);
                            emit uploadProgress(recordingId, nextOffset, fileSize);
                            uploadChunk(recordingId, uploadUrl, filePath,
                                        nextOffset, contentType);
                            return;
                        }

                        if (status == 404 || status == 410) {
                            qInfo("GDrive resume: session expired, starting fresh");
                            emit uploadFailed(
                                recordingId,
                                QStringLiteral("Upload session expired — please retry"));
                            return;
                        }

                        qWarning("GDrive resume probe failed: status=%d error=%s",
                                 status, qPrintable(reply->errorString()));
                        emit uploadFailed(recordingId, reply->errorString());
                    });
        },
        [this, recordingId](const QString &error) {
            emit uploadFailed(recordingId, error);
        });
}

} // namespace iptvxs
