extends Control
## Lobby screen (owner: NET). Shows _game().settings + _game().roster (host-authoritative, synced by Game) and
## sends every change as a Game request: mode/map/raid/rounds/difficulty (host), team columns with
## human/bot slots (+ add/remove bot, bot class, swap team), the class picker, Invite (Steam overlay),
## Ready and Start.

const CLASS_CARD := preload("res://ui/class_card.gd")
const THEME_PATH: String = "res://ui/theme.tres"
const MAP_REGISTRY: String = "res://maps/map_registry.gd"
const RAID_REGISTRY: String = "res://pve/raid_registry.gd"
const TEAM_COLORS: Array[Color] = [Color(0.45, 0.65, 1.0), Color(1.0, 0.5, 0.45)]
const TEAM_TITLES: Array[String] = ["蓝队 Blue Team", "红队 Red Team"]

var _mode: OptionButton
var _map: OptionButton
var _map_label: Label
var _rounds: OptionButton
var _rounds_label: Label
var _time: SpinBox
var _diff: OptionButton
var _team_size: SpinBox
var _team_size_label: Label
var _teams_box: VBoxContainer
var _card: Control
var _ready_btn: Button
var _start_btn: Button
var _invite_btn: Button
var _status: Label
var _info: Label
var _map_ids: Array[String] = []
## Slot the class picker applies to (-1 = my own slot).
var _pick_slot: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)
	_build()
	_game().roster_changed.connect(refresh)
	_game().message.connect(func(t: String) -> void: _status.text = t)
	refresh()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# Header.
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "房间 Lobby"
	title.add_theme_font_size_override("font_size", 32)
	head.add_child(title)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_info)
	# Settings row.
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 10)
	root.add_child(srow)
	srow.add_child(_lbl("模式 Mode"))
	_mode = OptionButton.new()
	for m: String in _game().MODES:
		_mode.add_item(_game().MODE_NAMES[m])
	_mode.item_selected.connect(func(i: int) -> void: _game().set_setting("mode", _game().MODES[i]))
	srow.add_child(_mode)
	_map_label = _lbl("地图 Map")
	srow.add_child(_map_label)
	_map = OptionButton.new()
	_map.item_selected.connect(_on_map_selected)
	srow.add_child(_map)
	_rounds_label = _lbl("胜场 Rounds")
	srow.add_child(_rounds_label)
	_rounds = OptionButton.new()
	for n in [1, 2, 3]:
		_rounds.add_item("BO%d" % (n * 2 - 1))
	_rounds.item_selected.connect(func(i: int) -> void: _game().set_setting("rounds_to_win", i + 1))
	srow.add_child(_rounds)
	srow.add_child(_lbl("时限 Time(s)"))
	_time = SpinBox.new()
	_time.min_value = 30
	_time.max_value = 900
	_time.step = 30
	_time.value_changed.connect(func(v: float) -> void: _game().set_setting("round_time", int(v)))
	srow.add_child(_time)
	srow.add_child(_lbl("电脑难度 Bot Level"))
	_diff = OptionButton.new()
	for d: String in _game().DIFFICULTY_NAMES:
		_diff.add_item(d)
	_diff.item_selected.connect(func(i: int) -> void: _game().set_setting("bot_difficulty", i))
	srow.add_child(_diff)
	_team_size_label = _lbl("每队人数 Team Size")
	srow.add_child(_team_size_label)
	_team_size = SpinBox.new()
	_team_size.min_value = 1
	_team_size.max_value = 5
	_team_size.value_changed.connect(func(v: float) -> void: _game().set_setting("team_size", int(v)))
	srow.add_child(_team_size)
	# Center: teams + class card.
	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 14)
	root.add_child(center)
	var tscroll := ScrollContainer.new()
	tscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(tscroll)
	# Teams are stacked (full width each) so slot rows keep room for the player name next to the class picker.
	_teams_box = VBoxContainer.new()
	_teams_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_teams_box.add_theme_constant_override("separation", 10)
	tscroll.add_child(_teams_box)
	_card = CLASS_CARD.new()
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.class_chosen.connect(_on_class_chosen)
	center.add_child(_card)
	# Bottom bar.
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 10)
	root.add_child(bot)
	var leave := Button.new()
	leave.text = "离开 Leave"
	leave.pressed.connect(func() -> void: _game().leave_session())
	bot.add_child(leave)
	_invite_btn = Button.new()
	_invite_btn.text = "邀请好友 Invite Friends"
	_invite_btn.pressed.connect(func() -> void:
		if not _net().invite_friends():
			_status.text = "需要 Steam 大厅 Steam lobby required")
	bot.add_child(_invite_btn)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot.add_child(_status)
	_ready_btn = Button.new()
	_ready_btn.toggle_mode = true
	_ready_btn.text = "准备 Ready"
	_ready_btn.toggled.connect(func(on: bool) -> void: _game().set_ready(on))
	bot.add_child(_ready_btn)
	_start_btn = Button.new()
	_start_btn.text = "开始比赛 Start Match"
	_start_btn.add_theme_font_size_override("font_size", 22)
	_start_btn.pressed.connect(func() -> void:
		var why: String = _game().start_match()
		if why != "":
			_status.text = why)
	bot.add_child(_start_btn)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _on_map_selected(i: int) -> void:
	if i < 0 or i >= _map_ids.size():
		return
	_game().set_setting("raid_id" if not _game().is_pvp() else "map_id", _map_ids[i])


func _on_class_chosen(class_id: String) -> void:
	var me: Dictionary = _game().my_slot()
	if _pick_slot < 0 or (not me.is_empty() and _pick_slot == int(me["slot"])):
		_game().set_my_class(class_id)
	else:
		_game().set_slot_class(_pick_slot, class_id)
	_pick_slot = -1
	_update_card_target()


## Map / raid choices from the MAPS / RAID registries (guarded; either may be missing).
static func list_choices(registry_path: String, kind: String, mode: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not ResourceLoader.exists(registry_path):
		return out
	var scr: Variant = load(registry_path)
	if not (scr is Script):
		return out
	var raw: Variant = null
	for m: Dictionary in (scr as Script).get_script_method_list():
		if str(m.get("name", "")) == "list":
			raw = (scr as Script).call("list")
			break
	if raw is Dictionary:
		var arr: Array = []
		for k: Variant in raw:
			var v: Variant = raw[k]
			if v is Dictionary:
				var d: Dictionary = (v as Dictionary).duplicate()
				d["id"] = str(k)
				arr.append(d)
			else:
				arr.append(str(k))
		raw = arr
	if raw is Array:
		for v: Variant in raw:
			if v is Dictionary:
				var d: Dictionary = v
				if kind != "" and d.has("kind") and str(d["kind"]) != kind:
					continue
				if mode != "" and d.get("modes") is Array and not (d["modes"] as Array).has(mode):
					continue
				var id := str(d.get("id", ""))
				if id == "":
					continue
				var label := "%s %s" % [str(d.get("name_cn", "")), str(d.get("name_en", ""))]
				out.append({"id": id, "label": label.strip_edges() if label.strip_edges() != "" else id})
			else:
				out.append({"id": str(v), "label": str(v)})
	return out


func refresh() -> void:
	if _mode == null:
		return
	var host: bool = _game().is_host()
	var mode := str(_game().settings.get("mode", "duel"))
	var pvp: bool = _game().is_pvp()
	_info.text = "%s    %s" % [_net().transport_label(), _net().steam_status if _net().steam_ok else ""]
	_mode.set_block_signals(true)
	_mode.select(maxi(0, _game().MODES.find(mode)))
	_mode.set_block_signals(false)
	_mode.disabled = not host
	# Map / raid list.
	var choices := list_choices(MAP_REGISTRY if pvp else RAID_REGISTRY, "arena" if pvp else "", mode if pvp else "")
	_map_label.text = "地图 Map" if pvp else "副本 Raid"
	_map.set_block_signals(true)
	_map.clear()
	_map_ids.clear()
	if choices.is_empty():
		_map.add_item("默认 Default")
		_map_ids.append("")
	for c: Dictionary in choices:
		_map.add_item(str(c["label"]))
		_map_ids.append(str(c["id"]))
	var cur := str(_game().settings.get("map_id" if pvp else "raid_id", ""))
	_map.select(maxi(0, _map_ids.find(cur)))
	_map.set_block_signals(false)
	_map.disabled = not host
	if host and not choices.is_empty() and not _map_ids.has(cur):
		_game().set_setting("map_id" if pvp else "raid_id", _map_ids[0])
	_rounds.set_block_signals(true)
	_rounds.select(clampi(int(_game().settings.get("rounds_to_win", 2)) - 1, 0, 2))
	_rounds.set_block_signals(false)
	_rounds.disabled = not host
	_rounds.visible = mode == "duel" or mode == "team"
	_rounds_label.visible = _rounds.visible
	_time.set_block_signals(true)
	_time.value = float(_game().settings.get("round_time", 180))
	_time.set_block_signals(false)
	_time.editable = host
	_diff.set_block_signals(true)
	_diff.select(clampi(int(_game().settings.get("bot_difficulty", 1)), 0, 3))
	_diff.set_block_signals(false)
	_diff.disabled = not host
	_team_size.set_block_signals(true)
	_team_size.value = float(_game().settings.get("team_size", 5))
	_team_size.set_block_signals(false)
	_team_size.editable = host
	_team_size.visible = mode == "team"
	_team_size_label.visible = _team_size.visible
	_build_teams(host)
	var me: Dictionary = _game().my_slot()
	_ready_btn.visible = not host
	_ready_btn.set_pressed_no_signal(not me.is_empty() and bool(me["ready"]))
	_start_btn.visible = host
	_invite_btn.visible = _net().steam_ok and _net().lobby_id != 0
	_update_card_target()
	if host:
		var why: String = _game().can_start()
		_status.text = why if why != "" else "可以开始 Ready to start"


func _update_card_target() -> void:
	if _card == null:
		return
	var me: Dictionary = _game().my_slot()
	if _pick_slot >= 0 and (me.is_empty() or _pick_slot != int(me["slot"])):
		var s: Dictionary = _game().find_slot(_pick_slot)
		_card.call("set_target_label", "为 %s 选择职业 Pick for %s" % [s.get("name", ""), s.get("name", "")])
	else:
		_pick_slot = -1
		_card.call("set_target_label", "我的职业 My class: %s" % _game().class_label(str(me.get("class_id", ""))) if not me.is_empty() else "")
	_card.call("set_select_enabled", not me.is_empty() or _pick_slot >= 0)


func _build_teams(host: bool) -> void:
	for c: Node in _teams_box.get_children():
		c.queue_free()
	var my: int = _game().my_peer()
	for t in _game().team_count():
		var col := PanelContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_teams_box.add_child(col)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		col.add_child(v)
		var h := Label.new()
		var slots: Array = _game().team_slots(t)
		h.text = "%s  (%d/%d)" % [TEAM_TITLES[t] if _game().is_pvp() else "队伍 Party", slots.size(), _game().team_capacity(t)]
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", TEAM_COLORS[t])
		v.add_child(h)
		for s: Dictionary in slots:
			v.add_child(_slot_row(s, host, my))
		if host and slots.size() < _game().team_capacity(t):
			var add := Button.new()
			add.text = "+ 添加电脑 Add Bot"
			var team: int = t
			add.pressed.connect(func() -> void: _game().add_bot(team))
			v.add_child(add)


func _slot_row(s: Dictionary, host: bool, my: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var peer := int(s["peer"])
	var slot_id := int(s["slot"])
	var tag := Label.new()
	tag.text = "[电脑 AI]" if peer == 0 else ("[房主 Host]" if peer == 1 else "[玩家 P]")
	tag.add_theme_font_size_override("font_size", 14)
	row.add_child(tag)
	var name_l := Label.new()
	name_l.text = str(s["name"]) + ("  *" if peer == my else "")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.custom_minimum_size = Vector2(110, 0)
	name_l.clip_text = true
	if peer == my:
		name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	row.add_child(name_l)
	var cls := Button.new()
	cls.text = _game().class_label(str(s["class_id"]))
	cls.add_theme_font_size_override("font_size", 15)
	var can_pick := peer == my or (host and peer == 0)
	cls.disabled = not can_pick
	cls.pressed.connect(func() -> void:
		_pick_slot = slot_id
		_card.call("preview", str(s["class_id"]))
		_update_card_target())
	row.add_child(cls)
	var rd := Label.new()
	rd.text = "已准备 Ready" if bool(s["ready"]) else "未准备 Not ready"
	rd.add_theme_font_size_override("font_size", 14)
	rd.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if bool(s["ready"]) else Color(0.8, 0.8, 0.8))
	row.add_child(rd)
	if _game().team_count() > 1 and (peer == my or host):
		var sw := Button.new()
		sw.text = "换队 Swap"
		sw.add_theme_font_size_override("font_size", 14)
		sw.pressed.connect(func() -> void: _game().swap_team(slot_id))
		row.add_child(sw)
	if host and peer == 0:
		var rm := Button.new()
		rm.text = "移除 Remove"
		rm.add_theme_font_size_override("font_size", 14)
		rm.pressed.connect(func() -> void: _game().remove_slot(slot_id))
		row.add_child(rm)
	return row


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
