extends Node3D
## Asset showcase: all 25 class bodies with their weapons, plus mobs and bosses.
## Keys: Left/Right = cycle animation key, 1..4 = camera views, F = fire sample effects, S = toggle statuses.
## Screenshot mode (used by the ASSETS verification):
##   godot --path . res://scenes/gallery.tscn -- --shot=<png> [--view=<view>] [--anim=<key>] [--wait=<sec>] [--status=<mask>]
## Views: front, mobs, close:<i>, one:<i>, group:<i> (4 classes), mobgroup:<i>, models:<page>, fx, fxclose, areas,
## proj, perf (10 fighters + continuous effects, prints average FPS). Debug: --axes=1 (handslot axis gizmos),
## --gunyaw=<deg>.

const CLASS_ORDER: Array[String] = ["blade_master", "berserker", "spellblade", "ghostblade", "battle_mage", "elementalist",
	"witch", "summoner", "sharpshooter", "spitfire", "launcher", "mechanic", "striker", "qi_master", "grappler", "brawler",
	"assassin", "ninja", "thief", "warlock", "knight", "exorcist", "cleric", "paladin", "unspecialized"]
## Fallback weapon per class (Registry kits are authoritative when present).
const CLASS_WEAPON: Dictionary = {
	"blade_master": ["lightsaber", ""], "berserker": ["greatsword", ""], "spellblade": ["short_sword", ""], "ghostblade": ["tachi", ""],
	"battle_mage": ["battle_lance", ""], "elementalist": ["staff", ""], "witch": ["broom", ""], "summoner": ["staff_ring", ""],
	"sharpshooter": ["revolver", ""], "spitfire": ["auto_pistol", "grenade"], "launcher": ["hand_cannon", ""], "mechanic": ["rifle", "mech_box"],
	"striker": ["gloves", ""], "qi_master": ["gloves_qi", ""], "grappler": ["tonfa", ""], "brawler": ["claws", ""],
	"assassin": ["dual_swords", ""], "ninja": ["ninjato", ""], "thief": ["dagger", ""], "warlock": ["cane", ""],
	"knight": ["knight_sword", "shield"], "exorcist": ["war_scythe", ""], "cleric": ["cross", ""], "paladin": ["great_axe", ""],
	"unspecialized": ["umbrella", ""],
}
const MOBS: Array[String] = ["skeleton_minion", "skeleton_warrior", "skeleton_rogue", "skeleton_mage", "necromancer", "werewolf", "orc_raider"]
const BOSSES: Array[String] = ["black_knight", "frost_golem", "orc_brute", "monstrosity", "skeleton_golem"]

var visuals: Array[CharacterVisual] = []
var mob_visuals: Array[CharacterVisual] = []
var cam: Camera3D
var anim_keys: Array = []
var anim_index := 0
var status_on := false
var _args: Dictionary = {}
var _label: Label
var _perf := false
var _perf_t := 0.0
var _perf_acc := 0.0
var _perf_frames := 0
var _perf_spawn := 0.0
var _perf_id := 5000
const PERF_KEYS: Array[StringName] = [&"attack_1h_1", &"attack_2h", &"cast", &"run", &"punch_combo", &"shoot_1h", &"attack_spin", &"idle"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	anim_keys = CharacterVisual.ANIM_MAP.keys()
	_build_world()
	_build_lineup()
	_set_view(_args.get("view", "front"))
	if _args.has("anim"):
		_play_all(StringName(_args["anim"]))
	if _args.has("status"):
		var m := int(_args["status"])
		for v in visuals:
			v.set_status_visual(m)
	if _args.has("axes"):
		for v in visuals:
			v.set_weapon("", "")
			for att in v.skeleton.find_children("Attach_handslot*", "BoneAttachment3D", false, false):
				att.add_child(_axes())
	if _args.has("gunyaw"):
		for w in find_children("Weapon_*", "Node3D", true, false):
			(w as Node3D).rotation_degrees.y = float(_args["gunyaw"])
	if _args.has("shot"):
		_take_shot.call_deferred()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.11, 0.12, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.68)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_bloom = 0.1
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-30), 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(150), 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.6, 0.7, 1.0)
	add_child(fill)
	# dungeon tile floor
	var tile: PackedScene = load("res://assets/env/dungeon/floor_tile_large.gltf")
	for x in range(-8, 9):
		for z in range(-5, 3):
			var t := tile.instantiate() as Node3D
			t.position = Vector3(x * 4.0, 0, z * 4.0)
			add_child(t)
	for i in 6:
		var p: Node3D = (load("res://assets/env/dungeon/pillar_decorated.gltf") as PackedScene).instantiate()
		p.position = Vector3(-30 + i * 12, 0, -16)
		add_child(p)
		var tl: Node3D = (load("res://assets/env/dungeon/torch_lit.gltf") as PackedScene).instantiate()
		tl.position = Vector3(-24 + i * 12, 0, -15)
		add_child(tl)
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	cl.add_child(_label)


func _class_weapon(cid: String) -> Array:
	var reg := get_node_or_null("/root/Registry")
	if reg and reg.has_method("get_kit"):
		var kit: Variant = reg.call("get_kit", cid)
		if kit is Object and kit != null:
			return [kit.get("weapon_type"), kit.get("offhand")]
	return CLASS_WEAPON[cid]


func _build_lineup() -> void:
	for i in CLASS_ORDER.size():
		var cid := CLASS_ORDER[i]
		var w := _class_weapon(cid)
		var v := CharacterVisual.create_for_class(cid, w[0], w[1])
		var row := i / 13
		var col := i % 13
		v.position = Vector3((col - 6) * 2.3 + row * 1.15, 0, row * -3.2)
		v.rotation.y = PI
		add_child(v)
		visuals.append(v)
		var lab := Label3D.new()
		lab.text = cid
		lab.font_size = 36
		lab.pixel_size = 0.004
		lab.position = Vector3(0, 0.25, -0.95)
		lab.rotation = Vector3(-PI / 2.0, PI, 0)
		v.add_child(lab)
	var all := MOBS + BOSSES
	for i in all.size():
		var id: String = all[i]
		var v := CharacterVisual.create(id, CharacterVisual.MOB_WEAPONS.get(id, ""), "skeleton_shield" if id == "skeleton_warrior" else ("black_knight_shield" if id == "black_knight" else ""), Color.WHITE)
		var x := -14.0 + i * 2.6 + (maxf(0, i - MOBS.size() + 1) * 2.4)
		v.position = Vector3(x, 0, -9.5)
		v.rotation.y = PI
		add_child(v)
		mob_visuals.append(v)


func _set_view(view: String) -> void:
	if view == "front":
		cam.position = Vector3(0, 6.5, 21.0)
		cam.look_at(Vector3(0, 1.0, -1.5))
	elif view == "mobs":
		cam.position = Vector3(4, 5.5, 6)
		cam.look_at(Vector3(4, 1.5, -9.5))
	elif view.begins_with("close:"):
		var i := int(view.substr(6))
		var v := visuals[clampi(i, 0, visuals.size() - 1)]
		var c := v.position + Vector3(2.3 * 1.5, 1.0, 0)
		cam.position = c + Vector3(0.6, 0.6, 5.2)
		cam.look_at(c)
	elif view.begins_with("one:"):
		var i := int(view.substr(4))
		var v := visuals[clampi(i, 0, visuals.size() - 1)]
		cam.position = v.position + Vector3(1.2, 1.3, 2.6)
		cam.look_at(v.position + Vector3(0, 0.95, 0))
	elif view.begins_with("group:") or view.begins_with("mobgroup:"):
		var src: Array[CharacterVisual] = visuals if view.begins_with("group:") else mob_visuals
		var i0 := int(view.get_slice(":", 1))
		for v in visuals + mob_visuals:
			v.visible = false
		var n := 4 if view.begins_with("group:") else 3
		var big := false
		for k in n:
			if i0 + k >= src.size():
				break
			var v := src[i0 + k]
			v.visible = true
			v.position = Vector3((k - (n - 1) * 0.5) * (1.9 if n == 4 else 3.4), 0, 4.0)
			big = big or v.rig == "large"
		var d := 6.0 if big else 5.0
		cam.position = Vector3(0.0, 1.7 if not big else 2.8, 4.0 + d)
		cam.look_at(Vector3(0, 0.95 if not big else 1.8, 4.0))
	elif view.begins_with("models"):
		for v in visuals + mob_visuals:
			v.visible = false
		var ids := CharacterVisual.MODELS.keys()
		var page := int(view.substr(7)) if view.length() > 7 else 0
		ids = ids.slice(page * 18, page * 18 + 18)
		for i in ids.size():
			var v := CharacterVisual.create(ids[i], "", "", Color.WHITE)
			v.position = Vector3((i % 6 - 2.5) * 2.4, 0, 6.0 - (i / 6) * 3.0)
			v.rotation.y = PI
			add_child(v)
			var lab := Label3D.new()
			lab.text = ids[i]
			lab.font_size = 64
			lab.pixel_size = 0.004
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.position = Vector3(0, 2.15, 0)
			v.add_child(lab)
		cam.position = Vector3(0, 5.5, 14.5)
		cam.look_at(Vector3(0, 0.5, 3.0))
	elif view == "fxclose":
		for v in visuals + mob_visuals:
			v.visible = false
		var k := visuals[0]
		k.visible = true
		k.position = Vector3(-3.0, 0, 4.0)
		k.rotation.y = -PI / 2
		k.replay(&"attack_1h_2")
		cam.position = Vector3(0, 3.2, 11.5)
		cam.look_at(Vector3(0, 1.2, 4.0))
		var fx := get_node_or_null("/root/Fx")
		if fx:
			fx.play(&"slash_arc", Vector3(-3.0, 1.1, 4.0), Vector3.RIGHT, Color.WHITE, 1.0)
			fx.play(&"hit_heavy", Vector3(-1.4, 1.1, 4.0), Vector3.RIGHT, Color.WHITE, 1.0)
			fx.play(&"lightning_strike", Vector3(1.0, 0.0, 4.0), Vector3.UP, Color.WHITE, 1.0)
			fx.play(&"explosion", Vector3(3.6, 0.0, 4.0), Vector3.UP, Color.WHITE, 1.0)
			fx.play(&"ultimate_flash", Vector3(6.5, 0.0, 2.0), Vector3.UP, Color.WHITE, 1.0)
			fx.spawn_area_visual(1, "ice", "line", Vector3(-6.0, 0.0, 7.0), -PI / 2, 2.0, 6.0, 1.5, 2.0, 2.0, Color.WHITE)
	elif view == "perf":
		for i in visuals.size():
			visuals[i].visible = i < 10
			if i < 10:
				visuals[i].position = Vector3((i % 5 - 2) * 2.5, 0, (i / 5) * 3.0 + 2.0)
		for v in mob_visuals:
			v.visible = false
		cam.position = Vector3(0, 7, 14)
		cam.look_at(Vector3(0, 0.5, 3))
		_perf = true
	elif view in ["fx", "areas", "proj"]:
		cam.position = Vector3(0, 7.5, 13)
		cam.look_at(Vector3(0, 0.5, 3))
		for v in visuals:
			v.visible = false
		_fx_demo(view)


func _fx_demo(view: String) -> void:
	var fx := get_node_or_null("/root/Fx")
	if fx == null or not fx.has_method("play"):
		return
	if view == "fx":
		var names := ["hit_spark", "hit_heavy", "slash_arc", "launch_burst", "land_dust", "cast_glow", "heal_burst", "buff_aura",
			"debuff_puff", "explosion", "ice_burst", "lightning_strike", "fire_burst", "holy_burst", "dark_burst", "poison_cloud",
			"smoke", "blink", "dash_trail", "summon_circle", "block_spark", "death", "ultimate_flash"]
		for i in names.size():
			var p := Vector3((i % 8 - 3.5) * 2.6, 0.8, (i / 8) * 3.0)
			fx.play(StringName(names[i]), p, Vector3.FORWARD, Color.WHITE, 1.0)
			var lab := Label3D.new()
			lab.text = names[i]
			lab.font_size = 40
			lab.pixel_size = 0.005
			lab.position = p + Vector3(0, -0.7, 0.8)
			add_child(lab)
		fx.damage_number(Vector3(-2, 2.5, 6), 1234, &"phys")
		fx.damage_number(Vector3(0, 2.5, 6), 5678, &"crit")
		fx.damage_number(Vector3(2, 2.5, 6), 900, &"heal")
		fx.damage_number(Vector3(4, 2.5, 6), 0, &"miss")
		fx.damage_number(Vector3(-4, 2.5, 6), 777, &"magic")
	elif view == "areas":
		var vis := ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]
		for i in vis.size():
			var p := Vector3((i % 4 - 1.5) * 6.0, 0.05, (i / 4) * 5.0 - 4.0)
			var shape := "circle" if i % 3 != 2 else ("ring" if i % 2 == 0 else "line")
			var delay := 0.0 if i < 8 else 3.0
			fx.spawn_area_visual(100 + i, vis[i], shape, p, 0.4, 2.2, 5.0, 1.6, delay, 6.0, Color.WHITE)
	elif view == "proj":
		var vis := ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi", "dragon", "lightning", "cannonball", "flask", "scythe"]
		for i in vis.size():
			var p := Vector3(-9.0, 1.2, (i - 7) * 0.9 + 2.0)
			var g := 9.0 if vis[i] in ["grenade", "flask", "cannonball"] else 0.0
			var vy := 4.0 if g > 0.0 else 0.0
			fx.spawn_projectile_visual(200 + i, vis[i], p, Vector3(7.0, vy, 0), g, Color.WHITE, 1.0, 0)


func _axes() -> Node3D:
	var n := Node3D.new()
	var cols := [Color.RED, Color.GREEN, Color.BLUE]
	var dirs := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.06 + dirs[i] * 0.9
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.position = dirs[i] * 0.45
		n.add_child(mi)
	return n


func _play_all(key: StringName) -> void:
	for v in visuals + mob_visuals:
		v.replay(key)
	_label.text = "anim: %s   (Left/Right to cycle)" % key


func _process(delta: float) -> void:
	if not _perf:
		return
	_perf_t += delta
	if _perf_t > 1.0:
		_perf_acc += delta
		_perf_frames += 1
	_perf_spawn -= delta
	var fx := get_node_or_null("/root/Fx")
	if _perf_spawn <= 0.0 and fx:
		_perf_spawn = 0.1
		var fxn := ["hit_spark", "slash_arc", "hit_heavy", "cast_glow", "explosion", "fire_burst", "block_spark", "lightning_strike"]
		for i in 10:
			var v := visuals[i]
			if randf() < 0.35:
				v.replay(PERF_KEYS[randi() % PERF_KEYS.size()])
			if randf() < 0.5:
				fx.play(StringName(fxn[randi() % fxn.size()]), v.global_position + Vector3(0, 1, 0), Vector3.FORWARD, Color.WHITE, 1.0)
			if randf() < 0.3:
				fx.damage_number(v.global_position + Vector3(0, 2, 0), randi() % 900, &"phys" if randf() < 0.8 else &"crit")
		if randf() < 0.5:
			_perf_id += 1
			var pv := ["orb", "bullet", "arrow", "qi", "missile", "dragon", "wave"]
			fx.spawn_projectile_visual(_perf_id, pv[randi() % pv.size()], Vector3(-8, 1.2, randf() * 6), Vector3(14, 0, 0), 0.0, Color.WHITE, 1.0, 0)
		if randf() < 0.1:
			_perf_id += 1
			var av := ["fire", "ice", "lightning", "holy", "poison", "rune"]
			fx.spawn_area_visual(_perf_id, av[randi() % av.size()], "circle", Vector3(randf_range(-5, 5), 0, randf_range(1, 6)), 0.0, 2.5, 0, 0, 0.8, 3.0, Color.WHITE)
	if _perf_t > 9.0 and _perf_frames > 0:
		print("PERF avg fps %.1f over %d frames, live fx nodes %d" % [_perf_frames / _perf_acc, _perf_frames, fx.call("live_count") if fx else -1])
		_perf = false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_RIGHT:
				anim_index = (anim_index + 1) % anim_keys.size()
				_play_all(anim_keys[anim_index])
			KEY_LEFT:
				anim_index = (anim_index - 1 + anim_keys.size()) % anim_keys.size()
				_play_all(anim_keys[anim_index])
			KEY_1:
				_set_view("front")
			KEY_2:
				_set_view("mobs")
			KEY_3:
				_set_view("close:0")
			KEY_F:
				_fx_demo("fx")
			KEY_S:
				status_on = not status_on
				for i in visuals.size():
					visuals[i].set_status_visual((1 << (i % 25)) if status_on else 0)


func _take_shot() -> void:
	var wait := float(_args.get("wait", "1.5"))
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args["shot"])
	print("SHOT saved ", _args["shot"])
	get_tree().quit()
