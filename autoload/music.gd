extends Node
## Autoload "Music" (owner: AUDIO): local music + ambience director. Purely local on every peer: no RPCs,
## no replicated state; each peer derives what to play from Game.state and the match mode's own signals
## (score_changed / match_ended are already broadcast to every peer by the host).
##
## Slots (PLAYLISTS): menu, lobby, battle_pvp, battle_arena, raid_explore_<raid id>, raid_boss_<boss id>,
## raid_boss_enrage, victory, defeat (stingers), results. play(slot) crossfades (CROSSFADE s) to the next track
## of the slot's playlist (rotation; the first play of a slot uses its first track). A track crossfades into the
## next one of its playlist shortly before it ends (single-track playlists crossfade into themselves); the
## streams are imported with loop=true as a safety net. Stingers fade the loop out, play once, then continue
## with `after` (default: results). duck(db, seconds) lowers the Music bus (its "Duck" AudioEffectAmplify)
## for ultimates / boss announcements. Ambience loops (Ambience bus) follow the map's EnvKit zone.
##
## Wiring: Game.state_changed (menu / lobby / leaving a match), ui/main_menu.gd sync_to_game() on open,
## modes/match_scene.gd enter_match(scene) (match track + ambience + mode signals: raid boss engage, enrage,
## phase announcements, victory / defeat -> results).

signal track_changed(slot: String, path: String)

const MUSIC_DIR: String = "res://assets/music/"
const AMBIENCE_DIR: String = "res://assets/ambience/"
const MUSIC_BUS: StringName = &"Music"
const AMBIENCE_BUS: StringName = &"Ambience"
const CROSSFADE: float = 1.5
const STINGER_FADE: float = 0.4
const AMBIENCE_FADE: float = 2.5
const SILENT_DB: float = -60.0
## Duck attack / release (seconds).
const DUCK_ATTACK: float = 0.12
const DUCK_RELEASE: float = 0.8
## slot -> files under MUSIC_DIR/<slot>/ (first entry = first choice). Credits: assets/CREDITS.md "Music".
const PLAYLISTS: Dictionary = {
	"menu": ["mountain_emperor.ogg", "jade_kings_throne.ogg"],
	"lobby": ["shenyang.ogg", "lotus_pond_loop.ogg", "guzheng_city.ogg"],
	"battle_pvp": ["big_mojo.ogg", "movement_proposition.ogg", "dragon_dance_loop.ogg", "undaunted.ogg"],
	"battle_arena": ["future_gladiator.ogg", "the_complex.ogg"],
	"raid_explore_frost_forest": ["the_snow_queen.ogg", "misty_mountains.ogg"],
	"raid_explore_boneyard": ["ossuary_6_air.ogg", "ossuary_1_a_beginning.ogg"],
	"raid_boss_frost_golem": ["five_armies.ogg"],
	"raid_boss_black_knight": ["final_battle_of_the_dark_wizards.ogg"],
	"raid_boss_enrage": ["black_vortex.ogg"],
	"victory": ["fanfare_a.ogg", "discovery_hit.ogg", "fanfare_b.ogg"],
	"defeat": ["death_of_a_ninja.ogg", "darkness_speaks.ogg"],
	"results": ["ishikari_lore.ogg"],
}
const STINGERS: Array[String] = ["victory", "defeat"]
## Raid id -> boss id (boss slot = "raid_boss_<boss id>").
const BOSS_BY_RAID: Dictionary = {"frost_forest": "frost_golem", "boneyard": "black_knight"}
## EnvKit zone (match_scene.ZONE_BY_MAP / map env_zone) -> ambience loop under AMBIENCE_DIR.
const AMBIENCE_BY_ZONE: Dictionary = {
	"glory_stage": "arena_crowd.ogg",
	"blossom": "forest_day.ogg",
	"golden_ruins": "mountain_wind.ogg",
	"lava": "volcano.ogg",
	"moon": "forest_night.ogg",
	"frost": "winter_wind.ogg",
}
const ZONE_BY_MAP_FALLBACK: Dictionary = {
	"classic_arena": "glory_stage",
	"hundred_blossoms": "blossom",
	"old_castle": "golden_ruins",
	"lava_cave": "lava",
	"boneyard": "moon",
	"frost_forest": "frost",
}
## Duck applied on a raid boss phase change / enrage announcement.
const ANNOUNCE_DUCK_DB: float = -9.0
const ANNOUNCE_DUCK_TIME: float = 2.5

## false: play() / ambience calls are ignored (silence everything with stop_all()).
var enabled: bool = true
## false: slots, rotation, fades and stingers still run, but no AudioStreamPlayer is started. Default off on
## headless runs (dedicated hosts, tests: no audio device, and queued playbacks would leak at exit).
var audible: bool = true
## Slot of the looping music ("" = none). A stinger in progress keeps the loop slot it will hand over to.
var current_slot: String = ""
var current_path: String = ""
var stinger_slot: String = ""
var ambience_path: String = ""
## Raid music state of the current match: 0 explore, 1 boss engaged, 2 enraged.
var raid_intensity: int = 0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _gain: Array[float] = [0.0, 0.0]
var _target: Array[float] = [0.0, 0.0]
var _stinger: AudioStreamPlayer
var _after_stinger: String = ""
var _stinger_end: float = 0.0
var _amb: AudioStreamPlayer
var _amb_gain: float = 0.0
var _amb_target: float = 0.0
var _amb_next: String = ""
var _rotation: Dictionary = {}
var _cache: Dictionary = {}
var _duck_db: float = 0.0
var _duck_target: float = 0.0
var _duck_until: float = 0.0
var _clock: float = 0.0
var _mode: Node = null
var _raid_id: String = ""
var _last_phase: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audible = DisplayServer.get_name() != "headless"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Track%d" % i
		p.bus = MUSIC_BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	_stinger.bus = MUSIC_BUS
	add_child(_stinger)
	_stinger.finished.connect(_on_stinger_finished)
	_amb = AudioStreamPlayer.new()
	_amb.name = "Ambience"
	_amb.bus = AMBIENCE_BUS
	_amb.volume_db = SILENT_DB
	add_child(_amb)
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_signal("state_changed"):
		game.connect("state_changed", _on_game_state)


func _exit_tree() -> void:
	stop_all()


# ================================================================== public API
## Crossfades to `slot` (no-op if it is already the playing loop, unless `restart`). Stinger slots are
## forwarded to play_stinger(). Unknown slots fall back (raid_boss_* -> raid_boss_black_knight,
## raid_explore_* -> raid_explore_frost_forest, else menu). Returns the chosen file path ("" = nothing).
func play(slot: String, restart: bool = false) -> String:
	if not enabled:
		return ""
	if STINGERS.has(slot):
		return play_stinger(slot)
	slot = resolve_slot(slot)
	if slot == current_slot and not restart and stinger_slot == "" and _players[_active].playing:
		return current_path
	_stop_stinger()
	var path := _next_track(slot)
	if path == "":
		return ""
	current_slot = slot
	_crossfade_to(path)
	return path


## Plays a one-shot stinger (victory / defeat): the loop fades out, then `after` starts ("" = stay silent).
func play_stinger(slot: String, after: String = "results") -> String:
	if not enabled:
		return ""
	var path := _next_track(slot)
	if path == "":
		if after != "":
			play(after)
		return ""
	_fade_all_tracks(STINGER_FADE)
	current_slot = ""
	current_path = ""
	stinger_slot = slot
	_after_stinger = after
	_stinger.stream = _load(path, false)
	_stinger.volume_db = 0.0
	_stinger_end = _clock + (_stinger.stream.get_length() if _stinger.stream != null else 0.0) + 0.1
	if audible:
		_stinger.play()
	track_changed.emit(slot, path)
	return path


## Lowers the Music bus by `db` (negative) for `seconds`, then releases. Overlapping ducks keep the deepest
## level and the latest end. Used for ultimates (Fx) and boss phase / enrage announcements.
func duck(db: float, seconds: float) -> void:
	db = minf(db, 0.0)
	if _clock < _duck_until:
		_duck_target = minf(_duck_target, db)
	else:
		_duck_target = db
	_duck_until = maxf(_duck_until, _clock + maxf(seconds, 0.0))


## Ambience loop for an EnvKit zone ("" or unknown = fade out).
func set_ambience(zone: String) -> void:
	var file := str(AMBIENCE_BY_ZONE.get(zone, ""))
	set_ambience_file(AMBIENCE_DIR + file if file != "" else "")


func set_ambience_file(path: String) -> void:
	if not enabled and path != "":
		return
	if path == ambience_path:
		return
	ambience_path = path
	_amb_next = path
	_amb_target = 0.0


## Raid music intensity: 0 explore, 1 boss engaged, 2 boss enraged (crossfades to the matching slot).
func set_raid_intensity(level: int) -> void:
	if level == raid_intensity:
		return
	raid_intensity = level
	if stinger_slot != "":
		return
	play(raid_slot(_raid_id, level))


## Plays what fits the Game state (menu / lobby); called by the main menu when it opens.
func sync_to_game() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		play("menu")
		return
	_on_game_state(int(game.get("state")))


## Called by modes/match_scene.gd once Map/World/Mode exist (every peer): match music, ambience, mode hooks.
func enter_match(scene: Node) -> void:
	_disconnect_mode()
	var settings: Dictionary = scene.get("settings") if scene.get("settings") is Dictionary else {}
	var mode_id := str(settings.get("mode", "duel"))
	_raid_id = str(settings.get("raid_id", ""))
	raid_intensity = 0
	_last_phase = 0
	var map: Node = scene.get("map")
	set_ambience(zone_of(scene, map))
	play(match_slot(mode_id, _raid_id))
	var m: Node = scene.get("mode")
	if m != null:
		_mode = m
		if m.has_signal("score_changed"):
			m.connect("score_changed", _on_score)
		if m.has_signal("match_ended"):
			m.connect("match_ended", _on_match_ended)


## Fades out the music, a stinger and the ambience.
func stop_music(fade: float = CROSSFADE) -> void:
	_stop_stinger()
	_fade_all_tracks(fade)
	current_slot = ""
	current_path = ""


## Immediate silence + frees the playbacks (tests / exit).
func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	_gain = [0.0, 0.0]
	_target = [0.0, 0.0]
	if _stinger != null:
		_stinger.stop()
		_stinger.stream = null
	if _amb != null:
		_amb.stop()
		_amb.stream = null
	_amb_gain = 0.0
	_amb_target = 0.0
	_amb_next = ""
	ambience_path = ""
	current_slot = ""
	current_path = ""
	stinger_slot = ""
	_after_stinger = ""


# ================================================================== slot helpers (static, testable)
static func match_slot(mode_id: String, raid_id: String) -> String:
	match mode_id:
		"arena":
			return "battle_arena"
		"raid":
			return "raid_explore_" + raid_id
	return "battle_pvp"


static func raid_slot(raid_id: String, level: int) -> String:
	if level >= 2:
		return "raid_boss_enrage"
	if level == 1:
		return "raid_boss_" + str(BOSS_BY_RAID.get(raid_id, raid_id))
	return "raid_explore_" + raid_id


static func resolve_slot(slot: String) -> String:
	if PLAYLISTS.has(slot):
		return slot
	if slot.begins_with("raid_boss_"):
		return "raid_boss_black_knight"
	if slot.begins_with("raid_explore_"):
		return "raid_explore_frost_forest"
	return "menu"


static func track_paths(slot: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in PLAYLISTS.get(slot, []):
		out.append(MUSIC_DIR + slot + "/" + str(f))
	return out


static func ambience_paths() -> Array[String]:
	var out: Array[String] = []
	for z: Variant in AMBIENCE_BY_ZONE:
		out.append(AMBIENCE_DIR + str(AMBIENCE_BY_ZONE[z]))
	return out


## The scene's EnvKit zone: map meta/property env_zone, else the match scene's ZONE_BY_MAP.
static func zone_of(scene: Node, map: Node) -> String:
	if map == null:
		return ""
	if map.has_meta("env_zone"):
		return str(map.get_meta("env_zone"))
	if "env_zone" in map:
		return str(map.get("env_zone"))
	var table: Dictionary = ZONE_BY_MAP_FALLBACK
	if scene != null and scene.get_script() != null:
		var consts: Dictionary = (scene.get_script() as Script).get_script_constant_map()
		if consts.get("ZONE_BY_MAP") is Dictionary:
			table = consts["ZONE_BY_MAP"]
	var id := str(map.get("map_id")) if "map_id" in map else ""
	return str(table.get(id, ""))


# ================================================================== internals
func _on_game_state(st: int) -> void:
	# Game.State: MENU 0, LOBBY 1, LOADING 2, MATCH 3 (the match scene picks its own track).
	if st == 0 or st == 1:
		_disconnect_mode()
		set_ambience("")
		play("menu" if st == 0 else "lobby")


func _on_score(s: Dictionary) -> void:
	if str(s.get("mode", "")) != "raid" or stinger_slot != "":
		return
	# Raid cleared (final boss dead): hold the boss track until the victory stinger instead of
	# blipping back to explore. Only a wipe (state reset with the boss alive) returns to explore.
	var st := str(s.get("state", ""))
	if st == "done" or (st == "cleared" and int(s.get("encounter", 0)) >= int(s.get("encounters", 1)) - 1):
		return
	var engaged := int(s.get("boss_uid", 0)) != 0 and str(s.get("state", "")) == "active"
	var enraged := engaged and bool(s.get("enraged", false))
	var phase := int(s.get("phase", 0))
	if engaged and (phase != _last_phase or (enraged and raid_intensity < 2)):
		duck(ANNOUNCE_DUCK_DB, ANNOUNCE_DUCK_TIME)
	_last_phase = phase if engaged else 0
	set_raid_intensity(2 if enraged else (1 if engaged else 0))


func _on_match_ended(result: Dictionary) -> void:
	var won := false
	var winner := int(result.get("winner_team", -1))
	var game := get_node_or_null("/root/Game")
	var my_team := -1
	if game != null and game.has_method("my_slot"):
		my_team = int((game.call("my_slot") as Dictionary).get("team", -1))
	if winner >= 0:
		won = winner == my_team if my_team >= 0 else true
	play_stinger("victory" if won else "defeat", "results")


func _disconnect_mode() -> void:
	if _mode != null and is_instance_valid(_mode):
		if _mode.is_connected("score_changed", _on_score):
			_mode.disconnect("score_changed", _on_score)
		if _mode.is_connected("match_ended", _on_match_ended):
			_mode.disconnect("match_ended", _on_match_ended)
	_mode = null


func _next_track(slot: String) -> String:
	var paths := track_paths(slot)
	var valid: Array[String] = []
	for p: String in paths:
		if ResourceLoader.exists(p):
			valid.append(p)
	if valid.is_empty():
		return ""
	var n := int(_rotation.get(slot, -1)) + 1
	_rotation[slot] = n
	return valid[n % valid.size()]


func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s := load(path) as AudioStream
	if s != null and loop and "loop" in s:
		s.set("loop", true)
	if s != null:
		_cache[path] = s
	return s


func _crossfade_to(path: String) -> void:
	var stream := _load(path, true)
	if stream == null:
		return
	var old := _active
	_active = 1 - _active
	var p := _players[_active]
	p.stop()
	p.stream = stream
	_gain[_active] = 0.0
	_target[_active] = 1.0
	p.volume_db = SILENT_DB
	if audible:
		p.play()
	_target[old] = 0.0
	current_path = path
	track_changed.emit(current_slot, path)


func _fade_all_tracks(_fade: float) -> void:
	for i in 2:
		_target[i] = 0.0


func _stop_stinger() -> void:
	if stinger_slot != "":
		stinger_slot = ""
		_after_stinger = ""
		_stinger.stop()


func _on_stinger_finished() -> void:
	if stinger_slot == "":
		return
	var nxt := _after_stinger
	stinger_slot = ""
	_after_stinger = ""
	if nxt != "":
		play(nxt)


func _process(delta: float) -> void:
	# Real seconds: ignore Engine.time_scale (tests speed the game up; music fades should not).
	var dt := delta / maxf(Engine.time_scale, 0.001)
	_clock += dt
	var step := dt / CROSSFADE
	for i in 2:
		var p := _players[i]
		if _gain[i] != _target[i]:
			var fade_step := step if _target[i] > 0.0 else dt / (STINGER_FADE if stinger_slot != "" else CROSSFADE)
			_gain[i] = move_toward(_gain[i], _target[i], fade_step)
			p.volume_db = linear_to_db(maxf(_gain[i], 0.001))
			if _gain[i] <= 0.0 and _target[i] <= 0.0:
				p.stop()
	# Stinger end by its length (also when not audible; `finished` may not fire without an audio device).
	if stinger_slot != "" and _clock >= _stinger_end:
		_on_stinger_finished()
	# Rotate (or self-crossfade) shortly before the active track ends.
	var a := _players[_active]
	if current_slot != "" and a.playing and a.stream != null and _target[_active] > 0.0:
		var length := a.stream.get_length()
		if length > CROSSFADE * 3.0 and a.get_playback_position() >= length - CROSSFADE - 0.05:
			var path := _next_track(current_slot)
			if path != "":
				_crossfade_to(path)
	_process_ambience(dt)
	_process_duck(dt)


func _process_ambience(dt: float) -> void:
	if _amb_gain != _amb_target:
		_amb_gain = move_toward(_amb_gain, _amb_target, dt / AMBIENCE_FADE)
		_amb.volume_db = linear_to_db(maxf(_amb_gain, 0.001))
	if _amb_gain <= 0.0 and _amb_target <= 0.0:
		if _amb.playing:
			_amb.stop()
		if _amb_next != "" or ambience_path == "":
			var nxt := _amb_next
			_amb_next = ""
			if nxt != "" and ResourceLoader.exists(nxt):
				_amb.stream = _load(nxt, true)
				_amb.volume_db = SILENT_DB
				if audible:
					_amb.play()
				_amb_target = 1.0
			elif _amb.stream != null:
				_amb.stream = null


func _process_duck(dt: float) -> void:
	var want := _duck_target if _clock < _duck_until else 0.0
	if is_equal_approx(_duck_db, want):
		return
	var rate := absf(ANNOUNCE_DUCK_DB) / (DUCK_ATTACK if want < _duck_db else DUCK_RELEASE)
	_duck_db = move_toward(_duck_db, want, rate * dt)
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx < 0:
		return
	for e in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, e)
		if fx is AudioEffectAmplify:
			(fx as AudioEffectAmplify).volume_db = _duck_db
			return


## Current duck level of the Music bus in dB (0 = none).
func duck_level() -> float:
	return _duck_db
