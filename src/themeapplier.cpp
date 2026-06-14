// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themeapplier.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTextStream>

ThemeApplier::ThemeApplier(QObject *parent)
    : QObject(parent)
{
}

bool ThemeApplier::runPkexecCommand(const QStringList &arguments, int timeoutMs)
{
    QProcess process;
    process.start(QStringLiteral("pkexec"), arguments);
    if (!process.waitForStarted()) {
        return false;
    }
    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        return false;
    }
    return process.exitCode() == 0;
}

bool ThemeApplier::writeConfigFileLine(const QString &metadataPath, const QString &configFile)
{
    QFile input(metadataPath);
    if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }

    QStringList lines;
    QTextStream in(&input);
    bool replaced = false;
    while (!in.atEnd()) {
        QString line = in.readLine();
        if (line.startsWith(QStringLiteral("ConfigFile="))) {
            line = QStringLiteral("ConfigFile=") + configFile;
            replaced = true;
        }
        lines.append(line);
    }
    input.close();

    if (!replaced) {
        lines.append(QStringLiteral("ConfigFile=") + configFile);
    }

    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    if (!tempFile.open()) {
        return false;
    }

    QTextStream out(&tempFile);
    for (const QString &line : lines) {
        out << line << '\n';
    }
    out.flush();
    tempFile.close();

    return runPkexecCommand({QStringLiteral("cp"), tempFile.fileName(), metadataPath});
}

bool ThemeApplier::applyVariant(const QString &metadataPath, const QString &configFile)
{
    if (metadataPath.isEmpty() || configFile.isEmpty()) {
        Q_EMIT applyFinished(false, QStringLiteral("Invalid theme metadata path or config file."));
        return false;
    }

    if (!QFile::exists(metadataPath)) {
        Q_EMIT applyFinished(false, QStringLiteral("metadata.desktop not found."));
        return false;
    }

    const bool ok = writeConfigFileLine(metadataPath, configFile);
    Q_EMIT applyFinished(ok, ok ? QStringLiteral("Variant applied successfully.")
                                  : QStringLiteral("Failed to write metadata.desktop (authentication may have been cancelled)."));
    return ok;
}

bool ThemeApplier::applySimpleTheme(const QString &themeId, bool activateInSddm)
{
    if (themeId.isEmpty()) {
        Q_EMIT applyFinished(false, QStringLiteral("Invalid theme id."));
        return false;
    }

    if (!activateInSddm) {
        Q_EMIT applyFinished(true, QStringLiteral("SDDM theme activation skipped."));
        return true;
    }

    const bool ok = setSddmCurrentTheme(themeId, true);
    Q_EMIT applyFinished(ok,
                         ok ? QStringLiteral("Theme applied as SDDM current theme.")
                            : QStringLiteral("Failed to update SDDM current theme."));
    return ok;
}

bool ThemeApplier::setSddmCurrentTheme(const QString &themeId, bool enabled)
{
    if (!enabled) {
        Q_EMIT sddmThemeFinished(true, QStringLiteral("SDDM theme activation skipped."));
        return true;
    }

    const QString kdeSettings = QStringLiteral("/etc/sddm.conf.d/kde_settings.conf");
    if (!QFile::exists(kdeSettings)) {
        Q_EMIT sddmThemeFinished(false, QStringLiteral("kde_settings.conf not found."));
        return false;
    }

    const bool ok = runPkexecCommand(
        {QStringLiteral("sed"),
         QStringLiteral("-i"),
         QStringLiteral("s|^Current=.*|Current=%1|").arg(themeId),
         kdeSettings});

    Q_EMIT sddmThemeFinished(
        ok,
        ok ? QStringLiteral("SDDM current theme updated.")
           : QStringLiteral("Failed to update SDDM current theme."));
    return ok;
}
