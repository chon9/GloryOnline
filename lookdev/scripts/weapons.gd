class_name LdWeapons
extends RefCounted
## Signature weapons for the slice (bible 2.6), upgraded from visuals/weapon_factory.gd primitives:
## real silhouettes (extruded blade profiles, lathed barrels), toon + outline materials, HDR emissive
## accents that bloom. Grip convention: origin = fist, weapon extends along +Y, local -Z = "up" over the fist.
## These keep WeaponFactory's id contract (battle_lance / hand_cannon / broom) so they can replace it later.

const BLACK := Color("#121216")
const STEEL := Color("#D5DCE6")
const GOLD := Color("#D8B25A")
const RED := Color("#E0232E")


static func que_xie() -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_battle_lance"
	# the fist grips mid-shaft (spear hold): everything sits under `body`, shifted so the head is ~0.75 m
	# above the fist and the butt spike ~1.2 m below it
	var body := Node3D.new()
	body.position = Vector3(0, -0.42, 0)
	root.add_child(body)
	var shaft := LdGear.toon(BLACK, {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.8, 0.85, 1.0), "rim_strength": 0.9})
	var steel := LdGear.toon(STEEL, {"shade": Color("#7C88A0") / STEEL, "rim": Color.WHITE, "rim_strength": 1.0})
	var gold := LdGear.toon(GOLD, {"shade": Color("#8A5A2B") / GOLD, "rim": Color("#FFE9A8")})
	LdGear.mi(LdGear.cyl(0.022, 0.022, 1.8, 10), shaft, body, Transform3D(Basis(), Vector3(0, 0.33, 0)))
	for y: float in [-0.12, 0.2, 0.62, 1.12]:
		LdGear.mi(LdGear.cyl(0.028, 0.028, 0.035, 10), gold, body, Transform3D(Basis(), Vector3(0, y, 0)))
	# silver butt spike with a gold collar
	LdGear.mi(LdGear.lathe([Vector2(0.0, -0.84), Vector2(0.02, -0.7), Vector2(0.034, -0.6), Vector2(0.026, -0.56)], 10), steel, body)
	LdGear.mi(LdGear.cyl(0.036, 0.036, 0.03, 10), gold, body, Transform3D(Basis(), Vector3(0, -0.55, 0)))
	# head assembly, modelled at 1x around y = 1.2 then scaled up 1.6x (weapons read 35-60% oversized, bible 2.6)
	var head := Node3D.new()
	head.position = Vector3(0, 1.2, 0)
	head.scale = Vector3.ONE * 1.6
	body.add_child(head)
	var o := Vector3(0, -1.2, 0)
	# flared black socket
	LdGear.mi(LdGear.lathe([Vector2(0.018, 1.18), Vector2(0.036, 1.24), Vector2(0.026, 1.28), Vector2(0.04, 1.3)], 12), shaft, head, Transform3D(Basis(), o))
	# three black claw prongs curling up around the gem
	for k in 3:
		var a := TAU * k / 3.0 + PI / 6.0
		var claw := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.02, 0.0), Vector2(0.04, 0.05), Vector2(0.034, 0.1), Vector2(0.016, 0.135), Vector2(0.018, 0.09), Vector2(0.008, 0.05)]), 0.014), shaft, head)
		claw.transform = Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.022, 1.29, -sin(a) * 0.022) + o)
	var orb := LdGear.mi(LdGear.sphere(0.04, 16), LdGear.toon(RED, {"emit": Color(1.0, 0.1, 0.12) * 2.2, "rim": Color(1, 0.8, 0.8), "rim_strength": 1.2, "outline": false}), head)
	orb.position = Vector3(0, 1.35, 0) + o
	var halo := LdGear.mi(LdGear.sphere(0.07, 12), LdGear.glow(Color(1.0, 0.2, 0.25), 1.6, true, 0.35), head)
	halo.position = orb.position
	# long serrated blade with a back hook: 6 saw teeth on one edge, swept hook at the base
	var blade := PackedVector2Array([
		Vector2(-0.03, 1.39), Vector2(0.03, 1.39), Vector2(0.06, 1.43), Vector2(0.115, 1.40), Vector2(0.09, 1.47), Vector2(0.056, 1.50),
		Vector2(0.07, 1.55), Vector2(0.05, 1.57), Vector2(0.066, 1.62), Vector2(0.046, 1.64), Vector2(0.06, 1.69), Vector2(0.042, 1.71),
		Vector2(0.054, 1.76), Vector2(0.036, 1.78), Vector2(0.046, 1.83), Vector2(0.028, 1.86), Vector2(0.0, 2.06),
		Vector2(-0.03, 1.9), Vector2(-0.044, 1.78), Vector2(-0.048, 1.62), Vector2(-0.044, 1.48)])
	LdGear.mi(LdGear.extrude(blade, 0.024, 0.008), steel, head, Transform3D(Basis(), o))
	# red energy fuller down the blade (bloom accent)
	var fuller := PackedVector2Array([Vector2(-0.007, 1.46), Vector2(0.007, 1.46), Vector2(0.004, 1.88), Vector2(-0.004, 1.88)])
	LdGear.mi(LdGear.extrude(fuller, 0.028), LdGear.glow(Color(1.0, 0.25, 0.25), 3.5), head, Transform3D(Basis(), o))
	# crimson tassel streamer under the head (secondary-motion silhouette)
	var tp: Array = []
	var tw: Array = []
	var ts: Array = []
	for i in 7:
		var t := float(i) / 6.0
		tp.append(Vector3(0.03 + t * 0.05, 1.16 - t * 0.34, sin(t * 3.0) * 0.03))
		tw.append(lerpf(0.05, 0.02, t))
		ts.append(Vector3(0, 0, 1))
	LdGear.mi(LdGear.ribbon(tp, tw, ts, 0.01), LdGear.toon(Color("#C8202A"), {"shade": Color(0.55, 0.3, 0.55)}), body)
	root.set_meta("two_hand", true)
	return root


static func launcher_cannon() -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_hand_cannon"
	var brass := LdGear.toon(Color("#A87A34"), {"shade": Color(0.55, 0.42, 0.55), "rim": Color("#FFE9A8"), "rim_strength": 0.9})
	var steel := LdGear.toon(Color("#5A6270"), {"shade": Color(0.55, 0.58, 0.85)})
	var dark := LdGear.toon(Color("#24242A"))
	var body := Node3D.new()
	body.position = Vector3(0, 0, -0.13)   # barrel axis sits over the fist
	root.add_child(body)
	# barrel: breech -> long brass tube -> flared muzzle
	LdGear.mi(LdGear.lathe([Vector2(0.0, -0.42), Vector2(0.09, -0.42), Vector2(0.125, -0.36), Vector2(0.13, -0.15), Vector2(0.105, -0.1),
		Vector2(0.1, 0.62), Vector2(0.115, 0.66), Vector2(0.15, 0.84), Vector2(0.162, 0.9), Vector2(0.13, 0.91), Vector2(0.08, 0.86)], 20), brass, body)
	LdGear.mi(LdGear.cyl(0.075, 0.075, 0.02, 20), LdGear.toon(Color("#120C08"), {"outline": false}), body, Transform3D(Basis(), Vector3(0, 0.875, 0)))
	for y: float in [0.05, 0.35, 0.6]:
		LdGear.mi(LdGear.lathe([Vector2(0.108, y - 0.02), Vector2(0.116, y), Vector2(0.108, y + 0.02)], 20), steel, body)
	# hazard-stripe band
	var stripes := LdGear.toon(Color.WHITE, {"tex": _stripe_tex(), "shade": Color(0.6, 0.6, 0.85)})
	LdGear.mi(LdGear.lathe([Vector2(0.104, 0.13), Vector2(0.104, 0.27)], 24), stripes, body)
	# glowing energy chamber with brass cage
	var glass := LdGear.glow(Color("#FFE45A"), 4.0)
	LdGear.mi(LdGear.cyl(0.07, 0.07, 0.2, 16), glass, body, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.24, -0.11)))
	for k in 5:
		var a := TAU * k / 5.0
		LdGear.mi(LdGear.box(Vector3(0.012, 0.012, 0.21)), brass, body, Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis(), Vector3(cos(a) * 0.075, -0.24, -0.11 + sin(a) * 0.075)))
	var halo := LdGear.mi(LdGear.sphere(0.13, 12), LdGear.glow(Color("#FFC43A"), 1.5, true, 0.25), body)
	halo.position = Vector3(0, -0.24, -0.11)
	# front grip + side fins
	LdGear.mi(LdGear.box(Vector3(0.05, 0.08, 0.16)), dark, root, Transform3D(Basis(), Vector3(0, 0.0, -0.03)))
	for side: float in [-1.0, 1.0]:
		var fin := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(0, -0.3), Vector2(0.09, -0.22), Vector2(0.06, 0.3), Vector2(0, 0.35)]), 0.012), brass, body)
		fin.transform = Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(side * 0.11, 0, 0))
	# braided fuse cable looping back from the breech
	var cable: Array = []
	for i in 16:
		var t := float(i) / 15.0
		cable.append(Vector3(sin(t * PI) * 0.12, -0.42 - t * 0.18, 0.05 + sin(t * PI * 1.5) * 0.2 + t * 0.12))
	LdGear.mi(LdGear.tube(cable, 0.014, 6), LdGear.toon(Color("#3A2418")), body)
	return root


static func _stripe_tex() -> ImageTexture:
	var im := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 8:
			var s := int(floor((x + y * 1.5) / 8.0)) % 2 == 0
			im.set_pixel(x, y, Color("#F2C230") if s else Color("#1A1A1E"))
	return ImageTexture.create_from_image(im)


static func star_broom() -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_broom"
	var wood := LdGear.toon(Color("#2A1A22"), {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.75, 0.8, 1.0)})
	var gold := LdGear.toon(Color("#D8B25A"), {"shade": Color("#8A5A2B") / Color("#D8B25A"), "rim": Color("#FFE9A8")})
	LdGear.mi(LdGear.cyl(0.018, 0.022, 1.7, 10), wood, root, Transform3D(Basis(), Vector3(0, 0.3, 0)))
	for y: float in [-0.5, 0.95, 1.1, 1.15]:
		LdGear.mi(LdGear.cyl(0.03, 0.03, 0.03, 12), gold, root, Transform3D(Basis(), Vector3(0, y, 0)))
	LdGear.mi(LdGear.lathe([Vector2(0.0, -0.62), Vector2(0.028, -0.56), Vector2(0.02, -0.52)], 10), gold, root)
	# bristle fan of star dust: violet-blue blades with white-hot cores (bloom)
	var fan := Node3D.new()
	fan.position = Vector3(0, 1.16, 0)
	root.add_child(fan)
	var blade_mat := LdGear.glow(Color("#6C7BFF"), 2.6, true, 0.85)
	var core_mat := LdGear.glow(Color("#E8ECFF"), 4.0, true, 0.9)
	for k in 13:
		var a := lerpf(-0.55, 0.55, k / 12.0)
		var len := 0.55 - absf(a) * 0.25
		var b := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(-0.012, 0), Vector2(0.012, 0), Vector2(0.0, len)]), 0.004), blade_mat, fan)
		b.transform = Transform3D(Basis(Vector3.FORWARD, a) * Basis(Vector3.UP, k * 0.5), Vector3.ZERO)
		if k % 3 == 1:
			var cb := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(-0.004, 0), Vector2(0.004, 0), Vector2(0.0, len * 0.7)]), 0.003), core_mat, fan)
			cb.transform = b.transform
	# drifting star dust
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.6
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.gravity = Vector3(0, 0.15, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(0.42, 0.48, 1.0, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = LdVfx.spark_tex()
	qm.emission_enabled = true
	qm.emission = Color("#9AA4FF")
	qm.emission_energy_multiplier = 3.0
	q.material = qm
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.3, 0)
	fan.add_child(p)
	return root
