// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include <clocale>
#include <memory>

#include <QApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QMenu>
#include <QMutex>
#include <QMutexLocker>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <QTextStream>

#ifndef Q_OS_WIN
#include "controller_input_bridge.h"
#endif
#include "viewmodels/app_viewmodel.h"
#include "viewmodels/log_viewmodel.h"

static LogViewModel *g_logViewModel = nullptr;
static QFile *g_logFile = nullptr;
static QMutex g_logMutex;

static void appMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg) {
    QMutexLocker lock(&g_logMutex);

    QString level;
    switch (type) {
    case QtDebugMsg:    level = QStringLiteral("DEBUG"); break;
    case QtInfoMsg:     level = QStringLiteral("INFO"); break;
    case QtWarningMsg:  level = QStringLiteral("WARN"); break;
    case QtCriticalMsg: level = QStringLiteral("ERROR"); break;
    case QtFatalMsg:    level = QStringLiteral("FATAL"); break;
    }

    auto timestamp = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    auto line = QStringLiteral("[%1] %2: %3").arg(timestamp, level, msg);

    if (g_logFile && g_logFile->isOpen()) {
        QTextStream stream(g_logFile);
        stream << line << "\n";
        stream.flush();
    }

    if (g_logViewModel) {
        QMetaObject::invokeMethod(g_logViewModel, "appendLog",
                                  Qt::QueuedConnection,
                                  Q_ARG(QString, level),
                                  Q_ARG(QString, timestamp),
                                  Q_ARG(QString, msg));
    }

    fprintf(stderr, "%s\n", qPrintable(line));
}

static QQuickWindow *showMainWindow(QQmlApplicationEngine &engine) {
    const auto roots = engine.rootObjects();
    if (!roots.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(roots.first());
        if (window) {
            window->show();
            window->raise();
            window->requestActivate();
            return window;
        }
    }
    return nullptr;
}

static QString localAppDataPath() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
           + QStringLiteral("/iptvXS");
}

int main(int argc, char *argv[]) {
    std::setlocale(LC_NUMERIC, "C");
#if defined(Q_OS_WIN) || defined(_WIN32)
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
#endif
    QApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");
    app.setApplicationName("iptvXS");
    app.setApplicationVersion(QStringLiteral(IPTVXS_VERSION));
    app.setOrganizationName("iptvXS");
    // Tied to closeToTray setting below, once viewModel is available.
    app.setQuitOnLastWindowClosed(true);

    QQuickStyle::setStyle("Basic");

    QString dataPath = localAppDataPath();
    QDir().mkpath(dataPath);

    auto logFilePath = dataPath + "/iptvxs.log";
    g_logFile = new QFile(logFilePath);
    g_logFile->open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);

    auto logVm = new LogViewModel(&app);
    g_logViewModel = logVm;
    qInstallMessageHandler(appMessageHandler);

    QIcon appIcon(QStringLiteral(":/images/iptvxs_tray.png"));
    app.setWindowIcon(appIcon);

    qInfo("iptvXS v%s starting", qPrintable(app.applicationVersion()));
    qInfo("Data directory: %s", qPrintable(dataPath));

    QString dbPath = dataPath + "/iptvxs.db";

    auto viewModel = new AppViewModel(&app);
    viewModel->setLogViewModel(logVm);
    if (!viewModel->initialize(dbPath)) {
        qCritical("Failed to initialize database at %s", qPrintable(dbPath));
        return 1;
    }

    auto applyQuitPolicy = [viewModel, &app]() {
        const bool tray = viewModel->closeToTray();
        app.setQuitOnLastWindowClosed(!tray);
        qInfo("Quit policy: quitOnLastWindowClosed=%s (closeToTray=%s)",
              tray ? "false" : "true", tray ? "on" : "off");
    };
    applyQuitPolicy();
    QObject::connect(viewModel, &AppViewModel::closeToTrayChanged, &app,
                     applyQuitPolicy);

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("appViewModel", viewModel);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    engine.loadFromModule("app.iptvxs", "Main");

    QSystemTrayIcon trayIcon(&app);
    trayIcon.setIcon(QIcon(QStringLiteral(":/images/iptvxs_tray.png")));
    trayIcon.setToolTip("iptvXS");

    auto *trayMenu = new QMenu();

    auto *showAction = trayMenu->addAction("Show iptvXS");
    QObject::connect(showAction, &QAction::triggered, &engine,
                     [&engine]() { showMainWindow(engine); });

    trayMenu->addSeparator();

    auto *stopAction = trayMenu->addAction("Stop Playing");
    QObject::connect(stopAction, &QAction::triggered, viewModel,
                     [viewModel]() { viewModel->player()->stop(); });

    auto *muteAction = trayMenu->addAction("Mute");
    QObject::connect(muteAction, &QAction::triggered, viewModel,
                     [viewModel]() { viewModel->player()->setMuted(true); });

    auto *unmuteAction = trayMenu->addAction("Unmute");
    QObject::connect(unmuteAction, &QAction::triggered, viewModel,
                     [viewModel]() { viewModel->player()->setMuted(false); });

    trayMenu->addSeparator();

    auto *quitAction = trayMenu->addAction("Quit");
    QObject::connect(quitAction, &QAction::triggered, &app,
                     &QApplication::quit);

    QObject::connect(viewModel->player(), &PlayerViewModel::stateChanged,
                     stopAction, [viewModel, stopAction]() {
                         stopAction->setEnabled(viewModel->player()->playing() ||
                                                viewModel->player()->paused());
                     });
    QObject::connect(viewModel->player(), &PlayerViewModel::mutedChanged,
                     muteAction, [viewModel, muteAction, unmuteAction]() {
                         bool muted = viewModel->player()->muted();
                         muteAction->setVisible(!muted);
                         unmuteAction->setVisible(muted);
                     });
    stopAction->setEnabled(false);
    unmuteAction->setVisible(false);

    trayIcon.setContextMenu(trayMenu);

    QObject::connect(
        &trayIcon, &QSystemTrayIcon::activated, &engine,
        [&engine](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger ||
                reason == QSystemTrayIcon::DoubleClick) {
                showMainWindow(engine);
            }
        });

    auto applyTrayVisibility = [viewModel, &trayIcon]() {
        if (!QSystemTrayIcon::isSystemTrayAvailable()) {
            trayIcon.hide();
            return;
        }
        const bool tray = viewModel->closeToTray();
        if (tray) {
            trayIcon.show();
        } else {
            trayIcon.hide();
        }
        qInfo("Tray icon visible=%s", tray ? "true" : "false");
    };
    applyTrayVisibility();
    QObject::connect(viewModel, &AppViewModel::closeToTrayChanged, &trayIcon,
                     applyTrayVisibility);

    auto *mainWindow = showMainWindow(engine);
#ifndef Q_OS_WIN
    auto controllerBridge = std::make_unique<ControllerInputBridge>(mainWindow, &app);
#endif

    qInfo("Application started successfully");

    auto result = QApplication::exec();

    qInfo("Application shutting down");
    qInstallMessageHandler(nullptr);
    g_logViewModel = nullptr;

    if (g_logFile) {
        g_logFile->close();
        delete g_logFile;
        g_logFile = nullptr;
    }

    return result;
}
