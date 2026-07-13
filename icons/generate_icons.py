#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later

"""Generate hicolor PNG icons and app logo from the design source.

KDE Plasma (KWin) and several Wayland compositors load window icons from the
icon theme (hicolor) via the .desktop Icon= name, not only from QWindow::setIcon.
Fully transparent corners often appear as a black box behind the icon, so
shipped PNGs use an opaque squircle background instead of transparency.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
ICON = "org.github.melker.sddmvariantmanager"
SOURCE = REPO / "icons/src/png" / f"{ICON}-source.png"
ICON_BG = (242, 214, 236, 255)
HICOLOR_SIZES = [16, 22, 24, 32, 48, 64, 128, 256, 512]


def is_bg(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    return r < 18 and g < 18 and b < 18


def extract_squircle(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size

    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not is_bg(r, g, b, a):
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)

    pad = max(2, int(min(w, h) * 0.01))
    minx = max(0, minx - pad)
    miny = max(0, miny - pad)
    maxx = min(w - 1, maxx + pad)
    maxy = min(h - 1, maxy + pad)

    cropped = img.crop((minx, miny, maxx + 1, maxy + 1)).convert("RGBA")
    cp = cropped.load()
    cw, ch = cropped.size
    for y in range(ch):
        for x in range(cw):
            r, g, b, a = cp[x, y]
            if is_bg(r, g, b, a):
                cp[x, y] = ICON_BG
            elif a < 255:
                alpha = a / 255.0
                cp[x, y] = (
                    int(r * alpha + ICON_BG[0] * (1 - alpha)),
                    int(g * alpha + ICON_BG[1] * (1 - alpha)),
                    int(b * alpha + ICON_BG[2] * (1 - alpha)),
                    255,
                )
            else:
                cp[x, y] = (r, g, b, 255)

    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), ICON_BG)
    square.paste(cropped, ((side - cw) // 2, (side - ch) // 2))
    return square


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Missing icon source: {SOURCE}")

    square = extract_squircle(Image.open(SOURCE))
    master = square.resize((1024, 1024), Image.Resampling.LANCZOS)
    save_png(master, REPO / "icons/src/png" / f"{ICON}-1024.png")
    save_png(square.resize((256, 256), Image.Resampling.LANCZOS), REPO / "icons/app-logo.png")

    hicolor = REPO / "icons/hicolor"
    for size in HICOLOR_SIZES:
        out = hicolor / f"{size}x{size}/apps/{ICON}.png"
        save_png(master.resize((size, size), Image.Resampling.LANCZOS), out)
        print(f"wrote {out}")

    print("Generated opaque hicolor icons and app-logo.png.")


if __name__ == "__main__":
    main()
