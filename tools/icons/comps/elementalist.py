"""元素法师 Elementalist (hooded plum robe, floating elemental orbs, staff). Plum-keyed bar: fire, frost, volt and
arcane light on a deep plum-black ground, gold trim. The four element tones are the class key itself; the bar's one
off-key accent is the key's cyan, on the ultimate's lightning rim.

Value plan:
  bolt_1              the orb staff on a rising diagonal, three arcane bolts streaking off its head      [staff]
  elemental_power     a rune circle flat on the ground, four element orbs orbiting on a tilted ring above
  piercing_lightning  one straight horizontal bolt across the frame, punching through two armour shards
  raging_flames       a tall column of fire erupting from a burning ground point, stones blown upward
  blizzard            a heavy dark storm cloud across the top, hail and ice shards slanting down out of it
  ice_line            a low wall of ice crystals running across the ground on a long diagonal
  teleport            the hooded plum robe at the left dissolving into shards that stream to a flare at the right
  heaven_earth        three lightning bolts from the top striking down into a field of earthen fire
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_swordmage import ICE, crystal, flame, lightning, rune_ring

ROBE = ["#0C0612", "#22102E", "#3A2350", "#64447E"]


def _orb(cv, x, y, r, el, k=1.0):
    m = cv.ellipse(x, y, r)
    light_form(cv, m, el, k, R=r * 0.6, glow_r=max(4.0, r * 0.6), lw=(0.25, 1.3))
    hot_core(cv, x - r * 0.25, y - r * 0.25, el, max(0.6, r / 12.0), 0.7 * k, star=False)
    return m


@skill("elementalist.bolt_1", tone="arcane")
def staff_bolt(cv, rng, el):
    n = cv.n
    mass = cv.poly([(0, n * 0.62), (n * 0.5, n * 0.98), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.66, n * 0.32), focus_r=0.5, focus_k=0.6, wash=-40, rng=rng)
    H = weapon_H((n * -0.04, n * 1.04), (n * 0.50, n * 0.50), 2.4)
    head = xf(H, [(0.89, 0.0)])[0]
    for (dx, dy), w, k in (((0.38, -0.36), 0.095, 1.0), ((0.42, -0.04), 0.07, 0.85), ((0.10, -0.42), 0.065, 0.8)):
        tip = head + np.array([dx, dy]) * n
        trail(cv, [head + (tip - head) * 0.15, head + (tip - head) * 0.6 + np.array([rng.uniform(-1, 1) * n * 0.02, 0]), tip], 0.5, n * w, el, 0.85 * k)
        _orb(cv, tip[0], tip[1], n * w * 0.7, el, k)
    pole(cv, H, el, "orb", gem=tone(el)[1])
    hot_core(cv, head[0], head[1], el, 2.0, 0.9, star_len=14)


@skill("elementalist.elemental_power", tone="arcane")
def elemental_power(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.78])
    ground(cv, el, [(cv.ellipse(c[0], c[1], n * 0.46, n * 0.15), 1)], focus=(n * 0.50, n * 0.50), focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    rune_ring(cv, c, n * 0.42, n * 0.13, el, 0.9, w=n * 0.012, ticks=24, star=8)
    for x in (0.34, 0.50, 0.66):   # the field heaving up
        light_streak(cv, (n * x, c[1]), (n * x, n * 0.30), n * 0.02, el, 0.5)
    oc = np.array([n * 0.50, n * 0.42])
    rot = math.radians(-14)
    rx, ry = n * 0.36, n * 0.13

    def at(a):
        ar = math.radians(a)
        return oc + np.array([math.cos(ar) * rx * math.cos(rot) - math.sin(ar) * ry * math.sin(rot),
                              math.cos(ar) * rx * math.sin(rot) + math.sin(ar) * ry * math.cos(rot)])
    ring = [at(a) for a in np.linspace(0, 360, 96)]
    soft_light(cv, cv.poly(ribbon(ring, [n * 0.008] * 96)), el, 0.6, R=0.8, glow_r=2)
    orbs = sorted(((math.sin(math.radians(a)), at(a), t) for a, t in ((200, "frost"), (290, "volt"), (20, "fire"), (110, "arcane"))),
                  key=lambda q: q[0])
    for depth, p, t in orbs:
        _orb(cv, p[0], p[1], n * (0.085 + 0.03 * depth), t, 0.8 + 0.2 * depth)
    for x, y, s in ((0.24, 0.64, 0.03), (0.76, 0.60, 0.028)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 90), el, trail=(0.0, -1.0))
    hot_core(cv, oc[0], oc[1] + n * 0.02, el, 2.0, 0.9, star_len=16)


@skill("elementalist.piercing_lightning", tone="volt")
def piercing_lightning(cv, rng, el):
    n = cv.n
    y = n * 0.50
    band = cv.poly([(0, n * 0.34), (n, n * 0.36), (n, n * 0.64), (0, n * 0.66)])
    ground(cv, el, [(band, 1)], focus=(n * 0.86, y), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    for x, s, a in ((0.36, 0.13, -60), (0.64, 0.11, 70)):   # two shards the bolt punches through, blown apart
        plate_fragment(cv, rng, n * x, y - n * 0.12, n * s, a, el, 1.0, trail=(0.2, -1.0))
        plate_fragment(cv, rng, n * (x + 0.04), y + n * 0.13, n * s * 0.85, a + 160, el, 1.0, trail=(0.2, 1.0))
    lightning(cv, rng, (n * -0.04, y + n * 0.02), (n * 1.0, y), n * 0.05, el, 1.0, branches=3, jag=0.08, depth=6)
    sparks(cv, rng, (n * 0.36, y), 6, n * 0.10, el, 0.7)
    sparks(cv, rng, (n * 0.64, y), 6, n * 0.10, el, 0.7)
    hot_core(cv, n * 0.90, y, el, 2.6, 1.1, star_len=22)


@skill("elementalist.raging_flames", tone="fire")
def raging_flames(cv, rng, el):
    """the 3 m fire column erupting from a burning point: a tall roaring pillar, embers and stones blown up"""
    n = cv.n
    base = np.array([n * 0.50, n * 0.92])
    low = cv.poly([(0, n * 0.82), (n, n * 0.82), (n, n), (0, n)])
    ground(cv, "arcane", [(low, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.5, wash=-90, rng=rng)
    pool = cv.ellipse(base[0], base[1] - n * 0.02, n * 0.38, n * 0.07)
    light_form(cv, pool, el, 0.8, R=n * 0.02, glow_r=8, lw=(0.3, 1.4), value=0.85)
    for x in (0.30, 0.42, 0.58, 0.70):
        light_streak(cv, (n * x, n * 0.80), (n * (0.5 + (x - 0.5) * 1.6), n * 0.04), n * 0.016, el, 0.5)
    for s in (-1, 1):
        flame(cv, (n * (0.50 + s * 0.22), base[1]), n * 0.40, n * 0.20, el, rng, lean=s * 0.35, tongues=3, k=0.85, bulb=0.6)
    flame(cv, base, n * 0.94, n * 0.40, el, rng, lean=0.0, tongues=7, k=1.0, bulb=0.45)
    for i in range(14):   # embers riding the updraft
        x = n * (0.5 + rng.normal(0, 0.16))
        y = n * rng.uniform(0.06, 0.60)
        cv.add(blur(cv.ellipse(x, y, n * rng.uniform(0.006, 0.012)), 0.5), tone(el)[2], 1.0)
    for x, y, s in ((0.12, 0.42, 0.04), (0.88, 0.38, 0.035), (0.16, 0.14, 0.03), (0.86, 0.12, 0.03)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 90), el, hot_dir=(0.5 - x, 0.5), trail=(0.0, -1.0))
    hot_core(cv, base[0], base[1] - n * 0.12, el, 2.8, 1.2, star_len=20)


@skill("elementalist.blizzard", tone="frost")
def blizzard(cv, rng, el):
    n = cv.n
    ground(cv, "arcane", [(cv.poly([(0, n * 0.84), (n, n * 0.80), (n, n), (0, n)]), 1)], focus=(n * 0.56, n * 0.70), focus_r=0.5, focus_k=0.5,
           wash=110, rng=rng)
    # the storm cloud: stacked dark puffs across the top, lit from inside at the underside
    cl = np.zeros((cv.w, cv.w), np.float32)
    for x, y, r in ((0.06, 0.14, 0.16), (0.24, 0.10, 0.18), (0.44, 0.14, 0.20), (0.66, 0.10, 0.18), (0.88, 0.14, 0.17), (0.16, 0.28, 0.13),
                    (0.36, 0.30, 0.14), (0.58, 0.30, 0.15), (0.80, 0.28, 0.14)):
        np.maximum(cl, cv.ellipse(n * x, n * y, n * r, n * r * 0.8), out=cl)
    ink_line(cv, cl, "#04060C", 0.4, 2.2, 0.3)
    paint_form(cv, cl, ["#06080E", "#121A2A", "#26344E", "#46607E"], R=n * 0.06, grad=0.6, thr=[0.25, 0.55, 0.85])
    X, Y = cv.grid()
    under = cl * smoothstep(n * 0.26, n * 0.40, Y)
    cv.add(blur(under, 2), tone(el)[1], 0.35)
    for i in range(16):   # hail and shards slanting down-left
        x = rng.uniform(0.05, 1.05) * n
        y = rng.uniform(0.36, 0.90) * n
        L = n * rng.uniform(0.08, 0.18)
        a = math.radians(115)
        d = np.array([math.cos(a), math.sin(a)])
        light_streak(cv, (x - d[0] * L, y - d[1] * L), (x, y), n * 0.008, el, 0.5)
        if i % 2 == 0:
            crystal(cv, (x - d[0] * n * 0.02, y - d[1] * n * 0.02), 115, n * rng.uniform(0.045, 0.07), n * 0.025, glow_c=tone(el)[1])
    for x in (0.20, 0.46, 0.74):   # hail hitting the ground
        shock_ring(cv, np.array([n * x, n * 0.90]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.08, n * 0.02, n * 0.008, el, 0.6)
    hot_core(cv, n * 0.46, n * 0.90, el, 1.8, 0.9, star_len=14)


@skill("elementalist.ice_line", tone="frost")
def ice_line(cv, rng, el):
    """a long low wall of ice drawn across the ground: uneven crystal clusters frozen along a glowing line"""
    n = cv.n
    ground(cv, "arcane", [(cv.poly([(0, n * 0.50), (n, n * 0.30), (n, n), (0, n)]), 1)], focus=(n * 0.50, n * 0.60), focus_r=0.5, focus_k=0.5,
           wash=-20, rng=rng)
    p0, p1 = np.array([n * 0.02, n * 0.86]), np.array([n * 1.0, n * 0.40])
    band = cv.poly(ribbon([p0, p1], [n * 0.16, n * 0.05]))
    paint_form(cv, blur(band, 3), ["#0A1A2A", "#1E4A6A", "#3E86A8", "#9FE4F4"], R=n * 0.05, grad=0.5, alpha=0.6)
    soft_light(cv, cv.poly(ribbon([p0, p1], [n * 0.02, n * 0.008])), el, 0.9, R=0.8, glow_r=4)
    for t, sc in ((0.92, 0.5), (0.74, 0.7), (0.52, 0.9), (0.28, 1.1), (0.06, 1.3)):   # clusters, far to near
        p = p0 + (p1 - p0) * t
        for a, h, w in ((-90, 0.22, 0.08), (-118, 0.13, 0.05), (-62, 0.15, 0.055), (-140, 0.08, 0.035), (-40, 0.09, 0.035)):
            hh = n * h * sc * rng.uniform(0.8, 1.15)
            crystal(cv, p + np.array([math.cos(math.radians(a)) * hh * 0.1, n * 0.01]), a + rng.uniform(-8, 8), hh, n * w * sc,
                    glow_c=tone(el)[1])
    hot_core(cv, n * 0.30, n * 0.56, el, 2.2, 1.0, star_len=16)


@skill("elementalist.teleport", tone="arcane")
def teleport(cv, rng, el):
    """the hooded robe at the left breaks into shards that stream right and re-form in a flare"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.80, n * 0.40), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    X, Y = cv.grid()
    robe = cv.poly(closed_spline([(n * 0.30, n * 0.12), (n * 0.40, n * 0.18), (n * 0.44, n * 0.32), (n * 0.50, n * 0.62), (n * 0.56, n * 0.96),
                                  (n * 0.30, n * 1.02), (n * 0.04, n * 0.96), (n * 0.12, n * 0.62), (n * 0.18, n * 0.32), (n * 0.22, n * 0.18)], 6))
    nz = (lowfreq(cv.w, 18, 3) - 0.5) * 0.22
    dissolve = smoothstep(0.32, 0.40, X / n + nz)
    body = robe * (1 - dissolve)
    ink_line(cv, body, "#05020A", 0.4, 2.2, 0.3)
    folds = 0.2 * np.sin(X / n * 26.0 + Y / n * 4.0) * smoothstep(0.3, 1.0, Y / n)
    paint_form(cv, body, ROBE, R=n * 0.05, grad=0.6, field=folds, thr=[0.2, 0.5, 0.82], soft=0.1)
    hood = cv.ellipse(n * 0.28, n * 0.30, n * 0.06, n * 0.08) * body
    cv.paint(blur(hood, 1.0), "#030106", 0.95)
    hem = cv.poly(ribbon([(n * 0.04, n * 0.95), (n * 0.30, n * 1.0), (n * 0.56, n * 0.95)], [n * 0.03] * 3)) * body
    material(cv, hem, "gold", R=n * 0.01, line=False)
    trim = cv.poly(ribbon([(n * 0.22, n * 0.20), (n * 0.30, n * 0.42), (n * 0.30, n * 0.98)], [n * 0.02] * 3)) * body
    material(cv, trim, "gold", R=n * 0.008, line=False)
    edge = np.clip(body - toward(body, 1.4, (-1.0, 0.0)), 0, 1) * dilate(dissolve, 0.8)
    cv.add(blur(edge, 1.0), tone(el)[1], 0.9)
    cv.add(edge, tone(el)[2], 0.5)
    dest = np.array([n * 0.80, n * 0.42])
    for i in range(24):   # shards streaming to the destination
        t = rng.uniform(0, 1)
        start = np.array([n * rng.uniform(0.34, 0.50), n * rng.uniform(0.20, 0.92)])
        p = start + (dest - start) * t ** 0.8
        s = n * rng.uniform(0.010, 0.024) * (1 - 0.5 * t)
        d = (dest - start) / np.linalg.norm(dest - start)
        nv = np.array([-d[1], d[0]])
        sh = cv.poly([p - d * s * 1.6, p + nv * s * 0.6, p + d * s, p - nv * s * 0.5])
        light_streak(cv, p - d * s * 6, p, s * 0.5, el, 0.4)
        if i % 2:
            material(cv, sh, "lacquer", R=max(0.6, s * 0.3), lw=(0.2, 0.6), back=tone(el)[2], back_k=0.9)
        else:
            light_form(cv, sh, el, 0.8, R=max(0.6, s * 0.3), glow_r=2, lw=(0.2, 0.8))
    shock_ring(cv, dest + np.array([0, n * 0.30]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.14, n * 0.04, n * 0.012, el, 0.8)
    flare_spikes(cv, dest[0], dest[1], [(-90, 1.0), (90, 0.9), (0, 0.6), (180, 0.5)], n * 0.02, n * 0.24, n * 0.03, el, 0.9)
    hot_core(cv, dest[0], dest[1], el, 2.6, 1.1, star_len=20)


@skill("elementalist.heaven_earth", tone="volt")
def heaven_earth(cv, rng, el):
    """天雷地火: three bolts from a dark sky striking a ground of earthen fire"""
    n = cv.n
    ground(cv, "arcane", [], focus=(n * 0.50, n * 0.80), focus_r=0.55, focus_k=0.7, ink="#05030A", wash=-90, rng=rng)
    cl = np.zeros((cv.w, cv.w), np.float32)
    for x, y, r in ((0.10, 0.06, 0.18), (0.34, 0.02, 0.20), (0.62, 0.04, 0.20), (0.90, 0.06, 0.18)):
        np.maximum(cl, cv.ellipse(n * x, n * y, n * r, n * r * 0.6), out=cl)
    paint_form(cv, cl, ["#05040A", "#100C1C", "#22183A", "#3A2A5A"], R=n * 0.06, grad=0.6)
    for x in (0.10, 0.28, 0.46, 0.64, 0.82, 0.98):   # earthen fire along the ground
        flame(cv, (n * x, n * 1.02), n * rng.uniform(0.26, 0.38), n * 0.20, "fire", rng, lean=0.0, tongues=4, k=0.9)
    hits = []
    for x0, x1, w in ((0.18, 0.24, 0.035), (0.80, 0.74, 0.035), (0.52, 0.50, 0.05)):
        lightning(cv, rng, (n * x0, n * 0.04), (n * x1, n * 0.80), n * w, el, 1.0, branches=2, jag=0.16)
        hits.append((n * x1, n * 0.80))
    for hx, hy in hits:
        hot_core(cv, hx, hy, "fire", 1.8, 0.9, star_len=14)
    hot_core(cv, n * 0.50, n * 0.80, el, 3.0, 1.2, star_len=24)

    def bleed(c2):
        # the bar's one off-key accent: a cyan rim of cold light along the centre bolt's top
        m = c2.poly(ribbon([(n * 0.52, n * 0.06), (n * 0.51, n * 0.30)], [n * 0.02, 0.4]))
        c2.add(blur(m, 1.5), KEY["cool"], 0.7)
    return {"bleed": bleed}
