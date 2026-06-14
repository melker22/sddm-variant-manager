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

public:
    explicit ThemeScanner(QObject *parent = nullptr);

    QVariantList themes() const;
    int themeCount() const;

    Q_INVOKABLE void rescan();
    Q_INVOKABLE QVariantMap themeAt(int index) const;
    Q_INVOKABLE QVariantList variantsForTheme(int themeIndex) const;

Q_SIGNALS:
    void themesChanged();

private:
    QVariantList m_themes;

    void scanBaseDirectory(const QString &basePath);
    static QString readDesktopValue(const QString &filePath, const QString &key);
    static QString readConfValue(const QString &filePath, const QString &key);
    static QString resolveThumbnail(const QString &themePath, const QString &backgroundRel);
    static QVariantMap buildThemeEntry(const QString &themePath);
};
