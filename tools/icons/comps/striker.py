"""拳法家 Striker (red boxing gloves, white gi). Warm-keyed bar: fire orange, crimson and gi-white on a red-black
ground, gold knuckle guards. The bar's one off-key accent is ice-cyan, on the ultimate's rim.

Value plan:
  jab             a gloved fist snapping up-right with its own afterimage, a small hit star: short diagonal [gloves]
  launching_kick  a leg kicking straight up the middle, the boot at the top, a launch arc: tall column
  straight_punch  the fist dead level at the right, the arm behind it, long dash streaks: horizontal bar [gloves]
  eagle_stamp     a boot stamping down from the top into a crater, two wings of fire spread low: inverted T
  iron_bones      a bell-shaped shell of riveted iron scale with gold seams, blades glancing off: dome
  emperors_fist   the fist foreshortened straight at the viewer inside rings of wind pressure: big disc  [gloves]
  blade_block     an open bare palm catching the point of a diving blade, the blade snapping: diagonal + hand
  tiger_flurry    a fan of fist afterimages under one rising fist, three tiger claw rakes behind: fan    [gloves]
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_gunfight import boot, boot_H, fist_side, leg, palm

PANTS = ["#120406", "#2E0A0E", "#5A1A1C", "#86383A"]
SHOE = "redlac"


def _u(a, b):
    d = np.asarray(b, float) - np.asarray(a, float)
    return d / (np.linalg.norm(d) + 1e-9)


def _fist_outline(cv, H):
    """the silhouette of fist_side (hand + rolls + thumb), without the forearm"""
    hand = lpoly(cv, H, spline([(0.08, -0.38), (0.45, -0.46), (0.70, -0.44), (0.72, 0.40), (0.45, 0.44), (0.10, 0.38)], 4))
    parts = [hand, lrib(cv, H, [(0.36, 0.40), (0.56, 0.30), (0.78, 0.16), (0.86, 0.10)], 0.18, 0.12, 6)]
    for y, x1 in ((-0.33, 1.0), (-0.11, 1.03), (0.11, 1.0), (0.31, 0.94)):
        parts.append(lpoly(cv, H, spline([(0.56, y - 0.105), (x1 - 0.06, y - 0.11), (x1, y - 0.06), (x1 + 0.01, y), (x1, y + 0.06),
                                          (x1 - 0.06, y + 0.105), (0.56, y + 0.10)], 4)))
    return union(cv, parts)


def _ghost_fist(cv, H, el, k=0.6):
    m = _fist_outline(cv, H)
    d = xf(H, [(1.0, 0.0)])[0] - xf(H, [(0.0, 0.0)])[0]
    f = streak_field(cv.w, math.degrees(math.atan2(d[1], d[0])), 60, 4, cv.seed())
    edge = np.clip(m - toward(m, max(1.0, lR(H, 0.05)), -LIGHT * 0 + np.array([0.0, 0.0]) + d / (np.linalg.norm(d) + 1e-9)), 0, 1)
    soft_light(cv, blur(m, 1.0) * (0.35 + 0.65 * f), el, k * 0.7, R=max(1.0, lR(H, 0.1)), glow_r=5, core_k=0.3)
    cv.add(blur(edge, 0.8), tone(el)[2], 0.6 * k)
    return m


@skill("striker.jab", tone="white")
def jab(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n), (0, n * 0.62), (n * 0.62, 0), (n, 0), (n, n * 0.30), (n * 0.30, n)])
    ground(cv, el, [(band, 1)], focus=(n * 0.76, n * 0.26), focus_r=0.45, focus_k=0.7, wash=-40, rng=rng)
    k = np.array([n * 0.74, n * 0.30])
    d = _u((n * 0.10, n * 0.90), k)
    nv = np.array([-d[1], d[0]])
    for o in (-0.16, 0.0, 0.14):
        light_streak(cv, k - d * n * 0.66 + nv * n * o, k - d * n * 0.30 + nv * n * o * 0.8, n * 0.014, "crimson", 0.6)
    crescent(cv, k - d * n * 0.30 + nv * n * 0.10, n * 0.30, n * 0.18, math.degrees(math.atan2(d[1], d[0])), 150, 20, 0.35, "crimson", 0.7)
    fist_side(cv, weapon_H(k - d * n * 0.34, k, 1.0), el, arm_len=1.4)
    tip = k + d * n * 0.05
    shock_ring(cv, tip, nv, d, n * 0.14, n * 0.05, n * 0.02, "fire", 0.8)
    flare_spikes(cv, tip[0], tip[1], [(-60, 1.0), (-20, 0.7), (20, 0.5), (-100, 0.5)], n * 0.03, n * 0.16, n * 0.03, "fire", 0.8)
    hot_core(cv, tip[0], tip[1], "fire", 2.4, 1.0, star_len=16)


@skill("striker.launching_kick", tone="fire")
def launching_kick(cv, rng, el):
    n = cv.n
    col_m = cv.poly([(n * 0.30, 0), (n * 0.74, 0), (n * 0.66, n), (n * 0.36, n)])
    ground(cv, el, [(col_m, 1)], focus=(n * 0.56, n * 0.16), focus_r=0.45, focus_k=0.8, wash=-90, rng=rng)
    crescent(cv, (n * 0.60, n * 0.62), n * 0.42, n * 0.50, 0, 150, 268, 0.35, el, 1.0)
    for x, y0, y1 in ((0.18, 0.90, 0.40), (0.84, 0.86, 0.30), (0.26, 0.60, 0.16)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * 0.016, el, 0.6)
    knee, ankle = np.array([n * 0.44, n * 0.74]), np.array([n * 0.52, n * 0.46])
    leg(cv, [(n * 0.30, n * 1.12), knee, ankle], [n * 0.30, n * 0.25, n * 0.19], PANTS, el, rim=tone(el)[2],
        folds=((0.45, 0.7), (0.8, 0.5)))
    boot(cv, boot_H(ankle, knee, (1.0, -0.25), n * 0.32), el, mat=SHOE)
    top = np.array([n * 0.74, n * 0.16])
    burst(cv, rng, top, n * 0.09, el, 0.9, smoke_k=0.0, puffs=5, core=False)
    hot_core(cv, top[0], top[1] + n * 0.02, el, 2.6, 1.1, star_len=20)


@skill("striker.straight_punch", tone="crimson")
def straight_punch(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.36), (n, n * 0.34), (n, n * 0.68), (0, n * 0.70)])
    ground(cv, el, [(band, 1)], focus=(n * 0.86, n * 0.50), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    speed_lines(cv, rng, 0, 12, el, 0.6, band=(0.25, 0.75))
    k = np.array([n * 0.86, n * 0.52])
    for i, x in enumerate((0.30, 0.48)):   # afterimages of the dash
        _ghost_fist(cv, weapon_H((n * (x - 0.26), k[1]), (n * x, k[1]), 1.0), el, 0.35 + 0.15 * i)
    fist_side(cv, weapon_H((n * 0.56, k[1]), k, 1.0), "fire", arm_len=2.4)
    for s, kk in ((1.0, 0.9), (1.5, 0.6)):
        shock_ring(cv, k + np.array([n * 0.04 * s, 0]), np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * 0.20 * s, n * 0.06 * s, n * 0.025, el, kk,
                   -60, 240)
    hot_core(cv, k[0] + n * 0.04, k[1], el, 2.6, 1.1, star_len=22)


@skill("striker.eagle_stamp", tone="fire")
def eagle_stamp(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.70), (n, n * 0.68), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.80), focus_r=0.5, focus_k=0.8, wash=-90, rng=rng)
    imp = np.array([n * 0.50, n * 0.80])
    for sg in (-1, 1):   # wings of fire sweeping out low on either side of the stamp
        crescent(cv, (n * 0.50, n * 0.40), n * 0.46, n * 0.36, 0, 90 - sg * 10, 90 - sg * 80, 0.40, el, 0.9)
    shock_ring(cv, imp, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.40, n * 0.10, n * 0.035, el, 1.0)
    for a in (-170, -150, -25, -8, 15, 165):
        ar = math.radians(a)
        p1 = imp + np.array([math.cos(ar) * n * 0.38, math.sin(ar) * n * 0.09 + n * 0.02])
        crack = cv.poly(ribbon(spline([imp, (imp + p1) / 2 + np.array([0, n * 0.012]), p1], 4), [n * 0.014, n * 0.008, 0.4]))
        soft_light(cv, crack, el, 0.8, R=0.8, glow_r=3)
    for x, y, s, dx in ((0.10, 0.62, 0.05, -1), (0.90, 0.60, 0.05, 1), (0.22, 0.52, 0.035, -1), (0.80, 0.50, 0.035, 1)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-dx * 0.8, 0.6), trail=(dx, -0.5))
    ankle = np.array([n * 0.46, n * 0.50])
    leg(cv, [(n * 0.40, n * -0.12), (n * 0.43, n * 0.20), ankle], [n * 0.30, n * 0.26, n * 0.20], PANTS, el, rim=tone(el)[2],
        folds=((0.55, 0.7),))
    boot(cv, boot_H(ankle, (n * 0.43, n * 0.20), (1.0, 0.12), n * 0.32), el, mat=SHOE)
    hot_core(cv, imp[0], imp[1] - n * 0.04, el, 2.8, 1.1, star_len=22)


@skill("striker.iron_bones", tone="white")
def iron_bones(cv, rng, el):
    """钢筋铁骨: the forearms crossed in a guard, bound in iron bands like rebar, a gold aura flaring behind them and
    blades glancing off in sparks; the gloves stay outside the frame"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.46), focus_r=0.6, focus_k=0.6, wash=-60, rng=rng)
    c = np.array([n * 0.50, n * 0.52])
    aura = cv.poly(closed_spline([(c[0] + math.cos(a) * n * (0.40 + 0.04 * math.sin(a * 6)), c[1] + math.sin(a) * n * (0.42 + 0.04 * math.sin(a * 6)))
                                  for a in np.linspace(0, 2 * math.pi, 18, endpoint=False)], 6))
    glow(cv, aura, "#FFB45A", 14, 0.5)
    shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.42, n * 0.42, n * 0.035, "fire", 0.8)
    arms = []
    for sg in (-1, 1):   # back arm first: from lower-left to upper-right, then the front arm crossing over it
        a0 = np.array([n * 0.50 - sg * n * 0.62, n * 1.06])
        a1 = np.array([n * 0.50 + sg * n * 0.62, n * -0.06])
        d = _u(a0, a1)
        nv = np.array([-d[1], d[0]])
        arm = cv.poly([a0 + nv * n * 0.10, a1 + nv * n * 0.085, a1 - nv * n * 0.085, a0 - nv * n * 0.10])
        material(cv, arm, "gf_wrap", R=n * 0.06, lw=(0.45, 2.4), back=tone("fire")[2], back_k=0.7)
        for t in np.linspace(0.08, 0.92, 9):   # cloth wraps
            p = a0 + (a1 - a0) * t
            cv.paint(cv.poly(ribbon([p - nv * n * 0.11, p + nv * n * 0.11 + d * n * 0.03], [n * 0.012, n * 0.012])) * arm, "#6E6458", 0.6)
        for t in (0.20, 0.36, 0.64, 0.80):   # iron bands
            p = a0 + (a1 - a0) * t
            band = cv.poly([p - d * n * 0.03 + nv * n * 0.11, p + d * n * 0.03 + nv * n * 0.10, p + d * n * 0.03 - nv * n * 0.10,
                            p - d * n * 0.03 - nv * n * 0.11])
            material(cv, band, "darksteel", R=n * 0.015, lw=(0.3, 1.4), back="#FFC86A", back_k=0.7)
            for o in (-0.07, 0.0, 0.07):
                cv.paint(cv.ellipse(*(p + nv * n * o), n * 0.009) * band, KEY["metal_hi"], 0.9)
        arms.append(arm)
    cross = c + np.array([0, n * 0.0])
    for (x, y, a) in ((0.10, 0.30, 25), (0.90, 0.36, 155), (0.86, 0.80, 200)):   # blades glancing off with sparks
        p = np.array([n * x, n * y])
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        nv = np.array([-d[1], d[0]])
        bl = cv.poly([p - d * n * 0.20 + nv * n * 0.014, p + d * n * 0.02, p - d * n * 0.20 - nv * n * 0.018])
        material(cv, bl, "steel", R=n * 0.006, lw=(0.25, 1.1), streak_ang=a)
        sparks(cv, rng, p + d * n * 0.02, 6, n * 0.08, "fire", 0.9, a_range=(a + 100, a + 260), width=1.2)
    hot_core(cv, cross[0], cross[1], "fire", 2.6, 1.0, star_len=22)


@skill("striker.emperors_fist", tone="fire")
def emperors_fist(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.56, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.6, focus_k=0.8, wash=-30, rng=rng)
    for i, r in enumerate((0.46, 0.36, 0.27)):   # wind pressure rings rushing at the viewer
        shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.92, n * (0.03 - i * 0.006), el, 0.7 + 0.15 * i)
    for i in range(14):
        a = math.radians(i * 360 / 14 + rng.uniform(-8, 8))
        d = np.array([math.cos(a), math.sin(a)])
        light_streak(cv, c + d * n * 0.30, c + d * n * rng.uniform(0.50, 0.70), n * 0.016, "crimson", 0.6)
    # the fist foreshortened: wrist small up-left in the distance, knuckles huge and near
    src = [(-0.6, -0.5), (1.05, -0.5), (1.05, 0.5), (-0.6, 0.5)]
    dst = [(n * 0.12, n * 0.16), (n * 0.80, n * 0.20), (n * 0.76, n * 0.86), (n * 0.18, n * 0.34)]
    fist_side(cv, H_quad(src, dst), el, arm_len=0.6)
    hot_core(cv, n * 0.74, n * 0.54, el, 2.8, 1.0, star_len=22)


@skill("striker.blade_block", tone="white")
def blade_block(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.48, n * 0.46), focus_r=0.5, focus_k=0.7, wash=45, rng=rng)
    hit = np.array([n * 0.46, n * 0.46])
    d = _u((n * 1.1, n * -0.1), hit)
    nv = np.array([-d[1], d[0]])
    # the diving blade, snapped near its point: the main length, a gap, the flying tip
    base = hit - d * n * 0.10
    far = hit - d * n * 0.90
    blade = cv.poly([far + nv * n * 0.045, base + nv * n * 0.04, base - nv * n * 0.035 + d * n * 0.02, far - nv * n * 0.04])
    material(cv, blade, "steel", R=n * 0.02, lw=(0.35, 1.8), streak_ang=math.degrees(math.atan2(d[1], d[0])), back=tone("fire")[2], back_k=0.7)
    cv.paint(cv.poly([far + nv * n * 0.004, base + nv * n * 0.004, base - nv * n * 0.004, far - nv * n * 0.004]) * blade, "#3A4256", 0.6)
    tipc = hit + np.array([n * 0.22, n * 0.18])
    tp = cv.poly([tipc - d * n * 0.06 + nv * n * 0.03, tipc + d * n * 0.08, tipc - d * n * 0.06 - nv * n * 0.03])
    material(cv, tp, "steel", R=n * 0.01, lw=(0.25, 1.2))
    trail(cv, [hit + np.array([n * 0.06, n * 0.05]), tipc - np.array([n * 0.04, n * 0.03])], 0.3, n * 0.02, "fire", 0.6)
    for i in range(5):
        p = hit + np.array([n * rng.uniform(0.04, 0.22), n * rng.uniform(-0.10, 0.10)])
        sh = cv.poly([p, p + np.array([n * 0.02, -n * 0.01]), p + np.array([n * 0.012, n * 0.02])])
        material(cv, sh, "steel", R=1.0, lw=(0.2, 0.7))
    # the open bare palm meeting it, wrists wrapped in gi white
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.45), (-0.55, 0.45)]
    dst = [(n * 0.06, n * 0.24), (n * 0.66, n * 0.36), (n * 0.56, n * 1.04), (n * -0.06, n * 0.92)]
    palm(cv, H_quad(src, dst), "fire", mat="gf_wrap", palm_mat="gf_skin")
    shock_ring(cv, hit, np.array([0.8, -0.6]), np.array([0.6, 0.8]), n * 0.16, n * 0.06, n * 0.02, "fire", 0.9)
    flare_spikes(cv, hit[0], hit[1], [(-30, 1.0), (60, 0.7), (150, 0.6), (-120, 0.6)], n * 0.03, n * 0.18, n * 0.03, "fire", 0.9)
    hot_core(cv, hit[0], hit[1], "fire", 2.8, 1.1, star_len=22)


@skill("striker.tiger_flurry", tone="crimson")
def tiger_flurry(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.56, n * 0.30), focus_r=0.55, focus_k=0.7, ink="#070404", wash=-60, rng=rng)
    for i, (x0, x1) in enumerate(((0.62, 0.98), (0.48, 0.90), (0.36, 0.78))):   # three tiger claw rakes
        pts = [(n * x0, n * (0.04 + i * 0.05)), (n * (x0 + x1) / 2 + n * 0.02, n * (0.42 + i * 0.05)), (n * x1 - n * 0.06, n * (0.92 - i * 0.02))]
        m = cv.poly(ribbon(spline(pts, 10), lambda t: n * 0.05 * math.sin(math.pi * t) ** 0.7 + 0.4))
        soft_light(cv, m, "fire", 0.75, R=n * 0.012, glow_r=5, core_k=0.6)
    src = np.array([n * 0.10, n * 1.02])
    for i, (a, L) in enumerate(((-85, 0.70), (-62, 0.82), (-20, 0.80), (2, 0.70))):   # the flurry: receding fists, pushed back by haze
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        kk = src + d * n * L
        fm = fist_side(cv, weapon_H(kk - d * n * 0.24, kk, 0.85), "fire", arm_len=0.9)
        cv.paint(fm, mix(KEY["ink_warm"], tone(el)[0], 0.5), 0.45)
        cv.add(np.clip(fm - toward(fm, 1.2, -d), 0, 1), tone(el)[2], 0.6)
    d = _u((n * 0.42, n * 1.0), (n * 0.58, n * 0.22))
    k = np.array([n * 0.58, n * 0.24])
    H = weapon_H(k - d * n * 0.36, k, 1.05)
    m = fist_side(cv, H, "fire", arm_len=1.6)
    burst(cv, rng, k + d * n * 0.10, n * 0.08, "fire", 0.8, smoke_k=0.0, puffs=5, core=False)
    hot_core(cv, k[0] + d[0] * n * 0.06, k[1] + d[1] * n * 0.06, "fire", 2.8, 1.1, star_len=22)

    def bleed(c2):
        c2.add(np.clip(m - toward(m, 1.6, LIGHT), 0, 1), KEY["cool"], 0.85)   # the bar's one off-key accent: ice-cyan rim
    return {"bleed": bleed}
