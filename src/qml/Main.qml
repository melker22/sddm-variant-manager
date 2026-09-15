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
    Kirigami.Theme.alternateBackgroundColor: appColors.rowSelected
    Kirigami.Theme.highlightColor: appColors.primary
    Kirigami.Theme.highlightedTextColor: appColors.primaryFg
    Kirigami.Theme.activeTextColor: appColors.primaryContainerText
    Kirigami.Theme.activeBackgroundColor: appColors.primaryContainer
    Kirigami.Theme.hoverColor: appColors.rowHover
    Kirigami.Theme.focusColor: appColors.primary
    Kirigami.Theme.linkColor: appColors.primary
    Kirigami.Theme.textColor: appColors.textPrimary
    Kirigami.Theme.disabledTextColor: appColors.textTertiary

    // ── Selection / search / install-sheet state (unchanged from the app's model) ──
    property int selectedThemeIndex: -1
    property int selectedVariantIndex: -1
    property int variantsRevision: 0
    property bool activateInSddm: true
    property string statusMessage: ""
    property string themeSearchText: ""
    property string localInstallPath: ""
    property string githubInstallUrl: ""
    property int installTabIndex: 0
    property bool diagnosticsOpen: false
    readonly property string closePreviewHelp: "The real greeter is covering this window. Use the floating bar to close the preview, or switch back with Alt+Tab / Super+Q."
    readonly property string appVersion: "2.4.0"
    readonly property bool canRemoveCurrentTheme: selectedThemeIndex >= 0
        && currentTheme.path
        && themeInstaller.canRemoveTheme(currentTheme.path)
    readonly property bool canApplyCurrentSelection: selectedThemeIndex >= 0 && (
        currentThemeHasVariants
            ? (!currentThemeReadOnly && currentVariant.configFile !== undefined)
            : currentTheme.id !== undefined)

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
    readonly property string qtStackShort: {
        if (!currentTheme.qtStack)
            return "—"
        return currentTheme.qtStack + (currentTheme.requiresQt5 ? " (legacy)" : "")
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
            return (ext.length > 0 ? ext : "Video") + " · loop"
        if (previewIsGif)
            return "Animated GIF"
        return ext.length > 0 ? ("Static image · " + ext) : "Static image"
    }
    readonly property string currentConfigHint: {
        if (currentThemeHasVariants && currentVariant.configFile)
            return currentVariant.configFile
        return ""
    }

    // Theme that SDDM will actually use at the next real login — independent
    // of whatever the user is currently browsing in the library.
    function themeIsSddmCurrent(theme) {
        const activeId = themeScanner.currentSddmThemeId || ""
        if (activeId.length === 0 || !theme)
            return false
        const path = theme.path || ""
        return theme.id === activeId || path.endsWith("/" + activeId)
    }
    readonly property var liveTheme: {
        variantsRevision
        for (let i = 0; i < themeScanner.themeCount; ++i) {
            const t = themeScanner.themeAt(i)
            if (themeIsSddmCurrent(t))
                return t
        }
        return null
    }
    readonly property string liveAtLoginLabel: {
        if (!liveTheme)
            return ""
        let label = liveTheme.name || liveTheme.id || "Theme"
        if (liveTheme.hasVariants) {
            const idx = themeScanner.themeIndexForId(liveTheme.id)
            const variants = idx >= 0 ? themeScanner.variantsForTheme(idx) : []
            for (const v of variants) {
                if (v.isActive) {
                    label += " · " + v.displayName
                    break
                }
            }
        }
        return label
    }

    readonly property int stageBottomReserve: {
        if (selectedThemeIndex < 0)
            return appColors.marginOuter
        if (currentThemeHasVariants && currentVariants.length > 0)
            return 214
        return 92
    }

    // Compatibility warnings for the currently selected theme, most severe first.
    readonly property var compatWarnings: {
        if (selectedThemeIndex < 0)
            return []
        let list = []
        const qtWarn = greeterCapabilities.qtCompatibilityWarning(currentTheme)
        if (qtWarn && qtWarn.length > 0) {
            list.push({
                severity: "danger",
                title: "Incompatible with your greeter",
                body: qtWarn
            })
        }
        const missing = greeterCapabilities.missingRequirementsForTheme(currentTheme) || []
        if (missing.length > 0) {
            const advisory = greeterCapabilities.advisoryForTheme(currentTheme)
            list.push({
                severity: "warning",
                title: "Missing on the greeter: " + missing.join(", "),
                body: advisory && advisory.length > 0 ? advisory : "This will fall back to a static frame at login."
            })
        }
        return list
    }

    // Directories that at least one installed theme lives under, tagged from
    // data already exposed per-theme (no direct Platform::allThemeScanDirs()
    // binding exists in QML, so empty-but-scanned directories are not listed).
    readonly property var scannedDirectoriesInfo: {
        variantsRevision
        let order = []
        let scopes = {}
        for (let i = 0; i < themeScanner.themeCount; ++i) {
            const t = themeScanner.themeAt(i)
            const path = t.path || ""
            const slash = path.lastIndexOf("/")
            if (slash <= 0)
                continue
            const dir = path.substring(0, slash)
            if (scopes[dir] === undefined) {
                let scope = "USER"
                if (t.readOnly)
                    scope = "READ-ONLY"
                else if ((t.installScope || "").toLowerCase() === "system")
                    scope = "SYSTEM"
                scopes[dir] = scope
                order.push(dir)
            }
        }
        return order.map(function(dir) { return { path: dir, scope: scopes[dir] } })
    }

    readonly property var diagnosticsModules: [
        { name: "QtMultimedia", present: greeterCapabilities.hasQtMultimedia, important: true },
        { name: "QtSvg", present: greeterCapabilities.hasQtSvg, important: true },
        { name: "Qt5Compat", present: greeterCapabilities.hasQt5Compat, important: true },
        { name: "VirtualKeyboard", present: greeterCapabilities.hasVirtualKeyboard, important: false }
    ]

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
        let base = theme.hasVariants
            ? (theme.variants.length + " variant" + (theme.variants.length === 1 ? "" : "s"))
            : "Simple theme"
        if (themeIsSddmCurrent(theme))
            base += " · active"
        return base
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

    function selectAdjacentTheme(delta) {
        const indices = filteredThemeIndices
        if (indices.length === 0)
            return
        const pos = indices.indexOf(selectedThemeIndex)
        let nextPos = pos < 0 ? 0 : pos + delta
        nextPos = Math.max(0, Math.min(indices.length - 1, nextPos))
        selectedThemeIndex = indices[nextPos]
    }

    function selectAdjacentVariant(delta) {
        if (!currentThemeHasVariants || currentVariants.length === 0)
            return
        let next = selectedVariantIndex + delta
        next = Math.max(0, Math.min(currentVariants.length - 1, next))
        selectedVariantIndex = next
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
        installTabIndex = 0
        openInstallThemeSheet()
    }

    function confirmInstallTheme() {
        if (themeInstaller.installing)
            return
        if (root.installTabIndex === 1) {
            if (!themeInstaller.gitAvailable || root.githubInstallUrl.trim().length === 0)
                return
            themeInstaller.installFromUrl(root.githubInstallUrl.trim(), systemWideCheck.checked)
            return
        }
        if (root.localInstallPath.trim().length === 0)
            return
        themeInstaller.installFromLocalPath(root.localInstallPath.trim(), systemWideCheck.checked)
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

    function copyThemePath() {
        if (!currentTheme.path)
            return
        clipboardHelper.text = currentTheme.path
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        notify("Path copied to clipboard.")
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
            githubInstallUrl = ""
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
                    root.notify("Installed \"" + ids[0] + "\" but it is not in the library yet. Click Rescan. "
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

    onSelectedThemeIndexChanged: {
        selectDefaultVariantForTheme()
        Qt.callLater(updatePreviewMedia)
    }
    onSelectedVariantIndexChanged: Qt.callLater(updatePreviewMedia)
    onPreviewMediaPathChanged: Qt.callLater(updatePreviewMedia)

    onClosing: function(close) {
        if (greeterPreview.running) {
            close.accepted = false
            root.showMinimized()
            notify("Preview still running. " + closePreviewHelp)
        } else {
            Qt.quit()
        }
    }

    // ── Reusable inline visual components ───────────────────────────
    component VariantThumbnail: Image {
        property url mediaSource
        fillMode: Image.PreserveAspectCrop
        source: mediaSource
        asynchronous: true
        smooth: true
        mipmap: true
    }

    component GlassIconButton: Rectangle {
        id: iconChrome
        property Item control
        implicitWidth: 32
        implicitHeight: 32
        radius: 9
        color: {
            if (!control)
                return "transparent"
            if (control.down)
                return Qt.rgba(1, 1, 1, appColors.isDark ? 0.14 : 0.10)
            if (control.hovered)
                return Qt.rgba(1, 1, 1, appColors.isDark ? 0.08 : 0.5)
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    component GlassSecondaryChrome: Rectangle {
        id: secondaryChrome
        property Item control
        radius: appColors.radiusButton
        color: {
            if (!control)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.12, 0.10, 0.27, 0.05)
            if (control.down)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.12, 0.10, 0.27, 0.09)
            if (control.hovered)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0.12, 0.10, 0.27, 0.07)
            return appColors.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.12, 0.10, 0.27, 0.05)
        }
        border.width: 1
        border.color: appColors.isDark ? Qt.rgba(1, 1, 1, 0.14) : "#E4E2EE"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    component PrimaryChrome: Rectangle {
        id: primaryChrome
        property Item control
        radius: appColors.radiusButton
        color: {
            if (!control || !control.enabled)
                return appColors.disabledPrimary
            if (control.down)
                return appColors.primaryPressed
            if (control.hovered)
                return appColors.primaryHover
            return appColors.primary
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Same look as GlassSecondaryChrome, but switches to a solid primary
    // fill when `emphasize` is true (e.g. the rail's Install button when the
    // library is empty) — one Item so hover/down bindings stay live,
    // avoiding the Component-id-as-background trap that silently drops
    // reactivity (background: someComponentId does not instantiate it).
    component AdaptiveChrome: Rectangle {
        id: adaptiveChrome
        property Item control
        property bool emphasize: false
        radius: appColors.radiusButton
        color: {
            if (emphasize) {
                if (!control || !control.enabled)
                    return appColors.disabledPrimary
                if (control.down)
                    return appColors.primaryPressed
                if (control.hovered)
                    return appColors.primaryHover
                return appColors.primary
            }
            if (!control)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.12, 0.10, 0.27, 0.05)
            if (control.down)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.12, 0.10, 0.27, 0.09)
            if (control.hovered)
                return appColors.isDark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0.12, 0.10, 0.27, 0.07)
            return appColors.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.12, 0.10, 0.27, 0.05)
        }
        border.width: emphasize ? 0 : 1
        border.color: appColors.isDark ? Qt.rgba(1, 1, 1, 0.14) : "#E4E2EE"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    component AppCheckIndicator: Rectangle {
        property Item control
        property bool onGlass: true
        implicitWidth: 16
        implicitHeight: 16
        radius: 4
        color: control && control.checked ? appColors.primary : "transparent"
        border.width: control && control.checked ? 0 : 1.6
        border.color: onGlass
            ? (appColors.isDark ? Qt.rgba(1, 1, 1, 0.35) : "#B9B4CC")
            : Qt.rgba(1, 1, 1, .35)

        Kirigami.Icon {
            isMask: true
            anchors.centerIn: parent
            width: 10
            height: 10
            source: "checkmark"
            color: "#FFFFFF"
            visible: control && control.checked
        }
    }

    // Dark-glass context menu row: icon + label, hover highlight, optional
    // destructive (red) styling — matches the sheet/modal look used by the
    // install/remove dialogs instead of the unstyled default Menu chrome.
    component OverflowMenuItem: MenuItem {
        id: menuItemRoot
        property string menuIcon: ""
        property bool danger: false
        implicitHeight: 38
        implicitWidth: 190
        leftPadding: 12
        rightPadding: 12

        readonly property color itemColor: !menuItemRoot.enabled ? appColors.sheetTextTertiary
            : (menuItemRoot.danger ? appColors.dangerAccent : appColors.sheetTextPrimary)

        contentItem: RowLayout {
            spacing: 10
            Kirigami.Icon {
                isMask: true
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: menuItemRoot.menuIcon
                color: menuItemRoot.itemColor
            }
            Label {
                Layout.fillWidth: true
                text: menuItemRoot.text
                font.family: root.bodyFont
                font.weight: menuItemRoot.danger ? Font.Bold : Font.Normal
                font.pixelSize: 13
                color: menuItemRoot.itemColor
            }
        }

        background: Rectangle {
            radius: 8
            color: {
                if (!menuItemRoot.enabled)
                    return "transparent"
                if (!menuItemRoot.highlighted)
                    return "transparent"
                return menuItemRoot.danger ? appColors.dangerBg : Qt.rgba(1, 1, 1, 0.08)
            }
        }
    }

    // ── Full-bleed drop target for local install ─────────────────────
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
            anchors.margins: appColors.marginOuter
            radius: appColors.radiusPanel
            visible: parent.containsDrag
            color: Qt.rgba(0.5451, 0.4039, 0.949, .10)
            border.width: 2
            z: 1000

            // QML doesn't support dashed borders natively; approximate one.
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#8B67F2"
                    ctx.lineWidth = 2
                    ctx.setLineDash([10, 8])
                    const r = appColors.radiusPanel
                    ctx.beginPath()
                    ctx.roundedRect ? ctx.roundedRect(1, 1, width - 2, height - 2, r)
                                    : ctx.rect(1, 1, width - 2, height - 2)
                    ctx.stroke()
                }
            }

            Label {
                anchors.centerIn: parent
                text: "Drop to install"
                font.family: root.headingFont
                font.weight: Font.Bold
                font.pixelSize: 24
                color: appColors.primaryTextOnGlass
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

    // ── Keyboard shortcuts ────────────────────────────────────────────
    Shortcut { sequence: "Up"; onActivated: root.selectAdjacentTheme(-1) }
    Shortcut { sequence: "Down"; onActivated: root.selectAdjacentTheme(1) }
    Shortcut { sequence: "Left"; onActivated: root.selectAdjacentVariant(-1) }
    Shortcut { sequence: "Right"; onActivated: root.selectAdjacentVariant(1) }
    Shortcut { sequence: "Return"; onActivated: root.applyCurrentSelection() }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (installThemeSheet.visible)
                installThemeSheet.close()
            else if (diagnosticsOpen)
                diagnosticsOpen = false
            else if (greeterPreview.running)
                greeterPreview.stopPreview()
        }
    }
    Shortcut { sequence: "Ctrl+F"; onActivated: themeSearchInput.forceActiveFocus() }
    Shortcut { sequence: "F5"; onActivated: themeScanner.rescan() }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        title: ""
        background: Rectangle { color: appColors.background }

        Item {
            id: stage
            anchors.fill: parent

            // ══ Layer 1 — preview stage (full-bleed) ══════════════════
            Item {
                id: stageBackdrop
                anchors.fill: parent
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: appColors.background
                }

                Canvas {
                    id: emptyStripes
                    anchors.fill: parent
                    visible: themeScanner.themeCount === 0
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = "#14151D"
                        ctx.fillRect(0, 0, width, height)
                        ctx.strokeStyle = "#171923"
                        ctx.lineWidth = 14
                        ctx.save()
                        const diag = Math.sqrt(width * width + height * height)
                        ctx.translate(width / 2, height / 2)
                        ctx.rotate(135 * Math.PI / 180)
                        for (let x = -diag; x < diag; x += 28) {
                            ctx.beginPath()
                            ctx.moveTo(x, -diag)
                            ctx.lineTo(x, diag)
                            ctx.stroke()
                        }
                        ctx.restore()
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()
                }

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
                    visible: previewMediaPath.length > 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: appColors.isDark ? Qt.rgba(0.0314, 0.0353, 0.0549, .55) : Qt.rgba(1, 1, 1, .34) }
                        GradientStop { position: appColors.isDark ? 0.32 : 0.30; color: appColors.isDark ? Qt.rgba(0.0314, 0.0353, 0.0549, .10) : Qt.rgba(1, 1, 1, 0) }
                        GradientStop { position: 1.0; color: appColors.isDark ? Qt.rgba(0.0314, 0.0353, 0.0549, .72) : Qt.rgba(1, 1, 1, .42) }
                    }
                }
            }

            // ══ Layer 2 — welcome / select-theme placeholder ══════════
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: themeScanner.themeCount > 0 && selectedThemeIndex < 0

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Select a theme"
                    font.family: root.headingFont
                    font.weight: Font.Bold
                    font.pixelSize: 22
                    color: appColors.textPrimary
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Pick a theme from the library on the left."
                    font.family: root.bodyFont
                    font.pixelSize: 14
                    color: appColors.textSecondary
                }
            }

            // ══ Layer 3 — empty-library drop zone ═════════════════════
            Rectangle {
                id: emptyDropZone
                visible: themeScanner.themeCount === 0
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 100
                anchors.leftMargin: appColors.stageInset
                anchors.rightMargin: appColors.marginOuter
                anchors.bottomMargin: appColors.marginOuter
                radius: appColors.radiusPanel
                color: Qt.rgba(0.5451, 0.4039, 0.949, .07)
                border.width: 0

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = Qt.rgba(0.5451, 0.4039, 0.949, .65)
                        ctx.lineWidth = 2
                        ctx.setLineDash([10, 8])
                        ctx.beginPath()
                        ctx.roundedRect ? ctx.roundedRect(1, 1, width - 2, height - 2, appColors.radiusPanel)
                                        : ctx.rect(1, 1, width - 2, height - 2)
                        ctx.stroke()
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16
                    width: Math.min(440, parent.width - 64)

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 62
                        height: 62
                        radius: 18
                        color: Qt.rgba(0.5451, 0.4039, 0.949, .18)
                        border.width: 1
                        border.color: Qt.rgba(0.5451, 0.4039, 0.949, .4)

                        Kirigami.Icon {
                            isMask: true
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: "list-add"
                            color: "#B49BFA"
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Drop a theme here"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 24
                        color: "#F2F1F7"
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "A folder with metadata.desktop, or a zip / tar.gz / tar.xz / tar.zst archive. You can also install from a public GitHub repository."
                        font.family: root.bodyFont
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, .52)
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Button {
                            id: emptyChooseFileBtn
                            implicitHeight: 42
                            leftPadding: 20
                            rightPadding: 20
                            onClicked: archiveFileDialog.open()
                            contentItem: Label {
                                text: "Choose file…"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: "#FFFFFF"
                            }
                            background: PrimaryChrome { control: emptyChooseFileBtn }
                        }

                        Button {
                            id: emptyGithubBtn
                            implicitHeight: 42
                            leftPadding: 20
                            rightPadding: 20
                            onClicked: {
                                root.installTabIndex = 1
                                root.openInstallThemeSheet()
                            }
                            contentItem: Label {
                                text: "Install from GitHub"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: appColors.isDark ? "#FFFFFF" : appColors.textPrimary
                            }
                            background: GlassSecondaryChrome { control: emptyGithubBtn }
                        }
                    }
                }
            }

            // ══ Layer 4 — header ═══════════════════════════════════════
            GlassPanel {
                id: headerPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: appColors.marginOuter
                height: 58
                backdropSource: stageBackdrop
                cornerRadius: appColors.radiusPanel
                blurAmount: appColors.blurRadius
                tint: appColors.panelGlass
                borderColor: appColors.panelBorder
                shadowColor: appColors.isDark ? "transparent" : appColors.panelShadow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 8
                        color: "transparent"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "qrc:/icons/app-logo.png"
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }
                    }

                    Label {
                        text: "Variant Manager"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 15
                        font.letterSpacing: 0.2
                        color: appColors.textPrimary
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 22
                        color: appColors.divider
                    }

                    Rectangle {
                        Layout.preferredWidth: 340
                        Layout.maximumWidth: 340
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 9
                        color: appColors.fieldBg
                        border.width: themeSearchInput.activeFocus ? 1 : 0
                        border.color: appColors.fieldBorderFocus

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            Kirigami.Icon {
                                isMask: true
                                source: "edit-find"
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                color: appColors.fieldPlaceholder
                            }

                            TextField {
                                id: themeSearchInput
                                Layout.fillWidth: true
                                placeholderText: "Search themes"
                                font.family: root.bodyFont
                                font.pixelSize: 14
                                color: appColors.textPrimary
                                placeholderTextColor: appColors.fieldPlaceholder
                                selectedTextColor: appColors.textPrimary
                                selectionColor: appColors.primaryTint
                                background: Item {}
                                onTextChanged: root.themeSearchText = text
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        radius: height / 2
                        color: root.liveTheme ? appColors.successBg
                             : (appColors.isDark ? Qt.rgba(1, 1, 1, .07) : Qt.rgba(0.1176, 0.098, 0.2745, .05))
                        border.width: 1
                        border.color: root.liveTheme ? appColors.successBorder
                                    : (appColors.isDark ? Qt.rgba(1, 1, 1, .12) : Qt.rgba(0.1176, 0.098, 0.2745, .10))
                        implicitHeight: statusPill.implicitHeight + 14
                        implicitWidth: statusPill.implicitWidth + 28

                        RowLayout {
                            id: statusPill
                            anchors.centerIn: parent
                            spacing: 9

                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: root.liveTheme ? appColors.successDot : appColors.textTertiary
                            }

                            Label {
                                text: root.liveTheme ? ("Live at login: " + root.liveAtLoginLabel) : "No active theme detected"
                                font.family: root.bodyFont
                                font.pixelSize: 13
                                color: root.liveTheme ? appColors.successText : appColors.textSecondary
                            }
                        }
                    }

                    Button {
                        id: refreshBtn
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: themeScanner.rescan()
                        ToolTip.visible: hovered
                        ToolTip.text: "Rescan themes (F5)"
                        ToolTip.delay: Kirigami.Units.toolTipDelay
                        contentItem: Kirigami.Icon {
                            isMask: true
                            source: "view-refresh"
                            color: appColors.textSecondary
                        }
                        background: GlassIconButton { control: refreshBtn }
                    }

                    Button {
                        id: settingsBtn
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: root.diagnosticsOpen = !root.diagnosticsOpen
                        ToolTip.visible: hovered
                        ToolTip.text: "System diagnostics"
                        ToolTip.delay: Kirigami.Units.toolTipDelay
                        contentItem: Kirigami.Icon {
                            isMask: true
                            source: "configure"
                            color: appColors.textSecondary
                        }
                        background: GlassIconButton { control: settingsBtn }
                    }
                }
            }

            // ══ Layer 5 — library rail ═════════════════════════════════
            GlassPanel {
                id: railPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.topMargin: 100
                anchors.leftMargin: appColors.marginOuter
                anchors.bottomMargin: root.stageBottomReserve
                width: appColors.railWidth
                backdropSource: stageBackdrop
                cornerRadius: appColors.radiusPanel
                blurAmount: appColors.blurRadius
                tint: appColors.panelGlass
                borderColor: appColors.panelBorder
                shadowColor: appColors.isDark ? "transparent" : appColors.panelShadow

                Behavior on anchors.bottomMargin { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // The panel itself always stays up (per the empty-library
                // design: "LIBRARY · 0" + empty message + emphasized Install
                // button live inside it) — only the middle content and the
                // Install button's emphasis switch on themeCount.
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.topMargin: 16
                        Layout.bottomMargin: 12

                        Label {
                            text: "LIBRARY · " + themeScanner.themeCount
                            font.family: root.headingFont
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            font.letterSpacing: 1.4
                            color: appColors.textSecondary
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: "Rescan"
                            font.family: root.bodyFont
                            font.weight: Font.Bold
                            font.pixelSize: 12
                            color: appColors.primaryTextOnGlass
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themeScanner.rescan()
                            }
                        }
                    }

                    ListView {
                        id: themeListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: themeScanner.themeCount > 0
                        clip: true
                        spacing: 2
                        leftMargin: 6
                        rightMargin: 6
                        bottomMargin: 6
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
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 8
                        visible: themeScanner.themeCount === 0

                        Item { Layout.fillHeight: true }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "No themes found"
                            font.family: root.bodyFont
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: Qt.rgba(1, 1, 1, .62)
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Nothing in the default SDDM theme directories yet."
                            font.family: root.bodyFont
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, .4)
                        }

                        Item { Layout.fillHeight: true }
                    }

                    Button {
                        id: installPrimaryBtn
                        Layout.fillWidth: true
                        Layout.margins: 14
                        Layout.topMargin: 8
                        implicitHeight: 42
                        onClicked: root.openInstallThemeSheet()

                        contentItem: RowLayout {
                            spacing: 9
                            Item { Layout.fillWidth: true }
                            Kirigami.Icon {
                                isMask: true
                                source: "list-add"
                                Layout.preferredWidth: 13
                                Layout.preferredHeight: 13
                                color: themeScanner.themeCount === 0 ? "#FFFFFF" : appColors.textPrimary
                            }
                            Label {
                                text: "Install theme"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: themeScanner.themeCount === 0 ? "#FFFFFF" : appColors.textPrimary
                            }
                            Item { Layout.fillWidth: true }
                        }
                        background: AdaptiveChrome {
                            control: installPrimaryBtn
                            emphasize: themeScanner.themeCount === 0
                        }
                    }
                }
            }

            // ══ Layer 6 — media chip + compatibility cards ═════════════
            ColumnLayout {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 100
                anchors.rightMargin: appColors.marginOuter
                width: 320
                spacing: 10
                visible: selectedThemeIndex >= 0

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    visible: root.previewTechLabel.length > 0
                    radius: 9
                    color: appColors.panelGlass
                    border.width: 1
                    border.color: appColors.panelBorder
                    implicitHeight: mediaChipRow.implicitHeight + 14
                    implicitWidth: mediaChipRow.implicitWidth + 26

                    RowLayout {
                        id: mediaChipRow
                        anchors.centerIn: parent
                        spacing: 9

                        Kirigami.Icon {
                            isMask: true
                            source: root.previewIsVideo ? "media-playback-start"
                                  : (root.previewIsGif ? "image-gif" : "image-x-generic")
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 12
                            color: appColors.textSecondary
                        }
                        Label {
                            text: root.previewTechLabel
                            font.family: root.bodyFont
                            font.pixelSize: 13
                            color: appColors.textSecondary
                        }
                    }
                }

                Repeater {
                    model: root.compatWarnings
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        radius: 11
                        color: modelData.severity === "danger" ? appColors.dangerBg : appColors.warningBg
                        border.width: 1
                        border.color: modelData.severity === "danger" ? appColors.dangerBorder : appColors.warningBorder
                        implicitHeight: warnCol.implicitHeight + 24

                        ColumnLayout {
                            id: warnCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 13
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9

                                Rectangle {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    radius: 8
                                    color: modelData.severity === "danger" ? appColors.dangerAccent : appColors.warningAccent

                                    Label {
                                        anchors.centerIn: parent
                                        text: "!"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: modelData.severity === "danger" ? "#FFFFFF" : appColors.warningDiscFg
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: modelData.title
                                    font.family: root.bodyFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 13
                                    color: modelData.severity === "danger" ? appColors.dangerText : appColors.warningText
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: modelData.body
                                font.family: root.bodyFont
                                font.pixelSize: 13
                                lineHeight: 1.4
                                color: modelData.severity === "danger" ? appColors.dangerBody : appColors.warningText
                            }
                        }
                    }
                }
            }

            // ══ Layer 7 — variant filmstrip / simple-theme info card ═══
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: appColors.stageInset
                anchors.rightMargin: appColors.marginOuter
                anchors.bottomMargin: 96
                spacing: 12
                visible: selectedThemeIndex >= 0 && currentThemeHasVariants && currentVariants.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 12

                    Label {
                        text: "VARIANTS"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 11
                        font.letterSpacing: 1.4
                        color: appColors.textSecondary
                    }
                    Label {
                        text: root.currentConfigHint
                        visible: text.length > 0
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        color: appColors.textTertiary
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 320
                    }
                }

                FontMetrics {
                    id: variantCaptionMetrics
                    font.family: root.bodyFont
                    font.pixelSize: 12
                }

                ListView {
                    id: variantFilmstrip
                    Layout.fillWidth: true
                    Layout.preferredHeight: 105 + 7 + variantCaptionMetrics.height
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: currentVariants
                    currentIndex: root.selectedVariantIndex

                    // currentIndex + highlightFollowsCurrentItem alone did not
                    // reliably scroll a newly selected (possibly offscreen)
                    // card into view here — call positionViewAtIndex directly
                    // whenever the selection or the model itself changes.
                    function revealSelection() {
                        if (root.selectedVariantIndex >= 0 && root.selectedVariantIndex < count)
                            positionViewAtIndex(root.selectedVariantIndex, ListView.Contain)
                    }
                    onModelChanged: Qt.callLater(revealSelection)

                    Connections {
                        target: root
                        function onSelectedVariantIndexChanged() { variantFilmstrip.revealSelection() }
                    }

                    // Horizontal-only list: map the (usually vertical) mouse
                    // wheel onto contentX so it's reachable without a
                    // touchpad/trackball, same as dragging the strip.
                    WheelHandler {
                        onWheel: function(event) {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            variantFilmstrip.contentX = Math.max(0, Math.min(
                                Math.max(0, variantFilmstrip.contentWidth - variantFilmstrip.width),
                                variantFilmstrip.contentX - delta))
                        }
                    }

                    delegate: Item {
                        id: variantCardRoot
                        required property var modelData
                        required property int index
                        width: 186
                        height: 105 + 7 + variantCaptionMetrics.height

                        readonly property bool variantSelected: root.selectedVariantIndex === index
                        readonly property bool variantActive: modelData.isActive === true

                        Rectangle {
                            id: variantCard
                            width: 186
                            height: 105
                            radius: appColors.radiusVariantCard
                            color: appColors.fieldBg
                            clip: true
                            border.width: variantActive ? 2 : (variantSelected ? 1.5 : 0)
                            border.color: variantActive ? appColors.primary
                                        : (variantSelected ? Qt.rgba(appColors.primary.r, appColors.primary.g, appColors.primary.b, 0.55) : "transparent")
                            scale: variantHover.hovered ? 1.02 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            layer.enabled: true
                            layer.effect: null

                            Rectangle {
                                z: -1
                                anchors.fill: parent
                                anchors.topMargin: 6
                                radius: parent.radius
                                color: appColors.isDark ? Qt.rgba(0, 0, 0, .35) : Qt.rgba(0.1176, 0.098, 0.2745, .18)
                            }

                            VariantThumbnail {
                                anchors.fill: parent
                                mediaSource: modelData.thumbnailPath ? "file://" + modelData.thumbnailPath : ""
                            }

                            HoverHandler { id: variantHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedVariantIndex = index
                            }
                        }

                        Label {
                            anchors.top: variantCard.bottom
                            anchors.topMargin: 7
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            width: variantCard.width
                            text: (modelData.displayName || modelData.id || "") + (variantCardRoot.variantActive ? " · applied" : "")
                            font.family: root.bodyFont
                            font.pixelSize: 12
                            color: appColors.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            GlassPanel {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: appColors.stageInset
                anchors.rightMargin: appColors.marginOuter
                anchors.bottomMargin: 96
                height: 54
                visible: selectedThemeIndex >= 0 && !currentThemeHasVariants
                backdropSource: stageBackdrop
                cornerRadius: 12
                blurAmount: appColors.blurRadius
                tint: appColors.panelGlass
                borderColor: appColors.panelBorder

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 17
                    anchors.rightMargin: 17

                    // Plain anchors instead of RowLayout: a fixed-size item next
                    // to a wrapping Label inside a Layout can end up with the
                    // fixed item's geometry mis-negotiated against the wrapped
                    // item's (huge, unwrapped) implicit width — anchors make
                    // both items' geometry unambiguous.
                    Rectangle {
                        id: simpleThemeInfoIcon
                        width: 17
                        height: 17
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 8.5
                        color: "transparent"
                        border.width: 1.5
                        border.color: appColors.textSecondary

                        Label {
                            anchors.centerIn: parent
                            text: "i"
                            font.pixelSize: 10
                            color: appColors.textSecondary
                        }
                    }

                    Label {
                        anchors.left: simpleThemeInfoIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        text: "Simple theme — no Themes/*.conf variant pack, so there is nothing to switch between. The stage above already shows exactly what SDDM will render."
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: appColors.textSecondary
                    }
                }
            }

            // ══ Layer 8 — command bar ═══════════════════════════════════
            GlassPanel {
                id: commandBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: appColors.stageInset
                anchors.rightMargin: appColors.marginOuter
                anchors.bottomMargin: appColors.marginOuter
                height: 60
                visible: selectedThemeIndex >= 0
                backdropSource: stageBackdrop
                cornerRadius: appColors.radiusPanel
                blurAmount: appColors.blurRadius
                tint: appColors.barGlass
                borderColor: appColors.barBorder
                shadowColor: appColors.barShadow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 10
                    spacing: 16

                    ColumnLayout {
                        spacing: 2
                        Layout.maximumWidth: 260

                        RowLayout {
                            spacing: 6
                            Label {
                                text: currentTheme.name || currentTheme.id || "Theme"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 16
                                color: appColors.textPrimary
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: currentThemeHasVariants && currentVariant.displayName
                                text: "· " + (currentVariant.displayName || "")
                                font.family: root.bodyFont
                                font.pixelSize: 16
                                color: appColors.textSecondary
                            }
                        }

                        Label {
                            text: [currentTheme.path || "", root.qtStackShort, "QML2"].filter(function(p) { return p && p.length > 0 }).join(" · ")
                            font.family: root.bodyFont
                            font.pixelSize: 12
                            color: appColors.textSecondary
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 9
                        visible: currentThemeHasVariants

                        CheckBox {
                            id: activateCheck
                            checked: root.activateInSddm
                            onCheckedChanged: root.activateInSddm = checked
                            indicator: AppCheckIndicator {
                                control: activateCheck
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            contentItem: Item { implicitWidth: 0; implicitHeight: 16 }
                        }

                        Label {
                            text: "Also set as current SDDM theme"
                            font.family: root.bodyFont
                            font.pixelSize: 13
                            color: appColors.textPrimary
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: activateCheck.checked = !activateCheck.checked
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 26
                        color: appColors.divider
                        visible: currentThemeHasVariants
                    }

                    Button {
                        id: previewBtn
                        implicitHeight: 40
                        leftPadding: 18
                        rightPadding: 18
                        enabled: (selectedThemeIndex >= 0 && (currentThemeHasVariants ? currentVariant.configFile !== undefined : true)) || greeterPreview.running
                        onClicked: {
                            if (greeterPreview.running)
                                greeterPreview.stopPreview()
                            else
                                startFullPreview()
                        }
                        contentItem: RowLayout {
                            spacing: 9
                            Kirigami.Icon {
                                isMask: true
                                source: greeterPreview.running ? "window-close" : "media-playback-start"
                                Layout.preferredWidth: 13
                                Layout.preferredHeight: 13
                                color: appColors.textPrimary
                            }
                            Label {
                                text: greeterPreview.running ? "Close preview" : "Test greeter"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: appColors.textPrimary
                            }
                        }
                        background: GlassSecondaryChrome { control: previewBtn }
                    }

                    Button {
                        id: applyBtn
                        implicitHeight: 40
                        leftPadding: 22
                        rightPadding: 22
                        enabled: root.canApplyCurrentSelection
                        onClicked: root.applyCurrentSelection()
                        contentItem: RowLayout {
                            spacing: 10
                            Kirigami.Icon {
                                isMask: true
                                source: "dialog-ok-apply"
                                Layout.preferredWidth: 13
                                Layout.preferredHeight: 13
                                color: applyBtn.enabled ? "#FFFFFF" : appColors.disabledPrimaryFg
                            }
                            Label {
                                text: currentThemeHasVariants ? "Apply variant" : "Apply theme"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: applyBtn.enabled ? "#FFFFFF" : appColors.disabledPrimaryFg
                            }
                        }
                        background: PrimaryChrome { control: applyBtn }
                    }

                    ToolButton {
                        id: overflowBtn
                        implicitWidth: 32
                        implicitHeight: 40
                        onClicked: overflowMenu.open()
                        contentItem: Label {
                            text: "⋯"
                            font.pixelSize: 17
                            color: appColors.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: GlassIconButton { control: overflowBtn }

                        Menu {
                            id: overflowMenu
                            y: -implicitHeight - 8
                            padding: 6

                            background: Rectangle {
                                implicitWidth: 190
                                radius: 12
                                color: appColors.sheetBg
                                border.width: 1
                                border.color: appColors.sheetBorder
                            }

                            OverflowMenuItem {
                                text: "Open folder"
                                menuIcon: "folder-open"
                                enabled: selectedThemeIndex >= 0 && currentTheme.path
                                onTriggered: root.openThemeInFileManager()
                            }
                            OverflowMenuItem {
                                text: "Copy path"
                                menuIcon: "edit-copy"
                                enabled: selectedThemeIndex >= 0 && currentTheme.path
                                onTriggered: root.copyThemePath()
                            }
                            MenuSeparator {
                                topPadding: 5
                                bottomPadding: 5
                                contentItem: Rectangle {
                                    implicitHeight: 1
                                    color: appColors.sheetHairline
                                }
                            }
                            OverflowMenuItem {
                                text: "Remove theme"
                                menuIcon: "edit-delete"
                                danger: true
                                enabled: root.canRemoveCurrentTheme && !themeInstaller.installing
                                onTriggered: root.requestRemoveCurrentTheme()
                            }
                        }
                    }
                }
            }

            // ══ Layer 9 — diagnostics panel ═════════════════════════════
            GlassPanel {
                id: diagnosticsPanel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: appColors.marginOuter
                width: Math.min(520, parent.width - appColors.marginOuter * 2)
                visible: opacity > 0.01
                opacity: root.diagnosticsOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                backdropSource: stageBackdrop
                cornerRadius: appColors.radiusModal
                blurAmount: appColors.blurRadius
                tint: appColors.sheetBg
                borderColor: appColors.sheetBorder
                shadowColor: appColors.sheetShadow
                shadowVerticalOffset: 0

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 28
                    contentWidth: width
                    contentHeight: diagCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: diagCol
                        width: parent.width
                        spacing: 22

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: "System"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 21
                                color: appColors.sheetTextPrimary
                            }
                            ToolButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                onClicked: root.diagnosticsOpen = false
                                contentItem: Label {
                                    text: "✕"
                                    font.pixelSize: 16
                                    color: appColors.sheetTextSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Item {}
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "GREETER"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                font.letterSpacing: 1.3
                                color: appColors.sheetTextTertiary
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Binary"; color: appColors.sheetTextSecondary; font.family: root.bodyFont; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: greeterCapabilities.greeterBinary || "—"
                                    color: appColors.sheetTextPrimary
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                    elide: Text.ElideMiddle
                                    Layout.maximumWidth: 300
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: appColors.sheetHairline }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Stack"; color: appColors.sheetTextSecondary; font.family: root.bodyFont; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: greeterCapabilities.greeterQtLabel || "—"
                                    color: appColors.sheetTextPrimary
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "GREETER MODULES"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                font.letterSpacing: 1.3
                                color: appColors.sheetTextTertiary
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 9

                                Repeater {
                                    model: root.diagnosticsModules
                                    delegate: Rectangle {
                                        required property var modelData
                                        radius: height / 2
                                        color: modelData.present ? appColors.successBg
                                             : (modelData.important ? appColors.warningBg : Qt.rgba(1, 1, 1, .06))
                                        border.width: 1
                                        border.color: modelData.present ? appColors.successBorder
                                                    : (modelData.important ? appColors.warningBorder : Qt.rgba(1, 1, 1, .12))
                                        implicitHeight: modChip.implicitHeight + 16
                                        implicitWidth: modChip.implicitWidth + 26

                                        RowLayout {
                                            id: modChip
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Rectangle {
                                                Layout.preferredWidth: 6
                                                Layout.preferredHeight: 6
                                                radius: 3
                                                color: modelData.present ? appColors.successDot
                                                     : (modelData.important ? appColors.warningAccent : Qt.rgba(1, 1, 1, .3))
                                            }
                                            Label {
                                                text: modelData.name + (modelData.present ? "" : " missing")
                                                font.family: root.bodyFont
                                                font.pixelSize: 13
                                                color: modelData.present ? appColors.successText
                                                     : (modelData.important ? appColors.warningText : Qt.rgba(1, 1, 1, .5))
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 9
                            visible: root.scannedDirectoriesInfo.length > 0

                            Label {
                                text: "SCANNED DIRECTORIES"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                font.letterSpacing: 1.3
                                color: appColors.sheetTextTertiary
                            }

                            Repeater {
                                model: root.scannedDirectoriesInfo
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.path
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        color: Qt.rgba(1, 1, 1, .7)
                                        elide: Text.ElideMiddle
                                    }
                                    Rectangle {
                                        radius: 5
                                        border.width: 1
                                        border.color: modelData.scope === "READ-ONLY" ? appColors.badgeReadonlyBorder
                                                    : (modelData.scope === "USER" ? appColors.badgeUserBorder : appColors.badgeBorder)
                                        implicitHeight: dirScopeLbl.implicitHeight + 6
                                        implicitWidth: dirScopeLbl.implicitWidth + 12
                                        Label {
                                            id: dirScopeLbl
                                            anchors.centerIn: parent
                                            text: modelData.scope
                                            font.family: root.headingFont
                                            font.weight: Font.Bold
                                            font.pixelSize: 10
                                            font.letterSpacing: 0.6
                                            color: modelData.scope === "READ-ONLY" ? appColors.badgeReadonlyText
                                                 : (modelData.scope === "USER" ? appColors.badgeUserText : appColors.badgeText)
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "TOOLS"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                font.letterSpacing: 1.3
                                color: appColors.sheetTextTertiary
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "ffmpeg"; color: appColors.sheetTextSecondary; font.family: root.bodyFont; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: themeScanner.ffmpegAvailable ? "available — sharp video thumbnails" : "missing — thumbnails will be generic"
                                    color: themeScanner.ffmpegAvailable ? appColors.successText : appColors.sheetTextSecondary
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: appColors.sheetHairline }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "git"; color: appColors.sheetTextSecondary; font.family: root.bodyFont; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: themeInstaller.gitAvailable ? "available — install from GitHub" : "missing — GitHub install disabled"
                                    color: themeInstaller.gitAvailable ? appColors.successText : appColors.sheetTextSecondary
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: greeterCapabilities.isNixOS
                            radius: 12
                            color: appColors.primaryContainer
                            border.width: 1
                            border.color: appColors.primaryContainerBorder
                            implicitHeight: nixosCol.implicitHeight + 28

                            ColumnLayout {
                                id: nixosCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 6

                                Label {
                                    text: "NixOS detected"
                                    font.family: root.bodyFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 13
                                    color: "#FFFFFF"
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: greeterCapabilities.nixosHint
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                    lineHeight: 1.5
                                    color: appColors.primaryContainerText
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: root.diagnosticsOpen
                z: diagnosticsPanel.z - 1
                onClicked: root.diagnosticsOpen = false
            }
        }
    }

    // ── Install theme sheet ────────────────────────────────────────────
    Popup {
        id: installThemeSheet
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: parent
        width: Math.min(root.width * 0.5, 660)
        padding: 28
        implicitHeight: Math.min(installSheetBody.implicitHeight + 56, root.height * 0.9)

        background: Rectangle {
            radius: appColors.radiusModal
            color: appColors.sheetBg
            border.width: 1
            border.color: appColors.sheetBorder
        }

        Overlay.modal: Rectangle {
            color: appColors.isDark ? Qt.rgba(0.0235, 0.0275, 0.0431, .65) : Qt.rgba(0.0784, 0.0627, 0.1569, .4)
        }

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: installSheetBody.implicitHeight
            clip: true

            ColumnLayout {
                id: installSheetBody
                width: parent.width
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Install theme"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 22
                        color: appColors.sheetTextPrimary
                    }

                    Rectangle {
                        visible: root.installTabIndex === 1
                        radius: 5
                        border.width: 1
                        border.color: appColors.betaBorder
                        implicitHeight: betaLbl.implicitHeight + 6
                        implicitWidth: betaLbl.implicitWidth + 14
                        Label {
                            id: betaLbl
                            anchors.centerIn: parent
                            text: "BETA"
                            font.family: root.headingFont
                            font.weight: Font.Bold
                            font.pixelSize: 11
                            font.letterSpacing: 0.8
                            color: appColors.betaText
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    wrapMode: Text.WordWrap
                    text: "Every folder with a valid metadata.desktop at the source gets installed."
                    font.family: root.bodyFont
                    font.pixelSize: 14
                    color: appColors.sheetTextSecondary
                }

                RowLayout {
                    Layout.topMargin: 22
                    spacing: 4

                    Rectangle {
                        radius: 11
                        color: appColors.sheetTrackBg
                        implicitHeight: tabsRow.implicitHeight + 6
                        implicitWidth: tabsRow.implicitWidth + 6

                        RowLayout {
                            id: tabsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                radius: 8
                                color: root.installTabIndex === 0 ? appColors.sheetTabActiveBg : "transparent"
                                implicitHeight: fromFileLbl.implicitHeight + 16
                                implicitWidth: fromFileLbl.implicitWidth + 36
                                Label {
                                    id: fromFileLbl
                                    anchors.centerIn: parent
                                    text: "From file"
                                    font.family: root.bodyFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 14
                                    color: root.installTabIndex === 0 ? appColors.sheetTabActiveText : appColors.sheetTextSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.installTabIndex = 0
                                }
                            }

                            Rectangle {
                                radius: 8
                                color: root.installTabIndex === 1 ? appColors.sheetTabActiveBg : "transparent"
                                implicitHeight: githubLbl.implicitHeight + 16
                                implicitWidth: githubLbl.implicitWidth + 36
                                Label {
                                    id: githubLbl
                                    anchors.centerIn: parent
                                    text: "GitHub"
                                    font.family: root.bodyFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 14
                                    color: root.installTabIndex === 1 ? appColors.sheetTabActiveText : appColors.sheetTextSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.installTabIndex = 1
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                ColumnLayout {
                    id: fileTabBody
                    visible: root.installTabIndex === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    spacing: 10

                    Label {
                        text: "SOURCE"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 11
                        font.letterSpacing: 1.3
                        color: appColors.sheetTextTertiary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        TextField {
                            id: localPathField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            text: root.localInstallPath
                            placeholderText: "Paste a path or choose below"
                            font.family: root.bodyFont
                            font.pixelSize: 14
                            color: appColors.sheetTextPrimary
                            placeholderTextColor: appColors.sheetTextTertiary
                            selectedTextColor: appColors.sheetTextPrimary
                            selectionColor: Qt.rgba(0.5451, 0.4039, 0.949, .4)
                            leftPadding: 14
                            rightPadding: 14
                            background: Rectangle {
                                radius: appColors.radiusButton
                                color: appColors.sheetFieldBg
                                border.width: 1
                                border.color: localPathField.activeFocus ? appColors.fieldBorderFocus : appColors.sheetFieldBorder
                            }
                            onTextEdited: root.localInstallPath = text
                            onAccepted: root.confirmInstallTheme()
                        }

                        Button {
                            id: chooseArchiveBtn
                            implicitHeight: 44
                            leftPadding: 16
                            rightPadding: 16
                            onClicked: archiveFileDialog.open()
                            contentItem: Label {
                                text: "File…"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: appColors.sheetTextPrimary
                            }
                            background: Rectangle {
                                radius: appColors.radiusButton
                                color: chooseArchiveBtn.hovered ? Qt.rgba(1, 1, 1, .12) : Qt.rgba(1, 1, 1, .08)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, .14)
                            }
                        }

                        Button {
                            id: chooseFolderBtn
                            implicitHeight: 44
                            leftPadding: 16
                            rightPadding: 16
                            onClicked: themeFolderDialog.open()
                            contentItem: Label {
                                text: "Folder…"
                                font.family: root.bodyFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: appColors.sheetTextPrimary
                            }
                            background: Rectangle {
                                radius: appColors.radiusButton
                                color: chooseFolderBtn.hovered ? Qt.rgba(1, 1, 1, .12) : Qt.rgba(1, 1, 1, .08)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, .14)
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "zip · tar · tar.gz · tar.xz · tar.bz2 · tar.zst — or a folder with metadata.desktop"
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: appColors.sheetTextTertiary
                    }
                }

                ColumnLayout {
                    id: githubTabBody
                    visible: root.installTabIndex === 1
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    spacing: 10

                    Label {
                        text: "PUBLIC REPOSITORY"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 11
                        font.letterSpacing: 1.3
                        color: appColors.sheetTextTertiary
                    }

                    TextField {
                        id: githubUrlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: root.githubInstallUrl
                        placeholderText: "https://github.com/user/sddm-theme-name"
                        font.family: root.bodyFont
                        font.pixelSize: 14
                        color: appColors.sheetTextPrimary
                        placeholderTextColor: appColors.sheetTextTertiary
                        selectedTextColor: appColors.sheetTextPrimary
                        selectionColor: Qt.rgba(0.5451, 0.4039, 0.949, .4)
                        leftPadding: 14
                        rightPadding: 14
                        background: Rectangle {
                            radius: appColors.radiusButton
                            color: appColors.sheetFieldBg
                            border.width: 1
                            border.color: githubUrlField.activeFocus ? appColors.fieldBorderFocus : appColors.sheetFieldBorder
                        }
                        onTextEdited: root.githubInstallUrl = text
                        onAccepted: root.confirmInstallTheme()
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: appColors.radiusButton
                        color: Qt.rgba(1, 1, 1, .05)
                        implicitHeight: experimentalNoteRow.implicitHeight + 24

                        RowLayout {
                            id: experimentalNoteRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10

                            Kirigami.Icon {
                                isMask: true
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignTop
                                source: "help-hint"
                                color: appColors.sheetTextSecondary
                            }

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                textFormat: Text.StyledText
                                text: "The app clones the repository and <b style=\"color:#fff\">reads</b> install.sh — it never runs it. Theme folders are copied into this distro's SDDM directories."
                                font.family: root.bodyFont
                                font.pixelSize: 13
                                lineHeight: 1.5
                                color: appColors.sheetTextSecondary
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !themeInstaller.gitAvailable
                        spacing: 8

                        Kirigami.Icon {
                            isMask: true
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "dialog-information"
                            color: appColors.sheetTextTertiary
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            text: "Install <b>git</b> to enable GitHub clone (Nix: nix profile add nixpkgs#git · Arch: pacman -S git)."
                            font.family: root.bodyFont
                            font.pixelSize: 12
                            color: appColors.sheetTextTertiary
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 24; height: 1; color: appColors.sheetHairline }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    spacing: 13

                    CheckBox {
                        id: systemWideCheck
                        indicator: AppCheckIndicator {
                            control: systemWideCheck
                            onGlass: false
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        contentItem: Item { implicitWidth: 0; implicitHeight: 18 }
                    }

                    ColumnLayout {
                        spacing: 2
                        Label {
                            text: "Install system-wide"
                            font.family: root.bodyFont
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: appColors.sheetTextPrimary
                        }
                        Label {
                            text: "Requires admin password (pkexec)"
                            font.family: root.bodyFont
                            font.pixelSize: 12
                            color: appColors.sheetTextTertiary
                        }
                    }

                    MouseArea {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: systemWideCheck.checked = !systemWideCheck.checked
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    radius: appColors.radiusButton
                    color: Qt.rgba(0.5451, 0.4039, 0.949, .12)
                    border.width: 1
                    border.color: Qt.rgba(0.5451, 0.4039, 0.949, .28)
                    implicitHeight: destinationRow.implicitHeight + 20

                    RowLayout {
                        id: destinationRow
                        anchors.centerIn: parent
                        spacing: 10

                        Kirigami.Icon {
                            isMask: true
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "folder"
                            color: "#B49BFA"
                        }

                        Label {
                            textFormat: Text.StyledText
                            font.family: root.bodyFont
                            font.pixelSize: 13
                            color: "#CBB9FB"
                            text: "Installs to <span style=\"color:#fff;font-weight:700\">"
                                  + (systemWideCheck.checked
                                     ? "/var/lib/sddm/themes/ (NixOS) or /usr/share/sddm/themes/"
                                     : "~/.local/share/sddm/themes/")
                                  + "</span>"
                        }
                    }
                }

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    running: themeInstaller.installing
                    visible: running
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    wrapMode: Text.Wrap
                    visible: themeInstaller.progressMessage.length > 0
                    text: themeInstaller.progressMessage
                    font.family: root.bodyFont
                    font.pixelSize: 13
                    color: appColors.sheetTextSecondary
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 26
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    Button {
                        id: installCancelBtn
                        implicitHeight: 44
                        leftPadding: 20
                        rightPadding: 20
                        onClicked: installThemeSheet.close()
                        contentItem: Label {
                            text: "Cancel"
                            font.family: root.headingFont
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: appColors.sheetTextSecondary
                        }
                        background: Item {}
                    }

                    Button {
                        id: installConfirmBtn
                        implicitHeight: 44
                        leftPadding: 22
                        rightPadding: 22
                        enabled: {
                            if (themeInstaller.installing)
                                return false
                            if (root.installTabIndex === 1)
                                return themeInstaller.gitAvailable && root.githubInstallUrl.trim().length > 0
                            return root.localInstallPath.trim().length > 0
                        }
                        onClicked: root.confirmInstallTheme()

                        contentItem: RowLayout {
                            spacing: 8
                            BusyIndicator {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                visible: themeInstaller.installing
                                running: visible
                            }
                            Kirigami.Icon {
                                isMask: true
                                Layout.preferredWidth: 13
                                Layout.preferredHeight: 13
                                visible: !themeInstaller.installing
                                source: "download"
                                color: "#FFFFFF"
                            }
                            Label {
                                text: themeInstaller.installing ? "Installing…" : "Install"
                                font.family: root.headingFont
                                font.weight: Font.Bold
                                font.pixelSize: 14
                                color: "#FFFFFF"
                            }
                        }
                        background: PrimaryChrome { control: installConfirmBtn }
                    }
                }
            }
        }
    }

    // ── Remove theme dialog ─────────────────────────────────────────────
    Dialog {
        id: removeConfirmDialog
        title: ""
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.NoButton
        width: Math.min(root.width * 0.4, 580)
        padding: 28

        background: Rectangle {
            radius: appColors.radiusModal
            color: appColors.sheetBg
            border.width: 1
            border.color: appColors.sheetBorder
        }

        Overlay.modal: Rectangle {
            color: appColors.isDark ? Qt.rgba(0.0235, 0.0275, 0.0431, .65) : Qt.rgba(0.0784, 0.0627, 0.1569, .4)
        }

        contentItem: ColumnLayout {
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 11
                    color: Qt.rgba(1, 1, 1, .08)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.themeThumbUrl(root.currentTheme)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: source.toString().length > 0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        Layout.fillWidth: true
                        text: "Remove " + (currentTheme.name || currentTheme.id || "this theme") + "?"
                        wrapMode: Text.WordWrap
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 21
                        color: appColors.sheetTextPrimary
                    }
                    Label {
                        text: (currentTheme.hasVariants
                                ? (currentTheme.variants.length + " variants · ")
                                : "")
                              + (root.themeScopeLabel(currentTheme) === "System" ? "system install" : "installed by user")
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: appColors.sheetTextTertiary
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "The theme files will be deleted from disk. This cannot be undone — you will need to install it again to get it back."
                font.family: root.bodyFont
                font.pixelSize: 14
                lineHeight: 1.6
                color: Qt.rgba(1, 1, 1, .66)
            }

            Rectangle {
                Layout.fillWidth: true
                radius: appColors.radiusButton
                color: Qt.rgba(1, 1, 1, .05)
                implicitHeight: removeInfoCol.implicitHeight + 26

                ColumnLayout {
                    id: removeInfoCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 13
                    spacing: 5

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.StyledText
                        text: "Path <span style=\"color:#fff\">" + (currentTheme.path || "") + "</span>"
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, .56)
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: currentTheme.readOnly === true
                              ? "Read-only path — cannot be removed here."
                              : "Writable by the app — no admin password needed."
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, .56)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }

                Button {
                    id: removeCancelBtn
                    implicitHeight: 44
                    leftPadding: 20
                    rightPadding: 20
                    onClicked: removeConfirmDialog.close()
                    contentItem: Label {
                        text: "Cancel"
                        font.family: root.headingFont
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: appColors.sheetTextSecondary
                    }
                    background: Item {}
                }

                Button {
                    id: removeConfirmBtn
                    implicitHeight: 44
                    leftPadding: 24
                    rightPadding: 24
                    enabled: root.currentTheme.readOnly !== true
                    onClicked: {
                        removeConfirmDialog.close()
                        root.confirmRemoveCurrentTheme()
                    }
                    contentItem: RowLayout {
                        spacing: 9
                        Kirigami.Icon {
                            isMask: true
                            Layout.preferredWidth: 13
                            Layout.preferredHeight: 13
                            source: "edit-delete"
                            color: "#FFFFFF"
                        }
                        Label {
                            text: "Remove theme"
                            font.family: root.headingFont
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                    }
                    background: Rectangle {
                        radius: appColors.radiusButton
                        color: !removeConfirmBtn.enabled ? Qt.rgba(0.851, 0.3373, 0.4157, .4)
                             : (removeConfirmBtn.hovered ? appColors.dangerHover : appColors.dangerAccent)
                    }
                }
            }
        }
    }

    // ── Screen 8: floating chip + exit bar over the real greeter ────────
    // Loaded on demand from a separate file (never a static import) because
    // it needs org.kde.layershell to anchor to a screen edge on Wayland —
    // a plain Window's x/y is not honored there, which used to collide both
    // panels into the compositor's own default placement. A Loader isolates
    // a missing/unavailable layer-shell module to just this feature (no
    // overlay) instead of failing the whole document.
    Loader {
        id: greeterOverlayLoader
        active: greeterPreview.running
        source: "GreeterPreviewOverlay.qml"

        onLoaded: {
            item.headingFont = root.headingFont
            item.bodyFont = root.bodyFont
            item.themeLabel = Qt.binding(function() {
                return "Real greeter in test mode · " + (root.currentTheme.name || root.currentTheme.id || "")
                    + (root.currentThemeHasVariants && root.currentVariant.displayName ? (" · " + root.currentVariant.displayName) : "")
            })
            item.applyEnabled = Qt.binding(function() { return root.canApplyCurrentSelection })
            item.applyRequested.connect(root.applyCurrentSelection)
            item.closeRequested.connect(greeterPreview.stopPreview)
        }
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("Preview overlay unavailable (org.kde.layershell not found) — Test Greeter still works, just without the floating chip/exit bar.")
        }
    }
}
