// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QStringList>

class ThemeInstaller : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool installing READ installing NOTIFY installingChanged)
    Q_PROPERTY(QString progressMessage READ progressMessage NOTIFY progressMessageChanged)
    Q_PROPERTY(bool gitAvailable READ gitAvailable CONSTANT)

public:
    explicit ThemeInstaller(QObject *parent = nullptr);

    bool installing() const;
    QString progressMessage() const;
    bool gitAvailable() const;

    Q_INVOKABLE bool installFromUrl(const QString &url, bool systemWide);
    Q_INVOKABLE bool installFromLocalPath(const QString &path, bool systemWide);

Q_SIGNALS:
    void installingChanged();
    void progressMessageChanged();
    void installFinished(bool success, const QString &message, const QStringList installedThemeIds);

private:
    bool m_installing = false;
    QString m_progressMessage;

    void setInstalling(bool installing);
    void setProgressMessage(const QString &message);
    void beginInstallJob();

    static bool normalizeGitHubUrl(const QString &input, QString *normalizedUrl, QString *error);
    static QStringList findThemeRoots(const QString &rootPath);
    static QString uniqueInstallPath(const QString &baseDir, const QString &folderName);
    static bool copyDirectory(const QString &source, const QString &destination);
    static bool installDirectory(const QString &source, const QString &destination, bool systemWide);
    static bool prepareInstallBase(const QString &installBase, bool systemWide, QString *error);
    static bool extractArchive(const QString &archivePath, const QString &destinationDir, QString *error);
    static bool isSupportedArchive(const QString &filePath);
};
