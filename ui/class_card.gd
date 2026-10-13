extends PanelContainer
## Class picker widget (owner: NET): every Registry kit grouped by the 6 base groups + 散人, and a detail
## card for the previewed class (CN/EN names, group, weapon, role, famous player, stats, passives and the
## 8 skills with CN/EN names, key, cooldown and description). Emits class_chosen(id) on "选择 Select".

signal class_chosen(class_id: String)

const SLOT_KEYS: Array[String] = ["左键 LMB", "右键 RMB", "Q", "E", "R", "F", "1", "2"]
const ROLE_NAMES: Dictionary = {
	"melee": "近战 Melee", "ranged": "远程 Ranged", "tank": "坦克 Tank", "healer": "治疗 Healer",
	"support": "辅助 Support", "control": "控制 Control", "summoner": "召唤 Summoner", "hybrid": "全能 Hybrid",
}

var preview_id: String = ""
## Text shown above the Select button (who the pick applies to).
var target_label: String = ""

var _groups_box: VBoxContainer
var _details: RichTextLabel
var _target: Label
var _select: Button
var _buttons: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(770, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var title := Label.new()
	title.text = "职业选择 Class Select"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	var scroll := ScrollContainer.new()
	# Tall enough for all 7 groups (one row each) at 1600x900, so every class is visible at once.
	scroll.custom_minimum_size = Vector2(0, 286)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_groups_box = VBoxContainer.new()
	_groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_groups_box)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.custom_minimum_size = Vector2(0, 200)
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.add_theme_font_size_override("bold_font_size", 16)
	root.add_child(_details)
	var row := HBoxContainer.new()
	root.add_child(row)
	_target = Label.new()
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.clip_text = true
	row.add_child(_target)
	_select = Button.new()
	_select.text = "选择 Select"
	_select.pressed.connect(func() -> void:
		if preview_id != "":
			class_chosen.emit(preview_id))
	row.add_child(_select)
	rebuild()


func _registry() -> Node:
	return get_node_or_null("/root/Registry")


func _kit(id: String) -> ClassKit:
	var r := _registry()
	if r == null:
		return null
	var k: Variant = r.call("get_kit", id)
	return k if k is ClassKit else null


## Rebuilds the class buttons from the Registry.
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
		# One row per group: fixed-width group caption + the group's class buttons.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_groups_box.add_child(row)
		var gl := Label.new()
		gl.text = "%s
%s" % [names.get("cn", ""), names.get("en", "")]
		gl.custom_minimum_size = Vector2(92, 0)
		gl.add_theme_font_size_override("font_size", 13)
		gl.add_theme_constant_override("line_spacing", -3)
		gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(gl)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		row.add_child(flow)
		for id: Variant in ids:
			var k := _kit(str(id))
			if k == null:
				continue
			var b := Button.new()
			b.text = "%s %s" % [k.name_cn, k.name_en]
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 14)
			_style_class_button(b, k.tint)
			var cid := str(id)
			b.pressed.connect(func() -> void: preview(cid))
			flow.add_child(b)
			_buttons[cid] = b
	if preview_id == "" or not _buttons.has(preview_id):
		var ids: Array = _buttons.keys()
		if not ids.is_empty():
			preview(str(ids[0]))
	else:
		preview(preview_id)


## Dark class chip with the class tint as a left stripe (readable on any theme); gold border when picked.
static func _style_class_button(b: Button, tint: Color) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	base.border_color = tint
	base.border_width_left = 4
	base.set_corner_radius_all(3)
	base.content_margin_left = 9.0
	base.content_margin_right = 7.0
	base.content_margin_top = 4.0
	base.content_margin_bottom = 4.0
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.22, 0.28, 0.98)
	var picked := base.duplicate() as StyleBoxFlat
	picked.bg_color = tint.darkened(0.55)
	picked.border_color = Color(1.0, 0.82, 0.35)
	picked.set_border_width_all(2)
	picked.border_width_left = 4
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", picked)
	b.add_theme_stylebox_override("hover_pressed", picked)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var txt := tint.lerp(Color.WHITE, 0.7)
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


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
