class_name VfxRibbon
extends MeshInstance3D
## Camera-facing light-streak ribbon behind a moving point (projectile trails). top_level, rebuilt each frame
## from a short position history into an ImmediateMesh (a few dozen vertices), drawn with vfx_trail.gdshader
## (white-hot centre line, element colour, razor taper). After `detach()` it keeps shrinking toward the head
## for `linger` seconds, so a despawned projectile's trail never pops.

const Lib := preload("res://visuals/vfx_lib.gd")

var width := 0.25
var max_points := 12
var min_step := 0.12
var linger := 0.22
var dying := false
var _pts: PackedVector3Array = PackedVector3Array()
var _im: ImmediateMesh
var _die_t := 0.0


func setup(pal: Array, w: float, points := 12, energy := 3.0) -> void:
	top_level = true
	width = w
	max_points = points
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	material_override = Lib.trail_mat()
	Lib.set_pal(self, pal)
	set_instance_shader_parameter(&"energy", energy)
	set_instance_shader_parameter(&"fade", 1.0)
	extra_cull_margin = 4.0


## Moves the head to `p`; a new joint is kept once the head is `min_step` past the previous joint.
func push(p: Vector3) -> void:
	if _pts.size() < 2 or _pts[1].distance_squared_to(p) > min_step * min_step:
		_pts.insert(0, p)
		if _pts.size() > max_points:
			_pts.resize(max_points)
	else:
		_pts[0] = p


func detach() -> void:
	dying = true
	_die_t = 0.0


## Returns false when a dying ribbon has fully shrunk.
func tick(delta: float, cam: Camera3D) -> bool:
	if dying:
		_die_t += delta
		if _die_t >= linger or _pts.size() < 2:
			return false
		set_instance_shader_parameter(&"fade", 1.0 - _die_t / linger)
		if _pts.size() > 2 and _die_t > linger * 0.3:
			_pts.resize(_pts.size() - 1)
	_rebuild(cam)
	return true


func _rebuild(cam: Camera3D) -> void:
	_im.clear_surfaces()
	var n := _pts.size()
	if n < 2 or cam == null:
		return
	var eye := cam.global_position
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var p := _pts[i]
		var t := _pts[maxi(i - 1, 0)] - _pts[mini(i + 1, n - 1)]
		var side := t.cross(eye - p)
		side = side.normalized() if side.length_squared() > 1e-8 else Vector3.UP
		var u := float(i) / float(n - 1)
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex(p - side * width * 0.5)
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex(p + side * width * 0.5)
	_im.surface_end()
