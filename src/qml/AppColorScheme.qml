// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

/**
 * Tokens for the "Palco" redesign (design/Claude Design/design_handoff_direction_a_palco).
 * The theme preview fills the window; every control lives on floating glass
 * panels above it, so most tokens are split explicitly dark/light.
 */
QtObject {
    id: scheme

    readonly property bool isDark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark

    // ── Accent (purple) ──────────────────────────────────────────
    readonly property color primary: "#8B67F2"
    readonly property color primaryHover: "#7B55EE"
    readonly property color primaryPressed: "#6C46E0"
    readonly property color primaryFg: "#FFFFFF"
    readonly property color primaryTint: "#ECE6FD"
    readonly property color primaryTextOnGlass: isDark ? "#B49BFA" : "#7B55EE"
    readonly property color primaryContainer: isDark ? Qt.rgba(0.5451, 0.4039, 0.949, .12) : Qt.rgba(0.5451, 0.4039, 0.949, .10)
    readonly property color primaryContainerBorder: isDark ? Qt.rgba(0.5451, 0.4039, 0.949, .28) : Qt.rgba(0.5451, 0.4039, 0.949, .22)
    readonly property color primaryContainerText: isDark ? "#CBB9FB" : "#6B4ED8"
    readonly property color disabledPrimary: Qt.rgba(0.5451, 0.4039, 0.949, .4)
    readonly property color disabledPrimaryFg: Qt.rgba(1, 1, 1, .6)

    // ── Semantic ─────────────────────────────────────────────────
    readonly property color successDot: isDark ? "#42D68A" : "#2FB26C"
    readonly property color successText: isDark ? "#8FE7BB" : "#2F7D57"
    readonly property color successBg: isDark ? Qt.rgba(0.1843, 0.698, 0.4235, .16) : "#E6F6EE"
    readonly property color successBorder: isDark ? Qt.rgba(0.1843, 0.698, 0.4235, .34) : "#C6E8D6"

    readonly property color warningAccent: "#F0B446"
    readonly property color warningText: "#F7DDA4"
    readonly property color warningBg: Qt.rgba(0.8392, 0.5961, 0.1569, .18)
    readonly property color warningBorder: Qt.rgba(0.9412, 0.7059, 0.2745, .38)
    readonly property color warningDiscFg: "#2A1C05"

    readonly property color dangerAccent: isDark ? "#D9566A" : "#CF3F54"
    readonly property color dangerHover: isDark ? "#C8485C" : "#B93049"
    readonly property color dangerBg: Qt.rgba(0.3451, 0.102, 0.1412, .55)
    readonly property color dangerBorder: Qt.rgba(0.851, 0.3373, 0.4157, .45)
    readonly property color dangerText: "#FFD9DE"
    readonly property color dangerBody: "#F0BCC4"
    readonly property color dangerToastBg: Qt.rgba(0.1882, 0.0784, 0.102, .95)
    readonly property color dangerToastText: "#F7D3D9"

    readonly property color successToastBg: Qt.rgba(0.0784, 0.1725, 0.1294, .95)
    readonly property color successToastText: "#D5F5E4"

    readonly property color betaBg: isDark ? Qt.rgba(0.9412, 0.7059, 0.2745, .16) : "#FBF1DD"
    readonly property color betaBorder: Qt.rgba(0.9412, 0.7059, 0.2745, .4)
    readonly property color betaText: "#F0B446"

    // ── Surfaces — dark mode ─────────────────────────────────────
    readonly property color panelGlassDark: Qt.rgba(0.0549, 0.0588, 0.0824, .62)
    readonly property color barGlassDark: Qt.rgba(0.0549, 0.0588, 0.0824, .68)
    readonly property color panelBorderDark: Qt.rgba(1, 1, 1, .10)
    readonly property color barBorderDark: Qt.rgba(1, 1, 1, .12)
    readonly property color textPrimaryDark: "#F2F1F7"
    readonly property color textSecondaryDark: Qt.rgba(1, 1, 1, .44)
    readonly property color textTertiaryDark: Qt.rgba(1, 1, 1, .40)
    readonly property color dividerDark: Qt.rgba(1, 1, 1, .14)
    readonly property color hairlineDark: Qt.rgba(1, 1, 1, .08)
    readonly property color scrimDark: Qt.rgba(0.0235, 0.0275, 0.0431, .65)

    // ── Surfaces — light mode ─────────────────────────────────────
    readonly property color panelGlassLight: Qt.rgba(1, 1, 1, .80)
    readonly property color barGlassLight: Qt.rgba(1, 1, 1, .86)
    readonly property color panelBorderLight: Qt.rgba(1, 1, 1, .90)
    readonly property color barBorderLight: Qt.rgba(1, 1, 1, .95)
    readonly property color textPrimaryLight: "#1A1A22"
    readonly property color textSecondaryLight: "#5C5C6B"
    readonly property color textTertiaryLight: "#8A8FA6"
    readonly property color dividerLight: Qt.rgba(0.1176, 0.098, 0.2745, .12)
    readonly property color hairlineLight: Qt.rgba(0.1176, 0.098, 0.2745, .08)
    readonly property color scrimLight: Qt.rgba(0.0784, 0.0627, 0.1569, .30)

    // ── Resolved (mode-aware) ─────────────────────────────────────
    readonly property color panelGlass: isDark ? panelGlassDark : panelGlassLight
    readonly property color barGlass: isDark ? barGlassDark : barGlassLight
    readonly property color panelBorder: isDark ? panelBorderDark : panelBorderLight
    readonly property color barBorder: isDark ? barBorderDark : barBorderLight
    readonly property color textPrimary: isDark ? textPrimaryDark : textPrimaryLight
    readonly property color textSecondary: isDark ? textSecondaryDark : textSecondaryLight
    readonly property color textTertiary: isDark ? textTertiaryDark : textTertiaryLight
    readonly property color divider: isDark ? dividerDark : dividerLight
    readonly property color hairline: isDark ? hairlineDark : hairlineLight
    readonly property color panelShadow: isDark ? Qt.rgba(0, 0, 0, .35) : Qt.rgba(0.1176, 0.098, 0.2745, .12)
    readonly property color barShadow: isDark ? Qt.rgba(0, 0, 0, .4) : Qt.rgba(0.1176, 0.098, 0.2745, .14)

    readonly property color fieldBg: isDark ? Qt.rgba(1, 1, 1, .07) : Qt.rgba(0.1176, 0.098, 0.2745, .06)
    readonly property color fieldBorder: isDark ? Qt.rgba(1, 1, 1, .12) : Qt.rgba(0.1176, 0.098, 0.2745, .10)
    readonly property color fieldBorderFocus: Qt.rgba(0.5451, 0.4039, 0.949, .55)
    readonly property color fieldPlaceholder: isDark ? Qt.rgba(1, 1, 1, .52) : "#9A9AB0"

    readonly property color rowHover: isDark ? Qt.rgba(1, 1, 1, .05) : Qt.rgba(0.1176, 0.098, 0.2745, .035)
    readonly property color rowSelected: isDark ? Qt.rgba(1, 1, 1, .10) : Qt.rgba(0.1176, 0.098, 0.2745, .07)

    readonly property color badgeBg: "transparent"
    readonly property color badgeBorder: isDark ? Qt.rgba(1, 1, 1, .16) : "#DCDAE6"
    readonly property color badgeText: isDark ? Qt.rgba(1, 1, 1, .42) : "#8A8FA6"
    readonly property color badgeUserBorder: Qt.rgba(0.5451, 0.4039, 0.949, .35)
    readonly property color badgeUserText: isDark ? "#B49BFA" : "#7B55EE"
    readonly property color badgeReadonlyBorder: Qt.rgba(0.9412, 0.7059, 0.2745, .35)
    readonly property color badgeReadonlyText: "#F0B446"

    // ── Sheets / modals (always dark glass, per handoff) ──────────
    readonly property color sheetBg: Qt.rgba(0.0706, 0.0745, 0.102, .95)
    readonly property color sheetBorder: Qt.rgba(1, 1, 1, .12)
    readonly property color sheetShadow: Qt.rgba(0, 0, 0, .5)
    readonly property color sheetTextPrimary: "#F2F1F7"
    readonly property color sheetTextSecondary: Qt.rgba(1, 1, 1, .5)
    readonly property color sheetTextTertiary: Qt.rgba(1, 1, 1, .42)
    readonly property color sheetFieldBg: Qt.rgba(1, 1, 1, .06)
    readonly property color sheetFieldBorder: Qt.rgba(1, 1, 1, .12)
    readonly property color sheetTrackBg: Qt.rgba(1, 1, 1, .06)
    readonly property color sheetTabActiveBg: "#ECEAF3"
    readonly property color sheetTabActiveText: "#12131A"
    readonly property color sheetHairline: Qt.rgba(1, 1, 1, .09)

    // ── Fonts / radii / spacing ────────────────────────────────────
    readonly property string fontHeading: "Sora"
    readonly property string fontBody: "Manrope"

    readonly property int radiusPanel: 16
    readonly property int radiusModal: 18
    readonly property int radiusButton: 11
    readonly property int radiusVariantCard: 10
    readonly property int radiusThumb: 9
    readonly property int radiusChip: 999

    readonly property int marginOuter: 22
    readonly property int railWidth: 286
    readonly property int stageInset: 330 // 22 + railWidth + 22

    readonly property int blurRadius: 22
}
