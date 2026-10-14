extends PanelContainer
## Top-center match info: mode name, round timer (or raid clear timer), team score and alive pips.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

const MODE_NAMES: Dictionary = {
	"duel": "个人赛 Individual", "arena": "擂台赛 Group Arena", "team": "团体赛 Team Battle", "raid": "副本 Raid",
}


class Pips extends Control:
	var alive: Array[int] = [0, 0]
	var total: Array[int] = [0, 0]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 14)

	func set_counts(a0: int, t0: int, a1: int, t1: int) -> void:
		if a0 == alive[0] and a1 == alive[1] and t0 == total[0] and t1 == total[1]:
			return
		alive = [a0, a1]
		total = [t0, t1]
		queue_redraw()

	func _draw() -> void:
		var cx := size.x * 0.5
		for team in 2:
			var c := HudStyle.team_color(team)
			for i in total[team]:
				var x := cx - 22.0 - i * 14.0 if team == 0 else cx + 22.0 + i * 14.0
				var p := Vector2(x, size.y * 0.5)
				if i < alive[team]:
					GD.diamond(get_canvas_item(), p, 4.5, 6.0, c)
				else:
					GD.polyline(get_canvas_item(), PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(4, 0), p + Vector2(0, 5.5), p + Vector2(-4, 0)]),
						Color(c, 0.45), 1.0, true)


var mode_label: Label
var timer_label: Label
var left_score: Label
var right_score: Label
var extra_label: Label
var pips: Pips
var _t: float = 0.0
var _urgent: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.glory("panel", 0.0)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(320, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	mode_label = HudStyle.make_label("", 12, HudStyle.UI_GOLD_HI, false, 3)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(mode_label)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 18)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hb)
	left_score = HudStyle.make_label_f("", HudStyle.crit(), 30, HudStyle.team_color(0).lightened(0.25), 6)
	left_score.custom_minimum_size = Vector2(50, 0)
	left_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(left_score)
	timer_label = HudStyle.make_label_f("--:--", HudStyle.num(650), 40, HudStyle.UI_GOLD_HI, 5)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.custom_minimum_size = Vector2(110, 0)
	hb.add_child(timer_label)
	right_score = HudStyle.make_label_f("", HudStyle.crit(), 30, HudStyle.team_color(1).lightened(0.2), 6)
	right_score.custom_minimum_size = Vector2(50, 0)
	hb.add_child(right_score)
	pips = Pips.new()
	vb.add_child(pips)
	extra_label = HudStyle.make_label("", 13, HudStyle.C_TEXT, false, 3)
	extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(extra_label)
	set_process(false)


static func mode_text(mode: String) -> String:
	return str(MODE_NAMES.get(mode, mode))


static func _score_value(score: Dictionary, team: int) -> Variant:
	for k: Variant in [team, str(team), "team%d" % team, "t%d" % team, "wins%d" % team]:
		if score.has(k):
			return score[k]
	var wins: Variant = score.get("wins", null)
	if wins is Array and (wins as Array).size() > team:
		return (wins as Array)[team]
	if wins is Dictionary and ((wins as Dictionary).has(team) or (wins as Dictionary).has(str(team))):
		return (wins as Dictionary).get(team, (wins as Dictionary).get(str(team)))
	return null


func set_mode(mode: String) -> void:
	mode_label.text = mode_text(mode) if mode != "" else "训练 Sandbox"


## `seconds` < 0 hides the timer; raid shows a clear timer (count-up) with its own caption.
func set_timer(seconds: float, count_up: bool) -> void:
	if seconds < 0.0:
		timer_label.text = "--:--"
		_urgent = false
	else:
		timer_label.text = HudStyle.fmt_time(seconds) if not count_up else "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
		_urgent = not count_up and seconds <= 10.0 and seconds > 0.0
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if _urgent else HudStyle.UI_GOLD_HI)
	set_process(_urgent)
	if not _urgent:
		timer_label.scale = Vector2.ONE


func set_score(score: Dictionary, raid: bool) -> void:
	var a: Variant = _score_value(score, 0)
	var b: Variant = _score_value(score, 1)
	left_score.text = str(a) if a != null and not raid else ""
	right_score.text = str(b) if b != null and not raid else ""
	var extra := ""
	if score.has("text"):
		extra = str(score["text"])
	elif score.get("remaining", null) is Array and (score["remaining"] as Array).size() == 2:
		var rem: Array = score["remaining"]
		extra = "剩余 Remaining  %s : %s" % [str(rem[0]), str(rem[1])]
	elif score.has("remaining0") or score.has("remaining1"):
		extra = "剩余 Remaining  %s : %s" % [str(score.get("remaining0", "-")), str(score.get("remaining1", "-"))]
	elif raid and score.has("encounter"):
		# MatchRaid: encounter is a 0-based index
		extra = "进度 Progress %d / %d" % [int(score["encounter"]) + 1, int(score.get("encounters", int(score["encounter"]) + 1))]
		var nm := ("%s %s" % [str(score.get("name_cn", "")), str(score.get("name_en", ""))]).strip_edges()
		if nm != "":
			extra += "  " + nm
	elif score.has("round"):
		extra = "第 %s 局 Round %s" % [str(score["round"]), str(score["round"])]
	extra_label.text = extra
	extra_label.visible = extra != ""


func _process(delta: float) -> void:
	_t += delta
	timer_label.pivot_offset = timer_label.size * 0.5
	var s := 1.0 + 0.08 * maxf(0.0, sin(_t * TAU))
	timer_label.scale = Vector2(s, s)
