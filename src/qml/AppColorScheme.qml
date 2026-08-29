// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

/**
 * Design tokens from the SDDM Variant Manager UX Pilot screen.
 *
 * Rule: these values define the product look. Qt / Kirigami / system
 * theme defaults must adapt to this palette — not the other way around.
 * The published design is light; do not flip to a system dark skin.
 */
QtObject {
    id: scheme

    // Locked to the UX Pilot light dashboard (not the OS color scheme).
    readonly property bool isDark: false

    readonly property color primary: "#8B67F2"
    readonly property color primaryFg: "#FFFFFF"
    readonly property color primaryContainer: "#EDE8FD"
    readonly property color primaryContainerFg: "#6B4ED8"
    readonly property color accentDark: "#6B4ED8"
    readonly property color accentHover: "#7455d4"
    readonly property color disabledPrimary: "#C4B5F0"

    readonly property color secondary: "#64748B"
    readonly property color secondaryFg: "#FFFFFF"
    readonly property color secondaryContainer: "#E2E8F0"
    readonly property color secondaryContainerFg: "#1A1626"

    readonly property color tertiary: "#C45A86"
    readonly property color tertiaryFg: "#FFFFFF"
    readonly property color tertiaryContainer: "#FFD8E8"
    readonly property color tertiaryContainerFg: "#3A1528"

    readonly property color background: "#F4F6FB"
    readonly property color surface: "#FEFDFE"
    readonly property color surfaceVariant: "#E2E8F0"
    readonly property color outline: "#E2E8F0"
    readonly property color surfaceFg: "#1A1626"
    readonly property color surfaceVariantFg: "#64748B"
    readonly property color textMuted: "#94A3B8"

    readonly property color sidebar: "#EEE9FB"
    readonly property color cardBorder: "#E2E8F0"
    readonly property color accentGlow: "#8B67F222"

    readonly property color fieldBg: "#FFFFFF"
    readonly property color fieldBorder: "#E2E8F0"
    readonly property color fieldBorderFocus: primary
    readonly property color fieldPlaceholder: "#94A3B8"
    readonly property color fieldSelection: "#D4C8FA"
    readonly property color checkboxBorder: "#94A3B8"
    readonly property color overlayScrim: "#00000055"

    readonly property color danger: "#B3261E"
    readonly property color dangerContainer: "#FCE8E6"
    readonly property color warning: "#E65100"
    readonly property color warningContainer: "#FFF3E0"

    readonly property color badgeSystemBg: "#E8F5E9"
    readonly property color badgeSystemText: "#2E7D32"
    readonly property color badgeUserBg: "#EDE8FD"
    readonly property color badgeUserText: "#6B4ED8"
    readonly property color badgeReadonlyBg: "#FFF3E0"
    readonly property color badgeReadonlyText: "#E65100"
    readonly property color badgeSuccessBg: "#E8F5E9"
    readonly property color badgeSuccessText: "#2E7D32"

    readonly property string fontHeading: "Sora"
    readonly property string fontBody: "Manrope"
    readonly property int radiusCard: 10
    readonly property int radiusModal: 16
    readonly property int radiusControl: 8

    // Soft card elevation from the design (shadow-card / shadow-card-hover).
    readonly property color shadowCard: "#0F000000"
    readonly property color shadowCardHover: "#268B67F2"
    readonly property int shadowY: 2
    readonly property int shadowYHover: 4
}
