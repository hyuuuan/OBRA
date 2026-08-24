#!/usr/bin/env python3
"""Build the OBRA bitmap font from the glyph table in font_glyphs.py.

    python3 tools/build_font.py

Writes game/ui/obra_font.png (the atlas) and game/ui/obra_font.fnt (BMFont text format,
which Godot imports as a FontFile with no further wiring). Both are GENERATED -- edit
tools/font_glyphs.py and re-run, never the outputs.

BMFont rather than poking FontFile's glyph-cache API from a Godot tool script: the cache
API wants a char-to-glyph-index mapping that only a real font file has, whereas .fnt is a
documented interchange format Godot reads directly. It is also inspectable in a text editor
when something looks wrong.

PROPORTIONAL, NOT MONOSPACE. Every glyph is trimmed to its own inked width and advances by
that plus one, so 'i' takes three pixels and 'W' takes six and prose has a rhythm. The
digits are the exception: they are forced to a common advance, because the ink readout
counts down while you draw and a proportional '1' makes the whole number jump sideways.
"""

import sys, pathlib, struct, zlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from font_glyphs import G, CELL_W, CELL_H, BASELINE

OUT = pathlib.Path(__file__).resolve().parent.parent / "game" / "ui"
COLUMNS = 16
## One transparent pixel between cells, so a glyph never samples its neighbour when the
## font is scaled up.
PAD = 1


def rows_of(spec):
    return spec.split()


def inked_span(rows):
    """Leftmost and rightmost inked column, or None for a blank glyph."""
    cols = [x for x in range(CELL_W) if any(r[x] == "#" for r in rows)]
    return (cols[0], cols[-1]) if cols else None


def build():
    order = list(G.keys())
    cell_w, cell_h = CELL_W + PAD, CELL_H + PAD
    width = COLUMNS * cell_w
    height = ((len(order) + COLUMNS - 1) // COLUMNS) * cell_h

    # RGBA, white ink so the engine can tint it to any colour in the palette.
    px = bytearray(width * height * 4)
    chars = []

    for index, ch in enumerate(order):
        rows = rows_of(G[ch])
        span = inked_span(rows)
        gx = (index % COLUMNS) * cell_w
        gy = (index // COLUMNS) * cell_h

        if span is None:
            # Space, and anything else that draws nothing. A quarter-em gap.
            chars.append((ch, gx, gy, 0, 0, 0, 4))
            continue

        left, right = span
        w = right - left + 1
        for y, row in enumerate(rows):
            for x in range(left, right + 1):
                if row[x] != "#":
                    continue
                off = ((gy + y) * width + gx + (x - left)) * 4
                px[off:off + 4] = b"\xff\xff\xff\xff"
        advance = w + 1
        if ch.isdigit():
            # Fixed, so a counting number does not shuffle its own digits sideways.
            advance = CELL_W + 1
        chars.append((ch, gx, gy, w, CELL_H, 0, advance))

    _write_png(OUT / "obra_font.png", width, height, px)
    _write_fnt(OUT / "obra_font.fnt", width, height, chars)
    print("wrote %s (%dx%d, %d glyphs)" % (OUT / "obra_font.png", width, height, len(chars)))


def _write_png(path, width, height, px):
    raw = b"".join(
        b"\x00" + bytes(px[y * width * 4:(y + 1) * width * 4]) for y in range(height)
    )

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _write_fnt(path, width, height, chars):
    lines = [
        'info face="OBRA" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100'
        ' smooth=0 aa=1 padding=0,0,0,0 spacing=0,0' % CELL_H,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (CELL_H + 2, BASELINE, width, height),
        'page id=0 file="obra_font.png"',
        "chars count=%d" % len(chars),
    ]
    for ch, x, y, w, h, yoff, adv in chars:
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d"
            " xadvance=%d page=0 chnl=15" % (ord(ch), x, y, w, h, yoff, adv)
        )
    path.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    build()
