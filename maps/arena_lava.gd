extends ArenaMap
## 熔岩洞 Lava Cave - 40 m duel / arena map in a volcanic cavern (dark, one hot hue: molten orange).
## Gameplay (unchanged): a lava river splits the basalt floor; cross it over the raised central basalt keep (2 m
## high ground, stairs north and south) or the two stone bridges on the flanks. Lava also runs along the east and
## west edges - knockbacks near the walls are dangerous. Lava is flush with the floor: walking in it is possible
## but burns (host-side hazard tick, is_hazard() for bots).
## Composition: primary landmark = the Molten Gate (熔火之门), a colossal rune ring standing in the lava lake to
## the north, framed by two lava falls; secondaries = the forge-altar keep, basalt organ-pipe columns, hanging
## stalactites under a broken cavern roof that lets a cold violet shaft of light in. Value: dark warm-violet
## rock, mid-value basalt floor, hottest light on the lava (warm = danger here, cold shaft = the keep).

const HALF: float = 20.0
const KEEP_H: float = 2.0
const KEEP_HALF: float = 4.0
## Fraction of max hp dealt per hazard tick and the tick period.
const LAVA_DMG: float = 0.04
const LAVA_TICK: float = 0.5

var _lava_timer: float = 0.0
var _m: Dictionary = {}


func _init() -> void:
	map_id = "lava_cave"
	name_cn = "熔岩洞"
	name_en = "Lava Cave"
	size = Vector2(40.0, 40.0)
	center = Vector3.ZERO


## True when an XZ position is over lava (flush with the floor).
func is_hazard(pos: Vector3) -> bool:
	return pos.y < 0.4 and is_lava(pos)


static func is_lava(p: Vector3) -> bool:
	var ax := absf(p.x)
	if ax > HALF - 2.0:
		return true
	if absf(p.z) < 2.0 and ax > KEEP_HALF and absf(ax - 12.0) > 2.0:
		return true
	return false


func _mats() -> void:
	var shade := Color("#3A2A5A")
	_m["floor"] = EnvKit.paint(Color("#6A5A60"), Color("#3A3040"), {"snow_amount": 0.0, "noise_scale": 0.45, "paint_strength": 0.4, "tiles": 0.0,
		"warm_amount": 0.55, "warm_col": Color("#C86A3A"), "shade_tint": shade, "stroke": 0.0})
	_m["basalt"] = EnvKit.paint(Color("#5E4E58"), Color("#2E2432"), {"snow_amount": 0.18, "snow_col": Color("#6A3A2E"), "snow_shadow_tint": Color("#4A2A3A"),
		"strata": 1.0, "noise_scale": 0.3, "paint_strength": 0.35, "warm_amount": 0.6, "warm_col": Color("#E07A3A"), "shade_tint": shade,
		"heat_col": Color("#FF5A1A") * 0.18, "heat_height": 2.5})
	_m["wall"] = EnvKit.paint(Color("#4A3A48"), Color("#221A26"), {"snow_amount": 0.0, "strata": 1.0, "noise_scale": 0.15, "paint_strength": 0.45,
		"warm_amount": 0.7, "warm_col": Color("#D0602A"), "shade_tint": Color("#2A1E40"), "stroke": 0.4, "heat_col": Color("#FF5A1A") * 0.35, "heat_height": 9.0})
	_m["stone"] = EnvKit.paint(Color("#6A5A5E"), Color("#3E3238"), {"snow_amount": 0.0, "noise_scale": 0.7, "paint_strength": 0.3, "blocks": 0.5,
		"warm_amount": 0.5, "warm_col": Color("#E08A50"), "shade_tint": shade})
	_m["obsidian"] = EnvKit.paint(Color("#2A2232"), Color("#120E18"), {"snow_amount": 0.0, "noise_scale": 0.8, "paint_strength": 0.2, "rim_amount": 0.9,
		"rim_col": Color("#FF8A4A"), "shade_tint": Color("#2A1E40"), "stroke": 0.0})
	_m["iron"] = EnvKit.paint(Color("#3A3236"), Color("#1E1A1E"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#2A2240"), "stroke": 0.0})
	_m["lava"] = EnvKit.shader_mat(EnvKit.LAVA, {"energy": 3.0, "crust_amount": 0.45})
	_m["lava_fall"] = EnvKit.shader_mat(EnvKit.LAVA, {"energy": 3.6, "crust_amount": 0.2, "flow": Vector2(0.0, -0.9)})
	_m["rune"] = EnvKit.glow(Color("#FF8A3A"), 6.0)
	_m["crystal"] = EnvKit.paint(Color("#FFB070"), Color("#C85A2A"), {"snow_amount": 0.0, "noise_scale": 1.5, "paint_strength": 0.2, "rim_amount": 1.0,
		"rim_col": Color("#FFE0A0"), "emission_col": Color("#FF6A1A") * 0.9, "shade_tint": Color("#8A2A3A"), "stroke": 0.0})
	_m["flame"] = EnvKit.glow(Color("#FFA040"), 3.0)
	_m["cold"] = EnvKit.glow(Color("#9A8AFF"), 2.2)


func _build_map() -> void:
	setup_atmosphere("lava")
	_mats()
	_floor()
	_cavern()
	_bridges()
	_keep()
	_stalagmites()
	_landmarks()
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	# embers rising off the lava, ash drifting down, cold motes in the light shaft
	env.particles(Vector3(0, 1.5, 0), Vector3(22, 1.5, 22), 260, 5.0, Color("#FF8A3A"), 0.07, Vector3(0.1, 1.0, 0.0), "spark", 3.0)
	env.particles(Vector3(0, 10, 0), Vector3(24, 6, 24), 120, 10.0, Color("#6A5A60"), 0.08, Vector3(0.2, -0.4, 0.1), "dot", 0.2)
	env.particles(Vector3(0, 9, 0), Vector3(5, 7, 5), 60, 9.0, Color("#B8A8FF"), 0.06, Vector3(0, -0.2, 0), "spark", 2.0)
	test_walks = [
		{"name": "keep ramp", "from": Vector3(0, 0, -13), "to": Vector3(0, KEEP_H, -1), "min_y": KEEP_H - 0.3},
		{"name": "flank bridge", "from": Vector3(-12, 0, -8), "to": Vector3(-12, 0, 8), "min_y": -1.0},
	]
	set_spawns_line(0, Vector3(0, 0, -16.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 16.0), Vector3.RIGHT, 2.2)


func _floor_h(x: float, z: float) -> float:
	return env.noise.get_noise_2d(x * 3.0, z * 3.0) * 0.03


## Cavern walls: steep rock rising beyond the lava edges and the north / south ends.
func _wall_h(x: float, z: float) -> float:
	var ax := absf(x)
	var az := absf(z)
	var n := env.noise.get_noise_2d(x * 1.3, z * 1.3)
	var d_main := maxf(ax - (HALF + 5.0), az - (HALF + 2.5))
	var d_north := maxf(ax - 17.0 - n * 2.0, absf(z + 34.0) - 13.0)
	var d := minf(d_main, d_north)
	if d < 0.0:
		return -1.2
	return smoothstep(0.0, 6.0, d) * 28.0 + d * 0.6 + n * 5.0 * smoothstep(0.0, 4.0, d) - 1.2


## Broken cavern roof (seen from below), with a jagged hole over the keep.
func _roof_h(x: float, z: float) -> float:
	var r := Vector2(x, z * 1.2).length()
	var n := env.noise.get_noise_2d(x * 0.9 + 200.0, z * 0.9)
	return 24.0 - smoothstep(10.0, 40.0, r) * 6.0 + n * 4.0 + absf(env.noise.get_noise_2d(x * 2.5, z * 2.5)) * 3.0


func _floor() -> void:
	# one collision slab under everything (lava is walkable), painted floor with holes where the lava runs
	kit.col_box(Vector3(0, -1.0, 0), Vector3(44.0, 2.0, 44.0), 0.0, "Floor")
	var lava_cell := func(x: float, z: float) -> bool: return is_lava(Vector3(x, 0, z))
	env.terrain(Rect2(-HALF - 2.0, -HALF - 4.0, 2.0 * HALF + 4.0, 2.0 * HALF + 8.0), 0.5, _floor_h, _m["floor"], Rect2(), 0.15, lava_cell)
	# lava surfaces: river, edges and a wide lake to the north (visual; the floor slab is under it)
	var lava_y := -0.06
	for sx: float in [-1.0, 1.0]:
		env.add(EnvKit.box(Vector3(12.0, 0.1, 60.0)), _m["lava"], Transform3D(Basis(), Vector3(sx * 24.0, lava_y, 0)), false)
	env.add(EnvKit.box(Vector3(40.0, 0.1, 4.0)), _m["lava"], Transform3D(Basis(), Vector3(0, lava_y, 0)), false)
	env.add(EnvKit.box(Vector3(40.0, 0.1, 28.0)), _m["lava"], Transform3D(Basis(), Vector3(0, lava_y - 0.4, -36.0)), false)
	env.add(EnvKit.box(Vector3(60.0, 0.1, 10.0)), _m["lava"], Transform3D(Basis(), Vector3(0, lava_y - 0.4, 28.0)), false)
	# cooled crust rims along the river / edges (small glowing-edged rocks, visual only)
	for i in 70:
		var x := env.rng.randf_range(-17.6, 17.6)
		if absf(x) < 4.3 or absf(absf(x) - 12.0) < 2.3:
			continue
		var z := (2.05 + env.rng.randf() * 0.35) * (1.0 if i % 2 == 0 else -1.0)
		EnvProps.rock(env, Vector3(x, -0.05, z), env.rng.randf_range(0.18, 0.4), _m["basalt"], 1500 + i, env.rng.randf() * TAU, 0.6, false)
	for i in 50:
		var z := env.rng.randf_range(-HALF, HALF)
		var sx := 1.0 if i % 2 == 0 else -1.0
		EnvProps.rock(env, Vector3(sx * (HALF - 2.05 - env.rng.randf() * 0.3), -0.05, z), env.rng.randf_range(0.2, 0.45), _m["basalt"], 1600 + i, env.rng.randf() * TAU, 0.6, false)
	# lava glow lights (low, warm)
	for p: Vector3 in [Vector3(-7, 0.8, 0), Vector3(7, 0.8, 0), Vector3(-19, 1.0, -9), Vector3(19, 1.0, 9),
			Vector3(-19, 1.0, 10), Vector3(19, 1.0, -10)]:
		add_omni(p, Color(1.0, 0.45, 0.15), 2.2, 9.0)


func _cavern() -> void:
	env.terrain(Rect2(-90, -90, 180, 180), 2.0, _wall_h, _m["wall"], Rect2(), 0.08)
	var hole := func(x: float, z: float) -> bool: return Vector2(x + env.noise.get_noise_2d(z, 9.0) * 6.0, z).length() < 9.0
	env.terrain(Rect2(-70, -70, 140, 140), 3.0, _roof_h, _m["wall"], Rect2(), 0.08, hole, true, true)
	# stalactites hanging from the roof
	for i in 34:
		var a := env.rng.randf() * TAU
		var d := env.rng.randf_range(11.0, 36.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var h := env.rng.randf_range(3.0, 9.0)
		var top := _roof_h(p.x, p.z) + 1.0
		var m := EnvKit.lathe([Vector2(0.0, -h), Vector2(h * 0.18, -h * 0.5), Vector2(h * 0.26, 0.0)], 6)
		env.add(m, _m["basalt"], Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU), Vector3(p.x, top, p.z)), false)
	# cold light shaft through the roof hole onto the keep
	var shaft := SpotLight3D.new()
	shaft.light_color = Color("#9A8AFF")
	shaft.light_energy = 6.0
	shaft.spot_range = 40.0
	shaft.spot_angle = 16.0
	shaft.light_volumetric_fog_energy = 3.0
	shaft.shadow_enabled = false
	shaft.position = Vector3(0, 30.0, 0)
	shaft.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(shaft)


func _bridges() -> void:
	for sx: float in [-1.0, 1.0]:
		# stone slab bridge deck over the river (visual; the floor slab carries it)
		var bx := sx * 12.0
		env.add(EnvKit.box(Vector3(3.8, 0.2, 5.2)), _m["stone"], Transform3D(Basis(), Vector3(bx, 0.0, 0)))
		for bz: float in [-2.6, 2.6]:
			for px: float in [9.6, 14.4]:
				var p := Vector3(sx * px, 0, bz)
				env.add(EnvKit.box(Vector3(0.7, 1.4, 2.0)), _m["stone"], Transform3D(Basis(), p + Vector3(0, 0.7, 0)))
				env.add(EnvKit.box(Vector3(0.85, 0.16, 2.15)), _m["iron"], Transform3D(Basis(), p + Vector3(0, 1.42, 0)), false)
				kit.col_box(p + Vector3(0, 0.7, 0), Vector3(2.0, 1.4, 0.7), 90.0, "BridgePost")
		for p: Vector3 in [Vector3(sx * 9.6, 1.4, -2.6), Vector3(sx * 14.4, 1.4, 2.6)]:
			env.add(EnvKit.lathe([Vector2(0.2, 0.0), Vector2(0.3, 0.25), Vector2(0.24, 0.35)], 8), _m["iron"], Transform3D(Basis(), p), false)
			env.flame(p + Vector3(0, 0.25, 0), 0.8)


func _keep() -> void:
	var rect := Rect2(-KEEP_HALF, -KEEP_HALF, 2.0 * KEEP_HALF, 2.0 * KEEP_HALF)
	kit.platform_col(rect, KEEP_H)
	EnvProps.plinth(env, rect, -0.2, KEEP_H, _m["stone"], _m["floor"], _m["iron"])
	var gap := func(p: Vector3) -> bool: return absf(p.x) < 2.6 and absf(p.z) > 3.0
	EnvProps.plinth_trim(env, rect, -0.2, KEEP_H, _m["basalt"], _m["obsidian"], gap)
	# forge runes on the keep top
	for k in 4:
		var a := PI * 0.5 * k
		env.add(EnvKit.box(Vector3(5.0, 0.03, 0.12)), _m["rune"], Transform3D(Basis(Vector3.UP, a), Vector3(0, KEEP_H + 0.02, 0) + Basis(Vector3.UP, a) * Vector3(0, 0, 2.6)), false)
	env.add(EnvKit.lathe([Vector2(1.6, 0.0), Vector2(1.7, 0.0)], 24), _m["rune"], Transform3D(Basis(), Vector3(0, KEEP_H + 0.03, 0)), false)
	kit.ramp(Vector3(0, KEEP_H, -KEEP_HALF), 180.0, 6.0, 4.0, 0.0, false)
	kit.ramp(Vector3(0, KEEP_H, KEEP_HALF), 0.0, 6.0, 4.0, 0.0, false)
	EnvProps.stairs(env, Vector3(0, KEEP_H, -KEEP_HALF), 180.0, 6.0, 4.0, -0.05, _m["stone"], _m["basalt"])
	EnvProps.stairs(env, Vector3(0, KEEP_H, KEEP_HALF), 0.0, 6.0, 4.0, -0.05, _m["stone"], _m["basalt"])
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 3.5, KEEP_H, 0)
		env.add(EnvKit.box(Vector3(0.7, 1.4, 4.0)), _m["stone"], Transform3D(Basis(), p + Vector3(0, 0.7, 0)))
		env.add(EnvKit.box(Vector3(0.12, 0.6, 3.0)), _m["rune"], Transform3D(Basis(), p + Vector3(-sx * 0.36, 0.7, 0)), false)
		kit.col_box(p + Vector3(0, 0.7, 0), Vector3(4.0, 1.4, 0.7), 90.0, "KeepRail")
	for p: Vector3 in [Vector3(-3.3, KEEP_H, -3.3), Vector3(3.3, KEEP_H, 3.3)]:
		env.add(EnvKit.lathe([Vector2(0.45, 0.0), Vector2(0.35, 0.2), Vector2(0.3, 1.2), Vector2(0.5, 1.4)], 8), _m["stone"], Transform3D(Basis(), p))
		env.add(EnvKit.lathe([Vector2(0.2, 1.4), Vector2(0.5, 1.55), Vector2(0.45, 1.7)], 8), _m["iron"], Transform3D(Basis(), p), false)
		env.flame(p + Vector3(0, 1.55, 0), 1.0)
		kit.col_cyl(p, 0.35, 1.4)
	add_omni(Vector3(-3.3, KEEP_H + 2.4, -3.3), Color(1.0, 0.62, 0.3), 1.6, 9.0)


## Basalt spire with collision from the same mesh (LOS breakers, unchanged positions and sizes).
func _spire(p: Vector3, h: float, r: float, seed_i: int) -> void:
	var m := EnvProps.spire(env, p, h, r, _m["basalt"], seed_i, float(seed_i) * 0.37)
	var cs := env.col_hull(m, Transform3D(Basis(Vector3.UP, float(seed_i) * 0.37), p), "Hull")
	cs.name = "Hull%d" % kit.shape_count
	kit.shape_count += 1


func _stalagmites() -> void:
	for p: Vector3 in [Vector3(-8.0, 0, -9.0), Vector3(8.0, 0, 9.0), Vector3(9.0, 0, -8.5), Vector3(-9.0, 0, 8.5)]:
		_spire(p, 6.5, 2.1, int(p.x * 11.0 + p.z) + 50)
		_spire(p + Vector3(signf(p.x) * 1.4, 0, -signf(p.z) * 0.6), 3.5, 1.5, int(p.z * 13.0) + 70)
		EnvProps.crystals(env, p + Vector3(-signf(p.x) * 1.6, 0, signf(p.z) * 0.9), _m["crystal"], int(p.x * 3.0) + 90, 0.7, 4)
	for p: Vector3 in [Vector3(-14.0, 0, -13.0), Vector3(14.0, 0, 13.0)]:
		_spire(p, 3.6, 1.6, int(p.x) + 120)
	for p: Vector3 in [Vector3(14.0, 0, -12.5), Vector3(-14.0, 0, 12.5)]:
		_spire(p, 4.5, 1.5, int(p.z) + 140)
	# organ-pipe basalt clusters in the corners behind the spawns (outside the walk lines, visual)
	for p: Vector3 in [Vector3(-16.0, 0, -18.5), Vector3(16.0, 0, 18.5), Vector3(16.0, 0, -18.5), Vector3(-16.0, 0, 18.5)]:
		EnvProps.basalt_columns(env, p, _m["basalt"], _m["stone"], int(p.x + p.z) + 160, 6, 0.8, 3.2)


func _landmarks() -> void:
	# primary: the Molten Gate - a 22 m rune ring standing in the northern lava lake
	var gate := Vector3(0, -1.0, -34.0)
	env.add(EnvKit.lathe([Vector2(10.0, -1.0), Vector2(11.4, 0.0), Vector2(10.0, 1.0), Vector2(8.6, 0.0), Vector2(10.0, -1.0)], 40), _m["obsidian"],
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), gate + Vector3(0, 10.0, 0)))
	env.add(EnvKit.lathe([Vector2(9.0, -1.05), Vector2(9.0, 1.05)], 40), _m["rune"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), gate + Vector3(0, 10.0, 0)), false)
	for k in 12:
		var a := TAU * k / 12.0
		var p := gate + Vector3(cos(a) * 10.0, 10.0 + sin(a) * 10.0, 0)
		env.add(EnvKit.lathe([Vector2(0.9, 0.0), Vector2(0.0, 2.6)], 4), _m["obsidian"], Transform3D(Basis(Vector3.FORWARD, a - PI * 0.5), p + Vector3(cos(a), sin(a), 0) * 1.0))
	var membrane := QuadMesh.new()
	membrane.size = Vector2(17.4, 17.4)
	env.add(membrane, EnvKit.shader_mat(load("res://visuals/shaders/painted_env_portal.gdshader")), Transform3D(Basis(), gate + Vector3(0, 10.0, 0)), false)
	for rr: float in [6.2, 3.6]:
		env.add(EnvKit.lathe([Vector2(rr - 0.06, -0.05), Vector2(rr + 0.06, -0.05), Vector2(rr + 0.06, 0.05), Vector2(rr - 0.06, 0.05), Vector2(rr - 0.06, -0.05)], 40), _m["rune"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), gate + Vector3(0, 10.0, 0.15)), false)
	for sx: float in [-1.0, 1.0]:
		EnvProps.basalt_columns(env, gate + Vector3(sx * 9.0, 0, 0), _m["basalt"], _m["stone"], 300 + int(sx), 8, 2.0, 6.0)
		# lava falls pouring from the cavern wall on both sides of the gate
		var top := Vector3(sx * 15.5, 22.0, -44.0)
		EnvProps.lava_fall(env, top, Vector3(sx * 14.0, -0.5, -38.0), 3.0, _m["lava_fall"])
	add_omni(gate + Vector3(0, 8.0, 6.0), Color("#FF6A2A"), 4.0, 30.0)
	# secondary: chained iron cage-bridge remains hanging over the south lake
	for i in 5:
		var p := Vector3(-8.0 + i * 4.0, 14.0 - absf(i - 2) * 1.5, 30.0)
		env.add(EnvKit.tube([p, p + Vector3(0, 9.0, 0)], 0.08, 4), _m["iron"], Transform3D.IDENTITY, false)
		env.add(EnvKit.box(Vector3(3.6, 0.3, 2.0)), _m["iron"], Transform3D(Basis(Vector3.FORWARD, 0.1 * (i - 2)), p), false)
	# big amber crystal growths on the cavern walls
	for p: Vector3 in [Vector3(-25.6, 0, 12.0), Vector3(25.6, 0, -14.0), Vector3(-25.6, 0, -6.0), Vector3(25.6, 0, 8.0), Vector3(-12.0, 0, 23.2), Vector3(10.0, 0, 23.2)]:
		p.y = _wall_h(p.x, p.z) - 0.6
		EnvProps.crystals(env, p, _m["crystal"], int(p.x * 5.0 + p.z), 2.4, 6)
	add_omni(Vector3(0, 6.0, 0), Color("#9A8AFF"), 0.8, 14.0)


# ================================================================== hazard (host only)
func _physics_process(delta: float) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_lava_timer += delta
	if _lava_timer < LAVA_TICK:
		return
	_lava_timer -= LAVA_TICK
	var w := World.get_instance()
	if w == null:
		return
	for f: Fighter in w.fighters:
		if not is_instance_valid(f) or not f.is_alive():
			continue
		var p := f.global_position
		if p.y > 0.4 or not is_lava(p):
			continue
		f.take_dot_damage(f.max_hp * LAVA_DMG, null, &"burn")
		f.add_status(&"slow", 0.6, 0.25)
		CoreUtil.fx(&"play", [&"fire_burst", p, Vector3.FORWARD, Color(1.0, 0.5, 0.15), 0.5])
