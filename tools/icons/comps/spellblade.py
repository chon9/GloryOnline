"""魔剑士 Spellblade (rune-etched short sword, magic circle at the hilt). Teal-keyed bar: wave teal, frost, volt
and gold trim on a deep sea-black ground. The bar's one off-key accent is fire orange, on 烈焰波动剑 (its element
demands it).

Value plan:
  atk1                     the short sword on a falling diagonal (upper left -> lower right), a teal smear [sword]
  earthquake_sword         a ground crack running from the foreground up to the horizon, slabs and gold
                           light erupting along it (a vertical wedge)
  wave_splitting_sword     one thick vertical crescent of wave light flying right, two fainter echoes behind
  fire_wave_sword          a row of fire pillars erupting along a diagonal ground line, shrinking into the
                           distance (orange: the off-key accent)
  ice_wave_sword           a low bowl-shaped frost smear sweeping across, ice crystals bristling from its back
  electric_wave_formation  a magic circle flat on the ground, lightning arcing up out of it into a dome
  waltzing_wave_slash      a tilted elliptical orbit trail coming round behind a split stone stele
  nebula_wave_slash        the sword point-up before a spiral nebula, a magic circle at the hilt          [sword]
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_swordmage import ICE, crystal, flame, lightning, rune_ring, short_sword

RUNE = "#7FFFF0"


@skill("spellblade.atk1", tone="wave")
def slash(cv, rng, el):
    """the blade level across the frame at the end of a flat sweep; the smear lies in the swing plane below it"""
    n = cv.n
    mass = cv.poly([(0, n * 0.70), (n, n * 0.62), (n, n), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.80, n * 0.36), focus_r=0.5, focus_k=0.6, wash=-15, rng=rng)
    crescent(cv, (n * 0.50, n * 0.50), n * 0.48, n * 0.24, -16, 150, -18, 0.42, el, 1.0)
    H = weapon_H((n * 0.06, n * 0.70), (n * 0.90, n * 0.30), 1.25)
    short_sword(cv, H, el, rune=RUNE)
    tip = xf(H, [(0.98, 0.0)])[0]
    hot_core(cv, tip[0], tip[1], el, 2.2, 1.0, star_len=16, ang=-25)


@skill("spellblade.earthquake_sword", tone="gold")
def earthquake(cv, rng, el):
    """a crack torn from the foreground to the horizon: slabs heave up along it, gold light pours out"""
    n = cv.n
    hz = n * 0.34
    floor = cv.poly([(0, hz), (n, hz), (n, n), (0, n)])
    ground(cv, "wave", [(floor, 1)], focus=(n * 0.50, n * 0.62), focus_r=0.5, focus_k=0.5, wash=-90, rng=rng)
    ys = np.linspace(n * 1.04, hz, 12)
    xs = n * 0.5 + np.array([rng.uniform(-1, 1) * n * 0.05 * (y - hz) / n for y in ys])
    w = n * 0.30 * ((ys - hz) / (n - hz)) ** 1.3 + 0.4
    crack = cv.poly(np.vstack([np.c_[xs - w / 2, ys], np.c_[xs + w / 2, ys][::-1]]))
    glow(cv, crack, tone(el)[1], 14, 1.0)
    light_form(cv, crack, el, 1.0, R=n * 0.03, glow_r=6, lw=(0.3, 1.6))
    for y0, k in ((0.96, 1.0), (0.82, 0.8), (0.68, 0.6)):   # light columns pouring up out of the crack
        i = int(np.argmin(np.abs(ys - n * y0)))
        light_streak(cv, (xs[i], ys[i]), (xs[i] + rng.uniform(-1, 1) * n * 0.02, ys[i] - n * 0.55 * (y0 - 0.3)), n * 0.06 * (y0 - 0.3), el, k)
    for t, s in ((0.50, 1), (0.46, -1), (0.30, 1), (0.26, -1), (0.10, 1), (0.06, -1)):   # heaved slabs, far to near
        y = n - (n - hz) * t
        i = int(np.argmin(np.abs(ys - y)))
        sz = n * 0.20 * (1 - t) ** 1.4 + n * 0.02
        x = xs[i] + s * (w[i] * 0.5 + sz * 0.55)
        stone_chip(cv, rng, x, y - sz * 0.45, sz, s * 28 + rng.uniform(-8, 8), el, hot_dir=(-s, 0.3))
    for x, y, s in ((0.30, 0.24, 0.035), (0.68, 0.18, 0.03), (0.46, 0.10, 0.022), (0.78, 0.36, 0.03), (0.20, 0.40, 0.025)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 90), el, trail=(0.0, -1.0))
    hot_core(cv, n * 0.50, n * 0.86, el, 2.8, 1.2, star_len=24)


@skill("spellblade.wave_splitting_sword", tone="wave")
def wave_split(cv, rng, el):
    """a tilted crescent of sword-qi racing to the upper right; the boulder it passed through falls apart behind"""
    n = cv.n
    low = cv.poly([(0, n * 0.80), (n, n * 0.74), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.70, n * 0.36), focus_r=0.5, focus_k=0.7, wash=-30, rng=rng)
    X, Y = cv.grid()
    # the boulder, cut along the wave's path: two halves sliding apart
    rock = cv.poly(closed_spline([(n * 0.04, n * 0.94), (n * 0.02, n * 0.70), (n * 0.12, n * 0.54), (n * 0.30, n * 0.50), (n * 0.44, n * 0.60),
                                  (n * 0.48, n * 0.80), (n * 0.40, n * 0.96)], 5))
    cut = (Y - n * 0.74) + (X - n * 0.25) * 0.55
    lo = (rock * (cut > n * 0.010)).astype(np.float32)
    hi = shift((rock * (cut < -n * 0.010)).astype(np.float32), int(-n * 0.025 * SS), int(-n * 0.03 * SS))
    for m, t in ((lo, (0.1, 0.2)), (hi, (-0.2, -0.3))):
        material(cv, m, "stone", R=n * 0.07, lw=(0.4, 2.2), grad=0.5, tilt=t, back=tone(el)[1], back_k=0.9)
    for m, d in ((lo, (0.48, -0.88)), (hi, (-0.48, 0.88))):   # the cut faces glow
        face = np.clip(m - toward(m, 1.8, d), 0, 1)
        cv.add(blur(face, 0.6), tone(el)[2], 0.9)
    crescent(cv, (n * 0.30, n * 0.80), n * 0.56, n * 0.40, -28, 160, 230, 0.20, el, 0.6, rim=False)
    qc = np.array([n * 0.66, n * 0.38])
    rot = math.radians(-35)
    ca, sa = math.cos(rot), math.sin(rot)
    lx = (X - qc[0]) * ca + (Y - qc[1]) * sa
    ly = -(X - qc[0]) * sa + (Y - qc[1]) * ca
    rx, ry = n * 0.17, n * 0.36
    outer = ((lx / rx) ** 2 + (ly / ry) ** 2) < 1.0
    inner = (((lx + rx * 0.62) / (rx * 0.95)) ** 2 + (ly / (ry * 0.92)) ** 2) < 1.0
    moon = (outer & ~inner & (lx > -rx * 0.45)).astype(np.float32)
    moon = blur(moon, 0.3)
    light_form(cv, moon, el, 1.0, R=n * 0.035, glow_r=9, lw=(0.3, 1.9))
    sparks(cv, rng, qc + np.array([ca, sa]) * rx, 6, n * 0.10, el, 0.7, a_range=(-80, 10))
    hot_core(cv, qc[0] + ca * rx, qc[1] + sa * rx, el, 2.6, 1.1, star_len=20, ang=-35)


@skill("spellblade.fire_wave_sword", tone="wave")
def fire_wave(cv, rng, el):
    """three fire pillars erupting along a burning ground line, near to far (the bar's one off-key accent)"""
    n = cv.n
    fire = "fire"
    floor = cv.poly([(0, n * 0.66), (n, n * 0.44), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.34, n * 0.70), focus_r=0.5, focus_k=0.4, wash=-20, rng=rng)
    p0, p1 = np.array([n * 0.30, n * 0.94]), np.array([n * 0.92, n * 0.56])
    line = cv.poly(ribbon([p0 - (p1 - p0) * 0.3, p0, p1], [n * 0.10, n * 0.07, n * 0.012]))
    light_form(cv, blur(line, 1.5), fire, 0.6, R=n * 0.02, glow_r=6, line=False, value=0.8)
    for t, hh, ww in ((0.92, 0.36, 0.14), (0.56, 0.58, 0.22), (0.10, 0.92, 0.40)):   # far to near
        p = p0 + (p1 - p0) * t
        cv.add(blur(cv.ellipse(p[0], p[1], n * ww * 0.6, n * ww * 0.15), 2), tone(fire)[2], 0.6)
        flame(cv, p, n * hh, n * ww, fire, rng, lean=0.12, tongues=5 if ww > 0.3 else 4, k=1.0)
    for x, y in ((0.10, 0.50), (0.66, 0.30), (0.84, 0.18)):
        stone_chip(cv, rng, n * x, n * y, n * 0.03, rng.uniform(0, 90), fire, trail=(0.0, -1.0))
    hot_core(cv, p0[0] + n * 0.05, p0[1] - n * 0.20, fire, 2.6, 1.1, star_len=18)


@skill("spellblade.ice_wave_sword", tone="frost")
def ice_wave(cv, rng, el):
    """a breaking wave frozen solid as it rolls right: a curling ice crest, crystals bristling along its lip"""
    n = cv.n
    ground(cv, "wave", [], focus=(n * 0.80, n * 0.56), focus_r=0.5, focus_k=0.6, wash=-10, rng=rng)
    body = closed_spline([(n * -0.04, n * 1.02), (n * -0.02, n * 0.60), (n * 0.12, n * 0.30), (n * 0.34, n * 0.14), (n * 0.56, n * 0.14),
                          (n * 0.72, n * 0.24), (n * 0.76, n * 0.38), (n * 0.66, n * 0.40), (n * 0.58, n * 0.32), (n * 0.48, n * 0.32),
                          (n * 0.42, n * 0.42), (n * 0.46, n * 0.60), (n * 0.62, n * 0.80), (n * 0.90, n * 0.94), (n * 1.04, n * 1.04)], 6)
    m = cv.poly(body)
    glow(cv, m, tone(el)[1], 8, 0.5)
    ink_line(cv, m, "#0A2238", 0.35, 2.2, 0.4)
    X, Y = cv.grid()
    sweep = 0.12 * np.sin((X * 0.6 - Y * 0.8) / n * 9.0 + cv.noise * 2.0) - 0.25 * smoothstep(0.4, 1.0, Y / n)
    paint_form(cv, m, ICE, R=n * 0.07, grad=0.6, field=sweep, thr=[0.24, 0.55, 0.84], soft=0.10, wobble=0.03)
    f = streak_field(cv.w, -40, 70, 4, cv.seed())
    cv.c *= (1 + 0.08 * (f - 0.5) * 2 * m)[..., None]
    curl = cv.poly(closed_spline([(n * 0.48, n * 0.32), (n * 0.58, n * 0.32), (n * 0.64, n * 0.40), (n * 0.54, n * 0.46), (n * 0.44, n * 0.44)], 4)) * m
    cv.paint(blur(curl, 1.5), ICE[0], 0.8)   # the hollow under the curl
    for x, y, a, h in ((0.20, 0.26, -120, 0.10), (0.32, 0.16, -95, 0.12), (0.46, 0.13, -70, 0.12), (0.60, 0.16, -40, 0.11),
                       (0.72, 0.26, -10, 0.10), (0.76, 0.38, 25, 0.08), (0.08, 0.42, -150, 0.08)):
        crystal(cv, (n * x, n * y), a, n * h, n * h * 0.42, glow_c=tone(el)[1])
    for x, y, s, a in ((0.86, 0.52, 0.05, 10), (0.92, 0.70, 0.04, 30), (0.88, 0.36, 0.035, -20)):   # spray thrown ahead
        crystal(cv, (n * x, n * y), a, n * s * 1.6, n * s * 0.6, glow_c=tone(el)[1])
    hot_core(cv, n * 0.74, n * 0.30, el, 2.4, 1.0, star_len=18)


@skill("spellblade.electric_wave_formation", tone="volt")
def electric_formation(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.74])
    disc = cv.ellipse(c[0], c[1], n * 0.46, n * 0.15)
    ground(cv, "wave", [(disc, 1)], focus=(n * 0.50, n * 0.50), focus_r=0.5, focus_k=0.5, ink="#04080E", wash=-90, rng=rng)
    X, Y = cv.grid()   # the dome of the field: a faint light shell
    dome = np.clip(cv.ellipse(c[0], c[1], n * 0.44, n * 0.56) * (Y < c[1]), 0, 1)
    shell = np.clip(dome - blur(dome, n * 0.04) * 0.9, 0, 1)
    cv.add(blur(shell, 2), tone(el)[1], 0.35)
    cv.add(blur(dome, 6) * 0.25, tone(el)[0], 0.5)
    rune_ring(cv, c, n * 0.42, n * 0.13, el, 1.0, w=n * 0.014, ticks=28, star=6)
    for x0, x1 in ((0.18, 0.40), (0.82, 0.60), (0.36, 0.52), (0.64, 0.46)):   # bolts arcing up from the circle
        top = np.array([n * x1, n * rng.uniform(0.16, 0.30)])
        lightning(cv, rng, (n * x0, c[1] - n * 0.01), top, n * 0.022, el, 0.9, branches=1, jag=0.18)
    lightning(cv, rng, (n * 0.50, c[1]), (n * 0.50, n * 0.10), n * 0.03, el, 1.0, branches=2, jag=0.15)
    hot_core(cv, n * 0.50, n * 0.34, el, 2.4, 1.0, star_len=18)


@skill("spellblade.waltzing_wave_slash", tone="wave")
def waltzing_wave(cv, rng, el):
    """the wave goes round the target on a tilted orbit and strikes the stele from behind"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.54])
    ground(cv, el, [], focus=(n * 0.40, n * 0.40), focus_r=0.5, focus_k=0.6, wash=-20, rng=rng)
    rot = math.radians(-20)
    rx, ry = n * 0.40, n * 0.20

    def orb(a):
        ar = math.radians(a)
        p = np.array([math.cos(ar) * rx, math.sin(ar) * ry])
        return c + np.array([p[0] * math.cos(rot) - p[1] * math.sin(rot), p[0] * math.sin(rot) + p[1] * math.cos(rot)])
    back = [orb(a) for a in np.linspace(0, -180, 30)]        # far half of the orbit: behind the stele
    trail(cv, back, 0.4, n * 0.035, el, 0.6, core_k=0.5)
    # the stele: a dark standing stone with a gold-inlaid face, split by the returning wave
    st = cv.poly([(n * 0.40, n * 0.86), (n * 0.38, n * 0.36), (n * 0.44, n * 0.24), (n * 0.56, n * 0.24), (n * 0.62, n * 0.36), (n * 0.60, n * 0.86)])
    X, Y = cv.grid()
    cut = (Y - n * 0.50) - (X - n * 0.5) * 0.35
    top = (st * (cut < -n * 0.010)).astype(np.float32)
    bot = (st * (cut > n * 0.010)).astype(np.float32)
    top = shift(top, int(-n * 0.02 * SS), int(-n * 0.012 * SS))
    for m in (bot, top):
        material(cv, m, "stone", R=n * 0.05, lw=(0.35, 2.0), grad=0.5, back=tone(el)[1], back_k=0.8)
    inl0 = cv.poly([(n * 0.45, n * 0.32), (n * 0.55, n * 0.32), (n * 0.55, n * 0.80), (n * 0.45, n * 0.80)])
    for m, off in ((bot, (0, 0)), (top, (int(-n * 0.02 * SS), int(-n * 0.012 * SS)))):   # gold-inlaid panel
        inl = shift(inl0, *off) * m
        cv.paint(inl, "#06090C", 0.6)
        edge = np.clip(inl - toward(inl, 1.0, (0.7, 0.7)), 0, 1)
        cv.add(edge, KEY["metal"], 0.9)
    gash = cv.poly(ribbon([(n * 0.30, n * 0.465), (n * 0.50, n * 0.50), (n * 0.70, n * 0.535)], [0.4, n * 0.03, 0.4]))
    soft_light(cv, gash, el, 1.0, R=n * 0.01, glow_r=4, core_k=1.2)
    front = [orb(a) for a in np.linspace(0, 150, 28)]         # near half: sweeping round in front, head at the left
    trail(cv, front, n * 0.006, n * 0.05, el, 0.9, core_k=0.8)
    hd = orb(150)
    qm = np.clip(cv.ellipse(hd[0], hd[1], n * 0.07, n * 0.12) - cv.ellipse(hd[0] + n * 0.045, hd[1] - n * 0.01, n * 0.06, n * 0.11), 0, 1)
    light_form(cv, qm, el, 1.0, R=n * 0.02, glow_r=6, lw=(0.3, 1.5))
    hot_core(cv, n * 0.50, n * 0.50, el, 2.4, 1.1, star_len=18, ang=20)


@skill("spellblade.nebula_wave_slash", tone="gold")
def nebula(cv, rng, el):
    """the sword raised point-up, a spiral nebula of wave, frost and gold light wheeling behind it"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.40])
    ground(cv, "wave", [], focus=c, focus_r=0.55, focus_k=0.7, ink="#03080A", wash=-60, rng=rng)
    X, Y = cv.grid()
    dx, dy = (X - c[0]) / n, (Y - c[1]) / n
    r = np.sqrt(dx * dx + dy * dy) + 1e-4
    th = np.arctan2(dy, dx)
    arms = 0.5 + 0.5 * np.cos(2 * th - 7.0 * np.log(r * 4 + 0.2) + cv.noise * 2.0)
    fall = np.exp(-(r / 0.36) ** 2)
    neb = (arms ** 2.4 * fall).astype(np.float32)
    cv.add(blur(neb, 3), tone("wave")[1], 0.7)
    cv.add(blur(neb * (0.5 + 0.5 * np.cos(th * 1.0 + 1.0)), 2) ** 1.5, tone("frost")[1], 0.6)
    cv.add(blur(neb * (0.5 + 0.5 * np.cos(th * 1.0 - 2.2)), 2) ** 1.5, tone(el)[1], 0.7)
    cv.add(np.exp(-(r / 0.06) ** 2), tone(el)[2], 0.7)
    for _ in range(26):   # stars
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.05, 0.45) * n
        p = c + np.array([math.cos(a), math.sin(a)]) * rr
        s = rng.uniform(0.5, 1.6)
        cv.add(np.exp(-((X - p[0]) ** 2 + (Y - p[1]) ** 2) / (s * s)), "#FFFFFF", 1.0)
        if s > 1.3:
            hot_core_cross(cv, p[0], p[1], s * 2.4, "#FFF6DC", 0.7)
    hc = np.array([n * 0.50, n * 0.84])
    rune_ring(cv, hc, n * 0.30, n * 0.09, "wave", 0.9, w=n * 0.012, ticks=20, star=5)
    H = weapon_H((n * 0.50, n * 0.98), (n * 0.50, n * 0.10), 1.35)
    short_sword(cv, H, "wave", rune=RUNE)
    hot_core(cv, n * 0.50, n * 0.11, el, 2.8, 1.2, star_len=24)
