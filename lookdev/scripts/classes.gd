class_name LdClasses
extends RefCounted
## Class "dress" definitions for the slice: base model, per-material recolour, costume + weapon builders,
## animation clips. Costume pieces are authored in CHARACTER SPACE at the rest (T) pose: metres, +Y up,
## character faces +Z, its right hand is at -X. LdCharacter.attach() converts to bone space.
## Palette tokens come from the Art Bible v1 (section 2.5 / 8).

const GOLD := Color("#D8B25A")
const GOLD_HI := Color("#FFE9A8")
const NAVY := Color("#1E2440")
const BLACK_COAT := Color("#16161C")
const RED_GEM := Color("#D2283A")
const SILVER := Color("#C9D3DE")
const WITCH_BLUE := Color("#23379A")
const LAUNCHER_Y := Color("#F2C230")
const LAUNCHER_O := Color("#F08A24")
const LEATHER := Color("#6B3E22")
const BRASS := Color("#B9944A")
static var gun_pitch := 0.0   # debug override (--gunpitch=deg)

## grip: T-pose model-space transform of the right-hand grip point, shaft along local +Y -> model +Z (fist axis)
static func grip_xf(c: LdCharacter, tilt_deg := 0.0, roll_deg := 0.0) -> Transform3D:
	var h := c.bone_pos("RightHand")
	var b := Basis(Vector3.RIGHT, PI / 2.0)                     # local +Y -> +Z (forward)
	b = Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)) * b         # tilt the shaft up
	b = Basis(Vector3.FORWARD, deg_to_rad(roll_deg)) * b
	return Transform3D(b, h + Vector3(-0.075, -0.03, 0.0))


## firearm grip: barrel along the forearm / knuckle direction (hand bone +Y), "up over the fist" = model +Y
static func gun_xf(c: LdCharacter, pitch_deg := 0.0) -> Transform3D:
	var h := c.bone_pos("RightHand")
	var b := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	b = Basis(Vector3(0, 0, 1), deg_to_rad(pitch_deg)) * b
	return Transform3D(b, h + Vector3(-0.06, -0.035, 0.0))


# =====================================================================  BATTLE MAGE  (一叶之秋 type)

static func battle_mage() -> Dictionary:
	return {
		"id": "battle_mage", "name": "BattleMage", "model": "res://lookdev/assets/chars/vroid_sakurada.glb",
		"idle": "Fighting Idle", "skill": "Sword_Regular_C", "skill_t": 0.55, "portrait": "Fighting Idle", "cast": "Power Up",
		"rim": Color(1.0, 0.88, 0.66),
		"dress": {
			# school vest + shirt -> black battle coat over a cream shirt; tie -> crimson; orange/violet hair -> blue-black
			"Tops": {"map": [Color("#07070B"), Color("#262632"), Color("#ECE6D6")], "contrast": 1.25},
			"Accessory": {"map": [Color("#3A0A10"), Color("#C8202A"), Color("#FF8A70")], "contrast": 1.1},
			"Bottoms": {"map": [Color("#09090E"), Color("#1C1C28"), Color("#4A4A60")], "contrast": 1.3},
			"Shoes": {"map": [Color("#120C08"), Color("#3B2416"), Color("#9A7440")], "contrast": 1.2},
			"HAIR": {"map": [Color("#0B090A"), Color("#211A1C"), Color("#584A4C")], "contrast": 1.0, "line": 1.7, "shade": Color(0.55, 0.5, 0.7)},
			"EyeIris": {"iris": Color(0.78, 0.62, 0.55)},
		},
		"build": func(c: LdCharacter) -> void: _bm_build(c),
	}


static func _bm_build(c: LdCharacter) -> void:
	_proportions(c, 1.06, 0.95)
	var coat := LdGear.toon(BLACK_COAT, {"shade": Color(0.55, 0.55, 0.85)})
	var gold := LdGear.toon(GOLD, {"shade": Color("#8A5A2B") / GOLD, "rim": GOLD_HI})
	var hips := c.bone_pos("Hips")
	# --- long coat split at the hips: 2 back panels on Hips, 2 front-side panels on the upper legs
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		_coat_panel(c, "Hips", side, hips, true, coat, gold)
		_coat_panel(c, leg, side, hips, false, coat, gold)
	# --- armoured high collar
	var neck := c.bone_pos("Neck")
	var collar := LdGear.mi(LdGear.lathe([Vector2(0.085, -0.06), Vector2(0.095, 0.0), Vector2(0.115, 0.07), Vector2(0.14, 0.12)], 20, 1.0, 1.0, TAU * 0.78), coat)
	collar.rotation.y = -PI * 0.5 - TAU * 0.39 + PI   # gap at the front
	c.attach("UpperChest", _wrap(collar), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	var collar_rim := LdGear.mi(LdGear.lathe([Vector2(0.138, 0.115), Vector2(0.15, 0.13)], 20, 1.0, 1.0, TAU * 0.78), gold)
	collar_rim.rotation.y = collar.rotation.y
	c.attach("UpperChest", _wrap(collar_rim), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.005)))
	# --- pauldrons: two faceted swept plates with gold edges + a swept-back gold fin (asymmetric, bigger on the lance arm)
	for side: float in [-1.0, 1.0]:
		var arm := "RightUpperArm" if side < 0 else "LeftUpperArm"
		var sh := c.bone_pos(arm)
		var big := 1.12 if side < 0 else 0.95
		for k in 2:
			var r := (0.085 - k * 0.012) * big
			var prof := [Vector2(0.0, r * 0.62), Vector2(r * 0.62, r * 0.55), Vector2(r * 0.95, r * 0.18), Vector2(r * 1.02, -r * 0.22)]
			var b := Basis(Vector3.FORWARD, side * deg_to_rad(-30.0 - k * 14.0))
			var at := sh + Vector3(side * (0.035 + k * 0.05), 0.035 - k * 0.035, -0.005)
			c.attach(arm, LdGear.mi(LdGear.lathe(prof, 7, 1.0, 1.3), coat), Transform3D(b, at))
			c.attach(arm, LdGear.mi(LdGear.lathe([Vector2(r * 1.02, -r * 0.24), Vector2(r * 1.08, -r * 0.1)], 7, 1.0, 1.3), gold), Transform3D(b, at))
		var fin := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.012), Vector2(0.13, 0.07), Vector2(0.045, -0.005), Vector2(0.012, -0.03)]), 0.01, 0.0), gold)
		c.attach(arm, fin, Transform3D(Basis(Vector3.UP, side * -PI * 0.5 + PI) * Basis(Vector3.FORWARD, 0.25), sh + Vector3(side * 0.06, 0.085 * big, -0.05)))
	# --- forearm guards (gold edged)
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var p := c.bone_pos(la)
		var g := LdGear.mi(LdGear.lathe([Vector2(0.042, 0.0), Vector2(0.05, 0.08), Vector2(0.058, 0.16), Vector2(0.066, 0.2)], 14), coat)
		c.attach(la, g, Transform3D(Basis(Vector3.FORWARD, side * PI * 0.5), p + Vector3(side * 0.06, 0, 0)))
		var gr := LdGear.mi(LdGear.lathe([Vector2(0.066, 0.2), Vector2(0.07, 0.215)], 14), gold)
		c.attach(la, gr, Transform3D(Basis(Vector3.FORWARD, side * PI * 0.5), p + Vector3(side * 0.06, 0, 0)))
	# --- belt with gold buckle and red gem
	var belt := LdGear.mi(LdGear.lathe([Vector2(0.155, -0.025), Vector2(0.16, 0.025)], 24, 1.0, 0.82), LdGear.toon(LEATHER))
	c.attach("Hips", belt, Transform3D(Basis(), hips + Vector3(0, 0.02, 0.0)))
	var buckle := LdGear.mi(LdGear.extrude(_diamond(0.045, 0.05), 0.02, 0.004), gold)
	c.attach("Hips", buckle, Transform3D(Basis(), hips + Vector3(0, 0.02, 0.13)))
	var gem := LdGear.mi(LdGear.sphere(0.018, 12), LdGear.toon(RED_GEM, {"emit": RED_GEM * 0.6, "outline": false}))
	c.attach("Hips", gem, Transform3D(Basis(), hips + Vector3(0, 0.02, 0.145)))
	# --- chest filigree crest
	var crest := LdGear.mi(LdGear.extrude(_wing_crest(), 0.01, 0.002), gold)
	var uc := c.bone_pos("UpperChest")
	c.attach("UpperChest", crest, Transform3D(Basis(), uc + Vector3(0, 0.02, 0.118)))
	# --- weapon: Que Xie battle lance
	var lance := LdWeapons.que_xie()
	c.attach("RightHand", lance, grip_xf(c, 0.0))
	c.enable_two_hand(lance)
	c.set_meta("weapon", lance)


static func _coat_panel(c: LdCharacter, bone: String, side: float, hips: Vector3, back: bool, coat: Material, gold: Material) -> void:
	var pts: Array = []
	var w: Array = []
	var sides: Array = []
	var trim: Array = []
	var top := hips.y + 0.03
	var bottom := 0.30
	var steps := 7
	for i in steps:
		var t := float(i) / (steps - 1)
		var y := lerpf(top, bottom, t)
		var flare := 1.0 + t * 0.55
		var ang := deg_to_rad(155.0 if back else 55.0)       # around the waist, from +Z (front)
		var rad := 0.165 * flare
		var x := side * sin(ang) * rad
		var z := cos(ang) * rad * 0.85 - (t * t * 0.08 if back else 0.0)
		pts.append(Vector3(x, y, z))
		w.append(lerpf(0.22, 0.34, t) if back else lerpf(0.18, 0.27, t))
		sides.append(Vector3(cos(ang) * side, 0, -sin(ang)))
	var mesh := LdGear.ribbon(pts, w, sides, 0.014)
	c.attach(bone, LdGear.mi(mesh, coat), Transform3D.IDENTITY)
	# gold hem
	var hp: Array = []
	var hw: Array = []
	var hs: Array = []
	var p_last: Vector3 = pts[steps - 1]
	var s_last: Vector3 = sides[steps - 1]
	var half: float = float(w[steps - 1]) * 0.5
	for i in 5:
		var t := float(i) / 4.0
		hp.append(p_last + s_last * lerpf(-half, half, t) + Vector3(0, 0.01, 0))
		hw.append(0.035)
		hs.append(Vector3.UP)
	var hem := LdGear.ribbon(hp, hw, hs, 0.02)
	c.attach(bone, LdGear.mi(hem, gold), Transform3D.IDENTITY)


static func _diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)])


static func _wing_crest() -> PackedVector2Array:
	# a small V of swept wing blades (original design, not the show's crest)
	var p := PackedVector2Array()
	p.append(Vector2(0, -0.05))
	p.append(Vector2(0.03, -0.01))
	p.append(Vector2(0.11, 0.035))
	p.append(Vector2(0.06, 0.005))
	p.append(Vector2(0.09, 0.045))
	p.append(Vector2(0.03, 0.02))
	p.append(Vector2(0, 0.06))
	p.append(Vector2(-0.03, 0.02))
	p.append(Vector2(-0.09, 0.045))
	p.append(Vector2(-0.06, 0.005))
	p.append(Vector2(-0.11, 0.035))
	p.append(Vector2(-0.03, -0.01))
	return p


static func _wrap(n: Node3D) -> Node3D:
	var w := Node3D.new()
	w.add_child(n)
	return w


## Taller anime proportions (bible 2.1): longer legs, slightly smaller head. Animation clips only carry
## rotations (+ hips translation), so the pose scale set here survives playback.
static func _proportions(c: LdCharacter, leg := 1.06, head := 0.95) -> void:
	var sk := c.skeleton
	for b in ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
		sk.set_bone_pose_scale(sk.find_bone(b), Vector3(1.0, leg, 1.0))
	sk.set_bone_pose_scale(sk.find_bone("Head"), Vector3.ONE * head)
	var leg_len := c.bone_pos("RightUpperLeg").y - c.bone_pos("RightFoot").y
	c.model.position.y = leg_len * (leg - 1.0)
	c.set_meta("leg_scale", leg)


# =====================================================================  LAUNCHER  (沐雨橙风 type)

static func launcher() -> Dictionary:
	return {
		"id": "launcher", "name": "Launcher", "model": "res://lookdev/assets/chars/vroid_avatarsample_g.glb",
		"idle": "Pistol_Idle", "skill": "Pistol_Shoot", "skill_t": 0.1, "cast": "Two-hand Blast",
		"rim": Color(1.0, 0.9, 0.7),
		"dress": {
			# stock sundress -> white blouse + cream underskirt; the costume pieces below supply corset, capelet, bustle
			"Onepice": {"map": [Color("#7A7E98"), Color("#E6E2DA"), Color("#FFFFFF")], "contrast": 1.2},
			"HAIR": {"map": [Color("#8A3A12"), Color("#E0782C"), Color("#FFD27A")], "contrast": 1.1, "line": 1.7},
			"Shoes": {"map": [Color("#1E1008"), Color("#5A3420"), Color("#B07A48")], "contrast": 1.2},
			"EyeIris": {"iris": Color(0.75, 0.9, 1.15)},
		},
		"build": func(c: LdCharacter) -> void: _la_build(c),
	}


static func _la_build(c: LdCharacter) -> void:
	_proportions(c, 1.07, 0.95)
	var leather := LdGear.toon(LEATHER)
	var brass := LdGear.toon(BRASS, {"shade": Color("#8A5A2B") / BRASS, "rim": GOLD_HI})
	var hips := c.bone_pos("Hips")
	var head := c.bone_pos("Head")
	# goggles pushed up on the forehead
	var strap := LdGear.mi(LdGear.lathe([Vector2(0.105, -0.018), Vector2(0.108, 0.018)], 24, 1.0, 1.12), leather)
	c.attach("Head", strap, Transform3D(Basis(Vector3.RIGHT, -0.35), head + Vector3(0, 0.11, 0.0)))
	for side: float in [-1.0, 1.0]:
		var lens := Node3D.new()
		LdGear.mi(LdGear.cyl(0.032, 0.036, 0.03, 16), brass, lens, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		LdGear.mi(LdGear.cyl(0.026, 0.026, 0.032, 16), LdGear.toon(Color("#FF9A3C"), {"emit": Color(0.9, 0.45, 0.1) * 0.6, "outline": false}), lens, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.002)))
		c.attach("Head", lens, Transform3D(Basis(Vector3.RIGHT, -0.5), head + Vector3(side * 0.045, 0.165, 0.085)))
	# belt with pouches + bandolier
	var belt := LdGear.mi(LdGear.lathe([Vector2(0.15, -0.02), Vector2(0.155, 0.025)], 24, 1.0, 0.8), leather)
	c.attach("Hips", belt, Transform3D(Basis(), hips + Vector3(0, 0.0, 0.0)))
	for k in 3:
		var a := deg_to_rad(-60.0 + k * 45.0) + PI * 0.5
		var pouch := LdGear.mi(LdGear.box(Vector3(0.06, 0.07, 0.04)), leather)
		c.attach("Hips", pouch, Transform3D(Basis(Vector3.UP, a), hips + Vector3(cos(a) * 0.16, -0.03, sin(a) * 0.13 * -1.0 + 0.0)))
	var uc := c.bone_pos("UpperChest")
	var band: Array = []
	var bw: Array = []
	var bs: Array = []
	for i in 9:
		var t := float(i) / 8.0
		var ang := lerpf(-0.2, PI + 0.2, t)
		band.append(Vector3(lerpf(0.14, -0.13, t), lerpf(uc.y + 0.12, hips.y + 0.05, t), cos(ang * 0.5) * 0.0 + 0.11 * sin(t * PI) + 0.02))
		bw.append(0.04)
		bs.append(Vector3(0, 1, 0.2))
	c.attach("UpperChest", LdGear.mi(LdGear.ribbon(band, bw, bs, 0.012), leather), Transform3D.IDENTITY)
	# brass shoulder plate on the cannon arm
	var sh := c.bone_pos("RightUpperArm")
	var plate := LdGear.mi(LdGear.lathe([Vector2(0.0, 0.07), Vector2(0.06, 0.06), Vector2(0.095, 0.03), Vector2(0.1, -0.02)], 16, 1.0, 1.2), brass)
	c.attach("RightUpperArm", plate, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(38.0)), sh + Vector3(-0.04, 0.04, 0)))
	_la_costume(c, leather, brass)
	# weapon: oversized brass hand cannon
	var cannon := LdWeapons.launcher_cannon()
	c.attach("RightHand", cannon, gun_xf(c, gun_pitch))
	c.set_meta("weapon", cannon)


## Launcher costume (bible 2.5: yellow / orange / white blouse / brown leather, lace-up corset, goggles):
## leather lace-up corset, yellow capelet with orange trim, orange bustle panels, knee boots, thigh straps.
static func _la_costume(c: LdCharacter, leather: Material, brass: Material) -> void:
	var yellow := LdGear.toon(LAUNCHER_Y, {"shade": Color(0.75, 0.55, 0.62), "rim": GOLD_HI})
	var orange := LdGear.toon(LAUNCHER_O, {"shade": Color(0.7, 0.45, 0.6), "rim": GOLD_HI})
	var hips := c.bone_pos("Hips")
	var neck := c.bone_pos("Neck")
	# corset: leather lathe over the waist, gold lacing + brass busk studs down the front
	var cy := hips.y + 0.02
	var corset := LdGear.mi(LdGear.lathe([Vector2(0.142, cy - 0.01), Vector2(0.13, cy + 0.08), Vector2(0.122, cy + 0.15), Vector2(0.138, cy + 0.23), Vector2(0.15, cy + 0.27)], 24, 1.0, 0.8), leather)
	c.attach("Spine", corset, Transform3D(Basis(), Vector3(0, 0, 0.005)))
	for side: float in [-1.0, 1.0]:
		var edge := LdGear.mi(LdGear.lathe([Vector2(0.152, cy + 0.265), Vector2(0.155, cy + 0.285)], 24, 1.0, 0.8), LdGear.toon(GOLD, {"shade": Color("#8A5A2B") / GOLD}))
		c.attach("Spine", edge, Transform3D(Basis(), Vector3(0, -0.28 if side < 0 else 0.0, 0.005)))
	var lace: Array = []
	var lw: Array = []
	var ls: Array = []
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(cy + 0.02, cy + 0.24, t)
		var r := 0.122 + absf(t - 0.55) * 0.05
		lace.append(Vector3((0.02 if i % 2 == 0 else -0.02), y, r * 0.8 + 0.012))
		lw.append(0.008)
		ls.append(Vector3(1, 0, 0))
	c.attach("Spine", LdGear.mi(LdGear.ribbon(lace, lw, ls, 0.004), LdGear.toon(GOLD_HI)), Transform3D.IDENTITY)
	# yellow capelet with orange trim (front gap)
	var cape := LdGear.mi(LdGear.lathe([Vector2(0.24, -0.15), Vector2(0.2, -0.07), Vector2(0.13, 0.0), Vector2(0.085, 0.045)], 24, 1.0, 0.8, TAU * 0.82), yellow)
	cape.rotation.y = PI * 0.5 + TAU * 0.09
	var cw := Node3D.new()
	cw.add_child(cape)
	c.attach("UpperChest", cw, Transform3D(Basis(), neck + Vector3(0, -0.03, -0.01)))
	var ctrim := LdGear.mi(LdGear.lathe([Vector2(0.245, -0.165), Vector2(0.24, -0.135)], 24, 1.0, 0.8, TAU * 0.82), orange)
	ctrim.rotation.y = cape.rotation.y
	var ctw := Node3D.new()
	ctw.add_child(ctrim)
	c.attach("UpperChest", ctw, Transform3D(Basis(), neck + Vector3(0, -0.03, -0.01)))
	# orange bustle: two back panels over the skirt, yellow hem
	var knee := c.bone_pos("RightLowerLeg")
	for side: float in [-1.0, 1.0]:
		var pts: Array = []
		var w: Array = []
		var sd: Array = []
		for i in 6:
			var t := float(i) / 5.0
			var ang := deg_to_rad(150.0)
			var rad := 0.16 * (1.0 + t * 0.9)
			pts.append(Vector3(side * sin(ang) * rad, lerpf(hips.y + 0.03, knee.y + 0.12, t), cos(ang) * rad * 0.85 - t * t * 0.05))
			w.append(lerpf(0.18, 0.3, t))
			sd.append(Vector3(cos(ang) * side, 0, -sin(ang)))
		c.attach("Hips", LdGear.mi(LdGear.ribbon(pts, w, sd, 0.012), orange), Transform3D.IDENTITY)
		var last: Vector3 = pts[5]
		var hem: Array = [last + (sd[5] as Vector3) * -0.15 + Vector3(0, 0.01, 0), last + Vector3(0, 0.01, 0), last + (sd[5] as Vector3) * 0.15 + Vector3(0, 0.01, 0)]
		c.attach("Hips", LdGear.mi(LdGear.ribbon(hem, [0.035, 0.035, 0.035], [Vector3.UP, Vector3.UP, Vector3.UP], 0.016), yellow), Transform3D.IDENTITY)
	# knee boots with a flared cuff + thigh straps with brass buckles
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		var kp := c.bone_pos(ll)
		var fp := c.bone_pos("RightFoot" if side < 0 else "LeftFoot")
		var boot := LdGear.mi(LdGear.lathe([Vector2(0.05, fp.y - 0.02), Vector2(0.055, fp.y + 0.08), Vector2(0.066, lerpf(fp.y, kp.y, 0.6)), Vector2(0.07, kp.y - 0.05), Vector2(0.085, kp.y - 0.0)], 14), leather)
		c.attach(ll, boot, Transform3D(Basis(), Vector3(kp.x, 0, kp.z + 0.005)))
		var cuff := LdGear.mi(LdGear.lathe([Vector2(0.086, kp.y - 0.005), Vector2(0.09, kp.y + 0.02)], 14), LdGear.toon(GOLD, {"shade": Color("#8A5A2B") / GOLD}))
		c.attach(ll, cuff, Transform3D(Basis(), Vector3(kp.x, 0, kp.z + 0.005)))
		var up := c.bone_pos(ul)
		var sy := lerpf(up.y, kp.y, 0.55)
		var sx := lerpf(up.x, kp.x, 0.55)
		var sz := lerpf(up.z, kp.z, 0.55)
		var strap := LdGear.mi(LdGear.lathe([Vector2(0.078, sy - 0.015), Vector2(0.08, sy + 0.015)], 14), leather)
		c.attach(ul, strap, Transform3D(Basis(), Vector3(sx, 0, sz)))
		var buckle := LdGear.mi(LdGear.box(Vector3(0.035, 0.035, 0.012)), brass)
		c.attach(ul, buckle, Transform3D(Basis(), Vector3(sx + side * 0.03, sy, sz + 0.075)))


# =====================================================================  WITCH  (王不留行 type)

static func witch() -> Dictionary:
	return {
		"id": "witch", "name": "Witch", "model": "res://lookdev/assets/chars/vroid_hairsample_male.glb",
		"idle": "Spell_Simple_Idle", "skill": "Spell_Simple_Shoot", "skill_t": 0.3, "cast": "Levitate Idle",
		"rim": Color(0.75, 0.85, 1.0),
		"dress": {
			"Tops": {"map": [Color("#0E1440"), Color("#23379A"), Color("#6F86E0")], "contrast": 1.3},
			"Bottoms": {"map": [Color("#0A0D24"), Color("#161C44"), Color("#3A4580")], "contrast": 1.2},
			"Shoes": {"map": [Color("#120C08"), Color("#3B2416"), Color("#9A7440")]},
			"HAIR": {"map": [Color("#5D6A86"), Color("#B9C4D8"), Color("#F4F8FF")], "contrast": 1.15, "line": 1.7},
			"EyeIris": {"iris": Color(0.8, 0.85, 1.2)},
		},
		"build": func(c: LdCharacter) -> void: _wi_build(c),
	}


static func _wi_build(c: LdCharacter) -> void:
	_proportions(c, 1.04, 0.95)
	var robe := LdGear.toon(WITCH_BLUE, {"shade": Color(0.5, 0.5, 0.9)})
	var robe_in := LdGear.toon(Color("#121A4A"), {"shade": Color(0.6, 0.6, 0.9)})
	var gold := LdGear.toon(GOLD, {"shade": Color("#8A5A2B") / GOLD, "rim": GOLD_HI})
	var hips := c.bone_pos("Hips")
	var head := c.bone_pos("Head")
	var uc := c.bone_pos("UpperChest")
	# floor-length robe: open-front bell (arc leaves a slit so the legs read when stepping)
	var prof := [Vector2(0.37, -hips.y + 0.07), Vector2(0.31, -0.75), Vector2(0.23, -0.35), Vector2(0.175, -0.05), Vector2(0.16, 0.06)]
	var bell := LdGear.mi(LdGear.lathe(prof, 28, 1.0, 0.9, TAU * 0.86), robe)
	bell.rotation.y = PI * 0.5 + TAU * 0.07
	var bw := Node3D.new()
	bw.add_child(bell)
	c.attach("Hips", bw, Transform3D(Basis(), hips))
	var hem := LdGear.mi(LdGear.lathe([Vector2(0.372, -hips.y + 0.07), Vector2(0.36, -hips.y + 0.13)], 28, 1.0, 0.9, TAU * 0.86), gold)
	hem.rotation.y = bell.rotation.y
	var hw := Node3D.new()
	hw.add_child(hem)
	c.attach("Hips", hw, Transform3D(Basis(), hips))
	# gold flame tongues along the hem
	for k in 11:
		var a := TAU * 0.07 + PI * 0.5 + TAU * 0.86 * (k + 0.5) / 11.0
		var fl := LdGear.mi(LdGear.extrude(_flame(), 0.008, 0.0), gold)
		var p := Vector3(cos(a) * 0.37, -hips.y + 0.13, -sin(a) * 0.37 * 0.9)
		c.attach("Hips", fl, Transform3D(Basis(Vector3.UP, a + PI * 0.5), hips + p))
	# mantle with gold flame trim
	var neck := c.bone_pos("Neck")
	var mantle := LdGear.mi(LdGear.lathe([Vector2(0.29, -0.2), Vector2(0.25, -0.1), Vector2(0.16, 0.0), Vector2(0.1, 0.05)], 24, 1.0, 0.75, TAU * 0.8), robe_in)
	mantle.rotation.y = PI * 0.5 + TAU * 0.1
	var mw := Node3D.new()
	mw.add_child(mantle)
	c.attach("UpperChest", mw, Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	var mrim := LdGear.mi(LdGear.lathe([Vector2(0.295, -0.215), Vector2(0.285, -0.18)], 24, 1.0, 0.75, TAU * 0.8), gold)
	mrim.rotation.y = mantle.rotation.y
	var mrw := Node3D.new()
	mrw.add_child(mrim)
	c.attach("UpperChest", mrw, Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	# crowned witch hat
	var hat := Node3D.new()
	LdGear.mi(LdGear.lathe([Vector2(0.3, -0.008), Vector2(0.24, 0.012), Vector2(0.12, 0.03)], 32), robe, hat)
	var cone_pts: Array = []
	var cone_r: Array = []
	for i in 10:
		var t := float(i) / 9.0
		cone_pts.append(Vector3(0, t * 0.48, -t * t * 0.2))
		cone_r.append(lerpf(0.125, 0.008, pow(t, 0.85)))
	LdGear.mi(LdGear.tube(cone_pts, cone_r, 18), robe, hat)
	LdGear.mi(LdGear.lathe([Vector2(0.128, 0.0), Vector2(0.124, 0.05)], 24), gold, hat)
	for k in 7:
		var a := TAU * k / 7.0
		var spike := LdGear.mi(LdGear.extrude(PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0, 0.075)]), 0.01), gold, hat)
		spike.transform = Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.124, 0.045, cos(a) * 0.124))
	var hgem := LdGear.mi(LdGear.sphere(0.02, 12), LdGear.toon(Color("#6C7BFF"), {"emit": Color("#6C7BFF") * 1.2, "outline": false}), hat)
	hgem.position = Vector3(0, 0.025, 0.13)
	c.attach("Head", hat, Transform3D(Basis(Vector3.RIGHT, -0.12), head + Vector3(0, 0.155, -0.01)))
	# weapon: Extinguished-Stardust style broom
	var broom := LdWeapons.star_broom()
	c.attach("RightHand", broom, grip_xf(c, 70.0))
	c.set_meta("weapon", broom)


static func _flame() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.02, 0.03), Vector2(0.035, 0.06), Vector2(0.008, 0.045), Vector2(0.0, 0.085), Vector2(-0.012, 0.04), Vector2(-0.032, 0.055), Vector2(-0.02, 0.025)])
