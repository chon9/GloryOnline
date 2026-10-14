extends RefCounted
## Launcher 枪炮师 (沐雨橙风 type), bible 2.5: yellow / orange / white blouse / brown leather, lace-up corset,
## goggles, oversized brass cannon (WeaponFactory "hand_cannon").
## The base's white one-piece is recoloured into a dark-orange under-dress and fully covered at the silhouette
## level: puffed-sleeve yellow jacket with a white ruff collar, leather corset, layered open-front overskirt with a
## long orange bustle, knee boots, gauntlets. (Lookdev gap: "the Launcher's white sundress".)

const Y := Color("#F2C230")
const O := Color("#F08A24")
const LEATHER := Color("#6B3E22")
const BRASS := Color("#B9944A")
const WHITE := Color("#F2F0EA")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_g",
		"height": 1.74,
		"proportions": [1.07, 0.95],
		"rim": Color(1.0, 0.9, 0.7),
		"dress": {
			"Onepice": {"map": [Color("#3A1A0C"), Color("#8A3E14"), Color("#D0782C")], "contrast": 1.3},
			"HAIR": {"map": [Color("#8A3A12"), Color("#E0782C"), Color("#FFD27A")], "contrast": 1.1, "line": 1.7},
			"Shoes": {"map": [Color("#1E1008"), Color("#5A3420"), Color("#B07A48")], "contrast": 1.2},
			"EyeIris": {"iris": Color(0.75, 0.9, 1.15)},
		},
		"anims": {&"idle": ["Idle_FoldArms"], &"attack": ["Pistol_Shoot"], &"shoot_2h": ["Pistol_Shoot"], &"cast": ["Two-hand Blast"]},
		"grips": {"hand_cannon": {"kind": "gun", "pitch": 0.0}},
	}


static func _mat_y() -> ShaderMaterial:
	return AnimeGear.toon(Y, {"shade": Color(0.78, 0.56, 0.6), "rim": ClassDress.GOLD_HI})


static func _mat_o() -> ShaderMaterial:
	return AnimeGear.toon(O, {"shade": Color(0.7, 0.45, 0.6), "rim": ClassDress.GOLD_HI})


static func build(b: AnimeBody) -> void:
	var leather := AnimeGear.toon(LEATHER)
	var brass := AnimeGear.toon(BRASS, {"shade": ClassDress.GOLD_SHADE / BRASS, "rim": ClassDress.GOLD_HI})
	var white := AnimeGear.toon(WHITE, {"shade": Color("#A9B3D6") / WHITE})
	var gold := AnimeGear.gold()
	var yellow := _mat_y()
	var orange := _mat_o()
	var hips := b.bone_pos("Hips")
	var head := b.bone_pos("Head")
	var neck := b.bone_pos("Neck")
	var uc := b.bone_pos("UpperChest")
	var knee := b.bone_pos("RightLowerLeg")
	# --- goggles pushed up on the forehead
	b.attach("Head", AnimeGear.mi(AnimeGear.lathe([Vector2(0.105, -0.018), Vector2(0.108, 0.018)], 24, 1.0, 1.12), leather), Transform3D(Basis(Vector3.RIGHT, -0.35), head + Vector3(0, 0.11, 0.0)))
	for side: float in [-1.0, 1.0]:
		var lens := Node3D.new()
		AnimeGear.mi(AnimeGear.cyl(0.032, 0.036, 0.03, 16), brass, lens, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		AnimeGear.mi(AnimeGear.cyl(0.026, 0.026, 0.032, 16), AnimeGear.toon(Color("#FF9A3C"), {"emit": Color(0.9, 0.45, 0.1) * 0.6, "outline": false}), lens, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.002)))
		b.attach("Head", lens, Transform3D(Basis(Vector3.RIGHT, -0.5), head + Vector3(side * 0.045, 0.165, 0.085)))
	# --- cropped yellow jacket: torso shell + puffed shoulders + white ruff collar
	var jy := uc.y
	var jacket := AnimeGear.mi(AnimeGear.lathe([Vector2(0.15, jy - 0.07), Vector2(0.152, jy - 0.03), Vector2(0.15, jy + 0.03), Vector2(0.135, jy + 0.09), Vector2(0.09, jy + 0.13)], 24, 1.0, 0.82, TAU * 0.84), yellow)
	jacket.rotation.y = PI * 0.5 + TAU * 0.08
	b.attach("UpperChest", ClassDress.wrap(jacket), Transform3D(Basis(), Vector3(0, 0, 0.0)))
	var jtrim := AnimeGear.mi(AnimeGear.lathe([Vector2(0.152, jy - 0.085), Vector2(0.152, jy - 0.06)], 24, 1.0, 0.82, TAU * 0.84), orange)
	jtrim.rotation.y = jacket.rotation.y
	b.attach("UpperChest", ClassDress.wrap(jtrim), Transform3D.IDENTITY)
	for side: float in [-1.0, 1.0]:
		var arm := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var sh := b.bone_pos(arm)
		var el := b.bone_pos("RightLowerArm" if side < 0 else "LeftLowerArm")
		var dir := (el - sh).normalized()
		var bs := Basis(Quaternion(Vector3.UP, dir))
		var puff := AnimeGear.mi(AnimeGear.lathe([Vector2(0.05, -0.02), Vector2(0.075, 0.03), Vector2(0.078, 0.09), Vector2(0.06, 0.14), Vector2(0.045, 0.16)], 14), yellow)
		b.attach(arm, puff, Transform3D(bs, sh))
		b.attach(arm, AnimeGear.mi(AnimeGear.lathe([Vector2(0.047, 0.15), Vector2(0.05, 0.175)], 14), white), Transform3D(bs, sh))
	var ruff := AnimeGear.mi(AnimeGear.lathe([Vector2(0.06, -0.03), Vector2(0.085, 0.01), Vector2(0.11, 0.04), Vector2(0.115, 0.05)], 20), white)
	b.attach("UpperChest", ruff, Transform3D(Basis(), neck + Vector3(0, -0.03, 0.0)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.022, 0.03), 0.02, 0.004), AnimeGear.toon(O, {"emit": O * 0.3})), Transform3D(Basis(), neck + Vector3(0, -0.05, 0.09)))
	# --- leather lace-up corset over the waist, gold lacing
	var cy := hips.y + 0.02
	b.attach("Spine", AnimeGear.mi(AnimeGear.lathe([Vector2(0.16, cy - 0.03), Vector2(0.148, cy + 0.08), Vector2(0.142, cy + 0.15), Vector2(0.152, cy + 0.2)], 24, 1.0, 0.8), leather), Transform3D(Basis(), Vector3(0, 0, 0.005)))
	b.attach("Spine", AnimeGear.mi(AnimeGear.lathe([Vector2(0.153, cy + 0.195), Vector2(0.156, cy + 0.212)], 24, 1.0, 0.8), gold), Transform3D(Basis(), Vector3(0, 0, 0.005)))
	var lace: Array = []
	var lw: Array = []
	var ls: Array = []
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(cy + 0.02, cy + 0.18, t)
		var r := 0.142 + absf(t - 0.45) * 0.03
		lace.append(Vector3((0.02 if i % 2 == 0 else -0.02), y, r * 0.8 + 0.012))
		lw.append(0.008)
		ls.append(Vector3(1, 0, 0))
	b.attach("Spine", AnimeGear.mi(AnimeGear.ribbon(lace, lw, ls, 0.004), AnimeGear.toon(ClassDress.GOLD_HI)), Transform3D.IDENTITY)
	# --- belt with pouches + bandolier
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.152, -0.02), Vector2(0.157, 0.025)], 24, 1.0, 0.8), leather), Transform3D(Basis(), hips + Vector3(0, -0.02, 0.0)))
	for k in 3:
		var a := deg_to_rad(-60.0 + k * 45.0) + PI * 0.5
		b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.06, 0.07, 0.04)), leather), Transform3D(Basis(Vector3.UP, a), hips + Vector3(cos(a) * 0.17, -0.05, -sin(a) * 0.14)))
	var band: Array = []
	var bw: Array = []
	var bs2: Array = []
	for i in 9:
		var t := float(i) / 8.0
		band.append(Vector3(lerpf(0.14, -0.13, t), lerpf(uc.y + 0.12, hips.y + 0.05, t), 0.115 * sin(t * PI) + 0.02))
		bw.append(0.04)
		bs2.append(Vector3(0, 1, 0.2))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon(band, bw, bs2, 0.012), leather), Transform3D.IDENTITY)
	for i in 4:
		var p: Vector3 = band[2 + i]
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.cyl(0.012, 0.012, 0.05, 8), brass), Transform3D(Basis(Vector3.FORWARD, 0.8), p + Vector3(0, 0, 0.02)))
	# --- layered overskirt: yellow open-front bell above the knee, orange under-layer, gold hem
	var sk_top := hips.y - 0.02
	var sk_bot := lerpf(hips.y, knee.y, 0.72)
	var under := AnimeGear.mi(AnimeGear.lathe([Vector2(0.3, sk_bot - 0.06 - hips.y), Vector2(0.22, (sk_top + sk_bot) * 0.5 - hips.y), Vector2(0.16, sk_top - hips.y)], 28, 1.0, 0.85), white)
	b.attach("Hips", under, Transform3D(Basis(), hips))
	var over := AnimeGear.mi(AnimeGear.lathe([Vector2(0.33, sk_bot - hips.y + 0.03), Vector2(0.26, (sk_top + sk_bot) * 0.5 - hips.y + 0.02), Vector2(0.17, sk_top - hips.y + 0.02)], 28, 1.0, 0.88, TAU * 0.7), orange)
	over.rotation.y = PI * 0.5 + TAU * 0.15
	b.attach("Hips", ClassDress.wrap(over), Transform3D(Basis(), hips))
	var ohem := AnimeGear.mi(AnimeGear.lathe([Vector2(0.335, sk_bot - hips.y + 0.02), Vector2(0.325, sk_bot - hips.y + 0.055)], 28, 1.0, 0.88, TAU * 0.7), yellow)
	ohem.rotation.y = over.rotation.y
	b.attach("Hips", ClassDress.wrap(ohem), Transform3D(Basis(), hips))
	# long orange bustle tails (secondary motion via cloth sim) with a yellow hem
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(side * 0.08, 0.0, -0.15)), {
			"name": "Bustle", "length": 0.62, "segments": 8, "width": [0.18, 0.24, 0.27], "dir": Vector3(side * 0.12, -1.0, -0.35),
			"side": Vector3(1, 0, 0), "material": orange, "stiffness": 0.2, "stiffness_tip": 0.05, "gravity": 8.0, "drag": 0.1,
			"colliders": [["Hips", 0.17, -0.05], ["RightUpperLeg", 0.1, -0.2], ["LeftUpperLeg", 0.1, -0.2]]})
	# --- knee boots with a flared gold cuff + thigh straps
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var kp := b.bone_pos(ll)
		var fp := b.bone_pos("RightFoot" if side < 0 else "LeftFoot")
		b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.05, fp.y - 0.02), Vector2(0.055, fp.y + 0.08), Vector2(0.066, lerpf(fp.y, kp.y, 0.6)), Vector2(0.07, kp.y - 0.05), Vector2(0.085, kp.y + 0.01)], 14), leather), Transform3D(Basis(), Vector3(kp.x, 0, kp.z + 0.005)))
		b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.086, kp.y), Vector2(0.09, kp.y + 0.025)], 14), gold), Transform3D(Basis(), Vector3(kp.x, 0, kp.z + 0.005)))
		var up := b.bone_pos(ul)
		var t := 0.62
		var sp := up.lerp(kp, t)
		b.attach(ul, AnimeGear.mi(AnimeGear.lathe([Vector2(0.074, -0.015), Vector2(0.076, 0.015)], 14), leather), Transform3D(Basis(), sp))
		b.attach(ul, AnimeGear.mi(AnimeGear.box(Vector3(0.03, 0.03, 0.012)), brass), Transform3D(Basis(), sp + Vector3(side * 0.03, 0, 0.072)))
	# --- leather gauntlets
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.036, 0.042, 0.05], 0.45, 1.0, leather, gold, 12)
	# --- brass shoulder plate on the cannon arm
	var sh := b.bone_pos("RightUpperArm")
	b.attach("RightUpperArm", AnimeGear.mi(AnimeGear.lathe([Vector2(0.0, 0.07), Vector2(0.06, 0.06), Vector2(0.095, 0.03), Vector2(0.1, -0.02)], 16, 1.0, 1.2), brass), Transform3D(Basis(Vector3.FORWARD, deg_to_rad(38.0)), sh + Vector3(-0.04, 0.05, 0)))
