"""刺客 Assassin (双剑 twin short swords). Wine-keyed bar: wine red, cold steel, shadow violet, on charcoal.
The bar's one off-key accent is ice-cyan, on the ultimate's five-form rim.

Value plan (one big greyscale shape each):
  atk1                 a short sword on a shallow diagonal under two quick parallel slash smears          [sword]
  leaping_blade        VERTICAL: a blade pointing up out of a tall rising crescent, launch burst below   [sword]
  teleporting_stab     HORIZONTAL THRUST: a blade driven left out of a shadow rift into a wine vital mark  [sword]
  shining_cut          X: two crossing blade-aura crescents, a white dash streak straight through them
  cut_throat           HAIRLINE: one razor-thin horizontal slit high in a dark field, a wine spray falling
  blade_storm          CONE: a dense fan of stab streaks converging on one point at the right
  life_risking_strike  DOWNWARD BLADE: a hand gripping the bare blade point-down, blood running, dark burst [sword]
  rend_kill_...        PINWHEEL: five crescents whirling around one hot centre, cyan rim (ULT)
The sword appears in 4 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_night import short_blade, cloud  # noqa: F401


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _blade(cv, butt, tip, el, w=1.0):
    return short_blade(cv, weapon_H(butt, tip, w), el, width=0.055, blade_from=0.30, guard_mat="steel", grip_mat="redlac",
                       kind="straight")


def _drop(cv, x, y, r, el, k=1.0):
    """a falling drop of wine-red blood: tear shape pointing up, lit glint"""
    m = cv.poly(closed_spline([(x, y - r * 2.2), (x + r * 0.9, y - r * 0.2), (x, y + r), (x - r * 0.9, y - r * 0.2)], 6))
    ink_line(cv, m, "#16020A", 0.2, max(0.6, r * 0.25), 0.3)
    paint_form(cv, m, ["#2A0408", "#5A0E20", "#A8203A", "#E04A6A"], R=max(0.8, r * 0.5), grad=0.5)
    cv.paint(cv.ellipse(x - r * 0.3, y - r * 0.2, max(0.4, r * 0.22)) * m, "#FFE0E8", 0.9 * k)
    return m


@skill("assassin.atk1", tone="steel")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.64, n * 0.36), focus_r=0.5, focus_k=0.7, wash=-30, rng=rng)
    crescent(cv, (n * 0.40, n * 0.86), n * 0.56, n * 0.40, -20, 150, 300, 0.16, el, 1.0)
    crescent(cv, (n * 0.46, n * 0.98), n * 0.56, n * 0.40, -20, 160, 290, 0.12, "wine", 0.8)
    _blade(cv, (n * 0.10, n * 0.86), (n * 0.80, n * 0.30), el)
    hot_core(cv, n * 0.80, n * 0.30, el, 2.4, 1.0, star_len=18, ang=-38)


@skill("assassin.leaping_blade", tone="wine")
def leaping_blade(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.84), (n, n * 0.84), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.52, n * 0.12), focus_r=0.45, focus_k=0.7, wash=-90, rng=rng)
    crescent(cv, (n * 0.20, n * 0.62), n * 0.38, n * 0.56, 0, 80, -78, 0.36, el, 1.0)
    shock_ring(cv, np.array([n * 0.46, n * 0.88]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.28, n * 0.06, n * 0.025, el, 0.8)
    for x, y0, y1, w in ((0.74, 0.92, 0.52, 0.016), (0.84, 0.86, 0.60, 0.012), (0.64, 0.98, 0.70, 0.01)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    _blade(cv, (n * 0.58, n * 0.98), (n * 0.54, n * 0.10), "steel")
    hot_core(cv, n * 0.54, n * 0.10, "steel", 2.6, 1.1, star_len=20, ang=-90)


@skill("assassin.teleporting_stab", tone="shadow")
def teleporting_stab(cv, rng, el):
    n = cv.n
    mark = np.array([n * 0.26, n * 0.48])
    ground(cv, el, [], focus=mark, focus_r=0.42, focus_k=0.7, wash=180, rng=rng)
    pal = tone(el)
    # the rift it blinked out of: a torn seam of shadow on the right, smoke curling off it
    for i in range(3):
        cloud(cv, rng, (n * (0.84 + 0.04 * i), n * (0.30 + 0.20 * i)), n * 0.16, ["#07050A", "#160E1C", "#2A1A30", "#4A345A"], puffs=6,
              alpha=0.85)
    rift = cv.poly(closed_spline([(n * 0.80, n * 0.12), (n * 0.86, n * 0.40), (n * 0.82, n * 0.70), (n * 0.78, n * 0.86),
                                  (n * 0.74, n * 0.56), (n * 0.76, n * 0.30)], 6))
    soft_light(cv, rift, el, 1.0, R=n * 0.02, glow_r=6)
    # the vital-point mark: a wine diamond reticle with ticks
    for r, w in ((0.15, 0.02), (0.09, 0.012)):
        pts = [mark + _dv(a) * n * r for a in (0, 90, 180, 270, 0)]
        m = cv.poly(ribbon(np.array(pts), [n * w] * 5))
        soft_light(cv, m, "wine", 0.9, R=n * 0.006, glow_r=3)
    for a in (45, 135, 225, 315):
        soft_light(cv, cv.poly(ribbon([mark + _dv(a) * n * 0.16, mark + _dv(a) * n * 0.22], [n * 0.018, n * 0.006])), "wine", 0.9, R=0.8,
                   glow_r=2)
    for y in (0.40, 0.48, 0.56):
        light_streak(cv, (n * 0.74, n * y), (n * 0.40, n * y), n * 0.01, el, 0.6)
    _blade(cv, (n * 0.92, n * 0.50), (n * 0.24, n * 0.48), "steel", 1.1)
    hot_core(cv, mark[0], mark[1], "wine", 2.4, 1.1, star_len=16)


@skill("assassin.shining_cut", tone="steel")
def shining_cut(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.5, n * 0.5), focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    # two great diagonal arcs crossing at the centre (each a circle through two opposite corners)
    crescent(cv, (n * 1.2, n * -0.2), n * 1.14, n * 1.14, 0, 166, 104, 0.085, el, 1.0)
    crescent(cv, (n * -0.2, n * -0.2), n * 1.14, n * 1.14, 0, 76, 14, 0.085, "wine", 1.0)
    for y, w, k in ((0.50, 0.03, 1.0), (0.44, 0.012, 0.6), (0.57, 0.012, 0.6)):
        light_streak(cv, (n * 0.0, n * y), (n * 1.0, n * (y - 0.02)), n * w, el, k)
    hot_core(cv, n * 0.50, n * 0.49, el, 3.0, 1.2, star_len=26)


@skill("assassin.cut_throat", tone="wine")
def cut_throat(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.56, n * 0.36), focus_r=0.45, focus_k=0.5, ink="#050304", wash=0, rng=rng)
    pal = tone(el)
    # the slit: a razor-thin line of light, tapered both ends, slightly curved
    sl = cv.poly(ribbon(spline([(n * 0.04, n * 0.40), (n * 0.50, n * 0.35), (n * 0.96, n * 0.30)], 12),
                        lambda t: n * 0.016 * math.sin(math.pi * t) ** 0.6 + 0.3))
    glow(cv, sl, pal[1], 14, 1.2)
    soft_light(cv, sl, el, 1.4, R=n * 0.006, glow_r=4, core_k=1.6)
    cv.add(blur(sl, 0.8), "#FFFFFF", 0.8)
    # the spray: an arc of blood droplets thrown down and right from the slit, a few hanging trails
    for i in range(16):
        t = rng.uniform(0.1, 1.0)
        x = n * (0.30 + 0.55 * t)
        y = n * (0.40 + 0.40 * t * t + rng.uniform(-0.04, 0.04))
        _drop(cv, x, y, n * rng.uniform(0.010, 0.028) * (1.2 - 0.5 * t), el)
    for x, L in ((0.36, 0.20), (0.50, 0.30), (0.62, 0.16)):
        m = cv.poly(ribbon(spline([(n * x, n * 0.37), (n * (x + 0.01), n * (0.37 + L * 0.5)), (n * x, n * (0.37 + L))], 6),
                           lambda t: n * 0.014 * (1 - t * 0.6) + 0.3))
        paint_form(cv, m, ["#2A0408", "#5A0E20", "#A8203A"], R=n * 0.006, grad=0.4)
        _drop(cv, n * x, n * (0.37 + L + 0.02), n * 0.016, el)
    hot_core(cv, n * 0.50, n * 0.35, el, 2.2, 1.1, star_len=30)


@skill("assassin.blade_storm", tone="steel")
def blade_storm(cv, rng, el):
    n = cv.n
    tgt = np.array([n * 0.82, n * 0.50])
    band = cv.poly([(0, n * 0.10), tgt + np.array([n * 0.1, 0]), (0, n * 0.90)])
    ground(cv, el, [(band, 1)], focus=tgt, focus_r=0.42, focus_k=0.8, wash=0, rng=rng)
    # a dense fan of thrusts: each a streak with a small steel point at its head, converging on the target
    for i in range(14):
        a = rng.uniform(-30, 30)
        d = _dv(a)
        head = tgt - d * n * rng.uniform(0.06, 0.30)
        tail = head - d * n * rng.uniform(0.35, 0.60)
        light_streak(cv, tail, head, n * rng.uniform(0.012, 0.024), "wine" if i % 3 == 0 else el, 0.8)
        H = weapon_H(head - d * n * 0.07, head + d * n * 0.02, 1.0)
        pt = lpoly(cv, H, [(0.0, -0.14), (0.7, -0.12), (1.0, 0.0), (0.7, 0.12), (0.0, 0.14)])
        material(cv, pt, "steel", R=n * 0.006, lw=(0.2, 0.9), back=tone(el)[2], back_k=0.7)
    shock_ring(cv, tgt, np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * 0.18, n * 0.06, n * 0.025, el, 0.8)
    hot_core(cv, tgt[0], tgt[1], el, 2.8, 1.2, star_len=20)


@skill("assassin.life_risking_strike", tone="wine")
def life_risking(cv, rng, el):
    n = cv.n
    pal = tone(el)
    tip = np.array([n * 0.50, n * 0.92])
    ground(cv, el, [], focus=(n * 0.50, n * 0.46), focus_r=0.5, focus_k=0.7, ink="#060304", wash=-90, rng=rng)
    # dark burst: life burning off as soft wine flame licking up around the blade
    for i in range(5):
        x = n * (0.30 + i * 0.10)
        h = n * (0.34 + 0.16 * math.sin(i * 1.9) ** 2)
        f = cv.poly(ribbon(spline([(x, n * 1.0), (x + n * 0.04 * math.sin(i * 2.3), n * 1.0 - h * 0.5), (x - n * 0.03, n * 1.0 - h)], 8),
                           lambda t: n * 0.12 * (1 - t) ** 1.2 + 0.4))
        soft_light(cv, blur(f, 2.0), el, 0.55, R=n * 0.04, glow_r=6, core_k=0.3)
    _blade(cv, (n * 0.50, n * 0.02), tip, "steel", 1.1)
    # the hand closing on the bare blade: four finger rolls stacked across it, thumb over the top
    fingers = []
    for i in range(4):
        y = n * (0.44 + i * 0.065)
        fingers.append(cv.poly(closed_spline([(n * 0.38, y - n * 0.026), (n * 0.56, y - n * 0.032), (n * 0.62, y),
                                              (n * 0.56, y + n * 0.032), (n * 0.38, y + n * 0.028), (n * 0.35, y)], 4)))
    back = cv.poly(closed_spline([(n * 0.22, n * 0.42), (n * 0.38, n * 0.40), (n * 0.40, n * 0.70), (n * 0.22, n * 0.72),
                                  (n * 0.08, n * 0.66)], 4))
    thumb = stroke(cv, [(n * 0.30, n * 0.42), (n * 0.44, n * 0.38), (n * 0.56, n * 0.40)], n * 0.06, n * 0.045)
    sleeve = cv.poly([(n * -0.05, n * 0.50), (n * 0.16, n * 0.44), (n * 0.20, n * 0.74), (n * -0.05, n * 0.80)])
    material(cv, sleeve, "darksteel", R=n * 0.04, lw=(0.4, 2.0), back=pal[2], back_k=0.7)
    hand = union(cv, [back, thumb] + fingers)
    ink_line(cv, hand, "#2A1606", 0.35, 2.0, 0.4)
    skin = ["#4A2E1A", "#9A7652", "#D8BE98", "#F2E2C8"]
    paint_form(cv, back, skin, R=n * 0.04, grad=0.5)
    for f in fingers:
        ink_line(cv, f, "#2A1606", 0.3, 1.2, 0.3)
        paint_form(cv, f, skin, R=n * 0.02, grad=0.5)
    paint_form(cv, thumb, skin, R=n * 0.02, grad=0.5)
    # blood running from between the fingers down the blade, dripping off the point
    for x, y0, L in ((0.47, 0.70, 0.18), (0.53, 0.66, 0.12), (0.50, 0.72, 0.08)):
        m = cv.poly(ribbon(spline([(n * x, n * y0), (n * (x + 0.005), n * (y0 + L * 0.5)), (n * x, n * (y0 + L))], 6),
                           lambda t: n * 0.016 * (1 - t * 0.5) + 0.3))
        paint_form(cv, m, ["#2A0408", "#5A0E20", "#A8203A", "#E04A6A"], R=n * 0.006, grad=0.4)
    _drop(cv, tip[0], tip[1] + n * 0.03, n * 0.018, el)
    hot_core(cv, n * 0.50, n * 0.44, el, 2.2, 1.0, star_len=16)


@skill("assassin.rend_kill_dodge_flash_exterminate", tone="wine")
def five_forms(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.52])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.7, ink="#060304", wash=-45, rng=rng)
    # a vortex of shadow smoke the five forms are cut out of (painted mass under the light)
    cloud(cv, rng, c, n * 0.30, ["#07050A", "#1A0E1C", "#34203C", "#5A3E66"], puffs=10, spread=(1.0, 1.0), alpha=0.9)
    # five crescents whirling around the centre, alternating wine / steel, each a different length
    for i in range(5):
        th = -90 + i * 72
        tone_ = el if i % 2 == 0 else "steel"
        crescent(cv, c + _dv(th) * n * 0.22, n * (0.27 - 0.01 * i), n * (0.27 - 0.01 * i), 0, th + 225, th + 90, 0.26, tone_, 0.9)
    hot_core(cv, c[0], c[1], "steel", 3.0, 1.2, star_len=24)

    def bleed(c2):
        X, Y = c2.grid()
        rho = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (n * 0.46)
        ring = smoothstep(0.04, 0.0, np.abs(rho - 1.0)) * smoothstep(c[0] - n * 0.1, c[0] + n * 0.3, X) * (Y > c[1] - n * 0.2)
        c2.add(blur(ring.astype(np.float32), 0.8), KEY["cool"], 0.8)   # the bar's one off-key accent
    return {"bleed": bleed}
