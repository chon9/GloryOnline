extends "res://modes/match_pvp.gd"
## 擂台赛 Group Arena (owner: NET): up to 3 fighters per team, one per team on the stage at a time.
## The winner of a bout stays with its remaining hp (+10% max hp heal); the loser's next challenger spawns.
## A team that runs out of fighters loses. Waiting fighters are NOT spawned (their humans spectate).
## Bout timeout: the fighter with the lower hp% is eliminated (both when exactly equal).

const WIN_HEAL: float = 0.10
const NEXT_DELAY: float = 2.5
const CORPSE_TIME: float = 2.0

## Per team: roster slot dicts in fight order.
var queues: Array = [[], []]
## Per team: index of the next slot to send in.
var next_idx: Array[int] = [0, 0]
## Per team: fighter currently on stage (or null).
var current: Array = [null, null]
var bout: int = 0
var _corpses: Array = []   # [{f, t}]


func begin() -> void:
	if not is_host() or running:
		return
	running = true
	for t in 2:
		var q: Array = []
		for slot: Dictionary in roster:
			if int(slot.get("team", 0)) == t:
				q.append(slot)
		queues[t] = q
	for t in 2:
		send_next(t)
	start_bout()


func remaining(team: int) -> int:
	var n: int = (queues[team] as Array).size() - next_idx[team]
	var f: Variant = current[team]
	if f != null and is_instance_valid(f) and (f as Fighter).is_alive():
		n += 1
	return n


## Spawns the next challenger of `team`. Returns false when the team has nobody left.
func send_next(team: int) -> bool:
	var q: Array = queues[team]
	if next_idx[team] >= q.size():
		current[team] = null
		return false
	var slot: Dictionary = q[next_idx[team]]
	next_idx[team] += 1
	current[team] = spawn_slot(slot, spawn_pos(team, 0), spawn_yaw(team), "pvp")
	return current[team] != null


func start_bout() -> void:
	bout += 1
	_clear_field()
	for t in 2:
		var f: Variant = current[t]
		if f != null and is_instance_valid(f):
			place_fighter(f, spawn_pos(t, 0), spawn_yaw(t), false)
	var n0 := _cur_name(0)
	var n1 := _cur_name(1)
	send_announce("第%d场 Bout %d: %s VS %s" % [bout, bout, n0, n1], 2.0)
	start_countdown()


func _cur_name(t: int) -> String:
	var f: Variant = current[t]
	return (f as Fighter).display_name if f != null and is_instance_valid(f) else "-"


func host_tick(delta: float) -> void:
	super.host_tick(delta)
	for c: Dictionary in _corpses.duplicate():
		c["t"] = float(c["t"]) - delta
		if float(c["t"]) <= 0.0:
			_corpses.erase(c)
			var f: Variant = c["f"]
			if f != null and is_instance_valid(f):
				snapshot_stats()
				(f as Fighter).queue_free()


func check_fight() -> void:
	var dead: Array[int] = []
	for t in 2:
		var f: Variant = current[t]
		if f == null or not is_instance_valid(f) or not (f as Fighter).is_alive():
			dead.append(t)
	if dead.is_empty():
		return
	end_bout(dead)


func _on_time_up() -> void:
	if phase != Phase.FIGHT:
		return
	send_announce("时间到 Time up!", 1.5)
	var h: Array[float] = [0.0, 0.0]
	for t in 2:
		var f: Variant = current[t]
		if f != null and is_instance_valid(f):
			h[t] = (f as Fighter).hp / maxf(1.0, (f as Fighter).max_hp)
	var losers: Array[int] = []
	if absf(h[0] - h[1]) < 0.0001:
		losers = [0, 1]
	else:
		losers = [0 if h[0] < h[1] else 1]
	for t: int in losers:
		var f: Variant = current[t]
		if f != null and is_instance_valid(f):
			(f as Fighter).kill(null)
	end_bout(losers)


func end_bout(losers: Array[int]) -> void:
	phase = Phase.ROUND_END
	phase_time = NEXT_DELAY
	frozen = true
	time_left = 0.0
	# Stop lingering DoT zones / projectiles / summons of the finished bout so they cannot kill the winner.
	_clear_field()
	for t in 2:
		var f: Variant = current[t]
		if losers.has(t):
			if f != null and is_instance_valid(f):
				_corpses.append({"f": f, "t": CORPSE_TIME})
			current[t] = null
		elif f != null and is_instance_valid(f):
			var w := f as Fighter
			w.cleanse()
			w.heal(w.max_hp * WIN_HEAL, null)
			wins[t] += 1
			send_announce("%s 守擂成功 holds the stage" % w.display_name, 2.0)
	if losers.size() == 2:
		send_announce("同归于尽 Both fighters fall", 2.0)
	update_score()


func on_round_end_done() -> void:
	var out: Array[int] = []
	for t in 2:
		# A winner that still died during the pause (DoT ticking at the bell) counts as eliminated.
		var f: Variant = current[t]
		if f != null and (not is_instance_valid(f) or not (f as Fighter).is_alive()):
			if is_instance_valid(f):
				_corpses.append({"f": f, "t": CORPSE_TIME})
			current[t] = null
		if current[t] == null and not send_next(t):
			out.append(t)
	if not out.is_empty():
		var winner := -1
		if out.size() == 1:
			winner = 1 - out[0]
		finish(winner)
		return
	start_bout()


func finish(winner: int) -> void:
	phase = Phase.DONE
	frozen = true
	time_left = 0.0
	update_score()
	if winner >= 0:
		send_announce("%s 获胜 Victory!" % TEAM_NAMES[winner], 3.0)
	else:
		send_announce("平局 Draw", 3.0)
	end_match({"winner_team": winner, "mvp_uid": compute_mvp(winner if winner >= 0 else -2)})


func update_score() -> void:
	var cur: Array = []
	for t in 2:
		var f: Variant = current[t]
		cur.append((f as Fighter).uid if f != null and is_instance_valid(f) else 0)
	score = {
		"mode": "arena",
		"phase": phase_name(),
		"bout": bout,
		"round": bout,
		"wins": [wins[0], wins[1]],
		"remaining": [remaining(0), remaining(1)],
		"current": cur,
	}
	send_score()
