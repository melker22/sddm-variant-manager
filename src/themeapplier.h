// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>

class ThemeApplier : public QObject
{
    Q_OBJECT

public:
    explicit ThemeApplier(QObject *parent = nullptr);

    Q_INVOKABLE bool applyVariant(const QString &metadataPath, const QString &configFile);
    Q_INVOKABLE bool applySimpleTheme(const QString &themeId, bool activateInSddm,
                                      const QString &themePath = QString());
    Q_INVOKABLE bool setSddmCurrentTheme(const QString &themeId, bool enabled,
                                         const QString &themePath = QString());

Q_SIGNALS:
    void applyFinished(bool success, const QString &message);
    void sddmThemeFinished(bool success, const QString &message);

private:
    bool runPkexecCommand(const QStringList &arguments, int timeoutMs = 120000);
    bool writeConfigFileLine(const QString &metadataPath, const QString &configFile);
    bool writeNixosSddmDropIn(const QString &themeId, const QString &themePath);
};
