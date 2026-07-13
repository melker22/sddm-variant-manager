// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themescanner.h"
#include "platform.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QProcess>
#include <QStandardPaths>
#include <QtConcurrent>
#include <QTextStream>

ThemeScanner::ThemeScanner(QObject *parent)
    : QObject(parent)
{
    rescan();
}

QVariantList ThemeScanner::themes() const
{
    return m_themes;
}

void ThemeScanner::rescan()
{
    m_themes.clear();

    const QStringList systemDirs = Platform::systemThemeScanDirs();
    for (const QString &systemDir : systemDirs) {
        scanBaseDirectory(systemDir);
    }

    const QString localBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/sddm/themes");
    if (!systemDirs.contains(localBase)) {
        scanBaseDirectory(localBase);
    }

    Q_EMIT themesChanged();
    generateMissingThumbnails();
}

int ThemeScanner::themeCount() const
{
    return m_themes.size();
}

bool ThemeScanner::ffmpegAvailable() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("ffmpeg")).isEmpty();
}

QVariantMap ThemeScanner::themeAt(int index) const
{
    if (index < 0 || index >= m_themes.size()) {
        return {};
    }
    return m_themes.at(index).toMap();
}

QVariantList ThemeScanner::variantsForTheme(int themeIndex) const
{
    const QVariantMap theme = themeAt(themeIndex);
    return theme.value(QStringLiteral("variants")).toList();
}

int ThemeScanner::themeIndexForId(const QString &themeId) const
{
    for (int i = 0; i < m_themes.size(); ++i) {
        if (m_themes.at(i).toMap().value(QStringLiteral("id")).toString() == themeId) {
            return i;
        }
    }
    return -1;
}

void ThemeScanner::scanBaseDirectory(const QString &basePath)
{
    QDir baseDir(basePath);
    if (!baseDir.exists()) {
        return;
    }

    const QString installScope =
        (basePath.startsWith(QStringLiteral("/usr/share/"))
         || basePath.startsWith(QStringLiteral("/run/current-system/"))
         || basePath.startsWith(QStringLiteral("/var/lib/sddm/")))
            ? QStringLiteral("system")
            : QStringLiteral("user");

    const QStringList themeDirs = baseDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &dirName : themeDirs) {
        const QString themePath = baseDir.absoluteFilePath(dirName);
        const QVariantMap entry = buildThemeEntry(themePath, installScope);
        if (entry.isEmpty()) {
            continue;
        }

        bool duplicate = false;
        for (const QVariant &existing : m_themes) {
            if (existing.toMap().value(QStringLiteral("path")).toString() == themePath) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            m_themes.append(entry);
        }
    }
}

QString ThemeScanner::readDesktopValue(const QString &filePath, const QString &key)
{
    QFile file(filePath);
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

QString ThemeScanner::readConfValue(const QString &filePath, const QString &key)
{
    return readDesktopValue(filePath, key);
}

bool ThemeScanner::isVideoFile(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    return suffix == QStringLiteral("mp4")
        || suffix == QStringLiteral("webm")
        || suffix == QStringLiteral("mov")
        || suffix == QStringLiteral("mkv");
}

bool ThemeScanner::isGifFile(const QString &path)
{
    return QFileInfo(path).suffix().compare(QStringLiteral("gif"), Qt::CaseInsensitive) == 0;
}

bool ThemeScanner::pathIsVideo(const QString &path) const
{
    return isVideoFile(path);
}

bool ThemeScanner::pathIsGif(const QString &path) const
{
    return isGifFile(path);
}

QString ThemeScanner::thumbnailCachePathForVideo(const QString &videoPath)
{
    const QFileInfo info(videoPath);
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + QStringLiteral("/thumbnails");

    return cacheDir + QDir::separator() + info.completeBaseName()
        + QStringLiteral("-") + QString::number(info.lastModified().toSecsSinceEpoch())
        + QStringLiteral(".jpg");
}

bool ThemeScanner::generateVideoThumbnail(const QString &videoPath, const QString &outputPath)
{
    const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
    if (ffmpeg.isEmpty() || !QFile::exists(videoPath)) {
        return false;
    }

    QDir().mkpath(QFileInfo(outputPath).absolutePath());

    QProcess process;
    process.start(ffmpeg,
                  {QStringLiteral("-hide_banner"),
                   QStringLiteral("-loglevel"),
                   QStringLiteral("error"),
                   QStringLiteral("-y"),
                   QStringLiteral("-ss"),
                   QStringLiteral("1"),
                   QStringLiteral("-i"),
                   videoPath,
                   QStringLiteral("-frames:v"),
                   QStringLiteral("1"),
                   QStringLiteral("-vf"),
                   QStringLiteral("scale=640:-2"),
                   QStringLiteral("-q:v"),
                   QStringLiteral("4"),
                   outputPath});

    if (!process.waitForFinished(20000) || process.exitCode() != 0) {
        return false;
    }

    return QFile::exists(outputPath);
}

QString ThemeScanner::resolveThumbnail(const QString &themePath, const QString &backgroundRel)
{
    const QFileInfo backgroundInfo(backgroundRel);
    const QString baseName = backgroundInfo.completeBaseName();
    const QString backgroundAbs = themePath + QStringLiteral("/") + backgroundRel;
    const QString backgroundsDir = themePath + QStringLiteral("/Backgrounds/");

    static const QStringList staticExtensions = {
        QStringLiteral(".jpg"),
        QStringLiteral(".jpeg"),
        QStringLiteral(".png"),
        QStringLiteral(".webp"),
    };

    for (const QString &extension : staticExtensions) {
        const QString candidate = backgroundsDir + baseName + extension;
        if (QFile::exists(candidate)) {
            return candidate;
        }
    }

    if (isVideoFile(backgroundAbs) && QFile::exists(backgroundAbs)) {
        const QString cached = thumbnailCachePathForVideo(backgroundAbs);
        if (QFile::exists(cached)) {
            return cached;
        }
    }

    const QStringList gifCandidates = {
        backgroundsDir + QStringLiteral("gifs/") + baseName + QStringLiteral(".gif"),
        backgroundsDir + QStringLiteral("gifs/") + baseName + QStringLiteral(".GIF"),
    };

    for (const QString &candidate : gifCandidates) {
        if (QFile::exists(candidate)) {
            return candidate;
        }
    }

    if (QFile::exists(backgroundAbs) && !isVideoFile(backgroundAbs)) {
        return backgroundAbs;
    }

    return {};
}

void ThemeScanner::refreshThumbnailPaths()
{
    for (int themeIndex = 0; themeIndex < m_themes.size(); ++themeIndex) {
        QVariantMap theme = m_themes.at(themeIndex).toMap();
        const QString themePath = theme.value(QStringLiteral("path")).toString();
        const QString metadataPath = theme.value(QStringLiteral("metadataPath")).toString();
        const bool hasVariants = theme.value(QStringLiteral("hasVariants")).toBool();

        if (hasVariants) {
            QVariantList variants = theme.value(QStringLiteral("variants")).toList();
            for (int variantIndex = 0; variantIndex < variants.size(); ++variantIndex) {
                QVariantMap variant = variants.at(variantIndex).toMap();
                const QString backgroundPath = variant.value(QStringLiteral("backgroundPath")).toString();
                const QString backgroundRel = QDir(themePath).relativeFilePath(backgroundPath);
                variant.insert(QStringLiteral("thumbnailPath"), resolveThumbnail(themePath, backgroundRel));
                variants[variantIndex] = variant;
            }
            theme.insert(QStringLiteral("variants"), variants);
        } else {
            const QString previewPath = resolveSimpleThemePreview(themePath, metadataPath);
            theme.insert(QStringLiteral("previewPath"), previewPath);
            theme.insert(QStringLiteral("thumbnailPath"), resolveSimpleThemeThumbnail(previewPath));
        }

        m_themes[themeIndex] = theme;
    }
}

void ThemeScanner::generateMissingThumbnails()
{
    struct ThumbnailJob {
        QString videoPath;
        QString cachePath;
    };

    QList<ThumbnailJob> jobs;
    for (const QVariant &themeVariant : std::as_const(m_themes)) {
        const QVariantMap theme = themeVariant.toMap();
        const QVariantList variants = theme.value(QStringLiteral("variants")).toList();
        for (const QVariant &variantVariant : variants) {
            const QString backgroundPath = variantVariant.toMap().value(QStringLiteral("backgroundPath")).toString();
            if (!isVideoFile(backgroundPath) || !QFile::exists(backgroundPath)) {
                continue;
            }

            const QString cachePath = thumbnailCachePathForVideo(backgroundPath);
            if (QFile::exists(cachePath)) {
                continue;
            }

            jobs.append({backgroundPath, cachePath});
        }

        if (!theme.value(QStringLiteral("hasVariants")).toBool()) {
            const QString previewPath = theme.value(QStringLiteral("previewPath")).toString();
            if (isVideoFile(previewPath) && QFile::exists(previewPath)) {
                const QString cachePath = thumbnailCachePathForVideo(previewPath);
                if (!QFile::exists(cachePath)) {
                    jobs.append({previewPath, cachePath});
                }
            }
        }
    }

    if (jobs.isEmpty()) {
        return;
    }

    (void)QtConcurrent::run([this, jobs]() {
        bool updated = false;
        for (const ThumbnailJob &job : jobs) {
            if (generateVideoThumbnail(job.videoPath, job.cachePath)) {
                updated = true;
            }
        }

        if (!updated) {
            return;
        }

        QMetaObject::invokeMethod(this, [this]() {
            refreshThumbnailPaths();
            Q_EMIT themesChanged();
        }, Qt::QueuedConnection);
    });
}

QString ThemeScanner::resolveSimpleThemePreview(const QString &themePath, const QString &metadataPath)
{
    auto resolveExistingMedia = [&](const QString &relativePath) -> QString {
        if (relativePath.isEmpty()) {
            return {};
        }

        const QString candidate = themePath + QStringLiteral("/") + relativePath;
        if (!QFile::exists(candidate)) {
            return {};
        }

        return candidate;
    };

    const QString screenshot = readDesktopValue(metadataPath, QStringLiteral("Screenshot"));
    const QString screenshotPath = resolveExistingMedia(screenshot);
    if (!screenshotPath.isEmpty()) {
        return screenshotPath;
    }

    const QString configRelative = readDesktopValue(metadataPath, QStringLiteral("ConfigFile"));
    if (!configRelative.isEmpty()) {
        const QString configPath = themePath + QStringLiteral("/") + configRelative;
        const QString configBackground = readDesktopValue(configPath, QStringLiteral("background"));
        const QString configBackgroundPath = resolveExistingMedia(configBackground);
        if (!configBackgroundPath.isEmpty()) {
            return configBackgroundPath;
        }
    }

    static const QStringList metadataKeys = {
        QStringLiteral("Background"),
        QStringLiteral("ThemeBackground"),
    };

    for (const QString &key : metadataKeys) {
        const QString metadataBackgroundPath = resolveExistingMedia(readDesktopValue(metadataPath, key));
        if (!metadataBackgroundPath.isEmpty()) {
            return metadataBackgroundPath;
        }
    }

    static const QStringList commonFiles = {
        QStringLiteral("preview.png"),
        QStringLiteral("preview.jpg"),
        QStringLiteral("background.jpg"),
        QStringLiteral("background.png"),
        QStringLiteral("Backgrounds/preview.jpg"),
        QStringLiteral("Backgrounds/preview.png"),
    };

    for (const QString &relativePath : commonFiles) {
        const QString candidate = themePath + QStringLiteral("/") + relativePath;
        if (QFile::exists(candidate)) {
            return candidate;
        }
    }

    const QDir backgroundsDir(themePath + QStringLiteral("/Backgrounds"));
    if (backgroundsDir.exists()) {
        const QStringList images = backgroundsDir.entryList(
            {QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.png"), QStringLiteral("*.webp"),
             QStringLiteral("*.mp4"), QStringLiteral("*.webm")},
            QDir::Files);
        if (!images.isEmpty()) {
            const QString candidate = backgroundsDir.absoluteFilePath(images.constFirst());
            return candidate;
        }
    }

    return {};
}

QString ThemeScanner::resolveSimpleThemeThumbnail(const QString &previewPath)
{
    if (previewPath.isEmpty()) {
        return {};
    }

    if (isVideoFile(previewPath)) {
        const QString cached = thumbnailCachePathForVideo(previewPath);
        if (QFile::exists(cached)) {
            return cached;
        }
    }

    return previewPath;
}

QVariantList ThemeScanner::buildVariantList(const QString &themePath, const QString &metadataPath)
{
    const QString themesDirPath = themePath + QStringLiteral("/Themes");
    QDir themesDir(themesDirPath);
    if (!themesDir.exists()) {
        return {};
    }

    const QStringList confFiles = themesDir.entryList({QStringLiteral("*.conf")}, QDir::Files);
    if (confFiles.isEmpty()) {
        return {};
    }

    const QString activeConfigFile = readDesktopValue(metadataPath, QStringLiteral("ConfigFile"));
    QVariantList variants;

    for (const QString &confFile : confFiles) {
        const QString confPath = themesDir.absoluteFilePath(confFile);
        const QString variantId = QFileInfo(confFile).completeBaseName();
        const QString configRelative = QStringLiteral("Themes/") + confFile;
        const QString headerText = readConfValue(confPath, QStringLiteral("HeaderText"));
        const QString backgroundRel = readConfValue(confPath, QStringLiteral("Background"));

        QVariantMap variant;
        variant.insert(QStringLiteral("id"), variantId);
        variant.insert(QStringLiteral("displayName"), headerText.isEmpty() ? variantId : headerText);
        variant.insert(QStringLiteral("configFile"), configRelative);
        variant.insert(QStringLiteral("backgroundPath"), themePath + QStringLiteral("/") + backgroundRel);
        variant.insert(QStringLiteral("thumbnailPath"), resolveThumbnail(themePath, backgroundRel));
        variant.insert(QStringLiteral("isActive"), configRelative == activeConfigFile);
        variants.append(variant);
    }

    return variants;
}

QVariantMap ThemeScanner::buildThemeEntry(const QString &themePath, const QString &installScope)
{
    const QString metadataPath = themePath + QStringLiteral("/metadata.desktop");
    if (!QFile::exists(metadataPath)) {
        return {};
    }

    const QString themeName = readDesktopValue(metadataPath, QStringLiteral("Name"));
    const QString themeId = QFileInfo(themePath).fileName();
    const QVariantList variants = buildVariantList(themePath, metadataPath);
    const bool hasVariants = !variants.isEmpty();

    QVariantMap theme;
    theme.insert(QStringLiteral("id"), themeId);
    theme.insert(QStringLiteral("name"), themeName.isEmpty() ? themeId : themeName);
    theme.insert(QStringLiteral("path"), themePath);
    theme.insert(QStringLiteral("metadataPath"), metadataPath);
    theme.insert(QStringLiteral("installScope"), installScope);
    theme.insert(QStringLiteral("readOnly"), Platform::pathIsReadOnly(themePath));
    theme.insert(QStringLiteral("hasVariants"), hasVariants);
    theme.insert(QStringLiteral("variants"), variants);

    // Detect themes that need QtMultimedia in the *system* greeter (video backgrounds).
    bool requiresMultimedia = QFile::exists(themePath + QStringLiteral("/BackgroundVideo.qml"));
    if (!requiresMultimedia) {
        const QString confPath = themePath + QStringLiteral("/theme.conf");
        const QString type = readConfValue(confPath, QStringLiteral("type")).toLower();
        const QString background = readConfValue(confPath, QStringLiteral("background")).toLower();
        requiresMultimedia = type == QLatin1String("video") || isVideoFile(background)
            || isVideoFile(themePath + QLatin1Char('/') + background);
    }
    if (!requiresMultimedia && !hasVariants) {
        requiresMultimedia = isVideoFile(theme.value(QStringLiteral("previewPath")).toString());
    }
    if (!requiresMultimedia && hasVariants) {
        for (const QVariant &variantVar : variants) {
            if (isVideoFile(variantVar.toMap().value(QStringLiteral("backgroundPath")).toString())) {
                requiresMultimedia = true;
                break;
            }
        }
    }
    theme.insert(QStringLiteral("requiresMultimedia"), requiresMultimedia);

    if (hasVariants) {
        theme.insert(QStringLiteral("activeConfigFile"),
                     readDesktopValue(metadataPath, QStringLiteral("ConfigFile")));
        theme.insert(QStringLiteral("previewPath"), QString());
        theme.insert(QStringLiteral("thumbnailPath"), QString());
    } else {
        const QString previewPath = resolveSimpleThemePreview(themePath, metadataPath);
        theme.insert(QStringLiteral("activeConfigFile"), QString());
        theme.insert(QStringLiteral("previewPath"), previewPath);
        theme.insert(QStringLiteral("thumbnailPath"), resolveSimpleThemeThumbnail(previewPath));
    }

    return theme;
}
