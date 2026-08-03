// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.kirigami.platform as Platform

QtObject {
    id: scheme

    readonly property bool isDark: {
        if (Qt.styleHints.colorScheme === Qt.ColorScheme.Dark) {
            return true
        }
        if (Qt.styleHints.colorScheme === Qt.ColorScheme.Light) {
            return false
        }
        // Unknown: light text usually means a dark system palette.
        return Platform.Theme.textColor.hslLightness > 0.5
    }

    // App palette — property names must not use on+Capital (signal handlers).
    readonly property color primary: isDark ? "#B9A0F7" : "#8B67F2"
    readonly property color primaryFg: "#FFFFFF"
    readonly property color primaryContainer: isDark ? "#3D2F66" : "#EDE8FD"
    readonly property color primaryContainerFg: isDark ? "#EDE8FD" : "#6B4ED8"
    readonly property color accentDark: isDark ? "#C4B0FA" : "#6B4ED8"
    readonly property color accentHover: isDark ? "#9B82F0" : "#7455d4"
    readonly property color disabledPrimary: isDark ? "#5C4B8A" : "#C4B5F0"

    readonly property color secondary: isDark ? "#A8B4C4" : "#64748B"
    readonly property color secondaryFg: "#FFFFFF"
    readonly property color secondaryContainer: isDark ? "#2A3140" : "#E2E8F0"
    readonly property color secondaryContainerFg: isDark ? "#E2E8F0" : "#1A1626"

    readonly property color tertiary: isDark ? "#F0A8C8" : "#C45A86"
    readonly property color tertiaryFg: "#FFFFFF"
    readonly property color tertiaryContainer: isDark ? "#6B3A52" : "#FFD8E8"
    readonly property color tertiaryContainerFg: isDark ? "#FFE8F1" : "#3A1528"

    readonly property color background: isDark ? "#12141A" : "#F4F6FB"
    readonly property color surface: isDark ? "#1A1D26" : "#FEFDFE"
    readonly property color surfaceVariant: isDark ? "#2A2F3A" : "#E2E8F0"
    readonly property color outline: isDark ? "#4B5568" : "#E2E8F0"
    readonly property color surfaceFg: isDark ? "#F1F5F9" : "#1A1626"
    readonly property color surfaceVariantFg: isDark ? "#A8B4C4" : "#64748B"
    readonly property color textMuted: isDark ? "#8B97A8" : "#94A3B8"

    readonly property color sidebar: isDark ? "#17151F" : "#EEE9FB"
    readonly property color cardBorder: isDark ? "#363D4D" : "#E2E8F0"
    readonly property color accentGlow: isDark ? "#8B67F233" : "#8B67F222"

    // Form fields / controls (Basic style replacements)
    readonly property color fieldBg: isDark ? "#141821" : "#FFFFFF"
    readonly property color fieldBorder: isDark ? "#3D4556" : "#E2E8F0"
    readonly property color fieldBorderFocus: primary
    readonly property color fieldPlaceholder: isDark ? "#7A8699" : "#94A3B8"
    readonly property color fieldSelection: isDark ? "#4A3A7A" : "#D4C8FA"
    readonly property color checkboxBorder: isDark ? "#64748B" : "#94A3B8"
    readonly property color overlayScrim: isDark ? "#00000099" : "#00000055"

    readonly property color danger: isDark ? "#F2B8B5" : "#B3261E"
    readonly property color dangerContainer: isDark ? "#4A1C1A" : "#FCE8E6"
    readonly property color warning: isDark ? "#FFB74D" : "#E65100"
    readonly property color warningContainer: isDark ? "#4A2E12" : "#FFF3E0"

    readonly property color badgeSystemBg: isDark ? "#1B3A24" : "#E8F5E9"
    readonly property color badgeSystemText: isDark ? "#81C784" : "#2E7D32"
    readonly property color badgeUserBg: isDark ? "#3D2F66" : "#EDE8FD"
    readonly property color badgeUserText: isDark ? "#B9A0F7" : "#6B4ED8"
    readonly property color badgeReadonlyBg: isDark ? "#4A2E12" : "#FFF3E0"
    readonly property color badgeReadonlyText: isDark ? "#FFB74D" : "#E65100"
    readonly property color badgeSuccessBg: isDark ? "#1B3A24" : "#E8F5E9"
    readonly property color badgeSuccessText: isDark ? "#81C784" : "#2E7D32"

    readonly property string fontHeading: "Sora"
    readonly property string fontBody: "Manrope"
    readonly property int radiusCard: 10
    readonly property int radiusModal: 16
    readonly property int radiusControl: 8
}
