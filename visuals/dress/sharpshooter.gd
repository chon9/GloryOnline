extends RefCounted
## Sharpshooter 神枪手, bible 2.5: twin revolvers (WeaponFactory "revolver" + left "pistol"), long duster coat with a
## shoulder capelet (runtime cloth tails = the hero silhouette), wide-brim gunslinger hat. Brown / crimson / brass.
## The base blazer becomes a brown riding jacket over a cream shirt, the tie a crimson cravat; a crimson waistcoat
## with brass buttons, crossed gun belts with holsters on both thighs, leather half-gauntlets, spurred knee boots.

const L := preload("res://visuals/dress/_gunfight_lib.gd")
const BROWN := Color("#5A3B28")
const CRIMSON := Color("#9E1B25")
const BRASS := Color("#B9944A")


static func dress() -> Dictionary:
	return {
		"base": "sakurada",
		"height": 1.86,
		"proportions": [1.07, 0.94],
		"rim": Color(1.0, 0.86, 0.66),
		"dress": {
			# blazer -> brown riding jacket (shirt stays cream), tie -> crimson cravat, trousers -> dark brown,
			# shoes -> boots; hair -> pale ash blond
			"Tops": {"map": [Color("#1A0F0A"), Color("#4E3222"), Color("#EDE2CC")], "contrast": 1.3},
			"Accessory": {"map": [Color("#3A0608"), Color("#9E1B25"), Color("#E05050")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#120C0A"), Color("#2E221C"), Color("#5E4A3C")], "contrast": 1.2},
			"Shoes": {"map": [Color("#140C08"), Color("#3E2618"), Color("#8A6040")], "contrast": 1.2},
			"HAIR": {"map": [Color("#6E665C"), Color("#C9C0AE"), Color("#F6F2E6")], "contrast": 1.15, "line": 1.7, "shade": Color(0.62, 0.6, 0.78)},
			"Brow": {"color": Color("#8A8070")},
			"EyeIris": {"iris": Color(1.0, 0.55, 0.42)},
		},
		"anims": {&"idle": ["Idle_Sword", "Pistol_Idle"], &"attack": ["Pistol_Shoot"]},
	}


static func build(b: AnimeBody) -> void:
	var coat := AnimeGear.toon(BROWN, {"shade": Color("#2A1A22") / BROWN, "rim": Color(1.0, 0.85, 0.65)})
	var coat_in := AnimeGear.toon(Color("#3A2418"), {"shade": Color(0.6, 0.55, 0.8)})
	var crimson := AnimeGear.toon(CRIMSON, {"shade": Color("#5A0A2A") / CRIMSON, "rim": Color(1.0, 0.7, 0.6)})
	var brass := AnimeGear.toon(BRASS, {"shade": ClassDress.GOLD_SHADE / BRASS, "rim": ClassDress.GOLD_HI})
	var leather := AnimeGear.toon(Color("#3E2618"), {"shade": Color(0.62, 0.55, 0.8)})
	var hat_mat := AnimeGear.toon(Color("#4A3020"), {"shade": Color(0.6, 0.52, 0.78), "rim": Color(1.0, 0.85, 0.65)})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	var yb := hips.y + 0.02 - uc.y
	# --- crimson waistcoat with brass buttons (over the cream shirt)
	var vest := [Vector2(0.158, yb - 0.02), Vector2(0.16, yb + 0.08), Vector2(0.172, -0.05), Vector2(0.178, 0.03), Vector2(0.16, 0.085), Vector2(0.1, 0.12)]
	L.shell(b, "UpperChest", vest, uc, crimson, 0.07, 1.0, 0.84)
	for k in 4:
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.011, 8), brass), Transform3D(Basis(), uc + Vector3(0.0, 0.04 - k * 0.07, 0.149 - absf(k - 1.5) * 0.004)))
	# --- the duster: open torso shell, popped collar, shoulder capelet, long split tails (cloth)
	var coat_p := [Vector2(0.172, yb - 0.04), Vector2(0.174, yb + 0.08), Vector2(0.186, -0.05), Vector2(0.194, 0.03), Vector2(0.18, 0.09), Vector2(0.135, 0.14), Vector2(0.1, 0.16)]
	var gap := 0.24
	L.shell(b, "UpperChest", coat_p, uc, coat, gap, 1.0, 0.86)
	for side: float in [-1.0, 1.0]:
		L.shell_edge(b, "UpperChest", coat_p, uc, gap, 1.0, 0.86, side, 0.03, coat_in, 0.006)
		L.shell_edge(b, "UpperChest", coat_p, uc, gap, 1.0, 0.86, side, 0.01, brass, 0.012)
	L.shell(b, "UpperChest", [Vector2(0.105, -0.03), Vector2(0.118, 0.03), Vector2(0.145, 0.1)], neck + Vector3(0, -0.02, -0.012), coat, 0.36, 1.0, 1.0, 18)
	var cape_p := [Vector2(0.3, -0.21), Vector2(0.27, -0.12), Vector2(0.2, -0.03), Vector2(0.13, 0.02), Vector2(0.105, 0.04)]
	L.shell(b, "UpperChest", cape_p, neck + Vector3(0, -0.04, -0.01), coat, 0.2, 1.0, 0.78)
	L.shell(b, "UpperChest", [Vector2(0.302, -0.222), Vector2(0.296, -0.198)], neck + Vector3(0, -0.04, -0.01), brass, 0.2, 1.0, 0.78)
	var cols := [["Hips", 0.19, -0.02], ["RightUpperLeg", 0.11, -0.18], ["LeftUpperLeg", 0.11, -0.18], ["RightLowerLeg", 0.085, -0.15], ["LeftLowerLeg", 0.085, -0.15]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.08, 0.02, -0.15)), {
			"name": "DusterBack", "length": 0.98, "segments": 11, "width": [0.21, 0.24, 0.27, 0.29, 0.3, 0.3],
			"dir": Vector3(side * 0.1, -1.0, -0.26), "side": Vector3(1, 0, 0.25 * side), "material": coat, "lining": coat_in,
			"thickness": 0.014, "stiffness": 0.035, "stiffness_tip": 0.006, "gravity": 9.0, "drag": 0.07,
			"wind": Vector3(0.4, 0, -0.7), "colliders": cols})
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.155, 0.02, 0.04)), {
			"name": "DusterFront", "length": 0.92, "segments": 10, "width": [0.13, 0.16, 0.18, 0.19, 0.19],
			"dir": Vector3(side * 0.12, -1.0, 0.02), "side": Vector3(-0.5, 0, side), "material": coat, "lining": coat_in, "lining_side": Vector3(-side, 0, -0.4),
			"thickness": 0.014, "stiffness": 0.045, "stiffness_tip": 0.008, "gravity": 9.0, "drag": 0.08, "colliders": cols})
	# half-belt across the back of the duster (hides the shell / tail seam), two brass buttons
	var hb: Array = []
	var hw: Array = []
	var hs: Array = []
	for i in 7:
		var a := lerpf(-PI * 0.78, -PI * 0.22, float(i) / 6.0)
		hb.append(hips + Vector3(cos(a) * 0.178, 0.035, sin(a) * 0.16))
		hw.append(0.045)
		hs.append(Vector3.UP)
	b.attach("Hips", AnimeGear.mi(AnimeGear.ribbon(hb, hw, hs, 0.014), coat_in), Transform3D.IDENTITY)
	for side: float in [-1.0, 1.0]:
		b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.013, 8), brass), Transform3D(Basis(), hips + Vector3(side * 0.1, 0.035, -0.172)))
	# --- coat cuffs turned back (brass buttons) over the leather half-gauntlets
	for side: float in [-1.0, 1.0]:
		var la := L.arm(side) + "LowerArm"
		var hd := L.arm(side) + "Hand"
		ClassDress.limb_guard(b, la, hd, [0.056, 0.064, 0.07], 0.52, 0.8, coat, brass, 14)
		L.gauntlet(b, side, leather, brass, {"radii": [0.052, 0.05, 0.048], "t0": 0.78, "fin": false, "studs": false})
	# --- crimson neckerchief knot + short point under the chin
	var knot := AnimeGear.mi(AnimeGear.sphere(0.026, 10), crimson)
	knot.scale = Vector3(1.2, 0.9, 0.7)
	b.attach("UpperChest", knot, Transform3D(Basis(), neck + Vector3(0, -0.035, 0.085)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.045, 0.0), Vector2(0.045, 0.0), Vector2(0.0, -0.085)]), 0.012, 0.003), crimson), Transform3D(Basis(Vector3.RIGHT, 0.25), neck + Vector3(0, -0.045, 0.092)))
	# --- crossed gun belts slung low, brass bullet loops, holsters on both thighs
	for side: float in [-1.0, 1.0]:
		var belt := Node3D.new()
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.168, -0.02), Vector2(0.172, 0.02)], 26, 1.0, 0.86), leather, belt)
		for k in 7:
			var a := PI * 0.5 + side * (0.35 + k * 0.17)
			AnimeGear.mi(AnimeGear.cyl(0.006, 0.006, 0.032, 6), brass, belt, Transform3D(Basis(), Vector3(cos(a) * 0.175, 0.0, sin(a) * 0.175 * 0.86)))
		b.attach("Hips", belt, Transform3D(Basis(Vector3.BACK, side * 0.16), hips + Vector3(0, -0.02, 0.0)))
		L.holster(b, side, leather, brass)
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.04, 0.014)), brass), Transform3D(Basis(), hips + Vector3(0, -0.0, 0.152)))
	# --- spurred knee boots with a folded cuff
	for side: float in [-1.0, 1.0]:
		var ll := L.arm(side) + "LowerLeg"
		var ft := L.arm(side) + "Foot"
		ClassDress.limb_guard(b, ll, ft, [0.078, 0.064, 0.056, 0.054], 0.04, 0.92, leather, null, 14)
		var kp := b.bone_pos(ll)
		b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.074, -0.03), Vector2(0.086, 0.02)], 14), coat_in), Transform3D(Basis(), kp + Vector3(0, -0.04, 0)))
		var fp := b.bone_pos(ft)
		var spur := Node3D.new()
		AnimeGear.mi(AnimeGear.cyl(0.004, 0.004, 0.06, 6), brass, spur, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.03)))
		AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.018, 6, 0.4), 0.004), brass, spur, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 0, -0.065)))
		b.attach(ft, spur, Transform3D(Basis(), fp + Vector3(0, -0.04, -0.03)))
	# --- the wide-brim gunslinger hat: curled brim, pinched crown, crimson band, brass concho; ash locks under it
	var hat := Node3D.new()
	hat.name = "GunslingerHat"
	AnimeGear.mi(L.brim(0.1, 0.235, 0.07, 0.02, 0.012, 36, 1.1), hat_mat, hat)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.112, 0.0), Vector2(0.116, 0.06), Vector2(0.108, 0.105), Vector2(0.075, 0.125), Vector2(0.0, 0.112)], 24, 1.0, 1.18), hat_mat, hat)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.117, 0.004), Vector2(0.118, 0.034)], 24, 1.0, 1.18), crimson, hat)
	AnimeGear.mi(AnimeGear.cyl(0.016, 0.016, 0.008, 12), brass, hat, Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis(), Vector3(0.0, 0.019, 0.142)))
	b.attach("Head", hat, Transform3D(Basis(Vector3.RIGHT, -0.08) * Basis(Vector3.BACK, 0.06), head + Vector3(0.0, 0.175, -0.005)))
