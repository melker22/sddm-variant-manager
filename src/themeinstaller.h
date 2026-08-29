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
    /// Delete an installed theme directory (user or system-wide with pkexec).
    Q_INVOKABLE bool removeTheme(const QString &themePath);
    /// True when the path can be removed by this app (not Nix store / read-only).
    Q_INVOKABLE bool canRemoveTheme(const QString &themePath) const;

    /// Result of reading (never executing) install.sh in a cloned repo.
    struct InstallScriptReport {
        QString scriptPath;
        QString scriptDestination;
        QStringList themeRoots;
        bool usedScript = false;
        bool unusualDestination = false;
    };

    static bool normalizeGitHubUrl(const QString &input, QString *normalizedUrl, QString *error);
    static InstallScriptReport analyzeInstallScripts(const QString &cloneRoot);

Q_SIGNALS:
    void installingChanged();
    void progressMessageChanged();
    void installFinished(bool success, const QString &message, const QStringList installedThemeIds);
    void removeFinished(bool success, const QString &message, const QString themeId);

private:
    bool m_installing = false;
    QString m_progressMessage;

    void setInstalling(bool installing);
    void setProgressMessage(const QString &message);
    void beginInstallJob();
    bool installDiscoveredThemes(const QStringList &themeRoots,
                                 bool systemWide,
                                 const QString &nameHint,
                                 QStringList *installedIds,
                                 QStringList *installedPaths,
                                 QString *error);

    static QStringList findThemeRoots(const QString &rootPath);
    static QString uniqueInstallPath(const QString &baseDir, const QString &folderName);
    static bool copyDirectory(const QString &source, const QString &destination, QString *error = nullptr);
    static bool removePathRecursively(const QString &path, bool systemWide, QString *error = nullptr);
    static bool installDirectory(const QString &source, const QString &destination, bool systemWide, QString *error = nullptr);
    static bool prepareInstallBase(const QString &installBase, bool systemWide, QString *error);
    static bool extractArchive(const QString &archivePath, const QString &destinationDir, QString *error);
    static bool isSupportedArchive(const QString &filePath);

    /// Prefer metadata Theme-Id/Id/Name, then preferredHint, then a non-temp directory name.
    static QString resolveInstallFolderName(const QString &themeRoot, const QString &preferredHint = {});
    static QString sanitizeFolderName(const QString &raw);
    static bool looksLikeTempFolderName(const QString &name);
    static QString readMetadataKey(const QString &themeRoot, const QString &key);
    static bool isValidThemeRoot(const QString &themeRoot);
    static bool themeLooksInstalled(const QString &themePath);
    static bool pathIsUnderThemeInstallRoot(const QString &themePath, bool *systemWideOut = nullptr);
};
