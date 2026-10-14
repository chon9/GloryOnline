"""机械师 Mechanic (rifle + gadgets). Steel-keyed bar: spark orange, gunmetal grey and volt blue on a blue-black
ground, steel metal with hazard-orange accents. The bar's one off-key accent is ice-cyan, on the ultimate's drone
lamps and rims.

Value plan:
  rifle_1                the rifle along the bottom third, one tracer piercing two plates: long horizontal  [rifle]
  bouncing_mine          a disc mine sprung up out of a dirt crater on a coil spring: disc over a pit
  mechanical_seeker      a squat tracked robot charging right, dust behind: a compact block low centre
  rocket_punch           a steel fist on a rocket stump flying up-right on an exhaust plume: diagonal
  electromagnetic_coil   an upright copper coil on a base plate inside field loops, arcs to the ground: column
  rotor_wings            the rotor backpack from behind, two spinning rotor discs: two ellipses high
  air_compressor         a compressor tank low left blasting a widening cone of gust curls: a fan
  air_drops              two bomber drones up top, a spiral of falling bombs onto a target ring below
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_gunfight import bullet, fist_side, muzzle_flash, rifle


def _u(a, b):
    d = np.asarray(b, float) - np.asarray(a, float)
    return d / (np.linalg.norm(d) + 1e-9)


def _rotor(cv, c, rx, ry, el, k=1.0, blades=3, phase=0.0):
    """a spinning rotor seen at an angle: a soft motion disc, faint blade streaks, a steel hub"""
    disc = cv.ellipse(c[0], c[1], rx, ry)
    cv.paint(blur(disc, 1.5), mix(tone(el)[0], tone(el)[1], 0.35), 0.45 * k)
    ring = np.clip(disc - cv.ellipse(c[0], c[1], rx * 0.9, ry * 0.85), 0, 1)
    soft_light(cv, ring, el, 0.6 * k, R=0.8, glow_r=2)
    for b in range(blades):
        a = phase + b * 2 * math.pi / blades
        tip = c + np.array([math.cos(a) * rx * 0.95, math.sin(a) * ry * 0.95])
        bl = cv.poly(ribbon([c, (c + tip) / 2, tip], [rx * 0.10, rx * 0.12, rx * 0.04]))
        cv.paint(blur(bl, 1.0), "#C8D0DC", 0.45 * k)
    hub = cv.ellipse(c[0], c[1], rx * 0.12, ry * 0.2)
    material(cv, hub, "steel", R=rx * 0.05, lw=(0.25, 1.0))
    return disc


def _bomb(cv, c, s, ang, el, k=1.0):
    """an aerial bomb: steel teardrop body, orange nose band, box fins"""
    H = H_affine(c, ang, s)
    body = lpoly(cv, H, spline([(-0.5, -0.20), (0.2, -0.26), (0.5, -0.12), (0.56, 0.0), (0.5, 0.12), (0.2, 0.26), (-0.5, 0.20)], 4))
    fins = lpoly(cv, H, [(-0.75, -0.30), (-0.42, -0.14), (-0.42, 0.14), (-0.75, 0.30)])
    material(cv, fins, "gf_gunmetal", R=s * 0.05, lw=(0.2, 0.9))
    material(cv, body, "gf_gunmetal", R=s * 0.12, lw=(0.25, 1.2), back=tone(el)[2], back_k=0.7 * k)
    cv.paint(lpoly(cv, H, [(0.22, -0.3), (0.32, -0.3), (0.32, 0.3), (0.22, 0.3)]) * body, KEY["accent"], 0.85)
    return body


@skill("mechanic.rifle_1", tone="gunmetal")
def rifle_shot(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.48), (n, n * 0.38), (n, n * 0.66), (0, n * 0.78)])
    ground(cv, el, [(band, 1)], focus=(n * 0.84, n * 0.48), focus_r=0.45, focus_k=0.6, wash=-6, rng=rng)
    a = np.array([n * 0.62, n * 0.585])
    b = np.array([n * 1.06, n * 0.51])
    d = _u(a, b)
    nv = np.array([-d[1], d[0]])
    beam = cv.poly([a + nv * n * 0.008, b + nv * n * 0.02, b - nv * n * 0.02, a - nv * n * 0.008])
    soft_light(cv, beam, "spark", 1.0, R=n * 0.012, glow_r=4, core_k=1.2)
    for t, h in ((0.36, 0.20), (0.74, 0.16)):   # two armour slabs seen edge-on, holed by the round
        p = a + (b - a) * t
        slab = cv.poly([p + np.array([-n * 0.02, -n * h]), p + np.array([n * 0.025, -n * h * 0.9]), p + np.array([n * 0.025, n * h]),
                        p + np.array([-n * 0.02, n * h * 0.9])])
        material(cv, slab, "plate", R=n * 0.01, lw=(0.35, 1.8), back=tone("spark")[2], back_k=0.8)
        hole = cv.ellipse(p[0], p[1], n * 0.018, n * 0.03)
        cv.paint(hole, "#140600")
        cv.add(blur(hole, 1.0), tone("spark")[2], 1.0)
        sparks(cv, rng, p + np.array([n * 0.03, 0]), 6, n * 0.09, "spark", 0.9, a_range=(-60, 60), width=1.2)
        hot_core(cv, p[0], p[1], "spark", 1.6, 0.9, star_len=10)
    H = weapon_H((n * -0.04, n * 0.70), (n * 0.62, n * 0.585), 1.9)
    rifle(cv, H, "spark", flash=0.0)
    muzzle_flash(cv, xf(H, [(1.03, -0.005)])[0], math.degrees(math.atan2(d[1], d[0])), n * 0.14, "spark", 0.9)
    for i in range(3):
        p = np.array([n * (0.36 + i * 0.05), n * (0.42 - i * 0.07)])
        bullet(cv, H_affine(p, -60 - i * 40, n * 0.06, n * 0.06), el, 0.6, tip="brass")


@skill("mechanic.bouncing_mine", tone="spark")
def bouncing_mine(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.76), (n, n * 0.74), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    pit = np.array([n * 0.50, n * 0.84])
    hole = cv.ellipse(pit[0], pit[1], n * 0.24, n * 0.06)
    cv.paint(blur(hole, 1.0), "#050302")
    shock_ring(cv, pit, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.32, n * 0.08, n * 0.02, el, 0.7)
    for i in range(9):   # dirt clods thrown up
        a = math.radians(rng.uniform(-160, -20))
        dv = np.array([math.cos(a), math.sin(a)])
        p = pit + dv * np.array([n * rng.uniform(0.20, 0.44), n * rng.uniform(0.10, 0.40)])
        stone_chip(cv, rng, p[0], p[1], n * rng.uniform(0.025, 0.05), rng.uniform(0, 360), el, hot_dir=(0, 1), trail=dv)
    # coil spring from the pit up to the mine
    top = np.array([n * 0.50, n * 0.50])
    for i in range(7):
        y = pit[1] - (pit[1] - top[1]) * (i + 0.5) / 7
        rw = n * (0.07 + 0.01 * i)
        lp = arc_pts(n * 0.50, y, rw, 200, 340, 16, ry=n * 0.025)
        coil = cv.poly(ribbon(lp, [n * 0.012] * len(lp)))
        material(cv, coil, "steel", R=n * 0.005, lw=(0.2, 0.8))
    c = np.array([n * 0.50, n * 0.42])
    side = cv.poly([(c[0] - n * 0.30, c[1]), (c[0] + n * 0.30, c[1]), (c[0] + n * 0.28, c[1] + n * 0.10), (c[0] - n * 0.28, c[1] + n * 0.10)])
    side = np.maximum(side, cv.ellipse(c[0], c[1] + n * 0.10, n * 0.28, n * 0.07))
    material(cv, side, "gf_gunmetal", R=n * 0.03, lw=(0.4, 2.2), back=tone(el)[2], back_k=0.8)
    cv.paint(cv.poly([(c[0] - n * 0.30, c[1] + n * 0.03), (c[0] + n * 0.30, c[1] + n * 0.03), (c[0] + n * 0.30, c[1] + n * 0.055),
                      (c[0] - n * 0.30, c[1] + n * 0.055)]) * side, KEY["accent"], 0.85)
    face = cv.ellipse(c[0], c[1], n * 0.30, n * 0.09)
    material(cv, face, "steel", R=n * 0.05, lw=(0.4, 1.8))
    for a in range(0, 360, 60):   # prongs and lamps on the face
        ar = math.radians(a + 30)
        p = c + np.array([math.cos(ar) * n * 0.19, math.sin(ar) * n * 0.055])
        lamp = cv.ellipse(p[0], p[1], n * 0.022, n * 0.012)
        cv.paint(lamp, "#200A02")
        cv.add(blur(lamp, 1.0), tone(el)[2], 0.9)
    pr = cv.ellipse(c[0], c[1] - n * 0.01, n * 0.06, n * 0.025)
    material(cv, pr, "gf_orange", R=n * 0.02, lw=(0.2, 1.0))
    for x in (-0.24, -0.08, 0.10, 0.26):
        light_streak(cv, (c[0] + n * x, n * 0.70), (c[0] + n * x * 1.2, n * 0.14), n * 0.012, el, 0.5)
    hot_core(cv, c[0], c[1] - n * 0.03, el, 2.4, 1.0, star_len=18)


@skill("mechanic.mechanical_seeker", tone="gunmetal")
def seeker(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.62, n * 0.56), focus_r=0.5, focus_k=0.6, wash=0, rng=rng)
    speed_lines(cv, rng, 0, 8, el, 0.45, band=(0.25, 0.70))
    smoke(cv, rng, [(n * -0.05, n * 0.78), (n * 0.08, n * 0.74), (n * 0.20, n * 0.76)], n * 0.07, "#3A4048", 0.7)
    c = np.array([n * 0.52, n * 0.58])
    tread = cv.poly(closed_spline([(c[0] - n * 0.30, c[1] + n * 0.08), (c[0] + n * 0.28, c[1] + n * 0.08), (c[0] + n * 0.34, c[1] + n * 0.16),
                                   (c[0] + n * 0.28, c[1] + n * 0.24), (c[0] - n * 0.30, c[1] + n * 0.24), (c[0] - n * 0.36, c[1] + n * 0.16)], 4))
    material(cv, tread, "darksteel", R=n * 0.03, lw=(0.4, 2.0), back=tone(el)[2], back_k=0.6)
    for i in range(5):
        w = cv.ellipse(c[0] + n * (-0.24 + i * 0.12), c[1] + n * 0.16, n * 0.045)
        material(cv, w, "steel", R=n * 0.015, lw=(0.2, 0.9))
        cv.paint(cv.ellipse(c[0] + n * (-0.24 + i * 0.12), c[1] + n * 0.16, n * 0.015), "#141820")
    body = cv.poly(closed_spline([(c[0] - n * 0.26, c[1] - n * 0.12), (c[0] + n * 0.18, c[1] - n * 0.14), (c[0] + n * 0.30, c[1] - n * 0.04),
                                  (c[0] + n * 0.28, c[1] + n * 0.10), (c[0] - n * 0.28, c[1] + n * 0.10)], 4))
    material(cv, body, "gf_gunmetal", R=n * 0.06, lw=(0.45, 2.2), back=tone(el)[2], back_k=0.7)
    for i in range(5):   # hazard stripes along the flank
        x = c[0] - n * 0.22 + i * n * 0.07
        cv.paint(cv.poly([(x, c[1] + n * 0.08), (x + n * 0.035, c[1] + n * 0.08), (x + n * 0.075, c[1] - n * 0.0), (x + n * 0.04, c[1] - n * 0.0)])
                 * body, KEY["accent"], 0.9)
    dome = cv.ellipse(c[0] - n * 0.04, c[1] - n * 0.13, n * 0.14, n * 0.10) * cv.poly([(0, 0), (n, 0), (n, c[1] - n * 0.12), (0, c[1] - n * 0.12)])
    material(cv, dome, "darksteel", R=n * 0.05, lw=(0.4, 1.8))
    lamp = cv.ellipse(c[0] - n * 0.04, c[1] - n * 0.25, n * 0.035, n * 0.025)
    soft_light(cv, lamp, "spark", 1.0, R=n * 0.02, glow_r=6)
    ant = stroke(cv, [(c[0] + n * 0.08, c[1] - n * 0.18), (c[0] + n * 0.0, c[1] - n * 0.36), (c[0] - n * 0.08, c[1] - n * 0.42)], n * 0.012, n * 0.006)
    material(cv, ant, "steel", R=n * 0.004, lw=(0.2, 0.7))
    lens = cv.ellipse(c[0] + n * 0.23, c[1] - n * 0.02, n * 0.045)
    material(cv, lens, "steel", R=n * 0.02, lw=(0.3, 1.2))
    cv.paint(cv.ellipse(c[0] + n * 0.235, c[1] - n * 0.02, n * 0.024), "#180802")
    cv.add(blur(cv.ellipse(c[0] + n * 0.24, c[1] - n * 0.025, n * 0.014), 1.0), tone("spark")[2], 1.0)
    hot_core(cv, c[0] - n * 0.04, c[1] - n * 0.25, "spark", 2.0, 0.9, star_len=14)


@skill("mechanic.rocket_punch", tone="spark")
def rocket_punch(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.70, n * 0.30), focus_r=0.5, focus_k=0.6, wash=-40, rng=rng)
    k = np.array([n * 0.84, n * 0.20])
    d = _u((n * 0.10, n * 0.94), k)
    wrist = k - d * n * 0.36
    noz = wrist - d * n * 0.20
    smoke(cv, rng, [noz - d * n * 0.62, noz - d * n * 0.44, noz - d * n * 0.26], n * 0.08, "#3A3E46", 0.75)
    trail(cv, [noz - d * n * 0.60, noz - d * n * 0.30, noz], 1.5, n * 0.15, el, 1.0, core_k=1.3)
    burst(cv, rng, noz - d * n * 0.06, n * 0.09, el, 0.8, smoke_k=0.0, puffs=5, core=False)
    H = weapon_H(noz, wrist + d * n * 0.02, 0.7)
    can = lpoly(cv, H, [(0.0, -0.62), (1.0, -0.62), (1.0, 0.62), (0.0, 0.62)])
    material(cv, can, "gf_blued", R=n * 0.04, lw=(0.4, 2.0), streak_ang=math.degrees(math.atan2(d[1], d[0])), back=tone(el)[2], back_k=0.8)
    for x in (0.15, 0.75):
        cv.paint(lpoly(cv, H, [(x, -0.7), (x + 0.10, -0.7), (x + 0.10, 0.7), (x, 0.7)]) * can, KEY["accent"], 0.85)
    for sg in (-1, 1):   # stabiliser fins
        fin = lpoly(cv, H, [(0.05, sg * 0.6), (0.45, sg * 0.6), (0.10, sg * 1.05), (-0.05, sg * 1.0)])
        material(cv, fin, "steel", R=n * 0.01, lw=(0.3, 1.3))
    bell = lpoly(cv, H, [(0.0, -0.46), (-0.25, -0.62), (-0.25, 0.62), (0.0, 0.46)])
    material(cv, bell, "steel", R=n * 0.02, lw=(0.3, 1.4))
    Hf = weapon_H(wrist, k, 0.95)
    fist_side(cv, Hf, el, glove="steel", trim="gf_orange", cuff="gf_blued", k=1.0, arm_len=0.1)
    hot_core(cv, k[0] + d[0] * n * 0.03, k[1] + d[1] * n * 0.03, el, 2.4, 1.0, star_len=18)


@skill("mechanic.electromagnetic_coil", tone="volt")
def em_coil(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.74), (n, n * 0.72), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.46), focus_r=0.5, focus_k=0.7, ink="#04060A", wash=-90, rng=rng)
    c = np.array([n * 0.50, n * 0.46])
    for s, k in ((1.0, 0.7), (0.78, 0.55)):   # magnetic field loops either side
        for sg in (-1, 1):
            lp = [c + np.array([sg * n * 0.10 + sg * n * 0.30 * s * math.sin(t), -n * 0.30 * math.cos(t) * s * 1.05]) for t in np.linspace(0.15, math.pi - 0.15, 24)]
            m = cv.poly(ribbon(np.array(lp), [n * 0.006, n * 0.014, n * 0.006]))
            soft_light(cv, m, el, k, R=0.8, glow_r=3)
    base = np.array([n * 0.50, n * 0.80])
    shock_ring(cv, base, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.40, n * 0.09, n * 0.025, el, 0.8)
    plate = cv.ellipse(base[0], base[1] - n * 0.02, n * 0.22, n * 0.06)
    plate = np.maximum(plate, cv.poly([(base[0] - n * 0.22, base[1] - n * 0.02), (base[0] + n * 0.22, base[1] - n * 0.02),
                                       (base[0] + n * 0.22, base[1] + n * 0.03), (base[0] - n * 0.22, base[1] + n * 0.03)]))
    plate = np.maximum(plate, cv.ellipse(base[0], base[1] + n * 0.03, n * 0.22, n * 0.06))
    material(cv, plate, "darksteel", R=n * 0.03, lw=(0.4, 2.0), back=tone(el)[2], back_k=0.7)
    core = cv.poly([(c[0] - n * 0.05, n * 0.16), (c[0] + n * 0.05, n * 0.16), (c[0] + n * 0.05, n * 0.78), (c[0] - n * 0.05, n * 0.78)])
    material(cv, core, "steel", R=n * 0.03, lw=(0.4, 1.8), streak_ang=90)
    for i in range(9):   # copper windings
        y = n * (0.26 + i * 0.052)
        lp = arc_pts(c[0], y, n * 0.12, -10, 190, 20, ry=n * 0.03)
        w = cv.poly(ribbon(lp, [n * 0.034] * len(lp)))
        material(cv, w, "gf_copper", R=n * 0.012, lw=(0.25, 1.1), brk=0.2)
    cap = cv.ellipse(c[0], n * 0.19, n * 0.10, n * 0.035)
    material(cv, cap, "gf_orange", R=n * 0.02, lw=(0.3, 1.2))
    for sg in (-1, 1):   # arcs crackling down to the plate
        pts = [np.array([c[0] + sg * n * 0.12, n * 0.40])]
        for j in range(4):
            pts.append(pts[-1] + np.array([sg * n * rng.uniform(0.04, 0.08), n * 0.09]) + rng.uniform(-1, 1, 2) * n * 0.02)
        bolt = cv.poly(ribbon(np.array(pts), [n * 0.016, n * 0.012, n * 0.010, n * 0.008, n * 0.004]))
        soft_light(cv, bolt, el, 1.0, R=0.8, glow_r=3)
    hot_core(cv, c[0], n * 0.19, el, 2.4, 1.0, star_len=18)


@skill("mechanic.rotor_wings", tone="gunmetal")
def rotor_wings(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.50, n * 0.30), focus_r=0.6, focus_k=0.6, wash=-90, rng=rng)
    for x in (0.12, 0.30, 0.70, 0.88):
        light_streak(cv, (n * x, n * 0.46), (n * x * 0.9 + n * 0.05, n * 1.0), n * 0.016, el, 0.5)
    pack = np.array([n * 0.50, n * 0.66])
    for sg in (-1, 1):   # arms up to the hubs
        arm = stroke(cv, [pack + np.array([sg * n * 0.08, -n * 0.10]), pack + np.array([sg * n * 0.20, -n * 0.26]),
                          np.array([n * 0.50 + sg * n * 0.27, n * 0.30])], n * 0.05, n * 0.035)
        material(cv, arm, "gf_gunmetal", R=n * 0.015, lw=(0.3, 1.5), back=tone(el)[2], back_k=0.5)
        cv.paint(stroke(cv, [pack + np.array([sg * n * 0.12, -n * 0.16]), pack + np.array([sg * n * 0.20, -n * 0.26])], n * 0.02, n * 0.02),
                 KEY["accent"], 0.85)
    for sg in (-1, 1):
        _rotor(cv, np.array([n * 0.50 + sg * n * 0.27, n * 0.28]), n * 0.24, n * 0.09, el, 1.0, phase=sg * 0.8)
    for sg in (-1, 1):   # shoulder straps running out of frame
        st = stroke(cv, [pack + np.array([sg * n * 0.13, -n * 0.10]), pack + np.array([sg * n * 0.22, n * 0.12]), (pack[0] + sg * n * 0.26, n * 1.05)],
                    n * 0.06, n * 0.07)
        material(cv, st, "leather", R=n * 0.02, lw=(0.35, 1.6))
    body = cv.poly(closed_spline([(pack[0] - n * 0.14, pack[1] - n * 0.18), (pack[0] + n * 0.14, pack[1] - n * 0.18),
                                  (pack[0] + n * 0.17, pack[1] + n * 0.04), (pack[0] + n * 0.12, pack[1] + n * 0.24),
                                  (pack[0] - n * 0.12, pack[1] + n * 0.24), (pack[0] - n * 0.17, pack[1] + n * 0.04)], 5))
    material(cv, body, "gf_gunmetal", R=n * 0.06, lw=(0.45, 2.2), back=tone(el)[2], back_k=0.7, streak_ang=90)
    turb = cv.ellipse(pack[0], pack[1] + n * 0.02, n * 0.085, n * 0.10)
    material(cv, turb, "darksteel", R=n * 0.03, lw=(0.35, 1.6))
    for i in range(10):   # turbine fan blades in the intake
        ar = math.radians(i * 36)
        bl = stroke(cv, [(pack[0], pack[1] + n * 0.02), (pack[0] + math.cos(ar) * n * 0.06 - math.sin(ar) * n * 0.02,
                                                         pack[1] + n * 0.02 + math.sin(ar) * n * 0.07 + math.cos(ar) * n * 0.02)], n * 0.016, n * 0.006)
        cv.paint(bl * turb, "#6E7A88", 0.8)
    material(cv, cv.ellipse(pack[0], pack[1] + n * 0.02, n * 0.022), "steel", R=n * 0.01, lw=(0.2, 0.9))
    for sg in (-1, 1):
        cv.paint(stroke(cv, [(pack[0] + sg * n * 0.15, pack[1] - n * 0.14), (pack[0] + sg * n * 0.13, pack[1] + n * 0.20)], n * 0.022, n * 0.022) * body,
                 KEY["accent"], 0.9)
    hot_core(cv, n * 0.50, n * 0.12, el, 2.2, 0.9, star_len=22)


@skill("mechanic.air_compressor", tone="volt")
def air_compressor(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.82), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.62, n * 0.44), focus_r=0.6, focus_k=0.7, wash=-25, rng=rng)
    noz = np.array([n * 0.34, n * 0.62])
    for i, (r, a0, a1, w) in enumerate(((0.20, -80, 40, 0.22), (0.34, -70, 30, 0.26), (0.50, -60, 22, 0.28), (0.66, -52, 16, 0.24))):
        crescent(cv, noz + np.array([-n * 0.04, 0]), n * r, n * r * 0.9, -20, a0, a1, w, el, 0.65 + 0.1 * i, rim=i == 3)
    for i in range(7):
        a = math.radians(rng.uniform(-50, 5))
        dv = np.array([math.cos(a), math.sin(a)])
        light_streak(cv, noz + dv * n * 0.2, noz + dv * n * rng.uniform(0.5, 0.7), n * 0.012, el, 0.6)
    for x, y, s in ((0.80, 0.22, 0.04), (0.90, 0.46, 0.05), (0.70, 0.12, 0.03)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-1, 0.3), trail=(1.0, -0.4))
    tank = cv.poly(closed_spline([(n * 0.04, n * 0.62), (n * 0.10, n * 0.54), (n * 0.30, n * 0.54), (n * 0.34, n * 0.62),
                                  (n * 0.30, n * 0.82), (n * 0.10, n * 0.82), (n * 0.04, n * 0.74)], 4))
    material(cv, tank, "gf_gunmetal", R=n * 0.07, lw=(0.45, 2.2), back=tone(el)[2], back_k=0.7)
    for x in (0.12, 0.22):
        cv.paint(cv.poly([(n * x, n * 0.54), (n * (x + 0.03), n * 0.54), (n * (x + 0.03), n * 0.82), (n * x, n * 0.82)]) * tank, KEY["accent"], 0.85)
    gauge = cv.ellipse(n * 0.18, n * 0.50, n * 0.05)
    material(cv, gauge, "steel", R=n * 0.02, lw=(0.3, 1.2))
    cv.paint(cv.ellipse(n * 0.18, n * 0.50, n * 0.033), "#E8ECF0")
    cv.paint(stroke(cv, [(n * 0.18, n * 0.50), (n * 0.205, n * 0.475)], n * 0.008, n * 0.004), KEY["accent"])
    cone = cv.poly([(n * 0.30, n * 0.58), (n * 0.40, n * 0.54), (n * 0.40, n * 0.70), (n * 0.30, n * 0.66)])
    material(cv, cone, "steel", R=n * 0.02, lw=(0.35, 1.6))
    hot_core(cv, n * 0.44, n * 0.60, el, 2.4, 1.0, star_len=18)


@skill("mechanic.air_drops", tone="spark")
def air_drops(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.72), (n, n * 0.70), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.82), focus_r=0.55, focus_k=0.8, wash=-80, rng=rng)
    tgt = np.array([n * 0.50, n * 0.84])
    shock_ring(cv, tgt, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.40, n * 0.10, n * 0.022, el, 0.8)
    shock_ring(cv, tgt, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.22, n * 0.055, n * 0.014, el, 0.6)
    burst(cv, rng, tgt + np.array([-n * 0.18, -n * 0.02]), n * 0.10, el, 0.8, smoke_k=0.6, puffs=6)
    burst(cv, rng, tgt + np.array([n * 0.16, n * 0.0]), n * 0.12, el, 0.9, smoke_k=0.6, puffs=7)
    for i in range(7):   # the spiral carpet: bombs falling on a corkscrew, smaller higher up
        t = i / 6
        a = t * math.pi * 2.2
        p = np.array([n * 0.50 + math.cos(a) * n * (0.30 - 0.12 * t), n * (0.70 - 0.42 * t) + math.sin(a) * n * 0.05])
        light_streak(cv, p - np.array([0, n * 0.10]), p - np.array([0, n * 0.02]), n * 0.012, el, 0.5)
        _bomb(cv, p, n * (0.11 - 0.04 * t), 90, el)
    drones = []
    for (x, y, s) in ((0.24, 0.13, 1.0), (0.76, 0.17, 0.85)):
        c = np.array([n * x, n * y])
        for sx in (-1, 1):
            arm = stroke(cv, [c, c + np.array([sx * n * 0.14 * s, -n * 0.03 * s])], n * 0.022 * s, n * 0.016 * s)
            material(cv, arm, "gf_gunmetal", R=n * 0.006, lw=(0.25, 1.0))
        for sx in (-1, 1):
            _rotor(cv, c + np.array([sx * n * 0.15 * s, -n * 0.04 * s]), n * 0.08 * s, n * 0.025 * s, "gunmetal", 0.8, blades=2, phase=sx)
        hull = cv.ellipse(c[0], c[1], n * 0.08 * s, n * 0.045 * s)
        material(cv, hull, "gf_gunmetal", R=n * 0.025, lw=(0.35, 1.6), back=tone(el)[2], back_k=0.6)
        cv.paint(cv.poly([(c[0] - n * 0.08 * s, c[1]), (c[0] + n * 0.08 * s, c[1]), (c[0] + n * 0.08 * s, c[1] + n * 0.01 * s),
                          (c[0] - n * 0.08 * s, c[1] + n * 0.01 * s)]) * hull, KEY["accent"], 0.9)
        drones.append((c, s, hull))
    hot_core(cv, tgt[0] + n * 0.16, tgt[1] - n * 0.02, el, 2.6, 1.0, star_len=20)

    def bleed(c2):
        for c, s, hull in drones:   # the bar's one off-key accent: ice-cyan drone lamps and rims
            c2.add(np.clip(hull - toward(hull, 1.2, LIGHT), 0, 1), KEY["cool"], 0.9)
            lamp = c2.ellipse(c[0], c[1] + n * 0.04 * s, n * 0.016 * s)
            c2.add(blur(lamp, 2.0), KEY["cool"], 1.0)
            c2.add(lamp, "#FFFFFF", 0.8)
    return {"bleed": bleed}
