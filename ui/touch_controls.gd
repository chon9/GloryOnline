extends Control
## Local multi-touch intent; uses the same FighterInput/RPC path as keyboard input.
## Each finger owns its original control until release, including outside its bounds.
const Style := preload("res://ui/hud_style.gd")
const Icons := preload("res://ui/hud_icons.gd")
var controller: PlayerController
var fingers: Dictionary = {}
var stick := Vector2.ZERO
var _repeat := 0.0
var _plate := Style.panel(Style.UI_PANEL, Style.UI_GOLD, 3)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func unit() -> float:
	return minf(size.x / 1280.0, size.y / 720.0)

func stick_center() -> Vector2:
	return Vector2(112, size.y / unit() - 130) * unit()

func button_rect(slot: int) -> Rect2:
	var u := unit()
	var p := Vector2(size.x - 324 * u, size.y - 194 * u)
	# Two rows, basic attack on the lower-right for the thumb.
	var cell := 7 if slot == 0 else slot - 1
	return Rect2(p + Vector2(cell % 4, cell / 4) * 76.0 * u, Vector2.ONE * 66.0 * u)

func utility_rect(index: int) -> Rect2:
	var u := unit()
	return Rect2(Vector2(size.x - (324 + 78 * (index + 1)) * u, size.y - 112 * u), Vector2(68, 58) * u)

func menu_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 34 * unit(), size.y - 60 * unit()), Vector2(68, 42) * unit())

func _input(e: InputEvent) -> void:
	if not is_instance_valid(controller) or not controller.enabled or not controller._focused:
		return
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	var index: int = e.index
	var p: Vector2 = e.position
	if e is InputEventScreenTouch and e.pressed:
		if p.distance_to(stick_center()) < 86.0 * unit() and not fingers.values().has(-1):
			fingers[index] = -1
			_update_stick(p)
		else:
			for slot in 8:
				if button_rect(slot).has_point(p) and not fingers.values().has(slot):
					fingers[index] = slot
					controller.touch_held |= 1 << slot
					if slot == 0:
						controller.touch_pressed |= 1
						_repeat = 0.0
					break
			for i in 2:
				if utility_rect(i).has_point(p):
					fingers[index] = -2 - i
					if i == 0:
						controller.touch_dodge = true
					else:
						controller.touch_jump = true
			if menu_rect().has_point(p):
				for n: Node in controller.get_parent().get_children():
					if n.has_method("open") and n.has_signal("resumed"):
						n.call("open")
						controller.clear_pending_input()
				get_viewport().set_input_as_handled()
				return
	if not fingers.has(index):
		return
	var action: int = fingers[index]
	if e is InputEventScreenDrag:
		if action == -1:
			_update_stick(p)
		elif action >= 0:
			var d := p - button_rect(action).get_center()
			if d.length() > 16 * unit():
				controller.touch_aim = d.normalized()
	elif e is InputEventScreenTouch and not e.pressed:
		if action == -1:
			stick = Vector2.ZERO
			controller.touch_move = Vector2.ZERO
		elif action >= 0:
			controller.touch_held &= ~(1 << action)
			if action > 0 and not e.canceled:
				controller.touch_pressed |= 1 << action
		fingers.erase(index)
	get_viewport().set_input_as_handled()

func _update_stick(p: Vector2) -> void:
	stick = ((p - stick_center()) / (62.0 * unit())).limit_length()
	controller.touch_move = stick if stick.length() > 0.14 else Vector2.ZERO
	# Move direction becomes the next default aim once no skill finger is aiming.
	if fingers.size() == 1 and controller.touch_move.length() > 0.14:
		controller.touch_aim = controller.touch_move.normalized()

func release_all() -> void:
	fingers.clear()
	stick = Vector2.ZERO
	_repeat = 0.0

func _process(delta: float) -> void:
	visible = is_instance_valid(controller) and controller.enabled
	if visible and (controller.touch_held & 1) != 0:
		_repeat += delta
		if _repeat >= 0.24:
			_repeat = 0.0
			controller.touch_pressed |= 1
	queue_redraw()

func _draw() -> void:
	var u := unit()
	var c := stick_center()
	draw_circle(c, 70 * u, Color(0.03, 0.025, 0.02, 0.7))
	draw_arc(c, 70 * u, 0, TAU, 48, Color(0.65, 0.58, 0.43, 0.55), 2 * u, true)
	draw_circle(c + stick * 45 * u, 27 * u, Color(0.5, 0.46, 0.38, 0.65))
	var f := controller.fighter if is_instance_valid(controller) else null
	for i in 8:
		var r := button_rect(i)
		draw_style_box(_plate, r)
		var skill := f.get_skill(i) if is_instance_valid(f) else null
		var texture := Style.skill_icon(skill)
		if texture != null:
			draw_texture_rect(texture, r.grow(-3 * u), false)
		else:
			Icons.draw_skill_icon(self, r.grow(-3 * u), skill, Style.UI_GOLD)
		if is_instance_valid(f) and i < f.cooldowns_packed.size() and f.cooldowns_packed[i] > 0:
			draw_rect(r, Color(0, 0, 0, 0.65))
			_label(r, str(ceili(f.cooldowns_packed[i])), 24 * u)
		elif skill != null:
			_label(Rect2(r.position + Vector2(0, r.size.y - 20 * u), Vector2(r.size.x, 20 * u)), skill.name_cn, 12 * u)
		if fingers.values().has(i):
			draw_rect(r, Style.UI_GOLD_HI, false, 2 * u)
	for i in 2:
		var r := utility_rect(i)
		draw_style_box(_plate, r)
		_label(r, "闪避" if i == 0 else "跳跃", 16 * u)
	draw_style_box(_plate, menu_rect())
	_label(menu_rect(), "菜单", 16 * u)

func _label(r: Rect2, text: String, px: float) -> void:
	var font := Style.font()
	var fs := maxi(10, int(px))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, r.get_center() + Vector2(-w * 0.5, fs * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	draw_string(font, r.get_center() + Vector2(-w * 0.5, fs * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.C_TEXT)
