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
    // Design background wins over whatever the desktop theme paints behind pages.
    color: appColors.background

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
    property string localInstallPath: ""
    readonly property string closePreviewHelp: "To close the full-screen preview: press Alt+Tab, select SDDM Variant Manager, then click Close preview."
    readonly property string appVersion: "2.2.0"
    readonly property bool canRemoveCurrentTheme: selectedThemeIndex >= 0
        && currentTheme.path
        && themeInstaller.canRemoveTheme(currentTheme.path)

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
    readonly property bool currentThemeIsSddmCurrent: {
        variantsRevision
        if (selectedThemeIndex < 0 || !currentTheme.id)
            return false
        const activeId = themeScanner.currentSddmThemeId || ""
        if (activeId.length === 0)
            return false
        const path = currentTheme.path || ""
        return currentTheme.id === activeId
            || path.endsWith("/" + activeId)
    }
    readonly property bool selectionIsActive: {
        if (!currentThemeIsSddmCurrent)
            return false
        if (currentThemeHasVariants)
            return currentVariant.isActive === true
        return true
    }
    readonly property string activeStatusLabel: {
        if (selectedThemeIndex < 0)
            return "No theme selected"
        const themeName = currentTheme.name || currentTheme.id || "Theme"
        if (selectionIsActive) {
            if (currentThemeHasVariants && currentVariant.displayName)
                return "SDDM Active: " + themeName + " · Variant: " + currentVariant.displayName
            return "SDDM Active: " + themeName
        }
        if (currentThemeHasVariants && currentVariant.displayName)
            return "Selected: " + themeName + " · " + currentVariant.displayName
        return "Selected: " + themeName
    }
    readonly property string previewKindLabel: {
        if (previewIsVideo)
            return "Video background"
        if (previewIsGif)
            return "Animated GIF"
        if (previewIsImage)
            return "Static image"
        return ""
    }
    readonly property string previewTechLabel: {
        if (previewMediaPath.length === 0)
            return ""
        const parts = previewMediaPath.split("/")
        const name = parts.length > 0 ? parts[parts.length - 1] : ""
        const dot = name.lastIndexOf(".")
        const ext = dot >= 0 ? name.slice(dot + 1).toUpperCase() : ""
        if (previewIsVideo)
            return (ext.length > 0 ? ext : "VIDEO") + " · loop"
        if (previewIsGif)
            return "GIF"
        return ext.length > 0 ? ("Static image · " + ext) : "Static image"
    }
    readonly property string qtStackShort: {
        if (!currentTheme.qtStack)
            return "—"
        return currentTheme.qtStack + (currentTheme.requiresQt5 ? " (legacy)" : "")
    }
    readonly property string multimediaStatusText: {
        if (selectedThemeIndex < 0)
            return ""
        if (currentTheme.requiresMultimedia === true)
            return "Needs multimedia"
        return "No multimedia required"
    }
    readonly property string greeterFooterText: {
        let parts = []
        if (greeterCapabilities.greeterQtLabel)
            parts.push("Greeter: " + greeterCapabilities.greeterQtLabel)
        if (greeterCapabilities.analyzed)
            parts.push(greeterCapabilities.hasQtMultimedia
                       ? "QtMultimedia available"
                       : "QtMultimedia missing")
        return parts.join(" · ")
    }
    readonly property string currentConfigHint: {
        if (currentThemeHasVariants && currentVariant.configFile)
            return currentVariant.configFile
        return ""
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
        if (selectedThemeIndex < 0 || !currentTheme.path) {
            notify("Select a theme before opening Full Preview.")
            return
        }

        const qtWarn = greeterCapabilities.qtCompatibilityWarning(currentTheme)
        if (qtWarn && qtWarn.length > 0)
            notify(qtWarn)

        const advisory = greeterCapabilities.advisoryForTheme(currentTheme)
        if (advisory && advisory.length > 0
            && currentTheme.requiresMultimedia === true
            && !greeterCapabilities.hasQtMultimedia
            && greeterCapabilities.previewCanProvideMultimedia) {
            notify("Full Preview will inject QtMultimedia from the app. Real login may still need it on the system greeter.")
        } else if (advisory && advisory.length > 0
                   && currentTheme.requiresMultimedia === true
                   && !greeterCapabilities.previewCanProvideMultimedia) {
            notify(advisory)
        }

        if (currentThemeHasVariants)
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, currentVariant.configFile || "")
        else
            greeterPreview.preview(currentTheme.path, currentTheme.metadataPath, "")
    }

    function openInstallThemeSheet() {
        if (!installThemeSheet.visible)
            installThemeSheet.open()
    }

    function openLocalInstallWithPath(path) {
        localInstallPath = path
        openInstallThemeSheet()
    }

    function requestRemoveCurrentTheme() {
        if (!canRemoveCurrentTheme)
            return
        removeConfirmDialog.open()
    }

    function confirmRemoveCurrentTheme() {
        if (!canRemoveCurrentTheme || !currentTheme.path)
            return
        themeInstaller.removeTheme(currentTheme.path)
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
            if (!success)
                return

            installThemeSheet.close()
            localInstallPath = ""
            root.themeSearchText = ""
            if (themeSearchInput)
                themeSearchInput.text = ""

            themeScanner.rescan()

            const ids = installedThemeIds || []
            Qt.callLater(function() {
                if (ids.length === 0)
                    return
                let index = themeScanner.themeIndexForId(ids[0])
                if (index < 0) {
                    themeScanner.rescan()
                    index = themeScanner.themeIndexForId(ids[0])
                }
                if (index < 0) {
                    root.notify("Installed \"" + ids[0] + "\" but it is not in the library yet. Click Refresh. "
                                + "Expected under ~/.local/share/sddm/themes/ or the system theme dir.")
                    return
                }
                root.selectedThemeIndex = index
                const theme = themeScanner.themeAt(index)
                const notes = greeterCapabilities.installNotesForTheme(theme)
                if (notes && notes.length > 0)
                    root.notify(notes)
            })
        }
        function onRemoveFinished(success, message, themeId) {
            root.notify(message)
            if (!success)
                return
            root.selectedThemeIndex = -1
            root.selectedVariantIndex = -1
            themeScanner.rescan()
            Qt.callLater(function() {
                root.ensureThemeSelection()
            })
        }
    }

    Dialog {
        id: removeConfirmDialog
        title: "Remove theme?"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.NoButton
        width: Math.min(root.width * 0.42, 440)
        padding: 20

        background: Rectangle {
            radius: appColors.radiusModal
            color: appColors.surface
            border.width: 1
            border.color: appColors.cardBorder
        }

        contentItem: ColumnLayout {
            spacing: 14

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Delete \"" + (currentTheme.name || currentTheme.id || "this theme")
                      + "\" from disk?\n\n"
                      + (currentTheme.path || "")
                      + "\n\nThis cannot be undone."
                font.family: root.bodyFont
                font.pixelSize: 13
                color: appColors.surfaceFg
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }

                Button {
                    id: removeCancelBtn
                    padding: 10
                    leftPadding: 16
                    rightPadding: 16
                    onClicked: removeConfirmDialog.close()
                    contentItem: Label {
                        text: "Cancel"
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: appColors.surfaceVariantFg
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: AppSecondaryChrome { control: removeCancelBtn }
                }

                Button {
                    id: removeConfirmBtn
                    padding: 10
                    leftPadding: 16
                    rightPadding: 16
                    onClicked: {
                        removeConfirmDialog.close()
                        root.confirmRemoveCurrentTheme()
                    }
                    contentItem: Label {
                        text: "Remove theme"
                        font.family: root.bodyFont
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: appColors.radiusCard
                        color: removeConfirmBtn.hovered ? "#9B1C1C" : appColors.danger
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
    onPreviewMediaPathChanged: Qt.callLater(updatePreviewMedia)

    component VariantThumbnail: Image {
        property url mediaSource
        fillMode: Image.PreserveAspectCrop
        source: mediaSource
        asynchronous: true
        smooth: true
        mipmap: true
    }

    component AppFieldBackground: Rectangle {
        property Item control
        radius: appColors.radiusCard
        color: appColors.fieldBg
        border.width: 1
        border.color: control && control.activeFocus ? appColors.fieldBorderFocus : appColors.fieldBorder
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    component AppSecondaryChrome: Rectangle {
        property Item control
        property bool danger: false
        radius: appColors.radiusCard
        // Design: white surface + subtle border; hover mauve wash (not Breeze/Fusion).
        color: {
            if (!control)
                return appColors.fieldBg
            if (control.down)
                return Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.12)
            if (control.hovered)
                return Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.08)
            return appColors.fieldBg
        }
        border.width: 1
        border.color: control && control.hovered ? appColors.primary : appColors.cardBorder
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    component AppCheckIndicator: Rectangle {
        property Item control
        implicitWidth: 18
        implicitHeight: 18
        radius: 4
        color: control && control.checked ? appColors.primary : appColors.fieldBg
        border.width: control && control.checked ? 0 : 1
        border.color: appColors.checkboxBorder

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 2
            color: appColors.primaryFg
            visible: control && control.checked
        }
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
                        color: root.selectionIsActive ? appColors.badgeSuccessBg : appColors.secondaryContainer
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
                                color: root.selectionIsActive ? appColors.badgeSuccessText : appColors.surfaceVariantFg
                            }

                            Label {
                                text: root.activeStatusLabel
                                font.family: root.bodyFont
                                font.weight: Font.DemiBold
                                font.pixelSize: 12
                                color: root.selectionIsActive ? appColors.badgeSuccessText : appColors.surfaceVariantFg
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 8

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
                            background: AppSecondaryChrome { control: refreshBtn }
                        }
                    }
                }
            }

            // ── Library | hero + filmstrip ───────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

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
                            Layout.bottomMargin: 8
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: appColors.radiusCard
                                color: appColors.fieldBg
                                border.width: 1
                                border.color: themeSearchInput.activeFocus ? appColors.fieldBorderFocus : appColors.fieldBorder

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
                                        placeholderTextColor: appColors.fieldPlaceholder
                                        selectedTextColor: appColors.surfaceFg
                                        selectionColor: appColors.fieldSelection
                                        background: Item {}
                                        onTextChanged: root.themeSearchText = text
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "INSTALLED (" + themeScanner.themeCount + ")"
                                    font.family: root.headingFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 11
                                    font.letterSpacing: 0.8
                                    color: appColors.textMuted
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: "Rescan"
                                    font.family: root.bodyFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 12
                                    color: appColors.primary
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: themeScanner.rescan()
                                    }
                                }
                            }
                        }

                        ListView {
                            id: themeListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            topMargin: 4
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
                                explanation: "Install from a local folder or an archive (zip/tar)."
                                icon.name: "preferences-desktop-theme"
                            }
                        }

                        Button {
                            id: installPrimaryBtn
                            Layout.fillWidth: true
                            Layout.margins: 16
                            Layout.topMargin: 8
                            text: "Install Theme"
                            onClicked: root.openInstallThemeSheet()
                            leftPadding: 16
                            rightPadding: 16
                            topPadding: 10
                            bottomPadding: 10

                            contentItem: RowLayout {
                                spacing: 8
                                Item { Layout.fillWidth: true }
                                Kirigami.Icon {
                                    source: "list-add"
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    color: appColors.primaryFg
                                }
                                Label {
                                    text: "Install Theme"
                                    font.family: root.bodyFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 13
                                    color: appColors.primaryFg
                                }
                                Item { Layout.fillWidth: true }
                            }
                            background: Rectangle {
                                radius: appColors.radiusCard
                                color: installPrimaryBtn.down ? appColors.accentHover
                                      : (installPrimaryBtn.hovered ? appColors.accentHover : appColors.primary)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    z: -1
                                    anchors.fill: parent
                                    anchors.topMargin: 3
                                    radius: parent.radius
                                    color: installPrimaryBtn.hovered ? appColors.shadowCardHover : "transparent"
                                    visible: installPrimaryBtn.hovered || installPrimaryBtn.down
                                }
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: stageColumn.implicitHeight + 32
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: stageColumn
                        width: parent.width
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 24
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        spacing: 16

                        Kirigami.PlaceholderMessage {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 280
                            visible: themeScanner.themeCount === 0
                            text: "Welcome"
                            explanation: "Install an SDDM theme to get started from a local folder or archive."
                            icon.name: "preferences-desktop-theme"
                            helpfulAction: Kirigami.Action {
                                text: "Install Theme"
                                icon.name: "list-add"
                                onTriggered: root.openInstallThemeSheet()
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

                        Item {
                            id: heroStage
                            visible: selectedThemeIndex >= 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(220, stageColumn.width * 9 / 16)

                            Rectangle {
                                anchors.fill: parent
                                radius: appColors.radiusCard
                                color: appColors.surface2
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
                                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.40) }
                                    }
                                    visible: previewMediaPath.length > 0
                                }

                                ColumnLayout {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 8

                                    Rectangle {
                                        visible: root.selectionIsActive
                                        radius: height / 2
                                        color: appColors.badgeSuccessBg
                                        border.width: 1
                                        border.color: appColors.badgeSuccessBorder
                                        implicitHeight: curActiveLbl.implicitHeight + 10
                                        implicitWidth: curActiveRow.implicitWidth + 18

                                        RowLayout {
                                            id: curActiveRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Rectangle {
                                                Layout.preferredWidth: 6
                                                Layout.preferredHeight: 6
                                                radius: 3
                                                color: appColors.badgeSuccessText
                                            }
                                            Label {
                                                id: curActiveLbl
                                                text: "Active"
                                                font.family: root.bodyFont
                                                font.weight: Font.DemiBold
                                                font.pixelSize: 11
                                                color: appColors.badgeSuccessText
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.previewIsVideo
                                        radius: height / 2
                                        color: Qt.rgba(0, 0, 0, 0.55)
                                        implicitHeight: videoBadgeLbl.implicitHeight + 10
                                        implicitWidth: videoBadgeLbl.implicitWidth + 18

                                        Label {
                                            id: videoBadgeLbl
                                            anchors.centerIn: parent
                                            text: "Video background"
                                            font.family: root.bodyFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 11
                                            color: "#FFFFFF"
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: root.previewTechLabel.length > 0
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 12
                                    radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    implicitHeight: techLbl.implicitHeight + 10
                                    implicitWidth: techLbl.implicitWidth + 18

                                    Label {
                                        id: techLbl
                                        anchors.centerIn: parent
                                        text: root.previewTechLabel
                                        font.family: root.bodyFont
                                        font.pixelSize: 11
                                        color: "#FFFFFF"
                                    }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    visible: previewMediaPath.length === 0
                                    text: "No preview"
                                    font.family: root.bodyFont
                                    color: appColors.textMuted
                                }
                            }
                        }

                        Rectangle {
                            visible: selectedThemeIndex >= 0
                                     && currentTheme.requiresMultimedia === true
                                     && !greeterCapabilities.hasQtMultimedia
                            Layout.fillWidth: true
                            radius: appColors.radiusCard
                            color: appColors.warningContainer
                            border.width: 1
                            border.color: appColors.warningFg
                            implicitHeight: mmWarnCol.implicitHeight + 24

                            RowLayout {
                                id: mmWarnCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 10

                                Kirigami.Icon {
                                    source: "dialog-warning"
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    color: appColors.warningFg
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "This theme needs QtMultimedia in the system SDDM greeter. Add it to the OS (NixOS: services.displayManager.sddm.extraPackages), then rebuild — the app will not alter theme files."
                                    font.family: root.bodyFont
                                    font.pixelSize: 12
                                    color: appColors.warningFg
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
                                     && greeterCapabilities.themeIncompatibleWithGreeter(currentTheme)
                            text: greeterCapabilities.qtCompatibilityWarning(currentTheme)
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

                        RowLayout {
                            visible: selectedThemeIndex >= 0
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Label {
                                        text: currentTheme.name || currentTheme.id || "Theme"
                                        font.family: root.headingFont
                                        font.weight: Font.Bold
                                        font.pixelSize: 22
                                        color: appColors.surfaceFg
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: currentThemeHasVariants && currentVariant.displayName
                                        radius: height / 2
                                        color: appColors.primaryContainer
                                        implicitHeight: variantChipLbl.implicitHeight + 8
                                        implicitWidth: variantChipLbl.implicitWidth + 16
                                        Label {
                                            id: variantChipLbl
                                            anchors.centerIn: parent
                                            text: currentVariant.displayName || ""
                                            font.family: root.bodyFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 11
                                            color: appColors.primaryContainerFg
                                        }
                                    }

                                    Rectangle {
                                        radius: height / 2
                                        color: themeScopeLabel(currentTheme) === "System"
                                               ? appColors.badgeSystemBg : appColors.badgeUserBg
                                        implicitHeight: scopeChipLbl.implicitHeight + 8
                                        implicitWidth: scopeChipLbl.implicitWidth + 16
                                        Label {
                                            id: scopeChipLbl
                                            anchors.centerIn: parent
                                            text: themeScopeLabel(currentTheme).toUpperCase()
                                            font.family: root.headingFont
                                            font.weight: Font.Bold
                                            font.pixelSize: 10
                                            color: themeScopeLabel(currentTheme) === "System"
                                                   ? appColors.badgeSystemText : appColors.badgeUserText
                                        }
                                    }

                                    Rectangle {
                                        visible: currentThemeReadOnly
                                        radius: height / 2
                                        color: appColors.badgeReadonlyBg
                                        implicitHeight: roChipLbl.implicitHeight + 8
                                        implicitWidth: roChipLbl.implicitWidth + 16
                                        Label {
                                            id: roChipLbl
                                            anchors.centerIn: parent
                                            text: "RO"
                                            font.family: root.headingFont
                                            font.weight: Font.Bold
                                            font.pixelSize: 10
                                            color: appColors.badgeReadonlyText
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16

                                    RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: "folder"
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: currentTheme.path || "—"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.surfaceVariantFg
                                            elide: Text.ElideMiddle
                                            Layout.maximumWidth: 360
                                        }
                                    }

                                    RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: "application-x-executable"
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 12
                                            color: appColors.textMuted
                                        }
                                        Label {
                                            text: root.qtStackShort
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: currentTheme.requiresQt5 === true ? appColors.warning : appColors.surfaceVariantFg
                                        }
                                    }

                                    RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: currentTheme.requiresMultimedia === true ? "media-playback-start" : "dialog-ok"
                                            Layout.preferredWidth: 12
                                            Layout.preferredHeight: 12
                                            color: currentTheme.requiresMultimedia === true
                                                   && !greeterCapabilities.hasQtMultimedia
                                                   ? appColors.warning : appColors.textMuted
                                        }
                                        Label {
                                            text: root.multimediaStatusText
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: currentTheme.requiresMultimedia === true
                                                   && !greeterCapabilities.hasQtMultimedia
                                                   ? appColors.warning : appColors.surfaceVariantFg
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                spacing: 8

                                CheckBox {
                                    id: activateCheck
                                    checked: root.activateInSddm
                                    onCheckedChanged: root.activateInSddm = checked
                                    Layout.alignment: Qt.AlignVCenter
                                    indicator: AppCheckIndicator {
                                        control: activateCheck
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    contentItem: Item { implicitWidth: 0; implicitHeight: 18 }
                                }

                                Label {
                                    text: "Also set as current SDDM theme"
                                    font.family: root.bodyFont
                                    font.pixelSize: 12
                                    color: appColors.surfaceFg
                                    wrapMode: Text.WordWrap
                                    Layout.maximumWidth: 180
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: activateCheck.checked = !activateCheck.checked
                                    }
                                }
                            }
                        }

                        RowLayout {
                            visible: selectedThemeIndex >= 0
                            Layout.fillWidth: true
                            spacing: 8

                            Button {
                                id: applyBtn
                                enabled: selectedThemeIndex >= 0 && (
                                    currentThemeHasVariants
                                        ? (!currentThemeReadOnly && currentVariant.configFile !== undefined)
                                        : currentTheme.id !== undefined)
                                onClicked: root.applyCurrentSelection()
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 10
                                bottomPadding: 10

                                contentItem: RowLayout {
                                    spacing: 8
                                    Kirigami.Icon {
                                        source: "dialog-ok-apply"
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        color: appColors.primaryFg
                                    }
                                    Label {
                                        text: "Apply as SDDM Theme"
                                        font.family: root.bodyFont
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 13
                                        color: appColors.primaryFg
                                    }
                                }
                                background: Rectangle {
                                    radius: appColors.radiusCard
                                    color: !applyBtn.enabled ? appColors.disabledPrimary
                                         : (applyBtn.down || applyBtn.hovered ? appColors.accentHover : appColors.primary)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Rectangle {
                                        z: -1
                                        anchors.fill: parent
                                        anchors.topMargin: 3
                                        radius: parent.radius
                                        color: appColors.shadowCardHover
                                        visible: applyBtn.enabled && (applyBtn.hovered || applyBtn.down)
                                    }
                                }
                            }

                            Button {
                                id: previewBtn
                                enabled: (selectedThemeIndex >= 0 && (currentThemeHasVariants ? currentVariant.configFile !== undefined : true)) || greeterPreview.running
                                onClicked: {
                                    if (greeterPreview.running)
                                        greeterPreview.stopPreview()
                                    else
                                        startFullPreview()
                                }
                                leftPadding: 14
                                rightPadding: 14
                                topPadding: 10
                                bottomPadding: 10

                                contentItem: RowLayout {
                                    spacing: 8
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
                                }
                                background: AppSecondaryChrome { control: previewBtn }
                            }

                            Button {
                                id: openFolderBtn
                                enabled: selectedThemeIndex >= 0 && currentTheme.path
                                onClicked: root.openThemeInFileManager()
                                leftPadding: 14
                                rightPadding: 14
                                topPadding: 10
                                bottomPadding: 10

                                contentItem: RowLayout {
                                    spacing: 8
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
                                }
                                background: AppSecondaryChrome { control: openFolderBtn }
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                id: removeThemeBtn
                                visible: selectedThemeIndex >= 0
                                enabled: root.canRemoveCurrentTheme && !themeInstaller.installing
                                onClicked: root.requestRemoveCurrentTheme()
                                ToolTip.visible: hovered && !enabled && selectedThemeIndex >= 0
                                ToolTip.text: currentThemeReadOnly
                                    ? "Read-only system/Nix themes cannot be deleted here"
                                    : "This theme cannot be removed from the app"
                                leftPadding: 14
                                rightPadding: 14
                                topPadding: 10
                                bottomPadding: 10

                                contentItem: RowLayout {
                                    spacing: 8
                                    Kirigami.Icon {
                                        source: "edit-delete"
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        color: removeThemeBtn.enabled ? appColors.danger : appColors.textMuted
                                    }
                                    Label {
                                        text: "Remove"
                                        font.family: root.bodyFont
                                        font.weight: Font.Medium
                                        font.pixelSize: 13
                                        color: removeThemeBtn.enabled ? appColors.danger : appColors.textMuted
                                    }
                                }
                                background: Rectangle {
                                    radius: appColors.radiusCard
                                    color: !removeThemeBtn.enabled
                                           ? "transparent"
                                           : (removeThemeBtn.hovered
                                              ? appColors.dangerContainer
                                              : appColors.surface)
                                    border.width: 1
                                    border.color: removeThemeBtn.enabled ? appColors.danger : appColors.cardBorder
                                }
                            }
                        }

                        ColumnLayout {
                            visible: selectedThemeIndex >= 0 && currentThemeHasVariants && currentVariants.length > 0
                            Layout.fillWidth: true
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "VARIANTS · " + currentVariants.length
                                    font.family: root.headingFont
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 11
                                    font.letterSpacing: 0.8
                                    color: appColors.textMuted
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    visible: root.currentConfigHint.length > 0
                                    text: root.currentConfigHint
                                    font.family: root.bodyFont
                                    font.pixelSize: 11
                                    color: appColors.accentDark
                                    elide: Text.ElideMiddle
                                    Layout.maximumWidth: 320
                                }
                            }

                            ListView {
                                id: variantStrip
                                Layout.fillWidth: true
                                Layout.preferredHeight: 138
                                orientation: ListView.Horizontal
                                spacing: 10
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: currentVariants

                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: 230
                                    height: 129

                                    property bool variantSelected: root.selectedVariantIndex === index
                                    property bool variantActive: modelData.isActive === true

                                    Rectangle {
                                        id: stripChrome
                                        anchors.fill: parent
                                        radius: appColors.radiusCard
                                        color: appColors.surface
                                        border.width: variantSelected ? 2 : 1
                                        border.color: variantSelected || stripHover.hovered
                                                       ? appColors.primary : appColors.cardBorder
                                        clip: true

                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        Rectangle {
                                            z: -1
                                            anchors.fill: parent
                                            anchors.topMargin: stripHover.hovered || variantSelected
                                                               ? appColors.shadowYHover : appColors.shadowY
                                            radius: parent.radius
                                            color: stripHover.hovered || variantSelected
                                                   ? appColors.shadowCardHover : appColors.shadowCard
                                        }

                                        VariantThumbnail {
                                            anchors.fill: parent
                                            mediaSource: modelData.thumbnailPath ? "file://" + modelData.thumbnailPath : ""
                                        }

                                        Rectangle {
                                            visible: variantActive
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: 8
                                            radius: height / 2
                                            color: appColors.primary
                                            implicitHeight: stripActiveLbl.implicitHeight + 8
                                            implicitWidth: stripActiveRow.implicitWidth + 16

                                            RowLayout {
                                                id: stripActiveRow
                                                anchors.centerIn: parent
                                                spacing: 5
                                                Rectangle {
                                                    Layout.preferredWidth: 5
                                                    Layout.preferredHeight: 5
                                                    radius: 3
                                                    color: appColors.primaryFg
                                                }
                                                Label {
                                                    id: stripActiveLbl
                                                    text: "Active"
                                                    font.family: root.bodyFont
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 10
                                                    color: appColors.primaryFg
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 36
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                                            }
                                        }

                                        Label {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 8
                                            text: modelData.displayName || modelData.id || ""
                                            font.family: root.headingFont
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 12
                                            color: "#FFFFFF"
                                            elide: Text.ElideRight
                                        }

                                        HoverHandler { id: stripHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectedVariantIndex = index
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: selectedThemeIndex >= 0 && !currentThemeHasVariants
                            Layout.fillWidth: true
                            radius: appColors.radiusCard
                            color: appColors.surface
                            border.width: 1
                            border.color: appColors.cardBorder
                            implicitHeight: simpleNoteLbl.implicitHeight + 24

                            Label {
                                id: simpleNoteLbl
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 14
                                wrapMode: Text.WordWrap
                                text: "Simple theme — no Themes/*.conf variant pack. Apply the theme as a whole."
                                font.family: root.bodyFont
                                font.pixelSize: 12
                                color: appColors.textMuted
                            }
                        }

                        Item { Layout.preferredHeight: 8 }
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
                        text: themeScanner.themeCount + " theme" + (themeScanner.themeCount === 1 ? "" : "s")
                              + " installed · " + root.totalVariantCount + " variant"
                              + (root.totalVariantCount === 1 ? "" : "s") + " total"
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    Label {
                        visible: statusMessage.length > 0
                        text: statusMessage
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width * 0.28
                    }

                    ToolButton {
                        id: copyCmdBtn
                        implicitWidth: 24
                        implicitHeight: 24
                        onClicked: root.copyPreviewCommand()
                        ToolTip.visible: hovered
                        ToolTip.text: "Copy preview command"
                        contentItem: Kirigami.Icon {
                            source: "edit-copy"
                            color: appColors.primary
                        }
                        background: Rectangle {
                            radius: 6
                            color: copyCmdBtn.hovered
                                   ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.12)
                                   : "transparent"
                        }
                    }

                    Label {
                        text: root.greeterFooterText.length > 0
                              ? root.greeterFooterText
                              : ("SDDM Variant Manager v" + root.appVersion)
                        font.family: root.bodyFont
                        font.pixelSize: 11
                        color: appColors.textMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width * 0.42
                    }
                }
            }
        }
    }

    // ── Install Modal (Popup avoids Kirigami OverlaySheet implicitHeight loops) ──
    Popup {
        id: installThemeSheet
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: parent
        width: Math.min(root.width * 0.5, 540)
        padding: 0
        // Height follows content; cap so small windows still scroll via Flickable if needed.
        implicitHeight: Math.min(installSheetBody.implicitHeight, root.height * 0.88)

        background: Rectangle {
            radius: appColors.radiusModal
            color: appColors.surface
            border.width: 1
            border.color: appColors.cardBorder
        }

        Overlay.modal: Rectangle {
            color: appColors.overlayScrim
        }

        ColumnLayout {
            id: installSheetBody
            width: installThemeSheet.width
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 12
                Layout.topMargin: 16
                Layout.bottomMargin: 12

                Label {
                    Layout.fillWidth: true
                    text: "Install Theme"
                    font.family: root.headingFont
                    font.weight: Font.DemiBold
                    font.pixelSize: 16
                    color: appColors.surfaceFg
                }

                ToolButton {
                    id: installSheetCloseBtn
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: installThemeSheet.close()
                    contentItem: Kirigami.Icon {
                        source: "window-close"
                        color: appColors.textMuted
                    }
                    background: Rectangle {
                        radius: 8
                        color: installSheetCloseBtn.hovered
                               ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.1)
                               : "transparent"
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
                Layout.margins: 20
                spacing: 0

                ColumnLayout {
                    id: fileTabBody
                    Layout.fillWidth: true
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
                                text: "Drop theme archive or folder here"
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
                                    id: chooseArchiveBtn
                                    padding: 10
                                    onClicked: archiveFileDialog.open()
                                    contentItem: RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: "document-open"
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            color: appColors.primary
                                        }
                                        Label {
                                            text: "Choose Archive…"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.surfaceFg
                                        }
                                    }
                                    background: AppSecondaryChrome { control: chooseArchiveBtn }
                                }
                                Button {
                                    id: chooseFolderBtn
                                    padding: 10
                                    onClicked: themeFolderDialog.open()
                                    contentItem: RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: "folder-open"
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            color: appColors.primary
                                        }
                                        Label {
                                            text: "Choose Folder…"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            color: appColors.surfaceFg
                                        }
                                    }
                                    background: AppSecondaryChrome { control: chooseFolderBtn }
                                }
                            }
                        }
                    }

                    TextField {
                        id: localPathField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        text: root.localInstallPath
                        placeholderText: "/path/to/theme-or-archive.zip"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        color: appColors.surfaceFg
                        placeholderTextColor: appColors.fieldPlaceholder
                        selectedTextColor: appColors.surfaceFg
                        selectionColor: appColors.fieldSelection
                        leftPadding: 12
                        rightPadding: 12
                        background: AppFieldBackground { control: localPathField }
                        onTextEdited: root.localInstallPath = text
                    }
                }

                CheckBox {
                    id: systemWideCheck
                    Layout.topMargin: 16
                    text: "Install system-wide — requires admin password"
                    font.family: root.bodyFont
                    spacing: 10
                    indicator: AppCheckIndicator {
                        control: systemWideCheck
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    contentItem: Label {
                        text: systemWideCheck.text
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: appColors.surfaceFg
                        leftPadding: systemWideCheck.indicator.width + systemWideCheck.spacing
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    wrapMode: Text.Wrap
                    text: "User install: ~/.local/share/sddm/themes/. System-wide: /var/lib/sddm/themes/ (NixOS) or /usr/share/sddm/themes/."
                    font.family: root.bodyFont
                    font.pixelSize: 11
                    color: appColors.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Button {
                        id: installCancelBtn
                        padding: 12
                        leftPadding: 18
                        rightPadding: 18
                        onClicked: installThemeSheet.close()
                        contentItem: Label {
                            text: "Cancel"
                            font.family: root.bodyFont
                            font.pixelSize: 13
                            color: appColors.surfaceVariantFg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: AppSecondaryChrome { control: installCancelBtn }
                    }

                    Button {
                        id: installConfirmBtn
                        padding: 12
                        leftPadding: 20
                        rightPadding: 20
                        text: themeInstaller.installing ? "Installing…" : "Install"
                        enabled: {
                            if (themeInstaller.installing)
                                return false
                            return root.localInstallPath.trim().length > 0
                        }
                        onClicked: {
                            themeInstaller.installFromLocalPath(root.localInstallPath.trim(), systemWideCheck.checked)
                        }

                        contentItem: Label {
                            text: installConfirmBtn.text
                            font.family: root.bodyFont
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                            color: appColors.primaryFg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: appColors.radiusCard
                            color: !installConfirmBtn.enabled ? appColors.disabledPrimary
                                 : (installConfirmBtn.hovered ? appColors.accentHover : appColors.primary)
                        }
                    }
                }

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    running: themeInstaller.installing
                    visible: running
                }

                Label {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
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
}
