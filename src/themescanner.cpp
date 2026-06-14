// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#include "themescanner.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
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

    scanBaseDirectory(QStringLiteral("/usr/share/sddm/themes"));

    const QString localBase = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/sddm/themes");
    if (localBase != QStringLiteral("/usr/share/sddm/themes")) {
        scanBaseDirectory(localBase);
    }

    Q_EMIT themesChanged();
}

int ThemeScanner::themeCount() const
{
    return m_themes.size();
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

void ThemeScanner::scanBaseDirectory(const QString &basePath)
{
    QDir baseDir(basePath);
    if (!baseDir.exists()) {
        return;
    }

    const QStringList themeDirs = baseDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &dirName : themeDirs) {
        const QString themePath = baseDir.absoluteFilePath(dirName);
        const QVariantMap entry = buildThemeEntry(themePath);
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

QString ThemeScanner::resolveThumbnail(const QString &themePath, const QString &backgroundRel)
{
    const QFileInfo backgroundInfo(backgroundRel);
    const QString baseName = backgroundInfo.completeBaseName();

    const QStringList candidates = {
        themePath + QStringLiteral("/Backgrounds/gifs/") + baseName + QStringLiteral(".gif"),
        themePath + QStringLiteral("/Backgrounds/gifs/") + baseName + QStringLiteral(".GIF"),
        themePath + QStringLiteral("/") + backgroundRel,
    };

    for (const QString &candidate : candidates) {
        if (QFile::exists(candidate)) {
            return candidate;
        }
    }

    return themePath + QStringLiteral("/") + backgroundRel;
}

QVariantMap ThemeScanner::buildThemeEntry(const QString &themePath)
{
    const QString metadataPath = themePath + QStringLiteral("/metadata.desktop");
    const QString themesDirPath = themePath + QStringLiteral("/Themes");

    QDir themesDir(themesDirPath);
    if (!QFile::exists(metadataPath) || !themesDir.exists()) {
        return {};
    }

    const QStringList confFiles = themesDir.entryList({QStringLiteral("*.conf")}, QDir::Files);
    if (confFiles.isEmpty()) {
        return {};
    }

    const QString activeConfigFile = readDesktopValue(metadataPath, QStringLiteral("ConfigFile"));
    const QString themeName = readDesktopValue(metadataPath, QStringLiteral("Name"));
    const QString themeId = QFileInfo(themePath).fileName();

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

    QVariantMap theme;
    theme.insert(QStringLiteral("id"), themeId);
    theme.insert(QStringLiteral("name"), themeName.isEmpty() ? themeId : themeName);
    theme.insert(QStringLiteral("path"), themePath);
    theme.insert(QStringLiteral("metadataPath"), metadataPath);
    theme.insert(QStringLiteral("activeConfigFile"), activeConfigFile);
    theme.insert(QStringLiteral("variants"), variants);
    return theme;
}
