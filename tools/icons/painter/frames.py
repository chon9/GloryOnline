"""painter.frames - generator-owned frames and badges (ICON_STYLE.md section 7). Never per skill.

  frame_skill / frame_ultimate / frame_passive   skill frames (chamfered navy/silver, gold HUD ornament, bronze ring)
  badge_ground / badge_finish                    status badges (buff round, debuff shield, cc hexagon)
  emblem_crest                                   class emblem crest (gold-on-navy, group shape, crystal gems, sunburst)
"""
import math

import numpy as np

from painter.core import *  # noqa: F401,F403


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
    orn = union(cv, [hud_corner(cv, 2, 2, 1, 1, s), hud_corner(cv, n - 2, 2, -1, 1, s),
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


# ------------------------------------------------------------------ status badges
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


# ------------------------------------------------------------------ class emblem crest (bible 7.4)
# Gold-on-navy crest; the shape encodes the class group. A gold double border, blue crystal side gems, a spiky
# gold sunburst behind the base. The class weapon (comps/_emblems.py) sits inside on the class's light mass.
def _crest_pts(group, n):
    s = n / 256.0
    P = lambda pts: [(x * s, y * s) for x, y in pts]
    if group == "swordsman":   # heater shield
        side = spline([(34, 26), (34, 120), (58, 190), (128, 240)], 10).tolist()
        right = [(256 - x, y) for x, y in side[::-1]]
        return P(side + right[1:] + [(128, 20)])
    if group == "mage":        # tall diamond with softened sides
        return P(closed_spline([(128, 8), (196, 70), (238, 128), (196, 186), (128, 248), (60, 186), (18, 128), (60, 70)], 3).tolist())
    if group == "gunner":      # chamfered badge
        return P([(64, 20), (192, 20), (232, 62), (232, 156), (128, 240), (24, 156), (24, 62)])
    if group == "fighter":     # medallion
        return P([(128 + math.cos(a) * 108, 126 + math.sin(a) * 108) for a in np.linspace(0, 2 * math.pi, 72, endpoint=False)])
    if group == "nightwalker":  # ogee-topped kite
        left = spline([(128, 10), (96, 40), (44, 62), (40, 140), (128, 246)], 10).tolist()
        right = [(256 - x, y) for x, y in left[::-1]]
        return P(left + right[1:-1])
    if group == "priest":      # crowned shield
        side = spline([(30, 40), (34, 130), (62, 196), (128, 244)], 10).tolist()
        right = [(256 - x, y) for x, y in side[::-1]]
        crown = [(226, 40), (186, 58), (158, 22), (128, 52), (98, 22), (70, 58), (30, 40)]
        return P(side + right[1:] + crown[1:-1])
    # unspecialized: eight-point star-octagon (every class's forms)
    pts = []
    for i in range(16):
        a = math.radians(-90 + i * 22.5)
        r = 118 if i % 2 == 0 else 96
        pts.append((128 + math.cos(a) * r, 128 + math.sin(a) * r))
    return P(pts)


def emblem_ground(cv, group, key, rng):
    """navy-glass crest interior + the class light mass + a low-contrast painted wash. Returns (outer, inner)."""
    n = cv.n
    X, Y = cv.grid()
    outer = cv.poly(_crest_pts(group, n))
    inner = (blur(outer, n * 0.045) > 0.985).astype(np.float32)
    t = np.clip(Y / n, 0, 1)[..., None]
    cv.c = hexc("#0B1222") * (1 - t) + hexc("#1E2440") * t
    lc, cc = key.get("emblem", (key["accent"], key["metal_hi"]))
    d2 = ((X - n * 0.5) ** 2 + (Y - n * 0.48) ** 2) / (n * 0.42) ** 2
    cv.add(np.exp(-d2 * 2.0), lc, 0.55)
    cv.add(np.exp(-d2 * 7.0), cc, 0.30)
    for i in range(18):
        a = math.radians(-45 + rng.uniform(-12, 12))
        d = np.array([math.cos(a), math.sin(a)])
        c = np.array([rng.uniform(0.1, 0.9) * n, rng.uniform(0.1, 0.9) * n])
        L = rng.uniform(0.3, 0.7) * n
        W = rng.uniform(0.04, 0.10) * n
        m = blur(cv.poly(ribbon(spline([c - d * L / 2, c, c + d * L / 2], 6), lambda u: W * math.sin(math.pi * u) ** 0.6 + 0.5)), 1.6)
        m = m * (0.55 + 0.45 * streak_field(cv.w, math.degrees(a), 60, 4, cv.seed()))
        cv.paint(m, mix("#05080F", lc, rng.uniform(0.0, 0.25)), 0.18 * rng.uniform(0.6, 1.3))
    u = (X / n) * 2 - 1
    w_ = (Y / n) * 2 - 1
    vg = np.clip((np.sqrt(u * u + w_ * w_) - 0.55) * 1.4, 0, 1)
    cv.c *= (1 - 0.5 * vg)[..., None]
    return outer, inner


def emblem_finish(cv, outer, inner, group, key):
    """gold double border, crystal gems, sunburst base. Returns alpha."""
    n = cv.n
    X, Y = cv.grid()
    # sunburst behind the base (outside the crest only)
    rays = np.zeros_like(outer)
    rows = np.nonzero(outer.max(axis=1) > 0.5)[0]
    by = rows[-1] / SS if len(rows) else n * 0.9
    cx, cy = n * 0.5, by - n * 0.20
    for i, a in enumerate(np.linspace(28, 152, 11)):
        ar = math.radians(a)
        L = n * (0.34 if i % 2 == 0 else 0.27)
        w = n * (0.035 if i % 2 == 0 else 0.025)
        d = np.array([math.cos(ar), math.sin(ar)])
        nv = np.array([-d[1], d[0]])
        p0 = np.array([cx, cy])
        rays = np.maximum(rays, cv.poly([p0 + nv * w, p0 + d * L, p0 - nv * w]))
    rays = np.clip(rays * (Y <= n - 1) - outer, 0, 1)
    rays = rays * (cv.ellipse(n * 0.5, n * 0.5, n * 0.5) > 0.5)
    ink_line(cv, rays, "#2A1606", 0.3, 1.4, 0.0)
    paint_form(cv, rays, ["#5A3414", "#A8783A", "#D8B25A", "#FFE9A8"], R=2.0, grad=0.6)
    # double border
    ring = np.clip(outer - inner, 0, 1)
    ink_line(cv, outer, "#1A0E04", 0.4, 2.2, 0.0)
    paint_form(cv, ring, ["#5A3414", "#8A5A2B", "#D8B25A", "#FFE9A8"], R=n * 0.02, grad=0.5,
               spec=[("#FFF6D0", 8, 0.35, 0.65, 0.7)])
    groove = np.clip(dilate(inner, n * 0.018) - dilate(inner, n * 0.009), 0, 1) * outer
    cv.paint(groove, "#3A1C08", 0.85)
    edge_in = np.clip(dilate(inner, 1.2) - inner, 0, 1)
    cv.paint(edge_in, "#05060C", 0.9)
    sweep = np.exp(-(((X - Y) / n - 0.25) ** 2) * 40)
    cv.add(ring * sweep, "#FFE9A8", 0.35)
    # crystals: left/right side gems on the border + one top gem
    gems = np.zeros_like(outer)
    rows_mid = outer[int(n * 0.45 * SS)]
    xs = np.nonzero(rows_mid > 0.5)[0]
    spots = []
    if len(xs):
        spots += [(xs[0] / SS + n * 0.012, n * 0.45), (xs[-1] / SS - n * 0.012, n * 0.45)]
    cols_mid = outer[:, int(n * 0.5 * SS)]
    ys = np.nonzero(cols_mid > 0.5)[0]
    if len(ys) and group not in ("priest",):
        spots.append((n * 0.5, ys[0] / SS + n * 0.012))
    elif group == "priest":
        spots.append((n * 0.5, n * 0.205))
    for gx, gy in spots:
        rx, ry = n * 0.028, n * 0.040
        mg = cv.poly([(gx, gy - ry), (gx + rx, gy), (gx, gy + ry), (gx - rx, gy)])
        cv.add(blur(mg, 5), "#3FA9FF", 0.6)
        cv.paint(np.clip(dilate(mg, 1.6) - mg, 0, 1), "#D8B25A")
        cv.paint(mg, "#2F8FE0")
        cv.paint(cv.poly([(gx, gy - ry), (gx + rx, gy), (gx, gy)]), "#9FDCFF")
        cv.paint(cv.poly([(gx, gy), (gx - rx, gy), (gx, gy + ry)]), "#174E8A")
        gems = np.maximum(gems, dilate(mg, 1.6))
    return np.clip(np.maximum(np.maximum(outer, rays), gems), 0, 1)
