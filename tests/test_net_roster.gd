extends SceneTree
## NET: roster ops + settings validation/sync logic + prefs + lobby UI smoke (offline host).
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_net_roster.gd -- --no-steam

const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

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


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _main() -> void:
	await process_frame
	game = root.get_node("Game")
	net = root.get_node("Net")
	root.get_node("Registry").call("register_kit", (load(KIT_PATH) as Script).new())
	game.prefs_path = "user://test_net_roster_settings.cfg"
	game.prefs["class_id"] = "test_dummy"
	await run()
	print("NET TESTS [roster]: %d passed, %d failed" % [passed, failed])
	print("NET TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _humans() -> Array:
	var out: Array = []
	for s: Dictionary in game.roster:
		if int(s["peer"]) != 0:
			out.append(s)
	return out


func run() -> void:
	check(game.state == 0, "Game starts in MENU")
	check(InputMap.has_action("skill_7") and InputMap.has_action("menu") and InputMap.has_action("move_forward"), "InputMap actions registered")
	for k: String in ["mode", "map_id", "bot_difficulty", "pvp_damage_scale", "round_time", "rounds_to_win", "raid_id"]:
		if not game.settings.has(k):
			check(false, "settings key " + k)
	check(true, "settings keep stub keys")
	check(net.get("steam_ok") is bool, "Net.steam_ok exists")
	# --- offline host
	game.start_solo()
	await frames(3)
	check(game.state == 1, "solo -> LOBBY state")
	check(game.roster.size() == 2, "duel roster has 2 slots", str(game.roster))
	var me: Dictionary = game.my_slot()
	check(not me.is_empty() and int(me["team"]) == 0 and int(me["peer"]) == 1, "host seated on team 0")
	check(str(me.get("class_id", "")) == "test_dummy", "host class from prefs")
	check(int((game.team_slots(1)[0] as Dictionary)["peer"]) == 0, "bot fills team 1")
	# --- settings
	game.set_setting("mode", "team")
	check(game.roster.size() == 10, "team mode fills 5v5 with bots", str(game.roster.size()))
	check(_humans().size() == 1 and int(_humans()[0]["team"]) == 0, "human kept after mode change")
	game.set_setting("team_size", 3)
	check(game.roster.size() == 6, "team_size 3 -> 6 slots")
	game.set_setting("bot_difficulty", 9)
	check(int(game.settings["bot_difficulty"]) == 3, "bot_difficulty clamped")
	check(not game.apply_op(1, "set_setting", ["mode", "chess"]), "invalid mode rejected")
	check(str(game.settings["mode"]) == "team", "mode unchanged after invalid")
	check(not game.apply_op(1, "set_setting", ["secret", 1]), "unknown setting key rejected")
	# --- bots
	me = game.my_slot()
	var bot: Dictionary = game.team_slots(1)[0]
	game.remove_slot(int(bot["slot"]))
	check(game.roster.size() == 5, "remove bot")
	check(not game.apply_op(1, "remove_slot", [int(me["slot"])]), "cannot remove a human slot")
	game.add_bot(1)
	check(game.team_slots(1).size() == 3, "add bot")
	check(not game.apply_op(1, "add_bot", [1]), "add bot to full team rejected")
	var b2: Dictionary = game.team_slots(1)[0]
	check(game.apply_op(1, "set_class", [int(b2["slot"]), "test_dummy"]), "host sets bot class")
	check(not game.apply_op(1, "set_class", [int(b2["slot"]), "no_such_class"]), "invalid class rejected")
	# --- swap team
	game.swap_team(int(me["slot"]))
	me = game.my_slot()
	check(int(me["team"]) == 1 and game.team_slots(0).size() == 3 and game.team_slots(1).size() == 3, "swap team trades with a bot")
	game.swap_team(int(me["slot"]))
	me = game.my_slot()
	check(int(me["team"]) == 0, "swap back")
	# --- remote client requests (validated by host)
	check(game.apply_op(5, "hello", ["Remote", "test_dummy"]), "hello seats remote human")
	var rs: Dictionary = game.slot_of_peer(5)
	check(not rs.is_empty() and int(rs["team"]) == 1, "remote placed on team with room (replaced a bot)")
	check(game.roster.size() == 6, "roster size unchanged (bot replaced)")
	check(not game.apply_op(5, "set_class", [int(me["slot"]), "test_dummy"]), "client cannot change another slot")
	check(not game.apply_op(5, "set_setting", ["mode", "duel"]), "client cannot change settings")
	check(not game.apply_op(5, "add_bot", [0]), "client cannot add bots")
	check(game.apply_op(5, "set_class", [int(rs["slot"]), "test_dummy"]), "client changes own class")
	check(game.can_start() != "", "cannot start while client not ready")
	check(game.apply_op(5, "set_ready", [true]), "client ready")
	check(game.can_start() == "", "can start when all ready", game.can_start())
	check(game.apply_op(5, "hello", ["Renamed", ""]), "repeat hello updates name")
	check(str(game.slot_of_peer(5)["name"]) == "Renamed" and game.roster.size() == 6, "no duplicate slot on repeat hello")
	# --- state sync roundtrip
	var st: Dictionary = game.get_state()
	var copy: Array = (st["roster"] as Array).duplicate(true)
	game.roster = []
	game.apply_state(st)
	check(game.roster == copy and str(game.settings["mode"]) == "team", "get_state/apply_state roundtrip")
	# --- disconnect in lobby
	game._on_peer_left(5)
	check(game.slot_of_peer(5).is_empty() and game.roster.size() == 6, "lobby disconnect removes slot, bot refills")
	# --- raid
	game.set_setting("mode", "raid")
	check(game.team_count() == 1 and game.roster.size() == 5, "raid: one party of 5")
	var all_t0 := true
	for s: Dictionary in game.roster:
		all_t0 = all_t0 and int(s["team"]) == 0
	check(all_t0, "raid: everyone on team 0")
	game.set_setting("mode", "arena")
	check(game.roster.size() == 6 and game.team_slots(0).size() == 3, "arena 3v3")
	game.set_setting("mode", "duel")
	check(game.roster.size() == 2, "back to duel")
	# --- capacity: a mode/team_size change may never unseat a connected human
	game.set_setting("mode", "team")
	for p: int in [2, 3, 4]:
		game.apply_op(p, "hello", ["P%d" % p, ""])
	check(_humans().size() == 4, "team: 4 humans seated", str(_humans()))
	check(not game.apply_op(1, "set_setting", ["mode", "duel"]), "mode -> duel rejected with 4 humans")
	check(str(game.settings["mode"]) == "team" and _humans().size() == 4, "mode unchanged, humans kept")
	check(not game.apply_op(1, "set_setting", ["team_size", 1]), "team_size 1 rejected with 4 humans")
	check(game.apply_op(1, "set_setting", ["team_size", 2]), "team_size 2 fits 4 humans")
	check(_humans().size() == 4 and game.roster.size() == 4, "2v2 keeps all 4 humans", str(game.roster.size()))
	check(game.apply_op(1, "set_setting", ["mode", "arena"]) and _humans().size() == 4, "arena keeps all 4 humans")
	for p: int in [2, 3, 4]:
		game._on_peer_left(p)
	game.set_setting("team_size", 5)
	game.set_setting("mode", "duel")
	check(game.roster.size() == 2 and _humans().size() == 1, "peers left -> duel allowed again")
	# --- rejected joiner keeps the host's reason over the generic disconnect text
	game._rpc_rejected("房间已满 Lobby is full")
	game._on_net_disconnected("主机已断开 Host disconnected")
	check(game.pending_message == "房间已满 Lobby is full" and game._reject_reason == "", "reject reason survives the kick", game.pending_message)
	game.start_solo()
	await frames(3)
	check(game.state == 1, "back in solo lobby after reject test", str(game.state))
	# --- prefs
	game.prefs["volume"] = 0.35
	game.prefs["mouse_sensitivity"] = 1.7
	game.prefs["player_name"] = "测试 Tester"
	check(game.save_prefs() == OK, "prefs saved")
	game.prefs["volume"] = 1.0
	game.prefs["player_name"] = ""
	game.load_prefs()
	check(absf(float(game.prefs["volume"]) - 0.35) < 0.001 and str(game.prefs["player_name"]) == "测试 Tester", "prefs loaded")
	check(game.local_name() == "测试 Tester", "local name from prefs")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.prefs_path))
	# --- UI smoke: main scene shows the lobby; class card describes kits; theme loads
	await frames(5)
	var cur := current_scene
	check(cur != null and cur.name == "Main", "main.tscn is current scene", str(cur))
	var lobby: Node = cur.get_node_or_null("Lobby") if cur != null else null
	check(lobby != null, "lobby view shown in LOBBY state")
	var th: Variant = load("res://ui/theme.tres")
	check(th is Theme and (th as Theme).default_font is SystemFont, "theme.tres loads with SystemFont")
	var card: Node = (load("res://ui/class_card.gd") as Script).new()
	root.add_child(card)
	await process_frame
	var txt: String = card.call("describe", "test_dummy")
	check(txt.contains("测试木人") and txt.contains("Light Bolt"), "class card lists CN/EN names + skills")
	card.queue_free()
	game.leave_session()
	await frames(5)
	check(game.state == 0 and current_scene != null and current_scene.name == "Main" and current_scene.get_node_or_null("Lobby") == null, "leave -> main menu")
