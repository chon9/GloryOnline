"""驱魔师 Exorcist. Black / crimson / silver keyed bar with yellow talisman paper and red ink.
The bar's one off-key accent is the key's `cool` ice-cyan, on the ice talisman of 落雷符/寒冰符/烈焰符 only.

Value plan:
  atk1                the war scythe raised on a diagonal, a wide crimson reaping crescent below it          [scythe]
  rising_emblem       a rune circle low in perspective, a column of gold light and spikes erupting from it
  hook                the scythe blade sweeping in from the right, its point hooked through a pale soul      [scythe]
  spirit_guidance     the scythe thrown: spinning flat as a pinwheel with a talisman tied on, a motion ring  [scythe]
  elemental_talisman  three talismans fanned like cards: lightning (gold), ice (cyan), fire (crimson)
  binding_talismans   a ring of talisman strips on a red cord orbiting a bright seal point (closed loop)
  star_fall           a faceted silver star plunging on a long diagonal trail into a cratered ground ring
  seal_talisman       one giant talisman pressing down on a crimson rune circle, red cords pulled to four corners
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_priest import INK_RED, rune_circle, talisman

RED = "#C8202A"


def _scythe(cv, butt, tip, el, scale=1.6, cord=True):
    H = weapon_H(butt, tip, scale)
    m = pole(cv, H, el, "scythe", shaft_mat="lacquer", band_mat="steel")
    if cord:   # red cord wrap and a hanging tassel under the head
        for x in (0.62, 0.66, 0.70):
            cv.paint(lrib(cv, H, [(x, -0.02), (x + 0.015, 0.02)], 0.01) * m, RED, 0.9)
        p = xf(H, [(0.70, 0.02)])[0]
        d = xf(H, [(0.70, 0.0), (0.70, 0.1)])
        dn = (d[1] - d[0]) / (np.linalg.norm(d[1] - d[0]) + 1e-9)
        tas = cv.poly(ribbon(spline([p, p + dn * cv.n * 0.05 + np.array([cv.n * 0.01, cv.n * 0.03]), p + np.array([cv.n * 0.03, cv.n * 0.12])], 6),
                             lambda u: cv.n * (0.012 + 0.02 * u)))
        material(cv, tas, "cloth_red", R=cv.n * 0.008, lw=(0.2, 0.9))
    return m


@skill("exorcist.atk1", tone="crimson")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.40, n * 0.70), focus_r=0.55, focus_k=0.6, wash=-10, rng=rng)
    crescent(cv, (n * 0.56, n * 0.40), n * 0.56, n * 0.40, 8, -20, 168, 0.36, el, 1.2)
    _scythe(cv, (n * 0.86, n * 1.04), (n * 0.30, n * 0.08), el, 1.6)
    hot_core(cv, n * 0.06, n * 0.52, el, 2.0, 1.0, star_len=14)


@skill("exorcist.rising_emblem", tone="talisman")
def rising_emblem(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.80])
    ground(cv, el, [], focus=(n * 0.5, n * 0.55), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    col_m = cv.poly([(n * 0.30, n * 0.80), (n * 0.70, n * 0.80), (n * 0.60, n * 0.0), (n * 0.40, n * 0.0)])
    cv.add(blur(col_m, 8) * smoothstep(0.0, 0.8, cv.grid()[1] / n), tone(el)[1], 0.45)
    rune_circle(cv, c, n * 0.44, n * 0.14, el, 1.0, w=n * 0.02)
    for i in range(9):
        x = n * (0.5 + rng.uniform(-0.22, 0.22))
        light_streak(cv, (x, n * 0.80), (x, n * rng.uniform(0.10, 0.45)), n * rng.uniform(0.014, 0.03), el, 0.8)
    flare_spikes(cv, c[0], c[1] - n * 0.04, [(-90, 1.0), (-110, 0.7), (-70, 0.7), (-130, 0.45), (-50, 0.45)], n * 0.02, n * 0.62, n * 0.04, el, 0.9)
    for (x, y, a) in ((0.22, 0.30, -14), (0.80, 0.22, 18)):   # two talismans swept up by the column
        talisman(cv, (n * x, n * y), n * 0.10, n * 0.24, a, mark=(0 if x < 0.5 else 1), glow_el=el, curl=0.4)
    hot_core(cv, c[0], c[1] - n * 0.04, el, 3.0, 1.2, star_len=20)


@skill("exorcist.hook", tone="silver")
def hook(cv, rng, el):
    """勾魂: the scythe raised on a long diagonal, its blade curling down at the upper left; a pale soul-flame is
    caught on the point (the point drawn over it, piercing), torn upward off a crimson soul-cord to the ground"""
    n = cv.n
    butt, top = np.array([n * 0.98, n * 1.06]), np.array([n * 0.80, n * 0.02])
    H = weapon_H(butt, top, 1.25)
    tip = xf(H, [(0.58, -0.40)])[0]
    soul_c = tip + np.array([-n * 0.06, n * 0.10])
    ground(cv, "crimson", [], focus=soul_c, focus_r=0.5, focus_k=0.5, wash=-50, rng=rng)
    crescent(cv, (n * 0.78, n * 0.30), n * 0.46, n * 0.40, 0, 20, 150, 0.26, "crimson", 0.9)
    _scythe(cv, butt, top, el, 1.25)
    saved = cv.c.copy()
    sc = soul_c
    cord = stroke(cv, [sc + np.array([0, n * 0.10]), sc + np.array([-n * 0.10, n * 0.18]), sc + np.array([-n * 0.16, n * 0.28]),
                       sc + np.array([-n * 0.30, n * 0.36])], n * 0.022, n * 0.008)
    soft_light(cv, cord, "crimson", 0.9, R=1.0, glow_r=4)
    for (dx, dy, L, a) in ((-0.08, -0.04, 0.20, -120), (0.0, -0.10, 0.24, -95), (0.08, -0.06, 0.18, -70), (-0.10, 0.06, 0.16, 160)):
        p0 = sc + np.array([n * dx, n * dy])
        ar = math.radians(a)
        p2 = p0 + np.array([math.cos(ar), math.sin(ar)]) * n * L
        p1 = (p0 + p2) / 2 + np.array([-math.sin(ar), math.cos(ar)]) * n * 0.03
        wisp = cv.poly(ribbon(spline([p0, p1, p2], 6), lambda u: n * 0.07 * (1 - u) ** 1.1 + 0.3))
        soft_light(cv, wisp, el, 0.8, R=n * 0.02, glow_r=6)
    rel = [(-0.12, 0.02), (-0.11, -0.08), (-0.05, -0.15), (0.0, -0.20), (0.06, -0.14), (0.12, -0.08), (0.11, 0.04), (0.0, 0.13)]
    soul = cv.poly(closed_spline([(sc[0] + n * x, sc[1] + n * y) for x, y in rel], 8))
    light_form(cv, soul, el, 1.0, R=n * 0.06, glow_r=12, lw=(0.3, 1.4), value=0.95)
    cv.add(blur(soul, 3) * soul, tone(el)[2], 0.3)
    for (x, y) in ((-0.045, -0.03), (0.045, -0.035)):
        e = cv.ellipse(sc[0] + n * x, sc[1] + n * y, n * 0.022, n * 0.034)
        cv.paint(blur(e, 0.8), "#1A1E30", 0.85)
    mouth = cv.ellipse(sc[0], sc[1] + n * 0.05, n * 0.02, n * 0.03)
    cv.paint(blur(mouth, 0.8), "#1A1E30", 0.7)
    # the blade's point pierces the soul: restore the blade pixels around the tip on top
    pierce = cv.poly([tip + np.array([n * 0.08, -n * 0.10]), tip + np.array([n * 0.10, n * 0.0]), tip + np.array([-n * 0.02, n * 0.06]),
                      tip + np.array([-n * 0.06, -n * 0.04])])
    k = blur(pierce, 0.6)[..., None]
    cv.c = cv.c * (1 - k) + saved * k
    cv.add(blur(cv.ellipse(tip[0], tip[1], n * 0.03), 2), tone(el)[3], 0.8)
    hot_core(cv, tip[0], tip[1] + n * 0.02, el, 2.2, 1.0, star_len=14)


@skill("exorcist.spirit_guidance", tone="crimson")
def spirit_guidance(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.54, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.6, wash=0, rng=rng)
    for k in range(3):   # the spin: three motion arcs around the hub
        a0 = k * 120 + 20
        crescent(cv, c, n * 0.40, n * 0.34, 0, a0, a0 + 100, 0.20, el, 0.9)
    speed_lines(cv, rng, 0, 8, el, 0.4, length=(0.2, 0.4), band=(0.2, 0.8))
    d = np.array([math.cos(math.radians(-35)), math.sin(math.radians(-35))])
    _scythe(cv, c - d * n * 0.36, c + d * n * 0.42, el, 1.5, cord=False)
    talisman(cv, c + d * n * 0.02 + np.array([0, n * 0.10]), n * 0.09, n * 0.20, -35 + 90 - 70, mark=2, glow_el="talisman", curl=0.5)
    hot_core(cv, c[0], c[1], el, 2.0, 0.9, star_len=14)


@skill("exorcist.elemental_talisman", tone="talisman")
def elemental_talisman(cv, rng, el):
    n = cv.n
    cool = KEY["cool"]
    ground(cv, "crimson", [], focus=(n * 0.5, n * 0.45), focus_r=0.55, focus_k=0.5, wash=-80, rng=rng)
    pivot = np.array([n * 0.50, n * 1.02])
    specs = ((-30, 0, "talisman"), (0, 2, None), (30, 1, "crimson"))
    for (a, mk, glow_el) in specs:
        ar = math.radians(a - 90)
        c = pivot + np.array([math.cos(ar), math.sin(ar)]) * n * 0.56
        if glow_el is None:   # the ice talisman: cyan glow drawn from the key's cool accent
            m_ = cv.poly([(c[0] - n * 0.08, c[1] - n * 0.20), (c[0] + n * 0.08, c[1] - n * 0.20), (c[0] + n * 0.08, c[1] + n * 0.20),
                          (c[0] - n * 0.08, c[1] + n * 0.20)])
            glow(cv, m_, cool, 12, 0.9)
        talisman(cv, c, n * 0.19, n * 0.44, a, mark=mk, glow_el=glow_el, glow_k=0.9)
        top = c + np.array([math.cos(ar), math.sin(ar)]) * n * 0.26
        if a < 0:     # lightning: a forked bolt crackling off the top
            bolt = union(cv, [stroke(cv, [top, top + np.array([-n * 0.04, -n * 0.06]), top + np.array([n * 0.0, -n * 0.10]),
                                          top + np.array([-n * 0.05, -n * 0.18])], n * 0.018, n * 0.004, n=2),
                              stroke(cv, [top + np.array([n * 0.0, -n * 0.10]), top + np.array([n * 0.05, -n * 0.15])], n * 0.012, n * 0.003, n=2)])
            soft_light(cv, bolt, "talisman", 1.0, R=0.8, glow_r=4)
        elif a == 0:  # ice: frost crystals
            for (dx, dy, s) in ((0.0, -0.08, 0.05), (-0.06, -0.02, 0.03), (0.06, -0.03, 0.035)):
                p = top + np.array([n * dx, n * dy])
                cr = cv.poly([(p[0], p[1] - n * s), (p[0] + n * s * 0.35, p[1]), (p[0], p[1] + n * s * 0.6), (p[0] - n * s * 0.35, p[1])])
                glow(cv, cr, cool, 4, 0.8)
                paint_form(cv, cr, ["#1E5A78", "#5FC8E8", "#BFF4FF", "#FFFFFF"], R=n * 0.01, grad=0.5)
        else:         # fire: flame tongues licking up
            for (dx, h_) in ((-0.04, 0.10), (0.02, 0.16), (0.07, 0.09)):
                p = top + np.array([n * dx, 0])
                fl = cv.poly(closed_spline([(p[0] - n * 0.03, p[1]), (p[0] - n * 0.01, p[1] - n * h_ * 0.6), (p[0] + n * 0.01, p[1] - n * h_),
                                            (p[0] + n * 0.03, p[1] - n * h_ * 0.4), (p[0] + n * 0.02, p[1] + n * 0.01)], 5))
                light_form(cv, fl, "crimson", 1.0, R=n * 0.012, glow_r=4, lw=(0.2, 1.0))
    hot_core(cv, n * 0.50, n * 0.30, "silver", 1.6, 0.6, star_len=10)


@skill("exorcist.binding_talismans", tone="talisman")
def binding_talismans(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.52])
    rx, ry = n * 0.36, n * 0.20
    ground(cv, "crimson", [], focus=c, focus_r=0.45, focus_k=0.6, wash=-30, rng=rng)
    flare_spikes(cv, c[0], c[1], [(a, 0.6 + 0.4 * (i % 2)) for i, a in enumerate(range(0, 360, 45))], n * 0.03, n * 0.16, n * 0.02, el, 0.8)
    angs = [i * 60 + 15 for i in range(6)]
    # back half of the loop (dimmer), then the front half
    for front in (False, True):
        cord = []
        for t in np.linspace(0, 360, 90):
            a = math.radians(t)
            if (math.sin(a) > 0) == front:
                cord.append(c + np.array([math.cos(a) * rx, math.sin(a) * ry]))
            elif len(cord) > 2:
                m = cv.poly(ribbon(cord, [n * 0.014] * len(cord)))
                material(cv, m, "cloth_red", R=n * 0.006, lw=(0.2, 0.9))
                if not front:
                    cv.paint(m, "#0A0204", 0.5)
                cord = []
        if len(cord) > 2:
            m = cv.poly(ribbon(cord, [n * 0.014] * len(cord)))
            material(cv, m, "cloth_red", R=n * 0.006, lw=(0.2, 0.9))
            if not front:
                cv.paint(m, "#0A0204", 0.5)
        for i, a in enumerate(angs):
            ar = math.radians(a)
            if (math.sin(ar) > 0) != front:
                continue
            p = c + np.array([math.cos(ar) * rx, math.sin(ar) * ry])
            sc = 0.85 + 0.3 * (math.sin(ar) + 1) / 2
            m = talisman(cv, p, n * 0.10 * sc, n * 0.22 * sc, math.degrees(math.cos(ar)) * 0.25 * 30, mark=i % 4, glow_el=el, glow_k=0.4)
            if not front:
                cv.paint(m, "#0A0204", 0.35)
    hot_core(cv, c[0], c[1], el, 3.0, 1.2, star_len=18)


def _star(cv, c, r, el):
    """an 8-point faceted silver star: lit facets toward the key light, shadow facets away"""
    pts = []
    for k in range(16):
        a = math.radians(-90 + k * 22.5 + 10)
        rr = r * (1.0 if k % 4 == 0 else (0.62 if k % 2 == 0 else 0.34))
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    sm = cv.poly(pts)
    glow(cv, sm, tone(el)[1], r * 0.8, 0.8)
    ink_line(cv, sm, "#2A3048", 0.3, 1.6, 0.3)
    for k in range(16):
        tri = cv.poly([tuple(c), pts[k], pts[(k + 1) % 16]])
        a = math.radians(-90 + (k + 0.5) * 22.5 + 10)
        lit = 0.5 + 0.5 * (math.cos(a) * LIGHT[0] + math.sin(a) * LIGHT[1])
        cv.paint(tri * sm, mix("#5A6280", "#FFFFFF", lit), 1.0)
    return sm


@skill("exorcist.star_fall", tone="silver")
def star_fall(cv, rng, el):
    """星落: a big faceted silver star plunging down-left on a long trail onto a cratered ground ring, two smaller
    stars following it, chips and dust kicked up"""
    n = cv.n
    star_c = np.array([n * 0.42, n * 0.56])
    land = np.array([n * 0.30, n * 0.86])
    ground(cv, el, [(cv.poly([(0, n * 0.84), (n, n * 0.78), (n, n), (0, n)]), 1)], focus=star_c, focus_r=0.5, focus_k=0.6, wash=-55, rng=rng)
    for (p0, p1, w, k) in (((1.08, -0.10), (0.42, 0.56), 0.20, 0.9), ((1.04, 0.10), (0.78, 0.36), 0.07, 0.6), ((0.70, -0.06), (0.56, 0.14), 0.06, 0.6)):
        a_ = np.array(p0) * n
        b_ = np.array(p1) * n
        trail(cv, [a_, (a_ + b_) / 2, b_], 2.0, n * w, el, k, core_k=0.7)
    smoke(cv, rng, [land + np.array([-n * 0.30, 0]), land + np.array([0, -n * 0.06]), land + np.array([n * 0.34, -n * 0.02])], n * 0.07, "#2A2E40", 0.7)
    shock_ring(cv, land, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.32, n * 0.07, n * 0.024, el, 0.9)
    for (dx, s_, a) in ((-0.20, 0.045, 10), (0.20, 0.05, -20), (0.06, 0.035, 50), (-0.06, 0.03, 0)):
        stone_chip(cv, rng, land[0] + n * dx, land[1] - n * 0.10, n * s_, a, el, hot_dir=(0.6, -0.8), trail=(0.0, -1.0))
    _star(cv, np.array([n * 0.78, n * 0.36]), n * 0.06, el)
    _star(cv, np.array([n * 0.56, n * 0.14]), n * 0.05, el)
    _star(cv, star_c, n * 0.20, el)
    hot_core(cv, star_c[0], star_c[1], el, 3.0, 1.2, star_len=22)


@skill("exorcist.seal_talisman", tone="crimson")
def seal_talisman(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.44])
    ground(cv, el, [], focus=(n * 0.5, n * 0.80), focus_r=0.5, focus_k=0.6, ink="#050304", wash=-90, rng=rng)
    rune_circle(cv, (n * 0.50, n * 0.84), n * 0.44, n * 0.12, el, 1.0, w=n * 0.022, star=6)
    for (x, y) in ((0.04, 0.06), (0.96, 0.06), (0.04, 0.96), (0.96, 0.96)):   # cords pulled taut to the corners
        cnr = np.array([n * x, n * y])
        anc = c + (cnr - c) * 0.16
        m = cv.poly(ribbon([anc, (anc + cnr) / 2, cnr], [n * 0.02, n * 0.016, n * 0.012]))
        glow(cv, m, RED, 5, 0.6)
        material(cv, m, "cloth_red", R=n * 0.008, lw=(0.2, 1.0))
    for i in range(10):
        x = n * rng.uniform(0.25, 0.75)
        light_streak(cv, (x, n * 0.10), (x, n * rng.uniform(0.70, 0.84)), n * 0.012, el, 0.5)
    talisman(cv, c, n * 0.34, n * 0.72, 0, mark=0, glow_el=el, glow_k=0.9)
    seal = cv.ellipse(c[0], c[1] + n * 0.20, n * 0.07)   # a red seal stamp pressed on the paper
    cv.paint(np.clip(seal - cv.ellipse(c[0], c[1] + n * 0.20, n * 0.055), 0, 1), INK_RED, 0.9)
    cv.paint(cv.ellipse(c[0], c[1] + n * 0.20, n * 0.035), INK_RED, 0.8)
    hot_core(cv, c[0], n * 0.84, el, 3.0, 1.1, star_len=22)
