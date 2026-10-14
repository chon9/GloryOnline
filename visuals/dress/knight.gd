extends RefCounted
## Knight 骑士 (main tank), bible 2.5: tower shield on the left forearm + knight sword, heavy layered plate,
## team-colour tabard. Bulk comes from the armour silhouette (flared cuirass, stacked pauldrons, hooped faulds,
## big gauntlets and greaves), never from the body. Open-faced crested helm with a trailing plume.

const L := preload("res://visuals/dress/_priest_lib.gd")
const STEEL := Color("#6C788C")
const STEEL_HI := Color("#A4B0C2")
const UNDER := Color("#1A1F2C")
const TABARD := Color("#2A4C9A")


static func dress() -> Dictionary:
	return {
		"base": "base_male",
		"height": 1.9,
		"proportions": [1.05, 0.93],
		"rim": Color(0.85, 0.92, 1.0),
		"dress": {
			# shirt + trousers -> dark gambeson under-suit, shoes -> steel sabatons, cap hair -> dark chestnut
			"Tops": {"map": [Color("#0A0D16"), Color("#1A1F2C"), Color("#3A4258")], "contrast": 1.2},
			"Accessory": {"map": [Color("#0A0D16"), Color("#2A4C9A"), Color("#6F8FD8")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#080A12"), Color("#161A26"), Color("#363E52")], "contrast": 1.2},
			"Shoes": {"map": [Color("#2E3542"), Color("#7E8A9C"), Color("#E0E6EE")], "contrast": 1.2},
			"Hair": {"map": [Color("#1A120C"), Color("#4A3424"), Color("#8A6A4C")], "contrast": 1.05, "line": 1.7},
			"Brow": {"color": Color("#3A281A")},
			"EyeIris": {"iris": Color(0.62, 0.78, 1.15)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"], &"block": ["kk_Melee_Blocking", "Sword_Block"]},
		"grips": {"knight_sword": {"kind": "blade", "tilt": 0.0}},
	}


static func build(b: AnimeBody) -> void:
	var steel := AnimeGear.toon(STEEL, {"shade": Color("#343C52") / STEEL, "rim": Color(0.85, 0.92, 1.0), "rim_strength": 0.7})
	var steel_hi := AnimeGear.toon(STEEL_HI, {"shade": Color("#5C6680") / STEEL_HI, "rim": Color(0.85, 0.92, 1.0), "rim_strength": 0.7})
	var gold := AnimeGear.gold()
	var tab := AnimeGear.toon(TABARD, {"shade": Color(0.5, 0.5, 0.9), "rim": Color(0.8, 0.88, 1.0)})
	var tab_in := AnimeGear.toon(Color("#E8E4DA"), {"shade": Color("#A9B3D6") / Color("#E8E4DA")})
	var leather := AnimeGear.toon(ClassDress.LEATHER)
	var hips := b.bone_pos("Hips")
	var sp := b.bone_pos("Spine")
	var ch := b.bone_pos("Chest")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- cuirass: broad flared breastplate (wider at the chest than the waist), pointed keel, layered plackart
	var y0 := ch.y - 0.08
	var y1 := uc.y + 0.13
	L.shell(b, "UpperChest", uc, [Vector2(0.17, y0 - uc.y), Vector2(0.19, ch.y - uc.y), Vector2(0.215, 0.02), Vector2(0.21, 0.08), Vector2(0.15, y1 - uc.y), Vector2(0.11, y1 - uc.y + 0.02)], steel, 0.84)
	L.rim(b, "UpperChest", uc, 0.112, y1 - uc.y + 0.012, gold, 0.84)
	L.rim(b, "UpperChest", uc, 0.172, y0 - uc.y, gold, 0.84)
	# keel ridge + gold crest on the chest
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.014, y0 - uc.y), Vector2(0.014, y0 - uc.y), Vector2(0.01, y1 - uc.y - 0.03), Vector2(-0.01, y1 - uc.y - 0.03)]), 0.02), steel_hi), Transform3D(Basis(), uc + Vector3(0, 0, 0.18)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(1.5), 0.014, 0.003), gold), Transform3D(Basis(), uc + Vector3(0, 0.03, 0.188)))
	L.gem(b, "UpperChest", uc + Vector3(0, 0.035, 0.198), Color("#3FA9FF"), 0.018, 1.4)
	# plackart: two stacked lames over the belly
	for k in 2:
		var yy := sp.y + 0.06 - k * 0.07
		L.shell(b, "Spine", Vector3(0, yy, 0), [Vector2(0.168 + k * 0.006, -0.04), Vector2(0.162 + k * 0.006, 0.04)], steel if k == 0 else steel_hi, 0.82)
		L.rim(b, "Spine", Vector3(0, yy, 0), 0.17 + k * 0.006, -0.04, gold, 0.82, TAU, true, 0.012)
	# gorget: stacked rings around the neck
	L.shell(b, "UpperChest", neck, [Vector2(0.13, -0.07), Vector2(0.11, -0.02), Vector2(0.085, 0.04)], steel_hi, 0.95)
	L.rim(b, "UpperChest", neck, 0.086, 0.04, gold, 0.95)
	# --- pauldrons: big stacked plates both sides (sword arm slightly larger), plus rerebraces
	ClassDress.pauldron(b, -1.0, steel, gold, 1.4, 3, true)
	ClassDress.pauldron(b, 1.0, steel, gold, 1.32, 3, true)
	for side: float in [-1.0, 1.0]:
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, ua, la, [0.052, 0.05, 0.048], 0.35, 0.95, steel_hi, null, 12)
		# elbow cop with a swept point
		var el := b.bone_pos(la)
		b.attach(la, AnimeGear.mi(AnimeGear.sphere(0.05, 10), steel), Transform3D(Basis(), el + Vector3(0, 0, -0.01)))
		var cop := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.035, 0.0), Vector2(0.035, 0.0), Vector2(0.0, -0.1)]), 0.012), gold)
		b.attach(la, cop, Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.BACK, side * PI * 0.5), el + Vector3(0, -0.03, -0.04)))
		# heavy flared gauntlets
		ClassDress.limb_guard(b, la, hd, [0.045, 0.052, 0.062, 0.072], 0.2, 1.0, steel, gold, 14)
		# greaves + sabatons + pointed knee cops
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ul, ll, [0.09, 0.085, 0.075], 0.35, 0.92, steel_hi, null, 14)
		ClassDress.limb_guard(b, ll, ft, [0.075, 0.07, 0.06, 0.056], 0.0, 0.95, steel, gold, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.06, -0.05), Vector2(0.06, -0.05), Vector2(0.065, 0.03), Vector2(0.0, 0.13), Vector2(-0.065, 0.03)]), 0.024, 0.006), steel_hi)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, 0.075)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.016, 0.024), 0.03), gold), Transform3D(Basis(), kp + Vector3(0, 0.02, 0.09)))
		var fp := b.bone_pos(ft)
		var toe := AnimeGear.mi(AnimeGear.lathe([Vector2(0.05, 0.0), Vector2(0.055, 0.05), Vector2(0.03, 0.15), Vector2(0.004, 0.19)], 10, 1.0, 0.7), steel)
		b.attach(ft, toe, Transform3D(Basis(Vector3.RIGHT, PI / 2), fp + Vector3(0, -0.05, 0.0)))
	# --- belt + hooped faulds flaring over the hips, tassets on the thighs
	L.shell(b, "Hips", hips, [Vector2(0.17, -0.0), Vector2(0.175, 0.05)], leather, 0.82)
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.04, 0.045), 0.02, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.025, 0.15)))
	for k in 2:
		L.shell(b, "Hips", hips, [Vector2(0.2 + k * 0.03, -0.06 - k * 0.055), Vector2(0.175 + k * 0.03, 0.0 - k * 0.055)], steel if k == 0 else steel_hi, 0.84, TAU * 0.62, true)
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var tp := PackedVector2Array([Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.075, -0.2), Vector2(0.0, -0.25), Vector2(-0.075, -0.2)])
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(tp, 0.018, 0.005), steel), Transform3D(Basis(Vector3.UP, side * 1.25) * Basis(Vector3.RIGHT, -0.1), hips + Vector3(side * 0.19, -0.1, 0.0)))
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.08, -0.02), Vector2(-0.08, -0.02)]), 0.022), gold), Transform3D(Basis(Vector3.UP, side * 1.25) * Basis(Vector3.RIGHT, -0.1), hips + Vector3(side * 0.19, -0.1, 0.0)))
	# --- the hero element: team-colour tabard, front and back panels hanging below the knees (runtime cloth)
	var cols := [["Hips", 0.2, 0.0], ["RightUpperLeg", 0.12, -0.15], ["LeftUpperLeg", 0.12, -0.15], ["RightLowerLeg", 0.1, -0.05], ["LeftLowerLeg", 0.1, -0.05]]
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0, 0.0, 0.17)), {
		"name": "TabardFront", "length": 0.78, "segments": 9, "width": [0.22, 0.24, 0.24, 0.2], "dir": Vector3(0, -1.0, 0.12),
		"side": Vector3(1, 0, 0), "material": tab_in, "lining": tab, "thickness": 0.012, "stiffness": 0.06, "stiffness_tip": 0.01,
		"gravity": 9.0, "drag": 0.1, "wind": Vector3(0.0, 0, 0.2), "colliders": cols})
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0, 0.0, -0.16)), {
		"name": "TabardBack", "length": 0.86, "segments": 9, "width": [0.26, 0.28, 0.28, 0.24], "dir": Vector3(0, -1.0, -0.12),
		"side": Vector3(1, 0, 0), "material": tab, "lining": tab_in, "thickness": 0.012, "stiffness": 0.05, "stiffness_tip": 0.008,
		"gravity": 9.0, "drag": 0.1, "wind": Vector3(0.2, 0, -0.5), "colliders": cols})
	# tabard top showing over the cuirass waist: a short team-colour band with a gold sun crest
	L.shell(b, "Spine", Vector3(0, sp.y - 0.03, 0), [Vector2(0.18, -0.03), Vector2(0.178, 0.03)], tab, 0.82)
	# --- open-faced helm: rounded skull, swept cheek guards, gold brow band, tall crest fin, trailing plume
	var hc := head + Vector3(0, 0.11, -0.012)
	var helm := Node3D.new()
	helm.name = "KnightHelm"
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.124, -0.018), Vector2(0.13, 0.02), Vector2(0.122, 0.07), Vector2(0.097, 0.11), Vector2(0.05, 0.136), Vector2(0.0, 0.143)], 24, 1.0, 1.0), steel, helm)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.127, -0.02), Vector2(0.132, 0.008)], 24, 1.0, 1.0), gold, helm)
	# back of the helm comes down over the nape
	var nape := AnimeGear.mi(AnimeGear.lathe([Vector2(0.115, -0.15), Vector2(0.128, -0.06), Vector2(0.129, 0.0)], 16, 1.0, 1.0, TAU * 0.5), steel, helm)
	nape.rotation.y = PI
	for side: float in [-1.0, 1.0]:
		var cheek := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.07, -0.08), Vector2(0.03, -0.14), Vector2(0.0, -0.1)])
		var cg := AnimeGear.mi(AnimeGear.extrude(cheek, 0.014, 0.003), steel, helm)
		cg.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(side * 0.126, -0.01, 0.06))
		# small swept wing on each temple
		var wg := Node3D.new()
		helm.add_child(wg)
		wg.transform = Transform3D(Basis(Vector3.UP, side * 0.25 + (PI if side < 0 else 0.0)), Vector3(side * 0.13, 0.05, -0.03))
		L.wing(wg, 3, 0.13, gold, steel_hi, 0.5, 0.5, 0.008)
	# pointed brow plate dipping toward the bridge of the nose, gold edged
	var brow := PackedVector2Array([Vector2(-0.075, 0.035), Vector2(0.075, 0.035), Vector2(0.07, 0.012), Vector2(0.022, 0.0), Vector2(0.0, -0.028), Vector2(-0.022, 0.0), Vector2(-0.07, 0.012)])
	var bp := AnimeGear.mi(AnimeGear.extrude(Geometry2D.offset_polygon(brow, 0.008)[0], 0.012), gold, helm)
	bp.transform = Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.014, 0.12))
	var bp2 := AnimeGear.mi(AnimeGear.extrude(brow, 0.02, 0.003), steel_hi, helm)
	bp2.transform = Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.014, 0.124))
	var crest := PackedVector2Array([Vector2(-0.12, 0.0), Vector2(0.1, 0.0), Vector2(0.11, 0.03), Vector2(0.06, 0.06), Vector2(-0.04, 0.08), Vector2(-0.16, 0.06)])
	var cr := AnimeGear.mi(AnimeGear.extrude(crest, 0.014, 0.004), gold, helm)
	cr.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.13, 0.0))
	b.attach("Head", helm, Transform3D(Basis(), hc))
	ClassDress.cloth(b, "Head", Transform3D(Basis(), hc + Vector3(0, 0.15, -0.09)), {
		"name": "Plume", "length": 0.5, "segments": 7, "width": [0.07, 0.09, 0.07, 0.02], "dir": Vector3(0, -0.4, -1.0),
		"side": Vector3(1, 0, 0), "material": tab, "thickness": 0.02, "stiffness": 0.08, "stiffness_tip": 0.01,
		"gravity": 5.0, "drag": 0.08, "wind": Vector3(0.2, 0.0, -0.6), "colliders": [["Head", 0.14, 0.08], ["UpperChest", 0.2, 0.0]]})
