extends Control
## Screen-space overlay for 3D things, drawn in one _draw per frame (no per-fighter nodes):
## overhead nameplates (name + hp bar, team colored, hidden for stealthed enemies), the lock-on reticle
## projected on the target, and the center crosshair.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

const MAX_DIST: float = 45.0
const PLATE_W: float = 86.0
const PLATE_H: float = 7.0

var world: World = null
var viewer: Fighter = null
var show_plates: bool = true
var show_crosshair: bool = true
var _t: float = 0.0
var _lock_uid: int = 0
var _lock_anim: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_lock_anim = minf(1.0, _lock_anim + delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if world != null and is_instance_valid(world) and cam != null:
		if show_plates:
			_draw_plates(cam)
		_draw_reticle(cam)
	if show_crosshair:
		_draw_crosshair()


func _visible_to_viewer(f: Fighter) -> bool:
	if not f.is_stealthed:
		return true
	return viewer != null and is_instance_valid(viewer) and viewer.team == f.team


func _draw_plates(cam: Camera3D) -> void:
	var font := HudStyle.font(true)
	var cam_pos := cam.global_position
	var lock := viewer.get_target() if viewer != null and is_instance_valid(viewer) else null
	for f: Fighter in world.fighters:
		if not is_instance_valid(f) or f == viewer or not f.is_inside_tree():
			continue
		if not f.is_alive() or f.kind == "boss":
			continue
		if not _visible_to_viewer(f):
			continue
		var head := f.global_position + Vector3(0.0, f.height() + 0.45, 0.0)
		var dist := cam_pos.distance_to(head)
		if dist > MAX_DIST or cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		if sp.x < -100 or sp.y < -60 or sp.x > size.x + 100 or sp.y > size.y + 60:
			continue
		var enemy := viewer != null and is_instance_valid(viewer) and f.team != viewer.team
		var col := HudStyle.C_ENEMY if enemy else HudStyle.C_ALLY
		var fade := clampf(1.0 - (dist - 25.0) / (MAX_DIST - 25.0), 0.25, 1.0)
		var alpha := fade * (0.45 if f.is_stealthed else 1.0)
		var summon := f.kind == "summon"
		var w := PLATE_W * (0.7 if summon else 1.0)
		var h := PLATE_H * (0.8 if summon else 1.0)
		var is_lock := f == lock
		var bar := Rect2(sp + Vector2(-w * 0.5, 0), Vector2(w, h))
		# name
		if not summon or dist < 18.0:
			var nm := f.display_name
			var fs := 14 if not summon else 11
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var np := Vector2(sp.x - tw * 0.5, sp.y - 5.0)
			var name_col := col.lerp(Color.WHITE, 0.45)
			if is_lock:
				name_col = Color(1, 0.9, 0.5)
			draw_string_outline(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85 * alpha))
			draw_string(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(name_col.r, name_col.g, name_col.b, alpha))
			# class glyph badge left of the name
			if f.kit != null and not summon:
				var bc := Vector2(np.x - 11.0, sp.y - 10.0)
				draw_circle(bc, 8.5, Color(0, 0, 0, 0.7 * alpha))
				draw_circle(bc, 7.0, Color(HudStyle.class_color(f).darkened(0.4), alpha))
				HudIcons.glyph(self, bc, HudStyle.class_glyph(f), 10, Color(1, 1, 1, alpha), 0)
		# hp bar
		draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.8 * alpha))
		var frac := clampf(f.hp / maxf(f.max_hp, 1.0), 0.0, 1.0)
		var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
		draw_rect(fill, Color(col.r, col.g, col.b, alpha))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Color(1, 1, 1, 0.22 * alpha))
		if f.shield_hp > 0.0:
			var sf := clampf(f.shield_hp / maxf(f.max_hp, 1.0), 0.0, 1.0)
			var sx := minf(frac, 1.0 - sf)
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * sx, 0), Vector2(bar.size.x * sf, bar.size.y)),
				Color(1, 1, 1, 0.6 * alpha))
		if is_lock:
			draw_rect(bar.grow(2.0), Color(1, 0.85, 0.35, alpha), false, 1.5)
		# status hint: a few dots for active debuffs/buffs (full icons live in the frames)
		if f.status_mask != 0 and dist < 25.0:
			var n := 0
			for bit in HudStyle.STATUS_INFO.size():
				if (f.status_mask >> bit) & 1:
					var r := Rect2(bar.position + Vector2(n * 13.0, h + 3.0), Vector2(12, 12))
					HudIcons.draw_status_icon(self, r, bit)
					n += 1
					if n >= 6:
						break


func _draw_reticle(cam: Camera3D) -> void:
	if viewer == null or not is_instance_valid(viewer):
		return
	var t := viewer.get_target()
	if t == null or not _visible_to_viewer(t):
		_lock_uid = 0
		return
	if t.uid != _lock_uid:
		_lock_uid = t.uid
		_lock_anim = 0.0
	var p := t.center()
	if cam.is_position_behind(p):
		return
	var sp := cam.unproject_position(p)
	var dist := cam.global_position.distance_to(p)
	var base_r := clampf(900.0 / maxf(dist, 1.0), 26.0, 90.0) * t.body_scale
	var r := base_r * (1.0 + (1.0 - _lock_anim) * 1.2)
	var a := 0.55 + 0.45 * _lock_anim
	var col := HudStyle.C_ENEMY if t.team != viewer.team else HudStyle.C_ALLY
	var gold := Color(1, 0.85, 0.35, a)
	var rot := _t * 1.2
	for i in 4:
		var ang := rot + i * PI * 0.5
		draw_arc(sp, r, ang - 0.38, ang + 0.38, 12, gold, 2.5, true)
		var tip := sp + Vector2(cos(ang), sin(ang)) * (r + 2.0)
		var inward := Vector2(cos(ang), sin(ang))
		var side := Vector2(-inward.y, inward.x)
		draw_colored_polygon(PackedVector2Array([tip - inward * 9.0, tip + side * 5.0, tip - side * 5.0]),
			Color(col.r, col.g, col.b, a))
	draw_arc(sp, r * 0.55, 0, TAU, 32, Color(1, 1, 1, 0.25 * a), 1.0, true)


func _draw_crosshair() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.85)
	var sh := Color(0, 0, 0, 0.6)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 5.0, c + d * 13.0, sh, 4.0)
		draw_line(c + d * 5.0, c + d * 13.0, col, 2.0)
	draw_circle(c, 2.5, sh)
	draw_circle(c, 1.5, col)
