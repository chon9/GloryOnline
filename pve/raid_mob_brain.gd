class_name RaidMobBrain
extends Node
## RAID fallback AI (used when res://ai/bot_brain.gd is absent / fails to load, and by deterministic raid
## tests). Drives a Fighter only through fighter.input, exactly like a human.
## Modes:
##  "mob"  - dungeon trash / adds: threat target (taunt respected), heals allies, summons, kites if ranged.
##  "raid" - party member: dodges enemy telegraphs, heals the lowest ally, attacks the nearest engaged enemy,
##           otherwise follows the raid goal published by MatchRaid (fighter meta "raid_goal").

const THINK_INTERVAL: float = 0.1
const AGGRO_RANGE: float = 26.0
const ENGAGE_RANGE: float = 15.0

var fighter: Fighter
var mode: String = "mob"
var role: String = ""
var _think_t: float = 0.0
var _target: Fighter = null
var _press: int = -1
var _strafe: float = 1.0
var _rng := RandomNumberGenerator.new()


func setup(f: Fighter, m: String = "mob") -> void:
	fighter = f
	mode = m


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter
	if fighter != null:
		_rng.seed = 7919 * fighter.uid + 13
		_strafe = 1.0 if fighter.uid % 2 == 0 else -1.0
	role = _derive_role()


func _physics_process(delta: float) -> void:
	var w := World.get_instance()
	if w != null and w.auto_step and w.is_host():
		think(delta)


func _derive_role() -> String:
	if fighter == null:
		return "melee"
	if fighter.kit != null:
		return fighter.kit.role
	var r := str(fighter.mob_def.get("role", ""))
	if r != "":
		return r
	return "melee"


func _is_ranged() -> bool:
	return role == "ranged" or role == "healer" or role == "summoner"


func think(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not fighter.is_alive():
		return
	var w := fighter.world()
	if w == null:
		return
	var inp := fighter.input
	_think_t -= delta
	if _think_t > 0.0:
		return
	_think_t = THINK_INTERVAL
	inp.move = Vector3.ZERO
	_target = _pick_target(w)
	# Party bots get out of telegraphed enemy AoEs first.
	if mode == "raid":
		var away := _danger_dir(w)
		if away != Vector3.ZERO:
			inp.move = away
			_aim(_target)
			return
	# Heal the lowest ally (party healers and mob healers alike).
	var heal_slot := _find_tagged_slot("heal")
	if heal_slot >= 0:
		var low := _lowest_ally(w, 18.0)
		if low != null and low.hp / low.max_hp < (0.65 if mode == "raid" else 0.75):
			_aim(low)
			inp.target_uid = low.uid if mode == "raid" else (_target.uid if _target != null else 0)
			inp.press(heal_slot)
			return
	if _target == null:
		inp.target_uid = 0
		_follow_goal()
		return
	_aim(_target)
	var dist := CoreUtil.flat(_target.global_position - fighter.global_position).length()
	var reach := dist - _target.radius()
	var slot := _choose_slot(reach)
	if slot >= 0:
		inp.press(slot)
	var want := _preferred_range()
	if reach > want:
		inp.move = CoreUtil.flat_dir(_target.global_position - fighter.global_position, Vector3.ZERO)
	elif _is_ranged() and reach < want * 0.45:
		inp.move = -CoreUtil.flat_dir(_target.global_position - fighter.global_position, Vector3.ZERO)


func _aim(t: Fighter) -> void:
	if t == null:
		fighter.input.aim_point = Vector3.ZERO
		return
	fighter.input.target_uid = t.uid
	fighter.input.aim_point = t.center()


func _pick_target(w: World) -> Fighter:
	if fighter.status.has(&"taunted"):
		var tt := fighter.status.source(&"taunted")
		if tt != null and tt.is_alive():
			return tt
	if mode == "mob":
		var top := fighter.top_threat()
		if top != null and top.is_alive() and not top.is_stealthed:
			return top
		return w.nearest_enemy(fighter, AGGRO_RANGE)
	# raid: keep the current target while it lives and is close; prefer enemies that are already engaged.
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree() and _target.is_alive() \
			and fighter.is_enemy(_target) \
			and _target.global_position.distance_to(fighter.global_position) < ENGAGE_RANGE * 1.6:
		return _target
	var best: Fighter = null
	var best_d := ENGAGE_RANGE
	for e: Fighter in w.enemies_of(fighter, false):
		if not e.is_inside_tree() or not _engaged(e):
			continue
		var d := e.global_position.distance_to(fighter.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Raid party only attacks enemies that are part of an active encounter (they have a brain) or attack us.
func _engaged(e: Fighter) -> bool:
	if e.brain != null and is_instance_valid(e.brain):
		return true
	return e.threat.size() > 0


func _follow_goal() -> void:
	if mode != "raid" or not fighter.has_meta("raid_goal"):
		return
	var goal: Vector3 = fighter.get_meta("raid_goal")
	var to := CoreUtil.flat(goal - fighter.global_position)
	if to.length() > 2.5:
		fighter.input.move = to.normalized()


func _preferred_range() -> float:
	if _is_ranged():
		var r := 0.0
		for s: SkillDef in fighter.skills:
			if s.has_tag("ranged") or s.range > 6.0:
				r = maxf(r, s.range)
		return clampf(r * 0.7, 5.0, 12.0)
	var m := 99.0
	for s: SkillDef in fighter.skills:
		if s.slot == 0:
			m = s.range
	if m >= 99.0:
		m = 2.2
	return maxf(1.4, m * 0.8)


func _find_tagged_slot(tag: String) -> int:
	for s: SkillDef in fighter.skills:
		if s.has_tag(tag) and fighter.can_cast(s.slot):
			return s.slot
	return -1


## Highest usable slot whose range reaches the target (skills before the basic attack).
func _choose_slot(reach: float) -> int:
	if not fighter.can_act() and fighter.state != Fighter.State.CAST:
		return -1
	var best := -1
	for s: SkillDef in fighter.skills:
		if s.slot < 0 or s.slot > 7:
			continue
		if s.has_tag("heal") or s.has_tag("escape"):
			continue
		if not fighter.can_cast(s.slot):
			continue
		var r := s.range
		if s.has_tag("buff_self") or s.has_tag("buff_ally") or s.has_tag("defensive") or s.has_tag("summon"):
			r = 8.0
		elif r <= 0.0:
			r = 3.0
		if reach > r + 0.3:
			continue
		if s.slot == 0:
			if best < 0:
				best = 0
			continue
		if best <= 0 or s.slot > best:
			best = s.slot
	return best


func _lowest_ally(w: World, radius: float) -> Fighter:
	var best: Fighter = null
	var best_v := 1.0
	for a: Fighter in w.allies_of(fighter, true, false):
		if a.kind == "summon":
			continue
		if a.global_position.distance_to(fighter.global_position) > radius:
			continue
		var v := a.hp / a.max_hp
		if v < best_v:
			best_v = v
			best = a
	return best


## Direction out of the nearest pending enemy telegraph we stand in (ZERO when safe).
func _danger_dir(w: World) -> Vector3:
	for e: Node in w.effects:
		if not (e is AreaEffect) or not is_instance_valid(e):
			continue
		var a := e as AreaEffect
		if not a.alive or a.team == fighter.team or a.mode == "trap":
			continue
		if a._t >= a.delay and a.duration <= 0.0:
			continue
		if not a.contains(fighter):
			continue
		var to := CoreUtil.flat(fighter.global_position - a.global_position)
		if a.shape == "line":
			var fwd := CoreUtil.dir_of_yaw(a.yaw)
			var rgt := fwd.cross(Vector3.UP)
			var x := to.dot(rgt)
			return rgt * (1.0 if x >= 0.0 else -1.0)
		if a.radius > 15.0:
			continue  # raid-wide: cannot be dodged, stay and fight
		if to.length() < 0.2:
			return CoreUtil.dir_of_yaw(fighter.facing_yaw + PI * 0.5 * _strafe)
		return to.normalized()
	return Vector3.ZERO
