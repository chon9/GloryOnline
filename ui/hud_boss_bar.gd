extends PanelContainer
## Boss bar at the top of the screen: name CN/EN, wide HP bar (trail, shield, % text), phase and enrage.
## Phase source (first available): boss brain `phase` (host, 0-based), Match score int "phase" (raid, 0-based) / "boss_phase", else mob_def.boss.phases HP thresholds.

const HudStyle := preload("res://ui/hud_style.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudStatusRow := preload("res://ui/hud_status_row.gd")

const ENRAGE_FRAC: float = 0.10

var name_label: Label
var phase_label: Label
var enrage_label: Label
var hp_bar: HudBar
var status_row: HudStatusRow
var boss_uid: int = 0
var _t: float = 0.0
var _enraged: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.glory("panel", 0.0)
	sb.set("fill", Color(0.09, 0.04, 0.06, 0.9))
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(720, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	phase_label = HudStyle.make_label("", 14, HudStyle.UI_GOLD_HI, true, 3)
	phase_label.custom_minimum_size = Vector2(150, 0)
	top.add_child(phase_label)
	name_label = HudStyle.make_label("", 22, Color("#FFD9A0"), true, 5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	enrage_label = HudStyle.make_label("", 15, Color(1, 0.3, 0.2), true)
	enrage_label.custom_minimum_size = Vector2(150, 0)
	enrage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(enrage_label)
	hp_bar = HudBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 24)
	hp_bar.fill_color = Color(0.85, 0.16, 0.14)
	hp_bar.trail_color = Color(1.0, 0.78, 0.35)
	hp_bar.text_mode = 3
	hp_bar.font_size = 15
	hp_bar.ticks = 10
	vb.add_child(hp_bar)
	status_row = HudStatusRow.new()
	status_row.icon_size = 24.0
	vb.add_child(status_row)
	set_process(false)


func refresh(boss: Fighter, score: Dictionary) -> void:
	if boss == null or not is_instance_valid(boss):
		visible = false
		boss_uid = 0
		set_process(false)
		return
	visible = true
	if boss.uid != boss_uid:
		boss_uid = boss.uid
		name_label.text = boss.display_name
		hp_bar.set_values(boss.hp, boss.max_hp, boss.shield_hp)
		hp_bar.snap()
	var frac := boss.hp / maxf(boss.max_hp, 1.0)
	hp_bar.custom_text = "%s / %s   %.1f%%" % [HudStyle.fmt_num(boss.hp), HudStyle.fmt_num(boss.max_hp), frac * 100.0]
	hp_bar.set_values(boss.hp, boss.max_hp, boss.shield_hp)
	hp_bar.queue_redraw()
	status_row.set_mask(boss.status_mask)
	var phase := _phase_of(boss, score)
	phase_label.text = "阶段 Phase %d" % phase if phase > 0 else ""
	_enraged = boss.is_alive() and (frac <= ENRAGE_FRAC or bool(score.get("boss_enraged", false)) or (score.get("enraged", false) is bool and bool(score.get("enraged", false))) or _brain_bool(boss, "enraged"))
	enrage_label.text = "狂暴 ENRAGED" if _enraged else ""
	hp_bar.fill_color = Color(1.0, 0.1, 0.05) if _enraged else Color(0.85, 0.16, 0.14)
	if not boss.is_alive():
		hp_bar.custom_text = "已击败 Defeated"
	set_process(_enraged)
	if not _enraged:
		enrage_label.modulate.a = 1.0


func _process(delta: float) -> void:
	_t += delta
	enrage_label.modulate.a = 0.55 + 0.45 * sin(_t * 9.0)


func is_enraged() -> bool:
	return _enraged


func _brain_bool(boss: Fighter, prop: String) -> bool:
	if boss.brain != null and is_instance_valid(boss.brain) and prop in boss.brain:
		return bool(boss.brain.get(prop))
	return false


func _phase_of(boss: Fighter, score: Dictionary) -> int:
	# BossBrain.phase is 0-based (index into data.phases); display is 1-based.
	if boss.brain != null and is_instance_valid(boss.brain) and "phase" in boss.brain:
		return int(boss.brain.get("phase")) + 1
	# MatchRaid sends score.phase as a 0-based int (PvP may send a String "phase" -- ignored).
	var sp: Variant = score.get("phase", null)
	if sp is int:
		return int(sp) + 1
	if score.has("boss_phase"):
		return int(score["boss_phase"])
	var frac := boss.hp / maxf(boss.max_hp, 1.0)
	var bdef: Variant = boss.mob_def.get("boss", {})
	var phases: Variant = (bdef as Dictionary).get("phases", null) if bdef is Dictionary else null
	if phases == null:
		phases = boss.mob_def.get("phases", null)
	if phases is Array and (phases as Array).size() > 0:
		var arr: Array = phases
		var p := 1
		for i in range(1, arr.size()):
			var th: Variant = arr[i]
			var v := float((th as Dictionary).get("hp", 0.0)) if th is Dictionary else float(th)
			if frac <= v:
				p += 1
		return p
	return 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
