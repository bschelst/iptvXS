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
    qInfo("[CTRL] ControllerInputBridge ctor — targetWindow=%p", targetWindow);
    if (SDL_Init(SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK | SDL_INIT_EVENTS) != 0) {
        qWarning("[CTRL] SDL controller init FAILED: %s", SDL_GetError());
        return;
    }
    qInfo("[CTRL] SDL init ok — joysticks attached: %d", SDL_NumJoysticks());

    openControllers();
    qInfo("[CTRL] openControllers() complete — %d controllers tracked", controllers_.size());
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
    qInfo("[CTRL] scanning %d joystick(s)", count);
    for (int i = 0; i < count; ++i) {
        const char *jname = SDL_JoystickNameForIndex(i);
        const bool isGc = SDL_IsGameController(i);
        qInfo("[CTRL]   joy[%d] name='%s' isGameController=%s",
              i, jname ? jname : "(null)", isGc ? "yes" : "NO");
        if (!isGc) {
            continue;
        }
        auto *controller = SDL_GameControllerOpen(i);
        if (!controller) {
            qWarning("[CTRL]   joy[%d] SDL_GameControllerOpen failed: %s",
                     i, SDL_GetError());
            continue;
        }
        SDL_Joystick *joystick = SDL_GameControllerGetJoystick(controller);
        if (!joystick) {
            SDL_GameControllerClose(controller);
            continue;
        }
        const auto id = SDL_JoystickInstanceID(joystick);
        controllers_.insert(id, controller);
        qInfo("[CTRL]   joy[%d] OPENED instanceId=%d name='%s'",
              i, id, SDL_GameControllerName(controller));
    }
}

void ControllerInputBridge::closeControllers() {
    for (auto *controller : controllers_) {
        SDL_GameControllerClose(controller);
    }
    controllers_.clear();
}

void ControllerInputBridge::sendKey(Qt::Key key, bool pressed) {
    if (!targetWindow_) {
        qWarning("[CTRL] sendKey: targetWindow_ is null (key=0x%x pressed=%d)", key, pressed);
        return;
    }
    if (key == Qt::Key_unknown) {
        return;
    }
    if (pressed) {
        qInfo("[CTRL] sendKey → window key=0x%x (%s)", static_cast<int>(key),
              key == Qt::Key_Up ? "Up"
              : key == Qt::Key_Down ? "Down"
              : key == Qt::Key_Left ? "Left"
              : key == Qt::Key_Right ? "Right"
              : key == Qt::Key_Return ? "Return"
              : key == Qt::Key_Escape ? "Escape"
              : key == Qt::Key_Space ? "Space" : "?");
    }

    QKeyEvent event(pressed ? QEvent::KeyPress : QEvent::KeyRelease,
                    key,
                    Qt::NoModifier);
    QCoreApplication::sendEvent(targetWindow_, &event);
}

void ControllerInputBridge::handleControllerButton(int button, bool pressed) {
    // Apply cooldown only to d-pad press events to prevent double-firing
    // (some controllers emit both hat and button events for d-pad).
    const bool isDpad = (button == SDL_CONTROLLER_BUTTON_DPAD_UP ||
                         button == SDL_CONTROLLER_BUTTON_DPAD_DOWN ||
                         button == SDL_CONTROLLER_BUTTON_DPAD_LEFT ||
                         button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT);
    if (pressed) {
        qInfo("[CTRL] SDL button down: %d (%s)%s",
              button,
              SDL_GameControllerGetStringForButton(static_cast<SDL_GameControllerButton>(button)),
              isDpad ? " [dpad]" : "");
    }
    if (isDpad && pressed) {
        const qint64 now = cooldownClock_.elapsed();
        const qint64 last = lastDpadPressMs_.value(button, 0);
        if (now - last < kDpadCooldownMs) {
            qInfo("[CTRL]   suppressed (cooldown %lld ms)", now - last);
            return; // suppress duplicate
        }
        lastDpadPressMs_[button] = now;
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
