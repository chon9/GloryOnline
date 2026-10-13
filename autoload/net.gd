extends Node
## Autoload "Net" (owner: NET) - transport layer only: Steam lobbies + SteamMultiplayerPeer (app 480 Spacewar)
## with ENet/LAN fallback and offline play (OfflineMultiplayerPeer, is_server() == true).
## Game (autoload/game.gd) owns roster/settings/scene flow and listens to the signals below.
## All Steam calls go through the `_steam` Object (dynamic calls) so the script still parses and runs when the
## GodotSteam extension is missing. Pass the user arg `--no-steam` to skip Steam init (tests, LAN only).

## Host is up and ready to accept players (Steam lobby created or ENet server listening).
signal hosted(transport: String)
## Client: transport connected to the host (multiplayer.connected_to_server).
signal connected
## Client: connecting/joining failed (bad address, Steam join refused, timeout...).
signal connection_failed(reason: String)
## Client: the host went away / we were dropped.
signal disconnected(reason: String)
## Steam lobby joined (host or client).
signal lobby_ready(lobby_id: int)
## Steam lobby search result: Array of {id, name, mode, members, max, owner}.
signal lobby_list_received(lobbies: Array)
## Steam lobby membership changed (someone entered/left).
signal lobby_members_changed
## Host: a transport peer connected / disconnected (multiplayer ids).
## About to drop the current session to join another (Steam invite / browse / LAN join). Game resets on it.
signal session_reset
signal peer_joined(id: int)
signal peer_left(id: int)

const APP_ID: int = 480
const GAME_KEY: String = "rongyao_arena"   # Spacewar 480 is shared by everyone: tag our lobbies
const GAME_VERSION: String = "1"
const ENET_PORT: int = 27777
const MAX_PLAYERS: int = 10
const CONNECT_TIMEOUT: float = 12.0

# GodotSteam enum values (verified, docs/research/godot-steam.md A5)
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
const LOBBY_TYPE_PUBLIC: int = 2
const LOBBY_COMPARISON_EQUAL: int = 0
const LOBBY_DISTANCE_WORLDWIDE: int = 3
const STEAM_RESULT_OK: int = 1
const CHAT_ENTER_SUCCESS: int = 1
const CHAT_ENTERED: int = 1
const CHAT_LEFT_MASK: int = 2 | 4 | 8 | 16

var steam_ok: bool = false
var steam_status: String = "Steam 未初始化 Not initialised"
var steam_id: int = 0
var persona_name: String = ""
var lobby_id: int = 0
## "offline" | "steam" | "enet"
var transport: String = "offline"
var enet_address: String = ""
var enet_port: int = ENET_PORT
## true while a client connection attempt is pending
var connecting: bool = false

var _steam: Object = null
var _connect_elapsed: float = 0.0
var _pending_lobby_name: String = ""
var _leaving: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if OS.get_cmdline_user_args().has("--no-steam"):
		steam_status = "Steam 已禁用 Disabled (--no-steam)"
	else:
		_init_steam()
		_check_launch_invite.call_deferred()


func _process(delta: float) -> void:
	if connecting:
		_connect_elapsed += delta
		if _connect_elapsed > CONNECT_TIMEOUT:
			connecting = false
			_fail("连接超时 Connection timed out")


# ================================================================== state helpers
func is_host() -> bool:
	return multiplayer.is_server()


## True when connected through a real network peer (not offline).
func is_online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer)


func my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func transport_label() -> String:
	match transport:
		"steam":
			return "Steam 大厅 Lobby %d" % lobby_id
		"enet":
			return "局域网 LAN %s:%d" % [enet_address if enet_address != "" else "*", enet_port]
	return "离线 Offline"


## Local player display name: Steam persona, else OS user, else "Player".
func local_name() -> String:
	if steam_ok and persona_name != "":
		return persona_name
	var u := OS.get_environment("USERNAME")
	if u == "":
		u = OS.get_environment("USER")
	return u if u != "" else "Player"


# ================================================================== Steam
func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		steam_status = "Steam 插件未加载 GodotSteam missing - LAN only"
		push_warning("Net: GodotSteam not loaded; LAN only")
		return
	_steam = Engine.get_singleton("Steam")
	var r: Variant = _steam.call("steamInitEx", APP_ID, true)
	var status := -1
	var verbal := ""
	if r is Dictionary:
		status = int((r as Dictionary).get("status", -1))
		verbal = str((r as Dictionary).get("verbal", ""))
	steam_ok = status == 0
	if not steam_ok:
		steam_status = "Steam 不可用 Unavailable (%d %s) - LAN only" % [status, verbal]
		push_warning("Net: Steam init failed (%d): %s - LAN only" % [status, verbal])
		return
	steam_id = int(_steam.call("getSteamID"))
	persona_name = str(_steam.call("getPersonaName"))
	steam_status = "Steam 已连接 Online: %s" % persona_name
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("lobby_match_list", _on_lobby_match_list)
	_steam.connect("lobby_chat_update", _on_lobby_chat_update)
	_steam.connect("join_requested", _on_join_requested)


func _check_launch_invite() -> void:
	# Accepting an invite while the game is closed launches it with "+connect_lobby <id>".
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if steam_ok and i >= 0 and i + 1 < args.size():
		join_lobby(int(args[i + 1]))


func steam_call(method: String, args: Array = []) -> Variant:
	if not steam_ok or _steam == null:
		return null
	return _steam.callv(method, args)


## Host a Steam lobby (falls back to ENet when Steam is unavailable).
func host_steam(lobby_name: String = "", max_players: int = MAX_PLAYERS, friends_only: bool = false) -> void:
	if not steam_ok:
		var e := host_enet()
		if e != OK:
			_fail("无法创建房间 Cannot host: %s" % error_string(e))
		return
	leave()
	_pending_lobby_name = lobby_name if lobby_name != "" else "%s 的房间 %s's arena" % [local_name(), local_name()]
	steam_call("createLobby", [LOBBY_TYPE_FRIENDS_ONLY if friends_only else LOBBY_TYPE_PUBLIC, max_players])


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		_fail("创建 Steam 大厅失败 Lobby creation failed (%d)" % result)
		return
	lobby_id = new_lobby_id
	steam_call("setLobbyJoinable", [lobby_id, true])
	steam_call("setLobbyData", [lobby_id, "game", GAME_KEY])
	steam_call("setLobbyData", [lobby_id, "ver", GAME_VERSION])
	steam_call("setLobbyData", [lobby_id, "name", _pending_lobby_name])
	steam_call("setLobbyData", [lobby_id, "mode", "duel"])
	var peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null:
		_fail("SteamMultiplayerPeer 不可用 unavailable")
		return
	var err: int = int(peer.call("host_with_lobby", lobby_id))
	if err != OK:
		_fail("host_with_lobby: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	steam_call("setRichPresence", ["status", "荣耀 Glory Arena lobby"])
	lobby_ready.emit(lobby_id)
	hosted.emit("steam")


## Request the list of our lobbies (result arrives through lobby_list_received).
func refresh_lobbies() -> void:
	if not steam_ok:
		lobby_list_received.emit([])
		return
	steam_call("addRequestLobbyListStringFilter", ["game", GAME_KEY, LOBBY_COMPARISON_EQUAL])
	steam_call("addRequestLobbyListDistanceFilter", [LOBBY_DISTANCE_WORLDWIDE])
	steam_call("addRequestLobbyListResultCountFilter", [50])
	steam_call("requestLobbyList")


func _on_lobby_match_list(lobbies: Array) -> void:
	var out: Array = []
	for v: Variant in lobbies:
		var id := int(v)
		out.append({
			"id": id,
			"name": str(steam_call("getLobbyData", [id, "name"])),
			"mode": str(steam_call("getLobbyData", [id, "mode"])),
			"members": int(steam_call("getNumLobbyMembers", [id])),
			"max": int(steam_call("getLobbyMemberLimit", [id])) if _steam.has_method("getLobbyMemberLimit") else MAX_PLAYERS,
			"owner": int(steam_call("getLobbyOwner", [id])),
		})
	lobby_list_received.emit(out)


func join_lobby(id: int) -> void:
	if not steam_ok:
		_fail("Steam 不可用 Steam unavailable")
		return
	session_reset.emit()
	leave()
	connecting = true
	_connect_elapsed = 0.0
	steam_call("joinLobby", [id])


func _on_lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != CHAT_ENTER_SUCCESS:
		connecting = false
		_fail("加入大厅失败 Join failed (response %d)" % response)
		return
	lobby_id = joined_id
	if int(steam_call("getLobbyOwner", [lobby_id])) == steam_id:
		return    # the creator also receives lobby_joined; already hosting
	var peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if peer == null:
		connecting = false
		_fail("SteamMultiplayerPeer 不可用 unavailable")
		return
	var err: int = int(peer.call("connect_to_lobby", lobby_id))
	if err != OK:
		connecting = false
		_fail("connect_to_lobby: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	lobby_ready.emit(lobby_id)


func _on_join_requested(requested_lobby: int, _friend_id: int) -> void:
	join_lobby(requested_lobby)


func _on_lobby_chat_update(_lobby: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	lobby_members_changed.emit()


func lobby_members() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not steam_ok or lobby_id == 0:
		return out
	for i in int(steam_call("getNumLobbyMembers", [lobby_id])):
		var sid := int(steam_call("getLobbyMemberByIndex", [lobby_id, i]))
		out.append({"steam_id": sid, "name": str(steam_call("getFriendPersonaName", [sid]))})
	return out


func set_lobby_data(key: String, value: String) -> void:
	if steam_ok and lobby_id != 0 and is_host():
		steam_call("setLobbyData", [lobby_id, key, value])


func set_lobby_joinable(joinable: bool) -> void:
	if steam_ok and lobby_id != 0 and is_host():
		steam_call("setLobbyJoinable", [lobby_id, joinable])


func invite_friends() -> bool:
	if steam_ok and lobby_id != 0:
		steam_call("activateGameOverlayInviteDialog", [lobby_id])
		return true
	return false


# ================================================================== ENet / LAN
func host_enet(port: int = ENET_PORT) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(port, MAX_PLAYERS)
	if e != OK:
		return e
	multiplayer.multiplayer_peer = p
	transport = "enet"
	enet_address = ""
	enet_port = port
	hosted.emit("enet")
	return OK


func join_enet(address: String = "127.0.0.1", port: int = ENET_PORT) -> Error:
	session_reset.emit()
	leave()
	if address.strip_edges() == "":
		address = "127.0.0.1"
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(address.strip_edges(), port)
	if e != OK:
		return e
	multiplayer.multiplayer_peer = p
	transport = "enet"
	enet_address = address
	enet_port = port
	connecting = true
	_connect_elapsed = 0.0
	return OK


## Offline play: same server code path (OfflineMultiplayerPeer, id 1).
func go_offline() -> void:
	leave()
	hosted.emit("offline")


## Close any session and fall back to OfflineMultiplayerPeer (null would leave NO peer, see research B6).
func leave() -> void:
	_leaving = true
	connecting = false
	var p := multiplayer.multiplayer_peer
	if p != null and not (p is OfflineMultiplayerPeer):
		p.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if steam_ok and lobby_id != 0:
		steam_call("leaveLobby", [lobby_id])
	lobby_id = 0
	transport = "offline"
	_leaving = false


## Host: drop one peer (lobby full, match running...).
func kick(peer_id: int) -> void:
	var p := multiplayer.multiplayer_peer
	if is_host() and p != null and not (p is OfflineMultiplayerPeer):
		p.disconnect_peer(peer_id)


# ================================================================== multiplayer signals
func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	connecting = false
	connected.emit()


func _on_connection_failed() -> void:
	connecting = false
	_fail("无法连接主机 Could not connect to host")


func _on_server_disconnected() -> void:
	if _leaving:
		return
	leave()
	disconnected.emit("主机已断开 Host disconnected")


func _fail(reason: String) -> void:
	push_warning("Net: " + reason)
	leave()
	connection_failed.emit(reason)
