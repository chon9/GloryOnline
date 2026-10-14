extends Node
## Autoload "Game" (owner: NET): match settings + roster (host-authoritative, synced to clients by RPC),
## local preferences (user://settings.cfg), runtime InputMap registration (ARCHITECTURE §2) and the
## scene flow  main menu -> lobby -> match.tscn -> results -> lobby.
## Offline/solo uses exactly the same code: OfflineMultiplayerPeer is the server (id 1).
##
## Roster slot: {slot: int, team: int, peer: int (0 = bot), name: String, class_id: String, ready: bool}

signal state_changed(state: int)
signal roster_changed
signal message(text: String)
signal prefs_changed

enum State { MENU, LOBBY, LOADING, MATCH }

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MATCH_SCENE: String = "res://scenes/match.tscn"
const PREFS_PATH: String = "user://settings.cfg"
const MAP_REGISTRY: String = "res://maps/map_registry.gd"
const RAID_REGISTRY: String = "res://pve/raid_registry.gd"
const MODES: Array[String] = ["duel", "arena", "team", "raid"]
const MODE_NAMES: Dictionary = {
	"duel": "个人赛 Duel (1v1)",
	"arena": "擂台赛 Group Arena (3v3)",
	"team": "团体赛 Team Battle (5v5)",
	"raid": "副本 Raid (PvE)",
}
const DIFFICULTY_NAMES: Array[String] = ["简单 Easy", "普通 Normal", "困难 Hard", "大神 Master"]
const LOAD_TIMEOUT: float = 25.0
const CLIENT_LEAVE_DELAY: float = 0.5
## Audio bus -> volume pref (0..1, linear) and a fixed offset in dB on top (ambience sits under the music).
## Buses come from res://default_bus_layout.tres (Master -> Music, SFX, UI, Ambience).
const BUS_PREFS: Dictionary = {
	"Master": "master_volume",
	"Music": "music_volume",
	"SFX": "sfx_volume",
	"UI": "ui_volume",
	"Ambience": "ambience_volume",
}
const BUS_BASE_DB: Dictionary = {"Ambience": -4.0}
## Audio sliders of the settings UIs (main menu + pause menu): [pref key, label].
const VOLUME_ROWS: Array = [
	["master_volume", "主音量 Master"],
	["music_volume", "音乐 Music"],
	["sfx_volume", "音效 SFX"],
	["ui_volume", "界面 UI"],
	["ambience_volume", "环境 Ambience"],
]
const SETTING_KEYS: Array[String] = ["mode", "map_id", "bot_difficulty", "pvp_damage_scale", "round_time",
	"rounds_to_win", "raid_id", "team_size"]

var settings: Dictionary = {
	"mode": "duel",
	"map_id": "",
	"bot_difficulty": 1,
	"pvp_damage_scale": 0.25,
	"round_time": 180,
	"rounds_to_win": 2,
	"raid_id": "",
	"team_size": 5,
}
var roster: Array = []
var state: int = State.MENU
## Message to show on the main menu (e.g. "host disconnected"); the menu clears it after showing.
var pending_message: String = ""
## Client: reason from the host's _rpc_rejected, shown instead of the generic disconnect message.
var _reject_reason: String = ""
## Local preferences (never synced).
var prefs: Dictionary = {
	"volume": 0.8,  # legacy alias of master_volume (kept working: writing it changes the master volume)
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"ui_volume": 0.8,
	"ambience_volume": 0.8,
	"mouse_sensitivity": 1.0,
	"bot_difficulty": 1,
	"player_name": "",
	"class_id": "",
	# effect intensity by caster (Fx ownership scaling) + camera impact feedback
	"fx_own": 1.0,
	"fx_ally": 0.5,
	"fx_enemy": 0.7,
	"camera_shake": true,
}
var prefs_path: String = PREFS_PATH
## Host: seconds the results screen stays before everyone returns to the lobby automatically (0 = button only).
var results_auto_return: float = 30.0
var last_result: Dictionary = {}
## The live match scene (scenes/match.tscn root, modes/match_scene.gd) or null.
var match_scene: Node = null

var _loaded: Dictionary = {}
var _load_elapsed: float = 0.0
var _next_slot: int = 1
var _rng := RandomNumberGenerator.new()
var _change_to: String = ""
## Master volume both "volume" and "master_volume" agreed on at the last sync (see _sync_volume_alias).
var _alias_master: float = 0.8


func _ready() -> void:
	register_input_actions()
	load_prefs()
	apply_prefs()
	_rng.seed = 0x5EED
	var net := get_node_or_null("/root/Net")
	if net != null:
		if net.has_signal("hosted"):
			net.connect("hosted", _on_net_hosted)
			net.connect("connected", _on_net_connected)
			net.connect("connection_failed", _on_net_failed)
			net.connect("disconnected", _on_net_disconnected)
			if net.has_signal("session_reset"):
				net.connect("session_reset", _on_net_session_reset)
			net.connect("peer_joined", _on_peer_joined)
			net.connect("peer_left", _on_peer_left)


func _process(delta: float) -> void:
	if state == State.LOADING and multiplayer.is_server():
		_load_elapsed += delta
		if _load_elapsed > LOAD_TIMEOUT:
			push_warning("Game: not every peer loaded the match in time; starting anyway")
			_begin_match_now()
	if _change_to != "":
		var p := _change_to
		_change_to = ""
		get_tree().change_scene_to_file(p)


# ================================================================== input map (ARCHITECTURE §2)
static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func register_input_actions() -> void:
	var map: Dictionary = {
		"move_forward": [_key(KEY_W)],
		"move_back": [_key(KEY_S)],
		"move_left": [_key(KEY_A)],
		"move_right": [_key(KEY_D)],
		"jump": [_key(KEY_SPACE)],
		# Tap = dodge, hold = sprint (PlayerController). The location-unspecified physical Shift matches both the
		# left and the right Shift key.
		"dodge_sprint": [_key(KEY_SHIFT)],
		# Dedicated dodge on press (no tap latency, no Sticky Keys prompt from repeated Shift taps).
		"dodge": [_key(KEY_ALT), _mouse(MOUSE_BUTTON_XBUTTON1)],
		"skill_0": [_mouse(MOUSE_BUTTON_LEFT)],
		"skill_1": [_mouse(MOUSE_BUTTON_RIGHT)],
		"skill_2": [_key(KEY_Q)],
		"skill_3": [_key(KEY_E)],
		"skill_4": [_key(KEY_R)],
		"skill_5": [_key(KEY_F)],
		"skill_6": [_key(KEY_1)],
		"skill_7": [_key(KEY_2)],
		"target_cycle": [_key(KEY_TAB)],
		"target_clear": [_mouse(MOUSE_BUTTON_MIDDLE)],
		"scoreboard": [_key(KEY_QUOTELEFT)],
		"menu": [_key(KEY_ESCAPE)],
		"camera_zoom_in": [_mouse(MOUSE_BUTTON_WHEEL_UP)],
		"camera_zoom_out": [_mouse(MOUSE_BUTTON_WHEEL_DOWN)],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for ev: InputEvent in map[action]:
				InputMap.action_add_event(action, ev)


# ================================================================== preferences
func load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(prefs_path) != OK:
		return
	var legacy: float = clampf(float(cf.get_value("audio", "volume", prefs["volume"])), 0.0, 1.0)
	prefs["master_volume"] = clampf(float(cf.get_value("audio", "master_volume", legacy)), 0.0, 1.0)
	prefs["volume"] = prefs["master_volume"]
	_alias_master = float(prefs["master_volume"])
	for k: String in ["music_volume", "sfx_volume", "ui_volume", "ambience_volume"]:
		prefs[k] = clampf(float(cf.get_value("audio", k, prefs[k])), 0.0, 1.0)
	prefs["mouse_sensitivity"] = clampf(float(cf.get_value("input", "mouse_sensitivity", prefs["mouse_sensitivity"])), 0.1, 5.0)
	prefs["bot_difficulty"] = clampi(int(cf.get_value("game", "bot_difficulty", prefs["bot_difficulty"])), 0, 3)
	prefs["player_name"] = str(cf.get_value("game", "player_name", prefs["player_name"]))
	prefs["class_id"] = str(cf.get_value("game", "class_id", prefs["class_id"]))
	for k: String in ["fx_own", "fx_ally", "fx_enemy"]:
		prefs[k] = clampf(float(cf.get_value("video", k, prefs[k])), 0.0, 1.0)
	prefs["camera_shake"] = bool(cf.get_value("video", "camera_shake", prefs["camera_shake"]))


func save_prefs() -> Error:
	_sync_volume_alias()
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", float(prefs["volume"]))
	for k: String in BUS_PREFS.values():
		cf.set_value("audio", k, float(prefs.get(k, 1.0)))
	cf.set_value("input", "mouse_sensitivity", float(prefs["mouse_sensitivity"]))
	cf.set_value("game", "bot_difficulty", int(prefs["bot_difficulty"]))
	cf.set_value("game", "player_name", str(prefs["player_name"]))
	cf.set_value("game", "class_id", str(prefs["class_id"]))
	for k: String in ["fx_own", "fx_ally", "fx_enemy"]:
		cf.set_value("video", k, float(prefs.get(k, 1.0)))
	cf.set_value("video", "camera_shake", bool(prefs.get("camera_shake", true)))
	return cf.save(prefs_path)


func apply_prefs() -> void:
	_sync_volume_alias()
	apply_bus_volumes()
	var fx := get_node_or_null("/root/Fx")
	if fx != null and "ally_intensity" in fx:
		fx.set("own_intensity", float(prefs.get("fx_own", 1.0)))
		fx.set("ally_intensity", float(prefs.get("fx_ally", 0.5)))
		fx.set("enemy_intensity", float(prefs.get("fx_enemy", 0.7)))
	prefs_changed.emit()


## Sets every audio bus of BUS_PREFS from its 0..1 pref (muted at 0). Missing buses are skipped.
func apply_bus_volumes() -> void:
	for bus: String in BUS_PREFS:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var v := clampf(float(prefs.get(BUS_PREFS[bus], 1.0)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)) + float(BUS_BASE_DB.get(bus, 0.0)))
		AudioServer.set_bus_mute(idx, v <= 0.001)


## Keeps the legacy "volume" key and "master_volume" equal: whichever changed since the last sync wins
## (old code/tests writing prefs["volume"] still change the master volume).
func _sync_volume_alias() -> void:
	var legacy := float(prefs.get("volume", _alias_master))
	if not is_equal_approx(legacy, _alias_master):
		prefs["master_volume"] = legacy
	prefs["volume"] = float(prefs.get("master_volume", legacy))
	_alias_master = float(prefs["master_volume"])


## CameraRig.mouse_sensitivity for the current preference.
func mouse_sensitivity() -> float:
	return 0.0025 * float(prefs["mouse_sensitivity"])


func local_name() -> String:
	var n := str(prefs.get("player_name", "")).strip_edges()
	if n != "":
		return n.left(24)
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("local_name"):
		return str(net.call("local_name")).left(24)
	return "Player"


func default_class() -> String:
	var want := str(prefs.get("class_id", ""))
	if _has_kit(want):
		return want
	var ids := _kit_ids()
	return ids[0] if not ids.is_empty() else ""


# ================================================================== registry helpers
func _registry() -> Node:
	return get_node_or_null("/root/Registry")


func _has_kit(id: String) -> bool:
	var r := _registry()
	return id != "" and r != null and bool(r.call("has_kit", id))


func _kit_ids() -> Array[String]:
	var out: Array[String] = []
	var r := _registry()
	if r != null:
		for id: Variant in r.call("kit_ids"):
			out.append(str(id))
	return out


func _kit_role(id: String) -> String:
	var r := _registry()
	if r == null:
		return ""
	var k: Variant = r.call("get_kit", id)
	return str(k.role) if k is ClassKit else ""


func class_label(id: String) -> String:
	var r := _registry()
	if r != null:
		var k: Variant = r.call("get_kit", id)
		if k is ClassKit:
			return "%s %s" % [(k as ClassKit).name_cn, (k as ClassKit).name_en]
	return id if id != "" else "未选择 None"


# ================================================================== roster queries
func is_host() -> bool:
	return multiplayer.is_server()


func my_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func in_lobby() -> bool:
	return state == State.LOBBY


func is_pvp() -> bool:
	return str(settings.get("mode", "duel")) != "raid"


func team_count() -> int:
	return 2 if is_pvp() else 1


func team_capacity(_team: int = 0) -> int:
	match str(settings.get("mode", "duel")):
		"duel":
			return 1
		"arena":
			return 3
		"team":
			return clampi(int(settings.get("team_size", 5)), 1, 5)
		"raid":
			return 5
	return 1


func team_slots(team: int) -> Array:
	var out: Array = []
	for s: Dictionary in roster:
		if int(s["team"]) == team:
			out.append(s)
	return out


func find_slot(slot_id: int) -> Dictionary:
	for s: Dictionary in roster:
		if int(s["slot"]) == slot_id:
			return s
	return {}


func slot_of_peer(peer: int) -> Dictionary:
	if peer == 0:
		return {}
	for s: Dictionary in roster:
		if int(s["peer"]) == peer:
			return s
	return {}


func my_slot() -> Dictionary:
	return slot_of_peer(my_peer())


func human_peers() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in roster:
		if int(s["peer"]) != 0:
			out.append(int(s["peer"]))
	return out


## "" when the host may start, else a bilingual reason.
func can_start() -> String:
	if not is_host():
		return "只有房主可以开始 Only the host can start"
	if state != State.LOBBY:
		return "不在房间中 Not in a lobby"
	for t in team_count():
		if team_slots(t).is_empty():
			return "队伍 %d 没有成员 Team %d is empty" % [t + 1, t + 1]
	for s: Dictionary in roster:
		var p := int(s["peer"])
		if p != 0 and p != 1 and not bool(s["ready"]):
			return "等待玩家准备 Waiting for players to ready up"
	return ""


# ================================================================== roster ops (requests)
## Public entry points; on clients they become requests the host validates.
func request(op: String, args: Array = []) -> void:
	if multiplayer.is_server():
		apply_op(my_peer(), op, args)
	else:
		_rpc_request.rpc_id(1, op, args)


func set_setting(key: String, value: Variant) -> void: request("set_setting", [key, value])
func add_bot(team: int) -> void: request("add_bot", [team])
func remove_slot(slot_id: int) -> void: request("remove_slot", [slot_id])
func set_slot_class(slot_id: int, class_id: String) -> void: request("set_class", [slot_id, class_id])
func swap_team(slot_id: int) -> void: request("swap_team", [slot_id])
func set_ready(ready: bool) -> void: request("set_ready", [ready])


func set_my_class(class_id: String) -> void:
	prefs["class_id"] = class_id
	var s := my_slot()
	if not s.is_empty():
		request("set_class", [int(s["slot"]), class_id])


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(op: String, args: Array) -> void:
	if not multiplayer.is_server():
		return
	apply_op(multiplayer.get_remote_sender_id(), op, args)


## Host: validates and applies one roster/settings operation from `sender`. Returns true if it changed state.
func apply_op(sender: int, op: String, args: Array) -> bool:
	if not multiplayer.is_server():
		return false
	var host := sender == my_peer()
	var ok := false
	match op:
		"hello":
			ok = _op_hello(sender, str(args[0]) if args.size() > 0 else "", str(args[1]) if args.size() > 1 else "")
		"set_setting":
			if host and state == State.LOBBY and args.size() == 2:
				ok = _op_setting(str(args[0]), args[1])
		"add_bot":
			if host and state == State.LOBBY and args.size() == 1:
				ok = not _add_bot_to(int(args[0])).is_empty()
		"remove_slot":
			if host and state == State.LOBBY and args.size() == 1:
				var s := find_slot(int(args[0]))
				if not s.is_empty() and int(s["peer"]) == 0:
					roster.erase(s)
					ok = true
		"set_class":
			if args.size() == 2 and state == State.LOBBY:
				var s := find_slot(int(args[0]))
				var cid := str(args[1])
				if not s.is_empty() and _has_kit(cid) and (int(s["peer"]) == sender or (host and int(s["peer"]) == 0)):
					s["class_id"] = cid
					ok = true
		"swap_team":
			if args.size() == 1 and state == State.LOBBY:
				var s := find_slot(int(args[0]))
				if not s.is_empty() and (int(s["peer"]) == sender or host):
					ok = _swap_team(s)
		"set_ready":
			var s := slot_of_peer(sender)
			if not s.is_empty() and args.size() == 1 and state == State.LOBBY:
				s["ready"] = bool(args[0])
				ok = true
		"set_name":
			var s := slot_of_peer(sender)
			if not s.is_empty() and args.size() == 1:
				var n := str(args[0]).strip_edges().left(24)
				if n != "":
					s["name"] = n
					ok = true
	if ok:
		broadcast()
	return ok


func _op_setting(key: String, value: Variant) -> bool:
	if not SETTING_KEYS.has(key):
		return false
	match key:
		"mode":
			var m := str(value)
			if not MODES.has(m):
				return false
			if not _fits_humans(m, int(settings.get("team_size", 5))):
				return false
			settings["mode"] = m
			_rebuild_roster()
			var net := get_node_or_null("/root/Net")
			if net != null and net.has_method("set_lobby_data"):
				net.call("set_lobby_data", "mode", m)
		"map_id", "raid_id":
			settings[key] = str(value)
		"bot_difficulty":
			settings[key] = clampi(int(value), 0, 3)
		"pvp_damage_scale":
			settings[key] = clampf(float(value), 0.25, 3.0)
		"round_time":
			settings[key] = clampi(int(value), 30, 900)
		"rounds_to_win":
			settings[key] = clampi(int(value), 1, 3)
		"team_size":
			var ts := clampi(int(value), 1, 5)
			if not _fits_humans(str(settings.get("mode", "duel")), ts):
				return false
			settings[key] = ts
			_rebuild_roster()
	return true


## True when every seated human still has a slot under `mode` / `team_size` (else tells the host why not).
func _fits_humans(mode: String, team_size: int) -> bool:
	var cap := 1
	match mode:
		"arena":
			cap = 3
		"team":
			cap = clampi(team_size, 1, 5)
		"raid":
			cap = 5
	var total := cap * (1 if mode == "raid" else 2)
	var humans := human_peers().size()
	if humans <= total:
		return true
	var msg := "玩家太多 Too many players (%d) for this mode (max %d)" % [humans, total]
	message.emit(msg)
	return false


func _op_hello(sender: int, pname: String, class_id: String) -> bool:
	pname = pname.strip_edges().left(24)
	if pname == "":
		pname = "Player %d" % sender
	var existing := slot_of_peer(sender)
	if not existing.is_empty():
		existing["name"] = pname
		if _has_kit(class_id):
			existing["class_id"] = class_id
		return true
	if state != State.LOBBY:
		if sender != my_peer():
			_reject(sender, "比赛进行中 Match in progress")
		return false
	if not _has_kit(class_id):
		class_id = default_class()
	var s := _place_human(sender, pname, class_id)
	if s.is_empty():
		if sender != my_peer():
			_reject(sender, "房间已满 Lobby is full")
		return false
	return true


func _reject(peer: int, reason: String) -> void:
	_rpc_rejected.rpc_id(peer, reason)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		var net := get_node_or_null("/root/Net")
		if net != null:
			net.call("kick", peer))


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	_reject_reason = reason
	pending_message = reason
	message.emit(reason)


## Puts a human into the team with the most free room (replacing a bot when full). {} if no room.
func _place_human(peer: int, pname: String, class_id: String) -> Dictionary:
	var best_team := -1
	var best_room := -999
	for t in team_count():
		var humans := 0
		for s: Dictionary in team_slots(t):
			if int(s["peer"]) != 0:
				humans += 1
		var room := team_capacity(t) - humans
		if room > best_room:
			best_room = room
			best_team = t
	if best_team < 0 or best_room <= 0:
		return {}
	var slots := team_slots(best_team)
	if slots.size() >= team_capacity(best_team):
		# Replace the last bot of that team.
		for i in range(slots.size() - 1, -1, -1):
			if int(slots[i]["peer"]) == 0:
				var b: Dictionary = slots[i]
				b["peer"] = peer
				b["name"] = pname
				b["class_id"] = class_id
				b["ready"] = false
				return b
		return {}
	var s := _new_slot(best_team, peer, pname, class_id)
	roster.append(s)
	_sort_roster()
	return s


func _new_slot(team: int, peer: int, pname: String, class_id: String) -> Dictionary:
	var s := {"slot": _next_slot, "team": team, "peer": peer, "name": pname, "class_id": class_id, "ready": peer == 1}
	_next_slot += 1
	return s


func _add_bot_to(team: int) -> Dictionary:
	if team < 0 or team >= team_count() or team_slots(team).size() >= team_capacity(team):
		return {}
	var n := 1
	var used: Array[String] = []
	for s: Dictionary in roster:
		used.append(str(s["name"]))
	while used.has(bot_name(n)):
		n += 1
	var s := _new_slot(team, 0, bot_name(n), _pick_bot_class(team))
	s["ready"] = true
	roster.append(s)
	_sort_roster()
	return s


static func bot_name(n: int) -> String:
	return "电脑%d Bot %d" % [n, n]


func _pick_bot_class(team: int) -> String:
	var ids := _kit_ids()
	if ids.is_empty():
		return ""
	if str(settings.get("mode", "")) == "raid":
		# Balanced party: tank, healer, then damage roles.
		var want: Array[String] = ["tank", "healer", "melee", "ranged", "control", "melee", "ranged"]
		var have: Array[String] = []
		for s: Dictionary in team_slots(team):
			have.append(_kit_role(str(s["class_id"])))
		for r: String in want:
			if have.has(r):
				have.erase(r)
				continue
			var cands: Array[String] = []
			for id: String in ids:
				if _kit_role(id) == r:
					cands.append(id)
			if not cands.is_empty():
				return cands[_rng.randi() % cands.size()]
			break
	return ids[_rng.randi() % ids.size()]


func _swap_team(s: Dictionary) -> bool:
	if team_count() < 2:
		return false
	var other := 1 - int(s["team"])
	var others := team_slots(other)
	if others.size() < team_capacity(other):
		s["team"] = other
		_sort_roster()
		return true
	for o: Dictionary in others:
		if int(o["peer"]) == 0:
			o["team"] = int(s["team"])
			s["team"] = other
			_sort_roster()
			return true
	return false


func _sort_roster() -> void:
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["team"]) != int(b["team"]):
			return int(a["team"]) < int(b["team"])
		var ah := 0 if int(a["peer"]) != 0 else 1
		var bh := 0 if int(b["peer"]) != 0 else 1
		if ah != bh:
			return ah < bh
		return int(a["slot"]) < int(b["slot"]))


## Re-seat humans for the current mode and fill the remaining capacity with bots.
func _rebuild_roster() -> void:
	var humans: Array = []
	for s: Dictionary in roster:
		if int(s["peer"]) != 0:
			humans.append(s)
	roster.clear()
	for h: Dictionary in humans:
		_place_human(int(h["peer"]), str(h["name"]), str(h["class_id"]))
		var ns := slot_of_peer(int(h["peer"]))
		if not ns.is_empty():
			ns["ready"] = bool(h["ready"])
	fill_bots()


func fill_bots() -> void:
	for t in team_count():
		while team_slots(t).size() < team_capacity(t):
			if _add_bot_to(t).is_empty():
				break


func get_state() -> Dictionary:
	return {"settings": settings.duplicate(true), "roster": roster.duplicate(true), "state": state}


func apply_state(st: Dictionary) -> void:
	if st.get("settings") is Dictionary:
		settings = (st["settings"] as Dictionary).duplicate(true)
	if st.get("roster") is Array:
		roster = (st["roster"] as Array).duplicate(true)
	roster_changed.emit()


## Host: push settings + roster to every client.
func broadcast() -> void:
	if not multiplayer.is_server():
		return
	roster_changed.emit()
	if _online():
		_rpc_sync.rpc(get_state())


@rpc("authority", "call_remote", "reliable")
func _rpc_sync(st: Dictionary) -> void:
	apply_state(st)
	if state == State.MENU:
		_set_state(State.LOBBY)
		_goto(MAIN_SCENE)


@rpc("authority", "call_remote", "reliable")
func _rpc_request_hello() -> void:
	_send_hello()


func _send_hello() -> void:
	_rpc_request.rpc_id(1, "hello", [local_name(), default_class()])


func _online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer)


func _set_state(s: int) -> void:
	if state != s:
		state = s
		state_changed.emit(s)


func _goto(path: String) -> void:
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path == path and path == MAIN_SCENE:
		return
	_change_to = path


# ================================================================== session flow
## Solo practice: offline lobby (same host code path).
func start_solo() -> void:
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("go_offline"):
		net.call("go_offline")
	else:
		_on_net_hosted("offline")


func host_steam() -> void:
	get_node("/root/Net").call("host_steam", "", 10, false)


func host_lan(port: int = 27777) -> Error:
	return get_node("/root/Net").call("host_enet", port)


func join_lan(address: String, port: int = 27777) -> Error:
	return get_node("/root/Net").call("join_enet", address, port)


func _on_net_hosted(_transport: String) -> void:
	roster.clear()
	_next_slot = 1
	last_result = {}
	settings["bot_difficulty"] = int(prefs.get("bot_difficulty", 1))
	_set_state(State.LOBBY)
	_place_human(my_peer(), local_name(), default_class())
	fill_bots()
	_set_refuse_connections(false)
	var net := get_node_or_null("/root/Net")
	if net != null and net.has_method("set_lobby_data"):
		net.call("set_lobby_data", "mode", str(settings.get("mode", "duel")))
	broadcast()
	_goto(MAIN_SCENE)


## Host: stop (or resume) accepting new transport peers - no joins while a match is loading/running.
func _set_refuse_connections(refuse: bool) -> void:
	if _online() and multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = refuse


func _on_net_connected() -> void:
	if state != State.MENU:
		# Joined another session (e.g. accepted a Steam invite) while still in a lobby/match: drop the old state.
		_back_to_menu()
	_reject_reason = ""
	_send_hello()


## Net is about to leave the current session to join another one (Steam invite, Browse, LAN join).
func _on_net_session_reset() -> void:
	_reject_reason = ""
	if state != State.MENU:
		_back_to_menu()


func _on_peer_joined(id: int) -> void:
	if multiplayer.is_server() and id != 1:
		_rpc_request_hello.rpc_id(id)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	var s := slot_of_peer(id)
	if s.is_empty():
		return
	if state == State.LOBBY:
		roster.erase(s)
		fill_bots()
	else:
		# Mid-match: their fighter becomes a bot.
		s["peer"] = 0
		s["ready"] = true
		s["name"] = str(s["name"]) + " (AI)"
		if match_scene != null and is_instance_valid(match_scene) and match_scene.has_method("on_peer_left"):
			match_scene.call("on_peer_left", id)
		_loaded.erase(id)
		if state == State.LOADING:
			_check_all_loaded()
	message.emit("%s 离开了 left" % str(s["name"]))
	broadcast()


func _on_net_failed(reason: String) -> void:
	pending_message = reason
	message.emit(reason)
	if state != State.MENU:
		_back_to_menu()


func _on_net_disconnected(reason: String) -> void:
	if _reject_reason != "":
		# The host kicked us after _rpc_rejected: show why instead of "Host disconnected".
		reason = _reject_reason
		_reject_reason = ""
	pending_message = reason
	message.emit(reason)
	_back_to_menu()


func _back_to_menu() -> void:
	roster.clear()
	match_scene = null
	_set_state(State.MENU)
	_goto(MAIN_SCENE)


## Leave the lobby/match and go back to the main menu (closes the network session).
func leave_session() -> void:
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.call("leave")
	_back_to_menu()


# ================================================================== match flow
## Host: everyone loads scenes/match.tscn; when all report ready the match begins.
func start_match() -> String:
	var why := can_start()
	if why != "":
		return why
	for s: Dictionary in roster:
		if not _has_kit(str(s["class_id"])):
			s["class_id"] = default_class() if int(s["peer"]) != 0 else _pick_bot_class(int(s["team"]))
	_ensure_map()
	_loaded.clear()
	_load_elapsed = 0.0
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.call("set_lobby_joinable", false)
	_set_refuse_connections(true)
	_rpc_load_match.rpc(settings.duplicate(true), roster.duplicate(true))
	return ""


## Host: make sure map_id (PvP) names a map the MAPS registry offers for this mode (MapRegistry.for_mode),
## else MapRegistry.default_id(mode); raid_id must be one of RaidRegistry.ids() (else the first one).
func _ensure_map() -> void:
	if not is_pvp():
		var rids := _script_call_array(RAID_REGISTRY, "ids", [])
		if not rids.is_empty() and not rids.has(str(settings.get("raid_id", ""))):
			settings["raid_id"] = str(rids[0])
		return
	var mode := str(settings.get("mode", "duel"))
	var id := str(settings.get("map_id", ""))
	var valid: Array[String] = []
	for d: Variant in _script_call_array(MAP_REGISTRY, "for_mode", [mode]):
		if d is Dictionary:
			valid.append(str((d as Dictionary).get("id", "")))
	if valid.is_empty() or valid.has(id):
		return
	var def := str(_script_call(MAP_REGISTRY, "default_id", [mode], ""))
	settings["map_id"] = def if valid.has(def) else valid[0]


## Calls a static method of a (possibly missing) registry script; `fallback` when absent.
func _script_call(path: String, method: String, args: Array, fallback: Variant) -> Variant:
	if not ResourceLoader.exists(path):
		return fallback
	var scr: Variant = load(path)
	if not (scr is Script):
		return fallback
	for md: Dictionary in (scr as Script).get_script_method_list():
		if str(md.get("name", "")) == method:
			return (scr as Script).callv(method, args)
	return fallback


func _script_call_array(path: String, method: String, args: Array) -> Array:
	var v: Variant = _script_call(path, method, args, [])
	return v as Array if v is Array else []


@rpc("authority", "call_local", "reliable")
func _rpc_load_match(p_settings: Dictionary, p_roster: Array) -> void:
	settings = p_settings
	roster = p_roster
	last_result = {}
	_set_state(State.LOADING)
	_change_to = MATCH_SCENE


## Called by modes/match_scene.gd once its World/map/mode exist on this peer.
func on_match_scene_ready(scene: Node) -> void:
	match_scene = scene
	if multiplayer.is_server():
		_mark_loaded(my_peer())
	else:
		_rpc_scene_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_scene_ready() -> void:
	if multiplayer.is_server():
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(peer: int) -> void:
	_loaded[peer] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if state != State.LOADING:
		return
	var connected: Array[int] = [my_peer()]
	for p: int in multiplayer.get_peers():
		connected.append(p)
	for p: int in human_peers():
		if connected.has(p) and not _loaded.has(p):
			return
	_begin_match_now()


func _begin_match_now() -> void:
	if state != State.LOADING:
		return
	if match_scene == null or not is_instance_valid(match_scene):
		return
	_set_state(State.MATCH)
	_rpc_match_started.rpc()
	match_scene.call("begin_match")


@rpc("authority", "call_remote", "reliable")
func _rpc_match_started() -> void:
	_set_state(State.MATCH)


## Called by match_scene on every peer when the mode emits match_ended.
func on_match_ended(result: Dictionary) -> void:
	last_result = result


## Host: back to the lobby for everyone (after results, or aborting a match).
func return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	# Ready flags reset for remote humans; humans that left mid-match stay as bots (drop the "(AI)" tag).
	for s: Dictionary in roster:
		s["ready"] = int(s["peer"]) == 1 or int(s["peer"]) == 0
		if int(s["peer"]) == 0:
			s["name"] = str(s["name"]).trim_suffix(" (AI)")
	var net := get_node_or_null("/root/Net")
	if net != null:
		net.call("set_lobby_joinable", true)
	_set_refuse_connections(false)
	_rpc_return_lobby.rpc(get_state())


@rpc("authority", "call_local", "reliable")
func _rpc_return_lobby(st: Dictionary) -> void:
	apply_state(st)
	match_scene = null
	_set_state(State.LOBBY)
	if multiplayer.is_server():
		_change_to = MAIN_SCENE
	else:
		# Clients keep the match scene a moment so the host's despawn packets for the freed fighters still
		# find their nodes (avoids "recv_nodes.has(net_id)" errors).
		get_tree().create_timer(CLIENT_LEAVE_DELAY).timeout.connect(func() -> void:
			if state == State.LOBBY:
				_change_to = MAIN_SCENE)
