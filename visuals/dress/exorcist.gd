extends RefCounted
## Exorcist 驱魔师, bible 2.5: talismans, black / red / silver; war scythe (WeaponFactory "war_scythe").
## Long black cassock coat with a closed mandarin collar and silver frog buttons, split skirts riding the legs,
## long red-lined coat tails (runtime cloth hero element), red rope sash with tassels, paper talismans that
## flutter from the belt and the silver pauldron, silver hair, red eyes.

const L := preload("res://visuals/dress/_priest_lib.gd")
const BLACK := Color("#16141A")
const RED := Color("#B81E2A")
const SILVER := Color("#C9D3DE")
const PAPER := Color("#EEE2BE")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_d",
		"height": 1.72,
		"proportions": [1.07, 0.95],
		"rim": Color(1.0, 0.86, 0.8),
		"dress": {
			# vest + shirt -> black cassock over a red under-shirt, bow -> red, skirt -> black, shoes -> black boots
			"Tops": {"map": [Color("#060508"), Color("#16141A"), Color("#9E1A26")], "contrast": 1.3},
			"Accessory": {"map": [Color("#3A0A10"), Color("#B81E2A"), Color("#FF7A70")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#060508"), Color("#141218"), Color("#3A3440")], "contrast": 1.2},
			"Shoes": {"map": [Color("#060508"), Color("#1E1A22"), Color("#5A5262")], "contrast": 1.2},
			"HAIR": {"map": [Color("#6A6E80"), Color("#C9D0DE"), Color("#FAFBFF")], "contrast": 1.15, "line": 1.7, "shade": Color(0.7, 0.68, 0.85)},
			"Brow": {"color": Color("#8A8EA0")},
			"EyeIris": {"iris": Color(1.25, 0.45, 0.45)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["kk_Melee_2H_Attack_Slice", "Sword_Regular_C"],
			&"cast": ["Spell_Simple_Shoot"]},
	}


static func build(b: AnimeBody) -> void:
	var black := AnimeGear.toon(BLACK, {"shade": Color(0.6, 0.55, 0.85), "rim": Color(1.0, 0.8, 0.8), "rim_strength": 0.8})
	var red := AnimeGear.toon(RED, {"shade": Color("#7A0F2E") / RED, "rim": Color(1.0, 0.75, 0.6)})
	var silver := AnimeGear.toon(SILVER, {"shade": Color("#6E7890") / SILVER, "rim": Color.WHITE, "rim_strength": 0.9})
	var paper := AnimeGear.toon(PAPER, {"shade": Color("#B49A84") / PAPER, "rim": Color(1.0, 0.95, 0.8)})
	var hips := b.bone_pos("Hips")
	var sp := b.bone_pos("Spine")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var foot := b.bone_pos("RightFoot")
	# --- fitted cassock top: black shell over the torso, silver hem; a red placket down the front
	L.shell(b, "Spine", Vector3(0, sp.y, 0), [Vector2(0.135, -0.1), Vector2(0.128, 0.0), Vector2(0.14, 0.09)], black, 0.86)
	L.shell(b, "UpperChest", uc, [Vector2(0.142, -0.1), Vector2(0.152, -0.02), Vector2(0.142, 0.06), Vector2(0.1, 0.11)], black, 0.88)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.box(Vector3(0.04, 0.3, 0.012)), red), Transform3D(Basis(Vector3.RIGHT, 0.08), uc + Vector3(0, -0.06, 0.13)))
	# silver frog buttons (盘扣) across the placket
	for k in 4:
		var y := uc.y + 0.05 - k * 0.07
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.box(Vector3(0.07, 0.012, 0.012)), silver), Transform3D(Basis(), Vector3(0, y, 0.137 - absf(k - 1.5) * 0.004)))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.009, 8), silver), Transform3D(Basis(), Vector3(-0.038, y, 0.137)))
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.009, 8), silver), Transform3D(Basis(), Vector3(0.038, y, 0.137)))
	# closed mandarin collar, silver rim
	L.shell(b, "UpperChest", neck, [Vector2(0.075, -0.05), Vector2(0.074, 0.02), Vector2(0.078, 0.05)], black, 1.0)
	L.rim(b, "UpperChest", neck, 0.079, 0.05, silver, 1.0, TAU, true, 0.012)
	# silver cross pendant on a cord
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(L.cross_poly(0.7), 0.012), silver), Transform3D(Basis(), uc + Vector3(0.0, 0.0, 0.152)))
	# --- the long cassock skirt: four split panels riding the legs (black, silver hem, red inner panel)
	var bot := foot.y + 0.1
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		ClassDress.coat_panel(b, leg, side, false, red, silver, bot + 0.22, 150.0, 96.0, 0.35)
		ClassDress.coat_panel(b, leg, side, false, black, silver, bot + 0.1, 150.0, 34.0, 0.45)
		# black thigh-high hose under the split skirt
		var ll0 := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		ClassDress.limb_guard(b, leg, ll0, [0.08, 0.072, 0.064, 0.058], 0.0, 1.0, black, null, 14)
	# --- red rope sash (Chinese seasoning): band, a knot on the left hip, two tasselled cords (runtime cloth)
	L.shell(b, "Hips", hips, [Vector2(0.162, -0.005), Vector2(0.165, 0.045)], red, 0.84)
	for k in 2:
		L.rim(b, "Hips", hips, 0.166, 0.0 + k * 0.045, AnimeGear.toon(Color("#7A0F1E")), 0.84, TAU, true, 0.008)
	var knot := hips + Vector3(0.13, 0.02, 0.09)
	b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.03, 10), red), Transform3D(Basis(), knot))
	for k in 2:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), knot + Vector3(k * 0.025 - 0.012, -0.02, 0.01)), {
			"name": "Tassel", "length": 0.42 + k * 0.08, "segments": 6, "width": [0.018, 0.018, 0.04], "dir": Vector3(0.1, -1.0, 0.1),
			"side": Vector3(1, 0, 0), "material": red, "thickness": 0.014, "stiffness": 0.04, "stiffness_tip": 0.01,
			"gravity": 9.0, "drag": 0.08, "colliders": [["Hips", 0.17, 0.0], ["LeftUpperLeg", 0.1, -0.15]]})
	# --- hero element: long black coat tails with a red lining (runtime cloth)
	var cols := [["Hips", 0.19, -0.03], ["RightUpperLeg", 0.12, -0.15], ["LeftUpperLeg", 0.12, -0.15], ["RightLowerLeg", 0.1, -0.05], ["LeftLowerLeg", 0.1, -0.05]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.085, 0.03, -0.14)), {
			"name": "CoatTail", "length": 0.85, "segments": 10, "width": [0.15, 0.16, 0.12, 0.05, 0.01], "dir": Vector3(side * 0.12, -1.0, -0.2),
			"side": Vector3(1, 0, 0), "material": black, "lining": red, "thickness": 0.012, "stiffness": 0.035, "stiffness_tip": 0.005,
			"gravity": 8.5, "drag": 0.08, "wind": Vector3(side * 0.2, 0.0, -0.5), "colliders": cols})
	# --- paper talismans: three on the belt (front-right), one pair on the pauldron (they flutter)
	for k in 4:
		var a := deg_to_rad(28.0 + k * 24.0)
		var at := hips + Vector3(sin(a) * 0.175, -0.01, cos(a) * 0.145)
		L.talisman(b, "Hips", at, 0.3 + (k % 2) * 0.08, paper, Vector3(sin(a) * 0.25, -1.0, cos(a) * 0.25), 0.055)
		b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.014, 0.018), 0.01), red), Transform3D(Basis(Vector3.UP, a), at + Vector3(sin(a) * 0.012, -0.03, cos(a) * 0.012)))
	# --- asymmetric silver pauldron on the left with a red cross, black gloves with silver cuffs, boots
	ClassDress.pauldron(b, 1.0, silver, red, 1.1, 2, true)
	var lsh := b.bone_pos("LeftUpperArm")
	L.talisman(b, "LeftUpperArm", lsh + Vector3(0.12, -0.03, 0.03), 0.22, paper, Vector3(0.3, -1.0, 0.1), 0.04)
	L.talisman(b, "LeftUpperArm", lsh + Vector3(0.12, -0.03, -0.03), 0.18, paper, Vector3(0.3, -1.0, -0.1), 0.04)
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.04, 0.042, 0.048, 0.056], 0.0, 1.0, black, silver, 12)
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.06, 0.058, 0.05, 0.046], -0.04, 0.92, black, silver, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.04, -0.03), Vector2(0.04, -0.03), Vector2(0.045, 0.02), Vector2(0.0, 0.08), Vector2(-0.045, 0.02)]), 0.016, 0.004), silver)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.0, 0.06)))
	# small red hair cord with a silver bell-bead (a light Chinese touch)
	var head := b.bone_pos("Head")
	L.gem(b, "Head", head + Vector3(0.1, 0.08, -0.04), RED, 0.016, 0.3)
