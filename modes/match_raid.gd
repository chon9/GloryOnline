class_name MatchRaid
extends Match
## PvE raid mode (副本, owner: RAID). Up to 5 party members (humans + bots in brain mode "raid") on team 0
## fight through a DungeonBase map: trash encounters, then a boss driven by BossBrain. Host-authoritative.
## - Encounters spawn one at a time (idle, no brain) and activate when a living party member enters the
##   encounter radius or a mob gets hit. Mob/boss hp scales with the party size on team 0 (min 25%).
## - Wipe (every party member dead) -> 5 s -> everyone respawns at the last checkpoint, encounter reset.
## - Clearing an encounter revives dead party members (out of combat); out of combat the party regenerates.
## - Victory (boss dead) -> end_match with clear_time (速通); best clear time per raid saved in user://records.json.

signal encounter_started(index: int)
signal encounter_cleared(index: int)
signal raid_wiped(count: int)
signal raid_cleared(clear_time: float)

const WIPE_DELAY: float = 5.0
const RECORDS_PATH: String = "user://records.json"
const OOC_REGEN: float = 0.08          # fraction of max hp / mp per second out of combat
const CORPSE_TIME: float = 4.0
const MOB_TEAM: int = 1
const PARTY_SIZE: int = 5
## Trash / add brains run at this fixed bot difficulty, so encounter difficulty does not change with the
## party bots' difficulty setting (Game.settings.bot_difficulty only tunes the party bots).
const MOB_DIFFICULTY: int = 2
## Raid supplies (副本补给, Glory dungeons are run with potions): party members regenerate mana this much
## faster (additive stat_bonus["mp_regen"], own share kept in fighter meta "raid_mp_regen"), so 3-4 minute
## boss fights are not decided by PvP-tuned mana pools running dry.
const RAID_MP_REGEN_BONUS: float = 1.0

var records_path: String = RECORDS_PATH
var raid_id: String = ""
## "auto": AI module's BotBrain through World.attach_brain (RAID fallback brain when it is missing);
## "internal": always the RAID fallback brain (deterministic tests).
var brain_policy: String = "auto"
## false: the owner calls host_tick() manually (deterministic tests with World.auto_step = false).
var auto_tick: bool = true
var encounters: Array[Dictionary] = []
var enc_state: Array[String] = []      # pending | idle | active | cleared
var enc_mobs: Dictionary = {}          # encounter index -> Array[Fighter]
var current: int = 0
var last_cleared: int = -1
var clear_time: float = 0.0
var wipes: int = 0
var wipe_timer: float = -1.0
var boss: Fighter = null
var boss_brain: BossBrain = null
var party_scale: float = 1.0
var best_time: float = 0.0
var victory: bool = false

var _net_t: float = 0.0
var _score_t: float = 0.0
var _corpses: Array[Dictionary] = []   # {f, t}


func _init() -> void:
	process_physics_priority = -10   # Mode nodes tick before World (DEVIATIONS / NET)


func setup(p_world: World, p_map: MapBase, p_settings: Dictionary, p_roster: Array) -> void:
	super.setup(p_world, p_map, p_settings, p_roster)
	raid_id = str(settings.get("raid_id", ""))
	if is_inside_tree() and not is_host() and not match_ended.is_connected(_on_client_ended):
		match_ended.connect(_on_client_ended)
	if map == null and raid_id != "":
		map = RaidRegistry.create(raid_id)
		if map != null:
			var parent: Node = world.get_parent() if world != null and world.get_parent() != null else self
			parent.add_child(map)
	if map is DungeonBase and not (map as DungeonBase).built:
		map.build()
	if raid_id == "" and map != null:
		raid_id = map.map_id
	if map != null:
		encounters = map.get_encounters()


## Replaces the base countdown: the raid timer counts UP (clear time) and is broadcast via _rpc_timer.
func _physics_process(delta: float) -> void:
	if not auto_tick or not running or ended or not is_host():
		return
	host_tick(delta)


# ================================================================== start
func begin() -> void:
	super.begin()
	if not is_host() or world == null or map == null:
		return
	map.apply_to_world(world)
	encounters = map.get_encounters()
	enc_state.clear()
	for e: Dictionary in encounters:
		enc_state.append("pending")
	current = 0
	last_cleared = -1
	clear_time = 0.0
	best_time = load_best(raid_id)
	var pts := map.get_spawn_points(0)
	var yaw := map.get_spawn_yaw(0)
	for i in roster.size():
		var slot: Dictionary = roster[i]
		_spawn_member(slot, pts[i % pts.size()], yaw)
	if not encounters.is_empty():
		_spawn_encounter(0)
	send_announce("%s %s：准备出发！ Raid start!" % [map.name_cn, map.name_en], 3.0)
	_send_score()


func _spawn_member(slot: Dictionary, pos: Vector3, yaw: float) -> Fighter:
	var peer: int = int(slot.get("peer", 0))
	var data := World.make_spawn_data({
		"uid": world.next_uid(),
		"kind": "player" if peer != 0 else "bot",
		"peer": peer,
		"class_id": str(slot.get("class_id", "")),
		"team": 0,
		"name": str(slot.get("name", "Bot")),
		"pos": pos,
		"yaw": yaw,
	})
	var f := world.spawn_fighter(data)
	if f == null:
		return null
	if not f.has_meta("raid_mp_regen"):
		f.stat_bonus["mp_regen"] = float(f.stat_bonus.get("mp_regen", 0.0)) + RAID_MP_REGEN_BONUS
		f.set_meta("raid_mp_regen", RAID_MP_REGEN_BONUS)
	if peer == 0:
		RaidUtil.attach_brain(world, f, "raid", brain_policy)
	slot_fighters[int(slot.get("slot", slot_fighters.size()))] = f
	_track(f)
	return f


func party() -> Array[Fighter]:
	var out: Array[Fighter] = []
	if world == null:
		return out
	for f: Fighter in world.team_fighters(0):
		out.append(f)
	return out


func party_alive() -> int:
	var n := 0
	for f: Fighter in party():
		if f.is_alive():
			n += 1
	return n


# ================================================================== host loop
func host_tick(delta: float) -> void:
	if ended or not running or world == null:
		return
	clear_time += delta
	_net_t += delta
	if _net_t >= 0.25:
		_net_t = 0.0
		time_left = clear_time
		_rpc_timer.rpc(clear_time)
	_tick_corpses(delta)
	if wipe_timer >= 0.0:
		wipe_timer -= delta
		if wipe_timer <= 0.0:
			_reset_after_wipe()
		return
	var members := party()
	if not members.is_empty() and party_alive() == 0:
		_start_wipe()
		return
	if current >= encounters.size():
		return
	match enc_state[current]:
		"idle":
			var puller := _puller(current, members)
			if puller != null:
				_activate(current, puller)
		"active":
			if _encounter_dead(current):
				_clear(current)
	_update_goals(members)
	if current < enc_state.size() and enc_state[current] != "active":
		for f: Fighter in members:
			if f.is_alive():
				# Direct write (hp syncs ON_CHANGE): heal() would spawn a damage number every frame.
				f.hp = minf(f.max_hp, f.hp + f.max_hp * OOC_REGEN * delta)
				f.mp = minf(f.max_mp, f.mp + f.max_mp * OOC_REGEN * delta)
	_score_t += delta
	if _score_t >= 1.0:
		_score_t = 0.0
		_send_score()


## A living party member inside the encounter radius, or whoever hit one of its idle mobs.
func _puller(i: int, members: Array[Fighter]) -> Fighter:
	var e: Dictionary = encounters[i]
	var pos: Vector3 = e["pos"]
	var r := float(e.get("radius", 10.0))
	for f: Fighter in members:
		if f.is_alive() and CoreUtil.flat(f.global_position - pos).length() <= r:
			return f
	for m: Fighter in enc_mobs.get(i, []):
		if is_instance_valid(m) and (not m.threat.is_empty() or m.hp < m.max_hp):
			var t := m.top_threat()
			if t != null:
				return t
			for f: Fighter in members:
				if f.is_alive():
					return f
	return null


func _update_goals(members: Array[Fighter]) -> void:
	if current >= encounters.size():
		return
	var goal: Vector3 = encounters[current]["pos"]
	var idx := 0
	for f: Fighter in members:
		f.set_meta("raid_goal", goal + Vector3((idx - 2) * 1.5, 0, 3.0 + absf(idx - 2) * 0.8))
		idx += 1


# ================================================================== encounters
func _spawn_encounter(i: int) -> void:
	if i < 0 or i >= encounters.size():
		return
	var e: Dictionary = encounters[i]
	var mobs: Array = e.get("mobs", [])
	var pos: Vector3 = e["pos"]
	var spawns: Array = e.get("spawns", [])
	var list: Array[Fighter] = []
	var n := mobs.size()
	party_scale = _compute_scale()
	for k in n:
		var mob_id := str(mobs[k])
		var p := pos
		if k < spawns.size():
			p = spawns[k]
		elif k > 0:
			var ang := TAU * float(k - 1) / float(maxi(1, n - 1)) + 0.4
			p = pos + Vector3(cos(ang), 0, sin(ang)) * (3.6 if n > 3 else 2.8)
		p = world.ground_point(world.clamp_to_bounds(p)) + Vector3(0, 0.1, 0)
		var f := world.spawn_fighter({"kind": "boss" if bool(e.get("boss", false)) else "mob", "peer": 0,
			"mob_id": mob_id, "team": MOB_TEAM, "name": "", "pos": p, "yaw": PI})
		if f == null:
			continue
		_scale_hp(f, party_scale)
		_track(f)
		list.append(f)
		if f.kind == "boss":
			boss = f
	enc_mobs[i] = list
	enc_state[i] = "idle"
	_send_score()


func _compute_scale() -> float:
	var n := party().size()
	return clampf(float(n) / float(PARTY_SIZE), 0.25, 2.0)


func _scale_hp(f: Fighter, s: float) -> void:
	var base := float((f.mob_def.get("stats", {}) as Dictionary).get("hp", f.max_hp))
	var frac := f.hp / maxf(1.0, f.max_hp)
	f.max_hp = maxf(1.0, base * s)
	f.hp = f.max_hp * frac


func _activate(i: int, puller: Fighter) -> void:
	enc_state[i] = "active"
	var e: Dictionary = encounters[i]
	party_scale = _compute_scale()
	for f: Fighter in enc_mobs.get(i, []):
		if not is_instance_valid(f) or not f.is_alive():
			continue
		_scale_hp(f, party_scale)
		if f.kind == "boss":
			_attach_boss_brain(f, e["pos"])
		else:
			_attach_mob_brain(f)
		if puller != null:
			f.add_threat(puller, 1.0)
	send_announce("遭遇：%s %s" % [str(e.get("name_cn", "")), str(e.get("name_en", ""))], 2.5)
	encounter_started.emit(i)
	_send_score()


func _attach_boss_brain(f: Fighter, home: Vector3) -> void:
	if f.brain != null and is_instance_valid(f.brain):
		return
	var b := BossBrain.new()
	b.fighter = f
	b.match_ref = self
	b.home = home
	b.name = "Brain"
	f.brain = b
	f.add_child(b)
	boss_brain = b
	b.phase_changed.connect(func(_p: int) -> void: _send_score())
	b.enraged_now.connect(func() -> void: _send_score())


## Host: called by BossBrain to spawn phase adds into the current encounter.
func spawn_add(mob_id: String, pos: Vector3, _src: Fighter = null) -> Fighter:
	var f := world.spawn_fighter({"kind": "mob", "peer": 0, "mob_id": mob_id, "team": MOB_TEAM, "name": "",
		"pos": pos, "yaw": PI})
	if f == null:
		return null
	var add_hp := 1.0
	var add_dmg := 1.0
	if _src != null and is_instance_valid(_src) and _src.mob_def.get("boss") is Dictionary:
		add_hp = float((_src.mob_def["boss"] as Dictionary).get("add_hp", 1.0))
		add_dmg = float((_src.mob_def["boss"] as Dictionary).get("add_dmg", 1.0))
	_scale_hp(f, party_scale * add_hp)
	if not is_equal_approx(add_dmg, 1.0):
		f.stat_bonus["dmg_out"] = float(f.stat_bonus.get("dmg_out", 0.0)) + add_dmg - 1.0
	_track(f)
	_attach_mob_brain(f)
	var list: Array = enc_mobs.get(current, [])
	list.append(f)
	enc_mobs[current] = list
	return f


func _attach_mob_brain(f: Fighter) -> void:
	var b := RaidUtil.attach_brain(world, f, "mob", brain_policy)
	if b != null and b.has_method("set_difficulty"):
		b.call("set_difficulty", MOB_DIFFICULTY)


func _encounter_dead(i: int) -> bool:
	var e: Dictionary = encounters[i]
	for f: Variant in enc_mobs.get(i, []):
		if not is_instance_valid(f):
			continue
		var fi := f as Fighter
		if fi.is_alive():
			if bool(e.get("boss", false)) and fi.kind != "boss":
				continue  # boss fights end when the boss dies; adds are removed
			return false
	return true


func _clear(i: int) -> void:
	enc_state[i] = "cleared"
	last_cleared = i
	var e: Dictionary = encounters[i]
	# Leftover adds / summons of the cleared encounter die with it.
	if boss_brain != null and is_instance_valid(boss_brain):
		boss_brain.despawn_adds()
	for f: Variant in enc_mobs.get(i, []):
		if is_instance_valid(f) and (f as Fighter).is_alive():
			(f as Fighter).kill(null)
	for f: Fighter in world.team_fighters(MOB_TEAM, true):
		if f.kind == "summon" and f.is_alive() and f is Summon:
			(f as Summon).expire()
	for f: Variant in enc_mobs.get(i, []):
		if is_instance_valid(f):
			_corpses.append({"f": f, "t": CORPSE_TIME})
	world.clear_effects()
	# Out-of-combat revive (脱战复活) of fallen party members.
	for f: Fighter in party():
		if not f.is_alive():
			f.revive(0.5)
	encounter_cleared.emit(i)
	if bool(e.get("boss", false)):
		_victory()
		return
	send_announce("%s %s 已清除 cleared!  (%s)" % [str(e.get("name_cn", "")), str(e.get("name_en", "")), format_time(clear_time)], 2.5)
	current = i + 1
	if current < encounters.size():
		_spawn_encounter(current)
	_send_score()


func _tick_corpses(delta: float) -> void:
	var i := 0
	while i < _corpses.size():
		var c: Dictionary = _corpses[i]
		c["t"] = float(c["t"]) - delta
		if float(c["t"]) <= 0.0:
			_corpses.remove_at(i)
			var f: Variant = c["f"]
			if is_instance_valid(f) and not (f as Fighter).is_alive():
				_remove_fighter(f)
		else:
			i += 1


func _remove_fighter(f: Fighter) -> void:
	if f == null or not is_instance_valid(f):
		return
	var p := f.get_parent()
	if p != null:
		p.remove_child(f)
	f.queue_free()


# ================================================================== wipe / reset
func _start_wipe() -> void:
	wipes += 1
	wipe_timer = WIPE_DELAY
	send_announce("团灭！%d秒后从检查点重新挑战 Wipe! Retrying from the checkpoint in %d s" % [int(WIPE_DELAY), int(WIPE_DELAY)], WIPE_DELAY)
	raid_wiped.emit(wipes)
	_send_score()


func _reset_after_wipe() -> void:
	wipe_timer = -1.0
	world.clear_effects()
	if boss_brain != null and is_instance_valid(boss_brain):
		boss_brain.despawn_adds()
	boss_brain = null
	boss = null
	for f: Variant in enc_mobs.get(current, []):
		if is_instance_valid(f):
			_remove_fighter(f)
	for f: Fighter in world.team_fighters(MOB_TEAM, true):
		_remove_fighter(f)
	for f: Fighter in world.team_fighters(0, true):
		if f.kind == "summon":
			_remove_fighter(f)
	enc_mobs[current] = []
	var cp := map.get_checkpoint(last_cleared)
	var idx := 0
	for f: Fighter in party():
		if not f.is_alive():
			f.revive(1.0)
		var p := cp + Vector3((idx - 2) * 1.6, 0.3, absf(idx - 2) * 1.2)
		f.reset_for_round(world.ground_point(p) + Vector3(0, 0.1, 0))
		f.velocity = Vector3.ZERO
		f.facing_yaw = map.get_spawn_yaw(0)
		idx += 1
	_spawn_encounter(current)
	send_announce("重新挑战！ Try again!", 2.0)


# ================================================================== victory / records
## Client peers keep their own local speedrun record (the host saves its own in _victory).
func _on_client_ended(r: Dictionary) -> void:
	if int(r.get("winner_team", -1)) != 0:
		return
	var t := float(r.get("clear_time", 0.0))
	if t > 0.0:
		save_record(str(r.get("raid_id", raid_id)), t)


func _victory() -> void:
	victory = true
	var t := clear_time
	var prev := load_best(raid_id)
	var new_record := prev <= 0.0 or t < prev
	best_time = t if new_record else prev
	save_record(raid_id, t)
	raid_cleared.emit(t)
	send_announce("副本通关！用时 %s Raid cleared in %s%s" % [format_time(t), format_time(t),
		"  新纪录 New record!" if new_record else ""], 4.0)
	_send_score()
	end_match({"winner_team": 0, "clear_time": t, "raid_id": raid_id, "best_time": best_time,
		"new_record": new_record, "wipes": wipes})


func load_records() -> Dictionary:
	if not FileAccess.file_exists(records_path):
		return {}
	var f := FileAccess.open(records_path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


func load_best(id: String) -> float:
	var r := load_records()
	var best: Variant = r.get("raid_best", {})
	if best is Dictionary:
		return float((best as Dictionary).get(id, 0.0))
	return 0.0


## Saves `t` as the best clear time for raid `id` if it beats the stored one. Keeps other keys.
func save_record(id: String, t: float) -> bool:
	var r := load_records()
	var best: Dictionary = r.get("raid_best", {}) if r.get("raid_best") is Dictionary else {}
	var clears: Dictionary = r.get("raid_clears", {}) if r.get("raid_clears") is Dictionary else {}
	var prev := float(best.get(id, 0.0))
	var improved := prev <= 0.0 or t < prev
	if improved:
		best[id] = snappedf(t, 0.01)
	clears[id] = int(clears.get(id, 0)) + 1
	r["raid_best"] = best
	r["raid_clears"] = clears
	var f := FileAccess.open(records_path, FileAccess.WRITE)
	if f == null:
		push_warning("MatchRaid: cannot write " + records_path)
		return false
	f.store_string(JSON.stringify(r, "\t"))
	f.close()
	return improved


static func format_time(t: float) -> String:
	var cs := roundi(maxf(0.0, t) * 100.0)
	var m := floori(cs / 6000.0)
	var s := float(cs - m * 6000) / 100.0
	return "%d:%05.2f" % [m, s]


func _send_score() -> void:
	if not is_host():
		return
	var e: Dictionary = encounters[current] if current < encounters.size() else {}
	score = {
		"mode": "raid", "raid_id": raid_id, "encounter": current, "encounters": encounters.size(),
		"state": enc_state[current] if current < enc_state.size() else "done",
		"name_cn": str(e.get("name_cn", "")), "name_en": str(e.get("name_en", "")),
		"boss_uid": boss.uid if boss != null and is_instance_valid(boss) else 0,
		"phase": boss_brain.phase if boss_brain != null and is_instance_valid(boss_brain) else 0,
		"enraged": boss_brain.enraged if boss_brain != null and is_instance_valid(boss_brain) else false,
		"wipes": wipes, "clear_time": clear_time, "best_time": best_time,
	}
	send_score()


# ================================================================== debug helpers (sandbox / tests)
## Host: skips straight to encounter `i` (previous ones count as cleared), party teleported in front of it.
func debug_skip_to(i: int) -> void:
	if i < 0 or i >= encounters.size():
		return
	for f: Variant in enc_mobs.get(current, []):
		if is_instance_valid(f):
			_remove_fighter(f)
	enc_mobs[current] = []
	world.clear_effects()
	for k in i:
		enc_state[k] = "cleared"
	last_cleared = i - 1
	current = i
	var cp := map.get_checkpoint(last_cleared)
	var idx := 0
	for f: Fighter in party():
		if not f.is_alive():
			f.revive(1.0)
		f.reset_for_round(world.ground_point(cp + Vector3((idx - 2) * 1.6, 0.3, 0)) + Vector3(0, 0.1, 0))
		idx += 1
	_spawn_encounter(i)
