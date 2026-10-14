"""战斗法师 Battle Mage (一叶之秋 / 却邪) - the reference bar, ported from lookdev/tools/icon_painter.py (iteration 4).

Value plan (one big greyscale shape each): diagonal stab into a ring | vertical column | horizontal jaws |
dark hand mass | elliptical ring | red diagonal dragon | horizontal dragon | gold S-coil.
The lance appears in 4 of 8: 突刺, 天击, 怒龙穿心, 伏龙翔天. The ultimate carries the bar's one cool accent.
"""
from painter import *  # noqa: F401,F403


@skill("battle_mage.lance_1", tone="white")
def thrust(cv, rng, el):
    """突刺: a 3/4 forward thrust, the blade foreshortened toward the viewer; a cone of speed lines converging on
    the point and an air-pierce shock ring at the tip. Reads as 'stab' at 32 px: one diagonal into one ring."""
    n = cv.n
    butt = np.array([n * -0.20, n * -0.16])
    tip = np.array([n * 0.63, n * 0.60])
    dv = (tip - butt) / np.linalg.norm(tip - butt)
    pv = np.array([-dv[1], dv[0]])
    band = cv.poly([butt + pv * n * 0.30, tip + pv * n * 0.34 + dv * n * 0.3, tip - pv * n * 0.34 + dv * n * 0.3, butt - pv * n * 0.30])
    ground(cv, el, [(band, 1)], focus=tip, focus_r=0.42, focus_k=0.9, wash=math.degrees(math.atan2(dv[1], dv[0])), rng=rng)
    # vapour cone: soft white cone opening backward from the point
    cone = cv.poly([tip + dv * n * 0.02, tip - dv * n * 0.42 + pv * n * 0.24, tip - dv * n * 0.50, tip - dv * n * 0.42 - pv * n * 0.24])
    cv.add(blur(cone, 9), tone(el)[1], 0.45)
    # cone of speed lines converging on the point from behind (few, varied, soft)
    for o, L, w in ((-0.95, 0.9, 0.010), (-0.55, 1.0, 0.016), (-0.25, 0.7, 0.009), (0.3, 0.85, 0.013), (0.62, 1.0, 0.018), (1.0, 0.75, 0.010)):
        far = tip - dv * n * L + pv * o * n * 0.62
        near = tip - dv * n * 0.16 + pv * o * n * 0.10
        light_streak(cv, far, near, n * w, el, 0.75, soft=1.8)
    H = lance_persp(butt, tip, n * 0.19, n * 0.075)
    draw_lance(cv, H, el, tassel=False)
    # air-pierce shock rings around the point, perpendicular to the thrust
    rc = tip + dv * n * 0.05
    shock_ring(cv, rc, pv, dv, n * 0.24, n * 0.085, n * 0.04, el, 1.0)
    shock_ring(cv, rc + dv * n * 0.10, pv, dv, n * 0.36, n * 0.12, n * 0.022, el, 0.55)
    hot_core(cv, tip[0] + dv[0] * 2, tip[1] + dv[1] * 2, el, 3.0, 1.2, star_len=20, ang=math.degrees(math.atan2(dv[1], dv[0])))


@skill("battle_mage.sky_strike", tone="gold")
def sky_strike(cv, rng, el):
    """天击: the launcher. The lance drives up from the bottom-left into a soft volumetric column of light; the
    enemy's breastplate bursts into curved gold-trimmed plate fragments flung into the sky."""
    n = cv.n
    hit = np.array([n * 0.60, n * 0.30])
    lowland = cv.poly([(0, n * 0.80), (n * 0.3, n * 0.74), (n * 0.7, n * 0.82), (n, n * 0.76), (n, n), (0, n)])
    ground(cv, el, [(lowland, 1)], focus=hit, focus_r=0.45, focus_k=0.8, wash=-88, rng=rng)
    # volumetric light column: gaussian across, widening and brightening upward, soft god-ray streaks
    pal = tone(el)
    X, Y = cv.grid()
    yy = np.clip(Y / n, 0, 1)
    cx = hit[0] + (yy - 0.3) * n * -0.04
    wcol = n * (0.10 + 0.14 * (1 - yy))
    colm = np.exp(-((X - cx) / wcol) ** 2) * (0.35 + 0.65 * smoothstep(1.0, 0.05, yy))
    rays = streak_field(cv.w, -90, 40, 3, cv.seed())
    cv.add(colm * (0.7 + 0.5 * rays), pal[1], 0.55)
    cv.add(colm ** 3 * (0.6 + 0.6 * rays), pal[2], 0.45)
    core = np.exp(-((X - cx) / (wcol * 0.25)) ** 2) * smoothstep(0.9, 0.0, yy) * smoothstep(0.05, 0.3, yy)
    cv.add(core, pal[3], 0.35)
    for i in range(14):  # light motes rising in the column
        x = hit[0] + rng.normal(0, n * 0.09)
        y = rng.uniform(0.05, 0.75) * n
        cv.add(blur(cv.ellipse(x, y, rng.uniform(0.6, 1.4)), 0.6), pal[3], 0.9)
    H = lance_H((n * 0.22, n * 1.16), (hit[0] + n * 0.04, hit[1] - n * 0.17), 1.25)
    draw_lance(cv, H, el, tassel=True)
    tipp = xf(H, [(1.0, 0.0)])[0]
    flare_spikes(cv, tipp[0], tipp[1] + n * 0.03, [(-90, 1.0), (-140, 0.55), (-38, 0.6), (200, 0.4), (-8, 0.35)], n * 0.04, n * 0.32, n * 0.03, el, 0.8)
    hot_core(cv, tipp[0], tipp[1] + n * 0.02, el, 2.8, 1.1)
    for (x, y, s, a, tr) in ((0.83, 0.18, 0.24, 22, (0.4, -1)), (0.30, 0.13, 0.17, -38, (-0.5, -1)), (0.88, 0.48, 0.12, 64, (1, -0.3)),
                             (0.40, 0.40, 0.09, -70, (-0.6, -0.8))):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 1.0, trail=np.array(tr) / np.linalg.norm(tr))


@skill("battle_mage.dragon_tooth", tone="ember")
def dragon_tooth(cv, rng, el):
    """龙牙: the jaws alone. Upper and lower dragon jaws of ember light snap shut on one hot point; narrow curved
    ivory fangs, scale rows on the jaw plates, the dark maw between them. Horizontal value structure."""
    n = cv.n
    snap = np.array([n * 0.86, n * 0.50])
    ground(cv, el, [], focus=snap, focus_r=0.45, focus_k=0.8, wash=8, rng=rng)
    pal = tone(el)
    # maw glow between the jaws
    maw = cv.poly([(n * -0.1, n * 0.30), (n * 0.50, n * 0.40), snap, (n * 0.50, n * 0.62), (n * -0.1, n * 0.72)])
    cv.paint(blur(maw, 4), "#1A0406", 0.8)
    cv.add(blur(maw, 10) * blur(cv.ellipse(snap[0] - n * 0.2, snap[1], n * 0.3, n * 0.12), 8), KEY["accent"], 0.8)
    jaws = []
    for sgn, path, ws in ((-1, [(-0.08, 0.12), (0.30, 0.16), (0.62, 0.30), (0.88, 0.47)], [0.36, 0.28, 0.16, 0.035]),
                          (1, [(-0.08, 0.90), (0.30, 0.86), (0.60, 0.70), (0.86, 0.53)], [0.30, 0.22, 0.12, 0.03])):
        P = spline([(n * x, n * y) for x, y in path], 12)
        W = np.interp(np.linspace(0, 1, len(P)), np.linspace(0, 1, len(ws)), np.array(ws) * n)
        m = cv.poly(ribbon(P, W))
        jaws.append((sgn, P, W, m))
    # fangs first (they sit behind the jaw rims)
    for sgn, P, W, m in jaws:
        d = np.gradient(P, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nr = np.c_[-d[:, 1], d[:, 0]]
        inner = -sgn  # inner side points toward the mouth
        sel = (0.24, 0.44, 0.62, 0.76) if sgn < 0 else (0.30, 0.50, 0.68)
        for j, t in enumerate(sel):
            i = int(t * (len(P) - 1))
            if nr[i][1] * inner < 0:
                nr_i = -nr[i]
            else:
                nr_i = nr[i]
            base = P[i] + nr_i * W[i] * 0.40
            L = n * (0.17 - 0.03 * j) * (1.0 if sgn < 0 else 0.8)
            tipf = base + nr_i * L - d[i] * L * 0.30
            mid = base + nr_i * L * 0.55 - d[i] * L * 0.05
            fm = cv.poly(ribbon(spline([base, mid, tipf], 6), lambda u: n * 0.042 * (1 - u) ** 0.85 + 0.25))
            material(cv, fm, "bone", R=n * 0.012, lw=(0.25, 1.3))
    for sgn, P, W, m in jaws:
        light_form(cv, m, el, 1.0, R=n * 0.05, glow_r=6, lw=(0.35, 2.4), tilt=(0.0, 0.25 * sgn))
        d = np.gradient(P, axis=0)
        d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
        nr = np.c_[-d[:, 1], d[:, 0]]
        if np.mean(nr[:, 1]) * sgn < 0:
            nr = -nr
        # gum ridge on the inner edge (darker, the mouth's shadow)
        gum = cv.poly(ribbon(P - nr * W[:, None] * 0.36, W * 0.22)) * m
        cv.paint(blur(gum, 0.8), mix(pal[0], pal[1], 0.55), 0.85)
        # scale rows on the outer jaw plate
        for i in range(3, int(len(P) * 0.8), 2):
            for o in (0.04, 0.20, 0.36):
                c = P[i] + nr[i] * W[i] * (o + (0.08 if i % 4 == 1 else 0))
                r = W[i] * 0.085
                sc = cv.ellipse(c[0], c[1], r)
                cut = cv.ellipse(c[0] + d[i][0] * r * 0.6, c[1] + d[i][1] * r * 0.6, r * 0.95)
                cv.paint(np.clip(sc - cut, 0, 1) * m, mix(pal[1], pal[2], 0.2), 0.7)
        # lip ridge
        lp = P + nr * W[:, None] * 0.18
        cv.paint(cv.poly(ribbon(lp[2:-3], lambda u: max(0.4, n * 0.012 * (1 - u)))) * m, mix(pal[2], pal[3], 0.5), 0.6)
    hot_core(cv, snap[0], snap[1], el, 3.2, 1.25, star_len=22)
    flare_spikes(cv, snap[0], snap[1], [(-60, 0.6), (0, 1.0), (60, 0.6), (180, 0.4)], n * 0.03, n * 0.18, n * 0.02, el, 0.7)


@skill("battle_mage.falling_flower_palm", tone="crimson")
def falling_flower_palm(cv, rng, el):
    """落花掌: an open-palm strike thrust toward the viewer, 3/4. The palm centre blazes; notched blossom petals with
    trails stream outward along the strike direction; two full blossoms with stamen clusters."""
    n = cv.n
    diag = cv.poly([(0, n * 0.15), (n * 0.55, 0), (n, n * 0.40), (n, n * 0.85), (n * 0.4, n), (0, n * 0.75)])
    ground(cv, el, [(diag, 1)], focus=(n * 0.48, n * 0.40), focus_r=0.5, focus_k=0.9, wash=-35, rng=rng)
    # far petals: small, dark, soft
    for i in range(9):
        x, y = rng.uniform(n * 0.05, n * 0.95), rng.uniform(n * 0.03, n * 0.55)
        s = rng.uniform(n * 0.05, n * 0.08)
        m = blur(cv.poly(petal_pts(x, y, s, rng.uniform(-80, 20), rng.uniform(0.5, 0.9))), rng.uniform(1.0, 2.0))
        cv.paint(m, mix("#4A0A18", "#C2202C", rng.uniform(0.2, 0.45)), 0.85)
    # 3/4 open palm: the wrist far (lower-left), the hand opening toward the viewer, upper-right edge nearer
    src = [(-0.55, -1.0), (0.55, -1.0), (0.55, 0.30), (-0.55, 0.30)]
    dst = [(n * 0.08, n * 0.04), (n * 0.84, n * -0.06), (n * 0.86, n * 1.02), (n * 0.12, n * 0.90)]
    H = H_quad(src, dst)
    pc = xf(H, [(0.0, -0.28)])[0]
    shock_ring(cv, pc, np.array([0.96, -0.28]), np.array([0.28, 0.96]), n * 0.44, n * 0.30, n * 0.035, el, 0.75, -230, 50)
    allm, palm = gauntlet_palm(cv, H, el)
    # palm centre: a blazing qi seal (soft light, no glyph)
    seal = cv.ellipse(pc[0], pc[1], n * 0.085, n * 0.075) * dilate(palm, 1.0)
    soft_light(cv, seal, el, 1.0, R=n * 0.05, glow_r=10, core_k=1.2)
    hot_core(cv, pc[0], pc[1], el, 3.0, 1.0, star_len=14)
    blossom(cv, pc[0] + n * 0.02, pc[1] + n * 0.01, n * 0.14, 12, el, glow_k=0.5)
    # near petals stream OUTWARD from the palm (the strike comes at the viewer): long axis radial, trail behind
    for i, (a_deg, dn) in enumerate([(-115, 0.34), (-88, 0.42), (-62, 0.36), (-40, 0.46), (-18, 0.40), (6, 0.44), (28, 0.36),
                                    (-75, 0.24), (-28, 0.27), (48, 0.30)]):
        a = a_deg + rng.uniform(-6, 6)
        ar = math.radians(a)
        x = pc[0] + math.cos(ar) * dn * n
        y = pc[1] + math.sin(ar) * dn * n
        s = n * rng.uniform(0.085, 0.12) * (0.7 + dn)
        petal(cv, x, y, s, a + rng.uniform(-20, 20), rng.uniform(0.55, 0.95), value=1.0, trail=1.4 if i % 3 == 0 else 0.7)
    blossom(cv, n * 0.86, n * 0.18, n * 0.15, 30, el, glow_k=0.3)


@skill("battle_mage.circle_swing", tone="gold")
def circle_swing(cv, rng, el):
    """圆舞棍: the swing arc alone. A tapered crescent smear sweeping 300 degrees around the wielder, seen at an
    angle: thick and white-hot at the leading edge, dissolving into streaks at the tail; stone debris flung
    outward and a dust ring on the ground."""
    n = cv.n
    pal = tone(el)
    c = np.array([n * 0.50, n * 0.46])
    rot = math.radians(-10)
    u = np.array([math.cos(rot), math.sin(rot)])
    v = np.array([-u[1], u[0]])
    rx, ry = n * 0.40, n * 0.16
    disc = cv.ellipse(c[0], c[1] + n * 0.2, n * 0.46, n * 0.16)
    ground(cv, el, [(disc, 1)], focus=c, focus_r=0.6, focus_k=0.55, wash=-10, rng=rng)
    # ground ring + dust puffs
    gc = c + v * n * 0.26
    shock_ring(cv, gc, u, v, n * 0.44, n * 0.11, n * 0.012, el, 0.35)
    dust = np.zeros((cv.w, cv.w), np.float32)
    for a in range(-20, 200, 22):
        ar = math.radians(a + rng.uniform(-8, 8))
        p = gc + u * math.cos(ar) * n * 0.44 + v * math.sin(ar) * n * 0.11
        r = n * rng.uniform(0.035, 0.06)
        np.maximum(dust, cv.ellipse(p[0], p[1] - r * 0.5, r * 1.6, r), out=dust)
    cv.add(blur(dust, 2.5) * (0.6 + 0.4 * cv.noise2), pal[1], 0.35)
    # the smear: head at +30 deg (front right), tail 300 deg behind it
    th_head, sweep = 30.0, 300.0
    X, Y = cv.grid()
    dx, dy = X - c[0], Y - c[1]
    lx, ly = dx * u[0] + dy * u[1], dx * v[0] + dy * v[1]
    ang = np.degrees(np.arctan2(ly / ry, lx / rx))
    t = ((ang - (th_head - sweep)) % 360) / sweep
    t = np.where(t <= 1.0, t, 0.0)
    rho = np.sqrt((lx / rx) ** 2 + (ly / ry) ** 2)
    front = smoothstep(-0.2, 0.9, np.sin(np.radians(ang)))     # near side of the ellipse is fatter
    width = (0.08 + 0.46 * t ** 1.2) * (0.55 + 0.45 * front)
    inside = smoothstep(width, width * 0.55, 1.0 - rho) * smoothstep(-0.05, 0.02, 1.0 - rho)   # crescent: outer edge on the ring
    head_cap = smoothstep(1.0, 0.985, t)
    m = (inside * (t > 0.003) * head_cap).astype(np.float32)
    streaky = 0.5 + 0.5 * np.sin(rho * 85.0 + cv.noise * 9.0)
    field = np.where(t < 0.62, (streaky ** 2.2) * smoothstep(0.0, 0.62, t) + smoothstep(0.35, 0.62, t) * 0.6, 1.0)
    inten = 0.35 + 0.75 * t ** 1.4
    mm = m * np.clip(field, 0, 1)
    cv.add(blur(m * inten, 7), pal[1], 0.8)
    cv.add(blur(mm * inten, 2.0), pal[2], 1.1)
    cv.add(mm * inten * smoothstep(0.3, 1.0, t), mix(pal[2], pal[3], 0.5), 0.9)
    edge_in = smoothstep(width * 0.6, width * 0.2, 1.0 - rho) * mm
    cv.add(edge_in * inten, pal[3], 0.5)
    # white-hot leading edge: the outermost rim of the last third, thickest at the head
    rimw = 0.06 * smoothstep(0.55, 1.0, t)
    rim = smoothstep(rimw + 0.01, rimw * 0.3, 1.0 - rho) * smoothstep(-0.03, 0.01, 1.0 - rho) * (t > 0.5) * head_cap
    cv.add(blur(rim.astype(np.float32), 0.6), pal[3], 1.3)
    hp = c + u * math.cos(math.radians(th_head)) * rx + v * math.sin(math.radians(th_head)) * ry
    hot_core(cv, hp[0], hp[1], el, 3.0, 1.15, star_len=18)
    # debris flung outward, tangential to the swing
    for a, s in ((-150, 0.07), (-95, 0.05), (-40, 0.065), (100, 0.085), (150, 0.06), (205, 0.075), (62, 0.05)):
        ar = math.radians(a)
        rr = 1.18 + rng.uniform(0, 0.15)
        p = c + u * math.cos(ar) * rx * rr + v * math.sin(ar) * ry * rr * 1.25
        tang = -u * math.sin(ar) * rx + v * math.cos(ar) * ry
        tang = tang / (np.linalg.norm(tang) + 1e-6)
        outv = p - c
        outv = outv / np.linalg.norm(outv)
        stone_chip(cv, rng, p[0], p[1], n * s, rng.uniform(0, 360), el, hot_dir=-outv, trail=(tang + outv) / np.linalg.norm(tang + outv))


@skill("battle_mage.furious_dragon", tone="crimson")
def furious_dragon(cv, rng, el):
    """怒龙穿心: the lance runs straight through an enemy breastplate; a crimson dragon of light erupts out of the far
    side, head in 3/4 view lunging up and out, its body streaming back along the lance. Ink ground so the red
    dragon separates."""
    n = cv.n
    hit = np.array([n * 0.36, n * 0.66])
    ground(cv, el, [], focus=(n * 0.64, n * 0.34), focus_r=0.45, focus_k=0.35, ink="#050407", wash=-40, rng=rng)
    dragon_body(cv, [(n * 0.56, n * 0.48), (n * 0.42, n * 0.64), (n * 0.24, n * 0.70), (n * 0.10, n * 0.86), (n * -0.06, n * 0.98)],
                [n * 0.17, n * 0.15, n * 0.11, n * 0.06, n * 0.03], el, k=0.95, solid_to=0.45, streaks=5, spread=2.4)
    plate_fragment(cv, rng, hit[0] - n * 0.02, hit[1] + n * 0.05, n * 0.26, -12, el, 1.0)
    plate_fragment(cv, rng, hit[0] - n * 0.24, hit[1] - n * 0.22, n * 0.11, -60, el, 1.0, trail=np.array([-0.6, -0.8]))
    plate_fragment(cv, rng, hit[0] + n * 0.04, hit[1] + n * 0.30, n * 0.09, 40, el, 1.0, trail=np.array([0.2, 1.0]))
    H = lance_H((n * -0.30, n * 1.06), (n * 0.72, n * 0.36), 1.15)
    draw_lance(cv, H, el)
    hot_core(cv, hit[0], hit[1], el, 2.6, 1.1)
    src = [(-0.9, -0.95), (1.25, -0.95), (1.25, 0.75), (-0.9, 0.75)]
    dst = [(n * 0.40, n * 0.06), (n * 0.98, n * -0.04), (n * 1.04, n * 0.60), (n * 0.46, n * 0.46)]
    dragon_head(cv, H_quad(src, dst), el, k=1.0, far_offset=(0.16, 0.05))


@skill("battle_mage.dragon_breaks_ranks", tone="ember")
def dragon_breaks_ranks(cv, rng, el):
    """豪龙破军: side-on charge. The dragon IS the charge (no lance): long-snouted profile head leading, claw raking
    forward, S-coil behind dissolving into qi, enemy plate armour bursting apart ahead of it."""
    n = cv.n
    band = cv.poly([(0, n * 0.30), (n, n * 0.22), (n, n * 0.78), (0, n * 0.86)])
    ground(cv, el, [(band, 1)], focus=(n * 0.70, n * 0.45), focus_r=0.55, focus_k=0.8, wash=0, rng=rng)
    for (a, b, w) in (((-0.1, 0.16), (0.55, 0.19), 0.018), ((-0.1, 0.88), (0.6, 0.85), 0.02), ((0.0, 0.08), (0.35, 0.10), 0.012)):
        light_streak(cv, (n * a[0], n * a[1]), (n * b[0], n * b[1]), n * w, el, 0.8)
    dragon_body(cv, [(n * 0.40, n * 0.47), (n * 0.26, n * 0.58), (n * 0.12, n * 0.42), (n * -0.02, n * 0.52), (n * -0.18, n * 0.70)],
                [n * 0.16, n * 0.15, n * 0.11, n * 0.07, n * 0.03], el, k=0.95, solid_to=0.55, streaks=5, spread=1.8)
    dragon_claw(cv, (n * 0.38, n * 0.62), 25, n * 0.28, el, 0.95, spread=1.1)
    dragon_head(cv, H_affine((n * 0.44, n * 0.42), 4, n * 0.34), el, k=1.0)
    for (x, y, s, a, tr) in ((0.92, 0.80, 0.15, 30, (1, 0.4)), (0.90, 0.14, 0.12, -50, (1, -0.5)), (0.74, 0.93, 0.08, 80, (0.6, 0.8))):
        plate_fragment(cv, rng, n * x, n * y, n * s, a, el, 1.0, trail=np.array(tr) / np.linalg.norm(tr))


@skill("battle_mage.rising_dragon", tone="gold")
def rising_dragon(cv, rng, el):
    """伏龙翔天 (ultimate): looking up from below, the lance stands vertical and a gold dragon spirals up around it,
    head well inside the frame, maw open to the sky. Ink-to-crimson ground so the gold separates. The only cool
    light on the bar: an ice-cyan back rim on the dragon."""
    n = cv.n
    cx = n * 0.44
    ground(cv, "crimson", [], focus=(n * 0.62, n * 0.30), focus_r=0.55, focus_k=0.55, ink="#060407", wash=-80, rng=rng)
    t = np.linspace(0, 1, 90)
    ph = t * math.pi * 1.6 + 1.2
    hx = cx + np.sin(ph) * n * (0.25 - 0.06 * t)
    hy = n * 1.06 - t * n * 0.60
    path = np.c_[hx, hy][::-1]
    widths = [n * 0.15, n * 0.14, n * 0.12, n * 0.08, n * 0.03]
    dragon_body(cv, path[::5].tolist(), widths, el, k=0.8, solid_to=0.72, streaks=4, spread=1.6, value=0.95)
    H = lance_H((cx + n * 0.015, n * 1.25), (cx - n * 0.015, n * 0.30), 1.25)
    draw_lance(cv, H, el)
    front = np.cos(ph) > 0
    idx = [i for i in range(len(t)) if front[i] and 0.15 < t[i] < 0.9]
    if len(idx) > 6:
        seg = np.c_[hx[idx], hy[idx]]
        sp = spline(seg[::3], 6)
        ws = np.interp(np.linspace(0, 1, len(sp)), [0, 1], [n * (0.07 + 0.08 * (1 - t[idx[0]])), n * (0.07 + 0.08 * (1 - t[idx[-1]]))])
        m = cv.poly(ribbon(sp, ws))
        light_form(cv, m, el, 1.0, R=n * 0.03, glow_r=5, lw=(0.3, 1.8))
        cv.add(m * (1 - toward(m, 1.6, LIGHT)), KEY["cool"], 0.8)
    tipp = xf(H, [(1.0, 0.0)])[0]
    hot_core(cv, tipp[0], tipp[1], el, 2.4, 1.0)

    def bleed(c2):
        Hh = H_affine((n * 0.50, n * 0.50), -42, n * 0.25)
        m = dragon_head(c2, Hh, el, k=1.0, far_offset=(0.12, 0.04))
        c2.add(m * (1 - toward(m, 1.8, LIGHT)), KEY["cool"], 1.0)  # the one cool accent: ice-cyan back rim
    return {"bleed": bleed}
