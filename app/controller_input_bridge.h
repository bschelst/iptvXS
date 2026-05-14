// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
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

    // Button cooldown: prevent duplicate inputs from hat+button overlap
    // (D-pad) and from Steam Input auto-repeating BUTTONDOWN events while
    // a button is held (shoulders, face buttons). 300 ms is fast enough
    // that intentional rapid presses still register but slow enough to
    // swallow Steam's auto-repeat.
    static constexpr qint64 kButtonCooldownMs = 300;
    QHash<int, qint64> lastDpadPressMs_;
    // Tracks whether each button is currently considered "held" — set on
    // the first BUTTONDOWN, cleared on BUTTONUP. Lets us discard auto-
    // repeat BUTTONDOWN events that Steam Input synthesizes mid-hold.
    QHash<int, bool> heldButtons_;
    QElapsedTimer cooldownClock_;
};
