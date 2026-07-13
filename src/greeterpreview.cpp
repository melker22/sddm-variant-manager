// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"
#include "platform.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTemporaryFile>
#include <QTextStream>

namespace {

QString readMetadataValue(const QString &metadataPath, const QString &key)
{
    QFile file(metadataPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.startsWith(key + QLatin1Char('='))) {
            return line.mid(key.size() + 1).trimmed();
        }
    }

    return {};
}

bool copyDirectoryRecursive(const QString &source, const QString &destination)
{
    QDir sourceDir(source);
    if (!sourceDir.exists()) {
        return false;
    }

    QDir().mkpath(destination);

    QDirIterator iterator(source, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString sourcePath = iterator.next();
        const QString relativePath = sourceDir.relativeFilePath(sourcePath);
        const QString destinationPath = destination + QDir::separator() + relativePath;
        const QFileInfo info(sourcePath);

        if (info.isDir()) {
            if (!QDir().mkpath(destinationPath)) {
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

bool writeConfigFileLocal(const QString &metadataPath, const QString &configFile)
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

} // namespace

GreeterPreview::GreeterPreview(QObject *parent)
    : QObject(parent)
{
    connect(&m_greeterProcess, &QProcess::finished, this, &GreeterPreview::onGreeterFinished);
    m_greeterProcess.setProcessEnvironment(QProcessEnvironment::systemEnvironment());
    m_greeterProcess.setProcessChannelMode(QProcess::MergedChannels);
}

GreeterPreview::~GreeterPreview()
{
    stopPreview();
}

bool GreeterPreview::running() const
{
    return m_greeterProcess.state() != QProcess::NotRunning;
}

QString GreeterPreview::greeterBinaryForTheme(const QString &metadataPath) const
{
    const QString qt6Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter-qt6"));
    const QString qt5Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter"));
    const QString qtVersion = readMetadataValue(metadataPath, QStringLiteral("QtVersion"));

    if (qtVersion == QStringLiteral("6")) {
        return qt6Greeter.isEmpty() ? qt5Greeter : qt6Greeter;
    }

    return qt5Greeter.isEmpty() ? qt6Greeter : qt5Greeter;
}

bool GreeterPreview::backupMetadata(const QString &metadataPath)
{
    m_originalMetadataPath = metadataPath;
    m_backupMetadataPath = metadataPath + QStringLiteral(".sddmvm-preview-backup");

    if (QFile::exists(m_backupMetadataPath)) {
        QFile::remove(m_backupMetadataPath);
    }

    return QFile::copy(metadataPath, m_backupMetadataPath);
}

bool GreeterPreview::restoreMetadata()
{
    // Temp-copy previews never touch the original theme directory and normally
    // have no metadata backup — but still drop any leftover backup from a
    // previous failed non-temp restore before resetting state.
    if (m_usingTempThemeCopy) {
        if (!m_backupMetadataPath.isEmpty()) {
            QFile::remove(m_backupMetadataPath);
        }
        m_modifiedMetadata = false;
        m_originalMetadataPath.clear();
        m_backupMetadataPath.clear();
        m_usingTempThemeCopy = false;
        m_tempThemeDir.reset();
        return true;
    }

    if (!m_modifiedMetadata || m_originalMetadataPath.isEmpty() || m_backupMetadataPath.isEmpty()) {
        return true;
    }

    if (QFileInfo(m_originalMetadataPath).isWritable()) {
        if (QFile::exists(m_originalMetadataPath)) {
            QFile::remove(m_originalMetadataPath);
        }
        const bool ok = QFile::copy(m_backupMetadataPath, m_originalMetadataPath);
        if (ok) {
            QFile::remove(m_backupMetadataPath);
            m_modifiedMetadata = false;
            m_originalMetadataPath.clear();
            m_backupMetadataPath.clear();
        }
        return ok;
    }

    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    if (cp.isEmpty()) {
        return false;
    }

    QProcess process;
    process.start(QStringLiteral("pkexec"), {cp, m_backupMetadataPath, m_originalMetadataPath});
    if (!process.waitForStarted() || !process.waitForFinished(120000)) {
        return false;
    }

    if (process.exitCode() == 0) {
        QFile::remove(m_backupMetadataPath);
        m_modifiedMetadata = false;
        m_originalMetadataPath.clear();
        m_backupMetadataPath.clear();
    }

    return process.exitCode() == 0;
}

bool GreeterPreview::writeConfigFileLine(const QString &metadataPath, const QString &configFile)
{
    if (QFileInfo(metadataPath).isWritable()) {
        return writeConfigFileLocal(metadataPath, configFile);
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

    QProcess process;
    process.start(QStringLiteral("pkexec"), {cp, tempFile.fileName(), metadataPath});
    if (!process.waitForStarted() || !process.waitForFinished(120000)) {
        return false;
    }
    return process.exitCode() == 0;
}

void GreeterPreview::preview(const QString &themePath, const QString &metadataPath, const QString &configFile)
{
    if (running()) {
        Q_EMIT previewFinished(false, QStringLiteral("A preview is already running."));
        return;
    }

    m_stoppedByUser = false;
    m_usingTempThemeCopy = false;
    m_tempThemeDir.reset();
    // Drop leftovers from a previous failed restore before starting a new preview.
    if (!m_backupMetadataPath.isEmpty()) {
        QFile::remove(m_backupMetadataPath);
        m_backupMetadataPath.clear();
    }
    m_modifiedMetadata = false;
    m_originalMetadataPath.clear();

    const QString greeter = greeterBinaryForTheme(metadataPath);
    if (greeter.isEmpty()) {
        Q_EMIT previewFinished(false, QStringLiteral("Neither sddm-greeter nor sddm-greeter-qt6 was found."));
        return;
    }

    if (!QFile::exists(themePath)) {
        Q_EMIT previewFinished(false, QStringLiteral("Theme directory not found."));
        return;
    }

    const bool modifyMetadata = !configFile.isEmpty();
    QString previewThemePath = themePath;
    QString previewMetadataPath = metadataPath;

    if (modifyMetadata) {
        // Read-only themes (Nix store): copy to a temp dir and edit there — no pkexec.
        if (Platform::pathIsReadOnly(themePath) || !QFileInfo(metadataPath).isWritable()) {
            m_tempThemeDir = std::make_unique<QTemporaryDir>();
            if (!m_tempThemeDir->isValid()) {
                Q_EMIT previewFinished(false, QStringLiteral("Could not create a temporary theme copy."));
                return;
            }

            const QString tempThemePath =
                m_tempThemeDir->path() + QDir::separator() + QFileInfo(themePath).fileName();
            if (!copyDirectoryRecursive(themePath, tempThemePath)) {
                m_tempThemeDir.reset();
                Q_EMIT previewFinished(false, QStringLiteral("Could not copy theme for preview."));
                return;
            }

            previewThemePath = tempThemePath;
            previewMetadataPath = tempThemePath + QStringLiteral("/metadata.desktop");
            if (!writeConfigFileLocal(previewMetadataPath, configFile)) {
                m_tempThemeDir.reset();
                Q_EMIT previewFinished(false, QStringLiteral("Could not set preview variant in temporary copy."));
                return;
            }

            m_usingTempThemeCopy = true;
            m_modifiedMetadata = true;
            m_originalMetadataPath = previewMetadataPath;
            m_backupMetadataPath.clear();
        } else {
            if (!backupMetadata(metadataPath)) {
                Q_EMIT previewFinished(false, QStringLiteral("Could not back up metadata.desktop."));
                return;
            }

            if (!writeConfigFileLine(metadataPath, configFile)) {
                restoreMetadata();
                Q_EMIT previewFinished(false, QStringLiteral("Could not set preview variant (authentication may have been cancelled)."));
                return;
            }

            m_modifiedMetadata = true;
        }
    } else {
        m_modifiedMetadata = false;
        m_originalMetadataPath.clear();
        m_backupMetadataPath.clear();
    }

    m_greeterProcess.setWorkingDirectory(previewThemePath);

    // The greeter needs Plasma/Breeze QML modules. When launched from nix-shell
    // or Qt Creator, QML2_IMPORT_PATH is often too narrow and hides the system
    // modules that SDDM themes (e.g. Breeze) import.
    QProcessEnvironment greeterEnv = QProcessEnvironment::systemEnvironment();
    const QString systemQml = Platform::systemQmlImportDir();
    if (!systemQml.isEmpty()) {
        const auto prependImportPath = [&greeterEnv, &systemQml](const QString &key) {
            const QString existing = greeterEnv.value(key);
            if (existing.isEmpty()) {
                greeterEnv.insert(key, systemQml);
            } else if (!existing.split(QLatin1Char(':')).contains(systemQml)) {
                greeterEnv.insert(key, systemQml + QLatin1Char(':') + existing);
            }
        };
        prependImportPath(QStringLiteral("QML2_IMPORT_PATH"));
        prependImportPath(QStringLiteral("QML_IMPORT_PATH"));
    }
    m_greeterProcess.setProcessEnvironment(greeterEnv);

    m_greeterProcess.start(greeter,
                           {QStringLiteral("--test-mode"),
                            QStringLiteral("--theme"),
                            previewThemePath});

    if (!m_greeterProcess.waitForStarted(5000)) {
        const QString details = QString::fromUtf8(m_greeterProcess.readAll()).trimmed();
        if (modifyMetadata) {
            restoreMetadata();
        }
        Q_EMIT previewFinished(false,
                               details.isEmpty()
                                   ? QStringLiteral("Failed to start SDDM greeter preview.")
                                   : QStringLiteral("Failed to start SDDM greeter preview: %1").arg(details));
        return;
    }

    Q_EMIT runningChanged();
}

void GreeterPreview::stopPreview()
{
    if (m_greeterProcess.state() == QProcess::NotRunning) {
        return;
    }

    m_stoppedByUser = true;
    m_greeterProcess.terminate();
    if (!m_greeterProcess.waitForFinished(2000)) {
        m_greeterProcess.kill();
        m_greeterProcess.waitForFinished(3000);
    }
}

void GreeterPreview::onGreeterFinished(int exitCode, QProcess::ExitStatus status)
{
    Q_UNUSED(status)

    const bool hadMetadataChanges = m_modifiedMetadata;
    const bool usedTempCopy = m_usingTempThemeCopy;
    const QString details = QString::fromUtf8(m_greeterProcess.readAll()).trimmed();
    const bool userStopped = m_stoppedByUser;
    m_stoppedByUser = false;
    const bool restored = restoreMetadata();
    Q_EMIT runningChanged();

    const bool closedNormally = userStopped || exitCode == 0 || exitCode == 15;

    QString message;
    if (!restored) {
        message = QStringLiteral("Preview closed, but metadata restore failed.");
    } else if (closedNormally) {
        message = hadMetadataChanges && !usedTempCopy
                      ? QStringLiteral("Preview closed. Theme metadata restored.")
                      : QStringLiteral("Preview closed.");
    } else if (!details.isEmpty()) {
        message = QStringLiteral("Preview failed: %1").arg(details);
    } else {
        message = QStringLiteral("Preview failed (exit code %1).").arg(exitCode);
    }

    Q_EMIT previewFinished(restored && closedNormally, message);
}
