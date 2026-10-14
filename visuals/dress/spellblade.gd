extends RefCounted
## Spellblade 魔剑士 (无浪 / Samsara colour cues), bible 2.5: rune-etched short sword with a magic circle at the hilt
## (WeaponFactory "short_sword"). Teal / white / gold: a fitted teal battle coat over a white high-collared shirt,
## long split coat tails with a white lining (runtime cloth, the hero element), white gauntlets, dark tights and
## white-gold boots, one swept pauldron on the off arm and a floating cyan rune ring on the off hand.
## The base's school uniform is buried: tie and skirt hidden, vest/shirt recoloured and covered by the coat.

const L := preload("res://visuals/dress/_swordmage_lib.gd")
const TEAL := Color("#147A82")
const DEEP := Color("#0A3238")
const WHITE := Color("#EDEDE6")
const RUNE := Color("#5FE6E0")


static func dress() -> Dictionary:
	return {
		"base": "sendagaya_shino",
		"height": 1.75,
		"proportions": [1.07, 0.95],
		"rim": Color(0.8, 0.98, 1.0),
		"dress": {
			# vest + shirt -> one white mid-layer under the coat; tie + pleated skirt hidden; socks -> dark teal; hair -> silver
			"Tops": {"map": [Color("#8FA6AE"), Color("#E2EAEA"), Color("#FFFFFF")], "contrast": 1.15},
			"Accessory": {"hide": true},
			"Bottoms": {"hide": true},
			"Shoes": {"map": [Color("#0E2C32"), Color("#1E4A50"), Color("#D8E4E4")], "contrast": 1.2},
			"HAIR": {"map": [Color("#7A949C"), Color("#CFE2E4"), Color("#FAFFFF")], "contrast": 1.1, "line": 1.7, "shade": Color(0.62, 0.66, 0.9)},
			"Brow": {"color": Color("#7A8C94")},
			"EyeIris": {"iris": Color(0.5, 1.05, 1.1)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"], &"cast": ["Spell_Simple_Shoot"]},
		"grips": {"short_sword": {"kind": "blade", "tilt": 0.0}},
	}


static func build(b: AnimeBody) -> void:
	var teal := AnimeGear.toon(TEAL, {"shade": Color("#0A3A5A") / TEAL, "rim": Color(0.8, 1.0, 1.0)})
	var deep := AnimeGear.toon(DEEP, {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.7, 0.95, 1.0)})
	var white := AnimeGear.toon(WHITE, {"shade": Color("#9AAEC8") / WHITE, "rim": Color.WHITE})
	var gold := AnimeGear.gold()
	var rune := AnimeGear.toon(RUNE, {"emit": RUNE * 1.3, "outline": false})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var sp := b.bone_pos("Spine")
	var neck := b.bone_pos("Neck")
	# --- fitted teal coat bodice, open at the front over the white shirt, gold edge
	var y0 := sp.y - 0.06
	var y1 := uc.y + 0.1
	var bod := [Vector2(0.155, y0 - uc.y), Vector2(0.143, sp.y - uc.y), Vector2(0.165, ch.y - uc.y), Vector2(0.178, 0.02), Vector2(0.16, 0.07), Vector2(0.11, y1 - uc.y)]
	b.attach("UpperChest", L.shell(bod, 0.07, teal, 24, 0.95), Transform3D(Basis(), uc))
	for side: float in [-1.0, 1.0]:
		# gold lapel edges down both sides of the opening
		var e: Array = []
		var ew: Array = []
		var es: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var prof: Vector2 = bod[i]
			var a := PI * 0.5 - side * TAU * 0.035
			e.append(uc + Vector3(cos(a) * prof.x * 1.01, prof.y, sin(a) * prof.x * 0.95 + 0.004))
			ew.append(0.022)
			es.append(Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5) * 0.95))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon(e, ew, es, 0.01), gold), Transform3D.IDENTITY)
	b.attach("UpperChest", L.shell([Vector2(0.11, y1 - uc.y - 0.012), Vector2(0.104, y1 - uc.y + 0.008)], 0.07, gold, 24, 0.95), Transform3D(Basis(), uc))
	# gold frog buttons across the coat opening (Chinese seasoning)
	for k in 3:
		var prof: Vector2 = bod[k + 1]
		var fz := uc.z + prof.x * 0.95 + 0.012
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.007, 0.007, 0.06, 6), gold), Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, uc.y + prof.y, fz)))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.011, 8), gold), Transform3D(Basis(), Vector3(0.0, uc.y + prof.y, fz + 0.004)))
	# white mandarin collar with a gold rim and a teal gem
	b.attach("UpperChest", L.shell([Vector2(0.074, -0.05), Vector2(0.082, 0.02), Vector2(0.088, 0.055)], 0.08, white, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, 0)))
	b.attach("UpperChest", L.shell([Vector2(0.088, 0.05), Vector2(0.091, 0.066)], 0.08, gold, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, 0)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.016, 0.022), 0.014, 0.003), rune), Transform3D(Basis(), neck + Vector3(0, -0.06, 0.085)))
	# --- long sleeves: teal upper sleeves, white gauntlets with gold flares
	for side: float in [-1.0, 1.0]:
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, ua, la, [0.052, 0.048, 0.044, 0.042], -0.05, 1.0, teal, null, 12)
		ClassDress.limb_guard(b, la, hd, [0.04, 0.044, 0.05, 0.058], 0.0, 1.0, white, gold, 12)
		var lp := b.bone_pos(la)
		var hp := b.bone_pos(hd)
		b.attach(la, AnimeGear.mi(AnimeGear.extrude(L.fin(0.14, 0.05), 0.01, 0.0), gold), Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, PI if side > 0 else 0.0), lp.lerp(hp, 0.7) + Vector3(0, 0.05, 0)))
	# one swept teal/gold pauldron on the off arm, a small white cap on the sword arm
	ClassDress.pauldron(b, 1.0, teal, gold, 0.98, 2, true)
	ClassDress.pauldron(b, -1.0, white, gold, 0.72, 1, false)
	# --- waist: white sash, gold buckle with a rune gem; dark shorts shell + dark tights on the legs
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.155, -0.1), Vector2(0.158, -0.02), Vector2(0.148, 0.06)], 24, 1.0, 0.84), deep), Transform3D(Basis(), hips))
	# short teal peplum, open at the front, gold hem (the long tails hang behind it)
	var pep := [Vector2(0.235, -0.2), Vector2(0.19, -0.1), Vector2(0.158, 0.0), Vector2(0.152, 0.05)]
	b.attach("Hips", L.shell(pep, 0.34, teal, 26, 0.86), Transform3D(Basis(), hips))
	b.attach("Hips", L.shell([Vector2(0.238, -0.21), Vector2(0.232, -0.185)], 0.34, gold, 26, 0.86), Transform3D(Basis(), hips))
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.153, 0.0), Vector2(0.15, 0.05)], 24, 1.0, 0.84), white), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.cyl(0.03, 0.03, 0.014, 6), gold), Transform3D(Basis(Vector3.RIGHT, PI / 2), hips + Vector3(0, 0.045, 0.13)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.012, 0.016), 0.01), rune), Transform3D(Basis(), hips + Vector3(0, 0.045, 0.14)))
	for side: float in [-1.0, 1.0]:
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ul, ll, [0.088, 0.082, 0.07, 0.06], -0.02, 1.02, deep, null, 14)
		ClassDress.limb_guard(b, ll, ft, [0.058, 0.054, 0.046, 0.04], 0.0, 0.5, deep, null, 12)
		var kp := b.bone_pos(ll)
		var fp := b.bone_pos(ft)
		# white boot shafts with a pointed gold-rimmed cuff under the knee
		ClassDress.limb_guard(b, ll, ft, [0.05, 0.049, 0.044, 0.042], 0.12, 0.98, white, gold, 12)
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(L.knee_plate(0.036), 0.018, 0.004), white), Transform3D(Basis(Vector3.RIGHT, -0.1), kp + Vector3(0, -0.02, 0.05)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.01, 0.016), 0.024), gold), Transform3D(Basis(), kp + Vector3(0, -0.005, 0.06)))
	# --- hero element: long split coat tails, teal with a white lining (runtime cloth)
	var cols := [["Hips", 0.19, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.08, -0.1], ["LeftLowerLeg", 0.08, -0.1]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.075, 0.04, -0.13)), {
			"name": "CoatTail", "length": 0.95, "segments": 10, "width": [0.15, 0.17, 0.2, 0.22, 0.2, 0.06], "dir": Vector3(side * 0.12, -1.0, -0.2),
			"side": Vector3(1, 0, 0), "material": teal, "lining": white, "thickness": 0.012, "stiffness": 0.04, "stiffness_tip": 0.006,
			"gravity": 9.0, "drag": 0.08, "wind": Vector3(side * 0.3, 0, -0.6), "colliders": cols})
	# gold rune clasp on the back where the tails split
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(0.7), 0.012, 0.002), gold), Transform3D(Basis(Vector3.UP, PI), hips + Vector3(0, 0.05, -0.15)))
	# --- floating rune ring on the off hand (spins; the blade carries the hilt circle)
	var lh := b.bone_pos("LeftHand")
	var la2 := b.bone_pos("LeftLowerArm")
	var f := L.floater(1.4, 0.0, 1.0)
	b.attach("LeftLowerArm", f, Transform3D(Basis(Quaternion(Vector3.UP, (lh - la2).normalized())), la2.lerp(lh, 0.45)))
	L.keep(AnimeGear.lathe([Vector2(0.085, -0.003), Vector2(0.092, 0.003)], 28), AnimeGear.glow(RUNE, 2.2, true, 0.75), f)
	for k in 4:
		var a := TAU * k / 4.0
		L.keep(AnimeGear.extrude(AnimeGear.star_poly(0.014, 4, 0.35), 0.006), AnimeGear.glow(RUNE.lightened(0.3), 3.0), f, Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, PI / 2), Vector3(cos(a) * 0.088, 0, sin(a) * 0.088)))
