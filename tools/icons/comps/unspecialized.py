"""散人 Unspecialized (君莫笑 / 千机伞). Tones: white (umbrella canopy), red (energy seam / scarf), gold, blast.
The bar's one off-key accent: the ultimate's ice-cyan rim.

Value plan (one big greyscale shape each):
  atk1            profile thrust, long diagonal rising left -> right, ring at the tip     [umbrella: lance form]
  sky_strike      tall rising crescent sweeping up the left side, debris flung up
  dragon_tooth    one huge horizontal fang of red qi driving right into a hot point, stun stars
  anti_tank       gun form low-left, three shells in a diagonal chain to a blast top-right [umbrella: gun form]
  sword_draw      thin horizontal iai crescent across the middle + a sword-qi crescent flying right
  eagle_stamp     a gold eagle talon stamping straight down into a flat crater ellipse
  shield_attack   the open canopy as a big disc with a bash shock to the right               [umbrella: shield form]
  myriad_combo    pinwheel: canopy hub with lance / gun / blade forms radiating, ring slash  [umbrella: all forms]
The umbrella appears in 4 of 8.
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403


def _dir(a_deg):
    a = math.radians(a_deg)
    return np.array([math.cos(a), math.sin(a)]), np.array([-math.sin(a), math.cos(a)])


@skill("unspecialized.atk1", tone="white")
def thrust(cv, rng, el):
    n = cv.n
    ang = -24.0
    d, nv = _dir(ang)
    tip = np.array([n * 0.80, n * 0.38])
    butt = tip - d * n * 1.25
    band = cv.poly([butt + nv * n * 0.18, tip + nv * n * 0.20 + d * n * 0.3, tip - nv * n * 0.20 + d * n * 0.3, butt - nv * n * 0.18])
    ground(cv, el, [(band, 1)], focus=tip, focus_r=0.40, focus_k=0.8, wash=ang, rng=rng)
    speed_lines(cv, rng, ang, 9, "white", 0.6, length=(0.35, 0.7), band=(0.15, 0.85))
    # the red seam leaves a long light trail along the thrust
    trail(cv, [tip - d * n * 0.95 + nv * n * 0.03, tip - d * n * 0.5 + nv * n * 0.035, tip - d * n * 0.12 + nv * n * 0.02],
          0.5, n * 0.03, "red", 0.9)
    H = weapon_H(butt, tip, 1.15)
    umbrella_folded(cv, H, el)
    shock_ring(cv, tip + d * n * 0.04, nv, d, n * 0.17, n * 0.06, n * 0.03, el, 1.0)
    shock_ring(cv, tip + d * n * 0.11, nv, d, n * 0.25, n * 0.08, n * 0.016, el, 0.5)
    hot_core(cv, tip[0] + d[0] * 3, tip[1] + d[1] * 3, el, 2.6, 1.1, star_len=18, ang=ang)


@skill("unspecialized.sky_strike", tone="red")
def sky_strike(cv, rng, el):
    n = cv.n
    low = cv.poly([(0, n * 0.82), (n * 0.4, n * 0.76), (n, n * 0.84), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.62, n * 0.20), focus_r=0.5, focus_k=0.7, wash=-70, rng=rng)
    c = (n * 0.28, n * 0.58)
    crescent(cv, c, n * 0.54, n * 0.50, 0, 95, -62, 0.50, el, 1.0)
    head = np.array(c) + np.array([math.cos(math.radians(-60)), math.sin(math.radians(-60))]) * np.array([n * 0.54, n * 0.50])
    for x, y0, y1, w in ((0.50, 0.80, 0.36, 0.022), (0.40, 0.70, 0.40, 0.014), (0.62, 0.92, 0.50, 0.012)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * w, el, 0.8)
    shock_ring(cv, np.array([n * 0.46, n * 0.86]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.30, n * 0.06, n * 0.016, el, 0.6)
    for x, y, s, a in ((0.84, 0.16, 0.13, 20), (0.36, 0.14, 0.10, -30), (0.56, 0.30, 0.08, 60)):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 1.0, trail=np.array([0.15, -1.0]) / 1.011)
    hot_core(cv, head[0], head[1] + n * 0.02, el, 2.6, 1.1, star_len=18)


@skill("unspecialized.dragon_tooth", tone="red")
def dragon_tooth(cv, rng, el):
    n = cv.n
    hit = np.array([n * 0.84, n * 0.46])
    band = cv.poly([(0, n * 0.30), (n, n * 0.34), (n, n * 0.62), (0, n * 0.66)])
    ground(cv, el, [(band, 1)], focus=hit, focus_r=0.42, focus_k=0.8, wash=-4, rng=rng)
    speed_lines(cv, rng, -2, 7, el, 0.55, length=(0.3, 0.6), band=(0.25, 0.75))
    # the fang: a single dragon canine, convex back, concave inner edge, curving down to a needle point at the hit;
    # ivory with enamel gloss, wrapped in red qi flames that stream back to the left (the stab's motion)
    upper = spline([(n * 0.06, n * 0.24), (n * 0.38, n * 0.24), (n * 0.66, n * 0.32), hit], 10)
    lower = spline([hit, (n * 0.64, n * 0.44), (n * 0.40, n * 0.52), (n * 0.10, n * 0.66)], 10)
    root = spline([(n * 0.10, n * 0.66), (n * 0.04, n * 0.50), (n * 0.06, n * 0.24)], 6)
    fang = cv.poly(np.vstack([upper, lower, root]))
    aura = dilate(fang, n * 0.03)
    for i in range(6):   # qi flame tongues streaming back
        y = n * (0.26 + i * 0.075)
        x0 = n * (0.30 + 0.08 * math.sin(i * 1.7))
        f = cv.poly(ribbon(spline([(x0, y), (x0 - n * 0.18, y - n * 0.03), (x0 - n * 0.36, y + n * 0.02)], 6),
                           lambda u: n * 0.06 * (1 - u) ** 0.8 + 0.4))
        soft_light(cv, f, el, 0.7, R=n * 0.02, glow_r=4, core_k=0.5)
    soft_light(cv, np.clip(aura - fang, 0, 1), el, 1.0, R=n * 0.012, glow_r=6, core_k=0.6)
    material(cv, fang, "bone", R=n * 0.07, lw=(0.35, 2.2), tilt=(-0.1, -0.35), grad=0.6)
    cv.add(fang * (1 - toward(fang, 2.0, LIGHT)), tone(el)[2], 0.7)   # red qi back-rim on the shadow edge
    for i, (x, y0, y1) in enumerate(((0.20, 0.27, 0.60), (0.36, 0.27, 0.51))):   # enamel growth lines
        cv.paint(stroke(cv, [(n * x, n * y0), (n * (x - 0.03), n * ((y0 + y1) / 2)), (n * (x - 0.01), n * y1)], n * 0.01, n * 0.006) * fang,
                 "#8A6A44", 0.5)
    gl = stroke(cv, [(n * 0.18, n * 0.29), (n * 0.46, n * 0.29), (n * 0.68, n * 0.37)], n * 0.02, n * 0.006)
    cv.paint(gl * fang * smoothstep(0.3, 0.5, cv.noise2), "#FFFFFF", 0.85)
    shock_ring(cv, hit + np.array([n * 0.03, 0]), np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * 0.20, n * 0.07, n * 0.03, el, 0.9)
    hot_core(cv, hit[0], hit[1], el, 2.8, 1.2, star_len=20)
    for a in (210, 320, 90):   # stun stars circling the impact
        ar = math.radians(a)
        p = hit + np.array([math.cos(ar) * n * 0.13 - n * 0.06, math.sin(ar) * n * 0.07 - n * 0.20])
        pts = []
        for k in range(10):
            aa = math.radians(-90 + k * 36)
            rr = n * 0.045 * (1.0 if k % 2 == 0 else 0.42)
            pts.append((p[0] + math.cos(aa) * rr, p[1] + math.sin(aa) * rr))
        m = cv.poly(pts)
        glow(cv, m, "#FFC43A", 3, 0.6)
        material(cv, m, "gold", R=n * 0.012, lw=(0.25, 1.1), brk=0.2)


@skill("unspecialized.anti_tank_missile", tone="blast")
def anti_tank(cv, rng, el):
    n = cv.n
    blast_c = np.array([n * 0.80, n * 0.22])
    ground(cv, el, [], focus=blast_c, focus_r=0.45, focus_k=0.8, wash=-40, rng=rng)
    mz = np.array([n * 0.36, n * 0.66])
    d = (blast_c - mz) / np.linalg.norm(blast_c - mz)
    nv = np.array([-d[1], d[0]])
    burst(cv, rng, blast_c, n * 0.20, el, 1.0, smoke_k=0.8)
    for i, t in enumerate((0.26, 0.50, 0.74)):
        p = mz + (blast_c - mz) * t + nv * n * (0.04 if i == 1 else -0.02)
        smoke(cv, rng, [p - d * n * 0.16, p - d * n * 0.06], n * 0.03, "#5A4A3E", 0.45)
        trail(cv, [p - d * n * 0.15, p - d * n * 0.04], 0.4, n * 0.025, el, 0.8)
        H = weapon_H(p - d * n * 0.05, p + d * n * 0.06, 1.1)
        shell = lpoly(cv, H, spline([(0.0, -0.22), (0.55, -0.24), (0.85, -0.16), (1.0, 0.0), (0.85, 0.16), (0.55, 0.24), (0.0, 0.22)], 4))
        solid(cv, H, shell, "darksteel", 0.12, lw=(0.3, 1.4), back=tone(el)[2], back_k=0.9)
        cv.paint(lpoly(cv, H, [(0.40, -0.25), (0.52, -0.25), (0.52, 0.25), (0.40, 0.25)]) * shell, "#B9944A", 0.9)
    flash = mz + d * n * 0.04
    flare_spikes(cv, flash[0], flash[1], [(math.degrees(math.atan2(d[1], d[0])) + a, s) for a, s in ((0, 1.0), (40, 0.5), (-40, 0.5))],
                 n * 0.02, n * 0.18, n * 0.03, el, 0.8)
    H = weapon_H(mz - d * n * 0.62 + nv * n * 0.03, mz, 1.9)
    umbrella_gatling(cv, H, "white")


@skill("unspecialized.sword_draw", tone="white")
def sword_draw(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.70, n * 0.52), focus_r=0.5, focus_k=0.6, ink="#05060A", wash=0, rng=rng)
    # iai arc: the lower half of a wide flat ellipse, sweeping left to right
    crescent(cv, (n * 0.44, n * 0.42), n * 0.44, n * 0.16, -6, 170, 12, 0.42, el, 1.0)
    # the released sword-qi: a thick crescent moon of red light flying right
    qc = np.array([n * 0.70, n * 0.56])
    outer = cv.ellipse(qc[0], qc[1], n * 0.16, n * 0.30)
    inner = cv.ellipse(qc[0] - n * 0.07, qc[1], n * 0.14, n * 0.28)
    moon = np.clip(outer - inner, 0, 1) * (cv.grid()[0] > qc[0] - n * 0.06)
    light_form(cv, moon, "red", 1.0, R=n * 0.03, glow_r=7, lw=(0.3, 1.8))
    for y in (0.36, 0.48, 0.62, 0.74):
        light_streak(cv, (n * 0.34, n * y), (n * 0.62, n * (y + 0.01)), n * 0.012, "red", 0.6)
    hot_core(cv, qc[0] + n * 0.15, qc[1], "red", 2.0, 0.9, star_len=14)
    hot_core(cv, n * 0.86, n * 0.42, el, 2.2, 1.0, star_len=16)


@skill("unspecialized.eagle_stamp", tone="gold")
def eagle_stamp(cv, rng, el):
    n = cv.n
    pal = tone(el)
    floor = cv.poly([(0, n * 0.72), (n, n * 0.70), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.80), focus_r=0.5, focus_k=0.8, wash=-90, rng=rng)
    impact = np.array([n * 0.50, n * 0.82])
    for x in (0.18, 0.30, 0.70, 0.84):
        light_streak(cv, (n * x, n * 0.02), (n * x, n * 0.46), n * 0.016, el, 0.5)
    # crater: flat glowing ring, radial cracks, debris thrown sideways
    shock_ring(cv, impact, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.42, n * 0.10, n * 0.04, el, 1.0)
    for a in (-170, -150, -30, -10, 20, 160):
        ar = math.radians(a)
        p1 = impact + np.array([math.cos(ar) * n * 0.40, math.sin(ar) * n * 0.10 + n * 0.02])
        crack = cv.poly(ribbon(spline([impact, (impact + p1) / 2 + np.array([0, n * 0.01]), p1], 4), [n * 0.012, n * 0.008, 0.4]))
        soft_light(cv, crack, el, 0.8, R=0.8, glow_r=3)
    for x, y, s, dx in ((0.12, 0.66, 0.05, -1), (0.88, 0.64, 0.055, 1), (0.22, 0.56, 0.035, -1), (0.80, 0.54, 0.04, 1)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-dx * 0.8, 0.6), trail=(dx, -0.4))
    # the talon: scaled leg of gold light from the top, three splayed front toes + a rear spur, ivory claws
    leg = cv.poly(ribbon(spline([(n * 0.60, n * -0.08), (n * 0.54, n * 0.18), (n * 0.50, n * 0.42)], 6), [n * 0.30, n * 0.24, n * 0.19]))
    toes, claws = [], []
    ank = np.array([n * 0.50, n * 0.44])
    for (tx, ty), w in (((0.16, 0.64), 0.12), ((0.44, 0.72), 0.13), ((0.74, 0.68), 0.12), ((0.78, 0.30), 0.09)):
        tip = np.array([n * tx, n * ty])
        mid = (ank + tip) / 2 + np.array([0, -n * 0.05])
        toes.append(cv.poly(ribbon(spline([ank, mid, tip], 6), [n * w, n * w * 0.9, n * w * 0.6])))
        toes.append(cv.ellipse(mid[0], mid[1], n * w * 0.5))   # knuckle pad
        dv = (tip - mid) / np.linalg.norm(tip - mid)
        claws.append(stroke(cv, [tip - dv * n * 0.02, tip + dv * n * 0.07 + np.array([0, n * 0.03]), tip + np.array([dv[0] * n * 0.06, n * 0.12])],
                            n * 0.075, 0.5))
    feet = union(cv, [leg] + toes)
    light_form(cv, feet, el, 1.0, R=n * 0.05, glow_r=6, lw=(0.35, 2.2))
    for i in range(6):   # scutes across the leg
        y = n * (0.04 + i * 0.065)
        xc = n * (0.58 - i * 0.014)
        cv.paint(stroke(cv, [(xc - n * 0.10, y), (xc, y + n * 0.035), (xc + n * 0.10, y)], n * 0.014, n * 0.014) * feet, mix(pal[0], pal[1], 0.5), 0.7)
    for i in range(7):   # feather fringe where the leg leaves the frame
        x = n * (0.36 + i * 0.07)
        f = stroke(cv, [(x, n * -0.04), (x + n * 0.012 * (i - 3), n * 0.08), (x + n * 0.03 * (i - 3), n * 0.17)], n * 0.07, 0.5)
        light_form(cv, f, el, 0.9, R=n * 0.015, glow_r=2, lw=(0.25, 1.4), value=0.8)
    for cm in claws:
        material(cv, cm, "bone", R=n * 0.012, lw=(0.25, 1.2))
    hot_core(cv, impact[0], impact[1] - n * 0.04, el, 2.6, 1.1, star_len=22)


@skill("unspecialized.shield_attack", tone="white")
def shield_attack(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.80, n * 0.50), focus_r=0.45, focus_k=0.7, wash=0, rng=rng)
    for k, (r, w) in enumerate(((0.30, 0.03), (0.40, 0.018))):
        shock_ring(cv, np.array([n * 0.70, n * 0.50]), np.array([0.0, 1.0]), np.array([1.0, 0.0]), n * r * 1.4, n * r * 0.6, n * w, "gold",
                   0.8 - k * 0.3, -90, 90)
    H = H_quad([(-1, -1), (1, -1), (1, 1), (-1, 1)],
               [(n * 0.10, n * 0.12), (n * 0.66, n * 0.04), (n * 0.68, n * 0.96), (n * 0.08, n * 0.86)])
    hub = xf(H, [(0.0, 0.0)])[0]
    # the khaki shaft behind the canopy, running out to the lower left: it reads as an umbrella, not a disc
    sh = weapon_H(hub + np.array([-n * 0.42, n * 0.40]), hub, 1.0)
    shaft = lpoly(cv, sh, [(0.0, -0.035), (1.0, -0.03), (1.0, 0.03), (0.0, 0.035)])
    solid(cv, sh, shaft, "khaki", 0.03, lw=(0.4, 1.8))
    umbrella_open(cv, H, el, rot=8)
    hot_core(cv, n * 0.74, n * 0.50, "gold", 2.4, 1.0, star_len=18)
    for a in (-60, 30, 120):   # dizzy stars thrown off the bash
        ar = math.radians(a)
        p = (n * 0.84 + math.cos(ar) * n * 0.08, n * 0.50 + math.sin(ar) * n * 0.16)
        pts = []
        for k in range(10):
            aa = math.radians(-90 + k * 36)
            rr = n * 0.04 * (1.0 if k % 2 == 0 else 0.42)
            pts.append((p[0] + math.cos(aa) * rr, p[1] + math.sin(aa) * rr))
        m = cv.poly(pts)
        glow(cv, m, "#FFC43A", 3, 0.6)
        material(cv, m, "gold", R=n * 0.012, lw=(0.25, 1.1), brk=0.2)


@skill("unspecialized.myriad_combo", tone="red")
def myriad_combo(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.48, n * 0.52])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.7, ink="#060508", wash=-45, rng=rng)
    crescent(cv, c, n * 0.44, n * 0.40, 0, 120, 430, 0.16, el, 0.9)
    # blade form (lower-left), gun form (lower-right), lance form (upper-right) radiating from the hub
    sword(cv, weapon_H(c + np.array([n * 0.04, -n * 0.04]), c + np.array([-n * 0.42, n * 0.38]), 1.0), "white", blade="curved",
          curve=0.05, width=0.05, blade_from=0.30, guard="tsuba", grip_mat="khaki", guard_mat="gold")
    umbrella_gatling(cv, weapon_H(c + np.array([-n * 0.18, -n * 0.10]), c + np.array([n * 0.44, n * 0.30]), 1.0), "white")
    umbrella_folded(cv, weapon_H(c + np.array([-n * 0.10, n * 0.10]), c + np.array([n * 0.44, -n * 0.46]), 1.3), "white")
    hub = H_affine(c, -20, n * 0.20, n * 0.16)
    umbrella_open(cv, hub, "white", rot=10, seam_k=0.9)
    hot_core(cv, c[0], c[1], el, 2.2, 0.9, star_len=16)

    def bleed(c2):
        m = c2.ellipse(c[0], c[1], n * 0.20, n * 0.16)
        c2.add(np.clip(m - toward(m, 1.6, LIGHT), 0, 1), KEY["cool"], 0.9)   # the bar's one off-key accent
    return {"bleed": bleed}
