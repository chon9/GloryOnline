extends ArenaMap
## 百花谷 Hundred Blossoms Valley - 50 m team map. A flowered valley floor between two raised stone
## plateaus (4.5 m high ground for ranged classes) reached by stair ramps at both ends, joined by a wooden
## bridge over the middle of the valley. Rocks and trees break line of sight in the valley.

const HALF: float = 25.0
## 4.5 m: above World.ground_y()'s +4 m probe so ground_point() under the bridge stays on the valley floor.
const PLAT_H: float = 4.5


func _init() -> void:
	map_id = "hundred_blossoms"
	name_cn = "百花谷"
	name_en = "Hundred Blossoms Valley"
	size = Vector2(50.0, 50.0)
	center = Vector3.ZERO


func _build_map() -> void:
	setup_environment({
		"sky_top": Color(0.3, 0.52, 0.85), "sky_horizon": Color(0.8, 0.84, 0.9),
		"ground": Color(0.3, 0.4, 0.25), "fog_color": Color(0.82, 0.86, 0.92), "fog_density": 0.0035,
		"sun_pitch": -42.0, "sun_yaw": 25.0, "sun_energy": 1.25, "ambient_energy": 0.75,
	})
	var D := MapKit.D
	var N := MapKit.N
	# ---- valley floor: grass + dirt paths
	var grass := MapKit.mat(Color(0.42, 0.6, 0.28), 1.0)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.05
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.9, 0.7))
	ramp.set_color(1, Color(1.0, 1.0, 0.85))
	ntex.color_ramp = ramp
	grass.albedo_texture = ntex
	grass.uv1_triplanar = true
	grass.uv1_scale = Vector3(0.05, 0.05, 0.05)
	kit.box_visual(Vector3(0, -0.5, 0), Vector3(180, 1.0, 180), grass, 0.0, false)
	kit.col_box(Vector3(0, -1.5, 0), Vector3(180, 3.0, 180), 0.0, "Ground")
	# dirt lanes: center lane + side branches to the ramps
	for z in range(-24, 25, 4):
		kit.piece(D + "floor_tile_large.gltf", Vector3(0, -0.04, z), 90.0 * (absi(z) % 3), Vector3.ONE, false)
	for sz: float in [-1.0, 1.0]:
		for x in range(-16, 17, 4):
			if absi(x) < 3:
				continue
			kit.piece(D + "floor_tile_small.gltf", Vector3(x, -0.04, sz * 18.0), 90.0 * (absi(x) % 3), Vector3.ONE, false)
	# ---- plateaus (west / east), ramps at both ends
	for sx: float in [-1.0, 1.0]:
		var x0 := -22.0 if sx < 0 else 12.0
		kit.platform(Rect2(x0, -12.0, 10.0, 24.0), PLAT_H)
		var cx := sx * 17.0
		kit.ramp(Vector3(cx, PLAT_H, -12.0), 180.0, 9.0, 4.0)
		kit.ramp(Vector3(cx, PLAT_H, 12.0), 0.0, 9.0, 4.0)
		# parapets (half cover) on the inner edge, leaving the bridge mouth and drop-down gaps open
		var ex := sx * 12.25
		for zc: float in [-8.0, 8.0]:
			kit.piece(D + "barrier.gltf", Vector3(ex, PLAT_H, zc), 90.0)
			kit.col_box(Vector3(ex, PLAT_H + 0.55, zc), Vector3(4.0, 1.1, 0.5), 90.0, "Parapet")
		# outer edge parapet (so knockbacks do not throw people off the back into the boundary)
		var ox := sx * 21.75
		for zc: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			kit.piece(D + "barrier_column.gltf", Vector3(ox, PLAT_H, zc), 90.0)
		kit.col_box(Vector3(ox, PLAT_H + 0.7, 0.0), Vector3(20.0, 1.4, 0.6), 90.0, "Parapet")
		# plateau cover: a tree and a ruined pillar
		kit.tree("Tree_5_A_Color1.gltf", Vector3(sx * 18.5, PLAT_H, -5.0), 40.0 * sx, 1.3)
		kit.tree("Tree_1_B_Color1.gltf", Vector3(sx * 17.5, PLAT_H, 6.0), -70.0 * sx, 1.15)
		kit.piece(D + "pillar.gltf", Vector3(sx * 15.0, PLAT_H, 0.0), 0.0, Vector3(1.0, 0.6, 1.0))
		kit.col_box(Vector3(sx * 15.0, PLAT_H + 1.2, 0.0), Vector3(1.5, 2.4, 1.5), 0.0, "Pillar")
		add_torch(Vector3(sx * 13.0, PLAT_H, -3.0), false)
		add_torch(Vector3(sx * 13.0, PLAT_H, 3.0), sx > 0)
	# ---- wooden bridge across the valley at z = 0
	var deck_mat := MapKit.mat(Color(0.36, 0.25, 0.16), 0.95)
	for x in range(-10, 11, 4):
		kit.piece(D + "floor_wood_large.gltf", Vector3(x, PLAT_H - 0.05, 0.0), 0.0, Vector3.ONE, false)
	kit.box_visual(Vector3(0, PLAT_H - 0.3, 0), Vector3(24.0, 0.4, 4.0), deck_mat)
	kit.col_box(Vector3(0, PLAT_H - 0.25, 0), Vector3(24.0, 0.5, 4.0), 0.0, "Bridge")
	for sz: float in [-1.0, 1.0]:
		for x in range(-10, 11, 4):
			kit.piece(D + "barrier_half.gltf", Vector3(x - 2.0, PLAT_H, sz * 2.1), 0.0)
			kit.piece(D + "barrier_half.gltf", Vector3(x, PLAT_H, sz * 2.1), 0.0)
		kit.col_box(Vector3(0, PLAT_H + 0.55, sz * 2.1), Vector3(24.0, 1.1, 0.4), 0.0, "Rail")
		for x: float in [-9.0, -3.0, 3.0, 9.0]:
			var post_h := PLAT_H - 0.3
			kit.piece(D + "post.gltf", Vector3(x, 0, sz * 1.7), 0.0, Vector3(1.2, 0.68 * post_h / 2.7, 1.2))
			kit.col_box(Vector3(x, post_h * 0.5, sz * 1.7), Vector3(0.5, post_h, 0.5), 0.0, "Post")
	# ---- valley cover: rock clusters and trees
	for p: Vector3 in [Vector3(-6.5, 0, -8.5), Vector3(6.5, 0, 8.5), Vector3(7.0, 0, -9.0), Vector3(-7.0, 0, 9.0)]:
		kit.rock("Rock_1_A_Color1.gltf", p, p.x * 13.0, Vector3(4.0, 3.6, 4.0))
		kit.rock("Rock_3_B_Color1.gltf", p + Vector3(signf(p.x) * 1.6, 0.4, 0.8), p.z * 9.0, Vector3(2.0, 2.0, 2.0))
	for p: Vector3 in [Vector3(0, 0, -11.0), Vector3(0, 0, 11.0)]:
		kit.tree("Tree_2_A_Color1.gltf", p + Vector3(2.5, 0, 0), p.z * 7.0, 1.2)
		kit.rock("Rock_1_C_Color1.gltf", p + Vector3(-2.2, 0, 0), p.z * 5.0, Vector3(3.0, 2.4, 3.0))
	for p: Vector3 in [Vector3(-9.0, 0, -17.0), Vector3(9.0, 0, 17.0), Vector3(9.5, 0, -16.0), Vector3(-9.5, 0, 16.0)]:
		kit.tree("Tree_1_A_Color1.gltf", p, p.x * 10.0, 1.25)
	# ---- blossoms: flower patches (visual only) and bushes
	_flowers()
	for i in 40:
		var p := Vector3(kit.rng.randf_range(-11.0, 11.0), 0, kit.rng.randf_range(-23.0, 23.0))
		if absf(p.x) < 2.6 or (absf(p.z) < 3.0):
			continue
		var b: String = ["Bush_1_A_Color1.gltf", "Bush_2_B_Color1.gltf", "Bush_3_A_Color1.gltf"][i % 3]
		var bs: float = [3.0, 0.9, 1.3][i % 3]
		kit.piece(N + b, p, kit.rng.randf() * 360.0, Vector3.ONE * bs * kit.rng.randf_range(0.8, 1.15), false)
	# ---- boundary: invisible outer wall + cliffs and forest outside
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	for i in 28:
		var side := i % 4
		var t := float(i / 4) / 6.0 * 2.0 - 1.0
		var along := t * (HALF + 2.0)
		var out := HALF + 4.5 + kit.rng.randf() * 2.0
		var p: Vector3
		match side:
			0: p = Vector3(along, 0, -out)
			1: p = Vector3(along, 0, out)
			2: p = Vector3(-out, 0, along)
			_: p = Vector3(out, 0, along)
		var hs := kit.rng.randf_range(0.9, 1.4)
		kit.piece(N + ("Hill_8x8x8_Color1.gltf" if i % 3 != 0 else "Hill_8x8x4_Color1.gltf"), p, 90.0 * (i % 4), Vector3(hs, kit.rng.randf_range(0.7, 1.3), hs))
	for i in 36:
		var a := TAU * i / 36.0
		var r := HALF * 1.45 + kit.rng.randf() * 8.0
		var tp: String = ["Tree_1_A_Color1.gltf", "Tree_2_B_Color1.gltf", "Tree_5_B_Color1.gltf", "Tree_3_A_Color1.gltf"][i % 4]
		kit.piece(N + tp, Vector3(cos(a) * r, 0, sin(a) * r), kit.rng.randf() * 360.0, Vector3.ONE * kit.rng.randf_range(1.8, 2.8))
	test_walks = [
		{"name": "west ramp up", "from": Vector3(-17, 0, -23), "to": Vector3(-17, PLAT_H, -6), "min_y": PLAT_H - 0.3},
		{"name": "east ramp up (south)", "from": Vector3(17, 0, 23), "to": Vector3(17, PLAT_H, 6), "min_y": PLAT_H - 0.3},
		{"name": "bridge crossing", "from": Vector3(-13, PLAT_H, 0), "to": Vector3(13, PLAT_H, 0), "min_y": PLAT_H - 0.3},
		{"name": "under the bridge", "from": Vector3(0, 0, -7), "to": Vector3(0, 0, 7), "min_y": -1.0},
	]
	# ---- spawns
	set_spawns_line(0, Vector3(0, 0, -21.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 21.0), Vector3.RIGHT, 2.2)


## Hundreds of small colored blossoms in clumps on the valley floor (single MultiMesh, no collision).
func _flowers() -> void:
	var colors: Array[Color] = [Color(1.0, 0.55, 0.75), Color(1.0, 0.95, 0.95), Color(1.0, 0.85, 0.3), Color(0.85, 0.5, 1.0),
		Color(1.0, 0.4, 0.4)]
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	for clump in 70:
		var c := Vector3(kit.rng.randf_range(-11.5, 11.5), 0, kit.rng.randf_range(-24.0, 24.0))
		if absf(c.x) < 2.4:
			c.x += 3.0 * signf(c.x + 0.01)
		var col: Color = colors[clump % colors.size()]
		for k in 14:
			var p := c + Vector3(kit.rng.randf_range(-1.1, 1.1), 0.1, kit.rng.randf_range(-1.1, 1.1))
			xs.append(Transform3D(Basis().scaled(Vector3.ONE * kit.rng.randf_range(0.7, 1.3)), p))
			cs.append(col)
	# plateau tops too
	for clump in 16:
		var sx := -1.0 if clump % 2 == 0 else 1.0
		var c := Vector3(sx * kit.rng.randf_range(13.5, 20.5), PLAT_H, kit.rng.randf_range(-10.0, 10.0))
		for k in 6:
			xs.append(Transform3D(Basis(), c + Vector3(kit.rng.randf_range(-0.8, 0.8), 0.1, kit.rng.randf_range(-0.8, 0.8))))
			cs.append(colors[(clump + k) % colors.size()])
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = Color(0.25, 0.15, 0.2)
	sm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Blossoms"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
