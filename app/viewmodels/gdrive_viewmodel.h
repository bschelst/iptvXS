#pragma once

#include <QObject>
#include <QQmlEngine>

#include "iptvxs/db/recording_repository.h"
#include "iptvxs/db/settings_repository.h"
#include "iptvxs/gdrive/gdrive_auth.h"
#include "iptvxs/gdrive/gdrive_uploader.h"

class GDriveViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authStateChanged)
    Q_PROPERTY(bool uploading READ uploading NOTIFY uploadingChanged)
    Q_PROPERTY(double uploadProgress READ uploadProgress NOTIFY uploadProgressChanged)
    Q_PROPERTY(QString uploadStatus READ uploadStatus NOTIFY uploadStatusChanged)
    Q_PROPERTY(QString folderName READ folderName WRITE setFolderName NOTIFY folderNameChanged)

public:
    explicit GDriveViewModel(QObject *parent = nullptr);

    void setAuth(iptvxs::GDriveAuth *auth);
    void setUploader(iptvxs::GDriveUploader *uploader);
    void setRecordingRepository(iptvxs::RecordingRepository *repo);
    void setSettingsRepository(iptvxs::SettingsRepository *repo);

    bool authenticated() const;
    bool uploading() const;
    double uploadProgress() const;
    QString uploadStatus() const;
    QString folderName() const;
    void setFolderName(const QString &name);

    Q_INVOKABLE void login();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void uploadRecording(int64_t recordingId);
    Q_INVOKABLE void cancelUpload(int64_t recordingId);
    Q_INVOKABLE void setClientCredentials(const QString &clientId, const QString &clientSecret);
    Q_INVOKABLE void resolveFolderNow();
    Q_INVOKABLE void resumePendingUploads();

    int64_t uploadingRecordingId() const;

signals:
    void authStateChanged();
    void uploadingChanged();
    void uploadProgressChanged();
    void uploadStatusChanged();
    void errorOccurred(const QString &message);
    void clientIdChanged(const QString &clientId);
    void folderNameChanged();

private:
    iptvxs::GDriveAuth *auth_{nullptr};
    iptvxs::GDriveUploader *uploader_{nullptr};
    iptvxs::RecordingRepository *recordingRepo_{nullptr};
    iptvxs::SettingsRepository *settingsRepo_{nullptr};
    bool uploading_{false};
    double uploadProgress_{0.0};
    QString uploadStatus_;
    int64_t pendingUploadId_{0};
    int64_t uploadingRecordingId_{0};
    bool deleteLocalAfterUpload_{false};

public:
    void setDeleteLocalAfterUpload(bool enabled) { deleteLocalAfterUpload_ = enabled; }
};
