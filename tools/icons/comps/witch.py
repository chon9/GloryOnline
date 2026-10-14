"""魔道学者 Witch (王不留行 / 灭绝星尘). Violet-blue keyed bar: star dust, arcane violet, night blue and gold trim.
The bar's one off-key accent is lava orange, on 熔岩烧瓶 (the flask's element demands it).

Value plan:
  broom_1           the star broom swatting on a diagonal, a crescent of star dust behind it      [broom]
  sweep             the broom low, sweeping a tall fan of star dust straight up                     [broom]
  magic_missile     three arcane missiles on curving comet tails homing in from the left
  lava_flask        a tumbling round flask of glowing lava, spilling into a splash pool below (orange)
  disperse_powder   a pouch at the lower left blowing a wide cone of glittering powder to the right
  shadow_cloak      a huge dark cloak flaring open like grasping hands, violet lining, a void inside
  doll_shururu      the stitched witch-hat doll sitting in pulsing gold taunt rings
  broom_tornado     a spiralling funnel of star dust with brooms whirling in it                     [broom]
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403


def _glints(cv, rng, count, box, size=(0.6, 1.6), c="#FFFFFF"):
    n = cv.n
    X, Y = cv.grid()
    for _ in range(count):
        x = rng.uniform(box[0], box[2]) * n
        y = rng.uniform(box[1], box[3]) * n
        r = rng.uniform(*size)
        cv.add(np.exp(-((X - x) ** 2 + (Y - y) ** 2) / (r * r)), c, 1.1)
        if r > 1.2:
            hot_core_cross(cv, x, y, r * 2.0, "#E8ECFF", 0.6)


@skill("witch.broom_1", tone="star")
def broom_swat(cv, rng, el):
    """the swat leaves a cloud of star dust along its arc (particles, not a blade-like crescent)"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.66, n * 0.32), focus_r=0.5, focus_k=0.6, wash=-40, rng=rng)
    c = np.array([n * 0.30, n * 0.80])
    X, Y = cv.grid()
    dust = np.zeros((cv.w, cv.w), np.float32)
    for i in range(60):
        t = rng.uniform(0, 1)
        a = math.radians(-100 + 70 * t)
        r = n * (0.62 + rng.normal(0, 0.05 + 0.05 * (1 - t)))
        p = c + np.array([math.cos(a), math.sin(a)]) * r
        rr = n * rng.uniform(0.012, 0.035) * (0.4 + t)
        np.maximum(dust, cv.ellipse(p[0], p[1], rr) * (0.3 + 0.7 * t), out=dust)
    cv.add(blur(dust, 2.0), "#6C7BFF", 0.8)
    cv.add(blur(dust, 0.6), "#B8C2FF", 0.6)
    _glints(cv, rng, 18, (0.25, 0.08, 0.95, 0.60))
    star_broom(cv, weapon_H((n * 0.04, n * 0.98), (n * 0.80, n * 0.20), 1.35), "star", rng, spread=1.2)


@skill("witch.sweep", tone="night")
def sweep(cv, rng, el):
    n = cv.n
    low = cv.poly([(0, n * 0.84), (n, n * 0.84), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.50, n * 0.30), focus_r=0.55, focus_k=0.6, wash=-90, rng=rng)
    # tall rising fan of star dust
    for i in range(14):
        a = math.radians(-90 + rng.uniform(-28, 28))
        d = np.array([math.cos(a), math.sin(a)])
        p0 = np.array([n * 0.50, n * 0.78])
        L = n * rng.uniform(0.45, 0.78)
        trail(cv, [p0 + d * n * 0.08, p0 + d * L * 0.6 + np.array([rng.uniform(-1, 1) * n * 0.03, 0]), p0 + d * L], 0.4,
              n * rng.uniform(0.012, 0.03), "star" if i % 3 else "arcane", 0.7, core_k=0.6)
    _glints(cv, rng, 22, (0.20, 0.04, 0.80, 0.60))
    shock_ring(cv, np.array([n * 0.50, n * 0.86]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.32, n * 0.06, n * 0.016, el, 0.6)
    star_broom(cv, weapon_H((n * 1.10, n * 1.02), (n * 0.30, n * 0.70), 1.4), "star", rng, spread=1.0, sparkle=0.5)


@skill("witch.magic_missile", tone="arcane")
def magic_missile(cv, rng, el):
    """three homing missiles arriving from three directions, converging on one target at the right"""
    n = cv.n
    tgt = np.array([n * 0.88, n * 0.46])
    ground(cv, el, [], focus=tgt, focus_r=0.45, focus_k=0.7, wash=-10, rng=rng)
    for start, ctrl, head, w in (((-0.05, 0.10), (0.30, 0.02), (0.62, 0.24), 0.075), ((-0.05, 0.58), (0.30, 0.66), (0.60, 0.52), 0.085),
                                 ((0.20, 1.05), (0.34, 0.80), (0.58, 0.80), 0.07)):
        head = np.array(head) * n
        path = [tuple(np.array(start) * n), tuple(np.array(ctrl) * n), tuple(head)]
        trail(cv, path, 0.5, n * w * 1.1, el, 0.85)
        trail(cv, path, 0.3, n * w * 0.35, "star", 0.8)
        orb = cv.ellipse(head[0], head[1], n * w)
        light_form(cv, orb, el, 1.0, R=n * w * 0.6, glow_r=8, lw=(0.3, 1.6))
        hot_core(cv, head[0] - n * 0.02, head[1] - n * 0.02, el, 1.6, 0.9, star_len=12)
        light_streak(cv, head + (tgt - head) * 0.25, head + (tgt - head) * 0.75, n * 0.012, "star", 0.5)
    shock_ring(cv, tgt, np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * 0.22, n * 0.08, n * 0.02, el, 0.7)
    hot_core(cv, tgt[0], tgt[1], el, 2.0, 0.9, star_len=14)
    _glints(cv, rng, 10, (0.10, 0.10, 0.90, 0.90))


@skill("witch.lava_flask", tone="night")
def lava_flask(cv, rng, el):
    n = cv.n
    lava = "fire"   # the bar's one off-key accent (STATUS_PAL fire)
    pool_m = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(pool_m, 1)], focus=(n * 0.48, n * 0.84), focus_r=0.45, focus_k=0.5, wash=-60, rng=rng)
    # the lava pool + splash below
    pool = cv.ellipse(n * 0.50, n * 0.86, n * 0.40, n * 0.09)
    light_form(cv, pool, lava, 0.9, R=n * 0.03, glow_r=8, lw=(0.3, 1.6))
    for x, y, r in ((0.20, 0.76, 0.03), (0.80, 0.74, 0.035), (0.30, 0.70, 0.02), (0.72, 0.66, 0.02), (0.88, 0.82, 0.02)):
        drop = cv.ellipse(n * x, n * y, n * r, n * r * 1.2)   # lava droplets thrown out of the splash
        light_form(cv, drop, lava, 0.9, R=n * 0.01, glow_r=3, lw=(0.2, 1.0))
    # flask: round glass bulb, long neck, cork; tilted, lava sloshing inside and spilling from the mouth
    H = H_affine((n * 0.46, n * 0.40), 32, 1.0)
    bulb_c = np.array([n * 0.46, n * 0.46])
    bulb = cv.ellipse(bulb_c[0], bulb_c[1], n * 0.22)
    neck = cv.poly(xf(H_affine(bulb_c, -58, 1.0), [(n * 0.14, -n * 0.06), (n * 0.40, -n * 0.05), (n * 0.40, n * 0.05), (n * 0.14, n * 0.06)]))
    glass = union(cv, [bulb, neck])
    X, Y = cv.grid()
    tilt_n = np.array([math.cos(math.radians(-58 + 90)), math.sin(math.radians(-58 + 90))])
    level = ((X - bulb_c[0]) * 0.35 + (Y - bulb_c[1]) * 0.94) > -n * 0.02
    inside = bulb * level
    glow(cv, inside, tone(lava)[1], 10, 0.9)
    paint_form(cv, inside, ["#5A1206", "#C83A10", "#FF9A3A", "#FFF0B0"], R=n * 0.08, grad=0.5, tilt=(0.0, -0.4))
    bub = union(cv, [cv.ellipse(n * x, n * y, n * r) for x, y, r in ((0.40, 0.56, 0.025), (0.52, 0.52, 0.018), (0.46, 0.62, 0.015))])
    cv.add(bub * inside, "#FFF6C0", 0.9)
    ink_line(cv, glass, "#0A1022", 0.35, 1.8, 0.4)
    cv.paint(glass * (1 - inside), "#1A2240", 0.35)
    cv.add(np.clip(glass - toward(glass, 2.0, -LIGHT), 0, 1), "#C8D8FF", 0.6)   # rim light on the glass
    hl = cv.poly(ribbon(arc_pts(bulb_c[0], bulb_c[1], n * 0.16, 200, 250, 12), [n * 0.025] * 12))
    cv.paint(hl * bulb, "#FFFFFF", 0.8)
    mouth = xf(H_affine(bulb_c, -58, 1.0), [(n * 0.40, 0.0)])[0]
    cork = cv.ellipse(mouth[0] + n * 0.06, mouth[1] - n * 0.08, n * 0.04, n * 0.05)
    material(cv, cork, "wood", R=n * 0.02, lw=(0.3, 1.3))
    ring = cv.poly(xf(H_affine(bulb_c, -58, 1.0), [(n * 0.36, -n * 0.07), (n * 0.40, -n * 0.07), (n * 0.40, n * 0.07), (n * 0.36, n * 0.07)]))
    material(cv, ring, "gold", R=n * 0.01, lw=(0.25, 1.1))
    drip = cv.poly(ribbon(spline([mouth, mouth + np.array([n * 0.08, n * 0.02]), mouth + np.array([n * 0.12, n * 0.18]),
                                  mouth + np.array([n * 0.10, n * 0.34])], 6), lambda u: n * 0.035 * (1 - u * 0.6) + 0.5))
    light_form(cv, drip, lava, 1.0, R=n * 0.01, glow_r=4, lw=(0.2, 1.0))


@skill("witch.disperse_powder", tone="arcane")
def disperse_powder(cv, rng, el):
    n = cv.n
    src = np.array([n * 0.20, n * 0.72])
    ground(cv, el, [], focus=(n * 0.70, n * 0.42), focus_r=0.55, focus_k=0.5, wash=-15, rng=rng)
    X, Y = cv.grid()
    dx, dy = X - src[0], Y - src[1]
    ang = np.degrees(np.arctan2(dy, dx))
    r = np.sqrt(dx * dx + dy * dy) / n
    cone = smoothstep(32, 20, np.abs(ang + 22)) * smoothstep(0.05, 0.2, r) * smoothstep(0.95, 0.6, r)
    rays = 0.5 + 0.5 * np.sin(np.radians(ang) * 40.0 + cv.noise * 6.0)
    puff = blur(cone.astype(np.float32) * (0.35 + 0.65 * smoothstep(0.3, 0.7, cv.noise)) * (0.5 + 0.5 * rays), 5)
    cv.add(puff, "#7A6AC0", 0.55)
    cv.add(blur(puff, 2) ** 2, "#E6DEFF", 0.5)
    for i in range(70):   # glitter in the powder
        a = math.radians(-22 + rng.uniform(-26, 26))
        rr = rng.uniform(0.15, 0.85) * n
        p = src + np.array([math.cos(a), math.sin(a)]) * rr
        s = rng.uniform(0.5, 1.6)
        cv.add(np.exp(-((X - p[0]) ** 2 + (Y - p[1]) ** 2) / (s * s)), "#FFFFFF" if i % 3 else "#FFD86A", 1.0)
    # dispelled buff light shattering in the cloud: broken gold rings
    for (x, y, rr) in ((0.70, 0.30, 0.08), (0.80, 0.56, 0.06)):
        segs = [cv.poly(ribbon(arc_pts(n * x, n * y, n * rr, a0, a0 + 50, 10), [n * 0.012] * 10)) for a0 in (0, 90, 200, 290)]
        soft_light(cv, union(cv, segs), "gold", 0.8, R=0.8, glow_r=2)
    # a cloth pouch, mouth toward the cone: round sack, gathered neck, ruffled open mouth, gold drawstring
    sack = cv.poly(closed_spline([(n * 0.02, n * 0.80), (n * 0.08, n * 0.66), (n * 0.20, n * 0.66), (n * 0.24, n * 0.80), (n * 0.16, n * 0.94),
                                  (n * 0.04, n * 0.92)], 6))
    neck = cv.poly([(n * 0.18, n * 0.68), (n * 0.24, n * 0.72), (n * 0.27, n * 0.70), (n * 0.21, n * 0.64)])
    mouth = cv.poly(closed_spline([(n * 0.24, n * 0.64), (n * 0.30, n * 0.62), (n * 0.32, n * 0.70), (n * 0.27, n * 0.74)], 4))
    cloth = ["#1E1036", "#3E2468", "#7A58B0", "#B8A0E6"]
    allm = union(cv, [sack, neck, mouth])
    ink_line(cv, allm, "#0A0418", 0.35, 1.8, 0.3)
    paint_form(cv, sack, cloth, R=n * 0.05, grad=0.6)
    paint_form(cv, mouth, cloth, R=n * 0.015, grad=0.5)
    cv.paint(cv.ellipse(n * 0.285, n * 0.675, n * 0.02, n * 0.028), "#0A0418", 0.9)
    tie = cv.poly(ribbon([(n * 0.17, n * 0.70), (n * 0.25, n * 0.66)], [n * 0.025] * 2))
    material(cv, tie, "gold", R=n * 0.01, lw=(0.2, 0.9))
    for pts in (((0.08, 0.74), (0.12, 0.86)), ((0.14, 0.72), (0.18, 0.84))):   # cloth folds
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.015, n * 0.005) * sack, "#140A28", 0.6)


@skill("witch.shadow_cloak", tone="night")
def shadow_cloak(cv, rng, el):
    """a huge clawed hand of shadow reaching out of a billowing dark cloak, violet rim light, a void at its palm"""
    n = cv.n
    ground(cv, "arcane", [], focus=(n * 0.56, n * 0.42), focus_r=0.5, focus_k=0.7, ink="#030208", wash=-60, rng=rng)
    cloak = cv.poly(closed_spline([(n * -0.05, n * 0.30), (n * 0.20, n * 0.50), (n * 0.40, n * 0.66), (n * 0.62, n * 0.90), (n * 0.40, n * 1.06),
                                   (n * -0.05, n * 1.06)], 6))
    ink_line(cv, cloak, "#020106", 0.4, 2.2, 0.3)
    paint_form(cv, cloak, ["#030208", "#0C0A1E", "#1E1A44", "#3A3480"], R=n * 0.06, grad=0.6)
    lin = cv.poly(ribbon(spline([(n * 0.02, n * 0.40), (n * 0.22, n * 0.58), (n * 0.40, n * 0.74), (n * 0.54, n * 0.92)], 6),
                         lambda u: n * 0.05 * math.sin(math.pi * u) + 0.4)) * cloak
    paint_form(cv, lin, ["#2A1450", "#5A2EA8", "#9A6AF0", "#C8A8FF"], R=n * 0.012, grad=0.5)
    # the hand: palm toward the viewer, five long clawed fingers spread and curling in
    wrist = np.array([n * 0.30, n * 0.66])
    palm_c = np.array([n * 0.48, n * 0.46])
    palm = cv.poly(closed_spline([wrist + np.array([-n * 0.06, n * 0.04]), palm_c + np.array([-n * 0.16, -n * 0.02]),
                                  palm_c + np.array([n * 0.02, -n * 0.14]), palm_c + np.array([n * 0.14, n * 0.04]),
                                  wrist + np.array([n * 0.10, n * 0.06])], 6))
    parts = [palm]
    claws = []
    for i, (a, L) in enumerate(((-165, 0.22), (-112, 0.34), (-88, 0.38), (-64, 0.34), (-40, 0.27))):
        ar = math.radians(a)
        base = palm_c + np.array([math.cos(ar), math.sin(ar)]) * n * 0.11
        d = np.array([math.cos(ar), math.sin(ar)])
        nv = np.array([-d[1], d[0]])
        k1 = base + d * n * L * 0.5
        tip = base + d * n * L * 0.85 + nv * n * 0.05   # fingertips curl inward
        fw = n * (0.085 if i == 0 else 0.072)
        parts.append(cv.poly(ribbon(spline([base, k1, tip], 6), lambda u: fw * (1 - u * 0.45) + 0.4)))
        parts.append(cv.ellipse(k1[0], k1[1], fw * 0.55))   # knuckle
        claws.append(stroke(cv, [tip, tip + d * n * 0.04 + nv * n * 0.03, tip + d * n * 0.05 + nv * n * 0.08], n * 0.03, 0.4))
    hand = union(cv, parts)
    glow(cv, hand, "#7A4CD8", 8, 0.5)
    ink_line(cv, hand, "#020106", 0.35, 2.0, 0.3)
    paint_form(cv, hand, ["#05040E", "#14123A", "#2A2668", "#4A44A0"], R=n * 0.025, grad=0.6)
    cv.add(np.clip(hand - toward(hand, 1.6, LIGHT), 0, 1), "#B48CFF", 0.9)
    for cm in claws:
        material(cv, cm, "lacquer", R=n * 0.008, lw=(0.2, 0.9), back="#B48CFF", back_k=0.8)
    cv.add(blur(cv.ellipse(palm_c[0], palm_c[1] + n * 0.03, n * 0.09), 4) * hand, "#7A4CD8", 0.6)   # violet glow pooled in the palm


@skill("witch.doll_shururu", tone="gold")
def doll(cv, rng, el):
    """修鲁鲁: a slumped rag doll in a little witch robe and hat, yarn hair, button eyes, stitched patch; taunt rings"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.60])
    ground(cv, "night", [], focus=c, focus_r=0.5, focus_k=0.5, wash=-60, rng=rng)
    for r, k in ((0.34, 0.7), (0.44, 0.45)):   # pulsing taunt rings
        shock_ring(cv, c + np.array([0, n * 0.12]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.36, n * 0.02, el, k)
    tan = ["#4A3424", "#8A6A4E", "#C8A888", "#ECD6BC"]
    legs = union(cv, [cv.poly(ribbon([(n * x0, n * 0.80), (n * x1, n * 0.90)], [n * 0.07, n * 0.06])) for x0, x1 in ((0.42, 0.34), (0.58, 0.68))])
    ink_line(cv, legs, "#1A0E06", 0.3, 1.5, 0.3)
    paint_form(cv, legs, tan, R=n * 0.02, grad=0.5)
    for x, y in ((0.34, 0.90), (0.68, 0.90)):   # cloth shoes
        sh = cv.ellipse(n * x, n * y, n * 0.05, n * 0.035)
        material(cv, sh, "cloth_red", R=n * 0.01, lw=(0.25, 1.1))
    robe = cv.poly(closed_spline([(n * 0.42, n * 0.52), (n * 0.58, n * 0.52), (n * 0.70, n * 0.86), (n * 0.50, n * 0.82), (n * 0.30, n * 0.86)], 6))
    material(cv, robe, "navy", R=n * 0.05, lw=(0.35, 1.8), back="#8C9BFF", back_k=0.6)
    hemm = cv.poly(ribbon(spline([(n * 0.31, n * 0.83), (n * 0.50, n * 0.79), (n * 0.69, n * 0.83)], 6), [n * 0.025] * 3)) * robe
    material(cv, hemm, "gold", R=n * 0.008, line=False)
    arms = union(cv, [cv.poly(ribbon([(n * 0.43, n * 0.56), (n * 0.32, n * 0.72)], [n * 0.06, n * 0.05])),
                      cv.poly(ribbon([(n * 0.57, n * 0.56), (n * 0.68, n * 0.72)], [n * 0.06, n * 0.05]))])
    material(cv, arms, "navy", R=n * 0.02, lw=(0.3, 1.4))
    for x in (0.32, 0.68):
        h = cv.ellipse(n * x, n * 0.74, n * 0.03)
        paint_form(cv, h, tan, R=n * 0.01, grad=0.5)
    head = cv.ellipse(n * 0.50, n * 0.42, n * 0.14, n * 0.13)
    hair = union(cv, [cv.poly(ribbon(spline([(n * (0.40 + 0.05 * i), n * 0.34), (n * (0.36 + 0.06 * i), n * 0.46), (n * (0.34 + 0.07 * i), n * 0.54)], 4),
                                          lambda u: n * 0.022 * (1 - u) + 0.4)) for i in (0, 4)])
    ink_line(cv, union(cv, [head, hair]), "#1A0E06", 0.35, 1.8, 0.3)
    paint_form(cv, head, tan, R=n * 0.06, grad=0.5)
    paint_form(cv, hair, ["#5A3A10", "#A8782A", "#E8C060", "#FFF0B0"], R=n * 0.01, grad=0.5)
    for x in (0.45, 0.56):   # button eyes with thread crosses
        b = cv.ellipse(n * x, n * 0.42, n * 0.026)
        material(cv, b, "lacquer", R=n * 0.01, lw=(0.2, 0.8))
        cv.paint(cv.poly(ribbon([(n * (x - 0.012), n * 0.408), (n * (x + 0.012), n * 0.432)], [n * 0.005] * 2)), "#C8B8A0", 0.7)
    cv.paint(cv.poly(ribbon([(n * 0.46, n * 0.49), (n * 0.54, n * 0.49)], [n * 0.007] * 2)) * head, "#3A2418", 0.85)
    for x in (0.47, 0.50, 0.53):
        cv.paint(cv.poly(ribbon([(n * x, n * 0.475), (n * x, n * 0.505)], [n * 0.005] * 2)) * head, "#3A2418", 0.75)
    patch = cv.poly([(n * 0.52, n * 0.62), (n * 0.62, n * 0.61), (n * 0.63, n * 0.70), (n * 0.53, n * 0.71)]) * robe
    material(cv, patch, "cloth_red", R=n * 0.01, line=False)
    hat = cv.poly(spline([(n * 0.32, n * 0.34), (n * 0.46, n * 0.29), (n * 0.54, n * 0.10), (n * 0.66, n * 0.04), (n * 0.62, n * 0.14),
                          (n * 0.58, n * 0.29), (n * 0.70, n * 0.34), (n * 0.50, n * 0.37)], 4))
    material(cv, hat, "navy", R=n * 0.04, lw=(0.35, 1.8), back="#8C9BFF", back_k=0.6)
    band = cv.poly([(n * 0.45, n * 0.28), (n * 0.58, n * 0.28), (n * 0.59, n * 0.32), (n * 0.44, n * 0.32)]) * hat
    material(cv, band, "gold", R=n * 0.01, line=False)


@skill("witch.broom_tornado", tone="star")
def broom_tornado(cv, rng, el):
    n = cv.n
    ground(cv, "night", [], focus=(n * 0.5, n * 0.40), focus_r=0.55, focus_k=0.7, ink="#04040C", wash=-80, rng=rng)
    # funnel: stacked elliptical star-dust rings widening upward, drawn back to front
    for i in range(9):
        t = i / 8.0
        y = n * (0.92 - 0.80 * t)
        rx = n * (0.08 + 0.38 * t ** 1.2)
        ry = rx * 0.26
        xo = n * 0.05 * math.sin(t * 5.0)
        crescent(cv, (n * 0.5 + xo, y), rx, ry, 0, 200 + 40 * i, 200 + 40 * i + 300, 0.45, "star" if i % 2 else "arcane", 0.55)
    _glints(cv, rng, 26, (0.1, 0.05, 0.9, 0.9))
    for (x, y, a, L) in ((0.24, 0.30, -20, 0.36), (0.74, 0.52, 160, 0.30)):   # brooms whirled in the storm
        p = np.array([n * x, n * y])
        ar = math.radians(a)
        d = np.array([math.cos(ar), math.sin(ar)])
        star_broom(cv, weapon_H(p - d * n * L * 0.5, p + d * n * L * 0.5, 1.4), "star", rng, spread=0.9, sparkle=0.4)
    hot_core(cv, n * 0.5, n * 0.86, el, 2.0, 0.9, star_len=16)
