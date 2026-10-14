"""忍者 Ninja / Shadow Warrior (忍刀 ninjato). Navy-keyed bar: cold steel, crimson scarf, sakura pink.
The bar's one off-key accent is moon gold, on the ultimate's moon rim.

Value plan (one big greyscale shape each):
  atk1                   FLAT SWEEP: the ninjato held low, a wide flat crescent across the top           [ninjato]
  annihilation           RISING: a steep crimson crescent climbing from the bottom-left, blade upright     [ninjato]
  shuriken               SPINNING STAR: one big four-point shuriken with a spin smear, stun stars
  storm_shuriken         TWO FANS: two volleys of small shuriken fanning out to the right on short trails
  shadow_clone           STAGGERED TRIO: a running ninja and two fading shadow copies stepping out of a smoke puff
  smoke_bomb             CLOUD: a big billowing smoke mass rising off a small round bomb with a lit fuse
  underground_tunneling  HORIZON SPLIT: a cracked ground line, earth erupting up, the blade bursting through [ninjato]
  moon_slaying_sakura    MOON: a full moon cut in two by a diagonal river of sakura petals, gold rim (ULT)
The ninjato appears in 3 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_night import shuriken, dizzy_stars, cloud, billow, figure  # noqa: F401


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _ninjato(cv, butt, tip, el, w=1.0):
    """straight single-edged blade, square-ish tsuba, black-wrapped grip with crimson diamond wraps"""
    H = weapon_H(butt, tip, w)
    m = sword(cv, H, el, blade="straight", guard="tsuba", blade_mat="steel", width=0.032, blade_from=0.30,
              grip_mat="lacquer", guard_mat="darksteel")
    for x in np.linspace(0.07, 0.24, 5):   # crimson ito wraps
        dm = lpoly(cv, H, [(x, 0.0), (x + 0.016, -0.013), (x + 0.032, 0.0), (x + 0.016, 0.013)])
        cv.paint(dm, "#C8202A", 0.85)
    return m


def _petals(cv, rng, p0, p1, count, spread, size, value=1.0):
    """a stream of sakura petals flying from p0 to p1 within +-spread, larger toward p1"""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    d = (p1 - p0) / np.linalg.norm(p1 - p0)
    nv = np.array([-d[1], d[0]])
    ang = math.degrees(math.atan2(d[1], d[0]))
    items = []
    for i in range(count):
        t = rng.uniform(0, 1)
        p = p0 + (p1 - p0) * t + nv * rng.normal(0, spread) * (0.5 + t)
        items.append((t, p))
    for t, p in sorted(items, key=lambda q: q[0]):
        petal(cv, p[0], p[1], size * (0.5 + 0.8 * t) * rng.uniform(0.8, 1.2), ang + rng.uniform(-60, 60), rng.uniform(0.6, 1.0),
              value * (0.55 + 0.45 * t), trail=1.2 if t > 0.4 else 0.0)


@skill("ninja.atk1", tone="steel")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.62, n * 0.30), focus_r=0.55, focus_k=0.6, wash=0, rng=rng)
    crescent(cv, (n * 0.50, n * 0.62), n * 0.52, n * 0.34, -4, 190, 340, 0.34, el, 1.0)
    _ninjato(cv, (n * 0.04, n * 0.80), (n * 0.94, n * 0.62), el)
    hot_core(cv, n * 0.92, n * 0.36, el, 2.4, 1.0, star_len=20)


@skill("ninja.annihilation", tone="crimson")
def annihilation(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.86), (n, n * 0.86), (n, n), (0, n)])
    col_ = cv.poly([(n * 0.26, 0), (n * 0.74, 0), (n * 0.66, n), (n * 0.34, n)])
    ground(cv, el, [(floor, 1), (col_, 1)], focus=(n * 0.50, n * 0.12), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    # the rising cut: a column of crimson up-streaks around an upright blade, the launch flaring off the top
    shock_ring(cv, np.array([n * 0.50, n * 0.88]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.30, n * 0.06, n * 0.025, el, 0.8)
    for x, y0, y1, w, k in ((0.30, 0.94, 0.30, 0.03, 0.9), (0.70, 0.96, 0.36, 0.026, 0.9), (0.40, 0.84, 0.12, 0.016, 0.8),
                            (0.60, 0.86, 0.18, 0.016, 0.8), (0.20, 0.80, 0.50, 0.012, 0.6), (0.80, 0.82, 0.54, 0.012, 0.6)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, k)
    flare_spikes(cv, n * 0.50, n * 0.14, [(-90, 1.0), (-130, 0.55), (-50, 0.55), (-165, 0.35), (-15, 0.35)], n * 0.04, n * 0.20,
                 n * 0.035, el, 0.9)
    _ninjato(cv, (n * 0.54, n * 1.04), (n * 0.50, n * 0.12), "steel")
    hot_core(cv, n * 0.50, n * 0.12, el, 2.6, 1.1, star_len=20, ang=-90)


@skill("ninja.shuriken", tone="steel")
def shuriken_skill(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.52, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.45, focus_k=0.7, wash=-10, rng=rng)
    speed_lines(cv, rng, -8, 8, el, 0.5, length=(0.25, 0.5), band=(0.3, 0.7))
    crescent(cv, c, n * 0.36, n * 0.36, 0, 100, 380, 0.16, el, 0.8)
    shuriken(cv, c, n * 0.30, 12, el, points=4, back_k=0.9)
    dizzy_stars(cv, (n * 0.74, n * 0.20), n * 0.14, n * 0.05, (200, 320, 80), n * 0.04)
    hot_core(cv, c[0] - n * 0.12, c[1] - n * 0.18, el, 1.8, 0.9, star_len=14)


@skill("ninja.storm_shuriken", tone="crimson")
def storm_shuriken(cv, rng, el):
    n = cv.n
    src = np.array([n * 0.06, n * 0.54])
    ground(cv, el, [], focus=(n * 0.70, n * 0.50), focus_r=0.55, focus_k=0.6, wash=0, rng=rng)
    for volley, (r0, k) in enumerate(((0.80, 1.0), (0.48, 0.75))):
        for i in range(5):
            a = -34 + i * 17 + (8 if volley else 0)
            p = src + _dv(a) * n * r0
            trail(cv, [src + _dv(a) * n * (r0 - 0.30), p - _dv(a) * n * 0.05], 0.4, n * 0.022, el, 0.6 * k, core_k=0.5)
            shuriken(cv, p, n * (0.075 if volley == 0 else 0.06), rng.uniform(0, 90), el, points=4, back_k=0.8 * k, hole=False)
    hot_core(cv, src[0] + n * 0.04, src[1], el, 2.2, 1.0, star_len=16)


@skill("ninja.shadow_clone", tone="sakura")
def shadow_clone(cv, rng, el):
    n = cv.n
    pal = tone(el)
    floor = cv.poly([(0, n * 0.86), (n, n * 0.84), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.66, n * 0.44), focus_r=0.5, focus_k=0.6, wash=0, rng=rng)
    billow(cv, rng, (n * 0.22, n * 0.74), n * 0.22, ["#0C0E18", "#2A3046", "#5A6488", "#9AA4C8"], puffs=6, spread=(1.2, 0.6), alpha=0.85)
    # two shadow copies behind (dim, violet-black, sakura rim), the real one in front, same dash pose
    pose = ((-20, 10), (150, 170)), ((40, 100), (130, 160))
    for x, v, rk in ((0.30, 0.25, 0.6), (0.48, 0.45, 0.8), (0.68, 1.0, 1.0)):
        m, _ = figure(cv, (n * x, n * 0.58), n * 0.46, -70, pose[0], pose[1], el, cloth="navy", belt="#C8202A", value=v, rim_k=rk,
                      far_dim=0.6)
        if v < 1.0:
            cv.paint(m, mix(KEY["ink"], pal[0], 0.5), 0.45)
            cv.add(m * (1 - toward(m, 1.6, LIGHT)), pal[1], 0.6)
    # the crimson scarf streaming back from the real one's neck
    sc = stroke(cv, [(n * 0.74, n * 0.40), (n * 0.62, n * 0.34), (n * 0.50, n * 0.38), (n * 0.36, n * 0.30)], n * 0.05, n * 0.02)
    material(cv, sc, "cloth_red", R=n * 0.015, lw=(0.3, 1.4), back=pal[2], back_k=0.6)
    hot_core(cv, n * 0.80, n * 0.40, el, 1.8, 0.8, star_len=14)


@skill("ninja.smoke_bomb", tone="steel")
def smoke_bomb(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.84), (n, n * 0.84), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.28, n * 0.78), focus_r=0.4, focus_k=0.7, wash=-60, rng=rng)
    smoke_ramp = ["#141826", "#3A4260", "#7A86AA", "#C8D2EC"]
    billow(cv, rng, (n * 0.64, n * 0.34), n * 0.34, smoke_ramp, puffs=12, spread=(1.0, 0.8))
    billow(cv, rng, (n * 0.44, n * 0.62), n * 0.22, smoke_ramp, puffs=7, spread=(1.0, 0.6))
    # the bomb: a lacquered ball with a steel band, a short lit fuse
    b = np.array([n * 0.24, n * 0.78])
    ball = cv.ellipse(b[0], b[1], n * 0.12)
    material(cv, ball, "lacquer", R=n * 0.06, lw=(0.4, 2.2), back=tone(el)[2], back_k=0.7)
    band = ball * cv.poly([(b[0] - n * 0.13, b[1] - n * 0.02), (b[0] + n * 0.13, b[1] - n * 0.06), (b[0] + n * 0.13, b[1] - n * 0.02),
                           (b[0] - n * 0.13, b[1] + n * 0.02)])
    material(cv, band, "steel", R=n * 0.01, lw=(0.2, 0.8))
    fuse = stroke(cv, [(b[0] + n * 0.04, b[1] - n * 0.11), (b[0] + n * 0.08, b[1] - n * 0.17), (b[0] + n * 0.05, b[1] - n * 0.22)],
                  n * 0.02, n * 0.014)
    material(cv, fuse, "leather", R=n * 0.005, lw=(0.2, 0.9))
    sparks(cv, rng, (b[0] + n * 0.05, b[1] - n * 0.22), 7, n * 0.08, "crimson", 0.8)
    hot_core(cv, b[0] + n * 0.05, b[1] - n * 0.22, "crimson", 2.0, 1.0, star_len=14)


@skill("ninja.underground_tunneling", tone="crimson")
def tunneling(cv, rng, el):
    n = cv.n
    gy = n * 0.62
    earth = cv.poly([(0, gy), (n, gy - n * 0.02), (n, n), (0, n)])
    ground(cv, el, [(earth, 1)], focus=(n * 0.52, gy), focus_r=0.45, focus_k=0.8, wash=0, rng=rng)
    paint_form(cv, earth, ["#05060C", "#0E1020", "#1A1C2E", "#2A2C40"], R=n * 0.05, grad=0.5)
    # a crimson-lit fissure running through the ground toward the eruption
    fis = cv.poly(ribbon(spline([(n * 0.04, gy + n * 0.14), (n * 0.20, gy + n * 0.08), (n * 0.34, gy + n * 0.12), (n * 0.52, gy)], 6),
                         lambda t: n * (0.006 + 0.02 * t)))
    soft_light(cv, fis, el, 0.9, R=n * 0.006, glow_r=4)
    # eruption: a cone of earth light and stone chips thrown up
    cone = cv.poly([(n * 0.40, gy), (n * 0.02, n * 0.10), (n * 0.98, n * 0.10), (n * 0.62, gy)])
    soft_light(cv, cone * (0.2 + 0.8 * smoothstep(n * 0.1, gy, cv.grid()[1])), el, 0.6, R=n * 0.06, glow_r=6, core_k=0.4)
    for x, y, s in ((0.24, 0.36, 0.06), (0.78, 0.30, 0.05), (0.34, 0.16, 0.04), (0.70, 0.12, 0.035), (0.86, 0.50, 0.04),
                    (0.14, 0.52, 0.045)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=((0.52 - x), (0.62 - y)), trail=((x - 0.52), (y - 0.62)))
    # the blade bursting up out of the ground
    _ninjato(cv, (n * 0.72, n * 1.06), (n * 0.30, n * 0.14), "steel")
    # the near lip of the ground hides the hilt: the blade comes out of the earth
    front = cv.poly([(0, gy + n * 0.02), (n * 0.44, gy + n * 0.01), (n * 0.52, gy + n * 0.035), (n * 0.62, gy + n * 0.0),
                     (n, gy - n * 0.01), (n, n), (0, n)])
    paint_form(cv, front, ["#05060C", "#0E1020", "#1A1C2E", "#2A2C40"], R=n * 0.05, grad=0.5)
    soft_light(cv, fis, el, 0.9, R=n * 0.006, glow_r=4)
    cv.add(blur(cv.ellipse(n * 0.52, gy + n * 0.03, n * 0.10, n * 0.025), 2.0), tone(el)[1], 0.9)
    for x in (0.34, 0.42, 0.60, 0.68):   # broken ground slabs tilting up around the hole
        stone_chip(cv, rng, n * x, gy, n * 0.05, rng.uniform(-20, 20), el, hot_dir=(0.0, -1.0))
    hot_core(cv, n * 0.51, gy - n * 0.02, el, 2.6, 1.1, star_len=22)


@skill("ninja.moon_slaying_sakura", tone="sakura")
def moon_slaying(cv, rng, el):
    n = cv.n
    mc = np.array([n * 0.54, n * 0.44])
    R = n * 0.32
    ground(cv, el, [], focus=mc, focus_r=0.55, focus_k=0.4, ink="#04050A", wash=-40, rng=rng)
    # the moon: a pale painted disc with soft maria, split along the cut, the halves sliding apart
    d = _dv(-40)
    nv = np.array([-d[1], d[0]])
    X, Y = cv.grid()
    side = ((X - mc[0]) * nv[0] + (Y - mc[1]) * nv[1])
    disc_a = cv.ellipse(mc[0] - nv[0] * n * 0.02, mc[1] - nv[1] * n * 0.02, R) * (side < -n * 0.02)
    disc_b = shift(cv.ellipse(mc[0], mc[1], R) * (side > n * 0.02), int(nv[0] * n * 0.03 * 4), int(nv[1] * n * 0.03 * 4))
    glow(cv, cv.ellipse(mc[0], mc[1], R), "#C8D4EC", 18, 0.35)
    for dm in (disc_a, disc_b):
        ink_line(cv, dm, "#2A3046", 0.4, 2.0, 0.3)
        paint_form(cv, dm, ["#5E6478", "#A8B0C2", "#E2E6EE", "#FFFFFF"], R=R * 0.5, grad=0.5, tilt=(-0.2, -0.2))
        maria = dm * smoothstep(0.55, 0.75, lowfreq(cv.w, 7, 5))
        cv.paint(blur(maria, 2.0), "#7A84A0", 0.45)
    # the cut: a river of sakura petals streaming along the diagonal, a crimson slash line inside it
    p0, p1 = mc - d * n * 0.62, mc + d * n * 0.60
    light_streak(cv, p0, p1, n * 0.03, "crimson", 1.0)
    _petals(cv, rng, p0, p1, 30, n * 0.06, n * 0.10, 1.0)
    hot_core(cv, *(mc + d * n * 0.30), el, 2.6, 1.1, star_len=20, ang=-40)

    def bleed(c2):
        m = c2.ellipse(mc[0], mc[1], R)
        rim = np.clip(m - toward(m, 2.0, LIGHT), 0, 1)
        c2.add(blur(rim, 0.8), KEY["cool"], 0.9)   # the bar's one off-key accent: gold moon rim
    return {"bleed": bleed}
