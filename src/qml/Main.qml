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
    readonly property string closePreviewHelp: "To close the full-screen preview: press Alt+Tab, select SDDM Variant Manager, then click Close preview."

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

    readonly property bool currentThemeHasVariants: currentTheme.hasVariants === true
    readonly property string previewMediaPath: previewPathForSelection()

    function previewPathForSelection() {
        variantsRevision
        if (selectedThemeIndex < 0) {
            return ""
        }
        if (currentThemeHasVariants) {
            if (selectedVariantIndex < 0 || selectedVariantIndex >= currentVariants.length) {
                return ""
            }
            return currentVariants[selectedVariantIndex].backgroundPath || ""
        }
        return currentTheme.previewPath || ""
    }

    function selectDefaultVariantForTheme() {
        if (!currentThemeHasVariants || currentVariants.length === 0) {
            selectedVariantIndex = -1
            return
        }

        let defaultIndex = 0
        for (let i = 0; i < currentVariants.length; ++i) {
            if (currentVariants[i].isActive) {
                defaultIndex = i
                break
            }
        }
        selectedVariantIndex = defaultIndex
    }

    Component.onCompleted: {
        ensureThemeSelection()
        if (!themeScanner.ffmpegAvailable) {
            statusMessage = "Install ffmpeg for high-quality thumbnails (recommended): pamac install ffmpeg"
        }
        if (!themeInstaller.gitAvailable) {
            if (statusMessage.length > 0) {
                statusMessage += " | "
            }
            statusMessage += "Install git to download themes from GitHub: pamac install git"
        }
    }

    function updatePreviewMedia() {
        previewPlayer.stop()
        const path = previewPathForSelection()
        if (path.length > 0) {
            previewPlayer.source = "file://" + path
            previewPlayer.play()
        } else {
            previewPlayer.source = ""
        }
    }

    function startFullPreview() {
        if (currentThemeHasVariants) {
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, currentVariant.configFile)
        } else {
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, "")
        }
    }

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
            if (success && root.activateInSddm && root.currentThemeHasVariants) {
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
            selectDefaultVariantForTheme()
            updatePreviewMedia()
        }
    }

    Connections {
        target: themeInstaller
        function onInstallFinished(success, message, installedThemeIds) {
            root.statusMessage = message
            if (success) {
                installThemeSheet.close()
                themeScanner.rescan()
                if (installedThemeIds.length > 0) {
                    const index = themeScanner.themeIndexForId(installedThemeIds[0])
                    if (index >= 0) {
                        selectedThemeIndex = index
                    }
                }
            }
        }
    }

    onSelectedThemeIndexChanged: {
        selectDefaultVariantForTheme()
        Qt.callLater(updatePreviewMedia)
    }

    onSelectedVariantIndexChanged: Qt.callLater(updatePreviewMedia)

    component VariantThumbnail: Image {
        property url mediaSource

        fillMode: Image.PreserveAspectCrop
        source: mediaSource
        asynchronous: true
        smooth: true
        mipmap: true
    }

    Connections {
        target: greeterPreview
        function onRunningChanged() {
            if (greeterPreview.running) {
                root.showMinimized()
            } else {
                root.showNormal()
                root.raise()
                root.requestActivate()
            }
        }
    }

    function openInstallThemeSheet() {
        if (!installThemeSheet.opened) {
            installThemeSheet.open()
        }
    }

    onClosing: function(close) {
        if (greeterPreview.running) {
            close.accepted = false
            root.showMinimized()
            statusMessage = "Preview still running. " + closePreviewHelp
        } else {
            Qt.quit()
        }
    }

    pageStack.initialPage: Kirigami.Page {
        title: root.title

        actions: [
            Kirigami.Action {
                text: "Install theme"
                icon.name: "download"
                onTriggered: root.openInstallThemeSheet()
            },
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
                            ? themeScanner.themeCount + " SDDM theme(s) found"
                            : "No SDDM themes found in /usr/share/sddm/themes or ~/.local/share/sddm/themes"
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
                                    text: {
                                        const theme = themeScanner.themeAt(index)
                                        if (theme.hasVariants) {
                                            return theme.variants.length + " variants · " + theme.installScope
                                        }
                                        return "Simple theme · " + theme.installScope
                                    }
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
                        enabled: currentThemeHasVariants && currentVariants.length > 0
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount === 0
                        text: "No SDDM themes installed yet. Use Install theme to download one from GitHub, or install a theme manually and click Refresh themes."
                        icon.name: "preferences-desktop-theme"
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount > 0 && selectedThemeIndex < 0
                        text: "Select a theme on the left."
                        icon.name: "view-grid"
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount > 0 && selectedThemeIndex >= 0 && !currentThemeHasVariants
                        text: "This theme has no background variants. Use the panel on the right to apply it or open a full SDDM preview."
                        icon.name: "image-missing"
                    }

                    Kirigami.PlaceholderMessage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount > 0 && currentThemeHasVariants && currentVariants.length === 0
                        text: "This theme has no readable variants in Themes/*.conf."
                        icon.name: "view-grid"
                    }

                    GridView {
                        id: variantGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: currentThemeHasVariants && currentVariants.length > 0
                        clip: true
                        model: filteredVariants
                        cellWidth: 220
                        cellHeight: 268

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: variantGrid.cellWidth - Kirigami.Units.smallSpacing
                            height: variantGrid.cellHeight - Kirigami.Units.smallSpacing

                            property int sourceIndex: {
                                for (let i = 0; i < currentVariants.length; ++i) {
                                    if (currentVariants[i].id === modelData.id) {
                                        return i
                                    }
                                }
                                return -1
                            }

                            Kirigami.Card {
                                anchors.fill: parent
                                highlighted: root.selectedVariantIndex === sourceIndex || modelData.isActive

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    VariantThumbnail {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 150
                                        mediaSource: modelData.thumbnailPath ? "file://" + modelData.thumbnailPath : ""
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

            Kirigami.Card {
                Layout.fillHeight: true
                Layout.preferredWidth: 360

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 2
                        text: currentThemeHasVariants
                            ? (currentVariant.displayName || currentTheme.name || "Preview")
                            : (currentTheme.name || "Preview")
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
                            visible: previewMediaPath.length === 0
                            text: currentThemeHasVariants
                                ? "Select a variant to preview its background"
                                : "No preview image found for this theme"
                        }
                    }

                    CheckBox {
                        text: "Also set as SDDM current theme"
                        checked: root.activateInSddm
                        onCheckedChanged: root.activateInSddm = checked
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: currentThemeHasVariants
                        text: "Apply variant"
                        icon.name: "dialog-ok-apply"
                        enabled: currentVariant.configFile !== undefined
                        onClicked: themeApplier.applyVariant(currentTheme.metadataPath, currentVariant.configFile)
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: !currentThemeHasVariants && selectedThemeIndex >= 0
                        text: "Apply as SDDM theme"
                        icon.name: "dialog-ok-apply"
                        enabled: currentTheme.id !== undefined
                        onClicked: themeApplier.applySimpleTheme(currentTheme.id, root.activateInSddm)
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: closePreviewHelp
                        opacity: 0.85
                    }

                    Button {
                        Layout.fillWidth: true
                        text: greeterPreview.running ? "Close preview" : "Full SDDM preview"
                        icon.name: greeterPreview.running ? "window-close" : "system-run"
                        enabled: (selectedThemeIndex >= 0 && (currentThemeHasVariants ? currentVariant.configFile !== undefined : true)) || greeterPreview.running
                        onClicked: {
                            if (greeterPreview.running) {
                                greeterPreview.stopPreview()
                            } else {
                                startFullPreview()
                            }
                        }
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: greeterPreview.running
                        text: closePreviewHelp
                        type: Kirigami.MessageType.Information
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
                            text: "Type: " + (currentThemeHasVariants ? "Multi-variant" : "Simple")
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            visible: currentThemeHasVariants
                            text: "Config: " + (currentVariant.configFile || "—")
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Background: " + (previewMediaPath || "—")
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

    Kirigami.OverlaySheet {
        id: installThemeSheet

        title: "Install SDDM theme"
        showCloseButton: true

        ColumnLayout {
            width: parent ? parent.width : implicitWidth
            Layout.preferredWidth: Math.min(root.width * 0.45, Kirigami.Units.gridUnit * 50)
            Layout.preferredHeight: root.height * 0.75
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                level: 2
                text: "Install from GitHub"
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Paste a public GitHub repository URL (HTTPS or SSH). All valid SDDM themes found in the repository will be installed."
            }

            TextField {
                id: repoUrlField
                Layout.fillWidth: true
                placeholderText: "https://github.com/user/sddm-theme"
            }

            CheckBox {
                id: systemWideCheck
                text: "Install system-wide (/usr/share/sddm/themes/) — requires admin password"
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.85
                text: "Default install location: ~/.local/share/sddm/themes/. HTTPS works for public repos. SSH requires your GitHub key to be configured."
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Button {
                    Layout.fillWidth: true
                    text: themeInstaller.installing ? "Installing…" : "Install theme"
                    icon.name: "download"
                    enabled: !themeInstaller.installing && repoUrlField.text.trim().length > 0
                    onClicked: themeInstaller.installFromUrl(repoUrlField.text.trim(), systemWideCheck.checked)
                }

                Button {
                    text: "Cancel"
                    onClicked: installThemeSheet.close()
                }
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: themeInstaller.installing
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: themeInstaller.progressMessage.length > 0
                text: themeInstaller.progressMessage
            }

            Item { Layout.fillHeight: true }
        }
    }
}
