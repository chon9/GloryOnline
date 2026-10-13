extends SceneTree
## NET: two-process ENet flow through Game/Net and the real scenes.
##   host:   & Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_enet.gd -- --role=host --no-steam
##   client: & Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_enet.gd -- --role=client --no-steam
## lobby (client hello/class/ready synced) -> start_match -> both load scenes/match.tscn -> fighters spawn for
## both peers -> client input moves its fighter on the host -> host ends the duel -> results -> both back
## in the lobby.

const PORT: int = 27941
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var role: String = "host"
var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
	_main.call_deferred()


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: [%s] %s" % [role, label])
	else:
		failed += 1
		print("FAIL: [%s] %s%s" % [role, label, "" if detail == "" else "  (" + detail + ")"])


func wait_until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _main() -> void:
	await process_frame
	game = root.get_node("Game")
	root.get_node("Registry").call("register_kit", (load(KIT_PATH) as Script).new())
	game.prefs["class_id"] = "test_dummy"
	game.prefs["player_name"] = "主机 Host" if role == "host" else "客户端 Client"
	game.results_auto_return = 1.5
	if role == "host":
		await _host()
	else:
		await _client()
	print("NET TESTS [enet-%s]: %d passed, %d failed" % [role, passed, failed])
	print("NET TESTS: %d passed, %d failed" % [passed, failed])
	root.get_node("Net").call("leave")
	quit(1 if failed > 0 else 0)


func in_match_scene() -> bool:
	return current_scene != null and current_scene.name == "MatchScene" and game.match_scene != null


func _world() -> World:
	return current_scene.get("world") as World if in_match_scene() else null


func _host() -> void:
	var e: int = game.host_lan(PORT)
	check(e == OK, "host_lan ok")
	check(await wait_until(func() -> bool: return game.state == 1, 3.0), "host in lobby")
	game.set_setting("mode", "duel")
	game.set_setting("rounds_to_win", 1)
	var ok: bool = await wait_until(func() -> bool:
		var s: Dictionary = game.slot_of_peer(_client_id())
		return not s.is_empty() and bool(s["ready"]), 20.0)
	check(ok, "client joined roster and readied up")
	if not ok:
		return
	var cid := _client_id()
	var cs: Dictionary = game.slot_of_peer(cid)
	check(str(cs["name"]) == "客户端 Client", "client name synced", str(cs["name"]))
	check(str(cs["class_id"]) == "test_dummy" and int(cs["team"]) == 1, "client class/team")
	check(game.roster.size() == 2, "duel roster: host + client (bot replaced)")
	var why: String = game.start_match()
	check(why == "", "start_match", why)
	ok = await wait_until(func() -> bool: return game.state == 3 and in_match_scene(), 25.0)
	check(ok, "host: every peer loaded -> match begun")
	if not ok:
		return
	current_scene.set("input_enabled", false)
	var box: Array = [null]   # lambdas capture locals by value
	ok = await wait_until(func() -> bool:
		var w := _world()
		if w == null:
			return false
		for f: Fighter in w.fighters:
			if f.peer == cid:
				box[0] = f
		return box[0] != null and w.local_fighter() != null, 10.0)
	var cf: Fighter = box[0]
	check(ok, "host: fighters spawned for both peers")
	if not ok:
		return
	ok = await wait_until(func() -> bool: return game.match_scene.get("mode").call("phase_name") == "fight", 10.0)
	check(ok, "host: countdown -> fight")
	var p0 := cf.global_position
	ok = await wait_until(func() -> bool: return CoreUtil.flat(cf.global_position - p0).length() > 1.5, 10.0)
	check(ok, "host: client input moved its fighter", str(cf.global_position - p0))
	cf.kill(_world().local_fighter())
	ok = await wait_until(func() -> bool: return not game.last_result.is_empty(), 8.0)
	check(ok and int(game.last_result.get("winner_team", -9)) == 0, "host: match ended, host team wins")
	ok = await wait_until(func() -> bool: return game.state == 1 and current_scene != null and current_scene.name == "Main", 15.0)
	check(ok, "host: back to lobby")
	check(not game.slot_of_peer(cid).is_empty(), "host: client still in roster after match")
	# Give the client time to observe the lobby, then wait for it to disconnect.
	await wait_until(func() -> bool: return root.multiplayer.get_peers().is_empty(), 15.0)


func _client_id() -> int:
	for p: int in root.multiplayer.get_peers():
		return p
	return -1


func _client() -> void:
	var e: int = -1
	var deadline := Time.get_ticks_msec() + 8000
	# The host may not be listening yet: retry.
	var ok := false
	while Time.get_ticks_msec() < deadline and not ok:
		e = game.join_lan("127.0.0.1", PORT)
		ok = await wait_until(func() -> bool: return game.state == 1, 3.0)
	check(e == OK and ok, "client joined lobby (state synced)")
	if not ok:
		return
	check(game.roster.size() == 2 and not game.my_slot().is_empty(), "client sees roster with own slot")
	game.set_my_class("test_dummy")
	game.set_ready(true)
	ok = await wait_until(func() -> bool: return in_match_scene(), 25.0)
	check(ok, "client: match scene loaded")
	if not ok:
		return
	current_scene.set("input_enabled", false)
	check(str(game.settings["mode"]) == "duel" and int(game.settings["rounds_to_win"]) == 1, "client: settings synced")
	var box: Array = [null]
	ok = await wait_until(func() -> bool:
		var w := _world()
		box[0] = w.local_fighter() if w != null else null
		return box[0] != null and w.fighters.size() == 2, 15.0)
	var me: Fighter = box[0]
	var kills: Array = []
	var mode_node: Node = game.match_scene.get("mode")
	if mode_node.has_signal("kill_event"):
		mode_node.connect("kill_event", func(v: int, k: int) -> void: kills.append([v, k]))
	check(ok, "client: own fighter + opponent replicated")
	if not ok:
		return
	var p0 := me.global_position
	var moved := false
	var press := 0
	deadline = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline and game.last_result.is_empty():
		await physics_frame
		if not is_instance_valid(me):
			break
		var inp := FighterInput.new()
		inp.move = Vector3(1, 0, 0)
		inp.press_id = press
		me.submit_input.rpc_id(1, inp.to_dict())
		if CoreUtil.flat(me.global_position - p0).length() > 1.5:
			moved = true
	check(moved, "client: replicated position changed from own input")
	check(not game.last_result.is_empty(), "client: match_ended received")
	check(int(game.last_result.get("winner_team", -9)) == 0, "client: winner synced")
	check(kills.size() == 1 and int(kills[0][0]) == me.uid, "client: kill_event received", str(kills))
	check(is_instance_valid(mode_node) and (mode_node.get("stats") as Dictionary).size() == 2, "client: Match.stats mirrored")
	var hud: Node = game.match_scene.get("hud") if game.match_scene != null else null
	var named := false
	if hud != null and hud.get("kill_feed") != null:
		var kf: Node = hud.get("kill_feed")
		for i: int in int(kf.call("entry_count")):
			if str(kf.call("entry_text", i)).contains("主机"):
				named = true
	check(named, "client: HUD kill feed names the host killer (kill_event)")
	ok = await wait_until(func() -> bool: return current_scene != null and current_scene.has_node("Results"), 6.0)
	check(ok, "client: results screen shown")
	ok = await wait_until(func() -> bool: return game.state == 1 and current_scene != null and current_scene.name == "Main", 15.0)
	check(ok, "client: back to lobby")
	await wait_until(func() -> bool: return false, 1.0)
	check(current_scene.get_node_or_null("Lobby") != null, "client: lobby view shown")
