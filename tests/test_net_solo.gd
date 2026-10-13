extends SceneTree
## NET: offline/solo flow through the real scenes: main menu -> solo lobby -> duel vs bot (best of 3, countdown
## freeze, round reset) -> results -> auto return to lobby -> group arena 3v3 (winner stays + heal, next
## challenger, team out) -> team battle free play with bots for a few seconds -> host aborts to the lobby.
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_solo.gd -- --no-steam

const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

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
	root.get_node("Registry").call("register_kit", (load(KIT_PATH) as Script).new())
	game.prefs["class_id"] = "test_dummy"
	game.results_auto_return = 1.0
	Engine.time_scale = 2.0
	await run()
	Engine.time_scale = 1.0
	print("NET TESTS [solo]: %d passed, %d failed" % [passed, failed])
	print("NET TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func scene() -> Node:
	return current_scene


func mode_node() -> Node:
	var s := current_scene
	return s.get("mode") if s != null and s.name == "MatchScene" else null


func start(mode: String) -> bool:
	game.set_setting("mode", mode)
	for s: Dictionary in game.roster:
		game.set_slot_class(int(s["slot"]), "test_dummy")
	game.set_my_class("test_dummy")
	var why: String = game.start_match()
	check(why == "", "start_match %s" % mode, why)
	var ok: bool = await wait_until(func() -> bool: return game.state == 3 and current_scene != null and current_scene.name == "MatchScene", 20.0)
	check(ok, "%s: match scene loaded and begun" % mode)
	if ok:
		current_scene.set("input_enabled", false)
	return ok


func phase_is(p: String) -> bool:
	var m := mode_node()
	return m != null and m.call("phase_name") == p


func me() -> Fighter:
	var s := current_scene
	if s == null or s.name != "MatchScene":
		return null
	return (s.get("world") as World).local_fighter()


func enemy_current() -> Fighter:
	var w: World = current_scene.get("world")
	for f: Fighter in w.fighters:
		if is_instance_valid(f) and f.team == 1 and f.kind != "summon" and f.is_alive():
			return f
	return null


func run() -> void:
	# --- main menu
	change_scene_to_file("res://scenes/main.tscn")
	await wait_frames(3)
	check(current_scene != null and current_scene.name == "Main", "main menu scene loads")
	game.start_solo()
	await wait_frames(3)
	check(game.state == 1 and current_scene.get_node_or_null("Lobby") != null, "solo -> lobby view")
	# ================= duel best of 3
	game.set_setting("rounds_to_win", 2)
	game.set_setting("round_time", 90)
	if not await start("duel"):
		return
	var ok: bool = await wait_until(func() -> bool: return me() != null and enemy_current() != null, 10.0)
	check(ok, "duel: human + bot fighters spawned")
	if not ok:
		return
	var w: World = current_scene.get("world")
	check(w.fighters.size() == 2 and enemy_current().kind == "bot", "duel: 1v1 with bot")
	check(current_scene.get("hud") != null or not ResourceLoader.exists("res://ui/hud.gd"), "HUD instanced when present")
	# Frozen during countdown.
	await wait_until(func() -> bool: return phase_is("countdown"), 5.0)
	var p0 := me().global_position
	for i in 30:
		var inp := FighterInput.new()
		inp.move = Vector3(1, 0, 0)
		me().apply_input(inp)
		await physics_frame
	check(CoreUtil.flat(me().global_position - p0).length() < 0.2, "countdown freezes movement", str(me().global_position - p0))
	ok = await wait_until(func() -> bool: return phase_is("fight"), 8.0)
	check(ok, "countdown -> fight")
	p0 = me().global_position
	for i in 30:
		var inp := FighterInput.new()
		inp.move = Vector3(1, 0, 0)
		me().apply_input(inp)
		await physics_frame
	check(me().global_position.distance_to(p0) > 0.5, "fight: input moves fighter")
	enemy_current().kill(me())
	ok = await wait_until(func() -> bool: return phase_is("round_end"), 3.0)
	var m := mode_node()
	check(ok and (m.get("wins") as Array)[0] == 1, "round 1 to team 0")
	ok = await wait_until(func() -> bool: return int(mode_node().get("round_no")) == 2, 8.0)
	check(ok, "round 2 started")
	var bot := enemy_current()
	check(bot != null and bot.hp >= bot.max_hp - 0.1, "round reset revives bot at full hp")
	await wait_until(func() -> bool: return phase_is("fight"), 8.0)
	enemy_current().kill(me())
	ok = await wait_until(func() -> bool: return not game.last_result.is_empty(), 8.0)
	check(ok, "duel: match_ended after 2 round wins")
	check(int(game.last_result.get("winner_team", -9)) == 0, "duel: team 0 wins", str(game.last_result.get("winner_team")))
	check((game.last_result.get("stats", {}) as Dictionary).size() >= 2, "duel: result has stats")
	ok = await wait_until(func() -> bool: return current_scene != null and current_scene.has_node("Results"), 6.0)
	check(ok, "results screen shown")
	ok = await wait_until(func() -> bool: return game.state == 1 and current_scene != null and current_scene.name == "Main", 10.0)
	check(ok, "results -> back to lobby")
	await wait_frames(3)
	check(current_scene.get_node_or_null("Lobby") != null, "lobby view after match")
	# ================= group arena 3v3
	if not await start("arena"):
		return
	ok = await wait_until(func() -> bool: return me() != null and enemy_current() != null, 10.0)
	w = current_scene.get("world")
	check(ok and w.fighters.size() == 2, "arena: only one fighter per team on stage", str(w.fighters.size()))
	for b in 3:
		ok = await wait_until(func() -> bool: return phase_is("fight") and enemy_current() != null, 12.0)
		if not ok:
			check(false, "arena: bout %d fight" % (b + 1))
			return
		var hero := me()
		hero.hp = hero.max_hp * 0.5
		enemy_current().kill(hero)
		ok = await wait_until(func() -> bool: return not phase_is("fight"), 3.0)
		var rem: Array = mode_node().get("score").get("remaining", [])
		check(rem.size() == 2 and int(rem[1]) == 2 - b and int(rem[0]) == 3, "arena: remaining after bout %d" % (b + 1), str(rem))
		check(absf(hero.hp - hero.max_hp * 0.6) < 1.0, "arena: winner stays with +10%% heal (bout %d)" % (b + 1), str(hero.hp / hero.max_hp))
	ok = await wait_until(func() -> bool: return not game.last_result.is_empty(), 8.0)
	check(ok and int(game.last_result.get("winner_team", -9)) == 0, "arena: team 1 out of fighters -> team 0 wins")
	check(int((game.last_result.get("stats", {}) as Dictionary).size()) >= 4, "arena: stats kept for freed fighters")
	ok = await wait_until(func() -> bool: return game.state == 1 and current_scene.name == "Main", 12.0)
	check(ok, "arena -> back to lobby")
	# ================= team battle free play (bots fight), host aborts
	game.set_setting("team_size", 3)
	game.set_setting("round_time", 60)
	if not await start("team"):
		return
	ok = await wait_until(func() -> bool: return (current_scene.get("world") as World).fighters.size() >= 6, 10.0)
	check(ok, "team: 3v3 spawned")
	await wait_until(func() -> bool: return phase_is("fight"), 8.0)
	await wait_frames(400)
	check(current_scene.name == "MatchScene", "team: free play ran ~13 s (scaled) without leaving")
	game.return_to_lobby()
	ok = await wait_until(func() -> bool: return game.state == 1 and current_scene.name == "Main", 8.0)
	check(ok, "host abort -> lobby")
	# ================= real class kits (when KITS has shipped them): 5v5 bots with random classes
	var real: Array[String] = []
	for id: Variant in root.get_node("Registry").call("kit_ids"):
		if not str(id).begins_with("test_"):
			real.append(str(id))
	if real.size() >= 2:
		game.set_setting("team_size", 5)
		game.set_setting("mode", "team")
		var i := 0
		for s: Dictionary in game.roster:
			game.set_slot_class(int(s["slot"]), real[i % real.size()])
			i += 3
		game.set_my_class(real[0])
		var why: String = game.start_match()
		check(why == "", "real kits: start", why)
		ok = await wait_until(func() -> bool: return game.state == 3 and current_scene.name == "MatchScene", 20.0)
		check(ok and (current_scene.get("world") as World).fighters.size() >= 10, "real kits: 5v5 spawned")
		current_scene.set("input_enabled", false)
		await wait_frames(600)
		check(current_scene.name == "MatchScene", "real kits: 5v5 bots fought ~20 s (scaled)")
		game.return_to_lobby()
		ok = await wait_until(func() -> bool: return game.state == 1 and current_scene.name == "Main", 8.0)
		check(ok, "real kits: back to lobby")
	else:
		print("SKIP: real class kits not present")
	# ================= raid (when RAID has shipped modes/match_raid.gd): party of 5 runs for a while
	if ResourceLoader.exists("res://modes/match_raid.gd") and real.size() >= 2:
		game.set_setting("mode", "raid")
		game.set_my_class(real[0])
		var why2: String = game.start_match()
		check(why2 == "", "raid: start", why2)
		ok = await wait_until(func() -> bool: return game.state == 3 and current_scene.name == "MatchScene", 20.0)
		check(ok and current_scene.get("mode").get_script().resource_path == "res://modes/match_raid.gd", "raid: MatchRaid mode loaded")
		check(ok and str((current_scene.get("map") as MapBase).map_kind) == "raid", "raid: dungeon map built", str((current_scene.get("map") as MapBase).map_id))
		current_scene.set("input_enabled", false)
		await wait_frames(300)
		check((current_scene.get("world") as World).team_fighters(0).size() == 5, "raid: party of 5 spawned")
		game.return_to_lobby()
		ok = await wait_until(func() -> bool: return game.state == 1 and current_scene.name == "Main", 8.0)
		check(ok, "raid: back to lobby")
	game.leave_session()
	await wait_frames(3)
	check(game.state == 0, "leave -> menu")
