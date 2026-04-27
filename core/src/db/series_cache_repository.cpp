// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/series_cache_repository.h"

#include <QJsonDocument>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

SeriesCacheRepository::SeriesCacheRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

std::optional<QJsonObject> SeriesCacheRepository::find(int64_t serverId,
                                                        const QString &seriesId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT data FROM series_info_cache WHERE server_id = ? AND series_id = ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(seriesId);

    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }

    auto doc = QJsonDocument::fromJson(query.value(0).toString().toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        return std::nullopt;
    }
    return doc.object();
}

void SeriesCacheRepository::store(int64_t serverId, const QString &seriesId,
                                   const QString &seriesName, const QString &logoUrl,
                                   const QJsonObject &data) {
    QSqlQuery query(db_);
    query.prepare(
        "INSERT INTO series_info_cache (server_id, series_id, series_name, logo_url, data, updated_at) "
        "VALUES (?, ?, ?, ?, ?, strftime('%s', 'now')) "
        "ON CONFLICT(server_id, series_id) DO UPDATE SET "
        "series_name = excluded.series_name, "
        "logo_url = excluded.logo_url, "
        "data = excluded.data, "
        "updated_at = strftime('%s', 'now')");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(seriesId);
    query.addBindValue(seriesName);
    query.addBindValue(logoUrl);
    query.addBindValue(QString::fromUtf8(QJsonDocument(data).toJson(QJsonDocument::Compact)));

    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to store series cache: %1")
                               .arg(query.lastError().text()));
    }
}

void SeriesCacheRepository::removeByServer(int64_t serverId) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM series_info_cache WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to clear series cache for server: %1")
                               .arg(query.lastError().text()));
    }
}

void SeriesCacheRepository::removeAll() {
    QSqlQuery query(db_);
    if (!query.exec("DELETE FROM series_info_cache")) {
        emit errorOccurred(QStringLiteral("Failed to clear all series cache: %1")
                               .arg(query.lastError().text()));
    }
}

} // namespace iptvxs
