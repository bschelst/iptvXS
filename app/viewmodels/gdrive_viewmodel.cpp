#include "gdrive_viewmodel.h"

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
        connect(uploader_, &iptvxs::GDriveUploader::uploadStarted, this,
                [this](int64_t) {
                    uploading_ = true;
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
                    uploadProgress_ = 1.0;
                    uploadStatus_ = QStringLiteral("Upload complete");

                    if (recordingRepo_) {
                        auto rec = recordingRepo_->findById(recordingId);
                        if (rec) {
                            auto updated = *rec;
                            updated.status = QStringLiteral("uploaded");
                            updated.gdriveFileId = gdriveFileId;
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
                    uploadStatus_ = QStringLiteral("Upload failed: %1").arg(error);

                    if (recordingRepo_) {
                        recordingRepo_->updateStatus(recordingId,
                                                     QStringLiteral("failed"), error);
                    }

                    emit uploadingChanged();
                    emit uploadStatusChanged();
                    emit errorOccurred(error);
                });
    }
}

void GDriveViewModel::setRecordingRepository(iptvxs::RecordingRepository *repo) {
    recordingRepo_ = repo;
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
    uploader_->uploadFile(recordingId, rec->filePath, {});
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

void GDriveViewModel::setClientCredentials(const QString &clientId,
                                           const QString &clientSecret) {
    if (auth_) {
        auth_->setCredentials(clientId, clientSecret);
    }
}
