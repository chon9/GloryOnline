class_name SimplePetBrain
extends Node
## Minimal built-in pet AI used when res://ai/bot_brain.gd is absent: follow the owner, attack the
## owner's target or the nearest enemy near the owner using the summon's skills. Writes fighter.input
## exactly like a human would.

const FOLLOW_DIST: float = 3.0
const LEASH: float = 14.0
const THINK_INTERVAL: float = 0.15

var fighter: Fighter
var mode: String = "pet"
var _think_t: float = 0.0
var _target: Fighter = null


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter


func _physics_process(delta: float) -> void:
	var w := World.get_instance()
	if w != null and w.auto_step and w.is_host():
		think(delta)


func think(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not fighter.is_alive():
		return
	var w := fighter.world()
	if w == null:
		return
	var owner_f := fighter.get_owner_fighter()
	var anchor := owner_f.global_position if owner_f != null else fighter.global_position
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = THINK_INTERVAL
		_target = null
		if owner_f != null:
			var ot := owner_f.get_target()
			if ot != null and fighter.is_enemy(ot):
				_target = ot
		if _target == null:
			var best_d := LEASH
			for e: Fighter in w.enemies_of(fighter, false):
				var d := e.global_position.distance_to(anchor)
				if d < best_d:
					best_d = d
					_target = e
		if fighter.status.has(&"taunted"):
			var tt := fighter.status.source(&"taunted")
			if tt != null:
				_target = tt
	var inp := fighter.input
	inp.move = Vector3.ZERO
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		inp.target_uid = _target.uid
		inp.aim_point = _target.center()
		var dist := fighter.global_position.distance_to(_target.global_position)
		var best_slot := -1
		for s: SkillDef in fighter.skills:
			if fighter.can_cast(s.slot) and dist <= s.range + _target.radius():
				if best_slot < 0 or s.slot > best_slot:
					best_slot = s.slot
		if best_slot >= 0:
			inp.press(best_slot)
		else:
			var min_range := 99.0
			for s: SkillDef in fighter.skills:
				min_range = minf(min_range, s.range)
			if min_range >= 99.0:
				min_range = 2.0
			if dist > min_range * 0.8:
				inp.move = CoreUtil.flat_dir(_target.global_position - fighter.global_position, Vector3.ZERO)
	else:
		inp.target_uid = 0
		inp.aim_point = Vector3.ZERO
		var to := CoreUtil.flat(anchor - fighter.global_position)
		if to.length() > FOLLOW_DIST:
			inp.move = to.normalized()
