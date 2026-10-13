extends CanvasLayer
## Results screen (owner: NET), shown by modes/match_scene.gd when the Match emits match_ended.
## Winner, MVP, per-player stats table; raid: clear time + local best record (user://records.json).
## Host: "返回房间 Back to Lobby" (also automatic after _game().results_auto_return seconds).

signal back_pressed
signal leave_pressed

const THEME_PATH: String = "res://ui/theme.tres"
const RECORDS_PATH: String = "user://records.json"
const TEAM_NAMES: Array[String] = ["蓝队 Blue Team", "红队 Red Team"]

var result: Dictionary = {}
var _countdown: Label
var _auto_left: float = -1.0


func _init() -> void:
	layer = 30
	name = "Results"


## Builds the screen for `res` (Match result dict, see modes/match.gd).
func show_result(res: Dictionary, is_host: bool, auto_return: float = 0.0) -> void:
	result = res
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = winner_text(res)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var stats: Dictionary = res.get("stats", {})
	var mvp := int(res.get("mvp_uid", -1))
	if stats.has(mvp):
		var ml := Label.new()
		var ms: Dictionary = stats[mvp]
		ml.text = "MVP 全场最佳: %s (%s)" % [str(ms.get("name", "")), _class_label(str(ms.get("class_id", "")))]
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.add_theme_font_size_override("font_size", 22)
		v.add_child(ml)
	var mode := str(res.get("mode", ""))
	if mode == "raid":
		var rl := Label.new()
		rl.text = raid_time_text(res)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rl)
	var sc: Dictionary = res.get("score", {})
	if sc.get("wins") is Array and mode != "raid":
		var w: Array = sc["wins"]
		if w.size() >= 2:
			var sl := Label.new()
			sl.text = "比分 Score  %d : %d" % [int(w[0]), int(w[1])]
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(sl)
	v.add_child(_stats_table(stats, mvp, mode == "raid"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	v.add_child(bar)
	_countdown = Label.new()
	bar.add_child(_countdown)
	if is_host:
		var back := Button.new()
		back.text = "返回房间 Back to Lobby"
		back.pressed.connect(func() -> void: back_pressed.emit())
		bar.add_child(back)
		_auto_left = auto_return if auto_return > 0.0 else -1.0
	else:
		_countdown.text = "等待房主 Waiting for host..."
	var leave := Button.new()
	leave.text = "离开 Leave to Menu"
	leave.pressed.connect(func() -> void: leave_pressed.emit())
	bar.add_child(leave)


func _process(delta: float) -> void:
	if _auto_left > 0.0:
		_auto_left -= delta
		if _countdown != null:
			_countdown.text = "%d 秒后返回 Returning in %ds" % [ceili(_auto_left), ceili(_auto_left)]
		if _auto_left <= 0.0:
			_auto_left = -1.0
			back_pressed.emit()


static func winner_text(res: Dictionary) -> String:
	var w := int(res.get("winner_team", -1))
	var mode := str(res.get("mode", ""))
	if mode == "raid":
		return "副本通关 Raid Cleared!" if w == 0 else "挑战失败 Raid Failed"
	if w < 0:
		return "平局 Draw"
	if mode == "duel":
		var stats: Dictionary = res.get("stats", {})
		for uid: Variant in stats:
			var s: Dictionary = stats[uid]
			if int(s.get("team", -1)) == w and str(s.get("kind", "")) in ["player", "bot"]:
				return "%s 获胜 Wins!" % str(s.get("name", ""))
	return "%s 获胜 Wins!" % (TEAM_NAMES[w] if w < TEAM_NAMES.size() else "Team %d" % w)


static func format_time(t: float) -> String:
	if t <= 0.0:
		return "--:--"
	return "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


## Clear time + local best record. MatchRaid (RAID) stores records in user://records.json under "raid_best"
## and reports best_time / new_record in the result; this screen only reads.
func raid_time_text(res: Dictionary) -> String:
	var cleared := int(res.get("winner_team", -1)) == 0
	var t := float(res.get("clear_time", 0.0))
	var raid_id := str(res.get("raid_id", _game().settings.get("raid_id", "")))
	var best := float(res.get("best_time", 0.0))
	if best <= 0.0:
		var rec := load_records()
		var rb: Variant = rec.get("raid_best", {})
		if rb is Dictionary:
			best = float((rb as Dictionary).get(raid_id, 0.0))
	var s := "用时 Clear Time: %s    最佳纪录 Record: %s" % [format_time(t) if cleared else "--:--", format_time(best)]
	if cleared and bool(res.get("new_record", false)):
		s += "    新纪录 New Record!"
	if int(res.get("wipes", 0)) > 0:
		s += "    团灭 Wipes: %d" % int(res.get("wipes", 0))
	return s


static func load_records() -> Dictionary:
	if not FileAccess.file_exists(RECORDS_PATH):
		return {}
	var f := FileAccess.open(RECORDS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _class_label(id: String) -> String:
	return _game().class_label(id)


func _stats_table(stats: Dictionary, mvp: int, raid: bool = false) -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	scroll.add_child(grid)
	for h: String in ["队伍 Team", "玩家 Player", "职业 Class", "击杀 K", "死亡 D", "伤害 Damage", "治疗 Healing"]:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		grid.add_child(l)
	var uids: Array = []
	for uid: Variant in stats:
		var k := str((stats[uid] as Dictionary).get("kind", ""))
		if k == "player" or k == "bot":
			uids.append(uid)
	uids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var sa: Dictionary = stats[a]
		var sb: Dictionary = stats[b]
		if int(sa.get("team", 0)) != int(sb.get("team", 0)):
			return int(sa.get("team", 0)) < int(sb.get("team", 0))
		return float(sa.get("damage", 0.0)) > float(sb.get("damage", 0.0)))
	for uid: Variant in uids:
		var s: Dictionary = stats[uid]
		var team := int(s.get("team", 0))
		var cells: Array[String] = [
			"队伍 Party" if raid else (TEAM_NAMES[team] if team >= 0 and team < TEAM_NAMES.size() else str(team)),
			str(s.get("name", "")) + ("  MVP" if int(uid) == mvp else ""),
			_class_label(str(s.get("class_id", ""))),
			str(int(s.get("kills", 0))),
			str(int(s.get("deaths", 0))),
			str(int(float(s.get("damage", 0.0)))),
			str(int(float(s.get("healing", 0.0)))),
		]
		for c: String in cells:
			var l := Label.new()
			l.text = c
			l.add_theme_font_size_override("font_size", 16)
			if team == 0:
				l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
			elif team == 1:
				l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.75))
			grid.add_child(l)
	return scroll


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
