extends "res://tests/test_core_base.gd"
## Camera projection, screen-relative intent, independent touch fingers and cancellation.

func run_tests() -> void:
	suite_name = "isometric_controls"
	await new_world()
	var a := spawn(0, Vector3.ZERO)
	var enemy := spawn(1, Vector3(4, 0, -3))
	var ctrl := PlayerController.new()
	ctrl.fighter = a
	world.add_child(ctrl)
	ctrl.set_physics_process(false)
	var rig := ctrl.camera
	rig.target = a
	await process_frame
	rig._process(0.1)
	check(rig.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "default gameplay camera is orthographic")
	check(not ctrl.capture_mouse, "PC keeps a visible aiming cursor")
	var yaw := rig.yaw
	var pitch := rig.pitch
	a.target_uid = enemy.uid
	a.facing_yaw = PI
	rig._process(0.5)
	check(is_equal_approx(yaw, rig.yaw) and is_equal_approx(pitch, rig.pitch), "facing and lock-on never rotate the isometric view")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(300, 200)
	rig._unhandled_input(mouse)
	check(rig.yaw == yaw and rig.pitch == pitch, "mouse aiming does not orbit the camera")
	for point: Vector3 in [Vector3(-5, 0, 2), Vector3(3, 0, -4)]:
		var ray := rig.screen_ray(rig.camera.unproject_position(point))
		var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray["from"], ray["dir"])
		check(ground is Vector3 and ground.distance_to(point) < 0.01, "off-center cursor ray reaches its world-space ground target")
	for key: String in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_press(key)
		var inp := ctrl.build_input()
		var from := rig.camera.unproject_position(a.center())
		var to := rig.camera.unproject_position(a.center() + inp.move)
		var screen_dir := (to - from).normalized()
		var expected: Vector2 = {"move_forward": Vector2.UP, "move_back": Vector2.DOWN, "move_left": Vector2.LEFT, "move_right": Vector2.RIGHT}[key]
		check(screen_dir.dot(expected) > 0.99, "%s moves in the corresponding screen direction" % key)
		Input.action_release(key)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	check(is_equal_approx(ctrl.build_input().move.length(), 1.0), "diagonal movement is normalized")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in 40:
		rig._unhandled_input(wheel)
	check(rig.iso_size == 12.0, "wheel zoom clamps at a readable near limit")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 40:
		rig._unhandled_input(wheel)
	check(rig.iso_size == 26.0, "wheel zoom clamps at tactical far limit")
	var ui: Control = load("res://ui/touch_controls.gd").new()
	ui.set("controller", ctrl)
	world.add_child(ui)
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1280, 720)
	ctrl.touch_controls = ui
	var center: Vector2 = ui.call("stick_center")
	_touch(ui, 0, center + Vector2(0, -50), true)
	check(ctrl.touch_move.y < -0.5 and ctrl.touch_move.x == 0, "left finger drives the movement stick")
	var rect: Rect2 = ui.call("button_rect", 2)
	_touch(ui, 1, rect.get_center(), true)
	check(ctrl.touch_move.y < -0.5 and (ctrl.touch_held & 4) != 0, "skill finger and movement finger operate simultaneously")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = rect.get_center() + Vector2(100, 0)
	ui.call("_input", drag)
	check(ctrl.touch_aim.dot(Vector2.RIGHT) > 0.99, "dragging a skill button sets an independent aim direction")
	_touch(ui, 1, drag.position, false)
	check((ctrl.touch_pressed & 4) != 0 and ctrl.touch_held == 0 and ctrl.touch_move.y < -0.5, "release outside the button casts once and leaves movement active")
	var edge := ctrl.build_input()
	check(edge.is_pressed(2) and edge.press_id > 0, "touch skill goes through the normal network edge protocol")
	ctrl.touch_pressed = 1 | 4
	var priority := ctrl.build_input()
	check(priority.is_pressed(2) and not priority.is_pressed(0), "aimed skill wins over a simultaneous basic-attack repeat")
	_touch(ui, 0, Vector2.ZERO, false)
	check(ctrl.touch_move == Vector2.ZERO, "releasing stick outside its bounds stops movement")
	ctrl.clear_pending_input()
	_touch(ui, 2, rect.get_center(), true)
	_touch(ui, 2, rect.get_center(), false, true)
	check(ctrl.touch_pressed == 0 and ctrl.touch_held == 0, "OS-cancelled touch does not cast or stick")
	_touch(ui, 0, center + Vector2(40, 0), true)
	_touch(ui, 1, (ui.call("button_rect", 0) as Rect2).get_center(), true)
	ctrl._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var neutral := ctrl.build_input()
	check(neutral.move == Vector3.ZERO and neutral.pressed == 0 and ctrl.touch_held == 0, "focus loss clears movement, held attack and pending resends")
	ctrl._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	ctrl.enabled = false
	Input.action_press("move_forward")
	check(ctrl.build_input().move == Vector3.ZERO, "disabled controller emits neutral movement")
	Input.action_release("move_forward")
	ctrl.queue_free()
	await process_frame

func _touch(ui: Control, index: int, pos: Vector2, down: bool, canceled := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = down
	e.canceled = canceled
	ui.call("_input", e)
