// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

/**
 * Tokens from the SDDM Variant Manager redesign (light + dark screens).
 * Product look wins over Qt / Kirigami / OS chrome.
 */
QtObject {
    id: scheme

    readonly property bool isDark: {
        if (Qt.styleHints.colorScheme === Qt.ColorScheme.Dark)
            return true
        if (Qt.styleHints.colorScheme === Qt.ColorScheme.Light)
            return false
        return false
    }

    readonly property color primary: "#8B67F2"
    readonly property color primaryFg: "#FFFFFF"
    readonly property color primaryContainer: isDark ? "#2A2145" : "#EDE8FD"
    readonly property color primaryContainerFg: isDark ? "#A78BFA" : "#6B4ED8"
    readonly property color accentDark: isDark ? "#A78BFA" : "#6B4ED8"
    readonly property color accentHover: isDark ? "#A78BFA" : "#7455d4"
    readonly property color disabledPrimary: isDark ? "#5C4B8A" : "#C4B5F0"

    readonly property color secondary: isDark ? "#8B8FA3" : "#64748B"
    readonly property color secondaryFg: "#FFFFFF"
    readonly property color secondaryContainer: isDark ? "#20232E" : "#E2E8F0"
    readonly property color secondaryContainerFg: isDark ? "#EDEBF7" : "#1A1626"

    readonly property color tertiary: isDark ? "#F0A8C8" : "#C45A86"
    readonly property color tertiaryFg: "#FFFFFF"
    readonly property color tertiaryContainer: isDark ? "#6B3A52" : "#FFD8E8"
    readonly property color tertiaryContainerFg: isDark ? "#FFE8F1" : "#3A1528"

    readonly property color background: isDark ? "#12141A" : "#F4F6FB"
    readonly property color surface: isDark ? "#1A1D26" : "#FEFDFE"
    readonly property color surface2: isDark ? "#20232E" : "#FFFFFF"
    readonly property color surfaceVariant: isDark ? "#20232E" : "#E2E8F0"
    readonly property color outline: isDark ? "#2B2E3B" : "#E2E8F0"
    readonly property color surfaceFg: isDark ? "#EDEBF7" : "#1A1626"
    readonly property color surfaceVariantFg: isDark ? "#8B8FA3" : "#64748B"
    readonly property color textMuted: isDark ? "#8B8FA3" : "#94A3B8"

    readonly property color sidebar: isDark ? "#1B1930" : "#EEE9FB"
    readonly property color cardBorder: isDark ? "#2B2E3B" : "#E2E8F0"
    readonly property color accentGlow: isDark ? "#8B67F240" : "#8B67F222"

    readonly property color fieldBg: isDark ? "#1A1D26" : "#FFFFFF"
    readonly property color fieldBorder: isDark ? "#2B2E3B" : "#E2E8F0"
    readonly property color fieldBorderFocus: primary
    readonly property color fieldPlaceholder: isDark ? "#8B8FA3" : "#94A3B8"
    readonly property color fieldSelection: isDark ? "#4A3A7A" : "#D4C8FA"
    readonly property color checkboxBorder: isDark ? "#8B8FA3" : "#94A3B8"
    readonly property color overlayScrim: isDark ? "#00000099" : "#00000055"

    readonly property color danger: isDark ? "#F0827E" : "#C23B3B"
    readonly property color dangerContainer: isDark ? "#2E1717" : "#FDF0F0"
    readonly property color dangerBorder: isDark ? "#4A2222" : "#F5D3D3"
    readonly property color warning: isDark ? "#E5A75B" : "#B4600F"
    readonly property color warningContainer: isDark ? "#2E2313" : "#FDF0E4"
    readonly property color warningFg: isDark ? "#C9A876" : "#B4600F"

    readonly property color badgeSystemBg: isDark ? "#16261F" : "#E4F8EC"
    readonly property color badgeSystemText: isDark ? "#6FE3A8" : "#1F7A4D"
    readonly property color badgeUserBg: isDark ? "#2A2145" : "#F3EEFF"
    readonly property color badgeUserText: isDark ? "#A78BFA" : "#6B4ED8"
    readonly property color badgeReadonlyBg: isDark ? "#2E2313" : "#FDF0E4"
    readonly property color badgeReadonlyText: isDark ? "#E5A75B" : "#B4600F"
    readonly property color badgeBetaBg: isDark ? "#332711" : "#FBF1DD"
    readonly property color badgeBetaText: isDark ? "#E5C583" : "#9A6B1F"
    readonly property color badgeBetaBorder: isDark ? "#4A3A1C" : "#F0DBA8"
    readonly property color badgeSuccessBg: isDark ? "#16261F" : "#EFFAF3"
    readonly property color badgeSuccessText: isDark ? "#6FE3A8" : "#1F7A4D"
    readonly property color badgeSuccessBorder: isDark ? "#25543C" : "#BEEBD0"

    readonly property string fontHeading: "Sora"
    readonly property string fontBody: "Manrope"
    readonly property int radiusCard: 10
    readonly property int radiusModal: 16
    readonly property int radiusControl: 8

    readonly property color shadowCard: isDark ? "#59000000" : "#0F000000"
    readonly property color shadowCardHover: isDark ? "#478B67F2" : "#268B67F2"
    readonly property int shadowY: 2
    readonly property int shadowYHover: 4
}
