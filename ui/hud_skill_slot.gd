extends Control
## One skill-bar slot (look-dev slot states): painted icon (procedural fallback), key label, cooldown sweep + seconds, charges, MP greying,
## cast highlight, ready flash and a rich hover tooltip (CN/EN name, desc, cooldown, MP cost).

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const GD := preload("res://ui/glory_draw.gd")

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
	set_process(cd > 0.0 or _flash > 0.0 or casting or (slot == 7 and skill != null))


func _process(delta: float) -> void:
	if cd > 0.0:
		cd = maxf(0.0, cd - delta)  # local interpolation between 0.1 s replicated steps
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	_pulse += delta
	queue_redraw()
	if cd <= 0.0 and _flash <= 0.0 and not casting and slot != 7:
		set_process(false)


func _draw() -> void:
	var ci := get_canvas_item()
	var ult := slot == 7
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var c := r.get_center()
	var ch := r.size.x * 0.07
	var face := GD.chamfer(r, ch)
	var is_ready := skill != null and cd <= 0.0 and not locked and not no_mp
	if ult and is_ready:
		# slow golden ready halo following the frame
		var pulse := 0.75 + 0.25 * sin(_pulse * 2.6)
		for k in 4:
			GD.polyline(ci, GD.chamfer(r.grow(1.5 + k * 1.6), ch + 1.5 + k * 1.6), Color(GD.GOLD, (0.34 - k * 0.075) * pulse), 1.8, true)
	if _flash > 0.0:
		for k in 6:
			GD.polyline(ci, GD.chamfer(r.grow(1.0 + k * 1.4), ch + 1.0 + k * 1.4), Color(GD.GOLD_HI, (0.55 - k * 0.09) * _flash), 2.0, true)
	GD.poly(ci, GD.chamfer(r.grow(2.0), ch + 2.0), Color(0, 0, 0, 0.6))
	var painted := HudStyle.skill_icon(skill)
	if painted != null:
		draw_texture_rect(painted, r, false)
	else:
		HudIcons.draw_skill_icon(self, r, skill, tint)
		# steel bevel (gold on the ultimate) around the procedural fallback
		GD.polyline(ci, face, GD.GOLD if ult else HudStyle.UI_STEEL, 2.0, true)
		GD.polyline(ci, GD.chamfer(r.grow(-2.5), ch), Color(0, 0, 0, 0.55), 1.0, true)
	if skill == null:
		GD.poly(ci, face, Color(0.02, 0.03, 0.06, 0.7))
		return
	var inner := r.grow(-r.size.x * 0.05)
	var box := GD.chamfer(inner, r.size.x * 0.04)
	var full_cd := cd > 0.0 and charges <= 0
	if locked:
		GD.poly(ci, face, Color(0.05, 0.05, 0.07, 0.62))
		# chain glyph: two linked rings
		GD.arc(ci, c + Vector2(-5, 0), 6.0, 0, TAU, Color(0.8, 0.82, 0.88, 0.9), 2.0, 16)
		GD.arc(ci, c + Vector2(5, 0), 6.0, 0, TAU, Color(0.8, 0.82, 0.88, 0.9), 2.0, 16)
	elif no_mp and not full_cd:
		# not enough MP: icon stays in colour (not a cooldown); blue inner border + crossed-out MP droplet
		GD.poly(ci, box, Color(0.0, 0.02, 0.08, 0.32))
		GD.polyline(ci, box, Color(HudStyle.C_MP, 0.95), 2.5, true)
		var dc := Vector2(r.end.x - r.size.x * 0.24, r.position.y + r.size.x * 0.26)
		var dr := r.size.x * 0.12
		var drop := PackedVector2Array([dc + Vector2(0, -dr * 1.5)])
		for k in 13:
			var a := lerpf(-PI * 0.15, PI * 1.15, k / 12.0)
			drop.append(dc + Vector2(cos(a), sin(a)) * dr)
		GD.poly(ci, drop, Color(0.02, 0.04, 0.1, 0.95))
		var inner_drop := PackedVector2Array()
		for v in drop:
			inner_drop.append(dc + (v - dc) * 0.72)
		GD.poly(ci, inner_drop, HudStyle.C_MP)
		GD.line(ci, dc + Vector2(-dr, dr), dc + Vector2(dr, -dr * 1.2), Color(0.02, 0.03, 0.07), 4.0)
		GD.line(ci, dc + Vector2(-dr, dr), dc + Vector2(dr, -dr * 1.2), Color("#FF6A6A"), 2.0)
	if cd > 0.0:
		var frac := clampf(cd / cd_total, 0.0, 1.0)
		if full_cd:
			_draw_sweep(r, box, frac, painted)
			var f_cd := HudStyle.num(700)
			# whole seconds only; the last 3 s are a gold bar that empties along the slot bottom
			var txt := "%d" % ceili(cd)
			if cd <= 3.0:
				var fb := Rect2(inner.position + Vector2(3, inner.size.y - 8), Vector2(inner.size.x - 6, 4))
				GD.rect(ci, fb, Color(0.02, 0.03, 0.07, 0.9))
				GD.rect(ci, Rect2(fb.position, Vector2(fb.size.x * clampf(cd / 3.0, 0.0, 1.0), fb.size.y)), HudStyle.C_CRIT)
			var fs := int(r.size.y * 0.62)
			var sz := f_cd.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var base := Vector2(c.x - sz.x * 0.5, c.y + f_cd.get_ascent(fs) * 0.36)
			GD.text(ci, f_cd, base, txt, fs, HudStyle.C_TEXT, 4, Color(0.02, 0.03, 0.07, 0.95))
		else:
			# a charge is still available: thin gold recharge ring along the frame
			var pts := PackedVector2Array()
			var steps := 24
			for k in steps + 1:
				var a := -PI * 0.5 + TAU * (1.0 - frac) * k / float(steps)
				var p := c + Vector2(cos(a), sin(a)) * r.size.x
				pts.append(Vector2(clampf(p.x, r.position.x + 1, r.end.x - 1), clampf(p.y, r.position.y + 1, r.end.y - 1)))
			GD.polyline(ci, pts, Color(HudStyle.C_CRIT, 0.9), 2.5)
	if max_charges > 1:
		# stack count: big outlined digit, bottom-right corner
		var f := HudStyle.num(700)
		var fs2 := int(r.size.y * 0.42)
		var t := str(charges)
		var sz2 := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var base2 := Vector2(r.end.x - sz2.x - 2, r.end.y - 4)
		GD.text(ci, f, base2, t, fs2, Color("#FFF4D0") if charges > 0 else Color(0.7, 0.7, 0.72), 4, Color(0.02, 0.03, 0.07, 0.95))
	if casting:
		# pressed / casting: gold stroke following the slot shape, inner glow, 1.5 px press shadow
		var a2 := 0.75 + 0.25 * sin(_pulse * 10.0)
		for k in 5:
			GD.polyline(ci, GD.chamfer(r.grow(-1.0 - k * 2.0), ch), Color(GD.GOLD, (0.30 - k * 0.06) * a2), 2.0, true)
		GD.polyline(ci, PackedVector2Array([Vector2(r.position.x + 3, r.end.y - 6), r.position + Vector2(3, 6), Vector2(r.end.x - 6, r.position.y + 3)]),
			Color(0, 0, 0, 0.6), 1.5)
		GD.polyline(ci, GD.chamfer(r.grow(1.5), ch + 1.5), Color(GD.GOLD_HI, a2), 2.0, true)
		GD.polyline(ci, GD.chamfer(r.grow(3.0), ch + 3.0), Color(GD.GOLD, 0.5 * a2), 1.2, true)
	if _flash > 0.0:
		GD.poly(ci, face, Color(1, 0.95, 0.75, 0.35 * _flash))
	# keybind tab on the frame's bottom edge
	var kf := HudStyle.sans(800)
	var ks := 11
	var tw := kf.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x
	var tab := Rect2(Vector2(c.x - tw * 0.5 - 6, r.end.y - 7), Vector2(tw + 12, 14))
	var tp := GD.chamfer(tab, 4.0)
	GD.poly(ci, tp, Color(0.03, 0.06, 0.11, 0.95))
	GD.polyline(ci, tp, Color(GD.GOLD if ult else HudStyle.UI_STEEL, 0.9), 1.0, true)
	GD.text(ci, kf, Vector2(c.x - tw * 0.5, tab.position.y + 11), key_label, ks, HudStyle.C_TEXT)


## Clockwise radial wipe over the remaining fraction: a darkened, desaturated copy of the icon (painted icons) or a
## dark veil (procedural), clipped to the slot face, with a bright tick at the sweep edge.
func _draw_sweep(r: Rect2, box: PackedVector2Array, frac: float, painted: Texture2D) -> void:
	var ci := get_canvas_item()
	var c := r.get_center()
	var rad := r.size.x * 0.75
	var a0 := -PI * 0.5 + TAU * (1.0 - frac)
	var a1 := -PI * 0.5 + TAU
	var pts := PackedVector2Array([c])
	var steps := maxi(2, int(48 * frac))
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	var grey := HudStyle.icon_cd(painted)
	for pl in Geometry2D.intersect_polygons(pts, box):
		if pl.size() < 3:
			continue
		if grey != null:
			var uv := PackedVector2Array()
			for v in pl:
				uv.append((v - r.position) / r.size)
			draw_colored_polygon(pl, Color.WHITE, uv, grey)
		else:
			GD.poly(ci, pl, Color(0.01, 0.02, 0.05, 0.62))
	var dir := Vector2(cos(a0), sin(a0))
	for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([c, c + dir * rad]), box):
		if seg.size() < 2:
			continue
		GD.polyline(ci, seg, Color(1, 0.92, 0.7, 0.55), 1.0)
		GD.line(ci, seg[seg.size() - 1] - dir * 6.0, seg[seg.size() - 1], Color(1, 0.96, 0.85, 1.0), 2.5)


func _make_custom_tooltip(_for_text: String) -> Object:
	return make_tooltip_panel(skill, key_label)


static func make_tooltip_panel(s: SkillDef, key: String) -> Control:
	if s == null:
		return null
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", HudStyle.glory("plain", 10.0))
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
