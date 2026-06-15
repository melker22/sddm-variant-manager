#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later

"""Generate hicolor PNG icons from Figma exports.

KDE Plasma (KWin) and several Wayland compositors load window icons from the
icon theme (hicolor) via the .desktop Icon= name, not only from QWindow::setIcon.
Fully transparent corners and soft drop-shadow fringes often appear as a black
box behind the icon. All shipped PNGs are defringed and use an opaque squircle
background color instead of transparency.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
ASSETS = Path.home() / ".cursor/projects/home-melker-Documentos-Linux-Rice-Bonito-SDDM/assets"
ICON = "org.github.melker.sddmvariantmanager"

# Material You primary container (squircle background in the icon artwork)
ICON_BG = (242, 214, 236, 255)

FIGMA_SOURCES = {
    256: "Icone_1_7_-1753f81b-1f26-4ac9-94ad-a8aeb057b535.png",
    384: "Icone_1_8_-c75530df-c740-4d7a-a4c5-bb564ad9fdd1.png",
    512: "Icone_1_5_-17b5e333-34ca-48e3-b029-34c7f9d5cd62.png",
    768: "Icone_1_1_-fdc7a0aa-6715-448a-b509-c788b4e3a721.png",
    1024: "Icone_1_2_-6869606f-7e24-498c-8a68-adf31579194d.png",
}

HICOLOR_SIZES = [16, 22, 24, 32, 48, 64, 128, 256, 512]


def load_source(size: int) -> Image.Image:
    path = ASSETS / FIGMA_SOURCES[size]
    if not path.exists():
        raise FileNotFoundError(f"Missing Figma export: {path}")
    return Image.open(path).convert("RGBA")


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def defringe(img: Image.Image, min_alpha: int = 48) -> Image.Image:
    out = img.copy().convert("RGBA")
    px = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a <= min_alpha:
                px[x, y] = (0, 0, 0, 0)
            elif a < 255:
                scale = 255.0 / a
                px[x, y] = (
                    min(255, int(r * scale)),
                    min(255, int(g * scale)),
                    min(255, int(b * scale)),
                    255,
                )
    return out


def fill_transparent(img: Image.Image, fill: tuple[int, int, int, int]) -> Image.Image:
    out = img.copy().convert("RGBA")
    px = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            if px[x, y][3] == 0:
                px[x, y] = fill
    return out


def prepare_icon(img: Image.Image) -> Image.Image:
    return fill_transparent(defringe(img), ICON_BG)


def resize(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    src_dir = REPO / "icons/src/png"
    hicolor = REPO / "icons/hicolor"

    masters = {size: load_source(size) for size in FIGMA_SOURCES}
    master_1024 = masters[1024]

    for size, img in masters.items():
        save_png(prepare_icon(img), src_dir / f"{ICON}-{size}.png")

    for size in HICOLOR_SIZES:
        out = hicolor / f"{size}x{size}/apps/{ICON}.png"
        if size in masters:
            base = masters[size]
        else:
            base = resize(master_1024, size)
        save_png(prepare_icon(base), out)

    print("Generated opaque hicolor icons for Plasma/Wayland.")


if __name__ == "__main__":
    main()
