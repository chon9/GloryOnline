extends ArenaMap
## 百花谷 Hundred Blossoms Valley - 50 m team map in a Chinese-fantasy blossom valley (warm spring day).
## Gameplay (unchanged): flowered valley floor between two raised stone terraces (4.5 m high ground for ranged
## classes) reached by stairs at both ends, joined by a lacquered bridge over the middle of the valley; rocks and
## blossom trees break line of sight in the valley.
## Composition: primary landmark = seven-tier pagoda on the north ridge (visible from anywhere); secondaries = the
## roofed bridge pavilion (廊桥) at the centre, an ancient giant blossom tree on the south ridge, paifang gates
## behind each spawn. Palette: warm sandstone, red lacquer, jade-teal roof tiles, gold, pink blossoms, fresh green.

const HALF: float = 25.0
## 4.5 m: above World.ground_y()'s +4 m probe so ground_point() under the bridge stays on the valley floor.
const PLAT_H: float = 4.5

var _m: Dictionary = {}


func _init() -> void:
	map_id = "hundred_blossoms"
	name_cn = "百花谷"
	name_en = "Hundred Blossoms Valley"
	size = Vector2(50.0, 50.0)
	center = Vector3.ZERO


func _mats() -> void:
	var shade := Color("#5A6AA8")
	# one painted ground for valley floor and walls: cover = desaturated spring grass with hue / dry patches,
	# steep faces = layered sandstone cliffs with ledges, vertex masks = worn earth paths and damp hollows
	_m["ground"] = EnvKit.paint(Color("#A89484"), Color("#5E5664"), {"snow_amount": 0.4, "snow_col": Color("#78965C"), "snow_shadow_tint": Color("#3E5A70"),
		"snow_sharp": 0.1, "strata": 1.0, "ledges": 0.8, "noise_scale": 0.3, "paint_strength": 0.6, "warm_amount": 0.35, "warm_col": Color("#E8B888"),
		"shade_tint": shade, "stroke": 0.25, "cover_col2": Color("#9AA262", 0.75), "cover_col3": Color("#B49C70", 0.5), "macro": 0.55,
		"macro_scale": 0.03, "use_vertex_masks": 1.0, "wear_col": Color("#A68C6C")})
	_m["grass"] = _m["ground"]
	_m["hill"] = _m["ground"]
	_m["petals"] = EnvKit.foliage("leaves_blossom.png", Color(1, 1, 1), Color(0.62, 0.42, 0.7), Color(1.0, 0.85, 0.8), 0.0)
	_m["shrub"] = EnvKit.foliage("leaves_green.png", Color(0.85, 0.9, 0.8), Color(0.45, 0.6, 0.7), Color(1.0, 0.95, 0.7), 0.03)
	_m["shrub_core"] = EnvKit.paint(Color("#3E6A4E"), Color("#24443E"), {"snow_amount": 0.0, "noise_scale": 1.2, "shade_tint": Color("#2A3A6A"), "stroke": 0.0})
	_m["panel"] = EnvKit.paint(Color("#B09A84"), Color("#8E7A6A"), {"snow_amount": 0.0, "noise_scale": 1.0, "paint_strength": 0.3, "shade_tint": shade, "stroke": 0.0})
	_m["stone"] = EnvKit.paint(Color("#C4AE94"), Color("#8A786C"), {"snow_amount": 0.0, "noise_scale": 0.7, "paint_strength": 0.3, "blocks": 0.55,
		"warm_amount": 0.5, "warm_col": Color("#F0D0A0"), "shade_tint": shade})
	_m["paving"] = EnvKit.paint(Color("#B8A084"), Color("#8E7A66"), {"snow_amount": 0.0, "noise_scale": 0.9, "paint_strength": 0.25, "shade_tint": shade, "stroke": 0.0})
	_m["lacquer"] = EnvKit.paint(Color("#C0302C"), Color("#8A1A22"), {"snow_amount": 0.0, "noise_scale": 1.5, "paint_strength": 0.15, "shade_tint": Color("#6A2A5A"), "stroke": 0.0})
	_m["lacquer_dark"] = EnvKit.paint(Color("#6A1A1E"), Color("#4A1018"), {"snow_amount": 0.0, "noise_scale": 1.5, "paint_strength": 0.15, "shade_tint": Color("#3A1A4A"), "stroke": 0.0})
	_m["tiles"] = EnvKit.paint(Color("#3E7A78"), Color("#24505A"), {"snow_amount": 0.0, "noise_scale": 1.8, "paint_strength": 0.3, "shade_tint": Color("#2A3A6A"), "rim_amount": 0.3})
	_m["gold"] = EnvKit.paint(Color("#E8C060"), Color("#B08030"), {"snow_amount": 0.0, "noise_scale": 2.0, "paint_strength": 0.15, "shade_tint": Color("#8A5A2B"), "stroke": 0.0})
	_m["wood"] = EnvKit.paint(Color("#8A5A3A"), Color("#5A3A28"), {"snow_amount": 0.0, "noise_scale": 2.5, "paint_strength": 0.3, "shade_tint": Color("#4A3A5A")})
	_m["bark"] = EnvKit.paint(Color("#5A3E3A"), Color("#3A2828"), {"snow_amount": 0.0, "noise_scale": 2.0, "shade_tint": Color("#3A2A4A")})
	_m["paper"] = EnvKit.glow(Color("#FF6A4A"), 1.6)
	_m["window"] = EnvKit.glow(Color("#FFC870"), 1.2)
	_m["wall"] = EnvKit.paint(Color("#E8DCC8"), Color("#C0AE98"), {"snow_amount": 0.0, "noise_scale": 0.8, "paint_strength": 0.2, "shade_tint": shade})
	_m["blossom"] = EnvKit.foliage("leaves_blossom.png", Color(1, 1, 1), Color(0.62, 0.42, 0.7), Color(1.0, 0.85, 0.8))
	_m["blossom_core"] = EnvKit.paint(Color("#D86A9A"), Color("#A84478"), {"snow_amount": 0.0, "noise_scale": 1.2, "paint_strength": 0.3, "shade_tint": Color("#6A3A7A"), "stroke": 0.0})
	_m["green"] = EnvKit.foliage("leaves_green.png", Color(1, 1, 1), Color(0.45, 0.6, 0.7), Color(1.0, 0.95, 0.7))
	_m["green_core"] = EnvKit.paint(Color("#3E7A5A"), Color("#2A5A4A"), {"snow_amount": 0.0, "noise_scale": 1.2, "shade_tint": Color("#2A4A6A"), "stroke": 0.0})
	_m["water"] = EnvKit.shader_mat(EnvKit.WATER, {"deep": Color("#2A7A8A"), "shallow": Color("#7AD0C8"), "alpha": 0.85})


func _build_map() -> void:
	setup_atmosphere("blossom")
	_mats()
	_ground()
	_terraces()
	_bridge()
	_valley_cover()
	_landmarks()
	_vegetation()
	# boundary: invisible outer walls (the valley sides rise beyond them)
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	env.particles(Vector3(0, 9, 0), Vector3(28, 6, 28), 260, 9.0, Color("#FFC2D6"), 0.16, Vector3(0.5, -0.6, 0.2), "petal", 0.6, -0.1)
	env.particles(Vector3(0, 2.5, 0), Vector3(24, 2.5, 24), 140, 7.0, Color("#FFF2C0"), 0.07, Vector3(0.1, 0.1, 0.0), "spark", 1.8)
	test_walks = [
		{"name": "west ramp up", "from": Vector3(-17, 0, -23), "to": Vector3(-17, PLAT_H, -6), "min_y": PLAT_H - 0.3},
		{"name": "east ramp up (south)", "from": Vector3(17, 0, 23), "to": Vector3(17, PLAT_H, 6), "min_y": PLAT_H - 0.3},
		{"name": "bridge crossing", "from": Vector3(-13, PLAT_H, 0), "to": Vector3(13, PLAT_H, 0), "min_y": PLAT_H - 0.3},
		{"name": "under the bridge", "from": Vector3(0, 0, -7), "to": Vector3(0, 0, 7), "min_y": -1.0},
	]
	set_spawns_line(0, Vector3(0, 0, -21.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 21.0), Vector3.RIGHT, 2.2)


func _height(x: float, z: float) -> float:
	var ax := absf(x)
	var az := absf(z)
	var n := env.noise.get_noise_2d(x, z)
	var d := maxf(ax - (HALF + 1.5), maxf(az - (HALF + 1.5), 0.0))
	if d <= 0.0:
		return n * 0.03
	# valley walls: terraced sandstone cliffs (painted ledges) rising into rolling ridges with a sharp crest line
	var rise := smoothstep(0.0, 22.0, d) * 15.0 + maxf(0.0, d - 22.0) * 0.3
	rise += (env.noise.get_noise_2d(x * 1.8 + 50.0, z * 1.8) * 0.5 + 0.5) * 6.0 * smoothstep(2.0, 12.0, d)
	rise += absf(env.noise.get_noise_2d(x * 0.9 + 7.0, z * 0.9)) * 8.0 * smoothstep(20.0, 45.0, d)
	var stepped := EnvKit.terrace(rise, 3.4, 0.28)
	rise = lerpf(rise, stepped, 0.8 * smoothstep(1.0, 6.0, d))
	var pag := exp(-pow(Vector2(x, z + 50.0).length() / 14.0, 2.0)) * 6.0
	var south := exp(-pow(Vector2(x - 4.0, z - 48.0).length() / 12.0, 2.0)) * 4.0
	return n * 0.4 + rise + pag + south


## Vertex masks: r = worn earth (lanes, stair feet, the path up to the pagoda), g = damp hollows / wall-foot shade.
func _mask(x: float, z: float) -> Color:
	var ax := absf(x)
	var az := absf(z)
	var wn := env.noise.get_noise_2d(x * 3.0, z * 3.0) * 0.6
	var wear := 0.0
	if az < HALF + 1.0 and ax < HALF + 1.0:
		wear = maxf(wear, smoothstep(2.2 + wn, 0.6, ax))
		if ax < 17.5:
			wear = maxf(wear, smoothstep(1.9 + wn, 0.5, absf(az - 18.0)))
		wear = maxf(wear, smoothstep(3.2, 1.0, Vector2(ax - 17.0, az - 21.0).length() + wn))
	elif z < 0.0 and z > -46.0:
		wear = smoothstep(2.4 + wn, 0.8, absf(x - sin(z * 0.12) * 4.0))
	var hollow := 0.0
	if az < 12.5 and (absf(ax - 12.0) < 1.2 or absf(ax - 22.0) < 1.2):
		hollow = 0.5 * smoothstep(1.2, 0.0, minf(absf(ax - 12.0), absf(ax - 22.0)))
	hollow = maxf(hollow, clampf(-env.noise.get_noise_2d(x * 0.6 + 33.0, z * 0.6) * 1.2, 0.0, 0.45))
	return Color(wear, hollow, 0.0, 1.0)


func _ground() -> void:
	kit.col_box(Vector3(0, -1.5, 0), Vector3(180, 3.0, 180), 0.0, "Ground")
	env.terrain(Rect2(-HALF - 2.0, -HALF - 2.0, 2.0 * HALF + 4.0, 2.0 * HALF + 4.0), 1.0, _height, _m["ground"], Rect2(), 0.1, Callable(), true, false, _mask)
	var outer := func(x: float, z: float) -> bool: return absf(x) < HALF + 1.5 and absf(z) < HALF + 1.5
	env.terrain(Rect2(-130, -130, 260, 260), 2.2, _height, _m["ground"], Rect2(), 0.06, outer, true, false, _mask)
	# the stream under the bridge (visual; ground stays at y 0) with pebble banks
	var pts: Array = []
	for i in 11:
		var t := float(i) / 10.0
		pts.append(Vector3(sin(t * PI * 1.5) * 1.2 + 0.5, 0.035, lerpf(-9.5, 9.5, t)))
	var w: Array = []
	var sides: Array = []
	for i in pts.size():
		w.append(2.6 if i > 0 and i < pts.size() - 1 else 1.4)
		sides.append(Vector3(1, 0, 0))
	env.add(EnvKit.ribbon(pts, w, sides, 0.01), _m["water"], Transform3D.IDENTITY, false)
	for i in 40:
		var p: Vector3 = pts[i % pts.size()]
		var side := 1.0 if i % 2 == 0 else -1.0
		EnvProps.rock(env, p + Vector3(side * env.rng.randf_range(1.3, 1.9), -0.05, env.rng.randf_range(-0.9, 0.9)), env.rng.randf_range(0.12, 0.32), _m["stone"], 1200 + i, env.rng.randf() * TAU, 0.6, false)
	env.backdrop({"haze": Color("#E4ECEE"), "far_col": Color("#A8BCD0"), "mid_col": Color("#7E98AE"), "near_col": Color("#5E7E80"),
		"snow_col": Color("#F4F8FF"), "warm_col": Color("#FFE8D0"), "snow_caps": 0.5, "h_scale": 0.55})
	_edges()


## Edge clutter so no sightline ends on empty plain: a lacquer fence + lanterns on the boundary, shrub and rock
## clusters just outside it, shrubs and boulders on the cliff shelves.
func _edges() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4711
	var e := HALF + 0.7
	var lines := [[Vector3(-e, 0, -e), Vector3(e, 0, -e)], [Vector3(-e, 0, e), Vector3(e, 0, e)], [Vector3(-e, 0, -e), Vector3(-e, 0, e)], [Vector3(e, 0, -e), Vector3(e, 0, e)]]
	for k in 4:
		var a: Vector3 = lines[k][0]
		var b: Vector3 = lines[k][1]
		for seg in 6:
			var p0 := a.lerp(b, seg / 6.0)
			var p1 := a.lerp(b, (seg + 1) / 6.0)
			if k < 2 and absf((p0.x + p1.x) * 0.5) < 6.0:
				continue   # leave the paifang gate gaps open
			EnvProps.balustrade(env, p0, p1, 0.9, _m["lacquer"], _m["lacquer_dark"], 1.6)
			if seg % 2 == 0:
				EnvProps.lantern(env, p0 + p0.normalized() * 0.4, _m["stone"], _m["paper"], false, Color.WHITE)
	for i in 80:
		var side := i % 4
		var t := r.randf_range(-HALF - 4.0, HALF + 4.0)
		var out := r.randf_range(1.8, 5.0)
		var p: Vector3
		match side:
			0: p = Vector3(t, 0, -HALF - out)
			1: p = Vector3(t, 0, HALF + out)
			2: p = Vector3(-HALF - out, 0, t)
			_: p = Vector3(HALF + out, 0, t)
		p.y = _height(p.x, p.z) - 0.1
		if i % 3 == 0:
			EnvProps.rock(env, p, r.randf_range(0.5, 1.4), _m["ground"], 7000 + i, r.randf() * TAU, 0.8)
			EnvProps.rock(env, p + Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)), r.randf_range(0.3, 0.6), _m["ground"], 7100 + i, r.randf() * TAU, 0.7, false)
		elif i % 3 == 1:
			EnvProps.shrub(env, p, r.randf_range(1.0, 1.8), {"core": _m["shrub_core"], "cards": _m["shrub"]}, 7200 + i)
		else:
			EnvProps.shrub(env, p, r.randf_range(1.0, 1.6), {"core": _m["blossom_core"], "cards": _m["blossom"]}, 7200 + i)
	var placed := 0
	var tries := 0
	while placed < 110 and tries < 3000:
		tries += 1
		var p := Vector3(r.randf_range(-62, 62), 0, r.randf_range(-62, 62))
		var d := maxf(absf(p.x), absf(p.z)) - HALF
		if d < 6.0 or d > 36.0:
			continue
		p.y = _height(p.x, p.z) - 0.1
		if placed % 3 == 0:
			EnvProps.rock(env, p, r.randf_range(0.8, 2.2), _m["ground"], 7400 + placed, r.randf() * TAU, 0.7)
		else:
			EnvProps.shrub(env, p, r.randf_range(1.4, 2.4), {"core": _m["shrub_core"], "cards": _m["shrub"]}, 7500 + placed)
		placed += 1


func _terraces() -> void:
	for sx: float in [-1.0, 1.0]:
		var x0 := -22.0 if sx < 0 else 12.0
		var rect := Rect2(x0, -12.0, 10.0, 24.0)
		kit.platform_col(rect, PLAT_H)
		EnvProps.plinth(env, rect, 0.0, PLAT_H, _m["stone"], _m["paving"], _m["gold"])
		var stair_gap := func(p: Vector3) -> bool: return absf(absf(p.x) - 17.0) < 2.6 and absf(p.z) > 11.0
		EnvProps.plinth_trim(env, rect, 0.0, PLAT_H, _m["stone"], _m["panel"], stair_gap)
		var cx := sx * 17.0
		kit.ramp(Vector3(cx, PLAT_H, -12.0), 180.0, 9.0, 4.0, 0.0, false)
		kit.ramp(Vector3(cx, PLAT_H, 12.0), 0.0, 9.0, 4.0, 0.0, false)
		EnvProps.stairs(env, Vector3(cx, PLAT_H, -12.0), 180.0, 9.0, 4.0, 0.0, _m["paving"], _m["stone"])
		EnvProps.stairs(env, Vector3(cx, PLAT_H, 12.0), 0.0, 9.0, 4.0, 0.0, _m["paving"], _m["stone"])
		# inner parapets (half cover): carved stone with red lacquer balustrade on top
		var ex := sx * 12.25
		for zc: float in [-8.0, 8.0]:
			env.add(EnvKit.box(Vector3(0.5, 0.7, 4.0)), _m["stone"], Transform3D(Basis(), Vector3(ex, PLAT_H + 0.35, zc)))
			EnvProps.balustrade(env, Vector3(ex, PLAT_H + 0.6, zc - 2.0), Vector3(ex, PLAT_H + 0.6, zc + 2.0), 0.5, _m["lacquer"], _m["lacquer_dark"], 1.0)
			kit.col_box(Vector3(ex, PLAT_H + 0.55, zc), Vector3(4.0, 1.1, 0.5), 90.0, "Parapet")
		# outer edge balustrade (keeps knockbacks on the terrace)
		var ox := sx * 21.75
		env.add(EnvKit.box(Vector3(0.6, 0.5, 20.0)), _m["stone"], Transform3D(Basis(), Vector3(ox, PLAT_H + 0.25, 0.0)))
		EnvProps.balustrade(env, Vector3(ox, PLAT_H + 0.4, -10.0), Vector3(ox, PLAT_H + 0.4, 10.0), 1.0, _m["lacquer"], _m["lacquer_dark"], 2.0)
		kit.col_box(Vector3(ox, PLAT_H + 0.7, 0.0), Vector3(20.0, 1.4, 0.6), 90.0, "Parapet")
		# terrace cover: two blossom trees (trunk colliders as before) and a carved stele
		_blossom_tree(Vector3(sx * 18.5, PLAT_H, -5.0), 7.5, 40 + int(sx * 3.0), true)
		_blossom_tree(Vector3(sx * 17.5, PLAT_H, 6.0), 6.8, 50 + int(sx * 3.0), true)
		_stele(Vector3(sx * 15.0, PLAT_H, 0.0), sx)
		add_lantern(Vector3(sx * 13.0, PLAT_H, -3.0), _m["stone"], Color("#FFB070"), false)
		add_lantern(Vector3(sx * 13.0, PLAT_H, 3.0), _m["stone"], Color("#FFB070"), sx > 0)


## Carved stone stele (碑) on a turtle-ish plinth, matching the old pillar collision (1.5 x 2.4 x 1.5).
func _stele(p: Vector3, sx: float) -> void:
	env.add(EnvKit.box(Vector3(1.5, 0.5, 1.5)), _m["stone"], Transform3D(Basis(), p + Vector3(0, 0.25, 0)))
	env.add(EnvKit.box(Vector3(0.5, 1.9, 1.2)), _m["stone"], Transform3D(Basis(), p + Vector3(0, 1.45, 0)))
	env.add(EnvKit.box(Vector3(0.12, 1.3, 0.8)), _m["gold"], Transform3D(Basis(), p + Vector3(-sx * 0.26, 1.45, 0)), false)
	EnvProps.curved_roof(env, p + Vector3(0, 2.4, 0), 1.0, 1.6, 0.45, _m["tiles"], _m["gold"])
	kit.col_box(p + Vector3(0, 1.2, 0), Vector3(1.5, 2.4, 1.5), 0.0, "Pillar")


func _bridge() -> void:
	# deck (lacquered wood planks on a stone arch) + rails, posts down to the valley floor
	env.add(EnvKit.box(Vector3(24.0, 0.45, 4.0)), _m["wood"], Transform3D(Basis(), Vector3(0, PLAT_H - 0.25, 0)))
	env.add(EnvKit.box(Vector3(24.2, 0.12, 4.3)), _m["lacquer_dark"], Transform3D(Basis(), Vector3(0, PLAT_H - 0.5, 0)), false)
	kit.col_box(Vector3(0, PLAT_H - 0.25, 0), Vector3(24.0, 0.5, 4.0), 0.0, "Bridge")
	for sz: float in [-1.0, 1.0]:
		EnvProps.balustrade(env, Vector3(-12.0, PLAT_H, sz * 2.1), Vector3(12.0, PLAT_H, sz * 2.1), 1.0, _m["lacquer"], _m["lacquer_dark"], 1.5)
		env.add(EnvKit.box(Vector3(24.0, 0.25, 0.3)), _m["lacquer"], Transform3D(Basis(), Vector3(0, PLAT_H + 0.1, sz * 2.1)), false)
		kit.col_box(Vector3(0, PLAT_H + 0.55, sz * 2.1), Vector3(24.0, 1.1, 0.4), 0.0, "Rail")
		for x: float in [-9.0, -3.0, 3.0, 9.0]:
			var post_h := PLAT_H - 0.3
			env.add(EnvKit.box(Vector3(0.5, post_h, 0.5)), _m["lacquer"], Transform3D(Basis(), Vector3(x, post_h * 0.5, sz * 1.7)))
			env.add(EnvKit.box(Vector3(0.8, 0.5, 0.8)), _m["stone"], Transform3D(Basis(), Vector3(x, 0.25, sz * 1.7)))
			kit.col_box(Vector3(x, post_h * 0.5, sz * 1.7), Vector3(0.5, post_h, 0.5), 0.0, "Post")
		# cross bracing under the deck
		for x: float in [-6.0, 0.0, 6.0]:
			env.add(EnvKit.box(Vector3(6.4, 0.25, 0.25)), _m["lacquer_dark"], Transform3D(Basis(Vector3.FORWARD, 0.55), Vector3(x, PLAT_H - 2.2, sz * 1.7)), false)
	# roofed bridge pavilion (廊桥) over the middle third: columns on the rail line, curved roof, lanterns
	for x: float in [-4.0, 4.0]:
		for sz: float in [-1.0, 1.0]:
			env.add(EnvKit.cyl(0.17, 0.19, 3.3, 8), _m["lacquer"], Transform3D(Basis(), Vector3(x, PLAT_H + 1.65, sz * 2.1)))
			kit.col_cyl(Vector3(x, PLAT_H, sz * 2.1), 0.2, 3.3)
			EnvProps.paper_lantern(env, Vector3(x * 0.5, PLAT_H + 2.6, sz * 1.7), _m["paper"], _m["gold"])
	env.add(EnvKit.box(Vector3(9.0, 0.35, 4.8)), _m["lacquer_dark"], Transform3D(Basis(), Vector3(0, PLAT_H + 3.4, 0)))
	EnvProps.curved_roof(env, Vector3(0, PLAT_H + 3.55, 0), 11.5, 6.4, 2.1, _m["tiles"], _m["gold"])
	add_omni(Vector3(0, PLAT_H + 2.4, 0), Color("#FFB070"), 1.3, 7.0)


func _valley_cover() -> void:
	for p: Vector3 in [Vector3(-6.5, 0, -8.5), Vector3(6.5, 0, 8.5), Vector3(7.0, 0, -9.0), Vector3(-7.0, 0, 9.0)]:
		_boulder(p, Vector3(2.0, 1.8, 2.0), int(p.x * 13.0 + p.z))
		_boulder(p + Vector3(signf(p.x) * 1.6, 0.0, 0.8), Vector3(1.0, 1.0, 1.0), int(p.z * 9.0) + 3)
	for p: Vector3 in [Vector3(0, 0, -11.0), Vector3(0, 0, 11.0)]:
		_blossom_tree(p + Vector3(2.5, 0, 0), 7.0, 60 + int(p.z), true)
		_boulder(p + Vector3(-2.2, 0, 0), Vector3(1.5, 1.2, 1.5), int(p.z) + 77)
	for p: Vector3 in [Vector3(-9.0, 0, -17.0), Vector3(9.0, 0, 17.0), Vector3(9.5, 0, -16.0), Vector3(-9.5, 0, 16.0)]:
		_blossom_tree(p, 7.2, 70 + int(p.x + p.z), true)


## Painted boulder with convex collision matching the mesh (half-size `s` = radii).
func _boulder(p: Vector3, s: Vector3, seed_i: int) -> void:
	var m := EnvKit.rock_mesh(1.0, 0.38, 400 + seed_i)
	var t := Transform3D(Basis(Vector3.UP, float(seed_i) * 0.7).scaled(s), p)
	env.add(m, _m["hill"], t)
	var cs := env.col_hull(m, t, "Hull")
	cs.name = "Hull%d" % kit.shape_count
	kit.shape_count += 1


func _blossom_tree(p: Vector3, h: float, seed_i: int, solid: bool) -> void:
	env.litter(p, h * 0.45, 26, _m["petals"], Callable(), 0.9)
	EnvProps.broadleaf(env, p, h, {"bark": _m["bark"], "core": _m["blossom_core"], "cards": _m["blossom"]}, 500 + seed_i, 5, 2.0, 5, 0.65, float(seed_i) * 0.9)
	if solid:
		kit.col_cyl(p, 0.35 * h / 6.0, 3.0 * h / 6.0)


func _landmarks() -> void:
	# primary: seven-tier pagoda on the north ridge
	var pg := Vector3(0, _height(0, -52.0) - 1.0, -52.0)
	EnvProps.pagoda(env, pg, 7, 7.0, 3.0, _m)
	add_omni(pg + Vector3(0, 6.0, 8.0), Color("#FFB070"), 2.0, 16.0)
	# ancient giant blossom tree on the south ridge
	var gt := Vector3(4.0, _height(4.0, 48.0) - 0.5, 48.0)
	EnvProps.broadleaf(env, gt, 26.0, {"bark": _m["bark"], "core": _m["blossom_core"], "cards": _m["blossom"]}, 991, 7, 4.2, 5, 0.75, 0.4, 0.9)
	# paifang gates behind each spawn
	for sz: float in [-1.0, 1.0]:
		var at := Vector3(0, 0, sz * 24.8)
		EnvProps.paifang(env, at, 0.0 if sz < 0 else PI, 8.0, 6.5, _m)
		for sx: float in [-0.5, 0.5]:
			kit.col_cyl(at + Vector3(sx * 8.0, 0, 0), 0.4, 6.5)
		EnvProps.banner(env, at + Vector3(-6.0, 0, 0), "banner_blue.png" if sz < 0 else "banner_red.png", Color.WHITE, 6.0, _m["lacquer_dark"], _m["gold"])
		EnvProps.banner(env, at + Vector3(6.0, 0, 0), "banner_blue.png" if sz < 0 else "banner_red.png", Color.WHITE, 6.0, _m["lacquer_dark"], _m["gold"])
	# hillside pavilions on the east / west valley walls (silhouettes framing the terraces)
	for sx: float in [-1.0, 1.0]:
		var hp := Vector3(sx * 40.0, 0, -14.0 * sx)
		hp.y = _height(hp.x, hp.z) - 0.3
		EnvProps.pavilion(env, hp, 2.6, 3.2, 6, _m)


func _vegetation() -> void:
	# background blossom / green trees on the valley walls
	var r := env.rng
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 600:
		tries += 1
		var x := r.randf_range(-70, 70)
		var z := r.randf_range(-70, 70)
		var d := maxf(absf(x), absf(z))
		if d < HALF + 4.0 or d > 62.0:
			continue
		if Vector2(x, z + 52.0).length() < 12.0 or Vector2(x - 4.0, z - 48.0).length() < 14.0:
			continue
		var y := _height(x, z)
		if placed % 3 == 0:
			EnvProps.broadleaf(env, Vector3(x, y - 0.3, z), r.randf_range(8.0, 12.0), {"bark": _m["bark"], "core": _m["green_core"], "cards": _m["green"]}, 2000 + placed, 4, 2.6, 4, 0.7)
		else:
			EnvProps.broadleaf(env, Vector3(x, y - 0.3, z), r.randf_range(7.0, 11.0), {"bark": _m["bark"], "core": _m["blossom_core"], "cards": _m["blossom"]}, 2000 + placed, 4, 2.6, 4, 0.7)
		placed += 1
	# cypress groves (MultiMesh) further out
	var cyp := EnvKit.cypress_mesh()
	var cmat := EnvKit.paint(Color("#3E6A5A"), Color("#24443E"), {"snow_amount": 0.0, "noise_scale": 1.0, "shade_tint": Color("#2A3A6A"), "warm_amount": 0.4, "warm_col": Color("#C8D080")})
	placed = 0
	while placed < 220:
		var x := r.randf_range(-130, 130)
		var z := r.randf_range(-130, 130)
		var d := maxf(absf(x), absf(z))
		if d < HALF + 9.0 or Vector2(x, z + 52.0).length() < 14.0:
			continue
		var s := r.randf_range(1.0, 1.8)
		env.inst(cyp, cmat, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.4), s)), Vector3(x, _height(x, z) - 0.3, z)), d < 60.0)
		placed += 1
	# grass tufts and flower drifts on the valley floor and the terrace tops (one MultiMesh each)
	var tuft := EnvKit.tuft_mesh(0.42, 0.06)
	var gmat := EnvKit.grass_mat(Color("#2E5A3E"), Color("#9ACD6A"), Color("#5A7AA8"), 0.1)
	var flower := EnvKit.tuft_mesh(0.3, 0.09)
	var fmat := EnvKit.grass_mat(Color("#3E6A3E"), Color("#FFFFFF"), Color("#7A7AB0"), 0.08, true)
	var fcols: Array[Color] = [Color("#FF9AC0"), Color("#FFF4F0"), Color("#FFD24A"), Color("#C890FF"), Color("#FF6A6A")]
	for i in 1400:
		var x := r.randf_range(-HALF, HALF)
		var z := r.randf_range(-HALF, HALF)
		var on_plat := absf(x) > 12.4 and absf(x) < 21.6 and absf(z) < 11.6
		if absf(x) < 2.2 or (absf(z) < 2.6 and absf(x) < 3.0) or (absf(absf(z) - 18.0) < 1.6 and absf(x) < 17.0):
			continue
		if not on_plat and absf(x) > 11.5 and absf(z) < 12.5:
			continue
		var y := PLAT_H if on_plat else 0.0
		var s := r.randf_range(0.7, 1.3)
		if i % 4 == 0:
			env.inst(flower, fmat, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z)), false, fcols[(i / 4 + int(absf(x))) % fcols.size()])
		else:
			env.inst(tuft, gmat, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z)), false)
