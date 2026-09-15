// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Effects

/**
 * Floating "frosted glass" panel: a live blur of whatever sits behind it
 * (the theme preview stage), tinted and bordered per the Palco design.
 * Used for the header, library rail, filmstrip lane, command bar and the
 * small contextual chips/cards that float over the preview.
 */
Item {
    id: root

    property Item backdropSource
    property color tint: "transparent"
    property color borderColor: "transparent"
    property real cornerRadius: 16
    property real blurAmount: 22
    property color shadowColor: "transparent"
    property real shadowVerticalOffset: 8
    property real shadowBlur: 26

    Rectangle {
        id: dropShadow
        anchors.fill: parent
        anchors.topMargin: -shadowBlur / 2 + shadowVerticalOffset
        anchors.bottomMargin: -shadowBlur / 2 - shadowVerticalOffset
        anchors.leftMargin: -shadowBlur / 3
        anchors.rightMargin: -shadowBlur / 3
        radius: root.cornerRadius + shadowBlur / 3
        color: root.shadowColor
        visible: root.shadowColor.a > 0
        z: -2
    }

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.cornerRadius
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // NOTE: assumes `root` and `backdropSource` share the same coordinate
    // space (both are siblings anchored within the same full-window stage) —
    // mapToItem()'s result would not stay reactive to layout changes here.
    ShaderEffectSource {
        id: backdropGrab
        anchors.fill: parent
        sourceItem: root.backdropSource
        live: true
        recursive: false
        hideSource: false
        visible: false
        sourceRect: Qt.rect(root.x, root.y, root.width, root.height)
    }

    MultiEffect {
        anchors.fill: parent
        source: backdropGrab
        visible: root.backdropSource !== null && root.blurAmount > 0
        blurEnabled: true
        blur: 1.0
        blurMax: root.blurAmount
        blurMultiplier: 1.0
        maskEnabled: true
        maskSource: maskShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.05
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.tint
        border.width: root.borderColor.a > 0 ? 1 : 0
        border.color: root.borderColor
    }

    default property alias content: contentHolder.children
    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
