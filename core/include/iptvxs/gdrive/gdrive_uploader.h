#pragma once

#include <functional>

#include <QFile>
#include <QMimeDatabase>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>

#include "iptvxs/gdrive/gdrive_auth.h"

namespace iptvxs {

class GDriveUploader : public QObject {
    Q_OBJECT

public:
    explicit GDriveUploader(GDriveAuth *auth, QObject *parent = nullptr);

    void uploadFile(int64_t recordingId, const QString &filePath,
                    const QString &fileName, const QString &folderId = {});

    void cancelUpload(int64_t recordingId);
    bool isUploading(int64_t recordingId) const;

    void resumeUpload(int64_t recordingId, const QString &filePath,
                      const QString &uploadUrl);

    // Look up a folder by name under My Drive root; create it if missing.
    // Emits folderResolved(folderId) on success or uploadFailed(-1, error).
    void ensureFolder(const QString &folderName);

signals:
    void uploadStarted(int64_t recordingId);
    void uploadProgress(int64_t recordingId, int64_t bytesSent, int64_t bytesTotal);
    void uploadSessionCreated(int64_t recordingId, const QString &uploadUrl);
    void uploadCompleted(int64_t recordingId, const QString &gdriveFileId);
    void uploadFailed(int64_t recordingId, const QString &error);
    void folderResolved(const QString &folderName, const QString &folderId);
    void folderResolveFailed(const QString &folderName, const QString &error);

private:
    void initiateResumableUpload(int64_t recordingId, const QString &filePath,
                                 const QString &fileName, const QString &folderId);
    void uploadChunk(int64_t recordingId, const QString &uploadUrl,
                     const QString &filePath, int64_t offset,
                     const QByteArray &contentType, int64_t declaredSize = 0);

    void withFreshToken(std::function<void()> action,
                        std::function<void(const QString &)> onError = {});
    static QByteArray mimeForFile(const QString &filePath);

    GDriveAuth *auth_;
    QNetworkAccessManager nam_;
    QMimeDatabase mimeDb_;
    QHash<int64_t, QNetworkReply *> activeUploads_;

    static constexpr int64_t kChunkSize = 10 * 1024 * 1024; // 10 MB
    static constexpr const char *kUploadUrl =
        "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable";
};

} // namespace iptvxs
