extends Node
## Fx autoload (owner: VFX track) - cosmetic VFX/SFX spawning, network-replicated (ARCHITECTURE §7.3).
##
## Networking: when this peer is the host of a real (non-offline) multiplayer session, every public call
## is broadcast with @rpc("authority", "call_local") so all peers play it. Offline / no peer / client-side
## calls just play locally. Nothing here touches gameplay state (hit-stop only pauses CharacterVisual
## AnimationMixers locally, never Engine.time_scale or physics).
##
## Conventions
## - Positions are global. `dir` / `yaw` follow Godot: forward = -Z rotated by yaw about +Y.
## - Area "line" shapes start at `pos` and extend `length` metres forward along `yaw`, `width` wide.
## - Colour Color.WHITE means "use the effect's default (element) colour".
##
## Look (art bible section 5, ported from the look-dev slice LdVfx): crescent slash smears with echo arcs,
## rotating glyph circles per element, cel-banded energy with white-hot HDR cores, shockwave rings and radial
## ray bursts, painted puffy dust / cel flame tongues, flat-shaded debris with outlines, light-streak ribbons,
## impact frames and hit-stop. Recipes live in res://visuals/vfx_*.gd, shaders in res://visuals/shaders/.
##
## Performance: every one-shot piece is a pooled VfxFlash / CPUParticles3D / damage number stepped by this
## node's single _process loop; all pieces of one shader share a single material (per-effect values are
## instance uniforms). A soft budget (MAX_LIVE_NODES) drops cosmetic extras, a hard one keeps only core pieces.

## CORE checks this to decide whether to draw its own debug meshes.
var is_stub: bool = false

const Lib := preload("res://visuals/vfx_lib.gd")
const Effects := preload("res://visuals/vfx_effects.gd")
const Projectiles := preload("res://visuals/vfx_projectiles.gd")
const Ground := preload("res://visuals/vfx_ground.gd")
const HitStop := preload("res://visuals/vfx_hitstop.gd")
const DamageNumber := preload("res://visuals/vfx_numbers.gd")
const FlashNode := preload("res://visuals/vfx_flash.gd")
const Ribbon := preload("res://visuals/vfx_ribbon.gd")

const SFX_DIR := "res://assets/sfx/"
const MAX_LIVE_NODES := 260
const HARD_LIVE_NODES := 560
const MAX_VOICES := 24
## 3D attenuation tuned for 40-60 m arenas: full volume inside ~10 m, about -12 dB at 40 m, silent past MAX_DIST.
## "far" sounds (explosions, big guns, ultimates, boss roars) carry across the whole map.
const UNIT_SIZE := 10.0
const MAX_DIST := 65.0
const FAR_UNIT_SIZE := 20.0
const FAR_MAX_DIST := 110.0
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const POOL_FLASH := 360
const POOL_BURST := 160
const POOL_NUMBERS := 48
const MAX_LIGHTS := 6

const EFFECT_NAMES: Array[StringName] = [&"hit_spark", &"hit_heavy", &"slash_arc", &"launch_burst", &"land_dust", &"cast_glow",
	&"heal_burst", &"buff_aura", &"debuff_puff", &"explosion", &"ice_burst", &"lightning_strike", &"fire_burst", &"holy_burst",
	&"dark_burst", &"poison_cloud", &"smoke", &"blink", &"dash_trail", &"summon_circle", &"block_spark", &"death", &"ultimate_flash"]
const PROJECTILE_VISUALS: Array[String] = ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi",
	"dragon", "lightning", "cannonball", "flask", "scythe"]
const AREA_VISUALS: Array[String] = ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]

## Default zone colours (bible 5.2 element mid colours).
const AREA_COLORS: Dictionary = {
	"fire": Color("#FF8A1F"), "ice": Color("#7FE8FF"), "lightning": Color("#B8F0FF"), "holy": Color("#FFD86A"),
	"dark": Color("#8A4CFF"), "poison": Color("#7CFF6B"), "wind": Color("#B8FFE0"), "earth": Color("#C08A4A"),
	"blood": Color("#E0232E"), "rune": Color("#8A4CFF"), "thorn": Color("#7CCB3A"),
}
## Default projectile colours (mid colour of each visual's palette).
const PROJ_COLORS: Dictionary = {
	"orb": Color("#8A4CFF"), "bullet": Color("#FFC43A"), "arrow": Color("#CFE6FF"), "grenade": Color("#FFC43A"),
	"shuriken": Color("#CFE6FF"), "wave": Color("#CFE6FF"), "missile": Color("#FFC43A"), "star": Color("#FFD86A"),
	"blood": Color("#E0232E"), "qi": Color("#7FC4FF"), "dragon": Color("#FF8A1F"), "lightning": Color("#B8F0FF"),
	"cannonball": Color("#FFC43A"), "flask": Color("#7CFF6B"), "scythe": Color("#8A4CFF"),
}
const NUMBER_COLORS: Dictionary = DamageNumber.COLORS

## --- SFX library (assets/sfx/<category>/, see assets/CREDITS.md) ------------------------------------------------
## sound name -> entry. Entry keys (all optional):
##   set + n   files "<set>_01.ogg" .. "<set>_<n>.ogg" under SFX_DIR (one picked at random, never the same twice)
##   files     explicit file list (relative to SFX_DIR)
##   alias     play another entry instead            layers  extra entries played together (whoosh + impact, thump...)
##   db        base volume (dB)                      vr      random volume range (+-dB, default 1.5)
##   p         base pitch (default 1)                pr      random pitch range (+-fraction, default 0.06)
##   max       max simultaneous voices of this name (default 4)
##   pri       priority 0 (footsteps, layers) .. 3 (ultimates, bosses); own > enemy > ally is added on top
##   far       big sound heard across the whole 40-60 m arena     fam   family for de-duplication (see _do_sfx)
##   ui        non-positional (UI bus unless `bus` says otherwise)  duck  ducks the Music bus (Music.duck)
## Generic names (hit, hit_heavy, swing, slash, shot, footstep) are resolved per caster weapon / map surface first.
## Unknown names fall back to "hit" with a one-time warning. "none" is silent.
const SFX_MAP: Dictionary = {
	# ---- weapon swings
	&"swing_light": {"set": "blade/swing_light", "n": 6, "db": -3.0, "pr": 0.1, "fam": &"swing"},
	&"swing_fist": {"set": "blade/swing_light", "n": 6, "db": -5.0, "p": 1.15, "pr": 0.1, "fam": &"swing"},
	&"swing_claw": {"set": "blade/swing_dagger", "n": 3, "db": -3.0, "p": 1.1, "fam": &"swing"},
	&"swing_dagger": {"set": "blade/swing_dagger", "n": 3, "db": -2.0, "fam": &"swing"},
	&"swing_blade": {"set": "blade/swing_blade", "n": 6, "db": -1.0, "fam": &"swing"},
	&"swing_katana": {"set": "blade/swing_blade", "n": 6, "db": -1.0, "p": 1.08, "fam": &"swing"},
	&"swing_saber": {"set": "blade/swing_blade", "n": 6, "db": -1.5, "p": 1.04, "layers": [&"saber_hum"], "fam": &"swing"},
	&"saber_hum": {"set": "energy/shield", "n": 3, "db": -12.0, "p": 1.7, "pr": 0.08, "max": 3, "pri": 0},
	&"swing_heavy": {"set": "blade/swing_heavy", "n": 6, "pr": 0.05, "fam": &"swing"},
	&"swing_scythe": {"set": "blade/swing_heavy", "n": 6, "p": 0.9, "fam": &"swing"},
	&"swing_spear": {"set": "blade/swing_heavy", "n": 6, "db": -1.5, "p": 1.12, "fam": &"swing"},
	&"swing_staff": {"set": "blade/swing_light", "n": 6, "db": -3.0, "p": 0.85, "fam": &"swing"},
	&"swing_spin": {"set": "blade/swing_heavy", "n": 6, "p": 0.95, "layers": [&"dash"], "fam": &"swing"},
	&"unsheathe": {"set": "blade/unsheathe", "n": 3, "db": -2.0},
	&"slash_hit": {"set": "blade/slash_hit", "n": 5, "db": -1.0, "fam": &"hit", "max": 5},
	&"stab": {"set": "blade/slash_hit", "n": 5, "db": -1.0, "p": 1.15, "layers": [&"hit_body_soft"], "fam": &"hit", "max": 5},
	# ---- hits on the victim (Fx picks the variant from the attacker's weapon; heavy / crit add a low thump)
	&"hit_body_soft": {"set": "blunt/punch_light", "n": 5, "db": -10.0, "pr": 0.1, "max": 4, "pri": 0},
	&"hit_blade": {"set": "blade/slash_hit", "n": 5, "db": -1.0, "layers": [&"hit_body_soft"], "fam": &"hit", "max": 5},
	&"hit_saber": {"set": "blade/slash_hit", "n": 5, "db": -2.0, "p": 1.1, "layers": [&"saber_hum", &"hit_body_soft"], "fam": &"hit", "max": 5},
	&"hit_blade_heavy": {"set": "blade/slash_hit", "n": 5, "p": 0.85, "layers": [&"blunt_heavy"], "fam": &"hit", "max": 5, "pri": 2},
	&"hit_blunt": {"set": "blunt/punch_light", "n": 5, "fam": &"hit", "max": 5},
	&"hit_blunt_heavy": {"set": "blunt/punch_heavy", "n": 5, "layers": [&"thump"], "fam": &"hit", "max": 5, "pri": 2},
	&"hit_wood": {"set": "blunt/wood", "n": 4, "db": -1.0, "layers": [&"hit_body_soft"], "fam": &"hit"},
	&"hit_pole": {"set": "metal/haft", "n": 3, "db": -1.0, "layers": [&"hit_body_soft"], "fam": &"hit"},
	&"hit_claw": {"set": "blade/slash_hit", "n": 5, "db": -2.0, "p": 1.2, "layers": [&"hit_body_soft"], "fam": &"hit", "max": 5},
	&"hit_bullet": {"set": "blunt/punch_light", "n": 5, "db": -3.0, "p": 1.3, "fam": &"hit", "max": 5},
	&"hit_arrow": {"set": "blade/slash_hit", "n": 5, "db": -3.0, "p": 1.3, "fam": &"hit"},
	&"hit_magic": {"set": "blunt/punch_light", "n": 5, "db": -7.0, "p": 0.85, "layers": [&"shimmer"], "fam": &"hit"},
	&"crit": {"set": "blunt/thump", "n": 2, "db": -2.0, "pr": 0.05, "max": 3, "pri": 2},
	&"thump": {"set": "blunt/thump", "n": 2, "db": -4.0, "pr": 0.05, "max": 3},
	&"thump_soft": {"set": "blunt/thump", "n": 2, "db": -12.0, "pr": 0.05, "max": 2, "pri": 0},
	&"blunt_light": {"set": "blunt/punch_light", "n": 5, "fam": &"hit", "max": 5},
	&"blunt_medium": {"set": "blunt/punch_heavy", "n": 5, "fam": &"hit", "max": 5},
	&"blunt_heavy": {"set": "blunt/blunt_heavy", "n": 5, "layers": [&"thump"], "fam": &"hit"},
	&"kick": {"set": "blunt/kick", "n": 3, "fam": &"hit"},
	&"wood": {"set": "blunt/wood", "n": 4},
	# ---- metal: guard, parry, shields
	&"block": {"set": "metal/block", "n": 5, "db": -1.0, "pri": 2, "fam": &"block"},
	&"parry": {"set": "metal/clash", "n": 8, "pri": 2, "fam": &"block"},
	&"shield": {"set": "metal/shield", "n": 5, "db": -1.0, "pri": 2, "fam": &"block"},
	&"clash": {"set": "metal/clash", "n": 8, "fam": &"block"},
	&"metal": {"set": "metal/metal_heavy", "n": 4},
	&"metal_light": {"set": "metal/metal_light", "n": 3},
	&"metal_tick": {"set": "metal/metal_light", "n": 3, "db": -12.0, "p": 1.5, "pri": 0},
	&"mace": {"set": "metal/mace", "n": 3, "layers": [&"thump"], "fam": &"hit"},
	&"chain": {"set": "metal/chain", "n": 3},
	# ---- guns, launchers, thrown
	&"gun_revolver": {"set": "gun/revolver", "n": 5, "db": -1.0, "pr": 0.04, "far": true, "fam": &"gun"},
	&"gun_pistol": {"set": "gun/pistol", "n": 6, "db": -2.0, "pr": 0.05, "fam": &"gun"},
	&"gun_pistol_heavy": {"set": "gun/pistol", "n": 6, "db": -1.0, "p": 0.88, "pr": 0.04, "layers": [&"thump_soft"], "fam": &"gun"},
	&"gun_pistol_stun": {"set": "gun/pistol", "n": 6, "db": -2.0, "p": 0.95, "pr": 0.04, "layers": [&"energy_shot"], "fam": &"gun"},
	&"gun_rifle": {"set": "gun/rifle", "n": 5, "db": -1.0, "pr": 0.04, "max": 3, "far": true, "fam": &"gun"},
	&"gun_sniper": {"set": "gun/rifle", "n": 5, "p": 0.85, "pr": 0.03, "max": 2, "far": true, "pri": 2, "layers": [&"thump"], "fam": &"gun"},
	&"gun_gatling": {"set": "gun/smg", "n": 5, "db": -3.0, "pr": 0.06, "fam": &"gun"},
	&"gun_shotgun": {"set": "gun/shotgun", "n": 4, "db": -1.0, "max": 3, "far": true, "fam": &"gun"},
	&"gun_cannon": {"set": "gun/cannon", "n": 5, "pr": 0.05, "max": 3, "far": true, "layers": [&"thump"], "fam": &"gun"},
	&"missile": {"set": "gun/missile", "n": 3, "db": -2.0, "max": 3, "fam": &"gun"},
	&"laser": {"set": "gun/laser", "n": 4, "db": -2.0, "max": 3},
	&"beam": {"set": "gun/laser", "n": 4, "db": -1.0, "p": 0.8, "max": 2, "layers": [&"crackle"]},
	&"energy_shot": {"set": "gun/laser_small", "n": 3, "db": -3.0},
	&"reload": {"set": "gun/click", "n": 3, "db": -3.0, "pri": 0},
	&"bow_shot": {"set": "blade/swing_light", "n": 6, "db": -2.0, "p": 1.25, "layers": [&"bow_twang"], "fam": &"gun"},
	&"bow_twang": {"set": "blunt/wood", "n": 4, "db": -10.0, "p": 1.6, "pri": 0},
	&"throw": {"set": "blade/swing_heavy", "n": 6, "db": -2.0, "p": 1.1, "fam": &"swing"},
	&"throw_light": {"set": "blade/swing_light", "n": 6, "db": -3.0, "p": 0.95, "fam": &"swing"},
	&"grenade_throw": {"set": "blade/swing_light", "n": 6, "db": -3.0, "p": 0.9, "layers": [&"grenade_pin"], "fam": &"swing"},
	&"grenade_pin": {"set": "gun/click", "n": 3, "db": -6.0, "p": 1.2, "pr": 0.05, "pri": 0},
	&"shuriken": {"set": "blade/swing_light", "n": 6, "db": -3.0, "p": 1.35, "layers": [&"metal_tick"], "fam": &"swing"},
	&"trap_set": {"set": "gun/click", "n": 3, "db": -2.0},
	# ---- explosions
	&"explosion_small": {"set": "explosion/small", "n": 6, "db": -1.0, "far": true, "fam": &"explosion"},
	&"explosion_large": {"set": "explosion/large", "n": 4, "max": 3, "far": true, "pri": 2, "layers": [&"thump"], "fam": &"explosion"},
	&"explosion_crunch": {"set": "explosion/crunch", "n": 3, "db": -1.0, "fam": &"explosion"},
	# ---- elements
	&"fire_cast": {"set": "magic_fire/fire_cast", "n": 3, "fam": &"fire"},
	&"fire_charge": {"set": "magic_fire/fire_charge", "n": 1, "pr": 0.08},
	&"fire_hit": {"set": "magic_fire/fire_hit", "n": 3, "fam": &"fire"},
	&"fire_burst": {"set": "magic_fire/fire_burst", "n": 4, "fam": &"fire"},
	&"fire_big": {"set": "magic_fire/fire_big", "n": 1, "far": true, "pri": 2, "max": 2, "fam": &"fire"},
	&"ice_cast": {"set": "magic_ice/ice_cast", "n": 3, "fam": &"ice"},
	&"ice_charge": {"set": "magic_ice/ice_charge", "n": 1, "pr": 0.08},
	&"ice_hit": {"set": "magic_ice/ice_hit", "n": 3, "fam": &"ice"},
	&"ice_big": {"set": "magic_ice/ice_big", "n": 1, "far": true, "pri": 2, "max": 2, "layers": [&"shatter"], "fam": &"ice"},
	&"freeze": {"set": "magic_ice/freeze", "n": 3, "layers": [&"ice_hit"], "fam": &"ice"},
	&"shatter": {"set": "magic_ice/shatter", "n": 4, "db": -2.0, "fam": &"ice"},
	&"lightning": {"set": "magic_lightning/zap_hit", "n": 3, "layers": [&"crackle"], "fam": &"lightning"},
	&"lightning_cast": {"set": "magic_lightning/zap_cast", "n": 3, "fam": &"lightning"},
	&"lightning_charge": {"set": "magic_lightning/zap_charge", "n": 1, "pr": 0.08},
	&"crackle": {"set": "magic_lightning/crackle", "n": 3, "db": -7.0, "max": 3, "pri": 0},
	&"thunder": {"set": "magic_lightning/thunder", "n": 2, "max": 2, "far": true, "pri": 2, "layers": [&"lightning"], "fam": &"lightning"},
	&"holy": {"set": "magic_holy/holy_hit", "n": 3, "layers": [&"bell_soft"], "fam": &"holy"},
	&"holy_cast": {"set": "magic_holy/chime", "n": 2, "db": -1.0, "fam": &"holy"},
	&"bell": {"set": "magic_holy/bell", "n": 3},
	&"bell_soft": {"set": "magic_holy/bell", "n": 3, "db": -9.0, "p": 1.2, "pri": 0},
	&"gong": {"set": "magic_holy/gong", "n": 2, "max": 2, "far": true, "pri": 2},
	&"heal": {"set": "magic_holy/heal", "n": 2, "db": -2.0, "max": 3, "fam": &"heal"},
	&"heal_big": {"set": "magic_holy/heal_full", "n": 1, "max": 2, "pri": 2, "fam": &"heal"},
	&"dark": {"set": "magic_dark/shade", "n": 5, "fam": &"dark"},
	&"shade_soft": {"set": "magic_dark/shade", "n": 5, "db": -9.0, "pri": 0},
	&"curse": {"set": "magic_dark/curse", "n": 2, "fam": &"dark"},
	&"dark_chant": {"set": "magic_dark/chant", "n": 1, "max": 2, "pri": 2},
	&"spirit": {"set": "magic_dark/spirit", "n": 2},
	&"blood": {"set": "magic_poison/slime", "n": 4, "p": 0.8, "layers": [&"slash_hit"], "fam": &"dark"},
	&"poison": {"set": "magic_poison/bubble", "n": 3, "layers": [&"slime"], "fam": &"poison"},
	&"slime": {"set": "magic_poison/slime", "n": 4, "db": -4.0},
	&"wind": {"set": "magic_wind/wind", "n": 3, "fam": &"wind"},
	&"wind_soft": {"set": "magic_wind/wind", "n": 3, "db": -9.0, "pri": 0},
	&"earth": {"set": "magic_earth/rock_break", "n": 3, "layers": [&"thump"], "fam": &"earth"},
	&"earth_light": {"set": "magic_earth/stones", "n": 3, "fam": &"earth"},
	&"stomp": {"set": "magic_earth/rock_fall", "n": 3, "far": true, "layers": [&"thump"], "fam": &"earth"},
	&"mining": {"set": "magic_earth/mining", "n": 3},
	# ---- arcane / energy / status
	&"cast": {"set": "energy/cast", "n": 5, "db": -1.0, "fam": &"cast"},
	&"magic": {"set": "energy/spell", "n": 3, "db": -2.0, "fam": &"cast"},
	&"magic_bolt": {"set": "energy/cast", "n": 5, "db": -2.0, "p": 1.1, "fam": &"cast"},
	&"qi": {"set": "energy/cast", "n": 5, "p": 0.75, "layers": [&"wind_soft"], "fam": &"cast"},
	&"qi_blast": {"set": "magic_lightning/zap_cast", "n": 3, "p": 0.7, "layers": [&"wind"], "fam": &"cast"},
	&"summon": {"set": "energy/summon", "n": 2, "max": 2, "pri": 2, "fam": &"summon"},
	&"buff": {"set": "energy/buff", "n": 2, "db": -2.0, "fam": &"buff"},
	&"shield_up": {"set": "energy/shield", "n": 3, "layers": [&"bell_soft"], "fam": &"buff"},
	&"debuff": {"set": "magic_dark/curse", "n": 2, "db": -2.0, "layers": [&"shade_soft"], "fam": &"debuff"},
	&"blink": {"set": "energy/teleport", "n": 3, "fam": &"blink"},
	&"teleport": {"alias": &"blink"},
	&"telegraph": {"set": "energy/telegraph", "n": 2, "db": -4.0, "max": 3},
	&"shimmer": {"set": "energy/shimmer", "n": 1, "db": -5.0, "pri": 0},
	&"launch": {"set": "movement/dash", "n": 3, "db": -3.0, "p": 0.85, "fam": &"launch"},
	&"smoke": {"set": "magic_wind/wind", "n": 3, "db": -4.0, "p": 1.3, "fam": &"smoke"},
	&"ultimate_charge": {"set": "energy/buff", "n": 2, "db": 1.0, "pr": 0.03, "max": 2, "pri": 3, "far": true,
		"layers": [&"ult_rise"], "fam": &"ult", "duck": true},
	&"ult_rise": {"files": ["magic_fire/fire_charge_01.ogg", "magic_lightning/zap_charge_01.ogg", "magic_ice/ice_charge_01.ogg"],
		"db": -2.0, "p": 0.85, "max": 2, "pri": 3, "far": true},
	&"ultimate_release": {"files": ["magic_fire/fire_big_01.ogg", "explosion/large_01.ogg", "explosion/large_02.ogg"],
		"db": 1.0, "max": 2, "pri": 3, "far": true, "layers": [&"thump"], "fam": &"ult_release", "duck": true},
	# ---- body / movement
	&"dash": {"set": "movement/dash", "n": 3, "db": -2.0, "fam": &"dash"},
	&"jump": {"set": "body/cloth", "n": 4, "db": -5.0, "max": 3, "pri": 0, "layers": [&"jump_whoosh"], "fam": &"jump"},
	&"jump_whoosh": {"set": "blade/swing_light", "n": 6, "db": -11.0, "p": 0.75, "max": 3, "pri": 0},
	&"land": {"set": "body/land", "n": 4, "db": -3.0, "max": 3, "pri": 0, "fam": &"land"},
	&"knockdown": {"set": "body/fall", "n": 4, "layers": [&"cloth_soft"], "fam": &"land"},
	&"wall_slam": {"set": "body/fall", "n": 4, "p": 0.9, "layers": [&"thump"], "fam": &"land"},
	&"recover": {"set": "body/cloth", "n": 4, "db": -2.0, "layers": [&"jump_whoosh"], "fam": &"blink"},
	&"death": {"set": "body/fall", "n": 4, "db": 1.0, "p": 0.9, "pri": 2, "layers": [&"armor"], "fam": &"death"},
	&"armor": {"set": "body/armor", "n": 2, "db": -6.0, "pri": 0},
	&"cloth_soft": {"set": "body/cloth", "n": 4, "db": -9.0, "pri": 0},
	&"grab": {"set": "body/grab", "n": 4, "layers": [&"hit_body_soft"], "fam": &"grab"},
	&"footstep_stone": {"set": "movement/step_stone", "n": 10, "db": -7.0, "pr": 0.08, "vr": 2.0, "max": 6, "pri": 0},
	&"footstep_grass": {"set": "movement/step_grass", "n": 5, "db": -7.0, "pr": 0.08, "vr": 2.0, "max": 6, "pri": 0},
	&"footstep_snow": {"set": "movement/step_snow", "n": 6, "db": -7.0, "pr": 0.08, "vr": 2.0, "max": 6, "pri": 0},
	&"footstep_dirt": {"set": "movement/step_dirt", "n": 6, "db": -7.0, "pr": 0.08, "vr": 2.0, "max": 6, "pri": 0},
	&"boss_step": {"set": "magic_earth/rock_fall", "n": 3, "db": -9.0, "p": 0.7, "max": 2, "far": true, "layers": [&"thump_soft"]},
	# ---- bosses and mobs
	&"boss_roar": {"set": "boss/roar", "n": 5, "db": 1.0, "p": 0.85, "pr": 0.05, "max": 2, "pri": 3, "far": true,
		"layers": [&"growl"], "duck": true},
	&"growl": {"set": "boss/growl", "n": 3, "db": -3.0, "max": 2, "pri": 2, "far": true},
	&"boss_stomp": {"set": "magic_earth/rock_break", "n": 3, "db": 1.0, "pri": 3, "far": true, "layers": [&"thump", &"blunt_heavy"], "fam": &"earth"},
	&"golem": {"set": "boss/golem", "n": 4, "p": 0.75, "max": 2, "pri": 2, "far": true},
	&"orc": {"set": "boss/ogre", "n": 3, "max": 3},
	&"mob_snarl": {"set": "boss/snarl", "n": 3, "max": 3},
	&"wolf": {"set": "boss/snarl", "n": 3, "p": 1.25, "max": 3},
	&"mob_hurt": {"set": "boss/hurt", "n": 4, "max": 3, "pri": 0},
	&"mob_death": {"set": "boss/die", "n": 3, "max": 3},
	&"monster": {"set": "boss/monster", "n": 3, "max": 3},
	&"skeleton": {"set": "boss/bones", "n": 4, "db": -2.0, "max": 3},
	# ---- UI (non-positional, UI bus)
	&"ui_click": {"set": "ui/click", "n": 4, "ui": true, "db": -4.0, "pr": 0.03, "vr": 0.5, "max": 2},
	&"ui_hover": {"set": "ui/hover", "n": 3, "ui": true, "db": -9.0, "pr": 0.03, "vr": 0.5, "max": 2},
	&"ui_confirm": {"set": "ui/confirm", "n": 2, "ui": true, "db": -3.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_cancel": {"set": "ui/back", "n": 2, "ui": true, "db": -3.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_back": {"alias": &"ui_cancel"},
	&"ui_error": {"set": "ui/error", "n": 2, "ui": true, "db": -3.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_tick": {"set": "ui/tick", "n": 2, "ui": true, "db": -2.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_toggle": {"set": "ui/toggle", "n": 2, "ui": true, "db": -4.0, "pr": 0.02, "vr": 0.0, "max": 2},
	&"ui_select": {"set": "ui/select", "n": 2, "ui": true, "db": -4.0, "pr": 0.02, "vr": 0.0, "max": 2},
	&"ui_open": {"set": "ui/open", "n": 1, "ui": true, "db": -4.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_close": {"set": "ui/close", "n": 1, "ui": true, "db": -4.0, "pr": 0.0, "vr": 0.0, "max": 2},
	&"ui_kill": {"set": "ui/kill", "n": 2, "ui": true, "db": -2.0, "pr": 0.02, "vr": 0.0, "max": 2},
	# ---- announcer (Kenney voiceover, English) + crowd
	&"vo_fight": {"files": ["voice/vo_fight.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_ready": {"files": ["voice/vo_ready.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_begin": {"files": ["voice/vo_begin.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_round_1": {"files": ["voice/vo_round_1.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_round_2": {"files": ["voice/vo_round_2.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_round_3": {"files": ["voice/vo_round_3.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_final_round": {"files": ["voice/vo_final_round.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_you_win": {"files": ["voice/vo_you_win.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_you_lose": {"files": ["voice/vo_you_lose.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_winner": {"files": ["voice/vo_winner.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_game_over": {"files": ["voice/vo_game_over.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_prepare": {"files": ["voice/vo_prepare_yourself.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_multi_kill": {"files": ["voice/vo_multi_kill.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_combo": {"files": ["voice/vo_combo.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_flawless": {"files": ["voice/vo_flawless_victory.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_sudden_death": {"files": ["voice/vo_sudden_death.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_time": {"files": ["voice/vo_time.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_tie": {"files": ["voice/vo_it_s_a_tie.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_1": {"files": ["voice/vo_1.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_2": {"files": ["voice/vo_2.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"vo_3": {"files": ["voice/vo_3.ogg"], "ui": true, "pr": 0.0, "vr": 0.0, "max": 1, "fam": &"vo"},
	&"crowd_cheer": {"set": "crowd/cheer", "n": 3, "ui": true, "bus": &"SFX", "db": -8.0, "pr": 0.02, "max": 1},
	# ---- legacy names (pre-0.2 kits / tests); generic ones are resolved per weapon first (see _resolve_sfx)
	&"hit": {"alias": &"hit_blunt"},
	&"hit_heavy": {"alias": &"hit_blunt_heavy"},
	&"swing": {"alias": &"swing_light"},
	&"slash": {"alias": &"swing_blade"},
	&"shot": {"alias": &"gun_pistol"},
	&"cannon": {"alias": &"gun_cannon"},
	&"explosion": {"alias": &"explosion_small"},
	&"fire": {"alias": &"fire_burst"},
	&"ice": {"alias": &"ice_hit"},
	&"ultimate": {"alias": &"ultimate_charge"},
	&"footstep": {"alias": &"footstep_stone"},
	&"glass": {"alias": &"shatter"},
	&"coin": {"alias": &"reload"},
	&"trap": {"alias": &"trap_set"},
	&"book": {"alias": &"cloth_soft"},
	&"none": {"files": []},
}

## Weapon (ClassKit.weapon_type, or a mob weapon id) -> sound class. Unlisted ids are matched by substring.
const WEAPON_CLASS: Dictionary = {
	"lightsaber": "saber", "tachi": "katana", "ninjato": "katana", "short_sword": "blade", "knight_sword": "blade",
	"dual_swords": "dagger", "dagger": "dagger", "greatsword": "heavy", "great_axe": "heavy", "war_scythe": "scythe",
	"battle_lance": "spear", "staff": "staff", "staff_ring": "staff", "cane": "staff", "broom": "staff", "umbrella": "staff",
	"cross": "mace", "gloves": "fist", "gloves_qi": "fist", "tonfa": "tonfa", "claws": "claw",
	"revolver": "gun", "auto_pistol": "gun", "rifle": "gun", "hand_cannon": "cannon",
}
## Generic sound name -> weapon class -> concrete name.
const GENERIC_SFX: Dictionary = {
	&"swing": {"saber": &"swing_saber", "katana": &"swing_katana", "blade": &"swing_blade", "dagger": &"swing_dagger",
		"heavy": &"swing_heavy", "scythe": &"swing_scythe", "spear": &"swing_spear", "staff": &"swing_staff", "mace": &"swing_heavy",
		"fist": &"swing_fist", "tonfa": &"swing_fist", "claw": &"swing_claw", "gun": &"swing_fist", "cannon": &"swing_heavy",
		"beast": &"swing_claw", "bow": &"swing_light"},
	&"hit": {"saber": &"hit_saber", "katana": &"hit_blade", "blade": &"hit_blade", "dagger": &"hit_blade",
		"heavy": &"hit_blade_heavy", "scythe": &"hit_blade_heavy", "spear": &"hit_pole", "staff": &"hit_pole", "mace": &"hit_blunt_heavy",
		"fist": &"hit_blunt", "tonfa": &"hit_wood", "claw": &"hit_claw", "gun": &"hit_bullet", "cannon": &"hit_blunt",
		"beast": &"hit_claw", "bow": &"hit_arrow"},
	&"hit_heavy": {"saber": &"hit_blade_heavy", "katana": &"hit_blade_heavy", "blade": &"hit_blade_heavy",
		"dagger": &"hit_blade_heavy", "heavy": &"hit_blade_heavy", "scythe": &"hit_blade_heavy", "claw": &"hit_blade_heavy",
		"beast": &"hit_blade_heavy"},
	&"shot": {"gun": &"gun_pistol", "cannon": &"gun_gatling", "bow": &"bow_shot", "staff": &"magic_bolt", "fist": &"qi",
		"claw": &"throw_light", "dagger": &"throw_light", "beast": &"throw_light", "saber": &"energy_shot", "katana": &"energy_shot",
		"blade": &"energy_shot", "heavy": &"energy_shot", "scythe": &"energy_shot", "spear": &"energy_shot", "mace": &"magic_bolt",
		"tonfa": &"throw_light"},
}
const GENERIC_SHOT_BY_WEAPON: Dictionary = {"revolver": &"gun_revolver", "auto_pistol": &"gun_pistol", "rifle": &"gun_rifle",
	"hand_cannon": &"gun_cannon"}
## Footstep surface per map id (map zone); unknown maps use stone.
const SURFACE_BY_MAP: Dictionary = {"classic_arena": &"footstep_stone", "hundred_blossoms": &"footstep_grass",
	"old_castle": &"footstep_stone", "lava_cave": &"footstep_dirt", "boneyard": &"footstep_dirt", "frost_forest": &"footstep_snow"}
## Area visual -> detonation sound (telegraphed areas only; instant ones are voiced by their skill's sfx step).
const AREA_SFX: Dictionary = {"fire": &"fire_burst", "ice": &"ice_hit", "lightning": &"lightning", "holy": &"holy",
	"dark": &"dark", "poison": &"poison", "wind": &"wind", "earth": &"earth", "blood": &"blood", "rune": &"cast",
	"thorn": &"earth_light"}
const UI_VOICES := 6

## Hit-stop (bible 5.3) from Fx events: hit_spark/block_spark 3 f, crit numbers 5 f, hit_heavy 8 f,
## ultimate_flash 12 f, plus explicit impact() calls. Local, cosmetic; set false to disable.
var hitstop_enabled: bool = true
## Fx events trigger hit-stop automatically (false = only explicit impact() calls do).
var auto_hitstop: bool = true
## Impact frames (screen_impact shader) on heavy hits near the camera and on ultimates.
var screen_impact_enabled: bool = true

## Emitted locally (every peer) for each impact / hit-stop event, so the local CameraRig can add shake and a FOV
## punch. level 1..4 (light / medium / heavy / ultimate), rel = REL_* of the effect's caster to the local player.
signal impact_fired(pos: Vector3, level: int, rel: int)

## --- Effect intensity by caster ownership (readability in 5v5 / raids; local prefs, never replicated) ---
## Every effect-spawning call can carry the caster's fighter uid (optional trailing `caster` argument; when 0 the
## host-side `context_caster` set by World.step is used and forwarded to clients). On each peer the effect is then
## scaled (alpha / emission / particle count / lights) by the caster's relation to the local player. Telegraphs of
## enemies (incl. bosses) always stay at full strength; damage numbers are never scaled.
const REL_UNKNOWN := -1
const REL_OWN := 0
const REL_ALLY := 1
const REL_ENEMY := 2
var own_intensity: float = 1.0
var ally_intensity: float = 0.5
var enemy_intensity: float = 0.7
## Fades effect pieces closer than `near_fade_dist` metres to the camera (caps additive overdraw / white-out).
var near_camera_fade: bool = true
var near_fade_dist: float = 2.0
## Host: uid of the fighter (or effect owner) currently being simulated; used when a call passes no caster.
var context_caster: int = 0

var _cur_k := 1.0                    # intensity of the effect being built right now
var _cur_rel := REL_UNKNOWN
var _cam_pos := Vector3.ZERO
var _cam_ok := false

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_i := 0
# Logical voice bookkeeping (kept even when headless/silent, so caps and priorities are testable):
var _v_name: Array[StringName] = []
var _v_end: PackedFloat64Array = []
var _v_pri: PackedFloat32Array = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _u_name: Array[StringName] = []
var _u_end: PackedFloat64Array = []
var _sfx_files: Dictionary = {}       # name -> expanded file list
var _sfx_last_file: Dictionary = {}   # name -> last file index (no immediate repeats)
var _sfx_last: Dictionary = {}        # name -> [time, pos] (same-sound spam guard)
var _fam_last: Dictionary = {}        # family -> [time, pos] of the last sound (auto-sound de-duplication)
var _fam_exp: Dictionary = {}         # family -> [time, pos] of the last explicit (non-auto) sound
var _weapon_cache: Dictionary = {}    # fighter uid -> weapon class
var _last_num: Array = [-10.0, Vector3.ZERO, &"phys"]   # last damage number [time, pos, kind]
var _surface_world: Node = null
var _surface: StringName = &"footstep_stone"
var _ui_hover_t := -10.0
## Counters for tests / debugging: sounds started, dropped by the voice cap, skipped as duplicates.
var sfx_stats: Dictionary = {"played": 0, "dropped": 0, "deduped": 0, "stolen": 0}
var _nodes: Dictionary = {}          # id -> Node3D (projectile / area visuals)
var _world: Node = null
var _warned: Dictionary = {}
var _parked: Array[Dictionary] = []  # despawned AreaVis kept briefly so a follow re-spawn can reclaim them
var _world_script: Script = null
var _world_has_instance := -1       # -1 unknown, 0 no, 1 core/world.gd has static get_instance()

var _clock := 0.0
var _flashes: Array = []            # active VfxFlash
var _flash_pool: Array = []
var _bursts: Array = []             # [CPUParticles3D, t_end, pooled]
var _burst_pool: Array = []
var _pending: Array = []            # [t_start, pos, cfg] delayed bursts
var _numbers: Array = []
var _number_pool: Array = []
var _lights: Array = []             # [OmniLight3D, t0, life, energy]
var _light_pool: Array = []
var _dying: Array = []              # detached VfxRibbon trails
var _curves: Dictionary = {}
var _ramps: Dictionary = {}
var _hitstop: VfxHitStop = HitStop.new()
var _impact_layer: CanvasLayer
var _impact_rect: ColorRect
var _impact_frame := -1
var _impact_total := 0
var _impact_lvl := 0
var _impact_last := -10.0

const AREA_PARK_MS := 150


# =============================================================================================
# Setup

func _ready() -> void:
	_ensure_voices()
	_impact_layer = CanvasLayer.new()
	_impact_layer.layer = 90
	add_child(_impact_layer)
	_impact_rect = ColorRect.new()
	_impact_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_impact_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Lib.IMPACT
	_impact_rect.material = m
	_impact_rect.visible = false
	_impact_layer.add_child(_impact_rect)
	var tree := get_tree()
	if tree and tree.has_signal(&"scene_changed"):
		tree.scene_changed.connect(clear_all)
	if tree and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


## Every button in the game gets UI sounds: click (or toggle) on press, a soft hover tick. A button can pick its
## press sound with meta "ui_sfx" (e.g. &"ui_confirm", &"ui_cancel"; &"none" silences it, hover included).
func _on_node_added(n: Node) -> void:
	if not (n is BaseButton) or n.has_meta(&"_fx_ui"):
		return
	var b := n as BaseButton
	b.set_meta(&"_fx_ui", true)
	b.pressed.connect(_on_ui_pressed.bind(b))
	b.mouse_entered.connect(_on_ui_hover.bind(b))


func _on_ui_pressed(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	# get_meta(key, null) errors on a missing key (a null default counts as "no default"), so guard with has_meta.
	var s: Variant = b.get_meta(&"ui_sfx") if b.has_meta(&"ui_sfx") else null
	if s == null:
		s = &"ui_toggle" if b.toggle_mode else &"ui_click"
	if StringName(s) != &"none":
		ui_sfx(StringName(s))


func _on_ui_hover(b: BaseButton) -> void:
	if not is_instance_valid(b) or b.disabled or StringName(b.get_meta(&"ui_sfx", &"")) == &"none":
		return
	var now := _now_s()
	if now - _ui_hover_t < 0.06:
		return
	_ui_hover_t = now
	ui_sfx(&"ui_hover")


func _process(delta: float) -> void:
	_clock += delta
	_hitstop.tick()
	_tick_impact()
	var cam0 := _camera()
	_cam_ok = cam0 != null and near_camera_fade
	if _cam_ok:
		_cam_pos = cam0.global_position
	# flashes (swap-remove)
	var i := _flashes.size() - 1
	while i >= 0:
		var f: Variant = _flashes[i]
		if not is_instance_valid(f) or (f as VfxFlash).is_queued_for_deletion():
			_flashes[i] = _flashes[_flashes.size() - 1]
			_flashes.pop_back()
		elif not (f as VfxFlash).step(delta):
			_flashes[i] = _flashes[_flashes.size() - 1]
			_flashes.pop_back()
			_retire_flash(f)
		else:
			_dim_flash(f as VfxFlash)
		i -= 1
	i = _bursts.size() - 1
	while i >= 0:
		var e: Array = _bursts[i]
		var p: Variant = e[0]
		if not is_instance_valid(p) or _clock >= float(e[1]):
			_bursts[i] = _bursts[_bursts.size() - 1]
			_bursts.pop_back()
			if is_instance_valid(p):
				_retire_burst(p, bool(e[2]))
		i -= 1
	i = _pending.size() - 1
	while i >= 0:
		var pe: Array = _pending[i]
		if _clock >= float(pe[0]):
			_pending.remove_at(i)
			var cfg: Dictionary = pe[2]
			cfg.erase("delay")
			burst(pe[1], cfg)
		i -= 1
	i = _numbers.size() - 1
	while i >= 0:
		var n: Variant = _numbers[i]
		if not is_instance_valid(n):
			_numbers.remove_at(i)
		elif not (n as VfxDamageNumber).step(delta):
			_numbers.remove_at(i)
			_retire_number(n)
		elif _cam_ok:
			# numbers spawned right at the lens would cover the screen: fade them inside ~3 m
			var nt := 1.0 - clampf((_cam_pos.distance_to((n as Node3D).global_position) - 1.0) / 2.0, 0.0, 1.0)
			if nt > 0.0 or (n as GeometryInstance3D).transparency > 0.0:
				(n as GeometryInstance3D).transparency = nt
				for c in (n as Node).get_children():
					if c is GeometryInstance3D:
						(c as GeometryInstance3D).transparency = nt
		i -= 1
	i = _lights.size() - 1
	while i >= 0:
		var le: Array = _lights[i]
		var l: Variant = le[0]
		var t := (_clock - float(le[1])) / float(le[2])
		if not is_instance_valid(l) or t >= 1.0:
			_lights.remove_at(i)
			if is_instance_valid(l):
				l.visible = false
				_light_pool.append(l)
		else:
			(l as OmniLight3D).light_energy = float(le[3]) * (1.0 - t) * (1.0 - t)
		i -= 1
	if not _dying.is_empty():
		var cam := _camera()
		i = _dying.size() - 1
		while i >= 0:
			var r: Variant = _dying[i]
			if not is_instance_valid(r) or not (r as VfxRibbon).tick(delta, cam):
				_dying.remove_at(i)
				if is_instance_valid(r):
					r.queue_free()
			i -= 1
	if _parked.is_empty():
		return
	var now := Time.get_ticks_msec()
	i = _parked.size() - 1
	while i >= 0:
		var pk: Dictionary = _parked[i]
		if now - int(pk["t"]) > AREA_PARK_MS or not is_instance_valid(pk["n"]):
			_parked.remove_at(i)
			_release(pk["n"])
		i -= 1


func _should_broadcast() -> bool:
	if not is_inside_tree():
		return false
	var mp := multiplayer
	if mp == null or not mp.has_multiplayer_peer():
		return false
	var peer := mp.multiplayer_peer
	if peer is OfflineMultiplayerPeer:
		return false
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return mp.is_server()


# =============================================================================================
# Public API (ARCHITECTURE §7.3)

## caster: uid of the fighter that caused the effect (0 = Fx.context_caster); scales it by ownership on each peer.
func play(name: StringName, pos: Vector3, dir := Vector3.FORWARD, color := Color.WHITE, scale := 1.0, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_play.rpc(name, pos, dir, color, scale, cu)
	else:
		_do_play(name, pos, dir, color, scale, cu)


## homing_rate: max turn rate in rad/s (pass the host Projectile.homing so the visual matches it);
## 0 keeps the legacy soft steering. Re-issuing the same id (e.g. on bounce) replaces the visual.
func spawn_projectile_visual(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid := 0, homing_rate := 0.0, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_projectile.rpc(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, cu)
	else:
		_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, cu)


func spawn_area_visual(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_area.rpc(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, cu)
	else:
		_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, cu)


## Moves/turns a live area visual without restarting it (for follow_caster areas and beams).
func move_area_visual(id: int, pos: Vector3, yaw: float) -> void:
	if _should_broadcast():
		_rpc_move_area.rpc(id, pos, yaw)
	else:
		_do_move_area(id, pos, yaw)


func despawn(id: int) -> void:
	if _should_broadcast():
		_rpc_despawn.rpc(id)
	else:
		_do_despawn(id)


func damage_number(pos: Vector3, amount: float, kind: StringName) -> void:
	if _should_broadcast():
		_rpc_number.rpc(pos, amount, kind)
	else:
		_do_number(pos, amount, kind)


## Positional sound at `pos`, played on every peer. caster: fighter uid (0 = Fx.context_caster); it picks
## weapon-specific variants of generic names (swing, hit, shot...) and the voice priority (own > enemy > ally).
func sfx(name: StringName, pos: Vector3, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_sfx.rpc(name, pos, cu)
	else:
		_do_sfx(name, pos, cu)


## Positional sound on this peer only (cosmetic code that already runs on every peer: footsteps, jumps).
func local_sfx(name: StringName, pos: Vector3, caster := 0) -> void:
	_do_sfx(name, pos, caster)


## Non-positional UI sound on the "UI" bus, this peer only (buttons, countdown ticks, announcer, kill ding).
func ui_sfx(name: StringName) -> void:
	_do_sfx(name, Vector3.ZERO, 0)


## One footstep of fighter `caster` at `pos` on the current map's surface (local; called by every peer).
func footstep(pos: Vector3, caster := 0, heavy := false) -> void:
	_do_sfx(&"boss_step" if heavy else _surface_sfx(), pos, caster)


## Sound voices currently in use (logical: counted even when headless). by_name: name -> count.
func voice_stats() -> Dictionary:
	var now := _now_s()
	var by: Dictionary = {}
	var n := 0
	for i in _v_end.size():
		if _v_end[i] > now:
			n += 1
			by[_v_name[i]] = int(by.get(_v_name[i], 0)) + 1
	var u := 0
	for i in _u_end.size():
		if _u_end[i] > now:
			u += 1
			by[_u_name[i]] = int(by.get(_u_name[i], 0)) + 1
	return {"active": n, "ui_active": u, "by_name": by, "cap": MAX_VOICES}


## Expanded file list (relative to SFX_DIR) of an SFX_MAP entry (aliases followed). Empty for unknown / silent.
func sfx_files(name: StringName) -> Array:
	var e := _sfx_entry(name)
	return _files_of(e[0], e[1]) if not (e[1] as Dictionary).is_empty() else []


## Impact frame + hit-stop at `pos` (the victim's centre). strength: 1 light (3 f), 2 medium (5 f),
## 3 heavy (8 f), 4 ultimate / finisher (12 f). dir = attacker -> victim (finds the attacker to freeze too).
## Cosmetic and local on every peer (never touches Engine.time_scale or the simulation).
func impact(pos: Vector3, strength := 2.0, dir := Vector3.ZERO, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_impact.rpc(pos, strength, dir, cu)
	else:
		_rpc_impact_local(pos, strength, dir, cu)


## Removes every live projectile/area visual and one-shot piece (call on scene change / round reset). Local only.
func clear_all() -> void:
	for e in _parked:
		if is_instance_valid(e["n"]):
			(e["n"] as Node).queue_free()
	_parked.clear()
	for id in _nodes.keys():
		var n: Node = _nodes[id]
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for f in _flashes:
		if is_instance_valid(f):
			_retire_flash(f)
	_flashes.clear()
	for e in _bursts:
		if is_instance_valid(e[0]):
			_retire_burst(e[0], bool(e[2]))
	_bursts.clear()
	_pending.clear()
	for n in _numbers:
		if is_instance_valid(n):
			_retire_number(n)
	_numbers.clear()
	for le in _lights:
		if is_instance_valid(le[0]):
			(le[0] as OmniLight3D).visible = false
			_light_pool.append(le[0])
	_lights.clear()
	for r in _dying:
		if is_instance_valid(r):
			r.queue_free()
	_dying.clear()
	_hitstop.release_all()
	_impact_frame = -1
	if _impact_rect:
		_impact_rect.visible = false
	_stop_voices()


## Stops every pooled SFX voice and drops its stream, so no AudioStreamPlayback outlives the current scene.
func _stop_voices() -> void:
	for v in _voices:
		if is_instance_valid(v):
			v.stop()
			v.stream = null
	for u in _ui_voices:
		if is_instance_valid(u):
			u.stop()
			u.stream = null
	_v_end.fill(0.0)
	_u_end.fill(0.0)
	_sfx_last.clear()
	_fam_last.clear()
	_fam_exp.clear()
	_weapon_cache.clear()
	_surface_world = null


## Full teardown (tests / app exit): clear_all + frees the pooled AudioStreamPlayer3D voices, the VFX pools and
## cached streams. Safe to call more than once; pools are rebuilt lazily.
func shutdown() -> void:
	clear_all()
	for v in _voices:
		if is_instance_valid(v):
			v.queue_free()
	_voices.clear()
	_voice_i = 0
	for u in _ui_voices:
		if is_instance_valid(u):
			u.queue_free()
	_ui_voices.clear()
	_v_name.clear()
	_v_end.clear()
	_v_pri.clear()
	_u_name.clear()
	_u_end.clear()
	for arr in [_flash_pool, _burst_pool, _number_pool, _light_pool]:
		for n in arr:
			if is_instance_valid(n):
				(n as Node).queue_free()
		arr.clear()
	for c in get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			c.queue_free()
	_streams.clear()


## True on the headless display server (tests, dedicated hosts): voices are prepared but never started, so no
## AudioStreamPlayback is left queued in the (Dummy) AudioServer at exit ("resources still in use" / leaks).
## Set `play_in_headless` to force playback anyway.
var play_in_headless: bool = false
var _headless := -1


func _audio_silent() -> bool:
	if play_in_headless:
		return false
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	return _headless == 1


func _ensure_voices() -> void:
	if not _voices.is_empty() or not is_inside_tree():
		return
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice%d" % i
		p.unit_size = UNIT_SIZE
		p.max_distance = MAX_DIST
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -18.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_voices.append(p)
	_v_name.resize(MAX_VOICES)
	_v_end.resize(MAX_VOICES)
	_v_end.fill(0.0)
	_v_pri.resize(MAX_VOICES)
	for i in UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.name = "UiVoice%d" % i
		add_child(u)
		_ui_voices.append(u)
	_u_name.resize(UI_VOICES)
	_u_end.resize(UI_VOICES)
	_u_end.fill(0.0)


func _exit_tree() -> void:
	_stop_voices()
	_streams.clear()
	_hitstop.release_all()


## Live cosmetic pieces (one-shot flashes, particle bursts, numbers, lights, trails, projectile/area visuals).
func live_count() -> int:
	return _flashes.size() + _bursts.size() + _pending.size() + _numbers.size() + _lights.size() + _dying.size() + _nodes.size()


## 0 = full detail, 1 = crowded (drop extras), 2 = over the hard cap (core pieces only).
func budget() -> int:
	var n := live_count()
	if n > HARD_LIVE_NODES:
		return 2
	if n > MAX_LIVE_NODES:
		return 1
	return 0


# --- RPC endpoints (host -> all peers, also run locally via call_local)

@rpc("authority", "call_local", "unreliable")
func _rpc_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float, caster: int) -> void:
	_do_play(name, pos, dir, color, scale, caster)

@rpc("authority", "call_local", "reliable")
func _rpc_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate: float, caster: int) -> void:
	_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, caster)

@rpc("authority", "call_local", "reliable")
func _rpc_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster: int) -> void:
	_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, caster)

@rpc("authority", "call_local", "unreliable_ordered")
func _rpc_move_area(id: int, pos: Vector3, yaw: float) -> void:
	_do_move_area(id, pos, yaw)

@rpc("authority", "call_local", "reliable")
func _rpc_despawn(id: int) -> void:
	_do_despawn(id)

@rpc("authority", "call_local", "unreliable")
func _rpc_number(pos: Vector3, amount: float, kind: StringName) -> void:
	_do_number(pos, amount, kind)

@rpc("authority", "call_local", "unreliable")
func _rpc_sfx(name: StringName, pos: Vector3, caster: int) -> void:
	_do_sfx(name, pos, caster)

@rpc("authority", "call_local", "unreliable")
func _rpc_impact(pos: Vector3, strength: float, dir: Vector3, caster: int) -> void:
	_rpc_impact_local(pos, strength, dir, caster)


func _rpc_impact_local(pos: Vector3, strength: float, dir: Vector3, caster: int) -> void:
	_begin_ctx(caster, false)
	_do_impact(pos, strength, dir)
	_end_ctx()


# =============================================================================================
# Named effects

func _do_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float, caster := 0) -> void:
	if not is_inside_tree():
		return
	_begin_ctx(caster, false)
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var s := maxf(scale, 0.05)
	# other players' effects at reduced intensity also drop their cosmetic extras
	var bud := budget()
	if _cur_k < 0.6:
		bud = maxi(bud, 1)
	if not Effects.play(self, name, pos, d, color, s, bud):
		if not _warned.has(name):
			_warned[name] = true
			push_warning("Fx.play: unknown effect '%s' (using hit_spark)" % name)
		Effects.play(self, &"hit_spark", pos, d, color, s, bud)
		name = &"hit_spark"
	if auto_hitstop:
		match name:
			&"hit_spark", &"block_spark":
				_do_impact(pos, 1.0, d)
			&"hit_heavy":
				_do_impact(pos, 3.0, d, Lib.pal(color, "impact")[1])
			&"ultimate_flash":
				_do_impact(pos + Vector3(0, 1.0, 0), 4.0, Vector3.ZERO, Lib.pal(color, "buff")[1])
	_end_ctx()
	_auto_sfx(name, pos, s, caster)


# =============================================================================================
# Hit-stop + impact frames

func _do_impact(pos: Vector3, strength: float, dir: Vector3, tint := Color(1.0, 0.9, 0.7)) -> void:
	if not is_inside_tree():
		return
	var lvl := clampi(int(round(strength)), 1, 4)
	if hitstop_enabled:
		var frames := HitStop.frames_for(lvl)
		var cands := _hitstop_candidates()
		var victim: Node3D = null
		var best := 1.8
		for c: Node3D in cands:
			var dd := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
			if dd < best:
				best = dd
				victim = c
		if victim:
			_hitstop.freeze(victim, frames, 0.025 * lvl if lvl >= 2 and lvl < 4 else 0.0)
		var fd := Vector2(dir.x, dir.z)
		if lvl < 4 and fd.length_squared() > 0.0001:
			fd = fd.normalized()
			var attacker: Node3D = null
			var best_a := 5.0
			for c: Node3D in cands:
				if c == victim:
					continue
				var rel := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z)
				var dist := rel.length()
				if dist < best_a and dist > 0.05 and rel.normalized().dot(-fd) > 0.25:
					best_a = dist
					attacker = c
			if attacker:
				_hitstop.freeze(attacker, frames)
	if lvl >= 3 and screen_impact_enabled and _impact_frame_allowed(pos, lvl):
		_screen_impact(pos, lvl, tint)
	impact_fired.emit(pos, lvl, _cur_rel)


## Full-screen impact frames only for the local player's own hits, hits on the local player, and (dimmed)
## ultimates of others; in a 10-fighter brawl everyone else's heavy hits would strobe the screen.
func _impact_frame_allowed(pos: Vector3, lvl: int) -> bool:
	if _cur_rel == REL_OWN or _cur_rel == REL_UNKNOWN:
		return true
	var me := _local_fighter()
	if me != null and Vector2(me.global_position.x - pos.x, me.global_position.z - pos.z).length() < 1.8:
		return true
	return lvl >= 4 and _clock - _impact_last >= 1.2 and _cur_k >= 0.45


func _hitstop_candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var w := _get_world()
	if w:
		var fr := w.get_node_or_null("Fighters")
		if fr:
			for f in fr.get_children():
				var v: Variant = f.get("visual")
				if v is Node3D and is_instance_valid(v) and (v as Node3D).is_visible_in_tree():
					out.append(v)
	var tree := get_tree()
	if tree:
		for n in tree.get_nodes_in_group(&"fx_hitstop"):
			if n is Node3D and not out.has(n):
				out.append(n)
	return out


func _screen_impact(pos: Vector3, lvl: int, tint: Color) -> void:
	var cam := _camera()
	if cam == null or _impact_rect == null:
		return
	if lvl < 4 and _clock - _impact_last < 0.45:
		return
	var dist := cam.global_position.distance_to(pos)
	if dist > (14.0 if lvl < 4 else 40.0) or cam.is_position_behind(pos):
		return
	_impact_last = _clock
	var vp := get_viewport().get_visible_rect().size
	var m := _impact_rect.material as ShaderMaterial
	m.set_shader_parameter("focus", cam.unproject_position(pos) / vp)
	m.set_shader_parameter("tint", tint)
	var kk := 1.0 if (_cur_rel == REL_OWN or _cur_rel == REL_UNKNOWN) else clampf(_cur_k, 0.3, 1.0) * 0.6
	m.set_shader_parameter("flash", (0.1 if lvl < 4 else 0.35) * kk)
	m.set_shader_parameter("lines", (0.38 if lvl < 4 else 0.8) * kk)
	m.set_shader_parameter("seed", randf())
	_impact_lvl = lvl if kk >= 0.99 else mini(lvl, 3)
	_impact_frame = 0
	_impact_total = 7 if lvl < 4 else 10
	_impact_rect.visible = true
	_tick_impact_params()


func _tick_impact() -> void:
	if _impact_frame < 0:
		return
	_impact_frame += 1
	if _impact_frame >= _impact_total:
		_impact_frame = -1
		_impact_rect.visible = false
		return
	_tick_impact_params()


func _tick_impact_params() -> void:
	var m := _impact_rect.material as ShaderMaterial
	# 1-2 full impact frames (ultimates open with an inverse frame), then a quick fade
	var st := 1.0 if _impact_frame < 2 else 1.0 - float(_impact_frame - 2) / float(maxi(_impact_total - 2, 1))
	m.set_shader_parameter("strength", st)
	m.set_shader_parameter("invert", 0.85 if (_impact_lvl >= 4 and _impact_frame == 0) else 0.0)


# =============================================================================================
# Pooled building blocks (used by res://visuals/vfx_effects.gd, vfx_projectiles.gd, vfx_ground.gd)

## Acquires a pooled VfxFlash (global position `pos`), registered for stepping. parent != null makes an unpooled
## child of that node (area spikes) that is freed with it.
func flash(mesh: Mesh, mat: Material, pos: Vector3, life: float, parent: Node = null) -> VfxFlash:
	var f: VfxFlash
	if parent != null:
		f = FlashNode.new()
		parent.add_child(f)
	elif not _flash_pool.is_empty():
		f = _flash_pool.pop_back()
	else:
		f = FlashNode.new()
		f.pooled = true
		add_child(f)
	f.reset_state()
	f.mesh = mesh
	f.material_override = mat
	f.life = maxf(life, 0.01)
	f.transparency = 0.0
	if parent == null:
		f.position = pos
	f.set_instance_shader_parameter(&"fade", 1.0)
	f.visible = true
	# opaque cel solids (debris, spikes) fade by noise erosion: dimming them would only dither them, so skip
	var solid := _is_solid(mat)
	f.set_meta(&"fx_solid", solid)
	f.set_meta(&"fx_k", 1.0 if solid else _cur_k)
	f.apply(0.0)
	_dim_flash(f)
	_flashes.append(f)
	return f


## Applies the ownership intensity (meta fx_k, set at spawn) and the near-camera fade on top of the fade the
## piece computed this frame (VfxFlash.apply() rewrites it every step, so this never compounds).
func _dim_flash(f: VfxFlash) -> void:
	if bool(f.get_meta(&"fx_solid", false)):
		return
	var k := float(f.get_meta(&"fx_k", 1.0))
	if _cam_ok:
		k *= _near_fade(f.global_position)
	if k >= 0.999:
		return
	if f.uses_shader:
		var cur: Variant = f.get_instance_shader_parameter(&"fade")
		f.set_instance_shader_parameter(&"fade", (float(cur) if cur != null else 1.0) * k)
	else:
		f.transparency = 1.0 - (1.0 - f.transparency) * k


static func _is_solid(mat: Material) -> bool:
	return mat is ShaderMaterial and ((mat as ShaderMaterial).shader == Lib.SOLID or (mat as ShaderMaterial).shader == Lib.OUTLINE)


func _near_fade(p: Vector3) -> float:
	var d := _cam_pos.distance_to(p)
	if d >= near_fade_dist:
		return 1.0
	return clampf((d - 0.5) / maxf(near_fade_dist - 0.5, 0.01), 0.0, 1.0)


func _retire_flash(f: VfxFlash) -> void:
	if f.pooled and f.get_parent() == self and _flash_pool.size() < POOL_FLASH:
		f.visible = false
		f.tweens = []
		_flash_pool.append(f)
	else:
		f.queue_free()


## One-shot particle burst at `pos` (pooled CPUParticles3D). See make_particles() for the cfg keys.
func burst(pos: Vector3, cfg: Dictionary) -> CPUParticles3D:
	if not is_inside_tree():
		return null
	var dl := float(cfg.get("delay", 0.0))
	if dl > 0.0:
		var dc := cfg.duplicate()
		dc["_k"] = _cur_k
		_pending.append([_clock + dl, pos, dc])
		return null
	var p: CPUParticles3D
	if not _burst_pool.is_empty():
		p = _burst_pool.pop_back()
	else:
		p = CPUParticles3D.new()
		add_child(p)
	_configure(p, cfg)
	var bk := float(cfg.get("_k", _cur_k)) * (_near_fade(pos) if _cam_ok else 1.0)
	if bk < 0.999:
		_dim_particles(p, bk)
	p.position = pos
	p.visible = true
	p.restart()
	p.emitting = true
	_bursts.append([p, _clock + p.lifetime * (1.0 + p.lifetime_randomness) + 0.1, true])
	return p


func _retire_burst(p: CPUParticles3D, pooled: bool) -> void:
	p.emitting = false
	if pooled and p.get_parent() == self and _burst_pool.size() < POOL_BURST:
		p.visible = false
		_burst_pool.append(p)
	else:
		p.queue_free()


## New (unpooled) particle emitter. cfg keys: kind (VfxLib.K_*), pal [core, mid, accent], energy, amount,
## life, speed [min, max], dir, spread, flat, gravity, size, curve ("shrink" | "grow" | "pop"), ramp ("fade" |
## "pop" | "late"), damp, align (streak along velocity), quad (Vector2 quad size), upright (no random
## rotation), tangent, radial, shape ("point" | "sphere" | "ring" | "box") + radius / inner / box, explosive,
## one_shot, color (per-particle tint multiplier).
func make_particles(cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_configure(p, cfg)
	return p


func _configure(p: CPUParticles3D, cfg: Dictionary) -> void:
	var kind := int(cfg.get("kind", Lib.K_SPARK))
	var align := bool(cfg.get("align", false))
	var bb := int(cfg.get("bb", 1 if align else 0))
	var q: Vector2 = cfg.get("quad", Vector2.ONE)
	p.mesh = Lib.particle_quad(kind, bb, q.x, q.y)
	var amt := maxi(1, int(cfg.get("amount", 10)))
	if p.amount != amt:
		p.amount = amt
	p.lifetime = maxf(float(cfg.get("life", 0.5)), 0.02)
	p.one_shot = bool(cfg.get("one_shot", true))
	p.explosiveness = float(cfg.get("explosive", 1.0 if p.one_shot else 0.0))
	p.randomness = 0.5
	p.lifetime_randomness = 0.25
	p.local_coords = false
	var sp: Array = cfg.get("speed", [2.0, 4.0])
	p.initial_velocity_min = sp[0]
	p.initial_velocity_max = sp[1]
	var dir: Vector3 = cfg.get("dir", Vector3.UP)
	p.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	p.spread = float(cfg.get("spread", 45.0))
	p.flatness = float(cfg.get("flat", 0.0))
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	var size := float(cfg.get("size", 0.4))
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = _curve_named(String(cfg.get("curve", "")))
	p.color = cfg.get("color", Color.WHITE)
	p.color_ramp = _ramp_named(String(cfg.get("ramp", "pop" if cfg.get("curve", "") == "pop" else "fade")))
	var dmp := float(cfg.get("damp", 0.0))
	p.damping_min = dmp
	p.damping_max = dmp * 1.3
	if bool(cfg.get("upright", false)) or align:
		p.angle_min = 0.0
		p.angle_max = 0.0
	else:
		p.angle_min = 0.0
		p.angle_max = 360.0
	var tg := float(cfg.get("tangent", 0.0))
	p.tangential_accel_min = tg
	p.tangential_accel_max = tg * 1.4
	var rd := float(cfg.get("radial", 0.0))
	p.radial_accel_min = rd
	p.radial_accel_max = rd * 1.3
	p.particle_flag_align_y = align
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	match String(cfg.get("shape", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(cfg.get("radius", 0.5))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.05
			p.emission_ring_radius = maxf(float(cfg.get("radius", 1.0)), 0.01)
			p.emission_ring_inner_radius = float(cfg.get("inner", 0.0))
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE * 0.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pal: Array = cfg.get("pal", Lib.PAL["phys"])
	Lib.set_pal(p, pal)
	p.set_instance_shader_parameter(&"energy", float(cfg.get("energy", 2.5)))
	p.set_instance_shader_parameter(&"fade", 1.0)
	p.set_instance_shader_parameter(&"progress", 0.0)
	p.set_instance_shader_parameter(&"seed", randf() * 10.0)


func _curve_named(n: String) -> Curve:
	if n == "":
		return null
	if _curves.has(n):
		return _curves[n]
	var pts: Array = {"shrink": [Vector2(0, 1), Vector2(1, 0.15)], "grow": [Vector2(0, 0.45), Vector2(1, 1.0)],
		"pop": [Vector2(0, 0.2), Vector2(0.2, 1.0), Vector2(1, 0.6)]}.get(n, [Vector2(0, 1), Vector2(1, 1)])
	var c := Curve.new()
	for pt: Vector2 in pts:
		c.add_point(pt)
	_curves[n] = c
	return c


func _ramp_named(n: String) -> Gradient:
	if _ramps.has(n):
		return _ramps[n]
	var spec: Array = {"fade": [[0.0, 0.6, 1.0], [1.0, 1.0, 0.0]], "pop": [[0.0, 0.12, 0.65, 1.0], [0.0, 1.0, 1.0, 0.0]],
		"late": [[0.0, 0.8, 1.0], [1.0, 1.0, 0.0]]}.get(n, [[0.0, 1.0], [1.0, 0.0]])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(spec[0])
	var cols := PackedColorArray()
	for a: float in spec[1]:
		cols.append(Color(1, 1, 1, a))
	g.colors = cols
	_ramps[n] = g
	return g


## Short-lived pooled point light (explosions, lightning, ultimates); at most MAX_LIGHTS at once.
func light(pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	if _lights.size() >= MAX_LIGHTS or budget() > 0 or _cur_k < 0.6:
		return
	energy *= _cur_k * _cur_k
	var l: OmniLight3D
	if not _light_pool.is_empty():
		l = _light_pool.pop_back()
	else:
		l = OmniLight3D.new()
		l.shadow_enabled = false
		add_child(l)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.visible = true
	_lights.append([l, _clock, maxf(life, 0.05), energy])


## Ground height under `pos` (ray down up to max_drop). Without a hit: pos.y - 0.9 for centre-height positions
## (max_drop >= 1) or pos.y for feet positions (max_drop < 1).
func ground_y(pos: Vector3, max_drop := 2.5) -> float:
	var fallback := pos.y - (0.9 if max_drop >= 1.0 else 0.0)
	var vp := get_viewport()
	if vp == null:
		return fallback
	var w3 := vp.find_world_3d()
	if w3 == null:
		return fallback
	var space := w3.direct_space_state
	if space == null:
		return fallback
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.1, 0), pos - Vector3(0, max_drop, 0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return float((hit["position"] as Vector3).y)


func _camera() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp else null


# =============================================================================================
# Projectile visuals

class ProjVis extends Node3D:
	var fx: Node
	var vel := Vector3.ZERO
	var grav := 0.0
	var homing_uid := 0
	var homing_rate := 0.0
	var _retry := 0.0
	var age := 0.0
	var max_life := 8.0
	var spin_node: Node3D
	var spin := Vector3.ZERO
	var trail: CPUParticles3D
	var ribbon: VfxRibbon
	var segments: Array[Node3D] = []
	var history: Array[Vector3] = []
	var flicker: Node3D
	var _target: WeakRef
	var _flick_base := Vector3.ONE

	func _process(delta: float) -> void:
		age += delta
		if age > max_life:
			fx.call("_do_despawn_node", self)
			return
		if homing_uid != 0:
			var tp: Variant = _target_pos(delta)
			if tp is Vector3:
				var want_dir: Vector3 = ((tp as Vector3) - global_position).normalized()
				if homing_rate > 0.0:
					# match the host Projectile: rotate at most homing_rate * delta per frame
					var cur := vel.normalized()
					var ang := cur.angle_to(want_dir)
					var axis := cur.cross(want_dir)
					if ang > 0.0001 and axis.length_squared() > 0.000001:
						vel = vel.rotated(axis.normalized(), minf(ang, homing_rate * delta))
				else:
					vel = vel.lerp(want_dir * vel.length(), clampf(delta * 5.0, 0.0, 1.0))
		vel.y -= grav * delta
		global_position += vel * delta
		if vel.length_squared() > 0.0001:
			var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
			look_at(global_position + vel, up)
		if spin_node:
			spin_node.rotate_object_local(Vector3.FORWARD, spin.z * delta)
			spin_node.rotate_object_local(Vector3.UP, spin.y * delta)
			spin_node.rotate_object_local(Vector3.RIGHT, spin.x * delta)
		if flicker:
			if _flick_base == Vector3.ONE:
				_flick_base = flicker.scale
			flicker.scale = _flick_base * randf_range(0.75, 1.25)
		if ribbon:
			ribbon.push(global_position)
			ribbon.tick(delta, get_viewport().get_camera_3d())
		if not segments.is_empty():
			history.push_front(global_position)
			if history.size() > segments.size() * 3 + 1:
				history.resize(segments.size() * 3 + 1)
			for i in segments.size():
				var hi := mini((i + 1) * 3, history.size() - 1)
				segments[i].global_position = history[hi]

	func _target_pos(delta := 0.0) -> Variant:
		var t: Node3D = _target.get_ref() if _target else null
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			t = null
			_target = null
			# back off: at most ~4 lookups per second while the target cannot be resolved
			_retry -= delta
			if _retry > 0.0:
				return null
			_retry = 0.25
			t = fx.call("_find_fighter", homing_uid)
			_target = weakref(t) if t else null
		if t == null:
			return null
		return t.global_position + Vector3(0, 1.0, 0)


func _do_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate := 0.0, caster := 0) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	_begin_ctx(caster, false)
	var s := maxf(scale, 0.05)
	var p := ProjVis.new()
	p.name = "Proj_%d" % id
	p.fx = self
	p.vel = vel
	p.grav = gravity
	p.homing_uid = homing_uid
	p.homing_rate = maxf(homing_rate, 0.0)
	var body := Node3D.new()
	body.name = "Body"
	p.add_child(body)
	body.scale = Vector3.ONE * s
	if not visual in PROJECTILE_VISUALS and not _warned.has("proj_" + visual):
		_warned["proj_" + visual] = true
		push_warning("Fx.spawn_projectile_visual: unknown visual '%s' (using orb)" % visual)
	Projectiles.build(self, p, body, visual if visual in PROJECTILE_VISUALS else "orb", color, s)
	if _cur_k < 0.999:
		_dim_tree(p, _cur_k)
	_end_ctx()
	add_child(p)
	p.global_position = from
	for seg in p.segments:
		seg.global_position = from
	if p.ribbon:
		p.ribbon.global_transform = Transform3D.IDENTITY
		p.ribbon.push(from)
	if vel.length_squared() > 0.0001:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
		p.look_at(from + vel, up)
	_nodes[id] = p


func _do_despawn_node(n: Node) -> void:
	for k in _nodes.keys():
		if _nodes[k] == n:
			_nodes.erase(k)
			_release(n)
			return
	for i in _parked.size():
		if _parked[i]["n"] == n:
			_parked.remove_at(i)
			break
	_release(n)


# =============================================================================================
# Area visuals

class AreaVis extends Node3D:
	var fx: Node
	var visual := ""
	var shape := "circle"
	var radius := 3.0
	var length := 6.0
	var width := 2.0
	var delay := 0.0
	var duration := 0.0
	var color := Color.WHITE
	var age := 0.0
	var telegraph: MeshInstance3D
	var zone: MeshInstance3D
	var started := false
	var ending := false
	var end_time := 0.0
	var tick := 0.0
	var spinners: Array[Node3D] = []
	var emitters: Array[CPUParticles3D] = []
	var decals: Array = []          # glyph circles fading with the zone
	var reclaimed := 0             # times this visual was re-used by a follow re-spawn
	var caster := 0                # fighter uid that owns the area (ownership intensity)
	var k := 1.0                   # zone intensity (Fx ownership scaling)
	var tk := 1.0                  # telegraph intensity (enemy telegraphs stay 1.0)

	func _process(delta: float) -> void:
		age += delta
		if telegraph and not started:
			var prog := clampf(age / maxf(delay, 0.001), 0.0, 1.0)
			telegraph.set_instance_shader_parameter(&"progress", prog)
			# pulses faster as the impact approaches
			telegraph.set_instance_shader_parameter(&"alpha", (0.78 + 0.22 * sin(age * lerpf(10.0, 26.0, prog))) * tk)
		if not started and age >= delay:
			started = true
			if telegraph:
				telegraph.queue_free()
				telegraph = null
			fx.call("_area_start", self)
			end_time = delay + maxf(duration, 0.6)
		if started:
			for s in spinners:
				if is_instance_valid(s):
					s.rotate_y(delta * 1.4)
			if duration > 0.0 and not ending:
				tick -= delta
				if tick <= 0.0:
					tick = 0.45
					fx.call("_area_tick", self)
			var remain := end_time - age
			if zone:
				var a := clampf(remain / 0.4, 0.0, 1.0) * clampf((age - delay) / 0.15, 0.0, 1.0)
				zone.set_instance_shader_parameter(&"alpha", a * (0.85 + 0.15 * sin(age * 5.0)) * k)
				for dcl in decals:
					if is_instance_valid(dcl):
						(dcl as GeometryInstance3D).set_instance_shader_parameter(&"fade", a * k)
			if remain <= 0.0:
				fx.call("_do_despawn_node", self)

	func line_center() -> Vector3:
		return Vector3(0, 0, -length * 0.5) if shape == "line" else Vector3.ZERO


func _do_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster := 0) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	if _reclaim_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color):
		return
	_begin_ctx(caster, false)
	var zk := _cur_k
	_end_ctx()
	_begin_ctx(caster, true)
	var tkk := _cur_k
	_end_ctx()
	var a := AreaVis.new()
	a.name = "Area_%d" % id
	a.fx = self
	a.visual = visual if visual in AREA_VISUALS else "rune"
	a.shape = shape if shape in ["circle", "line", "ring"] else "circle"
	a.radius = maxf(radius, 0.2)
	a.length = maxf(length, 0.5)
	a.width = maxf(width, 0.3)
	a.delay = maxf(delay, 0.0)
	a.duration = maxf(duration, 0.0)
	a.color = _c(color, AREA_COLORS.get(a.visual, Color(0.6, 0.45, 1.0)))
	a.caster = caster
	a.k = zk
	a.tk = tkk
	add_child(a)
	a.global_position = pos + Vector3(0, 0.04, 0)
	a.rotation.y = yaw
	if a.delay > 0.0:
		# warning colour: the element pushed toward hot red-orange so it always reads as danger
		var tc := a.color.lerp(Color(1.0, 0.22, 0.12), 0.65)
		a.telegraph = Ground.shape_mesh(a, tc, 1.0, true)
	_nodes[id] = a
	# subtle warning hum for telegraphed zones (the detonation sound plays in _area_start)
	if a.delay > 0.25:
		_do_sfx(&"telegraph", pos, caster, true)


## CORE's follow_caster areas re-issue their visual as despawn(old) + spawn(new id) when the caster moves.
## A just-despawned area with the same look is re-used (moved, re-keyed, timing updated) instead of
## restarting the fade-in, spikes, flare and first tick.
func _reclaim_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> bool:
	var v := visual if visual in AREA_VISUALS else "rune"
	var sh := shape if shape in ["circle", "line", "ring"] else "circle"
	var c := _c(color, AREA_COLORS.get(v, Color(0.6, 0.45, 1.0)))
	for i in range(_parked.size() - 1, -1, -1):
		var pn: Variant = _parked[i]["n"]
		if pn == null or not is_instance_valid(pn) or not (pn is AreaVis):
			continue
		var a := pn as AreaVis
		if a.is_queued_for_deletion():
			continue
		if a.visual != v or a.shape != sh or not a.color.is_equal_approx(c):
			continue
		if absf(a.radius - maxf(radius, 0.2)) > 0.01 or absf(a.length - maxf(length, 0.5)) > 0.01 or absf(a.width - maxf(width, 0.3)) > 0.01:
			continue
		_parked.remove_at(i)
		a.name = "Area_%d" % id
		a.global_position = pos + Vector3(0, 0.04, 0)
		a.rotation.y = yaw
		var d := maxf(delay, 0.0)
		var dur := maxf(duration, 0.0)
		if not a.started:
			a.delay = a.age + d
			a.duration = dur
		elif a.duration > 0.0:
			a.end_time = a.age + d + dur
		else:
			a.end_time = maxf(a.end_time, a.age + d + dur)
		a.reclaimed += 1
		_nodes[id] = a
		return true
	return false


func _do_move_area(id: int, pos: Vector3, yaw: float) -> void:
	var n: Variant = _nodes.get(id)
	if n == null or not is_instance_valid(n) or not (n is AreaVis):
		return
	var a := n as AreaVis
	a.global_position = pos + Vector3(0, 0.04, 0)
	a.rotation.y = yaw


func _area_start(a: AreaVis) -> void:
	_cur_k = a.k
	a.zone = Ground.shape_mesh(a, a.color, 0.0, false)
	Ground.start(self, a)
	if a.k < 0.999:
		for e in a.emitters:
			if is_instance_valid(e):
				_dim_particles(e, a.k)
	_cur_k = 1.0
	if a.delay > 0.05:
		_do_sfx(AREA_SFX.get(a.visual, &"cast"), a.global_position, a.caster, true)


## Periodic accents while a zone is active (lightning strikes, ember bursts...).
func _area_tick(a: AreaVis) -> void:
	_cur_k = a.k
	Ground.tick(self, a)
	_cur_k = 1.0


# =============================================================================================
# Ownership intensity

func _begin_ctx(caster: int, telegraph: bool) -> void:
	_cur_rel = _rel_of(caster)
	_cur_k = intensity_for(_cur_rel, telegraph)


func _end_ctx() -> void:
	_cur_k = 1.0
	_cur_rel = REL_UNKNOWN


## Intensity multiplier for an effect whose caster has relation `rel` (REL_*) to the local player.
func intensity_for(rel: int, telegraph := false) -> float:
	match rel:
		REL_OWN:
			return clampf(own_intensity, 0.0, 1.0)
		REL_ALLY:
			return maxf(clampf(ally_intensity, 0.0, 1.0), 0.6) if telegraph else clampf(ally_intensity, 0.0, 1.0)
		REL_ENEMY:
			return 1.0 if telegraph else clampf(enemy_intensity, 0.0, 1.0)
	return 1.0


func _local_fighter() -> Node3D:
	var w := _get_world()
	if w == null or not w.has_method("local_fighter"):
		return null
	var f: Variant = w.call("local_fighter")
	return f as Node3D if f is Node3D and is_instance_valid(f) else null


## Relation of fighter `uid` (summons resolve to their owner) to the local player.
func _rel_of(uid: int) -> int:
	if uid <= 0:
		return REL_UNKNOWN
	var f := _find_fighter(uid)
	if f == null:
		return REL_UNKNOWN
	if str(f.get("kind")) == "summon" and f.has_method("get_owner_fighter"):
		var o: Variant = f.call("get_owner_fighter")
		if o is Node3D and is_instance_valid(o):
			f = o
	var me := _local_fighter()
	if me == null:
		return REL_ENEMY   # spectator without a fighter: every effect is "someone else's"
	if f == me:
		return REL_OWN
	return REL_ALLY if f.get("team") == me.get("team") else REL_ENEMY


func _dim_particles(p: CPUParticles3D, k: float) -> void:
	var c := p.color
	c.a *= k
	p.color = c
	var amt := maxi(1, int(round(float(p.amount) * lerpf(0.45, 1.0, k))))
	if amt != p.amount:
		p.amount = amt
	var e: Variant = p.get_instance_shader_parameter(&"energy")
	if e != null:
		p.set_instance_shader_parameter(&"energy", float(e) * lerpf(0.6, 1.0, k))


## Dims a freshly built projectile visual (particles + mesh `fade`; pooled VfxFlash pieces are handled by meta).
func _dim_tree(n: Node, k: float) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		if c is CPUParticles3D:
			_dim_particles(c, k)
		elif c is VfxFlash:
			continue
		else:
			var gi := c as GeometryInstance3D
			if _is_solid(gi.material_override):
				continue
			var cur: Variant = gi.get_instance_shader_parameter(&"fade")
			if cur != null:
				gi.set_instance_shader_parameter(&"fade", float(cur) * k)
			elif gi.material_override is ShaderMaterial:
				gi.set_instance_shader_parameter(&"fade", k)


func _random_point_in(a: Node3D) -> Vector3:
	var local := Vector3.ZERO
	var shape: String = a.get("shape")
	var radius := float(a.get("radius"))
	if shape == "line":
		var w := float(a.get("width"))
		local = Vector3(randf_range(-w, w) * 0.5, 0, -randf() * float(a.get("length")))
	elif shape == "ring":
		var ang := randf() * TAU
		var r := randf_range(radius * 0.6, radius)
		local = Vector3(cos(ang) * r, 0, sin(ang) * r)
	else:
		var ang2 := randf() * TAU
		var r2 := sqrt(randf()) * radius * 0.9
		local = Vector3(cos(ang2) * r2, 0, sin(ang2) * r2)
	return a.global_transform * local


func _do_despawn(id: int) -> void:
	if not _nodes.has(id):
		return
	var n: Node3D = _nodes[id]
	_nodes.erase(id)
	if not is_instance_valid(n):
		return
	if n is AreaVis and not n.is_queued_for_deletion():
		# keep it alive for AREA_PARK_MS in case the host immediately re-spawns it (follow re-issue)
		_parked.append({"n": n, "t": Time.get_ticks_msec()})
		return
	_release(n)


## Frees a projectile/area visual, handing looping particle emitters and ribbon trails to Fx so they finish
## instead of popping.
func _release(n: Node) -> void:
	if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	for e in n.find_children("*", "CPUParticles3D", true, false):
		var cp := e as CPUParticles3D
		if cp.one_shot:
			continue
		var gp := cp.global_transform
		cp.get_parent().remove_child(cp)
		add_child(cp)
		cp.global_transform = gp
		cp.emitting = false
		_bursts.append([cp, _clock + cp.lifetime + 0.2, false])
	for r in n.find_children("*", "MeshInstance3D", true, false):
		if r is VfxRibbon:
			var rb := r as VfxRibbon
			rb.get_parent().remove_child(rb)
			add_child(rb)
			rb.global_transform = Transform3D.IDENTITY
			rb.detach()
			_dying.append(rb)
	n.queue_free()


# =============================================================================================
# Damage numbers + SFX

func _do_number(pos: Vector3, amount: float, kind: StringName) -> void:
	if not is_inside_tree():
		return
	var l: VfxDamageNumber
	if not _number_pool.is_empty():
		l = _number_pool.pop_back()
	else:
		l = DamageNumber.new()
		add_child(l)
	l.setup(kind, amount, Lib.number_font("num"), Lib.number_font("tag"))
	l.visible = true
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.2, randf_range(-0.25, 0.25))
	_numbers.append(l)
	_last_num = [_now_s(), pos - Vector3(0, 0.9, 0), kind]
	if kind == &"crit" and auto_hitstop:
		_do_impact(pos - Vector3(0, 0.9, 0), 2.0, Vector3.ZERO)


func _retire_number(n: VfxDamageNumber) -> void:
	if n.get_parent() == self and _number_pool.size() < POOL_NUMBERS:
		n.visible = false
		_number_pool.append(n)
	else:
		n.queue_free()


func _do_sfx(name: StringName, pos: Vector3, caster := 0, auto := false) -> void:
	if not is_inside_tree():
		return
	_ensure_voices()
	if _voices.is_empty():
		return
	var nm := _resolve_sfx(name, caster)
	_play_sfx(nm, pos, caster, auto, 0)


## Generic names -> weapon / surface specific ones (swing -> swing_katana for a tachi, shot -> gun_revolver...).
func _resolve_sfx(name: StringName, caster: int) -> StringName:
	if name == &"footstep":
		return _surface_sfx()
	if name == &"slash" and caster != 0:
		var sw := _resolve_sfx(&"swing", caster)
		return sw if sw != &"swing" else name
	if not GENERIC_SFX.has(name) or caster == 0:
		return name
	if name == &"shot":
		var wt := _weapon_type(caster)
		if GENERIC_SHOT_BY_WEAPON.has(wt):
			return GENERIC_SHOT_BY_WEAPON[wt]
	var wc := _weapon_class(caster)
	var tbl: Dictionary = GENERIC_SFX[name]
	if tbl.has(wc):
		return tbl[wc]
	if name == &"hit_heavy" and GENERIC_SFX[&"hit"].has(wc):
		return &"hit_blunt_heavy"
	return name


## [resolved name, entry] following aliases; unknown names fall back to "hit" (one warning each).
func _sfx_entry(name: StringName) -> Array:
	var nm := name
	for i in 6:
		var e: Variant = SFX_MAP.get(nm)
		if e == null:
			if not _warned.has("sfx_" + nm):
				_warned["sfx_" + nm] = true
				push_warning("Fx.sfx: unknown sound '%s' (using hit)" % nm)
			nm = &"hit_blunt"
			continue
		var d: Dictionary = e
		if d.has("alias"):
			nm = d["alias"]
			continue
		return [nm, d]
	return [&"none", {}]


func _files_of(nm: StringName, e: Dictionary) -> Array:
	var cached: Variant = _sfx_files.get(nm)
	if cached != null:
		return cached
	var out: Array = []
	if e.has("files"):
		out = (e["files"] as Array).duplicate()
	elif e.has("set"):
		for i in int(e.get("n", 1)):
			out.append("%s_%02d.ogg" % [e["set"], i + 1])
	_sfx_files[nm] = out
	return out


func _stream(file: String) -> AudioStream:
	var st: AudioStream = _streams.get(file)
	if st == null:
		if not ResourceLoader.exists(SFX_DIR + file):
			if not _warned.has("sfxfile_" + file):
				_warned["sfxfile_" + file] = true
				push_warning("Fx.sfx: missing file '%s'" % file)
			return null
		st = load(SFX_DIR + file)
		if st != null:
			_streams[file] = st
	return st


func _play_sfx(name: StringName, pos: Vector3, caster: int, auto: bool, depth: int) -> void:
	var r := _sfx_entry(name)
	var nm: StringName = r[0]
	var e: Dictionary = r[1]
	var files := _files_of(nm, e) if not e.is_empty() else []
	if files.is_empty():
		return
	var now := _now_s()
	var ui := bool(e.get("ui", false))
	# Spam guards: the same sound twice within 30 ms at (almost) the same spot, or a second sound of the same
	# family (e.g. a kit's explicit "explosion" step + the explosion effect's own sound) close in time and space.
	var last: Variant = _sfx_last.get(nm)
	if last != null and now - float(last[0]) < 0.03 and (ui or (last[1] as Vector3).distance_to(pos) < 2.0):
		sfx_stats["deduped"] += 1
		return
	# An automatic (effect-driven) sound yields to any same-family sound in the last 150 ms; an explicit one only
	# to another explicit one in the last 60 ms, so a kit's own sound is never lost to an effect's generic one.
	var fam: StringName = e.get("fam", &"")
	if depth == 0 and fam != &"":
		var fl: Variant = _fam_last.get(fam) if auto else _fam_exp.get(fam)
		var win := 0.15 if auto else 0.06
		if fl != null and now - float(fl[0]) < win and (ui or (fl[1] as Vector3).distance_to(pos) < 4.0):
			sfx_stats["deduped"] += 1
			return
		_fam_last[fam] = [now, pos]
		if not auto:
			_fam_exp[fam] = [now, pos]
	_sfx_last[nm] = [now, pos]
	var far := bool(e.get("far", false))
	# Priority: entry base (0..3) x10, + relation of the caster to the local player, - distance to the listener.
	var rel := _rel_of(caster) if caster > 0 else REL_UNKNOWN
	var pri := float(e.get("pri", 1)) * 10.0
	match rel:
		REL_OWN:
			pri += 3.0
		REL_ENEMY:
			pri += 2.0
		REL_ALLY:
			pri += 1.0
		_:
			pri += 1.5
	if not ui:
		var cam := _camera()
		if cam != null:
			var dist := cam.global_position.distance_to(pos)
			if dist > (FAR_MAX_DIST if far else MAX_DIST) + 5.0:
				sfx_stats["dropped"] += 1
				return
			pri -= dist / 15.0
	var maxp := int(e.get("max", 4))
	# pick a file (never the same one twice in a row)
	var fi := randi() % files.size()
	if files.size() > 1 and fi == int(_sfx_last_file.get(nm, -1)):
		fi = (fi + 1 + randi() % (files.size() - 1)) % files.size()
	_sfx_last_file[nm] = fi
	var st := _stream(files[fi])
	if st == null:
		return
	var pitch := float(e.get("p", 1.0)) * (1.0 + randf_range(-1.0, 1.0) * float(e.get("pr", 0.06)))
	pitch = clampf(pitch, 0.3, 3.0)
	var vr := float(e.get("vr", 1.5))
	var vol := float(e.get("db", 0.0)) + randf_range(-vr, vr)
	var length := maxf(st.get_length() / pitch, 0.05)
	if ui:
		var ui_i := _alloc(_u_name, _u_end, PackedFloat32Array(), nm, maxp, pri, now, true)
		if ui_i < 0:
			sfx_stats["dropped"] += 1
			return
		var u := _ui_voices[ui_i]
		u.stop()
		u.stream = st
		u.pitch_scale = pitch
		u.volume_db = vol
		u.bus = _bus(e.get("bus", BUS_UI))
		_u_name[ui_i] = nm
		_u_end[ui_i] = now + length
		if not _audio_silent():
			u.play()
	else:
		var i := _alloc(_v_name, _v_end, _v_pri, nm, maxp, pri, now, false)
		if i < 0:
			sfx_stats["dropped"] += 1
			return
		var v := _voices[i]
		v.stop()
		v.stream = st
		v.pitch_scale = pitch
		v.volume_db = vol
		v.unit_size = FAR_UNIT_SIZE if far else UNIT_SIZE
		v.max_distance = FAR_MAX_DIST if far else MAX_DIST
		v.bus = _bus(e.get("bus", BUS_SFX))
		v.global_position = pos
		_v_name[i] = nm
		_v_end[i] = now + length
		_v_pri[i] = pri
		if not _audio_silent():
			v.play()
	sfx_stats["played"] += 1
	if bool(e.get("duck", false)) and depth == 0:
		_duck_music(-7.0 if rel == REL_OWN or rel == REL_UNKNOWN else -4.0, clampf(length, 1.2, 2.5))
	if depth < 2:
		for l: Variant in e.get("layers", []):
			_play_sfx(l, pos, caster, auto, depth + 1)


## Voice index for a new sound, or -1 when it is dropped. Per-name polyphony first (steals the oldest voice of the
## same name), then a free voice, then the lowest-priority active voice if it ranks below the new one.
func _alloc(names: Array[StringName], ends: PackedFloat64Array, pris: PackedFloat32Array, nm: StringName, maxp: int, pri: float, now: float, ui: bool) -> int:
	var same := 0
	var oldest_same := -1
	var oldest_same_end := INF
	var free := -1
	var low := -1
	var low_pri := INF
	for i in ends.size():
		if ends[i] > now:
			if names[i] == nm:
				same += 1
				if ends[i] < oldest_same_end:
					oldest_same_end = ends[i]
					oldest_same = i
			if not ui and pris[i] < low_pri:
				low_pri = pris[i]
				low = i
		elif free < 0:
			free = i
	if same >= maxp:
		if not ui and pris[oldest_same] > pri + 0.5:
			return -1
		sfx_stats["stolen"] += 1
		return oldest_same
	if free >= 0:
		return free
	if ui:
		return -1
	if low >= 0 and low_pri < pri:
		sfx_stats["stolen"] += 1
		return low
	return -1


func _bus(b: Variant) -> StringName:
	var n := StringName(b)
	return n if AudioServer.get_bus_index(n) >= 0 else &"Master"


static func _now_s() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


## Music autoload (built by the music track) ducks its bus; absent -> no-op.
func _duck_music(db: float, seconds: float) -> void:
	var m := get_node_or_null(^"/root/Music")
	if m != null and m.has_method(&"duck"):
		m.call(&"duck", db, seconds)


## Weapon of fighter `uid` (weapon_form override > kit weapon_type).
func _weapon_type(uid: int) -> String:
	var f := _find_fighter(uid)
	if f == null:
		return ""
	var wf: Variant = f.get("weapon_form")
	if wf is String and wf != "":
		return wf
	var k: Variant = f.get("kit")
	if k is Object and is_instance_valid(k):
		var wt: Variant = (k as Object).get("weapon_type")
		if wt is String:
			return wt
	return ""


## Sound class of fighter `uid`'s weapon (WEAPON_CLASS, then substring rules for mob weapons; mobs with none are
## beasts). Cached per uid until the next clear_all().
func _weapon_class(uid: int) -> String:
	var c: Variant = _weapon_cache.get(uid)
	if c != null:
		return c
	var f := _find_fighter(uid)
	var wt := _weapon_type(uid)
	var wc := ""
	if WEAPON_CLASS.has(wt):
		wc = WEAPON_CLASS[wt]
	elif wt == "":
		wc = "beast" if f != null and str(f.get("kind")) != "player" and str(f.get("kind")) != "bot" else ""
	elif "bow" in wt:
		wc = "bow"
	elif "dagger" in wt:
		wc = "dagger"
	elif "mace" in wt or "hammer" in wt:
		wc = "mace"
	elif "axe" in wt:
		wc = "heavy"
	elif "sword" in wt or "blade" in wt:
		wc = "blade"
	elif "staff" in wt or "wand" in wt:
		wc = "staff"
	if f != null:
		_weapon_cache[uid] = wc
	return wc


## Footstep sound for the current map (map id -> surface); refreshed when the World changes.
func _surface_sfx() -> StringName:
	var w := _get_world()
	if w != _surface_world:
		_surface_world = w
		_surface = &"footstep_stone"
		var id := ""
		var p: Node = w.get_parent() if w != null else null
		if p != null:
			var m: Variant = p.get("map")
			if m is Object and is_instance_valid(m):
				id = str((m as Object).get("map_id"))
		if SURFACE_BY_MAP.has(id):
			_surface = SURFACE_BY_MAP[id]
	return _surface


## Victim-side hit sound: magic damage gets a soft energy hit; physical hits sound like the attacker's weapon.
## Uses the damage number that core shows just before the hit effect (same peer, same frame).
func _hit_sfx(pos: Vector3, caster: int, heavy: bool, projectile: bool) -> StringName:
	var magic := false
	var crit := false
	if _now_s() - float(_last_num[0]) < 0.08 and (_last_num[1] as Vector3).distance_to(pos) < 2.5:
		magic = _last_num[2] == &"magic"
		crit = _last_num[2] == &"crit"
	var wc := _weapon_class(caster) if caster > 0 else ""
	var nm: StringName
	if magic:
		nm = &"hit_magic"
	elif projectile and wc != "gun" and wc != "bow" and wc != "cannon":
		nm = &"hit_blunt"
	elif heavy or crit:
		nm = (GENERIC_SFX[&"hit_heavy"] as Dictionary).get(wc, &"hit_blunt_heavy")
	else:
		nm = (GENERIC_SFX[&"hit"] as Dictionary).get(wc, &"hit_blunt")
	if crit and not heavy:
		_do_sfx(&"crit", pos, caster, true)
	return nm


## Automatic sounds for named effects (every peer; the effect itself is already replicated).
func _auto_sfx(name: StringName, pos: Vector3, scale: float, caster: int) -> void:
	var s := StringName()
	match name:
		&"hit_spark":
			s = _hit_sfx(pos, caster, false, scale < 0.75)
		&"hit_heavy":
			s = _hit_sfx(pos, caster, true, false)
		&"block_spark":
			s = &"block"
		&"land_dust":
			if scale > 1.2:
				s = &"stomp"
			elif scale >= 0.95:
				s = &"knockdown"
			elif scale >= 0.7:
				s = &"wall_slam"
			else:
				s = &"land"
		&"death":
			s = &"death"
		&"explosion":
			s = &"explosion_large" if scale >= 1.4 else &"explosion_small"
		&"ice_burst":
			s = &"ice_hit"
		&"lightning_strike":
			s = &"lightning"
		&"fire_burst":
			s = &"fire_burst"
		&"holy_burst":
			s = &"holy"
		&"dark_burst":
			s = &"dark"
		&"poison_cloud":
			s = &"poison"
		&"heal_burst":
			s = &"heal"
		&"buff_aura":
			s = &"buff"
		&"debuff_puff":
			s = &"debuff"
		&"smoke":
			s = &"smoke"
		&"blink":
			s = &"recover" if scale < 0.8 else &"blink"
		&"dash_trail":
			s = &"dash"
		&"summon_circle":
			s = &"summon"
		&"launch_burst":
			s = &"launch"
		&"ultimate_flash":
			s = &"ultimate_charge"
			if scale >= 2.5:
				_do_sfx(&"boss_roar", pos, caster, true)
	if s != &"":
		_do_sfx(s, pos, caster, true)


# =============================================================================================
# World lookup

func _find_fighter(uid: int) -> Node3D:
	var w := _get_world()
	if w == null:
		return null
	var f: Variant = null
	if w.has_method("get_fighter"):
		f = w.call("get_fighter", uid)
	if not (f is Node3D):
		f = w.get_node_or_null("Fighters/" + str(uid))
	return f as Node3D if f is Node3D else null


func _get_world() -> Node:
	if is_instance_valid(_world) and _world.is_inside_tree():
		return _world
	_world = null
	# World.get_instance() when core/world.gd exists (looked up dynamically so Fx never hard-depends on CORE)
	if _world_has_instance < 0:
		_world_has_instance = 0
		if ResourceLoader.exists("res://core/world.gd"):
			var scr: Variant = load("res://core/world.gd")
			if scr is Script and (scr as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m.get("name") == "get_instance"):
				_world_script = scr
				_world_has_instance = 1
	if _world_has_instance == 1 and _world_script != null:
		var w: Variant = _world_script.call("get_instance")
		if w is Node:
			_world = w
			return _world
	var tree := get_tree()
	if tree == null:
		return null
	var g := tree.get_first_node_in_group(&"world")
	if g:
		_world = g
		return g
	if tree.current_scene:
		_world = tree.current_scene.find_child("World", true, false)
	return _world


func _c(c: Color, default: Color) -> Color:
	return default if c == Color.WHITE else c
