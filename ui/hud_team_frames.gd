extends VBoxContainer
## Party / team frames (allies: hp, mp, class, statuses, dead state) or a compact enemy team summary.
## Rows are pooled (created once up to MAX_ROWS) and re-bound each refresh.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudStatusRow := preload("res://ui/hud_status_row.gd")

const MAX_ROWS: int = 9


class Badge extends Control:
	var fighter: Fighter = null
	var ring: Color = Color.WHITE
	var dead: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fighter != null and is_instance_valid(fighter):
			HudIcons.draw_portrait(self, size * 0.5, minf(size.x, size.y) * 0.5, fighter, ring, dead)
		if dead:
			var c := size * 0.5
			var r := minf(size.x, size.y) * 0.3
			draw_line(c - Vector2(r, r), c + Vector2(r, r), Color(1, 0.3, 0.3, 0.9), 3.0, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color(1, 0.3, 0.3, 0.9), 3.0, true)


class Row extends PanelContainer:
	var badge: Badge
	var name_label: Label
	var class_label: Label
	var hp: HudBar
	var mp: HudBar
	var statuses: HudStatusRow
	var uid: int = 0
	var compact: bool = false
	var _dead: bool = false
	var _name: String = ""

	func _init(p_compact: bool) -> void:
		compact = p_compact
		mouse_filter = Control.MOUSE_FILTER_PASS
		var sb: StyleBox
		if compact:
			sb = HudStyle.glory("holo", 0.0, Color(HudStyle.C_ENEMY.lerp(Color.WHITE, 0.2), 0.9))
		else:
			sb = HudStyle.glory("panel", 0.0, Color(0, 0, 0, 0), false)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		add_theme_stylebox_override("panel", sb)
		custom_minimum_size = Vector2(230 if compact else 268, 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hb)
		badge = Badge.new()
		badge.custom_minimum_size = Vector2(32, 32) if compact else Vector2(42, 42)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(badge)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(vb)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 8)
		vb.add_child(top)
		name_label = HudStyle.make_label("", 14 if compact else 16, HudStyle.C_TEXT, true, 3)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		class_label = HudStyle.make_label("", 11, HudStyle.C_TEXT_DIM, false, 2)
		class_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(class_label)
		hp = HudBar.new()
		hp.custom_minimum_size = Vector2(0, 10 if compact else 13)
		hp.show_text = false
		hp.text_mode = 1
		hp.font_size = 10
		hp.ticks = 0 if compact else 10
		hp.low_color = HudStyle.C_HP_LOW
		hp.frame_color = Color(HudStyle.UI_GOLD, 0.7) if not compact else Color(HudStyle.C_ENEMY, 0.7)
		vb.add_child(hp)
		mp = HudBar.new()
		mp.custom_minimum_size = Vector2(0, 5)
		mp.fill_color = HudStyle.C_MP
		mp.trail_color = HudStyle.C_MP
		mp.show_text = false
		mp.ticks = 0
		mp.frame_color = Color(0, 0, 0, 0)
		mp.visible = not compact
		vb.add_child(mp)
		statuses = HudStatusRow.new()
		statuses.icon_size = 20.0
		statuses.spacing = 3.0
		statuses.max_icons = 6
		statuses.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		statuses.visible = not compact
		hb.add_child(statuses)

	func bind(f: Fighter, viewer: Fighter) -> void:
		var dead := not f.is_alive()
		var enemy := viewer != null and is_instance_valid(viewer) and f.team != viewer.team
		if f.uid != uid:
			uid = f.uid
			_name = ""
			hp.set_values(f.hp, f.max_hp, f.shield_hp)
			hp.snap()
		var nm := f.display_name
		if nm != _name or dead != _dead:
			_name = nm
			_dead = dead
			name_label.text = nm
			class_label.text = HudStyle.class_cn(f)
			name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58) if dead else HudStyle.C_TEXT)
			badge.fighter = f
			badge.dead = dead
			badge.ring = HudStyle.C_ENEMY if enemy else HudStyle.UI_GOLD
			badge.queue_redraw()
			modulate.a = 0.6 if dead else 1.0
			tooltip_text = "%s\n%s\n%s" % [nm, HudStyle.class_name_of(f), HudStyle.group_name_of(f)]
		hp.fill_color = HudStyle.C_HP_ENEMY if enemy else HudStyle.C_HP_ALLY
		hp.dead = dead
		var hidden := enemy and f.is_stealthed
		if hidden:
			hp.text_mode = 3
			hp.show_text = true
			hp.custom_text = "隐身 Stealth"
			hp.set_values(f.max_hp, f.max_hp)
		else:
			hp.text_mode = 1 if not dead else 3
			hp.show_text = dead
			hp.custom_text = "阵亡 Dead"
			hp.set_values(f.hp, f.max_hp, f.shield_hp)
		mp.set_values(f.mp, maxf(f.max_mp, 1.0))
		mp.visible = not compact and f.max_mp > 0.0
		statuses.set_mask(0 if hidden else f.status_mask)


var enemy_mode: bool = false
var rows: Array = []
var title: Label


func _init(p_enemy_mode: bool = false) -> void:
	enemy_mode = p_enemy_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)
	title = HudStyle.make_label("敌方 Enemies" if enemy_mode else "队伍 Party", 13, HudStyle.UI_GOLD_HI, true, 3)
	if enemy_mode:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(title)
	for i in MAX_ROWS:
		var r := Row.new(enemy_mode)
		r.visible = false
		add_child(r)
		rows.append(r)


## `fighters`: the fighters to show (already filtered/sorted by the Hud).
func refresh(fighters: Array, viewer: Fighter) -> void:
	var n := 0
	for f: Variant in fighters:
		if n >= MAX_ROWS:
			break
		if not is_instance_valid(f):
			continue
		var row: Row = rows[n]
		row.visible = true
		row.bind(f as Fighter, viewer)
		n += 1
	for i in range(n, MAX_ROWS):
		(rows[i] as Row).visible = false
		(rows[i] as Row).uid = 0
	visible = n > 0
