#include <clocale>

#include <QApplication>
#include <QIcon>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QSystemTrayIcon>

#include "viewmodels/app_viewmodel.h"

static void showMainWindow(QQmlApplicationEngine &engine) {
    const auto roots = engine.rootObjects();
    if (!roots.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(roots.first());
        if (window) {
            window->show();
            window->raise();
            window->requestActivate();
        }
    }
}

int main(int argc, char *argv[]) {
    std::setlocale(LC_NUMERIC, "C");
    QApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");
    app.setApplicationName("iptvxs");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("iptvxs");
    app.setQuitOnLastWindowClosed(false);

    QQuickStyle::setStyle("Basic");

    QString dataPath =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString dbPath = dataPath + "/iptvxs.db";

    auto viewModel = new AppViewModel(&app);
    if (!viewModel->initialize(dbPath)) {
        qCritical("Failed to initialize database at %s", qPrintable(dbPath));
        return 1;
    }

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("appViewModel", viewModel);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    engine.loadFromModule("app.iptvxs", "Main");

    QSystemTrayIcon trayIcon(&app);
    trayIcon.setIcon(QIcon::fromTheme("video-television",
                                      QIcon::fromTheme("applications-multimedia")));
    trayIcon.setToolTip("iptvxs");

    auto *trayMenu = new QMenu();

    auto *showAction = trayMenu->addAction("Show iptvxs");
    QObject::connect(showAction, &QAction::triggered, &engine,
                     [&engine]() { showMainWindow(engine); });

    trayMenu->addSeparator();

    auto *quitAction = trayMenu->addAction("Quit");
    QObject::connect(quitAction, &QAction::triggered, &app,
                     &QApplication::quit);

    trayIcon.setContextMenu(trayMenu);

    QObject::connect(
        &trayIcon, &QSystemTrayIcon::activated, &engine,
        [&engine](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger ||
                reason == QSystemTrayIcon::DoubleClick) {
                showMainWindow(engine);
            }
        });

    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        trayIcon.show();
    }

    return QApplication::exec();
}
