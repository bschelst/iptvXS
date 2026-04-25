#pragma once

#include <QObject>
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
};
