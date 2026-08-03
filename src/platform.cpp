// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "platform.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLibraryInfo>
#include <QStandardPaths>

namespace Platform {

bool isNixOS()
{
    static const bool cached = []() {
        if (QFile::exists(QStringLiteral("/run/current-system"))) {
            return true;
        }

        QFile osRelease(QStringLiteral("/etc/os-release"));
        if (!osRelease.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return false;
        }

        const QByteArray content = osRelease.readAll();
        return content.contains("\nID=nixos") || content.startsWith("ID=nixos");
    }();

    return cached;
}

QStringList systemThemeScanDirs()
{
    QStringList dirs;

    const auto appendExisting = [&dirs](const QString &path) {
        if (path.isEmpty() || dirs.contains(path)) {
            return;
        }
        if (QDir(path).exists()) {
            dirs.append(path);
        }
    };

    if (isNixOS()) {
        appendExisting(QStringLiteral("/run/current-system/sw/share/sddm/themes"));
        // Always include even if missing yet — installer may create it later; scanner
        // still skips non-existing paths in scanBaseDirectory.
        appendExisting(QStringLiteral("/var/lib/sddm/themes"));
    }

    // Arch / Debian / Fedora / most distros
    appendExisting(QStringLiteral("/usr/share/sddm/themes"));
    appendExisting(QStringLiteral("/usr/local/share/sddm/themes"));

    // Extra package roots from XDG (Nix profiles, Flatpak-exported data, etc.)
    const QByteArray xdg = qgetenv("XDG_DATA_DIRS");
    for (const QByteArray &part : xdg.split(':')) {
        if (part.isEmpty()) {
            continue;
        }
        appendExisting(QString::fromLocal8Bit(part) + QStringLiteral("/sddm/themes"));
    }

    return dirs;
}

QString userThemeDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/sddm/themes");
}

QStringList allThemeScanDirs()
{
    QStringList dirs = systemThemeScanDirs();
    const QString userDir = userThemeDir();
    // Always list the user install location (scanner skips if the path is missing).
    if (!userDir.isEmpty() && !dirs.contains(userDir)) {
        dirs.append(userDir);
    }
    return dirs;
}

QString writableSystemThemeDir()
{
    if (isNixOS()) {
        return QStringLiteral("/var/lib/sddm/themes");
    }
    return QStringLiteral("/usr/share/sddm/themes");
}

QString themeDirForThemePath(const QString &themePath)
{
    return QFileInfo(themePath).absolutePath();
}

bool pathIsReadOnly(const QString &path)
{
    if (path.startsWith(QStringLiteral("/nix/store"))
        || path.startsWith(QStringLiteral("/run/current-system"))) {
        return true;
    }

    // Symlinks into the nix store (e.g. under /run/current-system/sw/...)
    const QString canonical = QFileInfo(path).canonicalFilePath();
    return canonical.startsWith(QStringLiteral("/nix/store"));
}

QString absoluteExecutable(const QString &name)
{
    return QStandardPaths::findExecutable(name);
}

QString nixosSddmDropInPath()
{
    return QStringLiteral("/etc/sddm.conf.d/99-sddm-variant-manager.conf");
}

QString systemQmlImportDir()
{
    if (isNixOS()) {
        const QString nixQml = QStringLiteral("/run/current-system/sw/lib/qt-6/qml");
        if (QDir(nixQml).exists()) {
            return nixQml;
        }
    }

    const QStringList candidates = {
        QStringLiteral("/usr/lib/qt6/qml"),
        QStringLiteral("/usr/lib/qml"),
    };
    for (const QString &candidate : candidates) {
        if (QDir(candidate).exists()) {
            return candidate;
        }
    }
    return {};
}

namespace {

void appendExistingDir(QStringList *list, const QString &path)
{
    if (!list || path.isEmpty() || list->contains(path)) {
        return;
    }
    if (QDir(path).exists()) {
        list->append(path);
    }
}

void appendColonEnv(QStringList *list, const char *envName)
{
    const QByteArray raw = qgetenv(envName);
    for (const QByteArray &part : raw.split(':')) {
        if (!part.isEmpty()) {
            appendExistingDir(list, QString::fromLocal8Bit(part));
        }
    }
}

} // namespace

QStringList previewQmlImportPaths()
{
    QStringList paths;

    // 1) Qt used to build/run this app — usually has QtMultimedia (we link it).
    appendExistingDir(&paths, QLibraryInfo::path(QLibraryInfo::QmlImportsPath));

    // 2) Process environment (nix-shell / wrapped package).
    appendColonEnv(&paths, "QML2_IMPORT_PATH");
    appendColonEnv(&paths, "QML_IMPORT_PATH");

    // 3) System / distro roots used by Plasma & SDDM themes.
    appendExistingDir(&paths, systemQmlImportDir());
    appendExistingDir(&paths, QStringLiteral("/run/current-system/sw/lib/qt-6/qml"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib/qt6/qml"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib/qml"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib64/qt6/qml"));

    // 4) Nix user profile (optional multimedia install without full system rebuild).
    const QString home = QDir::homePath();
    if (!home.isEmpty()) {
        appendExistingDir(&paths, home + QStringLiteral("/.nix-profile/lib/qt-6/qml"));
        appendExistingDir(&paths, home + QStringLiteral("/.nix-profile/lib/qt6/qml"));
    }

    // 5) Relative to this binary (some distro layouts).
    const QString appDir = QCoreApplication::applicationDirPath();
    if (!appDir.isEmpty()) {
        appendExistingDir(&paths, QDir(appDir).absoluteFilePath(QStringLiteral("../lib/qt-6/qml")));
        appendExistingDir(&paths, QDir(appDir).absoluteFilePath(QStringLiteral("../lib/qml")));
    }

    return paths;
}

QStringList previewQtPluginPaths()
{
    QStringList paths;

    appendExistingDir(&paths, QLibraryInfo::path(QLibraryInfo::PluginsPath));
    appendColonEnv(&paths, "QT_PLUGIN_PATH");

    appendExistingDir(&paths, QStringLiteral("/run/current-system/sw/lib/qt-6/plugins"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib/qt6/plugins"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib64/qt6/plugins"));
    appendExistingDir(&paths, QStringLiteral("/usr/lib/qt/plugins"));

    const QString home = QDir::homePath();
    if (!home.isEmpty()) {
        appendExistingDir(&paths, home + QStringLiteral("/.nix-profile/lib/qt-6/plugins"));
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    if (!appDir.isEmpty()) {
        appendExistingDir(&paths, QDir(appDir).absoluteFilePath(QStringLiteral("../lib/qt-6/plugins")));
        appendExistingDir(&paths, QDir(appDir).absoluteFilePath(QStringLiteral("../lib/plugins")));
    }

    return paths;
}

} // namespace Platform
