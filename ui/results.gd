extends CanvasLayer
## Results screen (owner: NET), shown by modes/match_scene.gd when the Match emits match_ended.
## Winner, MVP, per-player stats table; raid: clear time + local best record (user://records.json).
## Host: "返回房间 Back to Lobby" (also automatic after _game().results_auto_return seconds).

signal back_pressed
signal leave_pressed

const THEME_PATH: String = "res://ui/theme.tres"
const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
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
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { vec2 d = UV - vec2(0.5, 0.35); float g = smoothstep(0.7, 0.0, length(d * vec2(1.6, 1.0))); COLOR = vec4(mix(vec3(0.015, 0.025, 0.06), vec3(0.12, 0.1, 0.06), g * 0.6), 0.82); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	dim.material = mat
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	var psb := HudStyle.glory("panel", 0.0)
	psb.content_margin_left = 40.0
	psb.content_margin_right = 40.0
	psb.content_margin_top = 10.0
	psb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var mode := str(res.get("mode", ""))
	var wt := winner_text(res)
	var parts := _split(wt)
	var title := HudStyle.make_label_f(parts[0], HudStyle.brush(), 76, HudStyle.UI_GOLD_HI, 10)
	title.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mode == "raid" and int(res.get("winner_team", -1)) != 0:
		title.add_theme_color_override("font_color", Color("#FF7A6A"))
	v.add_child(title)
	if parts[1] != "":
		var en := HudStyle.make_label_f(parts[1].to_upper(), HudStyle.crit(), 24, HudStyle.UI_GOLD, 5)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(en)
	var stats: Dictionary = res.get("stats", {})
	var mvp := int(res.get("mvp_uid", -1))
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 30)
	v.add_child(info)
	if stats.has(mvp):
		info.add_child(_mvp_card(stats[mvp]))
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 2)
	info.add_child(lines)
	if mode == "raid":
		var rl := HudStyle.make_label(raid_time_text(res), 17, HudStyle.C_TEXT, false, 3)
		lines.add_child(rl)
	var sc: Dictionary = res.get("score", {})
	if sc.get("wins") is Array and mode != "raid":
		var w: Array = sc["wins"]
		if w.size() >= 2:
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 14)
			var cap := HudStyle.make_label("比分 Score", 15, HudStyle.C_TEXT_DIM, false, 2)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			srow.add_child(cap)
			srow.add_child(HudStyle.make_label_f(str(int(w[0])), HudStyle.crit(), 40, HudStyle.team_color(0).lightened(0.25), 6))
			srow.add_child(HudStyle.make_label_f(":", HudStyle.crit(), 34, HudStyle.C_TEXT_DIM, 4))
			srow.add_child(HudStyle.make_label_f(str(int(w[1])), HudStyle.crit(), 40, HudStyle.team_color(1).lightened(0.2), 6))
			lines.add_child(srow)
	var sep := HSeparator.new()
	v.add_child(sep)
	v.add_child(_stats_table(stats, mvp, mode == "raid"))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	v.add_child(bar)
	_countdown = HudStyle.make_label("", 15, HudStyle.C_TEXT_DIM, false, 2)
	_countdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_countdown)
	if is_host:
		var back := Button.new()
		back.text = "返回房间  Back to Lobby"
		back.custom_minimum_size = Vector2(240, 48)
		back.pressed.connect(func() -> void: back_pressed.emit())
		bar.add_child(back)
		_auto_left = auto_return if auto_return > 0.0 else -1.0
	else:
		_countdown.text = "等待房主 Waiting for host..."
	var leave := Button.new()
	leave.text = "离开  Leave to Menu"
	leave.custom_minimum_size = Vector2(220, 48)
	leave.pressed.connect(func() -> void: leave_pressed.emit())
	bar.add_child(leave)


## "蓝队 Blue Team 获胜 Wins!" -> [CN words, EN words].
static func _split(t: String) -> PackedStringArray:
	var cn := PackedStringArray()
	var en := PackedStringArray()
	for w: String in t.split(" ", false):
		var has := false
		for k in w.length():
			if w.unicode_at(k) >= 0x2E80:
				has = true
		if has:
			cn.append(w)
		else:
			en.append(w)
	if cn.is_empty():
		return PackedStringArray([t, ""])
	return PackedStringArray([" ".join(cn), " ".join(en)])


func _mvp_card(ms: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := HudStyle.glory("holo", 0.0, HudStyle.UI_GOLD)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var cid := str(ms.get("class_id", ""))
	var em := Control.new()
	em.custom_minimum_size = Vector2(64, 64)
	em.draw.connect(func() -> void:
		var k := CoreUtil.get_kit(cid)
		HudIcons.draw_class_emblem(em, Rect2(Vector2.ZERO, em.size), cid, k.name_cn.substr(0, 1) if k != null else "?",
			k.tint if k != null else Color.WHITE))
	hb.add_child(em)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	hb.add_child(vb)
	var tag := HudStyle.make_label_f("MVP  全场最佳", HudStyle.crit(), 16, HudStyle.C_CRIT, 4)
	vb.add_child(tag)
	vb.add_child(HudStyle.make_label(str(ms.get("name", "")), 24, HudStyle.C_TEXT, true, 4))
	vb.add_child(HudStyle.make_label(_class_label(cid), 14, HudStyle.C_TEXT_DIM, false, 2))
	return card


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
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 8
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	grid.add_child(Control.new())
	var widths: Array[float] = [110.0, 200.0, 170.0, 56.0, 56.0, 110.0, 110.0]
	var heads: Array[String] = ["队伍 Team", "玩家 Player", "职业 Class", "击杀 K", "死亡 D", "伤害 Damage", "治疗 Healing"]
	for hi in heads.size():
		var l := HudStyle.make_label(heads[hi], 13, Color(HudStyle.UI_CYAN, 0.9), true, 2)
		l.custom_minimum_size = Vector2(widths[hi], 0)
		if hi >= 3:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
		var cid := str(s.get("class_id", ""))
		var em := Control.new()
		em.custom_minimum_size = Vector2(30, 30)
		em.draw.connect(func() -> void:
			var k := CoreUtil.get_kit(cid)
			HudIcons.draw_class_emblem(em, Rect2(Vector2.ZERO, em.size), cid, k.name_cn.substr(0, 1) if k != null else "?",
				k.tint if k != null else Color.WHITE))
		grid.add_child(em)
		var tcol := HudStyle.UI_GOLD_HI if raid else HudStyle.team_color(team).lerp(Color.WHITE, 0.35)
		var cells: Array[String] = [
			"队伍 Party" if raid else (TEAM_NAMES[team] if team >= 0 and team < TEAM_NAMES.size() else str(team)),
			str(s.get("name", "")) + ("  MVP" if int(uid) == mvp else ""),
			_class_label(cid),
			str(int(s.get("kills", 0))),
			str(int(s.get("deaths", 0))),
			HudStyle.fmt_num(float(s.get("damage", 0.0))),
			HudStyle.fmt_num(float(s.get("healing", 0.0))),
		]
		for ci in cells.size():
			var l: Label
			if ci >= 3:
				l = HudStyle.make_label_f(cells[ci], HudStyle.num(600), 22, HudStyle.C_TEXT, 3)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				l = HudStyle.make_label(cells[ci], 15, HudStyle.C_TEXT if ci != 0 else tcol, ci == 1, 2)
				l.clip_text = true
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size = Vector2(widths[ci], 0)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if ci == 1 and int(uid) == mvp:
				l.add_theme_color_override("font_color", HudStyle.C_CRIT)
			grid.add_child(l)
	return scroll


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
