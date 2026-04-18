#include "mpv_video_item.h"

#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQuickWindow>

#include <mpv/client.h>
#include <mpv/render_gl.h>

namespace {

void *getProcAddress(void * /*ctx*/, const char *name) {
    auto *glctx = QOpenGLContext::currentContext();
    if (!glctx) return nullptr;
    return reinterpret_cast<void *>(glctx->getProcAddress(QByteArray(name)));
}

} // namespace

class MpvRenderer : public QQuickFramebufferObject::Renderer {
public:
    explicit MpvRenderer(MpvVideoItem *item) : item_(item) {}

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        return new QOpenGLFramebufferObject(size,
            QOpenGLFramebufferObject::CombinedDepthStencil);
    }

    void render() override {
        auto *ctx = item_->renderContext();
        if (!ctx) return;

        auto *win = item_->window();
        if (win) win->beginExternalCommands();

        auto *fbo = framebufferObject();
        int fboId = static_cast<int>(fbo->handle());
        int width = fbo->width();
        int height = fbo->height();
        int flipY = 1;

        mpv_opengl_fbo mpvFbo{fboId, width, height, 0};
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &mpvFbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flipY},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };

        mpv_render_context_render(ctx, params);

        if (win) win->endExternalCommands();
    }

private:
    MpvVideoItem *item_;
};

MpvVideoItem::MpvVideoItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent) {
    setMirrorVertically(true);
}

MpvVideoItem::~MpvVideoItem() {
    if (renderCtx_) {
        mpv_render_context_set_update_callback(renderCtx_, nullptr, nullptr);
        mpv_render_context_free(renderCtx_);
    }
}

QQuickFramebufferObject::Renderer *MpvVideoItem::createRenderer() const {
    auto *self = const_cast<MpvVideoItem *>(this);
    if (!self->renderInitialized_) {
        self->initRenderContext();
    }
    return new MpvRenderer(self);
}

iptvxs::MpvPlayer *MpvVideoItem::player() const { return player_; }

void MpvVideoItem::setPlayer(iptvxs::MpvPlayer *player) {
    if (player_ != player) {
        player_ = player;
        emit playerChanged();
    }
}

mpv_render_context *MpvVideoItem::renderContext() const { return renderCtx_; }

bool MpvVideoItem::initRenderContext() {
    if (!player_ || !player_->handle()) return false;

    mpv_opengl_init_params glParams{getProcAddress, nullptr};
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE,
         const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glParams},
        {MPV_RENDER_PARAM_INVALID, nullptr},
    };

    if (mpv_render_context_create(&renderCtx_, player_->handle(), params) < 0) {
        qWarning("Failed to create mpv render context");
        return false;
    }

    mpv_render_context_set_update_callback(renderCtx_, onMpvUpdate, this);
    renderInitialized_ = true;
    return true;
}

void MpvVideoItem::onMpvUpdate(void *ctx) {
    auto *item = static_cast<MpvVideoItem *>(ctx);
    QMetaObject::invokeMethod(item, "update", Qt::QueuedConnection);
}
