extends SceneTree
## AUDIO (music) headless tests: bus layout (Master -> Music, SFX, UI, Ambience), volume prefs -> bus volumes
## (incl. the legacy "volume" key), every music slot / ambience zone resolves to an existing looping stream,
## Music.play crossfades between slots, stingers hand over to results, duck() lowers the Music bus and releases,
## raid score drives explore -> boss -> enrage, match end -> victory stinger, Game state -> lobby / menu.
## Music is local only (no RPC config).
## Run: godot --headless --path K:/Project/RONGYAO -s res://tests/test_audio_music.gd

const BUSES: Array[String] = ["Master", "Music", "SFX", "UI", "Ambience"]
const PREFS_TEST_PATH: String = "user://test_audio_settings.cfg"

var passed: int = 0
var failed: int = 0
var music: Node
var game: Node


class FakeMode:
	extends Node
	signal score_changed(score: Dictionary)
	signal match_ended(result: Dictionary)


class FakeScene:
	extends Node
	var settings: Dictionary = {}
	var map: Node
	var mode: Node


func _initialize() -> void:
	_main.call_deferred()


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


## Waits real time (Music fades run on real seconds).
func wait_secs(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _main() -> void:
	await process_frame
	music = root.get_node_or_null("Music")
	game = root.get_node_or_null("Game")
	check(music != null, "Music autoload present")
	check(game != null, "Game autoload present")
	if music != null and game != null:
		check(music.get("audible") == false, "headless run: Music not audible by default")
		music.set("audible", true)  # exercise the real players here (dummy audio driver)
		test_buses()
		test_prefs()
		test_assets()
		test_static_helpers()
		await test_play_crossfade()
		await test_stinger()
		await test_duck()
		await test_match_flow()
		music.call("stop_all")
		music.set("audible", false)
		await wait_secs(0.3)  # let the AudioServer drop the stopped playbacks before exit
	await process_frame
	print("AUDIO MUSIC TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_buses() -> void:
	check(ResourceLoader.exists("res://default_bus_layout.tres"), "default_bus_layout.tres exists")
	for b: String in BUSES:
		check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	for b: String in ["Music", "SFX", "UI", "Ambience"]:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			check(AudioServer.get_bus_send(i) == &"Master", "%s sends to Master" % b, str(AudioServer.get_bus_send(i)))
	var mi := AudioServer.get_bus_index("Music")
	var has_amp := false
	for e in AudioServer.get_bus_effect_count(mi):
		has_amp = has_amp or AudioServer.get_bus_effect(mi, e) is AudioEffectAmplify
	check(has_amp, "Music bus has the Duck amplify effect")
	var si := AudioServer.get_bus_index("SFX")
	var has_comp := false
	var has_lim := false
	for e in AudioServer.get_bus_effect_count(si):
		var fx := AudioServer.get_bus_effect(si, e)
		has_comp = has_comp or fx is AudioEffectCompressor
		has_lim = has_lim or fx is AudioEffectHardLimiter
	check(has_comp and has_lim, "SFX bus has compressor + limiter")


func test_prefs() -> void:
	var saved: Dictionary = game.prefs.duplicate()
	var saved_path: String = game.prefs_path
	game.prefs_path = PREFS_TEST_PATH
	for k: String in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambience_volume"]:
		check(game.prefs.has(k), "pref %s exists" % k)
	game.prefs["music_volume"] = 0.5
	game.prefs["sfx_volume"] = 0.25
	game.prefs["ui_volume"] = 0.0
	game.apply_prefs()
	var mdb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	check(absf(mdb - linear_to_db(0.5)) < 0.05, "music_volume -> Music bus dB", str(mdb))
	var sdb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	check(absf(sdb - linear_to_db(0.25)) < 0.05, "sfx_volume -> SFX bus dB", str(sdb))
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "ui_volume 0 mutes the UI bus")
	var adb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))
	check(adb < linear_to_db(float(game.prefs["ambience_volume"])) - 1.0, "ambience bus sits below its pref (base offset)", str(adb))
	# legacy key still drives the master volume
	game.prefs["volume"] = 0.3
	game.apply_prefs()
	check(absf(float(game.prefs["master_volume"]) - 0.3) < 0.001, "legacy volume key sets master_volume")
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.3)) < 0.05, "master bus follows the legacy key")
	game.prefs["master_volume"] = 0.6
	game.apply_prefs()
	check(absf(float(game.prefs["volume"]) - 0.6) < 0.001, "master_volume mirrors into the legacy key")
	check(game.save_prefs() == OK, "audio prefs saved")
	game.prefs["music_volume"] = 1.0
	game.prefs["master_volume"] = 1.0
	game.prefs["volume"] = 1.0
	game.load_prefs()
	check(absf(float(game.prefs["music_volume"]) - 0.5) < 0.001 and absf(float(game.prefs["master_volume"]) - 0.6) < 0.001,
		"audio prefs reload", "%s %s" % [game.prefs["music_volume"], game.prefs["master_volume"]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS_TEST_PATH))
	game.prefs_path = saved_path
	game.prefs = saved
	game.apply_prefs()


func test_assets() -> void:
	var playlists: Dictionary = music.PLAYLISTS
	var stingers: Array = music.STINGERS
	var total := 0
	for slot: String in playlists:
		var paths: Array = music.call("track_paths", slot)
		check(not paths.is_empty(), "slot %s has tracks" % slot)
		for p: String in paths:
			total += 1
			var s := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
			if s == null:
				check(false, "stream loads: " + p)
				continue
			if s.get_length() <= 0.5:
				check(false, "stream has length: " + p, str(s.get_length()))
			var want_loop := not stingers.has(slot)
			if "loop" in s and bool(s.get("loop")) != want_loop:
				check(false, "loop flag (%s) on %s" % [want_loop, p])
	check(total >= 20, "music tracks found", str(total))
	for p: String in music.call("ambience_paths"):
		var s := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
		check(s != null and bool(s.get("loop")), "ambience loops: " + p)
	for slot: String in ["menu", "lobby", "battle_pvp", "battle_arena", "raid_explore_frost_forest",
			"raid_explore_boneyard", "raid_boss_frost_golem", "raid_boss_black_knight", "raid_boss_enrage",
			"victory", "defeat", "results"]:
		check(playlists.has(slot), "required slot " + slot)
	var cfg: Variant = (music.get_script() as Script).get_rpc_config()
	check(cfg == null or (cfg is Dictionary and (cfg as Dictionary).is_empty()), "Music has no RPCs (local only)", str(cfg))


func test_static_helpers() -> void:
	check(music.call("match_slot", "duel", "") == "battle_pvp", "duel -> battle_pvp")
	check(music.call("match_slot", "team", "") == "battle_pvp", "team -> battle_pvp")
	check(music.call("match_slot", "arena", "") == "battle_arena", "arena -> battle_arena")
	check(music.call("match_slot", "raid", "boneyard") == "raid_explore_boneyard", "raid -> explore slot")
	check(music.call("raid_slot", "frost_forest", 1) == "raid_boss_frost_golem", "frost forest boss slot")
	check(music.call("raid_slot", "boneyard", 1) == "raid_boss_black_knight", "boneyard boss slot")
	check(music.call("raid_slot", "boneyard", 2) == "raid_boss_enrage", "enrage slot")
	check(music.call("resolve_slot", "raid_boss_unknown") == "raid_boss_black_knight", "unknown boss falls back")
	check(music.call("resolve_slot", "nonsense") == "menu", "unknown slot falls back to menu")


func test_play_crossfade() -> void:
	music.call("stop_all")
	var p1: String = music.call("play", "menu")
	check(p1.ends_with("menu/mountain_emperor.ogg"), "menu plays its first choice", p1)
	check(music.get("current_slot") == "menu", "current slot menu")
	var again: String = music.call("play", "menu")
	check(again == p1, "same slot does not restart")
	await wait_secs(0.3)
	var p2: String = music.call("play", "battle_pvp")
	check(p2.contains("battle_pvp/"), "battle_pvp track chosen", p2)
	await wait_secs(0.5)
	var players: Array = music.get("_players")
	var gains: Array = music.get("_gain")
	var act: int = music.get("_active")
	check((players[act] as AudioStreamPlayer).playing and float(gains[act]) > 0.1 and float(gains[act]) < 1.0,
		"incoming track fading in", str(gains))
	check(float(gains[1 - act]) < 1.0, "outgoing track fading out", str(gains))
	await wait_secs(1.6)
	gains = music.get("_gain")
	check(is_equal_approx(float(gains[act]), 1.0) and float(gains[1 - act]) <= 0.0, "crossfade completes", str(gains))
	check(not (players[1 - act] as AudioStreamPlayer).playing, "old track stopped")
	check(((players[act] as AudioStreamPlayer).bus) == &"Music", "music plays on the Music bus")
	var p3: String = music.call("play", "battle_pvp", true)
	check(p3 != p2, "restart rotates the playlist", p3)


func test_stinger() -> void:
	var sp: String = music.call("play_stinger", "victory", "results")
	check(sp.contains("victory/"), "victory stinger chosen", sp)
	check(music.get("stinger_slot") == "victory" and music.get("current_slot") == "", "stinger state")
	await wait_secs(0.6)
	var gains: Array = music.get("_gain")
	check(float(gains[0]) <= 0.0 and float(gains[1]) <= 0.0, "loop faded out under the stinger", str(gains))
	music.call("_on_stinger_finished")
	check(music.get("current_slot") == "results", "results follow the stinger", str(music.get("current_slot")))
	var dp: String = music.call("play", "defeat")
	check(dp.contains("defeat/"), "play(defeat) routes to a stinger", dp)
	music.call("play", "lobby")
	check(music.get("stinger_slot") == "" and music.get("current_slot") == "lobby", "play() cancels a stinger")


func test_duck() -> void:
	music.call("duck", -10.0, 0.4)
	await wait_secs(0.25)
	var lvl: float = music.call("duck_level")
	check(lvl < -6.0, "duck lowers the Music bus", str(lvl))
	var mi := AudioServer.get_bus_index("Music")
	var amp_db := 0.0
	for e in AudioServer.get_bus_effect_count(mi):
		var fx := AudioServer.get_bus_effect(mi, e)
		if fx is AudioEffectAmplify:
			amp_db = (fx as AudioEffectAmplify).volume_db
	check(amp_db < -6.0, "Duck effect follows", str(amp_db))
	await wait_secs(1.5)
	lvl = music.call("duck_level")
	check(is_equal_approx(lvl, 0.0), "duck releases", str(lvl))


func test_match_flow() -> void:
	var scene := FakeScene.new()
	scene.settings = {"mode": "raid", "raid_id": "frost_forest"}
	scene.map = Node.new()
	scene.map.set_meta("env_zone", "frost")
	scene.mode = FakeMode.new()
	scene.add_child(scene.map)
	scene.add_child(scene.mode)
	root.add_child(scene)
	music.call("enter_match", scene)
	check(music.get("current_slot") == "raid_explore_frost_forest", "raid start -> explore track", str(music.get("current_slot")))
	check(str(music.get("ambience_path")).ends_with("winter_wind.ogg"), "frost zone ambience", str(music.get("ambience_path")))
	await wait_secs(0.3)
	var amb: AudioStreamPlayer = music.get("_amb")
	check(amb.playing and amb.bus == &"Ambience", "ambience plays on the Ambience bus")
	check(float(music.get("_amb_target")) == 1.0, "ambience fades in")
	var m: FakeMode = scene.mode
	m.score_changed.emit({"mode": "raid", "boss_uid": 0, "state": "active", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_explore_frost_forest", "trash encounter keeps explore music")
	m.score_changed.emit({"mode": "raid", "boss_uid": 42, "state": "idle", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_explore_frost_forest", "idle boss keeps explore music")
	m.score_changed.emit({"mode": "raid", "boss_uid": 42, "state": "active", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_boss_frost_golem", "boss engage -> boss track", str(music.get("current_slot")))
	m.score_changed.emit({"mode": "raid", "boss_uid": 42, "state": "active", "phase": 1, "enraged": false})
	await wait_secs(0.2)
	check(float(music.call("duck_level")) < -3.0, "phase change ducks the music")
	m.score_changed.emit({"mode": "raid", "boss_uid": 42, "state": "active", "phase": 1, "enraged": true})
	check(music.get("current_slot") == "raid_boss_enrage", "enrage -> enrage track")
	m.score_changed.emit({"mode": "raid", "boss_uid": 0, "state": "idle", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_explore_frost_forest", "wipe reset -> explore track")
	# Final boss dies: MatchRaid sends cleared / done scores before match_ended -> no blip back to explore.
	m.score_changed.emit({"mode": "raid", "encounter": 2, "encounters": 3, "boss_uid": 42, "state": "active", "phase": 1, "enraged": true})
	m.score_changed.emit({"mode": "raid", "encounter": 2, "encounters": 3, "boss_uid": 0, "state": "cleared", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_boss_enrage", "final boss cleared keeps the boss track", str(music.get("current_slot")))
	m.score_changed.emit({"mode": "raid", "encounter": 3, "encounters": 3, "boss_uid": 0, "state": "done", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_boss_enrage", "raid done keeps the boss track until the stinger", str(music.get("current_slot")))
	m.score_changed.emit({"mode": "raid", "encounter": 0, "encounters": 3, "boss_uid": 0, "state": "cleared", "phase": 0, "enraged": false})
	check(music.get("current_slot") == "raid_explore_frost_forest", "earlier encounter cleared -> explore track", str(music.get("current_slot")))
	m.match_ended.emit({"winner_team": 0})
	check(music.get("stinger_slot") == "victory", "match won -> victory stinger", str(music.get("stinger_slot")))
	# Game state back to the lobby: lobby music, ambience fades out, mode hooks dropped
	music.call("_on_game_state", 1)
	check(music.get("current_slot") == "lobby" and music.get("ambience_path") == "", "lobby state -> lobby music, no ambience")
	check(not m.score_changed.is_connected(Callable(music, "_on_score")), "mode signals disconnected")
	music.call("_on_game_state", 0)
	check(music.get("current_slot") == "menu", "menu state -> menu music")
	# PvP: defeat when the other team wins
	var scene2 := FakeScene.new()
	scene2.settings = {"mode": "arena"}
	scene2.map = Node.new()
	scene2.map.set_meta("env_zone", "lava")
	scene2.mode = FakeMode.new()
	scene2.add_child(scene2.map)
	scene2.add_child(scene2.mode)
	root.add_child(scene2)
	music.call("enter_match", scene2)
	check(music.get("current_slot") == "battle_arena" and str(music.get("ambience_path")).ends_with("volcano.ogg"), "arena track + lava ambience")
	scene.queue_free()
	scene2.queue_free()
	await process_frame
