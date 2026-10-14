"""召唤师 Summoner (book on a chain, small floating spirits, ring staff). Green-teal keyed bar: spirit jade, thorn green
and cream on a deep green-black ground, gold trim. The bar's one off-key accent is coral, on 魔界之花's petals.

Value plan:
  staff_1           the ring staff upright at the left, a chain of three spirit bolts streaking right     [staff]
  thorn             four huge curved thorns erupting from a ground crack, a shard launched off the tallest
  goblin            a scowling long-eared goblin head rising out of a summoning circle (wide horizontal ears)
  elemental_spirit  one spirit-flame at the centre, four small element motifs orbiting it on a ring
  demon_flowers     a carnivorous flower head with a fanged maw spitting poison, thorny stem (coral accent)
  mark              a four-point star sigil in a ring over a cracked plate, three pet strikes converging
  switch            the chained grimoire at the centre, two swap arcs circling it in opposite directions
  spirit_sacrifice  four spirit comets diving into a rune circle that detonates in one column
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_swordmage import crystal, droplet, flame, lightning, rune_ring

SKIN = ["#0C1606", "#2A4A14", "#5A8A2A", "#A8D06A"]
BARK = ["#0A1206", "#1E3410", "#3E6A22", "#86B456"]
CORAL = ["#3A0A08", "#9A3A2A", "#FF8A6A", "#FFDCCC"]
POISON = ["#0A2006", "#2A6A14", "#7AD03A", "#E6FFB0"]


def _orb(cv, x, y, r, el, k=1.0):
    m = cv.ellipse(x, y, r)
    light_form(cv, m, el, k, R=r * 0.6, glow_r=max(4.0, r * 0.6), lw=(0.25, 1.3))
    hot_core(cv, x - r * 0.25, y - r * 0.25, el, max(0.6, r / 12.0), 0.7 * k, star=False)
    return m


def _thorn(cv, base, tip, ctrl, w, rng):
    """a huge curved thorn: bark-green ribbon tapering to a point, small side spines, a lit back rim"""
    n = cv.n
    path = spline([base, ctrl, tip], 10)
    m = cv.poly(ribbon(path, lambda u: w * (1 - u) ** 0.9 + 0.4))
    spines = []
    for t in (0.3, 0.5, 0.7):
        i = int(t * (len(path) - 1))
        d = path[min(len(path) - 1, i + 1)] - path[i]
        d = d / (np.linalg.norm(d) + 1e-9)
        nv = np.array([-d[1], d[0]]) * (1 if t != 0.5 else -1)
        hw = w * (1 - t) * 0.5
        p = path[i] + nv * hw
        spines.append(cv.poly([p - d * w * 0.15, p + nv * w * 0.45 + d * w * 0.25, p + d * w * 0.15]))
    allm = union(cv, [m] + spines)
    ink_line(cv, allm, "#050A02", 0.35, 2.0, 0.35)
    paint_form(cv, allm, BARK, R=w * 0.35, grad=0.5)
    f = streak_field(cv.w, math.degrees(math.atan2(tip[1] - base[1], tip[0] - base[0])), 100, 5, cv.seed())
    sl = bbox(allm, 2)
    if sl is not None:
        cv.c[sl] *= (1 + 0.15 * (f[sl] - 0.5) * 2 * allm[sl])[..., None]
    cv.add(np.clip(allm - toward(allm, 1.4, LIGHT), 0, 1), tone("spirit")[1], 0.6)
    tipm = cv.poly(ribbon(path[-4:], lambda u: max(0.4, w * 0.12 * (1 - u))))
    cv.paint(tipm, "#E8E0C0", 0.7)
    return allm


@skill("summoner.staff_1", tone="spirit")
def staff_bolt(cv, rng, el):
    n = cv.n
    mass = cv.poly([(0, n * 0.3), (n * 0.34, n * 0.3), (n * 0.40, n), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.80, n * 0.40), focus_r=0.5, focus_k=0.6, wash=-10, rng=rng)
    H = weapon_H((n * 0.10, n * 1.06), (n * 0.30, n * 0.12), 2.0)
    head = xf(H, [(0.86, 0.0)])[0]
    orbs = ((0.88, 0.42, 0.095), (0.64, 0.32, 0.072), (0.46, 0.27, 0.055))
    prev = head
    for x, y, r in orbs:
        p = np.array([n * x, n * y])
        trail(cv, [prev + (p - prev) * 0.1, (prev + p) / 2 + np.array([0, -n * 0.03]), p], 0.4, n * r * 1.1, el, 0.85)
        prev = p
    for i, (x, y, r) in enumerate(orbs):
        _orb(cv, n * x, n * y, n * r, el if i != 1 else "cream", 1.0 - 0.1 * i)
    pole(cv, H, el, "ring", gem=tone(el)[1])
    hot_core(cv, n * 0.88, n * 0.42, el, 2.4, 1.0, star_len=18)


@skill("summoner.thorn", tone="thorn")
def thorn(cv, rng, el):
    """three huge curved brambles erupt from a ground crack, hooked spines along them, a shard tossed off the top"""
    n = cv.n
    low = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.6, wash=-80, rng=rng)
    crack = cv.ellipse(n * 0.50, n * 0.88, n * 0.38, n * 0.07)
    glow(cv, crack, tone(el)[1], 8, 0.8)
    cv.paint(crack, "#030602")
    for base, tip, ctrl, w in (((0.26, 0.92), (0.06, 0.34), (0.30, 0.56), 0.17), ((0.76, 0.92), (0.96, 0.40), (0.72, 0.58), 0.17),
                               ((0.50, 0.94), (0.56, 0.06), (0.40, 0.48), 0.22)):
        _thorn(cv, np.array(base) * n, np.array(tip) * n, np.array(ctrl) * n, n * w, rng)
    for x, y, s in ((0.18, 0.86, 0.03), (0.84, 0.84, 0.03)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 90), el)
    plate_fragment(cv, rng, n * 0.80, n * 0.12, n * 0.11, 20, "spirit", 0.9, trail=(-0.2, -1.0))
    hot_core(cv, n * 0.50, n * 0.88, el, 2.4, 1.0, star_len=18)


@skill("summoner.goblin", tone="spirit")
def goblin(cv, rng, el):
    """a scowling goblin rising out of the summoning circle: long ears, heavy brow, hooked nose, one tusk"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.54), focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    c = np.array([n * 0.50, n * 0.88])
    X, Y = cv.grid()
    col_m = cv.poly([(n * 0.18, c[1]), (n * 0.30, n * 0.04), (n * 0.70, n * 0.04), (n * 0.82, c[1])])
    cv.add(blur(col_m, 8) * smoothstep(0, n, Y), tone(el)[1], 0.35)
    rune_ring(cv, c, n * 0.42, n * 0.10, el, 0.9, w=n * 0.012, ticks=20, star=5)
    ears = []
    for s in (-1, 1):
        pts = [(n * (0.50 + s * 0.15), n * 0.44), (n * (0.50 + s * 0.30), n * 0.38), (n * (0.50 + s * 0.46), n * 0.26)]
        ears.append(cv.poly(ribbon(spline(pts, 8), lambda u: n * 0.15 * (1 - u) ** 0.8 + 0.5)))
    em = union(cv, ears)
    ink_line(cv, em, "#060C02", 0.35, 2.0, 0.3)
    paint_form(cv, em, SKIN, R=n * 0.03, grad=0.5)
    for s in (-1, 1):   # inner ear
        inner = cv.poly(ribbon(spline([(n * (0.50 + s * 0.20), n * 0.43), (n * (0.50 + s * 0.31), n * 0.385), (n * (0.50 + s * 0.42), n * 0.30)], 6),
                               lambda u: n * 0.06 * (1 - u) + 0.4)) * em
        cv.paint(blur(inner, 0.6), "#1A2A0C", 0.8)
    ring = np.clip(cv.ellipse(n * 0.86, n * 0.36, n * 0.03) - cv.ellipse(n * 0.86, n * 0.36, n * 0.016), 0, 1)
    material(cv, ring, "gold", R=n * 0.008, lw=(0.2, 0.8))
    head = cv.poly(closed_spline([(n * 0.50, n * 0.20), (n * 0.64, n * 0.26), (n * 0.69, n * 0.44), (n * 0.64, n * 0.64), (n * 0.50, n * 0.76),
                                  (n * 0.36, n * 0.64), (n * 0.31, n * 0.44), (n * 0.36, n * 0.26)], 6))
    ink_line(cv, head, "#060C02", 0.4, 2.4, 0.3)
    paint_form(cv, head, SKIN, R=n * 0.08, grad=0.6)
    cv.add(np.clip(head - toward(head, 1.6, LIGHT), 0, 1), tone(el)[1], 0.5)
    cap = cv.poly(closed_spline([(n * 0.32, n * 0.34), (n * 0.36, n * 0.22), (n * 0.50, n * 0.15), (n * 0.64, n * 0.22), (n * 0.68, n * 0.34),
                                 (n * 0.50, n * 0.31)], 5))   # a dented iron skullcap with a riveted band
    material(cv, cap, "darksteel", R=n * 0.04, lw=(0.35, 2.0), grad=0.5, back=tone(el)[1], back_k=0.7)
    band = cv.poly(ribbon(spline([(n * 0.32, n * 0.33), (n * 0.50, n * 0.30), (n * 0.68, n * 0.33)], 6), [n * 0.03] * 3)) * dilate(cap, 0.5)
    material(cv, band, "bronze", R=n * 0.01, lw=(0.2, 0.9))
    for x in (0.38, 0.50, 0.62):
        rv = cv.ellipse(n * x, n * (0.315 + abs(x - 0.5) * 0.08), n * 0.009)
        material(cv, rv, "gold", R=n * 0.004, line=False)
    dent = cv.poly(ribbon([(n * 0.55, n * 0.20), (n * 0.59, n * 0.26)], [n * 0.012] * 2)) * cap
    cv.paint(dent, "#030306", 0.8)
    brow = cv.poly(ribbon(spline([(n * 0.34, n * 0.38), (n * 0.46, n * 0.44), (n * 0.50, n * 0.45), (n * 0.54, n * 0.44), (n * 0.66, n * 0.38)], 6),
                          [n * 0.05, n * 0.06, n * 0.05, n * 0.06, n * 0.05])) * head
    paint_form(cv, brow, SKIN[:3] + ["#7AA84A"], R=n * 0.02, grad=0.5, tilt=(0.0, -0.5))
    for x in (0.43, 0.57):   # small glowing eyes under the brow
        e = cv.poly([(n * (x - 0.04), n * 0.47), (n * x, n * 0.462), (n * (x + 0.04), n * 0.47), (n * x, n * 0.485)])
        cv.paint(dilate(e, 0.8) * head, "#050A02")
        glow(cv, e, "#E6FF9A", 2, 0.8)
        cv.add(e, "#F6FFD0", 1.0)
    nose = cv.poly(closed_spline([(n * 0.48, n * 0.46), (n * 0.52, n * 0.46), (n * 0.55, n * 0.56), (n * 0.53, n * 0.62), (n * 0.47, n * 0.62),
                                  (n * 0.45, n * 0.56)], 5))
    ink_line(cv, nose, "#060C02", 0.3, 1.6, 0.3)
    paint_form(cv, nose, SKIN, R=n * 0.025, grad=0.5, tilt=(-0.1, 0.2))
    mouth = cv.poly(ribbon(spline([(n * 0.41, n * 0.70), (n * 0.46, n * 0.67), (n * 0.54, n * 0.67), (n * 0.59, n * 0.70)], 6), [n * 0.012] * 4))
    cv.paint(mouth * head, "#050A02", 0.95)
    tusk = stroke(cv, [(n * 0.56, n * 0.70), (n * 0.575, n * 0.65), (n * 0.56, n * 0.60)], n * 0.03, 0.4)
    material(cv, tusk, "bone", R=n * 0.006, lw=(0.2, 0.8))
    hot_core(cv, c[0], c[1], el, 2.0, 0.9, star_len=18)


@skill("summoner.elemental_spirit", tone="spirit")
def elemental_spirit(cv, rng, el):
    """the spirit at the centre, its four forms (thunder, fire, ice, dark) orbiting it as motifs"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.6, wash=-60, rng=rng)
    ring = cv.poly(ribbon(arc_pts(c[0], c[1], n * 0.36, 0, 360, 96), [n * 0.008] * 96))
    soft_light(cv, ring, "cream", 0.5, R=0.8, glow_r=2)
    flame(cv, (n * 0.50, n * 0.66), n * 0.40, n * 0.22, el, rng, tongues=4, k=1.0, bulb=1.2)
    hot_core(cv, n * 0.49, n * 0.52, "cream", 2.2, 1.0, star_len=16)
    lightning(cv, rng, (n * 0.42, n * 0.02), (n * 0.56, n * 0.26), n * 0.04, "cream", 1.0, branches=0, jag=0.35, depth=3)
    flame(cv, (n * 0.86, n * 0.64), n * 0.26, n * 0.15, "thorn", rng, tongues=3, k=0.95)
    crystal(cv, (n * 0.52, n * 0.98), -84, n * 0.18, n * 0.07, glow_c=tone(el)[1])
    crystal(cv, (n * 0.47, n * 0.97), -116, n * 0.12, n * 0.05, glow_c=tone(el)[1])
    vo = cv.ellipse(n * 0.14, n * 0.50, n * 0.09)
    glow(cv, vo, tone(el)[1], 5, 0.8)
    material(cv, vo, "lacquer", R=n * 0.03, lw=(0.3, 1.4))
    rim = np.clip(vo - toward(vo, 3.5, (-0.7, 0.7)), 0, 1)
    cv.add(blur(rim, 0.6), tone("cream")[2], 0.9)


@skill("summoner.demon_flowers", tone="thorn")
def demon_flowers(cv, rng, el):
    """魔界之花: a carnivorous flower turret, hooked coral petals around a wide fanged maw spitting poison
    (coral: the bar's one off-key accent)"""
    n = cv.n
    ground(cv, el, [(cv.poly([(0, n * 0.86), (n, n * 0.86), (n, n), (0, n)]), 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.6,
           wash=-60, rng=rng)
    stem = cv.poly(ribbon(spline([(n * 0.36, n * 1.02), (n * 0.44, n * 0.84), (n * 0.36, n * 0.68), (n * 0.42, n * 0.52)], 8),
                          [n * 0.08, n * 0.07, n * 0.07, n * 0.06]))
    ink_line(cv, stem, "#050A02", 0.35, 2.0, 0.3)
    paint_form(cv, stem, BARK, R=n * 0.02, grad=0.5)
    for (x, y, a) in ((0.26, 0.88, 200), (0.50, 0.80, -20)):   # spiked leaves
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        p = np.array([n * x, n * y])
        lf = cv.poly(ribbon(spline([p, p + d * n * 0.13 + np.array([0, -n * 0.05]), p + d * n * 0.28], 6), lambda u: n * 0.08 * math.sin(math.pi * u) + 0.4))
        ink_line(cv, lf, "#050A02", 0.3, 1.5, 0.3)
        paint_form(cv, lf, SKIN, R=n * 0.02, grad=0.5)
    c = np.array([n * 0.46, n * 0.38])
    petals = []
    for i in range(6):
        a = math.radians(i * 60 + 30)
        d = np.array([math.cos(a), math.sin(a) * 0.9])
        nv = np.array([-d[1], d[0]])
        p0 = c + d * n * 0.12
        p1 = c + d * n * 0.40 + nv * n * 0.08   # hooked: the petal tips curl sideways like claws
        pts = spline([p0, c + d * n * 0.28 + nv * n * 0.01, p1], 6)
        petals.append(cv.poly(ribbon(pts, lambda u: n * 0.17 * (1 - u) ** 0.8 * min(1, u * 4 + 0.4) + 0.4)))
    for pm in petals:
        ink_line(cv, pm, "#2A0604", 0.35, 1.8, 0.35)
        paint_form(cv, pm, CORAL, R=n * 0.04, grad=0.5)
        cv.paint(np.clip(pm - toward(pm, 1.6, LIGHT), 0, 1), CORAL[0], 0.5)
    maw = cv.ellipse(c[0], c[1], n * 0.16, n * 0.14)
    ink_line(cv, maw, "#1A0402", 0.5, 2.4, 0.2)
    paint_form(cv, maw, ["#050102", "#1A0406", "#3A0A10", "#6A1A1A"], R=n * 0.06, grad=0.3, tilt=(0.4, 0.5))
    glow(cv, cv.ellipse(c[0] + n * 0.02, c[1] + n * 0.02, n * 0.06), POISON[2], 4, 1.0)
    cv.add(cv.ellipse(c[0] + n * 0.02, c[1] + n * 0.02, n * 0.035), POISON[3], 0.6)
    for i in range(12):   # narrow curved fangs ringing the maw, pointing inward
        a = math.radians(i * 30 + 8)
        d = np.array([math.cos(a), math.sin(a) * 0.88])
        p = c + d * n * 0.15
        nv = np.array([-d[1], d[0]])
        L = n * (0.07 if i % 2 else 0.05)
        fm = stroke(cv, [p, p - d * L * 0.6 + nv * L * 0.2, p - d * L], n * 0.024, 0.4)
        material(cv, fm, "bone", R=n * 0.006, lw=(0.2, 0.8))
    for x, y, r in ((0.70, 0.30, 0.04), (0.84, 0.22, 0.032), (0.94, 0.16, 0.024)):   # poison globs spat out of the maw
        droplet(cv, n * x, n * y, n * r, -30, POISON, "#051002", glow_c=POISON[2])
    hot_core(cv, c[0] + n * 0.02, c[1] + n * 0.02, el, 1.6, 0.9, star_len=12)


@skill("summoner.mark", tone="cream")
def mark(cv, rng, el):
    """the command mark: a four-point star sigil in a ring, armour shards breaking off under it, three pet strikes
    converging on it"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.46])
    ground(cv, "spirit", [], focus=c, focus_r=0.5, focus_k=0.6, wash=-45, rng=rng)
    for start, ctrl in (((0.0, 1.0), (0.12, 0.72)), ((1.0, 1.0), (0.88, 0.72)), ((0.0, 0.04), (0.14, 0.18)), ((1.0, 0.06), (0.86, 0.20))):
        trail(cv, [tuple(np.array(start) * n), tuple(np.array(ctrl) * n), tuple(c + (np.array(ctrl) * n - c) * 0.42)], 0.4, n * 0.04, "spirit", 0.8)
    for x, y, s, a in ((0.36, 0.86, 0.09, 200), (0.62, 0.90, 0.08, -20), (0.50, 0.78, 0.06, 90)):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, "spirit", 0.8, trail=(0.0, 1.0))
    ring = cv.poly(ribbon(arc_pts(c[0], c[1], n * 0.26, 0, 360, 96), [n * 0.016] * 96))
    soft_light(cv, ring, el, 0.9, R=0.8, glow_r=3)
    inner = cv.poly(ribbon(arc_pts(c[0], c[1], n * 0.20, 0, 360, 96), [n * 0.008] * 96))
    soft_light(cv, inner, "spirit", 0.8, R=0.6, glow_r=2)
    star = []
    for k in range(8):
        a = math.radians(-90 + k * 45)
        r = n * (0.40 if k % 4 == 0 else (0.30 if k % 2 == 0 else 0.065))
        star.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
    sm = cv.poly(star)
    light_form(cv, sm, el, 1.0, R=n * 0.03, glow_r=8, lw=(0.3, 1.6))
    hot_core(cv, c[0], c[1], el, 2.6, 1.1, star_len=20)


@skill("summoner.switch", tone="spirit")
def switch(cv, rng, el):
    """the chained grimoire at the centre; two swap arcs circle it in opposite directions"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.6, wash=-30, rng=rng)
    crescent(cv, c, n * 0.40, n * 0.40, 30, 170, 330, 0.26, el, 1.0)
    crescent(cv, c, n * 0.40, n * 0.40, 30, -10, 150, 0.26, "cream", 0.9)
    for a, t in ((330, el), (150, "cream")):
        ar = math.radians(a + 30)
        p = c + np.array([math.cos(ar), math.sin(ar)]) * n * 0.40
        _orb(cv, p[0], p[1], n * 0.055, t, 1.0)
    cover = cv.poly([(n * 0.34, n * 0.34), (n * 0.62, n * 0.30), (n * 0.68, n * 0.62), (n * 0.40, n * 0.68)])
    pages = cv.poly([(n * 0.40, n * 0.68), (n * 0.68, n * 0.62), (n * 0.69, n * 0.65), (n * 0.41, n * 0.71)])
    paint_form(cv, pages, ["#5A4A30", "#B8A47E", "#F2E6C8", "#FFFFFF"], R=n * 0.01, grad=0.4)
    ink_line(cv, pages, "#2A1E0A", 0.2, 1.0, 0.3)
    material(cv, cover, "leather", R=n * 0.04, lw=(0.4, 2.2), grad=0.5, back=tone(el)[1], back_k=0.8)
    for (x, y) in ((0.34, 0.34), (0.62, 0.30), (0.68, 0.62), (0.40, 0.68)):
        cm = cv.ellipse(n * x, n * y, n * 0.035) * dilate(cover, 0.5)
        material(cv, cm, "gold", R=n * 0.01, line=False)
    emb = cv.poly([(n * 0.51, n * 0.40), (n * 0.56, n * 0.49), (n * 0.51, n * 0.58), (n * 0.46, n * 0.49)])
    glow(cv, emb, tone(el)[1], 3, 0.9)
    cv.add(emb, tone(el)[2], 0.9)
    clasp = cv.poly([(n * 0.64, n * 0.44), (n * 0.71, n * 0.43), (n * 0.72, n * 0.49), (n * 0.65, n * 0.50)])
    material(cv, clasp, "gold", R=n * 0.01, lw=(0.25, 1.0))
    p = np.array([n * 0.37, n * 0.68])
    for i in range(6):   # the chain dropping from the spine
        q = p + np.array([-n * 0.02 * i, n * 0.045 * i])
        if i % 2 == 0:
            lk = np.clip(cv.ellipse(q[0], q[1], n * 0.016, n * 0.026) - cv.ellipse(q[0], q[1], n * 0.007, n * 0.016), 0, 1)
        else:
            lk = cv.ellipse(q[0], q[1], n * 0.007, n * 0.026)
        material(cv, lk, "gold", R=n * 0.005, lw=(0.2, 0.8))
    hot_core(cv, n * 0.51, n * 0.49, el, 1.6, 0.8, star_len=12)


@skill("summoner.spirit_sacrifice", tone="spirit")
def spirit_sacrifice(cv, rng, el):
    """every spirit dives into the rune at once; it detonates in one column"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.76])
    ground(cv, el, [(cv.ellipse(c[0], c[1], n * 0.48, n * 0.16), 1)], focus=(n * 0.50, n * 0.56), focus_r=0.55, focus_k=0.8, ink="#020604",
           wash=-90, rng=rng)
    rune_ring(cv, c, n * 0.44, n * 0.14, el, 1.0, w=n * 0.014, ticks=28, star=7)
    X, Y = cv.grid()
    col_m = cv.poly([(n * 0.36, c[1]), (n * 0.42, n * 0.0), (n * 0.58, n * 0.0), (n * 0.64, c[1])])
    soft_light(cv, blur(col_m, 4), el, 0.8, R=n * 0.06, glow_r=10, core_k=0.8)
    for start, ctrl, t in (((0.02, 0.10), (0.14, 0.40), "cream"), ((0.98, 0.08), (0.86, 0.36), "thorn"), ((0.0, 0.60), (0.20, 0.50), el),
                           ((1.0, 0.56), (0.80, 0.46), "cream")):
        head = c + (np.array(ctrl) * n - c) * 0.45 + np.array([0, -n * 0.06])
        trail(cv, [tuple(np.array(start) * n), tuple(np.array(ctrl) * n), tuple(head)], 0.5, n * 0.06, t, 0.9)
        _orb(cv, head[0], head[1], n * 0.045, t, 1.0)
    burst(cv, rng, (c[0], c[1] - n * 0.12), n * 0.16, el, 1.0, smoke_k=0.0, puffs=8, core=False)
    flare_spikes(cv, c[0], c[1] - n * 0.12, [(-90, 1.0), (-60, 0.5), (-120, 0.5), (0, 0.4), (180, 0.4)], n * 0.04, n * 0.50, n * 0.035, el, 0.9)
    hot_core(cv, c[0], c[1] - n * 0.12, el, 3.0, 1.2, star_len=24)
