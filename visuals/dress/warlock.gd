extends RefCounted
## Warlock 术士, bible 2.5: skull ornaments, cursed tome, black / toxic green; cane (WeaponFactory "cane").
## Hero silhouette: a long tattered black cloak with a toxic-green lining (several runtime-cloth strips of uneven
## length so the hem reads torn). Jagged bone collar, skull pauldron, chained cursed tome at the hip, rune-lit
## gauntlets, split black skirt riding the legs, mint-ash hair, green eyes.

const L := preload("res://visuals/dress/_priest_lib.gd")
const BLACK := Color("#141318")
const PLUM := Color("#2A1E36")
const TOXIC := Color("#7CFF6B")
const BONE := Color("#E6DEC8")


static func dress() -> Dictionary:
	return {
		"base": "avatarsample_f",
		"height": 1.72,
		"proportions": [1.07, 0.95],
		"rim": Color(0.75, 1.0, 0.75),
		"dress": {
			# one-piece -> black-plum robe dress, shoes -> black boots, hair -> mint ash
			"Onepice": {"map": [Color("#060508"), Color("#1C1622"), Color("#4A3A5A")], "contrast": 1.3},
			"Shoes": {"map": [Color("#060508"), Color("#1E1A22"), Color("#4A4452")], "contrast": 1.2},
			"HAIR": {"map": [Color("#3A5A48"), Color("#A8CDB4"), Color("#EEFFF0")], "contrast": 1.15, "line": 1.7, "shade": Color(0.62, 0.72, 0.8)},
			"Brow": {"color": Color("#5A7A60")},
			"EyeIris": {"iris": Color(0.6, 1.3, 0.55)},
		},
		"anims": {&"idle": ["Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"], &"cast": ["Two-hand Blast", "Spell_Simple_Shoot"],
			&"channel": ["Spell_Simple_Idle"], &"summon": ["kk_Ranged_Magic_Summon", "Two-hand Blast"]},
		# like the witch's broom: the cane stands upright beside the casting hand
		"grips": {"cane": {"kind": "pole", "tilt": 15.0, "yaw": 75.0}},
	}


static func _skull(s: float, bone: Material, eye: Material) -> Node3D:
	var n := Node3D.new()
	n.name = "Skull"
	var cr := AnimeGear.mi(AnimeGear.sphere(0.05 * s, 12), bone, n)
	cr.scale = Vector3(1.0, 0.92, 1.05)
	var jaw := AnimeGear.mi(AnimeGear.box(Vector3(0.06 * s, 0.03 * s, 0.05 * s)), bone, n)
	jaw.position = Vector3(0, -0.045 * s, 0.02 * s)
	for side: float in [-1.0, 1.0]:
		AnimeGear.mi(AnimeGear.sphere(0.016 * s, 8), eye, n, Transform3D(Basis(), Vector3(side * 0.021 * s, -0.004 * s, 0.044 * s)))
	return n


static func build(b: AnimeBody) -> void:
	var black := AnimeGear.toon(BLACK, {"shade": Color(0.6, 0.55, 0.85), "rim": Color(0.7, 1.0, 0.7), "rim_strength": 0.8})
	var plum := AnimeGear.toon(PLUM, {"shade": Color(0.6, 0.55, 0.85), "rim": Color(0.7, 1.0, 0.7)})
	var green := AnimeGear.toon(Color("#3C8A3A"), {"shade": Color(0.6, 0.7, 0.85), "rim": Color(0.8, 1.0, 0.7)})
	var glow := AnimeGear.toon(TOXIC, {"emit": TOXIC * 1.4, "outline": false})
	var bone := AnimeGear.toon(BONE, {"shade": Color("#9A8A78") / BONE, "rim": Color(0.85, 1.0, 0.8)})
	var silver := AnimeGear.toon(Color("#9AA4B4"), {"shade": Color(0.6, 0.62, 0.86), "rim": Color.WHITE})
	var hips := b.bone_pos("Hips")
	var uc := b.bone_pos("UpperChest")
	var neck := b.bone_pos("Neck")
	var foot := b.bone_pos("RightFoot")
	# --- black bodice + jagged bone collar (claw spikes fanning up behind the head)
	L.shell(b, "UpperChest", uc, [Vector2(0.135, -0.12), Vector2(0.148, -0.02), Vector2(0.138, 0.06), Vector2(0.095, 0.11)], black, 0.9)
	L.rim(b, "UpperChest", uc, 0.136, -0.12, green, 0.9, TAU, true, 0.012)
	var sp := b.bone_pos("Spine")
	L.shell(b, "Spine", Vector3(0, sp.y, 0), [Vector2(0.15, -0.12), Vector2(0.128, -0.02), Vector2(0.134, 0.08)], black, 0.86)
	L.shell(b, "UpperChest", neck + Vector3(0, -0.04, -0.005), [Vector2(0.2, -0.13), Vector2(0.17, -0.06), Vector2(0.12, 0.0), Vector2(0.09, 0.04)], plum, 0.8, TAU * 0.8, true)
	for k in 9:
		var a := -PI * 0.5 + TAU * 0.12 + TAU * 0.76 * k / 8.0
		var h := 0.08 + 0.07 * (1.0 - absf(float(k) - 4.0) / 4.0)
		var spike := PackedVector2Array([Vector2(-0.018, 0.0), Vector2(0.018, 0.0), Vector2(0.006, h * 0.6), Vector2(0.0, h)])
		var p := Vector3(cos(a) * 0.1, 0.02, -sin(a) * 0.09)
		var bs := Basis(Vector3.UP, a + PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
		b.attach("UpperChest", AnimeGear.mi(AnimeGear.extrude(spike, 0.01), bone), Transform3D(bs, neck + p))
	# toxic gem at the throat
	L.gem(b, "UpperChest", neck + Vector3(0, -0.07, 0.11), TOXIC, 0.016, 1.4)
	# --- skull pauldron on the left shoulder over a black plate; a small bone cap on the right
	ClassDress.pauldron(b, 1.0, black, green, 1.05, 2, false)
	var lsh := b.bone_pos("LeftUpperArm")
	var sk := _skull(1.55, bone, glow)
	b.attach("LeftUpperArm", sk, Transform3D(Basis(Vector3.UP, 1.15) * Basis(Vector3.RIGHT, 0.15), lsh + Vector3(0.1, 0.07, 0.01)))
	ClassDress.pauldron(b, -1.0, bone, black, 0.8, 1, false)
	# --- rune-lit gauntlets (black, glowing green bands) and black boots with pointed bone knee caps
	for side: float in [-1.0, 1.0]:
		var la := "RightLowerArm" if side < 0 else "LeftLowerArm"
		var hd := "RightHand" if side < 0 else "LeftHand"
		ClassDress.limb_guard(b, la, hd, [0.038, 0.042, 0.05, 0.06], 0.0, 1.0, black, green, 12)
		# black sleeves over the base's painted arm bands
		var ua := "RightUpperArm" if side < 0 else "LeftUpperArm"
		ClassDress.limb_guard(b, ua, la, [0.048, 0.046, 0.042, 0.04], 0.1, 1.02, black, null, 12)
		ClassDress.limb_guard(b, la, hd, [0.045, 0.046], 0.55, 0.6, glow, null, 12)
		var ll := "RightLowerLeg" if side < 0 else "LeftLowerLeg"
		var ft := "RightFoot" if side < 0 else "LeftFoot"
		ClassDress.limb_guard(b, ll, ft, [0.07, 0.066, 0.056, 0.05], -0.06, 0.94, black, green, 14)
		var kp := b.bone_pos(ll)
		var kg := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.035, -0.03), Vector2(0.035, -0.03), Vector2(0.04, 0.02), Vector2(0.0, 0.09), Vector2(-0.04, 0.02)]), 0.016, 0.004), bone)
		b.attach(ll, kg, Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.0, 0.058)))
		# black hose on the thighs
		var ul := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		ClassDress.limb_guard(b, ul, ll, [0.088, 0.08, 0.07, 0.064], 0.15, 1.0, black, null, 14)
	# --- split robe skirt riding the legs (plum outer, black inner), green-edged
	var bot := foot.y + 0.18
	for side: float in [-1.0, 1.0]:
		var leg := "RightUpperLeg" if side < 0 else "LeftUpperLeg"
		ClassDress.coat_panel(b, leg, side, false, plum, green, bot, 150.0, 40.0, 0.5)
		ClassDress.coat_panel(b, leg, side, false, black, green, bot + 0.06, 150.0, 92.0, 0.45)
	# --- belt with a skull buckle; the cursed tome on a chain at the right hip
	L.shell(b, "Hips", hips, [Vector2(0.158, -0.01), Vector2(0.162, 0.04)], AnimeGear.toon(Color("#2A1A14")), 0.84)
	var bk := _skull(0.7, bone, glow)
	b.attach("Hips", bk, Transform3D(Basis(), hips + Vector3(0, 0.02, 0.15)))
	var tome := Node3D.new()
	tome.name = "CursedTome"
	AnimeGear.mi(AnimeGear.box(Vector3(0.16, 0.2, 0.05)), plum, tome)
	AnimeGear.mi(AnimeGear.box(Vector3(0.15, 0.19, 0.04)), AnimeGear.toon(Color("#DCD2B4")), tome, Transform3D(Basis(), Vector3(0.012, 0, 0)))
	AnimeGear.mi(AnimeGear.box(Vector3(0.02, 0.21, 0.055)), silver, tome, Transform3D(Basis(), Vector3(-0.08, 0, 0)))
	for c: Vector2 in [Vector2(0.07, 0.09), Vector2(0.07, -0.09)]:
		AnimeGear.mi(AnimeGear.box(Vector3(0.03, 0.03, 0.056)), silver, tome, Transform3D(Basis(), Vector3(c.x, c.y, 0)))
	# glowing rune eye on the cover
	AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.045, 0.028), 0.006), glow, tome, Transform3D(Basis(), Vector3(0.0, 0.0, 0.027)))
	AnimeGear.mi(AnimeGear.sphere(0.012, 8), AnimeGear.toon(Color("#0A120A"), {"outline": false}), tome, Transform3D(Basis(), Vector3(0.0, 0.0, 0.03)))
	b.attach("Hips", tome, Transform3D(Basis(Vector3.UP, -1.35) * Basis(Vector3.FORWARD, 0.15), hips + Vector3(-0.2, -0.16, 0.02)))
	var chain: Array = []
	for i in 6:
		var t := float(i) / 5.0
		chain.append(hips + Vector3(lerpf(-0.13, -0.2, t), lerpf(0.0, -0.06, t) - sin(t * PI) * 0.03, lerpf(0.09, 0.03, t)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.tube(chain, 0.007, 6), silver), Transform3D.IDENTITY)
	# --- hero element: long tattered cloak, four strips of uneven length, black with a toxic-green lining
	var cols := [["UpperChest", 0.16, 0.0], ["Hips", 0.2, -0.03], ["RightUpperLeg", 0.13, -0.15], ["LeftUpperLeg", 0.13, -0.15], ["RightLowerLeg", 0.12, -0.05], ["LeftLowerLeg", 0.12, -0.05]]
	var lining := AnimeGear.toon(Color("#2E7A2A"), {"shade": Color(0.55, 0.65, 0.85), "rim": TOXIC})
	var strips := [[-0.1, 1.15, 0.13], [-0.035, 1.38, 0.14], [0.035, 1.22, 0.14], [0.1, 1.42, 0.13]]
	for st: Array in strips:
		var x: float = st[0]
		ClassDress.cloth(b, "UpperChest", Transform3D(Basis(), uc + Vector3(x, 0.1, -0.12)), {
			"name": "CloakStrip", "length": float(st[1]), "segments": 12, "width": [float(st[2]), float(st[2]) * 1.25, float(st[2]) * 1.2, float(st[2]) * 0.7, 0.015],
			"dir": Vector3(x * 0.8, -1.0, -0.2), "side": Vector3(1, 0, 0), "material": black, "lining": lining, "thickness": 0.012,
			"stiffness": 0.03, "stiffness_tip": 0.004, "gravity": 8.5, "drag": 0.07, "wind": Vector3(x * 2.0, 0.0, -0.6), "colliders": cols})
	# cloak clasps: two small bone skulls on the collar bones
	for side: float in [-1.0, 1.0]:
		b.attach("UpperChest", _skull(0.45, bone, glow), Transform3D(Basis(), uc + Vector3(side * 0.12, 0.1, 0.06)))
