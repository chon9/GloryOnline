extends Node3D
## Map preview with a fly camera (scenes/map_preview.tscn).
##   godot --path . res://scenes/map_preview.tscn -- --map=<id>
## Controls: WASD move, Q/E down/up, hold right mouse to look, Shift = fast, 1..5 = preset views,
## N = next map, P = save screenshot to user://map_<id>_<n>.png.
## Screenshot mode (renders every requested view, then quits):
##   godot --path . res://scenes/map_preview.tscn -- --map=<id> --shot=<prefix> [--views=overview,tps,side] [--wait=1.2] [--chars=1]
## Views: overview, tps (third-person from a blue spawn), tps_red, side, top, high (sniper view), custom:x,y,z,tx,ty,tz

const VIEWS: Array[String] = ["overview", "tps", "side", "high", "top"]

var map: MapBase
var cam: Camera3D
var _args: Dictionary = {}
var _label: Label
var _look := false
var _yaw := 0.0
var _pitch := -0.4
var _map_ids: Array[String] = []
var _map_index := 0
var _shot_n := 0
var _chars: Array[Node3D] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	for d: Dictionary in MapRegistry.list("all"):
		_map_ids.append(str(d["id"]))
	var id: String = _args.get("map", "classic_arena")
	_map_index = maxi(0, _map_ids.find(id))
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	cl.add_child(_label)
	_load_map(id)
	if _args.has("shot"):
		_shots.call_deferred()


func _load_map(id: String) -> void:
	if map != null:
		map.queue_free()
		map = null
	for c in _chars:
		c.queue_free()
	_chars.clear()
	map = MapRegistry.create(id)
	if map == null:
		_label.text = "未知地图 Unknown map: " + id
		return
	add_child(map)
	map.build()
	_set_view("overview")
	_update_label()
	if _args.get("chars", "1") == "1":
		_place_chars.call_deferred()


func _place_chars() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if map == null or not ClassDB.class_exists("Node3D"):
		return
	var classes := [["knight", "knight_sword", "shield"], ["blade_master", "lightsaber", ""], ["sharpshooter", "revolver", ""],
		["cleric", "cross", ""], ["berserker", "greatsword", ""]]
	for team in [0, 1]:
		var pts := map.get_spawn_points(team)
		var yaw := map.get_spawn_yaw(team)
		for i in mini(pts.size(), 3):
			var c: Array = classes[(i + team * 2) % classes.size()]
			var v := CharacterVisual.create_for_class(c[0], c[1], c[2], ArenaMap.TEAM_COLORS[team])
			v.position = _ground(pts[i])
			v.rotation.y = yaw
			add_child(v)
			_chars.append(v)


func _ground(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -30, 0), CoreUtil.LAYER_WORLD)
	var r := space.intersect_ray(q)
	return r["position"] if not r.is_empty() else p


func _update_label() -> void:
	if map == null:
		return
	_label.text = "%s %s  [%s]  %dx%d m\nWASD/QE 移动 move, 右键 RMB look, 1-5 视角 views, N 下一张 next map, P 截图 screenshot" % [
		map.name_cn, map.name_en, map.map_id, int(map.size.x), int(map.size.y)]


func _set_view(view: String) -> void:
	if map == null:
		return
	var s := maxf(map.size.x, map.size.y)
	var c := map.center
	var blue := map.get_spawn_points(0)
	var bc := Vector3.ZERO
	for p in blue:
		bc += p
	bc /= maxf(1.0, blue.size())
	var red := map.get_spawn_points(1)
	var rc := Vector3.ZERO
	for p in red:
		rc += p
	rc /= maxf(1.0, red.size())
	var pos := Vector3.ZERO
	var target := c
	match view:
		"overview":
			pos = c + Vector3(s * 0.55, s * 0.62, s * 0.75)
		"tps":
			var d := CoreUtil.flat_dir(c - bc)
			pos = bc - d * 4.5 + Vector3(0, 3.6, 0)
			target = bc + d * 12.0 + Vector3(0, 1.0, 0)
		"tps_red":
			var d := CoreUtil.flat_dir(c - rc)
			pos = rc - d * 4.5 + Vector3(0, 3.6, 0)
			target = rc + d * 12.0 + Vector3(0, 1.0, 0)
		"side":
			pos = c + Vector3(-s * 0.62, s * 0.22, s * 0.05)
			target = c + Vector3(0, 0.5, 0)
		"high":
			pos = c + Vector3(s * 0.05, s * 0.35, -s * 0.62)
			target = c + Vector3(0, 0, s * 0.1)
		"top":
			pos = c + Vector3(0, s * 1.25, 0.01)
		_:
			if view.begins_with("custom:"):
				var f := view.substr(7).split(",")
				if f.size() >= 6:
					pos = Vector3(float(f[0]), float(f[1]), float(f[2]))
					target = Vector3(float(f[3]), float(f[4]), float(f[5]))
	cam.position = pos
	cam.look_at(target)
	_yaw = cam.rotation.y
	_pitch = cam.rotation.x


func _shots() -> void:
	var wait := float(_args.get("wait", "1.2"))
	var views: PackedStringArray = str(_args.get("views", "overview,tps,side")).split(";" if str(_args.get("views", "")).contains(";") else ",")
	await get_tree().create_timer(wait).timeout
	for v in views:
		_set_view(v)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var name_part := v.replace(":", "_").replace(",", "_")
		if name_part.length() > 24:
			name_part = name_part.substr(0, 24)
		var path := "%s_%s.png" % [_args["shot"], name_part]
		img.save_png(path)
		print("SHOT saved ", path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_look = (event as InputEventMouseButton).pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _look:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.004
		_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.5, 1.5)
		cam.rotation = Vector3(_pitch, _yaw, 0)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_5:
			_set_view(VIEWS[k - KEY_1])
		elif k == KEY_N and _map_ids.size() > 0:
			_map_index = (_map_index + 1) % _map_ids.size()
			_load_map(_map_ids[_map_index])
		elif k == KEY_P:
			_shot_n += 1
			var path := "user://map_%s_%d.png" % [map.map_id if map else "none", _shot_n]
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT saved ", ProjectSettings.globalize_path(path))


func _process(delta: float) -> void:
	if _args.has("shot"):
		return
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		v.z -= 1
	if Input.is_key_pressed(KEY_S):
		v.z += 1
	if Input.is_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_key_pressed(KEY_D):
		v.x += 1
	if Input.is_key_pressed(KEY_E):
		v.y += 1
	if Input.is_key_pressed(KEY_Q):
		v.y -= 1
	if v != Vector3.ZERO:
		var spd := 30.0 if Input.is_key_pressed(KEY_SHIFT) else 10.0
		cam.position += cam.global_transform.basis * v.normalized() * spd * delta
