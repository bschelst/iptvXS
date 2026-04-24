#include "gdrive_viewmodel.h"

#include <QFile>
#include <QFileInfo>

GDriveViewModel::GDriveViewModel(QObject *parent) : QObject(parent) {}

void GDriveViewModel::setAuth(iptvxs::GDriveAuth *auth) {
    auth_ = auth;
    if (auth_) {
        connect(auth_, &iptvxs::GDriveAuth::authenticated, this, [this]() {
            emit authStateChanged();
            uploadStatus_ = QStringLiteral("Connected to Google Drive");
            emit uploadStatusChanged();
        });
        connect(auth_, &iptvxs::GDriveAuth::authenticationFailed, this,
                [this](const QString &error) {
                    emit errorOccurred(error);
                    uploadStatus_ = QStringLiteral("Authentication failed");
                    emit uploadStatusChanged();
                });
        connect(auth_, &iptvxs::GDriveAuth::loggedOut, this, [this]() {
            emit authStateChanged();
            uploadStatus_.clear();
            emit uploadStatusChanged();
        });
    }
}

void GDriveViewModel::setUploader(iptvxs::GDriveUploader *uploader) {
    uploader_ = uploader;
    if (uploader_) {
        connect(uploader_, &iptvxs::GDriveUploader::uploadSessionCreated, this,
                [this](int64_t recordingId, const QString &uploadUrl) {
                    if (recordingRepo_) {
                        recordingRepo_->updateUploadUrl(recordingId, uploadUrl);
                    }
                });

        connect(uploader_, &iptvxs::GDriveUploader::uploadStarted, this,
                [this](int64_t recordingId) {
                    uploading_ = true;
                    uploadingRecordingId_ = recordingId;
                    uploadProgress_ = 0.0;
                    uploadStatus_ = QStringLiteral("Uploading...");
                    emit uploadingChanged();
                    emit uploadProgressChanged();
                    emit uploadStatusChanged();
                });

        connect(uploader_, &iptvxs::GDriveUploader::uploadProgress, this,
                [this](int64_t, int64_t bytesSent, int64_t bytesTotal) {
                    if (bytesTotal > 0) {
                        uploadProgress_ = static_cast<double>(bytesSent) /
                                          static_cast<double>(bytesTotal);
                    }
                    emit uploadProgressChanged();
                });

        connect(uploader_, &iptvxs::GDriveUploader::uploadCompleted, this,
                [this](int64_t recordingId, const QString &gdriveFileId) {
                    uploading_ = false;
                    uploadingRecordingId_ = 0;
                    uploadProgress_ = 1.0;
                    uploadStatus_ = QStringLiteral("Upload complete");

                    if (recordingRepo_) {
                        auto rec = recordingRepo_->findById(recordingId);
                        if (rec) {
                            auto updated = *rec;
                            updated.status = QStringLiteral("uploaded");
                            updated.gdriveFileId = gdriveFileId;
                            updated.gdriveUploadUrl.clear();

                            if (deleteLocalAfterUpload_ && !rec->filePath.isEmpty()
                                && !rec->pinned) {
                                QFileInfo fi(rec->filePath);
                                if (fi.exists() && fi.isFile() && !fi.isSymLink()
                                    && fi.absoluteFilePath().contains(
                                           QStringLiteral("iptvxs"))) {
                                    QFile::remove(fi.absoluteFilePath());
                                    qInfo("Deleted local file after GDrive upload: %s",
                                          qPrintable(fi.absoluteFilePath()));
                                    updated.filePath.clear();
                                }
                            }

                            recordingRepo_->update(updated);
                        }
                    }

                    emit uploadingChanged();
                    emit uploadProgressChanged();
                    emit uploadStatusChanged();
                });

        connect(uploader_, &iptvxs::GDriveUploader::uploadFailed, this,
                [this](int64_t recordingId, const QString &error) {
                    uploading_ = false;
                    uploadingRecordingId_ = 0;
                    uploadStatus_ = QStringLiteral("Upload failed: %1").arg(error);

                    if (recordingRepo_) {
                        recordingRepo_->updateStatus(recordingId,
                                                     QStringLiteral("failed"), error);
                    }

                    emit uploadingChanged();
                    emit uploadStatusChanged();
                    emit errorOccurred(error);
                });

        connect(uploader_, &iptvxs::GDriveUploader::folderResolved, this,
                [this](const QString &name, const QString &id) {
                    if (settingsRepo_) {
                        settingsRepo_->set(QStringLiteral("gdrive_folder_id"), id);
                        settingsRepo_->set(QStringLiteral("gdrive_folder_name"), name);
                    }
                    uploadStatus_ =
                        QStringLiteral("Using Google Drive folder \"%1\"").arg(name);
                    emit uploadStatusChanged();

                    if (pendingUploadId_ > 0 && uploader_ && recordingRepo_) {
                        auto id64 = pendingUploadId_;
                        pendingUploadId_ = 0;
                        auto rec = recordingRepo_->findById(id64);
                        if (rec) {
                            QFileInfo fi(rec->filePath);
                            uploader_->uploadFile(id64, rec->filePath, fi.fileName(), id);
                        }
                    }
                });

        connect(uploader_, &iptvxs::GDriveUploader::folderResolveFailed, this,
                [this](const QString &name, const QString &error) {
                    uploading_ = false;
                    uploadStatus_ =
                        QStringLiteral("Folder \"%1\" failed: %2").arg(name, error);
                    emit uploadingChanged();
                    emit uploadStatusChanged();
                    emit errorOccurred(uploadStatus_);
                    pendingUploadId_ = 0;
                });
    }
}

void GDriveViewModel::setRecordingRepository(iptvxs::RecordingRepository *repo) {
    recordingRepo_ = repo;
}

void GDriveViewModel::setSettingsRepository(iptvxs::SettingsRepository *repo) {
    settingsRepo_ = repo;
}

QString GDriveViewModel::folderName() const {
    if (settingsRepo_) {
        auto stored = settingsRepo_->getString(QStringLiteral("gdrive_folder_name"));
        if (!stored.isEmpty()) return stored;
    }
    return QStringLiteral("iptvXS-recordings");
}

void GDriveViewModel::setFolderName(const QString &name) {
    if (!settingsRepo_) return;
    auto trimmed = name.trimmed();
    if (trimmed.isEmpty()) return;
    if (folderName() == trimmed) return;
    settingsRepo_->set(QStringLiteral("gdrive_folder_name"), trimmed);
    // Invalidate cached folder id — next upload (or resolveFolderNow) will resolve afresh.
    settingsRepo_->remove(QStringLiteral("gdrive_folder_id"));
    emit folderNameChanged();
}

void GDriveViewModel::resolveFolderNow() {
    if (!uploader_) return;
    uploader_->ensureFolder(folderName());
}

bool GDriveViewModel::authenticated() const {
    return auth_ && auth_->isAuthenticated();
}

bool GDriveViewModel::uploading() const {
    return uploading_;
}

double GDriveViewModel::uploadProgress() const {
    return uploadProgress_;
}

QString GDriveViewModel::uploadStatus() const {
    return uploadStatus_;
}

void GDriveViewModel::login() {
    if (auth_) {
        auth_->startAuthFlow();
    }
}

void GDriveViewModel::logout() {
    if (auth_) {
        auth_->logout();
    }
}

void GDriveViewModel::uploadRecording(int64_t recordingId) {
    if (!uploader_ || !recordingRepo_) {
        return;
    }

    auto rec = recordingRepo_->findById(recordingId);
    if (!rec) {
        emit errorOccurred(QStringLiteral("Recording not found"));
        return;
    }

    if (rec->filePath.isEmpty()) {
        emit errorOccurred(QStringLiteral("No file to upload"));
        return;
    }

    recordingRepo_->updateStatus(recordingId, QStringLiteral("uploading"));

    // Use cached folder id if we have one; otherwise resolve (create if needed)
    // and kick off the upload from folderResolved.
    QString cachedId;
    if (settingsRepo_) {
        cachedId = settingsRepo_->getString(QStringLiteral("gdrive_folder_id"));
    }
    QFileInfo fi(rec->filePath);
    if (!cachedId.isEmpty()) {
        uploader_->uploadFile(recordingId, rec->filePath, fi.fileName(), cachedId);
    } else {
        pendingUploadId_ = recordingId;
        uploadStatus_ = QStringLiteral("Resolving Google Drive folder...");
        emit uploadStatusChanged();
        uploader_->ensureFolder(folderName());
    }
}

void GDriveViewModel::cancelUpload(int64_t recordingId) {
    if (uploader_) {
        uploader_->cancelUpload(recordingId);
        uploading_ = false;
        uploadStatus_ = QStringLiteral("Upload cancelled");
        emit uploadingChanged();
        emit uploadStatusChanged();

        if (recordingRepo_) {
            recordingRepo_->updateStatus(recordingId, QStringLiteral("completed"));
        }
    }
}

int64_t GDriveViewModel::uploadingRecordingId() const {
    return uploadingRecordingId_;
}

void GDriveViewModel::resumePendingUploads() {
    if (!uploader_ || !recordingRepo_ || !auth_ || !auth_->isAuthenticated())
        return;

    auto uploading = recordingRepo_->findByStatus(QStringLiteral("uploading"));
    for (const auto &rec : uploading) {
        if (!rec.gdriveUploadUrl.isEmpty() && !rec.filePath.isEmpty()) {
            qInfo("Resuming GDrive upload for recording %lld",
                  static_cast<long long>(rec.id));
            uploader_->resumeUpload(rec.id, rec.filePath, rec.gdriveUploadUrl);
        } else {
            qWarning("Cannot resume recording %lld: missing upload URL or file path",
                     static_cast<long long>(rec.id));
            recordingRepo_->updateStatus(rec.id, QStringLiteral("completed"));
        }
    }
}

void GDriveViewModel::setClientCredentials(const QString &clientId,
                                           const QString &clientSecret) {
    Q_UNUSED(clientSecret);  // PKCE: secret is no longer required.
    if (auth_) {
        auth_->setClientId(clientId);
    }
    emit clientIdChanged(clientId);
}
