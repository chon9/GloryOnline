"""Shared drawers for the Priest-group bars (exorcist, cleric, paladin), plus a few the knight/warlock bars may reuse.
Imported explicitly (`from comps._lib_priest import ...`); never auto-discovered (name starts with _lib_).

  rune_circle(cv, c, rx, ry, el, k)        a holy rune circle in perspective: double ring, tick ring, an 8-point
                                            star of light strokes and bead dots; no letters, no real-world sigil
  talisman(cv, c, w, h, ang, k, mark)      a yellow paper talisman (符) with red brush marks (abstract strokes, not
                                            characters), a soft fold shading and a torn lower edge
  wing(cv, root, span, ang, el, mirror)    a painted feathered wing: primaries, secondaries, two covert rows,
                                            a leading-edge arm; white feather ramp with an element rim
  feather(cv, base, tip, w, el)            a single painted contour feather with a rachis and a few barb splits
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403

FEATHER = ["#4E5468", "#9AA2B6", "#DCE0EA", "#FFFFFF"]
PAPER = ["#6A4A12", "#B88E36", "#EED48A", "#FFF6D6"]
INK_RED = "#B0141C"


def _ell(c, rx, ry, a, rot=0.0):
    r = math.radians(rot)
    x, y = math.cos(a) * rx, math.sin(a) * ry
    return np.array([c[0] + x * math.cos(r) - y * math.sin(r), c[1] + x * math.sin(r) + y * math.cos(r)])


def rune_circle(cv, c, rx, ry, el, k=1.0, w=None, star=8, rot=0.0, beads=True):
    """a holy rune circle seen at the ellipse (rx, ry): two light rings, a ring of radial ticks between them, an
    inner star polygon (every 3rd vertex joined) and bead dots. Returns the union mask of its strokes."""
    n = cv.n
    w = w or n * 0.018
    c = np.asarray(c, float)
    u = np.array([math.cos(math.radians(rot)), math.sin(math.radians(rot))])
    v = np.array([-u[1], u[0]])
    m1 = shock_ring(cv, c, u, v, rx, ry, w, el, k)
    m2 = shock_ring(cv, c, u, v, rx * 0.80, ry * 0.80, w * 0.6, el, 0.8 * k)
    parts = []
    for i in range(36):
        a = 2 * math.pi * i / 36
        L = 0.07 if i % 3 == 0 else 0.035
        parts.append(stroke(cv, [_ell(c, rx * (0.82), ry * 0.82, a, rot), _ell(c, rx * (0.82 + L), ry * (0.82 + L), a, rot)],
                            w * 0.5, w * 0.3, n=2))
    pts = [_ell(c, rx * 0.62, ry * 0.62, 2 * math.pi * i / star - math.pi / 2, rot) for i in range(star)]
    step = 3 if star == 8 else 2
    for i in range(star):
        parts.append(stroke(cv, [pts[i], pts[(i + step) % star]], w * 0.45, w * 0.45, n=2))
    ticks = union(cv, parts)
    soft_light(cv, ticks, el, 0.8 * k, R=max(0.6, w * 0.2), glow_r=2, core_k=0.7)
    if beads:
        for i in range(star):
            a = 2 * math.pi * (i + 0.5) / star - math.pi / 2
            p = _ell(c, rx * 0.91, ry * 0.91, a, rot)
            b = cv.ellipse(p[0], p[1], w * 0.9, w * 0.9 * max(0.4, ry / rx))
            soft_light(cv, b, el, k, R=max(0.6, w * 0.3), glow_r=2)
    return union(cv, [m1, m2, ticks])


def _brush(cv, pts, w0, w1, wm=None):
    return stroke(cv, pts, w0, w1, n=6, w_mid=wm)


def talisman(cv, c, w, h, ang, k=1.0, mark=0, glow_el=None, glow_k=0.6, curl=0.0):
    """a paper talisman centred at c, w x h icon units, rotated ang degrees. mark picks one of four abstract
    brush designs (spiral-crown, triple bar, eye-and-spine, coil). curl bends the lower half (fluttering)."""
    H = H_affine(c, ang, 1.0)
    xs = np.linspace(-0.5, 0.5, 6)
    top = [(x * w, -h / 2) for x in xs]
    bot = []
    for i, x in enumerate(xs[::-1]):
        bot.append((x * w + curl * w * 0.4, h / 2 + (0.015 * h if i % 2 else -0.02 * h)))
    left = [(-w / 2 + curl * w * 0.2 * t, -h / 2 + h * t) for t in (0.25, 0.5, 0.75)]
    right = [(w / 2 + curl * w * 0.2 * t, -h / 2 + h * t) for t in (0.25, 0.5, 0.75)]
    pts = top + right + bot + left[::-1]
    m = cv.poly(xf(H, pts))
    if glow_el:
        glow(cv, m, tone(glow_el)[1], max(4.0, w * 0.25), glow_k)
    ink_line(cv, m, "#3A2406", 0.3, 1.5, 0.3)
    X, Y = cv.grid()
    fold = (0.12 * np.sin(((X - c[0]) * math.cos(math.radians(ang)) + (Y - c[1]) * math.sin(math.radians(ang))) / max(1, w) * 5.0)).astype(np.float32)
    paint_form(cv, m, PAPER, R=max(1.0, w * 0.18), grad=0.6, field=fold)
    T = lambda q: xf(H, [(px * w, py * h) for px, py in q])
    bw = max(0.6, w * 0.07)
    # red double border
    for s_ in (0.40, 0.36):
        frame = np.clip(cv.poly(T([(-s_, -0.46), (s_, -0.46), (s_, 0.46), (-s_, 0.46)])) - cv.poly(T([(-s_ + 0.02, -0.45), (s_ - 0.02, -0.45),
                                                                                                         (s_ - 0.02, 0.45), (-s_ + 0.02, 0.45)])), 0, 1)
        cv.paint(frame * m, INK_RED, 0.75)
    strokes = []
    if mark == 0:     # spiral crown over a spine with three branches
        strokes.append(_brush(cv, T([(-0.18, -0.30), (0.0, -0.40), (0.18, -0.30), (0.06, -0.22), (-0.04, -0.28)]), bw, bw * 0.4))
        strokes.append(_brush(cv, T([(0.0, -0.22), (0.02, 0.0), (-0.02, 0.24), (0.0, 0.40)]), bw * 1.2, bw * 0.3))
        for y, s_ in ((-0.08, -1), (0.06, 1), (0.20, -1)):
            strokes.append(_brush(cv, T([(0.0, y), (s_ * 0.16, y + 0.04), (s_ * 0.24, y + 0.10)]), bw * 0.9, bw * 0.3))
    elif mark == 1:   # three stacked bars and a long hooked tail
        for y in (-0.30, -0.20, -0.10):
            strokes.append(_brush(cv, T([(-0.24, y), (0.0, y - 0.02), (0.24, y)]), bw * 1.1, bw * 0.5))
        strokes.append(_brush(cv, T([(0.0, -0.06), (0.0, 0.20), (-0.08, 0.34), (-0.18, 0.32)]), bw * 1.2, bw * 0.3))
        strokes.append(_brush(cv, T([(0.10, 0.10), (0.20, 0.22)]), bw, bw * 0.3))
    elif mark == 2:   # a closed eye over a spine with dots
        strokes.append(_brush(cv, T([(-0.24, -0.26), (0.0, -0.34), (0.24, -0.26)]), bw * 0.6, bw * 0.6, bw * 1.3))
        strokes.append(_brush(cv, T([(-0.24, -0.26), (0.0, -0.20), (0.24, -0.26)]), bw * 0.6, bw * 0.6, bw * 1.3))
        strokes.append(_brush(cv, T([(0.0, -0.14), (0.0, 0.36)]), bw * 1.3, bw * 0.4))
        for y in (0.0, 0.14, 0.28):
            q = T([(0.14, y)])[0]
            strokes.append(cv.ellipse(q[0], q[1], bw * 0.7))
    else:             # a coil
        pts_ = [(math.cos(a) * 0.22 * (1 - a / 14), -0.10 + math.sin(a) * 0.14 * (1 - a / 14)) for a in np.linspace(0, 12, 26)]
        strokes.append(_brush(cv, T(pts_), bw * 1.1, bw * 0.4))
        strokes.append(_brush(cv, T([(0.0, 0.12), (0.02, 0.38)]), bw * 1.1, bw * 0.3))
    sm = union(cv, strokes) * m
    cv.paint(sm, INK_RED, 0.92)
    cv.add(sm * (1 - toward(sm, 0.6, LIGHT)), "#FF6A50", 0.3 * k)
    return m


def feather(cv, base, tip, w, el, k=1.0, ramp=None, rim=True, line=True, barbs=True):
    """one contour feather: an asymmetric vane (narrow leading side, broad trailing side) around a curved rachis,
    angled barb striations, two splits in the vane and a little down at the base"""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    d = tip - base
    L = float(np.linalg.norm(d))
    d /= L + 1e-9
    nv = np.array([-d[1], d[0]])
    mid = base + d * L * 0.5 + nv * L * 0.08
    path = spline([base, mid, tip], 10)
    prof = lambda u: math.sin(math.pi * min(1.0, 0.10 + u * 0.93)) ** 0.6
    lead = cv.poly(ribbon(path - nv * 0.0, lambda u: w * 0.70 * prof(u) + 0.3))
    trail_ = cv.poly(ribbon(path + nv * w * 0.22, lambda u: w * 1.05 * prof(u) + 0.3))
    m = np.maximum(lead, trail_)
    if line:
        ink_line(cv, m, "#1C2236", 0.25, 1.3, 0.45)
    field = None
    if barbs:
        X, Y = cv.grid()
        al = (X - base[0]) * d[0] + (Y - base[1]) * d[1]
        ac = (X - base[0]) * nv[0] + (Y - base[1]) * nv[1]
        f = np.sin((al - np.abs(ac) * 1.4) / max(0.6, w * 0.10) + cv.noise * 2.0)
        field = (0.20 * f).astype(np.float32)
    paint_form(cv, m, ramp or FEATHER, R=max(0.8, w * 0.35), grad=0.5, field=field)
    cv.paint(stroke(cv, [base, mid, tip], max(0.5, w * 0.12), 0.3) * m, "#8A90A4", 0.7)
    for t, side in ((0.36, -1), (0.50, 1), (0.62, -1), (0.72, 1), (0.84, 1)):
        p = base + d * L * t
        cut = stroke(cv, [p + nv * side * w * 0.06, p + nv * side * w * 0.6 - d * L * 0.08], max(0.4, w * 0.09), 0.3, n=2) * m
        cv.paint(cut, "#3A4054", 0.7)
    down = blur(cv.ellipse(base[0] + d[0] * L * 0.06, base[1] + d[1] * L * 0.06, w * 0.5, w * 0.5) * (1 - m), max(0.6, w * 0.15))
    cv.add(down, "#DCE0EA", 0.35)
    if rim:
        cv.add(m * (1 - toward(m, 1.0, LIGHT)), tone(el)[2], 0.6 * k)
    return m


def wing(cv, root, span, ang, el, mirror=False, k=1.0, lift=1.0, primaries=7, ramp=None):
    """a feathered wing from the shoulder `root`, reaching `span` icon units along angle `ang` (degrees, 0 = right,
    -90 = up). mirror=True builds a left wing. lift raises the wingtip. Returns the wing's union mask."""
    # build in an un-rotated local frame (x outward, y down), then map
    a = math.radians(ang)
    ux = np.array([math.cos(a), math.sin(a)]) * span
    uy = np.array([-math.sin(a), math.cos(a)]) * span
    if mirror:
        ux = np.array([-math.cos(a), math.sin(a)]) * span
        uy = np.array([math.sin(a), math.cos(a)]) * span
    R0 = np.asarray(root, float)

    def T(p):
        return R0 + ux * p[0] + uy * p[1]

    edge = [(0.0, 0.0), (0.22, -0.18 * lift), (0.48, -0.30 * lift), (0.62, -0.30 * lift), (0.80, -0.36 * lift)]
    E = spline(edge, 10)
    masks = []
    pal = ramp or FEATHER
    wpx = span * 0.15
    # primaries (outer hand), longest at the tip, fanning down and back
    for i in range(primaries):
        t = i / max(1, primaries - 1)
        b = E[int((0.50 + 0.50 * (1 - t)) * (len(E) - 1))]
        aa = math.radians(-22 + 82 * t)
        L = 0.62 - 0.22 * t
        tip = (b[0] + math.cos(aa) * L, b[1] + math.sin(aa) * L)
        masks.append(feather(cv, T(b), T(tip), wpx * (1.0 - 0.15 * t), el, k, ramp=pal))
    # secondaries along the arm, pointing down
    for i in range(6):
        t = i / 5.0
        b = E[int((0.08 + 0.45 * t) * (len(E) - 1))]
        aa = math.radians(100 - 30 * t)
        L = 0.36 + 0.06 * t
        tip = (b[0] + math.cos(aa) * L, b[1] + math.sin(aa) * L)
        masks.append(feather(cv, T(b), T(tip), wpx * 0.95, el, k, ramp=pal))
    # coverts: two rows of short rounded feathers over the bases
    for row, (off, L, cnt) in enumerate(((0.10, 0.28, 7), (0.03, 0.17, 7))):
        for i in range(cnt):
            t = (i + 0.5) / cnt
            b = E[int(t * 0.92 * (len(E) - 1))]
            aa = math.radians(95 - 45 * t)
            tip = (b[0] + math.cos(aa) * L, b[1] + math.sin(aa) * L + off)
            masks.append(feather(cv, T((b[0], b[1] + off * 0.5)), T(tip), wpx * (0.75 - 0.15 * row), el, k * 0.7, ramp=pal, barbs=False))
    arm = cv.poly(ribbon(spline([T(p) for p in edge[:4]], 8), lambda u: span * 0.07 * (1 - u * 0.6) + 0.5))
    ink_line(cv, arm, "#1C2236", 0.3, 1.4, 0.4)
    paint_form(cv, arm, pal, R=span * 0.02, grad=0.5)
    cv.add(arm * (1 - toward(arm, 1.2, LIGHT)), tone(el)[2], 0.5 * k)
    masks.append(arm)
    return union(cv, masks)
