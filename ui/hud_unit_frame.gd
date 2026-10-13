extends PanelContainer
## Unit frame (player / lock-on target): class portrait, name, class + group, HP (shield, trail), MP, statuses.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudStatusRow := preload("res://ui/hud_status_row.gd")


class Portrait extends Control:
	var fighter: Fighter = null
	var ring: Color = Color.WHITE
	var dead: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fighter == null or not is_instance_valid(fighter):
			return
		var rad := minf(size.x, size.y) * 0.5
		HudIcons.draw_portrait(self, size * 0.5, rad, fighter, ring, dead)


var portrait: Portrait
var name_label: Label
var class_label: Label
var info_label: Label
var hp_bar: HudBar
var mp_bar: HudBar
var status_row: HudStatusRow
var is_target: bool = false
var fighter_uid: int = 0

var _last_name: String = ""
var _last_dead: bool = false


func _init(target_style: bool = false, width: float = 360.0) -> void:
	is_target = target_style
	mouse_filter = Control.MOUSE_FILTER_PASS
	var border := HudStyle.C_ENEMY if target_style else HudStyle.C_BORDER
	var sb := HudStyle.panel(HudStyle.C_PANEL, Color(border.r, border.g, border.b, 0.7), 10, 1, 7.0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(width, 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(62, 62)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	name_label = HudStyle.make_label("", 17, HudStyle.C_TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	info_label = HudStyle.make_label("", 13, HudStyle.C_TEXT_DIM)
	top.add_child(info_label)
	class_label = HudStyle.make_label("", 13, HudStyle.C_TEXT_DIM)
	class_label.clip_text = true
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(class_label)
	hp_bar = HudBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 19)
	hp_bar.font_size = 13
	hp_bar.ticks = 10
	hp_bar.low_color = HudStyle.C_HP_LOW
	vb.add_child(hp_bar)
	mp_bar = HudBar.new()
	mp_bar.custom_minimum_size = Vector2(0, 13)
	mp_bar.fill_color = HudStyle.C_MP
	mp_bar.trail_color = Color(0.45, 0.6, 0.9, 0.7)
	mp_bar.font_size = 11
	vb.add_child(mp_bar)
	status_row = HudStatusRow.new()
	status_row.icon_size = 20.0
	status_row.custom_minimum_size = Vector2(0, 20)
	vb.add_child(status_row)


## Refresh from a fighter (null hides). `viewer` decides ally/enemy coloring.
func refresh(f: Fighter, viewer: Fighter) -> void:
	if f == null or not is_instance_valid(f):
		visible = false
		fighter_uid = 0
		return
	visible = true
	var dead := not f.is_alive()
	if f.uid != fighter_uid:
		fighter_uid = f.uid
		_last_name = ""
		hp_bar.set_values(f.hp, f.max_hp, f.shield_hp)
		hp_bar.snap()
		mp_bar.set_values(f.mp, f.max_mp)
		mp_bar.snap()
	var enemy := viewer != null and is_instance_valid(viewer) and f.team != viewer.team
	var nm := f.display_name
	if nm != _last_name or dead != _last_dead:
		_last_name = nm
		_last_dead = dead
		name_label.text = nm + ("  [阵亡 Dead]" if dead else "")
		var cls := HudStyle.class_name_of(f)
		var grp := HudStyle.group_name_of(f)
		class_label.text = cls + ("  ·  " + grp if grp != "" and grp != cls else "")
		class_label.add_theme_color_override("font_color", HudStyle.class_color(f))
		portrait.fighter = f
		portrait.dead = dead
		portrait.queue_redraw()
	var ring := HudStyle.C_ENEMY if enemy else (HudStyle.C_SELF if viewer == f else HudStyle.C_ALLY)
	if f.kind == "boss":
		ring = HudStyle.C_BOSS
	if ring != portrait.ring:
		portrait.ring = ring
		portrait.queue_redraw()
	name_label.add_theme_color_override("font_color", HudStyle.C_TEXT if not dead else Color(0.6, 0.6, 0.6))
	hp_bar.fill_color = HudStyle.C_HP_ENEMY if enemy else HudStyle.C_HP
	hp_bar.dead = dead
	hp_bar.set_values(f.hp, f.max_hp, f.shield_hp)
	mp_bar.visible = f.max_mp > 0.0
	mp_bar.set_values(f.mp, f.max_mp)
	status_row.set_mask(f.status_mask)
	if is_target and viewer != null and is_instance_valid(viewer) and viewer != f:
		info_label.text = "%.0fm" % viewer.global_position.distance_to(f.global_position)
	else:
		info_label.text = ""
