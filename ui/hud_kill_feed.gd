extends VBoxContainer
## Kill feed (top-right): "A 击败 B" with names in class colors; newest on top, entries fade after LIFE s.
## Entries are pooled (MAX entries created once).

const HudStyle := preload("res://ui/hud_style.gd")

const MAX: int = 6
const LIFE: float = 7.0

var _panels: Array = []          # Array[PanelContainer]
var _labels: Array = []          # Array[RichTextLabel]
var _life: PackedFloat32Array = PackedFloat32Array()
var _texts: PackedStringArray = PackedStringArray()
var _hl: Array[bool] = []
var _boxes: Array = []           # Array[GloryStyleBox] (plate accent = killer team / gold for the viewer)
var _accent: Array[Color] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in MAX:
		var pc := PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.size_flags_horizontal = Control.SIZE_SHRINK_END
		var sb := HudStyle.glory("plate", 0.0, HudStyle.C_ALLY)
		sb.content_margin_left = 22.0
		sb.content_margin_right = 20.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 3.0
		pc.add_theme_stylebox_override("panel", sb)
		_boxes.append(sb)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.add_theme_font_override("normal_font", HudStyle.font())
		rt.add_theme_font_override("bold_font", HudStyle.font(true))
		rt.add_theme_font_size_override("normal_font_size", 14)
		rt.add_theme_font_size_override("bold_font_size", 15)
		rt.add_theme_font_override("normal_font", HudStyle.sans(500))
		rt.add_theme_constant_override("outline_size", 3)
		rt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		pc.add_child(rt)
		pc.visible = false
		add_child(pc)
		_panels.append(pc)
		_labels.append(rt)
		_life.append(0.0)
		_texts.append("")
		_hl.append(false)
		_accent.append(HudStyle.C_ALLY)
	set_process(false)


static func name_bb(f: Fighter, fallback: String) -> String:
	if f == null or not is_instance_valid(f):
		return "[b]%s[/b]" % fallback
	var c := HudStyle.class_color(f)
	var cls := HudStyle.class_cn(f)
	var s := "[b][color=#%s]%s[/color][/b]" % [HudStyle.hex(c), f.display_name.replace("[", "(")]
	if cls != "" and f.kind != "boss" and not f.display_name.contains(cls):
		s += " [color=#8a92a6][font_size=12]%s[/font_size][/color]" % cls
	return s


## Adds "killer 击败 victim" (killer null -> "victim 阵亡").
func add_kill(killer: Fighter, victim: Fighter, viewer: Fighter = null) -> void:
	var t := ""
	if killer != null and is_instance_valid(killer) and killer != victim:
		t = "%s  [color=#ffd36a]击败[/color] [color=#9aa6b8][font_size=11]Defeated[/font_size][/color]  %s" % [
			name_bb(killer, "?"), name_bb(victim, "?")]
	else:
		t = "%s  [color=#ff7060]阵亡[/color] [color=#9aa3b5][font_size=12]Fell[/font_size][/color]" % name_bb(victim, "?")
	var involved := viewer != null and (viewer == killer or viewer == victim)
	var src: Fighter = killer if killer != null and is_instance_valid(killer) else victim
	var acc := HudStyle.C_ALLY
	if src != null and is_instance_valid(src):
		if src.kind == "mob" or src.kind == "boss":
			acc = HudStyle.C_BOSS
		elif viewer != null and is_instance_valid(viewer):
			acc = HudStyle.C_ALLY if src.team == viewer.team else HudStyle.C_ENEMY
		else:
			acc = HudStyle.team_color(src.team)
	add_entry(t, involved, acc)


func add_entry(bbcode: String, highlight: bool = false, accent: Color = HudStyle.C_ALLY) -> void:
	# shift down: newest goes on top (index 0)
	for i in range(MAX - 1, 0, -1):
		_texts[i] = _texts[i - 1]
		_life[i] = _life[i - 1]
		_hl[i] = _hl[i - 1]
		_accent[i] = _accent[i - 1]
	_texts[0] = bbcode
	_life[0] = LIFE
	_hl[0] = highlight
	_accent[0] = accent
	for i in MAX:
		_apply(i)
	set_process(true)


func entry_count() -> int:
	var n := 0
	for i in MAX:
		if _life[i] > 0.0:
			n += 1
	return n


func entry_text(i: int) -> String:
	return _texts[i] if i >= 0 and i < MAX and _life[i] > 0.0 else ""


func _apply(i: int) -> void:
	var pc: PanelContainer = _panels[i]
	var rt: RichTextLabel = _labels[i]
	pc.visible = _life[i] > 0.0
	if pc.visible:
		if rt.text != _texts[i]:
			rt.text = _texts[i]
		var sb: StyleBox = _boxes[i]
		sb.set("accent", HudStyle.UI_GOLD_HI if _hl[i] else _accent[i])
		pc.queue_redraw()
		pc.modulate.a = clampf(_life[i] / 0.6, 0.0, 1.0)


func _process(delta: float) -> void:
	var any := false
	for i in MAX:
		if _life[i] > 0.0:
			_life[i] = maxf(0.0, _life[i] - delta)
			(_panels[i] as PanelContainer).modulate.a = clampf(_life[i] / 0.6, 0.0, 1.0)
			if _life[i] <= 0.0:
				(_panels[i] as PanelContainer).visible = false
			else:
				any = true
	if not any:
		set_process(false)
