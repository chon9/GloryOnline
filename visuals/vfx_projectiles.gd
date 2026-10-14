class_name VfxProjectiles
extends RefCounted
## Anime projectile visuals for Fx.spawn_projectile_visual (all 15 ARCHITECTURE §7.3 names). Each look is a
## few cel-banded energy cores / flat-shaded cel solids on the projectile node, a camera-facing light-streak
## ribbon (VfxRibbon) and at most one particle trail. `p` is Fx's ProjVis: body = child "Body" (scaled), the
## builder may set p.trail, p.ribbon, p.spin_node, p.spin, p.flicker and p.segments.

const Lib := preload("res://visuals/vfx_lib.gd")
const Ribbon := preload("res://visuals/vfx_ribbon.gd")

## default palette per visual (Color.WHITE from the caller)
const DEFAULT_PAL: Dictionary = {
	"orb": "arcane", "bullet": "gun", "arrow": "phys", "grenade": "gun", "shuriken": "phys", "wave": "phys",
	"missile": "gun", "star": "holy", "blood": "blood", "qi": "qi", "dragon": "fire", "lightning": "lightning",
	"cannonball": "gun", "flask": "poison", "scythe": "dark",
}


static func build(fx: Node, p: Node3D, body: Node3D, visual: String, color: Color, s: float) -> void:
	var pal: Array = Lib.pal(color, DEFAULT_PAL.get(visual, "arcane"))
	match visual:
		"orb":
			_energy(body, Lib.sphere(0.2, 14), pal, 3.5)
			_halo(body, pal, 0.95, Lib.K_GLOW, 2.2)
			_ribbon(p, pal, 0.3 * s, 10)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_MOTE, "amount": 16, "life": 0.4, "size": 0.18 * s, "pal": pal, "energy": 3.0}))
		"bullet":
			var b := _energy(body, Lib.sphere(0.5, 10), pal, 4.5)
			b.scale = Vector3(0.09, 0.09, 0.6)
			var tip := _halo(body, pal, 0.45, Lib.K_SPARK, 4.0)
			tip.position = Vector3(0, 0, -0.25)
			_ribbon(p, pal, 0.07 * s, 7, 4.0)
		"arrow":
			var shaft := _solid(body, Lib.quad(), Color("#C9A46A"), Color("#6A4A3A"), Color(1, 1, 1))
			shaft.mesh = _box()
			shaft.scale = Vector3(0.035, 0.035, 0.85)
			var head := _solid(body, Lib.cone(4), Color("#DDE6F0"), Color("#5A6A8A"), pal[1], 2.0)
			head.rotation.x = -PI / 2
			head.position = Vector3(0, 0, -0.5)
			head.scale = Vector3(0.11, 0.2, 0.11)
			for k in 2:
				var fl := _solid(body, _box(), Color("#E0232E") if k == 0 else Color("#F2E6CF"), Color("#5A0812"), Color(1, 1, 1))
				fl.scale = Vector3(0.18, 0.012, 0.16)
				fl.position = Vector3(0, 0, 0.38)
				fl.rotation.z = k * PI / 2
			_ribbon(p, pal, 0.09 * s, 9, 3.5)
		"grenade":
			var g := _solid(body, Lib.sphere(0.2, 12), Color("#4A5A3A"), Color("#2A2A3A"), pal[1], 1.6)
			g.scale = Vector3(1.0, 1.15, 1.0)
			var cap := _solid(body, _box(), Color("#B0B4BC"), Color("#4A4A5A"), Color(1, 1, 1))
			cap.scale = Vector3(0.12, 0.08, 0.12)
			cap.position = Vector3(0, 0.24, 0)
			var spark := _halo(body, pal, 0.5, Lib.K_SPARK, 4.0)
			spark.position = Vector3(0, 0.34, 0)
			p.set("flicker", spark)
			p.set("spin_node", body)
			p.set("spin", Vector3(9.0, 0, 0))
			p.set("trail", _trail(fx, p, {"kind": Lib.K_PUFF, "amount": 8, "life": 0.4, "size": 0.24 * s, "pal": Lib.PAL["trailsmoke"], "energy": 1.0, "curve": "shrink"}))
		"shuriken":
			var st := _solid(body, Lib.star4(), Color("#C8D0DC"), Color("#3A4258"), pal[1], 2.2)
			st.scale = Vector3.ONE * 0.62
			var smear := _flat(body, Lib.ring_mat(false), pal, 0.7)
			smear.set_instance_shader_parameter(&"radius", 0.9)
			smear.set_instance_shader_parameter(&"width", 0.45)
			smear.set_instance_shader_parameter(&"energy", 1.6)
			smear.scale = Vector3(0.75, 1.0, 0.75)
			p.set("spin_node", body)
			p.set("spin", Vector3(0, 28.0, 0))
			_ribbon(p, pal, 0.1 * s, 8, 3.0)
		"wave":
			# sword wave: a horizontal crescent smear (bulging forward) with an echo arc behind it
			for k in 2:
				var a := MeshInstance3D.new()
				a.mesh = Lib.arc(0.55, 1.0, deg_to_rad(20.0), deg_to_rad(160.0))
				a.material_override = Lib.slash_mat()
				a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				Lib.set_pal(a, pal if k == 0 else [pal[1], pal[1].lerp(pal[2], 0.4), pal[2]])
				a.set_instance_shader_parameter(&"progress", 0.5)
				a.set_instance_shader_parameter(&"energy", 3.2 - k)
				a.set_instance_shader_parameter(&"alpha_mul", 1.0 - k * 0.35)
				a.set_instance_shader_parameter(&"fade", 1.0)
				# arc lies in XY with its bulge toward +Y: lay it flat with the bulge toward -Z (forward)
				a.basis = Basis(Vector3.RIGHT, -PI / 2)
				a.scale = Vector3.ONE * (1.5 - k * 0.2)
				a.position = Vector3(0, k * 0.05, 0.6 + k * 0.35)
				body.add_child(a)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_STREAK, "amount": 14, "life": 0.25, "size": 0.45 * s, "pal": pal, "energy": 3.0,
				"align": true, "quad": Vector2(0.14, 1.0), "box": Vector3(0.8, 0.1, 0.1)}))
		"missile":
			var m := _solid(body, Lib.cylinder(), Color("#D8DCE4"), Color("#5A6278"), Color(1, 0.8, 0.5), 1.2)
			m.rotation.x = PI / 2
			m.scale = Vector3(0.17, 0.7, 0.17)
			var nose := _solid(body, Lib.cone(10), Color("#E0232E"), Color("#5A0812"), Color(1, 0.8, 0.5))
			nose.rotation.x = -PI / 2
			nose.position = Vector3(0, 0, -0.45)
			nose.scale = Vector3(0.17, 0.22, 0.17)
			var jet := _halo(body, pal, 0.75, Lib.K_GLOW, 3.5)
			jet.position = Vector3(0, 0, 0.42)
			p.set("flicker", jet)
			_ribbon(p, pal, 0.16 * s, 8, 3.5)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_PUFF, "amount": 14, "life": 0.55, "size": 0.3 * s, "pal": Lib.PAL["trailsmoke"], "energy": 1.0, "curve": "shrink"}))
		"star":
			var st := _halo(body, pal, 1.1, Lib.K_SPARK, 4.0)
			p.set("flicker", st)
			_halo(body, pal, 0.8, Lib.K_GLOW, 2.4)
			_ribbon(p, pal, 0.22 * s, 10)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_MOTE, "amount": 16, "life": 0.45, "size": 0.2 * s, "pal": pal, "energy": 3.0}))
		"blood":
			_energy(body, Lib.sphere(0.2, 12), pal, 3.0)
			_halo(body, pal, 0.8, Lib.K_GLOW, 2.0)
			_ribbon(p, pal, 0.22 * s, 10, 2.6)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_GLOW, "amount": 14, "life": 0.45, "size": 0.14 * s, "pal": pal, "energy": 2.0, "gravity": Vector3(0, -6, 0)}))
		"qi":
			_energy(body, Lib.sphere(0.3, 16), pal, 3.8)
			var g := MeshInstance3D.new()
			g.mesh = Lib.quad()
			g.material_override = Lib.glyph_mat(true)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Lib.set_pal(g, pal)
			for k in [[&"energy", 2.4], [&"spin", 4.0], [&"reveal", 1.0], [&"fade", 1.0], [&"style", float(Lib.G_QI)], [&"seed", randf()]]:
				g.set_instance_shader_parameter(k[0], k[1])
			g.scale = Vector3.ONE * 1.3
			body.add_child(g)
			_halo(body, pal, 1.2, Lib.K_GLOW, 2.0)
			_ribbon(p, pal, 0.45 * s, 12)
		"dragon":
			_energy(body, Lib.sphere(0.34, 14), pal, 4.0)
			_halo(body, pal, 1.4, Lib.K_GLOW, 2.4)
			var fl := _halo(body, pal, 1.2, Lib.K_FLAME, 2.8)
			p.set("flicker", fl)
			var segs: Array[Node3D] = []
			for i in 7:
				var seg := Node3D.new()
				var sm := _energy(seg, Lib.sphere(0.28 - i * 0.026, 10), pal, 3.0 - i * 0.2)
				sm.scale = Vector3.ONE * s
				var fh := _halo(seg, pal, (1.15 - i * 0.11) * s, Lib.K_FLAME, 2.6)
				fh.set_instance_shader_parameter(&"seed", float(i) * 1.7)
				p.add_child(seg)
				seg.top_level = true
				segs.append(seg)
			p.set("segments", segs)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_FLAME, "amount": 20, "life": 0.4, "size": 0.55 * s, "pal": pal, "energy": 2.6, "upright": true}))
		"lightning":
			var bolt := _halo(body, pal, 1.2, Lib.K_SPARK, 4.5)
			p.set("flicker", bolt)
			_halo(body, pal, 0.9, Lib.K_GLOW, 2.6)
			var core := _energy(body, Lib.sphere(0.5, 8), pal, 5.0)
			core.scale = Vector3(0.08, 0.08, 1.2)
			core.position = Vector3(0, 0, 0.45)
			_ribbon(p, pal, 0.16 * s, 8, 4.0)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_STREAK, "amount": 18, "life": 0.18, "size": 0.35 * s, "pal": pal, "energy": 3.5,
				"align": true, "quad": Vector2(0.12, 1.0), "speed": [1.5, 4.0]}))
		"cannonball":
			_solid(body, Lib.sphere(0.3, 14), Color("#2A2A30"), Color("#141420"), pal[2], 2.6)
			var fl := _halo(body, pal, 1.0, Lib.K_GLOW, 3.0)
			fl.position = Vector3(0, 0, 0.22)
			_ribbon(p, pal, 0.3 * s, 9, 3.2)
			p.set("trail", _trail(fx, p, {"kind": Lib.K_FLAME, "amount": 16, "life": 0.35, "size": 0.55 * s, "pal": pal, "energy": 2.6, "upright": true}))
		"flask":
			var bottle := _solid(body, Lib.sphere(0.17, 12), (pal[1] as Color).lerp(Color.WHITE, 0.1), pal[2], pal[0], 1.8, 0.6)
			bottle.scale = Vector3(1.0, 1.05, 1.0)
			var neck := _solid(body, Lib.cylinder(), Color("#D8F0E8"), Color("#5A7A6A"), Color(1, 1, 1))
			neck.scale = Vector3(0.09, 0.16, 0.09)
			neck.position = Vector3(0, 0.22, 0)
			var cork := _solid(body, _box(), Color("#B08050"), Color("#5A3A22"), Color(1, 1, 1))
			cork.scale = Vector3(0.08, 0.06, 0.08)
			cork.position = Vector3(0, 0.32, 0)
			p.set("spin_node", body)
			p.set("spin", Vector3(10.0, 0, 3.0))
			p.set("trail", _trail(fx, p, {"kind": Lib.K_BUBBLE, "amount": 10, "life": 0.45, "size": 0.16 * s, "pal": pal, "energy": 2.2, "gravity": Vector3(0, -4, 0)}))
		"scythe":
			# a spinning violet crescent blade smear
			for k in 2:
				var a := MeshInstance3D.new()
				a.mesh = Lib.arc(0.5, 1.0, deg_to_rad(10.0 + k * 180.0), deg_to_rad(150.0 + k * 180.0))
				a.material_override = Lib.slash_mat()
				a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				Lib.set_pal(a, pal)
				a.set_instance_shader_parameter(&"progress", 0.5)
				a.set_instance_shader_parameter(&"energy", 3.0)
				a.set_instance_shader_parameter(&"alpha_mul", 1.0)
				a.set_instance_shader_parameter(&"fade", 1.0)
				a.basis = Basis(Vector3.RIGHT, -PI / 2)
				a.scale = Vector3.ONE * 0.95
				body.add_child(a)
			_halo(body, pal, 0.7, Lib.K_GLOW, 2.0)
			p.set("spin_node", body)
			p.set("spin", Vector3(0, 18.0, 0))
			p.set("trail", _trail(fx, p, {"kind": Lib.K_MOTE, "amount": 14, "life": 0.35, "size": 0.2 * s, "pal": pal, "energy": 3.0}))
		_:
			_energy(body, Lib.sphere(0.2, 14), pal, 3.5)
			_halo(body, pal, 0.95, Lib.K_GLOW, 2.2)
			_ribbon(p, pal, 0.3 * s, 10)


static var _box_mesh: BoxMesh


static func _box() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3.ONE
	return _box_mesh


static func _energy(parent: Node3D, mesh: Mesh, pal: Array, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Lib.energy_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Lib.set_pal(mi, pal)
	mi.set_instance_shader_parameter(&"energy", energy)
	mi.set_instance_shader_parameter(&"fade", 1.0)
	mi.set_instance_shader_parameter(&"vfade", 0.0)
	mi.set_instance_shader_parameter(&"dissolve", 0.0)
	mi.set_instance_shader_parameter(&"additive", 0.4)
	parent.add_child(mi)
	return mi


static func _halo(parent: Node3D, pal: Array, size: float, kind: int, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	mi.material_override = Lib.sprite_mat(kind, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Lib.set_pal(mi, pal)
	mi.set_instance_shader_parameter(&"energy", energy)
	mi.set_instance_shader_parameter(&"fade", 1.0)
	mi.set_instance_shader_parameter(&"progress", 0.0)
	mi.set_instance_shader_parameter(&"seed", randf() * 10.0)
	mi.scale = Vector3.ONE * size
	parent.add_child(mi)
	return mi


static func _solid(parent: Node3D, mesh: Mesh, base: Color, shade: Color, rim: Color, rim_strength := 1.5, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Lib.solid_mat(false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Lib.set_solid(mi, base, shade, rim, rim_strength, glow)
	parent.add_child(mi)
	return mi


static func _flat(parent: Node3D, mat: Material, pal: Array, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.plane()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Lib.set_pal(mi, pal)
	mi.set_instance_shader_parameter(&"fade", 1.0)
	mi.set_instance_shader_parameter(&"rays", 0.0)
	mi.set_instance_shader_parameter(&"cracks", 0.0)
	mi.scale = Vector3(size, 1.0, size)
	parent.add_child(mi)
	return mi


static func _ribbon(p: Node3D, pal: Array, w: float, points: int, energy := 3.0) -> void:
	var r := Ribbon.new()
	r.setup(pal, w, points, energy)
	p.add_child(r)
	p.set("ribbon", r)


## Looping particle trail emitted in world space behind the projectile.
static func _trail(fx: Node, p: Node3D, cfg: Dictionary) -> CPUParticles3D:
	var c := cfg.duplicate()
	c["one_shot"] = false
	c["explosive"] = 0.0
	if not c.has("speed"):
		c["speed"] = [0.0, 0.4]
	if not c.has("spread"):
		c["spread"] = 180.0
	if not c.has("curve"):
		c["curve"] = "shrink"
	var t: CPUParticles3D = fx.make_particles(c)
	t.local_coords = false
	t.emitting = true
	p.add_child(t)
	return t
