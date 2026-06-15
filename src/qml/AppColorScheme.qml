// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.kirigami.platform as Platform

QtObject {
    id: scheme

  // Qt.styleHints alone is unreliable on Hyprland/Wayland (often Light while Breeze is dark).
    readonly property bool isDark: {
        if (Qt.styleHints.colorScheme === Qt.ColorScheme.Dark) {
            return true
        }
        return Platform.Theme.textColor.hslLightness > 0.5
    }

    readonly property color primary: isDark ? "#E2BEE0" : "#B48EAD"
    readonly property color onPrimary: isDark ? "#4D3A4C" : "#FFFFFF"
    readonly property color primaryContainer: isDark ? "#674F65" : "#F2D7EC"
    readonly property color onPrimaryContainer: isDark ? "#F2D7EC" : "#3D2A3A"

    readonly property color secondary: isDark ? "#CCC2D0" : "#9C8FA1"
    readonly property color onSecondary: isDark ? "#352F3A" : "#FFFFFF"
    readonly property color secondaryContainer: isDark ? "#4C4452" : "#E8DFF0"
    readonly property color onSecondaryContainer: isDark ? "#E8DFF0" : "#332C38"

    readonly property color tertiary: isDark ? "#E3BBDD" : "#C7A2C5"
    readonly property color onTertiary: isDark ? "#473345" : "#FFFFFF"
    readonly property color tertiaryContainer: isDark ? "#5F4A5D" : "#F5DFF4"
    readonly property color onTertiaryContainer: isDark ? "#F5DFF4" : "#3F2D3E"

    readonly property color background: isDark ? "#1C1B1F" : "#FFFBFE"
    readonly property color surface: isDark ? "#1C1B1F" : "#FFFBFE"
    readonly property color surfaceVariant: isDark ? "#49454F" : "#E7E0EB"
    readonly property color outline: isDark ? "#948F99" : "#7A757F"
    readonly property color onSurface: isDark ? "#E6E1E5" : "#1C1B1F"
    readonly property color onSurfaceVariant: isDark ? "#CAC4D0" : "#49454F"

    readonly property string iconSource: isDark
        ? "qrc:/icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager-dark.svg"
        : "qrc:/icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager.svg"
}
