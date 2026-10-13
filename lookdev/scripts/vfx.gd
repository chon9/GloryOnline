class_name LdVfx
extends Node3D
## Anime skill VFX for the slice (bible section 5):
##   1 "天击 Sky Strike" lance slash   - physical palette: white core / ice-white / blue, crescent + 2 echo arcs + smear
##   2 Launcher cannon blast            - gun palette: white-yellow / gold / orange-red; muzzle star, beam, fireball,
##                                        shockwave ring, radial streak burst, painted debris + puffy cel dust
##   3 Witch glyph circle + star bolts  - shadow/star palette: white / violet / blue-violet rotating rune circles
## Each effect is built from a few procedural shaders (vfx_*.gdshader) on simple meshes, driven by one
## `progress` value so a frame can be frozen exactly for screenshots, or tweened live with hit-stop.

const SLASH := preload("res://lookdev/shaders/vfx_slash.gdshader")
const GLYPH := preload("res://lookdev/shaders/vfx_glyph.gdshader")
const RING := preload("res://lookdev/shaders/vfx_ring.gdshader")
const ENERGY := preload("res://lookdev/shaders/vfx_energy.gdshader")
const IMPACT := preload("res://lookdev/shaders/screen_impact.gdshader")

const PHYS := [Color("#FFFFFF"), Color("#CFE6FF"), Color("#6FA8FF")]
const GUN := [Color("#FFF6C0"), Color("#FFC43A"), Color("#FF5A1F")]
const STAR := [Color("#EEE6FF"), Color("#8A4CFF"), Color("#6C7BFF")]

static var _spark: ImageTexture
static var _leaf: ImageTexture


## Maple leaf sprite (5 pointed lobes) for falling-leaf particles.
static func leaf_tex() -> ImageTexture:
	if _leaf:
		return _leaf
	var n := 48
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := atan2(v, u) + PI * 0.5
			var lobes := 0.55 + 0.35 * pow(absf(cos(a * 2.5)), 3.0)
			var inside := 1.0 if r < lobes and v < 0.75 else 0.0
			if absf(u) < 0.05 and v > 0.0 and v < 0.95:
				inside = 1.0
			var vein := 1.0 - 0.25 * exp(-absf(u) * 30.0)
			im.set_pixel(x, y, Color(vein, vein, vein, inside))
	_leaf = ImageTexture.create_from_image(im)
	return _leaf
var _live: Array[Node] = []
var impact_points: Dictionary = {}   # world points the HUD uses for damage numbers
var screen_fx: CanvasLayer


static func spark_tex() -> ImageTexture:
	if _spark:
		return _spark
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := exp(-r * r * 9.0) + exp(-absf(u) * 22.0) * exp(-absf(v) * 3.0) * 0.6 + exp(-absf(v) * 22.0) * exp(-absf(u) * 3.0) * 0.6
			im.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	_spark = ImageTexture.create_from_image(im)
	return _spark


func clear() -> void:
	for n in _live:
		if is_instance_valid(n):
			n.queue_free()
	_live.clear()


func _keep(n: Node) -> Node:
	add_child(n)
	_live.append(n)
	return n


## Build every effect of the combat frame at time `t` (0..1). Waits two frames so bone attachments
## (weapon tips, muzzles) have their posed transforms.
func combat_moment(chars: Dictionary, t: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	clear()
	var bm: LdCharacter = chars["battle_mage"]
	var la: LdCharacter = chars["launcher"]
	var wi: LdCharacter = chars["witch"]
	_slash(bm, t)
	_cannon(la, bm, t)
	_glyph(wi, la, t)


# ------------------------------------------------------------------ 1  lance slash

func _arc_mesh(r_in: float, r_out: float, a0: float, a1: float, seg := 48) -> ArrayMesh:
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
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(q[k])
	return st.commit()


func _vmat(shader: Shader, pal: Array, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("core", pal[0])
	m.set_shader_parameter("mid", pal[1])
	m.set_shader_parameter("accent", pal[2] if pal.size() > 2 else pal[1])
	if shader == ENERGY:
		m.set_shader_parameter("rim", pal[2] if pal.size() > 2 else pal[1].darkened(0.3))
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _slash(bm: LdCharacter, t: float) -> void:
	var f := bm.global_basis.z.normalized()
	var right := bm.global_basis.x.normalized()
	var c := bm.global_position + Vector3(0, 1.15, 0) + f * 0.35
	var tilt := deg_to_rad(-32.0)
	var e2 := (Vector3.UP * cos(tilt) + right * sin(tilt)).normalized()
	var basis := Basis(f, e2, f.cross(e2)).orthonormalized()
	for k in 3:
		var r := 2.15 - k * 0.22
		var arc := MeshInstance3D.new()
		arc.mesh = _arc_mesh(r * 0.58, r, deg_to_rad(115.0 - k * 6.0), deg_to_rad(-105.0 + k * 10.0))
		arc.material_override = _vmat(SLASH, [PHYS[0] if k == 0 else PHYS[1], PHYS[1] if k == 0 else Color("#8FB8F8"), Color("#3F7CF0")], {"progress": clampf(t - k * 0.07, 0.0, 1.0), "energy": 2.0 - k * 0.5, "alpha_mul": 1.0 - k * 0.35})
		arc.transform = Transform3D(basis.rotated(f, k * 0.05), c - f * k * 0.08)
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_keep(arc)
	# sparks where the lance tip is
	var lance: Node3D = bm.get_meta("weapon")
	var tip := lance.global_transform * Vector3(0, 2.0, 0)
	_spark_burst(tip, PHYS[1], 0.45, 5, t)
	impact_points["slash"] = c + f * 1.9


func _spark_burst(at: Vector3, col: Color, size: float, count: int, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 100.0)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = spark_tex()
	m.albedo_color = col * 1.3
	q.material = m
	var core := MeshInstance3D.new()
	core.mesh = q
	core.position = at
	core.scale = Vector3.ONE * 0.7
	_keep(core)
	for i in count:
		var s := MeshInstance3D.new()
		s.mesh = q
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		s.position = at + d * (0.2 + t * 1.2) * rng.randf_range(0.5, 1.0)
		s.scale = Vector3.ONE * rng.randf_range(0.1, 0.22)
		_keep(s)


# ------------------------------------------------------------------ 2  cannon blast

func _cannon(la: LdCharacter, bm: LdCharacter, t: float) -> void:
	var cannon: Node3D = la.get_meta("weapon")
	var muzzle := cannon.global_transform * Vector3(0, 0.95, -0.13)
	var to_la := (la.global_position - bm.global_position).normalized()
	var target := bm.global_position + to_la * 2.1 - to_la.cross(Vector3.UP) * 1.0
	target.y = LdEnvironment.ARENA_Y
	impact_points["blast"] = target + Vector3(0, 1.2, 0)
	# muzzle flash: bright star + small energy ball
	_spark_burst(muzzle, GUN[1], 1.2, 0, 0.0)
	var mf := MeshInstance3D.new()
	mf.mesh = LdGear.sphere(0.22, 16)
	mf.material_override = _vmat(ENERGY, GUN, {"energy": 2.5})
	mf.position = muzzle
	_keep(mf)
	# energy beam muzzle -> impact (a tapered tube, additive)
	var pts: Array = []
	var radii: Array = []
	for i in 9:
		var k := float(i) / 8.0
		pts.append(muzzle.lerp(target + Vector3(0, 0.4, 0), k))
		radii.append(lerpf(0.13, 0.06, k) * (0.6 + 0.4 * sin(k * PI)))
	var beam := MeshInstance3D.new()
	beam.mesh = LdGear.tube(pts, radii, 10)
	beam.material_override = _vmat(ENERGY, GUN, {"energy": 1.8, "alpha_mul": 0.8})
	_keep(beam)
	# fireball: additive painted flame tongues (white core -> yellow -> orange -> red edge) around a hot core,
	# HDR so bloom carries the glow (bible 5.1 "additive cores"); no flat opaque blobs
	var fire_tex: Texture2D = load("res://lookdev/assets/textures/fire_tongue.png")
	var frng := RandomNumberGenerator.new()
	frng.seed = 21
	var halo_m := StandardMaterial3D.new()
	halo_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	halo_m.albedo_texture = fire_tex
	halo_m.albedo_color = Color(1.1, 0.45, 0.15, 0.55)
	# soft additive fireball: radial-gradient sprites (white-hot core -> yellow -> orange -> transparent red),
	# layered big-to-small so the centre burns out to white under bloom; the painted tongues are additive only
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 128
	soft.height = 128
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	g.colors = PackedColorArray([Color(1, 0.98, 0.9, 1), Color(1, 0.86, 0.45, 0.9), Color(1, 0.5, 0.12, 0.5), Color(0.85, 0.15, 0.05, 0.16), Color(0.5, 0.05, 0.0, 0.0)])
	soft.gradient = g
	var soft_m := StandardMaterial3D.new()
	soft_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soft_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soft_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	soft_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	soft_m.albedo_texture = soft
	for i in 9:
		var sz := (1.9 if i == 0 else frng.randf_range(0.7, 1.2)) * lerpf(0.7, 1.15, t)
		var a := TAU * i / 9.0
		var rr := 0.0 if i == 0 else frng.randf_range(0.4, 1.0) * lerpf(0.6, 1.2, t)
		var sq := QuadMesh.new()
		sq.size = Vector2(sz, sz)
		var sm := soft_m.duplicate() as StandardMaterial3D
		sm.albedo_color = Color(1.4, 1.0, 0.7, 0.75) if i == 0 else Color(1.0, 0.5, 0.2, 0.4)
		sq.material = sm
		var sp := MeshInstance3D.new()
		sp.mesh = sq
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = target + Vector3(cos(a) * rr, 0.7 + frng.randf_range(-0.1, 0.5), sin(a) * rr)
		_keep(sp)
	for i in 12:
		# rising additive flame tongues licking out of the fireball (no alpha-scissor cut-outs)
		var sz := frng.randf_range(0.5, 1.1) * lerpf(0.7, 1.15, t)
		var a := TAU * i / 12.0 + frng.randf_range(-0.2, 0.2)
		var rr := frng.randf_range(0.35, 1.05) * lerpf(0.6, 1.2, t)
		var fq := QuadMesh.new()
		fq.size = Vector2(sz * 0.75, sz)
		fq.center_offset = Vector3(0, sz * 0.4, 0)
		fq.material = halo_m
		var fp := MeshInstance3D.new()
		fp.mesh = fq
		fp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fp.position = target + Vector3(cos(a) * rr, frng.randf_range(0.1, 0.6), sin(a) * rr)
		_keep(fp)
	var core := MeshInstance3D.new()
	core.mesh = LdGear.sphere(0.2, 16)
	core.material_override = LdGear.glow(Color("#FFF4C2"), 3.0, true, 0.8)
	core.position = target + Vector3(0, 0.6, 0)
	_keep(core)
	# ground shockwave ring
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.5, 6.5)
	ring.mesh = pm
	ring.material_override = _vmat(RING, GUN, {"radius": lerpf(0.35, 0.92, t), "width": 0.22, "energy": 1.6})
	ring.position = target + Vector3(0, 0.04, 0)
	_keep(ring)
	# camera-facing radial streak burst
	var burst := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(3.6, 3.6)
	burst.mesh = bq
	var bmat := _vmat(RING, GUN, {"radius": 0.62, "width": 0.0, "energy": 1.6, "rays": 2.2})
	burst.material_override = bmat
	burst.position = target + Vector3(0, 0.9, 0)
	_keep(burst)
	burst.set_meta("billboard", true)
	# painted debris shards (cel shaded + outline) and puffy dust
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# painted debris: jagged extruded rock chips, warm fire-lit face / cool violet shade / orange rim + outline,
	# each dragging a short additive streak along its flight direction
	# angular dark stone: flat-shaded faceted shards (no bevel, no smooth normals), cool violet shade, hot orange rim
	var rock := LdGear.toon(Color("#3A3440"), {"shade": Color(0.42, 0.38, 0.62), "rim": Color(1.0, 0.5, 0.15), "rim_strength": 2.6, "line": 1.4, "darken": 0.25, "band_soft": 0.02})
	var streak := LdGear.glow(Color("#FFC43A"), 1.6, true, 0.4)
	for i in 16:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.6), rng.randf_range(-1, 1)).normalized()
		var dist := (0.6 + t * 3.2) * rng.randf_range(0.6, 1.1)
		var p := target + d * dist + Vector3(0, -0.5 * t * t * 2.0, 0)
		var poly := PackedVector2Array()
		var nv := rng.randi_range(5, 7)
		var rs := rng.randf_range(0.1, 0.24)
		for k in nv:
			var aa := TAU * k / nv + rng.randf_range(-0.3, 0.3)
			poly.append(Vector2(cos(aa), sin(aa)) * rs * rng.randf_range(0.55, 1.15))
		var sh := MeshInstance3D.new()
		sh.mesh = _shard_mesh(rng, rs)
		sh.material_override = rock
		sh.transform = Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)), p)
		_keep(sh)
		var tr := MeshInstance3D.new()
		tr.mesh = LdGear.tube([p - d * (0.4 + t * 0.9), p - d * rs], [0.002, rs * 0.12], 6)
		tr.material_override = streak
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_keep(tr)
	# ground smoke: soft dark warm-brown sprites hugging the floor (alpha-blended, so they darken the bright
	# snow), each with a smaller additive ember-orange glow on the side facing the fireball
	var smoke_m := StandardMaterial3D.new()
	smoke_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_m.albedo_texture = soft
	smoke_m.albedo_color = Color(0.16, 0.1, 0.08, 0.75)
	var ember_m := soft_m.duplicate() as StandardMaterial3D
	ember_m.albedo_color = Color(0.9, 0.3, 0.08, 0.35)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var rr := lerpf(0.9, 2.1, t) * rng.randf_range(0.8, 1.1)
		var p := target + Vector3(cos(a) * rr, 0.35 + rng.randf() * 0.25, sin(a) * rr)
		var s := rng.randf_range(1.3, 2.0) * lerpf(0.6, 1.2, t)
		for layer in 2:
			var q := QuadMesh.new()
			q.size = Vector2(s, s * 0.8) * (1.0 if layer == 0 else 0.55)
			q.material = smoke_m if layer == 0 else ember_m
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = p if layer == 0 else p.lerp(target + Vector3(0, 0.5, 0), 0.3)
			_keep(mi)
	var om := OmniLight3D.new()
	om.light_color = Color("#FFB04A")
	om.light_energy = 1.6
	om.omni_range = 5.5
	om.position = target + Vector3(0, 1.0, 0)
	_keep(om)


# ------------------------------------------------------------------ 3  witch glyph circle

func _glyph(wi: LdCharacter, bm: LdCharacter, t: float) -> void:   # bm = the bolts' target
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.4, 4.4)
	g.mesh = pm
	g.material_override = _vmat(GLYPH, STAR, {"reveal": clampf(t * 1.6, 0.25, 1.0), "energy": 2.8})
	g.position = wi.global_position + Vector3(0, 0.03, 0)
	_keep(g)
	# vertical casting circle in front of the casting hand, facing the target
	var hand := wi.skeleton.global_transform * wi.skeleton.get_bone_global_pose(wi.skeleton.find_bone("RightHand")).origin
	var to := (bm.global_position + Vector3(0, 1.2, 0) - hand).normalized()
	var v := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.9, 1.9)
	v.mesh = q
	v.material_override = _vmat(GLYPH, STAR, {"reveal": 1.0, "energy": 1.8, "spin": -0.6})
	v.global_transform = Transform3D(Basis.looking_at(-to, Vector3.UP), hand + to * 0.45)
	_keep(v)
	# star bolts flying toward the Battle Mage
	for i in 3:
		var k := clampf(t * 0.8 + i * 0.13, 0.0, 1.0)
		var p := hand.lerp(bm.global_position + Vector3(0, 1.3, 0), k * 0.75) + Vector3(0, sin(k * PI) * 0.6 * (i - 1), 0)
		var b := MeshInstance3D.new()
		b.mesh = LdGear.sphere(0.11, 12)
		b.material_override = _vmat(ENERGY, [STAR[0], STAR[1]], {"energy": 2.2})
		b.position = p
		_keep(b)
		var trail: Array = []
		var tr: Array = []
		for j in 7:
			var kk := maxf(k - j * 0.04, 0.0)
			trail.append(hand.lerp(bm.global_position + Vector3(0, 1.3, 0), kk * 0.75) + Vector3(0, sin(kk * PI) * 0.6 * (i - 1), 0))
			tr.append(lerpf(0.07, 0.01, j / 6.0))
		var tm := MeshInstance3D.new()
		tm.mesh = LdGear.tube(trail, tr, 8)
		tm.material_override = _vmat(ENERGY, [STAR[1], STAR[2]], {"energy": 1.4, "alpha_mul": 0.6})
		_keep(tm)
	var om := OmniLight3D.new()
	om.light_color = Color("#8A6CFF")
	om.light_energy = 3.0
	om.omni_range = 5.0
	om.position = wi.global_position + Vector3(0, 0.6, 0)
	_keep(om)
	impact_points["glyph"] = wi.global_position + Vector3(0.0, 2.3, 0)


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for n in _live:
		if is_instance_valid(n) and n.has_meta("billboard"):
			var m := n as Node3D
			m.global_basis = Basis.looking_at(cam.global_position - m.global_position, Vector3.UP).rotated(Vector3.UP, 0) * Basis(Vector3.UP, PI)


# ------------------------------------------------------------------ impact frame + live sequence

func impact_frame(cam: Camera3D, world: Vector3, tint: Color, strength := 1.0) -> void:
	if screen_fx == null:
		screen_fx = CanvasLayer.new()
		screen_fx.layer = 5
		add_child(screen_fx)
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = IMPACT
		r.material = m
		screen_fx.add_child(r)
	var rect := screen_fx.get_child(0) as ColorRect
	var vp := get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(world)
	var m2 := rect.material as ShaderMaterial
	m2.set_shader_parameter("focus", sp / vp)
	m2.set_shader_parameter("tint", tint)
	m2.set_shader_parameter("flash", 0.12 * strength)
	m2.set_shader_parameter("lines", 0.3 * strength)
	screen_fx.visible = true


func hide_impact() -> void:
	if screen_fx:
		screen_fx.visible = false


## Live demo: anticipation -> slash/blast -> impact frame + hit-stop (8 f heavy) -> follow-through dissolve.
func play_sequence(chars: Dictionary) -> void:
	var cam := get_viewport().get_camera_3d()
	for c in chars.values():
		(c as LdCharacter).play((c as LdCharacter).cfg["skill"], 0.1, 1.0, false)
	var t := 0.0
	var stopped := false
	while t < 1.0:
		await combat_moment(chars, t)
		if t > 0.42 and not stopped:
			stopped = true
			# hit-stop: freeze the fighters for 8 frames, VFX keep animating, impact frame on screen
			for c in chars.values():
				(c as LdCharacter).anim.speed_scale = 0.0
			impact_frame(cam, impact_points.get("blast", Vector3.ZERO), Color(1.0, 0.85, 0.6))
			for i in 8:
				await get_tree().process_frame
			hide_impact()
			for c in chars.values():
				(c as LdCharacter).anim.speed_scale = 1.0
		t += get_process_delta_time() * 1.6
	clear()
	for c in chars.values():
		(c as LdCharacter).play((c as LdCharacter).cfg["idle"])


## a flat-shaded angular stone shard: two apexes along the long axis around an irregular 5-point waist.
## Every triangle keeps its own face normal, so the toon ramp gives hard planar facets, not rounded lumps.
static func _shard_mesh(rng: RandomNumberGenerator, rs: float) -> ArrayMesh:
	var a := Vector3(rs * rng.randf_range(1.0, 1.6), rng.randf_range(-0.2, 0.2) * rs, 0)
	var b := Vector3(-rs * rng.randf_range(0.6, 1.0), rng.randf_range(-0.2, 0.2) * rs, 0)
	var waist: Array[Vector3] = []
	for k in 5:
		var ang := TAU * k / 5.0 + rng.randf_range(-0.35, 0.35)
		var r := rs * rng.randf_range(0.45, 0.85)
		waist.append(Vector3(rng.randf_range(-0.25, 0.25) * rs, cos(ang) * r, sin(ang) * r * 0.7))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for k in 5:
		var p0 := waist[k]
		var p1 := waist[(k + 1) % 5]
		st.add_vertex(a)
		st.add_vertex(p1)
		st.add_vertex(p0)
		st.add_vertex(b)
		st.add_vertex(p0)
		st.add_vertex(p1)
	st.generate_normals()
	return st.commit()
