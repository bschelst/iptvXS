#pragma once

#include <QObject>
#include <QQmlEngine>

#include "iptvxs/db/recording_repository.h"
#include "iptvxs/gdrive/gdrive_auth.h"
#include "iptvxs/gdrive/gdrive_uploader.h"

class GDriveViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authStateChanged)
    Q_PROPERTY(bool uploading READ uploading NOTIFY uploadingChanged)
    Q_PROPERTY(double uploadProgress READ uploadProgress NOTIFY uploadProgressChanged)
    Q_PROPERTY(QString uploadStatus READ uploadStatus NOTIFY uploadStatusChanged)

public:
    explicit GDriveViewModel(QObject *parent = nullptr);

    void setAuth(iptvxs::GDriveAuth *auth);
    void setUploader(iptvxs::GDriveUploader *uploader);
    void setRecordingRepository(iptvxs::RecordingRepository *repo);

    bool authenticated() const;
    bool uploading() const;
    double uploadProgress() const;
    QString uploadStatus() const;

    Q_INVOKABLE void login();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void uploadRecording(int64_t recordingId);
    Q_INVOKABLE void cancelUpload(int64_t recordingId);
    Q_INVOKABLE void setClientCredentials(const QString &clientId, const QString &clientSecret);

signals:
    void authStateChanged();
    void uploadingChanged();
    void uploadProgressChanged();
    void uploadStatusChanged();
    void errorOccurred(const QString &message);

private:
    iptvxs::GDriveAuth *auth_{nullptr};
    iptvxs::GDriveUploader *uploader_{nullptr};
    iptvxs::RecordingRepository *recordingRepo_{nullptr};
    bool uploading_{false};
    double uploadProgress_{0.0};
    QString uploadStatus_;
};
