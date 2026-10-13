"""Paint the look-dev's small hand-made textures (original art, drawn in code; ships under the repo licence).

    python -I lookdev/tools/paint_textures.py [out_dir]     (default lookdev/assets/textures/)

  maple_leaves.png   leaf-card atlas for the red-maple landmark (cel 3-tone maple leaves, wine outline)
  banner_blue.png    team banner cloth: field, gold double trim, swallow-tail cut, original lance-and-wing crest
  banner_red.png
  fire_tongue.png    additive flame tongue sprite (white core -> yellow -> orange -> red edge)
Reuses the icon painter's vector + cel primitives so the 2D and 3D art share one rendering language.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon_painter as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgba(cv, alpha):
    rgb = np.clip(P.tonemap(cv.c), 0, 1)
    a = np.clip(alpha, 0, 1)[..., None]
    return Image.fromarray((np.concatenate([rgb, a], 2) * 255 + 0.5).astype(np.uint8), "RGBA")


def maple_leaf(cx, cy, r, ang):
    """5-lobed maple leaf outline (pointed lobes, serrated tips)"""
    pts = []
    lobes = [(-90, 1.0), (-38, 0.86), (-142, 0.86), (12, 0.55), (-192, 0.55)]
    lobes.sort()
    a0 = math.radians(ang)
    for i, (la, lr) in enumerate(lobes):
        a = math.radians(la)
        # notch between lobes
        prev = math.radians(lobes[i - 1][0]) if i else math.radians(lobes[-1][0] - 360)
        mid = (prev + a) / 2
        pts.append((math.cos(mid) * r * 0.32, math.sin(mid) * r * 0.32))
        for k, (da, rr) in enumerate(((-14, 0.62), (-6, 0.8), (0, 1.0), (6, 0.8), (14, 0.62))):
            aa = a + math.radians(da)
            pts.append((math.cos(aa) * r * lr * rr, math.sin(aa) * r * lr * rr))
    # stem
    pts.append((math.cos(math.radians(85)) * r * 0.25, math.sin(math.radians(85)) * r * 0.25))
    pts.append((math.cos(math.radians(90)) * r * 0.7, math.sin(math.radians(90)) * r * 0.7))
    pts.append((math.cos(math.radians(95)) * r * 0.25, math.sin(math.radians(95)) * r * 0.25))
    ca, sa = math.cos(a0), math.sin(a0)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def paint_maple(out):
    n = 256
    cv = P.Canvas(n)
    cv.c[:] = P.hexc("#5A0A18")
    alpha = np.zeros((cv.w, cv.w), np.float32)
    rng = np.random.default_rng(11)
    tones = [("#E0283A", "#8E1030", "#FF8A6A"), ("#F04A2E", "#9E2030", "#FFB080"), ("#C81E3A", "#6E0A2A", "#FF7A80")]
    leaves = []
    for i in range(30):
        a = rng.uniform(0, math.tau)
        d = math.sqrt(rng.uniform(0, 1)) * n * 0.36
        leaves.append((n / 2 + math.cos(a) * d, n / 2 + math.sin(a) * d * 0.9, rng.uniform(22, 36), rng.uniform(0, 360), i % 3))
    leaves.sort(key=lambda l: -abs(l[1] - n / 2))
    for x, y, r, ang, t in leaves:
        m = cv.poly(maple_leaf(x, y, r, ang))
        base, shade, rim = tones[t]
        P.cel(cv, m, base, shade, rim=rim, line="#3A0612", lw=1.2, ks=r * 0.35, kr=1.2)
        vein = cv.poly(P.ribbon([(x, y), (x + math.cos(math.radians(ang - 90)) * r * 0.8, y + math.sin(math.radians(ang - 90)) * r * 0.8)], [1.4, 0.3]))
        cv.paint(vein * m, P.hexc(shade), 0.8)
        alpha = np.maximum(alpha, P.dilate(m, 1.2))
    rgba(cv, alpha).resize((512, 512), Image.LANCZOS).save(os.path.join(out, "maple_leaves.png"))


def crest(cv, cx, cy, s):
    """original team crest: a vertical lance between two swept wings over a ring (gold)"""
    m = cv.ellipse(cx, cy + s * 0.05, s * 0.42)
    m = np.clip(m - cv.ellipse(cx, cy + s * 0.05, s * 0.32), 0, 1)
    for sgn in (-1, 1):
        wing = [(cx + sgn * s * 0.06, cy - s * 0.05)]
        for k in range(5):
            t = k / 4
            wing.append((cx + sgn * s * (0.3 + 0.55 * t), cy - s * (0.55 - 0.35 * t) + (k % 2) * s * 0.12))
        wing.append((cx + sgn * s * 0.2, cy + s * 0.25))
        m = np.maximum(m, cv.poly(wing))
    H = P.lance_H((cx, cy + s * 0.95), (cx, cy - s * 1.0), 1.4)
    lm = P.draw_lance(cv, H, "gold")
    return m, lm


def paint_banner(out, name, field, field_dark):
    w, h = 128, 512
    cv = P.Canvas(h)  # square canvas, crop the strip
    X, Y = cv.grid()
    x0 = (h - w) / 2
    cv.c[:] = P.hexc(field)
    # painted cloth folds: vertical value bands
    fold = (np.sin((X - x0) / w * math.tau * 2.0 + Y / h * 1.5) * 0.5 + 0.5)
    q = np.floor(fold * 3) / 3
    cv.c = cv.c * (0.8 + 0.25 * q)[..., None]
    cv.c = np.where((Y > h * 0.9)[..., None], cv.c * 0.9, cv.c)
    # swallow-tail cut
    tail = cv.poly([(x0 - 2, h * 0.86), (x0 + w / 2, h * 0.76), (x0 + w + 2, h * 0.86), (x0 + w + 2, h + 2), (x0 - 2, h + 2)])
    keep = 1 - np.clip(tail - cv.poly([(x0 - 2, h * 0.86), (x0 - 2, h + 2), (x0 + w * 0.42, h + 2)]) - cv.poly([(x0 + w + 2, h * 0.86), (x0 + w + 2, h + 2), (x0 + w * 0.58, h + 2)]), 0, 1)
    strip = ((X > x0) & (X < x0 + w)).astype(np.float32)
    alpha = keep * strip
    # gold double trim following the outline
    inner = (P.blur(alpha, 3.5) > 0.98).astype(np.float32)
    trim = np.clip(alpha - inner, 0, 1)
    inner2 = (P.blur(alpha, 7.5) > 0.985).astype(np.float32)
    trim2 = np.clip(inner2 - (P.blur(alpha, 9.0) > 0.99).astype(np.float32), 0, 1)
    cv.paint(trim, P.hexc("#D8B25A"))
    cv.paint(trim * (1 - P.toward(trim, 1.0, -P.LIGHT)), P.hexc("#FFE9A8"))
    cv.paint(trim2, P.hexc("#D8B25A"))
    # crest
    m, _ = crest(cv, h / 2, h * 0.36, w * 0.55)
    P.cel(cv, m, "#D8B25A", "#8A5A2B", rim="#FFE9A8", line=field_dark, lw=1.4, ks=4)
    # flame/cloud filigree band under the crest
    for k in range(5):
        cx = x0 + w * (0.1 + 0.2 * k)
        fl = cv.poly([(cx - 9, h * 0.66), (cx, h * 0.60), (cx + 9, h * 0.66), (cx + 3, h * 0.64), (cx, h * 0.67), (cx - 3, h * 0.64)])
        cv.paint(fl, P.hexc("#D8B25A"))
    img = rgba(cv, alpha).resize((h, h), Image.LANCZOS).crop((int(x0), 0, int(x0 + w), h))
    img.save(os.path.join(out, name))


def paint_fire(out):
    n = 128
    cv = P.Canvas(n)
    cv.c[:] = 0
    shapes = [
        ([(64, 4), (78, 36), (96, 30), (100, 70), (108, 96), (90, 124), (38, 124), (20, 96), (28, 60), (40, 40), (48, 58)], "#C81E1A", 1.0),
        ([(66, 34), (80, 60), (86, 88), (76, 116), (50, 116), (40, 92), (52, 66), (58, 80)], "#FF7A1A", 1.0),
        ([(66, 66), (76, 88), (70, 112), (56, 112), (54, 92)], "#FFE45A", 1.0),
        ([(64, 86), (70, 100), (66, 110), (58, 110), (58, 98)], "#FFFFFF", 1.0),
    ]
    alpha = np.zeros((cv.w, cv.w), np.float32)
    for pts, col, k in shapes:
        m = cv.poly(P.spline(pts + [pts[0]], 4))
        cv.paint(m, P.hexc(col))
        alpha = np.maximum(alpha, m)
    # additive sprite: premultiply-ish, keep the alpha as a soft mask
    rgba(cv, P.blur(alpha, 0.8)).resize((n, n), Image.LANCZOS).save(os.path.join(out, "fire_tongue.png"))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "textures")
    os.makedirs(out, exist_ok=True)
    paint_maple(out)
    paint_banner(out, "banner_blue.png", "#1F4FBF", "#0A1A4A")
    paint_banner(out, "banner_red.png", "#C8202A", "#3A0612")
    paint_fire(out)
    print("textures ->", out)


if __name__ == "__main__":
    main()
