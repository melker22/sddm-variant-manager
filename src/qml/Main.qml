// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    title: "SDDM Variant Manager"
    width: 1280
    height: 820
    minimumWidth: 900
    minimumHeight: 600

    property int selectedThemeIndex: themeScanner.themeCount > 0 ? 0 : -1
    property int selectedVariantIndex: -1
    property bool activateInSddm: true
    property string statusMessage: ""
    property string searchText: ""

    readonly property var currentTheme: selectedThemeIndex >= 0 ? themeScanner.themeAt(selectedThemeIndex) : ({})
    readonly property var currentVariants: selectedThemeIndex >= 0 ? themeScanner.variantsForTheme(selectedThemeIndex) : []
    readonly property var filteredVariants: {
        if (searchText.trim().length === 0) {
            return currentVariants
        }
        const needle = searchText.trim().toLowerCase()
        return currentVariants.filter(function(variant) {
            return variant.displayName.toLowerCase().includes(needle)
                || variant.id.toLowerCase().includes(needle)
        })
    }
    readonly property var currentVariant: selectedVariantIndex >= 0 && selectedVariantIndex < currentVariants.length
        ? currentVariants[selectedVariantIndex] : ({})

    Connections {
        target: themeApplier
        function onApplyFinished(success, message) {
            root.statusMessage = message
            if (success && root.activateInSddm) {
                themeApplier.setSddmCurrentTheme(root.currentTheme.id, true)
            }
        }
        function onSddmThemeFinished(success, message) {
            if (message.length > 0) {
                root.statusMessage = message
            }
        }
    }

    Connections {
        target: greeterPreview
        function onPreviewFinished(success, message) {
            root.statusMessage = message
            if (success) {
                themeScanner.rescan()
            }
        }
    }

    Connections {
        target: themeScanner
        function onThemesChanged() {
            if (selectedThemeIndex >= themeScanner.themeCount) {
                selectedThemeIndex = themeScanner.themeCount > 0 ? 0 : -1
            }
            selectedVariantIndex = -1
        }
    }

    onSelectedThemeIndexChanged: selectedVariantIndex = -1

    onCurrentVariantChanged: {
        if (currentVariant.backgroundPath) {
            previewPlayer.source = "file://" + currentVariant.backgroundPath
            previewPlayer.play()
        } else {
            previewPlayer.stop()
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        title: "SDDM Themes"
        modal: Kirigami.Settings.isMobile
        collapsible: true

        actions: [
            Kirigami.Action {
                text: "Refresh"
                icon.name: "view-refresh"
                onTriggered: themeScanner.rescan()
            }
        ]

        ListView {
            anchors.fill: parent
            model: themeScanner.themes
            clip: true

            delegate: ItemDelegate {
                required property var modelData
                required property int index

                width: ListView.view ? ListView.view.width : implicitWidth
                text: modelData.name + "\n" + modelData.path
                highlighted: root.selectedThemeIndex === index
                onClicked: root.selectedThemeIndex = index
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.62

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 2
                    text: currentTheme.name || "Select a theme"
                }

                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Search variants…"
                    text: root.searchText
                    onTextEdited: root.searchText = text
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    GridLayout {
                        width: parent.width
                        columns: Math.max(1, Math.floor(width / 220))
                        columnSpacing: Kirigami.Units.smallSpacing
                        rowSpacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: filteredVariants

                            delegate: Kirigami.Card {
                                required property var modelData
                                required property int index

                                property int sourceIndex: {
                                    for (let i = 0; i < currentVariants.length; ++i) {
                                        if (currentVariants[i].id === modelData.id) {
                                            return i
                                        }
                                    }
                                    return -1
                                }

                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 230
                                highlighted: root.selectedVariantIndex === sourceIndex || modelData.isActive

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    Image {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        source: modelData.thumbnailPath ? "file://" + modelData.thumbnailPath : ""
                                    }

                                    Kirigami.Heading {
                                        Layout.fillWidth: true
                                        level: 3
                                        text: modelData.displayName
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        visible: modelData.isActive
                                        text: "Active"
                                        color: Kirigami.Theme.positiveTextColor
                                    }

                                    Item { Layout.fillHeight: true }

                                    Button {
                                        Layout.fillWidth: true
                                        text: "Select"
                                        onClicked: root.selectedVariantIndex = sourceIndex
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Card {
            Layout.fillHeight: true
            Layout.preferredWidth: 360

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 2
                    text: currentVariant.displayName || "Preview"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    radius: Kirigami.Units.smallSpacing
                    color: Kirigami.Theme.backgroundColor
                    clip: true

                    AudioOutput {
                        id: previewAudio
                        volume: 0
                        muted: true
                    }

                    MediaPlayer {
                        id: previewPlayer
                        audioOutput: previewAudio
                        videoOutput: previewVideoOutput
                        loops: MediaPlayer.Infinite
                    }

                    VideoOutput {
                        id: previewVideoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        visible: !currentVariant.backgroundPath
                        text: "Select a variant to preview its background"
                    }
                }

                CheckBox {
                    text: "Also set as SDDM current theme"
                    checked: root.activateInSddm
                    onCheckedChanged: root.activateInSddm = checked
                }

                Button {
                    Layout.fillWidth: true
                    text: "Apply variant"
                    icon.name: "dialog-ok-apply"
                    enabled: currentVariant.configFile !== undefined
                    onClicked: themeApplier.applyVariant(currentTheme.metadataPath, currentVariant.configFile)
                }

                Button {
                    Layout.fillWidth: true
                    text: greeterPreview.running ? "Preview running…" : "Full SDDM preview"
                    icon.name: "system-run"
                    enabled: currentVariant.configFile !== undefined && !greeterPreview.running
                    onClicked: greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, currentVariant.configFile)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 3
                        text: "Details"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Config: " + (currentVariant.configFile || "—")
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Background: " + (currentVariant.backgroundPath || "—")
                    }
                }

                Item { Layout.fillHeight: true }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: statusMessage.length > 0
                    text: statusMessage
                    type: Kirigami.MessageType.Information
                }
            }
        }
    }
}
