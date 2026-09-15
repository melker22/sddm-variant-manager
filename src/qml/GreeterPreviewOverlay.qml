// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.layershell as LayerShellQt

// Loaded on demand — via Loader { source: "GreeterPreviewOverlay.qml" },
// never a static import — so a system without layer-shell-qt just fails
// this Loader (Loader.Error) instead of crashing the whole app.
//
// Two small windows (status chip, exit bar) float over the real SDDM
// greeter's fullscreen test-mode window. Plain Window x/y is not honored
// by Wayland compositors for ordinary toplevels (there is no global
// coordinate space a client can place itself in) — that's what made the
// previous plain-Window version collide both panels into the compositor's
// default placement. wlr-layer-shell (Hyprland, Sway, …) is the actual
// protocol for anchoring a small overlay surface to a screen edge, so it
// replaces manual positioning entirely: no anchor on the cross-axis (left
// and right here) centers the surface on that axis per the protocol.
QtObject {
    id: overlay

    property string headingFont: "Sora"
    property string bodyFont: "Manrope"
    property string themeLabel: ""
    property bool applyEnabled: false

    signal applyRequested()
    signal closeRequested()

    property Window chipWindow: Window {
        visible: true
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        color: "transparent"
        width: chipContent.implicitWidth + 32
        height: chipContent.implicitHeight + 18
        // Plain-window fallback for platforms layer-shell doesn't cover
        // (X11); harmless where layer-shell is active — the protocol's own
        // anchoring takes over positioning there regardless of x/y.
        x: Math.round((Screen.width - width) / 2)
        y: 26

        LayerShellQt.Window.layer: LayerShellQt.Window.LayerOverlay
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop
        LayerShellQt.Window.margins.top: 26
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "sddm-variant-manager-preview-chip"

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0.0549, 0.0588, 0.0824, 0.72)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            RowLayout {
                id: chipContent
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 3.5
                    color: "#42D68A"
                }
                Label {
                    text: overlay.themeLabel
                    font.family: overlay.bodyFont
                    font.pixelSize: 13
                    color: "#ECEAF3"
                }
            }
        }
    }

    property Window exitBarWindow: Window {
        visible: true
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
        color: "transparent"
        width: exitBarContent.implicitWidth + 34
        height: 64
        x: Math.round((Screen.width - width) / 2)
        y: Screen.height - 34 - height

        LayerShellQt.Window.layer: LayerShellQt.Window.LayerOverlay
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorBottom
        LayerShellQt.Window.margins.bottom: 34
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityNone
        LayerShellQt.Window.scope: "sddm-variant-manager-preview-exit-bar"

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Qt.rgba(0.0549, 0.0588, 0.0824, 0.74)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)

            RowLayout {
                id: exitBarContent
                anchors.centerIn: parent
                spacing: 18

                ColumnLayout {
                    spacing: 3
                    Label {
                        text: "You're looking at the real login"
                        font.family: overlay.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 15
                        color: "#F2F1F7"
                    }
                    Label {
                        text: "Variant Manager stays open behind it — Hyprland: Super+Q · Plasma: Alt+Tab"
                        font.family: overlay.bodyFont
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                Button {
                    id: applyFromPreviewBtn
                    implicitHeight: 42
                    leftPadding: 20
                    rightPadding: 20
                    enabled: overlay.applyEnabled
                    onClicked: overlay.applyRequested()
                    contentItem: Label {
                        text: "Apply this variant"
                        font.family: overlay.bodyFont
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: "#F2F1F7"
                    }
                    background: Rectangle {
                        radius: 11
                        color: applyFromPreviewBtn.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                    }
                }

                Button {
                    id: closePreviewFromBarBtn
                    implicitHeight: 42
                    leftPadding: 22
                    rightPadding: 22
                    onClicked: overlay.closeRequested()
                    contentItem: Label {
                        text: "Close preview"
                        font.family: overlay.bodyFont
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: "#12131A"
                    }
                    background: Rectangle {
                        radius: 11
                        color: "#ECEAF3"
                    }
                }
            }
        }
    }
}
