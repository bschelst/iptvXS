#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/programme.h"

namespace iptvxs {

class ProgrammeRepository : public QObject {
    Q_OBJECT

public:
    explicit ProgrammeRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<Programme> findByChannel(const QString &epgChannelId,
                                     int64_t fromTime, int64_t toTime) const;
    QVector<Programme> findCurrent(const QString &epgChannelId) const;
    std::optional<Programme> findById(int64_t id) const;

    void batchUpsert(const QVector<Programme> &programmes);
    bool deleteOlderThan(int64_t timestamp);
    int count() const;

    static constexpr int kBatchSize = 500;

signals:
    void errorOccurred(const QString &message);

private:
    QSqlDatabase db_;
};

} // namespace iptvxs
