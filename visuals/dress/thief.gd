extends RefCounted
## Thief 盗贼 (trapper), bible 2.5: hood, belt pouches, shuriken; dark green and tan with brass trim; a short dagger
## (WeaponFactory "dagger") and a belt of trap discs. Hero silhouette: a pointed hood joined to a capelet with a long
## pointed cloak tail (runtime cloth). Layering: dark leggings, green tunic, tan leather corset + bracers + boots.

const P := preload("res://visuals/dress/_night_lib.gd")
const GREEN := Color("#1F3B2D")
const GREEN_D := Color("#0F2219")
const TAN := Color("#C8A878")
const LEATHER := Color("#6A4A28")
const BRASS := Color("#B9944A")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_e",
		"height": 1.66,
		"proportions": [1.1, 0.92],
		"rim": Color(1.0, 0.92, 0.75),
		"dress": {
			# one-piece -> dark green tunic with tan trims; boots -> tan leather; hair -> chestnut
			"Onepice": {"map": [Color("#06100B"), Color("#173022"), Color("#4A7458")], "contrast": 1.25},
			"Shoes": {"map": [Color("#24160A"), Color("#5E4024"), Color("#C8A878")], "contrast": 1.2},
			"HAIR": {"map": [Color("#2E140A"), Color("#7A3E1E"), Color("#D08850")], "contrast": 1.1, "line": 1.7, "shade": Color(0.7, 0.55, 0.65)},
			"EyeIris": {"iris": Color(0.75, 1.15, 0.55)},
		},
		"anims": {&"idle": ["Idle_Sword"], &"attack": ["kk_Melee_1H_Attack_Stab"], &"attack_stab": ["kk_Melee_1H_Attack_Stab"],
			&"attack_1h_1": ["kk_Melee_1H_Attack_Slice_Diagonal"], &"attack_1h_2": ["kk_Melee_1H_Attack_Stab"], &"throw": ["OverhandThrow"]},
	}


static func build(b: AnimeBody) -> void:
	var green := AnimeGear.toon(GREEN, {"shade": Color(0.55, 0.6, 0.85), "rim": Color(0.9, 1.0, 0.8), "rim_strength": 0.8})
	var green_d := AnimeGear.toon(GREEN_D, {"shade": Color(0.6, 0.62, 0.88)})
	var tan := AnimeGear.toon(TAN, {"shade": Color("#8A6A50") / TAN, "rim": Color(1.0, 0.92, 0.75)})
	var leather := AnimeGear.toon(LEATHER, {"shade": Color(0.66, 0.55, 0.75)})
	var brass := AnimeGear.toon(BRASS, {"shade": ClassDress.GOLD_SHADE / BRASS, "rim": ClassDress.GOLD_HI})
	var steel := AnimeGear.steel(ClassDress.SILVER)
	var hips := b.bone_pos("Hips")
	var ch := b.bone_pos("Chest")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	# --- hood (green, tan lining) with a long swept point
	P.hood(b, green, tan, 0.94, 0.13)
	# --- capelet over the shoulders, tan rim, brass toggle clasp
	var cape := [Vector2(0.22, -0.16), Vector2(0.2, -0.08), Vector2(0.14, 0.0), Vector2(0.085, 0.045)]
	P.shell(b, "UpperChest", neck + Vector3(0, -0.03, -0.005), cape, green, TAU * 0.86, 0.85, 0.0, 24)
	P.shell(b, "UpperChest", neck + Vector3(0, -0.03, -0.005), [Vector2(0.224, -0.172), Vector2(0.218, -0.145)], tan, TAU * 0.86, 0.85, 0.0, 24)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.008, 0.008, 0.07, 8), brass), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), neck + Vector3(0, -0.06, 0.088)))
	# --- the hero element: a long pointed cloak tail from the capelet (green, tan lining), runtime cloth
	var cols := [["UpperChest", 0.11, 0.0], ["Hips", 0.24, -0.1], ["RightUpperLeg", 0.09, -0.12], ["LeftUpperLeg", 0.09, -0.12], ["RightLowerLeg", 0.075, -0.08], ["LeftLowerLeg", 0.075, -0.08]]
	ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(0, 0.04, -0.14)), {
		"name": "CloakTail", "length": 0.86, "segments": 11, "width": [0.3, 0.34, 0.32, 0.22, 0.04], "dir": Vector3(0, -1.0, -0.25),
		"side": Vector3(1, 0, 0), "material": green, "lining": tan, "thickness": 0.012,
		"stiffness": 0.022, "stiffness_tip": 0.003, "gravity": 9.0, "drag": 0.07, "wind": Vector3(0.0, 0, -0.7), "colliders": cols})
	# --- tan leather corset with brass lacing over the tunic
	var cy := hips.y
	var cor := [Vector2(0.125, cy + 0.0 - ch.y), Vector2(0.118, cy + 0.07 - ch.y), Vector2(0.12, 0.0), Vector2(0.128, 0.04)]
	P.shell(b, "Chest", ch + Vector3(0, 0, 0.005), cor, leather, TAU, 0.86)
	var lace: Array = []
	var lw: Array = []
	var ls: Array = []
	for i in 7:
		var t := float(i) / 6.0
		lace.append(Vector3((0.016 if i % 2 == 0 else -0.016), lerpf(cy + 0.01, ch.y + 0.03, t), ch.z + 0.005 + 0.108))
		lw.append(0.007)
		ls.append(Vector3(1, 0, 0))
	b.attach("Chest", AnimeGear.mi(AnimeGear.ribbon(lace, lw, ls, 0.004), brass), Transform3D.IDENTITY)
	# --- belt slung low with pouches, a jade pendant with a red tassel, and trap discs on the back
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.142, -0.02), Vector2(0.146, 0.0), Vector2(0.142, 0.02)], 24, 1.0, 0.86), leather), Transform3D(Basis(Vector3.FORWARD, 0.08), hips + Vector3(0, -0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.04, 0.035, 0.012)), brass), Transform3D(Basis(Vector3.FORWARD, 0.08), hips + Vector3(0, -0.02, 0.125)))
	for a: float in [-1.0, -0.55, 0.7]:
		P.pouch(b, leather, brass, a, Vector3(0.05, 0.055, 0.035), -0.05, 0.15)
	var jp := hips + Vector3(0.1, -0.05, 0.1)
	b.attach("Hips", AnimeGear.mi(AnimeGear.cyl(0.02, 0.02, 0.008, 14), AnimeGear.toon(Color("#5FBF8A"), {"shade": Color(0.5, 0.65, 0.85)})), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), jp))
	var red := AnimeGear.toon(Color("#C8202A"), {"shade": Color("#7A0F2E") / Color("#C8202A")})
	b.attach("Hips", AnimeGear.mi(AnimeGear.cyl(0.003, 0.014, 0.05, 8), red), Transform3D(Basis(), jp + Vector3(0, -0.045, 0.0)))
	for k in 3:
		var a2 := PI + (k - 1) * 0.42
		var disc := Node3D.new()
		AnimeGear.mi(AnimeGear.cyl(0.04, 0.04, 0.016, 16), AnimeGear.toon(Color("#3A3A40"), {"shade": Color(0.6, 0.6, 0.85)}), disc)
		AnimeGear.mi(AnimeGear.cyl(0.022, 0.022, 0.02, 12), brass, disc)
		AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.046, 8, 0.78), 0.008), steel, disc, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
		b.attach("Hips", disc, Transform3D(Basis(Vector3.UP, a2) * Basis(Vector3.RIGHT, PI * 0.5), hips + Vector3(sin(a2) * 0.155, -0.04, cos(a2) * 0.14)))
	# --- bandolier with shuriken across the chest (right shoulder -> left hip)
	var band: Array = []
	for i in 7:
		var t := float(i) / 6.0
		band.append(Vector3(lerpf(-0.1, 0.11, t), lerpf(neck.y - 0.04, hips.y - 0.0, t), ch.z + 0.11 + sin(t * PI) * 0.03))
	P.strap(b, "Chest", band, 0.03, leather, 0.01)
	for i in 3:
		var p: Vector3 = band[2 + i]
		b.attach("Chest", AnimeGear.mi(AnimeGear.extrude(P.star(0.028, 4), 0.005), steel), Transform3D(Basis(Vector3.FORWARD, 0.3 * i), p + Vector3(0, 0, 0.012)))
	# --- leggings (dark green) on the thighs, tan wraps at the knee
	for side: float in [-1.0, 1.0]:
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		P.sleeve(b, ul, ll, [Vector2(0.066, 0.25), Vector2(0.06, 0.7), Vector2(0.052, 1.04)], green_d, 14)
		P.wraps(b, ul, ll, 0.06, 0.054, 0.72, 1.0, 2, tan, 0.2)
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.034, 0.038, 0.042, 0.046], 0.3, 0.96, leather, brass, 12)
		P.wraps(b, la, hd, 0.036, 0.04, 0.1, 0.28, 2, tan, 0.25)
	# --- two pointed leather tassets over the front of the tunic
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var tp := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.045, -0.12), Vector2(0.0, -0.16), Vector2(-0.045, -0.12)])
		b.attach(leg, AnimeGear.mi(AnimeGear.extrude(tp, 0.014, 0.004), leather), Transform3D(Basis(Vector3.UP, side * 0.5) * Basis(Vector3.RIGHT, -0.2), hips + Vector3(side * 0.085, -0.04, 0.15)))
		b.attach(leg, AnimeGear.mi(AnimeGear.sphere(0.01, 6), brass), Transform3D(Basis(), hips + Vector3(side * 0.085, -0.06, 0.162)))
	# --- tall leather boot shafts over the laced stockings, brass-rimmed cuffs
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.056, 0.05, 0.044, 0.042], 0.0, 0.9, leather, brass, 12)
		var kp := b.bone_pos(ll)
		b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.06, -0.03), Vector2(0.066, 0.02)], 12), leather), Transform3D(Basis(), kp + Vector3(0, 0.0, 0.004)))
	# small pointed leather shoulder guard on the dagger arm
	ClassDress.pauldron(b, -1.0, leather, brass, 0.7, 2, true)
	# --- tan neckerchief knotted under the chin
	b.attach("Neck", AnimeGear.mi(AnimeGear.lathe([Vector2(0.062, -0.03), Vector2(0.074, -0.01), Vector2(0.07, 0.02)], 16, 1.0, 1.05), tan), Transform3D(Basis(), neck + Vector3(0, -0.005, 0.006)))
	var tri := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.045, 0.0), Vector2(0.045, 0.0), Vector2(0.0, -0.07)]), 0.01), tan)
	b.attach("UpperChest", tri, Transform3D(Basis(Vector3.RIGHT, -0.25), neck + Vector3(0, -0.035, 0.075)))
