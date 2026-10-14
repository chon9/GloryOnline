class_name VfxLib
extends RefCounted
## Shared building blocks for the anime VFX (bible section 5), ported from lookdev/scripts/vfx.gd (LdVfx):
## element palettes (bible 5.2), shared shader materials (every per-effect value is an instance uniform, so one
## material per shader serves every effect and batches well), procedural meshes (crescent arcs, flat-shaded
## shards, crystals, tubes, shuriken stars) and the damage-number fonts. Everything is cached statically.

const SPRITE := preload("res://visuals/shaders/vfx_sprite.gdshader")
const SLASH := preload("res://visuals/shaders/vfx_slash.gdshader")
const GLYPH := preload("res://visuals/shaders/vfx_glyph.gdshader")
const RING := preload("res://visuals/shaders/vfx_ring.gdshader")
const ENERGY := preload("res://visuals/shaders/vfx_energy.gdshader")
const GROUND := preload("res://visuals/shaders/vfx_ground.gdshader")
const TRAIL := preload("res://visuals/shaders/vfx_trail.gdshader")
const SOLID := preload("res://visuals/shaders/vfx_solid.gdshader")
const OUTLINE := preload("res://visuals/shaders/vfx_outline.gdshader")
const IMPACT := preload("res://visuals/shaders/screen_impact.gdshader")

## vfx_sprite kinds
enum { K_SPARK, K_GLOW, K_STREAK, K_PUFF, K_FLAME, K_SHARD, K_PLUS, K_BUBBLE, K_MOTE, K_RING, K_HEX, K_LEAF, K_CHIP }
## vfx_glyph styles
enum { G_ARCANE, G_HOLY, G_DARK, G_NATURE, G_FIRE, G_ICE, G_LIGHTNING, G_QI }
## vfx_ground styles (same order as Fx.AREA_VISUALS)
const GROUND_STYLE: Dictionary = {"fire": 0, "ice": 1, "lightning": 2, "holy": 3, "dark": 4, "poison": 5, "wind": 6,
	"earth": 7, "blood": 8, "rune": 9, "thorn": 10}

## Element palettes: [core, mid, accent] (bible 5.2). Painted puffs use [highlight, body, shadow].
const PAL: Dictionary = {
	"phys": [Color("#FFFFFF"), Color("#CFE6FF"), Color("#6FA8FF")],
	"impact": [Color("#FFFFFF"), Color("#FFE6A8"), Color("#FF9A3C")],
	"fire": [Color("#FFF4C2"), Color("#FF8A1F"), Color("#D2283A")],
	"ice": [Color("#FFFFFF"), Color("#7FE8FF"), Color("#2F9BFF")],
	"lightning": [Color("#FFFFFF"), Color("#B8F0FF"), Color("#7A5CFF")],
	"dark": [Color("#E8D8FF"), Color("#8A4CFF"), Color("#2A0F4A")],
	"holy": [Color("#FFFBE6"), Color("#FFD86A"), Color("#7CF0A0")],
	"heal": [Color("#F4FFE8"), Color("#7CF0A0"), Color("#FFD86A")],
	"poison": [Color("#EFFFD6"), Color("#7CFF6B"), Color("#3A6B1F")],
	"qi": [Color("#FFFFFF"), Color("#7FC4FF"), Color("#9FFFE6")],
	"gun": [Color("#FFF6C0"), Color("#FFC43A"), Color("#FF5A1F")],
	"umbrella": [Color("#FFFFFF"), Color("#E0232E"), Color("#F2E6CF")],
	"arcane": [Color("#EEE6FF"), Color("#8A4CFF"), Color("#6C7BFF")],
	"blood": [Color("#FFE0E0"), Color("#E0232E"), Color("#5A0812")],
	"earth": [Color("#FFE9C2"), Color("#C08A4A"), Color("#5A3A22")],
	"wind": [Color("#FFFFFF"), Color("#B8FFE0"), Color("#4FD8B0")],
	"thorn": [Color("#F0FFD0"), Color("#7CCB3A"), Color("#2F5A1A")],
	"buff": [Color("#FFFBE6"), Color("#FFC43A"), Color("#FF8A1F")],
	"dust": [Color("#FFFFFF"), Color("#E9E2D6"), Color("#AFA9B8")],
	"smoke": [Color("#F4F4F8"), Color("#B8B8C6"), Color("#6E6E80")],
	"darksmoke": [Color("#8A6AA8"), Color("#3E2A58"), Color("#1A0F26")],
	"poisonsmoke": [Color("#E2FFB8"), Color("#86C95A"), Color("#456E3E")],
	"firesmoke": [Color("#9A7A6A"), Color("#5A4440"), Color("#2A2026")],
	"frost": [Color("#FFFFFF"), Color("#D8F4FF"), Color("#7FB8E8")],
	"trailsmoke": [Color("#FFFFFF"), Color("#ECECF2"), Color("#C2C2D0")],
}

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _pal_cache: Dictionary = {}
static var _fonts: Dictionary = {}


## Palette for a caller colour: Color.WHITE means "use the element default".
static func pal(c: Color, default_key: String) -> Array:
	if c == Color.WHITE:
		return PAL[default_key]
	return pal_from(c)


## Derives a bible-style 3 colour ramp (white-hot core, the colour, a deeper hue-shifted accent) from one colour.
static func pal_from(c: Color) -> Array:
	var k := c.to_html()
	if _pal_cache.has(k):
		return _pal_cache[k]
	var mid := Color(c.r, c.g, c.b, 1.0)
	var core := mid.lerp(Color.WHITE, 0.82)
	var acc := Color.from_hsv(fposmod(mid.h + 0.05, 1.0), clampf(mid.s * 1.15 + 0.1, 0.0, 1.0), mid.v * 0.62)
	var p := [core, mid, acc]
	if _pal_cache.size() > 256:
		_pal_cache.clear()
	_pal_cache[k] = p
	return p


# ------------------------------------------------------------------ materials (shared)

static func sprite_mat(kind: int, bb := 0, particles := false) -> ShaderMaterial:
	var k := "spr_%d_%d_%s" % [kind, bb, particles]
	if _mats.has(k):
		return _mats[k]
	var m := ShaderMaterial.new()
	m.shader = SPRITE
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("bb", bb)
	m.set_shader_parameter("particles", particles)
	_mats[k] = m
	return m


static func shader_mat(shader: Shader, key: String, params := {}) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = shader
	for p in params:
		m.set_shader_parameter(p, params[p])
	_mats[key] = m
	return m


static func slash_mat() -> ShaderMaterial:
	return shader_mat(SLASH, "slash")


static func glyph_mat(billboard := false) -> ShaderMaterial:
	return shader_mat(GLYPH, "glyph_%s" % billboard, {"bb": billboard})


static func ring_mat(billboard := false) -> ShaderMaterial:
	return shader_mat(RING, "ring_%s" % billboard, {"bb": billboard})


static func energy_mat() -> ShaderMaterial:
	return shader_mat(ENERGY, "energy")


static func ground_mat() -> ShaderMaterial:
	return shader_mat(GROUND, "ground")


static func trail_mat() -> ShaderMaterial:
	return shader_mat(TRAIL, "trail")


## Cel solid + inverted-hull outline (next pass). Colours are instance uniforms (tint/shade/rim_col).
static func solid_mat(outline := true) -> ShaderMaterial:
	var k := "solid_%s" % outline
	if _mats.has(k):
		return _mats[k]
	var m := ShaderMaterial.new()
	m.shader = SOLID
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", 0.022)
		m.next_pass = o
	_mats[k] = m
	return m


## Sets the [core, mid, accent] instance uniforms on a geometry instance.
static func set_pal(g: GeometryInstance3D, p: Array) -> void:
	g.set_instance_shader_parameter(&"core", p[0])
	g.set_instance_shader_parameter(&"mid", p[1])
	g.set_instance_shader_parameter(&"accent", p[2] if p.size() > 2 else p[1])


static func set_solid(g: GeometryInstance3D, base: Color, shade: Color, rim: Color, rim_strength := 1.5, glow := 0.0) -> void:
	g.set_instance_shader_parameter(&"tint", base)
	g.set_instance_shader_parameter(&"shade", shade)
	g.set_instance_shader_parameter(&"rim_col", rim)
	g.set_instance_shader_parameter(&"rim_strength", rim_strength)
	g.set_instance_shader_parameter(&"glow", glow)
	g.set_instance_shader_parameter(&"fade", 1.0)


# ------------------------------------------------------------------ meshes (shared)

static func quad(w := 1.0, h := 1.0) -> QuadMesh:
	var k := "quad_%.3f_%.3f" % [w, h]
	if not _meshes.has(k):
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		_meshes[k] = q
	return _meshes[k]


static func plane() -> PlaneMesh:
	if not _meshes.has("plane"):
		var p := PlaneMesh.new()
		p.size = Vector2.ONE
		_meshes["plane"] = p
	return _meshes["plane"]


## Particle quad with its material baked in (CPUParticles3D draws `mesh` with the mesh material).
static func particle_quad(kind: int, bb := 0, w := 1.0, h := 1.0) -> QuadMesh:
	var k := "pq_%d_%d_%.2f_%.2f" % [kind, bb, w, h]
	if not _meshes.has(k):
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		q.material = sprite_mat(kind, bb, true)
		_meshes[k] = q
	return _meshes[k]


static func sphere(r := 0.5, seg := 16) -> SphereMesh:
	var k := "sph_%.3f_%d" % [r, seg]
	if not _meshes.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = maxi(seg / 2, 4)
		_meshes[k] = s
	return _meshes[k]


## Open cylinder (pillars, blink slit): unit radius 0.5, height 1, UV.y 0..1 along the height.
static func cylinder() -> CylinderMesh:
	if not _meshes.has("cyl"):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 20
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_meshes["cyl"] = c
	return _meshes["cyl"]


static func cone(sides := 6) -> CylinderMesh:
	var k := "cone_%d" % sides
	if not _meshes.has(k):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = sides
		c.rings = 1
		_meshes[k] = c
	return _meshes[k]


## Crescent band in the XY plane (UV.x along the arc, UV.y inner -> outer), as LdVfx._arc_mesh.
static func arc(r_in: float, r_out: float, a0: float, a1: float, seg := 40) -> ArrayMesh:
	var k := "arc_%.2f_%.2f_%.2f_%.2f" % [r_in, r_out, a0, a1]
	if _meshes.has(k):
		return _meshes[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		var t0 := lerpf(a0, a1, u0)
		var t1 := lerpf(a0, a1, u1)
		var q := [Vector3(cos(t0) * r_in, sin(t0) * r_in, 0), Vector3(cos(t0) * r_out, sin(t0) * r_out, 0),
			Vector3(cos(t1) * r_out, sin(t1) * r_out, 0), Vector3(cos(t1) * r_in, sin(t1) * r_in, 0)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[j])
			st.add_vertex(q[j])
	var m := st.commit()
	_meshes[k] = m
	return m


## Flat-shaded angular stone shard (LdVfx._shard_mesh): two apexes around an irregular 5-point waist. A few
## variants are cached; `variant` picks one.
static func shard(variant: int) -> ArrayMesh:
	var k := "shard_%d" % (variant % 6)
	if _meshes.has(k):
		return _meshes[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + variant % 6
	var rs := 0.5
	var a := Vector3(rs * rng.randf_range(1.0, 1.6), rng.randf_range(-0.2, 0.2) * rs, 0)
	var b := Vector3(-rs * rng.randf_range(0.6, 1.0), rng.randf_range(-0.2, 0.2) * rs, 0)
	var waist: Array[Vector3] = []
	for i in 5:
		var ang := TAU * i / 5.0 + rng.randf_range(-0.35, 0.35)
		var r := rs * rng.randf_range(0.45, 0.85)
		waist.append(Vector3(rng.randf_range(-0.25, 0.25) * rs, cos(ang) * r, sin(ang) * r * 0.7))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 5:
		var p0 := waist[i]
		var p1 := waist[(i + 1) % 5]
		st.add_vertex(a)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(b)
		st.add_vertex(p1)
		st.add_vertex(p0)
	st.generate_normals()
	var m := st.commit()
	_meshes[k] = m
	return m


## Ice / thorn crystal: a faceted spike, base at y = 0, tip at y = 1, flat-shaded.
static func crystal(sides := 5, variant := 0) -> ArrayMesh:
	var k := "crys_%d_%d" % [sides, variant % 4]
	if _meshes.has(k):
		return _meshes[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = 211 + variant % 4 + sides * 7
	var tip := Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08))
	var ring_lo: Array[Vector3] = []
	var ring_hi: Array[Vector3] = []
	for i in sides:
		var ang := TAU * i / sides + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(0.16, 0.24)
		ring_lo.append(Vector3(cos(ang) * r, 0.0, sin(ang) * r))
		ring_hi.append(Vector3(cos(ang) * r * 0.85, 0.62 + rng.randf_range(-0.06, 0.06), sin(ang) * r * 0.85))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in sides:
		var j := (i + 1) % sides
		st.add_vertex(ring_lo[i])
		st.add_vertex(ring_lo[j])
		st.add_vertex(ring_hi[j])
		st.add_vertex(ring_lo[i])
		st.add_vertex(ring_hi[j])
		st.add_vertex(ring_hi[i])
		st.add_vertex(ring_hi[i])
		st.add_vertex(ring_hi[j])
		st.add_vertex(tip)
	st.generate_normals()
	var m := st.commit()
	_meshes[k] = m
	return m


## 4-point throwing star in the XZ plane (shuriken), flat-shaded with a bevel ridge.
static func star4() -> ArrayMesh:
	if _meshes.has("star4"):
		return _meshes["star4"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var top := Vector3(0, 0.06, 0)
	var bot := Vector3(0, -0.06, 0)
	var pts: Array[Vector3] = []
	for i in 8:
		var ang := TAU * i / 8.0
		var r := 0.5 if i % 2 == 0 else 0.13
		pts.append(Vector3(cos(ang) * r, 0, sin(ang) * r))
	for i in 8:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % 8]
		st.add_vertex(top)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(bot)
		st.add_vertex(p1)
		st.add_vertex(p0)
	st.generate_normals()
	var m := st.commit()
	_meshes["star4"] = m
	return m


## Tapered tube along a polyline (LdGear.tube), UV.y along the path. Not cached (callers build bolts once).
static func tube(pts: Array, radii: Array, seg := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var rings: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var fwd: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = fwd.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(fwd).normalized()
		var ring: Array = []
		for k in seg + 1:
			var a := TAU * k / seg
			ring.append(p + (side * cos(a) + up * sin(a)) * float(radii[i]))
		rings.append(ring)
	for i in n - 1:
		for k in seg:
			var v := float(i) / (n - 1)
			var v2 := float(i + 1) / (n - 1)
			var quad_pts := [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]]
			var uvs := [Vector2(float(k) / seg, v), Vector2(float(k) / seg, v2), Vector2(float(k + 1) / seg, v2), Vector2(float(k + 1) / seg, v)]
			var c0: Vector3 = pts[i]
			var c1: Vector3 = pts[i + 1]
			var centres := [c0, c1, c1, c0]
			for j in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uvs[j])
				st.set_normal(((quad_pts[j] as Vector3) - (centres[j] as Vector3)).normalized())
				st.add_vertex(quad_pts[j])
	return st.commit()


# ------------------------------------------------------------------ fonts (bible 5.5)

## Bold condensed numerals: Teko (UI track, assets/fonts) with Russo One and Noto Sans SC (CJK tags) as
## fallbacks; falls back to a system font when the files are missing.
static func number_font(kind := "num") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var cjk := _load_font(["res://assets/fonts/notosanssc/NotoSansSC[wght].ttf"])
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	sys.font_weight = 800
	var f: Font = null
	if kind == "tag":
		var russo := _load_font(["res://assets/fonts/russoone/RussoOne-Regular.ttf"])
		if russo:
			f = russo
	else:
		var teko := _load_font(["res://assets/fonts/teko/Teko[wght].ttf", "res://assets/fonts/teko/Teko-SemiBold.ttf", "res://assets/fonts/teko/Teko-Bold.ttf"])
		if teko:
			var fv := FontVariation.new()
			fv.base_font = teko
			fv.variation_opentype = {"wght": 640}
			f = fv
	if cjk:
		var cv := FontVariation.new()
		cv.base_font = cjk
		cv.variation_opentype = {"wght": 800}
		cjk = cv
	if f == null:
		f = sys
	var fb: Array[Font] = []
	if cjk:
		fb.append(cjk)
	if f != sys:
		fb.append(sys)
	if f is FontVariation:
		(f as FontVariation).fallbacks = fb
	elif f is FontFile:
		(f as FontFile).fallbacks = fb
	_fonts[kind] = f
	return f


static func _load_font(paths: Array) -> Font:
	for p: String in paths:
		if ResourceLoader.exists(p):
			var r: Variant = load(p)
			if r is Font:
				return r
		if FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				return ff
	return null
