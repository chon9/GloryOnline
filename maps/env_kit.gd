class_name EnvKit
extends RefCounted
## Painted-environment toolkit (art bible 3.2 / 4.x), ported from the look-dev slice (lookdev/scripts/environment.gd).
## One EnvKit per map build. It owns:
##  - materials: painted_env (hand-painted value noise, tinted soft terminator, slope cover = snow / grass / sand),
##    foliage cards, grass tufts, lava, water/ice, glow; cached statically by parameters.
##  - mesh builders: lathe, extrude, tube, ribbon, chunky rocks, foliage puffs, branching trees, pines, leaf cards.
##  - a static-geometry BATCHER: add(mesh, mat, xform) appends into one merged ArrayMesh per material (+ shadow flag),
##    inst() collects MultiMesh instances; finish() emits a handful of GeometryInstance3D nodes (draw-call budget).
##  - terrain: height-function grid meshes with matching trimesh collision on CoreUtil.LAYER_WORLD.
##  - atmosphere presets per zone (bible 4.2): painted sky, key + fill light, fog / volumetric fog, glow, grading.
##  - painted backdrop ranges, distant mountains, particles (snow, motes, embers, petals, leaves).
## Everything is deterministic: geometry comes from seeded RandomNumberGenerator / FastNoiseLite only, and batches
## are emitted in insertion order, so every peer builds identical maps.

const PAINT := preload("res://visuals/shaders/painted_env.gdshader")
const FLOOR := preload("res://visuals/shaders/arena_floor.gdshader")
const SKY := preload("res://visuals/shaders/anime_sky.gdshader")
const BACKDROP := preload("res://visuals/shaders/painted_backdrop.gdshader")
const FOLIAGE := preload("res://visuals/shaders/painted_env_foliage.gdshader")
const GRASS := preload("res://visuals/shaders/painted_env_grass.gdshader")
const LAVA := preload("res://visuals/shaders/painted_env_lava.gdshader")
const WATER := preload("res://visuals/shaders/painted_env_water.gdshader")
const FLAME := preload("res://visuals/shaders/painted_env_flame.gdshader")
const TEX: String = "res://assets/env/painted/"

## Zone presets (bible 4.2): key light, fill/sky, fog, grading. Sky keys map to anime_sky uniforms.
const PRESETS: Dictionary = {
	"frost": {
		"sun_color": Color("#FFF1DC"), "sun_energy": 1.45, "sun_dir": Vector3(-0.72, -0.48, 0.5),
		"fill_color": Color("#9FD6FF"), "fill_energy": 0.25, "fill_dir": Vector3(0.45, -0.35, -0.8),
		"ambient": Color("#8FC3DD"), "ambient_energy": 0.3, "sky_contrib": 0.6, "exposure": 0.82,
		"fog_color": Color("#9CCBE8"), "fog_density": 0.0028, "fog_aerial": 0.35, "fog_sky": 0.15, "fog_height": 4.0,
		"vfog": 0.0012, "vfog_albedo": Color("#E6F4FF"), "vfog_emission": Color("#5FA8C8"),
		"saturation": 1.22, "contrast": 1.1, "glow": 0.75,
		"sky": {},
	},
	"glory_stage": {
		"sun_color": Color("#FFC890"), "sun_energy": 1.75, "sun_dir": Vector3(0.62, -0.36, 0.7),
		"fill_color": Color("#7FA8FF"), "fill_energy": 0.3, "fill_dir": Vector3(-0.5, -0.4, -0.75),
		"ambient": Color("#6E7FB8"), "ambient_energy": 0.22, "sky_contrib": 0.4, "exposure": 0.9,
		"fog_color": Color("#E8C8C8"), "fog_density": 0.0022, "fog_aerial": 0.4, "fog_sky": 0.1, "fog_height": -5.0, "fog_height_density": 0.08,
		"vfog": 0.0009, "vfog_albedo": Color("#F0E4FF"), "vfog_emission": Color("#6A5AB8"),
		"saturation": 1.18, "contrast": 1.08, "glow": 0.8,
		"sky": {"zenith": Color("#1E2A6E"), "mid_sky": Color("#5A5AB0"), "horizon": Color("#FFB98A"), "ground": Color("#6A5A8A"),
			"cloud_lit": Color("#FFE4C8"), "cloud_shade": Color("#8A78B0"), "sun_tint": Color("#FFD0A0"), "cloud_cover": 0.3, "cloud_scale": 1.1},
	},
	"blossom": {
		"sun_color": Color("#FFE6C0"), "sun_energy": 1.5, "sun_dir": Vector3(-0.55, -0.62, -0.55),
		"fill_color": Color("#A8D0FF"), "fill_energy": 0.3, "fill_dir": Vector3(0.5, -0.4, 0.75),
		"ambient": Color("#9EC8E8"), "ambient_energy": 0.35, "sky_contrib": 0.6, "exposure": 0.86,
		"fog_color": Color("#CFE4F2"), "fog_density": 0.0022, "fog_aerial": 0.25, "fog_sky": 0.12, "fog_height": -12.0, "fog_height_density": 0.002,
		"vfog": 0.0004, "vfog_albedo": Color("#FFF2F6"), "vfog_emission": Color("#E8A0C0"),
		"saturation": 1.06, "contrast": 1.1, "glow": 0.7,
		"sky": {"zenith": Color("#1E6AC8"), "mid_sky": Color("#62A8E8"), "horizon": Color("#E8F0F4"), "ground": Color("#7A9A80"),
			"cloud_cover": 0.5},
	},
	"golden_ruins": {
		"sun_color": Color("#FFBE70"), "sun_energy": 1.75, "sun_dir": Vector3(-0.78, -0.3, 0.55),
		"fill_color": Color("#6A86D8"), "fill_energy": 0.45, "fill_dir": Vector3(0.6, -0.45, -0.6),
		"ambient": Color("#8A80A8"), "ambient_energy": 0.22, "sky_contrib": 0.3, "exposure": 0.88,
		"fog_color": Color("#E0B080"), "fog_density": 0.003, "fog_aerial": 0.35, "fog_sky": 0.15, "fog_height": -2.0, "fog_height_density": 0.004,
		"vfog": 0.0016, "vfog_albedo": Color("#FFE0B8"), "vfog_emission": Color("#C98A50"),
		"saturation": 1.06, "contrast": 1.1, "glow": 0.8,
		"sky": {"zenith": Color("#3A5A9A"), "mid_sky": Color("#8AA8D0"), "horizon": Color("#FFD8A0"), "ground": Color("#B08A6A"),
			"cloud_lit": Color("#FFE0B0"), "cloud_shade": Color("#B08AA0"), "sun_tint": Color("#FFC070"), "cloud_cover": 0.45},
	},
	"lava": {
		"sun_color": Color("#FFB070"), "sun_energy": 0.7, "sun_dir": Vector3(0.2, -0.9, 0.35),
		"fill_color": Color("#7A6AD8"), "fill_energy": 0.35, "fill_dir": Vector3(-0.4, -0.5, -0.75),
		"ambient": Color("#4A3A6A"), "ambient_energy": 0.6, "sky_contrib": 0.0, "exposure": 1.0,
		"fog_color": Color("#2A1424"), "fog_density": 0.0035, "fog_aerial": 0.0, "fog_sky": 0.7, "fog_height": 0.0, "fog_height_density": 0.0,
		"vfog": 0.0015, "vfog_albedo": Color("#FFC0A0"), "vfog_emission": Color("#3A0A06"),
		"saturation": 1.1, "contrast": 1.12, "glow": 0.9,
		"sky": {"zenith": Color("#0E0608"), "mid_sky": Color("#1A0A10"), "horizon": Color("#3A1218"), "ground": Color("#120608"),
			"cloud_lit": Color("#5A2A1A"), "cloud_shade": Color("#1A0A0A"), "sun_tint": Color("#FF7A3A"), "cloud_cover": 0.2,
			"sun_strength": 0.0},
	},
	"moon": {
		"sun_color": Color("#A8DCFF"), "sun_energy": 1.25, "sun_dir": Vector3(0.2, -0.34, 0.92),
		"fill_color": Color("#7A5AD8"), "fill_energy": 0.4, "fill_dir": Vector3(-0.5, -0.4, -0.6),
		"ambient": Color("#3B2E7A"), "ambient_energy": 0.42, "sky_contrib": 0.3, "exposure": 1.0,
		"fog_color": Color("#34346E"), "fog_density": 0.004, "fog_aerial": 0.3, "fog_sky": 0.25, "fog_height": 0.6, "fog_height_density": 0.07,
		"vfog": 0.0016, "vfog_albedo": Color("#A8B8F0"), "vfog_emission": Color("#3B2E7A"),
		"saturation": 1.0, "contrast": 1.12, "glow": 0.85,
		"sky": {"zenith": Color("#070A24"), "mid_sky": Color("#1C1E5A"), "horizon": Color("#4A4AA0"), "ground": Color("#1A1840"),
			"cloud_lit": Color("#9AA8E8"), "cloud_shade": Color("#2A2A6A"), "sun_tint": Color("#DDF2FF"), "cloud_cover": 0.3,
			"moon": 1.0, "moon_size": 0.07, "star_amount": 1.0, "nebula_col": Color("#7A4AD8")},
	},
}

static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

var root: Node3D
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var shape_count: int = 0
var _groups: Dictionary = {}       # key -> {mat, st, shadow, n}
var _group_order: Array[String] = []
var _mm: Dictionary = {}           # key -> {mesh, mat, xs, cols, shadow}
var _mm_order: Array[String] = []


func _init(p_root: Node3D, seed_value: int, p_body: StaticBody3D = null) -> void:
	root = p_root
	body = p_body
	rng.seed = seed_value
	noise.seed = seed_value % 100000
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4


# ================================================================== materials
static func paint(base: Color, base2: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "p%s%s%s" % [base.to_html(), base2.to_html(), str(opts)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("base_col2", base2)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


static func glow(col: Color, energy: float = 3.0, additive: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "g%s%.2f%s%.2f" % [col.to_html(), energy, additive, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	if additive or alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func foliage(tex_name: String, mul: Color = Color.WHITE, shade: Color = Color(0.45, 0.25, 0.55),
		rim: Color = Color(1.0, 0.75, 0.55), wind: float = 0.06) -> ShaderMaterial:
	var key := "f%s%s%s%s%.3f" % [tex_name, mul.to_html(), shade.to_html(), rim.to_html(), wind]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo_tex", load(TEX + tex_name))
	m.set_shader_parameter("albedo_mul", mul)
	m.set_shader_parameter("shade_tint", shade)
	m.set_shader_parameter("rim_col", rim)
	m.set_shader_parameter("wind", wind)
	_mat_cache[key] = m
	return m


static func grass_mat(root_c: Color, tip_c: Color, shade: Color, wind: float = 0.12, instance_color: bool = false) -> ShaderMaterial:
	var key := "gr%s%s%s%.2f%s" % [root_c.to_html(), tip_c.to_html(), shade.to_html(), wind, instance_color]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = GRASS
	m.set_shader_parameter("root_col", root_c)
	m.set_shader_parameter("tip_col", tip_c)
	m.set_shader_parameter("shade_tint", shade)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("use_instance_color", 1.0 if instance_color else 0.0)
	_mat_cache[key] = m
	return m


static func shader_mat(sh: Shader, params: Dictionary = {}) -> ShaderMaterial:
	var key := "s%s%s" % [sh.resource_path, str(params)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = sh
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	_mat_cache[key] = m
	return m


## Painted cloth for banners (texture from assets/env/painted/, tinted).
static func cloth(tex_name: String, tint: Color = Color.WHITE) -> ShaderMaterial:
	var key := "c%s%s" % [tex_name, tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("albedo_tex", load(TEX + tex_name))
	m.set_shader_parameter("albedo_mul", tint)
	m.set_shader_parameter("shade_tint", Color(0.5, 0.5, 0.85))
	m.set_shader_parameter("rim_col", Color(1.0, 0.9, 0.75))
	m.set_shader_parameter("wind", 0.05)
	m.set_shader_parameter("wind_speed", 2.2)
	m.set_shader_parameter("alpha_cut", 0.5)
	_mat_cache[key] = m
	return m


static func clear_caches() -> void:
	_mat_cache.clear()
	_mesh_cache.clear()


# ================================================================== batching
## Merges `mesh` (transformed) into the static batch of `mat`. Small props: shadow = false.
func add(mesh: Mesh, mat: Material, xf: Transform3D = Transform3D.IDENTITY, shadow: bool = true) -> void:
	if mesh == null:
		return
	if mesh is PrimitiveMesh:
		mesh = flat(mesh as PrimitiveMesh)
	var key := "%d|%s" % [mat.get_instance_id(), "s" if shadow else "n"]
	var g: Dictionary
	if _groups.has(key):
		g = _groups[key]
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		g = {"mat": mat, "st": st, "shadow": shadow, "n": 0}
		_groups[key] = g
		_group_order.append(key)
	var st2: SurfaceTool = g["st"]
	for s in mesh.get_surface_count():
		st2.append_from(mesh, s, xf)
	g["n"] = int(g["n"]) + 1


## Same mesh many times (foliage, pines, tufts): one MultiMeshInstance3D per (mesh, material).
func inst(mesh: Mesh, mat: Material, xf: Transform3D, shadow: bool = true, color: Color = Color(1, 1, 1, 0)) -> void:
	var key := "%d|%d|%s" % [mesh.get_instance_id(), mat.get_instance_id() if mat else 0, "s" if shadow else "n"]
	if not _mm.has(key):
		_mm[key] = {"mesh": mesh, "mat": mat, "xs": [], "cols": [], "shadow": shadow, "colored": false}
		_mm_order.append(key)
	var e: Dictionary = _mm[key]
	(e["xs"] as Array).append(xf)
	(e["cols"] as Array).append(color)
	if color.a > 0.0:
		e["colored"] = true


## Emits the batches under `parent` (default: root). Returns the number of geometry nodes created.
func finish(parent: Node3D = null) -> int:
	var holder := Node3D.new()
	holder.name = "PaintedGeometry"
	(parent if parent != null else root).add_child(holder)
	var made := 0
	for key: String in _group_order:
		var g: Dictionary = _groups[key]
		var st: SurfaceTool = g["st"]
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Batch%d" % made
		mi.mesh = mesh
		mi.material_override = g["mat"]
		if not bool(g["shadow"]):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		made += 1
	for key: String in _mm_order:
		var e: Dictionary = _mm[key]
		var xs: Array = e["xs"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = bool(e["colored"])
		mm.mesh = e["mesh"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			if mm.use_colors:
				mm.set_instance_color(i, (e["cols"] as Array)[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Multi%d" % made
		mmi.multimesh = mm
		if e["mat"] != null:
			mmi.material_override = e["mat"]
		if not bool(e["shadow"]):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
		made += 1
	_groups.clear()
	_group_order.clear()
	_mm.clear()
	_mm_order.clear()
	return made


## Painted flickering flame tongue (billboard, additive) standing on `base`; batched as one MultiMesh per tint.
func flame(base: Vector3, height: float = 0.9, tint: Color = Color(1.0, 0.8, 0.6)) -> void:
	var key := "flame%s" % tint.to_html()
	var m: ShaderMaterial
	if _mat_cache.has(key):
		m = _mat_cache[key]
	else:
		m = ShaderMaterial.new()
		m.shader = FLAME
		m.set_shader_parameter("flame_tex", load(TEX + "fire_tongue.png"))
		m.set_shader_parameter("tint", tint)
		_mat_cache[key] = m
	if not _mesh_cache.has("flame_quad"):
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.center_offset = Vector3(0, 0.5, 0)
		_mesh_cache["flame_quad"] = q
	inst(_mesh_cache["flame_quad"], m, Transform3D(Basis().scaled(Vector3(height * 0.7, height, 1.0)), base), false)


## Ground litter (fallen petals / leaves): flat painted atlas quads lying on the ground, one MultiMesh.
func litter(center: Vector3, radius: float, count: int, mat: Material, hfn: Callable = Callable(), size: float = 0.9) -> void:
	if not _mesh_cache.has("litter_quad"):
		var q := PlaneMesh.new()
		q.size = Vector2(1.0, 1.0)
		_mesh_cache["litter_quad"] = q
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := center + Vector3(cos(a) * d, 0, sin(a) * d)
		var y := float(hfn.call(p.x, p.z)) if hfn.is_valid() else center.y
		var s := size * rng.randf_range(0.6, 1.3)
		inst(_mesh_cache["litter_quad"], mat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s)), Vector3(p.x, y + 0.03, p.z)), false)


# ================================================================== collision
func col_box(center: Vector3, size: Vector3, yaw: float = 0.0, label: String = "EnvBox") -> CollisionShape3D:
	return col_box_xf(Transform3D(Basis(Vector3.UP, yaw), center), size, label)


func col_box_xf(t: Transform3D, size: Vector3, label: String = "EnvBox") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = t
	cs.name = "%s%d" % [label, shape_count]
	body.add_child(cs)
	shape_count += 1
	return cs


func col_cyl(base: Vector3, radius: float, height: float, label: String = "EnvCyl") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = base + Vector3(0, height * 0.5, 0)
	cs.name = "%s%d" % [label, shape_count]
	body.add_child(cs)
	shape_count += 1
	return cs


## Convex hull of a mesh placed with `xf` (rocks, mounds).
func col_hull(mesh: Mesh, xf: Transform3D, label: String = "EnvHull") -> CollisionShape3D:
	var pts := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for p in v:
			pts.append(Transform3D(xf.basis, Vector3.ZERO) * p)
	var cvx := ConvexPolygonShape3D.new()
	cvx.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = cvx
	cs.position = xf.origin
	cs.name = "%s%d" % [label, shape_count]
	body.add_child(cs)
	shape_count += 1
	return cs


func col_trimesh(faces: PackedVector3Array, label: String = "EnvTerrain") -> CollisionShape3D:
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.name = "%s%d" % [label, shape_count]
	body.add_child(cs)
	shape_count += 1
	return cs


# ================================================================== terrain
## Height-field grid over `rect` (XZ) sampled every `step` m with hfn(x, z) -> y. Visual mesh goes into the batch of
## `mat`. Cells whose centre lies inside `col_rect` also become trimesh collision (same samples, so it matches).
## `skip` (optional Callable(x, z) -> bool) drops cells (holes for lava, water...).
func terrain(rect: Rect2, step: float, hfn: Callable, mat: Material, col_rect: Rect2 = Rect2(), uv_scale: float = 0.1,
		skip: Callable = Callable(), shadow: bool = true, flip: bool = false, mask: Callable = Callable()) -> void:
	var nx := int(ceil(rect.size.x / step))
	var nz := int(ceil(rect.size.y / step))
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			hs[j * (nx + 1) + i] = float(hfn.call(rect.position.x + i * step, rect.position.y + j * step))
	var ms := PackedColorArray()
	if mask.is_valid():
		ms.resize((nx + 1) * (nz + 1))
		for j in nz + 1:
			for i in nx + 1:
				ms[j * (nx + 1) + i] = mask.call(rect.position.x + i * step, rect.position.y + j * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var want_col := col_rect.size.x > 0.0 and body != null
	for j in nz:
		for i in nx:
			var x0 := rect.position.x + i * step
			var z0 := rect.position.y + j * step
			if skip.is_valid() and bool(skip.call(x0 + step * 0.5, z0 + step * 0.5)):
				continue
			var p00 := Vector3(x0, hs[j * (nx + 1) + i], z0)
			var p10 := Vector3(x0 + step, hs[j * (nx + 1) + i + 1], z0)
			var p11 := Vector3(x0 + step, hs[(j + 1) * (nx + 1) + i + 1], z0 + step)
			var p01 := Vector3(x0, hs[(j + 1) * (nx + 1) + i], z0 + step)
			# split along the shorter diagonal so ridges stay crisp
			var tri: Array
			if absf(p00.y - p11.y) < absf(p10.y - p01.y):
				tri = [p00, p10, p11, p00, p11, p01]
			else:
				tri = [p00, p10, p01, p10, p11, p01]
			if flip:
				tri.reverse()
			for v: Vector3 in tri:
				st.set_uv(Vector2(v.x, v.z) * uv_scale)
				if mask.is_valid():
					var gi := clampi(roundi((v.x - rect.position.x) / step), 0, nx)
					var gj := clampi(roundi((v.z - rect.position.y) / step), 0, nz)
					st.set_color(ms[gj * (nx + 1) + gi])
				st.add_vertex(v)
			if want_col and col_rect.has_point(Vector2(x0 + step * 0.5, z0 + step * 0.5)):
				for v: Vector3 in tri:
					faces.append(v)
	st.generate_normals()
	add(st.commit(), mat, Transform3D.IDENTITY, shadow)
	if faces.size() > 0:
		col_trimesh(faces)


## Terraced height: flat shelves and steep painted cliff bands (`k` = fraction of each step that is cliff).
static func terrace(h: float, step: float, k: float = 0.35) -> float:
	var f := h / step
	var fl := floorf(f)
	return (fl + smoothstep(1.0 - k, 1.0, f - fl)) * step


# ================================================================== mesh builders
## PrimitiveMesh -> non-indexed ArrayMesh (so SurfaceTool.append_from can merge it with our own meshes).
static func flat(m: PrimitiveMesh) -> ArrayMesh:
	var key := "flat%d" % m.get_instance_id()
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.deindex()
	var out := st.commit()
	_mesh_cache[key] = out
	return out


static func box(size: Vector3) -> ArrayMesh:
	var key := "box%s" % size
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var b := BoxMesh.new()
	b.size = size
	var out := flat(b)
	_mesh_cache[key] = out
	return out


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 12) -> ArrayMesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [r_top, r_bot, h, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	var out := flat(c)
	_mesh_cache[key] = out
	return out


static func sphere(r: float, seg: int = 12) -> ArrayMesh:
	var key := "sph%.3f_%d" % [r, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	var out := flat(s)
	_mesh_cache[key] = out
	return out


## Surface of revolution around +Y. profile = [Vector2(radius, y), ...] bottom -> top.
static func lathe(profile: Array, seg: int = 16, sx: float = 1.0, sz: float = 1.0, arc: float = TAU) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for j in seg:
			var t0 := arc * j / seg
			var t1 := arc * (j + 1) / seg
			var p00 := Vector3(cos(t0) * a.x * sx, a.y, sin(t0) * a.x * sz)
			var p01 := Vector3(cos(t1) * a.x * sx, a.y, sin(t1) * a.x * sz)
			var p10 := Vector3(cos(t0) * b.x * sx, b.y, sin(t0) * b.x * sz)
			var p11 := Vector3(cos(t1) * b.x * sx, b.y, sin(t1) * b.x * sz)
			st.set_uv(Vector2(float(j) / seg, float(i) / profile.size()))
			for p: Vector3 in [p00, p11, p10, p00, p01, p11]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## Flat polygon (x, y) extruded along Z by `depth`, centred on z = 0, optional bevel inset on the faces.
static func extrude(poly: PackedVector2Array, depth: float, bevel: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	var face := poly
	if bevel > 0.0:
		var off := Geometry2D.offset_polygon(poly, -bevel)
		if off.size() > 0 and off[0].size() == poly.size():
			face = off[0]
			idx = Geometry2D.triangulate_polygon(face)
	if idx.is_empty():
		face = poly
		idx = Geometry2D.triangulate_polygon(poly)
	for side: float in [1.0, -1.0]:
		for k in range(0, idx.size(), 3):
			var order := [idx[k], idx[k + 1], idx[k + 2]] if side < 0 else [idx[k], idx[k + 2], idx[k + 1]]
			for o: int in order:
				var p: Vector2 = face[o]
				st.set_uv(p * 0.5)
				st.add_vertex(Vector3(p.x, p.y, side * hz))
	var n := poly.size()
	var ccw := _area(poly) > 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if bevel > 0.0 and face.size() == n:
			var fa := face[i]
			var fb := face[(i + 1) % n]
			for side: float in [1.0, -1.0]:
				_quad(st, [Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(fb.x, fb.y, side * hz), Vector3(fa.x, fa.y, side * hz)], (side > 0) == ccw)
		else:
			_quad(st, [Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3(b.x, b.y, hz), Vector3(a.x, a.y, hz)], ccw)
	st.generate_normals()
	return st.commit()


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _quad(st: SurfaceTool, q: Array, flip: bool) -> void:
	var order := [0, 1, 2, 0, 2, 3] if not flip else [0, 2, 1, 0, 3, 2]
	for o: int in order:
		st.set_uv(Vector2(o % 2, o / 2))
		st.add_vertex(q[o])


## Tube along a polyline; radius float or Array per point.
static func tube(pts: Array, radius: Variant, seg: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array = []
	for i in pts.size():
		radii.append(radius[i] if radius is Array else radius)
	tube_into(st, pts, radii, seg)
	st.generate_normals()
	return st.commit()


static func tube_into(st: SurfaceTool, pts: Array, radii: Array, sides: int) -> void:
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
			for v: Vector3 in [a, c, b, a, d, c]:
				st.add_vertex(v)


## Ribbon / cloth strip along a polyline (banners). widths and sides per point; thickness makes a closed slab.
static func ribbon(pts: Array, widths: Array, sides: Array, thickness: float = 0.02) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var L: Array = []
	var R: Array = []
	var nrm: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var s: Vector3 = (sides[i] as Vector3).normalized() * float(widths[i]) * 0.5
		var tng: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		L.append(p - s)
		R.append(p + s)
		nrm.append(tng.cross(s).normalized())
	var h := thickness * 0.5
	for i in n - 1:
		var v0 := float(i) / (n - 1)
		var v1 := float(i + 1) / (n - 1)
		for side: float in [1.0, -1.0]:
			var q := [L[i] + nrm[i] * h * side, R[i] + nrm[i] * h * side, R[i + 1] + nrm[i + 1] * h * side, L[i + 1] + nrm[i + 1] * h * side]
			var uvs := [Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]
			var order := [0, 1, 2, 0, 2, 3] if side < 0 else [0, 2, 1, 0, 3, 2]
			for o: int in order:
				st.set_uv(uvs[o])
				st.add_vertex(q[o])
	st.generate_normals()
	return st.commit()


## Chunky painted rock: noise-displaced sphere with quantised facets and a flattened base.
static func rock_mesh(r: float, rough: float, seed_i: int) -> ArrayMesh:
	var key := "rock%.3f_%.3f_%d" % [r, rough, seed_i]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
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
		p *= 1.0 + nz.get_noise_3dv(p) * rough
		p = p.snapped(Vector3.ONE * r * 0.12)
		if p.y < 0.0:
			p.y *= 0.5
		v[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_uv(Vector2(v[i].x, v[i].z) * 0.3)
		st.add_vertex(v[i])
	st.generate_normals()
	var out := st.commit()
	_mesh_cache[key] = out
	return out


## Lumpy foliage clump (sphere displaced by noise, flattened bottom).
static func puff_mesh(r: float, seed_i: int) -> ArrayMesh:
	var key := "puff%.3f_%d" % [r, seed_i]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_i
	nz.frequency = 1.4
	for i in v.size():
		var p := v[i] * (1.0 + nz.get_noise_3dv(v[i]) * 0.38)
		if p.y < -0.3 * r:
			p.y = lerpf(p.y, -0.3 * r, 0.6)
		v[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(v[i])
	st.generate_normals()
	var out := st.commit()
	_mesh_cache[key] = out
	return out


## Recursive branching (tubes) into `st`; leaf tips appended to `tips`.
static func branch(r_rng: RandomNumberGenerator, st: SurfaceTool, p: Vector3, dir: Vector3, length: float, r: float,
		depth: int, max_depth: int, tips: Array, spread: float, sides: int = 6) -> void:
	var seg := 4
	var pts: Array = [p]
	var d := dir
	var q := p
	for i in seg:
		d = (d + Vector3(r_rng.randf_range(-0.18, 0.18), r_rng.randf_range(-0.05, 0.12), r_rng.randf_range(-0.18, 0.18))).normalized()
		q += d * length / seg
		pts.append(q)
	var radii: Array = []
	for i in pts.size():
		radii.append(lerpf(r, r * 0.62, float(i) / seg))
	tube_into(st, pts, radii, sides if depth < 3 else 4)
	if depth >= max_depth:
		tips.append(q)
		return
	var kids := 2 if depth < 1 else (3 if r_rng.randf() < 0.5 else 2)
	for k in kids:
		var a := TAU * k / kids + r_rng.randf() * 1.2
		var side := Vector3(cos(a), 0, sin(a))
		var nd := (d + side * spread * r_rng.randf_range(0.8, 1.3) + Vector3(0, 0.25, 0)).normalized()
		branch(r_rng, st, q, nd, length * r_rng.randf_range(0.62, 0.78), r * 0.62, depth + 1, max_depth, tips, spread, sides)


## A full deciduous tree skeleton: returns [trunk ArrayMesh, tips Array[Vector3]] (cached by seed/params).
static func tree_skeleton(seed_i: int, height: float, radius: float, depth: int = 5, spread: float = 0.6, lean: Vector3 = Vector3(0.1, 1, 0.05)) -> Array:
	var key := "tree%d_%.2f_%.2f_%d_%.2f_%s" % [seed_i, height, radius, depth, spread, lean]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = seed_i
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips: Array = []
	branch(r, st, Vector3.ZERO, lean.normalized(), height, radius, 0, depth, tips, spread)
	st.generate_normals()
	var out := [st.commit(), tips]
	_mesh_cache[key] = out
	return out


## Layered leaf cards around canopy tips: double-sided quads whose normals bend outward from `centre`.
static func leaf_cards(r_rng: RandomNumberGenerator, tips: Array, centre: Vector3, per_tip: int, size: float, jitter: float = 1.15) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in tips:
		for k in per_tip:
			var c := p + Vector3(r_rng.randf_range(-1, 1), r_rng.randf_range(-0.5, 0.9), r_rng.randf_range(-1, 1)) * jitter
			var out := (c - centre).normalized()
			var b := Basis(Vector3(r_rng.randf_range(-1, 1), r_rng.randf_range(-1, 1), r_rng.randf_range(-1, 1)).normalized(), r_rng.randf() * TAU)
			var s := size * r_rng.randf_range(0.75, 1.25)
			var ax: Vector3 = b.x * s * 0.5
			var ay: Vector3 = b.y * s * 0.5
			var q := [c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for o: int in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[o]
				st.set_normal(((v - centre).normalized() * 0.7 + out * 0.3).normalized())
				st.set_uv(uv[o])
				st.add_vertex(v)
	return st.commit()


## Snow pine (tiered drooping skirts).
static func pine_mesh() -> ArrayMesh:
	if _mesh_cache.has("pine"):
		return _mesh_cache["pine"]
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
			var m0 := Vector3(cos(a0) * r * 0.95, y0 + 0.1, sin(a0) * r * 0.95)
			var m1 := Vector3(cos(a1) * r * 0.95, y0 + 0.1, sin(a1) * r * 0.95)
			for v: Vector3 in [p0, top, p1, m0, p0, p1, m0, p1, m1]:
				st.add_vertex(v)
	tube_into(st, [Vector3.ZERO, Vector3(0, 0.6, 0)], [0.15, 0.12], 5)
	st.generate_normals()
	var out := st.commit()
	_mesh_cache["pine"] = out
	return out


## Cypress / cone tree (blossom valley backdrop, castle grounds).
static func cypress_mesh() -> ArrayMesh:
	if _mesh_cache.has("cypress"):
		return _mesh_cache["cypress"]
	var out := lathe([Vector2(0.18, 0.0), Vector2(0.15, 0.7), Vector2(0.95, 1.0), Vector2(1.25, 2.4), Vector2(1.0, 4.2), Vector2(0.55, 5.6), Vector2(0.0, 6.6)], 9)
	_mesh_cache["cypress"] = out
	return out


## Grass tuft: 5 crossed tapering blades (UV.y = 0 at the tips, 1 at the root).
static func tuft_mesh(h: float = 0.45, w: float = 0.07) -> ArrayMesh:
	var key := "tuft%.2f_%.2f" % [h, w]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var lean := Vector3(cos(a), 0, sin(a)) * h * 0.35
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var base := Vector3(cos(a), 0, sin(a)) * 0.05
		var b0 := base - side
		var b1 := base + side
		var tip := base + lean + Vector3(0, h * (0.8 + 0.2 * float(k % 2)), 0)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(b0)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(b1)
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(tip)
	st.generate_normals()
	var out := st.commit()
	_mesh_cache[key] = out
	return out


# ================================================================== textures (generated, cached)
static func spark_tex() -> ImageTexture:
	if _tex_cache.has("spark"):
		return _tex_cache["spark"]
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := exp(-r * r * 9.0) + exp(-absf(u) * 22.0) * exp(-absf(v) * 3.0) * 0.6 + exp(-absf(v) * 22.0) * exp(-absf(u) * 3.0) * 0.6
			im.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	var t := ImageTexture.create_from_image(im)
	_tex_cache["spark"] = t
	return t


static func dot_tex() -> ImageTexture:
	if _tex_cache.has("dot"):
		return _tex_cache["dot"]
	var n := 32
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			im.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - sqrt(u * u + v * v), 0, 1) ** 1.5))
	var t := ImageTexture.create_from_image(im)
	_tex_cache["dot"] = t
	return t


## Maple-leaf / petal sprite (5 lobes, or a rounded petal when `petal`).
static func leaf_tex(petal: bool = false) -> ImageTexture:
	var key := "petal" if petal else "leaf"
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := 48
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var inside := 0.0
			if petal:
				inside = 1.0 if (u * u / 0.5 + v * v / 0.85) < 1.0 and not (v < -0.75 and absf(u) < 0.12) else 0.0
			else:
				var a := atan2(v, u) + PI * 0.5
				var lobes := 0.55 + 0.35 * pow(absf(cos(a * 2.5)), 3.0)
				inside = 1.0 if r < lobes and v < 0.75 else 0.0
				if absf(u) < 0.05 and v > 0.0 and v < 0.95:
					inside = 1.0
			var vein := 1.0 - 0.25 * exp(-absf(u) * 30.0)
			im.set_pixel(x, y, Color(vein, vein, vein, inside))
	var t := ImageTexture.create_from_image(im)
	_tex_cache[key] = t
	return t


# ================================================================== atmosphere
## Builds WorldEnvironment ("WorldEnvironment"), key light ("Sun") and a shadowless fill under `parent`.
## `over` overrides preset keys; "sky" sub-keys override anime_sky uniforms.
static func atmosphere(parent: Node, preset_name: String, over: Dictionary = {}) -> Dictionary:
	var p: Dictionary = (PRESETS[preset_name] as Dictionary).duplicate(true)
	for k: String in over:
		if k == "sky":
			(p["sky"] as Dictionary).merge(over["sky"], true)
		else:
			p[k] = over[k]
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	for k: String in p["sky"]:
		sm.set_shader_parameter(k, p["sky"][k])
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = float(p["sky_contrib"])
	e.ambient_light_color = p["ambient"]
	e.ambient_light_energy = float(p["ambient_energy"])
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = float(p["exposure"])
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = float(p["glow"])
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
	e.fog_light_color = p["fog_color"]
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.08
	e.fog_density = float(p["fog_density"])
	e.fog_aerial_perspective = float(p["fog_aerial"])
	e.fog_sky_affect = float(p["fog_sky"])
	e.fog_height = float(p["fog_height"])
	e.fog_height_density = float(p.get("fog_height_density", 0.006))
	if float(p["vfog"]) > 0.0:
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = float(p["vfog"])
		e.volumetric_fog_albedo = p["vfog_albedo"]
		e.volumetric_fog_emission = (p["vfog_emission"] as Color) * 0.02
		e.volumetric_fog_anisotropy = 0.3
		e.volumetric_fog_length = 64.0
		e.volumetric_fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = float(p["saturation"])
	e.adjustment_contrast = float(p["contrast"])
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = p["sun_color"]
	sun.light_energy = float(p["sun_energy"])
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 0.6
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	parent.add_child(sun)
	sun.basis = Basis.looking_at((p["sun_dir"] as Vector3).normalized(), Vector3.UP if absf((p["sun_dir"] as Vector3).normalized().y) < 0.99 else Vector3.FORWARD)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = p["fill_color"]
	fill.light_energy = float(p["fill_energy"])
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(fill)
	fill.basis = Basis.looking_at((p["fill_dir"] as Vector3).normalized(), Vector3.UP)
	return {"env": we, "sun": sun, "fill": fill}


## Matte-painted distant ranges on an inverted cylinder (radius < camera far 400).
func backdrop(params: Dictionary = {}, radius: float = 330.0) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 200.0
	cyl.radial_segments = 96
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = BACKDROP
	m.set_shader_parameter("h_scale", radius / 420.0)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	var mi := MeshInstance3D.new()
	mi.name = "PaintedBackdrop"
	mi.mesh = cyl
	mi.material_override = m
	mi.position = Vector3(0, -40.0 * radius / 420.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Distant 3D mountains (lathe cones) on an arc [a0, a1] (radians, 0 = +X, -PI/2 = -Z).
func mountains(mat: Material, count: int, a0: float, a1: float, dist: Vector2, height: Vector2, center: Vector3 = Vector3.ZERO, base_y: float = -8.0) -> void:
	for i in count:
		var a := lerpf(a0, a1, float(i) / maxf(1.0, count - 1)) + rng.randf_range(-0.1, 0.1)
		var d := rng.randf_range(dist.x, dist.y)
		var h := rng.randf_range(height.x, height.y)
		var pr: Array = []
		for q: Vector2 in [Vector2(1.0, 0.0), Vector2(0.7, 0.35), Vector2(0.38, 0.72), Vector2(0.0, 1.0)]:
			pr.append(Vector2(q.x * h * 1.3, q.y * h))
		add(lathe(pr, 7, 1.0, rng.randf_range(0.5, 0.9)), mat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), center + Vector3(cos(a) * d, base_y, sin(a) * d)), false)


## GPU particle box (snow, motes, embers, petals, leaves). `kind`: "dot" | "spark" | "leaf" | "petal".
func particles(at: Vector3, ext: Vector3, amount: int, life: float, col: Color, size: float, vel: Vector3, kind: String = "spark",
		energy: float = 0.6, gravity: float = 0.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Particles_" + kind
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = at
	p.fixed_fps = 30
	p.visibility_aabb = AABB(-ext * 1.5 - Vector3(0, life * absf(vel.y) + 2.0, 0), ext * 3.0 + Vector3(0, life * absf(vel.y) * 2.0 + 4.0, 0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = vel.normalized() if vel.length() > 0.001 else Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.3
	pm.gravity = Vector3(0, gravity, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var leafy := kind == "leaf" or kind == "petal"
	if leafy:
		pm.angle_min = 0
		pm.angle_max = 360
		pm.angular_velocity_min = -120
		pm.angular_velocity_max = 120
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (0.7 if leafy else 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = col
	if leafy:
		m.albedo_texture = leaf_tex(kind == "petal")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	else:
		m.albedo_texture = spark_tex() if kind == "spark" else dot_tex()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if energy > 1.0 else BaseMaterial3D.BLEND_MODE_MIX
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	return p


func omni(pos: Vector3, color: Color, energy: float, rng_m: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	root.add_child(l)
	return l
