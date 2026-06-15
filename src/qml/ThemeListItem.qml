// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: control

    required property int themeIndex
    required property var colors
    required property string themeName
    required property string themeSubtitle
    required property bool selected

    width: ListView.view ? ListView.view.width : implicitWidth
    highlighted: false

    // Inherit the Card palette for normal rows; only override when selected.
    Kirigami.Theme.inherit: !control.selected

    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: {
            if (control.selected) {
                return control.colors.primaryContainer
            }
            if (control.hovered) {
                return control.colors.surfaceVariant
            }
            return "transparent"
        }
    }

    contentItem: Column {
        spacing: 2
        width: parent.width

        Label {
            width: parent.width
            text: control.themeName
            font.bold: control.selected
            color: control.selected
                ? control.colors.onPrimaryContainer
                : Kirigami.Theme.textColor
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: control.themeSubtitle
            color: control.selected
                ? control.colors.onPrimaryContainer
                : Qt.rgba(
                      Kirigami.Theme.textColor.r,
                      Kirigami.Theme.textColor.g,
                      Kirigami.Theme.textColor.b,
                      0.72)
            opacity: control.selected ? 0.85 : 1.0
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideRight
        }
    }
}
