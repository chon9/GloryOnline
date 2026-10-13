class_name CharacterVisual
extends Node3D
## Visual body of a Fighter: a KayKit character model driven by a shared, runtime-built
## AnimationLibrary, weapons on the handslot bones, and status overlays (ARCHITECTURE §7.1).
##
## Conventions
## - The node faces -Z (Godot forward). KayKit models face +Z, so the model child is rotated 180 deg.
## - MODEL_SCALE is applied to every model (Medium rig chibis end up ~1.8 m, Large-rig bosses ~3.5 m).
## - One AnimationLibrary per rig ("medium"/"large") is built once from res://assets/anims/*.glb and
##   cached statically. Track paths are normalised to "Skeleton3D:<bone>" and the AnimationPlayer's
##   root_node points at the skeleton's parent, so the same library drives every character.
## - Rig_Large clips key the head (and other bones) at positions that do not match the Large models'
##   rest pose (head sinks ~0.115 m), so all position tracks except root/hips are stripped from the
##   Large library at build time.

const MODEL_SCALE := 0.75
const BLEND_TIME := 0.12

const MODELS: Dictionary = {
	# --- player-class bodies (Medium rig)
	"knight": "res://assets/characters/Knight.glb",
	"barbarian": "res://assets/characters/Barbarian.glb",
	"mage": "res://assets/characters/Mage.glb",
	"rogue": "res://assets/characters/Rogue.glb",
	"rogue_hooded": "res://assets/characters/Rogue_Hooded.glb",
	"ranger": "res://assets/characters/Ranger.glb",
	"druid": "res://assets/characters/Druid.glb",
	"engineer": "res://assets/characters/Engineer.glb",
	"paladin": "res://assets/characters/Paladin.glb",
	"paladin_helmet": "res://assets/characters/Paladin_with_Helmet.glb",
	"ninja": "res://assets/characters/Ninja.glb",
	"space_ranger": "res://assets/characters/SpaceRanger.glb",
	"survivalist": "res://assets/characters/Survivalist.glb",
	"action_figure": "res://assets/characters/ActionFigure.glb",
	"superhero": "res://assets/characters/Superhero.glb",
	"vampire": "res://assets/characters/Vampire.glb",
	"witch": "res://assets/characters/Witch.glb",
	"caveman": "res://assets/characters/Caveman.glb",
	"protagonist_a": "res://assets/characters/Protagonist_A.glb",
	"protagonist_b": "res://assets/characters/Protagonist_B.glb",
	"tiefling": "res://assets/characters/Tiefling.glb",
	"combat_mech": "res://assets/characters/CombatMech.glb",
	"hiker": "res://assets/characters/Hiker.glb",
	"cleric": "res://assets/characters/Cleric.glb",
	"lorekeeper": "res://assets/characters/Lorekeeper.glb",
	"marksman": "res://assets/characters/Marksman.glb",
	"magical_girl": "res://assets/characters/MagicalGirl.glb",
	"avian_swordsman": "res://assets/characters/AvianSwordsman.glb",
	"plant_warrior": "res://assets/characters/PlantWarrior.glb",
	"toy_soldier": "res://assets/characters/ToySoldier.glb",
	"hoarder": "res://assets/characters/Hoarder.glb",
	"robot_one": "res://assets/characters/Robot_One.glb",
	"robot_two": "res://assets/characters/Robot_Two.glb",
	# --- mobs (Medium rig)
	"skeleton_minion": "res://assets/characters/Skeleton_Minion.glb",
	"skeleton_warrior": "res://assets/characters/Skeleton_Warrior.glb",
	"skeleton_rogue": "res://assets/characters/Skeleton_Rogue.glb",
	"skeleton_mage": "res://assets/characters/Skeleton_Mage.glb",
	"necromancer": "res://assets/characters/Necromancer.glb",
	"werewolf": "res://assets/characters/Werewolf_Wolf.glb",
	"werewolf_man": "res://assets/characters/Werewolf_Man.glb",
		"orc_raider": "res://assets/characters/OrcRaider.glb",
	# --- bosses (Large rig)
	"black_knight": "res://assets/characters/BlackKnight.glb",
	"frost_golem": "res://assets/characters/FrostGolem.glb",
	"orc_brute": "res://assets/characters/OrcBrute.glb",
	"monstrosity": "res://assets/characters/Monstrosity.glb",
	"skeleton_golem": "res://assets/characters/Skeleton_Golem.glb",
	"clanker": "res://assets/characters/Clanker.glb",
	"barbarian_large": "res://assets/characters/Barbarian_Large.glb",
}

## Model ids that use Rig_Large (also auto-detected from the hips rest height).
const LARGE_MODELS: Array[String] = ["black_knight", "frost_golem", "orc_brute", "monstrosity", "skeleton_golem", "clanker", "barbarian_large"]

## Suggested default weapon per mob/boss model (for RAID; any WeaponFactory id works).
const MOB_WEAPONS: Dictionary = {
	"skeleton_minion": "skeleton_blade", "skeleton_warrior": "skeleton_axe", "skeleton_rogue": "skeleton_dagger",
	"skeleton_mage": "skeleton_staff", "necromancer": "skeleton_staff", "werewolf": "", "werewolf_man": "",
	"orc_raider": "orc_axe", "black_knight": "black_knight_sword", "frost_golem": "frost_golem_axe",
	"orc_brute": "orc_axe_large", "monstrosity": "monstrosity_pitchfork", "skeleton_golem": "skeleton_golem_axe",
	"clanker": "", "barbarian_large": "great_axe_large",
}

## class_id -> {model, tint}. Every class in ARCHITECTURE §6 has a distinct body.
const CLASS_MODEL: Dictionary = {
	"blade_master": {"model": "ranger", "tint": Color(0.55, 0.85, 1.0)},
	"berserker": {"model": "barbarian", "tint": Color(0.9, 0.12, 0.12)},
	"spellblade": {"model": "avian_swordsman", "tint": Color(0.45, 0.6, 1.0)},
	"ghostblade": {"model": "tiefling", "tint": Color(0.65, 0.3, 1.0)},
	"battle_mage": {"model": "protagonist_a", "tint": Color(0.95, 0.85, 0.75)},
	"elementalist": {"model": "mage", "tint": Color(1.0, 0.5, 0.15)},
	"witch": {"model": "witch", "tint": Color(0.85, 0.35, 0.95)},
	"summoner": {"model": "druid", "tint": Color(0.35, 0.9, 0.5)},
	"sharpshooter": {"model": "marksman", "tint": Color(1.0, 0.45, 0.15)},
	"spitfire": {"model": "action_figure", "tint": Color(1.0, 0.75, 0.2)},
	"launcher": {"model": "combat_mech", "tint": Color(1.0, 0.6, 0.1)},
	"mechanic": {"model": "engineer", "tint": Color(0.3, 0.85, 1.0)},
	"striker": {"model": "superhero", "tint": Color(1.0, 0.3, 0.15)},
	"qi_master": {"model": "protagonist_b", "tint": Color(0.45, 0.8, 1.0)},
	"grappler": {"model": "caveman", "tint": Color(0.95, 0.85, 0.5)},
	"brawler": {"model": "survivalist", "tint": Color(0.75, 0.75, 0.3)},
	"assassin": {"model": "rogue_hooded", "tint": Color(0.75, 0.15, 0.25)},
	"ninja": {"model": "ninja", "tint": Color(0.4, 0.45, 0.6)},
	"thief": {"model": "hoarder", "tint": Color(0.9, 0.8, 0.3)},
	"warlock": {"model": "vampire", "tint": Color(0.55, 0.15, 0.85)},
	"knight": {"model": "knight", "tint": Color(0.4, 0.6, 1.0)},
	"exorcist": {"model": "lorekeeper", "tint": Color(0.85, 0.9, 1.0)},
	"cleric": {"model": "cleric", "tint": Color(1.0, 0.95, 0.6)},
	"paladin": {"model": "paladin_helmet", "tint": Color(1.0, 0.85, 0.35)},
	"unspecialized": {"model": "rogue", "tint": Color(0.95, 0.35, 0.45)},
}

## Models whose glb ships without its texture (the texture is copied next to it and applied at load).
const TEXTURE_FIX: Dictionary = {
	"orc_raider": "res://assets/characters/OrcRaider_orc_texture_A.png",
}

## Abstract key -> ordered candidate clips. The first clip present in the rig library is used.
## Medium rig names come first, Large-rig fallbacks after them (Rig_Large has no jump, cast or
## ranged clips). Every key ends with a clip that exists in both rigs.
const ANIM_MAP: Dictionary = {
	&"idle": ["Idle_A"],
	&"run": ["Running_A"],
	&"walk": ["Walking_A"],
	&"jump": ["Jump_Start", "Dodge_Forward"],
	&"fall": ["Jump_Idle", "Idle_B"],
	&"land": ["Jump_Land", "Melee_Unarmed_Idle"],
	&"hit": ["Hit_A"],
	&"launched": ["Hit_B", "Hit_A"],
	&"knockdown": ["Death_A"],
	&"getup": ["Lie_StandUp", "Dodge_Backward", "Dodge_Backwards"],
	&"stunned": ["Idle_B"],
	&"death": ["Death_B", "Death_A"],
	&"dash": ["Dodge_Forward"],
	&"block": ["Melee_Blocking"],
	&"cast": ["Ranged_Magic_Shoot", "Melee_Unarmed_Punch"],
	&"cast_long": ["Ranged_Magic_Spellcasting_Long", "Melee_Block"],
	&"channel": ["Ranged_Magic_Spellcasting", "Melee_Blocking"],
	&"attack": ["Melee_1H_Attack_Chop", "Melee_1H_Slash"],
	&"attack_1h_1": ["Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Slash"],
	&"attack_1h_2": ["Melee_1H_Attack_Slice_Horizontal", "Melee_Dualwield_Slash"],
	&"attack_1h_3": ["Melee_1H_Attack_Chop", "Melee_1H_Stab"],
	&"attack_2h": ["Melee_2H_Attack_Chop", "Melee_2H_Attack"],
	&"attack_spin": ["Melee_2H_Attack_Spin", "Melee_Dualwield_SlashCombo"],
	&"attack_stab": ["Melee_1H_Attack_Stab", "Melee_1H_Stab"],
	&"attack_slam": ["Melee_2H_Attack_Slice", "Melee_2H_Slam"],
	&"attack_dual": ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Slash"],
	&"kick": ["Melee_Unarmed_Attack_Kick", "Melee_Unarmed_Kick"],
	&"punch": ["Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Punch"],
	&"punch_combo": ["Melee_Dualwield_Attack_Stab", "Melee_Dualwield_SlashCombo"],
	&"shoot_1h": ["Ranged_1H_Shoot", "Melee_1H_Stab"],
	&"shoot_2h": ["Ranged_2H_Shoot", "Melee_Block_Attack"],
	&"shoot_dual": ["Ranged_Magic_Shoot", "Melee_Dualwield_Slash"],
	&"throw": ["Throw", "Melee_1H_Slash"],
	&"summon": ["Ranged_Magic_Summon", "Melee_Unarmed_Smash"],
	&"heal": ["Ranged_Magic_Raise", "Idle_B"],
	&"taunt": ["Skeletons_Taunt", "Melee_Unarmed_Smash"],
	&"grab": ["Melee_Block_Attack"],
	&"leap": ["Jump_Full_Long", "Melee_2H_Slam"],
	&"aerial": ["Melee_1H_Attack_Jump_Chop", "Melee_2H_Slam"],
	&"victory": ["Cheering", "Melee_Unarmed_Smash"],
}

const LOOP_KEYS: Array[StringName] = [&"idle", &"run", &"walk", &"fall", &"stunned", &"block", &"channel", &"cast_long", &"launched"]
## One-shots that hold their last frame instead of returning to idle.
const HOLD_KEYS: Array[StringName] = [&"death", &"knockdown", &"launched"]
## Clips that loop inside the library (looping clips used by loop keys).
const LOOP_CLIPS: Array[String] = ["Idle_A", "Idle_B", "Running_A", "Walking_A", "Jump_Idle", "Melee_Blocking",
	"Ranged_Magic_Spellcasting", "Ranged_Magic_Spellcasting_Long", "Melee_2H_Idle", "Melee_Unarmed_Idle",
	"Running_HoldingRifle", "Ranged_1H_Aiming", "Ranged_2H_Aiming", "Melee_Block"]

## Weapon stances: override a few keys so heavy/unarmed/gun users look right.
const STANCE_OF_WEAPON: Dictionary = {
	"greatsword": "2h", "great_axe": "2h", "war_scythe": "2h", "battle_lance": "2h", "hand_cannon": "2h",
	"gloves": "unarmed", "gloves_qi": "unarmed", "claws": "unarmed", "tonfa": "unarmed", "": "unarmed",
	"rifle": "rifle",
}
const STANCE_OVERRIDES: Dictionary = {
	"2h": {&"idle": ["Melee_2H_Idle", "Idle_A"]},
	"unarmed": {&"idle": ["Melee_Unarmed_Idle", "Idle_A"], &"attack": ["Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Punch"]},
	"rifle": {&"run": ["Running_HoldingRifle", "Running_A"]},
}

## Weapons that are wielded as a mirrored pair when no explicit offhand is given.
const DUAL_WEAPONS: Array[String] = ["dual_swords", "gloves", "gloves_qi", "tonfa", "claws", "revolver"]

## Status bit order (ARCHITECTURE §4.2).
const STATUS_IDS: Array[StringName] = [&"stun", &"freeze", &"root", &"silence", &"sleep", &"blind", &"confusion",
	&"taunted", &"slow", &"haste", &"bleed", &"poison", &"burn", &"weight", &"super_armor", &"stealth", &"invuln",
	&"block", &"atk_up", &"def_up", &"def_down", &"matk_up", &"regen", &"shield", &"mark", &"atk_down", &"cast_slow"]

const _MEDIUM_ANIMS: Array[String] = ["MovementBasic", "MovementAdvanced", "General", "CombatMelee", "CombatRanged", "Special", "Simulation"]
const _LARGE_ANIMS: Array[String] = ["MovementBasic", "MovementAdvanced", "General", "CombatMelee"]
const _SKIP_CLIPS: Array[String] = ["T-Pose", "EXPERIMENTAL_Medium_Transform", "EXPERIMENTAL_Large_Transform"]

static var _libs: Dictionary = {}          # rig -> AnimationLibrary
static var _overlay_shader: Shader = null
static var _bubble_mat: Material = null
static var _star_mat: Material = null

var model_id: String = ""
var rig: String = "medium"
var weapon_type: String = ""
var offhand: String = ""
var tint: Color = Color.WHITE
var model_root: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var current_key: StringName = &""
var current_clip: String = ""
var height: float = 1.8

var _hand_r: BoneAttachment3D
var _hand_l: BoneAttachment3D
var _hip: BoneAttachment3D
var _head: BoneAttachment3D
var _meshes: Array[MeshInstance3D] = []
var _overlay: ShaderMaterial
var _alpha: float = 1.0
var _status_mask: int = 0
var _flash: float = 0.0
var _time: float = 0.0
var _bubble: MeshInstance3D
var _stars: Node3D
var _stance: String = ""
var _frozen := false
var _speed := 1.0
var _hidden_by_alpha := false


# --------------------------------------------------------------------------------------------
# Construction

static func create(p_model_id: String, p_weapon_type: String = "", p_offhand: String = "", p_tint: Color = Color.WHITE) -> CharacterVisual:
	var v := CharacterVisual.new()
	v.name = "Visual"
	v._build(p_model_id, p_tint)
	v.set_weapon(p_weapon_type, p_offhand)
	v.play(&"idle")
	return v


## Convenience: body + weapon for a class id from CLASS_MODEL.
static func create_for_class(class_id: String, p_weapon_type: String, p_offhand: String = "", p_tint := Color(0, 0, 0, 0)) -> CharacterVisual:
	var cm: Dictionary = CLASS_MODEL.get(class_id, {"model": "knight", "tint": Color.WHITE})
	var t: Color = p_tint if p_tint.a > 0.0 else cm.tint
	return create(cm.model, p_weapon_type, p_offhand, t)


static func model_path(p_model_id: String) -> String:
	return MODELS[resolve_model_id(p_model_id)]


## Accepts a MODELS id, a class id (CLASS_MODEL), a mob id, or a glb basename in any case
## ("AvianSwordsman", "Skeleton_Warrior"). Unknown ids return "knight".
static func resolve_model_id(id: String) -> String:
	if MODELS.has(id):
		return id
	if CLASS_MODEL.has(id):
		return CLASS_MODEL[id]["model"]
	var low := id.to_lower()
	if MODELS.has(low):
		return low
	for k in MODELS.keys():
		var base := String(MODELS[k]).get_file().get_basename().to_lower()
		if base == low or base.replace("_", "") == low.replace("_", ""):
			return k
	return "knight"


func _build(p_model_id: String, p_tint: Color) -> void:
	var resolved := resolve_model_id(p_model_id)
	if p_model_id != "" and resolved != p_model_id and not CLASS_MODEL.has(p_model_id) and resolved == "knight":
		push_warning("CharacterVisual: unknown model '%s', using knight" % p_model_id)
	p_model_id = resolved
	model_id = p_model_id
	tint = p_tint
	var ps: PackedScene = load(MODELS[p_model_id])
	model_root = ps.instantiate() as Node3D
	model_root.name = "Model"
	model_root.rotation = Vector3(0.0, PI, 0.0)
	model_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(model_root)
	skeleton = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		for n in model_root.find_children("*", "Skeleton3D", true, false):
			skeleton = n as Skeleton3D
			break
	if skeleton == null:
		push_error("CharacterVisual: no Skeleton3D in " + MODELS[p_model_id])
		return
	skeleton.name = "Skeleton3D"
	var hips := skeleton.find_bone("hips")
	rig = "large" if (p_model_id in LARGE_MODELS or (hips >= 0 and skeleton.get_bone_rest(hips).origin.y > 0.8)) else "medium"
	height = (4.7 if rig == "large" else 2.4) * MODEL_SCALE
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	if TEXTURE_FIX.has(p_model_id):
		_fix_texture(load(TEXTURE_FIX[p_model_id]))
	# animation
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_root.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(skeleton.get_parent())
	anim_player.add_animation_library(&"", get_library(rig))
	anim_player.animation_finished.connect(_on_anim_finished)
	# bone attachments
	_hand_r = _attach("handslot.r", "hand.r")
	_hand_l = _attach("handslot.l", "hand.l")
	_hip = _attach("hips", "root")
	_head = _attach("head", "hips")
	# status overlay material shared by all surfaces of this character
	_overlay = ShaderMaterial.new()
	_overlay.shader = _get_overlay_shader()
	_overlay.set_shader_parameter("color", Color(0, 0, 0, 0))
	_apply_overlay(false)


func _fix_texture(tex: Texture2D) -> void:
	for mi in _meshes:
		for si in mi.mesh.get_surface_count():
			var src := mi.get_active_material(si)
			var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			m.albedo_texture = tex
			m.albedo_color = Color.WHITE
			mi.mesh.surface_set_material(si, m)


func _attach(bone: String, fallback: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	var b := bone if skeleton.find_bone(bone) >= 0 else fallback
	ba.name = "Attach_" + b
	skeleton.add_child(ba)
	ba.bone_name = b
	return ba


# --------------------------------------------------------------------------------------------
# Animation library (shared per rig)

static func get_library(p_rig: String) -> AnimationLibrary:
	if _libs.has(p_rig):
		return _libs[p_rig]
	var lib := AnimationLibrary.new()
	var files := _MEDIUM_ANIMS if p_rig == "medium" else _LARGE_ANIMS
	var prefix := "Rig_Medium_" if p_rig == "medium" else "Rig_Large_"
	for f in files:
		var path := "res://assets/anims/%s%s.glb" % [prefix, f]
		var ps: PackedScene = load(path)
		if ps == null:
			push_error("CharacterVisual: missing anim file " + path)
			continue
		var inst := ps.instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			for clip in ap.get_animation_list():
				if String(clip) in _SKIP_CLIPS or lib.has_animation(clip):
					continue
				var a: Animation = ap.get_animation(clip).duplicate(true)
				_normalize_tracks(a, p_rig == "large")
				a.loop_mode = Animation.LOOP_LINEAR if String(clip) in LOOP_CLIPS else Animation.LOOP_NONE
				lib.add_animation(clip, a)
		inst.free()
	_libs[p_rig] = lib
	return lib


## Rewrites "<anything>/Skeleton3D:bone" to "Skeleton3D:bone"; for Large strips non-root/hips position tracks.
static func _normalize_tracks(a: Animation, strip_positions: bool) -> void:
	var t := a.get_track_count() - 1
	while t >= 0:
		var p := a.track_get_path(t)
		var bone := String(p.get_concatenated_subnames())
		if strip_positions and a.track_get_type(t) == Animation.TYPE_POSITION_3D and bone != "root" and bone != "hips":
			a.remove_track(t)
		else:
			a.track_set_path(t, NodePath("Skeleton3D:" + bone))
		t -= 1


static func resolve_clip(p_rig: String, key: StringName, stance: String = "") -> String:
	var lib := get_library(p_rig)
	var cands: Array = []
	if stance != "" and STANCE_OVERRIDES.has(stance) and (STANCE_OVERRIDES[stance] as Dictionary).has(key):
		cands = STANCE_OVERRIDES[stance][key]
	cands = cands + (ANIM_MAP.get(key, []) as Array)
	for c in cands:
		if lib.has_animation(StringName(c)):
			return c
	return "Idle_A"


# --------------------------------------------------------------------------------------------
# Public API (ARCHITECTURE §7.1)

func play(anim_key: StringName, speed := 1.0) -> void:
	## Loop keys and death/knockdown do not restart when re-requested; every other key (one-shots and
	## "launched", which replays its flinch on each juggle hit) restarts from frame 0 on each call, so CORE's
	## anim_seq retrigger replays attacks.
	if anim_player == null:
		return
	var clip := resolve_clip(rig, anim_key, _stance)
	anim_player.speed_scale = 0.0 if _frozen else speed
	_speed = speed
	var sticky := (anim_key in LOOP_KEYS and anim_key != &"launched") or anim_key == &"death" or anim_key == &"knockdown"
	if anim_key == current_key and clip == current_clip and sticky:
		return
	var restart := clip == current_clip and anim_player.current_animation == clip
	current_key = anim_key
	current_clip = clip
	if restart:
		anim_player.stop(true)
		anim_player.play(StringName(clip), 0.05)
	else:
		anim_player.play(StringName(clip), BLEND_TIME)
	if not (anim_key in LOOP_KEYS) or anim_key == &"launched":
		anim_player.seek(0.0, true)


## Restarts the current one-shot (e.g. the same attack key pressed twice).
func replay(anim_key: StringName, speed := 1.0) -> void:
	current_key = &""
	play(anim_key, speed)


func set_weapon(p_weapon_type: String, p_offhand := "") -> void:
	weapon_type = p_weapon_type
	offhand = p_offhand
	if _hand_r == null:
		return
	for att in [_hand_r, _hand_l, _hip]:
		for c in (att as Node).get_children():
			c.queue_free()
			(att as Node).remove_child(c)
	if p_weapon_type != "":
		var w := WeaponFactory.build(p_weapon_type, tint)
		if w:
			_hand_r.add_child(w)
	var off := p_offhand
	if off == "" and p_weapon_type in DUAL_WEAPONS:
		off = WeaponFactory.left_variant(p_weapon_type)
	if off != "":
		var o := WeaponFactory.build(off, tint)
		if o:
			if off == "mech_box":
				_hip.add_child(o)
				o.position = Vector3(0.38, 0.0, 0.05)
			else:
				_hand_l.add_child(o)
	_stance = STANCE_OF_WEAPON.get(p_weapon_type, "")
	if _alpha < 0.999:
		var a := _alpha
		_alpha = 1.0
		set_alpha(a)
	if current_key != &"":
		var k := current_key
		current_key = &""
		play(k, _speed)


func set_alpha(a: float) -> void:
	a = clampf(a, 0.0, 1.0)
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	if a <= 0.01:
		_hidden_by_alpha = visible
		visible = false
	elif _hidden_by_alpha:
		_hidden_by_alpha = false
		visible = true
	for mi in _all_meshes():
		_fade_override(mi, a)
		if mi.has_meta(&"_fade_override"):
			continue
		for s in mi.get_surface_override_material_count():
			if a >= 0.999:
				mi.set_surface_override_material(s, null)
				continue
			var m := mi.get_surface_override_material(s)
			if m == null:
				var src := mi.get_active_material(s)
				if src is BaseMaterial3D:
					m = src.duplicate()
					(m as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
					mi.set_surface_override_material(s, m)
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				bm.albedo_color.a = a
	_overlay.set_shader_parameter("alpha_mul", a)


## Fades a mesh whose material_override is set (procedural WeaponFactory meshes share
## static override materials, which take priority over surface overrides). The shared
## material is never mutated: a per-mesh duplicate is swapped in and the original is
## restored at full alpha.
func _fade_override(mi: MeshInstance3D, a: float) -> void:
	var cur := mi.material_override
	if cur == null and not mi.has_meta(&"_orig_override"):
		return
	var faded: Material = mi.get_meta(&"_fade_override") if mi.has_meta(&"_fade_override") else null
	if mi.has_meta(&"_orig_override") and cur != faded:
		# someone replaced the override since we faded it: adopt the new one as original
		mi.remove_meta(&"_orig_override")
		mi.remove_meta(&"_fade_override")
		faded = null
		if cur == null:
			return
	if not mi.has_meta(&"_orig_override"):
		mi.set_meta(&"_orig_override", cur)
	var orig: Material = mi.get_meta(&"_orig_override")
	if a >= 0.999:
		mi.material_override = orig
		mi.transparency = 0.0
		mi.remove_meta(&"_orig_override")
		mi.remove_meta(&"_fade_override")
		return
	if orig is BaseMaterial3D:
		var fm := faded as BaseMaterial3D
		if fm == null:
			fm = (orig as BaseMaterial3D).duplicate()
			if fm.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
				fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.set_meta(&"_fade_override", fm)
			mi.material_override = fm
		fm.albedo_color.a = (orig as BaseMaterial3D).albedo_color.a * a
	else:
		# shader or other material: fall back to per-instance transparency
		mi.set_meta(&"_fade_override", cur)
		mi.transparency = 1.0 - a


func set_status_visual(mask: int) -> void:
	if mask == _status_mask:
		return
	_status_mask = mask
	_frozen = _has(mask, &"freeze")
	anim_player.speed_scale = 0.0 if _frozen else _speed
	# shield bubble
	if _has(mask, &"shield") or _has(mask, &"invuln"):
		if _bubble == null:
			_bubble = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 24
			sm.rings = 12
			_bubble.mesh = sm
			_bubble.material_override = _get_bubble_mat()
			_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_bubble.scale = Vector3(0.75, 0.85, 0.75) * height
			_bubble.position = Vector3(0, height * 0.5, 0)
			add_child(_bubble)
		_bubble.visible = true
		_bubble.set_instance_shader_parameter("tint", Color(1.0, 0.9, 0.4, 1.0) if _has(mask, &"invuln") and not _has(mask, &"shield") else Color(0.45, 0.8, 1.0, 1.0))
	elif _bubble:
		_bubble.visible = false
	# stun / sleep / confusion stars
	if _has(mask, &"stun") or _has(mask, &"sleep") or _has(mask, &"confusion"):
		if _stars == null:
			_stars = _make_stars()
			_head.add_child(_stars)
			_stars.position = Vector3(0, 1.25 if rig == "medium" else 1.9, 0)
		_stars.visible = true
	elif _stars:
		_stars.visible = false
	_apply_overlay(_overlay_active())


func flash_hit() -> void:
	_flash = 0.12
	_apply_overlay(true)


func get_hand_position(right := true) -> Vector3:
	var att := _hand_r if right else _hand_l
	if att == null or not att.is_inside_tree():
		return global_position + Vector3(0, height * 0.55, 0) if is_inside_tree() else Vector3(0, height * 0.55, 0)
	return att.global_position


func get_head_position() -> Vector3:
	if _head == null or not _head.is_inside_tree():
		return global_position + Vector3(0, height, 0)
	return _head.global_position + Vector3(0, 0.6 * MODEL_SCALE, 0)


func has_clip_for(key: StringName) -> bool:
	return get_library(rig).has_animation(StringName(resolve_clip(rig, key, _stance)))


# --------------------------------------------------------------------------------------------
# Internals

func _process(delta: float) -> void:
	_time += delta
	if _stars and _stars.visible:
		_stars.rotate_y(delta * 4.0)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_apply_overlay(_overlay_active())
	_update_overlay_params()


func _on_anim_finished(clip: StringName) -> void:
	if current_key in HOLD_KEYS or current_key in LOOP_KEYS:
		return
	# one-shot finished: settle back into idle so a stale key never freezes mid-pose
	current_key = &""
	play(&"idle", _speed)


func _has(mask: int, id: StringName) -> bool:
	var i := STATUS_IDS.find(id)
	return i >= 0 and (mask & (1 << i)) != 0


func _overlay_active() -> bool:
	return _flash > 0.0 or _has(_status_mask, &"freeze") or _has(_status_mask, &"burn") or _has(_status_mask, &"super_armor") \
		or _has(_status_mask, &"poison") or _has(_status_mask, &"mark")


func _apply_overlay(on: bool) -> void:
	for mi in _meshes:
		mi.material_overlay = _overlay if on else null
	_update_overlay_params()


func _update_overlay_params() -> void:
	if _overlay == null or _meshes.is_empty() or _meshes[0].material_overlay == null:
		return
	var fill := Color(0, 0, 0, 0)
	var rim := Color(0, 0, 0, 0)
	if _has(_status_mask, &"freeze"):
		fill = Color(0.55, 0.85, 1.0, 0.55)
		rim = Color(0.85, 0.95, 1.0, 0.9)
	elif _has(_status_mask, &"burn"):
		var fl := 0.25 + 0.2 * sin(_time * 22.0) + 0.1 * sin(_time * 37.0)
		fill = Color(1.0, 0.45, 0.05, fl)
		rim = Color(1.0, 0.6, 0.1, 0.8)
	elif _has(_status_mask, &"poison"):
		fill = Color(0.35, 0.9, 0.2, 0.25 + 0.1 * sin(_time * 6.0))
	if _has(_status_mask, &"super_armor"):
		rim = Color(1.0, 0.8, 0.2, 0.9 + 0.1 * sin(_time * 10.0))
	elif _has(_status_mask, &"mark") and rim.a == 0.0:
		rim = Color(1.0, 0.2, 0.2, 0.7)
	if _flash > 0.0:
		fill = Color(1, 1, 1, 0.75 * clampf(_flash / 0.12, 0.0, 1.0))
	_overlay.set_shader_parameter("fill", fill)
	_overlay.set_shader_parameter("rim", rim)


func _all_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in find_children("*", "MeshInstance3D", true, false):
		if n != _bubble and not (_stars and _stars.is_ancestor_of(n)):
			out.append(n as MeshInstance3D)
	return out


func _make_stars() -> Node3D:
	var root := Node3D.new()
	root.name = "StunStars"
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	for i in 3:
		var s := MeshInstance3D.new()
		s.mesh = q
		s.material_override = _get_star_mat()
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := TAU * float(i) / 3.0
		s.position = Vector3(cos(ang) * 0.55, 0.0, sin(ang) * 0.55)
		root.add_child(s)
	return root


static func _get_overlay_shader() -> Shader:
	if _overlay_shader == null:
		_overlay_shader = Shader.new()
		_overlay_shader.code = """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 fill : source_color = vec4(0.0);
uniform vec4 rim : source_color = vec4(0.0);
uniform float alpha_mul = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 c = mix(fill.rgb, rim.rgb, clamp(f * rim.a * 1.5, 0.0, 1.0));
	float a = max(fill.a, f * rim.a);
	ALBEDO = c * (1.0 + f * rim.a * 1.5);
	ALPHA = clamp(a, 0.0, 1.0) * alpha_mul;
}
"""
	return _overlay_shader


static func _get_bubble_mat() -> Material:
	if _bubble_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(0.45, 0.8, 1.0, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float band = 0.5 + 0.5 * sin(TIME * 3.0 + UV.y * 30.0);
	ALBEDO = tint.rgb * (f * 1.6 + 0.06 + band * 0.04);
	ALPHA = 1.0;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_bubble_mat = m
	return _bubble_mat


static func _get_star_mat() -> Material:
	if _star_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/vfx/star_06.png")
		m.albedo_color = Color(1.0, 0.92, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.2)
		_star_mat = m
	return _star_mat
