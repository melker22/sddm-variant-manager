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
    parts << (m_hasQtMultimedia ? QStringLiteral("QtMultimedia: yes")
                                : QStringLiteral("QtMultimedia: missing"));
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
    m_greeterBinary = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter-qt6"));
    if (m_greeterBinary.isEmpty()) {
        m_greeterBinary = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter"));
    }

    m_hasQtMultimedia = false;
    m_hasQt5Compat = false;
    m_hasQtSvg = false;
    m_hasVirtualKeyboard = false;

    QStringList qmlRoots;

    // Prefer modules exposed by the greeter wrap itself (what the real login uses).
    if (!m_greeterBinary.isEmpty()) {
        QFile greeter(m_greeterBinary);
        if (greeter.open(QIODevice::ReadOnly)) {
            // Wrapper is small; full read is fine. Cap to avoid huge binaries.
            const QByteArray data = greeter.read(4 * 1024 * 1024);
            const QStringList multimediaRoots =
                extractColonPathsFromBinary(data, QByteArrayLiteral("qtmultimedia"));
            for (const QString &root : multimediaRoots) {
                qmlRoots.append(root);
                if (pathProvidesModule(root, QStringLiteral("QtMultimedia"))) {
                    m_hasQtMultimedia = true;
                }
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
        qmlRoots.append(systemQml);
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
            // Svg support is usually via plugins; treat presence of qtsvg plugins nearby.
            QDir plugins(systemQml);
            if (plugins.cdUp() && QDir(plugins.absoluteFilePath(QStringLiteral("plugins/imageformats"))).exists()) {
                m_hasQtSvg = true;
            }
        }
    }

    // Fallback: any qtmultimedia root found via process env (dev shell) is NOT enough
    // for the real greeter — only mark multimedia true if greeter wrap or system profile
    // provides it. (Already handled above.)

    Q_UNUSED(qmlRoots)
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

    return QStringLiteral(
               "Theme “%1” needs %2 in the system SDDM greeter. "
               "The app will not modify the theme. Install the missing module(s) "
               "for SDDM (on NixOS: sddm.extraPackages + nixos-rebuild), then refresh.")
        .arg(themeName, missing.join(QStringLiteral(", ")));
}
