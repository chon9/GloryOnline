"""柔道 Grappler (东方棍 tonfa). Indigo-keyed bar: indigo gi, white belt / tape light, pale-violet impact.
The bar's one off-key accent is ember orange, on the ultimate's spin ring.

Value plan (one big greyscale shape each):
  tonfa_strike      the tonfa on a steep diagonal, a short swing smear, impact star at its tip          [tonfa]
  toss              VERTICAL COLUMN: a launch pillar from a ground burst, the foe tumbling at the top
  back_throw        ARCH: a huge over-the-shoulder arc from the right, the foe head-down into a ground crater left
  receiving_throw   C-HOOK: an armoured fist driving in from the right, caught by a white hook that curls it back
  fling             HORIZONTAL BAND: the foe flung flat to the right along long speed lines
  flying_hands      INVERTED V: two arcs from a top-centre grip splitting to two foes slammed in both lower corners
  aerial_twist      SCREW: tilted spin smears wrapping the foe as it is wrung head-first down into the floor
  spinning_throw    RING: the foe swung at arm's length around a dark hub, a full spin ring with an ember rim (ULT)
The tonfa appears in 1 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_night import figure, dizzy_stars, cloud  # noqa: F401


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _tonfa(cv, H, el, grip=True):
    """lacquered tonfa: shaft 0..1 (half-width 0.045), side handle at x 0.30 out to -y with a round knob, steel end
    caps; a tape-wrapped fist closes around the handle"""
    pal = tone(el)
    a0, a1 = xf(H, [(0.0, 0.0), (1.0, 0.0)])
    ang = math.degrees(math.atan2(a1[1] - a0[1], a1[0] - a0[0]))
    sh = lpoly(cv, H, spline([(0.0, -0.040), (0.5, -0.045), (0.97, -0.044), (1.0, 0.0), (0.97, 0.044), (0.5, 0.045),
                              (0.0, 0.040), (-0.012, 0.0)], 3))
    hd = lpoly(cv, H, [(0.27, -0.04), (0.33, -0.04), (0.325, -0.21), (0.275, -0.21)])
    knob = cv.ellipse(*xf(H, [(0.30, -0.23)])[0], lR(H, 0.038))
    allm = union(cv, [sh, hd, knob])
    ink_line(cv, allm, "#04060E", 0.4, 2.2, 0.4)
    solid(cv, H, hd, "lacquer", 0.025, line=False)
    solid(cv, H, knob, "steel", 0.03, line=False)
    solid(cv, H, sh, "lacquer", 0.04, line=False, streak_ang=ang, back=pal[2], back_k=0.8)
    for x in (0.0, 0.93):
        cyl_band(cv, H, x, x + 0.07, 0.047, "steel")
    if grip:
        # the fist wraps the handle: white tape, knuckles toward the viewer, sleeve cuff behind
        cuff = lpoly(cv, H, [(0.05, -0.20), (0.22, -0.22), (0.22, -0.02), (0.05, -0.04)])
        solid(cv, H, cuff, "navy", 0.05, lw=(0.35, 1.6), back=pal[2], back_k=0.6)
        fm = lpoly(cv, H, spline([(0.21, -0.17), (0.30, -0.185), (0.39, -0.17), (0.40, -0.10), (0.37, -0.04), (0.22, -0.04)], 3))
        solid(cv, H, fm, "ivory", 0.05, lw=(0.35, 1.8))
        for y in (-0.15, -0.115, -0.08):
            cv.paint(lrib(cv, H, [(0.24, y), (0.39, y + 0.01)], 0.006) * fm, "#5E6478", 0.7)
        allm = union(cv, [allm, cuff, fm])
    return allm


@skill("grappler.tonfa_strike", tone="indigo")
def tonfa_strike(cv, rng, el):
    n = cv.n
    tip = np.array([n * 0.80, n * 0.20])
    ground(cv, el, [], focus=tip, focus_r=0.45, focus_k=0.8, wash=-45, rng=rng)
    crescent(cv, (n * 0.12, n * 0.92), n * 0.86, n * 0.86, 0, 8, -50, 0.30, el, 1.0)
    burst(cv, rng, tip + _dv(-45) * n * 0.04, n * 0.10, "impact", 0.8, smoke_k=0.0, puffs=5, core=False)
    _tonfa(cv, weapon_H((n * 0.10, n * 0.90), tip - _dv(-48) * n * 0.02, 1.0), el)
    for a in (-100, -60, -20, 20):
        p0 = tip + _dv(a) * n * 0.07
        light_streak(cv, p0, p0 + _dv(a) * n * 0.12, n * 0.016, "impact", 0.8)
    hot_core(cv, tip[0], tip[1], "impact", 2.6, 1.1, star_len=18)


@skill("grappler.toss", tone="white")
def toss(cv, rng, el):
    n = cv.n
    col_ = cv.poly([(n * 0.34, 0), (n * 0.66, 0), (n * 0.62, n), (n * 0.38, n)])
    floor = cv.poly([(0, n * 0.82), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(col_, 1), (floor, 1)], focus=(n * 0.5, n * 0.86), focus_r=0.45, focus_k=0.8, wash=-90, rng=rng)
    base = np.array([n * 0.50, n * 0.86])
    shock_ring(cv, base, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.34, n * 0.07, n * 0.03, el, 0.9)
    # the launch pillar: soft rising light, brightest at the floor, speed streaks up the sides
    pil = cv.poly([(n * 0.42, n * 0.12), (n * 0.58, n * 0.12), (n * 0.64, n * 0.86), (n * 0.36, n * 0.86)])
    pil = pil * (0.15 + 0.85 * smoothstep(n * 0.1, n * 0.86, cv.grid()[1]))
    soft_light(cv, pil, el, 0.75, R=n * 0.06, glow_r=6, core_k=0.6)
    for x, y0, y1, w in ((0.30, 0.82, 0.30, 0.016), (0.70, 0.84, 0.36, 0.014), (0.40, 0.70, 0.20, 0.01), (0.60, 0.74, 0.24, 0.01)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    flare_spikes(cv, base[0], base[1] - n * 0.02, [(-90, 1.0), (-120, 0.55), (-60, 0.55), (-150, 0.3), (-30, 0.3)],
                 n * 0.02, n * 0.26, n * 0.035, el, 0.9)
    # the foe tumbling, upside down, flung high
    figure(cv, (n * 0.52, n * 0.30), n * 0.40, 115, ((60, 20), (150, 190)), ((-80, -110), (-40, -10)), "indigo",
           rim_k=1.0)
    hot_core(cv, base[0], base[1] - n * 0.02, el, 2.8, 1.1, star_len=22)


@skill("grappler.back_throw", tone="indigo")
def back_throw(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.76), (n, n), (0, n)])
    hit = np.array([n * 0.30, n * 0.80])
    ground(cv, el, [(floor, 1)], focus=hit, focus_r=0.5, focus_k=0.8, wash=-150, rng=rng)
    # over-the-shoulder arc: from the lower right, over the top, down to the crater at the left
    crescent(cv, (n * 0.54, n * 0.74), n * 0.40, n * 0.56, 0, 10, -170, 0.30, el, 1.0)
    shock_ring(cv, hit, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.34, n * 0.08, n * 0.035, "impact", 1.0)
    for x, y, s, dx in ((0.08, 0.66, 0.05, -1), (0.56, 0.64, 0.045, 1), (0.16, 0.56, 0.035, -1), (0.48, 0.54, 0.03, 1)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-dx * 0.8, 0.6), trail=(dx, -0.5))
    figure(cv, (n * 0.30, n * 0.50), n * 0.42, 95, ((140, 170), (40, 60)), ((-70, -50), (-110, -140)), "indigo", rim_k=1.0)
    hot_core(cv, hit[0], hit[1] - n * 0.02, "impact", 2.6, 1.1, star_len=22)


@skill("grappler.receiving_throw", tone="white")
def receiving_throw(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.50])
    ground(cv, el, [], focus=(n * 0.56, n * 0.44), focus_r=0.45, focus_k=0.7, wash=180, rng=rng)
    speed_lines(cv, rng, 200, 7, "indigo", 0.5, length=(0.25, 0.45), band=(0.15, 0.6))
    # the catch: a white hook that takes the strike and curls it back over and behind
    crescent(cv, (n * 0.46, n * 0.48), n * 0.34, n * 0.34, 0, 40, 300, 0.36, el, 1.0)
    # the incoming armoured fist, knuckles toward the viewer-left
    H = weapon_H((n * 1.02, n * 0.20), (n * 0.40, n * 0.52), 1.0)
    fm = fist(cv, H, "indigo", wrap="#5E6478", plate_mat="steel")
    cv.paint(fm, "#1E2A54", 0.35)   # pull the leather into the indigo key
    hit = np.array([n * 0.36, n * 0.56])
    for a in (150, 190, 230):
        light_streak(cv, hit + _dv(a) * n * 0.05, hit + _dv(a) * n * 0.16, n * 0.016, el, 0.8)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1, star_len=18)


@skill("grappler.fling", tone="indigo")
def fling(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.34), (n, n * 0.30), (n, n * 0.68), (0, n * 0.72)])
    ground(cv, el, [(band, 1)], focus=(n * 0.80, n * 0.48), focus_r=0.45, focus_k=0.7, wash=-4, rng=rng)
    speed_lines(cv, rng, -3, 12, "white", 0.7, length=(0.35, 0.8), band=(0.25, 0.75))
    trail(cv, [(n * 0.02, n * 0.56), (n * 0.30, n * 0.54), (n * 0.56, n * 0.50)], 0.5, n * 0.10, "white", 0.9, core_k=0.6)
    figure(cv, (n * 0.56, n * 0.50), n * 0.48, -6, ((160, 175), (200, 190)), ((172, 178), (190, 200)), el, rim_k=1.0)
    hot_core(cv, n * 0.90, n * 0.48, "white", 2.0, 0.9, star_len=16)


@skill("grappler.flying_hands", tone="impact")
def flying_hands(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.82), (n, n * 0.82), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.24), focus_r=0.45, focus_k=0.6, wash=-90, rng=rng)
    top = np.array([n * 0.50, n * 0.18])
    # two arcs splitting from the grip at the top down into both lower corners
    crescent(cv, (n * 0.50, n * 0.86), n * 0.38, n * 0.68, 0, -88, -172, 0.26, el, 0.9)
    crescent(cv, (n * 0.50, n * 0.86), n * 0.38, n * 0.68, 0, -92, -8, 0.26, el, 0.9)
    for x in (0.18, 0.82):
        shock_ring(cv, np.array([n * x, n * 0.86]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.17, n * 0.05, n * 0.025, el, 0.9)
    figure(cv, (n * 0.20, n * 0.62), n * 0.30, 100, ((150, 180), (30, 60)), ((-60, -40), (-110, -150)), "indigo", rim_k=1.0)
    figure(cv, (n * 0.80, n * 0.62), n * 0.30, 80, ((30, 0), (150, 120)), ((-120, -140), (-70, -30)), "indigo", rim_k=1.0)
    # the double grip: a white-hot knot at the top
    hot_core(cv, top[0], top[1], el, 2.6, 1.1, star_len=20)


@skill("grappler.aerial_twist", tone="white")
def aerial_twist(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.84), (n, n * 0.82), (n, n), (0, n)])
    hit = np.array([n * 0.30, n * 0.86])
    ground(cv, el, [(floor, 1)], focus=(n * 0.40, n * 0.70), focus_r=0.5, focus_k=0.7, wash=-130, rng=rng)
    # the twist: tilted spin smears wrapping round the falling foe, descending like a screw toward the floor
    crescent(cv, (n * 0.50, n * 0.40), n * 0.36, n * 0.12, -28, 160, 480, 0.55, el, 0.9)
    crescent(cv, (n * 0.40, n * 0.64), n * 0.28, n * 0.09, -28, 160, 470, 0.55, "indigo", 0.9)
    for x, y0, y1 in ((0.78, 0.04, 0.30), (0.64, 0.02, 0.22)):
        light_streak(cv, (n * x, n * y0), (n * (x - 0.08), n * y1), n * 0.016, el, 0.6)
    shock_ring(cv, hit, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.26, n * 0.06, n * 0.03, "impact", 0.9)
    figure(cv, (n * 0.40, n * 0.62), n * 0.34, 120, ((-150, -120), (60, 90)), ((-60, -90), (-20, 10)), "indigo", rim_k=1.0)
    dizzy_stars(cv, (n * 0.70, n * 0.70), n * 0.14, n * 0.05, (200, 320, 60), n * 0.04)
    hot_core(cv, hit[0], hit[1] - n * 0.02, "impact", 2.4, 1.0, star_len=18)


@skill("grappler.spinning_throw", tone="indigo")
def spinning_throw(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.54])
    ground(cv, el, [], focus=(n * 0.62, n * 0.36), focus_r=0.5, focus_k=0.6, wash=-30, rng=rng)
    crescent(cv, c, n * 0.42, n * 0.34, -12, 150, 480, 0.34, el, 1.0)
    crescent(cv, c, n * 0.30, n * 0.24, -12, 200, 450, 0.22, "white", 0.55)
    for a in (110, 170, 230):   # bystanders bowled away: debris streaks flung off the ring
        p = c + np.array([math.cos(math.radians(a)) * n * 0.42, math.sin(math.radians(a)) * n * 0.34])
        light_streak(cv, p, p + _dv(a + 60) * n * 0.16, n * 0.022, "impact", 0.8)
        stone_chip(cv, rng, *(p + _dv(a + 60) * n * 0.18), n * 0.03, rng.uniform(0, 360), "impact", hot_dir=-_dv(a + 60))
    # the foe whirled at arm's length, head flung outward along the radius, limbs trailing against the spin
    ang = -58
    p = c + np.array([math.cos(math.radians(ang)) * n * 0.22, math.sin(math.radians(ang)) * n * 0.18])
    figure(cv, p, n * 0.40, ang, ((ang + 120, ang + 140), (ang + 150, ang + 170)), ((ang + 165, ang + 175), (ang + 200, ang + 190)),
           "white", rim_k=1.0)
    hold = c + _dv(ang) * n * 0.04
    for a in (ang + 150, ang + 175, ang + 200):   # motion smears trailing the body
        light_streak(cv, p + _dv(a) * n * 0.10, p + _dv(a) * n * 0.30, n * 0.02, "white", 0.5)
    hot_core(cv, c[0], c[1], "white", 2.6, 1.0, star_len=20)

    def bleed(c2):
        X, Y = c2.grid()
        lx = (X - c[0]) / (n * 0.42)
        ly = (Y - c[1]) / (n * 0.34)
        rho = np.sqrt(lx * lx + ly * ly)
        ring = smoothstep(0.06, 0.0, np.abs(rho - 1.0)) * (Y > c[1])
        c2.add(blur(ring.astype(np.float32), 0.8), KEY["cool"], 0.8)   # the bar's one off-key accent
    return {"bleed": bleed}
