extends SceneTree
## KITS-mage headless tests: battle_mage, elementalist, witch, summoner.
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_mage.gd
## Deterministic world (World.auto_step = false, Combat.deterministic) stepped manually.

const DT: float = 1.0 / 60.0
const DUMMY_KIT: String = "res://tests/test_kit_dummy.gd"
const KITS: Array[String] = ["battle_mage", "elementalist", "witch", "summoner"]
const DAMAGE_TAGS: Array[String] = ["melee", "ranged", "aoe", "cc", "grab", "finisher", "launcher", "combo",
	"ultimate", "debuff", "zone", "interrupt"]

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
		for kid: String in KITS:
			await test_kit(kid)
		await t_battle_mage_passives()
		await t_elementalist_mobile_cast()
		await t_witch_flight()
		await t_summoner_pets()
		await t_witch_powder()
		await t_summoner_sacrifice()
		await t_summoner_mark()
		for kid: String in KITS:
			await mini_fight(kid)
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("KITS[mage] TESTS: %d passed, %d failed" % [passed, failed])
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


func sim(seconds: float, each: Callable = Callable()) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)
		if each.is_valid():
			each.call()


func aim(f: Fighter, t: Fighter) -> void:
	f.input.target_uid = t.uid
	f.input.aim_point = t.center()
	f.target_uid = t.uid


## caster at origin facing -Z, two enemy dummies in front, one wounded ally dummy behind.
func arena(kid: String) -> Dictionary:
	await new_world()
	var c := spawn(kid, 0, Vector3(0, 0, 0), 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -2.5), PI)
	var e2 := spawn("test_dummy", 1, Vector3(1.0, 0, -3.2), PI)
	var al := spawn("test_dummy", 0, Vector3(2.0, 0, 1.5), 0.0)
	await sim(0.1)
	al.hp = al.max_hp * 0.5
	aim(c, e1)
	await sim(DT)
	return {"c": c, "e1": e1, "e2": e2, "al": al}


# ================================================================== per kit
func test_kit(kid: String) -> void:
	var kit: ClassKit = reg.call("get_kit", kid)
	check(kit != null, "[%s] Registry has kit" % kid)
	if kit == null:
		return
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == "mage" and kit.group_cn != "" and kit.group_en != "",
		"[%s] names and group" % kid, "%s %s" % [kit.name_cn, kit.name_en])
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != "" and kit.famous != "",
		"[%s] weapon/model/famous metadata" % kid)
	check(not kit.passives.is_empty(), "[%s] passives listed" % kid)
	var st: Dictionary = kit.get_stats()
	check(float(st["hp"]) >= 5500.0 and float(st["hp"]) <= 9500.0 and float(st["move_speed"]) >= 5.5 and float(st["move_speed"]) <= 6.8,
		"[%s] stats within balance targets" % kid)
	check(kit.skills.size() == 8, "[%s] exactly 8 skills" % kid, str(kit.skills.size()))
	var slots_ok := true
	var names_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s == null or s.slot != i:
			slots_ok = false
			continue
		if s.name_cn == "" or s.name_en == "" or s.desc == "":
			names_ok = false
	check(slots_ok, "[%s] skills fill slots 0..7 in order" % kid)
	check(names_ok, "[%s] every skill has CN/EN name and desc" % kid)
	var ult := kit.skill_for_slot(7)
	check(ult != null and ult.has_tag("ultimate") and ult.cooldown >= 40.0 and ult.cooldown <= 90.0,
		"[%s] slot 7 is a tagged ultimate with 40-90 s cooldown" % kid)
	var l1 := kit.skill_for_slot(1)
	var l2 := kit.skill_for_slot(2)
	check((l1 != null and l1.has_tag("launcher")) or (l2 != null and l2.has_tag("launcher")), "[%s] Lv1 launcher in slot 1/2" % kid)
	var b := kit.skill_for_slot(0)
	var chain_ok := b != null and b.chain.size() >= 2 and b.chain.size() <= 4
	if chain_ok:
		for cid: StringName in b.chain:
			if kit.get_skill_by_id(cid) == null:
				chain_ok = false
	check(chain_ok, "[%s] basic attack chain of 2-4 resolvable parts" % kid)
	var cd_ok := true
	for i in range(1, 7):
		var s2 := kit.skill_for_slot(i)
		if s2 != null and (s2.cooldown < 3.0 or s2.cooldown > 16.0):
			cd_ok = false
	check(cd_ok, "[%s] normal skill cooldowns 3-16 s" % kid)
	for slot in 8:
		await cast_one(kid, slot)


func cast_one(kid: String, slot: int) -> void:
	var a: Dictionary = await arena(kid)
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	var e2: Fighter = a["e2"]
	var al: Fighter = a["al"]
	var s: SkillDef = c.get_skill(slot)
	if kid == "summoner" and slot == 6:
		world.spawn_summon(c, "goblin", Vector3(0, 0, 8), 20.0)
		await sim(DT)
	c.reset_cooldowns()
	c.mp = c.max_mp
	var hp0 := e1.hp + e2.hp
	var ally0 := al.hp
	var pos0 := c.global_position
	var flags := {"launched": false, "state": false, "status": false, "air": false, "taunted": false}
	var watch := func() -> void:
		for e: Fighter in [e1, e2]:
			if e.state == Fighter.State.LAUNCHED:
				flags["launched"] = true
			if e.state != Fighter.State.IDLE and e.state != Fighter.State.MOVE:
				flags["state"] = true
			if e.status_mask != 0:
				flags["status"] = true
			if e.has_status(&"taunted"):
				flags["taunted"] = true
		if c.global_position.y > 0.6:
			flags["air"] = true
	var label := "[%s] slot %d %s" % [kid, slot, s.display_name() if s != null else "?"]
	var ok := c.try_cast(slot)
	check(ok, label + " try_cast succeeds", c.cast_block_reason(slot))
	if slot == 0:
		for i in 2:
			await sim(0.3, watch)
			c.try_cast(0)
	await sim(3.0, watch)
	var dmg := hp0 - (e1.hp + e2.hp)
	if s == null:
		return
	var is_damage := false
	for t: String in DAMAGE_TAGS:
		if s.has_tag(t):
			is_damage = true
	if s.has_tag("summon"):
		check(world.summons_of(c).size() > 0, label + " spawns a summon")
	elif s.has_tag("escape"):
		check(c.global_position.distance_to(pos0) > 2.0, label + " moves the caster",
			"%.2f m" % c.global_position.distance_to(pos0))
	elif is_damage:
		check(dmg > 0.0 or flags["state"] or flags["status"], label + " affects enemies",
			"dmg %.0f state %s status %s" % [dmg, flags["state"], flags["status"]])
	if s.has_tag("launcher"):
		check(flags["launched"], label + " launches a target")
	if s.has_tag("heal"):
		check(al.hp > ally0, label + " heals the ally")
	if dmg > 0.0:
		print("    %s: %.0f dmg (%.1f%% of one dummy)" % [label, dmg, 100.0 * dmg / e1.max_hp])
	# Class-specific checks on the generic casts.
	if kid == "witch" and slot == 6:
		check(flags["taunted"], label + " doll taunts enemies")
	if kid == "witch" and slot == 4:
		check(e1.has_status(&"slow") and e1.get_stat("patk") < 550.0, label + " slows and weakens", "patk %.0f" % e1.get_stat("patk"))
	if kid == "witch" and slot == 7:
		check(flags["air"], label + " caster takes to the air")
	if kid == "summoner" and slot == 5:
		check(e1.has_status(&"mark"), label + " marks the target")
	if kid == "summoner" and slot == 6:
		check(c.global_position.distance_to(Vector3(0, 0, 8)) < 2.0, label + " swaps with the summon")
	if kid == "summoner" and slot == 7:
		check(world.summons_of(c).is_empty(), label + " leaves no spirits")
	if kid == "elementalist" and slot == 5:
		check(flags["state"], label + " freezes on contact")


# ================================================================== class mechanics
func t_battle_mage_passives() -> void:
	var a: Dictionary = await arena("battle_mage")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	var kit: ClassKit = c.kit
	c.reset_cooldowns()
	c.mp = c.max_mp
	c.try_cast(2)  # Dragon Tooth -> neutral chaser
	await sim(1.2)
	c.reset_cooldowns()
	c.try_cast(4)  # Circle Swing -> shadow chaser
	await sim(1.2)
	var n := int(kit.call("chaser_count", c))
	check(n == 2, "[battle_mage] Chasers generated by skills", str(n))
	for i in 10:
		kit.call("add_chaser", c, "fire")
	check(int(kit.call("chaser_count", c)) == 7, "[battle_mage] Chasers capped at 7")
	await sim(1.5)
	var hp0 := e1.hp
	# Basic chain: third hit fires all chasers.
	c.try_cast(0)
	await sim(0.3)
	c.try_cast(0)
	await sim(0.3)
	var pc := {"n": 0}
	var count_proj := func() -> void:
		var k := 0
		for e: Node in world.effects:
			if e is Projectile:
				k += 1
		pc["n"] = maxi(int(pc["n"]), k)
	c.try_cast(0)
	await sim(0.4, count_proj)
	var proj := int(pc["n"])
	check(int(kit.call("chaser_count", c)) == 0 and proj >= 1, "[battle_mage] basic finisher fires chasers as projectiles", "proj %d" % proj)
	await sim(1.5)
	check(e1.hp < hp0 and (e1.has_status(&"burn") or e1.has_status(&"def_down")), "[battle_mage] chasers hit with element riders")
	# Battle Spirit.
	c.combo_count = 21
	c._combo_timer = 1.0
	await sim(DT)
	check(float(c.stat_bonus.get("atk_speed", 0.0)) > 0.2 and c.get_stat("move_speed") > 6.4,
		"[battle_mage] Battle Spirit stages raise speed", str(c.stat_bonus))
	await sim(2.0)
	check(float(c.stat_bonus.get("atk_speed", 0.0)) == 0.0, "[battle_mage] Battle Spirit resets with the combo")
	# Falling Flower Palm: stronger vs airborne.
	a = await arena("battle_mage")
	c = a["c"]
	e1 = a["e1"]
	var e2: Fighter = a["e2"]
	e2.global_position = Vector3(10, 0, 10)
	c.reset_cooldowns()
	var h0 := e1.hp
	c.try_cast(3)
	await sim(1.0)
	var ground_dmg := h0 - e1.hp
	a = await arena("battle_mage")
	c = a["c"]
	e1 = a["e1"]
	(a["e2"] as Fighter).global_position = Vector3(10, 0, 10)
	c.reset_cooldowns()
	c.try_cast(1)
	await sim(0.25)
	c.reset_cooldowns()
	h0 = e1.hp
	var air := e1.state == Fighter.State.LAUNCHED
	c.start_skill(c.get_skill(3), 3)
	await sim(0.5)
	var air_dmg := h0 - e1.hp
	check(air and air_dmg > ground_dmg * 1.2, "[battle_mage] Falling Flower Palm stronger vs airborne",
		"ground %.0f air %.0f" % [ground_dmg, air_dmg])


func t_elementalist_mobile_cast() -> void:
	var a: Dictionary = await arena("elementalist")
	var c: Fighter = a["c"]
	var all_mobile := true
	for s: SkillDef in c.kit.skills:
		if not s.move_while_casting:
			all_mobile = false
	check(all_mobile, "[elementalist] Mobile Cast: every skill castable while moving")
	c.reset_cooldowns()
	c.input.move = Vector3(1, 0, 0)
	var p0 := c.global_position
	c.try_cast(4)
	await sim(0.4)
	check(c.state == Fighter.State.CAST and c.global_position.distance_to(p0) > 0.5, "[elementalist] moves while casting",
		"%s %.2f" % [c.state_name(), c.global_position.distance_to(p0)])
	c.input.move = Vector3.ZERO


func t_witch_flight() -> void:
	var a: Dictionary = await arena("witch")
	var c: Fighter = a["c"]
	var kit: ClassKit = c.kit
	c.input.jump = true
	await sim(0.25)
	check(not c.is_on_floor(), "[witch] normal jump airborne")
	c.input.jump = true
	await sim(DT)
	check(bool(kit.call("is_flying", c)), "[witch] double jump mounts the broom")
	await sim(0.4)
	check(c.gravity_scale < 1.0 and c.max_fall_speed > 0.0, "[witch] broom flight uses CORE gravity_scale / fall cap",
		"g %.2f cap %.2f" % [c.gravity_scale, c.max_fall_speed])
	await sim(1.2)
	var y := c.global_position.y
	check(y > 0.8, "[witch] hovers well past a normal jump arc", "y %.2f" % y)
	c.input.jump = true
	await sim(0.3)
	check(c.global_position.y > y - 0.1, "[witch] flap keeps altitude", "y %.2f -> %.2f" % [y, c.global_position.y])
	c.reset_cooldowns()
	var proj0 := 0
	c.try_cast(2)
	await sim(0.15)
	for e: Node in world.effects:
		if e is Projectile:
			proj0 += 1
	check(proj0 >= 3, "[witch] Magic Missile volley while flying", str(proj0))
	await sim(4.0)
	check(c.is_on_floor() and not bool(kit.call("is_flying", c)) and c.gravity_scale == 1.0 and c.max_fall_speed == 0.0,
		"[witch] flight ends, the witch lands and gravity is restored")
	# Canon: no cooldown - right after landing the witch can mount again.
	c.input.jump = true
	await sim(0.2)
	c.input.jump = true
	await sim(DT)
	check(bool(kit.call("is_flying", c)), "[witch] Broom Mastery has no cooldown (remount after landing)")
	# But one flight per airtime: once it ends in mid-air, a jump press does not remount until landing.
	kit.call("_end_flight", c)
	c.input.jump = true
	await sim(DT)
	check(not bool(kit.call("is_flying", c)) and not c.is_on_floor(), "[witch] no remount before touching the ground")


func t_summoner_pets() -> void:
	var a: Dictionary = await arena("summoner")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	c.reset_cooldowns()
	c.try_cast(2)
	await sim(0.6)
	for i in 4:
		c.reset_cooldowns()
		c.try_cast(3)
		await sim(0.6)
	var ids: Array[String] = []
	for s: Fighter in world.summons_of(c):
		ids.append(s.mob_id)
	check(ids.has("goblin") and ids.has("thunder_spirit") and ids.has("fire_spirit") and ids.has("ice_spirit") and ids.has("dark_spirit"),
		"[summoner] goblin + 4 rotating elemental spirits", str(ids))
	await sim(1.1)
	var strengthened := true
	for s: Fighter in world.summons_of(c):
		if not s.has_status(&"atk_up") or not s.has_status(&"def_up"):
			strengthened = false
	check(strengthened, "[summoner] Strengthen Creature buffs pets")
	var hp0 := e1.hp
	await sim(4.0)
	check(e1.hp < hp0, "[summoner] pets attack enemies", "%.0f" % (hp0 - e1.hp))
	var far: Fighter = world.summons_of(c)[0]
	far.global_position = Vector3(25, 0, 25)
	await sim(1.2)
	check(far.global_position.distance_to(c.global_position) < 6.0, "[summoner] Follow recalls straying pets")


# ================================================================== 30 s mini fight
func mini_fight(kid: String) -> void:
	await new_world()
	var c := spawn(kid, 0, Vector3(0, 0, 0), 0.0)
	var d := spawn("test_dummy", 1, Vector3(0, 0, -5), PI)
	await sim(0.1)
	d.max_hp = 1000000.0
	d.hp = d.max_hp
	aim(c, d)
	var melee := c.kit.role == "melee" or c.kit.role == "control"
	var want := 2.2 if melee else 8.0
	var hp0 := d.hp
	var casts := 0
	await physics_frame
	var n := roundi(30.0 / DT)
	for i in n:
		aim(c, d)
		var dist := CoreUtil.flat(d.global_position - c.global_position).length()
		var to := CoreUtil.flat_dir(d.global_position - c.global_position, Vector3.ZERO)
		if dist > want + 0.5:
			c.input.move = to
		elif dist < want - 2.0 and not melee:
			c.input.move = -to
		else:
			c.input.move = Vector3.ZERO
		if i % 6 == 0:
			for slot in [7, 1, 2, 3, 4, 5, 6, 0]:
				var s: SkillDef = c.get_skill(slot)
				if s == null or s.has_tag("escape"):
					continue
				if s.range > 0.0 and dist > s.range + 1.0 and not s.has_tag("summon") and not s.has_tag("buff_self"):
					continue
				if c.try_cast(slot):
					casts += 1
					break
		world.step(DT)
		if i % 600 == 0 and i > 0:
			await physics_frame
	var dealt := hp0 - d.hp
	var dps := dealt / 30.0
	print("KITS[mage] mini-fight %s: %d casts, %.0f damage in 30 s, dps %.1f" % [kid, casts, dealt, dps])
	check(casts >= 10 and dps > 80.0, "[%s] 30 s mini-fight deals sustained damage" % kid, "dps %.1f casts %d" % [dps, casts])


# ================================================================== review fixes
func t_witch_powder() -> void:
	var a: Dictionary = await arena("witch")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	var base := e1.get_stat("patk")
	c.reset_cooldowns()
	c.try_cast(4)
	await sim(0.6)
	var down := e1.get_stat("patk")
	check(down < base * 0.85 and not e1.has_status(&"atk_up"), "[witch] Disperse Powder lowers attack without a negative atk_up",
		"%.0f -> %.0f" % [base, down])
	check(e1.has_status(&"atk_down") and e1.has_status(&"cast_slow") and e1.get_stat("cast_speed") < 1.0,
		"[witch] Disperse Powder applies CORE atk_down + cast_slow", "cast_speed %.2f" % e1.get_stat("cast_speed"))
	e1.add_status(&"atk_up", 7.0, 0.1, e1)
	await sim(DT)
	var buffed := e1.get_stat("patk")
	check(buffed < base, "[witch] victim's own atk buff does not flip the powder debuff", "%.0f" % buffed)
	e1.cleanse()
	await sim(0.2)
	check(is_equal_approx(float(c.kit.call("powder_share", e1)), 0.0) and e1.get_stat("patk") > base,
		"[witch] cleanse removes the powder attack-down", "patk %.0f share %s" % [e1.get_stat("patk"), c.kit.call("powder_share", e1)])
	e1.remove_status(&"atk_up")
	# Natural expiry restores stats exactly.
	var e2: Fighter = a["e2"]
	c.reset_cooldowns()
	c.try_cast(4)
	await sim(9.0)
	check(is_equal_approx(float(e2.stat_bonus.get("patk", 0.0)), 0.0) and is_equal_approx(float(e2.stat_bonus.get("matk", 0.0)), 0.0),
		"[witch] powder attack-down expires cleanly", str(e2.stat_bonus))


func t_summoner_sacrifice() -> void:
	var a: Dictionary = await arena("summoner")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	(a["e2"] as Fighter).global_position = Vector3(20, 0, 20)
	for sid: String in ["thunder_spirit", "fire_spirit", "ice_spirit", "dark_spirit"]:
		world.spawn_summon(c, sid, e1.global_position + Vector3(0.8, 0, 0.5), 30.0)
	for i in 4:
		world.spawn_summon(c, "goblin", e1.global_position + Vector3(-0.8, 0, 0.5 + 0.2 * i), 30.0)
	await sim(DT)
	# Freeze the pets so only the ultimate itself is measured (sacrifice still detonates stunned spirits).
	for s: Fighter in world.summons_of(c):
		s.add_status(&"stun", 5.0, 1.0, null)
	c.reset_cooldowns()
	c.mp = c.max_mp
	var hp0 := e1.hp
	c.try_cast(7)
	await sim(2.0)
	var pct := 100.0 * (hp0 - e1.hp) / e1.max_hp
	var spirits := 0
	var goblins := 0
	for s: Fighter in world.summons_of(c):
		if s.mob_id == "goblin":
			goblins += 1
		else:
			spirits += 1
	print("    [summoner] Spirit Sacrifice with 4 spirits + 4 goblins: %.1f%% of target hp" % pct)
	check(pct > 12.0 and pct <= 26.0, "[summoner] Spirit Sacrifice damage within ultimate budget", "%.1f%%" % pct)
	check(spirits == 0 and goblins == 4, "[summoner] Spirit Sacrifice consumes only the spirits", "spirits %d goblins %d" % [spirits, goblins])


func t_summoner_mark() -> void:
	var a: Dictionary = await arena("summoner")
	var c: Fighter = a["c"]
	var e1: Fighter = a["e1"]
	var e2: Fighter = a["e2"]
	world.spawn_summon(c, "goblin", Vector3(-1, 0, -1), 30.0)
	world.spawn_summon(c, "fire_spirit", Vector3(1, 0, 1), 30.0)
	await sim(DT)
	c.reset_cooldowns()
	c.try_cast(5)
	await sim(0.3)
	aim(c, e2)
	await sim(1.5)
	var held := true
	for s: Fighter in world.summons_of(c):
		var t := s.get_target()
		if t != e1:
			held = false
	check(held, "[summoner] Mark keeps pets on the marked target after the owner switches")
	# Pet passive through CORE summon-hit forwarding: pet hits on the marked enemy deal +20%.
	check(bool(c.kit.call("is_marked_by", c, e1)) and not bool(c.kit.call("is_marked_by", c, e2)),
		"[summoner] Mark remembers the marked enemy")
	var pet: Fighter = world.summons_of(c)[0]
	var hp0 := e1.hp
	c.kit.on_hit_dealt(c, e1, {"_by_summon_uid": pet.uid, "dmg": 0.5}, 100.0)
	var hp1 := e1.hp
	c.kit.on_hit_dealt(c, e1, {"dmg": 0.5}, 100.0)
	var hp2 := e1.hp
	var hp_e2 := e2.hp
	c.kit.on_hit_dealt(c, e2, {"_by_summon_uid": pet.uid, "dmg": 0.5}, 100.0)
	check(is_equal_approx(hp0 - hp1, 20.0) and is_equal_approx(hp1, hp2) and is_equal_approx(hp_e2, e2.hp),
		"[summoner] pet hits on the marked enemy deal +20% (own / unmarked hits do not)",
		"%.1f %.1f %.1f" % [hp0 - hp1, hp1 - hp2, hp_e2 - e2.hp])
	var n0 := int(c.get_meta(&"mage_mark_pet_hits", 0))
	await sim(4.0)
	var n1 := int(c.get_meta(&"mage_mark_pet_hits", 0))
	check(n1 > n0, "[summoner] live pet hits reach the owner's kit (CORE summon forwarding)", "%d -> %d" % [n0, n1])
