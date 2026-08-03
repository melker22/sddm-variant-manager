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
    /** True if Full Preview can inject QtMultimedia (app Qt / env), even if system greeter lacks it. */
    Q_PROPERTY(bool previewCanProvideMultimedia READ previewCanProvideMultimedia NOTIFY changed)
    Q_PROPERTY(bool hasQt5Greeter READ hasQt5Greeter NOTIFY changed)
    Q_PROPERTY(bool hasQt6Greeter READ hasQt6Greeter NOTIFY changed)
    /** Primary greeter stack: 5, 6, or 0 if unknown. */
    Q_PROPERTY(int greeterQtMajor READ greeterQtMajor NOTIFY changed)
    Q_PROPERTY(QString greeterQtLabel READ greeterQtLabel NOTIFY changed)
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
    bool previewCanProvideMultimedia() const;
    bool hasQt5Greeter() const;
    bool hasQt6Greeter() const;
    int greeterQtMajor() const;
    QString greeterQtLabel() const;
    QString greeterBinary() const;
    QString summary() const;
    QString nixosHint() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool themeNeedsMultimedia(const QVariantMap &theme) const;
    Q_INVOKABLE QStringList missingRequirementsForTheme(const QVariantMap &theme) const;
    Q_INVOKABLE QString advisoryForTheme(const QVariantMap &theme) const;
    /** Short note shown after installing a theme that needs greeter modules. */
    Q_INVOKABLE QString installNotesForTheme(const QVariantMap &theme) const;
    /**
     * Human-readable Qt stack mismatch (theme Qt5 vs greeter Qt6, or reverse).
     * Empty when compatible or unknown.
     */
    Q_INVOKABLE QString qtCompatibilityWarning(const QVariantMap &theme) const;
    Q_INVOKABLE bool themeIncompatibleWithGreeter(const QVariantMap &theme) const;

Q_SIGNALS:
    void changed();

private:
    bool m_ready = false;
    bool m_hasQtMultimedia = false;
    bool m_hasQt5Compat = false;
    bool m_hasQtSvg = false;
    bool m_hasVirtualKeyboard = false;
    bool m_previewCanProvideMultimedia = false;
    bool m_hasQt5Greeter = false;
    bool m_hasQt6Greeter = false;
    int m_greeterQtMajor = 0;
    QString m_greeterBinary;

    static bool pathProvidesModule(const QString &qmlRoot, const QString &moduleDir);
    static QStringList extractColonPathsFromBinary(const QByteArray &data, const QByteArray &needle);
};
