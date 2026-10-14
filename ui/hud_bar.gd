extends Control
## Slanted glossy resource bar (bible 6.2): dark back, trailing damage bar, gloss band, 10% ticks, shield overlay,
## leading-edge highlight and Teko numbers.
## Call set_values(); the trail animates in _process only while it is catching up.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

var value: float = 1.0
var max_value: float = 1.0
var shield: float = 0.0
var fill_color: Color = HudStyle.C_HP
var low_color: Color = Color(0, 0, 0, 0)     # when alpha > 0, fill lerps toward it below 30%
var trail_color: Color = HudStyle.C_TRAIL      # trailing "damage taken" bar
var back_color: Color = Color(0.02, 0.025, 0.04, 0.85)
var show_text: bool = true
var text_mode: int = 0                        # 0 = "cur / max", 1 = percent, 2 = cur only, 3 = custom text
var custom_text: String = ""
var font_size: int = 13
var ticks: int = 0                            # tick marks every 1/ticks of the bar
var radius: float = 4.0
var frame_color: Color = HudStyle.UI_GOLD     # outline of the slanted bar (alpha 0 = none)
var text_align: int = 0                       # 0 = centre, 1 = right
var dead: bool = false

var _trail: float = 1.0
var _trail_hold: float = 0.0
var _shown_text: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_values(v: float, m: float, sh: float = 0.0) -> void:
	m = maxf(m, 0.001)
	v = clampf(v, 0.0, m)
	if is_equal_approx(v, value) and is_equal_approx(m, max_value) and is_equal_approx(sh, shield):
		return
	var frac_new := v / m
	var frac_old := value / maxf(max_value, 0.001)
	if frac_new < frac_old - 0.0005:
		# a fresh loss: hold the trail where it is, then let it catch up
		_trail = maxf(_trail, frac_old)
		_trail_hold = 0.45
		set_process(true)
	elif frac_new >= _trail:
		_trail = frac_new
	value = v
	max_value = m
	shield = maxf(0.0, sh)
	queue_redraw()


## Snap the trail (e.g. after binding to a different fighter).
func snap() -> void:
	_trail = value / maxf(max_value, 0.001)
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var target := value / maxf(max_value, 0.001)
	if _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail = move_toward(_trail, target, delta * maxf(0.35, (_trail - target) * 3.0))
	if _trail <= target + 0.0005:
		_trail = target
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0 or r.size.y < 3.0:
		return
	var ci := get_canvas_item()
	var frac := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	var trail := clampf(_trail, frac, 1.0)
	var c := fill_color
	if low_color.a > 0.0 and frac < 0.3:
		c = low_color.lerp(fill_color, frac / 0.3)
	if dead:
		c = Color(0.3, 0.3, 0.32)
	var sf := clampf(shield / maxf(max_value, 0.001), 0.0, 1.0)
	GD.bar(ci, r, frac, trail, c, trail_color, frame_color, ticks, sf)
	if show_text and r.size.y >= 9.0:
		var t := _text()
		if t != "":
			var numeric := not _has_cjk(t)
			var f: Font = HudStyle.num(600) if numeric else HudStyle.font(true)
			var fs := int(font_size * 1.35) if numeric else font_size
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x := (r.size.x - w) * 0.5
			if text_align == 1:
				x = r.size.x - w - r.size.y * 0.9 - 4.0
			var asc := f.get_ascent(fs)
			var desc := f.get_descent(fs)
			var y := (r.size.y + asc - desc) * 0.5
			if numeric:
				y = r.size.y * 0.5 + asc * 0.36
			GD.text(ci, f, Vector2(x, y), t, fs, HudStyle.C_TEXT, 4)


func _text() -> String:
	match text_mode:
		0:
			var s := "%d / %d" % [int(ceil(value)), int(max_value)]
			if shield > 0.5:
				s += "  (+%d)" % int(shield)
			return s
		1:
			return "%d%%" % int(ceil(value / maxf(max_value, 0.001) * 100.0))
		2:
			return str(int(ceil(value)))
		_:
			return custom_text


static func _has_cjk(t: String) -> bool:
	for i in t.length():
		if t.unicode_at(i) >= 0x2E80:
			return true
	return false
