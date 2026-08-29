// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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
    topPadding: 8
    bottomPadding: 8

    readonly property string badgeText: {
        if (control.readOnly)
            return "RO"
        if (control.scopeLabel === "System")
            return "SYSTEM"
        if (control.scopeLabel === "User")
            return "USER"
        return control.scopeLabel.toUpperCase()
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: {
                if (control.selected)
                    return Qt.rgba(control.colors.primary.r, control.colors.primary.g, control.colors.primary.b,
                                   control.colors.isDark ? 0.20 : 0.10)
                if (control.hovered)
                    return control.colors.isDark ? Qt.rgba(1, 1, 1, 0.05)
                                                : Qt.rgba(1, 1, 1, 0.60)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            visible: control.selected
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: 2
            color: control.colors.primary
        }
    }

    contentItem: RowLayout {
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 8
            color: control.colors.surfaceVariant
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

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "preferences-desktop-theme"
                color: control.colors.textMuted
                visible: !thumbImage.visible
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
                font.pixelSize: 13
                color: control.colors.surfaceFg
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: control.themeSubtitle
                font.family: control.bodyFont
                font.pixelSize: 11
                color: control.colors.textMuted
                elide: Text.ElideRight
            }
        }

        Rectangle {
            radius: 6
            color: control.readOnly ? control.colors.badgeReadonlyBg
                 : (control.scopeLabel === "System" ? control.colors.badgeSystemBg : control.colors.badgeUserBg)
            implicitHeight: badgeLbl.implicitHeight + 6
            implicitWidth: badgeLbl.implicitWidth + 12

            Label {
                id: badgeLbl
                anchors.centerIn: parent
                text: control.badgeText
                font.family: control.headingFont
                font.weight: Font.Bold
                font.pixelSize: 9
                color: control.readOnly ? control.colors.badgeReadonlyText
                     : (control.scopeLabel === "System" ? control.colors.badgeSystemText : control.colors.badgeUserText)
            }
        }
    }
}
