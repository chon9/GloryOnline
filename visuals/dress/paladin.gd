extends RefCounted
## Paladin 守护天使 (off-tank healer, "guardian angel"), bible 2.5: wings motif, white / sky blue / gold; great axe
## (WeaponFactory "great_axe"). Hero silhouette: a pair of folded armoured wings on the back plate, plus long
## sky-blue tabard tails (runtime cloth). White-gold plate with feathered pauldrons, winged circlet, platinum hair.

const L := preload("res://visuals/dress/_priest_lib.gd")
const WHITE := Color("#EEF0F4")
const SKY := Color("#5FA8E8")
const SKY_D := Color("#2E5E9E")


static func dress() -> Dictionary:
	return {
		"base": "sendagaya_shino",
		"height": 1.76,
		"proportions": [1.07, 0.95],
		# the uniform skirt peeks between the hip plates: cull it below the belt (plates + under-hose cover the hips)
		"cull": [{"mat": "Bottoms", "bone": "Hips", "min": Vector3(-0.6, -0.7, -0.5), "max": Vector3(0.6, -0.04, 0.5)}],
		"rim": Color(1.0, 0.95, 0.82),
		"dress": {
			# uniform -> sky-blue arming dress with white collar, ribbon -> gold, skirt -> deep sky, shoes -> white
			"Tops": {"map": [Color("#0E2648"), Color("#2E6AB0"), Color("#9ACAF2")], "contrast": 1.3},
			"Accessory": {"map": [Color("#6A4A14"), Color("#D8B25A"), Color("#FFE9A8")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#0E2648"), Color("#2E5E9E"), Color("#7FB4E8")], "contrast": 1.2},
			"Shoes": {"map": [Color("#5A5E70"), Color("#D8DCE6"), Color("#FFFFFF")], "contrast": 1.2},
			"HAIR": {"map": [Color("#9A7A40"), Color("#E8D49A"), Color("#FFF8E0")], "contrast": 1.1, "line": 1.7, "shade": Color(0.8, 0.68, 0.72)},
			"Brow": {"color": Color("#A08050")},
			"EyeIris": {"iris": Color(0.6, 0.85, 1.25)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["kk_Melee_2H_Attack_Chop", "Sword_Regular_C"],
			&"heal": ["kk_Ranged_Magic_Raise", "Power Up"]},
	}


static func build(b: AnimeBody) -> void:
	var white := AnimeGear.toon(WHITE, {"shade": Color("#9AA6CC") / WHITE, "rim": Color(1.0, 0.95, 0.85), "rim_strength": 0.8})
	var sky := AnimeGear.toon(SKY, {"shade": Color(0.55, 0.58, 0.9), "rim": Color(0.9, 0.97, 1.0)})
	var sky_d := AnimeGear.toon(SKY_D, {"shade": Color(0.55, 0.55, 0.9)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	var sp := b.bone_pos("Spine")
	var ch := b.bone_pos("Chest")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- breastplate: white shell shaped over the bust, gold rims, sky gem in a gold wing crest
	var y0 := ch.y - 0.07
	var y1 := uc.y + 0.1
	L.shell(b, "UpperChest", uc, [Vector2(0.135, y0 - uc.y), Vector2(0.15, ch.y - uc.y), Vector2(0.158, 0.02), Vector2(0.145, 0.07), Vector2(0.1, y1 - uc.y)], white, 0.95)
	L.rim(b, "UpperChest", uc, 0.102, y1 - uc.y, gold, 0.95)
	L.rim(b, "UpperChest", uc, 0.137, y0 - uc.y, gold, 0.95)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.wing_crest(1.25), 0.012, 0.003), gold), Transform3D(Basis(), uc + Vector3(0, 0.035, 0.152)))
	L.gem(b, "UpperChest", uc + Vector3(0, 0.04, 0.162), Color("#7FC8FF"), 0.016, 1.3)
	# corset-like waist plate
	L.shell(b, "Spine", Vector3(0, sp.y, 0), [Vector2(0.13, -0.06), Vector2(0.122, 0.0), Vector2(0.13, 0.07)], white, 0.85)
	L.rim(b, "Spine", Vector3(0, sp.y, 0), 0.131, -0.06, gold, 0.85, TAU, true, 0.012)
	# --- feathered pauldrons: a layered white plate + 4 swept feathers each (the wing motif on the shoulders)
	ClassDress.pauldron(b, -1.0, white, gold, 1.05, 2, false)
	ClassDress.pauldron(b, 1.0, white, gold, 1.05, 2, false)
	for side: float in [-1.0, 1.0]:
		var arm := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var sh := b.bone_pos(arm)
		var w := Node3D.new()
		L.wing(w, 4, 0.16, white, gold, 0.6, -0.15, 0.01)
		# feathers point outward-down along the arm, swept back
		var bs := Basis(Vector3.UP, 0.5 if side > 0 else PI - 0.5)
		b.attach(arm, w, Transform3D(bs, sh + Vector3(side * 0.08, 0.06, -0.02)))
		# white vambraces with gold flares, long gold-rimmed gauntlet cuffs
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.038, 0.044, 0.052, 0.06], 0.25, 1.0, white, gold, 14)
		# deep-sky thigh-high under-hose with a gold garter band (no bare thighs between skirt and greaves)
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var ll0 := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		ClassDress.limb_guard(b, ul, ll0, [0.078, 0.07, 0.062], 0.3, 1.0, sky_d, null, 14)
		ClassDress.limb_guard(b, ul, ll0, [0.08, 0.08], 0.3, 0.34, gold, null, 14)
		# thigh-high white sabatons/greaves with winged knee cops
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.062, 0.058, 0.048, 0.044], 0.0, 0.92, white, gold, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.045, -0.035), Vector2(0.045, -0.035), Vector2(0.05, 0.03), Vector2(0.0, 0.09), Vector2(-0.05, 0.03)]), 0.018, 0.005), white)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, 0.062)))
		var kw := Node3D.new()
		L.wing(kw, 3, 0.08, gold, gold, 0.5, 0.4, 0.008)
		b.attach(ll, kw, Transform3D(Basis(Vector3.UP, (-PI * 0.5 + 0.3) if side > 0 else (PI * 0.5 - 0.3) + PI), kp + Vector3(side * 0.055, 0.03, 0.02)))
	# --- armoured skirt: hooped white faulds (open at the front), gold rims, sky-blue front tabard + back tails
	for k in 2:
		var r0 := 0.19 + k * 0.035
		var yy := -0.02 - k * 0.07
		L.shell(b, "Hips", hips, [Vector2(r0 + 0.03, yy - 0.08), Vector2(r0, yy)], white, 0.86, TAU * 0.7, true)
		L.shell(b, "Hips", hips, [Vector2(r0 + 0.032, yy - 0.085), Vector2(r0 + 0.03, yy - 0.068)], gold, 0.86, TAU * 0.7, true)
	L.shell(b, "Hips", hips, [Vector2(0.16, 0.0), Vector2(0.162, 0.05)], sky_d, 0.84)
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.03, 0.036), 0.018, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.025, 0.14)))
	var cols := [["Hips", 0.2, -0.04], ["RightUpperLeg", 0.12, -0.15], ["LeftUpperLeg", 0.12, -0.15], ["RightLowerLeg", 0.09, -0.05], ["LeftLowerLeg", 0.09, -0.05]]
	var lining := AnimeGear.toon(Color("#F4F2EC"), {"shade": Color("#A9B3D6") / Color("#F4F2EC")})
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0, 0.0, 0.16)), {
		"name": "TabardFront", "length": 0.55, "segments": 8, "width": [0.15, 0.15, 0.12, 0.03], "dir": Vector3(0, -1.0, 0.15),
		"side": Vector3(1, 0, 0), "material": lining, "lining": sky, "thickness": 0.01, "stiffness": 0.06, "stiffness_tip": 0.01,
		"gravity": 9.0, "drag": 0.1, "colliders": cols})
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.08, -0.02, -0.15)), {
			"name": "Tail", "length": 0.9, "segments": 10, "width": [0.12, 0.15, 0.12, 0.03], "dir": Vector3(side * 0.15, -1.0, -0.25),
			"side": Vector3(1, 0, 0), "material": sky, "lining": lining, "thickness": 0.01, "stiffness": 0.04, "stiffness_tip": 0.006,
			"gravity": 8.0, "drag": 0.08, "wind": Vector3(side * 0.2, 0.0, -0.5), "colliders": cols})
	# --- the hero element: folded armoured wings on a back plate (white feathers, gold leading edge)
	var back := uc + Vector3(0, 0.03, -0.14)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.07, 0.1), 0.1, 0.008), white), Transform3D(Basis(), back + Vector3(0, 0, -0.04)))
	L.gem(b, "UpperChest", back + Vector3(0, 0.0, -0.1), Color("#7FC8FF"), 0.02, 1.4)
	var pale := AnimeGear.toon(Color("#DCE8F6"), {"shade": Color("#8A9AC8") / Color("#DCE8F6"), "rim": Color(1.0, 0.95, 0.85)})
	for side: float in [-1.0, 1.0]:
		var wn := Node3D.new()
		wn.name = "Wing"
		# gold leading edge sweeping up and out from the back plate
		var edge := PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.2, 0.14), Vector2(0.36, 0.3), Vector2(0.42, 0.31), Vector2(0.36, 0.24), Vector2(0.22, 0.08), Vector2(0.04, -0.06)])
		AnimeGear.mi(AnimeGear.extrude(edge, 0.024, 0.005), gold, wn)
		# primaries hanging from the edge: longer toward the tip, fanning from straight down to down-and-out
		for k in 7:
			var t := float(k) / 6.0
			var ln := lerpf(0.3, 0.72, t)
			var f := AnimeGear.mi(AnimeGear.extrude(L.feather(ln, ln * 0.17), 0.012, 0.003), white if k % 2 == 0 else pale, wn)
			f.transform = Transform3D(Basis(Vector3.BACK, lerpf(-1.72, -1.2, t)), Vector3(0.04 + 0.33 * t, 0.0 + 0.27 * t, -0.006 - t * 0.012))
		# coverts: short feathers over the roots
		for k in 4:
			var t := float(k) / 3.0
			var cf := AnimeGear.mi(AnimeGear.extrude(L.feather(0.16, 0.05), 0.014, 0.003), white, wn)
			cf.transform = Transform3D(Basis(Vector3.BACK, -1.3 + t * 0.2), Vector3(0.06 + 0.26 * t, 0.02 + 0.22 * t, 0.012))
		# the right wing is the left one turned half round (the pieces are flat); both swept back off the hair
		var bs := Basis(Vector3.UP, side * -0.5) * (Basis(Vector3.UP, PI) if side < 0 else Basis())
		b.attach("UpperChest", wn, Transform3D(bs, back + Vector3(side * 0.05, 0.02, -0.08)))
	# --- winged circlet: gold band across the brow with two small swept wings at the temples
	var hc := head + Vector3(0, 0.125, -0.005)
	L.shell(b, "Head", hc, [Vector2(0.118, -0.008), Vector2(0.12, 0.012)], gold, 1.05)
	L.gem(b, "Head", hc + Vector3(0, 0.005, 0.128), Color("#7FC8FF"), 0.012, 1.4)
	for side: float in [-1.0, 1.0]:
		var hw := Node3D.new()
		L.wing(hw, 3, 0.1, gold, white, 0.45, 0.35, 0.008)
		b.attach("Head", hw, Transform3D(Basis(Vector3.UP, (-0.35) if side > 0 else PI + 0.35), hc + Vector3(side * 0.118, 0.0, -0.02)))
