// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

/**
 * Inspects the system SDDM greeter for runtime modules themes may need
 * (QtMultimedia, Qt5Compat, etc.) without modifying any theme files.
 */
class GreeterCapabilities : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool analyzed READ ready NOTIFY changed)
    Q_PROPERTY(bool isNixOS READ isNixOS CONSTANT)
    Q_PROPERTY(bool hasQtMultimedia READ hasQtMultimedia NOTIFY changed)
    Q_PROPERTY(bool hasQt5Compat READ hasQt5Compat NOTIFY changed)
    Q_PROPERTY(bool hasQtSvg READ hasQtSvg NOTIFY changed)
    Q_PROPERTY(bool hasVirtualKeyboard READ hasVirtualKeyboard NOTIFY changed)
    Q_PROPERTY(QString greeterBinary READ greeterBinary NOTIFY changed)
    Q_PROPERTY(QString summary READ summary NOTIFY changed)
    Q_PROPERTY(QString nixosHint READ nixosHint CONSTANT)

public:
    explicit GreeterCapabilities(QObject *parent = nullptr);

    bool ready() const;
    bool isNixOS() const;
    bool hasQtMultimedia() const;
    bool hasQt5Compat() const;
    bool hasQtSvg() const;
    bool hasVirtualKeyboard() const;
    QString greeterBinary() const;
    QString summary() const;
    QString nixosHint() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool themeNeedsMultimedia(const QVariantMap &theme) const;
    Q_INVOKABLE QStringList missingRequirementsForTheme(const QVariantMap &theme) const;
    Q_INVOKABLE QString advisoryForTheme(const QVariantMap &theme) const;

Q_SIGNALS:
    void changed();

private:
    bool m_ready = false;
    bool m_hasQtMultimedia = false;
    bool m_hasQt5Compat = false;
    bool m_hasQtSvg = false;
    bool m_hasVirtualKeyboard = false;
    QString m_greeterBinary;

    static bool pathProvidesModule(const QString &qmlRoot, const QString &moduleDir);
    static QStringList extractColonPathsFromBinary(const QByteArray &data, const QByteArray &needle);
};
