extends "res://tests/test_core_base.gd"
## Integration: runs scenes/sandbox_core.tscn in real time (World.auto_step, MultiplayerSpawner, PlayerController
## reading the InputMap registered by Game) and drives it with synthetic Input actions.


func run_tests() -> void:
	suite_name = "sandbox"
	var scene: Node = (load("res://scenes/sandbox_core.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 10:
		await physics_frame
	var w := World.get_instance()
	check(w != null and w.auto_step, "sandbox World exists and auto-steps")
	var player: Fighter = scene.get("player")
	check(player != null and player.get_parent() == w.fighters_root, "player spawned through MultiplayerSpawner path")
	check(w.local_fighter() == player, "local_fighter resolves human player")
	var ctrl: PlayerController = scene.get("controller")
	ctrl.capture_mouse = false
	check(InputMap.has_action("skill_0") and InputMap.has_action("move_forward"), "Game registered InputMap actions")
	# Walk forward (camera faces player's yaw at start => -Z).
	var z0 := player.global_position.z
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.z < z0 - 1.0, "WASD moves player via PlayerController", "z %.2f -> %.2f" % [z0, player.global_position.z])
	# Lock on and attack the nearest dummy.
	Input.action_press("target_cycle")
	await physics_frame
	Input.action_release("target_cycle")
	for i in 3:
		await physics_frame
	check(player.target_uid != 0, "Tab locks on to an enemy")
	var casts: Array = []
	player.skill_cast.connect(func(_f: Fighter, s: int) -> void: casts.append(s))
	Input.action_press("skill_2")
	await physics_frame
	Input.action_release("skill_2")
	for i in 5:
		await physics_frame
	check(casts.has(2), "skill key press casts through InputMap -> input -> host", str(casts))
	# Dummies fight back.
	scene.set("_dummy_fight", true)
	var hp0 := player.hp
	var t := 0
	while t < 400 and player.hp >= hp0:
		await physics_frame
		t += 1
	check(player.hp < hp0, "fighting dummy damages the player (bot input path)")
	scene.queue_free()
	await process_frame
