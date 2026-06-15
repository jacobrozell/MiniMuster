#!/usr/bin/env python3
"""Generate static launch-screen assets that mirror SplashView."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "MiniMuster" / "Resources" / "Assets.xcassets"
CREST_PATH = ASSETS / "CrestLogo.imageset" / "CrestLogo@3x.png"

PALETTES = {
    "light": {
        "bg": (0xF4, 0xF1, 0xEA),
        "bg2": (0xEB, 0xE6, 0xDC),
        "gold": (0x9A, 0x74, 0x28),
        "blood": (0xA8, 0x32, 0x28),
    },
    "dark": {
        "bg": (0x0B, 0x0C, 0x0F),
        "bg2": (0x10, 0x12, 0x18),
        "gold": (0xC9, 0xA4, 0x4C),
        "blood": (0x8C, 0x2B, 0x22),
    },
}

SIZES = {
    "1x": (393, 852),
    "2x": (786, 1704),
    "3x": (1179, 2556),
}


def blend(bottom: tuple[int, int, int], top: tuple[int, int, int], alpha: float) -> tuple[int, int, int]:
    return tuple(int(bottom[i] * (1 - alpha) + top[i] * alpha) for i in range(3))


def radial_gradient(
    size: tuple[int, int],
    center: tuple[float, float],
    inner: float,
    outer: float,
    color: tuple[int, int, int],
    alpha: float,
) -> Image.Image:
    width, height = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = layer.load()
    cx = center[0] * width
    cy = center[1] * height
    for y in range(height):
        for x in range(width):
            distance = math.hypot(x - cx, y - cy)
            if distance > outer:
                continue
            if distance <= inner:
                factor = 1.0
            else:
                factor = 1.0 - (distance - inner) / (outer - inner)
            pixels[x, y] = (*color, int(255 * alpha * factor))
    return layer


def make_backdrop(size: tuple[int, int], palette: dict[str, tuple[int, int, int]]) -> Image.Image:
    width, height = size
    base = Image.new("RGB", size, palette["bg"])
    canvas = base.convert("RGBA")

    top_glow = radial_gradient(size, (0.5, 0.0), 20, 420, palette["gold"], 0.18)
    bottom_glow = radial_gradient(size, (1.0, 1.0), 10, 320, palette["blood"], 0.08)

    canvas = Image.alpha_composite(canvas, top_glow)
    canvas = Image.alpha_composite(canvas, bottom_glow)

    fade = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(fade)
    mid = int(height * 0.45)
    for y in range(mid, height):
        t = (y - mid) / max(height - mid, 1)
        color = blend(palette["bg"], palette["bg2"], 0.55 * t)
        draw.line([(0, y), (width, y)], fill=(*color, 255))
    canvas = Image.alpha_composite(canvas, fade)
    return canvas.convert("RGB")


def make_crest_hero(diameter: int, palette: dict[str, tuple[int, int, int]]) -> Image.Image:
    canvas = int(diameter)
    size = (canvas, canvas)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    gold = palette["gold"]
    center = canvas / 2
    crest_size = int(canvas * 0.68)

    outer = canvas * 0.59
    middle = canvas * 0.50
    inner_fill = canvas * 0.50

    draw.ellipse(
        (center - outer, center - outer, center + outer, center + outer),
        outline=(*gold, int(255 * 0.12)),
        width=max(4, int(canvas * 0.05)),
    )
    draw.ellipse(
        (center - inner_fill, center - inner_fill, center + inner_fill, center + inner_fill),
        fill=(*gold, int(255 * 0.12)),
    )
    draw.ellipse(
        (center - middle, center - middle, center + middle, center + middle),
        outline=(*gold, int(255 * 0.35)),
        width=max(2, int(canvas * 0.011)),
    )

    crest = Image.open(CREST_PATH).convert("RGBA")
    crest = crest.resize((crest_size, crest_size), Image.Resampling.LANCZOS)
    offset = int((canvas - crest_size) / 2)
    image.alpha_composite(crest, (offset, offset))
    return image


def write_imageset(
    name: str,
    *,
    appearances: dict[str, dict[str, str]],
) -> None:
    imageset = ASSETS / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)

    images: list[dict] = []
    for appearance, scales in appearances.items():
        for scale, filename in scales.items():
            entry = {
                "filename": filename,
                "idiom": "universal",
                "scale": scale,
            }
            if appearance != "default":
                entry["appearances"] = [
                    {"appearance": "luminosity", "value": appearance}
                ]
            images.append(entry)

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_color(name: str, light: str, dark: str) -> None:
    colorset = ASSETS / f"{name}.colorset"
    colorset.mkdir(parents=True, exist_ok=True)

    def components(hex_value: str) -> dict[str, str]:
        value = hex_value.lstrip("#")
        r = int(value[0:2], 16) / 255
        g = int(value[2:4], 16) / 255
        b = int(value[4:6], 16) / 255
        return {"alpha": "1.000", "red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}"}

    contents = {
        "colors": [
            {
                "color": {"color-space": "srgb", "components": components(light)},
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {"color-space": "srgb", "components": components(dark)},
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (colorset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> None:
    backdrop_appearances: dict[str, dict[str, str]] = {"default": {}, "dark": {}}

    for scale, size in SIZES.items():
        for mode, palette in PALETTES.items():
            suffix = "" if mode == "light" else f"-{mode}"
            filename = f"LaunchBackdrop{suffix}@{scale}.png"
            image = make_backdrop(size, palette)
            path = ASSETS / "LaunchBackdrop.imageset" / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path, format="PNG", optimize=True)
            if mode == "light":
                backdrop_appearances["default"][scale] = filename
            else:
                backdrop_appearances["dark"][scale] = filename

    write_imageset("LaunchBackdrop", appearances=backdrop_appearances)

    crest_appearances: dict[str, dict[str, str]] = {"default": {}, "dark": {}}
    crest_diameters = {"1x": 132, "2x": 264, "3x": 396}

    for scale, diameter in crest_diameters.items():
        for mode, palette in PALETTES.items():
            suffix = "" if mode == "light" else f"-{mode}"
            filename = f"LaunchCrestHero{suffix}@{scale}.png"
            image = make_crest_hero(diameter, palette)
            path = ASSETS / "LaunchCrestHero.imageset" / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path, format="PNG", optimize=True)
            if mode == "light":
                crest_appearances["default"][scale] = filename
            else:
                crest_appearances["dark"][scale] = filename

    write_imageset("LaunchCrestHero", appearances=crest_appearances)

    write_color("BrandGold", "#9a7428", "#c9a44c")
    write_color("BrandInk", "#1a1814", "#e8e5dc")
    write_color("BrandInkSecondary", "#5c574e", "#9a978c")

    print("Generated launch assets in", ASSETS)


if __name__ == "__main__":
    main()
