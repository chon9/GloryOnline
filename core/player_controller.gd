class_name PlayerController
extends Node
## Reads local InputMap actions for this machine's human fighter (kind "player", peer == my id), builds a
## camera-relative FighterInput and sends it to the host every physics frame (host applies directly).
## Isometric PC: free cursor aiming + screen-relative WASD. Touch controls submit the same intent.
## Tab cycles enemies, middle mouse toggles lock-on. Capture is only for legacy perspective tools.
## Shift ("dodge_sprint"): a tap (released within DODGE_TAP_TIME) sends a dodge edge, holding it longer sprints.

const LOCK_RANGE: float = 30.0
const AIM_FALLBACK: float = 20.0
const RESEND_FRAMES: int = 3
const DODGE_TAP_TIME: float = 0.2

var fighter: Fighter = null
var camera: CameraRig = null
var capture_mouse: bool = false
var enabled: bool = true
var touch_controls: Control
var touch_move := Vector2.ZERO
var touch_aim := Vector2.ZERO
var touch_held: int = 0
var touch_pressed: int = 0
var touch_jump := false
var touch_dodge := false
var _focused := true

static func uses_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()

var _press_id: int = 0
var _resend_left: int = 0
var _last_pressed: int = 0
var _last_jump: bool = false
var _last_dodge: bool = false
var _shift_down: bool = false
var _shift_t: float = 0.0
var _lock_uid: int = 0
var _last_hp: float = -1.0


func _ready() -> void:
	if camera == null:
		camera = CameraRig.new()
		camera.name = "CameraRig"
		add_child(camera)
	if capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if uses_touch():
		var layer := CanvasLayer.new()
		layer.layer = 15
		add_child(layer)
		touch_controls = (load("res://ui/touch_controls.gd") as Script).new()
		touch_controls.set("controller", self)
		layer.add_child(touch_controls)


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(e: InputEvent) -> void:
	if not capture_mouse:
		return
	if _action(e, "menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


static func _action(e: InputEvent, a: String) -> bool:
	return InputMap.has_action(a) and e.is_action_pressed(a)


static func _just(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)


static func _held(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_pressed(a)


func _find_fighter() -> void:
	if fighter != null and is_instance_valid(fighter):
		return
	fighter = null
	var w := World.get_instance()
	if w != null:
		fighter = w.local_fighter()
	if camera != null:
		camera.target = fighter


func _physics_process(_delta: float) -> void:
	_find_fighter()
	if not enabled or fighter == null:
		clear_pending_input()
		return
	if camera != null:
		camera.target = fighter
		# Local hit feedback (works on clients too: hp is replicated).
		if _last_hp >= 0.0 and fighter.hp < _last_hp - 1.0:
			var frac := (_last_hp - fighter.hp) / maxf(fighter.max_hp, 1.0)
			if frac > 0.02:
				camera.shake(clampf(frac * 4.0, 0.1, 0.45))
		_last_hp = fighter.hp
	var inp := build_input()
	if multiplayer.is_server():
		fighter.apply_input(inp)
	else:
		fighter.submit_input.rpc_id(1, inp.to_dict())


func build_input() -> FighterInput:
	var inp := FighterInput.new()
	var active := enabled and _focused and (not capture_mouse or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if not active:
		clear_pending_input()
		return inp
	# Movement relative to the camera.
	var v := Vector2.ZERO
	if InputMap.has_action("move_left") and InputMap.has_action("move_forward"):
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length_squared() > 0.01:
		v = touch_move
	var fwd := camera.forward_flat() if camera != null else fighter.forward()
	var rgt := fwd.cross(Vector3.UP)
	inp.move = (rgt * v.x - fwd * v.y).limit_length(1.0)
	# Aim through the cursor in isometric mode (world + fighters, excluding self).
	var ray := (camera.pointer_ray() if camera.isometric else camera.center_ray()) if camera != null else {"from": fighter.center(), "dir": fighter.forward()}
	var from: Vector3 = ray["from"]
	var dir: Vector3 = ray["dir"]
	var reach := AIM_FALLBACK + (camera.spring.spring_length if camera != null and camera.spring != null else 0.0)
	inp.aim_dir = dir
	inp.aim_point = from + dir * reach
	var w := fighter.world()
	if w != null:
		var excl: Array[RID] = [fighter.get_rid()]
		var hit := w.raycast(from, from + dir * (reach + 40.0), CoreUtil.LAYER_WORLD | CoreUtil.LAYER_FIGHTERS, excl)
		if not hit.is_empty():
			inp.aim_point = hit["position"]
		elif camera != null and camera.isometric:
			var ground: Variant = Plane(Vector3.UP, fighter.global_position.y).intersects_ray(from, dir)
			if ground is Vector3:
				inp.aim_point = ground
	if uses_touch():
		var aim := touch_aim if touch_aim.length_squared() > 0.01 else v
		var world_aim := (rgt * aim.x - fwd * aim.y).normalized() if aim.length_squared() > 0.01 else fighter.forward()
		inp.aim_point = fighter.center() + world_aim * AIM_FALLBACK
		inp.aim_dir = world_aim
	# Lock-on.
	if active:
		if _just("target_cycle"):
			_cycle_target()
		elif _just("target_clear"):
			if _lock_uid != 0:
				_lock_uid = 0
			else:
				_lock_uid = _best_target(0)
	_validate_lock()
	inp.target_uid = _lock_uid
	# Edges and holds.
	var bits := touch_pressed
	if (bits & ~1) != 0:
		bits &= ~1  # A deliberate skill release takes priority over held basic-attack repeat.
	var held := touch_held
	touch_pressed = 0
	var hovered := get_viewport().gui_get_hovered_control()
	var pointer_blocked := hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if active:
		for i in 8:
			# Mouse clicks over menus/skill tooltips must not attack through the UI.
			if i < 2 and (pointer_blocked or uses_touch()):
				continue
			var a := "skill_%d" % i
			if _just(a):
				bits |= 1 << i
			if _held(a):
				held |= 1 << i
	var jump := touch_jump or (active and _just("jump"))
	touch_jump = false
	var dodge := feed_dodge_key(active and _held("dodge_sprint"), active and _just("dodge_sprint"),
		get_physics_process_delta_time())
	# Dedicated dodge (Alt / mouse thumb button): dodges on press, no tap latency.
	dodge = dodge or (active and _just("dodge"))
	dodge = dodge or touch_dodge
	touch_dodge = false
	inp.sprint = is_sprint_held()
	inp.held = held
	if bits != 0 or jump or dodge:
		_press_id += 1
		_resend_left = RESEND_FRAMES
		_last_pressed = bits
		_last_jump = jump
		_last_dodge = dodge
	elif _resend_left > 0:
		_resend_left -= 1
	else:
		_last_pressed = 0
		_last_jump = false
		_last_dodge = false
	inp.pressed = _last_pressed
	inp.jump = _last_jump
	inp.dodge = _last_dodge
	inp.press_id = _press_id
	return inp


func clear_pending_input() -> void:
	touch_move = Vector2.ZERO
	touch_aim = Vector2.ZERO
	touch_held = 0
	touch_pressed = 0
	touch_jump = false
	touch_dodge = false
	_resend_left = 0
	_last_pressed = 0
	_last_jump = false
	_last_dodge = false
	_shift_down = false
	_shift_t = 0.0
	if is_instance_valid(touch_controls):
		touch_controls.call("release_all")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		clear_pending_input()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


## Tap / hold detection for the dodge_sprint key, fed once per physics frame: `down` = held now, `just` = pressed
## since the last frame (catches a press + release inside one frame). Returns true on the frame a tap is released
## (held no longer than DODGE_TAP_TIME). Holding longer sprints (is_sprint_held) and releases without a dodge.
func feed_dodge_key(down: bool, just: bool, dt: float) -> bool:
	var tap := false
	if down:
		if not _shift_down or just:
			_shift_t = 0.0
		else:
			_shift_t += dt
	elif _shift_down:
		tap = _shift_t <= DODGE_TAP_TIME
	elif just:
		tap = true        # pressed and released between two physics frames
	_shift_down = down
	return tap


func is_sprint_held() -> bool:
	return _shift_down and _shift_t > DODGE_TAP_TIME


func _candidates() -> Array[Fighter]:
	var out: Array[Fighter] = []
	var w := fighter.world()
	if w == null:
		return out
	for e: Fighter in w.enemies_of(fighter, false):
		if e.global_position.distance_to(fighter.global_position) <= LOCK_RANGE:
			out.append(e)
	var fwd := camera.forward_flat() if camera != null else fighter.forward()
	var origin := fighter.global_position
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return fwd.angle_to(CoreUtil.flat_dir(a.global_position - origin)) < fwd.angle_to(CoreUtil.flat_dir(b.global_position - origin)))
	return out


func _best_target(_exclude: int) -> int:
	var c := _candidates()
	return c[0].uid if not c.is_empty() else 0


func _cycle_target() -> void:
	var c := _candidates()
	if c.is_empty():
		_lock_uid = 0
		return
	var idx := -1
	for i in c.size():
		if c[i].uid == _lock_uid:
			idx = i
	_lock_uid = c[(idx + 1) % c.size()].uid


func _validate_lock() -> void:
	if _lock_uid == 0:
		return
	var w := fighter.world()
	var t: Fighter = w.get_fighter(_lock_uid) if w != null else null
	if t == null or not fighter.is_enemy(t) or t.is_stealthed \
			or t.global_position.distance_to(fighter.global_position) > LOCK_RANGE * 1.5:
		_lock_uid = 0


func lock_target_uid() -> int:
	return _lock_uid
