extends DungeonBase
## 埋骨之地 Burial Grounds (Boneyard): a moonlit graveyard of the undead (bible 4.2 Night Canyon palette: cyan
## moon key, violet fill, violet soul-fire accent). Gate yard -> graveyard gate -> altar of the dead -> the Bone
## Champion's hall -> the ruined chapel courtyard where the Black Knight (黑骑士) waits with his necromancers.
## Composition: primary landmark = the ruined chapel (twin towers, broken rose window) silhouetted against a huge
## moon at the end of the path; secondaries = the dead great tree over the altar, mausoleums along the walls, the
## bell-tower stump. Warm lanterns mark the path (objective), cold violet soul fires mark the fights (danger).
## Gameplay contract unchanged: same rooms / encounters / checkpoints, floor at y 0 on every walkable cell
## (per-room collision slabs), walls on every boundary edge, corner piers, obstacles at the same spots.

const LANTERN_C := Color(1.0, 0.72, 0.4)
const SOUL_C := Color(0.7, 0.48, 1.0)

var _m: Dictionary = {}


func _init() -> void:
	map_id = "boneyard"
	name_cn = "埋骨之地"
	name_en = "Burial Grounds"
	map_kind = "raid"


func define_layout() -> void:
	var start := rect(-8, 8, 0, 16)
	var c1 := rect(-4, 4, -12, 0)
	var r1 := rect(-12, 12, -36, -12)
	var c2 := rect(-4, 4, -48, -36)
	var r2 := rect(-16, 16, -72, -48)
	var c3 := rect(-4, 4, -84, -72)
	var r3 := rect(-12, 12, -108, -84)
	var c4 := rect(-4, 4, -120, -108)
	var boss := rect(-20, 20, -160, -120)
	rooms = [start, c1, r1, c2, r2, c3, r3, c4, boss]
	spawn_center = Vector3(0, 0, 9)
	encounters = [
		encounter("graveyard_gate", "墓园之门", "Graveyard Gate", Vector3(0, 0, -26), 11.0,
			["skeleton_guard", "skeleton_grunt", "skeleton_grunt", "skeleton_crossbow"], false, r1),
		encounter("altar_of_dead", "亡灵祭坛", "Altar of the Dead", Vector3(0, 0, -62), 12.0,
			["skeleton_guard", "skeleton_rogue", "skeleton_mage", "necromancer", "skeleton_crossbow"], false, r2),
		encounter("bone_champion", "骨甲统领", "Bone Champion", Vector3(0, 0, -98), 11.0,
			["bone_champion", "skeleton_crossbow", "skeleton_mage", "skeleton_rogue"], false, r3),
		encounter("black_knight", "黑骑士", "Black Knight", Vector3(0, 0, -144), 16.0,
			["black_knight"], true, boss),
	]
	fit_bounds(2.0)


func _mats() -> void:
	var shade := Color("#2E2A6A")
	# dead-grass hills over stratified night rock: straw / sage / bare-earth patches, ledged crags, damp hollows
	_m["ground"] = EnvKit.paint(Color("#5E5C80"), Color("#2C2A48"), {"snow_amount": 0.42, "snow_col": Color("#58564E"), "snow_shadow_tint": Color("#26265A"),
		"snow_sharp": 0.12, "strata": 1.0, "ledges": 0.9, "noise_scale": 0.3, "paint_strength": 0.55, "warm_amount": 0.3, "warm_col": Color("#8A70A8"),
		"shade_tint": shade, "stroke": 0.3, "cover_col2": Color("#3E4A44", 0.7), "cover_col3": Color("#3A3040", 0.6), "macro": 0.6, "macro_scale": 0.035,
		"use_vertex_masks": 1.0, "wear_col": Color("#4E4658"), "rim_amount": 0.25, "rim_col": Color("#8FD0FF")})
	_m["twig"] = EnvKit.paint(Color("#3A3444"), Color("#221E2A"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#1E1A3A"), "rim_amount": 0.6, "rim_col": Color("#8FD0FF")})
	_m["litter"] = EnvKit.foliage("leaves_violet.png", Color(0.7, 0.7, 0.85), Color(0.35, 0.3, 0.7), Color(0.6, 0.85, 1.0), 0.0)
	_m["path"] = EnvKit.paint(Color("#6E6A84"), Color("#4A465E"), {"snow_amount": 0.0, "noise_scale": 0.6, "paint_strength": 0.35, "tiles": 1.3,
		"grout_col": Color("#24223A"), "warm_amount": 0.3, "warm_col": Color("#7A9A80"), "shade_tint": shade, "stroke": 0.0})
	_m["stone"] = EnvKit.paint(Color("#8A86A0"), Color("#4E4A66"), {"snow_amount": 0.25, "snow_col": Color("#5A7A70"), "noise_scale": 0.8, "paint_strength": 0.35,
		"blocks": 0.55, "warm_amount": 0.4, "warm_col": Color("#7AA090"), "shade_tint": shade, "rim_amount": 0.4, "rim_col": Color("#9FD8FF")})
	_m["grave"] = EnvKit.paint(Color("#9A98B0"), Color("#5E5A78"), {"snow_amount": 0.3, "snow_col": Color("#6A8A7A"), "noise_scale": 1.6, "paint_strength": 0.3,
		"shade_tint": shade, "rim_amount": 0.5, "rim_col": Color("#9FD8FF"), "stroke": 0.0})
	_m["rock"] = EnvKit.paint(Color("#4A4E7A"), Color("#2A2C4E"), {"snow_amount": 0.3, "snow_col": Color("#3E5070"), "strata": 1.0, "noise_scale": 0.3,
		"warm_amount": 0.4, "warm_col": Color("#7A6AB0"), "shade_tint": Color("#24205A"), "rim_amount": 0.4, "rim_col": Color("#8FD0FF")})
	_m["bark"] = EnvKit.paint(Color("#2E2838"), Color("#1A1622"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#1E1A3A"), "rim_amount": 0.6, "rim_col": Color("#8FD0FF")})
	_m["iron"] = EnvKit.paint(Color("#2A2834"), Color("#16141C"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#1A1830"), "stroke": 0.0, "rim_amount": 0.5, "rim_col": Color("#8FD0FF")})
	_m["dark"] = EnvKit.paint(Color("#1E1A2A"), Color("#120E1A"), {"snow_amount": 0.0, "noise_scale": 1.0, "shade_tint": Color("#100C20")})
	_m["wood"] = EnvKit.paint(Color("#5A4848"), Color("#3A2E32"), {"snow_amount": 0.0, "noise_scale": 2.5, "paint_strength": 0.3, "shade_tint": Color("#2A2240")})
	_m["glass"] = EnvKit.glow(Color("#B37BFF"), 1.6)
	_m["soul"] = EnvKit.glow(Color("#C08AFF"), 3.0)
	_m["warm"] = EnvKit.glow(Color("#FFC070"), 3.0)
	_m["wax"] = EnvKit.paint(Color("#D8D0C0"), Color("#A8A090"), {"snow_amount": 0.0, "noise_scale": 3.0, "stroke": 0.0})
	_m["leaves"] = EnvKit.foliage("leaves_violet.png", Color(0.8, 0.8, 0.95), Color(0.35, 0.3, 0.7), Color(0.6, 0.85, 1.0))
	_m["bone"] = EnvKit.paint(Color("#D8D2C0"), Color("#9A9280"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": shade, "stroke": 0.0})


func _h(x: float, z: float) -> float:
	var d := dist_to_walkable(Vector3(x, 0, z))
	var n := env.noise.get_noise_2d(x, z)
	if d <= 0.0:
		return 0.01
	var bank := smoothstep(0.0, 5.0, d) * (0.8 + n * 0.5)
	# hummocky graveyard ground with damp hollows, then terraced crags rising to sharp ridgelines
	var hollow := minf(env.noise.get_noise_2d(x * 1.4 + 11.0, z * 1.4), 0.0) * 2.2 * smoothstep(4.0, 10.0, d)
	var hills := smoothstep(8.0, 34.0, d) * (8.0 + env.noise.get_noise_2d(x * 1.5 + 90.0, z * 1.5) * 7.0)
	hills = lerpf(hills, EnvKit.terrace(hills, 2.6, 0.3), 0.75)
	var ridge := pow(1.0 - absf(env.noise.get_noise_2d(x * 0.7 + 300.0, z * 0.7)), 3.0) * 16.0 * smoothstep(26.0, 50.0, d)
	var cliffs := smoothstep(30.0, 50.0, d) * 14.0
	return bank + hills + ridge + cliffs + hollow + n * 0.8 * smoothstep(3.0, 12.0, d)


## g = hollow darkness (mist pools sit in them), r = trodden earth along the outside of the graveyard walls.
func _mask(x: float, z: float) -> Color:
	var d := dist_to_walkable(Vector3(x, 0, z))
	var hol := clampf(-env.noise.get_noise_2d(x * 1.4 + 11.0, z * 1.4) * 1.4, 0.0, 0.6) * smoothstep(4.0, 10.0, d)
	var wear := smoothstep(2.2, 0.6, d) * 0.8 if d > 0.0 else 0.0
	return Color(wear, hol, 0.0, 1.0)


func build_ground() -> void:
	_mats()
	floor_collision()
	var r := Rect2(Vector2(center.x - size.x * 0.5 - 55.0, center.z - size.y * 0.5 - 55.0), Vector2(size.x + 110.0, size.y + 110.0))
	env.terrain(r, 1.4, _h, _m["ground"], Rect2(), 0.1, Callable(), true, false, _mask)
	for rr: Rect2 in rooms:
		var corridor := rr.size.x <= 8.0
		var inset := 0.4 if corridor else 1.6
		env.add(EnvKit.box(Vector3(rr.size.x - inset * 2.0, 0.03, rr.size.y - (0.0 if corridor else inset * 2.0))), _m["path"],
			Transform3D(Basis(), Vector3(rr.get_center().x, 0.0, rr.get_center().y)), false)


func build_boundary() -> void:
	edge_collision()
	var i := 0
	for e: Dictionary in edges:
		var p: Vector3 = e["pos"]
		var inward: Vector3 = e["inward"]
		var side := Vector3(inward.z, 0, -inward.x)
		var a := p - side * 2.0
		var b := p + side * 2.0
		# low ruined graveyard wall with an iron spear fence on top (keeps the moonlit vista open)
		var hh := 1.0 + 0.5 * float((i * 7) % 3) * 0.5
		EnvProps.gothic_wall(env, a - inward * 0.2, b - inward * 0.2, hh, 0.7, _m["stone"], 900 + i, 0.5, false, false)
		EnvProps.iron_fence(env, a - inward * 0.2 + Vector3(0, hh, 0), b - inward * 0.2 + Vector3(0, hh, 0), 1.3, _m["iron"], 0 if i % 4 else 7)
		# gravestone rows just outside the wall
		var rr := RandomNumberGenerator.new()
		rr.seed = 1000 + i
		for k in 2:
			var gp := p - inward * rr.randf_range(2.5, 6.0) + side * rr.randf_range(-1.6, 1.6)
			EnvProps.gravestone(env, gp + Vector3(0, _h(gp.x, gp.z) - 0.05, 0), atan2(inward.x, inward.z) + rr.randf_range(-0.3, 0.3), rr.randi() % 4, _m["grave"], rr)
		i += 1
	for v: Vector3 in corner_vertices():
		EnvProps.pier(env, v, Vector2(1.4, 1.4), 3.2, _m["stone"], 0.0, true)
		add_box(v + Vector3(0, WALL_HEIGHT * 0.5, 0), Vector3(1.4, WALL_HEIGHT, 1.4))
	# the wider graveyard: gravestone fields, mausoleums, dead trees, rocks
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 77
	var placed := 0
	var tries := 0
	while placed < 160 and tries < 4000:
		tries += 1
		var p := Vector3(rng2.randf_range(center.x - size.x * 0.5 - 30.0, center.x + size.x * 0.5 + 30.0), 0, rng2.randf_range(center.z - size.y * 0.5 - 20.0, center.z + size.y * 0.5 + 20.0))
		var d := dist_to_walkable(p)
		if d < 7.0 or d > 26.0:
			continue
		EnvProps.gravestone(env, p + Vector3(0, _h(p.x, p.z) - 0.05, 0), rng2.randf_range(-0.4, 0.4) + (PI if p.x > 0 else 0.0) * 0.5, rng2.randi() % 4, _m["grave"], rng2)
		placed += 1
	placed = 0
	tries = 0
	while placed < 26 and tries < 2000:
		tries += 1
		var p := Vector3(rng2.randf_range(center.x - size.x * 0.5 - 34.0, center.x + size.x * 0.5 + 34.0), 0, rng2.randf_range(center.z - size.y * 0.5 - 24.0, center.z + size.y * 0.5 + 24.0))
		var d := dist_to_walkable(p)
		if d < 6.0 or d > 34.0:
			continue
		EnvProps.dead_tree(env, p + Vector3(0, _h(p.x, p.z) - 0.2, 0), rng2.randf_range(1.2, 2.0), _m["bark"], 300 + placed % 5 * 11, rng2.randf() * TAU)
		placed += 1
	for mp: Array in [[Vector3(-24.0, 0, -58.0), PI * 0.5], [Vector3(24.0, 0, -66.0), -PI * 0.5], [Vector3(-19.0, 0, -96.0), PI * 0.5],
			[Vector3(20.0, 0, -18.0), -PI * 0.5], [Vector3(-28.0, 0, -138.0), PI * 0.5], [Vector3(28.0, 0, -150.0), -PI * 0.5]]:
		var p: Vector3 = mp[0]
		EnvProps.mausoleum(env, p + Vector3(0, _h(p.x, p.z) - 0.3, 0), float(mp[1]), 4.0, 5.0, 3.6, _m["stone"], _m["dark"], _m["rock"])
	for k in 40:
		var p := Vector3(rng2.randf_range(center.x - size.x * 0.5 - 50.0, center.x + size.x * 0.5 + 50.0), 0, rng2.randf_range(center.z - size.y * 0.5 - 40.0, center.z + size.y * 0.5 + 40.0))
		if dist_to_walkable(p) < 12.0:
			continue
		EnvProps.rock(env, p + Vector3(0, _h(p.x, p.z) - 0.5, 0), rng2.randf_range(1.5, 4.0), _m["rock"], 5000 + k, rng2.randf() * TAU, 1.3)
	# edge clutter outside the walls: twig shrubs, rock clusters, leaf litter, sunken old graves
	placed = 0
	tries = 0
	while placed < 140 and tries < 5000:
		tries += 1
		var p := Vector3(rng2.randf_range(center.x - size.x * 0.5 - 14.0, center.x + size.x * 0.5 + 14.0), 0, rng2.randf_range(center.z - size.y * 0.5 - 10.0, center.z + size.y * 0.5 + 10.0))
		var d := dist_to_walkable(p)
		if d < 1.6 or d > 12.0:
			continue
		p.y = _h(p.x, p.z) - 0.05
		match placed % 4:
			0, 1:
				EnvProps.twig_shrub(env, p, rng2.randf_range(0.9, 1.6), _m["twig"], 20 + placed % 7)
			2:
				EnvProps.rock(env, p, rng2.randf_range(0.4, 1.1), _m["rock"], 5600 + placed, rng2.randf() * TAU, 0.7)
				EnvProps.rock(env, p + Vector3(0.7, 0, 0.3), rng2.randf_range(0.2, 0.5), _m["rock"], 5700 + placed, rng2.randf() * TAU, 0.7, false)
			_:
				env.litter(p, 1.6, 8, _m["litter"], _h, 0.8)
		placed += 1
	# dead-grass tufts in clumps over the hummocks (one MultiMesh)
	var tuft := EnvKit.tuft_mesh(0.5, 0.06)
	var tmat := EnvKit.grass_mat(Color("#2A2838"), Color("#8A8470"), Color("#3A3A7A"), 0.12)
	var clumps := 0
	tries = 0
	while clumps < 260 and tries < 6000:
		tries += 1
		var c := Vector3(rng2.randf_range(center.x - size.x * 0.5 - 22.0, center.x + size.x * 0.5 + 22.0), 0, rng2.randf_range(center.z - size.y * 0.5 - 16.0, center.z + size.y * 0.5 + 16.0))
		var d := dist_to_walkable(c)
		if d < 1.2 or d > 20.0:
			continue
		for k in 7:
			var p := c + Vector3(rng2.randf_range(-1.2, 1.2), 0, rng2.randf_range(-1.2, 1.2))
			env.inst(tuft, tmat, Transform3D(Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3.ONE * rng2.randf_range(0.7, 1.4)), p + Vector3(0, _h(p.x, p.z), 0)), false)
		clumps += 1
	env.backdrop({"haze": Color("#4A4A9A"), "far_col": Color("#3A3A80"), "mid_col": Color("#2A2A62"), "near_col": Color("#1C1C48"),
		"snow_col": Color("#8FA0E0"), "warm_col": Color("#B8A8FF"), "snow_caps": 0.15, "strata": 1.0, "h_scale": 0.55})


func decorate() -> void:
	# ---- gate yard: supply cart remains, the graveyard gate arch over the first corridor
	_barrels(Vector3(-6.3, 0, 14))
	_crates(Vector3(6.2, 0, 14), 0.4)
	_rubble(Vector3(5.5, 0, 2.5), 1.0)
	_gate_arch(Vector3(0, 0, 0.0))
	# ---- graveyard gate: rubble heaps, a toppled statue, broken low wall
	_rubble(Vector3(-8.5, 0, -15), 1.4)
	_rubble(Vector3(9.5, 0, -33.5), 1.2)
	_low_wall(Vector3(-10, 0, -33), Vector3(4.0, 1.4, 0.7), 0.0)
	EnvProps.sarcophagus(env, Vector3(8.5, 0, -15.5), 1.2, _m["grave"])
	add_box(Vector3(8.5, 0.4, -15.5), Vector3(1.0, 0.8, 2.2), 1.2)
	# ---- altar of the dead: four soul piers, the bone altar, tombs, the dead great tree
	for p: Vector3 in [Vector3(-8, 0, -54), Vector3(8, 0, -54), Vector3(-8, 0, -68), Vector3(8, 0, -68)]:
		EnvProps.pier(env, p, Vector2(1.3, 1.3), 4.2, _m["stone"], 0.0, true)
		for sgn: float in [-1.0, 1.0]:
			env.add(EnvKit.box(Vector3(0.1, 2.4, 0.06)), _m["soul"], Transform3D(Basis(), p + Vector3(sgn * 0.2, 2.2, signf(-62.0 - p.z) * 0.68)), false)
		add_box(p + Vector3(0, 2.1, 0), Vector3(1.3, 4.2, 1.3))
	var altar := Vector3(-13.6, 0, -60)
	env.add(EnvKit.box(Vector3(1.6, 1.0, 4.0)), _m["stone"], Transform3D(Basis(), altar + Vector3(0, 0.5, 0)))
	env.add(EnvKit.box(Vector3(1.9, 0.15, 4.3)), _m["grave"], Transform3D(Basis(), altar + Vector3(0, 1.05, 0)), false)
	for z: float in [-58.0, -60.0, -62.0]:
		EnvProps.candles(env, Vector3(-13.6, 1.1, z), _m["wax"], _m["warm"], int(z))
	for k in 3:
		env.add(EnvKit.sphere(0.18, 8), _m["bone"], Transform3D(Basis(), altar + Vector3(0.3, 1.25, -1.2 + k * 1.2)), false)
	add_box(altar + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 4.0))
	omni(Vector3(-12.5, 2.0, -60), SOUL_C, 2.2, 11.0)
	_tomb(Vector3(15.2, 0, -60), -PI * 0.5)
	_tomb(Vector3(15.2, 0, -55), -PI * 0.5)
	EnvProps.broadleaf(env, Vector3(-20.0, _h(-20.0, -64.0) - 0.3, -64.0), 16.0, {"bark": _m["bark"], "cards": _m["leaves"]}, 4242, 2, 2.6, 5, 0.9)
	# ---- the Bone Champion's hall: sarcophagi, rubble, broken coffins
	for p: Vector3 in [Vector3(-10, 0, -86.2), Vector3(10, 0, -86.2)]:
		EnvProps.sarcophagus(env, p, PI * 0.5, _m["grave"])
		add_box(p + Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 1.0))
	_rubble(Vector3(-10, 0, -105), 1.2)
	_crates(Vector3(10.3, 0, -105.5), 0.0)
	# ---- the chapel courtyard (boss): ring of broken columns, soul braziers, throne steps, the ruined chapel
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI / 8.0
		var p := Vector3(0, 0, -140) + Vector3(cos(a) * 15.0, 0, sin(a) * 15.0)
		EnvProps.column(env, p, [5.0, 2.6, 4.2, 1.8, 5.4, 3.0, 2.0, 4.6][k], _m["stone"], 800 + k, 0.55)
		add_box(p + Vector3(0, 3.0, 0), Vector3(1.3, 6.0, 1.3))
	for p: Vector3 in [Vector3(-9, 0, -126), Vector3(9, 0, -126), Vector3(-9, 0, -154), Vector3(9, 0, -154)]:
		EnvProps.brazier(env, p, _m["stone"], _m["iron"], _m["soul"])
		env.flame(p + Vector3(0, 1.3, 0), 1.2, Color(0.75, 0.55, 1.0))
		add_box(p + Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 0.9))
		omni(p + Vector3(0, 2.6, 0), SOUL_C, 2.0, 11.0)
	EnvProps.stairs(env, Vector3(0, 0.9, -156.8), 0.0, 1.6, 8.0, 0.0, _m["path"], _m["stone"])
	env.add(EnvKit.box(Vector3(8.0, 0.9, 2.6)), _m["stone"], Transform3D(Basis(), Vector3(0, 0.45, -158.1)))
	env.add(EnvKit.box(Vector3(1.8, 3.6, 0.6)), _m["dark"], Transform3D(Basis(), Vector3(0, 2.7, -159.2)))
	env.add(EnvKit.box(Vector3(2.2, 0.3, 0.8)), _m["iron"], Transform3D(Basis(), Vector3(0, 4.5, -159.1)), false)
	EnvProps.wall_banner(env, Vector3(-3.0, 4.6, -159.4), 0.0, 3.2, "banner_red.png", Color(0.42, 0.32, 0.62), _m["iron"])
	EnvProps.wall_banner(env, Vector3(3.0, 4.6, -159.4), 0.0, 3.2, "banner_red.png", Color(0.42, 0.32, 0.62), _m["iron"])
	_rubble(Vector3(-15, 0, -157), 1.6)
	_rubble(Vector3(15, 0, -123), 1.6)
	omni(Vector3(0, 7.0, -140), Color("#8FD0FF"), 1.6, 26.0)
	EnvProps.cathedral(env, Vector3(0, _h(0.0, -178.0) - 0.5, -178.0), 0.0, _m["stone"], _m["dark"], _m["glass"], 1.1)
	# warm lanterns along the path (they mark the way forward)
	for p: Vector3 in [Vector3(-3.3, 0, -4.0), Vector3(3.3, 0, -40.0), Vector3(-3.3, 0, -78.0), Vector3(3.3, 0, -114.0), Vector3(-6.5, 0, 3.0)]:
		EnvProps.lantern(env, p, _m["stone"], _m["warm"], false, LANTERN_C)
		add_box(p + Vector3(0, 1.0, 0), Vector3(0.5, 2.0, 0.5))
		omni(p + Vector3(0, 1.8, 0), LANTERN_C, 1.4, 8.0)
	# mist motes, soul wisps, drifting violet leaves
	for z: float in [0.0, -60.0, -130.0]:
		env.particles(Vector3(0, 2.0, z), Vector3(22, 2.0, 30), 160, 8.0, Color("#B8C8FF"), 0.07, Vector3(0.1, 0.15, 0.0), "spark", 1.6)
	env.particles(Vector3(0, 1.5, -140), Vector3(16, 1.5, 16), 90, 6.0, Color("#C08AFF"), 0.1, Vector3(0, 0.6, 0), "spark", 3.0)
	env.particles(Vector3(-20, 12, -64), Vector3(7, 3, 7), 50, 7.0, Color("#8A6AC8"), 0.14, Vector3(0.4, -0.5, 0.3), "leaf", 0.5, -0.12)


func _barrels(p: Vector3) -> void:
	EnvProps.barrel(env, p, _m["wood"], _m["iron"])
	EnvProps.barrel(env, p + Vector3(0.75, 0, 0.3), _m["wood"], _m["iron"])
	add_box(p + Vector3(0.35, 0.5, 0.15), Vector3(1.7, 1.0, 1.2))


func _crates(p: Vector3, yaw: float) -> void:
	EnvProps.crates(env, p, yaw, _m["wood"], _m["iron"], int(p.x * 5.0 + p.z))
	add_box(p + Vector3(0, 0.9, 0), Vector3(1.9, 1.8, 1.9), yaw)


func _rubble(p: Vector3, r: float) -> void:
	var m := EnvKit.rock_mesh(r, 0.35, 600 + int(p.x * 3.0 - p.z))
	var t := Transform3D(Basis(Vector3.UP, p.z * 0.37).scaled(Vector3(1.3, 0.6, 1.0)), p)
	env.add(m, _m["stone"], t)
	env.col_hull(m, t)
	var rr := RandomNumberGenerator.new()
	rr.seed = int(p.x * 17.0 + p.z)
	for i in 4:
		var a := rr.randf() * TAU
		env.add(EnvKit.box(Vector3(rr.randf_range(0.4, 0.7), rr.randf_range(0.3, 0.5), rr.randf_range(0.5, 0.8))), _m["stone"],
			Transform3D(Basis.from_euler(Vector3(rr.randf() * 0.5, a, rr.randf() * 0.5)), p + Vector3(cos(a), 0.12, sin(a)) * (r + 0.5)), false)


func _low_wall(c: Vector3, s: Vector3, yaw: float) -> void:
	env.add(EnvKit.box(s), _m["stone"], Transform3D(Basis(Vector3.UP, yaw), c + Vector3(0, s.y * 0.5, 0)))
	EnvProps.iron_fence(env, c + Basis(Vector3.UP, yaw) * Vector3(-s.x * 0.5, s.y, 0), c + Basis(Vector3.UP, yaw) * Vector3(s.x * 0.5, s.y, 0), 1.0, _m["iron"])
	add_box(c + Vector3(0, s.y * 0.5, 0), s, yaw)


## Wall tomb / ossuary niche against the room edge (solid).
func _tomb(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	env.add(EnvKit.box(Vector3(2.2, 2.6, 1.0)), _m["stone"], Transform3D(b, p + Vector3(0, 1.3, 0)))
	EnvProps.gothic_window(env, p + b * Vector3(0, 0.3, 0.52), yaw, 0.9, 1.9, _m["grave"], _m["dark"])
	for k in 3:
		env.add(EnvKit.sphere(0.13, 6), _m["bone"], Transform3D(Basis(), p + b * Vector3(-0.3 + k * 0.3, 0.45, 0.55)), false)
	add_box(p + Vector3(0, 1.3, 0), Vector3(2.2, 2.6, 1.0), yaw)


## Graveyard entrance arch over the first corridor (high above head height; piers sit outside the walk line).
func _gate_arch(at: Vector3) -> void:
	for sx: float in [-1.0, 1.0]:
		EnvProps.pier(env, at + Vector3(sx * 4.6, 0, 0), Vector2(1.2, 1.2), 5.6, _m["stone"], 0.0, true)
		add_box(at + Vector3(sx * 4.6, 2.8, 0), Vector3(1.2, 5.6, 1.2))
	var poly := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		poly.append(Vector2(lerpf(-5.2, 5.2, t), 5.4 + sin(t * PI) * 1.6))
	for i in 13:
		var t := 1.0 - float(i) / 12.0
		poly.append(Vector2(lerpf(-4.2, 4.2, t), 5.0 + sin(t * PI) * 1.2))
	env.add(EnvKit.extrude(poly, 0.6, 0.05), _m["iron"], Transform3D(Basis(), at))
	env.add(EnvKit.lathe([Vector2(0.4, 0.0), Vector2(0.0, 1.0)], 4), _m["iron"], Transform3D(Basis(), at + Vector3(0, 7.0, 0)), false)


func build_lighting() -> void:
	painted_environment("moon")
