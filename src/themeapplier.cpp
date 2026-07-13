// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themeapplier.h"
#include "platform.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QTemporaryFile>
#include <QTextStream>

namespace {

QString shellQuote(const QString &value)
{
    return QLatin1Char('\'')
        + QString(value).replace(QLatin1Char('\''), QStringLiteral("'\\''"))
        + QLatin1Char('\'');
}

} // namespace

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
    if (Platform::pathIsReadOnly(metadataPath)) {
        return false;
    }

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

    if (!Platform::pathIsReadOnly(metadataPath)
        && QFileInfo(metadataPath).isWritable()) {
        QFile output(metadataPath);
        if (!output.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            return false;
        }
        QTextStream out(&output);
        for (const QString &line : lines) {
            out << line << '\n';
        }
        return true;
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

    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    if (cp.isEmpty()) {
        return false;
    }

    return runPkexecCommand({cp, tempFile.fileName(), metadataPath});
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

    if (Platform::pathIsReadOnly(metadataPath)) {
        Q_EMIT applyFinished(
            false,
            QStringLiteral("This theme is read-only (Nix store). Install a writable copy "
                           "(system-wide on NixOS goes to /var/lib/sddm/themes) before applying variants."));
        return false;
    }

    const bool ok = writeConfigFileLine(metadataPath, configFile);
    Q_EMIT applyFinished(ok, ok ? QStringLiteral("Variant applied successfully.")
                                  : QStringLiteral("Failed to write metadata.desktop (authentication may have been cancelled)."));
    return ok;
}

bool ThemeApplier::applySimpleTheme(const QString &themeId, bool activateInSddm, const QString &themePath)
{
    if (themeId.isEmpty()) {
        Q_EMIT applyFinished(false, QStringLiteral("Invalid theme id."));
        return false;
    }

    if (!activateInSddm) {
        Q_EMIT applyFinished(true, QStringLiteral("SDDM theme activation skipped."));
        return true;
    }

    const bool ok = setSddmCurrentTheme(themeId, true, themePath);
    Q_EMIT applyFinished(ok,
                         ok ? QStringLiteral("Theme applied as SDDM current theme.")
                            : QStringLiteral("Failed to update SDDM current theme."));
    return ok;
}

bool ThemeApplier::writeNixosSddmDropIn(const QString &themeId, const QString &themePath)
{
    if (themePath.isEmpty() || !QFile::exists(themePath) || themeId.isEmpty()) {
        return false;
    }

    // Themes under $HOME are not readable by the sddm system user (home is often
    // mode 700). Publish an unmodified copy under the writable system ThemeDir.
    const QString homePath = QDir::homePath();
    const QString canonicalTheme = QFileInfo(themePath).canonicalFilePath();
    const bool underHome = !homePath.isEmpty()
        && (themePath.startsWith(homePath + QLatin1Char('/'))
            || (!canonicalTheme.isEmpty()
                && canonicalTheme.startsWith(homePath + QLatin1Char('/'))));

    QString themeDir = Platform::themeDirForThemePath(themePath);
    const QString publishSourcePath = themePath;

    if (underHome) {
        themeDir = Platform::writableSystemThemeDir();
    }

    const QString effectiveThemePath = underHome
        ? (themeDir + QLatin1Char('/') + themeId)
        : themePath;

    const QString dropInPath = Platform::nixosSddmDropInPath();
    const QString sh = Platform::absoluteExecutable(QStringLiteral("sh"));
    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    const QString mkdir = Platform::absoluteExecutable(QStringLiteral("mkdir"));
    const QString chmod = Platform::absoluteExecutable(QStringLiteral("chmod"));
    const QString install = Platform::absoluteExecutable(QStringLiteral("install"));
    const QString rm = Platform::absoluteExecutable(QStringLiteral("rm"));
    if (sh.isEmpty() || cp.isEmpty() || mkdir.isEmpty() || chmod.isEmpty()
        || install.isEmpty() || rm.isEmpty()) {
        return false;
    }

    QTemporaryFile tempFile;
    tempFile.setAutoRemove(true);
    if (!tempFile.open()) {
        return false;
    }

    QTextStream out(&tempFile);
    out << "# Generated by SDDM Variant Manager — overrides Theme settings from 00-nixos.conf\n";
    out << "[Theme]\n";
    out << "Current=" << themeId << '\n';
    out << "ThemeDir=" << themeDir << '\n';
    out.flush();
    tempFile.close();

    // Single pkexec: create dirs, copy theme unchanged, install drop-in as 644.
    QString script = QStringLiteral("%1 -p /etc/sddm.conf.d").arg(shellQuote(mkdir));
    if (underHome) {
        script += QStringLiteral(" && %1 -p %2"
                                 " && %3 -rf %4"
                                 " && %5 -a %6 %4"
                                 " && %7 -R a+rX %2")
                      .arg(shellQuote(mkdir),
                           shellQuote(themeDir),
                           shellQuote(rm),
                           shellQuote(effectiveThemePath),
                           shellQuote(cp),
                           shellQuote(publishSourcePath),
                           shellQuote(chmod));
    }
    script += QStringLiteral(" && %1 -m 644 %2 %3")
                  .arg(shellQuote(install),
                       shellQuote(tempFile.fileName()),
                       shellQuote(dropInPath));

    return runPkexecCommand({sh, QStringLiteral("-c"), script}, 300000);
}

bool ThemeApplier::setSddmCurrentTheme(const QString &themeId, bool enabled, const QString &themePath)
{
    if (!enabled) {
        Q_EMIT sddmThemeFinished(true, QStringLiteral("SDDM theme activation skipped."));
        return true;
    }

    if (Platform::isNixOS()) {
        const bool ok = writeNixosSddmDropIn(themeId, themePath);
        Q_EMIT sddmThemeFinished(
            ok,
            ok ? QStringLiteral("SDDM current theme updated (NixOS drop-in). Log out to see it.")
               : QStringLiteral("Failed to write /etc/sddm.conf.d/99-sddm-variant-manager.conf "
                                "(authentication may have been cancelled, or theme path missing)."));
        return ok;
    }

    const QString kdeSettings = QStringLiteral("/etc/sddm.conf.d/kde_settings.conf");
    if (!QFile::exists(kdeSettings)) {
        Q_EMIT sddmThemeFinished(false, QStringLiteral("kde_settings.conf not found."));
        return false;
    }

    const QString sed = Platform::absoluteExecutable(QStringLiteral("sed"));
    if (sed.isEmpty()) {
        Q_EMIT sddmThemeFinished(false, QStringLiteral("sed was not found."));
        return false;
    }

    const bool ok = runPkexecCommand(
        {sed,
         QStringLiteral("-i"),
         QStringLiteral("s|^Current=.*|Current=%1|").arg(themeId),
         kdeSettings});

    Q_EMIT sddmThemeFinished(
        ok,
        ok ? QStringLiteral("SDDM current theme updated.")
           : QStringLiteral("Failed to update SDDM current theme."));
    return ok;
}
