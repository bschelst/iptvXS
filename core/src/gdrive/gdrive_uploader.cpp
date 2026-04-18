#include "iptvxs/gdrive/gdrive_uploader.h"

#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>

namespace iptvxs {

GDriveUploader::GDriveUploader(GDriveAuth *auth, QObject *parent)
    : QObject(parent), auth_(auth) {}

void GDriveUploader::uploadFile(int64_t recordingId, const QString &filePath,
                                const QString &fileName, const QString &folderId) {
    if (activeUploads_.contains(recordingId)) {
        return;
    }

    if (!auth_ || !auth_->isAuthenticated()) {
        emit uploadFailed(recordingId, QStringLiteral("Not authenticated with Google Drive"));
        return;
    }

    auth_->refreshTokenIfNeeded();
    initiateResumableUpload(recordingId, filePath, fileName, folderId);
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

void GDriveUploader::initiateResumableUpload(int64_t recordingId, const QString &filePath,
                                             const QString &fileName, const QString &folderId) {
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        emit uploadFailed(recordingId, QStringLiteral("File not found: %1").arg(filePath));
        return;
    }

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
    request.setRawHeader("X-Upload-Content-Type", "video/x-matroska");
    request.setRawHeader("X-Upload-Content-Length",
                         QByteArray::number(fileInfo.size()));

    auto body = QJsonDocument(metadata).toJson(QJsonDocument::Compact);
    auto *reply = nam_.post(request, body);

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, recordingId, filePath]() {
                reply->deleteLater();

                if (reply->error() != QNetworkReply::NoError) {
                    emit uploadFailed(recordingId, reply->errorString());
                    return;
                }

                auto location = QString::fromUtf8(reply->rawHeader("Location"));
                if (location.isEmpty()) {
                    emit uploadFailed(recordingId,
                                      QStringLiteral("No upload URL in response"));
                    return;
                }

                emit uploadStarted(recordingId);
                uploadChunk(recordingId, location, filePath, 0);
            });
}

void GDriveUploader::uploadChunk(int64_t recordingId, const QString &uploadUrl,
                                 const QString &filePath, int64_t offset) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit uploadFailed(recordingId,
                          QStringLiteral("Cannot open file: %1").arg(filePath));
        return;
    }

    auto fileSize = file.size();
    file.seek(offset);

    auto chunkSize = qMin(kChunkSize, fileSize - offset);
    auto chunk = file.read(chunkSize);
    file.close();

    auto endByte = offset + chunk.size() - 1;

    QNetworkRequest request{QUrl{uploadUrl}};
    request.setRawHeader("Content-Range",
                         QStringLiteral("bytes %1-%2/%3")
                             .arg(offset)
                             .arg(endByte)
                             .arg(fileSize)
                             .toUtf8());
    request.setHeader(QNetworkRequest::ContentLengthHeader, chunk.size());
    request.setHeader(QNetworkRequest::ContentTypeHeader, "video/x-matroska");

    QNetworkReply *chunkReply = nam_.put(request, chunk);
    activeUploads_.insert(recordingId, chunkReply);

    connect(chunkReply, &QNetworkReply::uploadProgress, this,
            [this, recordingId, offset](int64_t bytesSent, int64_t /*bytesTotal*/) {
                emit uploadProgress(recordingId, offset + bytesSent, 0);
            });

    connect(chunkReply, &QNetworkReply::finished, this,
            [this, chunkReply, recordingId, uploadUrl, filePath, fileSize, endByte]() {
                activeUploads_.remove(recordingId);
                chunkReply->deleteLater();

                auto statusCode = chunkReply->attribute(
                    QNetworkRequest::HttpStatusCodeAttribute).toInt();

                if (statusCode == 200 || statusCode == 201) {
                    auto doc = QJsonDocument::fromJson(chunkReply->readAll());
                    auto fileId = doc.object().value(QStringLiteral("id")).toString();
                    emit uploadCompleted(recordingId, fileId);
                    return;
                }

                if (statusCode == 308) {
                    auto nextOffset = endByte + 1;
                    emit uploadProgress(recordingId, nextOffset, fileSize);
                    uploadChunk(recordingId, uploadUrl, filePath, nextOffset);
                    return;
                }

                if (chunkReply->error() != QNetworkReply::NoError) {
                    emit uploadFailed(recordingId, chunkReply->errorString());
                } else {
                    emit uploadFailed(recordingId,
                                      QStringLiteral("Unexpected status: %1").arg(statusCode));
                }
            });
}

} // namespace iptvxs
