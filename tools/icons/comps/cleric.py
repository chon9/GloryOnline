"""牧师 Cleric. White / navy / gold keyed bar: holy gold light, healing green, white cloth and feathers.
The bar's one off-key accent is the key's `cool` ice-cyan, on the ultimate 复活术's halo rim only.

Value plan:
  atk1           the cross staff swung down on a diagonal, its head bursting against a hot impact flare       [cross]
  rising_emblem  a near-round rune circle seen from above at a steep angle, three light spikes launching up
  heal           a soft green orb cradled by two spiral ribbons of light, leaf motes rising (slow, heal over time)
  cure           an opening flower of green-white light petals, a radial burst around a blazing core
  sacred_fire    a holy fireball streaking up to the right, flame tongues and embers trailing on the diagonal
  hypnosis       a crystal pendulum swinging on a gold chain, a white smoke spiral turning behind it
  angel_wings    a pair of white feathered wings spread wide and level, a small light core between them
  revive         a vertical beam falling from a floating halo onto a sanctuary ring, feathers drifting down
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_priest import feather, rune_circle, wing

GOLD = "#FFD86A"


def _cross_staff(cv, butt, top, el, scale=1.0):
    """十字架: an ivory staff with gold bands topped by a Latin cross with flared ends, white enamel panels inside
    gold rims, a sapphire at the crossing and a thin gold ring behind the crossing. Local frame along the staff."""
    n = cv.n
    H = weapon_H(butt, top, scale)
    ang = math.degrees(math.atan2(top[1] - butt[1], top[0] - butt[0]))
    shaft = lpoly(cv, H, [(0.0, -0.012), (0.70, -0.015), (0.70, 0.015), (0.0, 0.012)])
    ink_line(cv, shaft, "#1C2236", 0.4, 1.8, 0.4)
    solid(cv, H, shaft, "ivory", 0.012, line=False, streak_ang=ang, back=tone(el)[2], back_k=0.5)
    for x in (0.02, 0.36, 0.64):
        cyl_band(cv, H, x, x + 0.03, 0.02, "gold")
    cx = 0.84
    ring = np.clip(lpoly(cv, H, [(cx + math.cos(a) * 0.10, math.sin(a) * 0.10) for a in np.linspace(0, 2 * math.pi, 40)])
                   - lpoly(cv, H, [(cx + math.cos(a) * 0.085, math.sin(a) * 0.085) for a in np.linspace(0, 2 * math.pi, 40)]), 0, 1)
    solid(cv, H, ring, "gold", 0.01, lw=(0.2, 1.0))
    arms = []
    for (x0, y0, x1, y1) in ((0.68, 0.0, 1.0, 0.0), (cx, -0.16, cx, 0.16)):
        L = math.hypot(x1 - x0, y1 - y0)
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        vx, vy = -uy, ux
        w0, w1 = 0.028, 0.05   # flared toward the ends
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        pts = [(x0 + vx * w1, y0 + vy * w1), (mx + vx * w0, my + vy * w0), (x1 + vx * w1, y1 + vy * w1),
               (x1 - vx * w1, y1 - vy * w1), (mx - vx * w0, my - vy * w0), (x0 - vx * w1, y0 - vy * w1)]
        arms.append(lpoly(cv, H, pts))
    cm = union(cv, arms)
    glow(cv, cm, tone(el)[1], 8, 0.6)
    solid(cv, H, cm, "gold", 0.03, lw=(0.35, 1.8), back=tone(el)[2], back_k=0.6)
    inner = np.clip(cm - dilate(1 - cm, lR(H, 0.016)), 0, 1)
    solid(cv, H, inner, "ivory", 0.02, line=False)
    c = xf(H, [(cx, 0.0)])[0]
    gem = cv.ellipse(c[0], c[1], lR(H, 0.035))
    glow(cv, gem, GOLD, 4, 0.8)
    paint_form(cv, gem, ["#5A3A08", "#C88A1E", "#FFD86A", "#FFFBE6"], R=lR(H, 0.02), grad=0.5)   # topaz: stays in the warm key
    return union(cv, [shaft, cm, ring])


@skill("cleric.atk1", tone="holy")
def atk1(cv, rng, el):
    n = cv.n
    hit = np.array([n * 0.74, n * 0.30])
    ground(cv, el, [], focus=hit, focus_r=0.5, focus_k=0.7, wash=-40, rng=rng)
    crescent(cv, (n * 0.86, n * 0.96), n * 0.66, n * 0.80, 0, 186, 262, 0.30, el, 1.0)
    flare_spikes(cv, hit[0], hit[1], [(-150, 0.6), (-90, 0.8), (-30, 1.0), (20, 0.7), (70, 0.5), (120, 0.4)], n * 0.04, n * 0.30, n * 0.03, el, 0.9)
    _cross_staff(cv, (n * 0.30, n * 1.06), (n * 0.62, n * 0.06), el, 1.4)
    hot_core(cv, hit[0], hit[1], el, 2.8, 1.2, star_len=20)


@skill("cleric.rising_emblem", tone="holy")
def rising_emblem(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.66])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    disc = cv.ellipse(c[0], c[1], n * 0.40, n * 0.26)
    cv.add(blur(disc, 8), tone(el)[1], 0.35)
    rune_circle(cv, c, n * 0.42, n * 0.27, el, 1.0, w=n * 0.02)
    for (x, h, w) in ((0.50, 0.62, 0.07), (0.32, 0.40, 0.045), (0.68, 0.44, 0.045)):
        p0 = np.array([n * x, c[1] - n * 0.02])
        sp = cv.poly([(p0[0] - n * w, p0[1]), (p0[0], p0[1] - n * h), (p0[0] + n * w, p0[1])])
        soft_light(cv, sp, el, 1.0, R=n * 0.02, glow_r=8)
    for i in range(8):
        x = n * rng.uniform(0.2, 0.8)
        light_streak(cv, (x, n * rng.uniform(0.55, 0.75)), (x, n * rng.uniform(0.1, 0.4)), n * 0.01, "white", 0.6)
    hot_core(cv, c[0], c[1] - n * 0.04, el, 3.0, 1.2, star_len=20)


@skill("cleric.heal", tone="heal")
def heal(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.6, wash=-80, rng=rng)
    # two ribbons spiralling up around the orb (back halves dimmer)
    for front in (False, True):
        for ph in (0.0, math.pi):
            pts = []
            for t in np.linspace(0, 1, 60):
                a = ph + t * 3.2 * math.pi
                z = math.sin(a)
                if (z > 0) != front:
                    if len(pts) > 2:
                        m = cv.poly(ribbon(pts, lambda u: n * 0.03 + 0.4))
                        soft_light(cv, m, el, 1.0 if front else 0.4, R=n * 0.01, glow_r=4)
                    pts = []
                    continue
                r = n * (0.34 - 0.18 * t)
                pts.append((c[0] + math.cos(a) * r, n * (0.92 - 0.82 * t) + z * n * 0.04))
            if len(pts) > 2:
                m = cv.poly(ribbon(pts, lambda u: n * 0.03 + 0.4))
                soft_light(cv, m, el, 1.0 if front else 0.4, R=n * 0.01, glow_r=4)
        if not front:
            orb = cv.ellipse(c[0], c[1], n * 0.16)
            light_form(cv, orb, el, 1.0, R=n * 0.10, glow_r=14, lw=(0.3, 1.6))
            cv.add(blur(cv.ellipse(c[0] - n * 0.05, c[1] - n * 0.06, n * 0.05), 3) * orb, "#FFFFFF", 0.8)
    for i in range(9):   # leaf-shaped motes drifting up
        p = np.array([rng.uniform(0.15, 0.85) * n, rng.uniform(0.10, 0.85) * n])
        a = rng.uniform(-150, -30)
        lf = cv.poly(ribbon(spline([p, p + np.array([math.cos(math.radians(a)), math.sin(math.radians(a))]) * n * 0.05], 4),
                            lambda u: n * 0.03 * math.sin(math.pi * u) + 0.3))
        soft_light(cv, lf, el, 0.9, R=0.8, glow_r=3)
    hot_core(cv, c[0], c[1], el, 2.4, 1.0, star_len=16)


@skill("cleric.cure", tone="heal")
def cure(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.8, wash=-60, rng=rng)
    flare_spikes(cv, c[0], c[1], [(a + 22.5, 0.8 + 0.2 * (i % 2)) for i, a in enumerate(range(0, 360, 45))], n * 0.10, n * 0.50, n * 0.03, "white", 0.8)
    for ring, (L, w, rot, val) in enumerate(((0.40, 0.17, 0.0, 0.85), (0.27, 0.13, 22.5, 1.0))):
        for k in range(8):
            a = math.radians(rot + k * 45 - 90)
            d = np.array([math.cos(a), math.sin(a)])
            nv = np.array([-d[1], d[0]])
            base = c + d * n * 0.04
            tip = c + d * n * L
            pet = cv.poly(closed_spline([base, base + d * n * L * 0.45 + nv * n * w * 0.5, tip, base + d * n * L * 0.45 - nv * n * w * 0.5], 6))
            light_form(cv, pet, el, 1.0, R=n * 0.03, glow_r=4, lw=(0.25, 1.4), value=val)
            cv.paint(stroke(cv, [base + d * n * 0.04, tip - d * n * 0.04], n * 0.006, 0.3) * pet, tone(el)[1], 0.5)
    core = cv.ellipse(c[0], c[1], n * 0.07)
    soft_light(cv, core, "white", 1.0, R=n * 0.04, glow_r=8)
    hot_core(cv, c[0], c[1], "white", 3.2, 1.3, star_len=24)


@skill("cleric.sacred_fire", tone="holy")
def sacred_fire(cv, rng, el):
    """a holy fireball streaking up to the right: a painted fire burst for the head, a long tapering comet of gold
    flame behind it with flickering licks peeling off, dark smoke under the trail, embers"""
    n = cv.n
    c = np.array([n * 0.66, n * 0.34])
    back = np.array([-0.70, 0.71])
    nb = np.array([-back[1], back[0]])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.6, wash=-45, rng=rng)
    smoke(cv, rng, [c + back * n * 0.75 + nb * n * 0.04, c + back * n * 0.45, c + back * n * 0.20], n * 0.09, "#2A2418", 0.6)
    trail(cv, [c + back * n * 0.85, c + back * n * 0.45 + nb * n * 0.03, c], 2.0, n * 0.26, el, 0.9, core_k=0.6)
    for i in range(9):   # flame licks peeling off the comet, wavy, thin
        t0 = rng.uniform(0.05, 0.5)
        s_ = 1 if i % 2 else -1
        p0 = c + back * n * t0 + nb * s_ * n * 0.05
        p1 = p0 + back * n * 0.14 + nb * s_ * n * rng.uniform(0.04, 0.08)
        p2 = p1 + back * n * rng.uniform(0.10, 0.2) + nb * s_ * n * rng.uniform(-0.02, 0.06)
        trail(cv, [p2, p1, p0], 0.5, n * rng.uniform(0.03, 0.05), el, 0.75, core_k=0.5)
    for i in range(14):
        p = c + back * n * rng.uniform(0.2, 0.8) + nb * rng.uniform(-1, 1) * n * 0.14
        hot_core(cv, p[0], p[1], el, rng.uniform(0.4, 0.8), 0.7, star=False)
    burst(cv, rng, c, n * 0.17, el, 0.8, smoke_k=0.0, puffs=10, core=False)
    soft_light(cv, cv.ellipse(c[0] + n * 0.02, c[1] - n * 0.02, n * 0.05), "white", 0.6, R=n * 0.03, glow_r=6)
    hot_core(cv, c[0] + n * 0.02, c[1] - n * 0.02, "white", 2.4, 1.1, star_len=20)


@skill("cleric.hypnosis", tone="white")
def hypnosis(cv, rng, el):
    """催眠: a crystal pendulum on a gold chain mid-swing, two fading after-images along its arc, a pale crescent
    moon and slow star motes above, drowsy smoke drifting along the bottom"""
    n = cv.n
    pivot = np.array([n * 0.56, n * 0.02])
    L = n * 0.60

    def pendulum(ang_deg):
        ang = math.radians(ang_deg)
        bob = pivot + np.array([math.sin(ang), math.cos(ang)]) * L
        dv = (bob - pivot) / L
        nv = np.array([-dv[1], dv[0]])
        for i in range(18):
            p = pivot + (bob - pivot) * (i + 0.5) / 18
            lk = cv.ellipse(p[0], p[1], n * (0.010 if i % 2 else 0.006), n * 0.016)
            material(cv, lk, "gold", R=1.0, lw=(0.15, 0.7), brk=0.1)
        T = lambda x, y: bob + nv * n * x + dv * n * y
        tip = T(0.0, 0.30)
        mid = T(0.0, 0.10)
        a_, b_, c_ = T(-0.085, 0.08), T(0.0, 0.02), T(0.085, 0.07)
        cr = cv.poly([tuple(a_), tuple(b_), tuple(c_), tuple(tip)])
        glow(cv, cr, "#B8C8FF", 10, 0.6)
        ink_line(cv, cr, "#2A2E44", 0.3, 1.6, 0.3)
        for tri, v in (((a_, b_, mid), 0.95), ((b_, c_, mid), 0.7), ((a_, mid, tip), 0.75), ((mid, c_, tip), 0.45)):
            cv.paint(cv.poly([tuple(p) for p in tri]) * cr, mix("#3A4058", "#F2F0EA", v), 1.0)
        cap = cv.poly([tuple(T(-0.035, 0.0)), tuple(T(0.035, 0.0)), tuple(T(0.03, 0.03)), tuple(T(-0.03, 0.03))])
        material(cv, cap, "gold", R=n * 0.01, lw=(0.2, 1.0))
        return mid

    ground(cv, "holy", [], focus=(n * 0.40, n * 0.60), focus_r=0.5, focus_k=0.5, ink="#06070C", wash=-90, rng=rng)
    smoke(cv, rng, [(n * 0.0, n * 0.98), (n * 0.30, n * 0.88), (n * 0.56, n * 0.96), (n * 0.86, n * 0.86), (n * 1.04, n * 0.96)], n * 0.10,
          "#5A6074", 0.7)
    moon = np.clip(cv.ellipse(n * 0.20, n * 0.24, n * 0.13) - cv.ellipse(n * 0.27, n * 0.19, n * 0.12), 0, 1)
    light_form(cv, moon, el, 0.9, R=n * 0.03, glow_r=8, lw=(0.25, 1.3))
    for (x, y, s_) in ((0.38, 0.14, 0.9), (0.84, 0.30, 0.7), (0.10, 0.52, 0.6), (0.44, 0.34, 0.5)):
        hot_core(cv, n * x, n * y, el, s_, 0.8, star_len=10)
    for a_deg, k in ((-34, 0.25), (-22, 0.45)):   # after-images of the swing
        saved = cv.c.copy()
        pendulum(a_deg)
        cv.c = saved * (1 - k) + cv.c * k
    trail(cv, [pivot + np.array([math.sin(math.radians(a)), math.cos(math.radians(a))]) * (L + n * 0.10) for a in (-36, -24, -12)], 0.5, n * 0.05,
          el, 0.5, core_k=0.3)
    mid = pendulum(-8)
    hot_core(cv, mid[0], mid[1], el, 1.8, 1.0, star_len=14)


@skill("cleric.angel_wings", tone="white")
def angel_wings(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.56])
    ground(cv, "holy", [], focus=c, focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    for mirror in (False, True):
        wing(cv, c + np.array([(-1 if mirror else 1) * n * 0.04, 0]), n * 0.50, -14, "holy", mirror=mirror, lift=1.0)
    core = cv.ellipse(c[0], c[1], n * 0.06, n * 0.08)
    soft_light(cv, core, "holy", 1.0, R=n * 0.03, glow_r=10)
    for i in range(8):
        x = n * rng.uniform(0.3, 0.7)
        light_streak(cv, (x, n * 0.98), (x, n * rng.uniform(0.62, 0.8)), n * 0.01, "holy", 0.5)
    hot_core(cv, c[0], c[1], "holy", 2.6, 1.1, star_len=18)


@skill("cleric.revive", tone="holy")
def revive(cv, rng, el):
    n = cv.n
    cool = KEY["cool"]
    ground(cv, el, [], focus=(n * 0.5, n * 0.70), focus_r=0.55, focus_k=0.6, ink="#05060A", wash=-90, rng=rng)
    beam = cv.poly([(n * 0.40, n * 0.20), (n * 0.60, n * 0.20), (n * 0.70, n * 0.86), (n * 0.30, n * 0.86)])
    soft_light(cv, blur(beam, 3), el, 0.8, R=n * 0.10, glow_r=14, core_k=0.6)
    for i in range(7):
        x = n * rng.uniform(0.40, 0.60)
        light_streak(cv, (x, n * 0.22), (x + (x - n * 0.5) * 0.4, n * 0.84), n * rng.uniform(0.01, 0.02), "white", 0.6)
    rune_circle(cv, (n * 0.50, n * 0.84), n * 0.42, n * 0.11, "heal", 0.9, w=n * 0.02, star=8)
    # halo: a thick gold ring in perspective with a cyan outer rim
    hc = np.array([n * 0.50, n * 0.18])
    ring = shock_ring(cv, hc, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.22, n * 0.07, n * 0.05, el, 1.0, front_k=1.0)
    halo = np.clip(cv.ellipse(hc[0], hc[1], n * 0.23, n * 0.075) - cv.ellipse(hc[0], hc[1], n * 0.18, n * 0.05), 0, 1)
    material(cv, halo, "gold", R=n * 0.012, lw=(0.25, 1.3), back=cool, back_k=1.0)
    cv.add(np.clip(dilate(halo, 1.2) - halo, 0, 1), cool, 0.9)
    for (x, y, a, s) in ((0.20, 0.42, 120, 0.12), (0.80, 0.50, 70, 0.11), (0.28, 0.66, 150, 0.09), (0.74, 0.30, 40, 0.08)):
        ar = math.radians(a)
        b = np.array([n * x, n * y])
        feather(cv, b, b + np.array([math.cos(ar), math.sin(ar)]) * n * s, n * s * 0.30, el)
    hot_core(cv, n * 0.50, n * 0.80, el, 3.0, 1.2, star_len=22)
