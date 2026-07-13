// SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami
import "."

Kirigami.ApplicationWindow {
    id: root

    title: "SDDM Variant Manager"
    width: 1440
    height: 900
    minimumWidth: 1100
    minimumHeight: 700

    AppColorScheme {
        id: appColors
    }

    FontLoader {
        id: soraFont
        source: "qrc:/fonts/Sora-Regular.ttf"
    }
    FontLoader {
        id: manropeFont
        source: "qrc:/fonts/Manrope-Regular.ttf"
    }

    readonly property string headingFont: soraFont.name.length > 0 ? soraFont.name : "Sora"
    readonly property string bodyFont: manropeFont.name.length > 0 ? manropeFont.name : "Manrope"

    Kirigami.Theme.inherit: false
    Kirigami.Theme.backgroundColor: appColors.background
    Kirigami.Theme.alternateBackgroundColor: appColors.surfaceVariant
    Kirigami.Theme.highlightColor: appColors.primary
    Kirigami.Theme.highlightedTextColor: appColors.primaryFg
    Kirigami.Theme.activeTextColor: appColors.primaryContainerFg
    Kirigami.Theme.activeBackgroundColor: appColors.primaryContainer
    Kirigami.Theme.hoverColor: appColors.surfaceVariant
    Kirigami.Theme.focusColor: appColors.primary
    Kirigami.Theme.linkColor: appColors.primary
    Kirigami.Theme.textColor: appColors.surfaceFg
    Kirigami.Theme.disabledTextColor: appColors.textMuted

    property int selectedThemeIndex: -1
    property int selectedVariantIndex: -1
    property int variantsRevision: 0
    property bool activateInSddm: true
    property string statusMessage: ""
    property string themeSearchText: ""
    property string variantSearchText: ""
    property int installTabIndex: 0
    property string localInstallPath: ""
    readonly property string closePreviewHelp: "To close the full-screen preview: press Alt+Tab, select SDDM Variant Manager, then click Close preview."
    readonly property string appVersion: "2.0.1"

    readonly property var currentTheme: {
        variantsRevision
        return selectedThemeIndex >= 0 ? themeScanner.themeAt(selectedThemeIndex) : ({})
    }
    readonly property var currentVariants: {
        variantsRevision
        return selectedThemeIndex >= 0 ? themeScanner.variantsForTheme(selectedThemeIndex) : []
    }
    readonly property var filteredThemeIndices: {
        variantsRevision
        const needle = themeSearchText.trim().toLowerCase()
        let indices = []
        for (let i = 0; i < themeScanner.themeCount; ++i) {
            const theme = themeScanner.themeAt(i)
            if (needle.length === 0
                || (theme.name || "").toLowerCase().includes(needle)
                || (theme.id || "").toLowerCase().includes(needle)
                || (theme.installScope || "").toLowerCase().includes(needle)) {
                indices.push(i)
            }
        }
        return indices
    }
    readonly property var filteredVariants: {
        if (variantSearchText.trim().length === 0) {
            return currentVariants
        }
        const needle = variantSearchText.trim().toLowerCase()
        return currentVariants.filter(function(variant) {
            return variant.displayName.toLowerCase().includes(needle)
                || variant.id.toLowerCase().includes(needle)
        })
    }
    readonly property var currentVariant: selectedVariantIndex >= 0 && selectedVariantIndex < currentVariants.length
        ? currentVariants[selectedVariantIndex] : ({})

    readonly property bool currentThemeHasVariants: currentTheme.hasVariants === true
    readonly property bool currentThemeReadOnly: currentTheme.readOnly === true
    readonly property string previewMediaPath: previewPathForSelection()
    readonly property url previewMediaUrl: previewMediaPath.length > 0 ? ("file://" + previewMediaPath) : ""
    readonly property bool previewIsVideo: themeScanner.pathIsVideo(previewMediaPath)
    readonly property bool previewIsGif: themeScanner.pathIsGif(previewMediaPath)
    readonly property bool previewIsImage: previewMediaPath.length > 0 && !previewIsVideo && !previewIsGif
    readonly property int totalVariantCount: {
        variantsRevision
        let n = 0
        for (let i = 0; i < themeScanner.themeCount; ++i) {
            const t = themeScanner.themeAt(i)
            if (t.hasVariants && t.variants)
                n += t.variants.length
        }
        return n
    }
    readonly property string activeStatusLabel: {
        if (selectedThemeIndex < 0)
            return "No theme selected"
        const themeName = currentTheme.name || currentTheme.id || "Theme"
        if (currentThemeHasVariants && currentVariant.displayName)
            return "SDDM Active: " + themeName + " · Variant: " + currentVariant.displayName
        return "SDDM Selected: " + themeName
    }

    function previewPathForSelection() {
        variantsRevision
        if (selectedThemeIndex < 0)
            return ""
        if (currentThemeHasVariants) {
            if (selectedVariantIndex < 0 || selectedVariantIndex >= currentVariants.length)
                return ""
            return currentVariants[selectedVariantIndex].backgroundPath || ""
        }
        return currentTheme.previewPath || ""
    }

    function themeThumbUrl(theme) {
        const path = theme.thumbnailPath || theme.previewPath || ""
        return path.length > 0 ? ("file://" + path) : ""
    }

    function themeScopeLabel(theme) {
        const scope = (theme.installScope || "").toLowerCase()
        if (scope === "system")
            return "System"
        if (scope === "user")
            return "User"
        return theme.installScope || "Theme"
    }

    function themeSubtitleText(theme) {
        if (theme.hasVariants)
            return theme.variants.length + " variant" + (theme.variants.length === 1 ? "" : "s")
        return "Simple theme"
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

    function notify(message) {
        if (!message || message.length === 0)
            return
        statusMessage = message
        root.showPassiveNotification(message, "short")
    }

    function ensureThemeSelection() {
        if (themeScanner.themeCount > 0 && selectedThemeIndex < 0)
            selectedThemeIndex = 0
        if (themeScanner.themeCount === 0)
            selectedThemeIndex = -1
    }

    function updatePreviewMedia() {
        previewPlayer.stop()
        if (!previewIsVideo || previewMediaPath.length === 0) {
            previewPlayer.source = ""
            return
        }
        previewPlayer.source = previewMediaUrl
        previewPlayer.play()
    }

    function startFullPreview() {
        if (currentThemeHasVariants)
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, currentVariant.configFile)
        else
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, "")
    }

    function openInstallThemeSheet(tabIndex) {
        installTabIndex = tabIndex === undefined ? 0 : tabIndex
        if (!installThemeSheet.opened)
            installThemeSheet.open()
    }

    function openLocalInstallWithPath(path) {
        localInstallPath = path
        openInstallThemeSheet(1)
    }

    function openThemeInFileManager() {
        if (!currentTheme.path)
            return
        Qt.openUrlExternally("file://" + currentTheme.path)
    }

    function copyPreviewCommand() {
        const cmd = "sddm-greeter --test-mode --theme " + (currentTheme.path || "<theme>")
        // Clipboard via temporary TextEdit
        clipboardHelper.text = cmd
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        notify("Copied to clipboard!")
    }

    function applyCurrentSelection() {
        if (currentTheme.requiresMultimedia === true && !greeterCapabilities.hasQtMultimedia) {
            const msg = greeterCapabilities.advisoryForTheme(currentTheme)
            notify(msg && msg.length ? msg : "This theme needs QtMultimedia in the system SDDM greeter. Install it system-wide first — the theme files will not be modified.")
        }
        if (currentThemeHasVariants) {
            if (currentThemeReadOnly || !currentVariant.configFile)
                return
            themeApplier.applyVariant(currentTheme.metadataPath, currentVariant.configFile)
        } else if (selectedThemeIndex >= 0 && currentTheme.id) {
            themeApplier.applySimpleTheme(currentTheme.id, root.activateInSddm, currentTheme.path || "")
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    Component.onCompleted: {
        ensureThemeSelection()
        if (!themeScanner.ffmpegAvailable)
            notify("Install ffmpeg for high-quality thumbnails (recommended).")
        if (!themeInstaller.gitAvailable)
            notify("Install git to download themes from GitHub.")
        if (greeterCapabilities.analyzed && !greeterCapabilities.hasQtMultimedia)
            notify("System SDDM greeter lacks QtMultimedia — video themes need it installed system-wide.")
    }

    Connections {
        target: themeApplier
        function onApplyFinished(success, message) {
            root.notify(message)
            if (success && root.activateInSddm && root.currentThemeHasVariants)
                themeApplier.setSddmCurrentTheme(root.currentTheme.id, true, root.currentTheme.path || "")
        }
        function onSddmThemeFinished(success, message) {
            if (message.length > 0)
                root.notify(message)
        }
    }

    Connections {
        target: greeterPreview
        function onPreviewFinished(success, message) {
            root.notify(message)
        }
        function onRunningChanged() {
            if (greeterPreview.running)
                root.showMinimized()
            else {
                root.showNormal()
                root.raise()
                root.requestActivate()
            }
        }
    }

    Connections {
        target: themeScanner
        function onThemesChanged() {
            variantsRevision++
            if (selectedThemeIndex >= themeScanner.themeCount)
                selectedThemeIndex = themeScanner.themeCount > 0 ? themeScanner.themeCount - 1 : -1
            ensureThemeSelection()
            selectedVariantIndex = -1
            selectDefaultVariantForTheme()
            updatePreviewMedia()
        }
    }

    Connections {
        target: themeInstaller
        function onInstallFinished(success, message, installedThemeIds) {
            root.notify(message)
            if (success) {
                installThemeSheet.close()
                localInstallPath = ""
                repoUrlField.text = ""
                themeScanner.rescan()
                if (installedThemeIds.length > 0) {
                    const index = themeScanner.themeIndexForId(installedThemeIds[0])
                    if (index >= 0)
                        selectedThemeIndex = index
                }
            }
        }
    }

    onSelectedThemeIndexChanged: {
        selectDefaultVariantForTheme()
        Qt.callLater(updatePreviewMedia)
    }
    onSelectedVariantIndexChanged: Qt.callLater(updatePreviewMedia)
    onPreviewMediaPathChanged: Qt.callLater(updatePreviewMedia)

    component VariantThumbnail: Image {
        property url mediaSource
        fillMode: Image.PreserveAspectCrop
        source: mediaSource
        asynchronous: true
        smooth: true
        mipmap: true
    }

    onClosing: function(close) {
        if (greeterPreview.running) {
            close.accepted = false
            root.showMinimized()
            notify("Preview still running. " + closePreviewHelp)
        } else {
            Qt.quit()
        }
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: function(drop) {
            if (!drop.hasUrls || drop.urls.length === 0)
                return
            openLocalInstallWithPath(drop.urls[0].toString())
        }

        Rectangle {
            anchors.fill: parent
            visible: parent.containsDrag
            color: Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.12)
            border.width: 2
            border.color: appColors.primary
            z: 1000

            Label {
                anchors.centerIn: parent
                text: "Drop theme folder or archive to install"
                font.family: root.headingFont
                font.bold: true
                color: appColors.primary
            }
        }
    }

    FileDialog {
        id: archiveFileDialog
        title: "Choose theme archive"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Theme archives (*.zip *.tar *.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tbz2 *.tar.zst *.tzst)",
            "All files (*)"
        ]
        onAccepted: {
            if (selectedFile)
                root.localInstallPath = selectedFile.toString()
        }
    }

    FolderDialog {
        id: themeFolderDialog
        title: "Choose theme folder"
        onAccepted: {
            if (selectedFolder)
                root.localInstallPath = selectedFolder.toString()
        }
    }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        title: ""
        background: Rectangle { color: appColors.background }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header 60px ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: appColors.surface
                z: 50

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: appColors.cardBorder
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    RowLayout {
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            source: "qrc:/icons/app-logo.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        Label {
                            text: "SDDM Variant Manager"
                            font.family: root.headingFont
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            color: appColors.surfaceFg
                        }

                        Rectangle {
                            radius: height / 2
                            color: appColors.background
                            border.width: 1
                            border.color: appColors.cardBorder
                            implicitHeight: verLabel.implicitHeight + 4
                            implicitWidth: verLabel.implicitWidth + 16

                            Label {
                                id: verLabel
                                anchors.centerIn: parent
                                text: "v" + root.appVersion
                                font.family: root.bodyFont
                                font.pixelSize: 11
                                color: appColors.textMuted
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: selectedThemeIndex >= 0
                        radius: height / 2
                        color: appColors.badgeSuccessBg
                        implicitHeight: statusPill.implicitHeight + 12
                        implicitWidth: statusPill.implicitWidth + 28

                        RowLayout {
                            id: statusPill
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: appColors.badgeSuccessText
                            }

                            Label {
                                text: root.activeStatusLabel
                                font.family: root.bodyFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 12
                                color: appColors.badgeSuccessText
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 8

                        Button {
                            id: installPrimaryBtn
                            text: "Install Theme"
                            icon.name: "list-add"
                            onClicked: root.openInstallThemeSheet(0)

                            contentItem: RowLayout {
                                spacing: 8
                                Kirigami.Icon {
                                    source: "list-add"
                                    Layout.preferredWidth: 12
                                    Layout.preferredHeight: 12
                                    color: "white"
                                }
                                Label {
                                    text: "Install Theme"
                                    font.family: root.bodyFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 13
                                    color: "white"
                                }
                            }
                            background: Rectangle {
                                radius: appColors.radiusCard
                                color: installPrimaryBtn.down ? appColors.accentHover
                                      : (installPrimaryBtn.hovered ? appColors.accentHover : appColors.primary)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        Button {
                            id: fromFileBtn
                            text: "From File…"
                            onClicked: root.openInstallThemeSheet(1)

                            contentItem: RowLayout {
                                spacing: 8
                                Kirigami.Icon {
                                    source: "folder-open"
                                    Layout.preferredWidth: 12
                                    Layout.preferredHeight: 12
                                    color: appColors.primary
                                }
                                Label {
                                    text: "From File…"
                                    font.family: root.bodyFont
                                    font.weight: Font.Medium
                                    font.pixelSize: 13
                                    color: appColors.surfaceVariantFg
                                }
                            }
                            background: Rectangle {
                                radius: appColors.radiusCard
                                color: fromFileBtn.hovered ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.08) : appColors.surface
                                border.width: 1
                                border.color: fromFileBtn.hovered ? appColors.primary : appColors.cardBorder
                            }
                        }

                        Button {
                            id: refreshBtn
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: themeScanner.rescan()
                            ToolTip.visible: hovered
                            ToolTip.text: "Refresh themes"
                            ToolTip.delay: Kirigami.Units.toolTipDelay

                            contentItem: Kirigami.Icon {
                                source: "view-refresh"
                                color: appColors.primary
                            }
                            background: Rectangle {
                                radius: appColors.radiusCard
                                color: refreshBtn.hovered ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.08) : appColors.surface
                                border.width: 1
                                border.color: appColors.cardBorder
                            }
                        }
                    }
                }
            }

            // ── Main three columns ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // LEFT SIDEBAR 260px
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    color: appColors.sidebar

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: appColors.cardBorder
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 16
                            Layout.bottomMargin: 12
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "THEME LIBRARY"
                                    font.family: root.headingFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 13
                                    font.letterSpacing: 0.6
                                    color: appColors.accentDark
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    radius: height / 2
                                    color: appColors.surface
                                    border.width: 1
                                    border.color: appColors.cardBorder
                                    implicitHeight: countChip.implicitHeight + 4
                                    implicitWidth: countChip.implicitWidth + 14

                                    Label {
                                        id: countChip
                                        anchors.centerIn: parent
                                        text: themeScanner.themeCount + " theme" + (themeScanner.themeCount === 1 ? "" : "s")
                                        font.family: root.bodyFont
                                        font.pixelSize: 11
                                        color: appColors.textMuted
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: appColors.radiusCard
                                color: appColors.surface
                                border.width: 1
                                border.color: themeSearchInput.activeFocus ? appColors.primary : appColors.cardBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Kirigami.Icon {
                                        source: "edit-find"
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        color: appColors.textMuted
                                    }

                                    TextField {
                                        id: themeSearchInput
                                        Layout.fillWidth: true
                                        placeholderText: "Search themes…"
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        color: appColors.surfaceFg
                                        background: Item {}
                                        onTextChanged: root.themeSearchText = text
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(appColors.cardBorder.r, appColors.cardBorder.g, appColors.cardBorder.b, 0.6)
                        }

                        ListView {
                            id: themeListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            topMargin: 8
                            bottomMargin: 8
                            leftMargin: 8
                            rightMargin: 8
                            model: filteredThemeIndices

                            delegate: ThemeListItem {
                                required property int modelData
                                themeIndex: modelData
                                colors: appColors
                                headingFont: root.headingFont
                                bodyFont: root.bodyFont
                                themeName: {
                                    const theme = themeScanner.themeAt(modelData)
                                    return theme.name || theme.id || "Theme"
                                }
                                themeSubtitle: themeSubtitleText(themeScanner.themeAt(modelData))
                                thumbnailSource: themeThumbUrl(themeScanner.themeAt(modelData))
                                scopeLabel: themeScopeLabel(themeScanner.themeAt(modelData))
                                readOnly: themeScanner.themeAt(modelData).readOnly === true
                                selected: root.selectedThemeIndex === modelData
                                onClicked: root.selectedThemeIndex = modelData
                            }

                            Kirigami.PlaceholderMessage {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                visible: themeScanner.themeCount === 0
                                text: "No themes yet"
                                explanation: "Install from GitHub, a local folder, or an archive."
                                icon.name: "preferences-desktop-theme"
                                helpfulAction: Kirigami.Action {
                                    text: "Install Theme"
                                    icon.name: "list-add"
                                    onTriggered: root.openInstallThemeSheet(0)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: appColors.cardBorder
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            spacing: 8

                            Kirigami.Icon {
                                source: "help-about"
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                color: appColors.primary
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "Themes: ~/.local/share/sddm/"
                                font.family: root.bodyFont
                                font.pixelSize: 11
                                color: appColors.textMuted
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }

                // CENTER: Variant Gallery
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        color: appColors.surface

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: appColors.cardBorder
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8

                                    Label {
                                        text: currentTheme.name || "Select a theme"
                                        font.family: root.headingFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 18
                                        color: appColors.surfaceFg
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: selectedThemeIndex >= 0
                                        radius: height / 2
                                        color: themeScopeLabel(currentTheme) === "System"
                                               ? appColors.badgeSystemBg : appColors.badgeUserBg
                                        implicitHeight: scopeBadge.implicitHeight + 6
                                        implicitWidth: scopeBadge.implicitWidth + 16

                                        Label {
                                            id: scopeBadge
                                            anchors.centerIn: parent
                                            text: themeScopeLabel(currentTheme) + " Scope"
                                            font.family: root.bodyFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 11
                                            color: themeScopeLabel(currentTheme) === "System"
                                                   ? appColors.badgeSystemText : appColors.badgeUserText
                                        }
                                    }
                                }

                                Label {
                                    visible: selectedThemeIndex >= 0
                                    text: currentThemeHasVariants
                                          ? (currentVariants.length + " variant" + (currentVariants.length === 1 ? "" : "s") + " available")
                                          : "Simple theme · no background variants"
                                    font.family: root.bodyFont
                                    font.pixelSize: 12
                                    color: appColors.textMuted
                                }
                            }

                            Rectangle {
                                visible: currentThemeHasVariants && currentVariants.length > 0
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 34
                                radius: appColors.radiusCard
                                color: appColors.surface
                                border.width: 1
                                border.color: variantSearchInput.activeFocus ? appColors.primary : appColors.cardBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Kirigami.Icon {
                                        source: "edit-find"
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        color: appColors.textMuted
                                    }

                                    TextField {
                                        id: variantSearchInput
                                        Layout.fillWidth: true
                                        placeholderText: "Search variants…"
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        color: appColors.surfaceFg
                                        background: Item {}
                                        onTextChanged: root.variantSearchText = text
                                    }
                                }
                            }
                        }
                    }

                    // Gallery body
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: galleryColumn.implicitHeight + 40
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: galleryColumn
                            width: parent.width
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 20
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            spacing: 16

                            Kirigami.PlaceholderMessage {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                visible: themeScanner.themeCount === 0
                                text: "Welcome"
                                explanation: "Install an SDDM theme to get started. You can use GitHub, a local folder, or an archive."
                                icon.name: "preferences-desktop-theme"
                                helpfulAction: Kirigami.Action {
                                    text: "Install Theme"
                                    icon.name: "list-add"
                                    onTriggered: root.openInstallThemeSheet(0)
                                }
                            }

                            Kirigami.PlaceholderMessage {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                visible: themeScanner.themeCount > 0 && selectedThemeIndex < 0
                                text: "Select a theme"
                                explanation: "Pick a theme from the library on the left."
                                icon.name: "view-list-details"
                            }

                            Kirigami.PlaceholderMessage {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 220
                                visible: themeScanner.themeCount > 0 && selectedThemeIndex >= 0 && !currentThemeHasVariants
                                text: "This theme has no background variants."
                                explanation: "Use the Inspector on the right to apply it or open a full SDDM preview."
                                icon.name: "image"
                            }

                            Kirigami.PlaceholderMessage {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 220
                                visible: currentThemeHasVariants && currentVariants.length > 0 && filteredVariants.length === 0
                                text: "No matching variants"
                                explanation: "Try another search term."
                                icon.name: "edit-find"
                            }

                            GridView {
                                id: variantGrid
                                Layout.fillWidth: true
                                visible: currentThemeHasVariants && filteredVariants.length > 0
                                interactive: false
                                model: filteredVariants
                                readonly property int columns: Math.max(2, Math.floor(width / 230))
                                cellWidth: Math.floor(width / columns)
                                cellHeight: Math.floor(cellWidth * 0.78)
                                height: Math.ceil((filteredVariants.length + 1) / columns) * cellHeight
                                clip: false

                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: variantGrid.cellWidth
                                    height: variantGrid.cellHeight

                                    property int sourceIndex: {
                                        for (let i = 0; i < currentVariants.length; ++i) {
                                            if (currentVariants[i].id === modelData.id)
                                                return i
                                        }
                                        return -1
                                    }
                                    property bool variantSelected: root.selectedVariantIndex === sourceIndex
                                    property bool variantActive: modelData.isActive === true

                                    Rectangle {
                                        id: cardChrome
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        radius: appColors.radiusCard
                                        color: appColors.surface
                                        border.width: variantSelected ? 2 : 1
                                        border.color: variantSelected ? appColors.primary : appColors.cardBorder
                                        clip: true

                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Behavior on y { NumberAnimation { duration: 120 } }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 0

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true

                                                VariantThumbnail {
                                                    anchors.fill: parent
                                                    mediaSource: modelData.thumbnailPath ? "file://" + modelData.thumbnailPath : ""
                                                }

                                                Rectangle {
                                                    visible: variantActive
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 8
                                                    radius: height / 2
                                                    color: appColors.primary
                                                    implicitHeight: activeLbl.implicitHeight + 8
                                                    implicitWidth: activeRow.implicitWidth + 18

                                                    RowLayout {
                                                        id: activeRow
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Rectangle {
                                                            Layout.preferredWidth: 6
                                                            Layout.preferredHeight: 6
                                                            radius: 3
                                                            color: "white"
                                                        }

                                                        Label {
                                                            id: activeLbl
                                                            text: "Active"
                                                            font.family: root.bodyFont
                                                            font.weight: Font.DemiBold
                                                            font.pixelSize: 11
                                                            color: "white"
                                                        }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.margins: 10
                                                spacing: 2

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: modelData.displayName
                                                    font.family: root.headingFont
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 13
                                                    color: appColors.surfaceFg
                                                    elide: Text.ElideRight
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: modelData.configFile || modelData.id || ""
                                                    font.family: root.bodyFont
                                                    font.pixelSize: 11
                                                    color: appColors.textMuted
                                                    elide: Text.ElideMiddle
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectedVariantIndex = sourceIndex
                                            onEntered: cardChrome.y = -2
                                            onExited: cardChrome.y = 0
                                        }
                                    }
                                }
                            }

                            // Add Variant dashed card (opens install)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                visible: selectedThemeIndex >= 0
                                radius: appColors.radiusCard
                                color: addVariantMouse.containsMouse ? appColors.primaryContainer : "transparent"
                                border.width: 2
                                border.color: addVariantMouse.containsMouse ? appColors.primary : appColors.cardBorder

                                MouseArea {
                                    id: addVariantMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openInstallThemeSheet(0)
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: appColors.primaryContainer

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: "list-add"
                                            color: appColors.primary
                                        }
                                    }

                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Install another theme"
                                        font.family: root.bodyFont
                                        font.pixelSize: 12
                                        color: appColors.textMuted
                                    }
                                }
                            }

                            // Theme Information card
                            Rectangle {
                                Layout.fillWidth: true
                                visible: selectedThemeIndex >= 0
                                radius: appColors.radiusCard
                                color: appColors.surface
                                border.width: 1
                                border.color: appColors.cardBorder
                                implicitHeight: infoCol.implicitHeight + 32

                                ColumnLayout {
                                    id: infoCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 16
                                    spacing: 12

                                    Label {
                                        text: "Theme Information"
                                        font.family: root.headingFont
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 13
                                        color: appColors.surfaceFg
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 32
                                        rowSpacing: 4

                                        Label {
                                            text: "Type"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: currentThemeHasVariants ? "Multi-variant" : "Simple"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 12
                                            color: appColors.surfaceFg
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Label {
                                            text: "Scope"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: themeScopeLabel(currentTheme)
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 12
                                            color: appColors.surfaceFg
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Label {
                                            text: "Config"
                                            visible: currentThemeHasVariants
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            visible: currentThemeHasVariants
                                            text: currentVariant.configFile || "—"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 12
                                            color: appColors.accentDark
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideMiddle
                                        }

                                        Label {
                                            text: "Background"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: previewMediaPath.length > 0 ? previewMediaPath : "—"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 11
                                            color: appColors.accentDark
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideMiddle
                                            ToolTip.visible: truncated && bgHover.hovered
                                            ToolTip.text: previewMediaPath
                                            HoverHandler { id: bgHover }
                                        }

                                        Label {
                                            text: "Path"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: currentTheme.path || "—"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 11
                                            color: appColors.accentDark
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideMiddle
                                        }

                                        Label {
                                            text: "Needs multimedia"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: currentTheme.requiresMultimedia === true ? "Yes (QtMultimedia)" : "No"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 12
                                            color: currentTheme.requiresMultimedia === true
                                                   && !greeterCapabilities.hasQtMultimedia
                                                   ? "#B3261E"
                                                   : appColors.surfaceFg
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }

                            // System SDDM greeter capabilities (read-only analysis)
                            Rectangle {
                                Layout.fillWidth: true
                                radius: appColors.radiusCard
                                color: appColors.surface
                                border.width: 1
                                border.color: appColors.cardBorder
                                implicitHeight: greeterCapCol.implicitHeight + 32

                                ColumnLayout {
                                    id: greeterCapCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 16
                                    spacing: 8

                                    Label {
                                        text: "System SDDM greeter"
                                        font.family: root.headingFont
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 13
                                        color: appColors.surfaceFg
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: greeterCapabilities.summary
                                        font.family: root.bodyFont
                                        font.pixelSize: 11
                                        color: appColors.textMuted
                                        wrapMode: Text.WordWrap
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        visible: greeterCapabilities.isNixOS && !greeterCapabilities.hasQtMultimedia
                                        text: "Video themes need kdePackages.qtmultimedia in services.displayManager.sddm.extraPackages, then nixos-rebuild. Themes are never rewritten."
                                        font.family: root.bodyFont
                                        font.pixelSize: 11
                                        color: appColors.surfaceFg
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 8 }
                        }
                    }
                }

                // RIGHT INSPECTOR 320px
                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    color: appColors.surface

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: 1
                        color: appColors.cardBorder
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: 16
                            Layout.bottomMargin: 12

                            Label {
                                text: "INSPECTOR"
                                font.family: root.headingFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 13
                                font.letterSpacing: 0.6
                                color: appColors.accentDark
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: appColors.cardBorder
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: inspectorBody.implicitHeight + 24
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: inspectorBody
                                width: parent.width
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                spacing: 14

                                // Hero preview
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width * 9 / 16

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: appColors.radiusCard
                                        color: appColors.surfaceVariant
                                        border.width: 1
                                        border.color: appColors.cardBorder
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
                                            onMediaStatusChanged: function(status) {
                                                if (!root.previewIsVideo)
                                                    return
                                                if (status === MediaPlayer.LoadedMedia || status === MediaPlayer.BufferedMedia)
                                                    play()
                                            }
                                        }

                                        VideoOutput {
                                            id: previewVideoOutput
                                            anchors.fill: parent
                                            visible: root.previewIsVideo
                                            fillMode: VideoOutput.PreserveAspectCrop
                                        }

                                        AnimatedImage {
                                            anchors.fill: parent
                                            visible: root.previewIsGif
                                            source: root.previewIsGif ? root.previewMediaUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                            playing: root.previewIsGif
                                            asynchronous: true
                                            smooth: true
                                        }

                                        Image {
                                            anchors.fill: parent
                                            visible: root.previewIsImage
                                            source: root.previewIsImage ? root.previewMediaUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            gradient: Gradient {
                                                GradientStop { position: 0.55; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
                                            }
                                            visible: previewMediaPath.length > 0
                                        }

                                        Rectangle {
                                            visible: selectedThemeIndex >= 0 && (
                                                (currentThemeHasVariants && currentVariant.isActive)
                                                || (!currentThemeHasVariants))
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 10
                                            radius: height / 2
                                            color: appColors.primary
                                            implicitHeight: curActiveLbl.implicitHeight + 8
                                            implicitWidth: curActiveRow.implicitWidth + 18

                                            RowLayout {
                                                id: curActiveRow
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Rectangle {
                                                    Layout.preferredWidth: 6
                                                    Layout.preferredHeight: 6
                                                    radius: 3
                                                    color: "white"
                                                }
                                                Label {
                                                    id: curActiveLbl
                                                    text: "Currently Active"
                                                    font.family: root.bodyFont
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 11
                                                    color: "white"
                                                }
                                            }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            visible: previewMediaPath.length === 0
                                            text: selectedThemeIndex < 0 ? "No selection" : "No preview"
                                            font.family: root.bodyFont
                                            color: appColors.textMuted
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        Layout.fillWidth: true
                                        text: currentThemeHasVariants
                                              ? (currentVariant.displayName || currentTheme.name || "—")
                                              : (currentTheme.name || "—")
                                        font.family: root.headingFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 17
                                        color: appColors.surfaceFg
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: currentThemeHasVariants
                                              ? ((currentTheme.name || "") + " · Background Variant")
                                              : (themeScopeLabel(currentTheme) + " · Simple Theme")
                                        font.family: root.bodyFont
                                        font.pixelSize: 12
                                        color: appColors.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: appColors.radiusCard
                                    color: appColors.background
                                    border.width: 1
                                    border.color: appColors.cardBorder
                                    implicitHeight: metaCol.implicitHeight

                                    ColumnLayout {
                                        id: metaCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        spacing: 0

                                        component MetaRow: RowLayout {
                                            property string label
                                            property string value
                                            property bool showBadge: false
                                            property string badgeKind: "user"
                                            Layout.fillWidth: true
                                            height: 40

                                            Label {
                                                text: label
                                                font.family: root.bodyFont
                                                font.pixelSize: 12
                                                color: appColors.textMuted
                                                Layout.leftMargin: 12
                                            }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                visible: showBadge
                                                radius: height / 2
                                                color: badgeKind === "system" ? appColors.badgeSystemBg
                                                     : (badgeKind === "readonly" ? appColors.badgeReadonlyBg : appColors.badgeUserBg)
                                                implicitHeight: badgeTxt.implicitHeight + 4
                                                implicitWidth: badgeTxt.implicitWidth + 14
                                                Layout.rightMargin: 12
                                                Label {
                                                    id: badgeTxt
                                                    anchors.centerIn: parent
                                                    text: value
                                                    font.family: root.bodyFont
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 11
                                                    color: badgeKind === "system" ? appColors.badgeSystemText
                                                         : (badgeKind === "readonly" ? appColors.badgeReadonlyText : appColors.badgeUserText)
                                                }
                                            }
                                            Label {
                                                visible: !showBadge
                                                text: value
                                                font.family: root.bodyFont
                                                font.weight: Font.Medium
                                                font.pixelSize: 12
                                                color: appColors.surfaceFg
                                                Layout.rightMargin: 12
                                                elide: Text.ElideMiddle
                                                Layout.maximumWidth: 160
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 1
                                                color: appColors.cardBorder
                                                Layout.columnSpan: 99
                                                visible: false
                                            }
                                        }

                                        MetaRow {
                                            label: "Scope"
                                            value: themeScopeLabel(currentTheme)
                                            showBadge: true
                                            badgeKind: themeScopeLabel(currentTheme) === "System" ? "system" : "user"
                                        }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: appColors.cardBorder }
                                        MetaRow {
                                            label: "Type"
                                            value: currentThemeHasVariants ? "Background Image" : "Simple Theme"
                                        }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: appColors.cardBorder }
                                        MetaRow {
                                            label: "Path"
                                            value: currentTheme.path || "—"
                                        }
                                        Rectangle { Layout.fillWidth: true; height: 1; color: appColors.cardBorder }
                                        MetaRow {
                                            label: "Read-only"
                                            value: currentThemeReadOnly ? "Yes" : "No"
                                            showBadge: currentThemeReadOnly
                                            badgeKind: "readonly"
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    CheckBox {
                                        id: activateCheck
                                        checked: root.activateInSddm
                                        onCheckedChanged: root.activateInSddm = checked
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: "Also set as SDDM current theme"
                                        font.family: root.bodyFont
                                        font.pixelSize: 12
                                        color: appColors.surfaceFg
                                        wrapMode: Text.WordWrap
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: activateCheck.checked = !activateCheck.checked
                                        }
                                    }
                                }

                                Kirigami.InlineMessage {
                                    Layout.fillWidth: true
                                    visible: currentThemeHasVariants && currentThemeReadOnly
                                    text: "Read-only Nix theme. Install a writable copy before applying variants."
                                    type: Kirigami.MessageType.Information
                                }

                                Kirigami.InlineMessage {
                                    Layout.fillWidth: true
                                    visible: selectedThemeIndex >= 0
                                             && currentTheme.requiresMultimedia === true
                                             && !greeterCapabilities.hasQtMultimedia
                                    text: "This theme needs QtMultimedia in the system SDDM greeter. Add it to the OS (NixOS: services.displayManager.sddm.extraPackages), then rebuild — the app will not alter theme files."
                                    type: Kirigami.MessageType.Warning
                                }

                                Kirigami.InlineMessage {
                                    Layout.fillWidth: true
                                    visible: greeterCapabilities.analyzed
                                             && greeterCapabilities.isNixOS
                                             && !greeterCapabilities.hasQtMultimedia
                                             && !(selectedThemeIndex >= 0 && currentTheme.requiresMultimedia === true)
                                    text: "System SDDM greeter is missing QtMultimedia. Video themes will show UI without background until you add kdePackages.qtmultimedia to sddm.extraPackages."
                                    type: Kirigami.MessageType.Information
                                }

                                Kirigami.InlineMessage {
                                    Layout.fillWidth: true
                                    visible: greeterPreview.running
                                    text: closePreviewHelp
                                    type: Kirigami.MessageType.Positive
                                }

                                // Action buttons
                                Button {
                                    id: applyBtn
                                    Layout.fillWidth: true
                                    enabled: selectedThemeIndex >= 0 && (
                                        currentThemeHasVariants
                                            ? (!currentThemeReadOnly && currentVariant.configFile !== undefined)
                                            : currentTheme.id !== undefined)
                                    onClicked: root.applyCurrentSelection()

                                    contentItem: RowLayout {
                                        spacing: 8
                                        Item { Layout.fillWidth: true }
                                        Kirigami.Icon {
                                            source: "dialog-ok-apply"
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            color: "white"
                                        }
                                        Label {
                                            text: "Apply as SDDM Theme"
                                            font.family: root.bodyFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 13
                                            color: "white"
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    background: Rectangle {
                                        radius: appColors.radiusCard
                                        color: !applyBtn.enabled ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.4)
                                             : (applyBtn.down || applyBtn.hovered ? appColors.accentHover : appColors.primary)
                                    }
                                }

                                Button {
                                    id: previewBtn
                                    Layout.fillWidth: true
                                    enabled: (selectedThemeIndex >= 0 && (currentThemeHasVariants ? currentVariant.configFile !== undefined : true)) || greeterPreview.running
                                    onClicked: {
                                        if (greeterPreview.running)
                                            greeterPreview.stopPreview()
                                        else
                                            startFullPreview()
                                    }

                                    contentItem: RowLayout {
                                        spacing: 8
                                        Item { Layout.fillWidth: true }
                                        Kirigami.Icon {
                                            source: greeterPreview.running ? "window-close" : "media-playback-start"
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            color: appColors.primary
                                        }
                                        Label {
                                            text: greeterPreview.running ? "Close Preview" : "Full SDDM Preview"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 13
                                            color: appColors.surfaceVariantFg
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    background: Rectangle {
                                        radius: appColors.radiusCard
                                        color: previewBtn.hovered ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.08) : appColors.surface
                                        border.width: 1
                                        border.color: previewBtn.hovered ? appColors.primary : appColors.cardBorder
                                    }
                                }

                                Button {
                                    id: openFolderBtn
                                    Layout.fillWidth: true
                                    enabled: selectedThemeIndex >= 0 && currentTheme.path
                                    onClicked: root.openThemeInFileManager()

                                    contentItem: RowLayout {
                                        spacing: 8
                                        Item { Layout.fillWidth: true }
                                        Kirigami.Icon {
                                            source: "folder-open"
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            color: appColors.primary
                                        }
                                        Label {
                                            text: "Open in File Manager"
                                            font.family: root.bodyFont
                                            font.weight: Font.Medium
                                            font.pixelSize: 13
                                            color: appColors.surfaceVariantFg
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                    background: Rectangle {
                                        radius: appColors.radiusCard
                                        color: openFolderBtn.hovered ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.08) : appColors.surface
                                        border.width: 1
                                        border.color: appColors.cardBorder
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: appColors.cardBorder
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            spacing: 6

                            Label {
                                text: "Preview command"
                                font.family: root.bodyFont
                                font.pixelSize: 11
                                color: appColors.textMuted
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 8
                                color: appColors.background
                                border.width: 1
                                border.color: appColors.cardBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Kirigami.Icon {
                                        source: "utilities-terminal"
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        color: appColors.primary
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: "sddm-greeter --test-mode"
                                        font.family: root.bodyFont
                                        font.pixelSize: 11
                                        color: appColors.surfaceVariantFg
                                        elide: Text.ElideRight
                                    }

                                    ToolButton {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        icon.name: "edit-copy"
                                        onClicked: root.copyPreviewCommand()
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Copy"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer 28px ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: appColors.surface

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: appColors.cardBorder
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    Label {
                        text: themeScanner.themeCount + " themes · " + root.totalVariantCount + " variants installed"
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        text: statusMessage.length > 0 ? statusMessage : ("SDDM Variant Manager v" + root.appVersion)
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width * 0.45
                    }
                }
            }
        }
    }

    // ── Install Modal ────────────────────────────────────────────────
    Kirigami.OverlaySheet {
        id: installThemeSheet
        title: "Install Theme"
        showCloseButton: true

        ColumnLayout {
            width: parent ? parent.width : implicitWidth
            Layout.preferredWidth: Math.min(root.width * 0.48, 520)
            spacing: 0

            // Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Item {
                    Layout.preferredWidth: githubTab.implicitWidth + 8
                    Layout.preferredHeight: 44

                    Label {
                        id: githubTab
                        anchors.centerIn: parent
                        text: "GitHub URL"
                        font.family: root.bodyFont
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        color: root.installTabIndex === 0 ? appColors.primary : appColors.textMuted
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: appColors.primary
                        visible: root.installTabIndex === 0
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.installTabIndex = 0
                    }
                }

                Item {
                    Layout.preferredWidth: fileTab.implicitWidth + 8
                    Layout.preferredHeight: 44

                    Label {
                        id: fileTab
                        anchors.centerIn: parent
                        text: "File / Folder"
                        font.family: root.bodyFont
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        color: root.installTabIndex === 1 ? appColors.primary : appColors.textMuted
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: appColors.primary
                        visible: root.installTabIndex === 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.installTabIndex = 1
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: appColors.cardBorder
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                currentIndex: root.installTabIndex

                ColumnLayout {
                    spacing: 8

                    Label {
                        text: "Repository URL (HTTPS or SSH)"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        color: appColors.textMuted
                    }

                    TextField {
                        id: repoUrlField
                        Layout.fillWidth: true
                        placeholderText: "https://github.com/user/sddm-theme-name"
                        font.family: root.bodyFont
                        font.pixelSize: 13
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Supports HTTPS clone URLs and SSH git@github.com: URLs."
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                    }
                }

                ColumnLayout {
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        radius: appColors.radiusCard
                        color: dropZoneMouse.containsMouse ? appColors.primaryContainer : "transparent"
                        border.width: 2
                        border.color: dropZoneMouse.containsMouse ? appColors.primary : appColors.cardBorder

                        MouseArea {
                            id: dropZoneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 48
                                height: 48
                                radius: 12
                                color: appColors.primaryContainer

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: "cloud-upload"
                                    color: appColors.primary
                                }
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Drop theme archive here"
                                font.family: root.headingFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: appColors.surfaceFg
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Supports .tar.gz, .zip, .tar.xz — or a theme folder"
                                font.family: root.bodyFont
                                font.pixelSize: 12
                                color: appColors.textMuted
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Button {
                                    text: "Choose Archive…"
                                    icon.name: "document-open"
                                    onClicked: archiveFileDialog.open()
                                }
                                Button {
                                    text: "Choose Folder…"
                                    icon.name: "folder-open"
                                    onClicked: themeFolderDialog.open()
                                }
                            }
                        }
                    }

                    TextField {
                        id: localPathField
                        Layout.fillWidth: true
                        text: root.localInstallPath
                        placeholderText: "/path/to/theme-or-archive.zip"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        onTextEdited: root.localInstallPath = text
                    }
                }
            }

            CheckBox {
                id: systemWideCheck
                Layout.topMargin: 16
                text: "Install system-wide — requires admin password"
                font.family: root.bodyFont
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "User install: ~/.local/share/sddm/themes/. System-wide: /var/lib/sddm/themes/ (NixOS) or /usr/share/sddm/themes/."
                font.family: root.bodyFont
                font.pixelSize: 11
                color: appColors.textMuted
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: installThemeSheet.close()
                }

                Button {
                    id: installConfirmBtn
                    text: themeInstaller.installing ? "Installing…" : "Install"
                    enabled: {
                        if (themeInstaller.installing)
                            return false
                        if (root.installTabIndex === 0)
                            return repoUrlField.text.trim().length > 0
                        return root.localInstallPath.trim().length > 0
                    }
                    onClicked: {
                        if (root.installTabIndex === 0)
                            themeInstaller.installFromUrl(repoUrlField.text.trim(), systemWideCheck.checked)
                        else
                            themeInstaller.installFromLocalPath(root.localInstallPath.trim(), systemWideCheck.checked)
                    }

                    contentItem: Label {
                        text: installConfirmBtn.text
                        font.family: root.bodyFont
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: appColors.radiusCard
                        color: !installConfirmBtn.enabled ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.4)
                             : (installConfirmBtn.hovered ? appColors.accentHover : appColors.primary)
                    }
                }
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: themeInstaller.installing
                visible: running
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: themeInstaller.progressMessage.length > 0
                text: themeInstaller.progressMessage
                font.family: root.bodyFont
                font.pixelSize: 12
                color: appColors.surfaceVariantFg
            }
        }
    }
}
