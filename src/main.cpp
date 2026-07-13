// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "greetercapabilities.h"
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
#include <QQuickWindow>
#include <QTimer>
#include <QDebug>
#include <QUrl>
#include <cstdio>
#include <cstdlib>

namespace {

constexpr auto kAppIconName = "org.github.melker.sddmvariantmanager";

QIcon loadBundledIcon()
{
    static const int kIconSizes[] = {16, 22, 24, 32, 48, 64, 128, 256, 512};
    QIcon icon;
    for (int size : kIconSizes) {
        const QString resourcePath = QStringLiteral(":/icons/hicolor/%1x%2/apps/%3.png")
                                         .arg(size)
                                         .arg(size)
                                         .arg(QString::fromUtf8(kAppIconName));
        icon.addFile(resourcePath, QSize(size, size));
    }
    return icon;
}

QIcon loadApplicationIcon()
{
    const QString iconName = QString::fromUtf8(kAppIconName);

    // Plasma/KWin resolve the titlebar icon from the icon theme (hicolor) via
    // the .desktop Icon= name — not only from QWindow::setIcon().
    const QIcon themeIcon = QIcon::fromTheme(iconName);
    if (!themeIcon.isNull()) {
        return themeIcon;
    }

    return loadBundledIcon();
}

void applyWindowIcon(QWindow *window)
{
    const QIcon icon = loadApplicationIcon();
    if (icon.isNull()) {
        return;
    }

    QGuiApplication::setWindowIcon(icon);
    if (window) {
        window->setIcon(icon);
    }
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
    // Nix builds pin SOURCE_DATE_EPOCH, so qrc timestamps never change and a
    // stale qmlcache can keep serving an old UI after rebuilds.
    if (!qEnvironmentVariableIsSet("QML_DISK_CACHE")) {
        qputenv("QML_DISK_CACHE", "disable");
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
    QGuiApplication::setOrganizationName(QStringLiteral("Melker"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("github.melker"));
    QGuiApplication::setApplicationVersion(QStringLiteral("2.0.1"));
    QGuiApplication::setQuitOnLastWindowClosed(true);
    QGuiApplication::setDesktopFileName(QString::fromUtf8(kAppIconName));

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    ThemeScanner themeScanner;
    ThemeApplier themeApplier;
    GreeterPreview greeterPreview;
    ThemeInstaller themeInstaller;
    GreeterCapabilities greeterCapabilities;

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &greeterPreview, [&greeterPreview]() {
        if (greeterPreview.running()) {
            greeterPreview.stopPreview();
        }
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
    engine.rootContext()->setContextProperty(QStringLiteral("greeterCapabilities"), &greeterCapabilities);

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

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    applyWindowIcon(window);
    if (window) {
        QObject::connect(window, &QQuickWindow::visibleChanged, window, [window]() {
            if (window->isVisible()) {
                applyWindowIcon(window);
            }
        });
        QTimer::singleShot(0, window, [window]() {
            applyWindowIcon(window);
        });
    }

    return app.exec();
}
