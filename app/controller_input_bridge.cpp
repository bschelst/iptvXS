// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "controller_input_bridge.h"

#include <QCoreApplication>
#include <QKeyEvent>
#include <SDL.h>

namespace {
Qt::Key keyForControllerButton(SDL_GameControllerButton button) {
    switch (button) {
    case SDL_CONTROLLER_BUTTON_DPAD_UP:
        return Qt::Key_Up;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        return Qt::Key_Down;
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        return Qt::Key_Left;
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        return Qt::Key_Right;
    case SDL_CONTROLLER_BUTTON_A:
        return Qt::Key_Return;
    case SDL_CONTROLLER_BUTTON_B:
        return Qt::Key_Escape;
    case SDL_CONTROLLER_BUTTON_X:
        return Qt::Key_Space;
    case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
        return Qt::Key_PageUp;
    case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
        return Qt::Key_PageDown;
    default:
        return Qt::Key_unknown;
    }
}
} // namespace

ControllerInputBridge::ControllerInputBridge(QWindow *targetWindow, QObject *parent)
    : QObject(parent), targetWindow_(targetWindow) {
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    // Ensure external controllers connected via USB/Bluetooth are detected.
    SDL_SetHint(SDL_HINT_JOYSTICK_HIDAPI, "1");
    if (SDL_Init(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK | SDL_INIT_EVENTS) != 0) {
        qWarning("SDL controller init failed: %s", SDL_GetError());
        return;
    }

    openControllers();
    cooldownClock_.start();

    pollTimer_.setInterval(16);
    connect(&pollTimer_, &QTimer::timeout, this, &ControllerInputBridge::pollEvents);
    pollTimer_.start();
}

ControllerInputBridge::~ControllerInputBridge() {
    pollTimer_.stop();
    closeControllers();
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK | SDL_INIT_EVENTS);
}

void ControllerInputBridge::openControllers() {
    const int count = SDL_NumJoysticks();
    for (int i = 0; i < count; ++i) {
        if (!SDL_IsGameController(i)) {
            continue;
        }
        auto *controller = SDL_GameControllerOpen(i);
        if (!controller) {
            continue;
        }
        SDL_Joystick *joystick = SDL_GameControllerGetJoystick(controller);
        if (!joystick) {
            SDL_GameControllerClose(controller);
            continue;
        }
        controllers_.insert(SDL_JoystickInstanceID(joystick), controller);
    }
}

void ControllerInputBridge::closeControllers() {
    for (auto *controller : controllers_) {
        SDL_GameControllerClose(controller);
    }
    controllers_.clear();
}

void ControllerInputBridge::sendKey(Qt::Key key, bool pressed) {
    if (!targetWindow_ || key == Qt::Key_unknown) {
        return;
    }

    QKeyEvent event(pressed ? QEvent::KeyPress : QEvent::KeyRelease,
                    key,
                    Qt::NoModifier);
    QCoreApplication::sendEvent(targetWindow_, &event);
}

void ControllerInputBridge::handleControllerButton(int button, bool pressed) {
    if (pressed) {
        qInfo("[CTRL] SDL button down: %d (%s)", button,
              SDL_GameControllerGetStringForButton(
                  static_cast<SDL_GameControllerButton>(button)));
    }

    // Steam Input on the Steam Deck fires repeated BUTTONDOWN events
    // while a button is physically held (auto-repeat). For tap-style
    // controls (L1/R1 menu nav, A/B/X) every repeat re-runs the action
    // and the user gets +N steps instead of +1. Track held state per
    // button and ignore subsequent BUTTONDOWN until BUTTONUP arrives.
    //
    // The short cooldown still applies on top: it absorbs D-pad hat+button
    // double-events that arrive from the same physical press (SDL emits
    // both on some controllers).
    if (pressed) {
        if (heldButtons_.value(button, false)) {
            return; // already held, ignore auto-repeat
        }
        const qint64 now = cooldownClock_.elapsed();
        const qint64 last = lastDpadPressMs_.value(button, 0);
        if (now - last < kButtonCooldownMs) {
            qInfo("[CTRL]   suppressed (%lld ms since last press)", now - last);
            return; // suppress duplicate
        }
        lastDpadPressMs_[button] = now;
        heldButtons_[button] = true;
    } else {
        heldButtons_[button] = false;
    }

    sendKey(keyForControllerButton(static_cast<SDL_GameControllerButton>(button)), pressed);
}

void ControllerInputBridge::pollEvents() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_CONTROLLERBUTTONDOWN:
            handleControllerButton(event.cbutton.button, true);
            break;
        case SDL_CONTROLLERBUTTONUP:
            handleControllerButton(event.cbutton.button, false);
            break;
        case SDL_CONTROLLERDEVICEADDED:
            if (SDL_IsGameController(event.cdevice.which)) {
                auto *controller = SDL_GameControllerOpen(event.cdevice.which);
                if (controller) {
                    SDL_Joystick *joystick = SDL_GameControllerGetJoystick(controller);
                    if (joystick) {
                        controllers_.insert(SDL_JoystickInstanceID(joystick), controller);
                    } else {
                        SDL_GameControllerClose(controller);
                    }
                }
            }
            break;
        case SDL_CONTROLLERDEVICEREMOVED:
            if (controllers_.contains(event.cdevice.which)) {
                SDL_GameControllerClose(controllers_.take(event.cdevice.which));
            }
            break;
        default:
            break;
        }
    }
}
