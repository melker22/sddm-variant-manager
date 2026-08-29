// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "greetercapabilities.h"
#include "themeapplier.h"
#include "themeinstaller.h"
#include "themescanner.h"

#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTextStream>
#include <QTimer>
#include <QDebug>
#include <QUrl>
#include <QVariantMap>
#include <cstdio>
#include <cstdlib>

#include "platform.h"

namespace {

constexpr auto kAppIconName = "org.github.melker.sddmvariantmanager";

bool directoryHasGSettingsSchemas(const QString &dirPath)
{
    const QDir dir(dirPath);
    if (!dir.exists()) {
        return false;
    }
    // Compiled or raw schemas are enough for GLib to accept the directory.
    return !dir.entryList({QStringLiteral("*.compiled"), QStringLiteral("*.xml"), QStringLiteral("*.override")},
                          QDir::Files)
                .isEmpty();
}

QStringList discoverGSettingsSchemaDirs()
{
    QStringList dirs;

    const auto appendIfUseful = [&dirs](const QString &path) {
        if (path.isEmpty() || dirs.contains(path) || !directoryHasGSettingsSchemas(path)) {
            return;
        }
        dirs.append(path);
    };

    if (qEnvironmentVariableIsSet("GSETTINGS_SCHEMA_DIR")) {
        const QStringList existing =
            QString::fromLocal8Bit(qgetenv("GSETTINGS_SCHEMA_DIR")).split(QLatin1Char(':'), Qt::SkipEmptyParts);
        for (const QString &path : existing) {
            appendIfUseful(path);
        }
    }

    // Nix / FHS-style locations used by file dialogs via GTK platform themes.
    appendIfUseful(QStringLiteral("/run/current-system/sw/share/glib-2.0/schemas"));
    appendIfUseful(QDir::homePath() + QStringLiteral("/.nix-profile/share/glib-2.0/schemas"));
    appendIfUseful(QStringLiteral("/usr/share/glib-2.0/schemas"));
    appendIfUseful(QStringLiteral("/usr/local/share/glib-2.0/schemas"));

    const auto appendFromDataRoot = [&appendIfUseful](const QString &dataRoot) {
        if (dataRoot.isEmpty()) {
            return;
        }
        appendIfUseful(dataRoot + QStringLiteral("/glib-2.0/schemas"));

        // Nix layout: share/gsettings-schemas/<pkg>/glib-2.0/schemas
        const QDir nestedRoot(dataRoot + QStringLiteral("/gsettings-schemas"));
        if (!nestedRoot.exists()) {
            return;
        }
        const QStringList packages = nestedRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &pkg : packages) {
            appendIfUseful(nestedRoot.filePath(pkg + QStringLiteral("/glib-2.0/schemas")));
        }
    };

    const QByteArray xdgDataDirs = qgetenv("XDG_DATA_DIRS");
    for (const QByteArray &part : xdgDataDirs.split(':')) {
        if (part.isEmpty()) {
            continue;
        }
        appendFromDataRoot(QString::fromLocal8Bit(part));
    }

    for (const QString &dataRoot : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
        appendFromDataRoot(dataRoot);
    }

    return dirs;
}

// Avoid GLib hard-abort ("No GSettings schemas are installed") when a GTK file
// dialog opens under incomplete Nix/dev environments.
void prepareDesktopEnvironment()
{
    // Prefer the documented kill-switch; "disable" is not a valid QML_DISK_CACHE mode.
    if (qEnvironmentVariableIsSet("QML_DISK_CACHE")) {
        const QByteArray cacheMode = qgetenv("QML_DISK_CACHE");
        if (cacheMode == "disable" || cacheMode == "off" || cacheMode == "0") {
            qunsetenv("QML_DISK_CACHE");
            if (!qEnvironmentVariableIsSet("QML_DISABLE_DISK_CACHE")) {
                qputenv("QML_DISABLE_DISK_CACHE", "1");
            }
        }
    } else if (!qEnvironmentVariableIsSet("QML_DISABLE_DISK_CACHE")) {
        qputenv("QML_DISABLE_DISK_CACHE", "1");
    }

    const QStringList schemaDirs = discoverGSettingsSchemaDirs();
    if (!schemaDirs.isEmpty()) {
        if (!qEnvironmentVariableIsSet("GSETTINGS_SCHEMA_DIR")) {
            qputenv("GSETTINGS_SCHEMA_DIR", schemaDirs.join(QLatin1Char(':')).toLocal8Bit());
        }
        return;
    }

    const QByteArray platformTheme = qgetenv("QT_QPA_PLATFORMTHEME").toLower();
    if (platformTheme.contains("gtk")) {
        qWarning().noquote()
            << "GSettings schemas were not found. Switching QT_QPA_PLATFORMTHEME from"
            << QString::fromLocal8Bit(qgetenv("QT_QPA_PLATFORMTHEME"))
            << "to xdgdesktopportal so file dialogs do not abort the process.";
        qputenv("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");
    }
}

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

/**
 * Kirigami.Icon / QIcon::fromTheme need a Freedesktop icon theme (Breeze, etc.).
 * On Plasma that is always present. On Hyprland/other WMs, QT_QPA_PLATFORMTHEME=gtk3
 * follows the GTK icon theme — if that theme is missing from XDG_DATA_DIRS (or
 * points at Papirus/Adwaita without those packages), every UI icon vanishes even
 * though the app palette (light/dark) is fine.
 *
 * Always register Breeze as fallback (shipped via KF6/breeze-icons on Nix and
 * usually installed with Plasma tools). If the active theme still cannot resolve
 * a probe icon used in Main.qml, switch the primary theme to Breeze.
 */
void ensureFreedesktopIconTheme()
{
    const auto themeResolvesUiIcons = []() {
        return !QIcon::fromTheme(QStringLiteral("view-refresh")).isNull()
            && !QIcon::fromTheme(QStringLiteral("list-add")).isNull()
            && !QIcon::fromTheme(QStringLiteral("edit-find")).isNull();
    };

    // Prefer an explicit fallback so symbolic icons recolor correctly in light
    // and dark app palettes even when the session theme is incomplete.
    if (QIcon::fallbackThemeName().isEmpty()) {
        QIcon::setFallbackThemeName(QStringLiteral("breeze"));
    }

    if (themeResolvesUiIcons()) {
        return;
    }

    const QString previous = QIcon::themeName();
    for (const QString &candidate : {
             QStringLiteral("breeze"),
             QStringLiteral("breeze-dark"),
             QStringLiteral("Adwaita"),
         }) {
        QIcon::setThemeName(candidate);
        if (themeResolvesUiIcons()) {
            qInfo().noquote() << "Icon theme" << previous
                              << "missing Freedesktop icons; using" << candidate;
            return;
        }
    }

    if (!previous.isEmpty()) {
        QIcon::setThemeName(previous);
    }
    qWarning().noquote()
        << "Freedesktop UI icons could not be resolved. Install breeze-icons "
           "(or ensure your GTK icon theme is on XDG_DATA_DIRS).";
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

bool writeTextFile(const QString &path, const QString &contents)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return false;
    }
    QTextStream out(&file);
    out << contents;
    return true;
}

/**
 * Headless install → rescan smoke test for NixOS/Arch CI and local QA.
 * Usage: sddm-variant-manager --qa-self-test
 */
int runQaSelfTest()
{
    QTemporaryDir themeDir;
    if (!themeDir.isValid()) {
        fprintf(stderr, "QA: could not create temp dir\n");
        return 2;
    }

    const QString root = themeDir.path() + QStringLiteral("/qa-self-test-theme");
    if (!QDir().mkpath(root)) {
        fprintf(stderr, "QA: could not create theme root\n");
        return 2;
    }

    const QString metadata = QStringLiteral(
        "[SddmGreeterTheme]\n"
        "Name=QA Self Test Theme\n"
        "Description=Automated install/rescan check\n"
        "Author=QA\n"
        "License=GPLv3\n"
        "MainScript=Main.qml\n"
        "Theme-Id=qa-self-test-theme\n"
        "Theme-API=2.0\n"
        "QtVersion=6\n");
    if (!writeTextFile(root + QStringLiteral("/metadata.desktop"), metadata)
        || !writeTextFile(root + QStringLiteral("/Main.qml"),
                          QStringLiteral("import QtQuick\nRectangle { color: \"#8B67F2\" }\n"))) {
        fprintf(stderr, "QA: could not write fixture files\n");
        return 2;
    }

    // Also exercise archive install path.
    const QString tar = Platform::absoluteExecutable(QStringLiteral("tar"));
    QString archivePath;
    if (!tar.isEmpty()) {
        archivePath = themeDir.path() + QStringLiteral("/qa-self-test-theme.tar.gz");
        QProcess tarProc;
        tarProc.setWorkingDirectory(themeDir.path());
        tarProc.start(tar, {QStringLiteral("-czf"), archivePath, QStringLiteral("qa-self-test-theme")});
        if (!tarProc.waitForFinished(60000) || tarProc.exitCode() != 0) {
            archivePath.clear();
        }
    }

    ThemeInstaller installer;
    ThemeScanner scanner;

    auto runInstall = [&](const QString &path, const char *label) -> int {
        bool finished = false;
        bool ok = false;
        QString message;
        QStringList ids;

        QEventLoop loop;
        QObject::connect(
            &installer,
            &ThemeInstaller::installFinished,
            &loop,
            [&](bool success, const QString &msg, const QStringList &installedIds) {
                finished = true;
                ok = success;
                message = msg;
                ids = installedIds;
                loop.quit();
            },
            Qt::SingleShotConnection);

        QTimer::singleShot(180000, &loop, &QEventLoop::quit);
        if (!installer.installFromLocalPath(path, false)) {
            fprintf(stderr, "QA[%s]: installFromLocalPath returned false immediately\n", label);
            return 3;
        }
        loop.exec();

        if (!finished) {
            fprintf(stderr, "QA[%s]: timed out waiting for installFinished\n", label);
            return 4;
        }
        if (!ok) {
            fprintf(stderr, "QA[%s]: install failed: %s\n", label, qPrintable(message));
            return 5;
        }
        if (ids.isEmpty()) {
            fprintf(stderr, "QA[%s]: success but no installedThemeIds (%s)\n", label, qPrintable(message));
            return 6;
        }

        scanner.rescan();
        const int index = scanner.themeIndexForId(ids.constFirst());
        if (index < 0) {
            fprintf(stderr,
                    "QA[%s]: theme id '%s' not found after rescan. message=%s userDir=%s themeCount=%d\n",
                    label,
                    qPrintable(ids.constFirst()),
                    qPrintable(message),
                    qPrintable(Platform::userThemeDir()),
                    scanner.themeCount());
            for (int i = 0; i < scanner.themeCount(); ++i) {
                const QVariantMap t = scanner.themeAt(i);
                fprintf(stderr,
                        "  - id=%s path=%s\n",
                        qPrintable(t.value(QStringLiteral("id")).toString()),
                        qPrintable(t.value(QStringLiteral("path")).toString()));
            }
            return 7;
        }

        const QVariantMap theme = scanner.themeAt(index);
        fprintf(stdout,
                "QA[%s]: OK id=%s path=%s message=%s\n",
                label,
                qPrintable(theme.value(QStringLiteral("id")).toString()),
                qPrintable(theme.value(QStringLiteral("path")).toString()),
                qPrintable(message));
        return 0;
    };

    int rc = runInstall(root, "folder");
    if (rc != 0) {
        return rc;
    }

    const QString installedPath = Platform::userThemeDir() + QStringLiteral("/qa-self-test-theme");

    // Remove via ThemeInstaller API (user-path, no pkexec).
    {
        bool finished = false;
        bool ok = false;
        QString message;
        QEventLoop loop;
        QObject::connect(
            &installer,
            &ThemeInstaller::removeFinished,
            &loop,
            [&](bool success, const QString &msg, const QString &) {
                finished = true;
                ok = success;
                message = msg;
                loop.quit();
            },
            Qt::SingleShotConnection);
        QTimer::singleShot(60000, &loop, &QEventLoop::quit);
        if (!installer.canRemoveTheme(installedPath)) {
            fprintf(stderr, "QA[remove]: canRemoveTheme returned false for %s\n", qPrintable(installedPath));
            return 8;
        }
        if (!installer.removeTheme(installedPath)) {
            fprintf(stderr, "QA[remove]: removeTheme returned false immediately\n");
            return 9;
        }
        loop.exec();
        if (!finished || !ok || QFileInfo::exists(installedPath)) {
            fprintf(stderr,
                    "QA[remove]: failed finished=%d ok=%d exists=%d msg=%s\n",
                    finished,
                    ok,
                    QFileInfo::exists(installedPath),
                    qPrintable(message));
            return 10;
        }
        fprintf(stdout, "QA[remove]: OK %s\n", qPrintable(message));
    }

    if (!archivePath.isEmpty()) {
        rc = runInstall(archivePath, "archive");
        if (rc != 0) {
            return rc;
        }
        QDir(installedPath).removeRecursively();
    } else {
        fprintf(stdout, "QA[archive]: skipped (tar not available)\n");
    }

    fprintf(stdout, "QA: all self-tests passed\n");
    return 0;
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

    // Must run before QGuiApplication: platform theme + GSettings are read early.
    prepareDesktopEnvironment();
    // Design-first: Basic Quick Controls chrome; our QML paints the UX Pilot look.
    if (!qEnvironmentVariableIsSet("QT_QUICK_CONTROLS_STYLE")) {
        qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    }

    for (int i = 1; i < argc; ++i) {
        if (QString::fromLocal8Bit(argv[i]) == QLatin1String("--qa-self-test")) {
            QCoreApplication app(argc, argv);
            QCoreApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
            QCoreApplication::setOrganizationName(QStringLiteral("Melker"));
            return runQaSelfTest();
        }
    }

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sddm-variant-manager"));
    QGuiApplication::setOrganizationName(QStringLiteral("Melker"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("github.melker"));
    QGuiApplication::setApplicationVersion(QStringLiteral("2.1.0"));
    QGuiApplication::setQuitOnLastWindowClosed(true);
    QGuiApplication::setDesktopFileName(QString::fromUtf8(kAppIconName));

    // After QGuiApplication exists so platform theme / XDG paths are known.
    ensureFreedesktopIconTheme();

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
        &themeApplier,
        &ThemeApplier::sddmThemeFinished,
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
