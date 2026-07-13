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

- Lists **all installed SDDM themes** (`metadata.desktop`) under:
  - `/usr/share/sddm/themes/` (Arch / Manjaro / most distros)
  - `/run/current-system/sw/share/sddm/themes/` and `/var/lib/sddm/themes/` (**NixOS**)
  - `~/.local/share/sddm/themes/` (per-user)
- Multi-variant themes: browse `Themes/*.conf` variants, apply a variant, preview backgrounds
- Simple themes: apply as SDDM current theme and open a full greeter preview
- High-quality static thumbnails for variant galleries (cached JPEG frames via `ffmpeg`)
- **Install themes from GitHub** — paste an HTTPS or SSH repo URL and install all valid themes found
- **Install from a local folder or archive** — zip, tar, tar.gz, tar.xz, tar.bz2, tar.zst (or drag-and-drop onto the window)
- Full SDDM login preview via `sddm-greeter` / `sddm-greeter-qt6 --test-mode` (chosen automatically per theme)
- **Greeter capability check**: detects whether the system SDDM greeter has QtMultimedia / Qt5Compat / etc., and warns when a theme needs something missing (themes are never rewritten)
- **NixOS-aware**: system installs go to `/var/lib/sddm/themes/`; activating a theme writes a drop-in under `/etc/sddm.conf.d/` (no rebuild required)

## Requirements

### Required

- Qt 6 and KF6 Kirigami (a Plasma install on the system makes these easy to satisfy on Manjaro/Arch)
- KF6 Archive (`karchive`) — extract zip / tar archives when installing from a local file
- SDDM
- `sddm-greeter-qt6` and/or `sddm-greeter` (Qt 5 themes use the latter)
- `pkexec` (PolicyKit) for writing system theme files or system-wide installs

```bash
# Arch / Manjaro (if not already pulled in with Plasma)
pamac install karchive --no-confirm
```

### Required for GitHub installation

- **`git`**

```bash
# Arch / Manjaro
pamac install git --no-confirm
# or: sudo pacman -S git

# NixOS (user profile)
nix profile add nixpkgs#git
```

### Strongly recommended

- **`ffmpeg`** — builds sharp static thumbnails from theme background videos. The app still runs without it, but variant thumbnails fall back to low-resolution GIF previews.

```bash
# Arch / Manjaro
pamac install ffmpeg --no-confirm

# NixOS (user profile)
nix profile add nixpkgs#ffmpeg
```

Only skip `ffmpeg` if you truly cannot install it on your system.

## Build

### Classic (cmake)

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/sddm-variant-manager
```

Open the project in **Qt Creator** via `CMakeLists.txt`.

### Nix / NixOS (flake)

```bash
# One-shot run without installing
nix run .

# Development shell (cmake, Qt 6, Kirigami, …)
nix develop
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/sddm-variant-manager
```

On NixOS you can also use the existing `shell.nix` / `./qtcreator-dev.sh` helpers to open Qt Creator with the correct QML plugin paths.

## Install

### NixOS (recommended)

Enable flakes (`nix-command` + `flakes`) if you have not already.

#### 1. Quick try (no install)

```bash
nix run github:melker22/sddm-variant-manager
```

From a local clone:

```bash
nix run .
```

#### 2. Install into your user profile

```bash
nix profile add github:melker22/sddm-variant-manager
# or, from a local clone:
nix profile add .
```

#### 3. System-wide via flake (recommended)

Add the flake input and put the package on `environment.systemPackages`:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sddm-variant-manager.url = "github:melker22/sddm-variant-manager";
  };

  outputs = { nixpkgs, sddm-variant-manager, ... }: {
    nixosConfigurations.YOUR_HOSTNAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [
            sddm-variant-manager.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

#### 4. Home Manager

```nix
# In a flake-based home-manager config:
home.packages = [
  inputs.sddm-variant-manager.packages.${pkgs.system}.default
];
```

Or vendor the package without adding a flake input:

```nix
home.packages = [
  (pkgs.callPackage ./path/to/sddm-variant-manager/nix/package.nix { })
];
```

The package wraps Qt/Kirigami (`wrapQtAppsHook`) and puts `git` / `ffmpeg` on `PATH`.

#### 5. Video / animated themes — greeter Qt modules

The app **installs themes unchanged**. Video backgrounds need **QtMultimedia inside the system SDDM greeter**, not only in the app. On NixOS add:

```nix
services.displayManager.sddm.extraPackages = with pkgs.kdePackages; [
  qtmultimedia
  qtsvg
  qtvirtualkeyboard
];

# Optional: also on PATH for tooling
environment.systemPackages = with pkgs; [
  kdePackages.qtmultimedia
];
```

Then `sudo nixos-rebuild switch` and log out once so the new greeter wrap is used. The app reports missing greeter modules in the UI instead of rewriting theme files.

### How theme install/apply works on NixOS

NixOS keeps `/usr` and the SDDM theme tree under `/run/current-system/...` **immutable**. This app therefore:

| Action | Location |
|--------|----------|
| Scan system themes | `/run/current-system/sw/share/sddm/themes/` (read-only) |
| Install system-wide | `/var/lib/sddm/themes/` (writable, persists across rebuilds) |
| Install per-user | `~/.local/share/sddm/themes/` |
| Activate theme | writes `/etc/sddm.conf.d/99-sddm-variant-manager.conf` with `Current=` and `ThemeDir=` |

That drop-in overrides `Theme` settings from the generated `00-nixos.conf` **without** a `nixos-rebuild`. Polkit (`pkexec`) is required; Plasma/SDDM already provide it.

Home-installed themes are **copied unchanged** into `/var/lib/sddm/themes/` when activated, because the `sddm` user often cannot read `$HOME` (mode `700`).

**Read-only themes** from the Nix store (e.g. `breeze`) can still be **activated** and **previewed**. Applying a **variant** (editing `metadata.desktop`) needs a writable copy — install the theme system-wide or per-user first.

#### Declarative theme only (optional)

If you prefer everything in `configuration.nix` instead of the GUI:

```nix
{ pkgs, ... }:
{
  services.displayManager.sddm = {
    enable = true;
    theme = "breeze"; # theme directory name under ThemeDir
  };
}
```

Rebuild with `sudo nixos-rebuild switch`. The GUI drop-in and declarative `theme=` can conflict — remove `/etc/sddm.conf.d/99-sddm-variant-manager.conf` if you switch fully to declarative management.

### Arch Linux / Manjaro (recommended)

Build the native `.pkg.tar.zst` package:

```bash
cd packaging/arch
./build-package.sh
```

Install the generated package:

```bash
sudo pacman -U ./sddm-variant-manager-*.pkg.tar.zst
```

Or with **pamac**:

```bash
pamac install ./sddm-variant-manager-*.pkg.tar.zst --no-confirm
```

This installs to `/usr/bin` and registers the app in the system menu.

To remove later:

```bash
sudo pacman -R sddm-variant-manager
```

### From source (manual)

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
```

This installs the binary to `/usr/bin` and adds a `.desktop` entry.

## Usage

1. Launch **SDDM Variant Manager** from the application menu.
2. Pick a theme in the sidebar.
3. For multi-variant themes, select a variant and click **Apply variant**.
4. For simple themes, click **Apply as SDDM theme**.
5. Use **Full SDDM preview** to test the login screen.

### Install themes

1. Click **Install theme** in the toolbar (or drag a folder/archive onto the window).
2. Choose a source tab:

#### From GitHub

1. Paste a public GitHub URL, for example:
   - `https://github.com/user/sddm-theme`
   - `git@github.com:user/sddm-theme.git`
2. Optionally enable **Install system-wide**.
3. Click **Install**.

Requires **`git`**.

#### From file or folder

1. Open the **From file or folder** tab.
2. Use **Choose file…** for an archive (`.zip`, `.tar`, `.tar.gz` / `.tgz`, `.tar.xz` / `.txz`, `.tar.bz2`, `.tar.zst`) or **Choose folder…** for a directory that contains one or more themes (`metadata.desktop`).
3. Optionally enable **Install system-wide**.
4. Click **Install**.

You can also **drag and drop** a theme folder or archive onto the main window — the install dialog opens already filled in.

#### Install locations

- Leave **Install system-wide** unchecked to install for your user only (`~/.local/share/sddm/themes/`).
- On **NixOS**, check **Install system-wide** to install into `/var/lib/sddm/themes/` (not `/usr/share/...`).
- On Arch / Manjaro, system-wide installs go to `/usr/share/sddm/themes/`.

All folders containing `metadata.desktop` in the source are installed.

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

Applying variants, system-wide installs, and writing SDDM config (Arch: `/usr/share/sddm/themes/`; NixOS: `/var/lib/sddm/themes/` + `/etc/sddm.conf.d/99-sddm-variant-manager.conf`) require administrator authentication via Polkit.

## License

Copyright (C) 2026 Melker Halberd Pereira Alves

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE) for the full text.

## Author

Melker Halberd Pereira Alves <melker168@gmail.com>
