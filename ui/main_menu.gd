extends Control
## Main menu (owner: NET), root of scenes/main.tscn. Shows the title menu while _game().state == MENU and the
## lobby (ui/lobby.tscn) while _game().state == LOBBY. Sub-panels: LAN host/join, Steam lobby browser,
## settings (volume, mouse sensitivity, bot difficulty, name; saved to user://settings.cfg).

const LOBBY_SCENE: String = "res://ui/lobby.tscn"
const THEME_PATH: String = "res://ui/theme.tres"

var _menu: Control
var _lobby: Control
var _panels: Dictionary = {}
var _steam_label: Label
var _msg: Label
var _lobby_list: VBoxContainer
var _addr: LineEdit
var _port: SpinBox
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if theme == null and ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_background()
	_build_menu()
	_game().state_changed.connect(func(_s: int) -> void: _sync_view())
	_game().message.connect(_show_message)
	_net().lobby_list_received.connect(_on_lobby_list)
	_net().connection_failed.connect(func(r: String) -> void: _show_message(r))
	_sync_view()
	if _game().pending_message != "":
		_show_message(_game().pending_message)
		_game().pending_message = ""


func _process(_delta: float) -> void:
	if _steam_label != null and _menu.visible:
		var t: String = _net().steam_status
		if _net().connecting:
			t += "    连接中 Connecting..."
		_steam_label.text = t


func _sync_view() -> void:
	var in_lobby: bool = _game().call("in_lobby")
	_menu.visible = not in_lobby
	if in_lobby and (_lobby == null or not is_instance_valid(_lobby)):
		var ps: PackedScene = load(LOBBY_SCENE)
		_lobby = ps.instantiate()
		add_child(_lobby)
	elif not in_lobby and _lobby != null and is_instance_valid(_lobby):
		# Detach first so a same-frame MENU -> LOBBY round trip can reuse the "Lobby" node name.
		_lobby.name = "LobbyClosing"
		_lobby.queue_free()
		_lobby = null


# ================================================================== building
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.07, 0.08, 0.14);
	vec3 bot = vec3(0.18, 0.09, 0.08);
	vec3 c = mix(top, bot, uv.y);
	float glow = smoothstep(0.6, 0.0, distance(uv, vec2(0.5, 0.32)));
	c += vec3(0.35, 0.25, 0.08) * glow * 0.35;
	COLOR = vec4(c, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	add_child(bg)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	center.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(380, 0)
	row.add_child(left)
	var title := Label.new()
	title.text = "荣耀 Glory Arena"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	var sub := Label.new()
	sub.text = "全职高手 职业竞技场 The King's Avatar Arena"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	left.add_child(sub)
	_add_btn(left, "solo", "单人练习 Solo vs Bots", func() -> void: _game().start_solo())
	_add_btn(left, "host", "创建房间 Host (Steam)", _on_host_steam)
	_add_btn(left, "browse", "浏览房间 Browse Lobbies (Steam)", func() -> void:
		_open_panel("browse")
		_refresh_lobbies())
	_add_btn(left, "lan", "局域网 LAN Host/Join", func() -> void: _open_panel("lan"))
	_add_btn(left, "settings", "设置 Settings", func() -> void: _open_panel("settings"))
	_add_btn(left, "quit", "退出 Quit", func() -> void: get_tree().quit())
	_steam_label = Label.new()
	_steam_label.add_theme_font_size_override("font_size", 14)
	_steam_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_steam_label)
	_msg = Label.new()
	_msg.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_msg)
	var right := Control.new()
	right.custom_minimum_size = Vector2(520, 460)
	row.add_child(right)
	_panels["lan"] = _build_lan_panel()
	_panels["browse"] = _build_browse_panel()
	_panels["settings"] = _build_settings_panel()
	for k: Variant in _panels:
		var p: Control = _panels[k]
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		right.add_child(p)
	_buttons["host"].disabled = not _net().steam_ok
	_buttons["browse"].disabled = not _net().steam_ok


func _add_btn(parent: Control, key: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons[key] = b
	return b


func _open_panel(key: String) -> void:
	for k: Variant in _panels:
		(_panels[k] as Control).visible = str(k) == key and not (_panels[k] as Control).visible


func _panel_box(title_text: String) -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 26)
	v.add_child(t)
	return [p, v]


func _build_lan_panel() -> Control:
	var pv := _panel_box("局域网 LAN")
	var v: VBoxContainer = pv[1]
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	var al := Label.new()
	al.text = "地址 Address"
	r1.add_child(al)
	_addr = LineEdit.new()
	_addr.text = "127.0.0.1"
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_addr)
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	var pl := Label.new()
	pl.text = "端口 Port"
	r2.add_child(pl)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = _net().ENET_PORT
	r2.add_child(_port)
	var host := Button.new()
	host.text = "创建局域网房间 Host LAN"
	host.pressed.connect(func() -> void:
		var e: int = _game().host_lan(int(_port.value))
		if e != OK:
			_show_message("无法创建 Cannot host: %s" % error_string(e as Error)))
	v.add_child(host)
	var join := Button.new()
	join.text = "加入 Join"
	join.pressed.connect(func() -> void:
		var e: int = _game().join_lan(_addr.text, int(_port.value))
		if e != OK:
			_show_message("无法连接 Cannot connect: %s" % error_string(e as Error))
		else:
			_show_message("连接中 Connecting to %s:%d ..." % [_addr.text, int(_port.value)]))
	v.add_child(join)
	var hint := Label.new()
	hint.text = "同一台电脑测试请使用 127.0.0.1。Use 127.0.0.1 to test two copies on one PC."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	v.add_child(hint)
	return pv[0]


func _build_browse_panel() -> Control:
	var pv := _panel_box("浏览房间 Browse Lobbies")
	var v: VBoxContainer = pv[1]
	var refresh := Button.new()
	refresh.text = "刷新 Refresh"
	refresh.pressed.connect(_refresh_lobbies)
	v.add_child(refresh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	v.add_child(scroll)
	_lobby_list = VBoxContainer.new()
	_lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lobby_list)
	return pv[0]


func _build_settings_panel() -> Control:
	var pv := _panel_box("设置 Settings")
	var v: VBoxContainer = pv[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	v.add_child(grid)
	var nl := Label.new()
	nl.text = "名字 Name"
	grid.add_child(nl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = _net().local_name()
	name_edit.text = str(_game().prefs.get("player_name", ""))
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(260, 0)
	grid.add_child(name_edit)
	var vl := Label.new()
	vl.text = "音量 Volume"
	grid.add_child(vl)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(_game().prefs.get("volume", 0.8))
	vol.custom_minimum_size = Vector2(260, 24)
	grid.add_child(vol)
	var sl := Label.new()
	sl.text = "鼠标灵敏度 Mouse Sensitivity"
	grid.add_child(sl)
	var sens := HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.05
	sens.value = float(_game().prefs.get("mouse_sensitivity", 1.0))
	sens.custom_minimum_size = Vector2(260, 24)
	grid.add_child(sens)
	var dl := Label.new()
	dl.text = "电脑难度 Bot Difficulty"
	grid.add_child(dl)
	var diff := OptionButton.new()
	for d: String in _game().DIFFICULTY_NAMES:
		diff.add_item(d)
	diff.select(clampi(int(_game().prefs.get("bot_difficulty", 1)), 0, 3))
	grid.add_child(diff)
	var save := Button.new()
	save.text = "保存 Save"
	save.pressed.connect(func() -> void:
		_game().prefs["player_name"] = name_edit.text.strip_edges()
		_game().prefs["volume"] = vol.value
		_game().prefs["mouse_sensitivity"] = sens.value
		_game().prefs["bot_difficulty"] = diff.selected
		_game().apply_prefs()
		var e: int = _game().save_prefs()
		_show_message("已保存 Saved" if e == OK else "保存失败 Save failed: %s" % error_string(e as Error)))
	v.add_child(save)
	return pv[0]


# ================================================================== actions
func _on_host_steam() -> void:
	if not _net().steam_ok:
		_show_message("Steam 不可用，请使用局域网 Steam unavailable, use LAN")
		return
	_show_message("正在创建 Steam 大厅 Creating Steam lobby...")
	_game().host_steam()


func _refresh_lobbies() -> void:
	if _lobby_list == null:
		return
	for c: Node in _lobby_list.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "搜索中 Searching..." if _net().steam_ok else "Steam 不可用 Steam unavailable"
	_lobby_list.add_child(l)
	_net().refresh_lobbies()


func _on_lobby_list(lobbies: Array) -> void:
	if _lobby_list == null:
		return
	for c: Node in _lobby_list.get_children():
		c.queue_free()
	if lobbies.is_empty():
		var l := Label.new()
		l.text = "没有找到房间 No lobbies found"
		_lobby_list.add_child(l)
		return
	for d: Variant in lobbies:
		if not (d is Dictionary):
			continue
		var info: Dictionary = d
		var row := HBoxContainer.new()
		var lab := Label.new()
		var mode := str(info.get("mode", ""))
		lab.text = "%s  [%s]  %d/%d" % [str(info.get("name", "?")), _game().MODE_NAMES.get(mode, mode),
			int(info.get("members", 0)), int(info.get("max", 10))]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.clip_text = true
		row.add_child(lab)
		var join := Button.new()
		join.text = "加入 Join"
		var id := int(info.get("id", 0))
		join.pressed.connect(func() -> void:
			_show_message("加入中 Joining...")
			_net().join_lobby(id))
		row.add_child(join)
		_lobby_list.add_child(row)


func _show_message(t: String) -> void:
	if _msg != null:
		_msg.text = t


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
