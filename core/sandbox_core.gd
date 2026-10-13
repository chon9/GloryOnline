extends Node3D
## CORE combat sandbox (scenes/sandbox_core.tscn): flat arena, a human player using the test kit and two
## training dummies. Lets humans try the combat feel without the rest of the game.
## Keys: F1 reset dummies, F2 toggle dummy super armor, F3 toggle dummy block, F4 dummy fights back.

const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var world: World
var controller: PlayerController
var player: Fighter
var dummies: Array[Fighter] = []
var hud: Label
var help: Label
var _dummy_armor: bool = false
var _dummy_block: bool = false
var _dummy_fight: bool = false
var _respawn: Dictionary = {}       # uid -> seconds until revive
var _ai_t: float = 0.0


func _ready() -> void:
	var reg := get_node_or_null("/root/Registry")
	var kit: ClassKit = (load(KIT_PATH) as Script).new()
	if reg != null:
		reg.call("register_kit", kit)
	_build_environment()
	world = World.new()
	world.set_arena_size(60.0, 60.0)
	add_child(world)
	_build_floor()
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	_build_hud()
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	player = world.spawn_fighter({"kind": "player", "peer": multiplayer.get_unique_id(), "class_id": "test_dummy",
		"team": 0, "name": "玩家 Player", "pos": Vector3(0, 0, 6), "yaw": 0.0})
	for i in 2:
		var d := world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": "test_dummy", "team": 1,
			"name": "木人%d Dummy %d" % [i + 1, i + 1], "pos": Vector3(-2.5 + 5.0 * i, 0, -3), "yaw": PI})
		d.died.connect(_on_dummy_died)
		dummies.append(d)


func _on_dummy_died(f: Fighter, _killer: Fighter) -> void:
	_respawn[f.uid] = 2.0


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.8)
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
	sun.light_energy = 1.2
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
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(64, 64)
	mesh.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.42)
	mat.uv1_scale = Vector3(32, 32, 1)
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.42, 0.45, 0.5))
	img.set_pixel(1, 1, Color(0.42, 0.45, 0.5))
	img.set_pixel(1, 0, Color(0.32, 0.34, 0.38))
	img.set_pixel(0, 1, Color(0.32, 0.34, 0.38))
	var tex := ImageTexture.create_from_image(img)
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh.material_override = mat
	body.add_child(mesh)
	world.add_child(body)
	# A few pillars so walls / blink raycasts / camera spring can be tried.
	for p: Vector3 in [Vector3(8, 0, -8), Vector3(-9, 0, 4), Vector3(4, 0, 12)]:
		var pil := StaticBody3D.new()
		pil.collision_layer = CoreUtil.LAYER_WORLD
		pil.position = p + Vector3(0, 1.5, 0)
		var pcs := CollisionShape3D.new()
		var pb := BoxShape3D.new()
		pb.size = Vector3(1.5, 3, 1.5)
		pcs.shape = pb
		pil.add_child(pcs)
		var pmesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pb.size
		pmesh.mesh = bm
		pil.add_child(pmesh)
		world.add_child(pil)


func _make_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	return f


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font := _make_font()
	hud = Label.new()
	hud.position = Vector2(16, 16)
	hud.add_theme_font_override("font", font)
	hud.add_theme_font_size_override("font_size", 15)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)
	help = Label.new()
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(16, -150)
	help.add_theme_font_override("font", font)
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	help.text = "移动 Move: WASD   跳 Jump/受身 Recover: Space   普攻 Attack: LMB   技能 Skills: RMB Q E R F 1 2\n" \
		+ "锁定 Lock-on: Tab / 中键 MMB   缩放 Zoom: 滚轮 Wheel   鼠标 Mouse: Esc 释放 release\n" \
		+ "F1 重置木人 Reset dummies   F2 木人霸体 Dummy super armor   F3 木人格挡 Dummy block   F4 木人反击 Dummy fights"
	layer.add_child(help)
	var cross := Label.new()
	cross.text = "+"
	cross.anchor_left = 0.5
	cross.anchor_top = 0.5
	cross.anchor_right = 0.5
	cross.anchor_bottom = 0.5
	cross.position = Vector2(-5, -12)
	cross.add_theme_font_size_override("font_size", 20)
	layer.add_child(cross)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match (e as InputEventKey).keycode:
		KEY_F1:
			for d: Fighter in dummies:
				if is_instance_valid(d):
					if not d.is_alive():
						d.revive(1.0)
					d.reset_for_round()
		KEY_F2:
			_dummy_armor = not _dummy_armor
		KEY_F3:
			_dummy_block = not _dummy_block
		KEY_F4:
			_dummy_fight = not _dummy_fight


func _physics_process(delta: float) -> void:
	for uid: Variant in _respawn.keys():
		_respawn[uid] = float(_respawn[uid]) - delta
		if float(_respawn[uid]) <= 0.0:
			_respawn.erase(uid)
			var f := world.get_fighter(int(uid))
			if f != null:
				f.revive(1.0)
				f.reset_for_round()
	_ai_t -= delta
	for d: Fighter in dummies:
		if not is_instance_valid(d) or not d.is_alive():
			continue
		if _dummy_armor and not d.has_status(&"super_armor"):
			d.add_status(&"super_armor", 999.0, 1.0, d)
		elif not _dummy_armor and d.has_status(&"super_armor") and d.status.remaining(&"super_armor") > 100.0:
			d.remove_status(&"super_armor")
		if _dummy_block and not d.has_status(&"block"):
			d.add_status(&"block", 999.0, 0.6, d)
		elif not _dummy_block and d.has_status(&"block") and d.status.remaining(&"block") > 100.0:
			d.remove_status(&"block")
		# Out-of-combat regen so the training dummies never run dry.
		if d.state == Fighter.State.IDLE and d.hp < d.max_hp:
			d.heal(d.max_hp * 0.05 * delta, null)
		d.input.move = Vector3.ZERO
		if _dummy_fight and player != null and is_instance_valid(player) and player.is_alive():
			d.input.target_uid = player.uid
			d.input.aim_point = player.center()
			var dist := d.global_position.distance_to(player.global_position)
			if dist > 2.2:
				d.input.move = CoreUtil.flat_dir(player.global_position - d.global_position, Vector3.ZERO)
			elif _ai_t <= 0.0:
				d.input.press(0 if randf() < 0.7 else 1)
		else:
			d.input.target_uid = 0
	if _ai_t <= 0.0:
		_ai_t = 0.6
	if player != null and is_instance_valid(player) and not player.is_alive() and not _respawn.has(player.uid):
		_respawn[player.uid] = 2.0


func _process(_delta: float) -> void:
	if hud == null or player == null or not is_instance_valid(player):
		return
	var lines: PackedStringArray = []
	lines.append("%s  生命 HP %d/%d  法力 MP %d/%d  护盾 Shield %d" % [player.display_name, player.hp, player.max_hp,
		player.mp, player.max_mp, player.shield_hp])
	lines.append("状态 State: %s   动画 Anim: %s   连击 Combo: %d" % [player.state_name(), player.anim_key, player.combo_count])
	var keys := ["LMB", "RMB", "Q", "E", "R", "F", "1", "2"]
	for i in 8:
		var s := player.get_skill(i)
		if s == null:
			continue
		var cd := player.get_cooldown(i)
		var ch := player.get_charges(i)
		var tag := "就绪 ready" if ch > 0 else "%.1fs" % cd
		if s.charges > 1:
			tag += "  [%d/%d]" % [ch, s.charges]
		lines.append("  [%s] %s  %s" % [keys[i], s.display_name(), tag])
	var t := player.get_target()
	if t != null:
		lines.append("目标 Target: %s  HP %d/%d  %s  浮空保护 Juggle %d" % [t.display_name, t.hp, t.max_hp, t.state_name(), t.juggle_points])
	lines.append("木人 Dummies: 霸体 Armor %s  格挡 Block %s  反击 Fight %s" % ["ON" if _dummy_armor else "off",
		"ON" if _dummy_block else "off", "ON" if _dummy_fight else "off"])
	hud.text = "\n".join(lines)
