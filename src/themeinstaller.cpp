// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themeinstaller.h"
#include "platform.h"

#include <KTar>
#include <KZip>

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

#include <memory>

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

void ThemeInstaller::beginInstallJob()
{
    setInstalling(true);
    setProgressMessage(QStringLiteral("Starting installation…"));
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

    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    const QString mkdir = Platform::absoluteExecutable(QStringLiteral("mkdir"));
    if (cp.isEmpty() || mkdir.isEmpty()) {
        return false;
    }

    const QString parentDir = QFileInfo(destination).absolutePath();
    QProcess mkdirProcess;
    mkdirProcess.start(QStringLiteral("pkexec"),
                       {mkdir, QStringLiteral("-p"), parentDir});
    if (!mkdirProcess.waitForStarted() || !mkdirProcess.waitForFinished(120000)
        || mkdirProcess.exitCode() != 0) {
        return false;
    }

    QProcess process;
    process.start(QStringLiteral("pkexec"),
                  {cp, QStringLiteral("-r"), source, destination});
    if (!process.waitForStarted() || !process.waitForFinished(120000)) {
        return false;
    }
    return process.exitCode() == 0;
}

bool ThemeInstaller::prepareInstallBase(const QString &installBase, bool systemWide, QString *error)
{
    if (!systemWide) {
        if (!QDir().mkpath(installBase)) {
            *error = QStringLiteral("Could not create %1.").arg(installBase);
            return false;
        }
        return true;
    }

    if (Platform::isNixOS()) {
        const QString mkdir = Platform::absoluteExecutable(QStringLiteral("mkdir"));
        if (mkdir.isEmpty()) {
            *error = QStringLiteral("mkdir was not found; cannot create %1.").arg(installBase);
            return false;
        }
        QProcess mkdirProcess;
        mkdirProcess.start(QStringLiteral("pkexec"), {mkdir, QStringLiteral("-p"), installBase});
        if (!mkdirProcess.waitForStarted() || !mkdirProcess.waitForFinished(120000)
            || mkdirProcess.exitCode() != 0) {
            *error = QStringLiteral("Failed to create %1 (authentication may have been cancelled).")
                         .arg(installBase);
            return false;
        }
    }

    return true;
}

bool ThemeInstaller::isSupportedArchive(const QString &filePath)
{
    const QString name = QFileInfo(filePath).fileName().toLower();
    return name.endsWith(QStringLiteral(".zip"))
        || name.endsWith(QStringLiteral(".tar"))
        || name.endsWith(QStringLiteral(".tar.gz"))
        || name.endsWith(QStringLiteral(".tgz"))
        || name.endsWith(QStringLiteral(".tar.xz"))
        || name.endsWith(QStringLiteral(".txz"))
        || name.endsWith(QStringLiteral(".tar.bz2"))
        || name.endsWith(QStringLiteral(".tbz2"))
        || name.endsWith(QStringLiteral(".tar.zst"))
        || name.endsWith(QStringLiteral(".tzst"));
}

bool ThemeInstaller::extractArchive(const QString &archivePath, const QString &destinationDir, QString *error)
{
    const QString name = QFileInfo(archivePath).fileName().toLower();
    std::unique_ptr<KArchive> archive;

    if (name.endsWith(QStringLiteral(".zip"))) {
        archive = std::make_unique<KZip>(archivePath);
    } else if (name.endsWith(QStringLiteral(".tar"))
               || name.endsWith(QStringLiteral(".tar.gz"))
               || name.endsWith(QStringLiteral(".tgz"))
               || name.endsWith(QStringLiteral(".tar.xz"))
               || name.endsWith(QStringLiteral(".txz"))
               || name.endsWith(QStringLiteral(".tar.bz2"))
               || name.endsWith(QStringLiteral(".tbz2"))
               || name.endsWith(QStringLiteral(".tar.zst"))
               || name.endsWith(QStringLiteral(".tzst"))) {
        archive = std::make_unique<KTar>(archivePath);
    } else {
        *error = QStringLiteral("Unsupported archive format. Use zip, tar, tar.gz, tar.xz, tar.bz2, or tar.zst.");
        return false;
    }

    if (!archive->open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Could not open archive: %1").arg(archivePath);
        return false;
    }

    const KArchiveDirectory *root = archive->directory();
    if (!root) {
        *error = QStringLiteral("Archive is empty or unreadable.");
        return false;
    }

    if (!root->copyTo(destinationDir, true)) {
        *error = QStringLiteral("Failed to extract archive contents.");
        return false;
    }

    return true;
}

bool ThemeInstaller::installFromUrl(const QString &url, bool systemWide)
{
    if (m_installing) {
        Q_EMIT installFinished(false, QStringLiteral("An installation is already in progress."), {});
        return false;
    }

    if (!gitAvailable()) {
        Q_EMIT installFinished(false,
                               QStringLiteral("git is not installed. Install it with your package manager (e.g. nix profile add nixpkgs#git, pacman -S git)."),
                               {});
        return false;
    }

    QString normalizedUrl;
    QString validationError;
    if (!normalizeGitHubUrl(url, &normalizedUrl, &validationError)) {
        Q_EMIT installFinished(false, validationError, {});
        return false;
    }

    beginInstallJob();

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

        QMetaObject::invokeMethod(this, [this]() {
            setProgressMessage(QStringLiteral("Looking for SDDM themes…"));
        }, Qt::QueuedConnection);

        const QStringList themeRoots = findThemeRoots(tempDir.path());
        if (themeRoots.isEmpty()) {
            finish(false, QStringLiteral("No SDDM themes found in the repository (metadata.desktop missing)."));
            return;
        }

        const QString userBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/sddm/themes");
        const QString systemBase = Platform::writableSystemThemeDir();
        const QString installBase = systemWide ? systemBase : userBase;

        QString prepareError;
        if (!prepareInstallBase(installBase, systemWide, &prepareError)) {
            finish(false, prepareError);
            return;
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

bool ThemeInstaller::installFromLocalPath(const QString &path, bool systemWide)
{
    if (m_installing) {
        Q_EMIT installFinished(false, QStringLiteral("An installation is already in progress."), {});
        return false;
    }

    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty()) {
        Q_EMIT installFinished(false, QStringLiteral("Choose a theme folder or archive file."), {});
        return false;
    }

    // Support file:// URLs from drag-and-drop / dialogs.
    QString localPath = trimmed;
    const QUrl url(trimmed);
    if (url.isLocalFile()) {
        localPath = url.toLocalFile();
    }

    const QFileInfo info(localPath);
    if (!info.exists()) {
        Q_EMIT installFinished(false, QStringLiteral("Path does not exist: %1").arg(localPath), {});
        return false;
    }

    beginInstallJob();

    if (info.isDir()) {
        (void)QtConcurrent::run([this, localPath, systemWide]() {
            QStringList installedThemeIds;

            auto finish = [this, &installedThemeIds](bool success, const QString &message) {
                QMetaObject::invokeMethod(this, [this, success, message, installedThemeIds]() {
                    setInstalling(false);
                    setProgressMessage(success ? QStringLiteral("Installation finished.") : message);
                    Q_EMIT installFinished(success, message, installedThemeIds);
                }, Qt::QueuedConnection);
            };

            QMetaObject::invokeMethod(this, [this]() {
                setProgressMessage(QStringLiteral("Looking for SDDM themes…"));
            }, Qt::QueuedConnection);

            const QStringList themeRoots = findThemeRoots(localPath);
            if (themeRoots.isEmpty()) {
                finish(false, QStringLiteral("No SDDM themes found in the folder (metadata.desktop missing)."));
                return;
            }

            const QString userBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + QStringLiteral("/sddm/themes");
            const QString systemBase = Platform::writableSystemThemeDir();
            const QString installBase = systemWide ? systemBase : userBase;

            QString prepareError;
            if (!prepareInstallBase(installBase, systemWide, &prepareError)) {
                finish(false, prepareError);
                return;
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

    if (!info.isFile()) {
        setInstalling(false);
        Q_EMIT installFinished(false, QStringLiteral("Path must be a folder or an archive file."), {});
        return false;
    }

    if (!isSupportedArchive(localPath)) {
        setInstalling(false);
        Q_EMIT installFinished(false,
                               QStringLiteral("Unsupported archive format. Use zip, tar, tar.gz, tar.xz, tar.bz2, or tar.zst."),
                               {});
        return false;
    }

    (void)QtConcurrent::run([this, localPath, systemWide]() {
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
            setProgressMessage(QStringLiteral("Extracting archive…"));
        }, Qt::QueuedConnection);

        QString extractError;
        if (!extractArchive(localPath, tempDir.path(), &extractError)) {
            finish(false, extractError);
            return;
        }

        QMetaObject::invokeMethod(this, [this]() {
            setProgressMessage(QStringLiteral("Looking for SDDM themes…"));
        }, Qt::QueuedConnection);

        const QStringList themeRoots = findThemeRoots(tempDir.path());
        if (themeRoots.isEmpty()) {
            finish(false, QStringLiteral("No SDDM themes found in the archive (metadata.desktop missing)."));
            return;
        }

        const QString userBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/sddm/themes");
        const QString systemBase = Platform::writableSystemThemeDir();
        const QString installBase = systemWide ? systemBase : userBase;

        QString prepareError;
        if (!prepareInstallBase(installBase, systemWide, &prepareError)) {
            finish(false, prepareError);
            return;
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
