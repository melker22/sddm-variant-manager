// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themeinstaller.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtConcurrent>
#include <QUrl>

ThemeInstaller::ThemeInstaller(QObject *parent)
    : QObject(parent)
{
}

bool ThemeInstaller::installing() const
{
    return m_installing;
}

QString ThemeInstaller::progressMessage() const
{
    return m_progressMessage;
}

bool ThemeInstaller::gitAvailable() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("git")).isEmpty();
}

void ThemeInstaller::setInstalling(bool installing)
{
    if (m_installing == installing) {
        return;
    }
    m_installing = installing;
    Q_EMIT installingChanged();
}

void ThemeInstaller::setProgressMessage(const QString &message)
{
    if (m_progressMessage == message) {
        return;
    }
    m_progressMessage = message;
    Q_EMIT progressMessageChanged();
}

bool ThemeInstaller::normalizeGitHubUrl(const QString &input, QString *normalizedUrl, QString *error)
{
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty()) {
        *error = QStringLiteral("Enter a GitHub repository URL.");
        return false;
    }

    if (trimmed.startsWith(QStringLiteral("git@github.com:"))) {
        static const QRegularExpression sshPattern(
            QStringLiteral(R"(^git@github\.com:([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$)"));
        const QRegularExpressionMatch match = sshPattern.match(trimmed);
        if (!match.hasMatch()) {
            *error = QStringLiteral("Invalid SSH GitHub URL. Example: git@github.com:user/repo.git");
            return false;
        }
        *normalizedUrl = QStringLiteral("https://github.com/%1/%2.git")
                             .arg(match.captured(1), match.captured(2));
        return true;
    }

    QUrl url(trimmed);
    if (!url.isValid() || url.host().toLower() != QStringLiteral("github.com")) {
        *error = QStringLiteral("Only public GitHub repositories are supported.");
        return false;
    }

    const QStringList parts = url.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (parts.size() < 2) {
        *error = QStringLiteral("Invalid GitHub repository URL.");
        return false;
    }

    QString repo = parts.at(1);
    if (repo.endsWith(QStringLiteral(".git"))) {
        repo.chop(4);
    }

    *normalizedUrl = QStringLiteral("https://github.com/%1/%2.git").arg(parts.constFirst(), repo);
    return true;
}

QStringList ThemeInstaller::findThemeRoots(const QString &rootPath)
{
    QStringList themeRoots;
    QDirIterator iterator(rootPath,
                          {QStringLiteral("metadata.desktop")},
                          QDir::Files,
                          QDirIterator::Subdirectories);

    while (iterator.hasNext()) {
        const QString metadataPath = iterator.next();
        const QString themeRoot = QFileInfo(metadataPath).absolutePath();
        if (!themeRoots.contains(themeRoot)) {
            themeRoots.append(themeRoot);
        }
    }

    return themeRoots;
}

QString ThemeInstaller::uniqueInstallPath(const QString &baseDir, const QString &folderName)
{
    QString candidate = baseDir + QDir::separator() + folderName;
    if (!QFile::exists(candidate)) {
        return candidate;
    }

    for (int suffix = 2; suffix < 100; ++suffix) {
        candidate = baseDir + QDir::separator() + folderName + QStringLiteral("-") + QString::number(suffix);
        if (!QFile::exists(candidate)) {
            return candidate;
        }
    }

    return {};
}

bool ThemeInstaller::copyDirectory(const QString &source, const QString &destination)
{
    QDir sourceDir(source);
    if (!sourceDir.exists()) {
        return false;
    }

    QDir destinationDir;
    if (!destinationDir.mkpath(destination)) {
        return false;
    }

    QDirIterator iterator(source, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString sourcePath = iterator.next();
        const QString relativePath = sourceDir.relativeFilePath(sourcePath);
        const QString destinationPath = destination + QDir::separator() + relativePath;

        const QFileInfo info(sourcePath);
        if (info.isDir()) {
            if (!destinationDir.mkpath(destinationPath)) {
                return false;
            }
            continue;
        }

        QDir().mkpath(QFileInfo(destinationPath).absolutePath());
        if (QFile::exists(destinationPath)) {
            QFile::remove(destinationPath);
        }
        if (!QFile::copy(sourcePath, destinationPath)) {
            return false;
        }
    }

    return true;
}

bool ThemeInstaller::installDirectory(const QString &source, const QString &destination, bool systemWide)
{
    if (!systemWide) {
        return copyDirectory(source, destination);
    }

    QProcess process;
    process.start(QStringLiteral("pkexec"),
                  {QStringLiteral("cp"), QStringLiteral("-r"), source, destination});
    if (!process.waitForStarted() || !process.waitForFinished(120000)) {
        return false;
    }
    return process.exitCode() == 0;
}

bool ThemeInstaller::installFromUrl(const QString &url, bool systemWide)
{
    if (m_installing) {
        Q_EMIT installFinished(false, QStringLiteral("An installation is already in progress."), {});
        return false;
    }

    if (!gitAvailable()) {
        Q_EMIT installFinished(false, QStringLiteral("git is not installed. Install it with: pamac install git"), {});
        return false;
    }

    QString normalizedUrl;
    QString validationError;
    if (!normalizeGitHubUrl(url, &normalizedUrl, &validationError)) {
        Q_EMIT installFinished(false, validationError, {});
        return false;
    }

    setInstalling(true);
    setProgressMessage(QStringLiteral("Starting installation…"));

    (void)QtConcurrent::run([this, normalizedUrl, systemWide]() {
        QStringList installedThemeIds;

        auto finish = [this, &installedThemeIds](bool success, const QString &message) {
            QMetaObject::invokeMethod(this, [this, success, message, installedThemeIds]() {
                setInstalling(false);
                setProgressMessage(success ? QStringLiteral("Installation finished.") : message);
                Q_EMIT installFinished(success, message, installedThemeIds);
            }, Qt::QueuedConnection);
        };

        QTemporaryDir tempDir;
        if (!tempDir.isValid()) {
            finish(false, QStringLiteral("Could not create a temporary directory."));
            return;
        }

        QMetaObject::invokeMethod(this, [this]() {
            setProgressMessage(QStringLiteral("Cloning repository…"));
        }, Qt::QueuedConnection);

        QProcess cloneProcess;
        cloneProcess.start(QStandardPaths::findExecutable(QStringLiteral("git")),
                           {QStringLiteral("clone"), QStringLiteral("--depth"), QStringLiteral("1"),
                            normalizedUrl, tempDir.path()});
        if (!cloneProcess.waitForFinished(180000) || cloneProcess.exitCode() != 0) {
            const QString details = QString::fromUtf8(cloneProcess.readAllStandardError()).trimmed();
            finish(false,
                   details.isEmpty() ? QStringLiteral("git clone failed.")
                                     : QStringLiteral("git clone failed: %1").arg(details));
            return;
        }

        const QStringList themeRoots = findThemeRoots(tempDir.path());
        if (themeRoots.isEmpty()) {
            finish(false, QStringLiteral("No SDDM themes found in the repository (metadata.desktop missing)."));
            return;
        }

        const QString userBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/sddm/themes");
        const QString systemBase = QStringLiteral("/usr/share/sddm/themes");
        const QString installBase = systemWide ? systemBase : userBase;

        if (!systemWide) {
            QDir().mkpath(installBase);
        }

        for (const QString &themeRoot : themeRoots) {
            const QString folderName = QFileInfo(themeRoot).fileName();
            const QString destination = uniqueInstallPath(installBase, folderName);
            if (destination.isEmpty()) {
                finish(false, QStringLiteral("Could not choose a destination folder for %1.").arg(folderName));
                return;
            }

            QMetaObject::invokeMethod(this, [this, folderName]() {
                setProgressMessage(QStringLiteral("Installing %1…").arg(folderName));
            }, Qt::QueuedConnection);

            if (!installDirectory(themeRoot, destination, systemWide)) {
                finish(false,
                       systemWide
                           ? QStringLiteral("Failed to install %1 system-wide (authentication may have been cancelled).")
                                 .arg(folderName)
                           : QStringLiteral("Failed to install %1.").arg(folderName));
                return;
            }

            installedThemeIds.append(QFileInfo(destination).fileName());
        }

        finish(true,
               installedThemeIds.size() == 1
                   ? QStringLiteral("Installed 1 theme: %1").arg(installedThemeIds.constFirst())
                   : QStringLiteral("Installed %1 themes.").arg(installedThemeIds.size()));
    });

    return true;
}
