extends SceneTree
## MAPS headless tests: every arena builds, spawns are valid, ramps/bridges are walkable, lava hurts,
## builds are deterministic, registry works.
##   godot --headless --path . -s res://tests/test_maps_build.gd

const DT: float = 1.0 / 60.0
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var passed: int = 0
var failed: int = 0
var world: World = null
var map: MapBase = null


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	var kit: ClassKit = (load(KIT_PATH) as Script).new()
	var reg := root.get_node_or_null("Registry")
	if reg != null:
		reg.call("register_kit", kit)
	_test_registry()
	for d: Dictionary in MapRegistry.list("arena"):
		await _test_map(str(d["id"]))
	await _test_determinism()
	await _test_lava()
	await _test_blossoms_bridge()
	_cleanup()
	await process_frame
	print("MAPS TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


func _cleanup() -> void:
	if map != null and is_instance_valid(map):
		map.get_parent().remove_child(map)
		map.free()
	map = null
	if world != null and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()
	world = null


func _setup(id: String) -> bool:
	_cleanup()
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	map = MapRegistry.create(id)
	if map == null:
		return false
	world.add_child(map)
	map.build()
	map.apply_to_world(world)
	await physics_frame
	await physics_frame
	return true


func _test_registry() -> void:
	var l := MapRegistry.list()
	check(l.size() >= 4, "registry lists >= 4 arenas", str(l.size()))
	var ok := true
	for d: Dictionary in l:
		for k in ["id", "name_cn", "name_en", "modes", "script"]:
			ok = ok and d.has(k)
	check(ok, "registry entries have id/name_cn/name_en/modes/script")
	check(MapRegistry.for_mode("duel").size() >= 2 and MapRegistry.for_mode("team").size() >= 2, "maps exist for duel and team")
	check(MapRegistry.create("no_such_map_xyz") == null, "unknown id returns null")


func _test_map(id: String) -> void:
	var ok: bool = await _setup(id)
	check(ok and map != null, "[%s] creates" % id)
	if not ok:
		return
	check(map.map_id == id and map.name_cn != "" and map.name_en != "", "[%s] id and bilingual names" % id)
	check(map.size.x >= 30.0 and map.size.x <= 70.0 and map.size.y >= 30.0 and map.size.y <= 70.0, "[%s] size sane" % id, str(map.size))
	var b := world.bounds
	check(is_equal_approx(b.size.x, map.size.x) and is_equal_approx(b.size.z, map.size.y), "[%s] apply_to_world sets bounds" % id, str(b))
	# collision body
	var body := map.find_child("WorldCollision", true, false) as StaticBody3D
	var nshapes := 0
	if body != null:
		for c in body.get_children():
			if c is CollisionShape3D:
				nshapes += 1
	check(body != null and body.collision_layer == CoreUtil.LAYER_WORLD and nshapes > 5, "[%s] world collision on LAYER_WORLD" % id, "%d shapes" % nshapes)
	# environment and lights
	check(map.find_children("*", "WorldEnvironment", true, false).size() == 1, "[%s] has WorldEnvironment" % id)
	check(map.find_children("*", "DirectionalLight3D", true, false).size() >= 1, "[%s] has DirectionalLight3D" % id)
	var omni := map.find_children("*", "OmniLight3D", true, false).size()
	check(omni >= 1 and omni <= 16, "[%s] a few omni lights" % id, str(omni))
	# art migration: painted look-dev environment, no KayKit tile pieces, one zone atmosphere
	var painted := map.find_child("PaintedGeometry", true, false)
	check(painted != null and painted.get_child_count() >= 5, "[%s] painted environment batches built" % id,
		str(painted.get_child_count() if painted != null else 0))
	check(map is ArenaMap and (map as ArenaMap).kit.piece_count == 0, "[%s] no KayKit tile pieces left" % id)
	var we := map.find_children("*", "WorldEnvironment", true, false)
	var sky_ok := false
	if we.size() == 1:
		var e := (we[0] as WorldEnvironment).environment
		sky_ok = e.sky != null and e.sky.sky_material is ShaderMaterial and e.fog_enabled and e.glow_enabled
	check(sky_ok, "[%s] painted sky + fog + glow grading" % id)
	var draws := map.find_children("*", "GeometryInstance3D", true, false).size()
	check(draws <= 160, "[%s] draw-call budget (geometry nodes <= 160)" % id, str(draws))
	# ramps <= 35 degrees
	var steep := ""
	if body != null:
		for c in body.get_children():
			if c is CollisionShape3D and str(c.name).begins_with("Ramp") and not str(c.name).begins_with("RampFill"):
				var up := (c as CollisionShape3D).global_transform.basis.y.normalized()
				var ang := rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
				if ang > 35.0:
					steep += "%s=%.1f " % [c.name, ang]
	check(steep == "", "[%s] ramps <= 35 deg" % id, steep)
	# spawns
	var space := world.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = Fighter.BODY_RADIUS
	cap.height = Fighter.BODY_HEIGHT
	var centroids: Array[Vector3] = []
	for team in [0, 1]:
		var pts := map.get_spawn_points(team)
		check(pts.size() >= 5, "[%s] team %d has >= 5 spawn points" % [id, team], str(pts.size()))
		if pts.size() >= 5:
			var cen := Vector3.ZERO
			for q in pts:
				cen += q
			cen /= pts.size()
			check(Vector2(pts[0].x - cen.x, pts[0].z - cen.z).length() < 0.5, "[%s] team %d spawn 0 is the centre of the line" % [id, team], str(pts[0]))
		var bad_ground := ""
		var bad_wall := ""
		var bad_bounds := ""
		var c := Vector3.ZERO
		for p in pts:
			c += p
			var r := world.raycast(p + Vector3(0, 1.0, 0), p + Vector3(0, -6.0, 0))
			if r.is_empty() or absf((r["position"] as Vector3).y - (p.y - 0.3)) > 0.5 or (r["normal"] as Vector3).y < 0.85:
				bad_ground += str(p) + " "
			var gy: float = (r["position"] as Vector3).y if not r.is_empty() else p.y
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.collision_mask = CoreUtil.LAYER_WORLD
			q.transform = Transform3D(Basis(), Vector3(p.x, gy + Fighter.BODY_HEIGHT * 0.5 + 0.08, p.z))
			if space.intersect_shape(q, 4).size() > 0:
				bad_wall += str(p) + " "
			if not world.bounds.has_point(p):
				bad_bounds += str(p) + " "
		check(bad_ground == "", "[%s] team %d spawns have flat ground underneath" % [id, team], bad_ground)
		check(bad_wall == "", "[%s] team %d spawns not inside geometry" % [id, team], bad_wall)
		check(bad_bounds == "", "[%s] team %d spawns inside bounds" % [id, team], bad_bounds)
		c /= maxf(1.0, pts.size())
		centroids.append(c)
		var face := CoreUtil.dir_of_yaw(map.get_spawn_yaw(team))
		check(face.dot(CoreUtil.flat_dir(map.center - c)) > 0.7, "[%s] team %d spawn yaw faces the center" % [id, team])
	var min_sep := INF
	for a in map.get_spawn_points(0):
		for bpt in map.get_spawn_points(1):
			min_sep = minf(min_sep, a.distance_to(bpt))
	check(min_sep >= 15.0, "[%s] team spawns separated (>= 15 m)" % id, "%.1f" % min_sep)
	# team markers
	var markers := 0
	for n in map.get_children():
		if str(n.name).begins_with("SpawnMarker"):
			markers += 1
	check(markers >= 10, "[%s] team spawn markers present" % id, str(markers))
	# fighters drop at every spawn, land, and can walk 5 m
	var land_bad := ""
	var walk_bad := ""
	for team in [0, 1]:
		var yaw := map.get_spawn_yaw(team)
		for p in map.get_spawn_points(team):
			var f := world.spawn_fighter({"kind": "bot", "class_id": "test_dummy", "team": team, "pos": p, "yaw": yaw})
			await _sim(0.6)
			if not f.is_on_floor() or absf(f.global_position.y - (p.y - 0.3)) > 0.4:
				land_bad += "%s->%s " % [p, f.global_position]
			var start := f.global_position
			var walked := false
			for k in 8:
				var dir := CoreUtil.dir_of_yaw(yaw + TAU * k / 8.0)
				f.global_position = start
				f.velocity = Vector3.ZERO
				f.input.move = dir
				await _sim(1.2)
				f.input.move = Vector3.ZERO
				if CoreUtil.flat(f.global_position - start).length() >= 5.0 and f.is_on_floor():
					walked = true
					break
			if not walked:
				walk_bad += str(p) + " "
			world.fighters.erase(f)
			world.by_uid.erase(f.uid)
			f.get_parent().remove_child(f)
			f.free()
	check(land_bad == "", "[%s] fighters land on every spawn" % id, land_bad)
	check(walk_bad == "", "[%s] fighters can walk 5 m from every spawn" % id, walk_bad)
	# designer routes (ramps, bridges, doorways)
	if map is ArenaMap:
		for w: Dictionary in (map as ArenaMap).test_walks:
			var res: Array = await _walk(w["from"], w["to"])
			var reached: bool = res[0]
			var fy: float = res[1]
			check(reached and fy >= float(w["min_y"]), "[%s] route '%s' walkable" % [id, w["name"]],
				"reached=%s y=%.2f need %.2f end=%s" % [reached, fy, float(w["min_y"]), res[2]])


## Walks a fresh fighter from `from` toward `to` (steering each step). Returns [reached, final_y, final_pos].
func _walk(from: Vector3, to: Vector3) -> Array:
	var f := world.spawn_fighter({"kind": "bot", "class_id": "test_dummy", "team": 0, "pos": from + Vector3(0, 0.3, 0)})
	await _sim(0.4)
	var reached := false
	await physics_frame
	for i in roundi(9.0 / DT):
		var d := CoreUtil.flat(to - f.global_position)
		if d.length() < 0.8:
			reached = true
			break
		f.input.move = d.normalized()
		world.step(DT)
	f.input.move = Vector3.ZERO
	await _sim(0.3)
	var out := [reached, f.global_position.y, f.global_position]
	world.fighters.erase(f)
	world.by_uid.erase(f.uid)
	f.get_parent().remove_child(f)
	f.free()
	return out


func _sim(seconds: float) -> void:
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)


func _test_determinism() -> void:
	for d: Dictionary in MapRegistry.list("arena"):
		var id := str(d["id"])
		var a := MapRegistry.create(id)
		var b := MapRegistry.create(id)
		root.add_child(a)
		root.add_child(b)
		a.build()
		b.build()
		var fa := str(a.call("fingerprint")) if a.has_method("fingerprint") else ""
		var fb := str(b.call("fingerprint")) if b.has_method("fingerprint") else "x"
		check(fa == fb and fa != "", "[%s] deterministic build" % id, fa + " vs " + fb)
		check(a.get_spawn_points(0) == b.get_spawn_points(0) and a.get_spawn_points(1) == b.get_spawn_points(1), "[%s] deterministic spawns" % id)
		root.remove_child(a)
		root.remove_child(b)
		a.free()
		b.free()
		await process_frame


func _test_lava() -> void:
	var ok: bool = await _setup("lava_cave")
	if not ok:
		check(false, "lava map loads")
		return
	var lava_pos := Vector3(-19.0, 0.3, 0.0)
	var safe_pos := Vector3(0.0, 0.3, -16.0)
	var hot := world.spawn_fighter({"kind": "bot", "class_id": "test_dummy", "team": 0, "pos": lava_pos})
	var cold := world.spawn_fighter({"kind": "bot", "class_id": "test_dummy", "team": 1, "pos": safe_pos})
	var hp0 := hot.hp
	for i in 90:
		await physics_frame
		world.step(DT)
	check(hot.hp < hp0 - hot.max_hp * 0.05, "[lava_cave] lava burns fighters standing in it", "%.0f -> %.0f" % [hp0, hot.hp])
	check(is_equal_approx(cold.hp, cold.max_hp), "[lava_cave] safe ground does not burn")
	check(map.has_method("is_hazard") and bool(map.call("is_hazard", lava_pos)), "[lava_cave] is_hazard true in lava")
	check(not bool(map.call("is_hazard", safe_pos)) and not bool(map.call("is_hazard", Vector3(-19.0, 3.0, 0.0))), "[lava_cave] is_hazard false on safe ground / above lava")


func _test_blossoms_bridge() -> void:
	var ok: bool = await _setup("hundred_blossoms")
	if not ok:
		check(false, "blossoms map loads")
		return
	var bad := ""
	for p: Vector3 in [Vector3(0, 0, -1), Vector3(5, 0, 0.5), Vector3(-6, 0, 0), Vector3(0, 0, 0)]:
		var gy := world.ground_y(p)
		if absf(gy) > 0.15:
			bad += "%s->%.2f " % [p, gy]
	check(bad == "", "[hundred_blossoms] ground_y under the bridge is the valley floor", bad)
	check(absf(world.ground_y(Vector3(0, 4.5, 0)) - 4.5) < 0.15, "[hundred_blossoms] ground_y on the bridge deck is the deck")
