"""comps/_lib_night.py - reusable drawers for the grappler / brawler / assassin / ninja / thief bars.

  figure(cv, pelvis, s, torso_ang, arms, legs, el, ...)   a painted human body (gi / jacket cloth with form shading, a
                                                          belt, rim light of the skill tone): the thrown / grabbed foe.
                                                          Angles in degrees, screen space (0 = right, 90 = down).
  dizzy_stars(cv, c, rx, ry, count, size)                 gold 5-point stun stars on an orbit
  shuriken(cv, c, r, rot, el, points)                      bevelled dark-steel throwing star with a ring hole
  short_blade(cv, H, el, ...)                              a short straight sword / dagger: wrapped grip, small guard
  brick(cv, c, size, ang, el)                              a fired clay brick in 3/4 view, chipped corner
  cloud(cv, rng, c, r, ramp, puffs)                        a painted billowing cloud (4-value, lit top-left)
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403


def _dv(a):
    r = math.radians(a)
    return np.array([math.cos(r), math.sin(r)])


def _limb(cv, p0, a0, l0, a1, l1, w0, w1, w2):
    """two-segment limb from p0: returns (mask, joint, end)"""
    j = p0 + _dv(a0) * l0
    e = j + _dv(a1) * l1
    m = cv.poly(ribbon(spline([p0, (p0 + j) / 2, j, (j + e) / 2, e], 4), [w0, w0 * 0.92, w1, w1 * 0.92, w2]))
    np.maximum(m, cv.ellipse(j[0], j[1], w1 * 0.5), out=m)
    return m, j, e


def figure(cv, pelvis, s, torso_ang, arms, legs, el, cloth="navy", skin="ivory", belt="#E8ECF4", rim_k=0.9,
           value=1.0, far_dim=0.55, line_col="#04060E", face_side=1.0):
    """painted body in a loose gi / jacket. pelvis xy, s = body scale (pelvis->neck = 0.44 s). torso_ang: direction
    pelvis -> neck. arms / legs: ((upper_ang, lower_ang), (upper_ang, lower_ang)) for (near, far).
    face_side (+1 / -1) picks which side of the head the face is on. Returns (mask, parts dict)."""
    pal = tone(el)
    P = np.asarray(pelvis, float)
    d = _dv(torso_ang)
    nv = np.array([-d[1], d[0]]) * face_side
    neck = P + d * s * 0.44
    head_c = neck + d * s * 0.15
    sh = [neck - d * s * 0.04 + nv * s * 0.15, neck - d * s * 0.04 - nv * s * 0.15]
    hp = [P + nv * s * 0.08, P - nv * s * 0.08]
    torso = cv.poly(closed_spline([sh[0] + nv * s * 0.03, neck + d * s * 0.03, sh[1] - nv * s * 0.03,
                                   (sh[1] + hp[1]) / 2 - nv * s * 0.01, P - nv * s * 0.15 - d * s * 0.12,
                                   P - d * s * 0.16, P + nv * s * 0.15 - d * s * 0.12,
                                   (sh[0] + hp[0]) / 2 + nv * s * 0.01], 6))
    limbs = []
    for i in (1, 0):   # far side first
        la, lb = legs[i]
        lm, kn, ft = _limb(cv, hp[i], la, s * 0.35, lb, s * 0.33, s * 0.19, s * 0.155, s * 0.13)
        foot = cv.poly(ribbon([ft - _dv(lb) * s * 0.02, ft + _dv(lb) * s * 0.03 + _dv(lb + 75) * s * 0.09],
                              [s * 0.09, s * 0.06]))
        aa, ab = arms[i]
        am, el_, hd = _limb(cv, sh[i], aa, s * 0.25, ab, s * 0.21, s * 0.14, s * 0.13, s * 0.12)
        cuff = cv.poly(ribbon([hd - _dv(ab) * s * 0.035, hd], [s * 0.125, s * 0.125]))
        hand = cv.ellipse(*(hd + _dv(ab) * s * 0.045), s * 0.062)
        limbs.append((i, lm, foot, am, hand, cuff, (hp[i], kn, ft), (sh[i], el_, hd)))
    head = cv.ellipse(head_c[0], head_c[1], s * 0.12, s * 0.12)
    allm = union(cv, [torso, head] + [m for L in limbs for m in L[1:6]])
    ink_line(cv, allm, line_col, 0.35, max(1.3, s * 0.02), 0.4)
    ramp = [col(c) * value for c in MAT[cloth][0]]
    for i, lm, foot, am, hand, cuff, legj, armj in limbs:
        dim = far_dim if i == 1 else 1.0
        rr = [c * dim for c in ramp]
        if i == 0:
            paint_form(cv, torso, ramp, R=s * 0.07, grad=0.4)
            # gi lapels crossing to the belt
            lap = stroke(cv, [neck + nv * s * 0.10, P + d * s * 0.16, P - nv * s * 0.06], s * 0.05, s * 0.03) * torso
            paint_form(cv, lap, [mix(ramp[2], "#FFFFFF", 0.2), mix(ramp[3], "#FFFFFF", 0.35), mix(ramp[3], "#FFFFFF", 0.6)],
                       R=s * 0.015, grad=0.4)
            if belt:
                bm = cv.poly(ribbon([P + nv * s * 0.16 + d * s * 0.03, P - nv * s * 0.16 + d * s * 0.03], [s * 0.06, s * 0.06])) * torso
                paint_form(cv, bm, [mix(belt, "#000000", 0.6), mix(belt, "#000000", 0.3), belt], R=s * 0.02, grad=0.4)
                tail = stroke(cv, [P + nv * s * 0.05 + d * s * 0.02, P + nv * s * 0.10 - d * s * 0.14], s * 0.035, s * 0.02)
                paint_form(cv, tail, [mix(belt, "#000000", 0.6), mix(belt, "#000000", 0.3), belt], R=s * 0.01, grad=0.4)
        paint_form(cv, lm, rr, R=s * 0.06, grad=0.4)
        paint_form(cv, am, rr, R=s * 0.05, grad=0.4)
        # cloth folds: darker crease strokes across the knee and elbow
        for (a, j, e), m_ in ((legj, lm), (armj, am)):
            for t in (0.75, 0.15):
                q = j + (a - j) * t * 0.5 if t > 0.5 else j + (e - j) * t
                dd = (e - a) / (np.linalg.norm(e - a) + 1e-6)
                nn = np.array([-dd[1], dd[0]])
                cr = stroke(cv, [q - nn * s * 0.06, q + dd * s * 0.02, q + nn * s * 0.05], s * 0.018, s * 0.008) * m_
                cv.paint(cr, rr[0], 0.6)
        paint_form(cv, cuff, [c * 0.9 for c in rr[1:]], R=s * 0.02, grad=0.4)
        sk = [col(c) * value * dim for c in MAT[skin][0]]
        paint_form(cv, union(cv, [hand, foot]), sk, R=s * 0.025, grad=0.4)
        if i == 1:
            cv.paint(union(cv, [lm, am, foot, hand, cuff]) * (1 - torso), mix(KEY["ink"], pal[0], 0.5), 0.25)
    # head: dark hair over most of it, a pale face plane on the front side (no features at icon scale)
    paint_form(cv, head, [col(c) * value for c in ("#06060A", "#141420", "#2A2A3E", "#4A4A66")], R=s * 0.05, grad=0.5)
    fc = head_c + nv * s * 0.06 - d * s * 0.02
    face = head * cv.ellipse(fc[0], fc[1], s * 0.085, s * 0.085)
    paint_form(cv, face, [col(c) * value for c in MAT["bone"][0][:3]], R=s * 0.02, grad=0.5)
    if rim_k:
        b = allm * (1 - toward(allm, max(1.0, s * 0.022), LIGHT))
        cv.add(b, pal[2], rim_k)
    return allm, {"neck": neck, "head": head_c, "pelvis": P, "torso": torso}


def star5(cv, x, y, s, k=1.0):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = s * (1.0 if i % 2 == 0 else 0.42)
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    m = cv.poly(pts)
    glow(cv, m, "#FFC43A", 3, 0.6 * k)
    material(cv, m, "gold", R=s * 0.3, lw=(0.25, 1.1), brk=0.2)
    return m


def dizzy_stars(cv, c, rx, ry, angs, size):
    for a in angs:
        ar = math.radians(a)
        star5(cv, c[0] + math.cos(ar) * rx, c[1] + math.sin(ar) * ry, size * (0.8 + 0.2 * math.sin(ar)))


def shuriken(cv, c, r, rot, el, points=4, mat="darksteel", back_k=0.8, hole=True):
    """bevelled throwing star: points blades with a concave flank, each blade split into a lit and a dark facet"""
    pal = tone(el)
    c = np.asarray(c, float)
    outer, facets = [], []
    for i in range(points):
        a = math.radians(rot + i * 360.0 / points)
        b = math.radians(rot + (i + 0.5) * 360.0 / points)
        tip = c + np.array([math.cos(a), math.sin(a)]) * r
        valley = c + np.array([math.cos(b), math.sin(b)]) * r * 0.28
        outer += [tuple(tip), tuple(c + np.array([math.cos(b - 0.35), math.sin(b - 0.35)]) * r * 0.42), tuple(valley),
                  tuple(c + np.array([math.cos(b + 0.35), math.sin(b + 0.35)]) * r * 0.42)]
    m = cv.poly(outer)
    ink_line(cv, m, MAT[mat][1], 0.35, max(1.0, r * 0.06), 0.4)
    paint_form(cv, m, MAT[mat][0], R=max(1.0, r * 0.1), grad=0.4, spec=MAT[mat][2])
    for i in range(points):
        a = math.radians(rot + i * 360.0 / points)
        tip = c + np.array([math.cos(a), math.sin(a)]) * r
        side = c + np.array([math.cos(a + 0.9), math.sin(a + 0.9)]) * r * 0.3
        f = cv.poly([tuple(c), tuple(tip), tuple(side)]) * m
        lit = float(np.dot(np.array([math.cos(a + 0.45), math.sin(a + 0.45)]), LIGHT2))
        cv.paint(f, "#FFFFFF" if lit > 0 else "#000000", 0.18 + 0.12 * abs(lit))
        # honed edge
        e = cv.poly(ribbon([tip, c + (tip - c) * 0.35 + (side - c) * 0.6], [0.3, max(0.5, r * 0.04)])) * m
        cv.paint(e, "#E8EEF6", 0.6)
    cv.add(m * (1 - toward(m, max(0.8, r * 0.05), LIGHT)), pal[2], back_k)
    if hole:
        ring = np.clip(cv.ellipse(c[0], c[1], r * 0.16) - cv.ellipse(c[0], c[1], r * 0.08), 0, 1)
        material(cv, ring, "steel", R=r * 0.04, lw=(0.2, 0.8))
        cv.paint(cv.ellipse(c[0], c[1], r * 0.08), KEY["ink"])
    return m


def short_blade(cv, H, el, blade_mat="steel", width=0.06, blade_from=0.30, guard_mat="steel", grip_mat="leather",
                kind="dagger", line=True):
    """a short sword / dagger along local x (grip at 0). kind: dagger (leaf taper) | straight | tanto"""
    return sword(cv, H, el, blade={"dagger": "dagger", "straight": "straight", "tanto": "curved"}[kind],
                 guard="cross" if kind != "tanto" else "tsuba", blade_mat=blade_mat, width=width, blade_from=blade_from,
                 grip_mat=grip_mat, guard_mat=guard_mat, curve=0.02 if kind == "tanto" else 0.0, line=line)


def brick(cv, c, size, ang, el, k=1.0):
    """fired clay brick, 3/4 view: lit top face, mid long face, dark end face, chipped corner, mortar crust"""
    pal = tone(el)
    H = H_affine(c, ang, size)
    L, Wd, D = 0.5, 0.24, 0.16
    top = [(-L, -Wd), (L, -Wd), (L + 0.12, -Wd - 0.12), (-L + 0.12, -Wd - 0.12)]
    front = [(-L, -Wd), (L, -Wd), (L, Wd), (-L, Wd)]
    end = [(L, -Wd), (L + 0.12, -Wd - 0.12), (L + 0.12, Wd - 0.12), (L, Wd)]
    chip = cv.poly(xf(H, [(-L - 0.02, Wd * 0.2), (-L + 0.16, Wd + 0.02), (-L - 0.02, Wd + 0.02)]))
    mt, mf, me = (cv.poly(xf(H, p)) for p in (top, front, end))
    allm = np.clip(union(cv, [mt, mf, me]) - chip, 0, 1)
    ink_line(cv, allm, "#1A0A04", 0.4, 2.0, 0.4)
    clay = ["#2A0E06", "#6A2A14", "#A8482A", "#D27A50"]
    paint_form(cv, np.clip(mf - chip, 0, 1), clay, R=size * 0.05, grad=0.5, tilt=(0.0, 0.2))
    paint_form(cv, mt * allm, [mix(c_, "#FFE0C0", 0.15) for c_ in clay[1:]], R=size * 0.04, grad=0.4, tilt=(-0.3, -0.5))
    paint_form(cv, me * allm, [mix(c_, "#000000", 0.45) for c_ in clay[:3]], R=size * 0.03, grad=0.4)
    # pitted texture (low frequency) + mortar crust on the top edge
    cv.c *= (1 - 0.18 * allm * smoothstep(0.45, 0.65, cv.noise2))[..., None]
    crust = cv.poly(xf(H, [(-L + 0.02, -Wd - 0.02), (L - 0.1, -Wd - 0.03), (L - 0.15, -Wd + 0.05), (-L + 0.1, -Wd + 0.06)])) * allm
    paint_form(cv, crust * smoothstep(0.4, 0.6, cv.noise), ["#6A6258", "#A89C8A", "#D8CEBE"], R=1.0, grad=0.3)
    cv.add(allm * (1 - toward(allm, 1.4, LIGHT)), pal[2], 0.7 * k)
    return allm


def cloud(cv, rng, c, r, ramp, puffs=9, spread=(1.0, 0.7), alpha=1.0, line=None, grad=0.6, soft=0.0, wisps=0):
    """a billowing painted cloud: overlapping puffs, larger at the base, lit from the top-left. soft > 0 feathers the
    edge (smoke, not stone) and widens the value bands; wisps adds curling tendrils off the rim"""
    c = np.asarray(c, float)
    m = cv.ellipse(c[0], c[1], r * 0.62)
    for i in range(puffs):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.35, 0.8)
        p = c + np.array([math.cos(a) * r * d * spread[0], math.sin(a) * r * d * spread[1]])
        np.maximum(m, cv.ellipse(p[0], p[1], r * rng.uniform(0.32, 0.5)), out=m)
    for i in range(wisps):
        a = rng.uniform(0, 2 * math.pi)
        p0 = c + np.array([math.cos(a) * r * 0.7 * spread[0], math.sin(a) * r * 0.7 * spread[1]])
        dv = np.array([math.cos(a + 0.6), math.sin(a + 0.6)])
        wp = [p0, p0 + dv * r * 0.4 + np.array([-dv[1], dv[0]]) * r * 0.15, p0 + dv * r * 0.7]
        np.maximum(m, cv.poly(ribbon(spline(wp, 6), lambda t: r * 0.22 * (1 - t) + 0.4)), out=m)
    if soft:
        m = blur(m, r * soft)
    if line:
        ink_line(cv, m, line, 0.3, max(1.0, r * 0.03), 0.5, a=alpha)
    paint_form(cv, m, ramp, R=r * 0.35, grad=grad, alpha=alpha, thr=None, soft=0.08 + soft * 0.5)
    return m


def billow(cv, rng, c, r, ramp, puffs=10, spread=(1.0, 0.7), alpha=1.0):
    """soft smoke: puffs painted back to front as feathered value masses (shadow underside, mid body, lit cap toward
    the key light), so it reads as vapour, not as bevelled stones. ramp = (dark, mid, light, top)"""
    c = np.asarray(c, float)
    pts = []
    for i in range(puffs):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.0, 0.85)
        pts.append((c + np.array([math.cos(a) * r * d * spread[0], math.sin(a) * r * d * spread[1]]), r * rng.uniform(0.32, 0.55)))
    pts.sort(key=lambda q: -q[0][1])   # lower puffs first, upper puffs overlap them
    tot = np.zeros((cv.w, cv.w), np.float32)
    for p, rr in pts:
        e = cv.ellipse(p[0], p[1], rr)
        body = blur(e, rr * 0.22)
        cv.paint(body, ramp[1], 0.92 * alpha)
        under = blur(e * (1 - toward(e, rr * 0.45, LIGHT2)), rr * 0.3)
        cv.paint(under, ramp[0], 0.55 * alpha)
        cap = blur(e * toward(e, rr * 0.35, -LIGHT2) * cv.ellipse(p[0] - rr * 0.25, p[1] - rr * 0.3, rr * 0.75), rr * 0.25)
        cv.paint(cap, ramp[2], 0.7 * alpha)
        cv.paint(blur(cap * cv.ellipse(p[0] - rr * 0.35, p[1] - rr * 0.4, rr * 0.4), rr * 0.2), ramp[3], 0.45 * alpha)
        np.maximum(tot, body, out=tot)
    return tot
