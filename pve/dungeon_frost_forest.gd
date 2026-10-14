extends DungeonBase
## 冰霜森林 Frost Forest: a snowed-in forest trail (start camp -> wolf pack clearing -> orc camp) ending at a
## frozen lake where the Frost Golem (冰霜巨人) waits. Painted look-dev style (bible 4.2 Frost Forest): low
## white-cyan key light, cyan-shadowed snow, frosted bare branches and snow pines, ice crystals; the hero accent
## is the blood-red maple on a rock outcrop behind the frozen lake - visible straight down the trail from the camp.
## Gameplay contract unchanged: same rooms / encounters / checkpoints, floor at y 0 on every walkable cell
## (per-room collision slabs), invisible walls on every boundary edge, obstacles at the same spots.
## Secondaries: the broken Gothic arch over the orc camp, a frozen waterfall behind the lake, the camp tents.

const ICE_C := Color(0.55, 0.85, 1.0)
const MAPLE_AT := Vector3(6.0, 0.0, -133.0)

var _m: Dictionary = {}


func _init() -> void:
	map_id = "frost_forest"
	name_cn = "冰霜森林"
	name_en = "Frost Forest"
	map_kind = "raid"


func define_layout() -> void:
	var start := rect(-8, 8, 0, 16)
	var c1 := rect(-4, 4, -12, 0)
	var r1 := rect(-12, 12, -36, -12)
	var c2 := rect(-4, 4, -48, -36)
	var r2 := rect(-12, 12, -72, -48)
	var c3 := rect(-4, 4, -84, -72)
	var boss := rect(-20, 20, -124, -84)
	rooms = [start, c1, r1, c2, r2, c3, boss]
	spawn_center = Vector3(0, 0, 9)
	encounters = [
		encounter("wolf_pack", "冰原狼群", "Frost Wolf Pack", Vector3(0, 0, -26), 11.0,
			["frost_wolf", "frost_wolf", "orc_raider", "orc_guard", "ice_archer"], false, r1),
		encounter("orc_camp", "兽人营地", "Orc Camp", Vector3(0, 0, -62), 11.0,
			["orc_warlord", "orc_guard", "orc_raider", "ice_archer", "frost_shaman"], false, r2),
		encounter("frost_golem", "冰霜巨人", "Frost Golem", Vector3(0, 0, -108), 15.0,
			["frost_golem"], true, boss),
	]
	fit_bounds(2.0)


func _mats() -> void:
	_m["snow"] = EnvKit.paint(Color("#8A96B8"), Color("#5E6A90"), {"snow_amount": 0.72, "strata": 1.0, "ledges": 0.7, "noise_scale": 0.22, "snow_sharp": 0.05,
		"cover_col2": Color("#E0ECFA", 0.6), "macro": 0.3, "macro_scale": 0.03})
	_m["trail"] = EnvKit.paint(Color("#A4B2CC"), Color("#7E8EB0"), {"snow_amount": 0.0, "noise_scale": 0.6, "paint_strength": 0.45, "stroke": 0.0,
		"warm_amount": 0.25, "warm_col": Color("#C8B8C8")})
	_m["rock"] = EnvKit.paint(Color("#6E7896"), Color("#454E6C"), {"snow_amount": 0.42, "strata": 1.0, "noise_scale": 0.6, "warm_amount": 0.5, "warm_col": Color("#C89A6A")})
	_m["outcrop"] = EnvKit.paint(Color("#8A7E8C"), Color("#4A4260"), {"snow_amount": 0.62, "strata": 1.0, "noise_scale": 0.5, "warm_amount": 0.7, "warm_col": Color("#D8A27A")})
	_m["bark"] = EnvKit.paint(Color("#3B3546"), Color("#26222E"), {"snow_amount": 0.42, "noise_scale": 2.5, "snow_sharp": 0.03, "snow_col": Color("#F4FAFF")})
	_m["maple_bark"] = EnvKit.paint(Color("#3A2A30"), Color("#22181E"), {"snow_amount": 0.32, "noise_scale": 2.0, "snow_sharp": 0.03})
	_m["maple_core"] = EnvKit.paint(Color("#9E1430"), Color("#6A0E28"), {"snow_amount": 0.0, "noise_scale": 1.2, "shade_tint": Color("#5A2A6A"), "stroke": 0.0})
	_m["maple"] = EnvKit.foliage("maple_leaves.png", Color(0.9, 0.48, 0.48), Color(0.45, 0.2, 0.5), Color(1.0, 0.7, 0.5))
	_m["pine"] = EnvKit.paint(Color("#1F4A4E"), Color("#163236"), {"snow_amount": 0.5, "noise_scale": 1.4, "snow_sharp": 0.04})
	_m["stone"] = EnvKit.paint(Color("#A2968E"), Color("#625A70"), {"snow_amount": 0.3, "noise_scale": 0.7, "paint_strength": 0.4, "rim_amount": 0.25, "blocks": 0.6,
		"warm_amount": 0.8, "warm_col": Color("#E8B888")})
	_m["column"] = EnvKit.paint(Color("#A49AA6"), Color("#655C78"), {"snow_amount": 0.3, "noise_scale": 0.8, "paint_strength": 0.4, "warm_amount": 0.75,
		"warm_col": Color("#E0B48C"), "blocks": 0.55})
	_m["wood"] = EnvKit.paint(Color("#7A5A44"), Color("#4A3428"), {"snow_amount": 0.45, "noise_scale": 2.5, "paint_strength": 0.3})
	_m["iron"] = EnvKit.paint(Color("#4A4C5A"), Color("#2A2C36"), {"snow_amount": 0.3, "noise_scale": 2.0, "stroke": 0.0})
	_m["canvas"] = EnvKit.paint(Color("#C8B89A"), Color("#8E7E6A"), {"snow_amount": 0.55, "noise_scale": 1.0, "paint_strength": 0.25, "stroke": 0.0})
	_m["orc_canvas"] = EnvKit.paint(Color("#8A4A3A"), Color("#5A2A28"), {"snow_amount": 0.5, "noise_scale": 1.0, "paint_strength": 0.25, "stroke": 0.0})
	_m["ice"] = EnvKit.paint(Color("#7ED4F6"), Color("#3E9ACC"), {"snow_amount": 0.15, "noise_scale": 1.5, "paint_strength": 0.15, "rim_amount": 1.0,
		"rim_col": Color.WHITE, "emission_col": Color("#2F9BFF") * 0.25, "shade_tint": Color(0.35, 0.5, 0.95), "stroke": 0.0})
	_m["ice_core"] = EnvKit.glow(Color("#7FE8FF"), 1.3, true, 0.35)
	_m["lake"] = EnvKit.shader_mat(EnvKit.WATER, {"ice": 1.0, "deep": Color("#3A7AA8"), "shallow": Color("#8AD0F0"), "frost": Color("#E8F4FF")})
	_m["flame"] = EnvKit.glow(Color("#FFA040"), 3.0)
	_m["core"] = EnvKit.glow(Color("#7FE8FF"), 4.0)


## Ground height: 0 on the walkable trail (collision slabs), snow banks and ridges outside.
func _h(x: float, z: float) -> float:
	var d := dist_to_walkable(Vector3(x, 0, z))
	var n := env.noise.get_noise_2d(x, z)
	if d <= 0.0:
		return 0.01 + n * 0.01
	var bank := smoothstep(0.0, 4.0, d) * (1.6 + n * 0.8)
	var ridge := smoothstep(6.0, 30.0, d) * (9.0 + env.noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7) * 6.0)
	return bank + ridge + n * 1.2 * smoothstep(2.0, 10.0, d)


func build_ground() -> void:
	_mats()
	floor_collision()
	var r := Rect2(Vector2(center.x - size.x * 0.5 - 50.0, center.z - size.y * 0.5 - 50.0), Vector2(size.x + 100.0, size.y + 100.0))
	env.terrain(r, 1.5, _h, _m["snow"], Rect2(), 0.1)
	# packed-snow trail strips over the walkable rooms
	for rr: Rect2 in rooms:
		env.add(EnvKit.box(Vector3(rr.size.x - 0.8, 0.03, rr.size.y - 0.8)), _m["trail"], Transform3D(Basis(), Vector3(rr.get_center().x, 0.0, rr.get_center().y)), false)
	# frozen lake in the boss arena (visual, flush)
	env.add(EnvKit.cyl(15.0, 15.0, 0.04, 48), _m["lake"], Transform3D(Basis(), Vector3(0, 0.03, -104)), false)
	env.add(EnvKit.lathe([Vector2(15.8, 0.0), Vector2(15.0, 0.1), Vector2(14.6, 0.05)], 48), _m["trail"], Transform3D(Basis(), Vector3(0, 0.0, -104)), false)


func build_boundary() -> void:
	edge_collision()
	# frosted rocks breaking the edge line (outside the walkable cells, half-buried in the snow bank)
	for e: Dictionary in edges:
		if rng.randf() < 0.45:
			continue
		var p: Vector3 = e["pos"]
		var out := -(e["inward"] as Vector3)
		var side := Vector3(out.z, 0, -out.x)
		var rp := p + side * rng.randf_range(-1.6, 1.6) + out * rng.randf_range(1.2, 2.4)
		EnvProps.rock(env, rp + Vector3(0, _h(rp.x, rp.z) - 0.3, 0), rng.randf_range(0.9, 1.9), _m["rock"], 2000 + int(rp.x * 7.0 + rp.z), rng.randf() * TAU, 0.8)
	for v: Vector3 in corner_vertices():
		var out := Vector3(signf(v.x - center.x), 0, 0) * 1.5
		var rp := v + out
		EnvProps.rock(env, rp + Vector3(0, _h(rp.x, rp.z) - 0.4, 0), rng.randf_range(1.8, 2.8), _m["rock"], 2500 + int(v.x * 3.0 - v.z), rng.randf() * TAU, 0.85)
	# frosted bare trees close to the trail, snow pines (MultiMesh) further out
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 3000:
		tries += 1
		var p := Vector3(rng.randf_range(center.x - size.x * 0.5 - 22.0, center.x + size.x * 0.5 + 22.0), 0, rng.randf_range(center.z - size.y * 0.5 - 20.0, center.z + size.y * 0.5 + 20.0))
		var d := dist_to_walkable(p)
		if d < 3.5 or d > 16.0 or p.distance_to(MAPLE_AT) < 9.0:
			continue
		EnvProps.bare_tree(env, p + Vector3(0, _h(p.x, p.z) - 0.2, 0), rng.randf_range(1.0, 1.6), _m["bark"], 100 + placed % 6 * 7, rng.randf() * TAU)
		placed += 1
	var pine := EnvKit.pine_mesh()
	placed = 0
	tries = 0
	while placed < 520 and tries < 8000:
		tries += 1
		var p := Vector3(rng.randf_range(center.x - size.x * 0.5 - 50.0, center.x + size.x * 0.5 + 50.0), 0, rng.randf_range(center.z - size.y * 0.5 - 50.0, center.z + size.y * 0.5 + 50.0))
		var d := dist_to_walkable(p)
		if d < 8.0 or p.distance_to(MAPLE_AT) < 10.0:
			continue
		var s := rng.randf_range(1.2, 2.4)
		env.inst(pine, _m["pine"], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s)), p + Vector3(0, _h(p.x, p.z) - 0.3, 0)), d < 26.0)
		placed += 1
	env.backdrop({}, 330.0)


func decorate() -> void:
	# ---- start camp: tents, campfire, supply crates, blue banners
	EnvProps.tent(env, Vector3(-5.5, 0, 13.6), PI * 0.5, _m["canvas"], _m["wood"])
	add_box(Vector3(-5.5, 1.0, 13.6), Vector3(3.0, 2.0, 3.0))
	_crates(Vector3(-6, 0, 14) + Vector3(0, 0, -3.8), 0.3)
	_barrel(Vector3(6, 0, 14))
	_barrel(Vector3(6.2, 0, 11.5))
	_campfire(Vector3(0, 0, 13.5))
	for sx: float in [-1.0, 1.0]:
		EnvProps.banner(env, Vector3(sx * 7.4, 0, 6), "banner_blue.png", Color.WHITE, 5.5, _m["iron"], _m["column"], -sx * PI * 0.5)
	# ---- wolf clearing: boulders (convex collision), broken weapons, ice crystals, a frozen adventurer's shield
	for p: Vector3 in [Vector3(-9.5, 0, -16), Vector3(9.5, 0, -33), Vector3(-9, 0, -33)]:
		_boulder(p, 1.25, int(p.x * 5.0 - p.z))
	EnvProps.column(env, Vector3(5, 0, -17), 1.4, _m["column"], 41, 0.4)
	add_box(Vector3(5, 0.8, -17), Vector3(1.0, 1.6, 1.0))
	_crystals(Vector3(10, 0, -24), 1.0)
	_crystals(Vector3(-10, 0, -28), 0.8)
	_outcrop(Vector3(10.5, 0, -14.5), 1.6)
	# ---- orc camp: palisade, crates and barrels, weapon racks, red war banners, campfires; ruined arch behind
	_crates(Vector3(-10, 0, -51), 0.2)
	_crates(Vector3(-10, 0, -54.5), 0.9)
	_barrel(Vector3(10, 0, -51))
	_barrel(Vector3(10, 0, -54.5))
	EnvProps.tent(env, Vector3(-9.0, 0, -68.0), PI * 0.5, _m["orc_canvas"], _m["wood"])
	add_box(Vector3(-9.0, 1.0, -68.0), Vector3(3.0, 2.0, 3.0))
	_rack(Vector3(9.5, 0, -69), -0.5)
	for sx: float in [-1.0, 1.0]:
		EnvProps.banner(env, Vector3(sx * 11.4, 0, -60), "banner_red.png", Color(0.75, 0.55, 0.5), 5.5, _m["wood"], _m["iron"], -sx * PI * 0.5)
		for k in 5:
			var pz := -50.0 - k * 4.5
			var pp := Vector3(sx * 12.8, 0, pz)
			env.add(EnvKit.lathe([Vector2(0.18, 0.0), Vector2(0.16, 2.2), Vector2(0.0, 2.7)], 6), _m["wood"], Transform3D(Basis(Vector3.FORWARD, sx * 0.25), pp))
	_campfire(Vector3(-6, 0, -57))
	_campfire(Vector3(6, 0, -67))
	EnvProps.ruin_arch(env, Vector3(-2.5, 0, -78.5), 0.0, _m["stone"], _h, 0.95)
	_outcrop(Vector3(-11.0, 0, -49.5), 1.4)
	# ---- boss arena: ring of ice crystals around the frozen lake, broken pillars, frozen waterfall + red maple
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var p := Vector3(0, 0, -104) + Vector3(cos(a), 0, sin(a)) * 17.0
		if absf(p.x) < 5.0 and p.z > -100.0:
			continue  # keep the entrance clear
		_crystals(p, 1.2)
	var hs := [4.6, 2.2, 3.4, 1.4]
	var k := 0
	for p: Vector3 in [Vector3(-17, 0, -88), Vector3(17, 0, -88), Vector3(-17, 0, -121), Vector3(17, 0, -121)]:
		EnvProps.column(env, p, hs[k], _m["column"], 70 + k, 0.55)
		add_box(p + Vector3(0, 1.5, 0), Vector3(1.4, 3.0, 1.4))
		k += 1
	for i in 4:
		var lp := Vector3(-17 + 34 * (i % 2), 0, -96 - 16 * floori(i * 0.5))
		omni(lp + Vector3(0, 2.5, 0), ICE_C, 1.6, 12.0)
	omni(Vector3(0, 6, -104), Color(0.6, 0.85, 1.0), 2.0, 22.0)
	_waterfall(Vector3(-10.0, 0, -131.0))
	_maple(MAPLE_AT)
	# lantern posts along the trail (cyan rune light marks the way)
	for p: Vector3 in [Vector3(-3.3, 0, -2), Vector3(3.3, 0, -10), Vector3(-3.3, 0, -40), Vector3(3.3, 0, -46), Vector3(-3.3, 0, -76), Vector3(3.3, 0, -82)]:
		EnvProps.lantern(env, p, _m["column"], _m["core"], false, ICE_C)
		add_box(p + Vector3(0, 1.0, 0), Vector3(0.5, 2.0, 0.5))
	# snow, light motes and falling maple leaves
	for z: float in [6.0, -40.0, -100.0]:
		env.particles(Vector3(0, 13, z), Vector3(26, 12, 30), 1600, 9.0, Color(1, 1, 1, 0.9), 0.07, Vector3(0.4, -1.0, 0.15), "dot", 0.6)
	env.particles(Vector3(0, 2.5, -104), Vector3(16, 2.5, 16), 140, 7.0, Color("#BFF2FF"), 0.09, Vector3(0.05, 0.08, 0.0), "spark", 2.5)
	env.particles(MAPLE_AT + Vector3(0, 13, 4), Vector3(6, 3, 6), 90, 6.0, Color("#E0283A"), 0.14, Vector3(0.3, -0.5, 0.6), "leaf", 0.6, -0.15)


func _crates(p: Vector3, yaw: float) -> void:
	EnvProps.crates(env, p, yaw, _m["wood"], _m["iron"], int(p.x * 7.0 + p.z))
	add_box(p + Vector3(0, 0.9, 0), Vector3(1.9, 1.8, 1.9), yaw)


func _barrel(p: Vector3) -> void:
	EnvProps.barrel(env, p, _m["wood"], _m["iron"])
	add_box(p + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8))


func _rack(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	env.add(EnvKit.box(Vector3(2.2, 0.12, 0.12)), _m["wood"], Transform3D(b, p + Vector3(0, 1.2, 0)))
	for sx: float in [-1.0, 1.0]:
		env.add(EnvKit.box(Vector3(0.14, 1.5, 0.14)), _m["wood"], Transform3D(b, p + b * Vector3(sx * 1.0, 0.75, 0)))
	for i in 4:
		env.add(EnvKit.box(Vector3(0.08, 1.6, 0.03)), _m["iron"], Transform3D(b * Basis(Vector3.FORWARD, 0.12), p + b * Vector3(-0.75 + i * 0.5, 0.85, 0.12)), false)
	add_box(p + Vector3(0, 0.75, 0), Vector3(2.2, 1.5, 0.5), yaw)


func _campfire(p: Vector3) -> void:
	var lp := EnvProps.campfire(env, p, _m["rock"], _m["wood"], _m["flame"])
	omni(lp + Vector3(0, 0.4, 0), Color(1.0, 0.6, 0.25), 2.2, 10.0, false)
	add_box(p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.6))


func _boulder(p: Vector3, r: float, seed_i: int) -> void:
	var m := EnvKit.rock_mesh(r, 0.4, 3000 + seed_i)
	var t := Transform3D(Basis(Vector3.UP, float(seed_i) * 0.3), p)
	env.add(m, _m["rock"], t)
	env.col_hull(m, t)


## Snowy rock outcrop (+1.5 m raised ground feature at a room corner, solid).
func _outcrop(p: Vector3, r: float) -> void:
	for i in 3:
		var off := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)) * r
		var m := EnvKit.rock_mesh(r * rng.randf_range(0.8, 1.1), 0.42, 3100 + i + int(p.z))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, rng.randf_range(0.9, 1.3), 1.0)), p + off)
		env.add(m, _m["outcrop"], t)
		env.col_hull(m, t)


func _crystals(p: Vector3, s: float) -> void:
	EnvProps.ice_cluster(env, p, _m["ice"], _m["ice_core"], int(p.x * 13.0 + p.z), s, false)
	add_box(p + Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8))


## Frozen waterfall spilling off the ridge behind the lake (ice ribbon + icicle fringe).
func _waterfall(at: Vector3) -> void:
	var top := at + Vector3(0, _h(at.x, at.z - 12.0) + 9.0, -12.0)
	var pts: Array = []
	var w: Array = []
	var sides: Array = []
	for i in 10:
		var t := float(i) / 9.0
		var p := top.lerp(at + Vector3(0, 0.2, 0), t)
		p.z += sin(t * PI) * 2.0
		pts.append(p)
		w.append(lerpf(4.0, 7.0, t))
		sides.append(Vector3(1, 0, 0))
	env.add(EnvKit.ribbon(pts, w, sides, 0.6), _m["ice"], Transform3D.IDENTITY)
	for i in 9:
		var p := top + Vector3(-2.0 + i * 0.5, -0.2, 0.5)
		env.add(EnvKit.lathe([Vector2(0.15, 0.0), Vector2(0.0, -rng.randf_range(1.0, 2.6))], 5), _m["ice"], Transform3D(Basis(), p), false)
	EnvProps.ice_cluster(env, at + Vector3(2.0, 0, 1.0), _m["ice"], _m["ice_core"], 909, 1.6, false)


## The red maple on its rock outcrop (primary landmark, from the look-dev slice).
func _maple(at: Vector3) -> void:
	var gy := _h(at.x, at.z)
	for i in 6:
		var r := rng.randf_range(2.4, 4.0)
		var off := Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(0.8, 2.6), rng.randf_range(-2.0, 2.0))
		env.add(EnvKit.rock_mesh(r, 0.45, i * 13 + 2), _m["outcrop"], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 0.85, 1.0)), at + Vector3(0, gy, 0) + off))
	var top := at + Vector3(0, gy + 4.6, 0)
	EnvProps.broadleaf(env, top, 14.0, {"bark": _m["maple_bark"], "core": _m["maple_core"], "cards": _m["maple"]}, 77, 10, 2.8, 5, 0.6, 0.0, 1.0)
	omni(top + Vector3(0, 6.0, 6.0), Color("#FFB0A0"), 1.2, 14.0)


func build_lighting() -> void:
	painted_environment("frost")
