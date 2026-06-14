# SDDM Variant Manager

Graphical tool for KDE/Plasma users to browse, preview, and apply background variants of multi-variant SDDM themes (such as [ZenMatrix Collection](https://github.com/OminduD/sddm-themes)) without editing text files manually.

## Features

- Detects SDDM themes with a `Themes/*.conf` folder under `/usr/share/sddm/themes/` and `~/.local/share/sddm/themes/`
- Grid gallery with thumbnails (GIF when available, otherwise the background media)
- Quick embedded video preview
- Full SDDM login preview via `sddm-greeter-qt6 --test-mode`
- One-click apply with optional SDDM current theme activation

## Requirements

- Plasma 6 / Qt 6
- SDDM
- `sddm-greeter-qt6`
- `pkexec` (PolicyKit) for writing system theme files

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
2. Pick a multi-variant SDDM theme in the sidebar.
3. Select a background variant from the grid.
4. Use **Apply variant** to persist the choice, or **Full SDDM preview** to test the login screen.

Applying or previewing system themes in `/usr/share/sddm/themes/` requires administrator authentication.

## License

Copyright (C) 2026 Melker Halberd Pereira Alves

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE) for the full text.

## Author

Melker Halberd Pereira Alves <melker168@gmail.com>
