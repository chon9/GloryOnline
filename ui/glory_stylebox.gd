@tool
class_name GloryStyleBox
extends StyleBox
## Navy-glass + gold style box (bible section 6) for PanelContainers, buttons and inputs, drawn with ui/glory_draw.gd.
## kind:
##   "panel"   navy glass, gold double line, filigree corners, crystal gems (gems toggles the gems)
##   "plain"   navy glass + single gold line, no ornaments (small panels / rows)
##   "holo"    charcoal holo overlay with cyan lines (accent overrides the line colour)
##   "plate"   angled broadcast plate with an accent stripe
##   "button" / "button_hover" / "button_pressed" / "button_disabled" / "button_focus"
##   "field"   dark inset (LineEdit / SpinBox / OptionButton popups)
##   "chip" / "chip_hover" / "chip_on"  class-picker card (accent = class tint)
##   "none"    draws nothing

const GD := preload("res://ui/glory_draw.gd")

@export var kind: String = "panel"
@export var gems: bool = true
@export var accent: Color = Color("#4FD8FF")
@export var fill: Color = Color(0.055, 0.1, 0.165, 0.88)


func _draw(to_canvas_item: RID, r: Rect2) -> void:
	var ci := to_canvas_item
	match kind:
		"panel":
			GD.panel(ci, r, gems, fill)
		"plain":
			var p := GD.chamfer(r, minf(7.0, r.size.y * 0.3))
			GD.poly(ci, p, fill)
			GD.polyline(ci, p, Color(GD.GOLD, 0.7), 1.2, true)
		"holo":
			GD.holo(ci, r, accent)
		"plate":
			GD.plate(ci, r, accent)
		"button", "button_hover", "button_pressed", "button_disabled":
			_button(ci, r)
		"button_focus":
			GD.polyline(ci, GD.chamfer(r.grow(2.0), 9.0), Color(GD.GOLD_HI, 0.55), 1.2, true)
		"field":
			var p2 := GD.chamfer(r, 5.0)
			GD.poly(ci, p2, Color(0.015, 0.03, 0.06, 0.92))
			GD.polyline(ci, p2, Color(GD.CRYSTAL, 0.45), 1.0, true)
		"field_focus":
			GD.polyline(ci, GD.chamfer(r, 5.0), Color(GD.GOLD, 0.95), 1.4, true)
		"chip", "chip_hover", "chip_on":
			_chip(ci, r)
		_:
			pass


func _button(ci: RID, r: Rect2) -> void:
	var ch := minf(9.0, r.size.y * 0.32)
	var p := GD.chamfer(r, ch)
	var top := Color(0.09, 0.16, 0.27, 0.95)
	var bot := Color(0.03, 0.06, 0.11, 0.95)
	var line := Color(GD.GOLD, 0.85)
	match kind:
		"button_hover":
			top = Color(0.14, 0.24, 0.4, 0.97)
			bot = Color(0.05, 0.1, 0.18, 0.97)
			line = GD.GOLD_HI
		"button_pressed":
			top = Color(0.42, 0.3, 0.1, 0.97)
			bot = Color(0.16, 0.1, 0.03, 0.97)
			line = GD.GOLD_HI
		"button_disabled":
			top = Color(0.08, 0.09, 0.12, 0.85)
			bot = Color(0.05, 0.05, 0.07, 0.85)
			line = Color(0.45, 0.48, 0.55, 0.6)
	var cols := PackedColorArray()
	for v in p:
		cols.append(top.lerp(bot, clampf((v.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	GD.poly_grad(ci, p, cols)
	GD.rect(ci, Rect2(r.position + Vector2(ch, 2), Vector2(maxf(0.0, r.size.x - ch * 2), r.size.y * 0.38)), Color(1, 1, 1, 0.045))
	GD.polyline(ci, GD.chamfer(r.grow(-3.0), maxf(1.0, ch - 2.0)), Color(line, 0.3), 1.0, true)
	GD.polyline(ci, p, line, 1.4, true)
	if kind != "button_disabled" and r.size.x > 60:
		# small crystal at the left mid-point, gold ticks at the right
		GD.diamond(ci, Vector2(r.position.x + 1, r.get_center().y), 4.5, 6.0, GD.CRYSTAL if kind != "button_pressed" else GD.GOLD_HI)
		GD.line(ci, Vector2(r.end.x - 10, r.position.y + 5), Vector2(r.end.x - 5, r.position.y + 5), Color(GD.GOLD_HI, 0.6), 1.0)
		GD.line(ci, Vector2(r.end.x - 5, r.position.y + 5), Vector2(r.end.x - 5, r.position.y + 10), Color(GD.GOLD_HI, 0.6), 1.0)


func _chip(ci: RID, r: Rect2) -> void:
	var p := GD.chamfer(r, 6.0)
	var bg := Color(0.04, 0.07, 0.13, 0.92)
	if kind == "chip_hover":
		bg = Color(0.08, 0.13, 0.22, 0.96)
	elif kind == "chip_on":
		bg = Color(accent.darkened(0.62), 0.97)
	GD.poly(ci, p, bg)
	GD.poly(ci, PackedVector2Array([r.position + Vector2(0, 6), r.position + Vector2(6, 0), r.position + Vector2(9, 0),
		Vector2(r.position.x + 3, r.end.y), Vector2(r.position.x, r.end.y - 6)]), accent)
	if kind == "chip_on":
		GD.polyline(ci, p, GD.GOLD_HI, 2.0, true)
		GD.polyline(ci, GD.chamfer(r.grow(-3.0), 4.0), Color(GD.GOLD, 0.45), 1.0, true)
	else:
		GD.polyline(ci, p, Color(GD.GOLD, 0.5 if kind == "chip" else 0.9), 1.0, true)
