extends Node3D
## VFX showcase for the anime Fx (every named effect, projectile visual, ground zone / telegraph, damage
## numbers, hit-stop + impact frame) on the look-dev Frost Forest arena.
## Run:   godot --path . res://visuals/vfx_gallery.tscn [-- --view=<view>]
## Shots: godot --path . res://visuals/vfx_gallery.tscn -- --shotdir=<dir> [--view=<view>|all]
##        (writes <dir>/mig_vfx_<view>.png; "all" renders every view in one run)
## Views: melee | magic | elements | proj | ground_circle | ground_line | ground_ring | telegraph | numbers |
##        combat | one:<effect name> | perf (10 fighters spamming skills; prints avg FPS; use --disable-vsync)
## Keys:  1..9 cycle views, Space = replay the current view.

const Y := 1.2
const VIEWS: Array[String] = ["melee", "magic", "elements", "proj", "ground_circle", "ground_line", "ground_ring", "telegraph", "numbers", "combat"]
const HERO_T: Dictionary = {
	&"hit_spark": 0.05, &"hit_heavy": 0.07, &"slash_arc": 0.1, &"launch_burst": 0.1, &"land_dust": 0.22, &"cast_glow": 0.3,
	&"heal_burst": 0.32, &"buff_aura": 0.3, &"debuff_puff": 0.3, &"explosion": 0.12, &"ice_burst": 0.12, &"lightning_strike": 0.05,
	&"fire_burst": 0.2, &"holy_burst": 0.22, &"dark_burst": 0.16, &"poison_cloud": 0.6, &"smoke": 0.45, &"blink": 0.08,
	&"dash_trail": 0.1, &"summon_circle": 0.5, &"block_spark": 0.06, &"death": 0.45, &"ultimate_flash": 0.25,
}
const GROUPS: Dictionary = {
	"melee": [&"slash_arc", &"hit_spark", &"hit_heavy", &"block_spark", &"launch_burst", &"land_dust", &"dash_trail", &"blink"],
	"magic": [&"cast_glow", &"heal_burst", &"buff_aura", &"debuff_puff", &"summon_circle", &"holy_burst", &"dark_burst", &"ultimate_flash"],
	"elements": [&"explosion", &"ice_burst", &"lightning_strike", &"fire_burst", &"poison_cloud", &"smoke", &"death", &"hit_heavy"],
}

var cam: Camera3D
var fx: Node
var _args: Dictionary = {}
var _schedule: Array = []      # [t, Callable]
var _t := 0.0
var _labels: Array[Node] = []
var _chars: Dictionary = {}
var _view_i := 0
var _perf := {"on": false, "t": 0.0, "frames": 0, "acc": 0.0, "spawn": 0.0, "id": 90000, "min_fps": 1e9}
var _fighters: Array[Node3D] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	if _args.has("shotdir") or _args.has("fullhd"):
		get_window().borderless = true
		get_window().position = Vector2i.ZERO
		get_window().size = Vector2i(1920, 1080)
	fx = get_node_or_null("/root/Fx")
	_build_world()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	var view: String = _args.get("view", "combat" if not _args.has("shotdir") else "all")
	if _args.has("shotdir"):
		_shoot.call_deferred(view)
	else:
		_set_view(view)


func _build_world() -> void:
	var env_script: Variant = load("res://lookdev/scripts/environment.gd")
	if env_script is Script and (env_script as Script).can_instantiate():
		(env_script as Script).call("build", self)
	else:
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("#8EC3F0")
		e.glow_enabled = true
		e.tonemap_mode = Environment.TONE_MAPPER_ACES
		we.environment = e
		add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0)
		add_child(sun)
		var fl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 40)
		fl.mesh = pm
		fl.position.y = Y
		add_child(fl)
	# a static floor collider so Fx.ground_y finds the arena
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(0, Y - 0.5, 0)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	var i := _schedule.size() - 1
	while i >= 0:
		if _t >= float(_schedule[i][0]):
			var c: Callable = _schedule[i][1]
			_schedule.remove_at(i)
			c.call()
		i -= 1
	if _perf["on"]:
		_perf_tick(delta)


func _at(t: float, c: Callable) -> void:
	_schedule.append([t, c])


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_9:
			_view_i = (k - KEY_1) % VIEWS.size()
			_set_view(VIEWS[_view_i])
		elif k == KEY_SPACE:
			_set_view(VIEWS[_view_i])


func _shoot(view: String) -> void:
	var dir: String = _args["shotdir"]
	DirAccess.make_dir_recursive_absolute(dir)
	var list: Array = VIEWS if view == "all" else Array(view.split(","))
	await get_tree().create_timer(float(_args.get("wait", "2.0"))).timeout
	for v: String in list:
		var cap_t: float = await _set_view(v)
		while _t < cap_t:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := dir.path_join("mig_vfx_%s.png" % v.replace(":", "_"))
		img.save_png(path)
		print("SHOT saved ", path)
	if fx:
		fx.call("shutdown")
	get_tree().quit()


func _clear() -> void:
	_schedule.clear()
	for l in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()
	for c in _chars.values():
		if is_instance_valid(c):
			(c as Node).queue_free()
	_chars.clear()
	for f in _fighters:
		if is_instance_valid(f):
			f.queue_free()
	_fighters.clear()
	_perf["on"] = false
	if fx:
		fx.call("clear_all")
		fx.set("screen_impact_enabled", false)


func _label(text: String, pos: Vector3, size := 48) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.modulate = Color(1, 1, 1, 0.9)
	l.outline_modulate = Color(0.05, 0.05, 0.1, 0.9)
	l.no_depth_test = true
	add_child(l)
	l.position = pos
	_labels.append(l)


## Sets up a view and returns the capture time (on the gallery clock).
func _set_view(view: String) -> float:
	_clear()
	await get_tree().process_frame
	_t = 0.0
	var cap := 1.0
	if view in GROUPS:
		cap = _group(GROUPS[view])
	elif view.begins_with("one:") or StringName(view) in HERO_T:
		cap = _one(StringName(view.trim_prefix("one:")))
	else:
		match view:
			"proj":
				cap = _proj()
			"ground_circle":
				cap = _ground("circle", false)
			"ground_line":
				cap = _ground("line", false)
			"ground_ring":
				cap = _ground("ring", false)
			"telegraph":
				cap = _ground("mixed", true)
			"numbers":
				cap = _numbers()
			"combat":
				cap = await _combat()
			"perf":
				_perf_setup()
				cap = 1e9
	return cap


func _wide_cam() -> void:
	cam.fov = 46.0
	cam.position = Vector3(0, 5.6, 10.0)
	cam.look_at(Vector3(0, Y + 0.9, -0.4))


func _group(names: Array) -> float:
	_wide_cam()
	var cap := 1.2
	for i in names.size():
		var n: StringName = names[i]
		var col := i % 4
		var row := i / 4
		var p := Vector3(-5.1 + col * 3.4, Y + 1.0, -2.2 + row * 3.6)
		_label(String(n), Vector3(p.x, Y + 3.4, p.z), 40)
		var d := Vector3(1, 0, -0.35).normalized() if n != &"dash_trail" else Vector3(1, 0, 0)
		var at := p
		if n in [&"heal_burst", &"buff_aura", &"holy_burst", &"ultimate_flash", &"death", &"land_dust", &"summon_circle"]:
			at = Vector3(p.x, Y, p.z)
		_at(cap - float(HERO_T.get(n, 0.1)), func() -> void: fx.call("play", n, at, d, Color.WHITE, 1.0))
	return cap


func _one(n: StringName) -> float:
	cam.fov = 40.0
	cam.position = Vector3(-4.2, Y + 2.6, 5.6)
	cam.look_at(Vector3(0, Y + 1.0, 0))
	var at := Vector3(0, Y + 1.0, 0)
	if n in [&"heal_burst", &"buff_aura", &"holy_burst", &"ultimate_flash", &"death", &"land_dust", &"summon_circle"]:
		at = Vector3(0, Y, 0)
	var t := float(_args.get("t", str(HERO_T.get(n, 0.1))))
	_at(1.0 - t, func() -> void: fx.call("play", n, at, Vector3(1, 0, -0.3).normalized(), Color.WHITE, 1.0))
	return 1.0


func _proj() -> float:
	cam.fov = 52.0
	cam.position = Vector3(0, 8.5, 11.0)
	cam.look_at(Vector3(0, Y + 0.6, -0.8))
	var names: Array = fx.get("PROJECTILE_VISUALS")
	var cap := 1.0
	for i in names.size():
		var bank := 0 if i < 8 else 1
		var lane := i if bank == 0 else i - 8
		var z := -5.0 + lane * 1.35
		var x0 := -8.5 if bank == 0 else 0.5
		var from := Vector3(x0, Y + 1.0, z)
		var v: String = names[i]
		_label(v, Vector3(x0 + 2.6, Y + 1.9, z), 32)
		var id := 7000 + i
		_at(0.1, func() -> void: fx.call("spawn_projectile_visual", id, v, from, Vector3(9.0, 0.0, 0.0), 0.0, Color.WHITE, 1.0, 0, 0.0))
	return cap


func _ground(shape: String, telegraph: bool) -> float:
	cam.fov = 50.0
	cam.position = Vector3(0, 10.5, 10.5)
	cam.look_at(Vector3(0, Y, -0.8))
	var names: Array = fx.get("AREA_VISUALS")
	var cap := 1.1 if not telegraph else 1.5
	for i in names.size():
		var col := i % 4
		var row := i / 4
		var p := Vector3(-6.3 + col * 4.2, Y, -4.6 + row * 4.0)
		var v: String = names[i]
		var sh := shape
		if shape == "mixed":
			sh = ["circle", "line", "ring"][i % 3]
		var yaw := 0.0
		var origin := p
		if sh == "line":
			origin = p + Vector3(0, 0, 1.6)
		_label(v, Vector3(p.x, Y + 1.6, p.z), 34)
		var id := 8000 + i
		var dl := 2.4 if telegraph else 0.0
		_at(0.05, func() -> void: fx.call("spawn_area_visual", id, v, sh, origin, yaw, 1.6, 3.4, 1.4, dl, 3.0, Color.WHITE))
	return cap


func _numbers() -> float:
	cam.fov = 40.0
	cam.position = Vector3(0, Y + 2.4, 7.0)
	cam.look_at(Vector3(0, Y + 1.8, 0))
	var kinds := [[&"phys", 1234.0], [&"magic", 2860.0], [&"crit", 12580.0], [&"heal", 3420.0], [&"miss", 0.0], [&"true", 777.0]]
	for i in kinds.size():
		var k: Array = kinds[i]
		var p := Vector3(-3.4 + i * 1.36, Y + 1.2, 0)
		_label(String(k[0]), Vector3(p.x, Y + 0.6, 0), 30)
		_at(0.05, func() -> void: fx.call("damage_number", p, k[1], k[0]))
	return 0.42


## Hero frame like lookdev_4: the slice's three heroes mid-combat, every pillar of the bible's VFX section.
func _combat() -> float:
	var roster: Variant = load("res://lookdev/scripts/roster.gd")
	if not (roster is Script):
		return _group(GROUPS["melee"])
	_chars = (roster as Script).call("spawn", self)
	(roster as Script).call("stage", _chars, "combat")
	await get_tree().process_frame
	await get_tree().process_frame
	var bm: Node3D = _chars["battle_mage"]
	var la: Node3D = _chars["launcher"]
	var wi: Node3D = _chars["witch"]
	for c in _chars.values():
		(c as Node).add_to_group(&"fx_hitstop")
	var vf := bm.global_basis.z.normalized()
	var vs := bm.global_basis.x.normalized()
	cam.fov = 44.0
	cam.position = bm.global_position - vs * 6.2 + vf * 1.2 + Vector3.UP * 1.9
	cam.look_at(bm.global_position + vf * 1.6 + Vector3.UP * 1.3)
	fx.set("screen_impact_enabled", true)
	var to_la := (la.global_position - bm.global_position)
	to_la.y = 0
	var dir := to_la.normalized()
	var blast := bm.global_position + dir * 2.4 + Vector3(0, 1.0, 0)
	var cap := 1.2
	_at(cap - 0.22, func() -> void: fx.call("play", &"cast_glow", wi.global_position + Vector3(0, 0.9, 0), (la.global_position - wi.global_position).normalized(), Color.WHITE, 1.2))
	_at(cap - 0.1, func() -> void: fx.call("play", &"slash_arc", bm.global_position + Vector3(0, 1.0, 0) + vf * 1.2, vf, Color.WHITE, 1.1))
	_at(cap - 0.12, func() -> void: fx.call("play", &"explosion", blast, Vector3.UP, Color.WHITE, 1.0))
	_at(cap - 0.09, func() -> void: fx.call("play", &"hit_heavy", la.global_position + Vector3(0, 1.1, 0), dir, Color.WHITE, 1.0))
	_at(cap - 0.2, func() -> void: fx.call("damage_number", blast + Vector3(0, 1.2, 0) - dir * 1.0, 12580.0, &"crit"))
	_at(cap - 0.15, func() -> void: fx.call("damage_number", blast + Vector3(0.6, 1.0, 0), 2346.0, &"phys"))
	_at(cap - 0.6, func() -> void: fx.call("spawn_projectile_visual", 9100, "star", wi.global_position + Vector3(0, 1.6, 0), (la.global_position - wi.global_position).normalized() * 9.0, 0.0, Color.WHITE, 1.0, 0, 0.0))
	return cap


# ------------------------------------------------------------------ perf: 10 fighters spamming skills

func _perf_setup() -> void:
	cam.fov = 55.0
	cam.position = Vector3(0, 7.5, 13.0)
	cam.look_at(Vector3(0, Y + 0.8, -1.0))
	fx.set("screen_impact_enabled", true)
	var cv: Variant = load("res://visuals/character_visual.gd")
	var classes := ["blade_master", "battle_mage", "launcher", "witch", "qi_master", "knight", "cleric", "ninja", "sharpshooter", "elementalist"]
	for i in 10:
		var n: Node3D = null
		if cv is Script and (cv as Script).can_instantiate():
			n = (cv as Script).call("create_for_class", classes[i], "")
		if n == null:
			n = Node3D.new()
		add_child(n)
		var a := TAU * i / 10.0
		n.position = Vector3(cos(a) * 5.0, Y, sin(a) * 4.0 - 0.5)
		n.add_to_group(&"fx_hitstop")
		if n.has_method("play"):
			n.call("play", &"idle")
		_fighters.append(n)
	var real := _fighters.filter(func(n: Node3D) -> bool: return n.has_method("play")).size()
	print("PERF setup: %d / 10 fighters are CharacterVisuals" % real)
	_perf["on"] = true
	_perf["t"] = 0.0
	_perf["frames"] = 0
	_perf["acc"] = 0.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


const PERF_FX: Array[StringName] = [&"slash_arc", &"hit_spark", &"hit_heavy", &"cast_glow", &"explosion", &"fire_burst",
	&"ice_burst", &"lightning_strike", &"heal_burst", &"dark_burst", &"blink", &"land_dust", &"block_spark", &"holy_burst"]
const PERF_ANIMS: Array[StringName] = [&"attack_1h_1", &"attack_2h", &"cast", &"shoot_1h", &"punch_combo", &"run"]


func _perf_tick(delta: float) -> void:
	_perf["t"] += delta
	_perf["spawn"] -= delta
	if _perf["spawn"] <= 0.0:
		_perf["spawn"] = 0.33 / 10.0   # each of 10 fighters acts about every 0.33 s
		var i := randi() % _fighters.size()
		var a := _fighters[i]
		var b := _fighters[(i + 1 + randi() % 9) % _fighters.size()]
		if not is_instance_valid(a) or not is_instance_valid(b):
			return
		var d := (b.global_position - a.global_position)
		d.y = 0.0
		d = d.normalized()
		if a.has_method("play"):
			a.call("play", PERF_ANIMS[randi() % PERF_ANIMS.size()])
		var r := randi() % 10
		var c := a.global_position + Vector3(0, 1.0, 0)
		if r < 5:
			var en: StringName = PERF_FX[randi() % PERF_FX.size()]
			_perf["last"] = en
			fx.call("play", en, c + d * 1.2, d, Color.WHITE, 1.0)
			fx.call("play", &"hit_spark", b.global_position + Vector3(0, 1.0, 0), d, Color.WHITE, 1.0)
			fx.call("damage_number", b.global_position + Vector3(0, 2.0, 0), randf_range(200, 3000), [&"phys", &"magic", &"crit"][randi() % 3])
		elif r < 8:
			var id: int = _perf["id"]
			_perf["id"] = id + 1
			var v: String = (fx.get("PROJECTILE_VISUALS") as Array)[randi() % 15]
			_perf["last"] = "proj " + v
			fx.call("spawn_projectile_visual", id, v, c, d * 12.0, 0.0, Color.WHITE, 1.0, 0, 0.0)
			_at(_t + 0.7, func() -> void: fx.call("despawn", id))
		else:
			var aid: int = _perf["id"]
			_perf["id"] = aid + 1
			var av: String = (fx.get("AREA_VISUALS") as Array)[randi() % 11]
			_perf["last"] = "area " + av
			fx.call("spawn_area_visual", aid, av, ["circle", "line", "ring"][randi() % 3], b.global_position, randf() * TAU, 2.5, 5.0, 1.6, 0.8, 2.0, Color.WHITE)
	if _perf["t"] > 2.0:
		_perf["acc"] += delta
		_perf["frames"] += 1
		_perf["min_fps"] = minf(_perf["min_fps"], 1.0 / maxf(delta, 1e-4))
		if delta > 0.034:
			_perf["hitches"] = int(_perf.get("hitches", 0)) + 1
			if _args.has("verbose"):
				print("  hitch %.1f ms at t=%.2f (last: %s)" % [delta * 1000.0, _perf["t"], _perf.get("last", "")])
	if _perf["t"] > 12.0:
		var vr := get_viewport().get_viewport_rid()
		print("PERF vfx avg fps %.1f over %d frames (min %.1f, %d frames > 34 ms), 10 fighters + VFX spam, live fx %d, render cpu %.2f ms, gpu %.2f ms, draw calls %d, primitives %d" % [
			_perf["frames"] / _perf["acc"], _perf["frames"], _perf["min_fps"], int(_perf.get("hitches", 0)), int(fx.call("live_count")),
			RenderingServer.viewport_get_measured_render_time_cpu(vr), RenderingServer.viewport_get_measured_render_time_gpu(vr),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		_perf["on"] = false
		if _args.has("quit"):
			fx.call("shutdown")
			get_tree().quit()
