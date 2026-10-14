extends ArenaMap
## 古堡 Old Castle - 55 m team map inside Gothic castle ruins at golden hour (bible 4.2 Golden Ruins).
## Gameplay (unchanged): each team starts in a walled courtyard; a ruined curtain wall with a central gate and two
## side gates separates it from the middle. The middle has a raised keep (3 m high ground, stairs north and south),
## two side courts, and two flank corridors behind inner walls with doorways.
## Composition: primary landmark = the ruined cathedral facade (twin towers, rose window, one broken spire) east of
## the castle, back-lit by the low amber sun; secondaries = the keep with its golden standard, a broken round
## tower in the north-west corner, a fallen colossus head in the sand to the south-west, floating debris.
## Palette: warm sandstone / amber highlights, violet-blue shadows, dusty haze, red + blue team cloth, gold.

const HALF: float = 27.5
const KEEP_H: float = 3.0

var _m: Dictionary = {}


func _init() -> void:
	map_id = "old_castle"
	name_cn = "古堡"
	name_en = "Old Castle"
	size = Vector2(55.0, 55.0)
	center = Vector3.ZERO


func _mats() -> void:
	var shade := Color("#5A4E9A")
	_m["wall"] = EnvKit.paint(Color("#D8B88C"), Color("#8A6E5A"), {"snow_amount": 0.25, "snow_col": Color("#E8C890"), "snow_shadow_tint": Color("#8A6AA0"),
		"noise_scale": 0.6, "paint_strength": 0.35, "blocks": 0.6, "warm_amount": 0.6, "warm_col": Color("#FFC080"), "shade_tint": shade,
		"macro": 0.35, "macro_scale": 0.12})
	_m["wall_dark"] = EnvKit.paint(Color("#A8886A"), Color("#6A5048"), {"snow_amount": 0.2, "snow_col": Color("#E0C090"), "noise_scale": 0.7, "blocks": 0.5,
		"shade_tint": Color("#4A3E8A")})
	_m["floor"] = EnvKit.paint(Color("#C8A880"), Color("#9A7E66"), {"snow_amount": 0.0, "noise_scale": 0.35, "paint_strength": 0.3, "tiles": 1.6,
		"grout_col": Color("#6A5444"), "warm_amount": 0.4, "warm_col": Color("#F0C890"), "shade_tint": shade, "stroke": 0.0})
	_m["sand"] = EnvKit.paint(Color("#B89478"), Color("#7A5E58"), {"snow_amount": 0.45, "snow_col": Color("#D8BC98"), "snow_shadow_tint": Color("#7A6AA8"),
		"cover_col2": Color("#E4C8A0", 0.6), "cover_col3": Color("#A88A70", 0.45), "macro": 0.45, "macro_scale": 0.03, "ledges": 0.7,
		"noise_scale": 0.12, "paint_strength": 0.35, "strata": 0.8,
		"warm_amount": 0.5, "warm_col": Color("#FFD0A0"), "shade_tint": Color("#7A6AA8"), "stroke": 0.1})
	_m["rock"] = EnvKit.paint(Color("#B08068"), Color("#5E4450"), {"snow_amount": 0.3, "snow_col": Color("#D8B488"), "strata": 1.0, "ledges": 0.9, "noise_scale": 0.25, "macro": 0.3,
		"warm_amount": 0.6, "warm_col": Color("#FFB070"), "shade_tint": shade})
	_m["gold"] = EnvKit.paint(Color("#E8C060"), Color("#A07030"), {"snow_amount": 0.0, "noise_scale": 2.0, "paint_strength": 0.15, "shade_tint": Color("#8A5A2B"), "stroke": 0.0})
	_m["wood"] = EnvKit.paint(Color("#8A6040"), Color("#5A3A2A"), {"snow_amount": 0.0, "noise_scale": 2.5, "paint_strength": 0.3, "shade_tint": Color("#4A3A5A")})
	_m["iron"] = EnvKit.paint(Color("#4A4450"), Color("#2A262E"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#2A2A4A"), "stroke": 0.0})
	_m["glass"] = EnvKit.glow(Color("#FFB45C"), 1.8)
	_m["dark"] = EnvKit.paint(Color("#3A2E3A"), Color("#241C26"), {"snow_amount": 0.0, "noise_scale": 1.0, "shade_tint": Color("#2A2040")})
	_m["leaves"] = EnvKit.foliage("leaves_gold.png", Color(1, 1, 1), Color(0.6, 0.4, 0.62), Color(1.0, 0.8, 0.5))
	_m["leaf_core"] = EnvKit.paint(Color("#B86A2A"), Color("#7A3A1E"), {"snow_amount": 0.0, "noise_scale": 1.2, "shade_tint": Color("#5A3060"), "stroke": 0.0})
	_m["bark"] = EnvKit.paint(Color("#5A4038"), Color("#3A2828"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#3A2A4A")})
	_m["flame"] = EnvKit.glow(Color("#FFA040"), 3.2)


func _build_map() -> void:
	setup_atmosphere("golden_ruins")
	_mats()
	_ground()
	_outer_walls()
	_curtain_walls()
	_keep()
	_flanks()
	_courtyards()
	_landmarks()
	env.particles(Vector3(0, 4, 0), Vector3(30, 4, 30), 240, 9.0, Color("#FFD9A0"), 0.07, Vector3(0.5, 0.1, -0.2), "spark", 1.8)
	env.particles(Vector3(0, 1.0, 0), Vector3(30, 0.8, 30), 120, 6.0, Color("#E8C090"), 0.25, Vector3(1.2, 0.05, -0.4), "dot", 0.3)
	test_walks = [
		{"name": "gate + keep ramp", "from": Vector3(0, 0, -20), "to": Vector3(0, KEEP_H, -1), "min_y": KEEP_H - 0.3},
		{"name": "south keep ramp", "from": Vector3(0, 0, 20), "to": Vector3(0, KEEP_H, 1), "min_y": KEEP_H - 0.3},
		{"name": "side court doorway to flank", "from": Vector3(-10, 0, 0), "to": Vector3(-18, 0, 0), "min_y": -1.0},
		{"name": "side gate", "from": Vector3(17, 0, -20), "to": Vector3(17, 0, -9), "min_y": -1.0},
	]
	set_spawns_line(0, Vector3(0, 0, -22.0), Vector3.RIGHT, 2.4)
	set_spawns_line(1, Vector3(0, 0, 22.0), Vector3.RIGHT, 2.4)


func _height(x: float, z: float) -> float:
	var d := maxf(absf(x) - (HALF + 1.5), maxf(absf(z) - (HALF + 1.5), 0.0))
	var n := env.noise.get_noise_2d(x, z)
	if d <= 0.0:
		return -0.04
	# sand drifts against the outer walls, then dunes and a mesa ridge far out
	var drift := exp(-pow((d - 1.5) / 2.5, 2.0)) * 1.6
	var dunes := (sin(x * 0.07 + n * 2.0) * 0.5 + 0.5) * 4.0 * smoothstep(4.0, 30.0, d)
	# wind-cut dune crests (sharp ridgelines) + rock mesas with stepped strata breaking the sand sea
	dunes += pow(1.0 - absf(env.noise.get_noise_2d(x * 0.9 + 120.0, z * 0.5)), 4.0) * 5.0 * smoothstep(8.0, 30.0, d)
	var mesa := clampf(env.noise.get_noise_2d(x * 0.45 + 500.0, z * 0.45) * 3.0 - 0.9, 0.0, 1.0) * smoothstep(18.0, 40.0, d)
	dunes += EnvKit.terrace(mesa * 16.0, 4.0, 0.25)
	var ridge := smoothstep(45.0, 90.0, d) * 22.0 * (0.6 + 0.4 * env.noise.get_noise_2d(x * 0.5, z * 0.5 + 70.0))
	return drift + dunes + ridge + n * 1.5 * smoothstep(0.0, 10.0, d)


func _ground() -> void:
	kit.col_box(Vector3(0, -1.5, 0), Vector3(200, 3.0, 200), 0.0, "Ground")
	env.add(EnvKit.box(Vector3(2.0 * HALF + 2.0, 0.1, 2.0 * HALF + 2.0)), _m["floor"], Transform3D(Basis(), Vector3(0, -0.05, 0)), false)
	var inner := func(x: float, z: float) -> bool: return absf(x) < HALF + 0.5 and absf(z) < HALF + 0.5
	env.terrain(Rect2(-140, -140, 280, 280), 2.0, _height, _m["sand"], Rect2(), 0.06, inner)
	# sand drifts creeping over the courtyard edges and rubble in the corners (soft edges, bible 4.3.7)
	for i in 40:
		var side := i % 4
		var t := env.rng.randf_range(-HALF + 1.0, HALF - 1.0)
		var p: Vector3
		match side:
			0: p = Vector3(t, 0, -HALF + 0.8)
			1: p = Vector3(t, 0, HALF - 0.8)
			2: p = Vector3(-HALF + 0.8, 0, t)
			_: p = Vector3(HALF - 0.8, 0, t)
		if absf(p.x) < 6.0:
			continue
		env.add(EnvKit.sphere(1.0, 10), _m["sand"], Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU).scaled(Vector3(env.rng.randf_range(1.5, 3.0), 0.35, env.rng.randf_range(0.8, 1.4))), p - Vector3(0, 0.1, 0)), false)
	env.backdrop({"haze": Color("#F8D8B0"), "far_col": Color("#E0A880"), "mid_col": Color("#B07A68"), "near_col": Color("#7A5A68"),
		"snow_col": Color("#FFE0B0"), "warm_col": Color("#FFB070"), "snow_caps": 0.0, "strata": 1.0, "h_scale": 0.5})


func _outer_walls() -> void:
	var c := HALF + 0.5
	var corners := [Vector3(-c, 0, -c), Vector3(c, 0, -c), Vector3(c, 0, c), Vector3(-c, 0, c)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		EnvProps.gothic_wall(env, a, b, 5.0, 1.4, _m["wall"], 300 + i, 0.45, true, true, _m["wall_dark"], _m["dark"])
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	# corner towers (the NW one is the tall broken landmark tower)
	for i in 4:
		var p: Vector3 = corners[i]
		var tall := i == 0
		var h := 16.0 if tall else 8.0
		env.add(EnvKit.lathe([Vector2(3.2, 0.0), Vector2(2.9, 1.0), Vector2(2.7, h), Vector2(3.1, h + 0.4), Vector2(3.1, h + 1.4)], 12), _m["wall"], Transform3D(Basis(), p))
		for k in 6:
			var a := TAU * k / 6.0
			if tall and k == 2:
				continue
			env.add(EnvKit.box(Vector3(1.0, 1.0, 0.7)), _m["wall"], Transform3D(Basis(Vector3.UP, -a), p + Vector3(cos(a), 0, sin(a)) * 2.8 + Vector3(0, h + 1.9, 0)), false)
		if tall:
			env.add(EnvKit.rock_mesh(2.4, 0.5, 88), _m["wall"], Transform3D(Basis().scaled(Vector3(1.2, 0.6, 1.2)), p + Vector3(0.5, h + 1.6, 0.5)), false)
			for k in 3:
				EnvProps.gothic_window(env, p + Basis(Vector3.UP, PI * 0.75) * Vector3(0, 4.0 + k * 4.0, 3.0), PI * 0.75, 1.0, 2.4, _m["wall_dark"], _m["glass"] if k == 1 else _m["dark"])


func _curtain_walls() -> void:
	for sz: float in [-1.0, 1.0]:
		var z := sz * 14.0
		for seg: Vector2 in [Vector2(-HALF, -19.0), Vector2(-15.0, -3.0), Vector2(3.0, 15.0), Vector2(19.0, HALF)]:
			EnvProps.gothic_wall(env, Vector3(seg.x, 0, z), Vector3(seg.y, 0, z), 4.0, 1.0, _m["wall"], int(seg.x * 7.0 + z), 0.5, true, false, _m["wall_dark"], _m["dark"])
			kit.col_box(Vector3((seg.x + seg.y) * 0.5, 2.0, z), Vector3(absf(seg.y - seg.x), 4.0, 1.0), 0.0, "Wall")
		for gx: float in [-19.0, -15.0, -3.0, 3.0, 15.0, 19.0]:
			EnvProps.pier(env, Vector3(gx, 0, z), Vector2(1.5, 1.5), 5.2 if absf(gx) == 3.0 else 4.6, _m["wall_dark"], 0.0, true)
			kit.col_box(Vector3(gx, 2.0, z), Vector3(1.5, 4.0, 1.5), 0.0, "GatePillar")
		# central gate arch (pointed, high above head height)
		var arch := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var a := lerpf(PI, PI / 3.0, t)
			arch.append(Vector2(3.0, 5.2) + Vector2(cos(a), sin(a)) * 6.0)
		for i in 9:
			var t := float(i) / 8.0
			var a := lerpf(PI * 2.0 / 3.0, 0.0, t)
			arch.append(Vector2(-3.0, 5.2) + Vector2(cos(a), sin(a)) * 6.0)
		var outer := PackedVector2Array([Vector2(-3.8, 5.2), Vector2(-3.8, 11.5), Vector2(3.8, 11.5), Vector2(3.8, 5.2)])
		var shape := Geometry2D.clip_polygons(outer, arch)
		for poly: PackedVector2Array in shape:
			env.add(EnvKit.extrude(poly, 1.2, 0.08), _m["wall"], Transform3D(Basis(), Vector3(0, 0, z)))
		# team banners hanging on the courtyard side of the curtain wall
		var tex := "banner_blue.png" if sz < 0 else "banner_red.png"
		for bx: float in [-23.0, -9.0, 9.0, 23.0]:
			EnvProps.wall_banner(env, Vector3(bx, 3.8, z + sz * 0.55), 0.0 if sz > 0 else PI, 3.2, tex, Color.WHITE, _m["gold"])
		for bx: float in [-12.0, -4.0, 4.0, 12.0]:
			EnvProps.wall_banner(env, Vector3(bx, 4.6, sz * (HALF - 0.2)), PI if sz > 0 else 0.0, 3.8, tex, Color.WHITE, _m["gold"])


func _keep() -> void:
	var rect := Rect2(-6.0, -6.0, 12.0, 12.0)
	kit.platform_col(rect, KEEP_H)
	EnvProps.plinth(env, rect, 0.0, KEEP_H, _m["wall"], _m["floor"], _m["gold"])
	var gap := func(p: Vector3) -> bool: return absf(p.x) < 2.6 and absf(p.z) > 5.0
	EnvProps.plinth_trim(env, rect, 0.0, KEEP_H, _m["wall_dark"], _m["dark"], gap)
	kit.ramp(Vector3(0, KEEP_H, -6.0), 180.0, 8.0, 4.0, 0.0, false)
	kit.ramp(Vector3(0, KEEP_H, 6.0), 0.0, 8.0, 4.0, 0.0, false)
	EnvProps.stairs(env, Vector3(0, KEEP_H, -6.0), 180.0, 8.0, 4.0, 0.0, _m["floor"], _m["wall_dark"])
	EnvProps.stairs(env, Vector3(0, KEEP_H, 6.0), 0.0, 8.0, 4.0, 0.0, _m["floor"], _m["wall_dark"])
	var hs := [5.2, 3.0, 4.4, 2.2]
	var k := 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			EnvProps.column(env, Vector3(sx * 5.0, KEEP_H, sz * 5.0), hs[k], _m["wall"], 600 + k, 0.62)
			kit.col_box(Vector3(sx * 5.0, KEEP_H + 2.0, sz * 5.0), Vector3(1.5, 4.0, 1.5), 0.0, "KeepPillar")
			var pc := Vector3(sx * 4.0, KEEP_H, sz * 5.75)
			env.add(EnvKit.box(Vector3(4.0, 1.1, 0.5)), _m["wall"], Transform3D(Basis(), pc + Vector3(0, 0.55, 0)))
			env.add(EnvKit.box(Vector3(4.1, 0.14, 0.62)), _m["gold"], Transform3D(Basis(), pc + Vector3(0, 1.12, 0)), false)
			k += 1
		kit.col_box(Vector3(sx * 4.0, KEEP_H + 0.55, -5.75), Vector3(4.0, 1.1, 0.5), 0.0, "Parapet")
		kit.col_box(Vector3(sx * 4.0, KEEP_H + 0.55, 5.75), Vector3(4.0, 1.1, 0.5), 0.0, "Parapet")
	# golden standard on the keep
	EnvProps.banner(env, Vector3(0, KEEP_H, 0.45), "banner_red.png", Color("#FFD27A"), 5.2, _m["iron"], _m["gold"])
	env.add(EnvKit.cyl(0.6, 0.8, 0.5, 8), _m["wall_dark"], Transform3D(Basis(), Vector3(0, KEEP_H + 0.25, 0.45)))
	kit.col_box(Vector3(0, KEEP_H + 2.6, 0.45), Vector3(0.5, 5.2, 0.5), 0.0, "FlagPost")
	for p: Vector3 in [Vector3(-2.5, KEEP_H, -3.0), Vector3(2.5, KEEP_H, 3.0)]:
		EnvProps.brazier(env, p, _m["wall_dark"], _m["iron"], _m["flame"])
		kit.col_cyl(p, 0.45, 1.4)
	add_omni(Vector3(0, KEEP_H + 2.5, 0), Color("#FFB45C"), 1.8, 12.0)


func _flanks() -> void:
	for sx: float in [-1.0, 1.0]:
		var x := sx * 14.0
		EnvProps.gothic_wall(env, Vector3(x, 0, -10.0), Vector3(x, 0, -2.0), 4.0, 1.0, _m["wall"], 400 + int(sx), 0.4, true, false, _m["wall_dark"], _m["dark"])
		EnvProps.gothic_wall(env, Vector3(x, 0, 2.0), Vector3(x, 0, 10.0), 4.0, 1.0, _m["wall"], 410 + int(sx), 0.4, true, false, _m["wall_dark"], _m["dark"])
		kit.col_box(Vector3(x, 2.0, -6.0), Vector3(8.0, 4.0, 1.0), 90.0, "Wall")
		kit.col_box(Vector3(x, 2.0, 6.0), Vector3(8.0, 4.0, 1.0), 90.0, "Wall")
		for gz: float in [-10.0, -2.0, 2.0, 10.0]:
			EnvProps.pier(env, Vector3(x, 0, gz), Vector2(1.5, 1.5), 4.6, _m["wall_dark"])
			kit.col_box(Vector3(x, 2.0, gz), Vector3(1.5, 4.0, 1.5), 0.0, "WallPillar")
		# side court cover: rubble heaps (convex hulls)
		_rubble(Vector3(sx * 9.0, 0, -9.5), 2.2, 700 + int(sx))
		_rubble(Vector3(sx * 9.5, 0, 9.0), 2.2, 710 + int(sx))
		# flank corridor cover
		var fx := sx * 21.0
		EnvProps.gothic_wall(env, Vector3(fx, 0, -2.0), Vector3(fx, 0, 2.0), 4.0, 1.0, _m["wall"], 420 + int(sx), 0.2, true, false, _m["wall_dark"], _m["dark"])
		kit.col_box(Vector3(fx, 2.0, 0.0), Vector3(4.0, 4.0, 1.0), 90.0, "Wall")
		_crates(Vector3(sx * 24.5, 0, -7.0), 20.0 * sx)
		_crates(Vector3(sx * 17.5, 0, 6.5), -15.0 * sx)
		_barrel(Vector3(sx * 18.0, 0, -8.0))
		_barrel(Vector3(sx * 25.0, 0, 9.0))
		var tp := Vector3(sx * 12.9, 0, 3.2)
		EnvProps.brazier(env, tp, _m["wall_dark"], _m["iron"], _m["flame"])
		kit.col_cyl(tp, 0.45, 1.5)
		add_omni(tp + Vector3(0, 2.2, 0), Color("#FFA040"), 1.5, 8.0)


func _rubble(p: Vector3, r: float, seed_i: int) -> void:
	var m := EnvKit.rock_mesh(r, 0.35, seed_i)
	var t := Transform3D(Basis(Vector3.UP, float(seed_i)).scaled(Vector3(1.0, 0.55, 1.0)), p)
	env.add(m, _m["wall"], t)
	var cs := env.col_hull(m, t, "Hull")
	cs.name = "Hull%d" % kit.shape_count
	kit.shape_count += 1
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_i
	for i in 5:
		var a := rr.randf() * TAU
		env.add(EnvKit.box(Vector3(rr.randf_range(0.5, 0.9), rr.randf_range(0.4, 0.6), rr.randf_range(0.6, 1.0))), _m["wall"],
			Transform3D(Basis.from_euler(Vector3(rr.randf() * 0.5, a, rr.randf() * 0.5)), p + Vector3(cos(a), 0.15, sin(a)) * (r + 0.4)), false)


func _crates(p: Vector3, yaw: float) -> void:
	EnvProps.crates(env, p, deg_to_rad(yaw), _m["wood"], _m["iron"], int(p.x * 3.0 + p.z))
	kit.col_box(p + Vector3(0, 1.05, 0), Vector3(2.0, 2.1, 2.1), yaw, "Crates")


func _barrel(p: Vector3) -> void:
	env.add(EnvKit.lathe([Vector2(0.0, 0.0), Vector2(0.75, 0.0), Vector2(0.85, 1.0), Vector2(0.75, 2.0), Vector2(0.0, 2.0)], 12), _m["wood"], Transform3D(Basis(), p))
	for y: float in [0.35, 1.65]:
		env.add(EnvKit.lathe([Vector2(0.82, y - 0.06), Vector2(0.82, y + 0.06)], 12), _m["iron"], Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0)), p), false)
	kit.col_cyl(p, 0.85, 2.0)


func _courtyards() -> void:
	for sz: float in [-1.0, 1.0]:
		for bx: float in [-9.0, 9.0]:
			var p := Vector3(bx, 0, sz * 17.5)
			env.add(EnvKit.box(Vector3(4.0, 1.1, 0.5)), _m["wall"], Transform3D(Basis(), p + Vector3(0, 0.55, 0)))
			env.add(EnvKit.box(Vector3(4.1, 0.14, 0.62)), _m["gold"], Transform3D(Basis(), p + Vector3(0, 1.12, 0)), false)
			kit.col_box(Vector3(bx, 0.55, sz * 17.5), Vector3(4.0, 1.1, 0.5), 0.0, "Barricade")
		_crates(Vector3(-20.0, 0, sz * 21.0), 10.0)
		_crates(Vector3(20.0, 0, sz * 21.5), -10.0)
		for tx: float in [-4.0, 4.0]:
			var tp := Vector3(tx, 0, sz * 15.0)
			EnvProps.brazier(env, tp, _m["wall_dark"], _m["iron"], _m["flame"])
			kit.col_cyl(tp, 0.45, 1.5)
		add_omni(Vector3(0, 2.2, sz * 15.0), Color("#FFA040"), 1.4, 9.0)
		# golden autumn trees in the courtyard corners
		for cx: float in [-24.0, 24.0]:
			var tp := Vector3(cx, 0, sz * 25.0)
			EnvProps.broadleaf(env, tp, 7.0, {"bark": _m["bark"], "core": _m["leaf_core"], "cards": _m["leaves"]}, 800 + int(cx + sz * 3.0), 5, 2.0, 5, 0.6)
			kit.col_cyl(tp, 0.4, 3.0)


func _landmarks() -> void:
	# primary: ruined cathedral east of the castle, facing west toward the keep (back-lit by the low sun)
	var cat := Vector3(58.0, _height(58.0, -6.0) - 0.5, -6.0)
	EnvProps.cathedral(env, cat, -PI * 0.5, _m["wall"], _m["dark"], _m["glass"], 1.25)
	add_omni(cat + Vector3(-4.0, 16.0, 0.0), Color("#FFB45C"), 3.0, 26.0)
	# toppled colossal column in the sand (south-west), drums rolled apart
	var cp := Vector3(-42.0, _height(-42.0, 30.0) + 1.2, 30.0)
	for i in 4:
		var dp := cp + Basis(Vector3.UP, 0.7) * Vector3(i * 4.6 + (0.4 if i > 1 else 0.0), 0, sin(i * 1.7) * 0.8)
		dp.y = _height(dp.x, dp.z) + 1.4
		env.add(EnvKit.lathe([Vector2(1.7, -2.1), Vector2(1.8, 0.0), Vector2(1.7, 2.1)], 14), _m["wall"], Transform3D(Basis(Vector3.UP, 0.7 + i * 0.12) * Basis(Vector3.FORWARD, PI * 0.5), dp))
	env.add(EnvKit.box(Vector3(5.0, 1.6, 5.0)), _m["wall"], Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, 0.2), cp + Vector3(-4.0, -0.4, -2.0)))
	env.add(EnvKit.lathe([Vector2(2.4, 0.0), Vector2(1.8, 1.2), Vector2(1.7, 2.6)], 14), _m["wall"], Transform3D(Basis(), cp + Vector3(-4.0, 0.2, -2.0)))
	# broken flying buttress arcs and floating debris over the dunes behind the cathedral
	for i in 9:
		var p := cat + Vector3(env.rng.randf_range(-12, 6), env.rng.randf_range(10, 30), env.rng.randf_range(-24, 24))
		env.add(EnvKit.box(Vector3(env.rng.randf_range(0.8, 2.0), env.rng.randf_range(0.6, 1.4), env.rng.randf_range(0.8, 2.0))), _m["wall"],
			Transform3D(Basis.from_euler(Vector3(env.rng.randf() * TAU, env.rng.randf() * TAU, 0)), p), false)
	# ruined outbuildings + golden trees on the dunes
	for i in 16:
		var a := env.rng.randf() * TAU
		var d := env.rng.randf_range(40.0, 80.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if Vector2(p.x - 58.0, p.z + 6.0).length() < 20.0:
			continue
		p.y = _height(p.x, p.z) - 0.3
		if i % 2 == 0:
			EnvProps.broadleaf(env, p, env.rng.randf_range(7.0, 11.0), {"bark": _m["bark"], "core": _m["leaf_core"], "cards": _m["leaves"]}, 1600 + i, 4, 2.4, 4, 0.7)
		else:
			EnvProps.gothic_wall(env, p, p + Basis(Vector3.UP, a) * Vector3(env.rng.randf_range(6.0, 12.0), 0, 0), env.rng.randf_range(3.0, 7.0), 1.2, _m["wall"], 1700 + i, 0.8, false, true, _m["wall_dark"], _m["dark"])
	# edge clutter just outside the outer walls: rubble spills, scrub, sunk masonry
	var scrub := EnvKit.foliage("leaves_gold.png", Color(0.8, 0.7, 0.55), Color(0.55, 0.4, 0.6), Color(1.0, 0.8, 0.5), 0.03)
	for i in 70:
		var side := i % 4
		var t := env.rng.randf_range(-HALF - 3.0, HALF + 3.0)
		var out := env.rng.randf_range(2.6, 8.0)
		var p: Vector3
		match side:
			0: p = Vector3(t, 0, -HALF - out)
			1: p = Vector3(t, 0, HALF + out)
			2: p = Vector3(-HALF - out, 0, t)
			_: p = Vector3(HALF + out, 0, t)
		p.y = _height(p.x, p.z) - 0.1
		match i % 3:
			0:
				EnvProps.rock(env, p, env.rng.randf_range(0.5, 1.5), _m["rock"], 2100 + i, env.rng.randf() * TAU, 0.8)
			1:
				EnvProps.shrub(env, p, env.rng.randf_range(0.9, 1.5), {"cards": scrub}, 2200 + i)
			_:
				env.add(EnvKit.box(Vector3(env.rng.randf_range(0.8, 1.6), env.rng.randf_range(0.5, 0.9), env.rng.randf_range(0.6, 1.0))), _m["wall"],
					Transform3D(Basis.from_euler(Vector3(env.rng.randf() * 0.4, env.rng.randf() * TAU, env.rng.randf() * 0.4)), p), false)
	for i in 30:
		var a := env.rng.randf() * TAU
		var d := env.rng.randf_range(34.0, 70.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		EnvProps.rock(env, p + Vector3(0, _height(p.x, p.z) - 0.4, 0), env.rng.randf_range(0.8, 2.6), _m["rock"], 1800 + i, env.rng.randf() * TAU)
