extends Control
## Big juicy combo counter ("17 连击 HITS"): pops on every new hit, color heats up with the count,
## shakes slightly on milestones, fades out after the combo drops.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

const MIN_SHOW: int = 2
const FADE_TIME: float = 0.9

var count: int = 0
var best: int = 0
var _shown: int = 0
var _pop: float = 0.0
var _alpha: float = 0.0
var _fade: float = 0.0
var _shake: float = 0.0
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 130)
	set_process(false)


## Called at HUD refresh rate with the local fighter's combo_count.
func set_count(n: int) -> void:
	if n == count:
		return
	if n > count and n >= MIN_SHOW:
		_pop = 1.0
		_alpha = 1.0
		_fade = 0.0
		_shown = n
		if n % 10 == 0:
			_shake = 1.0
		best = maxi(best, n)
		set_process(true)
	elif n < MIN_SHOW and count >= MIN_SHOW:
		_fade = FADE_TIME
		set_process(true)
	count = n


func is_showing() -> bool:
	return _alpha > 0.01


func heat_color(n: int) -> Color:
	if n >= 40:
		return Color(1.0, 0.25, 0.35)
	if n >= 20:
		return Color(1.0, 0.45, 0.15)
	if n >= 10:
		return Color(1.0, 0.75, 0.2)
	return Color(1.0, 0.95, 0.8)


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 5.0)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _fade > 0.0:
		_fade -= delta
		_alpha = clampf(_fade / FADE_TIME, 0.0, 1.0)
	queue_redraw()
	if _alpha <= 0.01 and _pop <= 0.0:
		_alpha = 0.0
		set_process(false)


func _draw() -> void:
	if _alpha <= 0.01 or _shown < MIN_SHOW:
		return
	var col := heat_color(_shown)
	var a := _alpha
	var sc := 1.0 + _pop * 0.45
	var jitter := Vector2(sin(_t * 70.0), cos(_t * 53.0)) * _shake * 4.0
	var num := str(_shown)
	var f := HudStyle.font(true)
	var fs := int(64 * sc)
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(size.x - 12.0, size.y * 0.62) + jitter
	# soft slanted underline swoosh
	var u0 := base + Vector2(-nw - 140, 30)
	var u1 := base + Vector2(6, 22)
	draw_polygon(PackedVector2Array([u0, u1, u1 + Vector2(-6, 7), u0 + Vector2(10, 9)]),
		PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.9 * a),
		Color(col.r, col.g, col.b, 0.6 * a), Color(col.r, col.g, col.b, 0.0)]))
	var np := base + Vector2(-nw - 118, 0)
	draw_string_outline(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.9 * a))
	draw_string_outline(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(col.darkened(0.5), a))
	draw_string(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))
	# white pop flash over the number
	if _pop > 0.0:
		draw_string(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, _pop * 0.6 * a))
	var lp := base + Vector2(-108, -20)
	draw_string_outline(f, lp, "连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, 0.9 * a))
	draw_string(f, lp, "连击", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
	var ep := base + Vector2(-104, 8)
	draw_string_outline(f, ep, "HITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.9 * a))
	draw_string(f, ep, "HITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(col.r, col.g, col.b, a))
