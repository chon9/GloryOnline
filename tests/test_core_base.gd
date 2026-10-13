extends SceneTree
## Shared harness for CORE headless tests. Subclasses override run_tests() (a coroutine).
## Simulation is stepped manually (World.auto_step = false) inside physics frames, deterministic combat.

const DT: float = 1.0 / 60.0
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var passed: int = 0
var failed: int = 0
var world: World = null
var kit: ClassKit = null
var suite_name: String = "core"


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	Combat.seed_rng(12345)
	# CORE suites check raw 1.0x damage formulas; the shipped PvP default scale (BALANCE) is pinned off here.
	var game := root.get_node_or_null("Game")
	if game != null and game.get("settings") is Dictionary:
		(game.get("settings") as Dictionary)["pvp_damage_scale"] = 1.0
	kit =(load(KIT_PATH) as Script).new()
	var reg := root.get_node_or_null("Registry")
	if reg == null:
		print("FAIL: Registry autoload missing")
		failed += 1
	else:
		reg.call("register_kit", kit)
	await run_tests()
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	# Free Fx's pooled voices / playbacks so the run ends without leak / "resources still in use" lines.
	var fx := root.get_node_or_null("Fx")
	if fx != null and fx.has_method("shutdown"):
		fx.call("shutdown")
	await process_frame
	await process_frame
	print("CORE TESTS [%s]: %d passed, %d failed" % [suite_name, passed, failed])
	print("CORE TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func run_tests() -> void:
	pass


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


func approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


## Fresh world with a 60x60 floor (layer 1) and manual stepping.
func new_world() -> void:
	if world != null and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = CoreUtil.LAYER_WORLD
	floor_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	world.add_child(floor_body)
	await physics_frame
	await physics_frame


func spawn(team: int, pos: Vector3, yaw: float = 0.0, kind: String = "bot") -> Fighter:
	var f := world.spawn_fighter({"kind": kind, "peer": 0, "class_id": "test_dummy", "team": team,
		"name": "T%d" % team, "pos": pos, "yaw": yaw})
	return f


## Steps the simulation `seconds` (inside one physics frame so space queries are valid).
func sim(seconds: float) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)


## Steps until cond() is true or timeout; returns whether cond became true.
func sim_until(cond: Callable, timeout: float) -> bool:
	await physics_frame
	var n := roundi(timeout / DT)
	for i in n:
		world.step(DT)
		if cond.call():
			return true
	return false


func skill(id: String) -> SkillDef:
	return kit.get_skill_by_id(StringName(id))


## Expected deterministic damage of a hit (front, no crit) from default dummy stats.
func expected(dmg: float, magic := false) -> float:
	var atk := 550.0
	var def := 400.0
	return atk * dmg * (1.0 - def / (def + 600.0)) * (1.0 if not magic else 1.0)
