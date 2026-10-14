extends RefCounted
## Berserker 狂剑士 (落花狼藉 / Hundred Blossoms colour cues), bible 2.5: huge greatsword, bare sword arm, tattered
## half-cape. Crimson / black / bronze: a black leather cuirass with crimson plate, one massive layered pauldron on
## the off arm, bare bandaged arms, a torn crimson half-cape over the left shoulder (runtime cloth), torn waist tabards, red rope sash
## with tassels; wild crimson hair. Weapon: WeaponFactory "greatsword" (two-handed).

const L := preload("res://visuals/dress/_swordmage_lib.gd")
const CRIMSON := Color("#9E1B25")
const BLACK := Color("#1A1416")
const BRONZE := Color("#B07A3A")


static func dress() -> Dictionary:
	return {
		"base": "hairsample_male",
		"height": 1.9,
		"proportions": [1.07, 0.93],
		"rim": Color(1.0, 0.8, 0.62),
		"dress": {
			# hoodie -> black-crimson gambeson, trousers -> black, shoes -> dark leather boots; hair -> wild crimson
			# the hoodie is hidden: bare (bandaged) arms under the cuirass, as the bible's "bare arm" hook asks
			"Tops": {"hide": true},
			"Bottoms": {"map": [Color("#060406"), Color("#151014"), Color("#3A2E34")], "contrast": 1.2},
			"Shoes": {"map": [Color("#0C0806"), Color("#2A1A12"), Color("#6A4A32")], "contrast": 1.2},
			"HAIR": {"map": [Color("#8A1018"), Color("#D02A2E"), Color("#FF8A66")], "contrast": 1.1, "line": 1.8, "shade": Color(0.6, 0.45, 0.7)},
			"Brow": {"color": Color("#5A1014")},
			"EyeIris": {"iris": Color(1.15, 0.55, 0.35)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_C"], &"attack_2h": ["Sword_Regular_C"],
			&"attack_1h_3": ["Sword_Regular_C"]},
		"grips": {"greatsword": {"kind": "blade", "tilt": 0.0, "two_hand": true}},
	}


static func build(b: AnimeBody) -> void:
	var black := AnimeGear.toon(BLACK, {"shade": Color(0.6, 0.55, 0.85), "rim": Color(1.0, 0.75, 0.6)})
	var crimson := AnimeGear.toon(CRIMSON, {"shade": Color("#4A0A22") / CRIMSON, "rim": Color(1.0, 0.7, 0.55)})
	var bronze := AnimeGear.toon(BRONZE, {"shade": Color("#5A2E14") / BRONZE, "rim": Color("#FFD8A0")})
	var gold := AnimeGear.gold()
	var leather := AnimeGear.toon(ClassDress.LEATHER)
	var wrap := AnimeGear.toon(Color("#D8CCB8"), {"shade": Color("#8A7A8A") / Color("#D8CCB8")})
	var rope := AnimeGear.toon(Color("#C8202A"), {"shade": Color(0.55, 0.3, 0.55)})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var neck := b.bone_pos("Neck")
	# --- cuirass: black leather shell, crimson chest plate with a bronze V, bronze rims
	var y0 := ch.y - 0.13
	var y1 := uc.y + 0.1
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.172, y0 - uc.y), Vector2(0.186, ch.y - uc.y), Vector2(0.196, 0.03), Vector2(0.18, 0.08), Vector2(0.125, y1 - uc.y)], 22, 1.0, 0.86), black), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.128, y1 - uc.y - 0.012), Vector2(0.12, y1 - uc.y + 0.01)], 22, 1.0, 0.86), bronze), Transform3D(Basis(), uc))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.lathe([Vector2(0.174, y0 - uc.y - 0.008), Vector2(0.175, y0 - uc.y + 0.018)], 22, 1.0, 0.86), bronze), Transform3D(Basis(), uc))
	# crimson chest plate: two swept halves meeting in a V (asymmetric: the left half is bigger)
	for side: float in [-1.0, 1.0]:
		var s := 1.12 if side > 0 else 0.92
		var half := PackedVector2Array([Vector2(0.0, -0.11), Vector2(side * 0.02, -0.11), Vector2(side * 0.15 * s, 0.02), Vector2(side * 0.14 * s, 0.1), Vector2(side * 0.05, 0.07), Vector2(0.0, -0.02)])
		if side < 0:
			half.reverse()
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(half, 0.018, 0.004), crimson), Transform3D(Basis(Vector3.UP, side * 0.32), uc + Vector3(side * 0.02, -0.02, 0.155)))
	var vee := PackedVector2Array([Vector2(-0.07, 0.06), Vector2(-0.05, 0.06), Vector2(0.0, -0.06), Vector2(0.05, 0.06), Vector2(0.07, 0.06), Vector2(0.0, -0.1)])
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(vee, 0.024, 0.003), bronze), Transform3D(Basis(), uc + Vector3(0, 0.0, 0.17)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.018, 10), AnimeGear.toon(Color("#FF3A2A"), {"emit": Color("#FF3A2A") * 1.1, "outline": false})), Transform3D(Basis(), uc + Vector3(0, -0.07, 0.18)))
	# standing mandarin collar (crimson, bronze rim), open at the front
	var collar := L.shell([Vector2(0.088, -0.05), Vector2(0.1, 0.02), Vector2(0.108, 0.06)], 0.16, crimson, 20, 1.0)
	b.attach("UpperChest", collar, Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	b.attach("UpperChest", L.shell([Vector2(0.108, 0.055), Vector2(0.112, 0.072)], 0.16, bronze, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	# --- off arm (left): massive three-layer crimson/bronze pauldron with a swept fin, black gauntlet
	ClassDress.pauldron(b, 1.0, crimson, bronze, 1.38, 3, true)
	var lsh := b.bone_pos("LeftUpperArm")
	b.attach("LeftUpperArm", AnimeGear.mi(AnimeGear.extrude(L.fin(0.2, 0.09), 0.012, 0.0), bronze), Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.FORWARD, -0.15), lsh + Vector3(0.1, 0.13, 0.03)))
	ClassDress.limb_guard(b, "LeftLowerArm", "LeftHand", [0.042, 0.05, 0.058, 0.066], 0.25, 1.0, black, bronze, 14)
	var lla := b.bone_pos("LeftLowerArm")
	var lh := b.bone_pos("LeftHand")
	b.attach("LeftLowerArm", AnimeGear.mi(AnimeGear.extrude(L.fin(0.16, 0.06), 0.012, 0.0), crimson), Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, PI), lla.lerp(lh, 0.75) + Vector3(-0.0, 0.055, 0.0)))
	# --- sword arm (right): no plate, crimson-stained bandage wraps from elbow to knuckles + a bronze cuff
	L.bandage(b, "RightUpperArm", "RightLowerArm", 0.052, 2.2, 0.45, 1.0, wrap, 0.03)
	L.bandage(b, "RightLowerArm", "RightHand", 0.045, 3.2, 0.0, 0.95, wrap, 0.03)
	var rla := b.bone_pos("RightLowerArm")
	var rh := b.bone_pos("RightHand")
	var cuff := AnimeGear.lathe([Vector2(0.05, 0.0), Vector2(0.056, 0.05), Vector2(0.06, 0.07)], 14)
	b.attach("RightLowerArm", AnimeGear.mi(cuff, bronze), Transform3D(Basis(Quaternion(Vector3.UP, (rh - rla).normalized())), rla.lerp(rh, 0.55)))
	ClassDress.pauldron(b, -1.0, black, bronze, 0.8, 1, false)
	# --- belt, red rope sash with two tassels (Chinese seasoning), torn crimson tabards front and back
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.162, -0.03), Vector2(0.166, 0.03)], 24, 1.0, 0.82), leather), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.17, -0.012), Vector2(0.172, 0.012)], 24, 1.0, 0.84), rope), Transform3D(Basis(Vector3.FORWARD, 0.08), hips + Vector3(0, 0.0, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.cyl(0.042, 0.042, 0.02, 6), bronze), Transform3D(Basis(Vector3.RIGHT, PI / 2), hips + Vector3(0, 0.02, 0.138)))
	L.tassel(b, "Hips", hips + Vector3(0.1, -0.01, 0.12), rope, gold, 0.26)
	L.tassel(b, "Hips", hips + Vector3(0.13, -0.0, 0.08), rope, gold, 0.2)
	# short black back tabard with a pointed crimson hem
	var tb: Array = []
	var tw: Array = []
	var ts: Array = []
	for i in 5:
		var t := float(i) / 4.0
		tb.append(Vector3(0, hips.y - t * 0.36, -0.15 - t * 0.07))
		tw.append(lerpf(0.24, 0.2, t))
		ts.append(Vector3.RIGHT)
	b.attach("Hips", AnimeGear.mi(AnimeGear.ribbon(tb, tw, ts, 0.012), black), Transform3D.IDENTITY)
	var tip := PackedVector2Array([Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.08, -0.05), Vector2(0.03, -0.03), Vector2(0.0, -0.1), Vector2(-0.04, -0.035), Vector2(-0.08, -0.06)])
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(tip, 0.014, 0.0), crimson), Transform3D(Basis(Vector3.RIGHT, 0.2), (tb[4] as Vector3) + Vector3(0, 0.01, 0)))
	# a torn crimson sash end hanging from the rope belt on the left hip (runtime cloth)
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0.12, -0.02, 0.1)), {
		"name": "SashEnd", "length": 0.62, "segments": 8, "width": [0.1, 0.12, 0.11, 0.13, 0.05, 0.09, 0.02], "dir": Vector3(0.15, -1.0, 0.05),
		"side": Vector3(0.6, 0, 0.8), "material": crimson, "thickness": 0.01, "stiffness": 0.05, "stiffness_tip": 0.008,
		"gravity": 8.0, "drag": 0.08, "wind": Vector3(0.4, 0, -0.5), "colliders": [["Hips", 0.18, -0.05], ["LeftUpperLeg", 0.1, -0.15]]})
	# side faulds: black plates with bronze rims
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var tp := PackedVector2Array([Vector2(-0.065, 0.0), Vector2(0.065, 0.0), Vector2(0.06, -0.15), Vector2(0.0, -0.21), Vector2(-0.06, -0.15)])
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(tp, 0.016, 0.004), black), Transform3D(Basis(Vector3.UP, side * 1.25) * Basis(Vector3.RIGHT, -0.12), hips + Vector3(side * 0.165, -0.03, 0.02)))
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.02, 0.028), 0.022), bronze), Transform3D(Basis(Vector3.UP, side * 1.25), hips + Vector3(side * 0.175, -0.07, 0.02)))
	# --- greaves: black with pointed bronze-rimmed crimson knee guards, boots with claw toes
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.07, 0.064, 0.054, 0.05], 0.05, 0.94, black, bronze, 14)
		var kp := b.bone_pos(ll)
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(L.knee_plate(0.05), 0.03, 0.006), bronze), Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.025, 0.066)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(L.knee_plate(0.038), 0.03, 0.004), crimson), Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.03, 0.074)))
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(L.fin(0.11, 0.05), 0.01, 0.0), bronze), Transform3D(Basis(Vector3.UP, side * -PI * 0.5) * Basis(Vector3.FORWARD, 0.5), kp + Vector3(side * 0.065, 0.02, 0.0)))
	# --- the hero element: a torn crimson half-cape pinned at the left pauldron (runtime cloth), with a short
	# black under-layer for depth
	var cols := [["UpperChest", 0.18, 0.0], ["Hips", 0.2, 0.0], ["LeftUpperLeg", 0.11, -0.15], ["RightUpperLeg", 0.11, -0.15], ["LeftLowerLeg", 0.09, -0.1]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(0.1, 0.1, -0.12)), {
		"name": "HalfCape", "length": 1.15, "segments": 12, "width": [0.3, 0.36, 0.38, 0.34, 0.26, 0.3, 0.12, 0.22, 0.04],
		"dir": Vector3(0.12, -1.0, -0.25), "side": Vector3(1, 0, 0.15), "material": crimson, "lining": AnimeGear.toon(Color("#3A0A12"), {"shade": Color(0.6, 0.5, 0.8)}), "thickness": 0.014,
		"stiffness": 0.035, "stiffness_tip": 0.004, "gravity": 9.0, "drag": 0.08, "wind": Vector3(0.6, 0.0, -0.7), "colliders": cols})
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.034, 0.034, 0.016, 8), bronze), Transform3D(Basis(Vector3.RIGHT, PI / 2), uc + Vector3(0.12, 0.08, 0.12)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon([uc + Vector3(0.12, 0.08, 0.12), uc + Vector3(0.17, 0.12, 0.0), uc + Vector3(0.13, 0.11, -0.12)], [0.03, 0.035, 0.03], [Vector3.UP, Vector3.UP, Vector3.UP], 0.01), leather), Transform3D.IDENTITY)
