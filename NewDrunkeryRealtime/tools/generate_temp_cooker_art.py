#!/usr/bin/env python3
from __future__ import annotations

import struct
import zlib
from pathlib import Path


SCALE = 8
LOW_SIZE = 128
OUT_SIZE = LOW_SIZE * SCALE
TOP_SPLIT = 95


Color = tuple[int, int, int, int]


def rgba(hex_color: str, alpha: int = 255) -> Color:
    value = hex_color.lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16),
        alpha,
    )


TRANSPARENT: Color = (0, 0, 0, 0)
OUTLINE = rgba("#2a1c18")
OUTLINE_DARK = rgba("#16100f")
WOOD_DARK = rgba("#6b3f24")
WOOD = rgba("#9a6033")
WOOD_LIGHT = rgba("#c68645")
METAL_DARK = rgba("#59616a")
METAL = rgba("#8f9aa2")
METAL_LIGHT = rgba("#d0d8dc")
SHADOW = rgba("#1b1512", 150)


def make_canvas() -> list[list[Color]]:
    return [[TRANSPARENT for _ in range(LOW_SIZE)] for _ in range(LOW_SIZE)]


def set_px(img: list[list[Color]], x: int, y: int, color: Color) -> None:
    if 0 <= x < LOW_SIZE and 0 <= y < LOW_SIZE:
        img[y][x] = color


def rect(img: list[list[Color]], x: int, y: int, w: int, h: int, color: Color) -> None:
    for py in range(y, y + h):
        for px in range(x, x + w):
            set_px(img, px, py, color)


def rect_outline(img: list[list[Color]], x: int, y: int, w: int, h: int, fill: Color, outline: Color = OUTLINE, bw: int = 2) -> None:
    rect(img, x, y, w, h, outline)
    rect(img, x + bw, y + bw, w - bw * 2, h - bw * 2, fill)


def ellipse(img: list[list[Color]], cx: int, cy: int, rx: int, ry: int, color: Color) -> None:
    for py in range(cy - ry, cy + ry + 1):
        for px in range(cx - rx, cx + rx + 1):
            dx = (px - cx) / max(rx, 1)
            dy = (py - cy) / max(ry, 1)
            if dx * dx + dy * dy <= 1.0:
                set_px(img, px, py, color)


def ellipse_outline(img: list[list[Color]], cx: int, cy: int, rx: int, ry: int, fill: Color, outline: Color = OUTLINE, bw: int = 2) -> None:
    ellipse(img, cx, cy, rx, ry, outline)
    ellipse(img, cx, cy, max(rx - bw, 1), max(ry - bw, 1), fill)


def line(img: list[list[Color]], x0: int, y0: int, x1: int, y1: int, color: Color, thickness: int = 1) -> None:
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        rect(img, x - thickness // 2, y - thickness // 2, thickness, thickness, color)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy


def draw_base(img: list[list[Color]], accent: Color) -> None:
    # Top sprite portion.
    ellipse(img, 64, 91, 51, 9, SHADOW)
    rect_outline(img, 20, 54, 88, 25, WOOD, OUTLINE, 2)
    rect(img, 24, 58, 80, 6, WOOD_LIGHT)
    rect(img, 24, 70, 80, 6, WOOD_DARK)
    rect(img, 25, 79, 78, 10, WOOD_DARK)
    rect(img, 29, 81, 70, 4, WOOD)
    rect(img, 24, 88, 11, 7, OUTLINE_DARK)
    rect(img, 93, 88, 11, 7, OUTLINE_DARK)
    rect(img, 26, 78, 76, 5, accent)

    # LowerSprite receives this region, but it is now only the lower edge of the
    # same station body instead of a separate stool-like object.
    rect_outline(img, 23, 96, 82, 20, WOOD_DARK, OUTLINE_DARK, 2)
    rect(img, 28, 99, 72, 5, WOOD)
    rect(img, 31, 116, 10, 8, OUTLINE_DARK)
    rect(img, 87, 116, 10, 8, OUTLINE_DARK)


def draw_cut(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#d9b15a"))
    rect_outline(img, 39, 31, 50, 27, rgba("#d8a65a"), OUTLINE, 2)
    rect(img, 45, 36, 38, 5, rgba("#f0c77d"))
    line(img, 81, 27, 52, 55, METAL_LIGHT, 5)
    line(img, 83, 27, 54, 55, OUTLINE, 1)
    rect(img, 83, 24, 8, 9, rgba("#50301e"))


def draw_stir(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#e37d2f"))
    ellipse_outline(img, 64, 45, 35, 18, rgba("#30343b"), OUTLINE, 2)
    ellipse(img, 64, 42, 28, 10, rgba("#16191d"))
    line(img, 32, 42, 20, 34, OUTLINE, 3)
    line(img, 96, 42, 108, 34, OUTLINE, 3)
    for x, h, c in [(50, 13, "#ffb13b"), (64, 18, "#ff6b2b"), (78, 12, "#ffd36a")]:
        line(img, x, 75, x - 3, 75 - h, rgba(c), 3)
        line(img, x, 75, x + 4, 75 - h, rgba(c), 3)


def draw_fry(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#f0bd3f"))
    rect_outline(img, 31, 32, 66, 32, rgba("#4c4d45"), OUTLINE, 2)
    rect(img, 36, 37, 56, 10, rgba("#f3c847"))
    rect(img, 39, 50, 50, 9, rgba("#d68c2d"))
    for x in [46, 57, 70, 82]:
        line(img, x, 32, x + 5, 21, METAL_LIGHT, 2)
    ellipse_outline(img, 93, 25, 12, 8, rgba("#d0d8dc"), OUTLINE, 1)
    for x in range(87, 101, 4):
        line(img, x, 21, x, 29, OUTLINE, 1)


def draw_steam(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#96d0b0"))
    rect_outline(img, 33, 42, 62, 23, rgba("#c78f4d"), OUTLINE, 2)
    rect(img, 37, 47, 54, 4, rgba("#e1b46b"))
    rect(img, 37, 57, 54, 4, rgba("#9d6635"))
    ellipse_outline(img, 64, 38, 33, 10, rgba("#d8a45e"), OUTLINE, 2)
    for x in [48, 64, 80]:
        line(img, x, 34, x - 3, 24, rgba("#dff5ee", 210), 2)
        line(img, x - 3, 24, x + 2, 16, rgba("#dff5ee", 170), 2)


def draw_boil(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#5caeea"))
    rect_outline(img, 36, 29, 56, 37, rgba("#56616b"), OUTLINE, 2)
    ellipse_outline(img, 64, 30, 32, 11, rgba("#39414b"), OUTLINE, 2)
    ellipse(img, 64, 31, 25, 7, rgba("#59bde9"))
    for x in [54, 63, 73]:
        rect(img, x, 30, 4, 2, rgba("#baf0ff"))
        rect(img, x + 2, 37, 4, 2, rgba("#baf0ff"))
    rect(img, 43, 66, 42, 6, rgba("#ff7a35"))


def draw_bake(img: list[list[Color]]) -> None:
    draw_base(img, rgba("#d35a3c"))
    rect_outline(img, 31, 39, 66, 24, rgba("#4b4650"), OUTLINE, 2)
    rect(img, 36, 53, 56, 6, rgba("#211716"))
    for x in [40, 48, 56, 64, 72, 80, 88]:
        line(img, x, 37, x, 63, METAL_LIGHT, 2)
    for y in [43, 50, 57]:
        line(img, 34, y, 94, y, METAL, 2)
    for x, h, c in [(47, 8, "#ff8a32"), (61, 11, "#ffd66a"), (75, 8, "#ff5a2e")]:
        line(img, x, 59, x - 3, 59 - h, rgba(c), 3)
        line(img, x, 59, x + 4, 59 - h, rgba(c), 3)
    line(img, 41, 34, 89, 49, rgba("#7b3f24"), 4)
    line(img, 40, 33, 88, 48, OUTLINE, 1)
    for x, y in [(49, 36), (61, 40), (73, 44)]:
        rect_outline(img, x, y, 9, 7, rgba("#d09042"), OUTLINE, 1)


def write_png(path: Path, low_img: list[list[Color]]) -> None:
    rows = []
    for y in range(OUT_SIZE):
        low_y = y // SCALE
        row = bytearray([0])
        for x in range(OUT_SIZE):
            row.extend(low_img[low_y][x // SCALE])
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", OUT_SIZE, OUT_SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    out_dir = Path("ArtResource/Cooker")
    out_dir.mkdir(parents=True, exist_ok=True)
    drawers = {
        "temp_cut_station.png": draw_cut,
        "temp_stir_station.png": draw_stir,
        "temp_fry_station.png": draw_fry,
        "temp_steam_station.png": draw_steam,
        "temp_boil_station.png": draw_boil,
        "temp_bake_station.png": draw_bake,
    }
    for filename, drawer in drawers.items():
        img = make_canvas()
        drawer(img)
        write_png(out_dir / filename, img)
        print(out_dir / filename)


if __name__ == "__main__":
    main()
