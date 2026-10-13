class_name Summon
extends Fighter
## A Fighter with kind "summon": owned by owner_uid, inherits the owner's team, stats/skills from
## owner.kit.summons[summon_id] (or Registry.mob_defs[summon_id]), expires after life_left seconds.

var life_left: float = -1.0          # < 0 = permanent until killed


func summon_id() -> String:
	return mob_id


func host_tick(delta: float) -> void:
	if is_alive():
		var o := get_owner_fighter()
		if o == null or not o.is_alive():
			expire()
		elif life_left >= 0.0:
			life_left -= delta
			if life_left <= 0.0:
				expire()
	super.host_tick(delta)


## Ends the summon (no killer, no kill credit) and frees it shortly after.
func expire() -> void:
	if not is_alive():
		return
	CoreUtil.fx(&"play", [&"smoke", global_position, forward(), Color.WHITE, 1.0])
	kill(null)
