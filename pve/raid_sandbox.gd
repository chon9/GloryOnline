extends Node3D
## Raid sandbox (scenes/raid_sandbox.tscn): one human player (PlayerController + CameraRig) and 4 bots run
## a raid dungeon offline. Uses real class kits from the Registry when present (tank / healer / dps picks),
## otherwise the test kit. Keys: F1 skip to the boss, F2 clear the current encounter, F3 restart,
## F4 god mode for the player, F5 switch dungeon.
## Screenshot mode (needs a display):
##   godot --path . res://scenes/raid_sandbox.tscn -- --raid=frost_forest --view=boss --shot=<png> [--wait=3]
##   views: start, room1, room2, boss, boss_close, overview, play (player camera)

const KIT_PATH: String = "res://tests/test_kit_dummy.gd"
const PLAYER_PICKS: Array[String] = ["blade_master", "battle_mage", "berserker", "striker", "unspecialized"]
const BOT_PICKS: Array[Array] = [["knight", "paladin"], ["cleric", "paladin"], ["elementalist", "sharpshooter", "launcher"],
	["assassin", "spellblade", "ghostblade", "qi_master"]]

## Survives scene reloads (F5 switches dungeon).
static var chosen_raid: String = ""

var world: World
var map: MapBase
var match_node: MatchRaid
var controller: PlayerController
var raid_id: String = "frost_forest"
var god: bool = false
var _args: Dictionary = {}
var _hud: Label
var _ann: Label
var _ann_t: float = 0.0
var _boss_bar: ProgressBar
var _boss_label: Label
var _shot_cam: Camera3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	raid_id = str(_args.get("raid", raid_id))
	if chosen_raid != "":
		raid_id = chosen_raid
	var reg := get_node_or_null("/root/Registry")
	if reg != null and not bool(reg.call("has_kit", "test_dummy")):
		reg.call("register_kit", (load(KIT_PATH) as Script).new())
	world = World.new()
	add_child(world)
	map = RaidRegistry.create(raid_id)
	if map == null:
		push_error("raid_sandbox: unknown raid " + raid_id)
		return
	add_child(map)
	map.build()
	match_node = MatchRaid.new()
	match_node.name = "MatchRaid"
	add_child(match_node)
	match_node.setup(world, map, {"mode": "raid", "raid_id": raid_id}, _roster())
	match_node.announce.connect(_on_announce)
	match_node.match_ended.connect(_on_ended)
	var shot := _args.has("shot")
	if not shot or str(_args.get("view", "")) == "play":
		controller = PlayerController.new()
		controller.name = "PlayerController"
		controller.capture_mouse = not shot
		add_child(controller)
	_build_hud()
	_begin.call_deferred()


func _begin() -> void:
	match_node.begin()
	if _args.has("shot"):
		_shot.call_deferred()


func _roster() -> Array:
	var reg := get_node_or_null("/root/Registry")
	var have := func(id: String) -> bool: return reg != null and bool(reg.call("has_kit", id))
	var used: Array[String] = []
	var player_class := "test_dummy"
	for id: String in PLAYER_PICKS:
		if have.call(id):
			player_class = id
			break
	used.append(player_class)
	var roster: Array = [{"slot": 0, "team": 0, "peer": multiplayer.get_unique_id(), "name": "玩家 Player",
		"class_id": player_class, "ready": true}]
	for i in BOT_PICKS.size():
		var cid := "test_dummy"
		for id: String in BOT_PICKS[i]:
			if have.call(id) and not used.has(id):
				cid = id
				break
		used.append(cid)
		roster.append({"slot": i + 1, "team": 0, "peer": 0, "name": "队友%d Bot %d" % [i + 1, i + 1], "class_id": cid, "ready": true})
	return roster


# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font := RaidUtil.font()
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_style(_hud, font, 15)
	layer.add_child(_hud)
	_ann = Label.new()
	_ann.anchor_left = 0.5
	_ann.anchor_right = 0.5
	_ann.position = Vector2(-500, 90)
	_ann.size = Vector2(1000, 40)
	_ann.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_ann, font, 24)
	_ann.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	layer.add_child(_ann)
	_boss_label = Label.new()
	_boss_label.anchor_left = 0.5
	_boss_label.anchor_right = 0.5
	_boss_label.position = Vector2(-300, 22)
	_boss_label.size = Vector2(600, 24)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_boss_label, font, 17)
	layer.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.position = Vector2(-300, 50)
	_boss_bar.size = Vector2(600, 18)
	_boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.15, 0.12)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	_boss_bar.add_theme_stylebox_override("background", bg)
	layer.add_child(_boss_bar)
	var help := Label.new()
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(16, -64)
	_style(help, font, 13)
	help.text = "移动 WASD  跳 Space  普攻 LMB  技能 RMB Q E R F 1 2  锁定 Tab  释放鼠标 Esc\n" \
		+ "F1 直达首领 Skip to boss   F2 清除当前遭遇 Clear encounter   F3 重开 Restart   F4 无敌 God mode   F5 换副本 Switch dungeon"
	layer.add_child(help)


func _style(l: Label, font: Font, sz: int) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)


func _on_announce(text: String, seconds: float) -> void:
	_ann.text = text
	_ann_t = seconds


func _on_ended(result: Dictionary) -> void:
	_on_announce("通关！用时 Cleared in %s   最佳 Best %s" % [MatchRaid.format_time(float(result.get("clear_time", 0.0))),
		MatchRaid.format_time(float(result.get("best_time", 0.0)))], 30.0)


func _process(delta: float) -> void:
	if match_node == null or _hud == null:
		return
	_ann_t -= delta
	_ann.visible = _ann_t > 0.0
	var lines: PackedStringArray = []
	lines.append("%s %s   用时 Time %s   团灭 Wipes %d" % [map.name_cn, map.name_en, MatchRaid.format_time(match_node.clear_time), match_node.wipes])
	if match_node.current < match_node.encounters.size():
		var e: Dictionary = match_node.encounters[match_node.current]
		lines.append("遭遇 Encounter %d/%d: %s %s  [%s]" % [match_node.current + 1, match_node.encounters.size(),
			e.get("name_cn", ""), e.get("name_en", ""), match_node.enc_state[match_node.current]])
	if god:
		lines.append("无敌 GOD MODE")
	for f: Fighter in match_node.party():
		lines.append("  %s  %s  %d/%d %s" % [f.display_name, f.class_id, f.hp, f.max_hp, "" if f.is_alive() else "阵亡 DEAD"])
	_hud.text = "\n".join(lines)
	var b := match_node.boss
	var show_boss := b != null and is_instance_valid(b) and b.is_inside_tree() and match_node.boss_brain != null \
		and is_instance_valid(match_node.boss_brain)
	_boss_bar.visible = show_boss
	_boss_label.visible = show_boss
	if show_boss:
		var bb := match_node.boss_brain
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp
		var tag := ""
		if bb.enraged:
			tag = "  红血狂暴 ENRAGED"
		elif bb.break_left > 0.0:
			tag = "  破防 BROKEN"
		elif not bb.channel.is_empty():
			tag = "  引导中 CHANNELING - 打断 INTERRUPT!"
		_boss_label.text = "%s   阶段 Phase %d   %d%%%s" % [b.display_name, bb.phase + 1, roundi(b.hp / b.max_hp * 100.0), tag]


func _physics_process(_delta: float) -> void:
	if god and match_node != null:
		var p := world.local_fighter()
		if p != null and p.is_alive() and p.hp < p.max_hp:
			p.hp = p.max_hp


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or match_node == null:
		return
	match (e as InputEventKey).keycode:
		KEY_F1:
			match_node.debug_skip_to(match_node.encounters.size() - 1)
		KEY_F2:
			for f: Variant in match_node.enc_mobs.get(match_node.current, []):
				if is_instance_valid(f) and (f as Fighter).is_alive():
					(f as Fighter).kill(world.local_fighter())
			if match_node.enc_state[match_node.current] == "idle":
				match_node.enc_state[match_node.current] = "active"
		KEY_F3:
			get_tree().reload_current_scene()
		KEY_F4:
			god = not god
		KEY_F5:
			var ids := RaidRegistry.ids()
			chosen_raid = ids[(ids.find(raid_id) + 1) % ids.size()]
			get_tree().reload_current_scene()


# ---------------------------------------------------------------- screenshots
func _shot() -> void:
	var view := str(_args.get("view", "start"))
	var encs := map.get_encounters()
	var boss_pos: Vector3 = encs[encs.size() - 1]["pos"]
	if view.begins_with("boss"):
		match_node.debug_skip_to(encs.size() - 1)
	if view != "play":
		_shot_cam = Camera3D.new()
		_shot_cam.fov = 70.0
		add_child(_shot_cam)
		_shot_cam.current = true
		var cp := map.get_checkpoint(-1)
		match view:
			"start":
				_look(cp + Vector3(0, 4.0, 5.5), cp + Vector3(0, 1, -14))
			"room1":
				var p: Vector3 = encs[0]["pos"]
				_look(p + Vector3(-7, 6, 13), p + Vector3(0, 0, -2))
			"room2":
				var p: Vector3 = encs[1]["pos"]
				_look(p + Vector3(8, 7, 12), p + Vector3(0, 0, -2))
			"boss":
				_look(boss_pos + Vector3(0, 9, 22), boss_pos + Vector3(0, 1, -2))
			"boss_close":
				_look(boss_pos + Vector3(4, 3.5, 8.5), boss_pos + Vector3(0, 2.5, 0))
			"overview":
				var c := map.center
				_shot_cam.fov = 60.0
				_look(c + Vector3(55, 75, 30), c + Vector3(0, 0, -5))
	if view == "boss_activate":
		match_node._activate(encs.size() - 1, match_node.party()[0])
	await get_tree().create_timer(float(_args.get("wait", "3.0"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(_args["shot"]))
	print("SHOT saved ", _args["shot"])
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	_shot_cam.global_position = from
	_shot_cam.look_at(at, Vector3.UP)
