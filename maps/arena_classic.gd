extends ArenaMap
## 竞技场 Classic Arena - "Glory Stage" pro-league duel ring on a cliff plateau at dusk (bible 4.2 Pro arena).
## Gameplay (unchanged): round 36 m floor, boundary ring wall, four LOS rune pylons on the diagonals, low stone
## barricades on the east / west flanks, teams spawn north (-Z) and south (+Z). New: a low central dais (+1.2 m,
## 23 deg slopes) as high ground.
## Composition: primary landmark = rune obelisk with floating rings on a cliff spur to the east; secondaries = the
## two team gates (blue north / red south), a colossal planted sword monument to the west, floating rock islands.
## Value: mid-value slate floor, dark parapet framing, bright warm dusk sky and hazy valley behind.

const R: float = 18.0          # inner radius of the play area
const SEGMENTS: int = 28
const DAIS_H: float = 1.2
const DAIS_TOP: float = 3.2
const DAIS_BOT: float = 6.0

var _rock: Material
var _stone: Material
var _stone_dark: Material
var _trim: Material


func _init() -> void:
	map_id = "classic_arena"
	name_cn = "竞技场"
	name_en = "Classic Arena"
	size = Vector2(36.0, 36.0)
	center = Vector3.ZERO


func _build_map() -> void:
	setup_atmosphere("glory_stage")
	_rock = EnvKit.paint(Color("#7A6E92"), Color("#433C5E"), {"snow_amount": 0.32, "snow_col": Color("#7A9A6A"), "snow_shadow_tint": Color("#4A5A8A"),
		"strata": 1.0, "ledges": 0.9, "noise_scale": 0.3, "warm_amount": 0.7, "warm_col": Color("#E0A070"), "shade_tint": Color("#4A3E8A"),
		"cover_col2": Color("#8A9A66", 0.7), "cover_col3": Color("#A08A70", 0.5), "macro": 0.5, "macro_scale": 0.03})
	_stone = EnvKit.paint(Color("#B4AAB8"), Color("#7A7090"), {"snow_amount": 0.0, "noise_scale": 0.8, "paint_strength": 0.35, "blocks": 0.6,
		"warm_amount": 0.6, "warm_col": Color("#F0C090"), "shade_tint": Color("#5A4E9A")})
	_stone_dark = EnvKit.paint(Color("#4E4A6A"), Color("#2E2A48"), {"snow_amount": 0.0, "noise_scale": 0.9, "blocks": 0.5, "shade_tint": Color("#3A2E7A")})
	_trim = EnvKit.paint(Color("#E0B860"), Color("#A07030"), {"snow_amount": 0.0, "noise_scale": 2.0, "paint_strength": 0.2, "shade_tint": Color("#8A5A2B")})
	_floor()
	_plateau()
	_ring_wall()
	_dais()
	_pylons()
	_barricades()
	_stands()
	_landmarks()
	_sky_dressing()
	# lanterns at the wall (E, W lit) and beside each spawn
	var lamp := Color("#7FE8FF")
	for a_deg: float in [0.0, 180.0, 60.0, 120.0, 240.0, 300.0]:
		var a := deg_to_rad(a_deg)
		add_lantern(Vector3(cos(a) * (R - 1.0), 0, sin(a) * (R - 1.0)), _stone, lamp, int(a_deg) % 180 == 0)
	env.particles(Vector3(0, 3.0, 0), Vector3(20, 3, 20), 220, 8.0, Color("#FFD9A0"), 0.08, Vector3(0.1, 0.12, 0.0), "spark", 2.0)
	env.particles(Vector3(0, 0.6, 0), Vector3(R, 0.4, R), 90, 4.0, Color("#7FE8FF"), 0.06, Vector3(0, 0.5, 0), "spark", 3.0)
	test_walks = [
		{"name": "spawn->center", "from": Vector3(0, 0, -13), "to": Vector3(0, 0, -1), "min_y": -1.0},
		{"name": "behind the west barricade", "from": Vector3(-15, 0, -6), "to": Vector3(-15, 0, 1), "min_y": -1.0},
		{"name": "up the dais", "from": Vector3(0, 0, 12), "to": Vector3(0, 0, 0.5), "min_y": DAIS_H - 0.3},
	]
	set_spawns_line(0, Vector3(0, 0, -13.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 13.0), Vector3.RIGHT, 2.2)


func _floor() -> void:
	var fm := EnvKit.shader_mat(EnvKit.FLOOR, {"radius": R + 0.2, "ring_width": 1.8, "seal_radius": 0.0, "glyph_count": 160.0,
		"stone_a": Color("#3E4466"), "stone_b": Color("#5A6088"), "grout": Color("#1C1F36"), "frost": Color("#D8C8E0"),
		"frost_amount": 0.07, "rune_col": Color("#4FD8FF"), "rune_energy": 2.4, "shade_tint": Color("#5A4E9A")})
	var disc := CylinderMesh.new()
	disc.top_radius = R + 0.9
	disc.bottom_radius = R + 0.9
	disc.height = 0.1
	disc.radial_segments = 72
	disc.rings = 1
	env.add(disc, fm, Transform3D(Basis(), Vector3(0, -0.05, 0)), false)
	# outer ground collision (as before) - the terrain outside is visual only
	kit.col_box(Vector3(0, -1.5, 0), Vector3(160, 3.0, 160), 0.0, "Ground")


func _height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var n := env.noise.get_noise_2d(x, z)
	if d < R + 3.0:
		return -0.08 + n * 0.15
	# cliff edge of the plateau, dropping into a hazy valley; rock spurs east (obelisk) and west (sword)
	var edge := R + 9.0 + env.noise.get_noise_2d(cos(atan2(z, x)) * 40.0, sin(atan2(z, x)) * 40.0) * 6.0
	var t := clampf((d - edge) / 10.0, 0.0, 1.0)
	var hills := env.noise.get_noise_2d(x * 0.35 + 300.0, z * 0.35) * 16.0 + absf(env.noise.get_noise_2d(x * 0.8, z * 0.8 + 90.0)) * 10.0
	var drop := -smoothstep(0.0, 1.0, t) * 24.0 + n * 4.0 * t + hills * clampf((d - edge - 6.0) / 40.0, 0.0, 1.0)
	var ridge := (env.noise.get_noise_2d(x * 2.2 + 40.0, z * 2.2) * 0.5 + 0.5) * 5.0 * t
	drop = lerpf(-0.08 + n * 0.15, drop, smoothstep(R + 3.0, R + 6.0, d))
	var spur := maxf(exp(-pow(Vector2(x - 36.0, z).length() / 9.0, 2.0)), exp(-pow(Vector2(x + 38.0, z - 4.0).length() / 8.0, 2.0)))
	return lerpf(drop + ridge, -0.5 + n * 1.5, clampf(spur * 1.3, 0.0, 1.0))


func _plateau() -> void:
	env.terrain(Rect2(-130, -130, 260, 260), 2.0, _height, _rock, Rect2(), 0.08)
	# grass tufts and wild flowers on the terrace ring (one MultiMesh each)
	var tuft := EnvKit.tuft_mesh(0.4, 0.06)
	var gmat := EnvKit.grass_mat(Color("#3E5A4A"), Color("#A8C878"), Color("#5A5AA0"), 0.1)
	var flower := EnvKit.tuft_mesh(0.28, 0.08)
	var fmat := EnvKit.grass_mat(Color("#3E5A4A"), Color.WHITE, Color("#6A5AA0"), 0.08, true)
	var fcols: Array[Color] = [Color("#FFD27A"), Color("#FF9AC0"), Color("#C8A8FF"), Color("#FFFFFF")]
	for i in 1500:
		var a := env.rng.randf() * TAU
		var d := sqrt(env.rng.randf_range(pow(R + 1.6, 2.0), pow(R + 10.0, 2.0)))
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var y := _height(p.x, p.z)
		if y < -0.6:
			continue
		var xf := Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU).scaled(Vector3.ONE * env.rng.randf_range(0.7, 1.4)), p + Vector3(0, y, 0))
		if i % 5 == 0:
			env.inst(flower, fmat, xf, false, fcols[i % fcols.size()])
		else:
			env.inst(tuft, gmat, xf, false)
	# scattered boulders on the terrace ring
	for i in 22:
		var a := env.rng.randf() * TAU
		var d := env.rng.randf_range(R + 3.5, R + 9.5)
		if absf(sin(a)) > 0.8:
			continue
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		EnvProps.rock(env, p + Vector3(0, _height(p.x, p.z), 0), env.rng.randf_range(0.6, 1.6), _rock, 700 + i, env.rng.randf() * TAU)
	env.backdrop({"haze": Color("#F2C4A8"), "far_col": Color("#B898C0"), "mid_col": Color("#7E6AA4"), "near_col": Color("#54487E"),
		"snow_col": Color("#FFE0D8"), "warm_col": Color("#FFB890"), "snow_caps": 0.35, "h_scale": 0.42})
	# valley forest far below the plateau (violet silhouettes in the haze)
	var pine := EnvKit.pine_mesh()
	var pmat := EnvKit.paint(Color("#3E3A6A"), Color("#2A2650"), {"snow_amount": 0.25, "snow_col": Color("#C8A8C8"), "noise_scale": 1.2})
	var placed := 0
	while placed < 520:
		var x := env.rng.randf_range(-120, 120)
		var z := env.rng.randf_range(-120, 120)
		var d := Vector2(x, z).length()
		if d < R + 22.0 or d > 125.0:
			continue
		var y := _height(x, z)
		if y > -7.0 or env.rng.randf() < 0.25:
			continue
		var s := env.rng.randf_range(1.6, 3.0)
		env.inst(pine, pmat, Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU).scaled(Vector3(s, s * env.rng.randf_range(0.9, 1.3), s)), Vector3(x, y - 0.3, z)), false)
		placed += 1


func _ring_wall() -> void:
	var wr := R + 0.5
	var lip := EnvKit.glow(Color("#4FD8FF"), 2.4)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var p0 := Vector3(cos(a0) * wr, 0, sin(a0) * wr)
		var p1 := Vector3(cos(a1) * wr, 0, sin(a1) * wr)
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1) + 0.6
		var yaw := atan2(-(p1.z - p0.z), p1.x - p0.x)
		# low carved parapet (keeps the cliff vista open), rune lip at the floor edge
		env.add(EnvKit.box(Vector3(seg_len - 0.5, 1.1, 0.7)), _stone, Transform3D(Basis(Vector3.UP, yaw), mid + mid.normalized() * 0.3 + Vector3(0, 0.55, 0)))
		env.add(EnvKit.box(Vector3(seg_len - 0.3, 0.16, 0.9)), _trim, Transform3D(Basis(Vector3.UP, yaw), mid + mid.normalized() * 0.3 + Vector3(0, 1.18, 0)), false)
		env.add(EnvKit.box(Vector3(seg_len - 0.4, 0.06, 0.08)), lip, Transform3D(Basis(Vector3.UP, yaw), mid - mid.normalized() * 0.08 + Vector3(0, 0.25, 0)), false)
		EnvProps.pier(env, p0 + p0.normalized() * 0.3, Vector2(0.9, 0.9), 1.9 if i % 2 == 0 else 1.5, _stone_dark, -a0, i % 2 == 0)
		kit.col_box(Vector3(mid.x, 8.0, mid.z) + mid.normalized() * 0.5, Vector3(seg_len, 16.0, 2.0), rad_to_deg(yaw), "Ring")
	# plinth skirt under the parapet down to the terrace
	env.add(EnvKit.lathe([Vector2(R + 1.6, -1.2), Vector2(R + 1.2, 0.0), Vector2(R + 0.9, 0.0)], 56), _stone_dark, Transform3D(Basis(), Vector3.ZERO))


func _dais() -> void:
	var prof := [Vector2(DAIS_BOT, 0.0), Vector2(DAIS_TOP, DAIS_H)]
	var side := EnvKit.lathe(prof, 8)
	env.add(side, _stone, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3(0, -0.02, 0)))
	var top := CylinderMesh.new()
	top.top_radius = DAIS_TOP / cos(PI / 8.0)
	top.bottom_radius = DAIS_TOP / cos(PI / 8.0)
	top.height = 0.06
	top.radial_segments = 8
	top.rings = 1
	var tm := EnvKit.shader_mat(EnvKit.FLOOR, {"radius": DAIS_TOP + 0.2, "ring_width": 1.1, "seal_radius": 1.9, "glyph_count": 48.0,
		"stone_a": Color("#4A5078"), "stone_b": Color("#646A94"), "grout": Color("#1C1F36"), "frost_amount": 0.0,
		"rune_col": Color("#FFD27A"), "rune_energy": 2.2, "shade_tint": Color("#5A4E9A")})
	env.add(top, tm, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3(0, DAIS_H - 0.03, 0)), false)
	env.add(EnvKit.lathe([Vector2(DAIS_TOP + 0.05, DAIS_H - 0.02), Vector2(DAIS_TOP + 0.05, DAIS_H + 0.06)], 8), _trim, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3.ZERO), false)
	# collision: convex frustum through the same octagon
	var pts := PackedVector3Array()
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		pts.append(Vector3(cos(a) * DAIS_BOT, -0.02, sin(a) * DAIS_BOT))
		pts.append(Vector3(cos(a) * DAIS_TOP, DAIS_H, sin(a) * DAIS_TOP))
	var cvx := ConvexPolygonShape3D.new()
	cvx.points = pts
	var cs := CollisionShape3D.new()
	cs.name = "Dais%d" % kit.shape_count
	cs.shape = cvx
	kit.body.add_child(cs)
	kit.shape_count += 1


func _pylons() -> void:
	var rune := EnvKit.glow(Color("#4FD8FF"), 3.0)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var p := Vector3(cos(a) * 8.0, 0, sin(a) * 8.0)
		var yaw := -a + PI * 0.5
		EnvProps.pier(env, p, Vector2(1.6, 1.6), 4.0, _stone, yaw, true)
		for sgn: float in [-1.0, 1.0]:
			env.add(EnvKit.box(Vector3(0.14, 2.6, 0.06)), rune, Transform3D(Basis(Vector3.UP, yaw), p + Basis(Vector3.UP, yaw) * Vector3(0, 2.0, sgn * 0.83)), false)
		env.add(EnvKit.box(Vector3(1.8, 0.2, 1.8)), _trim, Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 4.0, 0)), false)
		kit.col_box(p + Vector3(0, 2.0, 0), Vector3(1.6, 4.0, 1.6), rad_to_deg(-a) + 90.0, "Pillar")


func _barricades() -> void:
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * 11.5, 0, 0)
		_low_wall(c, Vector3(4.0, 1.1, 0.5), deg_to_rad(90.0))
		kit.col_box(c + Vector3(0, 0.55, 0), Vector3(4.0, 1.1, 0.5), 90.0, "Barrier")
		for sz: float in [1.0, -1.0]:
			var p := c + Vector3(sx * 1.5, 0, sz * 4.0)
			var yaw := 90.0 - sx * 30.0 * sz
			_low_wall(p, Vector3(4.0, 1.4, 0.7), deg_to_rad(yaw))
			kit.col_box(p + Vector3(0, 0.7, 0), Vector3(4.0, 1.4, 0.7), yaw, "Barrier")


## Stone half-wall exactly matching its collision box, gold coping and a rubble foot.
func _low_wall(c: Vector3, s: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	env.add(EnvKit.box(s), _stone, Transform3D(b, c + Vector3(0, s.y * 0.5, 0)))
	env.add(EnvKit.box(Vector3(s.x + 0.1, 0.12, s.z + 0.14)), _trim, Transform3D(b, c + Vector3(0, s.y + 0.04, 0)), false)
	for e: float in [-1.0, 1.0]:
		env.add(EnvKit.box(Vector3(0.3, s.y + 0.25, s.z + 0.2)), _stone_dark, Transform3D(b, c + b * Vector3(e * s.x * 0.5, 0, 0) + Vector3(0, (s.y + 0.25) * 0.5, 0)), false)


## Spectator terraces on the east and west arcs (visual): 4 stepped tiers, banner pylons on top.
func _stands() -> void:
	for side: float in [0.0, PI]:
		for tier in 4:
			var r0 := R + 2.2 + tier * 1.4
			var h := 0.6 + tier * 0.75
			var a0 := side - 0.95
			var a1 := side + 0.95
			var segs := 18
			for i in segs:
				var a := lerpf(a0, a1, (i + 0.5) / segs)
				var p := Vector3(cos(a) * (r0 + 0.7), 0, sin(a) * (r0 + 0.7))
				var w := (r0 + 0.7) * (a1 - a0) / segs + 0.05
				env.add(EnvKit.box(Vector3(1.4, h, w)), _stone_dark if tier % 2 == 0 else _stone, Transform3D(Basis(Vector3.UP, -a), p + Vector3(0, h * 0.5 - 0.1, 0)))
		for k in 5:
			var a := side + lerpf(-0.8, 0.8, k / 4.0)
			var p := Vector3(cos(a), 0, sin(a)) * (R + 8.6)
			var team_tex := "banner_blue.png" if sin(a) < 0.0 else "banner_red.png"
			EnvProps.banner(env, p + Vector3(0, 3.3, 0), team_tex, Color.WHITE, 6.0, _stone_dark, _trim, -a + PI * 0.5)


func _landmarks() -> void:
	# primary: the rune obelisk on the eastern spur (top of the spur ~ y 0)
	var crystal := EnvKit.glow(Color("#9FE6FF"), 3.5)
	EnvProps.obelisk(env, Vector3(36.0, _height(36.0, 0.0) - 0.5, 0.0), 26.0, _stone, _trim, EnvKit.glow(Color("#4FD8FF"), 3.2), crystal)
	add_omni(Vector3(36.0, 30.0, 0.0), Color("#7FE8FF"), 3.0, 24.0)
	# team gates behind each spawn (north blue, south red)
	for team in [0, 1]:
		var z := -(R + 3.2) if team == 0 else (R + 3.2)
		var col: Color = TEAM_COLORS[team]
		EnvProps.team_gate(env, Vector3(0, -0.1, z), 0.0, 7.0, 7.5, _stone, _trim, EnvKit.glow(col, 3.0))
		for sx: float in [-1.0, 1.0]:
			EnvProps.banner(env, Vector3(sx * 5.6, 0, z + signf(z) * 0.4), "banner_blue.png" if team == 0 else "banner_red.png", Color.WHITE, 6.5, _stone_dark, _trim)
		add_omni(Vector3(0, 6.0, z), col, 1.6, 12.0)
	# secondary: colossal planted sword on the western spur
	var at := Vector3(-38.0, _height(-38.0, 4.0) - 1.0, 4.0)
	var steel := EnvKit.paint(Color("#D8E0F0"), Color("#8A94B8"), {"snow_amount": 0.0, "noise_scale": 0.35, "paint_strength": 0.12, "rim_amount": 0.8, "shade_tint": Color("#5A5EA8"), "stroke": 0.0})
	var tilt := Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, 0.18 + PI) * Basis(Vector3.RIGHT, -0.08)
	at += Vector3(0, 18.0, 0)
	var blade := PackedVector2Array([Vector2(-1.5, -8.0), Vector2(1.5, -8.0), Vector2(1.25, 18.0), Vector2(0.0, 22.0), Vector2(-1.25, 18.0)])
	env.add(EnvKit.extrude(blade, 0.55, 0.35), steel, Transform3D(tilt, at))
	env.add(EnvKit.box(Vector3(0.28, 24.0, 0.62)), EnvKit.glow(Color("#7FE8FF"), 2.0), Transform3D(tilt, at + tilt * Vector3(0, 6.0, 0)), false)
	var guard := PackedVector2Array([Vector2(-5.2, 0.6), Vector2(-3.0, -0.3), Vector2(0.0, -0.9), Vector2(3.0, -0.3), Vector2(5.2, 0.6), Vector2(4.4, 1.0), Vector2(1.6, 0.6), Vector2(0.0, 1.4), Vector2(-1.6, 0.6), Vector2(-4.4, 1.0)])
	env.add(EnvKit.extrude(guard, 1.2, 0.15), _trim, Transform3D(tilt, at + tilt * Vector3(0, -8.6, 0)))
	env.add(EnvKit.cyl(0.5, 0.6, 6.0, 8), _stone_dark, Transform3D(tilt, at + tilt * Vector3(0, -12.0, 0)))
	env.add(EnvKit.sphere(1.1, 8), crystal, Transform3D(tilt, at + tilt * Vector3(0, -15.6, 0)), false)
	at -= Vector3(0, 18.0, 0)
	for i in 6:
		EnvProps.rock(env, at + Vector3(env.rng.randf_range(-3, 3), -0.5, env.rng.randf_range(-3, 3)), env.rng.randf_range(1.2, 2.4), _rock, 820 + i)


func _sky_dressing() -> void:
	# floating rock islands with crystal undersides drifting over the valley
	var crystal := EnvKit.glow(Color("#B37BFF"), 2.0)
	for i in 7:
		var a := env.rng.randf_range(-PI, PI)
		if absf(a) < 0.5 or absf(absf(a) - PI) < 0.4:
			a += 0.8
		var d := env.rng.randf_range(55.0, 110.0)
		var p := Vector3(cos(a) * d, env.rng.randf_range(4.0, 26.0), sin(a) * d)
		var r := env.rng.randf_range(2.5, 6.0)
		env.add(EnvKit.rock_mesh(r, 0.45, 900 + i), _rock, Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU).scaled(Vector3(1.0, 0.55, 1.0)), p), false)
		env.add(EnvKit.lathe([Vector2(r * 0.8, 0.0), Vector2(0.0, -r * 1.6)], 6), _rock, Transform3D(Basis(Vector3.UP, env.rng.randf() * TAU), p), false)
		EnvProps.crystals(env, p - Vector3(0, r * 0.6, 0), crystal, 950 + i, r * 0.3, 3)
