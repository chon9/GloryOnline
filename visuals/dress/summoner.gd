extends RefCounted
## Summoner 召唤师 (昧光 colour cues), bible 2.5: book on a chain, small floating spirits; ring staff with a hanging
## spirit orb (WeaponFactory "staff_ring"). Green-teal / cream / gold: a cream capelet with a teal collar and two
## long cream stole tails lined in teal (runtime cloth, the hero element), a teal beret with a gold leaf pin, a
## layered skirt hem, a big gold-cornered grimoire hanging on a chain at the hip and three little spirit wisps
## circling the head. Chestnut hair.

const L := preload("res://visuals/dress/_swordmage_lib.gd")
const TEAL := Color("#2F8F7A")
const TEAL_DK := Color("#14453C")
const CREAM := Color("#F2EAD0")
const SPIRIT := Color("#7CF0A0")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_e",
		"height": 1.66,
		"proportions": [1.08, 0.96],
		"rim": Color(1.0, 0.92, 0.72),
		"dress": {
			# one-piece -> teal dress with cream panels; laced boots -> brown leather; hair -> chestnut
			"Onepice": {"map": [Color("#0C2E28"), Color("#2F8F7A"), Color("#F2EAD0")], "contrast": 1.25},
			"Shoes": {"map": [Color("#1A0E08"), Color("#5A3820"), Color("#C09060")], "contrast": 1.2},
			"HAIR": {"map": [Color("#2A1408"), Color("#7A4424"), Color("#D49A62")], "contrast": 1.1, "line": 1.7, "shade": Color(0.7, 0.55, 0.7)},
			"EyeIris": {"iris": Color(0.55, 1.15, 0.75)},
		},
		"anims": {&"idle": ["Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"], &"summon": ["kk_Ranged_Magic_Summon", "Two-hand Blast"],
			&"heal": ["kk_Ranged_Magic_Raise", "Two-hand Blast"],
			&"cast": ["Spell_Simple_Shoot"]},
		"grips": {"staff_ring": {"kind": "pole", "tilt": 15.0, "yaw": 75.0}},
	}


static func build(b: AnimeBody) -> void:
	var teal := AnimeGear.toon(TEAL, {"shade": Color("#14405A") / TEAL, "rim": Color(0.85, 1.0, 0.85)})
	var teal_dk := AnimeGear.toon(TEAL_DK, {"shade": Color(0.6, 0.62, 0.9), "rim": Color(0.8, 1.0, 0.85)})
	var cream := AnimeGear.toon(CREAM, {"shade": Color("#A8A0B8") / CREAM, "rim": Color.WHITE})
	var gold := AnimeGear.gold()
	var leather := AnimeGear.toon(ClassDress.LEATHER)
	var spirit := AnimeGear.toon(SPIRIT, {"emit": SPIRIT * 1.2, "outline": false})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var head := b.bone_pos("Head")
	# --- teal beret tilted over one ear, gold leaf pin with a spirit gem
	var beret := Node3D.new()
	beret.name = "Beret"
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.115, -0.01), Vector2(0.15, 0.025), Vector2(0.14, 0.06), Vector2(0.08, 0.085), Vector2(0.0, 0.09)], 22, 1.0, 1.0), teal, beret)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.112, -0.016), Vector2(0.118, 0.006)], 22), gold, beret)
	AnimeGear.mi(AnimeGear.cyl(0.006, 0.012, 0.03, 6), teal_dk, beret, Transform3D(Basis(), Vector3(0, 0.1, 0)))
	var leaf := PackedVector2Array([Vector2(0, 0), Vector2(0.02, 0.03), Vector2(0.015, 0.075), Vector2(0, 0.1), Vector2(-0.015, 0.075), Vector2(-0.02, 0.03)])
	AnimeGear.mi(AnimeGear.extrude(leaf, 0.008, 0.002), gold, beret, Transform3D(Basis(Vector3.FORWARD, -0.6), Vector3(0.1, 0.03, 0.06)))
	AnimeGear.mi(AnimeGear.extrude(leaf, 0.008, 0.002), gold, beret, Transform3D(Basis(Vector3.FORWARD, -1.1), Vector3(0.1, 0.02, 0.06)))
	AnimeGear.mi(AnimeGear.sphere(0.016, 10), spirit, beret, Transform3D(Basis(), Vector3(0.1, 0.03, 0.075)))
	b.attach("Head", beret, Transform3D(Basis(Vector3.FORWARD, -0.22) * Basis(Vector3.RIGHT, -0.18), head + Vector3(0.02, 0.17, -0.02)))
	# --- cream capelet over the shoulders, teal stand collar, gold rim and clasp
	var cape := [Vector2(0.235, -0.17), Vector2(0.205, -0.08), Vector2(0.13, 0.0), Vector2(0.085, 0.04)]
	b.attach("UpperChest", L.shell(cape, 0.1, cream, 24, 0.85), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.005)))
	b.attach("UpperChest", L.shell([Vector2(0.24, -0.182), Vector2(0.232, -0.152)], 0.1, teal, 24, 0.85), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.005)))
	b.attach("UpperChest", L.shell([Vector2(0.075, -0.04), Vector2(0.08, 0.03), Vector2(0.088, 0.05)], 0.12, teal, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, 0)))
	b.attach("UpperChest", L.shell([Vector2(0.088, 0.045), Vector2(0.091, 0.06)], 0.12, gold, 20, 1.0), Transform3D(Basis(), neck + Vector3(0, -0.02, 0)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.03, 4, 0.45), 0.012, 0.003), gold), Transform3D(Basis(), neck + Vector3(0, -0.07, 0.085)))
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.sphere(0.012, 8), spirit), Transform3D(Basis(), neck + Vector3(0, -0.07, 0.094)))
	# --- teal cuffs with cream turn-backs on the forearms
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.04, 0.046, 0.054], 0.55, 1.0, teal, null, 12)
		ClassDress.limb_guard(b, la, hd, [0.056, 0.06], 0.88, 1.0, cream, gold, 12)
	# --- belt with a gold buckle; layered cream underskirt hem peeking under the dress
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.142, -0.02), Vector2(0.145, 0.022)], 24, 1.0, 0.85), leather), Transform3D(Basis(), hips + Vector3(0, 0.035, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.026, 0.032), 0.016, 0.004), gold), Transform3D(Basis(), hips + Vector3(0, 0.035, 0.125)))
	# --- the grimoire on a chain at the left hip: teal cover, cream pages, gold corners and a glowing sigil
	var book := Node3D.new()
	book.name = "Grimoire"
	AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.22, 0.17)), cream, book)
	AnimeGear.mi(AnimeGear.box(Vector3(0.012, 0.235, 0.185)), teal, book, Transform3D(Basis(), Vector3(0.03, 0, 0.0)))
	AnimeGear.mi(AnimeGear.box(Vector3(0.012, 0.235, 0.185)), teal, book, Transform3D(Basis(), Vector3(-0.03, 0, 0.0)))
	AnimeGear.mi(AnimeGear.box(Vector3(0.072, 0.235, 0.018)), teal_dk, book, Transform3D(Basis(), Vector3(0, 0, -0.088)))
	for cy: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			AnimeGear.mi(AnimeGear.box(Vector3(0.078, 0.03, 0.03)), gold, book, Transform3D(Basis(), Vector3(0, cy * 0.105, cz * 0.08)))
	AnimeGear.mi(AnimeGear.extrude(AnimeGear.star_poly(0.05, 6, 0.5), 0.004), AnimeGear.glow(SPIRIT, 2.4), book, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.038, 0, 0)))
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.06, -0.002), Vector2(0.066, 0.002)], 20), gold, book, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0.037, 0, 0)))
	var bpos := hips + Vector3(0.2, -0.2, 0.02)
	b.attach("Hips", book, Transform3D(Basis(Vector3.UP, -0.25) * Basis(Vector3.FORWARD, 0.12), bpos))
	var chain: Array = []
	var c0 := hips + Vector3(0.12, 0.03, 0.1)
	var c1 := bpos + Vector3(-0.01, 0.125, 0.0)
	for i in 7:
		var t := float(i) / 6.0
		chain.append(c0.lerp(c1, t) + Vector3(0, -0.06 * sin(t * PI), 0))
	for i in 6:
		var p0: Vector3 = chain[i]
		var p1: Vector3 = chain[i + 1]
		var lk := AnimeGear.mi(AnimeGear.lathe([Vector2(0.011, -0.004), Vector2(0.013, 0.004)], 8, 1.0, 1.6), gold)
		b.attach("Hips", lk, Transform3D(Basis(Quaternion(Vector3.UP, (p1 - p0).normalized())) * Basis(Vector3.RIGHT, PI / 2 if i % 2 == 0 else 0.0), (p0 + p1) * 0.5))
	# --- hero element: two long cream stole tails from the capelet, teal lining (runtime cloth)
	var cols := [["UpperChest", 0.16, 0.0], ["Hips", 0.19, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15], ["RightLowerLeg", 0.08, -0.1], ["LeftLowerLeg", 0.08, -0.1]]
	for side: float in [-1.0, 1.0]:
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(side * 0.07, 0.04, -0.15)), {
			"name": "Stole", "length": 0.8, "segments": 10, "width": [0.13, 0.15, 0.17, 0.18, 0.2, 0.14], "dir": Vector3(side * 0.1, -1.0, -0.25),
			"side": Vector3(1, 0, 0), "material": cream, "lining": teal, "thickness": 0.012, "stiffness": 0.035, "stiffness_tip": 0.005,
			"gravity": 8.5, "drag": 0.08, "wind": Vector3(side * 0.3, 0, -0.6), "colliders": cols})
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(leaf, 0.008, 0.002), gold), Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.FORWARD, side * 0.5 + PI), uc + Vector3(side * 0.07, 0.07, -0.165)))
	# --- three spirit wisps circling the head (slow orbit, gentle bob)
	var f := L.floater(1.1, 0.03, 2.4)
	b.attach("Head", f, Transform3D(Basis(), head + Vector3(0, 0.2, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var p := Vector3(cos(a) * 0.38, 0.06 * sin(a * 3.0), sin(a) * 0.38)
		L.orb(f, p, SPIRIT if k != 1 else Color("#9AD8FF"), 0.028)
		# a tiny tail trailing each wisp
		var tail: Array = [p, p + Vector3(-sin(a), 0.0, cos(a)) * 0.05 + Vector3(0, -0.01, 0), p + Vector3(-sin(a), 0.0, cos(a)) * 0.1 + Vector3(0, -0.03, 0)]
		L.keep(AnimeGear.tube(tail, [0.02, 0.012, 0.002], 8), AnimeGear.glow(SPIRIT, 1.6, true, 0.55), f)
