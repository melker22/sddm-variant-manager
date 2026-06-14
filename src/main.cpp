// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "themeapplier.h"
#include "themeinstaller.h"
#include "themescanner.h"

#include <QCoreApplication>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QDebug>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
    QGuiApplication::setOrganizationName(QStringLiteral("Melker"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("github.melker"));
    QGuiApplication::setApplicationVersion(QStringLiteral("1.0.0"));
    QGuiApplication::setQuitOnLastWindowClosed(true);

    ThemeScanner themeScanner;
    ThemeApplier themeApplier;
    GreeterPreview greeterPreview;
    ThemeInstaller themeInstaller;

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &greeterPreview, [&greeterPreview]() {
        if (greeterPreview.running()) {
            greeterPreview.stopPreview();
        }
    });

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("/usr/lib/qt6/qml"));
    engine.addImportPath(QStringLiteral("/usr/lib/qml"));
    engine.addImportPath(QCoreApplication::applicationDirPath());
    engine.addImportPath(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("..")));

    engine.rootContext()->setContextProperty(QStringLiteral("themeScanner"), &themeScanner);
    engine.rootContext()->setContextProperty(QStringLiteral("themeApplier"), &themeApplier);
    engine.rootContext()->setContextProperty(QStringLiteral("greeterPreview"), &greeterPreview);
    engine.rootContext()->setContextProperty(QStringLiteral("themeInstaller"), &themeInstaller);

    QObject::connect(
        &themeApplier,
        &ThemeApplier::applyFinished,
        &themeScanner,
        [&themeScanner](bool success, const QString &) {
            if (success) {
                themeScanner.rescan();
            }
        });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::warnings,
        [](const QList<QQmlError> &warnings) {
            for (const QQmlError &error : warnings) {
                qWarning().noquote() << error.toString();
            }
        });

    engine.load(QUrl(QStringLiteral("qrc:/src/qml/Main.qml")));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML file qrc:/src/qml/Main.qml";
        return -1;
    }

    return app.exec();
}
