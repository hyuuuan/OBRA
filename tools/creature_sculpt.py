#!/usr/bin/env python3
"""A small sculpting renderer for Dilim's creatures, in the delivered art's idiom.

WHY
---
The first creatures were flat shapes on a 2-px grain; the delivered art (the apo, Lolo, the
bakunawa) is drawn at one art pixel to one screen pixel, with five or six tones a material, light
from the upper left, and a SELECTIVE outline -- each part edged in a darker tone of its own colour,
never black. This draws creatures that way from shaped parts, so a pose is a set of numbers and an
animation is a few poses, and every frame is shaded and outlined the same.

HOW
---
A `Sculpt` holds a material buffer and a normal buffer. Parts are painted back to front:
`ellipse`, `capsule` (a limb: two circles and the hull between them), `poly`. Each writes its
material and a pseudo-normal (a sphere's or a cylinder's) into the pixels it covers. `render`
lights every pixel against LIGHT, picks the tone from the material's ramp with a little ordered
dither between tones, then outlines: a pixel at the silhouette takes its material's darkest tone,
and a pixel where two materials meet takes the darker of the two (`seam`). Details -- hair, fur,
membranes, eyes, teeth -- are drawn on top with `line`, `dot` and `glint` in named tones.
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image

LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexes(*codes: str) -> np.ndarray:
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in codes], dtype=np.uint8)


class Sculpt:
    def __init__(self, width: int, height: int) -> None:
        self.w, self.h = width, height
        self.mat = np.full((height, width), -1, dtype=np.int32)
        self.nrm = np.zeros((height, width, 3), dtype=np.float32)
        self.ramps: list[np.ndarray] = []
        self.names: dict[str, int] = {}
        self.over = np.zeros((height, width, 4), dtype=np.uint8)
        self.ys, self.xs = np.mgrid[0:height, 0:width]

    def material(self, name: str, ramp: np.ndarray) -> None:
        self.names[name] = len(self.ramps)
        self.ramps.append(ramp)

    def _paint(self, mask: np.ndarray, name: str, nx: np.ndarray, ny: np.ndarray) -> None:
        nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
        self.mat[mask] = self.names[name]
        self.nrm[mask] = np.stack([nx[mask], ny[mask], nz[mask]], axis=-1)

    def ellipse(self, name: str, cx: float, cy: float, rx: float, ry: float, flat: float = 0.0) -> None:
        dx = (self.xs + 0.5 - cx) / max(rx, 0.5)
        dy = (self.ys + 0.5 - cy) / max(ry, 0.5)
        mask = dx * dx + dy * dy <= 1.0
        k = 1.0 - flat
        self._paint(mask, name, dx * k, dy * k)

    def capsule(self, name: str, p0: tuple[float, float], p1: tuple[float, float], r0: float, r1: float) -> None:
        ax, ay = p0
        bx, by = p1
        vx, vy = bx - ax, by - ay
        length2 = max(vx * vx + vy * vy, 1e-6)
        px = self.xs + 0.5 - ax
        py = self.ys + 0.5 - ay
        t = np.clip((px * vx + py * vy) / length2, 0.0, 1.0)
        cx = ax + t * vx
        cy = ay + t * vy
        r = r0 + (r1 - r0) * t
        ox = self.xs + 0.5 - cx
        oy = self.ys + 0.5 - cy
        d = np.sqrt(ox * ox + oy * oy)
        mask = d <= r
        rr = np.maximum(r, 0.5)
        self._paint(mask, name, ox / rr, oy / rr)

    def poly(self, name: str, points: list[tuple[float, float]], bulge: float = 0.35) -> None:
        # Even-odd fill, every pixel centre against every edge at once.
        px = self.xs + 0.5
        py = self.ys + 0.5
        inside = np.zeros((self.h, self.w), dtype=bool)
        for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]):
            crosses = ((y0 > py) != (y1 > py)) & (px < (x1 - x0) * (py - y0) / ((y1 - y0) or 1e-9) + x0)
            inside ^= crosses
        cx = sum(p[0] for p in points) / len(points)
        cy = sum(p[1] for p in points) / len(points)
        span = max(max(abs(p[0] - cx) for p in points), max(abs(p[1] - cy) for p in points), 1.0)
        self._paint(inside, name, (px - cx) / span * bulge, (py - cy) / span * bulge)

    # --- details, drawn over the lit body ---

    def tone(self, name: str, index: int) -> np.ndarray:
        ramp = self.ramps[self.names[name]]
        return ramp[max(0, min(len(ramp) - 1, index))]

    def dot(self, x: float, y: float, colour: np.ndarray, alpha: int = 255) -> None:
        ix, iy = int(round(x)), int(round(y))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            self.over[iy, ix, :3] = colour
            self.over[iy, ix, 3] = alpha

    def line(self, p0: tuple[float, float], p1: tuple[float, float], colour: np.ndarray, only_on_body: bool = False) -> None:
        steps = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
        for i in range(steps + 1):
            t = i / max(steps, 1)
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t
            ix, iy = int(round(x)), int(round(y))
            if only_on_body and not (0 <= ix < self.w and 0 <= iy < self.h and self.mat[iy, ix] >= 0):
                continue
            self.dot(x, y, colour)

    def curve(self, points: list[tuple[float, float]], colour: np.ndarray, only_on_body: bool = False) -> None:
        for a, b in zip(points, points[1:]):
            self.line(a, b, colour, only_on_body)

    def render(self, outline: bool = True, seam: bool = True, cel: bool = True) -> Image.Image:
        """Lit, toned and outlined. `cel` (the game's own way, and the default): flat bands -- a
        deep shadow, a shadow, the base and a light -- with hard edges and no dither, and the seams
        between parts in the outline's tone, as the delivered art draws them."""
        out = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        lit = np.clip((self.nrm @ LIGHT) * 0.5 + 0.5, 0.0, 1.0)
        body = self.mat >= 0
        for index, ramp in enumerate(self.ramps):
            m = self.mat == index
            if not m.any():
                continue
            n = len(ramp)
            if cel:
                # Four flat bands at most, the darkest tone kept for the outline.
                # A part facing the viewer lands in the base band; only what turns toward the
                # upper-left light catches the light band and the small highlight.
                idx = np.where(lit > 0.90, n - 1, np.where(lit > 0.80, n - 2,
                    np.where(lit > 0.58, max(1, n - 3), max(1, n - 4)))).astype(int)
            else:
                # Interior tones skip the darkest, which is the outline's.
                level = lit * (n - 1.15) + 1.0
                dither = BAYER4[self.ys % 4, self.xs % 4] - 0.5
                idx = np.clip(np.floor(level + dither * 0.55), 1, n - 1).astype(int)
            out[m, :3] = ramp[idx[m]]
            out[m, 3] = 255
        if outline:
            pad = np.pad(body, 1, constant_values=False)
            edge = body & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
            for index, ramp in enumerate(self.ramps):
                m = edge & (self.mat == index)
                out[m, :3] = ramp[0]
        if seam:
            mat = self.mat
            down = np.zeros_like(body)
            right = np.zeros_like(body)
            down[:-1] = (mat[:-1] != mat[1:]) & (mat[:-1] >= 0) & (mat[1:] >= 0)
            right[:, :-1] = (mat[:, :-1] != mat[:, 1:]) & (mat[:, :-1] >= 0) & (mat[:, 1:] >= 0)
            for m in (down, right):
                ys, xs = np.nonzero(m)
                for y, x in zip(ys, xs):
                    # The seam goes on the part in front -- the one drawn later has the higher id
                    # only by chance, so take the darker of the pair's darkest tones, at 1.
                    a, b = mat[y, x], (mat[y + 1, x] if m is down else mat[y, x + 1])
                    ra, rb = self.ramps[a], self.ramps[b]
                    tone = 0 if cel else 1
                    pick = ra[tone] if ra[tone].sum() < rb[tone].sum() else rb[tone]
                    out[y, x, :3] = pick
        top = self.over[..., 3] > 0
        out[top] = self.over[top]
        return Image.fromarray(out, "RGBA")


def strip(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    return sheet


def rot(p: tuple[float, float], origin: tuple[float, float], degrees: float) -> tuple[float, float]:
    a = math.radians(degrees)
    x, y = p[0] - origin[0], p[1] - origin[1]
    return (origin[0] + x * math.cos(a) - y * math.sin(a), origin[1] + x * math.sin(a) + y * math.cos(a))
