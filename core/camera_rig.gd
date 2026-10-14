class_name CameraRig
extends Node3D
## Third-person action-MMO camera (purely local, never replicated).
## Framing: the arm pivots a little above the followed fighter's head (scaled by the visual's real height), with a
## right-shoulder offset and a default ~17 degree downward pitch, so the own character sits in the lower third,
## slightly left of centre, and the fight in front of it stays visible. Mouse look, smooth wheel zoom, wall
## collision via a sphere cast (pulls in quickly, eases back out: no snapping), lock-on framing that keeps the
## player and the target in view, trauma-model shake and a short FOV punch (hooked to Fx.impact_fired).

@export var distance: float = 6.4
@export var min_distance: float = 2.6
@export var max_distance: float = 11.0
## Arm pivot height for a 1.8 m character (scaled by the followed fighter's visual height / body_scale).
@export var pivot_height: float = 2.05
@export var shoulder: float = 0.6
@export var base_fov: float = 62.0
@export var mouse_sensitivity: float = 0.0025
@export var follow_sharpness: float = 14.0
@export var lock_sharpness: float = 6.0
@export var vertical_sharpness: float = 5.0
@export var zoom_sharpness: float = 9.0
## Default downward pitch (radians) used when the camera snaps to a fighter.
@export var default_pitch: float = -0.3
## Shake / FOV punch from impacts (bible 5.3: trauma 0.1 / 0.25 / 0.5, 3-5% FOV punch).
@export var impact_feedback: bool = true

const PROBE_RADIUS: float = 0.25
const MIN_ARM: float = 0.6
const REF_HEIGHT: float = 1.8

var target: Fighter = null
var yaw: float = 0.0
var pitch: float = -0.3
var spring: SpringArm3D
var camera: Camera3D

var _shake: float = 0.0          # trauma 0..1 (shake amount = trauma^2)
var _shake_t: float = 0.0
var _fov_punch: float = 0.0      # current FOV reduction fraction
var _fov_punch_t: float = 0.0
var _arm: float = -1.0           # smoothed collision-limited arm length
var _zoom: float = 6.4           # smoothed zoom distance
var _rng := RandomNumberGenerator.new()
var _snapped: bool = false
var _lock_extra: float = 0.0
var _last_hit: String = ""


func _ready() -> void:
	top_level = true
	pitch = default_pitch
	_zoom = distance
	spring = SpringArm3D.new()
	spring.name = "Spring"
	# Collision is resolved by our own sphere cast (smooth); the SpringArm only places the camera.
	spring.collision_mask = 0
	spring.spring_length = distance
	spring.margin = 0.2
	spring.position = Vector3(shoulder, 0.0, 0.0)
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = base_fov
	camera.near = 0.05
	camera.far = 400.0
	spring.add_child(camera)
	camera.current = true
	_rng.randomize()
	var fx := CoreUtil.autoload("Fx")
	if fx != null and fx.has_signal(&"impact_fired"):
		fx.connect(&"impact_fired", _on_fx_impact)


func get_camera() -> Camera3D:
	return camera


## Adds camera trauma (0..2 accepted for compatibility; 0.1 light, 0.25 medium, 0.5 heavy).
func shake(strength: float) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, 1.0)


## Short FOV punch-in (fraction of the FOV, e.g. 0.03 - 0.05).
func fov_punch(amount: float) -> void:
	_fov_punch = clampf(maxf(_fov_punch, amount), 0.0, 0.08)
	_fov_punch_t = 0.0


func forward_flat() -> Vector3:
	return CoreUtil.dir_of_yaw(yaw)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * mouse_sensitivity
		pitch = clampf(pitch - mm.relative.y * mouse_sensitivity, -1.2, 0.55)
	elif e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.7, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.7, min_distance, max_distance)


## Height scale of the followed fighter (anime bodies 1.66-1.88 m, bosses bigger).
func _height_scale() -> float:
	if target == null or not is_instance_valid(target):
		return 1.0
	var h := 0.0
	var v: Variant = target.get("visual")
	if v is Node3D and is_instance_valid(v):
		var hv: Variant = (v as Node3D).get("height")
		if hv is float:
			h = hv
	if h <= 0.1:
		h = REF_HEIGHT * target.body_scale
	return clampf(h / REF_HEIGHT, 0.6, 3.0)


func _process(delta: float) -> void:
	if spring == null:
		return
	var hs := _height_scale()
	var lock_dist_extra := 0.0
	if target != null and is_instance_valid(target):
		var pivot := target.global_position + Vector3(0.0, pivot_height * hs, 0.0)
		if not _snapped:
			global_position = pivot
			yaw = target.facing_yaw
			pitch = default_pitch
			_snapped = true
		else:
			# vertical follow is softer so leaps / launches do not yank the view up and down
			var gp := global_position.lerp(pivot, 1.0 - exp(-follow_sharpness * delta))
			gp.y = lerpf(global_position.y, pivot.y, 1.0 - exp(-vertical_sharpness * delta))
			global_position = gp
		var lock := target.get_target()
		if lock != null and lock != target and is_instance_valid(lock):
			var to := lock.center() - pivot
			var flat := CoreUtil.flat(to)
			var fl := flat.length()
			if fl > 0.5:
				# Aim a little to the right of the target so the shoulder-offset player and the target share the frame.
				var want_yaw := CoreUtil.yaw_of(flat.normalized()) + clampf(0.5 / fl, 0.0, 0.25)
				yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-lock_sharpness * delta))
				# Pitch toward the target's centre as seen from the camera (not the pivot, which would tip the view
				# straight down at melee range), biased down so the player stays in the lower third.
				var reach := fl + maxf(_arm, MIN_ARM) * cos(pitch)
				var want_pitch := clampf(atan2(to.y, reach) - 0.22, -0.7, 0.2)
				pitch = lerpf(pitch, want_pitch, 1.0 - exp(-lock_sharpness * 0.5 * delta))
				# Pull out a bit when the target is very close or very big.
				lock_dist_extra = clampf(3.5 - fl, 0.0, 2.5) * 0.6 + maxf(lock.body_scale - 1.0, 0.0) * 2.5
	_lock_extra = lerpf(_lock_extra, lock_dist_extra, 1.0 - exp(-3.0 * delta))
	rotation = Vector3(pitch, yaw, 0.0)
	_zoom = lerpf(_zoom, distance, 1.0 - exp(-zoom_sharpness * delta))
	var want_len := (_zoom + _lock_extra) * clampf(lerpf(1.0, hs, 0.5), 0.8, 2.0)
	var hit_len := _probe_arm(want_len)
	if _arm < 0.0:
		_arm = hit_len
	elif hit_len < _arm:
		# obstacle: pull in fast (2-3 frames) but never sit behind the hit point
		_arm = minf(lerpf(_arm, hit_len, 1.0 - exp(-30.0 * delta)), hit_len + 0.25)
	else:
		# free again: ease back out
		_arm = lerpf(_arm, hit_len, 1.0 - exp(-3.5 * delta))
	spring.spring_length = maxf(_arm, MIN_ARM)
	_tick_feedback(delta)


## Debug / tests: {arm, zoom, lock_extra, pitch, yaw, fov}.
func debug_state() -> Dictionary:
	return {"arm": _arm, "zoom": _zoom, "lock_extra": _lock_extra, "pitch": pitch, "yaw": yaw, "fov": camera.fov if camera else 0.0, "hit": _last_hit}


## Sphere cast from the pivot (incl. shoulder offset) back along the arm; returns the free length. Invisible
## gameplay boundaries (collision shapes named "Bound*" or with meta camera_ignore) do not push the camera in.
func _probe_arm(want: float) -> float:
	var w3 := get_world_3d()
	if w3 == null or not is_inside_tree():
		return want
	var space := w3.direct_space_state
	if space == null:
		return want
	var origin := global_transform * Vector3(shoulder, 0.0, 0.0)
	var back := global_transform.basis.z.normalized()
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = PROBE_RADIUS
	q.shape = sph
	q.collision_mask = CoreUtil.LAYER_WORLD
	q.collide_with_areas = false
	var start := 0.0
	for _i in 3:
		var remain := want - start
		if remain <= 0.01:
			return want
		q.transform = Transform3D(Basis.IDENTITY, origin + back * start)
		q.motion = back * remain
		var r := space.cast_motion(q)
		if r.size() < 2 or float(r[0]) >= 0.999:
			return want
		var hit_at := start + remain * float(r[0])
		var touch := PhysicsShapeQueryParameters3D.new()
		var big := SphereShape3D.new()
		big.radius = PROBE_RADIUS + 0.06
		touch.shape = big
		touch.collision_mask = CoreUtil.LAYER_WORLD
		touch.collide_with_areas = false
		touch.transform = Transform3D(Basis.IDENTITY, origin + back * (start + remain * float(r[1])))
		var solid := false
		var hits := space.intersect_shape(touch, 6)
		for h: Dictionary in hits:
			if not _camera_transparent(h, origin.y):
				solid = true
				_last_hit = _hit_name(h)
				break
		if solid or hits.is_empty():
			return maxf(hit_at - 0.05, MIN_ARM)
		start = hit_at + 2.5   # skip through the (thin) invisible boundary
	return want


static func _hit_name(info: Dictionary) -> String:
	var obj := instance_from_id(int(info.get("collider_id", 0))) if not info.is_empty() else null
	if obj is CollisionObject3D:
		var co := obj as CollisionObject3D
		var node: Variant = co.shape_owner_get_owner(co.shape_find_owner(int(info.get("shape", 0))))
		return str((node as Node).name) if node is Node else str(co.name)
	return "?"


static func _camera_transparent(info: Dictionary, pivot_y: float) -> bool:
	if info.is_empty():
		return false
	var obj := instance_from_id(int(info.get("collider_id", 0)))
	if not (obj is CollisionObject3D):
		return false
	var co := obj as CollisionObject3D
	var owner_id := co.shape_find_owner(int(info.get("shape", 0)))
	var node: Variant = co.shape_owner_get_owner(owner_id)
	if node is Node:
		var n := node as Node
		if n.has_meta(&"camera_ignore") or str(n.name).begins_with("Bound"):
			return true
		# Thin / low props (fence posts, rails, lanterns) would yank the camera to the player's back: see through.
		if n is CollisionShape3D:
			var sh := (n as CollisionShape3D).shape
			var sc := (n as Node3D).global_transform.basis.get_scale()
			var ext := Vector3.INF
			if sh is BoxShape3D:
				ext = (sh as BoxShape3D).size * sc
			elif sh is CylinderShape3D:
				var c := sh as CylinderShape3D
				ext = Vector3(c.radius * 2.0, c.height, c.radius * 2.0) * sc
			elif sh is CapsuleShape3D:
				var cp := sh as CapsuleShape3D
				ext = Vector3(cp.radius * 2.0, cp.height, cp.radius * 2.0) * sc
			elif sh is SphereShape3D:
				ext = Vector3.ONE * (sh as SphereShape3D).radius * 2.0 * sc
			if ext != Vector3.INF:
				var top := (n as Node3D).global_position.y + ext.y * 0.5
				var low_prop := top < pivot_y - 0.3
				var slender := maxf(ext.x, ext.z) < 0.9 and ext.y > 1.5 * maxf(ext.x, ext.z)
				return low_prop or slender
	return false


func _tick_feedback(delta: float) -> void:
	if camera == null:
		return
	_shake_t += delta
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.6)
		var amt := _shake * _shake
		var t := _shake_t * 32.0
		# smooth pseudo-noise (sum of sines) instead of per-frame random jumps
		camera.h_offset = (sin(t * 1.13) + sin(t * 2.71 + 1.3) * 0.5) * amt * 0.22
		camera.v_offset = (sin(t * 1.37 + 0.7) + sin(t * 3.11 + 2.1) * 0.5) * amt * 0.22
		camera.rotation.z = sin(t * 0.91 + 0.4) * amt * 0.035
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0
	if _fov_punch > 0.0:
		_fov_punch_t += delta
		# 0.06 s in, 0.25 s ease back out
		var k := clampf(_fov_punch_t / 0.06, 0.0, 1.0) if _fov_punch_t < 0.06 else 1.0 - clampf((_fov_punch_t - 0.06) / 0.25, 0.0, 1.0)
		camera.fov = base_fov * (1.0 - _fov_punch * ease(k, 0.6))
		if _fov_punch_t > 0.31:
			_fov_punch = 0.0
			camera.fov = base_fov
	elif camera.fov != base_fov:
		camera.fov = base_fov


## Fx impact (hit-stop) events -> trauma + FOV punch, weighted by how close the hit is to the followed fighter.
## level 1 light / 2 medium / 3 heavy / 4 ultimate; rel = Fx.REL_* (0 own, 1 ally, 2 enemy, -1 unknown).
func _on_fx_impact(pos: Vector3, level: int, rel: int) -> void:
	if not impact_feedback or camera == null or not camera.current:
		return
	if target == null or not is_instance_valid(target):
		return
	var d := Vector2(pos.x - target.global_position.x, pos.z - target.global_position.z).length()
	var involved := rel == 0 or d < 1.8
	if level <= 1:
		if involved:
			shake(0.1 if rel == 0 else 0.18)
		return
	var w := 1.0 if involved else clampf(1.0 - (d - 2.0) / 10.0, 0.0, 1.0) * 0.5
	if w <= 0.01:
		return
	var trauma: float = [0.0, 0.1, 0.25, 0.5, 0.6][clampi(level, 0, 4)]
	shake(trauma * w)
	if level >= 3 and (involved or level >= 4):
		fov_punch((0.03 if level == 3 else 0.05) * w)


## World-space ray through the screen center: {from, dir}.
func center_ray() -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {"from": global_position, "dir": forward_flat()}
	var vp := camera.get_viewport()
	var c := vp.get_visible_rect().size * 0.5
	return {"from": camera.project_ray_origin(c), "dir": camera.project_ray_normal(c)}
