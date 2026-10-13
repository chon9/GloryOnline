extends Match
## PvP rounds (owner: NET): "duel" 个人赛 (1v1) and "team" 团体赛 (up to 5v5).
## Best of (2 * rounds_to_win - 1) rounds; a round ends when one team is wiped, or on timeout (higher total
## hp% wins). Between rounds every fighter is reset at its spawn point and a 3-2-1 countdown runs with all
## fighters frozen (match-level input lock: this node runs its physics step BEFORE World and wipes every
## fighter's FighterInput while frozen, so humans and bots alike cannot move or cast).
## modes/match_arena.gd extends this script.

## Fires on every peer when a non-summon fighter dies (killer_uid 0 = none; summon kills credit the owner).
signal kill_event(victim_uid: int, killer_uid: int)

enum Phase { IDLE, COUNTDOWN, FIGHT, ROUND_END, DONE }

const COUNTDOWN_TIME: float = 3.0
const ROUND_END_TIME: float = 3.0
const TEAM_NAMES: Array[String] = ["蓝队 Blue Team", "红队 Red Team"]
const STATS_SYNC_INTERVAL: float = 1.0

var phase: int = Phase.IDLE
var phase_time: float = 0.0
var round_no: int = 0
var wins: Array[int] = [0, 0]
var frozen: bool = false
var _last_count: int = -1
var _stats_accum: float = 0.0


func _init() -> void:
	name = "Mode"
	process_physics_priority = -10


func rounds_to_win() -> int:
	return clampi(int(settings.get("rounds_to_win", 2)), 1, 5)


func round_time() -> float:
	return maxf(10.0, float(settings.get("round_time", 180)))


func max_rounds() -> int:
	return rounds_to_win() * 2 + 1


# ================================================================== start
func begin() -> void:
	if not is_host() or running:
		return
	super.begin()
	spawn_all()
	start_round()


func spawn_all() -> void:
	for t in 2:
		var idx := 0
		for slot: Dictionary in roster:
			if int(slot.get("team", 0)) != t:
				continue
			spawn_slot(slot, spawn_pos(t, idx), spawn_yaw(t), "pvp")
			idx += 1


func spawn_pos(team: int, idx: int) -> Vector3:
	var pts: Array[Vector3] = map.get_spawn_points(team) if map != null else []
	if pts.is_empty():
		return Vector3((idx - 2) * 2.0, 0.5, -12.0 if team == 0 else 12.0)
	var p: Vector3 = pts[idx % pts.size()]
	if idx >= pts.size():
		p += Vector3(0.0, 0.0, 1.5 * floorf(float(idx) / float(pts.size())) * (-1.0 if team == 0 else 1.0))
	return p


func spawn_yaw(team: int) -> float:
	return map.get_spawn_yaw(team) if map != null else (PI if team == 0 else 0.0)


func start_round() -> void:
	round_no += 1
	_clear_field()
	for slot_id: Variant in slot_fighters:
		var f: Fighter = slot_fighters[slot_id]
		if not is_instance_valid(f):
			continue
		var idx := _team_index(f)
		place_fighter(f, spawn_pos(f.team, idx), spawn_yaw(f.team), true)
	send_announce("第%d回合 Round %d" % [round_no, round_no], 1.5)
	start_countdown()


## Removes summons, projectiles and zones left from the previous round/bout.
func _clear_field() -> void:
	world.clear_effects()
	for f: Fighter in world.fighters.duplicate():
		if is_instance_valid(f) and f.kind == "summon" and f is Summon:
			(f as Summon).expire()


func _team_index(f: Fighter) -> int:
	var idx := 0
	for slot: Dictionary in roster:
		if int(slot.get("team", 0)) != f.team:
			continue
		if slot_fighters.get(int(slot.get("slot", -1))) == f:
			return idx
		idx += 1
	return 0


## Moves a fighter to its spawn point (full reset when `full_reset`).
func place_fighter(f: Fighter, pos: Vector3, yaw: float, full_reset: bool) -> void:
	if full_reset:
		f.reset_for_round(pos)
	else:
		f.interrupt_cast()
		f.velocity = Vector3.ZERO
		f.global_position = pos
	f.facing_yaw = yaw
	f.rotation.y = yaw
	f.target_uid = 0


func start_countdown() -> void:
	phase = Phase.COUNTDOWN
	phase_time = COUNTDOWN_TIME
	frozen = true
	time_left = 0.0
	_last_count = -1
	_rpc_timer.rpc(round_time())
	update_score()


# ================================================================== tick
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Keep everyone frozen on the results screen too (base stops calling host_tick once ended).
	if ended and is_host() and frozen:
		freeze_inputs()


func host_tick(delta: float) -> void:
	if frozen:
		freeze_inputs()
	_stats_accum += delta
	if _stats_accum >= STATS_SYNC_INTERVAL:
		_stats_accum = 0.0
		sync_stats()
	phase_time -= delta
	match phase:
		Phase.COUNTDOWN:
			var n := ceili(phase_time)
			if n != _last_count and n > 0:
				_last_count = n
				send_announce(str(n), 0.9)
			if phase_time <= 0.0:
				phase = Phase.FIGHT
				frozen = false
				time_left = round_time()
				send_announce("开始 Fight!", 1.0)
				update_score()
		Phase.FIGHT:
			check_fight()
		Phase.ROUND_END:
			if phase_time <= 0.0:
				on_round_end_done()


## Wipes every fighter's input so nobody can move/cast (runs before World.step each physics frame).
func freeze_inputs() -> void:
	for f: Fighter in world.fighters:
		if is_instance_valid(f):
			f.input.move = Vector3.ZERO
			f.input.pressed = 0
			f.input.held = 0
			f.input.jump = false


func check_fight() -> void:
	var a := world.team_alive(0)
	var b := world.team_alive(1)
	if a > 0 and b > 0:
		return
	var winner := -1
	if a > 0:
		winner = 0
	elif b > 0:
		winner = 1
	end_round(winner)


func team_hp_frac(team: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for f: Fighter in world.team_fighters(team):
		mx += f.max_hp
		hp += maxf(0.0, f.hp) if f.is_alive() else 0.0
	return hp / mx if mx > 0.0 else 0.0


func _on_time_up() -> void:
	if phase != Phase.FIGHT:
		return
	var h0 := team_hp_frac(0)
	var h1 := team_hp_frac(1)
	send_announce("时间到 Time up!", 1.5)
	if absf(h0 - h1) < 0.0001:
		end_round(-1)
	else:
		end_round(0 if h0 > h1 else 1)


func end_round(winner: int) -> void:
	phase = Phase.ROUND_END
	phase_time = ROUND_END_TIME
	frozen = true
	time_left = 0.0
	if winner >= 0:
		wins[winner] += 1
		send_announce("%s 赢得本回合 wins the round" % team_label(winner), 2.5)
	else:
		send_announce("平局 Draw", 2.5)
	update_score()


func on_round_end_done() -> void:
	var leader := -1
	for t in 2:
		if wins[t] >= rounds_to_win():
			leader = t
	if leader >= 0 or round_no >= max_rounds():
		if leader < 0:
			leader = 0 if wins[0] > wins[1] else (1 if wins[1] > wins[0] else -1)
		finish(leader)
	else:
		start_round()


func finish(winner: int) -> void:
	phase = Phase.DONE
	frozen = true
	time_left = 0.0
	update_score()
	if winner >= 0:
		send_announce("%s 获胜 Victory!" % team_label(winner), 3.0)
	else:
		send_announce("平局 Draw", 3.0)
	end_match({"winner_team": winner, "mvp_uid": compute_mvp(winner if winner >= 0 else -2)})


## Team label; in 1v1 duels the fighter's name.
func team_label(team: int) -> String:
	var fs := world.team_fighters(team)
	if fs.size() == 1 and str(settings.get("mode", "")) == "duel":
		return fs[0].display_name
	return TEAM_NAMES[team] if team >= 0 and team < TEAM_NAMES.size() else "Team %d" % team


func phase_name() -> String:
	return ["idle", "countdown", "fight", "round_end", "done"][phase]


func update_score() -> void:
	score = {
		"mode": str(settings.get("mode", "")),
		"phase": phase_name(),
		"round": round_no,
		"wins": [wins[0], wins[1]],
		"rounds_to_win": rounds_to_win(),
	}
	send_score()


# ================================================================== stats / kill feed for clients
## Host: mirror Match.stats (kills/deaths/damage/healing are host-only counters) to clients.
func sync_stats() -> void:
	if not is_host():
		return
	snapshot_stats()
	if multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_rpc_stats.rpc(stats)


@rpc("authority", "call_remote", "reliable")
func _rpc_stats(s: Dictionary) -> void:
	stats = s


func on_fighter_died(f: Fighter, killer: Fighter) -> void:
	if f == null or f.kind == "summon":
		return
	var k := killer
	if k != null and is_instance_valid(k) and k.kind == "summon":
		k = k.get_owner_fighter()
	_rpc_kill.rpc(f.uid, k.uid if k != null and is_instance_valid(k) else 0)
	sync_stats()


@rpc("authority", "call_local", "reliable")
func _rpc_kill(victim_uid: int, killer_uid: int) -> void:
	kill_event.emit(victim_uid, killer_uid)
