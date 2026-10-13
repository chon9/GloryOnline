class_name CameraRig
extends Node3D
## Third-person over-the-shoulder camera: spring arm (collides with world layer), mouse look, zoom,
## smooth follow, lock-on framing and a shake(strength) API. Purely local (never replicated).

@export var distance: float = 5.0
@export var min_distance: float = 2.0
@export var max_distance: float = 10.0
@export var pivot_height: float = 1.6
@export var shoulder: float = 0.55
@export var mouse_sensitivity: float = 0.0025
@export var follow_sharpness: float = 14.0
@export var lock_sharpness: float = 6.0

var target: Fighter = null
var yaw: float = 0.0
var pitch: float = -0.3
var spring: SpringArm3D
var camera: Camera3D

var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()
var _snapped: bool = false


func _ready() -> void:
	top_level = true
	spring = SpringArm3D.new()
	spring.name = "Spring"
	spring.collision_mask = CoreUtil.LAYER_WORLD
	spring.spring_length = distance
	spring.margin = 0.2
	spring.position = Vector3(shoulder, 0.0, 0.0)
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	spring.shape = probe
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 400.0
	spring.add_child(camera)
	camera.current = true


func get_camera() -> Camera3D:
	return camera


func shake(strength: float) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, 2.0)


func forward_flat() -> Vector3:
	return CoreUtil.dir_of_yaw(yaw)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * mouse_sensitivity
		pitch = clampf(pitch - mm.relative.y * mouse_sensitivity, -1.25, 0.7)
	elif e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.6, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.6, min_distance, max_distance)


func _process(delta: float) -> void:
	if spring == null:
		return
	if target != null and is_instance_valid(target):
		var pivot := target.global_position + Vector3(0.0, pivot_height * target.body_scale, 0.0)
		if not _snapped:
			global_position = pivot
			yaw = target.facing_yaw
			_snapped = true
		else:
			global_position = global_position.lerp(pivot, 1.0 - exp(-follow_sharpness * delta))
		var lock := target.get_target()
		if lock != null and lock != target:
			var to := lock.center() - pivot
			var flat := CoreUtil.flat(to)
			if flat.length() > 0.5:
				var want_yaw := CoreUtil.yaw_of(flat.normalized())
				yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-lock_sharpness * delta))
				var want_pitch := clampf(atan2(to.y, flat.length()) - 0.25, -0.9, 0.3)
				pitch = lerpf(pitch, want_pitch, 1.0 - exp(-lock_sharpness * 0.5 * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	spring.spring_length = lerpf(spring.spring_length, distance, 1.0 - exp(-10.0 * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		camera.h_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.25
		camera.v_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.25
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## World-space ray through the screen center: {from, dir}.
func center_ray() -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {"from": global_position, "dir": forward_flat()}
	var vp := camera.get_viewport()
	var c := vp.get_visible_rect().size * 0.5
	return {"from": camera.project_ray_origin(c), "dir": camera.project_ray_normal(c)}
