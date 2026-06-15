# SDDM Variant Manager

Graphical tool for anyone who uses **SDDM** — whether you run **Hyprland**, **Plasma**, or another desktop — to browse, preview, apply, and install login screen themes without logging out every time. It supports multi-variant collections such as [ZenMatrix Collection](https://github.com/OminduD/sddm-themes).

The interface is built with **Qt 6** and **Kirigami** (KDE-style). You do not need a Plasma session day to day; you only need SDDM and the runtime libraries listed below.

## Why this exists

I use **Hyprland** daily with **SDDM** as my display manager and enjoy customizing the login screen. Browsing SDDM themes was frustrating: the only reliable way to see how a theme really looked was to set it, log out, and test on the actual greeter — over and over.

Themes with **multiple background variants** (collections that ship a `Themes/*.conf` folder) were worse: switching variants meant editing `metadata.desktop` or config files by hand.

KDE's SDDM theme settings (available on my Manjaro install, which also has Plasma) help with thumbnails and picking a theme, but they do not show a faithful fullscreen preview — especially for **animated backgrounds** (video, GIF, or QML animation).

SDDM Variant Manager was built to fix that: browse variants, preview backgrounds, run the real greeter in test mode, and apply changes without logging out every time.

## Who it's for

- **Hyprland, Plasma, or any setup** that uses SDDM
- Rice / theme collectors who install many login themes
- Multi-variant theme packs (e.g. ZenMatrix Collection)
- Video or animated SDDM backgrounds

## Features

- Lists **all installed SDDM themes** (`metadata.desktop`) under `/usr/share/sddm/themes/` and `~/.local/share/sddm/themes/`
- Multi-variant themes: browse `Themes/*.conf` variants, apply a variant, preview backgrounds
- Simple themes: apply as SDDM current theme and open a full greeter preview
- High-quality static thumbnails for variant galleries (cached JPEG frames via `ffmpeg`)
- **Install themes from GitHub** — paste an HTTPS or SSH repo URL and install all valid themes found
- Full SDDM login preview via `sddm-greeter` / `sddm-greeter-qt6 --test-mode` (chosen automatically per theme)

## Requirements

### Required

- Qt 6 and KF6 Kirigami (a Plasma install on the system makes these easy to satisfy on Manjaro/Arch)
- SDDM
- `sddm-greeter-qt6` and/or `sddm-greeter` (Qt 5 themes use the latter)
- `pkexec` (PolicyKit) for writing system theme files or system-wide installs

### Required for GitHub installation

- **`git`**

```bash
pamac install git --no-confirm
```

### Strongly recommended

- **`ffmpeg`** — builds sharp static thumbnails from theme background videos. The app still runs without it, but variant thumbnails fall back to low-resolution GIF previews.

```bash
pamac install ffmpeg --no-confirm
```

Only skip `ffmpeg` if you truly cannot install it on your system.

## Build

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/sddm-variant-manager
```

Open the project in **Qt Creator** via `CMakeLists.txt`.

## Install

```bash
cmake --install build
```

This installs the binary to `/usr/local/bin` (or your chosen prefix) and adds a `.desktop` entry.

## Usage

1. Launch **SDDM Variant Manager** from the application menu.
2. Pick a theme in the sidebar.
3. For multi-variant themes, select a variant and click **Apply variant**.
4. For simple themes, click **Apply as SDDM theme**.
5. Use **Full SDDM preview** to test the login screen.

### Install a theme from GitHub

1. Click **Install theme** in the toolbar.
2. Paste a public GitHub URL, for example:
   - `https://github.com/user/sddm-theme`
   - `git@github.com:user/sddm-theme.git`
3. Leave **Install system-wide** unchecked to install for your user only (`~/.local/share/sddm/themes/`).
4. Click **Install theme**.

All folders containing `metadata.desktop` in the repository are installed.

### Close full SDDM preview

The preview opens the real SDDM greeter in test mode and covers the entire screen. **SDDM Variant Manager stays open in the background** — you need a separate way to dismiss the preview window.

How you do that depends on your desktop environment.

#### On KDE Plasma

Plasma keeps the app reachable through the task switcher:

1. Press **Alt+Tab**
2. Select **SDDM Variant Manager**
3. Click **Close preview**

#### On Hyprland

Hyprland gives you more direct control over each window than a traditional desktop like Plasma or GNOME. You do **not** need to Alt+Tab back to the app first — you can close the preview window itself.

**Option A — Close the preview directly (simplest)**

1. Make sure the SDDM preview window is focused (it usually already is, because it is fullscreen).
2. Press your Hyprland **close window** keybind — the same shortcut you already use to close other applications.

On Hyprland there is normally **no title-bar X button** like on Plasma or GNOME. Closing apps is done with keyboard shortcuts, and the exact binding is yours to configure in `hyprland.conf` (common examples: `Super + Q`, `Alt + F4`, or similar).

**Option B — Leave fullscreen, then close**

1. Press your Hyprland **toggle fullscreen** keybind while the preview is focused.
2. Press your **close window** keybind.

Either option stops the greeter preview and returns you to SDDM Variant Manager.

Applying variants, system-wide installs, and writing themes in `/usr/share/sddm/themes/` require administrator authentication.

## License

Copyright (C) 2026 Melker Halberd Pereira Alves

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE) for the full text.

## Author

Melker Halberd Pereira Alves <melker168@gmail.com>
