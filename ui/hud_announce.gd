extends Control
## Center announcement banner (bilingual, animated): band sweeps open, text slides in, holds, fades.
## Messages queue; a new one with priority replaces the current one immediately.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

const IN_TIME: float = 0.28
const OUT_TIME: float = 0.35

var _queue: Array = []          # [text, seconds, color]
var _text: String = ""
var _color: Color = HudStyle.C_GOLD
var _dur: float = 0.0
var _t: float = 0.0
var _active: bool = false
## Compact "mechanic warning" style (boss call-outs): a narrower, shorter band in the upper screen band that slides
## in from the side and auto-fades after at most `max_hold` seconds. Round / victory banners use the full style.
var compact: bool = false
var max_hold: float = 2.5


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
	_dur = clampf(seconds, 0.8, max_hold) if compact else maxf(seconds, 0.8)
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
	var band_h := (138.0 if sub != "" else 112.0) * (0.35 + 0.65 * open)
	if compact:
		band_h = (78.0 if sub != "" else 64.0) * (0.6 + 0.4 * open)
	var cy := size.y * 0.5
	var w := size.x
	# band: transparent edges, dark middle
	var mid := Color(0.035, 0.07, 0.13, (0.74 if compact else 0.82) * a)
	var edge := Color(0.035, 0.07, 0.13, 0.0)
	var half := w * (0.24 if compact else 0.42)
	var x0 := w * 0.5 - half * open
	var x1 := w * 0.5 + half * open
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
	# text: CN headline in brush calligraphy, the English half in condensed caps below, sub lines last
	var parts := split_bilingual(main)
	var head := parts[0]
	var en := parts[1]
	var ci := get_canvas_item()
	var ink := Color(0.12, 0.06, 0.0, 0.92 * a)
	var slide := (1.0 - open) * (120.0 if compact else 60.0) - out * 40.0
	var f := HudStyle.brush() if _has_cjk(head) else HudStyle.crit()
	var fs := 64 if _has_cjk(head) else 44
	if compact:
		fs = 34 if _has_cjk(head) else 26
	var maxw := w * (0.46 if compact else 0.8)
	var tw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > maxw:
		fs = int(fs * maxw / tw)
		tw = f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lines_below := (1 if en != "" else 0) + (1 if sub != "" else 0)
	var ty := cy + f.get_ascent(fs) * 0.42 - lines_below * (9.0 if compact else 13.0)
	var tp := Vector2((w - tw) * 0.5 + slide, ty)
	GD.text(ci, f, tp, head, fs, Color(_color.lerp(Color.WHITE, 0.25), a * open), 9, ink)
	if _t < IN_TIME + 0.15:
		var fl := clampf(1.0 - (_t - IN_TIME) / 0.15, 0.0, 1.0) if _t > IN_TIME else open
		f.draw_string(ci, tp, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5 * fl * a))
	var y2 := ty + (20.0 if compact else 30.0)
	if en != "":
		var ef := HudStyle.tech(800)
		var es := 13 if compact else 18
		var ew := ef.get_string_size(en.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
		GD.text(ci, ef, Vector2((w - ew) * 0.5 - slide * 0.5, y2), en.to_upper(), es, Color(HudStyle.UI_GOLD_HI, 0.95 * a * open), 4)
		y2 += 26.0
	if sub != "":
		var sf := HudStyle.sans(600)
		var ss := 19
		var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		if sw > w * 0.8:
			ss = maxi(12, int(ss * w * 0.8 / sw))
			sw = sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		GD.text(ci, sf, Vector2((w - sw) * 0.5 - slide * 0.5, y2), sub, ss, Color(1, 1, 1, 0.92 * a * open), 5)


static func _has_cjk(t: String) -> bool:
	for k in t.length():
		if _is_cjk(t.unicode_at(k)):
			return true
	return false


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
