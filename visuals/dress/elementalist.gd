extends RefCounted
## Elementalist 元素法师 (风城烟雨 colour cues), bible 2.5: hooded robe, floating elemental orbs; staff with a crescent
## cradle and crystal (WeaponFactory "staff"). Deep plum robe with gold trim: a deep hood and shoulder mantle, wide
## bell sleeves, an open-front over-robe to mid-calf with a long plum train that sweeps behind (runtime cloth, the
## hero element), and three elemental orbs (fire / frost / lightning) orbiting the shoulders. Lilac-silver hair.

const L := preload("res://visuals/dress/_swordmage_lib.gd")
const PLUM := Color("#3A2350")
const PLUM_DK := Color("#1E1030")
const FIRE := Color("#FF8A2A")
const ICE := Color("#6FD8FF")
const BOLT := Color("#F2E05A")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_f",
		"height": 1.72,
		"proportions": [1.06, 0.95],
		"rim": Color(1.0, 0.85, 0.75),
		"dress": {
			# fantasy one-piece -> plum bodice and dark-plum stockings; shoes -> dark leather; hair -> lilac silver
			"Onepice": {"map": [Color("#12081C"), Color("#3A2350"), Color("#B08AD0")], "contrast": 1.25},
			"Shoes": {"map": [Color("#0E0810"), Color("#2A1A26"), Color("#7A5A60")], "contrast": 1.2},
			"HAIR": {"map": [Color("#7A6A98"), Color("#CEC4E6"), Color("#FBF8FF")], "contrast": 1.1, "line": 1.7, "shade": Color(0.68, 0.62, 0.92)},
			"EyeIris": {"iris": Color(1.2, 0.68, 0.38)},
		},
		"anims": {&"idle": ["Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"], &"cast": ["Two-hand Blast", "Spell_Simple_Shoot"],
			&"channel": ["Spell_Simple_Idle"], &"summon": ["kk_Ranged_Magic_Summon", "Two-hand Blast"],
			&"cast_long": ["kk_Ranged_Magic_Spellcasting_Long", "Spell_Simple_Idle"]},
		"grips": {"staff": {"kind": "pole", "tilt": 15.0, "yaw": 75.0}},
	}


static func build(b: AnimeBody) -> void:
	var plum := AnimeGear.toon(PLUM, {"shade": Color(0.6, 0.55, 0.92), "rim": Color(1.0, 0.82, 0.7)})
	var plum_dk := AnimeGear.toon(PLUM_DK, {"shade": Color(0.7, 0.65, 0.95), "rim": Color(0.9, 0.75, 1.0)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	# --- lowered hood: a deep cowl folded on the upper back (face and hair stay readable), gold rim, fire gem
	var hood_prof := [Vector2(0.1, -0.02), Vector2(0.13, 0.05), Vector2(0.135, 0.11), Vector2(0.1, 0.16), Vector2(0.03, 0.18)]
	var hood_xf := Transform3D(Basis(Vector3.RIGHT, -1.05), neck + Vector3(0, 0.0, -0.07))
	b.attach("UpperChest", L.shell(hood_prof, 0.42, plum, 22, 1.0), hood_xf)
	b.attach("UpperChest", L.shell([Vector2(0.1, -0.03), Vector2(0.103, 0.0)], 0.42, gold, 22, 1.0), hood_xf)
	# --- shoulder mantle with gold rim and a gold clasp
	var mantle := [Vector2(0.27, -0.2), Vector2(0.23, -0.1), Vector2(0.15, 0.0), Vector2(0.095, 0.05)]
	b.attach("UpperChest", L.shell(mantle, 0.12, plum_dk, 24, 0.82), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	b.attach("UpperChest", L.shell([Vector2(0.275, -0.212), Vector2(0.265, -0.18)], 0.12, gold, 24, 0.82), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.026, 0.026, 0.012, 12), gold), Transform3D(Basis(Vector3.RIGHT, PI / 2), neck + Vector3(0, -0.07, 0.1)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.014, 10), AnimeGear.toon(FIRE, {"emit": FIRE, "outline": false})), Transform3D(Basis(), neck + Vector3(0, -0.07, 0.108)))
	# --- wide bell sleeves on the forearms (plum, gold hem)
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, ua, la, [0.05, 0.047, 0.046], 0.25, 1.02, plum, null, 12)
		var p0 := b.bone_pos(la)
		var dir := (b.bone_pos(hd) - p0).normalized()
		var bs := Basis(Quaternion(Vector3.UP, dir))
		b.attach(la, AnimeGear.mi(AnimeGear.lathe([Vector2(0.046, -0.02), Vector2(0.06, 0.08), Vector2(0.1, 0.18), Vector2(0.115, 0.2)], 14), plum), Transform3D(bs, p0))
		b.attach(la, AnimeGear.mi(AnimeGear.lathe([Vector2(0.115, 0.195), Vector2(0.119, 0.215)], 14), gold), Transform3D(bs, p0))
	# --- open-front over-robe to mid-calf with a gold hem and flame tongues, sash with a hanging gem
	var knee := b.bone_pos("RightLowerLeg")
	var foot := b.bone_pos("RightFoot")
	var bot := lerpf(knee.y, foot.y, 0.45) - hips.y
	var robe := [Vector2(0.32, bot), Vector2(0.26, (bot - 0.05) * 0.55), Vector2(0.19, -0.08), Vector2(0.16, 0.02), Vector2(0.15, 0.08)]
	b.attach("Hips", L.shell(robe, 0.3, plum, 28, 0.9), Transform3D(Basis(), hips))
	b.attach("Hips", L.shell([Vector2(0.322, bot - 0.005), Vector2(0.315, bot + 0.04)], 0.3, gold, 28, 0.9), Transform3D(Basis(), hips))
	# elemental gem studs along the hem (fire / frost / lightning), the elementalist's own trim motif
	var gems := [AnimeGear.toon(FIRE, {"emit": FIRE * 0.7}), AnimeGear.toon(ICE, {"emit": ICE * 0.7}), AnimeGear.toon(BOLT, {"emit": BOLT * 0.6})]
	for k in 12:
		var a := PI * 0.5 + PI * 0.3 + (TAU - PI * 0.6) * (k + 0.5) / 12.0
		var g := AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.018, 0.03), 0.01, 0.002), gems[k % 3])
		b.attach("Hips", g, Transform3D(Basis(Vector3.UP, -a + PI * 0.5), hips + Vector3(cos(a) * 0.326, bot + 0.07, sin(a) * 0.326 * 0.9)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.158, -0.02), Vector2(0.155, 0.035)], 24, 1.0, 0.86), gold), Transform3D(Basis(), hips + Vector3(0, 0.05, 0)))
	L.tassel(b, "Hips", hips + Vector3(-0.06, 0.04, 0.13), plum_dk, AnimeGear.toon(ICE, {"emit": ICE * 0.8, "outline": false}), 0.3)
	# --- hero element: long plum train behind the robe, gold-lined (runtime cloth)
	ClassDress.cloth(b, "Spine", Transform3D(Basis(), hips + Vector3(0, 0.08, -0.14)), {
		"name": "RobeTrain", "length": 1.1, "segments": 12, "width": [0.3, 0.36, 0.44, 0.5, 0.52, 0.5], "dir": Vector3(0, -1.0, -0.25),
		"side": Vector3(1, 0, 0), "material": plum, "lining": AnimeGear.toon(Color("#6A3A8A"), {"shade": Color(0.65, 0.55, 0.9)}), "thickness": 0.012,
		"stiffness": 0.035, "stiffness_tip": 0.005, "gravity": 9.0, "drag": 0.08, "wind": Vector3(0.3, 0, -0.6),
		"colliders": [["Hips", 0.24, 0.0], ["RightUpperLeg", 0.12, -0.15], ["LeftUpperLeg", 0.12, -0.15], ["RightLowerLeg", 0.1, -0.1], ["LeftLowerLeg", 0.1, -0.1]]})
	# --- three elemental orbs orbiting the shoulders
	var f := L.floater(0.9, 0.04, 1.6)
	b.attach("UpperChest", f, Transform3D(Basis(), uc + Vector3(0, 0.12, -0.02)))
	var cols := [FIRE, ICE, BOLT]
	for k in 3:
		var a := TAU * k / 3.0
		L.orb(f, Vector3(cos(a) * 0.38, 0.05 * sin(a * 2.0), sin(a) * 0.38), cols[k], 0.042)
