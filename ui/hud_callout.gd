extends Control
## Brush-calligraphy skill call-out (the donghua's signature): when the local player casts a skill, its CN name
## slams in in Ma Shan Zheng over a diagonal slash band in the class tone, with "职业 · English name" beside it.
## Ultimates use a gold band and a bigger name. One Control, drawn in _draw; processing only while visible.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

const IN_TIME: float = 0.16
const HOLD: float = 1.05
const OUT_TIME: float = 0.35

var skill_name: String = ""
var sub_text: String = ""
var tone: Color = Color("#E0A83A")
var ultimate: bool = false
var shows: int = 0
var _t: float = 99.0
var _seed: int = 5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 170)
	set_process(false)


func show_skill(s: SkillDef, class_cn: String, class_tint: Color) -> void:
	if s == null:
		return
	skill_name = s.name_cn if s.name_cn != "" else s.name_en
	var en := s.name_en
	if en.contains(" ("):
		en = en.substr(0, en.find(" ("))
	sub_text = ("%s · %s" % [class_cn, en]) if class_cn != "" else en
	ultimate = s.is_ultimate()
	# class tone kept saturated and bright enough to read as light behind the ink
	var h := class_tint
	tone = Color.from_hsv(h.h, clampf(h.s, 0.45, 0.85), clampf(h.v, 0.75, 1.0)) if not ultimate else Color("#FFC43A")
	_seed = absi(hash(skill_name)) % 1000
	_t = 0.0
	shows += 1
	set_process(true)
	queue_redraw()


func is_showing() -> bool:
	return _t < IN_TIME + HOLD + OUT_TIME


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not is_showing():
		set_process(false)


func _draw() -> void:
	if not is_showing() or skill_name == "":
		return
	var ci := get_canvas_item()
	var k_in := clampf(_t / IN_TIME, 0.0, 1.0)
	var k_out := clampf((_t - IN_TIME - HOLD) / OUT_TIME, 0.0, 1.0)
	var a := 1.0 - k_out
	var slam := 1.0 + (1.0 - k_in) * 0.5
	var slide := (1.0 - pow(k_in, 0.5)) * -120.0 + k_out * 40.0
	draw_set_transform(Vector2(30 + slide, 40), deg_to_rad(-7.0), Vector2.ONE)
	var band_w := 540.0 if not ultimate else 600.0
	GD.callout_band(ci, Rect2(Vector2(-30, 22), Vector2(band_w * minf(1.0, k_in * 1.4), 96)), tone, _seed, a)
	var f := HudStyle.brush()
	var fs := 128 if ultimate else 116
	var tw := f.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var max_w := band_w * 0.62
	if tw > max_w:
		fs = int(fs * max_w / tw)
		tw = f.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(Vector2(30 + slide, 40), deg_to_rad(-7.0), Vector2(slam, slam))
	var base := Vector2(14, 22 + 96 * 0.5 + f.get_ascent(fs) * 0.36)
	GD.text(ci, f, base, skill_name, fs, Color(1, 1, 1, a), 12, Color(0.22, 0.1, 0.02, 0.95 * a))
	if _t < IN_TIME + 0.12:
		f.draw_string(ci, base, skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tone.lightened(0.6), 0.55 * (1.0 - k_in * 0.6) * a))
	draw_set_transform(Vector2(30 + slide, 40), deg_to_rad(-7.0), Vector2.ONE)
	var sf := HudStyle.sans(600)
	var sw := sf.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var sx := 30.0 + tw * slam + 16.0
	if sx + sw > band_w - 50.0:
		# no room beside the name: tuck it under the band
		GD.text(ci, sf, Vector2(maxf(40.0, band_w - 70.0 - sw), 22 + 96 + 22), sub_text, 16, Color(HudStyle.UI_GOLD_HI, a), 4)
	else:
		GD.text(ci, sf, Vector2(sx, 22 + 66), sub_text, 16, Color(HudStyle.UI_GOLD_HI, a), 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
