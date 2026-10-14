class_name CharacterVisual
extends Node3D
## Visual body of a Fighter (ARCHITECTURE §7.1), two kinds of rig behind one API:
## - "anime": every player class. An AnimeBody (converted VRoid CC0 base + toon/outline + class dress from
##   ClassDress / visuals/dress/<class_id>.gd), the shared retargeted Mesh2Motion + KayKit-gap AnimationLibrary,
##   spring-bone hair and runtime cloth (both switched off beyond 25 m from the camera).
## - "medium" / "large": KayKit mobs, bosses and summons. KayKit meshes restyled with the same toon + outline
##   shader (bible 4.3: never leave KayKit defaults), driven by the KayKit Rig_Medium / Rig_Large libraries.
##
## Conventions
## - The node faces -Z (Godot forward). Both kinds of model face +Z, so the model child is rotated 180 deg.
## - Player bodies are scaled to their dress height (~1.74-1.86 m). KayKit models use MODEL_SCALE.
## - Weapons (WeaponFactory, metres) sit on BoneAttachments of RightHand / LeftHand with the dress grip
##   transform; on KayKit rigs they sit on the handslot bones.
## - Rig_Large clips key the head at positions that do not match the Large models' rest pose, so all
##   position tracks except root/hips are stripped from the Large library at build time.

const MODEL_SCALE := 0.75
const BLEND_TIME := 0.12
const SPRING_CULL_DIST := 25.0

## KayKit models (mobs, bosses, summons). Player classes are anime bodies (see ClassDress).
const MODELS: Dictionary = {
	# --- summons (Medium rig)
	"magical_girl": "res://assets/characters/MagicalGirl.glb",
	"plant_warrior": "res://assets/characters/PlantWarrior.glb",
	"toy_soldier": "res://assets/characters/ToySoldier.glb",
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

## class_id -> {model, tint}. Every class body is its own anime dress (model = the class id).
const CLASS_MODEL: Dictionary = {
	"blade_master": {"model": "blade_master", "tint": Color(0.55, 0.85, 1.0)},
	"berserker": {"model": "berserker", "tint": Color(0.9, 0.12, 0.12)},
	"spellblade": {"model": "spellblade", "tint": Color(0.45, 0.6, 1.0)},
	"ghostblade": {"model": "ghostblade", "tint": Color(0.65, 0.3, 1.0)},
	"battle_mage": {"model": "battle_mage", "tint": Color(0.95, 0.85, 0.75)},
	"elementalist": {"model": "elementalist", "tint": Color(1.0, 0.5, 0.15)},
	"witch": {"model": "witch", "tint": Color(0.85, 0.35, 0.95)},
	"summoner": {"model": "summoner", "tint": Color(0.35, 0.9, 0.5)},
	"sharpshooter": {"model": "sharpshooter", "tint": Color(1.0, 0.45, 0.15)},
	"spitfire": {"model": "spitfire", "tint": Color(1.0, 0.75, 0.2)},
	"launcher": {"model": "launcher", "tint": Color(1.0, 0.6, 0.1)},
	"mechanic": {"model": "mechanic", "tint": Color(0.3, 0.85, 1.0)},
	"striker": {"model": "striker", "tint": Color(1.0, 0.3, 0.15)},
	"qi_master": {"model": "qi_master", "tint": Color(0.45, 0.8, 1.0)},
	"grappler": {"model": "grappler", "tint": Color(0.95, 0.85, 0.5)},
	"brawler": {"model": "brawler", "tint": Color(0.75, 0.75, 0.3)},
	"assassin": {"model": "assassin", "tint": Color(0.75, 0.15, 0.25)},
	"ninja": {"model": "ninja", "tint": Color(0.4, 0.45, 0.6)},
	"thief": {"model": "thief", "tint": Color(0.9, 0.8, 0.3)},
	"warlock": {"model": "warlock", "tint": Color(0.55, 0.15, 0.85)},
	"knight": {"model": "knight", "tint": Color(0.4, 0.6, 1.0)},
	"exorcist": {"model": "exorcist", "tint": Color(0.85, 0.9, 1.0)},
	"cleric": {"model": "cleric", "tint": Color(1.0, 0.95, 0.6)},
	"paladin": {"model": "paladin", "tint": Color(1.0, 0.85, 0.35)},
	"unspecialized": {"model": "unspecialized", "tint": Color(0.95, 0.35, 0.45)},
}

## KayKit mob / boss toon tone: [shade tint, rim colour, outline px, albedo mul, outline darken, rim strength].
## Bright models (ice, bone) get a darker, bluer albedo and a deeper shadow band so they read against snow.
const MOB_TONE: Dictionary = {
	"": [Color(0.48, 0.5, 0.8), Color(0.78, 0.88, 1.0), 1.9, Color(0.82, 0.82, 0.87), 0.22, 0.55],
	"frost_golem": [Color(0.36, 0.42, 0.78), Color(0.7, 0.92, 1.0), 2.4, Color(0.5, 0.64, 0.88), 0.16, 0.7],
	"skeleton_golem": [Color(0.42, 0.42, 0.72), Color(0.78, 0.88, 1.0), 2.2, Color(0.72, 0.7, 0.72), 0.18, 0.6],
	"skeleton_minion": [Color(0.44, 0.44, 0.74), Color(0.78, 0.88, 1.0), 2.0, Color(0.76, 0.74, 0.76), 0.2, 0.55],
	"skeleton_warrior": [Color(0.44, 0.44, 0.74), Color(0.78, 0.88, 1.0), 2.0, Color(0.76, 0.74, 0.76), 0.2, 0.55],
	"skeleton_rogue": [Color(0.44, 0.44, 0.74), Color(0.78, 0.88, 1.0), 2.0, Color(0.76, 0.74, 0.76), 0.2, 0.55],
	"skeleton_mage": [Color(0.44, 0.44, 0.74), Color(0.78, 0.88, 1.0), 2.0, Color(0.76, 0.74, 0.76), 0.2, 0.55],
}

## Models whose glb ships without its texture (the texture is copied next to it and applied at load).
const TEXTURE_FIX: Dictionary = {
	"orc_raider": "res://assets/characters/OrcRaider_orc_texture_A.png",
}

## KayKit rigs: abstract key -> ordered candidate clips (first present in the rig library wins).
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
	&"dodge": ["Dodge_Forward"],
	&"backstep": ["Dodge_Backward", "Dodge_Backwards", "Dodge_Forward"],
	&"sprint": ["Running_A"],
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

## Anime rig: abstract key -> Mesh2Motion clips (CC0), "kk_" = KayKit clip retargeted through a BoneMap
## (gap fillers: 2H spin, dual-wield, kick, summon, raise). Every key ends with a clip that always exists.
const ANIME_ANIM_MAP: Dictionary = {
	&"idle": ["Idle_A"],
	&"run": ["Run_Anime"],
	&"walk": ["Walk"],
	&"jump": ["Jump_Start"],
	&"fall": ["Jump_air"],
	&"land": ["Jump_Land"],
	&"hit": ["Hit_Chest"],
	&"launched": ["Hit_Knockback"],
	&"knockdown": ["Death_B"],
	&"getup": ["LayToIdle"],
	&"stunned": ["Dizzy"],
	&"death": ["Death_A"],
	&"dash": ["Sword_Dash_RM"],
	&"dodge": ["Roll", "Sword_Dash_RM"],
	&"backstep": ["NinjaJump_Land", "Jump_Land"],
	&"sprint": ["Sprint", "Run_Anime"],
	&"block": ["Sword_Block"],
	&"cast": ["Spell_Simple_Shoot"],
	&"cast_long": ["kk_Ranged_Magic_Spellcasting_Long", "Spell_Simple_Idle"],
	&"channel": ["Spell_Simple_Idle"],
	&"attack": ["Sword_Regular_A"],
	&"attack_1h_1": ["Sword_Regular_A"],
	&"attack_1h_2": ["Sword_Regular_B"],
	&"attack_1h_3": ["Sword_Regular_C"],
	&"attack_2h": ["Sword_Regular_C"],
	&"attack_spin": ["kk_Melee_2H_Attack_Spin", "Sword_Regular_Combo"],
	&"attack_stab": ["Sword_Regular_A"],
	&"attack_slam": ["Attack_Ground_Pound"],
	&"attack_dual": ["kk_Melee_Dualwield_Attack_Slice", "Sword_Regular_B"],
	&"kick": ["kk_Melee_Unarmed_Attack_Kick", "Melee_Hook"],
	&"punch": ["Punch_Jab"],
	&"punch_combo": ["Punch_Cross"],
	&"shoot_1h": ["Pistol_Shoot"],
	&"shoot_2h": ["kk_Ranged_2H_Shoot", "Pistol_Shoot"],
	&"shoot_dual": ["Pistol_Shoot"],
	&"throw": ["OverhandThrow"],
	&"summon": ["kk_Ranged_Magic_Summon", "Power Up"],
	&"heal": ["kk_Ranged_Magic_Raise", "Power Up"],
	&"taunt": ["Angry"],
	&"grab": ["Melee_Hook"],
	&"leap": ["NinjaJump_Start"],
	&"aerial": ["kk_Melee_1H_Attack_Jump_Chop", "Sword_Regular_C"],
	&"victory": ["Victory"],
}

const LOOP_KEYS: Array[StringName] = [&"idle", &"run", &"sprint", &"walk", &"fall", &"stunned", &"block", &"channel", &"cast_long", &"launched"]
## One-shots time-fitted at speed 1.0 to this many seconds (the dodge clips run 0.33 s on KayKit and 1.83 s for the
## anime Roll, while the dodge itself lasts 0.3 s); the requested speed scales on top.
const FIT_TIME: Dictionary = {&"dodge": 0.5, &"backstep": 0.45}
## One-shots that hold their last frame instead of returning to idle.
const HOLD_KEYS: Array[StringName] = [&"death", &"knockdown", &"launched"]
## Clips that loop inside the KayKit libraries.
const LOOP_CLIPS: Array[String] = ["Idle_A", "Idle_B", "Running_A", "Walking_A", "Jump_Idle", "Melee_Blocking",
	"Ranged_Magic_Spellcasting", "Ranged_Magic_Spellcasting_Long", "Melee_2H_Idle", "Melee_Unarmed_Idle",
	"Running_HoldingRifle", "Ranged_1H_Aiming", "Ranged_2H_Aiming", "Melee_Block"]
## Clips that loop inside the anime library (only clips used by loop keys or idles).
const ANIME_LOOP_CLIPS: Array[String] = ["Idle_A", "Idle_Sword", "Fighting Idle", "Pistol_Idle", "Spell_Simple_Idle", "Idle_Shield",
	"Run_Anime", "Run_Female", "Jog", "Sprint", "Walk", "Walk_Female", "Jump_air", "Dizzy", "Sword_Block", "Levitate Idle",
	"Hit_Knockback", "Idle_FoldArms", "Idle_Subtle", "Meditate", "Run_Stealth", "Walk_Stealth", "NinjaJump_Idle",
	"kk_Ranged_Magic_Spellcasting_Long", "kk_Ranged_Magic_Spellcasting", "kk_Melee_Blocking", "kk_Melee_2H_Idle", "kk_Ranged_2H_Aiming"]

## KayKit weapon stances.
const STANCE_OF_WEAPON: Dictionary = {
	"greatsword": "2h", "great_axe": "2h", "war_scythe": "2h", "battle_lance": "2h", "hand_cannon": "2h",
	"gloves": "unarmed", "gloves_qi": "unarmed", "claws": "unarmed", "tonfa": "unarmed", "": "unarmed",
	"rifle": "rifle",
}
const STANCE_OVERRIDES: Dictionary = {
	"2h": {&"idle": ["Melee_2H_Idle", "Idle_A"]},
	"unarmed": {&"idle": ["Melee_Unarmed_Idle", "Idle_A"], &"attack": ["Melee_Unarmed_Attack_Punch_A", "Melee_Unarmed_Punch"]},
	"rifle": {&"run": ["Running_HoldingRifle", "Running_A"], &"sprint": ["Running_HoldingRifle", "Running_A"]},
}
## Anime weapon stances (by WeaponFactory grip kind / id); dress `anims` take precedence.
const ANIME_STANCE_OF_WEAPON: Dictionary = {
	"lightsaber": "blade", "short_sword": "blade", "tachi": "blade", "knight_sword": "blade", "ninjato": "blade",
	"dual_swords": "blade", "dagger": "blade", "sword": "blade", "greatsword": "heavy", "great_axe": "heavy", "war_scythe": "heavy",
	"battle_lance": "heavy", "umbrella": "heavy", "umbrella_open": "heavy",
	"staff": "caster", "staff_ring": "caster", "cane": "caster", "cross": "caster", "broom": "caster",
	"revolver": "gun", "auto_pistol": "gun", "hand_cannon": "gun", "rifle": "gun", "umbrella_gun": "gun",
	"gloves": "fist", "gloves_qi": "fist", "claws": "fist", "tonfa": "fist", "": "fist",
}
const ANIME_STANCE_OVERRIDES: Dictionary = {
	"blade": {&"idle": ["Fighting Idle"]},
	# the Sprint clip locks the arms, so a lance / greatsword stuck rigidly across the body: sprint on the run cycle
	# (sped up by the fighter's sprint speed) so the heavy weapon swings with the stride
	"heavy": {&"idle": ["Fighting Idle"], &"sprint": ["Run_Anime"]},
	"caster": {&"idle": ["Spell_Simple_Idle"], &"attack": ["Spell_Simple_Shoot"]},
	# guns held low at the sides (Pistol_Idle / the KayKit aims raise the gun across the face in close shots)
	"gun": {&"idle": ["Idle_Sword", "Pistol_Idle"], &"attack": ["Pistol_Shoot"]},
	"fist": {&"idle": ["Fighting Idle"], &"attack": ["Punch_Jab"], &"attack_1h_1": ["Fighting Left Jab"],
		&"attack_1h_2": ["Fighting Right Jab"], &"attack_1h_3": ["Punch_Cross"]},
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

## Zone tints (rim, shadow ambient multiplier) per ENV zone preset name (maps/env_kit.gd PRESETS keys). Derived
## from each preset's key/fill/ambient colours; used when env_kit is not loadable.
const ZONE_TINTS: Dictionary = {
	"frost": [Color("#CFEFFF"), Color("#E2F0FA")],
	"glory_stage": [Color("#FFD8B0"), Color("#DCD6F4")],
	"blossom": [Color("#FFF0DA"), Color("#EEF4FA")],
	"golden_ruins": [Color("#FFCC88"), Color("#ECE4EE")],
	"lava": [Color("#FF9A60"), Color("#E6CCD8")],
	"moon": [Color("#B8E0FF"), Color("#C8C2F0")],
}

static var _libs: Dictionary = {}          # rig -> AnimationLibrary
static var _zone_rim: Color = Color(1, 1, 1, 0)
static var _zone_ambient: Color = Color.WHITE
static var _overlay_shader: Shader = null
static var _bubble_mat: Material = null

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
var body: AnimeBody                       # anime rig only
var dress: Dictionary = {}                # anime rig only

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
var _ice: Node3D
var _embers: GPUParticles3D
var _stance: String = ""
var _frozen := false
var _speed := 1.0
var _play_speed := 1.0           # _speed with the FIT_TIME scaling applied (the AnimationPlayer speed_scale)
var _hidden_by_alpha := false
var _cull_t := 0.0
var _near := true
var _extra_atts: Array[Node] = []
var _morph: Array = []        # umbrella form transition: [node, from Transform3D, to Transform3D]
var _morph_t := 1.0
const MORPH_TIME := 0.2
var _mounts: Array[Dictionary] = []   # anime weapon mounts: {node, id, left, kind, units, bone, grip, two, cur, from?, to?}
var _grip_t := 1.0


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
	var cm: Dictionary = CLASS_MODEL.get(class_id, {"model": class_id, "tint": Color.WHITE})
	var t: Color = p_tint if p_tint.a > 0.0 else cm.tint
	return create(cm.model, p_weapon_type, p_offhand, t)


## Resource path of a model id (anime classes resolve to their VRoid base).
static func model_path(p_model_id: String) -> String:
	var id := resolve_model_id(p_model_id)
	if MODELS.has(id):
		return MODELS[id]
	return String(ClassDress.get_dress(id).get("model", ""))


## True when the id (after resolution) is an anime player body.
static func is_anime_id(id: String) -> bool:
	return ClassDress.has_class(resolve_model_id(id))


## Accepts a class id (anime body), a MODELS id (KayKit mob/boss/summon), or a glb basename in any case
## ("Skeleton_Warrior"). Unknown ids and "" return "knight" (the anime Knight).
static func resolve_model_id(id: String) -> String:
	if ClassDress.has_class(id):
		return id
	if MODELS.has(id):
		return id
	var low := id.to_lower()
	if ClassDress.has_class(low):
		return low
	if MODELS.has(low):
		return low
	for k in MODELS.keys():
		var base := String(MODELS[k]).get_file().get_basename().to_lower()
		if base == low or base.replace("_", "") == low.replace("_", ""):
			return k
	return "knight"


func _build(p_model_id: String, p_tint: Color) -> void:
	var resolved := resolve_model_id(p_model_id)
	if p_model_id != "" and resolved == "knight" and p_model_id.to_lower() != "knight":
		push_warning("CharacterVisual: unknown model '%s', using knight" % p_model_id)
	model_id = resolved
	tint = p_tint
	if ClassDress.has_class(resolved):
		_build_anime(resolved)
	else:
		_build_kaykit(resolved)
	if skeleton == null:
		return
	anim_player.animation_finished.connect(_on_anim_finished)
	add_to_group(&"character_visuals")
	if _zone_rim.a > 0.0:
		set_zone_tint(Color(_zone_rim.r, _zone_rim.g, _zone_rim.b), _zone_ambient)
	_overlay = ShaderMaterial.new()
	_overlay.shader = _get_overlay_shader()
	_overlay.set_shader_parameter("fill", Color(0, 0, 0, 0))
	_apply_overlay(false)


func _build_anime(class_id: String) -> void:
	rig = "anime"
	dress = ClassDress.get_dress(class_id)
	body = AnimeBody.new(dress)
	body.build(ANIME_LOOP_CLIPS)
	if body.skeleton == null:
		push_error("CharacterVisual: anime body failed for " + class_id)
		return
	model_root = body
	model_root.name = "Model"
	model_root.rotation = Vector3(0.0, PI, 0.0)
	height = float(dress.get("height", 1.8))
	model_root.scale = Vector3.ONE * (height / maxf(body.natural_height, 0.5))
	add_child(model_root)
	skeleton = body.skeleton
	anim_player = body.anim
	_meshes = body.meshes
	_hand_r = _attach("RightHand", "RightHand")
	_hand_l = _attach("LeftHand", "LeftHand")
	_hip = _attach("Hips", "Hips")
	_head = _attach("Head", "Neck")


func _build_kaykit(p_model_id: String) -> void:
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
	# restyle: toon + coloured outline, slightly muted so mobs sit under the heroes in value (bible 4.3), with a deep
	# cool shadow band, a cool rim and a heavier, darker line so pale models still separate from snow / sand
	var tone: Array = MOB_TONE.get(p_model_id, MOB_TONE[""])
	for mi in _meshes:
		WeaponFactory.toonify(mi, tone[0], tone[1], tone[2], tone[3], tone[4], tone[5])
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_root.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(skeleton.get_parent())
	anim_player.add_animation_library(&"", get_library(rig))
	_hand_r = _attach("handslot.r", "hand.r")
	_hand_l = _attach("handslot.l", "hand.l")
	_hip = _attach("hips", "root")
	_head = _attach("head", "hips")


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
# Animation libraries (shared per rig)

static func get_library(p_rig: String) -> AnimationLibrary:
	if p_rig == "anime":
		return AnimeBody.anim_library(ANIME_LOOP_CLIPS)
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


static func anim_map_for(p_rig: String) -> Dictionary:
	return ANIME_ANIM_MAP if p_rig == "anime" else ANIM_MAP


static func resolve_clip(p_rig: String, key: StringName, stance: String = "", extra: Dictionary = {}) -> String:
	var lib := get_library(p_rig)
	var cands: Array = []
	if extra.has(key):
		cands = cands + (extra[key] as Array)
	var so: Dictionary = ANIME_STANCE_OVERRIDES if p_rig == "anime" else STANCE_OVERRIDES
	if stance != "" and so.has(stance) and (so[stance] as Dictionary).has(key):
		cands = cands + (so[stance][key] as Array)
	cands = cands + (anim_map_for(p_rig).get(key, []) as Array)
	for c in cands:
		if lib.has_animation(StringName(c)):
			return c
	return "Idle_A"


## The clip this visual plays for `key` (dress overrides > weapon stance > rig map).
func resolve_key(key: StringName) -> String:
	var extra: Dictionary = dress.get("anims", {})
	var wa: Dictionary = dress.get("weapon_anims", {})
	if wa.has(weapon_type):
		extra = extra.duplicate()
		var w: Dictionary = wa[weapon_type]
		for k in w:
			extra[k] = w[k]
	return resolve_clip(rig, key, _stance, extra)


# --------------------------------------------------------------------------------------------
# Public API (ARCHITECTURE §7.1)

func play(anim_key: StringName, speed := 1.0) -> void:
	## Loop keys and death/knockdown do not restart when re-requested; every other key (one-shots and
	## "launched", which replays its flinch on each juggle hit) restarts from frame 0 on each call, so CORE's
	## anim_seq retrigger replays attacks.
	if anim_player == null:
		return
	var clip := resolve_key(anim_key)
	var eff := speed
	if FIT_TIME.has(anim_key) and anim_player.has_animation(StringName(clip)):
		eff *= anim_player.get_animation(StringName(clip)).length / float(FIT_TIME[anim_key])
	anim_player.speed_scale = 0.0 if _frozen else eff
	_speed = speed
	_play_speed = eff
	var sticky := (anim_key in LOOP_KEYS and anim_key != &"launched") or anim_key == &"death" or anim_key == &"knockdown"
	if anim_key == current_key and clip == current_clip and sticky:
		return
	var restart := clip == current_clip and anim_player.current_animation == clip
	current_key = anim_key
	current_clip = clip
	_update_clip_grips(clip, anim_key)
	if restart:
		anim_player.stop(true)
		anim_player.play(StringName(clip), 0.05)
	else:
		anim_player.play(StringName(clip), BLEND_TIME)
	if not (anim_key in LOOP_KEYS) or anim_key == &"launched":
		anim_player.seek(0.0, true)


## Tools / screenshots: hold `clip` at time `t` (paused) with its weapon grips snapped in and the cloth settled.
func pose_clip(clip: String, t: float, key: StringName = &"") -> void:
	if anim_player == null or not anim_player.has_animation(StringName(clip)):
		return
	anim_player.play(StringName(clip), 0.0)
	anim_player.seek(t, true)
	anim_player.pause()
	current_clip = clip
	if key != &"":
		current_key = key
	_update_clip_grips(clip, current_key)
	if _grip_t < 1.0:
		_update_grip_blend(BLEND_TIME * 2.0)
	settle_cloth()


## Runs the runtime cloth (capes, scarves) for `seconds` of simulated time at the current pose so stills show a
## settled drape instead of the rest shape.
func settle_cloth(seconds := 1.5) -> void:
	if body == null or not is_inside_tree():
		return
	if skeleton:
		skeleton.force_update_all_bone_transforms()
	for c in body.find_children("*", "AnimeCloth", true, false):
		(c as AnimeCloth).settle(seconds)


## Restarts the current one-shot (e.g. the same attack key pressed twice).
func replay(anim_key: StringName, speed := 1.0) -> void:
	current_key = &""
	play(anim_key, speed)


func set_weapon(p_weapon_type: String, p_offhand := "") -> void:
	# 千机伞 form switch: remember where the old canopy panels are so the new form's panels fold / snap out of them
	var old_panels: Dictionary = {}
	if weapon_type != p_weapon_type and weapon_type in WeaponFactory.UMBRELLA_FORMS and p_weapon_type in WeaponFactory.UMBRELLA_FORMS and is_inside_tree():
		for n in find_children("Panel_*", "Node3D", true, false):
			old_panels[String(n.name)] = (n as Node3D).global_transform
	weapon_type = p_weapon_type
	offhand = p_offhand
	if _hand_r == null:
		return
	for att in [_hand_r, _hand_l, _hip]:
		for c in (att as Node).get_children():
			(att as Node).remove_child(c)
			c.queue_free()
	for e in _extra_atts:
		if is_instance_valid(e):
			e.get_parent().remove_child(e)
			e.queue_free()
	_extra_atts.clear()
	_mounts.clear()
	_grip_t = 1.0
	if body:
		body.disable_two_hand()
	if p_weapon_type != "":
		var w := WeaponFactory.build(p_weapon_type, tint)
		if w:
			_mount(w, p_weapon_type, false)
	var off := p_offhand
	if off == "" and p_weapon_type in DUAL_WEAPONS:
		off = WeaponFactory.left_variant(p_weapon_type)
	if off != "":
		var o := WeaponFactory.build(off, tint)
		if o:
			_mount(o, off, true)
	if not old_panels.is_empty():
		_start_morph(old_panels)
	if rig == "anime":
		_stance = ANIME_STANCE_OF_WEAPON.get(p_weapon_type, "blade")
	else:
		_stance = STANCE_OF_WEAPON.get(p_weapon_type, "")
	if _alpha < 0.999:
		var a := _alpha
		_alpha = 1.0
		set_alpha(a)
	if current_key != &"":
		var k := current_key
		current_key = &""
		play(k, _speed)


## Puts a WeaponFactory node on the right/left hand (or the hip) with the rig's grip convention.
func _mount(w: Node3D, id: String, left: bool) -> void:
	var kind := String(w.get_meta("grip_kind", "blade"))
	var units := String(w.get_meta("units", "m"))
	if rig != "anime":
		var att := _hip if kind == "hip" else (_hand_l if left else _hand_r)
		if kind == "hip":
			w.position = Vector3(0.38, 0.0, 0.05)
		if units == "m":
			w.scale = Vector3.ONE / MODEL_SCALE
		if POLE_TILT_KAYKIT.has(id):
			var tilt := Node3D.new()
			tilt.name = "Tilt"
			tilt.rotation_degrees.z = POLE_TILT_KAYKIT[id]
			att.add_child(tilt)
			tilt.add_child(w)
		else:
			att.add_child(w)
		return
	var grips: Dictionary = dress.get("grips", {})
	var g: Dictionary = grips.get(id, {})
	kind = String(g.get("kind", kind))
	if g.get("accent_only", false):
		_strip_to_accents(w)
	var bone := "LeftHand" if left else "RightHand"
	var att2 := _hand_l if left else _hand_r
	match kind:
		"shield":
			bone = "LeftLowerArm"
			att2 = null
		"hip":
			bone = "Hips"
			att2 = _hip
	var parent: Node3D = att2
	if parent == null:
		parent = _attach(bone, bone)
		parent.name = "Attach_" + bone + "_" + id
		_extra_atts.append(parent)
	parent.add_child(w)
	var two := bool(g.get("two_hand", w.get_meta("two_hand", false))) and not left
	var m := {"node": w, "id": id, "left": left, "kind": kind, "units": units, "bone": bone, "grip": g, "two": two}
	_mounts.append(m)
	var cur := _clip_grip(m, current_clip, current_key)
	m["cur"] = cur
	w.transform = _mount_local_xf(m, cur)
	if two:
		body.enable_two_hand(w)


## Dress grip `accent_only`: the class builds its own armour for this weapon (e.g. articulated gauntlets on the
## finger bones), so only the factory node's emissive accents (the team-tint energy lines, qi orbs) are kept.
static func _strip_to_accents(w: Node3D) -> void:
	for n in w.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		if mi.material_override:
			if not _is_accent(mi.material_override):
				mi.get_parent().remove_child(mi)
				mi.free()
			continue
		var src := mi.mesh as ArrayMesh
		if src == null:
			continue
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var mat := src.surface_get_material(si)
			if _is_accent(mat):
				out.add_surface_from_arrays(src.surface_get_primitive_type(si), src.surface_get_arrays(si))
				out.surface_set_material(out.get_surface_count() - 1, mat)
		if out.get_surface_count() == 0:
			mi.get_parent().remove_child(mi)
			mi.free()
		else:
			mi.mesh = out


static func _is_accent(m: Material) -> bool:
	return m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled


## Local transform (relative to the hand / bone attachment) of a mounted weapon for a grip dictionary.
func _mount_local_xf(m: Dictionary, g: Dictionary) -> Transform3D:
	var kind := String(m["kind"])
	var id := String(m["id"])
	var left := bool(m["left"])
	var xf: Transform3D
	match kind:
		"gun", "fist", "held":
			var off: Vector3 = g.get("offset", Vector3(0.0, -0.01, 0.0) if kind == "fist" else Vector3(0.06, -0.035, 0.0))
			var rolls: Array = FIST_ROLL.get(id, [0.0, 0.0])
			var roll := float(g.get("roll_l" if left else "roll_r", g.get("roll", rolls[1] if left else rolls[0])))
			xf = ClassDress.gun_xf(body, left, float(g.get("pitch", 0.0)), off, roll)
		"shield":
			xf = ClassDress.shield_xf(body)
		"hip":
			var hp := body.bone_pos("Hips")
			xf = Transform3D(Basis(Vector3.UP, PI / 2), hp + Vector3(-0.22, -0.05, -0.08))
		"pole":
			xf = ClassDress.grip_xf(body, left, float(g.get("tilt", POLE_TILT_ANIME.get(id, 0.0))), float(g.get("roll", 0.0)), float(g.get("yaw", 0.0)))
		_:
			xf = ClassDress.grip_xf(body, left, float(g.get("tilt", 0.0)), float(g.get("roll", 0.0)), float(g.get("yaw", 0.0)))
	if String(m["units"]) == "kaykit":
		xf = xf.scaled_local(Vector3.ONE * MODEL_SCALE)
	elif g.has("scale"):
		xf = xf.scaled_local(Vector3.ONE * float(g["scale"]))
	return body.bone_xf(String(m["bone"])).affine_inverse() * xf


## Grip for a mount while `clip` (abstract `key`) plays: the dress grip, then the shared CLIP_GRIPS row for caster
## poles (right hand), then the dress grip's own "clips" {clip: {...}} and "anims" {key: {...}} overrides.
func _clip_grip(m: Dictionary, clip: String, key: StringName) -> Dictionary:
	var base: Dictionary = m["grip"]
	var out := base
	var layers: Array = []
	if not bool(m["left"]) and String(m["id"]) in CLIP_GRIP_WEAPONS and CLIP_GRIPS.has(clip):
		layers.append(CLIP_GRIPS[clip])
	var bc: Dictionary = base.get("clips", {})
	if bc.has(clip):
		layers.append(bc[clip])
	var ba: Dictionary = base.get("anims", {})
	if ba.has(key):
		layers.append(ba[key])
	if layers.is_empty():
		return base
	out = base.duplicate()
	for l in layers:
		for k in (l as Dictionary):
			out[k] = l[k]
	return out


## Re-grips mounted weapons for the clip that just started; the change eases in over the clip blend.
func _update_clip_grips(clip: String, key: StringName) -> void:
	if rig != "anime" or body == null:
		return
	var any := false
	for m: Dictionary in _mounts:
		if not is_instance_valid(m["node"]):
			continue
		var w: Node3D = m["node"]
		var g := _clip_grip(m, clip, key)
		if g == m.get("cur"):
			continue
		m["cur"] = g
		m["from"] = body.get_two_hand_rest() if bool(m["two"]) and body.is_two_hand(w) else w.transform
		m["to"] = _mount_local_xf(m, g)
		any = true
	if any:
		_grip_t = 0.0


func _update_grip_blend(delta: float) -> void:
	_grip_t = minf(_grip_t + delta / BLEND_TIME, 1.0)
	var k := 1.0 - pow(1.0 - _grip_t, 2.0)
	for m: Dictionary in _mounts:
		if not m.has("to"):
			continue
		if not is_instance_valid(m["node"]):
			continue
		var w: Node3D = m["node"]
		var xf: Transform3D = (m["from"] as Transform3D).interpolate_with(m["to"], k)
		if bool(m["two"]) and body.is_two_hand(w):
			body.set_two_hand_rest(xf)
		else:
			w.transform = xf
		if _grip_t >= 1.0:
			m.erase("from")
			m.erase("to")


## Animated umbrella form change (~0.2 s): each new canopy panel starts at the old form's panel transform and
## eases into place; the gun form's barrel cluster ("Morph_Barrels") grows out of the hub.
func _start_morph(old_panels: Dictionary) -> void:
	_morph.clear()
	for n in find_children("Panel_*", "Node3D", true, false):
		var nd := n as Node3D
		if not old_panels.has(String(nd.name)) or not nd.is_inside_tree():
			continue
		var from: Transform3D = nd.get_parent_node_3d().global_transform.affine_inverse() * (old_panels[String(nd.name)] as Transform3D)
		_morph.append([nd, from, nd.transform])
		nd.transform = from
	for n in find_children("Morph_*", "Node3D", true, false):
		var nd := n as Node3D
		_morph.append([nd, nd.transform.scaled_local(Vector3.ONE * 0.05), nd.transform])
		nd.transform = nd.transform.scaled_local(Vector3.ONE * 0.05)
	_morph_t = 0.0 if not _morph.is_empty() else 1.0


func _update_morph(delta: float) -> void:
	_morph_t = minf(_morph_t + delta / MORPH_TIME, 1.0)
	var k := 1.0 - pow(1.0 - _morph_t, 3.0)
	for m in _morph:
		if not is_instance_valid(m[0]):
			continue
		var nd: Node3D = m[0]
		var a: Transform3D = m[1]
		var b: Transform3D = m[2]
		nd.transform = a.interpolate_with(b, k)
	if _morph_t >= 1.0:
		_morph.clear()


## Fist weapons rolled about the forearm per hand [right, left] (degrees, ClassDress.gun_xf roll): the tonfa rod
## rides the pinky side of both forearms. Dress grips override with roll / roll_r / roll_l.
const FIST_ROLL: Dictionary = {"tonfa": [180.0, 0.0]}
## Caster poles re-gripped while KayKit cast clips play: those clips swing the hand so far that the idle grip
## (tuned for Spell_Simple_*) points the staff head at the floor. Grips found by sampling the right-hand pose of
## five bases over each clip's held frames and maximising "shaft up, head facing forward" (ClassDress.grip_xf
## tilt / yaw / roll, absolute). Dress grips may add their own "clips" / "anims" rows on top.
const CLIP_GRIP_WEAPONS: Array[String] = ["staff", "staff_ring", "cane", "broom", "cross", "great_axe"]
const CLIP_GRIPS: Dictionary = {
	"kk_Ranged_Magic_Summon": {"tilt": 20.0, "yaw": -80.0, "roll": 150.0},
	"kk_Ranged_Magic_Raise": {"tilt": 150.0, "yaw": 80.0, "roll": -135.0},
	"kk_Ranged_Magic_Spellcasting_Long": {"tilt": 20.0, "yaw": -50.0, "roll": -15.0},
	"kk_Ranged_Magic_Shoot": {"tilt": 140.0, "yaw": 140.0, "roll": 30.0},
	"Power Up": {"tilt": 10.0, "yaw": -40.0, "roll": 135.0},
	"Two-hand Blast": {"tilt": 170.0, "yaw": 140.0, "roll": -45.0},
}

## KayKit handslots: pole weapons tilted so heads read "up" in KayKit poses.
const POLE_TILT_KAYKIT: Dictionary = WeaponFactory.POLE_TILT
## Anime grip tilt (degrees the shaft is raised from "forward") per pole weapon.
const POLE_TILT_ANIME: Dictionary = {"staff": 70.0, "staff_ring": 70.0, "broom": 70.0, "cane": 55.0, "cross": 70.0, "umbrella_open": 10.0}


## Stealth (bible: readable, never a smeared half-transparent toon): every mesh swaps to a shared per-visual
## "ghost" material - a dark glassy body with a bright cel rim, alpha-blended with depth writes so the body never
## self-sorts - and the original materials (toon, eyes, weapons; never mutated) come back at alpha 1. 0 hides.
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
		if a >= 0.999:
			if mi.has_meta(&"_pre_stealth"):
				mi.material_override = mi.get_meta(&"_pre_stealth")
				mi.remove_meta(&"_pre_stealth")
			continue
		if not mi.has_meta(&"_pre_stealth"):
			mi.set_meta(&"_pre_stealth", mi.material_override)
		mi.material_override = _get_stealth_mat()
	if _stealth_mat:
		_stealth_mat.set_shader_parameter("alpha", a)
	if _overlay:
		_overlay.set_shader_parameter("alpha_mul", a)


var _stealth_mat: ShaderMaterial
static var _stealth_shader: Shader


func _get_stealth_mat() -> ShaderMaterial:
	if _stealth_mat == null:
		if _stealth_shader == null:
			_stealth_shader = Shader.new()
			_stealth_shader.code = """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_always, cull_back, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float alpha = 0.4;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.5, 0.56, f);
	float shimmer = 0.5 + 0.5 * sin(TIME * 4.0 + VERTEX.y * 18.0);
	ALBEDO = mix(tint.rgb * 0.25, mix(tint.rgb, vec3(0.9, 0.97, 1.0), 0.6) * 1.4, rim);
	ALPHA = clamp(alpha * (0.45 + 0.55 * rim + 0.08 * shimmer), 0.0, 1.0);
}
"""
		_stealth_mat = ShaderMaterial.new()
		_stealth_mat.shader = _stealth_shader
		var t := tint if tint != Color.WHITE else Color(0.4, 0.6, 1.0)
		_stealth_mat.set_shader_parameter("tint", t)
	return _stealth_mat


func set_status_visual(mask: int) -> void:
	if mask == _status_mask:
		return
	_status_mask = mask
	_frozen = _has(mask, &"freeze")
	if anim_player:
		anim_player.speed_scale = 0.0 if _frozen else _play_speed
	# shield bubble (cyan barrier; gold for invulnerable)
	if _has(mask, &"shield") or _has(mask, &"invuln"):
		if _bubble == null:
			_bubble = MeshInstance3D.new()
			_bubble.name = "ShieldBubble"
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 32
			sm.rings = 16
			_bubble.mesh = sm
			_bubble.material_override = _get_bubble_mat()
			_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_bubble.scale = Vector3(0.62, 0.62, 0.62) * height
			_bubble.position = Vector3(0, height * 0.5, 0)
			add_child(_bubble)
		_bubble.visible = true
		_bubble.set_instance_shader_parameter("tint", Color(1.0, 0.85, 0.35, 1.0) if _has(mask, &"invuln") and not _has(mask, &"shield") else Color(0.45, 0.85, 1.0, 1.0))
	elif _bubble:
		_bubble.visible = false
	# stun / sleep / confusion: gold stars circling the head
	if _has(mask, &"stun") or _has(mask, &"sleep") or _has(mask, &"confusion"):
		if _stars == null:
			_stars = _make_stars()
			add_child(_stars)
		_stars.visible = true
	elif _stars:
		_stars.visible = false
	# freeze: ice crystals around the legs
	if _frozen:
		if _ice == null:
			_ice = _make_ice()
			add_child(_ice)
		_ice.visible = true
	elif _ice:
		_ice.visible = false
	# burn: rising embers
	if _has(mask, &"burn"):
		if _embers == null:
			_embers = _make_embers()
			add_child(_embers)
		_embers.emitting = true
		_embers.visible = true
	elif _embers:
		_embers.emitting = false
	_apply_overlay(_overlay_active())


func flash_hit() -> void:
	_flash = 0.12
	_apply_overlay(true)


## Zone tint (ENV integration): rim light colour and shadow/ambient multiplier for this visual's toon materials
## (body, costume, weapons; KayKit mobs too). Shared costume/weapon materials make it effectively global.
func set_zone_tint(rim: Color, ambient: Color) -> void:
	var mix := 0.7 if rim.a > 0.0 else 0.0
	if body:
		body.set_zone_tint(rim, ambient, mix)
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mats: Array = []
		if mi.material_override:
			mats.append(mi.material_override)
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(si)
				if m == null:
					m = mi.mesh.surface_get_material(si)
				if m:
					mats.append(m)
		for m in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader == AnimeBody.TOON:
				(m as ShaderMaterial).set_shader_parameter("zone_rim", Color(rim.r, rim.g, rim.b, mix))
				(m as ShaderMaterial).set_shader_parameter("zone_ambient", ambient)


## Sets the zone for every CharacterVisual (existing and future). `zone` is an ENV preset name ("frost",
## "glory_stage", "blossom", "golden_ruins", "lava", "moon"); "" resets to neutral. Call from the match scene / map.
static func set_zone(zone: String, tree: SceneTree = null) -> void:
	var rim := Color.WHITE
	var amb := Color.WHITE
	var on := zone != "" and ZONE_TINTS.has(zone)
	if on:
		rim = ZONE_TINTS[zone][0]
		amb = ZONE_TINTS[zone][1]
	set_zone_colors(rim, amb, on, tree)


static func set_zone_colors(rim: Color, ambient: Color, on := true, tree: SceneTree = null) -> void:
	_zone_rim = Color(rim.r, rim.g, rim.b, 1.0 if on else 0.0)
	_zone_ambient = ambient if on else Color.WHITE
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for v in tree.get_nodes_in_group(&"character_visuals"):
		if on:
			(v as CharacterVisual).set_zone_tint(rim, ambient)
		else:
			(v as CharacterVisual).set_zone_tint(Color(1, 1, 1, 0), Color.WHITE)


func get_hand_position(right := true) -> Vector3:
	var att := _hand_r if right else _hand_l
	if att == null or not att.is_inside_tree():
		return global_position + Vector3(0, height * 0.55, 0) if is_inside_tree() else Vector3(0, height * 0.55, 0)
	return att.global_position


func get_head_position() -> Vector3:
	if _head == null or not _head.is_inside_tree():
		return global_position + Vector3(0, height, 0)
	if rig == "anime":
		return _head.global_position + Vector3(0, 0.3, 0)
	return _head.global_position + Vector3(0, 0.6 * MODEL_SCALE, 0)


func has_clip_for(key: StringName) -> bool:
	return get_library(rig).has_animation(StringName(resolve_key(key)))


# --------------------------------------------------------------------------------------------
# Internals

func _process(delta: float) -> void:
	_time += delta
	if _morph_t < 1.0:
		_update_morph(delta)
	if _grip_t < 1.0:
		_update_grip_blend(delta)
	if _stars and _stars.visible:
		_stars.rotate_y(delta * 3.5)
		if _head and _head.is_inside_tree():
			_stars.global_position = get_head_position() + Vector3(0, 0.12, 0)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_apply_overlay(_overlay_active())
	_update_overlay_params()
	_update_near_fade(delta)
	if body:
		if visible and _near:
			body.update_face()
		_cull_t -= delta
		if _cull_t <= 0.0:
			_cull_t = 0.5 + randf() * 0.1
			_update_lod()


## Spring bones and cloth only simulate within SPRING_CULL_DIST of the active camera.
func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := cam == null or cam.global_position.distance_to(global_position) <= SPRING_CULL_DIST
	if near == _near:
		return
	_near = near
	body.set_springs_active(near)
	for c in body.find_children("*", "AnimeCloth", true, false):
		(c as AnimeCloth).active = near


func _on_anim_finished(_clip: StringName) -> void:
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
		if is_instance_valid(mi):
			mi.material_overlay = _overlay if on else null
	_update_overlay_params()


## Overlay colours (bible 5.2 element palette): ice-cyan freeze, ember burn, toxic poison, gold super armor rim,
## red mark rim, white hit flash.
func _update_overlay_params() -> void:
	if _overlay == null or _meshes.is_empty() or _meshes[0].material_overlay == null:
		return
	var fill := Color(0, 0, 0, 0)
	var rim := Color(0, 0, 0, 0)
	if _has(_status_mask, &"freeze"):
		fill = Color(0.5, 0.88, 1.0, 0.5)
		rim = Color(0.92, 0.98, 1.0, 1.0)
	elif _has(_status_mask, &"burn"):
		var fl := 0.3 + 0.14 * sin(_time * 22.0) + 0.08 * sin(_time * 37.0)
		fill = Color(1.0, 0.42, 0.06, fl)
		rim = Color(1.0, 0.62, 0.12, 0.95)
	elif _has(_status_mask, &"poison"):
		fill = Color(0.48, 1.0, 0.42, 0.12 + 0.05 * sin(_time * 6.0))
		rim = Color(0.48, 1.0, 0.42, 0.55)
	if _has(_status_mask, &"super_armor"):
		rim = Color(1.0, 0.82, 0.3, 0.85 + 0.15 * sin(_time * 10.0))
	elif _has(_status_mask, &"mark") and rim.a == 0.0:
		rim = Color(1.0, 0.25, 0.3, 0.75)
	if _flash > 0.0:
		fill = Color(1, 1, 1, 0.8 * clampf(_flash / 0.12, 0.0, 1.0))
	_overlay.set_shader_parameter("fill", fill)
	_overlay.set_shader_parameter("rim", rim)
	_overlay.set_shader_parameter("time", _time)


func _all_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in find_children("*", "MeshInstance3D", true, false):
		if n != _bubble and not (_stars and _stars.is_ancestor_of(n)) and not (_ice and _ice.is_ancestor_of(n)):
			out.append(n as MeshInstance3D)
	return out


## Three faceted gold stars and a thin gold halo ring, toon-shaded with an HDR core (blooms slightly).
func _make_stars() -> Node3D:
	var root := Node3D.new()
	root.name = "StunStars"
	root.top_level = true
	var star := AnimeGear.extrude(AnimeGear.star_poly(0.085, 5, 0.45), 0.03, 0.01)
	var mat := AnimeGear.toon(Color("#FFD54A"), {"emit": Color(1.0, 0.75, 0.2) * 0.9, "shade": Color(0.85, 0.6, 0.5), "rim": Color.WHITE, "rim_strength": 1.0})
	for i in 3:
		var s := MeshInstance3D.new()
		s.mesh = star
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := TAU * float(i) / 3.0
		s.position = Vector3(cos(ang) * 0.32, sin(ang * 2.0) * 0.04, sin(ang) * 0.32)
		s.rotation = Vector3(0, -ang, 0.3)
		root.add_child(s)
	var ring := MeshInstance3D.new()
	ring.mesh = AnimeGear.lathe([Vector2(0.31, -0.004), Vector2(0.325, 0.004)], 40)
	ring.material_override = AnimeGear.glow(Color(1.0, 0.85, 0.4), 2.0, true, 0.6)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


## Freeze: a ring of faceted ice crystals encasing the feet and shins.
func _make_ice() -> Node3D:
	var root := Node3D.new()
	root.name = "IceShell"
	var mat := AnimeGear.toon(Color("#BFEFFF"), {"emit": Color(0.25, 0.55, 0.8) * 0.5, "shade": Color(0.55, 0.75, 1.0), "rim": Color.WHITE, "rim_strength": 1.2})
	var crystal := AnimeGear.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.05), Vector2(0.06, 0.32), Vector2(0.0, 0.5)], 5)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = crystal
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := 0.28 if i % 2 == 0 else 0.22
		var s := 0.7 + 0.5 * float((i * 37) % 5) / 4.0
		mi.transform = Transform3D(Basis(Vector3(sin(a), 0, -cos(a)).normalized(), 0.35 + 0.1 * (i % 3)).scaled(Vector3.ONE * s), Vector3(cos(a) * r, 0.0, sin(a) * r))
		root.add_child(mi)
	return root


## Burn: additive ember sparks rising off the body.
func _make_embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = 28
	p.lifetime = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.25, height * 0.4, 0.2)
	pm.gravity = Vector3(0, 2.2, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 1))
	grad.set_color(1, Color(1.0, 0.3, 0.05, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = AnimeGear.spark_tex()
	qm.albedo_color = Color(2.5, 1.4, 0.5)
	q.material = qm
	p.draw_pass_1 = q
	p.position = Vector3(0, height * 0.5, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Status overlay drawn over every body surface: flat fill + a hard cel rim band (no smooth glow blobs).
static func _get_overlay_shader() -> Shader:
	if _overlay_shader == null:
		_overlay_shader = Shader.new()
		_overlay_shader.code = """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 fill : source_color = vec4(0.0);
uniform vec4 rim : source_color = vec4(0.0);
uniform float alpha_mul = 1.0;
uniform float time = 0.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float band = smoothstep(0.52, 0.58, f);
	float inner = smoothstep(0.25, 0.75, f) * 0.3;
	float k = clamp((band + inner) * rim.a, 0.0, 1.0);
	vec3 c = mix(fill.rgb, rim.rgb, k);
	ALBEDO = c * (1.0 + band * rim.a * 1.4);
	ALPHA = clamp(max(fill.a, (band * 0.95 + inner) * rim.a), 0.0, 1.0) * alpha_mul;
}
"""
	return _overlay_shader


## Shield bubble: hard fresnel band + faint hexagonal barrier lines, additive.
static func _get_bubble_mat() -> Material:
	if _bubble_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(0.45, 0.85, 1.0, 1.0);
float hexd(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(0.7, 0.76, f);
	float soft = pow(f, 3.0) * 0.6;
	vec2 uv = UV * vec2(28.0, 14.0);
	vec2 g = vec2(uv.x + mod(floor(uv.y), 2.0) * 0.5, uv.y);
	vec2 cell = fract(g) - 0.5;
	float hex = smoothstep(0.43, 0.47, hexd(cell));
	float sweep = smoothstep(0.0, 0.12, fract(UV.y * 1.0 - TIME * 0.35)) * (1.0 - smoothstep(0.12, 0.2, fract(UV.y - TIME * 0.35)));
	ALBEDO = tint.rgb * (edge * 1.6 + soft + hex * 0.12 * (0.4 + f) + sweep * 0.25 + 0.02);
	ALPHA = 1.0;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_bubble_mat = m
	return _bubble_mat


# --------------------------------------------------------------------------------------------
# Near-camera fade (feelfix, visual glitches): characters and their weapons right next to the lens, and any
# character standing between the camera and the player it follows, are screen-door dithered (toon shader instance
# uniforms near_fade_end / fade_mul) so allies never block the view. Only visuals in the main viewport (never
# portraits or previews). Non-toon surfaces (eyes, glow accents) follow via GeometryInstance3D.transparency.

const NEAR_FADE_END := 2.8            # view metres: solid beyond this, gone below 35% of it (per pixel)
const NEAR_FADE_END_FOCUS := 1.1      # the camera's own target only fades when the camera is jammed into it
const OCCLUDER_FADE := 0.3            # whole-body fade while standing in the camera -> player line
const FOREGROUND_NEAR := 3.0          # foreground characters: FOREGROUND_FADE at this camera distance ...
const FOREGROUND_FAR := 5.0           # ... solid from here
const FOREGROUND_FADE := 0.3
const OCCLUDER_WIDTH := 0.3          # body half width as a fraction of its on-screen height
const OCCLUDER_PROBE_Y: Array[float] = [0.25, 0.7, 1.1, 1.6]   # followed player's feet, waist, chest, head (m)

var near_fade: float = 1.0            # current whole-body fade (1 = solid), for diagnostics
var _nf_target := 1.0
var _nf_t := 0.0
var _nf_end := 0.0
var _nf_obj := 1.0                    # object-level near factor for non-toon surfaces
var _nf_meshes: Array[MeshInstance3D] = []
var _nf_plain: Array[MeshInstance3D] = []   # meshes carrying non-shader (BaseMaterial3D) surfaces
var _nf_applied := Vector3(-1, -1, -1)      # (end, fade_mul, plain transparency) last pushed


func _update_near_fade(delta: float) -> void:
	if not is_inside_tree() or get_viewport() != get_tree().root:
		return
	_nf_t -= delta
	if _nf_t <= 0.0:
		_nf_t = 0.1
		_refresh_near_fade()
	near_fade = move_toward(near_fade, _nf_target, delta * 5.0)
	var plain := 1.0 - minf(near_fade, _nf_obj)
	var want := Vector3(_nf_end, near_fade, plain)
	if want.is_equal_approx(_nf_applied):
		return
	_nf_applied = want
	for mi in _nf_meshes:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(&"near_fade_end", _nf_end)
			mi.set_instance_shader_parameter(&"fade_mul", near_fade)
	for mi in _nf_plain:
		if is_instance_valid(mi):
			mi.transparency = plain


func _refresh_near_fade() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var focus: Node3D = null
	var n: Node = cam.get_parent()
	for i in 4:
		if n == null:
			break
		var t: Variant = n.get(&"target")
		if t is Node3D and is_instance_valid(t):
			focus = t
			break
		n = n.get_parent()
	var is_focus := focus != null and focus.is_ancestor_of(self)
	var end := NEAR_FADE_END_FOCUS if is_focus else NEAR_FADE_END
	var cp := cam.global_position
	var center := global_position + Vector3(0, height * 0.55, 0)
	var d := cp.distance_to(center)
	_nf_obj = smoothstep(end * 0.35, end, d)
	_nf_target = 1.0
	if focus != null and not is_focus:
		var fp := focus.global_position + Vector3(0, 1.1, 0)
		# foreground: well in front of the followed player and close to the lens (it fills a big part of the
		# frame, e.g. allies running past the camera) -> dithered down with distance
		if d < cp.distance_to(fp) - 1.5:
			_nf_target = lerpf(FOREGROUND_FADE, 1.0, smoothstep(FOREGROUND_NEAR, FOREGROUND_FAR, d))
		# occluder: nearer than the followed player and covering any of its feet / waist / chest / head on screen
		# (a bot crossing in front of the player's legs blocks the view just as much as one over its chest)
		var feet := global_position
		var top := global_position + Vector3(0, height * scale.y, 0)
		if d < cp.distance_to(fp) - 0.6 and not cam.is_position_behind(fp) and not cam.is_position_behind(feet) 				and not cam.is_position_behind(top):
			var s_feet := cam.unproject_position(feet)
			var s_top := cam.unproject_position(top)
			var half_w := maxf(absf(s_feet.y - s_top.y) * OCCLUDER_WIDTH, 8.0)
			var r := Rect2(Vector2(minf(s_feet.x, s_top.x) - half_w, minf(s_top.y, s_feet.y)),
				Vector2(absf(s_feet.x - s_top.x) + half_w * 2.0, absf(s_feet.y - s_top.y)))
			for hy: float in OCCLUDER_PROBE_Y:
				if r.has_point(cam.unproject_position(focus.global_position + Vector3(0, hy, 0))):
					_nf_target = minf(_nf_target, OCCLUDER_FADE)
					break
	# mesh lists (weapons swap at runtime); a new mesh gets the current values on the next push
	var meshes := _all_meshes()
	if meshes.size() != _nf_meshes.size() or end != _nf_end:
		_nf_end = end
		_nf_meshes = meshes
		_nf_plain.clear()
		for mi in meshes:
			if _has_plain_surface(mi):
				_nf_plain.append(mi)
		_nf_applied = Vector3(-1, -1, -1)


static func _has_plain_surface(mi: MeshInstance3D) -> bool:
	if mi.material_override != null:
		return mi.material_override is BaseMaterial3D
	if mi.mesh == null:
		return false
	for si in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(si)
		if m == null:
			m = mi.mesh.surface_get_material(si)
		if m is BaseMaterial3D:
			return true
	return false
