// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/player/mpv_player.h"

#include <QDebug>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QTimer>

#include <mpv/client.h>

namespace iptvxs {

namespace {

QString sanitizeUrl(const QString &url) {
    static const QRegularExpression re(
        QStringLiteral("((?:username|password|user|pass)=)[^&]*"),
        QRegularExpression::CaseInsensitiveOption);
    QString masked = url;
    masked.replace(re, QStringLiteral("\\1***"));
    return masked;
}

void wakeupCallback(void *ctx) {
    auto *player = static_cast<MpvPlayer *>(ctx);
    QMetaObject::invokeMethod(player, "processEvents", Qt::QueuedConnection);
}

int mpvSetOptionString(mpv_handle *h, const char *name, const char *value) {
    return mpv_set_option_string(h, name, value);
}

} // namespace

MpvPlayer::MpvPlayer(QObject *parent) : QObject(parent) {}

MpvPlayer::~MpvPlayer() {
    if (mpv_) {
        mpv_terminate_destroy(mpv_);
    }
}

bool MpvPlayer::initialize() {
    mpv_ = mpv_create();
    if (!mpv_) {
        emit errorOccurred(QStringLiteral("Failed to create mpv context"));
        return false;
    }

    mpvSetOptionString(mpv_, "vo", "libmpv");
    mpvSetOptionString(mpv_, "hwdec", "auto-safe");
    mpvSetOptionString(mpv_, "keep-open", "yes");
    mpvSetOptionString(mpv_, "idle", "yes");
    mpvSetOptionString(mpv_, "input-default-bindings", "no");
    mpvSetOptionString(mpv_, "input-vo-keyboard", "no");
    mpvSetOptionString(mpv_, "osc", "no");
    mpvSetOptionString(mpv_, "ytdl", "no");
    mpvSetOptionString(mpv_, "cache", "yes");
    mpvSetOptionString(mpv_, "demuxer-max-bytes", "50MiB");
    mpvSetOptionString(mpv_, "demuxer-readahead-secs", "60");
    mpvSetOptionString(mpv_, "stream-lavf-o-append", "reconnect=1");
    mpvSetOptionString(mpv_, "stream-lavf-o-append", "reconnect_streamed=1");
    mpvSetOptionString(mpv_, "stream-lavf-o-append", "reconnect_on_network_error=1");
    mpvSetOptionString(mpv_, "stream-lavf-o-append", "reconnect_delay_max=5");

    if (mpv_initialize(mpv_) < 0) {
        emit errorOccurred(QStringLiteral("Failed to initialize mpv"));
        mpv_terminate_destroy(mpv_);
        mpv_ = nullptr;
        return false;
    }

    mpv_observe_property(mpv_, 0, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(mpv_, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv_, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv_, 0, "volume", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv_, 0, "mute", MPV_FORMAT_FLAG);
    mpv_observe_property(mpv_, 0, "idle-active", MPV_FORMAT_FLAG);
    mpv_observe_property(mpv_, 0, "demuxer-cache-duration", MPV_FORMAT_DOUBLE);

    mpv_request_log_messages(mpv_, "warn");
    mpv_set_wakeup_callback(mpv_, wakeupCallback, this);

    return true;
}

void MpvPlayer::setHttpHeaders(const QStringList &headers) {
    if (!mpv_) return;
    QByteArrayList raw;
    for (const auto &h : headers) raw.append(h.toUtf8());
    std::vector<const char *> ptrs;
    for (const auto &r : raw) ptrs.push_back(r.constData());
    ptrs.push_back(nullptr);
    mpv_node_list list{};
    list.num = static_cast<int>(headers.size());
    std::vector<mpv_node> nodes(list.num);
    for (int i = 0; i < list.num; ++i) {
        nodes[i].u.string = const_cast<char *>(ptrs[static_cast<size_t>(i)]);
        nodes[i].format = MPV_FORMAT_STRING;
    }
    list.values = nodes.data();
    mpv_node node{};
    node.u.list = &list;
    node.format = MPV_FORMAT_NODE_ARRAY;
    mpv_set_property(mpv_, "http-header-fields", MPV_FORMAT_NODE, &node);
}

void MpvPlayer::clearHttpHeaders() {
    if (!mpv_) return;
    mpv_node_list list{};
    list.num = 0;
    list.values = nullptr;
    mpv_node node{};
    node.u.list = &list;
    node.format = MPV_FORMAT_NODE_ARRAY;
    mpv_set_property(mpv_, "http-header-fields", MPV_FORMAT_NODE, &node);
}

void MpvPlayer::play(const QString &url) {
    if (!mpv_) return;

    qInfo("MpvPlayer: loading %s", qPrintable(sanitizeUrl(url)));

    auto urlStr = url.toUtf8();
    const char *args[] = {"loadfile", urlStr.constData(), nullptr};
    mpv_command_async(mpv_, 0, args);

    state_ = State::Loading;
    emit stateChanged(state_);
}

void MpvPlayer::pause() {
    if (!mpv_ || state_ != State::Playing) return;
    int flag = 1;
    mpv_set_property(mpv_, "pause", MPV_FORMAT_FLAG, &flag);
}

void MpvPlayer::resume() {
    if (!mpv_ || state_ != State::Paused) return;
    int flag = 0;
    mpv_set_property(mpv_, "pause", MPV_FORMAT_FLAG, &flag);
}

void MpvPlayer::stop() {
    if (!mpv_) return;
    const char *args[] = {"stop", nullptr};
    mpv_command_async(mpv_, 0, args);
    state_ = State::Stopped;
    position_ = 0;
    duration_ = 0;
    emit stateChanged(state_);
    emit positionChanged(0);
    emit durationChanged(0);
}

void MpvPlayer::togglePause() {
    if (state_ == State::Playing)
        pause();
    else if (state_ == State::Paused)
        resume();
}

void MpvPlayer::setVolume(int vol) {
    if (!mpv_) return;
    double v = qBound(0, vol, 100);
    mpv_set_property(mpv_, "volume", MPV_FORMAT_DOUBLE, &v);
}

int MpvPlayer::volume() const { return volume_; }

void MpvPlayer::setMuted(bool m) {
    if (!mpv_) return;
    int flag = m ? 1 : 0;
    mpv_set_property(mpv_, "mute", MPV_FORMAT_FLAG, &flag);
}

bool MpvPlayer::muted() const { return muted_; }

MpvPlayer::State MpvPlayer::state() const { return state_; }

double MpvPlayer::duration() const { return duration_; }

double MpvPlayer::position() const { return position_; }

double MpvPlayer::cacheDuration() const { return cacheDuration_; }

void MpvPlayer::seek(double seconds) {
    if (!mpv_) return;
    auto sStr = QByteArray::number(seconds, 'f', 1);
    const char *args[] = {"seek", sStr.constData(), "absolute", nullptr};
    mpv_command_async(mpv_, 0, args);
}

mpv_handle *MpvPlayer::handle() const { return mpv_; }

void MpvPlayer::command(const QStringList &args) {
    if (!mpv_) return;
    QVector<QByteArray> utf8Args;
    utf8Args.reserve(args.size());
    QVector<const char *> cArgs;
    cArgs.reserve(args.size() + 1);
    for (const auto &a : args) {
        utf8Args.append(a.toUtf8());
        cArgs.append(utf8Args.last().constData());
    }
    cArgs.append(nullptr);
    mpv_command_async(mpv_, 0, cArgs.data());
}

void MpvPlayer::setProperty(const QString &name, const QVariant &value) {
    if (!mpv_) return;
    auto nameUtf8 = name.toUtf8();
    if (value.typeId() == QMetaType::Int || value.typeId() == QMetaType::LongLong) {
        int64_t v = value.toLongLong();
        mpv_set_property(mpv_, nameUtf8.constData(), MPV_FORMAT_INT64, &v);
    } else if (value.typeId() == QMetaType::Double) {
        double v = value.toDouble();
        mpv_set_property(mpv_, nameUtf8.constData(), MPV_FORMAT_DOUBLE, &v);
    } else if (value.typeId() == QMetaType::Bool) {
        int flag = value.toBool() ? 1 : 0;
        mpv_set_property(mpv_, nameUtf8.constData(), MPV_FORMAT_FLAG, &flag);
    } else {
        auto valUtf8 = value.toString().toUtf8();
        mpv_set_property_string(mpv_, nameUtf8.constData(), valUtf8.constData());
    }
}

QVariant MpvPlayer::getProperty(const QString &name) const {
    if (!mpv_) return {};
    auto nameUtf8 = name.toUtf8();
    char *result = mpv_get_property_string(mpv_, nameUtf8.constData());
    if (!result) return {};
    auto val = QString::fromUtf8(result);
    mpv_free(result);
    return val;
}

void MpvPlayer::processEvents() {
    if (!mpv_) return;

    while (true) {
        auto *event = mpv_wait_event(mpv_, 0);
        if (event->event_id == MPV_EVENT_NONE) break;

        switch (event->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *prop = static_cast<mpv_event_property *>(event->data);
            auto name = QString::fromUtf8(prop->name);

            if (name == QLatin1String("pause") && prop->format == MPV_FORMAT_FLAG) {
                bool paused = *static_cast<int *>(prop->data);
                qInfo("MpvPlayer: pause=%d state=%d", paused, static_cast<int>(state_));
                if (paused && state_ == State::Playing) {
                    state_ = State::Paused;
                    emit stateChanged(state_);
                } else if (!paused && (state_ == State::Paused || state_ == State::Loading)) {
                    state_ = State::Playing;
                    emit stateChanged(state_);
                }
            } else if (name == QLatin1String("duration") && prop->format == MPV_FORMAT_DOUBLE) {
                duration_ = *static_cast<double *>(prop->data);
                emit durationChanged(duration_);
            } else if (name == QLatin1String("time-pos") && prop->format == MPV_FORMAT_DOUBLE) {
                position_ = *static_cast<double *>(prop->data);
                if (position_ > 0 && state_ == State::Loading) {
                    state_ = State::Playing;
                    emit stateChanged(state_);
                }
                emit positionChanged(position_);
            } else if (name == QLatin1String("volume") && prop->format == MPV_FORMAT_DOUBLE) {
                volume_ = static_cast<int>(*static_cast<double *>(prop->data));
                emit volumeChanged(volume_);
            } else if (name == QLatin1String("mute") && prop->format == MPV_FORMAT_FLAG) {
                muted_ = *static_cast<int *>(prop->data);
                emit mutedChanged(muted_);
            } else if (name == QLatin1String("demuxer-cache-duration") && prop->format == MPV_FORMAT_DOUBLE) {
                cacheDuration_ = *static_cast<double *>(prop->data);
                emit cacheDurationChanged(cacheDuration_);
            }
            break;
        }
        case MPV_EVENT_FILE_LOADED:
            qInfo("MpvPlayer: FILE_LOADED, setting Playing");
            state_ = State::Playing;
            emit stateChanged(state_);
            emit mediaLoaded();
            break;
        case MPV_EVENT_END_FILE: {
            auto *end = static_cast<mpv_event_end_file *>(event->data);
            if (end->reason == MPV_END_FILE_REASON_ERROR) {
                emit errorOccurred(QStringLiteral("Playback error: %1")
                    .arg(QString::fromUtf8(mpv_error_string(end->error))));
            }
            state_ = State::Stopped;
            emit stateChanged(state_);
            emit endOfFile();
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            auto *msg = static_cast<mpv_event_log_message *>(event->data);
            if (msg->log_level <= MPV_LOG_LEVEL_WARN) {
                QString text = QString::fromUtf8(msg->text).trimmed();
                if (text.contains(QStringLiteral("experimental feature")))
                    break;
                qWarning("mpv: %s", qPrintable(text));
            }
            break;
        }
        case MPV_EVENT_START_FILE:
            qInfo("MpvPlayer: file loading started");
            break;
        default:
            break;
        }
    }
}

} // namespace iptvxs
