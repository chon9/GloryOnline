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
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "菜单 Menu"
	t.add_theme_font_size_override("font_size", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := Button.new()
	resume.text = "继续 Resume"
	resume.pressed.connect(close)
	v.add_child(resume)
	var sl := Label.new()
	sl.text = "鼠标灵敏度 Mouse Sensitivity"
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
	if _game().is_host():
		var lobby := Button.new()
		lobby.text = "结束比赛并返回房间 End Match (Back to Lobby)"
		lobby.pressed.connect(func() -> void: back_to_lobby.emit())
		v.add_child(lobby)
	var leave := Button.new()
	leave.text = "离开比赛 Leave Match"
	leave.pressed.connect(func() -> void: leave_match.emit())
	v.add_child(leave)
	var keys := Label.new()
	keys.text = "WASD 移动 Move  空格 Jump  左/右键 LMB/RMB  Q E R F 1 2 技能 Skills\nTab 锁定 Lock-on  中键 Toggle lock  ` 计分板 Scoreboard"
	keys.add_theme_font_size_override("font_size", 13)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)


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
