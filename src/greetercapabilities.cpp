// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greetercapabilities.h"
#include "platform.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

namespace {

bool themeTreeNeedsMultimedia(const QString &themePath)
{
    if (themePath.isEmpty() || !QDir(themePath).exists()) {
        return false;
    }

    if (QFile::exists(themePath + QStringLiteral("/BackgroundVideo.qml"))) {
        return true;
    }

    const QString confPath = themePath + QStringLiteral("/theme.conf");
    if (QFile::exists(confPath)) {
        QFile conf(confPath);
        if (conf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray content = conf.readAll().toLower();
            if (content.contains("type=video")
                || content.contains(".mp4")
                || content.contains(".webm")
                || content.contains(".mkv")) {
                return true;
            }
        }
    }

    QDirIterator it(themePath,
                    {QStringLiteral("*.qml"), QStringLiteral("*.conf")},
                    QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        const QByteArray content = file.readAll();
        if (content.contains("QtMultimedia")
            || content.contains("MediaPlayer")
            || content.contains("VideoOutput")
            || content.contains(".mp4")
            || content.contains(".webm")) {
            return true;
        }
    }

    return false;
}

} // namespace

GreeterCapabilities::GreeterCapabilities(QObject *parent)
    : QObject(parent)
{
    refresh();
}

bool GreeterCapabilities::ready() const
{
    return m_ready;
}

bool GreeterCapabilities::isNixOS() const
{
    return Platform::isNixOS();
}

bool GreeterCapabilities::hasQtMultimedia() const
{
    return m_hasQtMultimedia;
}

bool GreeterCapabilities::hasQt5Compat() const
{
    return m_hasQt5Compat;
}

bool GreeterCapabilities::hasQtSvg() const
{
    return m_hasQtSvg;
}

bool GreeterCapabilities::hasVirtualKeyboard() const
{
    return m_hasVirtualKeyboard;
}

bool GreeterCapabilities::previewCanProvideMultimedia() const
{
    return m_previewCanProvideMultimedia;
}

bool GreeterCapabilities::hasQt5Greeter() const
{
    return m_hasQt5Greeter;
}

bool GreeterCapabilities::hasQt6Greeter() const
{
    return m_hasQt6Greeter;
}

int GreeterCapabilities::greeterQtMajor() const
{
    return m_greeterQtMajor;
}

QString GreeterCapabilities::greeterQtLabel() const
{
    if (m_greeterQtMajor == 6) {
        return m_hasQt5Greeter ? QStringLiteral("Qt6 (also has Qt5 greeter)")
                               : QStringLiteral("Qt6");
    }
    if (m_greeterQtMajor == 5) {
        return m_hasQt6Greeter ? QStringLiteral("Qt5 (also has Qt6 greeter)")
                               : QStringLiteral("Qt5");
    }
    return QStringLiteral("Unknown");
}

QString GreeterCapabilities::greeterBinary() const
{
    return m_greeterBinary;
}

QString GreeterCapabilities::summary() const
{
    if (!m_ready) {
        return QStringLiteral("Greeter capabilities not scanned yet.");
    }

    QStringList parts;
    parts << QStringLiteral("Greeter: %1").arg(greeterQtLabel());
    parts << (m_hasQtMultimedia ? QStringLiteral("QtMultimedia: yes")
                                : (m_previewCanProvideMultimedia
                                       ? QStringLiteral("QtMultimedia: preview only")
                                       : QStringLiteral("QtMultimedia: missing")));
    parts << (m_hasQt5Compat ? QStringLiteral("Qt5Compat: yes")
                             : QStringLiteral("Qt5Compat: missing"));
    parts << (m_hasQtSvg ? QStringLiteral("QtSvg: yes") : QStringLiteral("QtSvg: missing"));
    parts << (m_hasVirtualKeyboard ? QStringLiteral("VirtualKeyboard: yes")
                                   : QStringLiteral("VirtualKeyboard: missing"));
    return parts.join(QStringLiteral(" · "));
}

QString GreeterCapabilities::nixosHint() const
{
    return QStringLiteral(
        "On NixOS, add Qt modules to the SDDM greeter wrap, then rebuild:\n\n"
        "services.displayManager.sddm.extraPackages = with pkgs.kdePackages; [\n"
        "  qtmultimedia\n"
        "  qtsvg\n"
        "  qtvirtualkeyboard\n"
        "];\n\n"
        "Also add pkgs.kdePackages.qtmultimedia to environment.systemPackages,\n"
        "then run: sudo nixos-rebuild switch");
}

bool GreeterCapabilities::pathProvidesModule(const QString &qmlRoot, const QString &moduleDir)
{
    return QDir(qmlRoot + QLatin1Char('/') + moduleDir).exists();
}

QStringList GreeterCapabilities::extractColonPathsFromBinary(const QByteArray &data,
                                                             const QByteArray &needle)
{
    QStringList paths;
    int from = 0;
    while (true) {
        const int idx = data.indexOf(needle, from);
        if (idx < 0) {
            break;
        }

        int start = idx;
        while (start > 0) {
            const char c = data.at(start - 1);
            if (c == '\0' || c == '\n' || c == ' ' || c == '\'' || c == '"') {
                break;
            }
            --start;
        }

        int end = idx;
        while (end < data.size()) {
            const char c = data.at(end);
            if (c == '\0' || c == '\n' || c == ' ' || c == '\'' || c == '"') {
                break;
            }
            ++end;
        }

        const QString chunk = QString::fromUtf8(data.mid(start, end - start));
        for (const QString &part : chunk.split(QLatin1Char(':'))) {
            if (part.contains(QString::fromUtf8(needle)) && QDir(part).exists()
                && !paths.contains(part)) {
                paths.append(part);
            }
        }
        from = end + 1;
    }
    return paths;
}

void GreeterCapabilities::refresh()
{
    const QString qt6Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter-qt6"));
    const QString qt5Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter"));
    m_hasQt6Greeter = !qt6Greeter.isEmpty();
    // sddm-greeter is the classic Qt5 binary name; ignore if it somehow points at qt6.
    m_hasQt5Greeter = !qt5Greeter.isEmpty()
        && !QFileInfo(qt5Greeter).fileName().contains(QStringLiteral("qt6"), Qt::CaseInsensitive);

    // Prefer the greeter SDDM is most likely to use: Qt6 when present, else Qt5.
    if (m_hasQt6Greeter) {
        m_greeterBinary = qt6Greeter;
        m_greeterQtMajor = 6;
    } else if (m_hasQt5Greeter) {
        m_greeterBinary = qt5Greeter;
        m_greeterQtMajor = 5;
    } else {
        m_greeterBinary.clear();
        m_greeterQtMajor = 0;
    }

    m_hasQtMultimedia = false;
    m_hasQt5Compat = false;
    m_hasQtSvg = false;
    m_hasVirtualKeyboard = false;
    m_previewCanProvideMultimedia = false;

    // Prefer modules exposed by the greeter wrap itself (what the real login uses).
    if (!m_greeterBinary.isEmpty()) {
        QFile greeter(m_greeterBinary);
        if (greeter.open(QIODevice::ReadOnly)) {
            // Wrapper is small; full read is fine. Cap to avoid huge binaries.
            const QByteArray data = greeter.read(4 * 1024 * 1024);
            const QStringList multimediaRoots =
                extractColonPathsFromBinary(data, QByteArrayLiteral("qtmultimedia"));
            for (const QString &root : multimediaRoots) {
                if (pathProvidesModule(root, QStringLiteral("QtMultimedia"))) {
                    m_hasQtMultimedia = true;
                }
            }
            // makeBinaryWrapper embeds store paths as a blob; detect by substring too.
            if (data.contains("qtmultimedia") || data.contains("QtMultimedia")) {
                m_hasQtMultimedia = true;
            }
            if (data.contains("qt5compat") || data.contains("Qt5Compat")) {
                m_hasQt5Compat = true;
            }
            if (data.contains("qtsvg") || data.contains("/QtQuick/Shapes")
                || data.contains("QtSvg")) {
                m_hasQtSvg = true;
            }
            if (data.contains("qtvirtualkeyboard") || data.contains("QtQuick/VirtualKeyboard")) {
                m_hasVirtualKeyboard = true;
            }
        }
    }

    // Also check the system profile QML root (after nixos-rebuild with extraPackages).
    const QString systemQml = Platform::systemQmlImportDir();
    if (!systemQml.isEmpty()) {
        if (pathProvidesModule(systemQml, QStringLiteral("QtMultimedia"))) {
            m_hasQtMultimedia = true;
        }
        if (pathProvidesModule(systemQml, QStringLiteral("Qt5Compat"))
            || pathProvidesModule(systemQml, QStringLiteral("Qt5Compat/GraphicalEffects"))) {
            m_hasQt5Compat = true;
        }
        if (pathProvidesModule(systemQml, QStringLiteral("QtQuick/VirtualKeyboard"))) {
            m_hasVirtualKeyboard = true;
        }
        if (QDir(systemQml + QStringLiteral("/QtQuick")).exists()) {
            QDir plugins(systemQml);
            if (plugins.cdUp() && QDir(plugins.absoluteFilePath(QStringLiteral("plugins/imageformats"))).exists()) {
                m_hasQtSvg = true;
            }
        }
    }

    // Full Preview can inject this app's Qt + env paths (see GreeterPreview).
    for (const QString &root : Platform::previewQmlImportPaths()) {
        if (pathProvidesModule(root, QStringLiteral("QtMultimedia"))) {
            m_previewCanProvideMultimedia = true;
            break;
        }
    }
    if (m_hasQtMultimedia) {
        m_previewCanProvideMultimedia = true;
    }

    m_ready = true;
    Q_EMIT changed();
}

bool GreeterCapabilities::themeNeedsMultimedia(const QVariantMap &theme) const
{
    if (theme.value(QStringLiteral("requiresMultimedia")).toBool()) {
        return true;
    }
    return themeTreeNeedsMultimedia(theme.value(QStringLiteral("path")).toString());
}

QStringList GreeterCapabilities::missingRequirementsForTheme(const QVariantMap &theme) const
{
    QStringList missing;
    if (themeNeedsMultimedia(theme) && !m_hasQtMultimedia) {
        missing << QStringLiteral("QtMultimedia");
    }

    const QString path = theme.value(QStringLiteral("path")).toString();
    if (!path.isEmpty()) {
        QDirIterator it(path, {QStringLiteral("*.qml")}, QDir::Files, QDirIterator::Subdirectories);
        bool needsQt5Compat = false;
        while (it.hasNext()) {
            QFile file(it.next());
            if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }
            const QByteArray content = file.readAll();
            if (content.contains("Qt5Compat") || content.contains("GraphicalEffects")) {
                needsQt5Compat = true;
                break;
            }
        }
        if (needsQt5Compat && !m_hasQt5Compat) {
            missing << QStringLiteral("Qt5Compat (GraphicalEffects)");
        }
    }

    return missing;
}

QString GreeterCapabilities::advisoryForTheme(const QVariantMap &theme) const
{
    const QStringList missing = missingRequirementsForTheme(theme);
    if (missing.isEmpty()) {
        return {};
    }

    const QString themeName = theme.value(QStringLiteral("name")).toString().isEmpty()
        ? theme.value(QStringLiteral("id")).toString()
        : theme.value(QStringLiteral("name")).toString();

    QString msg = QStringLiteral(
                      "Theme “%1” needs %2 for the real login greeter. "
                      "The theme files are not modified.")
                      .arg(themeName, missing.join(QStringLiteral(", ")));

    if (themeNeedsMultimedia(theme) && m_previewCanProvideMultimedia && !m_hasQtMultimedia) {
        msg += QStringLiteral(
            " Full Preview will inject Qt modules from this app so you can still test. "
            "For the actual login screen on NixOS, add kdePackages.qtmultimedia to "
            "services.displayManager.sddm.extraPackages and nixos-rebuild.");
    } else if (isNixOS()) {
        msg += QStringLiteral(
            " On NixOS: services.displayManager.sddm.extraPackages = with pkgs.kdePackages; "
            "[ qtmultimedia qtsvg qt5compat ]; then nixos-rebuild switch.");
    } else {
        msg += QStringLiteral(
            " On Arch: ensure qt6-multimedia (and qt6-5compat if needed) are installed "
            "so the SDDM greeter can load them.");
    }
    return msg;
}

QString GreeterCapabilities::installNotesForTheme(const QVariantMap &theme) const
{
    QStringList notes;

    const QString qtMismatch = qtCompatibilityWarning(theme);
    if (!qtMismatch.isEmpty()) {
        notes << qtMismatch;
    }

    if (themeNeedsMultimedia(theme)) {
        if (m_hasQtMultimedia) {
            notes << QStringLiteral("Video/multimedia: greeter OK");
        } else if (m_previewCanProvideMultimedia) {
            notes << QStringLiteral(
                "Video theme: Full Preview uses this app’s QtMultimedia. "
                "Real login still needs it on the system SDDM greeter "
                "(NixOS: sddm.extraPackages += kdePackages.qtmultimedia)");
        } else {
            notes << QStringLiteral(
                "Video theme: QtMultimedia missing for greeter and preview. "
                "Install qt6-multimedia / kdePackages.qtmultimedia");
        }
    }

    const QStringList missing = missingRequirementsForTheme(theme);
    for (const QString &m : missing) {
        if (m.startsWith(QStringLiteral("QtMultimedia"))) {
            continue;
        }
        notes << QStringLiteral("Also needs: %1").arg(m);
    }

    return notes.join(QStringLiteral(" · "));
}

bool GreeterCapabilities::themeIncompatibleWithGreeter(const QVariantMap &theme) const
{
    return !qtCompatibilityWarning(theme).isEmpty();
}

QString GreeterCapabilities::qtCompatibilityWarning(const QVariantMap &theme) const
{
    if (theme.isEmpty()) {
        return {};
    }

    const QString stack = theme.value(QStringLiteral("qtStack")).toString();
    const bool themeIsQt5 = theme.value(QStringLiteral("requiresQt5")).toBool()
        || stack == QStringLiteral("Qt5");
    const bool themeIsQt6 = theme.value(QStringLiteral("requiresQt6")).toBool()
        || stack == QStringLiteral("Qt6");

    // Theme Qt5, system greeter is Qt6-only → Layan-style failure.
    if (themeIsQt5 && m_hasQt6Greeter && !m_hasQt5Greeter) {
        return QStringLiteral(
            "Incompatible: this theme is Qt5, but your SDDM greeter is Qt6 only "
            "(sddm-greeter-qt6). It will not load correctly at login "
            "(QtQuick.Controls 1.x / old APIs). Use a Qt6 theme, or install a Qt5 greeter "
            "if your distro still ships sddm-greeter.");
    }

    // Theme Qt5, both greeters present — SDDM often still prefers Qt6.
    if (themeIsQt5 && m_hasQt6Greeter && m_hasQt5Greeter) {
        return QStringLiteral(
            "Warning: this theme is Qt5. Your system also has a Qt6 greeter; SDDM may use "
            "sddm-greeter-qt6 by default and fail to load this theme at login.");
    }

    // Theme Qt6, system greeter is Qt5-only → reverse case the user asked about.
    if (themeIsQt6 && m_hasQt5Greeter && !m_hasQt6Greeter) {
        return QStringLiteral(
            "Incompatible: this theme is Qt6, but your SDDM greeter is Qt5 only "
            "(sddm-greeter). It will not load correctly at login. Use a Qt5 theme, or "
            "upgrade SDDM to a Qt6 greeter (sddm-greeter-qt6).");
    }

    // Theme Qt6, both present — usually OK if Qt6 is preferred.
    if (themeIsQt6 && m_hasQt5Greeter && m_hasQt6Greeter) {
        return {};
    }

    // Theme Qt5, greeter Qt5 only — OK.
    // Theme Qt6, greeter Qt6 only — OK.
    return {};
}
