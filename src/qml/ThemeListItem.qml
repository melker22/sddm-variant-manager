// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ItemDelegate {
    id: control

    required property int themeIndex
    required property var colors
    required property string themeName
    required property string themeSubtitle
    required property string thumbnailSource
    required property string scopeLabel
    required property bool readOnly
    required property bool selected
    property string headingFont: "Sora"
    property string bodyFont: "Manrope"

    width: ListView.view
           ? (ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin)
           : implicitWidth
    height: 52
    highlighted: false
    hoverEnabled: true
    leftPadding: 10
    rightPadding: 10
    topPadding: 9
    bottomPadding: 9

    readonly property string badgeText: {
        if (control.readOnly)
            return "RO"
        if (control.scopeLabel === "System")
            return "SYS"
        if (control.scopeLabel === "User")
            return "USER"
        return control.scopeLabel.toUpperCase()
    }

    background: Rectangle {
        radius: 11
        color: {
            if (control.selected)
                return control.colors.rowSelected
            if (control.hovered)
                return Qt.rgba(control.colors.rowHover.r, control.colors.rowHover.g,
                                control.colors.rowHover.b, control.colors.rowHover.a * 0.5)
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: RowLayout {
        spacing: 11

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 9
            color: control.colors.fieldBg
            clip: true

            Image {
                id: thumbImage
                anchors.fill: parent
                source: control.thumbnailSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                visible: control.thumbnailSource.length > 0 && status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Label {
                Layout.fillWidth: true
                text: control.themeName
                font.family: control.headingFont
                font.weight: Font.Bold
                font.pixelSize: 14
                color: control.colors.textPrimary
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: control.themeSubtitle
                font.family: control.bodyFont
                font.pixelSize: 12
                color: control.colors.textSecondary
                elide: Text.ElideRight
            }
        }

        Rectangle {
            radius: 5
            color: "transparent"
            border.width: 1
            border.color: control.readOnly ? control.colors.badgeReadonlyBorder
                        : (control.scopeLabel === "User" ? control.colors.badgeUserBorder : control.colors.badgeBorder)
            implicitHeight: badgeLbl.implicitHeight + 6
            implicitWidth: badgeLbl.implicitWidth + 12

            Label {
                id: badgeLbl
                anchors.centerIn: parent
                text: control.badgeText
                font.family: control.headingFont
                font.weight: Font.Bold
                font.pixelSize: 10
                font.letterSpacing: 0.7
                color: control.readOnly ? control.colors.badgeReadonlyText
                     : (control.scopeLabel === "User" ? control.colors.badgeUserText : control.colors.badgeText)
            }
        }
    }
}
