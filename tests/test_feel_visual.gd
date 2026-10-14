extends SceneTree
## Visual-glitch regressions (feelfix, verifier round 2):
##   1. raid follow: BotBrain._detour_around never routes a bot through the 1.3 m keep-out around the human.
##   2. nameplates: HUD panels in HudWorldOverlay.keep_out are reported as occupied rects (plates never under them).
##   3. Frost Forest: its invisible edge walls are camera-transparent ("Bound*"), solid for fighters.
##   4. vfx_solid / vfx_outline dissolve: fine noise, and the dark outline hull is dropped once the dissolve starts.
## Run: godot --headless --path K:/Project/RONGYAO -s res://tests/test_feel_visual.gd

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
	await test_detour()
	await test_keep_out()
	await test_frost_edges()
	test_dissolve_source()
	print("FEEL VISUAL TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Distance from `c` to the polyline p -> wp -> goal (flat).
static func _path_clearance(p: Vector3, wp: Vector3, goal: Vector3, c: Vector3) -> float:
	var best := INF
	for seg: Array in [[p, wp], [wp, goal]]:
		var a: Vector3 = CoreUtil.flat(seg[0])
		var b: Vector3 = CoreUtil.flat(seg[1])
		var cc := CoreUtil.flat(c)
		var ab := b - a
		var t := 0.0 if ab.length_squared() < 1e-6 else clampf((cc - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(cc))
	return best


func test_detour() -> void:
	var world := World.new()
	world.auto_step = false
	root.add_child(world)
	await process_frame
	var bot := world.spawn_fighter({"kind": "bot", "team": 0, "pos": Vector3(0, 0, 3)})
	var b := BotBrain.new()
	b.setup(bot, "raid")
	var human := Vector3.ZERO
	var r := BotBrain.FOLLOW_KEEP_OUT
	# straight through the human: detoured to the side
	var goal := Vector3(0.3, 0, -3)
	var wp := b._detour_around(goal, human, r)
	check(wp != goal, "a walk through the human is detoured")
	check(_path_clearance(bot.global_position, wp, goal, human) >= r - 0.05, "detour keeps the keep-out radius",
		"clearance %.2f" % _path_clearance(bot.global_position, wp, goal, human))
	# path that already passes wide: untouched
	goal = Vector3(4, 0, -3)
	bot.global_position = Vector3(4, 0, 3)
	check(b._detour_around(goal, human, r) == goal, "a clear path is not detoured")
	# inside the circle and heading through the human: steps out on its own side first
	bot.global_position = Vector3(0, 0, 0.6)
	wp = b._detour_around(Vector3(0, 0, -3), human, r)
	check(wp.z > 0.6 and CoreUtil.flat(wp).length() >= r, "inside the circle: steps out away from the human first", str(wp))
	world.queue_free()
	await process_frame


func test_keep_out() -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	root.add_child(host)
	var ov: Control = (load("res://ui/hud_world_overlay.gd") as GDScript).new()
	host.add_child(ov)
	ov.size = Vector2(1920, 1080)
	var panel := Control.new()
	panel.position = Vector2(20, 200)
	panel.size = Vector2(500, 300)
	host.add_child(panel)
	var hidden := Control.new()
	hidden.position = Vector2(1400, 300)
	hidden.size = Vector2(300, 300)
	hidden.visible = false
	host.add_child(hidden)
	var keep: Array[Control] = [panel, hidden]
	ov.set(&"keep_out", keep)
	await process_frame
	var rects: Array = ov.call(&"keep_out_rects")
	check(rects.size() == 1, "only visible keep-out panels are reported", str(rects))
	if rects.size() == 1:
		var r: Rect2 = rects[0]
		check(r.has_point(Vector2(30, 210)) and r.has_point(Vector2(510, 490)), "keep-out rect covers the panel", str(r))
	host.queue_free()
	await process_frame


func test_frost_edges() -> void:
	var dungeon: MapBase = RaidRegistry.create("frost_forest")
	if dungeon == null:
		check(false, "frost_forest dungeon creates")
		return
	root.add_child(dungeon)
	dungeon.build()
	var bounds := 0
	var walls := 0
	for n: Node in dungeon.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is BoxShape3D and is_equal_approx((cs.shape as BoxShape3D).size.y, 6.0):
			walls += 1
			if str(cs.name).begins_with("Bound"):
				bounds += 1
	check(walls > 0 and bounds == walls, "every Frost Forest edge wall is camera-transparent (Bound*)", "%d / %d" % [bounds, walls])
	dungeon.queue_free()
	await process_frame


func test_dissolve_source() -> void:
	var solid := FileAccess.get_file_as_string("res://visuals/shaders/vfx_solid.gdshader")
	var outline := FileAccess.get_file_as_string("res://visuals/shaders/vfx_outline.gdshader")
	check(not solid.contains("v_obj * 22.0"), "vfx_solid dissolve no longer uses the coarse 22/m cells")
	check(solid.contains("edge"), "vfx_solid dissolve has a tinted edge")
	check(outline.contains("fade < 0.97") and not outline.contains("hash3"), "vfx_outline hull is dropped once the dissolve starts")
