@tool
extends RefCounted
## Glory UI drawing primitives (port of the look-dev LdHudWidget, bible section 6). Every function draws onto a
## CanvasItem RID, so the same code serves Control._draw (pass get_canvas_item()) and GloryStyleBox._draw.
##   navy glass panel + gold filigree corners + blue crystal gems, holo plate, slanted glossy bars with 10% ticks,
##   chamfered skill-slot frames, swallow-tail ribbon, broadcast name plate, calligraphy call-out band,
##   portrait ring with sunburst, minimap rim, procedural class crest.

const PANEL := Color(0.055, 0.1, 0.165, 0.88)
const HOLO := Color(0.078, 0.094, 0.125, 0.74)
const GOLD := Color("#D8B25A")
const GOLD_HI := Color("#FFE9A8")
const GOLD_SH := Color("#8A5A2B")
const CRYSTAL := Color("#3FA9FF")
const CYAN := Color("#4FD8FF")
const TEXT := Color("#F4F6FA")
const INK := Color(0.02, 0.03, 0.07)



# ---------------------------------------------------------------- low level
static func poly(ci: RID, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([col]))


static func poly_grad(ci: RID, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	RenderingServer.canvas_item_add_polygon(ci, pts, cols)


static func line(ci: RID, a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	RenderingServer.canvas_item_add_line(ci, a, b, col, w, true)


static func polyline(ci: RID, pts: PackedVector2Array, col: Color, w: float = 1.0, closed: bool = false) -> void:
	if pts.size() < 2:
		return
	var p := pts
	if closed:
		p = pts.duplicate()
		p.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, p, PackedColorArray([col]), w, true)


static func circle(ci: RID, c: Vector2, r: float, col: Color) -> void:
	RenderingServer.canvas_item_add_circle(ci, c, r, col, true)


static func arc(ci: RID, c: Vector2, r: float, a0: float, a1: float, col: Color, w: float = 1.0, seg: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / seg)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), w, true)


static func rect(ci: RID, r: Rect2, col: Color) -> void:
	RenderingServer.canvas_item_add_rect(ci, r, col)


static func tex(ci: RID, t: Texture2D, r: Rect2, modulate: Color = Color.WHITE) -> void:
	if t != null:
		RenderingServer.canvas_item_add_texture_rect(ci, r, t.get_rid(), false, modulate)


## Text with outline. `pos` = baseline left.
static func text(ci: RID, f: Font, pos: Vector2, s: String, size: int, col: Color, outline: int = 0,
		ocol: Color = Color(0.01, 0.02, 0.05, 0.92)) -> void:
	if outline > 0:
		f.draw_string_outline(ci, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
	f.draw_string(ci, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Text centred on `c` (vertically on the cap height).
static func text_c(ci: RID, f: Font, c: Vector2, s: String, size: int, col: Color, outline: int = 0,
		ocol: Color = Color(0.01, 0.02, 0.05, 0.92)) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	text(ci, f, Vector2(c.x - w * 0.5, c.y + (asc - desc) * 0.5), s, size, col, outline, ocol)


static func chamfer(r: Rect2, c: float) -> PackedVector2Array:
	c = minf(c, minf(r.size.x, r.size.y) * 0.5)
	var p := r.position
	var s := r.size
	return PackedVector2Array([p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)])


static func slant(r: Rect2, sk: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - sk, r.end.y),
		Vector2(r.position.x, r.end.y)])


# ---------------------------------------------------------------- ornaments
static func diamond(ci: RID, c: Vector2, rx: float, ry: float, col: Color = CRYSTAL) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)])
	poly(ci, pts, col.darkened(0.1))
	poly(ci, PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c]), col.lightened(0.45))
	polyline(ci, pts, GOLD, 1.2, true)


## Gold corner flourish: two tapered horns along the edges and a bead on the diagonal.
static func filigree_corner(ci: RID, o: Vector2, sx: float, sy: float, k: float = 1.0) -> void:
	var s := Vector2(sx, sy) * k
	for horn: Array in [[Vector2(1.5, 1.5), Vector2(10, 2.2), Vector2(22, 3.4)], [Vector2(1.5, 1.5), Vector2(2.2, 10), Vector2(3.4, 22)]]:
		var a: Vector2 = horn[0]
		var m: Vector2 = horn[1]
		var b: Vector2 = horn[2]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x) * 1.3
		poly(ci, PackedVector2Array([o + (a + nrm) * s, o + (m + nrm * 0.6) * s, o + b * s, o + (m - nrm * 0.6) * s, o + (a - nrm) * s]), GOLD)
		line(ci, o + a * s, o + m * s, GOLD_HI, 1.0)
	circle(ci, o + Vector2(4.2, 4.2) * s, 1.9 * k, GOLD_HI)


# ---------------------------------------------------------------- panels
## Navy glass panel: magic-circle traces, top gloss, inner + outer gold line, filigree corners, crystal gems.
static func panel(ci: RID, r: Rect2, gems: bool = true, fill: Color = PANEL, border: Color = GOLD, corners: bool = true) -> void:
	if r.size.x < 8 or r.size.y < 8:
		return
	var ch := minf(10.0, minf(r.size.x, r.size.y) * 0.3)
	var pts := chamfer(r, ch)
	poly(ci, pts, fill)
	var c := r.get_center()
	var clip := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	for k in 3:
		var rad := r.size.y * (0.5 + k * 0.35)
		var cc := c + Vector2(r.size.x * 0.3, 0)
		var seg := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			var p := cc + Vector2(cos(a), sin(a)) * rad
			seg.append(Vector2(clampf(p.x, clip.position.x, clip.end.x), clampf(p.y, clip.position.y, clip.end.y)))
		RenderingServer.canvas_item_add_polyline(ci, seg, PackedColorArray([Color(CYAN, 0.045)]), 1.0, true)
	for i in 6:
		var x := r.position.x + r.size.x * (0.1 + i * 0.16)
		line(ci, Vector2(x, r.position.y + 6), Vector2(minf(x + 18, r.end.x - 6), r.position.y + 6), Color(CYAN, 0.06))
	var gh := minf(r.size.y * 0.35, 60.0)
	var g0 := r.position + Vector2(ch, 2)
	poly_grad(ci, PackedVector2Array([g0, g0 + Vector2(r.size.x - ch * 2, 0), g0 + Vector2(r.size.x - ch * 2, gh), g0 + Vector2(0, gh)]),
		PackedColorArray([Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	polyline(ci, chamfer(r.grow(-3.0), ch - 2.0), Color(border, 0.35), 1.0, true)
	polyline(ci, pts, border, 1.6, true)
	if corners and r.size.x > 60 and r.size.y > 40:
		var k := 1.0 if r.size.y > 70 else 0.75
		filigree_corner(ci, r.position + Vector2(1, 1), 1, 1, k)
		filigree_corner(ci, Vector2(r.end.x - 1, r.position.y + 1), -1, 1, k)
		filigree_corner(ci, Vector2(r.position.x + 1, r.end.y - 1), 1, -1, k)
		filigree_corner(ci, r.end - Vector2(1, 1), -1, -1, k)
	if gems:
		diamond(ci, Vector2(c.x, r.position.y), 7, 9)
		diamond(ci, Vector2(c.x, r.end.y), 6, 7)


## Charcoal holo overlay (target info, scoreboard): scan lines, circuit traces, cyan line, white corner ticks.
static func holo(ci: RID, r: Rect2, line_col: Color = CYAN, fill: Color = HOLO) -> void:
	if r.size.x < 8 or r.size.y < 8:
		return
	var pts := chamfer(r, minf(14.0, minf(r.size.x, r.size.y) * 0.3))
	poly(ci, pts, fill)
	var y := r.position.y + 3.0
	while y < r.end.y - 2:
		line(ci, Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(line_col, 0.03))
		y += 3.0
	var tr := Color(line_col, 0.25)
	if r.size.x > 200:
		polyline(ci, PackedVector2Array([r.position + Vector2(18, r.size.y - 8), r.position + Vector2(60, r.size.y - 8),
			r.position + Vector2(70, r.size.y - 18), r.position + Vector2(140, r.size.y - 18)]), tr)
		circle(ci, r.position + Vector2(140, r.size.y - 18), 2.2, tr)
		polyline(ci, PackedVector2Array([Vector2(r.end.x - 18, r.position.y + 8), Vector2(r.end.x - 70, r.position.y + 8),
			Vector2(r.end.x - 80, r.position.y + 16)]), tr)
	polyline(ci, pts, Color(line_col, 0.8), 1.2, true)
	for s: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var o := r.get_center() + Vector2(r.size.x * 0.5 * s.x, r.size.y * 0.5 * s.y) - s * 2.0
		line(ci, o - Vector2(0, s.y * 14), o - Vector2(s.x * 6, s.y * 20), Color.WHITE, 2.0)


## Angled broadcast name plate with a team-colour stripe.
static func plate(ci: RID, r: Rect2, col: Color, fill: Color = Color(0.04, 0.05, 0.09, 0.86)) -> void:
	var sk := minf(r.size.y * 0.45, r.size.x * 0.2)
	var p := slant(r, sk)
	poly(ci, p, fill)
	poly(ci, PackedVector2Array([r.position + Vector2(sk, 0), r.position + Vector2(sk + 8, 0), Vector2(r.position.x + 8, r.end.y),
		Vector2(r.position.x, r.end.y)]), col)
	polyline(ci, p, Color(col, 0.9), 1.2, true)


## Gold swallow-tail ribbon (觉醒 over the ultimate).
static func ribbon(ci: RID, r: Rect2) -> void:
	var nt := r.size.y * 0.45
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - nt, r.position.y + r.size.y * 0.5),
		r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + nt, r.position.y + r.size.y * 0.5)])
	poly(ci, p, GOLD_SH)
	var inner := PackedVector2Array([r.position + Vector2(nt * 0.8, 2), Vector2(r.end.x - nt * 0.8, r.position.y + 2),
		Vector2(r.end.x - nt * 0.8, r.end.y - 2), Vector2(r.position.x + nt * 0.8, r.end.y - 2)])
	poly(ci, inner, GOLD)
	rect(ci, Rect2(inner[0], Vector2(inner[1].x - inner[0].x, r.size.y * 0.32)), Color(GOLD_HI, 0.6))
	polyline(ci, p, Color(0.16, 0.08, 0.02), 1.2, true)


## Diagonal slash band behind a calligraphy name, white-hot edge, speed lines.
static func callout_band(ci: RID, r: Rect2, col: Color, seed_v: int = 5, alpha: float = 1.0) -> void:
	var sk := r.size.y * 0.5
	poly(ci, slant(r, sk), Color(0.03, 0.05, 0.1, 0.8 * alpha))
	poly(ci, PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - 4, r.position.y + 6),
		r.position + Vector2(sk - 4, 6)]), Color(col, 0.95 * alpha))
	poly(ci, PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.end.x - sk + 3, r.end.y - 3),
		Vector2(r.position.x + 3, r.end.y - 3)]), Color(col, 0.7 * alpha))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 22:
		var y := r.position.y + rng.randf_range(8, maxf(9.0, r.size.y - 8))
		var x0 := r.position.x + rng.randf_range(0.0, r.size.x * 0.5)
		line(ci, Vector2(x0, y), Vector2(minf(x0 + rng.randf_range(60, 240), r.end.x - sk * 0.5), y),
			Color(col.lightened(0.5), rng.randf_range(0.08, 0.3) * alpha), rng.randf_range(1.0, 2.5))


# ---------------------------------------------------------------- bars
## Slanted glossy resource bar: dark back, trailing damage fill, main fill, gloss band, 10% ticks, leading edge.
## Returns the fill end x (for overlays).
static func bar(ci: RID, r: Rect2, v: float, trail: float, col: Color, tcol: Color, frame: Color = GOLD,
		ticks: int = 10, shield: float = 0.0) -> float:
	if r.size.x < 8 or r.size.y < 3:
		return r.position.x
	v = clampf(v, 0.0, 1.0)
	trail = clampf(trail, v, 1.0)
	var sl := minf(r.size.y * 0.6, r.size.x * 0.1)
	var bg := slant(r, sl)
	poly(ci, bg, Color(0.02, 0.03, 0.06, 0.9))
	var w := r.size.x - sl
	var inset := minf(2.0, r.size.y * 0.15)
	var fill_poly := func(t0: float, t1: float) -> PackedVector2Array:
		var xa := r.position.x + sl + w * t0
		var xb := r.position.x + sl + w * t1
		var k := sl * (r.size.y - inset * 2.0) / r.size.y
		return PackedVector2Array([Vector2(xa, r.position.y + inset), Vector2(xb, r.position.y + inset),
			Vector2(xb - k, r.end.y - inset), Vector2(xa - k, r.end.y - inset)])
	if trail > v + 0.001:
		poly(ci, fill_poly.call(v, trail), tcol)
	if v > 0.001:
		var fp: PackedVector2Array = fill_poly.call(0.0, v)
		poly_grad(ci, fp, PackedColorArray([col.lightened(0.18), col.lightened(0.18), col.darkened(0.3), col.darkened(0.3)]))
		var x1 := r.position.x + sl + w * v
		poly(ci, PackedVector2Array([r.position + Vector2(sl, inset), Vector2(x1, r.position.y + inset),
			Vector2(x1 - sl * 0.35, r.position.y + r.size.y * 0.42), Vector2(r.position.x + sl * 0.65, r.position.y + r.size.y * 0.42)]),
			Color(1, 1, 1, 0.26))
	if shield > 0.001:
		var s0 := minf(v, 1.0 - shield)
		var sp: PackedVector2Array = fill_poly.call(s0, minf(1.0, s0 + shield))
		poly(ci, sp, Color(0.92, 0.96, 1.0, 0.55))
		polyline(ci, sp, Color(1, 1, 1, 0.95), 1.0, true)
	if ticks > 1:
		for i in range(1, ticks):
			var x := r.position.x + sl + w * i / float(ticks)
			line(ci, Vector2(x, r.position.y + inset), Vector2(x - sl, r.end.y - inset), Color(0, 0, 0, 0.45))
	var xe := r.position.x + sl + w * v
	if v > 0.001 and v < 0.999:
		line(ci, Vector2(xe, r.position.y + inset), Vector2(xe - sl, r.end.y - inset), Color(1, 1, 1, 0.8), 1.5)
	if frame.a > 0.0:
		polyline(ci, bg, frame, 1.2, true)
	return xe


# ---------------------------------------------------------------- portrait / minimap / crest
static func portrait_ring(ci: RID, r: Rect2, ring: Color = GOLD, sunburst: bool = true, gem: bool = true) -> void:
	var c := r.get_center()
	var rad := r.size.x * 0.5
	arc(ci, c, rad - 2, 0, TAU, ring, 3.0, 64)
	arc(ci, c, rad - 6, 0, TAU, Color(GOLD_SH, 0.9), 1.5, 64)
	arc(ci, c, rad + 3, -PI * 0.9, -PI * 0.1, GOLD_HI, 1.5, 32)
	if sunburst:
		for i in 7:
			var a := PI * 0.5 + (i - 3) * 0.18
			var p0 := c + Vector2(cos(a), sin(a)) * (rad - 1)
			var p1 := c + Vector2(cos(a), sin(a)) * (rad + rad * 0.1 + (rad * 0.06 if i % 2 == 0 else 0.0))
			poly(ci, PackedVector2Array([p0 + Vector2(-3, 0).rotated(a + PI * 0.5), p1, p0 + Vector2(3, 0).rotated(a + PI * 0.5)]), GOLD)
	if gem:
		diamond(ci, c + Vector2(rad * 0.72, rad * 0.72), rad * 0.09, rad * 0.11)


static func minimap_rim(ci: RID, c: Vector2, rad: float) -> void:
	arc(ci, c, rad + 2, 0, TAU, GOLD, 3.0, 72)
	arc(ci, c, rad + 6, 0, TAU, Color(GOLD_SH, 0.8), 1.2, 72)
	for i in 72:
		var a := TAU * i / 72.0
		var l := 7.0 if i % 18 == 0 else 3.5
		line(ci, c + Vector2(cos(a), sin(a)) * (rad - 1), c + Vector2(cos(a), sin(a)) * (rad - 1 - l), Color(GOLD_HI, 0.8))


## Procedural class crest (fallback when assets/icons/class/<id>.png is missing): navy shield, gold double rim,
## crystal side gems, sunburst base and the class's first CN glyph in brush calligraphy.
static func crest(ci: RID, r: Rect2, glyph: String, tint: Color, glyph_font: Font) -> void:
	var c := r.get_center()
	var w := r.size.x * 0.5
	var h := r.size.y * 0.5
	var sh := PackedVector2Array([c + Vector2(-w * 0.78, -h * 0.82), c + Vector2(0, -h * 0.98), c + Vector2(w * 0.78, -h * 0.82),
		c + Vector2(w * 0.74, h * 0.1), c + Vector2(0, h * 0.95), c + Vector2(-w * 0.74, h * 0.1)])
	for i in 5:
		var a := PI * 0.5 + (i - 2) * 0.34
		var p0 := c + Vector2(0, h * 0.35)
		poly(ci, PackedVector2Array([p0 + Vector2(-w * 0.12, 0).rotated(a - PI * 0.5), p0 + Vector2(cos(a), sin(a)) * h * (0.75 if i % 2 == 0 else 0.62),
			p0 + Vector2(w * 0.12, 0).rotated(a - PI * 0.5)]), Color(GOLD, 0.85))
	poly_grad(ci, sh, PackedColorArray([Color(0.1, 0.16, 0.3), Color(0.12, 0.2, 0.36), Color(0.1, 0.16, 0.3),
		Color(0.04, 0.06, 0.12), Color(0.03, 0.04, 0.09), Color(0.04, 0.06, 0.12)]))
	var inner := PackedVector2Array()
	for p in sh:
		inner.append(c + (p - c) * 0.84)
	poly(ci, inner, Color(tint.darkened(0.55), 0.55))
	polyline(ci, inner, Color(GOLD, 0.55), 1.0, true)
	polyline(ci, sh, GOLD, maxf(1.5, r.size.x * 0.035), true)
	diamond(ci, c + Vector2(-w * 0.78, -h * 0.35), w * 0.1, h * 0.13)
	diamond(ci, c + Vector2(w * 0.78, -h * 0.35), w * 0.1, h * 0.13)
	if glyph_font != null and glyph != "":
		text_c(ci, glyph_font, c + Vector2(0, -h * 0.06), glyph, int(r.size.y * 0.5), GOLD_HI, maxi(2, int(r.size.y * 0.05)), Color(0.12, 0.06, 0.0, 0.95))
