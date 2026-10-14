extends RefCounted
## Spitfire 弹药专家, bible 2.5: olive / rust demolition trooper. Cropped olive field jacket with rolled sleeves over a
## rust shirt, grenade bandolier, utility belt with pouches and a thigh holster, a big rust scarf (pulled down from
## a mask) whose two torn tails are the hero silhouette (runtime cloth), tilted beret with a brass badge, padded
## combat boots. Weapons: WeaponFactory "auto_pistol" + offhand "grenade".

const L := preload("res://visuals/dress/_gunfight_lib.gd")
const OLIVE := Color("#5B6235")
const RUST := Color("#A4502A")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_d",
		"height": 1.7,
		"proportions": [1.07, 0.95],
		"rim": Color(1.0, 0.88, 0.68),
		"dress": {
			# vest -> dark olive, shirt -> rust, bow -> rust, skirt -> olive drab; hair -> dark cocoa with warm lights
			"Tops": {"map": [Color("#101208"), Color("#2C3216"), Color("#B0562E")], "contrast": 1.3},
			"Accessory": {"map": [Color("#3A160A"), Color("#A4502A"), Color("#E08A5A")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#22260F"), Color("#4C5329"), Color("#868E58")], "contrast": 1.15},
			"Shoes": {"map": [Color("#0E0A08"), Color("#2A1E16"), Color("#6A5240")], "contrast": 1.2},
			"HAIR": {"map": [Color("#140C0A"), Color("#3E2820"), Color("#9A6A4A")], "contrast": 1.1, "line": 1.7, "shade": Color(0.6, 0.5, 0.72)},
			"EyeIris": {"iris": Color(1.1, 0.7, 0.4)},
		},
		"anims": {&"idle": ["Idle_Sword", "Pistol_Idle"], &"attack": ["Pistol_Shoot"], &"throw": ["OverhandThrow"]},
	}


static func build(b: AnimeBody) -> void:
	var olive := AnimeGear.toon(OLIVE, {"shade": Color("#262A1E") / OLIVE, "rim": Color(1.0, 0.92, 0.7)})
	var olive_dk := AnimeGear.toon(Color("#3A3F22"), {"shade": Color(0.6, 0.58, 0.8)})
	var rust := AnimeGear.toon(RUST, {"shade": Color("#5A1E22") / RUST, "rim": Color(1.0, 0.75, 0.55)})
	var khaki := AnimeGear.toon(Color("#B9A77A"), {"shade": Color("#6E6A80") / Color("#B9A77A")})
	var leather := AnimeGear.toon(Color("#4A2E1C"), {"shade": Color(0.62, 0.55, 0.8)})
	var brass := AnimeGear.toon(Color("#B9944A"), {"shade": ClassDress.GOLD_SHADE / Color("#B9944A"), "rim": ClassDress.GOLD_HI})
	var steel := AnimeGear.steel(Color("#9AA2AE"))
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- cropped olive field jacket, open front, stand collar, brass buttons, rolled short sleeves
	var jy0 := hips.y + 0.1 - uc.y
	var jac := [Vector2(0.14, jy0), Vector2(0.146, jy0 + 0.08), Vector2(0.16, -0.02), Vector2(0.162, 0.05), Vector2(0.145, 0.1), Vector2(0.095, 0.13)]
	var gap := 0.2
	L.shell(b, "UpperChest", jac, uc, olive, gap, 1.0, 0.86)
	L.shell(b, "UpperChest", [Vector2(0.142, jy0 - 0.02), Vector2(0.142, jy0 + 0.012)], uc, khaki, gap, 1.0, 0.86)
	for side: float in [-1.0, 1.0]:
		L.shell_edge(b, "UpperChest", jac, uc, gap, 1.0, 0.86, side, 0.026, olive_dk, 0.006)
		for k in 3:
			b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.008, 8), brass), Transform3D(Basis(), uc + Vector3(side * 0.07, 0.03 - k * 0.06, 0.128)))
		# chest pocket flap
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.022, 0.012)), olive_dk), Transform3D(Basis(Vector3.UP, side * 0.35), uc + Vector3(side * 0.085, 0.035, 0.118)))
		var ua := L.arm(side) + "UpperArm"
		var sh := b.bone_pos(ua)
		var el := b.bone_pos(L.arm(side) + "LowerArm")
		var bs := Basis(Quaternion(Vector3.UP, (el - sh).normalized()))
		var ln := (el - sh).length()
		b.attach(ua, AnimeGear.mi(AnimeGear.lathe([Vector2(0.055, -0.03), Vector2(0.062, ln * 0.3), Vector2(0.06, ln * 0.62)], 14), olive), Transform3D(bs, sh))
		b.attach(ua, AnimeGear.mi(AnimeGear.lathe([Vector2(0.062, ln * 0.56), Vector2(0.068, ln * 0.62), Vector2(0.066, ln * 0.74)], 14), khaki), Transform3D(bs, sh))
		# shoulder strap (epaulette) with a button
		b.attach(ua, AnimeGear.mi(AnimeGear.box(Vector3(0.09, 0.012, 0.035)), olive_dk), Transform3D(Basis(), sh + Vector3(-side * 0.01, 0.058, 0.0)))
	L.shell(b, "UpperChest", [Vector2(0.09, -0.02), Vector2(0.094, 0.04)], neck + Vector3(0, -0.03, -0.004), olive, 0.3, 1.0, 1.0, 18)
	# --- grenade bandolier from the right shoulder to the left hip
	var band: Array = L.bandolier(b, -1.0, leather, 0.04, 0.215, 0.13, 0.82, -0.09)
	var pts: Array = band[0]
	var rot: Basis = band[1]
	for i: int in [4, 6, 8, 10, 12]:
		var p: Vector3 = pts[i]
		var n := Vector3(p.x, 0, p.z).normalized()
		var g := Node3D.new()
		AnimeGear.mi(AnimeGear.sphere(0.026, 10), olive, g)
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.0265, -0.004), Vector2(0.0265, 0.004)], 12), olive_dk, g)
		AnimeGear.mi(AnimeGear.cyl(0.01, 0.012, 0.018, 8), steel, g, Transform3D(Basis(), Vector3(0, 0.03, 0)))
		AnimeGear.mi(AnimeGear.box(Vector3(0.006, 0.03, 0.01)), steel, g, Transform3D(Basis(), Vector3(0.016, 0.018, 0.0)))
		b.attach("UpperChest", g, Transform3D(rot, p + n * 0.03))
	# --- utility belt with pouches, thigh holster on the right, ammo drum on the back
	L.ring(b, "Hips", hips + Vector3(0, 0.02, 0), 0.148, 0.04, leather, 0.82)
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.038, 0.012)), brass), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.124)))
	for a_deg: float in [35.0, 70.0, 145.0, 200.0, 235.0]:
		var a := deg_to_rad(a_deg)
		L.pouch(b, "Hips", hips + Vector3(cos(a) * 0.162, -0.015, sin(a) * 0.14), olive_dk, olive)
	L.holster(b, -1.0, leather, steel)
	# tactical flaps over the skirt: khaki-edged olive panels at the front sides, a rust tab on the left
	for side: float in [-1.0, 1.0]:
		var leg := L.arm(side) + "UpperLeg"
		var flap := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.046, -0.14), Vector2(0.0, -0.165), Vector2(-0.046, -0.14)])
		var fx := Transform3D(Basis(Vector3.UP, side * 0.5) * Basis(Vector3.RIGHT, -0.18), hips + Vector3(side * 0.09, -0.005, 0.125))
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(flap, 0.014, 0.004), olive), fx)
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.046, -0.13), Vector2(0.046, -0.13), Vector2(0.0, -0.17)]), 0.018), khaki), fx)
	b.attach("LeftUpperLeg", AnimeGear.mi(AnimeGear.box(Vector3(0.03, 0.12, 0.012)), rust), Transform3D(Basis(Vector3.UP, 1.2), hips + Vector3(0.16, -0.06, 0.03)))
	var drum := Node3D.new()
	AnimeGear.mi(AnimeGear.cyl(0.07, 0.07, 0.06, 16), olive_dk, drum, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	AnimeGear.mi(AnimeGear.cyl(0.04, 0.04, 0.066, 12), steel, drum, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	AnimeGear.mi(AnimeGear.box(Vector3(0.012, 0.11, 0.07)), rust, drum)
	b.attach("Hips", drum, Transform3D(Basis(Vector3.UP, 0.4), hips + Vector3(0.09, -0.02, -0.17)))
	# --- fingerless gloves with steel knuckles
	for side: float in [-1.0, 1.0]:
		L.gauntlet(b, side, leather, steel, {"radii": [0.044, 0.042, 0.04], "t0": 0.62, "fin": false, "studs": false})
	# --- padded combat boots with olive knee pads
	for side: float in [-1.0, 1.0]:
		var ll := L.arm(side) + "LowerLeg"
		var ft := L.arm(side) + "Foot"
		ClassDress.limb_guard(b, ll, ft, [0.058, 0.052, 0.05, 0.052], 0.42, 0.95, leather, khaki, 14)
		var kp := b.bone_pos(ll)
		var pad := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.045, -0.05), Vector2(0.045, -0.05), Vector2(0.05, 0.03), Vector2(0.0, 0.07), Vector2(-0.05, 0.03)]), 0.026, 0.008), olive)
		b.attach(ll, pad, Transform3D(Basis(Vector3.RIGHT, -0.12), kp + Vector3(0, 0.0, 0.055)))
		b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.06, -0.012), Vector2(0.062, 0.012)], 14), leather), Transform3D(Basis(), kp + Vector3(0, -0.03, 0)))
	# --- the hero element: a big rust scarf bunched round the neck, two long torn tails trailing behind
	var wrap := AnimeGear.mi(AnimeGear.lathe([Vector2(0.075, -0.07), Vector2(0.115, -0.045), Vector2(0.122, 0.0), Vector2(0.1, 0.04), Vector2(0.078, 0.055)], 18, 1.0, 1.08), rust)
	b.attach("Neck", wrap, Transform3D(Basis(Vector3.RIGHT, 0.1), neck + Vector3(0, -0.005, 0.01)))
	var fold := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.0, -0.1)]), 0.016, 0.005), rust)
	b.attach("UpperChest", fold, Transform3D(Basis(Vector3.RIGHT, 0.3), neck + Vector3(0.0, -0.06, 0.1)))
	var cols := [["UpperChest", 0.16, 0.0], ["Hips", 0.18, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(0.05, -0.06, -0.09)), {
		"name": "ScarfTail", "length": 0.98, "segments": 12, "width": [0.17, 0.2, 0.2, 0.18, 0.15, 0.1, 0.03],
		"dir": Vector3(0.15, -1.0, -0.32), "side": Vector3(1, 0.2, 0), "material": rust, "thickness": 0.012,
		"stiffness": 0.03, "stiffness_tip": 0.004, "gravity": 9.0, "drag": 0.06, "wind": Vector3(0.4, 0.0, -0.5), "colliders": cols})
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(0.02, -0.07, -0.09)), {
		"name": "ScarfTail2", "length": 0.7, "segments": 8, "width": [0.15, 0.15, 0.12, 0.06],
		"dir": Vector3(-0.1, -1.0, -0.3), "side": Vector3(1, 0.1, 0), "material": rust, "thickness": 0.012,
		"stiffness": 0.035, "stiffness_tip": 0.005, "gravity": 9.0, "drag": 0.07, "wind": Vector3(0.5, 0.0, -0.9), "colliders": cols})
	# --- tilted beret with a brass badge
	var beret := Node3D.new()
	var dome := AnimeGear.mi(AnimeGear.sphere(0.13, 18), olive_dk, beret)
	dome.scale = Vector3(1.0, 0.36, 1.05)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.104, -0.012), Vector2(0.106, 0.008)], 22, 1.0, 1.05), leather, beret, Transform3D(Basis(), Vector3(0, -0.02, 0)))
	AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.022, 5, 0.45), 0.008), brass, beret, Transform3D(Basis(Vector3.UP, -0.5), Vector3(-0.055, 0.0, 0.1)))
	b.attach("Head", beret, Transform3D(Basis(Vector3.BACK, -0.32) * Basis(Vector3.RIGHT, -0.12), head + Vector3(0.025, 0.205, -0.005)))
