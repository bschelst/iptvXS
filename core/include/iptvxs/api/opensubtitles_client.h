#pragma once

#include <QObject>
#include <QString>
#include <QVector>

namespace iptvxs {

class HttpClient;

struct SubtitleResult {
    QString id;
    QString fileName;
    QString language;
    int downloadCount{0};
    QString downloadUrl;
    QString fileId;
};

class OpenSubtitlesClient : public QObject {
    Q_OBJECT

public:
    explicit OpenSubtitlesClient(HttpClient *http, QObject *parent = nullptr);

    void setApiKey(const QString &apiKey);
    void searchByName(const QString &query, const QString &language = {});
    void downloadSubtitle(const QString &fileId, const QString &outputPath);

signals:
    void searchCompleted(const QVector<iptvxs::SubtitleResult> &results);
    void downloadCompleted(const QString &filePath);
    void errorOccurred(const QString &message);

private:
    void doSearch(const QString &token, const QString &query,
                  const QString &langCode);

    HttpClient *http_;
};

} // namespace iptvxs
