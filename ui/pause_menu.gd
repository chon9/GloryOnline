extends CanvasLayer
## In-match pause menu (owner: NET). Esc toggles it. The simulation keeps running (multiplayer); while open the
## local PlayerController is disabled and the mouse is released.
## Host: back to lobby for everyone (ends the match) or leave to the main menu (closes the session).
## Client: leave to the main menu (the host turns our fighter into a bot).

signal resumed
signal back_to_lobby
signal leave_match
signal sensitivity_changed(mult: float)

const THEME_PATH: String = "res://ui/theme.tres"
const HudStyle := preload("res://ui/hud_style.gd")

var is_open: bool = false
var _root: Control


func _init() -> void:
	layer = 25
	name = "PauseMenu"


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		_root.theme = load(THEME_PATH)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var psb := HudStyle.glory("panel", 0.0)
	psb.content_margin_left = 34.0
	psb.content_margin_right = 34.0
	psb.content_margin_top = 14.0
	psb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := HudStyle.make_label_f("暂停", HudStyle.brush(), 56, HudStyle.UI_GOLD_HI, 8)
	t.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0, 0.95))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var te := HudStyle.make_label_f("MENU", HudStyle.tech(800), 15, HudStyle.C_TEXT_DIM, 2)
	te.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(te)
	v.add_child(HSeparator.new())
	var resume := Button.new()
	resume.text = "继续  Resume"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.pressed.connect(close)
	v.add_child(resume)
	var sl := HudStyle.make_label("鼠标灵敏度 Mouse Sensitivity", 15, HudStyle.C_TEXT_DIM, false, 2)
	v.add_child(sl)
	var sens := HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.05
	sens.value = float(_game().prefs.get("mouse_sensitivity", 1.0))
	sens.value_changed.connect(func(x: float) -> void:
		_game().prefs["mouse_sensitivity"] = x
		_game().save_prefs()
		sensitivity_changed.emit(x))
	v.add_child(sens)
	_add_audio_options(v)
	_add_fx_options(v)
	if _game().is_host():
		var lobby := Button.new()
		lobby.text = "结束比赛并返回房间  End Match"
		lobby.custom_minimum_size = Vector2(0, 48)
		lobby.pressed.connect(func() -> void: back_to_lobby.emit())
		v.add_child(lobby)
	var leave := Button.new()
	leave.text = "离开比赛  Leave Match"
	leave.custom_minimum_size = Vector2(0, 48)
	leave.pressed.connect(func() -> void: leave_match.emit())
	v.add_child(leave)
	var keys := HudStyle.make_label("WASD 移动 Move   空格 跳跃 Jump   左/右键 LMB/RMB   Q E R F 1 2 技能 Skills
Tab 锁定 Lock-on   中键 切换锁定 Toggle lock   ` 战绩 Scoreboard   F1 帮助 Help", 13, HudStyle.C_TEXT_DIM, false, 2)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)


## One volume slider per audio bus (Game.VOLUME_ROWS); applied live and saved to user://settings.cfg.
func _add_audio_options(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.name = "AudioOptions"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	for row: Array in _game().VOLUME_ROWS:
		var key: String = row[0]
		g.add_child(HudStyle.make_label(str(row[1]), 14, HudStyle.C_TEXT_DIM, false, 2))
		var sl := HSlider.new()
		sl.name = "Volume_" + key
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(190, 22)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value = float(_game().prefs.get(key, 0.8))
		sl.value_changed.connect(func(x: float) -> void:
			_game().prefs[key] = x
			_game().apply_bus_volumes()
			_game().save_prefs())
		g.add_child(sl)


## Effect intensity by caster (own / allies / enemies; enemy telegraphs always full) + camera shake toggle.
## Applied live (Game.apply_prefs -> Fx) and saved to user://settings.cfg.
func _add_fx_options(v: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	for row: Array in [["fx_own", "自身特效 Own Effects"], ["fx_ally", "友方特效 Ally Effects"], ["fx_enemy", "敌方特效 Enemy Effects"]]:
		var key: String = row[0]
		g.add_child(HudStyle.make_label(str(row[1]), 14, HudStyle.C_TEXT_DIM, false, 2))
		var sl := HSlider.new()
		sl.name = "Slider_" + key
		sl.min_value = 0.1
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(190, 22)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value = float(_game().prefs.get(key, 1.0))
		sl.value_changed.connect(func(x: float) -> void:
			_game().prefs[key] = x
			_game().apply_prefs()
			_game().save_prefs())
		g.add_child(sl)
	var shake := CheckBox.new()
	shake.name = "CameraShake"
	shake.text = "镜头震动 Camera Shake"
	shake.button_pressed = bool(_game().prefs.get("camera_shake", true))
	shake.toggled.connect(func(on: bool) -> void:
		_game().prefs["camera_shake"] = on
		_game().apply_prefs()
		_game().save_prefs())
	v.add_child(shake)


func _unhandled_input(e: InputEvent) -> void:
	if InputMap.has_action("menu") and e.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	if _root != null:
		_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	is_open = false
	if _root != null:
		_root.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
