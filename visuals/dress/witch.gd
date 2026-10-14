extends RefCounted
## Witch 魔道学者 (王不留行 type), bible 2.5: tall crowned witch hat, floor-trailing royal-blue robe with gold
## flame trim, mantle, silver hair; 灭绝星尘 broom (WeaponFactory "broom").

const WITCH_BLUE := Color("#23379A")


static func dress() -> Dictionary:
	return {
		"base": "hairsample_male",
		"height": 1.84,
		"proportions": [1.04, 0.95],
		"rim": Color(0.75, 0.85, 1.0),
		# the HairSample_Male hoodie hood never shows under the costume: cull it (character space, relative to Neck)
		"cull": [{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.22, -0.16, -0.3), "max": Vector3(0.22, 0.2, -0.11)},
			{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.25, -0.06, -0.35), "max": Vector3(0.25, 0.35, 0.03)}],
		"face": {"blink": 0.25},
		"dress": {
			"Tops": {"map": [Color("#080C2C"), Color("#182878"), Color("#33479E")], "contrast": 1.2},
			"Bottoms": {"map": [Color("#0A0D24"), Color("#161C44"), Color("#3A4580")], "contrast": 1.2},
			"Shoes": {"map": [Color("#120C08"), Color("#3B2416"), Color("#9A7440")]},
			"HAIR": {"map": [Color("#6A7488"), Color("#C2CAD8"), Color("#F4F8FF")], "contrast": 1.15, "line": 1.7, "shade": Color(0.78, 0.78, 0.88)},
			"EyeIris": {"iris": Color(0.8, 0.85, 1.2)},
		},
		"anims": {&"idle": ["Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"], &"channel": ["Levitate Idle"]},
		"grips": {"broom": {"kind": "pole", "tilt": 15.0, "yaw": 75.0}},
	}


static func build(b: AnimeBody) -> void:
	var robe := AnimeGear.toon(WITCH_BLUE, {"shade": Color(0.5, 0.5, 0.9)})
	var robe_in := AnimeGear.toon(Color("#121A4A"), {"shade": Color(0.6, 0.6, 0.9)})
	var gold := AnimeGear.gold()
	var hips := b.bone_pos("Hips")
	var head := b.bone_pos("Head")
	# floor-length robe: open-front bell (the slit lets the legs read when stepping)
	var prof := [Vector2(0.37, -hips.y + 0.07), Vector2(0.31, -0.75), Vector2(0.23, -0.35), Vector2(0.175, -0.05), Vector2(0.16, 0.06)]
	var bell := AnimeGear.mi(AnimeGear.lathe(prof, 28, 1.0, 0.9, TAU * 0.86), robe)
	bell.rotation.y = PI * 0.5 + TAU * 0.07
	b.attach("Hips", ClassDress.wrap(bell), Transform3D(Basis(), hips))
	var hem := AnimeGear.mi(AnimeGear.lathe([Vector2(0.372, -hips.y + 0.07), Vector2(0.36, -hips.y + 0.13)], 28, 1.0, 0.9, TAU * 0.86), gold)
	hem.rotation.y = bell.rotation.y
	b.attach("Hips", ClassDress.wrap(hem), Transform3D(Basis(), hips))
	# gold flame tongues along the hem
	for k in 11:
		var a := TAU * 0.07 + PI * 0.5 + TAU * 0.86 * (k + 0.5) / 11.0
		var fl := AnimeGear.mi(AnimeGear.extrude(ClassDress.flame(), 0.008, 0.0), gold)
		var p := Vector3(cos(a) * 0.37, -hips.y + 0.13, -sin(a) * 0.37 * 0.9)
		b.attach("Hips", fl, Transform3D(Basis(Vector3.UP, a + PI * 0.5), hips + p))
	# mantle with gold rim
	var neck := b.bone_pos("Neck")
	var mantle := AnimeGear.mi(AnimeGear.lathe([Vector2(0.29, -0.2), Vector2(0.25, -0.1), Vector2(0.16, 0.0), Vector2(0.1, 0.05)], 24, 1.0, 0.75, TAU * 0.8), robe_in)
	mantle.rotation.y = PI * 0.5 + TAU * 0.1
	b.attach("UpperChest", ClassDress.wrap(mantle), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	var mrim := AnimeGear.mi(AnimeGear.lathe([Vector2(0.295, -0.215), Vector2(0.285, -0.18)], 24, 1.0, 0.75, TAU * 0.8), gold)
	mrim.rotation.y = mantle.rotation.y
	b.attach("UpperChest", ClassDress.wrap(mrim), Transform3D(Basis(), neck + Vector3(0, -0.04, -0.01)))
	# crowned witch hat with a bent tip
	var hat := Node3D.new()
	hat.name = "WitchHat"
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.3, -0.008), Vector2(0.24, 0.012), Vector2(0.12, 0.03)], 32), robe, hat)
	var cone_pts: Array = []
	var cone_r: Array = []
	for i in 10:
		var t := float(i) / 9.0
		cone_pts.append(Vector3(0, t * 0.48, -t * t * 0.2))
		cone_r.append(lerpf(0.125, 0.008, pow(t, 0.85)))
	AnimeGear.mi(AnimeGear.tube(cone_pts, cone_r, 18), robe, hat)
	AnimeGear.mi(AnimeGear.lathe([Vector2(0.128, 0.0), Vector2(0.124, 0.05)], 24), gold, hat)
	for k in 7:
		var a := TAU * k / 7.0
		var spike := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0, 0.075)]), 0.01), gold, hat)
		spike.transform = Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.124, 0.045, cos(a) * 0.124))
	var hgem := AnimeGear.mi(AnimeGear.sphere(0.02, 12), AnimeGear.toon(Color("#6C7BFF"), {"emit": Color("#6C7BFF") * 1.2, "outline": false}), hat)
	hgem.position = Vector3(0, 0.025, 0.13)
	b.attach("Head", hat, Transform3D(Basis(Vector3.RIGHT, -0.12), head + Vector3(0, 0.155, -0.01)))
