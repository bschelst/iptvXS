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

    // Cooldowns on DISPATCH (not on event arrival). Steam Input sends
    // fake BUTTONUP between its auto-repeat BUTTONDOWN events, so any
    // state-based debounce gets defeated. Only time since last DISPATCH
    // is reliable.
    //
    // - kDpadCooldownMs: held D-pad should repeat for list scrolling
    //   (~12 events/sec). 80 ms feels responsive.
    // - kButtonCooldownMs: shoulders + face buttons are tap-style;
    //   500 ms is well past the longest Steam Input repeat (~700 ms)
    //   while still allowing intentional double-taps (e.g., for a
    //   confirm-then-confirm pattern).
    static constexpr qint64 kDpadCooldownMs = 80;
    static constexpr qint64 kButtonCooldownMs = 500;
    QHash<int, qint64> lastDispatchMs_;
    QElapsedTimer cooldownClock_;
};
