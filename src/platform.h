// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QString>
#include <QStringList>

namespace Platform {

bool isNixOS();

/** Traditional / NixOS read-only theme roots shipped with the system. */
QStringList systemThemeScanDirs();

/** Writable location for system-wide theme installs. */
QString writableSystemThemeDir();

/** Parent directory of an installed theme (used as SDDM ThemeDir). */
QString themeDirForThemePath(const QString &themePath);

/** True for paths under /nix/store or /run/current-system (immutable). */
bool pathIsReadOnly(const QString &path);

/** Absolute path to a binary for pkexec (NixOS-safe). Empty if not found. */
QString absoluteExecutable(const QString &name);

/** NixOS drop-in that overrides 00-nixos.conf Theme settings. */
QString nixosSddmDropInPath();

/**
 * System QML import root that ships Plasma/Breeze modules (needed by SDDM
 * greeter --test-mode on NixOS when the parent process has a narrow
 * QML2_IMPORT_PATH from nix-shell / Qt Creator).
 */
QString systemQmlImportDir();

} // namespace Platform
