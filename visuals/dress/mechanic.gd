extends RefCounted
## Mechanic 机械师, bible 2.5: gunmetal / safety orange field engineer. Gunmetal work suit, harness with a hazard
## chest plate, an orange work jacket tied round the waist (its two sleeves are runtime cloth), heavy work gloves and
## boots with orange toe caps, welding goggles pushed up on teal hair. The hero silhouette is the backpack drone rig:
## engine pack with thrusters, an articulated manipulator arm over the right shoulder, an antenna and a docked
## scout drone over the left shoulder. Weapons: WeaponFactory "rifle" + "mech_box" (hip).

const L := preload("res://visuals/dress/_gunfight_lib.gd")
const GUNMETAL := Color("#4A525C")
const ORANGE := Color("#FF8A1F")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_e",
		"height": 1.66,
		"proportions": [1.06, 0.97],
		"rim": Color(0.85, 0.95, 1.0),
		"dress": {
			# one-piece -> gunmetal work suit; hair -> teal (complements the safety orange)
			"Onepice": {"map": [Color("#101318"), Color("#2E353E"), Color("#6A7480")], "contrast": 1.3},
			"Shoes": {"map": [Color("#0C0C0E"), Color("#24262C"), Color("#5A5E68")], "contrast": 1.2},
			"HAIR": {"map": [Color("#0A2A30"), Color("#1F7A80"), Color("#86E2D6")], "contrast": 1.15, "line": 1.7, "shade": Color(0.55, 0.62, 0.85)},
			"EyeIris": {"iris": Color(1.2, 0.75, 0.35)},
		},
		"anims": {&"idle": ["Idle_Sword", "Pistol_Idle"], &"attack": ["Pistol_Shoot"], &"cast": ["Two-hand Blast"]},
	}


static func _hazard() -> ShaderMaterial:
	return AnimeGear.toon(ORANGE, {"shade": Color("#8A3A3A") / ORANGE, "rim": Color(1.0, 0.85, 0.6)})


static func build(b: AnimeBody) -> void:
	var metal := AnimeGear.toon(GUNMETAL, {"shade": Color(0.6, 0.62, 0.88), "rim": Color(0.85, 0.95, 1.0), "rim_strength": 0.8})
	var dark := AnimeGear.toon(Color("#22262C"), {"shade": Color(0.6, 0.6, 0.85)})
	var orange := _hazard()
	var leather := AnimeGear.toon(Color("#4A2E1C"), {"shade": Color(0.62, 0.55, 0.8)})
	var steel := AnimeGear.steel(Color("#B8C2CE"))
	var lens := AnimeGear.toon(Color("#FFB040"), {"emit": Color(1.0, 0.5, 0.1) * 0.7, "outline": false})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- fitted gunmetal bodice over the one-piece, orange piping, collar
	var yb := hips.y + 0.04 - uc.y
	var bod := [Vector2(0.142, yb), Vector2(0.14, yb + 0.08), Vector2(0.152, ch.y - uc.y), Vector2(0.158, 0.04), Vector2(0.14, 0.1), Vector2(0.09, 0.125)]
	L.shell(b, "UpperChest", bod, uc, metal, 0.0, 1.0, 0.86)
	L.mandarin_collar(b, dark, orange, 0.066, 0.05)
	# hazard chest plate on the harness
	var plate := PackedVector2Array([Vector2(-0.085, 0.05), Vector2(0.085, 0.05), Vector2(0.095, -0.0), Vector2(0.06, -0.07), Vector2(-0.06, -0.07), Vector2(-0.095, 0.0)])
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(plate, 0.016, 0.004), dark), Transform3D(Basis(Vector3.RIGHT, -0.12), uc + Vector3(0, 0.0, 0.138)))
	for k in 4:
		var stripe := PackedVector2Array([Vector2(-0.012, 0.0), Vector2(0.008, 0.0), Vector2(0.028, 0.05), Vector2(0.008, 0.05)])
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(stripe, 0.02), orange), Transform3D(Basis(Vector3.RIGHT, -0.12), uc + Vector3(-0.06 + k * 0.034, -0.03, 0.141)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.014, 10), AnimeGear.toon(Color("#7FE8FF"), {"emit": Color("#2FB0FF") * 1.2, "outline": false})), Transform3D(Basis(), uc + Vector3(0.0, 0.035, 0.15)))
	# harness straps over both shoulders to the belt
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		var ws: Array = []
		var ss: Array = []
		for i in 11:
			var a := lerpf(-PI * 0.46, PI * 0.46, float(i) / 10.0)
			pts.append(uc + Vector3(side * 0.088, cos(a) * 0.27 - 0.13, sin(a) * 0.158))
			ws.append(0.032)
			ss.append(Vector3(1, 0, 0))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon(pts, ws, ss, 0.01), leather), Transform3D.IDENTITY)
	# --- right shoulder: layered gunmetal plate with orange edge; left: a small strap pad
	ClassDress.pauldron(b, -1.0, metal, orange, 0.95, 2, false)
	# --- heavy work gloves and boots with orange toe caps, knee pads
	for side: float in [-1.0, 1.0]:
		L.gauntlet(b, side, metal, orange, {"radii": [0.05, 0.047, 0.045, 0.044], "t0": 0.45, "fin": false, "studs": false})
		var ll := L.arm(side) + "LowerLeg"
		var ft := L.arm(side) + "Foot"
		ClassDress.limb_guard(b, ll, ft, [0.056, 0.054, 0.05, 0.054], 0.5, 0.96, dark, orange, 14)
		var fp := b.bone_pos(ft)
		var toe := b.bone_pos(L.arm(side) + "Toes")
		b.attach(ft, AnimeGear.mi(AnimeGear.box(Vector3(0.088, 0.055, 0.075)), orange), Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(fp.x, 0.035, toe.z + 0.03)))
		var kp := b.bone_pos(ll)
		var pad := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.042, -0.045), Vector2(0.042, -0.045), Vector2(0.046, 0.03), Vector2(0.0, 0.06), Vector2(-0.046, 0.03)]), 0.024, 0.007), metal)
		b.attach(ll, pad, Transform3D(Basis(Vector3.RIGHT, -0.12), kp + Vector3(0, 0.0, 0.052)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.014, 0.014), 0.03), orange), Transform3D(Basis(), kp + Vector3(0, 0.005, 0.066)))
	# --- tool belt: leather, steel buckle, pouches, a wrench on the left hip
	L.ring(b, "Hips", hips + Vector3(0, 0.0, 0), 0.145, 0.038, leather, 0.84)
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.045, 0.036, 0.012)), steel), Transform3D(Basis(), hips + Vector3(0, 0.0, 0.125)))
	for a_deg: float in [40.0, 140.0, 215.0, 250.0]:
		var a := deg_to_rad(a_deg)
		L.pouch(b, "Hips", hips + Vector3(cos(a) * 0.158, -0.035, sin(a) * 0.14), dark, orange, Vector3(0.055, 0.065, 0.035))
	var wrench := Node3D.new()
	AnimeGear.mi(AnimeGear.box(Vector3(0.018, 0.17, 0.008)), steel, wrench)
	AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.025, 0.0), Vector2(-0.01, 0.0), Vector2(-0.01, 0.02), Vector2(0.01, 0.02), Vector2(0.01, 0.0), Vector2(0.025, 0.0), Vector2(0.02, 0.04), Vector2(-0.02, 0.04)]), 0.01), steel, wrench, Transform3D(Basis(), Vector3(0, 0.08, 0)))
	b.attach("Hips", wrench, Transform3D(Basis(Vector3.UP, 1.4) * Basis(Vector3.BACK, 0.25), hips + Vector3(0.155, -0.1, 0.02)))
	# --- gunmetal utility over-skirt with an orange hem (buries the base's lace hem)
	L.shell(b, "Hips", [Vector2(0.29, -0.27), Vector2(0.25, -0.15), Vector2(0.19, -0.04), Vector2(0.152, 0.02)], hips, dark, 0.0, 1.0, 0.9, 28)
	L.ring(b, "Hips", hips + Vector3(0, -0.258, 0), 0.292, 0.028, orange, 0.9, 28)
	# --- orange work jacket tied round the waist: knotted band + two hanging sleeves (cloth) + back panel
	L.ring(b, "Hips", hips + Vector3(0, -0.04, 0), 0.162, 0.05, orange, 0.86)
	var knot := AnimeGear.mi(AnimeGear.sphere(0.03, 10), orange)
	knot.scale = Vector3(1.3, 0.9, 0.8)
	b.attach("Hips", knot, Transform3D(Basis(), hips + Vector3(-0.04, -0.045, 0.14)))
	var cols := [["Hips", 0.17, -0.05], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.075, -0.1], ["LeftLowerLeg", 0.075, -0.1]]
	for k in 2:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(-0.055 + k * 0.03, -0.06, 0.145)), {
			"name": "JacketSleeve", "length": 0.5 - k * 0.08, "segments": 7, "width": [0.07, 0.075, 0.08, 0.085, 0.09],
			"dir": Vector3(-0.2 + k * 0.3, -1.0, 0.12), "side": Vector3(1, 0, 0.2), "material": orange, "thickness": 0.03,
			"stiffness": 0.05, "stiffness_tip": 0.01, "gravity": 9.0, "drag": 0.08, "colliders": cols})
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0.0, -0.05, -0.15)), {
		"name": "JacketBack", "length": 0.36, "segments": 7, "width": [0.26, 0.27, 0.28, 0.26, 0.14], "dir": Vector3(0, -1.0, -0.2),
		"side": Vector3(1, 0, 0), "material": orange, "lining": dark, "thickness": 0.014, "stiffness": 0.05,
		"stiffness_tip": 0.012, "gravity": 9.0, "drag": 0.08, "colliders": cols})
	# --- welding goggles pushed up on the hair
	b.attach("Head", AnimeGear.mi(AnimeGear.lathe([Vector2(0.104, -0.016), Vector2(0.107, 0.016)], 24, 1.0, 1.1), dark), Transform3D(Basis(Vector3.RIGHT, -0.4), head + Vector3(0, 0.11, 0.0)))
	for side: float in [-1.0, 1.0]:
		var gg := Node3D.new()
		AnimeGear.mi(AnimeGear.cyl(0.036, 0.04, 0.034, 16), metal, gg, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		AnimeGear.mi(AnimeGear.cyl(0.04, 0.04, 0.01, 16), orange, gg, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.014)))
		AnimeGear.mi(AnimeGear.cyl(0.028, 0.028, 0.036, 16), lens, gg, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.004)))
		b.attach("Head", gg, Transform3D(Basis(Vector3.RIGHT, -0.62), head + Vector3(side * 0.048, 0.175, 0.08)))
	# --- the hero element: backpack drone rig
	var pack := Node3D.new()
	pack.name = "DroneRig"
	AnimeGear.mi(AnimeGear.box(Vector3(0.25, 0.3, 0.12)), metal, pack)
	AnimeGear.mi(AnimeGear.box(Vector3(0.2, 0.08, 0.125)), orange, pack, Transform3D(Basis(), Vector3(0, 0.08, 0.002)))
	AnimeGear.mi(AnimeGear.box(Vector3(0.27, 0.03, 0.13)), dark, pack, Transform3D(Basis(), Vector3(0, -0.14, 0)))
	for side: float in [-1.0, 1.0]:
		# twin thrusters with a glowing nozzle
		AnimeGear.mi(AnimeGear.cyl(0.04, 0.05, 0.26, 14), dark, pack, Transform3D(Basis(), Vector3(side * 0.15, -0.04, -0.03)))
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.05, -0.155), Vector2(0.056, -0.13), Vector2(0.052, -0.12)], 14), orange, pack, Transform3D(Basis(), Vector3(side * 0.15, -0.04, -0.03)))
		AnimeGear.mi(AnimeGear.cyl(0.035, 0.035, 0.01, 14), AnimeGear.glow(Color("#FFB040"), 2.5), pack, Transform3D(Basis(), Vector3(side * 0.15, -0.205, -0.03)))
		# swept fins
		var fin := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0.0), Vector2(0.13, 0.11), Vector2(0.03, 0.05)]), 0.01, 0.002), metal, pack)
		fin.transform = Transform3D(Basis(Vector3.UP, -side * PI / 2) * Basis(Vector3.BACK, 0.0), Vector3(side * 0.13, 0.06, -0.02))
		if side > 0:
			fin.scale = Vector3(-1, 1, 1)
	# antenna with an orange beacon (left)
	AnimeGear.mi(AnimeGear.cyl(0.006, 0.008, 0.32, 6), steel, pack, Transform3D(Basis(Vector3.BACK, -0.12), Vector3(0.1, 0.3, -0.03)))
	AnimeGear.mi(AnimeGear.sphere(0.016, 10), AnimeGear.glow(ORANGE, 2.5), pack, Transform3D(Basis(), Vector3(0.12, 0.46, -0.03)))
	# articulated manipulator arm rising over the right shoulder, three-finger claw
	var arm_pts: Array = [Vector3(-0.08, 0.13, -0.02), Vector3(-0.12, 0.3, -0.05), Vector3(-0.14, 0.4, 0.05), Vector3(-0.15, 0.42, 0.16)]
	for i in 3:
		var a: Vector3 = arm_pts[i]
		var c: Vector3 = arm_pts[i + 1]
		var seg := AnimeGear.mi(AnimeGear.cyl(0.022 - i * 0.004, 0.026 - i * 0.004, (c - a).length(), 10), metal if i != 1 else orange, pack)
		seg.transform = Transform3D(Basis(Quaternion(Vector3.UP, (c - a).normalized())), (a + c) * 0.5)
		AnimeGear.mi(AnimeGear.sphere(0.03 - i * 0.004, 10), dark, pack, Transform3D(Basis(), c))
	for k in 3:
		var fa := TAU * k / 3.0
		var claw := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.006, 0.0), Vector2(0.006, 0.0), Vector2(0.012, 0.04), Vector2(0.0, 0.06)]), 0.008), steel, pack)
		claw.transform = Transform3D(Basis(Vector3.BACK, 0.0) * Basis(Vector3.RIGHT, PI / 2 - 0.3) * Basis(Vector3.FORWARD, fa), arm_pts[3] + Vector3(cos(fa) * 0.015, sin(fa) * 0.015, 0.01))
	b.attach("UpperChest", pack, Transform3D(Basis(), uc + Vector3(0, -0.03, -0.2)))
	# docked scout drone hovering over the left shoulder
	var drone := Node3D.new()
	drone.name = "ScoutDrone"
	var bd := AnimeGear.mi(AnimeGear.sphere(0.05, 14), metal, drone)
	bd.scale = Vector3(1.2, 0.7, 1.0)
	AnimeGear.mi(AnimeGear.sphere(0.02, 10), AnimeGear.glow(Color("#7FE8FF"), 2.5), drone, Transform3D(Basis(), Vector3(0, -0.005, 0.045)))
	for side: float in [-1.0, 1.0]:
		AnimeGear.mi(AnimeGear.box(Vector3(0.07, 0.012, 0.02)), dark, drone, Transform3D(Basis(), Vector3(side * 0.07, 0.01, 0)))
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.045, -0.006), Vector2(0.048, 0.006)], 16), orange, drone, Transform3D(Basis(), Vector3(side * 0.11, 0.018, 0)))
	b.attach("UpperChest", drone, Transform3D(Basis(Vector3.UP, -0.4), uc + Vector3(0.26, 0.4, -0.1)))
