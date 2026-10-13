extends Node3D
## HUD visual check scene (scenes/hud_preview.tscn): a small arena, a World with a player, allies,
## enemies (and a boss in the "boss" state), a Match node feeding timer/score/announcements, and the Hud.
## Screenshot mode (non-headless):
##   godot --path . --resolution 1600x900 res://scenes/hud_preview.tscn -- --state=<s> --shot=<png> [--wait=2.5] [--dummy=1]
## States: combat (default), boss, scoreboard, announce, help, defeat, result, spectate,
## icons (renders the procedural status + skill icon sheet and exports res://ui/icons/*.png).
## Interactive keys: F1 help, ` scoreboard, F2 next state, F3 announce, F4 kill a random enemy.

const KIT_PATH: String = "res://tests/test_kit_dummy.gd"
const BOSS_ID: String = "hud_preview_boss"
const MOB_ID: String = "hud_preview_mob"
const PREFERRED: Array[String] = ["blade_master", "cleric", "launcher", "assassin", "knight", "elementalist", "berserker"]
const STATES: Array[String] = ["combat", "boss", "scoreboard", "announce", "help", "defeat", "result", "spectate", "icons"]
const HudIcons := preload("res://ui/hud_icons.gd")
const HudStyle := preload("res://ui/hud_style.gd")
const ICON_PX: int = 64
const ICON_DIR: String = "res://ui/icons"

var world: World
var hud: Hud
var match_node: Match
var cam: CameraRig
var player: Fighter
var allies: Array[Fighter] = []
var enemies: Array[Fighter] = []
var boss: Fighter = null
var state: String = "combat"
var _args: Dictionary = {}
var _class_pool: Array[String] = []
var _t: float = 0.0
var _act_t: float = 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	state = str(_args.get("state", "combat"))
	var reg := get_node_or_null("/root/Registry")
	var dummy: ClassKit = (load(KIT_PATH) as Script).new()
	if reg != null:
		reg.call("register_kit", dummy)
		_register_mobs(reg)
		if not _args.has("dummy"):
			for id: String in PREFERRED:
				if bool(reg.call("has_kit", id)):
					_class_pool.append(id)
	if _class_pool.size() < 3:
		_class_pool = ["test_dummy"]
	_build_environment()
	world = World.new()
	world.set_arena_size(60.0, 60.0)
	add_child(world)
	_build_floor()
	match_node = Match.new()
	match_node.name = "Match"
	match_node.settings = {"mode": "raid" if state == "boss" else "team"}
	add_child(match_node)
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	_spawn_all.call_deferred()


func _cls(i: int) -> String:
	return _class_pool[i % _class_pool.size()]


func _register_mobs(reg: Node) -> void:
	reg.call("register_mob_def", BOSS_ID, {"name_cn": "霜之魔像", "name_en": "Frost Golem", "model": "frost_golem",
		"weapon_type": "frost_golem_axe", "scale": 1.0, "tint": Color(0.5, 0.8, 1.0),
		"stats": {"hp": 180000.0, "mp": 0.0, "patk": 700.0, "pdef": 600.0, "mdef": 600.0, "move_speed": 4.0}, "skills": []})
	reg.call("register_mob_def", MOB_ID, {"name_cn": "骷髅战士", "name_en": "Skeleton Warrior", "model": "skeleton_warrior",
		"weapon_type": "skeleton_blade", "scale": 1.0, "tint": Color(0.8, 0.8, 0.7),
		"stats": {"hp": 9000.0, "mp": 0.0, "patk": 450.0}, "skills": []})


func _spawn_all() -> void:
	var me_peer := multiplayer.get_unique_id()
	player = world.spawn_fighter({"kind": "player", "peer": me_peer, "class_id": _cls(0), "team": 0,
		"name": "叶秋 Ye Qiu", "pos": Vector3(0, 0, 6), "yaw": 0.0})
	var ally_names: Array[String] = ["苏沐橙 Su Mucheng", "方锐 Fang Rui", "包荣兴 Bao Rongxing", "安文逸 An Wenyi"]
	for i in (4 if state == "boss" else 2):
		allies.append(world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": _cls(i + 1), "team": 0,
			"name": ally_names[i], "pos": Vector3([-4.5, 4.5, -7.5, 7.5][i], 0, 4.0 - (i / 2) * 1.5), "yaw": 0.0}))
	if state == "boss":
		boss = world.spawn_fighter({"kind": "boss", "peer": 0, "class_id": "", "mob_id": BOSS_ID, "team": 1,
			"name": "", "pos": Vector3(0, 0, -6), "yaw": PI})
		for i in 2:
			enemies.append(world.spawn_fighter({"kind": "mob", "peer": 0, "class_id": "", "mob_id": MOB_ID, "team": 1,
				"name": "", "pos": Vector3(-5.0 + i * 10.0, 0, -2), "yaw": PI}))
	else:
		var foe_names: Array[String] = ["韩文清 Han Wenqing", "张新杰 Zhang Xinjie", "林敬言 Lin Jingyan"]
		for i in 3:
			enemies.append(world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": _cls(i + 3), "team": 1,
				"name": foe_names[i], "pos": Vector3(-3.5 + i * 3.5, 0, -1.0 - (i % 2) * 1.5), "yaw": PI}))
	cam.target = player
	cam.distance = 6.5
	cam.pitch = -0.32
	hud.bind(world, match_node, 0)
	_setup_state()
	if _args.has("shot"):
		_take_shot.call_deferred()


func _setup_state() -> void:
	var lock: Fighter = boss if boss != null else enemies[1]
	player.input.target_uid = lock.uid
	player.target_uid = lock.uid
	# timer / score
	if state == "boss":
		match_node.score_changed.emit({"encounter": "3 / 3", "boss_phase": 2})
	else:
		match_node.timer_changed.emit(83.0)
		match_node.score_changed.emit({0: 1, 1: 0, "round": 2})
	# combat flavour: statuses, cooldowns, damage, combo, kill feed
	player.add_status(&"burn", 6.0, 1.0, enemies[0])
	player.add_status(&"slow", 6.0, 0.3, enemies[0])
	player.add_status(&"haste", 8.0, 0.2)
	player.add_status(&"atk_up", 8.0, 0.2)
	player.add_status(&"regen", 8.0, 0.01)
	player.add_shield(player.max_hp * 0.12, 8.0)
	player.hp = player.max_hp * 0.62
	player.mp = player.max_mp * 0.48
	for i in [2, 3, 5, 6]:
		var s := player.get_skill(i)
		if s != null:
			player._consume_charge(i, s.cooldown)
	player.mp = minf(player.mp, 120.0) if state == "combat" else player.mp
	player.combo_count = 23
	for f: Fighter in allies:
		f.hp = f.max_hp * randf_range(0.35, 0.95)
	allies[0].add_status(&"def_up", 6.0, 0.2)
	allies[1].add_status(&"poison", 6.0, 1.0)
	lock.add_status(&"def_down", 6.0, 0.2)
	lock.add_status(&"mark", 6.0)
	lock.add_status(&"bleed", 6.0, 1.0)
	if boss != null:
		boss.hp = boss.max_hp * 0.43
		enemies[0].hp = enemies[0].max_hp * 0.4
	else:
		enemies[0].hp = enemies[0].max_hp * 0.55
		enemies[1].hp = enemies[1].max_hp * 0.38
		enemies[2].add_status(&"stealth", 30.0)
	# a few feed entries
	if boss == null:
		var extra := world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": _cls(5), "team": 1,
			"name": "孙翔 Sun Xiang", "pos": Vector3(8, 0, -6), "yaw": PI})
		extra.kill(player)
		player.damage_dealt = 18450.0
		allies[0].damage_dealt = 12210.0
		allies[1].healing_done = 15800.0
		if state == "scoreboard":
			allies[0].kill(null)
	else:
		var mob := world.spawn_fighter({"kind": "mob", "peer": 0, "class_id": "", "mob_id": MOB_ID, "team": 1,
			"name": "", "pos": Vector3(9, 0, -6), "yaw": PI})
		mob.kill(allies[1])
		allies[3].kill(boss)
	match state:
		"announce":
			pass
		"help":
			hud.set_help_visible(true)
		"scoreboard":
			hud.set_scoreboard_forced(true)
		"defeat":
			player.kill(enemies[0])
		"spectate":
			hud.set_local_uid(allies[0].uid)
			cam.target = allies[0]
		"icons":
			_build_icon_sheet()
		"result":
			match_node.match_ended.emit({"winner_team": 0, "mode": "team", "mvp_uid": player.uid, "clear_time": 0.0,
				"stats": {}})


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	# keep the scene alive: enemies poke the player, player keeps the combo going
	_act_t += delta
	if _act_t > 0.45 and state != "defeat" and player.is_alive():
		_act_t = 0.0
		if state == "combat" or state == "boss":
			player.combo_count += 1
	var wait := float(_args.get("wait", "2.5"))
	if state == "announce" and _t > wait - 0.45 and hud.announce_banner.current_text() == "":
		hud.announce("第二局 开始  Round 2 - Fight!\n击败所有对手  Defeat every opponent", 3.0)
	if state == "combat" and player.cast_slot < 0 and _t > wait - 0.55 and _t < wait - 0.3:
		var ult := player.get_skill(7)
		if ult != null:
			player.start_skill(ult, 7)


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_F2:
			var i := (STATES.find(state) + 1) % STATES.size()
			_args["state"] = STATES[i]
			get_tree().reload_current_scene()
		KEY_F3:
			hud.announce("首领出现  Boss Incoming\n小心地面预警  Watch the telegraphs", 2.5)
		KEY_F4:
			for f: Fighter in enemies:
				if is_instance_valid(f) and f.is_alive():
					f.kill(player)
					break


func _take_shot() -> void:
	var wait := float(_args.get("wait", "2.5"))
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args["shot"])
	print("SHOT saved ", _args["shot"], " ", img.get_size())
	if state == "icons":
		_export_icons(img)
	get_tree().quit()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.68)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(30.0), 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = CoreUtil.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(64, 1, 64)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	world.add_child(body)
	var tile_path := "res://assets/env/dungeon/floor_tile_large.gltf"
	if ResourceLoader.exists(tile_path):
		var tile: PackedScene = load(tile_path)
		for x in range(-6, 7):
			for z in range(-6, 5):
				var t := tile.instantiate() as Node3D
				t.position = Vector3(x * 4.0, 0, z * 4.0)
				add_child(t)
		var pillar_path := "res://assets/env/dungeon/pillar_decorated.gltf"
		var torch_path := "res://assets/env/dungeon/torch_lit.gltf"
		for i in 5:
			if ResourceLoader.exists(pillar_path):
				var p: Node3D = (load(pillar_path) as PackedScene).instantiate()
				p.position = Vector3(-16 + i * 8, 0, -18)
				add_child(p)
			if ResourceLoader.exists(torch_path):
				var tl: Node3D = (load(torch_path) as PackedScene).instantiate()
				tl.position = Vector3(-12 + i * 8, 0, -17)
				add_child(tl)
	else:
		var mesh := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(64, 64)
		mesh.mesh = pm
		body.add_child(mesh)


# ------------------------------------------------------------------ icon sheet (state "icons")
class IconSheet extends Control:
	var skills: Array = []
	var tint: Color = Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.1))
		var f := HudStyle.font(true)
		for i in HudStyle.STATUS_INFO.size():
			var r := HudPreviewIcons.status_rect(i)
			HudIcons.draw_status_icon(self, r, i)
			var info: Array = HudStyle.STATUS_INFO[i]
			draw_string(f, r.position + Vector2(0, r.size.y + 16), "%s %s" % [info[1], info[2]], HORIZONTAL_ALIGNMENT_LEFT, 150, 12, Color(0.9, 0.9, 0.9))
		for i in skills.size():
			var r2 := HudPreviewIcons.skill_rect(i)
			HudIcons.draw_skill_icon(self, r2, skills[i], tint)


class HudPreviewIcons:
	static func status_rect(i: int) -> Rect2:
		return Rect2(Vector2(40 + (i % 9) * 170, 60 + (i / 9) * 120), Vector2(64, 64))

	static func skill_rect(i: int) -> Rect2:
		return Rect2(Vector2(40 + i * 110, 470), Vector2(80, 80))


func _build_icon_sheet() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	var sheet := IconSheet.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 8:
		sheet.skills.append(player.get_skill(i))
	sheet.tint = player.kit.tint if player.kit != null else Color.WHITE
	cl.add_child(sheet)


func _export_icons(img: Image) -> void:
	var dir := ProjectSettings.globalize_path(ICON_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var vp := get_viewport().get_visible_rect().size
	var sx := img.get_width() / vp.x
	var sy := img.get_height() / vp.y
	for i in StatusSet.IDS.size():
		var r := HudPreviewIcons.status_rect(i)
		var sub := img.get_region(Rect2i(int(r.position.x * sx), int(r.position.y * sy), int(r.size.x * sx), int(r.size.y * sy)))
		sub.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
		sub.save_png(dir.path_join("status_%s.png" % StatusSet.IDS[i]))
	print("ICONS exported to ", dir)
