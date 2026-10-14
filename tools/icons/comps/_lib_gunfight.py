"""_lib_gunfight - reusable drawers for the Gunner and Fighter bars (sharpshooter, spitfire, mechanic, striker,
qi_master). Imported explicitly by those comps files; never auto-discovered (name starts with _lib_).

Weapons use the painter.weapons convention: local x runs 0 (rear / grip) -> 1 (muzzle), local y across it, screen
down; build H with weapon_H(rear_xy, muzzle_xy, width_scale) or H_quad for foreshortening.

  revolver(cv, H, el)          single-action long revolver: blued frame, fluted cylinder, octagon barrel, crimson grip
  auto_pistol(cv, H, el)       slide pistol: serrated slide, olive grip, brass base plate
  rifle(cv, H, el)             long rifle: steel receiver, scope, vented handguard, muzzle brake, orange stripe
  bullet(cv, H, el)            brass case + copper ogive (x 0 base -> 1 tip, half height 0.2)
  grenade(cv, c, r, ang, el, kind)   frag / impact / burst / timed hand grenades (r = body radius)
  muzzle_flash(cv, p, ang, size, el) forward flare cone + side spikes + hot core
  boot_H(ankle, shin_from, toe_dir, L) / boot(cv, H, el)   combat boot (heel bottom origin, toe +x, shin up -y)
  leg(cv, pts, widths, ramp, el, ...)   trouser leg along hip -> knee -> ankle with painted folds
  fist_side(cv, H, el)         gloved fist in profile: wrist x 0 -> knuckles x 1, top of the hand at -y
  palm(cv, H, el, curl)        open hand, palm toward the viewer: wrist at the origin, fingers toward -y
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from painter.core import union
from painter.weapons import MAT, _axis_ang

MAT.update({
    "gf_blued": (["#06070C", "#141826", "#2C3348", "#566079"], "#020308", [("#C8D4F0", 14, 0.40, 0.62, 0.8)]),
    "gf_olive": (["#14160A", "#2E3418", "#525C30", "#808A50"], "#080A04", [("#E8ECC0", 10, 0.40, 0.64, 0.5)]),
    "gf_copper": (["#3A1408", "#7A3418", "#C86A36", "#F6B884"], "#1E0804", [("#FFE6CC", 14, 0.38, 0.62, 0.9)]),
    "gf_orange": (["#3A1404", "#8A3A0C", "#E06A18", "#FFB25A"], "#200A02", [("#FFE0B0", 12, 0.40, 0.62, 0.6)]),
    "gf_gunmetal": (["#101418", "#262E36", "#46525E", "#76848E"], "#06080A", [("#E0ECF6", 14, 0.40, 0.62, 0.8)]),
    "gf_redglove": (["#1E0406", "#4A0A0E", "#8E1A1E", "#C8403A"], "#120203", [("#FFB0A0", 10, 0.40, 0.64, 0.6)]),
    "gf_wrap": (["#3E3A36", "#8A8278", "#C8C0B2", "#F2ECE0"], "#1E1A16", []),
    "gf_skin": (["#4A2A1E", "#9A6248", "#D8A07E", "#F6D2B6"], "#2A140C", [("#FFF0E0", 8, 0.45, 0.70, 0.35)]),
})

CLOTH_DARK = ["#0A0608", "#1E1216", "#3A2428", "#5E3E3E"]
CLOTH_WHITE = ["#3A3634", "#7E766E", "#C2BAAE", "#ECE6DA"]
CLOTH_NAVY = ["#06080E", "#121A2A", "#26344E", "#46587A"]


def _paint_parts(cv, H, parts, back, ang, r=0.03):
    for m, mat in parts:
        solid(cv, H, m, mat, r, lw=(0.35, 1.8), streak_ang=ang, back=back, back_k=0.55)


# ------------------------------------------------------------------ guns
def revolver(cv, H, el, grip="redlac", body="gf_blued", flash=0.0, back=None):
    """single-action long revolver, side view, muzzle at x=1. Returns the union mask."""
    pal = tone(el)
    back = pal[2] if back is None else back
    ang = _axis_ang(H)
    gr = lpoly(cv, H, spline([(0.13, 0.02), (0.03, 0.10), (-0.05, 0.24), (-0.10, 0.36), (-0.03, 0.43), (0.06, 0.36),
                              (0.13, 0.20), (0.22, 0.06)], 4))
    solid(cv, H, gr, grip, 0.05, lw=(0.4, 2.0), back=back, back_k=0.4)
    for t in (0.35, 0.55, 0.75):   # checkering grooves
        a = (0.13 - 0.16 * t, 0.06 + 0.30 * t)
        cv.paint(lrib(cv, H, [(a[0] - 0.05, a[1] - 0.02), (a[0] + 0.07, a[1] + 0.02)], 0.008) * gr, "#14020A", 0.6)
    med = cv.ellipse(*xf(H, [(0.04, 0.24)])[0], lR(H, 0.028))
    solid(cv, H, med, "brass", 0.02, lw=(0.2, 0.8))
    frame = lpoly(cv, H, [(0.0, -0.07), (0.40, -0.07), (0.40, 0.05), (0.30, 0.07), (0.18, 0.07), (0.12, 0.06), (0.02, 0.04)])
    ham = lrib(cv, H, [(0.05, -0.05), (0.01, -0.12), (-0.05, -0.15)], 0.055, 0.03, 4)
    guard = lrib(cv, H, [(0.13, 0.06), (0.14, 0.15), (0.23, 0.165), (0.30, 0.065)], 0.02, 0.02, 5)
    trig = lrib(cv, H, [(0.21, 0.06), (0.195, 0.10), (0.215, 0.135)], 0.025, 0.01, 4)
    _paint_parts(cv, H, [(ham, body), (guard, "brass"), (trig, body), (frame, body)], back, ang)
    barrel = lpoly(cv, H, [(0.37, -0.066), (1.0, -0.058), (1.0, -0.004), (0.37, 0.002)])
    ejector = lpoly(cv, H, [(0.37, 0.0), (0.70, 0.0), (0.72, 0.018), (0.70, 0.036), (0.37, 0.04)])
    sight = lpoly(cv, H, [(0.93, -0.058), (0.955, -0.088), (0.98, -0.058)])
    _paint_parts(cv, H, [(ejector, body), (barrel, body), (sight, body)], back, ang, 0.025)
    cv.paint(lrib(cv, H, [(0.38, -0.050), (0.99, -0.044)], 0.007) * barrel, "#C8D4F0", 0.55)   # octagon flat glint
    cyl = lpoly(cv, H, spline([(0.15, -0.07), (0.17, -0.098), (0.35, -0.098), (0.37, -0.07), (0.37, 0.055),
                               (0.35, 0.08), (0.17, 0.08), (0.15, 0.055)], 3))
    solid(cv, H, cyl, body, 0.05, lw=(0.4, 1.8), back=back, back_k=0.6)
    for y in (-0.06, -0.012, 0.036):   # flutes
        f = lrib(cv, H, [(0.18, y), (0.34, y)], 0.022)
        cv.paint(f * cyl, "#04050A", 0.75)
        cv.paint(np.clip(f - toward(f, 0.5, LIGHT), 0, 1) * cyl, "#7A86A6", 0.5)
    for x0 in (0.15, 0.355, 0.955):
        cyl_band(cv, H, x0, x0 + 0.02, 0.07 if x0 < 0.5 else 0.035, "brass")
    for p in ((0.06, -0.035), (0.27, 0.03)):   # engraving scrolls on the frame
        cv.paint(stroke(cv, xf(H, [(p[0], p[1]), (p[0] + 0.03, p[1] - 0.015), (p[0] + 0.06, p[1]), (p[0] + 0.05, p[1] + 0.015)]),
                        lR(H, 0.006), lR(H, 0.004), 4) * frame, KEY["metal"], 0.8)
    if flash:
        mz = xf(H, [(1.02, -0.03)])[0]
        muzzle_flash(cv, mz, ang, hlen(H, (0.5, 0), (0.45, 0)), el, flash)
    return union(cv, [gr, frame, ham, guard, cyl, barrel, ejector])


def auto_pistol(cv, H, el, flash=0.0, back=None, grip="gf_olive"):
    """automatic pistol, side view, muzzle at x=1"""
    pal = tone(el)
    back = pal[2] if back is None else back
    ang = _axis_ang(H)
    gr = lpoly(cv, H, spline([(0.08, -0.02), (0.30, -0.02), (0.27, 0.12), (0.22, 0.40), (0.02, 0.40), (0.0, 0.30),
                              (0.04, 0.10)], 3))
    solid(cv, H, gr, grip, 0.05, lw=(0.4, 2.0), back=back, back_k=0.4)
    for t in np.linspace(0.12, 0.34, 6):
        cv.paint(lrib(cv, H, [(0.04 + t * 0.05, t), (0.26 - t * 0.12, t)], 0.009) * gr, "#050603", 0.55)
    plate = lpoly(cv, H, [(0.0, 0.38), (0.23, 0.38), (0.23, 0.44), (0.0, 0.44)])
    solid(cv, H, plate, "brass", 0.02, lw=(0.25, 1.0))
    frame = lpoly(cv, H, [(0.04, -0.03), (0.74, -0.03), (0.74, 0.03), (0.40, 0.04), (0.33, 0.05), (0.06, 0.04)])
    guard = lrib(cv, H, [(0.30, 0.04), (0.32, 0.15), (0.44, 0.15), (0.48, 0.04)], 0.022, 0.022, 5)
    trig = lrib(cv, H, [(0.36, 0.035), (0.35, 0.08), (0.375, 0.115)], 0.028, 0.012, 4)
    _paint_parts(cv, H, [(guard, "gf_blued"), (trig, "gf_blued"), (frame, "gf_blued")], back, ang)
    tip = lpoly(cv, H, [(0.96, -0.10), (1.03, -0.10), (1.03, -0.035), (0.96, -0.035)])
    solid(cv, H, tip, "steel", 0.02, lw=(0.3, 1.2))
    slide = lpoly(cv, H, [(0.0, -0.14), (0.95, -0.14), (0.99, -0.115), (0.99, -0.025), (0.0, -0.025)])
    solid(cv, H, slide, "plate", 0.05, lw=(0.4, 2.0), streak_ang=ang, back=back, back_k=0.6)
    for x in np.linspace(0.05, 0.22, 6):
        cv.paint(lrib(cv, H, [(x, -0.135), (x + 0.012, -0.03)], 0.009) * slide, "#0C0E16", 0.8)
    port = lpoly(cv, H, [(0.48, -0.135), (0.66, -0.135), (0.66, -0.09), (0.48, -0.09)])
    cv.paint(port * slide, "#05060A", 0.85)
    cv.paint(lrib(cv, H, [(0.50, -0.105), (0.64, -0.105)], 0.02) * port, "#B9944A", 0.9)   # brass in the port
    cv.paint(lrib(cv, H, [(0.25, -0.128), (0.94, -0.122)], 0.008) * slide, "#FFFFFF", 0.35)
    cv.paint(lrib(cv, H, [(0.30, -0.06), (0.90, -0.06)], 0.012) * slide, KEY["accent"], 0.7)   # accent pinstripe
    if flash:
        mz = xf(H, [(1.05, -0.068)])[0]
        muzzle_flash(cv, mz, ang, hlen(H, (0.5, 0), (0.45, 0)), el, flash)
    return union(cv, [gr, frame, slide, guard, tip])


def rifle(cv, H, el, flash=0.0, back=None):
    """long rifle side view, muzzle at x=1 (stock 0..0.30, scope, vented handguard, brake)"""
    pal = tone(el)
    back = pal[2] if back is None else back
    ang = _axis_ang(H)
    stock = lpoly(cv, H, spline([(0.0, -0.035), (0.10, -0.04), (0.28, -0.045), (0.31, 0.03), (0.22, 0.055), (0.06, 0.12),
                                 (0.0, 0.115)], 3))
    grip = lpoly(cv, H, [(0.30, 0.03), (0.37, 0.03), (0.345, 0.15), (0.28, 0.15)])
    mag = lpoly(cv, H, spline([(0.47, 0.03), (0.55, 0.03), (0.585, 0.16), (0.51, 0.185)], 3))
    _paint_parts(cv, H, [(stock, "gf_gunmetal"), (grip, "leather"), (mag, "gf_blued")], back, ang)
    cv.paint(lrib(cv, H, [(0.03, 0.02), (0.27, -0.005)], 0.022) * stock, KEY["accent"], 0.85)   # orange stripe
    recv = lpoly(cv, H, [(0.27, -0.065), (0.63, -0.065), (0.64, 0.04), (0.28, 0.045)])
    hg = lpoly(cv, H, [(0.62, -0.05), (0.85, -0.045), (0.85, 0.032), (0.62, 0.038)])
    barrel = lpoly(cv, H, [(0.84, -0.022), (0.97, -0.02), (0.97, 0.012), (0.84, 0.015)])
    brake = lpoly(cv, H, [(0.96, -0.036), (1.02, -0.036), (1.02, 0.026), (0.96, 0.026)])
    _paint_parts(cv, H, [(barrel, "darksteel"), (brake, "steel"), (hg, "gf_gunmetal"), (recv, "steel")], back, ang, 0.025)
    for x in np.linspace(0.65, 0.82, 5):   # vents
        cv.paint(lpoly(cv, H, [(x, -0.025), (x + 0.022, -0.025), (x + 0.022, 0.012), (x, 0.012)]) * hg, "#05080A", 0.85)
    for x in (0.975, 0.995):
        cv.paint(lpoly(cv, H, [(x, -0.03), (x + 0.01, -0.03), (x + 0.01, 0.02), (x, 0.02)]) * brake, "#0A0C10", 0.8)
    cv.paint(lpoly(cv, H, [(0.40, -0.03), (0.56, -0.03), (0.56, 0.0), (0.40, 0.0)]) * recv, "#202830", 0.7)  # ejection port
    for xa, xb in ((0.36, 0.40), (0.52, 0.56)):   # scope rings
        solid(cv, H, lpoly(cv, H, [(xa, -0.10), (xb, -0.10), (xb, -0.06), (xa, -0.06)]), "darksteel", 0.01, lw=(0.2, 0.8))
    scope = lpoly(cv, H, spline([(0.31, -0.155), (0.35, -0.135), (0.56, -0.135), (0.61, -0.16), (0.61, -0.085),
                                 (0.56, -0.105), (0.35, -0.105), (0.31, -0.085)], 3))
    solid(cv, H, scope, "darksteel", 0.03, lw=(0.3, 1.4), streak_ang=ang, back=back, back_k=0.5)
    lens = lpoly(cv, H, [(0.6, -0.155), (0.615, -0.155), (0.615, -0.09), (0.6, -0.09)])
    cv.paint(lens, KEY["accent"])
    cv.add(blur(lens, 1.2), KEY["accent"], 0.6)
    if flash:
        mz = xf(H, [(1.03, -0.005)])[0]
        muzzle_flash(cv, mz, ang, hlen(H, (0.5, 0), (0.30, 0)), el, flash)
    return union(cv, [stock, grip, mag, recv, hg, barrel, brake, scope])


def bullet(cv, H, el, k=1.0, case=True, tip="gf_copper", back=None):
    """cartridge: brass case 0..0.58 with an extractor groove, copper ogive 0.56..1. Half height 0.2 local"""
    pal = tone(el)
    back = pal[2] if back is None else back
    parts = []
    if case:
        cs = lpoly(cv, H, [(0.0, -0.21), (0.05, -0.21), (0.06, -0.17), (0.09, -0.17), (0.10, -0.2), (0.58, -0.2),
                           (0.58, 0.2), (0.10, 0.2), (0.09, 0.17), (0.06, 0.17), (0.05, 0.21), (0.0, 0.21)])
        solid(cv, H, cs, "brass", 0.14, lw=(0.3, 1.4), back=back, back_k=0.7 * k)
        parts.append(cs)
    hd = lpoly(cv, H, spline([(0.55, -0.19), (0.76, -0.17), (0.92, -0.09), (1.0, 0.0), (0.92, 0.09), (0.76, 0.17),
                              (0.55, 0.19)], 4))
    solid(cv, H, hd, tip, 0.13, lw=(0.3, 1.4), back=back, back_k=0.8 * k)
    parts.append(hd)
    return union(cv, parts)


def muzzle_flash(cv, p, ang, size, el, k=1.0):
    """forward flare cone + two side spikes + a white-hot core, `size` = forward reach in icon units"""
    flare_spikes(cv, p[0], p[1], [(ang, 1.0), (ang - 24, 0.6), (ang + 24, 0.6), (ang - 80, 0.32), (ang + 80, 0.32)],
                 size * 0.04, size, size * 0.13, el, k)
    hot_core(cv, p[0], p[1], el, max(1.0, size / 28.0), k, star_len=12, ang=ang)


def grenade(cv, c, r, ang, el, kind="frag", body="gf_olive", k=1.0, pin=True, back=None):
    """hand grenade, body radius r, rotated by ang (local -y = fuse end). kind: frag | impact | burst | timed"""
    pal = tone(el)
    back = pal[2] if back is None else back
    H = H_affine(c, ang, r)
    t = np.linspace(0, 2 * math.pi, 64, endpoint=False)
    if kind == "timed":
        bd = lpoly(cv, H, closed_spline([(-0.45, -0.80), (0.45, -0.80), (0.86, -0.40), (0.92, 0.30), (0.62, 0.90), (0.0, 1.0),
                                         (-0.62, 0.90), (-0.92, 0.30), (-0.86, -0.40)], 6))
    elif kind == "impact":
        bd = lpoly(cv, H, np.c_[np.cos(t) * 0.86, 0.12 + np.sin(t) * 0.92 + np.maximum(0, np.sin(t)) * 0.18])
    else:
        bd = lpoly(cv, H, np.c_[np.cos(t) * 0.80, 0.12 + np.sin(t) * 0.98])
    solid(cv, H, bd, body, 0.35, lw=(0.35, 2.0), back=back, back_k=0.8 * k)
    out = [bd]
    if kind == "frag":
        for y in (-0.45, 0.05, 0.55):   # pineapple grooves
            g = lrib(cv, H, [(-0.9, y - 0.06), (0.0, y + 0.05), (0.9, y - 0.06)], 0.07, 0.07, 6)
            cv.paint(g * bd, "#070804", 0.7)
            cv.paint(np.clip(toward(g, 0.6, -LIGHT) - g, 0, 1) * bd, "#B0BA7A", 0.35)
        for x in (-0.42, 0.0, 0.42):
            g = lrib(cv, H, [(x * 1.1, -0.85), (x * 1.25, 0.12), (x * 1.1, 1.0)], 0.06, 0.06, 6)
            cv.paint(g * bd, "#070804", 0.65)
    elif kind == "impact":
        band = lpoly(cv, H, [(-1.0, 0.10), (1.0, 0.10), (1.0, 0.30), (-1.0, 0.30)]) * bd
        material(cv, band, "brass", R=lR(H, 0.08), lw=(0.2, 0.8))
        nose = lpoly(cv, H, spline([(-0.22, 1.08), (0.0, 1.30), (0.22, 1.08)], 3) .tolist() + [(0.0, 0.9)])
        solid(cv, H, nose, "steel", 0.08, lw=(0.25, 1.0))
        cv.paint(lrib(cv, H, [(-0.5, 0.55), (0.5, 0.55)], 0.06) * bd, KEY["accent"], 0.75)
        out.append(nose)
    elif kind == "burst":
        for a in range(0, 360, 45):   # radial blast vents glowing from inside
            ar = math.radians(a)
            vc = xf(H, [(math.cos(ar) * 0.42, 0.12 + math.sin(ar) * 0.52)])[0]
            v = cv.ellipse(vc[0], vc[1], lR(H, 0.11))
            cv.paint(v, "#140804")
            cv.add(blur(v, 1.0) * v, pal[2], 1.0 * k)
        cv.paint(lrib(cv, H, [(-0.82, 0.12), (0.82, 0.12)], 0.08) * bd, KEY["accent"], 0.6)
    elif kind == "timed":
        face = cv.ellipse(*xf(H, [(0.0, 0.14)])[0], lR(H, 0.52))
        solid(cv, H, face, "darksteel", 0.2, lw=(0.3, 1.4))
        fc = xf(H, [(0.0, 0.14)])[0]
        for i in range(12):   # timer ticks around the dial, the first 7 lit
            a = math.radians(-90 + i * 30 + ang)
            p0 = fc + np.array([math.cos(a), math.sin(a)]) * r * 0.34
            p1 = fc + np.array([math.cos(a), math.sin(a)]) * r * 0.46
            tk = cv.poly(ribbon([p0, p1], [r * 0.08, r * 0.08]))
            if i < 7:
                soft_light(cv, tk, el, 0.9 * k, R=0.8, glow_r=2)
            else:
                cv.paint(tk, "#3A3A30", 0.9)
        core = cv.ellipse(fc[0], fc[1], r * 0.22)
        cv.paint(core, "#140A04")
        soft_light(cv, core * cv.ellipse(fc[0], fc[1], r * 0.16), el, 0.9 * k, R=r * 0.08, glow_r=3)
        for y in (-0.52, 0.74):   # ribbed canister bands
            cv.paint(lrib(cv, H, [(-0.9, y - 0.05), (0.0, y + 0.04), (0.9, y - 0.05)], 0.07, 0.07, 6) * bd, "#070804", 0.7)

    cap = lpoly(cv, H, [(-0.30, -0.80), (-0.26, -1.08), (0.26, -1.08), (0.30, -0.80)])
    solid(cv, H, cap, "brass", 0.1, lw=(0.3, 1.2), back=back, back_k=0.6 * k)
    spoon = lrib(cv, H, [(0.15, -1.02), (0.55, -0.92), (0.82, -0.55), (0.86, -0.05)], 0.16, 0.10, 6)
    solid(cv, H, spoon, "steel", 0.06, lw=(0.3, 1.3), back=back, back_k=0.6 * k)
    out += [cap, spoon]
    if pin:
        rc = xf(H, [(-0.52, -1.02)])[0]
        ring = np.clip(cv.ellipse(rc[0], rc[1], r * 0.26) - cv.ellipse(rc[0], rc[1], r * 0.17), 0, 1)
        material(cv, ring, "steel", R=max(0.8, r * 0.04), lw=(0.2, 0.9))
        out.append(ring)
    return union(cv, out)


# ------------------------------------------------------------------ legs
def boot_H(ankle, shin_from, toe_dir, L):
    """frame for boot(): heel bottom at the origin, toe toward +x, shin up toward -y; local (0.22, -0.92) = ankle"""
    v = np.asarray(shin_from, float) - np.asarray(ankle, float)
    v = v / (np.linalg.norm(v) + 1e-9)
    u = np.asarray(toe_dir, float)
    u = u / (np.linalg.norm(u) + 1e-9)
    O = np.asarray(ankle, float) - 0.22 * L * u - 0.92 * L * v
    return np.array([[L * u[0], -L * v[0], O[0]], [L * u[1], -L * v[1], O[1]], [0, 0, 1]], np.float64)


def boot(cv, H, el, mat="leather", sole_back=None, k=1.0):
    """combat boot: leather upper with a brass-buckled strap, laced instep, thick sole and heel block"""
    pal = tone(el)
    upper = lpoly(cv, H, spline([(0.0, -1.0), (0.44, -1.0), (0.46, -0.58), (0.64, -0.36), (0.92, -0.25), (1.02, -0.10),
                                 (0.98, -0.02), (0.0, -0.02), (-0.05, -0.18), (0.04, -0.52)], 3))
    sole = lpoly(cv, H, [(0.0, -0.10), (1.0, -0.10), (1.04, -0.03), (0.98, 0.04), (0.30, 0.04), (0.28, 0.10), (0.0, 0.10),
                         (-0.04, 0.0)])
    material(cv, sole, "darksteel", R=lR(H, 0.05), lw=(0.35, 1.8), back=sole_back or pal[2], back_k=0.8 * k)
    material(cv, upper, mat, R=lR(H, 0.16), lw=(0.4, 2.2), tilt=(0.1, -0.2), back=pal[2], back_k=0.7 * k)
    cv.paint(np.clip(upper - toward(upper, 1.2, -LIGHT), 0, 1) * upper, mix(MAT[mat][0][3], "#FFFFFF", 0.2), 0.5)
    for i in range(4):   # laces across the instep
        a = 0.46 + i * 0.08
        cv.paint(lrib(cv, H, [(a, -0.60 + i * 0.075), (a + 0.09, -0.48 + i * 0.065)], 0.025) * upper, "#C8BCA8", 0.8)
    strap = lpoly(cv, H, [(0.0, -0.80), (0.45, -0.80), (0.45, -0.68), (-0.01, -0.68)]) * upper
    material(cv, strap, "leather", R=lR(H, 0.04), lw=(0.2, 0.9))
    bk = lpoly(cv, H, [(0.18, -0.83), (0.30, -0.83), (0.30, -0.65), (0.18, -0.65)])
    material(cv, bk, "brass", R=lR(H, 0.03), lw=(0.2, 0.8))
    toe = lpoly(cv, H, spline([(0.72, -0.30), (0.92, -0.25), (1.02, -0.10), (0.98, -0.03), (0.72, -0.03)], 3)) * upper
    cv.paint(toe, MAT[mat][0][3], 0.35)
    return union(cv, [upper, sole])


def leg(cv, pts, widths, ramp, el, rim=None, rim_k=0.8, folds=((0.45, 0.6),), seed_ang=None):
    """trouser leg along hip -> knee -> ankle with brushed fold shading and crease strokes at `folds` (t, size)"""
    pal = tone(el)
    sp = spline(pts, 10)
    m = cv.poly(ribbon(sp, widths if not callable(widths) else widths))
    d = sp[-1] - sp[0]
    a = math.degrees(math.atan2(d[1], d[0])) if seed_ang is None else seed_ang
    f = streak_field(cv.w, a, 30, 3, cv.seed())
    ink_line(cv, m, mix(ramp[0], "#000000", 0.4), 0.4, 2.2, 0.4)
    paint_form(cv, m, ramp, R=max(2.0, float(np.max(widths)) * 0.35), grad=0.35, field=(f - 0.5) * 0.35)
    wv = np.interp(np.linspace(0, 1, len(sp)), np.linspace(0, 1, len(widths)), widths)
    dd = np.gradient(sp, axis=0)
    dd /= np.linalg.norm(dd, axis=1, keepdims=True) + 1e-9
    nv = np.c_[-dd[:, 1], dd[:, 0]]
    for t, s in folds:   # crease pull lines (a dark stroke with a lit lip) across the leg
        for j in (-1, 0, 1):
            i = int(np.clip(t + j * 0.06 * s, 0, 1) * (len(sp) - 1))
            c = sp[i]
            w = wv[i]
            p0 = c + nv[i] * w * 0.42
            p1 = c - nv[i] * w * 0.10 + dd[i] * w * 0.35 * s
            cr = stroke(cv, [p0, (p0 + p1) / 2 + dd[i] * w * 0.08, p1], max(0.6, w * 0.07), 0.3) * m
            cv.paint(cr, ramp[0], 0.7)
            cv.paint(toward(cr, 0.8, -LIGHT) * m * (1 - cr), ramp[3], 0.35)
    if rim is not None:
        cv.add(m * (1 - toward(m, 1.4, LIGHT)), rim, rim_k)
    return m


# ------------------------------------------------------------------ hands
def fist_side(cv, H, el, glove="gf_redglove", trim="gold", cuff="gf_wrap", back=None, k=1.0, arm_len=1.2):
    """gloved fist, 3/4 side view: four separate finger rolls stacked across the front, the thumb folded across the
    lower two, a knuckle guard over the roll tops. Local: wrist x 0 -> knuckles x 1, the top of the hand at -y,
    height ~ +-0.45"""
    pal = tone(el)
    back = pal[2] if back is None else back
    arm = lpoly(cv, H, [(-arm_len, -0.30), (0.14, -0.36), (0.16, 0.34), (-arm_len, 0.30)])
    material(cv, arm, cuff, R=lR(H, 0.16), lw=(0.4, 2.2), back=back, back_k=0.6 * k)
    for x in np.linspace(-arm_len + 0.1, 0.0, max(2, int(arm_len * 7))):   # wrap bands
        w = lrib(cv, H, [(x, -0.34), (x + 0.10, 0.34)], 0.035)
        cv.paint(w * arm, MAT[cuff][0][0], 0.6)
    hand = lpoly(cv, H, spline([(0.08, -0.38), (0.45, -0.46), (0.70, -0.44), (0.72, 0.40), (0.45, 0.44), (0.10, 0.38)], 4))
    material(cv, hand, glove, R=lR(H, 0.2), lw=(0.4, 2.4), tilt=(0.1, -0.15), back=back, back_k=0.8 * k)
    rolls = []
    for i, (y, x1) in enumerate(((-0.33, 1.0), (-0.11, 1.03), (0.11, 1.0), (0.31, 0.94))):
        r = lpoly(cv, H, spline([(0.56, y - 0.105), (x1 - 0.06, y - 0.11), (x1, y - 0.06), (x1 + 0.01, y), (x1, y + 0.06),
                                 (x1 - 0.06, y + 0.105), (0.56, y + 0.10)], 4))
        material(cv, r, glove, R=lR(H, 0.07), lw=(0.3, 1.8), brk=0.3, tilt=(0.15, -0.1), back=back, back_k=0.7 * k)
        cr = lrib(cv, H, [(x1 - 0.17, y - 0.08), (x1 - 0.15, y), (x1 - 0.17, y + 0.08)], 0.018, 0.018, 4) * r   # middle-joint fold
        cv.paint(cr, MAT[glove][0][0], 0.8)
        rolls.append(r)
    thumb = lrib(cv, H, [(0.36, 0.40), (0.56, 0.30), (0.78, 0.16), (0.86, 0.10)], 0.18, 0.12, 6)
    material(cv, thumb, glove, R=lR(H, 0.07), lw=(0.35, 1.8), back=back, back_k=0.7 * k)
    cv.paint(lrib(cv, H, [(0.62, 0.30), (0.66, 0.22)], 0.012) * thumb, MAT[glove][0][0], 0.7)
    kp = lrib(cv, H, [(0.66, -0.44), (0.70, -0.10), (0.68, 0.36)], 0.10, 0.08, 5)
    material(cv, kp, trim, R=lR(H, 0.04), lw=(0.25, 1.1), back=back, back_k=0.5 * k)
    for ky in (-0.33, -0.11, 0.11):   # knuckle studs on the guard
        st = cv.ellipse(*xf(H, [(0.69, ky)])[0], lR(H, 0.03))
        material(cv, st, "steel", R=lR(H, 0.025), lw=(0.2, 0.7), brk=0.1)
    cb = lpoly(cv, H, [(0.04, -0.39), (0.16, -0.40), (0.18, 0.38), (0.06, 0.36)])
    material(cv, cb, trim, R=lR(H, 0.04), lw=(0.25, 1.1))
    return union(cv, [arm, hand, thumb] + rolls)


def palm(cv, H, el, curl=0.0, mat="gf_wrap", palm_mat=None, light=False, k=1.0, back=None, spread=1.0):
    """open hand, palm toward the viewer. Local: wrist at the origin, fingers toward -y, palm width ~0.64.
    curl 0 = flat open palm, 1 = clawed grasp (fingers bend toward the viewer and shorten). light=True paints the
    whole hand as a construct of light in `el` (a qi hand). Returns (union mask, palm mask)."""
    pal = tone(el)
    back = pal[2] if back is None else back
    T = lambda pts: xf(H, pts)
    S = lambda p, w: hlen(H, p, (w, 0))
    wrist = cv.poly(T([(-0.28, 0.0), (0.28, 0.0), (0.30, 0.42), (-0.30, 0.42)]))
    pm = cv.poly(T(closed_spline([(-0.30, -0.04), (-0.34, -0.30), (-0.28, -0.48), (-0.10, -0.53), (0.10, -0.54),
                                  (0.27, -0.48), (0.33, -0.30), (0.30, -0.04), (0.0, 0.02)], 6)))
    segs_all, creases = [], []
    for (bx, by), ang, L, w in (((-0.22, -0.45), -20, 0.40, 0.15), ((-0.075, -0.51), -6, 0.47, 0.155),
                                ((0.078, -0.51), 8, 0.44, 0.15), ((0.21, -0.44), 24, 0.33, 0.135)):
        p = np.array([bx, by])
        a = math.radians(ang * spread - 90)
        for s_i, frac in enumerate((0.44, 0.32, 0.24)):
            frac = frac * (1 - 0.35 * curl * (s_i + 1) / 3)
            dv = np.array([math.cos(a), math.sin(a)])
            q = p + dv * L * frac
            ww = w * (1 - s_i * 0.12)
            pa, qa = T([p])[0], T([q])[0]
            seg = cv.poly(ribbon(spline([pa, (pa + qa) / 2, qa], 3), [S(p, ww), S(p, ww * 0.97), S(q, ww * 0.9)]))
            np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.46)), out=seg)
            segs_all.append(seg)
            nv = np.array([-dv[1], dv[0]])
            creases.append(T([p + nv * ww * 0.42, p + dv * 0.01, p - nv * ww * 0.42]))
            p = q
            a += math.radians((10 + 40 * curl) * (1 if ang >= 0 else -1) * 0.5)
    thumb = []
    p = np.array([-0.30, -0.10])
    a = math.radians(-150 + 30 * curl)
    for Ls, ww in ((0.21, 0.17), (0.16, 0.145)):
        dv = np.array([math.cos(a), math.sin(a)])
        q = p + dv * Ls
        pa, qa = T([p])[0], T([q])[0]
        seg = cv.poly(ribbon([pa, (pa + qa) / 2, qa], [S(p, ww), S(p, ww * 0.97), S(q, ww * 0.88)]))
        np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.45)), out=seg)
        thumb.append(seg)
        p = q
        a += math.radians(18 + 20 * curl)
    allm = union(cv, [pm, wrist] + segs_all + thumb)
    if light:
        light_form(cv, union(cv, [pm] + segs_all + thumb), el, k, R=S((0, -0.3), 0.1), glow_r=6, lw=(0.3, 1.8))
        for cp in creases:
            cv.paint(stroke(cv, cp, S((0, -0.5), 0.02), S((0, -0.5), 0.012), 4) * allm, mix(pal[1], pal[0], 0.4), 0.7)
        return allm, pm
    material(cv, wrist, mat, R=S((0, 0.2), 0.14), lw=(0.4, 2.2), back=back, back_k=0.6 * k)
    for y in np.linspace(0.05, 0.38, 5):
        cv.paint(cv.poly(T([(-0.32, y), (0.32, y + 0.05), (0.32, y + 0.08), (-0.32, y + 0.03)])) * wrist, MAT[mat][0][0], 0.5)
    material(cv, pm, palm_mat or mat, R=S((0, -0.3), 0.16), tilt=(0.1, -0.1), lw=(0.4, 2.2), back=back, back_k=0.6 * k)
    for pts in (((-0.26, -0.36), (-0.04, -0.30), (0.20, -0.36)), ((-0.24, -0.22), (0.0, -0.17), (0.12, -0.10))):
        cv.paint(stroke(cv, T(pts), S((0, -0.3), 0.02), 0.3, 6) * pm, MAT[palm_mat or mat][0][0], 0.6)
    for seg in thumb + segs_all:
        material(cv, seg, palm_mat or mat, R=max(1.5, S((0, -0.6), 0.05)), lw=(0.25, 1.3), brk=0.5, back=back, back_k=0.5 * k)
    for cp in creases:
        cv.paint(stroke(cv, cp, S((0, -0.6), 0.016), S((0, -0.6), 0.016), 4), MAT[palm_mat or mat][0][0], 0.7)
    return allm, pm
