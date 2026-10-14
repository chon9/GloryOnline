"""剑客 Blade Master (夜雨声烦 / 冰雨). Cool-keyed bar: ice, azure, steel and moon light on a deep-navy ground,
with the class's royal-blue cape (white lining) as the painted non-weapon mass. The bar's one off-key accent is warm
gold, on the ultimate.

Value plan:
  atk1                    冰雨 mid-swing on a diagonal, crescent smear behind it                 [blade]
  upward_slash            a tall "(" crescent rising up the right side, ice shards flung up
  triple_slash            a steel breastplate cut by three parallel diagonal slashes, sliding apart
  sword_draw              a flat ring of draw-slash light + a thick sword-qi crescent flying right
  falling_phoenix_slash   a broad-winged phoenix of ice light diving down-left into a cracked crater
  lunge                   the blade thrusting right with a fan of ghost stabs, sparks            [blade]
  guard                   the blade braced diagonally in front of the swirling royal-blue cape   [blade]
  formless_phantom_blade  a peacock fan of phantom blades spreading from one hilt, gold rim      [blade]
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403

HALO, BODY, CORE = "#2F9BFF", "#7FE8FF", "#FFFFFF"
CAPE = ["#040816", "#0B1C46", "#174694", "#3E7ACC"]
LINING = ["#4A5470", "#A9B3D6", "#E6EAF4", "#FFFFFF"]


def _ghost_blade(cv, H, el, k=0.6):
    """an afterimage of the energy blade: soft light only, no hilt"""
    bl = lpoly(cv, H, [(0.19, -0.016), (0.92, -0.016), (1.0, 0.0), (0.92, 0.016), (0.19, 0.016)])
    soft_light(cv, bl, el, k, R=max(0.8, lR(H, 0.01)), glow_r=4, core_k=0.6)
    return bl


def _shard(cv, x, y, s, ang, k=1.0):
    a = math.radians(ang)
    d = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-d[1], d[0]])
    p = np.array([x, y])
    m = cv.poly([p - d * s * 0.6, p + nv * s * 0.22, p + d * s, p - nv * s * 0.18])
    glow(cv, m, BODY, 2, 0.4 * k)
    ink_line(cv, m, "#0A2A40", 0.2, 1.0, 0.3)
    paint_form(cv, m, ["#3C7EAA", "#8CCBE6", "#DDF6FF", "#FFFFFF"], R=s * 0.15, tilt=tuple(LIGHT2 * 0.4), grad=0.5)
    return m


def cape(cv, outer, lining_edge, folds, rim_el=None):
    """the royal-blue cape as a painted cloth mass: 4-value form, fold shadows, white lining along one edge.
    outer: closed outline points; lining_edge: polyline (inside the outline) the lining shows along;
    folds: list of polylines for fold shadows."""
    n = cv.n
    m = cv.poly(closed_spline(outer, 6))
    ink_line(cv, m, "#02040C", 0.45, 2.4, 0.35)
    X, Y = cv.grid()
    proj = (X * 0.8 + Y * 0.6) / n
    folds_f = 0.24 * np.sin(proj * 9.0 + 0.8 * np.sin(Y / n * 5.0)) - 0.15 * smoothstep(0.3, 1.0, Y / n)
    paint_form(cv, m, CAPE, R=n * 0.05, grad=0.7, tilt=(-0.1, -0.2), field=folds_f, thr=[0.18, 0.46, 0.80], soft=0.14, wobble=0.03)
    f = streak_field(cv.w, -60, 70, 4, cv.seed())
    cv.c *= (1 + 0.10 * (f - 0.5) * 2 * m)[..., None]
    for fp in folds:
        fm = cv.poly(ribbon(spline(fp, 6), lambda u: n * 0.035 * math.sin(math.pi * u) + 0.4))
        cv.paint(blur(fm, 1.2) * m, CAPE[0], 0.7)
        hl = cv.poly(ribbon(spline([(x - n * 0.02, y - n * 0.01) for x, y in fp], 6), lambda u: n * 0.012 * math.sin(math.pi * u) + 0.3))
        cv.paint(blur(hl, 0.6) * m, CAPE[3], 0.5)
    lm = cv.poly(ribbon(spline(lining_edge, 6), lambda u: n * (0.04 + 0.03 * math.sin(math.pi * u)))) * m
    paint_form(cv, lm, LINING, R=n * 0.02, grad=0.5)
    if rim_el:
        cv.add(m * (1 - toward(m, 1.6, LIGHT)), tone(rim_el)[2], 0.6)
    return m


@skill("blade_master.atk1", tone="ice")
def quick_slash(cv, rng, el):
    n = cv.n
    mass = cv.poly([(0, n * 0.55), (n * 0.5, n * 0.95), (0, n)])
    ground(cv, el, [(mass, 1)], focus=(n * 0.66, n * 0.36), focus_r=0.5, focus_k=0.6, wash=-35, rng=rng)
    crescent(cv, (n * 0.44, n * 0.56), n * 0.46, n * 0.30, -32, 150, 335, 0.34, el, 0.9)
    for x, y, s, a in ((0.80, 0.62, 0.06, 20), (0.70, 0.78, 0.045, 50), (0.90, 0.44, 0.04, -10)):
        _shard(cv, n * x, n * y, n * s, a, 0.8)
    light_sword(cv, weapon_H((n * 0.10, n * 0.92), (n * 0.86, n * 0.20), 1.25))
    hot_core(cv, n * 0.84, n * 0.22, el, 2.2, 0.9, star_len=16, ang=-42)


@skill("blade_master.upward_slash", tone="azure")
def upward_slash(cv, rng, el):
    n = cv.n
    low = cv.poly([(0, n * 0.84), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.36, n * 0.22), focus_r=0.5, focus_k=0.6, wash=-80, rng=rng)
    crescent(cv, (n * 0.74, n * 0.58), n * 0.56, n * 0.50, 0, 85, 242, 0.48, el, 1.0)
    for x, y0, y1, w in ((0.46, 0.84, 0.30, 0.02), (0.58, 0.72, 0.38, 0.014), (0.36, 0.90, 0.52, 0.012)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.7)
    for x, y, s, a in ((0.20, 0.30, 0.12, -100), (0.42, 0.14, 0.09, -70), (0.62, 0.30, 0.08, -120), (0.12, 0.56, 0.07, -95)):
        _shard(cv, n * x, n * y, n * s, a)
    shock_ring(cv, np.array([n * 0.56, n * 0.88]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.30, n * 0.05, n * 0.014, el, 0.6)
    hot_core(cv, n * 0.30, n * 0.14, el, 2.4, 1.0, star_len=18)


@skill("blade_master.triple_slash", tone="steel")
def triple_slash(cv, rng, el):
    """a breastplate (steel, gold trim) cut by three parallel slashes; the four slices slide apart along the cuts"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.5, n * 0.5), focus_r=0.55, focus_k=0.6, ink="#04060C", wash=-35, rng=rng)
    speed_lines(cv, rng, -35, 7, "azure", 0.4, band=(0.1, 0.9))
    plate = closed_spline([(n * 0.18, n * 0.22), (n * 0.40, n * 0.16), (n * 0.50, n * 0.22), (n * 0.60, n * 0.16), (n * 0.82, n * 0.22),
                           (n * 0.80, n * 0.52), (n * 0.70, n * 0.76), (n * 0.50, n * 0.90), (n * 0.30, n * 0.76), (n * 0.20, n * 0.52)], 6)
    base = cv.poly(plate)
    ang = -35.0
    d = np.array([math.cos(math.radians(ang)), math.sin(math.radians(ang))])
    nv = np.array([-d[1], d[0]])
    X, Y = cv.grid()
    proj = (X - n * 0.5) * nv[0] + (Y - n * 0.52) * nv[1]
    offs = [-0.20, -0.02, 0.17]
    bands = []
    edges = [-1e9] + [o * n for o in offs] + [1e9]
    for i in range(4):
        sl = base * ((proj > edges[i] + n * 0.012) & (proj < edges[i + 1] - n * 0.012))
        shift_v = d * n * (0.035 * (i - 1.5))
        sl = shift(sl, int(round(shift_v[0] * SS)), int(round(shift_v[1] * SS)))
        bands.append(sl)
    for i, sl in enumerate(bands):
        material(cv, sl, "plate", R=n * 0.07, lw=(0.35, 1.8), grad=0.5, tilt=(0.1 * (i - 1.5), -0.2), back=BODY, back_k=0.6)
        trim = np.clip(sl - (blur(sl, n * 0.025) > 0.97), 0, 1) * (Y < n * 0.32)
        material(cv, trim, "gold", R=n * 0.01, line=False)
    for o in offs:   # the cuts: ice light along each line, overshooting the plate
        a = np.array([n * 0.5, n * 0.52]) + nv * o * n - d * n * 0.62
        b = np.array([n * 0.5, n * 0.52]) + nv * o * n + d * n * 0.62
        m = cv.poly(ribbon([a, a + (b - a) * 0.4, a + (b - a) * 0.75, b], [0.4, n * 0.03, n * 0.04, 0.4]))
        glow(cv, m, HALO, 5, 0.7)
        soft_light(cv, m, "ice", 1.0, R=n * 0.01, glow_r=3, core_k=1.1)
    hot_core(cv, n * 0.66, n * 0.40, "ice", 2.0, 0.9, star_len=16, ang=ang)


@skill("blade_master.sword_draw", tone="ice")
def draw_ring(cv, rng, el):
    n = cv.n
    disc = cv.ellipse(n * 0.36, n * 0.66, n * 0.40, n * 0.14)
    ground(cv, el, [(disc, 1)], focus=(n * 0.70, n * 0.48), focus_r=0.5, focus_k=0.6, wash=0, rng=rng)
    crescent(cv, (n * 0.34, n * 0.62), n * 0.32, n * 0.12, -4, 200, 500, 0.6, el, 0.9, streak_freq=110)
    # the released sword-qi: a thick crescent of ice light flying right, frost crystallising in its wake
    qc = np.array([n * 0.66, n * 0.46])
    moon = np.clip(cv.ellipse(qc[0], qc[1], n * 0.16, n * 0.34) - cv.ellipse(qc[0] - n * 0.08, qc[1], n * 0.14, n * 0.31), 0, 1)
    moon = moon * (cv.grid()[0] > qc[0] - n * 0.07)
    light_form(cv, moon, el, 1.0, R=n * 0.03, glow_r=8, lw=(0.3, 1.8))
    for y in (0.26, 0.38, 0.54, 0.66):
        light_streak(cv, (n * 0.30, n * (y + 0.02)), (n * 0.62, n * y), n * 0.012, el, 0.6)
    for x, y, s, a in ((0.44, 0.30, 0.05, 180), (0.40, 0.56, 0.045, 170), (0.50, 0.42, 0.04, 190)):
        _shard(cv, n * x, n * y, n * s, a, 0.7)
    hot_core(cv, qc[0] + n * 0.15, qc[1], el, 2.4, 1.0, star_len=18)


@skill("blade_master.falling_phoenix_slash", tone="moon")
def falling_phoenix(cv, rng, el):
    n = cv.n
    pal = tone(el)
    floor = cv.poly([(0, n * 0.80), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.36, n * 0.84), focus_r=0.45, focus_k=0.8, wash=-60, rng=rng)
    impact = np.array([n * 0.34, n * 0.86])
    shock_ring(cv, impact, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.34, n * 0.07, n * 0.03, "ice", 1.0)
    for a in (-175, -150, -30, -5):
        ar = math.radians(a)
        p1 = impact + np.array([math.cos(ar) * n * 0.38, math.sin(ar) * n * 0.07])
        soft_light(cv, cv.poly(ribbon([impact, p1], [n * 0.014, 0.4])), "ice", 0.8, R=0.8, glow_r=3)
    # diving down-left: body axis from the upper right to the impact; wings broad feather fans swept back
    ax = np.array([-0.55, 0.83])
    ax = ax / np.linalg.norm(ax)
    side = np.array([-ax[1], ax[0]])
    head = np.array([n * 0.40, n * 0.74])
    for j in range(3):   # long tail plumes streaming back up-right, curling at the ends
        p0 = head - ax * n * 0.20
        q = [p0, p0 - ax * n * 0.28 + side * n * (0.06 * (j - 1)), p0 - ax * n * 0.55 + side * n * (0.16 * (j - 1)),
             p0 - ax * n * 0.66 + side * n * (0.16 * (j - 1) + 0.08)]
        tail = cv.poly(ribbon(spline(q, 8), lambda u: n * 0.06 * (1 - u) ** 0.5 + 0.5))
        light_form(cv, tail, "ice", 0.8, R=n * 0.015, glow_r=4, lw=(0.2, 1.2), value=0.85)
    feathers = []
    for sx, span in ((1, 0.50), (-1, 0.36)):   # near wing (right) larger than the far wing
        shoulder = head - ax * n * 0.14 + side * sx * n * 0.04
        # arm line: out from the shoulder, swept back toward the tail
        out = side * sx * 0.80 - ax * 0.60
        out = out / np.linalg.norm(out)
        wrist = shoulder + out * n * span * 0.55 + ax * n * 0.02
        tipw = shoulder + out * n * span
        arm = cv.poly(ribbon(spline([shoulder, wrist, tipw], 6), lambda u: n * 0.07 * (1 - u * 0.6) + 0.5))
        feathers.append(arm)
        for j in range(5):   # broad, round-tipped flight feathers trailing back from the arm
            t = j / 4.0
            base = shoulder + (tipw - shoulder) * (0.15 + 0.85 * t)
            back = -ax * (0.9 - 0.3 * t) + out * 0.35 * t
            back = back / np.linalg.norm(back)
            L = n * (0.18 + 0.12 * math.sin(math.pi * (0.3 + 0.7 * t))) * (span / 0.5)
            tip = base + back * L
            pts = spline([base, base + back * L * 0.6 + side * sx * n * 0.01, tip], 6)
            fw = n * 0.10
            feathers.append(union(cv, [cv.poly(ribbon(pts, lambda u: fw * (1 - 0.35 * u) + 0.6)), cv.ellipse(tip[0], tip[1], fw * 0.33)]))
    wings = union(cv, feathers)
    light_form(cv, wings, "ice", 0.95, R=n * 0.03, glow_r=8, lw=(0.3, 2.0))
    for fm in feathers[1:]:   # feather separation: a darker edge on each feather's shadow side
        cv.paint(np.clip(fm - toward(fm, 1.2, LIGHT), 0, 1) * wings, mix(pal[0], pal[1], 0.6), 0.55)
    body = cv.poly(closed_spline([head + ax * n * 0.07, head - ax * n * 0.06 + side * n * 0.06, head - ax * n * 0.22 + side * n * 0.04,
                                  head - ax * n * 0.22 - side * n * 0.04, head - ax * n * 0.06 - side * n * 0.06], 6))
    light_form(cv, body, "ice", 1.0, R=n * 0.03, glow_r=6, lw=(0.3, 1.8))
    beak = cv.poly([head + side * n * 0.022, head + ax * n * 0.13, head - side * n * 0.022])
    material(cv, beak, "gold", R=n * 0.01, lw=(0.25, 1.1))
    hot_core(cv, impact[0], impact[1] - n * 0.04, "ice", 2.6, 1.2, star_len=24)


@skill("blade_master.lunge", tone="azure")
def lunge(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.30), (n, n * 0.34), (n, n * 0.68), (0, n * 0.72)])
    ground(cv, el, [(band, 1)], focus=(n * 0.88, n * 0.50), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    for oy, k in ((-0.22, 0.45), (-0.11, 0.6), (0.11, 0.6), (0.22, 0.45)):
        H = weapon_H((n * -0.30, n * (0.50 + oy * 0.4)), (n * (0.86 - abs(oy) * 0.3), n * (0.50 + oy)), 1.1)
        _ghost_blade(cv, H, el, k)
        tp = xf(H, [(1.0, 0.0)])[0]
        hot_core(cv, tp[0], tp[1], el, 1.0, 0.6, star_len=8)
    light_sword(cv, weapon_H((n * -0.12, n * 0.52), (n * 0.90, n * 0.50), 1.3))
    sparks(cv, rng, (n * 0.90, n * 0.50), 7, n * 0.12, el, 0.8, a_range=(-70, 70))
    hot_core(cv, n * 0.90, n * 0.50, el, 2.4, 1.1, star_len=18)


@skill("blade_master.guard", tone="steel")
def guard(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.62, n * 0.30), focus_r=0.5, focus_k=0.6, wash=-60, rng=rng)
    cape(cv, [(n * 0.10, n * 0.16), (n * 0.40, n * 0.06), (n * 0.62, n * 0.20), (n * 0.86, n * 0.50), (n * 1.02, n * 0.86),
              (n * 0.70, n * 1.02), (n * 0.40, n * 0.94), (n * 0.14, n * 1.02), (n * 0.02, n * 0.60)],
         [(n * 0.70, n * 0.40), (n * 0.88, n * 0.66), (n * 0.98, n * 0.86)],
         [[(n * 0.20, n * 0.30), (n * 0.30, n * 0.60), (n * 0.26, n * 0.92)], [(n * 0.44, n * 0.30), (n * 0.56, n * 0.62), (n * 0.60, n * 0.96)],
          [(n * 0.10, n * 0.50), (n * 0.12, n * 0.80)]], rim_el="ice")
    H = weapon_H((n * 0.20, n * 0.86), (n * 0.94, n * 0.16), 1.35)
    light_sword(cv, H)
    hit = xf(H, [(0.70, -0.02)])[0]
    for a in (-160, -130, -100, -70):
        ar = math.radians(a)
        light_streak(cv, hit, hit + np.array([math.cos(ar), math.sin(ar)]) * n * 0.24, n * 0.02, "ice", 0.9)
    shock_ring(cv, hit, np.array([0.7, -0.7]), np.array([0.7, 0.7]), n * 0.14, n * 0.07, n * 0.02, "ice", 0.8, 180, 360)
    hot_core(cv, hit[0], hit[1], "ice", 2.4, 1.1, star_len=18)


@skill("blade_master.formless_phantom_blade", tone="ice")
def phantom_blade(cv, rng, el):
    n = cv.n
    hilt = np.array([n * 0.16, n * 0.88])
    ground(cv, "azure", [], focus=(n * 0.60, n * 0.36), focus_r=0.55, focus_k=0.8, ink="#03050C", wash=-45, rng=rng)
    tips = []
    for i, a in enumerate(np.linspace(-100, 5, 8)):   # a peacock fan of phantom blades spreading from one hilt
        ar = math.radians(a)
        tip = hilt + np.array([math.cos(ar), math.sin(ar)]) * n * 0.86
        tips.append(tip)
        _ghost_blade(cv, weapon_H(hilt, tip, 1.15), "azure" if i % 2 else el, 0.55 + 0.05 * (i % 3))
    crescent(cv, hilt, n * 0.80, n * 0.80, 0, -100, 5, 0.10, el, 0.6)
    light_sword(cv, weapon_H(hilt - np.array([n * 0.06, -n * 0.06]), hilt + np.array([math.cos(math.radians(-47)), math.sin(math.radians(-47))]) * n * 0.86,
                             1.4))
    tp = hilt + np.array([math.cos(math.radians(-47)), math.sin(math.radians(-47))]) * n * 0.80
    hot_core(cv, tp[0], tp[1], el, 2.8, 1.2, star_len=22)

    def bleed(c2):
        X, Y = c2.grid()
        r = np.sqrt((X - hilt[0]) ** 2 + (Y - hilt[1]) ** 2)
        a = np.degrees(np.arctan2(Y - hilt[1], X - hilt[0]))
        ring = np.exp(-((r - n * 0.84) ** 2) / (n * 0.012) ** 2) * ((a > -100) & (a < 5))
        c2.add(ring.astype(np.float32), KEY["cool"], 0.7)   # the bar's one off-key accent: a warm gold arc at the fan's edge
    return {"bleed": bleed}
