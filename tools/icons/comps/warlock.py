"""术士 Warlock. Black / toxic-green keyed bar: curse green, bone and a dusky void violet, steel trim.
The bar's one off-key accent is the key's `cool` violet rim light, on the ultimate 死亡之门 only.

Value plan:
  atk1              the cane low-left on a diagonal, a dark shadow-bolt orb leaving its crook to the top right   [cane]
  soul_strike       a bone skull blasted straight up inside a vertical green column, its soul-flame torn off it
  bind_spell        dark iron chains rising from a glowing ground seal and coiling into a tight helix
  curse_arrow       five barbed curse arrows fanning out from the lower left on curving homing trails
  hexagram_prison   a hexagonal cage of void light bars standing on a six-point floor seal (tall prism)
  chaotic_rain      a heavy dark cloud mass on top, crossed slanting rain falling into swirling puddles
  grasping_ghosts   a ragged pale ghost flying left to right, clawed arms reaching, green life motes drained in
  deaths_door       a great bone-and-stone arch, its doors swung open on a violet vortex, tentacles reaching out
"""
import math

import numpy as np

from painter import *  # noqa: F401,F403

GREEN = "#7CFF6B"


def _chain(cv, path, size, el, back=GREEN, k=1.0, edge_every=2):
    """a run of iron chain links along a polyline: face-on rings alternating with edge-on bars"""
    sp = spline(path, 16)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(sp, axis=0), axis=1))]
    step = size * 1.35
    s = 0.0
    i = 0
    masks = []
    while s < L[-1]:
        p = np.array([np.interp(s, L, sp[:, 0]), np.interp(s, L, sp[:, 1])])
        j = min(len(sp) - 2, int(np.searchsorted(L, s)))
        d = sp[j + 1] - sp[max(0, j - 1)]
        d = d / (np.linalg.norm(d) + 1e-9)
        ang = math.degrees(math.atan2(d[1], d[0]))
        H = H_affine(p, ang, 1.0)
        if i % edge_every == 0:
            t = np.linspace(0, 2 * math.pi, 32)
            outer = cv.poly(xf(H, np.c_[np.cos(t) * size, np.sin(t) * size * 0.62]))
            inner = cv.poly(xf(H, np.c_[np.cos(t) * size * 0.62, np.sin(t) * size * 0.26]))
            m = np.clip(outer - inner, 0, 1)
        else:
            m = cv.poly(xf(H, [(-size * 1.0, -size * 0.17), (size * 1.0, -size * 0.17), (size * 1.0, size * 0.17), (-size * 1.0, size * 0.17)]))
        material(cv, m, "darksteel", R=size * 0.25, lw=(0.3, 1.4), back=back, back_k=0.8 * k)
        masks.append(m)
        s += step
        i += 1
    return union(cv, masks)


def _skull(cv, c, s, ang, el, back=GREEN):
    """a cranium without the jaw (no teeth): domed skull, deep sockets, nasal notch, cheekbones"""
    H = H_affine(c, ang, s)
    dome = cv.poly(xf(H, closed_spline([(-0.55, -0.05), (-0.45, -0.55), (0.0, -0.78), (0.48, -0.58), (0.58, -0.08),
                                        (0.44, 0.28), (0.30, 0.52), (-0.28, 0.52), (-0.44, 0.30)], 8)))
    ink_line(cv, dome, "#1A1006", 0.35, 2.0, 0.35)
    material(cv, dome, "bone", R=s * 0.35, line=False, grad=0.5, back=back, back_k=0.7)
    for sx in (-1, 1):
        sock = cv.poly(xf(H, closed_spline([(sx * 0.08, 0.02), (sx * 0.20, -0.12), (sx * 0.38, -0.08), (sx * 0.40, 0.10),
                                            (sx * 0.24, 0.22), (sx * 0.10, 0.16)], 6)))
        cv.paint(blur(sock, 0.8), "#120A04", 0.95)
        cv.paint(sock, "#050302", 0.9)
        e = xf(H, [(sx * 0.24, 0.06)])[0]
        cv.add(blur(cv.ellipse(e[0], e[1], s * 0.06), 1.5) * sock, GREEN, 1.0)
    nose = cv.poly(xf(H, [(0.0, 0.20), (0.08, 0.38), (-0.08, 0.38)]))
    cv.paint(nose, "#120A04", 0.95)
    brow = cv.poly(xf(H, ribbon(spline([(-0.42, -0.16), (-0.2, -0.22), (0.0, -0.14), (0.2, -0.22), (0.42, -0.16)], 6), [0.06] * 6))) * dome
    cv.paint(brow, "#FFF8EA", 0.45)
    crack = stroke(cv, xf(H, [(0.12, -0.70), (0.20, -0.52), (0.14, -0.40), (0.24, -0.28)]), s * 0.035, s * 0.01) * dome
    cv.paint(crack, "#3A2610", 0.9)
    return dome


def _cane(cv, butt, top, n, el):
    """手杖: a black lacquer cane with steel bands, a hooked crook, a small bone skull knob on the bend"""
    butt, top = np.array(butt, float), np.array(top, float)
    d = (top - butt) / np.linalg.norm(top - butt)
    nv = np.array([-d[1], d[0]])
    shaft = cv.poly(ribbon([butt, top], [n * 0.028, n * 0.036]))
    hook_pts = [top - d * n * 0.02, top + d * n * 0.08, top + d * n * 0.13 - nv * n * 0.05, top + d * n * 0.10 - nv * n * 0.12,
                top + d * n * 0.03 - nv * n * 0.13, top - nv * n * 0.10]
    hook = cv.poly(ribbon(spline(hook_pts, 8), lambda u: n * (0.036 - 0.018 * u)))
    allm = union(cv, [shaft, hook])
    ink_line(cv, allm, "#020302", 0.4, 2.0, 0.4)
    ang = math.degrees(math.atan2(d[1], d[0]))
    material(cv, shaft, "lacquer", R=n * 0.012, line=False, streak_ang=ang, back=GREEN, back_k=0.6)
    material(cv, hook, "lacquer", R=n * 0.012, line=False, back=GREEN, back_k=0.6)
    for t in (0.05, 0.55, 0.92):
        p = butt + (top - butt) * t
        b = cv.poly(ribbon([p - d * n * 0.012, p + d * n * 0.012], [n * 0.046] * 2))
        material(cv, b, "steel", R=n * 0.008, lw=(0.2, 1.0))
    _skull(cv, top + d * n * 0.07 - nv * n * 0.01, n * 0.07, ang + 90, el)
    return allm


def _tentacle(cv, pts, w, el, back=GREEN, k=1.0, curl=1.0, suckers=True):
    """a tapering tentacle with a curled tip and one row of pale suckers on its underside"""
    path = curl_tip(pts, 1.0, curl)
    sp = spline(path, 10)
    m = cv.poly(ribbon(sp, lambda u: w * (1 - u) ** 1.3 + 0.4))
    ink_line(cv, m, "#020104", 0.35, 1.8, 0.3)
    paint_form(cv, m, ["#0A0614", "#241838", "#4A3466", "#8068A8"], R=w * 0.4, grad=0.5)
    cv.add(m * (1 - toward(m, 1.8, LIGHT)), back, 1.0 * k)
    if suckers:
        d = np.gradient(sp, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nr = np.c_[-d[:, 1], d[:, 0]] * curl
        for i in range(3, int(len(sp) * 0.7), 4):
            ww = w * (1 - i / len(sp)) ** 1.3
            p = sp[i] + nr[i] * ww * 0.30
            su = cv.ellipse(p[0], p[1], max(0.6, ww * 0.20), max(0.5, ww * 0.14))
            paint_form(cv, su * m, ["#5A4878", "#B8A6D8", "#E6DCF6"], R=max(0.5, ww * 0.06), grad=0.4)
            cv.paint(cv.ellipse(p[0], p[1], max(0.3, ww * 0.07)) * m, "#2A1E40", 0.8)
    return m


@skill("warlock.atk1", tone="curse")
def atk1(cv, rng, el):
    """the cane (skull-knobbed crook) low left; a dark shadow bolt wreathed in green flame flies off it to the top right"""
    n = cv.n
    orb_c = np.array([n * 0.68, n * 0.32])
    back_d = np.array([-0.62, 0.78])
    ground(cv, el, [], focus=orb_c, focus_r=0.5, focus_k=0.6, wash=-40, rng=rng)
    trail(cv, [(n * 0.40, n * 0.48), (n * 0.52, n * 0.42), orb_c + back_d * n * 0.08], 1.0, n * 0.14, el, 0.7, core_k=0.4)
    _cane(cv, (n * 0.04, n * 1.04), (n * 0.38, n * 0.50), n, el)
    # flame tongues streaming back from the bolt
    for i in range(7):
        a = math.atan2(back_d[1], back_d[0]) + rng.uniform(-0.75, 0.75)
        d = np.array([math.cos(a), math.sin(a)])
        nv = np.array([-d[1], d[0]])
        p0 = orb_c + d * n * 0.08
        L = n * rng.uniform(0.16, 0.30)
        p1 = p0 + d * L * 0.5 + nv * n * rng.uniform(-0.04, 0.04)
        p2 = p0 + d * L + nv * n * rng.uniform(-0.06, 0.06)
        fm = cv.poly(ribbon(spline([p0, p1, p2], 6), lambda u: n * 0.07 * (1 - u) ** 1.2 + 0.4))
        light_form(cv, fm, el, 0.8, R=n * 0.015, glow_r=4, lw=(0.25, 1.2))
    orb = cv.ellipse(orb_c[0], orb_c[1], n * 0.15)
    glow(cv, orb, GREEN, 12, 0.9)
    ink_line(cv, orb, "#0E2A08", 0.4, 2.2, 0.4)
    paint_form(cv, orb, ["#010201", "#050C05", "#0E220C", "#1E4012"], R=n * 0.07, grad=0.4)
    for i in range(6):   # crackling veins of curse light across the dark sphere
        a = rng.uniform(0, 2 * math.pi)
        p = [orb_c + np.array([math.cos(a), math.sin(a)]) * n * 0.02]
        for j in range(3):
            a += rng.uniform(-0.8, 0.8)
            p.append(p[-1] + np.array([math.cos(a), math.sin(a)]) * n * 0.045)
        v = stroke(cv, p, n * 0.014, n * 0.003, n=3) * orb
        cv.add(blur(v, 0.8), GREEN, 0.8)
        cv.add(v, "#EFFFD6", 0.5)
    rim = orb * (1 - toward(orb, n * 0.025, -LIGHT))
    cv.add(blur(rim, 1.0), GREEN, 0.9)
    hot_core(cv, orb_c[0], orb_c[1], el, 2.0, 1.0, star_len=12)


@skill("warlock.soul_strike", tone="curse")
def soul_strike(cv, rng, el):
    n = cv.n
    col_m = cv.poly([(n * 0.36, n * 1.0), (n * 0.64, n * 1.0), (n * 0.58, 0), (n * 0.42, 0)])
    ground(cv, el, [(col_m, 1)], focus=(n * 0.5, n * 0.30), focus_r=0.5, focus_k=0.6, wash=-90, rng=rng)
    # the blast column: streaky soft light rising from a ground ring
    for i in range(9):
        x = n * (0.5 + rng.uniform(-0.12, 0.12))
        light_streak(cv, (x, n * 0.98), (x + rng.uniform(-0.03, 0.03) * n, n * rng.uniform(0.02, 0.3)), n * rng.uniform(0.02, 0.05), el, 0.55)
    soft_light(cv, cv.poly([(n * 0.44, n * 0.95), (n * 0.56, n * 0.95), (n * 0.53, n * 0.05), (n * 0.47, n * 0.05)]), el, 0.5, R=n * 0.04, glow_r=10)
    shock_ring(cv, np.array([n * 0.5, n * 0.88]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * 0.34, n * 0.07, n * 0.025, el, 0.9)
    for (x, y, s, a) in ((0.20, 0.80, 0.05, 20), (0.80, 0.74, 0.06, -30), (0.28, 0.62, 0.035, 60), (0.74, 0.56, 0.03, 10)):
        stone_chip(cv, rng, n * x, n * y, n * s, a, el, hot_dir=(0.0, 1.0), trail=(0.0, -1.0))
    # the soul-flame torn upward off the skull
    fl = cv.poly(closed_spline([(n * 0.42, n * 0.40), (n * 0.40, n * 0.26), (n * 0.46, n * 0.12), (n * 0.50, n * 0.02), (n * 0.53, n * 0.14),
                                (n * 0.60, n * 0.22), (n * 0.60, n * 0.36), (n * 0.52, n * 0.44)], 6))
    light_form(cv, fl, el, 1.0, R=n * 0.05, glow_r=10, lw=(0.3, 1.6))
    _skull(cv, (n * 0.50, n * 0.58), n * 0.27, -14, el)
    hot_core(cv, n * 0.50, n * 0.30, el, 2.4, 1.0, star_len=14)


@skill("warlock.bind_spell", tone="curse")
def bind_spell(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.50, n * 0.84])
    ground(cv, el, [], focus=(n * 0.5, n * 0.62), focus_r=0.55, focus_k=0.9, wash=-70, rng=rng)
    cv.add(blur(cv.ellipse(n * 0.5, n * 0.80, n * 0.36, n * 0.12), 10), tone(el)[1], 0.6)
    # ground seal: two rings and six short spokes
    for rx, w in ((0.42, 0.022), (0.30, 0.014)):
        shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * rx, n * rx * 0.26, n * w, el, 0.9)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        p0 = c + np.array([math.cos(a) * n * 0.30, math.sin(a) * n * 0.078])
        p1 = c + np.array([math.cos(a) * n * 0.42, math.sin(a) * n * 0.11])
        soft_light(cv, stroke(cv, [p0, p1], n * 0.018, n * 0.006), el, 0.8, R=0.8, glow_r=2)
    # two chains rising in a helix (back halves first, dimmer, then the front halves)
    def helix(phase, front):
        pts = []
        for t in np.linspace(0, 1, 40):
            a = phase + t * 2.6 * math.pi
            y = n * (0.84 - 0.74 * t)
            r = n * (0.20 + 0.14 * t)
            z = math.sin(a)
            if (z > 0) == front:
                pts.append((n * 0.5 + math.cos(a) * r, y + z * n * 0.04))
            elif len(pts) > 2:
                yield pts
                pts = []
            else:
                pts = []
        if len(pts) > 2:
            yield pts
    for front, k in ((False, 0.35), (True, 1.0)):
        for ph in (0.0, math.pi):
            for seg in helix(ph, front):
                m = _chain(cv, seg, n * 0.042, el, k=k * 1.6)
                if not front:
                    cv.paint(m, "#020302", 0.45)
    hot_core(cv, c[0], c[1] - n * 0.02, el, 2.4, 1.0, star_len=16)


def _arrow(cv, path, el, w):
    """a curse arrow of green light: barbed head, thin shaft trail, ragged black fletching at the tail"""
    sp = spline(path, 10)
    head = sp[-1]
    d = sp[-1] - sp[-3]
    d = d / (np.linalg.norm(d) + 1e-9)
    nv = np.array([-d[1], d[0]])
    trail(cv, list(sp[: int(len(sp) * 0.62)]), 0.5, w * 1.3, el, 0.7, core_k=0.5)
    # the arrow itself: a black shaft, ragged fletching, a barbed bone head wreathed in green
    i0 = int(len(sp) * 0.55)
    shaft = cv.poly(ribbon(sp[i0:], [w * 0.32] * (len(sp) - i0)))
    tail = sp[i0]
    td = sp[i0 + 1] - tail
    td = td / (np.linalg.norm(td) + 1e-9)
    tn = np.array([-td[1], td[0]])
    fl = []
    for s in (-1, 1):
        fl.append(cv.poly([tail + td * w * 1.8, tail + tn * s * w * 1.0 - td * w * 0.2, tail + tn * s * w * 0.7 - td * w * 0.9, tail]))
    fm = union(cv, fl)
    tip = head + d * w * 2.8
    hm = cv.poly([tip, head + nv * w * 1.1 - d * w * 0.5, head + nv * w * 0.35, head - nv * w * 0.35, head - nv * w * 1.1 - d * w * 0.5])
    glow(cv, hm, GREEN, 6, 0.9)
    material(cv, shaft, "lacquer", R=w * 0.15, lw=(0.2, 1.0), back=GREEN, back_k=0.7)
    material(cv, fm, "lacquer", R=w * 0.2, lw=(0.2, 1.0), back=GREEN, back_k=0.9)
    material(cv, hm, "bone", R=w * 0.4, lw=(0.25, 1.2), back=GREEN, back_k=1.0)
    return tip


@skill("warlock.curse_arrow", tone="curse")
def curse_arrow(cv, rng, el):
    n = cv.n
    src = np.array([n * 0.06, n * 0.92])
    ground(cv, el, [], focus=(n * 0.62, n * 0.40), focus_r=0.6, focus_k=0.5, wash=-35, rng=rng)
    soft_light(cv, cv.ellipse(src[0], src[1], n * 0.10), el, 0.8, R=n * 0.04, glow_r=8)
    tips = []
    for i, (bend, end) in enumerate(((-0.10, (0.30, 0.10)), (-0.05, (0.58, 0.14)), (0.0, (0.82, 0.30)), (0.05, (0.88, 0.56)), (0.08, (0.82, 0.80)))):
        e = np.array(end) * n
        mid = (src + e) / 2 + np.array([-(e - src)[1], (e - src)[0]]) * bend * 2.0
        tips.append(_arrow(cv, [src, mid, e], el, n * 0.042))
    for t in tips[1:4]:
        hot_core(cv, t[0], t[1], el, 1.2, 0.6, star_len=8)
    hot_core(cv, tips[2][0], tips[2][1], el, 2.2, 1.0, star_len=14)


@skill("warlock.hexagram_prison", tone="void")
def hexagram_prison(cv, rng, el):
    n = cv.n
    c = np.array([n * 0.5, n * 0.80])
    rx, ry = n * 0.40, n * 0.13
    top_y = n * 0.18
    ground(cv, el, [], focus=(n * 0.5, n * 0.55), focus_r=0.5, focus_k=0.7, wash=-90, rng=rng)
    verts = [c + np.array([math.cos(math.radians(a)) * rx, math.sin(math.radians(a)) * ry]) for a in range(-90, 270, 60)]
    # violet haze filling the cage, a lit floor disc
    floor = cv.poly([(v[0], v[1]) for v in verts])
    cv.add(blur(floor, 6), tone(el)[1], 0.7)
    haze = cv.poly([(n * 0.12, n * 0.80), (n * 0.12, top_y), (n * 0.88, top_y), (n * 0.88, n * 0.80)])
    cv.add(blur(haze, 10) * smoothstep(0.2, 0.85, cv.grid()[1] / n), tone(el)[0], 0.9)
    # floor seal: the two triangles of the six-point star + ring
    for tri in ((0, 2, 4), (1, 3, 5)):
        pts = [verts[i] for i in tri] + [verts[tri[0]]]
        for a_, b_ in zip(pts[:-1], pts[1:]):
            soft_light(cv, stroke(cv, [a_, b_], n * 0.024, n * 0.024), el, 1.0, R=1.0, glow_r=4)
    shock_ring(cv, c, np.array([1.0, 0.0]), np.array([0.0, 1.0]), rx * 1.08, ry * 1.08, n * 0.02, el, 0.9)
    # light bars at the six vertices, back ones dimmer; lintel ring on top
    order = sorted(range(6), key=lambda i: verts[i][1])
    for i in order:
        v = verts[i]
        back = v[1] < c[1] - 1
        tv = np.array([v[0], top_y + (v[1] - c[1]) * 0.6])
        bar = cv.poly(ribbon([v, (v + tv) / 2, tv], [n * 0.05, n * 0.04, n * 0.034]))
        light_form(cv, bar, el, 0.55 if back else 1.0, R=n * 0.016, glow_r=6, lw=(0.3, 1.5), value=0.55 if back else 1.0)
    for i in range(6):
        a, b = verts[i], verts[(i + 1) % 6]
        ta = np.array([a[0], top_y + (a[1] - c[1]) * 0.6])
        tb = np.array([b[0], top_y + (b[1] - c[1]) * 0.6])
        front = (a[1] + b[1]) / 2 > c[1]
        for t in (0.33, 0.66):
            p0 = a + (ta - a) * t
            p1 = b + (tb - b) * t
            soft_light(cv, stroke(cv, [p0, p1], n * 0.012, n * 0.012), el, 0.7 if front else 0.35, R=0.6, glow_r=2)
        soft_light(cv, stroke(cv, [ta, tb], n * 0.026, n * 0.026), el, 0.9 if front else 0.5, R=1.0, glow_r=3)
    # seal sigil hanging in the middle: a dark hexagonal plate with a lit rim
    hc = np.array([n * 0.5, n * 0.50])
    hx = cv.poly([hc + np.array([math.cos(math.radians(a)), math.sin(math.radians(a))]) * n * 0.07 for a in range(0, 360, 60)])
    material(cv, hx, "lacquer", R=n * 0.02, lw=(0.3, 1.4), back=tone(el)[2], back_k=0.9)
    hot_core(cv, hc[0], hc[1], el, 2.2, 1.0, star_len=14)


@skill("warlock.chaotic_rain", tone="curse")
def chaotic_rain(cv, rng, el):
    n = cv.n
    ground(cv, el, [], focus=(n * 0.5, n * 0.80), focus_r=0.55, focus_k=0.6, wash=-60, rng=rng)
    X, Y = cv.grid()
    # puddles with confusion swirls
    for (x, y, r) in ((0.28, 0.86, 0.13), (0.70, 0.88, 0.15)):
        shock_ring(cv, np.array([n * x, n * y]), np.array([1.0, 0.0]), np.array([0.0, 1.0]), n * r, n * r * 0.3, n * 0.012, el, 0.6)
        pts = [(n * x + math.cos(a) * n * r * (0.15 + 0.6 * a / 12.0), n * y + math.sin(a) * n * r * 0.3 * (0.15 + 0.6 * a / 12.0))
               for a in np.linspace(0, 12, 30)]
        soft_light(cv, cv.poly(ribbon(pts, lambda u: n * 0.012 * (1 - u * 0.5))), el, 0.9, R=0.8, glow_r=3)
    # crossed rain: two slant directions
    for i in range(30):
        x = rng.uniform(0.05, 0.95) * n
        y = rng.uniform(0.32, 0.80) * n
        s = 1 if i % 2 else -1
        L = rng.uniform(0.08, 0.16) * n
        d = np.array([0.35 * s, 1.0])
        d = d / np.linalg.norm(d)
        light_streak(cv, (x, y), (x + d[0] * L, y + d[1] * L), n * rng.uniform(0.008, 0.014), el, rng.uniform(0.6, 1.0))
    # the cloud: heavy, painted, dark masses with a green underlit belly
    cl = np.zeros((cv.w, cv.w), np.float32)
    for (x, y, r) in ((0.16, 0.20, 0.17), (0.38, 0.12, 0.20), (0.62, 0.14, 0.19), (0.84, 0.22, 0.17), (0.28, 0.30, 0.14),
                      (0.52, 0.30, 0.16), (0.74, 0.32, 0.13), (0.50, 0.04, 0.16)):
        np.maximum(cl, cv.ellipse(n * x, n * y, n * r, n * r * 0.85), out=cl)
    ink_line(cv, cl, "#010201", 0.4, 2.2, 0.3)
    paint_form(cv, cl, ["#030503", "#0C140A", "#1C2A16", "#34482A"], R=n * 0.05, grad=0.5, tilt=(0.0, -0.3))
    belly = cl * (1 - toward(cl, n * 0.025, (0.0, 1.0)))
    cv.add(blur(belly, 2.0), GREEN, 0.7)
    cv.add(blur(cv.ellipse(n * 0.46, n * 0.40, n * 0.30, n * 0.06), 6) * cl, GREEN, 0.5)   # sickly underglow
    bolt = stroke(cv, [(n * 0.58, n * 0.30), (n * 0.52, n * 0.40), (n * 0.60, n * 0.46), (n * 0.54, n * 0.58)], n * 0.016, n * 0.004, n=3)
    soft_light(cv, bolt, el, 1.0, R=0.8, glow_r=4)
    hot_core(cv, n * 0.56, n * 0.44, el, 1.6, 0.8, star_len=10)


@skill("warlock.grasping_ghosts", tone="bone")
def grasping_ghosts(cv, rng, el):
    """a translucent hooded wraith lunging in from the upper left: one long cowl-and-robe shape streaming back into
    jagged tatters and fading out, sleeves ending in big bony clawed hands grasping right, life motes pulled in"""
    n = cv.n
    ground(cv, "curse", [], focus=(n * 0.74, n * 0.50), focus_r=0.55, focus_k=0.5, wash=-25, rng=rng)
    X, Y = cv.grid()
    ramp = ["#20261A", "#5A6450", "#A8B496", "#E8F2D6"]
    # robe: from the cowl peak back to a ragged zigzag hem at the lower left
    hem = []
    for i in range(9):
        t = i / 8.0
        p = np.array([0.02 + 0.40 * t, 0.50 + 0.46 * t]) if i % 2 == 0 else np.array([0.12 + 0.40 * t, 0.50 + 0.40 * t])
        hem.append(tuple(p * n))
    robe = cv.poly([(n * 0.46, n * 0.12), (n * 0.62, n * 0.16), (n * 0.70, n * 0.36), (n * 0.66, n * 0.60), (n * 0.58, n * 0.78)]
                   + hem[::-1] + [(n * 0.0, n * 0.40), (n * 0.20, n * 0.30)])
    robe = blur(robe, 1.0)
    fade = smoothstep(0.0, 0.5, X / n) * 0.7 + 0.3
    glow(cv, robe, "#9AC888", 10, 0.35)
    ink_line(cv, robe, "#1E2416", 0.3, 1.6, 0.6, a=0.7)
    folds = (0.16 * np.sin((X * 0.75 - Y * 0.65) / n * 16 + cv.noise * 3)).astype(np.float32)
    sl_ = paint_form(cv, robe * fade, ramp, R=n * 0.06, grad=0.8, field=folds)
    hood = cv.poly(closed_spline([(n * 0.42, n * 0.20), (n * 0.50, n * 0.08), (n * 0.66, n * 0.10), (n * 0.74, n * 0.26),
                                  (n * 0.72, n * 0.42), (n * 0.60, n * 0.48), (n * 0.48, n * 0.40)], 8))
    ink_line(cv, hood, "#1E2416", 0.3, 1.8, 0.5)
    paint_form(cv, hood, ramp, R=n * 0.05, grad=0.7)
    hollow = cv.poly(closed_spline([(n * 0.56, n * 0.20), (n * 0.68, n * 0.20), (n * 0.72, n * 0.32), (n * 0.66, n * 0.44),
                                    (n * 0.56, n * 0.38)], 6))
    cv.paint(blur(hollow, 1.2), "#050804", 0.94)
    for (x, y) in ((0.605, 0.29), (0.675, 0.285)):
        e = cv.poly([(n * (x - 0.024), n * (y + 0.006)), (n * x, n * (y - 0.010)), (n * (x + 0.020), n * (y + 0.002)), (n * x, n * (y + 0.012))])
        cv.add(blur(e, 1.6), GREEN, 0.9)
        cv.add(e, "#EFFFD6", 0.9)
    for (sh, mid, wr, rot) in (((0.56, 0.56), (0.66, 0.64), (0.76, 0.66), 10), ((0.64, 0.46), (0.72, 0.42), (0.80, 0.38), -15)):
        sh, mid, wr = (np.array(p) * n for p in (sh, mid, wr))
        sl_m = cv.poly(ribbon(spline([sh, mid, wr], 6), lambda u: n * (0.10 - 0.045 * u)))
        ink_line(cv, sl_m, "#1E2416", 0.3, 1.4, 0.5)
        paint_form(cv, sl_m, ramp, R=n * 0.02, grad=0.6)
        palm = cv.ellipse(wr[0] + n * 0.03, wr[1], n * 0.04, n * 0.035)
        parts = [palm]
        for k, (a, L) in enumerate(((-70, 0.11), (-35, 0.15), (-5, 0.16), (25, 0.15), (60, 0.10))):
            ar = math.radians(a + rot)
            d = np.array([math.cos(ar), math.sin(ar)])
            b0 = wr + np.array([n * 0.03, 0]) + d * n * 0.03
            p1 = b0 + d * n * L * 0.55
            p2 = p1 + np.array([math.cos(ar + 0.7), math.sin(ar + 0.7)]) * n * L * 0.45
            parts.append(stroke(cv, [b0, p1, p2], n * 0.024, n * 0.004, n=4))
        hand = union(cv, parts)
        glow(cv, hand, GREEN, 4, 0.4)
        material(cv, hand, "bone", R=n * 0.008, lw=(0.25, 1.2), back=GREEN, back_k=0.7)
    tgt = np.array([n * 0.93, n * 0.54])
    for i in range(16):
        p0 = np.array([rng.uniform(0.90, 1.04) * n, rng.uniform(0.20, 0.98) * n])
        p1 = p0 + (tgt - p0) * rng.uniform(0.35, 0.7)
        light_streak(cv, p0, p1, n * 0.014, "curse", 0.8)
        hot_core(cv, p1[0], p1[1], "curse", 0.7, 0.6, star=False)
    hot_core(cv, tgt[0], tgt[1], "curse", 1.8, 0.9, star_len=12)


@skill("warlock.deaths_door", tone="void")
def deaths_door(cv, rng, el):
    n = cv.n
    cool = KEY["cool"]
    c = np.array([n * 0.5, n * 0.52])
    ground(cv, el, [], focus=c, focus_r=0.45, focus_k=0.6, ink="#030206", wash=-90, rng=rng)
    X, Y = cv.grid()
    # the opening: pointed arch, a spiral vortex inside
    arch_pts = [(n * 0.26, n * 0.98), (n * 0.26, n * 0.44)] + [tuple(p) for p in arc_pts(n * 0.50, n * 0.44, n * 0.24, 180, 270, 10, ry=n * 0.30)] + \
               [tuple(p) for p in arc_pts(n * 0.50, n * 0.44, n * 0.24, 270, 360, 10, ry=n * 0.30)] + [(n * 0.74, n * 0.44), (n * 0.74, n * 0.98)]
    opening = cv.poly(arch_pts)
    dx, dy = X - c[0], Y - c[1]
    r = np.sqrt(dx * dx + dy * dy) / n
    ang = np.arctan2(dy, dx)
    spiral = (0.5 + 0.5 * np.sin(ang * 4 - r * 30.0)) ** 3 * smoothstep(0.34, 0.03, r)
    cv.paint(opening, "#06030C")
    cv.add(blur(spiral.astype(np.float32), 1.6) * opening, tone(el)[1], 1.1)
    cv.add(blur(spiral.astype(np.float32) * smoothstep(0.2, 0.05, r), 0.6) * opening, GREEN, 0.6)
    cv.add(np.exp(-(r / 0.10) ** 2) * opening, cool, 0.9)
    # frame: stone jambs and an arch with bone inlay; doors swung open (in perspective) on each side
    jamb = np.clip(dilate(opening, n * 0.07) - opening, 0, 1) * (Y < n * 0.99)
    material(cv, jamb, "stone", R=n * 0.03, lw=(0.35, 2.0), back=cool, back_k=0.8, spec=False)
    for k in range(9):   # bone voussoirs around the arch
        a = math.radians(180 + k * 22.5)
        p = np.array([n * 0.50 + math.cos(a) * n * 0.275, n * 0.44 + math.sin(a) * n * 0.335])
        b = cv.ellipse(p[0], p[1], n * 0.028, n * 0.022)
        material(cv, b, "bone", R=n * 0.01, lw=(0.2, 1.0))
    key_s = cv.poly([(n * 0.46, n * 0.06), (n * 0.54, n * 0.06), (n * 0.52, n * 0.16), (n * 0.48, n * 0.16)])
    material(cv, key_s, "bone", R=n * 0.02, lw=(0.3, 1.3))
    for s in (-1, 1):
        x0 = n * (0.5 + s * 0.31)
        x1 = n * (0.5 + s * 0.47)
        door = cv.poly([(x0, n * 0.40), (x1, n * 0.30), (x1, n * 1.0), (x0, n * 0.98)])
        material(cv, door, "darksteel", R=n * 0.03, lw=(0.35, 2.0), back=cool, back_k=0.6)
        for yy in (0.52, 0.80):
            band = cv.poly([(x0, n * (yy - 0.02)), (x1, n * (yy - 0.05)), (x1, n * (yy - 0.02)), (x0, n * (yy + 0.01))]) * door
            material(cv, band, "steel", R=n * 0.006, line=False)
    # tentacles reaching out of the gate toward the viewer
    for pts, w, cs in ((((0.46, 0.56), (0.34, 0.50), (0.20, 0.58), (0.10, 0.48), (0.10, 0.34)), 0.075, 1.0),
                       (((0.55, 0.58), (0.68, 0.52), (0.80, 0.62), (0.92, 0.54), (0.90, 0.40)), 0.075, -1.0),
                       (((0.47, 0.64), (0.36, 0.76), (0.18, 0.74), (0.10, 0.86)), 0.07, -1.0),
                       (((0.54, 0.66), (0.62, 0.82), (0.80, 0.84), (0.88, 0.94)), 0.07, 1.0)):
        _tentacle(cv, [(n * x, n * y) for x, y in pts], n * w, el, back=cool, k=0.9, curl=cs)
    hot_core(cv, c[0], c[1], el, 2.4, 1.0, star_len=16)
