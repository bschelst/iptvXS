// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <functional>

#include <QByteArray>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>

#include "iptvxs/gdrive/gdrive_auth.h"

namespace iptvxs {

// Small-file Drive operations used by SyncService. Distinct from
// GDriveUploader (which is tuned for resumable recording uploads):
//   - find file by name under a folder
//   - download a file's media content into memory
//   - simple multipart upload of in-memory bytes (creates or updates)
// Caller is responsible for orchestrating the auth token refresh via
// GDriveAuth before calling these helpers — they reuse the cached token.
class GDriveSyncIO : public QObject {
    Q_OBJECT

public:
    explicit GDriveSyncIO(GDriveAuth *auth, QObject *parent = nullptr);

    using FindCallback = std::function<void(const QString &fileId, const QString &error)>;
    using DownloadCallback = std::function<void(const QByteArray &data, const QString &error)>;
    using UploadCallback = std::function<void(const QString &fileId, const QString &error)>;
    using FolderCallback = std::function<void(const QString &folderId, const QString &error)>;

    // List a single file matching the name under the given folder. fileId is
    // empty (no error) when nothing matches.
    void findFile(const QString &folderId, const QString &fileName, FindCallback cb);

    // GET file media. Returns the raw bytes.
    void downloadFile(const QString &fileId, DownloadCallback cb);

    // Upload bytes; if existingFileId is empty creates a new file under
    // folderId, otherwise PATCHes the existing one. Calls cb with the
    // resulting fileId.
    void uploadBytes(const QByteArray &data, const QString &fileName,
                     const QByteArray &mimeType, const QString &folderId,
                     const QString &existingFileId, UploadCallback cb);

    // Look up a folder by name or path (e.g. "iptvXS/sync"). For nested paths,
    // each segment is resolved (or created) under the previous segment's id;
    // the leaf segment's id is returned via cb. Top-level segment lives at My
    // Drive root.
    void ensureFolder(const QString &folderPath, FolderCallback cb);

private:
    void withToken(std::function<void(const QString &token)> action,
                   std::function<void(const QString &)> onError);
    void ensureFolderInParent(const QString &folderName, const QString &parentId,
                              FolderCallback cb);

    GDriveAuth *auth_;
    QNetworkAccessManager nam_;
};

} // namespace iptvxs
