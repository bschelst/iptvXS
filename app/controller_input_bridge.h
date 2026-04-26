#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QHash>
#include <QPointer>
#include <QTimer>
#include <QWindow>

#include <SDL.h>

class ControllerInputBridge : public QObject {
    Q_OBJECT

public:
    explicit ControllerInputBridge(QWindow *targetWindow, QObject *parent = nullptr);
    ~ControllerInputBridge() override;

private:
    void pollEvents();
    void openControllers();
    void closeControllers();
    void handleControllerButton(int button, bool pressed);
    void sendKey(Qt::Key key, bool pressed);

    QPointer<QWindow> targetWindow_;
    QTimer pollTimer_;
    QHash<SDL_JoystickID, SDL_GameController *> controllers_;

    // D-pad cooldown: prevent duplicate inputs from hat+button overlap.
    static constexpr qint64 kDpadCooldownMs = 120;
    QHash<int, qint64> lastDpadPressMs_;
    QElapsedTimer cooldownClock_;
};
