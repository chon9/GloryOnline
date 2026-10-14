"""狂剑士 Berserker (huge greatsword, bare arm, tattered half-cape). Blood-keyed bar: crimson blood, rage orange and
bronze on a near-black ground. The bar's one off-key accent is the key's violet, on the ultimate's outer wave rim.

Value plan:
  atk1                 the greatsword on a rising diagonal, a wide flat horizontal cleave smear       [greatsword]
  backwards_slash      a tall "(" crescent rising from a ground burst, armour shards flung straight up
  collapsing_mountain  the greatsword driven point-down into the ground: vertical blade over a wide
                       shock ellipse, cracks and stone chips                                          [greatsword]
  gore_cross           two uneven crossing slashes on a cut breastplate, blood spraying from the cross
  blood_sword          a horizontal arrow of blood light, a spiral blood ribbon wound around its shaft
  crimson_grip         a huge clawed hand of blood light from the upper right, pull streaks converging
  enrage               a bare fist thrust straight up, burning veins, a column of rage flame
  crimson_storm        three nested blood-wave rings around one hot core, a violet rim on the outer wave
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_swordmage import BLOOD, droplet, droplets, flame, greatsword

DARK_BLOOD = ["#1A0204", "#4A060C", "#8E1420", "#D8404A"]


@skill("berserker.atk1", tone="blood")
def heavy_cleave(cv, rng, el):
    n = cv.n
    mass = cv.poly([(0, n * 0.62), (n * 0.6, n * 0.98), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.70, n * 0.40), focus_r=0.5, focus_k=0.6, wash=-10, rng=rng)
    crescent(cv, (n * 0.46, n * 0.58), n * 0.50, n * 0.22, -8, 160, 345, 0.42, el, 1.0)
    H = weapon_H((n * 0.08, n * 0.90), (n * 0.90, n * 0.26), 1.0)
    greatsword(cv, H, el)
    tip = xf(H, [(0.97, 0.0)])[0]
    droplets(cv, rng, tip + np.array([n * 0.02, n * 0.06]), 5, n * 0.02, n * 0.16, (10, 70), n * 0.022)
    hot_core(cv, tip[0], tip[1], el, 2.2, 1.0, star_len=16, ang=-38)


@skill("berserker.backwards_slash", tone="rage")
def backwards_slash(cv, rng, el):
    """the launcher: a tall smear sweeping up the right side from a ground burst at the lower left, armour shards
    flung straight up off its head"""
    n = cv.n
    low = cv.poly([(0, n * 0.82), (n, n * 0.86), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.62, n * 0.16), focus_r=0.5, focus_k=0.6, wash=-75, rng=rng)
    for x, y0, y1, w in ((0.44, 0.92, 0.40, 0.016), (0.74, 0.70, 0.30, 0.012), (0.26, 0.80, 0.50, 0.010)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.6)
    burst(cv, rng, (n * 0.24, n * 0.86), n * 0.13, el, 0.8, smoke_k=0.7, puffs=7, core=False)
    crescent(cv, (n * 0.10, n * 0.70), n * 0.74, n * 0.62, 0, 80, -58, 0.30, el, 1.0, streak_freq=110)
    for x, y, s, a in ((0.60, 0.14, 0.13, -20), (0.82, 0.30, 0.09, 30), (0.40, 0.24, 0.08, 60)):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 0.9, trail=(0.0, -1.0))
    for x, y in ((0.52, 0.36), (0.70, 0.48)):
        droplet(cv, n * x, n * y, n * 0.018, -90, BLOOD, "#1A0104")
    hot_core(cv, n * 0.48, n * 0.10, el, 2.4, 1.0, star_len=18)


@skill("berserker.collapsing_mountain", tone="bronze")
def collapsing_mountain(cv, rng, el):
    n = cv.n
    imp = np.array([n * 0.50, n * 0.78])
    floor = cv.poly([(0, n * 0.70), (n, n * 0.70), (n, n), (0, n)])
    ground(cv, "rage", [(floor, 1)], focus=imp, focus_r=0.45, focus_k=0.8, wash=-20, rng=rng)
    for a in (-178, -160, -140, 175, 150, -2, -22, -40, 10, 35):   # cracks radiating across the floor, glowing inside
        ar = math.radians(a)
        L = n * rng.uniform(0.28, 0.48)
        p1 = imp + np.array([math.cos(ar) * L, abs(math.sin(ar)) * L * 0.30 + n * 0.02])
        pts = [imp, (imp + p1) / 2 + np.array([rng.uniform(-1, 1) * n * 0.03, rng.uniform(-1, 1) * n * 0.012]), p1]
        cm = stroke(cv, pts, n * 0.016, 0.4)
        cv.paint(blur(cm, 0.6), "#050203", 0.9)
        cv.add(blur(cm, 1.2) * 0.8, tone("rage")[1], 0.7)
    shock_ring(cv, imp, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.40, n * 0.10, n * 0.03, "rage", 1.0)
    for x, y, s, a in ((0.16, 0.50, 0.05, 20), (0.84, 0.46, 0.06, -30), (0.24, 0.30, 0.04, 70), (0.78, 0.26, 0.035, 10),
                       (0.10, 0.70, 0.04, -10), (0.92, 0.66, 0.04, 40)):
        dv = np.array([n * x, n * y]) - imp
        dv = dv / np.linalg.norm(dv)
        stone_chip(cv, rng, n * x, n * y, n * s, a, "rage", hot_dir=-dv, trail=dv)
    H = weapon_H((n * 0.52, n * 0.02), (n * 0.50, n * 0.80), 1.7)
    greatsword(cv, H, el)
    burst(cv, rng, imp + np.array([0, n * 0.02]), n * 0.10, "rage", 0.7, smoke_k=0.0, puffs=6, core=False)
    hot_core(cv, imp[0], imp[1] - n * 0.01, "rage", 2.6, 1.2, star_len=26)


@skill("berserker.gore_cross", tone="blood")
def gore_cross(cv, rng, el):
    """a cuirass cut by two crossing slashes, the four pieces sliding apart, blood bursting out of the crossing"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.50), focus_r=0.5, focus_k=0.6, wash=-45, rng=rng)
    out = [(n * 0.30, n * 0.14), (n * 0.42, n * 0.20), (n * 0.50, n * 0.26), (n * 0.58, n * 0.20), (n * 0.70, n * 0.14),
           (n * 0.72, n * 0.26), (n * 0.80, n * 0.40), (n * 0.80, n * 0.60), (n * 0.72, n * 0.82), (n * 0.50, n * 0.90),
           (n * 0.28, n * 0.82), (n * 0.20, n * 0.60), (n * 0.20, n * 0.40), (n * 0.28, n * 0.26)]
    base = cv.poly(out)
    cross = np.array([n * 0.50, n * 0.52])
    angs = (-50.0, 38.0)
    ds = [np.array([math.cos(math.radians(a)), math.sin(math.radians(a))]) for a in angs]
    nvs = [np.array([-d[1], d[0]]) for d in ds]
    X, Y = cv.grid()
    p0 = (X - cross[0]) * nvs[0][0] + (Y - cross[1]) * nvs[0][1]
    p1 = (X - cross[0]) * nvs[1][0] + (Y - cross[1]) * nvs[1][1]
    gap = n * 0.016
    ridge0 = cv.poly(ribbon([(n * 0.50, n * 0.28), (n * 0.50, n * 0.88)], [n * 0.014] * 2))
    for s0 in (-1, 1):
        for s1 in (-1, 1):
            q = (base * ((p0 * s0) > gap) * ((p1 * s1) > gap)).astype(np.float32)
            push = (nvs[0] * s0 + nvs[1] * s1) * n * 0.022
            dx, dy = int(round(push[0] * SS)), int(round(push[1] * SS))
            q = shift(q, dx, dy)
            material(cv, q, "plate", R=n * 0.06, lw=(0.35, 1.9), grad=0.5, tilt=(0.25 * s1, -0.15 * s0), back=tone(el)[1], back_k=0.6)
            trim = np.clip(q - (blur(q, n * 0.022) > 0.97), 0, 1) * (Y < n * 0.36)
            material(cv, trim, "bronze", R=n * 0.01, line=False)
            cv.paint(shift(ridge0, dx, dy) * q, "#B8C2D4", 0.45)
    for d, L, w in ((ds[0], 0.50, 0.050), (ds[1], 0.42, 0.040)):
        m = cv.poly(ribbon([cross - d * n * L, cross - d * n * L * 0.3, cross + d * n * L * 0.4, cross + d * n * L], [0.4, n * w * 0.8, n * w, 0.4]))
        glow(cv, m, tone(el)[1], 6, 0.8)
        soft_light(cv, m, el, 1.0, R=n * 0.012, glow_r=3, core_k=1.2)
    droplets(cv, rng, cross, 12, n * 0.06, n * 0.36, (-30, 210), n * 0.026)
    hot_core(cv, cross[0], cross[1], el, 2.6, 1.2, star_len=22, ang=-50)


@skill("berserker.blood_sword", tone="blood")
def blood_sword(cv, rng, el):
    """the blood arrow: a barbed head of crystallised blood, a spiral ribbon of blood wound around the shaft"""
    n = cv.n
    y = n * 0.54
    band = cv.poly([(0, n * 0.38), (n, n * 0.40), (n, n * 0.68), (0, n * 0.70)])
    ground(cv, el, [(band, 1)], focus=(n * 0.80, y), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    speed_lines(cv, rng, 0, 6, el, 0.4, band=(0.15, 0.4))
    speed_lines(cv, rng, 0, 4, el, 0.4, band=(0.7, 0.9))
    shaft = cv.poly(ribbon([(n * -0.02, y + n * 0.01), (n * 0.30, y), (n * 0.60, y)], [0.5, n * 0.07, n * 0.10]))
    light_form(cv, shaft, el, 0.9, R=n * 0.03, glow_r=8, lw=(0.3, 1.6))
    xs = np.linspace(n * 0.02, n * 0.62, 70)
    amp = n * 0.11 * np.linspace(0.35, 1.0, 70)
    ph = np.linspace(0, 4.6 * math.pi, 70)
    pts = np.c_[xs, y + np.sin(ph) * amp]
    rib = cv.poly(ribbon(pts, lambda t: n * 0.012 + n * 0.03 * t))
    front = (np.cos(np.interp(cv.grid()[0], xs, ph)) > 0).astype(np.float32)
    cv.paint(rib * (1 - front), "#2A0206", 0.85)
    ink_line(cv, rib * front, "#1A0104", 0.25, 1.4, 0.3)
    paint_form(cv, rib * front, BLOOD, R=n * 0.012, grad=0.4)
    head = cv.poly([(n * 0.52, y - n * 0.16), (n * 0.68, y - n * 0.05), (n * 0.98, y), (n * 0.68, y + n * 0.05), (n * 0.52, y + n * 0.16),
                    (n * 0.60, y)])
    glow(cv, head, tone(el)[1], 10, 0.9)
    ink_line(cv, head, "#1A0104", 0.3, 2.0, 0.3)
    up = head * (cv.grid()[1] < y)
    paint_form(cv, up, ["#8E1420", "#E0323C", "#FF8A80", "#FFE6E0"], R=n * 0.025, tilt=tuple(LIGHT2 * 0.5), grad=0.5)
    paint_form(cv, np.clip(head - up, 0, 1), DARK_BLOOD, R=n * 0.025, tilt=tuple(-LIGHT2 * 0.4), grad=0.5)
    for x, yy, r in ((0.16, 0.30, 0.02), (0.30, 0.80, 0.024), (0.08, 0.72, 0.016), (0.40, 0.24, 0.016), (0.48, 0.84, 0.018)):
        droplet(cv, n * x, n * yy, n * r, 0, BLOOD, "#1A0104")
    hot_core(cv, n * 0.96, y, el, 2.4, 1.0, star_len=18)


@skill("berserker.crimson_grip", tone="rage")
def crimson_grip(cv, rng, el):
    """a huge demonic hand of dark blood reaching down from above, claws closing on a point; pull streaks converge"""
    n = cv.n
    tgt = np.array([n * 0.50, n * 0.86])
    ground(cv, "blood", [], focus=tgt, focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    for a in range(0, 360, 30):
        ar = math.radians(a + rng.uniform(-8, 8))
        d = np.array([math.cos(ar), math.sin(ar)])
        light_streak(cv, tgt + d * n * 0.46, tgt + d * n * 0.14, n * 0.014, "blood", 0.55)
    pc = np.array([n * 0.50, n * 0.34])
    arm = cv.poly(ribbon(spline([(n * 0.66, n * -0.06), (n * 0.58, n * 0.10), pc + np.array([0, -n * 0.04])], 6), lambda u: n * (0.22 - 0.04 * u)))
    palm = cv.ellipse(pc[0], pc[1], n * 0.19, n * 0.13)
    parts = [arm, palm]
    fingers, claws = [], []
    for a, L, bend in ((132, 0.36, -32), (106, 0.44, -18), (78, 0.44, 18), (52, 0.36, 32)):
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        base = pc + d * n * 0.09
        k1 = base + d * n * L * 0.50
        br = math.radians(a + bend)
        d2 = np.array([math.cos(br), math.sin(br)])
        k2 = k1 + d2 * n * L * 0.34
        br2 = math.radians(a + bend * 2.2)
        d3 = np.array([math.cos(br2), math.sin(br2)])
        tip = k2 + d3 * n * L * 0.18
        fw = n * 0.078
        f = union(cv, [cv.poly(ribbon(spline([base, k1, k2, tip], 6), lambda u: fw * (1 - u * 0.45) + 0.4)), cv.ellipse(k1[0], k1[1], fw * 0.56)])
        fingers.append(f)
        parts.append(f)
        claws.append(stroke(cv, [tip - d3 * n * 0.01, tip + d3 * n * 0.05, tip + d3 * n * 0.08 + d2 * n * 0.01], n * 0.032, 0.4))
    th0 = pc + np.array([-n * 0.15, -n * 0.02])
    thumb = cv.poly(ribbon(spline([th0, th0 + np.array([-n * 0.10, n * 0.08]), th0 + np.array([-n * 0.08, n * 0.20])], 6),
                           lambda u: n * 0.075 * (1 - u * 0.4) + 0.4))
    parts.append(thumb)
    fingers.append(thumb)
    claws.append(stroke(cv, [th0 + np.array([-n * 0.08, n * 0.19]), th0 + np.array([-n * 0.05, n * 0.26]), th0 + np.array([-n * 0.01, n * 0.29])],
                        n * 0.03, 0.4))
    hand = union(cv, parts)
    glow(cv, hand, tone("blood")[1], 10, 0.7)
    ink_line(cv, hand, "#120103", 0.4, 2.4, 0.3)
    paint_form(cv, hand, DARK_BLOOD, R=n * 0.03, grad=0.6, thr=[0.24, 0.55, 0.86])
    for f in fingers:
        cv.paint(np.clip(f - toward(f, 1.6, LIGHT), 0, 1) * hand, "#0E0103", 0.7)
    cv.add(np.clip(hand - toward(hand, 1.8, LIGHT), 0, 1), tone(el)[2], 0.8)   # hot rim from the target below
    for pts in (((0.40, 0.04), (0.46, 0.18), (0.44, 0.30)), ((0.58, 0.10), (0.56, 0.24), (0.62, 0.36)), ((0.50, 0.30), (0.42, 0.40), (0.36, 0.52))):
        vm = stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.016, n * 0.006) * hand
        cv.add(blur(vm, 1.2), tone("blood")[1], 0.9)
        cv.add(vm, tone("blood")[3], 0.6)
    for cm in claws:
        material(cv, cm, "bone", R=n * 0.008, lw=(0.2, 0.9))
    droplets(cv, rng, tgt, 7, n * 0.08, n * 0.20, (190, 350), n * 0.018)
    hot_core(cv, tgt[0], tgt[1], el, 2.2, 1.1, star_len=16)


@skill("berserker.enrage", tone="rage")
def enrage(cv, rng, el):
    """the berserker's horned helm, eye slit burning, rage flames roaring up behind it"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    for x, h, w, l in ((0.22, 0.70, 0.34, -0.2), (0.78, 0.66, 0.34, 0.2), (0.50, 0.96, 0.56, 0.0)):
        flame(cv, (n * x, n * 1.0), n * h, n * w, "rage" if x != 0.5 else "blood", rng, lean=l, tongues=5, k=0.85, value=0.9)
    X, Y = cv.grid()
    horns = []
    for s in (-1, 1):   # thick bone horns sweeping out and up from the temples
        cx = n * 0.50
        pts = [(cx + s * n * 0.17, n * 0.44), (cx + s * n * 0.32, n * 0.38), (cx + s * n * 0.40, n * 0.24), (cx + s * n * 0.36, n * 0.08)]
        horns.append(cv.poly(ribbon(spline(pts, 8), lambda u: n * 0.10 * (1 - u) ** 0.9 + 0.5)))
    hm = union(cv, horns)
    material(cv, hm, "bone", R=n * 0.03, lw=(0.35, 2.0), back=tone(el)[1], back_k=0.8)
    rings = (0.5 + 0.5 * np.sin(Y / n * 70.0)) ** 6
    cv.paint(hm * rings * (Y > n * 0.20), "#5A3E22", 0.5)
    dome = cv.poly(closed_spline([(n * 0.50, n * 0.22), (n * 0.68, n * 0.30), (n * 0.72, n * 0.50), (n * 0.68, n * 0.74), (n * 0.58, n * 0.90),
                                  (n * 0.50, n * 0.92), (n * 0.42, n * 0.90), (n * 0.32, n * 0.74), (n * 0.28, n * 0.50), (n * 0.32, n * 0.30)], 6))
    material(cv, dome, "darksteel", R=n * 0.09, lw=(0.4, 2.4), grad=0.5, back=tone(el)[1], back_k=0.9)
    brow = cv.poly(ribbon(spline([(n * 0.29, n * 0.50), (n * 0.50, n * 0.46), (n * 0.71, n * 0.50)], 6), [n * 0.05] * 3)) * dome
    material(cv, brow, "bronze", R=n * 0.015, lw=(0.25, 1.2))
    crest = cv.poly(ribbon([(n * 0.50, n * 0.23), (n * 0.50, n * 0.46)], [n * 0.03, n * 0.05])) * dome
    material(cv, crest, "bronze", R=n * 0.012, lw=(0.25, 1.1))
    slit = cv.poly(closed_spline([(n * 0.33, n * 0.555), (n * 0.50, n * 0.575), (n * 0.67, n * 0.555), (n * 0.50, n * 0.605)], 4))
    cv.paint(dilate(slit, 1.5) * dome, "#050203")
    for x in (0.41, 0.59):   # burning eyes
        e = cv.ellipse(n * x, n * 0.578, n * 0.035, n * 0.014)
        glow(cv, e, tone(el)[1], 4, 1.0)
        cv.add(e, tone(el)[3], 1.0)
        light_streak(cv, (n * x, n * 0.578), (n * (x + (0.16 if x > 0.5 else -0.16)), n * 0.55), n * 0.016, el, 0.8)
    for x in (0.38, 0.44, 0.50, 0.56, 0.62):   # breathing holes on the faceplate
        h = cv.ellipse(n * x, n * 0.76 + abs(x - 0.5) * n * 0.1, n * 0.009)
        cv.paint(h * dome, "#050203", 0.9)
    hot_core(cv, n * 0.59, n * 0.578, el, 1.6, 0.9, star_len=14)


@skill("berserker.crimson_storm", tone="blood")
def crimson_storm(cv, rng, el):
    """three nested blood waves bursting out around one point, crests breaking into drops"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.60])
    ground(cv, el, [(cv.ellipse(c[0], c[1], n * 0.46, n * 0.20), 1)], focus=c, focus_r=0.5, focus_k=0.8, ink="#060202", wash=-20, rng=rng)
    u, v = np.array([1.0, 0.0]), np.array([0.0, 1.0])
    for r, w, k, ty in ((0.44, 0.075, 0.8, -0.06), (0.30, 0.060, 0.95, -0.03), (0.17, 0.045, 1.1, 0.0)):
        # each wave: a dark blood wall rising from the ring, its crest lit
        cc = c + np.array([0, n * ty])
        X, Y = cv.grid()
        dx, dy = (X - cc[0]) / (n * r), (Y - cc[1]) / (n * r * 0.36)
        rho = np.sqrt(dx * dx + dy * dy)
        wall = smoothstep(1.0 + w * 3.0, 1.0, rho) * smoothstep(1.0 - w * 4.5, 1.0 - w * 1.2, rho)
        wall = wall * smoothstep(n * 0.02, -n * r * 0.6, Y - cc[1] - n * r * 0.36 * 1.0) + wall * (Y > cc[1]) * 0.6
        wall = np.clip(wall, 0, 1).astype(np.float32)
        paint_form(cv, wall, DARK_BLOOD, R=n * 0.02, grad=0.6, alpha=0.95)
        shock_ring(cv, cc, u, v, n * r, n * r * 0.36, n * w * 0.6, el, k)
    for a in np.linspace(-170, -10, 9):   # crest spray
        ar = math.radians(a)
        p = c + np.array([math.cos(ar) * n * 0.44, math.sin(ar) * n * 0.16 - n * 0.08])
        droplet(cv, p[0], p[1], n * rng.uniform(0.014, 0.024), a, BLOOD, "#1A0104")
    flare_spikes(cv, c[0], c[1] - n * 0.06, [(-90, 1.0), (-60, 0.6), (-120, 0.6), (-30, 0.35), (-150, 0.35)], n * 0.04, n * 0.48, n * 0.03, el, 0.9)
    hot_core(cv, c[0], c[1] - n * 0.04, el, 3.0, 1.2, star_len=24)

    def bleed(c2):
        # the bar's one off-key accent: a violet rim along the outermost wave's far side
        t = np.linspace(math.radians(190), math.radians(350), 64)
        pts = np.c_[c[0] + np.cos(t) * n * 0.44, c[1] - n * 0.06 + np.sin(t) * n * 0.16]
        m = c2.poly(ribbon(pts, lambda q: n * 0.012 * math.sin(math.pi * q) + 0.3))
        c2.add(blur(m, 1.2), KEY["cool"], 0.9)
    return {"bleed": bleed}
