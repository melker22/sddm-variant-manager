// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "themeapplier.h"
#include "themescanner.h"

#include <QCoreApplication>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
    QGuiApplication::setOrganizationName(QStringLiteral("Melker"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("github.melker"));
    QGuiApplication::setApplicationVersion(QStringLiteral("1.0.0"));

    ThemeScanner themeScanner;
    ThemeApplier themeApplier;
    GreeterPreview greeterPreview;

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("/usr/lib/qt6/qml"));
    engine.addImportPath(QStringLiteral("/usr/lib/qml"));
    engine.addImportPath(QCoreApplication::applicationDirPath());
    engine.addImportPath(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("..")));

    engine.rootContext()->setContextProperty(QStringLiteral("themeScanner"), &themeScanner);
    engine.rootContext()->setContextProperty(QStringLiteral("themeApplier"), &themeApplier);
    engine.rootContext()->setContextProperty(QStringLiteral("greeterPreview"), &greeterPreview);

    QObject::connect(
        &themeApplier,
        &ThemeApplier::applyFinished,
        &themeScanner,
        [&themeScanner](bool success, const QString &) {
            if (success) {
                themeScanner.rescan();
            }
        });

    engine.loadFromModule(QStringLiteral("org.github.melker.sddmvariantmanager"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
