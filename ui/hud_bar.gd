extends Control
## Resource bar drawn in _draw: gradient fill, delayed damage trail, shield overlay, tick marks and text.
## Call set_values(); the trail animates in _process only while it is catching up.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

var value: float = 1.0
var max_value: float = 1.0
var shield: float = 0.0
var fill_color: Color = HudStyle.C_HP
var low_color: Color = Color(0, 0, 0, 0)     # when alpha > 0, fill lerps toward it below 30%
var trail_color: Color = HudStyle.C_TRAIL
var back_color: Color = Color(0.02, 0.025, 0.04, 0.85)
var show_text: bool = true
var text_mode: int = 0                        # 0 = "cur / max", 1 = percent, 2 = cur only, 3 = custom text
var custom_text: String = ""
var font_size: int = 13
var ticks: int = 0                            # tick marks every 1/ticks of the bar
var radius: float = 4.0
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
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var rad := minf(radius, r.size.y * 0.5)
	HudIcons.gradient_rect(self, r, back_color.lightened(0.04), back_color, rad)
	var inner := r.grow(-1.5)
	var frac := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	var trail := clampf(_trail, frac, 1.0)
	if trail > frac:
		var tr := Rect2(inner.position + Vector2(inner.size.x * frac, 0), Vector2(inner.size.x * (trail - frac), inner.size.y))
		draw_rect(tr, trail_color)
	var c := fill_color
	if low_color.a > 0.0 and frac < 0.3:
		c = low_color.lerp(fill_color, frac / 0.3)
	if dead:
		c = Color(0.3, 0.3, 0.32)
	if frac > 0.0:
		var fr := Rect2(inner.position, Vector2(maxf(inner.size.x * frac, 2.0), inner.size.y))
		HudIcons.gradient_rect(self, fr, c.lightened(0.28), c.darkened(0.25), maxf(rad - 1.0, 1.0))
		# top highlight
		draw_rect(Rect2(fr.position + Vector2(1, 1), Vector2(maxf(fr.size.x - 2.0, 0.0), fr.size.y * 0.32)), Color(1, 1, 1, 0.16))
	if shield > 0.0:
		var sf := clampf(shield / maxf(max_value, 0.001), 0.0, 1.0)
		var start := frac
		if frac + sf > 1.0:
			start = 1.0 - sf
		var sr := Rect2(inner.position + Vector2(inner.size.x * start, 0), Vector2(inner.size.x * sf, inner.size.y))
		draw_rect(sr, Color(HudStyle.C_SHIELD.r, HudStyle.C_SHIELD.g, HudStyle.C_SHIELD.b, 0.55))
		# diagonal hatching so the shield reads as an overlay
		var step := 6.0
		var x := sr.position.x
		while x < sr.end.x:
			var x2 := minf(x + sr.size.y * 0.6, sr.end.x)
			draw_line(Vector2(x, sr.end.y), Vector2(x2, sr.position.y), Color(1, 1, 1, 0.55), 1.0)
			x += step
		draw_rect(sr, Color(1, 1, 1, 0.9), false, 1.0)
	if ticks > 1:
		for i in range(1, ticks):
			var tx := inner.position.x + inner.size.x * float(i) / float(ticks)
			draw_line(Vector2(tx, inner.position.y + 1), Vector2(tx, inner.end.y - 1), Color(0, 0, 0, 0.35), 1.0)
	HudIcons.outline_rect(self, r, Color(0, 0, 0, 0.8), 1.0, rad)
	if show_text and r.size.y >= 9.0:
		var t := _text()
		if t != "":
			var f := HudStyle.font(true)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var pos := Vector2((r.size.x - w) * 0.5, (r.size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5)
			draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.9))
			draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudStyle.C_TEXT)


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
