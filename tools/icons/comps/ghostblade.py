"""鬼剑士 Ghostblade (bandaged arm, ghost runes, long coat, tachi). Violet-keyed bar: ghost violet, moon silver-blue and
soul magenta on a black-violet ground, silver metal. The bar's one off-key accent is ice-cyan, on 冰阵 (its element
demands it).

Value plan:
  atk1                  the tachi level across the frame, a flat violet swing-plane smear below it        [tachi]
  ghost_claw            a spectral clawed hand bursting straight up out of a ground rift, debris launched
  moonlight_slash       a huge pale crescent moon ("C"), the upward slash arc cutting across its mouth
  full_moonlight_slash  a full moon disc ringed by a near-closed circular slash, shards blown outward
  ice_soul              a top-down frost mandala: six ice crystals radiating from a cyan core (cyan accent)
  silence_boundary      a dark temple bell bound in chains, its sound rings cut off, violet seal below
  sword_soul            a palisade of ghost tachi planted point-down around a rune circle             [tachi]
  ghost_feast           three boundaries detonating at once: three pillars of ghost fire, a burst between
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_swordmage import ICE, crystal, flame, rune_ring, tachi, wisp

SPECTRE = ["#0C0618", "#2A1450", "#6A3CB0", "#C8A8FF"]
RUNE = "#D8B8FF"


@skill("ghostblade.atk1", tone="ghost")
def tachi_slash(cv, rng, el):
    n = cv.n
    mass = cv.poly([(0, n * 0.62), (n, n * 0.70), (n, n), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.22, n * 0.34), focus_r=0.5, focus_k=0.6, wash=15, rng=rng)
    crescent(cv, (n * 0.50, n * 0.50), n * 0.48, n * 0.24, 16, 30, 198, 0.42, el, 1.0)
    H = weapon_H((n * 0.94, n * 0.70), (n * 0.08, n * 0.30), 1.4)
    tachi(cv, H, el, rune=RUNE)
    tip = xf(H, [(0.98, -0.05)])[0]
    hot_core(cv, tip[0], tip[1], el, 2.2, 1.0, star_len=16, ang=25)


def _spectral_hand(cv, pc, fingers, thumb, el, k=1.0, claw_len=1.0):
    """a ghost hand: dark violet translucent form, glowing rim and knuckles. fingers: [(ang, len, bend)]"""
    n = cv.n
    parts = [cv.ellipse(pc[0], pc[1], n * 0.15, n * 0.13)]
    fms, claws = [], []
    for a, L, bend in fingers:
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        base = pc + d * n * 0.08
        k1 = base + d * n * L * 0.5
        d2 = np.array([math.cos(ar + math.radians(bend)), math.sin(ar + math.radians(bend))])
        k2 = k1 + d2 * n * L * 0.32
        d3 = np.array([math.cos(ar + math.radians(bend * 2.2)), math.sin(ar + math.radians(bend * 2.2))])
        tip = k2 + d3 * n * L * 0.18
        fw = n * 0.062
        f = union(cv, [cv.poly(ribbon(spline([base, k1, k2, tip], 6), lambda u: fw * (1 - u * 0.5) + 0.4)), cv.ellipse(k1[0], k1[1], fw * 0.55)])
        fms.append(f)
        claws.append(stroke(cv, [tip, tip + d3 * n * 0.05 * claw_len, tip + d3 * n * 0.08 * claw_len + d2 * n * 0.03 * claw_len], n * 0.03, 0.4))
    parts += fms
    if thumb is not None:
        t0, t1, t2 = [np.asarray(p, float) for p in thumb]
        tm = cv.poly(ribbon(spline([t0, t1, t2], 6), lambda u: n * 0.07 * (1 - u * 0.45) + 0.4))
        parts.append(tm)
        fms.append(tm)
    hand = union(cv, parts)
    glow(cv, hand, tone(el)[1], 10, 0.8 * k)
    ink_line(cv, hand, "#1A0A30", 0.35, 2.0, 0.4)
    paint_form(cv, hand, SPECTRE, R=n * 0.03, grad=0.6, thr=[0.24, 0.55, 0.86], alpha=0.92)
    for f in fms:
        cv.paint(np.clip(f - toward(f, 1.5, LIGHT), 0, 1) * hand, SPECTRE[0], 0.6)
    cv.add(np.clip(hand - toward(hand, 1.6, -LIGHT2), 0, 1), tone(el)[2], 0.7)
    for cm in claws:
        light_form(cv, cm, el, 1.0, R=n * 0.006, glow_r=3, lw=(0.2, 0.8))
    return hand


@skill("ghostblade.ghost_claw", tone="ghost")
def ghost_claw(cv, rng, el):
    n = cv.n
    rift_c = np.array([n * 0.50, n * 0.88])
    low = cv.poly([(0, n * 0.80), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    rift = cv.ellipse(rift_c[0], rift_c[1], n * 0.36, n * 0.08)
    glow(cv, rift, tone(el)[1], 6, 0.9)
    cv.paint(rift, "#05020A")
    cv.add(np.clip(rift - toward(rift, 2.0, (0, 1)), 0, 1), tone(el)[2], 0.9)
    for x, y0, y1 in ((0.16, 0.86, 0.40), (0.84, 0.86, 0.44), (0.28, 0.90, 0.24), (0.74, 0.90, 0.20)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * 0.014, el, 0.6)
    arm = cv.poly(ribbon([rift_c + np.array([0, n * 0.02]), rift_c + np.array([n * 0.01, -n * 0.18]), (n * 0.50, n * 0.62)], [n * 0.20, n * 0.18, n * 0.18]))
    glow(cv, arm, tone(el)[1], 6, 0.6)
    paint_form(cv, arm, SPECTRE, R=n * 0.04, grad=0.6, alpha=0.9)
    for y in (0.70, 0.76):   # torn bandage wraps on the wrist
        bw = cv.poly(ribbon([(n * 0.38, n * (y + 0.02)), (n * 0.62, n * (y - 0.02))], [n * 0.035] * 2)) * dilate(arm, 0.5)
        paint_form(cv, bw, ["#3A3448", "#7A7088", "#C8C0D4", "#F2EEF8"], R=n * 0.012, grad=0.4)
    _spectral_hand(cv, np.array([n * 0.50, n * 0.56]),
                   [(-142, 0.40, 34), (-112, 0.50, 24), (-84, 0.52, -8), (-56, 0.44, -28)],
                   [(n * 0.64, n * 0.60), (n * 0.78, n * 0.52), (n * 0.84, n * 0.38)], el, claw_len=1.8)
    for x, y, s, a in ((0.16, 0.20, 0.035, 20), (0.86, 0.16, 0.03, -40), (0.10, 0.48, 0.03, 70)):
        stone_chip(cv, rng, n * x, n * y, n * s, a, el, trail=(0.0, -1.0))
    hot_core(cv, n * 0.46, n * 0.07, el, 2.2, 1.0, star_len=16)


@skill("ghostblade.moonlight_slash", tone="moon")
def moonlight_slash(cv, rng, el):
    n = cv.n
    ground(cv, "ghost", [], focus=(n * 0.56, n * 0.40), focus_r=0.55, focus_k=0.6, wash=-60, rng=rng)
    mc = np.array([n * 0.54, n * 0.46])
    moon = np.clip(cv.ellipse(mc[0], mc[1], n * 0.36) - cv.ellipse(mc[0] + n * 0.18, mc[1] - n * 0.08, n * 0.32), 0, 1)
    glow(cv, moon, tone(el)[1], 14, 0.5)
    ink_line(cv, moon, "#2A3A6A", 0.3, 1.8, 0.4)
    X, Y = cv.grid()
    maria = 0.18 * (lowfreq(cv.w, 7, 77) - 0.5)
    paint_form(cv, moon, ["#4A5A8A", "#8A9ACC", "#D2DCFF", "#FFFFFF"], R=n * 0.06, grad=0.5, field=maria, thr=[0.2, 0.5, 0.85])
    crescent(cv, (n * 0.70, n * 0.74), n * 0.62, n * 0.56, 0, 150, 255, 0.24, "ghost", 1.0)
    plate_fragment(cv, rng, n * 0.30, n * 0.14, n * 0.10, -20, "ghost", 0.9, trail=(0.2, -1.0))
    hot_core(cv, n * 0.56, n * 0.18, "ghost", 2.4, 1.0, star_len=18)


@skill("ghostblade.full_moonlight_slash", tone="moon")
def full_moon(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, "ghost", [], focus=c, focus_r=0.5, focus_k=0.6, ink="#05030A", wash=-30, rng=rng)
    disc = cv.ellipse(c[0], c[1], n * 0.22)
    glow(cv, disc, tone(el)[1], 16, 0.6)
    ink_line(cv, disc, "#2A3A6A", 0.3, 1.6, 0.4)
    maria = 0.22 * (lowfreq(cv.w, 6, 91) - 0.5)
    paint_form(cv, disc, ["#4A5A8A", "#8A9ACC", "#D2DCFF", "#FFFFFF"], R=n * 0.08, grad=0.5, field=maria, thr=[0.2, 0.5, 0.85])
    crescent(cv, c, n * 0.38, n * 0.38, 0, -60, 270, 0.30, "ghost", 1.0)
    for a in (-30, 30, 100, 160, 210):   # shards blown out of the ring
        ar = math.radians(a)
        p = c + np.array([math.cos(ar), math.sin(ar)]) * n * 0.44
        plate_fragment(cv, rng, p[0], p[1], n * 0.07, a + 90, "ghost", 0.8, trail=(math.cos(ar), math.sin(ar)))
    hot_core(cv, c[0] + n * 0.19, c[1] - n * 0.33, "ghost", 2.4, 1.0, star_len=18)


@skill("ghostblade.ice_soul", tone="moon")
def ice_soul(cv, rng, el):
    """冰阵: a frozen seal circle on the ground, a cluster of ice crystals bursting up from it at uneven angles,
    cyan cold light at the roots (the bar's one off-key accent)"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.78])
    ground(cv, el, [(cv.ellipse(c[0], c[1], n * 0.48, n * 0.15), 1)], focus=(n * 0.50, n * 0.56), focus_r=0.5, focus_k=0.5, ink="#04060C",
           wash=-90, rng=rng)
    cyan = KEY["cool"]
    frost = cv.ellipse(c[0], c[1], n * 0.44, n * 0.13)
    paint_form(cv, frost, ["#0A1A2A", "#1E4A6A", "#3E86A8", "#9FE4F4"], R=n * 0.04, grad=0.5, tilt=(0.0, -0.5), alpha=0.85)
    rune_ring(cv, c, n * 0.40, n * 0.12, el, 0.8, w=n * 0.010, ticks=20, star=6)
    for x, a, h, w in ((0.24, -118, 0.20, 0.07), (0.78, -64, 0.22, 0.075), (0.36, -100, 0.38, 0.10), (0.64, -78, 0.42, 0.11),
                       (0.52, -88, 0.62, 0.15), (0.44, -128, 0.24, 0.07), (0.60, -50, 0.20, 0.065), (0.86, -40, 0.12, 0.05),
                       (0.14, -150, 0.12, 0.05)):
        crystal(cv, (n * x, c[1] - n * 0.01), a, n * h, n * w, glow_c=cyan)
    roots = cv.ellipse(c[0], c[1] - n * 0.01, n * 0.30, n * 0.06)
    cv.add(blur(roots, 5), cyan, 0.7)
    hot_core(cv, n * 0.53, n * 0.22, el, 2.4, 1.0, star_len=18)


@skill("ghostblade.silence_boundary", tone="ghost")
def silence(cv, rng, el):
    """a dark temple bell bound in chains: its sound rings stop dead at the chains; a violet seal under it"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.44), focus_r=0.5, focus_k=0.5, wash=-90, rng=rng)
    rune_ring(cv, (n * 0.50, n * 0.86), n * 0.40, n * 0.10, el, 0.9, w=n * 0.012, ticks=24, star=5)
    for r, k in ((0.34, 0.6), (0.44, 0.4)):   # sound rings, broken off where the chains bind
        for a0, a1 in ((200, 250), (290, 340)):
            seg = cv.poly(ribbon(arc_pts(n * 0.50, n * 0.44, n * r, a0, a1, 16), [n * 0.012] * 16))
            soft_light(cv, seg, "soul", k, R=0.8, glow_r=2)
    out = [(n * 0.46, n * 0.16), (n * 0.54, n * 0.16), (n * 0.56, n * 0.20), (n * 0.66, n * 0.24), (n * 0.68, n * 0.40),
           (n * 0.72, n * 0.62), (n * 0.80, n * 0.74), (n * 0.50, n * 0.78), (n * 0.20, n * 0.74), (n * 0.28, n * 0.62),
           (n * 0.32, n * 0.40), (n * 0.34, n * 0.24), (n * 0.44, n * 0.20)]
    bell = cv.poly(closed_spline(out, 5))
    crown = np.clip(cv.ellipse(n * 0.50, n * 0.12, n * 0.06, n * 0.05) - cv.ellipse(n * 0.50, n * 0.12, n * 0.03, n * 0.025), 0, 1)
    material(cv, crown, "darksteel", R=n * 0.01, lw=(0.3, 1.4), back=tone(el)[1], back_k=0.8)
    material(cv, bell, "darksteel", R=n * 0.10, lw=(0.4, 2.4), grad=0.6, tilt=(-0.1, -0.1), back=tone(el)[1], back_k=0.9)
    X, Y = cv.grid()
    for y in (0.30, 0.56, 0.70):   # cast ribs
        rib = cv.poly(ribbon(spline([(n * 0.10, n * (y - 0.02)), (n * 0.50, n * (y + 0.025)), (n * 0.90, n * (y - 0.02))], 6), [n * 0.018] * 3)) * bell
        material(cv, rib, "steel", R=n * 0.008, line=False)
    lip = cv.ellipse(n * 0.50, n * 0.765, n * 0.30, n * 0.03) * dilate(bell, 1.0)
    cv.paint(lip, "#05030A", 0.9)
    clap = cv.ellipse(n * 0.52, n * 0.80, n * 0.035)
    material(cv, clap, "darksteel", R=n * 0.01, lw=(0.3, 1.2))
    for p0, p1 in (((0.18, 0.30), (0.82, 0.62)), ((0.82, 0.28), (0.18, 0.64))):   # chains crossing the bell
        p0, p1 = np.array(p0) * n, np.array(p1) * n
        d = (p1 - p0) / np.linalg.norm(p1 - p0)
        nv = np.array([-d[1], d[0]])
        L = np.linalg.norm(p1 - p0)
        k = int(L / (n * 0.055))
        for i in range(k + 1):
            p = p0 + d * L * i / k
            if i % 2 == 0:
                lk = np.clip(cv.poly(ribbon(arc_pts(0, 0, 1, 0, 360, 24) * [n * 0.034, n * 0.018] @ np.array([[d[0], d[1]], [nv[0], nv[1]]]) + p,
                                            [n * 0.010] * 24)), 0, 1)
            else:
                lk = cv.poly(ribbon([p - d * n * 0.028, p + d * n * 0.028], [n * 0.014] * 2))
            material(cv, lk, "steel", R=n * 0.006, lw=(0.25, 1.1), back=tone(el)[1], back_k=0.7)
    seal = cv.ellipse(n * 0.50, n * 0.46, n * 0.045)
    glow(cv, seal, tone(el)[1], 5, 1.0)
    cv.add(seal, tone(el)[2], 0.8)
    hot_core(cv, n * 0.50, n * 0.46, el, 1.8, 0.9, star_len=14)


@skill("ghostblade.sword_soul", tone="soul")
def sword_soul(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.76])
    ground(cv, "ghost", [(cv.ellipse(c[0], c[1], n * 0.46, n * 0.15), 1)], focus=(n * 0.50, n * 0.46), focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    rune_ring(cv, c, n * 0.38, n * 0.11, el, 0.9, w=n * 0.012, ticks=20, star=6)
    X, Y = cv.grid()
    col_m = cv.poly([(n * 0.30, c[1]), (n * 0.40, n * 0.0), (n * 0.60, n * 0.0), (n * 0.70, c[1])])
    cv.add(blur(col_m, 8) * smoothstep(0, n, Y), tone(el)[1], 0.35)
    pts = []
    for a in (215, 270, 325, 30, 90, 150):
        ar = math.radians(a)
        pts.append((math.sin(ar), c + np.array([math.cos(ar) * n * 0.38, math.sin(ar) * n * 0.11])))
    for depth, p in sorted(pts, key=lambda q: q[0]):
        s = 0.80 + 0.22 * depth
        hilt = p + np.array([0, -n * 0.70 * s])
        H = weapon_H(hilt, p + np.array([0, n * 0.02]), 1.4)
        glow(cv, lpoly(cv, H, [(0.2, -0.03), (1.0, -0.03), (1.0, 0.03), (0.2, 0.03)]), tone(el)[1], 4, 0.6)
        tachi(cv, H, el, rune=RUNE if depth > 0 else None)
        if depth < 0:
            cv.paint(blur(lpoly(cv, H, [(0.0, -0.06), (1.0, -0.06), (1.0, 0.06), (0.0, 0.06)]), 1.0), tone("ghost")[0], 0.35)
    hot_core(cv, c[0], c[1] - n * 0.36, el, 2.4, 1.0, star_len=20)


@skill("ghostblade.ghost_feast", tone="soul")
def ghost_feast(cv, rng, el):
    """every boundary detonates: three seal circles erupt in pillars of ghost light, wisps of ghost-fire streaming up
    them into one burst"""
    n = cv.n
    ground(cv, "ghost", [], focus=(n * 0.50, n * 0.36), focus_r=0.55, focus_k=0.8, ink="#05030A", wash=-90, rng=rng)
    X, Y = cv.grid()
    top = np.array([n * 0.50, n * 0.30])
    for (x, y, s, t) in ((0.20, 0.66, 0.78, "ghost"), (0.80, 0.70, 0.80, "ghost"), (0.50, 0.90, 1.0, el)):
        base = np.array([n * x, n * y])
        rune_ring(cv, base, n * 0.20 * s, n * 0.06 * s, t, 0.9, w=n * 0.010, ticks=16, star=5)
        col_m = cv.poly(ribbon(spline([base, base + (top - base) * 0.5 + np.array([0, -n * 0.05]), top], 6), lambda u: n * 0.20 * s * (1 - 0.7 * u)))
        soft_light(cv, blur(col_m, 2.5), t, 0.55, R=n * 0.05, glow_r=8, core_k=0.4)
        for j in range(3):   # ghost-fire tongues streaming up the pillar
            off = (j - 1) * n * 0.05 * s
            p0 = base + np.array([off, -n * 0.01])
            q = [p0, p0 + (top - p0) * 0.35 + np.array([off * 0.8 + rng.uniform(-1, 1) * n * 0.04, 0]),
                 p0 + (top - p0) * 0.65 + np.array([-off * 0.6 + rng.uniform(-1, 1) * n * 0.04, 0]), p0 + (top - p0) * rng.uniform(0.80, 0.95)]
            tm = cv.poly(ribbon(spline(q, 8), lambda u: n * 0.07 * s * (1 - u) ** 0.7 + 0.4))
            light_form(cv, tm, t, 0.85, R=n * 0.012, glow_r=4, lw=(0.2, 1.2), value=0.9)
    burst(cv, rng, top, n * 0.14, el, 0.9, smoke_k=0.0, puffs=6, core=False)
    for i in range(8):
        a = math.radians(-90 + rng.uniform(-80, 80))
        light_streak(cv, top, (top[0] + math.cos(a) * n * 0.44, top[1] + math.sin(a) * n * 0.44), n * 0.014, el, 0.6)
    hot_core(cv, top[0], top[1], el, 3.0, 1.2, star_len=24)
