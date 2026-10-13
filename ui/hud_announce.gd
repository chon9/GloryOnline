extends Control
## Center announcement banner (bilingual, animated): band sweeps open, text slides in, holds, fades.
## Messages queue; a new one with priority replaces the current one immediately.

const HudStyle := preload("res://ui/hud_style.gd")

const IN_TIME: float = 0.28
const OUT_TIME: float = 0.35

var _queue: Array = []          # [text, seconds, color]
var _text: String = ""
var _color: Color = HudStyle.C_GOLD
var _dur: float = 0.0
var _t: float = 0.0
var _active: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func show_text(text: String, seconds: float = 2.0, color: Color = HudStyle.C_GOLD, interrupt: bool = false) -> void:
	if text.strip_edges() == "":
		return
	if interrupt or not _active:
		_queue.clear()
		_start(text, seconds, color)
	else:
		_queue.append([text, seconds, color])
		if _queue.size() > 4:
			_queue.pop_front()


func current_text() -> String:
	return _text if _active else ""


func _start(text: String, seconds: float, color: Color) -> void:
	_text = text
	_dur = maxf(seconds, 0.8)
	_color = color
	_t = 0.0
	_active = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur + OUT_TIME:
		_active = false
		if _queue.size() > 0:
			var q: Array = _queue.pop_front()
			_start(q[0], q[1], q[2])
		else:
			set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var open := clampf(_t / IN_TIME, 0.0, 1.0)
	open = 1.0 - pow(1.0 - open, 3.0)
	var out := clampf((_t - _dur) / OUT_TIME, 0.0, 1.0)
	var a := 1.0 - out
	var lines := _text.split("\n")
	var main := lines[0]
	var sub := "\n".join(lines.slice(1)) if lines.size() > 1 else ""
	var band_h := (100.0 if sub != "" else 76.0) * (0.35 + 0.65 * open)
	var cy := size.y * 0.5
	var w := size.x
	# band: transparent edges, dark middle
	var mid := Color(0.02, 0.02, 0.04, 0.7 * a)
	var edge := Color(0.02, 0.02, 0.04, 0.0)
	var x0 := w * 0.5 - w * 0.42 * open
	var x1 := w * 0.5 + w * 0.42 * open
	var top := cy - band_h * 0.5
	var bot := cy + band_h * 0.5
	var xm0 := lerpf(x0, x1, 0.25)
	var xm1 := lerpf(x0, x1, 0.75)
	draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(xm0, top), Vector2(xm0, bot), Vector2(x0, bot)]),
		PackedColorArray([edge, mid, mid, edge]))
	draw_rect(Rect2(xm0, top, xm1 - xm0, band_h), mid)
	draw_polygon(PackedVector2Array([Vector2(xm1, top), Vector2(x1, top), Vector2(x1, bot), Vector2(xm1, bot)]),
		PackedColorArray([mid, edge, edge, mid]))
	var gl := Color(_color.r, _color.g, _color.b, 0.85 * a)
	var gl0 := Color(_color.r, _color.g, _color.b, 0.0)
	for y: float in [top, bot]:
		draw_polygon(PackedVector2Array([Vector2(x0, y - 1), Vector2(w * 0.5, y - 1), Vector2(w * 0.5, y + 1), Vector2(x0, y + 1)]),
			PackedColorArray([gl0, gl, gl, gl0]))
		draw_polygon(PackedVector2Array([Vector2(w * 0.5, y - 1), Vector2(x1, y - 1), Vector2(x1, y + 1), Vector2(w * 0.5, y + 1)]),
			PackedColorArray([gl, gl0, gl0, gl]))
	# text
	var f := HudStyle.font(true)
	var slide := (1.0 - open) * 60.0 - out * 40.0
	var fs := 40
	var tw := f.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > w * 0.8:
		fs = int(fs * w * 0.8 / tw)
		tw = f.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := cy + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - (14.0 if sub != "" else 0.0)
	var tp := Vector2((w - tw) * 0.5 + slide, ty)
	draw_string_outline(f, tp, main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.9 * a))
	draw_string(f, tp, main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_color.r, _color.g, _color.b, a * open))
	if _t < IN_TIME + 0.15:
		var fl := clampf(1.0 - (_t - IN_TIME) / 0.15, 0.0, 1.0) if _t > IN_TIME else open
		draw_string(f, tp, main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5 * fl * a))
	if sub != "":
		var sf := HudStyle.font(false)
		var ss := 20
		var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		if sw > w * 0.8:
			ss = maxi(12, int(ss * w * 0.8 / sw))
			sw = sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var sp := Vector2((w - sw) * 0.5 - slide * 0.5, ty + 32.0)
		draw_string_outline(sf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 5, Color(0, 0, 0, 0.9 * a))
		draw_string(sf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(1, 1, 1, 0.9 * a * open))


static func _is_cjk(c: int) -> bool:
	return (c >= 0x3000 and c <= 0x9FFF) or (c >= 0xFF00 and c <= 0xFFEF)


## Splits "中文 English" after the last CJK character (when the rest is non-CJK text): [cn, en] or [text, ""].
static func split_bilingual(text: String) -> PackedStringArray:
	var last := -1
	for i in text.length():
		if _is_cjk(text.unicode_at(i)):
			last = i
	if last < 0 or last >= text.length() - 1:
		return PackedStringArray([text, ""])
	var head := text.substr(0, last + 1).strip_edges()
	var tail := text.substr(last + 1).strip_edges()
	if tail == "" or head == "":
		return PackedStringArray([text, ""])
	return PackedStringArray([head, tail])
