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
#include <QTextStream>
#include <QtConcurrent>
#include <QUrl>

#include <memory>

namespace {

QString shellQuote(const QString &value)
{
    return QLatin1Char('\'')
        + QString(value).replace(QLatin1Char('\''), QStringLiteral("'\\''"))
        + QLatin1Char('\'');
}

/**
 * After installing under /var/lib/sddm/themes (NixOS), the parent /var/lib/sddm
 * is often mode 0700 (sddm's home). Without world-execute on that home, the
 * desktop user cannot read themes for the library UI or post-install checks.
 * o+x allows path traversal to known subdirs without listing the home.
 */
QString ensureSystemThemeReadableSnippet(const QString &destination, const QString &chmod)
{
    const QString parent = QFileInfo(destination).absolutePath(); // .../themes
    const QString sddmHome = QFileInfo(parent).absolutePath();    // .../sddm or similar

    QString snippet;
    // Only relax the sddm state home when we actually install under it.
    if (sddmHome.endsWith(QStringLiteral("/sddm")) || sddmHome.endsWith(QStringLiteral("/sddm/"))) {
        snippet += QStringLiteral("%1 o+x %2 2>/dev/null || true; ")
                       .arg(shellQuote(chmod), shellQuote(sddmHome));
    }
    snippet += QStringLiteral("%1 -R a+rX %2 && %1 a+rx %3")
                   .arg(shellQuote(chmod), shellQuote(destination), shellQuote(parent));
    return snippet;
}

} // namespace

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

bool ThemeInstaller::pathIsUnderThemeInstallRoot(const QString &themePath, bool *systemWideOut)
{
    if (themePath.isEmpty()) {
        return false;
    }

    const QString canonical = QFileInfo(themePath).canonicalFilePath();
    const QString path = canonical.isEmpty() ? QFileInfo(themePath).absoluteFilePath() : canonical;

    const QString userDir = QFileInfo(Platform::userThemeDir()).absoluteFilePath();
    const QString systemDir = QFileInfo(Platform::writableSystemThemeDir()).absoluteFilePath();
    const QString usrShare = QStringLiteral("/usr/share/sddm/themes");
    const QString usrLocal = QStringLiteral("/usr/local/share/sddm/themes");

    auto under = [&path](const QString &root) {
        if (root.isEmpty()) {
            return false;
        }
        return path == root || path.startsWith(root + QLatin1Char('/'));
    };

    if (under(userDir)) {
        if (systemWideOut) {
            *systemWideOut = false;
        }
        return true;
    }

    if (under(systemDir) || under(usrShare) || under(usrLocal)) {
        if (systemWideOut) {
            *systemWideOut = true;
        }
        return true;
    }

    return false;
}

bool ThemeInstaller::canRemoveTheme(const QString &themePath) const
{
    if (themePath.trimmed().isEmpty() || !QFileInfo::exists(themePath)) {
        return false;
    }
    if (Platform::pathIsReadOnly(themePath)) {
        return false;
    }
    return pathIsUnderThemeInstallRoot(themePath);
}

bool ThemeInstaller::removeTheme(const QString &themePath)
{
    if (m_installing) {
        Q_EMIT removeFinished(false, QStringLiteral("Another operation is already in progress."), {});
        return false;
    }

    QString path = themePath.trimmed();
    const QUrl url(path);
    if (url.isLocalFile()) {
        path = url.toLocalFile();
    }

    if (path.isEmpty() || !QFileInfo::exists(path)) {
        Q_EMIT removeFinished(false, QStringLiteral("Theme path does not exist."), {});
        return false;
    }

    if (Platform::pathIsReadOnly(path)) {
        Q_EMIT removeFinished(
            false,
            QStringLiteral("This theme is read-only (Nix store / system image) and cannot be deleted from the app."),
            {});
        return false;
    }

    bool systemWide = false;
    if (!pathIsUnderThemeInstallRoot(path, &systemWide)) {
        Q_EMIT removeFinished(
            false,
            QStringLiteral("Refusing to delete a path outside known SDDM theme directories."),
            {});
        return false;
    }

    if (!QFile::exists(path + QStringLiteral("/metadata.desktop"))) {
        Q_EMIT removeFinished(false, QStringLiteral("Not a theme directory (metadata.desktop missing)."), {});
        return false;
    }

    const QString themeId = QFileInfo(path).fileName();
    beginInstallJob();
    setProgressMessage(QStringLiteral("Removing %1…").arg(themeId));

    (void)QtConcurrent::run([this, path, systemWide, themeId]() {
        QString error;
        const bool ok = removePathRecursively(path, systemWide, &error);
        QMetaObject::invokeMethod(this, [this, ok, error, themeId, path]() {
            setInstalling(false);
            if (ok) {
                setProgressMessage(QStringLiteral("Theme removed."));
                Q_EMIT removeFinished(true,
                                      QStringLiteral("Removed theme “%1” (%2).").arg(themeId, path),
                                      themeId);
            } else {
                setProgressMessage(error);
                Q_EMIT removeFinished(false,
                                      error.isEmpty()
                                          ? QStringLiteral("Failed to remove theme “%1”.").arg(themeId)
                                          : error,
                                      themeId);
            }
        }, Qt::QueuedConnection);
    });

    return true;
}

bool ThemeInstaller::isValidThemeRoot(const QString &themeRoot)
{
    const QString metadataPath = themeRoot + QStringLiteral("/metadata.desktop");
    if (!QFile::exists(metadataPath)) {
        return false;
    }

    // Readable metadata is the SDDM contract. Prefer a QML entry point when present,
    // but do not reject classic themes solely because MainScript path is odd.
    const QString mainScript = readMetadataKey(themeRoot, QStringLiteral("MainScript"));
    if (!mainScript.isEmpty() && QFile::exists(themeRoot + QLatin1Char('/') + mainScript)) {
        return true;
    }

    if (QFile::exists(themeRoot + QStringLiteral("/Main.qml"))
        || QFile::exists(themeRoot + QStringLiteral("/main.qml"))) {
        return true;
    }

    const QString name = readMetadataKey(themeRoot, QStringLiteral("Name"));
    const QString type = readMetadataKey(themeRoot, QStringLiteral("Type")).toLower();
    const QString themeId = readMetadataKey(themeRoot, QStringLiteral("Theme-Id"));
    const QString id = readMetadataKey(themeRoot, QStringLiteral("Id"));

    // [SddmGreeterTheme] themes always have Name= in practice.
    if (!name.isEmpty()
        || !themeId.isEmpty()
        || !id.isEmpty()
        || type.contains(QStringLiteral("sddm"))
        || !mainScript.isEmpty()) {
        QDir dir(themeRoot);
        const QStringList qml = dir.entryList({QStringLiteral("*.qml")}, QDir::Files);
        if (!qml.isEmpty() || !mainScript.isEmpty() || !name.isEmpty()) {
            return true;
        }
    }

    return false;
}

bool ThemeInstaller::themeLooksInstalled(const QString &themePath)
{
    return isValidThemeRoot(themePath);
}

QStringList ThemeInstaller::findThemeRoots(const QString &rootPath)
{
    QStringList themeRoots;
    if (rootPath.isEmpty() || !QDir(rootPath).exists()) {
        return themeRoots;
    }

    // Prefer a root that itself is a theme (folder/file drop of a single theme).
    if (isValidThemeRoot(rootPath)) {
        themeRoots.append(QFileInfo(rootPath).absoluteFilePath());
        return themeRoots;
    }

    QDirIterator iterator(rootPath,
                          {QStringLiteral("metadata.desktop")},
                          QDir::Files,
                          QDirIterator::Subdirectories);

    while (iterator.hasNext()) {
        const QString metadataPath = iterator.next();
        const QString themeRoot = QFileInfo(metadataPath).absolutePath();
        if (themeRoots.contains(themeRoot)) {
            continue;
        }
        if (!isValidThemeRoot(themeRoot)) {
            continue;
        }
        themeRoots.append(themeRoot);
    }

    return themeRoots;
}

bool ThemeInstaller::looksLikeTempFolderName(const QString &name)
{
    if (name.isEmpty()) {
        return true;
    }
    // QTemporaryDir uses applicationName + random suffix by default.
    if (name.startsWith(QStringLiteral("sddm-variant-manager-"), Qt::CaseInsensitive)) {
        return true;
    }
    static const QRegularExpression qtTemp(
        QStringLiteral(R"(^(?:tmp|temp|qt_temp)[-_.].+)"),
        QRegularExpression::CaseInsensitiveOption);
    return qtTemp.match(name).hasMatch();
}

QString ThemeInstaller::sanitizeFolderName(const QString &raw)
{
    QString name = raw.trimmed();
    if (name.isEmpty()) {
        return {};
    }

    // Drop path separators and control characters; keep a stable SDDM-friendly id.
    name.replace(QRegularExpression(QStringLiteral(R"([\\/]+)")), QStringLiteral("-"));
    name.replace(QRegularExpression(QStringLiteral(R"([^\w.\-]+)")), QStringLiteral("-"));
    name.replace(QRegularExpression(QStringLiteral(R"(-{2,})")), QStringLiteral("-"));
    while (name.startsWith(QLatin1Char('-')) || name.startsWith(QLatin1Char('.'))) {
        name.remove(0, 1);
    }
    while (name.endsWith(QLatin1Char('-')) || name.endsWith(QLatin1Char('.'))) {
        name.chop(1);
    }

    if (name.isEmpty() || looksLikeTempFolderName(name)) {
        return {};
    }
    return name;
}

QString ThemeInstaller::readMetadataKey(const QString &themeRoot, const QString &key)
{
    const QString metadataPath = themeRoot + QStringLiteral("/metadata.desktop");
    QFile file(metadataPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    QTextStream in(&file);
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.startsWith(key + QLatin1Char('='))) {
            QString value = line.mid(key.size() + 1).trimmed();
            if (value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"'))) {
                value = value.mid(1, value.size() - 2);
            }
            return value;
        }
    }
    return {};
}

QString ThemeInstaller::resolveInstallFolderName(const QString &themeRoot, const QString &preferredHint)
{
    // Prefer stable ids from metadata so temp-dir clones never become install names.
    const QStringList metadataKeys = {
        QStringLiteral("Theme-Id"),
        QStringLiteral("Id"),
        QStringLiteral("Theme-ID"),
        QStringLiteral("Name"),
    };
    for (const QString &key : metadataKeys) {
        const QString candidate = sanitizeFolderName(readMetadataKey(themeRoot, key));
        if (!candidate.isEmpty()) {
            return candidate;
        }
    }

    const QString hint = sanitizeFolderName(preferredHint);
    if (!hint.isEmpty()) {
        return hint;
    }

    const QString dirName = QFileInfo(themeRoot).fileName();
    const QString fromDir = sanitizeFolderName(dirName);
    if (!fromDir.isEmpty()) {
        return fromDir;
    }

    return QStringLiteral("sddm-theme");
}

QString ThemeInstaller::uniqueInstallPath(const QString &baseDir, const QString &folderName)
{
    // Always install to a stable path derived from Theme-Id/Name. Reinstalls
    // overwrite (installDirectory removes the previous tree first) so the theme
    // stays visible under the same library id instead of quiet name-2 clones.
    if (baseDir.isEmpty() || folderName.isEmpty()) {
        return {};
    }
    return baseDir + QDir::separator() + folderName;
}

bool ThemeInstaller::removePathRecursively(const QString &path, bool systemWide, QString *error)
{
    if (path.isEmpty() || !QFileInfo::exists(path)) {
        return true;
    }

    if (!systemWide) {
        if (QFileInfo(path).isDir()) {
            if (!QDir(path).removeRecursively()) {
                if (error) {
                    *error = QStringLiteral("Could not remove existing directory: %1").arg(path);
                }
                return false;
            }
        } else if (!QFile::remove(path)) {
            if (error) {
                *error = QStringLiteral("Could not remove existing file: %1").arg(path);
            }
            return false;
        }
        return true;
    }

    const QString rm = Platform::absoluteExecutable(QStringLiteral("rm"));
    if (rm.isEmpty()) {
        if (error) {
            *error = QStringLiteral("rm was not found.");
        }
        return false;
    }

    QProcess process;
    process.start(QStringLiteral("pkexec"), {rm, QStringLiteral("-rf"), path});
    if (!process.waitForStarted() || !process.waitForFinished(120000) || process.exitCode() != 0) {
        if (error) {
            *error = QStringLiteral("Failed to remove %1 (authentication may have been cancelled).").arg(path);
        }
        return false;
    }
    return true;
}

bool ThemeInstaller::copyDirectory(const QString &source, const QString &destination, QString *error)
{
    QDir sourceDir(source);
    if (!sourceDir.exists()) {
        if (error) {
            *error = QStringLiteral("Source theme directory does not exist: %1").arg(source);
        }
        return false;
    }

    // Prefer system cp -a: handles symlinks, permissions, and large trees better
    // than QFile::copy on Linux (Arch / NixOS / Fedora).
    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    if (!cp.isEmpty()) {
        QDir().mkpath(QFileInfo(destination).absolutePath());
        if (QFileInfo::exists(destination)) {
            QString removeError;
            if (!removePathRecursively(destination, false, &removeError)) {
                if (error) {
                    *error = removeError;
                }
                return false;
            }
        }

        QProcess process;
        process.start(cp, {QStringLiteral("-a"), source, destination});
        if (process.waitForStarted() && process.waitForFinished(600000) && process.exitCode() == 0
            && themeLooksInstalled(destination)) {
            return true;
        }
        // Fall through to Qt copy if cp failed (busybox quirks, etc.).
        if (QFileInfo::exists(destination)) {
            QDir(destination).removeRecursively();
        }
    }

    QDir destinationDir;
    if (!destinationDir.mkpath(destination)) {
        if (error) {
            *error = QStringLiteral("Could not create destination: %1").arg(destination);
        }
        return false;
    }

    QDirIterator iterator(source,
                          QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString sourcePath = iterator.next();
        const QString relativePath = sourceDir.relativeFilePath(sourcePath);
        const QString destinationPath = destination + QDir::separator() + relativePath;

        const QFileInfo info(sourcePath);
        if (info.isDir()) {
            if (!destinationDir.mkpath(destinationPath)) {
                if (error) {
                    *error = QStringLiteral("Could not create %1").arg(destinationPath);
                }
                return false;
            }
            continue;
        }

        QDir().mkpath(QFileInfo(destinationPath).absolutePath());
        if (QFile::exists(destinationPath)) {
            QFile::remove(destinationPath);
        }
        if (!QFile::copy(sourcePath, destinationPath)) {
            if (error) {
                *error = QStringLiteral("Failed to copy %1 → %2").arg(sourcePath, destinationPath);
            }
            return false;
        }
    }

    if (!themeLooksInstalled(destination)) {
        if (error) {
            *error = QStringLiteral("Copy finished but %1 is not a valid SDDM theme (metadata/MainScript missing).")
                         .arg(destination);
        }
        return false;
    }

    return true;
}

bool ThemeInstaller::installDirectory(const QString &source,
                                      const QString &destination,
                                      bool systemWide,
                                      QString *error)
{
    if (!systemWide) {
        return copyDirectory(source, destination, error);
    }

    const QString sh = Platform::absoluteExecutable(QStringLiteral("sh"));
    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    const QString mkdir = Platform::absoluteExecutable(QStringLiteral("mkdir"));
    const QString rm = Platform::absoluteExecutable(QStringLiteral("rm"));
    const QString chmod = Platform::absoluteExecutable(QStringLiteral("chmod"));
    const QString test = Platform::absoluteExecutable(QStringLiteral("test"));
    if (sh.isEmpty() || cp.isEmpty() || mkdir.isEmpty() || rm.isEmpty() || chmod.isEmpty()
        || test.isEmpty()) {
        if (error) {
            *error = QStringLiteral("Required tools (sh/cp/mkdir/rm/chmod/test) not found on PATH.");
        }
        return false;
    }

    // IMPORTANT: do not use QFileInfo::exists(destination) as the unprivileged user.
    // On NixOS, /var/lib/sddm is often mode 0700 (sddm home), so exists() is false even
    // when the theme dir is already there. Then `cp -a src dest` nests as dest/basename(src).
    const QString parentDir = QFileInfo(destination).absolutePath();
    const QString metaCheck = destination + QStringLiteral("/metadata.desktop");

    // Single privileged transaction: mkdir, replace dest, copy, fix perms, validate as root.
    const QString script =
        QStringLiteral("%1 -p %2"
                       " && %3 -rf %4"
                       " && %5 -a %6 %4"
                       " && %7"
                       " && %8 -f %9")
            .arg(shellQuote(mkdir),
                 shellQuote(parentDir),
                 shellQuote(rm),
                 shellQuote(destination),
                 shellQuote(cp),
                 shellQuote(source),
                 ensureSystemThemeReadableSnippet(destination, chmod),
                 shellQuote(test),
                 shellQuote(metaCheck));

    QProcess process;
    process.start(QStringLiteral("pkexec"), {sh, QStringLiteral("-c"), script});
    if (!process.waitForStarted() || !process.waitForFinished(600000)) {
        if (error) {
            *error = QStringLiteral("Timed out while installing theme system-wide.");
        }
        return false;
    }
    if (process.exitCode() != 0) {
        if (error) {
            const QString details = QString::fromUtf8(process.readAllStandardError()).trimmed();
            *error = details.isEmpty()
                         ? QStringLiteral(
                               "Failed to install system-wide (authentication may have been cancelled, "
                               "or the theme is missing metadata.desktop).")
                         : details;
        }
        return false;
    }

    // Prefer a user-visible check after chmod o+x on sddm home; if still unreadable,
    // root already validated metadata.desktop via `test -f` above — treat as success.
    if (!themeLooksInstalled(destination) && !QFile::exists(metaCheck)) {
        // Still unreadable by this user, but root verified the file exists.
        return true;
    }

    return true;
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

    if (QDir(installBase).exists()) {
        return true;
    }

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

    if (!QDir().mkpath(destinationDir)) {
        *error = QStringLiteral("Could not create extract directory: %1").arg(destinationDir);
        return false;
    }

    if (!root->copyTo(destinationDir, true)) {
        *error = QStringLiteral("Failed to extract archive contents.");
        return false;
    }

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
                finish(false,
                       QStringLiteral("No valid SDDM themes found in the folder "
                                      "(need metadata.desktop + MainScript/Main.qml)."));
                return;
            }

            const QString userBase = Platform::userThemeDir();
            const QString systemBase = Platform::writableSystemThemeDir();
            const QString installBase = systemWide ? systemBase : userBase;

            QString prepareError;
            if (!prepareInstallBase(installBase, systemWide, &prepareError)) {
                finish(false, prepareError);
                return;
            }

            QStringList installedPaths;
            for (const QString &themeRoot : themeRoots) {
                const QString folderName =
                    resolveInstallFolderName(themeRoot, QFileInfo(localPath).fileName());
                const QString destination = uniqueInstallPath(installBase, folderName);
                if (destination.isEmpty()) {
                    finish(false, QStringLiteral("Could not choose a destination folder for %1.").arg(folderName));
                    return;
                }

                QMetaObject::invokeMethod(this, [this, folderName]() {
                    setProgressMessage(QStringLiteral("Installing %1…").arg(folderName));
                }, Qt::QueuedConnection);

                QString installError;
                if (!installDirectory(themeRoot, destination, systemWide, &installError)) {
                    finish(false,
                           installError.isEmpty()
                               ? QStringLiteral("Failed to install %1.").arg(folderName)
                               : installError);
                    return;
                }

                installedThemeIds.append(QFileInfo(destination).fileName());
                installedPaths.append(destination);
            }

            finish(true,
                   installedThemeIds.size() == 1
                       ? QStringLiteral("Installed theme “%1” → %2")
                             .arg(installedThemeIds.constFirst(), installedPaths.constFirst())
                       : QStringLiteral("Installed %1 themes under %2.")
                             .arg(installedThemeIds.size())
                             .arg(installBase));
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

        // Always extract into a neutral directory. Archives usually already contain
        // a top-level theme folder (e.g. Layan/…); naming extractRoot after the
        // archive basename created Layan/Layan nests and bad installs.
        // Prefer archive stem without multi-part suffixes (.tar.gz / .tar.xz / …).
        QString archiveStem = QFileInfo(localPath).fileName();
        static const QStringList multiSuffixes = {
            QStringLiteral(".tar.gz"),  QStringLiteral(".tgz"),
            QStringLiteral(".tar.xz"),  QStringLiteral(".txz"),
            QStringLiteral(".tar.bz2"), QStringLiteral(".tbz2"),
            QStringLiteral(".tar.zst"), QStringLiteral(".tzst"),
        };
        const QString lowerName = archiveStem.toLower();
        for (const QString &suffix : multiSuffixes) {
            if (lowerName.endsWith(suffix)) {
                archiveStem.chop(suffix.size());
                break;
            }
        }
        if (archiveStem == QFileInfo(localPath).fileName()) {
            archiveStem = QFileInfo(localPath).completeBaseName();
        }
        const QString archiveHint = sanitizeFolderName(archiveStem);
        const QString extractRoot = tempDir.path() + QDir::separator() + QStringLiteral("extracted");

        QString extractError;
        if (!extractArchive(localPath, extractRoot, &extractError)) {
            finish(false, extractError);
            return;
        }

        QMetaObject::invokeMethod(this, [this]() {
            setProgressMessage(QStringLiteral("Looking for SDDM themes…"));
        }, Qt::QueuedConnection);

        const QStringList themeRoots = findThemeRoots(extractRoot);
        if (themeRoots.isEmpty()) {
            finish(false,
                   QStringLiteral("No valid SDDM themes found in the archive "
                                  "(need metadata.desktop + MainScript/Main.qml)."));
            return;
        }

        const QString userBase = Platform::userThemeDir();
        const QString systemBase = Platform::writableSystemThemeDir();
        const QString installBase = systemWide ? systemBase : userBase;

        QString prepareError;
        if (!prepareInstallBase(installBase, systemWide, &prepareError)) {
            finish(false, prepareError);
            return;
        }

        QStringList installedPaths;
        for (const QString &themeRoot : themeRoots) {
            const QString folderName = resolveInstallFolderName(themeRoot, archiveHint);
            const QString destination = uniqueInstallPath(installBase, folderName);
            if (destination.isEmpty()) {
                finish(false, QStringLiteral("Could not choose a destination folder for %1.").arg(folderName));
                return;
            }

            QMetaObject::invokeMethod(this, [this, folderName]() {
                setProgressMessage(QStringLiteral("Installing %1…").arg(folderName));
            }, Qt::QueuedConnection);

            QString installError;
            if (!installDirectory(themeRoot, destination, systemWide, &installError)) {
                finish(false,
                       installError.isEmpty()
                           ? QStringLiteral("Failed to install %1.").arg(folderName)
                           : installError);
                return;
            }

            installedThemeIds.append(QFileInfo(destination).fileName());
            installedPaths.append(destination);
        }

        finish(true,
               installedThemeIds.size() == 1
                   ? QStringLiteral("Installed theme “%1” → %2")
                         .arg(installedThemeIds.constFirst(), installedPaths.constFirst())
                   : QStringLiteral("Installed %1 themes under %2.")
                         .arg(installedThemeIds.size())
                         .arg(installBase));
    });

    return true;
}
