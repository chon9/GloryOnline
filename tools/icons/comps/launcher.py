"""枪炮师 Launcher (沐雨橙风 / 吞日). Warm-keyed bar: blast orange, brass, energy yellow and smoke.
The bar's one off-key accent is ice-cyan, on the ultimate's satellite beams.

Value plan:
  cannon_1               the cannon foreshortened straight at the viewer: one big muzzle ring + blast  [cannon]
  swing                  the cannon swung up on a steep diagonal, a smear rising behind it            [cannon]
  anti_tank_missile      three shells flying right in a staggered row, smoke trails, stun stars
  laser_rifle            cannon low-left firing one thick beam up across the frame, recoil smoke       [cannon]
  stinger                a shell bursting high, eight stingers raining down in a fan onto a target ring
  gatling_gun            six-barrel cluster end-on at the left, a cone of tracers spraying right       [cannon form]
  heat_seeking_missile   a missile on a looping trail homing into a lock-on reticle
  satellite_beam         six beams of light dropping from the sky in a ring onto the ground, cyan rims
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403


def _persp(near_c, far_c, near_hw, far_hw):
    """cannon local frame (x 0 = butt far, 1 = muzzle near; y in +-0.14) -> a foreshortened quad"""
    b, t = np.array(far_c, float), np.array(near_c, float)
    d = (t - b) / np.linalg.norm(t - b)
    nv = np.array([-d[1], d[0]])
    src = [(0, -0.14), (1, -0.14), (1, 0.14), (0, 0.14)]
    dst = [b - nv * far_hw, t - nv * near_hw, t + nv * near_hw, b + nv * far_hw]
    return H_quad(src, dst)


def _shell(cv, H, el, k=1.0):
    m = lpoly(cv, H, spline([(0.0, -0.22), (0.55, -0.24), (0.85, -0.16), (1.0, 0.0), (0.85, 0.16), (0.55, 0.24), (0.0, 0.22)], 4))
    solid(cv, H, m, "darksteel", 0.12, lw=(0.3, 1.4), back=tone(el)[2], back_k=0.9 * k)
    cv.paint(lpoly(cv, H, [(0.40, -0.25), (0.52, -0.25), (0.52, 0.25), (0.40, 0.25)]) * m, "#B9944A", 0.9)
    tip = lpoly(cv, H, [(0.80, -0.17), (1.0, 0.0), (0.80, 0.17)]) * m
    cv.paint(tip, "#C8202A", 0.8)
    return m


def _star(cv, x, y, s):
    pts = []
    for k in range(10):
        a = math.radians(-90 + k * 36)
        r = s * (1.0 if k % 2 == 0 else 0.42)
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    m = cv.poly(pts)
    glow(cv, m, "#FFC43A", 3, 0.6)
    material(cv, m, "gold", R=s * 0.3, lw=(0.25, 1.1), brk=0.2)


@skill("launcher.cannon_1", tone="blast")
def cannon_shot(cv, rng, el):
    """3/4 view down the barrel: the cannon comes at the viewer from the lower left, its muzzle face a big brass
    ring with a glowing bore, the blast and the shell bursting out of it"""
    n = cv.n
    ground(cv, el, [], focus=(n * 0.62, n * 0.40), focus_r=0.5, focus_k=0.8, wash=-35, rng=rng)
    near, far = np.array([n * 0.56, n * 0.46]), np.array([n * 0.02, n * 1.02])
    H = _persp(near, far, n * 0.25, n * 0.13)
    hand_cannon(cv, H, el, cable=False)
    d = (near - far) / np.linalg.norm(near - far)
    ang = math.degrees(math.atan2(d[1], d[0]))
    # muzzle face: an ellipse perpendicular to the axis (minor axis along it)
    Hm = H_affine(near, ang, n * 0.10, n * 0.27)
    t = np.linspace(0, 2 * math.pi, 48)
    face = cv.poly(xf(Hm, np.c_[np.cos(t), np.sin(t)]))
    material(cv, face, "brass", R=n * 0.04, lw=(0.4, 2.2), back=tone(el)[2], back_k=0.8)
    bore = cv.poly(xf(H_affine(near + d * n * 0.01, ang, n * 0.07, n * 0.18), np.c_[np.cos(t), np.sin(t)]))
    cv.paint(bore, "#120804")
    cv.add(blur(bore, 3) * bore, tone(el)[2], 1.0)
    burst(cv, rng, near + d * n * 0.16, n * 0.18, el, 1.0, smoke_k=0.0, puffs=8)
    shock_ring(cv, near + d * n * 0.10, -np.array([-d[1], d[0]]), d, n * 0.36, n * 0.12, n * 0.03, el, 0.8)
    sh = cv.ellipse(*(near + d * n * 0.30), n * 0.075)
    material(cv, sh, "darksteel", R=n * 0.05, lw=(0.4, 2.0), back=tone(el)[2], back_k=1.0)
    hot_core(cv, *(near + d * n * 0.08), el, 2.6, 1.1, star_len=20)


@skill("launcher.swing", tone="brass")
def swing(cv, rng, el):
    n = cv.n
    low = cv.poly([(0, n * 0.86), (n, n * 0.80), (n, n), (0, n)])
    ground(cv, el, [(low, 1)], focus=(n * 0.72, n * 0.20), focus_r=0.5, focus_k=0.7, wash=-60, rng=rng)
    crescent(cv, (n * 0.30, n * 0.70), n * 0.62, n * 0.62, 0, 70, -42, 0.30, el, 1.0)
    hand_cannon(cv, weapon_H((n * 0.06, n * 0.90), (n * 0.62, n * 0.10), 0.85), "blast", cable=False)
    for x, y, s, a in ((0.82, 0.30, 0.06, 0), (0.88, 0.52, 0.045, 0), (0.72, 0.12, 0.04, 0)):
        stone_chip(cv, rng, n * x, n * y, n * s, rng.uniform(0, 360), el, hot_dir=(-0.8, 0.6), trail=(0.3, -1.0))
    for x, y0, y1 in ((0.78, 0.86, 0.50), (0.90, 0.78, 0.60)):
        light_streak(cv, (n * x, n * y0), (n * x, n * y1), n * 0.016, el, 0.7)
    hot_core(cv, n * 0.66, n * 0.10, el, 2.4, 1.0, star_len=18)


@skill("launcher.anti_tank_missile", tone="blast")
def anti_tank(cv, rng, el):
    n = cv.n
    band = cv.poly([(0, n * 0.28), (n, n * 0.24), (n, n * 0.76), (0, n * 0.72)])
    ground(cv, el, [(band, 1)], focus=(n * 0.92, n * 0.50), focus_r=0.4, focus_k=0.7, wash=0, rng=rng)
    for i, (x, y) in enumerate(((0.30, 0.30), (0.52, 0.52), (0.74, 0.74))):
        p = np.array([n * x, n * y])
        d = np.array([1.0, -0.05])
        smoke(cv, rng, [p - np.array([n * 0.44, -n * 0.01]), p - np.array([n * 0.22, 0]), p - np.array([n * 0.10, 0])], n * 0.05, "#4A3A2E", 0.6)
        trail(cv, [p - np.array([n * 0.30, 0]), p - np.array([n * 0.06, 0])], 0.4, n * 0.035, el, 0.9)
        _shell(cv, weapon_H(p - np.array([n * 0.07, 0]), p + np.array([n * 0.11, -n * 0.005]), 1.0), el)
    burst(cv, rng, (n * 0.96, n * 0.36), n * 0.14, el, 0.9, smoke_k=0.6, puffs=6)
    for x, y, s in ((0.86, 0.14, 0.05), (0.66, 0.16, 0.04), (0.92, 0.62, 0.035)):
        _star(cv, n * x, n * y, n * s)


@skill("launcher.laser_rifle", tone="energy")
def laser(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.70, n * 0.30), focus_r=0.55, focus_k=0.6, ink="#060504", wash=-38, rng=rng)
    mz = np.array([n * 0.50, n * 0.58])
    end = np.array([n * 1.10, n * 0.06])
    d = (end - mz) / np.linalg.norm(end - mz)
    nv = np.array([-d[1], d[0]])
    smoke(cv, rng, [mz - d * n * 0.30 + nv * n * 0.10, mz - d * n * 0.45 + nv * n * 0.20, mz - d * n * 0.55 + nv * n * 0.32], n * 0.08,
          "#4A3E30", 0.7)
    beam = cv.poly([mz + nv * n * 0.07, end + nv * n * 0.16, end - nv * n * 0.16, mz - nv * n * 0.07])
    glow(cv, beam, tone(el)[1], 14, 0.9)
    soft_light(cv, beam, el, 1.2, R=n * 0.05, glow_r=8, core_k=1.4)
    for o in (-0.07, 0.07):   # spiralling energy filaments along the beam
        pts = [mz + d * n * t + nv * n * (o * t * 1.2 + 0.03 * math.sin(t * 22)) for t in np.linspace(0.05, 1.0, 30)]
        light_streak(cv, pts[0], pts[-1], n * 0.01, el, 0.5)
    hand_cannon(cv, weapon_H(mz - d * n * 0.80, mz, 1.0), "blast", cable=True, chamber_k=1.3)
    for a_ in (-30, 30):   # recoil blast flaring sideways out of the muzzle
        ar = math.radians(math.degrees(math.atan2(d[1], d[0])) + 180 + a_)
        light_streak(cv, mz, mz + np.array([math.cos(ar), math.sin(ar)]) * n * 0.18, n * 0.03, "blast", 0.7)
    hot_core(cv, mz[0] + d[0] * n * 0.02, mz[1] + d[1] * n * 0.02, el, 3.0, 1.3, star_len=22, ang=math.degrees(math.atan2(d[1], d[0])))


@skill("launcher.stinger", tone="blast")
def stinger(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.80), (n, n * 0.78), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.18), focus_r=0.4, focus_k=0.7, wash=-90, rng=rng)
    top = np.array([n * 0.50, n * 0.16])
    burst(cv, rng, top, n * 0.11, el, 0.9, smoke_k=0.7, puffs=6)
    tgt = np.array([n * 0.50, n * 0.88])
    shock_ring(cv, tgt, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.36, n * 0.07, n * 0.02, el, 0.7)
    for i in range(8):
        a = math.radians(55 + i * (70 / 7.0))
        d = np.array([math.cos(a), math.sin(a)])
        head = top + d * n * (0.52 + 0.14 * math.sin(i * 1.3))
        tail = top + d * n * 0.14
        trail(cv, [tail, (tail + head) / 2, head - d * n * 0.06], 0.4, n * 0.018, el, 0.7)
        H = weapon_H(head - d * n * 0.11, head, 1.0)
        dart = lpoly(cv, H, [(0.0, -0.06), (0.75, -0.08), (1.0, 0.0), (0.75, 0.08), (0.0, 0.06)])
        fins = lpoly(cv, H, [(0.0, -0.20), (0.22, -0.06), (0.22, 0.06), (0.0, 0.20)])
        solid(cv, H, fins, "brass", 0.05, lw=(0.25, 1.0))
        solid(cv, H, dart, "steel", 0.05, lw=(0.25, 1.1), back=tone(el)[2], back_k=0.8)
        hot_core(cv, head[0], head[1], el, 0.8, 0.5, star=False)


@skill("launcher.gatling_gun", tone="brass")
def gatling(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.26, n * 0.52])
    ground(cv, el, [], focus=(n * 0.62, n * 0.50), focus_r=0.55, focus_k=0.6, wash=0, rng=rng)
    for i in range(16):   # tracer cone
        a = math.radians(rng.uniform(-24, 24))
        d = np.array([math.cos(a), math.sin(a)])
        r0 = n * rng.uniform(0.22, 0.55)
        L = n * rng.uniform(0.10, 0.22)
        light_streak(cv, c + d * r0, c + d * (r0 + L), n * rng.uniform(0.010, 0.02), el, 0.9)
    for i in range(6):   # brass casings tumbling out below
        p = np.array([n * rng.uniform(0.20, 0.60), n * rng.uniform(0.78, 0.94)])
        H = H_affine(p, rng.uniform(0, 180), n * 0.06, n * 0.06)
        cs = cv.poly(xf(H, [(-0.5, -0.18), (0.5, -0.18), (0.5, 0.18), (-0.5, 0.18)]))
        material(cv, cs, "brass", R=n * 0.01, lw=(0.25, 1.0))
    # the barrel cluster end-on: a brass drum, six bores around a hub, a muzzle-flash ring
    drum = cv.ellipse(c[0], c[1], n * 0.22, n * 0.24)
    material(cv, drum, "brass", R=n * 0.08, lw=(0.45, 2.4), grad=0.5, back=tone(el)[2], back_k=0.6)
    cv.paint(np.clip(drum - cv.ellipse(c[0], c[1], n * 0.18, n * 0.20), 0, 1), "#2A1A08", 0.5)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        p = c + np.array([math.cos(a) * n * 0.12, math.sin(a) * n * 0.13])
        b = cv.ellipse(p[0], p[1], n * 0.05)
        material(cv, b, "darksteel", R=n * 0.02, lw=(0.3, 1.3))
        bore = cv.ellipse(p[0] + n * 0.004, p[1] + n * 0.004, n * 0.026)
        cv.paint(bore, "#050403")
        cv.add(blur(bore, 1.5), tone(el)[2], 0.6)
    hub = cv.ellipse(c[0], c[1], n * 0.045)
    material(cv, hub, "gold", R=n * 0.02, lw=(0.3, 1.2))
    flare_spikes(cv, c[0] + n * 0.20, c[1], [(-20, 0.7), (0, 1.0), (20, 0.7)], n * 0.02, n * 0.20, n * 0.04, el, 0.8)
    hot_core(cv, c[0] + n * 0.22, c[1], el, 2.4, 1.0, star_len=18)


@skill("launcher.heat_seeking_missile", tone="blast")
def heat_seeker(cv, rng, el):
    n = cv.n
    tgt = np.array([n * 0.74, n * 0.30])
    ground(cv, el, [], focus=tgt, focus_r=0.45, focus_k=0.7, wash=-30, rng=rng)
    # lock-on reticle
    for r, w, a0 in ((0.17, 0.02, 20), (0.11, 0.012, 65)):
        segs = [cv.poly(ribbon(arc_pts(tgt[0], tgt[1], n * r, a0 + k * 90, a0 + k * 90 + 60, 20), [n * w] * 20)) for k in range(4)]
        soft_light(cv, union(cv, segs), "energy", 0.9, R=n * 0.008, glow_r=3)
    for k in range(4):
        a = math.radians(45 + k * 90)
        d = np.array([math.cos(a), math.sin(a)])
        p0, p1 = tgt + d * n * 0.20, tgt + d * n * 0.27
        soft_light(cv, cv.poly(ribbon([p0, p1], [n * 0.02, n * 0.008])), "energy", 0.9, R=0.8, glow_r=2)
    # looping trail from the lower left, around, then in toward the reticle
    path = [(n * 0.04, n * 0.92), (n * 0.30, n * 0.80), (n * 0.48, n * 0.56), (n * 0.34, n * 0.42), (n * 0.22, n * 0.56),
            (n * 0.36, n * 0.70), (n * 0.56, n * 0.56)]
    sp = spline(path, 10)
    smoke(cv, rng, sp[:-6:4].tolist(), n * 0.03, "#4A3A2E", 0.55)
    trail(cv, sp[2:].tolist(), 0.5, n * 0.035, el, 0.9)
    head = sp[-1]
    d = (sp[-1] - sp[-4]) / np.linalg.norm(sp[-1] - sp[-4])
    H = weapon_H(head - d * n * 0.10, head + d * n * 0.10, 1.0)
    m = lpoly(cv, H, spline([(0.0, -0.10), (0.6, -0.12), (0.9, -0.08), (1.0, 0.0), (0.9, 0.08), (0.6, 0.12), (0.0, 0.10)], 4))
    fins = lpoly(cv, H, [(0.0, -0.28), (0.20, -0.10), (0.20, 0.10), (0.0, 0.28)])
    solid(cv, H, fins, "darksteel", 0.05, lw=(0.25, 1.1))
    solid(cv, H, m, "plate", 0.08, lw=(0.3, 1.4), back=tone(el)[2], back_k=0.8)
    cv.paint(lpoly(cv, H, [(0.70, -0.12), (1.0, 0.0), (0.70, 0.12)]) * m, "#E8A020", 0.8)
    hot_core(cv, head[0] - d[0] * n * 0.10, head[1] - d[1] * n * 0.10, el, 1.4, 0.9, star_len=10)
    hot_core(cv, tgt[0], tgt[1], "energy", 1.4, 0.8, star_len=12)


@skill("launcher.satellite_beam", tone="energy")
def satellite(cv, rng, el):
    n = cv.n
    floor = cv.poly([(0, n * 0.66), (n, n * 0.64), (n, n), (0, n)])
    ground(cv, el, [(floor, 1)], focus=(n * 0.5, n * 0.80), focus_r=0.55, focus_k=0.9, ink="#050403", wash=-90, rng=rng)
    gc = np.array([n * 0.50, n * 0.80])
    shock_ring(cv, gc, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.40, n * 0.11, n * 0.03, el, 0.9)
    beams = []
    for k in range(6):
        a = math.radians(k * 60 + 15)
        foot = gc + np.array([math.cos(a) * n * 0.34, math.sin(a) * n * 0.09])
        w = n * (0.030 + 0.016 * (math.sin(a) + 1) * 0.5)   # near beams wider
        top = np.array([foot[0] + (foot[0] - n * 0.5) * 0.25, -n * 0.05])
        m = cv.poly([top + np.array([-w * 0.6, 0]), top + np.array([w * 0.6, 0]), foot + np.array([w, 0]), foot - np.array([w, 0])])
        m = m * (0.25 + 0.75 * smoothstep(0.0, n * 0.75, cv.grid()[1]))   # light gathers toward the ground
        beams.append((math.sin(a), m, foot))
    for _, m, foot in sorted(beams, key=lambda b: b[0]):
        glow(cv, m, tone(el)[1], 6, 0.35)
        cv.add(blur(m, 1.0), tone(el)[1], 0.45)
        core_m = np.clip(blur(m, 0.5) * 2.2 - 1.2, 0, 1)
        cv.add(core_m, tone(el)[3], 0.7)
        hot_core(cv, foot[0], foot[1], el, 1.4, 0.8, star_len=12)
    burst(cv, rng, gc - np.array([0, n * 0.02]), n * 0.13, "blast", 0.9, smoke_k=0.5, puffs=7)

    def bleed(c2):
        for _, m, _f in beams:
            c2.add(np.clip(m - toward(m, 1.6, LIGHT), 0, 1), KEY["cool"], 0.9)   # the bar's one off-key accent
    return {"bleed": bleed}
