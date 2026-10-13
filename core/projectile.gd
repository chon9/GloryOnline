class_name Projectile
extends Node3D
## Host-simulated projectile (ARCHITECTURE §5.1 `projectile`). Clients see an Fx visual that simulates
## the same trajectory; this node owns hit logic only. Stepped by World.step().

var caster: Fighter = null
var team: int = 0
var runner: SkillRunner = null
var velocity: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var radius: float = 0.35
var max_range: float = 18.0
var pierce: bool = false
var bounce: int = 0
var homing: float = 0.0               # turn rate rad/s
var homing_target: Fighter = null
var hit: Dictionary = {}
var explode: Dictionary = {}          # {radius, hit}
var visual: String = "orb"
var color: Color = Color.WHITE
var visual_scale: float = 1.0
var fx_id: int = 0
var traveled: float = 0.0
var max_lifetime: float = 8.0
var alive: bool = true

var _age: float = 0.0
var _hit_uids: Dictionary = {}
var _debug: MeshInstance3D = null


func _ready() -> void:
	var w := World.get_instance()
	if w != null:
		fx_id = w.next_fx_id()
	_issue_visual(global_position)
	if CoreUtil.fx_is_stub():
		_debug = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = maxf(0.12, radius) * visual_scale
		m.height = m.radius * 2.0
		_debug.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		_debug.material_override = mat
		add_child(_debug)


## (Re-)issues the Fx visual for this projectile id. homing_rate = `homing` so the visual turns like the host.
## Re-issuing the same id (on bounce) replaces the visual with the new position/velocity.
func _issue_visual(from: Vector3) -> void:
	var huid := homing_target.uid if (homing_target != null and is_instance_valid(homing_target)) else 0
	CoreUtil.fx(&"spawn_projectile_visual", [fx_id, visual, from, velocity, gravity, color, visual_scale, huid, homing])


func _caster_valid() -> bool:
	return caster != null and is_instance_valid(caster)


func tick(delta: float) -> void:
	if not alive:
		return
	_age += delta
	var w := World.get_instance()
	if w == null:
		finish()
		return
	# Homing.
	if homing > 0.0 and homing_target != null and is_instance_valid(homing_target) and homing_target.is_alive():
		var want := (homing_target.center() - global_position).normalized()
		var cur := velocity.normalized()
		var ang := cur.angle_to(want)
		if ang > 0.0001:
			var axis := cur.cross(want)
			if axis.length_squared() > 0.000001:
				velocity = velocity.rotated(axis.normalized(), minf(ang, homing * delta))
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	# World geometry.
	var r := w.raycast(from, to, CoreUtil.LAYER_WORLD)
	if not r.is_empty():
		var hp_: Vector3 = r["position"]
		var n: Vector3 = r["normal"]
		if bounce > 0:
			bounce -= 1
			velocity = velocity.bounce(n) * 0.7
			to = hp_ + n * 0.05
			_issue_visual(to)
		else:
			to = hp_
			if _check_fighters(w, from, to):
				return
			global_position = to
			_terminate()
			return
	if _check_fighters(w, from, to):
		return
	traveled += from.distance_to(to)
	global_position = to
	if traveled >= max_range or _age >= max_lifetime or to.y < w.bounds.position.y:
		_terminate()


## Returns true if the projectile terminated.
func _check_fighters(w: World, from: Vector3, to: Vector3) -> bool:
	var candidates: Array = []
	for f: Fighter in w.fighters:
		if not is_instance_valid(f) or f.team == team or not f.is_hittable() or _hit_uids.has(f.uid):
			continue
		var base := f.global_position
		var a := base + Vector3(0, f.radius(), 0)
		var b := base + Vector3(0, maxf(f.height() - f.radius(), f.radius()), 0)
		var pts := Geometry3D.get_closest_points_between_segments(from, to, a, b)
		if pts.size() < 2:
			continue
		var d := pts[0].distance_to(pts[1])
		if d <= radius + f.radius():
			candidates.append([from.distance_squared_to(pts[0]), f, pts[0]])
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for c: Array in candidates:
		var f: Fighter = c[1]
		_hit_uids[f.uid] = true
		var src: Fighter = caster if _caster_valid() else null
		if runner != null and _caster_valid():
			runner.deal(f, hit, from)
		else:
			f.receive_hit(src, hit, from)
		if not pierce:
			global_position = c[2]
			_terminate()
			return true
	return false


func _terminate() -> void:
	if not alive:
		return
	if not explode.is_empty():
		var w := World.get_instance()
		var r := SkillRunner.pf(explode, "radius", 2.5)
		var h := Hit.normalize(explode.get("hit", {}))
		if w != null:
			for f: Fighter in w.fighters:
				if not is_instance_valid(f) or f.team == team or not f.is_hittable():
					continue
				if f.center().distance_to(global_position) - f.radius() <= r:
					if runner != null and _caster_valid():
						runner.deal(f, h, global_position)
					else:
						f.receive_hit(caster if _caster_valid() else null, h, global_position)
		CoreUtil.fx(&"play", [StringName(SkillRunner.ps(explode, "fx", "explosion")), global_position, Vector3.UP, color, r / 2.0])
	else:
		CoreUtil.fx(&"play", [&"hit_spark", global_position, velocity.normalized(), color, 0.5])
	finish()


func finish() -> void:
	if not alive:
		return
	alive = false
	CoreUtil.fx(&"despawn", [fx_id])
	queue_free()


## Removed while still alive (World freed / round reset): drop the visual on every peer.
func _exit_tree() -> void:
	if alive:
		alive = false
		if fx_id != 0:
			CoreUtil.fx(&"despawn", [fx_id])
