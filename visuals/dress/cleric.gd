extends RefCounted
## Cleric 牧师 (healer, Fang Shiqian-type), bible 2.5: white cape with a gold cross clasp, high standing collar,
## white / navy / gold. Long navy over-robe split into leg-riding panels over a white under-skirt, white stole with
## gold crosses (runtime cloth), white mantle with gold filigree; cross staff (WeaponFactory "cross").

const L := preload("res://visuals/dress/_priest_lib.gd")
const WHITE := Color("#F2F0EA")
const NAVY := Color("#1C2550")


static func dress() -> Dictionary:
	return {
		"base": "sakurada",
		"height": 1.84,
		"proportions": [1.06, 0.94],
		# the blazer's shirt collar shows as a white sliver inside the standing collar: cull it (relative to Neck)
		"cull": [{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.11, -0.07, -0.02), "max": Vector3(0.11, 0.1, 0.15)}],
		"rim": Color(1.0, 0.94, 0.8),
		"dress": {
			# blazer + shirt -> navy cassock over a white collar; tie -> gold; trousers -> navy; shoes -> white boots
			"Tops": {"map": [Color("#0C1230"), Color("#1C2550"), Color("#F2F0EA")], "contrast": 1.3},
			"Accessory": {"map": [Color("#6A4A14"), Color("#D8B25A"), Color("#FFE9A8")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#080C22"), Color("#141B3C"), Color("#36406A")], "contrast": 1.2},
			"Shoes": {"map": [Color("#5A5E70"), Color("#D8DCE6"), Color("#FFFFFF")], "contrast": 1.2},
			"HAIR": {"map": [Color("#1E1612"), Color("#4A3A30"), Color("#9A8270")], "contrast": 1.1, "line": 1.7, "shade": Color(0.6, 0.55, 0.72)},
			"Brow": {"color": Color("#3A2A20")},
			"EyeIris": {"iris": Color(0.7, 0.85, 1.2)},
		},
		"anims": {&"idle": ["Idle_Lantern", "Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"], &"cast": ["Spell_Simple_Shoot"],
			&"heal": ["kk_Ranged_Magic_Raise", "Power Up"], &"channel": ["Spell_Simple_Idle"]},
	}


static func build(b: AnimeBody) -> void:
	var white := AnimeGear.toon(WHITE, {"shade": Color("#A9B3D6") / WHITE, "rim": Color(1.0, 0.95, 0.85)})
	var navy := AnimeGear.toon(NAVY, {"shade": Color("#0E1230") / NAVY, "rim": Color(0.75, 0.82, 1.0)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	var sp := b.bone_pos("Spine")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var foot := b.bone_pos("RightFoot")
	# --- long robe: a white under-skirt to mid-thigh + a navy over-robe split into four long panels that ride the
	# legs (so stepping legs never poke through), gold-hemmed, and a ring of gold filigree points on the under-skirt
	var bot := foot.y + 0.13
	L.shell(b, "Hips", hips, [Vector2(0.25, -0.3), Vector2(0.2, -0.14), Vector2(0.168, 0.0), Vector2(0.16, 0.06)], white, 0.9)
	L.rim(b, "Hips", hips, 0.25, -0.3, gold, 0.9)
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var pt := PackedVector2Array([Vector2(-0.03, 0.0), Vector2(0.03, 0.0), Vector2(0.0, -0.06)])
		var p := Vector3(cos(a) * 0.252, -0.305, -sin(a) * 0.252 * 0.9)
		b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(pt, 0.008), gold), Transform3D(Basis(Vector3.UP, a + PI * 0.5), hips + p))
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		ClassDress.coat_panel(b, leg, side, true, navy, gold, bot, 150.0, 55.0, 0.95)
		ClassDress.coat_panel(b, leg, side, false, navy, gold, bot, 150.0, 62.0, 0.8)
		ClassDress.coat_panel(b, leg, side, false, navy, gold, bot + 0.05, 150.0, 102.0, 0.9)
	L.shell(b, "Hips", hips, [Vector2(0.178, -0.02), Vector2(0.17, 0.07)], navy, 0.9)
	# navy bodice (the over-robe's top) open over a white front
	L.shell(b, "Spine", Vector3(0, sp.y, 0), [Vector2(0.172, -0.1), Vector2(0.165, 0.05), Vector2(0.17, 0.14)], navy, 0.86, TAU * 0.8, true)
	# --- sash: white band with gold rims and a gold buckle
	L.shell(b, "Hips", hips, [Vector2(0.185, 0.0), Vector2(0.187, 0.055)], white, 0.88)
	L.rim(b, "Hips", hips, 0.189, 0.055, gold, 0.88, TAU, true, 0.01)
	L.rim(b, "Hips", hips, 0.186, 0.0, gold, 0.88, TAU, true, 0.01)
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.035, 0.04), 0.02, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.028, 0.168)))
	# --- white mantle over the shoulders (gold filigree rim) + tall standing collar
	var mantle := [Vector2(0.27, -0.17), Vector2(0.24, -0.09), Vector2(0.17, -0.01), Vector2(0.11, 0.04)]
	L.shell(b, "UpperChest", neck + Vector3(0, -0.04, -0.005), mantle, white, 0.78, TAU * 0.86, true)
	L.shell(b, "UpperChest", neck + Vector3(0, -0.04, -0.005), [Vector2(0.274, -0.185), Vector2(0.266, -0.15)], gold, 0.78, TAU * 0.86, true)
	for k in 7:
		var a := -PI * 0.5 + TAU * 0.07 + TAU * 0.86 * (k + 0.5) / 7.0
		var cl := PackedVector2Array([Vector2(-0.022, 0.0), Vector2(0.022, 0.0), Vector2(0.0, -0.05)])
		var p := Vector3(cos(a) * 0.272, -0.04 - 0.18, -sin(a) * 0.272 * 0.78)
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(cl, 0.008), gold), Transform3D(Basis(Vector3.UP, a + PI * 0.5), neck + p))
	var col := [Vector2(0.085, -0.04), Vector2(0.09, 0.02), Vector2(0.1, 0.065), Vector2(0.115, 0.095)]
	L.shell(b, "UpperChest", neck, col, white, 1.0, TAU * 0.82, true)
	L.shell(b, "UpperChest", neck, [Vector2(0.114, 0.088), Vector2(0.122, 0.106)], gold, 1.0, TAU * 0.82, true)
	# gold cross clasp at the throat, blue gem
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(L.cross_poly(1.0), 0.016, 0.003), gold), Transform3D(Basis(), neck + Vector3(0, -0.1, 0.13)))
	L.gem(b, "UpperChest", neck + Vector3(0, -0.1, 0.142), Color("#7FC8FF"), 0.014, 1.2)
	# --- wide white cuffs with gold rims (bell sleeves)
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.045, 0.055, 0.075, 0.09], 0.35, 0.95, white, gold, 14)
		# navy sleeves over the base's short shirt sleeves (no bare arms on a priest)
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		ClassDress.limb_guard(b, ua, la, [0.052, 0.048, 0.044, 0.042], 0.15, 1.02, navy, null, 12)
		ClassDress.limb_guard(b, la, hd, [0.042, 0.04, 0.038], 0.0, 0.4, navy, null, 12)
	# --- navy stole with gold crosses: two strips from the shoulders down the front (runtime cloth)
	var white_g := AnimeGear.toon(WHITE, {"shade": Color("#A9B3D6") / WHITE, "rim": ClassDress.GOLD_HI})
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(side * 0.075, -0.05, 0.1)), {
			"name": "Stole", "length": 0.8, "segments": 10, "width": [0.07, 0.075, 0.08, 0.09], "dir": Vector3(side * 0.03, -1.0, 0.25),
			"side": Vector3(1, 0, 0), "material": white_g, "lining": gold, "thickness": 0.01, "stiffness": 0.05, "stiffness_tip": 0.01,
			"gravity": 9.0, "drag": 0.1, "wind": Vector3(0.0, 0.0, 0.2),
			"colliders": [["UpperChest", 0.18, 0.0], ["Spine", 0.19, 0.0], ["Hips", 0.25, -0.05], ["RightUpperLeg", 0.19, -0.15], ["LeftUpperLeg", 0.19, -0.15]]})
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(L.cross_poly(0.6), 0.012), gold), Transform3D(Basis(), neck + Vector3(side * 0.08, -0.12, 0.13)))
	# --- the hero element: long white cape with a navy lining from both shoulders (runtime cloth)
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(0, 0.12, -0.12)), {
		"name": "Cape", "length": 1.3, "segments": 12, "width": [0.4, 0.55, 0.68, 0.76], "dir": Vector3(0, -1.0, -0.2),
		"side": Vector3(1, 0, 0), "material": white, "lining": navy, "thickness": 0.014,
		"stiffness": 0.035, "stiffness_tip": 0.004, "gravity": 9.0, "drag": 0.08, "wind": Vector3(0.12, 0, -0.35),
		"colliders": [["UpperChest", 0.18, 0.0], ["Hips", 0.23, -0.05], ["RightUpperLeg", 0.16, -0.2], ["LeftUpperLeg", 0.16, -0.2], ["RightLowerLeg", 0.15, -0.1], ["LeftLowerLeg", 0.15, -0.1]]})
	for side: float in [-1.0, 1.0]:
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.028, 0.028, 0.014, 14), gold), Transform3D(Basis(Vector3.RIGHT, PI / 2), uc + Vector3(side * 0.13, 0.1, 0.09)))
