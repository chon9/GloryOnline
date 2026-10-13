extends "res://tests/test_ai_base.gd"
## Balancing matrix: every available kit vs every other kit, bot vs bot (difficulty 2 by default). Each pairing is
## fought `reps` times (default 2) with sides mirrored on alternate reps, 180 s cap. Prints a win-rate grid, per-kit
## win rate, average time-to-kill and the skill slots the AI never cast, plus one machine-readable line per fight:
##   MATCHRES|a|b|winner(0=a,1=b,-1 draw)|time|dmgA|dmgB|swap|hp%A|hp%B (hp left at the end)
## Team mode (--team) fights 3v3 comps instead: support comps (tank + healer + dps) vs 3-dps comps, both sides:
##   TEAMRES|a1,a2,a3|b1,b2,b3|winner|time|swap
## User args (after `--`): --diff=N --cap=S --reps=N --kits=a,b,c --shard=i/n (pairing index % n == i) --scale=X
## (sets Game.settings.pvp_damage_scale for this run) --team --strict (fail when the §6 balance targets are missed;
## only meaningful for an unsharded full run). Env fallbacks: AI_MATRIX_DIFF, AI_MATRIX_CAP, AI_MATRIX_KITS.

const SUPPORT_COMPS: Array = [
	["knight", "cleric", "blade_master"],
	["paladin", "cleric", "sharpshooter"],
	["knight", "paladin", "elementalist"],
	["knight", "cleric", "assassin"],
]
const DPS_COMPS: Array = [
	["blade_master", "elementalist", "sharpshooter"],
	["berserker", "assassin", "launcher"],
	["striker", "battle_mage", "spitfire"],
	["ninja", "ghostblade", "qi_master"],
]

var _casts: Dictionary = {}      # kit id -> PackedInt32Array(8)
var _diff: int = 2
var _cap: float = 180.0
var _reps: int = 2
var _shard: int = 0
var _shards: int = 1
var _strict: bool = false
var _team: bool = false


func _parse_args() -> Array[String]:
	if OS.get_environment("AI_MATRIX_DIFF") != "":
		_diff = int(OS.get_environment("AI_MATRIX_DIFF"))
	if OS.get_environment("AI_MATRIX_CAP") != "":
		_cap = float(OS.get_environment("AI_MATRIX_CAP"))
	var kit_list := OS.get_environment("AI_MATRIX_KITS")
	# Fight at the shipped default PvP scale even if a shared harness pinned another value (--scale overrides).
	var game := root.get_node_or_null("Game")
	var game_script := load("res://autoload/game.gd") as Script
	if game != null and game_script != null:
		var defaults: Variant = game_script.get_property_default_value("settings")
		if defaults is Dictionary and (defaults as Dictionary).has("pvp_damage_scale"):
			(game.get("settings") as Dictionary)["pvp_damage_scale"] = float((defaults as Dictionary)["pvp_damage_scale"])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--diff="):
			_diff = int(a.get_slice("=", 1))
		elif a.begins_with("--cap="):
			_cap = float(a.get_slice("=", 1))
		elif a.begins_with("--reps="):
			_reps = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--kits="):
			kit_list = a.get_slice("=", 1)
		elif a.begins_with("--shard="):
			var v := a.get_slice("=", 1)
			_shard = int(v.get_slice("/", 0))
			_shards = maxi(1, int(v.get_slice("/", 1)))
		elif a.begins_with("--scale="):
			var g := root.get_node_or_null("Game")
			if g != null:
				(g.get("settings") as Dictionary)["pvp_damage_scale"] = float(a.get_slice("=", 1))
		elif a == "--strict":
			_strict = true
		elif a == "--team":
			_team = true
	var kits := available_kits()
	if kit_list != "":
		kits.clear()
		for id: String in kit_list.split(",", false):
			if reg.call("has_kit", id.strip_edges()):
				kits.append(id.strip_edges())
	return kits


func run_tests() -> void:
	suite_name = "matrix"
	var kits := _parse_args()
	print("AI MATRIX: pvp_damage_scale %.3f" % float(CoreUtil.setting("pvp_damage_scale", 1.0)))
	if _team:
		await _run_team()
		return
	var n := kits.size()
	var pairings: Array = []
	var idx := 0
	for i in n:
		for j in range(i + 1, n):
			if idx % _shards == _shard:
				pairings.append([kits[i], kits[j]])
			idx += 1
	print("AI MATRIX: %d kits, difficulty %d, cap %.0f s, %d pairings x %d reps (shard %d/%d)" % [n, _diff, _cap,
		pairings.size(), _reps, _shard, _shards])
	for id: String in kits:
		var arr := PackedInt32Array()
		arr.resize(8)
		_casts[id] = arr
	var grid: Dictionary = {}     # "a|b" -> [wins, losses, draws] from a's view
	var stats: Dictionary = {}
	for id: String in kits:
		stats[id] = {"w": 0, "l": 0, "d": 0, "ttk": 0.0, "ttk_n": 0, "dmg": 0.0, "fights": 0}
	var t0 := Time.get_ticks_msec()
	var fight := 0
	for p: Array in pairings:
		var a: String = p[0]
		var b: String = p[1]
		for rep in _reps:
			BotBrain.rng_seed = 9000 + fight * 7 + rep
			Combat.seed_rng(777 + fight)
			var swap := rep % 2 == 1
			var r: Dictionary = await _fight(a, b, _diff, _cap, swap)
			fight += 1
			var w := int(r["winner"])
			var ra := "D"
			var rb := "D"
			if w == 0:
				ra = "W"
				rb = "L"
			elif w == 1:
				ra = "L"
				rb = "W"
			print("MATCHRES|%s|%s|%d|%.2f|%.0f|%.0f|%d|%.3f|%.3f" % [a, b, w, float(r["time"]), float((r["dmg"] as Array)[0]),
				float((r["dmg"] as Array)[1]), 1 if swap else 0, float((r["hp"] as Array)[0]), float((r["hp"] as Array)[1])])
			_grid_add(grid, a + "|" + b, ra)
			_grid_add(grid, b + "|" + a, rb)
			_acc(stats[a], ra, r, 0)
			_acc(stats[b], rb, r, 1)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	_print_grid(kits, grid)
	_print_summary(kits, stats)
	print("AI MATRIX: done in %.1f s real time" % secs)
	check(fight == pairings.size() * _reps and n >= 2, "matrix completed", "%d fights" % fight)
	if _strict and _shards == 1:
		_check_targets(kits, stats)


func _grid_add(grid: Dictionary, key: String, res: String) -> void:
	var g: Array = grid.get(key, [0, 0, 0])
	match res:
		"W":
			g[0] += 1
		"L":
			g[1] += 1
		_:
			g[2] += 1
	grid[key] = g


func _check_targets(kits: Array[String], stats: Dictionary) -> void:
	var ttk := 0.0
	var ttk_n := 0
	for id: String in kits:
		var s: Dictionary = stats[id]
		ttk += float(s["ttk"])
		ttk_n += int(s["ttk_n"])
		var wr := float(s["w"]) / maxf(1.0, float(s["fights"]))
		var lo := 0.25 if kit_role(id) in ["tank", "healer"] else 0.30
		check(wr >= lo and wr <= 0.70, "win rate in range: " + id, "%.0f%%" % (100.0 * wr))
	var avg := ttk / maxf(1.0, float(ttk_n))
	check(avg >= 60.0 and avg <= 120.0, "average TTK 60-120 s", "%.1f s" % avg)


func _acc(s: Dictionary, res: String, r: Dictionary, side: int) -> void:
	s["fights"] = int(s["fights"]) + 1
	match res:
		"W":
			s["w"] = int(s["w"]) + 1
		"L":
			s["l"] = int(s["l"]) + 1
		_:
			s["d"] = int(s["d"]) + 1
	if res != "D":
		s["ttk"] = float(s["ttk"]) + float(r["time"])
		s["ttk_n"] = int(s["ttk_n"]) + 1
	s["dmg"] = float(s["dmg"]) + float((r["dmg"] as Array)[side])


## One fight; side 0 is kit `a`. Returns {winner (0 = a, 1 = b, -1 draw), time, dmg: [a, b]}.
func _fight(a: String, b: String, diff: int, cap: float, swap: bool) -> Dictionary:
	await new_world()
	var pa := Vector3(0, 0, 6) if not swap else Vector3(0, 0, -6)
	var pb := -pa
	var fa := spawn_bot(a, 0, pa, diff)
	var fb := spawn_bot(b, 1, pb, diff)
	fa.skill_cast.connect(_on_cast.bind(a))
	fb.skill_cast.connect(_on_cast.bind(b))
	await physics_frame
	var steps := 0
	for i in roundi(cap / DT):
		world.step(DT)
		steps += 1
		if not fa.is_alive() or not fb.is_alive():
			break
	var winner := -1
	if fa.is_alive() and not fb.is_alive():
		winner = 0
	elif fb.is_alive() and not fa.is_alive():
		winner = 1
	return {"winner": winner, "time": float(steps) * DT, "dmg": [fa.damage_dealt, fb.damage_dealt],
		"hp": [maxf(0.0, fa.hp) / maxf(1.0, fa.max_hp), maxf(0.0, fb.hp) / maxf(1.0, fb.max_hp)]}


# ================================================================== 3v3
func _run_team() -> void:
	var fights: Array = []
	var idx := 0
	for s: Array in SUPPORT_COMPS:
		for d: Array in DPS_COMPS:
			for rep in _reps:
				if idx % _shards == _shard:
					fights.append([s, d, rep % 2 == 1])
				idx += 1
	print("AI MATRIX [team]: %d fights, difficulty %d, cap %.0f s (shard %d/%d)" % [fights.size(), _diff, _cap, _shard, _shards])
	var sup_w := 0
	var dps_w := 0
	var draws := 0
	var ttk := 0.0
	var ttk_n := 0
	var n := 0
	for f: Array in fights:
		BotBrain.rng_seed = 5000 + n * 13
		Combat.seed_rng(555 + n)
		var r: Dictionary = await _team_fight(f[0], f[1], bool(f[2]))
		n += 1
		var w := int(r["winner"])
		if w == 0:
			sup_w += 1
		elif w == 1:
			dps_w += 1
		else:
			draws += 1
		if w >= 0:
			ttk += float(r["time"])
			ttk_n += 1
		print("TEAMRES|%s|%s|%d|%.2f|%d" % [",".join(f[0]), ",".join(f[1]), w, float(r["time"]), 1 if bool(f[2]) else 0])
	var avg := ttk / maxf(1.0, float(ttk_n))
	print("AI MATRIX [team]: support %d, dps %d, draws %d, avg resolve %.1f s" % [sup_w, dps_w, draws, avg])
	check(n == fights.size() and n > 0, "team matrix completed", "%d fights" % n)
	if _strict and _shards == 1:
		check(avg >= 60.0 and avg <= 150.0, "3v3 resolves in 60-150 s", "%.1f s" % avg)
		var wr := float(sup_w) / maxf(1.0, float(sup_w + dps_w))
		check(wr >= 0.35 and wr <= 0.70, "support comp competitive", "%.0f%%" % (100.0 * wr))


## Side 0 is comp `ta`. Winner = side with the last living member (draw at cap when both stand).
func _team_fight(ta: Array, tb: Array, swap: bool) -> Dictionary:
	await new_world()
	var za := 8.0 if not swap else -8.0
	var fa: Array[Fighter] = []
	var fb: Array[Fighter] = []
	for i in ta.size():
		fa.append(spawn_bot(str(ta[i]), 0, Vector3(-3.0 + 3.0 * i, 0, za), _diff))
	for i in tb.size():
		fb.append(spawn_bot(str(tb[i]), 1, Vector3(-3.0 + 3.0 * i, 0, -za), _diff))
	await physics_frame
	var steps := 0
	var alive_a := ta.size()
	var alive_b := tb.size()
	for i in roundi(_cap / DT):
		world.step(DT)
		steps += 1
		alive_a = _alive(fa)
		alive_b = _alive(fb)
		if alive_a == 0 or alive_b == 0:
			break
	var winner := -1
	if alive_a > 0 and alive_b == 0:
		winner = 0
	elif alive_b > 0 and alive_a == 0:
		winner = 1
	return {"winner": winner, "time": float(steps) * DT}


func _alive(arr: Array[Fighter]) -> int:
	var c := 0
	for f: Fighter in arr:
		if is_instance_valid(f) and f.is_alive():
			c += 1
	return c


func _on_cast(_f: Fighter, slot: int, kit_id: String) -> void:
	if not _casts.has(kit_id):
		return
	var arr: PackedInt32Array = _casts[kit_id]
	if slot >= 0 and slot < arr.size():
		arr[slot] += 1
		_casts[kit_id] = arr


func _short(id: String) -> String:
	var parts := id.split("_")
	if parts.size() >= 2:
		return (parts[0].substr(0, 3) + parts[1].substr(0, 2)).substr(0, 5)
	return id.substr(0, 5)


func _print_grid(kits: Array[String], grid: Dictionary) -> void:
	print("")
	print("Win grid (row kit vs column kit, row's wins out of the fights played; '.' = not played in this shard):")
	var header := "%-14s" % ""
	for id: String in kits:
		header += "%-6s" % _short(id)
	print(header)
	for a: String in kits:
		var line := "%-14s" % a.substr(0, 14)
		for b: String in kits:
			if a == b:
				line += "%-6s" % "-"
			elif grid.has(a + "|" + b):
				var g: Array = grid[a + "|" + b]
				line += "%-6s" % ("%d/%d" % [g[0], int(g[0]) + int(g[1]) + int(g[2])])
			else:
				line += "%-6s" % "."
		print(line)


func _print_summary(kits: Array[String], stats: Dictionary) -> void:
	print("")
	print("%-14s %-9s %5s %4s %4s %4s %8s %9s  %s" % ["kit", "role", "win%", "W", "L", "D", "avgTTK", "avgDmg", "casts slot0..7 (never-cast slots flagged)"])
	var order := kits.duplicate()
	order.sort_custom(func(x: String, y: String) -> bool:
		var sx: Dictionary = stats[x]
		var sy: Dictionary = stats[y]
		return float(sx["w"]) / maxf(1.0, float(sx["fights"])) > float(sy["w"]) / maxf(1.0, float(sy["fights"])))
	for id: String in order:
		var s: Dictionary = stats[id]
		if int(s["fights"]) == 0:
			continue
		var fights := maxi(1, int(s["fights"]))
		var arr: PackedInt32Array = _casts[id]
		var casts := ""
		var never := ""
		for k in arr.size():
			casts += "%d " % arr[k]
			if arr[k] == 0:
				never += str(k)
		print("%-14s %-9s %5.0f %4d %4d %4d %7.1fs %9.0f  %s%s" % [id.substr(0, 14), kit_role(id), 100.0 * float(s["w"]) / float(fights),
			int(s["w"]), int(s["l"]), int(s["d"]), float(s["ttk"]) / maxf(1.0, float(s["ttk_n"])), float(s["dmg"]) / float(fights),
			casts, ("" if never == "" else " NEVER:" + never)])
