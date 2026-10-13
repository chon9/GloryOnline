# Godot 4.7.2 + GodotSteam 4.23.1: technical reference (RONGYAO)

All findings come from probes run on this machine with `Godot_v4.7.2-stable_win64_console.exe --headless`. Steam was running and logged in. Items marked **[VERIFIED]** were executed or parse-checked. Items marked **[UNVERIFIED]** come from documentation or memory and were not executed. I deleted all my probe files (`tools/probe_ref_*`) and their `.uid` files, then re-ran `--import` to purge the cache. The file `tools/probe_steam.gd`/`.uid` was already there before I started, so I did not touch it.

---

## A. GodotSteam 4.23.1

### A1. Accessing the singleton [VERIFIED]
- `Engine.has_singleton("Steam") == true`, `ClassDB.class_exists("Steam") == true`.
- Use the global identifier `Steam` directly: `Steam == Engine.get_singleton("Steam")` returns true. No `Engine.get_singleton` call is needed.
- `Steam.get_godotsteam_version()` returns `"4.23.1"`.

### A2. Init [VERIFIED]
```
steamInitEx(app_id: int = 0, embed_callbacks: bool = false) -> Dictionary
steamInit(app_id: int = 0, embed_callbacks: bool = false) -> bool
run_callbacks() -> void
steamShutdown() -> void
isSteamRunning() -> bool
loggedOn() -> bool
getSteamID() -> int
getPersonaName() -> String
getFriendPersonaName(steam_id: int) -> String
```
- The return value is `{"status": int, "verbal": String}`. On success it is `{ "status": 0, "verbal": "" }`. The call took about 234 ms.
- Status constants:
  - `STEAM_API_INIT_RESULT_OK=0`
  - `STEAM_API_INIT_RESULT_FAILED_GENERIC=1`
  - `STEAM_API_INIT_RESULT_NO_STEAM_CLIENT=2`
  - `STEAM_API_INIT_RESULT_VERSION_MISMATCH=3`
- **`embed_callbacks=true`** makes GodotSteam call `run_callbacks()` every frame itself. With `false`, you must call `Steam.run_callbacks()` in `_process`.
- **Gotcha:** if you call `steamInitEx(480, true)` from `SceneTree._init()` (before a tree exists), it logs `ERROR: SceneTree is not present, cannot connect Steam callbacks internally.` Init itself still succeeds. Call it from an autoload's `_ready()` (or `SceneTree._initialize()`), which works.
- Project settings that the addon registers (all currently at defaults):
  - `steam/initialization/app_data/app_id=0`
  - `steam/initialization/processes/initialize_on_startup=false`
  - `steam/initialization/processes/embed_callbacks=false`
  - `steam/multiplayer_peer/max_channels=4`
  - `steam/settings/enable_debug=false`

  Initializing manually from an autoload (below) is the recommended route.
- **Steam not running [UNVERIFIED, I could not stop your Steam]:** documentation says `steamInitEx` returns `status=2` (NO_STEAM_CLIENT) with a text in `verbal`. Treat any `status != 0` as "LAN/ENet only". Do not call other Steam APIs afterwards. Gate every call on a `steam_ok` flag, as in the manager below.

### A3. Lobby API: exact signatures [VERIFIED via ClassDB]
```
createLobby(lobby_type: Steam.LobbyType, max_members: int = 2) -> void
joinLobby(steam_lobby_id: int) -> void
leaveLobby(steam_lobby_id: int) -> void
requestLobbyList() -> void
addRequestLobbyListStringFilter(key_to_match: String, value_to_match: String, comparison_type: Steam.LobbyComparison) -> void
addRequestLobbyListDistanceFilter(distance_filter: Steam.LobbyDistanceFilter) -> void
addRequestLobbyListResultCountFilter(max_results: int) -> void
setLobbyData(steam_lobby_id: int, key: String, value: String) -> bool
getLobbyData(steam_lobby_id: int, key: String) -> String
setLobbyMemberData(steam_lobby_id: int, key: String, value: String) -> void
getLobbyMemberData(steam_lobby_id: int, steam_id_user: int, key: String) -> String
getNumLobbyMembers(steam_lobby_id: int) -> int
getLobbyMemberByIndex(steam_lobby_id: int, member: int) -> int
getLobbyOwner(steam_lobby_id: int) -> int
setLobbyJoinable(steam_lobby_id: int, joinable: bool) -> bool
setLobbyType(steam_lobby_id: int, lobby_type: Steam.LobbyType) -> bool
inviteUserToLobby(steam_lobby_id: int, steam_id_invitee: int) -> bool
sendLobbyChatMsg(steam_lobby_id: int, message_body: String) -> bool
activateGameOverlayInviteDialog(lobby_id: int) -> void
setRichPresence(key: String, value: String) -> bool
```

### A4. Signals [VERIFIED]
```
lobby_created(connect: int, lobby_id: int)                 # connect == Steam.RESULT_OK (1) on success
lobby_joined(lobby: int, permissions: int, locked: bool, response: int)   # response == CHAT_ROOM_ENTER_RESPONSE_SUCCESS (1)
lobby_match_list(lobbies: Array)                           # Array of int lobby ids
lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int)
lobby_data_update(success: int, lobby_id: int, member_id: int)
lobby_message(lobby_id: int, user: int, message: String, chat_type: int)
lobby_invite(inviter: int, lobby: int, game: int)
join_requested(lobby_id: int, steam_id: int)               # friend clicked "Join game"
join_game_requested(user: int, connect: String)
persona_state_change(steam_id: int, flags: int)
```

### A5. Constants [VERIFIED]
- **Lobby type:** `LOBBY_TYPE_PRIVATE=0`, `FRIENDS_ONLY=1`, `PUBLIC=2`, `INVISIBLE=3`, `PRIVATE_UNIQUE=4`
- **Comparison:** `LOBBY_COMPARISON_EQUAL_TO_OR_LESS_THAN=-2`, `LESS_THAN=-1`, `EQUAL=0`, `GREATER_THAN=1`, `EQUAL_TO_GREATER_THAN=2`, `NOT_EQUAL=3`
- **Distance:** `LOBBY_DISTANCE_FILTER_CLOSE=0`, `DEFAULT=1`, `FAR=2`, `WORLDWIDE=3`
- **Chat member state (bit flags):** `CHAT_MEMBER_STATE_CHANGE_ENTERED=1`, `LEFT=2`, `DISCONNECTED=4`, `KICKED=8`, `BANNED=16`
- **Other:** `RESULT_OK=1`, `CHAT_ROOM_ENTER_RESPONSE_SUCCESS=1`

### A6. SteamMultiplayerPeer [VERIFIED]
The parent class is `MultiplayerPeerExtension`. It has no signals of its own; use `multiplayer.peer_connected` and related signals.
```
host_with_lobby(lobby_id: int) -> Error
connect_to_lobby(lobby_id: int) -> Error
create_host(virtual_port: int = 0) -> Error
create_client(steam_id: int, virtual_port: int = 0) -> Error
add_peer(steam_id: int, virtual_port: int = 0) -> Error
get_peer(peer_id: int) -> Object
get_steam_id_for_peer_id(peer_id: int) -> int
get_peer_id_for_steam_id(steam_id: int) -> int
props: no_delay: bool, no_nagle: bool, server_relay: bool, debug_level: DebugLevel (DEBUG_LEVEL_NONE=0, PEER=1, STEAM=2)
```

**Order of events, verified live on app 480:**
1. `createLobby(PUBLIC, 6)` fires `lobby_created(1, id)`.
2. Inside that handler:
   - `host_with_lobby(id)` returns `OK`.
   - After assigning the peer, `multiplayer.is_server()` is true, `get_unique_id()` is 1, the status is CONNECTED, and `get_steam_id_for_peer_id(1)` returns your own Steam ID.
3. The creator **also** receives `lobby_joined(id, 0, false, 1)` afterwards, so skip `connect_to_lobby` when `getLobbyOwner(id) == getSteamID()`.

**Lobby list:** `requestLobbyList()` with a string filter found the lobby when the query was sent from `lobby_joined` or 2 s after creation. Sent directly inside `lobby_created`, it returned 0 results, so lobby data needs a moment to propagate.

**Choosing a flow:**
- `host_with_lobby` / `connect_to_lobby` is the lobby-driven flow; use this one.
- `create_host` / `create_client(host_steam_id)` is the raw P2P alternative, where you exchange the host Steam ID yourself.

**[UNVERIFIED] known limitation:** two instances on one PC under one Steam account cannot connect to each other through Steam. Use ENet for local tests.

### A7. Net manager autoload (parse-checked AND run live: steam_ok, lobby_ready, member list, lobby list found, leave) [VERIFIED]
```gdscript
extends Node
## Autoload "Net" — Steam lobby + SteamMultiplayerPeer with ENet fallback.
signal lobby_ready(lobby_id: int)
signal lobby_list_received(lobbies: Array)

const APP_ID := 480
const GAME_KEY := "rongyao_arena"      # tag our lobbies (Spacewar 480 is shared by everyone)
const ENET_PORT := 27777

var steam_ok := false
var steam_id := 0
var lobby_id := 0

func _ready() -> void:
	_init_steam()
	_check_launch_invite()

func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		push_warning("GodotSteam not loaded; LAN only"); return
	var r: Dictionary = Steam.steamInitEx(APP_ID, true)   # true = auto run_callbacks
	steam_ok = r.get("status", -1) == Steam.STEAM_API_INIT_RESULT_OK
	if not steam_ok:
		push_warning("Steam init failed (%s): %s — LAN only" % [r.get("status"), r.get("verbal")]); return
	steam_id = Steam.getSteamID()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(func(l: Array): lobby_list_received.emit(l))
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.join_requested.connect(_on_join_requested)

func _check_launch_invite() -> void:
	# [UNVERIFIED convention] accepting an invite while game closed launches with "+connect_lobby <id>"
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if steam_ok and i >= 0 and i + 1 < args.size():
		join_lobby(int(args[i + 1]))

func host_lobby(max_players: int = 10) -> void:
	if steam_ok: Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)
	else: host_enet()

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("createLobby failed: %d" % result); return
	lobby_id = new_lobby_id
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "game", GAME_KEY)
	Steam.setLobbyData(lobby_id, "name", "%s's arena" % Steam.getPersonaName())
	var peer := SteamMultiplayerPeer.new()
	var err := peer.host_with_lobby(lobby_id)
	if err != OK:
		push_error("host_with_lobby: %s" % error_string(err)); return
	multiplayer.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)

func refresh_lobbies() -> void:
	Steam.addRequestLobbyListStringFilter("game", GAME_KEY, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()

func join_lobby(id: int) -> void:
	Steam.joinLobby(id)

func _on_lobby_joined(joined_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("joinLobby failed, response=%d" % response); return
	lobby_id = joined_id
	if Steam.getLobbyOwner(lobby_id) == steam_id:
		return    # creator also gets lobby_joined; already hosting
	var peer := SteamMultiplayerPeer.new()
	var err := peer.connect_to_lobby(lobby_id)
	if err != OK:
		push_error("connect_to_lobby: %s" % error_string(err)); return
	multiplayer.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)

func _on_join_requested(requested_lobby: int, _friend_id: int) -> void:
	join_lobby(requested_lobby)

func _on_lobby_chat_update(_lobby: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	var who := Steam.getFriendPersonaName(changed_id)
	if chat_state & Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED: print(who, " joined")
	elif chat_state & (Steam.CHAT_MEMBER_STATE_CHANGE_LEFT | Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED): print(who, " left")

func lobby_members() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in Steam.getNumLobbyMembers(lobby_id):
		var sid := Steam.getLobbyMemberByIndex(lobby_id, i)
		out.append({"steam_id": sid, "name": Steam.getFriendPersonaName(sid)})
	return out

func invite_friends() -> void:
	if steam_ok and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()   # see B6: null leaves NO peer
	if steam_ok and lobby_id != 0:
		Steam.leaveLobby(lobby_id)
	lobby_id = 0

func host_enet(port: int = ENET_PORT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var e := p.create_server(port, 10)
	if e == OK: multiplayer.multiplayer_peer = p
	return e

func join_enet(address: String = "127.0.0.1", port: int = ENET_PORT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var e := p.create_client(address, port)
	if e == OK: multiplayer.multiplayer_peer = p
	return e
```
(The verified run used `= null` in `leave()`. The `OfflineMultiplayerPeer` line is the fix suggested by B6.)

**Harmless console noise:** Steam prints `Setting breakpad minidump AppID = 480` on stderr. It also sometimes prints `steamnetworkingsockets ... waited 111ms for lock` assertions, which are harmless.

---

## B. High-level multiplayer (Godot 4.7.2)

### B1. API surface [VERIFIED via ClassDB]
**`ENetMultiplayerPeer`**
- `create_server(port, max_clients=32, max_channels=0, in_bw=0, out_bw=0)`
- `create_client(address, port, channel_count=0, in_bw=0, out_bw=0, local_port=0)`

**`MultiplayerAPI`**
- Signals: `peer_connected(id)`, `peer_disconnected(id)`, `connected_to_server()`, `connection_failed()`, `server_disconnected()`.
- Methods: `get_unique_id()`, `is_server()`, `get_remote_sender_id()`, `get_peers()`.

**`SceneMultiplayer` properties**
- `root_path`, `auth_callback`, `auth_timeout`, `allow_object_decoding`, `refuse_new_connections`, `server_relay`, `max_sync_packet_size`, `max_delta_packet_size`.

**`Node`**
- `set_multiplayer_authority(id, recursive=true)`, `get_multiplayer_authority()`, `is_multiplayer_authority()`.
- `rpc(method, ...)`, `rpc_id(peer, method, ...)`, `rpc_config(method, config)`.

**`MultiplayerSpawner`**
- Properties: `spawn_path`, `spawn_limit`, `spawn_function` (Callable), `_spawnable_scenes`.
- Methods: `add_spawnable_scene(path)`, `clear_spawnable_scenes()`, `spawn(data=null) -> Node`.
- Signals: `spawned(node)`, `despawned(node)`.

**`MultiplayerSynchronizer`**
- Properties: `root_path` (default `..`), `replication_interval`, `delta_interval`, `replication_config`, `visibility_update_mode` (`VISIBILITY_PROCESS_IDLE`/`PHYSICS`/`NONE`), `public_visibility`.
- Methods: `set_visibility_for(peer, bool)`, `add_visibility_filter(Callable)`, `update_visibility(for_peer=0)`.
- Signals: `synchronized`, `delta_synchronized`, `visibility_changed`.

**`SceneReplicationConfig`**
- Methods: `add_property(path, index=-1)`, `remove_property`, `has_property`, `get_properties`, `property_set_replication_mode(path, mode)`, `property_set_spawn(path, bool)`, `property_set_sync`, `property_set_watch`.
- Modes: `REPLICATION_MODE_NEVER=0`, `ALWAYS=1`, `ON_CHANGE=2`.

### B2. @rpc syntax
Write it as `@rpc(<mode>, <sync>, <transfer_mode>, <channel:int>)`. The arguments can come in any order, and all are optional.
- **mode:** `"authority"` (default) or `"any_peer"`
- **sync:** `"call_remote"` (default) or `"call_local"`
- **transfer:** `"unreliable"`, `"unreliable_ordered"`, or `"reliable"` (default)
- **channel:** an int, default 0

Call it as `func_name.rpc(args)` or `func_name.rpc_id(peer_id, args)`. RPCs on inner classes work. Node paths, and therefore node names, must be identical on all peers.

### B3. Host-authoritative pattern [VERIFIED: 2 headless ENet processes, host and client on 127.0.0.1]
- The client sent `submit_input` every physics frame.
- The host moved the player, and position replicated identically on both sides (2.67 → 17.67).
- The `request_skill` RPC ran on the host, hp changed 100→90 and replicated, and the FX RPC fired on both peers.
```gdscript
class Player extends Node3D:          # in a real project: player.gd with class_name
	var owner_peer: int = 0
	var hp: int = 100
	var move_input := Vector3.ZERO

	@rpc("any_peer", "call_local", "unreliable_ordered")     # client -> host, every frame
	func submit_input(dir: Vector3) -> void:
		if not multiplayer.is_server(): return
		if multiplayer.get_remote_sender_id() != owner_peer: return   # anti-spoof
		move_input = dir.limit_length(1.0)

	@rpc("any_peer", "call_local", "reliable")               # client -> host, must arrive
	func request_skill(skill_id: StringName) -> void:
		if not multiplayer.is_server(): return
		if multiplayer.get_remote_sender_id() != owner_peer: return
		hp -= 10                                             # host validates cooldown/mana, applies
		play_skill_fx.rpc(skill_id)

	@rpc("authority", "call_local", "reliable")              # host -> all, cosmetic
	func play_skill_fx(skill_id: StringName) -> void:
		pass

	func _physics_process(delta: float) -> void:
		if multiplayer.is_server():
			position += move_input * 5.0 * delta

# Spawn function: runs on EVERY peer when host calls spawner.spawn(data)
func _make_player(data: Variant) -> Node:
	var peer_id: int = data
	var p := Player.new()
	p.name = str(peer_id)               # must be deterministic
	p.owner_peer = peer_id
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))   # relative to sync.root_path ("..")
	cfg.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	cfg.add_property(NodePath(".:hp"))
	cfg.property_set_replication_mode(NodePath(".:hp"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg       # set BEFORE node enters tree
	p.add_child(sync)
	return p

# Setup (identical tree on host and clients): World/Players + World/Spawner
spawner.spawn_path = spawner.get_path_to(players)
spawner.spawn_function = _make_player
# host only:
multiplayer.peer_connected.connect(func(id): spawner.spawn(id))
multiplayer.peer_disconnected.connect(func(id):
	var n := players.get_node_or_null(str(id))
	if n: n.queue_free())               # spawner auto-despawns on clients
spawner.spawn(1)                         # host's own player — only once spawner is inside tree
# client, each physics frame:
var me := players.get_node_or_null(str(multiplayer.get_unique_id())) as Player
if me: me.submit_input.rpc_id(1, dir)
```
**Rules:**
- The synchronizer authority stays 1 (the host), so state flows host to clients.
- Keep `set_multiplayer_authority(peer)` for client-predicted things only, such as a camera or input node.
- For AI and NPC bosses in a PvE raid, spawn them with the same spawner from the host and simulate them only where `multiplayer.is_server()` is true.

### B4. Running 2 local instances [VERIFIED]
Run these from PowerShell:
```powershell
& "K:/Godot_v4.7.2-stable_win64_console.exe" --path K:/Project/RONGYAO -- --role=host
& "K:/Godot_v4.7.2-stable_win64_console.exe" --path K:/Project/RONGYAO -- --role=client
```
Read the role with `OS.get_cmdline_user_args()` (verified: it returns `["--role=host"]`). In the editor, Debug > Customize Run Instances does the same.

### B5. Gotchas found [VERIFIED]
- In `SceneTree._initialize()`, `root.multiplayer` was **null**, so use `get_multiplayer()`. Also, `spawner.spawn()` failed there with `!is_inside_tree() || !has_multiplayer_peer() || !is_multiplayer_authority()`, because the children had not entered the tree yet. Call `spawn` after `_ready` or deferred.
- Only the host may call `spawner.spawn()`.

### B6. Peer reset [VERIFIED]
- The default peer is an `OfflineMultiplayerPeer`, where `is_server()` is true and the id is 1. Offline solo PvE can therefore use the same server code paths.
- Setting `multiplayer.multiplayer_peer = null` leaves **no** peer (`has_multiplayer_peer()` returns false). `get_unique_id()` then errors with `No multiplayer peer is assigned`.
- After leaving, assign `OfflineMultiplayerPeer.new()` instead of null.

---

## C. Godot 4.4 → 4.7 changes for GDScript authors

### C1. Language features (all parse and run in 4.7.2) [VERIFIED]
- **Typed dictionaries:** `var cds: Dictionary[StringName, float]`. `@export var t: Dictionary[StringName, int]` also works. Use `get_typed_key_builtin()` / `get_typed_value_builtin()`. Added in 4.4.
- **Abstract classes and methods:** `@abstract class Skill:` and `@abstract func cast(c: Node3D) -> void` (no body). Added in 4.5.
- **Variadic functions:** `func f(first: int, ...rest: Array)`. Added in 4.5.
- **Export annotations:** `@export_tool_button("Label", "Icon") var b := _callable` (needs `@tool`), `@export_storage`, `@export_custom(hint, "hint_string")`, `@export_file("*.glb")`, `@export_flags(...)`.
- **Warning regions:** `@warning_ignore_start("x")` … `@warning_ignore_restore("x")`.
- **`.uid` sidecar files:** since 4.4, every script gets a `.uid` (`*.gd.uid` files exist here). Commit them, and move or delete them together with their scripts. `preload("uid://...")` works, and the addon itself uses it.

### C2. Physics [VERIFIED]
- `physics/3d/physics_engine` options are `DEFAULT`, `Jolt Physics`, `GodotPhysics3D`, `Dummy`. **This project has `DEFAULT`, which resolved to GodotPhysics3D:** the leaked RIDs were of type `GodotBody3D`.
- A scratch project with `3d/physics_engine="Jolt Physics"` produced `JoltBody3D` and Jolt warnings.
- **To use Jolt, add this to `project.godot`:**
  ```
  [physics]
  3d/physics_engine="Jolt Physics"
  ```
- Jolt ignores some joint parameters, such as pin and hinge `bias`, and warns about them.
- `JoltPhysicsServer3D` is not an exposed class.

### C3. Classes present in 4.7.2 [VERIFIED exist; version-of-introduction UNVERIFIED]
- **Skeleton modifiers:** `SkeletonModifier3D`, `RetargetModifier3D` (properties `profile`, `use_global_pose`, `enable`), `LookAtModifier3D`, `SpringBoneSimulator3D`, `ModifierBoneTarget3D`, `CopyTransformModifier3D`, `AimModifier3D`, `ConvertTransformModifier3D`, `IKModifier3D`, `TwoBoneIK3D`, `ChainIK3D`, `BoneTwistDisperser3D`.
- **Retargeting and animation:** `BoneMap`, `SkeletonProfileHumanoid`, `AnimationMixer`, `AnimationTree`, `AnimationNodeStateMachine`.
- **Navigation:** `NavigationAgent3D`, `NavigationRegion3D`, `NavigationMeshSourceGeometryData3D`.
- **Other:** `VirtualJoystick`, `FoldableContainer`, `Logger`.

### C4. AnimationMixer / Player [VERIFIED]
- **`AnimationMixer`** is the base class of AnimationPlayer and AnimationTree.
  - Methods: `add_animation_library(name, lib)`, `get_animation_library`, `get_animation_library_list`, `has_animation`, `get_animation`.
  - Properties: `root_node`, `root_motion_track`, `root_motion_local`, `deterministic`, `callback_mode_process`, `callback_mode_method`, `callback_mode_discrete`, `active`, `audio_max_polyphony`.
- **`AnimationPlayer`**
  - `play(name="", custom_blend=-1, custom_speed=1.0, from_end=false)`
  - `play_section(name, start, end, blend, speed, from_end)`
  - `play_with_capture(name, duration, blend, speed, from_end, trans, ease)`
  - `queue(name)`
- **Sharing animations across models (verified at runtime):**
  ```gdscript
  var lib := AnimationLibrary.new()
  lib.add_animation(&"idle", anim)                     # -> OK
  anim_player.add_animation_library(&"shared", lib)    # -> OK
  anim_player.has_animation(&"shared/idle")            # true; play("shared/idle")
  ```
- **Separate animation-library GLB [UNVERIFIED editor workflow, not run headless]:**
  1. Import the animations-only `.glb`.
  2. In Advanced Import Settings, set Import As to "Animation Library", which saves a `.res`/`.tres` AnimationLibrary.
  3. Give every character model (Mixamo-style or VRM-like humanoids) a `BoneMap` with `SkeletonProfileHumanoid` at import (Skeleton3D > Retarget > Bone Map). Optionally enable "Rename bones" and "Unique node > Make unique" with skeleton name `GeneralSkeleton`.

  Once all models share the same bone names and paths (`%GeneralSkeleton:Hips` and so on), one library plays on all of them. `RetargetModifier3D` is the runtime alternative for differing rest poses.
- **Track path format:** `NodePath("Skeleton3D:Hips")`, i.e. `"<skeleton node path>:<bone>"`.

### C5. BoneAttachment3D for weapons [VERIFIED properties]
- Properties: `bone_name: StringName`, `bone_idx`, `override_pose`, `use_external_skeleton`, `external_skeleton: NodePath`.
- Usage: make it a child of the `Skeleton3D` (or set `external_skeleton`), set `bone_name = &"RightHand"`, and put the weapon mesh under it.

### C6. Runtime glTF [VERIFIED API]
- `GLTFDocument.append_from_file(path, state: GLTFState, flags=0, base_path="") -> Error`
- `GLTFDocument.generate_scene(state, bake_fps=30, trimming=false, remove_immutable_tracks=true)`

### C7. Renderer defaults [VERIFIED]
- The renderer is `forward_plus`. In headless mode the display driver is `headless`.

---

## D. Gotchas

### D1. Headless + GodotSteam [VERIFIED]
- The extension loads headless, and `steamInitEx` succeeds headless whenever the Steam client is running.
- Lobby create, join, list and `host_with_lobby` all worked headless.
- The failure mode without Steam is a non-zero `status` (see A2, unverified). No crash was observed in the code paths I ran.
- Calling with `embed_callbacks=true` before a SceneTree exists only logs an error.

### D2. Autoload order [VERIFIED in scratch project]
- Autoloads are instantiated in `[autoload]` order and added to root before the main scene. The root children were `[Net, Game, Main]`.
- When `Net._ready` runs, the next autoload, `/root/Game`, already exists as a node.
- Autoload global names (for example `Net`) resolve from `project.godot` without any cache refresh.
- Put the Steam/Net autoload first.

### D3. class_name cache [VERIFIED]
- A new `class_name X` script is **not** visible to `-s` or `--check-only` runs until `.godot/global_script_class_cache.cfg` is refreshed. Until then you get `Parse Error: Identifier "X" not declared in the current scope.`
- To refresh it headlessly (about 4 s, exit 0):
  ```
  & "K:/Godot_v4.7.2-stable_win64_console.exe" --headless --path K:/Project/RONGYAO --import
  ```
  This rescans files, registers global classes and generates `.uid` files. Run it again after deleting or renaming class_name scripts.

### D4. Parse check [VERIFIED]
```
& "K:/Godot_v4.7.2-stable_win64_console.exe" --headless --path K:/Project/RONGYAO --check-only -s res://path/script.gd
```
It exits 1 on a parse error and 0 when clean. Non-MainLoop scripts (`extends Node`) can be checked this way too.

### D5. Smoke test a scene [VERIFIED]
```
& "K:/Godot_v4.7.2-stable_win64_console.exe" --headless --path K:/Project/RONGYAO --quit-after 120 res://scenes/arena.tscn 2>&1
```
Omit the scene argument to run `run/main_scene`. **The exit code is 0 even when runtime `SCRIPT ERROR`s occur**, so a CI or agent check must scan the output for `SCRIPT ERROR` or `ERROR:`:
```powershell
$out = & "K:/Godot_v4.7.2-stable_win64_console.exe" --headless --path K:/Project/RONGYAO --quit-after 120 2>&1 | Out-String
if ($out -match "SCRIPT ERROR|Parse Error|ERROR:") { "FAIL"; $out } else { "PASS" }
```
- Two kinds of `ERROR:` lines appear at exit and should be filtered out:
  - Leaked-RID and ObjectDB-leak warnings when quitting abruptly.
  - Steam's breakpad lines on stderr.
- A `SceneTree` script must return `true` from `_process`/`_physics_process`, or call `quit()`, to exit.
- For network tests, start both processes with `Start-Process -PassThru` and stdout/stderr redirected to files. Then `WaitForExit`, and `Kill()` any process left running. I did that, and no Godot processes remain.