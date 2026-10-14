extends RefCounted
## Builds the game-wide UI theme (navy glass + gold, bible section 6) in code. res://ui/theme.tres is this theme
## saved by ui/tools/build_theme.gd; HudStyle.get_theme() falls back to build() if the file is missing.
##   godot --headless --path . -s res://ui/tools/build_theme.gd

const HudStyle := preload("res://ui/hud_style.gd")
const GloryBox := preload("res://ui/glory_stylebox.gd")


static func box(kind: String, ml: float = 14.0, mt: float = 8.0, mr: float = -1.0, mb: float = -1.0, gems: bool = true) -> StyleBox:
	var sb: StyleBox = GloryBox.new()
	sb.set("kind", kind)
	sb.set("gems", gems)
	sb.content_margin_left = ml
	sb.content_margin_top = mt
	sb.content_margin_right = ml if mr < 0.0 else mr
	sb.content_margin_bottom = mt if mb < 0.0 else mb
	return sb


static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 3, m: float = 4.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(m)
	s.anti_aliasing = true
	return s


static func _diamond_tex(px: int, col: Color, rim: Color) -> ImageTexture:
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	for y in px:
		for x in px:
			var d := absf(x - c) + absf(y - c)
			if d <= c - 1.5:
				var k := clampf(1.0 - (y / float(px)) * 0.6, 0.0, 1.0)
				img.set_pixel(x, y, col.lerp(Color.WHITE, 0.35 * k if x < c else 0.0))
			elif d <= c:
				img.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	var sans := HudStyle.sans(500)
	var sans_b := HudStyle.sans(700)
	t.default_font = sans
	t.default_font_size = 17
	var text := HudStyle.C_TEXT
	var dim := HudStyle.C_TEXT_DIM
	var gold_hi := HudStyle.UI_GOLD_HI
	# labels
	t.set_color("font_color", "Label", text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	# panels
	t.set_stylebox("panel", "PanelContainer", box("panel", 18, 16))
	t.set_stylebox("panel", "Panel", box("panel", 18, 16))
	t.set_stylebox("panel", "TooltipPanel", box("plain", 10, 8))
	t.set_color("font_color", "TooltipLabel", text)
	t.set_font("font", "TooltipLabel", sans)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# buttons
	for cls: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, box("button", 18, 7))
		t.set_stylebox("hover", cls, box("button_hover", 18, 7))
		t.set_stylebox("pressed", cls, box("button_pressed", 18, 8, -1, 6))
		t.set_stylebox("hover_pressed", cls, box("button_pressed", 18, 8, -1, 6))
		t.set_stylebox("disabled", cls, box("button_disabled", 18, 7))
		t.set_stylebox("focus", cls, box("button_focus", 18, 7))
		t.set_font("font", cls, sans_b)
		t.set_font_size("font_size", cls, 17)
		t.set_color("font_color", cls, text)
		t.set_color("font_hover_color", cls, gold_hi)
		t.set_color("font_pressed_color", cls, Color(1, 0.96, 0.86))
		t.set_color("font_hover_pressed_color", cls, Color(1, 0.96, 0.86))
		t.set_color("font_focus_color", cls, text)
		t.set_color("font_disabled_color", cls, Color(0.55, 0.58, 0.64))
		t.set_color("font_outline_color", cls, Color(0.01, 0.02, 0.05, 0.8))
		t.set_constant("outline_size", cls, 2)
	t.set_constant("arrow_margin", "OptionButton", 10)
	# check boxes
	for cls2: String in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", cls2, StyleBoxEmpty.new())
		t.set_stylebox("hover", cls2, StyleBoxEmpty.new())
		t.set_stylebox("pressed", cls2, StyleBoxEmpty.new())
		t.set_stylebox("focus", cls2, StyleBoxEmpty.new())
		t.set_color("font_color", cls2, text)
		t.set_color("font_hover_color", cls2, gold_hi)
		t.set_color("font_pressed_color", cls2, gold_hi)
	# inputs
	t.set_stylebox("normal", "LineEdit", box("field", 10, 6))
	t.set_stylebox("focus", "LineEdit", box("field_focus", 10, 6))
	t.set_stylebox("read_only", "LineEdit", box("field", 10, 6))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("font_placeholder_color", "LineEdit", Color(dim, 0.7))
	t.set_color("caret_color", "LineEdit", gold_hi)
	t.set_color("selection_color", "LineEdit", Color(HudStyle.UI_CRYSTAL, 0.4))
	# sliders
	t.set_stylebox("slider", "HSlider", flat(Color(0.02, 0.04, 0.08, 0.95), Color(HudStyle.UI_GOLD, 0.55), 1, 2, 3))
	t.set_stylebox("grabber_area", "HSlider", flat(Color(0.18, 0.45, 0.85, 0.95), Color(0, 0, 0, 0), 0, 2, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color(0.3, 0.6, 1.0, 1.0), Color(0, 0, 0, 0), 0, 2, 3))
	t.set_icon("grabber", "HSlider", _diamond_tex(18, HudStyle.UI_GOLD, Color(0.25, 0.14, 0.03)))
	t.set_icon("grabber_highlight", "HSlider", _diamond_tex(18, gold_hi, Color(0.25, 0.14, 0.03)))
	# scroll bars
	for sc: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, flat(Color(0.02, 0.04, 0.08, 0.6), Color(0, 0, 0, 0), 0, 3, 2))
		t.set_stylebox("grabber", sc, flat(Color(HudStyle.UI_GOLD, 0.55), Color(0, 0, 0, 0), 0, 3, 2))
		t.set_stylebox("grabber_highlight", sc, flat(Color(HudStyle.UI_GOLD, 0.85), Color(0, 0, 0, 0), 0, 3, 2))
		t.set_stylebox("grabber_pressed", sc, flat(gold_hi, Color(0, 0, 0, 0), 0, 3, 2))
	# popups
	t.set_stylebox("panel", "PopupMenu", box("plain", 8, 8))
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.12, 0.24, 0.42, 0.95), Color(HudStyle.UI_GOLD, 0.8), 1, 2, 4))
	t.set_color("font_color", "PopupMenu", text)
	t.set_color("font_hover_color", "PopupMenu", gold_hi)
	t.set_font("font", "PopupMenu", sans)
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_constant("v_separation", "PopupMenu", 8)
	# rich text
	t.set_font("normal_font", "RichTextLabel", sans)
	t.set_font("bold_font", "RichTextLabel", HudStyle.sans(800))
	t.set_color("default_color", "RichTextLabel", text)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 16)
	# separators
	t.set_stylebox("separator", "HSeparator", flat(Color(HudStyle.UI_GOLD, 0.45), Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 6)
	return t
