extends Control
## One skill-bar slot: procedural icon, key label, cooldown sweep + seconds, charges, MP greying,
## cast highlight, ready flash and a rich hover tooltip (CN/EN name, desc, cooldown, MP cost).

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

var slot: int = 0
var skill: SkillDef = null
var tint: Color = Color(0.6, 0.7, 0.9)
var key_label: String = ""
var cd: float = 0.0
var cd_total: float = 1.0
var charges: int = 1
var max_charges: int = 1
var no_mp: bool = false
var locked: bool = false        # silenced / disabled / dead
var casting: bool = false

var _flash: float = 0.0
var _pulse: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(58, 58)
	tooltip_text = " "
	set_process(false)


func set_skill(s: SkillDef, kit_tint: Color, key: String) -> void:
	skill = s
	tint = kit_tint
	key_label = key
	max_charges = s.charges if s != null else 1
	cd_total = maxf(s.cooldown, 0.01) if s != null else 1.0
	queue_redraw()


func update_state(p_cd: float, p_charges: int, p_no_mp: bool, p_locked: bool, p_casting: bool) -> void:
	var was_cd := cd > 0.05 or (max_charges > 1 and charges < max_charges)
	var changed := not is_equal_approx(p_cd, cd) or p_charges != charges or p_no_mp != no_mp \
		or p_locked != locked or p_casting != casting
	if p_cd <= 0.0 and cd > 0.0 and (max_charges <= 1 or p_charges > charges):
		_flash = 1.0
	elif max_charges > 1 and p_charges > charges and was_cd:
		_flash = 1.0
	cd = maxf(p_cd, 0.0)
	charges = p_charges
	no_mp = p_no_mp
	locked = p_locked
	casting = p_casting
	if changed or _flash > 0.0:
		queue_redraw()
	set_process(cd > 0.0 or _flash > 0.0 or casting)


func _process(delta: float) -> void:
	if cd > 0.0:
		cd = maxf(0.0, cd - delta)  # local interpolation between 0.1 s replicated steps
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	_pulse += delta
	queue_redraw()
	if cd <= 0.0 and _flash <= 0.0 and not casting:
		set_process(false)


func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	# frame shadow
	HudIcons.gradient_rect(self, r.grow(2), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.75), 9.0)
	HudIcons.draw_skill_icon(self, r, skill, tint)
	if skill == null:
		return
	var center := r.get_center()
	var full_cd := cd > 0.0 and charges <= 0
	if locked:
		HudIcons.gradient_rect(self, r, Color(0.1, 0.1, 0.12, 0.7), Color(0.05, 0.05, 0.06, 0.8), 7.0)
	elif no_mp and not full_cd:
		HudIcons.gradient_rect(self, r, Color(0.05, 0.12, 0.35, 0.55), Color(0.02, 0.05, 0.2, 0.7), 7.0)
	if cd > 0.0:
		var frac := clampf(cd / cd_total, 0.0, 1.0)
		if full_cd:
			HudIcons.gradient_rect(self, r, Color(0, 0, 0, 0.30), Color(0, 0, 0, 0.42), 7.0)
			_draw_sweep(r, frac, Color(0, 0, 0, 0.5))
		else:
			# a charge is still available: thin progress ring only
			draw_arc(center, r.size.x * 0.5 - 2.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - frac), 32,
				Color(1, 0.85, 0.4, 0.85), 2.5, true)
		if full_cd:
			var t := ("%.1f" % cd) if cd < 10.0 else str(int(ceil(cd)))
			HudIcons.glyph(self, center + Vector2(0, 2), t, int(r.size.y * 0.4), Color(1, 0.97, 0.88), 6, Color(0, 0, 0, 1.0), true)
	if max_charges > 1:
		var b := Rect2(r.position + Vector2(r.size.x - 20, r.size.y - 18), Vector2(18, 16))
		HudIcons.gradient_rect(self, b, Color(0.15, 0.15, 0.2, 0.95), Color(0.05, 0.05, 0.08, 0.95), 4.0)
		HudIcons.glyph(self, b.get_center(), str(charges), 12, Color(1, 0.9, 0.5) if charges > 0 else Color(0.7, 0.7, 0.7), 2)
	if no_mp and not locked:
		var mt := "MP %d" % int(skill.mp_cost)
		HudIcons.glyph(self, Vector2(center.x, r.end.y - 9), mt, 11, Color(0.55, 0.75, 1.0), 3)
	# key label
	var kf := HudStyle.font(true)
	var ksz := 12
	var kw := kf.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ksz).x + 8.0
	var kr := Rect2(r.position + Vector2(-1, -1), Vector2(kw, 16))
	HudIcons.gradient_rect(self, kr, Color(0.12, 0.13, 0.18, 0.95), Color(0.04, 0.04, 0.06, 0.95), 4.0)
	HudIcons.outline_rect(self, kr, Color(1, 1, 1, 0.25), 1.0, 4.0)
	HudIcons.glyph(self, kr.get_center(), key_label, ksz, Color(1, 0.95, 0.8), 0)
	if casting:
		var a := 0.6 + 0.4 * sin(_pulse * 10.0)
		HudIcons.outline_rect(self, r.grow(1), Color(1, 0.85, 0.3, a), 3.0, 8.0)
		HudIcons.outline_rect(self, r.grow(3), Color(1, 0.7, 0.2, a * 0.4), 2.0, 9.0)
	if _flash > 0.0:
		HudIcons.gradient_rect(self, r, Color(1, 1, 1, 0.55 * _flash), Color(1, 0.95, 0.7, 0.25 * _flash), 7.0)
		HudIcons.outline_rect(self, r.grow(2.0 + (1.0 - _flash) * 4.0), Color(1, 0.95, 0.6, _flash), 2.0, 9.0)


func _draw_sweep(r: Rect2, frac: float, c: Color) -> void:
	# Pie covering the remaining fraction, clockwise from 12 o'clock, clipped to the tile square.
	var center := r.get_center()
	var rad := r.size.length() * 0.5 + 2.0
	var pts := PackedVector2Array([center])
	var start := -PI * 0.5 + TAU * (1.0 - frac)
	var end := -PI * 0.5 + TAU
	var steps := maxi(2, int(32 * frac))
	for i in steps + 1:
		var a := lerpf(start, end, float(i) / float(steps))
		var p := center + Vector2(cos(a), sin(a)) * rad
		p.x = clampf(p.x, r.position.x, r.end.x)
		p.y = clampf(p.y, r.position.y, r.end.y)
		pts.append(p)
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)
	var edge := center + Vector2(cos(start), sin(start)) * rad
	edge.x = clampf(edge.x, r.position.x, r.end.x)
	edge.y = clampf(edge.y, r.position.y, r.end.y)
	draw_line(center, edge, Color(1, 0.9, 0.5, 0.8), 1.5, true)


func _make_custom_tooltip(_for_text: String) -> Object:
	return make_tooltip_panel(skill, key_label)


static func make_tooltip_panel(s: SkillDef, key: String) -> Control:
	if s == null:
		return null
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", HudStyle.panel(Color(0.04, 0.05, 0.08, 0.96), HudStyle.C_BORDER, 8, 1, 10.0))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(320, 0)
	rt.add_theme_font_override("normal_font", HudStyle.font())
	rt.add_theme_font_override("bold_font", HudStyle.font(true))
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 17)
	rt.text = skill_bbcode(s, key)
	pc.add_child(rt)
	return pc


static func skill_bbcode(s: SkillDef, key: String) -> String:
	var t := "[b][color=#%s]%s[/color][/b]  [color=#c8ccd6]%s[/color]\n" % [HudStyle.hex(HudStyle.C_GOLD), s.name_cn, s.name_en]
	t += "[color=#9aa3b5]按键 Key: %s" % key
	if s.is_ultimate():
		t += "   [color=#ffd060]大招 Ultimate[/color]"
	t += "[/color]\n"
	var cd_txt := "冷却 Cooldown %.1fs" % s.cooldown if s.cooldown > 0.0 else "无冷却 No cooldown"
	var mp_txt := "法力 MP %d" % int(s.mp_cost) if s.mp_cost > 0.0 else "无消耗 No cost"
	t += "[color=#8fd0ff]%s[/color]   [color=#7fa8ff]%s[/color]" % [cd_txt, mp_txt]
	if s.charges > 1:
		t += "   [color=#ffd060]充能 Charges %d[/color]" % s.charges
	if s.cast_time >= 0.6:
		t += "\n[color=#c0c0c0]施法 Cast %.1fs[/color]" % s.cast_time
	if s.desc != "":
		t += "\n\n" + s.desc
	if s.tags.size() > 0:
		t += "\n[color=#808898]" + " · ".join(tag_names(s.tags)) + "[/color]"
	return t


const TAG_NAMES: Dictionary = {
	"launcher": "浮空 Launcher", "combo": "连招 Combo", "gap_closer": "突进 Gap closer", "escape": "位移 Escape",
	"cc": "控制 CC", "aoe": "范围 AoE", "ranged": "远程 Ranged", "melee": "近战 Melee", "heal": "治疗 Heal",
	"buff_self": "自身增益 Self buff", "buff_ally": "队友增益 Ally buff", "debuff": "减益 Debuff", "grab": "抓取 Grab",
	"finisher": "终结 Finisher", "summon": "召唤 Summon", "zone": "区域 Zone", "defensive": "防御 Defensive",
	"ultimate": "大招 Ultimate",
}


static func tag_names(tags: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for t: String in tags:
		out.append(str(TAG_NAMES.get(t, t)))
	return out
