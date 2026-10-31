extends "res://tests/test_core_base.gd"
const Style := preload("res://ui/hud_style.gd")

func run_tests() -> void:
	suite_name = "battle_mage_motion"
	await test_poses()
	await test_contacts()
	await test_dragon_control()
	await test_touch_steering()

func mage() -> Fighter:
	return world.spawn_fighter({"kind": "player", "peer": 1, "class_id": "battle_mage", "team": 0, "pos": Vector3.ZERO})

func test_poses() -> void:
	var v := CharacterVisual.create_for_class("battle_mage", "battle_lance")
	root.add_child(v)
	await process_frame
	var kit_bm := CoreUtil.get_kit("battle_mage")
	for skill: SkillDef in kit_bm.skills:
		check(v.resolve_key(skill.anim).begins_with("battle/"), "%s has authored choreography" % skill.id)
		var tex := Style.skill_icon(skill)
		check(tex != null and tex.resource_path.contains("battle_mage_painted"), "%s uses its painted icon" % skill.id)
	var w: Node3D = v._mounts[0]["node"]
	for key: String in ["bm_thrust", "bm_tooth", "bm_pierce"]:
		v.pose_clip(v.resolve_key(StringName(key)), 0.2 if key == "bm_pierce" else 0.12, StringName(key))
		await process_frame
		check(w.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.98, "%s points at its forward hitbox" % key)
		var left := v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.skeleton.find_bone("LeftHand"))
		var palm := left.origin + left.basis.y.normalized() * 0.075 * v.model_root.scale.x
		var on_shaft := Geometry3D.get_closest_point_to_segment(palm, w.to_global(Vector3(0, -0.2, 0)), w.to_global(Vector3(0, 0.65, 0)))
		check(palm.distance_to(on_shaft) < 0.12, "%s front palm stays on shaft" % key, str(palm.distance_to(on_shaft)))
	v.pose_clip(v.resolve_key(&"bm_sky"), 0.06, &"bm_sky")
	await process_frame
	var low := w.to_global(Vector3(0, 2.156, 0)).y
	v.pose_clip(v.resolve_key(&"bm_sky"), 0.23, &"bm_sky")
	await process_frame
	check(w.to_global(Vector3(0, 2.156, 0)).y > low + 1.5, "Sky Strike lifts the spear from below to above the target")
	v.play(&"run")
	check(v.body.is_two_hand(w) and not v.current_clip.begins_with("battle/"), "locomotion restores the ordinary grip solver")
	v.queue_free()
	await process_frame

func test_contacts() -> void:
	await new_world()
	var a := mage()
	var front := spawn(1, Vector3(0, 0, -2))
	var behind := spawn(1, Vector3(0, 0, 2))
	await sim(0.1)
	a.start_skill(a.kit.skills[4], 4)
	await sim(0.16)
	check(front.state == Fighter.State.GRABBED and behind.state != Fighter.State.GRABBED, "Circle Swing catches one forward target, never a rear AoE")
	await sim(0.22)
	check(front.global_position.y > 0.8, "Circle Swing carries the caught target through an overhead arc")
	var before := front.hp
	await sim(0.25)
	check(front.hp < before and front.is_downed(), "Circle Swing releases damage into forced knockdown")
	check(int(a.kit.call("chaser_count", a)) == 1, "the completed throw creates exactly one chaser")
	await new_world()
	a = mage()
	front = spawn(1, Vector3(0, 0, -20))
	await sim(0.1)
	a.start_skill(a.kit.skills[2], 2)
	await sim(0.5)
	check(int(a.kit.call("chaser_count", a)) == 0, "a Dragon Tooth whiff cannot farm chasers")
	front.global_position = a.global_position + a.forward() * 4
	var far_hp := front.hp
	a.input.aim_point = Vector3(20, 0, 0)
	var r := a.start_skill(a.kit.skills[5], 5)
	front.global_position = a.global_position + a.forward() * 4
	a.input.aim_point = Vector3(-20, 0, 0) # aim changes after the forward stance was committed
	for step: Dictionary in a.kit.skills[5].steps:
		if step.get("type") == "melee":
			r.execute_step(step)
	check(front.hp < far_hp, "Heart Pierce follows the caster's spear line rather than a remote aim patch")

func controlled_projectile(a: Fighter, steer: Vector2) -> Projectile:
	var cast := SkillDef.new()
	cast.id = &"test.manual_dragon"
	cast.cast_time = 2.0
	cast.anim = &"bm_dragon"
	var runner := a.start_skill(cast, 7)
	a.input.steer = steer
	var p := Projectile.new()
	p.caster = a
	p.team = a.team
	p.runner = runner
	p.position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.FORWARD * 20.0
	p.radius = 0.15
	p.max_range = 16.0
	p.visual = "spear_dragon"
	p.manual_steer = 1.8
	p.steer_window = 0.36
	p.hit = Hit.normalize({"dmg": 1.0, "knockback": 0.0})
	world.add_effect(p)
	return p

func test_dragon_control() -> void:
	await new_world()
	var a := mage()
	var high := spawn(1, Vector3(0, 1.4, -5))
	await physics_frame
	a.target_uid = high.uid
	var hp0 := high.hp
	var straight := controlled_projectile(a, Vector2.ZERO)
	for i in 24:
		straight.tick(DT)
	check(high.hp == hp0 and absf(straight.velocity.y) < 0.001, "no gesture stays straight even with an elevated lock target")
	straight.finish()
	var lifted := controlled_projectile(a, Vector2(0, 1))
	for i in 24:
		if lifted.alive:
			lifted.tick(DT)
	check(high.hp < hp0, "manual head lift catches an opponent above the original trajectory")
	if lifted.alive:
		lifted.finish()
	high.global_position = Vector3(30, 0, 30)
	var turned := controlled_projectile(a, Vector2(1, 0.5))
	for i in 24:
		turned.tick(DT)
	check(turned.velocity.x > 1.0 and turned.velocity.y > 1.0, "one gesture can steer sideways and upward")
	check(Vector3.FORWARD.angle_to(turned.velocity.normalized()) <= 1.8 * 0.36 + 0.001, "turn angle is bounded by the server turn-rate budget")
	var after := turned.velocity
	a.input.steer = Vector2(-1, -1)
	for i in 5:
		turned.tick(DT)
	check(turned.velocity.is_equal_approx(after), "input after the steering window cannot curve the dragon")
	turned.finish()
	for hz: int in [30, 60, 144]:
		var sampled := controlled_projectile(a, Vector2(1, 0.5))
		for frame in ceili(0.45 * hz):
			sampled.tick(1.0 / hz)
		check(absf(Vector3.FORWARD.angle_to(sampled.velocity.normalized()) - 1.8 * 0.36) < 0.001,
			"manual turn window has the same angle budget at %d Hz" % hz)
		sampled.finish()
	var stopped := controlled_projectile(a, Vector2.ONE)
	stopped.tick(DT)
	a.interrupt_cast()
	var heading := stopped.velocity
	stopped.tick(DT)
	check(stopped.velocity.is_equal_approx(heading), "interrupting the caster removes further flight control")
	stopped.finish()
	var input := FighterInput.new()
	input.steer = Vector2(0.5, 0.8)
	check(FighterInput.from_dict(input.to_dict()).steer == input.steer, "manual steering survives the multiplayer input packet")
	a.apply_input(input)
	check(a.input.steer == input.steer, "local and remote intent reach the fighter's steering state")
	check(FighterInput.from_dict({"s": Vector2(INF, NAN)}).steer == Vector2.ZERO, "nonfinite steering is rejected")
	var fx := root.get_node("Fx")
	fx.spawn_projectile_visual(90001, "spear_dragon", Vector3.ZERO, Vector3.FORWARD, 0.0, Color.WHITE, 1.0)
	var visual: Node3D = fx._nodes[90001]
	fx.move_projectile_visual(90001, Vector3(1, 2, -3), Vector3(2, 3, -8))
	check(fx._nodes[90001] == visual and visual.position == Vector3(1, 2, -3) and visual.vel == Vector3(2, 3, -8), "host correction updates position/velocity without replacing the dragon or its trail")
	fx.despawn(90001)

func test_touch_steering() -> void:
	await new_world()
	var a := mage()
	a.start_skill(a.kit.skills[7], 7)
	var ctrl := PlayerController.new()
	ctrl.fighter = a
	world.add_child(ctrl)
	ctrl.set_physics_process(false)
	var ui: Control = load("res://ui/touch_controls.gd").new()
	ui.controller = ctrl
	world.add_child(ui)
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1280, 720)
	var point: Vector2 = ui.button_rect(7).get_center()
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.position = point
	press.pressed = true
	ui._input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = point + Vector2(40, -60)
	ui._input(drag)
	check(ctrl.touch_steer.x > 0 and ctrl.touch_steer.y > 0, "dragging the active ultimate right/up controls the dragon")
	a.interrupt_cast()
	press.pressed = false
	ui._input(press)
	check(ctrl.touch_pressed == 0 and ctrl.touch_steer == Vector2.ZERO, "releasing flight control after the cast ends does not queue a second ultimate")
