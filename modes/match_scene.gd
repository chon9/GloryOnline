extends Node3D
## Root of scenes/match.tscn (owner: NET). Built identically on every peer from _game().settings/ _game().roster:
##   MatchScene
##     Map        (maps/map_registry.gd create(map_id) / raid registry / flat fallback)
##     World      (core/world.gd; fighters replicated through its MultiplayerSpawner)
##     Mode       (Match subclass: duel/team -> match_pvp.gd, arena -> match_arena.gd, raid -> match_raid.gd)
##     Controller (PlayerController for the local human, if they have a roster slot)
##     SpectateCam(CameraRig used while the local player has no living fighter)
##     Hud        (ui/hud.gd when present)  PauseMenu  Results
## When built, it reports to _game().on_match_scene_ready(); once every peer is ready the host calls begin_match().

const MAP_REGISTRY: String = "res://maps/map_registry.gd"
const RAID_REGISTRY: String = "res://pve/raid_registry.gd"
const HUD_PATH: String = "res://ui/hud.gd"
const MODE_SCRIPTS: Dictionary = {
	"duel": "res://modes/match_pvp.gd",
	"team": "res://modes/match_pvp.gd",
	"arena": "res://modes/match_arena.gd",
	"raid": "res://modes/match_raid.gd",
}
const RESULTS_SCRIPT := preload("res://ui/results.gd")
const PAUSE_SCRIPT := preload("res://ui/pause_menu.gd")
const SPECTATE_DELAY: float = 1.5
## EnvKit atmosphere preset per map id (maps call setup_atmosphere / painted_environment with these). A map can
## override it with an `env_zone` property or meta.
const ZONE_BY_MAP: Dictionary = {
	"classic_arena": "glory_stage",
	"hundred_blossoms": "blossom",
	"old_castle": "golden_ruins",
	"lava_cave": "lava",
	"boneyard": "moon",
	"frost_forest": "frost",
}
const RESULTS_DELAY: float = 2.5

var settings: Dictionary = {}
var roster: Array = []
var map: MapBase
var world: World
var mode: Match
var hud: Node
var controller: PlayerController
var spectate_cam: CameraRig
var pause_menu: CanvasLayer
var results: CanvasLayer
var spectating: bool = false
## Set false to stop the local PlayerController (tests drive input themselves).
var input_enabled: bool = true
var spectate_uid: int = 0

var _dead_time: float = 0.0
var _begun: bool = false


func _ready() -> void:
	name = "MatchScene"
	settings = _game().settings
	roster = _game().roster
	map = create_map()
	map.name = "Map"
	add_child(map)
	if map.get_child_count() == 0:
		map.build()
	world = World.new()
	world.name = "World"
	add_child(world)
	map.apply_to_world(world)
	apply_zone()
	world.fighter_removed.connect(_on_fighter_removed)
	mode = create_mode()
	add_child(mode)
	mode.match_ended.connect(_on_match_ended)
	if get_node_or_null("/root/Music") != null: get_node("/root/Music").call("enter_match", self)  # local music/ambience
	if not _game().my_slot().is_empty():
		controller = PlayerController.new()
		controller.name = "Controller"
		add_child(controller)
		if controller.camera != null:
			controller.camera.mouse_sensitivity = _game().mouse_sensitivity()
	spectate_cam = CameraRig.new()
	spectate_cam.name = "SpectateCam"
	add_child(spectate_cam)
	_build_hud()
	pause_menu = PAUSE_SCRIPT.new()
	add_child(pause_menu)
	pause_menu.connect("back_to_lobby", func() -> void: _game().return_to_lobby())
	pause_menu.connect("leave_match", func() -> void: _game().leave_session())
	pause_menu.connect("sensitivity_changed", func(_m: float) -> void:
		if controller != null and controller.camera != null:
			controller.camera.mouse_sensitivity = _game().mouse_sensitivity()
		spectate_cam.mouse_sensitivity = _game().mouse_sensitivity())
	spectate_cam.mouse_sensitivity = _game().mouse_sensitivity()
	_apply_camera_prefs()
	if _game().has_signal("prefs_changed"):
		_game().connect("prefs_changed", _apply_camera_prefs)
	_update_cameras(0.0)
	_game().on_match_scene_ready(self)


func _apply_camera_prefs() -> void:
	var on := bool(_game().prefs.get("camera_shake", true))
	for rig: CameraRig in [controller.camera if controller != null else null, spectate_cam]:
		if rig != null and is_instance_valid(rig):
			rig.impact_feedback = on


func _exit_tree() -> void:
	CharacterVisual.set_zone("", get_tree())


## Zone rim / shadow tint for every character visual (CHARS request): the map's EnvKit preset, "" = neutral.
func apply_zone() -> String:
	var z := ""
	if map != null:
		if map.has_meta("env_zone"):
			z = str(map.get_meta("env_zone"))
		elif "env_zone" in map:
			z = str(map.get("env_zone"))
		else:
			z = str(ZONE_BY_MAP.get(map.map_id, ""))
	CharacterVisual.set_zone(z, get_tree())
	return z


## Host: every peer has loaded; start the mode (spawns fighters through World's spawner).
func begin_match() -> void:
	if _begun or not multiplayer.is_server():
		return
	_begun = true
	mode.begin()


# ================================================================== building
func create_map() -> MapBase:
	var m: MapBase = null
	if str(settings.get("mode", "")) == "raid":
		m = _call_registry(RAID_REGISTRY, ["create_map", "create"], str(settings.get("raid_id", "")))
	if m == null:
		var key := "raid_id" if str(settings.get("mode", "")) == "raid" else "map_id"
		if str(settings.get(key, "")) != "":
			m = _call_registry(MAP_REGISTRY, ["create"], str(settings.get(key, "")))
	if m == null:
		m = FlatMap.new()
	return m


static func _call_registry(path: String, methods: Array, id: String) -> MapBase:
	if not ResourceLoader.exists(path):
		return null
	var scr: Variant = load(path)
	if not (scr is Script):
		return null
	var names: Array[String] = []
	for md: Dictionary in (scr as Script).get_script_method_list():
		names.append(str(md.get("name", "")))
	for meth: Variant in methods:
		if names.has(str(meth)):
			var r: Variant = (scr as Script).call(str(meth), id)
			if r is MapBase:
				return r
			if r is Node:
				(r as Node).free()
	return null


func create_mode() -> Match:
	var path: String = MODE_SCRIPTS.get(str(settings.get("mode", "duel")), MODE_SCRIPTS["duel"])
	var m: Match = null
	if ResourceLoader.exists(path):
		var scr: Variant = load(path)
		if scr is Script and (scr as Script).can_instantiate():
			var inst: Variant = (scr as Script).new()
			if inst is Match:
				m = inst
			elif inst is Node:
				(inst as Node).free()
	if m == null:
		push_warning("MatchScene: mode script %s missing; falling back to duel rules" % path)
		m = (load(MODE_SCRIPTS["duel"]) as Script).new()
	m.name = "Mode"
	m.setup(world, map, settings, roster)
	return m


func _build_hud() -> void:
	if not ResourceLoader.exists(HUD_PATH):
		return
	var scr: Variant = load(HUD_PATH)
	if not (scr is Script) or not (scr as Script).can_instantiate():
		return
	var inst: Variant = (scr as Script).new()
	if not (inst is Node):
		return
	hud = inst
	hud.name = "Hud"
	add_child(hud)
	for meth: String in ["bind", "setup"]:
		var argc := -1
		for md: Dictionary in (scr as Script).get_script_method_list():
			if str(md.get("name", "")) == meth:
				argc = (md.get("args", []) as Array).size()
		match argc:
			-1:
				continue
			0:
				hud.call(meth)
			1:
				hud.call(meth, mode)
			2:
				hud.call(meth, world, mode)
			_:
				hud.call(meth, world, mode, 0)   # Hud.bind(world, match, local_uid): 0 = auto (own fighter)
		break


# ================================================================== runtime
func _process(delta: float) -> void:
	_update_cameras(delta)
	if controller != null:
		var on: bool = input_enabled and not (pause_menu != null and bool(pause_menu.get("is_open"))) and results == null
		if controller.enabled and not on:
			_send_neutral_input()
		controller.enabled = on


## Stops the local fighter when the controller gets disabled (the host keeps the last input otherwise).
func _send_neutral_input() -> void:
	var f := controller.fighter
	if f == null or not is_instance_valid(f):
		return
	var inp := FighterInput.new()
	if multiplayer.is_server():
		f.apply_input(inp)
	else:
		f.submit_input.rpc_id(1, inp.to_dict())


func local_fighter() -> Fighter:
	return world.local_fighter() if world != null else null


func _update_cameras(delta: float) -> void:
	var me := local_fighter()
	if me != null and not me.is_alive():
		_dead_time += delta
	else:
		_dead_time = 0.0
	var want := me == null or (not me.is_alive() and _dead_time > SPECTATE_DELAY)
	spectating = want
	if want:
		if controller != null and InputMap.has_action("target_cycle") and Input.is_action_just_pressed("target_cycle"):
			spectate_uid = _next_spectate_target(spectate_uid, true)
		var t := world.get_fighter(spectate_uid)
		if t == null or not t.is_alive() or not t.is_inside_tree():
			spectate_uid = _next_spectate_target(0, false)
			t = world.get_fighter(spectate_uid)
		spectate_cam.target = t
		_hud_follow(t.uid if t != null else 0)
		if spectate_cam.camera != null:
			spectate_cam.camera.current = true
	else:
		_hud_follow(0)
		if controller != null and controller.camera != null and controller.camera.camera != null:
			controller.camera.camera.current = true


var _hud_uid: int = -1


func _hud_follow(uid: int) -> void:
	if uid == _hud_uid or hud == null or not hud.has_method("set_local_uid"):
		return
	_hud_uid = uid
	hud.call("set_local_uid", uid)


## Picks a living fighter to watch: allies of my team first (cycling after `after`).
func _next_spectate_target(after: int, cycle: bool) -> int:
	var my_team := int(_game().my_slot().get("team", 0))
	var cands: Array[Fighter] = []
	for f: Fighter in world.fighters:
		if is_instance_valid(f) and f.is_inside_tree() and f.is_alive() and f.kind != "summon":
			cands.append(f)
	if cands.is_empty():
		return 0
	cands.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		var ta := 0 if a.team == my_team else 1
		var tb := 0 if b.team == my_team else 1
		return ta < tb if ta != tb else a.uid < b.uid)
	if not cycle:
		return cands[0].uid
	for i in cands.size():
		if cands[i].uid == after:
			return cands[(i + 1) % cands.size()].uid
	return cands[0].uid


## Host: a human left mid-match; their fighter (if any) becomes a bot.
func on_peer_left(peer: int) -> void:
	if not multiplayer.is_server() or world == null:
		return
	var brain_mode := "raid" if str(settings.get("mode", "")) == "raid" else "pvp"
	for f: Fighter in world.fighters:
		if is_instance_valid(f) and f.peer == peer and f.kind == "player":
			f.peer = 0
			f.kind = "bot"
			f.input = FighterInput.new()
			world.attach_brain(f, brain_mode)
	if mode != null and mode.has_method("on_peer_left"):
		mode.call("on_peer_left", peer)


## A fighter left the tree (despawn / arena corpse): cameras must not keep following it.
func _on_fighter_removed(f: Fighter) -> void:
	if spectate_cam != null and spectate_cam.target == f:
		spectate_cam.target = null
	if controller != null:
		if controller.camera != null and controller.camera.target == f:
			controller.camera.target = null
		if controller.fighter == f:
			controller.fighter = null


func _on_match_ended(result: Dictionary) -> void:
	_game().on_match_ended(result)
	if results != null:
		return
	# Let the HUD's victory banner play first.
	await get_tree().create_timer(RESULTS_DELAY).timeout
	if results != null or not is_inside_tree():
		return
	if pause_menu != null and pause_menu.get("is_open"):
		pause_menu.call("close")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The results screen replaces the HUD (its own result banner/scoreboard would show through otherwise).
	if hud != null and hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	results = RESULTS_SCRIPT.new()
	add_child(results)
	results.call("show_result", result, multiplayer.is_server(), _game().results_auto_return)
	results.connect("back_pressed", func() -> void: _game().return_to_lobby())
	results.connect("leave_pressed", func() -> void: _game().leave_session())


# ================================================================== fallback map
## Flat 40x40 arena used when the MAPS / RAID registries are not available.
class FlatMap extends MapBase:
	func _init() -> void:
		map_id = "fallback_flat"
		name_cn = "训练场"
		name_en = "Training Ground"
		size = Vector2(40.0, 40.0)

	func build() -> void:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.5, 0.6, 0.75)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.6, 0.62, 0.7)
		env.ambient_light_energy = 0.6
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
		sun.shadow_enabled = true
		add_child(sun)
		var body := StaticBody3D.new()
		body.name = "Floor"
		body.collision_layer = CoreUtil.LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x + 4.0, 1.0, size.y + 4.0)
		cs.shape = box
		cs.position = Vector3(0, -0.5, 0)
		body.add_child(cs)
		var mesh := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(size.x + 4.0, size.y + 4.0)
		mesh.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.36, 0.38, 0.42)
		mesh.material_override = mat
		body.add_child(mesh)
		add_child(body)


func _game() -> Node:
	return get_node("/root/Game")


func _net() -> Node:
	return get_node("/root/Net")
