class_name WeaponFactory
extends RefCounted
## Builds weapon nodes for CharacterVisual (ARCHITECTURE §7.2).
##
## Grip convention (KayKit handslot convention, used for every weapon id):
## - Node origin = the point held in the fist (sits exactly on the handslot.r / handslot.l bone).
## - Blades, shafts and hafts extend along +Y (pommel/butt goes a little into -Y).
## - Handslot axes (verified with an axis gizmo): +Y = blade direction (up in a guard pose), +X = knuckle /
##   aim direction (along the forearm, away from the elbow), Z = across the palm. Tonfa rods and claw
##   blades therefore run along X; staves are tilted 45 deg toward -X so their heads read upward.
## - Firearms are modelled with the muzzle along +Z and the grip hanging toward -Y, then wrapped in an
##   inner "Aim" pivot yawed +90 deg, so on the returned node the muzzle points along +X. That is the
##   axis the KayKit handslot bones point at the target in Ranged_1H/2H_Shoot (verified by rendering).
## - Units are KayKit model units (unscaled character space, a Medium character is ~2.4 units tall).
##   CharacterVisual scales the whole model by MODEL_SCALE, weapons included.
## Weapons with no matching KayKit mesh are built procedurally from primitive meshes with an emissive
## accent coloured by `tint`.

const KAYKIT: Dictionary = {
	"greatsword": "res://assets/weapons/adv/sword_2handed.gltf",
	"short_sword": "res://assets/weapons/special/AvianSwordsman_Sword/AvianSwordsman_Sword.gltf",
	"tachi": "res://assets/weapons/special/Ninja_Katana/Ninja_Katana.gltf",
	"battle_lance": "res://assets/weapons/fantasy/spear_A.gltf",
	"staff": "res://assets/weapons/fantasy/staff_A.gltf",
	"staff_ring": "res://assets/weapons/adv/druid_staff.gltf",
	"broom": "res://assets/weapons/special/Broom/Broom.gltf",
	"rifle": "res://assets/weapons/guns/Gun_Rifle.gltf",
	"gloves": "res://assets/weapons/fantasy/fistweapon_C_right.gltf",
	"gloves_left": "res://assets/weapons/fantasy/fistweapon_C_left.gltf",
	"gloves_qi": "res://assets/weapons/fantasy/fistweapon_A.gltf",
	"dual_swords": "res://assets/weapons/fantasy/dagger_B.gltf",
	"dagger": "res://assets/weapons/adv/dagger.gltf",
	"cane": "res://assets/weapons/special/Skeleton_Staff/Skeleton_Staff.gltf",
	"knight_sword": "res://assets/weapons/adv/sword_1handed.gltf",
	"war_scythe": "res://assets/weapons/fantasy/scythe.gltf",
	"great_axe": "res://assets/weapons/adv/axe_2handed.gltf",
	"shield": "res://assets/weapons/adv/shield_badge.gltf",
	"grenade": "res://assets/weapons/special/Grenade/Grenade.gltf",
	"sword": "res://assets/weapons/adv/sword_1handed.gltf",
	# mobs / bosses
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

## Every class weapon_type and offhand id from ARCHITECTURE §7.2 (all supported by build()).
## Pole weapons tilted (degrees about the handslot Z axis) so the head reads "up" in idle and casts.
const POLE_TILT: Dictionary = {"staff": 45.0, "staff_ring": 45.0, "cane": 45.0, "umbrella_open": 35.0, "umbrella": 20.0, "cross": 60.0,
	"skeleton_staff": 45.0, "magic_wand": 30.0, "wand": 30.0}

## Ids built as firearms (wrapped in the +90 deg "Aim" pivot).
const FIREARMS: Array[String] = ["revolver", "pistol", "auto_pistol", "hand_cannon", "rifle", "crossbow", "skeleton_crossbow"]

const WEAPON_TYPES: Array[String] = ["lightsaber", "greatsword", "short_sword", "tachi", "battle_lance", "staff", "staff_ring",
	"broom", "revolver", "auto_pistol", "hand_cannon", "rifle", "gloves", "gloves_qi", "tonfa", "claws", "dual_swords",
	"ninjato", "dagger", "cane", "knight_sword", "war_scythe", "cross", "great_axe", "umbrella"]
const OFFHAND_TYPES: Array[String] = ["shield", "grenade", "mech_box", "pistol", "dagger", "sword"]
## Extra forms of the Myriad Manifestation Umbrella for set_weapon() form switches.
## "umbrella" = folded (spear/sword form, default), "umbrella_open" = canopy open (shield form),
## "umbrella_gun" = folded with a muzzle (gun form). Kits switch with CharacterVisual.set_weapon().
const UMBRELLA_FORMS: Array[String] = ["umbrella", "umbrella_open", "umbrella_gun"]

static var _mats: Dictionary = {}
static var _scenes: Dictionary = {}


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


static func build(weapon_type: String, tint := Color.WHITE) -> Node3D:
	var outer := Node3D.new()
	outer.name = "Weapon_" + weapon_type
	var root := outer
	if weapon_type in FIREARMS:
		root = Node3D.new()
		root.name = "Aim"
		root.rotation_degrees.y = 90.0
		outer.add_child(root)
	elif POLE_TILT.has(weapon_type):
		root = Node3D.new()
		root.name = "Tilt"
		root.rotation_degrees.z = POLE_TILT[weapon_type]
		outer.add_child(root)
	match weapon_type:
		"lightsaber":
			_lightsaber(root, tint)
		"revolver", "pistol":
			_revolver(root, tint)
		"auto_pistol":
			_auto_pistol(root, tint)
		"hand_cannon":
			_hand_cannon(root, tint)
		"tonfa":
			_tonfa(root, tint)
		"claws":
			_claws(root, tint)
		"ninjato":
			_ninjato(root, tint)
		"cross":
			_cross(root, tint)
		"mech_box":
			_mech_box(root, tint)
		"umbrella_open":
			_umbrella(root, tint, true, false)
		"umbrella", "umbrella_closed":
			_umbrella(root, tint, false, false)
		"umbrella_gun":
			_umbrella(root, tint, false, true)
		_:
			if KAYKIT.has(weapon_type):
				_kaykit(root, KAYKIT[weapon_type])
				_decorate(root, weapon_type, tint)
			else:
				push_warning("WeaponFactory: unknown weapon type '%s', using knight_sword" % weapon_type)
				_kaykit(root, KAYKIT["knight_sword"])
	for mi in outer.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return outer


# ------------------------------------------------------------------------------------------
# KayKit meshes + canon details

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


static func _decorate(root: Node3D, t: String, tint: Color) -> void:
	match t:
		"short_sword":
			# faintly glowing rune strip on both faces of the blade
			_box(root, Vector3(0.04, 0.8, 0.125), Vector3(0, 0.62, 0), _glow(tint, 1.6, 0.6))
		"battle_lance":
			# red tassel under the blade (Que Xie)
			_cyl(root, 0.0, 0.09, 0.32, Vector3(0, 1.38, 0), Vector3.ZERO, _mat("tassel", Color(0.85, 0.08, 0.08)))
		"staff":
			# crescent cradle holding a glowing crystal sphere
			_torus(root, 0.1, 0.16, Vector3(0, 1.18, 0), Vector3(PI / 2, 0, 0), _mat("gold", Color(0.95, 0.75, 0.25), 0.7, 0.35))
			_sphere(root, 0.12, Vector3(0, 1.2, 0), _glow(tint, 3.0))
		"staff_ring":
			_torus(root, 0.2, 0.26, Vector3(0, 1.45, 0), Vector3(PI / 2, 0, 0), _mat("gold", Color(0.95, 0.75, 0.25), 0.7, 0.35))
			_sphere(root, 0.07, Vector3(0, 1.45, 0), _glow(tint, 3.0))
			_cyl(root, 0.02, 0.02, 0.22, Vector3(0.0, 1.08, 0.0), Vector3.ZERO, _mat("cord", Color(0.8, 0.2, 0.2)))
			_sphere(root, 0.05, Vector3(0, 0.95, 0), _glow(tint, 2.0))
		"cane":
			_sphere(root, 0.11, Vector3(0, 1.3, 0), _glow(Color(0.65, 0.2, 1.0) if tint == Color.WHITE else tint, 3.0))
		"gloves_qi":
			_sphere(root, 0.22, Vector3(0, 0.05, 0), _glow(tint, 1.2, 0.35))
		"war_scythe":
			# paper talismans hanging from the shaft
			for i in 3:
				_box(root, Vector3(0.12, 0.26, 0.01), Vector3(0.08, 0.55 - i * 0.28, 0.05), _mat("talisman", Color(0.95, 0.85, 0.35)))
		"great_axe":
			_box(root, Vector3(0.06, 0.06, 0.28), Vector3(0, 0.95, 0), _mat("gold", Color(0.95, 0.75, 0.25), 0.7, 0.35))
		"tachi":
			# purple ghost mist edge
			_box(root, Vector3(0.02, 1.1, 0.06), Vector3(0, 0.85, 0), _glow(tint, 1.2, 0.5))


# ------------------------------------------------------------------------------------------
# Procedural weapons

static func _lightsaber(root: Node3D, tint: Color) -> void:
	var c := tint if tint != Color.WHITE else Color(0.6, 0.85, 1.0)
	var metal := _mat("steel", Color(0.75, 0.77, 0.8), 0.8, 0.3)
	var dark := _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5)
	_cyl(root, 0.055, 0.055, 0.42, Vector3(0, 0.0, 0), Vector3.ZERO, metal)
	for i in 3:
		_cyl(root, 0.062, 0.062, 0.035, Vector3(0, -0.12 + i * 0.08, 0), Vector3.ZERO, dark)
	_cyl(root, 0.09, 0.06, 0.06, Vector3(0, 0.23, 0), Vector3.ZERO, metal)
	_box(root, Vector3(0.24, 0.035, 0.07), Vector3(0, 0.25, 0), metal)
	_cyl(root, 0.045, 0.05, 1.35, Vector3(0, 0.95, 0), Vector3.ZERO, _glow(Color.WHITE.lerp(c, 0.35), 4.0))
	_cyl(root, 0.075, 0.08, 1.4, Vector3(0, 0.95, 0), Vector3.ZERO, _glow(c, 2.5, 0.45))


static func _revolver(root: Node3D, tint: Color) -> void:
	var metal := _mat("gunmetal", Color(0.3, 0.32, 0.36), 0.85, 0.35)
	var wood := _mat("wood", Color(0.45, 0.26, 0.14))
	var acc := _mat("accent_" + tint.to_html(), tint if tint != Color.WHITE else Color(0.85, 0.7, 0.3), 0.6, 0.4)
	_box(root, Vector3(0.11, 0.3, 0.13), Vector3(0, -0.08, -0.04), wood)            # grip
	_box(root, Vector3(0.12, 0.13, 0.28), Vector3(0, 0.1, 0.06), metal)             # frame
	_cyl(root, 0.085, 0.085, 0.14, Vector3(0, 0.1, 0.08), Vector3(PI / 2, 0, 0), acc)  # cylinder
	_cyl(root, 0.04, 0.045, 0.62, Vector3(0, 0.13, 0.45), Vector3(PI / 2, 0, 0), metal)  # long barrel
	_box(root, Vector3(0.03, 0.05, 0.05), Vector3(0, 0.19, 0.72), metal)            # sight
	_torus(root, 0.035, 0.06, Vector3(0, 0.02, 0.06), Vector3(0, 0, PI / 2), metal) # trigger guard


static func _auto_pistol(root: Node3D, tint: Color) -> void:
	var metal := _mat("gunmetal", Color(0.3, 0.32, 0.36), 0.85, 0.35)
	var dark := _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5)
	_box(root, Vector3(0.11, 0.3, 0.13), Vector3(0, -0.08, -0.02), dark)
	_box(root, Vector3(0.12, 0.13, 0.5), Vector3(0, 0.1, 0.14), metal)
	_box(root, Vector3(0.1, 0.24, 0.09), Vector3(0, -0.2, 0.1), dark)               # magazine
	_box(root, Vector3(0.124, 0.03, 0.4), Vector3(0, 0.13, 0.16), _glow(tint if tint != Color.WHITE else Color(1, 0.7, 0.2), 1.5))
	_cyl(root, 0.03, 0.03, 0.08, Vector3(0, 0.1, 0.42), Vector3(PI / 2, 0, 0), dark)


static func _hand_cannon(root: Node3D, tint: Color) -> void:
	var c := tint if tint != Color.WHITE else Color(1.0, 0.65, 0.15)
	var metal := _mat("cannon", Color(0.35, 0.33, 0.3), 0.85, 0.4)
	var gold := _mat("gold", Color(0.95, 0.75, 0.25), 0.7, 0.35)
	_box(root, Vector3(0.12, 0.28, 0.14), Vector3(0, -0.12, 0), _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5))   # side grip
	_box(root, Vector3(0.36, 0.36, 0.42), Vector3(0, 0.18, -0.12), metal)            # breech box
	_cyl(root, 0.2, 0.17, 1.15, Vector3(0, 0.2, 0.55), Vector3(PI / 2, 0, 0), metal)  # wide barrel
	_torus(root, 0.17, 0.26, Vector3(0, 0.2, 1.1), Vector3(PI / 2, 0, 0), gold)       # muzzle ring
	_cyl(root, 0.14, 0.14, 0.02, Vector3(0, 0.2, 1.13), Vector3(PI / 2, 0, 0), _glow(c, 2.5))
	_torus(root, 0.17, 0.22, Vector3(0, 0.2, 0.3), Vector3(PI / 2, 0, 0), gold)
	_box(root, Vector3(0.38, 0.05, 0.3), Vector3(0, 0.38, -0.12), _glow(c, 1.5))


static func _tonfa(root: Node3D, tint: Color) -> void:
	var wood := _mat("tonfa_wood", Color(0.25, 0.16, 0.1))
	var wrap := _mat("wrap", Color(0.85, 0.85, 0.8))
	_cyl(root, 0.05, 0.05, 0.3, Vector3(0, 0, 0), Vector3.ZERO, wrap)               # side handle (held)
	# main rod perpendicular to the handle, lying along the forearm (+X short end, -X toward the elbow)
	_box(root, Vector3(0.95, 0.1, 0.1), Vector3(-0.22, 0.18, 0), wood)
	_box(root, Vector3(0.2, 0.105, 0.03), Vector3(0.18, 0.18, 0.0), _glow(tint if tint != Color.WHITE else Color(0.9, 0.8, 0.5), 1.0))


static func _claws(root: Node3D, tint: Color) -> void:
	var metal := _mat("steel", Color(0.75, 0.77, 0.8), 0.8, 0.3)
	var dark := _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5)
	_box(root, Vector3(0.24, 0.22, 0.24), Vector3(0, 0.0, 0), dark)                  # gauntlet
	_box(root, Vector3(0.26, 0.06, 0.26), Vector3(0, 0.1, 0), metal)
	# three curved blades out of the knuckles (+X)
	for i in 3:
		var y := -0.08 + i * 0.08
		var blade := _box(root, Vector3(0.6, 0.025, 0.06), Vector3(0.42, y, 0.0), metal)
		blade.rotation = Vector3(0, 0, -0.12)
		_cone(root, 0.035, 0.16, Vector3(0.78, y - 0.05, 0.0), Vector3(0, 0, -PI / 2 - 0.3), metal)
	_box(root, Vector3(0.02, 0.2, 0.03), Vector3(0.13, 0, 0.12), _glow(tint if tint != Color.WHITE else Color(0.8, 0.8, 0.3), 0.6))


static func _ninjato(root: Node3D, tint: Color) -> void:
	var steel := _mat("steel", Color(0.75, 0.77, 0.8), 0.8, 0.3)
	var dark := _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5)
	_box(root, Vector3(0.08, 0.42, 0.08), Vector3(0, -0.02, 0), _mat("wrap_blue", Color(0.15, 0.2, 0.35)))
	_box(root, Vector3(0.22, 0.03, 0.22), Vector3(0, 0.2, 0), dark)                  # square tsuba
	_box(root, Vector3(0.025, 0.95, 0.09), Vector3(0, 0.68, 0), steel)
	_box(root, Vector3(0.01, 0.95, 0.02), Vector3(0, 0.68, 0.045), _glow(tint if tint != Color.WHITE else Color(0.7, 0.8, 1.0), 1.0))
	var tip := _box(root, Vector3(0.025, 0.12, 0.06), Vector3(0, 1.18, -0.01), steel)
	tip.rotation = Vector3(0.5, 0, 0)


static func _cross(root: Node3D, tint: Color) -> void:
	var white := _mat("holy_white", Color(0.95, 0.95, 0.92), 0.2, 0.4)
	var gold := _mat("gold", Color(0.95, 0.75, 0.25), 0.7, 0.35)
	_box(root, Vector3(0.12, 1.25, 0.1), Vector3(0, 0.4, 0), white)                 # vertical
	_box(root, Vector3(0.62, 0.12, 0.1), Vector3(0, 0.72, 0), white)                # horizontal
	_box(root, Vector3(0.14, 0.03, 0.12), Vector3(0, -0.2, 0), gold)
	for p in [Vector3(0, 1.03, 0), Vector3(-0.31, 0.72, 0), Vector3(0.31, 0.72, 0)]:
		_box(root, Vector3(0.15, 0.04, 0.12), p, gold)
	_sphere(root, 0.08, Vector3(0, 0.72, 0.05), _glow(tint if tint != Color.WHITE else Color(1.0, 0.9, 0.5), 3.0))


static func _mech_box(root: Node3D, tint: Color) -> void:
	var metal := _mat("toolbox", Color(0.55, 0.57, 0.6), 0.7, 0.4)
	var acc := _mat("accent_" + tint.to_html(), tint if tint != Color.WHITE else Color(0.95, 0.6, 0.1), 0.3, 0.5)
	_box(root, Vector3(0.22, 0.32, 0.44), Vector3(0, 0, 0), metal)
	_box(root, Vector3(0.23, 0.06, 0.45), Vector3(0, 0.1, 0), acc)
	_box(root, Vector3(0.05, 0.05, 0.2), Vector3(0, 0.2, 0), _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5))
	_sphere(root, 0.035, Vector3(0.115, -0.05, 0.12), _glow(Color(0.3, 1.0, 0.5), 2.0))


static func _umbrella(root: Node3D, tint: Color, open: bool, gun: bool) -> void:
	var c := tint if tint != Color.WHITE else Color(0.85, 0.2, 0.25)
	var metal := _mat("steel", Color(0.75, 0.77, 0.8), 0.8, 0.3)
	var canopy := _mat("canopy_" + c.to_html(), c, 0.1, 0.6)
	canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cyl(root, 0.035, 0.035, 2.0, Vector3(0, 0.55, 0), Vector3.ZERO, metal)           # shaft
	var hook := _torus(root, 0.06, 0.1, Vector3(0.08, -0.48, 0), Vector3(PI / 2, 0, 0), _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5))
	hook.scale = Vector3(1, 1, 1)
	if open:
		_cone(root, 0.78, 0.45, Vector3(0, 1.32, 0), Vector3.ZERO, canopy)
		for i in 8:
			var a := TAU * i / 8.0
			var rib := _box(root, Vector3(0.025, 0.025, 0.8), Vector3(sin(a) * 0.39, 1.32, cos(a) * 0.39), metal)
			rib.rotation = Vector3(-0.52, a, 0)
		_cone(root, 0.05, 0.25, Vector3(0, 1.62, 0), Vector3.ZERO, metal)
	else:
		_cone(root, 0.2, 1.1, Vector3(0, 1.0, 0), Vector3.ZERO, canopy)
		_cone(root, 0.045, 0.45, Vector3(0, 1.75, 0), Vector3.ZERO, metal)            # spear tip
		_box(root, Vector3(0.03, 0.3, 0.012), Vector3(0, 1.75, 0), _glow(c, 1.5))
	if gun:
		_cyl(root, 0.06, 0.06, 0.5, Vector3(0, 0.1, 0.15), Vector3(PI / 2, 0, 0), metal)
		_box(root, Vector3(0.1, 0.2, 0.12), Vector3(0, 0.0, 0.0), _mat("dark", Color(0.12, 0.12, 0.14), 0.4, 0.5))


# ------------------------------------------------------------------------------------------
# Primitive helpers

static func _mat(key: String, col: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var k := key + col.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	_mats[k] = m
	return m


static func _glow(col: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var k := "glow%s_%.2f_%.2f" % [col.to_html(), energy, alpha]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[k] = m
	return m


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(root, m, pos, Vector3.ZERO, mat)


static func _cyl(root: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return _add(root, m, pos, rot, mat)


static func _cone(root: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	return _cyl(root, 0.0, r, h, pos, rot, mat)


static func _sphere(root: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return _add(root, m, pos, Vector3.ZERO, mat)


static func _torus(root: Node3D, inner: float, outer: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	return _add(root, m, pos, rot, mat)
