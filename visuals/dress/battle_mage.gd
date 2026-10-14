extends RefCounted
## Battle Mage 战斗法师 (一叶之秋 type), bible 2.5: floor-length black coat split at the hips, armoured high
## collar, swept pauldrons, gold filigree, red gem; 却邪 battle lance (WeaponFactory "battle_lance").

const BLACK_COAT := Color("#16161C")
const RED_GEM := Color("#D2283A")


static func dress() -> Dictionary:
	return {
		"base": "sakurada",
		"height": 1.86,
		"proportions": [1.06, 0.95],
		"rim": Color(1.0, 0.88, 0.66),
		# 一叶之秋: calm, stern brows (Blade Master shares the base but grins)
		"face": {"angry": 0.3, "blink": 0.15},
		"dress": {
			# school vest + shirt -> black battle coat over a cream shirt; tie -> crimson; hair -> blue-black
			"Tops": {"map": [Color("#07070B"), Color("#262632"), Color("#ECE6D6")], "contrast": 1.25},
			"Accessory": {"map": [Color("#3A0A10"), Color("#C8202A"), Color("#FF8A70")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#09090E"), Color("#1C1C28"), Color("#4A4A60")], "contrast": 1.3},
			"Shoes": {"map": [Color("#120C08"), Color("#3B2416"), Color("#9A7440")], "contrast": 1.2},
			"HAIR": {"map": [Color("#0B090A"), Color("#211A1C"), Color("#584A4C")], "contrast": 1.0, "line": 1.7, "shade": Color(0.55, 0.5, 0.7)},
			"EyeIris": {"iris": Color(0.78, 0.62, 0.55)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"], &"attack_stab": ["Sword_Regular_A"]},
		"grips": {"battle_lance": {"kind": "pole", "tilt": 0.0, "two_hand": true}},
	}


static func build(b: AnimeBody) -> void:
	var coat := AnimeGear.toon(BLACK_COAT, {"shade": Color(0.55, 0.55, 0.85)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	# long coat split at the hips: 2 back panels on Hips, 2 front-side panels on the upper legs
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		ClassDress.coat_panel(b, "Hips", side, true, coat, gold)
		ClassDress.coat_panel(b, leg, side, false, coat, gold)
	# armoured high collar, open at the front
	var neck := b.bone_pos("Neck")
	var collar := AnimeGear.mi(AnimeGear.lathe([Vector2(0.085, -0.06), Vector2(0.095, 0.0), Vector2(0.115, 0.07), Vector2(0.14, 0.12)], 20, 1.0, 1.0, TAU * 0.78), coat)
	collar.rotation.y = -PI * 0.5 - TAU * 0.39 + PI
	b.attach("UpperChest", ClassDress.wrap(collar), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	var collar_rim := AnimeGear.mi(AnimeGear.lathe([Vector2(0.138, 0.115), Vector2(0.15, 0.13)], 20, 1.0, 1.0, TAU * 0.78), gold)
	collar_rim.rotation.y = collar.rotation.y
	b.attach("UpperChest", ClassDress.wrap(collar_rim), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	# pauldrons: asymmetric, bigger on the lance arm
	ClassDress.pauldron(b, -1.0, coat, gold, 1.12)
	ClassDress.pauldron(b, 1.0, coat, gold, 0.95)
	# forearm guards (gold edged)
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var p := b.bone_pos(la)
		var g := AnimeGear.mi(AnimeGear.lathe([Vector2(0.042, 0.0), Vector2(0.05, 0.08), Vector2(0.058, 0.16), Vector2(0.066, 0.2)], 14), coat)
		b.attach(la, g, Transform3D(Basis(Vector3.FORWARD, side * PI * 0.5), p + Vector3(side * 0.06, 0, 0)))
		var gr := AnimeGear.mi(AnimeGear.lathe([Vector2(0.066, 0.2), Vector2(0.07, 0.215)], 14), gold)
		b.attach(la, gr, Transform3D(Basis(Vector3.FORWARD, side * PI * 0.5), p + Vector3(side * 0.06, 0, 0)))
	# belt with gold buckle and red gem
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.155, -0.025), Vector2(0.16, 0.025)], 24, 1.0, 0.82), AnimeGear.toon(ClassDress.LEATHER)), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.045, 0.05), 0.02, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.13)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.018, 12), AnimeGear.toon(RED_GEM, {"emit": RED_GEM * 0.6, "outline": false})), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.145)))
	# chest filigree crest
	var uc := b.bone_pos("UpperChest")
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(), 0.01, 0.002), gold), Transform3D(Basis(), uc + Vector3(0, 0.02, 0.118)))
