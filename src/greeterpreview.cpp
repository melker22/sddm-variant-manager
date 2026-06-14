// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "greeterpreview.h"

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTextStream>

GreeterPreview::GreeterPreview(QObject *parent)
    : QObject(parent)
{
    connect(&m_greeterProcess, &QProcess::finished, this, &GreeterPreview::onGreeterFinished);
}

GreeterPreview::~GreeterPreview()
{
    stopPreview();
}

bool GreeterPreview::running() const
{
    return m_greeterProcess.state() != QProcess::NotRunning;
}

QString GreeterPreview::greeterBinary() const
{
    const QString qt6Greeter = QStandardPaths::findExecutable(QStringLiteral("sddm-greeter-qt6"));
    if (!qt6Greeter.isEmpty()) {
        return qt6Greeter;
    }
    return QStandardPaths::findExecutable(QStringLiteral("sddm-greeter"));
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
    if (!m_modifiedMetadata || m_originalMetadataPath.isEmpty() || m_backupMetadataPath.isEmpty()) {
        return true;
    }

    QProcess process;
    process.start(QStringLiteral("pkexec"),
                  {QStringLiteral("cp"), m_backupMetadataPath, m_originalMetadataPath});
    if (!process.waitForStarted() || !process.waitForFinished(120000)) {
        return false;
    }

    QFile::remove(m_backupMetadataPath);
    m_modifiedMetadata = false;
    m_originalMetadataPath.clear();
    m_backupMetadataPath.clear();
    return process.exitCode() == 0;
}

bool GreeterPreview::writeConfigFileLine(const QString &metadataPath, const QString &configFile)
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

    QProcess process;
    process.start(QStringLiteral("pkexec"), {QStringLiteral("cp"), tempFile.fileName(), metadataPath});
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

    const QString greeter = greeterBinary();
    if (greeter.isEmpty()) {
        Q_EMIT previewFinished(false, QStringLiteral("sddm-greeter-qt6 not found."));
        return;
    }

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

    m_greeterProcess.start(greeter,
                           {QStringLiteral("--test-mode"),
                            QStringLiteral("--theme"),
                            themePath});

    if (!m_greeterProcess.waitForStarted()) {
        restoreMetadata();
        Q_EMIT previewFinished(false, QStringLiteral("Failed to start SDDM greeter preview."));
        return;
    }

    Q_EMIT runningChanged();
}

void GreeterPreview::stopPreview()
{
    if (m_greeterProcess.state() != QProcess::NotRunning) {
        m_greeterProcess.kill();
        m_greeterProcess.waitForFinished(3000);
    }
}

void GreeterPreview::onGreeterFinished(int exitCode, QProcess::ExitStatus status)
{
    Q_UNUSED(exitCode)
    Q_UNUSED(status)

    const bool restored = restoreMetadata();
    Q_EMIT runningChanged();
    Q_EMIT previewFinished(
        restored,
        restored ? QStringLiteral("Preview closed. Theme metadata restored.")
                 : QStringLiteral("Preview closed, but metadata restore failed."));
}
