"""气功师 Qi Master (fingerless navy gloves, 念气 light). Cool-keyed bar: qi blue, jade and sky on a deep navy ground,
silver metal. Qi is painted as light with solid cores (light_form) next to one painted mass per icon. The bar's one
off-key accent is warm gold, on the ultimate's rim.

Value plan:
  palm           an open gloved palm thrust at the viewer, a qi sphere bursting off its centre: hand mass  [gloves]
  countercurrent a twisting geyser of jade qi erupting from a ground ring up the middle: column
  qi_bullet      one heavy swirling orb high right, a broad comet tail down to the lower left: ball + tail
  dragon_wave    a jade qi dragon surging right on a flat S, head leading: horizontal S
  cloud_grasp    a giant clawed hand of light closing at the upper right, tethers streaming back: claw
  nen_guard      a faceted half-dome barrier over a ground ring, impacts rippling on it: dome
  rainbow        a broad three-band arc of qi vaulting from lower left over the frame, a comet head: arch
  qi_blast       a central detonation of qi, forked bolts and a spiral of wind radiating: radial burst
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403
from comps._lib_gunfight import palm


def _swirl(cv, c, r, turns, count, el, k=1.0, w=0.02, ry=None):
    """spiral strokes of qi light winding into the centre"""
    n = cv.n
    ry = r if ry is None else ry
    for i in range(count):
        a0 = i * 2 * math.pi / count
        pts = [np.array(c) + np.array([math.cos(a0 + t * turns * 2 * math.pi) * r * (1 - 0.8 * t),
                                       math.sin(a0 + t * turns * 2 * math.pi) * ry * (1 - 0.8 * t)]) for t in np.linspace(0, 1, 14)]
        m = cv.poly(ribbon(spline(pts, 6), lambda q: n * w * math.sin(math.pi * min(1.0, q * 1.3)) ** 0.8 + 0.3))
        soft_light(cv, m, el, k, R=max(0.8, n * w * 0.4), glow_r=3, core_k=0.7)


def _bolt(cv, rng, p0, ang, length, el, w, k=1.0, forks=2):
    n = cv.n
    pts = [np.array(p0, float)]
    a = math.radians(ang)
    for j in range(6):
        a += rng.uniform(-0.5, 0.5)
        pts.append(pts[-1] + np.array([math.cos(a), math.sin(a)]) * length / 6)
    m = cv.poly(ribbon(np.array(pts), np.linspace(w, w * 0.2, len(pts))))
    soft_light(cv, m, el, k, R=max(0.6, w * 0.4), glow_r=3)
    for f in range(forks):
        i = int(rng.integers(2, 5))
        fa = ang + rng.choice([-1, 1]) * rng.uniform(25, 50)
        _bolt(cv, rng, pts[i], fa, length * 0.4, el, w * 0.6, k * 0.8, 0)


@skill("qi_master.palm", tone="qi")
def qi_palm(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.52, n * 0.42), focus_r=0.55, focus_k=0.8, wash=-35, rng=rng)
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.42), (-0.55, 0.42)]
    dst = [(n * 0.10, n * 0.02), (n * 0.88, n * 0.00), (n * 0.80, n * 1.04), (n * 0.12, n * 0.98)]
    H = H_quad(src, dst)
    pc = xf(H, [(0.0, -0.28)])[0]
    for r, k in ((0.46, 0.5), (0.36, 0.7)):
        shock_ring(cv, pc, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.9, n * 0.025, el, k)
    palm(cv, H, el, mat="navy", palm_mat="gf_skin")
    orb = cv.ellipse(pc[0], pc[1], n * 0.13)
    soft_light(cv, orb, el, 1.1, R=n * 0.08, glow_r=10, core_k=1.2)
    _swirl(cv, pc, n * 0.20, 0.6, 5, "sky", 0.8, w=0.016)
    hot_core(cv, pc[0], pc[1], el, 3.0, 1.1, star_len=18)


@skill("qi_master.countercurrent", tone="jade")
def countercurrent(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.40), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    base = np.array([n * 0.50, n * 0.86])
    shock_ring(cv, base, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.36, n * 0.08, n * 0.03, el, 0.9)
    for x, y, s in ((0.20, 0.74, 0.04), (0.82, 0.72, 0.045), (0.30, 0.60, 0.03), (0.70, 0.56, 0.03)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(0.5 - x, 0.5), trail=(x - 0.5, -1.0))
    col_m = cv.poly([(n * 0.38, n * 0.86), (n * 0.62, n * 0.86), (n * 0.66, n * 0.06), (n * 0.34, n * 0.06)])
    soft_light(cv, blur(col_m, 4), el, 0.5, R=n * 0.06, glow_r=10, core_k=0.3)
    wisps = []
    for i in range(7):   # turbulent tongues of qi rising, each its own phase and width, widening toward the top
        ph = rng.uniform(0, 2 * math.pi)
        x0 = n * 0.50 + (i - 3) * n * 0.025
        amp = n * rng.uniform(0.03, 0.06)
        top = n * rng.uniform(0.04, 0.22)
        pts = [(x0 + (x0 - n * 0.50) * t * 2.2 + math.sin(ph + t * rng.uniform(4, 7)) * amp * t, n * 0.86 - (n * 0.86 - top) * t)
               for t in np.linspace(0, 1, 16)]
        w0 = n * rng.uniform(0.05, 0.08)
        wisps.append(cv.poly(ribbon(spline(pts, 6), lambda q, w0=w0: w0 * (1 - q) ** 0.6 * (0.6 + 0.4 * math.sin(math.pi * min(1, q * 2))) + 0.4)))
    wm = union(cv, wisps)
    soft_light(cv, wm, el, 0.9, R=n * 0.03, glow_r=6, core_k=0.6, field=0.5 + 0.5 * streak_field(cv.w, -90, 50, 4, cv.seed()))
    for a in (-140, -118, -100, -80, -62, -40):   # the crown: spray flung up and out of the top
        ar = math.radians(a + rng.uniform(-5, 5))
        dv = np.array([math.cos(ar), math.sin(ar)])
        p0 = np.array([n * 0.50, n * 0.22]) + dv * n * 0.04
        light_streak(cv, p0, p0 + dv * n * rng.uniform(0.14, 0.22), n * 0.022, "sky", 0.8)
    for i in range(10):
        p = np.array([n * rng.uniform(0.24, 0.76), n * rng.uniform(0.04, 0.30)])
        hot_core_cross(cv, p[0], p[1], n * rng.uniform(0.012, 0.025), tone("sky")[2], 0.7)
    hot_core(cv, n * 0.50, n * 0.14, el, 2.6, 1.0, star_len=20)


@skill("qi_master.qi_bullet", tone="qi")
def qi_bullet(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.62, n * 0.40])
    ground(cv, el, [], focus=c, focus_r=0.5, focus_k=0.8, wash=-35, rng=rng)
    d = np.array([0.80, -0.60])
    trail(cv, [c - d * n * 0.80, c - d * n * 0.45, c - d * n * 0.12], 1.0, n * 0.26, el, 0.8, core_k=0.5)
    for o in (-0.12, 0.12):
        nv = np.array([-d[1], d[0]])
        light_streak(cv, c - d * n * 0.70 + nv * n * o * 1.6, c - d * n * 0.20 + nv * n * o, n * 0.014, "sky", 0.6)
    orb = cv.ellipse(c[0], c[1], n * 0.22)
    light_form(cv, orb, el, 1.0, R=n * 0.10, glow_r=10, lw=(0.3, 2.0))
    _swirl(cv, c, n * 0.20, 0.9, 4, "sky", 0.9, w=0.024)
    shock_ring(cv, c + d * n * 0.04, -np.array([-d[1], d[0]]), d, n * 0.28, n * 0.10, n * 0.02, el, 0.7, -80, 80)
    hot_core(cv, c[0] - n * 0.04, c[1] - n * 0.04, el, 3.0, 1.1, star_len=18)


@skill("qi_master.dragon_wave", tone="jade")
def dragon_wave(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.30), (n, n * 0.22), (n, n * 0.74), (0, n * 0.82)])
    ground(cv, el, [(band, 1)], focus=(n * 0.72, n * 0.40), focus_r=0.5, focus_k=0.7, wash=0, rng=rng)
    dragon_body(cv, [(n * 0.50, n * 0.44), (n * 0.34, n * 0.60), (n * 0.18, n * 0.44), (n * 0.02, n * 0.56), (n * -0.14, n * 0.74)],
                [n * 0.15, n * 0.14, n * 0.10, n * 0.06, n * 0.03], el, k=0.95, solid_to=0.55, streaks=5, spread=1.8)
    dragon_head(cv, H_affine((n * 0.52, n * 0.38), 2, n * 0.34), el, k=1.0)
    for (a, b, w) in (((0.0, 0.14), (0.40, 0.16), 0.012), ((0.10, 0.90), (0.62, 0.86), 0.016)):
        light_streak(cv, (n * a[0], n * a[1]), (n * b[0], n * b[1]), n * w, "sky", 0.7)


@skill("qi_master.cloud_grasp", tone="sky")
def cloud_grasp(cv, rng, el):
    """捉云手: a giant clawed hand of qi closing high on the left, far from the caster; tethers of qi stream back from
    it to the lower right, dragging the catch in"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.38, n * 0.34), focus_r=0.55, focus_k=0.6, wash=-140, rng=rng)
    for i, o in enumerate((-0.10, 0.0, 0.10)):
        pts = [(n * (0.40 - o), n * (0.56 + o * 0.5)), (n * (0.62 - o * 1.5), n * (0.74 + o)), (n * (0.92 - o * 2), n * (1.0 + o * 0.5))]
        m = cv.poly(ribbon(spline(pts, 8), lambda q: n * (0.045 - 0.035 * q) + 0.3))
        soft_light(cv, m, "qi", 0.8, R=n * 0.01, glow_r=4, core_k=0.6)
    for i in range(6):
        p = np.array([n * rng.uniform(0.40, 0.85), n * rng.uniform(0.60, 0.95)])
        light_streak(cv, p, p + np.array([n * 0.10, n * 0.08]), n * 0.012, "qi", 0.6)
    _swirl(cv, (n * 0.38, n * 0.34), n * 0.36, 0.5, 5, "qi", 0.5, w=0.014, ry=n * 0.30)
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.42), (-0.55, 0.42)]
    dst = [(n * -0.02, n * 0.06), (n * 0.64, n * -0.06), (n * 0.70, n * 0.64), (n * 0.14, n * 0.80)]
    H = H_quad(src, dst)
    palm(cv, H, el, curl=0.85, light=True, k=1.0)
    pc = xf(H, [(0.0, -0.26)])[0]
    hot_core(cv, pc[0], pc[1], el, 2.6, 1.0, star_len=16)


@skill("qi_master.nen_guard", tone="sky")
def nen_guard(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.78), (n, n * 0.76), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.40, n * 0.40), focus_r=0.6, focus_k=0.5, wash=-60, rng=rng)
    c = np.array([n * 0.50, n * 0.82])
    R = n * 0.44
    dome = cv.poly(np.r_[arc_pts(c[0], c[1], R, 180, 360, 64, ry=R * 1.40), arc_pts(c[0], c[1], R, 0, 180, 32, ry=R * 0.22)])
    cv.paint(blur(dome, 2), mix(tone(el)[0], KEY["ink"], 0.4), 0.6)
    glow(cv, dome, tone(el)[1], 10, 0.3)
    # hex facets across the dome: a projected lattice, brighter toward the lit top left
    X, Y = cv.grid()
    lat = np.zeros_like(dome)
    for j in range(-4, 5):
        for i in range(-6, 7):
            hx = c[0] + (i + (j % 2) * 0.5) * R * 0.30
            hy = c[1] - R * 1.4 + (j + 4) * R * 0.25
            hexp = [(hx + math.cos(math.radians(30 + 60 * k)) * R * 0.15, hy + math.sin(math.radians(30 + 60 * k)) * R * 0.13) for k in range(6)]
            np.maximum(lat, cv.poly(ribbon(np.array(hexp + [hexp[0]]), [R * 0.012] * 7)), out=lat)
    lat = lat * dome
    soft_light(cv, lat * (0.35 + 0.65 * smoothstep(n * 0.9, n * 0.2, X + Y * 0.6)), el, 0.7, R=0.6, glow_r=2, core_k=0.6)
    rim = np.clip(dome - toward(dome, 3.0, -LIGHT), 0, 1)
    soft_light(cv, rim, el, 0.9, R=n * 0.01, glow_r=4)
    shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), R, R * 0.22, n * 0.03, el, 0.9)
    for (x, y, s) in ((0.30, 0.38, 1.0), (0.70, 0.46, 0.8), (0.52, 0.22, 0.7)):   # impacts absorbed, rippling out on the skin
        p = np.array([n * x, n * y])
        for r in (0.05, 0.09):
            shock_ring(cv, p, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r * s, n * r * s * 0.7, n * 0.01, "qi", 0.7)
        hot_core(cv, p[0], p[1], "qi", 1.4 * s, 0.8, star_len=10)
    hot_core(cv, n * 0.30, n * 0.38, el, 2.6, 0.8, star_len=16)


@skill("qi_master.rainbow", tone="qi")
def rainbow(cv, rng, el):
    """气贯长虹: the dash as one long arching beam of qi (a 长虹) vaulting from the lower left over to the right, jade
    and sky bands streaming inside it, a white-hot spear head punching through and scattering debris"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.80, n * 0.60), focus_r=0.5, focus_k=0.7, wash=-30, rng=rng)
    c = np.array([n * 0.46, n * 0.90])
    crescent(cv, c, n * 0.42, n * 0.66, 0, 190, 342, 0.26, el, 1.1)
    crescent(cv, c + np.array([0, n * 0.03]), n * 0.37, n * 0.60, 0, 200, 338, 0.16, "jade", 0.8, rim=False)
    crescent(cv, c + np.array([0, n * 0.06]), n * 0.32, n * 0.54, 0, 210, 334, 0.12, "sky", 0.6, rim=False)
    head = c + np.array([math.cos(math.radians(342)) * n * 0.42, math.sin(math.radians(342)) * n * 0.66])
    d = np.array([0.55, 0.83])
    nv = np.array([-d[1], d[0]])
    tip = cv.poly([head - d * n * 0.12 + nv * n * 0.08, head + d * n * 0.12, head - d * n * 0.12 - nv * n * 0.08, head - d * n * 0.06])
    light_form(cv, tip, el, 1.0, R=n * 0.03, glow_r=6, lw=(0.3, 1.6))
    shock_ring(cv, head + d * n * 0.06, nv, d, n * 0.16, n * 0.05, n * 0.025, el, 0.9)
    for i in range(7):   # enemies' debris blown aside at the head
        a = math.radians(rng.uniform(-40, 140))
        p = head + np.array([math.cos(a), math.sin(a)]) * n * rng.uniform(0.12, 0.22)
        stone_chip(cv, rng, p[0], p[1], n * rng.uniform(0.02, 0.04), rng.uniform(0, 360), el, hot_dir=(-math.cos(a), -math.sin(a)),
                   trail=(math.cos(a), math.sin(a)))
    hot_core(cv, head[0], head[1], el, 3.0, 1.1, star_len=22)


@skill("qi_master.qi_blast", tone="qi")
def qi_blast(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.74), (n, n * 0.72), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.50, n * 0.52), focus_r=0.6, focus_k=0.9, ink="#03050A", wash=-60, rng=rng)
    c = np.array([n * 0.50, n * 0.54])
    shock_ring(cv, c + np.array([0, n * 0.22]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.46, n * 0.12, n * 0.035, el, 0.9)
    _swirl(cv, c, n * 0.44, 0.55, 6, "jade", 0.8, w=0.03, ry=n * 0.40)
    for i in range(7):
        a = -90 + (i - 3) * 48 + rng.uniform(-10, 10)
        _bolt(cv, rng, c + np.array([math.cos(math.radians(a)), math.sin(math.radians(a))]) * n * 0.12, a, n * 0.40, "sky", n * 0.022, 0.9)
    core = cv.ellipse(c[0], c[1], n * 0.17)
    burst(cv, rng, c, n * 0.16, "sky", 0.7, smoke_k=0.0, puffs=7, core=False)
    soft_light(cv, core, el, 1.2, R=n * 0.12, glow_r=12, core_k=1.3)
    hot_core(cv, c[0], c[1], el, 3.4, 1.2, star_len=26)

    def bleed(c2):
        ring = np.clip(c2.ellipse(c[0], c[1], n * 0.215) - c2.ellipse(c[0], c[1], n * 0.19), 0, 1)
        ring = ring * (0.4 + 0.6 * smoothstep(0.0, 1.0, (c2.grid()[0] - c[0] + c2.grid()[1] - c[1]) / (n * 0.3) + 0.5))
        c2.add(blur(ring, 0.6), KEY["cool"], 1.0)   # the bar's one off-key accent: a warm gold rim on the detonation
        c2.add(blur(ring, 3.0), KEY["cool"], 0.5)
    return {"bleed": bleed}
