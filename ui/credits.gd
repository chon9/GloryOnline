extends RefCounted
## In-game credits (required: game-icons.net icons are CC BY 3.0 and need visible attribution).
## Reads res://assets/CREDITS.md at runtime and shows every attribution table (tables whose header has a
## "License" column) under its section heading, plus the paragraphs that carry attribution notes
## (CC BY / game-icons / authors to support). Falls back to a built-in summary when the file is not packed.

const HudStyle := preload("res://ui/hud_style.gd")
const CREDITS_PATH: String = "res://assets/CREDITS.md"
const FALLBACK: String = "[b][color=#ffe9a8]素材致谢 Asset Credits[/color][/b]\n" \
	+ "KayKit (Kay Lousberg) - CC0 1.0: characters, animations, weapons, dungeon and nature kits\n" \
	+ "Kenney (kenney.nl) - CC0 1.0: particles, UI pack, RPG audio, impact sounds\n" \
	+ "Icons: game-icons.net silhouettes by their authors - CC BY 3.0 (see assets/CREDITS.md)\n" \
	+ "Fonts - SIL OFL 1.1: Noto Sans SC, Ma Shan Zheng, Teko, Russo One, Orbitron\n" \
	+ "VRoid CC0 sample avatars, Mesh2Motion animations - CC0 / MIT (see assets/CREDITS.md)\n"


static func make_view() -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = true
	rt.selection_enabled = false
	rt.custom_minimum_size = Vector2(0, 380)
	rt.add_theme_font_override("normal_font", HudStyle.sans(500))
	rt.add_theme_font_override("bold_font", HudStyle.sans(800))
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 15)
	rt.text = bbcode()
	return rt


static func bbcode() -> String:
	var txt := ""
	if FileAccess.file_exists(CREDITS_PATH):
		var f := FileAccess.open(CREDITS_PATH, FileAccess.READ)
		if f != null:
			txt = f.get_as_text()
	if txt == "":
		return FALLBACK
	var out := from_markdown(txt)
	return out if out.strip_edges() != "" else FALLBACK


static func _inline(s: String) -> String:
	var t := s.replace("[", "(").replace("]", ")").replace("`", "")
	var re := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	t = re.sub(t, "[b]$1[/b]", true)
	return t.strip_edges()


static func _cells(line: String) -> PackedStringArray:
	var parts := line.strip_edges().trim_prefix("|").trim_suffix("|").split("|")
	var out := PackedStringArray()
	for p in parts:
		out.append(p.strip_edges())
	return out


## Markdown -> BBCode, attribution tables and notes only.
static func from_markdown(md: String) -> String:
	var lines := md.split("\n")
	var out := ""
	var heading := ""
	var heading_done := false
	var in_table := false
	var keep_table := false
	var header: PackedStringArray = []
	var para := ""
	for raw in lines:
		var l := raw.strip_edges()
		if l.begins_with("#"):
			heading = l.lstrip("#").strip_edges()
			heading_done = false
			in_table = false
			continue
		if l.begins_with("|"):
			var cells := _cells(l)
			if not in_table:
				in_table = true
				header = cells
				var hl := " ".join(cells).to_lower()
				keep_table = hl.contains("license") or hl.contains("许可")
				continue
			if cells.size() > 0 and cells[0].begins_with("---"):
				continue
			if keep_table:
				if not heading_done:
					out += "\n[b][color=#ffe9a8]%s[/color][/b]\n" % _inline(heading)
					heading_done = true
				var first := _inline(cells[0]) if cells.size() > 0 else ""
				var rest := PackedStringArray()
				for i in range(1, cells.size()):
					var h := header[i].to_lower() if i < header.size() else ""
					if h.contains("folder") or cells[i] == "":
						continue
					rest.append(_inline(cells[i]))
				out += "[b]%s[/b]  [color=#9aa6b8]%s[/color]\n" % [first, "  ·  ".join(rest)]
			continue
		in_table = false
		if l == "" or l.begins_with("---"):
			if para != "":
				var pl := para.to_lower()
				if pl.contains("cc by") or pl.contains("game-icons") or pl.contains("support") or pl.contains("attribution"):
					out += "[color=#c8d0dc]%s[/color]\n" % _inline(para)
				para = ""
			continue
		para += (" " if para != "" else "") + l
	if para != "":
		var pl2 := para.to_lower()
		if pl2.contains("cc by") or pl2.contains("game-icons") or pl2.contains("support"):
			out += "[color=#c8d0dc]%s[/color]\n" % _inline(para)
	return out.strip_edges()
