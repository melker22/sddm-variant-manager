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

    property int selectedThemeIndex: -1
    property int selectedVariantIndex: -1
    property int variantsRevision: 0
    property bool activateInSddm: true
    property string statusMessage: ""
    property string searchText: ""

    readonly property var currentTheme: {
        variantsRevision
        return selectedThemeIndex >= 0 ? themeScanner.themeAt(selectedThemeIndex) : ({})
    }
    readonly property var currentVariants: {
        variantsRevision
        return selectedThemeIndex >= 0 ? themeScanner.variantsForTheme(selectedThemeIndex) : []
    }
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

    Component.onCompleted: ensureThemeSelection()

    function ensureThemeSelection() {
        if (themeScanner.themeCount > 0 && selectedThemeIndex < 0) {
            selectedThemeIndex = 0
        }
        if (themeScanner.themeCount === 0) {
            selectedThemeIndex = -1
        }
    }

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
            variantsRevision++
            if (selectedThemeIndex >= themeScanner.themeCount) {
                selectedThemeIndex = themeScanner.themeCount > 0 ? themeScanner.themeCount - 1 : -1
            }
            ensureThemeSelection()
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

    pageStack.initialPage: Kirigami.Page {
        title: root.title

        actions: [
            Kirigami.Action {
                text: "Refresh themes"
                icon.name: "view-refresh"
                onTriggered: themeScanner.rescan()
            }
        ]

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Card {
                Layout.preferredWidth: 260
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 2
                        text: "SDDM Themes"
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: themeScanner.themeCount > 0
                            ? themeScanner.themeCount + " multi-variant theme(s) found"
                            : "No multi-variant themes found in /usr/share/sddm/themes or ~/.local/share/sddm/themes"
                    }

                    ListView {
                        id: themeListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: themeScanner.themeCount

                        delegate: ItemDelegate {
                            required property int index

                            width: themeListView.width
                            highlighted: root.selectedThemeIndex === index
                            onClicked: root.selectedThemeIndex = index

                            contentItem: Column {
                                spacing: 2
                                width: parent.width

                                Label {
                                    width: parent.width
                                    text: themeScanner.themeAt(index).name
                                    font.bold: root.selectedThemeIndex === index
                                    elide: Text.ElideRight
                                }

                                Label {
                                    width: parent.width
                                    text: themeScanner.themeAt(index).id
                                    opacity: 0.7
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Kirigami.Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.5

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
                        enabled: currentVariants.length > 0
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount === 0
                        text: "Install a SDDM theme with a Themes/*.conf folder (for example ZenMatrix / hyprlands-video-themes), then click Refresh themes."
                        icon.name: "preferences-desktop-theme"
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount > 0 && currentVariants.length === 0
                        text: "Select a theme on the left to browse its background variants."
                        icon.name: "view-grid"
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: currentVariants.length > 0

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
}
