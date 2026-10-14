"""骑士 Knight. Steel-and-azure keyed bar: brushed steel, azure light, navy tabard cloth.
The bar's one off-key accent is the key's `cool` gold, used only on the ultimate 十字军审判 (the holy smash).

Value plan:
  atk1              the knight's sword held level across the frame inside a wide horizontal cut smear      [sword]
  shield_attack     the tower shield driven up on a steep diagonal, rising smear under it, launch burst on top
  charge            the shield seen edge-on, a tall narrow slab on the right with long horizontal dash trails
  repel             a plated fist punching at the viewer, a cone of pressure rings blasting debris to the right
  roar              a barrel great-helm dead centre, concentric roar arcs radiating to both sides
  shield_counter    the shield face-on and tilted, a spell bolt striking it and bouncing back off a spark ring
  heroic_leap       a tall parabolic leap trail ending in a crater burst at the lower right, stone chips flying
  crusaders_trial   the sword plunged point-down into the ground before a huge gold cross of light            [sword]
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403

AZ = "#7FB4FF"
CLOTH = ["#060C1C", "#10224A", "#1E3E7A", "#3A64A8"]


def _shield(cv, c, size, ang, sx=1.0, el="azure", rim_k=1.0):
    """tower (heater-topped) shield: navy cloth face with fold shading, a broad brushed-steel rim, a steel boss and a
    steel bar down the middle. Local: width 1, height ~1.45, centre at c; sx < 1 foreshortens it (turned away)."""
    H = H_affine(c, ang, size * sx, size)
    pts = closed_spline([(-0.50, -0.66), (0.0, -0.72), (0.50, -0.66), (0.52, -0.10), (0.42, 0.34), (0.0, 0.76), (-0.42, 0.34),
                         (-0.52, -0.10)], 8)
    out = cv.poly(xf(H, pts))
    inner = cv.poly(xf(H, pts * 0.84))
    rim = np.clip(out - inner, 0, 1)
    ink_line(cv, out, "#04060C", 0.45, 2.4, 0.35)
    X, Y = cv.grid()
    folds = (0.10 * np.sin((X - c[0]) / size * 7.0 + cv.noise * 4)).astype(np.float32)
    paint_form(cv, inner, CLOTH, R=size * 0.25, grad=0.6, field=folds)
    border = np.clip(cv.poly(xf(H, pts * 0.74)) - cv.poly(xf(H, pts * 0.68)), 0, 1)
    material(cv, border, "steel", R=size * 0.02, lw=(0.15, 0.8))
    spine = cv.poly(xf(H, [(-0.035, -0.50), (0.035, -0.50), (0.03, 0.50), (-0.03, 0.50)])) * inner
    material(cv, spine, "steel", R=size * 0.02, lw=(0.2, 0.9))
    material(cv, rim, "steel", R=size * 0.05, line=False, grad=0.5, back=AZ, back_k=0.8 * rim_k)
    bc = xf(H, [(0.0, -0.10)])[0]
    boss = cv.ellipse(bc[0], bc[1], size * sx * 0.16, size * 0.16)
    material(cv, boss, "steel", R=size * 0.08, lw=(0.25, 1.3))
    for p in ((-0.40, -0.55), (0.40, -0.55), (-0.36, 0.25), (0.36, 0.25), (0.0, 0.62)):   # rivets on the rim
        q = xf(H, [p])[0]
        rv = cv.ellipse(q[0], q[1], max(0.8, size * 0.025))
        material(cv, rv, "steel", R=max(0.6, size * 0.015), lw=(0.15, 0.6))
    return out


def _knight_sword(cv, butt, tip, el, rune=AZ, scale=1.0):
    return sword(cv, weapon_H(butt, tip, scale), el, blade="broad", guard="cross", guard_mat="steel", width=0.042, blade_from=0.22,
                 rune=rune)


@skill("knight.atk1", tone="steel")
def atk1(cv, rng, el):
    n = cv.n
    ground(cv, "azure", [], focus=(n * 0.70, n * 0.46), focus_r=0.55, focus_k=0.6, wash=0, rng=rng)
    crescent(cv, (n * 0.46, n * 0.78), n * 0.66, n * 0.44, -6, 196, 340, 0.42, "azure", 1.2)
    speed_lines(cv, rng, -6, 7, "azure", 0.45, length=(0.25, 0.5), band=(0.25, 0.75))
    _knight_sword(cv, (n * 0.02, n * 0.66), (n * 0.94, n * 0.46), el, scale=1.6)
    hot_core(cv, n * 0.86, n * 0.42, "azure", 2.0, 1.0, star_len=16)


@skill("knight.shield_attack", tone="azure")
def shield_attack(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.66, n * 0.22), focus_r=0.5, focus_k=0.7, wash=-70, rng=rng)
    crescent(cv, (n * 0.82, n * 0.86), n * 0.70, n * 0.60, 0, 160, 262, 0.30, el, 1.0)
    for i in range(7):
        x = n * rng.uniform(0.20, 0.95)
        y = n * rng.uniform(0.40, 0.90)
        light_streak(cv, (x, y), (x + n * 0.04, y - n * rng.uniform(0.18, 0.32)), n * 0.012, el, 0.6)
    flare_spikes(cv, n * 0.66, n * 0.16, [(-90, 1.0), (-40, 0.6), (-140, 0.6), (-10, 0.35), (190, 0.35)], n * 0.03, n * 0.20, n * 0.025, el, 0.9)
    _shield(cv, (n * 0.40, n * 0.58), n * 0.40, 28, sx=0.62)
    for (x, y, s, a) in ((0.86, 0.32, 0.05, 30), (0.80, 0.10, 0.035, -20), (0.30, 0.12, 0.03, 50)):
        stone_chip(cv, rng, n * x, n * y, n * s, a, el, hot_dir=(-0.3, 1.0), trail=(0.0, -1.0))
    hot_core(cv, n * 0.66, n * 0.18, el, 2.6, 1.1, star_len=18)


@skill("knight.charge", tone="azure")
def charge(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.80, n * 0.50), focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    for i in range(16):
        y = n * rng.uniform(0.12, 0.90)
        x1 = n * rng.uniform(0.40, 0.66)
        light_streak(cv, (x1 - n * rng.uniform(0.35, 0.7), y), (x1, y), n * rng.uniform(0.012, 0.03), el, rng.uniform(0.5, 1.0))
    smoke(cv, rng, [(n * 0.02, n * 0.92), (n * 0.30, n * 0.88), (n * 0.60, n * 0.90)], n * 0.07, "#2A3448", 0.8)
    # impact: a flat burst on the shield face, shock arcs ahead of it
    for r, k in ((0.16, 0.9), (0.26, 0.6)):
        crescent(cv, (n * 0.70, n * 0.50), n * r, n * r * 2.2, 0, -70, 70, 0.18, el, k, rim=True)
    _shield(cv, (n * 0.64, n * 0.50), n * 0.50, 0, sx=0.36, rim_k=1.4)
    hot_core(cv, n * 0.84, n * 0.48, el, 2.6, 1.0, star_len=18)


def _axis(H):
    a = xf(H, [(0.3, 0.0), (0.7, 0.0)])
    return math.degrees(math.atan2(a[1][1] - a[0][1], a[1][0] - a[0][0]))


def _gauntlet_fist(cv, H, el):
    """a plate gauntlet clenched, knuckles toward the viewer: a flared steel cuff with darksteel bands, a steel
    back-of-hand plate, four finger rolls in articulated steel lames, a thumb plate folded across.
    Local: wrist at x=0, knuckle row along y at x~0.62."""
    cuff = lpoly(cv, H, [(0.0, -0.24), (0.36, -0.22), (0.40, 0.24), (0.0, 0.28)])
    ink_line(cv, cuff, "#04060C", 0.4, 2.2, 0.4)
    solid(cv, H, cuff, "steel", 0.12, line=False, streak_ang=_axis(H), back=AZ, back_k=0.7)
    for x in (0.06, 0.30):
        cyl_band(cv, H, x, x + 0.04, 0.27, "darksteel")
    back = lpoly(cv, H, spline([(0.34, -0.30), (0.56, -0.32), (0.64, 0.0), (0.56, 0.32), (0.34, 0.30)], 4))
    solid(cv, H, back, "steel", 0.12, lw=(0.4, 2.2), back=AZ, back_k=0.6)
    parts = [cuff, back]
    for i in range(4):
        y = -0.24 + i * 0.16
        for j, (x0, x1) in enumerate(((0.52, 0.64), (0.62, 0.72), (0.70, 0.78))):
            f = lpoly(cv, H, spline([(x0, y - 0.075), (x1, y - 0.07), (x1 + 0.02, y), (x1, y + 0.07), (x0, y + 0.075)], 4))
            solid(cv, H, f, "steel" if j != 1 else "plate", 0.04, lw=(0.3, 1.5), back=AZ, back_k=0.5)
            parts.append(f)
    thumb = lrib(cv, H, [(0.40, 0.32), (0.50, 0.20), (0.60, 0.04)], 0.10, 0.07, 6)
    solid(cv, H, thumb, "steel", 0.04, lw=(0.35, 1.8), back=AZ, back_k=0.6)
    return union(cv, parts + [thumb])


@skill("knight.repel", tone="steel")
def repel(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.38, n * 0.52])
    ground(cv, "azure", [], focus=(n * 0.62, n * 0.50), focus_r=0.55, focus_k=0.6, wash=0, rng=rng)
    for i, (rx, k) in enumerate(((0.20, 1.0), (0.32, 0.8), (0.46, 0.6), (0.60, 0.4))):
        crescent(cv, (c[0] + n * 0.02, c[1]), n * rx, n * rx * 1.25, 0, -62, 62, 0.16, "azure", k)
    for (x, y, s, a, tr) in ((0.86, 0.22, 0.06, 20, (1, -0.4)), (0.92, 0.70, 0.05, -40, (1, 0.4)), (0.74, 0.86, 0.04, 70, (1, 0.6)),
                             (0.78, 0.10, 0.035, 10, (1, -0.6))):
        t = np.array(tr) / np.linalg.norm(tr)
        stone_chip(cv, rng, n * x, n * y, n * s, a, "azure", hot_dir=-t, trail=t)
    H = H_affine((n * 0.06, n * 0.60), -10, n * 0.62)
    _gauntlet_fist(cv, H, el)
    hot_core(cv, n * 0.50, n * 0.50, "azure", 2.4, 1.0, star_len=18)


@skill("knight.roar", tone="azure")
def roar(cv, rng, el):
    """a flat-topped barrel great-helm dead centre (eye slit glowing, breaths, a face ridge between a lit and a
    shadowed plane, flared bevor, a navy horsehair crest streaming back), roar arcs radiating to both sides"""
    n = cv.n
    c = np.array([n * 0.50, n * 0.54])
    ground(cv, el, [], focus=c, focus_r=0.55, focus_k=0.6, wash=-90, rng=rng)
    for s in (-1, 1):
        for i, r in enumerate((0.30, 0.40, 0.50)):
            a0, a1 = (150, 210) if s < 0 else (-30, 30)
            crescent(cv, c, n * r, n * r * 1.1, 0, a0 if s > 0 else a1, a1 if s > 0 else a0, 0.10, el, 0.9 - i * 0.2, rim=True)
    for k in range(5):   # the plume: five long feathers sweeping back from a socket on the crown
        a = math.radians(-100 + k * 16)
        p0 = np.array([n * 0.52, n * 0.20])
        p1 = p0 + np.array([math.cos(a), math.sin(a)]) * n * 0.10
        p2 = p1 + np.array([math.cos(a + 0.9), math.sin(a + 0.9)]) * n * (0.14 + 0.02 * k)
        fe = cv.poly(ribbon(spline([p0, p1, p2], 8), lambda u: n * 0.05 * math.sin(math.pi * min(1, u * 1.1 + 0.1)) + 0.4))
        ink_line(cv, fe, "#04060C", 0.25, 1.2, 0.4)
        paint_form(cv, fe, CLOTH, R=n * 0.012, grad=0.6)
        cv.paint(stroke(cv, [p0, p1, p2], n * 0.005, n * 0.002) * fe, "#7FB4FF", 0.6)
    helm = cv.poly([tuple(p) for p in arc_pts(n * 0.50, n * 0.34, n * 0.19, 180, 360, 16, ry=n * 0.16)]
                   + [(n * 0.70, n * 0.40), (n * 0.69, n * 0.62), (n * 0.62, n * 0.76), (n * 0.50, n * 0.86), (n * 0.38, n * 0.76),
                      (n * 0.31, n * 0.62), (n * 0.30, n * 0.40)])
    glow(cv, helm, AZ, 10, 0.4)
    ink_line(cv, helm, "#04060C", 0.45, 2.4, 0.35)
    X_, Y_ = cv.grid()
    cyl = (0.45 * np.cos((X_ - n * 0.44) / (n * 0.24) * 1.4)).astype(np.float32) - 0.2
    paint_form(cv, helm, MAT["steel"][0], R=n * 0.05, grad=0.3, field=cyl, spec=MAT["steel"][2])
    f = streak_field(cv.w, 90, 140, 6, cv.seed())
    cv.c *= (1 + 0.14 * (f - 0.5) * 2 * helm)[..., None]
    cv.add(helm * (1 - toward(helm, 1.6, LIGHT)), AZ, 0.9)
    ridge = cv.poly([(n * 0.49, n * 0.20), (n * 0.51, n * 0.20), (n * 0.515, n * 0.84), (n * 0.485, n * 0.84)]) * helm
    cv.add(ridge * (1 - (cv.grid()[1] > n * 0.39) * (cv.grid()[1] < n * 0.47)), "#FFFFFF", 0.35)
    brow = cv.poly([(n * 0.29, n * 0.355), (n * 0.71, n * 0.355), (n * 0.71, n * 0.395), (n * 0.29, n * 0.395)]) * helm
    material(cv, brow, "darksteel", R=n * 0.012, line=False)
    cv.add(brow * (1 - toward(brow, 0.8, (0, -1))), "#DCE4FF", 0.5)
    slit = cv.poly([(n * 0.32, n * 0.40), (n * 0.48, n * 0.42), (n * 0.52, n * 0.42), (n * 0.68, n * 0.40), (n * 0.68, n * 0.445),
                    (n * 0.52, n * 0.465), (n * 0.48, n * 0.465), (n * 0.32, n * 0.445)]) * helm
    cv.paint(slit, "#02040A")
    cv.add(blur(slit, 1.5), AZ, 0.8)
    for sx in (-1, 1):
        cv.add(blur(cv.ellipse(n * (0.5 + sx * 0.09), n * 0.43, n * 0.022, n * 0.009), 1.0), "#F0F6FF", 1.0)
    for i in range(3):
        for j in range(3):
            q = (n * (0.56 + 0.03 * j - 0.01 * i), n * (0.53 + 0.035 * i))
            cv.paint(cv.ellipse(q[0], q[1], n * 0.008) * helm, "#0A0E18", 0.95)
    for x in (0.35, 0.65):
        for y in (0.30, 0.56):
            rv = cv.ellipse(n * x, n * y, n * 0.01)
            material(cv, rv, "steel", R=1.0, lw=(0.15, 0.6))
    hot_core(cv, n * 0.59, n * 0.43, el, 1.4, 0.9, star_len=12)


@skill("knight.shield_counter", tone="steel")
def shield_counter(cv, rng, el):
    n = cv.n
    hit = np.array([n * 0.60, n * 0.38])
    ground(cv, "azure", [], focus=hit, focus_r=0.55, focus_k=0.6, wash=-30, rng=rng)
    _shield(cv, (n * 0.42, n * 0.56), n * 0.50, -8, sx=0.86)
    # a spell bolt striking the shield face from the upper right and thrown back out to the lower right
    trail(cv, [(n * 1.06, n * 0.04), (n * 0.86, n * 0.18), hit + np.array([n * 0.03, -n * 0.02])], 2.0, n * 0.07, "azure", 0.9)
    trail(cv, [hit + np.array([n * 0.03, n * 0.03]), (n * 0.84, n * 0.56), (n * 1.06, n * 0.70)], n * 0.10, 1.0, "azure", 1.0)
    for i, (r, w, k) in enumerate(((0.14, 0.03, 1.0), (0.22, 0.018, 0.6))):
        shock_ring(cv, hit, np.array([0.30, 0.95]), np.array([0.95, -0.30]), n * r, n * r * 0.45, n * w, "azure", k)
    sparks(cv, rng, hit, 12, n * 0.18, "azure", 0.9, a_range=(-80, 80))
    hot_core(cv, hit[0], hit[1], "azure", 3.0, 1.2, star_len=20)


@skill("knight.heroic_leap", tone="azure")
def heroic_leap(cv, rng, el):
    n = cv.n
    land = np.array([n * 0.70, n * 0.80])
    ground(cv, el, [(cv.poly([(0, n * 0.84), (n, n * 0.80), (n, n), (0, n)]), 1)], focus=land, focus_r=0.5, focus_k=0.6, wash=-20, rng=rng)
    path = [(n * 0.06, n * 0.92), (n * 0.12, n * 0.40), (n * 0.30, n * 0.12), (n * 0.52, n * 0.14), (n * 0.64, n * 0.42), land + np.array([0, -n * 0.06])]
    trail(cv, path, 1.0, n * 0.10, el, 0.85, core_k=0.6)
    for k in range(3):   # dash marks along the arc (the leap's motion)
        pts = [(x + n * 0.04 * (k - 1), y) for x, y in path[1:4]]
        cv.add(blur(stroke(cv, pts, n * 0.005, n * 0.005), 0.8), AZ, 0.3)
    # crater: dark broken ground bowl, a shock ring, chips flying out of it, dust
    bowl = cv.ellipse(land[0], land[1] + n * 0.03, n * 0.24, n * 0.07)
    material(cv, bowl, "stone", R=n * 0.03, lw=(0.3, 1.6), spec=False)
    for k in range(7):
        a = math.radians(-180 + k * 30 + rng.uniform(-8, 8))
        crack = stroke(cv, [land, land + np.array([math.cos(a) * n * 0.22, abs(math.sin(a)) * n * 0.05 + n * 0.02])], n * 0.012, 0.4)
        soft_light(cv, crack * dilate(bowl, 2), el, 0.8, R=0.6, glow_r=2)
    smoke(cv, rng, [land + np.array([-n * 0.30, -n * 0.02]), land + np.array([-n * 0.12, -n * 0.08]), land + np.array([n * 0.20, -n * 0.04])],
          n * 0.06, "#2A3448", 0.7)
    shock_ring(cv, land, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.30, n * 0.08, n * 0.025, el, 1.0)
    for (dx, dy, s, a) in ((-0.20, -0.20, 0.045, 10), (0.16, -0.26, 0.05, -30), (0.04, -0.36, 0.035, 60), (-0.08, -0.30, 0.03, 0),
                           (0.24, -0.12, 0.035, 40)):
        tr = np.array([dx, dy]) / np.linalg.norm([dx, dy])
        stone_chip(cv, rng, land[0] + n * dx, land[1] + n * dy, n * s, a, el, hot_dir=-tr, trail=tr)
    burst(cv, rng, land + np.array([0, -n * 0.05]), n * 0.10, el, 0.9, smoke_k=0.0, puffs=7)
    hot_core(cv, land[0], land[1] - n * 0.06, el, 2.6, 1.0, star_len=18)


@skill("knight.crusaders_trial", tone="gold")
def crusaders_trial(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.44])
    ground(cv, "azure", [], focus=c, focus_r=0.5, focus_k=0.5, ink="#04060A", wash=-90, rng=rng)
    # the gold cross of light: a tall beam and a crossbar, painted as light forms with flared ends
    vbar = cv.poly([(n * 0.45, n * 0.02), (n * 0.55, n * 0.02), (n * 0.535, n * 0.86), (n * 0.465, n * 0.86)])
    hbar = cv.poly([(n * 0.12, n * 0.31), (n * 0.88, n * 0.31), (n * 0.88, n * 0.40), (n * 0.12, n * 0.40)])
    crossm = union(cv, [vbar, hbar])
    soft_light(cv, crossm, el, 1.0, R=n * 0.03, glow_r=14, core_k=0.9)
    for (x, y, a) in ((0.12, 0.355, 180), (0.88, 0.355, 0), (0.50, 0.02, -90)):
        flare_spikes(cv, n * x, n * y, [(a, 1.0), (a - 30, 0.5), (a + 30, 0.5)], n * 0.0, n * 0.10, n * 0.025, el, 0.7)
    # ground shock and cracks where the sword is driven in
    gp = np.array([n * 0.50, n * 0.86])
    shock_ring(cv, gp, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.38, n * 0.08, n * 0.03, el, 1.0)
    for k in range(6):
        a = math.radians(-160 + k * 28)
        crack = stroke(cv, [gp, gp + np.array([math.cos(a) * n * 0.30, n * 0.04 + abs(math.sin(a)) * n * 0.05])], n * 0.014, 0.4)
        soft_light(cv, crack, el, 0.8, R=0.6, glow_r=2)
    _knight_sword(cv, (n * 0.50, n * 0.14), (n * 0.50, n * 0.92), "azure", rune="#FFC85A", scale=1.25)
    hot_core(cv, n * 0.50, n * 0.355, el, 3.0, 1.2, star_len=22)
