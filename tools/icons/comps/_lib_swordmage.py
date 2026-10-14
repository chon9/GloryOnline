"""_lib_swordmage - reusable drawers for the berserker, spellblade, ghostblade, elementalist and summoner bars.

Imported explicitly by those comps files (never auto-discovered). Everything paints with the active class key via
tone(), so the same drawer stays inside each bar's palette.

  greatsword / tachi / short_sword   the three class blades (thin wrappers over painter.weapons.sword)
  bolt_path / lightning              a jagged branching lightning bolt painted as light
  rune_ring                          a magic circle in perspective: double ring, ticks, inner star polygon
  crystal                            a faceted ice crystal prism (glass ramp, lit facet + shadow facet)
  droplet / droplets                 painted liquid drops (blood, poison) with a lit cap and a tail
  flame                              a flame tongue as a solid 4-value light form with curling tips
  wisp                               a spirit wisp: round head, tapering curled tail, hot core
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403


# ------------------------------------------------------------------ blades
def greatsword(cv, H, el, rune=None):
    """狂剑士 greatsword: very broad, a blood groove; local x 0 butt -> 1 tip"""
    return sword(cv, H, el, blade="broad", guard="cross", blade_mat="steel", width=0.075, blade_from=0.22,
                 rune=rune, grip_mat="leather", guard_mat="bronze" if "bronze" in MAT else "gold")


def tachi(cv, H, el, rune=None):
    """鬼剑士 tachi: slim, single edge, gentle curve, round tsuba"""
    return sword(cv, H, el, blade="curved", guard="tsuba", blade_mat="steel", width=0.028, blade_from=0.20, curve=0.05,
                 rune=rune, grip_mat="leather", guard_mat="darksteel")


def short_sword(cv, H, el, rune=None):
    """魔剑士 short sword: leaf blade, gold winged guard, rune fuller"""
    return sword(cv, H, el, blade="leaf", guard="wings", blade_mat="steel", width=0.05, blade_from=0.26, rune=rune,
                 grip_mat="leather", guard_mat="gold")


# ------------------------------------------------------------------ lightning
def bolt_path(rng, p0, p1, depth=5, jag=0.22):
    """midpoint-displacement polyline from p0 to p1"""
    pts = [np.array(p0, float), np.array(p1, float)]
    amp = jag
    for _ in range(depth):
        out = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            d = b - a
            L = float(np.linalg.norm(d))
            nv = np.array([-d[1], d[0]]) / (L + 1e-9)
            m = (a + b) / 2 + nv * L * amp * rng.uniform(-1, 1)
            out += [m, b]
        pts = out
        amp *= 0.55
    return np.array(pts)


def lightning(cv, rng, p0, p1, w, el, k=1.0, branches=2, jag=0.22, depth=5):
    """a jagged bolt painted as light: wide bloom, saturated body, white core; a few thinner forks"""
    pts = bolt_path(rng, p0, p1, depth, jag)
    m = cv.poly(ribbon(pts, lambda t: max(0.5, w * (0.45 + 0.55 * math.sin(math.pi * min(1.0, t * 1.05 + 0.08))))))
    soft_light(cv, m, el, k, R=max(0.8, w * 0.35), glow_r=max(3.0, w * 1.6), core_k=1.2)
    for _ in range(branches):
        i = int(rng.integers(len(pts) // 5, len(pts) * 3 // 4))
        a = pts[i]
        d = pts[min(len(pts) - 1, i + 6)] - a
        ang = math.atan2(d[1], d[0]) + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
        L = float(np.linalg.norm(np.array(p1) - np.array(p0))) * rng.uniform(0.18, 0.32)
        b = a + np.array([math.cos(ang), math.sin(ang)]) * L
        bp = bolt_path(rng, a, b, 4, 0.28)
        bm = cv.poly(ribbon(bp, lambda t: max(0.4, w * 0.45 * (1 - t))))
        soft_light(cv, bm, el, 0.8 * k, R=max(0.6, w * 0.15), glow_r=max(2.0, w * 0.8), core_k=0.9)
        m = np.maximum(m, bm)
    return m


# ------------------------------------------------------------------ magic circle
def rune_ring(cv, c, rx, ry, el, k=1.0, w=None, ticks=24, star=6, spin=0.0, inner=0.78):
    """a magic circle seen in perspective (ry < rx): outer + inner ring, tick band between, a star polygon inside.
    Painted as light. Returns the mask."""
    n = cv.n
    w = w or n * 0.012
    c = np.asarray(c, float)
    parts = []
    for r, ww in ((1.0, w), (inner, w * 0.7)):
        parts.append(cv.poly(ribbon(np.r_[arc_pts(c[0], c[1], rx * r, 0, 360, 96, ry * r)], [ww] * 96)))
    for i in range(ticks):
        a = math.radians(spin + i * 360.0 / ticks)
        r0, r1 = inner + 0.04, 0.96 if i % 3 == 0 else 0.90
        p0 = c + np.array([math.cos(a) * rx * r0, math.sin(a) * ry * r0])
        p1 = c + np.array([math.cos(a) * rx * r1, math.sin(a) * ry * r1])
        parts.append(cv.poly(ribbon([p0, p1], [w * 0.8, w * 0.5])))
    if star:
        step = 2 if star >= 5 else 1
        vs = [c + np.array([math.cos(math.radians(spin + 90 + i * 360.0 / star)) * rx * inner * 0.96,
                            math.sin(math.radians(spin + 90 + i * 360.0 / star)) * ry * inner * 0.96]) for i in range(star)]
        for i in range(star):
            a, b = vs[i], vs[(i + step) % star]
            parts.append(cv.poly(ribbon([a, b], [w * 0.6, w * 0.6])))
    m = union(cv, parts)
    soft_light(cv, m, el, k, R=max(0.6, w * 0.3), glow_r=max(2.5, w * 0.6), core_k=0.8)
    return m


# ------------------------------------------------------------------ ice crystal
ICE = ["#1E4A78", "#4E9AC8", "#A8E6FA", "#F2FDFF"]


def crystal(cv, base, ang, h, w, ramp=ICE, line_col="#0A2238", k=1.0, glow_c=None):
    """a faceted crystal prism growing from base along ang (deg): hexagonal outline, pointed tip, the lit facet left
    of the ridge, the shadow facet right of it"""
    a = math.radians(ang)
    d = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-d[1], d[0]])
    b = np.asarray(base, float)
    pts = [b - nv * w * 0.45, b - nv * w * 0.5 + d * h * 0.70, b + d * h, b + nv * w * 0.5 + d * h * 0.70, b + nv * w * 0.45]
    m = cv.poly(pts)
    if glow_c is not None:
        glow(cv, m, glow_c, max(2.0, w * 0.5), 0.5 * k)
    ink_line(cv, m, line_col, 0.25, max(0.8, w * 0.10), 0.35)
    ridge = [b + nv * w * 0.06, b + nv * w * 0.04 + d * h * 0.72, b + d * h]
    lit_side = 1 if (nv @ LIGHT2) > 0 else -1
    fa = cv.poly([pts[0] if lit_side < 0 else pts[4], pts[1] if lit_side < 0 else pts[3], b + d * h] + ridge[::-1][1:]) * m
    fb = np.clip(m - fa, 0, 1)
    paint_form(cv, fa, [ramp[1], ramp[2], ramp[3]], R=max(0.8, w * 0.15), tilt=tuple(LIGHT2 * 0.5), grad=0.5, thr=[0.3, 0.75])
    paint_form(cv, fb, [ramp[0], ramp[1], ramp[2]], R=max(0.8, w * 0.15), tilt=tuple(-LIGHT2 * 0.5), grad=0.5, thr=[0.35, 0.8])
    cv.paint(cv.poly(ribbon(ridge, [max(0.4, w * 0.05)] * 3)) * m, ramp[3], 0.7)
    return m


# ------------------------------------------------------------------ liquid
def droplet(cv, x, y, r, ang, ramp, line_col, tail=1.6, glow_c=None, k=1.0):
    """a flying drop: round head, tapered tail pointing back along -ang"""
    a = math.radians(ang)
    d = np.array([math.cos(a), math.sin(a)])
    p = np.array([x, y], float)
    tail_m = cv.poly(ribbon([p - d * r * tail * 2.2, p - d * r * tail, p], [0.3, r * 0.9, r * 1.9]))
    m = np.maximum(cv.ellipse(x, y, r), tail_m)
    if glow_c is not None:
        glow(cv, m, glow_c, max(1.5, r * 0.8), 0.5 * k)
    ink_line(cv, m, line_col, 0.2, max(0.6, r * 0.25), 0.3)
    paint_form(cv, m, ramp, R=max(0.8, r * 0.6), grad=0.5, tilt=(-0.2, -0.3))
    cv.add(cv.ellipse(x - r * 0.35, y - r * 0.35, r * 0.28), "#FFFFFF", 0.7 * k)
    return m


BLOOD = ["#2A0206", "#6A0A12", "#C01E2A", "#FF6A5E"]


def droplets(cv, rng, c, count, r0, r1, a_range, size, ramp=BLOOD, line_col="#1A0104", glow_c=None):
    c = np.asarray(c, float)
    out = []
    for _ in range(count):
        a = rng.uniform(*a_range)
        rr = rng.uniform(r0, r1)
        p = c + np.array([math.cos(math.radians(a)), math.sin(math.radians(a))]) * rr
        out.append(droplet(cv, p[0], p[1], size * rng.uniform(0.5, 1.0), a, ramp, line_col, glow_c=glow_c))
    return out


# ------------------------------------------------------------------ flame
def flame(cv, base, h, w, el, rng, lean=0.0, tongues=4, k=1.0, value=1.0, bulb=1.0):
    """a flame body: a broad teardrop base and several tapering tongues curling up, painted as solid light"""
    b = np.asarray(base, float)
    parts = [cv.ellipse(b[0], b[1] - h * 0.16 * bulb, w * 0.5, h * 0.2 * bulb)]
    for i in range(tongues):
        t = (i + 0.5) / tongues - 0.5
        x0 = b[0] + t * w * 0.8
        L = h * (1.0 - abs(t) * 1.1) * rng.uniform(0.8, 1.0)
        sway = rng.uniform(-1, 1) * w * 0.12
        pts = [(x0, b[1] - h * 0.05), (x0 + sway + lean * L * 0.3, b[1] - L * 0.45), (x0 - sway * 0.5 + lean * L * 0.6, b[1] - L * 0.8),
               (x0 + sway + lean * L * 0.8 + w * 0.06 * np.sign(t + 1e-3), b[1] - L)]
        ww = w * (0.42 - abs(t) * 0.25)
        parts.append(cv.poly(ribbon(spline(pts, 8), lambda u: ww * (1 - u) ** 0.8 + 0.4)))
    m = union(cv, parts)
    light_form(cv, m, el, k, R=max(1.0, w * 0.12), glow_r=max(4.0, w * 0.3), lw=(0.25, 1.4), value=value)
    return m


# ------------------------------------------------------------------ spirit wisp
def wisp(cv, head, r, tail_dir, tail_len, el, k=1.0, curl=0.6):
    """round glowing head with a tapered tail curling behind it"""
    h = np.asarray(head, float)
    a = math.atan2(tail_dir[1], tail_dir[0])
    pts = []
    for i in range(7):
        t = i / 6.0
        aa = a + curl * t * t * 1.4
        pts.append(h + np.array([math.cos(aa), math.sin(aa)]) * tail_len * t)
    tail_m = cv.poly(ribbon(spline(pts, 6), lambda u: r * 1.8 * (1 - u) ** 1.2 + 0.4))
    m = np.maximum(cv.ellipse(h[0], h[1], r), tail_m)
    light_form(cv, m, el, k, R=max(1.0, r * 0.5), glow_r=max(3.0, r * 0.7), lw=(0.25, 1.3))
    hot_core(cv, h[0] - r * 0.15, h[1] - r * 0.15, el, max(0.6, r / 9.0), 0.6 * k, star=False)
    return m
