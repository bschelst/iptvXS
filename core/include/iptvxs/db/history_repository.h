#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <cstdint>

namespace iptvxs {

struct HistoryEntry {
    int64_t id{0};
    int64_t channelId{0};
    QString channelName;
    QString channelLogo;
    QString channelType;
    QString streamUrl;
    int64_t watchedAt{0};
    int durationSecs{0};
};

class HistoryRepository : public QObject {
    Q_OBJECT

public:
    explicit HistoryRepository(QSqlDatabase db, QObject *parent = nullptr);

    void addEntry(int64_t channelId, int durationSecs = 0);
    void addEntry(const QString &name, const QString &logo, const QString &type,
                  const QString &streamUrl = {}, int durationSecs = 0);
    QVector<HistoryEntry> findRecent(int limit = 100, int offset = 0) const;
    int count() const;
    void removeEntry(int64_t id);
    void clear();
    bool hasWatched(int64_t channelId) const;

private:
    QSqlDatabase db_;
};

} // namespace iptvxs
