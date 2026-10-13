class_name Match
extends Node
## Base class for all match modes (duel / arena / team owned by NET, raid owned by RAID).
## Lives in scenes/match.tscn next to the World and the map. The host runs the rules; clients only
## receive announce/timer/score updates through the RPCs below (the HUD listens to the signals,
## which fire on every peer).

signal announce(text: String, seconds: float)
signal timer_changed(seconds_left: float)
signal score_changed(score: Dictionary)
## result: {winner_team: int (-1 draw / raid fail), mode: String, mvp_uid: int, clear_time: float,
##          stats: {uid(int): {name, class_id, team, kills, deaths, damage, healing}}, score: Dictionary}
signal match_ended(result: Dictionary)

var world: World
var map: MapBase
var settings: Dictionary = {}
## Roster slots from Game.roster: {slot, team, peer (0 = bot), name, class_id, ready}.
var roster: Array = []
var score: Dictionary = {}
var time_left: float = 0.0
var running: bool = false
var ended: bool = false
## Fighters spawned from roster slots: slot index -> Fighter.
var slot_fighters: Dictionary = {}
## Persistent per-uid stats snapshot (fighters may be freed between rounds).
var stats: Dictionary = {}

var _timer_accum: float = 0.0


func setup(p_world: World, p_map: MapBase, p_settings: Dictionary, p_roster: Array) -> void:
	world = p_world
	map = p_map
	settings = p_settings
	roster = p_roster
	if world and not world.fighter_died.is_connected(_on_world_fighter_died):
		world.fighter_died.connect(_on_world_fighter_died)


func is_host() -> bool:
	return multiplayer.is_server()


## Host: called once every peer has loaded the match scene. Subclasses spawn and start rounds.
func begin() -> void:
	running = true


func _physics_process(delta: float) -> void:
	if not running or ended or not is_host():
		return
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		_timer_accum += delta
		if _timer_accum >= 0.25 or time_left <= 0.0:
			_timer_accum = 0.0
			_rpc_timer.rpc(time_left)
		if time_left <= 0.0:
			_on_time_up()
	host_tick(delta)


## Host per-frame rules hook for subclasses.
func host_tick(_delta: float) -> void:
	pass


func _on_time_up() -> void:
	pass


# -- spawning helpers (host) --------------------------------------------------------------------

## Spawns the fighter for a roster slot. Bots (peer == 0) get a BotBrain in `brain_mode`.
func spawn_slot(slot: Dictionary, pos: Vector3, yaw: float = 0.0, brain_mode: String = "pvp") -> Fighter:
	var peer: int = int(slot.get("peer", 0))
	var data := World.make_spawn_data({
		"uid": world.next_uid(),
		"kind": "player" if peer != 0 else "bot",
		"peer": peer,
		"class_id": str(slot.get("class_id", "")),
		"team": int(slot.get("team", 0)),
		"name": str(slot.get("name", "Bot")),
		"pos": pos,
		"yaw": yaw,
	})
	var f := world.spawn_fighter(data)
	if f == null:
		return null
	if peer == 0:
		world.attach_brain(f, brain_mode)
	slot_fighters[int(slot.get("slot", slot_fighters.size()))] = f
	_track(f)
	return f


func _track(f: Fighter) -> void:
	if not stats.has(f.uid):
		stats[f.uid] = {"name": f.display_name, "class_id": f.class_id, "team": f.team, "kind": f.kind,
			"kills": 0, "deaths": 0, "damage": 0.0, "healing": 0.0}


## Refresh the stats snapshot from live fighters (call before ending / on scoreboard requests).
func snapshot_stats() -> void:
	if world == null:
		return
	for f: Fighter in world.fighters:
		if not is_instance_valid(f) or f.kind == "summon":
			continue
		_track(f)
		var s: Dictionary = stats[f.uid]
		s["kills"] = f.kills
		s["deaths"] = f.deaths
		s["damage"] = f.damage_dealt
		s["healing"] = f.healing_done


func _on_world_fighter_died(f: Fighter, killer: Fighter) -> void:
	if is_host() and running and not ended:
		on_fighter_died(f, killer)


## Host hook for subclasses.
func on_fighter_died(_f: Fighter, _killer: Fighter) -> void:
	pass


func compute_mvp(team: int = -2) -> int:
	snapshot_stats()
	var best := -1
	var best_score := -INF
	for uid: int in stats:
		var s: Dictionary = stats[uid]
		if team != -2 and int(s["team"]) != team:
			continue
		if s.get("kind", "") in ["mob", "boss", "summon"]:
			continue
		var v: float = float(s["damage"]) + float(s["healing"]) * 1.2 + int(s["kills"]) * 800.0 - int(s["deaths"]) * 400.0
		if v > best_score:
			best_score = v
			best = uid
	return best


# -- host -> all broadcasts ---------------------------------------------------------------------

func send_announce(text: String, seconds: float = 2.0) -> void:
	if is_host():
		_rpc_announce.rpc(text, seconds)


func send_score() -> void:
	if is_host():
		_rpc_score.rpc(score)


func end_match(result: Dictionary) -> void:
	if not is_host() or ended:
		return
	snapshot_stats()
	result["mode"] = str(settings.get("mode", ""))
	result["score"] = score
	result["stats"] = stats
	if not result.has("mvp_uid"):
		result["mvp_uid"] = compute_mvp()
	if not result.has("clear_time"):
		result["clear_time"] = 0.0
	_rpc_end.rpc(result)


@rpc("authority", "call_local", "reliable")
func _rpc_announce(text: String, seconds: float) -> void:
	announce.emit(text, seconds)


@rpc("authority", "call_local", "unreliable_ordered")
func _rpc_timer(t: float) -> void:
	time_left = t
	timer_changed.emit(t)


@rpc("authority", "call_local", "reliable")
func _rpc_score(s: Dictionary) -> void:
	score = s
	score_changed.emit(s)


@rpc("authority", "call_local", "reliable")
func _rpc_end(result: Dictionary) -> void:
	ended = true
	running = false
	match_ended.emit(result)
