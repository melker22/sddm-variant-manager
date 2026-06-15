// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "themeapplier.h"
#include "themeinstaller.h"
#include "themescanner.h"

#include <QCoreApplication>
#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QStyleHints>
#include <QDebug>
#include <QUrl>
#include <cstdio>
#include <cstdlib>

namespace {

void applyWindowIcon()
{
    const bool dark = QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
    const QString iconPath = dark
        ? QStringLiteral(":/icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager-dark.svg")
        : QStringLiteral(":/icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager.svg");
    QGuiApplication::setWindowIcon(QIcon(iconPath));
}

} // namespace

int main(int argc, char *argv[])
{
    if (!qEnvironmentVariableIsSet("AV_LOG_LEVEL")) {
        qputenv("AV_LOG_LEVEL", "-8");
    }
    if (!qEnvironmentVariableIsSet("QT_FFMPEG_DECODING_HW_DEVICE_TYPES")) {
        qputenv("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "");
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
    QGuiApplication::setOrganizationName(QStringLiteral("Melker"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("github.melker"));
    QGuiApplication::setApplicationVersion(QStringLiteral("1.0.0"));
    QGuiApplication::setQuitOnLastWindowClosed(true);

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    ThemeScanner themeScanner;
    ThemeApplier themeApplier;
    GreeterPreview greeterPreview;
    ThemeInstaller themeInstaller;

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &greeterPreview, [&greeterPreview]() {
        if (greeterPreview.running()) {
            greeterPreview.stopPreview();
        }
    });

    QObject::connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, &app, []() {
        applyWindowIcon();
    });

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/src/qml"));
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
                qCritical().noquote() << error.toString();
            }
        });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        [](const QUrl &url) {
            qCritical().noquote() << "QML object creation failed for" << url;
        });

    const QUrl mainQmlUrl(QStringLiteral("qrc:/src/qml/Main.qml"));
    QQmlComponent component(&engine, mainQmlUrl);
    if (component.isError()) {
        for (const QQmlError &error : component.errors()) {
            const QString message = error.toString();
            qCritical().noquote() << message;
            fprintf(stderr, "%s\n", qPrintable(message));
        }
        return -1;
    }

    engine.load(mainQmlUrl);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML file" << mainQmlUrl;
        fprintf(stderr, "Failed to load QML file %s\n", qPrintable(mainQmlUrl.toString()));
        return -1;
    }

    applyWindowIcon();

    return app.exec();
}
