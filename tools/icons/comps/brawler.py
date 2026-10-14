"""流氓 Brawler (爪 claws). Street-keyed bar: mustard, bruise purple, bottle fire, brass knuckles and chain.
The bar's one off-key accent is ice-cyan, on the ultimate's stolen skill orb.

Value plan (one big greyscale shape each):
  claw_swipe       three raking claw smears fanned from a claw gauntlet on the lower left               [claws]
  uppercut         VERTICAL FIST: a wrapped fist driving straight up, a rising smear and a burst on top
  strangle         NOOSE: a heavy chain loop cinched around a purple choke glow, the free end pulled up-right
  brick_buster     BLOCK: a brick slamming down on a diagonal into a cracked impact star, dizzy stars
  sand_toss        CONE: a sack low-left flinging a wide fan of sand grains and dust to the upper right
  molotov          BOTTLE: a tumbling bottle with a burning rag, a fire arc behind it, burning puddle below
  chain_punch      CLUSTER: a barrage of fists stacked toward the viewer, hit sparks bursting at the centre
  tooth_for_tooth  JAWS: two claw gauntlets closing like jaws on a stolen orb of light (cyan rim) (ULT)  [claws]
The claws appear in 2 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_night import brick, dizzy_stars, cloud, figure  # noqa: F401


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _claw(cv, H, el, blades=3, spread=1.0):
    """brawler claw gauntlet: brass knuckle plate, three hooked steel blades along +x (local, like weapons.claw)"""
    pal = tone(el)
    plate = lpoly(cv, H, spline([(0.0, -0.20), (0.26, -0.22), (0.33, 0.0), (0.26, 0.22), (0.0, 0.20), (-0.05, 0.0)], 4))
    cuff = lpoly(cv, H, [(-0.30, -0.16), (0.02, -0.19), (0.02, 0.19), (-0.30, 0.16)])
    solid(cv, H, cuff, "leather", 0.08, lw=(0.4, 2.0))
    cv.paint(cuff, "#4A1E5E", 0.45)
    for x in (-0.22, -0.12):
        cyl_band(cv, H, x, x + 0.04, 0.19, "brass")
    blades_m = []
    for i in range(blades):
        y = (i - (blades - 1) / 2) * 0.13 * spread
        b = lpoly(cv, H, spline([(0.22, y - 0.04), (0.6, y - 0.05), (0.92, y - 0.11), (1.02, y - 0.21)], 6).tolist()
                  + spline([(0.95, y - 0.12), (0.62, y + 0.005), (0.22, y + 0.04)], 6).tolist())
        blades_m.append(b)
    bm = union(cv, blades_m)
    ink_line(cv, bm, "#121828", 0.35, 1.8, 0.4)
    for b in blades_m:
        material(cv, b, "steel", R=lR(H, 0.02), line=False, streak_ang=None, back=pal[2], back_k=0.7)
        cv.paint(np.clip(b - toward(b, 0.9, (0, 1)), 0, 1) * 0.0, "#FFFFFF")
    solid(cv, H, plate, "brass", 0.07, lw=(0.4, 2.0), back=pal[2], back_k=0.5)
    for y in (-0.11, 0.0, 0.11):
        rv = cv.ellipse(*xf(H, [(0.15, y)])[0], lR(H, 0.028))
        solid(cv, H, rv, "darksteel", 0.02, lw=(0.2, 0.8))
    return union(cv, [plate, cuff, bm])


def _link(cv, c, ang, size, face, el):
    """one chain link: an oval ring face-on, or a thin bar edge-on"""
    H = H_affine(c, ang, size, size)
    t = np.linspace(0, 2 * math.pi, 40)
    if face:
        outer = cv.poly(xf(H, np.c_[np.cos(t) * 0.62, np.sin(t) * 0.36]))
        inner = cv.poly(xf(H, np.c_[np.cos(t) * 0.36, np.sin(t) * 0.13]))
        m = np.clip(outer - inner, 0, 1)
    else:
        m = cv.poly(xf(H, np.c_[np.cos(t) * 0.62, np.sin(t) * 0.12]))
    material(cv, m, "brass", R=size * 0.08, lw=(0.3, 1.4), back=tone(el)[2], back_k=0.6)
    return m


def _chain(cv, pts, size, el):
    sp = spline(pts, 16)
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(sp, axis=0), axis=1))]
    step = size * 0.78
    m = np.zeros((cv.w, cv.w), np.float32)
    k = 0
    s = 0.0
    while s <= seg[-1]:
        i = min(int(np.searchsorted(seg, s)), len(sp) - 2)
        d = sp[i + 1] - sp[i]
        np.maximum(m, _link(cv, sp[i], math.degrees(math.atan2(d[1], d[0])), size, k % 2 == 0, el), out=m)
        s += step
        k += 1
    return m


@skill("brawler.claw_swipe", tone="mustard")
def claw_swipe(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.62, n * 0.34), focus_r=0.5, focus_k=0.7, wash=-50, rng=rng)
    # three parallel raking gashes (same arc, offset across the stroke, staggered lengths), not a concentric fan
    for r, a0, a1, w, k in ((0.64, 0, -66, 0.07, 0.85), (0.78, 6, -74, 0.07, 1.0), (0.92, 12, -62, 0.06, 0.8)):
        crescent(cv, (n * 0.02, n * 1.02), n * r, n * r, 0, a0, a1, w, el, k, streak_freq=60.0)
    _claw(cv, weapon_H((n * 0.08, n * 0.94), (n * 0.48, n * 0.52), 0.9), el)
    hot_core(cv, n * 0.82, n * 0.30, el, 2.4, 1.0, star_len=18)


@skill("brawler.uppercut", tone="fire")
def uppercut(cv, rng, el):
    n = cv.n
    col_ = cv.poly([(n * 0.30, 0), (n * 0.70, 0), (n * 0.66, n), (n * 0.34, n)])
    ground(cv, el, [(col_, 1)], focus=(n * 0.5, n * 0.16), focus_r=0.45, focus_k=0.8, wash=-90, rng=rng)
    crescent(cv, (n * 0.86, n * 0.80), n * 0.48, n * 0.70, 0, 120, 190, 0.26, "mustard", 0.9)
    for x, y0, y1, w in ((0.24, 0.90, 0.46, 0.016), (0.78, 0.94, 0.56, 0.014), (0.34, 0.98, 0.70, 0.01)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    flare_spikes(cv, n * 0.52, n * 0.16, [(-90, 1.0), (-130, 0.6), (-50, 0.6), (-170, 0.4), (-10, 0.4)], n * 0.06, n * 0.24, n * 0.04, el, 0.9)
    fm = fist(cv, weapon_H((n * 0.50, n * 1.06), (n * 0.52, n * 0.20), 0.85), el, wrap="#E8D8B0", plate_mat="brass")
    hot_core(cv, n * 0.52, n * 0.14, el, 2.6, 1.1, star_len=20)


@skill("brawler.strangle", tone="purple")
def strangle(cv, rng, el):
    n = cv.n
    pal = tone(el)
    neck_c = np.array([n * 0.46, n * 0.56])
    ground(cv, el, [], focus=neck_c, focus_r=0.42, focus_k=0.8, wash=20, rng=rng)
    # the victim, head-and-shoulders bust: jacket shoulders, neck column, head forced back and to the side
    sh = cv.poly(closed_spline([(n * 0.02, n * 1.02), (n * 0.06, n * 0.80), (n * 0.30, n * 0.68), (n * 0.62, n * 0.68),
                                (n * 0.88, n * 0.80), (n * 0.94, n * 1.02)], 6))
    neck = cv.poly(closed_spline([(n * 0.34, n * 0.74), (n * 0.38, n * 0.50), (n * 0.44, n * 0.40), (n * 0.58, n * 0.42),
                                  (n * 0.60, n * 0.56), (n * 0.62, n * 0.74)], 6))
    hair = np.clip(cv.ellipse(n * 0.47, n * 0.25, n * 0.17, n * 0.15) - cv.poly([(n * 0.55, n * 0.20), (n * 0.80, n * 0.10),
                                                                              (n * 0.80, n * 0.50), (n * 0.53, n * 0.46)]), 0, 1)
    face = cv.poly(closed_spline([(n * 0.46, n * 0.12), (n * 0.56, n * 0.12), (n * 0.62, n * 0.17), (n * 0.70, n * 0.20),
                                  (n * 0.65, n * 0.25), (n * 0.67, n * 0.29), (n * 0.645, n * 0.33), (n * 0.64, n * 0.38),
                                  (n * 0.56, n * 0.44), (n * 0.48, n * 0.40), (n * 0.47, n * 0.26)], 4))
    head = union(cv, [hair, face])
    ink_line(cv, union(cv, [sh, neck, head]), "#0A0410", 0.4, 2.4, 0.4)
    material(cv, sh, "leather", R=n * 0.08, line=False, tilt=(0.0, -0.2), back=pal[2], back_k=0.7)
    cv.paint(sh, "#3A1A48", 0.4)
    skin = ["#5A3E22", "#A8885E", "#E6D2B0"]
    paint_form(cv, neck, skin, R=n * 0.04, grad=0.5)
    for pts in (((0.44, 0.44), (0.42, 0.58), (0.40, 0.70)), ((0.55, 0.46), (0.56, 0.58), (0.58, 0.70))):   # strained tendons
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.014, n * 0.008) * neck, "#5A3E22", 0.6)
    paint_form(cv, hair, ["#06060A", "#141420", "#2A2A3E", "#4A4A66"], R=n * 0.05, grad=0.5)
    paint_form(cv, face * (1 - hair), skin + ["#FFF8EA"], R=n * 0.03, grad=0.5)
    cv.paint(neck * cv.ellipse(n * 0.54, n * 0.45, n * 0.10, n * 0.04), "#3A2414", 0.55)   # shadow under the jaw
    cv.paint(stroke(cv, [(n * 0.57, n * 0.18), (n * 0.62, n * 0.185)], n * 0.016, n * 0.01) * face, "#2A1A10", 0.8)   # shut eye
    cv.paint(stroke(cv, [(n * 0.62, n * 0.30), (n * 0.655, n * 0.305)], n * 0.012, n * 0.008) * face, "#5A1E1E", 0.8)  # mouth

    # choke glow squeezed out around the throat
    glow(cv, cv.ellipse(neck_c[0], neck_c[1], n * 0.12, n * 0.05), pal[1], 8, 0.9)
    # chain noose: back half behind the neck, front half over it, free end pulled up to the right
    loop_back = [(neck_c[0] + math.cos(a) * n * 0.14, neck_c[1] + math.sin(a) * n * 0.05) for a in np.linspace(math.pi * 1.05, math.pi * 1.95, 6)]
    loop_front = [(neck_c[0] + math.cos(a) * n * 0.15, neck_c[1] + math.sin(a) * n * 0.06) for a in np.linspace(-0.1, math.pi + 0.1, 8)]
    cv.paint(neck * cv.poly(ribbon(spline(loop_back, 6), [n * 0.05] * len(spline(loop_back, 6)))), "#1A0A22", 0.6)
    _chain(cv, loop_front, n * 0.075, el)
    _chain(cv, [(neck_c[0] + n * 0.15, neck_c[1]), (n * 0.76, n * 0.36), (n * 0.98, n * 0.08)], n * 0.085, el)
    for x, y, L in ((0.30, 0.66, 0.14), (0.62, 0.66, 0.18)):   # slow: heavy drips of purple light
        light_streak(cv, (n * x, n * y), (n * x, n * (y + L)), n * 0.022, el, 0.7)
    hot_core(cv, neck_c[0] - n * 0.04, neck_c[1] + n * 0.04, el, 2.2, 1.0, star_len=14)


@skill("brawler.brick_buster", tone="mustard")
def brick_buster(cv, rng, el):
    n = cv.n
    hit = np.array([n * 0.34, n * 0.70])
    ground(cv, el, [], focus=hit, focus_r=0.45, focus_k=0.8, wash=-130, rng=rng)
    for a in (-140, -120, -100):   # the downswing
        light_streak(cv, hit + _dv(-50) * n * 0.70 + _dv(a + 90) * n * 0.05 * (a + 120) / 20, hit + _dv(-50) * n * 0.30, n * 0.02, el, 0.6)
    # impact star cracks
    flare_spikes(cv, hit[0], hit[1], [(a, s) for a, s in ((200, 1.0), (150, 0.7), (250, 0.6), (100, 0.5), (300, 0.5), (20, 0.4))],
                 n * 0.04, n * 0.30, n * 0.035, el, 0.9)
    brick(cv, hit + _dv(-50) * n * 0.26, n * 0.62, -40, el)
    dizzy_stars(cv, (n * 0.30, n * 0.78), n * 0.20, n * 0.06, (160, 240, 330, 50), n * 0.05)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1, star_len=20)


@skill("brawler.sand_toss", tone="mustard")
def sand_toss(cv, rng, el):
    n = cv.n
    src = np.array([n * 0.22, n * 0.78])
    ground(cv, el, [], focus=(n * 0.70, n * 0.32), focus_r=0.55, focus_k=0.6, wash=-40, rng=rng)
    pal = tone(el)
    # the throw: a fan of streaked sand spray
    for i in range(16):
        a = rng.uniform(-74, -10)
        L = n * rng.uniform(0.45, 0.85)
        p0 = src + _dv(a) * n * rng.uniform(0.04, 0.12)
        light_streak(cv, p0, src + _dv(a) * L, n * rng.uniform(0.012, 0.03), el, 0.55)
    # blinding dust haze where it lands
    X, Y = cv.grid()
    hz = np.exp(-(((X - n * 0.72) / (n * 0.24)) ** 2 + ((Y - n * 0.32) / (n * 0.20)) ** 2))
    cv.add(hz * (0.6 + 0.6 * cv.noise), pal[1], 0.45)
    for i in range(90):   # grains: big near the hand, fine in the haze
        t = rng.uniform(0.1, 1.0) ** 0.7
        a = math.radians(rng.uniform(-76, -8))
        p = src + np.array([math.cos(a), math.sin(a)]) * n * t * 0.86
        r = n * (0.018 - 0.012 * t) * rng.uniform(0.6, 1.3)
        g = cv.ellipse(p[0], p[1], r)
        cv.paint(g, mix(pal[1], pal[2], rng.uniform(0.1, 0.7)), 0.95)
        cv.paint(g * (1 - toward(g, r * 0.6, -LIGHT2)), pal[0], 0.7)
    # the sack: rough purple cloth, gathered neck tied with brass wire
    sack = cv.poly(closed_spline([(n * 0.02, n * 0.98), (n * 0.03, n * 0.80), (n * 0.11, n * 0.71), (n * 0.22, n * 0.70),
                                  (n * 0.30, n * 0.78), (n * 0.27, n * 0.93), (n * 0.16, n * 1.02)], 6))
    material(cv, sack, "leather", R=n * 0.05, lw=(0.4, 2.0), back=pal[2], back_k=0.7)
    cv.paint(sack, "#5A2E6E", 0.5)
    for pts in (((0.08, 0.80), (0.12, 0.88), (0.10, 0.96)), ((0.18, 0.80), (0.22, 0.88), (0.20, 0.96))):
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.012, n * 0.006) * sack, "#1A0A22", 0.6)
    tie = stroke(cv, [(n * 0.10, n * 0.73), (n * 0.20, n * 0.78), (n * 0.30, n * 0.76)], n * 0.025, n * 0.02)
    material(cv, tie, "brass", R=n * 0.008, lw=(0.2, 0.9))
    hot_core(cv, n * 0.30, n * 0.68, el, 1.8, 0.8, star_len=12)


@skill("brawler.molotov", tone="fire")
def molotov(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.86), focus_r=0.5, focus_k=0.8, wash=-20, rng=rng)
    # burning puddle on the floor
    pool = cv.ellipse(n * 0.52, n * 0.88, n * 0.40, n * 0.07)
    soft_light(cv, pool, el, 0.8, R=n * 0.03, glow_r=6)
    for x, h in ((0.24, 0.16), (0.40, 0.24), (0.58, 0.20), (0.74, 0.14)):
        fl = cv.poly(ribbon(spline([(n * x, n * 0.90), (n * (x - 0.02), n * (0.90 - h * 0.5)), (n * (x + 0.02), n * (0.90 - h))], 6),
                            lambda t: n * 0.06 * (1 - t) ** 0.8 + 0.4))
        light_form(cv, fl, el, 0.9, R=n * 0.02, glow_r=4, lw=(0.2, 1.2))
    # the throw arc
    trail(cv, [(n * 0.02, n * 0.60), (n * 0.20, n * 0.32), (n * 0.40, n * 0.26)], 0.5, n * 0.05, el, 0.7, core_k=0.5)
    # the bottle: tilted, glass with liquid, a rag stuffed in the neck burning
    H = weapon_H((n * 0.36, n * 0.68), (n * 0.66, n * 0.16), 1.0)
    body = lpoly(cv, H, spline([(0.0, -0.17), (0.40, -0.18), (0.52, -0.12), (0.62, -0.06), (0.82, -0.06), (0.82, 0.06),
                                (0.62, 0.06), (0.52, 0.12), (0.40, 0.18), (0.0, 0.17), (-0.02, 0.0)], 3))
    liquid = lpoly(cv, H, [(0.0, -0.17), (0.30, -0.18), (0.30, 0.18), (0.0, 0.17)]) * body
    material(cv, body, "glass", R=n * 0.05, lw=(0.4, 2.0))
    cv.paint(body, "#6A4A14", 0.55)   # amber bottle glass (keeps the bar warm)
    paint_form(cv, liquid, ["#5A3008", "#A8601A", "#E8A040", "#FFD890"], R=n * 0.04, grad=0.5)
    glare = lrib(cv, H, [(0.06, -0.10), (0.36, -0.12), (0.5, -0.08)], 0.02, 0.008)
    cv.paint(glare * body, "#FFFFFF", 0.7)
    rag = lpoly(cv, H, spline([(0.80, -0.07), (0.94, -0.10), (1.04, -0.02), (1.10, 0.12), (0.96, 0.10), (0.80, 0.07)], 3))
    material(cv, rag, "leather", R=n * 0.02, lw=(0.3, 1.4))
    cv.paint(rag, "#E8D8B0", 0.5)
    tipp = xf(H, [(1.08, 0.04)])[0]
    burst(cv, rng, tipp + np.array([n * 0.04, -n * 0.06]), n * 0.11, el, 0.9, smoke_k=0.5, puffs=6, core=False)
    hot_core(cv, tipp[0] + n * 0.03, tipp[1] - n * 0.05, el, 2.4, 1.0, star_len=16)


@skill("brawler.chain_punch", tone="purple")
def chain_punch(cv, rng, el):
    n = cv.n
    pal = tone(el)
    hit = np.array([n * 0.74, n * 0.46])
    ground(cv, el, [], focus=hit, focus_r=0.45, focus_k=0.8, wash=-10, rng=rng)
    speed_lines(cv, rng, -8, 10, "mustard", 0.6, length=(0.3, 0.6), band=(0.15, 0.85))
    # afterimage fists: purple ghosts of the earlier punches
    for (bx, by), (tx, ty), ws in (((-0.10, 0.04), (0.60, 0.22), 0.6), ((-0.10, 0.92), (0.62, 0.70), 0.6)):
        fm = fist(cv, weapon_H((n * bx, n * by), (n * tx, n * ty), ws), el, wrap="#E8D8B0", plate_mat="brass")
        cv.paint(fm, mix(pal[0], pal[1], 0.5), 0.55)
        cv.add(fm * (1 - toward(fm, 1.5, LIGHT)), pal[2], 0.8)
    for a in range(0, 360, 36):
        light_streak(cv, hit + _dv(a) * n * 0.08, hit + _dv(a) * n * (0.22 + 0.06 * math.sin(a)), n * 0.024, "mustard", 0.9)
    fist(cv, weapon_H((n * 0.00, n * 0.56), (n * 0.70, n * 0.46), 0.85), el, wrap="#E8D8B0", plate_mat="brass")
    hot_core(cv, hit[0] + n * 0.06, hit[1], "mustard", 2.8, 1.2, star_len=22)


@skill("brawler.tooth_for_tooth", tone="purple")
def tooth_for_tooth(cv, rng, el):
    n = cv.n
    orb = np.array([n * 0.56, n * 0.50])
    ground(cv, el, [], focus=orb, focus_r=0.45, focus_k=0.7, wash=180, rng=rng)
    crescent(cv, orb, n * 0.40, n * 0.40, 0, 200, 340, 0.20, "fire", 0.7)
    crescent(cv, orb, n * 0.40, n * 0.40, 0, 20, 160, 0.20, "fire", 0.7)
    # the stolen skill: an orb of light
    om = cv.ellipse(orb[0], orb[1], n * 0.12)
    soft_light(cv, om, "mustard", 1.0, R=n * 0.08, glow_r=8, core_k=1.2)
    # two claw gauntlets closing on it like upper and lower jaws
    _claw(cv, weapon_H((n * -0.02, n * 0.20), (n * 0.70, n * 0.40), 0.95), el, spread=1.1)
    _claw(cv, H_affine((n * -0.02, n * 0.80), -16, n * 0.74, -n * 0.70), el, spread=1.1)
    hot_core(cv, orb[0], orb[1], "mustard", 2.8, 1.1, star_len=20)

    def bleed(c2):
        m = c2.ellipse(orb[0], orb[1], n * 0.13)
        ring = np.clip(m - c2.ellipse(orb[0] - n * 0.012, orb[1] - n * 0.012, n * 0.12), 0, 1)
        c2.add(blur(ring, 0.8), KEY["cool"], 1.0)   # the bar's one off-key accent
    return {"bleed": bleed}
