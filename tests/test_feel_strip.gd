extends SceneTree
## Regression: "long glitch strip from enemies". The inverted-hull outline (toon_outline.gdshader) used to park
## every vertex beyond its 40 m LOD distance at a fixed clip position, so a hull triangle straddling 40 m stretched
## from the character to the bottom-right screen corner (grey strip from an orc axe, teal from the Frost Golem).
##   1. shader source: no fixed-clip vertex parking; the LOD thins the line continuously.
##   2. cloth: every class's AnimeCloth stays within 1.5x its length of its anchor after a 30 m teleport.
##   3. (rendering only, i.e. NOT --headless) every mob / boss / summon model with its MOB_WEAPONS weapon and
##      every class body, idle and attacking, swept through 36..44 m straight ahead of the camera: nothing may
##      be drawn far from the character, and no rigid MeshInstance3D under a visual may exceed 6 m.
## Run: godot --path K:/Project/RONGYAO -s res://tests/test_feel_strip.gd            (full, renders)
##      godot --headless --path K:/Project/RONGYAO -s res://tests/test_feel_strip.gd (checks 1 + 2 only)

const OUTLINE := "res://visuals/shaders/toon_outline.gdshader"
const BG := Color(0.85, 0.9, 1.0)
const RES := Vector2i(1280, 720)

var passed: int = 0
var failed: int = 0


func check(ok: bool, what: String, info: String = "") -> void:
	if ok:
		passed += 1
		print("PASS: ", what)
	else:
		failed += 1
		print("FAIL: ", what, ("  (" + info + ")") if info != "" else "")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	test_shader_source()
	await test_cloth_teleport()
	if DisplayServer.get_name() != "headless":
		await test_render_sweep()
	else:
		print("SKIP: render sweep (headless)")
	print("STRIP TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_shader_source() -> void:
	var src := FileAccess.get_file_as_string(OUTLINE)
	check(src != "", "outline shader readable")
	var code := ""
	for line in src.split("\n"):
		var i := line.find("//")
		code += (line.substr(0, i) if i >= 0 else line) + "\n"
	var assigns := code.count("POSITION")
	check(assigns == 1 and code.contains("POSITION = clip;"), "outline: single continuous POSITION = clip", "POSITION uses: %d" % assigns)
	check(not code.contains("vec4(2.0, 2.0, 2.0"), "outline: no fixed clip-space vertex parking")
	check(code.contains("cull_dist"), "outline: LOD distance still applied (as a continuous width fade)")


func _visual(id: String) -> CharacterVisual:
	if CharacterVisual.CLASS_MODEL.has(id):
		var reg := root.get_node_or_null("Registry")
		var kit: ClassKit = reg.call("get_kit", id) if reg != null else null
		if kit != null:
			return CharacterVisual.create_for_class(id, kit.weapon_type, kit.offhand)
		return CharacterVisual.create_for_class(id, "")
	return CharacterVisual.create(id, str(CharacterVisual.MOB_WEAPONS.get(id, "")))


func test_cloth_teleport() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var worst := 0.0
	var worst_id := ""
	var n_cloth := 0
	for id: String in CharacterVisual.CLASS_MODEL.keys():
		var v := _visual(id)
		holder.add_child(v)
		v.global_position = Vector3.ZERO
		for i in 3:
			await process_frame
		v.settle_cloth(1.0)
		for i in 10:
			await process_frame
		v.global_position = Vector3(30.0, 0.0, -12.0)
		for i in 6:
			await process_frame
		for c in v.find_children("*", "AnimeCloth", true, false):
			var cl := c as AnimeCloth
			var rig: Skeleton3D = cl.get("_rig")
			if rig == null:
				continue
			n_cloth += 1
			var a := (cl.get_parent() as Node3D).global_transform
			var lim := float(cl.opts.get("length", 1.2)) * a.basis.get_scale().x * 1.5
			for b in rig.get_bone_count():
				var d := rig.get_bone_pose(b).origin.distance_to(a.origin) / maxf(lim, 0.01)
				if d > worst:
					worst = d
					worst_id = "%s/%s" % [id, cl.name]
		v.queue_free()
		await process_frame
	holder.queue_free()
	check(n_cloth > 0, "cloth strips found on class bodies", str(n_cloth))
	check(worst <= 1.0, "cloth stays within 1.5x its length of its anchor after a 30 m teleport", "worst %.2f at %s" % [worst, worst_id])


func test_render_sweep() -> void:
	root.size = RES
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 70.0
	root.add_child(cam)
	cam.global_position = Vector3(0, 1.2, 0)
	cam.current = true
	var ids: Array = CharacterVisual.MODELS.keys()
	ids.append_array(CharacterVisual.CLASS_MODEL.keys())
	var bad: Array[String] = []
	var big: Array[String] = []
	for id: String in ids:
		var v := _visual(id)
		root.add_child(v)
		v.rotation.y = PI
		for key: StringName in [&"idle", &"attack"]:
			v.play(key)
			var dd := 36.0
			while dd <= 44.0:
				v.global_position = Vector3(0, 0, -dd)
				await process_frame
				await RenderingServer.frame_post_draw
				var stray := _stray_pixels(root.get_texture().get_image())
				if stray > 40:
					bad.append("%s %s d=%.1f stray=%d" % [id, key, dd, stray])
				dd += 0.5
		for n in v.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or mi.skin != null or mi is AnimeCloth or not mi.is_visible_in_tree():
				continue
			var ab := mi.global_transform * mi.get_aabb()
			if ab.size.length() > 6.0:
				big.append("%s %s %.1f m" % [id, v.get_path_to(mi), ab.size.length()])
		v.queue_free()
		await process_frame
	check(bad.is_empty(), "no stray outline strips around %d models at 36..44 m (idle + attack)" % ids.size(), ", ".join(bad.slice(0, 8)))
	check(big.is_empty(), "no rigid mesh under a visual larger than 6 m", ", ".join(big.slice(0, 8)))


## Non-background pixels outside a generous box around the screen centre (a character 36+ m away covers < 60 px).
func _stray_pixels(img: Image) -> int:
	var cx := img.get_width() / 2
	var cy := img.get_height() / 2
	var n := 0
	var y := 0
	while y < img.get_height():
		var x := 0
		while x < img.get_width():
			if absi(x - cx) > 140 or absi(y - cy) > 140:
				var c := img.get_pixel(x, y)
				if absf(c.r - BG.r) + absf(c.g - BG.g) + absf(c.b - BG.b) > 0.12:
					n += 1
			x += 4
		y += 4
	return n
