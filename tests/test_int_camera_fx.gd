extends SceneTree
## Integration checks (art migration): Fx ownership intensity + prefs, impact_fired hook, CameraRig arm probe
## (solid walls pull it in, invisible "Bound*" walls and slender props do not), shake / FOV punch decay.
## Run: godot --headless --path K:/Project/RONGYAO -s res://tests/test_int_camera_fx.gd

var passed: int = 0
var failed: int = 0


func check(ok: bool, what: String, info: String = "") -> void:
	if ok:
		passed += 1
		print("PASS: ", what)
	else:
		failed += 1
		print("FAIL: ", what, ("  (" + info + ")") if info != "" else "")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fx: Node = root.get_node("Fx")
	var game: Node = root.get_node("Game")
	# --- intensity table (pin the shipped defaults so a player's saved settings can't affect the test)
	var user_fx: Array = [fx.own_intensity, fx.ally_intensity, fx.enemy_intensity]
	fx.own_intensity = 1.0
	fx.ally_intensity = 0.5
	fx.enemy_intensity = 0.7
	check(is_equal_approx(fx.intensity_for(fx.REL_OWN), 1.0), "own effects at 100%")
	check(is_equal_approx(fx.intensity_for(fx.REL_ALLY), 0.5), "ally effects default 50%")
	check(is_equal_approx(fx.intensity_for(fx.REL_ENEMY), 0.7), "enemy effects default 70%")
	check(is_equal_approx(fx.intensity_for(fx.REL_ENEMY, true), 1.0), "enemy telegraphs always full")
	check(fx.intensity_for(fx.REL_ALLY, true) >= 0.6, "ally telegraphs stay readable")
	fx.own_intensity = user_fx[0]
	fx.ally_intensity = user_fx[1]
	fx.enemy_intensity = user_fx[2]
	check(is_equal_approx(fx.intensity_for(fx.REL_UNKNOWN), 1.0), "unknown caster untouched")
	# --- prefs -> Fx
	var old_ally: float = float(game.prefs.get("fx_ally", 0.5))
	game.prefs["fx_ally"] = 0.3
	game.apply_prefs()
	check(is_equal_approx(float(fx.ally_intensity), 0.3), "apply_prefs pushes fx_ally to Fx")
	game.prefs["fx_ally"] = old_ally
	game.apply_prefs()
	# --- impact_fired
	var got: Array = []
	var cb := func(p: Vector3, lvl: int, rel: int) -> void: got.append([p, lvl, rel])
	fx.connect("impact_fired", cb)
	fx.impact(Vector3(1, 1, 1), 3.0)
	check(got.size() == 1 and int(got[0][1]) == 3, "Fx.impact emits impact_fired with its level", str(got))
	fx.disconnect("impact_fired", cb)
	# --- dimmed one-shot pieces carry their intensity (fx_k) and solids are never dithered
	fx.call("_begin_ctx", 0, false)
	fx.set("_cur_k", 0.5)
	var fl: Node = fx.flash(QuadMesh.new(), ShaderMaterial.new(), Vector3(0, 50, 0), 0.5)
	check(is_equal_approx(float(fl.get_meta(&"fx_k", 1.0)), 0.5), "flash spawned under a 50% caster keeps fx_k 0.5")
	var cur: Variant = fl.get_instance_shader_parameter(&"fade")
	check(cur != null and float(cur) <= 0.51, "flash fade scaled by intensity", str(cur))
	fx.call("_end_ctx")
	fx.clear_all()

	# --- camera rig arm probe
	var scene := Node3D.new()
	root.add_child(scene)
	var body := StaticBody3D.new()
	body.collision_layer = CoreUtil.LAYER_WORLD
	scene.add_child(body)
	_box(body, "Bound0", Vector3(0, 2, 4.0), Vector3(20, 6, 1))
	var rig := CameraRig.new()
	scene.add_child(rig)
	rig.global_position = Vector3(-0.6, 2.0, 0)   # shoulder offset puts the probe at x = 0
	rig.rotation = Vector3.ZERO                   # arm points +Z (behind)
	await physics_frame
	await physics_frame
	check(rig.call("_probe_arm", 8.0) > 7.9, "invisible Bound wall does not pull the camera in", str(rig.call("_probe_arm", 8.0)))
	var post := _box(body, "Post1", Vector3(0, 2, 2.5), Vector3(0.3, 4, 0.3))
	await physics_frame
	await physics_frame
	check(rig.call("_probe_arm", 8.0) > 7.9, "slender post does not pull the camera in")
	post.queue_free()
	_box(body, "Wall2", Vector3(0, 2, 3.0), Vector3(20, 6, 1))
	await physics_frame
	await physics_frame
	var arm: float = rig.call("_probe_arm", 8.0)
	check(arm < 3.0 and arm > 1.5, "solid wall pulls the arm in front of it", str(arm))
	# --- shake / FOV punch decay
	rig.shake(0.5)
	rig.fov_punch(0.05)
	await create_timer(0.9).timeout
	await process_frame
	check(is_equal_approx(rig.camera.fov, rig.base_fov), "FOV punch returns to base FOV", str(rig.camera.fov))
	check(rig.camera.h_offset == 0.0 and rig.camera.v_offset == 0.0, "shake decays to rest")
	scene.queue_free()
	await process_frame
	print("INT TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _box(body: StaticBody3D, n: String, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = n
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)
	return cs
