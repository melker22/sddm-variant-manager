// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QVariantList>

class ThemeScanner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList themes READ themes NOTIFY themesChanged)
    Q_PROPERTY(int themeCount READ themeCount NOTIFY themesChanged)
    Q_PROPERTY(bool ffmpegAvailable READ ffmpegAvailable CONSTANT)

public:
    explicit ThemeScanner(QObject *parent = nullptr);

    QVariantList themes() const;
    int themeCount() const;
    bool ffmpegAvailable() const;

    Q_INVOKABLE void rescan();
    Q_INVOKABLE QVariantMap themeAt(int index) const;
    Q_INVOKABLE QVariantList variantsForTheme(int themeIndex) const;
    Q_INVOKABLE int themeIndexForId(const QString &themeId) const;
    Q_INVOKABLE bool pathIsVideo(const QString &path) const;
    Q_INVOKABLE bool pathIsGif(const QString &path) const;

Q_SIGNALS:
    void themesChanged();

private:
    QVariantList m_themes;

    void scanBaseDirectory(const QString &basePath);
    void generateMissingThumbnails();
    void refreshThumbnailPaths();

    static QString readDesktopValue(const QString &filePath, const QString &key);
    static QString readConfValue(const QString &filePath, const QString &key);
    static bool isVideoFile(const QString &path);
    static bool isGifFile(const QString &path);
    static QString thumbnailCachePathForVideo(const QString &videoPath);
    static bool generateVideoThumbnail(const QString &videoPath, const QString &outputPath);
    static QString resolveThumbnail(const QString &themePath, const QString &backgroundRel);
    static QString resolveSimpleThemePreview(const QString &themePath, const QString &metadataPath);
    static QString resolveSimpleThemeThumbnail(const QString &previewPath);
    static QVariantMap buildThemeEntry(const QString &themePath, const QString &installScope);
    static QVariantList buildVariantList(const QString &themePath, const QString &metadataPath);
};
