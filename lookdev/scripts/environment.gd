class_name LdEnvironment
extends RefCounted
## "Frost Forest Arena" (冰霜森林 · 竞技场) - one coherent zone from the bible (4.2 Frost Forest + Pro arena):
##   primary landmark  : a blood-red maple on a rock outcrop (readable from anywhere)
##   secondary         : broken Gothic arch ruin, team banners, ice-crystal clusters
##   composition       : raised octagonal rune arena (mid value) inside a snow bowl, cliffs + frosted forest
##                       behind (lighter through fog), dark trunks framing the foreground
##   height variation  : arena +1.2 m, steps, outcrop +4 m, ridges up to ~14 m, fallen pillars, rubble
##   atmosphere        : painted sky, depth fog + aerial perspective, volumetric light, snow + light motes
## Everything is procedural (original code, no third-party meshes), so it ships without licence questions.

const ARENA_Y := 1.2
const ARENA_R := 9.0
const PAINT := preload("res://lookdev/shaders/painted_env.gdshader")
const FLOOR := preload("res://lookdev/shaders/arena_floor.gdshader")
const SKY := preload("res://lookdev/shaders/anime_sky.gdshader")

static var noise: FastNoiseLite
static var rng := RandomNumberGenerator.new()


static func build(root: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = "Environment"
	root.add_child(n)
	rng.seed = 7
	noise = FastNoiseLite.new()
	noise.seed = 3
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	_atmosphere(n)
	_terrain(n)
	_arena(n)
	_maple(n, Vector3(13.5, 0.0, -15.0))
	_ruin_arch(n, Vector3(-6.0, 0.0, -19.0))
	_forest(n)
	_ice_clusters(n)
	_rocks(n)
	_banners(n)
	_mountains(n)
	_backdrop(n)
	_particles(n)
	return n


static func mat(base: Color, base2: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("base_col2", base2)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


# ------------------------------------------------------------------ lighting & atmosphere

static func _atmosphere(n: Node3D) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.6
	e.ambient_light_color = Color("#8FC3DD")
	e.ambient_light_energy = 0.3
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.82
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		e.set_glow_level(i, 1.0 if i in [2, 3, 4, 5] else 0.0)
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color("#9CCBE8")
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.08
	e.fog_density = 0.0028
	e.fog_aerial_perspective = 0.35
	e.fog_sky_affect = 0.15
	e.fog_height = 4.0
	e.fog_height_density = 0.006
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.0012
	e.volumetric_fog_albedo = Color("#E6F4FF")
	e.volumetric_fog_emission = Color("#5FA8C8") * 0.02
	e.volumetric_fog_anisotropy = 0.3
	e.volumetric_fog_length = 80.0
	e.volumetric_fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.22
	e.adjustment_contrast = 1.1
	e.adjustment_brightness = 1.0
	we.environment = e
	n.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#FFF1DC")
	sun.light_energy = 1.45
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 0.6
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	n.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.72, -0.48, 0.5), Vector3.UP)
	# cool bounce from the snow (no shadows) so shadow sides stay cyan, not dead
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9FD6FF")
	fill.light_energy = 0.25
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	n.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.45, -0.35, -0.8), Vector3.UP)


# ------------------------------------------------------------------ terrain

static func height(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var h := noise.get_noise_2d(x, z) * 1.1
	# snow bowl around the arena: flat inside, rising ridges behind and to the right
	var ridge := 0.0
	var back := clampf((-z - 13.0) / 22.0, 0.0, 1.0)
	var right := clampf((x - 15.0) / 22.0, 0.0, 1.0)
	var left := clampf((-x - 17.0) / 25.0, 0.0, 1.0) * clampf((-z + 6.0) / 20.0, 0.0, 1.0)
	ridge = maxf(maxf(back * back * 16.0, right * right * 13.0), left * 7.0)
	ridge += (noise.get_noise_2d(x * 2.5 + 40.0, z * 2.5) * 0.5 + 0.5) * ridge * 0.35
	h += ridge
	# keep the arena surroundings flat-ish, gentle drop toward the camera side
	var flat := smoothstep(11.0, 16.0, d)
	h = lerpf(-0.05 + noise.get_noise_2d(x * 3.0, z * 3.0) * 0.08, h, flat)
	h -= clampf((z - 16.0) / 20.0, 0.0, 1.0) * 1.5
	return h


static func _terrain(n: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := 150.0
	var res := 150
	var step := size / res
	var o := -size * 0.5
	var hs: PackedFloat32Array = PackedFloat32Array()
	hs.resize((res + 1) * (res + 1))
	for j in res + 1:
		for i in res + 1:
			hs[j * (res + 1) + i] = height(o + i * step, o + j * step - 15.0)
	for j in res:
		for i in res:
			var p := []
			for c: Array in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var x: float = o + (i + int(c[0])) * step
				var z: float = o + (j + int(c[1])) * step - 15.0
				p.append(Vector3(x, hs[(j + c[1]) * (res + 1) + i + c[0]], z))
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_uv(Vector2(p[k].x, p[k].z) * 0.1)
				st.add_vertex(p[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(Color("#7A86A8"), Color("#4E5878"), {"snow_amount": 0.72, "strata": 1.0, "noise_scale": 0.22, "snow_sharp": 0.05})
	n.add_child(mi)


# ------------------------------------------------------------------ arena

static func _arena(n: Node3D) -> void:
	var a := Node3D.new()
	a.name = "Arena"
	n.add_child(a)
	# octagonal plinth: stone sides with a darker band, top gets the rune floor shader
	var side_mat := mat(Color("#5A6584"), Color("#3E4662"), {"snow_amount": 0.1, "noise_scale": 0.9, "paint_strength": 0.35, "blocks": 0.42})
	var plinth := LdGear.lathe([Vector2(ARENA_R + 0.9, -1.0), Vector2(ARENA_R + 0.7, 0.0), Vector2(ARENA_R + 0.2, ARENA_Y - 0.25), Vector2(ARENA_R + 0.35, ARENA_Y - 0.15), Vector2(ARENA_R + 0.35, ARENA_Y)], 8)
	var pm := LdGear.mi(plinth, side_mat, a)
	pm.rotation.y = PI / 8.0
	# glowing rune lip around the plinth (reads as "pro-league stage" at any distance)
	var lip := LdGear.mi(LdGear.lathe([Vector2(ARENA_R + 0.37, ARENA_Y - 0.36), Vector2(ARENA_R + 0.37, ARENA_Y - 0.31)], 8), LdGear.glow(Color("#4FD8FF"), 2.2), a)
	lip.rotation.y = PI / 8.0
	var drift_mat := mat(Color("#B9C6DA"), Color("#95A6C2"), {"snow_amount": 0.8, "noise_scale": 0.6})
	var drift := LdGear.mi(LdGear.lathe([Vector2(ARENA_R + 3.2, -0.3), Vector2(ARENA_R + 1.6, 0.25), Vector2(ARENA_R + 0.75, 0.45), Vector2(ARENA_R + 0.6, 0.3)], 8), drift_mat, a)
	drift.rotation.y = PI / 8.0
	var base_rock := mat(Color("#646A86"), Color("#3A3F5C"), {"snow_amount": 0.35, "strata": 1.0, "noise_scale": 0.7, "warm_amount": 0.55, "warm_col": Color("#C89A6A")})
	for k in 14:
		var ra := TAU * k / 14.0 + 0.2
		if absf(wrapf(ra - PI * 0.5, -PI, PI)) < 0.45 or absf(wrapf(ra - PI, -PI, PI)) < 0.45:
			continue
		var rp := Vector3(cos(ra), 0, sin(ra)) * (ARENA_R + 1.3)
		LdGear.mi(_rock_mesh(rng.randf_range(0.45, 1.0), 0.45, 900 + k), base_rock, a, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), rp + Vector3(0, 0.1, 0)))
	var top := CylinderMesh.new()
	top.top_radius = ARENA_R + 0.35
	top.bottom_radius = ARENA_R + 0.35
	top.height = 0.05
	top.radial_segments = 8
	top.rings = 1
	var fm := ShaderMaterial.new()
	fm.shader = FLOOR
	fm.set_shader_parameter("radius", ARENA_R)
	var floor_mi := LdGear.mi(top, fm, a, Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3(0, ARENA_Y - 0.025, 0)))
	floor_mi.name = "ArenaFloor"
	# raised kerb ring around the fighting floor
	var kerb_mat := mat(Color("#8B93AE"), Color("#6A7290"), {"snow_amount": 0.4, "noise_scale": 1.2})
	var kerb := LdGear.mi(LdGear.lathe([Vector2(ARENA_R + 0.36, ARENA_Y - 0.02), Vector2(ARENA_R + 0.36, ARENA_Y + 0.22), Vector2(ARENA_R - 0.05, ARENA_Y + 0.22), Vector2(ARENA_R - 0.1, ARENA_Y - 0.02)], 8), kerb_mat, a)
	kerb.rotation.y = PI / 8.0
	# steps on the camera side and the left
	var step_mat := mat(Color("#7C84A0"), Color("#5A6280"), {"snow_amount": 0.55, "noise_scale": 1.0})
	for ang: float in [PI * 0.5, PI]:
		for s in 4:
			var w := 4.2 - s * 0.2
			var dist := (ARENA_R + 0.35) * cos(PI / 8.0) + 1.2 - s * 0.4
			var stp := LdGear.mi(LdGear.box(Vector3(w, ARENA_Y * (s + 1) / 4.0, 0.42)), step_mat, a)
			stp.transform = Transform3D(Basis(Vector3.UP, -ang + PI * 0.5), Vector3(cos(ang), 0, sin(ang)) * dist + Vector3(0, ARENA_Y * (s + 1) / 8.0, 0))
		# step-side lantern posts with cyan rune light
		for sd: float in [-1.0, 1.0]:
			var side := Vector3(-sin(ang), 0, cos(ang)) * sd * 2.5
			var base := Vector3(cos(ang), 0, sin(ang)) * ((ARENA_R + 0.35) * cos(PI / 8.0) + 0.6) + side
			_lantern(a, base)
	# broken pillars on the octagon corners (varying heights, one fallen)
	var col_mat := mat(Color("#A49AA6"), Color("#655C78"), {"snow_amount": 0.3, "noise_scale": 0.8, "paint_strength": 0.4, "warm_amount": 0.75, "warm_col": Color("#E0B48C"), "blocks": 0.55})
	var heights := [4.6, 1.4, 3.2, 0.0, 5.4, 2.2, 0.9, 3.8]
	for k in 8:
		var ang := TAU * k / 8.0 + PI / 8.0
		var pos := Vector3(cos(ang), 0, sin(ang)) * (ARENA_R + 0.6)
		var h: float = heights[k]
		if absf(wrapf(ang - PI * 0.5, -PI, PI)) < 0.5 or absf(wrapf(ang - PI, -PI, PI)) < 0.5:
			h = minf(h, 1.4)   # keep the step entrances open
		if h <= 0.01:
			# fallen drum segments
			var outv := Vector3(cos(ang), 0, sin(ang))
			for s in 3:
				var drum := LdGear.mi(LdGear.lathe([Vector2(0.48, -0.55), Vector2(0.5, 0.0), Vector2(0.48, 0.55)], 10), col_mat, a)
				var dp := pos + outv * (1.6 + s * 0.9) + Vector3(-outv.z, 0, outv.x) * (s - 1) * 1.1
				drum.transform = Transform3D(Basis(Vector3.UP, ang + s * 0.7) * Basis(Vector3.FORWARD, PI * 0.5), dp + Vector3(0, height(dp.x, dp.z) + 0.42, 0))
			continue
		_column(a, pos + Vector3(0, ARENA_Y, 0), h, col_mat)


static func _column(parent: Node3D, base: Vector3, h: float, m: Material) -> void:
	var c := Node3D.new()
	c.position = base
	parent.add_child(c)
	LdGear.mi(LdGear.lathe([Vector2(0.78, 0.0), Vector2(0.78, 0.35), Vector2(0.62, 0.45), Vector2(0.55, 0.6)], 8), m, c)
	LdGear.mi(LdGear.lathe([Vector2(0.52, 0.55), Vector2(0.47, h - 0.2), Vector2(0.5, h)], 16), m, c)
	if h > 4.0:
		LdGear.mi(LdGear.lathe([Vector2(0.5, h), Vector2(0.72, h + 0.35), Vector2(0.75, h + 0.55)], 8), m, c)
	else:
		# jagged broken top
		var chunk := _rock_mesh(0.62, 0.35, rng.randi())
		LdGear.mi(chunk, m, c, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)), Vector3(0.05, h, 0.0)))
	# rubble at the foot
	for i in 3:
		var r := _rock_mesh(rng.randf_range(0.18, 0.35), 0.4, rng.randi())
		var a := rng.randf() * TAU
		LdGear.mi(r, m, c, Transform3D(Basis(), Vector3(cos(a) * 1.0, 0.1, sin(a) * 1.0)))


static func _lantern(parent: Node3D, base: Vector3) -> void:
	var stone := mat(Color("#8B93AE"), Color("#6A7290"), {"snow_amount": 0.6, "noise_scale": 1.2})
	var l := Node3D.new()
	l.position = Vector3(base.x, height(base.x, base.z), base.z)
	parent.add_child(l)
	LdGear.mi(LdGear.lathe([Vector2(0.28, 0.0), Vector2(0.22, 0.15), Vector2(0.12, 0.3), Vector2(0.1, 1.2), Vector2(0.24, 1.35), Vector2(0.24, 1.42)], 6), stone, l)
	LdGear.mi(LdGear.lathe([Vector2(0.2, 1.42), Vector2(0.17, 1.75), Vector2(0.3, 1.8), Vector2(0.0, 2.15)], 6), stone, l)
	var core := LdGear.mi(LdGear.cyl(0.11, 0.11, 0.28, 6), LdGear.glow(Color("#7FE8FF"), 4.0), l)
	core.position = Vector3(0, 1.6, 0)
	var om := OmniLight3D.new()
	om.light_color = Color("#7FE8FF")
	om.light_energy = 1.4
	om.omni_range = 4.0
	om.position = Vector3(0, 1.6, 0)
	l.add_child(om)


# ------------------------------------------------------------------ landmarks

static func _maple(n: Node3D, at: Vector3) -> void:
	var t := Node3D.new()
	t.name = "RedMaple"
	n.add_child(t)
	# rock outcrop
	var rock_mat := mat(Color("#8A7E8C"), Color("#4A4260"), {"snow_amount": 0.62, "strata": 1.0, "noise_scale": 0.5, "warm_amount": 0.7, "warm_col": Color("#D8A27A")})
	var gy := height(at.x, at.z)
	for i in 6:
		var r := rng.randf_range(2.4, 4.0)
		var off := Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(0.8, 2.6), rng.randf_range(-2.0, 2.0))
		LdGear.mi(_rock_mesh(r, 0.45, i * 13 + 2), rock_mat, t, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 0.85, 1.0)), at + Vector3(0, gy, 0) + off))
	var top := at + Vector3(0, gy + 4.6, 0)
	# tree: trunk + branches, foliage puffs at the tips
	var bark := mat(Color("#3A2A30"), Color("#22181E"), {"snow_amount": 0.32, "noise_scale": 2.0, "snow_sharp": 0.03})
	var tips: Array = []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_branch(st, top, Vector3(0.12, 1, 0.05).normalized(), 4.2, 0.62, 0, 5, tips, 0.6)
	st.generate_normals()
	LdGear.mi(st.commit(), bark, t)
	# foliage: dark crimson core masses (value structure: darker at the core) + layered painted leaf cards
	var core := LdGear.toon(Color("#9E1430"), {"shade": Color(0.5, 0.2, 0.55), "rim": Color(1.0, 0.6, 0.5), "rim_strength": 0.4, "line": 1.2, "darken": 0.4})
	var puffs := [_puff_mesh(1.0, 1), _puff_mesh(1.0, 2), _puff_mesh(1.0, 3)]
	for i in tips.size():
		var p: Vector3 = tips[i]
		var s := rng.randf_range(0.6, 0.85)
		LdGear.mi(puffs[i % 3], core, t, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.75, s)), p + Vector3(0, 0.1, 0)))
	var cards := LdGear.toon(Color(0.86, 0.5, 0.5), {"tex": load("res://lookdev/assets/textures/maple_leaves.png"), "shade": Color(0.45, 0.2, 0.5), "rim": Color(1.0, 0.7, 0.5), "rim_strength": 0.3, "outline": false})
	var centre := top + Vector3(0, 4.0, 0)
	LdGear.mi(_leaf_cards(tips, centre, 6, 2.6), cards, t)
	# falling leaves
	var pp := _particles_box(Vector3(5, 3, 5), 90, 6.0, Color("#E0283A"), 0.14, Vector3(0.3, -0.5, 0.2), true)
	pp.position = top + Vector3(0, 4.5, 0)
	t.add_child(pp)


## Layered leaf cards around every branch tip: double-sided quads with normals bent out from the canopy
## centre (soft volumetric cel shading), textured with the painted maple-leaf atlas, alpha-scissored.
static func _leaf_cards(tips: Array, centre: Vector3, per_tip: int, size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in tips:
		for k in per_tip:
			var c := p + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.9), rng.randf_range(-1, 1)) * 1.15
			var out := (c - centre).normalized()
			var b := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
			var s := size * rng.randf_range(0.75, 1.25)
			var ax: Vector3 = b.x * s * 0.5
			var ay: Vector3 = b.y * s * 0.5
			var q := [c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for face in 2:
				var order := [0, 1, 2, 0, 2, 3] if face == 0 else [0, 2, 1, 0, 3, 2]
				for o: int in order:
					var v: Vector3 = q[o]
					st.set_normal(((v - centre).normalized() * 0.7 + out * 0.3).normalized())
					st.set_uv(uv[o])
					st.add_vertex(v)
	return st.commit()


## Matte-painted distant ranges behind the 3D mountains (aerial perspective without geometry).
static func _backdrop(n: Node3D) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 420.0
	cyl.bottom_radius = 420.0
	cyl.height = 200.0
	cyl.radial_segments = 96
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = preload("res://lookdev/shaders/painted_backdrop.gdshader")
	var mi := LdGear.mi(cyl, m, n, Transform3D(Basis(), Vector3(0, -40.0, 0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "PaintedBackdrop"


static func _branch(st: SurfaceTool, p: Vector3, dir: Vector3, length: float, r: float, depth: int, max_depth: int, tips: Array, spread: float) -> void:
	var seg := 4
	var pts: Array = [p]
	var d := dir
	var q := p
	for i in seg:
		d = (d + Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.05, 0.12), rng.randf_range(-0.18, 0.18))).normalized()
		q += d * length / seg
		pts.append(q)
	var radii: Array = []
	for i in pts.size():
		radii.append(lerpf(r, r * 0.62, float(i) / seg))
	_tube_into(st, pts, radii, 6)
	if depth >= max_depth:
		tips.append(q)
		return
	var kids := 2 if depth < 1 else (3 if rng.randf() < 0.5 else 2)
	for k in kids:
		var a := TAU * k / kids + rng.randf() * 1.2
		var side := Vector3(cos(a), 0, sin(a))
		var nd := (d + side * spread * rng.randf_range(0.8, 1.3) + Vector3(0, 0.25, 0)).normalized()
		_branch(st, q, nd, length * rng.randf_range(0.62, 0.78), r * 0.62, depth + 1, max_depth, tips, spread)


static func _tube_into(st: SurfaceTool, pts: Array, radii: Array, sides: int) -> void:
	var rings: Array = []
	var up := Vector3.UP
	for i in pts.size():
		var t: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if absf(t.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var bx := t.cross(up).normalized()
		var by := bx.cross(t).normalized()
		var ring: Array = []
		for j in sides:
			var a := TAU * j / sides
			ring.append((pts[i] as Vector3) + (bx * cos(a) + by * sin(a)) * float(radii[i]))
		rings.append(ring)
	for i in pts.size() - 1:
		for j in sides:
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][(j + 1) % sides]
			var c: Vector3 = rings[i + 1][(j + 1) % sides]
			var d: Vector3 = rings[i + 1][j]
			for v in [a, c, b, a, d, c]:
				st.add_vertex(v)


static func _puff_mesh(r: float, seed_i: int) -> ArrayMesh:
	# lumpy foliage clump: sphere displaced by noise, flattened bottom (reads as a painted leaf mass)
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 18
	sm.rings = 10
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_i
	nz.frequency = 1.4
	for i in v.size():
		var p := v[i]
		var k := 1.0 + nz.get_noise_3dv(p * 1.0) * 0.38
		p *= k
		if p.y < -0.3 * r:
			p.y = lerpf(p.y, -0.3 * r, 0.6)
		v[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()


static func _rock_mesh(r: float, rough: float, seed_i: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 7
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_i
	nz.frequency = 0.9 / r
	nz.fractal_octaves = 2
	for i in v.size():
		var p := v[i]
		var k := 1.0 + nz.get_noise_3dv(p) * rough
		p *= k
		# flat facets: quantise a little for a chunky painted rock
		p = p.snapped(Vector3.ONE * r * 0.12)
		if p.y < 0.0:
			p.y *= 0.5
		v[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()


static func _ruin_arch(n: Node3D, at: Vector3) -> void:
	var r := Node3D.new()
	r.name = "RuinArch"
	n.add_child(r)
	var stone := mat(Color("#A2968E"), Color("#625A70"), {"snow_amount": 0.3, "noise_scale": 0.7, "paint_strength": 0.4, "rim_amount": 0.25, "blocks": 0.6, "warm_amount": 0.8, "warm_col": Color("#E8B888")})
	var gy := height(at.x, at.z)
	# pointed (equilateral Gothic) half-arch, snapped off just short of the apex; the right pier stands alone
	var Wi := 3.0
	var T := 1.0
	var Wo := Wi + T
	var H := 6.5
	var poly := PackedVector2Array()
	poly.append(Vector2(-Wo, 0))
	poly.append(Vector2(-Wo, H))
	for i in 10:
		var a := lerpf(PI, PI * 0.4, float(i) / 9.0)
		poly.append(Vector2(Wo, H) + Vector2(cos(a), sin(a)) * (2.0 * Wo))
	var tip := poly[poly.size() - 1]
	poly.append(tip + Vector2(0.15, -0.7))
	poly.append(tip + Vector2(-0.35, -1.1))
	poly.append(tip + Vector2(-0.1, -1.6))
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
	var W := Wi
	var arch := LdGear.mi(LdGear.extrude(poly, 1.6, 0.12), stone, r)
	arch.transform = Transform3D(Basis(Vector3.UP, 0.15), at + Vector3(0, gy - 0.3, 0))
	# the matching right pier, standing alone
	var pier := LdGear.mi(LdGear.box(Vector3(T, H * 0.75, 1.3)), stone, r)
	pier.transform = Transform3D(Basis(Vector3.UP, 0.15), at + Basis(Vector3.UP, 0.15) * Vector3(W + T * 0.5, 0, 0) + Vector3(0, gy + H * 0.375 - 0.3, 0))
	# collapsed voussoir blocks
	for i in 6:
		var b := LdGear.mi(LdGear.box(Vector3(rng.randf_range(0.6, 1.1), rng.randf_range(0.5, 0.8), rng.randf_range(0.7, 1.2))), stone, r)
		var p := at + Vector3(rng.randf_range(0.5, 5.0), 0, rng.randf_range(0.5, 3.5))
		b.transform = Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)), p + Vector3(0, height(p.x, p.z) + 0.25, 0))
	# rose-window tracery ring hanging in the arch
	var ring := LdGear.mi(LdGear.lathe([Vector2(1.3, -0.12), Vector2(1.45, 0.0), Vector2(1.3, 0.12)], 20), stone, r)
	ring.transform = Transform3D(Basis(Vector3.UP, 0.15) * Basis(Vector3.RIGHT, PI * 0.5), at + Basis(Vector3.UP, 0.15) * Vector3(-0.5, gy + H + 1.4, 0))


# ------------------------------------------------------------------ forest

static func _frost_tree_mesh(seed_i: int, scale: float) -> ArrayMesh:
	rng.seed = seed_i
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips: Array = []
	_branch(st, Vector3.ZERO, Vector3(0, 1, 0), 2.6 * scale, 0.28 * scale, 0, 5, tips, 0.75)
	st.generate_normals()
	return st.commit()


static func _forest(n: Node3D) -> void:
	var f := Node3D.new()
	f.name = "FrostForest"
	n.add_child(f)
	var bark := mat(Color("#3B3546"), Color("#26222E"), {"snow_amount": 0.42, "noise_scale": 2.5, "snow_sharp": 0.03, "snow_col": Color("#F4FAFF")})
	var variants: Array = []
	for i in 5:
		variants.append(_frost_tree_mesh(100 + i * 7, 1.0 + i * 0.12))
	rng.seed = 42
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-55, 55)
		var z := rng.randf_range(-70, 22)
		var d := Vector2(x, z).length()
		if d < 15.5:
			continue
		if Vector2(x - 13.5, z + 15.0).length() < 7.5 or Vector2(x + 6.0, z + 19.0).length() < 7.5:
			continue
		# keep the wide-shot sight line to the arena clear
		if z > 6.0 and x < -2.0 and x > -24.0:
			continue
		var y := height(x, z)
		var s := rng.randf_range(0.9, 1.5)
		LdGear.mi(variants[placed % variants.size()], bark, f, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - 0.2, z)))
		placed += 1
	# foreground framing trunks (dark, close to the gameplay / wide cameras)
	for p: Vector3 in [Vector3(-19.5, 0, 16.5), Vector3(-6.5, 0, 21.0), Vector3(-23.0, 0, 9.0)]:
		LdGear.mi(variants[2], bark, f, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.4), p + Vector3(0, height(p.x, p.z) - 0.2, 0)))
	# distant snow pines as a MultiMesh (silhouettes in the fog)
	var pine := _pine_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pine
	var xs: Array = []
	rng.seed = 9
	while xs.size() < 420:
		var x := rng.randf_range(-75, 75)
		var z := rng.randf_range(-90, 0)
		if Vector2(x, z).length() < 30.0:
			continue
		var s := rng.randf_range(1.0, 2.2)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s)), Vector3(x, height(x, z) - 0.3, z)))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat(Color("#1F4A4E"), Color("#163236"), {"snow_amount": 0.5, "noise_scale": 1.4, "snow_sharp": 0.04})
	f.add_child(mmi)


static func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [[0.0, 1.8, 1.6], [1.2, 1.45, 1.4], [2.3, 1.05, 1.3], [3.3, 0.7, 1.2]]
	for t: Array in tiers:
		var y0: float = t[0]
		var r: float = t[1]
		var h: float = t[2]
		var seg := 9
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var p0 := Vector3(cos(a0) * r, y0 + 0.4, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0 + 0.4, sin(a1) * r)
			var top := Vector3(0, y0 + 0.4 + h, 0)
			# drooping skirt
			var m0 := Vector3(cos(a0) * r * 0.95, y0 + 0.1, sin(a0) * r * 0.95)
			var m1 := Vector3(cos(a1) * r * 0.95, y0 + 0.1, sin(a1) * r * 0.95)
			for v in [p0, top, p1, m0, p0, p1, m0, p1, m1]:
				st.add_vertex(v)
	_tube_into(st, [Vector3.ZERO, Vector3(0, 0.6, 0)], [0.15, 0.12], 5)
	st.generate_normals()
	return st.commit()


# ------------------------------------------------------------------ dressing

static func _ice_clusters(n: Node3D) -> void:
	var ice := LdGear.toon(Color("#5CC8F2"), {"shade": Color(0.35, 0.5, 0.95), "rim": Color.WHITE, "rim_strength": 1.0, "emit": Color("#2F9BFF") * 0.18, "line": 1.3, "darken": 0.45})
	var core := LdGear.glow(Color("#7FE8FF"), 1.3, true, 0.35)
	for c: Vector3 in [Vector3(-13.0, 0, -2.0), Vector3(9.0, 0, 11.5), Vector3(11.5, 0, -4.5), Vector3(-4.5, 0, -12.5), Vector3(-15.0, 0, -6.0)]:
		var g := Node3D.new()
		g.position = c + Vector3(0, height(c.x, c.z), 0)
		n.add_child(g)
		for i in 6:
			var h := rng.randf_range(0.8, 2.6) * (1.6 if i == 0 else 1.0)
			var r := h * 0.16
			var shard := LdGear.lathe([Vector2(r * 0.7, -0.2), Vector2(r, 0.0), Vector2(r, h * 0.7), Vector2(0.0, h)], 6)
			var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.1, 0.55) if i > 0 else 0.08)
			var p := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)) if i > 0 else Vector3.ZERO
			LdGear.mi(shard, ice, g, Transform3D(tilt, p))
			if i < 2:
				LdGear.mi(shard, core, g, Transform3D(tilt.scaled(Vector3(0.55, 0.85, 0.55)), p))
		var om := OmniLight3D.new()
		om.light_color = Color("#7FE8FF")
		om.light_energy = 1.2
		om.omni_range = 5.0
		om.position = Vector3(0, 1.4, 0)
		g.add_child(om)


static func _rocks(n: Node3D) -> void:
	var rock := mat(Color("#6E7896"), Color("#454E6C"), {"snow_amount": 0.4, "strata": 1.0, "noise_scale": 0.6, "warm_amount": 0.5, "warm_col": Color("#C89A6A")})
	rng.seed = 77
	for i in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(11.0, 24.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if p.z > 8.0 and p.x < 0.0 and p.x > -22.0:
			continue
		var r := rng.randf_range(0.5, 1.8)
		LdGear.mi(_rock_mesh(r, 0.4, 500 + i), rock, n, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, height(p.x, p.z), 0)))


static func _banners(n: Node3D) -> void:
	var pole := LdGear.toon(Color("#2A2A34"))
	var gold := LdGear.toon(Color("#D8B25A"), {"shade": Color("#8A5A2B") / Color("#D8B25A")})
	for b: Array in [[Vector3(-7.2, ARENA_Y, -6.2), Color("#2F7BFF")], [Vector3(6.0, ARENA_Y, -7.4), Color("#FF3B4A")]]:
		var at: Vector3 = b[0]
		var col: Color = b[1]
		var g := Node3D.new()
		g.position = at
		n.add_child(g)
		LdGear.mi(LdGear.cyl(0.06, 0.08, 6.2, 8), pole, g, Transform3D(Basis(), Vector3(0, 3.1, 0)))
		LdGear.mi(LdGear.sphere(0.13, 10), gold, g, Transform3D(Basis(), Vector3(0, 6.25, 0)))
		LdGear.mi(LdGear.cyl(0.035, 0.035, 1.4, 6), gold, g, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.55, 5.9, 0)))
		# cloth: wavy ribbon hanging from the crossbar, swallow-tail cut implied by the tapering width
		var pts: Array = []
		var w: Array = []
		var s: Array = []
		for i in 12:
			var t := float(i) / 11.0
			pts.append(Vector3(0.55 + sin(t * 4.0) * 0.08, 5.85 - t * 4.4, sin(t * 5.0 + 1.0) * 0.2))
			w.append(1.15)
			s.append(Vector3(1, 0, 0.15 * cos(t * 5.0)))
		var tex: Texture2D = load("res://lookdev/assets/textures/banner_%s.png" % ("blue" if col.b > col.r else "red"))
		var cloth := LdGear.toon(Color.WHITE, {"tex": tex, "shade": Color(0.5, 0.5, 0.85), "rim": Color(1, 0.95, 0.85), "line": 1.4})
		(cloth.next_pass as ShaderMaterial).set_shader_parameter("albedo_tex", tex)
		(cloth.next_pass as ShaderMaterial).set_shader_parameter("albedo_mul", col)
		LdGear.mi(LdGear.ribbon(pts, w, s, 0.02), cloth, g)


static func _mountains(n: Node3D) -> void:
	var m := mat(Color("#8EA6C8"), Color("#6D84AA"), {"snow_amount": 0.62, "noise_scale": 0.05, "strata": 0.4, "snow_sharp": 0.08})
	rng.seed = 5
	for i in 9:
		var a := lerpf(-2.6, -0.5, float(i) / 8.0) + rng.randf_range(-0.1, 0.1)
		var d := rng.randf_range(170.0, 260.0)
		var h := rng.randf_range(55.0, 110.0)
		var prof := [Vector2(1.0, 0.0), Vector2(0.7, 0.35), Vector2(0.38, 0.72), Vector2(0.0, 1.0)]
		var pr: Array = []
		for p: Vector2 in prof:
			pr.append(Vector2(p.x * h * 1.3, p.y * h))
		var mesh := LdGear.lathe(pr, 7, 1.0, rng.randf_range(0.5, 0.9))
		LdGear.mi(mesh, m, n, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, -8.0, sin(a) * d)))


static func _particles(n: Node3D) -> void:
	var snow := _particles_box(Vector3(45, 14, 45), 2600, 9.0, Color(1, 1, 1, 0.9), 0.07, Vector3(0.4, -1.0, 0.15), false)
	snow.position = Vector3(0, 13, 0)
	n.add_child(snow)
	var motes := _particles_box(Vector3(20, 3, 20), 160, 7.0, Color("#BFF2FF"), 0.09, Vector3(0.05, 0.08, 0.0), false)
	motes.position = Vector3(0, ARENA_Y + 2.0, 0)
	(motes.draw_pass_1.surface_get_material(0) as StandardMaterial3D).emission_energy_multiplier = 2.5
	n.add_child(motes)


static func _particles_box(ext: Vector3, amount: int, life: float, col: Color, size: float, vel: Vector3, leaves: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(-ext * 1.5, ext * 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = vel.normalized()
	pm.spread = 25.0
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.3
	pm.gravity = Vector3(0, -0.15 if leaves else 0.0, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	if leaves:
		pm.angle_min = 0
		pm.angle_max = 360
		pm.angular_velocity_min = -120
		pm.angular_velocity_max = 120
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (0.7 if leaves else 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = col
	if leaves:
		m.albedo_texture = LdVfx.leaf_tex()
		m.alpha_scissor_threshold = 0.5
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if not leaves:
		m.albedo_texture = LdVfx.spark_tex()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if col.b > 0.95 and col.r < 0.9 else BaseMaterial3D.BLEND_MODE_MIX
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.6
	q.material = m
	p.draw_pass_1 = q
	return p
