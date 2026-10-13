"""ICON PAINTER v2 - offline skill / status icon renderer for the RONGYAO look-dev (Art Bible v1 section 7,
lookdev/ICON_STYLE.md v2).

Everything drawn here is original art authored in code. No third-party silhouettes are used.

    python -I lookdev/tools/icon_painter.py [spec.json] [out_dir] [qa_sheet.png] [only_ids,comma,separated]

Defaults: lookdev/assets/icons/icons.json -> lookdev/assets/icons/out/

v2 = PAINTED rendering (art-director pass 4). The v1 look was flat 2-tone fills with one uniform outline width,
which reads as vector clip-art. v2 replaces the rendering core:

  * ink_line()    tapered, varying line weight from a distance field: thick on the shadow side (bottom-right),
                  thin and BROKEN on the lit side, coloured per material (never black).
  * paint_form()  3-5 value form shading from pseudo-normals (a bevel built from the inner distance field), band
                  edges wobbled by low-frequency noise like brush edges, a value gradient across the form, and
                  per-material specular: lacquer gets hard gloss hotspots, gold a warm-to-white highlight,
                  steel a sharp streak.
  * material()    named materials (lacquer, gold, steel, darksteel, leather, cloth, bone, petal, stone) +
                  brushed-metal streaks along a direction.
  * soft_light()  light shapes with a feathered painted falloff (no hard edge) and a white-hot interior.
  * brush_wash()  low-contrast directional brush strokes on the ground (painted backdrop, not grain).

The GENERATOR owns grounds, frames, badges, lighting rules and QA. SUBJECTS are per-skill `comp_*` functions.
Add a class: one CLASS_KEYS entry + its weapon asset + one comp per skill; frames/grounds/QA are reused.
Supersampled 4x, downsampled with Lanczos.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SS = 4
LIGHT = np.array([-0.55, -0.83])  # direction TOWARD the key light (top-left), icon space, y down
LIGHT2 = LIGHT / np.linalg.norm(LIGHT)
L3 = np.array([-0.55, -0.83, 0.85])
L3 = L3 / np.linalg.norm(L3)


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], np.float32) / 255.0 * a


def col(c):
    return hexc(c) if isinstance(c, str) else np.asarray(c, np.float32)


def mix(a, b, t):
    a, b = col(a), col(b)
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ noise (low frequency only: brush, not grain)
def lowfreq(w, cells, seed):
    rng = np.random.default_rng(seed)
    a = rng.random((cells, cells)).astype(np.float32)
    return np.asarray(Image.fromarray(a, "F").resize((w, w), Image.BICUBIC), np.float32)


def streak_field(w, ang_deg, across, along, seed):
    """anisotropic brush / brushed-metal streaks running along ang_deg (icon space, y down). 0..1"""
    big = int(w * 1.5)
    rng = np.random.default_rng(seed)
    a = rng.random((across, along)).astype(np.float32)
    img = Image.fromarray(a, "F").resize((big, big), Image.BICUBIC).rotate(-ang_deg, Image.BICUBIC)
    o = (big - w) // 2
    f = np.asarray(img, np.float32)[o:o + w, o:o + w]
    return np.clip((f - 0.5) * 1.6 + 0.5, 0, 1)


# ------------------------------------------------------------------ canvas
class Canvas:
    def __init__(self, n, seed=0):
        self.n = n
        self.w = n * SS
        self.c = np.zeros((self.w, self.w, 3), np.float32)
        self.noise = lowfreq(self.w, 22, seed + 11)
        self.noise2 = lowfreq(self.w, 64, seed + 12)
        self._seed = seed

    def poly(self, pts):
        img = Image.new("L", (self.w, self.w), 0)
        if len(pts) >= 3:
            ImageDraw.Draw(img).polygon([(float(x) * SS, float(y) * SS) for x, y in pts], fill=255)
        return np.asarray(img, np.float32) / 255.0

    def ellipse(self, cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        img = Image.new("L", (self.w, self.w), 0)
        ImageDraw.Draw(img).ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)
        return np.asarray(img, np.float32) / 255.0

    def grid(self):
        v = (np.arange(self.w, dtype=np.float32) + 0.5) / SS
        return np.meshgrid(v, v)  # X, Y in icon units

    def paint(self, m, c, a=1.0):
        k = (m * a)[..., None]
        self.c = self.c * (1.0 - k) + col(c) * k

    def add(self, m, c, k=1.0):
        self.c = self.c + m[..., None] * col(c) * k

    def seed(self):
        self._seed += 1
        return self._seed


def tonemap(c):
    # hot additive light: overflow bleeds to white, then a soft shoulder
    over = np.clip(c.max(axis=2, keepdims=True) - 1.0, 0, None)
    c = c + over * 0.85
    knee = 0.82
    return np.where(c < knee, c, knee + (1 - knee) * (1 - np.exp(-(c - knee) / (1 - knee))))


# ------------------------------------------------------------------ mask ops
def _box(m, r, axis):
    p = [(0, 0), (0, 0)]
    p[axis] = (r + 1, r)
    a = np.pad(m, p, mode="edge")
    cs = np.cumsum(a, axis=axis, dtype=np.float64)
    if axis == 0:
        o = cs[2 * r + 1:, :] - cs[:-2 * r - 1, :]
    else:
        o = cs[:, 2 * r + 1:] - cs[:, :-2 * r - 1]
    return (o / (2 * r + 1)).astype(np.float32)


def blur_px(m, r_px):
    r = max(1, int(r_px / 1.7))
    o = m
    for _ in range(3):
        o = _box(o, r, 0)
        o = _box(o, r, 1)
    return o


def blur(m, r_icon):
    return blur_px(m, r_icon * SS)


def shift(m, dx, dy):
    """out[y, x] = m[y - dy, x - dx]  (dx, dy in SS pixels, ints)"""
    o = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    o[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = m[ys0:ys1, xs0:xs1]
    return o


def toward(m, d_icon, direction):
    """mask value at p - direction*d. m*(1-toward(m,d,-LIGHT)) = lit edge, m*(1-toward(m,d,LIGHT)) = shadow side"""
    return shift(m, int(round(direction[0] * d_icon * SS)), int(round(direction[1] * d_icon * SS)))


def _sh(a, dy, dx, fill):
    o = np.full_like(a, fill)
    h, w = a.shape
    o[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = a[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
    return o


_STEPS = [(0, 1, 1.0), (0, -1, 1.0), (1, 0, 1.0), (-1, 0, 1.0), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]


def dist_out(m, maxd):
    """chamfer distance (SS px) from each pixel to the mask (m >= 0.5), capped at maxd; 0 inside"""
    INF = 1e4
    d = np.where(m >= 0.5, 0.0, INF).astype(np.float32)
    for _ in range(int(math.ceil(maxd)) + 1):
        for dy, dx, w in _STEPS:
            np.minimum(d, _sh(d, dy, dx, INF) + w, out=d)
    return np.minimum(d, maxd)


def bbox(m, pad):
    rows = np.nonzero(m.max(axis=1) > 0.01)[0]
    if not len(rows):
        return None
    cols = np.nonzero(m.max(axis=0) > 0.01)[0]
    H, W = m.shape
    return (slice(max(0, rows[0] - pad), min(H, rows[-1] + pad + 1)), slice(max(0, cols[0] - pad), min(W, cols[-1] + pad + 1)))


def dilate(m, r_icon):
    sl = bbox(m, int(r_icon * SS) + 3)
    o = np.zeros_like(m)
    if sl is None:
        return o
    d = dist_out(m[sl], r_icon * SS + 1)
    o[sl] = np.clip(r_icon * SS - d + 0.5, 0, 1)
    return np.maximum(o, m)


def _union(cv, parts):
    m = np.zeros((cv.w, cv.w), np.float32)
    for p in parts:
        np.maximum(m, p, out=m)
    return m


# ------------------------------------------------------------------ geometry helpers
def H_affine(pos, ang_deg, scale, sy=None):
    a = math.radians(ang_deg)
    sx = scale
    sy = scale if sy is None else sy
    c, s = math.cos(a), math.sin(a)
    return np.array([[c * sx, -s * sy, pos[0]], [s * sx, c * sy, pos[1]], [0, 0, 1]], np.float64)


def H_quad(src, dst):
    """homography mapping 4 src points to 4 dst points"""
    A, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    h = np.linalg.solve(np.array(A, np.float64), np.array(b, np.float64))
    return np.array([[h[0], h[1], h[2]], [h[3], h[4], h[5]], [h[6], h[7], 1.0]])


def xf(H, pts):
    p = np.asarray(pts, np.float64)
    q = np.c_[p, np.ones(len(p))] @ H.T
    return q[:, :2] / q[:, 2:3]


def hlen(H, p, v):
    """icon-space length of local vector v at local point p"""
    a = xf(H, [p, (p[0] + v[0], p[1] + v[1])])
    return float(np.linalg.norm(a[1] - a[0]))


def spline(pts, n=12):
    """Catmull-Rom densify"""
    p = np.asarray(pts, np.float64)
    if len(p) < 3:
        return p
    p = np.vstack([p[0] * 2 - p[1], p, p[-1] * 2 - p[-2]])
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(p[-2])
    return np.array(out)


def closed_spline(pts, n=8):
    p = np.asarray(pts, np.float64)
    q = np.vstack([p[-1], p, p[0], p[1]])
    out = []
    for i in range(1, len(q) - 2):
        p0, p1, p2, p3 = q[i - 1], q[i], q[i + 1], q[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    return np.array(out)


def ribbon(path, widths):
    """tapered stroke polygon around a polyline; widths = callable(t) or list matching path"""
    p = np.asarray(path, np.float64)
    n = len(p)
    if callable(widths):
        w = np.array([widths(i / (n - 1)) for i in range(n)])
    else:
        w = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(widths)), widths)
    d = np.gradient(p, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    nrm = np.c_[-d[:, 1], d[:, 0]]
    left = p + nrm * w[:, None] * 0.5
    right = p - nrm * w[:, None] * 0.5
    return np.vstack([left, right[::-1]])


def stroke(cv, pts, w0, w1, n=8, w_mid=None):
    """tapered spline stroke mask"""
    sp = spline(pts, n) if len(pts) > 2 else np.asarray(pts, float)
    if w_mid is None:
        return cv.poly(ribbon(sp, lambda t: w0 + (w1 - w0) * t))
    return cv.poly(ribbon(sp, lambda t: (w0 + (w_mid - w0) * t * 2) if t < 0.5 else (w_mid + (w1 - w_mid) * (t - 0.5) * 2)))


def arc_pts(cx, cy, r, a0, a1, n=48, ry=None):
    ry = r if ry is None else ry
    t = np.linspace(math.radians(a0), math.radians(a1), n)
    return np.c_[cx + np.cos(t) * r, cy + np.sin(t) * ry]


# ------------------------------------------------------------------ PAINTED RENDERING CORE
def ink_line(cv, m, line_col, thin=0.45, thick=2.2, brk=0.45, a=1.0):
    """tapered contour: `thick` icon units on the shadow side, `thin` on the lit side, broken in places on the lit
    side (like a brush lifting off). Coloured, never black."""
    maxd = thick * SS + 2
    sl = bbox(m, int(maxd) + 3)
    if sl is None:
        return
    mc = m[sl]
    d = dist_out(mc, maxd)
    db = blur_px(d, 3)
    gy, gx = np.gradient(db)
    nn = np.sqrt(gx * gx + gy * gy) + 1e-6
    side = np.clip(0.5 + 0.8 * (gx * -LIGHT2[0] + gy * -LIGHT2[1]) / nn, 0, 1)   # 1 = shadow side
    w = (thin + (thick - thin) * side ** 1.4) * SS
    al = np.clip(w - d + 0.5, 0, 1) * (d > 0)
    if brk:
        gate = smoothstep(0.42, 0.52, cv.noise2[sl])
        lit = smoothstep(0.35, 0.15, side)
        al = al * (1 - brk * lit * gate)
    k = (al * a)[..., None]
    cv.c[sl] = cv.c[sl] * (1 - k) + col(line_col) * k


def _normals(mc, R):
    """pseudo-normals of a mask crop: a circular bevel of radius R (SS px) built on the inner distance"""
    d = dist_out(1.0 - mc, R)
    t = np.clip(d / R, 0, 1)
    h = R * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1))
    h = blur_px(h, 2.0)
    gy, gx = np.gradient(h)
    inv = 1.0 / np.sqrt(gx * gx + gy * gy + 1.0)
    return -gx * inv, -gy * inv, inv, t


DEFAULT_THR = {2: [0.45], 3: [0.32, 0.74], 4: [0.20, 0.52, 0.82], 5: [0.12, 0.36, 0.62, 0.86]}


def paint_form(cv, m, ramp, R=4.0, thr=None, soft=0.05, tilt=(0.0, 0.0), grad=0.25, wobble=0.07, spec=(), alpha=1.0,
               light=None, field=None):
    """3+ value painted form: pseudo-normal shading quantised to the ramp with soft, brush-wobbled band edges,
    a value gradient across the form, optional specular layers [(colour, power, lo, hi, strength), ...]"""
    sl = bbox(m, 2)
    if sl is None:
        return None
    mc = m[sl]
    nx, ny, nz, t = _normals(mc, max(2.0, R * SS))
    if tilt[0] or tilt[1]:
        nx = nx + tilt[0] * nz
        ny = ny + tilt[1] * nz
        inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx * inv, ny * inv, nz * inv
    L = L3 if light is None else light
    ndl = nx * L[0] + ny * L[1] + nz * L[2]
    v = ndl.copy()
    if grad:
        ys = np.arange(sl[0].start, sl[0].stop, dtype=np.float32)
        xs = np.arange(sl[1].start, sl[1].stop, dtype=np.float32)
        X, Y = np.meshgrid(xs, ys)
        proj = X * LIGHT2[0] + Y * LIGHT2[1]
        pm = proj[mc > 0.5] if (mc > 0.5).any() else proj
        lo, hi = float(pm.min()), float(pm.max())
        v = v + grad * ((proj - lo) / (hi - lo + 1e-6) - 0.5)
    if wobble:
        v = v + wobble * (cv.noise[sl] - 0.5) * 2
    if field is not None:
        v = v + field[sl]
    rc = [col(c) for c in ramp]
    thr = thr or DEFAULT_THR[len(rc)]
    c = np.broadcast_to(rc[0], mc.shape + (3,)).copy()
    for i, th in enumerate(thr):
        s = smoothstep(th - soft, th + soft, v)[..., None]
        c = c + (rc[i + 1] - c) * s
    a = (mc * alpha)[..., None]
    cv.c[sl] = cv.c[sl] * (1 - a) + c * a
    if spec:
        refl = np.clip(2 * ndl * nz - L[2], 0, 1)
        for scol, power, lo_, hi_, k in spec:
            sp = refl ** power
            hot = smoothstep(lo_, hi_, sp + 0.08 * (cv.noise2[sl] - 0.5)) * mc * k
            cv.c[sl] = cv.c[sl] * (1 - hot[..., None]) + col(scol) * hot[..., None]
    return sl, ndl, t


MAT = {
    # ramp dark -> light, line colour, specular layers
    "lacquer": (["#040408", "#100F17", "#22202C", "#3E3B4C"], "#020104",
                [("#3A3A50", 3, 0.25, 0.75, 0.55), ("#E6ECFF", 26, 0.42, 0.55, 0.95)]),
    "gold": (["#3A1C08", "#8A5A2B", "#CC9A44", "#F0C870"], "#2A1406",
             [("#FFE3A0", 5, 0.30, 0.70, 0.75), ("#FFFDF4", 22, 0.40, 0.62, 1.0)]),
    "steel": (["#3A4256", "#7A849C", "#B8C2D4", "#E8EEF6"], "#121828",
              [("#FFFFFF", 18, 0.40, 0.60, 0.9)]),
    "darksteel": (["#08080C", "#17171F", "#2E2E3A", "#55556A"], "#030306",
                  [("#B8BED8", 14, 0.40, 0.62, 0.7)]),
    "plate": (["#141824", "#2C3446", "#525E78", "#8A96B0"], "#05060C",
              [("#DCE4FF", 10, 0.35, 0.6, 0.85)]),
    "leather": (["#120A0A", "#24171A", "#3E2A2C", "#5E4442"], "#050203", []),
    "cloth_red": (["#3A0612", "#7A0F2E", "#C2202C", "#EE5452"], "#2A040A", []),
    "bone": (["#5A3E22", "#A8885E", "#E6D2B0", "#FFF8EA"], "#2A1606", [("#FFFFFF", 12, 0.4, 0.7, 0.8)]),
    "petal": (["#6A0C26", "#C0304E", "#F07088", "#FFD4DA"], "#3A0418", []),
    "stone": (["#08070A", "#1A1720", "#322C38", "#4E4554"], "#030205", []),
    "glass": (["#123048", "#2C6A90", "#7FC8E8", "#DFF6FF"], "#0A2234", [("#FFFFFF", 20, 0.4, 0.6, 0.9)]),
}


def material(cv, m, name, R=4.0, lw=(0.45, 2.0), brk=0.45, tilt=(0.0, 0.0), grad=0.25, streak_ang=None, streak_k=0.16,
             back=None, back_k=0.9, line=True, thr=None, soft=0.05, spec=True):
    """a solid part painted in a named material: tapered coloured contour, 4-value form, specular, optional
    brushed streaks along streak_ang, optional back rim of the skill light on the shadow side"""
    ramp, lcol, sp = MAT[name]
    if line:
        ink_line(cv, m, lcol, lw[0], lw[1], brk)
    r = paint_form(cv, m, ramp, R=R, tilt=tilt, grad=grad, spec=sp if spec else (), thr=thr, soft=soft)
    if r is None:
        return m
    sl = r[0]
    if streak_ang is not None:
        f = streak_field(cv.w, streak_ang, 140, 6, cv.seed())[sl]
        cv.c[sl] *= (1 + streak_k * (f - 0.5) * 2 * m[sl])[..., None]
    if back is not None:
        b = m * (1 - toward(m, 1.3, LIGHT))
        cv.add(b * (0.6 + 0.4 * smoothstep(0.3, 0.7, cv.noise2)), back, back_k)
    return m


def glow(cv, m, c, r=8.0, k=1.0):
    cv.add(blur(m, r), c, k)


# ------------------------------------------------------------------ CLASS KEY (icon style sheet section 1)
CLASS_KEYS = {
    "battle_mage": {
        "ink": "#09080C", "ink_warm": "#1B120F", "metal": "#D8B25A", "metal_hi": "#FFE9A8", "metal_sh": "#8A5A2B",
        "accent": "#D2283A", "accent_dk": "#4A0810", "cool": "#7FE8FF",
        "tones": {
            # mid, light, core
            "gold": ("#8E5E1A", "#FFC85A", "#FFF6DC"),
            "crimson": ("#7E0C1E", "#FF4A4E", "#FFE6DA"),
            "ember": ("#9A3E14", "#FF9E4A", "#FFF2DC"),
            "white": ("#6E5E46", "#F4E4C2", "#FFFFFF"),
        },
    },
}
KEY = CLASS_KEYS["battle_mage"]

# status palettes (status icons are a cross-class family: the element colour carries meaning)
STATUS_PAL = {
    "gold": ["#1A1206", "#8E5E1A", "#FFC85A", "#FFF6DC"],
    "crimson": ["#1A0608", "#8A1420", "#FF5A56", "#FFE6E0"],
    "wind": ["#061C18", "#1A7A5C", "#8CFFD8", "#F0FFF8"],
    "fire": ["#1E0806", "#A8301A", "#FF9A3A", "#FFF4C2"],
    "ice": ["#06141F", "#2A72A8", "#9FEFFF", "#FFFFFF"],
    "steel": ["#120A0E", "#6A2A34", "#FF6A6A", "#FFE6E6"],
    "cc": ["#120A22", "#5A30A0", "#D8B8FF", "#FFFFFF"],
}


def tone(t):
    """(dark, mid, light, core) for a tone of the active class key, or a status palette"""
    if t in KEY["tones"]:
        m, l, c = KEY["tones"][t]
        return [KEY["ink_warm"], m, l, c]
    return STATUS_PAL[t]


# ------------------------------------------------------------------ light
def soft_light(cv, m, el, k=1.0, R=4.0, glow_r=7.0, core_k=1.0, field=None, body_col=None):
    """a shape made of light with a feathered, painted falloff: bloom, saturated body, white-hot interior"""
    pal = tone(el)
    glow(cv, m, pal[1], glow_r * 2.0, 0.5 * k)
    glow(cv, m, pal[2], glow_r * 0.6, 0.3 * k)
    sl = bbox(m, 2)
    if sl is None:
        return
    d = dist_out(1.0 - m[sl], R * SS)
    t = d / (R * SS)
    body = smoothstep(0.0, 1.0, t) ** 0.7
    if field is not None:
        body = body * field[sl]
    cv.c[sl] += (body[..., None] * (col(body_col) if body_col is not None else mix(pal[1], pal[2], 0.6))) * 0.95 * k
    cv.c[sl] += ((t ** 2.2) * body)[..., None] * col(pal[3]) * core_k * k


def light_form(cv, m, el, k=1.0, R=6.0, glow_r=6.0, lw=(0.3, 1.8), line=True, tilt=(0.0, 0.0), grad=0.3, value=1.0):
    """a construct of light painted as a solid: bloom, coloured tapered contour, 4-value ramp in the element"""
    pal = tone(el)
    if glow_r:
        glow(cv, m, pal[1], glow_r * 2.0, 0.45 * k)
        glow(cv, m, pal[2], glow_r * 0.6, 0.25 * k)
    if line:
        ink_line(cv, m, mix(pal[0], pal[1], 0.45), lw[0], lw[1], 0.5)
    ramp = [mix(pal[1], pal[0], 0.25) * value, mix(pal[1], pal[2], 0.40) * value, mix(pal[2], pal[3], 0.25) * value, col(pal[3]) * value]
    return paint_form(cv, m, ramp, R=R, thr=[0.24, 0.56, 0.86], soft=0.06, tilt=tilt, grad=grad)


def hot_core(cv, x, y, el, size=1.0, k=1.0, star=True, star_len=16.0, ang=0.0):
    pal = tone(el)
    X, Y = cv.grid()
    dx, dy = X - x, Y - y
    if ang:
        a = math.radians(ang)
        dx, dy = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
    r2 = (dx * dx + dy * dy) / (size * size)
    cv.add(np.exp(-r2 / 40.0), pal[2], 0.5 * k)
    cv.add(np.exp(-r2 / 6.0), pal[3], 1.3 * k)
    if star:
        s = np.exp(-np.abs(dy) / (0.7 * size)) * np.exp(-np.abs(dx) / (star_len * size)) + \
            np.exp(-np.abs(dx) / (0.7 * size)) * np.exp(-np.abs(dy) / (star_len * size * 0.6))
        cv.add(s, pal[3], 0.8 * k)


def light_streak(cv, p0, p1, w, el, k=1.0, soft=1.2):
    """a painted speed line: tapered both ends, soft edge, brighter toward p1"""
    pal = tone(el)
    p0, p1 = np.array(p0, float), np.array(p1, float)
    pts = [p0 + (p1 - p0) * t for t in (0, 0.5, 0.85, 1.0)]
    m = cv.poly(ribbon(pts, [0.2, w * 0.7, w, 0.2]))
    m = blur(m, soft)
    cv.add(m, pal[1], 0.6 * k)
    cv.add(np.clip(m * 1.6 - 0.5, 0, 1), pal[2], 0.6 * k)
    return m


# ------------------------------------------------------------------ ground: value masses + painted wash
def brush_wash(cv, rng, el, ang, count=26, k=0.16, length=(0.35, 0.8), width=(0.05, 0.14), ink=None):
    """low-contrast directional brush strokes: the painted backdrop (never per-pixel grain)"""
    n = cv.n
    pal = tone(el)
    for i in range(count):
        a = math.radians(ang + rng.uniform(-14, 14))
        d = np.array([math.cos(a), math.sin(a)])
        c = np.array([rng.uniform(-0.1, 1.1) * n, rng.uniform(-0.1, 1.1) * n])
        L = rng.uniform(*length) * n
        W = rng.uniform(*width) * n
        bend = np.array([-d[1], d[0]]) * rng.uniform(-0.08, 0.08) * n
        pts = [c - d * L / 2, c + bend, c + d * L / 2]
        m = cv.poly(ribbon(spline(pts, 8), lambda t: W * (math.sin(math.pi * t) ** 0.6) + 0.5))
        m = blur(m, 1.6)
        f = streak_field(cv.w, math.degrees(a), 60, 4, cv.seed())
        m = m * (0.55 + 0.45 * f)
        dark = rng.random() < 0.55
        c_ = mix(ink or KEY["ink"], pal[0], 0.5) if dark else mix(pal[0], pal[1], rng.uniform(0.25, 0.6))
        cv.paint(m, c_, k * rng.uniform(0.6, 1.3))


def ground(cv, el, masses=(), focus=None, focus_r=0.55, focus_k=0.9, ink=None, wash=None, rng=None):
    """ink base + a few large soft value masses + painted wash + one smooth light falloff toward the focal point.
    masses: [(mask, level)] where level 1 = warm dark mass, 2 = mid mass, 3 = lit mass."""
    n = cv.n
    X, Y = cv.grid()
    pal = tone(el)
    base = col(ink or KEY["ink"])
    warm = col(pal[0])
    t = np.clip(Y / n, 0, 1)[..., None]
    cv.c = base * (1 - t * 0.6) + warm * (t * 0.6)
    for m, level in masses:
        c = {1: mix(pal[0], pal[1], 0.30), 2: mix(pal[0], pal[1], 0.70), 3: mix(pal[1], pal[2], 0.35)}[level]
        cv.paint(blur(m, 2.5), c)
    if wash is not None and rng is not None:
        brush_wash(cv, rng, el, wash, ink=ink)
    if focus is not None:
        fx, fy = focus
        d2 = ((X - fx) ** 2 + (Y - fy) ** 2) / (n * focus_r) ** 2
        cv.add(np.exp(-d2 * 2.2), pal[1], 0.55 * focus_k)
        cv.add(np.exp(-d2 * 9.0), pal[2], 0.35 * focus_k)
    u = (X / n) * 2 - 1
    w_ = (Y / n) * 2 - 1
    vg = np.clip((np.maximum(abs(u), abs(w_)) * 0.6 + np.sqrt(u * u + w_ * w_) * 0.5 - 0.7) * 1.6, 0, 1)
    cv.c *= (1 - 0.45 * vg)[..., None]


# ------------------------------------------------------------------ class weapon: 却邪 (matches LdWeapons model)
# local units: x along the weapon 0 (butt) .. 1 (tip), y across (screen-down, top/back side = -y).
# The blade is 48% of the weapon (2x the v1 icon), slim (w/l ~ 0.08), with a back hook and fine serrations.
def lance_geom():
    G = {}
    G["butt"] = [(0.0, 0.0), (0.028, -0.011), (0.042, -0.0125), (0.042, 0.0125), (0.028, 0.011)]
    G["shaft"] = [(0.04, -0.0105), (0.44, -0.0105), (0.44, 0.0105), (0.04, 0.0105)]
    G["bands"] = [[(a, -0.0145), (b, -0.0145), (b, 0.0145), (a, 0.0145)] for a, b in ((0.04, 0.056), (0.18, 0.193), (0.31, 0.323), (0.415, 0.432))]
    G["socket"] = [(0.43, -0.011), (0.452, -0.0185), (0.462, -0.014), (0.462, 0.014), (0.452, 0.0185), (0.43, 0.011)]
    cu = [(0.452, -0.011), (0.462, -0.029), (0.482, -0.037), (0.501, -0.030), (0.511, -0.016)]
    G["claw_u"] = (cu, (0.011, 0.0022))
    G["claw_l"] = ([(x, -y) for x, y in cu], (0.011, 0.0022))
    G["orb"] = (0.484, 0.0, 0.0195)
    G["guard"] = [(0.507, -0.011), (0.512, -0.024), (0.527, -0.030), (0.522, -0.016), (0.529, 0.0), (0.522, 0.016),
                  (0.527, 0.030), (0.512, 0.024), (0.507, 0.011)]
    # blade outline: back hook at the base (pointing back toward the wielder), fine forward-raked serrations along
    # the back edge, smooth cutting edge with a slight belly, long point
    back = [(0.524, -0.012), (0.513, -0.034), (0.506, -0.052), (0.522, -0.042), (0.540, -0.030), (0.556, -0.022)]
    x, s = 0.556, 0.0228
    teeth = []
    while x < 0.885:
        by = -(0.0215 - 0.0065 * (x - 0.556) / 0.33)
        teeth += [(x, by), (x + s * 0.78, by - 0.0058), (x + s * 0.82, by + 0.0004)]
        x += s
    back += teeth + [(0.93, -0.0128), (0.97, -0.0072), (1.0, 0.0015)]
    edge = [(1.0, 0.0015), (0.965, 0.0105), (0.90, 0.0175), (0.80, 0.0215), (0.68, 0.0225), (0.58, 0.0195), (0.524, 0.0125)]
    G["blade"] = back + edge[1:]
    ridge = [(0.524, -0.002), (0.70, -0.0015), (0.90, 0.0), (0.995, 0.0012)]
    G["facet_back"] = back + ridge[::-1]
    G["facet_edge"] = ridge + edge[1:]
    G["ridge"] = ridge
    G["edge"] = edge
    G["fuller"] = [(0.545, 0.0035), (0.72, 0.0032), (0.90, 0.0022)]
    return G


def draw_lance(cv, H, el, glow_k=1.0, tassel=False, line=True):
    """draw 却邪 through homography H (local -> icon). Returns the full mask."""
    G = lance_geom()
    T = lambda pts: xf(H, pts)
    pal = tone(el)
    c0, c1 = xf(H, [(0.80, 0.0), (0.80, -0.02)])
    back_lit = float(np.dot(c1 - c0, LIGHT)) > 0
    hw_shaft = hlen(H, (0.30, 0.0), (0.0, 0.0105))
    hw_head = hlen(H, (0.75, 0.0), (0.0, 0.02))
    axis = xf(H, [(0.6, 0.0), (0.9, 0.0)])
    ang = math.degrees(math.atan2(axis[1][1] - axis[0][1], axis[1][0] - axis[0][0]))
    shaft = cv.poly(T(G["shaft"]))
    butt = cv.poly(T(G["butt"]))
    bands = [cv.poly(T(b)) for b in G["bands"]]
    socket = cv.poly(T(G["socket"]))
    claws = []
    for k in ("claw_u", "claw_l"):
        pts, (w0, w1) = G[k]
        sp = spline(T(pts), 8)
        sc = hlen(H, pts[0], (0.0, 1.0))
        claws.append(cv.poly(ribbon(sp, lambda t: max(0.6, sc * (w0 + (w1 - w0) * t)))))
    guard = cv.poly(T(G["guard"]))
    blade = cv.poly(T(G["blade"]))
    fb = cv.poly(T(G["facet_back"])) * blade
    fe = np.clip(blade - fb, 0, 1)
    ox, oy, orr = G["orb"]
    oc = xf(H, [(ox, oy)])[0]
    orad = max(hlen(H, (ox, oy), (0.0, orr)), 1.4)
    parts = [shaft, butt, socket, guard, blade] + bands + claws
    full = _union(cv, parts + [cv.ellipse(oc[0], oc[1], orad)])
    if tassel:
        a = xf(H, [(0.43, 0.0)])[0]
        d = xf(H, [(0.43, 0.0), (0.33, 0.0)])
        bk = (d[1] - d[0]) / (np.linalg.norm(d[1] - d[0]) + 1e-6)
        side = np.array([-bk[1], bk[0]])
        if side[1] < 0:
            side = -side
        L = hlen(H, (0.0, 0.0), (0.25, 0.0))
        path = spline([a, a + side * L * 0.25 + bk * L * 0.10, a + side * L * 0.42 + bk * L * 0.38, a + side * L * 0.36 + bk * L * 0.72], 6)
        tm = cv.poly(ribbon(path, lambda t: max(1.0, L * 0.06 * (1 - t * 0.55))))
        material(cv, tm, "cloth_red", R=max(1.5, L * 0.02), lw=(0.3, 1.4))
        np.maximum(full, tm, out=full)
    if line:
        ink_line(cv, _union(cv, parts), "#030206", 0.45, 2.2, 0.4)
    material(cv, shaft, "lacquer", R=hw_shaft, line=False, streak_ang=ang, streak_k=0.10, back=pal[2], back_k=0.7)
    material(cv, butt, "steel", R=hw_shaft, line=False)
    for b in bands:
        material(cv, b, "gold", R=hw_shaft * 1.2, line=False)
    material(cv, socket, "lacquer", R=hw_shaft * 1.4, line=False)
    for cm in claws:
        material(cv, cm, "lacquer", R=max(1.0, hw_head * 0.3), lw=(0.3, 1.0), back="#FF3A44", back_k=0.6)
    # orb: a glowing crimson sphere with radial bloom -- no sclera ring, no dark centre
    om = cv.ellipse(oc[0], oc[1], orad * 1.0)
    glow(cv, om, "#FF1A2E", orad * 2.6, 1.0 * glow_k)
    glow(cv, om, "#FF5A50", orad * 1.0, 0.6 * glow_k)
    sl = bbox(om, int(orad * SS) + 4)
    X, Y = cv.grid()
    Xs, Ys = X[sl], Y[sl]
    dd = np.sqrt((Xs - oc[0]) ** 2 + (Ys - oc[1]) ** 2) / orad
    hc = oc + LIGHT2 * orad * 0.28
    dh = np.sqrt((Xs - hc[0]) ** 2 + (Ys - hc[1]) ** 2) / orad
    cfill = (col("#8A0818")[None, None] * (1 - smoothstep(1.0, 0.35, dd)[..., None]) + col("#F42A38")[None, None] * smoothstep(1.0, 0.35, dd)[..., None])
    a = smoothstep(1.02, 0.86, dd)[..., None]
    cv.c[sl] = cv.c[sl] * (1 - a) + cfill * a
    cv.c[sl] += (np.exp(-dh * dh * 3.2) * a[..., 0])[..., None] * col("#FFB8A8") * 1.1
    cv.c[sl] += (np.exp(-dd * dd * 0.9) * (1 - a[..., 0]) * 0.8)[..., None] * col("#FF3A44")
    material(cv, guard, "gold", R=hw_head * 0.5, lw=(0.3, 1.2))
    # blade: two facets split along the spine ridge, brushed along the blade, sharp spec streak on the lit facet
    lit, dark = (fb, fe) if back_lit else (fe, fb)
    paint_form(cv, lit, ["#9AA4BA", "#C8D0DE", "#E8EDF5", "#FFFFFF"], R=max(1.0, hw_head * 0.5), tilt=tuple(LIGHT2 * 0.5),
               grad=0.5, thr=[0.30, 0.62, 0.92])
    paint_form(cv, dark, ["#2E3448", "#4E586E", "#76809A", "#9CA6BC"], R=max(1.0, hw_head * 0.5), tilt=tuple(-LIGHT2 * 0.5),
               grad=0.5, thr=[0.2, 0.48, 0.78])
    sl = bbox(blade, 2)
    if sl is not None:
        f = streak_field(cv.w, ang, 180, 5, cv.seed())[sl]
        cv.c[sl] *= (1 + 0.18 * (f - 0.5) * 2 * blade[sl])[..., None]
    rp = spline(T(G["ridge"]), 8)
    off = (1 if back_lit else -1) * hw_head * 0.22
    nrm = np.array([-math.sin(math.radians(ang)), math.cos(math.radians(ang))]) * -off
    spec = cv.poly(ribbon(rp + nrm, lambda t: max(0.35, hw_head * 0.16 * math.sin(math.pi * min(1, t * 1.1)))))
    cv.paint(spec * blade * smoothstep(0.35, 0.5, cv.noise2), "#FFFFFF", 0.95)
    # cutting edge: thin bright honed line, broken; skill-light back rim on the shadow edge
    ep = spline(T(G["edge"]), 6)
    em = cv.poly(ribbon(ep, lambda t: max(0.35, hw_head * 0.10)))
    cv.paint(em * blade * (0.4 + 0.6 * smoothstep(0.3, 0.5, cv.noise2)), "#FFFFFF" if not back_lit else "#C8D2E4", 0.85)
    cv.add(blade * (1 - toward(blade, 1.2, LIGHT)), pal[2], 0.7)
    # red energy fuller
    fm = cv.poly(ribbon(spline(T(G["fuller"]), 6), lambda t: max(0.5, hw_head * (0.17 - 0.09 * t))))
    glow(cv, fm, "#FF2A3A", 2.2, 0.9 * glow_k)
    cv.paint(fm, "#E8202E")
    cv.add(np.clip(blur(fm, 0.35) * 2 - 1, 0, 1), "#FFB0A8", 0.9)
    return full


def lance_H(butt, tip, width_scale=1.0):
    b, t = np.array(butt, float), np.array(tip, float)
    d = t - b
    L = np.linalg.norm(d)
    ang = math.degrees(math.atan2(d[1], d[0]))
    return H_affine(b, ang, L, L * width_scale)


def lance_persp(butt, tip, near_w, far_w):
    """projective lance: the tip end is near the camera (wide), the butt far (narrow). widths = icon units for a
    local half-width of 0.06"""
    b, t = np.array(butt, float), np.array(tip, float)
    d = (t - b) / np.linalg.norm(t - b)
    nn = np.array([-d[1], d[0]])
    src = [(0, -1), (1, -1), (1, 1), (0, 1)]
    dst = [b - nn * far_w, t - nn * near_w, t + nn * near_w, b + nn * far_w]
    return H_quad(src, dst) @ np.diag([1.0, 1.0 / 0.06, 1.0])


# ------------------------------------------------------------------ Chinese dragon (龙) asset
# Profile facing +x, y down, ~unit size. v2: snout lengthened 1.35x past the eye (a 龙 muzzle, not a fox), narrow
# curved fangs, tapered antlers and whiskers.
def _snout(pts):
    return [((x if x < 0.5 else 0.5 + (x - 0.5) * 1.35), y) for x, y in pts]


D_UPPER = _snout([(-0.04, -0.16), (0.10, -0.27), (0.24, -0.33), (0.36, -0.31), (0.47, -0.23), (0.56, -0.19), (0.68, -0.20),
                  (0.76, -0.25), (0.82, -0.31), (0.90, -0.30), (0.96, -0.23), (0.97, -0.15), (0.91, -0.08), (0.84, -0.05), (0.80, -0.02),
                  (0.62, 0.00), (0.46, 0.04), (0.36, 0.10), (0.26, 0.16), (0.12, 0.18), (0.0, 0.10), (-0.06, -0.02)])
D_JAW = _snout([(0.22, 0.14), (0.36, 0.12), (0.50, 0.20), (0.64, 0.28), (0.74, 0.32), (0.82, 0.30), (0.81, 0.37), (0.72, 0.44),
                (0.62, 0.50), (0.58, 0.45), (0.50, 0.41), (0.36, 0.34), (0.22, 0.26), (0.14, 0.20)])
D_MOUTH = _snout([(0.34, 0.10), (0.46, 0.04), (0.62, 0.0), (0.80, -0.03), (0.84, 0.0), (0.78, 0.33), (0.64, 0.29), (0.50, 0.20)])
# narrow curved fangs: (base, mid, tip, base width)
D_FANGS = [(_snout([(0.775, -0.02), (0.790, 0.06), (0.772, 0.15)]), 0.030), (_snout([(0.64, 0.0), (0.648, 0.05), (0.638, 0.10)]), 0.022),
           (_snout([(0.705, 0.30), (0.716, 0.23), (0.704, 0.16)]), 0.026), (_snout([(0.56, 0.24), (0.566, 0.20), (0.556, 0.15)]), 0.020)]
D_TONGUE = (_snout([(0.42, 0.16), (0.60, 0.22), (0.78, 0.20), (0.92, 0.12), (1.0, 0.19)]), 0.05)
D_EYE = [(0.30, -0.215), (0.40, -0.25), (0.52, -0.19), (0.41, -0.16)]
D_PUPIL = [(0.425, -0.235), (0.437, -0.205), (0.428, -0.17), (0.416, -0.205)]
D_BROW = ([(0.56, -0.20), (0.42, -0.28), (0.28, -0.37), (0.12, -0.44), (-0.04, -0.44)], 0.11)
D_BROW2 = ([(0.40, -0.28), (0.30, -0.40), (0.22, -0.54)], 0.06)
D_TOP = _snout([(0.10, -0.27), (0.24, -0.33), (0.36, -0.31), (0.47, -0.23), (0.56, -0.19), (0.68, -0.20), (0.76, -0.25),
                (0.82, -0.31), (0.90, -0.30), (0.96, -0.23), (0.88, -0.21), (0.78, -0.16), (0.62, -0.12), (0.50, -0.12),
                (0.36, -0.15), (0.20, -0.19), (0.06, -0.17)])
D_CHEEK = _snout([(0.04, 0.0), (0.20, -0.05), (0.40, -0.05), (0.62, -0.04), (0.80, -0.04), (0.80, 0.0), (0.46, 0.05),
                  (0.30, 0.13), (0.12, 0.18), (0.0, 0.10)])
D_CARVE = [(_snout([(0.40, -0.07), (0.28, 0.0), (0.16, 0.06)]), 0.02), (_snout([(0.56, -0.16), (0.68, -0.17), (0.77, -0.24)]), 0.014),
           (_snout([(0.48, 0.32), (0.34, 0.26), (0.22, 0.20)]), 0.014), (_snout([(0.62, -0.11), (0.74, -0.12), (0.84, -0.09)]), 0.012)]
D_NOSTRIL = (_snout([(0.895, -0.215)])[0], 0.03)
D_FINS = [[(0.14, 0.12), (-0.14, 0.22), (0.08, 0.23)], [(0.20, 0.24), (-0.04, 0.42), (0.20, 0.33)]]
D_ANTLER = [([(0.20, -0.30), (0.12, -0.48), (-0.02, -0.60), (-0.22, -0.70), (-0.46, -0.72)], 0.075),
            ([(0.10, -0.50), (0.18, -0.64), (0.15, -0.78)], 0.045),
            ([(-0.06, -0.62), (-0.02, -0.78), (-0.08, -0.92)], 0.04),
            ([(-0.27, -0.70), (-0.33, -0.86)], 0.032)]
D_MANE = [([(0.04, -0.22), (-0.16, -0.30), (-0.34, -0.40), (-0.52, -0.40), (-0.74, -0.54)], 0.17),
          ([(-0.02, -0.08), (-0.24, -0.10), (-0.44, -0.18), (-0.64, -0.14), (-0.90, -0.24)], 0.20),
          ([(0.0, 0.06), (-0.22, 0.08), (-0.42, 0.18), (-0.62, 0.14), (-0.84, 0.24)], 0.18),
          ([(0.10, 0.18), (-0.08, 0.30), (-0.28, 0.36), (-0.46, 0.48), (-0.66, 0.46)], 0.15),
          ([(0.24, 0.30), (0.16, 0.44), (0.02, 0.52), (-0.10, 0.66), (-0.28, 0.70)], 0.11),
          ([(-0.02, -0.16), (-0.20, -0.20), (-0.40, -0.28), (-0.58, -0.26)], 0.10),
          ([(0.04, 0.12), (-0.16, 0.20), (-0.34, 0.28), (-0.52, 0.28)], 0.09)]
D_BEARD = [(_snout([(0.76, 0.44), (0.70, 0.58), (0.58, 0.68), (0.42, 0.72)]), 0.10),
           (_snout([(0.62, 0.46), (0.52, 0.58), (0.38, 0.64)]), 0.07)]
D_WHISKERS = [(_snout([(0.92, -0.16)]) + [(1.12, -0.28), (1.10, -0.44), (0.90, -0.52), (0.62, -0.50), (0.32, -0.58), (0.0, -0.54)], 0.036),
              (_snout([(0.90, -0.10)]) + [(1.14, 0.04), (1.16, 0.28), (1.00, 0.48), (0.72, 0.56), (0.46, 0.50)], 0.034)]


def curl_tip(path, turns=1.0, sign=1.0):
    """extend a lock path with a curling flame tip (the 'cloud curl' of Chinese ornament)"""
    p = [np.array(q, float) for q in path]
    d = p[-1] - p[-2]
    L = np.linalg.norm(d) * 0.45
    a = math.atan2(d[1], d[0])
    for i in range(3):
        a += sign * math.radians(55 * turns)
        L *= 0.6
        p.append(p[-1] + np.array([math.cos(a), math.sin(a)]) * L)
    return [tuple(q) for q in p]


def _rib(cv, H, path, w, taper=1.0, n=8, power=1.0):
    pts = spline(xf(H, path), n)
    sc = hlen(H, (0, 0), (w, 0))
    return cv.poly(ribbon(pts, lambda t: sc * (1 - taper * t ** power) + 0.35))


def dragon_head(cv, H, el, k=1.0, far_offset=(0.10, 0.035), mane_k=1.0, value=1.0):
    """龙首 through homography H. 3-value planar shading, tapered strokes. Returns the union mask."""
    pal = tone(el)
    Hf = H @ H_affine(far_offset, 0, 1.0)
    far = _union(cv, [_rib(cv, Hf, p, w, 0.9, 8, 0.8) for p, w in D_ANTLER])
    material(cv, far, "gold", R=1.5, lw=(0.2, 1.0))
    cv.paint(far, mix(pal[0], KEY["ink"], 0.4), 0.45)
    mane = _union(cv, [_rib(cv, H, curl_tip(p, 0.7, 1) if i == 1 else p, w, 1.0, 10, 0.8) for i, (p, w) in enumerate(D_MANE)])
    light_form(cv, mane, el, 0.8 * k * mane_k, R=3.0, glow_r=5, lw=(0.2, 1.4), value=0.92 * value)
    antler = _union(cv, [_rib(cv, H, p, w, 0.9, 8, 0.8) for p, w in D_ANTLER])
    material(cv, antler, "gold", R=2.0, lw=(0.25, 1.4), back=pal[2], back_k=0.6)
    fins = _union(cv, [cv.poly(xf(H, f)) for f in D_FINS])
    light_form(cv, fins, el, 0.9 * k, R=2.5, glow_r=3, lw=(0.2, 1.2), value=value)
    beard = _union(cv, [_rib(cv, H, p, w, 1.0, 8) for p, w in D_BEARD])
    light_form(cv, beard, el, 0.7 * k, R=2.0, glow_r=3, lw=(0.2, 1.2), value=0.9 * value)
    mouth = cv.poly(xf(H, D_MOUTH))
    cv.paint(mouth, KEY["accent_dk"])
    cv.add(blur(mouth, 3) * mouth, KEY["accent"], 0.6)
    tongue = _rib(cv, H, *D_TONGUE, 0.6, 10)
    material(cv, tongue, "cloth_red", R=1.5, lw=(0.2, 0.9))
    jaw = cv.poly(xf(H, D_JAW))
    upper = cv.poly(xf(H, D_UPPER))
    light_form(cv, jaw, el, k, R=5.0, glow_r=4, lw=(0.3, 1.8), tilt=(0.0, 0.5), value=0.85 * value)
    light_form(cv, upper, el, k, R=7.0, glow_r=5, lw=(0.35, 2.0), value=value)
    # planar form: lit top plane, mid side plane, shadowed cheek plane under the eye line (3 values)
    top = cv.poly(xf(H, D_TOP)) * upper
    cv.paint(blur(top, 0.6), mix(pal[2], pal[3], 0.5) * value, 0.8)
    cheek = cv.poly(xf(H, D_CHEEK)) * upper
    cv.paint(blur(cheek, 0.6), mix(pal[1], pal[2], 0.15) * value, 0.8)
    mc = xf(H, [_snout([(0.62, 0.12)])[0]])[0]
    sz = hlen(H, (0, 0), (0.1, 0))
    X, Y = cv.grid()
    cv.add(np.exp(-((X - mc[0]) ** 2 + (Y - mc[1]) ** 2) / (sz * sz * 1.6)) * mouth, pal[3], 1.1 * k)
    for p, w in D_CARVE:
        cv.paint(_rib(cv, H, p, w, 0.95, 8, 1.2), mix(pal[0], pal[1], 0.4) * value, 0.9)
    brow = _union(cv, [_rib(cv, H, *D_BROW, 1.0, 10, 0.8), _rib(cv, H, *D_BROW2, 1.0, 8)])
    cv.paint(blur(brow, 1.5) * upper, mix(pal[0], pal[1], 0.3), 0.7)  # brow casts a shadow over the eye
    light_form(cv, brow, el, k, R=2.0, glow_r=2, lw=(0.25, 1.3), value=value)
    for (pts, w) in D_FANGS:
        P = xf(H, pts)
        sc = hlen(H, pts[0], (w, 0))
        fm = cv.poly(ribbon(spline(P, 6), lambda t: sc * (1 - t) ** 0.9 + 0.25))
        material(cv, fm, "bone", R=max(0.8, sc * 0.35), lw=(0.2, 0.9))
    (nx_, ny_), nr = D_NOSTRIL
    nc = xf(H, [(nx_, ny_), (nx_ + nr, ny_)])
    cv.paint(cv.ellipse(nc[0][0], nc[0][1], max(np.linalg.norm(nc[1] - nc[0]), 0.8), max(np.linalg.norm(nc[1] - nc[0]) * 0.6, 0.6)),
             mix(pal[0], pal[1], 0.3))
    eye = cv.poly(xf(H, D_EYE))
    ink_line(cv, eye, mix(pal[0], KEY["ink"], 0.3), 0.3, 1.2, 0.0)
    cv.paint(eye, mix(pal[2], pal[3], 0.6))
    cv.add(blur(eye, 1.0), pal[2], 0.45 * k)
    cv.paint(cv.poly(xf(H, D_PUPIL)), KEY["accent_dk"])
    wh = _union(cv, [_rib(cv, H, p, w, 1.0, 10, 0.7) for p, w in D_WHISKERS])
    soft_light(cv, wh, el, 0.9 * k, R=0.8, glow_r=2.5, core_k=0.8)
    return _union(cv, [upper, jaw, mane, antler, wh, beard])


def dragon_body(cv, path, widths, el, k=1.0, solid_to=0.6, streaks=5, spread=1.6, fins=True, scales_to=0.75, value=1.0):
    """S-curve body of light painted as a solid (3-value), scale rows along the neck, dorsal flame fins; past
    `solid_to` it splits into diverging qi streaks that fade out. widths: list along the path (head end first)."""
    pal = tone(el)
    p = spline(path, 16)
    N = len(p)
    w = np.interp(np.linspace(0, 1, N), np.linspace(0, 1, len(widths)), widths)
    d = np.gradient(p, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    nrm = np.c_[-d[:, 1], d[:, 0]]
    i_s = int(N * solid_to)
    if fins:
        fm = np.zeros((cv.w, cv.w), np.float32)
        for i in range(2, i_s - 1, 4):
            base0 = p[i] + nrm[i] * w[i] * 0.42
            tip = p[i] + nrm[i] * w[i] * 1.15 - d[i] * w[i] * 1.1
            np.maximum(fm, cv.poly(spline([base0 + d[i] * w[i] * 0.5, base0 + nrm[i] * w[i] * 0.45, tip], 4).tolist() + [base0 - d[i] * w[i] * 0.45]), out=fm)
        light_form(cv, fm, el, 0.8 * k, R=2.0, glow_r=3, lw=(0.2, 1.2), value=0.9 * value)
    for s in range(streaks):
        off = (s - (streaks - 1) / 2) / max(1, (streaks - 1) / 2)
        pts, ww = [], []
        for i in range(i_s - 3, N):
            t = (i - i_s + 3) / max(1, N - i_s + 3)
            pts.append(p[i] + nrm[i] * off * w[i] * 0.42 * (1 + spread * t * t))
            ww.append(w[i] * (0.32 if s % 2 == 0 else 0.2) * (1 - t) ** 1.2 + 0.3)
        sm = cv.poly(ribbon(np.array(pts), ww))
        fade = 1.0 - 0.45 * abs(off)
        soft_light(cv, sm, el, 0.75 * k * fade, R=1.4, glow_r=3, core_k=0.6)
    body = cv.poly(ribbon(p[:i_s + 1], w[:i_s + 1] * np.r_[np.ones(i_s - 3), np.linspace(1, 0.55, 4)]))
    light_form(cv, body, el, k, R=max(2.0, w.max() * 0.30), glow_r=max(4.0, w.max() * 0.3), lw=(0.3, 2.0), value=value)
    # scale rows on the neck: overlapping scallops, darker body with a lit lower rim
    i_sc = int(i_s * scales_to)
    for i in range(2, i_sc, 2):
        for j, o in enumerate((-0.26, 0.0, 0.26)):
            if (i // 2) % 2:
                o += 0.13
            c = p[i] + nrm[i] * o * w[i]
            r = w[i] * 0.15
            sc = cv.ellipse(c[0], c[1], r)
            cut = cv.ellipse(c[0] - d[i][0] * r * 0.55, c[1] - d[i][1] * r * 0.55, r * 0.95)
            cres = np.clip(sc - cut, 0, 1) * body
            cv.paint(cres, mix(pal[1], pal[2], 0.25) * value, 0.75)
            cv.paint(np.clip(sc - toward(sc, r * 0.3, -d[i]), 0, 1) * cut * body, mix(pal[2], pal[3], 0.5) * value, 0.35)
    for i in range(3, i_s - 1, 3):  # belly ridges
        a = p[i] - nrm[i] * w[i] * 0.48
        b = p[i] - nrm[i] * w[i] * 0.05
        c = p[i] - d[i] * w[i] * 0.25 - nrm[i] * w[i] * 0.25
        rm = cv.poly(ribbon(spline([a, c, b], 4), [0.3, max(0.8, w[i] * 0.06), 0.3]))
        cv.paint(rm * body, mix(pal[0], pal[1], 0.6) * value, 0.55)
    return body, p, w, nrm, d


def dragon_claw(cv, base, ang_deg, size, el, k=1.0, spread=1.0):
    """forelimb + four-toed claw: tapered leg, palm pad, four curved toes ending in ivory talons"""
    a = math.radians(ang_deg)
    dv = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-dv[1], dv[0]])
    b = np.array(base, float)
    elbow = b + dv * size * 0.55 + nv * size * 0.22
    wrist = elbow + dv * size * 0.5 - nv * size * 0.05
    leg = cv.poly(ribbon(spline([b, elbow, wrist], 6), [size * 0.34, size * 0.24, size * 0.2]))
    palm = cv.ellipse(wrist[0] + dv[0] * size * 0.08, wrist[1] + dv[1] * size * 0.08, size * 0.16)
    toes, talons = [], []
    for i, da in enumerate((-50, -18, 14, 46)):
        ta = a + math.radians(da * spread)
        tv = np.array([math.cos(ta), math.sin(ta)])
        tn = np.array([-tv[1], tv[0]])
        L = size * (0.42 if i in (1, 2) else 0.34)
        p0 = wrist + dv * size * 0.08
        p1 = p0 + tv * L * 0.55 + tn * L * 0.08
        p2 = p0 + tv * L
        toes.append(cv.poly(ribbon(spline([p0, p1, p2], 4), [size * 0.12, size * 0.1, size * 0.08])))
        talons.append(stroke(cv, [p2 - tv * size * 0.02, p2 + tv * size * 0.10 + tn * size * 0.04, p2 + tv * size * 0.15 + tn * size * 0.13],
                             size * 0.085, 0.3))
    m = _union(cv, [leg, palm] + toes)
    light_form(cv, m, el, k, R=size * 0.10, glow_r=4, lw=(0.3, 1.6))
    for tm in talons:
        material(cv, tm, "bone", R=size * 0.03, lw=(0.2, 0.9))
    return m


# ------------------------------------------------------------------ shared subject assets
def plate_fragment(cv, rng, cx, cy, size, ang, el, k=1.0, trail=None):
    """a curved piece of a broken breastplate: dark lacquered steel face, gold trim along the original curved edge,
    a visible thickness side, a jagged break edge glowing with the skill's light"""
    pal = tone(el)
    H = H_affine((cx, cy), ang, size)
    top = [(x, -0.34 + 0.28 * x * x + 0.04 * x) for x in np.linspace(-0.5, 0.5, 8)]
    jag = []
    xs = np.linspace(0.5, -0.5, int(rng.integers(4, 7)))
    for i, x in enumerate(xs):
        jag.append((x + rng.uniform(-0.05, 0.05), 0.28 + rng.uniform(-0.2, 0.16) + (0.08 if i % 2 else -0.04)))
    face_pts = xf(H, top + jag)
    face = cv.poly(face_pts)
    th = max(1.0, size * 0.08)
    thick = np.clip(toward(face, th, -LIGHT2) - face, 0, 1)
    if trail is not None:
        tm = blur(toward(face, size * 0.5, -np.asarray(trail)), size * 0.12) * (1 - face)
        cv.add(tm, pal[1], 0.35 * k)
    ink_line(cv, _union(cv, [face, toward(face, th, -LIGHT2)]), "#030206", 0.35, 1.8, 0.4)
    cv.paint(thick, "#07070C")
    cv.paint(thick * (1 - toward(thick, 0.8, (0, 1))), "#2A2A38", 0.7)
    curve_tilt = (math.sin(math.radians(ang)) * 0.3, -0.25)
    material(cv, face, "plate", R=size * 0.22, line=False, tilt=curve_tilt, grad=0.6, back=pal[2], back_k=0.5)
    trim_in = xf(H, [(x, y + 0.11) for x, y in top][::-1])
    trim = cv.poly(np.vstack([face_pts[:len(top)], trim_in])) * face
    material(cv, trim, "gold", R=size * 0.05, lw=(0.2, 0.8), brk=0.2)
    # filigree notch in the trim
    fp = xf(H, [(-0.12, -0.24), (0.0, -0.30), (0.12, -0.24)])
    cv.paint(stroke(cv, fp, size * 0.03, size * 0.01) * face, "#3A1C08", 0.8)
    # the break glows: hot element rim along the jagged edge
    jm = cv.poly(ribbon(xf(H, jag), [max(0.6, size * 0.035)] * len(jag))) * dilate(face, 0.6)
    cv.add(blur(jm, 0.8), pal[2], 0.9 * k)
    cv.add(jm, pal[3], 0.5 * k)
    return face


def stone_chip(cv, rng, cx, cy, size, ang, el, hot_dir=None, trail=None, k=1.0):
    """angular dark stone chip, hard faceted planes, a hot rim edge facing the energy source"""
    pal = tone(el)
    nv = int(rng.integers(5, 7))
    angs = np.sort(rng.uniform(0, 2 * math.pi, nv))
    pts = [(cx + math.cos(a + math.radians(ang)) * size * rng.uniform(0.55, 1.0),
            cy + math.sin(a + math.radians(ang)) * size * rng.uniform(0.4, 0.8)) for a in angs]
    m = cv.poly(pts)
    if trail is not None:
        tr = np.asarray(trail, float)
        tm = blur(toward(m, size * 2.2, -tr), size * 0.5) * (1 - m)
        cv.add(tm, pal[1], 0.3 * k)
    ink_line(cv, m, "#020103", 0.3, 1.4, 0.3)
    # facets: split by a line through the centre, each facet flat-shaded at a different value
    c = np.mean(pts, axis=0)
    fa = cv.poly([c] + pts[:nv // 2 + 1]) * m
    fbm = np.clip(m - fa, 0, 1)
    material(cv, fa, "stone", R=size * 0.2, line=False, tilt=tuple(LIGHT2 * 0.6), spec=False)
    material(cv, fbm, "stone", R=size * 0.2, line=False, tilt=tuple(-LIGHT2 * 0.4), spec=False)
    hd = np.asarray(hot_dir if hot_dir is not None else LIGHT2, float)
    rim = m * (1 - toward(m, max(0.7, size * 0.14), -hd))
    cv.add(blur(rim, 0.4), pal[1], 0.9 * k)
    cv.add(rim, pal[2], 0.45 * k)
    return m


def shock_ring(cv, c, u, v, ru, rv, w, el, k=1.0, a0=0, a1=360, front_k=1.0):
    """ellipse ring with axes u (radius ru) and v (radius rv); thicker and brighter on the near side (+v)"""
    pal = tone(el)
    t = np.linspace(math.radians(a0), math.radians(a1), 96)
    pts = np.array([c + u * math.cos(a) * ru + v * math.sin(a) * rv for a in t])
    ws = [w * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(a))) * (0.4 + 0.6 * math.sin(math.pi * i / 95)) for i, a in enumerate(t)]
    m = cv.poly(ribbon(pts, ws))
    soft_light(cv, m, el, k, R=max(0.8, w * 0.35), glow_r=3, core_k=0.9)
    return m


def flare_spikes(cv, cx, cy, angs, r0, r1, w, el, k=1.0):
    """a few big light spikes with a soft painted falloff"""
    m = np.zeros((cv.w, cv.w), np.float32)
    for a, s in angs:
        a = math.radians(a)
        dv = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-dv[1], dv[0]])
        p0 = np.array([cx, cy]) + dv * r0
        p1 = np.array([cx, cy]) + dv * (r0 + (r1 - r0) * s)
        np.maximum(m, cv.poly([p0 + nv * w * s, p1, p0 - nv * w * s]), out=m)
    soft_light(cv, m, el, k, R=max(1.0, w * 0.4), glow_r=3)
    return m


def petal_pts(cx, cy, size, ang, squash=1.0, notch=0.07):
    """peach/plum petal: narrow claw at the base, broad rounded blade, a shallow notch at the tip. Base at (cx, cy)."""
    u = np.linspace(0, 2 * math.pi, 56)
    s = (1 - np.cos(u)) / 2
    x = size * s
    y = 0.40 * size * np.sin(u) * s ** 0.75 * squash
    x = x - notch * size * np.exp(-(y / (0.09 * size * max(squash, 0.3) + 1e-6)) ** 2) * s ** 8
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return np.c_[cx + x * ca - y * sa, cy + x * sa + y * ca]


def petal(cv, x, y, size, ang, squash=1.0, value=1.0, trail=0.0, lw=True):
    m = cv.poly(petal_pts(x, y, size, ang, squash))
    if trail:
        a = math.radians(ang)
        dv = np.array([math.cos(a), math.sin(a)])
        tm = blur(toward(m, size * trail, -dv), size * 0.25) * (1 - m)
        cv.add(tm, "#FF5A6A", 0.30 * value)
    glow(cv, m, KEY["accent"], size * 0.25, 0.25 * value)
    ramp, lcol, _ = MAT["petal"]
    if lw:
        ink_line(cv, m, lcol, 0.2, max(0.6, size * 0.06), 0.5, a=value)
    paint_form(cv, m, [col(c) * value for c in ramp], R=max(1.0, size * 0.22), tilt=(math.cos(math.radians(ang)) * -0.3, -0.2), grad=0.45)
    # vein: one thin darker stroke from the base
    a = math.radians(ang)
    dv = np.array([math.cos(a), math.sin(a)])
    cv.paint(stroke(cv, [(x, y), (x + dv[0] * size * 0.55, y + dv[1] * size * 0.55)], max(0.4, size * 0.04), 0.2) * m, col("#8A1024") * value, 0.5)
    return m


def blossom(cv, cx, cy, size, ang, el, k=1.0, glow_k=0.0, tilt=1.0):
    """5 notched petals + a stamen cluster (filaments with gold anthers)"""
    m = np.zeros((cv.w, cv.w), np.float32)
    if glow_k:
        glow(cv, cv.ellipse(cx, cy, size * 0.5), KEY["accent"], size * 0.4, glow_k)
    for i in range(5):
        a = ang + i * 72
        np.maximum(m, petal(cv, cx, cy, size * 0.62, a, 0.95 * (0.75 + 0.25 * abs(math.cos(math.radians(a)))) if tilt < 1 else 0.95), out=m)
    cv.paint(cv.ellipse(cx, cy, size * 0.12), "#7A0F2E")
    cv.add(blur(cv.ellipse(cx, cy, size * 0.10), 1.0), "#FFD86A", 0.6)
    for i in range(11):
        a = math.radians(ang + 17 + i * 32.7)
        L = size * (0.26 + 0.06 * ((i * 7) % 3))
        e = (cx + math.cos(a) * L, cy + math.sin(a) * L)
        cv.paint(stroke(cv, [(cx, cy), e], max(0.35, size * 0.022), 0.3), "#FFE9C8", 0.9)
        cv.paint(cv.ellipse(e[0], e[1], max(0.6, size * 0.035)), "#FFD24A")
        cv.paint(cv.ellipse(e[0] - 0.2, e[1] - 0.2, max(0.3, size * 0.015)), "#FFFBE0")
    return m


# ------------------------------------------------------------------ frames (generator-owned)
def chamfer_dist(X, Y, n, c):
    e = np.minimum(np.minimum(X, Y), np.minimum(n - X, n - Y))
    k = 0.7071
    for a, b in ((X, Y), (n - X, Y), (X, n - Y), (n - X, n - Y)):
        e = np.minimum(e, (a + b - c) * k)
    return e


def frame_skill(cv):
    """thin dark-navy / silver bevel, the same language as the HUD panels"""
    X, Y = cv.grid()
    n = cv.n
    e = chamfer_dist(X, Y, n, n * 0.07)
    alpha = np.clip(e * SS, 0, 1)
    lit = np.clip(1.15 - (X + Y) / n * 0.8, 0.35, 1.0)
    navy = hexc("#0E1A2A")
    band = (e < n * 0.035)
    c = cv.c.copy()
    c = np.where(band[..., None], navy[None, None] + 0.04, c)
    line = (e > n * 0.012) & (e < n * 0.012 + 1.1)
    c = np.where(line[..., None], hexc("#9AA6B8") * lit[..., None] + 0.08, c)
    inner = (e >= n * 0.035) & (e < n * 0.035 + 1.0)
    c = np.where(inner[..., None], hexc("#C9D3DE") * lit[..., None] * 1.05, c)
    shade = (e >= n * 0.035 + 1.0) & (e < n * 0.035 + 4.0)
    c = np.where(shade[..., None], c * 0.55, c)
    cv.c = c
    return alpha


def hud_corner(cv, ox, oy, sx, sy, s):
    """THE shared gold corner ornament (same geometry as LdHudWidget._filigree_corner): two swept tapered horns along
    the edges, and a gold bead on the diagonal. No square L bracket. s = scale (1.0 = HUD px)."""
    P = lambda pts: [(ox + sx * x * s, oy + sy * y * s) for x, y in pts]
    m = np.zeros((cv.w, cv.w), np.float32)
    np.maximum(m, cv.poly(ribbon(spline(P([(1.5, 1.5), (10, 2.2), (22, 3.4)]), 6), lambda t: 2.6 * s * (1 - t) + 0.3)), out=m)
    np.maximum(m, cv.poly(ribbon(spline(P([(1.5, 1.5), (2.2, 10), (3.4, 22)]), 6), lambda t: 2.6 * s * (1 - t) + 0.3)), out=m)
    np.maximum(m, cv.ellipse(*P([(4.2, 4.2)])[0], 1.9 * s), out=m)
    return m


def frame_ultimate(cv, rng):
    """navy glass border, thin gold double line, the shared HUD corner ornament, one blue crystal top-centre"""
    X, Y = cv.grid()
    n = cv.n
    e = chamfer_dist(X, Y, n, n * 0.05)
    alpha = np.clip(e * SS, 0, 1)
    bw = n * 0.065
    c = cv.c.copy()
    glass = e < bw
    gl = hexc("#0E1A2A") * (0.85 + 0.3 * np.clip(1 - Y / n, 0, 1))[..., None]
    c = np.where(glass[..., None], gl + 0.03, c)
    c = np.where(((e >= bw) & (e < bw + 3.0))[..., None], c * 0.5, c)
    cv.c = c
    gold, gold_hi, gold_sh = hexc("#D8B25A"), hexc("#FFE9A8"), hexc("#8A5A2B")
    fil = (((e > n * 0.014) & (e < n * 0.014 + 1.6)) | ((e > bw - 1.8) & (e < bw))).astype(np.float32)
    s = n / 64.0
    orn = _union(cv, [hud_corner(cv, 2, 2, 1, 1, s), hud_corner(cv, n - 2, 2, -1, 1, s),
                      hud_corner(cv, 2, n - 2, 1, -1, s), hud_corner(cv, n - 2, n - 2, -1, -1, s)])
    allg = np.clip(np.maximum(orn, fil), 0, 1)
    ink_line(cv, orn, "#2A1606", 0.3, 1.2, 0.0)
    lit = np.clip(1.2 - (X + Y) / n * 0.7, 0.4, 1.1)[..., None]
    cv.paint(allg, gold * lit)
    cv.paint(orn * (1 - toward(orn, 1.5, LIGHT)), gold_sh)
    cv.paint(allg * (1 - toward(allg, 1.0, -LIGHT)), gold_hi)
    sweep = np.exp(-(((X - Y) / n - 0.25) ** 2) * 40)
    cv.add(allg * sweep, gold_hi, 0.6)
    cv.add(blur(allg, 3) * (e > bw), "#FFC43A", 0.2)
    cx, cy = n / 2, n * 0.035
    rx, ry = 7 * s * 0.9, 9 * s * 0.9
    gem = [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]
    mg = cv.poly(gem)
    cv.paint(np.clip(dilate(mg, 1.4) - mg, 0, 1), gold)
    cv.paint(mg, "#2F8FE0")
    cv.paint(cv.poly([(cx, cy - ry), (cx + rx, cy), (cx, cy)]), "#9FDCFF")
    cv.add(blur(mg, 5), "#3FA9FF", 0.5)
    return alpha


def frame_passive(cv):
    X, Y = cv.grid()
    n = cv.n
    r = np.sqrt((X - n / 2) ** 2 + (Y - n / 2) ** 2)
    e = n / 2 - 1 - r
    alpha = np.clip(e * SS, 0, 1)
    bw = n * 0.06
    band = e < bw
    prof = np.sin(np.clip(e / bw, 0, 1) * math.pi)
    br = hexc("#B07A3E")[None, None] * (0.5 + 0.6 * prof[..., None])
    cv.c = np.where(band[..., None], br, cv.c)
    cv.c = np.where(((e >= bw) & (e < bw + 2))[..., None], hexc("#140A04"), cv.c)
    return alpha


# ------------------------------------------------------------------ SKILL COMPOSITIONS (Battle Mage)
# Lance appears in exactly 4 of 8: 突刺, 天击, 怒龙穿心, 伏龙翔天. The others show the action alone.
def comp_thrust(cv, rng, el):
    """突刺: a 3/4 forward thrust, the blade foreshortened toward the viewer; a cone of speed lines converging on
    the point and an air-pierce shock ring at the tip. Reads as 'stab' at 32 px: one diagonal into one ring."""
    n = cv.n
    butt = np.array([n * -0.20, n * -0.16])
    tip = np.array([n * 0.63, n * 0.60])
    dv = (tip - butt) / np.linalg.norm(tip - butt)
    pv = np.array([-dv[1], dv[0]])
    band = cv.poly([butt + pv * n * 0.30, tip + pv * n * 0.34 + dv * n * 0.3, tip - pv * n * 0.34 + dv * n * 0.3, butt - pv * n * 0.30])
    ground(cv, el, [(band, 1)], focus=tip, focus_r=0.42, focus_k=0.9, wash=math.degrees(math.atan2(dv[1], dv[0])), rng=rng)
    # vapour cone: soft white cone opening backward from the point
    cone = cv.poly([tip + dv * n * 0.02, tip - dv * n * 0.42 + pv * n * 0.24, tip - dv * n * 0.50, tip - dv * n * 0.42 - pv * n * 0.24])
    cv.add(blur(cone, 9), tone(el)[1], 0.45)
    # cone of speed lines converging on the point from behind (few, varied, soft)
    for o, L, w in ((-0.95, 0.9, 0.010), (-0.55, 1.0, 0.016), (-0.25, 0.7, 0.009), (0.3, 0.85, 0.013), (0.62, 1.0, 0.018), (1.0, 0.75, 0.010)):
        far = tip - dv * n * L + pv * o * n * 0.62
        near = tip - dv * n * 0.16 + pv * o * n * 0.10
        light_streak(cv, far, near, n * w, el, 0.75, soft=1.8)
    H = lance_persp(butt, tip, n * 0.19, n * 0.075)
    draw_lance(cv, H, el, tassel=False)
    # air-pierce shock rings around the point, perpendicular to the thrust
    rc = tip + dv * n * 0.05
    shock_ring(cv, rc, pv, dv, n * 0.24, n * 0.085, n * 0.04, el, 1.0)
    shock_ring(cv, rc + dv * n * 0.10, pv, dv, n * 0.36, n * 0.12, n * 0.022, el, 0.55)
    hot_core(cv, tip[0] + dv[0] * 2, tip[1] + dv[1] * 2, el, 3.0, 1.2, star_len=20, ang=math.degrees(math.atan2(dv[1], dv[0])))


def comp_sky_strike(cv, rng, el):
    """天击: the launcher. The lance drives up from the bottom-left into a soft volumetric column of light; the
    enemy's breastplate bursts into curved gold-trimmed plate fragments flung into the sky."""
    n = cv.n
    hit = np.array([n * 0.60, n * 0.30])
    lowland = cv.poly([(0, n * 0.80), (n * 0.3, n * 0.74), (n * 0.7, n * 0.82), (n, n * 0.76), (n, n), (0, n)])
    ground(cv, el, [(lowland, 1)], focus=hit, focus_r=0.45, focus_k=0.8, wash=-88, rng=rng)
    # volumetric light column: gaussian across, widening and brightening upward, soft god-ray streaks
    pal = tone(el)
    X, Y = cv.grid()
    yy = np.clip(Y / n, 0, 1)
    cx = hit[0] + (yy - 0.3) * n * -0.04
    wcol = n * (0.10 + 0.14 * (1 - yy))
    colm = np.exp(-((X - cx) / wcol) ** 2) * (0.35 + 0.65 * smoothstep(1.0, 0.05, yy))
    rays = streak_field(cv.w, -90, 40, 3, cv.seed())
    cv.add(colm * (0.7 + 0.5 * rays), pal[1], 0.55)
    cv.add(colm ** 3 * (0.6 + 0.6 * rays), pal[2], 0.45)
    core = np.exp(-((X - cx) / (wcol * 0.25)) ** 2) * smoothstep(0.9, 0.0, yy) * smoothstep(0.05, 0.3, yy)
    cv.add(core, pal[3], 0.35)
    for i in range(14):  # light motes rising in the column
        x = hit[0] + rng.normal(0, n * 0.09)
        y = rng.uniform(0.05, 0.75) * n
        cv.add(blur(cv.ellipse(x, y, rng.uniform(0.6, 1.4)), 0.6), pal[3], 0.9)
    H = lance_H((n * 0.22, n * 1.16), (hit[0] + n * 0.04, hit[1] - n * 0.17), 1.25)
    draw_lance(cv, H, el, tassel=True)
    tipp = xf(H, [(1.0, 0.0)])[0]
    flare_spikes(cv, tipp[0], tipp[1] + n * 0.03, [(-90, 1.0), (-140, 0.55), (-38, 0.6), (200, 0.4), (-8, 0.35)], n * 0.04, n * 0.32, n * 0.03, el, 0.8)
    hot_core(cv, tipp[0], tipp[1] + n * 0.02, el, 2.8, 1.1)
    for (x, y, s, a, tr) in ((0.83, 0.18, 0.24, 22, (0.4, -1)), (0.30, 0.13, 0.17, -38, (-0.5, -1)), (0.88, 0.48, 0.12, 64, (1, -0.3)),
                             (0.40, 0.40, 0.09, -70, (-0.6, -0.8))):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 1.0, trail=np.array(tr) / np.linalg.norm(tr))


def comp_dragon_tooth(cv, rng, el):
    """龙牙: the jaws alone. Upper and lower dragon jaws of ember light snap shut on one hot point; narrow curved
    ivory fangs, scale rows on the jaw plates, the dark maw between them. Horizontal value structure."""
    n = cv.n
    snap = np.array([n * 0.86, n * 0.50])
    ground(cv, el, [], focus=snap, focus_r=0.45, focus_k=0.8, wash=8, rng=rng)
    pal = tone(el)
    # maw glow between the jaws
    maw = cv.poly([(n * -0.1, n * 0.30), (n * 0.50, n * 0.40), snap, (n * 0.50, n * 0.62), (n * -0.1, n * 0.72)])
    cv.paint(blur(maw, 4), "#1A0406", 0.8)
    cv.add(blur(maw, 10) * blur(cv.ellipse(snap[0] - n * 0.2, snap[1], n * 0.3, n * 0.12), 8), KEY["accent"], 0.8)
    jaws = []
    for sgn, path, ws in ((-1, [(-0.08, 0.12), (0.30, 0.16), (0.62, 0.30), (0.88, 0.47)], [0.36, 0.28, 0.16, 0.035]),
                          (1, [(-0.08, 0.90), (0.30, 0.86), (0.60, 0.70), (0.86, 0.53)], [0.30, 0.22, 0.12, 0.03])):
        P = spline([(n * x, n * y) for x, y in path], 12)
        W = np.interp(np.linspace(0, 1, len(P)), np.linspace(0, 1, len(ws)), np.array(ws) * n)
        m = cv.poly(ribbon(P, W))
        jaws.append((sgn, P, W, m))
    # fangs first (they sit behind the jaw rims)
    for sgn, P, W, m in jaws:
        d = np.gradient(P, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nr = np.c_[-d[:, 1], d[:, 0]]
        inner = -sgn  # inner side points toward the mouth
        sel = (0.24, 0.44, 0.62, 0.76) if sgn < 0 else (0.30, 0.50, 0.68)
        for j, t in enumerate(sel):
            i = int(t * (len(P) - 1))
            if nr[i][1] * inner < 0:
                nr_i = -nr[i]
            else:
                nr_i = nr[i]
            base = P[i] + nr_i * W[i] * 0.40
            L = n * (0.17 - 0.03 * j) * (1.0 if sgn < 0 else 0.8)
            tipf = base + nr_i * L - d[i] * L * 0.30
            mid = base + nr_i * L * 0.55 - d[i] * L * 0.05
            fm = cv.poly(ribbon(spline([base, mid, tipf], 6), lambda u: n * 0.042 * (1 - u) ** 0.85 + 0.25))
            material(cv, fm, "bone", R=n * 0.012, lw=(0.25, 1.3))
    for sgn, P, W, m in jaws:
        light_form(cv, m, el, 1.0, R=n * 0.05, glow_r=6, lw=(0.35, 2.4), tilt=(0.0, 0.25 * sgn))
        d = np.gradient(P, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nr = np.c_[-d[:, 1], d[:, 0]]
        if np.mean(nr[:, 1]) * sgn < 0:
            nr = -nr
        # gum ridge on the inner edge (darker, the mouth's shadow)
        gum = cv.poly(ribbon(P - nr * W[:, None] * 0.36, W * 0.22)) * m
        cv.paint(blur(gum, 0.8), mix(pal[0], pal[1], 0.55), 0.85)
        # scale rows on the outer jaw plate
        for i in range(3, int(len(P) * 0.8), 2):
            for o in (0.04, 0.20, 0.36):
                c = P[i] + nr[i] * W[i] * (o + (0.08 if i % 4 == 1 else 0))
                r = W[i] * 0.085
                sc = cv.ellipse(c[0], c[1], r)
                cut = cv.ellipse(c[0] + d[i][0] * r * 0.6, c[1] + d[i][1] * r * 0.6, r * 0.95)
                cv.paint(np.clip(sc - cut, 0, 1) * m, mix(pal[1], pal[2], 0.2), 0.7)
        # lip ridge
        lp = P + nr * W[:, None] * 0.18
        cv.paint(cv.poly(ribbon(lp[2:-3], lambda u: max(0.4, n * 0.012 * (1 - u)))) * m, mix(pal[2], pal[3], 0.5), 0.6)
    hot_core(cv, snap[0], snap[1], el, 3.2, 1.25, star_len=22)
    flare_spikes(cv, snap[0], snap[1], [(-60, 0.6), (0, 1.0), (60, 0.6), (180, 0.4)], n * 0.03, n * 0.18, n * 0.02, el, 0.7)


def gauntlet_palm(cv, H, el):
    """一叶之秋-style armoured gauntlet, OPEN PALM toward the viewer. Fingers splayed at different lengths, three
    plated segments each with a knuckle break and a gold joint line, small gold claw tips, a clear 2-segment thumb,
    a foreshortened leather palm with a glowing centre, a lacquered vambrace with gold trim. Local: wrist at the
    origin, fingers toward -y, palm width ~0.64."""
    T = lambda pts: xf(H, pts)
    S = lambda p, w: hlen(H, p, (w, 0))
    cuff = cv.poly(T([(-0.30, -0.02), (0.30, -0.02), (0.36, 0.30), (0.42, 0.66), (-0.42, 0.66), (-0.36, 0.30)]))
    palm = cv.poly(T(closed_spline([(-0.31, -0.06), (-0.34, -0.30), (-0.28, -0.46), (-0.10, -0.52), (0.10, -0.53), (0.27, -0.47),
                                    (0.33, -0.30), (0.30, -0.06), (0.0, 0.0)], 6)))
    fingers, joints, tips = [], [], []
    # base, splay angle (deg from up), length, width, bend per joint (curl toward the viewer)
    for (bx, by), ang, L, w, bend in (((-0.220, -0.44), -19, 0.40, 0.150, 6), ((-0.072, -0.50), -6, 0.47, 0.158, 4),
                                      ((0.078, -0.50), 8, 0.43, 0.152, 6), ((0.212, -0.43), 24, 0.31, 0.135, 9)):
        p = np.array([bx, by])
        a = math.radians(ang - 90)
        segs = []
        for s_i, frac in enumerate((0.44, 0.32, 0.24)):
            dv = np.array([math.cos(a), math.sin(a)])
            q = p + dv * L * frac
            ww = w * (1.0 - s_i * 0.12)
            pa, qa = T([p])[0], T([q - dv * 0.012])[0]
            seg = cv.poly(ribbon(spline([pa, (pa + qa) / 2, qa], 3), [S(p, ww), S(p, ww * 0.98), S(q, ww * 0.9)]))
            np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.45)), out=seg)
            segs.append(seg)
            nv = np.array([-dv[1], dv[0]])
            joints.append(T([p + nv * ww * 0.48, p + dv * 0.012, p - nv * ww * 0.48]))
            p = q
            a += math.radians(bend * (1 if ang >= 0 else -1))
        dv = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-dv[1], dv[0]])
        tips.append(cv.poly(T([p - nv * w * 0.32 - dv * 0.01, p + dv * 0.075 + nv * w * 0.05, p + nv * w * 0.32 - dv * 0.01])))
        fingers.append(segs)
    thumb = []
    p = np.array([-0.30, -0.12])
    a = math.radians(-148)
    for s_i, (Ls, ww) in enumerate(((0.20, 0.175), (0.16, 0.15))):
        dv = np.array([math.cos(a), math.sin(a)])
        q = p + dv * Ls
        pa, qa = T([p])[0], T([q])[0]
        seg = cv.poly(ribbon([pa, (pa + qa) / 2, qa], [S(p, ww), S(p, ww * 0.98), S(q, ww * 0.88)]))
        np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.44)), out=seg)
        thumb.append(seg)
        nv = np.array([-dv[1], dv[0]])
        joints.append(T([p + nv * ww * 0.5, p, p - nv * ww * 0.5]))
        p = q
        a += math.radians(16)
    dv = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-dv[1], dv[0]])
    tips.append(cv.poly(T([p - nv * 0.045, p + dv * 0.07 + nv * 0.01, p + nv * 0.045])))
    allm = _union(cv, [palm, cuff] + thumb + [s for f in fingers for s in f] + tips)
    ink_line(cv, allm, "#030206", 0.5, 2.6, 0.35)
    material(cv, cuff, "lacquer", R=S((0, 0.3), 0.18), line=False, tilt=(0.0, 0.3), back="#FF5A50", back_k=0.6)
    trim = cv.poly(T([(-0.31, 0.0), (0.31, 0.0), (0.33, 0.09), (-0.33, 0.09)])) * cuff
    material(cv, trim, "gold", R=1.5, lw=(0.2, 0.9))
    # cloud-scroll (祥云) motif on the vambrace
    for sx in (-1, 1):
        cp = [(sx * (0.02 + 0.10 * math.cos(a)), 0.24 + 0.07 * math.sin(a)) for a in np.linspace(math.pi, math.pi * 2.6, 9)]
        cv.paint(stroke(cv, T([(0.0, 0.30)] + cp), S((0, 0.3), 0.035), S((0, 0.3), 0.012), 6) * cuff, "#D8B25A", 0.95)
    material(cv, palm, "leather", R=S((0, -0.3), 0.16), line=False, tilt=(0.15, -0.1), back="#FF4A4E", back_k=0.6)
    # palm creases
    for pts in (((-0.26, -0.36), (-0.04, -0.30), (0.20, -0.36)), ((-0.24, -0.22), (0.0, -0.17), (0.12, -0.10))):
        cv.paint(stroke(cv, T(pts), S((0, -0.3), 0.022), 0.3, 6) * palm, "#0C0607", 0.75)
    for segs in fingers + [thumb]:
        for s_i, seg in enumerate(segs):
            material(cv, seg, "lacquer", R=max(1.5, hlen(H, (0, -0.6), (0.05, 0))), lw=(0.25, 1.2), brk=0.5, back="#FF5A50", back_k=0.5)
    for jp in joints:  # gold trim line across each knuckle break
        cv.paint(stroke(cv, jp, S((0, -0.6), 0.02), S((0, -0.6), 0.02), 4), "#D8B25A", 0.95)
        cv.paint(stroke(cv, jp, S((0, -0.6), 0.008), S((0, -0.6), 0.008), 4), "#FFE9A8", 0.8)
    for t_ in tips:
        material(cv, t_, "gold", R=1.0, lw=(0.2, 0.8), brk=0.1)
    return allm, palm


def comp_falling_flower_palm(cv, rng, el):
    """落花掌: an open-palm strike thrust toward the viewer, 3/4. The palm centre blazes; notched blossom petals with
    trails stream outward along the strike direction; two full blossoms with stamen clusters."""
    n = cv.n
    diag = cv.poly([(0, n * 0.15), (n * 0.55, 0), (n, n * 0.40), (n, n * 0.85), (n * 0.4, n), (0, n * 0.75)])
    ground(cv, el, [(diag, 1)], focus=(n * 0.48, n * 0.40), focus_r=0.5, focus_k=0.9, wash=-35, rng=rng)
    # far petals: small, dark, soft
    for i in range(9):
        x, y = rng.uniform(n * 0.05, n * 0.95), rng.uniform(n * 0.03, n * 0.55)
        s = rng.uniform(n * 0.05, n * 0.08)
        m = blur(cv.poly(petal_pts(x, y, s, rng.uniform(-80, 20), rng.uniform(0.5, 0.9))), rng.uniform(1.0, 2.0))
        cv.paint(m, mix("#4A0A18", "#C2202C", rng.uniform(0.2, 0.45)), 0.85)
    # 3/4 open palm: the wrist far (lower-left), the hand opening toward the viewer, upper-right edge nearer
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.30), (-0.55, 0.30)]
    dst = [(n * 0.08, n * 0.04), (n * 0.84, n * -0.06), (n * 0.86, n * 1.02), (n * 0.12, n * 0.90)]
    H = H_quad(src, dst)
    pc = xf(H, [(0.0, -0.28)])[0]
    shock_ring(cv, pc, np.array([0.96, -0.28]), np.array([0.28, 0.96]), n * 0.44, n * 0.30, n * 0.035, el, 0.75, -230, 50)
    allm, palm = gauntlet_palm(cv, H, el)
    # palm centre: a blazing qi seal (soft light, no glyph)
    seal = cv.ellipse(pc[0], pc[1], n * 0.085, n * 0.075) * dilate(palm, 1.0)
    soft_light(cv, seal, el, 1.0, R=n * 0.05, glow_r=10, core_k=1.2)
    hot_core(cv, pc[0], pc[1], el, 3.0, 1.0, star_len=14)
    blossom(cv, pc[0] + n * 0.02, pc[1] + n * 0.01, n * 0.14, 12, el, glow_k=0.5)
    # near petals stream OUTWARD from the palm (the strike comes at the viewer): long axis radial, trail behind
    for i, (a_deg, dn) in enumerate([(-115, 0.34), (-88, 0.42), (-62, 0.36), (-40, 0.46), (-18, 0.40), (6, 0.44), (28, 0.36),
                                    (-75, 0.24), (-28, 0.27), (48, 0.30)]):
        a = a_deg + rng.uniform(-6, 6)
        ar = math.radians(a)
        x = pc[0] + math.cos(ar) * dn * n
        y = pc[1] + math.sin(ar) * dn * n
        s = n * rng.uniform(0.085, 0.12) * (0.7 + dn)
        petal(cv, x, y, s, a + rng.uniform(-20, 20), rng.uniform(0.55, 0.95), value=1.0, trail=1.4 if i % 3 == 0 else 0.7)
    blossom(cv, n * 0.86, n * 0.18, n * 0.15, 30, el, glow_k=0.3)


def comp_circle_swing(cv, rng, el):
    """圆舞棍: the swing arc alone. A tapered crescent smear sweeping 300 degrees around the wielder, seen at an
    angle: thick and white-hot at the leading edge, dissolving into streaks at the tail; stone debris flung
    outward and a dust ring on the ground."""
    n = cv.n
    pal = tone(el)
    c = np.array([n * 0.50, n * 0.46])
    rot = math.radians(-10)
    u = np.array([math.cos(rot), math.sin(rot)])
    v = np.array([-u[1], u[0]])
    rx, ry = n * 0.40, n * 0.16
    disc = cv.ellipse(c[0], c[1] + n * 0.2, n * 0.46, n * 0.16)
    ground(cv, el, [(disc, 1)], focus=c, focus_r=0.6, focus_k=0.55, wash=-10, rng=rng)
    # ground ring + dust puffs
    gc = c + v * n * 0.26
    shock_ring(cv, gc, u, v, n * 0.44, n * 0.11, n * 0.012, el, 0.35)
    dust = np.zeros((cv.w, cv.w), np.float32)
    for a in range(-20, 200, 22):
        ar = math.radians(a + rng.uniform(-8, 8))
        p = gc + u * math.cos(ar) * n * 0.44 + v * math.sin(ar) * n * 0.11
        r = n * rng.uniform(0.035, 0.06)
        np.maximum(dust, cv.ellipse(p[0], p[1] - r * 0.5, r * 1.6, r), out=dust)
    cv.add(blur(dust, 2.5) * (0.6 + 0.4 * cv.noise2), pal[1], 0.35)
    # the smear: head at +30 deg (front right), tail 300 deg behind it
    th_head, sweep = 30.0, 300.0
    X, Y = cv.grid()
    dx, dy = X - c[0], Y - c[1]
    lx, ly = dx * u[0] + dy * u[1], dx * v[0] + dy * v[1]
    ang = np.degrees(np.arctan2(ly / ry, lx / rx))
    t = ((ang - (th_head - sweep)) % 360) / sweep
    t = np.where(t <= 1.0, t, 0.0)
    rho = np.sqrt((lx / rx) ** 2 + (ly / ry) ** 2)
    front = smoothstep(-0.2, 0.9, np.sin(np.radians(ang)))     # near side of the ellipse is fatter
    width = (0.08 + 0.46 * t ** 1.2) * (0.55 + 0.45 * front)
    inside = smoothstep(width, width * 0.55, 1.0 - rho) * smoothstep(-0.05, 0.02, 1.0 - rho)   # crescent: outer edge on the ring
    head_cap = smoothstep(1.0, 0.985, t)
    m = (inside * (t > 0.003) * head_cap).astype(np.float32)
    streaky = 0.5 + 0.5 * np.sin(rho * 85.0 + cv.noise * 9.0)
    field = np.where(t < 0.62, (streaky ** 2.2) * smoothstep(0.0, 0.62, t) + smoothstep(0.35, 0.62, t) * 0.6, 1.0)
    inten = 0.35 + 0.75 * t ** 1.4
    mm = m * np.clip(field, 0, 1)
    cv.add(blur(m * inten, 7), pal[1], 0.8)
    cv.add(blur(mm * inten, 2.0), pal[2], 1.1)
    cv.add(mm * inten * smoothstep(0.3, 1.0, t), mix(pal[2], pal[3], 0.5), 0.9)
    edge_in = smoothstep(width * 0.6, width * 0.2, 1.0 - rho) * mm
    cv.add(edge_in * inten, pal[3], 0.5)
    # white-hot leading edge: the outermost rim of the last third, thickest at the head
    rimw = 0.06 * smoothstep(0.55, 1.0, t)
    rim = smoothstep(rimw + 0.01, rimw * 0.3, 1.0 - rho) * smoothstep(-0.03, 0.01, 1.0 - rho) * (t > 0.5) * head_cap
    cv.add(blur(rim.astype(np.float32), 0.6), pal[3], 1.3)
    hp = c + u * math.cos(math.radians(th_head)) * rx + v * math.sin(math.radians(th_head)) * ry
    hot_core(cv, hp[0], hp[1], el, 3.0, 1.15, star_len=18)
    # debris flung outward, tangential to the swing
    for a, s in ((-150, 0.07), (-95, 0.05), (-40, 0.065), (100, 0.085), (150, 0.06), (205, 0.075), (62, 0.05)):
        ar = math.radians(a)
        rr = 1.18 + rng.uniform(0, 0.15)
        p = c + u * math.cos(ar) * rx * rr + v * math.sin(ar) * ry * rr * 1.25
        tang = -u * math.sin(ar) * rx + v * math.cos(ar) * ry
        tang = tang / (np.linalg.norm(tang) + 1e-6)
        outv = p - c
        outv = outv / np.linalg.norm(outv)
        stone_chip(cv, rng, p[0], p[1], n * s, rng.uniform(0, 360), el, hot_dir=-outv, trail=(tang + outv) / np.linalg.norm(tang + outv))


def comp_furious_dragon(cv, rng, el):
    """怒龙穿心: the lance runs straight through an enemy breastplate; a crimson dragon of light erupts out of the far
    side, head in 3/4 view lunging up and out, its body streaming back along the lance. Ink ground so the red
    dragon separates."""
    n = cv.n
    hit = np.array([n * 0.36, n * 0.66])
    ground(cv, el, [], focus=(n * 0.64, n * 0.34), focus_r=0.45, focus_k=0.35, ink="#050407", wash=-40, rng=rng)
    dragon_body(cv, [(n * 0.56, n * 0.48), (n * 0.42, n * 0.64), (n * 0.24, n * 0.70), (n * 0.10, n * 0.86), (n * -0.06, n * 0.98)],
                [n * 0.17, n * 0.15, n * 0.11, n * 0.06, n * 0.03], el, k=0.95, solid_to=0.45, streaks=5, spread=2.4)
    plate_fragment(cv, rng, hit[0] - n * 0.02, hit[1] + n * 0.05, n * 0.26, -12, el, 1.0)
    plate_fragment(cv, rng, hit[0] - n * 0.24, hit[1] - n * 0.22, n * 0.11, -60, el, 1.0, trail=np.array([-0.6, -0.8]))
    plate_fragment(cv, rng, hit[0] + n * 0.04, hit[1] + n * 0.30, n * 0.09, 40, el, 1.0, trail=np.array([0.2, 1.0]))
    H = lance_H((n * -0.30, n * 1.06), (n * 0.72, n * 0.36), 1.15)
    draw_lance(cv, H, el)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1)
    src = [(-0.9, -0.95), (1.25, -0.95), (1.25, 0.75), (-0.9, 0.75)]
    dst = [(n * 0.40, n * 0.06), (n * 0.98, n * -0.04), (n * 1.04, n * 0.60), (n * 0.46, n * 0.46)]
    dragon_head(cv, H_quad(src, dst), el, k=1.0, far_offset=(0.16, 0.05))


def comp_dragon_breaks_ranks(cv, rng, el):
    """豪龙破军: side-on charge. The dragon IS the charge (no lance): long-snouted profile head leading, claw raking
    forward, S-coil behind dissolving into qi, enemy plate armour bursting apart ahead of it."""
    n = cv.n
    band = cv.poly([(0, n * 0.30), (n, n * 0.22), (n, n * 0.78), (0, n * 0.86)])
    ground(cv, el, [(band, 1)], focus=(n * 0.70, n * 0.45), focus_r=0.55, focus_k=0.8, wash=0, rng=rng)
    for (a, b, w) in (((-0.1, 0.16), (0.55, 0.19), 0.018), ((-0.1, 0.88), (0.6, 0.85), 0.02), ((0.0, 0.08), (0.35, 0.10), 0.012)):
        light_streak(cv, (n * a[0], n * a[1]), (n * b[0], n * b[1]), n * w, el, 0.8)
    dragon_body(cv, [(n * 0.40, n * 0.47), (n * 0.26, n * 0.58), (n * 0.12, n * 0.42), (n * -0.02, n * 0.52), (n * -0.18, n * 0.70)],
                [n * 0.16, n * 0.15, n * 0.11, n * 0.07, n * 0.03], el, k=0.95, solid_to=0.55, streaks=5, spread=1.8)
    dragon_claw(cv, (n * 0.38, n * 0.62), 25, n * 0.28, el, 0.95, spread=1.1)
    dragon_head(cv, H_affine((n * 0.44, n * 0.42), 4, n * 0.34), el, k=1.0)
    for (x, y, s, a, tr) in ((0.92, 0.80, 0.15, 30, (1, 0.4)), (0.90, 0.14, 0.12, -50, (1, -0.5)), (0.74, 0.93, 0.08, 80, (0.6, 0.8))):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 1.0, trail=np.array(tr) / np.linalg.norm(tr))


def comp_rising_dragon(cv, rng, el):
    """伏龙翔天 (ultimate): looking up from below, the lance stands vertical and a gold dragon spirals up around it,
    head well inside the frame, maw open to the sky. Ink-to-crimson ground so the gold separates. The only cool
    light on the bar: an ice-cyan back rim on the dragon."""
    n = cv.n
    cx = n * 0.44
    ground(cv, "crimson", [], focus=(n * 0.62, n * 0.30), focus_r=0.55, focus_k=0.55, ink="#060407", wash=-80, rng=rng)
    t = np.linspace(0, 1, 90)
    ph = t * math.pi * 1.6 + 1.2
    hx = cx + np.sin(ph) * n * (0.25 - 0.06 * t)
    hy = n * 1.06 - t * n * 0.60
    path = np.c_[hx, hy][::-1]
    widths = [n * 0.15, n * 0.14, n * 0.12, n * 0.08, n * 0.03]
    dragon_body(cv, path[::5].tolist(), widths, el, k=0.8, solid_to=0.72, streaks=4, spread=1.6, value=0.95)
    H = lance_H((cx + n * 0.015, n * 1.25), (cx - n * 0.015, n * 0.30), 1.25)
    draw_lance(cv, H, el)
    front = np.cos(ph) > 0
    idx = [i for i in range(len(t)) if front[i] and 0.15 < t[i] < 0.9]
    if len(idx) > 6:
        seg = np.c_[hx[idx], hy[idx]]
        sp = spline(seg[::3], 6)
        ws = np.interp(np.linspace(0, 1, len(sp)), [0, 1], [n * (0.07 + 0.08 * (1 - t[idx[0]])), n * (0.07 + 0.08 * (1 - t[idx[-1]]))])
        m = cv.poly(ribbon(sp, ws))
        light_form(cv, m, el, 1.0, R=n * 0.03, glow_r=5, lw=(0.3, 1.8))
        cv.add(m * (1 - toward(m, 1.6, LIGHT)), KEY["cool"], 0.8)
    tipp = xf(H, [(1.0, 0.0)])[0]
    hot_core(cv, tipp[0], tipp[1], el, 2.4, 1.0)

    def bleed(c2):
        Hh = H_affine((n * 0.50, n * 0.50), -42, n * 0.25)
        m = dragon_head(c2, Hh, el, k=1.0, far_offset=(0.12, 0.04))
        c2.add(m * (1 - toward(m, 1.8, LIGHT)), KEY["cool"], 1.0)  # the one cool accent: ice-cyan back rim
    return {"bleed": bleed}


COMPS = {k[5:]: v for k, v in globals().items() if k.startswith("comp_")}


# ------------------------------------------------------------------ STATUS ICONS (same painted language)
BADGE = {
    "buff": ("#B8F0A0", "#7CD86B", "#D8B25A"),
    "debuff": ("#FF9A9A", "#E0323C", "#7A1018"),
    "cc": ("#E8D4FF", "#A85CFF", "#4A2280"),
}


def badge_shape(cv, kind):
    n = cv.n
    c = n / 2
    if kind == "buff":
        return cv.ellipse(c, c, n * 0.47)
    if kind == "cc":
        pts = [(c + math.cos(math.radians(a)) * n * 0.49, c + math.sin(math.radians(a)) * n * 0.49) for a in range(-90, 270, 60)]
        return cv.poly(pts)
    return cv.poly([(n * 0.07, n * 0.07), (n * 0.93, n * 0.07), (n * 0.93, n * 0.54), (n * 0.5, n * 0.96), (n * 0.07, n * 0.54)])


def badge_ground(cv, kind, el, rng, focus=(0.5, 0.42), k=1.0):
    """every status icon: the same neutral ink base + one soft light mass in the element colour + painted wash"""
    n = cv.n
    ground(cv, el, [], focus=(n * focus[0], n * focus[1]), focus_r=0.5, focus_k=k, ink="#0A090C", wash=-60, rng=rng)
    outer = badge_shape(cv, kind)
    inner = (blur(outer, n * 0.03) > 0.985).astype(np.float32)
    return outer, inner


def badge_finish(cv, outer, inner, kind):
    """thin metallic bevel in the polarity colour (lit top-left, shaded bottom-right) + soft polarity glow"""
    hi, midc, sh = (hexc(c) for c in BADGE[kind])
    ring = np.clip(outer - inner, 0, 1)
    X, Y = cv.grid()
    t = np.clip((X + Y) / (2 * cv.n), 0, 1)[..., None]
    grad = hi * (1 - t) * 0.45 + midc * 0.5 + sh * t * 0.5
    cv.paint(ring, grad)
    cv.paint(ring * (1 - toward(ring, 1.4, LIGHT)), sh * 0.6)
    cv.paint(ring * (1 - toward(ring, 0.9, -LIGHT)), hexc("#FFFFFF"), 0.6)
    cv.paint(np.clip(dilate(inner, 0.8) - inner, 0, 1) * outer, hexc("#05060C"), 0.85)
    cv.add(blur(ring, 3) * inner, midc, 0.35 if kind == "cc" else 0.2)
    return outer


def st_atk_up(cv, rng, el):
    """攻击提升: an up-pointing blade whose tip is a broad arrowhead, rising on crimson light"""
    n = cv.n
    for x, y0, y1, w in ((0.24, 0.86, 0.36, 0.035), (0.76, 0.84, 0.40, 0.035), (0.33, 0.95, 0.60, 0.022), (0.67, 0.95, 0.62, 0.022)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.9)
    glow(cv, cv.ellipse(n * 0.5, n * 0.24, n * 0.16), tone(el)[2], 8, 0.6)
    blade = cv.poly([(n * 0.455, n * 0.86), (n * 0.455, n * 0.40), (n * 0.30, n * 0.42), (n * 0.5, n * 0.07), (n * 0.70, n * 0.42),
                     (n * 0.545, n * 0.40), (n * 0.545, n * 0.86)])
    material(cv, blade, "steel", R=n * 0.04, lw=(0.3, 1.6), streak_ang=-90, back=tone(el)[2], back_k=0.9)
    ridge = cv.poly([(n * 0.5, n * 0.10), (n * 0.512, n * 0.42), (n * 0.505, n * 0.86), (n * 0.495, n * 0.86), (n * 0.488, n * 0.42)])
    cv.paint(ridge * blade, "#FFFFFF", 0.7)
    guard = cv.poly([(n * 0.26, n * 0.80), (n * 0.5, n * 0.74), (n * 0.74, n * 0.80), (n * 0.70, n * 0.88), (n * 0.5, n * 0.84), (n * 0.30, n * 0.88)])
    material(cv, guard, "gold", R=n * 0.03, lw=(0.3, 1.3))
    gem = cv.ellipse(n * 0.5, n * 0.81, n * 0.035)
    glow(cv, gem, "#FF2A3A", 3, 0.8)
    cv.paint(gem, "#E0202E")
    cv.add(blur(cv.ellipse(n * 0.49, n * 0.80, n * 0.015), 0.5), "#FFC8C0", 1.0)
    hot_core(cv, n * 0.5, n * 0.09, el, 1.4, 0.8, star_len=12)


def st_haste(cv, rng, el):
    """加速: a swept wing of light with speed streaks trailing it"""
    n = cv.n
    for p0, p1, w in (((0.05, 0.62), (0.55, 0.60), 0.035), ((0.08, 0.76), (0.48, 0.73), 0.028), ((0.12, 0.48), (0.40, 0.47), 0.022)):
        light_streak(cv, (n * p0[0], n * p0[1]), (n * p1[0], n * p1[1]), n * w, el, 0.9)
    feathers = []
    for i in range(5):
        a = math.radians(-160 + i * 16)
        base = np.array([n * 0.66, n * 0.60])
        L = n * (0.52 - i * 0.06)
        tip = base + np.array([math.cos(a), math.sin(a)]) * L
        mid = base + (tip - base) * 0.55 + np.array([0, -n * 0.04])
        feathers.append(cv.poly(ribbon(spline([base, mid, tip], 6), lambda t: n * 0.09 * (1 - t) ** 0.6 + 0.6)))
    for i, f in enumerate(reversed(feathers)):
        light_form(cv, f, el, 0.8 + 0.05 * i, R=n * 0.025, glow_r=3, lw=(0.2, 1.2))
    arm = cv.poly(spline([(n * 0.60, n * 0.66), (n * 0.80, n * 0.52), (n * 0.88, n * 0.30)], 6).tolist()
                  + spline([(n * 0.94, n * 0.34), (n * 0.82, n * 0.62), (n * 0.62, n * 0.74)], 6).tolist())
    light_form(cv, arm, el, 1.0, R=n * 0.03, glow_r=4, lw=(0.25, 1.4))


def st_super_armor(cv, rng, el):
    """霸体: a full gold breastplate filling the badge -- shoulders, gorget, pectoral plates, centre ridge, red gem"""
    n = cv.n
    glow(cv, cv.ellipse(n * 0.5, n * 0.52, n * 0.34), tone(el)[2], 8, 0.5)
    plate = closed_spline([(n * 0.14, n * 0.30), (n * 0.34, n * 0.20), (n * 0.42, n * 0.30), (n * 0.5, n * 0.33), (n * 0.58, n * 0.30),
                           (n * 0.66, n * 0.20), (n * 0.86, n * 0.30), (n * 0.82, n * 0.50), (n * 0.74, n * 0.70), (n * 0.5, n * 0.88),
                           (n * 0.26, n * 0.70), (n * 0.18, n * 0.50)], 6)
    m = cv.poly(plate)
    material(cv, m, "gold", R=n * 0.10, lw=(0.35, 1.9), grad=0.4)
    # pectoral split lines, centre ridge, gorget
    for pts in (((0.22, 0.46), (0.36, 0.54), (0.48, 0.52)), ((0.78, 0.46), (0.64, 0.54), (0.52, 0.52)), ((0.30, 0.68), (0.5, 0.74), (0.70, 0.68))):
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.03, n * 0.008, 6) * m, "#5A3414", 0.85)
    ridge = cv.poly([(n * 0.485, n * 0.36), (n * 0.515, n * 0.36), (n * 0.515, n * 0.82), (n * 0.5, n * 0.86), (n * 0.485, n * 0.82)])
    cv.paint(ridge * m, "#FFF2C8", 0.9)
    gorget = cv.poly(closed_spline([(n * 0.36, n * 0.27), (n * 0.5, n * 0.30), (n * 0.64, n * 0.27), (n * 0.60, n * 0.36), (n * 0.5, n * 0.39), (n * 0.40, n * 0.36)], 4))
    material(cv, gorget, "lacquer", R=n * 0.03, lw=(0.2, 1.0))
    gem = cv.ellipse(n * 0.5, n * 0.52, n * 0.06)
    glow(cv, gem, "#FF2A3A", 3, 0.9)
    cv.paint(gem, "#D2202E")
    cv.add(blur(cv.ellipse(n * 0.49, n * 0.51, n * 0.026), 0.6), "#FFC0B8", 1.1)


def st_burn(cv, rng, el):
    """灼烧: a cracked dark plate, its cracks glowing ember-hot, small flames licking up out of the cracks"""
    n = cv.n
    pal = tone(el)
    plate = cv.poly(closed_spline([(n * 0.16, n * 0.40), (n * 0.40, n * 0.34), (n * 0.66, n * 0.36), (n * 0.86, n * 0.44), (n * 0.82, n * 0.74),
                                   (n * 0.56, n * 0.86), (n * 0.30, n * 0.82), (n * 0.14, n * 0.66)], 6))
    # flames behind/above the plate, rising from the cracks
    for x0, h, lean in ((0.30, 0.30, -0.05), (0.50, 0.40, 0.03), (0.68, 0.28, 0.06), (0.40, 0.20, -0.02)):
        base = np.array([n * x0, n * 0.46])
        pts = [base, base + np.array([n * lean * 0.5 + n * 0.03, -n * h * 0.45]), base + np.array([n * lean, -n * h])]
        fm = cv.poly(ribbon(spline(pts, 6), lambda t: n * 0.11 * (1 - t) ** 0.8 + 0.4))
        soft_light(cv, fm, el, 1.0, R=n * 0.035, glow_r=4, core_k=0.8)
    material(cv, plate, "darksteel", R=n * 0.08, lw=(0.35, 1.8), grad=0.4, back=pal[2], back_k=0.8)
    cracks = _union(cv, [stroke(cv, [(n * x, n * y) for x, y in pts], n * w0, 0.3, 6) for pts, w0 in (
        (((0.30, 0.40), (0.36, 0.56), (0.30, 0.70), (0.34, 0.82)), 0.035),
        (((0.50, 0.36), (0.46, 0.52), (0.56, 0.64), (0.52, 0.84)), 0.04),
        (((0.68, 0.38), (0.62, 0.50), (0.74, 0.62)), 0.03),
        (((0.46, 0.52), (0.36, 0.56)), 0.02), (((0.56, 0.64), (0.70, 0.70)), 0.02))]) * plate
    glow(cv, cracks, pal[1], 2.5, 0.9)
    cv.paint(cracks, pal[2])
    cv.add(np.clip(blur(cracks, 0.4) * 2 - 0.8, 0, 1), pal[3], 0.9)
    for _ in range(6):
        x, y = rng.uniform(0.25, 0.8) * n, rng.uniform(0.08, 0.3) * n
        cv.add(blur(cv.ellipse(x, y, rng.uniform(0.8, 1.5)), 0.4), "#FFD86A", 1.2)


def st_def_down(cv, rng, el):
    """破防: a steel shield split in two by a red crack"""
    n = cv.n
    left = [(n * 0.20, n * 0.18), (n * 0.48, n * 0.12), (n * 0.44, n * 0.30), (n * 0.52, n * 0.46), (n * 0.42, n * 0.62),
            (n * 0.47, n * 0.88), (n * 0.40, n * 0.84), (n * 0.22, n * 0.64), (n * 0.17, n * 0.40)]
    right = [(n * 0.55, n * 0.13), (n * 0.82, n * 0.19), (n * 0.84, n * 0.40), (n * 0.78, n * 0.64), (n * 0.58, n * 0.86),
             (n * 0.52, n * 0.62), (n * 0.62, n * 0.46), (n * 0.53, n * 0.30)]
    crack = cv.poly(ribbon([(n * 0.52, n * 0.06), (n * 0.48, n * 0.30), (n * 0.57, n * 0.46), (n * 0.47, n * 0.62), (n * 0.53, n * 0.92)], [1, 4, 3.5, 3.5, 0.5]))
    soft_light(cv, crack, "steel", 0.9, R=1.2, glow_r=5)
    Hr = H_affine((n * 0.06, n * 0.04), 7, 1.0)
    for pts, H in ((left, np.eye(3)), (right, Hr)):
        m = cv.poly(xf(H, pts))
        material(cv, m, "steel", R=n * 0.06, lw=(0.3, 1.7), back="#FF6A6A", back_k=0.9, grad=0.4)
        cv.paint(np.clip(m - toward(m, 1.6, (0.0, -1.0)), 0, 1), "#D8B25A", 0.9)


def st_slow(cv, rng, el):
    """减速: a frost-bound hourglass -- gold frame, ice-blue sand frozen mid-fall, ice crystals crusting the frame"""
    n = cv.n
    pal = tone(el)
    glow(cv, cv.ellipse(n * 0.5, n * 0.5, n * 0.3), pal[1], 8, 0.5)
    bulb = cv.poly(closed_spline([(n * 0.32, n * 0.24), (n * 0.68, n * 0.24), (n * 0.62, n * 0.40), (n * 0.53, n * 0.50), (n * 0.62, n * 0.60),
                                  (n * 0.68, n * 0.76), (n * 0.32, n * 0.76), (n * 0.38, n * 0.60), (n * 0.47, n * 0.50), (n * 0.38, n * 0.40)], 6))
    material(cv, bulb, "glass", R=n * 0.06, lw=(0.2, 1.0), grad=0.3)
    sand = cv.poly(closed_spline([(n * 0.37, n * 0.74), (n * 0.63, n * 0.74), (n * 0.58, n * 0.64), (n * 0.5, n * 0.60), (n * 0.42, n * 0.64)], 4))
    cv.paint(sand * bulb, "#BFF2FF")
    cv.paint(cv.poly([(n * 0.40, n * 0.30), (n * 0.60, n * 0.30), (n * 0.5, n * 0.42)]) * bulb, "#BFF2FF", 0.9)
    cv.paint(stroke(cv, [(n * 0.5, n * 0.44), (n * 0.5, n * 0.62)], n * 0.018, n * 0.01), "#E8FBFF")
    for y in (0.17, 0.83):
        cap = cv.poly(closed_spline([(n * 0.22, n * (y - 0.05)), (n * 0.78, n * (y - 0.05)), (n * 0.80, n * (y + 0.05)), (n * 0.20, n * (y + 0.05))], 3))
        material(cv, cap, "gold", R=n * 0.03, lw=(0.3, 1.5))
    for x in (0.27, 0.73):
        post = cv.poly([(n * (x - 0.025), n * 0.2), (n * (x + 0.025), n * 0.2), (n * (x + 0.025), n * 0.8), (n * (x - 0.025), n * 0.8)])
        material(cv, post, "gold", R=n * 0.02, lw=(0.3, 1.3))
    # ice crust: shards growing off the frame corners, rime along the top cap
    for cx_, cy_, a0 in ((0.27, 0.21, -135), (0.73, 0.79, 45), (0.73, 0.21, -45), (0.27, 0.79, 135), (0.5, 0.86, 90)):
        for j, (da, L, w) in enumerate(((0, 0.14, 0.07), (-40, 0.10, 0.05), (40, 0.09, 0.05))):
            a = math.radians(a0 + da)
            b = np.array([n * cx_, n * cy_])
            tp = b + np.array([math.cos(a), math.sin(a)]) * n * L
            nv = np.array([-math.sin(a), math.cos(a)]) * n * w * 0.5
            shard = cv.poly([b + nv, b + (tp - b) * 0.7 + nv * 0.9, tp, b + (tp - b) * 0.7 - nv * 0.9, b - nv])
            glow(cv, shard, pal[2], 2, 0.35)
            paint_form(cv, shard, ["#3C7EAA", "#8CCBE6", "#DDF6FF", "#FFFFFF"], R=n * 0.02, tilt=tuple(LIGHT2 * 0.4), grad=0.5)
            ink_line(cv, shard, "#0A2A40", 0.2, 1.0, 0.3)
    rime = cv.poly(ribbon(spline([(n * 0.22, n * 0.12), (n * 0.5, n * 0.10), (n * 0.78, n * 0.12)], 6), [n * 0.02, n * 0.04, n * 0.02]))
    cv.paint(rime * (0.6 + 0.4 * cv.noise2), "#F0FCFF", 0.9)


def st_stun(cv, rng, el):
    """眩晕: three gold stars circling a glowing spiral (no birds: they do not read at 28 px)"""
    n = cv.n
    c = (n * 0.5, n * 0.54)
    t = np.linspace(0, 1, 140)
    ang = t * math.pi * 4.4
    r = n * (0.03 + 0.24 * t)
    pts = np.c_[c[0] + np.cos(ang) * r, c[1] + np.sin(ang) * r * 0.85]
    sp = cv.poly(ribbon(pts, lambda u: 1.0 + 6.0 * u))
    soft_light(cv, sp, el, 1.0, R=1.0, glow_r=4)
    orb = arc_pts(c[0], c[1] - n * 0.06, n * 0.38, 0, 360, 96, n * 0.15)
    cv.add(cv.poly(ribbon(orb, [1.6] * 96)), "#FFE9A8", 0.35)
    for a_deg, s in ((205, 0.17), (325, 0.15), (85, 0.19)):
        a = math.radians(a_deg)
        x, y = c[0] + math.cos(a) * n * 0.38, c[1] - n * 0.06 + math.sin(a) * n * 0.15
        sp_ = []
        for i in range(10):
            aa = math.radians(-90 + i * 36)
            rr = n * s * (1.0 if i % 2 == 0 else 0.45)
            sp_.append((x + math.cos(aa) * rr, y + math.sin(aa) * rr))
        m = cv.poly(sp_)
        glow(cv, m, "#FFC43A", 3, 0.7)
        material(cv, m, "gold", R=n * s * 0.3, lw=(0.25, 1.3), brk=0.2)


STATUS = {k[3:]: v for k, v in globals().items() if k.startswith("st_")}


# ------------------------------------------------------------------ driver
def render_skill(ic, idx):
    rng = np.random.default_rng(1000 + idx * 37)
    cv = Canvas(256, seed=idx * 101)
    res = COMPS[ic["comp"]](cv, rng, ic["element"]) or {}
    kind = ic["kind"]
    if kind == "ultimate":
        alpha = frame_ultimate(cv, rng)
    elif kind == "passive":
        alpha = frame_passive(cv)
    else:
        alpha = frame_skill(cv)
    if "bleed" in res:
        res["bleed"](cv)
    return cv, alpha


def render_status(ic, idx):
    rng = np.random.default_rng(5000 + idx * 31)
    cv = Canvas(128, seed=idx * 53)
    outer, inner = badge_ground(cv, ic["kind"], ic["element"], rng)
    STATUS[ic["comp"]](cv, rng, ic["element"])
    badge_finish(cv, outer, inner, ic["kind"])
    return cv, outer


def save(cv, alpha, path_base, px):
    rgb = tonemap(cv.c)
    a = np.clip(alpha, 0, 1)[..., None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), a], axis=2)
    img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    big = img.resize((px * 2, px * 2), Image.LANCZOS)
    small = img.resize((px, px), Image.LANCZOS)
    big.save(path_base + "@2x.png")
    small.save(path_base + ".png")
    return small


# ------------------------------------------------------------------ QA (style sheet section 6)
def grey32(img):
    bg = Image.new("RGBA", img.size, (15, 18, 26, 255))
    bg.alpha_composite(img)
    return np.asarray(bg.convert("L").resize((32, 32), Image.LANCZOS), np.float64) / 255.0


def ssim(a, b, win=7):
    """mean SSIM over a sliding Gaussian window (Wang et al. 2004), single scale"""
    g = np.exp(-((np.arange(win) - win // 2) ** 2) / (2 * 1.5 ** 2))
    g /= g.sum()

    def f(x):
        x = np.apply_along_axis(lambda r: np.convolve(r, g, "valid"), 0, x)
        return np.apply_along_axis(lambda r: np.convolve(r, g, "valid"), 1, x)
    C1, C2 = 0.01 ** 2, 0.03 ** 2
    ma, mb = f(a), f(b)
    va, vb, cab = f(a * a) - ma * ma, f(b * b) - mb * mb, f(a * b) - ma * mb
    s = ((2 * ma * mb + C1) * (2 * cab + C2)) / ((ma * ma + mb * mb + C1) * (va + vb + C2))
    return float(s.mean())


def ssim_gate(made, limit=0.6, kinds=("skill", "ultimate", "passive"), label="skills"):
    items = [(ic, img) for ic, img in made if ic["kind"] in kinds]
    g = [grey32(img) for _, img in items]
    worst, fails = 0.0, []
    print("SSIM 32px greyscale, %s (fail > %.2f)" % (label, limit))
    for i in range(len(g)):
        row = []
        for j in range(len(g)):
            s = ssim(g[i], g[j]) if i != j else 1.0
            row.append("%.2f" % s)
            if j > i:
                worst = max(worst, s)
                if s > limit:
                    fails.append((items[i][0]["id"], items[j][0]["id"], s))
        print("  %-34s %s" % (items[i][0]["id"], " ".join(row)))
    print("SSIM max pair %.3f -> %s" % (worst, "PASS" if not fails else "FAIL " + str(fails)))
    return not fails, worst


def _on_bg(img, size):
    bg = Image.new("RGBA", img.size, (15, 18, 26, 255))
    bg.alpha_composite(img)
    return bg.resize((size, size), Image.LANCZOS)


def qa_sheet(made, path):
    """rows: native | 32 px colour | 32 px greyscale | SQUINT (skills: 24 px, blurred) | status 28 px greyscale.
    Also writes <path>_naming.png: the unlabelled, numbered sheet for the human naming test (ICON_STYLE 6.2)."""
    cell = 140
    W = cell * len(made) + 20
    sheet = Image.new("RGBA", (W, 520), (15, 18, 26, 255))
    for k, (ic, img) in enumerate(made):
        x0 = 10 + k * cell
        sheet.alpha_composite(img, (x0 + (cell - img.width) // 2, 10))
        up = img.resize((32, 32), Image.LANCZOS).resize((96, 96), Image.NEAREST)
        sheet.alpha_composite(up, (x0 + 22, 150))
        sheet.alpha_composite(up.convert("LA").convert("RGBA"), (x0 + 22, 262))
        if ic["kind"] in ("skill", "ultimate", "passive"):
            sq = _on_bg(img, 24).filter(ImageFilter.GaussianBlur(0.8)).resize((96, 96), Image.NEAREST)
        else:
            sq = _on_bg(img, 28).convert("L").convert("RGBA").resize((96, 96), Image.NEAREST)
        sheet.alpha_composite(sq, (x0 + 22, 380))
    sheet.save(path)
    skills = [img for ic, img in made if ic["kind"] in ("skill", "ultimate", "passive")]
    if skills:
        nm = Image.new("RGBA", (len(skills) * 84 + 12, 96), (15, 18, 26, 255))
        d = ImageDraw.Draw(nm)
        for i, img in enumerate(skills):
            nm.alpha_composite(img.resize((64, 64), Image.LANCZOS), (12 + i * 84, 8))
            d.text((12 + i * 84 + 28, 76), str(i + 1), fill=(220, 226, 236, 255))
        nm.save(os.path.splitext(path)[0] + "_naming.png")


def main():
    a = sys.argv[1:]
    spec_path = a[0] if len(a) > 0 and a[0] else os.path.join(ROOT, "assets", "icons", "icons.json")
    out_dir = a[1] if len(a) > 1 and a[1] else os.path.join(ROOT, "assets", "icons", "out")
    qa = a[2] if len(a) > 2 else ""
    only = a[3].split(",") if len(a) > 3 and a[3] else None
    os.makedirs(out_dir, exist_ok=True)
    spec = json.load(open(spec_path, encoding="utf-8"))
    global KEY
    KEY = CLASS_KEYS[spec.get("class", "battle_mage")]
    made = []
    for i, ic in enumerate(spec["icons"]):
        if only and ic["id"] not in only:
            continue
        if ic["kind"] in ("skill", "ultimate", "passive"):
            cv, alpha = render_skill(ic, i)
            img = save(cv, alpha, os.path.join(out_dir, ic["id"]), 128)
        else:
            cv, alpha = render_status(ic, i)
            img = save(cv, alpha, os.path.join(out_dir, ic["id"]), 64)
        made.append((ic, img))
        print("icon", ic["id"], flush=True)
    if qa:
        qa_sheet(made, qa)
        print("QA", qa)
    ok, _ = ssim_gate(made)
    ok2, _ = ssim_gate(made, 0.6, ("buff", "debuff", "cc"), "status")
    if not (ok and ok2) and not only:
        sys.exit(2)


if __name__ == "__main__":
    main()
