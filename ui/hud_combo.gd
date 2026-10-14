extends Control
## Combo counter (look-dev: Russo One gold digits, 连击, slash underline): pops on every new hit, colour heats up,
## shakes slightly on milestones, fades out after the combo drops.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

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
		return Color("#FF4A5A")
	if n >= 20:
		return Color("#FF8A2A")
	return Color("#FFC43A")


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
	var ci := get_canvas_item()
	var col := heat_color(_shown)
	var a := _alpha
	var sc := 1.0 + _pop * 0.4
	var jitter := Vector2(sin(_t * 70.0), cos(_t * 53.0)) * _shake * 4.0
	draw_set_transform(Vector2(20, size.y * 0.72) + jitter, deg_to_rad(-4.0), Vector2.ONE)
	var num := str(_shown)
	var f := HudStyle.crit()
	var fs := int(76 * sc)
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color(0.2, 0.08, 0.02, 0.95 * a)
	# slash underline band in the heat colour
	GD.callout_band(ci, Rect2(Vector2(-6, 10), Vector2(nw + 130, 10)), col, 11, 0.9 * a)
	GD.text(ci, f, Vector2(0, 0), num, fs, Color(col, a), 8, ink)
	if _pop > 0.0:
		f.draw_string(ci, Vector2(0, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, _pop * 0.55 * a))
	var lf := HudStyle.sans(800)
	GD.text(ci, lf, Vector2(nw + 12, -10), "连击", 34, Color(HudStyle.UI_GOLD_HI, a), 6, ink)
	GD.text(ci, HudStyle.tech(800), Vector2(nw + 14, 8), "HITS", 14, Color(col, 0.9 * a), 4, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
