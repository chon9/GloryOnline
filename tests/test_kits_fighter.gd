extends SceneTree
## KITS-fighter tests: 拳法家 Striker, 气功师 Qi Master, 柔道 Grappler, 流氓 Brawler.
## Metadata, every skill cast in a deterministic World (auto_step = false), class mechanics (parry, counter-grab,
## Tooth for Tooth copy, passives) and a 30 s scripted mini-fight per class (prints dps).
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_fighter.gd

const DT: float = 1.0 / 60.0
const GROUP: String = "fighter"
const KIT_IDS: Array[String] = ["striker", "qi_master", "grappler", "brawler"]
const DUMMY_KIT_PATH: String = "res://tests/test_kit_dummy.gd"
const DAMAGE_TAGS: Array[String] = ["launcher", "melee", "ranged", "aoe", "grab", "cc", "finisher", "debuff", "ultimate", "combo"]

var passed: int = 0
var failed: int = 0
var world: World = null
var reg: Node = null


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	# Damage assertions are written against unscaled kit numbers; pin the PvP scale (shipped default is lower).
	if root.get_node_or_null("Game") != null:
		(root.get_node("Game").get("settings") as Dictionary)["pvp_damage_scale"] = 1.0
	Combat.seed_rng(777)
	reg = root.get_node_or_null("Registry")
	if reg == null:
		check(false, "Registry autoload present")
	else:
		var dummy: ClassKit = (load(DUMMY_KIT_PATH) as Script).new()
		reg.call("register_kit", dummy)
		for kid: String in KIT_IDS:
			await test_kit(kid)
		await test_striker_mechanics()
		await test_qi_master_mechanics()
		await test_grappler_mechanics()
		await test_brawler_mechanics()
		for kid: String in KIT_IDS:
			await mini_fight(kid)
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("KITS[%s] TESTS: %d passed, %d failed" % [GROUP, passed, failed])
	quit(1 if failed > 0 else 0)


# ================================================================== harness
func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


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


func spawn(class_id: String, team: int, pos: Vector3, yaw: float = 0.0) -> Fighter:
	return world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": class_id, "team": team,
		"name": "%s_%d" % [class_id, team], "pos": pos, "yaw": yaw})


func sim(seconds: float) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)


## Steps `seconds`, calling cb.call() after every step.
func sim_watch(seconds: float, cb: Callable) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)
		cb.call()


## Standard arena: caster at origin facing -Z, two enemy dummies in front, one ally dummy at 50% hp.
func setup_arena(kid: String) -> Dictionary:
	await new_world()
	var c := spawn(kid, 0, Vector3(0, 0, 0), 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -1.6), PI)
	var e2 := spawn("test_dummy", 1, Vector3(0.9, 0, -2.0), PI)
	var al := spawn("test_dummy", 0, Vector3(-1.6, 0, 0.8), 0.0)
	await sim(0.1)
	al.hp = al.max_hp * 0.5
	c.input.target_uid = e1.uid
	await sim(DT)
	c.reset_cooldowns()
	c.mp = c.max_mp
	return {"c": c, "e1": e1, "e2": e2, "al": al}


# ================================================================== per-kit
func test_kit(kid: String) -> void:
	var kit: ClassKit = reg.call("get_kit", kid)
	check(kit != null, "[%s] Registry has kit" % kid)
	if kit == null:
		return
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == GROUP and kit.group_cn != "" and kit.group_en != "",
		"[%s] names / group metadata" % kid, "%s %s %s" % [kit.name_cn, kit.name_en, kit.group_id])
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != ""
		and kit.famous != "" and kit.role != "", "[%s] weapon / model / famous / role" % kid)
	var st: Dictionary = kit.get_stats()
	check(float(st["hp"]) >= 6000.0 and float(st["hp"]) <= 9600.0 and float(st["move_speed"]) >= 5.5
		and float(st["move_speed"]) <= 6.8, "[%s] stats in balance range" % kid)
	check(kit.skills.size() == 8, "[%s] exactly 8 skills" % kid, str(kit.skills.size()))
	var slots_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s == null or s.slot != i or s.name_cn == "" or s.name_en == "" or s.desc == "" or s.steps.is_empty() and s.chain.is_empty():
			slots_ok = false
	check(slots_ok, "[%s] skills fill slots 0..7 with CN/EN names, desc and steps" % kid)
	var ult := kit.skill_for_slot(7)
	check(ult != null and ult.has_tag("ultimate") and ult.cooldown >= 40.0 and ult.cooldown <= 90.0,
		"[%s] slot 7 is a long-cooldown ultimate" % kid)
	var l1 := kit.skill_for_slot(1)
	var l2 := kit.skill_for_slot(2)
	check((l1 != null and l1.has_tag("launcher")) or (l2 != null and l2.has_tag("launcher")), "[%s] launcher in slot 1-2" % kid)
	var b := kit.skill_for_slot(0)
	check(b != null and b.chain.size() >= 2 and b.chain.size() <= 4, "[%s] basic attack chain of 2-4" % kid)
	var chain_ok := true
	for cid: StringName in b.chain:
		if kit.get_skill_by_id(cid) == null:
			chain_ok = false
	check(chain_ok, "[%s] chain parts resolvable" % kid)
	check(kit.passives.size() >= 1 and str(kit.passives[0].get("name_cn", "")) != "", "[%s] passives listed" % kid)
	for slot in 8:
		await test_skill(kid, slot)


func test_skill(kid: String, slot: int) -> void:
	var a: Dictionary = await setup_arena(kid)
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	var e2: Fighter = a["e2"]
	var al: Fighter = a["al"]
	var s: SkillDef = c.get_skill(slot)
	var name := "[%s] %d %s" % [kid, slot, s.display_name()]
	var hp1 := e1.hp
	var hp2 := e2.hp
	var ally_hp := al.hp
	var seen := {"launched": false, "grabbed": false, "state": false, "status": false, "c_sa": false, "c_shield": false,
		"ally_buff": false, "poison": false, "ids": {}, "max_chain": 0}
	var ok := c.try_cast(slot)
	check(ok, name + " casts", c.cast_block_reason(slot))
	var presses := 1
	var watch := func() -> void:
		for e: Fighter in [e1, e2]:
			if e.state == Fighter.State.LAUNCHED:
				seen["launched"] = true
			if e.state == Fighter.State.GRABBED:
				seen["grabbed"] = true
			if e.state != Fighter.State.IDLE and e.state != Fighter.State.MOVE:
				seen["state"] = true
			if e.status_mask != 0:
				seen["status"] = true
			if e.has_status(&"poison"):
				seen["poison"] = true
		if c.has_status(&"super_armor"):
			seen["c_sa"] = true
		if c.shield_hp > 0.0:
			seen["c_shield"] = true
		if al.has_status(&"atk_up"):
			seen["ally_buff"] = true
		if c.runner != null:
			(seen["ids"] as Dictionary)[c.runner.skill.id] = true
	if slot == 0:
		# Mash the basic attack: the press chain must advance through every part.
		await physics_frame
		for i in roundi(3.0 / DT):
			if presses < s.chain.size() + 1 and c.can_cast(0):
				if c.try_cast(0):
					presses += 1
			world.step(DT)
			watch.call()
		check((seen["ids"] as Dictionary).size() >= s.chain.size(), name + " chain advances through all parts",
			str((seen["ids"] as Dictionary).keys()))
	else:
		await sim_watch(3.0, watch)
	var dealt := (hp1 - e1.hp) + (hp2 - e2.hp)
	var tags := s.tags
	var wants_damage := false
	for t: String in DAMAGE_TAGS:
		if tags.has(t):
			wants_damage = true
	if tags.has("defensive") and (tags.has("buff_self") or tags.has("interrupt")):
		wants_damage = tags.has("interrupt")
	if wants_damage:
		check(dealt > 0.0 or bool(seen["state"]) or bool(seen["status"]), name + " affects enemies",
			"dmg %.0f" % dealt)
	if tags.has("launcher"):
		check(bool(seen["launched"]), name + " launches (LAUNCHED)")
	if tags.has("grab"):
		check(bool(seen["grabbed"]) or slot == 7 and kid == "brawler", name + " grabs (GRABBED)")
	if tags.has("buff_ally"):
		check(bool(seen["ally_buff"]), name + " buffs ally")
	if tags.has("buff_self"):
		check(bool(seen["c_sa"]) or bool(seen["c_shield"]), name + " buffs self")
	if tags.has("heal"):
		check(al.hp > ally_hp, name + " heals ally")
	if tags.has("ultimate"):
		check(dealt >= e1.max_hp * 0.12, name + " ultimate deals heavy damage", "%.0f (%.1f%%)" % [dealt, dealt / e1.max_hp * 100.0])
	if kid == "brawler" and slot == 0:
		check(bool(seen["poison"]), name + " Apply Poison passive poisons")
	if kid == "grappler" and slot == 1:
		check(bool(seen["c_sa"]), name + " Grappling Mastery grants super armor after a throw")
	check(c.is_alive() and c.mp >= 0.0, name + " caster ok", "%s mp %.0f" % [c.state_name(), c.mp])
	print("  %s: dmg %.0f (%.1f%% of target hp) cd %.1f mp %.0f" % [name, dealt, dealt / e1.max_hp * 100.0, s.cooldown, s.mp_cost])


# ================================================================== class mechanics
## Enemy dummy swings its basic attack at the caster `delay` s after the caster starts `slot`.
func _enemy_swing_during(kid: String, slot: int, delay: float, enemy_skill: String) -> Dictionary:
	var a: Dictionary = await setup_arena(kid)
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	e1.input.target_uid = c.uid
	e1.face_towards(c.global_position)
	var hp_c := c.hp
	var hp_e := e1.hp
	check(c.try_cast(slot), "[%s] stance skill %d starts" % [kid, slot])
	await sim(delay)
	var es: SkillDef = e1.find_skill(StringName(enemy_skill))
	e1.start_skill(es)
	var seen := {"launched": false, "grabbed": false}
	await sim_watch(2.0, func() -> void:
		if e1.state == Fighter.State.LAUNCHED:
			seen["launched"] = true
		if e1.state == Fighter.State.GRABBED:
			seen["grabbed"] = true)
	return {"c": c, "e1": e1, "hp_c": hp_c, "hp_e": hp_e, "seen": seen}


## A real class `atk_kid` (enemy) uses `atk_skill` on the caster `delay` s after the caster starts stance `slot`.
func _duel_counter(kid: String, slot: int, atk_kid: String, atk_skill: String, delay: float) -> Dictionary:
	await new_world()
	var c := spawn(kid, 0, Vector3(0, 0, 0), 0.0)
	var e := spawn(atk_kid, 1, Vector3(0, 0, -1.5), PI)
	await sim(0.1)
	c.input.target_uid = e.uid
	e.input.target_uid = c.uid
	e.face_towards(c.global_position)
	await sim(DT)
	c.reset_cooldowns()
	var hp_c := c.hp
	var hp_e := e.hp
	c.try_cast(slot)
	await sim(delay)
	e.start_skill(e.find_skill(StringName(atk_skill)))
	var seen := {"e_launched": false, "c_blind": false, "c_down": false, "c_grabbed": false}
	await sim_watch(1.5, func() -> void:
		if e.state == Fighter.State.LAUNCHED:
			seen["e_launched"] = true
		if c.has_status(&"blind"):
			seen["c_blind"] = true
		if c.state == Fighter.State.KNOCKDOWN:
			seen["c_down"] = true
		if c.state == Fighter.State.GRABBED:
			seen["c_grabbed"] = true)
	return {"c": c, "e": e, "hp_c": hp_c, "hp_e": hp_e, "seen": seen}


func test_striker_mechanics() -> void:
	var r: Dictionary = await _enemy_swing_during("striker", 6, 0.1, "test_dummy.atk1")
	var c: Fighter = r["c"]
	var e1: Fighter = r["e1"]
	check(c.hp >= float(r["hp_c"]) - 0.01, "[striker] Blade Block negates the melee hit", "%.0f -> %.0f" % [r["hp_c"], c.hp])
	check(e1.hp < float(r["hp_e"]) and bool((r["seen"] as Dictionary)["launched"]), "[striker] Blade Block counters (dmg + launch)")
	# A parried hit is fully negated: no rider statuses (blind) and no armor-break knockdown.
	r = await _duel_counter("striker", 6, "brawler", "brawler.sand_toss", 0.1)
	var sn: Dictionary = r["seen"]
	check(not bool(sn["c_blind"]) and (r["e"] as Fighter).hp < float(r["hp_e"]), "[striker] parried Sand Toss does not blind the parrier",
		"blind %s" % sn["c_blind"])
	r = await _duel_counter("striker", 6, "striker", "striker.emperors_fist", 0.1)
	sn = r["seen"]
	check(not bool(sn["c_down"]) and bool(sn["e_launched"]), "[striker] parried armor-break Emperor's Fist: no knockdown, attacker launched",
		"down %s launched %s" % [sn["c_down"], sn["e_launched"]])
	# Being grabbed mid-stance ends the parry: the throw lands and is not countered.
	r = await _duel_counter("striker", 6, "grappler", "grappler.toss", 0.1)
	sn = r["seen"]
	check(bool(sn["c_grabbed"]) and (r["c"] as Fighter).hp < float(r["hp_c"]) and not bool(sn["e_launched"]),
		"[striker] a grab during Blade Block is not parried", "grabbed %s launched %s hp %.0f->%.0f" % [sn["c_grabbed"],
		sn["e_launched"], r["hp_c"], (r["c"] as Fighter).hp])
	# Momentum passive.
	var a: Dictionary = await setup_arena("striker")
	c = a["c"]
	c.set_meta(&"striker_mom", 5)
	c.set_meta(&"striker_mom_t", 2.0)
	c.try_cast(0)
	await sim(0.3)
	check(c.has_status(&"super_armor"), "[striker] Iron Fist Momentum grants super armor on the 6th hit")


func test_qi_master_mechanics() -> void:
	var a: Dictionary = await setup_arena("qi_master")
	var c: Fighter = a["c"]
	await sim(0.1)
	var full := c.get_stat("pdef")
	c.mp = 0.0
	await sim(DT)
	var empty := c.get_stat("pdef")
	check(full > empty * 1.2, "[qi_master] True Qi Protection: defense scales with mana", "%.0f vs %.0f" % [full, empty])
	c.stat_bonus["pdef"] = float(c.stat_bonus.get("pdef", 0.0)) + 0.25      # foreign modifier
	c.mp = c.max_mp
	await sim(DT)
	check(absf(float(c.stat_bonus.get("pdef", 0.0)) - (0.25 + 0.3 * c.mp / c.max_mp)) < 0.01,
		"[qi_master] True Qi Protection is an additive pdef share", str(c.stat_bonus.get("pdef", 0.0)))
	# Cloud Grasping Fist at long range.
	await new_world()
	c = spawn("qi_master", 0, Vector3(0, 0, 0), 0.0)
	var far := spawn("test_dummy", 1, Vector3(0, 0, -8.0), PI)
	await sim(0.1)
	c.input.target_uid = far.uid
	await sim(DT)
	c.reset_cooldowns()
	var grabbed := {"v": false}
	check(c.try_cast(4), "[qi_master] Cloud Grasping Fist cast at 8 m")
	await sim_watch(1.0, func() -> void:
		if far.state == Fighter.State.GRABBED:
			grabbed["v"] = true)
	var d := CoreUtil.flat(far.global_position - c.global_position).length()
	check(bool(grabbed["v"]) and d < 3.5, "[qi_master] Cloud Grasping Fist pulls the target in", "dist %.1f" % d)
	# Dragon Wave empowers allies but not the Qi Master himself.
	a = await setup_arena("qi_master")
	c = a["c"]
	var al: Fighter = a["al"]
	c.try_cast(3)
	await sim(0.6)
	check(al.has_status(&"atk_up") and not c.has_status(&"atk_up"), "[qi_master] Dragon Wave buffs allies, not self")
	# Without a lock, Cloud Grasping Fist only grabs enemies in front.
	await new_world()
	c = spawn("qi_master", 0, Vector3(0, 0, 0), 0.0)
	var behind := spawn("test_dummy", 1, Vector3(0, 0, 8.0), 0.0)
	await sim(0.1)
	c.input.target_uid = 0
	c.reset_cooldowns()
	var pos0 := behind.global_position
	var gb := {"v": false}
	c.try_cast(4)
	await sim_watch(1.0, func() -> void:
		if behind.state == Fighter.State.GRABBED:
			gb["v"] = true)
	check(not bool(gb["v"]) and behind.global_position.distance_to(pos0) < 1.0, "[qi_master] Cloud Grasping Fist ignores enemies behind")


func test_grappler_mechanics() -> void:
	var r: Dictionary = await _enemy_swing_during("grappler", 3, 0.1, "test_dummy.atk1")
	var c: Fighter = r["c"]
	var e1: Fighter = r["e1"]
	check(c.hp >= float(r["hp_c"]) - 0.01, "[grappler] Receiving Throw negates the melee hit")
	check(bool((r["seen"] as Dictionary)["grabbed"]) and e1.hp < float(r["hp_e"]), "[grappler] Receiving Throw counter-grabs the attacker")
	r = await _duel_counter("grappler", 3, "brawler", "brawler.sand_toss", 0.1)
	check(not bool((r["seen"] as Dictionary)["c_blind"]) and (r["c"] as Fighter).hp >= float(r["hp_c"]) - 0.01,
		"[grappler] countered Sand Toss does not blind the Grappler")
	# Throws break super armor.
	var a: Dictionary = await setup_arena("grappler")
	c = a["c"]
	e1 = a["e1"]
	e1.add_status(&"super_armor", 10.0, 1.0, e1)
	var seen := {"g": false}
	c.try_cast(2)
	await sim_watch(1.5, func() -> void:
		if e1.state == Fighter.State.GRABBED:
			seen["g"] = true)
	check(bool(seen["g"]) and e1.hp < e1.max_hp, "[grappler] Back Throw grabs a super-armored target")
	# Aerial Twist catches an airborne target.
	a = await setup_arena("grappler")
	c = a["c"]
	e1 = a["e1"]
	e1.receive_hit(null, {"dmg": 0.0, "launch": 9.0, "knockback": 0.0}, e1.global_position + Vector3(0, 0, -1))
	await sim(0.15)
	var hp0 := e1.hp
	c.reset_cooldowns()
	check(c.try_cast(6), "[grappler] Aerial Twist cast vs airborne target")
	var down := {"v": false}
	await sim_watch(2.0, func() -> void:
		if e1.state == Fighter.State.KNOCKDOWN:
			down["v"] = true)
	check(e1.hp < hp0 and bool(down["v"]), "[grappler] Aerial Twist slams the airborne target down")


func test_brawler_mechanics() -> void:
	var a: Dictionary = await setup_arena("brawler")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	e1.input.target_uid = c.uid
	e1.face_towards(c.global_position)
	e1.start_skill(e1.find_skill(&"test_dummy.rising"))
	await sim(0.4)
	var stored: Variant = c.get_meta(&"brawler_t4t_skill") if c.has_meta(&"brawler_t4t_skill") else null
	check(stored is SkillDef and (stored as SkillDef).id == &"test_dummy.rising", "[brawler] Tooth for Tooth remembers the skill that hit")
	await sim(3.0)
	c.reset_cooldowns()
	c.mp = c.max_mp
	c.face_towards(e1.global_position)
	var hp0 := e1.hp
	var ok := c.try_cast(7)
	var copied := ok and c.runner != null and c.runner.skill.id == &"test_dummy.rising"
	check(copied, "[brawler] Tooth for Tooth replays the copied skill", "%s" % (str(c.runner.skill.id) if c.runner != null else "none"))
	var seen := {"l": false}
	await sim_watch(1.5, func() -> void:
		if e1.state == Fighter.State.LAUNCHED:
			seen["l"] = true)
	check(e1.hp < hp0 and bool(seen["l"]), "[brawler] copied launcher hits back and launches")
	# Brick Buster from behind dizzies longer.
	a = await setup_arena("brawler")
	c = a["c"]
	e1 = a["e1"]
	e1.face_towards(e1.global_position + Vector3(0, 0, -5))
	await sim(DT)
	c.try_cast(3)
	await sim(0.3)
	var left := float((e1.status.entries.get(&"stun", {}) as Dictionary).get("dur", 0.0))
	check(left > 2.5, "[brawler] Brick Buster from behind: long dizzy", "%.2f s" % left)


# ================================================================== mini fight
func mini_fight(kid: String) -> void:
	await new_world()
	var c := spawn(kid, 0, Vector3(0, 0, 0), 0.0)
	var d := spawn("test_dummy", 1, Vector3(0, 0, -3.0), PI)
	await sim(0.1)
	d.max_hp = 1000000.0
	d.hp = d.max_hp
	c.input.target_uid = d.uid
	c.reset_cooldowns()
	var order: Array[int] = [7, 1, 2, 3, 6, 5, 4]
	var casts := {}
	var mp_blocked := 0
	await physics_frame
	for i in roundi(30.0 / DT):
		var to := CoreUtil.flat(d.global_position - c.global_position)
		c.input.move = to.normalized() if to.length() > 1.9 else Vector3.ZERO
		c.input.aim_point = d.center()
		var cast := false
		for sl: int in order:
			var sd := c.get_skill(sl)
			if sd != null and sd.range > 0.0 and to.length() > sd.range + 0.4:
				continue
			if c.can_cast(sl):
				if c.try_cast(sl):
					casts[sl] = int(casts.get(sl, 0)) + 1
					cast = true
					break
			elif c.cast_block_reason(sl) == "mp":
				mp_blocked += 1
		if not cast and c.can_cast(0) and to.length() < c.get_skill(0).range + 0.4:
			if c.try_cast(0):
				casts[0] = int(casts.get(0, 0)) + 1
		world.step(DT)
	var dmg := d.max_hp - d.hp
	var dps := dmg / 30.0
	print("KITS[%s] mini-fight %s: %.0f damage in 30 s = %.0f dps; casts %s; mp-blocked frames %d"
		% [GROUP, kid, dmg, dps, str(casts), mp_blocked])
	check(dps > 150.0 and c.is_alive(), "[%s] 30 s mini-fight deals damage" % kid, "%.0f dps" % dps)
	check(casts.size() >= 7, "[%s] mini-fight rotation uses most skills" % kid, str(casts.keys()))
