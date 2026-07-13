#!/usr/bin/env python3
"""Regenerates VietNews/Assets.xcassets/AppIcon.appiconset from Resources/IconSource.

Run after changing colors, glyph, or padding:
    python3 Scripts/generate_app_icon.py
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_PATH = ROOT / "Resources/IconSource/ArchivoBlack-Regular.ttf"
APPICONSET = ROOT / "VietNews/Assets.xcassets/AppIcon.appiconset"

SIZE = 1024
GLYPH = "TTX"
SAFE_WIDTH_RATIO = 0.62  # glyph occupies ~62% of the icon width, per Apple HIG safe area


def render(bg_top, bg_bottom, glyph_color, filename):
    img = Image.new("RGB", (SIZE, SIZE), bg_bottom)
    draw = ImageDraw.Draw(img)

    # Diagonal paper sheen: lighten toward the top-left corner.
    for y in range(SIZE):
        t = y / SIZE
        row = tuple(int(bg_top[i] * (1 - t) + bg_bottom[i] * t) for i in range(3))
        draw.line([(0, y), (SIZE, y)], fill=row)

    # Fit the glyph to SAFE_WIDTH_RATIO of the icon by binary-searching the font size.
    lo, hi = 10, SIZE
    font = None
    target_width = SIZE * SAFE_WIDTH_RATIO
    while lo <= hi:
        mid = (lo + hi) // 2
        candidate = ImageFont.truetype(str(FONT_PATH), mid)
        bbox = draw.textbbox((0, 0), GLYPH, font=candidate)
        width = bbox[2] - bbox[0]
        if width <= target_width:
            font = candidate
            lo = mid + 1
        else:
            hi = mid - 1

    bbox = draw.textbbox((0, 0), GLYPH, font=font)
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pos = ((SIZE - text_w) / 2 - bbox[0], (SIZE - text_h) / 2 - bbox[1])
    draw.text(pos, GLYPH, font=font, fill=glyph_color)

    img.save(APPICONSET / filename, format="PNG")


def main():
    APPICONSET.mkdir(parents=True, exist_ok=True)

    # Base: off-white paper, charcoal ink.
    render((0xFA, 0xF8, 0xF2), (0xE4, 0xE1, 0xD6), (0x23, 0x23, 0x20), "AppIcon-1024.png")

    # Dark appearance: inverted, near-black paper, off-white ink.
    render((0x28, 0x28, 0x2A), (0x1C, 0x1C, 0x1E), (0xF2, 0xF0, 0xE9), "AppIcon-1024-dark.png")

    # Tinted appearance: grayscale so the system tint composites correctly.
    render((0x2E, 0x2E, 0x2E), (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), "AppIcon-1024-tinted.png")

    print(f"Wrote 3 icon PNGs to {APPICONSET}")


if __name__ == "__main__":
    main()
