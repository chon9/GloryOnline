extends RefCounted
## Unspecialized 散人 (君莫笑 type), bible 2.5: long red scarf trailing 1.5-2 m with torn ends (runtime cloth),
## mismatched navy/gold plate over a white-silver under-plate, transforming 千机伞 (WeaponFactory "umbrella",
## "umbrella_open", "umbrella_gun").

const NAVY := Color("#1E2440")
const UNDER := Color("#DCE2EA")
const SCARF := Color("#C8202A")


static func dress() -> Dictionary:
	return {
		"base": "hairsample_male",
		"height": 1.86,
		"proportions": [1.07, 0.94],
		"rim": Color(1.0, 0.88, 0.7),
		# the HairSample_Male hoodie hood never shows under the costume: cull it (character space, relative to Neck)
		"cull": [{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.22, -0.16, -0.3), "max": Vector3(0.22, 0.2, -0.11)},
			{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.25, -0.06, -0.35), "max": Vector3(0.25, 0.35, 0.03)}],
		# Ye Xiu: lazy half-lidded, faint smirk
		"face": {"blink": 0.38, "fun": 0.12},
		"dress": {
			# hoodie -> navy gambeson, trousers -> dark navy, shoes -> black boots; hair -> warm black-brown
			"Tops": {"map": [Color("#05060C"), Color("#0E1226"), Color("#262E52")], "contrast": 1.15},
			"Bottoms": {"map": [Color("#06070E"), Color("#141828"), Color("#3A4058")], "contrast": 1.2},
			"Shoes": {"map": [Color("#0A0808"), Color("#221A16"), Color("#5A4A3A")], "contrast": 1.2},
			"HAIR": {"map": [Color("#0A0807"), Color("#231B18"), Color("#5E4B42")], "contrast": 1.05, "line": 1.7, "shade": Color(0.55, 0.5, 0.7)},
			"EyeIris": {"iris": Color(0.72, 0.58, 0.5)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"]},
		"weapon_anims": {"umbrella_gun": {&"idle": ["Idle_Sword", "Pistol_Idle"], &"attack": ["Pistol_Shoot"]}},
		"grips": {
			"umbrella": {"kind": "pole", "tilt": 0.0, "two_hand": true},
			"umbrella_open": {"kind": "pole", "tilt": 15.0},
			"umbrella_gun": {"kind": "gun", "pitch": 0.0},
		},
	}


static func build(b: AnimeBody) -> void:
	var navy := AnimeGear.toon(NAVY, {"shade": Color("#10122A") / NAVY, "rim": Color(0.75, 0.82, 1.0), "rim_strength": 0.8})
	var under := AnimeGear.toon(UNDER, {"shade": Color("#7C88A0") / UNDER, "rim": Color.WHITE, "rim_strength": 0.8})
	var gold := AnimeGear.gold()
	var red := AnimeGear.toon(SCARF, {"shade": Color("#7A0F2E") / SCARF, "rim": Color(1.0, 0.75, 0.6)})
	var leather := AnimeGear.toon(ClassDress.LEATHER)
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	# --- navy breastplate over a silver under-plate, gold rims and a chest gem
	var y0 := ch.y - 0.12
	var y1 := uc.y + 0.1
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.175, y0 - uc.y - 0.04), Vector2(0.18, y0 - uc.y + 0.02)], 22, 1.0, 0.84), under), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.172, y0 - uc.y), Vector2(0.188, ch.y - uc.y), Vector2(0.198, 0.03), Vector2(0.182, 0.08), Vector2(0.125, y1 - uc.y)], 22, 1.0, 0.86), navy), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.128, y1 - uc.y - 0.012), Vector2(0.12, y1 - uc.y + 0.008)], 22, 1.0, 0.86), gold), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.174, y0 - uc.y - 0.006), Vector2(0.174, y0 - uc.y + 0.016)], 22, 1.0, 0.86), gold), Transform3D(Basis(), uc))
	# gold claw filigree on the plate (swept V-strokes, original)
	for side: float in [-1.0, 1.0]:
		var stroke := PackedVector2Array([Vector2(0.0, -0.01), Vector2(side * 0.012, -0.004), Vector2(side * 0.09, 0.07), Vector2(side * 0.07, 0.072), Vector2(0.0, 0.01)])
		if side < 0:
			stroke.reverse()
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(stroke, 0.01), gold), Transform3D(Basis(), uc + Vector3(0, -0.02, 0.172)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.017, 10), AnimeGear.toon(Color("#E0232E"), {"emit": Color("#E0232E") * 1.2, "outline": false})), Transform3D(Basis(), uc + Vector3(0, -0.015, 0.18)))
	# --- mismatched shoulders: a big layered navy/gold pauldron on the left, a small silver cap on the right
	ClassDress.pauldron(b, 1.0, navy, gold, 1.22, 3, true)
	ClassDress.pauldron(b, -1.0, under, gold, 0.85, 1, false)
	# --- gauntlets: navy left, silver right; navy greaves with gold-rimmed pointed knees
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.04, 0.046, 0.054, 0.06], 0.3, 1.0, under if side < 0 else navy, gold, 14)
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.068, 0.062, 0.052, 0.05], 0.05, 0.92, navy, gold, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.05, -0.04), Vector2(0.05, -0.04), Vector2(0.055, 0.03), Vector2(0.0, 0.11), Vector2(-0.055, 0.03)]), 0.02, 0.006), under)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, 0.07)))
	# --- belt, white under-plate faulds over the hips, leather pouch
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.158, -0.025), Vector2(0.162, 0.025)], 24, 1.0, 0.82), leather), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.035, 0.04), 0.02, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.13)))
	for k in 5:
		var a := deg_to_rad(-70.0 + k * 35.0)
		var plate := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.045, -0.15), Vector2(0.0, -0.18), Vector2(-0.045, -0.15)])
		var leg := "RightUpperLeg" if a < 0 else "LeftUpperLeg"
		if absf(a) < 0.1:
			continue
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(plate, 0.014, 0.004), under), Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.15), hips + Vector3(sin(a) * 0.16, -0.01, cos(a) * 0.13)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.07, 0.08, 0.045)), leather), Transform3D(Basis(Vector3.UP, -2.2), hips + Vector3(0.13, -0.04, -0.09)))
	# --- the hero element: a long red scarf wound round the neck, two trailing torn tails (runtime cloth)
	var wrap := AnimeGear.mi(AnimeGear.lathe([Vector2(0.09, -0.06), Vector2(0.125, -0.035), Vector2(0.13, 0.02), Vector2(0.1, 0.055)], 18, 1.0, 1.05), red)
	b.attach("Neck", wrap, Transform3D(Basis(Vector3.RIGHT, 0.12), neck + Vector3(0, 0.0, 0.005)))
	var knot := AnimeGear.mi(AnimeGear.sphere(0.04, 10), red)
	knot.scale = Vector3(1.0, 0.8, 0.7)
	b.attach("UpperChest", knot, Transform3D(Basis(), neck + Vector3(-0.06, -0.06, -0.08)))
	var cols := [["UpperChest", 0.17, 0.0], ["Hips", 0.2, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(-0.06, -0.07, -0.1)), {
		"name": "ScarfLong", "length": 1.75, "segments": 14, "width": [0.16, 0.2, 0.19, 0.16, 0.1, 0.03], "dir": Vector3(-0.2, -0.9, -0.6),
		"side": Vector3(1, 0.2, 0), "material": red, "thickness": 0.012, "stiffness": 0.03, "stiffness_tip": 0.003,
		"gravity": 6.0, "drag": 0.06, "wind": Vector3(-0.8, 0.1, -1.0), "colliders": cols})
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(-0.03, -0.08, -0.1)), {
		"name": "ScarfShort", "length": 1.05, "segments": 10, "width": [0.15, 0.16, 0.12, 0.04], "dir": Vector3(0.2, -0.95, -0.5),
		"side": Vector3(1, 0.1, 0), "material": red, "thickness": 0.012, "stiffness": 0.035, "stiffness_tip": 0.004,
		"gravity": 7.0, "drag": 0.07, "wind": Vector3(-0.6, 0.0, -0.9), "colliders": cols})
