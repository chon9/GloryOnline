class_name LdHud
extends RefCounted
## HUD mock in the new UI language (bible section 6): navy glass + gold filigree + crystal gems, holo target
## frame, glossy HP/MP bars, 8-slot skill bar with the new Battle Mage icons (clock-sweep cooldowns, pressed /
## no-MP / ultimate-ready states, keybinds), status icons with polarity frames, minimap, combo counter,
## world-anchored damage numbers and a brush-calligraphy skill callout.
## Layout is authored for the project's 1600x900 virtual canvas (stretch mode canvas_items).

const ICONS := "res://lookdev/assets/icons/out/"
const F_SANS := "res://lookdev/assets/fonts/notosanssc/NotoSansSC[wght].ttf"
const F_BRUSH := "res://lookdev/assets/fonts/mashanzheng/MaShanZheng-Regular.ttf"
const F_NUM := "res://lookdev/assets/fonts/teko/Teko[wght].ttf"
const F_CRIT := "res://lookdev/assets/fonts/russoone/RussoOne-Regular.ttf"
const F_TECH := "res://lookdev/assets/fonts/orbitron/Orbitron[wght].ttf"
const MASK := "shader_type canvas_item;\nvoid fragment() { vec2 d = UV - 0.5; float r = length(d); COLOR = texture(TEXTURE, UV); COLOR.a *= smoothstep(0.5, 0.48, r); }"

const SKILLS := ["lance_1", "sky_strike", "dragon_tooth", "falling_flower_palm", "circle_swing", "furious_dragon", "dragon_breaks_ranks", "rising_dragon"]
const KEYS := ["LMB", "1", "2", "3", "4", "Q", "E", "R"]


static func font(path: String, weight := 0) -> Font:
	var f: Font = load(path)
	if weight > 0:
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		return v
	return f


static func label(parent: Control, text: String, f: Font, size: int, col: Color, pos: Vector2, outline := 0, outline_col := Color(0.02, 0.03, 0.08)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func widget(parent: Control, kind: String, rect: Rect2, d := {}) -> LdHudWidget:
	var w := LdHudWidget.new(kind, d)
	w.position = rect.position
	w.size = rect.size
	parent.add_child(w)
	return w


static func tex(id: String) -> Texture2D:
	var p := ICONS + id + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	return ImageTexture.create_from_image(img) if img else null


## Cooldown copy of an icon: 45% value, fully desaturated (drawn inside the radial wipe).
static func tex_cd(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(0.45, 1.0, 0.0)
	return ImageTexture.create_from_image(img)


static func build(root: Node) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "HUD"
	root.add_child(cl)
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ui)
	var sans := font(F_SANS, 500)
	var sans_b := font(F_SANS, 800)
	var num := font(F_NUM, 500)
	var num_b := font(F_NUM, 650)
	var vw := 1600.0
	var vh := 900.0

	# ---------------------------------------------------------------- player frame (top-left)
	widget(ui, "panel", Rect2(18, 16, 430, 116))
	var port := SubViewportContainer.new()
	port.position = Vector2(26, 22)
	port.size = Vector2(104, 104)
	port.stretch = true
	var pm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MASK
	pm.shader = sh
	port.material = pm
	ui.add_child(port)
	var sv := SubViewport.new()
	sv.size = Vector2i(208, 208)
	sv.transparent_bg = false
	port.add_child(sv)
	var pc := Camera3D.new()
	pc.name = "PortraitCam"
	pc.fov = 24.0
	sv.add_child(pc)
	cl.set_meta("portrait_cam", pc)
	widget(ui, "portrait_ring", Rect2(24, 20, 108, 108))
	label(ui, "一叶之秋", sans_b, 22, LdHudWidget.TEXT, Vector2(146, 20), 4)
	label(ui, "战斗法师  ·  Lv.75", sans, 13, LdHudWidget.DIM, Vector2(256, 28), 3)
	widget(ui, "bar", Rect2(146, 56, 286, 20), {"value": 0.78, "trail": 0.88})
	label(ui, "5,928 / 7,600", num, 20, LdHudWidget.TEXT, Vector2(330, 52), 4)
	widget(ui, "bar", Rect2(146, 80, 250, 12), {"value": 0.64, "trail": 0.64, "color": LdHudWidget.MP, "trail_color": LdHudWidget.MP})
	# buffs (above the debuffs row): stack counts + duration sweep, final-3s blink drawn as dimmer frame
	var buffs := [["status_atk_up", "3", 0.7], ["status_super_armor", "", 0.35], ["status_haste", "", 0.85]]
	for i in buffs.size():
		var b: Array = buffs[i]
		widget(ui, "status", Rect2(146 + i * 34, 98, 30, 30), {"icon": tex(b[0]), "dur": b[2], "stack": b[1], "font": num_b})
	widget(ui, "status", Rect2(258, 98, 30, 30), {"icon": tex("status_burn"), "dur": 0.4})
	# chaser orbs (Battle Mage passive 炫纹)
	var orb_cols := [Color("#F2E6CF"), Color("#7FE8FF"), Color("#FF8A1F"), Color("#FFE45A"), Color("#8A4CFF")]
	for i in orb_cols.size():
		var o := widget(ui, "status", Rect2(306 + i * 22, 104, 18, 18), {})
		o.draw.connect(func() -> void:
			o.draw_circle(Vector2(9, 9), 8.0, Color(orb_cols[i], 0.35))
			o.draw_circle(Vector2(9, 9), 5.0, orb_cols[i])
			o.draw_circle(Vector2(7, 7), 2.0, Color.WHITE))

	# ---------------------------------------------------------------- teammate frame (left)
	widget(ui, "panel", Rect2(18, 148, 250, 58), {"gems": false})
	label(ui, "王不留行", sans_b, 16, LdHudWidget.TEXT, Vector2(32, 154), 3)
	label(ui, "魔道学者", sans, 11, LdHudWidget.DIM, Vector2(110, 158), 3)
	widget(ui, "bar", Rect2(32, 180, 180, 12), {"value": 0.92, "trail": 0.95})
	widget(ui, "status", Rect2(222, 172, 26, 26), {"icon": tex("status_slow"), "dur": 0.5})

	# ---------------------------------------------------------------- target frame (top centre, holo)
	widget(ui, "holo", Rect2(vw * 0.5 - 230, 16, 460, 84))
	widget(ui, "plate", Rect2(vw * 0.5 - 214, 24, 150, 26), {"color": Color("#FF3B4A")})
	label(ui, "沐雨橙风", sans_b, 18, LdHudWidget.TEXT, Vector2(vw * 0.5 - 192, 22), 3)
	label(ui, "枪炮师  ·  嘉世", sans, 12, Color("#9FE6FF"), Vector2(vw * 0.5 - 54, 28), 3)
	label(ui, "目标", sans, 11, Color(LdHudWidget.CYAN, 0.8), Vector2(vw * 0.5 + 172, 26), 0)
	widget(ui, "bar", Rect2(vw * 0.5 - 214, 56, 400, 18), {"value": 0.41, "trail": 0.57, "frame": Color(LdHudWidget.CYAN, 0.9)})
	label(ui, "41%", num_b, 22, LdHudWidget.TEXT, Vector2(vw * 0.5 + 192, 50), 4)
	for i in 3:
		var ids := ["status_stun", "status_def_down", "status_burn"]
		widget(ui, "status", Rect2(vw * 0.5 - 214 + i * 34, 76, 30, 30), {"icon": tex(ids[i]), "dur": [0.3, 0.6, 0.8][i]})

	# ---------------------------------------------------------------- minimap (top-right)
	widget(ui, "minimap", Rect2(vw - 178, 14, 160, 160), {"dots": [[Vector2(0.08, -0.12), Color("#FF3B4A")], [Vector2(-0.2, -0.05), Color("#2F7BFF")]]})
	label(ui, "冰霜森林 · 竞技场", sans, 13, LdHudWidget.TEXT, Vector2(vw - 170, 180), 3)
	label(ui, "02:47", num_b, 26, Color("#FFE9A8"), Vector2(vw - 70, 172), 4)
	# kill feed (broadcast plates)
	widget(ui, "plate", Rect2(vw - 330, 210, 312, 26), {"color": Color("#2F7BFF")})
	label(ui, "一叶之秋  击破  沐雨橙风 · 护盾", sans, 13, LdHudWidget.TEXT, Vector2(vw - 308, 213), 3)

	# ---------------------------------------------------------------- skill bar (bottom centre)
	var slot := 62.0
	var gap := 8.0
	var ult := 78.0
	var bar_w := 7 * slot + 6 * gap + gap * 2.5 + ult
	var x0 := vw * 0.5 - bar_w * 0.5
	var y0 := vh - 104.0
	widget(ui, "panel", Rect2(x0 - 22, y0 - 16, bar_w + 44, ult + 30))
	var ult_x := x0 + 7 * (slot + gap) + gap * 2.5
	widget(ui, "bar", Rect2(x0 + 20, y0 - 34, ult_x - x0 - 40, 10), {"value": 0.64, "trail": 0.64, "color": LdHudWidget.MP, "trail_color": LdHudWidget.MP})
	var cd_font := font(F_NUM, 700)
	# LMB ready, 1 pressed, 2 on cooldown (6.4 s left), 3 just came off cooldown (gold flash), 4 cooldown 12 s,
	# Q no MP, E cooldown 1.1 s, R ultimate ready
	var states := [{}, {"pressed": true}, {"cd": 0.55, "t": 6.4}, {"flash": true}, {"cd": 0.82, "t": 12.0}, {"no_mp": true}, {"cd": 0.18, "t": 1.1}, {"ult": true}]
	for i in 8:
		var is_ult := i == 7
		var s := ult if is_ult else slot
		var x := x0 + i * (slot + gap) + (gap * 2.5 if is_ult else 0.0)
		var y := y0 + (ult - s) * 0.5 + (-4.0 if is_ult else 4.0)
		var d: Dictionary = (states[i] as Dictionary).duplicate()
		d["icon"] = tex("battle_mage_" + SKILLS[i])
		d["ult"] = is_ult
		d["key"] = KEYS[i]
		d["key_font"] = sans_b
		d["cd_font"] = cd_font
		if d.has("cd"):
			d["icon_cd"] = tex_cd(d["icon"])
		widget(ui, "slot", Rect2(x, y, s, s), d)
	# 觉醒 as a gold ribbon above the ultimate frame, clear of its crystal
	widget(ui, "ribbon", Rect2(ult_x + ult * 0.5 - 34, y0 - 40, 68, 20))
	label(ui, "觉醒", sans_b, 13, Color("#2A1606"), Vector2(ult_x + ult * 0.5 - 14, y0 - 41), 0).add_theme_constant_override("shadow_offset_y", 0)

	# ---------------------------------------------------------------- combo counter + skill callout
	var combo := Control.new()
	combo.name = "Combo"
	combo.position = Vector2(vw - 300, 330)
	combo.rotation = deg_to_rad(-4)
	ui.add_child(combo)
	label(combo, "12", font(F_CRIT), 76, Color("#FFC43A"), Vector2(0, 0), 8, Color(0.2, 0.08, 0.02))
	label(combo, "连击", sans_b, 34, Color("#FFE9A8"), Vector2(104, 34), 6, Color(0.2, 0.08, 0.02))
	var ul := widget(combo, "callout_band", Rect2(0, 92, 230, 10), {"color": Color("#FFC43A")})
	ul.modulate = Color(1, 1, 1, 0.9)
	var call := Control.new()
	call.position = Vector2(120, 236)
	call.rotation = deg_to_rad(-7)
	call.name = "Callout"
	ui.add_child(call)
	# callout band takes the skill's tone from the class key (天击 = gold), like its icon
	widget(call, "callout_band", Rect2(-30, 22, 520, 96), {"color": Color("#E0A83A")})
	label(call, "天击", font(F_BRUSH), 120, Color.WHITE, Vector2(20, -22), 12, Color(0.22, 0.1, 0.02))
	label(call, "战斗法师 · 二段挑空", sans, 16, Color("#FFE9A8"), Vector2(286, 58), 3)

	# damage numbers are world-anchored: see place_numbers()
	var dmg := Control.new()
	dmg.name = "Damage"
	dmg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dmg)
	cl.set_meta("dmg", dmg)
	return cl


## Damage numbers (bible 5.5): white normal, gold larger crit with 暴击 tag, green heal, red taken.
static func place_numbers(hud: CanvasLayer, cam: Camera3D, pts: Dictionary) -> void:
	var dmg: Control = hud.get_meta("dmg")
	for c in dmg.get_children():
		c.queue_free()
	var vp := hud.get_viewport().get_visible_rect().size
	var k := 1600.0 / vp.x
	var crit := font(F_CRIT)
	var num := font(F_NUM, 600)
	var sans_b := font(F_SANS, 800)
	if pts.has("blast"):
		var p := cam.unproject_position(pts["blast"] + Vector3(0, 1.0, 0)) * k
		label(dmg, "-3,862", num, 42, Color("#FF4A4A"), p + Vector2(-250, 40), 6, Color(0.15, 0.0, 0.02))
	if pts.has("slash"):
		var p2 := cam.unproject_position(pts["slash"] + Vector3(0, 1.4, 0)) * k
		var c := Control.new()
		c.position = p2 + Vector2(-60, -60)
		c.rotation = deg_to_rad(-5)
		dmg.add_child(c)
		label(c, "暴击", sans_b, 22, Color("#FFE9A8"), Vector2(0, 6), 5, Color(0.25, 0.1, 0.0))
		label(c, "12,846", crit, 62, Color("#FFC43A"), Vector2(52, -10), 8, Color(0.25, 0.1, 0.0))
		label(dmg, "2,104", num, 40, Color.WHITE, p2 + Vector2(120, 30), 5)
		label(dmg, "1,877", num, 34, Color(1, 1, 1, 0.8), p2 + Vector2(96, 74), 5)
	if pts.has("glyph"):
		var p3 := cam.unproject_position(pts["glyph"]) * k
		label(dmg, "+1,520", num, 40, Color("#7CF0A0"), p3 + Vector2(-40, -30), 5, Color(0.0, 0.15, 0.05))


static func aim_portrait(hud: CanvasLayer, who: LdCharacter) -> void:
	var pc: Camera3D = hud.get_meta("portrait_cam")
	var sk := who.skeleton
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var fwd := who.global_basis.z.normalized()
	pc.global_position = head + fwd * 1.15 + Vector3(0, 0.06, 0) + who.global_basis.x * 0.3
	pc.look_at(head + Vector3(0, 0.04, 0))


## Icon design board for the HUD screenshot: every generated icon at native size with its name and frame type.
static func show_sheet(hud: CanvasLayer) -> void:
	var ui: Control = hud.get_node("UI")
	(ui.get_node("Callout") as Control).visible = false
	(ui.get_node("Combo") as Control).visible = false
	var sans := font(F_SANS, 500)
	var sans_b := font(F_SANS, 800)
	var r := Rect2(560, 238, 1010, 470)
	widget(ui, "panel", r)
	label(ui, "技能图标 · 战斗法师", sans_b, 22, LdHudWidget.TEXT, r.position + Vector2(26, 16), 3)
	label(ui, "八式 · 状态", sans, 13, Color(LdHudWidget.CYAN, 0.85), r.position + Vector2(300, 24), 0)
	var names := ["突刺", "天击", "龙牙", "落花掌", "圆舞棍", "怒龙穿心", "豪龙破军", "伏龙翔天"]
	for i in 8:
		var x := r.position.x + 26 + (i % 4) * 124
		var y := r.position.y + 58 + (i / 4) * 150
		widget(ui, "slot", Rect2(x, y, 108, 108), {"icon": tex("battle_mage_" + SKILLS[i]), "ult": i == 7})
		label(ui, names[i], sans, 14, LdHudWidget.TEXT, Vector2(x + 2, y + 112), 3)
	var st := [["status_atk_up", "攻击提升", "增益"], ["status_haste", "加速", "增益"], ["status_super_armor", "霸体", "增益"], ["status_burn", "灼烧", "减益"],
		["status_slow", "减速", "减益"], ["status_def_down", "破防", "减益"], ["status_stun", "眩晕", "控制"]]
	for i in st.size():
		var x := r.position.x + 540 + (i % 4) * 112
		var y := r.position.y + 70 + (i / 4) * 128
		widget(ui, "status", Rect2(x + 14, y, 64, 64), {"icon": tex(st[i][0])})
		label(ui, st[i][1], sans, 14, LdHudWidget.TEXT, Vector2(x + 14, y + 70), 3)
		label(ui, st[i][2], sans, 11, LdHudWidget.DIM, Vector2(x + 14, y + 90), 0)
	label(ui, "银框 普通技能 · 金框 觉醒 · 圆 增益 · 盾 减益 · 六角 控制", sans, 13, LdHudWidget.DIM, r.position + Vector2(540, 334), 3)
	# 32 px colour + greyscale readability strips (bible 7.3 step 5)
	label(ui, "小图", sans, 12, LdHudWidget.DIM, r.position + Vector2(540, 372), 0)
	label(ui, "灰度", sans, 12, LdHudWidget.DIM, r.position + Vector2(540, 416), 0)
	var grey := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = "shader_type canvas_item;
void fragment() { vec4 c = texture(TEXTURE, UV); float l = dot(c.rgb, vec3(0.299, 0.587, 0.114)); COLOR = vec4(vec3(l), c.a); }"
	grey.shader = gs
	for i in 8:
		widget(ui, "slot", Rect2(r.position.x + 590 + i * 40, r.position.y + 366, 32, 32), {"icon": tex("battle_mage_" + SKILLS[i])})
		var g := widget(ui, "slot", Rect2(r.position.x + 590 + i * 40, r.position.y + 410, 32, 32), {"icon": tex("battle_mage_" + SKILLS[i])})
		g.material = grey
