#include "iptvxs/api/xtream_response.h"

#include <QJsonArray>

namespace iptvxs {

XtreamUserInfo XtreamUserInfo::fromJson(const QJsonObject &obj) {
    XtreamUserInfo info;
    info.username = obj.value("username").toString();
    info.password = obj.value("password").toString();
    info.status = obj.value("status").toString();
    info.expDate = obj.value("exp_date").toVariant().toLongLong();
    info.isTrial = obj.value("is_trial").toVariant().toBool();
    info.activeCons = obj.value("active_cons").toVariant().toInt();
    info.createdAt = obj.value("created_at").toVariant().toLongLong();
    info.maxConnections = obj.value("max_connections").toVariant().toInt();

    const auto formats = obj.value("allowed_output_formats").toArray();
    for (const auto &f : formats) {
        info.allowedOutputFormats.append(f.toString());
    }
    return info;
}

XtreamServerInfo XtreamServerInfo::fromJson(const QJsonObject &obj) {
    XtreamServerInfo info;
    info.url = obj.value("url").toString();
    info.port = obj.value("port").toVariant().toInt();
    info.httpsPort = obj.value("https_port").toVariant().toInt();
    info.serverProtocol = obj.value("server_protocol").toString();
    info.timezone = obj.value("timezone").toString();
    info.timestampNow = obj.value("timestamp_now").toVariant().toLongLong();

    const auto userObj = obj.value("user_info").toObject();
    info.userInfo = XtreamUserInfo::fromJson(userObj);
    return info;
}

XtreamCategory XtreamCategory::fromJson(const QJsonObject &obj) {
    XtreamCategory cat;
    cat.categoryId = obj.value("category_id").toVariant().toString();
    cat.categoryName = obj.value("category_name").toString();
    cat.parentId = obj.value("parent_id").toVariant().toInt();
    return cat;
}

XtreamStream XtreamStream::fromJson(const QJsonObject &obj) {
    XtreamStream stream;
    stream.num = obj.value("num").toVariant().toLongLong();
    stream.name = obj.value("name").toString();
    stream.streamType = obj.value("stream_type").toString();
    stream.streamId = obj.value("stream_id").toVariant().toString();
    stream.streamIcon = obj.value("stream_icon").toString();
    stream.epgChannelId = obj.value("epg_channel_id").toString();
    stream.added = obj.value("added").toVariant().toLongLong();
    stream.categoryId = obj.value("category_id").toVariant().toString();
    stream.customSid = obj.value("custom_sid").toString();
    stream.tvArchive = obj.value("tv_archive").toVariant().toInt();
    stream.directSource = obj.value("direct_source").toString();
    stream.tvArchiveDuration = obj.value("tv_archive_duration").toVariant().toInt();
    return stream;
}

} // namespace iptvxs
