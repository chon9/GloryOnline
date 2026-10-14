extends RefCounted
## Assassin 刺客, bible 2.5: short cloak, face mask, hood; charcoal with wine-red; twin short swords
## (WeaponFactory "dual_swords", mirrored pair). Hero silhouette: a pointed hood + a half-cape thrown over the left
## shoulder (runtime cloth) and long wine sash tails. Layering: charcoal undersuit, wine mid-layer, dark steel plates
## with silver trim on the forearms and shins; crossed scabbards on the lower back.

const P := preload("res://visuals/dress/_night_lib.gd")
const CHAR := Color("#2A2A32")
const CHAR_D := Color("#16161C")
const WINE := Color("#7A1F33")
const STEEL_D := Color("#3A3F4C")


static func dress() -> Dictionary:
	return {
		"base": "sakurada",
		"height": 1.82,
		"proportions": [1.07, 0.94],
		"rim": Color(1.0, 0.8, 0.82),
		"dress": {
			# blazer -> charcoal, shirt -> wine, tie -> charcoal, trousers -> black-charcoal, shoes -> dark boots
			"Tops": {"map": [Color("#09090C"), Color("#1E1E26"), Color("#6A1A2C")], "contrast": 1.3},
			"Accessory": {"map": [Color("#08080A"), Color("#1A1A20"), Color("#3A3A44")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#07070A"), Color("#15151C"), Color("#34343E")], "contrast": 1.2},
			"Shoes": {"map": [Color("#08080A"), Color("#1E1A1C"), Color("#4A4048")], "contrast": 1.2},
			"HAIR": {"map": [Color("#33374A"), Color("#767C92"), Color("#B4BACA")], "contrast": 1.1, "line": 1.7, "shade": Color(0.6, 0.6, 0.82)},
			"Brow": {"color": Color("#5A5E70")},
			"EyeIris": {"iris": Color(1.2, 0.45, 0.55)},
		},
		"anims": {&"idle": ["Idle_Sword"], &"attack": ["kk_Melee_Dualwield_Attack_Slice"],
			&"attack_1h_1": ["kk_Melee_Dualwield_Attack_Slice"], &"attack_1h_2": ["kk_Melee_Dualwield_Attack_Chop"],
			&"attack_1h_3": ["kk_Melee_Dualwield_Attack_Stab"], &"attack_stab": ["kk_Melee_Dualwield_Attack_Stab"]},
	}


static func build(b: AnimeBody) -> void:
	var charc := AnimeGear.toon(CHAR, {"shade": Color(0.62, 0.6, 0.85), "rim": Color(1.0, 0.75, 0.8), "rim_strength": 0.8})
	var dark := AnimeGear.toon(CHAR_D, {"shade": Color(0.7, 0.66, 0.9), "rim": Color(1.0, 0.75, 0.8)})
	var wine := AnimeGear.toon(WINE, {"shade": Color("#3A0A1E") / WINE, "rim": Color(1.0, 0.7, 0.7)})
	var wine_d := AnimeGear.toon(Color("#4A1424"), {"shade": Color(0.7, 0.6, 0.85), "rim": Color(1.0, 0.7, 0.7)})
	var plate := AnimeGear.toon(STEEL_D, {"shade": Color(0.55, 0.55, 0.8), "rim": Color.WHITE, "rim_strength": 0.9})
	var silver := AnimeGear.steel(ClassDress.SILVER)
	var leather := AnimeGear.toon(Color("#2E2024"), {"shade": Color(0.7, 0.6, 0.85)})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	# --- hood (charcoal, wine lining) and the lower-face mask
	P.hood(b, charc, wine, 0.98, 0.18)
	P.mask(b, dark, 1.04, 0.074, 0.003)
	# --- cowl / short mantle: asymmetric, long over the left shoulder, cut away on the sword arm
	var mantle := [Vector2(0.27, -0.2), Vector2(0.24, -0.1), Vector2(0.17, 0.0), Vector2(0.11, 0.06)]
	P.shell(b, "UpperChest", neck + Vector3(0.0, -0.04, -0.01), mantle, charc, TAU * 0.6, 0.78, -0.55, 24)
	P.shell(b, "UpperChest", neck + Vector3(0.0, -0.04, -0.01), [Vector2(0.275, -0.215), Vector2(0.268, -0.18)], wine, TAU * 0.6, 0.78, -0.55, 24)
	# silver clasp with a wine gem on the left collarbone
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.03, 0.04), 0.014, 0.003), silver), Transform3D(Basis(), neck + Vector3(0.09, -0.08, 0.1)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.013, 8), AnimeGear.toon(Color("#C8203A"), {"emit": Color("#C8203A") * 0.6, "outline": false})), Transform3D(Basis(), neck + Vector3(0.09, -0.08, 0.112)))
	# --- the hero element: a half-cape off the left shoulder (charcoal, wine lining), runtime cloth
	var cols := [["UpperChest", 0.17, 0.0], ["Hips", 0.2, 0.0], ["LeftUpperLeg", 0.11, -0.15], ["RightUpperLeg", 0.11, -0.15], ["LeftLowerLeg", 0.09, -0.1]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(0.07, 0.1, -0.15)), {
		"name": "HalfCape", "length": 0.98, "segments": 11, "width": [0.26, 0.32, 0.3, 0.2, 0.06], "dir": Vector3(0.12, -1.0, -0.2),
		"side": Vector3(1, 0, -0.2), "material": charc, "lining": wine_d, "thickness": 0.012,
		"stiffness": 0.004, "stiffness_tip": 0.0008, "gravity": 9.0, "drag": 0.07, "wind": Vector3(0.0, 0, -0.6), "colliders": cols})
	# --- torso: wine mid-layer vest panel with silver edge, crossed leather harness
	var vest := [Vector2(0.165, hips.y + 0.02 - ch.y), Vector2(0.16, 0.0), Vector2(0.165, uc.y - ch.y + 0.02), Vector2(0.15, uc.y - ch.y + 0.1)]
	P.shell(b, "Chest", ch, vest, wine, TAU * 0.3, 0.84, 0.0, 20)
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var y := lerpf(neck.y - 0.03, hips.y + 0.04, t)
			var x := lerpf(side * 0.12, -side * 0.11, t)
			pts.append(Vector3(x, y, 0.15 + sin(t * PI) * 0.012))
		P.strap(b, "Chest", pts, 0.03, leather, 0.01)
	b.attach("Chest", AnimeGear.mi(AnimeGear.cyl(0.024, 0.024, 0.014, 14), silver), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, lerpf(neck.y - 0.03, hips.y + 0.04, 0.5), 0.168)))
	# --- crossed scabbards on the lower back (dark lacquer, silver chapes)
	for side: float in [-1.0, 1.0]:
		var sc := Node3D.new()
		AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.56, 0.026)), dark, sc)
		AnimeGear.mi(AnimeGear.box(Vector3(0.056, 0.05, 0.03)), silver, sc, Transform3D(Basis(), Vector3(0, 0.26, 0)))
		AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.028, 0.0), Vector2(0.028, 0.0), Vector2(0.0, -0.05)]), 0.03), silver, sc, Transform3D(Basis(), Vector3(0, -0.28, 0)))
		AnimeGear.mi(AnimeGear.box(Vector3(0.054, 0.02, 0.03)), wine, sc, Transform3D(Basis(), Vector3(0, 0.1, 0)))
		b.attach("Hips", sc, Transform3D(Basis(Vector3.BACK, side * 1.05), hips + Vector3(0, 0.07, -0.17)))
	# --- wine sash with a knot on the right hip and two long tails (Chinese seasoning: rope + tassels)
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.162, -0.035), Vector2(0.166, 0.0), Vector2(0.162, 0.035)], 26, 1.0, 0.84), wine), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	var kp := hips + Vector3(-0.13, 0.02, 0.09)
	var kn := AnimeGear.mi(AnimeGear.sphere(0.03, 10), wine)
	kn.scale = Vector3(1.0, 0.8, 0.6)
	b.attach("Hips", kn, Transform3D(Basis(), kp))
	for k in 2:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), kp + Vector3(-0.01 * k, -0.02, 0.0)), {
			"name": "SashTail", "length": 0.62 - k * 0.12, "segments": 8, "width": [0.07, 0.065, 0.05], "dir": Vector3(-0.3, -1.0, 0.1 - k * 0.3),
			"side": Vector3(0, 0, 1), "material": wine, "thickness": 0.008, "stiffness": 0.03, "stiffness_tip": 0.004,
			"gravity": 8.0, "drag": 0.07, "wind": Vector3(-0.4, 0, -0.6), "colliders": [["RightUpperLeg", 0.1, -0.12], ["Hips", 0.18, 0.0]]})
	# --- forearm plates (dark steel, silver rims, swept elbow fins) and fingerless gloves
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.042, 0.048, 0.054, 0.058], 0.2, 0.92, plate, silver, 14)
		var ep := b.bone_pos(la)
		var fin := AnimeGear.mi(AnimeGear.extrude(P.spike(0.1, 0.022), 0.012, 0.003), plate)
		b.attach(la, fin, Transform3D(Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.FORWARD, side * 1.25), ep + Vector3(side * 0.02, 0.01, -0.045)))
		P.wraps(b, la, hd, 0.046, 0.05, 0.05, 0.2, 2, wine, 0.2)
	# --- small swept pauldron on the sword (right) shoulder only
	ClassDress.pauldron(b, -1.0, plate, silver, 0.9, 2, true)
	# --- legs: thigh strap with throwing knives, shin plates with pointed knees, wine ankle wraps
	for side: float in [-1.0, 1.0]:
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.064, 0.06, 0.052, 0.048], 0.08, 0.84, plate, silver, 14)
		P.knee(b, ll, plate, silver, 1.0, 0.068)
		P.wraps(b, ll, ft, 0.05, 0.048, 0.86, 1.0, 2, wine, 0.2)
		var up := b.bone_pos(ul)
		var kn2 := b.bone_pos(ll)
		var sp := up.lerp(kn2, 0.45)
		b.attach(ul, AnimeGear.mi(AnimeGear.lathe([Vector2(0.078, -0.014), Vector2(0.08, 0.014)], 14, 1.0, 1.0), leather), Transform3D(Basis(), sp))
		if side < 0:
			for k in 3:
				var kv := Node3D.new()
				AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.01, 0.0), Vector2(0.0, 0.09)]), 0.006), silver, kv)
				AnimeGear.mi(AnimeGear.box(Vector3(0.014, 0.045, 0.012)), dark, kv, Transform3D(Basis(), Vector3(0, -0.02, 0)))
				b.attach(ul, kv, Transform3D(Basis(Vector3.UP, -PI * 0.5), sp + Vector3(-0.082, 0.0, 0.03 - k * 0.03)))
