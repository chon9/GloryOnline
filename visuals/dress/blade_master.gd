extends RefCounted
## Blade Master 剑客 (夜雨声烦 type), bible 2.5: silver cuirass with gold trim, royal-blue cape with a white lining
## (runtime cloth), gold hair with an ahoge, light sword with a glowing ice-cyan blade (WeaponFactory "lightsaber").

const SILVER := Color("#AEBACB")
const ROYAL := Color("#1F5FBF")
const NAVY := Color("#16224A")


static func dress() -> Dictionary:
	return {
		"base": "sakurada",
		"height": 1.82,
		"proportions": [1.07, 0.94],
		"rim": Color(0.85, 0.93, 1.0),
		# 夜雨声烦: cocky open grin, wide eyes (Battle Mage shares the base but is stern and half-lidded)
		"face": {"joy": 0.45, "surprised": 0.15},
		"dress": {
			# jacket/vest -> royal-blue tunic, shirt -> white; trousers -> navy; shoes -> silver sabatons; hair -> gold
			"Tops": {"map": [Color("#0B1A44"), Color("#1F5FBF"), Color("#F2F4F8")], "contrast": 1.35},
			"Accessory": {"map": [Color("#5A3A0A"), Color("#D8B25A"), Color("#FFE9A8")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#070B1C"), Color("#121A38"), Color("#33406A")], "contrast": 1.2},
			"Shoes": {"map": [Color("#3A4250"), Color("#9AA6B8"), Color("#F0F4FA")], "contrast": 1.2},
			"HAIR": {"map": [Color("#7A4A0E"), Color("#E3B13E"), Color("#FFF2B8")], "contrast": 1.15, "line": 1.7, "shade": Color(0.75, 0.6, 0.62)},
			"Brow": {"color": Color("#8A5A20")},
			"EyeIris": {"iris": Color(0.65, 0.85, 1.25)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"]},
		"grips": {"lightsaber": {"kind": "blade", "tilt": 0.0}},
	}


static func build(b: AnimeBody) -> void:
	var silver := AnimeGear.toon(SILVER, {"shade": Color("#7C88A0") / SILVER, "rim": Color.WHITE, "rim_strength": 0.9})
	var gold := AnimeGear.gold()
	var blue := AnimeGear.toon(ROYAL, {"shade": Color(0.5, 0.5, 0.92)})
	var white := AnimeGear.toon(Color("#F2F0EA"), {"shade": Color("#A9B3D6") / Color("#F2F0EA")})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- silver cuirass: chest shell with a centre ridge, gold neckline and waist rims
	var y0 := ch.y - 0.1
	var y1 := uc.y + 0.12
	var cuirass := AnimeGear.mi(AnimeGear.lathe([Vector2(0.135, y0 - uc.y), Vector2(0.15, ch.y - uc.y), Vector2(0.162, 0.03), Vector2(0.15, 0.09), Vector2(0.11, y1 - uc.y)], 22, 1.0, 0.86), silver)
	b.attach("UpperChest", cuirass, Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.112, y1 - uc.y - 0.012), Vector2(0.104, y1 - uc.y + 0.008)], 22, 1.0, 0.86), gold), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.137, y0 - uc.y - 0.012), Vector2(0.137, y0 - uc.y + 0.014)], 22, 1.0, 0.86), gold), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.012, y0 - uc.y), Vector2(0.012, y0 - uc.y), Vector2(0.008, y1 - uc.y - 0.02), Vector2(-0.008, y1 - uc.y - 0.02)]), 0.016), gold), Transform3D(Basis(), uc + Vector3(0, 0, 0.142)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(1.15), 0.012, 0.002), gold), Transform3D(Basis(), uc + Vector3(0, 0.02, 0.145)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.016, 10), AnimeGear.toon(Color("#7FE8FF"), {"emit": Color("#2F9BFF") * 1.5, "outline": false})), Transform3D(Basis(), uc + Vector3(0, 0.03, 0.155)))
	# --- pauldrons: silver plates, gold rims; bigger on the sword arm
	ClassDress.pauldron(b, -1.0, silver, gold, 1.08, 3)
	ClassDress.pauldron(b, 1.0, silver, gold, 0.98, 2)
	# --- gauntlets and greaves
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.04, 0.046, 0.054, 0.06], 0.3, 1.0, silver, gold, 14)
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.07, 0.062, 0.052, 0.048], 0.0, 0.9, silver, gold, 14)
		var kp := b.bone_pos(ll)
		# pointed knee guard with a swept fin
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.05, -0.04), Vector2(0.05, -0.04), Vector2(0.055, 0.03), Vector2(0.0, 0.1), Vector2(-0.055, 0.03)]), 0.02, 0.006), silver)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, 0.07)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.014, 0.02), 0.026), gold), Transform3D(Basis(), kp + Vector3(0, 0.02, 0.083)))
	# --- tassets: two short plates over the hips + blue sash with gold buckle
	for side: float in [-1.0, 1.0]:
		var tp := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.06, -0.16), Vector2(0.0, -0.2), Vector2(-0.06, -0.16)])
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(tp, 0.016, 0.004), silver), Transform3D(Basis(Vector3.UP, side * 0.55) * Basis(Vector3.RIGHT, -0.12), hips + Vector3(side * 0.1, -0.02, 0.1)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.158, -0.03), Vector2(0.162, 0.025)], 24, 1.0, 0.82), blue), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.04, 0.045), 0.02, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.13)))
	# --- the hero element: royal-blue cape with a white lining, clasped at both shoulders
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(0, 0.1, -0.13)), {
		"name": "Cape", "length": 1.18, "segments": 12, "width": [0.36, 0.5, 0.6, 0.64], "dir": Vector3(0, -1.0, -0.22),
		"side": Vector3(1, 0, 0), "material": blue, "lining": white, "thickness": 0.014,
		"stiffness": 0.035, "stiffness_tip": 0.004, "gravity": 9.0, "drag": 0.08, "wind": Vector3(0.5, 0, -0.6),
		"colliders": [["UpperChest", 0.17, 0.0], ["Hips", 0.2, 0.0], ["RightUpperLeg", 0.11, -0.15], ["LeftUpperLeg", 0.11, -0.15], ["RightLowerLeg", 0.09, -0.1], ["LeftLowerLeg", 0.09, -0.1]]})
	for side: float in [-1.0, 1.0]:
		var c := AnimeGear.mi(AnimeGear.cyl(0.03, 0.03, 0.014, 14), gold)
		b.attach("UpperChest", c, Transform3D(Basis(Vector3.RIGHT, PI / 2), uc + Vector3(side * 0.11, 0.1, 0.1)))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.012, 8), AnimeGear.toon(Color("#7FE8FF"), {"emit": Color("#2F9BFF"), "outline": false})), Transform3D(Basis(), uc + Vector3(side * 0.11, 0.1, 0.11)))
	# blue collar band under the clasps
	var col := AnimeGear.mi(AnimeGear.lathe([Vector2(0.1, -0.04), Vector2(0.115, 0.02), Vector2(0.12, 0.05)], 20, 1.0, 1.0, TAU * 0.8), blue)
	col.rotation.y = PI * 0.5 + TAU * 0.1
	b.attach("UpperChest", ClassDress.wrap(col), Transform3D(Basis(), neck + Vector3(0, -0.03, -0.005)))
	# --- ahoge: one swept gold lock rising from the crown (Huang Shaotian's silhouette hook)
	var hair := AnimeGear.toon(Color("#E3B13E"), {"shade": Color(0.78, 0.6, 0.6), "rim": Color("#FFF2B8")})
	var lock := PackedVector2Array([Vector2(-0.012, 0.0), Vector2(0.014, 0.0), Vector2(0.03, 0.05), Vector2(0.02, 0.1), Vector2(-0.025, 0.14), Vector2(0.0, 0.09), Vector2(0.004, 0.045)])
	b.attach("Head", AnimeGear.mi(AnimeGear.extrude(lock, 0.012, 0.003), hair), Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.3), head + Vector3(0.0, 0.2, 0.0)))
