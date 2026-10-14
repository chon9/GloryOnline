extends PanelContainer
## Scoreboard (hold `): per player K / D / damage / healing, grouped by team. Labels are pooled.
## Data: live Fighter counters merged with Match.stats (fighters may be freed between rounds).

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")


class Emblem extends Control:
	var class_id: String = ""
	var glyph: String = ""
	var tint: Color = Color.WHITE
	var dead: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(30, 30)

	func _draw() -> void:
		if glyph != "" or class_id != "":
			HudIcons.draw_class_emblem(self, Rect2(Vector2.ZERO, size), class_id, glyph, tint, dead)


const ROWS_PER_TEAM: int = 6
const COLS: Array[String] = ["名称 Name", "职业 Class", "击败 K", "阵亡 D", "伤害 Damage", "治疗 Healing"]
const COL_W: Array[float] = [250.0, 170.0, 70.0, 70.0, 120.0, 120.0]

var title: Label
var subtitle: Label
var team_titles: Array = []       # Array[Label]
var grids: Array = []             # Array[GridContainer]
var cells: Array = []             # [team][row][col] -> Label
var emblems: Array = []           # [team][row] -> Emblem
var row_count: int = 0
var hint: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.glory("holo", 0.0)
	sb.set("fill", Color(0.035, 0.05, 0.08, 0.96))
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	title = HudStyle.make_label_f("战绩  Scoreboard", HudStyle.brush(), 38, HudStyle.UI_GOLD_HI, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	subtitle = HudStyle.make_label("", 14, HudStyle.C_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle)
	for team in 2:
		var tl := HudStyle.make_label(HudStyle.team_name(team), 18, HudStyle.team_color(team).lightened(0.3), true)
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := HudStyle.glory("plate", 0.0, HudStyle.team_color(team))
		psb.content_margin_left = 24.0
		psb.content_margin_right = 30.0
		psb.content_margin_top = 1.0
		psb.content_margin_bottom = 2.0
		plate.add_theme_stylebox_override("panel", psb)
		plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		plate.add_child(tl)
		vb.add_child(plate)
		team_titles.append(tl)
		var g := GridContainer.new()
		g.columns = COLS.size() + 1
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 4)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(g)
		grids.append(g)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(30, 0)
		g.add_child(spacer)
		for c in COLS.size():
			var h := HudStyle.make_label(COLS[c], 13, Color(HudStyle.UI_CYAN, 0.85), true, 3)
			h.custom_minimum_size = Vector2(COL_W[c], 0)
			if c >= 2:
				h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(h)
		var trows: Array = []
		var tems: Array = []
		for r in ROWS_PER_TEAM:
			var row: Array = []
			var em := Emblem.new()
			g.add_child(em)
			tems.append(em)
			for c in COLS.size():
				var l := HudStyle.make_label("", 16, HudStyle.C_TEXT, c == 0, 3) if c < 2 else HudStyle.make_label_f("", HudStyle.num(600), 22, HudStyle.C_TEXT, 3)
				l.custom_minimum_size = Vector2(COL_W[c], 0)
				l.clip_text = true
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if c >= 2:
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				g.add_child(l)
				row.append(l)
			trows.append(row)
		cells.append(trows)
		emblems.append(tems)
	hint = HudStyle.make_label("松开 ` 关闭  Release ` to close", 12, HudStyle.C_TEXT_DIM, false, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)


## Rebuilds the table. `match_stats` = Match.stats (uid -> {name, class_id, team, kills, ...}) or {}.
func refresh(world: World, match_stats: Dictionary, viewer: Fighter, mode_text: String) -> void:
	subtitle.text = mode_text
	var per_team: Array = [[], []]
	var seen: Dictionary = {}
	if world != null and is_instance_valid(world):
		for f: Fighter in world.fighters:
			if not is_instance_valid(f) or f.kind in ["summon", "mob", "boss"]:
				continue
			var s: Dictionary = match_stats.get(f.uid, {})
			var e := {
				"uid": f.uid, "name": f.display_name, "cls": HudStyle.class_name_of(f), "team": f.team, "class_id": f.class_id,
				"kills": maxi(f.kills, int(s.get("kills", 0))), "deaths": maxi(f.deaths, int(s.get("deaths", 0))),
				"damage": maxf(f.damage_dealt, float(s.get("damage", 0.0))),
				"healing": maxf(f.healing_done, float(s.get("healing", 0.0))),
				"dead": not f.is_alive(), "color": HudStyle.class_color(f), "me": f == viewer,
			}
			seen[f.uid] = true
			per_team[clampi(f.team, 0, 1)].append(e)
	for uid: Variant in match_stats:
		if seen.has(uid):
			continue
		var s: Dictionary = match_stats[uid]
		if str(s.get("kind", "")) in ["summon", "mob", "boss"]:
			continue
		var kit := CoreUtil.get_kit(str(s.get("class_id", "")))
		per_team[clampi(int(s.get("team", 0)), 0, 1)].append({
			"uid": int(uid), "name": str(s.get("name", "?")), "team": int(s.get("team", 0)), "class_id": str(s.get("class_id", "")),
			"cls": ("%s %s" % [kit.name_cn, kit.name_en]) if kit != null else str(s.get("class_id", "")),
			"kills": int(s.get("kills", 0)), "deaths": int(s.get("deaths", 0)), "damage": float(s.get("damage", 0.0)),
			"healing": float(s.get("healing", 0.0)), "dead": true,
			"color": kit.tint.lerp(Color.WHITE, 0.25) if kit != null else HudStyle.C_TEXT, "me": false,
		})
	row_count = 0
	for team in 2:
		var arr: Array = per_team[team]
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["kills"]) != int(b["kills"]):
				return int(a["kills"]) > int(b["kills"])
			return float(a["damage"]) > float(b["damage"]))
		var show := arr.size() > 0
		(team_titles[team] as Label).get_parent().visible = show
		(grids[team] as GridContainer).visible = show
		var tk := 0
		for e: Dictionary in arr:
			tk += int(e["kills"])
		(team_titles[team] as Label).text = "%s   击败 Kills %d" % [HudStyle.team_name(team), tk]
		for r in ROWS_PER_TEAM:
			var row: Array = cells[team][r]
			var has := r < arr.size()
			for c in COLS.size():
				(row[c] as Label).visible = has
			var em: Emblem = emblems[team][r]
			em.visible = has
			if not has:
				continue
			row_count += 1
			var e: Dictionary = arr[r]
			em.class_id = str(e.get("class_id", ""))
			em.glyph = str(e.get("cls", "?")).substr(0, 1)
			em.tint = e["color"]
			em.dead = bool(e["dead"])
			em.queue_redraw()
			var name_l: Label = row[0]
			name_l.text = ("> " if e["me"] else "") + str(e["name"]) + ("  (阵亡)" if e["dead"] else "")
			name_l.add_theme_color_override("font_color", HudStyle.UI_GOLD_HI if e["me"] else HudStyle.C_TEXT)
			(row[1] as Label).text = str(e["cls"])
			(row[1] as Label).add_theme_color_override("font_color", (e["color"] as Color).lerp(Color.WHITE, 0.45))
			(row[2] as Label).text = str(e["kills"])
			(row[3] as Label).text = str(e["deaths"])
			(row[4] as Label).text = HudStyle.fmt_num(float(e["damage"]))
			(row[5] as Label).text = HudStyle.fmt_num(float(e["healing"]))
			for c in COLS.size():
				(row[c] as Label).modulate.a = 0.6 if e["dead"] else 1.0
