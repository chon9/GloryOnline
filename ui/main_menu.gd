extends Control
## Main menu (owner: NET, look: UI track), root of scenes/main.tscn. Shows the title menu while _game().state == MENU
## and the lobby (ui/lobby.tscn) while _game().state == LOBBY. Sub-panels: LAN host/join, Steam lobby browser,
## settings (volume, mouse sensitivity, bot difficulty, name; saved to user://settings.cfg) and credits
## (asset attributions from assets/CREDITS.md; game-icons.net CC BY requires in-game attribution).
## Look: painted navy night backdrop with drifting gold motes and a rune circle, brush-calligraphy 荣耀 title,
## navy-glass gold buttons and a turning class showcase.

const LOBBY_SCENE: String = "res://ui/lobby.tscn"
const THEME_PATH: String = "res://ui/theme.tres"
const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")
const CharPreview := preload("res://ui/char_preview.gd")
const Credits := preload("res://ui/credits.gd")
const HudAnnounce := preload("res://ui/hud_announce.gd")
const SHOWCASE: Array[String] = ["battle_mage", "launcher", "witch", "blade_master", "unspecialized"]

const BG_SHADER: String = """shader_type canvas_item;
uniform float t = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.035, 0.06, 0.13);
	vec3 mid = vec3(0.07, 0.11, 0.24);
	vec3 bot = vec3(0.16, 0.08, 0.17);
	vec3 c = mix(top, mid, smoothstep(0.0, 0.55, uv.y));
	c = mix(c, bot, smoothstep(0.55, 1.0, uv.y));
	// warm key glow behind the showcase, cool rim on the left
	c += vec3(0.42, 0.28, 0.1) * smoothstep(0.55, 0.0, distance(uv * vec2(1.78, 1.0), vec2(1.33, 0.52))) * 0.42;
	c += vec3(0.1, 0.25, 0.5) * smoothstep(0.7, 0.0, distance(uv * vec2(1.78, 1.0), vec2(0.15, 0.2))) * 0.25;
	// rune circle behind the showcase
	vec2 p = (uv - vec2(0.75, 0.56)) * vec2(1.78, 1.0);
	float r = length(p);
	float ring = smoothstep(0.004, 0.0, abs(r - 0.36)) + smoothstep(0.003, 0.0, abs(r - 0.33)) * 0.6 + smoothstep(0.003, 0.0, abs(r - 0.24)) * 0.4;
	float ang = atan(p.y, p.x) + t * 0.05;
	float ticks = step(0.92, fract(ang * 12.0)) * smoothstep(0.012, 0.0, abs(r - 0.345));
	c += vec3(1.0, 0.78, 0.36) * (ring + ticks) * 0.22;
	// drifting light motes
	for (int i = 0; i < 3; i++) {
		vec2 g = uv * vec2(32.0, 18.0) * (1.0 + float(i) * 0.6) + vec2(0.0, t * (0.25 + float(i) * 0.12));
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + float(i) * 13.0);
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(f - o * 0.6);
		float m = smoothstep(0.08, 0.0, d) * step(0.86, h) * (0.5 + 0.5 * sin(t * 2.0 + h * 30.0));
		c += vec3(1.0, 0.85, 0.5) * m * (0.55 - float(i) * 0.12);
	}
	// vignette
	vec2 v = uv - 0.5;
	c *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(c, 1.0);
}"""

var _menu: Control
var _lobby: Control
var _panels: Dictionary = {}
var _steam_label: Label
var _msg: Label
var _lobby_list: VBoxContainer
var _addr: LineEdit
var _port: SpinBox
var _buttons: Dictionary = {}
var _bg_mat: ShaderMaterial
var _showcase: Control
var _show_name: Label
var _show_en: Label
var _show_i: int = 0
var _show_t: float = 0.0
var _t: float = 0.0


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


func _process(delta: float) -> void:
	_t += delta
	if _bg_mat != null:
		_bg_mat.set_shader_parameter("t", _t)
	if _steam_label != null and _menu.visible:
		var t: String = _net().steam_status
		if _net().connecting:
			t += "    连接中 Connecting..."
		_steam_label.text = t
	if _showcase != null and _menu.visible and _showcase.visible:
		_show_t += delta
		if _show_t > 9.0:
			_show_t = 0.0
			_show_i = (_show_i + 1) % SHOWCASE.size()
			_set_showcase(SHOWCASE[_show_i])


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
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BG_SHADER
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = sh
	bg.material = _bg_mat
	add_child(bg)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "Menu"
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	# class showcase (right)
	var sc := Control.new()
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.anchor_left = 0.56
	sc.anchor_right = 0.98
	sc.anchor_top = 0.08
	sc.anchor_bottom = 0.96
	_menu.add_child(sc)
	_showcase = sc
	var pv := CharPreview.new()
	pv.name = "Showcase"
	pv.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.add_child(pv)
	var cap := VBoxContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.anchor_left = -0.08
	cap.anchor_right = 0.4
	cap.anchor_top = 0.66
	cap.anchor_bottom = 0.86
	cap.add_theme_constant_override("separation", -6)
	sc.add_child(cap)
	_show_name = HudStyle.make_label_f("", HudStyle.brush(), 64, HudStyle.UI_GOLD_HI, 8)
	_show_name.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0, 0.95))
	_show_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.add_child(_show_name)
	_show_en = HudStyle.make_label_f("", HudStyle.tech(700), 15, HudStyle.C_TEXT_DIM, 3)
	_show_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.add_child(_show_en)
	_set_showcase(SHOWCASE[0])
	# left column: title + buttons
	var left := VBoxContainer.new()
	left.name = "Left"
	left.position = Vector2(84, 70)
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 10)
	_menu.add_child(left)
	left.add_child(_build_title())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	left.add_child(gap)
	_add_btn(left, "solo", "单人练习  Solo vs Bots", func() -> void: _game().start_solo())
	_add_btn(left, "host", "创建房间  Host (Steam)", _on_host_steam)
	_add_btn(left, "browse", "浏览房间  Browse Lobbies", func() -> void:
		_open_panel("browse")
		_refresh_lobbies())
	_add_btn(left, "lan", "局域网  LAN Host / Join", func() -> void: _open_panel("lan"))
	_add_btn(left, "settings", "设置  Settings", func() -> void: _open_panel("settings"))
	_add_btn(left, "credits", "鸣谢  Credits", func() -> void: _open_panel("credits"))
	_add_btn(left, "quit", "退出  Quit", func() -> void: get_tree().quit())
	_steam_label = HudStyle.make_label("", 13, HudStyle.C_TEXT_DIM, false, 2)
	_steam_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_steam_label.custom_minimum_size = Vector2(380, 0)
	left.add_child(_steam_label)
	_msg = HudStyle.make_label("", 15, Color(1.0, 0.62, 0.5), false, 3)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(380, 0)
	left.add_child(_msg)
	# right: sub-panels (over the showcase)
	var right := Control.new()
	right.name = "Panels"
	right.position = Vector2(520, 150)
	right.custom_minimum_size = Vector2(560, 600)
	right.size = Vector2(560, 600)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(right)
	_panels["lan"] = _build_lan_panel()
	_panels["browse"] = _build_browse_panel()
	_panels["settings"] = _build_settings_panel()
	_panels["credits"] = _build_credits_panel()
	for k: Variant in _panels:
		var p: Control = _panels[k]
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		right.add_child(p)
	_buttons["host"].disabled = not _net().steam_ok
	_buttons["browse"].disabled = not _net().steam_ok
	var ver := HudStyle.make_label("Rongyao Arena  ·  荣耀竞技场", 12, Color(HudStyle.C_TEXT_DIM, 0.7), false, 2)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 20
	ver.offset_top = -30
	_menu.add_child(ver)


## 荣耀 in brush calligraphy over a gold sunburst, "GLORY ARENA" in broadcast caps, CN tagline.
func _build_title() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(380, 230)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var ci := c.get_canvas_item()
		var cen := Vector2(150, 92)
		for i in 24:
			var a := TAU * i / 24.0 + 0.13
			var l := 118.0 if i % 2 == 0 else 86.0
			GD.poly(ci, PackedVector2Array([cen + Vector2(cos(a - 0.05), sin(a - 0.05)) * 58.0, cen + Vector2(cos(a), sin(a)) * l,
				cen + Vector2(cos(a + 0.05), sin(a + 0.05)) * 58.0]), Color(GD.GOLD, 0.16 if i % 2 == 0 else 0.1))
		GD.arc(ci, cen, 62.0, 0, TAU, Color(GD.GOLD, 0.55), 1.5, 64)
		GD.arc(ci, cen, 56.0, 0, TAU, Color(GD.GOLD_SH, 0.6), 1.0, 64)
		var bf := HudStyle.brush()
		GD.text(ci, bf, Vector2(8, 150), "荣耀", 150, GD.GOLD_HI, 12, Color(0.16, 0.07, 0.0, 0.95))
		var tf := HudStyle.tech(900)
		GD.text(ci, tf, Vector2(12, 192), "GLORY  ARENA", 30, GD.TEXT, 5)
		GD.line(ci, Vector2(12, 204), Vector2(360, 204), Color(GD.GOLD, 0.8), 1.5)
		GD.diamond(ci, Vector2(186, 204), 5, 7)
		GD.text(ci, HudStyle.sans(600), Vector2(12, 228), "全职高手 · 职业竞技场   The King's Avatar Arena", 15, HudStyle.C_TEXT_DIM, 3))
	return c


func _set_showcase(id: String) -> void:
	var pv := _showcase.get_node_or_null("Showcase") if _showcase != null else null
	if pv != null:
		pv.call("set_class", id)
	var k := CoreUtil.get_kit(id)
	if _show_name != null:
		_show_name.text = k.name_cn if k != null else ""
		_show_en.text = k.name_en.to_upper() if k != null else ""


func _add_btn(parent: Control, key: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons[key] = b
	return b


func _open_panel(key: String) -> void:
	for k: Variant in _panels:
		(_panels[k] as Control).visible = str(k) == key and not (_panels[k] as Control).visible
	var any := false
	for k: Variant in _panels:
		any = any or (_panels[k] as Control).visible
	if _showcase != null:
		_showcase.modulate.a = 0.25 if any else 1.0


func _panel_box(title_text: String) -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var parts := HudAnnounce.split_bilingual(title_text)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var t := HudStyle.make_label_f(parts[0], HudStyle.brush(), 40, HudStyle.UI_GOLD_HI, 5)
	t.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0, 0.95))
	hb.add_child(t)
	if parts[1] != "":
		var e := HudStyle.make_label_f(parts[1].to_upper(), HudStyle.tech(700), 15, HudStyle.C_TEXT_DIM, 2)
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(e)
	var sep := HSeparator.new()
	v.add_child(sep)
	return [p, v]


func _field_label(t: String) -> Label:
	var l := HudStyle.make_label(t, 16, HudStyle.C_TEXT, false, 2)
	l.custom_minimum_size = Vector2(150, 0)
	return l


func _build_lan_panel() -> Control:
	var pv := _panel_box("局域网 LAN")
	var v: VBoxContainer = pv[1]
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(_field_label("地址 Address"))
	_addr = LineEdit.new()
	_addr.text = "127.0.0.1"
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(_addr)
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	r2.add_child(_field_label("端口 Port"))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = _net().ENET_PORT
	r2.add_child(_port)
	var host := Button.new()
	host.text = "创建局域网房间  Host LAN"
	host.pressed.connect(func() -> void:
		var e: int = _game().host_lan(int(_port.value))
		if e != OK:
			_show_message("无法创建 Cannot host: %s" % error_string(e as Error)))
	v.add_child(host)
	var join := Button.new()
	join.text = "加入  Join"
	join.pressed.connect(func() -> void:
		var e: int = _game().join_lan(_addr.text, int(_port.value))
		if e != OK:
			_show_message("无法连接 Cannot connect: %s" % error_string(e as Error))
		else:
			_show_message("连接中 Connecting to %s:%d ..." % [_addr.text, int(_port.value)]))
	v.add_child(join)
	var hint := HudStyle.make_label("同一台电脑测试请使用 127.0.0.1。\nUse 127.0.0.1 to test two copies on one PC.", 14, HudStyle.C_TEXT_DIM, false, 2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return pv[0]


func _build_browse_panel() -> Control:
	var pv := _panel_box("浏览房间 Browse Lobbies")
	var v: VBoxContainer = pv[1]
	var refresh := Button.new()
	refresh.text = "刷新  Refresh"
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
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	grid.add_child(_field_label("名字 Name"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = _net().local_name()
	name_edit.text = str(_game().prefs.get("player_name", ""))
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(280, 0)
	grid.add_child(name_edit)
	grid.add_child(_field_label("音量 Volume"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(_game().prefs.get("volume", 0.8))
	vol.custom_minimum_size = Vector2(280, 24)
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(vol)
	grid.add_child(_field_label("鼠标灵敏度 Mouse"))
	var sens := HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.05
	sens.value = float(_game().prefs.get("mouse_sensitivity", 1.0))
	sens.custom_minimum_size = Vector2(280, 24)
	sens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(sens)
	grid.add_child(_field_label("电脑难度 Bot Level"))
	var diff := OptionButton.new()
	for d: String in _game().DIFFICULTY_NAMES:
		diff.add_item(d)
	diff.select(clampi(int(_game().prefs.get("bot_difficulty", 1)), 0, 3))
	grid.add_child(diff)
	var fx_sliders: Dictionary = {}
	for row: Array in [["fx_own", "自身特效 Own FX"], ["fx_ally", "友方特效 Ally FX"], ["fx_enemy", "敌方特效 Enemy FX"]]:
		grid.add_child(_field_label(str(row[1])))
		var fs := HSlider.new()
		fs.min_value = 0.1
		fs.max_value = 1.0
		fs.step = 0.05
		fs.value = float(_game().prefs.get(str(row[0]), 1.0))
		fs.custom_minimum_size = Vector2(280, 24)
		fs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fs.tooltip_text = "其他玩家技能特效强度（敌方预警始终全亮） Strength of other players' skill effects (enemy telegraphs always full)"
		grid.add_child(fs)
		fx_sliders[row[0]] = fs
	grid.add_child(_field_label("镜头震动 Camera Shake"))
	var shake := CheckBox.new()
	shake.button_pressed = bool(_game().prefs.get("camera_shake", true))
	grid.add_child(shake)
	var save := Button.new()
	save.text = "保存  Save"
	save.pressed.connect(func() -> void:
		_game().prefs["player_name"] = name_edit.text.strip_edges()
		_game().prefs["volume"] = vol.value
		_game().prefs["mouse_sensitivity"] = sens.value
		_game().prefs["bot_difficulty"] = diff.selected
		for k: Variant in fx_sliders:
			_game().prefs[k] = (fx_sliders[k] as HSlider).value
		_game().prefs["camera_shake"] = shake.button_pressed
		_game().apply_prefs()
		var e: int = _game().save_prefs()
		_show_message("已保存 Saved" if e == OK else "保存失败 Save failed: %s" % error_string(e as Error)))
	v.add_child(save)
	return pv[0]


func _build_credits_panel() -> Control:
	var pv := _panel_box("鸣谢 Credits")
	var v: VBoxContainer = pv[1]
	var rt := Credits.make_view()
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rt)
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
	var l := HudStyle.make_label("搜索中 Searching..." if _net().steam_ok else "Steam 不可用 Steam unavailable", 16, HudStyle.C_TEXT_DIM, false, 2)
	_lobby_list.add_child(l)
	_net().refresh_lobbies()


func _on_lobby_list(lobbies: Array) -> void:
	if _lobby_list == null:
		return
	for c: Node in _lobby_list.get_children():
		c.queue_free()
	if lobbies.is_empty():
		_lobby_list.add_child(HudStyle.make_label("没有找到房间 No lobbies found", 16, HudStyle.C_TEXT_DIM, false, 2))
		return
	for d: Variant in lobbies:
		if not (d is Dictionary):
			continue
		var info: Dictionary = d
		var row := HBoxContainer.new()
		var mode := str(info.get("mode", ""))
		var lab := HudStyle.make_label("%s  [%s]  %d/%d" % [str(info.get("name", "?")), _game().MODE_NAMES.get(mode, mode),
			int(info.get("members", 0)), int(info.get("max", 10))], 16, HudStyle.C_TEXT, false, 2)
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
