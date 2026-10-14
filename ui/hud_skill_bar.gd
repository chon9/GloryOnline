extends VBoxContainer
## Skill bar (look-dev layout): 8 slots (LMB RMB | Q E R F 1 | ultimate 2) in a navy-glass gold panel, an MP strip and the
## 觉醒 ribbon above it, and a cast bar for long casts (>= 0.6 s).
## refresh(f) is called by the Hud at ~25 Hz; the slots interpolate their sweeps per frame.

const HudStyle := preload("res://ui/hud_style.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudSkillSlot := preload("res://ui/hud_skill_slot.gd")
const GD := preload("res://ui/glory_draw.gd")

const LONG_CAST: float = 0.6

var slots: Array = []           # Array[HudSkillSlot]
var cast_panel: PanelContainer
var cast_bar: HudBar
var cast_label: Label
var mp_hint: Label

var _bound_uid: int = -1
var _kit_key: String = ""
var _cast_slot: int = -1
var _cast_skill: SkillDef = null
var _cast_t: float = 0.0
var _cast_total: float = 0.0
var _fighter: Fighter = null


class Strip extends Control:
	## MP bar along the slots + the gold 觉醒 ribbon over the ultimate (look-dev layout).
	var bar_owner: Node = null
	var mp: float = 0.0
	var mp_max: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 24)

	func _draw() -> void:
		if bar_owner == null:
			return
		var slots_a: Array = bar_owner.get("slots")
		if slots_a.size() < 8:
			return
		var ci := get_canvas_item()
		var gx := get_global_rect().position
		var s0: Rect2 = (slots_a[0] as Control).get_global_rect()
		var s6: Rect2 = (slots_a[6] as Control).get_global_rect()
		var s7: Rect2 = (slots_a[7] as Control).get_global_rect()
		var x0 := s0.position.x - gx.x + 6.0
		var x1 := s6.end.x - gx.x - 2.0
		if mp_max > 0.0:
			var br := Rect2(Vector2(x0, size.y - 13.0), Vector2(x1 - x0, 10.0))
			GD.bar(ci, br, mp / maxf(mp_max, 0.001), mp / maxf(mp_max, 0.001), HudStyle.C_MP, HudStyle.C_MP, Color(HudStyle.UI_GOLD, 0.8), 10)
			var f := HudStyle.num(600)
			var t := "%d / %d" % [int(ceil(mp)), int(mp_max)]
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			GD.text(ci, f, Vector2(x1 - w - 10.0, size.y - 10.0), t, 17, Color("#CFE2FF"), 4)
		var ux := s7.get_center().x - gx.x
		var rr := Rect2(Vector2(ux - 34.0, size.y - 22.0), Vector2(68.0, 20.0))
		GD.ribbon(ci, rr)
		var bf := HudStyle.sans(800)
		GD.text_c(ci, bf, rr.get_center() + Vector2(0, -1), "觉醒", 13, Color("#2A1606"))


var strip: Strip


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	# cast bar
	var cast_center := CenterContainer.new()
	cast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cast_center)
	cast_panel = PanelContainer.new()
	cast_panel.add_theme_stylebox_override("panel", HudStyle.glory("plain", 7.0))
	cast_panel.custom_minimum_size = Vector2(380, 0)
	cast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_center.add_child(cast_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_panel.add_child(cv)
	cast_label = HudStyle.make_label("", 15, HudStyle.UI_GOLD_HI, true)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cast_label)
	cast_bar = HudBar.new()
	cast_bar.custom_minimum_size = Vector2(0, 12)
	cast_bar.fill_color = Color(1.0, 0.78, 0.3)
	cast_bar.trail_color = Color(1.0, 0.78, 0.3)
	cast_bar.ticks = 0
	cast_bar.show_text = false
	cv.add_child(cast_bar)
	cast_panel.visible = false
	# slots in a navy-glass gold panel; MP strip + 觉醒 ribbon above
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(col)
	strip = Strip.new()
	strip.bar_owner = self
	col.add_child(strip)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", HudStyle.glory("panel", 0.0))
	(bg.get_theme_stylebox("panel") as StyleBox).content_margin_left = 20.0
	(bg.get_theme_stylebox("panel") as StyleBox).content_margin_right = 20.0
	(bg.get_theme_stylebox("panel") as StyleBox).content_margin_top = 10.0
	(bg.get_theme_stylebox("panel") as StyleBox).content_margin_bottom = 10.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(row)
	for i in 8:
		if i == 2 or i == 7:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(8 if i == 2 else 12, 0)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sep)
		var s := HudSkillSlot.new()
		s.slot = i
		if i == 7:
			s.custom_minimum_size = Vector2(82, 82)
		elif i <= 1:
			s.custom_minimum_size = Vector2(62, 62)
		else:
			s.custom_minimum_size = Vector2(66, 66)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(s)
		slots.append(s)


func refresh(f: Fighter) -> void:
	_fighter = f
	if f == null or not is_instance_valid(f):
		visible = false
		_bound_uid = -1
		return
	visible = true
	var tint := f.kit.tint if f.kit != null else HudStyle.class_color(f)
	var key := "%d:%s" % [f.uid, f.kit.id if f.kit != null else f.mob_id]
	if key != _kit_key:
		_kit_key = key
		for i in 8:
			(slots[i] as HudSkillSlot).set_skill(f.get_skill(i), tint, HudStyle.KEY_LABELS[i])
	var silenced := f.has_status(&"silence") or (f.status_mask >> 3) & 1 == 1
	var disabled := not f.is_alive() or (f.status_mask & 0b10011) != 0   # stun / freeze / sleep
	for i in 8:
		var s: HudSkillSlot = slots[i]
		var sk := s.skill
		var cd := f.cooldowns_packed[i] if i < f.cooldowns_packed.size() else 0.0
		var ch := f.charges_packed[i] if i < f.charges_packed.size() else 1
		var no_mp := sk != null and sk.mp_cost > f.mp + 0.01
		s.update_state(cd, ch, no_mp, silenced or disabled, f.cast_slot == i)
	strip.mp = f.mp
	strip.mp_max = f.max_mp
	strip.queue_redraw()
	_update_cast(f)


func _update_cast(f: Fighter) -> void:
	var cs := f.cast_slot
	if cs != _cast_slot:
		_cast_slot = cs
		_cast_skill = null
		_cast_t = 0.0
		_cast_total = 0.0
		if cs >= 0:
			var sk: SkillDef = null
			if f.runner != null:
				sk = f.runner.skill
			if sk == null:
				sk = f.get_skill(cs)
			if sk != null:
				var rate := clampf(f.get_stat("cast_speed") if cs != 0 else f.get_stat("atk_speed"), 0.25, 4.0)
				_cast_skill = sk
				_cast_total = sk.total_time() / rate
	var show := _cast_skill != null and _cast_total >= LONG_CAST and f.is_alive()
	cast_panel.visible = show
	set_process(show)
	if show:
		cast_label.text = "%s %s" % [_cast_skill.name_cn, _cast_skill.name_en]
		_apply_cast_progress()


func _process(delta: float) -> void:
	_cast_t += delta
	_apply_cast_progress()


func _apply_cast_progress() -> void:
	var p := _cast_t
	if _fighter != null and is_instance_valid(_fighter) and _fighter.runner != null and _fighter.runner.duration > 0.0:
		p = _fighter.runner.real_elapsed   # host: exact
	cast_bar.set_values(clampf(p, 0.0, _cast_total), maxf(_cast_total, 0.01))
	cast_bar.snap()
