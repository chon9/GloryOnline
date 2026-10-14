"""Paint the environment leaf-card atlases (original art, drawn in code; ships under the repo licence).

    python -I assets/env/painted/paint_env_textures.py [out_dir]     (default: this folder)

  leaves_blossom.png  peach / cherry blossom clusters (Hundred Blossoms valley)
  leaves_green.png    lanceolate leaves, lit green -> teal core (generic broadleaf / willow)
  leaves_gold.png     amber-gold fan leaves (golden-hour castle ruins)
  leaves_violet.png   dusky violet leaves (moonlit graveyard)
Style matches lookdev maple_leaves.png: 3-tone cel leaves (shade, base, rim) with a dark tinted outline, alpha cut-out.
maple_leaves.png and banner_*.png are copies of the look-dev textures (lookdev/tools/paint_textures.py).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 256
SS = 3
W = N * SS


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def mask(pts):
    img = Image.new("L", (W, W), 0)
    ImageDraw.Draw(img).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return np.asarray(img, np.float32) / 255.0


def dilate(m, r):
    img = Image.fromarray((m * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MaxFilter(int(r * SS) * 2 + 1))
    return np.asarray(img, np.float32) / 255.0


def shift(m, dx, dy):
    o = np.zeros_like(m)
    dx, dy = int(dx * SS), int(dy * SS)
    ys = slice(max(dy, 0), W + min(dy, 0))
    yd = slice(max(-dy, 0), W + min(-dy, 0))
    xs = slice(max(dx, 0), W + min(dx, 0))
    xd = slice(max(-dx, 0), W + min(-dx, 0))
    o[ys, xs] = m[yd, xd]
    return o


def leaf_shape(cx, cy, r, ang, kind):
    pts = []
    if kind == "lance":
        for i in range(24):
            t = i / 23.0
            pts.append((t * 2 - 1, math.sin(t * math.pi) * 0.32))
        for i in range(24):
            t = 1 - i / 23.0
            pts.append((t * 2 - 1, -math.sin(t * math.pi) * 0.32 * (0.85 + 0.15 * t)))
    elif kind == "fan":   # ginkgo-like fan with a notch
        pts.append((-1.0, 0.0))
        for i in range(25):
            a = -1.0 + 2.0 * i / 24.0
            rr = 1.0 - 0.18 * math.exp(-(a * 6) ** 2)
            pts.append((-1.0 + 1.9 * rr * math.cos(a), 1.9 * rr * math.sin(a) * 0.62))
    elif kind == "petal":
        for i in range(40):
            u = i / 39.0 * math.tau
            s = (1 - math.cos(u)) / 2
            x = s * 2 - 1
            y = 0.62 * math.sin(u) * s ** 0.6
            if s > 0.92:
                x -= 0.12 * math.exp(-(y / 0.08) ** 2)
            pts.append((x, y))
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return [(cx + (x * ca - y * sa) * r, cy + (x * sa + y * ca) * r) for x, y in pts]


class Painter:
    def __init__(self, line):
        self.c = np.zeros((W, W, 3), np.float32)
        self.c[:] = hexc(line)
        self.a = np.zeros((W, W), np.float32)
        self.line = hexc(line)

    def put(self, m, base, shade, rim, lw=1.2, split_ang=None):
        """cel fill: lower-right half in shade, top-left rim, outline around the shape"""
        out = dilate(m, lw)
        k = out[..., None]
        self.c = self.c * (1 - k) + self.line * k
        self.a = np.maximum(self.a, out)
        lit = m * (1 - shift(m, -3.0, -3.0))     # pixels whose up-left neighbour is outside = rim side
        sh = m * (1 - shift(m, 4.0, 4.0))
        fill = m[..., None]
        self.c = self.c * (1 - fill) + hexc(base) * fill
        if split_ang is not None:
            ys, xs = np.nonzero(m > 0.5)
            if len(xs):
                cx, cy = xs.mean(), ys.mean()
                X, Y = np.meshgrid(np.arange(W), np.arange(W))
                d = (X - cx) * math.cos(split_ang) + (Y - cy) * math.sin(split_ang)
                half = (d > 0).astype(np.float32) * m
                self.c = self.c * (1 - half[..., None] * 0.85) + hexc(shade) * (half[..., None] * 0.85)
        s2 = np.clip(sh - lit, 0, 1)[..., None]
        self.c = self.c * (1 - s2) + hexc(shade) * s2
        r2 = np.clip(lit, 0, 1)[..., None] * 0.9
        self.c = self.c * (1 - r2) + hexc(rim) * r2

    def save(self, path):
        rgb = np.clip(self.c, 0, 1)
        img = np.concatenate([rgb, self.a[..., None]], 2)
        Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").resize((512, 512), Image.LANCZOS).save(path)


def scatter(rng, count, rmin, rmax):
    out = []
    for i in range(count):
        a = rng.uniform(0, math.tau)
        d = math.sqrt(rng.uniform(0, 1)) * N * 0.37
        out.append((N / 2 + math.cos(a) * d, N / 2 + math.sin(a) * d * 0.9, rng.uniform(rmin, rmax), rng.uniform(0, 360), i % 3))
    out.sort(key=lambda l: -abs(l[1] - N / 2))
    return out


def paint_leaves(path, kind, tones, line, count, rmin, rmax, seed):
    rng = np.random.default_rng(seed)
    p = Painter(line)
    for x, y, r, ang, t in scatter(rng, count, rmin, rmax):
        base, shade, rim = tones[t]
        p.put(mask(leaf_shape(x, y, r, ang, kind)), base, shade, rim, 1.1, math.radians(ang + 90))
    p.save(path)


def paint_blossom(path, seed):
    rng = np.random.default_rng(seed)
    p = Painter("#7A1E3E")
    tones = [("#FFC2D6", "#E07AA6", "#FFF2F6"), ("#FFD6E2", "#E890B4", "#FFFFFF"), ("#F7A8C6", "#C85C90", "#FFE6EE")]
    flowers = scatter(rng, 44, 12, 18)
    # a few green-bronze leaves under the flowers
    for x, y, r, ang, t in flowers[::3]:
        p.put(mask(leaf_shape(x + r * 0.8, y + r * 0.5, r * 0.75, ang, "lance")), "#7DA05A", "#3E6A50", "#B8D890", 1.0, math.radians(ang + 90))
    for x, y, r, ang, t in flowers:
        base, shade, rim = tones[t]
        for k in range(5):
            a = ang + k * 72
            cx = x + math.cos(math.radians(a)) * r * 0.5
            cy = y + math.sin(math.radians(a)) * r * 0.5
            p.put(mask(leaf_shape(cx, cy, r * 0.52, a, "petal")), base, shade, rim, 0.9, math.radians(a + 140))
        ctr = Image.new("L", (W, W), 0)
        ImageDraw.Draw(ctr).ellipse([(x - r * 0.18) * SS, (y - r * 0.18) * SS, (x + r * 0.18) * SS, (y + r * 0.18) * SS], fill=255)
        m = np.asarray(ctr, np.float32) / 255.0
        p.c = p.c * (1 - m[..., None]) + hexc("#FFD24A") * m[..., None]
    p.save(path)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out, exist_ok=True)
    paint_blossom(os.path.join(out, "leaves_blossom.png"), 5)
    paint_leaves(os.path.join(out, "leaves_green.png"), "lance",
                 [("#8CC56A", "#2E6A5A", "#D8F0A0"), ("#6FAE5C", "#245A4E", "#C4E890"), ("#A6D070", "#3A7458", "#E8F8B0")],
                 "#173A34", 46, 16, 26, 7)
    paint_leaves(os.path.join(out, "leaves_gold.png"), "fan",
                 [("#F0B048", "#A8582A", "#FFE6A0"), ("#E89A3A", "#94442A", "#FFD890"), ("#F6C860", "#B06A2E", "#FFF2C0")],
                 "#4A1E10", 34, 14, 22, 9)
    paint_leaves(os.path.join(out, "leaves_violet.png"), "lance",
                 [("#7A5AB8", "#3B2E7A", "#B8A0F0"), ("#6A4AA8", "#2E2468", "#A890E8"), ("#8A6AC8", "#44348A", "#C8B4FF")],
                 "#1A1238", 40, 14, 24, 13)
    print("env textures ->", out)


if __name__ == "__main__":
    main()
