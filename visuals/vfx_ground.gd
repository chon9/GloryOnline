class_name VfxGround
extends RefCounted
## Ground-zone visuals for Fx.spawn_area_visual (11 elements x circle / line / ring). The zone and the
## telegraph are one plane with vfx_ground.gdshader (element pattern / readable warning); elements add
## glyph circles, cel crystals and rock spikes, flame tongues, puffs and periodic accents. `a` is Fx's AreaVis.

const Lib := preload("res://visuals/vfx_lib.gd")
const Effects := preload("res://visuals/vfx_effects.gd")

## Default zone colours (bible 5.2 mid colours); Fx.AREA_COLORS mirrors this.
const ELEMENT_PAL: Dictionary = {
	"fire": "fire", "ice": "ice", "lightning": "lightning", "holy": "holy", "dark": "dark", "poison": "poison",
	"wind": "wind", "earth": "earth", "blood": "blood", "rune": "arcane", "thorn": "thorn",
}


static func pal_for(a: Node3D) -> Array:
	var v: String = a.get("visual")
	var c: Color = a.get("color")
	var base: Array = Lib.PAL[ELEMENT_PAL.get(v, "arcane")]
	if c.is_equal_approx(base[1]):
		return base
	return Lib.pal_from(c)


## Flat zone / telegraph plane (child of the area). Shader instance params: tint, shape, inner, telegraph,
## progress, alpha, style, size, seed.
static func shape_mesh(a: Node3D, c: Color, alpha: float, is_telegraph: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.plane()
	var shape: String = a.get("shape")
	var sz := Vector2(float(a.get("width")), float(a.get("length"))) if shape == "line" else Vector2.ONE * float(a.get("radius")) * 2.0
	mi.scale = Vector3(sz.x, 1.0, sz.y)
	mi.material_override = Lib.ground_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a.call("line_center") as Vector3) + Vector3(0, 0.05 if is_telegraph else 0.03, 0)
	mi.set_instance_shader_parameter(&"tint", c)
	mi.set_instance_shader_parameter(&"shape", 1.0 if shape == "line" else (2.0 if shape == "ring" else 0.0))
	mi.set_instance_shader_parameter(&"inner", 0.55)
	mi.set_instance_shader_parameter(&"telegraph", 1.0 if is_telegraph else 0.0)
	mi.set_instance_shader_parameter(&"progress", 0.0 if is_telegraph else 1.0)
	mi.set_instance_shader_parameter(&"alpha", alpha)
	mi.set_instance_shader_parameter(&"style", float(Lib.GROUND_STYLE.get(a.get("visual"), 9)))
	mi.set_instance_shader_parameter(&"size", sz)
	mi.set_instance_shader_parameter(&"seed", randf() * 20.0)
	a.add_child(mi)
	return mi


static func emit_cfg(a: Node3D) -> Dictionary:
	var shape: String = a.get("shape")
	var r := float(a.get("radius"))
	if shape == "line":
		return {"shape": "box", "box": Vector3(float(a.get("width")) * 0.5, 0.05, float(a.get("length")) * 0.5)}
	if shape == "ring":
		return {"shape": "ring", "radius": r, "inner": r * 0.55}
	return {"shape": "ring", "radius": r * 0.95, "inner": 0.0}


static func area_size(a: Node3D) -> float:
	if String(a.get("shape")) == "line":
		return float(a.get("width")) * float(a.get("length"))
	return PI * pow(float(a.get("radius")), 2.0)


## Glyph circle lying on the zone (spins in the shader; fades with the zone through `decals`).
static func _glyph_decal(a: Node3D, pal: Array, style: int, spin: float, size_k := 1.0) -> void:
	if String(a.get("shape")) == "line":
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.plane()
	mi.material_override = Lib.glyph_mat(false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := float(a.get("radius")) * 2.0 * size_k
	mi.scale = Vector3(d, 1.0, d)
	mi.position = Vector3(0, 0.07, 0)
	Lib.set_pal(mi, pal)
	for k in [[&"energy", 2.2], [&"spin", spin], [&"reveal", 1.0], [&"fade", 0.0], [&"style", float(style)], [&"seed", randf()]]:
		mi.set_instance_shader_parameter(k[0], k[1])
	a.add_child(mi)
	(a.get("decals") as Array).append(mi)


## Called when the zone becomes active (after the telegraph).
static func start(fx: Node, a: Node3D) -> void:
	var visual: String = a.get("visual")
	var pal := pal_for(a)
	var persistent := float(a.get("duration")) > 0.0
	var base := emit_cfg(a)
	var dens := clampf(area_size(a) / 12.0, 0.6, 3.0)
	var center: Vector3 = a.call("line_center")
	var cfg := {}
	match visual:
		"fire":
			cfg = {"kind": Lib.K_FLAME, "amount": int(18 * dens), "life": 0.7, "speed": [1.2, 3.0], "dir": Vector3.UP, "spread": 10.0,
				"size": 0.9, "pal": pal, "energy": 2.6, "gravity": Vector3(0, 2, 0), "curve": "shrink", "upright": true}
		"ice":
			cfg = {"kind": Lib.K_PUFF, "amount": int(8 * dens), "life": 1.2, "speed": [0.3, 0.8], "dir": Vector3.UP, "spread": 30.0,
				"size": 0.9, "pal": Lib.PAL["frost"], "energy": 1.1, "curve": "pop", "ramp": "pop"}
			_spikes(fx, a, "ice", pal, int(8 * dens), 1.1)
		"lightning":
			cfg = {"kind": Lib.K_STREAK, "amount": int(16 * dens), "life": 0.22, "speed": [1.0, 4.0], "dir": Vector3.UP, "spread": 70.0,
				"size": 0.45, "pal": pal, "energy": 3.5, "align": true, "quad": Vector2(0.12, 1.0), "curve": "shrink"}
			_glyph_decal(a, pal, Lib.G_LIGHTNING, 2.0)
		"holy":
			cfg = {"kind": Lib.K_MOTE, "amount": int(16 * dens), "life": 1.2, "speed": [1.0, 2.4], "dir": Vector3.UP, "spread": 8.0,
				"size": 0.26, "pal": pal, "energy": 3.0, "curve": "pop"}
			_glyph_decal(a, pal, Lib.G_HOLY, 0.6)
			if String(a.get("shape")) != "line":
				var col: VfxFlash = Effects._column(fx, a.global_position, pal, 0.6 if not persistent else 0.9, float(a.get("radius")) * 0.3, 6.0)
				col.fade_tail = 0.8
		"dark":
			cfg = {"kind": Lib.K_FLAME, "amount": int(14 * dens), "life": 1.0, "speed": [0.6, 1.8], "dir": Vector3.UP, "spread": 12.0,
				"size": 0.6, "pal": [pal[1], pal[2], Color("#12061E")], "energy": 2.0, "curve": "shrink", "upright": true}
			_glyph_decal(a, pal, Lib.G_DARK, -1.2)
		"poison":
			cfg = {"kind": Lib.K_PUFF, "amount": int(10 * dens), "life": 1.6, "speed": [0.2, 0.7], "dir": Vector3.UP, "spread": 40.0,
				"size": 1.1, "pal": Lib.PAL["poisonsmoke"] if pal == Lib.PAL["poison"] else pal, "energy": 1.0, "curve": "pop", "ramp": "pop"}
		"wind":
			cfg = {"kind": Lib.K_STREAK, "amount": int(16 * dens), "life": 0.6, "speed": [3.0, 6.0], "dir": Vector3.UP, "spread": 30.0,
				"size": 0.7, "pal": pal, "energy": 2.6, "align": true, "quad": Vector2(0.1, 1.0), "curve": "shrink", "tangent": 7.0}
			_glyph_decal(a, pal, Lib.G_QI, 3.0, 0.9)
		"earth":
			cfg = {"kind": Lib.K_CHIP, "amount": int(12 * dens), "life": 0.7, "speed": [3.0, 6.0], "dir": Vector3.UP, "spread": 25.0,
				"size": 0.4, "pal": pal, "energy": 1.0, "gravity": Vector3(0, -14, 0)}
			_spikes(fx, a, "earth", pal, int(7 * dens), 1.25)
		"blood":
			cfg = {"kind": Lib.K_GLOW, "amount": int(14 * dens), "life": 0.9, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 25.0,
				"size": 0.22, "pal": pal, "energy": 2.0, "gravity": Vector3(0, -6, 0), "curve": "shrink"}
		"rune":
			cfg = {"kind": Lib.K_MOTE, "amount": int(10 * dens), "life": 1.4, "speed": [0.4, 1.2], "dir": Vector3.UP, "spread": 5.0,
				"size": 0.3, "pal": pal, "energy": 3.0, "curve": "pop"}
			_glyph_decal(a, pal, Lib.G_ARCANE, 0.8)
		"thorn":
			cfg = {"kind": Lib.K_LEAF, "amount": int(8 * dens), "life": 0.8, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 30.0,
				"size": 0.28, "pal": pal, "energy": 1.0, "gravity": Vector3(0, -2, 0)}
			_spikes(fx, a, "thorn", pal, int(10 * dens), 0.95)
	cfg.merge(base)
	if persistent:
		cfg["one_shot"] = false
		cfg["explosive"] = 0.0
		var e: CPUParticles3D = fx.make_particles(cfg)
		e.position = center
		a.add_child(e)
		e.emitting = true
		(a.get("emitters") as Array).append(e)
	else:
		cfg["explosive"] = 0.85
		var e2: CPUParticles3D = fx.make_particles(cfg)
		e2.one_shot = true
		e2.position = center
		a.add_child(e2)
		e2.emitting = true
		var w := a.global_position + a.global_basis * center
		var rad := maxf(float(a.get("radius")), float(a.get("width")))
		Effects._star(fx, w + Vector3(0, 0.5, 0), pal, 0.2, 1.0, rad * 1.4, 4.0)
		if String(a.get("shape")) != "line":
			Effects._ground_ring(fx, a.global_position, pal, 0.35, rad * 2.3, 0.3, 0.95, 0.12, 1.0, 0.0, 2.6)
	tick(fx, a)


## Periodic accents while a zone is active (lightning strikes, ember bursts...).
static func tick(fx: Node, a: Node3D) -> void:
	if int(fx.call("budget")) > 0:
		return
	var p: Vector3 = fx.call("_random_point_in", a)
	var pal := pal_for(a)
	match String(a.get("visual")):
		"lightning":
			Effects._lightning(fx, p, pal, 0.6, 1)
		"fire":
			fx.burst(p, {"kind": Lib.K_MOTE, "amount": 5, "life": 0.6, "speed": [2.0, 5.0], "dir": Vector3.UP, "spread": 30.0,
				"size": 0.14, "pal": pal, "energy": 3.5, "gravity": Vector3(0, -3, 0)})
		"holy":
			Effects._star(fx, p + Vector3(0, 0.8, 0), pal, 0.45, 0.4, 1.1, 3.5)
		"ice":
			fx.burst(p, {"kind": Lib.K_MOTE, "amount": 3, "life": 0.6, "speed": [0.5, 1.0], "dir": Vector3.UP, "spread": 20.0,
				"size": 0.2, "pal": pal, "energy": 3.0, "curve": "pop"})
		"poison":
			fx.burst(p + Vector3(0, 0.1, 0), {"kind": Lib.K_BUBBLE, "amount": 3, "life": 0.8, "speed": [0.4, 1.0], "dir": Vector3.UP,
				"spread": 20.0, "size": 0.2, "pal": pal, "energy": 2.2, "curve": "pop"})


## Cel crystals (ice), rock shards (earth) or thorns growing out of the zone; children of the area, they fade
## through the `fade` instance uniform (dissolve) at the end.
static func _spikes(fx: Node, a: Node3D, kind: String, pal: Array, n: int, h: float) -> void:
	n = clampi(n, 3, 24)
	for i in n:
		var mesh: Mesh
		var base: Color
		var shade: Color
		var rim: Color
		var glow := 0.0
		match kind:
			"ice":
				mesh = Lib.crystal(5, i)
				base = (pal[1] as Color).lerp(Color.WHITE, 0.35)
				shade = pal[2]
				rim = pal[0]
				glow = 0.8
			"earth":
				mesh = Lib.crystal(4, i + 2)
				base = Color("#8A6A4A")
				shade = Color("#4A3A4A")
				rim = Color("#FFC88A")
			_:
				mesh = Lib.crystal(4, i)
				base = Color("#4E7A2A")
				shade = Color("#1E3A1A")
				rim = pal[0]
		var f: VfxFlash = fx.flash(mesh, Lib.solid_mat(true), Vector3.ZERO, maxf(float(a.get("duration")), 0.8) + 0.3, a)
		Lib.set_solid(f, base, shade, rim, 1.6, glow)
		var hh := h * randf_range(0.6, 1.3)
		var wk := randf_range(0.8, 1.3) * (1.6 if kind == "earth" else 1.0)
		f.s0 = Vector3(wk, 0.05, wk)
		f.s1 = Vector3(wk, hh, wk)
		f.grow_time = 0.12
		f.keep_scale = true
		f.fade_tail = 0.3
		f.global_position = fx.call("_random_point_in", a)
		f.rot = Basis.from_euler(Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3)))
		f.mark_base()
		f.position.y -= 0.02
		f.mark_base()
