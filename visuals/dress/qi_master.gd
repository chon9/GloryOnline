extends RefCounted
## Qi Master 气功师, bible 2.5: white / sky blue #7FC4FF with silver trim. Hanfu-inspired fighter: white cross-collar
## robe with sky-blue lapels and cloud trim, wide sky-blue waist sash with a jade disc and tassel, split robe skirt
## over wrapped leggings. Hero silhouette: wide flowing sleeve drapes on both forearms plus a long 披帛 shawl
## trailing from the shoulders (all runtime cloth) and floating qi orbs. Qi gloves are built on the hand bones
## (wraps, silver knuckles); the glowing qi spheres at the fists are the WeaponFactory "gloves_qi" accents in the team
## tint (grip `accent_only` keeps only its emissive parts).

const L := preload("res://visuals/dress/_gunfight_lib.gd")
const SKY := Color("#7FC4FF")
const WHITE := Color("#F4F8FF")
const NAVY := Color("#1E2A4A")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_g",
		"height": 1.72,
		"proportions": [1.07, 0.95],
		# the one-piece's frilled skirt would poke through the robe skirt and its front slit: cull it below the sash
		"cull": [{"mat": "Onepice", "bone": "Hips", "min": Vector3(-0.6, -0.7, -0.5), "max": Vector3(0.6, -0.03, 0.5)}],
		"rim": Color(0.8, 0.92, 1.0),
		"dress": {
			# one-piece -> white silk with sky shadows; shoes -> sky cloth shoes; long hair -> indigo black, blue sheen
			"Onepice": {"map": [Color("#6A8EC0"), Color("#DCE8F6"), Color("#FFFFFF")], "contrast": 1.2},
			"Shoes": {"map": [Color("#142038"), Color("#3E6EA8"), Color("#CFE4F8")], "contrast": 1.2},
			"HAIR": {"map": [Color("#030409"), Color("#0A0F22"), Color("#1C2646")], "contrast": 1.1, "line": 1.7, "shade": Color(0.6, 0.62, 0.9)},
			"EyeIris": {"iris": Color(0.7, 0.9, 1.25)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Punch_Jab"], &"cast": ["Two-hand Blast"]},
		"grips": {"gloves_qi": {"kind": "fist", "accent_only": true}},
	}


static func cloud(s := 1.0) -> PackedVector2Array:
	# a three-lobed 祥云 cloud with a curled tail (original motif)
	var p := PackedVector2Array()
	for k in 3:
		var cx := (k - 1) * 0.028
		var cy := 0.012 if k == 1 else 0.0
		var r := 0.02 if k == 1 else 0.016
		for i in 7:
			var a := PI - PI * i / 6.0
			p.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	p.append(Vector2(0.05, -0.012))
	p.append(Vector2(0.03, -0.006))
	p.append(Vector2(-0.03, -0.006))
	p.append(Vector2(-0.05, -0.012))
	for i in p.size():
		p[i] *= s
	return p


static func build(b: AnimeBody) -> void:
	var white := AnimeGear.toon(WHITE, {"shade": Color("#8AA2D8") / WHITE, "rim": Color.WHITE, "rim_strength": 0.7})
	var sky := AnimeGear.toon(SKY, {"shade": Color("#3C6CC0") / SKY, "rim": Color(0.85, 0.95, 1.0)})
	var navy := AnimeGear.toon(NAVY, {"shade": Color(0.6, 0.6, 0.9)})
	var silver := AnimeGear.toon(ClassDress.SILVER, {"shade": Color("#7C88A0") / ClassDress.SILVER, "rim": Color.WHITE, "rim_strength": 0.9})
	var jade := AnimeGear.toon(Color("#9FE8D0"), {"emit": Color("#4FD8B0") * 0.5, "rim": Color.WHITE})
	var qi_core := AnimeGear.glow(Color("#E8F6FF"), 3.0)
	var qi_halo := AnimeGear.glow(Color("#4FA8FF"), 2.2, true, 0.55)
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- white cross-collar robe bodice, sky lapel crossing right-over-left, silver edge, cloud badge
	var yb := hips.y + 0.05 - uc.y
	var bod := [Vector2(0.142, yb), Vector2(0.146, yb + 0.08), Vector2(0.158, -0.03), Vector2(0.162, 0.04), Vector2(0.146, 0.1), Vector2(0.09, 0.13)]
	L.shell(b, "UpperChest", bod, uc, white, 0.0, 1.0, 0.86)
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		var ws: Array = []
		var ss: Array = []
		for i in 9:
			var t := float(i) / 8.0
			var y := lerpf(0.12, yb + 0.06, t)
			var x := lerpf(side * 0.055, -side * 0.07, t)
			var r := lerpf(0.09, 0.15, minf(t * 2.2, 1.0))
			var z := sqrt(maxf(r * r - x * x, 0.0)) * 0.86 + 0.014 + (0.004 if side > 0 else 0.0)
			pts.append(uc + Vector3(x, y, z))
			ws.append(0.042)
			ss.append(Vector3(1.0, side * 0.8, 0.0).normalized())
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon(pts, ws, ss, 0.008 if side < 0 else 0.012), sky if side > 0 else silver), Transform3D.IDENTITY)
	L.mandarin_collar(b, white, sky, 0.068, 0.055)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(cloud(1.2), 0.01, 0.002), silver), Transform3D(Basis(Vector3.RIGHT, -0.15), uc + Vector3(0.07, 0.03, 0.14)))
	# --- shoulders: a small layered silver cloud guard on the left only
	ClassDress.pauldron(b, 1.0, white, silver, 0.85, 2, false)
	var shl := b.bone_pos("LeftUpperArm")
	b.attach("LeftUpperArm", AnimeGear.mi(AnimeGear.extrude(cloud(1.3), 0.012, 0.002), sky), Transform3D(Basis(Vector3.UP, PI / 2), shl + Vector3(0.1, 0.035, 0.0)))
	# --- wide sky waist sash, navy cord, jade disc + tassel cord
	L.shell(b, "Hips", [Vector2(0.148, 0.03), Vector2(0.152, 0.075), Vector2(0.15, 0.12)], hips, navy, 0.0, 1.0, 0.84)
	L.ring(b, "Hips", hips + Vector3(0, 0.035, 0), 0.151, 0.01, silver, 0.84)
	L.ring(b, "Hips", hips + Vector3(0, 0.115, 0), 0.152, 0.01, silver, 0.84)
	L.ring(b, "Hips", hips + Vector3(0, 0.075, 0), 0.155, 0.014, sky, 0.84)
	for k in 3:
		var a := PI * 0.5 + (k - 1) * 0.5
		b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(cloud(0.6), 0.008), silver), Transform3D(Basis(Vector3.UP, a - PI * 0.5), hips + Vector3(cos(a) * 0.152, 0.1, sin(a) * 0.13)))
	var disc := Node3D.new()
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.012, -0.005), Vector2(0.032, -0.005), Vector2(0.034, 0.0), Vector2(0.032, 0.005), Vector2(0.012, 0.005)], 18), jade, disc, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	b.attach("Hips", disc, Transform3D(Basis(Vector3.UP, 0.4), hips + Vector3(0.1, -0.01, 0.13)))
	var cols := [["Hips", 0.17, -0.04], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.075, -0.12], ["LeftLowerLeg", 0.075, -0.12]]
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0.1, -0.045, 0.13)), {
		"name": "JadeTassel", "length": 0.36, "segments": 6, "width": [0.012, 0.012, 0.012, 0.03, 0.045],
		"dir": Vector3(0.05, -1, 0.1), "side": Vector3(1, 0, 0), "material": navy, "thickness": 0.012,
		"stiffness": 0.05, "stiffness_tip": 0.01, "gravity": 9.0, "drag": 0.08, "colliders": cols})
	# --- split robe skirt to mid-calf (front slit), sky hem with silver line; front 蔽膝 panel (cloth)
	var knee := b.bone_pos("RightLowerLeg")
	var sk_bot := knee.y - 0.17 - hips.y
	var skirt := [Vector2(0.35, sk_bot), Vector2(0.315, -0.3), Vector2(0.285, -0.16), Vector2(0.25, -0.07), Vector2(0.2, -0.0), Vector2(0.152, 0.035)]
	L.shell(b, "Hips", skirt, hips, sky, 0.13, 1.0, 0.9, 28)
	L.shell(b, "Hips", [Vector2(0.352, sk_bot - 0.004), Vector2(0.346, sk_bot + 0.045)], hips, white, 0.13, 1.0, 0.9, 28)
	L.shell(b, "Hips", [Vector2(0.344, sk_bot + 0.05), Vector2(0.342, sk_bot + 0.06)], hips, navy, 0.13, 1.0, 0.9, 28)
	for side: float in [-1.0, 1.0]:
		L.shell_edge(b, "Hips", skirt, hips, 0.13, 1.0, 0.9, side, 0.03, white, 0.006)
	ClassDress.cloth(b, "Hips", Transform3D(Basis(), hips + Vector3(0.0, 0.03, 0.135)), {
		"name": "FrontPanel", "length": 0.62, "segments": 8, "width": [0.13, 0.14, 0.15, 0.16, 0.12],
		"dir": Vector3(0, -1, 0.12), "side": Vector3(1, 0, 0), "material": navy, "lining": sky, "lining_side": Vector3(0, 0, -1),
		"thickness": 0.012, "stiffness": 0.05, "stiffness_tip": 0.01, "gravity": 9.0, "drag": 0.08, "colliders": cols})
	# --- wrapped leggings with sky criss-cross bindings
	for side: float in [-1.0, 1.0]:
		var ll := L.arm(side) + "LowerLeg"
		var ft := L.arm(side) + "Foot"
		ClassDress.limb_guard(b, ll, ft, [0.056, 0.054, 0.046, 0.044], -0.05, 0.92, white, null, 14)
		var p0 := b.bone_pos(ll)
		var p1 := b.bone_pos(ft)
		for k in 3:
			var p := p0.lerp(p1, 0.35 + k * 0.2)
			b.attach(ll, AnimeGear.mi(AnimeGear.lathe([Vector2(0.056 - k * 0.003, -0.008), Vector2(0.058 - k * 0.003, 0.008)], 12), sky), Transform3D(Basis(Vector3.RIGHT, 0.25 * (1 if k % 2 == 0 else -1)), p))
	# --- qi gloves: white wraps, silver knuckles (the qi spheres at the fists come from the gloves_qi weapon)
	for side: float in [-1.0, 1.0]:
		L.gauntlet(b, side, white, silver, {"radii": [0.046, 0.044, 0.042, 0.041], "t0": 0.45, "fin": false, "studs": false, "glow": SKY})
	# --- wide hanfu sleeves: a tube from the shoulder that widens and droops toward an open cuff past the elbow
	for side: float in [-1.0, 1.0]:
		var ua := L.arm(side) + "UpperArm"
		var la := L.arm(side) + "LowerArm"
		var sh := b.bone_pos(ua)
		var e := b.bone_pos(la)
		var w := b.bone_pos(L.arm(side) + "Hand")
		var up_pts: Array = []
		var up_r: Array = []
		for i in 5:
			var t := float(i) / 4.0
			up_pts.append(sh.lerp(e, t) + Vector3(0, -t * 0.012, 0))
			up_r.append(lerpf(0.062, 0.07, t))
		b.attach(ua, AnimeGear.mi(AnimeGear.tube(up_pts, up_r, 14), white), Transform3D.IDENTITY)
		var lo_pts: Array = []
		var lo_r: Array = []
		for i in 7:
			var t := float(i) / 6.0
			lo_pts.append(e.lerp(w, t * 0.92) + Vector3(0, -0.012 - t * t * 0.07, -t * 0.01))
			lo_r.append(lerpf(0.07, 0.135, t * t))
		b.attach(la, AnimeGear.mi(AnimeGear.tube(lo_pts, lo_r, 16), white), Transform3D.IDENTITY)
		# sky lining visible inside the cuff + silver rim
		var cdir := ((lo_pts[6] as Vector3) - (lo_pts[5] as Vector3)).normalized()
		var cb := Basis(Quaternion(Vector3.UP, cdir))
		b.attach(la, AnimeGear.mi(AnimeGear.lathe([Vector2(0.128, -0.03), Vector2(0.13, 0.0)], 16), sky), Transform3D(cb, lo_pts[6]))
		b.attach(la, AnimeGear.mi(AnimeGear.lathe([Vector2(0.136, -0.006), Vector2(0.137, 0.006)], 16), silver), Transform3D(cb, lo_pts[6]))
		# short cuff streamer for motion
		ClassDress.cloth(b, la, Transform3D(Basis(), (lo_pts[6] as Vector3) + Vector3(0, -0.11, 0)), {
			"name": "SleeveTail", "length": 0.32, "segments": 6, "width": [0.12, 0.13, 0.12, 0.05],
			"dir": Vector3(0, -1.0, -0.2), "side": cdir, "material": white, "lining": sky, "thickness": 0.01,
			"stiffness": 0.02, "stiffness_tip": 0.004, "gravity": 9.0, "drag": 0.08})
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(side * 0.13, 0.1, -0.11)), {
			"name": "Pibo", "length": 1.1 if side > 0 else 0.92, "segments": 13, "width": [0.07, 0.11, 0.13, 0.13, 0.12, 0.1, 0.06],
			"dir": Vector3(side * 0.15, -1.0, -0.3), "side": Vector3(1, 0, 0.3 * side), "material": sky, "thickness": 0.01,
			"stiffness": 0.015, "stiffness_tip": 0.002, "gravity": 8.0, "drag": 0.06, "wind": Vector3(side * 0.2, 0.0, -0.4),
			"colliders": [["UpperChest", 0.16, 0.0], ["Hips", 0.2, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15]]})
	# --- floating qi orbs around the body
	for o: Vector3 in [Vector3(-0.34, -0.12, -0.1), Vector3(0.32, -0.02, -0.14), Vector3(0.05, 0.32, -0.26)]:
		var q := Node3D.new()
		AnimeGear.mi(AnimeGear.sphere(0.024, 10), qi_core, q)
		AnimeGear.mi(AnimeGear.sphere(0.055, 12), qi_halo, q)
		AnimeGear.mi(AnimeGear.lathe([Vector2(0.07, -0.003), Vector2(0.07, 0.003)], 20), AnimeGear.glow(SKY, 2.0), q, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3.ZERO))
		b.attach("UpperChest", q, Transform3D(Basis(), uc + o))
	# --- silver hairpin with a sky tassel
	var pin := Node3D.new()
	AnimeGear.mi(AnimeGear.cyl(0.005, 0.007, 0.2, 6), silver, pin, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO))
	AnimeGear.mi(AnimeGear.extrude(cloud(0.8), 0.012, 0.002), silver, pin, Transform3D(Basis(), Vector3(0.1, 0.0, 0.0)))
	AnimeGear.mi(AnimeGear.sphere(0.012, 8), jade, pin, Transform3D(Basis(), Vector3(0.1, 0.0, 0.008)))
	b.attach("Head", pin, Transform3D(Basis(Vector3.BACK, 0.35), head + Vector3(0.02, 0.17, -0.09)))
