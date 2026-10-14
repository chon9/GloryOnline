extends PanelContainer
## Class picker (owner: NET, look: UI track): every Registry kit as an emblem chip grouped by the 6 base groups
## + 散人, and a detail column for the previewed class: turning CharacterVisual showcase, brush CN name + EN name,
## group / weapon / role / famous player, and the 8 skills with painted icons (hover for the full tooltip).
## Emits class_chosen(id) on "选择 Select". describe(id) returns the full BBCode text (tests, tooltips).

signal class_chosen(class_id: String)

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const HudSkillSlot := preload("res://ui/hud_skill_slot.gd")
const GD := preload("res://ui/glory_draw.gd")
const CharPreview := preload("res://ui/char_preview.gd")

const SLOT_KEYS: Array[String] = ["左键 LMB", "右键 RMB", "Q", "E", "R", "F", "1", "2"]
const ROLE_NAMES: Dictionary = {
	"melee": "近战 Melee", "ranged": "远程 Ranged", "tank": "坦克 Tank", "healer": "治疗 Healer",
	"support": "辅助 Support", "control": "控制 Control", "summoner": "召唤 Summoner", "hybrid": "全能 Hybrid",
}
const CHIP_W: float = 136.0
const CHIP_H: float = 50.0


class SkillRow extends HBoxContainer:
	## Icon + key + CN/EN name + cooldown; the slot tooltip on hover.
	var skill: SkillDef = null
	var tint: Color = Color.WHITE
	var key: String = ""
	var icon: Control
	var name_l: Label
	var meta_l: Label

	func _init() -> void:
		add_theme_constant_override("separation", 8)
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "
		icon = Control.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func() -> void:
			if skill != null:
				HudIcons.draw_skill_icon(icon, Rect2(Vector2.ZERO, icon.size), skill, tint))
		add_child(icon)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(v)
		name_l = HudStyle.make_label("", 14, HudStyle.C_TEXT, true, 2)
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(name_l)
		meta_l = HudStyle.make_label("", 11, HudStyle.C_TEXT_DIM, false, 2)
		meta_l.clip_text = true
		meta_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(meta_l)

	func bind(s: SkillDef, p_tint: Color, p_key: String) -> void:
		skill = s
		tint = p_tint
		key = p_key
		visible = s != null
		if s == null:
			return
		name_l.text = "%s  %s" % [s.name_cn, s.name_en]
		name_l.add_theme_color_override("font_color", HudStyle.UI_GOLD_HI if s.is_ultimate() else HudStyle.C_TEXT)
		var m := "[%s]" % p_key
		m += ("   CD %.0fs" % s.cooldown) if s.cooldown > 0.0 else ""
		m += ("   MP %d" % int(s.mp_cost)) if s.mp_cost > 0.0 else ""
		if s.is_ultimate():
			m += "   觉醒 Ultimate"
		meta_l.text = m
		icon.queue_redraw()

	func _make_custom_tooltip(_t: String) -> Object:
		return HudSkillSlot.make_tooltip_panel(skill, key)


var preview_id: String = ""
## Text shown above the Select button (who the pick applies to).
var target_label: String = ""

var _groups_box: VBoxContainer
var _details: RichTextLabel
var _target: Label
var _select: Button
var _buttons: Dictionary = {}
var _preview: Control
var _name_cn: Label
var _name_en: Label
var _info: RichTextLabel
var _skill_rows: Array = []
var _emblem: Control


func _ready() -> void:
	custom_minimum_size = Vector2(1000, 0)
	var sb := HudStyle.glory("panel", 0.0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", sb)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	# ---- left: title + group rows of emblem chips
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	left.add_child(th)
	var title := HudStyle.make_label_f("职业选择", HudStyle.brush(), 36, HudStyle.UI_GOLD_HI, 5)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0, 0.95))
	th.add_child(title)
	var te := HudStyle.make_label_f("CLASS SELECT", HudStyle.tech(800), 14, HudStyle.C_TEXT_DIM, 2)
	te.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(te)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(78 + 4 * (CHIP_W + 6), 7 * (CHIP_H + 6))
	left.add_child(scroll)
	_groups_box = VBoxContainer.new()
	_groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_groups_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	_target = HudStyle.make_label("", 15, HudStyle.C_TEXT, false, 2)
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.clip_text = true
	_target.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_target.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_target)
	_select = Button.new()
	_select.text = "选择  Select"
	_select.custom_minimum_size = Vector2(170, 46)
	_select.add_theme_font_size_override("font_size", 19)
	_select.pressed.connect(func() -> void:
		if preview_id != "":
			class_chosen.emit(preview_id))
	row.add_child(_select)
	# ---- right: showcase + info + skills
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(318, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 210)
	stage.clip_contents = true
	stage.draw.connect(func() -> void:
		var ci := stage.get_canvas_item()
		var r := Rect2(Vector2.ZERO, stage.size)
		GD.poly_grad(ci, PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
			PackedColorArray([Color(0.06, 0.1, 0.2, 0.9), Color(0.1, 0.14, 0.28, 0.9), Color(0.16, 0.1, 0.12, 0.9), Color(0.04, 0.06, 0.12, 0.9)]))
		GD.polyline(ci, GD.chamfer(r, 8.0), Color(GD.GOLD, 0.6), 1.0, true))
	right.add_child(stage)
	_preview = CharPreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 90
	stage.add_child(_preview)
	_emblem = Control.new()
	_emblem.position = Vector2(12, 12)
	_emblem.size = Vector2(72, 72)
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.draw.connect(func() -> void:
		var k := _kit(preview_id)
		if k != null:
			HudIcons.draw_class_emblem(_emblem, Rect2(Vector2.ZERO, _emblem.size), k.id, k.name_cn.substr(0, 1), k.tint))
	stage.add_child(_emblem)
	var nv := VBoxContainer.new()
	nv.position = Vector2(12, 128)
	nv.add_theme_constant_override("separation", -8)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(nv)
	_name_cn = HudStyle.make_label_f("", HudStyle.brush(), 50, Color.WHITE, 7)
	_name_cn.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0, 0.95))
	nv.add_child(_name_cn)
	_name_en = HudStyle.make_label_f("", HudStyle.tech(800), 14, HudStyle.UI_GOLD_HI, 3)
	nv.add_child(_name_en)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 13)
	right.add_child(_info)
	var sep := HSeparator.new()
	right.add_child(sep)
	var sk := VBoxContainer.new()
	sk.add_theme_constant_override("separation", 2)
	right.add_child(sk)
	for i in 8:
		var sr := SkillRow.new()
		sk.add_child(sr)
		_skill_rows.append(sr)
	# hidden full description (kept for tooltips / older callers)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.visible = false
	add_child(_details)
	rebuild()


func _registry() -> Node:
	return get_node_or_null("/root/Registry")


func _kit(id: String) -> ClassKit:
	var r := _registry()
	if r == null:
		return null
	var k: Variant = r.call("get_kit", id)
	return k if k is ClassKit else null


## Rebuilds the class chips from the Registry.
func rebuild() -> void:
	if _groups_box == null:
		return
	for c: Node in _groups_box.get_children():
		c.queue_free()
	_buttons.clear()
	var r := _registry()
	if r == null:
		return
	var by: Dictionary = r.call("kit_ids_by_group")
	for g: Variant in by:
		var ids: Array = by[g]
		if ids.is_empty():
			continue
		var names: Dictionary = ClassKit.GROUP_NAMES.get(str(g), {"cn": str(g), "en": str(g)})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_groups_box.add_child(row)
		var gl := HudStyle.make_label("%s\n%s" % [names.get("cn", ""), names.get("en", "")], 12, HudStyle.UI_GOLD_HI, true, 2)
		gl.custom_minimum_size = Vector2(72, 0)
		gl.add_theme_constant_override("line_spacing", -4)
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(gl)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		row.add_child(flow)
		for id: Variant in ids:
			var k := _kit(str(id))
			if k == null:
				continue
			var b := _make_chip(k)
			var cid := str(id)
			b.pressed.connect(func() -> void: preview(cid))
			flow.add_child(b)
			_buttons[cid] = b
	if preview_id == "" or not _buttons.has(preview_id):
		var ids2: Array = _buttons.keys()
		if not ids2.is_empty():
			preview(str(ids2[0]))
	else:
		preview(preview_id)


## Emblem chip: class emblem at the left, CN name over EN name, class-tint stripe; gold frame when picked.
func _make_chip(k: ClassKit) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [k.name_cn, k.name_en]
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CHIP_W, CHIP_H)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_override("font", HudStyle.sans(700))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_constant_override("line_spacing", -3)
	b.tooltip_text = "%s %s\n%s" % [k.name_cn, k.name_en, k.famous]
	var tint := k.tint
	for st: Array in [["normal", "chip"], ["hover", "chip_hover"], ["pressed", "chip_on"], ["hover_pressed", "chip_on"], ["disabled", "chip"]]:
		var sb := HudStyle.glory(str(st[1]), 0.0, tint)
		sb.content_margin_left = 48.0
		sb.content_margin_right = 4.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		b.add_theme_stylebox_override(str(st[0]), sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", HudStyle.C_TEXT)
	b.add_theme_color_override("font_hover_color", HudStyle.UI_GOLD_HI)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	var cid := k.id
	var glyph := k.name_cn.substr(0, 1)
	b.draw.connect(func() -> void:
		HudIcons.draw_class_emblem(b, Rect2(Vector2(9, (b.size.y - 36.0) * 0.5), Vector2(36, 36)), cid, glyph, tint))
	return b


func set_target_label(text: String) -> void:
	target_label = text
	if _target != null:
		_target.text = text


func set_select_enabled(on: bool) -> void:
	if _select != null:
		_select.disabled = not on


func preview(id: String) -> void:
	preview_id = id
	for bid: Variant in _buttons:
		(_buttons[bid] as Button).set_pressed_no_signal(str(bid) == id)
	if _details != null:
		_details.text = describe(id)
	if _target != null:
		_target.text = target_label
	var k := _kit(id)
	if k == null or _name_cn == null:
		return
	_preview.call("set_class", id)
	_name_cn.text = k.name_cn
	_name_en.text = k.name_en.to_upper()
	_emblem.queue_redraw()
	var names: Dictionary = ClassKit.GROUP_NAMES.get(k.group_id, {"cn": k.group_cn, "en": k.group_en})
	var wcn := k.weapon_name_cn if k.weapon_name_cn != "" else k.weapon_type
	var t := "[color=#9aa6b8]职业系 Group[/color]  %s %s    [color=#9aa6b8]定位 Role[/color]  %s\n" % [
		names.get("cn", ""), names.get("en", ""), ROLE_NAMES.get(k.role, k.role)]
	t += "[color=#9aa6b8]武器 Weapon[/color]  %s %s" % [wcn, k.weapon_name_en]
	if k.famous != "":
		t += "\n[color=#9aa6b8]代表人物 Famous[/color]  [color=#ffe9a8]%s[/color]" % k.famous
	_info.text = t
	var by_slot: Dictionary = {}
	for s: SkillDef in k.skills:
		by_slot[s.slot] = s
	for i in 8:
		(_skill_rows[i] as SkillRow).bind(by_slot.get(i, null), k.tint, SLOT_KEYS[i])


## BBCode description of a class (also used by tests).
func describe(id: String) -> String:
	var k := _kit(id)
	if k == null:
		return "未知职业 Unknown class: %s" % id
	var names: Dictionary = ClassKit.GROUP_NAMES.get(k.group_id, {"cn": k.group_cn, "en": k.group_en})
	var t := "[b][color=#%s]%s %s[/color][/b]\n" % [k.tint.lerp(Color.WHITE, 0.4).to_html(false), k.name_cn, k.name_en]
	t += "职业系 Group: %s %s    定位 Role: %s\n" % [names.get("cn", ""), names.get("en", ""), ROLE_NAMES.get(k.role, k.role)]
	var wcn := k.weapon_name_cn if k.weapon_name_cn != "" else k.weapon_type
	t += "武器 Weapon: %s %s" % [wcn, k.weapon_name_en]
	if k.offhand != "":
		t += " + %s" % k.offhand
	t += "\n"
	if k.famous != "":
		t += "代表人物 Famous: %s\n" % k.famous
	var st := k.get_stats()
	t += "生命 HP %d  法力 MP %d  物攻 PAtk %d  法攻 MAtk %d  物防 PDef %d  法防 MDef %d\n" % [
		int(st.get("hp", 0)), int(st.get("mp", 0)), int(st.get("patk", 0)), int(st.get("matk", 0)),
		int(st.get("pdef", 0)), int(st.get("mdef", 0))]
	for p: Dictionary in k.passives:
		t += "[color=#9fd3ff]被动 Passive: %s %s[/color] - %s\n" % [p.get("name_cn", ""), p.get("name_en", ""), p.get("desc", "")]
	t += "[b]技能 Skills[/b]\n"
	for s: SkillDef in k.skills:
		var key: String = SLOT_KEYS[s.slot] if s.slot >= 0 and s.slot < SLOT_KEYS.size() else str(s.slot)
		var ult := " [color=#ffcf5a](大招 Ultimate)[/color]" if s.slot == 7 else ""
		t += "[color=#ffe7a0][%s][/color] [b]%s %s[/b]%s  CD %.1fs  MP %d\n" % [key, s.name_cn, s.name_en, ult, s.cooldown, int(s.mp_cost)]
		if s.desc != "":
			t += "    %s\n" % s.desc
	return t
