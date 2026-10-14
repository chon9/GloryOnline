extends Control
## Circular minimap (bible 6.2 / look-dev): navy disc, arena bounds, gold rim with compass ticks, fighter dots
## (allies blue, enemies red, bosses orange, stealthed enemies hidden), player arrow. Camera-up orientation:
## the camera's forward is always the top of the disc. Redraws at REFRESH_HZ.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

const RANGE: float = 38.0     # metres from the centre to the rim
const REFRESH_HZ: float = 15.0

var world: World = null
var viewer: Fighter = null
var caption: String = ""
var _accum: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(176, 200)


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= 1.0 / REFRESH_HZ:
		_accum = 0.0
		queue_redraw()


func _basis() -> Array:
	var fwd := Vector3(0, 0, -1)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		fwd = -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	return [fwd, Vector3(-fwd.z, 0, fwd.x)]


func _draw() -> void:
	var ci := get_canvas_item()
	var rad := size.x * 0.5 - 8.0
	var c := Vector2(size.x * 0.5, size.x * 0.5)
	GD.circle(ci, c, rad, Color(0.06, 0.12, 0.2, 0.88))
	GD.arc(ci, c, rad * 0.5, 0, TAU, Color(GD.CYAN, 0.12), 1.0, 40)
	GD.line(ci, c - Vector2(rad, 0), c + Vector2(rad, 0), Color(GD.CYAN, 0.08))
	GD.line(ci, c - Vector2(0, rad), c + Vector2(0, rad), Color(GD.CYAN, 0.08))
	var origin := Vector3.ZERO
	var have := world != null and is_instance_valid(world)
	var me := viewer if viewer != null and is_instance_valid(viewer) else null
	if me != null:
		origin = me.global_position
	var b := _basis()
	var fwd: Vector3 = b[0]
	var right: Vector3 = b[1]
	var to_map := func(p: Vector3) -> Vector2:
		var d := p - origin
		return c + Vector2(d.dot(right), -d.dot(fwd)) / RANGE * rad
	# arena bounds clipped to the disc
	var disc := PackedVector2Array()
	for i in 48:
		disc.append(c + Vector2(cos(TAU * i / 48.0), sin(TAU * i / 48.0)) * (rad - 1.0))
	if have:
		var bb: AABB = world.bounds
		var corners := PackedVector2Array([to_map.call(Vector3(bb.position.x, 0, bb.position.z)), to_map.call(Vector3(bb.end.x, 0, bb.position.z)),
			to_map.call(Vector3(bb.end.x, 0, bb.end.z)), to_map.call(Vector3(bb.position.x, 0, bb.end.z))])
		for pl in Geometry2D.intersect_polygons(corners, disc):
			GD.poly(ci, pl, Color(0.16, 0.3, 0.42, 0.45))
		for i in 4:
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([corners[i], corners[(i + 1) % 4]]), disc):
				GD.polyline(ci, seg, Color(GD.CYAN, 0.75), 1.5)
		# fighters
		for f: Fighter in world.fighters:
			if not is_instance_valid(f) or f == me or not f.is_alive():
				continue
			var ally := me != null and f.team == me.team
			if f.is_stealthed and not ally:
				continue
			var p: Vector2 = to_map.call(f.global_position)
			var d := p - c
			if d.length() > rad - 5.0:
				p = c + d.normalized() * (rad - 5.0)
			var col := HudStyle.C_ALLY if ally else HudStyle.C_ENEMY
			var r := 4.0
			if f.kind == "boss":
				col = HudStyle.C_BOSS
				r = 7.0
			elif f.kind == "mob":
				r = 3.0
			elif f.kind == "summon":
				r = 2.5
			GD.circle(ci, p, r + 1.5, Color(0, 0, 0, 0.7))
			GD.circle(ci, p, r, col.lightened(0.15))
	# player arrow (pointing along the fighter's facing, in camera space)
	var dir := Vector2(0, -1)
	if me != null:
		var fv := me.forward()
		dir = Vector2(fv.dot(right), -fv.dot(fwd)).normalized()
	var side := Vector2(-dir.y, dir.x)
	GD.poly(ci, PackedVector2Array([c + dir * 10.0, c - dir * 6.0 + side * 6.5, c - dir * 2.0, c - dir * 6.0 - side * 6.5]), Color.WHITE)
	# view cone
	GD.poly(ci, PackedVector2Array([c, c + Vector2(-0.55, -1).normalized() * rad * 0.9, c + Vector2(0.55, -1).normalized() * rad * 0.9]),
		Color(1, 1, 1, 0.05))
	GD.minimap_rim(ci, c, rad)
	# north marker on the rim
	var n3 := Vector3(0, 0, -1)
	var nd := Vector2(n3.dot(right), -n3.dot(fwd)).normalized()
	var np := c + nd * (rad + 4.0)
	GD.circle(ci, np, 8.0, Color(0.03, 0.06, 0.11, 0.95))
	GD.text_c(ci, HudStyle.sans(800), np, "北", 10, HudStyle.UI_GOLD_HI)
	if caption != "":
		var f2 := HudStyle.sans(600)
		var w := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		GD.text(ci, f2, Vector2(size.x * 0.5 - w * 0.5, size.x + 14.0), caption, 13, HudStyle.C_TEXT, 3)
