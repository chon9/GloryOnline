extends VBoxContainer
## Skill bar: 8 slots (LMB RMB | Q E R F | 1 2) + a cast bar for long casts (>= 0.6 s).
## refresh(f) is called by the Hud at ~25 Hz; the slots interpolate their sweeps per frame.

const HudStyle := preload("res://ui/hud_style.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudSkillSlot := preload("res://ui/hud_skill_slot.gd")

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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)
	# cast bar
	var cast_center := CenterContainer.new()
	cast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cast_center)
	cast_panel = PanelContainer.new()
	cast_panel.add_theme_stylebox_override("panel", HudStyle.panel(Color(0.04, 0.05, 0.08, 0.78), HudStyle.C_BORDER, 6, 1, 4.0))
	cast_panel.custom_minimum_size = Vector2(380, 0)
	cast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_center.add_child(cast_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_panel.add_child(cv)
	cast_label = HudStyle.make_label("", 15, HudStyle.C_GOLD, true)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cast_label)
	cast_bar = HudBar.new()
	cast_bar.custom_minimum_size = Vector2(0, 12)
	cast_bar.fill_color = Color(1.0, 0.78, 0.3)
	cast_bar.show_text = false
	cv.add_child(cast_bar)
	cast_panel.visible = false
	# slots
	var row_center := CenterContainer.new()
	row_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row_center)
	var bg := PanelContainer.new()
	var sb := HudStyle.panel(Color(0.04, 0.05, 0.08, 0.72), Color(HudStyle.C_BORDER.r, HudStyle.C_BORDER.g, HudStyle.C_BORDER.b, 0.55), 12, 1, 7.0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_center.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(row)
	for i in 8:
		if i == 2 or i == 6:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(10, 0)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sep)
		var s := HudSkillSlot.new()
		s.slot = i
		if i == 7:
			s.custom_minimum_size = Vector2(66, 66)
			s.size_flags_vertical = Control.SIZE_SHRINK_END
		elif i <= 1:
			s.custom_minimum_size = Vector2(56, 56)
			s.size_flags_vertical = Control.SIZE_SHRINK_END
		else:
			s.custom_minimum_size = Vector2(60, 60)
			s.size_flags_vertical = Control.SIZE_SHRINK_END
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
