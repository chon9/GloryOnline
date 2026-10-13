extends SceneTree
## NET: Steam path. When Steam is running: Net initialises (app 480), hosts a lobby (SteamMultiplayerPeer
## host_with_lobby), Game enters the lobby, the lobby is tagged/listed, then leaves back to offline.
## Skips gracefully (0 passed, 0 failed) when Steam is not available.
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_steam.gd

var passed: int = 0
var failed: int = 0
var game: Node
var net: Node


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
		await process_frame
	return bool(cond.call())


func _main() -> void:
	await process_frame
	game = root.get_node("Game")
	net = root.get_node("Net")
	print("Steam status: " + str(net.get("steam_status")))
	if not bool(net.get("steam_ok")):
		print("SKIP: Steam not running / GodotSteam unavailable")
		check(net.call("is_host") == true and not bool(net.call("is_online")), "offline fallback is server")
	else:
		await run()
	print("NET TESTS [steam]: %d passed, %d failed" % [passed, failed])
	print("NET TESTS: %d passed, %d failed" % [passed, failed])
	net.call("leave")
	quit(1 if failed > 0 else 0)


func run() -> void:
	check(int(net.get("steam_id")) != 0 and str(net.get("persona_name")) != "", "Steam id + persona name")
	var ready_ids: Array = []
	net.connect("lobby_ready", func(id: int) -> void: ready_ids.append(id))
	var lists: Array = []
	net.connect("lobby_list_received", func(l: Array) -> void: lists.append(l))
	game.host_steam()
	var ok: bool = await wait_until(func() -> bool: return not ready_ids.is_empty(), 20.0)
	check(ok, "lobby created (lobby_ready)")
	if not ok:
		return
	var lid: int = int(net.get("lobby_id"))
	check(lid != 0 and lid == int(ready_ids[0]), "lobby id set")
	check(str(net.get("transport")) == "steam" and root.multiplayer.is_server() and root.multiplayer.get_unique_id() == 1, "SteamMultiplayerPeer hosting (server, id 1)")
	ok = await wait_until(func() -> bool: return game.state == 1, 3.0)
	check(ok and not game.my_slot().is_empty(), "Game entered lobby with host slot")
	var members: Array = net.call("lobby_members")
	check(members.size() == 1, "lobby member list has self", str(members))
	check(str(net.call("steam_call", "getLobbyData", [lid, "game"])) == "rongyao_arena", "lobby tagged with GAME_KEY")
	game.set_setting("mode", "team")
	check(str(net.call("steam_call", "getLobbyData", [lid, "mode"])) == "team", "lobby mode data follows settings")
	await wait_until(func() -> bool: return false, 2.0)
	net.call("refresh_lobbies")
	ok = await wait_until(func() -> bool: return not lists.is_empty(), 15.0)
	check(ok, "lobby list received")
	if ok:
		var found := false
		for d: Variant in lists[0]:
			if d is Dictionary and int((d as Dictionary).get("id", 0)) == lid:
				found = true
		print("lobbies listed: %d (own found: %s)" % [(lists[0] as Array).size(), found])
	game.leave_session()
	await wait_until(func() -> bool: return false, 0.5)
	check(int(net.get("lobby_id")) == 0 and str(net.get("transport")) == "offline", "left lobby")
	check(root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and root.multiplayer.is_server(), "back to OfflineMultiplayerPeer")
	check(game.state == 0, "Game back in MENU")
