extends PanelContainer
## Unit frame (look-dev player / target frames).
##   player: navy-glass gold panel, live 3D head portrait in a gold sunburst ring, name, class · group, slanted HP bar
##           (trail, shield, numbers), MP bar, status icons and kit-counter pips (Fighter.kit_counter / _max).
##   target: holo plate (cyan lines), team-colour name plate, class · group, HP bar with %, class emblem, statuses.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const HudBar := preload("res://ui/hud_bar.gd")
const HudStatusRow := preload("res://ui/hud_status_row.gd")
const GD := preload("res://ui/glory_draw.gd")
const CharPreview := preload("res://ui/char_preview.gd")

const MASK_SHADER: String = "shader_type canvas_item;\nuniform float grey = 0.0;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)); c.rgb = mix(c.rgb, vec3(l * 0.7), grey); float r = length(UV - 0.5); COLOR = vec4(c.rgb, c.a * smoothstep(0.5, 0.47, r)); }"


class Portrait extends Control:
	## Live 3D bust (the class's CharacterVisual idling in its own small World3D, see ui/char_preview.gd) masked to a
	## circle inside the gold sunburst ring; falls back to the class emblem for mobs / headless / missing visuals.
	var fighter: Fighter = null
	var ring: Color = Color.WHITE
	var dead: bool = false
	var live: bool = false
	var svc: SubViewportContainer
	var ring_layer: Control
	var _class: String = ""

	func _init(p_live: bool) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		live = p_live and DisplayServer.get_name() != "headless"
		if live:
			svc = CharPreview.new()
			svc.set_anchors_preset(Control.PRESET_FULL_RECT)
			svc.offset_left = 4
			svc.offset_top = 4
			svc.offset_right = -4
			svc.offset_bottom = -4
			var m := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = MASK_SHADER
			m.shader = sh
			svc.material = m
			add_child(svc)
			svc.call("set_head_shot", true)
			svc.visible = false
		ring_layer = Control.new()
		ring_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring_layer.draw.connect(_draw_ring)
		add_child(ring_layer)

	## Called by the frame when the bound fighter changes.
	func sync() -> void:
		if not live:
			return
		var cid := fighter.class_id if fighter != null and is_instance_valid(fighter) and fighter.kit != null else ""
		if cid != _class:
			_class = cid
			if cid != "":
				svc.call("set_class", cid)
			svc.visible = cid != "" and svc.get("visual") != null
		(svc.material as ShaderMaterial).set_shader_parameter("grey", 1.0 if dead else 0.0)
		queue_redraw()

	func _draw() -> void:
		var rad := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var ci := get_canvas_item()
		GD.circle(ci, c, rad - 3.0, Color(0.05, 0.09, 0.17, 0.98))
		GD.circle(ci, c + Vector2(0, -rad * 0.25), rad * 0.55, Color(0.3, 0.42, 0.7, 0.25))
		if live and svc != null and svc.visible:
			return
		if fighter != null and is_instance_valid(fighter):
			var er := Rect2(c - Vector2(rad, rad) * 0.72, Vector2(rad, rad) * 1.44)
			HudIcons.draw_class_emblem(self, er, fighter.class_id if fighter.kit != null else "", HudStyle.class_glyph(fighter),
				HudStyle.class_color(fighter), dead)

	func _draw_ring() -> void:
		var r := Rect2(Vector2.ZERO, ring_layer.size)
		GD.portrait_ring(ring_layer.get_canvas_item(), r, ring if ring.a > 0.0 else GD.GOLD, live or size.x > 80.0, true)


class Pips extends Control:
	## Kit counter (stacks / charges exposed by the class kit): diamond pips, or "x N" without a max.
	var count: int = 0
	var max_count: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 26)

	func set_counts(c: int, m: int) -> void:
		if c == count and m == max_count:
			return
		count = c
		max_count = m
		var n := max_count if max_count > 0 else (1 if count > 0 else 0)
		custom_minimum_size = Vector2(n * 18.0 + (26.0 if max_count <= 0 and count > 0 else 0.0), 26)
		visible = count > 0 or max_count > 0
		queue_redraw()

	func _draw() -> void:
		var ci := get_canvas_item()
		var cy := size.y * 0.5
		if max_count > 0:
			for i in max_count:
				var p := Vector2(9 + i * 18.0, cy)
				if i < count:
					GD.circle(ci, p, 8.0, Color(HudStyle.UI_CRYSTAL, 0.3))
					GD.diamond(ci, p, 5.5, 7.5, Color("#7FE8FF"))
				else:
					GD.polyline(ci, PackedVector2Array([p + Vector2(0, -7), p + Vector2(5, 0), p + Vector2(0, 7), p + Vector2(-5, 0)]),
						Color(HudStyle.UI_GOLD, 0.6), 1.0, true)
		elif count > 0:
			GD.diamond(ci, Vector2(9, cy), 5.5, 7.5, Color("#7FE8FF"))
			GD.text(ci, HudStyle.num(700), Vector2(18, cy + 8), "x%d" % count, 22, Color("#FFF4D0"), 4)


var portrait: Portrait
var name_label: Label
var class_label: Label
var info_label: Label
var pct_label: Label
var hp_bar: HudBar
var mp_bar: HudBar
var status_row: HudStatusRow
var pips: Pips
var name_plate: PanelContainer
var is_target: bool = false
var fighter_uid: int = 0

var _last_name: String = ""
var _last_dead: bool = false
var _plate_box: StyleBox


func _init(target_style: bool = false, width: float = 430.0) -> void:
	is_target = target_style
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(maxf(width, 400.0), 0)
	if target_style:
		_build_target()
	else:
		_build_player()


func _build_player() -> void:
	var sb := HudStyle.glory("panel", 0.0)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	portrait = Portrait.new(true)
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	name_label = HudStyle.make_label("", 22, HudStyle.C_TEXT, true, 4)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(60, 0)
	top.add_child(name_label)
	class_label = HudStyle.make_label("", 13, HudStyle.C_TEXT_DIM, false, 3)
	class_label.clip_text = true
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(class_label)
	info_label = HudStyle.make_label("", 13, HudStyle.C_TEXT_DIM)
	info_label.visible = false
	top.add_child(info_label)
	hp_bar = HudBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 21)
	hp_bar.font_size = 15
	hp_bar.ticks = 10
	hp_bar.text_align = 1
	hp_bar.fill_color = HudStyle.C_HP
	hp_bar.low_color = HudStyle.C_HP_LOW
	vb.add_child(hp_bar)
	mp_bar = HudBar.new()
	mp_bar.custom_minimum_size = Vector2(0, 12)
	mp_bar.fill_color = HudStyle.C_MP
	mp_bar.trail_color = HudStyle.C_MP
	mp_bar.show_text = false
	mp_bar.size_flags_horizontal = Control.SIZE_FILL
	vb.add_child(mp_bar)
	var srow := HBoxContainer.new()
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_theme_constant_override("separation", 10)
	vb.add_child(srow)
	status_row = HudStatusRow.new()
	status_row.icon_size = 28.0
	status_row.spacing = 4.0
	status_row.max_icons = 8
	status_row.custom_minimum_size = Vector2(0, 28)
	srow.add_child(status_row)
	pips = Pips.new()
	pips.visible = false
	srow.add_child(pips)
	pct_label = HudStyle.make_label("", 12)
	pct_label.visible = false
	srow.add_child(pct_label)


func _build_target() -> void:
	var sb := HudStyle.glory("holo", 0.0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)
	portrait = Portrait.new(false)
	portrait.custom_minimum_size = Vector2(58, 58)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	name_plate = PanelContainer.new()
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_box = HudStyle.glory("plate", 0.0, HudStyle.C_ENEMY)
	_plate_box.content_margin_left = 20.0
	_plate_box.content_margin_right = 18.0
	_plate_box.content_margin_top = 0.0
	_plate_box.content_margin_bottom = 1.0
	name_plate.add_theme_stylebox_override("panel", _plate_box)
	top.add_child(name_plate)
	name_label = HudStyle.make_label("", 18, HudStyle.C_TEXT, true, 3)
	name_plate.add_child(name_label)
	class_label = HudStyle.make_label("", 12, Color("#9FE6FF"), false, 3)
	class_label.clip_text = true
	class_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(class_label)
	info_label = HudStyle.make_label("", 12, Color(HudStyle.UI_CYAN, 0.85), false, 2)
	info_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(info_label)
	var hrow := HBoxContainer.new()
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_theme_constant_override("separation", 8)
	vb.add_child(hrow)
	hp_bar = HudBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 18)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.ticks = 10
	hp_bar.show_text = false
	hp_bar.frame_color = Color(HudStyle.UI_CYAN, 0.9)
	hp_bar.low_color = HudStyle.C_HP_LOW
	hrow.add_child(hp_bar)
	pct_label = HudStyle.make_label_f("", HudStyle.num(650), 26, HudStyle.C_TEXT, 4)
	pct_label.custom_minimum_size = Vector2(52, 0)
	pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hrow.add_child(pct_label)
	mp_bar = HudBar.new()
	mp_bar.custom_minimum_size = Vector2(0, 6)
	mp_bar.fill_color = HudStyle.C_MP
	mp_bar.trail_color = HudStyle.C_MP
	mp_bar.show_text = false
	mp_bar.ticks = 0
	mp_bar.frame_color = Color(0, 0, 0, 0)
	vb.add_child(mp_bar)
	status_row = HudStatusRow.new()
	status_row.icon_size = 26.0
	status_row.spacing = 4.0
	status_row.custom_minimum_size = Vector2(0, 26)
	vb.add_child(status_row)


## Refresh from a fighter (null hides). `viewer` decides ally/enemy colouring.
func refresh(f: Fighter, viewer: Fighter) -> void:
	if f == null or not is_instance_valid(f):
		visible = false
		fighter_uid = 0
		if portrait != null:
			portrait.fighter = null
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
		# no levels in this game: class + group instead of the look-dev "Lv.75"
		var grp_cn := grp.split(" ")[0] if grp != "" else ""
		if is_target:
			class_label.text = (f.kit.name_cn if f.kit != null else cls) + ("  ·  " + grp_cn if grp_cn != "" and grp_cn != cls else "")
		else:
			class_label.text = cls + ("  ·  " + grp_cn if grp_cn != "" and grp_cn != cls else "")
		if not is_target:
			class_label.add_theme_color_override("font_color", HudStyle.class_color(f).lerp(HudStyle.C_TEXT_DIM, 0.45))
		portrait.fighter = f
		portrait.dead = dead
		portrait.sync()
		portrait.ring_layer.queue_redraw()
	var ring := HudStyle.C_ENEMY if enemy else GD.GOLD
	if f.kind == "boss":
		ring = HudStyle.C_BOSS
	if ring != portrait.ring:
		portrait.ring = ring
		portrait.ring_layer.queue_redraw()
	if is_target and _plate_box != null:
		var pc := HudStyle.C_BOSS if f.kind == "boss" else (HudStyle.C_ENEMY if enemy else HudStyle.C_ALLY)
		if _plate_box.get("accent") != pc:
			_plate_box.set("accent", pc)
			name_plate.queue_redraw()
	name_label.add_theme_color_override("font_color", HudStyle.C_TEXT if not dead else Color(0.6, 0.6, 0.6))
	hp_bar.fill_color = HudStyle.C_HP if (enemy or not is_target) else HudStyle.C_HP_ALLY
	hp_bar.dead = dead
	hp_bar.set_values(f.hp, f.max_hp, f.shield_hp)
	mp_bar.visible = f.max_mp > 0.0
	mp_bar.set_values(f.mp, f.max_mp)
	status_row.set_mask(f.status_mask)
	if is_target:
		pct_label.text = "%d%%" % int(ceil(f.hp / maxf(f.max_hp, 1.0) * 100.0)) if not dead else "0%"
		if viewer != null and is_instance_valid(viewer) and viewer != f:
			info_label.text = "目标  %.0fm" % viewer.global_position.distance_to(f.global_position)
		else:
			info_label.text = "目标"
	else:
		info_label.text = ""
		var kc: Variant = f.get("kit_counter")
		var km: Variant = f.get("kit_counter_max")
		pips.set_counts(int(kc) if kc != null else 0, int(km) if km != null else 0)
