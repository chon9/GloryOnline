"""painter.fx - shared painted effect shapes for skill compositions (reuse across classes).

  crescent(cv, c, rx, ry, rot, a0, a1, width, el)   slash arc / swing smear: tail (a0) thin and streaky, head (a1) thick
                                                    with a white-hot leading rim. Angles in degrees, ellipse frame
                                                    rotated by `rot`.
  burst(cv, rng, c, r, el)                          cel explosion: stacked painted fire puffs, dark smoke behind, hot core
  trail(cv, pts, w0, w1, el)                        comet / projectile trail: soft light ribbon, brightest at the head
  smoke(cv, rng, pts, r, colour)                    soft smoke puffs along a path
  sparks(cv, rng, c, n, length, el)                 short radial spark streaks with hot heads
  speed_lines(cv, rng, ang, count, el)              background motion streaks along a direction
"""
import math

import numpy as np

from painter.core import *  # noqa: F401,F403
from painter.core import union
from painter.subjects import flare_spikes, hot_core, shock_ring  # noqa: F401


def _rot(rot):
    r = math.radians(rot)
    return np.array([math.cos(r), math.sin(r)]), np.array([-math.sin(r), math.cos(r)])


def crescent(cv, c, rx, ry, rot, a0, a1, width, el, k=1.0, head_k=1.0, rim=True, streak_freq=85.0):
    """painted slash smear along an elliptical arc from a0 (tail) to a1 (head), the 圆舞棍 technique: a polar field,
    streaky and dissolving at the tail, solid and white-hot at the leading edge. width = max thickness as a fraction
    of the radius (grows toward the head). Angles in degrees in the ellipse frame rotated by `rot` (y down, so 90 is
    the bottom). Sweeps may run either way and wrap past 360. Returns the smear mask."""
    n = cv.n
    pal = tone(el)
    u, v = _rot(rot)
    X, Y = cv.grid()
    dx, dy = X - c[0], Y - c[1]
    lx = (dx * u[0] + dy * u[1]) / rx
    ly = (dx * v[0] + dy * v[1]) / ry
    ang = np.degrees(np.arctan2(ly, lx))
    sweep = float(a1 - a0)
    sgn = 1.0 if sweep >= 0 else -1.0
    t = (((ang - a0) * sgn) % 360.0) / abs(sweep)
    valid = t <= 1.0
    t = np.where(valid, t, 0.0)
    rho = np.sqrt(lx * lx + ly * ly)
    wt = width * (0.06 + 0.94 * smoothstep(0.0, 0.7, t) ** 0.9) * (1 - smoothstep(0.94, 1.0, t) * 0.7)
    inside = smoothstep(wt, wt * 0.55, 1.0 - rho) * smoothstep(-0.05, 0.02, 1.0 - rho)
    head_cap = smoothstep(1.0, 0.985, t)
    m = (inside * valid * head_cap * (t > 0.003)).astype(np.float32)
    streaky = 0.5 + 0.5 * np.sin(rho * streak_freq + cv.noise * 9.0)
    field = np.where(t < 0.62, (streaky ** 2.2) * smoothstep(0.0, 0.62, t) + smoothstep(0.35, 0.62, t) * 0.6, 1.0)
    inten = 0.35 + 0.75 * t ** 1.4
    mm = m * np.clip(field, 0, 1)
    s = n / 256.0
    cv.add(blur(m * inten, 7 * s), pal[1], 0.8 * k)
    cv.add(blur(mm * inten, 2 * s), pal[2], 1.1 * k)
    cv.add(mm * inten * smoothstep(0.3, 1.0, t), mix(pal[2], pal[3], 0.5), 0.9 * k)
    edge_in = smoothstep(wt * 0.6, wt * 0.2, 1.0 - rho) * mm
    cv.add(edge_in * inten, pal[3], 0.5 * k)
    if rim:
        rimw = 0.06 * smoothstep(0.55, 1.0, t)
        rm = smoothstep(rimw + 0.01, rimw * 0.3, 1.0 - rho) * smoothstep(-0.03, 0.01, 1.0 - rho) * (t > 0.5) * head_cap * valid
        cv.add(blur(rm.astype(np.float32), 0.6 * s), pal[3], 1.3 * head_k)
    return m


def burst(cv, rng, c, r, el, k=1.0, smoke_k=0.8, puffs=9, core=True):
    """cel explosion: dark smoke puffs behind, then stacked fire puffs painted in a 4-value ramp, hot white core"""
    pal = tone(el)
    c = np.asarray(c, float)
    sm = np.zeros((cv.w, cv.w), np.float32)
    for i in range(6):
        a = rng.uniform(0, 2 * math.pi)
        p = c + np.array([math.cos(a), math.sin(a)]) * r * rng.uniform(0.6, 1.0)
        np.maximum(sm, cv.ellipse(p[0], p[1], r * rng.uniform(0.35, 0.55)), out=sm)
    if smoke_k:
        paint_form(cv, sm, ["#120C0A", "#2A221E", "#4A3E36", "#6A5C50"], R=r * 0.3, grad=0.6, alpha=smoke_k)
    fire = np.zeros_like(sm)
    for i in range(puffs):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.0, 0.55) * r
        p = c + np.array([math.cos(a), math.sin(a)]) * d
        np.maximum(fire, cv.ellipse(p[0], p[1], r * rng.uniform(0.32, 0.52)), out=fire)
    glow(cv, fire, pal[1], r * 0.7, 0.8 * k)
    ink_line(cv, fire, mix(pal[0], pal[1], 0.4), 0.3, 1.6, 0.5)
    paint_form(cv, fire, [mix(pal[1], pal[0], 0.35), pal[1], mix(pal[2], pal[3], 0.3), pal[3]], R=r * 0.35, grad=0.5,
               thr=[0.25, 0.55, 0.82])
    if core:
        hot_core(cv, c[0] - r * 0.1, c[1] - r * 0.1, el, r / 12.0, 1.0 * k, star_len=14)
    return np.maximum(fire, sm)


def trail(cv, pts, w0, w1, el, k=1.0, n=10, core_k=0.8):
    """tapered soft-light ribbon along pts; w0 at the tail (first point), w1 at the head (last point)"""
    sp = spline(pts, n) if len(pts) > 2 else np.asarray(pts, float)
    m = cv.poly(ribbon(sp, lambda q: max(0.3, w0 + (w1 - w0) * q ** 0.8)))
    soft_light(cv, m, el, k, R=max(0.8, w1 * 0.35), glow_r=max(2.0, w1 * 0.8), core_k=core_k)
    return m


def smoke(cv, rng, pts, r, colour="#4A3E36", k=0.7):
    sp = spline(pts, 6) if len(pts) > 2 else np.asarray(pts, float)
    m = np.zeros((cv.w, cv.w), np.float32)
    for i, p in enumerate(sp[::2]):
        rr = r * (0.5 + 0.8 * i / max(1, len(sp[::2]) - 1)) * rng.uniform(0.8, 1.2)
        np.maximum(m, cv.ellipse(p[0] + rng.uniform(-r, r) * 0.3, p[1] + rng.uniform(-r, r) * 0.3, rr), out=m)
    m = blur(m, r * 0.25)
    paint_form(cv, m, [mix(colour, "#000000", 0.5), colour, mix(colour, "#FFFFFF", 0.25)], R=r * 0.4, grad=0.6, alpha=k)
    return m


def sparks(cv, rng, c, count, length, el, k=1.0, a_range=(0, 360), width=1.4):
    c = np.asarray(c, float)
    for i in range(count):
        a = math.radians(rng.uniform(*a_range))
        d = np.array([math.cos(a), math.sin(a)])
        r0 = length * rng.uniform(0.2, 0.5)
        L = length * rng.uniform(0.5, 1.0)
        light_streak(cv, c + d * r0, c + d * (r0 + L), width * rng.uniform(0.7, 1.3), el, k)


def speed_lines(cv, rng, ang, count, el, k=0.6, length=(0.3, 0.7), width=(0.006, 0.016), band=(0.0, 1.0)):
    n = cv.n
    a = math.radians(ang)
    d = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-d[1], d[0]])
    for i in range(count):
        o = rng.uniform(*band) - 0.5
        along = rng.uniform(-0.3, 0.3)
        mid = np.array([n * 0.5, n * 0.5]) + nv * o * n * 1.2 + d * along * n
        L = rng.uniform(*length) * n
        light_streak(cv, mid - d * L / 2, mid + d * L / 2, rng.uniform(*width) * n, el, k * rng.uniform(0.6, 1.1))
