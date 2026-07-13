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

    width: ListView.view ? ListView.view.width : implicitWidth
    height: 52
    highlighted: false
    hoverEnabled: true
    leftPadding: 10
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: {
                if (control.selected)
                    return Qt.rgba(control.colors.primary.r, control.colors.primary.g, control.colors.primary.b, 0.12)
                if (control.hovered)
                    return Qt.rgba(control.colors.primary.r, control.colors.primary.g, control.colors.primary.b, 0.07)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            visible: control.selected
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            width: 3
            radius: 2
            color: control.colors.primary
        }
    }

    contentItem: RowLayout {
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 8
            color: control.colors.surfaceVariant
            border.width: 1
            border.color: control.colors.cardBorder
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
                font.weight: control.selected ? Font.DemiBold : Font.Medium
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
            visible: !control.readOnly
            radius: height / 2
            color: control.scopeLabel === "System" ? control.colors.badgeSystemBg : control.colors.badgeUserBg
            implicitHeight: scopeChip.implicitHeight + 4
            implicitWidth: scopeChip.implicitWidth + 14

            Label {
                id: scopeChip
                anchors.centerIn: parent
                text: control.scopeLabel
                font.family: control.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 11
                color: control.scopeLabel === "System" ? control.colors.badgeSystemText : control.colors.badgeUserText
            }
        }

        Rectangle {
            visible: control.readOnly
            radius: height / 2
            color: control.colors.badgeReadonlyBg
            implicitHeight: roChip.implicitHeight + 4
            implicitWidth: roChip.implicitWidth + 14

            Label {
                id: roChip
                anchors.centerIn: parent
                text: "Read-only"
                font.family: control.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 11
                color: control.colors.badgeReadonlyText
            }
        }
    }
}
