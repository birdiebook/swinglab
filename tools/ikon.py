"""Ritar appens ikon (BESLUT B13): svart botten, vitt typografiskt märke, ingen figur.

    python3 tools/ikon.py [<typsnitt.otf>]

Skriver App/Assets.xcassets/AppIcon.appiconset/icon-1024.png (RGB, utan alfa:
App Store Connect vägrar en ikon med genomskinlighet). Typsnittet är Inter
(SIL OFL); utan det används PIL:s eget.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

UT = Path(__file__).resolve().parent.parent / "App/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
TYPSNITT = ["/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf",
            "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"]
STORLEK = 1024


def typsnitt(storlek: int, val: list[str]) -> ImageFont.ImageFont:
    for p in val:
        if Path(p).exists():
            return ImageFont.truetype(p, storlek)
    return ImageFont.load_default(size=storlek)


def rita(val: list[str]) -> Image.Image:
    bild = Image.new("RGB", (STORLEK, STORLEK), (0, 0, 0))
    rita = ImageDraw.Draw(bild)
    font = typsnitt(440, val)
    text = "SL"
    x0, y0, x1, y1 = rita.textbbox((0, 0), text, font=font)
    x = (STORLEK - (x1 - x0)) / 2 - x0
    y = (STORLEK - (y1 - y0)) / 2 - y0
    rita.text((x, y), text, font=font, fill=(255, 255, 255))
    # En tunn linje under märket: mätinstrumentets nollinje, inget annat.
    linje_y = y + y1 + 70
    rita.rectangle([(STORLEK - (x1 - x0)) / 2, linje_y, (STORLEK + (x1 - x0)) / 2, linje_y + 10],
                   fill=(255, 255, 255))
    return bild


if __name__ == "__main__":
    rita(sys.argv[1:] + TYPSNITT).save(UT, optimize=True)
    print(UT)
