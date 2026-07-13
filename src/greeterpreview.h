// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QProcess>
#include <QTemporaryDir>
#include <memory>

class GreeterPreview : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit GreeterPreview(QObject *parent = nullptr);
    ~GreeterPreview() override;

    bool running() const;

    Q_INVOKABLE void preview(const QString &themePath, const QString &metadataPath, const QString &configFile);
    Q_INVOKABLE void stopPreview();

Q_SIGNALS:
    void runningChanged();
    void previewFinished(bool success, const QString &message);

private:
    QProcess m_greeterProcess;
    QString m_backupMetadataPath;
    QString m_originalMetadataPath;
    bool m_modifiedMetadata = false;
    bool m_stoppedByUser = false;
    bool m_usingTempThemeCopy = false;
    std::unique_ptr<QTemporaryDir> m_tempThemeDir;

    QString greeterBinaryForTheme(const QString &metadataPath) const;
    bool backupMetadata(const QString &metadataPath);
    bool restoreMetadata();
    bool writeConfigFileLine(const QString &metadataPath, const QString &configFile);
    void onGreeterFinished(int exitCode, QProcess::ExitStatus status);
};
