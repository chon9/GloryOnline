extends SceneTree
## Two-process ENet test of the CORE replication contract (run one with `-- --role=host`, one with
## `-- --role=client`). Host spawns the client's fighter through World's MultiplayerSpawner; the client sends
## FighterInput via Fighter.submit_input RPC; Sync replicates position / hp / cooldowns back.

const PORT: int = 27931
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var role: String = "host"
var passed: int = 0
var failed: int = 0
var world: World


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
	_main.call_deferred()


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("PASS: [%s] %s" % [role, label])
	else:
		failed += 1
		print("FAIL: [%s] %s" % [role, label])


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	var reg := root.get_node_or_null("Registry")
	reg.call("register_kit", (load(KIT_PATH) as Script).new())
	_isolate_from_lobby()
	var mp := root.multiplayer
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 4) if role == "host" else peer.create_client("127.0.0.1", PORT)
	check(err == OK, "enet peer created")
	mp.multiplayer_peer = peer
	world = World.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CoreUtil.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	world.add_child(floor_body)
	if role == "host":
		await _host(mp)
	else:
		await _client(mp)
	print("CORE TESTS [net-%s]: %d passed, %d failed" % [role, passed, failed])
	print("CORE TESTS: %d passed, %d failed" % [passed, failed])
	mp.multiplayer_peer = OfflineMultiplayerPeer.new()
	quit(1 if failed > 0 else 0)


## This test drives the raw CORE replication path without a lobby: detach Game from Net's session signals so
## the NET hello/roster handshake does not reject + kick the test client (Game only accepts hellos in LOBBY).
func _isolate_from_lobby() -> void:
	var net := root.get_node_or_null("Net")
	var game := root.get_node_or_null("Game")
	if net == null or game == null:
		return
	for sig: Dictionary in net.get_signal_list():
		var sname := StringName(sig["name"])
		for c: Dictionary in net.get_signal_connection_list(sname):
			var cb: Callable = c["callable"]
			if cb.get_object() == game:
				net.disconnect(sname, cb)


func _host(mp: MultiplayerAPI) -> void:
	var client_id := 0
	var deadline := Time.get_ticks_msec() + 20000
	while client_id == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
		var peers := mp.get_peers()
		if not peers.is_empty():
			client_id = peers[0]
	check(client_id != 0, "client connected")
	if client_id == 0:
		return
	for i in 5:
		await physics_frame
	var pf := world.spawn_fighter({"kind": "player", "peer": client_id, "class_id": "test_dummy", "team": 0,
		"name": "Client", "pos": Vector3(0, 0, 0)})
	var dummy := world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": "test_dummy", "team": 1,
		"name": "Dummy", "pos": Vector3(0, 0, -8), "yaw": PI})
	check(pf != null and pf.get_parent() == world.fighters_root, "host spawned client fighter via spawner")
	var start_z := pf.global_position.z
	var casts: Array = []
	pf.skill_cast.connect(func(_f: Fighter, s: int) -> void: casts.append(s))
	var frames := 0
	while frames < 600 and not (casts.has(2) and dummy.hp < dummy.max_hp and pf.global_position.z < start_z - 1.0):
		await physics_frame
		frames += 1
	check(pf.global_position.z < start_z - 1.0, "host: remote input moved fighter")
	check(casts.has(2), "host: remote skill press cast skill 2")
	check(dummy.hp < dummy.max_hp, "host: remote projectile damaged dummy")
	# Spoof check: input from the host's own id must not drive the client's fighter.
	var z_before := pf.global_position.z
	pf.submit_input({"m": Vector2(0, 1), "p": 0, "i": 999})
	for i in 20:
		await physics_frame
	check(absf(pf.global_position.z - z_before) < 0.5, "host: submit_input from wrong sender ignored")
	# Let the client observe the replicated state before quitting.
	for i in 150:
		await physics_frame


func _client(mp: MultiplayerAPI) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while mp.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	check(mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "connected to host")
	var me: Fighter = null
	deadline = Time.get_ticks_msec() + 15000
	while me == null and Time.get_ticks_msec() < deadline:
		await physics_frame
		me = world.local_fighter()
	check(me != null, "client received its fighter via spawner")
	if me == null:
		return
	var dummy: Fighter = null
	while dummy == null and Time.get_ticks_msec() < deadline:
		for f: Fighter in world.fighters:
			if f != me:
				dummy = f
		if dummy == null:
			await physics_frame
	check(dummy != null and dummy.team == 1, "client received dummy fighter")
	if dummy == null:
		return
	var z0 := me.global_position.z
	var press_id := 0
	var frames := 0
	var saw_cd := false
	while frames < 600:
		await physics_frame
		frames += 1
		var inp := FighterInput.new()
		inp.aim_point = Vector3(0, 1, -8)
		if frames < 60:
			inp.move = Vector3(0, 0, -1)
		if frames >= 70 and frames < 73:
			if frames == 70:
				press_id += 1
			inp.press(2)
		inp.press_id = press_id
		me.submit_input.rpc_id(1, inp.to_dict())
		if me.cooldowns_packed.size() > 2 and me.cooldowns_packed[2] > 0.0:
			saw_cd = true
		if frames > 120 and saw_cd and dummy.hp < dummy.max_hp and me.global_position.z < z0 - 1.0:
			break
	check(me.global_position.z < z0 - 1.0, "client: replicated position moved")
	check(saw_cd, "client: replicated cooldowns_packed")
	check(dummy.hp < dummy.max_hp, "client: replicated dummy hp dropped")
	check(me.visual != null, "client: fighter visual created")
	# wave3: smoothing + replicated counters.
	check(not me._snaps.is_empty(), "client: position snapshots buffered (interpolation active)")
	check(me.position.distance_to(me.latest_net_position()) < 2.0, "client: interpolated position tracks the newest snapshot")
	for i in 40:
		await physics_frame
	check(dummy.last_attacker_uid == me.uid, "client: replicated last_attacker_uid")
	check(me.damage_dealt > 0.0 and me.net_damage_dealt > 0, "client: replicated damage_dealt mirror (%.0f)" % me.damage_dealt)
