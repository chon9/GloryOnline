class_name LdHudWidget
extends Control
## Immediate-mode drawn HUD pieces (bible section 6): navy glass panels with gold filigree + crystal gems,
## holo plates, glossy HP/MP bars with tick marks and a trailing damage bar, skill slots with clock-sweep
## cooldowns, status icons with polarity frames, minimap. One class, `kind` selects what _draw renders.

const PANEL := Color(0.055, 0.1, 0.165, 0.88)        # ui_panel #0E1A2A
const HOLO := Color(0.078, 0.094, 0.125, 0.72)       # ui_holo #141820
const GOLD := Color("#D8B25A")
const GOLD_HI := Color("#FFE9A8")
const GOLD_SH := Color("#8A5A2B")
const CRYSTAL := Color("#3FA9FF")
const CYAN := Color("#4FD8FF")
const TEXT := Color("#F4F6FA")
const DIM := Color("#9AA6B8")
const HP := Color("#E0323C")
const HP_TRAIL := Color("#8A1A22")
const MP := Color("#2F7BFF")

var kind := "panel"
var data: Dictionary = {}


func _init(k := "panel", d := {}) -> void:
	kind = k
	data = d
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match kind:
		"panel": _panel(Rect2(Vector2.ZERO, size), data.get("gems", true))
		"holo": _holo(Rect2(Vector2.ZERO, size))
		"bar": _bar(Rect2(Vector2.ZERO, size))
		"slot": _slot(Rect2(Vector2.ZERO, size))
		"status": _status(Rect2(Vector2.ZERO, size))
		"portrait_ring": _portrait_ring(Rect2(Vector2.ZERO, size))
		"minimap": _minimap(Rect2(Vector2.ZERO, size))
		"callout_band": _callout_band(Rect2(Vector2.ZERO, size))
		"plate": _plate(Rect2(Vector2.ZERO, size))
		"ribbon": _ribbon(Rect2(Vector2.ZERO, size))


# ---------------------------------------------------------------- primitives

func _chamfer(r: Rect2, c: float) -> PackedVector2Array:
	var p := r.position
	var s := r.size
	return PackedVector2Array([p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)])


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o


func _diamond(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)])
	draw_colored_polygon(pts, col.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c]), col.lightened(0.45))
	draw_polyline(_closed(pts), GOLD, 1.2, true)


func _filigree_corner(o: Vector2, sx: float, sy: float) -> void:
	# gold corner flourish (same geometry as icon_painter.hud_corner): two swept horns that taper along the edges,
	# and a gold bead on the diagonal. No square L bracket.
	var s := Vector2(sx, sy)
	for horn: Array in [[Vector2(1.5, 1.5), Vector2(10, 2.2), Vector2(22, 3.4)], [Vector2(1.5, 1.5), Vector2(2.2, 10), Vector2(3.4, 22)]]:
		var a: Vector2 = horn[0]
		var m: Vector2 = horn[1]
		var b: Vector2 = horn[2]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x) * 1.3
		draw_colored_polygon(PackedVector2Array([o + (a + nrm) * s, o + (m + nrm * 0.6) * s, o + b * s, o + (m - nrm * 0.6) * s, o + (a - nrm) * s]), GOLD)
		draw_line(o + a * s, o + m * s, GOLD_HI, 1.0, true)
	draw_circle(o + Vector2(4.2, 4.2) * s, 1.9, GOLD_HI)


func _panel(r: Rect2, gems: bool) -> void:
	var pts := _chamfer(r, 10.0)
	draw_colored_polygon(pts, PANEL)
	# faint magic-circle trace texture (5-8%)
	var c := r.get_center()
	for k in 3:
		draw_arc(c + Vector2(r.size.x * 0.3, 0), r.size.y * (0.5 + k * 0.35), 0, TAU, 48, Color(CYAN, 0.05), 1.0, true)
	for i in 6:
		var x := r.position.x + r.size.x * (0.1 + i * 0.16)
		draw_line(Vector2(x, r.position.y + 6), Vector2(x + 18, r.position.y + 6), Color(CYAN, 0.06), 1.0)
	# top gloss
	draw_rect(Rect2(r.position + Vector2(10, 2), Vector2(r.size.x - 20, r.size.y * 0.35)), Color(1, 1, 1, 0.03))
	draw_polyline(_closed(_chamfer(r.grow(-3.0), 8.0)), Color(GOLD, 0.35), 1.0, true)
	draw_polyline(_closed(pts), GOLD, 1.6, true)
	_filigree_corner(r.position + Vector2(1, 1), 1, 1)
	_filigree_corner(r.position + Vector2(r.size.x - 1, 1), -1, 1)
	_filigree_corner(r.position + Vector2(1, r.size.y - 1), 1, -1)
	_filigree_corner(r.end - Vector2(1, 1), -1, -1)
	if gems:
		_diamond(Vector2(c.x, r.position.y), 7, 9, CRYSTAL)
		_diamond(Vector2(c.x, r.end.y), 6, 7, CRYSTAL)


func _holo(r: Rect2) -> void:
	var pts := _chamfer(r, 14.0)
	draw_colored_polygon(pts, HOLO)
	# scan lines + circuit traces
	var y := r.position.y + 3.0
	while y < r.end.y:
		draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(CYAN, 0.035), 1.0)
		y += 3.0
	var tr := Color(CYAN, 0.25)
	draw_polyline(PackedVector2Array([r.position + Vector2(18, r.size.y - 8), r.position + Vector2(60, r.size.y - 8), r.position + Vector2(70, r.size.y - 18), r.position + Vector2(140, r.size.y - 18)]), tr, 1.0)
	draw_circle(r.position + Vector2(140, r.size.y - 18), 2.2, tr)
	draw_polyline(PackedVector2Array([r.end - Vector2(18, r.size.y - 8), r.end - Vector2(70, r.size.y - 8), r.end - Vector2(80, r.size.y - 16)]), tr, 1.0)
	draw_polyline(_closed(pts), Color(CYAN, 0.8), 1.2, true)
	# bright corner brackets
	for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var o := r.get_center() + Vector2(r.size.x * 0.5 * s.x, r.size.y * 0.5 * s.y) - Vector2(s.x * 2, s.y * 2)
		draw_polyline(PackedVector2Array([o - Vector2(0, s.y * 14), o - Vector2(s.x * 6, s.y * 20)]), Color.WHITE, 2.0)


func _bar(r: Rect2) -> void:
	var v: float = data.get("value", 0.7)
	var trail: float = data.get("trail", v)
	var col: Color = data.get("color", HP)
	var tcol: Color = data.get("trail_color", HP_TRAIL)
	var slant := r.size.y * 0.6
	var bg := PackedVector2Array([r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - slant, r.end.y), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(bg, Color(0.02, 0.03, 0.06, 0.9))
	var w := r.size.x - slant
	var fill := func(t: float, c: Color) -> void:
		var x1 := r.position.x + slant + w * t
		var p := PackedVector2Array([r.position + Vector2(slant, 2), Vector2(x1, r.position.y + 2), Vector2(x1 - slant * (r.size.y - 4) / r.size.y, r.end.y - 2), Vector2(r.position.x + slant * 4.0 / r.size.y, r.end.y - 2)])
		draw_colored_polygon(p, c)
	fill.call(trail, tcol)
	fill.call(v, col)
	# glossy top band + darker bottom
	var x1 := r.position.x + slant + w * v
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(slant, 2), Vector2(x1, r.position.y + 2), Vector2(x1 - slant * 0.35, r.position.y + r.size.y * 0.42), Vector2(r.position.x + slant * 0.65, r.position.y + r.size.y * 0.42)]), Color(1, 1, 1, 0.28))
	# 10% ticks
	for i in range(1, 10):
		var x := r.position.x + slant + w * i / 10.0
		draw_line(Vector2(x, r.position.y + 2), Vector2(x - slant, r.end.y - 2), Color(0, 0, 0, 0.45), 1.0)
	# leading edge highlight
	draw_line(Vector2(x1, r.position.y + 2), Vector2(x1 - slant, r.end.y - 2), Color(1, 1, 1, 0.8), 1.5)
	draw_polyline(_closed(bg), data.get("frame", GOLD), 1.2, true)


func _slot(r: Rect2) -> void:
	var icon: Texture2D = data.get("icon")
	var cd: float = data.get("cd", 0.0)            # 0..1 remaining fraction
	var ult: bool = data.get("ult", false)
	var c := r.get_center()
	# the icon frames are chamfered squares (corner cut = 7% of the side): every state follows that shape
	var face := _chamfer(r, r.size.x * 0.07)
	if ult:
		# slow golden ready halo, following the frame shape
		for k in 4:
			draw_polyline(_closed(_chamfer(r.grow(2.0 + k * 1.8), r.size.x * 0.07 + 2.0 + k * 1.8)), Color(GOLD, 0.32 - k * 0.07), 1.8, true)
	if data.get("flash", false):
		# ready: brief gold flash on the frame (the 150 ms peak of it)
		for k in 6:
			draw_polyline(_closed(_chamfer(r.grow(1.0 + k * 1.6), r.size.x * 0.07 + 1.0 + k * 1.6)), Color(GOLD_HI, 0.55 - k * 0.09), 2.0, true)
	if icon:
		draw_texture_rect(icon, r, false)
	var inset := r.size.x * 0.05
	var inner := r.grow(-inset)
	var box := _chamfer(inner, r.size.x * 0.04)
	if data.get("no_mp", false):
		# not enough MP: the icon stays in colour (it is NOT on cooldown); a blue inner border and a crossed-out
		# MP droplet in the top-right corner say why it cannot be cast
		draw_colored_polygon(box, Color(0.0, 0.02, 0.06, 0.30))
		draw_polyline(_closed(box), Color(MP, 0.95), 2.5, true)
		var dc := Vector2(r.end.x - r.size.x * 0.24, r.position.y + r.size.x * 0.26)
		var dr := r.size.x * 0.13
		var drop := PackedVector2Array([dc + Vector2(0, -dr * 1.5)])
		for i in 13:
			var a := lerpf(-PI * 0.15, PI * 1.15, i / 12.0)
			drop.append(dc + Vector2(cos(a), sin(a)) * dr)
		draw_colored_polygon(drop, Color(0.02, 0.04, 0.1, 0.95))
		var inner_drop := PackedVector2Array()
		for v in drop:
			inner_drop.append(dc + (v - dc) * 0.72)
		draw_colored_polygon(inner_drop, MP)
		draw_line(dc + Vector2(-dr, dr), dc + Vector2(dr, -dr * 1.2), Color(0.02, 0.03, 0.07), 4.0, true)
		draw_line(dc + Vector2(-dr, dr), dc + Vector2(dr, -dr * 1.2), Color("#FF6A6A"), 2.0, true)
	if cd > 0.0:
		# clockwise radial wipe: the remaining sector shows a DARKENED (45% value) and DESATURATED copy of the
		# icon, so a slot on cooldown reads at a glance; a bright tick marks the sweep edge on the frame
		var grey: Texture2D = data.get("icon_cd")
		var pts := PackedVector2Array([c])
		var rad := r.size.x * 0.75
		var a0 := -PI * 0.5
		var a1 := a0 + TAU * cd
		for i in 49:
			var a := lerpf(a0, a1, i / 48.0)
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		for poly in Geometry2D.intersect_polygons(pts, box):
			var uv := PackedVector2Array()
			for v in poly:
				uv.append((v - r.position) / r.size)
			if grey:
				draw_colored_polygon(poly, Color.WHITE, uv, grey)
			else:
				draw_colored_polygon(poly, Color(0, 0, 0, 0.55))
		var dir := Vector2(cos(a1), sin(a1))
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([c, c + dir * rad]), box):
			draw_polyline(seg, Color(1, 0.92, 0.7, 0.55), 1.0, true)
			draw_line(seg[seg.size() - 1] - dir * 6.0, seg[seg.size() - 1], Color(1, 0.96, 0.85, 1.0), 2.5, true)
		var t: float = data.get("t", 0.0)
		var f_cd: Font = data.get("cd_font")
		if f_cd and t > 0.0:
			# whole seconds only: a decimal point vanishes inside the outline at slot size ('1.1' read as '11').
			# The last 3 s are shown by a gold fill bar along the slot bottom that empties instead.
			var txt := "%d" % ceili(t)
			if t <= 3.0:
				var fb := Rect2(inner.position + Vector2(3, inner.size.y - 7), Vector2(inner.size.x - 6, 4))
				draw_rect(fb, Color(0.02, 0.03, 0.07, 0.9))
				draw_rect(Rect2(fb.position, Vector2(fb.size.x * clampf(t / 3.0, 0.0, 1.0), fb.size.y)), Color("#FFC43A"))
			var fs := int(r.size.y * 0.62)
			var sz := f_cd.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var asc := f_cd.get_ascent(fs)
			# Teko's digits sit high in the em box: centre on the cap height (~0.4 of the slot)
			var base := Vector2(c.x - sz.x * 0.5, c.y + asc * 0.36)
			draw_string_outline(f_cd, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.02, 0.03, 0.07, 0.95))
			draw_string(f_cd, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)
	if data.get("pressed", false):
		# pressed / queued: gold stroke that follows the slot shape, soft inner glow, 1.5 px press inset shadow
		for k in 5:
			draw_polyline(_closed(_chamfer(r.grow(-1.0 - k * 2.0), r.size.x * 0.07)), Color(GOLD, 0.30 - k * 0.06), 2.0, true)
		draw_polyline(PackedVector2Array([Vector2(r.position.x + 3, r.end.y - 6), r.position + Vector2(3, 6), Vector2(r.end.x - 6, r.position.y + 3)]), Color(0, 0, 0, 0.6), 1.5, true)
		draw_polyline(_closed(_chamfer(r.grow(1.5), r.size.x * 0.07 + 1.5)), GOLD_HI, 2.0, true)
		draw_polyline(_closed(_chamfer(r.grow(3.0), r.size.x * 0.07 + 3.0)), Color(GOLD, 0.5), 1.2, true)
	var key: String = data.get("key", "")
	var f: Font = data.get("key_font")
	if key != "" and f:
		var fs := 11
		var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tab := Rect2(Vector2(c.x - tw * 0.5 - 6, r.end.y - 7), Vector2(tw + 12, 14))
		var tp := _chamfer(tab, 4.0)
		draw_colored_polygon(tp, Color(0.03, 0.06, 0.11, 0.95))
		draw_polyline(_closed(tp), Color(GOLD if ult else Color("#9AA6B8"), 0.9), 1.0, true)
		draw_string(f, Vector2(c.x - tw * 0.5, tab.position.y + 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)


func _ribbon(r: Rect2) -> void:
	# gold title ribbon (觉醒 over the ultimate): swallow-tailed band, dark bevel line, shimmer
	var nt := r.size.y * 0.45
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - nt, r.position.y + r.size.y * 0.5),
		r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + nt, r.position.y + r.size.y * 0.5)])
	draw_colored_polygon(p, GOLD_SH)
	var inner := PackedVector2Array([r.position + Vector2(nt * 0.8, 2), Vector2(r.end.x - nt * 0.8, r.position.y + 2),
		Vector2(r.end.x - nt * 0.8, r.end.y - 2), Vector2(r.position.x + nt * 0.8, r.end.y - 2)])
	draw_colored_polygon(inner, GOLD)
	draw_rect(Rect2(inner[0], Vector2(inner[1].x - inner[0].x, r.size.y * 0.32)), Color(GOLD_HI, 0.6))
	draw_polyline(_closed(p), Color(0.16, 0.08, 0.02), 1.2, true)


func _status(r: Rect2) -> void:
	var icon: Texture2D = data.get("icon")
	var dur: float = data.get("dur", 1.0)
	if icon:
		draw_texture_rect(icon, r, false, Color(1, 1, 1, 1.0 if dur > 0.12 else 0.55))
	if dur < 1.0:
		var c := r.get_center()
		var pts := PackedVector2Array([c])
		for i in 25:
			var a := -PI * 0.5 + TAU * (1.0 - dur) * i / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * r.size.x * 0.40)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	var stack: String = data.get("stack", "")
	var f: Font = data.get("font")
	if stack != "" and f:
		# stack count: big bold digit, dark outline, bottom-right corner (overhangs the badge slightly)
		var fs := int(r.size.y * 0.72)
		var sz := f.get_string_size(stack, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var base := Vector2(r.end.x - sz.x + 3, r.end.y + 4)
		draw_string_outline(f, base, stack, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.02, 0.03, 0.07, 0.95))
		draw_string(f, base, stack, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FFF4D0"))


func _portrait_ring(r: Rect2) -> void:
	var c := r.get_center()
	var rad := r.size.x * 0.5
	draw_arc(c, rad - 2, 0, TAU, 64, GOLD, 3.0, true)
	draw_arc(c, rad - 6, 0, TAU, 64, Color(GOLD_SH, 0.9), 1.5, true)
	draw_arc(c, rad + 3, -PI * 0.9, -PI * 0.1, 32, GOLD_HI, 1.5, true)
	# spiky sunburst ornaments below (hero frame only)
	for i in 7:
		var a := PI * 0.5 + (i - 3) * 0.18
		var p0 := c + Vector2(cos(a), sin(a)) * (rad - 1)
		var p1 := c + Vector2(cos(a), sin(a)) * (rad + 10 + (6 if i % 2 == 0 else 0))
		draw_colored_polygon(PackedVector2Array([p0 + Vector2(-3, 0).rotated(a + PI * 0.5), p1, p0 + Vector2(3, 0).rotated(a + PI * 0.5)]), GOLD)
	_diamond(c + Vector2(rad * 0.72, rad * 0.72), 9, 11, CRYSTAL)


func _minimap(r: Rect2) -> void:
	var c := r.get_center()
	var rad := r.size.x * 0.5 - 6
	draw_circle(c, rad, Color(0.06, 0.12, 0.2, 0.86))
	# arena octagon + paths
	var oct := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 8.0 + PI / 8.0
		oct.append(c + Vector2(cos(a), sin(a)) * rad * 0.42)
	draw_polyline(oct, Color(CYAN, 0.8), 1.5, true)
	draw_arc(c, rad * 0.32, 0, TAU, 32, Color(CYAN, 0.25), 1.0, true)
	draw_circle(c + Vector2(rad * 0.45, -rad * 0.55), 5, Color("#E0283A"))   # red maple landmark
	draw_circle(c + Vector2(-rad * 0.3, -rad * 0.62), 3, Color(0.8, 0.85, 1.0))
	for p: Array in data.get("dots", []):
		draw_circle(c + (p[0] as Vector2) * rad, 4.0, p[1])
	# player arrow
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 6), c + Vector2(0, 2), c + Vector2(-6, 6)]), Color.WHITE)
	draw_arc(c, rad + 2, 0, TAU, 72, GOLD, 3.0, true)
	draw_arc(c, rad + 6, 0, TAU, 72, Color(GOLD_SH, 0.8), 1.2, true)
	for i in 72:
		var a := TAU * i / 72.0
		var l := 7.0 if i % 18 == 0 else 3.5
		draw_line(c + Vector2(cos(a), sin(a)) * (rad - 1), c + Vector2(cos(a), sin(a)) * (rad - 1 - l), Color(GOLD_HI, 0.8), 1.0)


func _callout_band(r: Rect2) -> void:
	# diagonal slash band behind the calligraphy skill name (element colour), white-hot edge, speed lines
	var col: Color = data.get("color", Color("#6FA8FF"))
	var sk := r.size.y * 0.5
	var band := PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(band, Color(0.03, 0.05, 0.1, 0.78))
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - 4, r.position.y + 6), r.position + Vector2(sk - 4, 6)]), Color(col, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.end.x - sk + 3, r.end.y - 3), Vector2(r.position.x + 3, r.end.y - 3)]), Color(col, 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var y := r.position.y + rng.randf_range(8, r.size.y - 8)
		var x0 := r.position.x + rng.randf_range(0.0, r.size.x * 0.5)
		draw_line(Vector2(x0, y), Vector2(x0 + rng.randf_range(60, 240), y), Color(col.lightened(0.5), rng.randf_range(0.08, 0.3)), rng.randf_range(1.0, 2.5))


func _plate(r: Rect2) -> void:
	# angled broadcast name plate (team colour)
	var col: Color = data.get("color", MP)
	var sk := r.size.y * 0.45
	var p := PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.position.x, r.end.y)])
	draw_colored_polygon(p, Color(0.04, 0.05, 0.09, 0.85))
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(sk, 0), r.position + Vector2(sk + 8, 0), Vector2(r.position.x + 8, r.end.y), Vector2(r.position.x, r.end.y)]), col)
	draw_polyline(_closed(p), Color(col, 0.9), 1.2, true)
