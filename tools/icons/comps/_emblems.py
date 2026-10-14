"""Class emblems (bible 7.4): the class weapon, painted, on the class light mass inside the group crest
(frames.emblem_ground / emblem_finish). Weapons are framed head-first (butts run off the crest) and each class gets
its own orientation / secondary motif so the 25 emblems separate in greyscale (bake.py gates the crest interior).
fn(cv, rng, key): key = the class palette key (already active).
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from painter.weapons import (claw, fist, gun, hand_cannon, light_sword, pole, star_broom, sword, tonfa,
                             umbrella_folded, umbrella_open, weapon_H)


def _el(key):
    return list(key["tones"])[0]


def _W(n, butt, tip, ws=1.0):
    return weapon_H((n * butt[0], n * butt[1]), (n * tip[0], n * tip[1]), ws)


def _backlight(cv, key, k=0.5):
    n = cv.n
    lc = key["emblem"][0]
    m = cv.poly([(n * 0.12, n * 0.92), (n * 0.92, n * 0.12), (n * 0.98, n * 0.24), (n * 0.24, n * 0.98)])
    cv.add(blur(m, n * 0.06), lc, 0.35 * k)


# ------------------------------------------------------------------ Swordsman
@emblem("blade_master")
def e_blade_master(cv, rng, key):
    _backlight(cv, key)
    light_sword(cv, _W(cv.n, (0.10, 0.96), (0.90, 0.10), 1.6), glow_k=0.9)


@emblem("berserker")
def e_berserker(cv, rng, key):
    n = cv.n
    cv.add(blur(cv.ellipse(n * 0.5, n * 0.45, n * 0.16, n * 0.36), n * 0.05), key["emblem"][0], 0.35)
    sword(cv, _W(n, (0.50, 1.02), (0.50, 0.06)), _el(key), blade="broad", width=0.09, blade_from=0.30,
          guard_mat="bronze", rune="#E0323C")


@emblem("spellblade")
def e_spellblade(cv, rng, key):
    """point-down blade through a magic circle at the hilt (bible 2.5)"""
    n = cv.n
    H = _W(n, (0.50, 0.06), (0.50, 1.02), 1.0)
    c = xf(H, [(0.28, 0.0)])[0]
    for r, w in ((0.30, 0.012), (0.24, 0.006)):
        ring = np.clip(cv.ellipse(c[0], c[1], n * r, n * r * 0.42) - cv.ellipse(c[0], c[1], n * (r - w), n * (r - w) * 0.42), 0, 1)
        soft_light(cv, ring, "wave", 0.8, R=1.2, glow_r=4)
    for i in range(8):
        a = math.radians(i * 45 + 10)
        p = (c[0] + math.cos(a) * n * 0.27, c[1] + math.sin(a) * n * 0.27 * 0.42)
        soft_light(cv, cv.poly([(p[0], p[1] - n * 0.02), (p[0] + n * 0.012, p[1]), (p[0], p[1] + n * 0.02), (p[0] - n * 0.012, p[1])]),
                   "wave", 0.9, R=0.8, glow_r=2)
    sword(cv, H, _el(key), blade="leaf", width=0.06, blade_from=0.30, rune="#4FE0D8")


@emblem("ghostblade")
def e_ghostblade(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    H = _W(n, (0.88, 0.94), (0.10, 0.12), 1.0)
    for i in range(5):   # ghost flame wisps rising off the blade
        t = 0.45 + i * 0.11
        p = xf(H, [(t, 0.02)])[0]
        path = [p, p + np.array([n * 0.04, n * -0.08]), p + np.array([n * -0.01, n * -0.17]), p + np.array([n * 0.05, n * -0.24])]
        m = cv.poly(ribbon(spline(path, 6), lambda u: n * 0.035 * (1 - u) ** 0.8 + 0.4))
        soft_light(cv, m, "ghost", 0.55, R=n * 0.012, glow_r=4, core_k=0.5)
    sword(cv, H, _el(key), blade="curved", curve=-0.09, width=0.045, guard="tsuba",
          grip_mat="darksteel", guard_mat="darksteel", rune="#B48CFF")


# ------------------------------------------------------------------ Mage
@emblem("battle_mage")
def e_battle_mage(cv, rng, key):
    _backlight(cv, key)
    n = cv.n
    draw_lance(cv, lance_H((n * -0.20, n * 1.18), (n * 0.92, n * 0.08), 1.9), "gold", tassel=True)


@emblem("elementalist")
def e_elementalist(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    H = _W(n, (-0.70, 1.62), (0.80, 0.18), 1.6)
    pole(cv, H, _el(key), "orb", shaft_mat="wood", gem="#C89CFF")
    c = xf(H, [(0.89, 0.0)])[0]
    for a, el in ((200, "fire"), (320, "frost"), (80, "volt")):
        ar = math.radians(a)
        p = (c[0] + math.cos(ar) * n * 0.26, c[1] + math.sin(ar) * n * 0.20)
        soft_light(cv, cv.ellipse(p[0], p[1], n * 0.035), el, 1.0, R=n * 0.025, glow_r=6)


@emblem("witch")
def e_witch(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    star_broom(cv, _W(n, (1.50, -0.12), (0.10, 0.80), 1.4), "star", rng, spread=1.3)


@emblem("summoner")
def e_summoner(cv, rng, key):
    n = cv.n
    cv.add(blur(cv.ellipse(n * 0.5, n * 0.36, n * 0.3), n * 0.06), key["emblem"][1], 0.35)
    pole(cv, _W(n, (0.50, 1.90), (0.50, 0.06), 1.4), _el(key), "ring", gem="#6FE0B0")


# ------------------------------------------------------------------ Gunner
@emblem("sharpshooter")
def e_sharpshooter(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    gun(cv, _W(n, (0.70, 0.86), (0.08, 0.20), 1.0), _el(key), "revolver")
    gun(cv, _W(n, (0.30, 0.86), (0.92, 0.20), 1.0), _el(key), "revolver")


@emblem("spitfire")
def e_spitfire(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    g = cv.ellipse(n * 0.66, n * 0.62, n * 0.13, n * 0.15)
    material(cv, g, "plate", R=n * 0.06, lw=(0.4, 2.0), back=tone(_el(key))[2], back_k=0.5)
    for y in (0.56, 0.66):
        cv.paint(cv.poly(ribbon([(n * 0.54, n * y), (n * 0.78, n * y)], [n * 0.015] * 2)) * g, "#202418", 0.8)
    cap = cv.poly([(n * 0.60, n * 0.44), (n * 0.72, n * 0.44), (n * 0.72, n * 0.50), (n * 0.60, n * 0.50)])
    material(cv, cap, "brass", R=n * 0.02, lw=(0.3, 1.2))
    lever = stroke(cv, [(n * 0.72, n * 0.46), (n * 0.80, n * 0.50), (n * 0.82, n * 0.62)], n * 0.022, n * 0.014)
    material(cv, lever, "steel", R=n * 0.01, lw=(0.3, 1.2))
    gun(cv, _W(n, (0.18, 0.86), (0.62, 0.16), 1.0), _el(key), "pistol")


@emblem("launcher")
def e_launcher(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    hand_cannon(cv, _W(n, (0.16, 0.76), (0.88, 0.22), 0.95), "blast")


@emblem("mechanic")
def e_mechanic(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    gun(cv, _W(n, (0.02, 0.70), (1.0, 0.36), 1.0), _el(key), "rifle")


# ------------------------------------------------------------------ Fighter
@emblem("striker")
def e_striker(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    fist(cv, _W(n, (0.24, 0.86), (0.70, 0.26), 1.0), _el(key), wrap="#ECE6DA")


@emblem("qi_master")
def e_qi_master(cv, rng, key):
    n = cv.n
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.30), (-0.55, 0.30)]
    dst = [(n * 0.24, n * 0.20), (n * 0.80, n * 0.16), (n * 0.80, n * 0.84), (n * 0.26, n * 0.82)]
    H = H_quad(src, dst)
    gauntlet_palm(cv, H, "qi")
    pc = xf(H, [(0.0, -0.28)])[0]
    soft_light(cv, cv.ellipse(pc[0], pc[1], n * 0.10), "qi", 1.0, R=n * 0.06, glow_r=12, core_k=1.2)
    hot_core(cv, pc[0], pc[1], "qi", 2.6, 1.0, star_len=14)


@emblem("grappler")
def e_grappler(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    tonfa(cv, _W(n, (0.20, 0.80), (0.84, 0.22), 1.6), _el(key))
    tonfa(cv, _W(n, (0.80, 0.80), (0.16, 0.22), 1.6), _el(key))


@emblem("brawler")
def e_brawler(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    claw(cv, _W(n, (0.22, 0.78), (0.86, 0.22), 0.9), _el(key))


# ------------------------------------------------------------------ Nightwalker
@emblem("assassin")
def e_assassin(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    sword(cv, _W(n, (0.24, 0.86), (0.80, 0.16), 1.0), "steel", blade="curved", curve=0.05,
          width=0.05, blade_from=0.28, guard="cross", guard_mat="steel", grip_mat="cloth_red")
    sword(cv, _W(n, (0.76, 0.86), (0.20, 0.16), 1.0), "steel", blade="curved", curve=-0.05,
          width=0.05, blade_from=0.28, guard="cross", guard_mat="steel", grip_mat="cloth_red")


@emblem("ninja")
def e_ninja(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    sword(cv, _W(n, (0.12, 0.92), (0.88, 0.14)), "steel", blade="straight", width=0.04, blade_from=0.30, guard="tsuba",
          grip_mat="cloth_red", guard_mat="darksteel")
    for i, (x, y) in enumerate(((0.30, 0.30), (0.70, 0.70))):   # shuriken
        pts = []
        for k in range(8):
            a = math.radians(k * 45 + 20)
            r = n * (0.075 if k % 2 == 0 else 0.025)
            pts.append((n * x + math.cos(a) * r, n * y + math.sin(a) * r))
        m = cv.poly(pts)
        material(cv, m, "steel", R=n * 0.015, lw=(0.3, 1.3))
        cv.paint(cv.ellipse(n * x, n * y, n * 0.01), "#05060C")


@emblem("thief")
def e_thief(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    H = _W(n, (0.50, 0.04), (0.50, 0.92), 1.0)
    sword(cv, H, _el(key), blade="dagger", width=0.10, blade_from=0.36, guard="cross", guard_mat="brass", rune="#7CFF6B")
    tp = xf(H, [(0.97, 0.0)])[0]
    drop = cv.poly(closed_spline([(tp[0], tp[1] + n * 0.02), (tp[0] + n * 0.02, tp[1] + n * 0.06), (tp[0], tp[1] + n * 0.08),
                                  (tp[0] - n * 0.02, tp[1] + n * 0.06)], 4))
    soft_light(cv, drop, "poison", 1.0, R=n * 0.015, glow_r=4)


@emblem("warlock")
def e_warlock(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    """the cursed tome (bible 2.5) in front of the cane: a closed book in 3/4 with a glowing hexagram on the cover"""
    pole(cv, _W(n, (1.10, 1.30), (0.20, 0.10), 1.4), _el(key), "crook", shaft_mat="lacquer", band_mat="steel", gem="#7CFF6B")
    cover = [(n * 0.26, n * 0.40), (n * 0.66, n * 0.30), (n * 0.80, n * 0.70), (n * 0.40, n * 0.82)]
    pages = cv.poly([cover[3], cover[2], (cover[2][0] + n * 0.02, cover[2][1] + n * 0.06), (cover[3][0] + n * 0.02, cover[3][1] + n * 0.06)])
    paint_form(cv, pages, ["#6A5E44", "#B8A880", "#E6D8B8"], R=n * 0.01, grad=0.4)
    for k in range(4):
        y = 0.012 + k * 0.012
        cv.paint(cv.poly(ribbon([(cover[3][0] + n * 0.01, cover[3][1] + n * y), (cover[2][0] + n * 0.01, cover[2][1] + n * y)],
                                [0.6, 0.6])) * pages, "#5A4E36", 0.6)
    cm = cv.poly(cover)
    material(cv, cm, "leather", R=n * 0.05, lw=(0.4, 2.2), grad=0.5, back="#7CFF6B", back_k=0.5)
    for c_ in cover:   # silver corner caps
        cap = cv.ellipse(c_[0], c_[1], n * 0.045) * cm
        material(cv, cap, "steel", R=n * 0.01, line=False)
    cx, cy = np.mean([p[0] for p in cover]), np.mean([p[1] for p in cover])
    ring = np.clip(cv.ellipse(cx, cy, n * 0.15, n * 0.13) - cv.ellipse(cx, cy, n * 0.13, n * 0.11), 0, 1)
    hooks = []   # three curling hooks spiralling into a closed eye: an original curse seal, no real-world symbol
    for k in range(3):
        a0 = math.radians(-90 + k * 120)
        path = [(cx + math.cos(a0 + t * 2.2) * n * (0.12 - t * 0.09), cy + math.sin(a0 + t * 2.2) * n * (0.10 - t * 0.075))
                for t in np.linspace(0, 1, 7)]
        hooks.append(cv.poly(ribbon(spline(path, 5), lambda u: n * 0.022 * (1 - u) + 0.5)))
    eye = cv.ellipse(cx, cy, n * 0.035, n * 0.02)
    sig = union(cv, [ring, eye] + hooks)
    soft_light(cv, sig, "curse", 1.0, R=1.0, glow_r=5, core_k=0.8)


# ------------------------------------------------------------------ Priest
@emblem("knight")
def e_knight(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    sh = cv.poly(spline([(n * 0.40, n * 0.30), (n * 0.82, n * 0.30), (n * 0.80, n * 0.58), (n * 0.61, n * 0.84),
                         (n * 0.42, n * 0.58)], 6))
    material(cv, sh, "plate", R=n * 0.07, lw=(0.45, 2.4), grad=0.5, back="#7FB4FF", back_k=0.5)
    trim = np.clip(sh - (blur(sh, n * 0.03) > 0.97), 0, 1)
    material(cv, trim, "gold", R=n * 0.01, line=False)
    cr = union(cv, [cv.poly(ribbon([(n * 0.61, n * 0.38), (n * 0.61, n * 0.72)], [n * 0.035] * 2)),
                    cv.poly(ribbon([(n * 0.49, n * 0.48), (n * 0.73, n * 0.48)], [n * 0.035] * 2))])
    material(cv, cr * sh, "cloth_red", R=n * 0.01, line=False)
    sword(cv, _W(n, (0.22, 0.88), (0.52, 0.12)), _el(key), blade="straight", width=0.035, blade_from=0.24)


@emblem("exorcist")
def e_exorcist(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    pole(cv, _W(n, (-0.10, 1.30), (0.50, 0.12), -1.4), _el(key), "scythe", shaft_mat="lacquer", band_mat="steel")
    for x, y in ((0.70, 0.62), (0.80, 0.44)):   # paper talismans
        t = cv.poly([(n * (x - 0.05), n * (y - 0.10)), (n * (x + 0.05), n * (y - 0.11)), (n * (x + 0.06), n * (y + 0.12)),
                     (n * (x - 0.04), n * (y + 0.13))])
        paint_form(cv, t, ["#8A7A50", "#D8C898", "#F6ECD0"], R=n * 0.02, grad=0.5)
        cv.paint(cv.poly(ribbon([(n * x, n * (y - 0.07)), (n * (x + 0.005), n * (y + 0.09))], [n * 0.012] * 2)) * t, "#B01A20", 0.9)


@emblem("cleric")
def e_cleric(cv, rng, key):
    n = cv.n
    cv.add(blur(cv.ellipse(n * 0.5, n * 0.36, n * 0.28), n * 0.06), "#FFD86A", 0.45)
    pole(cv, _W(n, (0.50, 1.70), (0.50, 0.10), 1.3), _el(key), "cross", shaft_mat="ivory", gem="#3FA9FF")


@emblem("paladin")
def e_paladin(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    for s_ in (-1, 1):   # wing motif behind
        for i in range(4):
            p0 = (n * (0.5 + s_ * 0.06), n * 0.60)
            p1 = (n * (0.5 + s_ * (0.26 + i * 0.05)), n * (0.40 + i * 0.07))
            m = cv.poly(ribbon(spline([p0, ((p0[0] + p1[0]) / 2, p0[1] - n * 0.08), p1], 6), lambda u: n * 0.04 * (1 - u) + 0.5))
            cv.paint(blur(m, 0.8), "#F2F4FA", 0.25)
    pole(cv, _W(n, (-0.50, 1.50), (0.80, 0.16), 1.3), _el(key), "axe", shaft_mat="ivory", gem="#7FB4FF")


# ------------------------------------------------------------------ 散人
@emblem("unspecialized")
def e_unspecialized(cv, rng, key):
    n = cv.n
    _backlight(cv, key)
    Hd = H_affine((n * 0.60, n * 0.38), -24, n * 0.27, n * 0.19)
    umbrella_open(cv, Hd, "white", rot=12, seam_k=0.8)
    cv.paint(blur(cv.ellipse(n * 0.60, n * 0.38, n * 0.27, n * 0.19), 4), "#0B1222", 0.30)
    umbrella_folded(cv, _W(n, (0.02, 1.02), (0.74, 0.30), 1.7), "white")
