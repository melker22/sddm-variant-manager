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
#include <QRegularExpression>
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
    // Prefer cp -a: large video assets, symlinks, modes — QFile::copy is fragile.
    const QString cp = Platform::absoluteExecutable(QStringLiteral("cp"));
    if (!cp.isEmpty()) {
        if (QFileInfo::exists(destination)) {
            QDir(destination).removeRecursively();
        }
        QDir().mkpath(QFileInfo(destination).absolutePath());
        QProcess process;
        process.start(cp, {QStringLiteral("-a"), source, destination});
        if (process.waitForStarted() && process.waitForFinished(600000) && process.exitCode() == 0
            && QDir(destination).exists()) {
            return true;
        }
        if (QFileInfo::exists(destination)) {
            QDir(destination).removeRecursively();
        }
    }

    QDir sourceDir(source);
    if (!sourceDir.exists()) {
        return false;
    }

    QDir().mkpath(destination);

    QDirIterator iterator(source,
                          QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden,
                          QDirIterator::Subdirectories);
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

void prependColonEnv(QProcessEnvironment *env, const QString &key, const QStringList &paths)
{
    if (!env || paths.isEmpty()) {
        return;
    }
    QStringList merged = paths;
    const QString existing = env->value(key);
    if (!existing.isEmpty()) {
        for (const QString &part : existing.split(QLatin1Char(':'))) {
            if (!part.isEmpty() && !merged.contains(part)) {
                merged.append(part);
            }
        }
    }
    env->insert(key, merged.join(QLatin1Char(':')));
}

QString humanizeGreeterFailure(const QString &details)
{
    const QString lower = details.toLower();
    if ((lower.contains(QStringLiteral("qtquick.controls")) && lower.contains(QStringLiteral("1.")))
        || lower.contains(QStringLiteral("controls.styles"))
        || (lower.contains(QStringLiteral("graphicaleffects")) && lower.contains(QStringLiteral("1.")))) {
        return QStringLiteral(
            "Preview failed: this theme is Qt5, not Qt6 "
            "(QtQuick.Controls 1.x / QtGraphicalEffects / Controls.Styles). "
            "Your greeter is sddm-greeter-qt6. Prefer a Qt6 theme, or install the Qt5 greeter "
            "(sddm-greeter) if your distro still provides it.\n\nDetails:\n%1");
    }
    if (lower.contains(QStringLiteral("qtmultimedia")) || lower.contains(QStringLiteral("mediaplayer"))
        || lower.contains(QStringLiteral("videooutput"))) {
        return QStringLiteral(
            "Preview failed: greeter cannot load QtMultimedia (needed for video themes). "
            "This app injects its own Qt modules for Full Preview — if it still fails, "
            "install QtMultimedia for SDDM (NixOS: services.displayManager.sddm.extraPackages "
            "+ kdePackages.qtmultimedia) and rebuild.\n\nDetails:\n%1");
    }
    if (lower.contains(QStringLiteral("qt5compat")) || lower.contains(QStringLiteral("graphicaleffects"))) {
        return QStringLiteral(
            "Preview failed: greeter cannot load Qt5Compat/GraphicalEffects. "
            "On NixOS add kdePackages.qt5compat to sddm.extraPackages and rebuild.\n\nDetails:\n%1");
    }
    if (lower.contains(QStringLiteral("module")) && lower.contains(QStringLiteral("is not installed"))) {
        return QStringLiteral(
            "Preview failed: a QML module is missing for the greeter.\n\nDetails:\n%1");
    }
    if (details.trimmed().isEmpty()) {
        return QStringLiteral("Preview failed (greeter exited with an error).");
    }
    return QStringLiteral("Preview failed: %1");
}

QString rewriteQmlImportsForQt6(QString content)
{
    // Order matters: match "as Alias" forms before bare imports.
    static const QList<QPair<QRegularExpression, QString>> rules = {
        {QRegularExpression(QStringLiteral(R"(import\s+QtGraphicalEffects\s+1\.[0-9]+)")),
         QStringLiteral("import Qt5Compat.GraphicalEffects")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtGraphicalEffects\s*$)"),
                            QRegularExpression::MultilineOption),
         QStringLiteral("import Qt5Compat.GraphicalEffects")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Controls\s+1\.[0-9]+\s+as\s+)")),
         QStringLiteral("import QtQuick.Controls as ")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Controls\s+1\.[0-9]+)")),
         QStringLiteral("import QtQuick.Controls")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Controls\.Styles\s+1\.[0-9]+\s+as\s+)")),
         QStringLiteral("import QtQuick.Controls as ")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Controls\.Styles\s+1\.[0-9]+)")),
         QStringLiteral("import QtQuick.Controls")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Dialogs\s+1\.[0-9]+)")),
         QStringLiteral("import QtQuick.Dialogs")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\.Layouts\s+1\.[0-9]+)")),
         QStringLiteral("import QtQuick.Layouts")},
        {QRegularExpression(QStringLiteral(R"(import\s+QtQuick\s+2\.[0-9]+)")),
         QStringLiteral("import QtQuick")},
    };

    for (const auto &rule : rules) {
        content.replace(rule.first, rule.second);
    }
    return content;
}

} // namespace

GreeterPreview::GreeterPreview(QObject *parent)
    : QObject(parent)
{
    connect(&m_greeterProcess, &QProcess::finished, this, &GreeterPreview::onGreeterFinished);
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

bool GreeterPreview::themeNeedsQt5Stack(const QString &themePath)
{
    if (themePath.isEmpty() || !QDir(themePath).exists()) {
        return false;
    }

    QDirIterator it(themePath, {QStringLiteral("*.qml")}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        QFile file(it.next());
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        const QByteArray content = file.readAll();
        if (content.contains("QtQuick.Controls 1.")
            || content.contains("QtQuick.Controls.Styles")
            || content.contains("QtGraphicalEffects 1.")
            || content.contains("import QtGraphicalEffects\n")
            || content.contains("import QtGraphicalEffects\r")) {
            return true;
        }
    }
    return false;
}

bool GreeterPreview::modernizeThemeQmlForQt6Greeter(const QString &themeRoot)
{
    if (themeRoot.isEmpty() || !QDir(themeRoot).exists()) {
        return false;
    }

    bool any = false;
    QDirIterator it(themeRoot, {QStringLiteral("*.qml")}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        const QString original = QString::fromUtf8(file.readAll());
        file.close();

        const QString rewritten = rewriteQmlImportsForQt6(original);
        if (rewritten == original) {
            continue;
        }

        if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            continue;
        }
        QTextStream out(&file);
        out << rewritten;
        file.close();
        any = true;
    }
    return any;
}

QString GreeterPreview::greeterBinaryForTheme(const QString &themePath, const QString &metadataPath) const
{
    const QString qt6Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter-qt6"));
    const QString qt5Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter"));
    const QString qtVersion = readMetadataValue(metadataPath, QStringLiteral("QtVersion"));
    const bool needsQt5 = themeNeedsQt5Stack(themePath);

    // Explicit Qt 6 themes always prefer the Qt6 greeter.
    if (qtVersion == QStringLiteral("6")) {
        return qt6Greeter.isEmpty() ? qt5Greeter : qt6Greeter;
    }

    // Plasma/Breeze-era themes (Controls 1.x, GraphicalEffects) need the Qt5 greeter
    // when available — otherwise we modernize imports and use Qt6.
    if (needsQt5 && !qt5Greeter.isEmpty()) {
        return qt5Greeter;
    }

    if (qtVersion == QStringLiteral("5") && !qt5Greeter.isEmpty()) {
        return qt5Greeter;
    }

    if (!qt6Greeter.isEmpty()) {
        return qt6Greeter;
    }
    return qt5Greeter;
}

QProcessEnvironment GreeterPreview::buildPreviewEnvironment() const
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();

    const QStringList qmlPaths = Platform::previewQmlImportPaths();
    const QStringList pluginPaths = Platform::previewQtPluginPaths();

    // Standard Qt paths + NixOS Qt6 packaging hook used by sddm-wrapped greeters.
    prependColonEnv(&env, QStringLiteral("QML2_IMPORT_PATH"), qmlPaths);
    prependColonEnv(&env, QStringLiteral("QML_IMPORT_PATH"), qmlPaths);
    prependColonEnv(&env, QStringLiteral("NIXPKGS_QT6_QML_IMPORT_PATH"), qmlPaths);
    prependColonEnv(&env, QStringLiteral("QT_PLUGIN_PATH"), pluginPaths);

    if (!env.contains(QStringLiteral("AV_LOG_LEVEL"))) {
        env.insert(QStringLiteral("AV_LOG_LEVEL"), QStringLiteral("-8"));
    }
    // Prefer software decode fallbacks when HW decode is broken (common on hybrid GPUs).
    if (!env.contains(QStringLiteral("QT_FFMPEG_DECODING_HW_DEVICE_TYPES"))) {
        env.insert(QStringLiteral("QT_FFMPEG_DECODING_HW_DEVICE_TYPES"), QString());
    }

    return env;
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
    if (!m_backupMetadataPath.isEmpty()) {
        QFile::remove(m_backupMetadataPath);
        m_backupMetadataPath.clear();
    }
    m_modifiedMetadata = false;
    m_originalMetadataPath.clear();

    if (!QFile::exists(themePath)) {
        Q_EMIT previewFinished(false, QStringLiteral("Theme directory not found."));
        return;
    }

    const QString greeter = greeterBinaryForTheme(themePath, metadataPath);
    if (greeter.isEmpty()) {
        Q_EMIT previewFinished(
            false,
            QStringLiteral("Neither sddm-greeter nor sddm-greeter-qt6 was found on PATH. "
                           "Install SDDM (Arch: pacman -S sddm; NixOS: enable services.displayManager.sddm)."));
        return;
    }

    const bool modifyMetadata = !configFile.isEmpty();
    const QString greeterName = QFileInfo(greeter).fileName();
    const bool greeterIsQt6 = greeterName.contains(QStringLiteral("qt6"), Qt::CaseInsensitive)
        || greeter.contains(QStringLiteral("qt6"), Qt::CaseInsensitive);

    // Always work on a temp copy for Full Preview so we never mutate installed themes
    // and can rewrite Qt5-only imports when only the Qt6 greeter is available.
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

    const QString previewThemePath = tempThemePath;
    const QString previewMetadataPath = tempThemePath + QStringLiteral("/metadata.desktop");
    if (modifyMetadata && !writeConfigFileLocal(previewMetadataPath, configFile)) {
        m_tempThemeDir.reset();
        Q_EMIT previewFinished(false, QStringLiteral("Could not set preview variant in temporary copy."));
        return;
    }

    // Qt6 greeter cannot load Controls 1.x / QtGraphicalEffects — rewrite imports in the
    // temp tree only (Layan, old Breeze forks, etc.). Qt5 greeter keeps original QML.
    if (greeterIsQt6) {
        modernizeThemeQmlForQt6Greeter(previewThemePath);
    }

    m_usingTempThemeCopy = true;
    m_modifiedMetadata = modifyMetadata;
    m_originalMetadataPath = previewMetadataPath;
    m_backupMetadataPath.clear();

    m_greeterProcess.setWorkingDirectory(previewThemePath);
    m_greeterProcess.setProcessEnvironment(buildPreviewEnvironment());

    m_greeterProcess.start(greeter,
                           {QStringLiteral("--test-mode"),
                            QStringLiteral("--theme"),
                            previewThemePath});

    if (!m_greeterProcess.waitForStarted(5000)) {
        const QString details = QString::fromUtf8(m_greeterProcess.readAll()).trimmed();
        restoreMetadata();
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
    } else {
        const QString fmt = humanizeGreeterFailure(details);
        message = fmt.contains(QStringLiteral("%1")) ? fmt.arg(details) : fmt;
    }

    Q_EMIT previewFinished(restored && closedNormally, message);
}
