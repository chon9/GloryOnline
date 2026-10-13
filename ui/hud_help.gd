extends PanelContainer
## F1 help overlay: the local class's 8 skills (icon, key, CN/EN name, description, cooldown/MP), passives
## and the control scheme. Rebuilt only when the bound class changes.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const HudSkillSlot := preload("res://ui/hud_skill_slot.gd")

const CONTROLS: Array = [
	["W A S D", "移动 Move"], ["空格 Space", "跳跃 / 受身 Jump / Quick recover"],
	["左键 LMB", "普攻连招 Basic attack chain"], ["右键 RMB", "职业副技能 Class secondary"],
	["Q E R F 1", "技能 Skills"], ["2", "大招 Ultimate"],
	["Tab", "切换锁定 Cycle lock-on"], ["中键 MMB", "锁定 / 取消 Toggle lock-on"],
	["`", "按住查看战绩 Hold for scoreboard"], ["F1", "帮助 Help"],
	["Esc", "菜单 / 鼠标 Menu / cursor"], ["滚轮 Wheel", "镜头缩放 Camera zoom"],
]


class SkillIcon extends Control:
	var skill: SkillDef = null
	var tint: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(52, 52)

	func _draw() -> void:
		HudIcons.draw_skill_icon(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)), skill, tint)


var title: Label
var info: Label
var skill_rows: Array = []        # [SkillIcon, Label key, RichTextLabel text]
var passive_label: RichTextLabel
var _class_key: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.panel(Color(0.03, 0.04, 0.07, 0.93), HudStyle.C_BORDER, 14, 2, 18.0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	add_theme_stylebox_override("panel", sb)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	title = HudStyle.make_label("", 26, HudStyle.C_GOLD, true, 5)
	root.add_child(title)
	info = HudStyle.make_label("", 14, HudStyle.C_TEXT_DIM, false, 3)
	root.add_child(info)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cols)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(grid)
	for i in 8:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size = Vector2(430, 0)
		var ic := SkillIcon.new()
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cell.add_child(ic)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.add_theme_font_override("normal_font", HudStyle.font())
		rt.add_theme_font_override("bold_font", HudStyle.font(true))
		rt.add_theme_font_size_override("normal_font_size", 13)
		rt.add_theme_font_size_override("bold_font_size", 16)
		cell.add_child(rt)
		grid.add_child(cell)
		skill_rows.append([ic, rt])
	# controls column
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.custom_minimum_size = Vector2(300, 0)
	cols.add_child(cv)
	cv.add_child(HudStyle.make_label("操作 Controls", 18, HudStyle.C_GOLD, true))
	for c: Array in CONTROLS:
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := HudStyle.make_label(str(c[0]), 14, Color(1, 0.92, 0.7), true, 3)
		k.custom_minimum_size = Vector2(96, 0)
		hb.add_child(k)
		hb.add_child(HudStyle.make_label(str(c[1]), 14, HudStyle.C_TEXT, false, 3))
		cv.add_child(hb)
	passive_label = RichTextLabel.new()
	passive_label.bbcode_enabled = true
	passive_label.fit_content = true
	passive_label.scroll_active = false
	passive_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	passive_label.add_theme_font_override("normal_font", HudStyle.font())
	passive_label.add_theme_font_override("bold_font", HudStyle.font(true))
	passive_label.add_theme_font_size_override("normal_font_size", 13)
	root.add_child(passive_label)
	var hint := HudStyle.make_label("按 F1 关闭  Press F1 to close", 13, HudStyle.C_TEXT_DIM, false, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)


func refresh(f: Fighter) -> void:
	var key := "none"
	if f != null and is_instance_valid(f):
		key = "%d:%s" % [f.uid, f.class_id]
	if key == _class_key:
		return
	_class_key = key
	if f == null or not is_instance_valid(f):
		title.text = "帮助 Help"
		info.text = ""
		for row: Array in skill_rows:
			(row[0] as Control).visible = false
			(row[1] as RichTextLabel).text = ""
		passive_label.text = ""
		return
	var kit := f.kit
	title.text = "%s 技能一览  Skills" % HudStyle.class_name_of(f)
	if kit != null:
		var w := ("%s %s" % [kit.weapon_name_cn, kit.weapon_name_en]).strip_edges()
		info.text = "%s   ·   %s%s" % [HudStyle.group_name_of(f), ("武器 Weapon: " + w) if w != "" else "",
			("   ·   " + kit.famous) if kit.famous != "" else ""]
	else:
		info.text = HudStyle.group_name_of(f)
	var tint := kit.tint if kit != null else HudStyle.class_color(f)
	for i in 8:
		var row: Array = skill_rows[i]
		var ic: SkillIcon = row[0]
		var rt: RichTextLabel = row[1]
		var s := f.get_skill(i)
		ic.skill = s
		ic.tint = tint
		ic.visible = true
		ic.queue_redraw()
		if s == null:
			rt.text = "[color=#808080]%s  -[/color]" % HudStyle.KEY_LABELS[i]
			continue
		var t := "[b][color=#ffe6a8][%s][/color]  [color=#%s]%s[/color] [color=#d0d4de]%s[/color][/b]" % [
			(HudStyle.KEY_LABELS_CN[i] + " " + HudStyle.KEY_LABELS[i]) if HudStyle.KEY_LABELS_CN[i] != HudStyle.KEY_LABELS[i] else HudStyle.KEY_LABELS[i],
			HudStyle.hex(HudStyle.C_GOLD), s.name_cn, s.name_en]
		if s.is_ultimate():
			t += " [color=#ffb040]大招 ULT[/color]"
		t += "\n[color=#8fd0ff]冷却 CD %.0fs[/color]  [color=#7fa8ff]MP %d[/color]" % [s.cooldown, int(s.mp_cost)]
		if s.charges > 1:
			t += "  [color=#ffd060]充能 x%d[/color]" % s.charges
		if s.tags.size() > 0:
			t += "  [color=#808898]" + " · ".join(HudSkillSlot.tag_names(s.tags).slice(0, 2)) + "[/color]"
		if s.desc != "":
			t += "\n" + s.desc
		rt.text = t
	var p := ""
	if kit != null and kit.passives.size() > 0:
		p = "[b][color=#ffd060]被动 Passives[/color][/b]  "
		var parts: PackedStringArray = []
		for pd: Dictionary in kit.passives:
			parts.append("[b]%s %s[/b] — %s" % [pd.get("name_cn", ""), pd.get("name_en", ""), pd.get("desc", "")])
		p += "    ".join(parts)
	passive_label.text = p

