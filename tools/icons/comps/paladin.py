"""守护天使 Paladin. White / sky-blue / gold keyed bar: holy gold light, sky light, white feathers and enamel.
The bar's one off-key accent is the key's `cool` coral, on the ultimate 天使威光's outer pulse rim only.

Value plan:
  atk1                the great axe chopping straight down, a tall vertical cleave smear beside it             [axe]
  holy_light_strike   the axe swung up on a rising diagonal, a holy starburst blooming above the edge           [axe]
  rising_emblem       a sky rune circle almost flat at the bottom, a fan of launch rays bursting from it
  halo_smash          a huge gold halo ring slammed flat into the ground: cracks, dust ring, chips thrown up
  recovery            one large white feather drifting down on a curve, a trail of soft sky motes behind it
  holy_shield         a white-and-gold kite shield face-on inside a dome of light, an arrow glancing off
  life_activation     an opening lotus of sky light at the bottom, life motes and small rings rising
  angels_might        two great wings raised in a V behind a blazing core inside three expanding pulse rings
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_priest import feather, rune_circle, wing

SKY = "#9FCFFF"


def _axe(cv, butt, top, el, scale=1.5):
    """巨斧: a two-handed great axe. Ivory haft with gold bands; a broad bearded crescent bit on the -y side with a
    honed edge band and concave cheeks, a short back spike on the +y side, a gold-socketed eye with a sky gem and
    a spear point on top. Local x along the haft."""
    H = weapon_H(butt, top, scale)
    pal = tone(el)
    ang = math.degrees(math.atan2(top[1] - butt[1], top[0] - butt[0]))
    haft = lpoly(cv, H, [(0.0, -0.012), (0.90, -0.015), (0.90, 0.015), (0.0, 0.012)])
    ink_line(cv, haft, "#1C2236", 0.4, 1.8, 0.4)
    solid(cv, H, haft, "ivory", 0.012, line=False, streak_ang=ang, back=pal[2], back_k=0.5)
    for x in (0.02, 0.30, 0.56):
        cyl_band(cv, H, x, x + 0.03, 0.02, "gold")
    edge_pts = spline([(0.62, -0.42), (0.70, -0.47), (0.82, -0.49), (0.94, -0.46), (1.02, -0.40)], 8)
    bit = lpoly(cv, H, [(0.86, -0.03), (0.82, -0.13), (0.72, -0.28)] + [tuple(p) for p in edge_pts] + [(0.97, -0.24), (0.93, -0.12), (0.92, -0.03)])
    spike = lpoly(cv, H, [(0.82, 0.03), (0.85, 0.12), (0.87, 0.20), (0.90, 0.12), (0.92, 0.03)])
    blade = union(cv, [bit, spike])
    ink_line(cv, blade, "#0A0E1A", 0.45, 2.2, 0.35)
    solid(cv, H, blade, "plate", 0.06, line=False, streak_ang=ang + 90, back=pal[2], back_k=0.8)
    edge = lrib(cv, H, [tuple(p) for p in edge_pts], 0.09, 0.09) * bit
    paint_form(cv, edge, ["#7A849C", "#B8C2D4", "#E8EEF6", "#FFFFFF"], R=lR(H, 0.02), grad=0.6, tilt=(-0.3, -0.3))
    inlay = lrib(cv, H, [(0.68, -0.36), (0.80, -0.40), (0.92, -0.38), (0.98, -0.33)], 0.012, 0.012) * bit
    material(cv, inlay, "gold", R=1.0, line=False)
    bev = lrib(cv, H, [(0.86, -0.06), (0.80, -0.18), (0.70, -0.33)], 0.012, 0.006) * bit
    cv.paint(bev, "#C8D2E2", 0.6)
    tipm = lpoly(cv, H, [(0.90, -0.03), (1.04, 0.0), (0.90, 0.03)])
    solid(cv, H, tipm, "steel", 0.02, lw=(0.3, 1.2))
    sock = lpoly(cv, H, [(0.78, -0.045), (0.94, -0.045), (0.94, 0.045), (0.78, 0.045)])
    solid(cv, H, sock, "gold", 0.03, lw=(0.3, 1.4))
    c = xf(H, [(0.86, 0.0)])[0]
    gem = cv.ellipse(c[0], c[1], lR(H, 0.026))
    glow(cv, gem, "#7FB4FF", 3, 0.8)
    paint_form(cv, gem, ["#0A2A5A", "#3A7AD8", "#9FCFFF", "#FFFFFF"], R=lR(H, 0.015), grad=0.5)
    return union(cv, [haft, blade, tipm, sock])


@skill("paladin.atk1", tone="sky")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, el, [(cv.poly([(0, n * 0.88), (n, n * 0.88), (n, n), (0, n)]), 1)], focus=(n * 0.56, n * 0.80), focus_r=0.5, focus_k=0.6,
           wash=-90, rng=rng)
    crescent(cv, (n * 0.20, n * 0.50), n * 0.48, n * 0.46, 0, -80, 60, 0.30, el, 1.1)
    for i in range(6):
        x = n * rng.uniform(0.55, 0.85)
        light_streak(cv, (x, n * rng.uniform(0.05, 0.3)), (x, n * rng.uniform(0.55, 0.85)), n * 0.012, el, 0.5)
    shock_ring(cv, np.array([n * 0.56, n * 0.90]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.28, n * 0.05, n * 0.02, el, 0.9)
    _axe(cv, (n * 0.20, n * 0.02), (n * 0.44, n * 0.86), el, 1.15)
    hot_core(cv, n * 0.56, n * 0.88, el, 2.6, 1.1, star_len=18)


@skill("paladin.holy_light_strike", tone="holy")
def holy_light_strike(cv, rng, el):
    n = cv.n
    star = np.array([n * 0.70, n * 0.24])
    ground(cv, el, [], focus=star, focus_r=0.5, focus_k=0.7, wash=-45, rng=rng)
    crescent(cv, (n * 0.86, n * 0.92), n * 0.70, n * 0.66, 0, 170, 262, 0.34, el, 1.0)
    flare_spikes(cv, star[0], star[1], [(a, 1.0 if i % 2 == 0 else 0.55) for i, a in enumerate(range(0, 360, 30))], n * 0.03, n * 0.30, n * 0.028, el, 1.0)
    soft_light(cv, cv.ellipse(star[0], star[1], n * 0.07), "white", 1.0, R=n * 0.04, glow_r=10)
    _axe(cv, (n * 0.04, n * 1.02), (n * 0.58, n * 0.40), el, 1.25)
    hot_core(cv, star[0], star[1], "white", 3.2, 1.3, star_len=24)


@skill("paladin.rising_emblem", tone="sky")
def rising_emblem(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.86])
    ground(cv, el, [], focus=(n * 0.5, n * 0.70), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    rays = [(a, 0.6 + 0.4 * ((i * 7) % 3) / 2) for i, a in enumerate(range(-160, -10, 15))]
    flare_spikes(cv, c[0], c[1], rays, n * 0.06, n * 0.82, n * 0.03, el, 0.9)
    rune_circle(cv, c, n * 0.46, n * 0.09, el, 1.0, w=n * 0.02, star=8)
    hot_core(cv, c[0], c[1] - n * 0.02, el, 3.0, 1.2, star_len=24)


@skill("paladin.halo_smash", tone="holy")
def halo_smash(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.70])
    ground(cv, el, [(cv.poly([(0, n * 0.62), (n, n * 0.62), (n, n), (0, n)]), 1)], focus=c, focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    for i in range(10):   # the slam: speed lines above the ring
        x = n * rng.uniform(0.15, 0.85)
        light_streak(cv, (x, n * rng.uniform(0.02, 0.2)), (x, n * rng.uniform(0.45, 0.6)), n * rng.uniform(0.01, 0.02), el, 0.6)
    for k in range(9):   # glowing cracks running out of the impact
        a = math.radians(k * 40 + rng.uniform(-10, 10))
        p1 = c + np.array([math.cos(a) * n * 0.48, math.sin(a) * n * 0.14])
        crack = stroke(cv, [c + np.array([math.cos(a) * n * 0.30, math.sin(a) * n * 0.09]), (c + p1) / 2 + np.array([0, n * 0.01]), p1],
                       n * 0.014, 0.4, n=3)
        soft_light(cv, crack, el, 0.8, R=0.6, glow_r=2)
    smoke(cv, rng, [c + np.array([-n * 0.46, -n * 0.02]), c + np.array([-n * 0.2, -n * 0.10]), c + np.array([n * 0.2, -n * 0.10]),
                    c + np.array([n * 0.46, -n * 0.02])], n * 0.07, "#3A4058", 0.7)
    # the halo: a thick gold ring lying flat, painted solid, with its light bloom
    outer = cv.ellipse(c[0], c[1], n * 0.36, n * 0.12)
    inner = cv.ellipse(c[0], c[1] - n * 0.005, n * 0.27, n * 0.075)
    halo = np.clip(outer - inner, 0, 1)
    glow(cv, halo, tone(el)[1], 12, 0.8)
    material(cv, halo, "gold", R=n * 0.03, lw=(0.35, 2.0), back=tone(el)[2], back_k=1.0)
    cv.add(halo * (1 - toward(halo, 1.4, LIGHT)), "#FFFBE6", 0.5)
    for (dx, dy, s, a) in ((-0.30, -0.26, 0.05, 20), (0.32, -0.30, 0.045, -30), (0.10, -0.40, 0.035, 60), (-0.12, -0.34, 0.03, 0)):
        tr = np.array([dx, dy]) / np.linalg.norm([dx, dy])
        stone_chip(cv, rng, c[0] + n * dx, c[1] + n * dy, n * s, a, el, hot_dir=-tr, trail=tr)
    hot_core(cv, c[0], c[1] + n * 0.10, el, 2.6, 1.0, star_len=20)


@skill("paladin.recovery", tone="sky")
def recovery(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.46, n * 0.52), focus_r=0.55, focus_k=0.5, wash=-60, rng=rng)
    path = [(n * 0.92, n * 0.06), (n * 0.80, n * 0.24), (n * 0.58, n * 0.30), (n * 0.40, n * 0.44)]
    trail(cv, path, 1.0, n * 0.08, el, 0.7, core_k=0.5)
    for i in range(16):
        t = rng.uniform(0, 1)
        sp = spline(path, 8)
        p = sp[int(t * (len(sp) - 1))] + np.array([rng.uniform(-1, 1), rng.uniform(-1, 1)]) * n * 0.06
        hot_core(cv, p[0], p[1], el, rng.uniform(0.4, 0.9), 0.7, star=(i % 4 == 0), star_len=8)
    for (x, y, r) in ((0.40, 0.88, 0.20), (0.40, 0.88, 0.30)):   # soft regen rings on the ground below
        shock_ring(cv, np.array([n * x, n * y]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.25, n * 0.014, el, 0.6)
    feather(cv, (n * 0.20, n * 0.86), (n * 0.62, n * 0.22), n * 0.15, el, 1.0)
    hot_core(cv, n * 0.60, n * 0.26, "white", 2.0, 1.0, star_len=14)


@skill("paladin.holy_shield", tone="holy")
def holy_shield(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.52])
    ground(cv, "sky", [], focus=c, focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    dome = cv.ellipse(c[0], c[1], n * 0.42, n * 0.42)
    X, Y = cv.grid()
    r = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (n * 0.42)
    shell = (smoothstep(0.80, 1.0, r) * smoothstep(1.04, 0.98, r)).astype(np.float32)
    cv.add(blur(shell, 1.2), tone(el)[1], 0.8)
    cv.add(blur(dome, 6) * 0.25, tone(el)[1], 0.6)
    hexes = (0.5 + 0.5 * np.cos((X - c[0]) / n * 40) * np.cos((Y - c[1]) / n * 40)) ** 8 * dome * smoothstep(0.4, 0.95, r)
    cv.add(hexes.astype(np.float32), tone(el)[2], 0.25)
    # kite shield: white enamel face, gold rim, a gold sunburst boss
    H = H_affine(c + np.array([0, n * 0.02]), 0, n * 0.44)
    pts = closed_spline([(-0.42, -0.50), (0.0, -0.56), (0.42, -0.50), (0.44, -0.04), (0.30, 0.30), (0.0, 0.62), (-0.30, 0.30), (-0.44, -0.04)], 8)
    out = cv.poly(xf(H, pts))
    face = cv.poly(xf(H, pts * 0.84))
    ink_line(cv, out, "#3A2A10", 0.45, 2.4, 0.35)
    material(cv, np.clip(out - face, 0, 1), "gold", R=n * 0.02, line=False, back=tone(el)[2], back_k=0.6)
    material(cv, face, "ivory", R=n * 0.08, line=False, grad=0.6)
    sky_band = cv.poly(xf(H, [(-0.40, -0.16), (0.40, -0.16), (0.40, -0.04), (-0.40, -0.04)])) * face
    material(cv, sky_band, "glass", R=n * 0.01, line=False)
    boss = cv.ellipse(*xf(H, [(0.0, -0.10)])[0], n * 0.07)
    flare_spikes(cv, *xf(H, [(0.0, -0.10)])[0], [(a, 1.0) for a in range(0, 360, 45)], n * 0.06, n * 0.13, n * 0.012, el, 0.6)
    material(cv, boss, "gold", R=n * 0.04, lw=(0.3, 1.4))
    # an arrow glancing off the shield, sparks at the contact point
    hit = c + np.array([n * 0.22, -n * 0.30])
    tr = np.array([0.5, -0.86])
    cv.add(blur(stroke(cv, [hit + tr * n * 0.04, hit + tr * n * 0.36], n * 0.02, n * 0.006), 1.0), tone(el)[2], 0.6)
    shaft = stroke(cv, [hit + np.array([n * 0.08, -n * 0.03]), hit + np.array([n * 0.34, -n * 0.02])], n * 0.016, n * 0.016, n=2)
    material(cv, shaft, "wood", R=n * 0.006, lw=(0.2, 0.9))
    sparks(cv, rng, hit, 9, n * 0.12, el, 1.0)
    hot_core(cv, hit[0], hit[1], el, 2.4, 1.1, star_len=16)


@skill("paladin.life_activation", tone="sky")
def life_activation(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.80])
    ground(cv, el, [], focus=(n * 0.5, n * 0.60), focus_r=0.55, focus_k=0.6, wash=-90, rng=rng)
    for i in range(14):   # life motes rising
        x = n * rng.uniform(0.18, 0.82)
        y0 = n * rng.uniform(0.40, 0.70)
        light_streak(cv, (x, y0), (x + rng.uniform(-0.02, 0.02) * n, y0 - n * rng.uniform(0.10, 0.28)), n * 0.012, el, 0.7)
        hot_core(cv, x, y0 - n * 0.02, el, rng.uniform(0.5, 0.9), 0.7, star=False)
    for (y, r, k) in ((0.30, 0.16, 0.6), (0.18, 0.10, 0.45)):   # small rings rising off the flower
        shock_ring(cv, np.array([n * 0.5, n * y]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.3, n * 0.012, el, k)
    # the lotus: back petals (dimmer), then the front fan
    for row, (L, w, angs, val) in enumerate(((0.44, 0.16, (-150, -125, -100, -80, -55, -30), 0.75), (0.34, 0.15, (-140, -112, -90, -68, -40), 1.0))):
        for a in angs:
            ar = math.radians(a)
            d = np.array([math.cos(ar), math.sin(ar) * 0.9])
            nv = np.array([-d[1], d[0]])
            base = c + d * n * 0.02
            tip = c + d * n * L
            pet = cv.poly(closed_spline([base, base + d * n * L * 0.5 + nv * n * w * 0.5, tip, base + d * n * L * 0.5 - nv * n * w * 0.5], 6))
            light_form(cv, pet, el, 1.0, R=n * 0.035, glow_r=4, lw=(0.25, 1.4), value=val)
            cv.paint(stroke(cv, [base + d * n * 0.04, tip - d * n * 0.05], n * 0.006, 0.3) * pet, tone(el)[1], 0.5)
    pad = cv.ellipse(c[0], c[1] + n * 0.04, n * 0.40, n * 0.07)
    material(cv, pad, "glass", R=n * 0.02, lw=(0.3, 1.6))
    hot_core(cv, c[0], c[1] - n * 0.06, "white", 2.6, 1.1, star_len=18)


@skill("paladin.angels_might", tone="holy")
def angels_might(cv, rng, el):
    n = cv.n
    cool = KEY["cool"]
    c = np.array([n * 0.50, n * 0.56])
    ground(cv, "sky", [], focus=c, focus_r=0.5, focus_k=0.6, ink="#04060C", wash=-90, rng=rng)
    for i, (r, k) in enumerate(((0.44, 0.6), (0.33, 0.8), (0.22, 1.0))):   # three pulses
        shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.92, n * 0.024, el, k)
    outer = np.clip(cv.ellipse(c[0], c[1], n * 0.462, n * 0.425) - cv.ellipse(c[0], c[1], n * 0.448, n * 0.41), 0, 1)
    cv.add(blur(outer, 0.8), cool, 0.9)   # the coral rim on the outermost pulse
    for mirror in (False, True):
        wing(cv, c + np.array([(-1 if mirror else 1) * n * 0.04, -n * 0.02]), n * 0.46, -52, el, mirror=mirror, lift=1.0, primaries=6)
    core = cv.ellipse(c[0], c[1], n * 0.09)
    soft_light(cv, core, "white", 1.0, R=n * 0.05, glow_r=14)
    flare_spikes(cv, c[0], c[1], [(a, 1.0 if a % 90 == 0 else 0.5) for a in range(0, 360, 45)], n * 0.05, n * 0.30, n * 0.03, el, 0.9)
    hot_core(cv, c[0], c[1], "white", 3.4, 1.3, star_len=26)
