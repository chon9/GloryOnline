class_name Fighter
extends CharacterBody3D
## The central combat actor (ARCHITECTURE §4). Host-authoritative: World.step() calls host_tick() on the
## host; clients only render replicated state (see _build_sync for the replicated property list).

signal died(f: Fighter, killer: Fighter)
signal damaged(f: Fighter, amount: float, src: Fighter)
signal skill_cast(f: Fighter, slot: int)
signal healed(f: Fighter, amount: float, src: Fighter)

enum State { IDLE, MOVE, AIR, CAST, HITSTUN, LAUNCHED, KNOCKDOWN, GETUP, GRABBED, STUNNED, DEAD }
const STATE_NAMES: Array[String] = ["IDLE", "MOVE", "AIR", "CAST", "HITSTUN", "LAUNCHED", "KNOCKDOWN",
	"GETUP", "GRABBED", "STUNNED", "DEAD"]

const GRAVITY: float = 24.0
const KNOCKDOWN_TIME: float = 0.9
const GETUP_TIME: float = 0.4
const GETUP_INVULN: float = 0.6
const QUICK_RECOVER_WINDOW: float = 0.25
const QUICK_RECOVER_PREBUFFER: float = 0.1
const JUGGLE_RESET_TIME: float = 1.2
const JUGGLE_MAX: float = 120.0
const JUGGLE_FALL_GRAVITY: float = 1.6
const JUGGLE_POP: float = 3.0          # vertical pop when a non-launch hit connects on a launched target
const DOWNED_DAMAGE: float = 0.5
const CHAIN_WINDOW: float = 0.6
const INPUT_BUFFER: float = 0.25
const BODY_RADIUS: float = 0.4
const BODY_HEIGHT: float = 1.8
const TURN_SPEED: float = 14.0
const KNOCK_FRICTION_GROUND: float = 14.0
const KNOCK_FRICTION_AIR: float = 3.0
const SEPARATION_STRENGTH: float = 8.0
const COMBO_RESET: float = 1.2
const CAST_MOVE_FACTOR: float = 0.7
const CORPSE_FREE_TIME: float = 1.2    # summons are freed this long after death
const CHAR_VISUAL_PATH: String = "res://visuals/character_visual.gd"
const TEAM_COLORS: Array[Color] = [Color(0.25, 0.5, 1.0), Color(1.0, 0.3, 0.25), Color(0.3, 0.85, 0.4),
	Color(0.95, 0.8, 0.3)]

# ------------------------------------------------------------------ identity
var uid: int = 0
var kind: String = "player"
var peer: int = 0
var team: int = 0
var display_name: String = ""
var class_id: String = ""
var mob_id: String = ""
var kit: ClassKit = null
var owner_uid: int = 0
var mob_def: Dictionary = {}        # mob / boss / summon definition (kit == null)
var body_scale: float = 1.0

# ------------------------------------------------------------------ replicated state
var hp: float = 1.0
var max_hp: float = 1.0
var mp: float = 0.0
var max_mp: float = 0.0
var state: int = State.IDLE
var anim_key: StringName = &"idle"
var anim_speed: float = 1.0
var anim_seq: int = 0                # bumps whenever an animation must restart (same key re-trigger)
var status_mask: int = 0
var shield_hp: float = 0.0
var combo_count: int = 0
var target_uid: int = 0
var facing_yaw: float = 0.0
var cooldowns_packed: PackedFloat32Array = PackedFloat32Array()
var charges_packed: PackedInt32Array = PackedInt32Array()
var cast_slot: int = -1
var is_stealthed: bool = false
## Replicated weapon form override (e.g. Unspecialized umbrella forms). "" = the kit's default weapon.
## Host sets it (kits: f.weapon_form = "umbrella_gun"); every peer calls visual.set_weapon when it changes.
var weapon_form: String = ""
var _vis_weapon_form: String = ""

# ------------------------------------------------------------------ simulation (host)
var stats: Dictionary = {}
var stat_bonus: Dictionary = {}      # key -> additive fraction (e.g. {"patk": 0.2, "dmg_out": 0.1, "dmg_in": -0.1})
var status: StatusSet
var input: FighterInput
var brain: Node = null
var visual: Node3D = null
var runner: SkillRunner = null
var skills: Array[SkillDef] = []
var threat: Dictionary = {}          # attacker uid -> accumulated threat (bosses/mobs)
var last_attacker_uid: int = 0       # replicated ON_CHANGE (client kill feed)
var kills: int = 0                   # replicated ON_CHANGE
var deaths: int = 0                  # replicated ON_CHANGE
var damage_dealt: float = 0.0        # host: exact; clients: integer mirror updated <= STAT_SYNC_HZ
var healing_done: float = 0.0        # host: exact; clients: integer mirror updated <= STAT_SYNC_HZ
var juggle_points: float = 0.0
## Per-fighter gravity multiplier (flight / hover skills). Reset to 1 by reset_for_round(). Ignored while LAUNCHED.
var gravity_scale: float = 1.0
## > 0 caps the fall speed (m/s) while not LAUNCHED (glide). Reset by reset_for_round().
var max_fall_speed: float = 0.0
## Small kit-defined counter replicated to clients (e.g. stacks for the HUD). Host writes it.
var kit_counter: int = 0
## Optional maximum for kit_counter (0 = no maximum / not shown as a meter).
var kit_counter_max: int = 0
## Replicated integer mirrors of damage_dealt / healing_done (throttled, see STAT_SYNC_HZ).
var net_damage_dealt: int = 0:
	set(v):
		net_damage_dealt = v
		if not _is_host():
			damage_dealt = float(v)
var net_healing_done: int = 0:
	set(v):
		net_healing_done = v
		if not _is_host():
			healing_done = float(v)
## Replicated position. Host: same as `position`. Clients: buffered and interpolated (see _client_smooth).
var net_pos: Vector3:
	get:
		return position
	set(v):
		_net_pos_in(v)

const STAT_SYNC_HZ: float = 4.0
## Client-side interpolation of replicated position/yaw (render delay in seconds). Host simulation is unaffected.
static var client_smoothing: bool = true
static var interp_delay: float = 0.1
const SNAP_DISTANCE: float = 4.0     # consecutive snapshots further apart than this teleport (blink, reset)
const MAX_SNAPS: int = 40
var _snaps: Array = []               # [time_s, pos, yaw] oldest first (clients only)
var _stat_sync_t: float = 0.0
var _body_radius: float = BODY_RADIUS
var _body_height: float = BODY_HEIGHT

var _world: World = null
var _time: float = 0.0
var _state_time: float = 0.0
var _timer: float = 0.0
var _since_hit: float = 99.0
var _no_recover: bool = false
var _force_knockdown: bool = false
var _left_ground: bool = false
var _jump_buffer: float = 0.0
var _cd: PackedFloat32Array = PackedFloat32Array()
var _charges: PackedInt32Array = PackedInt32Array()
var _chain_index: int = 0
var _chain_time: float = -99.0
var _buffered_slot: int = -1
var _buffer_left: float = 0.0
var _knock_vel: Vector3 = Vector3.ZERO
var _move: Vector3 = Vector3.ZERO
var _last_press_id: int = -1
var _combo_timer: float = 0.0
var _corpse_timer: float = 0.0
var _runner_fresh: bool = false
## Set by SkillRunner (dash) – horizontal velocity override while casting.
var skill_velocity: Vector3 = Vector3.ZERO
## Set by SkillRunner (leap) – the runner moved the body directly this frame; skip physics.
var motion_override: bool = false
## Set by SkillRunner (dash through enemies) – disables soft separation.
var ghost: bool = false
var _grabbed_by: Fighter = null
var _grab_final: Dictionary = {}
var _wall_fx_t: float = -10.0
var _grab_throw: Dictionary = {}

# visual-side caches (all peers)
var _vis_anim: StringName = &""
var _vis_seq: int = -1
var _vis_speed: float = -1.0
var _vis_mask: int = -1
var _vis_alpha: float = -1.0
var _vis_hidden: bool = false
var _vis_hp: float = -1.0
# cosmetic audio (all peers, local): footsteps by distance run, jump on the jump animation edge
const STEP_STRIDE: float = 1.9
var _aud_anim: StringName = &""
var _aud_pos: Vector3 = Vector3.ZERO
var _aud_step: float = 0.0


# ================================================================== setup
func _init() -> void:
	status = StatusSet.new(self)
	input = FighterInput.new()


## Called by World._spawn_fighter on every peer BEFORE the node enters the tree.
func setup(data: Dictionary) -> void:
	uid = int(data.get("uid", 0))
	kind = str(data.get("kind", "player"))
	peer = int(data.get("peer", 0))
	team = int(data.get("team", 0))
	display_name = str(data.get("name", ""))
	class_id = str(data.get("class_id", ""))
	mob_id = str(data.get("mob_id", ""))
	owner_uid = int(data.get("owner_uid", 0))
	name = str(uid)
	position = CoreUtil.to_vec3(data.get("pos", Vector3.ZERO))
	facing_yaw = float(data.get("yaw", 0.0))
	rotation.y = facing_yaw
	_resolve_definition()
	var base: Dictionary = ClassKit.DEFAULT_STATS.duplicate()
	var src_stats: Variant = kit.get_stats() if kit != null else mob_def.get("stats", {})
	if src_stats is Dictionary:
		for k: Variant in src_stats:
			base[k] = float(src_stats[k])
	stats = base
	max_hp = maxf(1.0, float(stats["hp"]))
	hp = max_hp
	max_mp = maxf(0.0, float(stats["mp"]))
	mp = max_mp
	if display_name == "":
		display_name = _default_name()
	_init_cooldowns()
	_build_collision()
	_create_visual()
	_build_sync()


func _resolve_definition() -> void:
	kit = null
	mob_def = {}
	if kind == "summon":
		var owner_kit := CoreUtil.get_kit(class_id)
		if owner_kit != null and owner_kit.summons.has(mob_id) and owner_kit.summons[mob_id] is Dictionary:
			mob_def = owner_kit.summons[mob_id]
		else:
			mob_def = CoreUtil.get_mob_def(mob_id)
		if mob_def.is_empty():
			CoreUtil.warn_once("summon_def_" + mob_id, "Fighter: summon def '%s' not found (kit '%s')" % [mob_id, class_id])
	elif (kind == "mob" or kind == "boss") and mob_id != "":
		mob_def = CoreUtil.get_mob_def(mob_id)
		if mob_def.is_empty():
			CoreUtil.warn_once("mob_def_" + mob_id, "Fighter: mob def '%s' not found" % mob_id)
	else:
		kit = CoreUtil.get_kit(class_id)
		if kit == null and class_id != "":
			CoreUtil.warn_once("kit_" + class_id, "Fighter: class kit '%s' not found" % class_id)
	skills.clear()
	if kit != null:
		for s: SkillDef in kit.skills:
			if s != null:
				skills.append(s)
	else:
		var arr: Variant = mob_def.get("skills", [])
		if arr is Array:
			for s: Variant in arr:
				if s is SkillDef:
					skills.append(s)
				elif s is Dictionary:
					skills.append(SkillDef.from_dict(s))
	body_scale = float(mob_def.get("scale", 1.0)) if kit == null else 1.0
	body_scale = clampf(body_scale, 0.2, 6.0)
	# Capsule: def keys body_radius / body_height (meters, absolute) override the scaled defaults.
	_body_radius = BODY_RADIUS * body_scale
	_body_height = BODY_HEIGHT * body_scale
	if kit == null:
		var br: Variant = mob_def.get("body_radius", null)
		if (br is float or br is int) and float(br) > 0.0:
			_body_radius = clampf(float(br), 0.1, 6.0)
		var bh: Variant = mob_def.get("body_height", null)
		if (bh is float or bh is int) and float(bh) > 0.0:
			_body_height = clampf(float(bh), 0.3, 20.0)
	_body_height = maxf(_body_height, _body_radius * 2.0)


func _default_name() -> String:
	if kit != null:
		return kit.display_name()
	if not mob_def.is_empty():
		return "%s %s" % [mob_def.get("name_cn", ""), mob_def.get("name_en", mob_id)]
	return "Fighter %d" % uid


func _init_cooldowns() -> void:
	var n := 8
	for s: SkillDef in skills:
		n = maxi(n, s.slot + 1)
	_cd.resize(n)
	_charges.resize(n)
	cooldowns_packed.resize(n)
	charges_packed.resize(n)
	for i in n:
		_cd[i] = 0.0
		var s := get_skill(i)
		_charges[i] = s.charges if s != null else 1
	_pack_cooldowns()


func _build_collision() -> void:
	collision_layer = CoreUtil.LAYER_FIGHTERS
	collision_mask = CoreUtil.LAYER_WORLD
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	var shape := CapsuleShape3D.new()
	shape.radius = _body_radius
	shape.height = _body_height
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = shape
	cs.position = Vector3(0.0, _body_height * 0.5, 0.0)
	add_child(cs)


func _create_visual() -> void:
	var model := ""
	var weapon := ""
	var offhand := ""
	var tint := TEAM_COLORS[posmod(team, TEAM_COLORS.size())]
	if kit != null:
		model = kit.model if kit.model != "" else kit.id   # CharacterVisual resolves a class id to its body
		weapon = kit.weapon_type
		offhand = kit.offhand
		tint = kit.tint
	elif not mob_def.is_empty():
		model = str(mob_def.get("model", ""))
		weapon = str(mob_def.get("weapon_type", ""))
		offhand = str(mob_def.get("offhand", ""))
		tint = CoreUtil.to_color(mob_def.get("tint", tint), tint)
	var v: Node3D = null
	if ResourceLoader.exists(CHAR_VISUAL_PATH):
		var scr: Variant = load(CHAR_VISUAL_PATH)
		if scr is Script and _script_has_method(scr, "create"):
			var made: Variant = (scr as Script).call("create", model, weapon, offhand, tint)
			if made is Node3D:
				v = made
	if v == null:
		var fb := FallbackVisual.new()
		fb.build(TEAM_COLORS[posmod(team, TEAM_COLORS.size())], tint, weapon)
		v = fb
	v.name = "Visual"
	v.scale = Vector3.ONE * body_scale
	add_child(v)
	visual = v


static func _script_has_method(scr: Script, method: String) -> bool:
	for m: Dictionary in scr.get_script_method_list():
		if str(m.get("name", "")) == method:
			return true
	return false


## Position is replicated through `net_pos` (after facing_yaw, so each snapshot carries the matching yaw).
const SYNC_ALWAYS: Array[String] = ["facing_yaw", "net_pos", "velocity", "anim_key", "anim_speed"]
const SYNC_ON_CHANGE: Array[String] = ["hp", "max_hp", "mp", "max_mp", "state", "status_mask", "shield_hp",
	"team", "combo_count", "target_uid", "cooldowns_packed", "charges_packed", "cast_slot", "is_stealthed",
	"anim_seq", "weapon_form", "kit_counter", "kit_counter_max", "last_attacker_uid", "kills", "deaths",
	"net_damage_dealt", "net_healing_done"]


func _build_sync() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for p: String in SYNC_ALWAYS:
		var path := NodePath(".:" + p)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		cfg.property_set_spawn(path, true)
	for p: String in SYNC_ON_CHANGE:
		var path := NodePath(".:" + p)
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		cfg.property_set_spawn(path, true)
	sync.replication_config = cfg
	# Sim runs at the 60 Hz physics rate: never re-send per render frame.
	sync.replication_interval = 1.0 / 60.0
	sync.delta_interval = 1.0 / 30.0
	sync.set_multiplayer_authority(1)
	add_child(sync)


func _enter_tree() -> void:
	var n: Node = get_parent()
	while n != null and not (n is World):
		n = n.get_parent()
	_world = n as World
	if _world == null:
		_world = World.get_instance()


func _ready() -> void:
	if _world != null:
		_world._register(self)
	if _is_host() and kit != null:
		kit.on_spawn(self)


func _exit_tree() -> void:
	if _world != null:
		_world._unregister(self)


func world() -> World:
	if _world == null or not is_instance_valid(_world):
		_world = World.get_instance()
	return _world


func _is_host() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.is_server()


# ================================================================== queries
func is_alive() -> bool:
	return state != State.DEAD and hp > 0.0


func is_enemy(other: Fighter) -> bool:
	return other != null and other != self and is_instance_valid(other) and other.team != team \
		and other.is_alive() and is_alive()


func is_ally(other: Fighter) -> bool:
	return other != null and is_instance_valid(other) and other.team == team


## Can be affected by attacks at all (alive and not invulnerable).
func is_hittable() -> bool:
	return is_alive() and not status.has(&"invuln")


func is_downed() -> bool:
	return state == State.KNOCKDOWN or state == State.GETUP


func is_airborne() -> bool:
	return state == State.LAUNCHED or not is_on_floor()


func is_player_controlled() -> bool:
	return kind == "player"


func get_owner_fighter() -> Fighter:
	if owner_uid == 0 or world() == null:
		return null
	return world().get_fighter(owner_uid)


func center() -> Vector3:
	return global_position + Vector3(0.0, _body_height * 0.5, 0.0)


func radius() -> float:
	return _body_radius


func height() -> float:
	return _body_height


func get_stat(key: String) -> float:
	var base := float(stats.get(key, ClassKit.DEFAULT_STATS.get(key, 0.0)))
	var m := 1.0 + float(stat_bonus.get(key, 0.0))
	match key:
		"move_speed":
			m *= (1.0 - clampf(status.power(&"slow"), 0.0, 0.95)) * (1.0 + maxf(0.0, status.power(&"haste"))) \
				* (1.0 - clampf(status.power(&"weight"), 0.0, 0.95))
		"jump_velocity":
			m *= 1.0 - clampf(status.power(&"weight"), 0.0, 0.95)
		"patk":
			m += status.power(&"atk_up")
			m *= 1.0 - clampf(status.power(&"atk_down"), 0.0, 0.95)
		"matk":
			m += status.power(&"atk_up") + status.power(&"matk_up")
			m *= 1.0 - clampf(status.power(&"atk_down"), 0.0, 0.95)
		"pdef", "mdef":
			m += status.power(&"def_up") - status.power(&"def_down")
		"cast_speed":
			m *= 1.0 - clampf(status.power(&"cast_slow"), 0.0, 0.95)
	return base * maxf(m, 0.0)


func can_act() -> bool:
	if not is_alive():
		return false
	if status.is_disabled():
		return false
	return state == State.IDLE or state == State.MOVE or state == State.AIR


func has_status(id: StringName) -> bool:
	return status.has(id)


func forward() -> Vector3:
	return CoreUtil.dir_of_yaw(facing_yaw)


func right() -> Vector3:
	return forward().cross(Vector3.UP)


func get_target() -> Fighter:
	if target_uid == 0 or world() == null:
		return null
	var t := world().get_fighter(target_uid)
	if t == null or not t.is_alive():
		return null
	if t.is_stealthed and t.team != team:
		return null
	return t


func aim_point() -> Vector3:
	var t := get_target()
	if t != null and t != self:
		return t.center()
	if input != null and input.aim_point != Vector3.ZERO:
		return input.aim_point
	return center() + forward() * 10.0


func face_towards(p: Vector3) -> void:
	var d := CoreUtil.flat(p - global_position)
	if d.length_squared() < 0.0004:
		return
	facing_yaw = CoreUtil.yaw_of(d.normalized())
	rotation.y = facing_yaw


# ================================================================== skills / cooldowns
func get_skill(slot: int) -> SkillDef:
	for s: SkillDef in skills:
		if s.slot == slot:
			return s
	return null


func find_skill(id: StringName) -> SkillDef:
	if kit != null:
		var s := kit.get_skill_by_id(id)
		if s != null:
			return s
	for s: SkillDef in skills:
		if s.id == id:
			return s
	var reg := CoreUtil.registry()
	if reg != null and reg.has_method("get_skill"):
		var r: Variant = reg.call("get_skill", id)
		if r is SkillDef:
			return r
	return null


func _chain_next_index(base: SkillDef) -> int:
	if base.chain.is_empty():
		return 0
	var advancing := (state == State.CAST and cast_slot == 0) or (_time - _chain_time) <= CHAIN_WINDOW
	if advancing and _chain_index + 1 < base.chain.size():
		return _chain_index + 1
	return 0


## The SkillDef a press of `slot` would cast right now (resolves the slot-0 press chain).
func resolve_skill(slot: int) -> SkillDef:
	var base := get_skill(slot)
	if base == null or slot != 0 or base.chain.is_empty():
		return base
	var idx := _chain_next_index(base)
	var s := find_skill(base.chain[idx])
	return s if s != null else base


func get_cooldown(slot: int) -> float:
	return _cd[slot] if slot >= 0 and slot < _cd.size() else 0.0


func get_charges(slot: int) -> int:
	return _charges[slot] if slot >= 0 and slot < _charges.size() else 0


func reset_cooldowns() -> void:
	for i in _cd.size():
		_cd[i] = 0.0
		var s := get_skill(i)
		_charges[i] = s.charges if s != null else 1
	_pack_cooldowns()


## Max charges of `slot` (1 when the slot has no skill).
func max_charges(slot: int) -> int:
	var s := get_skill(slot)
	return maxi(1, s.charges) if s != null else 1


## Host: gives back `n` charges to `slot` (capped at the skill's charges). A full slot stops its timer.
func restore_charge(slot: int, n: int = 1) -> void:
	if slot < 0 or slot >= _charges.size() or n <= 0:
		return
	var mx := max_charges(slot)
	_charges[slot] = mini(mx, _charges[slot] + n)
	if _charges[slot] >= mx:
		_cd[slot] = 0.0
	_pack_cooldowns()


## Host: sets the seconds until `slot`'s next charge. t > 0 on a full slot consumes one charge so the timer
## runs (a 1-charge skill becomes uncastable for t seconds); t <= 0 refills the slot completely.
func set_cooldown(slot: int, t: float) -> void:
	if slot < 0 or slot >= _cd.size():
		return
	var mx := max_charges(slot)
	if t <= 0.0:
		_cd[slot] = 0.0
		_charges[slot] = mx
	else:
		if _charges[slot] >= mx:
			_charges[slot] = mx - 1
		_cd[slot] = t
	_pack_cooldowns()


## Empty string = castable; otherwise one of: dead, no_skill, silenced, busy, cooldown, mp, requires, kit.
func cast_block_reason(slot: int) -> String:
	if not is_alive():
		return "dead"
	var s := resolve_skill(slot)
	if s == null:
		return "no_skill"
	if slot != 0 and status.has(&"silence"):
		return "silenced"
	if state == State.CAST:
		if runner == null or not runner.can_cancel_into(slot):
			return "busy"
	elif not can_act():
		return "busy"
	if slot < 0 or slot >= _charges.size() or _charges[slot] <= 0:
		return "cooldown"
	if mp < s.mp_cost:
		return "mp"
	if not _requires_ok(s):
		return "requires"
	if kit != null and not kit.can_cast_extra(self, s):
		return "kit"
	return ""


func can_cast(slot: int) -> bool:
	return cast_block_reason(slot) == ""


func _requires_ok(s: SkillDef) -> bool:
	if s.requires.is_empty():
		return true
	var t := get_target()
	for k: Variant in s.requires:
		var v: Variant = s.requires[k]
		match str(k):
			"airborne":
				if (not is_on_floor()) != bool(v):
					return false
			"grounded":
				if is_on_floor() != bool(v):
					return false
			"has_target":
				if (t != null) != bool(v):
					return false
			"target_downed":
				if (t != null and t.is_downed()) != bool(v):
					return false
			"target_airborne":
				if (t != null and t.is_airborne()) != bool(v):
					return false
			"target_range":
				if t == null or global_position.distance_to(t.global_position) > float(v):
					return false
			"hp_below":
				if hp / max_hp >= float(v):
					return false
			"hp_above":
				if hp / max_hp <= float(v):
					return false
			"status":
				if not status.has(StringName(str(v))):
					return false
			"no_status":
				if status.has(StringName(str(v))):
					return false
			_:
				CoreUtil.warn_once("requires_" + str(k), "SkillDef.requires: unknown key '%s' ignored" % k)
	return true


## Host only. Validates and starts the skill in `slot`, paying costs.
func try_cast(slot: int) -> bool:
	if not _is_host():
		return false
	if cast_block_reason(slot) != "":
		return false
	var base := get_skill(slot)
	var s := resolve_skill(slot)
	if slot == 0 and base != null and not base.chain.is_empty():
		_chain_index = _chain_next_index(base)
	mp -= s.mp_cost
	_consume_charge(slot, s.cooldown)
	start_skill(s, slot)
	return true


## Starts a skill without checking/paying costs (used by try_cast, kits, brains and tests). Host only.
func start_skill(s: SkillDef, slot: int = -1) -> SkillRunner:
	if s == null or not is_alive():
		return null
	if runner != null:
		if cast_slot == 0:
			_chain_time = _time
		runner.cancel()
		runner = null
	var actual_slot := slot if slot >= 0 else s.slot
	_set_state(State.CAST)
	cast_slot = actual_slot
	var ap := aim_point()
	if CoreUtil.flat(ap - global_position).length() > 0.3:
		face_towards(ap)
	runner = SkillRunner.new(self, s, actual_slot)
	anim_key = s.anim
	anim_speed = s.anim_speed * runner.rate
	anim_seq += 1
	skill_velocity = Vector3.ZERO
	skill_cast.emit(self, actual_slot)
	if kit != null:
		kit.on_skill_cast(self, s)
	runner.start()
	_runner_fresh = true
	if runner != null and runner.finished:
		_end_cast()
	return runner


func _consume_charge(slot: int, cooldown: float) -> void:
	if slot < 0 or slot >= _charges.size() or cooldown <= 0.0:
		return
	_charges[slot] -= 1
	if _cd[slot] <= 0.0:
		_cd[slot] = cooldown


func _tick_cooldowns(delta: float) -> void:
	for i in _cd.size():
		var s := get_skill(i)
		var max_c := s.charges if s != null else 1
		if _charges[i] >= max_c:
			_cd[i] = 0.0
			continue
		_cd[i] -= delta
		if _cd[i] <= 0.0:
			_charges[i] += 1
			_cd[i] = (s.cooldown + _cd[i]) if (s != null and _charges[i] < max_c) else 0.0
	_pack_cooldowns()


func _pack_cooldowns() -> void:
	if cooldowns_packed.size() != _cd.size():
		cooldowns_packed.resize(_cd.size())
		charges_packed.resize(_cd.size())
	for i in _cd.size():
		# Rounded up to 0.1 s so the ON_CHANGE sync fires ~10x/s instead of every tick.
		cooldowns_packed[i] = ceilf(maxf(_cd[i], 0.0) * 10.0) / 10.0
		charges_packed[i] = _charges[i]


func _end_cast() -> void:
	if cast_slot == 0:
		_chain_time = _time
	runner = null
	cast_slot = -1
	skill_velocity = Vector3.ZERO
	ghost = false
	if state == State.CAST:
		_to_neutral()


## Stops the current skill (remaining steps cancelled). Used for hit interrupts and death.
func interrupt_cast() -> void:
	if runner != null:
		var r := runner
		runner = null
		r.interrupt()
	cast_slot = -1
	skill_velocity = Vector3.ZERO
	ghost = false
	motion_override = false


# ================================================================== input
@rpc("any_peer", "call_local", "unreliable_ordered")
func submit_input(d: Dictionary) -> void:
	if not _is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != peer:
		return
	apply_input(FighterInput.from_dict(d))


## Host: merge a controller input frame. Edges (pressed/jump) are latched until the next host tick and
## de-duplicated by press_id so resent packets do not double-press.
func apply_input(inp: FighterInput) -> void:
	input.move = inp.move
	input.aim_point = inp.aim_point
	input.aim_dir = inp.aim_dir
	input.held = inp.held
	input.target_uid = inp.target_uid
	if inp.press_id != _last_press_id:
		_last_press_id = inp.press_id
		input.pressed |= inp.pressed
		input.jump = input.jump or inp.jump


func _consume_input(delta: float) -> void:
	# Lock-on target (taunt forces it).
	var desired := input.target_uid
	if status.has(&"taunted"):
		var taunter := status.source(&"taunted")
		if taunter != null and taunter.is_alive():
			desired = taunter.uid
	if desired != 0 and world() != null:
		var t := world().get_fighter(desired)
		if t == null or not t.is_alive() or (t.is_stealthed and t.team != team):
			desired = 0
	target_uid = desired
	# Movement intent.
	_move = CoreUtil.flat(input.move).limit_length(1.0)
	if status.has(&"confusion"):
		_move = -_move
	# Jump edge.
	if input.jump:
		match state:
			State.KNOCKDOWN:
				_try_quick_recover()
			State.LAUNCHED:
				_jump_buffer = QUICK_RECOVER_PREBUFFER
			_:
				if can_act() and is_on_floor() and not status.has(&"root"):
					velocity.y = get_stat("jump_velocity")
					_set_state(State.AIR)
					_left_ground = false
	# Skill presses (lowest slot first among simultaneous presses; failures due to "busy" are buffered).
	var pressed := input.pressed
	if pressed != 0:
		for slot in 15:
			if (pressed & (1 << slot)) == 0:
				continue
			if try_cast(slot):
				_buffered_slot = -1
				break
			if cast_block_reason(slot) == "busy":
				_buffered_slot = slot
				_buffer_left = INPUT_BUFFER
	elif _buffered_slot >= 0:
		_buffer_left -= delta
		if _buffer_left <= 0.0:
			_buffered_slot = -1
		elif try_cast(_buffered_slot):
			_buffered_slot = -1
	input.clear_edges()


func _try_quick_recover() -> bool:
	if state != State.KNOCKDOWN or _no_recover or _state_time > QUICK_RECOVER_WINDOW:
		return false
	_enter_getup()
	CoreUtil.fx(&"play", [&"blink", global_position, forward(), Color(0.8, 0.9, 1.0), 0.6])
	return true


# ================================================================== host tick
## One host simulation step. Called by World.step().
func host_tick(delta: float) -> void:
	_time += delta
	_state_time += delta
	_stat_sync_t -= delta
	if _stat_sync_t <= 0.0:
		sync_stats()
	if state == State.DEAD:
		_tick_dead(delta)
		return
	_runner_fresh = false
	_since_hit += delta
	if _since_hit > JUGGLE_RESET_TIME:
		juggle_points = 0.0
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_count = 0
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_tick_cooldowns(delta)
	mp = minf(max_mp, mp + get_stat("mp_regen") * delta)
	status.tick(delta)
	if not is_alive():
		return
	if kit != null:
		kit.on_tick(self, delta)
	_consume_input(delta)
	if runner != null:
		if not _runner_fresh:
			runner.tick(delta)
		if runner != null and runner.finished:
			_end_cast()
	_tick_state(delta)
	_physics_move(delta)
	_post_move()
	_update_facing(delta)
	_update_derived()
	_select_anim()


## Host: pushes the integer damage/heal mirrors (replicated ON_CHANGE). Called at STAT_SYNC_HZ by host_tick;
## call it directly to publish immediately (e.g. at match end).
func sync_stats() -> void:
	_stat_sync_t = 1.0 / STAT_SYNC_HZ
	var d := int(damage_dealt)
	if d != net_damage_dealt:
		net_damage_dealt = d
	var h := int(healing_done)
	if h != net_healing_done:
		net_healing_done = h


func _tick_dead(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_clamp_bounds()
	if kind == "summon":
		_corpse_timer += delta
		if _corpse_timer >= CORPSE_FREE_TIME and not is_queued_for_deletion():
			queue_free()


func _set_state(s: int) -> void:
	if state != s:
		state = s
		_state_time = 0.0


func _to_neutral() -> void:
	if not is_alive():
		return
	if status.is_disabled():
		_set_state(State.STUNNED)
	elif is_on_floor():
		_set_state(State.IDLE)
	else:
		_set_state(State.AIR)


## Host: public escape helper. Clears knockback/juggle and leaves LAUNCHED / HITSTUN / KNOCKDOWN / GETUP / GRABBED
## for IDLE or AIR (STUNNED if still disabled by a status). Upward launch velocity is cancelled. Dead or casting
## fighters are left alone. Returns true if the state changed.
func recover_to_neutral() -> bool:
	if not is_alive():
		return false
	_knock_vel = Vector3.ZERO
	juggle_points = 0.0
	_force_knockdown = false
	_no_recover = false
	_jump_buffer = 0.0
	if state == State.GRABBED:
		_grabbed_by = null
	match state:
		State.LAUNCHED, State.HITSTUN, State.KNOCKDOWN, State.GETUP, State.GRABBED:
			velocity.y = minf(velocity.y, 0.0)
			var before := state
			_timer = 0.0
			_to_neutral()
			if state == before:
				_set_state(State.IDLE if is_on_floor() else State.AIR)
			anim_seq += 1
			return true
	return false


## Host: flight/hover helper. gscale multiplies gravity, fall_cap > 0 caps the fall speed (m/s).
func set_hover(gscale: float, fall_cap: float = 0.0) -> void:
	gravity_scale = maxf(0.0, gscale)
	max_fall_speed = maxf(0.0, fall_cap)


func clear_hover() -> void:
	gravity_scale = 1.0
	max_fall_speed = 0.0


func _tick_state(delta: float) -> void:
	match state:
		State.HITSTUN:
			_timer -= delta
			if _timer <= 0.0:
				_to_neutral()
		State.KNOCKDOWN:
			_timer -= delta
			if _timer <= 0.0:
				_enter_getup()
		State.GETUP:
			_timer -= delta
			if _timer <= 0.0:
				_no_recover = false
				_to_neutral()
		State.GRABBED:
			_tick_grabbed(delta)
		State.STUNNED:
			if not status.is_disabled():
				_to_neutral()
		State.IDLE, State.MOVE, State.AIR, State.CAST:
			if status.is_disabled():
				interrupt_cast()
				_set_state(State.STUNNED)
			elif state == State.IDLE or state == State.MOVE:
				_set_state(State.MOVE if _move.length() > 0.1 and not status.has(&"root") else State.IDLE)


func _physics_move(delta: float) -> void:
	if motion_override:
		motion_override = false
		velocity = Vector3.ZERO
		_clamp_bounds()
		return
	if state == State.GRABBED:
		velocity = Vector3.ZERO
		return
	var g := GRAVITY
	var launched := state == State.LAUNCHED
	if launched and juggle_points > JUGGLE_MAX:
		g *= JUGGLE_FALL_GRAVITY
	if not launched:
		g *= gravity_scale
	velocity.y -= g * delta
	if not launched and max_fall_speed > 0.0 and velocity.y < -max_fall_speed:
		velocity.y = -max_fall_speed
	var horiz := Vector3.ZERO
	var rooted := status.has(&"root")
	match state:
		State.IDLE, State.MOVE, State.AIR:
			if not rooted:
				horiz = _move * get_stat("move_speed")
		State.CAST:
			if skill_velocity != Vector3.ZERO:
				horiz = CoreUtil.flat(skill_velocity)
			elif runner != null and runner.skill.move_while_casting and not rooted:
				horiz = _move * get_stat("move_speed") * CAST_MOVE_FACTOR
	horiz += _knock_vel
	var fr := KNOCK_FRICTION_GROUND if is_on_floor() else KNOCK_FRICTION_AIR
	_knock_vel = _knock_vel.move_toward(Vector3.ZERO, fr * delta)
	if not ghost:
		horiz += _separation_push()
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()
	# Cosmetic wall slam: a launched / thrown body hitting a wall at speed (hit-stop + dust; no gameplay change).
	if launched and _knock_vel.length() > 5.0 and is_on_wall() and _time - _wall_fx_t > 0.6:
		_wall_fx_t = _time
		var wn := get_wall_normal()
		CoreUtil.fx(&"impact", [center(), 3.0, -wn, last_attacker_uid])
		CoreUtil.fx(&"play", [&"land_dust", center() - wn * radius(), wn, Color.WHITE, 0.8, last_attacker_uid])
	_clamp_bounds()


func _separation_push() -> Vector3:
	var w := world()
	if w == null:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for o: Fighter in w.fighters:
		if o == self or not is_instance_valid(o) or not o.is_alive() or o.ghost:
			continue
		var d := CoreUtil.flat(global_position - o.global_position)
		if absf(global_position.y - o.global_position.y) > 1.5:
			continue
		var min_d := radius() + o.radius()
		var dist := d.length()
		if dist >= min_d:
			continue
		if dist < 0.001:
			d = CoreUtil.dir_of_yaw(float(uid) * 2.399)
			dist = 0.001
		push += d.normalized() * (min_d - dist) * SEPARATION_STRENGTH
	return push


func _clamp_bounds() -> void:
	var w := world()
	if w == null:
		return
	var p := global_position
	var c := w.clamp_to_bounds(p)
	if p.y < w.bounds.position.y:
		c.y = w.floor_y + 1.0
		velocity = Vector3.ZERO
	if c != p:
		global_position = c


func _post_move() -> void:
	if not is_on_floor():
		_left_ground = true
		return
	match state:
		State.LAUNCHED:
			if (_left_ground or _state_time > 0.15) and velocity.y <= 0.01:
				_enter_knockdown()
				if _jump_buffer > 0.0:
					_try_quick_recover()
		State.AIR:
			if _left_ground or _state_time > 0.15:
				_set_state(State.IDLE)
				CoreUtil.fx(&"play", [&"land_dust", global_position, forward(), Color.WHITE, 0.5])
	_left_ground = false


func _update_facing(delta: float) -> void:
	if state == State.GRABBED or state == State.DEAD or state == State.KNOCKDOWN:
		return
	var desired := facing_yaw
	var turning := false
	if (state == State.IDLE or state == State.MOVE or state == State.AIR) and _move.length() > 0.1:
		desired = CoreUtil.yaw_of(_move.normalized())
		turning = true
	elif state == State.IDLE:
		var t := get_target()
		if t != null:
			var d := CoreUtil.flat(t.global_position - global_position)
			if d.length() > 0.2:
				desired = CoreUtil.yaw_of(d.normalized())
				turning = true
	if turning:
		facing_yaw = rotate_toward(facing_yaw, desired, TURN_SPEED * delta)
	facing_yaw = wrapf(facing_yaw, -PI, PI)
	rotation.y = facing_yaw


func _update_derived() -> void:
	status_mask = status.mask()
	is_stealthed = status.has(&"stealth")
	if shield_hp > 0.0 and not status.has(&"shield"):
		shield_hp = 0.0


func _select_anim() -> void:
	var k: StringName = anim_key
	var sp := 1.0
	match state:
		State.DEAD:
			k = &"death"
		State.CAST:
			return
		State.HITSTUN, State.GRABBED:
			k = &"hit"
		State.LAUNCHED:
			k = &"launched"
		State.KNOCKDOWN:
			k = &"knockdown"
		State.GETUP:
			k = &"getup"
		State.STUNNED:
			k = &"stunned"
		State.AIR:
			k = &"jump" if velocity.y > 0.0 else &"fall"
		State.MOVE:
			k = &"run"
			sp = clampf(get_stat("move_speed") / 6.0, 0.5, 1.8)
		_:
			k = &"block" if status.has(&"block") else &"idle"
	anim_key = k
	anim_speed = sp


# ================================================================== hits
## Host only. Applies a HIT from `src` (may be null for environment), originating at `from_pos`.
## Returns damage dealt to hp (after shields).
func receive_hit(src: Fighter, hit_in: Dictionary, from_pos: Vector3) -> float:
	if not _is_host() or not is_alive():
		return 0.0
	if status.has(&"invuln"):
		return 0.0
	if src != null and not is_instance_valid(src):
		src = null
	var hit := Hit.normalize(hit_in)
	# Grab connect (§4.1): lock the victim only. The full HIT (damage, statuses, stun) is applied
	# once, at release, by _tick_grabbed via _grab_final.
	if bool(hit["grab"]) and float(hit["grab_time"]) > 0.0 and src != null and _can_be_grabbed_by(src, hit):
		_since_hit = 0.0
		last_attacker_uid = src.uid
		src.status.remove(&"stealth")
		_begin_grabbed(src, hit)
		return 0.0
	var res := Combat.compute(src, self, hit, from_pos)
	if bool(res["miss"]):
		CoreUtil.fx(&"damage_number", [center() + Vector3.UP, 0.0, &"miss"])
		return 0.0
	_since_hit = 0.0
	if src != null:
		last_attacker_uid = src.uid
	var reactions := true
	var dmg := float(res["amount"])
	if is_downed() and not bool(hit["otg"]):
		dmg *= DOWNED_DAMAGE
		reactions = false
	if state == State.GRABBED and src != _grabbed_by:
		reactions = false
	if kit != null:
		dmg = kit.on_hit_taken(self, src, hit, dmg)
	dmg = maxf(0.0, dmg)
	var dealt := _apply_damage(dmg, src, res["kind"])
	if src != null:
		src.status.remove(&"stealth")
		src.register_combo()
		# Kits read hit["_blocked"] instead of re-deriving the frontal-block rule.
		hit["_blocked"] = bool(res["blocked"])
		if src.kit != null:
			src.kit.on_hit_dealt(src, self, hit, dealt)
		elif src.kind == "summon":
			_notify_summon_owner(src, hit, dealt)
		var ls := float(hit["lifesteal"])
		if ls > 0.0 and dealt > 0.0:
			src.heal(dealt * ls, src)
		add_threat(src, dealt * float(hit["threat"]))
	var fx_name: StringName = &"hit_heavy" if (float(hit["launch"]) > 0.0 or bool(hit["knockdown"]) or bool(res["crit"])) else &"hit_spark"
	if bool(res["blocked"]):
		fx_name = &"block_spark"
	CoreUtil.fx(&"play", [fx_name, center(), CoreUtil.flat_dir(global_position - from_pos), Color.WHITE, 1.0])
	# Finisher hits (skills tagged "finisher") get the heavy hit-stop / impact frame even when the hit fx is light.
	if fx_name == &"hit_spark" and src != null and src.runner != null and src.runner.skill != null \
			and src.runner.skill.has_tag("finisher"):
		CoreUtil.fx(&"impact", [center(), 3.0, CoreUtil.flat_dir(global_position - from_pos), src.uid])
	if not is_alive():
		return dealt
	var armored := status.has(&"super_armor") and not bool(hit["armor_break"]) and not bool(hit["grab"])
	if reactions:
		_apply_reactions(src, hit, from_pos, bool(res["blocked"]), armored)
	# A guarded frontal hit (§4.1) only chips damage: no hitstun, no stun, no rider statuses.
	if state != State.DEAD and not bool(res["blocked"]):
		for s: Dictionary in hit["statuses"]:
			add_status(s["id"], float(s["dur"]), float(s["power"]), src)
		if float(hit["stun"]) > 0.0 and reactions:
			add_status(&"stun", float(hit["stun"]), 1.0, src)
	return dealt


## A summon's hit reaches its (living) owner's kit: on_hit_dealt(owner, victim, hit, dmg) with
## hit["_by_summon_uid"] = summon uid (removed again afterwards; the hit dict may be shared between victims).
func _notify_summon_owner(summon: Fighter, hit: Dictionary, dealt: float) -> void:
	var o := summon.get_owner_fighter()
	if o == null or not is_instance_valid(o) or not o.is_alive() or o.kit == null:
		return
	hit["_by_summon_uid"] = summon.uid
	o.kit.on_hit_dealt(o, self, hit, dealt)
	hit.erase("_by_summon_uid")


## Damage bookkeeping shared by hits and DoTs: shields, stealth/sleep break, signals, death.
func _apply_damage(amount: float, src: Fighter, num_kind: StringName) -> float:
	var absorbed := 0.0
	if shield_hp > 0.0 and amount > 0.0:
		absorbed = minf(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
		if shield_hp <= 0.0:
			shield_hp = 0.0
			status.remove(&"shield")
	if amount + absorbed > 0.0:
		status.remove(&"stealth")
		status.remove(&"sleep")
		is_stealthed = false
	hp -= amount
	if src != null:
		src.damage_dealt += amount
		if src.kind == "summon":
			var o := src.get_owner_fighter()
			if o != null and o != src:
				o.damage_dealt += amount   # scoreboards credit pets to their owner (summon keeps its own counter)
	CoreUtil.fx(&"damage_number", [center() + Vector3.UP * 0.9, amount + absorbed, num_kind])
	damaged.emit(self, amount, src)
	if hp <= 0.0:
		hp = 0.0
		_die(src)
	return amount


func take_dot_damage(amount: float, src: Fighter, _id: StringName = &"") -> float:
	if not _is_host() or not is_alive() or status.has(&"invuln"):
		return 0.0
	_since_hit = minf(_since_hit, JUGGLE_RESET_TIME)
	var d := _apply_damage(maxf(0.0, amount), src, &"true")
	if src != null and is_instance_valid(src):
		add_threat(src, d)
	return d


## True when a grab HIT from `src` would lock this fighter (same gates as hit reactions).
func _can_be_grabbed_by(src: Fighter, hit: Dictionary) -> bool:
	if state == State.LAUNCHED or state == State.DEAD:
		return false
	if is_downed() and not bool(hit["otg"]):
		return false
	if state == State.GRABBED and src != _grabbed_by:
		return false
	return true


func _apply_reactions(src: Fighter, hit: Dictionary, from_pos: Vector3, blocked: bool, armored: bool) -> void:
	if bool(hit["grab"]) or bool(hit["armor_break"]):
		status.remove(&"block")
		blocked = false
	if armored:
		return
	var kb_dir := CoreUtil.flat_dir(global_position - from_pos, -forward())
	if bool(hit["pull"]):
		kb_dir = -kb_dir
	var kb := float(hit["knockback"])
	if blocked:
		_knock_vel = kb_dir * kb * 0.4
		return
	var interrupted := false
	var launch := float(hit["launch"])
	var airborne := state == State.LAUNCHED or (not is_on_floor() and state != State.GRABBED)
	if launch > 0.0 or state == State.LAUNCHED:
		if not (state == State.LAUNCHED and juggle_points > JUGGLE_MAX):
			var scale := clampf(1.0 - juggle_points / JUGGLE_MAX, 0.25, 1.0)
			var v := launch if launch > 0.0 else JUGGLE_POP
			velocity.y = v * scale
			juggle_points += float(hit["juggle_cost"])
			_enter_launched()
		if bool(hit["knockdown"]):
			_force_knockdown = true
		interrupted = true
	elif bool(hit["knockdown"]):
		if is_on_floor() and not airborne:
			interrupt_cast()
			_enter_knockdown()
		else:
			velocity.y = maxf(velocity.y, 2.0)
			_enter_launched()
		interrupted = true
	elif float(hit["hitstun"]) > 0.0:
		var hs := float(hit["hitstun"])
		if state == State.HITSTUN:
			_timer = maxf(_timer, hs)
		else:
			_timer = hs
		if state != State.KNOCKDOWN and state != State.GETUP:
			_set_state(State.HITSTUN)
		interrupted = true
	if bool(hit["no_recover"]) and (state == State.LAUNCHED or state == State.KNOCKDOWN):
		_no_recover = true
	if kb > 0.0:
		_knock_vel = kb_dir * kb
	if interrupted:
		interrupt_cast()
		anim_seq += 1


func _enter_launched() -> void:
	interrupt_cast()
	if state != State.LAUNCHED:
		_set_state(State.LAUNCHED)
		_left_ground = false
	_state_time = 0.0


func _enter_knockdown() -> void:
	_set_state(State.KNOCKDOWN)
	_timer = KNOCKDOWN_TIME
	juggle_points = 0.0
	_force_knockdown = false
	_knock_vel *= 0.3
	velocity = Vector3.ZERO
	anim_seq += 1
	CoreUtil.fx(&"play", [&"land_dust", global_position, forward(), Color.WHITE, 1.0])


func _enter_getup() -> void:
	_set_state(State.GETUP)
	_timer = GETUP_TIME
	juggle_points = 0.0
	status.add(&"invuln", GETUP_INVULN, 1.0, null)
	anim_seq += 1


func _begin_grabbed(src: Fighter, hit: Dictionary) -> void:
	interrupt_cast()
	status.remove(&"block")
	_set_state(State.GRABBED)
	var gt := float(hit["grab_time"])
	_timer = gt
	_grabbed_by = src
	var fin := Hit.with(hit, {"grab": false, "grab_time": 0.0, "armor_break": true, "no_recover": true})
	_grab_throw = (hit.get("throw", {}) as Dictionary) if hit.get("throw", {}) is Dictionary else {}
	fin.erase("throw")
	_grab_final = fin
	velocity = Vector3.ZERO
	_knock_vel = Vector3.ZERO
	if src.runner != null:
		src.runner.hold_for(gt + 0.05)
	anim_seq += 1


func _tick_grabbed(delta: float) -> void:
	var g := _grabbed_by
	if g == null or not is_instance_valid(g) or not g.is_alive() or g.state != State.CAST:
		_grabbed_by = null
		_to_neutral()
		return
	global_position = g.global_position + g.forward() * (g.radius() + radius() + 0.3) + _grab_side_offset(g)
	face_towards(g.global_position)
	_timer -= delta
	if _timer > 0.0:
		return
	_grabbed_by = null
	_set_state(State.IDLE)
	var fin := _grab_final
	var throw_d := _grab_throw
	receive_hit(g, fin, g.global_position)
	if is_alive() and not throw_d.is_empty():
		var force := float(throw_d.get("force", 8.0))
		match str(throw_d.get("dir", "forward")):
			"back":
				global_position = g.global_position - g.forward() * (g.radius() + radius() + 0.3)
				_knock_vel = -g.forward() * force
				velocity.y = 5.0
			"up":
				velocity.y = force
			_:
				_knock_vel = g.forward() * force
				velocity.y = 5.0
		_no_recover = true
		_enter_launched()
		var ult := g.runner != null and g.runner.skill != null and g.runner.skill.is_ultimate()
		CoreUtil.fx(&"impact", [center(), 4.0 if ult else 3.0, g.forward(), g.uid])


## Sideways offset when one grabber holds several victims: victims (ordered by uid) spread along the
## grabber's right axis, centered, so they do not overlap.
func _grab_side_offset(g: Fighter) -> Vector3:
	var w := world()
	if w == null:
		return Vector3.ZERO
	var held: Array[Fighter] = []
	for o: Fighter in w.fighters:
		if is_instance_valid(o) and o.state == State.GRABBED and o._grabbed_by == g:
			held.append(o)
	if held.size() <= 1:
		return Vector3.ZERO
	held.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.uid < b.uid)
	var idx := held.find(self)
	if idx < 0:
		return Vector3.ZERO
	var spacing := radius() * 2.0 + 0.2
	return g.right() * (float(idx) - float(held.size() - 1) * 0.5) * spacing


func apply_knockback(dir: Vector3, horizontal: float, vertical: float) -> void:
	if not is_alive():
		return
	_knock_vel = CoreUtil.flat_dir(dir, Vector3.ZERO) * horizontal
	if vertical != 0.0:
		velocity.y = vertical


func register_combo() -> void:
	combo_count = combo_count + 1 if _combo_timer > 0.0 else 1
	_combo_timer = COMBO_RESET


func add_threat(src: Fighter, amount: float) -> void:
	if src == null or amount <= 0.0:
		return
	threat[src.uid] = float(threat.get(src.uid, 0.0)) + amount


func top_threat() -> Fighter:
	var best: Fighter = null
	var best_v := -1.0
	var w := world()
	if w == null:
		return null
	for k: Variant in threat:
		var f: Fighter = w.get_fighter(int(k))
		if f == null or not f.is_alive() or not is_enemy(f):
			continue
		if float(threat[k]) > best_v:
			best_v = float(threat[k])
			best = f
	return best


# ================================================================== statuses / heal / death
func add_status(id: StringName, duration: float, power: float = 1.0, src: Fighter = null) -> void:
	if not is_alive() or duration <= 0.0:
		return
	if StatusSet.is_negative(id) and status.has(&"invuln"):
		return
	if StatusSet.DISABLING.has(id) and status.has(&"super_armor"):
		return
	status.add(id, duration, power, src)
	match id:
		&"taunted":
			if src != null:
				var top := 0.0
				for k: Variant in threat:
					top = maxf(top, float(threat[k]))
				threat[src.uid] = top + 1000.0
				target_uid = src.uid
		&"stealth":
			is_stealthed = true
		&"stun", &"freeze", &"sleep":
			if state == State.IDLE or state == State.MOVE or state == State.AIR or state == State.CAST \
					or state == State.HITSTUN:
				interrupt_cast()
				_set_state(State.STUNNED)
	status_mask = status.mask()


func remove_status(id: StringName) -> void:
	status.remove(id)
	if id == &"shield":
		shield_hp = 0.0
	if id == &"stealth":
		is_stealthed = false
	status_mask = status.mask()


## Called by StatusSet when a status times out.
func _on_status_expired(id: StringName) -> void:
	if id == &"shield":
		shield_hp = 0.0
	elif id == &"stealth":
		is_stealthed = false


func add_shield(amount: float, duration: float, src: Fighter = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	shield_hp = maxf(shield_hp, amount)
	status.add(&"shield", duration, 1.0, src)
	status_mask = status.mask()


func cleanse() -> int:
	var n := status.clear_negative()
	status_mask = status.mask()
	if state == State.STUNNED:
		_to_neutral()
	return n


func heal(amount: float, src: Fighter) -> void:
	if not is_alive() or amount <= 0.0:
		return
	var actual := minf(amount, max_hp - hp)
	hp += actual
	if src != null and is_instance_valid(src):
		src.healing_done += actual
		if src.kind == "summon":
			var o := src.get_owner_fighter()
			if o != null and o != src:
				o.healing_done += actual
	if actual >= 1.0:
		CoreUtil.fx(&"damage_number", [center() + Vector3.UP * 0.9, actual, &"heal"])
	healed.emit(self, actual, src)


func revive(hp_fraction: float = 0.3) -> void:
	if is_alive():
		return
	hp = clampf(hp_fraction, 0.01, 1.0) * max_hp
	collision_layer = CoreUtil.LAYER_FIGHTERS
	_corpse_timer = 0.0
	_set_state(State.IDLE)
	status.add(&"invuln", 1.5, 1.0, null)
	anim_seq += 1
	CoreUtil.fx(&"play", [&"heal_burst", global_position, forward(), Color(1, 1, 0.7), 1.5])


## Full reset (new round): hp/mp, statuses, cooldowns, state.
func reset_for_round(pos: Variant = null) -> void:
	interrupt_cast()
	status.clear_all()
	hp = max_hp
	mp = max_mp
	shield_hp = 0.0
	juggle_points = 0.0
	threat.clear()
	combo_count = 0
	_knock_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = CoreUtil.LAYER_FIGHTERS
	_grabbed_by = null
	gravity_scale = 1.0
	max_fall_speed = 0.0
	reset_cooldowns()
	if pos is Vector3:
		global_position = pos
	_set_state(State.IDLE)
	_update_derived()


func kill(killer: Fighter = null) -> void:
	if is_alive():
		hp = 0.0
		_die(killer)


func _die(killer: Fighter) -> void:
	if state == State.DEAD:
		return
	if killer != null and not is_instance_valid(killer):
		killer = null
	interrupt_cast()
	_set_state(State.DEAD)
	hp = 0.0
	status.clear_all()
	shield_hp = 0.0
	status_mask = 0
	is_stealthed = false
	_knock_vel = Vector3.ZERO
	_grabbed_by = null
	collision_layer = 0
	deaths += 1
	anim_key = &"death"
	anim_seq += 1
	if killer != null and killer != self:
		killer.kills += 1
		if killer.kit != null:
			killer.kit.on_kill(killer, self)
	if kit != null:
		kit.on_death(self, killer)
	CoreUtil.fx(&"play", [&"death", global_position, forward(), Color.WHITE, 1.0])
	died.emit(self, killer)


# ================================================================== visuals (all peers)
func _process(delta: float) -> void:
	if _is_host():
		rotation.y = facing_yaw
	elif client_smoothing and not _snaps.is_empty():
		_client_smooth()
	else:
		rotation.y = lerp_angle(rotation.y, facing_yaw, 1.0 - exp(-30.0 * delta))
	_update_visual()
	_update_audio()


## Cosmetic, local on every peer (state is replicated): a footstep every STEP_STRIDE metres while running (bosses
## stomp), and a jump sound when the jump animation starts from the ground. Landing / knockdown / death sounds
## come from the replicated land_dust / death effects.
func _update_audio() -> void:
	var k := anim_key
	var p := global_position
	if k != _aud_anim:
		if k == &"jump" and _aud_anim != &"fall" and _aud_anim != &"launched":
			CoreUtil.fx(&"local_sfx", [&"jump", p, uid])
		_aud_anim = k
	if k == &"run" and not is_stealthed:
		_aud_step += Vector2(p.x - _aud_pos.x, p.z - _aud_pos.z).length()
		var stride := STEP_STRIDE * (1.8 if kind == "boss" else 1.0)
		if _aud_step >= stride:
			_aud_step = 0.0 if _aud_step > stride * 3.0 else _aud_step - stride
			CoreUtil.fx(&"footstep", [p, uid, kind == "boss"])
	else:
		_aud_step = STEP_STRIDE * 0.6   # first step comes quickly after starting to run
	_aud_pos = p


static func _now_s() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


## Client: a replicated position snapshot arrived (Sync applies facing_yaw first, so it is current).
func _net_pos_in(v: Vector3) -> void:
	if not client_smoothing or not is_inside_tree() or _is_host():
		position = v
		_snaps.clear()
		return
	if not _snaps.is_empty():
		var last: Vector3 = _snaps[_snaps.size() - 1][1]
		if last.distance_to(v) > SNAP_DISTANCE:
			_snaps.clear()        # teleport (blink, round reset): no sliding across the map
			position = v
	_snaps.append([_now_s(), v, facing_yaw])
	while _snaps.size() > MAX_SNAPS:
		_snaps.pop_front()


## Client: renders the body interp_delay seconds in the past, interpolating between the two bracketing
## snapshots (holds the newest when packets are late). Host simulation never runs this.
func _client_smooth() -> void:
	var rt := _now_s() - interp_delay
	while _snaps.size() >= 2 and float(_snaps[1][0]) <= rt:
		_snaps.pop_front()
	var a: Array = _snaps[0]
	if _snaps.size() >= 2 and float(a[0]) <= rt:
		var b: Array = _snaps[1]
		var span := maxf(float(b[0]) - float(a[0]), 0.0001)
		var k := clampf((rt - float(a[0])) / span, 0.0, 1.0)
		position = (a[1] as Vector3).lerp(b[1], k)
		rotation.y = lerp_angle(float(a[2]), float(b[2]), k)
	else:
		position = a[1]
		rotation.y = float(a[2])


## Latest replicated (un-interpolated) position: the host's own position, or the newest client snapshot.
func latest_net_position() -> Vector3:
	if _snaps.is_empty():
		return position
	return _snaps[_snaps.size() - 1][1]


func _update_visual() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if anim_key != _vis_anim or anim_seq != _vis_seq or not is_equal_approx(anim_speed, _vis_speed):
		_vis_anim = anim_key
		_vis_seq = anim_seq
		_vis_speed = anim_speed
		if visual.has_method(&"play"):
			visual.call(&"play", anim_key, anim_speed)
	if weapon_form != _vis_weapon_form:
		_vis_weapon_form = weapon_form
		if visual.has_method(&"set_weapon"):
			var wt: String = weapon_form
			if wt == "" and kit != null:
				wt = kit.weapon_type
			if wt != "":
				visual.call(&"set_weapon", wt, kit.offhand if kit != null and weapon_form == "" else "")
	if status_mask != _vis_mask:
		_vis_mask = status_mask
		if visual.has_method(&"set_status_visual"):
			visual.call(&"set_status_visual", status_mask)
	var hidden := false
	var alpha := 1.0
	if is_stealthed:
		var viewer: Fighter = world().local_fighter() if world() != null else null
		if viewer != null and viewer.team != team:
			hidden = true
		else:
			alpha = 0.15
	if hidden != _vis_hidden:
		_vis_hidden = hidden
		visual.visible = not hidden
	if not is_equal_approx(alpha, _vis_alpha):
		_vis_alpha = alpha
		if visual.has_method(&"set_alpha"):
			visual.call(&"set_alpha", alpha)
	if _vis_hp >= 0.0 and hp < _vis_hp - 0.5 and visual.has_method(&"flash_hit"):
		visual.call(&"flash_hit")
	_vis_hp = hp


func hand_position(right_hand := true) -> Vector3:
	if visual != null and visual.has_method(&"get_hand_position"):
		var p: Variant = visual.call(&"get_hand_position", right_hand)
		if p is Vector3 and p != Vector3.ZERO:
			return p
	var side := right() * (0.3 if right_hand else -0.3)
	return global_position + Vector3(0.0, 1.3 * body_scale, 0.0) + forward() * 0.45 + side


func state_name() -> String:
	return STATE_NAMES[state] if state >= 0 and state < STATE_NAMES.size() else str(state)
