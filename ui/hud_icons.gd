extends RefCounted
## HUD icons drawn straight onto a CanvasItem. Painted PNGs from the ICONS track (assets/icons/**) are used when present;
## otherwise the procedural fallback below draws them (no per-frame node allocations).
## Skill icon: gradient tile in kit.tint + first CN glyph of the skill name + a small shape by tags.
## Status icon: colored badge + CN glyph, red rim for debuffs, green/gold rim for buffs.

const HudStyle := preload("res://ui/hud_style.gd")
const GD := preload("res://ui/glory_draw.gd")

## Tag -> badge shape (first matching tag wins, in this order).
const TAG_ORDER: Array[String] = ["ultimate", "launcher", "grab", "heal", "summon", "gap_closer", "escape", "cc",
	"aoe", "zone", "ranged", "buff_self", "buff_ally", "defensive", "debuff", "finisher", "combo", "melee"]


static func _rounded_rect_points(r: Rect2, radius: float, seg: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners: Array[Vector2] = [
		Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var start_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in seg + 1:
			var a: float = start_angles[c] + (PI * 0.5) * float(i) / float(seg)
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


## Gradient filled rounded rect (top-left `c1` to bottom-right `c2`).
static func gradient_rect(ci: CanvasItem, r: Rect2, c1: Color, c2: Color, radius: float = 6.0) -> void:
	var pts := _rounded_rect_points(r, radius)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	var diag := r.size.x + r.size.y
	for i in pts.size():
		var t := ((pts[i].x - r.position.x) + (pts[i].y - r.position.y)) / maxf(diag, 1.0)
		cols[i] = c1.lerp(c2, t)
	ci.draw_polygon(pts, cols)


static func outline_rect(ci: CanvasItem, r: Rect2, c: Color, width: float = 1.5, radius: float = 6.0) -> void:
	var pts := _rounded_rect_points(r, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, c, width, true)


static func glyph(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color,
		outline: int = 4, outline_color: Color = Color(0, 0, 0, 0.85), bold: bool = true) -> void:
	var f := HudStyle.font(bold)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var pos := Vector2(center.x - w * 0.5, center.y + (asc - desc) * 0.5)
	if outline > 0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func skill_tag(skill: SkillDef) -> String:
	if skill == null:
		return ""
	if skill.is_ultimate():
		return "ultimate"
	for t: String in TAG_ORDER:
		if skill.tags.has(t):
			return t
	return ""


static func skill_glyph(skill: SkillDef) -> String:
	if skill == null:
		return ""
	var n := skill.name_cn.strip_edges()
	if n == "":
		n = skill.name_en.strip_edges()
	return n.substr(0, 1) if n != "" else "?"


## Full skill icon inside `r`. `tint` = kit.tint (or mob tint).
static func draw_skill_icon(ci: CanvasItem, r: Rect2, skill: SkillDef, tint: Color) -> void:
	var painted := HudStyle.skill_icon(skill)
	if painted != null:
		ci.draw_texture_rect(painted, r, false)
		return
	if skill == null:
		gradient_rect(ci, r, Color(0.12, 0.13, 0.16), Color(0.06, 0.07, 0.09), 7.0)
		return
	var hue_shift := float(absi(hash(str(skill.id))) % 100) / 100.0 * 0.12 - 0.06
	var base := Color.from_hsv(fposmod(tint.h + hue_shift, 1.0), clampf(tint.s * 0.9 + 0.1, 0.25, 0.85),
		clampf(tint.v * 0.75, 0.35, 0.8))
	var light := base.lightened(0.35)
	var dark := base.darkened(0.65)
	gradient_rect(ci, r, light, dark, 7.0)
	# diagonal sheen
	var sheen := PackedVector2Array([r.position + Vector2(r.size.x * 0.0, r.size.y * 0.42),
		r.position + Vector2(r.size.x * 0.42, 0), r.position + Vector2(r.size.x * 0.62, 0),
		r.position + Vector2(0, r.size.y * 0.62)])
	ci.draw_colored_polygon(sheen, Color(1, 1, 1, 0.10))
	var tag := skill_tag(skill)
	# tag motif behind the glyph
	_draw_tag_shape(ci, r, tag, Color(1, 1, 1, 0.22), true)
	var gsize := int(r.size.y * 0.52)
	glyph(ci, r.get_center() + Vector2(0, -r.size.y * 0.02), skill_glyph(skill), gsize, Color(1, 0.98, 0.92),
		maxi(3, int(r.size.y * 0.08)))
	# small badge bottom-right
	if tag != "":
		var b := r.size.x * 0.30
		var br := Rect2(r.end - Vector2(b + 2, b + 2), Vector2(b, b))
		ci.draw_circle(br.get_center(), b * 0.55, Color(0, 0, 0, 0.55))
		_draw_tag_shape(ci, br, tag, Color(1, 0.95, 0.75), false)
	var rim := Color(1, 0.84, 0.35) if tag == "ultimate" else base.lightened(0.5)
	outline_rect(ci, r, rim, 2.0 if tag == "ultimate" else 1.5, 7.0)
	if tag == "ultimate":
		outline_rect(ci, r.grow(-3), Color(1, 0.84, 0.35, 0.45), 1.0, 5.0)


static func _draw_tag_shape(ci: CanvasItem, r: Rect2, tag: String, c: Color, big: bool) -> void:
	var cen := r.get_center()
	var s := minf(r.size.x, r.size.y) * (0.42 if big else 0.36)
	match tag:
		"ultimate":
			_star(ci, cen, s, s * 0.45, 5, c)
		"launcher":
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(0, -s), cen + Vector2(s * 0.8, 0),
				cen + Vector2(s * 0.3, 0), cen + Vector2(s * 0.3, s), cen + Vector2(-s * 0.3, s),
				cen + Vector2(-s * 0.3, 0), cen + Vector2(-s * 0.8, 0)]), c)
		"heal":
			var w := s * 0.36
			ci.draw_rect(Rect2(cen - Vector2(w, s), Vector2(w * 2, s * 2)), c)
			ci.draw_rect(Rect2(cen - Vector2(s, w), Vector2(s * 2, w * 2)), c)
		"aoe", "zone":
			ci.draw_arc(cen, s * 0.9, 0, TAU, 24, c, maxf(1.5, s * 0.18), true)
			ci.draw_circle(cen, s * 0.35, c)
		"ranged":
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(s, 0), cen + Vector2(-s * 0.2, -s * 0.6),
				cen + Vector2(-s * 0.2, -s * 0.2), cen + Vector2(-s, -s * 0.2), cen + Vector2(-s, s * 0.2),
				cen + Vector2(-s * 0.2, s * 0.2), cen + Vector2(-s * 0.2, s * 0.6)]), c)
		"gap_closer", "escape":
			for k in 2:
				var o := Vector2(-s * 0.45 + k * s * 0.7, 0)
				ci.draw_polyline(PackedVector2Array([cen + o + Vector2(-s * 0.35, -s * 0.7), cen + o + Vector2(s * 0.3, 0),
					cen + o + Vector2(-s * 0.35, s * 0.7)]), c, maxf(1.5, s * 0.25), true)
		"cc", "debuff":
			_star(ci, cen, s, s * 0.35, 4, c)
		"grab":
			ci.draw_arc(cen, s * 0.75, PI * 0.15, PI * 1.85, 16, c, maxf(1.5, s * 0.28), true)
		"summon":
			ci.draw_circle(cen + Vector2(0, s * 0.3), s * 0.45, c)
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.75
				ci.draw_circle(cen + Vector2(0, s * 0.2) + Vector2(cos(a), sin(a)) * s * 0.85, s * 0.2, c)
		"buff_self", "buff_ally", "defensive":
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.75, -s * 0.8), cen + Vector2(s * 0.75, -s * 0.8),
				cen + Vector2(s * 0.7, s * 0.1), cen + Vector2(0, s), cen + Vector2(-s * 0.7, s * 0.1)]), c)
		"finisher":
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.2, -s), cen + Vector2(s * 0.6, -s * 0.1),
				cen + Vector2(s * 0.05, -s * 0.05), cen + Vector2(s * 0.3, s), cen + Vector2(-s * 0.6, s * 0.05),
				cen + Vector2(-s * 0.05, 0)]), c)
		"combo", "melee":
			ci.draw_line(cen + Vector2(-s, s), cen + Vector2(s, -s), c, maxf(1.5, s * 0.3), true)
			ci.draw_line(cen + Vector2(-s * 0.55, s * 0.15), cen + Vector2(-s * 0.15, s * 0.55), c, maxf(1.5, s * 0.3), true)
		_:
			pass


static func _star(ci: CanvasItem, cen: Vector2, r_out: float, r_in: float, n: int, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI * 0.5 + PI * float(i) / float(n)
		var rr := r_out if i % 2 == 0 else r_in
		pts.append(cen + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, c)


## Status badge for StatusSet bit `bit` inside `r`: painted icon, else ink ground + glyph; polarity frame
## (buff green-gold, debuff red, CC purple) on the procedural fallback (painted icons carry their own bevel).
static func draw_status_icon(ci: CanvasItem, r: Rect2, bit: int, alpha: float = 1.0) -> void:
	if bit < 0 or bit >= HudStyle.STATUS_INFO.size():
		return
	var painted := HudStyle.status_icon(bit)
	if painted != null:
		ci.draw_texture_rect(painted, r, false, Color(1, 1, 1, alpha))
		return
	var info: Array = HudStyle.STATUS_INFO[bit]
	var c: Color = info[3]
	var frame := HudStyle.status_frame_color(bit)
	var rid := ci.get_canvas_item()
	var pts := GD.chamfer(r, r.size.x * 0.18)
	var cols := PackedColorArray()
	for v in pts:
		var k := clampf((v.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		cols.append(Color(c.darkened(0.55).lerp(Color(0.03, 0.04, 0.08), k * 0.8), alpha))
	GD.poly_grad(rid, pts, cols)
	GD.circle(rid, r.get_center() + Vector2(0, -r.size.y * 0.06), r.size.x * 0.32, Color(c, 0.22 * alpha))
	glyph(ci, r.get_center() + Vector2(0, r.size.y * 0.02), str(info[0]), int(r.size.y * 0.6), Color(c.lerp(Color.WHITE, 0.55), alpha),
		maxi(2, int(r.size.y * 0.1)), Color(0.02, 0.03, 0.07, 0.95 * alpha))
	if HudStyle.is_negative_bit(bit) and not HudStyle.CC_BITS.has(bit):
		GD.polyline(rid, pts, Color(frame, alpha), maxf(1.2, r.size.x * 0.06), true)
	elif HudStyle.CC_BITS.has(bit):
		GD.polyline(rid, pts, Color(frame, alpha), maxf(1.5, r.size.x * 0.08), true)
	else:
		GD.polyline(rid, pts, Color(HudStyle.UI_GOLD, alpha), maxf(1.2, r.size.x * 0.06), true)
		GD.polyline(rid, GD.chamfer(r.grow(-2.0), r.size.x * 0.14), Color(frame, 0.6 * alpha), 1.0, true)


## Class emblem (painted assets/icons/class/<id>.png, else the procedural gold-on-navy crest).
static func draw_class_emblem(ci: CanvasItem, r: Rect2, class_id: String, glyph_text: String, tint: Color, dead: bool = false) -> void:
	var t := HudStyle.class_emblem(class_id)
	var mod := Color(0.5, 0.5, 0.52) if dead else Color.WHITE
	if t != null:
		ci.draw_texture_rect(t, r, false, mod)
		return
	GD.crest(ci.get_canvas_item(), r, glyph_text, tint if not dead else Color(0.4, 0.4, 0.42), HudStyle.brush())


## Circular class badge: navy disc, class emblem, ring in `ring` colour (team / self / boss).
static func draw_portrait(ci: CanvasItem, cen: Vector2, radius: float, f: Fighter, ring: Color, dead: bool) -> void:
	var rid := ci.get_canvas_item()
	GD.circle(rid, cen, radius, Color(0.03, 0.05, 0.1, 0.95))
	GD.circle(rid, cen, radius * 0.86, Color(0.07, 0.12, 0.22, 0.95))
	var cid := ""
	if f != null and is_instance_valid(f):
		cid = f.class_id if f.kit != null else ""
	var er := Rect2(cen - Vector2(radius, radius) * 0.78, Vector2(radius, radius) * 1.56)
	draw_class_emblem(ci, er, cid, HudStyle.class_glyph(f), HudStyle.class_color(f), dead)
	GD.arc(rid, cen, radius - 1.0, 0, TAU, ring, 2.2, 40)
	GD.arc(rid, cen, radius - 3.5, 0, TAU, Color(GD.GOLD_SH, 0.8), 1.0, 40)
