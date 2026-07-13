// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "platform.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
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

    if (isNixOS()) {
        const QString nixThemes = QStringLiteral("/run/current-system/sw/share/sddm/themes");
        if (QDir(nixThemes).exists()) {
            dirs.append(nixThemes);
        }
        const QString varThemes = QStringLiteral("/var/lib/sddm/themes");
        if (QDir(varThemes).exists()) {
            dirs.append(varThemes);
        }
    }

    const QString usrThemes = QStringLiteral("/usr/share/sddm/themes");
    if (QDir(usrThemes).exists() && !dirs.contains(usrThemes)) {
        dirs.append(usrThemes);
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

} // namespace Platform
