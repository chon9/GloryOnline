extends "res://tests/test_core_base.gd"
## SFX library test (headless): every Fx.SFX_MAP entry resolves to real streams, every sfx name used by kits /
## mobs / core / UI exists, weapon / surface resolution, bus routing, and the voice cap + priorities under a
## 10-fighter stress (two teams of 5 real class kits casting everything at once).
## Run: godot --headless --path . -s res://tests/test_audio_sfx.gd

const SCAN_DIRS: Array[String] = ["res://classes", "res://pve", "res://core", "res://ui", "res://modes"]
const STRESS_KITS: Array[String] = ["blade_master", "sharpshooter", "launcher", "elementalist", "knight",
	"cleric", "ninja", "berserker", "striker", "warlock"]

var fx: Node = null


func run_tests() -> void:
	suite_name = "audio_sfx"
	fx = root.get_node_or_null("Fx")
	check(fx != null and fx.has_method("voice_stats") and fx.has_method("ui_sfx") and fx.has_method("local_sfx"),
		"Fx autoload with the SFX API (voice_stats, ui_sfx, local_sfx, footstep)")
	if fx == null:
		return
	t_map_resolves()
	t_files_used()
	t_names_used()
	t_buses()
	await t_resolution()
	await t_voice_cap()
	await t_stress()


func _map() -> Dictionary:
	return fx.get("SFX_MAP")


## Every entry: aliases / layers point at existing entries, every file exists and loads as a non-empty stream.
func t_map_resolves() -> void:
	var m := _map()
	var bad: Array[String] = []
	var files_ok := 0
	for k: StringName in m:
		var e: Dictionary = m[k]
		if e.has("alias") and not m.has(e["alias"]):
			bad.append("%s -> alias %s" % [k, e["alias"]])
		for l: Variant in e.get("layers", []):
			if not m.has(l):
				bad.append("%s -> layer %s" % [k, l])
		var files: Array = fx.call("sfx_files", k)
		if files.is_empty() and k != &"none":
			bad.append("%s: no files" % k)
		for f: String in files:
			var p: String = fx.get("SFX_DIR") + f
			var st: Variant = load(p) if ResourceLoader.exists(p) else null
			if not (st is AudioStream) or (st as AudioStream).get_length() <= 0.0:
				bad.append("%s: %s" % [k, f])
			else:
				files_ok += 1
	check(bad.is_empty(), "every SFX_MAP entry resolves to existing streams (%d files)" % files_ok, str(bad))
	check(m.size() >= 150, "rich vocabulary (%d names)" % m.size())
	var tables: Array = [fx.get("AREA_SFX").values(), fx.get("SURFACE_BY_MAP").values(), fx.get("GENERIC_SHOT_BY_WEAPON").values()]
	for g: Variant in (fx.get("GENERIC_SFX") as Dictionary).values():
		tables.append((g as Dictionary).values())
	var miss: Array[String] = []
	for vals: Array in tables:
		for v: Variant in vals:
			if not m.has(v):
				miss.append(str(v))
	check(miss.is_empty(), "weapon / surface / area tables only name existing sounds", str(miss))


## No orphan files: every .ogg under assets/sfx is used by some entry, no loose files in the root.
func t_files_used() -> void:
	var used: Dictionary = {}
	for k: StringName in _map():
		for f: String in fx.call("sfx_files", k):
			used[f] = true
	var on_disk: Array[String] = []
	_walk("res://assets/sfx", "", on_disk)
	var orphans: Array[String] = []
	var loose: Array[String] = []
	for f in on_disk:
		if not f.ends_with(".ogg") and not f.ends_with(".wav"):
			continue
		if not "/" in f:
			loose.append(f)
		if not used.has(f):
			orphans.append(f)
	check(on_disk.size() >= 300, "SFX library present (%d files)" % on_disk.size())
	check(orphans.is_empty(), "no unused sfx files on disk", str(orphans.slice(0, 10)))
	check(loose.is_empty(), "no loose files in assets/sfx root (old placeholders removed)", str(loose))


func _walk(dir: String, rel: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		out.append(rel + f)
	for sub in d.get_directories():
		_walk(dir + "/" + sub, rel + sub + "/", out)


func _gd_files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_gd_files(dir + "/" + sub, out)


## Every sfx name written in kits, mob defs, core, modes and UI scripts (sfx steps, projectile "sfx" keys,
## direct Fx.sfx / local_sfx / ui_sfx calls, "ui_sfx" button metas) and in Fx's own effect hooks exists.
func t_names_used() -> void:
	var m := _map()
	var pats: Array[RegEx] = []
	for s in ['"type": "sfx", "name": "([a-z_0-9]+)"', '"sfx": "([a-z_0-9]+)"',
			'fx\\(&"(?:sfx|local_sfx)", \\[&"([a-z_0-9]+)"', 'ui_sfx", &"([a-z_0-9]+)"', 'return &"((?:vo|ui|crowd)_[a-z_0-9]+)"']:
		var r := RegEx.new()
		r.compile(s)
		pats.append(r)
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_gd_files(d, files)
	var names: Dictionary = {}
	for p in files:
		var txt := FileAccess.get_file_as_string(p)
		for r in pats:
			for mt in r.search_all(txt):
				names[StringName(mt.get_string(1))] = p.get_file()
	# Fx's own automatic sounds (effect / area / hit hooks)
	var fxsrc := FileAccess.get_file_as_string("res://autoload/fx.gd")
	for s in ['\\bs = &"([a-z_0-9]+)"', '_do_sfx\\(&"([a-z_0-9]+)"', 'nm = &"([a-z_0-9]+)"', 'ui_sfx\\(&"([a-z_0-9]+)"']:
		var r := RegEx.new()
		r.compile(s)
		for mt in r.search_all(fxsrc):
			names[StringName(mt.get_string(1))] = "fx.gd"
	var missing: Array[String] = []
	for n: StringName in names:
		if not m.has(n):
			missing.append("%s (%s)" % [n, names[n]])
	check(names.size() >= 80, "scanned sfx names in game code (%d distinct)" % names.size())
	check(missing.is_empty(), "every sfx name used in classes/ pve/ core/ modes/ ui/ and Fx hooks resolves", str(missing))
	# announcer mapping of the match announcements
	var ann: Script = load("res://ui/hud_announce.gd")
	var cases := {"3": &"vo_3", "开始 Fight!": &"vo_fight", "第2回合 Round 2": &"vo_round_2", "时间到 Time up!": &"vo_time",
		"平局 Draw": &"vo_tie", "红队 获胜 Victory!": &"", "第5回合 Round 5": &"vo_final_round", "hello": &""}
	var wrong: Array[String] = []
	for t: String in cases:
		var got: StringName = ann.call("announce_sfx", t)
		if got != cases[t] or (got != &"" and not m.has(got)):
			wrong.append("%s -> %s" % [t, got])
	check(wrong.is_empty(), "announcer lines for countdown / fight / rounds / time / draw / victory", str(wrong))


## Positional voices go to the SFX bus, UI sounds to the UI bus (Master when the bus layout lacks them).
func t_buses() -> void:
	fx.call("local_sfx", &"hit_blunt", Vector3(1, 1, 1))
	fx.call("ui_sfx", &"ui_click")
	var sfx_bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	var ui_bus := &"UI" if AudioServer.get_bus_index(&"UI") >= 0 else &"Master"
	var v3: Array = fx.get("_voices")
	var vu: Array = fx.get("_ui_voices")
	var ok3 := not v3.is_empty()
	for v: AudioStreamPlayer3D in v3:
		if v.stream != null and v.bus != sfx_bus:
			ok3 = false
	var oku := not vu.is_empty()
	var any_ui := false
	for u: AudioStreamPlayer in vu:
		if u.stream != null:
			any_ui = true
			if u.bus != ui_bus:
				oku = false
	check(ok3, "positional SFX routed to bus %s" % sfx_bus)
	check(oku and any_ui, "UI sounds non-positional on bus %s" % ui_bus)
	if FileAccess.file_exists("res://default_bus_layout.tres"):
		check(AudioServer.get_bus_index(&"SFX") >= 0 and AudioServer.get_bus_index(&"UI") >= 0
			and AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"Ambience") >= 0,
			"default_bus_layout.tres provides Music / SFX / UI / Ambience buses")
	var cheer: Dictionary = _map()[&"crowd_cheer"]
	check(bool(cheer.get("ui", false)) and StringName(cheer.get("bus", "")) == &"SFX", "crowd cheer is non-positional on the SFX bus")


## Generic names resolve per caster weapon; footsteps per map surface.
func t_resolution() -> void:
	await new_world()
	var cases := {"blade_master": [&"swing", &"swing_saber"], "sharpshooter": [&"shot", &"gun_revolver"],
		"spitfire": [&"shot", &"gun_pistol"], "mechanic": [&"shot", &"gun_rifle"], "ninja": [&"hit", &"hit_blade"],
		"berserker": [&"hit_heavy", &"hit_blade_heavy"], "striker": [&"hit", &"hit_blunt"], "grappler": [&"hit", &"hit_wood"],
		"battle_mage": [&"swing", &"swing_spear"], "ghostblade": [&"slash", &"swing_katana"], "elementalist": [&"shot", &"magic_bolt"]}
	var bad: Array[String] = []
	var x := 0.0
	for cid: String in cases:
		var f := world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": cid, "team": 0, "name": cid, "pos": Vector3(x, 0, 0)})
		x += 2.0
		if f == null:
			bad.append(cid + ": spawn")
			continue
		var c: Array = cases[cid]
		var got: StringName = fx.call("_resolve_sfx", c[0], f.uid)
		if got != c[1]:
			bad.append("%s %s -> %s" % [cid, c[0], got])
	check(bad.is_empty(), "generic sounds resolve to the caster's weapon", str(bad))
	check(fx.call("_resolve_sfx", &"swing", 0) == &"swing", "no caster -> generic name kept (alias)")
	check(fx.call("_surface_sfx") == &"footstep_stone", "footsteps default to stone without a map")


## Voice allocation: global cap, per-name polyphony, priorities (ultimates / boss steal from footsteps).
func t_voice_cap() -> void:
	fx.call("clear_all")
	var cap: int = fx.get("MAX_VOICES")
	for i in 40:
		fx.call("local_sfx", &"footstep_stone", Vector3(i * 3.0, 0, 0))
	var st: Dictionary = fx.call("voice_stats")
	check(int(st["active"]) <= cap, "global voice cap holds (%d/%d)" % [st["active"], cap])
	check(int((st["by_name"] as Dictionary).get(&"footstep_stone", 0)) <= 6, "footstep polyphony <= 6")
	for i in 30:
		fx.call("local_sfx", &"hit_blunt", Vector3(i * 3.0, 0, 10))
	st = fx.call("voice_stats")
	check(int((st["by_name"] as Dictionary).get(&"hit_blunt", 0)) <= 5, "hit polyphony <= 5 (%d)" % int((st["by_name"] as Dictionary).get(&"hit_blunt", 0)))
	# fill the pool with low-priority sounds of many names, then an ultimate must still get a voice
	for i in 60:
		var n: StringName = [&"footstep_grass", &"footstep_snow", &"footstep_dirt", &"cloth_soft", &"shade_soft", &"bell_soft"][i % 6]
		fx.call("local_sfx", n, Vector3(i * 2.5, 0, 20))
	st = fx.call("voice_stats")
	var before: int = (fx.get("sfx_stats") as Dictionary)["played"]
	fx.call("local_sfx", &"ultimate_charge", Vector3(0, 0, 30))
	st = fx.call("voice_stats")
	check(int((st["by_name"] as Dictionary).get(&"ultimate_charge", 0)) == 1 and int(st["active"]) <= cap,
		"ultimate takes a voice from low-priority sounds when the pool is full")
	check(int((fx.get("sfx_stats") as Dictionary)["played"]) > before, "ultimate played")
	# same sound twice in 30 ms at one spot is de-duplicated
	var d0: int = (fx.get("sfx_stats") as Dictionary)["deduped"]
	fx.call("local_sfx", &"gun_cannon", Vector3(50, 0, 50))
	fx.call("local_sfx", &"gun_cannon", Vector3(50, 0, 50))
	check(int((fx.get("sfx_stats") as Dictionary)["deduped"]) > d0, "same-sound spam guard")
	# UI pool
	for i in 20:
		fx.call("ui_sfx", &"ui_click")
	st = fx.call("voice_stats")
	check(int(st["ui_active"]) <= 6, "UI voice pool capped")
	fx.call("clear_all")
	check(int((fx.call("voice_stats") as Dictionary)["active"]) == 0, "clear_all releases every voice")


## 10 fighters (5 v 5, real kits) cast every skill repeatedly for 4 s: no errors, cap respected every step.
func t_stress() -> void:
	await new_world()
	fx.call("clear_all")
	var fs: Array[Fighter] = []
	for i in STRESS_KITS.size():
		var team := i % 2
		var f := world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": STRESS_KITS[i], "team": team,
			"name": STRESS_KITS[i], "pos": Vector3(float(i / 2) * 1.5 - 3.0, 0, -1.2 if team == 0 else 1.2),
			"yaw": 0.0 if team == 0 else PI})
		if f != null:
			fs.append(f)
	check(fs.size() == 10, "10 stress fighters spawned")
	var cap: int = fx.get("MAX_VOICES")
	var played0: int = (fx.get("sfx_stats") as Dictionary)["played"]
	var worst := 0
	var over_name: Array[String] = []
	var m := _map()
	for step in 240:
		for f in fs:
			if is_instance_valid(f) and f.is_alive():
				f.hp = f.max_hp
				f.mp = f.get_stat("mp")
				f.reset_cooldowns()
				for slot in 8:
					if f.try_cast((step / 3 + slot) % 8):
						break
		await sim(DT)
		var st: Dictionary = fx.call("voice_stats")
		worst = maxi(worst, int(st["active"]))
		for n: Variant in st["by_name"]:
			var r: Array = fx.call("_sfx_entry", n)
			var mx := int((r[1] as Dictionary).get("max", 4))
			if int(st["by_name"][n]) > mx and not over_name.has(str(n)):
				over_name.append("%s=%d>%d" % [n, st["by_name"][n], mx])
	var stats: Dictionary = fx.get("sfx_stats")
	print("  stress: played %d, dropped %d, stolen %d, deduped %d, peak voices %d/%d" % [
		int(stats["played"]) - played0, stats["dropped"], stats["stolen"], stats["deduped"], worst, cap])
	check(int(stats["played"]) - played0 > 50, "stress produced plenty of sounds")
	check(worst <= cap, "voice cap respected under 10-fighter stress (peak %d/%d)" % [worst, cap])
	check(over_name.is_empty(), "per-name polyphony respected under stress", str(over_name))
	fx.call("clear_all")
