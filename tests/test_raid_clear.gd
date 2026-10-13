extends SceneTree
## RAID full-dungeon clear test (owner: RAID). Runs complete MatchRaid dungeons headless with a 5-bot party of
## REAL kits driven by the AI module's BotBrain (party mode "raid", trash mode "mob", bosses on BossBrain),
## deterministically (World.auto_step = false, fixed seeds, manual MatchRaid.host_tick).
##
##   godot --headless --path . -s res://tests/test_raid_clear.gd                 # both dungeons, tank+healer, diff 3
##   godot --headless --path . -s res://tests/test_raid_clear.gd -- --quick      # Frost Forest only
##   godot --headless --path . -s res://tests/test_raid_clear.gd -- --matrix     # balance table (diff 1/3, 2 comps)
## Options: --raid=frost_forest,boneyard  --seed=N (robustness runs)  --diff=3  --party=knight,cleric,...  --cap=1200 (sim s)  --verbose
##
## Per run it reports clear time, wipes per encounter, boss ability usage counts, soak / interrupt results, party
## deaths by source, and a stuck watchdog (no encounter progress, no enemy damage and no wipe for STUCK_TIME s).

const DT: float = 1.0 / 60.0
const RECORDS: String = "user://test_raid_clear_records.json"
const STUCK_TIME: float = 75.0
const COMP_HEALER: Array[String] = ["knight", "cleric", "elementalist", "blade_master", "sharpshooter"]
const COMP_NO_HEALER: Array[String] = ["knight", "berserker", "elementalist", "assassin", "launcher"]

var passed: int = 0
var failed: int = 0
var world: World = null
var map: MapBase = null
var match_node: MatchRaid = null
var reg: Node = null
var verbose: bool = false
var rows: Array[Dictionary] = []
var seed_offset: int = 0
var _abilities: Dictionary = {}
var _events: Dictionary = {}
var _seen_brain: Object = null
var _seen_n: int = 0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	reg = root.get_node_or_null("Registry")
	var args := _parse_args()
	verbose = args.has("verbose")
	seed_offset = int(args.get("seed", "0"))
	var cap := float(args.get("cap", "1200"))
	var raids: Array[String] = []
	for s: String in str(args.get("raid", "frost_forest,boneyard" if not args.has("quick") else "frost_forest")).split(",", false):
		raids.append(s.strip_edges())
	var party: Array[String] = COMP_HEALER.duplicate()
	if args.has("party"):
		party.clear()
		for s: String in str(args["party"]).split(",", false):
			party.append(s.strip_edges())
	var missing: Array[String] = []
	for id: String in COMP_HEALER + COMP_NO_HEALER + party:
		if reg == null or not bool(reg.call("has_kit", id)):
			missing.append(id)
	if not missing.is_empty():
		check(false, "real kits present", str(missing))
	elif args.has("matrix"):
		await _matrix(raids, cap)
	else:
		var diff := int(args.get("diff", "3"))
		for rid: String in raids:
			var r := await run_raid(rid, party, diff, cap)
			_check_clear(r, party.has("cleric") and diff >= 3)
	_print_table()
	rows.clear()
	_abilities = {}
	_events = {}
	_seen_brain = null
	_teardown()
	# Note: DungeonBase.clear_cache() is deliberately not called here; from this script it made the run end
	# with "ObjectDB instances leaked" / "resources still in use" lines (and an occasional exit segfault).
	if FileAccess.file_exists(RECORDS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	var fx := root.get_node_or_null("Fx")
	if fx != null and fx.has_method("shutdown"):
		fx.call("shutdown")
	await process_frame
	print("RAID TESTS [clear]: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var eq := s.find("=")
		if eq >= 0:
			out[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			out[s] = "1"
	return out


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label + ("" if detail == "" else "  (" + detail + ")"))
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


# ================================================================== matrix
func _matrix(raids: Array[String], cap: float) -> void:
	for rid: String in raids:
		var a3 := await run_raid(rid, COMP_HEALER, 3, cap)
		_check_clear(a3, true)
		var a1 := await run_raid(rid, COMP_HEALER, 1, cap)
		var b3 := await run_raid(rid, COMP_NO_HEALER, 3, cap)
		var b1 := await run_raid(rid, COMP_NO_HEALER, 1, cap)
		check(not bool(a1["stuck"]) and not bool(b3["stuck"]) and not bool(b1["stuck"]), "%s: no stuck states in any run" % rid)
		# Difficulty 1 is clearly worse than difficulty 3: more wipes, slower, or no clear.
		check(not bool(a1["victory"]) or int(a1["wipes"]) >= 1 or float(a1["time"]) > float(a3["time"]) * 1.15,
			"%s: diff-1 tank+healer party struggles (wipes or slower)" % rid,
			"d1 %s/%d wipes/%.0fs vs d3 %.0fs" % [str(a1["victory"]), int(a1["wipes"]), float(a1["time"]), float(a3["time"])])
		# No healer: struggles (wipes / fails) at both difficulties.
		check(not bool(b3["victory"]) or int(b3["wipes"]) > int(a3["wipes"]),
			"%s: no-healer comp struggles at diff 3" % rid, "victory %s wipes %d" % [str(b3["victory"]), int(b3["wipes"])])
		check(not bool(b1["victory"]) or int(b1["wipes"]) >= 2, "%s: no-healer comp struggles at diff 1" % rid,
			"victory %s wipes %d" % [str(b1["victory"]), int(b1["wipes"])])
		if rid == "boneyard":
			check(not bool(a1["victory"]) or int(a1["wipes"]) >= 1, "boneyard: diff-1 party wipes or fails the second boss",
				"victory %s wipes %d" % [str(a1["victory"]), int(a1["wipes"])])


## Checks for a run that is expected to clear (tank + healer at difficulty 3 when `strict`).
func _check_clear(r: Dictionary, strict: bool) -> void:
	var rid := str(r["raid"])
	check(not bool(r["stuck"]), "%s: no stuck state (bots progress, encounters trigger, no leash / respawn loop)" % rid,
		str(r["stuck_info"]))
	check(not bool(r["idle_hit"]), "%s: idle (unpulled) mobs are never attacked" % rid)
	check(int(r["trash_cleared"]) == int(r["encounters"]) - 1, "%s: every trash encounter cleared" % rid,
		"%d/%d" % [int(r["trash_cleared"]), int(r["encounters"]) - 1])
	check(int(r["max_wipes_one_enc"]) <= 4, "%s: no endless wipe loop on one encounter" % rid, str(r["wipes_at"]))
	if not strict:
		return
	check(bool(r["victory"]), "%s: tank+healer diff-3 party clears the dungeon" % rid, "wipes %d" % int(r["wipes"]))
	check(int(r["wipes"]) <= 1, "%s: 0-1 wipes" % rid, str(r["wipes"]))
	var t := float(r["time"])
	# Target ~6-12 min; a small margin absorbs drift from kit / AI changes.
	check(t >= 330.0 and t <= 780.0, "%s: clear time ~6-12 min simulated" % rid, "%.0f s" % t)
	var unused: Array = r["unused_abilities"]
	check(unused.is_empty(), "%s: boss used every ability" % rid, "unused %s, counts %s" % [str(unused), str(r["abilities"])])
	check(int(r["enrage"]) >= 1, "%s: boss reached red-blood enrage" % rid)


# ================================================================== one raid
func _new_raid(raid_id: String, party: Array[String], diff: int) -> void:
	_teardown()
	Combat.deterministic = false
	Combat.seed_rng(31337 + seed_offset)
	BotBrain.rng_seed = 4242 + seed_offset
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
	match_node.setup(world, map, {"mode": "raid", "raid_id": raid_id, "bot_difficulty": diff}, roster)
	await physics_frame
	await physics_frame
	BotBrain.difficulty_override = diff
	match_node.begin()
	BotBrain.difficulty_override = -1


func _teardown() -> void:
	for n: Node in [match_node, map, world]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	match_node = null
	map = null
	world = null


func run_raid(raid_id: String, party: Array[String], diff: int, cap: float) -> Dictionary:
	await _new_raid(raid_id, party, diff)
	var n_enc := match_node.encounters.size()
	var wipes_at: Array[int] = []
	wipes_at.resize(n_enc)
	var clear_at: Array[float] = []
	clear_at.resize(n_enc)
	clear_at.fill(-1.0)
	var start_at: Array[float] = []
	start_at.resize(n_enc)
	start_at.fill(-1.0)
	var boss_hp_wipe: Array[String] = []
	_abilities = {}
	_events = {}
	_seen_brain = null
	_seen_n = 0
	var abilities := _abilities
	var events := _events
	var deaths: Dictionary = {}
	var progress := {"t": 0.0}
	match_node.raid_wiped.connect(func(_c: int) -> void:
		_collect()
		progress["t"] = match_node.clear_time
		if match_node.current < n_enc:
			wipes_at[match_node.current] += 1
		var b := match_node.boss
		if b != null and is_instance_valid(b) and match_node.current == n_enc - 1:
			boss_hp_wipe.append("%.0f%%" % (b.hp / b.max_hp * 100.0)))
	match_node.encounter_cleared.connect(func(i: int) -> void:
		_collect()
		progress["t"] = match_node.clear_time
		clear_at[i] = match_node.clear_time)
	match_node.encounter_started.connect(func(i: int) -> void:
		progress["t"] = match_node.clear_time
		if start_at[i] < 0.0:
			start_at[i] = match_node.clear_time)
	world.fighter_died.connect(func(f: Fighter, killer: Fighter) -> void:
		if f.team != 0 or f.kind == "summon":
			return
		var why := "?"
		if killer != null and is_instance_valid(killer):
			why = killer.mob_id if killer.mob_id != "" else killer.class_id
			if killer.runner != null and killer.runner.skill != null:
				why += "/" + str(killer.runner.skill.id).get_slice(".", 1)
		why = f.class_id.substr(0, 5) + "<-" + why
		deaths[why] = int(deaths.get(why, 0)) + 1
		if verbose:
			print("    t=%.1f %s died <- %s" % [match_node.clear_time, f.class_id, why]))
	var dmg_by: Dictionary = {}
	for pf: Fighter in match_node.party():
		pf.damaged.connect(func(_f: Fighter, amount: float, src: Fighter) -> void:
			if match_node.current != n_enc - 1:
				return
			var k := "?"
			if src != null and is_instance_valid(src):
				k = src.mob_id if src.mob_id != "" else src.class_id
				if src.kind == "boss":
					var sk := "mech"
					if src.runner != null and src.runner.skill != null:
						sk = str(src.runner.skill.id).get_slice(".", 1)
					k = "boss/" + sk
			dmg_by[k] = int(dmg_by.get(k, 0)) + int(amount))
	var diffs: Array[int] = []
	for pf: Fighter in match_node.party():
		diffs.append(int(pf.brain.get("difficulty")) if pf.brain != null and "difficulty" in pf.brain else -1)
	check(diffs.count(diff) == diffs.size(), "%s: party bots run at difficulty %d" % [raid_id, diff], str(diffs))
	var idle_hit := false
	var stuck := false
	var stuck_info := ""
	var enemy_hp := -1.0
	var boss_t0 := -1.0
	var boss_state := ""
	await physics_frame
	var steps := roundi(cap / DT)
	for i in steps:
		match_node.host_tick(DT)
		world.step(DT)
		if match_node.ended or match_node.victory:
			break
		if i % 30 != 0:
			continue
		_collect()
		# Progress = enemies losing hp (any encounter), encounter state changes, wipes.
		var hp_sum := 0.0
		for f: Fighter in world.team_fighters(MatchRaid.MOB_TEAM, true):
			if f.is_alive():
				hp_sum += f.hp
		if enemy_hp < 0.0 or hp_sum < enemy_hp - 1.0:
			progress["t"] = match_node.clear_time
		enemy_hp = hp_sum
		for k in n_enc:
			if k < match_node.enc_state.size() and match_node.enc_state[k] == "idle":
				for m: Variant in match_node.enc_mobs.get(k, []):
					if is_instance_valid(m) and (m as Fighter).brain == null and (m as Fighter).hp < (m as Fighter).max_hp - 1.0:
						idle_hit = true
		if match_node.current == n_enc - 1:
			var st := match_node.enc_state[n_enc - 1]
			if st == "active" and boss_state != "active":
				boss_t0 = match_node.clear_time
			boss_state = st
		if match_node.clear_time - float(progress["t"]) > STUCK_TIME:
			stuck = true
			stuck_info = _stuck_report()
			print("  STUCK: " + stuck_info)
			break
		if verbose and i % 600 == 0:
			print("    t=%.0f enc=%d %s wipes=%d %s" % [match_node.clear_time, match_node.current,
				match_node.enc_state[mini(match_node.current, n_enc - 1)], match_node.wipes, _party_line()])
	_collect()
	var trash := 0
	var max_w := 0
	var enc_line := ""
	for k in n_enc:
		var e: Dictionary = match_node.encounters[k]
		if clear_at[k] >= 0.0 and not bool(e.get("boss", false)):
			trash += 1
		max_w = maxi(max_w, wipes_at[k])
		enc_line += "[%s %s w%d] " % [str(e.get("id", k)), ("%.0fs" % clear_at[k]) if clear_at[k] >= 0.0 else "-", wipes_at[k]]
	var boss_def: Dictionary = {}
	if match_node.encounters.size() > 0:
		var bid := str((match_node.encounters[n_enc - 1].get("mobs", [""]) as Array)[0])
		boss_def = (reg.call("get_mob_def", bid) as Dictionary).get("boss", {})
	var unused: Array[String] = []
	for id: Variant in boss_def.get("abilities", {}):
		if int(abilities.get(str(id), 0)) <= 0:
			unused.append(str(id))
	var r := {"raid": raid_id, "party": ",".join(party), "diff": diff, "victory": match_node.victory,
		"time": match_node.clear_time, "wipes": match_node.wipes, "wipes_at": wipes_at, "clear_at": clear_at,
		"encounters": n_enc, "trash_cleared": trash, "max_wipes_one_enc": max_w, "abilities": abilities,
		"events": events, "deaths": deaths, "boss_hp_wipe": boss_hp_wipe, "unused_abilities": unused,
		"stuck": stuck, "stuck_info": stuck_info, "idle_hit": idle_hit,
		"boss_time": (match_node.clear_time - boss_t0) if boss_t0 >= 0.0 else -1.0,
		"enrage": int(events.get("enrage", 0)), "healer": party.has("cleric"), "dmg_by": dmg_by}
	rows.append(r)
	print("RAID %s diff=%d party=%s: victory=%s time=%s wipes=%d\n  encounters: %s\n  boss fight (last attempt) %.0fs, boss hp at wipes: %s\n  abilities: %s\n  events: %s\n  party deaths: %s" % [
		raid_id, diff, ",".join(party), str(match_node.victory), MatchRaid.format_time(match_node.clear_time),
		match_node.wipes, enc_line, float(r["boss_time"]), ", ".join(PackedStringArray(boss_hp_wipe)), str(abilities), str(events), str(deaths)])
	print("  boss-room damage taken by source: %s\n  healing/damage per member: %s" % [str(dmg_by), _heal_line()])
	return r


func _collect() -> void:
	var bb := match_node.boss_brain
	if bb == null or not is_instance_valid(bb):
		return
	if _seen_brain != bb:
		_seen_brain = bb
		_seen_n = 0
	var evs: Array[String] = bb.log_events
	for k in range(_seen_n, evs.size()):
		var ev: String = evs[k]
		if ev.begins_with("ability:"):
			var id := ev.substr(8)
			_abilities[id] = int(_abilities.get(id, 0)) + 1
		else:
			_events[ev] = int(_events.get(ev, 0)) + 1
	_seen_n = evs.size()


func _heal_line() -> String:
	var s := ""
	for f: Fighter in match_node.party():
		s += "%s %.0f/%.0f  " % [f.class_id, f.healing_done, f.damage_dealt]
	return s


func _party_line() -> String:
	var s := ""
	for f: Fighter in match_node.party():
		s += "%s %.0f%%/m%.0f " % [f.class_id.substr(0, 5), f.hp / f.max_hp * 100.0, f.mp / maxf(1.0, f.max_mp) * 100.0]
	var b := match_node.boss
	if b != null and is_instance_valid(b) and match_node.boss_brain != null:
		s += "| boss %.0f%%" % (b.hp / b.max_hp * 100.0)
	return s


func _stuck_report() -> String:
	var s := "t=%.0f enc=%d state=%s |" % [match_node.clear_time, match_node.current,
		match_node.enc_state[mini(match_node.current, match_node.enc_state.size() - 1)]]
	for f: Fighter in match_node.party():
		s += " %s@(%.0f,%.0f)%s" % [f.class_id, f.global_position.x, f.global_position.z, "" if f.is_alive() else "x"]
	s += " | mobs:"
	for f: Fighter in world.team_fighters(MatchRaid.MOB_TEAM, true):
		if f.is_alive():
			s += " %s@(%.0f,%.0f)%s" % [f.mob_id, f.global_position.x, f.global_position.z, "" if f.brain != null else "(idle)"]
	return s


func _print_table() -> void:
	if rows.is_empty():
		return
	print("\nRAID CLEAR TABLE")
	print("| raid | party | diff | result | clear time | wipes | wipes per encounter | boss hp at wipes |")
	print("|---|---|---|---|---|---|---|---|")
	for r: Dictionary in rows:
		print("| %s | %s | %d | %s | %s | %d | %s | %s |" % [r["raid"], "tank+healer" if bool(r["healer"]) else "no healer",
			int(r["diff"]), "clear" if bool(r["victory"]) else ("STUCK" if bool(r["stuck"]) else "fail"),
			MatchRaid.format_time(float(r["time"])), int(r["wipes"]), str(r["wipes_at"]), ", ".join(PackedStringArray(r["boss_hp_wipe"]))])
