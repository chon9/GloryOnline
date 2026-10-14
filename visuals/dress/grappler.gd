extends RefCounted
## Grappler 柔道, bible 2.5: gi-style wrap jacket with indigo lapels, black belt, heavy armoured forearms; indigo
## and white with silver trim; pair of tonfas (WeaponFactory "tonfa"). Hero silhouette: a long indigo headband
## whose two tails stream behind the head (runtime cloth), plus the belt ends. Light Chinese seasoning: frog
## buttons on the lapel and a red rope knot with tassels on the belt.

const P := preload("res://visuals/dress/_night_lib.gd")
const INDIGO := Color("#26335F")
const INDIGO_D := Color("#18224A")
const GI := Color("#F0EEE6")
const BELT := Color("#16141A")
const ROPE := Color("#C8202A")


static func dress() -> Dictionary:
	return {
		"base": "base_male",
		"height": 1.88,
		"proportions": [1.06, 0.94],
		"rim": Color(0.88, 0.93, 1.0),
		"dress": {
			# shirt + vest -> white gi under-layer with an indigo vest tone; trousers -> indigo gi pants; shoes -> dark
			"Tops": {"map": [Color("#1E2A55"), Color("#C8CCD8"), Color("#F4F2EC")], "contrast": 1.2},
			"Accessory_Tie": {"hide": true},
			"Bottoms": {"map": [Color("#0C1230"), Color("#22305E"), Color("#4A5A94")], "contrast": 1.2},
			"Shoes": {"map": [Color("#0A0A10"), Color("#1E1E2A"), Color("#4A4A5E")], "contrast": 1.2},
			"HairBack": {"map": [Color("#0C0A0A"), Color("#2A201C"), Color("#5A4A42")], "contrast": 1.1, "line": 1.8, "shade": Color(0.55, 0.5, 0.72)},
			"EyeIris": {"iris": Color(0.62, 0.72, 1.1)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Punch_Cross"], &"grab": ["Melee_Hook"]},
	}


static func build(b: AnimeBody) -> void:
	var gi := AnimeGear.toon(GI, {"shade": Color("#A9B3D6") / GI, "rim": Color.WHITE, "rim_strength": 0.7})
	var indigo := AnimeGear.toon(INDIGO, {"shade": Color(0.55, 0.55, 0.9), "rim": Color(0.75, 0.85, 1.0), "rim_strength": 0.8})
	var indigo_d := AnimeGear.toon(INDIGO_D, {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.75, 0.85, 1.0)})
	var belt := AnimeGear.toon(BELT, {"shade": Color(0.7, 0.7, 0.95), "rim": Color(0.8, 0.85, 1.0)})
	var silver := AnimeGear.steel(ClassDress.SILVER)
	var rope := AnimeGear.toon(ROPE, {"shade": Color("#7A0F2E") / ROPE})
	var hips := b.bone_pos("Hips")
	var ch := b.bone_pos("Chest")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- gi jacket: upper shell on the chest (wrap-front), skirt on the hips
	var top := [Vector2(0.162, hips.y + 0.04 - ch.y), Vector2(0.158, 0.0), Vector2(0.162, uc.y - ch.y + 0.02), Vector2(0.155, uc.y - ch.y + 0.1), Vector2(0.11, neck.y - ch.y - 0.005), Vector2(0.082, neck.y - ch.y + 0.03)]
	P.shell(b, "Chest", ch, top, gi, TAU, 0.8)
	var skirt := [Vector2(0.215, -0.24), Vector2(0.19, -0.1), Vector2(0.172, 0.0), Vector2(0.168, 0.07)]
	P.shell(b, "Hips", hips, skirt, gi, TAU * 0.9, 0.86)
	var hem := [Vector2(0.217, -0.245), Vector2(0.214, -0.22)]
	P.shell(b, "Hips", hips, hem, indigo, TAU * 0.9, 0.86)
	# crossed lapels (right over left as a gi is worn): indigo bands from the collar to the opposite hip
	for side: float in [1.0, -1.0]:
		var pts: Array = []
		for i in 7:
			var t := float(i) / 6.0
			var y := lerpf(neck.y + 0.02, hips.y - 0.02, t)
			var x := lerpf(side * 0.075, -side * 0.12, pow(t, 0.8))
			var zr := lerpf(0.105, 0.165, minf(t * 2.0, 1.0))
			pts.append(Vector3(x, y, sqrt(maxf(zr * zr - x * x * 0.4, 0.0)) * 0.86 + 0.012 + (0.006 if side > 0 else 0.0)))
		P.strap(b, "Chest", pts, 0.068, indigo, 0.012)
	# frog buttons (Chinese seasoning) on the outer lapel
	for k in 2:
		var p := Vector3(-0.045 - k * 0.04, uc.y - 0.07 - k * 0.09, 0.168)
		b.attach("Chest", AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.03, -0.006), Vector2(0.03, -0.006), Vector2(0.034, 0.006), Vector2(-0.034, 0.006)]), 0.01), rope), Transform3D(Basis(Vector3.FORWARD, 0.4), p))
		b.attach("Chest", AnimeGear.mi(AnimeGear.sphere(0.011, 8), AnimeGear.gold()), Transform3D(Basis(), p + Vector3(0.032, 0.012, 0.004)))
	# back crest: an indigo roundel with a silver swept-wing mark (original)
	b.attach("Chest", AnimeGear.mi(AnimeGear.cyl(0.075, 0.075, 0.01, 24), indigo), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), uc + Vector3(0, -0.03, -0.136)))
	b.attach("Chest", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(0.62), 0.012, 0.002), silver), Transform3D(Basis(Vector3.UP, PI), uc + Vector3(0, -0.03, -0.145)))
	# high gi collar ring
	P.shell(b, "UpperChest", neck, [Vector2(0.088, -0.05), Vector2(0.094, -0.005), Vector2(0.1, 0.03)], indigo, TAU * 0.78, 1.0)
	# --- wide half sleeves over the upper arms
	for side: float in [-1.0, 1.0]:
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		P.sleeve(b, ua, la, [Vector2(0.072, -0.08), Vector2(0.074, 0.3), Vector2(0.08, 0.75), Vector2(0.088, 1.04)], gi)
		P.sleeve(b, ua, la, [Vector2(0.089, 0.98), Vector2(0.091, 1.08)], indigo)
	# --- heavy forearm guards: indigo plates, silver bands and swept elbow fins
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.05, 0.06, 0.066, 0.07, 0.074], 0.14, 0.94, indigo, silver, 14)
		P.wraps(b, la, hd, 0.067, 0.072, 0.38, 0.72, 2, silver, 0.0)
		var ep := b.bone_pos(la)
		var fin := AnimeGear.mi(AnimeGear.extrude(P.spike(0.11, 0.026), 0.014, 0.003), silver)
		b.attach(la, fin, Transform3D(Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.FORWARD, side * 1.2), ep + Vector3(side * 0.03, 0.0, -0.05)))
	# --- one heavy pauldron on the lead (left) shoulder, a gi shoulder cap on the right
	ClassDress.pauldron(b, 1.0, indigo, silver, 1.12, 2, true)
	# --- black belt wound twice, square knot in front with two hanging ends, red rope with tassels at the side
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.175, -0.035), Vector2(0.178, 0.0), Vector2(0.175, 0.035)], 26, 1.0, 0.86), belt), Transform3D(Basis(), hips + Vector3(0, 0.05, 0)))
	var kn := AnimeGear.mi(AnimeGear.box(Vector3(0.06, 0.05, 0.035)), belt)
	b.attach("Hips", kn, Transform3D(Basis(Vector3.FORWARD, 0.25), hips + Vector3(0.02, 0.05, 0.155)))
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		for i in 5:
			var t := float(i) / 4.0
			pts.append(hips + Vector3(0.02 + side * (0.02 + t * 0.05), 0.04 - t * 0.26, 0.162 + t * 0.02))
		b.attach("Hips", AnimeGear.mi(AnimeGear.ribbon(pts, [0.05, 0.05, 0.05, 0.05, 0.05], [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT], 0.01), belt), Transform3D.IDENTITY)
		b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.052, 0.022, 0.012)), AnimeGear.gold()), Transform3D(Basis(), (pts[4] as Vector3) + Vector3(0, 0.005, 0.002)))
	var rp := hips + Vector3(0.15, 0.03, 0.07)
	b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.022, 10), rope), Transform3D(Basis(), rp))
	for k in 2:
		var tp: Array = [rp, rp + Vector3(0.01 + k * 0.015, -0.08, 0.005), rp + Vector3(0.015 + k * 0.02, -0.17, 0.01)]
		b.attach("Hips", AnimeGear.mi(AnimeGear.tube(tp, [0.008, 0.007, 0.006], 6), rope), Transform3D.IDENTITY)
		b.attach("Hips", AnimeGear.mi(AnimeGear.cyl(0.004, 0.018, 0.06, 8), rope), Transform3D(Basis(), (tp[2] as Vector3) + Vector3(0, -0.03, 0)))
	# --- shin guards (indigo, silver rim) with pointed knees over the gi pants, wrapped ankles
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.07, 0.066, 0.056, 0.05], 0.08, 0.86, indigo, silver, 14)
		P.knee(b, ll, indigo, silver, 1.05)
		P.wraps(b, ll, ft, 0.05, 0.048, 0.88, 1.0, 2, gi, 0.18)
	# --- the hero element: a long indigo headband tied at the back, two tails streaming (runtime cloth)
	var hc := head + Vector3(0, 0.12, -0.004)
	b.attach("Head", AnimeGear.mi(AnimeGear.lathe([Vector2(0.112, -0.018), Vector2(0.116, 0.0), Vector2(0.112, 0.02)], 26, 1.0, 1.12), indigo), Transform3D(Basis(Vector3.RIGHT, -0.12), hc))
	b.attach("Head", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.03, 0.018), 0.012, 0.003), silver), Transform3D(Basis(Vector3.RIGHT, -0.12), hc + Vector3(0, 0.012, 0.126)))
	var knot := AnimeGear.mi(AnimeGear.sphere(0.028, 10), indigo)
	knot.scale = Vector3(1.0, 0.8, 0.7)
	b.attach("Head", knot, Transform3D(Basis(), hc + Vector3(0.0, -0.01, -0.125)))
	var cols := [["Neck", 0.08, 0.0], ["UpperChest", 0.17, 0.0], ["Hips", 0.19, 0.0]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Head", Transform3D(Basis(), hc + Vector3(side * 0.02, -0.015, -0.13)), {
			"name": "Headband", "length": 0.78 if side > 0 else 0.62, "segments": 9, "width": [0.055, 0.065, 0.06, 0.03],
			"dir": Vector3(side * 0.25, -1.0, -0.35), "side": Vector3(1, 0, 0.2), "material": indigo, "lining": gi,
			"thickness": 0.008, "stiffness": 0.025, "stiffness_tip": 0.002, "gravity": 8.0, "drag": 0.06,
			"wind": Vector3(side * 0.4, 0.15, -1.2), "colliders": cols})
