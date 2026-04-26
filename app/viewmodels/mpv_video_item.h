// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QOpenGLFramebufferObject>
#include <QQmlEngine>
#include <QQuickFramebufferObject>

#include "iptvxs/player/mpv_player.h"

struct mpv_render_context;

class MpvVideoItem : public QQuickFramebufferObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(iptvxs::MpvPlayer *player READ player WRITE setPlayer NOTIFY playerChanged)

public:
    explicit MpvVideoItem(QQuickItem *parent = nullptr);
    ~MpvVideoItem() override;

    Renderer *createRenderer() const override;

    iptvxs::MpvPlayer *player() const;
    void setPlayer(iptvxs::MpvPlayer *player);

    mpv_render_context *renderContext() const;

signals:
    void playerChanged();

private:
    bool initRenderContext();
    static void onMpvUpdate(void *ctx);

    iptvxs::MpvPlayer *player_{nullptr};
    mpv_render_context *renderCtx_{nullptr};
    bool renderInitialized_{false};
};
