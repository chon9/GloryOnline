"""盗贼 Thief (匕首 dagger). Green-keyed bar: toxic green, leather tan, trap frost, brass trap plates.
The bar's one off-key accent is fire orange, on 火焰陷阱 (the inferno trap's element demands it).

Value plan (one big greyscale shape each):
  atk1              a dagger on a rising diagonal, a short quick slash smear across its tip           [dagger]
  spike_trap        LOW DISC + FAN: a brass trap plate in perspective, steel spikes springing up out of it
  poison_gas_trap   BIG ROUND CLOUD: a toxic green billow swelling off a small vented canister
  inferno_trap      FLAME PILLAR: a column of fire roaring up off a trap plate (fire orange)
  shadow_trap       PORTAL + LOOP: a dark ring on the floor, a return trail looping out of the dark and back in
  stealth           HOOD: an empty hooded cloak dissolving into smoke from the hem up
  ambush            DARK MASS + STAB: a dagger lunging down out of a shadow mass into a hot point      [dagger]
  ice_trap          CRYSTAL CLUSTER: ice shards erupting from a wide frost ring (ULT)
The dagger appears in 2 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_night import short_blade, dizzy_stars, billow  # noqa: F401


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _dagger(cv, butt, tip, el, w=1.0):
    return short_blade(cv, weapon_H(butt, tip, w), el, width=0.07, blade_from=0.36, guard_mat="brass", grip_mat="leather",
                       kind="dagger")


def _plate(cv, c, rx, ry, el, teeth=12, vents=0):
    """trap plate in perspective: a brass disc with a dark rim side, toothed jaw ring, rivets, dark centre plate"""
    pal = tone(el)
    c = np.asarray(c, float)
    side = np.clip(cv.ellipse(c[0], c[1] + ry * 0.35, rx, ry) - cv.ellipse(c[0], c[1], rx, ry), 0, 1)
    top = cv.ellipse(c[0], c[1], rx, ry)
    allm = union(cv, [side, top])
    ink_line(cv, allm, "#140A04", 0.4, 2.2, 0.4)
    paint_form(cv, side, ["#1A0E04", "#3A2408", "#6A4A1A"], R=ry * 0.2, grad=0.5)
    material(cv, top, "brass", R=ry * 0.5, line=False, tilt=(0.0, -0.4), back=pal[2], back_k=0.5)
    inner = cv.ellipse(c[0], c[1], rx * 0.62, ry * 0.62)
    material(cv, inner, "darksteel", R=ry * 0.3, lw=(0.3, 1.2), tilt=(0.0, -0.3))
    for i in range(teeth):   # serrated jaw teeth around the inner plate
        a = 2 * math.pi * i / teeth
        p0 = c + np.array([math.cos(a) * rx * 0.62, math.sin(a) * ry * 0.62])
        p1 = c + np.array([math.cos(a) * rx * 0.80, math.sin(a) * ry * 0.80])
        q = c + np.array([math.cos(a + 0.18) * rx * 0.64, math.sin(a + 0.18) * ry * 0.64])
        tm = cv.poly([p0, p1, q])
        material(cv, tm, "steel", R=1.0, lw=(0.2, 0.7), spec=False)
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        p = c + np.array([math.cos(a) * rx * 0.9, math.sin(a) * ry * 0.9])
        cv.paint(cv.ellipse(p[0], p[1], rx * 0.035), "#2A1A08")
        cv.paint(cv.ellipse(p[0] - rx * 0.008, p[1] - rx * 0.008, rx * 0.02), "#FFE7A0", 0.8)
    for i in range(vents):
        a = 2 * math.pi * i / vents
        p = c + np.array([math.cos(a) * rx * 0.30, math.sin(a) * ry * 0.30])
        cv.paint(cv.ellipse(p[0], p[1], rx * 0.07, ry * 0.07), "#020302")
    return allm


@skill("thief.atk1", tone="tan")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.70, n * 0.30), focus_r=0.5, focus_k=0.7, wash=-50, rng=rng)
    crescent(cv, (n * 0.62, n * 0.42), n * 0.30, n * 0.18, -45, 110, 330, 0.30, el, 1.0)
    _dagger(cv, (n * 0.12, n * 0.92), (n * 0.70, n * 0.30), el)
    hot_core(cv, n * 0.72, n * 0.28, el, 2.4, 1.0, star_len=18, ang=-45)


@skill("thief.spike_trap", tone="tan")
def spike_trap(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.66), (n, n * 0.64), (n, n), (0, n)])
    c = np.array([n * 0.50, n * 0.76])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    _plate(cv, c, n * 0.40, n * 0.13, el, teeth=14)
    # steel spikes sprung up out of the plate in a fan, each with a launch streak
    for i, a in enumerate((-150, -132, -114, -98, -82, -66, -48, -30)):
        base = c + np.array([math.cos(math.radians(a)) * n * 0.22, -n * 0.02 + math.sin(math.radians(a)) * n * 0.03])
        L = n * (0.40 + 0.18 * math.sin(math.pi * i / 7))
        tip = base + _dv(a) * L * np.array([0.55, 1.0])
        d = (tip - base) / np.linalg.norm(tip - base)
        light_streak(cv, base - d * n * 0.02, tip - d * n * 0.06, n * 0.02, "poison", 0.55)
        H = weapon_H(base, tip, 1.0)
        sp = lpoly(cv, H, [(0.0, -0.05), (0.8, -0.03), (1.0, 0.0), (0.8, 0.03), (0.0, 0.05)])
        material(cv, sp, "steel", R=n * 0.008, lw=(0.25, 1.2), back=tone(el)[2], back_k=0.8)
    hot_core(cv, n * 0.50, n * 0.16, el, 2.2, 1.0, star_len=18)


@skill("thief.poison_gas_trap", tone="poison")
def poison_gas(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.82), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.42), focus_r=0.5, focus_k=0.6, wash=-80, rng=rng)
    pal = tone(el)
    gas = ["#0A1A06", "#2A5A14", "#5AB83E", "#B8FF9A"]
    # the gas hugs the floor and rolls outward, a second bank rising behind it, tendrils curling off the edges
    billow(cv, rng, (n * 0.50, n * 0.38), n * 0.30, gas, puffs=9, spread=(1.5, 0.5), alpha=0.85)
    billow(cv, rng, (n * 0.50, n * 0.62), n * 0.38, gas, puffs=14, spread=(1.3, 0.45))
    for sx in (-1, 1):
        for k in range(2):
            p0 = np.array([n * (0.5 + sx * (0.36 + 0.06 * k)), n * (0.60 - 0.14 * k)])
            tp = [p0, p0 + np.array([sx * n * 0.08, -n * 0.06]), p0 + np.array([sx * n * 0.04, -n * 0.14])]
            soft_light(cv, cv.poly(ribbon(spline(tp, 6), lambda t: n * 0.04 * (1 - t) + 0.4)), el, 0.45, R=n * 0.015, glow_r=4, core_k=0.2)
    glow(cv, cv.ellipse(n * 0.5, n * 0.56, n * 0.40, n * 0.18), pal[1], 10, 0.35)
    X, Y = cv.grid()
    for i in range(9):   # toxic bubbles rising through the cloud
        p = (n * rng.uniform(0.22, 0.78), n * rng.uniform(0.18, 0.66))
        r = n * rng.uniform(0.015, 0.035)
        ring = np.clip(cv.ellipse(p[0], p[1], r) - cv.ellipse(p[0] - r * 0.12, p[1] - r * 0.12, r * 0.78), 0, 1)
        cv.add(ring, pal[2], 0.8)
        cv.add(cv.ellipse(p[0] - r * 0.4, p[1] - r * 0.4, r * 0.25), "#FFFFFF", 0.8)
    _plate(cv, (n * 0.50, n * 0.86), n * 0.24, n * 0.07, el, teeth=0, vents=5)
    hot_core(cv, n * 0.50, n * 0.80, el, 2.0, 0.9, star=False)


@skill("thief.inferno_trap", tone="fire")
def inferno(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.60), focus_r=0.5, focus_k=0.8, wash=-90, rng=rng)
    c = np.array([n * 0.50, n * 0.84])
    # the pillar: stacked flame tongues roaring up, widest at the base, licking out at the top
    for i in range(9):
        x = n * (0.30 + 0.05 * i)
        h = n * (0.52 + 0.22 * math.sin(math.pi * i / 8) + rng.uniform(-0.05, 0.05))
        sw = rng.uniform(-0.08, 0.08)
        f = cv.poly(ribbon(spline([(x, c[1]), (x + n * sw, c[1] - h * 0.5), (x - n * sw * 1.5, c[1] - h)], 8),
                           lambda t: n * 0.12 * (1 - t) ** 0.9 + 0.4))
        light_form(cv, f, el, 0.9, R=n * 0.03, glow_r=5, lw=(0.2, 1.4))
    burst(cv, rng, (n * 0.50, n * 0.62), n * 0.16, el, 0.9, smoke_k=0.0, puffs=7, core=False)
    sparks(cv, rng, (n * 0.50, n * 0.30), 10, n * 0.16, el, 0.7, a_range=(-160, -20))
    _plate(cv, c, n * 0.30, n * 0.08, "tan", teeth=10)
    hot_core(cv, n * 0.50, n * 0.66, el, 2.8, 1.1, star_len=22)


@skill("thief.shadow_trap", tone="tan")
def shadow_trap(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.62), (n, n * 0.60), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.74), focus_r=0.45, focus_k=0.5, ink="#020403", wash=0, rng=rng)
    pal = tone(el)
    c = np.array([n * 0.50, n * 0.76])
    # the portal: a pit of shadow in a brass-studded ring
    pit = cv.ellipse(c[0], c[1], n * 0.36, n * 0.12)
    ring = np.clip(pit - cv.ellipse(c[0], c[1] + n * 0.006, n * 0.30, n * 0.095), 0, 1)
    material(cv, ring, "brass", R=n * 0.02, lw=(0.35, 1.8), tilt=(0.0, -0.4), back=pal[2], back_k=0.7)
    hole = cv.ellipse(c[0], c[1] + n * 0.006, n * 0.30, n * 0.095)
    cv.paint(hole, "#010201")
    cv.add(blur(hole * (1 - toward(hole, n * 0.04, (0, 1))), 2.0), "#2A5A14", 0.6)
    for i in range(8):   # notches around the ring (no glyphs)
        a = 2 * math.pi * i / 8
        p = c + np.array([math.cos(a) * n * 0.33, math.sin(a) * n * 0.108])
        cv.paint(cv.ellipse(p[0], p[1], n * 0.014, n * 0.008), "#2A1A08")
    # shadow tendrils rising out of the pit
    for i in range(5):
        x = n * (0.32 + 0.09 * i)
        t_ = cv.poly(ribbon(spline([(x, c[1]), (x + n * 0.04 * math.sin(i * 2.1), n * 0.56), (x - n * 0.03, n * 0.42)], 8),
                            lambda t: n * 0.05 * (1 - t) ** 1.2 + 0.4))
        paint_form(cv, blur(t_, 1.0), ["#010201", "#08100A", "#14261A", "#24402C"], R=n * 0.02, grad=0.6)
    # the return loop: a trail leaving the pit, arcing up and around, diving back in
    path = [(n * 0.66, n * 0.74), (n * 0.86, n * 0.48), (n * 0.76, n * 0.18), (n * 0.46, n * 0.12), (n * 0.22, n * 0.26),
            (n * 0.18, n * 0.50), (n * 0.36, n * 0.72)]
    trail(cv, path, 0.6, n * 0.05, el, 0.9, core_k=0.6)
    hot_core(cv, n * 0.36, n * 0.72, el, 2.4, 1.0, star_len=16)


@skill("thief.stealth", tone="poison")
def stealth(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.44, n * 0.30), focus_r=0.5, focus_k=0.5, ink="#030604", wash=-90, rng=rng)
    pal = tone(el)
    # the empty hooded cloak: hood peak, open face hollow, shoulders, hem fading into smoke
    cloak = cv.poly(closed_spline([(n * 0.50, n * 0.06), (n * 0.66, n * 0.18), (n * 0.72, n * 0.36), (n * 0.86, n * 0.56),
                                   (n * 0.90, n * 0.92), (n * 0.10, n * 0.92), (n * 0.14, n * 0.56), (n * 0.28, n * 0.36),
                                   (n * 0.34, n * 0.18)], 8))
    fade = smoothstep(n * 0.92, n * 0.48, cv.grid()[1])
    cl = cloak * fade
    ink_line(cv, cloak * smoothstep(n * 0.70, n * 0.50, cv.grid()[1]), "#0A1206", 0.4, 2.4, 0.4)
    paint_form(cv, cl, ["#06100A", "#14261A", "#2A4630", "#4A6A48"], R=n * 0.10, grad=0.6)
    for pts in (((0.40, 0.44), (0.34, 0.66), (0.30, 0.88)), ((0.62, 0.44), (0.68, 0.66), (0.72, 0.88)), ((0.50, 0.50), (0.50, 0.70), (0.52, 0.90))):
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.03, n * 0.01) * cl, "#020402", 0.6)   # cloth folds
    trim = cv.poly(ribbon(spline([(n * 0.30, n * 0.38), (n * 0.40, n * 0.42), (n * 0.50, n * 0.44), (n * 0.60, n * 0.42),
                                  (n * 0.70, n * 0.38)], 6), [n * 0.03] * 25)) * cloak
    material(cv, trim, "brass", R=n * 0.01, line=False)
    hollow = cv.poly(closed_spline([(n * 0.50, n * 0.16), (n * 0.60, n * 0.24), (n * 0.60, n * 0.36), (n * 0.50, n * 0.42),
                                    (n * 0.40, n * 0.36), (n * 0.40, n * 0.24)], 8))
    cv.paint(hollow, "#010201")
    cv.paint(hollow * (1 - toward(hollow, n * 0.03, LIGHT2)), "#14261A", 0.6)
    # the hem dissolving: smoke wisps drifting off
    billow(cv, rng, (n * 0.50, n * 0.86), n * 0.30, ["#030604", "#0E1A12", "#24402C", "#4A6A48"], puffs=8, spread=(1.3, 0.35),
           alpha=0.8)
    cv.add(cloak * (1 - toward(cloak, 1.8, LIGHT)) * fade, pal[1], 0.8)   # rim of poison light
    for p in ((0.46, 0.30), (0.56, 0.30)):   # two faint glints in the dark of the hood
        hot_core(cv, n * p[0], n * p[1], el, 0.7, 0.5, star=False)
    hot_core(cv, n * 0.30, n * 0.12, el, 1.6, 0.7, star_len=12)


@skill("thief.ambush", tone="poison")
def ambush(cv, rng, el):
    n = cv.n
    hit = np.array([n * 0.72, n * 0.74])
    ground(cv, el, [], focus=hit, focus_r=0.42, focus_k=0.8, ink="#020403", wash=-135, rng=rng)
    sh = billow(cv, rng, (n * 0.22, n * 0.22), n * 0.34, ["#010201", "#0A1A0E", "#20402A", "#3A6A44"], puffs=10, spread=(1.0, 1.0))
    cv.add(np.clip(sh - toward(sh, n * 0.03, LIGHT), 0, 1) * smoothstep(0.3, 0.7, sh), tone(el)[0], 0.8)
    d = (hit - np.array([n * 0.10, n * 0.10])) / np.linalg.norm(hit - np.array([n * 0.10, n * 0.10]))
    nv = np.array([-d[1], d[0]])
    for o in (-0.06, 0.0, 0.06):
        light_streak(cv, np.array([n * 0.20, n * 0.20]) + nv * n * o, hit - d * n * 0.12 + nv * n * o, n * 0.014, el, 0.6)
    _dagger(cv, (n * 0.20, n * 0.20), hit, "tan", 1.1)
    shock_ring(cv, hit + d * n * 0.02, nv, d, n * 0.16, n * 0.06, n * 0.025, el, 0.9)
    dizzy_stars(cv, (n * 0.70, n * 0.56), n * 0.16, n * 0.05, (190, 300, 40), n * 0.04)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1, star_len=20, ang=45)


@skill("thief.ice_trap", tone="frost")
def ice_trap(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.66), (n, n * 0.64), (n, n), (0, n)])
    c = np.array([n * 0.50, n * 0.78])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.60), focus_r=0.55, focus_k=0.8, wash=0, rng=rng)
    shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.44, n * 0.13, n * 0.035, el, 0.9)
    frost_floor = cv.ellipse(c[0], c[1], n * 0.42, n * 0.12)
    cv.add(blur(frost_floor, 3.0), tone(el)[1], 0.35)
    # crystal shards erupting from the ring: tall centre, splaying outward, each split into lit / shadow facets
    shards = [(-90, 0.62, 0.075), (-112, 0.46, 0.06), (-68, 0.50, 0.062), (-135, 0.30, 0.05), (-45, 0.34, 0.05),
              (-155, 0.20, 0.04), (-25, 0.22, 0.04), (-100, 0.30, 0.045), (-78, 0.26, 0.045)]
    for a, L, w in sorted(shards, key=lambda q: -q[1]):
        base = c + np.array([math.cos(math.radians(a)) * n * 0.10, n * 0.02])
        d = _dv(a)
        nv = np.array([-d[1], d[0]])
        tip = base + d * n * L
        m = cv.poly([base - nv * n * w, base + d * n * L * 0.78 - nv * n * w * 0.8, tip, base + d * n * L * 0.78 + nv * n * w * 0.8,
                     base + nv * n * w])
        lit = cv.poly([base, base + d * n * L * 0.78 - nv * n * w * 0.8, tip, base + d * n * L * 0.5]) * m
        glow(cv, m, tone(el)[1], 5, 0.4)
        material(cv, m, "glass", R=n * 0.015, lw=(0.3, 1.6), tilt=(-0.3, -0.2))
        cv.paint(lit, "#DFF6FF", 0.45)
        cv.add(np.clip(m - toward(m, 1.2, LIGHT), 0, 1), tone(el)[2], 0.6)
    for x, y in ((0.12, 0.70), (0.86, 0.68), (0.20, 0.88), (0.80, 0.90)):
        stone_chip(cv, rng, n * x, n * y, n * 0.03, rng.uniform(0, 360), el, hot_dir=(0.5 - x, 0.8 - y))
    hot_core(cv, n * 0.50, n * 0.40, el, 2.6, 1.1, star_len=22)
