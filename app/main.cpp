#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>

#include "viewmodels/app_viewmodel.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("iptvxs");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("iptvxs");

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

    return QGuiApplication::exec();
}
