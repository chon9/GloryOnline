class_name WeaponFactory
extends RefCounted
## Builds weapon nodes for CharacterVisual (ARCHITECTURE §7.2), restyled for the anime art bible (2.6):
## real silhouettes (extruded blade profiles, lathed shafts and barrels), the same toon + outline materials as
## the characters, and HDR emissive accents that bloom. Weapons are 35-60% oversized and carry the brightest
## values on the model.
##
## Grip convention (unchanged contract, every id):
## - Node origin = the point held in the fist.
## - Blades, shafts and hafts extend along +Y (pommel / butt a little into -Y).
## - Firearms: muzzle along +X, sights up along +Y (built along +Y with -Z up, then wrapped in an "Aim" pivot).
## - Fist weapons (gloves, claws, tonfa): knuckles / aim along +X, back of the hand +Y.
## - Units: metres, authored for a ~1.75 m anime body (meta "units" = "m"). KayKit mob weapons keep KayKit units
##   (meta "units" = "kaykit"); CharacterVisual compensates when a weapon goes on the other kind of rig.
## - meta "grip_kind": blade | pole | gun | fist | shield | held | hip; meta "two_hand" for lance-type weapons.
## `tint` colours the energy accents (team / kit colour); Color.WHITE keeps the bible's signature colours.

const KAYKIT: Dictionary = {
	# mobs / bosses / summons (KayKit meshes, toon-shaded at build time)
	"skeleton_blade": "res://assets/weapons/special/Skeleton_Blade/Skeleton_Blade.gltf",
	"skeleton_axe": "res://assets/weapons/special/Skeleton_Axe/Skeleton_Axe.gltf",
	"skeleton_dagger": "res://assets/weapons/special/Skeleton_Dagger/Skeleton_Dagger.gltf",
	"skeleton_staff": "res://assets/weapons/special/Skeleton_Staff/Skeleton_Staff.gltf",
	"skeleton_crossbow": "res://assets/weapons/special/Skeleton_Crossbow/Skeleton_Crossbow.gltf",
	"skeleton_shield": "res://assets/weapons/special/Skeleton_Shield_Small_A/Skeleton_Shield_Small_A.gltf",
	"skeleton_shield_large": "res://assets/weapons/special/Skeleton_Shield_Large_A/Skeleton_Shield_Large_A.gltf",
	"skeleton_scythe": "res://assets/weapons/special/Skeleton_Scythe/Skeleton_Scythe.gltf",
	"orc_axe": "res://assets/weapons/fantasy/axe_A.gltf",
	"orc_axe_large": "res://assets/weapons/special/Orc_Axe_Large/Orc_Axe_Large.gltf",
	"black_knight_sword": "res://assets/weapons/special/BlackKnight_Sword_Large/BlackKnight_Sword_Large.gltf",
	"black_knight_shield": "res://assets/weapons/special/BlackKnight_Shield_Large/BlackKnight_Shield_Large.gltf",
	"frost_golem_axe": "res://assets/weapons/special/FrostGolem_Axe_Large/FrostGolem_Axe_Large.gltf",
	"skeleton_golem_axe": "res://assets/weapons/special/Skeleton_Golem_Axe_Large/Skeleton_Golem_Axe_Large.gltf",
	"skeleton_mace_large": "res://assets/weapons/special/Skeleton_Mace_Large/Skeleton_Mace_Large.gltf",
	"monstrosity_pitchfork": "res://assets/weapons/special/Monstrosity_Pitchfork_Large/Monstrosity_Pitchfork_Large.gltf",
	"great_axe_large": "res://assets/weapons/adv/axe_2handed_Large.gltf",
	"crossbow": "res://assets/weapons/adv/crossbow_1handed.gltf",
	"wand": "res://assets/weapons/fantasy/wand_A.gltf",
	"spellbook": "res://assets/weapons/adv/spellbook_open.gltf",
	"magic_wand": "res://assets/weapons/special/MagicalGirl_Wand/MagicalGirl_Wand.gltf",
}

## KayKit-rig only: pole weapons tilted (degrees about the handslot Z axis) so heads read "up" in KayKit poses.
const POLE_TILT: Dictionary = {"staff": 45.0, "staff_ring": 45.0, "cane": 45.0, "umbrella_open": 35.0, "umbrella": 20.0, "cross": 60.0,
	"skeleton_staff": 45.0, "magic_wand": 30.0, "wand": 30.0}

## Ids built as firearms (muzzle along +X).
const FIREARMS: Array[String] = ["revolver", "pistol", "auto_pistol", "hand_cannon", "rifle", "umbrella_gun", "crossbow", "skeleton_crossbow"]

const WEAPON_TYPES: Array[String] = ["lightsaber", "greatsword", "short_sword", "tachi", "battle_lance", "staff", "staff_ring",
	"broom", "revolver", "auto_pistol", "hand_cannon", "rifle", "gloves", "gloves_qi", "tonfa", "claws", "dual_swords",
	"ninjato", "dagger", "cane", "knight_sword", "war_scythe", "cross", "great_axe", "umbrella"]
const OFFHAND_TYPES: Array[String] = ["shield", "grenade", "mech_box", "pistol", "dagger", "sword"]
## Forms of the Myriad Manifestation Umbrella (千机伞) for set_weapon() form switches:
## "umbrella" = folded (lance / sword form, default), "umbrella_open" = canopy open (shield form),
## "umbrella_gun" = folded with a 6-barrel gatling hub (gun form).
const UMBRELLA_FORMS: Array[String] = ["umbrella", "umbrella_open", "umbrella_gun"]

const GRIP_KIND: Dictionary = {
	"lightsaber": "blade", "greatsword": "blade", "short_sword": "blade", "tachi": "blade", "dual_swords": "blade",
	"ninjato": "blade", "dagger": "blade", "knight_sword": "blade", "sword": "blade",
	"battle_lance": "pole", "staff": "pole", "staff_ring": "pole", "broom": "pole", "cane": "pole", "war_scythe": "pole",
	"cross": "pole", "great_axe": "pole", "umbrella": "pole", "umbrella_open": "pole",
	"revolver": "gun", "pistol": "gun", "auto_pistol": "gun", "hand_cannon": "gun", "rifle": "gun", "umbrella_gun": "gun",
	"gloves": "fist", "gloves_left": "fist", "gloves_qi": "fist", "tonfa": "fist", "claws": "fist",
	"shield": "shield", "grenade": "held", "mech_box": "hip",
}
const TWO_HAND: Array[String] = ["battle_lance", "umbrella", "war_scythe", "great_axe"]

const BLACK := Color("#121216")
const STEEL := Color("#D5DCE6")
const GOLD := Color("#D8B25A")
const RED := Color("#E0232E")
const BRASS := Color("#A87A34")
const GUNMETAL := Color("#4A525C")
const BONE := Color("#CBB89A")

static var _scenes: Dictionary = {}
static var _toon_cache: Dictionary = {}


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(WEAPON_TYPES)
	for o in OFFHAND_TYPES:
		if not o in out:
			out.append(o)
	out.append_array(["umbrella_open", "umbrella_gun", "gloves_left"])
	for k in KAYKIT.keys():
		if not k in out:
			out.append(k)
	return out


## Which id the left hand gets for weapons wielded as a pair.
static func left_variant(weapon_type: String) -> String:
	match weapon_type:
		"gloves":
			return "gloves_left"
		"revolver":
			return "pistol"
		_:
			return weapon_type


static func grip_kind(weapon_type: String) -> String:
	if GRIP_KIND.has(weapon_type):
		return GRIP_KIND[weapon_type]
	if weapon_type in FIREARMS:
		return "gun"
	return "blade"


static func build(weapon_type: String, tint := Color.WHITE) -> Node3D:
	var outer := Node3D.new()
	outer.name = "Weapon_" + weapon_type
	outer.set_meta("units", "m")
	outer.set_meta("grip_kind", grip_kind(weapon_type))
	outer.set_meta("two_hand", weapon_type in TWO_HAND)
	var root := outer
	if weapon_type in FIREARMS:
		# guns are modelled barrel along +Y, "up" along -Z; the pivot turns that into muzzle +X, up +Y
		root = Node3D.new()
		root.name = "Aim"
		root.basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
		outer.add_child(root)
	var acc := tint if tint != Color.WHITE else Color(0, 0, 0, 0)
	match weapon_type:
		"lightsaber":
			_lightsaber(root, acc)
		"greatsword":
			_greatsword(root, acc)
		"short_sword":
			_short_sword(root, acc)
		"tachi":
			_tachi(root, acc)
		"battle_lance":
			_lance(root, acc)
		"staff":
			_staff(root, acc)
		"staff_ring":
			_staff_ring(root, acc)
		"broom":
			_broom(root, acc)
		"revolver", "pistol":
			_revolver(root, acc, weapon_type == "pistol")
		"auto_pistol":
			_auto_pistol(root, acc)
		"hand_cannon":
			_cannon(root, acc)
		"rifle":
			_rifle(root, acc)
		"gloves", "gloves_left":
			_gloves(root, acc)
		"gloves_qi":
			_gloves_qi(root, acc)
		"tonfa":
			_tonfa(root, acc)
		"claws":
			_claws(root, acc)
		"dual_swords":
			_dual_sword(root, acc)
		"ninjato":
			_ninjato(root, acc)
		"dagger":
			_dagger(root, acc)
		"cane":
			_cane(root, acc)
		"knight_sword", "sword":
			_knight_sword(root, acc)
		"war_scythe":
			_scythe(root, acc)
		"cross":
			_cross(root, acc)
		"great_axe":
			_great_axe(root, acc)
		"umbrella", "umbrella_closed":
			_umbrella(root, acc, "folded")
		"umbrella_open":
			_umbrella(root, acc, "open")
		"umbrella_gun":
			_umbrella(root, acc, "gun")
		"shield":
			_shield(root, acc)
		"grenade":
			_grenade(root, acc)
		"mech_box":
			_mech_box(root, acc)
		_:
			if KAYKIT.has(weapon_type):
				outer.set_meta("units", "kaykit")
				_kaykit(root, KAYKIT[weapon_type])
			else:
				push_warning("WeaponFactory: unknown weapon type '%s', using knight_sword" % weapon_type)
				_knight_sword(root, acc)
	if String(outer.get_meta("units")) == "m":
		AnimeGear.merge_static(outer)
	for mi in outer.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name in [&"Merged", &"MergedFx"]:
			continue
		var mat := m.material_override
		var additive := mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if additive else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return outer


static func _c(acc: Color, fallback: Color) -> Color:
	return fallback if acc.a <= 0.0 else acc


# ------------------------------------------------------------------------------------------ material shortcuts

static func _t(col: Color, opts := {}) -> ShaderMaterial:
	return AnimeGear.toon(col, opts)


static func _dark() -> ShaderMaterial:
	return AnimeGear.toon(BLACK, {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.8, 0.85, 1.0), "rim_strength": 0.9})


static func _glow(col: Color, e := 3.0, additive := false, alpha := 1.0) -> StandardMaterial3D:
	return AnimeGear.glow(col, e, additive, alpha)


static func _m(parent: Node3D, mesh: Mesh, mat: Material, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	return AnimeGear.mi(mesh, mat, parent, xf)


static func _at(p: Vector3, b := Basis()) -> Transform3D:
	return Transform3D(b, p)


## Flat blade outline (x across, y along) extruded along Z.
static func _blade(parent: Node3D, poly: PackedVector2Array, depth: float, mat: Material, xf := Transform3D.IDENTITY, bevel := 0.006) -> MeshInstance3D:
	return _m(parent, AnimeGear.extrude(poly, depth, bevel), mat, xf)


static func _grip(parent: Node3D, y0: float, y1: float, r: float, wrap: Color) -> void:
	_m(parent, AnimeGear.cyl(r, r * 1.05, y1 - y0, 10), _t(wrap), _at(Vector3(0, (y0 + y1) * 0.5, 0)))
	var n := int((y1 - y0) / 0.045)
	for i in n:
		_m(parent, AnimeGear.cyl(r * 1.18, r * 1.18, 0.012, 10), _t(wrap.darkened(0.35)), _at(Vector3(0, y0 + 0.02 + i * 0.045, 0)))


# ------------------------------------------------------------------------------------------ swords

## 冰雨 Ice Rain: slim hilt with gold guard wings, translucent ice-cyan energy blade with a solid core.
static func _lightsaber(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#7FE8FF"))
	var halo := Color("#2F9BFF") if acc.a <= 0.0 else acc.darkened(0.2)
	var steel := AnimeGear.steel()
	var gold := AnimeGear.gold()
	_grip(r, -0.13, 0.1, 0.024, Color("#1E2A4A"))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.2), Vector2(0.03, -0.18), Vector2(0.034, -0.15), Vector2(0.026, -0.13)], 12), gold)
	# guard: swept gold wings
	var wing := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.01), Vector2(0.16, 0.07), Vector2(0.12, 0.02), Vector2(0.06, -0.02), Vector2(0.0, -0.025)])
	for s: float in [-1.0, 1.0]:
		var w := PackedVector2Array()
		for p in wing:
			w.append(Vector2(p.x * s, p.y))
		_blade(r, w, 0.022, gold, _at(Vector3(0, 0.12, 0)), 0.004)
	_m(r, AnimeGear.cyl(0.034, 0.03, 0.06, 12), steel, _at(Vector3(0, 0.13, 0)))
	_m(r, AnimeGear.sphere(0.022, 12), _glow(col, 4.0), _at(Vector3(0, 0.12, 0.03)))
	# energy blade: core + translucent halo, leaf-shaped (wider mid, needle tip)
	var core := [Vector2(0.012, 0.16), Vector2(0.018, 0.4), Vector2(0.016, 0.85), Vector2(0.01, 1.08), Vector2(0.0, 1.16)]
	_m(r, AnimeGear.lathe(core, 10, 1.0, 0.45), _glow(Color.WHITE.lerp(col, 0.35), 5.0))
	var hal := [Vector2(0.03, 0.15), Vector2(0.045, 0.42), Vector2(0.04, 0.88), Vector2(0.024, 1.1), Vector2(0.0, 1.22)]
	_m(r, AnimeGear.lathe(hal, 12, 1.0, 0.5), _glow(col, 2.2, true, 0.55))
	_m(r, AnimeGear.lathe([Vector2(0.06, 0.15), Vector2(0.075, 0.45), Vector2(0.06, 0.9), Vector2(0.0, 1.28)], 12, 1.0, 0.55), _glow(halo, 1.2, true, 0.25))


## Berserker greatsword: huge crimson-black blade with a bronze guard and a broken notch.
static func _greatsword(r: Node3D, acc: Color) -> void:
	var steel := AnimeGear.steel(Color("#C6CCD6"))
	var dark := _t(Color("#2A1416"), {"shade": Color(0.6, 0.5, 0.8)})
	var bronze := _t(Color("#B07A3A"), {"shade": Color("#6A3A1A") / Color("#B07A3A"), "rim": GOLD.lightened(0.4)})
	_grip(r, -0.32, 0.08, 0.03, Color("#3A1A14"))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.42), Vector2(0.045, -0.39), Vector2(0.05, -0.35), Vector2(0.035, -0.32)], 10), bronze)
	_blade(r, PackedVector2Array([Vector2(-0.2, 0.08), Vector2(0.2, 0.08), Vector2(0.26, 0.14), Vector2(0.1, 0.17), Vector2(-0.1, 0.17), Vector2(-0.26, 0.14)]), 0.07, bronze, Transform3D.IDENTITY, 0.01)
	var b := PackedVector2Array([Vector2(-0.11, 0.17), Vector2(0.11, 0.17), Vector2(0.125, 0.6), Vector2(0.1, 0.66), Vector2(0.125, 0.72), Vector2(0.12, 1.2),
		Vector2(0.06, 1.42), Vector2(0.0, 1.52), Vector2(-0.12, 1.3), Vector2(-0.125, 0.4)])
	_blade(r, b, 0.035, steel, Transform3D.IDENTITY, 0.012)
	# dark blood fuller with an ember line
	_blade(r, PackedVector2Array([Vector2(-0.035, 0.22), Vector2(0.035, 0.22), Vector2(0.03, 1.2), Vector2(0.0, 1.3), Vector2(-0.03, 1.2)]), 0.04, dark, Transform3D.IDENTITY, 0.0)
	_blade(r, PackedVector2Array([Vector2(-0.006, 0.26), Vector2(0.006, 0.26), Vector2(0.004, 1.18), Vector2(-0.004, 1.18)]), 0.044, _glow(_c(acc, Color("#FF3A2A")), 3.0), Transform3D.IDENTITY, 0.0)


## Spellblade short sword: rune-etched blade, glowing magic circle at the hilt.
static func _short_sword(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#5FE6E0"))
	var steel := AnimeGear.steel()
	var gold := AnimeGear.gold()
	_grip(r, -0.12, 0.08, 0.022, Color("#147A82"))
	_m(r, AnimeGear.sphere(0.03, 10), gold, _at(Vector3(0, -0.14, 0)))
	_blade(r, PackedVector2Array([Vector2(-0.13, 0.08), Vector2(0.13, 0.08), Vector2(0.15, 0.115), Vector2(0.05, 0.12), Vector2(-0.05, 0.12), Vector2(-0.15, 0.115)]), 0.03, gold)
	_blade(r, PackedVector2Array([Vector2(-0.045, 0.12), Vector2(0.045, 0.12), Vector2(0.05, 0.62), Vector2(0.0, 0.8), Vector2(-0.05, 0.62)]), 0.02, steel)
	for i in 5:
		var y := 0.18 + i * 0.09
		_blade(r, AnimeGear.star_poly(0.016, 4, 0.35), 0.026, _glow(col, 3.0), _at(Vector3(0, y, 0)), 0.0)
	var ring := _m(r, AnimeGear.lathe([Vector2(0.1, -0.004), Vector2(0.11, 0.004)], 32), _glow(col, 2.5, true, 0.8), _at(Vector3(0, 0.1, 0)))
	ring.name = "RuneCircle"
	_m(r, AnimeGear.lathe([Vector2(0.07, -0.002), Vector2(0.074, 0.002)], 32), _glow(Color.WHITE.lerp(col, 0.5), 3.0, true, 0.8), _at(Vector3(0, 0.1, 0)))


## Ghostblade tachi: long curved blade with a violet ghost edge.
static func _tachi(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#B48CFF"))
	var steel := AnimeGear.steel(Color("#D8DCE8"))
	_grip(r, -0.26, 0.04, 0.022, Color("#2A1E3A"))
	_m(r, AnimeGear.cyl(0.075, 0.075, 0.016, 16), _t(Color("#3A2E1E")), _at(Vector3(0, 0.05, 0)))
	_m(r, AnimeGear.cyl(0.03, 0.03, 0.04, 10), AnimeGear.gold(), _at(Vector3(0, 0.08, 0)))
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var y := 0.08 + t * 1.0
		var cx := t * t * 0.11
		var w := lerpf(0.032, 0.022, t)
		edge.append(Vector2(cx + w, y))
		back.append(Vector2(cx - w * 0.9, y))
	var poly := PackedVector2Array()
	poly.append_array(edge)
	poly.append(Vector2(0.11 + 0.0, 1.13))
	back.reverse()
	poly.append_array(back)
	_blade(r, poly, 0.016, steel, Transform3D.IDENTITY, 0.004)
	var ghost := PackedVector2Array()
	for p in edge:
		ghost.append(p + Vector2(0.012, 0))
	var inner := PackedVector2Array()
	for i in range(edge.size() - 1, -1, -1):
		inner.append(edge[i] + Vector2(-0.006, 0))
	ghost.append_array(inner)
	_blade(r, ghost, 0.022, _glow(col, 2.5, true, 0.7), Transform3D.IDENTITY, 0.0)


static func _dual_sword(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#E04060"))
	_grip(r, -0.1, 0.05, 0.02, Color("#2A1A20"))
	_blade(r, PackedVector2Array([Vector2(-0.07, 0.05), Vector2(0.07, 0.05), Vector2(0.04, 0.08), Vector2(-0.04, 0.08)]), 0.03, AnimeGear.gold())
	var poly := PackedVector2Array([Vector2(-0.025, 0.08), Vector2(0.028, 0.08), Vector2(0.05, 0.36), Vector2(0.06, 0.55), Vector2(0.0, 0.7), Vector2(-0.02, 0.4)])
	_blade(r, poly, 0.014, AnimeGear.steel(), Transform3D.IDENTITY, 0.004)
	_blade(r, PackedVector2Array([Vector2(-0.004, 0.12), Vector2(0.006, 0.12), Vector2(0.03, 0.5), Vector2(0.02, 0.5)]), 0.018, _glow(col, 2.6), Transform3D.IDENTITY, 0.0)


static func _ninjato(r: Node3D, acc: Color) -> void:
	_grip(r, -0.22, 0.04, 0.022, Color("#1A2448"))
	_blade(r, PackedVector2Array([Vector2(-0.07, 0.04), Vector2(0.07, 0.04), Vector2(0.07, 0.065), Vector2(-0.07, 0.065)]), 0.07, _dark(), Transform3D.IDENTITY, 0.004)
	_blade(r, PackedVector2Array([Vector2(-0.024, 0.065), Vector2(0.024, 0.065), Vector2(0.024, 0.9), Vector2(-0.024, 0.98)]), 0.012, AnimeGear.steel(), Transform3D.IDENTITY, 0.004)
	_blade(r, PackedVector2Array([Vector2(0.016, 0.1), Vector2(0.024, 0.1), Vector2(0.024, 0.88), Vector2(0.016, 0.88)]), 0.016, _glow(_c(acc, Color("#C8202A")), 2.5), Transform3D.IDENTITY, 0.0)
	# crimson tassel
	var tp: Array = []
	for i in 6:
		var t := float(i) / 5.0
		tp.append(Vector3(0.02, -0.24 - t * 0.2, sin(t * 2.5) * 0.03))
	_m(r, AnimeGear.ribbon(tp, [0.03, 0.03, 0.026, 0.022, 0.018, 0.012], [Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD], 0.008), _t(Color("#C8202A")))


static func _dagger(r: Node3D, acc: Color) -> void:
	_grip(r, -0.1, 0.03, 0.02, Color("#3A2A18"))
	_blade(r, PackedVector2Array([Vector2(-0.07, 0.03), Vector2(0.07, 0.03), Vector2(0.09, 0.06), Vector2(-0.09, 0.06)]), 0.025, AnimeGear.gold())
	_blade(r, PackedVector2Array([Vector2(-0.03, 0.06), Vector2(0.03, 0.06), Vector2(0.035, 0.24), Vector2(0.0, 0.4), Vector2(-0.035, 0.24)]), 0.014, AnimeGear.steel())
	_blade(r, PackedVector2Array([Vector2(-0.004, 0.08), Vector2(0.004, 0.08), Vector2(0.003, 0.3), Vector2(-0.003, 0.3)]), 0.018, _glow(_c(acc, Color("#A0E070")), 2.2), Transform3D.IDENTITY, 0.0)


static func _knight_sword(r: Node3D, acc: Color) -> void:
	var gold := AnimeGear.gold()
	_grip(r, -0.15, 0.06, 0.024, Color("#1E2A4A"))
	_m(r, AnimeGear.sphere(0.036, 12), gold, _at(Vector3(0, -0.18, 0)))
	_blade(r, PackedVector2Array([Vector2(-0.2, 0.06), Vector2(-0.16, 0.09), Vector2(0.0, 0.1), Vector2(0.16, 0.09), Vector2(0.2, 0.06), Vector2(0.16, 0.05), Vector2(0.0, 0.06), Vector2(-0.16, 0.05)]), 0.035, gold)
	_m(r, AnimeGear.sphere(0.022, 10), _glow(_c(acc, Color("#3FA9FF")), 3.0), _at(Vector3(0, 0.075, 0.02)))
	_blade(r, PackedVector2Array([Vector2(-0.04, 0.1), Vector2(0.04, 0.1), Vector2(0.036, 0.88), Vector2(0.0, 1.0), Vector2(-0.036, 0.88)]), 0.018, AnimeGear.steel())
	_blade(r, PackedVector2Array([Vector2(-0.008, 0.12), Vector2(0.008, 0.12), Vector2(0.006, 0.82), Vector2(-0.006, 0.82)]), 0.022, _t(Color("#8A96AA")), Transform3D.IDENTITY, 0.0)


# ------------------------------------------------------------------------------------------ poles

## 却邪 battle lance (ported from lookdev LdWeapons.que_xie): held mid-shaft, head ~0.75 m above the fist.
static func _lance(root: Node3D, acc: Color) -> void:
	var body := Node3D.new()
	body.position = Vector3(0, -0.42, 0)
	root.add_child(body)
	var shaft := _dark()
	var steel := AnimeGear.steel()
	var gold := AnimeGear.gold()
	var gem := _c(acc, RED)
	_m(body, AnimeGear.cyl(0.022, 0.022, 1.8, 10), shaft, _at(Vector3(0, 0.33, 0)))
	for y: float in [-0.12, 0.2, 0.62, 1.12]:
		_m(body, AnimeGear.cyl(0.028, 0.028, 0.035, 10), gold, _at(Vector3(0, y, 0)))
	_m(body, AnimeGear.lathe([Vector2(0.0, -0.84), Vector2(0.02, -0.7), Vector2(0.034, -0.6), Vector2(0.026, -0.56)], 10), steel)
	_m(body, AnimeGear.cyl(0.036, 0.036, 0.03, 10), gold, _at(Vector3(0, -0.55, 0)))
	var head := Node3D.new()
	head.position = Vector3(0, 1.2, 0)
	head.scale = Vector3.ONE * 1.6
	body.add_child(head)
	var o := Vector3(0, -1.2, 0)
	_m(head, AnimeGear.lathe([Vector2(0.018, 1.18), Vector2(0.036, 1.24), Vector2(0.026, 1.28), Vector2(0.04, 1.3)], 12), shaft, _at(o))
	for k in 3:
		var a := TAU * k / 3.0 + PI / 6.0
		var claw := _m(head, AnimeGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.02, 0.0), Vector2(0.04, 0.05), Vector2(0.034, 0.1), Vector2(0.016, 0.135), Vector2(0.018, 0.09), Vector2(0.008, 0.05)]), 0.014), shaft)
		claw.transform = Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.022, 1.29, -sin(a) * 0.022) + o)
	var orb := _m(head, AnimeGear.sphere(0.04, 16), AnimeGear.toon(gem, {"emit": Color(gem.r, gem.g * 0.4, gem.b * 0.4) * 2.2, "rim": Color(1, 0.8, 0.8), "rim_strength": 1.2, "outline": false}))
	orb.position = Vector3(0, 1.35, 0) + o
	var halo := _m(head, AnimeGear.sphere(0.07, 12), _glow(gem.lightened(0.1), 1.6, true, 0.35))
	halo.position = orb.position
	var blade := PackedVector2Array([
		Vector2(-0.03, 1.39), Vector2(0.03, 1.39), Vector2(0.06, 1.43), Vector2(0.115, 1.40), Vector2(0.09, 1.47), Vector2(0.056, 1.50),
		Vector2(0.07, 1.55), Vector2(0.05, 1.57), Vector2(0.066, 1.62), Vector2(0.046, 1.64), Vector2(0.06, 1.69), Vector2(0.042, 1.71),
		Vector2(0.054, 1.76), Vector2(0.036, 1.78), Vector2(0.046, 1.83), Vector2(0.028, 1.86), Vector2(0.0, 2.06),
		Vector2(-0.03, 1.9), Vector2(-0.044, 1.78), Vector2(-0.048, 1.62), Vector2(-0.044, 1.48)])
	_m(head, AnimeGear.extrude(blade, 0.024, 0.008), steel, _at(o))
	var fuller := PackedVector2Array([Vector2(-0.007, 1.46), Vector2(0.007, 1.46), Vector2(0.004, 1.88), Vector2(-0.004, 1.88)])
	_m(head, AnimeGear.extrude(fuller, 0.028), _glow(gem.lightened(0.15), 3.5), _at(o))
	var tp: Array = []
	var tw: Array = []
	var ts: Array = []
	for i in 7:
		var t := float(i) / 6.0
		tp.append(Vector3(0.03 + t * 0.05, 1.16 - t * 0.34, sin(t * 3.0) * 0.03))
		tw.append(lerpf(0.05, 0.02, t))
		ts.append(Vector3(0, 0, 1))
	_m(body, AnimeGear.ribbon(tp, tw, ts, 0.01), _t(Color("#C8202A"), {"shade": Color(0.55, 0.3, 0.55)}))


## Elementalist staff: dark wood shaft, gold crescent cradle holding a glowing crystal.
static func _staff(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#FF8A1F"))
	var wood := _t(Color("#3A2418"), {"shade": Color(0.6, 0.55, 0.85)})
	var gold := AnimeGear.gold()
	_m(r, AnimeGear.cyl(0.02, 0.026, 1.75, 10), wood, _at(Vector3(0, 0.33, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.62), Vector2(0.03, -0.55), Vector2(0.024, -0.5)], 10), gold)
	for y: float in [0.9, 1.0]:
		_m(r, AnimeGear.cyl(0.032, 0.032, 0.03, 10), gold, _at(Vector3(0, y, 0)))
	var cres := PackedVector2Array()
	for i in 17:
		var a := lerpf(-0.35, PI + 0.35, float(i) / 16.0)
		cres.append(Vector2(cos(a) * 0.16, sin(a) * 0.16 + 0.04))
	for i in range(16, -1, -1):
		var a := lerpf(-0.2, PI + 0.2, float(i) / 16.0)
		cres.append(Vector2(cos(a) * 0.12, sin(a) * 0.1 + 0.07))
	for k in 2:
		_blade(r, cres, 0.024, gold, Transform3D(Basis(Vector3.UP, k * PI * 0.5) * Basis(Vector3.RIGHT, PI), Vector3(0, 1.32, 0)), 0.004)
	var crystal := _m(r, AnimeGear.lathe([Vector2(0.0, -0.11), Vector2(0.07, 0.0), Vector2(0.0, 0.14)], 6), _t(col.lightened(0.3), {"emit": col * 1.6, "outline": false, "rim": Color.WHITE}), _at(Vector3(0, 1.28, 0)))
	crystal.name = "Crystal"
	_m(r, AnimeGear.sphere(0.16, 12), _glow(col, 1.6, true, 0.3), _at(Vector3(0, 1.3, 0)))


## Summoner staff: a big gold ring with a hanging spirit orb and red cords.
static func _staff_ring(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#7CF0A0"))
	var wood := _t(Color("#2A3A2E"), {"shade": Color(0.6, 0.6, 0.85)})
	var gold := AnimeGear.gold()
	_m(r, AnimeGear.cyl(0.02, 0.024, 1.7, 10), wood, _at(Vector3(0, 0.3, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.6), Vector2(0.028, -0.54), Vector2(0.022, -0.5)], 10), gold)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.2
	ring.rings = 24
	ring.ring_segments = 8
	_m(r, ring, gold, _at(Vector3(0, 1.36, 0), Basis(Vector3.RIGHT, PI / 2)))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_blade(r, ClassDress.diamond(0.025, 0.04), 0.02, gold, _at(Vector3(cos(a) * 0.2, 1.36 + sin(a) * 0.2, 0), Basis(Vector3.FORWARD, a - PI / 2)))
	_m(r, AnimeGear.sphere(0.06, 14), _glow(Color.WHITE.lerp(col, 0.5), 3.5), _at(Vector3(0, 1.36, 0)))
	_m(r, AnimeGear.sphere(0.12, 12), _glow(col, 1.4, true, 0.35), _at(Vector3(0, 1.36, 0)))
	for s: float in [-1.0, 1.0]:
		var tp: Array = [Vector3(s * 0.04, 1.16, 0), Vector3(s * 0.06, 1.02, 0.01), Vector3(s * 0.07, 0.9, 0.0)]
		_m(r, AnimeGear.tube(tp, 0.008, 6), _t(Color("#C8202A")))
		_m(r, AnimeGear.sphere(0.022, 8), _t(Color("#C8202A")), _at(Vector3(s * 0.07, 0.88, 0)))


## 灭绝星尘 broom (ported from lookdev LdWeapons.star_broom).
static func _broom(root: Node3D, acc: Color) -> void:
	var star := _c(acc, Color("#6C7BFF"))
	var wood := _t(Color("#2A1A22"), {"shade": Color(0.6, 0.6, 0.9), "rim": Color(0.75, 0.8, 1.0)})
	var gold := AnimeGear.gold()
	_m(root, AnimeGear.cyl(0.018, 0.022, 1.7, 10), wood, _at(Vector3(0, 0.3, 0)))
	for y: float in [-0.5, 0.95, 1.1, 1.15]:
		_m(root, AnimeGear.cyl(0.03, 0.03, 0.03, 12), gold, _at(Vector3(0, y, 0)))
	_m(root, AnimeGear.lathe([Vector2(0.0, -0.62), Vector2(0.028, -0.56), Vector2(0.02, -0.52)], 10), gold)
	var fan := Node3D.new()
	fan.name = "StarFan"
	fan.position = Vector3(0, 1.16, 0)
	root.add_child(fan)
	var blade_mat := _glow(star, 2.6, true, 0.85)
	var core_mat := _glow(Color("#E8ECFF"), 4.0, true, 0.9)
	for k in 13:
		var a := lerpf(-0.55, 0.55, k / 12.0)
		var ln := 0.55 - absf(a) * 0.25
		var b := _m(fan, AnimeGear.extrude(PackedVector2Array([Vector2(-0.012, 0), Vector2(0.012, 0), Vector2(0.0, ln)]), 0.004), blade_mat)
		b.transform = Transform3D(Basis(Vector3.FORWARD, a) * Basis(Vector3.UP, k * 0.5), Vector3.ZERO)
		if k % 3 == 1:
			var cb := _m(fan, AnimeGear.extrude(PackedVector2Array([Vector2(-0.004, 0), Vector2(0.004, 0), Vector2(0.0, ln * 0.7)]), 0.003), core_mat)
			cb.transform = b.transform
	var p := GPUParticles3D.new()
	p.name = "StarDust"
	p.amount = 40
	p.lifetime = 1.6
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.gravity = Vector3(0, 0.15, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(star.r, star.g, star.b, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = AnimeGear.spark_tex()
	qm.emission_enabled = true
	qm.emission = star.lightened(0.3)
	qm.emission_energy_multiplier = 3.0
	q.material = qm
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.3, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fan.add_child(p)


## Warlock cane: crooked black cane topped by a horned skull cage around a toxic-green flame.
static func _cane(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#7CFF6B"))
	var dark := _dark()
	var bone := _t(BONE, {"shade": Color(0.7, 0.62, 0.75)})
	var pts: Array = []
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(sin(t * 7.0) * 0.012, lerpf(-0.6, 1.0, t), 0))
	_m(r, AnimeGear.tube(pts, 0.02, 8), dark)
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.66), Vector2(0.022, -0.6)], 8), AnimeGear.steel())
	var skull := _m(r, AnimeGear.sphere(0.07, 12), bone, _at(Vector3(0, 1.1, 0)))
	skull.scale = Vector3(1, 1.1, 1.05)
	for s: float in [-1.0, 1.0]:
		var horn: Array = []
		var hr: Array = []
		for i in 6:
			var t := float(i) / 5.0
			horn.append(Vector3(s * (0.05 + t * 0.09), 1.14 + sin(t * 2.4) * 0.09, -t * 0.03))
			hr.append(lerpf(0.022, 0.003, t))
		_m(r, AnimeGear.tube(horn, hr, 8), dark)
		_m(r, AnimeGear.sphere(0.014, 8), _glow(col, 4.0), _at(Vector3(s * 0.025, 1.11, 0.058)))
	_m(r, AnimeGear.sphere(0.13, 12), _glow(col, 1.3, true, 0.3), _at(Vector3(0, 1.12, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, 1.17), Vector2(0.035, 1.22), Vector2(0.0, 1.38)], 8), _glow(col, 3.0, true, 0.75))


## Exorcist war scythe: long black shaft, crescent blade with a red edge, paper talismans.
static func _scythe(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#E0323C"))
	var dark := _dark()
	_m(r, AnimeGear.cyl(0.022, 0.022, 2.0, 10), dark, _at(Vector3(0, 0.35, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.72), Vector2(0.03, -0.64)], 8), AnimeGear.steel())
	for y: float in [0.5, 1.3, 1.35]:
		_m(r, AnimeGear.cyl(0.03, 0.03, 0.03, 10), AnimeGear.steel(Color("#9AA6B8")), _at(Vector3(0, y, 0)))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		outer.append(Vector2(-0.82 * t, 1.3 + 0.28 * sin(PI * t * 0.92) - 0.34 * t * t))
		inner.append(Vector2(-0.74 * t, 1.2 + 0.13 * sin(PI * t) - 0.2 * t * t))
	inner.reverse()
	var poly := PackedVector2Array()
	poly.append_array(outer)
	poly.append_array(inner.slice(1))
	_blade(r, poly, 0.02, AnimeGear.steel(), Transform3D.IDENTITY, 0.004)
	var ln := PackedVector2Array()
	for i in outer.size():
		ln.append(outer[i])
	for i in range(outer.size() - 1, -1, -1):
		ln.append(outer[i] + Vector2(0.0, -0.028))
	_blade(r, ln, 0.026, _glow(col, 2.8), Transform3D.IDENTITY, 0.0)
	_m(r, AnimeGear.lathe([Vector2(0.03, 1.16), Vector2(0.045, 1.24), Vector2(0.03, 1.34), Vector2(0.0, 1.42)], 8), dark)
	var paper := _t(Color("#F2E6B0"), {"shade": Color(0.8, 0.7, 0.75)})
	for i in 3:
		_blade(r, PackedVector2Array([Vector2(-0.035, 0), Vector2(0.035, 0), Vector2(0.035, -0.17), Vector2(-0.035, -0.17)]), 0.004, paper, _at(Vector3(0.035, 1.26 - i * 0.04, 0.03 + i * 0.02), Basis(Vector3.UP, 0.4 * i)), 0.0)
		_blade(r, PackedVector2Array([Vector2(-0.01, -0.03), Vector2(0.01, -0.03), Vector2(0.01, -0.13), Vector2(-0.01, -0.13)]), 0.006, _t(Color("#B02020")), _at(Vector3(0.035, 1.26 - i * 0.04, 0.03 + i * 0.02), Basis(Vector3.UP, 0.4 * i)), 0.0)


## Cleric cross staff: white shaft, large gold-trimmed white cross with a radiant gem.
static func _cross(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#FFD86A"))
	var white := _t(Color("#F2F0EA"), {"shade": Color("#A9B3D6") / Color("#F2F0EA")})
	var gold := AnimeGear.gold()
	_m(r, AnimeGear.cyl(0.02, 0.024, 1.5, 10), white, _at(Vector3(0, 0.25, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.56), Vector2(0.03, -0.5)], 10), gold)
	var cross := PackedVector2Array([Vector2(-0.04, 0.95), Vector2(0.04, 0.95), Vector2(0.04, 1.18), Vector2(0.2, 1.18), Vector2(0.24, 1.22), Vector2(0.2, 1.26),
		Vector2(0.04, 1.26), Vector2(0.04, 1.44), Vector2(0.0, 1.5), Vector2(-0.04, 1.44), Vector2(-0.04, 1.26), Vector2(-0.2, 1.26), Vector2(-0.24, 1.22), Vector2(-0.2, 1.18), Vector2(-0.04, 1.18)])
	_blade(r, cross, 0.05, white, Transform3D.IDENTITY, 0.008)
	var rim := PackedVector2Array()
	for p in cross:
		rim.append(p)
	_blade(r, Geometry2D.offset_polygon(cross, 0.012)[0], 0.03, gold, Transform3D.IDENTITY, 0.0)
	_m(r, AnimeGear.sphere(0.04, 12), _glow(col, 4.0), _at(Vector3(0, 1.22, 0.03)))
	_m(r, AnimeGear.sphere(0.04, 12), _glow(col, 4.0), _at(Vector3(0, 1.22, -0.03)))
	var ray := _m(r, AnimeGear.extrude(AnimeGear.star_poly(0.16, 8, 0.25), 0.004), _glow(col, 2.0, true, 0.45), _at(Vector3(0, 1.22, 0)))
	ray.name = "Halo"


## Paladin great axe: double crescent bits in white steel with gold, a sky-blue gem.
static func _great_axe(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#7FC8FF"))
	var white := AnimeGear.steel(Color("#E8EEF6"))
	var gold := AnimeGear.gold()
	_m(r, AnimeGear.cyl(0.024, 0.026, 1.6, 10), _t(Color("#2A3A6A")), _at(Vector3(0, 0.3, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, -0.58), Vector2(0.036, -0.5)], 10), gold)
	for y: float in [0.6, 1.0]:
		_m(r, AnimeGear.cyl(0.032, 0.032, 0.03, 10), gold, _at(Vector3(0, y, 0)))
	for s: float in [-1.0, 1.0]:
		var bit := PackedVector2Array([Vector2(0.03, 0.92), Vector2(0.18, 0.84), Vector2(0.34, 0.76), Vector2(0.4, 0.98), Vector2(0.38, 1.2), Vector2(0.32, 1.38), Vector2(0.18, 1.24), Vector2(0.03, 1.18)])
		var p := PackedVector2Array()
		for v in bit:
			p.append(Vector2(v.x * s, v.y))
		if s < 0:
			p.reverse()
		_blade(r, p, 0.03, white, Transform3D.IDENTITY, 0.006)
		var e := PackedVector2Array()
		for v in [Vector2(0.38, 0.8), Vector2(0.42, 0.98), Vector2(0.4, 1.2), Vector2(0.34, 1.36), Vector2(0.32, 1.32), Vector2(0.37, 1.18), Vector2(0.38, 0.98), Vector2(0.35, 0.82)]:
			e.append(Vector2(v.x * s, v.y))
		if s < 0:
			e.reverse()
		_blade(r, e, 0.034, gold, Transform3D.IDENTITY, 0.0)
	_m(r, AnimeGear.sphere(0.05, 12), _glow(col, 3.5), _at(Vector3(0, 1.06, 0)))
	_m(r, AnimeGear.lathe([Vector2(0.0, 1.2), Vector2(0.03, 1.3), Vector2(0.0, 1.5)], 6), white)


## 千机伞 Myriad Manifestations Umbrella: 8 white canopy panels with dark rib lines, khaki mechanical shaft
## with claw guards and spikes, a glowing red seam. Forms: folded (giant faceted spear tip), open (shield),
## gun (6 dark barrels out of the canopy hub). Panels are separate meshes ("Panel_i") so forms can animate.
static func _umbrella(r: Node3D, acc: Color, form: String) -> void:
	var seam := _c(acc, RED)
	var khaki := _t(BONE, {"shade": Color(0.72, 0.62, 0.78), "rim": Color("#FFF4DC")})
	var white := _t(Color("#F2F2F4"), {"shade": Color("#A9B3D6") / Color("#F2F0EA"), "rim": Color.WHITE, "rim_strength": 0.8})
	var dark := _t(Color("#2A2A30"))
	var steel := AnimeGear.steel()
	var gun := form == "gun"
	var open := form == "open"
	# body is built along +Y; in gun form the whole thing is turned so the canopy points along the barrel
	var b := Node3D.new()
	b.name = "Umbrella"
	r.add_child(b)
	if gun:
		b.position = Vector3(0, -0.3, 0)
	# mechanical shaft
	_m(b, AnimeGear.cyl(0.024, 0.026, 1.05, 10), khaki, _at(Vector3(0, 0.2, 0)))
	_m(b, AnimeGear.lathe([Vector2(0.0, -0.5), Vector2(0.03, -0.44), Vector2(0.042, -0.36), Vector2(0.03, -0.3)], 10), khaki)
	for y: float in [-0.2, -0.05, 0.12]:
		_m(b, AnimeGear.cyl(0.032, 0.032, 0.025, 8), dark, _at(Vector3(0, y, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var claw := PackedVector2Array([Vector2(0, 0), Vector2(0.02, 0.0), Vector2(0.07, 0.07), Vector2(0.05, 0.11), Vector2(0.03, 0.06)])
		_blade(b, claw, 0.012, khaki, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.02, 0.18, -sin(a) * 0.02)), 0.0)
	# red energy seam along the shaft
	_blade(b, PackedVector2Array([Vector2(0.022, -0.3), Vector2(0.03, -0.3), Vector2(0.03, 0.8), Vector2(0.022, 0.8)]), 0.008, _glow(seam, 3.5), Transform3D.IDENTITY, 0.0)
	var hub_y := 0.72
	var tip_y := 1.62
	if open:
		# open canopy: 8 panels forming a shallow faceted dome facing +Y (the shield face)
		var R := 0.62
		for i in 8:
			var a0 := TAU * i / 8.0
			var a1 := TAU * (i + 1) / 8.0
			var poly := PackedVector2Array([Vector2(0, 0), Vector2(cos(a0) * R, sin(a0) * R), Vector2(cos(a1) * R, sin(a1) * R)])
			var pan := _blade(b, poly, 0.012, white, Transform3D(Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.FORWARD, 0.0), Vector3(0, 1.05, 0)), 0.0)
			pan.name = "Panel_%d" % i
			pan.transform = Transform3D(Basis(Vector3.UP, 0.0) * Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 1.05, 0))
			var mid := (a0 + a1) * 0.5
			pan.rotate_object_local(Vector3(sin(mid), -cos(mid), 0).normalized(), 0.42)
			var rib := _m(b, AnimeGear.box(Vector3(0.012, 0.012, R)), dark)
			rib.transform = Transform3D(Basis(Vector3.UP, -a0 + PI / 2) * Basis(Vector3.RIGHT, -0.42), Vector3(cos(a0) * R * 0.46, 1.05 - 0.13, -sin(a0) * R * 0.46))
		_m(b, AnimeGear.lathe([Vector2(0.0, 1.0), Vector2(0.06, 1.05), Vector2(0.0, 1.25)], 8), steel)
		var ring := _m(b, AnimeGear.lathe([Vector2(R * 0.98, 0.0), Vector2(R * 1.0, 0.012)], 32), _glow(seam, 2.5), _at(Vector3(0, 0.98, 0)))
		ring.name = "Seam"
		_m(b, AnimeGear.lathe([Vector2(0.64, -0.01), Vector2(0.66, 0.01)], 32), _glow(Color("#F2E6CF"), 1.2, true, 0.5), _at(Vector3(0, 0.99, 0)))
	else:
		# folded: 8 long triangular panels around the hub reading as a giant faceted spear tip
		for i in 8:
			var a := TAU * i / 8.0
			var w := 0.095
			var poly := PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(0.0, tip_y - hub_y)])
			var pan := _blade(b, poly, 0.01, white, Transform3D.IDENTITY, 0.0)
			pan.name = "Panel_%d" % i
			pan.transform = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.06), Vector3(sin(a) * 0.075, hub_y, cos(a) * 0.075))
			_m(b, AnimeGear.box(Vector3(0.006, tip_y - hub_y, 0.006)), dark, Transform3D(Basis(Vector3.UP, a + PI / 8.0) * Basis(Vector3.RIGHT, -0.065), Vector3(sin(a + PI / 8.0) * 0.08, hub_y + (tip_y - hub_y) * 0.5, cos(a + PI / 8.0) * 0.08)))
		_m(b, AnimeGear.cyl(0.085, 0.04, 0.09, 8), khaki, _at(Vector3(0, hub_y - 0.02, 0)))
		_m(b, AnimeGear.lathe([Vector2(0.0, tip_y - 0.05), Vector2(0.03, tip_y), Vector2(0.0, tip_y + 0.22)], 6), steel)
		_blade(b, PackedVector2Array([Vector2(-0.006, hub_y + 0.05), Vector2(0.006, hub_y + 0.05), Vector2(0.003, tip_y - 0.05), Vector2(-0.003, tip_y - 0.05)]), 0.17, _glow(seam, 3.0), Transform3D.IDENTITY, 0.0)
		if gun:
			# 6 dark barrels out of the hub, ringed by a brass collar ("Morph_" = grows out during the form change)
			var gb := Node3D.new()
			gb.name = "Morph_Barrels"
			gb.position = Vector3(0, tip_y - 0.25, 0)
			b.add_child(gb)
			var go := Vector3(0, -(tip_y - 0.25), 0)
			for k in 6:
				var a := TAU * k / 6.0
				_m(gb, AnimeGear.cyl(0.018, 0.018, 0.75, 8), _t(Color("#2A2A30")), _at(Vector3(cos(a) * 0.045, tip_y + 0.05, sin(a) * 0.045) + go))
			_m(gb, AnimeGear.cyl(0.08, 0.08, 0.05, 12), AnimeGear.gold(), _at(Vector3(0, tip_y - 0.25, 0) + go))
			_m(gb, AnimeGear.cyl(0.075, 0.075, 0.04, 12), _t(Color("#2A2A30")), _at(Vector3(0, tip_y + 0.42, 0) + go))
			_m(gb, AnimeGear.cyl(0.04, 0.04, 0.02, 10), _glow(seam, 3.5), _at(Vector3(0, tip_y + 0.44, 0) + go))
			# grip block under the shaft
			_m(r, AnimeGear.box(Vector3(0.05, 0.12, 0.14)), dark, _at(Vector3(0, -0.02, 0.06)))


# ------------------------------------------------------------------------------------------ firearms
# modelled barrel along +Y, sights / "up" along -Z (the Aim pivot maps this to muzzle +X, up +Y)

static func _revolver(r: Node3D, acc: Color, small: bool) -> void:
	var s := 1.25 if small else 1.45
	var metal := _t(Color("#3E444E"), {"shade": Color(0.6, 0.62, 0.86), "rim": Color.WHITE, "rim_strength": 0.9})
	var brass := _t(Color("#B9944A"), {"shade": Color("#8A5A2B") / Color("#B9944A"), "rim": GOLD_HI()})
	var wood := _t(Color("#5A3B28"), {"shade": Color(0.7, 0.55, 0.7)})
	var g := Node3D.new()
	g.scale = Vector3.ONE * s
	r.add_child(g)
	_m(g, AnimeGear.box(Vector3(0.05, 0.11, 0.2)), wood, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, -0.06, 0.06)))
	_m(g, AnimeGear.box(Vector3(0.055, 0.2, 0.07)), metal, _at(Vector3(0, 0.03, -0.02)))
	_m(g, AnimeGear.cyl(0.042, 0.042, 0.08, 6), brass, _at(Vector3(0, 0.07, -0.03)))
	_m(g, AnimeGear.cyl(0.018, 0.022, 0.42, 10), metal, _at(Vector3(0, 0.31, -0.04)))
	_m(g, AnimeGear.box(Vector3(0.012, 0.36, 0.02)), brass, _at(Vector3(0, 0.3, -0.065)))
	_m(g, AnimeGear.cyl(0.026, 0.026, 0.03, 10), brass, _at(Vector3(0, 0.5, -0.04)))
	_m(g, AnimeGear.box(Vector3(0.01, 0.03, 0.025)), metal, _at(Vector3(0, 0.49, -0.07)))
	_m(g, AnimeGear.lathe([Vector2(0.03, -0.004), Vector2(0.034, 0.004)], 12), metal, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0, -0.01, 0.0)))
	_m(g, AnimeGear.box(Vector3(0.008, 0.07, 0.008)), _glow(_c(acc, Color("#FFC43A")), 2.5), _at(Vector3(0.03, 0.07, -0.03)))


static func _auto_pistol(root: Node3D, acc: Color) -> void:
	var r := Node3D.new()
	r.scale = Vector3.ONE * 1.4
	root.add_child(r)
	var metal := _t(Color("#3A3F48"), {"shade": Color(0.6, 0.62, 0.86), "rim": Color.WHITE})
	var olive := _t(Color("#5B6235"))
	_m(r, AnimeGear.box(Vector3(0.05, 0.1, 0.17)), olive, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, -0.05, 0.06)))
	_m(r, AnimeGear.box(Vector3(0.06, 0.34, 0.07)), metal, _at(Vector3(0, 0.12, -0.03)))
	_m(r, AnimeGear.box(Vector3(0.045, 0.06, 0.16)), _t(Color("#1A1A1E")), _at(Vector3(0, 0.12, 0.08)))
	_m(r, AnimeGear.cyl(0.016, 0.016, 0.12, 8), metal, _at(Vector3(0, 0.33, -0.03)))
	_m(r, AnimeGear.box(Vector3(0.062, 0.26, 0.012)), _glow(_c(acc, Color("#FF8A1F")), 2.2), _at(Vector3(0, 0.13, -0.068)))


## Launcher hand cannon (ported from lookdev LdWeapons.launcher_cannon): brass barrel, hazard stripes,
## glowing yellow energy chamber, braided fuse.
static func _cannon(root: Node3D, acc: Color) -> void:
	var energy := _c(acc, Color("#FFE45A"))
	var brass := _t(BRASS, {"shade": Color(0.55, 0.42, 0.55), "rim": GOLD_HI(), "rim_strength": 0.9})
	var steel := _t(Color("#5A6270"), {"shade": Color(0.55, 0.58, 0.85)})
	var dark := _t(Color("#24242A"))
	var body := Node3D.new()
	body.position = Vector3(0, 0, -0.13)
	root.add_child(body)
	_m(body, AnimeGear.lathe([Vector2(0.0, -0.42), Vector2(0.09, -0.42), Vector2(0.125, -0.36), Vector2(0.13, -0.15), Vector2(0.105, -0.1),
		Vector2(0.1, 0.62), Vector2(0.115, 0.66), Vector2(0.15, 0.84), Vector2(0.162, 0.9), Vector2(0.13, 0.91), Vector2(0.08, 0.86)], 20), brass)
	_m(body, AnimeGear.cyl(0.075, 0.075, 0.02, 20), _t(Color("#120C08"), {"outline": false}), _at(Vector3(0, 0.875, 0)))
	for y: float in [0.05, 0.35, 0.6]:
		_m(body, AnimeGear.lathe([Vector2(0.108, y - 0.02), Vector2(0.116, y), Vector2(0.108, y + 0.02)], 20), steel)
	_m(body, AnimeGear.lathe([Vector2(0.104, 0.13), Vector2(0.104, 0.27)], 24), _t(Color.WHITE, {"tex": _stripe_tex(), "shade": Color(0.6, 0.6, 0.85)}))
	_m(body, AnimeGear.cyl(0.07, 0.07, 0.2, 16), _glow(energy, 4.0), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.24, -0.11)))
	for k in 5:
		var a := TAU * k / 5.0
		_m(body, AnimeGear.box(Vector3(0.012, 0.012, 0.21)), brass, _at(Vector3(cos(a) * 0.075, -0.24, -0.11 + sin(a) * 0.075)))
	_m(body, AnimeGear.sphere(0.13, 12), _glow(energy.darkened(0.1), 1.5, true, 0.25), _at(Vector3(0, -0.24, -0.11)))
	_m(root, AnimeGear.box(Vector3(0.05, 0.08, 0.16)), dark, _at(Vector3(0, 0.0, -0.03)))
	for side: float in [-1.0, 1.0]:
		var fin := _m(body, AnimeGear.extrude(PackedVector2Array([Vector2(0, -0.3), Vector2(0.09, -0.22), Vector2(0.06, 0.3), Vector2(0, 0.35)]), 0.012), brass)
		fin.transform = Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3(side * 0.11, 0, 0))
	var cable: Array = []
	for i in 16:
		var t := float(i) / 15.0
		cable.append(Vector3(sin(t * PI) * 0.12, -0.42 - t * 0.18, 0.05 + sin(t * PI * 1.5) * 0.2 + t * 0.12))
	_m(body, AnimeGear.tube(cable, 0.014, 6), _t(Color("#3A2418")))


static func _rifle(r: Node3D, acc: Color) -> void:
	var metal := _t(GUNMETAL, {"shade": Color(0.6, 0.62, 0.86), "rim": Color.WHITE})
	var dark := _t(Color("#22262C"))
	var orange := _t(Color("#FF8A1F"), {"shade": Color(0.75, 0.5, 0.6)})
	_m(r, AnimeGear.box(Vector3(0.05, 0.1, 0.15)), dark, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, -0.04, 0.06)))
	_m(r, AnimeGear.box(Vector3(0.07, 0.5, 0.1)), metal, _at(Vector3(0, 0.12, -0.04)))
	_m(r, AnimeGear.box(Vector3(0.06, 0.32, 0.12)), orange, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, -0.26, -0.01)))
	_m(r, AnimeGear.cyl(0.02, 0.024, 0.6, 10), metal, _at(Vector3(0, 0.66, -0.06)))
	_m(r, AnimeGear.cyl(0.032, 0.032, 0.09, 10), dark, _at(Vector3(0, 0.95, -0.06)))
	_m(r, AnimeGear.cyl(0.03, 0.03, 0.22, 12), dark, _at(Vector3(0, 0.2, -0.14)))
	_m(r, AnimeGear.cyl(0.024, 0.024, 0.01, 12), _glow(_c(acc, Color("#7FE8FF")), 3.0), _at(Vector3(0, 0.31, -0.14)))
	_m(r, AnimeGear.box(Vector3(0.05, 0.14, 0.08)), dark, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.15, 0.06)))
	_m(r, AnimeGear.box(Vector3(0.072, 0.3, 0.01)), _glow(_c(acc, Color("#FF8A1F")), 2.0), _at(Vector3(0, 0.15, -0.095)))


# ------------------------------------------------------------------------------------------ fist weapons
# knuckles / aim along +X, back of the hand +Y, forearm toward -X

## Gauntlet: flared cuff along the forearm (-X, toward the elbow), armoured back of the hand, knuckle bar and
## finger plates. `studs` adds knuckle spikes, `fin` the swept elbow fin (both sit on the plate surfaces).
static func _gauntlet(r: Node3D, plate: Material, trim: Material, studs := true, fin := true) -> void:
	var along := Basis(Vector3.BACK, PI / 2)   # lathe +Y -> -X (toward the elbow)
	_m(r, AnimeGear.lathe([Vector2(0.046, -0.03), Vector2(0.05, 0.06), Vector2(0.056, 0.15), Vector2(0.07, 0.22), Vector2(0.076, 0.245)], 12, 1.0, 0.85), plate, Transform3D(along, Vector3.ZERO))
	_m(r, AnimeGear.lathe([Vector2(0.072, 0.235), Vector2(0.08, 0.252)], 12, 1.0, 0.85), trim, Transform3D(along, Vector3.ZERO))
	_m(r, AnimeGear.lathe([Vector2(0.049, -0.03), Vector2(0.052, -0.012)], 12, 1.0, 0.85), trim, Transform3D(along, Vector3.ZERO))
	# back-of-hand plate: rests on the back of the fist (+Y), from the wrist to the knuckles
	_blade(r, PackedVector2Array([Vector2(-0.03, -0.042), Vector2(0.08, -0.046), Vector2(0.11, 0.0), Vector2(0.08, 0.046), Vector2(-0.03, 0.042)]), 0.026, plate, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.0, 0.034, 0)), 0.006)
	_m(r, AnimeGear.box(Vector3(0.028, 0.03, 0.1)), trim, _at(Vector3(0.105, 0.03, 0)))
	for k in 4:
		var z := -0.036 + k * 0.024
		_m(r, AnimeGear.box(Vector3(0.05, 0.016, 0.019)), plate, Transform3D(Basis(Vector3.BACK, -0.55), Vector3(0.135, 0.012, z)))
		if studs:
			_blade(r, PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.01, 0.0), Vector2(0.0, 0.03)]), 0.012, trim, Transform3D(Basis(Vector3.BACK, -PI / 2 + 0.35), Vector3(0.112, 0.04, z)), 0.0)
	if fin:
		# swept fin on the top of the cuff, pointing back toward the elbow
		_blade(r, PackedVector2Array([Vector2(0.0, 0.0), Vector2(-0.04, 0.0), Vector2(-0.12, 0.045), Vector2(-0.03, 0.018)]), 0.01, trim, _at(Vector3(-0.1, 0.058, 0.0)), 0.0)


static func _gloves(r: Node3D, acc: Color) -> void:
	var red := _t(Color("#B3262A"), {"shade": Color("#7A0F2E") / Color("#C8202A")})
	_gauntlet(r, red, AnimeGear.gold())
	# team-tint energy line along the knuckle bar and down the back of the hand
	_m(r, AnimeGear.box(Vector3(0.016, 0.01, 0.092)), _glow(_c(acc, Color("#FF8A1F")), 2.0), _at(Vector3(0.105, 0.048, 0)))
	_m(r, AnimeGear.box(Vector3(0.09, 0.008, 0.012)), _glow(_c(acc, Color("#FF8A1F")), 2.0), _at(Vector3(0.03, 0.049, 0)))


static func _gloves_qi(r: Node3D, acc: Color) -> void:
	var col := _c(acc, Color("#7FC4FF"))
	var wrapm := _t(Color("#F2F4F8"), {"shade": Color("#A9B3D6") / Color("#F2F0EA")})
	_gauntlet(r, wrapm, _t(Color("#5A8AC8")))
	_m(r, AnimeGear.sphere(0.07, 14), _glow(Color.WHITE.lerp(col, 0.4), 3.0), _at(Vector3(0.1, -0.05, 0)))
	_m(r, AnimeGear.sphere(0.16, 14), _glow(col, 1.3, true, 0.3), _at(Vector3(0.1, -0.05, 0)))


static func _tonfa(r: Node3D, acc: Color) -> void:
	var wood := _t(Color("#3A2418"), {"shade": Color(0.65, 0.55, 0.8)})
	var steel := AnimeGear.steel()
	_m(r, AnimeGear.cyl(0.022, 0.022, 0.14, 10), _t(Color("#F0EEE6")), _at(Vector3(0, -0.01, 0), Basis(Vector3.RIGHT, PI / 2)))
	# main rod along the forearm, short end past the knuckles
	_m(r, AnimeGear.cyl(0.03, 0.03, 0.62, 10), wood, _at(Vector3(-0.17, 0.0, -0.075), Basis(Vector3.FORWARD, PI / 2)))
	for x: float in [-0.46, 0.13]:
		_m(r, AnimeGear.cyl(0.034, 0.034, 0.04, 10), steel, _at(Vector3(x, 0.0, -0.075), Basis(Vector3.FORWARD, PI / 2)))
	# energy line on both faces of the rod (the right-hand tonfa is rolled 180 deg so both rods ride the pinky side)
	for y: float in [0.03, -0.03]:
		_m(r, AnimeGear.box(Vector3(0.3, 0.012, 0.012)), _glow(_c(acc, Color("#8AA0E0")), 2.0), _at(Vector3(-0.2, y, -0.075)))


static func _claws(r: Node3D, acc: Color) -> void:
	var purple := _t(Color("#5A2E6E"))
	var gold := _t(Color("#D8B040"), {"shade": Color("#8A5A2B") / GOLD})
	_gauntlet(r, purple, gold, false, true)
	var steel := AnimeGear.steel()
	# three blades rooted in the knuckle bar (no free-floating trim)
	for i in 3:
		var z := -0.032 + i * 0.032
		var poly := PackedVector2Array([Vector2(0.09, 0.012), Vector2(0.24, -0.008), Vector2(0.38, 0.012), Vector2(0.44, 0.05), Vector2(0.36, 0.032), Vector2(0.22, 0.034), Vector2(0.09, 0.046)])
		_blade(r, poly, 0.008, steel, _at(Vector3(0.0, 0.0, z)), 0.002)
	_m(r, AnimeGear.box(Vector3(0.07, 0.008, 0.012)), _glow(_c(acc, Color("#D8B040")), 2.0), _at(Vector3(0.03, 0.049, 0)))


# ------------------------------------------------------------------------------------------ offhands

## Knight tower shield: kite outline, steel face, gold rim, team-colour field with an original crest.
## Face along +Z, long axis along +Y, grip at the origin.
static func _shield(r: Node3D, acc: Color) -> void:
	var field := _c(acc, Color("#2F5FBF"))
	var kite := PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.2, -0.28), Vector2(0.26, 0.1), Vector2(0.24, 0.36), Vector2(0.0, 0.44), Vector2(-0.24, 0.36), Vector2(-0.26, 0.1), Vector2(-0.2, -0.28)])
	_blade(r, Geometry2D.offset_polygon(kite, 0.025)[0], 0.04, AnimeGear.gold(), _at(Vector3(0, 0.0, 0.03)), 0.006)
	_blade(r, kite, 0.05, AnimeGear.steel(Color("#B8C4D4")), _at(Vector3(0, 0.0, 0.035)), 0.01)
	var inner := Geometry2D.offset_polygon(kite, -0.05)[0]
	_blade(r, inner, 0.02, _t(field, {"shade": AnimeGear.shade_for(field)}), _at(Vector3(0, 0.0, 0.06)), 0.004)
	_blade(r, ClassDress.wing_crest(1.6), 0.012, AnimeGear.gold(), _at(Vector3(0, 0.08, 0.07)), 0.002)
	_m(r, AnimeGear.sphere(0.03, 10), _glow(Color("#3FA9FF"), 3.0), _at(Vector3(0, -0.12, 0.075)))
	_m(r, AnimeGear.box(Vector3(0.03, 0.16, 0.05)), _t(LEATHER_C()), _at(Vector3(0, 0, 0.0)))


static func _grenade(r: Node3D, acc: Color) -> void:
	var olive := _t(Color("#5B6235"))
	_m(r, AnimeGear.sphere(0.06, 12), olive, _at(Vector3(0, 0.06, 0)))
	for y: float in [0.04, 0.08]:
		_m(r, AnimeGear.lathe([Vector2(0.061, y - 0.004), Vector2(0.061, y + 0.004)], 12), _t(Color("#2A2A20")))
	_m(r, AnimeGear.cyl(0.022, 0.026, 0.04, 8), AnimeGear.steel(), _at(Vector3(0, 0.13, 0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.012
	ring.outer_radius = 0.02
	_m(r, ring, AnimeGear.steel(), _at(Vector3(0.03, 0.15, 0), Basis(Vector3.RIGHT, PI / 2)))
	_m(r, AnimeGear.sphere(0.012, 8), _glow(_c(acc, Color("#FF5A1F")), 3.0), _at(Vector3(0, 0.06, 0.058)))


static func _mech_box(r: Node3D, acc: Color) -> void:
	var metal := _t(GUNMETAL, {"shade": Color(0.6, 0.62, 0.86), "rim": Color.WHITE})
	var orange := _t(_c(acc, Color("#FF8A1F")), {"shade": Color(0.75, 0.5, 0.6)})
	_m(r, AnimeGear.box(Vector3(0.16, 0.24, 0.32)), metal)
	_m(r, AnimeGear.box(Vector3(0.165, 0.05, 0.325)), orange, _at(Vector3(0, 0.08, 0)))
	_m(r, AnimeGear.box(Vector3(0.04, 0.04, 0.16)), _t(Color("#1A1A1E")), _at(Vector3(0, 0.15, 0)))
	_m(r, AnimeGear.cyl(0.006, 0.006, 0.22, 6), AnimeGear.steel(), _at(Vector3(0.05, 0.22, -0.12)))
	_m(r, AnimeGear.sphere(0.02, 8), _glow(Color("#7CFF6B"), 3.0), _at(Vector3(0.05, 0.34, -0.12)))
	_m(r, AnimeGear.sphere(0.025, 8), _glow(Color("#7CFF6B"), 2.5), _at(Vector3(0.082, -0.04, 0.09)))


# ------------------------------------------------------------------------------------------ KayKit (mobs)

static func _kaykit(root: Node3D, path: String) -> void:
	var ps: PackedScene = _scenes.get(path)
	if ps == null:
		ps = load(path)
		_scenes[path] = ps
	if ps == null:
		push_error("WeaponFactory: missing " + path)
		return
	var inst := ps.instantiate()
	root.add_child(inst)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		toonify(n as MeshInstance3D)


## Replaces a KayKit (StandardMaterial3D, palette texture) mesh's materials with the toon + outline shaders.
static func toonify(mi: MeshInstance3D, shade := Color(0.62, 0.66, 0.86), rim := Color(1.0, 0.9, 0.75), line := 1.4, mul := Color.WHITE, darken := 0.3, rim_strength := 0.5) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var src := mi.get_active_material(s)
		if src is ShaderMaterial:
			continue
		var key := "%d_%s_%s_%s_%.2f_%.2f_%.2f" % [src.get_instance_id() if src else 0, shade.to_html(), rim.to_html(), mul.to_html(), darken, rim_strength, line]
		var m: ShaderMaterial = _toon_cache.get(key)
		if m == null:
			var bm := src as BaseMaterial3D
			var tex: Texture2D = bm.albedo_texture if bm else null
			var col: Color = bm.albedo_color if bm else Color.WHITE
			m = ShaderMaterial.new()
			m.shader = AnimeBody.TOON
			m.set_shader_parameter("albedo_tex", tex if tex else AnimeGear.white_tex())
			m.set_shader_parameter("albedo_mul", col * mul)
			m.set_shader_parameter("shade_tint", shade)
			m.set_shader_parameter("rim_color", rim)
			m.set_shader_parameter("rim_strength", rim_strength)
			m.set_shader_parameter("alpha_cut", 0.5)
			if bm and bm.emission_enabled:
				m.set_shader_parameter("emission_col", bm.emission * bm.emission_energy_multiplier)
			var o := ShaderMaterial.new()
			o.shader = AnimeBody.OUTLINE
			o.set_shader_parameter("albedo_tex", tex if tex else AnimeGear.white_tex())
			o.set_shader_parameter("albedo_mul", col * mul)
			o.set_shader_parameter("darken", darken)
			o.set_shader_parameter("width_px", line)
			m.next_pass = o
			_toon_cache[key] = m
		mi.set_surface_override_material(s, m)


static func _stripe_tex() -> ImageTexture:
	var im := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 8:
			var on := int(floor((x + y * 1.5) / 8.0)) % 2 == 0
			im.set_pixel(x, y, Color("#F2C230") if on else Color("#1A1A1E"))
	return ImageTexture.create_from_image(im)


static func GOLD_HI() -> Color:
	return Color("#FFE9A8")


static func LEATHER_C() -> Color:
	return Color("#6B3E22")
