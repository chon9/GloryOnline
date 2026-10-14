extends RefCounted
## Striker 拳法家 (大漠孤烟 type), bible 2.5: red / black / white / gold, black hair with a crimson sheen (the
## berserker owns the bright-red hair on this base). Black fighting undersuit, red mandarin vest
## with gold frog buttons, a torn white long coat worn open (runtime cloth tails with a red lining = the hero
## silhouette), one gold lion pauldron, red rope sash with tassels, red-and-gold knuckle gauntlets.
## Gauntlets: the WeaponFactory "gloves" (flared red cuff over the hoodie sleeve, back plate, knuckle bar, team-tint
## energy lines) plus articulated finger plates built here on the finger bones (they follow the curled fingers).

const L := preload("res://visuals/dress/_gunfight_lib.gd")
const RED := Color("#B3262A")
const COAT := Color("#ECE6DA")
const BLACK := Color("#16131A")


static func dress() -> Dictionary:
	return {
		"base": "hairsample_male",
		"height": 1.9,
		"proportions": [1.05, 0.93],
		# the HairSample_Male hoodie hood never shows above the coat collar: cull it (character space, relative to Neck)
		"cull": [{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.22, -0.16, -0.3), "max": Vector3(0.22, 0.2, -0.11)},
			{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.25, -0.06, -0.35), "max": Vector3(0.25, 0.35, 0.03)}],
		"rim": Color(1.0, 0.84, 0.66),
		"dress": {
			# hoodie -> black undersuit, trousers -> black-brown, shoes -> black boots; hair -> deep crimson-black
			"Tops": {"map": [Color("#050406"), Color("#121016"), Color("#2C2630")], "contrast": 1.2},
			"Bottoms": {"map": [Color("#060506"), Color("#16121A"), Color("#3A3036")], "contrast": 1.2},
			"Shoes": {"map": [Color("#070606"), Color("#1A1414"), Color("#4A3A34")], "contrast": 1.2},
			"HAIR": {"map": [Color("#0E0A0C"), Color("#2E1A1E"), Color("#8A3A34")], "contrast": 1.15, "line": 1.8, "shade": Color(0.6, 0.5, 0.75)},
			"Brow": {"color": Color("#3A0A0A")},
			"EyeIris": {"iris": Color(1.0, 0.62, 0.42)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Punch_Cross"]},
	}


static func build(b: AnimeBody) -> void:
	L.broaden(b, 0.022)
	var red := AnimeGear.toon(RED, {"shade": Color("#6A0E2A") / RED, "rim": Color(1.0, 0.7, 0.55)})
	var coat := AnimeGear.toon(COAT, {"shade": Color("#8E94B8") / COAT, "rim": Color.WHITE, "rim_strength": 0.7})
	var black := AnimeGear.toon(BLACK, {"shade": Color(0.6, 0.55, 0.85)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var yb := hips.y - 0.04 - uc.y
	# --- black mandarin vest (closed) with red edging and gold frog buttons, under the open coat
	var vest := [Vector2(0.205, yb - 0.08), Vector2(0.19, yb), Vector2(0.176, yb + 0.1), Vector2(0.185, -0.05), Vector2(0.192, 0.04), Vector2(0.176, 0.1), Vector2(0.118, 0.155)]
	L.shell(b, "UpperChest", vest, uc, black, 0.0, 1.0, 0.84)
	# tunic skirt over the hips (buries the base's hoodie hem), red hem with a gold line
	L.shell(b, "Hips", [Vector2(0.222, -0.13), Vector2(0.205, -0.06), Vector2(0.186, 0.02)], hips, black, 0.0, 1.0, 0.93)
	L.ring(b, "Hips", hips + Vector3(0, -0.118, 0), 0.224, 0.028, red, 0.93)
	L.ring(b, "Hips", hips + Vector3(0, -0.1, 0), 0.219, 0.008, gold, 0.93)
	L.mandarin_collar(b, red, gold, 0.072, 0.07)
	for k in 3:
		var y := 0.07 - k * 0.075
		L.frog(b, "UpperChest", uc + Vector3(0, y, 0.162 - k * 0.002), gold, 1.0)
	# --- torn white long coat worn open: torso shell, red lapels with gold edge, sleeves to the elbow
	var coat_p := [Vector2(0.192, yb - 0.02), Vector2(0.186, yb + 0.1), Vector2(0.198, -0.05), Vector2(0.207, 0.04), Vector2(0.194, 0.1), Vector2(0.15, 0.15), Vector2(0.11, 0.175)]
	var gap := 0.15
	L.shell(b, "UpperChest", coat_p, uc, coat, gap, 1.0, 0.86)
	for side: float in [-1.0, 1.0]:
		L.shell_edge(b, "UpperChest", coat_p, uc, gap, 1.0, 0.86, side, 0.05, red, 0.008)
		L.shell_edge(b, "UpperChest", coat_p, uc, gap, 1.0, 0.86, side, 0.014, gold, 0.014)
	# high coat collar flaring behind the neck
	var col := [Vector2(0.115, -0.03), Vector2(0.128, 0.03), Vector2(0.15, 0.075)]
	L.shell(b, "UpperChest", col, neck + Vector3(0, -0.02, -0.012), coat, 0.42, 1.0, 1.0, 18)
	L.shell(b, "UpperChest", [Vector2(0.148, 0.068), Vector2(0.154, 0.082)], neck + Vector3(0, -0.02, -0.012), gold, 0.42, 1.0, 1.0, 18)
	# sleeveless coat: a short white shoulder cap with a red / gold rim on the bare (right) arm
	var ua := "RightUpperArm"
	var sh := b.bone_pos(ua)
	var el := b.bone_pos("RightLowerArm")
	var bs := Basis(Quaternion(Vector3.UP, (el - sh).normalized()))
	b.attach(ua, AnimeGear.mi(AnimeGear.lathe([Vector2(0.05, -0.05), Vector2(0.082, -0.01), Vector2(0.084, 0.06), Vector2(0.08, 0.1)], 14), coat), Transform3D(bs, sh))
	b.attach(ua, AnimeGear.mi(AnimeGear.lathe([Vector2(0.081, 0.085), Vector2(0.085, 0.115)], 14), red), Transform3D(bs, sh))
	b.attach(ua, AnimeGear.mi(AnimeGear.lathe([Vector2(0.085, 0.11), Vector2(0.087, 0.122)], 14), gold), Transform3D(bs, sh))
	# coat tails (hero element): two long torn back panels + two shorter front panels, red lining
	var cols := [["Hips", 0.19, -0.02], ["RightUpperLeg", 0.11, -0.18], ["LeftUpperLeg", 0.11, -0.18], ["RightLowerLeg", 0.085, -0.12], ["LeftLowerLeg", 0.085, -0.12]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.085, 0.035, -0.15)), {
			"name": "CoatTail", "length": 1.02 if side < 0 else 0.86, "segments": 11,
			"width": [0.2, 0.22, 0.24, 0.25, 0.25, 0.24, 0.2, 0.12, 0.05] if side < 0 else [0.2, 0.22, 0.24, 0.24, 0.22, 0.14, 0.04],
			"dir": Vector3(side * 0.12, -1.0, -0.28), "side": Vector3(1, 0, 0.2 * side), "material": coat, "lining": red,
			"thickness": 0.014, "stiffness": 0.035, "stiffness_tip": 0.005, "gravity": 9.0, "drag": 0.07,
			"wind": Vector3(0.3, 0, -0.7), "colliders": cols})
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.15, 0.035, 0.06)), {
			"name": "CoatFront", "length": 0.7 if side < 0 else 0.78, "segments": 8,
			"width": [0.12, 0.15, 0.16, 0.15, 0.1, 0.04], "dir": Vector3(side * 0.2, -1.0, 0.12), "side": Vector3(-0.35, 0, side),
			"material": coat, "thickness": 0.014, "stiffness": 0.045, "stiffness_tip": 0.008, "gravity": 9.0,
			"drag": 0.08, "colliders": cols})
	# --- gold lion pauldron on the left shoulder (red under-plates)
	ClassDress.pauldron(b, 1.0, red, gold, 1.3, 2, false)
	var shl := b.bone_pos("LeftUpperArm")
	var lion := Node3D.new()
	var gold_dk := AnimeGear.toon(Color("#B08A3A"), {"shade": ClassDress.GOLD_SHADE / Color("#B08A3A"), "rim": ClassDress.GOLD_HI})
	var mane := AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.105, 14, 0.72), 0.03, 0.006), gold, lion)
	mane.position = Vector3(0, 0, -0.01)
	AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.078, 10, 0.78), 0.03, 0.004), gold_dk, lion, Transform3D(Basis(Vector3.BACK, 0.3), Vector3(0, 0, 0.004)))
	AnimeGear.mi(AnimeGear.cyl(0.05, 0.056, 0.036, 14), gold, lion, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.0, 0.02)))
	# brow ridge, snout, glowing eyes, open mouth with fangs
	AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.0, 0.018), Vector2(0.05, 0.0), Vector2(0.0, 0.032)]), 0.02, 0.003), gold_dk, lion, Transform3D(Basis(), Vector3(0, 0.012, 0.042)))
	AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.016, 0.0), Vector2(0.016, 0.0), Vector2(0.011, -0.03), Vector2(0.0, -0.036), Vector2(-0.011, -0.03)]), 0.022, 0.004), gold, lion, Transform3D(Basis(), Vector3(0, 0.0, 0.05)))
	AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.022, 0.0), Vector2(0.022, 0.0), Vector2(0.0, -0.022)]), 0.01), AnimeGear.toon(Color("#2A0A0A"), {"outline": false}), lion, Transform3D(Basis(), Vector3(0, -0.036, 0.04)))
	for side: float in [-1.0, 1.0]:
		var eye := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(side * 0.024, 0.008), Vector2(side * 0.02, 0.016)]), 0.01), AnimeGear.toon(Color("#FF3A2A"), {"emit": Color("#FF2A10") * 1.2, "outline": false}), lion)
		eye.position = Vector3(side * 0.01, 0.004, 0.044)
		var fang := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.005, 0), Vector2(0.005, 0), Vector2(0, -0.022)]), 0.008), AnimeGear.toon(Color("#F4EEDC")), lion)
		fang.position = Vector3(side * 0.014, -0.034, 0.046)
	b.attach("LeftUpperArm", lion, Transform3D(Basis(Vector3.UP, 1.0) * Basis(Vector3.RIGHT, -0.25), shl + Vector3(0.12, 0.04, 0.05)))
	# swept mane flames trailing back over the shoulder
	for k in 3:
		var fl := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.01), Vector2(0.11 - k * 0.02, 0.05), Vector2(0.04, -0.01), Vector2(0.01, -0.025)]), 0.012, 0.002), gold)
		b.attach("LeftUpperArm", fl, Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.2) * Basis(Vector3.BACK, 0.35 - k * 0.3), shl + Vector3(0.09, 0.09 - k * 0.04, -0.06)))
	# --- red rope sash, knot on the right hip, tasselled tails
	L.rope_sash(b, red, -1.0, 0.172, 0.15, 0.035, 0.6)
	# --- articulated finger plates under the factory gauntlets (cuff, back plate and knuckles come from "gloves")
	for side: float in [-1.0, 1.0]:
		L.gauntlet(b, side, red, gold, {"bracer": false, "back": false, "fin": false})
	# --- legs: black shin wraps with gold ankle rings, pointed red knee plates
	for side: float in [-1.0, 1.0]:
		var ll := L.arm(side) + "LowerLeg"
		var ft := L.arm(side) + "Foot"
		ClassDress.limb_guard(b, ll, ft, [0.07, 0.066, 0.058, 0.052], 0.12, 0.93, black, gold, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.045, -0.04), Vector2(0.045, -0.04), Vector2(0.05, 0.03), Vector2(0.0, 0.1), Vector2(-0.05, 0.03)]), 0.02, 0.006), red)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, 0.07)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.014, 0.02), 0.026), gold), Transform3D(Basis(), kp + Vector3(0, 0.025, 0.083)))
