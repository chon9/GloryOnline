extends PanelContainer
## Scoreboard (hold `): per player K / D / damage / healing, grouped by team. Labels are pooled.
## Data: live Fighter counters merged with Match.stats (fighters may be freed between rounds).

const HudStyle := preload("res://ui/hud_style.gd")

const ROWS_PER_TEAM: int = 6
const COLS: Array[String] = ["名称 Name", "职业 Class", "击败 K", "阵亡 D", "伤害 Damage", "治疗 Healing"]
const COL_W: Array[float] = [250.0, 170.0, 70.0, 70.0, 120.0, 120.0]

var title: Label
var subtitle: Label
var team_titles: Array = []       # Array[Label]
var grids: Array = []             # Array[GridContainer]
var cells: Array = []             # [team][row][col] -> Label
var row_count: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.panel(Color(0.03, 0.04, 0.07, 0.9), HudStyle.C_BORDER, 12, 2, 18.0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	title = HudStyle.make_label("战绩 Scoreboard", 26, HudStyle.C_GOLD, true, 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	subtitle = HudStyle.make_label("", 14, HudStyle.C_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle)
	for team in 2:
		var tl := HudStyle.make_label(HudStyle.team_name(team), 18, HudStyle.team_color(team), true)
		vb.add_child(tl)
		team_titles.append(tl)
		var g := GridContainer.new()
		g.columns = COLS.size()
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 4)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(g)
		grids.append(g)
		for c in COLS.size():
			var h := HudStyle.make_label(COLS[c], 13, HudStyle.C_TEXT_DIM, true, 3)
			h.custom_minimum_size = Vector2(COL_W[c], 0)
			if c >= 2:
				h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(h)
		var trows: Array = []
		for r in ROWS_PER_TEAM:
			var row: Array = []
			for c in COLS.size():
				var l := HudStyle.make_label("", 16, HudStyle.C_TEXT, c == 0, 3)
				l.custom_minimum_size = Vector2(COL_W[c], 0)
				l.clip_text = true
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if c >= 2:
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				g.add_child(l)
				row.append(l)
			trows.append(row)
		cells.append(trows)
	var hint := HudStyle.make_label("松开 ` 关闭  Release ` to close", 12, HudStyle.C_TEXT_DIM, false, 3)
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
				"uid": f.uid, "name": f.display_name, "cls": HudStyle.class_name_of(f), "team": f.team,
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
			"uid": int(uid), "name": str(s.get("name", "?")), "team": int(s.get("team", 0)),
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
		(team_titles[team] as Label).visible = show
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
			if not has:
				continue
			row_count += 1
			var e: Dictionary = arr[r]
			var name_l: Label = row[0]
			name_l.text = ("> " if e["me"] else "") + str(e["name"]) + ("  (阵亡)" if e["dead"] else "")
			name_l.add_theme_color_override("font_color", HudStyle.C_GOLD if e["me"] else HudStyle.C_TEXT)
			(row[1] as Label).text = str(e["cls"])
			(row[1] as Label).add_theme_color_override("font_color", e["color"])
			(row[2] as Label).text = str(e["kills"])
			(row[3] as Label).text = str(e["deaths"])
			(row[4] as Label).text = HudStyle.fmt_num(float(e["damage"]))
			(row[5] as Label).text = HudStyle.fmt_num(float(e["healing"]))
			for c in COLS.size():
				(row[c] as Label).modulate.a = 0.6 if e["dead"] else 1.0
