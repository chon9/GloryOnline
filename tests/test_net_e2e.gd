extends SceneTree
## NET-HUD integration: every lobby option end to end, solo with bots and the REAL class kits.
##   main menu loads -> solo lobby (class picker lists all kits with CN/EN, map list valid per mode, raid list)
##   -> for duel / arena / team / raid: start_match, the local fighter is handed to a BotBrain, the match
##   runs to completion on its own (short round_time, Engine.time_scale), HUD bound to World + Mode,
##   results screen data == Match result, auto return to the lobby.
## Raid: the party clears the first encounter naturally where possible, then skips to the boss
## (MatchRaid.debug_skip_to); a boss still standing after the time budget is finished off (reported as NOTE).
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_e2e.gd -- --no-steam

const TIME_SCALE: float = 4.0
const RECORDS_TMP: String = "user://test_e2e_records.json"

var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	_main.call_deferred()


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


func wait_until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _main() -> void:
	await process_frame
	game = root.get_node("Game")
	game.results_auto_return = 1.5
	await run()
	Engine.time_scale = 1.0
	if FileAccess.file_exists(RECORDS_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS_TMP))
	print("NET TESTS [e2e]: %d passed, %d failed" % [passed, failed])
	print("NET TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func in_match() -> bool:
	return current_scene != null and current_scene.name == "MatchScene"


func in_lobby() -> bool:
	return game.state == 1 and current_scene != null and current_scene.name == "Main" \
		and current_scene.get_node_or_null("Lobby") != null


func real_kits() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in root.get_node("Registry").call("kit_ids"):
		if not str(id).begins_with("test_"):
			out.append(str(id))
	return out


func run() -> void:
	# ---------------------------------------------------------------- main menu + lobby
	change_scene_to_file("res://scenes/main.tscn")
	await wait_frames(3)
	check(current_scene != null and current_scene.name == "Main", "main menu scene loads")
	game.start_solo()
	await wait_frames(3)
	check(in_lobby(), "solo -> lobby view")
	var lobby: Node = current_scene.get_node_or_null("Lobby")
	var card: Node = lobby.get("_card") if lobby != null else null
	var kits := real_kits()
	check(kits.size() == 25, "registry has 25 real classes", str(kits.size()))
	if card != null:
		var buttons: Dictionary = card.get("_buttons")
		var bilingual := 0
		for id: Variant in buttons:
			var t: String = (buttons[id] as Button).text
			var k: ClassKit = root.get_node("Registry").call("get_kit", str(id))
			if k != null and t.contains(k.name_cn) and t.contains(k.name_en):
				bilingual += 1
		var real_buttons := 0
		for id: Variant in buttons:
			if kits.has(str(id)):
				real_buttons += 1
		check(real_buttons == 25 and bilingual == buttons.size(), "class picker: 25 classes, CN + EN labels",
			"%d/%d" % [real_buttons, bilingual])
		var desc: String = card.call("describe", "unspecialized")
		check(desc.contains("散人") and desc.contains("Unspecialized"), "class picker describes 散人 Unspecialized")
	else:
		check(false, "class picker present in lobby")
	# lobby map lists follow MapRegistry.for_mode / RaidRegistry
	for m: String in ["duel", "arena", "team", "raid"]:
		game.set_setting("mode", m)
		await wait_frames(2)
		var ids: Array = lobby.get("_map_ids")
		var valid: Array[String] = []
		if m == "raid":
			for id: Variant in RaidRegistry.ids():
				valid.append(str(id))
		else:
			for d: Dictionary in MapRegistry.for_mode(m):
				valid.append(str(d["id"]))
		var ok := not ids.is_empty()
		for id: Variant in ids:
			ok = ok and valid.has(str(id))
		check(ok and ids.size() == valid.size(), "lobby %s list = valid maps only" % m, str(ids))
	# Game._ensure_map: an invalid map for the mode falls back to a valid one
	game.set_setting("mode", "duel")
	game.settings["map_id"] = "old_castle"
	game.call("_ensure_map")
	var duel_ids: Array[String] = []
	for d: Dictionary in MapRegistry.for_mode("duel"):
		duel_ids.append(str(d["id"]))
	check(duel_ids.has(str(game.settings["map_id"])), "_ensure_map: old_castle is not a duel map -> fallback",
		str(game.settings["map_id"]))
	game.settings["raid_id"] = "nope"
	game.set_setting("mode", "raid")
	game.call("_ensure_map")
	check(RaidRegistry.ids().has(str(game.settings["raid_id"])), "_ensure_map: unknown raid id -> first raid")
	# ---------------------------------------------------------------- the four modes
	Engine.time_scale = TIME_SCALE
	game.set_setting("bot_difficulty", 3)
	game.set_setting("rounds_to_win", 1)
	game.set_setting("round_time", 30)
	await play_mode("duel", 2, 150.0)
	await play_mode("arena", 2, 240.0)
	game.set_setting("team_size", 5)
	await play_mode("team", 10, 200.0)
	await play_mode("raid", 5, 240.0)
	game.leave_session()
	await wait_frames(3)
	check(game.state == 0, "leave -> menu")


## Starts `mode` with random real kits, lets bots play it to the end, checks HUD/results/return.
func play_mode(mode: String, expect_fighters: int, budget: float) -> void:
	game.set_setting("mode", mode)
	var kits := real_kits()
	kits.shuffle()
	var i := 0
	for s: Dictionary in game.roster:
		game.set_slot_class(int(s["slot"]), kits[i % kits.size()])
		i += 1
	game.set_my_class(kits[0])
	var why: String = game.start_match()
	check(why == "", "%s: start_match" % mode, why)
	var ok: bool = await wait_until(func() -> bool: return game.state == 3 and in_match(), 25.0)
	check(ok, "%s: match scene loaded" % mode)
	if not ok:
		return
	var scene := current_scene
	scene.set("input_enabled", false)
	var w: World = scene.get("world")
	var mnode: Node = scene.get("mode")
	if mode == "raid":
		mnode.set("records_path", RECORDS_TMP)
		check(mnode.get_script().resource_path == "res://modes/match_raid.gd", "raid: MatchRaid instantiated")
		check(str((scene.get("map") as MapBase).map_kind) == "raid", "raid: dungeon map")
	ok = await wait_until(func() -> bool: return w.fighters.size() >= expect_fighters, 15.0)
	check(ok, "%s: %d fighters spawned" % [mode, expect_fighters], str(w.fighters.size()))
	# HUD wiring done by the real match scene
	var hud: Node = scene.get("hud")
	check(hud != null and hud.get("world") == w and hud.get("match_node") == mnode, "%s: HUD bound to World + Mode" % mode)
	check(hud != null and str(hud.get("mode")) == mode, "%s: HUD mode" % mode)
	var map_id := str((scene.get("map") as MapBase).map_id)
	if mode != "raid":
		var valid: Array[String] = []
		for d: Dictionary in MapRegistry.for_mode(mode):
			valid.append(str(d["id"]))
		check(valid.has(map_id), "%s: map valid for mode" % mode, map_id)
	# hand the local fighter to the AI so the match plays itself
	var kill_events: Array = []
	if mnode.has_signal("kill_event"):
		mnode.connect("kill_event", func(v: int, k: int) -> void: kill_events.append([v, k]))
	var skipped := false
	var boss_seen := false
	var bar_seen := false
	var forced := false
	var start_ms := Time.get_ticks_msec()
	var t_end := start_ms + int(budget * 1000.0)
	while Time.get_ticks_msec() < t_end and game.last_result.is_empty():
		await physics_frame
		if not is_instance_valid(w):
			break
		var me := w.local_fighter()
		if me != null and me.brain == null:
			me.kind = "bot"
			w.attach_brain(me, "raid" if mode == "raid" else "pvp")
		if mode == "raid":
			var elapsed := float(Time.get_ticks_msec() - start_ms) / 1000.0
			var cur := int(mnode.get("current"))
			var encs: Array = mnode.get("encounters")
			if not skipped and (elapsed > 45.0 or cur >= encs.size() - 1):
				skipped = true
				print("NOTE: raid reached encounter %d/%d naturally (clear time %.1f s)" % [cur + 1, encs.size(), float(mnode.get("clear_time"))])
				if cur < encs.size() - 1:
					mnode.call("debug_skip_to", encs.size() - 1)
			var sc: Dictionary = mnode.get("score")
			if int(sc.get("boss_uid", 0)) != 0:
				boss_seen = true
			if hud != null and (hud.get("boss_bar") as Control).visible:
				bar_seen = true
			var boss: Variant = mnode.get("boss")
			if not forced and elapsed > budget * 0.75 and boss != null and is_instance_valid(boss) and (boss as Fighter).is_alive():
				forced = true
				print("NOTE: boss not down after %.0f s real; finishing it (hp %.0f%%, sim %.0f s, wipes %d)" % [elapsed,
						100.0 * (boss as Fighter).hp / (boss as Fighter).max_hp, float(mnode.get("clear_time")), int(mnode.get("wipes"))])
				(boss as Fighter).kill(w.team_fighters(0)[0])
	var res: Dictionary = game.last_result
	check(not res.is_empty(), "%s: match ran to completion" % mode, "%.0f s real" % (float(Time.get_ticks_msec() - start_ms) / 1000.0))
	if res.is_empty():
		game.return_to_lobby()
		await wait_until(func() -> bool: return in_lobby(), 10.0)
		return
	print("INFO: %s ended in %.1f s real: winner %d mvp %d, sim clear_time %.1f, wipes %d" % [mode,
		float(Time.get_ticks_msec() - start_ms) / 1000.0, int(res.get("winner_team", -9)), int(res.get("mvp_uid", -1)),
		float(res.get("clear_time", 0.0)), int(res.get("wipes", 0))])
	var stats: Dictionary = res.get("stats", {})
	check(str(res.get("mode", "")) == mode, "%s: result mode" % mode)
	check(stats.has(int(res.get("mvp_uid", -1))), "%s: MVP is in stats" % mode)
	var players := 0
	for uid: Variant in stats:
		var s: Dictionary = stats[uid]
		if str(s.get("kind", "")) in ["player", "bot"]:
			players += 1
	if mode == "arena":
		# only fighters that reached the stage are spawned/tracked: the loser's 3 + the winner's 1..3
		check(players >= 4 and players <= 6, "arena: stats for every fighter that fought", str(players))
	else:
		check(players == expect_fighters, "%s: stats for every roster fighter" % mode, str(players))
	if mode == "raid":
		check(int(res.get("winner_team", -1)) == 0 and float(res.get("clear_time", 0.0)) > 0.0, "raid: cleared with clear_time",
			str(res.get("clear_time")))
		check(str(res.get("raid_id", "")) == str(game.settings.get("raid_id", "")), "raid: result raid_id")
		check(boss_seen, "raid: score.boss_uid published")
		check(bar_seen, "raid: HUD boss bar shown")
	else:
		var wt := int(res.get("winner_team", -9))
		check(wt >= -1 and wt <= 1, "%s: winner_team" % mode, str(wt))
		var sc: Dictionary = res.get("score", {})
		check((sc.get("wins", []) as Array).size() == 2, "%s: final score wins" % mode)
		var deaths := 0
		for uid: Variant in stats:
			deaths += int((stats[uid] as Dictionary).get("deaths", 0))
		check(kill_events.size() == deaths, "%s: kill_event per death" % mode, "%d events / %d deaths" % [kill_events.size(), deaths])
	ok = await wait_until(func() -> bool: return in_match() and current_scene.has_node("Results"), 10.0)
	check(ok, "%s: results screen shown" % mode)
	if ok:
		var rs: Node = current_scene.get_node("Results")
		var shown: Dictionary = rs.get("result")
		check(int(shown.get("winner_team", -9)) == int(res.get("winner_team", -8)) and (shown.get("stats", {}) as Dictionary).size() == stats.size(),
			"%s: results screen shows the match result" % mode)
		check(hud != null and (hud.get("scoreboard") as Control).visible, "%s: HUD scoreboard after end" % mode)
	ok = await wait_until(func() -> bool: return in_lobby(), 15.0)
	check(ok, "%s: results -> back to lobby" % mode)
	await wait_frames(2)
