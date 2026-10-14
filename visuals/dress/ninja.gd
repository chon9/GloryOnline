extends RefCounted
## Ninja / Shadow Warrior 忍者, bible 2.5: ninja wrap, long scarf, ninjato (WeaponFactory "ninjato"); navy with a
## crimson scarf and dark-steel plates. Hero silhouette: a long crimson scarf wound round the neck, two tails
## streaming 1.5 m behind (runtime cloth). Layering: navy undersuit, crossed navy wrap top with a crimson obi,
## split hakama panels over the legs, dark-steel tekko (forearm) and suneate (shin) plates with crimson cords.

const P := preload("res://visuals/dress/_night_lib.gd")
const NAVY := Color("#1A2448")
const NAVY_D := Color("#0D1430")
const CRIMSON := Color("#C8202A")
const PLATE := Color("#3A4258")


static func dress() -> Dictionary:
	return {
		"base": "sendagaya_shino",
		"height": 1.72,
		"proportions": [1.07, 0.95],
		"rim": Color(0.85, 0.88, 1.0),
		"dress": {
			# uniform -> navy wrap, ribbon -> crimson, skirt -> deep navy, shoes -> navy tabi boots, hair -> blue-black
			"Tops": {"map": [Color("#050816"), Color("#111A38"), Color("#2A3866")], "contrast": 1.25},
			"Accessory": {"map": [Color("#3A0A10"), Color("#C8202A"), Color("#FF7A6A")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#04060F"), Color("#0E1430"), Color("#22305A")], "contrast": 1.2},
			"Shoes": {"map": [Color("#04060E"), Color("#121A34"), Color("#3A4466")], "contrast": 1.2},
			"HAIR": {"map": [Color("#040408"), Color("#12141E"), Color("#3A4060")], "contrast": 1.05, "line": 1.7, "shade": Color(0.55, 0.55, 0.8)},
			"EyeIris": {"iris": Color(1.2, 0.4, 0.45)},
		},
		"anims": {&"idle": ["Idle_Sword"], &"attack": ["kk_Melee_1H_Attack_Slice_Horizontal"],
			&"attack_1h_1": ["kk_Melee_1H_Attack_Slice_Diagonal"], &"attack_1h_2": ["kk_Melee_1H_Attack_Slice_Horizontal"],
			&"attack_1h_3": ["kk_Melee_1H_Attack_Stab"], &"attack_stab": ["kk_Melee_1H_Attack_Stab"]},
	}


static func build(b: AnimeBody) -> void:
	var navy := AnimeGear.toon(NAVY, {"shade": Color(0.55, 0.55, 0.9), "rim": Color(0.75, 0.82, 1.0), "rim_strength": 0.8})
	var navy_d := AnimeGear.toon(NAVY_D, {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.75, 0.82, 1.0)})
	var crimson := AnimeGear.toon(CRIMSON, {"shade": Color("#7A0F2E") / CRIMSON, "rim": Color(1.0, 0.75, 0.6)})
	var plate := AnimeGear.toon(PLATE, {"shade": Color(0.55, 0.55, 0.85), "rim": Color.WHITE, "rim_strength": 0.9})
	var silver := AnimeGear.steel(ClassDress.SILVER)
	var hips := b.bone_pos("Hips")
	var ch := b.bone_pos("Chest")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- crossed wrap top: two navy lapel bands meeting at the obi, crimson edge on the outer one
	for side: float in [1.0, -1.0]:
		var pts: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var y := lerpf(neck.y + 0.0, hips.y + 0.1, t)
			var x := lerpf(side * 0.06, -side * 0.08, t)
			var z := ch.z + lerpf(0.07, 0.125, sin(minf(t * 1.6, 1.0) * PI * 0.5)) - (t * t * 0.03)
			pts.append(Vector3(x, y, z + (0.006 if side > 0 else 0.0)))
		P.strap(b, "Chest", pts, 0.05, crimson if side > 0 else navy_d, 0.012)
	# --- crimson obi sash at the waist, a steel plate in front and a flat bow at the back
	var oy := hips.y + 0.08
	b.attach("Spine", AnimeGear.mi(AnimeGear.lathe([Vector2(0.138, oy - 0.05), Vector2(0.142, oy), Vector2(0.138, oy + 0.05)], 26, 1.0, 0.86), crimson), Transform3D(Basis(), Vector3(0, 0, hips.z + 0.005)))
	b.attach("Spine", AnimeGear.mi(AnimeGear.lathe([Vector2(0.141, oy - 0.012), Vector2(0.143, oy + 0.012)], 26, 1.0, 0.86), navy_d), Transform3D(Basis(), Vector3(0, 0, hips.z + 0.005)))
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array()
		for v: Vector2 in [Vector2(0.0, -0.02), Vector2(0.1, -0.06), Vector2(0.12, 0.0), Vector2(0.1, 0.055), Vector2(0.0, 0.02)]:
			wing.append(Vector2(v.x * side, v.y))
		if side < 0:
			wing.reverse()
		b.attach("Spine", AnimeGear.mi(AnimeGear.extrude(wing, 0.03, 0.006), crimson), Transform3D(Basis(), Vector3(0, oy + 0.01, hips.z - 0.135)))
	b.attach("Spine", AnimeGear.mi(AnimeGear.box(Vector3(0.045, 0.06, 0.04)), crimson), Transform3D(Basis(), Vector3(0, oy + 0.01, hips.z - 0.13)))
	# shuriken tucked in the obi
	b.attach("Spine", AnimeGear.mi(AnimeGear.extrude(P.star(0.035, 4), 0.006), silver), Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.11, oy, hips.z + 0.09)))
	# --- split hakama panels over the skirt: front pair + back pair, navy with crimson hem
	var knee := b.bone_pos("RightLowerLeg")
	for k in 4:
		var a := deg_to_rad([-35.0, 35.0, -150.0, 150.0][k])
		var leg := "RightUpperLeg" if a < 0 else "LeftUpperLeg"
		var top := hips.y + 0.04
		var bot := lerpf(hips.y, knee.y, 0.72)
		var pts: Array = []
		var ws: Array = []
		var sides: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var r := lerpf(0.15, 0.2, t)
			pts.append(Vector3(sin(a) * r, lerpf(top, bot, t), cos(a) * r * 0.85))
			ws.append(lerpf(0.12, 0.15, t))
			sides.append(Vector3(cos(a), 0, -sin(a)))
		b.attach(leg, AnimeGear.mi(AnimeGear.ribbon(pts, ws, sides, 0.012), navy), Transform3D.IDENTITY)
		var hp: Array = []
		var hs: Array = []
		var p_last: Vector3 = pts[5]
		for i in 4:
			hp.append(p_last + (sides[5] as Vector3) * lerpf(-0.075, 0.075, float(i) / 3.0) + Vector3(0, 0.008, 0))
			hs.append(Vector3.UP)
		b.attach(leg, AnimeGear.mi(AnimeGear.ribbon(hp, [0.022, 0.022, 0.022, 0.022], hs, 0.016), crimson), Transform3D.IDENTITY)
	# --- tekko: dark-steel forearm plates with crimson cord wraps; pointed shoulder guard on the sword arm
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.036, 0.04, 0.045, 0.05], 0.25, 0.95, plate, silver, 12)
		P.wraps(b, la, hd, 0.038, 0.042, 0.06, 0.24, 3, crimson, 0.25)
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		P.sleeve(b, ua, la, [Vector2(0.052, -0.05), Vector2(0.05, 0.5), Vector2(0.046, 1.0)], navy_d, 12)
	ClassDress.pauldron(b, -1.0, plate, crimson, 0.82, 2, true)
	# --- legs: navy thigh wraps, suneate shin plates with pointed knees, crimson ankle cords
	for side: float in [-1.0, 1.0]:
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		P.sleeve(b, ul, ll, [Vector2(0.074, 0.35), Vector2(0.068, 0.7), Vector2(0.06, 1.02)], navy_d, 14)
		P.wraps(b, ul, ll, 0.072, 0.064, 0.45, 0.95, 3, navy, 0.22)
		ClassDress.limb_guard(b, ll, ft, [0.058, 0.055, 0.047, 0.043], 0.08, 0.84, plate, silver, 12)
		P.knee(b, ll, plate, silver, 0.9, 0.062)
		P.wraps(b, ll, ft, 0.045, 0.043, 0.86, 1.0, 2, crimson, 0.25)
	# kunai holster on the right thigh
	var up := b.bone_pos("RightUpperLeg")
	var sp := up.lerp(knee, 0.4)
	for k in 2:
		var kv := Node3D.new()
		AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.014, 0.0), Vector2(0.014, 0.0), Vector2(0.0, 0.08)]), 0.006), silver, kv)
		AnimeGear.mi(AnimeGear.cyl(0.008, 0.008, 0.06, 6), navy_d, kv, Transform3D(Basis(), Vector3(0, -0.03, 0)))
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.01, -0.07), Vector2(0.014, -0.064), Vector2(0.01, -0.058)], 8), silver, kv)
		b.attach("RightUpperLeg", kv, Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.FORWARD, PI), sp + Vector3(-0.078, 0.02, 0.025 - k * 0.035)))
	# --- forehead guard: a small swept steel plate on a crimson band (original shape)
	var hc := head + Vector3(0, 0.115, 0.0)
	b.attach("Head", AnimeGear.mi(AnimeGear.lathe([Vector2(0.104, -0.012), Vector2(0.108, 0.0), Vector2(0.104, 0.012)], 24, 1.0, 1.12), crimson), Transform3D(Basis(Vector3.RIGHT, -0.18), hc))
	b.attach("Head", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(0.55), 0.01, 0.002), silver), Transform3D(Basis(Vector3.RIGHT, -0.18), hc + Vector3(0, 0.02, 0.118)))
	# --- lower-face mask (navy)
	P.mask(b, navy_d, 0.92, 0.072, 0.002)
	# --- the hero element: crimson scarf wound round the neck with two long trailing tails (runtime cloth)
	var wrap := AnimeGear.mi(AnimeGear.lathe([Vector2(0.075, -0.05), Vector2(0.105, -0.03), Vector2(0.11, 0.015), Vector2(0.085, 0.045)], 18, 1.0, 1.05), crimson)
	b.attach("Neck", wrap, Transform3D(Basis(Vector3.RIGHT, 0.1), neck + Vector3(0, -0.005, 0.005)))
	var knot := AnimeGear.mi(AnimeGear.sphere(0.034, 10), crimson)
	knot.scale = Vector3(1.0, 0.8, 0.7)
	b.attach("UpperChest", knot, Transform3D(Basis(), neck + Vector3(0.05, -0.05, -0.075)))
	var cols := [["UpperChest", 0.15, 0.0], ["Hips", 0.18, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.08, -0.1], ["LeftLowerLeg", 0.08, -0.1]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(0.05, -0.06, -0.09)), {
		"name": "ScarfLong", "length": 1.55, "segments": 14, "width": [0.13, 0.16, 0.15, 0.13, 0.08, 0.03], "dir": Vector3(0.2, -0.85, -0.7),
		"side": Vector3(1, 0.2, 0), "material": crimson, "thickness": 0.012, "stiffness": 0.025, "stiffness_tip": 0.003,
		"gravity": 7.0, "drag": 0.06, "wind": Vector3(0.5, 0.05, -0.65), "colliders": cols})
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), neck + Vector3(0.03, -0.07, -0.09)), {
		"name": "ScarfShort", "length": 0.95, "segments": 10, "width": [0.12, 0.13, 0.1, 0.03], "dir": Vector3(-0.15, -0.95, -0.5),
		"side": Vector3(1, 0.1, 0), "material": crimson, "thickness": 0.012, "stiffness": 0.03, "stiffness_tip": 0.004,
		"gravity": 7.0, "drag": 0.07, "wind": Vector3(0.6, 0.0, -0.9), "colliders": cols})
