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
static QString g_logFilePath;
static QMutex g_logMutex;
static constexpr qint64 kMaxActiveLogBytes = 5 * 1024 * 1024;

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

static QString rotatedLogPath(const QString &basePath, int version) {
    return QStringLiteral("%1.%2.qz").arg(basePath).arg(version);
}

static QString legacyDatabasePath(const QString &dataPath) {
    return dataPath + QStringLiteral("/iptvxs.db");
}

static QString databasePath(const QString &dataPath) {
    return dataPath + QStringLiteral("/iptvXS.db");
}

static bool renameLegacyDatabaseFiles(const QString &dataPath) {
    const QString oldDb = legacyDatabasePath(dataPath);
    const QString newDb = databasePath(dataPath);
    if (!QFile::exists(oldDb) || QFile::exists(newDb)) {
        return false;
    }

    QFile::remove(newDb);
    QFile::remove(newDb + QStringLiteral("-wal"));
    QFile::remove(newDb + QStringLiteral("-shm"));

    const bool dbOk = QFile::rename(oldDb, newDb);
    const bool walOk = !QFile::exists(oldDb + QStringLiteral("-wal"))
                           || QFile::rename(oldDb + QStringLiteral("-wal"),
                                           newDb + QStringLiteral("-wal"));
    const bool shmOk = !QFile::exists(oldDb + QStringLiteral("-shm"))
                           || QFile::rename(oldDb + QStringLiteral("-shm"),
                                           newDb + QStringLiteral("-shm"));
    return dbOk && walOk && shmOk;
}

static void rotateStartupLogs(const QString &logFilePath, int maxVersions = 5) {
    for (int version = maxVersions; version >= 1; --version) {
        const QString source = rotatedLogPath(logFilePath, version);
        const QString target = rotatedLogPath(logFilePath, version + 1);
        QFile::remove(target);
        if (QFile::exists(source)) {
            QFile::rename(source, target);
        }
    }

    QFile current(logFilePath);
    if (!current.exists() || !current.open(QIODevice::ReadOnly)) {
        return;
    }

    const QByteArray compressed = qCompress(current.readAll(), 9);
    current.close();

    QFile rotated(rotatedLogPath(logFilePath, 1));
    if (!rotated.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    rotated.write(compressed);
    rotated.close();
}

static void appMessageHandler(QtMsgType type, const QMessageLogContext &, const QString &msg) {
    // Suppress noisy warnings that aren't actionable
    if (msg.contains(QStringLiteral("libcuda")) || msg.contains(QStringLiteral("CUDA")))
        return;

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
        if (!g_logFilePath.isEmpty() && g_logFile->size() > kMaxActiveLogBytes) {
            g_logFile->close();
            rotateStartupLogs(g_logFilePath);
            g_logFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);
        }
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

    // Ensure Qt finds imageformat plugins (WebP etc.) in Flatpak
    app.addLibraryPath(QStringLiteral("/app/lib/plugins"));

    QString dataPath = localAppDataPath();
    QDir().mkpath(dataPath);
    const bool renamedLegacyDb = renameLegacyDatabaseFiles(dataPath);

    auto logFilePath = dataPath + "/iptvXS.log";
    g_logFilePath = logFilePath;
    rotateStartupLogs(logFilePath);
    g_logFile = new QFile(logFilePath);
    g_logFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);

    auto logVm = new LogViewModel(&app);
    g_logViewModel = logVm;
    qInstallMessageHandler(appMessageHandler);

    QIcon appIcon(QStringLiteral(":/images/iptvxs_tray.png"));
    app.setWindowIcon(appIcon);

    qInfo("iptvXS v%s starting", qPrintable(app.applicationVersion()));
    qInfo("Data directory: %s", qPrintable(dataPath));
    if (renamedLegacyDb) {
        qInfo("Migrated legacy database files to iptvXS.db");
    }

    QString dbPath = databasePath(dataPath);

    auto viewModel = new AppViewModel(&app);
    viewModel->setLogViewModel(logVm);
    QObject::connect(viewModel, &AppViewModel::errorOccurred, &app,
                     [](const QString &message) { qWarning("%s", qPrintable(message)); });
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
