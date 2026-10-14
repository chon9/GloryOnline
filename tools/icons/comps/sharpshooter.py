"""神枪手 Sharpshooter (唐昊 style gunslinger, dual revolvers). Warm-keyed bar: muzzle gold, crimson and dust tan on a
near-black brown ground, brass metal and a crimson-lacquer grip. The bar's one off-key accent is ice-cyan, on the
ultimate's piercing round.

Value plan:
  shot_1           the revolver on a rising diagonal, flash and one round leaving the top right         [revolver]
  knee_attack      a bent leg driving its armoured knee straight up into a burst: an arch, streaks up
  slide_kick       a straight leg sliding in low along the floor, sole first, a long dust wake: low band
  punisher         a boot stamping down from the top into a ground ring, revolver firing into it       [revolver]
  random_firing    two crossed revolvers low left, three fanned volleys of tracers: a wide wedge        [revolvers]
  roundhouse_kick  a wide flat elliptical sweep of the kick, the boot at its head: a big ellipse ring
  dual_load        the cylinder swung out end-on, six chambers, a round sliding in: one dense disc     [cylinder]
  barrett_snipe    a long anti-materiel rifle on a bipod, a round piercing a line of shock rings: long beam
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_gunfight import boot, boot_H, bullet, leg, muzzle_flash, revolver

CHAPS = ["#1E100C", "#4E2C20", "#86543A", "#BC8A62"]   # worn tan leather trousers: a lit mass on the dark ground


def _u(a, b):
    d = np.asarray(b, float) - np.asarray(a, float)
    return d / (np.linalg.norm(d) + 1e-9)


@skill("sharpshooter.shot_1", tone="muzzle")
def shot(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.95), (n * 0.95, 0), (n, 0), (n, n * 0.35), (n * 0.35, n)])
    ground(cv, el, [(band, 1)], focus=(n * 0.80, n * 0.22), focus_r=0.5, focus_k=0.7, wash=-38, rng=rng)
    H = weapon_H((n * 0.14, n * 0.78), (n * 0.66, n * 0.36), 1.35)
    mz = xf(H, [(1.02, -0.03)])[0]
    d = _u((n * 0.12, n * 0.80), (n * 0.66, n * 0.36))
    smoke(cv, rng, [mz + d * n * 0.02 + np.array([0, -n * 0.02]), mz + np.array([-n * 0.04, -n * 0.10]), mz + np.array([-n * 0.12, -n * 0.16])],
          n * 0.04, "#4A3A2E", 0.5)
    trail(cv, [mz + d * n * 0.06, mz + d * n * 0.30], 0.5, n * 0.028, el, 0.9)
    revolver(cv, H, el, flash=1.0)
    bullet(cv, weapon_H(mz + d * n * 0.27, mz + d * n * 0.37, 1.0), el)
    hot_core(cv, mz[0] + d[0] * n * 0.02, mz[1] + d[1] * n * 0.02, el, 2.4, 1.0, star_len=18, ang=math.degrees(math.atan2(d[1], d[0])))


@skill("sharpshooter.knee_attack", tone="crimson")
def knee_attack(cv, rng, el):
    """side view: the thigh drives up and forward, the shin hangs straight down under it, and the armoured knee
    erupts into a launching burst; streaks rise from the hit"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.62, n * 0.30), focus_r=0.5, focus_k=0.8, wash=-90, rng=rng)
    knee = np.array([n * 0.58, n * 0.42])
    hit = knee + np.array([n * 0.06, -n * 0.10])
    for a in (-120, -105, -90, -75, -60):
        ar = math.radians(a + rng.uniform(-4, 4))
        d = np.array([math.cos(ar), math.sin(ar)])
        light_streak(cv, hit + d * n * 0.10, hit + d * n * rng.uniform(0.30, 0.42), n * 0.02, el, 0.8)
    hip, ankle = np.array([n * -0.12, n * 0.78]), np.array([n * 0.50, n * 0.72])
    boot(cv, boot_H(ankle, knee, (0.62, 0.78), n * 0.23), el)
    leg(cv, [knee + np.array([n * 0.0, n * 0.02]), (knee + ankle) / 2, ankle], [n * 0.20, n * 0.18, n * 0.15], CHAPS, el,
        rim=tone(el)[2], folds=((0.35, 0.5),))
    leg(cv, [hip, (hip + knee) / 2 + np.array([0, n * 0.03]), knee], [n * 0.30, n * 0.27, n * 0.23], CHAPS, el,
        rim=tone(el)[2], folds=((0.55, 0.8),))
    kc = knee + np.array([n * 0.04, -n * 0.02])
    pad = cv.poly(closed_spline([kc + np.array([-n * 0.04, n * 0.06]), kc + np.array([-n * 0.04, -n * 0.05]),
                                 kc + np.array([n * 0.03, -n * 0.075]), kc + np.array([n * 0.085, -n * 0.01]),
                                 kc + np.array([n * 0.05, n * 0.07])], 6))
    material(cv, pad, "plate", R=n * 0.04, lw=(0.4, 2.0), back=tone(el)[2], back_k=0.9)
    cv.paint(stroke(cv, [kc + np.array([-n * 0.04, -n * 0.04]), kc + np.array([n * 0.03, -n * 0.06]), kc + np.array([n * 0.08, 0])],
                    n * 0.012, n * 0.012) * pad, KEY["metal"], 0.9)
    shock_ring(cv, hit + np.array([0, -n * 0.02]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.20, n * 0.06, n * 0.025, el, 0.9, 180, 360)
    shock_ring(cv, hit + np.array([0, -n * 0.10]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.13, n * 0.04, n * 0.018, el, 0.7, 180, 360)
    flare_spikes(cv, hit[0], hit[1], [(-90, 1.0), (-130, 0.6), (-50, 0.6), (180, 0.4), (0, 0.4)], n * 0.03, n * 0.24, n * 0.035, el, 0.9)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1, star_len=20)


@skill("sharpshooter.slide_kick", tone="dust")
def slide_kick(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.78, n * 0.62), focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    speed_lines(cv, rng, 0, 9, el, 0.5, band=(0.15, 0.62))
    smoke(cv, rng, [(n * -0.05, n * 0.82), (n * 0.15, n * 0.78), (n * 0.35, n * 0.74), (n * 0.55, n * 0.76)], n * 0.12, "#8A6C50", 0.85)
    for i in range(6):
        stone_chip(cv, rng, n * rng.uniform(0.80, 0.98), n * rng.uniform(0.50, 0.80), n * rng.uniform(0.025, 0.045),
                   rng.uniform(0, 360), el, hot_dir=(-1, 0.2), trail=(1.0, -0.3))
    hip, knee, ankle = np.array([n * -0.10, n * 0.62]), np.array([n * 0.30, n * 0.64]), np.array([n * 0.64, n * 0.66])
    leg(cv, [hip, knee, ankle], [n * 0.26, n * 0.22, n * 0.17], CHAPS, el, rim=tone(el)[2], folds=((0.5, 0.7),))
    boot(cv, boot_H(ankle, knee, (0.1, -1.0), n * 0.28), el)
    sole = np.array([n * 0.76, n * 0.62])
    for a in (-30, 0, 30):
        ar = math.radians(a)
        light_streak(cv, sole + np.array([math.cos(ar), math.sin(ar)]) * n * 0.08, sole + np.array([math.cos(ar), math.sin(ar)]) * n * 0.22,
                     n * 0.02, el, 0.8)
    hot_core(cv, sole[0] + n * 0.04, sole[1], el, 2.4, 1.0, star_len=16)


@skill("sharpshooter.punisher", tone="crimson")
def punisher(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.66), (n, n * 0.62), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.46, n * 0.80), focus_r=0.5, focus_k=0.8, wash=-90, rng=rng)
    gc = np.array([n * 0.46, n * 0.82])
    shock_ring(cv, gc, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.36, n * 0.09, n * 0.035, el, 0.9)
    for a in (-160, -120, -30, 10, 170):
        ar = math.radians(a)
        p1 = gc + np.array([math.cos(ar) * n * 0.34, math.sin(ar) * n * 0.085])
        crack = cv.poly(ribbon(spline([gc, (gc + p1) / 2 + np.array([0, n * 0.012]), p1], 4), [n * 0.012, n * 0.008, 0.4]))
        soft_light(cv, crack, el, 0.7, R=0.8, glow_r=3)
    ankle = np.array([n * 0.36, n * 0.52])
    leg(cv, [(n * 0.26, n * -0.10), (n * 0.30, n * 0.20), ankle], [n * 0.26, n * 0.23, n * 0.18], CHAPS, el,
        rim=tone(el)[2], folds=((0.6, 0.7),))
    boot(cv, boot_H(ankle, (n * 0.30, n * 0.20), (1.0, 0.25), n * 0.30), el)
    H = weapon_H((n * 1.0, n * 0.08), (n * 0.64, n * 0.62), 1.3)
    revolver(cv, H, el)
    mz = xf(H, [(1.02, -0.03)])[0]
    d = _u((n * 1.02, n * 0.14), (n * 0.66, n * 0.66))
    muzzle_flash(cv, mz, math.degrees(math.atan2(d[1], d[0])), n * 0.18, el, 1.0)
    for p in ((0.58, 0.84), (0.30, 0.86), (0.66, 0.78)):
        sparks(cv, rng, (n * p[0], n * p[1]), 4, n * 0.07, el, 0.8, a_range=(200, 340))
    hot_core(cv, n * 0.56, n * 0.80, el, 2.6, 1.0, star_len=18)


@skill("sharpshooter.random_firing", tone="muzzle")
def random_firing(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.70, n * 0.40), focus_r=0.6, focus_k=0.6, wash=-20, rng=rng)
    c = np.array([n * 0.24, n * 0.72])
    for v, (a0, a1) in enumerate(((-62, -42), (-34, -14), (-6, 14))):   # three fanned volleys
        for i in range(6):
            a = math.radians(rng.uniform(a0, a1))
            d = np.array([math.cos(a), math.sin(a)])
            r0 = n * rng.uniform(0.28, 0.55)
            L = n * rng.uniform(0.12, 0.22)
            light_streak(cv, c + d * r0, c + d * (r0 + L), n * rng.uniform(0.012, 0.02), el, 0.9 if v == 1 else 0.75)
            if i % 3 == 0:
                hot_core(cv, *(c + d * (r0 + L)), el, 0.8, 0.5, star=False)
    for i in range(5):   # spent casings
        p = np.array([n * rng.uniform(0.06, 0.40), n * rng.uniform(0.36, 0.56)])
        bullet(cv, H_affine(p, rng.uniform(0, 180), n * 0.07, n * 0.07), el, 0.6, tip="brass")
    H1 = weapon_H((n * 0.02, n * 0.98), (n * 0.46, n * 0.50), 0.95)
    H2 = weapon_H((n * 0.02, n * 0.70), (n * 0.56, n * 0.74), 0.95)
    revolver(cv, H2, el, flash=0.9)
    revolver(cv, H1, el, flash=1.0)
    m1 = xf(H1, [(1.02, -0.03)])[0]
    hot_core(cv, m1[0], m1[1], el, 2.4, 1.0, star_len=18)


@skill("sharpshooter.roundhouse_kick", tone="dust")
def roundhouse(cv, rng, el):
    """a wide flat elliptical sweep around the frame; the leg reaches in from the right at mid height, the boot
    (instep leading) at the head of the sweep on the left, enemies' debris knocked outward"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    disc = cv.ellipse(c[0], c[1] + n * 0.26, n * 0.48, n * 0.12)
    ground(cv, el, [(disc, 1)], focus=(n * 0.24, n * 0.52), focus_r=0.55, focus_k=0.7, wash=-8, rng=rng)
    shock_ring(cv, c + np.array([0, n * 0.28]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.44, n * 0.09, n * 0.014, el, 0.4)
    crescent(cv, c + np.array([0, n * 0.06]), n * 0.46, n * 0.30, 0, 10, 172, 0.45, el, 1.0)
    crescent(cv, c + np.array([0, n * 0.06]), n * 0.46, n * 0.30, 0, -50, 10, 0.18, el, 0.45, rim=False)
    ankle = np.array([n * 0.30, n * 0.50])
    knee = np.array([n * 0.64, n * 0.36])
    leg(cv, [(n * 1.12, n * 0.16), knee, ankle], [n * 0.32, n * 0.26, n * 0.19], CHAPS, el, rim=tone(el)[2],
        folds=((0.45, 0.6),))
    boot(cv, boot_H(ankle, knee, (-0.35, 1.0), n * 0.31), el)
    for x, y, s, a in ((0.06, 0.32, 0.05, 200), (0.08, 0.64, 0.04, 160), (0.20, 0.20, 0.035, 230), (0.16, 0.80, 0.03, 140)):
        ar = math.radians(a)
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-math.cos(ar), -math.sin(ar)),
                   trail=(math.cos(ar), math.sin(ar)))
    hot_core(cv, n * 0.07, n * 0.60, el, 2.6, 1.1, star_len=18)


@skill("sharpshooter.dual_load", tone="muzzle")
def dual_load(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.46, n * 0.54])
    ground(cv, el, [], focus=c, focus_r=0.55, focus_k=0.8, wash=-60, rng=rng)
    # reload loop: a crescent of light chasing round the cylinder
    crescent(cv, c, n * 0.40, n * 0.40, 0, 120, 400, 0.18, el, 0.8)
    t = np.linspace(0, 2 * math.pi, 7)[:-1]
    R = n * 0.25
    cyl_pts = []
    for i in range(12):   # fluted outline: six lobes
        a = i * math.pi / 6 + math.pi / 6
        r = R * (1.0 if i % 2 == 0 else 0.90)
        cyl_pts.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
    cyl = cv.poly(closed_spline(cyl_pts, 6))
    material(cv, cyl, "gf_blued", R=n * 0.06, lw=(0.45, 2.4), back=tone(el)[2], back_k=0.9)
    cv.paint(np.clip(cyl - cv.ellipse(c[0], c[1], R * 0.93), 0, 1), KEY["metal"], 0.5)
    for i, a in enumerate(t + math.pi / 6):
        p = c + np.array([math.cos(a), math.sin(a)]) * R * 0.58
        ch = cv.ellipse(p[0], p[1], R * 0.27)
        cv.paint(ch, "#050304")
        if i == 4:   # the empty chamber, lit from inside
            cv.add(blur(ch, 2.0) * ch, tone(el)[1], 0.8)
            continue
        hd = cv.ellipse(p[0], p[1], R * 0.24)
        material(cv, hd, "brass", R=R * 0.08, lw=(0.3, 1.2))
        pr = cv.ellipse(p[0] + R * 0.01, p[1] + R * 0.01, R * 0.08)
        material(cv, pr, "gf_copper", R=R * 0.04, lw=(0.2, 0.8))
    hub = cv.ellipse(c[0], c[1], R * 0.14)
    material(cv, hub, "steel", R=R * 0.06, lw=(0.3, 1.2))
    # the round sliding into the empty chamber from the upper right
    a = t[4] + math.pi / 6
    p = c + np.array([math.cos(a), math.sin(a)]) * R * 0.58
    tip = p + np.array([n * 0.17, -n * 0.15])
    trail(cv, [tip + np.array([n * 0.30, -n * 0.26]), tip + np.array([n * 0.20, -n * 0.17])], 0.4, n * 0.03, el, 0.7)
    bullet(cv, weapon_H(tip + _u(p, tip) * n * 0.28, tip, 1.0), el)
    hot_core(cv, p[0] + n * 0.06, p[1] - n * 0.06, el, 2.2, 1.0, star_len=16)


@skill("sharpshooter.barrett_snipe", tone="crimson")
def barrett(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.40), (n, n * 0.36), (n, n * 0.62), (0, n * 0.66)])
    ground(cv, el, [(band, 1)], focus=(n * 0.88, n * 0.48), focus_r=0.45, focus_k=0.6, ink="#060403", wash=0, rng=rng)
    y = n * 0.48
    beam = cv.poly([(n * 0.62, y - n * 0.020), (n * 1.05, y - n * 0.045), (n * 1.05, y + n * 0.045), (n * 0.62, y + n * 0.020)])
    soft_light(cv, beam, el, 1.2, R=n * 0.03, glow_r=7, core_k=1.4)
    for x, s in ((0.72, 0.9), (0.84, 1.1), (0.96, 1.3)):
        shock_ring(cv, np.array([n * x, y]), np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * 0.13 * s, n * 0.035 * s, n * 0.02, el, 0.8)
    H = weapon_H((n * -0.10, n * 0.58), (n * 0.64, y + n * 0.004), 1.7)
    # bipod legs under the handguard
    for dx in (-0.04, 0.03):
        lg = stroke(cv, [xf(H, [(0.66, 0.02)])[0], (n * (0.46 + dx * 1.5), n * 0.86)], n * 0.026, n * 0.016)
        material(cv, lg, "darksteel", R=n * 0.008, lw=(0.25, 1.1))
    _barrett(cv, H, el)

    def bleed(c2):
        rim = np.clip(beam - toward(beam, 1.5, LIGHT), 0, 1)
        c2.add(rim, KEY["cool"], 0.9)   # the bar's one off-key accent: an ice-cyan rim on the piercing round
        hot_core(c2, n * 0.64, y, el, 2.8, 1.0, star_len=24)
    return {"bleed": bleed}


def _barrett(cv, H, el):
    """anti-materiel rifle side view: skeletal stock, long receiver, big scope, fluted barrel, double-port brake"""
    pal = tone(el)
    from painter.weapons import _axis_ang
    ang = _axis_ang(H)
    parts = []
    stock = lpoly(cv, H, [(0.0, -0.05), (0.22, -0.045), (0.24, 0.05), (0.16, 0.06), (0.04, 0.10), (0.0, 0.09)])
    hole = lpoly(cv, H, [(0.05, -0.015), (0.17, -0.015), (0.17, 0.035), (0.08, 0.06)])
    solid(cv, H, np.clip(stock - hole, 0, 1), "gf_blued", 0.03, lw=(0.35, 1.8), back=pal[2], back_k=0.5)
    grip = lpoly(cv, H, [(0.27, 0.03), (0.32, 0.03), (0.30, 0.13), (0.25, 0.13)])
    mag = lpoly(cv, H, [(0.36, 0.03), (0.44, 0.03), (0.44, 0.12), (0.36, 0.12)])
    recv = lpoly(cv, H, [(0.20, -0.055), (0.58, -0.055), (0.58, 0.035), (0.20, 0.035)])
    barrel = lpoly(cv, H, [(0.58, -0.022), (0.94, -0.018), (0.94, 0.012), (0.58, 0.016)])
    brake = lpoly(cv, H, spline([(0.92, -0.045), (1.0, -0.045), (1.0, 0.035), (0.92, 0.035)], 2))
    for m, mat in ((grip, "leather"), (mag, "gf_blued"), (barrel, "darksteel"), (recv, "plate"), (brake, "steel")):
        solid(cv, H, m, mat, 0.022, lw=(0.35, 1.7), streak_ang=ang, back=pal[2], back_k=0.5)
        parts.append(m)
    for x in (0.945, 0.975):
        cv.paint(lpoly(cv, H, [(x, -0.04), (x + 0.012, -0.04), (x + 0.012, 0.03), (x, 0.03)]) * brake, "#0A0608", 0.85)
    for x in np.linspace(0.62, 0.90, 7):   # barrel flutes
        cv.paint(lrib(cv, H, [(x, -0.004), (x + 0.03, -0.004)], 0.006) * barrel, "#000000", 0.5)
    cv.paint(lrib(cv, H, [(0.24, 0.0), (0.56, 0.0)], 0.012) * recv, KEY["accent"], 0.8)
    for xa in (0.30, 0.46):
        solid(cv, H, lpoly(cv, H, [(xa, -0.10), (xa + 0.035, -0.10), (xa + 0.035, -0.05), (xa, -0.05)]), "darksteel", 0.01, lw=(0.2, 0.8))
    scope = lpoly(cv, H, spline([(0.24, -0.15), (0.29, -0.125), (0.48, -0.125), (0.54, -0.155), (0.54, -0.08), (0.48, -0.095),
                                 (0.29, -0.095), (0.24, -0.08)], 3))
    solid(cv, H, scope, "darksteel", 0.03, lw=(0.3, 1.4), streak_ang=ang, back=pal[2], back_k=0.6)
    lens = cv.ellipse(*xf(H, [(0.54, -0.117)])[0], lR(H, 0.02))
    cv.paint(lens, pal[2])
    cv.add(blur(lens, 1.5), pal[1], 0.7)
    return union(cv, parts + [stock, scope])
