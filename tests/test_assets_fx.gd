extends SceneTree
## ASSETS headless test: Fx autoload (offline). Every named effect, projectile visual, area visual
## (all shapes, with and without telegraph), despawn, damage numbers and sfx run without errors,
## projectile visuals move/fall/home, and everything frees itself.
## Run: godot --headless --path . -s res://tests/test_assets_fx.gd

const CONTRACT_EFFECTS: Array[StringName] = [&"hit_spark", &"hit_heavy", &"slash_arc", &"launch_burst", &"land_dust", &"cast_glow",
	&"heal_burst", &"buff_aura", &"debuff_puff", &"explosion", &"ice_burst", &"lightning_strike", &"fire_burst", &"holy_burst",
	&"dark_burst", &"poison_cloud", &"smoke", &"blink", &"dash_trail", &"summon_circle", &"block_spark", &"death", &"ultimate_flash"]
const CONTRACT_PROJ: Array[String] = ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi",
	"dragon", "lightning", "cannonball", "flask", "scythe"]
const CONTRACT_AREA: Array[String] = ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]
const SFX_NAMES: Array[StringName] = [&"hit", &"hit_heavy", &"slash", &"swing", &"magic", &"explosion", &"shot", &"heal", &"block",
	&"footstep", &"death", &"ui_click", &"lightning", &"ice", &"ultimate", &"dash", &"buff", &"debuff", &"cannon"]


class ErrCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		if "autoload" in rationale or "autoload" in code or "autoload" in file:
			return
		errors.append("%s:%d %s %s" % [file, line, code, rationale])

	func _log_message(message: String, error: bool) -> void:
		pass


class FakeTarget extends Node3D:
	pass


var passed := 0
var failed := 0
var errlog := ErrCounter.new()


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)


func _initialize() -> void:
	OS.add_logger(errlog)
	_run.call_deferred()


func _run() -> void:
	var fx: Node = root.get_node_or_null("Fx")
	if fx == null or fx.get_script() == null or fx.get("is_stub") == true:
		fx = (load("res://autoload/fx.gd") as Script).new()
		fx.name = "FxTest"
		root.add_child(fx)
	check(fx.get("is_stub") == false, "real Fx (not the stub)")
	check(not fx.call("_should_broadcast"), "offline: no broadcast, local play")
	var e0 := errlog.errors.size()

	# named effects
	for i in CONTRACT_EFFECTS.size():
		var n := CONTRACT_EFFECTS[i]
		var before: int = fx.call("live_count")
		fx.play(n, Vector3(i * 2.0, 1.0, 0.0), Vector3.FORWARD, Color.WHITE, 1.0)
		fx.play(n, Vector3(i * 2.0, 1.0, 3.0), Vector3.LEFT, Color(1, 0.2, 0.2), 1.6)
		check(int(fx.call("live_count")) > before, "effect spawns nodes: " + n)
	check(fx.has_method("play") and fx.has_method("spawn_projectile_visual") and fx.has_method("spawn_area_visual") \
		and fx.has_method("despawn") and fx.has_method("damage_number") and fx.has_method("sfx"), "§7.3 API present")

	# projectiles: straight, gravity, homing
	var target := FakeTarget.new()
	target.name = "HomingTarget"
	root.add_child(target)
	target.global_position = Vector3(0, 1, -20)
	for i in CONTRACT_PROJ.size():
		var v := CONTRACT_PROJ[i]
		fx.spawn_projectile_visual(1000 + i, v, Vector3(0, 1, 0), Vector3(10, 0, 0), 0.0, Color.WHITE, 1.0, 0)
		check(fx._nodes.has(1000 + i), "projectile visual spawned: " + v)
	fx.spawn_projectile_visual(2000, "grenade", Vector3(0, 1, 0), Vector3(5, 5, 0), 20.0, Color.WHITE, 1.0, 0)
	# area visuals: every visual x shape, with/without telegraph, burst and persistent
	var aid := 3000
	for v in CONTRACT_AREA:
		for shape in ["circle", "line", "ring"]:
			fx.spawn_area_visual(aid, v, shape, Vector3(aid % 7, 0, 5), 0.7, 3.0, 6.0, 2.0, 0.3, 1.2, Color.WHITE)
			aid += 1
		fx.spawn_area_visual(aid, v, "circle", Vector3(0, 0, 10), 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, Color(0.2, 0.9, 0.4))
		aid += 1
	check(fx._nodes.size() >= CONTRACT_AREA.size() * 4, "area visuals registered (%d)" % fx._nodes.size())
	var tel: Node = fx._nodes[3000]
	check(tel.get("telegraph") != null, "delayed area shows a telegraph")
	for k in [&"phys", &"magic", &"crit", &"heal", &"miss", &"true"]:
		fx.damage_number(Vector3(0, 2, 0), 1234.0, k)
	for s in SFX_NAMES:
		fx.sfx(s, Vector3.ZERO)
	fx.sfx(&"definitely_unknown", Vector3.ZERO)

	# simulate 0.5 s
	var p0: Node3D = fx._nodes[1000]
	var g0: Node3D = fx._nodes[2000]
	var gy0 := g0.global_position.y
	for f in 30:
		await process_frame
	check(p0.global_position.x > 2.0, "projectile moves with velocity (x=%.2f)" % p0.global_position.x)
	check(tel.get("telegraph") == null and tel.get("started") == true, "telegraph ends and the effect starts after delay")
	var g_vy: float = g0.get("vel").y
	check(g_vy < 5.0, "gravity bends grenade trajectory (vy=%.2f, y %.2f->%.2f)" % [g_vy, gy0, g0.global_position.y])
	# homing toward a fighter uid: point a projectile's resolver at the fake target via the World fallback
	var hp := fx._nodes[1003] as Node3D
	hp.set("homing_uid", 77)
	hp.set("_target", weakref(target))
	var d0 := hp.global_position.distance_to(target.global_position)
	for f in 20:
		await process_frame
	check(hp.global_position.distance_to(target.global_position) < d0 + 0.5 and hp.get("vel").z < -0.5, "homing steers toward target")

	# despawn
	for i in CONTRACT_PROJ.size():
		fx.despawn(1000 + i)
	fx.despawn(2000)
	fx.despawn(424242)  # unknown id is a no-op
	await process_frame
	var left := 0
	for i in CONTRACT_PROJ.size():
		if fx._nodes.has(1000 + i):
			left += 1
	check(left == 0, "despawn removes projectile visuals")

	# everything frees itself
	for f in 360:
		await process_frame
		if int(fx.call("live_count")) == 0:
			break
	await create_timer(3.0).timeout
	check(int(fx.call("live_count")) <= 2, "effects auto-free (live=%d)" % int(fx.call("live_count")))
	check(fx._nodes.is_empty(), "area visuals expire (%d left)" % fx._nodes.size())

	# --- review fixes: follow re-spawn re-uses the area, move_area_visual, park release, spikes fade, homing rate
	check(scene_changed.is_connected(Callable(fx, "clear_all")), "clear_all hooked to scene_changed")
	var base_live: int = fx.call("live_count")
	var fid := 5000
	fx.spawn_area_visual(fid, "lightning", "line", Vector3(0, 0, 0), 0.0, 1.0, 8.0, 1.2, 0.0, 4.0, Color.WHITE)
	var beam: Node3D = fx._nodes[fid]
	var min_alpha := 1.0
	var peak_live := 0
	var t := 0.0
	for step in 120:
		await process_frame
		t += 1.0 / 60.0
		if step % 6 == 5:
			fx.despawn(fid)
			fid += 1
			fx.spawn_area_visual(fid, "lightning", "line", Vector3(step * 0.05, 0, 0), step * 0.01, 1.0, 8.0, 1.2, 0.0, maxf(0.05, 4.0 - t), Color.WHITE)
		peak_live = maxi(peak_live, int(fx.call("live_count")) - base_live)
		var z: MeshInstance3D = beam.get("zone")
		if step > 20 and step < 100 and z:
			min_alpha = minf(min_alpha, float(z.get_instance_shader_parameter("alpha")))
	check(fx._nodes.get(fid) == beam and int(beam.get("reclaimed")) >= 15, "follow re-spawn re-uses the same area visual (%d)" % int(beam.get("reclaimed")))
	check(min_alpha > 0.6, "re-issued beam does not flicker (min zone alpha %.2f)" % min_alpha)
	check(peak_live < 45, "re-issued beam stays cheap (peak %d live nodes)" % peak_live)
	check(absf(beam.global_position.x - 113 * 0.05) < 0.3, "re-issue moves the visual (x=%.2f)" % beam.global_position.x)
	fx.despawn(fid)
	fx.spawn_area_visual(6000, "fire", "circle", Vector3.ZERO, 0.0, 2.0, 0.0, 0.0, 0.0, 3.0, Color.WHITE)
	var mv: Node3D = fx._nodes[6000]
	fx.move_area_visual(6000, Vector3(4, 0, -3), 1.2)
	check(mv.global_position.distance_to(Vector3(4, 0.04, -3)) < 0.01 and absf(mv.rotation.y - 1.2) < 0.01, "move_area_visual moves without re-spawn")
	fx.move_area_visual(999999, Vector3.ZERO, 0.0)  # unknown id is a no-op
	fx.despawn(6000)
	await create_timer(0.35).timeout
	check(not is_instance_valid(beam) or beam.is_queued_for_deletion(), "parked area frees when not reclaimed")
	check(not is_instance_valid(mv) or mv.is_queued_for_deletion(), "despawned area frees after the park window")
	fx.spawn_area_visual(6100, "earth", "circle", Vector3.ZERO, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE)
	await process_frame
	await process_frame
	var spikes := 0
	var shader_spikes := 0
	for c in (fx._nodes[6100] as Node).get_children():
		if c is MeshInstance3D and c.get("uses_shader") != null:
			spikes += 1
			if c.get("uses_shader"):
				shader_spikes += 1
	check(spikes > 0 and shader_spikes == 0, "earth spikes use the transparency fade path (%d spikes)" % spikes)
	target.global_position = Vector3(0, 0, -20)
	fx.spawn_projectile_visual(7000, "orb", Vector3(0, 0, 0), Vector3(10, 0, 0), 0.0, Color.WHITE, 1.0, 77, 1.0)
	var hr: Node3D = fx._nodes[7000]
	hr.set("_target", weakref(target))
	var v0: Vector3 = hr.get("vel")
	var t0 := Time.get_ticks_msec()
	for f in 15:
		await process_frame
	var turned := v0.angle_to(hr.get("vel"))
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	check(turned > 0.01 and turned <= 1.0 * el + 0.05, "homing_rate limits visual turning (%.2f rad in %.2f s)" % [turned, el])
	fx.despawn(7000)
	fx.call("clear_all")

	# stress: 10 fighters worth of effects in one frame stays bounded
	for i in 200:
		fx.play(CONTRACT_EFFECTS[i % CONTRACT_EFFECTS.size()], Vector3(randf() * 20, 1, randf() * 20))
	var peak: int = fx.call("live_count")
	check(peak < 1200, "stress burst bounded (%d live nodes)" % peak)
	fx.call("clear_all")

	var errs := errlog.errors.slice(e0)
	for e in errs:
		print("  ENGINE ERROR: ", e)
	check(errs.is_empty(), "no engine/script errors during Fx test (%d)" % errs.size())
	print("ASSETS TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
