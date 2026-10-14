"""弹药专家 Spitfire (automatic pistol + a bandolier of grenades). Warm-keyed bar: blast orange, olive drab and spark
yellow on an olive-black ground, brass metal. The bar's one off-key accent is ice-cyan, on 冰弹 (the round's element
demands it); the ultimate stays inside the key.

Value plan:
  burst_1          the pistol side-on mid frame, two rounds in tandem streaking right: a horizontal bar   [pistol]
  floating_bullet  the pistol low, one round rising straight up through stacked pressure rings: a column [pistol]
  grenade          an impact grenade on a high arc from the upper left, bursting low right: arc into blast
  stun_bullet      one fat slow round dead centre inside concentric drag ripples and a ring of stun sparks
  ice_bullet       a frost-sheathed round diving down a diagonal into an ice-crystal bloom (ice-cyan)
  burst_grenade    a vented sphere at the centre splitting open, a huge radial blast ring flinging debris
  timed_grenade    a squat timer grenade sitting on burning ground, its dial ticking, fuse sparks: low mass
  chaotic_thunder  a scatter of grenades tumbling across the sky above a field of five blossoming bursts
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_gunfight import auto_pistol, bullet, grenade, muzzle_flash


def _u(a, b):
    d = np.asarray(b, float) - np.asarray(a, float)
    return d / (np.linalg.norm(d) + 1e-9)


@skill("spitfire.burst_1", tone="spark")
def burst_1(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.40), (n, n * 0.20), (n, n * 0.52), (0, n * 0.80)])
    ground(cv, el, [(band, 1)], focus=(n * 0.62, n * 0.42), focus_r=0.55, focus_k=0.8, wash=-12, rng=rng)
    H = weapon_H((n * 0.02, n * 0.66), (n * 0.56, n * 0.52), 1.45)
    mz = xf(H, [(1.05, -0.068)])[0]
    d = _u(xf(H, [(0.0, -0.068)])[0], mz)
    for t0, t1, k in ((0.08, 0.20, 0.7), (0.28, 0.44, 0.9)):
        trail(cv, [mz + d * n * t0, mz + d * n * t1], 0.4, n * 0.024, el, k)
    for t in (0.24, 0.50):
        bullet(cv, weapon_H(mz + d * n * (t - 0.10), mz + d * n * t, 1.0), el)
    cp = xf(H, [(0.57, -0.14)])[0] + np.array([n * 0.04, -n * 0.18])   # the ejected casing flipping up out of the port
    bullet(cv, H_affine(cp, -70, n * 0.08, n * 0.08), el, 0.7, tip="brass")
    smoke(cv, rng, [mz + np.array([-n * 0.02, -n * 0.04]), mz + np.array([-n * 0.06, -n * 0.12]), mz + np.array([-n * 0.04, -n * 0.22])],
          n * 0.035, "#46462E", 0.5)
    auto_pistol(cv, H, el, flash=1.2)
    hot_core(cv, mz[0] + n * 0.02, mz[1], el, 2.6, 1.1, star_len=18)


@skill("spitfire.floating_bullet", tone="blast")
def floating_bullet(cv, rng, el):
    n = cv.n
    col_m = cv.poly([(n * 0.32, 0), (n * 0.68, 0), (n * 0.62, n), (n * 0.38, n)])
    ground(cv, el, [(col_m, 1)], focus=(n * 0.50, n * 0.18), focus_r=0.45, focus_k=0.8, wash=-90, rng=rng)
    x = n * 0.52
    for y, s in ((0.66, 0.8), (0.46, 1.0), (0.26, 1.2)):
        shock_ring(cv, np.array([x, n * y]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.16 * s, n * 0.045 * s, n * 0.022, el, 0.8)
    trail(cv, [(x, n * 0.80), (x, n * 0.40), (x, n * 0.24)], 0.5, n * 0.05, el, 1.0)
    for dx in (-0.16, 0.18):
        light_streak(cv, (x + n * dx, n * 0.70), (x + n * dx * 1.2, n * 0.10), n * 0.015, el, 0.6)
    bullet(cv, weapon_H((x, n * 0.30), (x, n * 0.08), 1.2), el)
    smoke(cv, rng, [(n * 0.30, n * 0.96), (n * 0.40, n * 0.88), (n * 0.50, n * 0.84)], n * 0.06, "#46462E", 0.7)
    H = weapon_H((n * 0.30, n * 1.10), (n * 0.52, n * 0.80), 1.15)
    auto_pistol(cv, H, el, flash=0.0)
    mz = xf(H, [(1.05, -0.068)])[0]
    muzzle_flash(cv, mz, -90, n * 0.16, el, 0.9)
    hot_core(cv, x, n * 0.07, el, 2.4, 1.0, star_len=16)


@skill("spitfire.grenade", tone="blast")
def grenade_toss(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.82), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.72, n * 0.72), focus_r=0.5, focus_k=0.8, wash=-20, rng=rng)
    hit = np.array([n * 0.72, n * 0.72])
    arc = [(n * -0.04, n * 0.30), (n * 0.16, n * 0.12), (n * 0.38, n * 0.14), (n * 0.56, n * 0.38), (n * 0.68, n * 0.62)]
    sp = spline(arc, 10)
    for i in range(2, len(sp) - 6, 4):   # dashed motion trail of the toss
        seg = cv.poly(ribbon(sp[i:i + 3], [n * 0.008, n * 0.014, n * 0.008]))
        soft_light(cv, seg, "olive", 0.6, R=0.6, glow_r=2)
    shock_ring(cv, hit + np.array([0, n * 0.06]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.30, n * 0.08, n * 0.03, el, 0.9)
    burst(cv, rng, hit, n * 0.17, el, 1.0, smoke_k=0.8, puffs=9)
    for a in (-160, -130, -40, -10, 200):
        ar = math.radians(a)
        p = hit + np.array([math.cos(ar), math.sin(ar)]) * n * rng.uniform(0.26, 0.36)
        stone_chip(cv, rng, p[0], p[1], n * 0.035, rng.uniform(0, 360), el, hot_dir=(-math.cos(ar), -math.sin(ar)),
                   trail=(math.cos(ar), math.sin(ar)))
    g = sp[int(len(sp) * 0.45)]
    grenade(cv, g, n * 0.10, 35, el, kind="impact", pin=False)


@skill("spitfire.stun_bullet", tone="spark")
def stun_bullet(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    for r, k in ((0.44, 0.45), (0.34, 0.6), (0.25, 0.8)):   # slow drag ripples ahead of the round
        shock_ring(cv, c + np.array([n * (0.44 - r) * 0.6, 0]), np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * r, n * r * 0.40, n * 0.02, el, k, 200, 340)
    smoke(cv, rng, [(n * -0.05, n * 0.52), (n * 0.10, n * 0.50), (n * 0.22, n * 0.50)], n * 0.05, "#46462E", 0.5)
    trail(cv, [(n * 0.0, c[1]), (n * 0.30, c[1])], 0.4, n * 0.06, "olive", 0.7)
    bullet(cv, weapon_H(c - np.array([n * 0.24, 0]), c + np.array([n * 0.20, 0]), 1.35), el)
    # electric stun crackle: short jagged arcs round the nose
    for i in range(7):
        a = math.radians(-90 + i * 52 + rng.uniform(-10, 10))
        p0 = c + np.array([n * 0.16, 0]) + np.array([math.cos(a), math.sin(a)]) * n * 0.12
        pts = [p0]
        for j in range(3):
            pts.append(pts[-1] + np.array([math.cos(a), math.sin(a)]) * n * 0.05 + rng.uniform(-1, 1, 2) * n * 0.025)
        bolt = cv.poly(ribbon(np.array(pts), [n * 0.012, n * 0.010, n * 0.008, n * 0.003]))
        soft_light(cv, bolt, el, 0.9, R=0.6, glow_r=2.5)
    hot_core(cv, c[0] + n * 0.21, c[1], el, 2.6, 1.1, star_len=18)


@skill("spitfire.ice_bullet", tone="olive")
def ice_bullet(cv, rng, el):
    n = cv.n
    ICE = KEY["cool"]
    ground(cv, el, [], focus=(n * 0.66, n * 0.68), focus_r=0.5, focus_k=0.4, ink="#060806", wash=40, rng=rng)
    hit = np.array([n * 0.68, n * 0.70])
    X, Y = cv.grid()
    cv.add(np.exp(-((X - hit[0]) ** 2 + (Y - hit[1]) ** 2) / (n * 0.22) ** 2), "#2C6A90", 0.6)
    # frost bloom: angular glass shards fanning out of the impact
    for a, L in ((-150, 0.30), (-120, 0.22), (-80, 0.30), (-45, 0.24), (-10, 0.30), (20, 0.18), (60, 0.20), (110, 0.22), (160, 0.18)):
        ar = math.radians(a + rng.uniform(-6, 6))
        d = np.array([math.cos(ar), math.sin(ar)])
        nv = np.array([-d[1], d[0]])
        Lr = n * L
        w = n * 0.045
        sh = cv.poly([hit + nv * w * 0.6, hit + d * Lr * 0.55 + nv * w, hit + d * Lr, hit + d * Lr * 0.55 - nv * w * 0.7, hit - nv * w * 0.6])
        glow(cv, sh, ICE, 4, 0.35)
        material(cv, sh, "glass", R=n * 0.02, lw=(0.25, 1.4), brk=0.3)
        cv.paint(np.clip(sh - toward(sh, 1.0, LIGHT), 0, 1), "#FFFFFF", 0.5)
    d = _u((n * 0.10, n * 0.10), hit)
    trail(cv, [hit - d * n * 0.62, hit - d * n * 0.30], 0.4, n * 0.035, "olive", 0.7)
    for i in range(8):   # frost flakes shed along the path
        p = hit - d * n * rng.uniform(0.25, 0.65) + np.array([-d[1], d[0]]) * n * rng.uniform(-0.08, 0.08)
        hot_core_cross(cv, p[0], p[1], n * rng.uniform(0.015, 0.03), ICE, 0.8)
    H = weapon_H(hit - d * n * 0.40, hit - d * n * 0.06, 1.2)
    bullet(cv, H, el)
    for x, y, L, a_ in ((0.30, -0.20, 0.16, -100), (0.42, 0.20, 0.14, 95), (0.62, -0.18, 0.18, -70), (0.70, 0.17, 0.12, 80),
                        (0.84, -0.10, 0.12, -45), (0.50, -0.20, 0.10, -120)):
        p0 = xf(H, [(x, y)])[0]
        ar = math.radians(math.degrees(math.atan2(d[1], d[0])) + a_)
        dv = np.array([math.cos(ar), math.sin(ar)])
        nv = np.array([-dv[1], dv[0]])
        sh = cv.poly([p0 - nv * n * 0.016, p0 + dv * n * L * 0.6 - nv * n * 0.012, p0 + dv * n * L, p0 + nv * n * 0.016])
        glow(cv, sh, ICE, 3, 0.4)
        material(cv, sh, "glass", R=n * 0.01, lw=(0.2, 1.0), brk=0.3)
    frost = blur(dilate(lpoly(cv, H, [(0.1, -0.2), (0.95, -0.12), (0.95, 0.12), (0.1, 0.2)]), 1.5), 2.5)
    cv.add(frost * (0.4 + 0.6 * cv.noise2), ICE, 0.25)
    hot_core(cv, hit[0], hit[1], "spark", 2.4, 0.8, star_len=16)


@skill("spitfire.burst_grenade", tone="blast")
def burst_grenade(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.52])
    ground(cv, el, [], focus=c, focus_r=0.6, focus_k=0.9, ink="#060604", wash=-45, rng=rng)
    burst(cv, rng, c, n * 0.26, el, 0.8, smoke_k=0.9, puffs=10, core=False)
    shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.44, n * 0.40, n * 0.045, el, 1.0)
    for i in range(7):   # the implosion: spiral streaks sucked in toward the core before the blast
        a0 = i * 2 * math.pi / 7
        pts = [c + np.array([math.cos(a0 + t * 1.6), math.sin(a0 + t * 1.6)]) * n * (0.40 - 0.26 * t) for t in np.linspace(0, 1, 8)]
        m = cv.poly(ribbon(spline(pts, 6), lambda q: n * (0.006 + 0.022 * q)))
        soft_light(cv, m, "spark", 0.8, R=0.8, glow_r=3)
    for i in range(10):   # debris hurled outward
        a = math.radians(i * 36 + rng.uniform(-10, 10))
        d = np.array([math.cos(a), math.sin(a)])
        p = c + d * n * rng.uniform(0.36, 0.46)
        stone_chip(cv, rng, p[0], p[1], n * rng.uniform(0.025, 0.045), rng.uniform(0, 360), el, hot_dir=-d, trail=d)
    grenade(cv, c + np.array([0, n * 0.01]), n * 0.11, -15, el, kind="burst", pin=False)
    hot_core(cv, c[0] - n * 0.02, c[1] + n * 0.02, el, 2.6, 1.0, star_len=24)


@skill("spitfire.timed_grenade", tone="spark")
def timed_grenade(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.70), (n, n * 0.68), (n, n), (0, n)])
    ground(cv, el, [(floor, 2)], focus=(n * 0.46, n * 0.66), focus_r=0.55, focus_k=0.7, wash=0, rng=rng)
    c = np.array([n * 0.46, n * 0.54])
    # burning ground around the base: low licking flame tongues
    flames = []
    for i in range(7):
        x = n * (0.08 + i * 0.14) + rng.uniform(-5, 5)
        h = n * rng.uniform(0.16, 0.26) * (1.25 - 1.2 * abs(x - c[0]) / n)
        b = n * 0.86
        sw = rng.uniform(-1, 1) * n * 0.05
        flames.append(cv.poly(ribbon(spline([(x, b), (x + sw * 0.4, b - h * 0.45), (x - sw * 0.3, b - h * 0.8), (x + sw, b - h)], 8),
                                     lambda q: n * 0.11 * (1 - q) ** 0.8 + 0.4)))
    fm = union(cv, flames)
    soft_light(cv, blur(fm, 1.5), "blast", 1.0, R=n * 0.03, glow_r=6, core_k=0.9, field=0.55 + 0.45 * streak_field(cv.w, -90, 40, 4, cv.seed()))
    shock_ring(cv, np.array([c[0], n * 0.82]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.36, n * 0.07, n * 0.02, el, 0.7)
    grenade(cv, c, n * 0.24, 0, el, kind="timed", pin=False)
    fuse = c + np.array([n * 0.0, -n * 0.27])
    sparks(cv, rng, fuse, 10, n * 0.12, el, 1.0, a_range=(200, 340), width=1.6)
    hot_core(cv, fuse[0], fuse[1], el, 2.4, 1.1, star_len=18)


@skill("spitfire.chaotic_thunder", tone="blast")
def chaotic_thunder(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.62), (n, n * 0.58), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.62), focus_r=0.6, focus_k=0.8, wash=-30, rng=rng)
    for (x, y, r) in ((0.20, 0.70, 0.13), (0.78, 0.66, 0.14), (0.50, 0.80, 0.17), (0.34, 0.50, 0.10), (0.66, 0.44, 0.09)):
        burst(cv, rng, (n * x, n * y), n * r, el if (x + y) % 0.2 < 0.1 else "spark", 0.9, smoke_k=0.6, puffs=7)
    for (x, y, s, a, kind) in ((0.12, 0.22, 0.065, -30, "frag"), (0.34, 0.12, 0.055, 40, "impact"), (0.58, 0.18, 0.06, 120, "frag"),
                              (0.84, 0.14, 0.05, -80, "impact"), (0.92, 0.36, 0.045, 60, "frag")):
        p = np.array([n * x, n * y])
        trail(cv, [p + np.array([-n * 0.10, -n * 0.08]), p + np.array([-n * 0.03, -n * 0.02])], 0.3, n * 0.016, "spark", 0.6)
        grenade(cv, p, n * s, a, el, kind=kind, pin=kind == "frag")
    hot_core(cv, n * 0.50, n * 0.78, el, 2.8, 1.1, star_len=22)
