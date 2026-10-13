extends SceneTree
## KITS-nightwalker tests: 刺客 Assassin, 忍者 Ninja, 盗贼 Thief, 术士 Warlock.
## Metadata, every skill cast in a deterministic World, class passives, and a 30 s scripted mini-fight.

const DT: float = 1.0 / 60.0
const DUMMY_KIT: String = "res://tests/test_kit_dummy.gd"
const KIT_IDS: Array[String] = ["assassin", "ninja", "thief", "warlock"]
const EFFECT_TAGS: Array[String] = ["melee", "ranged", "aoe", "cc", "debuff", "launcher", "grab", "finisher"]
const CC_STATES: Array[int] = [Fighter.State.HITSTUN, Fighter.State.LAUNCHED, Fighter.State.KNOCKDOWN,
	Fighter.State.STUNNED, Fighter.State.GRABBED]

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
		reg.call("register_kit", (load(DUMMY_KIT) as Script).new())
		for kid: String in KIT_IDS:
			await test_kit(kid)
		await test_assassin_passives()
		await test_ninja_passive()
		await test_thief_passives()
		await test_warlock_passive()
		await test_regressions()
		for kid: String in KIT_IDS:
			await mini_fight(kid)
	if world != null and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()
	await process_frame
	await process_frame
	print("KITS[nightwalker] TESTS: %d passed, %d failed" % [passed, failed])
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
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)


## Steps the world and records what happened to `watch` fighters each frame.
func sim_watch(seconds: float, watch: Array[Fighter]) -> Dictionary:
	var rec := {"cc": false, "launched": false, "status": false}
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)
		for e: Fighter in watch:
			if not is_instance_valid(e):
				continue
			if CC_STATES.has(e.state):
				rec["cc"] = true
			if e.state == Fighter.State.LAUNCHED:
				rec["launched"] = true
			if e.status_mask != 0:
				rec["status"] = true
	return rec


func has_any_tag(s: SkillDef, tags: Array[String]) -> bool:
	for t: String in tags:
		if s.has_tag(t):
			return true
	return false


## Caster at origin facing -Z, two enemy dummies in front, one ally dummy at 50% hp.
func setup_scene(kid: String, enemy_dist: float = 2.5) -> Dictionary:
	await new_world()
	var c := spawn(kid, 0, Vector3.ZERO, 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -enemy_dist), PI)
	var e2 := spawn("test_dummy", 1, Vector3(1.3, 0, -enemy_dist - 0.6), PI)
	var al := spawn("test_dummy", 0, Vector3(2.0, 0, 1.0), 0.0)
	await sim(0.1)
	al.hp = al.max_hp * 0.5
	c.input.target_uid = e1.uid
	c.input.aim_point = e1.center()
	await sim(DT)
	return {"c": c, "e1": e1, "e2": e2, "ally": al}


# ================================================================== per-kit tests
func test_kit(kid: String) -> void:
	var kit: ClassKit = reg.call("get_kit", kid)
	check(kit != null, "[%s] registered in Registry" % kid)
	if kit == null:
		return
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == "nightwalker" and kit.group_cn != "",
		"[%s] names / group" % kid, "%s %s %s" % [kit.name_cn, kit.name_en, kit.group_id])
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != ""
		and kit.famous != "" and kit.role != "", "[%s] weapon/model/famous/role" % kid)
	var st := kit.get_stats()
	check(float(st["hp"]) >= 6000.0 and float(st["hp"]) <= 9500.0 and float(st["move_speed"]) >= 5.5
		and float(st["move_speed"]) <= 6.8, "[%s] stats in balance range" % kid, str(st))
	check(kit.skills.size() == 8, "[%s] exactly 8 skills" % kid, str(kit.skills.size()))
	var slots_ok := true
	for i in 8:
		var s := kit.skill_for_slot(i)
		if s == null or s.name_cn == "" or s.name_en == "" or s.desc == "" or s.steps.is_empty():
			slots_ok = false
	check(slots_ok, "[%s] slots 0..7 filled with names/desc/steps" % kid)
	var ult := kit.skill_for_slot(7)
	check(ult != null and ult.has_tag("ultimate") and ult.cooldown >= 40.0 and ult.cooldown <= 90.0,
		"[%s] slot 7 is ultimate (40-90 s cd)" % kid)
	var s1 := kit.skill_for_slot(1)
	var s2 := kit.skill_for_slot(2)
	check((s1 != null and s1.has_tag("launcher")) or (s2 != null and s2.has_tag("launcher")), "[%s] launcher in slot 1/2" % kid)
	check(kit.skill_for_slot(0).chain.size() >= 2 and kit.skill_for_slot(0).chain.size() <= 4, "[%s] basic attack chain 2-4" % kid)
	var chain_ok := true
	for cid: StringName in kit.skill_for_slot(0).chain:
		if kit.get_skill_by_id(cid) == null:
			chain_ok = false
	check(chain_ok, "[%s] chain parts resolvable" % kid)
	check(not kit.passives.is_empty(), "[%s] passives listed" % kid)
	var cds_ok := true
	for i in range(1, 7):
		var s := kit.skill_for_slot(i)
		if s.cooldown < 3.0 or s.cooldown > 16.0:
			cds_ok = false
	check(cds_ok, "[%s] normal cooldowns 3-16 s" % kid)

	# Basic chain.
	var sc: Dictionary = await setup_scene(kid)
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	var e2: Fighter = sc["e2"]
	var hp0 := e1.hp + e2.hp
	var parts := 0
	for i in 6:
		if c.try_cast(0):
			parts += 1
		await sim(0.2)
		c.input.target_uid = e1.uid
	await sim(1.0)
	check(parts >= kit.skill_for_slot(0).chain.size() and e1.hp + e2.hp < hp0, "[%s] basic chain hits" % kid,
		"parts=%d dmg=%.0f" % [parts, hp0 - e1.hp - e2.hp])

	# Every skill 1..7.
	for slot in range(1, 8):
		var s := kit.skill_for_slot(slot)
		sc = await setup_scene(kid, 6.5 if s.has_tag("ranged") and not s.has_tag("melee") else 2.5)
		c = sc["c"]
		e1 = sc["e1"]
		e2 = sc["e2"]
		var ally: Fighter = sc["ally"]
		c.reset_cooldowns()
		c.mp = c.max_mp
		hp0 = e1.hp + e2.hp
		var ally_hp := ally.hp
		var reason := c.cast_block_reason(slot)
		var ok := c.try_cast(slot)
		check(ok, "[%s] cast slot %d %s" % [kid, slot, s.display_name()], reason)
		var w: Array[Fighter] = [e1, e2]
		var rec: Dictionary = await sim_watch(3.0, w)
		var dealt := hp0 - (e1.hp + e2.hp)
		var label := "[%s] %s" % [kid, s.name_en]
		print("  %s: dmg=%.0f (%.1f%% of one dummy) cc=%s launched=%s status=%s" % [label, dealt,
			dealt / e1.max_hp * 100.0, rec["cc"], rec["launched"], rec["status"]])
		if has_any_tag(s, EFFECT_TAGS) and s.id != &"thief.shadow_trap":
			check(dealt > 0.0 or rec["cc"] or rec["status"], label + " affects enemies (hp/state)")
		if s.has_tag("launcher"):
			check(rec["launched"], label + " launches (LAUNCHED)")
		if s.has_tag("heal"):
			check(ally.hp > ally_hp, label + " heals ally")
		if s.has_tag("summon"):
			check(not world.summons_of(c).is_empty() or _summoned_any(c), label + " spawns a summon")
		if s.has_tag("ultimate"):
			check(dealt >= e1.max_hp * 0.1, label + " ultimate deals heavy damage", "%.0f" % dealt)
		await _skill_specific(kid, s, sc)


func _summoned_any(c: Fighter) -> bool:
	for f: Fighter in world.fighters:
		if is_instance_valid(f) and f.kind == "summon" and f.owner_uid == c.uid:
			return true
	return false


## Extra per-skill assertions (state right after the 3 s window, or a re-cast).
func _skill_specific(kid: String, s: SkillDef, sc: Dictionary) -> void:
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	match str(s.id):
		"ninja.shadow_clone":
			await new_world()
			c = spawn(kid, 0, Vector3.ZERO, 0.0)
			e1 = spawn("test_dummy", 1, Vector3(0, 0, -3), PI)
			await sim(0.1)
			c.input.target_uid = e1.uid
			await sim(DT)
			c.start_skill(s)
			await sim(0.2)
			var clones := world.summons_of(c, "shadow_clone")
			check(clones.size() == 1, "[ninja] shadow clone spawned")
			check(e1.has_status(&"taunted") and clones.size() > 0 and e1.status.source(&"taunted") == clones[0],
				"[ninja] clone taunts nearby enemies")
			check(c.global_position.distance_to(Vector3.ZERO) > 4.0 and c.is_stealthed, "[ninja] relocates and vanishes")
		"ninja.smoke_bomb":
			await new_world()
			c = spawn(kid, 0, Vector3.ZERO, 0.0)
			e1 = spawn("test_dummy", 1, Vector3(0, 0, -2), PI)
			await sim(0.1)
			c.input.target_uid = e1.uid
			c.start_skill(s)
			await sim(0.6)
			check(e1.has_status(&"blind"), "[ninja] smoke blinds enemies")
			check(c.is_stealthed, "[ninja] caster hidden inside the smoke")
		"thief.stealth":
			check(c.is_stealthed, "[thief] stealth active after cast")
		"thief.shadow_trap":
			await new_world()
			c = spawn(kid, 0, Vector3.ZERO, 0.0)
			e1 = spawn("test_dummy", 1, Vector3(0, 0, -15), PI)
			await sim(0.1)
			check(c.try_cast(4), "[thief] shadow trap placed")
			await sim(0.5)
			var traps := 0
			for e: Variant in world.effects:
				if e is AreaEffect and (e as AreaEffect).mode == "trap":
					traps += 1
			check(traps == 1, "[thief] shadow trap exists", str(traps))
			c.global_position = Vector3(6, 0, 4)
			await sim(0.1)
			c.reset_cooldowns()
			check(c.try_cast(4), "[thief] shadow trap recast")
			await sim(0.3)
			check(CoreUtil.flat(c.global_position).length() < 0.6, "[thief] teleported back to the shadow trap",
				str(c.global_position))
		"thief.ambush":
			await new_world()
			c = spawn(kid, 0, Vector3.ZERO, 0.0)
			e1 = spawn("test_dummy", 1, Vector3(0, 0, -2), PI)
			var e3 := spawn("test_dummy", 1, Vector3(8, 0, -2), PI)
			await sim(0.1)
			c.input.target_uid = e1.uid
			await sim(DT)
			var h0 := e1.hp
			c.start_skill(s)
			await sim(0.5)
			var plain := h0 - e1.hp
			await sim(2.0)
			c.global_position = Vector3(8, 0, 0)
			c.input.target_uid = e3.uid
			c.add_status(&"stealth", 5.0, 1.0, c)
			await sim(DT)
			var h1 := e3.hp
			c.start_skill(s)
			await sim(0.5)
			var sneak := h1 - e3.hp
			check(sneak > plain * 1.8 and e3.has_status(&"stun"), "[thief] ambush from stealth: double damage + stun",
				"plain=%.0f sneak=%.0f" % [plain, sneak])
		"assassin.cut_throat":
			await new_world()
			c = spawn(kid, 0, Vector3.ZERO, 0.0)
			e1 = spawn("test_dummy", 1, Vector3(0, 0, -2), PI)                # facing the assassin
			var e4 := spawn("test_dummy", 1, Vector3(8, 0, -2), 0.0)          # facing away
			await sim(0.1)
			e1.add_status(&"super_armor", 10.0)
			c.input.target_uid = e1.uid
			await sim(DT)
			var h0 := e1.hp
			c.start_skill(s)
			var wl: Array[Fighter] = [e1]
			var rec: Dictionary = await sim_watch(0.5, wl)
			var front := h0 - e1.hp
			check(rec["cc"], "[assassin] cut throat breaks super armor")
			await sim(1.5)
			c.global_position = Vector3(8, 0, 0)
			c.input.target_uid = e4.uid
			await sim(DT)
			var h1 := e4.hp
			c.start_skill(s)
			await sim(0.5)
			var back := h1 - e4.hp
			check(back > front * 1.8 and e4.has_status(&"stun"), "[assassin] cut throat from behind: heavy + stun",
				"front=%.0f back=%.0f" % [front, back])
		"assassin.life_risking_strike":
			check(c.hp < c.max_hp * 0.95, "[assassin] life-risking strike costs own hp", "%.0f/%.0f" % [c.hp, c.max_hp])
		"warlock.bind_spell":
			pass
		"warlock.hexagram_prison":
			pass


# ================================================================== passives
func test_assassin_passives() -> void:
	# 空跃 Air Jump.
	await new_world()
	var c := spawn("assassin", 0, Vector3.ZERO, 0.0)
	await sim(0.3)
	c.input.jump = true
	await sim(0.15)
	var y1 := c.global_position.y
	var vy_before := c.velocity.y
	c.input.jump = true
	await sim(DT * 2.0)
	check(c.get_meta(&"nw_air_jump", false) and c.velocity.y > vy_before, "[assassin] air jump (double jump)",
		"y=%.2f vy %.2f -> %.2f" % [y1, vy_before, c.velocity.y])
	await sim(2.0)
	check(c.is_on_floor() and not c.get_meta(&"nw_air_jump", true), "[assassin] air jump resets on landing")
	# 暗杀 Assassination: hits from behind deal bonus damage.
	await new_world()
	c = spawn("assassin", 0, Vector3.ZERO, 0.0)
	var front := spawn("test_dummy", 1, Vector3(0, 0, -2), PI)
	var back := spawn("test_dummy", 1, Vector3(10, 0, -2), 0.0)
	await sim(0.1)
	var kit: ClassKit = c.kit
	var h := Hit.normalize(kit.hit(1.0, {"hitstun": 0.0, "knockback": 0.0}))
	var a0 := front.hp
	front.receive_hit(c, h, c.global_position)
	var df := a0 - front.hp
	c.global_position = Vector3(10, 0, 0)
	var b0 := back.hp
	back.receive_hit(c, h, c.global_position)
	var db := b0 - back.hp
	check(db > df * 1.35, "[assassin] assassination back-attack bonus", "front=%.0f back=%.0f" % [df, db])
	# 致命要害 Vitals Strike: marked targets take extra.
	front.add_status(&"mark", 5.0, 1.0, c)
	c.global_position = Vector3.ZERO
	var m0 := front.hp
	front.receive_hit(c, h, c.global_position)
	check(m0 - front.hp > df * 1.1, "[assassin] vitals strike mark bonus", "%.0f vs %.0f" % [m0 - front.hp, df])


func test_ninja_passive() -> void:
	await new_world()
	var n := spawn("ninja", 0, Vector3.ZERO, 0.0)
	var atk := spawn("test_dummy", 1, Vector3(0, 0, -2), PI)
	await sim(0.1)
	var h := {"dmg": 0.1, "launch": 9.0, "knockback": 0.5}
	n.receive_hit(atk, h, atk.global_position)
	await sim(0.1)
	n.receive_hit(atk, h, atk.global_position)
	await sim(0.1)
	check(n.state != Fighter.State.LAUNCHED, "[ninja] body replacement escapes the juggle", n.state_name())
	check(n.juggle_points == 0.0 and n.velocity.y <= 0.0, "[ninja] body replacement recovers to neutral (CORE recover_to_neutral)")
	check(not world.summons_of(n, "scarecrow").is_empty(), "[ninja] scarecrow left behind")
	check(n.global_position.distance_to(Vector3.ZERO) > 3.0, "[ninja] relocated away from attacker")
	await sim(1.0)
	n.receive_hit(atk, h, atk.global_position)
	await sim(0.05)
	n.receive_hit(atk, h, atk.global_position)
	await sim(0.1)
	check(n.state == Fighter.State.LAUNCHED or n.is_downed(), "[ninja] body replacement on cooldown", n.state_name())


func test_thief_passives() -> void:
	await new_world()
	var c := spawn("thief", 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -4), PI)
	await sim(0.1)
	c.input.target_uid = e.uid
	await sim(DT)
	c.start_skill(c.kit.skill_for_slot(5))
	await sim(0.3)
	check(c.is_stealthed, "[thief] stealthed before trapping")
	c.start_skill(c.kit.skill_for_slot(1))
	var wl: Array[Fighter] = [e]
	var rec: Dictionary = await sim_watch(1.0, wl)
	check(rec["launched"] and e.hp < e.max_hp, "[thief] spike trap triggers while stealthed")
	check(c.is_stealthed, "[thief] trap proficiency keeps stealth after a trap hit")


func test_warlock_passive() -> void:
	await new_world()
	var c := spawn("warlock", 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -5), PI)
	await sim(0.1)
	c.input.target_uid = e.uid
	e.mp = 500.0
	c.mp = 100.0
	await sim(DT)
	c.start_skill(c.kit.skill_for_slot(1))
	await sim(0.5)
	check(e.mp < 500.0, "[warlock] control spell drains enemy mp", "%.0f" % e.mp)
	# Death's Door pulls enemies to the gate.
	await new_world()
	c = spawn("warlock", 0, Vector3.ZERO, 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -8), PI)
	var e2 := spawn("test_dummy", 1, Vector3(4, 0, -9), PI)
	await sim(0.1)
	c.input.target_uid = e1.uid
	await sim(DT)
	var d0 := e2.global_position.distance_to(e1.global_position)
	c.start_skill(c.kit.skill_for_slot(7))
	await sim(1.3)
	var d1 := e2.global_position.distance_to(e1.global_position)
	check(d1 < d0 - 0.5, "[warlock] death's door drags enemies inward", "%.2f -> %.2f" % [d0, d1])


# ================================================================== review regressions
func _count_traps() -> int:
	var n := 0
	for e: Variant in world.effects:
		if is_instance_valid(e) and e is AreaEffect and (e as AreaEffect).mode == "trap":
			n += 1
	return n


## Damage one skill deals to a single dummy at `dist` (fresh world).
func _single_target_damage(kid: String, slot: int, dist: float, seconds: float) -> float:
	await new_world()
	var c := spawn(kid, 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -dist), PI)
	await sim(0.1)
	c.input.target_uid = e.uid
	c.input.aim_point = e.center()
	await sim(DT)
	var h0 := e.hp
	c.start_skill(c.kit.skill_for_slot(slot))
	await sim(seconds)
	return h0 - e.hp


func test_regressions() -> void:
	# Thief: Shadow Trap can be recast after the previous trap fired (freed instance in meta).
	await new_world()
	var c := spawn("thief", 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -15), PI)
	await sim(0.1)
	check(c.try_cast(4), "[thief] shadow trap placed (regression)")
	await sim(0.8)
	c.global_position = Vector3(6, 0, 4)
	e.global_position = Vector3(0, 0, 0.2)
	await sim(1.0)
	await sim(0.5)
	check(e.hp < e.max_hp and _count_traps() == 0, "[thief] enemy triggered the shadow trap",
		"hp=%.0f traps=%d" % [e.hp, _count_traps()])
	e.global_position = Vector3(0, 0, -15)
	await sim(0.1)
	c.reset_cooldowns()
	check(c.try_cast(4), "[thief] shadow trap recast after it fired")
	await sim(0.5)
	check(_count_traps() == 1, "[thief] a new shadow trap is placed after the old one fired", str(_count_traps()))
	check(not c.has_meta(&"nw_shadow_trap") or is_instance_valid(c.get_meta(&"nw_shadow_trap")),
		"[thief] no stale shadow trap reference")
	# Thief: taking damage clears the remembered stealth so a later trap hit cannot restore it.
	c.set_meta(&"nw_stealth_left", 3.0)
	c.kit.on_hit_taken(c, e, {}, 10.0)
	check(float(c.get_meta(&"nw_stealth_left", 1.0)) == 0.0, "[thief] hit taken clears stored stealth time")
	# Ninja: Storm Shuriken at point blank stays below the ultimate on one target.
	var storm_dmg: float = await _single_target_damage("ninja", 3, 2.5, 1.5)
	var ult_dmg: float = await _single_target_damage("ninja", 7, 2.5, 3.0)
	check(storm_dmg > 0.0 and storm_dmg < ult_dmg, "[ninja] storm shuriken point blank < ultimate",
		"storm=%.0f ult=%.0f" % [storm_dmg, ult_dmg])
	# Warlock: Control Spell drains at most once per victim per second, returning half.
	await new_world()
	c = spawn("warlock", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -5), PI)
	await sim(0.1)
	e.mp = 500.0
	c.mp = 100.0
	var mh := {"type": "magic"}
	for i in 5:
		c.kit.on_hit_dealt(c, e, mh, 10.0)
	check(is_equal_approx(e.mp, 485.0) and is_equal_approx(c.mp, 107.5),
		"[warlock] control spell drain capped per second, half returned", "enemy=%.1f self=%.1f" % [e.mp, c.mp])
	await sim(1.1)
	var before := e.mp
	c.kit.on_hit_dealt(c, e, mh, 10.0)
	check(e.mp < before, "[warlock] control spell drains again after the interval")
	# Assassin: Life-Risking Strike hits one target for (about) the hp cost.
	await new_world()
	c = spawn("assassin", 0, Vector3.ZERO, 0.0)
	var a1 := spawn("test_dummy", 1, Vector3(0, 0, -1.8), PI)
	var a2 := spawn("test_dummy", 1, Vector3(0.8, 0, -1.9), PI)
	await sim(0.1)
	c.input.target_uid = a1.uid
	await sim(DT)
	var hp0 := c.hp
	var t0 := a1.hp + a2.hp
	c.start_skill(c.kit.skill_for_slot(6))
	await sim(1.0)
	var cost := hp0 - c.hp
	var dealt := t0 - (a1.hp + a2.hp)
	check(cost > 0.0 and dealt > cost * 0.8 and dealt < cost * 1.25, "[assassin] life-risking strike deals ~ its hp cost once",
		"cost=%.0f dealt=%.0f" % [cost, dealt])


# ================================================================== mini fight
func mini_fight(kid: String) -> void:
	await new_world()
	var c := spawn(kid, 0, Vector3.ZERO, 0.0)
	var d := spawn("test_dummy", 1, Vector3(0, 0, -3), PI)
	await sim(0.1)
	d.max_hp = 200000.0
	d.hp = d.max_hp
	var kit: ClassKit = c.kit
	var desired := 7.0 if kit.role == "control" and kit.weapon_type == "cane" else 1.8
	var casts := 0
	var used: Dictionary = {}
	await physics_frame
	var frames := roundi(30.0 / DT)
	for i in frames:
		c.input.target_uid = d.uid
		c.input.aim_point = d.center()
		var to := CoreUtil.flat(d.global_position - c.global_position)
		c.input.move = to.normalized() if to.length() > desired + 0.5 else Vector3.ZERO
		if c.state != Fighter.State.CAST or (c.runner != null and c.runner.in_cancel_window()):
			for slot: int in [7, 1, 2, 3, 4, 5, 6, 0]:
				if c.can_cast(slot) and c.try_cast(slot):
					casts += 1
					used[slot] = true
					break
		world.step(DT)
		if i % 30 == 0:
			await physics_frame
	var dealt := d.max_hp - d.hp
	var dps := dealt / 30.0
	print("KITS[nightwalker] %s mini-fight: %d casts, slots used %s, damage %.0f, dps %.1f, mp left %.0f" % [
		kid, casts, str(used.keys()), dealt, dps, c.mp])
	check(dps > 80.0 and dps < 2000.0, "[%s] mini-fight dps sane" % kid, "%.1f" % dps)
	check(used.size() >= 6, "[%s] mini-fight used most skills" % kid, str(used.keys()))
