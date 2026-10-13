extends ArenaMap
## 竞技场 Classic Arena - round 36 m duel arena: stone floor, ring wall with pillars, four LOS pillars,
## two low barricades on the flanks, spectator tiers outside the wall.

const R: float = 18.0          # inner radius of the play area
const SEGMENTS: int = 28


func _init() -> void:
	map_id = "classic_arena"
	name_cn = "竞技场"
	name_en = "Classic Arena"
	size = Vector2(36.0, 36.0)
	center = Vector3.ZERO


func _build_map() -> void:
	setup_environment({
		"sky_top": Color(0.28, 0.45, 0.75), "sky_horizon": Color(0.78, 0.74, 0.68),
		"ground": Color(0.3, 0.27, 0.22), "fog_color": Color(0.78, 0.74, 0.68), "fog_density": 0.004,
		"sun_pitch": -48.0, "sun_yaw": -30.0, "sun_energy": 1.2, "ambient_energy": 0.7,
	})
	var D := MapKit.D
	# ---- floor: stone tiles inside, dirt ring outside the wall
	var inside := func(c: Vector3) -> bool: return Vector2(c.x, c.z).length() > R + 3.5
	kit.floor_grid(Rect2(-24, -24, 48, 48), 0.0, D + "floor_tile_large.gltf", inside,
		[D + "floor_tile_big_grate.gltf"], 0.05)
	# outer ground (visual + collision far beyond the wall)
	var ground_mat := MapKit.mat(Color(0.42, 0.36, 0.28), 1.0)
	kit.box_visual(Vector3(0, -0.6, 0), Vector3(160, 1.0, 160), ground_mat, 0.0, false)
	kit.col_box(Vector3(0, -1.5, 0), Vector3(160, 3.0, 160), 0.0, "Ground")
	# central grate emblem
	kit.piece(D + "floor_tile_big_grate.gltf", Vector3(0, -0.04, 0), 45.0, Vector3.ONE, false)
	# ---- ring wall (visible) + tall boundary collision
	var wr := R + 0.5
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var p0 := Vector3(cos(a0) * wr, 0, sin(a0) * wr)
		var p1 := Vector3(cos(a1) * wr, 0, sin(a1) * wr)
		var kinds: Array = ["wall"] if i % 7 != 3 else ["wall_cracked"]
		kit.wall_line(p0, p1, kinds, 4.0, 1.0, false)
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1) + 0.6
		var yaw := rad_to_deg(atan2(-(p1.z - p0.z), p1.x - p0.x))
		kit.col_box(Vector3(mid.x, 8.0, mid.z) + mid.normalized() * 0.5, Vector3(seg_len, 16.0, 2.0), yaw, "Ring")
		kit.piece(D + "pillar.gltf", p0, rad_to_deg(-a0))
		# banners: blue on the north half (team 0, -Z), red on the south half
		if i % 2 == 1:
			var b := "banner_patternA_blue" if mid.z < -2.0 else ("banner_patternA_red" if mid.z > 2.0 else "banner_patternC_white")
			kit.piece(D + b + ".gltf", mid, yaw, Vector3.ONE, false)
	# ---- spectator tiers outside
	for tier in 3:
		var tr := R + 2.8 + tier * 2.0
		var n := int(TAU * tr / 2.0)
		for i in n:
			var a := TAU * i / n
			kit.piece(D + "floor_foundation_allsides.gltf", Vector3(cos(a) * tr, 0, sin(a) * tr), rad_to_deg(-a),
				Vector3(1.0, 0.5 + tier * 0.75, 1.0))
	# ---- four LOS pillars on the diagonals
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var p := Vector3(cos(a) * 8.0, 0, sin(a) * 8.0)
		kit.piece(D + "pillar_decorated.gltf", p, rad_to_deg(-a) + 90.0)
		kit.col_box(p + Vector3(0, 2.0, 0), Vector3(1.6, 4.0, 1.6), rad_to_deg(-a) + 90.0, "Pillar")
	# ---- low barricades on the east/west flanks (half cover: blocks movement, not jumps over)
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * 11.5, 0, 0)
		kit.piece(D + "barrier.gltf", c, 90.0)
		kit.col_box(c + Vector3(0, 0.55, 0), Vector3(4.0, 1.1, 0.5), 90.0, "Barrier")
		kit.piece(D + "barrier_column.gltf", c + Vector3(sx * 1.5, 0, 0) + Vector3(0, 0, 4.0), 90.0 - sx * 30.0)
		kit.col_box(c + Vector3(sx * 1.5, 0.7, 4.0), Vector3(4.0, 1.4, 0.7), 90.0 - sx * 30.0, "Barrier")
		kit.piece(D + "barrier_column.gltf", c + Vector3(sx * 1.5, 0, 0) + Vector3(0, 0, -4.0), 90.0 + sx * 30.0)
		kit.col_box(c + Vector3(sx * 1.5, 0.7, -4.0), Vector3(4.0, 1.4, 0.7), 90.0 + sx * 30.0, "Barrier")
	# ---- torches at the wall (E, W and near each spawn)
	for a_deg: float in [0.0, 180.0, 60.0, 120.0, 240.0, 300.0]:
		var a := deg_to_rad(a_deg)
		add_torch(Vector3(cos(a) * (R - 1.0), 0, sin(a) * (R - 1.0)), int(a_deg) % 180 == 0)
	# scenery: trees beyond the stands
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		var r := R + 13.0 + kit.rng.randf() * 4.0
		var t: String = ["Tree_1_A_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_5_A_Color1.gltf"][i % 3]
		kit.piece(MapKit.N + t, Vector3(cos(a) * r, 0, sin(a) * r), kit.rng.randf() * 360.0, Vector3.ONE * (2.0 + kit.rng.randf()))
	test_walks = [
		{"name": "spawn->center", "from": Vector3(0, 0, -13), "to": Vector3(0, 0, -1), "min_y": -1.0},
		{"name": "behind the west barricade", "from": Vector3(-15, 0, -6), "to": Vector3(-15, 0, 1), "min_y": -1.0},
	]
	# ---- spawns (team 0 north / -Z, team 1 south / +Z)
	set_spawns_line(0, Vector3(0, 0, -13.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 13.0), Vector3.RIGHT, 2.2)
