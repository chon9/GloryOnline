"""painter.weapons - class weapon assets drawn in painted materials (bible 2.6). Shared, reusable by every class.

Convention (same as 却邪 in subjects.py): local x runs along the weapon from 0 (butt / grip end) to 1 (tip / muzzle),
local y is across it (screen-down). `H` maps local -> icon space; build it with weapon_H(butt, tip, width_scale)
(affine) or lance_persp(...) / H_quad(...) for foreshortening. Every drawer returns the union mask it painted.

Hero weapons (match the 3D models / bible 2.6):
  umbrella_folded   千机伞 lance form: faceted white canopy spear tip, khaki mechanical shaft, red energy seam
  umbrella_open     千机伞 shield form (local: canopy disc of radius 1 around the origin)
  umbrella_gatling  千机伞 gun form: canopy folded back, six dark barrels out of the hub
  light_sword       冰雨: slim hilt, gold guard wings, translucent ice-cyan energy blade
  hand_cannon       Launcher cannon: brass and steel, hazard band, glowing glass chamber, braided fuse cable
  star_broom        灭绝星尘: dark shaft, gold bands, a fan of star-dust bristles
Generic family drawers (emblems and future bars): sword, staff_head weapons (staff, ring staff, cane, cross,
scythe, axe), guns (revolver, pistol, rifle), tonfa, claw, fist.
"""
import math

import numpy as np

from painter.core import *  # noqa: F401,F403
from painter.core import union

# extra materials (dark -> light ramp, line colour, specular layers)
MAT.update({
    "ivory": (["#5E6478", "#A8B0C2", "#E2E6EE", "#FFFFFF"], "#232A40", [("#FFFFFF", 16, 0.40, 0.62, 0.85)]),
    "khaki": (["#3E3222", "#7E6C50", "#CBB89A", "#F2E6CC"], "#221A0E", [("#FFF6E0", 10, 0.40, 0.66, 0.6)]),
    "brass": (["#3A2408", "#7A5A22", "#B9944A", "#F2D898"], "#22140A", [("#FFE9B0", 6, 0.32, 0.70, 0.7),
                                                                      ("#FFFFFF", 22, 0.42, 0.60, 0.95)]),
    "wood": (["#1A0E06", "#3A2212", "#5E3C22", "#8A5E3A"], "#0E0603", []),
    "navy": (["#080C1C", "#16203C", "#2A3A62", "#4A5E8E"], "#04060E", [("#A8C0FF", 12, 0.40, 0.62, 0.6)]),
    "redlac": (["#2A0408", "#5A0A12", "#9A1A24", "#D2343E"], "#16020A", [("#FFC0C0", 16, 0.40, 0.62, 0.8)]),
    "bronze": (["#2A1406", "#6A3E18", "#B07A3E", "#E8B878"], "#180A02", [("#FFE0B0", 10, 0.38, 0.66, 0.8)]),
})


def weapon_H(butt, tip, width_scale=1.0):
    b, t = np.array(butt, float), np.array(tip, float)
    d = t - b
    L = float(np.linalg.norm(d))
    return H_affine(b, math.degrees(math.atan2(d[1], d[0])), L, L * width_scale)


def _axis_ang(H):
    a = xf(H, [(0.3, 0.0), (0.7, 0.0)])
    return math.degrees(math.atan2(a[1][1] - a[0][1], a[1][0] - a[0][0]))


def lpoly(cv, H, pts):
    return cv.poly(xf(H, pts))


def lrib(cv, H, path, w0, w1=None, n=8):
    """tapered ribbon along a local path; widths in local units"""
    w1 = w0 if w1 is None else w1
    sp = spline(xf(H, path), n) if len(path) > 2 else xf(H, path)
    s0 = hlen(H, path[0], (0, w0))
    s1 = hlen(H, path[-1], (0, w1))
    return cv.poly(ribbon(sp, lambda t: max(0.4, s0 + (s1 - s0) * t)))


def lR(H, r, at=(0.5, 0.0)):
    """local radius -> icon units"""
    return max(0.8, hlen(H, at, (0, r)))


def solid(cv, H, m, mat, r, **kw):
    """paint a mask in a material with a local-unit bevel radius"""
    kw.setdefault("streak_ang", None)
    return material(cv, m, mat, R=lR(H, r), **kw)


def cyl_band(cv, H, x0, x1, hw, mat="gold"):
    m = lpoly(cv, H, [(x0, -hw), (x1, -hw), (x1, hw), (x0, hw)])
    solid(cv, H, m, mat, hw * 0.9, lw=(0.25, 1.1), brk=0.3)
    return m


# ------------------------------------------------------------------ 千机伞
def _umbrella_shaft(cv, H, x0, x1, hw, el):
    ang = _axis_ang(H)
    shaft = lpoly(cv, H, [(x0, -hw), (x1, -hw), (x1, hw), (x0, hw)])
    ink_line(cv, shaft, "#1A1208", 0.4, 1.8, 0.4)
    solid(cv, H, shaft, "khaki", hw * 0.9, line=False, streak_ang=ang, streak_k=0.12, back=tone(el)[2], back_k=0.5)
    # mechanical segments: dark joints + small rivets
    for x in np.linspace(x0 + 0.04, x1 - 0.03, 5):
        j = lpoly(cv, H, [(x, -hw * 1.05), (x + 0.008, -hw * 1.05), (x + 0.008, hw * 1.05), (x, hw * 1.05)])
        cv.paint(j, "#2A2014", 0.85)
    return shaft


def _claw_guard(cv, H, x, hw, el, k=1.0):
    """claw-like hilt guard: two forward-swept khaki spikes and a red-lit collar"""
    parts = []
    for s in (-1, 1):
        parts.append(lrib(cv, H, [(x - 0.02, s * hw * 0.8), (x + 0.02, s * hw * 2.6), (x + 0.075, s * hw * 3.4)], hw * 1.1, 0.002))
    m = union(cv, parts)
    solid(cv, H, m, "khaki", hw * 0.5, lw=(0.3, 1.3), back="#FF3A44", back_k=0.6 * k)
    col_ = lpoly(cv, H, [(x - 0.02, -hw * 1.6), (x + 0.03, -hw * 1.9), (x + 0.03, hw * 1.9), (x - 0.02, hw * 1.6)])
    solid(cv, H, col_, "gold", hw, lw=(0.3, 1.2))
    return union(cv, [m, col_])


def umbrella_folded(cv, H, el, seam_k=1.0, line=True):
    """千机伞 lance form. Shaft 0..0.40, guard at 0.40, folded canopy 0.43..0.97, steel ferrule to 1.0"""
    hw = 0.012
    shaft = _umbrella_shaft(cv, H, 0.0, 0.42, hw, el)
    pommel = lpoly(cv, H, [(-0.03, 0.0), (0.0, -hw * 1.8), (0.02, -hw * 1.5), (0.02, hw * 1.5), (0.0, hw * 1.8)])
    solid(cv, H, pommel, "steel", hw, lw=(0.3, 1.2))
    guard = _claw_guard(cv, H, 0.41, hw, el)
    # canopy: 4 visible facets of a folded 8-panel canopy, widest just past the hub
    xs = [0.43, 0.50, 0.62, 0.78, 0.92, 0.975]
    hws = [0.020, 0.058, 0.056, 0.040, 0.016, 0.004]
    top = [(x, -h) for x, h in zip(xs, hws)]
    bot = [(x, h) for x, h in zip(xs, hws)][::-1]
    canopy = lpoly(cv, H, top + bot)
    ink_line(cv, canopy, "#1E2438", 0.4, 2.0, 0.4)
    fr = [-1.0, -0.45, 0.1, 0.55, 1.0]  # facet boundaries as fraction of the half-width
    vals = [0.95, 0.75, 0.45, 0.28]     # lit top facets -> shadowed bottom facets
    for i in range(4):
        a, b = fr[i], fr[i + 1]
        fpts = [(x, h * a) for x, h in zip(xs, hws)] + [(x, h * b) for x, h in zip(xs, hws)][::-1]
        fm = lpoly(cv, H, fpts) * canopy
        v = vals[i]
        ramp = [mix("#3A4058", "#FFFFFF", v * 0.55), mix("#3A4058", "#FFFFFF", v * 0.8), mix("#3A4058", "#FFFFFF", v),
                mix("#FFFFFF", "#FFFFFF", 1)]
        paint_form(cv, fm, ramp[:3], R=lR(H, 0.01), grad=0.5, thr=[0.35, 0.75], soft=0.08)
        if i in (0, 1):
            f = streak_field(cv.w, _axis_ang(H), 120, 5, cv.seed())
            cv.c *= (1 + 0.08 * (f - 0.5) * 2 * fm)[..., None]
    # rib lines between facets
    for b in fr[1:-1]:
        rib = lrib(cv, H, [(x, h * b) for x, h in zip(xs, hws)][:5], 0.0035, 0.001)
        cv.paint(rib * canopy, "#2A3046", 0.8)
    # red energy seam along the lower edge
    seam = lrib(cv, H, [(x, h * 0.86) for x, h in zip(xs, hws)][:5], 0.006, 0.002)
    glow(cv, seam * canopy, "#E0232E", 3.0, 0.9 * seam_k)
    cv.paint(seam * canopy, "#FF3A44")
    cv.add(np.clip(blur(seam * canopy, 0.4) * 2 - 1, 0, 1), "#FFC8C0", 0.8 * seam_k)
    # spec glint along the top ridge
    sp = lrib(cv, H, [(0.50, -0.040), (0.70, -0.034), (0.88, -0.014)], 0.004, 0.001)
    cv.paint(sp * canopy * smoothstep(0.3, 0.5, cv.noise2), "#FFFFFF", 0.95)
    tip = lpoly(cv, H, [(0.965, -0.006), (1.0, 0.0), (0.965, 0.006)])
    solid(cv, H, tip, "steel", 0.004, lw=(0.2, 0.8))
    return union(cv, [shaft, pommel, guard, canopy, tip])


def umbrella_open(cv, H, el, panels=8, rot=0.0, seam_k=1.0, hub=True):
    """千机伞 shield form: the open canopy. Local: disc of radius 1 centred on the origin (H can tilt it).
    Alternating panel values, dark ribs, scalloped rim between rib tips, one panel edge carries the red seam."""
    pts_rim = []
    parts = []
    tips = []
    for i in range(panels):
        a0 = math.radians(rot + i * 360.0 / panels)
        tips.append((math.cos(a0), math.sin(a0)))
    for i in range(panels):
        p0, p1 = tips[i], tips[(i + 1) % panels]
        mid = ((p0[0] + p1[0]) * 0.5 * 0.93, (p0[1] + p1[1]) * 0.5 * 0.93)  # scallop dips between rib tips
        rim = spline([p0, mid, p1], 6)
        pts_rim.extend(rim[:-1].tolist())
        parts.append([(0.0, 0.0)] + rim.tolist())
    disc = lpoly(cv, H, pts_rim)
    ink_line(cv, disc, "#1E2438", 0.45, 2.4, 0.35)
    L3_ = L3
    for i, pp in enumerate(parts):
        pm = lpoly(cv, H, pp) * disc
        # panel normal: the canopy is a shallow cone, so panels facing the key light are brighter
        c = np.mean(np.asarray(pp[1:]), axis=0)
        q = xf(H, [(0.0, 0.0), tuple(c)])
        d = q[1] - q[0]
        d = d / (np.linalg.norm(d) + 1e-6)
        lit = float(np.clip(0.55 + 0.6 * (d[0] * L3_[0] + d[1] * L3_[1]), 0.0, 1.0))
        v = lit * (0.72 if i % 2 else 1.0)
        # stretched cloth: darker by the hub, lightest just inside the rim, sagging scallop shadow at the rim
        X, Y = cv.grid()
        hub_ = xf(H, [(0.0, 0.0)])[0]
        rad = np.sqrt((X - hub_[0]) ** 2 + (Y - hub_[1]) ** 2) / (lR(H, 1.0, (0, 0)) + 1e-6)
        field = 0.45 * (smoothstep(0.0, 0.8, rad) - 0.5) - 0.35 * smoothstep(0.86, 1.0, rad)
        sf = streak_field(cv.w, math.degrees(math.atan2(d[1], d[0])), 90, 4, cv.seed())
        field = field + 0.12 * (sf - 0.5)
        ramp = [mix("#262B3E", "#B8C0D0", v * 0.6), mix("#3A4058", "#E6EAF2", 0.2 + v * 0.7), mix("#C8CEDC", "#FFFFFF", v),
                "#FFFFFF"]
        paint_form(cv, pm, ramp, R=lR(H, 0.06, (0, 0)), grad=0.35, thr=[0.22, 0.55, 0.9], soft=0.09, field=field)
    for i, t in enumerate(tips):
        rib = lrib(cv, H, [(0.0, 0.0), (t[0] * 0.5, t[1] * 0.5), t], 0.035, 0.012)
        cv.paint(rib * disc, "#2A3046", 0.85)
        cv.paint(np.clip(rib - toward(rib, 0.8, LIGHT), 0, 1) * disc, "#9AA4BA", 0.5)
        tm = cv.ellipse(*xf(H, [t])[0], lR(H, 0.035, t))
        solid(cv, H, tm, "khaki", 0.03, lw=(0.2, 0.9))
    # red seam along one rib
    t = tips[1]
    seam = lrib(cv, H, [(0.08 * t[0], 0.08 * t[1]), (t[0] * 0.55, t[1] * 0.55), (t[0] * 0.96, t[1] * 0.96)], 0.03, 0.012)
    glow(cv, seam, "#E0232E", 4.0, 0.9 * seam_k)
    cv.paint(seam, "#FF3A44")
    cv.add(np.clip(blur(seam, 0.5) * 2 - 1, 0, 1), "#FFD0C8", 0.8 * seam_k)
    hm = disc
    if hub:
        hm_ = cv.ellipse(*xf(H, [(0.0, 0.0)])[0], lR(H, 0.13, (0, 0)))
        solid(cv, H, hm_, "khaki", 0.1, lw=(0.3, 1.4), back="#FF3A44", back_k=0.6)
        cap = cv.ellipse(*xf(H, [(0.0, 0.0)])[0], lR(H, 0.06, (0, 0)))
        solid(cv, H, cap, "gold", 0.05, lw=(0.2, 0.9))
        hm = union(cv, [disc, hm_])
    return hm


def umbrella_gatling(cv, H, el, muzzle_k=1.0):
    """千机伞 gun form, side-on: khaki stock 0..0.30, canopy folded BACK over the body (0.25..0.62), six dark
    barrels out of the hub (0.55..1.0) seen as a bundle: three visible barrels with muzzle rings."""
    hw = 0.016
    stock = lpoly(cv, H, [(0.0, -0.03), (0.06, -0.04), (0.30, -0.03), (0.30, 0.04), (0.16, 0.05), (0.10, 0.12),
                          (0.04, 0.12), (0.08, 0.04), (0.0, 0.035)])
    solid(cv, H, stock, "khaki", 0.02, lw=(0.4, 2.0), back=tone(el)[2], back_k=0.5)
    # barrels (behind the canopy hub): stacked cylinders with brushed steel
    barrels = []
    for j, (oy, val) in enumerate(((-0.040, 0.9), (0.0, 0.6), (0.040, 0.35))):
        b = lpoly(cv, H, [(0.50, oy - 0.017), (0.985, oy - 0.015), (0.985, oy + 0.015), (0.50, oy + 0.017)])
        barrels.append(b)
    ball = union(cv, barrels)
    ink_line(cv, ball, "#05060A", 0.4, 2.0, 0.35)
    for j, b in enumerate(barrels):
        material(cv, b, "darksteel", R=lR(H, 0.012), line=False, streak_ang=_axis_ang(H), streak_k=0.2)
        sep = lrib(cv, H, [(0.5, -0.040 + j * 0.04 + 0.018), (0.985, -0.040 + j * 0.04 + 0.016)], 0.003)
        cv.paint(sep * ball, "#020204", 0.9)
    for x in (0.70, 0.86):
        cyl_band(cv, H, x, x + 0.03, 0.062, "darksteel")
    mz = lpoly(cv, H, [(0.97, -0.064), (1.0, -0.06), (1.0, 0.06), (0.97, 0.064)])
    solid(cv, H, mz, "steel", 0.02, lw=(0.3, 1.2))
    # folded canopy wrapped back over the body: white faceted cowl
    xs = [0.62, 0.55, 0.42, 0.30, 0.24]
    hws = [0.020, 0.075, 0.085, 0.07, 0.03]
    cowl = lpoly(cv, H, [(x, -h) for x, h in zip(xs, hws)] + [(x, h) for x, h in zip(xs, hws)][::-1])
    ink_line(cv, cowl, "#1E2438", 0.4, 2.0, 0.4)
    for i, (a, b, v) in enumerate(((-1.0, -0.3, 0.95), (-0.3, 0.35, 0.65), (0.35, 1.0, 0.35))):
        fm = lpoly(cv, H, [(x, h * a) for x, h in zip(xs, hws)] + [(x, h * b) for x, h in zip(xs, hws)][::-1]) * cowl
        paint_form(cv, fm, [mix("#3A4058", "#FFFFFF", v * 0.6), mix("#3A4058", "#FFFFFF", v * 0.85),
                            mix("#3A4058", "#FFFFFF", v)], R=lR(H, 0.012), grad=0.5, thr=[0.35, 0.75])
    seam = lrib(cv, H, [(x, h * 0.85) for x, h in zip(xs, hws)][1:4], 0.007, 0.004)
    glow(cv, seam * cowl, "#E0232E", 3.0, 0.9)
    cv.paint(seam * cowl, "#FF3A44")
    hub = cv.ellipse(*xf(H, [(0.60, 0.0)])[0], lR(H, 0.05, (0.6, 0)))
    solid(cv, H, hub, "khaki", 0.04, lw=(0.3, 1.3))
    return union(cv, [stock, ball, cowl, hub, mz])


# ------------------------------------------------------------------ 冰雨 light sword
def light_sword(cv, H, halo="#2F9BFF", body="#7FE8FF", core="#FFFFFF", glow_k=1.0, blade_to=1.0, hilt=True):
    """slim hilt (0..0.17), gold swept guard wings at 0.17, energy blade 0.19..blade_to: wide soft halo, saturated
    body, solid white core, flickering broken edge"""
    parts = []
    if hilt:
        grip = lpoly(cv, H, [(0.02, -0.016), (0.165, -0.017), (0.165, 0.017), (0.02, 0.016)])
        ink_line(cv, grip, "#05060C", 0.35, 1.6, 0.3)
        solid(cv, H, grip, "darksteel", 0.014, line=False, streak_ang=_axis_ang(H))
        for x in (0.05, 0.09, 0.13):
            cv.paint(lpoly(cv, H, [(x, -0.018), (x + 0.012, -0.018), (x + 0.012, 0.018), (x, 0.018)]), "#7A849C", 0.7)
        pom = lpoly(cv, H, [(-0.02, 0.0), (0.0, -0.022), (0.025, -0.02), (0.025, 0.02), (0.0, 0.022)])
        solid(cv, H, pom, "gold", 0.015, lw=(0.25, 1.0))
        wings = union(cv, [lrib(cv, H, [(0.175, s * 0.012), (0.15, s * 0.05), (0.10, s * 0.085), (0.06, s * 0.095)], 0.028, 0.004)
                           for s in (-1, 1)])
        collar = lpoly(cv, H, [(0.16, -0.026), (0.195, -0.022), (0.195, 0.022), (0.16, 0.026)])
        solid(cv, H, wings, "gold", 0.01, lw=(0.3, 1.3))
        solid(cv, H, collar, "gold", 0.015, lw=(0.25, 1.0))
        gem = cv.ellipse(*xf(H, [(0.178, 0.0)])[0], lR(H, 0.011, (0.178, 0)))
        cv.paint(gem, body)
        cv.add(blur(gem, 1.5), body, 0.8)
        parts += [grip, pom, wings, collar]
    bl = lpoly(cv, H, [(0.19, -0.016), (blade_to - 0.08, -0.016), (blade_to, 0.0), (blade_to - 0.08, 0.016), (0.19, 0.016)])
    glow(cv, bl, halo, lR(H, 0.09), 0.9 * glow_k)
    glow(cv, bl, body, lR(H, 0.03), 0.7 * glow_k)
    # flickering edge: the body mask is the blade grown by a noisy amount
    flick = np.clip(blur(bl, lR(H, 0.012)) * (0.75 + 0.6 * (cv.noise2 - 0.5)) * 2.2 - 0.3, 0, 1)
    cv.paint(flick, mix(halo, body, 0.5), 0.9)
    paint_form(cv, bl, [body, mix(body, core, 0.6), core], R=lR(H, 0.012), grad=0.2, thr=[0.25, 0.6], soft=0.1)
    cv.add(np.clip(blur(bl, 0.6) * 2 - 1, 0, 1), core, 0.6 * glow_k)
    return union(cv, parts + [bl])


# ------------------------------------------------------------------ launcher hand cannon
def hand_cannon(cv, H, el, chamber_k=1.0, cable=True, muzzle_glow=0.0):
    """side view. Barrel 0.12..1.0 (half-width ~0.10), rear cap at 0..0.12, glass energy chamber at 0.26..0.44,
    hazard band at 0.64..0.72, muzzle flare ring at 0.94..1.0, pistol grip and top carry handle, fuse cable."""
    pal = tone(el)
    ang = _axis_ang(H)
    parts = []
    if cable:
        cab = lrib(cv, H, [(0.06, 0.08), (-0.02, 0.22), (0.08, 0.34), (0.30, 0.30), (0.40, 0.20)], 0.022, 0.018, 10)
        solid(cv, H, cab, "leather", 0.012, lw=(0.3, 1.4))
        # braid: short diagonal ticks along the cable
        for t in np.linspace(0.05, 0.95, 14):
            p = spline([(0.06, 0.08), (-0.02, 0.22), (0.08, 0.34), (0.30, 0.30), (0.40, 0.20)], 10)
            i = int(t * (len(p) - 2))
            a, b = p[i], p[i + 1]
            d = (b - a) / (np.linalg.norm(b - a) + 1e-9)
            nn = np.array([-d[1], d[0]])
            tk = lrib(cv, H, [tuple(a - nn * 0.01 - d * 0.006), tuple(a + nn * 0.01 + d * 0.006)], 0.005)
            cv.paint(tk * cab, "#C8A060", 0.6)
        parts.append(cab)
    grip = lpoly(cv, H, [(0.20, 0.08), (0.30, 0.08), (0.27, 0.26), (0.18, 0.27)])
    solid(cv, H, grip, "leather", 0.03, lw=(0.35, 1.6))
    handle = lrib(cv, H, [(0.48, -0.10), (0.56, -0.17), (0.66, -0.17), (0.72, -0.10)], 0.022, 0.022, 6)
    solid(cv, H, handle, "darksteel", 0.01, lw=(0.3, 1.4))
    body = lpoly(cv, H, [(0.0, -0.075), (0.12, -0.10), (0.92, -0.10), (0.92, 0.10), (0.12, 0.10), (0.0, 0.075)])
    ink_line(cv, body, "#140C04", 0.45, 2.4, 0.35)
    material(cv, body, "brass", R=lR(H, 0.09), line=False, streak_ang=ang, streak_k=0.12, back=pal[2], back_k=0.6)
    for x0, x1 in ((0.0, 0.12), (0.46, 0.50), (0.84, 0.88)):
        cyl_band(cv, H, x0, x1, 0.104, "darksteel")
    # hazard band: diagonal yellow/black stripes
    hz = lpoly(cv, H, [(0.62, -0.102), (0.74, -0.102), (0.74, 0.102), (0.62, 0.102)])
    stripes = np.zeros_like(hz)
    for k in range(-2, 8):
        x = 0.60 + k * 0.03
        stripes = np.maximum(stripes, lpoly(cv, H, [(x, -0.11), (x + 0.015, -0.11), (x + 0.045, 0.11), (x + 0.03, 0.11)]))
    paint_form(cv, hz, ["#6A5010", "#C8A020", "#F2C230", "#FFE890"], R=lR(H, 0.08), grad=0.4)
    paint_form(cv, hz * stripes, ["#050505", "#121214", "#24242A", "#3A3A44"], R=lR(H, 0.08), grad=0.4)
    # glass energy chamber
    ch = lpoly(cv, H, [(0.26, -0.065), (0.44, -0.065), (0.44, 0.065), (0.26, 0.065)])
    ink_line(cv, ch, "#2A1A04", 0.3, 1.2, 0.0)
    cv.paint(ch, "#4A3A08")
    glow(cv, ch, "#FFE45A", lR(H, 0.08), 0.8 * chamber_k)
    X, Y = cv.grid()
    cc = xf(H, [(0.35, 0.0)])[0]
    rr = lR(H, 0.09, (0.35, 0))
    core_ = np.exp(-((X - cc[0]) ** 2 + (Y - cc[1]) ** 2) / (rr * rr * 0.5))
    cv.paint(ch * np.clip(core_ * 1.4, 0, 1), "#FFF6B0", 0.95 * chamber_k)
    cv.add(ch * core_, "#FFE45A", 0.6 * chamber_k)
    gl = lpoly(cv, H, [(0.27, -0.06), (0.33, -0.06), (0.30, 0.06), (0.27, 0.06)]) * ch
    cv.paint(gl, "#FFFFFF", 0.35)
    for x in (0.26, 0.44):
        cyl_band(cv, H, x - 0.012, x + 0.012, 0.075, "gold")
    # muzzle flare ring + bore
    mz = lpoly(cv, H, [(0.90, -0.13), (1.0, -0.14), (1.0, 0.14), (0.90, 0.13)])
    solid(cv, H, mz, "darksteel", 0.04, lw=(0.4, 1.8))
    rimm = lpoly(cv, H, [(0.975, -0.14), (1.0, -0.14), (1.0, 0.14), (0.975, 0.14)])
    solid(cv, H, rimm, "brass", 0.01, lw=(0.2, 0.8))
    if muzzle_glow:
        bore = lpoly(cv, H, [(0.985, -0.07), (1.0, -0.075), (1.0, 0.075), (0.985, 0.07)])
        cv.add(blur(bore, 2), pal[2], muzzle_glow)
        cv.paint(bore, pal[3], 0.8 * muzzle_glow)
    return union(cv, parts + [grip, handle, body, mz])


# ------------------------------------------------------------------ 灭绝星尘 star broom
def star_broom(cv, H, el, rng, bristle_k=1.0, spread=1.0, sparkle=1.0):
    """dark shaft 0..0.66 with gold bands, binding at 0.62..0.70, bristles 0.68..1.0: a fan of star-dust strokes
    (violet-blue) with white sparkles"""
    ang = _axis_ang(H)
    shaft = lpoly(cv, H, [(0.0, -0.012), (0.66, -0.014), (0.66, 0.014), (0.0, 0.012)])
    ink_line(cv, shaft, "#04040A", 0.4, 1.8, 0.4)
    material(cv, shaft, "lacquer", R=lR(H, 0.012), line=False, streak_ang=ang, streak_k=0.1, back="#8C9BFF", back_k=0.6)
    for x in (0.02, 0.22, 0.44):
        cyl_band(cv, H, x, x + 0.022, 0.017, "gold")
    # bristles: a dense soft fan body (deep blue), then many fine star-dust strokes over it whose tips dissolve
    # into sparkles -- not a rake of equal tines
    fan_pts = [(0.66, -0.035)] + [(0.66 + 0.36 * math.cos(math.radians(a)) * (1.0 - 0.06 * abs(a) / 30),
                                   0.36 * math.sin(math.radians(a)) * 0.55 * spread) for a in np.linspace(-30, 30, 9)] + [(0.66, 0.035)]
    body = lpoly(cv, H, spline(fan_pts, 4))
    body = blur(body, lR(H, 0.012)) * (0.75 + 0.5 * (cv.noise - 0.5))
    glow(cv, body, "#6C7BFF", lR(H, 0.08), 0.55 * bristle_k)
    cv.paint(np.clip(body * 1.3, 0, 1), "#1E2470", 0.9)
    cv.paint(np.clip(body * 1.3, 0, 1) * smoothstep(0.3, 0.7, cv.noise2), "#2E3AA0", 0.6)
    fan = np.zeros((cv.w, cv.w), np.float32)
    for i in range(26):
        f = rng.uniform(-1, 1)
        L = 0.24 + 0.12 * (1 - abs(f)) * rng.uniform(0.6, 1.0)
        p = [(0.67, f * 0.03), (0.67 + L * 0.5, f * 0.09 * spread + rng.uniform(-0.012, 0.012)),
             (0.67 + L, f * 0.19 * spread + rng.uniform(-0.02, 0.02))]
        m = lrib(cv, H, p, rng.uniform(0.006, 0.012), 0.001, 8)
        np.maximum(fan, m, out=fan)
        cv.paint(m, mix("#4A58E0", "#A8B4FF", rng.uniform(0, 1) ** 1.5), 0.75)
        cv.add(m, "#6C7BFF", 0.12 * bristle_k)
    cv.add(np.clip(blur(fan, 0.5) * 1.6 - 0.9, 0, 1), "#E0E6FF", 0.3 * bristle_k)
    fan = np.maximum(fan, np.clip(body, 0, 1))
    X, Y = cv.grid()
    for _ in range(int(22 * sparkle)):
        t = rng.uniform(0.80, 1.10)
        q = xf(H, [(t, rng.uniform(-0.2, 0.2) * spread * (t - 0.62) / 0.4)])[0]
        r = rng.uniform(0.5, 1.5)
        cv.add(np.exp(-((X - q[0]) ** 2 + (Y - q[1]) ** 2) / (r * r)), "#FFFFFF", 1.2)
        if r > 1.15:
            hot_core_cross(cv, q[0], q[1], r * 1.8, "#E8ECFF", 0.6)
    bind = lpoly(cv, H, [(0.62, -0.03), (0.71, -0.04), (0.71, 0.04), (0.62, 0.03)])
    solid(cv, H, bind, "gold", 0.025, lw=(0.3, 1.3))
    for x in (0.645, 0.685):
        cv.paint(lrib(cv, H, [(x, -0.04), (x, 0.04)], 0.004) * bind, "#5A3414", 0.8)
    return union(cv, [shaft, fan, bind])


def hot_core_cross(cv, x, y, size, c, k=1.0):
    """a small 4-point sparkle (star dust, glints)"""
    X, Y = cv.grid()
    dx, dy = np.abs(X - x), np.abs(Y - y)
    s = np.exp(-dy / (0.18 * size)) * np.exp(-dx / size) + np.exp(-dx / (0.18 * size)) * np.exp(-dy / size)
    cv.add(s, c, k)


# ------------------------------------------------------------------ generic families (emblems, future bars)
def sword(cv, H, el, blade="straight", guard="cross", blade_mat="steel", width=0.035, blade_from=0.24, curve=0.0,
          rune=None, grip_mat="leather", guard_mat="gold", line=True):
    """a sword: grip 0.04..blade_from-0.02, guard, blade blade_from..1.0.
    blade: straight | broad | curved (single edge, set curve) | dagger | leaf. guard: cross | wings | tsuba | none"""
    parts = []
    gw = width * 0.45
    grip = lpoly(cv, H, [(0.04, -gw), (blade_from - 0.02, -gw), (blade_from - 0.02, gw), (0.04, gw)])
    pom = cv.ellipse(*xf(H, [(0.03, 0.0)])[0], lR(H, gw * 1.6, (0.03, 0)))
    # blade outline
    xs = np.linspace(blade_from, 1.0, 14)
    if blade == "broad":
        hwf = lambda x: width * (1.0 - 0.15 * (x - blade_from)) if x < 0.88 else width * (1.0 - 0.15 * 0.64) * (1 - (x - 0.88) / 0.12)
    elif blade == "dagger":
        hwf = lambda x: width * (1 - ((x - blade_from) / (1 - blade_from)) ** 1.6)
    elif blade == "leaf":
        hwf = lambda x: width * math.sin(math.pi * min(1.0, (x - blade_from) / (1 - blade_from) * 0.92 + 0.08)) ** 0.7
    else:
        hwf = lambda x: width * (1 - 0.25 * (x - blade_from)) if x < 0.9 else width * 0.8 * (1 - (x - 0.9) / 0.1)
    bend = lambda x: -curve * ((x - blade_from) / (1 - blade_from)) ** 2
    if blade == "curved":
        top = [(x, bend(x) - hwf(x) * 0.9) for x in xs]
        bot = [(x, bend(x) + hwf(x) * 0.6) for x in xs]
        ridge = [(x, bend(x) - hwf(x) * 0.25) for x in xs]
    else:
        top = [(x, bend(x) - hwf(x)) for x in xs]
        bot = [(x, bend(x) + hwf(x)) for x in xs]
        ridge = [(x, bend(x)) for x in xs]
    bl = lpoly(cv, H, top + bot[::-1])
    gm = None
    if guard == "cross":
        gm = lpoly(cv, H, [(blade_from - 0.025, -width * 3.2), (blade_from, -width * 3.4), (blade_from + 0.012, -width * 2.8),
                           (blade_from + 0.012, width * 2.8), (blade_from, width * 3.4), (blade_from - 0.025, width * 3.2)])
    elif guard == "wings":
        gm = union(cv, [lrib(cv, H, [(blade_from + 0.01, s * width * 0.5), (blade_from - 0.02, s * width * 2.4),
                                     (blade_from - 0.07, s * width * 3.2)], width * 1.2, 0.002) for s in (-1, 1)])
    elif guard == "tsuba":
        c = xf(H, [(blade_from - 0.008, 0.0)])[0]
        a = xf(H, [(blade_from - 0.008, 0.0), (blade_from - 0.008, width * 2.2)])
        r = float(np.linalg.norm(a[1] - a[0]))
        d = xf(H, [(blade_from - 0.02, 0.0), (blade_from + 0.005, 0.0)])
        rx = max(1.0, float(np.linalg.norm(d[1] - d[0])))
        u = (d[1] - d[0]) / (np.linalg.norm(d[1] - d[0]) + 1e-6)
        ang_ = math.atan2(u[1], u[0])
        t = np.linspace(0, 2 * math.pi, 40)
        gm = cv.poly(np.c_[c[0] + np.cos(t) * rx * math.cos(ang_) - np.sin(t) * r * math.sin(ang_),
                           c[1] + np.cos(t) * rx * math.sin(ang_) + np.sin(t) * r * math.cos(ang_)])
    allm = union(cv, [grip, pom, bl] + ([gm] if gm is not None else []))
    if line:
        ink_line(cv, allm, "#04050A", 0.4, 2.0, 0.4)
    solid(cv, H, grip, grip_mat, gw, line=False)
    for x in np.linspace(0.06, blade_from - 0.04, 4):
        cv.paint(lrib(cv, H, [(x, -gw), (x + 0.02, gw)], gw * 0.35) * grip, "#C8A060" if grip_mat == "leather" else "#2A2A34", 0.6)
    solid(cv, H, pom, guard_mat, gw, line=False)
    if blade_mat == "energy":
        light_sword(cv, H, hilt=False, blade_to=1.0)
    else:
        fb = lpoly(cv, H, top + ridge[::-1]) * bl
        fe = np.clip(bl - fb, 0, 1)
        ramp_l = MAT[blade_mat][0]
        paint_form(cv, fb, [mix(ramp_l[1], ramp_l[2], 0.3), ramp_l[2], ramp_l[3], "#FFFFFF"], R=lR(H, width * 0.5),
                   tilt=tuple(LIGHT2 * 0.5), grad=0.5, thr=[0.3, 0.62, 0.92])
        paint_form(cv, fe, [ramp_l[0], ramp_l[1], mix(ramp_l[1], ramp_l[2], 0.5), ramp_l[2]], R=lR(H, width * 0.5),
                   tilt=tuple(-LIGHT2 * 0.5), grad=0.5, thr=[0.2, 0.48, 0.78])
        sl = bbox(bl, 2)
        if sl is not None:
            f = streak_field(cv.w, _axis_ang(H), 180, 5, cv.seed())[sl]
            cv.c[sl] *= (1 + 0.16 * (f - 0.5) * 2 * bl[sl])[..., None]
        em = lrib(cv, H, bot[2:], width * 0.12, width * 0.05)
        cv.paint(em * bl * (0.4 + 0.6 * smoothstep(0.3, 0.5, cv.noise2)), "#FFFFFF", 0.8)
        cv.add(bl * (1 - toward(bl, 1.2, LIGHT)), tone(el)[2], 0.6)
        if rune:
            fm = lrib(cv, H, [(blade_from + 0.05, ridge[1][1]), (0.6, ridge[7][1]), (0.82, ridge[10][1])], width * 0.22, width * 0.08)
            glow(cv, fm * bl, rune, 2.5, 0.9)
            cv.paint(fm * bl, rune, 0.9)
            cv.add(np.clip(blur(fm * bl, 0.4) * 2 - 1, 0, 1), "#FFFFFF", 0.6)
    if gm is not None:
        solid(cv, H, gm, guard_mat, width * 0.6, line=False)
    return allm


def pole(cv, H, el, head, shaft_mat="wood", band_mat="gold", gem=None, rng=None):
    """a polearm / staff: shaft 0..0.72 with bands, then a head:
    orb (crystal in curled prongs) | ring (summoner ring + hanging rings) | crook (cane hook + gem) |
    cross (flared cross + gem) | scythe (crescent blade) | axe (double-bit head)"""
    pal = tone(el)
    ang = _axis_ang(H)
    hw = 0.014
    shaft_to = {"orb": 0.80, "ring": 0.74, "crook": 0.74, "cross": 0.66, "scythe": 0.92, "axe": 0.95}[head]
    shaft = lpoly(cv, H, [(0.0, -hw * 0.9), (shaft_to, -hw), (shaft_to, hw), (0.0, hw * 0.9)])
    ink_line(cv, shaft, "#05040A", 0.4, 1.8, 0.4)
    solid(cv, H, shaft, shaft_mat, hw, line=False, streak_ang=ang, streak_k=0.12, back=pal[2], back_k=0.5)
    for x in (0.0, 0.30, shaft_to - 0.06):
        cyl_band(cv, H, x, x + 0.025, hw * 1.35, band_mat)
    parts = [shaft]
    gc = gem or KEY.get("accent", "#D2283A")

    def jewel(x, y, r):
        c = xf(H, [(x, y)])[0]
        rr = lR(H, r, (x, y))
        m = cv.ellipse(c[0], c[1], rr)
        glow(cv, m, gc, rr * 2.2, 0.9)
        cv.paint(m, mix(gc, "#000000", 0.35))
        cv.add(np.exp(-(((cv.grid()[0] - c[0] + rr * 0.3) ** 2 + (cv.grid()[1] - c[1] + rr * 0.3) ** 2) / (rr * rr * 0.35))) * m,
               mix(gc, "#FFFFFF", 0.6), 1.1)
        return m

    if head == "orb":
        prongs = union(cv, [lrib(cv, H, [(0.78, s * 0.012), (0.83, s * 0.06), (0.92, s * 0.065), (0.97, s * 0.03)], 0.016, 0.003)
                            for s in (-1, 1)])
        solid(cv, H, prongs, band_mat, 0.01, lw=(0.3, 1.3))
        parts += [prongs, jewel(0.89, 0.0, 0.045)]
    elif head == "ring":
        ring_c = (0.86, 0.0)
        t = np.linspace(0, 2 * math.pi, 48)
        outer = lpoly(cv, H, [(ring_c[0] + math.cos(a) * 0.12, ring_c[1] + math.sin(a) * 0.12) for a in t])
        inner = lpoly(cv, H, [(ring_c[0] + math.cos(a) * 0.09, ring_c[1] + math.sin(a) * 0.09) for a in t])
        ring = np.clip(outer - inner, 0, 1)
        solid(cv, H, ring, band_mat, 0.012, lw=(0.3, 1.4))
        for a in (150, 210, 270, 90):
            ar = math.radians(a)
            c = xf(H, [(ring_c[0] + math.cos(ar) * 0.105, math.sin(ar) * 0.105)])[0]
            sm = np.clip(cv.ellipse(c[0], c[1], lR(H, 0.028)) - cv.ellipse(c[0], c[1], lR(H, 0.016)), 0, 1)
            solid(cv, H, sm, band_mat, 0.006, lw=(0.2, 0.8))
        parts += [ring, jewel(ring_c[0], 0.0, 0.035)]
    elif head == "crook":
        hook = lrib(cv, H, [(0.72, 0.0), (0.86, -0.01), (0.96, -0.07), (0.95, -0.15), (0.88, -0.17), (0.84, -0.13)], 0.03, 0.012, 10)
        solid(cv, H, hook, shaft_mat, 0.014, lw=(0.35, 1.6), back=pal[2], back_k=0.6)
        cyl_band(cv, H, 0.72, 0.76, 0.024, band_mat)
        parts += [hook, jewel(0.80, -0.10, 0.03)]
    elif head == "cross":
        arms = []
        for p0, p1, w0 in (((0.66, 0.0), (1.0, 0.0), 0.05), ((0.82, -0.17), (0.82, 0.17), 0.05)):
            arms.append(lrib(cv, H, [p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2), p1], w0, w0))
        flares = [lpoly(cv, H, [(x - 0.03, y - 0.05), (x + 0.03, y - 0.05), (x + 0.04, y + 0.05), (x - 0.04, y + 0.05)])
                  for x, y in ((1.0, 0.0),)]
        for (x, y) in ((0.82, -0.17), (0.82, 0.17)):
            flares.append(lpoly(cv, H, [(x - 0.05, y), (x + 0.05, y), (x + 0.04, y + 0.03 * np.sign(y)), (x - 0.04, y + 0.03 * np.sign(y))]))
        cm = union(cv, arms + flares)
        solid(cv, H, cm, band_mat, 0.03, lw=(0.35, 1.8), back=pal[2], back_k=0.5)
        parts += [cm, jewel(0.82, 0.0, 0.035)]
    elif head == "scythe":
        bl = lpoly(cv, H, spline([(0.90, -0.02), (0.96, -0.10), (0.92, -0.24), (0.78, -0.36), (0.58, -0.40)], 6).tolist()
                   + spline([(0.62, -0.36), (0.80, -0.28), (0.86, -0.16), (0.86, -0.04)], 6).tolist())
        solid(cv, H, bl, "steel", 0.03, lw=(0.35, 1.8), streak_ang=ang + 90, back=pal[2], back_k=0.7)
        cyl_band(cv, H, 0.86, 0.92, 0.024, band_mat)
        parts += [bl]
    elif head == "axe":
        for s in (-1, 1):
            hd = lpoly(cv, H, spline([(0.80, s * 0.02), (0.74, s * 0.12), (0.70, s * 0.24), (0.82, s * 0.22), (0.94, s * 0.24),
                                      (0.92, s * 0.12), (0.88, s * 0.02)], 5))
            solid(cv, H, hd, "steel", 0.04, lw=(0.35, 1.8), back=pal[2], back_k=0.6)
            edge = lrib(cv, H, [(0.71, s * 0.235), (0.82, s * 0.215), (0.93, s * 0.235)], 0.01, 0.01)
            cv.paint(edge * hd, "#FFFFFF", 0.7)
            parts.append(hd)
        cap = lpoly(cv, H, [(0.78, -0.04), (0.98, -0.03), (1.0, 0.0), (0.98, 0.03), (0.78, 0.04)])
        solid(cv, H, cap, band_mat, 0.02, lw=(0.3, 1.3))
        parts.append(cap)
        parts.append(jewel(0.84, 0.0, 0.022))
    return union(cv, parts)


def gun(cv, H, el, kind="revolver", flash=0.0):
    """side view, muzzle at x=1. kind: revolver | pistol | rifle"""
    pal = tone(el)
    ang = _axis_ang(H)
    parts = []
    if kind == "rifle":
        stock = lpoly(cv, H, [(0.0, -0.03), (0.30, -0.03), (0.34, 0.03), (0.22, 0.05), (0.02, 0.10), (0.0, 0.08)])
        solid(cv, H, stock, "wood", 0.03, lw=(0.4, 1.8))
        body = lpoly(cv, H, [(0.28, -0.04), (0.62, -0.04), (0.62, 0.035), (0.28, 0.04)])
        barrel = lpoly(cv, H, [(0.6, -0.018), (1.0, -0.014), (1.0, 0.014), (0.6, 0.018)])
        grip = lpoly(cv, H, [(0.36, 0.03), (0.42, 0.03), (0.40, 0.14), (0.34, 0.14)])
        scope = lpoly(cv, H, [(0.38, -0.10), (0.62, -0.09), (0.62, -0.05), (0.38, -0.06)])
        mag = lpoly(cv, H, [(0.48, 0.03), (0.55, 0.03), (0.57, 0.14), (0.50, 0.14)])
        for m, mat in ((grip, "leather"), (mag, "darksteel"), (barrel, "darksteel"), (body, "plate"), (scope, "darksteel")):
            solid(cv, H, m, mat, 0.02, lw=(0.35, 1.6), streak_ang=ang, back=pal[2], back_k=0.5)
        lens = cv.ellipse(*xf(H, [(0.62, -0.075)])[0], lR(H, 0.018))
        cv.paint(lens, "#7FE8FF")
        cv.add(blur(lens, 1.5), "#7FE8FF", 0.6)
        parts += [stock, body, barrel, grip, scope, mag]
    else:
        long_ = kind == "revolver"
        bx0 = 0.42 if long_ else 0.30
        grip = lpoly(cv, H, spline([(0.10, -0.02), (0.26, -0.02), (0.22, 0.10), (0.14, 0.30), (0.02, 0.30), (0.04, 0.12)], 4))
        solid(cv, H, grip, "wood" if long_ else "leather", 0.05, lw=(0.4, 2.0))
        frame = lpoly(cv, H, [(0.08, -0.07), (bx0 + 0.02, -0.07), (bx0 + 0.02, 0.06), (0.26, 0.06), (0.20, 0.10), (0.08, 0.02)])
        solid(cv, H, frame, "plate" if long_ else "darksteel", 0.04, lw=(0.4, 2.0), back=pal[2], back_k=0.5)
        barrel = lpoly(cv, H, [(bx0, -0.06), (1.0, -0.05), (1.0, 0.025), (bx0, 0.03)])
        solid(cv, H, barrel, "steel" if long_ else "darksteel", 0.03, lw=(0.4, 2.0), streak_ang=ang, back=pal[2], back_k=0.6)
        rib = lrib(cv, H, [(bx0, -0.045), (1.0, -0.038)], 0.008)
        cv.paint(rib * barrel, "#FFFFFF", 0.5)
        trig = lrib(cv, H, [(0.20, 0.06), (0.22, 0.13), (0.30, 0.13), (0.30, 0.06)], 0.012, 0.012, 4)
        solid(cv, H, trig, "darksteel", 0.006, lw=(0.2, 0.9))
        parts += [grip, frame, barrel, trig]
        if long_:
            cyl = lpoly(cv, H, [(0.24, -0.09), (0.42, -0.09), (0.42, 0.065), (0.24, 0.065)])
            solid(cv, H, cyl, "steel", 0.05, lw=(0.4, 1.8))
            for y in (-0.05, 0.0, 0.045):
                cv.paint(lrib(cv, H, [(0.26, y), (0.40, y)], 0.012) * cyl, "#3A4256", 0.7)
            ham = lrib(cv, H, [(0.12, -0.06), (0.08, -0.12), (0.04, -0.13)], 0.03, 0.01, 4)
            solid(cv, H, ham, "darksteel", 0.01, lw=(0.2, 1.0))
            cyl_band(cv, H, 0.94, 0.98, 0.06, "brass")
            parts += [cyl, ham]
        else:
            slide = lpoly(cv, H, [(0.10, -0.09), (0.94, -0.09), (0.98, -0.06), (0.98, 0.0), (0.10, 0.0)])
            solid(cv, H, slide, "plate", 0.04, lw=(0.4, 1.8), streak_ang=ang)
            for x in np.linspace(0.14, 0.30, 5):
                cv.paint(lrib(cv, H, [(x, -0.085), (x + 0.01, -0.005)], 0.006) * slide, "#141824", 0.8)
            parts.append(slide)
    if flash:
        mz = xf(H, [(1.04, -0.01)])[0]
        hot_core_cross(cv, mz[0], mz[1], lR(H, 0.25), pal[2], flash)
    return union(cv, parts)


def tonfa(cv, H, el):
    """tonfa: shaft 0..1, side handle at x 0.25 sticking out to -y"""
    pal = tone(el)
    sh = lpoly(cv, H, [(0.0, -0.035), (0.96, -0.035), (1.0, 0.0), (0.96, 0.035), (0.0, 0.035)])
    solid(cv, H, sh, "wood", 0.03, lw=(0.4, 2.0), streak_ang=_axis_ang(H), back=pal[2], back_k=0.6)
    hd = lpoly(cv, H, [(0.20, -0.03), (0.28, -0.03), (0.28, -0.22), (0.20, -0.22)])
    solid(cv, H, hd, "wood", 0.03, lw=(0.35, 1.6))
    cap = lpoly(cv, H, [(0.18, -0.20), (0.30, -0.20), (0.30, -0.25), (0.18, -0.25)])
    solid(cv, H, cap, "gold", 0.02, lw=(0.3, 1.2))
    for x in (0.0, 0.88):
        cyl_band(cv, H, x, x + 0.06, 0.038, "darksteel")
    return union(cv, [sh, hd, cap])


def claw(cv, H, el, blades=3):
    """claw gauntlet: a knuckle plate at the origin end with `blades` long curved blades along +x"""
    pal = tone(el)
    plate = lpoly(cv, H, spline([(0.0, -0.18), (0.26, -0.20), (0.32, 0.0), (0.26, 0.20), (0.0, 0.18), (-0.04, 0.0)], 4))
    solid(cv, H, plate, "darksteel", 0.06, lw=(0.4, 2.0), back=pal[2], back_k=0.5)
    parts = [plate]
    for i in range(blades):
        y = (i - (blades - 1) / 2) * 0.13
        b = lpoly(cv, H, spline([(0.24, y - 0.035), (0.6, y - 0.05), (0.92, y - 0.12), (1.0, y - 0.2)], 6).tolist()
                  + spline([(0.94, y - 0.13), (0.62, y + 0.0), (0.24, y + 0.035)], 6).tolist())
        solid(cv, H, b, "steel", 0.02, lw=(0.35, 1.6), streak_ang=_axis_ang(H), back=pal[2], back_k=0.6)
        parts.append(b)
    for y in (-0.1, 0.0, 0.1):
        rv = cv.ellipse(*xf(H, [(0.12, y)])[0], lR(H, 0.025))
        solid(cv, H, rv, "brass", 0.02, lw=(0.2, 0.8))
    return union(cv, parts)


def fist(cv, H, el, wrap="#ECE6DA", plate_mat="gold"):
    """a clenched fist seen from the front (knuckles toward the viewer, slightly from above). Local: knuckle row
    along y at x~0.62, wrist at x=0. Four finger rolls with knuckle plates, thumb folded across, wrapped forearm."""
    pal = tone(el)
    arm = lpoly(cv, H, [(0.0, -0.20), (0.40, -0.26), (0.40, 0.26), (0.0, 0.22)])
    solid(cv, H, arm, "cloth_red" if wrap is None else "leather", 0.12, lw=(0.4, 2.2))
    # wraps
    for x in np.linspace(0.04, 0.36, 6):
        w = lrib(cv, H, [(x, -0.27), (x + 0.05, 0.27)], 0.03)
        paint_form(cv, w * arm, [mix(wrap, "#000000", 0.55), mix(wrap, "#000000", 0.25), wrap], R=lR(H, 0.02), grad=0.4)
    palm = lpoly(cv, H, spline([(0.36, -0.30), (0.58, -0.32), (0.66, 0.0), (0.58, 0.32), (0.36, 0.30)], 4))
    solid(cv, H, palm, "leather", 0.12, lw=(0.4, 2.2))
    fingers = []
    for i in range(4):
        y = -0.24 + i * 0.16
        f = lpoly(cv, H, spline([(0.52, y - 0.075), (0.70, y - 0.07), (0.76, y), (0.70, y + 0.07), (0.52, y + 0.075)], 4))
        solid(cv, H, f, "leather", 0.05, lw=(0.35, 1.8), back=pal[2], back_k=0.5)
        k = lpoly(cv, H, spline([(0.64, y - 0.06), (0.75, y - 0.055), (0.78, y), (0.75, y + 0.055), (0.64, y + 0.06)], 4))
        solid(cv, H, k, plate_mat, 0.03, lw=(0.3, 1.4))
        fingers += [f, k]
    thumb = lrib(cv, H, [(0.40, 0.30), (0.50, 0.18), (0.58, 0.02)], 0.10, 0.07, 6)
    solid(cv, H, thumb, "leather", 0.04, lw=(0.35, 1.8))
    return union(cv, [arm, palm, thumb] + fingers)
