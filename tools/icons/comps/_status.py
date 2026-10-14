"""Status icons (all 27 StatusSet.IDS). Cross-class family: one neutral ink badge ground, one soft light mass in the
element colour (STATUS_PAL), the subject, then the polarity bevel (buff round / debuff shield / cc hexagon).
Badge kind per id: painter.keys.STATUS_KIND. Each subject must differ in big shape (SSIM gate across all 27).
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from painter import weapons  # noqa: F401  (registers the extra materials)


@status("atk_up", tone="crimson")
def st_atk_up(cv, rng, el):
    """攻击提升: an up-pointing blade whose tip is a broad arrowhead, rising on crimson light"""
    n = cv.n
    for x, y0, y1, w in ((0.24, 0.86, 0.36, 0.035), (0.76, 0.84, 0.40, 0.035), (0.33, 0.95, 0.60, 0.022), (0.67, 0.95, 0.62, 0.022)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.9)
    glow(cv, cv.ellipse(n * 0.5, n * 0.24, n * 0.16), tone(el)[2], 8, 0.6)
    blade = cv.poly([(n * 0.455, n * 0.86), (n * 0.455, n * 0.40), (n * 0.30, n * 0.42), (n * 0.5, n * 0.07), (n * 0.70, n * 0.42),
                     (n * 0.545, n * 0.40), (n * 0.545, n * 0.86)])
    material(cv, blade, "steel", R=n * 0.04, lw=(0.3, 1.6), streak_ang=-90, back=tone(el)[2], back_k=0.9)
    ridge = cv.poly([(n * 0.5, n * 0.10), (n * 0.512, n * 0.42), (n * 0.505, n * 0.86), (n * 0.495, n * 0.86), (n * 0.488, n * 0.42)])
    cv.paint(ridge * blade, "#FFFFFF", 0.7)
    guard = cv.poly([(n * 0.26, n * 0.80), (n * 0.5, n * 0.74), (n * 0.74, n * 0.80), (n * 0.70, n * 0.88), (n * 0.5, n * 0.84), (n * 0.30, n * 0.88)])
    material(cv, guard, "gold", R=n * 0.03, lw=(0.3, 1.3))
    gem = cv.ellipse(n * 0.5, n * 0.81, n * 0.035)
    glow(cv, gem, "#FF2A3A", 3, 0.8)
    cv.paint(gem, "#E0202E")
    cv.add(blur(cv.ellipse(n * 0.49, n * 0.80, n * 0.015), 0.5), "#FFC8C0", 1.0)
    hot_core(cv, n * 0.5, n * 0.09, el, 1.4, 0.8, star_len=12)


@status("haste", tone="wind")
def st_haste(cv, rng, el):
    """加速: a swept wing of light with speed streaks trailing it"""
    n = cv.n
    for p0, p1, w in (((0.05, 0.62), (0.55, 0.60), 0.035), ((0.08, 0.76), (0.48, 0.73), 0.028), ((0.12, 0.48), (0.40, 0.47), 0.022)):
        light_streak(cv, (n * p0[0], n * p0[1]), (n * p1[0], n * p1[1]), n * w, el, 0.9)
    feathers = []
    for i in range(5):
        a = math.radians(-160 + i * 16)
        base = np.array([n * 0.66, n * 0.60])
        L = n * (0.52 - i * 0.06)
        tip = base + np.array([math.cos(a), math.sin(a)]) * L
        mid = base + (tip - base) * 0.55 + np.array([0, -n * 0.04])
        feathers.append(cv.poly(ribbon(spline([base, mid, tip], 6), lambda t: n * 0.09 * (1 - t) ** 0.6 + 0.6)))
    for i, f in enumerate(reversed(feathers)):
        light_form(cv, f, el, 0.8 + 0.05 * i, R=n * 0.025, glow_r=3, lw=(0.2, 1.2))
    arm = cv.poly(spline([(n * 0.60, n * 0.66), (n * 0.80, n * 0.52), (n * 0.88, n * 0.30)], 6).tolist()
                  + spline([(n * 0.94, n * 0.34), (n * 0.82, n * 0.62), (n * 0.62, n * 0.74)], 6).tolist())
    light_form(cv, arm, el, 1.0, R=n * 0.03, glow_r=4, lw=(0.25, 1.4))


@status("super_armor", tone="gold")
def st_super_armor(cv, rng, el):
    """霸体: a full gold breastplate filling the badge -- shoulders, gorget, pectoral plates, centre ridge, red gem"""
    n = cv.n
    glow(cv, cv.ellipse(n * 0.5, n * 0.52, n * 0.34), tone(el)[2], 8, 0.5)
    plate = closed_spline([(n * 0.14, n * 0.30), (n * 0.34, n * 0.20), (n * 0.42, n * 0.30), (n * 0.5, n * 0.33), (n * 0.58, n * 0.30),
                           (n * 0.66, n * 0.20), (n * 0.86, n * 0.30), (n * 0.82, n * 0.50), (n * 0.74, n * 0.70), (n * 0.5, n * 0.88),
                           (n * 0.26, n * 0.70), (n * 0.18, n * 0.50)], 6)
    m = cv.poly(plate)
    material(cv, m, "gold", R=n * 0.10, lw=(0.35, 1.9), grad=0.4)
    # pectoral split lines, centre ridge, gorget
    for pts in (((0.22, 0.46), (0.36, 0.54), (0.48, 0.52)), ((0.78, 0.46), (0.64, 0.54), (0.52, 0.52)), ((0.30, 0.68), (0.5, 0.74), (0.70, 0.68))):
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * 0.03, n * 0.008, 6) * m, "#5A3414", 0.85)
    ridge = cv.poly([(n * 0.485, n * 0.36), (n * 0.515, n * 0.36), (n * 0.515, n * 0.82), (n * 0.5, n * 0.86), (n * 0.485, n * 0.82)])
    cv.paint(ridge * m, "#FFF2C8", 0.9)
    gorget = cv.poly(closed_spline([(n * 0.36, n * 0.27), (n * 0.5, n * 0.30), (n * 0.64, n * 0.27), (n * 0.60, n * 0.36), (n * 0.5, n * 0.39), (n * 0.40, n * 0.36)], 4))
    material(cv, gorget, "lacquer", R=n * 0.03, lw=(0.2, 1.0))
    gem = cv.ellipse(n * 0.5, n * 0.52, n * 0.06)
    glow(cv, gem, "#FF2A3A", 3, 0.9)
    cv.paint(gem, "#D2202E")
    cv.add(blur(cv.ellipse(n * 0.49, n * 0.51, n * 0.026), 0.6), "#FFC0B8", 1.1)


@status("burn", tone="fire")
def st_burn(cv, rng, el):
    """灼烧: a cracked dark plate, its cracks glowing ember-hot, small flames licking up out of the cracks"""
    n = cv.n
    pal = tone(el)
    plate = cv.poly(closed_spline([(n * 0.16, n * 0.40), (n * 0.40, n * 0.34), (n * 0.66, n * 0.36), (n * 0.86, n * 0.44), (n * 0.82, n * 0.74),
                                   (n * 0.56, n * 0.86), (n * 0.30, n * 0.82), (n * 0.14, n * 0.66)], 6))
    # flames behind/above the plate, rising from the cracks
    for x0, h, lean in ((0.30, 0.30, -0.05), (0.50, 0.40, 0.03), (0.68, 0.28, 0.06), (0.40, 0.20, -0.02)):
        base = np.array([n * x0, n * 0.46])
        pts = [base, base + np.array([n * lean * 0.5 + n * 0.03, -n * h * 0.45]), base + np.array([n * lean, -n * h])]
        fm = cv.poly(ribbon(spline(pts, 6), lambda t: n * 0.11 * (1 - t) ** 0.8 + 0.4))
        soft_light(cv, fm, el, 1.0, R=n * 0.035, glow_r=4, core_k=0.8)
    material(cv, plate, "darksteel", R=n * 0.08, lw=(0.35, 1.8), grad=0.4, back=pal[2], back_k=0.8)
    cracks = union(cv, [stroke(cv, [(n * x, n * y) for x, y in pts], n * w0, 0.3, 6) for pts, w0 in (
        (((0.30, 0.40), (0.36, 0.56), (0.30, 0.70), (0.34, 0.82)), 0.035),
        (((0.50, 0.36), (0.46, 0.52), (0.56, 0.64), (0.52, 0.84)), 0.04),
        (((0.68, 0.38), (0.62, 0.50), (0.74, 0.62)), 0.03),
        (((0.46, 0.52), (0.36, 0.56)), 0.02), (((0.56, 0.64), (0.70, 0.70)), 0.02))]) * plate
    glow(cv, cracks, pal[1], 2.5, 0.9)
    cv.paint(cracks, pal[2])
    cv.add(np.clip(blur(cracks, 0.4) * 2 - 0.8, 0, 1), pal[3], 0.9)
    for _ in range(6):
        x, y = rng.uniform(0.25, 0.8) * n, rng.uniform(0.08, 0.3) * n
        cv.add(blur(cv.ellipse(x, y, rng.uniform(0.8, 1.5)), 0.4), "#FFD86A", 1.2)


@status("def_down", tone="steel")
def st_def_down(cv, rng, el):
    """破防: a steel shield split in two by a red crack"""
    n = cv.n
    left = [(n * 0.20, n * 0.18), (n * 0.48, n * 0.12), (n * 0.44, n * 0.30), (n * 0.52, n * 0.46), (n * 0.42, n * 0.62),
            (n * 0.47, n * 0.88), (n * 0.40, n * 0.84), (n * 0.22, n * 0.64), (n * 0.17, n * 0.40)]
    right = [(n * 0.55, n * 0.13), (n * 0.82, n * 0.19), (n * 0.84, n * 0.40), (n * 0.78, n * 0.64), (n * 0.58, n * 0.86),
             (n * 0.52, n * 0.62), (n * 0.62, n * 0.46), (n * 0.53, n * 0.30)]
    crack = cv.poly(ribbon([(n * 0.52, n * 0.06), (n * 0.48, n * 0.30), (n * 0.57, n * 0.46), (n * 0.47, n * 0.62), (n * 0.53, n * 0.92)], [1, 4, 3.5, 3.5, 0.5]))
    soft_light(cv, crack, "steel", 0.9, R=1.2, glow_r=5)
    Hr = H_affine((n * 0.06, n * 0.04), 7, 1.0)
    for pts, H in ((left, np.eye(3)), (right, Hr)):
        m = cv.poly(xf(H, pts))
        material(cv, m, "steel", R=n * 0.06, lw=(0.3, 1.7), back="#FF6A6A", back_k=0.9, grad=0.4)
        cv.paint(np.clip(m - toward(m, 1.6, (0.0, -1.0)), 0, 1), "#D8B25A", 0.9)


@status("slow", tone="ice")
def st_slow(cv, rng, el):
    """减速: a frost-bound hourglass -- gold frame, ice-blue sand frozen mid-fall, ice crystals crusting the frame"""
    n = cv.n
    pal = tone(el)
    glow(cv, cv.ellipse(n * 0.5, n * 0.5, n * 0.3), pal[1], 8, 0.5)
    bulb = cv.poly(closed_spline([(n * 0.32, n * 0.24), (n * 0.68, n * 0.24), (n * 0.62, n * 0.40), (n * 0.53, n * 0.50), (n * 0.62, n * 0.60),
                                  (n * 0.68, n * 0.76), (n * 0.32, n * 0.76), (n * 0.38, n * 0.60), (n * 0.47, n * 0.50), (n * 0.38, n * 0.40)], 6))
    material(cv, bulb, "glass", R=n * 0.06, lw=(0.2, 1.0), grad=0.3)
    sand = cv.poly(closed_spline([(n * 0.37, n * 0.74), (n * 0.63, n * 0.74), (n * 0.58, n * 0.64), (n * 0.5, n * 0.60), (n * 0.42, n * 0.64)], 4))
    cv.paint(sand * bulb, "#BFF2FF")
    cv.paint(cv.poly([(n * 0.40, n * 0.30), (n * 0.60, n * 0.30), (n * 0.5, n * 0.42)]) * bulb, "#BFF2FF", 0.9)
    cv.paint(stroke(cv, [(n * 0.5, n * 0.44), (n * 0.5, n * 0.62)], n * 0.018, n * 0.01), "#E8FBFF")
    for y in (0.17, 0.83):
        cap = cv.poly(closed_spline([(n * 0.22, n * (y - 0.05)), (n * 0.78, n * (y - 0.05)), (n * 0.80, n * (y + 0.05)), (n * 0.20, n * (y + 0.05))], 3))
        material(cv, cap, "gold", R=n * 0.03, lw=(0.3, 1.5))
    for x in (0.27, 0.73):
        post = cv.poly([(n * (x - 0.025), n * 0.2), (n * (x + 0.025), n * 0.2), (n * (x + 0.025), n * 0.8), (n * (x - 0.025), n * 0.8)])
        material(cv, post, "gold", R=n * 0.02, lw=(0.3, 1.3))
    # ice crust: shards growing off the frame corners, rime along the top cap
    for cx_, cy_, a0 in ((0.27, 0.21, -135), (0.73, 0.79, 45), (0.73, 0.21, -45), (0.27, 0.79, 135), (0.5, 0.86, 90)):
        for j, (da, L, w) in enumerate(((0, 0.14, 0.07), (-40, 0.10, 0.05), (40, 0.09, 0.05))):
            a = math.radians(a0 + da)
            b = np.array([n * cx_, n * cy_])
            tp = b + np.array([math.cos(a), math.sin(a)]) * n * L
            nv = np.array([-math.sin(a), math.cos(a)]) * n * w * 0.5
            shard = cv.poly([b + nv, b + (tp - b) * 0.7 + nv * 0.9, tp, b + (tp - b) * 0.7 - nv * 0.9, b - nv])
            glow(cv, shard, pal[2], 2, 0.35)
            paint_form(cv, shard, ["#3C7EAA", "#8CCBE6", "#DDF6FF", "#FFFFFF"], R=n * 0.02, tilt=tuple(LIGHT2 * 0.4), grad=0.5)
            ink_line(cv, shard, "#0A2A40", 0.2, 1.0, 0.3)
    rime = cv.poly(ribbon(spline([(n * 0.22, n * 0.12), (n * 0.5, n * 0.10), (n * 0.78, n * 0.12)], 6), [n * 0.02, n * 0.04, n * 0.02]))
    cv.paint(rime * (0.6 + 0.4 * cv.noise2), "#F0FCFF", 0.9)


@status("stun", tone="cc")
def st_stun(cv, rng, el):
    """眩晕: three gold stars circling a glowing spiral (no birds: they do not read at 28 px)"""
    n = cv.n
    c = (n * 0.5, n * 0.54)
    t = np.linspace(0, 1, 140)
    ang = t * math.pi * 4.4
    r = n * (0.03 + 0.24 * t)
    pts = np.c_[c[0] + np.cos(ang) * r, c[1] + np.sin(ang) * r * 0.85]
    sp = cv.poly(ribbon(pts, lambda u: 1.0 + 6.0 * u))
    soft_light(cv, sp, el, 1.0, R=1.0, glow_r=4)
    orb = arc_pts(c[0], c[1] - n * 0.06, n * 0.38, 0, 360, 96, n * 0.15)
    cv.add(cv.poly(ribbon(orb, [1.6] * 96)), "#FFE9A8", 0.35)
    for a_deg, s in ((205, 0.17), (325, 0.15), (85, 0.19)):
        a = math.radians(a_deg)
        x, y = c[0] + math.cos(a) * n * 0.38, c[1] - n * 0.06 + math.sin(a) * n * 0.15
        sp_ = []
        for i in range(10):
            aa = math.radians(-90 + i * 36)
            rr = n * s * (1.0 if i % 2 == 0 else 0.45)
            sp_.append((x + math.cos(aa) * rr, y + math.sin(aa) * rr))
        m = cv.poly(sp_)
        glow(cv, m, "#FFC43A", 3, 0.7)
        material(cv, m, "gold", R=n * s * 0.3, lw=(0.25, 1.3), brk=0.2)



# ================================================================== the other 20 statuses (migration phase)
def _hexagon(cx, cy, r, rot=0.0):
    return [(cx + math.cos(math.radians(rot + 60 * k)) * r, cy + math.sin(math.radians(rot + 60 * k)) * r) for k in range(6)]


def _star(cx, cy, r_out, r_in, points=4, rot=-90.0):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180.0 / points)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


@status("freeze", tone="ice")
def st_freeze(cv, rng, el):
    """冰冻: a faceted six-arm frost crystal; each arm a two-facet ice blade with side barbs"""
    n = cv.n
    pal = tone(el)
    c = np.array([n * 0.5, n * 0.52])
    glow(cv, cv.ellipse(c[0], c[1], n * 0.22), pal[1], 8, 0.6)
    for k in range(6):
        a = math.radians(-90 + k * 60)
        d = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-d[1], d[0]])
        L = n * 0.36
        tip = c + d * L
        left = cv.poly([c + nv * n * 0.045, tip, c])
        right = cv.poly([c - nv * n * 0.045, tip, c])
        lit_first = float(np.dot(nv, LIGHT2)) > 0
        for m, v in ((left, 1.0 if lit_first else 0.55), (right, 0.55 if lit_first else 1.0)):
            paint_form(cv, m, [mix("#2A72A8", "#9FEFFF", v * 0.6), mix("#8CCBE6", "#FFFFFF", v * 0.5), mix("#DDF6FF", "#FFFFFF", v)],
                       R=n * 0.01, grad=0.4, thr=[0.3, 0.7])
        ink_line(cv, union(cv, [left, right]), "#0A2A40", 0.2, 0.9, 0.3)
        for t, s in ((0.55, 1), (0.55, -1), (0.75, 1), (0.75, -1)):
            b = c + d * L * t
            bt = b + (d * 0.6 + nv * s * 0.8) * n * (0.10 if t < 0.7 else 0.06)
            bm = cv.poly([b + d * n * 0.012, bt, b - d * n * 0.012])
            paint_form(cv, bm, ["#5AA8D8", "#C8F0FF", "#FFFFFF"], R=n * 0.005, grad=0.3, thr=[0.3, 0.7])
    core = cv.poly(_hexagon(c[0], c[1], n * 0.07, 30))
    paint_form(cv, core, ["#9FEFFF", "#E6FBFF", "#FFFFFF"], R=n * 0.02, grad=0.5, thr=[0.3, 0.7])
    hot_core(cv, c[0] - n * 0.01, c[1] - n * 0.01, el, 1.0, 0.6, star_len=10)


@status("root", tone="earth")
def st_root(cv, rng, el):
    """定身: a heavy chain looping across, pinned to the ground by an iron stake over a glowing earth crack"""
    n = cv.n
    pal = tone(el)
    crack = cv.poly(ribbon([(n * 0.20, n * 0.80), (n * 0.40, n * 0.76), (n * 0.52, n * 0.82), (n * 0.66, n * 0.76), (n * 0.84, n * 0.80)],
                           [0.6, 2.6, 3.2, 2.6, 0.6]))
    soft_light(cv, crack, el, 0.9, R=1.0, glow_r=5)
    stake = cv.poly([(n * 0.46, n * 0.22), (n * 0.56, n * 0.22), (n * 0.54, n * 0.70), (n * 0.51, n * 0.84), (n * 0.48, n * 0.70)])
    material(cv, stake, "darksteel", R=n * 0.03, lw=(0.3, 1.6), streak_ang=90, back=pal[2], back_k=0.7)
    cap = cv.poly([(n * 0.40, n * 0.16), (n * 0.62, n * 0.16), (n * 0.60, n * 0.25), (n * 0.42, n * 0.25)])
    material(cv, cap, "darksteel", R=n * 0.03, lw=(0.3, 1.4))
    # chain: alternating face-on and edge-on oval links along an arc through the stake
    path = [(n * 0.10, n * 0.42), (n * 0.30, n * 0.56), (n * 0.50, n * 0.60), (n * 0.70, n * 0.54), (n * 0.90, n * 0.38)]
    sp = spline(path, 10)
    idx = np.linspace(0, len(sp) - 1, 7).astype(int)
    t = np.linspace(0, 2 * math.pi, 40)
    for j, i in enumerate(idx):
        p = sp[i]
        d = sp[min(i + 1, len(sp) - 1)] - sp[max(i - 1, 0)]
        a = math.degrees(math.atan2(d[1], d[0]))
        H = H_affine(p, a, n * 0.075, n * (0.045 if j % 2 == 0 else 0.018))
        outer = cv.poly(xf(H, np.c_[np.cos(t), np.sin(t)]))
        inner = cv.poly(xf(H, np.c_[np.cos(t) * 0.55, np.sin(t) * 0.35])) if j % 2 == 0 else np.zeros_like(outer)
        link = np.clip(outer - inner, 0, 1)
        material(cv, link, "steel", R=n * 0.012, lw=(0.3, 1.4), back=pal[2], back_k=0.6)


@status("silence", tone="cc")
def st_silence(cv, rng, el):
    """沉默: a spell orb sealed under a paper talisman (abstract red brush seal, no glyph), bound with a red cord"""
    n = cv.n
    pal = tone(el)
    orb = cv.ellipse(n * 0.5, n * 0.52, n * 0.27)
    glow(cv, orb, pal[1], 8, 0.6)
    paint_form(cv, orb, [mix(pal[0], pal[1], 0.6), pal[1], mix(pal[1], pal[2], 0.6), pal[2]], R=n * 0.12, grad=0.5)
    cv.add(blur(cv.ellipse(n * 0.42, n * 0.42, n * 0.07), 2), "#FFFFFF", 0.5)
    tal = cv.poly([(n * 0.38, n * 0.14), (n * 0.62, n * 0.12), (n * 0.66, n * 0.88), (n * 0.40, n * 0.90)])
    ink_line(cv, tal, "#3A2E18", 0.3, 1.4, 0.3)
    paint_form(cv, tal, ["#8A7448", "#D8C48E", "#F6E8C2", "#FFF8E6"], R=n * 0.03, grad=0.6, tilt=(0.2, 0.0))
    for pts, w in ((((0.51, 0.20), (0.50, 0.40), (0.53, 0.62), (0.52, 0.82)), 0.035),
                   (((0.43, 0.32), (0.52, 0.30), (0.60, 0.34)), 0.022), (((0.44, 0.56), (0.53, 0.52), (0.60, 0.58)), 0.022)):
        cv.paint(stroke(cv, [(n * x, n * y) for x, y in pts], n * w, n * w * 0.3, 6) * tal, "#B01A20", 0.92)
    seal = np.clip(cv.ellipse(n * 0.52, n * 0.72, n * 0.07) - cv.ellipse(n * 0.52, n * 0.72, n * 0.05), 0, 1)
    cv.paint(seal * tal, "#B01A20", 0.85)
    cord = stroke(cv, [(n * 0.24, n * 0.44), (n * 0.50, n * 0.47), (n * 0.76, n * 0.42)], n * 0.025, n * 0.02)
    material(cv, cord, "cloth_red", R=n * 0.008, lw=(0.2, 0.8))


@status("sleep", tone="dream")
def st_sleep(cv, rng, el):
    """睡眠: a crescent moon resting on a soft drifting cloud, two small stars"""
    n = cv.n
    pal = tone(el)
    moon = np.clip(cv.ellipse(n * 0.46, n * 0.42, n * 0.28) - cv.ellipse(n * 0.58, n * 0.34, n * 0.24), 0, 1)
    glow(cv, moon, pal[2], 8, 0.6)
    ink_line(cv, moon, "#4A3A10", 0.25, 1.2, 0.4)
    paint_form(cv, moon, ["#B89A3A", "#F2D27A", "#FFF0B8", "#FFFDF0"], R=n * 0.05, grad=0.5)
    cl = union(cv, [cv.ellipse(n * x, n * y, n * r) for x, y, r in ((0.30, 0.74, 0.12), (0.46, 0.68, 0.15), (0.63, 0.72, 0.13),
                                                                    (0.76, 0.78, 0.09), (0.50, 0.80, 0.14))])
    cl = cl * (cv.grid()[1] < n * 0.86)
    ink_line(cv, cl, mix(pal[0], pal[1], 0.4), 0.25, 1.3, 0.4)
    paint_form(cv, cl, [mix(pal[0], pal[1], 0.7), pal[1], mix(pal[1], pal[2], 0.6), pal[3]], R=n * 0.05, grad=0.6, tilt=(0, -0.3))
    for x, y, s in ((0.74, 0.26, 0.07), (0.84, 0.48, 0.045)):
        m = cv.poly(_star(n * x, n * y, n * s, n * s * 0.35))
        glow(cv, m, "#FFE9A8", 3, 0.6)
        cv.paint(m, "#FFF6D0")


@status("confusion", tone="cc")
def st_confusion(cv, rng, el):
    """混乱: two light arrows chasing each other around a ring, a pale swirl at the centre"""
    n = cv.n
    c = (n * 0.5, n * 0.52)
    for k, el2 in ((0, "cc"), (1, "mark")):
        a0 = k * 180 + 20
        pts = arc_pts(c[0], c[1], n * 0.29, a0, a0 + 140, 40, n * 0.26)
        body = cv.poly(ribbon(pts, lambda u: n * (0.03 + 0.06 * u)))
        light_form(cv, body, el2, 1.0, R=n * 0.02, glow_r=4, lw=(0.25, 1.3))
        e = pts[-1]
        d = pts[-1] - pts[-4]
        d = d / np.linalg.norm(d)
        nv = np.array([-d[1], d[0]])
        head = cv.poly([e + nv * n * 0.10, e + d * n * 0.13, e - nv * n * 0.10])
        light_form(cv, head, el2, 1.0, R=n * 0.02, glow_r=4, lw=(0.25, 1.3))
    t = np.linspace(0, 1, 60)
    ang = t * math.pi * 3.0
    r = n * (0.02 + 0.10 * t)
    sp = cv.poly(ribbon(np.c_[c[0] + np.cos(ang) * r, c[1] + np.sin(ang) * r], lambda u: 0.8 + 3.0 * u))
    soft_light(cv, sp, "cc", 0.8, R=0.8, glow_r=3)


@status("taunted", tone="crimson")
def st_taunted(cv, rng, el):
    """嘲讽: the anime anger mark -- four bulging vein curves around a cross, painted as glossy red forms"""
    n = cv.n
    pal = tone(el)
    glow(cv, cv.ellipse(n * 0.5, n * 0.5, n * 0.3), pal[1], 8, 0.5)
    c = np.array([n * 0.5, n * 0.5])
    parts = []
    for k in range(4):
        # one bulging vein per quadrant: a thick curve whose middle bows in toward the centre and whose tapered ends
        # flare out along the axes, leaving a clear cross-shaped gap between the four (the manga anger mark)
        a = math.radians(45 + k * 90)
        d = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-d[1], d[0]])
        mid = c + d * n * 0.17
        e1 = c + d * n * 0.34 + nv * n * 0.17
        e2 = c + d * n * 0.34 - nv * n * 0.17
        pts = spline([e1, c + d * n * 0.21 + nv * n * 0.10, mid, c + d * n * 0.21 - nv * n * 0.10, e2], 8)
        parts.append(cv.poly(ribbon(pts, lambda u: n * (0.01 + 0.085 * math.sin(math.pi * u) ** 1.2))))
    m = union(cv, parts)
    ink_line(cv, m, "#3A0408", 0.3, 1.8, 0.3)
    paint_form(cv, m, ["#5A0610", "#B0141E", "#F03A3A", "#FFB0A0"], R=n * 0.035, grad=0.5,
               spec=[("#FFFFFF", 16, 0.45, 0.6, 0.9)])


@status("blind", tone="dusk")
def st_blind(cv, rng, el):
    """致盲: an almond eye with a dull iris, a dark cloth bandage slashed diagonally across it"""
    n = cv.n
    eye = cv.poly(spline([(n * 0.08, n * 0.44), (n * 0.50, n * 0.18), (n * 0.92, n * 0.44), (n * 0.50, n * 0.70), (n * 0.08, n * 0.44)], 10))
    glow(cv, eye, "#B8A8A0", 6, 0.4)
    ink_line(cv, eye, "#140A0A", 0.4, 2.0, 0.2)
    paint_form(cv, eye, ["#8A847E", "#D0C8C0", "#F2EEE8", "#FFFFFF"], R=n * 0.06, grad=0.5)
    iris = cv.ellipse(n * 0.5, n * 0.44, n * 0.16) * eye
    paint_form(cv, iris, ["#3A3430", "#6A5E56", "#9A8E82"], R=n * 0.05, grad=0.5)
    cv.paint(cv.ellipse(n * 0.5, n * 0.44, n * 0.065) * eye, "#0A0808")
    cv.add(blur(cv.ellipse(n * 0.45, n * 0.39, n * 0.025), 0.6), "#FFFFFF", 0.7)
    cv.paint(blur(eye * (1 - toward(eye, 3, (0, 1))), 1.5) * eye, "#3A3430", 0.5)
    bp = [(n * 0.10, n * 0.84), (n * 0.40, n * 0.56), (n * 0.62, n * 0.36), (n * 0.90, n * 0.10)]
    band = cv.poly(ribbon(spline(bp, 8), lambda u: n * (0.085 - 0.015 * abs(u - 0.5))))
    material(cv, band, "leather", R=n * 0.04, lw=(0.35, 1.8), tilt=(0.2, -0.2), grad=0.5, back="#FF6A6A", back_k=0.6)
    p = spline(bp, 8)
    for t in (0.25, 0.5, 0.75):   # cloth folds
        i = int(t * (len(p) - 1))
        cv.paint(stroke(cv, [p[i] + np.array([-n * 0.05, -n * 0.06]), p[i] + np.array([n * 0.05, n * 0.06])], n * 0.015, n * 0.005) * band,
                 "#0C0607", 0.7)


@status("bleed", tone="blood")
def st_bleed(cv, rng, el):
    """流血: a three-line claw-slash wound of red light with glossy blood drops falling from it"""
    n = cv.n
    for o, w in ((-0.10, 0.05), (0.0, 0.07), (0.10, 0.05)):
        p0 = np.array([n * (0.16 + o), n * (0.18 - o)])
        p1 = np.array([n * (0.70 + o), n * (0.56 - o)])
        m = cv.poly(ribbon(spline([p0, (p0 + p1) / 2 + np.array([n * 0.02, -n * 0.03]), p1], 6),
                           lambda u: n * w * math.sin(math.pi * u) ** 0.7 + 0.3))
        soft_light(cv, m, el, 0.9, R=n * 0.02, glow_r=4, core_k=0.7)
    for x, y, s in ((0.62, 0.66, 0.10), (0.78, 0.60, 0.065), (0.48, 0.80, 0.06)):
        pts = closed_spline([(n * x, n * (y - s * 1.5)), (n * (x + s * 0.75), n * (y + s * 0.2)), (n * x, n * (y + s)),
                             (n * (x - s * 0.75), n * (y + s * 0.2))], 6)
        m = cv.poly(pts)
        ink_line(cv, m, "#2A0206", 0.3, 1.5, 0.3)
        paint_form(cv, m, ["#3A0408", "#8A0A14", "#D2283A", "#FF8A80"], R=n * s * 0.5, grad=0.5,
                   spec=[("#FFFFFF", 18, 0.45, 0.6, 1.0)])


@status("poison", tone="poison")
def st_poison(cv, rng, el):
    """中毒: two curved serpent fangs dripping glowing venom, venom bubbles rising"""
    n = cv.n
    pal = tone(el)
    gum = cv.poly(spline([(n * 0.12, n * 0.16), (n * 0.50, n * 0.26), (n * 0.88, n * 0.16), (n * 0.84, n * 0.30), (n * 0.50, n * 0.40),
                          (n * 0.16, n * 0.30)], 6))
    material(cv, gum, "stone", R=n * 0.05, lw=(0.35, 1.8), back=pal[2], back_k=0.5)
    for sx in (-1, 1):
        base = np.array([n * (0.5 + sx * 0.17), n * 0.32])
        pts = [base, base + np.array([sx * n * 0.02, n * 0.20]), base + np.array([-sx * n * 0.04, n * 0.40])]
        fm = cv.poly(ribbon(spline(pts, 6), lambda u: n * 0.10 * (1 - u) ** 0.9 + 0.3))
        material(cv, fm, "bone", R=n * 0.02, lw=(0.3, 1.5))
        tip = pts[-1]
        drop = cv.poly(closed_spline([(tip[0], tip[1] + n * 0.03), (tip[0] + n * 0.04, tip[1] + n * 0.10), (tip[0], tip[1] + n * 0.14),
                                      (tip[0] - n * 0.04, tip[1] + n * 0.10)], 5))
        soft_light(cv, drop, el, 1.0, R=n * 0.02, glow_r=5)
        cv.paint(stroke(cv, [(tip[0] - sx * n * 0.008, tip[1] - n * 0.12), (tip[0], tip[1] + n * 0.02)], n * 0.012, n * 0.006), pal[2], 0.8)
    for x, y, r in ((0.30, 0.70, 0.035), (0.68, 0.76, 0.03), (0.50, 0.62, 0.025)):
        b = np.clip(cv.ellipse(n * x, n * y, n * r) - cv.ellipse(n * (x + r * 0.2), n * (y + r * 0.2), n * r * 0.7), 0, 1)
        soft_light(cv, b, el, 0.8, R=0.8, glow_r=2)


@status("weight", tone="earth")
def st_weight(cv, rng, el):
    """负重: a 秤砣 steelyard weight (bell-shaped iron with a hanging ring) pressing down, downward streaks + dust"""
    n = cv.n
    pal = tone(el)
    for x in (0.18, 0.82, 0.28, 0.72):
        light_streak(cv, (n * x, n * 0.10), (n * x, n * 0.62), n * 0.03, el, 0.8)
    ring = np.clip(cv.ellipse(n * 0.5, n * 0.20, n * 0.09) - cv.ellipse(n * 0.5, n * 0.20, n * 0.055), 0, 1)
    material(cv, ring, "steel", R=n * 0.015, lw=(0.3, 1.3), back=pal[2], back_k=0.6)
    body = cv.poly(closed_spline([(n * 0.42, n * 0.28), (n * 0.58, n * 0.28), (n * 0.62, n * 0.38), (n * 0.76, n * 0.64), (n * 0.78, n * 0.78),
                                  (n * 0.50, n * 0.82), (n * 0.22, n * 0.78), (n * 0.24, n * 0.64), (n * 0.38, n * 0.38)], 6))
    glow(cv, body, pal[2], 6, 0.5)
    material(cv, body, "plate", R=n * 0.12, lw=(0.4, 2.2), grad=0.6, back=pal[2], back_k=0.9)
    for y0 in (0.88, 0.94):   # down-pressing chevrons under the weight
        m = cv.poly([(n * 0.30, n * (y0 - 0.06)), (n * 0.50, n * y0), (n * 0.70, n * (y0 - 0.06)), (n * 0.70, n * (y0 - 0.03)), (n * 0.50, n * (y0 + 0.03)),
                     (n * 0.30, n * (y0 - 0.03))])
        soft_light(cv, m, el, 0.6, R=0.8, glow_r=2)
    band = cv.poly([(n * 0.30, n * 0.56), (n * 0.70, n * 0.56), (n * 0.72, n * 0.62), (n * 0.28, n * 0.62)]) * body
    material(cv, band, "brass", R=n * 0.01, line=False)
    dust = union(cv, [cv.ellipse(n * x, n * 0.86, n * r, n * r * 0.5) for x, r in ((0.24, 0.08), (0.40, 0.09), (0.62, 0.09), (0.78, 0.07))])
    cv.add(blur(dust, 2.5), pal[1], 0.4)


@status("mark", tone="mark")
def st_mark(cv, rng, el):
    """印记: a branded reticle -- two counter-rotating broken rings, four inward ticks, a hot diamond at the centre"""
    n = cv.n
    c = (n * 0.5, n * 0.5)
    for r, w, a0, gaps in ((0.34, 0.035, 10, 4), (0.24, 0.022, 55, 3)):
        segs = []
        span = 360.0 / gaps
        for k in range(gaps):
            segs.append(cv.poly(ribbon(arc_pts(c[0], c[1], n * r, a0 + k * span, a0 + k * span + span * 0.7, 30), [n * w] * 30)))
        soft_light(cv, union(cv, segs), el, 0.9, R=n * 0.01, glow_r=4)
    for k in range(4):
        a = math.radians(45 + k * 90)
        d = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-d[1], d[0]])
        p = np.array(c) + d * n * 0.44
        m = cv.poly([p + nv * n * 0.05, np.array(c) + d * n * 0.30, p - nv * n * 0.05])
        light_form(cv, m, el, 1.0, R=n * 0.01, glow_r=3, lw=(0.2, 1.0))
    dm = cv.poly([(c[0], c[1] - n * 0.10), (c[0] + n * 0.07, c[1]), (c[0], c[1] + n * 0.10), (c[0] - n * 0.07, c[1])])
    light_form(cv, dm, el, 1.0, R=n * 0.03, glow_r=6, lw=(0.25, 1.3))
    hot_core(cv, c[0], c[1], el, 1.2, 0.8, star_len=12)


@status("atk_down", tone="steel")
def st_atk_down(cv, rng, el):
    """攻击降低: a sword snapped in two, its point falling away, downward red light streaks"""
    n = cv.n
    pal = tone(el)
    for x, y0, y1, w in ((0.30, 0.12, 0.70, 0.03), (0.70, 0.14, 0.72, 0.03)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    grip = cv.poly([(n * 0.46, n * 0.08), (n * 0.54, n * 0.08), (n * 0.54, n * 0.26), (n * 0.46, n * 0.26)])
    material(cv, grip, "leather", R=n * 0.03, lw=(0.3, 1.4))
    guard = cv.poly([(n * 0.28, n * 0.26), (n * 0.72, n * 0.26), (n * 0.70, n * 0.33), (n * 0.30, n * 0.33)])
    material(cv, guard, "gold", R=n * 0.02, lw=(0.3, 1.3))
    upper = cv.poly([(n * 0.44, n * 0.33), (n * 0.56, n * 0.33), (n * 0.555, n * 0.50), (n * 0.52, n * 0.47), (n * 0.49, n * 0.53),
                     (n * 0.445, n * 0.50)])
    material(cv, upper, "steel", R=n * 0.03, lw=(0.3, 1.5), streak_ang=90, back=pal[2], back_k=0.8)
    H = H_affine((n * 0.56, n * 0.60), 14, 1.0)
    lower = cv.poly(xf(H, [(-n * 0.055, 0), (-n * 0.02, -n * 0.03), (n * 0.01, n * 0.01), (n * 0.055, -n * 0.02), (n * 0.05, n * 0.22),
                           (0, n * 0.32), (-n * 0.05, n * 0.22)]))
    material(cv, lower, "steel", R=n * 0.03, lw=(0.3, 1.5), streak_ang=104, back=pal[2], back_k=0.8)
    hot_core(cv, n * 0.52, n * 0.54, el, 1.2, 0.8, star_len=10)


@status("cast_slow", tone="arcane")
def st_cast_slow(cv, rng, el):
    """施法减速: a magic circle whose rune ring is half drained, a gold clock hand stalled on it, motes draining away"""
    n = cv.n
    pal = tone(el)
    c = (n * 0.5, n * 0.5)
    X, Y = cv.grid()
    lit = smoothstep(n * 0.62, n * 0.38, X)    # left half lit, right half drained
    for r, w in ((0.36, 0.03), (0.26, 0.016)):
        ring = cv.poly(ribbon(arc_pts(c[0], c[1], n * r, 0, 360, 80), [n * w] * 80))
        soft_light(cv, ring * (0.2 + 0.8 * lit), el, 0.9, R=n * 0.008, glow_r=3)
    for k in range(12):
        a = math.radians(k * 30)
        p0 = (c[0] + math.cos(a) * n * 0.28, c[1] + math.sin(a) * n * 0.28)
        p1 = (c[0] + math.cos(a) * n * 0.34, c[1] + math.sin(a) * n * 0.34)
        m = cv.poly(ribbon([p0, p1], [n * 0.025, n * 0.01]))
        cv.paint(m, mix(pal[1], pal[2], 0.7) if math.cos(a) < 0.2 else mix(pal[0], pal[1], 0.4), 0.9)
    hand = cv.poly([(c[0] - n * 0.03, c[1] + n * 0.03), (c[0] + n * 0.20, c[1] - n * 0.16), (c[0] + n * 0.03, c[1] + n * 0.04)])
    material(cv, hand, "gold", R=n * 0.01, lw=(0.3, 1.4))
    hub = cv.ellipse(c[0], c[1], n * 0.05)
    material(cv, hub, "gold", R=n * 0.02, lw=(0.3, 1.3))
    for i in range(7):
        x = n * (0.70 + rng.uniform(-0.05, 0.08))
        y = n * (0.60 + i * 0.05)
        cv.add(blur(cv.ellipse(x, y, rng.uniform(0.8, 1.5)), 0.5), pal[2], 0.8)


@status("stealth", tone="shadow")
def st_stealth(cv, rng, el):
    """隐身: a deep hood seen front-on, its lower edge dissolving into drifting smoke, two faint eye glints inside"""
    n = cv.n
    pal = tone(el)
    hood = cv.poly(closed_spline([(n * 0.50, n * 0.10), (n * 0.74, n * 0.24), (n * 0.82, n * 0.50), (n * 0.76, n * 0.72), (n * 0.50, n * 0.78),
                                  (n * 0.24, n * 0.72), (n * 0.18, n * 0.50), (n * 0.26, n * 0.24)], 6))
    X, Y = cv.grid()
    fade = smoothstep(n * 0.78, n * 0.48, Y + (cv.noise - 0.5) * n * 0.25)
    ink_line(cv, hood * (Y < n * 0.5), mix(pal[0], pal[1], 0.4), 0.3, 1.6, 0.4)
    paint_form(cv, hood * fade, [mix(pal[0], "#000000", 0.3), pal[0], pal[1], pal[2]], R=n * 0.08, grad=0.6, tilt=(-0.2, -0.2))
    face = cv.poly(closed_spline([(n * 0.50, n * 0.28), (n * 0.64, n * 0.38), (n * 0.62, n * 0.58), (n * 0.50, n * 0.64), (n * 0.38, n * 0.58),
                                  (n * 0.36, n * 0.38)], 6))
    cv.paint(blur(face, 2) * fade, "#030206", 0.95)
    for x in (0.44, 0.57):
        e = cv.poly([(n * (x - 0.05), n * 0.47), (n * x, n * 0.45), (n * (x + 0.05), n * 0.47), (n * x, n * 0.485)])
        soft_light(cv, e, el, 1.0, R=0.8, glow_r=3)
    for i in range(5):
        y = n * (0.66 + i * 0.05)
        p = [(n * rng.uniform(0.15, 0.3), y), (n * 0.5, y + n * rng.uniform(-0.04, 0.04)), (n * rng.uniform(0.7, 0.88), y - n * 0.02)]
        m = cv.poly(ribbon(spline(p, 6), lambda u: n * 0.04 * math.sin(math.pi * u) + 0.3))
        cv.add(blur(m, 1.5), pal[1], 0.35)


@status("invuln", tone="holy")
def st_invuln(cv, rng, el):
    """无敌: 金钟罩 -- a translucent golden bell of light with ribbed bands, a radiant core inside, rays around"""
    n = cv.n
    pal = tone(el)
    flare_spikes(cv, n * 0.5, n * 0.5, [(a, 0.6 + 0.4 * (k % 2)) for k, a in enumerate(range(-90, 270, 30))], n * 0.30, n * 0.47,
                 n * 0.02, el, 0.5)
    bell = cv.poly(closed_spline([(n * 0.44, n * 0.14), (n * 0.56, n * 0.14), (n * 0.66, n * 0.30), (n * 0.70, n * 0.58), (n * 0.82, n * 0.80),
                                  (n * 0.50, n * 0.84), (n * 0.18, n * 0.80), (n * 0.30, n * 0.58), (n * 0.34, n * 0.30)], 6))
    glow(cv, bell, pal[2], 8, 0.6)
    ink_line(cv, bell, "#5A3A0A", 0.3, 1.6, 0.3)
    paint_form(cv, bell, [mix(pal[0], pal[1], 0.7), pal[1], mix(pal[1], pal[2], 0.6), pal[2]], R=n * 0.10, grad=0.6, alpha=0.85,
               spec=[("#FFFFFF", 10, 0.4, 0.65, 0.8)])
    for y, w in ((0.30, 0.012), (0.62, 0.016), (0.74, 0.012)):
        cv.paint(stroke(cv, [(n * 0.24, n * y + n * 0.04), (n * 0.50, n * y), (n * 0.76, n * y + n * 0.04)], n * w, n * w) * bell, "#8A5A1A", 0.8)
    knob = cv.ellipse(n * 0.5, n * 0.12, n * 0.05)
    material(cv, knob, "gold", R=n * 0.02, lw=(0.3, 1.2))
    hot_core(cv, n * 0.5, n * 0.52, el, 1.6, 1.0, star_len=14)


@status("block", tone="azure")
def st_block(cv, rng, el):
    """格挡: a horizontal parrying blade catching a blow -- a bright spark burst where the strike meets its edge"""
    from painter.weapons import sword
    n = cv.n
    H = H_affine((n * 0.08, n * 0.66), -12, n * 0.90, n * 0.90)
    sword(cv, H, el, blade="straight", width=0.05, blade_from=0.28)
    hit = xf(H, [(0.66, -0.05)])[0]
    for a in (-150, -120, -95, -60, -30):
        ar = math.radians(a)
        light_streak(cv, hit, (hit[0] + math.cos(ar) * n * 0.32, hit[1] + math.sin(ar) * n * 0.32), n * 0.025, el, 0.9)
    shock_ring(cv, hit, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.16, n * 0.08, n * 0.02, el, 0.7, 180, 360)
    hot_core(cv, hit[0], hit[1], el, 1.6, 1.2, star_len=16)


@status("def_up", tone="azure")
def st_def_up(cv, rng, el):
    """防御提升: an intact blue-and-steel tower shield, gold rim, rising chevrons of light behind it"""
    n = cv.n
    pal = tone(el)
    for k in range(3):
        y = n * (0.40 - k * 0.12)
        m = cv.poly([(n * 0.14, y + n * 0.10), (n * 0.50, y - n * 0.06), (n * 0.86, y + n * 0.10), (n * 0.86, y + n * 0.16), (n * 0.50, y),
                     (n * 0.14, y + n * 0.16)])
        soft_light(cv, m, el, 0.6 - k * 0.12, R=n * 0.01, glow_r=3)
    sh = cv.poly(closed_spline([(n * 0.28, n * 0.24), (n * 0.50, n * 0.20), (n * 0.72, n * 0.24), (n * 0.72, n * 0.62), (n * 0.50, n * 0.88),
                                (n * 0.28, n * 0.62)], 4))
    from painter.weapons import MAT as _M  # noqa: F401  (registers the navy material)
    material(cv, sh, "navy", R=n * 0.08, lw=(0.4, 2.2), grad=0.5, back=pal[2], back_k=0.6)
    rim = np.clip(sh - (blur(sh, n * 0.04) > 0.97), 0, 1)
    material(cv, rim, "gold", R=n * 0.01, line=False)
    boss = cv.ellipse(n * 0.5, n * 0.48, n * 0.08)
    material(cv, boss, "steel", R=n * 0.04, lw=(0.3, 1.4))
    up = cv.poly([(n * 0.40, n * 0.42), (n * 0.50, n * 0.32), (n * 0.60, n * 0.42), (n * 0.56, n * 0.44), (n * 0.50, n * 0.38), (n * 0.44, n * 0.44)])
    soft_light(cv, up, el, 0.9, R=0.8, glow_r=2)


@status("matk_up", tone="arcane")
def st_matk_up(cv, rng, el):
    """法攻提升: a faceted arcane crystal floating on rising light, two orbiting motes"""
    n = cv.n
    pal = tone(el)
    for x, y0, y1, w in ((0.30, 0.90, 0.40, 0.03), (0.70, 0.88, 0.42, 0.03), (0.50, 0.96, 0.60, 0.04)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    top, mid_l, mid_r, bot = (n * 0.5, n * 0.10), (n * 0.30, n * 0.42), (n * 0.70, n * 0.42), (n * 0.5, n * 0.84)
    ctr = (n * 0.47, n * 0.44)
    facets = [((top, mid_l, ctr), 1.0), ((top, ctr, mid_r), 0.7), ((mid_l, bot, ctr), 0.5), ((ctr, bot, mid_r), 0.3)]
    allm = union(cv, [cv.poly(f) for f, _ in facets])
    glow(cv, allm, pal[2], 8, 0.7)
    ink_line(cv, allm, mix(pal[0], pal[1], 0.4), 0.3, 1.8, 0.3)
    for f, v in facets:
        m = cv.poly(f)
        paint_form(cv, m, [mix(pal[1], pal[0], 0.4 * (1 - v)), mix(pal[1], pal[2], v * 0.7), mix(pal[2], pal[3], v * 0.8)], R=n * 0.02,
                   grad=0.6, thr=[0.3, 0.7])
    hot_core(cv, n * 0.42, n * 0.28, el, 1.0, 0.7, star_len=10)
    for x, y in ((0.20, 0.30), (0.80, 0.56)):
        soft_light(cv, cv.ellipse(n * x, n * y, n * 0.035), el, 1.0, R=n * 0.02, glow_r=4)


@status("regen", tone="jade")
def st_regen(cv, rng, el):
    """回复: a sprout of two broad leaves unfurling from a glowing seed, healing motes rising"""
    n = cv.n
    seed = cv.ellipse(n * 0.5, n * 0.76, n * 0.10, n * 0.07)
    soft_light(cv, seed, el, 1.0, R=n * 0.04, glow_r=6)
    stem = stroke(cv, [(n * 0.5, n * 0.74), (n * 0.48, n * 0.56), (n * 0.52, n * 0.40)], n * 0.035, n * 0.02)
    paint_form(cv, stem, ["#1A4A22", "#3A8A3A", "#7CC86A"], R=n * 0.01, grad=0.4)
    for sx, ang, L in ((-1, -150, 0.34), (1, -40, 0.36)):
        base = np.array([n * 0.50, n * 0.50])
        a = math.radians(ang)
        d = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-d[1], d[0]])
        tip = base + d * n * L
        leaf = cv.poly(spline([base, base + d * n * L * 0.5 + nv * n * 0.12, tip], 8).tolist() +
                       spline([tip, base + d * n * L * 0.5 - nv * n * 0.08, base], 8).tolist())
        ink_line(cv, leaf, "#0A2A10", 0.3, 1.5, 0.4)
        paint_form(cv, leaf, ["#1E5A28", "#3E9A44", "#8ADC78", "#E0FFD0"], R=n * 0.04, grad=0.5, tilt=(-sx * 0.2, -0.2))
        cv.paint(stroke(cv, [base, base + d * n * L * 0.85], n * 0.012, n * 0.004) * leaf, "#1A4A22", 0.7)
    for x, y in ((0.26, 0.30), (0.74, 0.22), (0.62, 0.12), (0.36, 0.14)):
        soft_light(cv, cv.poly(_star(n * x, n * y, n * 0.05, n * 0.014)), el, 0.9, R=0.8, glow_r=3)


@status("shield", tone="azure")
def st_shield(cv, rng, el):
    """护盾: a translucent barrier bubble -- a sphere of light with a hexagonal lattice, rim-lit, a hit ripple"""
    n = cv.n
    pal = tone(el)
    c = (n * 0.5, n * 0.52)
    sph = cv.ellipse(c[0], c[1], n * 0.36)
    X, Y = cv.grid()
    r = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (n * 0.36)
    fres = np.clip(r, 0, 1) ** 3 * sph
    cv.add(blur(sph, 4) * 0.2, pal[1], 1.0)
    cv.add(fres, pal[2], 0.9)
    lat = np.zeros_like(sph)
    s = n * 0.085
    for i in range(-4, 5):
        for j in range(-4, 5):
            hx = c[0] + i * s * 1.5
            hy = c[1] + j * s * 1.732 + (s * 0.866 if i % 2 else 0)
            pts = _hexagon(hx, hy, s)
            np.maximum(lat, cv.poly(ribbon(np.array(pts + [pts[0]]), [1.1] * 7)), out=lat)
    cv.add(lat * sph * (0.25 + 0.75 * np.clip(r, 0, 1) ** 2), pal[2], 0.8)   # lattice reads mostly near the rim
    rim = np.clip(sph - toward(sph, 2.0, LIGHT), 0, 1)
    cv.add(blur(rim, 0.8), pal[3], 0.9)
    shock_ring(cv, np.array([n * 0.66, n * 0.40]), np.array([0.8, 0.6]), np.array([-0.6, 0.8]), n * 0.10, n * 0.06, n * 0.015, el, 0.8)
    hot_core(cv, n * 0.38, n * 0.36, el, 1.0, 0.6, star_len=8)
