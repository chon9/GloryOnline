extends ArenaMap
## 古堡 Old Castle - 55 m team map inside ruined castle walls. Each team starts in a walled courtyard;
## a ruined curtain wall with a central gate and two side gates separates it from the middle. The middle has
## a raised keep (3 m high ground, stair ramps north and south), two side courts, and two flank corridors
## behind inner walls with doorways - lots of line-of-sight play and flanking routes.

const HALF: float = 27.5
const KEEP_H: float = 3.0


func _init() -> void:
	map_id = "old_castle"
	name_cn = "古堡"
	name_en = "Old Castle"
	size = Vector2(55.0, 55.0)
	center = Vector3.ZERO


func _build_map() -> void:
	setup_environment({
		"sky_top": Color(0.36, 0.42, 0.62), "sky_horizon": Color(0.92, 0.72, 0.55),
		"ground": Color(0.25, 0.22, 0.2), "fog_color": Color(0.85, 0.7, 0.58), "fog_density": 0.0035,
		"sun_pitch": -32.0, "sun_yaw": -60.0, "sun_energy": 1.15, "sun_color": Color(1.0, 0.86, 0.68),
		"ambient_energy": 0.7,
	})
	var D := MapKit.D
	var N := MapKit.N
	# ---- ground: flagstones inside, earth outside
	kit.floor_grid(Rect2(-28, -28, 56, 56), 0.0, D + "floor_tile_large.gltf", Callable(),
		[D + "floor_dirt_large.gltf", D + "floor_tile_big_grate.gltf"], 0.12, false)
	var earth := MapKit.mat(Color(0.36, 0.31, 0.25), 1.0)
	kit.box_visual(Vector3(0, -0.55, 0), Vector3(200, 1.0, 200), earth, 0.0, false)
	kit.col_box(Vector3(0, -1.5, 0), Vector3(200, 3.0, 200), 0.0, "Ground")
	# ---- outer castle walls (boundary): visible 4 m walls + tall collision
	var wk: Array = ["wall", "wall", "wall_cracked", "wall", "wall_arched", "wall"]
	var c := HALF + 0.5
	kit.wall_line(Vector3(-c, 0, -c), Vector3(c, 0, -c), wk, 4.0, 1.0, false)
	kit.wall_line(Vector3(c, 0, c), Vector3(-c, 0, c), wk, 4.0, 1.0, false)
	kit.wall_line(Vector3(-c, 0, c), Vector3(-c, 0, -c), wk, 4.0, 1.0, false)
	kit.wall_line(Vector3(c, 0, -c), Vector3(c, 0, c), wk, 4.0, 1.0, false)
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.piece(D + "pillar_decorated.gltf", Vector3(sx * c, 0, sz * c), 45.0, Vector3(1.6, 1.4, 1.6))
	# ---- curtain walls at z = +-14: gaps at the center gate (|x| < 3) and side gates (15 < |x| < 19)
	for sz: float in [-1.0, 1.0]:
		var z := sz * 14.0
		for seg: Vector2 in [Vector2(-HALF, -19.0), Vector2(-15.0, -3.0), Vector2(3.0, 15.0), Vector2(19.0, HALF)]:
			kit.wall_line(Vector3(seg.x, 0, z), Vector3(seg.y, 0, z), ["wall", "wall_cracked", "wall"], 4.0, 1.0)
		for gx: float in [-19.0, -15.0, -3.0, 3.0, 15.0, 19.0]:
			kit.piece(D + "pillar.gltf", Vector3(gx, 0, z))
			kit.col_box(Vector3(gx, 2.0, z), Vector3(1.5, 4.0, 1.5), 0.0, "GatePillar")
		# team banners on the courtyard side of the curtain wall
		var ban := "banner_shield_blue" if sz < 0 else "banner_shield_red"
		for bx: float in [-23.0, -9.0, 9.0, 23.0]:
			kit.piece(D + ban + ".gltf", Vector3(bx, 0.0, z), 180.0 if sz < 0 else 0.0, Vector3.ONE, false)
		# banners on the outer wall behind the spawns
		var ban2 := "banner_triple_blue" if sz < 0 else "banner_triple_red"
		for bx: float in [-12.0, -4.0, 4.0, 12.0]:
			kit.piece(D + ban2 + ".gltf", Vector3(bx, 0.0, sz * (HALF + 0.5)), 0.0 if sz < 0 else 180.0, Vector3.ONE, false)
	# ---- the keep: raised platform with stair ramps north and south, corner pillars, parapets
	kit.platform(Rect2(-6.0, -6.0, 12.0, 12.0), KEEP_H)
	kit.ramp(Vector3(0, KEEP_H, -6.0), 180.0, 8.0, 4.0)
	kit.ramp(Vector3(0, KEEP_H, 6.0), 0.0, 8.0, 4.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kit.piece(D + "pillar.gltf", Vector3(sx * 5.0, KEEP_H, sz * 5.0))
			kit.col_box(Vector3(sx * 5.0, KEEP_H + 2.0, sz * 5.0), Vector3(1.5, 4.0, 1.5), 0.0, "KeepPillar")
			kit.piece(D + "barrier.gltf", Vector3(sx * 4.0, KEEP_H, sz * 5.75), 0.0)
		kit.col_box(Vector3(sx * 4.0, KEEP_H + 0.55, -5.75), Vector3(4.0, 1.1, 0.5), 0.0, "Parapet")
		kit.col_box(Vector3(sx * 4.0, KEEP_H + 0.55, 5.75), Vector3(4.0, 1.1, 0.5), 0.0, "Parapet")
	kit.piece(D + "banner_patternB_yellow.gltf", Vector3(0, KEEP_H + 0.1, 0), 0.0, Vector3(1.4, 1.4, 1.4), false)
	kit.piece(D + "post.gltf", Vector3(0, KEEP_H, 0.45), 0.0, Vector3(1.2, 1.3, 1.2))
	kit.col_box(Vector3(0, KEEP_H + 2.6, 0.45), Vector3(0.5, 5.2, 0.5), 0.0, "FlagPost")
	# ---- inner flank walls at x = +-14 (doorway gap at |z| < 2) separating side courts from flank corridors
	for sx: float in [-1.0, 1.0]:
		var x := sx * 14.0
		kit.wall_line(Vector3(x, 0, -10.0), Vector3(x, 0, -2.0), ["wall", "wall_cracked"], 4.0, 1.0)
		kit.wall_line(Vector3(x, 0, 2.0), Vector3(x, 0, 10.0), ["wall_cracked", "wall"], 4.0, 1.0)
		for gz: float in [-10.0, -2.0, 2.0, 10.0]:
			kit.piece(D + "pillar.gltf", Vector3(x, 0, gz))
			kit.col_box(Vector3(x, 2.0, gz), Vector3(1.5, 4.0, 1.5), 0.0, "WallPillar")
		# side court cover: rubble piles
		kit.piece(D + "rubble_half.gltf", Vector3(sx * 9.0, 0, -9.5), 90.0 + 90.0 * sx)
		kit.col_hull(D + "rubble_half.gltf", MapKit.xf(Vector3(sx * 9.0, 0, -9.5), 90.0 + 90.0 * sx))
		kit.piece(D + "rubble_half.gltf", Vector3(sx * 9.5, 0, 9.0), -90.0 + 90.0 * sx)
		kit.col_hull(D + "rubble_half.gltf", MapKit.xf(Vector3(sx * 9.5, 0, 9.0), -90.0 + 90.0 * sx))
		# flank corridor cover
		var fx := sx * 21.0
		kit.wall_line(Vector3(fx, 0, -2.0), Vector3(fx, 0, 2.0), ["wall"], 4.0, 1.0)
		_crates(Vector3(sx * 24.5, 0, -7.0), 20.0 * sx)
		_crates(Vector3(sx * 17.5, 0, 6.5), -15.0 * sx)
		_barrel(Vector3(sx * 18.0, 0, -8.0))
		_barrel(Vector3(sx * 25.0, 0, 9.0))
		# beside the doorway (against the wall), not in its mouth
		add_torch(Vector3(sx * 12.9, 0, 3.2), true)
	# ---- spawn courtyards: low barricades and torches
	for sz: float in [-1.0, 1.0]:
		for bx: float in [-9.0, 9.0]:
			kit.piece(D + "barrier.gltf", Vector3(bx, 0, sz * 17.5), 0.0)
			kit.col_box(Vector3(bx, 0.55, sz * 17.5), Vector3(4.0, 1.1, 0.5), 0.0, "Barricade")
		_crates(Vector3(-20.0, 0, sz * 21.0), 10.0)
		_crates(Vector3(20.0, 0, sz * 21.5), -10.0)
		add_torch(Vector3(-4.0, 0, sz * 15.0), sz < 0)
		add_torch(Vector3(4.0, 0, sz * 15.0), sz > 0)
	# ---- outside scenery: bare trees and rocks beyond the walls
	for i in 30:
		var a := TAU * i / 30.0
		var r := HALF * 1.5 + kit.rng.randf() * 10.0
		var tp: String = ["Tree_Bare_1_A_Color1.gltf", "Tree_Bare_2_B_Color1.gltf", "Tree_4_A_Color1.gltf"][i % 3]
		kit.piece(N + tp, Vector3(cos(a) * r, 0, sin(a) * r), kit.rng.randf() * 360.0, Vector3.ONE * kit.rng.randf_range(2.0, 3.2))
	test_walks = [
		{"name": "gate + keep ramp", "from": Vector3(0, 0, -20), "to": Vector3(0, KEEP_H, -1), "min_y": KEEP_H - 0.3},
		{"name": "south keep ramp", "from": Vector3(0, 0, 20), "to": Vector3(0, KEEP_H, 1), "min_y": KEEP_H - 0.3},
		{"name": "side court doorway to flank", "from": Vector3(-10, 0, 0), "to": Vector3(-18, 0, 0), "min_y": -1.0},
		{"name": "side gate", "from": Vector3(17, 0, -20), "to": Vector3(17, 0, -9), "min_y": -1.0},
	]
	# ---- spawns
	set_spawns_line(0, Vector3(0, 0, -22.0), Vector3.RIGHT, 2.4)
	set_spawns_line(1, Vector3(0, 0, 22.0), Vector3.RIGHT, 2.4)


func _crates(p: Vector3, yaw: float) -> void:
	kit.piece(MapKit.D + "crates_stacked.gltf", p, yaw)
	kit.col_box(p + Vector3(0, 1.05, 0), Vector3(2.0, 2.1, 2.1), yaw, "Crates")


func _barrel(p: Vector3) -> void:
	kit.piece(MapKit.D + "barrel_large.gltf", p)
	kit.col_cyl(p, 0.85, 2.0)
