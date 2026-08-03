// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QString>
#include <QStringList>

namespace Platform {

bool isNixOS();

/** Traditional / NixOS read-only theme roots shipped with the system. */
QStringList systemThemeScanDirs();

/**
 * Every directory that may contain SDDM themes: system roots, XDG_DATA_DIRS,
 * and the per-user install location (~/.local/share/sddm/themes).
 */
QStringList allThemeScanDirs();

/** Per-user writable theme directory (~/.local/share/sddm/themes). */
QString userThemeDir();

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

/**
 * QML import roots for Full Preview: this app's Qt (includes Multimedia when
 * linked), system profile, common distro paths, and any roots already in the
 * process environment. Used so sddm-greeter --test-mode can load modules that
 * the system greeter wrap may not ship.
 */
QStringList previewQmlImportPaths();

/** Qt plugin roots for Full Preview (multimedia backends, imageformats, …). */
QStringList previewQtPluginPaths();

} // namespace Platform
