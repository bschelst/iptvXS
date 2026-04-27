// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QJsonObject>
#include <QObject>
#include <QSqlDatabase>
#include <optional>

namespace iptvxs {

class SeriesCacheRepository : public QObject {
    Q_OBJECT

public:
    explicit SeriesCacheRepository(QSqlDatabase db, QObject *parent = nullptr);

    std::optional<QJsonObject> find(int64_t serverId, const QString &seriesId) const;
    void store(int64_t serverId, const QString &seriesId, const QString &seriesName,
               const QString &logoUrl, const QJsonObject &data);
    void removeByServer(int64_t serverId);
    void removeAll();

signals:
    void errorOccurred(const QString &message);

private:
    QSqlDatabase db_;
};

} // namespace iptvxs
