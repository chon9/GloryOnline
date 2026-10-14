class_name EnvProps
extends RefCounted
## Landmark + set-dressing builders for the painted maps (all procedural, original code; no third-party meshes).
## Every builder appends merged geometry to an EnvKit batch (kit.add / kit.inst) - no per-prop nodes - and returns
## nothing unless noted. Collision is the caller's job (gameplay layout lives in the map scripts), except where a
## builder takes a `solid` flag. Materials are passed in so each zone keeps ONE palette (bible 4.3.1).

const UP := Vector3.UP


static func xf(pos: Vector3, yaw: float = 0.0, s: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(UP, yaw).scaled(s), pos)


# ================================================================== trees
## Red maple / blossom / gold / violet broadleaf: branching trunk, dark core puffs (value: darker at the core),
## painted leaf cards. `pal` = {bark, core, cards}. Returns the canopy centre.
static func broadleaf(kit: EnvKit, at: Vector3, height: float, pal: Dictionary, seed_i: int, cards_per_tip: int = 5,
		card_size: float = 2.2, depth: int = 5, spread: float = 0.6, yaw: float = 0.0, puff_scale: float = 0.75) -> Vector3:
	var sk := EnvKit.tree_skeleton(seed_i, height * 0.42, height * 0.065, depth, spread)
	var b := Basis(UP, yaw)
	var t := Transform3D(b, at)
	kit.add(sk[0], pal["bark"], t)
	var tips: Array = []
	for p: Vector3 in sk[1]:
		tips.append(t * p)
	var centre := Vector3.ZERO
	for p: Vector3 in tips:
		centre += p
	centre /= maxf(1.0, tips.size())
	centre.y -= height * 0.12
	var r := RandomNumberGenerator.new()
	r.seed = seed_i * 31 + 7
	if pal.has("core"):
		for i in tips.size():
			var s := r.randf_range(0.6, 0.85) * height * 0.09 * puff_scale / 0.75
			kit.add(EnvKit.puff_mesh(1.0, 1 + i % 3), pal["core"], Transform3D(Basis(UP, r.randf() * TAU).scaled(Vector3(s, s * 0.75, s)), (tips[i] as Vector3) + Vector3(0, 0.1, 0)))
	kit.add(EnvKit.leaf_cards(r, tips, centre, cards_per_tip, card_size, height * 0.11), pal["cards"], Transform3D.IDENTITY, true)
	return centre


## Bare frosted / dead tree (branch silhouette only).
static func bare_tree(kit: EnvKit, at: Vector3, scale: float, bark: Material, seed_i: int, yaw: float = 0.0) -> void:
	var sk := EnvKit.tree_skeleton(seed_i, 2.6, 0.28, 5, 0.75, Vector3(0, 1, 0))
	kit.add(sk[0], bark, Transform3D(Basis(UP, yaw).scaled(Vector3.ONE * scale), at))


## Gnarled dead tree (graveyard): leaning trunk, fewer longer twisted branches.
static func dead_tree(kit: EnvKit, at: Vector3, scale: float, bark: Material, seed_i: int, yaw: float = 0.0) -> void:
	var sk := EnvKit.tree_skeleton(seed_i, 3.2, 0.34, 4, 1.05, Vector3(0.35, 1, 0.1))
	kit.add(sk[0], bark, Transform3D(Basis(UP, yaw).scaled(Vector3.ONE * scale), at))


## Low shrub / bush: dark core puffs and painted leaf cards (edge clutter). pal = {core, cards}.
static func shrub(kit: EnvKit, at: Vector3, size: float, pal: Dictionary, seed_i: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var tips: Array = []
	for i in 4:
		var p := at + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(0.3, 0.7), r.randf_range(-0.6, 0.6)) * size
		tips.append(p)
		if pal.has("core"):
			var s := size * r.randf_range(0.35, 0.5)
			kit.add(EnvKit.puff_mesh(1.0, 1 + i % 3), pal["core"], Transform3D(Basis(UP, r.randf() * TAU).scaled(Vector3(s, s * 0.7, s)), p), false)
	kit.add(EnvKit.leaf_cards(r, tips, at + Vector3(0, size * 0.2, 0), 4, size * 0.9, size * 0.4), pal["cards"], Transform3D.IDENTITY, false)


## Bare twig shrub (dead / winter).
static func twig_shrub(kit: EnvKit, at: Vector3, size: float, bark: Material, seed_i: int) -> void:
	var sk := EnvKit.tree_skeleton(seed_i, 0.7, 0.06, 3, 1.2, Vector3(0, 1, 0))
	kit.add(sk[0], bark, Transform3D(Basis(UP, float(seed_i)).scaled(Vector3.ONE * size), at), false)


# ================================================================== stone & ruins
## Chunky rock scattered; returns the rock mesh used (for optional hull collision).
static func rock(kit: EnvKit, at: Vector3, r: float, mat: Material, seed_i: int, yaw: float = 0.0, squash: float = 1.0, shadow: bool = true) -> ArrayMesh:
	var m := EnvKit.rock_mesh(r, 0.42, seed_i)
	kit.add(m, mat, Transform3D(Basis(UP, yaw).scaled(Vector3(1.0, squash, 1.0)), at), shadow)
	return m


## Classical column with base and capital; h < 4 -> broken top with a jagged chunk; rubble at the foot.
static func column(kit: EnvKit, base: Vector3, h: float, mat: Material, seed_i: int, r: float = 0.5) -> void:
	var t := Transform3D(Basis(), base)
	kit.add(EnvKit.lathe([Vector2(r * 1.56, 0.0), Vector2(r * 1.56, 0.35), Vector2(r * 1.24, 0.45), Vector2(r * 1.1, 0.6)], 8), mat, t)
	kit.add(EnvKit.lathe([Vector2(r * 1.04, 0.55), Vector2(r * 0.94, h - 0.2), Vector2(r, h)], 14), mat, t)
	if h > 4.0:
		kit.add(EnvKit.lathe([Vector2(r, h), Vector2(r * 1.44, h + 0.35), Vector2(r * 1.5, h + 0.55)], 8), mat, t)
	else:
		kit.add(EnvKit.rock_mesh(r * 1.24, 0.35, seed_i), mat, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)), base + Vector3(0.05, h, 0.0)))
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_i
	for i in 3:
		var a := rr.randf() * TAU
		kit.add(EnvKit.rock_mesh(rr.randf_range(0.18, 0.35), 0.4, seed_i + i + 1), mat, Transform3D(Basis(), base + Vector3(cos(a), 0.1, sin(a)) * Vector3(1.0 + r, 1.0, 1.0 + r)), false)


## Square Gothic pier / buttress block with a pointed cap.
static func pier(kit: EnvKit, base: Vector3, size: Vector2, h: float, mat: Material, yaw: float = 0.0, cap: bool = true) -> void:
	kit.add(EnvKit.box(Vector3(size.x, h, size.y)), mat, xf(base + Vector3(0, h * 0.5, 0), yaw))
	kit.add(EnvKit.box(Vector3(size.x + 0.3, 0.35, size.y + 0.3)), mat, xf(base + Vector3(0, 0.17, 0), yaw))
	if cap:
		kit.add(EnvKit.lathe([Vector2(maxf(size.x, size.y) * 0.72, 0.0), Vector2(0.0, maxf(size.x, size.y) * 1.4)], 4), mat, xf(base + Vector3(0, h, 0), yaw + PI * 0.25))


## Broken pointed (Gothic) half-arch with a lone pier, fallen voussoirs and a tracery ring (look-dev landmark).
static func ruin_arch(kit: EnvKit, at: Vector3, yaw: float, stone: Material, ground: Callable, scale: float = 1.0) -> void:
	var Wi := 3.0 * scale
	var T := 1.0 * scale
	var Wo := Wi + T
	var H := 6.5 * scale
	var poly := PackedVector2Array()
	poly.append(Vector2(-Wo, 0))
	poly.append(Vector2(-Wo, H))
	for i in 10:
		var a := lerpf(PI, PI * 0.4, float(i) / 9.0)
		poly.append(Vector2(Wo, H) + Vector2(cos(a), sin(a)) * (2.0 * Wo))
	var tip := poly[poly.size() - 1]
	poly.append(tip + Vector2(0.15, -0.7) * scale)
	poly.append(tip + Vector2(-0.35, -1.1) * scale)
	poly.append(tip + Vector2(-0.1, -1.6) * scale)
	var inner := PackedVector2Array()
	for i in 10:
		var a := lerpf(PI, PI * 0.43, float(i) / 9.0)
		inner.append(Vector2(Wi, H) + Vector2(cos(a), sin(a)) * (2.0 * Wi))
	inner.reverse()
	for q in inner:
		if q.x < poly[poly.size() - 1].x - 0.2:
			poly.append(q)
	poly.append(Vector2(-Wi, H))
	poly.append(Vector2(-Wi, 0))
	var b := Basis(UP, yaw)
	var gy := float(ground.call(at.x, at.z))
	kit.add(EnvKit.extrude(poly, 1.6 * scale, 0.12), stone, Transform3D(b, at + Vector3(0, gy - 0.3, 0)))
	kit.add(EnvKit.box(Vector3(T, H * 0.75, 1.3 * scale)), stone, Transform3D(b, at + b * Vector3(Wi + T * 0.5, 0, 0) + Vector3(0, gy + H * 0.375 - 0.3, 0)))
	var r := RandomNumberGenerator.new()
	r.seed = int(at.x * 13.0 + at.z * 7.0) + 991
	for i in 6:
		var p := at + b * Vector3(r.randf_range(0.5, 5.0), 0, r.randf_range(0.5, 3.5)) * scale
		kit.add(EnvKit.box(Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.5, 0.8), r.randf_range(0.7, 1.2)) * scale), stone,
			Transform3D(Basis.from_euler(Vector3(r.randf() * 0.6, r.randf() * TAU, r.randf() * 0.6)), p + Vector3(0, float(ground.call(p.x, p.z)) + 0.25, 0)))
	kit.add(EnvKit.lathe([Vector2(1.3, -0.12), Vector2(1.45, 0.0), Vector2(1.3, 0.12)], 20), stone,
		Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * scale), at + b * Vector3(-0.5, 0, 0) * scale + Vector3(0, gy + H + 1.4 * scale, 0)))


## Gothic wall run from a to b (y = a.y): ashlar body, crenellations with gaps, broken top segments, buttresses.
## height h, thickness th. `broken` 0..1 lowers random merlons/segments.
static func gothic_wall(kit: EnvKit, a: Vector3, b: Vector3, h: float, th: float, mat: Material, seed_i: int, broken: float = 0.3,
		crenel: bool = true, buttress: bool = true, trim: Material = null, dark: Material = null) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	if length < 0.05:
		return
	var dir := d / length
	var out := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(-dir.z, dir.x)
	var bs := Basis(UP, yaw)
	var tm := trim if trim != null else mat
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var n := maxi(1, int(round(length / 3.0)))
	var seg := length / n
	for i in n:
		var c := a + dir * (seg * (i + 0.5))
		var hh := h
		var is_broken := r.randf() < broken * 0.5
		if is_broken:
			hh = h * r.randf_range(0.55, 0.8)
		kit.add(EnvKit.box(Vector3(seg + 0.02, hh, th)), mat, Transform3D(bs, c + Vector3(0, hh * 0.5, 0)))
		# battered plinth course + string course trim
		kit.add(EnvKit.box(Vector3(seg + 0.02, 0.5, th + 0.3)), mat, Transform3D(bs, c + Vector3(0, 0.25, 0)))
		kit.add(EnvKit.box(Vector3(seg + 0.02, 0.14, th + 0.22)), tm, Transform3D(bs, c + Vector3(0, 0.56, 0)), false)
		if hh > h * 0.7:
			kit.add(EnvKit.box(Vector3(seg + 0.02, 0.16, th + 0.18)), tm, Transform3D(bs, c + Vector3(0, h * 0.68, 0)), false)
		# proud / sunken ashlar blocks break the flat faces
		for k in 3:
			var side := 1.0 if (k + i) % 2 == 0 else -1.0
			var bp := c + dir * r.randf_range(-seg * 0.4, seg * 0.4) + Vector3(0, r.randf_range(0.8, hh - 0.4), 0)
			var bsz := Vector3(r.randf_range(0.5, 1.0), r.randf_range(0.3, 0.55), 0.12)
			kit.add(EnvKit.box(bsz), mat, Transform3D(bs, bp + out * side * (th * 0.5 + 0.02)), false)
		# arrow slit (dark inset) every other segment
		if dark != null and i % 2 == 1 and hh > 2.4:
			for side: float in [-1.0, 1.0]:
				kit.add(EnvKit.box(Vector3(0.16, 1.1, 0.06)), dark, Transform3D(bs, c + out * side * (th * 0.5 + 0.01) + Vector3(0, hh * 0.5 + 0.2, 0)), false)
				kit.add(EnvKit.box(Vector3(0.5, 0.12, 0.1)), tm, Transform3D(bs, c + out * side * (th * 0.5 + 0.03) + Vector3(0, hh * 0.5 + 0.8, 0)), false)
		if crenel and not is_broken:
			# coping + merlons with caps, a few chipped or missing
			kit.add(EnvKit.box(Vector3(seg + 0.04, 0.16, th + 0.2)), tm, Transform3D(bs, c + Vector3(0, hh + 0.08, 0)), false)
			for k in 2:
				var roll := r.randf()
				if roll < broken * 0.3:
					continue
				var mc := c + dir * ((k - 0.5) * seg * 0.5)
				var mh := 0.85 if roll > broken * 0.6 else r.randf_range(0.35, 0.6)
				var tilt := Basis(dir, r.randf_range(-0.06, 0.06)) if mh < 0.8 else Basis()
				kit.add(EnvKit.box(Vector3(seg * 0.3, mh, th + 0.05)), mat, Transform3D(tilt * bs, mc + Vector3(0, hh + 0.16 + mh * 0.5, 0)), false)
				if mh > 0.8:
					kit.add(EnvKit.box(Vector3(seg * 0.3 + 0.12, 0.1, th + 0.17)), tm, Transform3D(bs, mc + Vector3(0, hh + 0.16 + mh + 0.05, 0)), false)
		elif is_broken:
			# stepped break: offset course stones, a jagged chunk, rubble spilling at the foot
			kit.add(EnvKit.box(Vector3(seg * 0.45, 0.45, th)), mat, Transform3D(bs, c - dir * seg * 0.27 + Vector3(0, hh + 0.22, 0)))
			kit.add(EnvKit.rock_mesh(th * 0.6, 0.4, seed_i + i), mat, Transform3D(bs.scaled(Vector3(1.4, 0.6, 1.0)), c + dir * seg * 0.2 + Vector3(0, hh, 0)), false)
			for k in 3:
				var rp := c + dir * r.randf_range(-seg * 0.5, seg * 0.5) + out * (1.0 if k % 2 == 0 else -1.0) * (th * 0.5 + r.randf_range(0.3, 0.9))
				kit.add(EnvKit.box(Vector3(r.randf_range(0.35, 0.7), r.randf_range(0.25, 0.45), r.randf_range(0.35, 0.6))), mat,
					Transform3D(Basis.from_euler(Vector3(r.randf() * 0.5, r.randf() * TAU, r.randf() * 0.5)), rp + Vector3(0, 0.15, 0)), false)
		if buttress and i % 2 == 0 and i > 0:
			var bp := a + dir * (seg * i)
			for sgn: float in [-1.0, 1.0]:
				kit.add(EnvKit.box(Vector3(0.7, h * 0.7, 0.8)), mat, Transform3D(bs, bp + out * sgn * (th * 0.5 + 0.35) + Vector3(0, h * 0.35, 0)))
				kit.add(EnvKit.lathe([Vector2(0.55, 0.0), Vector2(0.0, 0.9)], 4), tm, Transform3D(bs * Basis(UP, PI * 0.25), bp + out * sgn * (th * 0.5 + 0.35) + Vector3(0, h * 0.7, 0)), false)


## Pointed arch window frame (for walls / chapel facades). Dark glass optional (glow mat for lit windows).
static func gothic_window(kit: EnvKit, at: Vector3, yaw: float, w: float, h: float, frame: Material, glass: Material = null) -> void:
	var poly := PackedVector2Array()
	var steps := 8
	poly.append(Vector2(-w * 0.5, 0))
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(PI, PI / 3.0, t)
		poly.append(Vector2(w * 0.5, h - w) + Vector2(cos(a), sin(a)) * w)
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(PI * 2.0 / 3.0, 0.0, t)
		poly.append(Vector2(-w * 0.5, h - w) + Vector2(cos(a), sin(a)) * w)
	poly.append(Vector2(w * 0.5, 0))
	var b := Basis(UP, yaw)
	if glass != null:
		kit.add(EnvKit.extrude(poly, 0.12), glass, Transform3D(b, at), false)
	# frame: thin outline ribs
	var pts: Array = []
	for p in poly:
		pts.append(at + b * Vector3(p.x, p.y, 0.1))
	pts.append(pts[0])
	kit.add(EnvKit.tube(pts, 0.12, 5), frame, Transform3D.IDENTITY, false)


## Ruined Gothic cathedral facade (castle / graveyard landmark): twin towers with spires (one broken), central
## gable with a rose window, pointed portal, flying buttress stubs. Faces local +Z; ~26 m wide, spire ~34 m.
static func cathedral(kit: EnvKit, at: Vector3, yaw: float, stone: Material, dark: Material, glass: Material, scale: float = 1.0) -> void:
	var b := Basis(UP, yaw)
	var s := scale
	var T := func(p: Vector3) -> Vector3: return at + b * (p * s)
	# towers
	for sx: float in [-1.0, 1.0]:
		var base: Vector3 = T.call(Vector3(sx * 9.0, 0, 0))
		kit.add(EnvKit.box(Vector3(6.0, 22.0, 6.0) * s), stone, Transform3D(b, base + Vector3(0, 11.0 * s, 0)))
		kit.add(EnvKit.box(Vector3(6.8, 0.8, 6.8) * s), stone, Transform3D(b, base + Vector3(0, 22.0 * s, 0)))
		for k in 3:
			gothic_window(kit, base + b * Vector3(0, (5.0 + k * 6.0) * s, 3.05 * s), yaw, 1.6 * s, 4.0 * s, dark, glass if k == 1 else null)
		if sx < 0:
			# full spire with pinnacles
			kit.add(EnvKit.lathe([Vector2(3.0, 0.0), Vector2(2.6, 1.0), Vector2(0.0, 13.0)], 8), stone, Transform3D(b.scaled(Vector3.ONE * s), base + Vector3(0, 22.4 * s, 0)))
			for c in 4:
				var ca := TAU * c / 4.0 + PI * 0.25
				kit.add(EnvKit.lathe([Vector2(0.5, 0.0), Vector2(0.0, 3.2)], 4), stone, Transform3D(b.scaled(Vector3.ONE * s), base + b * Vector3(cos(ca) * 3.0, 22.4, sin(ca) * 3.0) * s))
		else:
			# broken: jagged stump of the spire
			kit.add(EnvKit.lathe([Vector2(3.0, 0.0), Vector2(2.6, 1.0), Vector2(1.6, 5.0)], 8), stone, Transform3D(b.scaled(Vector3.ONE * s), base + Vector3(0, 22.4 * s, 0)))
			kit.add(EnvKit.rock_mesh(2.0 * s, 0.5, 77), stone, Transform3D(b.scaled(Vector3(1.0, 0.7, 1.0)), base + Vector3(0, 27.0 * s, 0)))
	# nave gable wall between the towers
	var gable := PackedVector2Array([Vector2(-6.0, 0), Vector2(6.0, 0), Vector2(6.0, 15.0), Vector2(0.0, 22.0), Vector2(-6.0, 15.0)])
	kit.add(EnvKit.extrude(gable, 2.0), stone, Transform3D(b.scaled(Vector3.ONE * s), T.call(Vector3(0, 0, -0.5))))
	# rose window
	var rose_c: Vector3 = T.call(Vector3(0, 13.5, 0.6))
	kit.add(EnvKit.lathe([Vector2(3.0, -0.25), Vector2(3.3, 0.0), Vector2(3.0, 0.25)], 24), stone, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * s), rose_c))
	var rb := b * Basis(Vector3.RIGHT, PI * 0.5)
	# stained glass: alternating lit / dark wedges, then stone tracery over them (spokes, petal foils, hub)
	for k in 16:
		var a0 := TAU * k / 16.0
		var a1 := TAU * (k + 1) / 16.0
		var wedge := PackedVector2Array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * 3.0, Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * 3.05, Vector2(cos(a1), sin(a1)) * 3.0])
		kit.add(EnvKit.extrude(wedge, 0.08), glass if k % 2 == 0 else dark, Transform3D(b.scaled(Vector3.ONE * s), rose_c - b * Vector3(0, 0, 0.04) * s), false)
	for k in 8:
		var a := TAU * k / 8.0
		kit.add(EnvKit.box(Vector3(0.2, 2.9, 0.34) * s), stone, Transform3D(b * Basis(Vector3.FORWARD, a), rose_c + b * Vector3(cos(a + PI * 0.5), sin(a + PI * 0.5), 0) * 1.45 * s), false)
		var fc := rose_c + b * Vector3(cos(a + PI / 8.0), sin(a + PI / 8.0), 0) * 2.15 * s
		kit.add(EnvKit.lathe([Vector2(0.5, -0.12), Vector2(0.58, 0.0), Vector2(0.5, 0.12), Vector2(0.42, 0.0), Vector2(0.5, -0.12)], 12), stone, Transform3D(rb.scaled(Vector3.ONE * s), fc + b * Vector3(0, 0, 0.05) * s), false)
	for rr: float in [0.85, 1.6]:
		kit.add(EnvKit.lathe([Vector2(rr - 0.08, -0.15), Vector2(rr + 0.08, -0.15), Vector2(rr + 0.08, 0.15), Vector2(rr - 0.08, 0.15), Vector2(rr - 0.08, -0.15)], 24), stone, Transform3D(rb.scaled(Vector3.ONE * s), rose_c + b * Vector3(0, 0, 0.08) * s), false)
	kit.add(EnvKit.lathe([Vector2(3.5, -0.3), Vector2(3.7, 0.0), Vector2(3.5, 0.35), Vector2(3.2, 0.3)], 32), stone, Transform3D(rb.scaled(Vector3.ONE * s), rose_c), false)
	# portal
	gothic_window(kit, T.call(Vector3(0, 0, 0.7)), yaw, 4.0 * s, 8.0 * s, stone, dark)
	# flying buttress stubs reaching back
	for sx: float in [-1.0, 1.0]:
		var p0: Vector3 = T.call(Vector3(sx * 6.0, 12.0, -4.0))
		var p1: Vector3 = T.call(Vector3(sx * 10.0, 4.0, -9.0))
		kit.add(EnvKit.tube([p0, (p0 + p1) * 0.5 + Vector3(0, 1.5 * s, 0), p1], 0.7 * s, 6), stone, Transform3D.IDENTITY)
		kit.add(EnvKit.box(Vector3(1.8, 8.0, 1.8) * s), stone, Transform3D(b, T.call(Vector3(sx * 10.5, 4.0, -9.5))))


# ================================================================== platforms, stairs
## Stone plinth block: ashlar sides, a moulded lip and a top cap in `top_mat`. rect in XZ, from base_y to h.
static func plinth(kit: EnvKit, rect: Rect2, base_y: float, h: float, side_mat: Material, top_mat: Material, lip_mat: Material = null) -> void:
	var c := Vector3(rect.get_center().x, 0, rect.get_center().y)
	var hh := h - base_y
	kit.add(EnvKit.box(Vector3(rect.size.x, hh - 0.12, rect.size.y)), side_mat, Transform3D(Basis(), c + Vector3(0, base_y + (hh - 0.12) * 0.5, 0)))
	kit.add(EnvKit.box(Vector3(rect.size.x + 0.5, 0.45, rect.size.y + 0.5)), side_mat, Transform3D(Basis(), c + Vector3(0, base_y + 0.22, 0)))
	kit.add(EnvKit.box(Vector3(rect.size.x + 0.16, 0.14, rect.size.y + 0.16)), lip_mat if lip_mat != null else side_mat, Transform3D(Basis(), c + Vector3(0, h - 0.07 - 0.02, 0)))
	kit.add(EnvKit.box(Vector3(rect.size.x - 0.02, 0.04, rect.size.y - 0.02)), top_mat, Transform3D(Basis(), c + Vector3(0, h - 0.0, 0)), false)


## Decorative facing for a plinth: pilasters every ~3 m, recessed panels between them and a cornice under the lip
## (breaks the flat ashlar box at close range). Visual only, stays within 0.15 m of the faces.
static func plinth_trim(kit: EnvKit, rect: Rect2, base_y: float, h: float, trim: Material, panel: Material, skip: Callable = Callable()) -> void:
	var c := Vector3(rect.get_center().x, 0, rect.get_center().y)
	var hh := h - base_y
	var sides := [[Vector3(0, 0, -rect.size.y * 0.5), Vector3(1, 0, 0), rect.size.x], [Vector3(0, 0, rect.size.y * 0.5), Vector3(1, 0, 0), rect.size.x],
		[Vector3(-rect.size.x * 0.5, 0, 0), Vector3(0, 0, 1), rect.size.y], [Vector3(rect.size.x * 0.5, 0, 0), Vector3(0, 0, 1), rect.size.y]]
	for sd: Array in sides:
		var off: Vector3 = sd[0]
		var along: Vector3 = sd[1]
		var length: float = sd[2]
		var out := off.normalized()
		var yaw := atan2(-along.z, along.x)
		var b := Basis(UP, yaw)
		var face := c + off
		kit.add(EnvKit.box(Vector3(length + 0.3, 0.22, 0.3)), trim, Transform3D(b, face + out * 0.05 + Vector3(0, h - 0.26, 0)), false)
		var n := maxi(1, int(round(length / 3.0)))
		for i in n + 1:
			var p := face + along * (-length * 0.5 + length * float(i) / n)
			if skip.is_valid() and bool(skip.call(p)):
				continue
			kit.add(EnvKit.box(Vector3(0.45, hh - 0.6, 0.24)), trim, Transform3D(b, p + out * 0.02 + Vector3(0, base_y + 0.3 + (hh - 0.6) * 0.5, 0)), false)
			if i < n:
				var pc := face + along * (-length * 0.5 + length * (float(i) + 0.5) / n)
				if not (skip.is_valid() and bool(skip.call(pc))):
					kit.add(EnvKit.box(Vector3(length / n - 1.1, (hh - 1.0) * 0.7, 0.06)), panel, Transform3D(b, pc + out * 0.02 + Vector3(0, base_y + 0.5 + (hh - 1.0) * 0.45, 0)), false)


## Stairs visual matching MapKit.ramp collision: from `top` (centre of the upper edge) down along yaw (0 = +Z).
static func stairs(kit: EnvKit, top: Vector3, yaw_deg: float, length: float, width: float, base_y: float, step_mat: Material,
		cheek_mat: Material) -> void:
	var h := top.y - base_y
	var n := maxi(2, int(round(h / 0.25)))
	var b := Basis(UP, deg_to_rad(yaw_deg))
	var o := Vector3(top.x, base_y, top.z)
	for i in n:
		var y1 := h * float(n - i) / n
		var z0 := length * float(i) / n
		var z1 := length * float(i + 1) / n
		var c := o + b * Vector3(0, y1 * 0.5, (z0 + z1) * 0.5)
		kit.add(EnvKit.box(Vector3(width, y1, z1 - z0 + 0.02)), step_mat, Transform3D(b, c))
	for sx: float in [-1.0, 1.0]:
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(0, h + 0.35), Vector2(0.6, h + 0.35), Vector2(length + 0.3, 0.35), Vector2(length + 0.3, 0)])
		kit.add(EnvKit.extrude(poly, 0.45), cheek_mat, Transform3D(b * Basis(UP, -PI * 0.5), o + b * Vector3(sx * (width * 0.5 + 0.22), 0, 0)))


# ================================================================== lights & small props
## Stone lantern post with a glowing core; returns the light position.
static func lantern(kit: EnvKit, base: Vector3, stone: Material, core: Material, light: bool, color: Color, energy: float = 1.4) -> Vector3:
	var t := Transform3D(Basis(), base)
	kit.add(EnvKit.lathe([Vector2(0.28, 0.0), Vector2(0.22, 0.15), Vector2(0.12, 0.3), Vector2(0.1, 1.2), Vector2(0.24, 1.35), Vector2(0.24, 1.42)], 6), stone, t)
	kit.add(EnvKit.lathe([Vector2(0.2, 1.42), Vector2(0.17, 1.75), Vector2(0.3, 1.8), Vector2(0.0, 2.15)], 6), stone, t)
	kit.add(EnvKit.cyl(0.11, 0.11, 0.28, 6), core, Transform3D(Basis(), base + Vector3(0, 1.6, 0)), false)
	if light:
		kit.omni(base + Vector3(0, 1.6, 0), color, energy, 6.0)
	return base + Vector3(0, 1.6, 0)


## Chinese hanging lantern (red paper, gold caps).
static func paper_lantern(kit: EnvKit, at: Vector3, paper: Material, gold: Material) -> void:
	kit.add(EnvKit.lathe([Vector2(0.0, -0.32), Vector2(0.18, -0.3), Vector2(0.3, -0.12), Vector2(0.32, 0.0), Vector2(0.3, 0.12), Vector2(0.18, 0.3), Vector2(0.0, 0.32)], 10), paper, Transform3D(Basis(), at), false)
	kit.add(EnvKit.cyl(0.12, 0.12, 0.08, 8), gold, Transform3D(Basis(), at + Vector3(0, 0.33, 0)), false)
	kit.add(EnvKit.cyl(0.1, 0.1, 0.06, 8), gold, Transform3D(Basis(), at - Vector3(0, 0.33, 0)), false)
	kit.add(EnvKit.cyl(0.015, 0.015, 0.4, 4), gold, Transform3D(Basis(), at - Vector3(0, 0.55, 0)), false)


## Fire brazier (iron bowl on a stone drum) with flame core glow.
static func brazier(kit: EnvKit, base: Vector3, stone: Material, iron: Material, flame: Material) -> void:
	var t := Transform3D(Basis(), base)
	kit.add(EnvKit.lathe([Vector2(0.45, 0.0), Vector2(0.38, 0.2), Vector2(0.26, 0.3), Vector2(0.22, 0.9), Vector2(0.4, 1.0)], 8), stone, t)
	kit.add(EnvKit.lathe([Vector2(0.18, 1.0), Vector2(0.55, 1.2), Vector2(0.62, 1.45), Vector2(0.5, 1.42), Vector2(0.15, 1.25)], 10), iron, t)
	kit.add(EnvKit.lathe([Vector2(0.45, 1.36), Vector2(0.0, 1.46)], 8), flame, t, false)
	kit.flame(base + Vector3(0, 1.3, 0), 1.1)


## Team / guild banner on a pole (painted cloth texture, gold finial and crossbar).
static func banner(kit: EnvKit, at: Vector3, tex_name: String, tint: Color, pole_h: float, pole: Material, gold: Material, yaw: float = 0.0) -> void:
	var b := Basis(UP, yaw)
	kit.add(EnvKit.cyl(0.06, 0.08, pole_h, 8), pole, Transform3D(b, at + Vector3(0, pole_h * 0.5, 0)))
	kit.add(EnvKit.sphere(0.13, 8), gold, Transform3D(b, at + Vector3(0, pole_h + 0.05, 0)), false)
	kit.add(EnvKit.cyl(0.035, 0.035, 1.4, 6), gold, Transform3D(b * Basis(Vector3.FORWARD, PI * 0.5), at + b * Vector3(0.55, pole_h - 0.3, 0)), false)
	var pts: Array = []
	var w: Array = []
	var s: Array = []
	var len := pole_h * 0.7
	for i in 12:
		var t := float(i) / 11.0
		pts.append(Vector3(0.55 + sin(t * 4.0) * 0.08, pole_h - 0.35 - t * len, sin(t * 5.0 + 1.0) * 0.2))
		w.append(1.15)
		s.append(Vector3(1, 0, 0.15 * cos(t * 5.0)))
	kit.add(EnvKit.ribbon(pts, w, s, 0.02), EnvKit.cloth(tex_name, tint), Transform3D(b, at), true)


## Wall-hung banner cloth (no pole): hangs from `top`, facing `yaw` (local +Z outward).
static func wall_banner(kit: EnvKit, top: Vector3, yaw: float, length: float, tex_name: String, tint: Color, rod: Material) -> void:
	var b := Basis(UP, yaw)
	var pts: Array = []
	var w: Array = []
	var s: Array = []
	for i in 10:
		var t := float(i) / 9.0
		pts.append(Vector3(0, -t * length, 0.12 + sin(t * 3.0) * 0.05))
		w.append(1.2)
		s.append(Vector3(1, 0, 0))
	kit.add(EnvKit.ribbon(pts, w, s, 0.02), EnvKit.cloth(tex_name, tint), Transform3D(b, top), false)
	kit.add(EnvKit.cyl(0.04, 0.04, 1.5, 6), rod, Transform3D(b * Basis(Vector3.FORWARD, PI * 0.5), top + b * Vector3(0, 0.02, 0.12)), false)


## Ice crystal cluster (cyan) with an inner glow; optional light.
static func ice_cluster(kit: EnvKit, at: Vector3, ice: Material, core: Material, seed_i: int, scale: float = 1.0, light: bool = false) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	for i in 6:
		var h := r.randf_range(0.8, 2.6) * (1.6 if i == 0 else 1.0) * scale
		var rad := h * 0.16
		var shard := EnvKit.lathe([Vector2(rad * 0.7, -0.2), Vector2(rad, 0.0), Vector2(rad, h * 0.7), Vector2(0.0, h)], 6)
		var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), r.randf_range(0.1, 0.55) if i > 0 else 0.08)
		var p := (Vector3(r.randf_range(-0.8, 0.8), 0, r.randf_range(-0.8, 0.8)) * scale) if i > 0 else Vector3.ZERO
		kit.add(shard, ice, Transform3D(tilt, at + p), i < 2)
		if i < 2:
			kit.add(shard, core, Transform3D(tilt.scaled(Vector3(0.55, 0.85, 0.55)), at + p), false)
	if light:
		kit.omni(at + Vector3(0, 1.4 * scale, 0), Color("#7FE8FF"), 1.2, 5.0 * scale)


## Generic crystal cluster with an emissive tint (lava cave: amber; graveyard: violet).
static func crystals(kit: EnvKit, at: Vector3, mat: Material, seed_i: int, scale: float = 1.0, count: int = 5) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	for i in count:
		var h := r.randf_range(0.7, 2.0) * scale * (1.5 if i == 0 else 1.0)
		var rad := h * 0.18
		var shard := EnvKit.lathe([Vector2(rad * 0.6, -0.2), Vector2(rad, 0.1), Vector2(rad * 0.9, h * 0.75), Vector2(0.0, h)], 5)
		var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), r.randf_range(0.15, 0.6) if i > 0 else 0.05)
		kit.add(shard, mat, Transform3D(tilt, at + (Vector3(r.randf_range(-0.7, 0.7), 0, r.randf_range(-0.7, 0.7)) * scale if i > 0 else Vector3.ZERO)), false)


## Painted wooden crate stack (2-3 boxes) and a barrel; returns footprint radius.
static func crates(kit: EnvKit, at: Vector3, yaw: float, wood: Material, trim: Material, seed_i: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var b := Basis(UP, yaw)
	var s := 1.0
	kit.add(EnvKit.box(Vector3(s, s, s)), wood, Transform3D(b, at + b * Vector3(-0.5, 0.5, 0)))
	kit.add(EnvKit.box(Vector3(s, s, s) * 0.95), wood, Transform3D(b * Basis(UP, 0.3), at + b * Vector3(0.55, 0.48, 0.1)))
	kit.add(EnvKit.box(Vector3(s, s, s) * 0.85), wood, Transform3D(b * Basis(UP, -0.2), at + b * Vector3(-0.3, 1.43, 0.05)))
	for p: Vector3 in [Vector3(-0.5, 0.5, 0), Vector3(-0.3, 1.43, 0.05)]:
		kit.add(EnvKit.box(Vector3(1.04, 0.1, 1.04)), trim, Transform3D(b, at + b * p + Vector3(0, 0.42, 0)), false)
	barrel(kit, at + b * Vector3(0.2, 0, 1.0), wood, trim)


static func barrel(kit: EnvKit, base: Vector3, wood: Material, hoop: Material) -> void:
	var t := Transform3D(Basis(), base)
	kit.add(EnvKit.lathe([Vector2(0.0, 0.0), Vector2(0.36, 0.0), Vector2(0.44, 0.5), Vector2(0.36, 1.0), Vector2(0.0, 1.0)], 10), wood, t)
	for y: float in [0.18, 0.82]:
		kit.add(EnvKit.lathe([Vector2(0.43, y - 0.04), Vector2(0.43, y + 0.04)], 10), hoop, Transform3D(Basis().scaled(Vector3(0.98, 1, 0.98)), base), false)


## Campfire: ring of stones, crossed logs, flame glow cone; returns the light position.
static func campfire(kit: EnvKit, at: Vector3, stone: Material, log_mat: Material, flame: Material) -> Vector3:
	for i in 7:
		var a := TAU * i / 7.0
		kit.add(EnvKit.rock_mesh(0.22, 0.35, 300 + i), stone, Transform3D(Basis(UP, a), at + Vector3(cos(a), 0.08, sin(a)) * 0.85), false)
	for k in 3:
		var a := TAU * k / 3.0
		kit.add(EnvKit.cyl(0.08, 0.1, 1.1, 6), log_mat, Transform3D(Basis(UP, a) * Basis(Vector3.RIGHT, 1.1), at + Vector3(cos(a) * 0.2, 0.25, sin(a) * 0.2)), false)
	kit.add(EnvKit.lathe([Vector2(0.4, 0.12), Vector2(0.0, 0.2)], 8), flame, Transform3D(Basis(), at), false)
	kit.flame(at + Vector3(0, 0.05, 0), 1.3)
	return at + Vector3(0, 1.0, 0)


## A-frame canvas tent.
static func tent(kit: EnvKit, at: Vector3, yaw: float, canvas: Material, pole: Material) -> void:
	var b := Basis(UP, yaw)
	var poly := PackedVector2Array([Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0.0, 2.2)])
	kit.add(EnvKit.extrude(poly, 3.0), canvas, Transform3D(b, at))
	kit.add(EnvKit.cyl(0.05, 0.05, 3.4, 5), pole, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 2.25, 0)), false)


# ================================================================== Chinese fantasy (blossom valley)
## Curved-eave roof (歇山-ish): a flared hip roof with upturned corners; `w`/`d` footprint, `h` rise.
static func curved_roof(kit: EnvKit, at: Vector3, w: float, d: float, h: float, tiles: Material, ridge: Material, yaw: float = 0.0) -> void:
	var b := Basis(UP, yaw)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var seg := 16
	# rings from the eave (t=0) to the ridge (t=1); superellipse footprint, concave profile, corners lift
	var prev: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var sc := 1.0 - t * 0.82
		var y := h * (t * t * 0.85 + t * 0.15)
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			var cx := cos(a)
			var cz := sin(a)
			var k := pow(pow(absf(cx), 4.0) + pow(absf(cz), 4.0), -0.25)
			var px := cx * k * w * 0.5 * sc
			var pz := cz * k * d * 0.5 * sc
			var corner := pow(absf(cx * cz) * 2.0, 3.0)
			ring.append(Vector3(px, y + corner * (1.0 - t) * h * 0.35, pz))
		if i > 0:
			for j in seg:
				var a0: Vector3 = prev[j]
				var a1: Vector3 = prev[(j + 1) % seg]
				var b0: Vector3 = ring[j]
				var b1: Vector3 = ring[(j + 1) % seg]
				for v: Vector3 in [a0, b1, a1, a0, b0, b1, a0, a1, b1, a0, b1, b0]:
					st.add_vertex(v)
		prev = ring
	st.generate_normals()
	kit.add(st.commit(), tiles, Transform3D(b, at))
	kit.add(EnvKit.box(Vector3(w * 0.22, 0.25, 0.25)), ridge, Transform3D(b, at + Vector3(0, h + 0.05, 0)), false)
	kit.add(EnvKit.lathe([Vector2(0.25, 0.0), Vector2(0.12, 0.4), Vector2(0.0, 0.8)], 6), ridge, Transform3D(b, at + Vector3(0, h + 0.15, 0)), false)


## Open pavilion (亭): stone base, 4/6 red lacquer columns, beam ring, curved roof, hanging lanterns.
static func pavilion(kit: EnvKit, at: Vector3, radius: float, height: float, sides: int, mats: Dictionary, yaw: float = 0.0, base_h: float = 0.4) -> void:
	kit.add(EnvKit.lathe([Vector2(radius + 0.6, 0.0), Vector2(radius + 0.6, base_h), Vector2(radius + 0.4, base_h + 0.05), Vector2(0.0, base_h + 0.05)], sides), mats["stone"], Transform3D(Basis(UP, yaw + PI / sides), at))
	for k in sides:
		var a := yaw + TAU * k / sides
		var p := at + Vector3(cos(a), 0, sin(a)) * radius
		kit.add(EnvKit.cyl(0.16, 0.18, height, 8), mats["lacquer"], Transform3D(Basis(), p + Vector3(0, base_h + height * 0.5, 0)))
		kit.add(EnvKit.lathe([Vector2(0.3, 0.0), Vector2(0.26, 0.2)], 8), mats["stone"], Transform3D(Basis(), p + Vector3(0, base_h, 0)), false)
		paper_lantern(kit, p + Vector3(0, base_h + height - 0.7, 0) + Vector3(cos(a), 0, sin(a)) * 0.45, mats["paper"], mats["gold"])
	kit.add(EnvKit.lathe([Vector2(radius + 0.25, 0.0), Vector2(radius + 0.25, 0.35), Vector2(radius - 0.25, 0.35), Vector2(radius - 0.25, 0.0)], sides), mats["lacquer_dark"], Transform3D(Basis(UP, yaw + PI / sides), at + Vector3(0, base_h + height, 0)))
	curved_roof(kit, at + Vector3(0, base_h + height + 0.3, 0), (radius + 1.6) * 2.0, (radius + 1.6) * 2.0, radius * 0.9 + 0.8, mats["tiles"], mats["gold"], yaw)


## Multi-tier pagoda (塔) landmark, `tiers` floors, footprint shrinking upward.
static func pagoda(kit: EnvKit, at: Vector3, tiers: int, base_w: float, tier_h: float, mats: Dictionary, yaw: float = 0.0) -> void:
	var y := 0.0
	kit.add(EnvKit.box(Vector3(base_w + 3.0, 1.2, base_w + 3.0)), mats["stone"], Transform3D(Basis(UP, yaw), at + Vector3(0, 0.6, 0)))
	y = 1.2
	for t in tiers:
		var w := base_w * (1.0 - float(t) * 0.11)
		kit.add(EnvKit.box(Vector3(w, tier_h, w)), mats["wall"], Transform3D(Basis(UP, yaw), at + Vector3(0, y + tier_h * 0.5, 0)))
		for k in 4:
			var a := yaw + PI * 0.5 * k
			var face := at + Basis(UP, a) * Vector3(0, y + tier_h * 0.45, w * 0.5 + 0.02)
			kit.add(EnvKit.box(Vector3(w * 0.3, tier_h * 0.55, 0.1)), mats["lacquer"], Transform3D(Basis(UP, a), face), false)
			kit.add(EnvKit.box(Vector3(w * 0.22, tier_h * 0.42, 0.12)), mats["window"], Transform3D(Basis(UP, a), face + Basis(UP, a) * Vector3(0, 0, 0.03)), false)
		for c in 4:
			var ca := yaw + PI * 0.5 * c + PI * 0.25
			kit.add(EnvKit.cyl(0.2, 0.2, tier_h, 6), mats["lacquer"], Transform3D(Basis(), at + Vector3(cos(ca), 0, sin(ca)) * w * 0.7 + Vector3(0, y + tier_h * 0.5, 0)), false)
		curved_roof(kit, at + Vector3(0, y + tier_h, 0), w + 3.2, w + 3.2, 1.3 + 0.1 * (tiers - t), mats["tiles"], mats["gold"], yaw)
		y += tier_h + 1.1
	kit.add(EnvKit.lathe([Vector2(0.35, 0.0), Vector2(0.22, 1.5), Vector2(0.3, 1.8), Vector2(0.08, 4.5), Vector2(0.0, 5.0)], 8), mats["gold"], Transform3D(Basis(), at + Vector3(0, y + 0.4, 0)))


## Lacquered balustrade along a->b (posts + rails), for terrace edges and bridges.
static func balustrade(kit: EnvKit, a: Vector3, b: Vector3, h: float, post: Material, rail: Material, spacing: float = 2.0) -> void:
	var d := b - a
	var length := Vector2(d.x, d.z).length()
	if length < 0.1:
		return
	var n := maxi(1, int(round(length / spacing)))
	var yaw := atan2(-d.z, d.x)
	for i in n + 1:
		var p := a + d * (float(i) / n)
		kit.add(EnvKit.box(Vector3(0.22, h + 0.15, 0.22)), post, Transform3D(Basis(UP, yaw), p + Vector3(0, (h + 0.15) * 0.5, 0)), false)
		kit.add(EnvKit.sphere(0.13, 6), post, Transform3D(Basis(), p + Vector3(0, h + 0.2, 0)), false)
	var mid := (a + b) * 0.5
	kit.add(EnvKit.box(Vector3(length, 0.12, 0.14)), rail, Transform3D(Basis(UP, yaw), mid + Vector3(0, h, 0)), false)
	kit.add(EnvKit.box(Vector3(length, 0.08, 0.1)), rail, Transform3D(Basis(UP, yaw), mid + Vector3(0, h * 0.45, 0)), false)


## Paifang gate (牌坊): two/four columns, stacked lintels, small roofs. Faces +Z (local).
static func paifang(kit: EnvKit, at: Vector3, yaw: float, w: float, h: float, mats: Dictionary) -> void:
	var b := Basis(UP, yaw)
	for sx: float in [-0.5, 0.5]:
		var p := at + b * Vector3(sx * w, 0, 0)
		kit.add(EnvKit.cyl(0.3, 0.32, h, 8), mats["lacquer"], Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)))
		kit.add(EnvKit.box(Vector3(1.0, 0.6, 1.0)), mats["stone"], Transform3D(b, p + Vector3(0, 0.3, 0)))
	kit.add(EnvKit.box(Vector3(w + 1.6, 0.5, 0.5)), mats["lacquer_dark"], Transform3D(b, at + Vector3(0, h - 0.3, 0)))
	kit.add(EnvKit.box(Vector3(w * 0.45, 0.8, 0.2)), mats["gold"], Transform3D(b, at + b * Vector3(0, 0, 0.2) + Vector3(0, h - 1.1, 0)), false)
	kit.add(EnvKit.box(Vector3(w + 0.6, 0.3, 0.4)), mats["lacquer"], Transform3D(b, at + Vector3(0, h - 1.7, 0)))
	curved_roof(kit, at + Vector3(0, h, 0), w + 2.6, 2.0, 1.0, mats["tiles"], mats["gold"], yaw)


# ================================================================== glory stage (classic arena)
## Rune obelisk with two counter-tilted floating rings and a crystal crown (primary landmark).
static func obelisk(kit: EnvKit, at: Vector3, h: float, stone: Material, trim: Material, rune: Material, crystal: Material) -> void:
	var t := Transform3D(Basis(), at)
	kit.add(EnvKit.lathe([Vector2(3.2, 0.0), Vector2(3.0, 0.8), Vector2(2.4, 1.0), Vector2(2.2, 1.8), Vector2(1.7, 2.0)], 8), stone, t)
	kit.add(EnvKit.lathe([Vector2(1.5, 2.0), Vector2(1.1, h * 0.8), Vector2(0.9, h * 0.86), Vector2(0.0, h)], 4), stone, Transform3D(Basis(UP, PI * 0.25), at))
	for k in 4:
		var a := PI * 0.5 * k
		kit.add(EnvKit.box(Vector3(0.18, h * 0.65, 0.1)), rune, Transform3D(Basis(UP, a), at + Basis(UP, a) * Vector3(0, 2.0 + h * 0.33, 1.38 - 0.22 * 0.5)), false)
	for k in 2:
		var tilt := Basis(Vector3.RIGHT, 0.35 if k == 0 else -0.5) * Basis(Vector3.FORWARD, 0.2 * (k * 2 - 1))
		var ry := h * (0.55 + k * 0.18)
		kit.add(EnvKit.lathe([Vector2(3.2 + k, -0.18), Vector2(3.45 + k, 0.0), Vector2(3.2 + k, 0.18), Vector2(2.95 + k, 0.0), Vector2(3.2 + k, -0.18)], 32), trim, Transform3D(tilt, at + Vector3(0, ry, 0)), false)
		kit.add(EnvKit.lathe([Vector2(3.0 + k, -0.04), Vector2(3.0 + k, 0.04)], 32), rune, Transform3D(tilt, at + Vector3(0, ry, 0)), false)
	kit.add(EnvKit.lathe([Vector2(0.0, -1.2), Vector2(0.9, 0.0), Vector2(0.0, 1.8)], 6), crystal, Transform3D(Basis(), at + Vector3(0, h + 1.8, 0)), false)


## Team gate arch: two pylons with a crossbeam carrying a team-colour light strip.
static func team_gate(kit: EnvKit, at: Vector3, yaw: float, w: float, h: float, stone: Material, trim: Material, light: Material) -> void:
	var b := Basis(UP, yaw)
	for sx: float in [-0.5, 0.5]:
		var p := at + b * Vector3(sx * w, 0, 0)
		pier(kit, p, Vector2(1.4, 1.4), h, stone, yaw, true)
		kit.add(EnvKit.box(Vector3(0.12, h * 0.75, 1.5)), light, Transform3D(b, p + b * Vector3(-sx * 0.72, 0, 0) + Vector3(0, h * 0.45, 0)), false)
	kit.add(EnvKit.box(Vector3(w + 1.4, 1.0, 1.2)), stone, Transform3D(b, at + Vector3(0, h - 0.5, 0)))
	kit.add(EnvKit.box(Vector3(w + 1.6, 0.18, 1.3)), trim, Transform3D(b, at + Vector3(0, h, 0)), false)
	kit.add(EnvKit.box(Vector3(w - 0.4, 0.14, 0.1)), light, Transform3D(b, at + b * Vector3(0, 0, 0.62) + Vector3(0, h - 0.6, 0)), false)


# ================================================================== graveyard
## Gravestones: kind 0 rounded slab, 1 cross, 2 obelisk, 3 broken slab. Slight random lean.
static func gravestone(kit: EnvKit, at: Vector3, yaw: float, kind: int, stone: Material, r: RandomNumberGenerator) -> void:
	var lean := Basis(UP, yaw) * Basis(Vector3.RIGHT, r.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, r.randf_range(-0.1, 0.1))
	match kind:
		0:
			var poly := PackedVector2Array([Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0.4, 0.9)])
			for i in 7:
				var a := lerpf(0.0, PI, float(i) / 6.0)
				poly.append(Vector2(cos(a) * 0.4, 0.9 + sin(a) * 0.3))
			poly.append(Vector2(-0.4, 0.9))
			kit.add(EnvKit.extrude(poly, 0.16, 0.03), stone, Transform3D(lean, at), false)
		1:
			kit.add(EnvKit.box(Vector3(0.18, 1.3, 0.16)), stone, Transform3D(lean, at + lean * Vector3(0, 0.65, 0)), false)
			kit.add(EnvKit.box(Vector3(0.7, 0.16, 0.16)), stone, Transform3D(lean, at + lean * Vector3(0, 0.95, 0)), false)
		2:
			kit.add(EnvKit.lathe([Vector2(0.3, 0.0), Vector2(0.3, 0.25), Vector2(0.18, 0.3), Vector2(0.14, 1.4), Vector2(0.0, 1.7)], 4), stone, Transform3D(lean * Basis(UP, PI * 0.25), at), false)
		_:
			kit.add(EnvKit.box(Vector3(0.75, 0.55, 0.16)), stone, Transform3D(lean, at + lean * Vector3(0, 0.27, 0)), false)
			kit.add(EnvKit.box(Vector3(0.5, 0.12, 0.6)), stone, Transform3D(Basis(UP, yaw + 0.4), at + Vector3(0.3, 0.06, 0.5)), false)
	kit.add(EnvKit.box(Vector3(0.9, 0.12, 1.6)), stone, Transform3D(Basis(UP, yaw), at + Basis(UP, yaw) * Vector3(0, 0.0, 0.8)), false)


## Iron spear fence from a to b.
static func iron_fence(kit: EnvKit, a: Vector3, b: Vector3, h: float, iron: Material, gap_every: int = 0) -> void:
	var d := b - a
	var length := Vector2(d.x, d.z).length()
	if length < 0.1:
		return
	var n := maxi(1, int(round(length / 0.35)))
	var yaw := atan2(-d.z, d.x)
	for i in n + 1:
		if gap_every > 0 and i % gap_every == gap_every - 1:
			continue
		var p := a + d * (float(i) / n)
		kit.add(EnvKit.cyl(0.025, 0.025, h, 4), iron, Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), false)
		kit.add(EnvKit.lathe([Vector2(0.05, 0.0), Vector2(0.0, 0.18)], 4), iron, Transform3D(Basis(), p + Vector3(0, h, 0)), false)
	var mid := (a + b) * 0.5
	for y: float in [h * 0.25, h * 0.85]:
		kit.add(EnvKit.box(Vector3(length, 0.05, 0.05)), iron, Transform3D(Basis(UP, yaw), mid + Vector3(0, y, 0)), false)


## Mausoleum (small crypt house): plinth, walls, pediment, columns, dark door. Faces local +Z.
static func mausoleum(kit: EnvKit, at: Vector3, yaw: float, w: float, d: float, h: float, stone: Material, dark: Material, roof: Material) -> void:
	var b := Basis(UP, yaw)
	kit.add(EnvKit.box(Vector3(w + 1.0, 0.5, d + 1.0)), stone, Transform3D(b, at + Vector3(0, 0.25, 0)))
	kit.add(EnvKit.box(Vector3(w, h, d)), stone, Transform3D(b, at + Vector3(0, 0.5 + h * 0.5, 0)))
	var ped := PackedVector2Array([Vector2(-w * 0.55, 0), Vector2(w * 0.55, 0), Vector2(0, h * 0.35)])
	kit.add(EnvKit.extrude(ped, d + 0.4), roof, Transform3D(b * Basis(UP, 0.0), at + Vector3(0, 0.5 + h, 0)))
	gothic_window(kit, at + b * Vector3(0, 0.5, d * 0.5 + 0.02), yaw, w * 0.36, h * 0.75, stone, dark)
	for sx: float in [-1.0, 1.0]:
		kit.add(EnvKit.cyl(0.18, 0.2, h, 8), stone, Transform3D(Basis(), at + b * Vector3(sx * w * 0.38, 0.5 + h * 0.5, d * 0.5 + 0.35)))


## Coffin / sarcophagus.
static func sarcophagus(kit: EnvKit, at: Vector3, yaw: float, stone: Material) -> void:
	var b := Basis(UP, yaw)
	kit.add(EnvKit.box(Vector3(0.9, 0.7, 2.1)), stone, Transform3D(b, at + Vector3(0, 0.35, 0)))
	kit.add(EnvKit.box(Vector3(1.0, 0.15, 2.2)), stone, Transform3D(b * Basis(UP, 0.12), at + Vector3(0.15, 0.78, 0.1)), false)


## Candle cluster (tiny emissive tips; no light).
static func candles(kit: EnvKit, at: Vector3, wax: Material, flame: Material, seed_i: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	for i in 5:
		var h := r.randf_range(0.15, 0.45)
		var p := at + Vector3(r.randf_range(-0.3, 0.3), 0, r.randf_range(-0.3, 0.3))
		kit.add(EnvKit.cyl(0.04, 0.045, h, 6), wax, Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), false)
		kit.add(EnvKit.lathe([Vector2(0.025, 0.0), Vector2(0.0, 0.09)], 5), flame, Transform3D(Basis(), p + Vector3(0, h, 0)), false)


# ================================================================== lava cave
## Basalt stalagmite / obsidian spire (glowing crack band optional).
static func spire(kit: EnvKit, at: Vector3, h: float, r: float, mat: Material, seed_i: int, yaw: float = 0.0, crack: Material = null) -> ArrayMesh:
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_i
	var prof: Array = [Vector2(r, 0.0)]
	var n := 6
	for i in range(1, n + 1):
		var t := float(i) / n
		prof.append(Vector2(r * (1.0 - t) * rr.randf_range(0.85, 1.1) + 0.02, h * t))
	prof[n] = Vector2(0.0, h)
	var sz := rr.randf_range(0.7, 1.0)
	var m := EnvKit.lathe(prof, 7, 1.0, sz)   # collision proxy (convex-ish), returned to the caller
	# render mesh: concave flared profile, fluted and noise-chiselled, with a slight bend
	var nz := FastNoiseLite.new()
	nz.seed = seed_i
	nz.frequency = 1.2 / r
	var rings := 18
	var seg := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var rad := r * pow(1.0 - t, 1.35) * (1.0 + 0.25 * exp(-t * 8.0)) + 0.02
		rad *= 1.0 + 0.14 * smoothstep(0.6, 0.85, fposmod(t * 4.0 + float(seed_i) * 0.37, 1.0))   # stepped strata tiers
		var bend := Vector3(sin(t * 2.0 + seed_i) * 0.25, 0, cos(t * 1.7 + seed_i) * 0.2) * h * 0.06 * t * t
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			var flute := 1.0 - 0.12 * pow(absf(sin(a * 2.5 + float(seed_i))), 4.0)
			var p := Vector3(cos(a) * rad * flute, h * t, sin(a) * rad * flute * sz)
			p += p.normalized() * nz.get_noise_3dv(p) * rad * 0.6 * (1.0 - t * 0.5)
			p.y = h * t + nz.get_noise_2d(a * 3.0, t * 5.0) * h * 0.02
			ring.append(p + bend)
		pts.append(ring)
	for i in rings:
		for j in seg:
			var a0: Vector3 = pts[i][j]
			var a1: Vector3 = pts[i][(j + 1) % seg]
			var b0: Vector3 = pts[i + 1][j]
			var b1: Vector3 = pts[i + 1][(j + 1) % seg]
			for v: Vector3 in [a0, b1, b0, a0, a1, b1]:
				st.add_vertex(v)
	st.generate_normals()
	var xf := Transform3D(Basis(UP, yaw) * Basis(Vector3(1, 0, 0.3).normalized(), rr.randf_range(-0.08, 0.08)), at)
	kit.add(st.commit(), mat, xf)
	if crack != null:
		for k in 2:
			var y := h * rr.randf_range(0.15, 0.45)
			var rad := r * pow(1.0 - y / h, 1.35) * 1.02
			kit.add(EnvKit.lathe([Vector2(rad, y - 0.04), Vector2(rad * 1.02, y), Vector2(rad, y + 0.04)], 11, 1.0, sz), crack, xf, false)
	# satellite spikes + scree around the foot
	for k in 3:
		var a := rr.randf() * TAU
		var sp := at + Vector3(cos(a), 0, sin(a)) * r * rr.randf_range(0.9, 1.3)
		var sh := h * rr.randf_range(0.08, 0.15)
		kit.add(EnvKit.lathe([Vector2(r * 0.3, 0.0), Vector2(r * 0.12, sh * 0.6), Vector2(0.0, sh)], 5), mat, Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(UP), -0.25), sp), false)
		kit.add(EnvKit.rock_mesh(r * 0.18, 0.4, seed_i + k), mat, Transform3D(Basis(), at + Vector3(cos(a + 1.0), 0.05, sin(a + 1.0)) * r * 1.4), false)
	return m


## Hexagonal basalt column cluster (organ pipes).
static func basalt_columns(kit: EnvKit, at: Vector3, mat: Material, top_mat: Material, seed_i: int, count: int = 7, h0: float = 1.0, h1: float = 4.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	for i in count:
		var p := at + Vector3(r.randf_range(-1.6, 1.6), 0, r.randf_range(-1.6, 1.6))
		var h := r.randf_range(h0, h1)
		kit.add(EnvKit.cyl(0.55, 0.6, h, 6), mat, Transform3D(Basis(UP, r.randf() * TAU), p + Vector3(0, h * 0.5 - 0.2, 0)))
		kit.add(EnvKit.cyl(0.53, 0.53, 0.06, 6), top_mat, Transform3D(Basis(UP, r.randf() * TAU), p + Vector3(0, h - 0.17, 0)), false)


## Lava fall: a ribbon of lava cascading down a wall face from `top` to `bottom` (local +Z faces out).
static func lava_fall(kit: EnvKit, top: Vector3, bottom: Vector3, w: float, lava: Material) -> void:
	var pts: Array = []
	var ws: Array = []
	var sides: Array = []
	for i in 10:
		var t := float(i) / 9.0
		var p := top.lerp(bottom, t)
		p.z += sin(t * PI) * 1.2
		pts.append(p)
		ws.append(w * (0.8 + 0.4 * t))
		sides.append(Vector3(1, 0, 0))
	kit.add(EnvKit.ribbon(pts, ws, sides, 0.3), lava, Transform3D.IDENTITY, false)
