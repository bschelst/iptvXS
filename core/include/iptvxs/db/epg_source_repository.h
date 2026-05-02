// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/epg_source.h"

namespace iptvxs {

class EpgSourceRepository : public QObject {
    Q_OBJECT

public:
    explicit EpgSourceRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<EpgSource> findAll() const;
    std::optional<EpgSource> findById(int64_t id) const;
    int64_t create(const EpgSource &source);
    bool update(const EpgSource &source);
    bool remove(int64_t id);
    bool updateLastSynced(int64_t id, int64_t timestamp);
    bool setEnabled(int64_t id, bool enabled);
    bool setPrimary(int64_t id);
    int count() const;

signals:
    void errorOccurred(const QString &message);

private:
    static EpgSource fromQuery(const QSqlQuery &query);
    QSqlDatabase db_;
};

} // namespace iptvxs
