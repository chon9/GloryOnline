extends "res://tests/test_ai_base.gd"
## Full raid runs with REAL kits and the AI module's BotBrain (MatchRaid brain_policy "auto": party bots in mode
## "raid", trash in mode "mob", bosses on RAID's BossBrain). Deterministic stepping (World.auto_step = false,
## MatchRaid.auto_tick = false). Reports clear time and wipes per encounter (boss wipes included).
## Checks: the party walks to MatchRaid's raid_goal and pulls encounter 1, idle (unpulled) mobs are never hit,
## trash is cleared, and every run progresses past the trash. A full clear is reported (and checked when
## AI_RAID_STRICT is set).
## Env: AI_RAID_IDS (comma separated raid ids, default all), AI_RAID_CAP (sim seconds per raid, default 900),
## AI_RAID_PARTY (comma separated 5 class ids), AI_RAID_DIFF (0..3, default 2).

const RECORDS: String = "user://test_ai_raid_records.json"
const DEFAULT_PARTY: Array[String] = ["knight", "cleric", "elementalist", "blade_master", "sharpshooter"]

var map: MapBase = null
var match_node: MatchRaid = null


func run_tests() -> void:
	suite_name = "raid"
	Combat.deterministic = false
	Combat.seed_rng(31337)
	var ids: Array[String] = []
	var env_ids := OS.get_environment("AI_RAID_IDS")
	if env_ids != "":
		for s: String in env_ids.split(",", false):
			ids.append(s.strip_edges())
	else:
		for id: Variant in RaidRegistry.ids():
			ids.append(str(id))
	var cap := float(OS.get_environment("AI_RAID_CAP")) if OS.get_environment("AI_RAID_CAP") != "" else 900.0
	var diff := int(OS.get_environment("AI_RAID_DIFF")) if OS.get_environment("AI_RAID_DIFF") != "" else 2
	var party: Array[String] = []
	var env_party := OS.get_environment("AI_RAID_PARTY")
	if env_party != "":
		for s: String in env_party.split(",", false):
			party.append(s.strip_edges())
	else:
		party = DEFAULT_PARTY.duplicate()
	var real_ok := true
	for id: String in party:
		if not bool(reg.call("has_kit", id)):
			real_ok = false
	if not real_ok:
		print("SKIP: real kits missing, party %s" % str(party))
		return
	for rid: String in ids:
		await _run_raid(rid, party, cap, diff)
	_teardown()
	DungeonBase.clear_cache()
	if FileAccess.file_exists(RECORDS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))


func _new_raid(raid_id: String, party: Array[String]) -> void:
	_teardown()
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	map = RaidRegistry.create(raid_id)
	root.add_child(map)
	map.build()
	match_node = MatchRaid.new()
	match_node.name = "MatchRaid"
	match_node.brain_policy = "auto"
	match_node.auto_tick = false
	match_node.records_path = RECORDS
	root.add_child(match_node)
	var roster: Array = []
	for i in party.size():
		roster.append({"slot": i, "team": 0, "peer": 0, "name": "Bot%d" % i, "class_id": party[i], "ready": true})
	match_node.setup(world, map, {"mode": "raid", "raid_id": raid_id}, roster)
	await physics_frame
	await physics_frame
	match_node.begin()


func _teardown() -> void:
	for n: Node in [match_node, map, world]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	match_node = null
	map = null
	world = null


func _run_raid(raid_id: String, party: Array[String], cap: float, diff: int) -> void:
	BotBrain.difficulty_override = diff
	await _new_raid(raid_id, party)
	BotBrain.difficulty_override = -1
	var n_enc := match_node.encounters.size()
	var wipes_at: Array[int] = []
	wipes_at.resize(n_enc)
	var clear_at: Array[float] = []
	clear_at.resize(n_enc)
	clear_at.fill(-1.0)
	var boss_hp_at_wipe: Array[String] = []
	var ev_counts: Dictionary = {}
	var count_events := func() -> void:
		var bb := match_node.boss_brain
		if bb != null and is_instance_valid(bb):
			for ev: String in bb.log_events:
				var k := ev.split(":")[0] + (":" + ev.split(":")[1] if ev.contains(":") and not ev.begins_with("ability") else "")
				ev_counts[k] = int(ev_counts.get(k, 0)) + 1
	match_node.raid_wiped.connect(func(_c: int) -> void:
		if match_node.current < n_enc:
			wipes_at[match_node.current] += 1
		var b := match_node.boss
		if b != null and is_instance_valid(b):
			boss_hp_at_wipe.append("%.0f%%" % (b.hp / b.max_hp * 100.0))
			count_events.call())
	match_node.encounter_cleared.connect(func(i: int) -> void: clear_at[i] = match_node.clear_time)
	var dbg := OS.get_environment("AI_RAID_DEBUG") != ""
	var deaths: Dictionary = {}
	world.fighter_died.connect(func(f: Fighter, killer: Fighter) -> void:
		if f.team != 0:
			return
		var why := "?"
		if killer != null and is_instance_valid(killer):
			why = killer.mob_id if killer.mob_id != "" else killer.class_id
			if killer.runner != null and killer.runner.skill != null:
				why += "/" + str(killer.runner.skill.id)
		var key := "%s<-%s" % [f.class_id, why]
		deaths[key] = int(deaths.get(key, 0)) + 1
		if dbg:
			var b := match_node.boss
			print("    death t=%.1f %s by %s boss=%s" % [match_node.clear_time, f.class_id, why,
				("%.0f%%" % (b.hp / b.max_hp * 100.0)) if b != null and is_instance_valid(b) else "-"]))
	var casts: Dictionary = {}
	for f: Fighter in match_node.party():
		f.skill_cast.connect(func(ff: Fighter, slot: int) -> void:
			var arr: PackedInt32Array = casts.get(ff.class_id, PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0]))
			if slot >= 0 and slot < 8:
				arr[slot] += 1
			casts[ff.class_id] = arr)
	var started_0 := -1.0
	var idle_hit := false
	var bot_brains := 0
	for f: Fighter in match_node.party():
		if f.brain is BotBrain:
			bot_brains += 1
	await physics_frame
	var steps := roundi(cap / DT)
	for i in steps:
		match_node.host_tick(DT)
		world.step(DT)
		if started_0 < 0.0 and match_node.enc_state.size() > 0 and match_node.enc_state[0] != "idle":
			started_0 = match_node.clear_time
		# Mobs of a not-yet-activated encounter must stay untouched.
		if i % 30 == 0:
			for k in n_enc:
				if k < match_node.enc_state.size() and match_node.enc_state[k] == "idle":
					for m: Variant in match_node.enc_mobs.get(k, []):
						if is_instance_valid(m) and (m as Fighter).brain == null and (m as Fighter).hp < (m as Fighter).max_hp - 1.0:
							idle_hit = true
		if dbg and i % 60 == 0 and match_node.boss != null and is_instance_valid(match_node.boss) and match_node.boss_brain != null:
			var bo := match_node.boss
			var tg := world.get_fighter(bo.target_uid)
			var row := "    t=%.0f boss %.0f%% tgt=%s top=%s |" % [match_node.clear_time, bo.hp / bo.max_hp * 100.0,
				tg.class_id if tg != null else "-", bo.top_threat().class_id if bo.top_threat() != null else "-"]
			for f: Fighter in match_node.party():
				var to := CoreUtil.flat(f.global_position - bo.global_position)
				var front := to.normalized().dot(bo.forward()) if to.length() > 0.1 else 0.0
				row += " %s %.0f%% m%.0f d%.1f f%.1f %s|" % [f.class_id.substr(0, 5), f.hp / f.max_hp * 100.0, f.mp / maxf(1.0, f.max_mp) * 100.0, to.length(), front, f.state_name()]
			print(row)
		if match_node.ended or match_node.victory:
			break
	if not match_node.victory:
		count_events.call()
	var line := ""
	var trash_cleared := 0
	for k in n_enc:
		var e: Dictionary = match_node.encounters[k]
		var boss := bool(e.get("boss", false))
		if clear_at[k] >= 0.0 and not boss:
			trash_cleared += 1
		line += "  [%d %s%s] cleared=%s wipes=%d\n" % [k, str(e.get("name_en", "")), " BOSS" if boss else "",
			("%.0fs" % clear_at[k]) if clear_at[k] >= 0.0 else "no", wipes_at[k]]
	print("RAID %s party=%s diff=%d: victory=%s time=%.0fs wipes=%d\n%s" % [raid_id, ",".join(party), diff,
		str(match_node.victory), match_node.clear_time, match_node.wipes, line])
	var cl := ""
	var heal_s := ""
	for f: Fighter in match_node.party():
		cl += " %s%s" % [f.class_id, str(casts.get(f.class_id, []))]
		heal_s += " %s:%.0f" % [f.class_id, f.healing_done]
	print("  casts per slot:%s
  healing done:%s" % [cl, heal_s])
	print("  boss hp at wipes: %s
  boss events: %s
  party deaths: %s" % [", ".join(boss_hp_at_wipe), str(ev_counts), str(deaths)])
	check(bot_brains == party.size(), "%s: party bots run BotBrain (mode raid)" % raid_id, "%d/%d" % [bot_brains, party.size()])
	check(started_0 >= 0.0 and started_0 < 60.0, "%s: bots walk to raid_goal and pull encounter 1" % raid_id, "t=%.1f" % started_0)
	check(not idle_hit, "%s: idle (unpulled) mobs are never attacked" % raid_id)
	check(trash_cleared >= 1, "%s: party clears trash with real kits" % raid_id, "%d trash cleared" % trash_cleared)
	if OS.get_environment("AI_RAID_STRICT") != "":
		check(match_node.victory, "%s: full clear" % raid_id, "wipes %d" % match_node.wipes)
