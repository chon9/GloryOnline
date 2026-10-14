"""painter.subjects - shared subject library (reuse across classes; see tools/icons/README.md).

  draw_lance / lance_H / lance_persp   却邪 battle lance (matches the 3D model, lookdev_3)
  dragon_head / dragon_body / dragon_claw   Chinese dragon (龙) parts, any view through a homography
  gauntlet_palm                        armoured open palm, 3/4 view
  plate_fragment / stone_chip          armour shards / angular stone debris
  shock_ring / flare_spikes / petal / blossom

Shared module: per-class agents add new subjects in their own comps file or comps/_lib_<name>.py instead.
"""
import math

import numpy as np

from painter.core import *  # noqa: F401,F403


# ------------------------------------------------------------------ class weapon: 却邪 (matches LdWeapons model)
# local units: x along the weapon 0 (butt) .. 1 (tip), y across (screen-down, top/back side = -y).
# The blade is 48% of the weapon (2x the v1 icon), slim (w/l ~ 0.08), with a back hook and fine serrations.
def lance_geom():
    G = {}
    G["butt"] = [(0.0, 0.0), (0.028, -0.011), (0.042, -0.0125), (0.042, 0.0125), (0.028, 0.011)]
    G["shaft"] = [(0.04, -0.0105), (0.44, -0.0105), (0.44, 0.0105), (0.04, 0.0105)]
    G["bands"] = [[(a, -0.0145), (b, -0.0145), (b, 0.0145), (a, 0.0145)] for a, b in ((0.04, 0.056), (0.18, 0.193), (0.31, 0.323), (0.415, 0.432))]
    G["socket"] = [(0.43, -0.011), (0.452, -0.0185), (0.462, -0.014), (0.462, 0.014), (0.452, 0.0185), (0.43, 0.011)]
    cu = [(0.452, -0.011), (0.462, -0.029), (0.482, -0.037), (0.501, -0.030), (0.511, -0.016)]
    G["claw_u"] = (cu, (0.011, 0.0022))
    G["claw_l"] = ([(x, -y) for x, y in cu], (0.011, 0.0022))
    G["orb"] = (0.484, 0.0, 0.0195)
    G["guard"] = [(0.507, -0.011), (0.512, -0.024), (0.527, -0.030), (0.522, -0.016), (0.529, 0.0), (0.522, 0.016),
                  (0.527, 0.030), (0.512, 0.024), (0.507, 0.011)]
    # blade outline: back hook at the base (pointing back toward the wielder), fine forward-raked serrations along
    # the back edge, smooth cutting edge with a slight belly, long point
    back = [(0.524, -0.012), (0.513, -0.034), (0.506, -0.052), (0.522, -0.042), (0.540, -0.030), (0.556, -0.022)]
    x, s = 0.556, 0.0228
    teeth = []
    while x < 0.885:
        by = -(0.0215 - 0.0065 * (x - 0.556) / 0.33)
        teeth += [(x, by), (x + s * 0.78, by - 0.0058), (x + s * 0.82, by + 0.0004)]
        x += s
    back += teeth + [(0.93, -0.0128), (0.97, -0.0072), (1.0, 0.0015)]
    edge = [(1.0, 0.0015), (0.965, 0.0105), (0.90, 0.0175), (0.80, 0.0215), (0.68, 0.0225), (0.58, 0.0195), (0.524, 0.0125)]
    G["blade"] = back + edge[1:]
    ridge = [(0.524, -0.002), (0.70, -0.0015), (0.90, 0.0), (0.995, 0.0012)]
    G["facet_back"] = back + ridge[::-1]
    G["facet_edge"] = ridge + edge[1:]
    G["ridge"] = ridge
    G["edge"] = edge
    G["fuller"] = [(0.545, 0.0035), (0.72, 0.0032), (0.90, 0.0022)]
    return G


def draw_lance(cv, H, el, glow_k=1.0, tassel=False, line=True):
    """draw 却邪 through homography H (local -> icon). Returns the full mask."""
    G = lance_geom()
    T = lambda pts: xf(H, pts)
    pal = tone(el)
    c0, c1 = xf(H, [(0.80, 0.0), (0.80, -0.02)])
    back_lit = float(np.dot(c1 - c0, LIGHT)) > 0
    hw_shaft = hlen(H, (0.30, 0.0), (0.0, 0.0105))
    hw_head = hlen(H, (0.75, 0.0), (0.0, 0.02))
    axis = xf(H, [(0.6, 0.0), (0.9, 0.0)])
    ang = math.degrees(math.atan2(axis[1][1] - axis[0][1], axis[1][0] - axis[0][0]))
    shaft = cv.poly(T(G["shaft"]))
    butt = cv.poly(T(G["butt"]))
    bands = [cv.poly(T(b)) for b in G["bands"]]
    socket = cv.poly(T(G["socket"]))
    claws = []
    for k in ("claw_u", "claw_l"):
        pts, (w0, w1) = G[k]
        sp = spline(T(pts), 8)
        sc = hlen(H, pts[0], (0.0, 1.0))
        claws.append(cv.poly(ribbon(sp, lambda t: max(0.6, sc * (w0 + (w1 - w0) * t)))))
    guard = cv.poly(T(G["guard"]))
    blade = cv.poly(T(G["blade"]))
    fb = cv.poly(T(G["facet_back"])) * blade
    fe = np.clip(blade - fb, 0, 1)
    ox, oy, orr = G["orb"]
    oc = xf(H, [(ox, oy)])[0]
    orad = max(hlen(H, (ox, oy), (0.0, orr)), 1.4)
    parts = [shaft, butt, socket, guard, blade] + bands + claws
    full = union(cv, parts + [cv.ellipse(oc[0], oc[1], orad)])
    if tassel:
        a = xf(H, [(0.43, 0.0)])[0]
        d = xf(H, [(0.43, 0.0), (0.33, 0.0)])
        bk = (d[1] - d[0]) / (np.linalg.norm(d[1] - d[0]) + 1e-6)
        side = np.array([-bk[1], bk[0]])
        if side[1] < 0:
            side = -side
        L = hlen(H, (0.0, 0.0), (0.25, 0.0))
        path = spline([a, a + side * L * 0.25 + bk * L * 0.10, a + side * L * 0.42 + bk * L * 0.38, a + side * L * 0.36 + bk * L * 0.72], 6)
        tm = cv.poly(ribbon(path, lambda t: max(1.0, L * 0.06 * (1 - t * 0.55))))
        material(cv, tm, "cloth_red", R=max(1.5, L * 0.02), lw=(0.3, 1.4))
        np.maximum(full, tm, out=full)
    if line:
        ink_line(cv, union(cv, parts), "#030206", 0.45, 2.2, 0.4)
    material(cv, shaft, "lacquer", R=hw_shaft, line=False, streak_ang=ang, streak_k=0.10, back=pal[2], back_k=0.7)
    material(cv, butt, "steel", R=hw_shaft, line=False)
    for b in bands:
        material(cv, b, "gold", R=hw_shaft * 1.2, line=False)
    material(cv, socket, "lacquer", R=hw_shaft * 1.4, line=False)
    for cm in claws:
        material(cv, cm, "lacquer", R=max(1.0, hw_head * 0.3), lw=(0.3, 1.0), back="#FF3A44", back_k=0.6)
    # orb: a glowing crimson sphere with radial bloom -- no sclera ring, no dark centre
    om = cv.ellipse(oc[0], oc[1], orad * 1.0)
    glow(cv, om, "#FF1A2E", orad * 2.6, 1.0 * glow_k)
    glow(cv, om, "#FF5A50", orad * 1.0, 0.6 * glow_k)
    sl = bbox(om, int(orad * SS) + 4)
    X, Y = cv.grid()
    Xs, Ys = X[sl], Y[sl]
    dd = np.sqrt((Xs - oc[0]) ** 2 + (Ys - oc[1]) ** 2) / orad
    hc = oc + LIGHT2 * orad * 0.28
    dh = np.sqrt((Xs - hc[0]) ** 2 + (Ys - hc[1]) ** 2) / orad
    cfill = (col("#8A0818")[None, None] * (1 - smoothstep(1.0, 0.35, dd)[..., None]) + col("#F42A38")[None, None] * smoothstep(1.0, 0.35, dd)[..., None])
    a = smoothstep(1.02, 0.86, dd)[..., None]
    cv.c[sl] = cv.c[sl] * (1 - a) + cfill * a
    cv.c[sl] += (np.exp(-dh * dh * 3.2) * a[..., 0])[..., None] * col("#FFB8A8") * 1.1
    cv.c[sl] += (np.exp(-dd * dd * 0.9) * (1 - a[..., 0]) * 0.8)[..., None] * col("#FF3A44")
    material(cv, guard, "gold", R=hw_head * 0.5, lw=(0.3, 1.2))
    # blade: two facets split along the spine ridge, brushed along the blade, sharp spec streak on the lit facet
    lit, dark = (fb, fe) if back_lit else (fe, fb)
    paint_form(cv, lit, ["#9AA4BA", "#C8D0DE", "#E8EDF5", "#FFFFFF"], R=max(1.0, hw_head * 0.5), tilt=tuple(LIGHT2 * 0.5),
               grad=0.5, thr=[0.30, 0.62, 0.92])
    paint_form(cv, dark, ["#2E3448", "#4E586E", "#76809A", "#9CA6BC"], R=max(1.0, hw_head * 0.5), tilt=tuple(-LIGHT2 * 0.5),
               grad=0.5, thr=[0.2, 0.48, 0.78])
    sl = bbox(blade, 2)
    if sl is not None:
        f = streak_field(cv.w, ang, 180, 5, cv.seed())[sl]
        cv.c[sl] *= (1 + 0.18 * (f - 0.5) * 2 * blade[sl])[..., None]
    rp = spline(T(G["ridge"]), 8)
    off = (1 if back_lit else -1) * hw_head * 0.22
    nrm = np.array([-math.sin(math.radians(ang)), math.cos(math.radians(ang))]) * -off
    spec = cv.poly(ribbon(rp + nrm, lambda t: max(0.35, hw_head * 0.16 * math.sin(math.pi * min(1, t * 1.1)))))
    cv.paint(spec * blade * smoothstep(0.35, 0.5, cv.noise2), "#FFFFFF", 0.95)
    # cutting edge: thin bright honed line, broken; skill-light back rim on the shadow edge
    ep = spline(T(G["edge"]), 6)
    em = cv.poly(ribbon(ep, lambda t: max(0.35, hw_head * 0.10)))
    cv.paint(em * blade * (0.4 + 0.6 * smoothstep(0.3, 0.5, cv.noise2)), "#FFFFFF" if not back_lit else "#C8D2E4", 0.85)
    cv.add(blade * (1 - toward(blade, 1.2, LIGHT)), pal[2], 0.7)
    # red energy fuller
    fm = cv.poly(ribbon(spline(T(G["fuller"]), 6), lambda t: max(0.5, hw_head * (0.17 - 0.09 * t))))
    glow(cv, fm, "#FF2A3A", 2.2, 0.9 * glow_k)
    cv.paint(fm, "#E8202E")
    cv.add(np.clip(blur(fm, 0.35) * 2 - 1, 0, 1), "#FFB0A8", 0.9)
    return full


def lance_H(butt, tip, width_scale=1.0):
    b, t = np.array(butt, float), np.array(tip, float)
    d = t - b
    L = np.linalg.norm(d)
    ang = math.degrees(math.atan2(d[1], d[0]))
    return H_affine(b, ang, L, L * width_scale)


def lance_persp(butt, tip, near_w, far_w):
    """projective lance: the tip end is near the camera (wide), the butt far (narrow). widths = icon units for a
    local half-width of 0.06"""
    b, t = np.array(butt, float), np.array(tip, float)
    d = (t - b) / np.linalg.norm(t - b)
    nn = np.array([-d[1], d[0]])
    src = [(0, -1), (1, -1), (1, 1), (0, 1)]
    dst = [b - nn * far_w, t - nn * near_w, t + nn * near_w, b + nn * far_w]
    return H_quad(src, dst) @ np.diag([1.0, 1.0 / 0.06, 1.0])


# ------------------------------------------------------------------ Chinese dragon (龙) asset
# Profile facing +x, y down, ~unit size. v2: snout lengthened 1.35x past the eye (a 龙 muzzle, not a fox), narrow
# curved fangs, tapered antlers and whiskers.
def _snout(pts):
    return [((x if x < 0.5 else 0.5 + (x - 0.5) * 1.35), y) for x, y in pts]


D_UPPER = _snout([(-0.04, -0.16), (0.10, -0.27), (0.24, -0.33), (0.36, -0.31), (0.47, -0.23), (0.56, -0.19), (0.68, -0.20),
                  (0.76, -0.25), (0.82, -0.31), (0.90, -0.30), (0.96, -0.23), (0.97, -0.15), (0.91, -0.08), (0.84, -0.05), (0.80, -0.02),
                  (0.62, 0.00), (0.46, 0.04), (0.36, 0.10), (0.26, 0.16), (0.12, 0.18), (0.0, 0.10), (-0.06, -0.02)])
D_JAW = _snout([(0.22, 0.14), (0.36, 0.12), (0.50, 0.20), (0.64, 0.28), (0.74, 0.32), (0.82, 0.30), (0.81, 0.37), (0.72, 0.44),
                (0.62, 0.50), (0.58, 0.45), (0.50, 0.41), (0.36, 0.34), (0.22, 0.26), (0.14, 0.20)])
D_MOUTH = _snout([(0.34, 0.10), (0.46, 0.04), (0.62, 0.0), (0.80, -0.03), (0.84, 0.0), (0.78, 0.33), (0.64, 0.29), (0.50, 0.20)])
# narrow curved fangs: (base, mid, tip, base width)
D_FANGS = [(_snout([(0.775, -0.02), (0.790, 0.06), (0.772, 0.15)]), 0.030), (_snout([(0.64, 0.0), (0.648, 0.05), (0.638, 0.10)]), 0.022),
           (_snout([(0.705, 0.30), (0.716, 0.23), (0.704, 0.16)]), 0.026), (_snout([(0.56, 0.24), (0.566, 0.20), (0.556, 0.15)]), 0.020)]
D_TONGUE = (_snout([(0.42, 0.16), (0.60, 0.22), (0.78, 0.20), (0.92, 0.12), (1.0, 0.19)]), 0.05)
D_EYE = [(0.30, -0.215), (0.40, -0.25), (0.52, -0.19), (0.41, -0.16)]
D_PUPIL = [(0.425, -0.235), (0.437, -0.205), (0.428, -0.17), (0.416, -0.205)]
D_BROW = ([(0.56, -0.20), (0.42, -0.28), (0.28, -0.37), (0.12, -0.44), (-0.04, -0.44)], 0.11)
D_BROW2 = ([(0.40, -0.28), (0.30, -0.40), (0.22, -0.54)], 0.06)
D_TOP = _snout([(0.10, -0.27), (0.24, -0.33), (0.36, -0.31), (0.47, -0.23), (0.56, -0.19), (0.68, -0.20), (0.76, -0.25),
                (0.82, -0.31), (0.90, -0.30), (0.96, -0.23), (0.88, -0.21), (0.78, -0.16), (0.62, -0.12), (0.50, -0.12),
                (0.36, -0.15), (0.20, -0.19), (0.06, -0.17)])
D_CHEEK = _snout([(0.04, 0.0), (0.20, -0.05), (0.40, -0.05), (0.62, -0.04), (0.80, -0.04), (0.80, 0.0), (0.46, 0.05),
                  (0.30, 0.13), (0.12, 0.18), (0.0, 0.10)])
D_CARVE = [(_snout([(0.40, -0.07), (0.28, 0.0), (0.16, 0.06)]), 0.02), (_snout([(0.56, -0.16), (0.68, -0.17), (0.77, -0.24)]), 0.014),
           (_snout([(0.48, 0.32), (0.34, 0.26), (0.22, 0.20)]), 0.014), (_snout([(0.62, -0.11), (0.74, -0.12), (0.84, -0.09)]), 0.012)]
D_NOSTRIL = (_snout([(0.895, -0.215)])[0], 0.03)
D_FINS = [[(0.14, 0.12), (-0.14, 0.22), (0.08, 0.23)], [(0.20, 0.24), (-0.04, 0.42), (0.20, 0.33)]]
D_ANTLER = [([(0.20, -0.30), (0.12, -0.48), (-0.02, -0.60), (-0.22, -0.70), (-0.46, -0.72)], 0.075),
            ([(0.10, -0.50), (0.18, -0.64), (0.15, -0.78)], 0.045),
            ([(-0.06, -0.62), (-0.02, -0.78), (-0.08, -0.92)], 0.04),
            ([(-0.27, -0.70), (-0.33, -0.86)], 0.032)]
D_MANE = [([(0.04, -0.22), (-0.16, -0.30), (-0.34, -0.40), (-0.52, -0.40), (-0.74, -0.54)], 0.17),
          ([(-0.02, -0.08), (-0.24, -0.10), (-0.44, -0.18), (-0.64, -0.14), (-0.90, -0.24)], 0.20),
          ([(0.0, 0.06), (-0.22, 0.08), (-0.42, 0.18), (-0.62, 0.14), (-0.84, 0.24)], 0.18),
          ([(0.10, 0.18), (-0.08, 0.30), (-0.28, 0.36), (-0.46, 0.48), (-0.66, 0.46)], 0.15),
          ([(0.24, 0.30), (0.16, 0.44), (0.02, 0.52), (-0.10, 0.66), (-0.28, 0.70)], 0.11),
          ([(-0.02, -0.16), (-0.20, -0.20), (-0.40, -0.28), (-0.58, -0.26)], 0.10),
          ([(0.04, 0.12), (-0.16, 0.20), (-0.34, 0.28), (-0.52, 0.28)], 0.09)]
D_BEARD = [(_snout([(0.76, 0.44), (0.70, 0.58), (0.58, 0.68), (0.42, 0.72)]), 0.10),
           (_snout([(0.62, 0.46), (0.52, 0.58), (0.38, 0.64)]), 0.07)]
D_WHISKERS = [(_snout([(0.92, -0.16)]) + [(1.12, -0.28), (1.10, -0.44), (0.90, -0.52), (0.62, -0.50), (0.32, -0.58), (0.0, -0.54)], 0.036),
              (_snout([(0.90, -0.10)]) + [(1.14, 0.04), (1.16, 0.28), (1.00, 0.48), (0.72, 0.56), (0.46, 0.50)], 0.034)]


def curl_tip(path, turns=1.0, sign=1.0):
    """extend a lock path with a curling flame tip (the 'cloud curl' of Chinese ornament)"""
    p = [np.array(q, float) for q in path]
    d = p[-1] - p[-2]
    L = np.linalg.norm(d) * 0.45
    a = math.atan2(d[1], d[0])
    for i in range(3):
        a += sign * math.radians(55 * turns)
        L *= 0.6
        p.append(p[-1] + np.array([math.cos(a), math.sin(a)]) * L)
    return [tuple(q) for q in p]


def _rib(cv, H, path, w, taper=1.0, n=8, power=1.0):
    pts = spline(xf(H, path), n)
    sc = hlen(H, (0, 0), (w, 0))
    return cv.poly(ribbon(pts, lambda t: sc * (1 - taper * t ** power) + 0.35))


def dragon_head(cv, H, el, k=1.0, far_offset=(0.10, 0.035), mane_k=1.0, value=1.0):
    """龙首 through homography H. 3-value planar shading, tapered strokes. Returns the union mask."""
    pal = tone(el)
    Hf = H @ H_affine(far_offset, 0, 1.0)
    far = union(cv, [_rib(cv, Hf, p, w, 0.9, 8, 0.8) for p, w in D_ANTLER])
    material(cv, far, "gold", R=1.5, lw=(0.2, 1.0))
    cv.paint(far, mix(pal[0], KEY["ink"], 0.4), 0.45)
    mane = union(cv, [_rib(cv, H, curl_tip(p, 0.7, 1) if i == 1 else p, w, 1.0, 10, 0.8) for i, (p, w) in enumerate(D_MANE)])
    light_form(cv, mane, el, 0.8 * k * mane_k, R=3.0, glow_r=5, lw=(0.2, 1.4), value=0.92 * value)
    antler = union(cv, [_rib(cv, H, p, w, 0.9, 8, 0.8) for p, w in D_ANTLER])
    material(cv, antler, "gold", R=2.0, lw=(0.25, 1.4), back=pal[2], back_k=0.6)
    fins = union(cv, [cv.poly(xf(H, f)) for f in D_FINS])
    light_form(cv, fins, el, 0.9 * k, R=2.5, glow_r=3, lw=(0.2, 1.2), value=value)
    beard = union(cv, [_rib(cv, H, p, w, 1.0, 8) for p, w in D_BEARD])
    light_form(cv, beard, el, 0.7 * k, R=2.0, glow_r=3, lw=(0.2, 1.2), value=0.9 * value)
    mouth = cv.poly(xf(H, D_MOUTH))
    cv.paint(mouth, KEY["accent_dk"])
    cv.add(blur(mouth, 3) * mouth, KEY["accent"], 0.6)
    tongue = _rib(cv, H, *D_TONGUE, 0.6, 10)
    material(cv, tongue, "cloth_red", R=1.5, lw=(0.2, 0.9))
    jaw = cv.poly(xf(H, D_JAW))
    upper = cv.poly(xf(H, D_UPPER))
    light_form(cv, jaw, el, k, R=5.0, glow_r=4, lw=(0.3, 1.8), tilt=(0.0, 0.5), value=0.85 * value)
    light_form(cv, upper, el, k, R=7.0, glow_r=5, lw=(0.35, 2.0), value=value)
    # planar form: lit top plane, mid side plane, shadowed cheek plane under the eye line (3 values)
    top = cv.poly(xf(H, D_TOP)) * upper
    cv.paint(blur(top, 0.6), mix(pal[2], pal[3], 0.5) * value, 0.8)
    cheek = cv.poly(xf(H, D_CHEEK)) * upper
    cv.paint(blur(cheek, 0.6), mix(pal[1], pal[2], 0.15) * value, 0.8)
    mc = xf(H, [_snout([(0.62, 0.12)])[0]])[0]
    sz = hlen(H, (0, 0), (0.1, 0))
    X, Y = cv.grid()
    cv.add(np.exp(-((X - mc[0]) ** 2 + (Y - mc[1]) ** 2) / (sz * sz * 1.6)) * mouth, pal[3], 1.1 * k)
    for p, w in D_CARVE:
        cv.paint(_rib(cv, H, p, w, 0.95, 8, 1.2), mix(pal[0], pal[1], 0.4) * value, 0.9)
    brow = union(cv, [_rib(cv, H, *D_BROW, 1.0, 10, 0.8), _rib(cv, H, *D_BROW2, 1.0, 8)])
    cv.paint(blur(brow, 1.5) * upper, mix(pal[0], pal[1], 0.3), 0.7)  # brow casts a shadow over the eye
    light_form(cv, brow, el, k, R=2.0, glow_r=2, lw=(0.25, 1.3), value=value)
    for (pts, w) in D_FANGS:
        P = xf(H, pts)
        sc = hlen(H, pts[0], (w, 0))
        fm = cv.poly(ribbon(spline(P, 6), lambda t: sc * (1 - t) ** 0.9 + 0.25))
        material(cv, fm, "bone", R=max(0.8, sc * 0.35), lw=(0.2, 0.9))
    (nx_, ny_), nr = D_NOSTRIL
    nc = xf(H, [(nx_, ny_), (nx_ + nr, ny_)])
    cv.paint(cv.ellipse(nc[0][0], nc[0][1], max(np.linalg.norm(nc[1] - nc[0]), 0.8), max(np.linalg.norm(nc[1] - nc[0]) * 0.6, 0.6)),
             mix(pal[0], pal[1], 0.3))
    eye = cv.poly(xf(H, D_EYE))
    ink_line(cv, eye, mix(pal[0], KEY["ink"], 0.3), 0.3, 1.2, 0.0)
    cv.paint(eye, mix(pal[2], pal[3], 0.6))
    cv.add(blur(eye, 1.0), pal[2], 0.45 * k)
    cv.paint(cv.poly(xf(H, D_PUPIL)), KEY["accent_dk"])
    wh = union(cv, [_rib(cv, H, p, w, 1.0, 10, 0.7) for p, w in D_WHISKERS])
    soft_light(cv, wh, el, 0.9 * k, R=0.8, glow_r=2.5, core_k=0.8)
    return union(cv, [upper, jaw, mane, antler, wh, beard])


def dragon_body(cv, path, widths, el, k=1.0, solid_to=0.6, streaks=5, spread=1.6, fins=True, scales_to=0.75, value=1.0):
    """S-curve body of light painted as a solid (3-value), scale rows along the neck, dorsal flame fins; past
    `solid_to` it splits into diverging qi streaks that fade out. widths: list along the path (head end first)."""
    pal = tone(el)
    p = spline(path, 16)
    N = len(p)
    w = np.interp(np.linspace(0, 1, N), np.linspace(0, 1, len(widths)), widths)
    d = np.gradient(p, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    nrm = np.c_[-d[:, 1], d[:, 0]]
    i_s = int(N * solid_to)
    if fins:
        fm = np.zeros((cv.w, cv.w), np.float32)
        for i in range(2, i_s - 1, 4):
            base0 = p[i] + nrm[i] * w[i] * 0.42
            tip = p[i] + nrm[i] * w[i] * 1.15 - d[i] * w[i] * 1.1
            np.maximum(fm, cv.poly(spline([base0 + d[i] * w[i] * 0.5, base0 + nrm[i] * w[i] * 0.45, tip], 4).tolist() + [base0 - d[i] * w[i] * 0.45]), out=fm)
        light_form(cv, fm, el, 0.8 * k, R=2.0, glow_r=3, lw=(0.2, 1.2), value=0.9 * value)
    for s in range(streaks):
        off = (s - (streaks - 1) / 2) / max(1, (streaks - 1) / 2)
        pts, ww = [], []
        for i in range(i_s - 3, N):
            t = (i - i_s + 3) / max(1, N - i_s + 3)
            pts.append(p[i] + nrm[i] * off * w[i] * 0.42 * (1 + spread * t * t))
            ww.append(w[i] * (0.32 if s % 2 == 0 else 0.2) * (1 - t) ** 1.2 + 0.3)
        sm = cv.poly(ribbon(np.array(pts), ww))
        fade = 1.0 - 0.45 * abs(off)
        soft_light(cv, sm, el, 0.75 * k * fade, R=1.4, glow_r=3, core_k=0.6)
    body = cv.poly(ribbon(p[:i_s + 1], w[:i_s + 1] * np.r_[np.ones(i_s - 3), np.linspace(1, 0.55, 4)]))
    light_form(cv, body, el, k, R=max(2.0, w.max() * 0.30), glow_r=max(4.0, w.max() * 0.3), lw=(0.3, 2.0), value=value)
    # scale rows on the neck: overlapping scallops, darker body with a lit lower rim
    i_sc = int(i_s * scales_to)
    for i in range(2, i_sc, 2):
        for j, o in enumerate((-0.26, 0.0, 0.26)):
            if (i // 2) % 2:
                o += 0.13
            c = p[i] + nrm[i] * o * w[i]
            r = w[i] * 0.15
            sc = cv.ellipse(c[0], c[1], r)
            cut = cv.ellipse(c[0] - d[i][0] * r * 0.55, c[1] - d[i][1] * r * 0.55, r * 0.95)
            cres = np.clip(sc - cut, 0, 1) * body
            cv.paint(cres, mix(pal[1], pal[2], 0.25) * value, 0.75)
            cv.paint(np.clip(sc - toward(sc, r * 0.3, -d[i]), 0, 1) * cut * body, mix(pal[2], pal[3], 0.5) * value, 0.35)
    for i in range(3, i_s - 1, 3):  # belly ridges
        a = p[i] - nrm[i] * w[i] * 0.48
        b = p[i] - nrm[i] * w[i] * 0.05
        c = p[i] - d[i] * w[i] * 0.25 - nrm[i] * w[i] * 0.25
        rm = cv.poly(ribbon(spline([a, c, b], 4), [0.3, max(0.8, w[i] * 0.06), 0.3]))
        cv.paint(rm * body, mix(pal[0], pal[1], 0.6) * value, 0.55)
    return body, p, w, nrm, d


def dragon_claw(cv, base, ang_deg, size, el, k=1.0, spread=1.0):
    """forelimb + four-toed claw: tapered leg, palm pad, four curved toes ending in ivory talons"""
    a = math.radians(ang_deg)
    dv = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-dv[1], dv[0]])
    b = np.array(base, float)
    elbow = b + dv * size * 0.55 + nv * size * 0.22
    wrist = elbow + dv * size * 0.5 - nv * size * 0.05
    leg = cv.poly(ribbon(spline([b, elbow, wrist], 6), [size * 0.34, size * 0.24, size * 0.2]))
    palm = cv.ellipse(wrist[0] + dv[0] * size * 0.08, wrist[1] + dv[1] * size * 0.08, size * 0.16)
    toes, talons = [], []
    for i, da in enumerate((-50, -18, 14, 46)):
        ta = a + math.radians(da * spread)
        tv = np.array([math.cos(ta), math.sin(ta)])
        tn = np.array([-tv[1], tv[0]])
        L = size * (0.42 if i in (1, 2) else 0.34)
        p0 = wrist + dv * size * 0.08
        p1 = p0 + tv * L * 0.55 + tn * L * 0.08
        p2 = p0 + tv * L
        toes.append(cv.poly(ribbon(spline([p0, p1, p2], 4), [size * 0.12, size * 0.1, size * 0.08])))
        talons.append(stroke(cv, [p2 - tv * size * 0.02, p2 + tv * size * 0.10 + tn * size * 0.04, p2 + tv * size * 0.15 + tn * size * 0.13],
                             size * 0.085, 0.3))
    m = union(cv, [leg, palm] + toes)
    light_form(cv, m, el, k, R=size * 0.10, glow_r=4, lw=(0.3, 1.6))
    for tm in talons:
        material(cv, tm, "bone", R=size * 0.03, lw=(0.2, 0.9))
    return m


# ------------------------------------------------------------------ shared subject assets
def plate_fragment(cv, rng, cx, cy, size, ang, el, k=1.0, trail=None):
    """a curved piece of a broken breastplate: dark lacquered steel face, gold trim along the original curved edge,
    a visible thickness side, a jagged break edge glowing with the skill's light"""
    pal = tone(el)
    H = H_affine((cx, cy), ang, size)
    top = [(x, -0.34 + 0.28 * x * x + 0.04 * x) for x in np.linspace(-0.5, 0.5, 8)]
    jag = []
    xs = np.linspace(0.5, -0.5, int(rng.integers(4, 7)))
    for i, x in enumerate(xs):
        jag.append((x + rng.uniform(-0.05, 0.05), 0.28 + rng.uniform(-0.2, 0.16) + (0.08 if i % 2 else -0.04)))
    face_pts = xf(H, top + jag)
    face = cv.poly(face_pts)
    th = max(1.0, size * 0.08)
    thick = np.clip(toward(face, th, -LIGHT2) - face, 0, 1)
    if trail is not None:
        tm = blur(toward(face, size * 0.5, -np.asarray(trail)), size * 0.12) * (1 - face)
        cv.add(tm, pal[1], 0.35 * k)
    ink_line(cv, union(cv, [face, toward(face, th, -LIGHT2)]), "#030206", 0.35, 1.8, 0.4)
    cv.paint(thick, "#07070C")
    cv.paint(thick * (1 - toward(thick, 0.8, (0, 1))), "#2A2A38", 0.7)
    curve_tilt = (math.sin(math.radians(ang)) * 0.3, -0.25)
    material(cv, face, "plate", R=size * 0.22, line=False, tilt=curve_tilt, grad=0.6, back=pal[2], back_k=0.5)
    trim_in = xf(H, [(x, y + 0.11) for x, y in top][::-1])
    trim = cv.poly(np.vstack([face_pts[:len(top)], trim_in])) * face
    material(cv, trim, "gold", R=size * 0.05, lw=(0.2, 0.8), brk=0.2)
    # filigree notch in the trim
    fp = xf(H, [(-0.12, -0.24), (0.0, -0.30), (0.12, -0.24)])
    cv.paint(stroke(cv, fp, size * 0.03, size * 0.01) * face, "#3A1C08", 0.8)
    # the break glows: hot element rim along the jagged edge
    jm = cv.poly(ribbon(xf(H, jag), [max(0.6, size * 0.035)] * len(jag))) * dilate(face, 0.6)
    cv.add(blur(jm, 0.8), pal[2], 0.9 * k)
    cv.add(jm, pal[3], 0.5 * k)
    return face


def stone_chip(cv, rng, cx, cy, size, ang, el, hot_dir=None, trail=None, k=1.0):
    """angular dark stone chip, hard faceted planes, a hot rim edge facing the energy source"""
    pal = tone(el)
    nv = int(rng.integers(5, 7))
    angs = np.sort(rng.uniform(0, 2 * math.pi, nv))
    pts = [(cx + math.cos(a + math.radians(ang)) * size * rng.uniform(0.55, 1.0),
            cy + math.sin(a + math.radians(ang)) * size * rng.uniform(0.4, 0.8)) for a in angs]
    m = cv.poly(pts)
    if trail is not None:
        tr = np.asarray(trail, float)
        tm = blur(toward(m, size * 2.2, -tr), size * 0.5) * (1 - m)
        cv.add(tm, pal[1], 0.3 * k)
    ink_line(cv, m, "#020103", 0.3, 1.4, 0.3)
    # facets: split by a line through the centre, each facet flat-shaded at a different value
    c = np.mean(pts, axis=0)
    fa = cv.poly([c] + pts[:nv // 2 + 1]) * m
    fbm = np.clip(m - fa, 0, 1)
    material(cv, fa, "stone", R=size * 0.2, line=False, tilt=tuple(LIGHT2 * 0.6), spec=False)
    material(cv, fbm, "stone", R=size * 0.2, line=False, tilt=tuple(-LIGHT2 * 0.4), spec=False)
    hd = np.asarray(hot_dir if hot_dir is not None else LIGHT2, float)
    rim = m * (1 - toward(m, max(0.7, size * 0.14), -hd))
    cv.add(blur(rim, 0.4), pal[1], 0.9 * k)
    cv.add(rim, pal[2], 0.45 * k)
    return m


def shock_ring(cv, c, u, v, ru, rv, w, el, k=1.0, a0=0, a1=360, front_k=1.0):
    """ellipse ring with axes u (radius ru) and v (radius rv); thicker and brighter on the near side (+v)"""
    pal = tone(el)
    t = np.linspace(math.radians(a0), math.radians(a1), 96)
    pts = np.array([c + u * math.cos(a) * ru + v * math.sin(a) * rv for a in t])
    ws = [w * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(a))) * (0.4 + 0.6 * math.sin(math.pi * i / 95)) for i, a in enumerate(t)]
    m = cv.poly(ribbon(pts, ws))
    soft_light(cv, m, el, k, R=max(0.8, w * 0.35), glow_r=3, core_k=0.9)
    return m


def flare_spikes(cv, cx, cy, angs, r0, r1, w, el, k=1.0):
    """a few big light spikes with a soft painted falloff"""
    m = np.zeros((cv.w, cv.w), np.float32)
    for a, s in angs:
        a = math.radians(a)
        dv = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-dv[1], dv[0]])
        p0 = np.array([cx, cy]) + dv * r0
        p1 = np.array([cx, cy]) + dv * (r0 + (r1 - r0) * s)
        np.maximum(m, cv.poly([p0 + nv * w * s, p1, p0 - nv * w * s]), out=m)
    soft_light(cv, m, el, k, R=max(1.0, w * 0.4), glow_r=3)
    return m


def petal_pts(cx, cy, size, ang, squash=1.0, notch=0.07):
    """peach/plum petal: narrow claw at the base, broad rounded blade, a shallow notch at the tip. Base at (cx, cy)."""
    u = np.linspace(0, 2 * math.pi, 56)
    s = (1 - np.cos(u)) / 2
    x = size * s
    y = 0.40 * size * np.sin(u) * s ** 0.75 * squash
    x = x - notch * size * np.exp(-(y / (0.09 * size * max(squash, 0.3) + 1e-6)) ** 2) * s ** 8
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return np.c_[cx + x * ca - y * sa, cy + x * sa + y * ca]


def petal(cv, x, y, size, ang, squash=1.0, value=1.0, trail=0.0, lw=True):
    m = cv.poly(petal_pts(x, y, size, ang, squash))
    if trail:
        a = math.radians(ang)
        dv = np.array([math.cos(a), math.sin(a)])
        tm = blur(toward(m, size * trail, -dv), size * 0.25) * (1 - m)
        cv.add(tm, "#FF5A6A", 0.30 * value)
    glow(cv, m, KEY["accent"], size * 0.25, 0.25 * value)
    ramp, lcol, _ = MAT["petal"]
    if lw:
        ink_line(cv, m, lcol, 0.2, max(0.6, size * 0.06), 0.5, a=value)
    paint_form(cv, m, [col(c) * value for c in ramp], R=max(1.0, size * 0.22), tilt=(math.cos(math.radians(ang)) * -0.3, -0.2), grad=0.45)
    # vein: one thin darker stroke from the base
    a = math.radians(ang)
    dv = np.array([math.cos(a), math.sin(a)])
    cv.paint(stroke(cv, [(x, y), (x + dv[0] * size * 0.55, y + dv[1] * size * 0.55)], max(0.4, size * 0.04), 0.2) * m, col("#8A1024") * value, 0.5)
    return m


def blossom(cv, cx, cy, size, ang, el, k=1.0, glow_k=0.0, tilt=1.0):
    """5 notched petals + a stamen cluster (filaments with gold anthers)"""
    m = np.zeros((cv.w, cv.w), np.float32)
    if glow_k:
        glow(cv, cv.ellipse(cx, cy, size * 0.5), KEY["accent"], size * 0.4, glow_k)
    for i in range(5):
        a = ang + i * 72
        np.maximum(m, petal(cv, cx, cy, size * 0.62, a, 0.95 * (0.75 + 0.25 * abs(math.cos(math.radians(a)))) if tilt < 1 else 0.95), out=m)
    cv.paint(cv.ellipse(cx, cy, size * 0.12), "#7A0F2E")
    cv.add(blur(cv.ellipse(cx, cy, size * 0.10), 1.0), "#FFD86A", 0.6)
    for i in range(11):
        a = math.radians(ang + 17 + i * 32.7)
        L = size * (0.26 + 0.06 * ((i * 7) % 3))
        e = (cx + math.cos(a) * L, cy + math.sin(a) * L)
        cv.paint(stroke(cv, [(cx, cy), e], max(0.35, size * 0.022), 0.3), "#FFE9C8", 0.9)
        cv.paint(cv.ellipse(e[0], e[1], max(0.6, size * 0.035)), "#FFD24A")
        cv.paint(cv.ellipse(e[0] - 0.2, e[1] - 0.2, max(0.3, size * 0.015)), "#FFFBE0")
    return m


# ------------------------------------------------------------------ armoured open palm
def gauntlet_palm(cv, H, el):
    """一叶之秋-style armoured gauntlet, OPEN PALM toward the viewer. Fingers splayed at different lengths, three
    plated segments each with a knuckle break and a gold joint line, small gold claw tips, a clear 2-segment thumb,
    a foreshortened leather palm with a glowing centre, a lacquered vambrace with gold trim. Local: wrist at the
    origin, fingers toward -y, palm width ~0.64."""
    T = lambda pts: xf(H, pts)
    S = lambda p, w: hlen(H, p, (w, 0))
    cuff = cv.poly(T([(-0.30, -0.02), (0.30, -0.02), (0.36, 0.30), (0.42, 0.66), (-0.42, 0.66), (-0.36, 0.30)]))
    palm = cv.poly(T(closed_spline([(-0.31, -0.06), (-0.34, -0.30), (-0.28, -0.46), (-0.10, -0.52), (0.10, -0.53), (0.27, -0.47),
                                    (0.33, -0.30), (0.30, -0.06), (0.0, 0.0)], 6)))
    fingers, joints, tips = [], [], []
    # base, splay angle (deg from up), length, width, bend per joint (curl toward the viewer)
    for (bx, by), ang, L, w, bend in (((-0.220, -0.44), -19, 0.40, 0.150, 6), ((-0.072, -0.50), -6, 0.47, 0.158, 4),
                                      ((0.078, -0.50), 8, 0.43, 0.152, 6), ((0.212, -0.43), 24, 0.31, 0.135, 9)):
        p = np.array([bx, by])
        a = math.radians(ang - 90)
        segs = []
        for s_i, frac in enumerate((0.44, 0.32, 0.24)):
            dv = np.array([math.cos(a), math.sin(a)])
            q = p + dv * L * frac
            ww = w * (1.0 - s_i * 0.12)
            pa, qa = T([p])[0], T([q - dv * 0.012])[0]
            seg = cv.poly(ribbon(spline([pa, (pa + qa) / 2, qa], 3), [S(p, ww), S(p, ww * 0.98), S(q, ww * 0.9)]))
            np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.45)), out=seg)
            segs.append(seg)
            nv = np.array([-dv[1], dv[0]])
            joints.append(T([p + nv * ww * 0.48, p + dv * 0.012, p - nv * ww * 0.48]))
            p = q
            a += math.radians(bend * (1 if ang >= 0 else -1))
        dv = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-dv[1], dv[0]])
        tips.append(cv.poly(T([p - nv * w * 0.32 - dv * 0.01, p + dv * 0.075 + nv * w * 0.05, p + nv * w * 0.32 - dv * 0.01])))
        fingers.append(segs)
    thumb = []
    p = np.array([-0.30, -0.12])
    a = math.radians(-148)
    for s_i, (Ls, ww) in enumerate(((0.20, 0.175), (0.16, 0.15))):
        dv = np.array([math.cos(a), math.sin(a)])
        q = p + dv * Ls
        pa, qa = T([p])[0], T([q])[0]
        seg = cv.poly(ribbon([pa, (pa + qa) / 2, qa], [S(p, ww), S(p, ww * 0.98), S(q, ww * 0.88)]))
        np.maximum(seg, cv.ellipse(qa[0], qa[1], S(q, ww * 0.44)), out=seg)
        thumb.append(seg)
        nv = np.array([-dv[1], dv[0]])
        joints.append(T([p + nv * ww * 0.5, p, p - nv * ww * 0.5]))
        p = q
        a += math.radians(16)
    dv = np.array([math.cos(a), math.sin(a)])
    nv = np.array([-dv[1], dv[0]])
    tips.append(cv.poly(T([p - nv * 0.045, p + dv * 0.07 + nv * 0.01, p + nv * 0.045])))
    allm = union(cv, [palm, cuff] + thumb + [s for f in fingers for s in f] + tips)
    ink_line(cv, allm, "#030206", 0.5, 2.6, 0.35)
    material(cv, cuff, "lacquer", R=S((0, 0.3), 0.18), line=False, tilt=(0.0, 0.3), back="#FF5A50", back_k=0.6)
    trim = cv.poly(T([(-0.31, 0.0), (0.31, 0.0), (0.33, 0.09), (-0.33, 0.09)])) * cuff
    material(cv, trim, "gold", R=1.5, lw=(0.2, 0.9))
    # cloud-scroll (祥云) motif on the vambrace
    for sx in (-1, 1):
        cp = [(sx * (0.02 + 0.10 * math.cos(a)), 0.24 + 0.07 * math.sin(a)) for a in np.linspace(math.pi, math.pi * 2.6, 9)]
        cv.paint(stroke(cv, T([(0.0, 0.30)] + cp), S((0, 0.3), 0.035), S((0, 0.3), 0.012), 6) * cuff, "#D8B25A", 0.95)
    material(cv, palm, "leather", R=S((0, -0.3), 0.16), line=False, tilt=(0.15, -0.1), back="#FF4A4E", back_k=0.6)
    # palm creases
    for pts in (((-0.26, -0.36), (-0.04, -0.30), (0.20, -0.36)), ((-0.24, -0.22), (0.0, -0.17), (0.12, -0.10))):
        cv.paint(stroke(cv, T(pts), S((0, -0.3), 0.022), 0.3, 6) * palm, "#0C0607", 0.75)
    for segs in fingers + [thumb]:
        for s_i, seg in enumerate(segs):
            material(cv, seg, "lacquer", R=max(1.5, hlen(H, (0, -0.6), (0.05, 0))), lw=(0.25, 1.2), brk=0.5, back="#FF5A50", back_k=0.5)
    for jp in joints:  # gold trim line across each knuckle break
        cv.paint(stroke(cv, jp, S((0, -0.6), 0.02), S((0, -0.6), 0.02), 4), "#D8B25A", 0.95)
        cv.paint(stroke(cv, jp, S((0, -0.6), 0.008), S((0, -0.6), 0.008), 4), "#FFE9A8", 0.8)
    for t_ in tips:
        material(cv, t_, "gold", R=1.0, lw=(0.2, 0.8), brk=0.1)
    return allm, palm
