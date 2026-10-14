extends RefCounted
## Brawler 流氓, bible 2.5: street-fighter look - a long purple coat thrown over the shoulders like a cape with its
## sleeves hanging empty (the hero silhouette, runtime cloth), turned-up collar, chains, studded belt, one spiked
## shoulder plate; purple and mustard with steel trim; bleached spiky hair. Claw gauntlets (WeaponFactory "claws").

const P := preload("res://visuals/dress/_night_lib.gd")
const PURPLE := Color("#5A2E6E")
const PURPLE_D := Color("#2A1436")
const MUSTARD := Color("#D8A830")


static func dress() -> Dictionary:
	return {
		"base": "hairsample_male",
		"height": 1.85,
		"proportions": [1.06, 0.94],
		"rim": Color(1.0, 0.88, 0.72),
		"dress": {
			# hoodie -> plum-black under-shirt, trousers -> dark purple, shoes -> mustard-laced street boots
			"Tops": {"map": [Color("#0A060E"), Color("#1A0E22"), Color("#30203E")], "contrast": 1.15},
			"Bottoms": {"map": [Color("#0C0710"), Color("#1E1226"), Color("#3E2A4C")], "contrast": 1.2},
			"Shoes": {"map": [Color("#140C08"), Color("#3A2614"), Color("#D8A830")], "contrast": 1.2},
			"HAIR": {"map": [Color("#6A5010"), Color("#DDB540"), Color("#FFF4B8")], "contrast": 1.1, "line": 1.8, "shade": Color(0.78, 0.6, 0.62)},
			"Brow": {"color": Color("#6A4410")},
			"EyeIris": {"iris": Color(1.15, 0.85, 0.35)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Punch_Cross"], &"taunt": ["Angry"]},
	}


static func build(b: AnimeBody) -> void:
	var purple := AnimeGear.toon(PURPLE, {"shade": Color(0.6, 0.5, 0.9), "rim": Color(1.0, 0.85, 0.7)})
	var purple_d := AnimeGear.toon(PURPLE_D, {"shade": Color(0.65, 0.6, 0.9)})
	var mustard := AnimeGear.toon(MUSTARD, {"shade": ClassDress.GOLD_SHADE / MUSTARD, "rim": ClassDress.GOLD_HI})
	var steel := AnimeGear.steel(ClassDress.SILVER)
	var leather := AnimeGear.toon(Color("#2A1A14"), {"shade": Color(0.7, 0.6, 0.85)})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	# --- coat yoke draped over the shoulders (back half shell) + turned-up collar
	var yoke := [Vector2(0.2, uc.y - 0.1 - uc.y), Vector2(0.21, 0.03), Vector2(0.19, 0.1), Vector2(0.13, neck.y - uc.y - 0.02)]
	P.shell(b, "UpperChest", uc, yoke, purple, TAU * 0.62, 0.78, 0.0, 24)
	var collar := [Vector2(0.105, -0.06), Vector2(0.115, 0.0), Vector2(0.14, 0.08), Vector2(0.16, 0.13)]
	P.shell(b, "UpperChest", neck, collar, purple, TAU * 0.7, 1.0, 0.0, 22)
	P.shell(b, "UpperChest", neck, [Vector2(0.158, 0.125), Vector2(0.165, 0.145)], mustard, TAU * 0.7, 1.0, 0.0, 22)
	# coat front lapels hanging open over the chest (short panels from the shoulders)
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		for i in 6:
			var t := float(i) / 5.0
			pts.append(Vector3(side * lerpf(0.13, 0.15, t), lerpf(neck.y - 0.03, ch.y - 0.12, t), lerpf(0.06, 0.135, sqrt(t))))
		P.strap(b, "UpperChest", pts, 0.085, purple, 0.014)
		var ed: Array = []
		for p: Vector3 in pts:
			ed.append(p + Vector3(-side * 0.044, 0, 0.004))
		P.strap(b, "UpperChest", ed, 0.014, mustard, 0.016)
	# --- the hero element: the coat body as a long cape (purple, mustard lining) + two empty sleeves
	var cols := [["UpperChest", 0.18, 0.0], ["Hips", 0.21, 0.0], ["RightUpperLeg", 0.11, -0.15], ["LeftUpperLeg", 0.11, -0.15], ["RightLowerLeg", 0.09, -0.12], ["LeftLowerLeg", 0.09, -0.12]]
	# two back panels with a centre vent so the coat swings like a coat, not a board
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(side * 0.105, 0.08, -0.165)), {
			"name": "CoatCape", "length": 1.12 if side < 0 else 1.06, "segments": 12, "width": [0.24, 0.28, 0.31, 0.33],
			"dir": Vector3(side * 0.12, -1.0, -0.22), "side": Vector3(1, 0, side * 0.25), "material": purple, "lining": mustard,
			"thickness": 0.014, "stiffness": 0.03, "stiffness_tip": 0.003, "gravity": 9.0, "drag": 0.08,
			"wind": Vector3(0.4 + side * 0.2, 0, -0.8), "colliders": cols})
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(side * 0.2, 0.08, -0.05)), {
			"name": "EmptySleeve", "length": 0.62, "segments": 8, "width": [0.13, 0.12, 0.11], "dir": Vector3(side * 0.15, -1.0, -0.15),
			"side": Vector3(0, 0, 1), "material": purple, "thickness": 0.03, "stiffness": 0.04, "stiffness_tip": 0.006,
			"gravity": 9.0, "drag": 0.08, "wind": Vector3(0.3, 0, -0.5), "colliders": cols})
		# mustard cuff at the sleeve end is painted by a band near the shoulder seam (sleeves are plain cloth)
	# --- spiked shoulder plate on the right shoulder (steel), mustard rim
	ClassDress.pauldron(b, -1.0, purple_d, mustard, 1.1, 2, false)
	var sh := b.bone_pos("RightUpperArm")
	for k in 3:
		var sp := AnimeGear.mi(AnimeGear.extrude(P.spike(0.075 - k * 0.012, 0.02), 0.018, 0.004), steel)
		b.attach("RightUpperArm", sp, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(40.0 + k * 22.0)), sh + Vector3(-0.05 - k * 0.025, 0.09 - k * 0.025, -0.01 + (k - 1) * 0.035)))
	# --- chains: one across the chest (left shoulder -> right hip), a hanging loop from the belt
	var chest_pts := [Vector3(0.14, neck.y - 0.02, 0.04), Vector3(0.08, uc.y + 0.02, 0.13), Vector3(-0.02, ch.y - 0.02, 0.15), Vector3(-0.12, hips.y + 0.07, 0.13)]
	P.chain(b, "UpperChest", chest_pts, steel, 0.026)
	var hip_pts := [hips + Vector3(-0.16, 0.0, 0.06), hips + Vector3(-0.19, -0.12, 0.02), hips + Vector3(-0.17, -0.18, -0.06), hips + Vector3(-0.12, -0.02, -0.13)]
	P.chain(b, "Hips", hip_pts, steel, 0.024)
	# --- studded belt with a big mustard buckle, hip pouch
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.162, -0.025), Vector2(0.166, 0.0), Vector2(0.162, 0.025)], 26, 1.0, 0.84), leather), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	for k in 9:
		var a := deg_to_rad(-120.0 + k * 30.0)
		if absf(a) < 0.2:
			continue
		b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.009, 6), steel), Transform3D(Basis(), hips + Vector3(sin(a) * 0.168, 0.02, cos(a) * 0.168 * 0.84)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.07, 0.05, 0.015)), mustard), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.14)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.04, 0.022, 0.018)), leather), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.143)))
	P.pouch(b, leather, mustard, 1.9, Vector3(0.07, 0.075, 0.045), -0.03, 0.17)
	# --- knee pads (steel-rimmed purple) and mustard ankle wraps
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		P.knee(b, ll, purple_d, mustard, 1.0, 0.075)
		P.wraps(b, ll, ft, 0.058, 0.054, 0.78, 0.94, 2, mustard, 0.2)
	# --- street track stripes (mustard) down the outside of the trousers
	for side: float in [-1.0, 1.0]:
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		var a := b.bone_pos(ul)
		var k := b.bone_pos(ll)
		var f := b.bone_pos(ft)
		var up: Array = []
		var lo: Array = []
		for i in 5:
			var t := float(i) / 4.0
			up.append(a.lerp(k, t) + Vector3(side * lerpf(0.088, 0.066, t), 0.0, -0.005))
			lo.append(k.lerp(f, t * 0.8) + Vector3(side * lerpf(0.064, 0.056, t), 0.0, -0.01))
		P.strap(b, ul, up, 0.02, mustard, 0.006)
		P.strap(b, ll, lo, 0.02, mustard, 0.006)
	# --- bandaged upper arms under the coat (the claws cover the forearms)
	for side: float in [-1.0, 1.0]:
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		P.wraps(b, ua, la, 0.058, 0.052, 0.55, 0.95, 3, AnimeGear.toon(Color("#ECE6DA"), {"shade": Color("#A9B3D6") / Color("#ECE6DA")}), 0.25)
	# --- Chinese seasoning: a red rope knot with tassel hanging from the coat collar
	var rope := AnimeGear.toon(Color("#C8202A"), {"shade": Color("#7A0F2E") / Color("#C8202A")})
	var kp := neck + Vector3(0.13, -0.08, 0.1)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.018, 8), rope), Transform3D(Basis(), kp))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.tube([kp, kp + Vector3(0.005, -0.06, 0.01), kp + Vector3(0.01, -0.1, 0.012)], [0.006, 0.006, 0.005], 6), rope), Transform3D.IDENTITY)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.004, 0.016, 0.055, 8), rope), Transform3D(Basis(), kp + Vector3(0.01, -0.125, 0.012)))
