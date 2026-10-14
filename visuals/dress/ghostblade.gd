extends RefCounted
## Ghostblade 鬼剑士 (逢山鬼泣 / 一寸灰 colour cues), bible 2.5: bandaged sword arm, ghost runes, long coat; tachi
## (WeaponFactory "tachi"). Black-violet / pale violet glow / silver: a long black-violet coat with a high silver-edged
## collar and floor-sweeping split tails (runtime cloth, the hero element), a wide-cuffed off-hand sleeve, glowing
## rune-inked bandages on the sword arm, paper talismans on a silver chain belt and three ghost-rune sigils that
## drift around the waist. Lavender-silver hair.

const L := preload("res://visuals/dress/_swordmage_lib.gd")
const COAT := Color("#33254A")
const DARK := Color("#120C1A")
const GLOW := Color("#B48CFF")
const SILVER := Color("#C9D3DE")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_d_darkness",
		"height": 1.76,
		"proportions": [1.07, 0.95],
		"rim": Color(0.82, 0.75, 1.0),
		"dress": {
			# gothic one-piece -> black-violet under-dress with violet folds; shoes -> silver-trimmed black; hair -> lavender silver
			"Tops": {"map": [Color("#0A0712"), Color("#2C2042"), Color("#8A6CB8")], "contrast": 1.2},
			"Shoes": {"map": [Color("#08060C"), Color("#2A2236"), Color("#C9D3DE")], "contrast": 1.2},
			"HAIR": {"map": [Color("#6E6488"), Color("#C8C0E2"), Color("#FBF8FF")], "contrast": 1.1, "line": 1.7, "shade": Color(0.66, 0.6, 0.92)},
			"Brow": {"color": Color("#6E6488")},
			"EyeIris": {"iris": Color(0.85, 0.65, 1.25)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_B"], &"attack_1h_1": ["Sword_Regular_B"], &"attack_1h_2": ["Sword_Regular_A"]},
		"grips": {"tachi": {"kind": "blade", "tilt": 0.0}},
	}


static func build(b: AnimeBody) -> void:
	var coat := AnimeGear.toon(COAT, {"shade": Color(0.6, 0.55, 0.9), "rim": Color(0.85, 0.75, 1.0), "rim_strength": 0.75})
	var dark := AnimeGear.toon(DARK, {"shade": Color(0.7, 0.65, 0.95), "rim": Color(0.8, 0.7, 1.0)})
	var silver := AnimeGear.toon(SILVER, {"shade": Color("#6E7894") / SILVER, "rim": Color.WHITE, "rim_strength": 0.9})
	var wrap := AnimeGear.toon(Color("#E4DEEC"), {"shade": Color("#8A80A8") / Color("#E4DEEC")})
	var paper := AnimeGear.toon(Color("#EFE6D2"), {"shade": Color("#9A8AA0") / Color("#EFE6D2")})
	var ink := AnimeGear.toon(Color("#B0202E"), {"outline": false})
	var glow := AnimeGear.glow(GLOW, 2.6)
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var ch := b.bone_pos("Chest")
	var sp := b.bone_pos("Spine")
	var neck := b.bone_pos("Neck")
	# --- long coat bodice, open at the front, silver edges; tall silver-rimmed collar flaring outward at the back
	var y0 := sp.y - 0.08
	var y1 := uc.y + 0.1
	var bod := [Vector2(0.158, y0 - uc.y), Vector2(0.142, sp.y - uc.y), Vector2(0.152, ch.y - uc.y), Vector2(0.165, 0.02), Vector2(0.152, 0.07), Vector2(0.112, y1 - uc.y)]
	b.attach("UpperChest", L.shell(bod, 0.24, coat, 24, 0.84), Transform3D(Basis(), uc))
	b.attach("UpperChest", L.shell([Vector2(0.16, y0 - uc.y - 0.01), Vector2(0.16, y0 - uc.y + 0.014)], 0.24, silver, 24, 0.84), Transform3D(Basis(), uc))
	var collar := [Vector2(0.08, -0.06), Vector2(0.088, 0.02), Vector2(0.105, 0.09), Vector2(0.13, 0.13)]
	b.attach("UpperChest", L.shell(collar, 0.3, coat, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.01)))
	b.attach("UpperChest", L.shell([Vector2(0.13, 0.125), Vector2(0.136, 0.142)], 0.3, silver, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, -0.01)))
	# silver claw clasps across the opening + a violet ghost gem
	for k in 2:
		var cy := lerpf(ch.y + 0.03, sp.y + 0.0, float(k))
		var bar := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(-0.03, 0.01), Vector2(0.0, 0.0), Vector2(0.03, 0.01), Vector2(0.07, 0.0), Vector2(0.03, -0.012), Vector2(0.0, -0.006), Vector2(-0.03, -0.012)])
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(bar, 0.01), silver), Transform3D(Basis(), Vector3(0, cy, ch.z + 0.15 - k * 0.02)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.016, 10), AnimeGear.toon(GLOW, {"emit": GLOW * 1.4, "outline": false})), Transform3D(Basis(), neck + Vector3(0, -0.07, 0.085)))
	# --- off arm: coat sleeve with a wide flared cuff, pointed silver shoulder plate
	var lua := b.bone_pos("LeftUpperArm")
	var lla := b.bone_pos("LeftLowerArm")
	var lh := b.bone_pos("LeftHand")
	ClassDress.limb_guard(b, "LeftUpperArm", "LeftLowerArm", [0.05, 0.047, 0.045], -0.05, 1.02, coat, null, 12)
	var cuff := AnimeGear.lathe([Vector2(0.045, 0.0), Vector2(0.06, 0.12), Vector2(0.095, 0.24), Vector2(0.1, 0.25)], 14)
	b.attach("LeftLowerArm", AnimeGear.mi(cuff, coat), Transform3D(Basis(Quaternion(Vector3.UP, (lh - lla).normalized())), lla))
	b.attach("LeftLowerArm", AnimeGear.mi(AnimeGear.lathe([Vector2(0.1, 0.245), Vector2(0.104, 0.262)], 14), silver), Transform3D(Basis(Quaternion(Vector3.UP, (lh - lla).normalized())), lla))
	ClassDress.pauldron(b, 1.0, dark, silver, 0.95, 2, true)
	# --- sword arm: rune-inked bandages from shoulder to knuckles, violet glyphs glowing through, silver bracer
	L.bandage(b, "RightUpperArm", "RightLowerArm", 0.05, 3.0, 0.05, 1.0, wrap, 0.028)
	L.bandage(b, "RightLowerArm", "RightHand", 0.043, 3.5, 0.0, 1.0, wrap, 0.026)
	var rua := b.bone_pos("RightUpperArm")
	var rla := b.bone_pos("RightLowerArm")
	var rh := b.bone_pos("RightHand")
	for k in 4:
		var t := 0.15 + k * 0.22
		var on_upper := k < 2
		var p := rua.lerp(rla, t * 2.0 - 0.1) if on_upper else rla.lerp(rh, (t - 0.44) * 1.6)
		var g := AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.014, 4, 0.3), 0.004), glow)
		b.attach("RightUpperArm" if on_upper else "RightLowerArm", g, Transform3D(Basis(), p + Vector3(0, 0.0, 0.05)))
	ClassDress.limb_guard(b, "RightLowerArm", "RightHand", [0.05, 0.054], 0.62, 0.8, silver, null, 12)
	ClassDress.pauldron(b, -1.0, dark, silver, 0.7, 1, false)
	# --- silver chain belt with paper talismans (red glyph strokes) on the off hip
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.152, -0.018), Vector2(0.155, 0.018)], 24, 1.0, 0.84), dark), Transform3D(Basis(), hips + Vector3(0, 0.04, 0)))
	for k in 10:
		var a := TAU * k / 10.0
		var lk := AnimeGear.mi(AnimeGear.lathe([Vector2(0.012, -0.004), Vector2(0.014, 0.004)], 8), silver)
		b.attach("Hips", lk, Transform3D(Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.RIGHT, a), hips + Vector3(sin(a) * 0.162, 0.01 + 0.02 * cos(a), cos(a) * 0.138)))
	for k in 3:
		var tx := 0.1 + k * 0.03
		var top := hips + Vector3(tx, 0.0, 0.11 - k * 0.04)
		var strip := AnimeGear.mi(AnimeGear.box(Vector3(0.04, 0.17 - k * 0.025, 0.004)), paper)
		var rot := Basis(Vector3.UP, 0.5 + k * 0.35) * Basis(Vector3.FORWARD, 0.08)
		b.attach("Hips", strip, Transform3D(rot, top + Vector3(0, -0.09 + k * 0.012, 0)))
		for j in 3:
			b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(0.022 - j * 0.005, 0.006, 0.006)), ink), Transform3D(rot, top + rot * Vector3(0, -0.04 - j * 0.035, 0.003)))
	# --- legs: black boots shafts with silver pointed knee guards
	for side: float in [-1.0, 1.0]:
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.052, 0.05, 0.044, 0.042], 0.05, 0.95, dark, silver, 12)
		var kp := b.bone_pos(ll)
		b.attach(ll, AnimeGear.mi(AnimeGear.extrude(L.knee_plate(0.038), 0.02, 0.005), silver), Transform3D(Basis(Vector3.RIGHT, -0.1), kp + Vector3(0, 0.0, 0.05)))
	# --- hero element: two floor-sweeping coat tails, black-violet with a darker lining (runtime cloth)
	var cols := [["Hips", 0.2, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.085, -0.12], ["LeftLowerLeg", 0.085, -0.12]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "Spine", Transform3D(Basis(), hips + Vector3(side * 0.06, 0.08, -0.14)), {
			"name": "LongCoat", "length": 1.08, "segments": 12, "width": [0.16, 0.18, 0.2, 0.22, 0.22, 0.18, 0.05], "dir": Vector3(side * 0.08, -1.0, -0.22),
			"side": Vector3(1, 0, side * 0.2), "material": coat, "lining": AnimeGear.toon(Color("#4A3272"), {"shade": Color(0.6, 0.55, 0.9)}), "thickness": 0.012, "stiffness": 0.035, "stiffness_tip": 0.005,
			"gravity": 9.0, "drag": 0.08, "wind": Vector3(side * 0.4, 0, -0.7), "colliders": cols})
	# --- three ghost-rune sigils drifting around the waist (slow orbit)
	var f := L.floater(0.55, 0.03, 1.3)
	b.attach("Hips", f, Transform3D(Basis(), hips + Vector3(0, 0.12, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var pos := Vector3(cos(a) * 0.34, 0.06 * k, sin(a) * 0.34)
		var face := Basis(Vector3.UP, -a + PI * 0.5)
		L.keep(AnimeGear.lathe([Vector2(0.062, -0.003), Vector2(0.07, 0.003)], 20), AnimeGear.glow(GLOW, 2.6, true, 0.9), f, Transform3D(face * Basis(Vector3.RIGHT, PI / 2), pos))
		L.keep(AnimeGear.extrude(AnimeGear.star_poly(0.05, 3, 0.3), 0.005), AnimeGear.glow(GLOW.lightened(0.35), 3.2), f, Transform3D(face, pos))
		L.keep(AnimeGear.sphere(0.075, 10), AnimeGear.glow(GLOW, 1.2, true, 0.18), f, Transform3D(Basis(), pos))
