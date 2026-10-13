extends SceneTree
## Shared harness for AI headless tests (run directly it only builds the kits and reports 0/0).
## Deterministic: World.auto_step = false, Combat.deterministic, BotBrain.rng_seed fixed.
## Kits: every real kit in Registry (res://classes) plus role test kits built from tests/test_kit_dummy.gd
## (melee "test_dummy", tank "ai_test_tank", healer "ai_test_healer", ranged "ai_test_ranged").

const DT: float = 1.0 / 60.0
const DUMMY_PATH: String = "res://tests/test_kit_dummy.gd"
const TEST_KIT_IDS: Array[String] = ["test_dummy", "ai_test_tank", "ai_test_healer", "ai_test_ranged"]

var passed: int = 0
var failed: int = 0
var world: World = null
var reg: Node = null
var suite_name: String = "ai"


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	Combat.seed_rng(777)
	BotBrain.rng_seed = 4242
	reg = root.get_node_or_null("Registry")
	if reg == null:
		print("FAIL: Registry autoload missing")
		failed += 1
	else:
		for k: ClassKit in build_test_kits():
			reg.call("register_kit", k)
	await run_tests()
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("AI TESTS [%s]: %d passed, %d failed" % [suite_name, passed, failed])
	print("AI TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func run_tests() -> void:
	pass


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label + ("" if detail == "" else "  (" + detail + ")"))
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


# ================================================================== kits
func _dummy() -> ClassKit:
	return (load(DUMMY_PATH) as Script).new()


func _retag(s: SkillDef, slot: int, cd: float, mp: float = -1.0) -> SkillDef:
	s.slot = slot
	s.cooldown = cd
	if mp >= 0.0:
		s.mp_cost = mp
	return s


func build_test_kits() -> Array[ClassKit]:
	var out: Array[ClassKit] = []
	out.append(_dummy())
	# ---------------------------------------------------------------- tank
	var tk := _dummy()
	tk.id = "ai_test_tank"
	tk.name_cn = "测试骑士"
	tk.name_en = "Test Tank"
	tk.role = "tank"
	tk.stats = {"hp": 10500.0, "mp": 1000.0, "mp_regen": 12.0, "patk": 470.0, "matk": 400.0,
		"pdef": 620.0, "mdef": 560.0, "move_speed": 5.8}
	tk.skills = [tk.skill_for_slot(0), tk.skill_for_slot(1),
		_retag(tk.get_skill_by_id(&"test_dummy.charge"), 2, 7.0, 30.0),
		_retag(tk.get_skill_by_id(&"test_dummy.provoke"), 3, 12.0, 40.0),
		tk.skill_for_slot(4), tk.skill_for_slot(5),
		_retag(tk.get_skill_by_id(&"test_dummy.slam"), 6, 9.0, 40.0), tk.skill_for_slot(7)]
	out.append(tk)
	# ---------------------------------------------------------------- healer
	var hk := _dummy()
	hk.id = "ai_test_healer"
	hk.name_cn = "测试牧师"
	hk.name_en = "Test Healer"
	hk.role = "healer"
	hk.stats = {"hp": 6800.0, "mp": 1400.0, "mp_regen": 20.0, "patk": 420.0, "matk": 580.0,
		"pdef": 360.0, "mdef": 480.0, "move_speed": 6.0}
	var hbolt := hk.sk(0, "holy_bolt", "圣光弹", "Holy Bolt", 0.0, 0.0, 0.45, &"cast", 14.0, ["ranged"],
		[{"t": 0.15, "type": "projectile", "speed": 26.0, "range": 15.0, "aim": "target", "hit": hk.hit(0.7, {"type": "magic", "hitstun": 0.15})}])
	var heal := _retag(hk.get_skill_by_id(&"test_dummy.heal_wave"), 2, 3.5, 60.0)
	var ground := _retag(hk.get_skill_by_id(&"test_dummy.holy_ground"), 3, 12.0, 80.0)
	var purify := _retag(hk.get_skill_by_id(&"test_dummy.purify"), 4, 12.0, 40.0)
	var rez := hk.sk(5, "resurrect", "复活术", "Resurrection", 30.0, 200.0, 1.0, &"heal", 8.0, ["heal"],
		[{"t": 0.9, "type": "heal", "target": "target_ally", "radius": 10.0, "amount": 0.35, "revive": true}])
	var hop := hk.sk(6, "retreat", "后撤", "Retreat", 8.0, 20.0, 0.25, &"dash", 6.0, ["escape"],
		[{"t": 0.0, "type": "dash", "direction": "back", "distance": 6.0, "speed": 26.0}])
	var sanct := hk.sk(7, "sanctuary", "圣域庇护", "Sanctuary", 45.0, 250.0, 0.6, &"heal", 12.0, ["ultimate", "heal"],
		[{"t": 0.3, "type": "heal", "target": "allies", "radius": 12.0, "amount": 0.3}])
	hk.skills = [hbolt, hk.skill_for_slot(1), heal, ground, purify, rez, hop, sanct]
	out.append(hk)
	# ---------------------------------------------------------------- ranged
	var rk := _dummy()
	rk.id = "ai_test_ranged"
	rk.name_cn = "测试枪手"
	rk.name_en = "Test Gunner"
	rk.role = "ranged"
	rk.stats = {"hp": 6800.0, "mp": 1000.0, "mp_regen": 14.0, "patk": 580.0, "matk": 500.0,
		"pdef": 360.0, "mdef": 380.0, "move_speed": 6.2}
	var shot := rk.sk(0, "shot", "射击", "Shot", 0.0, 0.0, 0.35, &"shoot_1h", 16.0, ["ranged"],
		[{"t": 0.1, "type": "projectile", "speed": 34.0, "range": 18.0, "aim": "target", "visual": "bullet", "hit": rk.hit(0.75, {"hitstun": 0.15})}])
	var kick := rk.sk(1, "rising_kick", "浮空踢", "Rising Kick", 5.0, 20.0, 0.35, &"kick", 2.2, ["launcher", "melee"],
		[{"t": 0.1, "type": "melee", "hit": rk.hit(0.8, {"launch": 9.0})}])
	var bolt := _retag(rk.get_skill_by_id(&"test_dummy.bolt"), 2, 2.0, 25.0)
	var meteor := rk.get_skill_by_id(&"test_dummy.meteor")
	var ray := _retag(rk.get_skill_by_id(&"test_dummy.ray"), 4, 7.0, 50.0)
	var back := rk.sk(5, "backflip", "后跳", "Backflip", 7.0, 20.0, 0.25, &"dash", 6.0, ["escape"],
		[{"t": 0.0, "type": "dash", "direction": "back", "distance": 7.0, "speed": 28.0}])
	var lance := _retag(rk.get_skill_by_id(&"test_dummy.lance"), 6, 6.0, 40.0)
	var barrage := rk.sk(7, "barrage", "弹幕", "Barrage", 35.0, 200.0, 1.0, &"shoot_2h", 16.0, ["ultimate", "ranged", "aoe"],
		[{"t": 0.2, "type": "projectile", "count": 5, "spread": 20.0, "speed": 30.0, "range": 18.0, "aim": "target",
		"hit": rk.hit(0.8)}, {"t": 0.6, "type": "projectile", "count": 5, "spread": 20.0, "speed": 30.0, "range": 18.0,
		"aim": "target", "hit": rk.hit(0.8)}])
	rk.skills = [shot, kick, bolt, meteor, ray, back, lance, barrage]
	out.append(rk)
	return out


## Real kits (res://classes) when at least two exist, otherwise the test kits.
func available_kits() -> Array[String]:
	var real: Array[String] = []
	if reg != null:
		for id: Variant in reg.call("kit_ids"):
			if not TEST_KIT_IDS.has(str(id)):
				real.append(str(id))
	if real.size() >= 2:
		return real
	return TEST_KIT_IDS.duplicate()


func kit_role(id: String) -> String:
	var k: Variant = reg.call("get_kit", id) if reg != null else null
	return (k as ClassKit).role if k is ClassKit else "melee"


## First available kit with one of `roles`, falling back to `fallback`.
func kit_for_roles(roles: Array, fallback: String, exclude: Array = []) -> String:
	for id: String in available_kits():
		if roles.has(kit_role(id)) and not exclude.has(id):
			return id
	return fallback


# ================================================================== world / sim
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


func spawn(class_id: String, team: int, pos: Vector3, yaw: float = 0.0, kind: String = "bot") -> Fighter:
	return world.spawn_fighter({"kind": kind, "peer": 0, "class_id": class_id, "team": team,
		"name": "%s_%d" % [class_id, team], "pos": pos, "yaw": yaw})


func spawn_bot(class_id: String, team: int, pos: Vector3, diff: int, mode: String = "pvp") -> Fighter:
	var f := spawn(class_id, team, pos, 0.0 if team == 0 else PI)
	var b := world.attach_brain(f, mode)
	if b is BotBrain:
		(b as BotBrain).set_difficulty(diff)
	return f


func brain_of(f: Fighter) -> BotBrain:
	return f.brain as BotBrain if f != null and f.brain is BotBrain else null


func sim(seconds: float) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)


func sim_until(cond: Callable, timeout: float) -> bool:
	await physics_frame
	var n := roundi(timeout / DT)
	for i in n:
		world.step(DT)
		if cond.call():
			return true
	return false


func team_wiped(team: int) -> bool:
	return world.team_alive(team) == 0


## Bot vs bot duel. Returns {winner: team or -1, time: seconds, hp: [frac0, frac1]}.
func duel(a_id: String, b_id: String, diff_a: int, diff_b: int, cap: float, swap := false) -> Dictionary:
	await new_world()
	var pa := Vector3(0, 0, 6) if not swap else Vector3(0, 0, -6)
	var pb := Vector3(0, 0, -6) if not swap else Vector3(0, 0, 6)
	var a := spawn_bot(a_id, 0, pa, diff_a)
	var b := spawn_bot(b_id, 1, pb, diff_b)
	var t0 := 0.0
	await physics_frame
	var n := roundi(cap / DT)
	var steps := 0
	for i in n:
		world.step(DT)
		steps += 1
		if not a.is_alive() or not b.is_alive():
			break
	t0 = float(steps) * DT
	var winner := -1
	if not a.is_alive() and b.is_alive():
		winner = 1
	elif not b.is_alive() and a.is_alive():
		winner = 0
	return {"winner": winner, "time": t0, "hp": [a.hp / a.max_hp, b.hp / b.max_hp]}
