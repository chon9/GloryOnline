extends SceneTree
## KITS tests: 散人 Unspecialized (classes/unspecialized.gd).
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_unspecialized.gd

const DT: float = 1.0 / 60.0
const KIT_ID: String = "unspecialized"
const DUMMY_PATH: String = "res://tests/test_kit_dummy.gd"

var passed: int = 0
var failed: int = 0
var world: World = null
var reg: Node = null
var kit: ClassKit = null


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
		reg.call("register_kit", (load(DUMMY_PATH) as Script).new())
		kit = reg.call("get_kit", KIT_ID)
		check(kit != null, "Registry has kit '%s'" % KIT_ID)
		if kit != null:
			t_metadata()
			await t_each_skill()
			await t_weapon_forms()
			await t_myriad_forms()
			await t_myriad_rules()
			await t_mini_fight()
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("KITS[unspecialized] TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ==================================================================== harness
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


func sim(seconds: float) -> void:
	await physics_frame
	var n := maxi(1, roundi(seconds / DT))
	for i in n:
		world.step(DT)


func aim(c: Fighter, e: Fighter) -> void:
	c.input.target_uid = e.uid
	c.input.aim_point = e.global_position


## Fresh scene: caster at origin facing -Z, enemy1 at distance `dist`, enemy2 beside it, ally at 50% hp.
func setup_scene(dist: float) -> Array:
	await new_world()
	var c := spawn(KIT_ID, 0, Vector3.ZERO, 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -dist), PI)
	var e2 := spawn("test_dummy", 1, Vector3(1.2, 0, -dist - 0.5), PI)
	var al := spawn("test_dummy", 0, Vector3(-2.5, 0, 1.0), 0.0)
	await sim(0.1)
	al.hp = al.max_hp * 0.5
	aim(c, e1)
	await sim(DT)
	return [c, e1, e2, al]


# ==================================================================== tests
func t_metadata() -> void:
	check(kit.name_cn != "" and kit.name_en != "", "names CN/EN set", "%s %s" % [kit.name_cn, kit.name_en])
	check(kit.group_id == "unspecialized" and kit.group_cn != "" and kit.group_en != "", "group set")
	check(kit.weapon_type == "umbrella" and kit.weapon_name_cn == "千机伞", "weapon umbrella 千机伞")
	check(kit.famous.contains("叶修") and kit.model != "" and kit.role != "", "famous/model/role set")
	check(kit.skills.size() == 8, "exactly 8 skills", str(kit.skills.size()))
	var slots_ok := true
	var names_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s == null or s.slot != i:
			slots_ok = false
		elif s.name_cn == "" or s.name_en == "" or s.desc == "":
			names_ok = false
	check(slots_ok, "skills in slots 0..7")
	check(names_ok, "every skill has CN/EN names and desc")
	check(kit.skills[7].has_tag("ultimate") and kit.skills[7].cooldown >= 40.0 and kit.skills[7].cooldown <= 90.0,
		"slot 7 tagged ultimate with long cooldown")
	check(kit.skills[1].has_tag("launcher") or kit.skills[2].has_tag("launcher"), "launcher in slot 1-2")
	check(kit.skills[0].chain.size() >= 2 and kit.skills[0].chain.size() <= 4, "slot 0 basic chain of 2-4")
	var chain_ok := true
	for cid: StringName in kit.skills[0].chain:
		if kit.get_skill_by_id(cid) == null:
			chain_ok = false
	check(chain_ok, "chain parts resolvable")
	check(kit.passives.size() >= 1 and str(kit.passives[0].get("name_cn", "")) == "千变", "passive 千变 Myriad Forms listed")
	var forms_ok := true
	for s: SkillDef in kit.skills:
		if s.steps.is_empty() or str(s.steps[0].get("type", "")) != "custom" or str(s.steps[0].get("method", "")) != "form" \
				or float(s.steps[0].get("t", 1.0)) != 0.0:
			forms_ok = false
	check(forms_ok, "every skill begins with a t=0 form switch")
	var st: Dictionary = kit.get_stats()
	check(st["hp"] >= 6000.0 and st["hp"] <= 9000.0 and st["move_speed"] >= 5.5 and st["move_speed"] <= 6.8, "stats in range")


func t_each_skill() -> void:
	# slot -> enemy distance
	var dists: Dictionary = {0: 2.0, 1: 2.0, 2: 3.0, 3: 8.0, 4: 2.2, 5: 6.0, 6: 1.8, 7: 2.5}
	for slot in 8:
		var s: SkillDef = kit.skills[slot]
		var sc: Array = await setup_scene(float(dists[slot]))
		var c: Fighter = sc[0]
		var e1: Fighter = sc[1]
		var e2: Fighter = sc[2]
		var al: Fighter = sc[3]
		var hp1 := e1.hp
		var hp2 := e2.hp
		var ally_hp := al.hp
		c.reset_cooldowns()
		var label := "slot %d %s" % [slot, s.display_name()]
		var ok := c.try_cast(slot)
		check(ok, label + ": try_cast succeeds", c.cast_block_reason(slot))
		var launched := false
		var stunned := false
		var max_t := 3.0
		var t := 0.0
		while t < max_t:
			await sim(0.05)
			t += 0.05
			if slot == 0 and c.state != Fighter.State.CAST and t < 1.5:
				aim(c, e1)
				c.try_cast(0)
			if e1.state == Fighter.State.LAUNCHED:
				launched = true
			if e1.has_status(&"stun") or e1.state == Fighter.State.STUNNED:
				stunned = true
		var dmg := hp1 - e1.hp
		print("  %s: target dmg %.0f (%.1f%% of max hp), splash %.0f" % [label, dmg, dmg / e1.max_hp * 100.0, hp2 - e2.hp])
		check(dmg > 0.0, label + ": damages target")
		check(al.hp >= ally_hp, label + ": ally not harmed")
		if s.has_tag("launcher"):
			check(launched, label + ": launches target (LAUNCHED)")
		if s.has_tag("cc") and slot != 3:
			check(stunned or launched, label + ": applies cc")
		if slot == 3:
			check(stunned or dmg > 0.0, label + ": cc shells land")
		if s.has_tag("aoe") and slot != 5:
			check(e2.hp < hp2, label + ": aoe hits second enemy")
		if slot == 7:
			check(dmg >= e1.max_hp * 0.12 and dmg <= e1.max_hp * 0.4, label + ": ultimate damage 12-40% hp",
				"%.1f%%" % (dmg / e1.max_hp * 100.0))
		if slot == 5:
			check(c.global_position.distance_to(Vector3.ZERO) > 3.0, label + ": leaps toward target")


func t_weapon_forms() -> void:
	var sc: Array = await setup_scene(3.0)
	var c: Fighter = sc[0]
	var e1: Fighter = sc[1]
	check(c.weapon_form == "", "spawn uses kit weapon (weapon_form empty)")
	var expect: Dictionary = {1: "umbrella", 3: "umbrella_gun", 4: "tachi", 5: "tonfa", 6: "umbrella_open", 0: "umbrella"}
	var seen: Dictionary = {}
	for slot: int in [1, 3, 4, 5, 6, 0]:
		e1.global_position = Vector3(0, 0, -3.0)
		c.global_position = Vector3.ZERO
		await sim(0.05)
		aim(c, e1)
		c.reset_cooldowns()
		c.start_skill(c.resolve_skill(slot), slot)
		await sim(DT)
		check(c.weapon_form == expect[slot], "slot %d switches weapon_form to %s" % [slot, expect[slot]], c.weapon_form)
		seen[c.weapon_form] = true
		await sim(1.0)
	check(seen.size() >= 5, "five distinct forms displayed", str(seen.keys()))
	# Ultimate cycles 4 forms.
	c.reset_cooldowns()
	var forms_in_ult: Dictionary = {}
	c.start_skill(kit.skills[7], 7)
	for i in 120:
		await sim(DT)
		forms_in_ult[c.weapon_form] = true
	check(forms_in_ult.size() >= 4, "ultimate cycles >= 4 forms", str(forms_in_ult.keys()))


func t_myriad_forms() -> void:
	var sc: Array = await setup_scene(2.0)
	var c: Fighter = sc[0]
	var e1: Fighter = sc[1]
	var dmg_base := 0.0
	# Baseline single skill damage at 0 stacks.
	c.start_skill(kit.skills[6], 6)
	var hp0 := e1.hp
	await sim(0.6)
	dmg_base = hp0 - e1.hp
	check(kit.call("myriad_stacks", c) == 0, "first skill gives 0 stacks")
	# Weave lance -> gun -> blade -> fist -> shield -> lance quickly.
	for slot: int in [1, 3, 4, 5, 6, 2]:
		e1.global_position = c.global_position + Vector3(0, 0, -2.0)
		aim(c, e1)
		c.start_skill(kit.skills[slot], slot)
		await sim(0.7)
	var stacks: int = kit.call("myriad_stacks", c)
	check(stacks == 5, "weaving 6 different forms reaches max 5 stacks", str(stacks))
	check(c.kit_counter == 5 and c.kit_counter_max == 5, "Myriad Forms stacks live in the replicated kit_counter",
		"%d/%d" % [c.kit_counter, c.kit_counter_max])
	check(is_equal_approx(float(c.stat_bonus.get("dmg_out", 0.0)), 0.25), "dmg_out bonus = +25%",
		str(c.stat_bonus.get("dmg_out", 0.0)))
	# Damage really goes up: shield attack again with 5 stacks (shield differs from lance, stays at cap).
	await sim(0.8)
	e1.reset_for_round(c.global_position + Vector3(0, 0, -1.8))
	await sim(0.3)
	aim(c, e1)
	hp0 = e1.hp
	c.start_skill(kit.skills[6], 6)
	await sim(0.6)
	var dmg_buffed := hp0 - e1.hp
	check(dmg_buffed > dmg_base * 1.15, "stacked damage higher", "%.0f vs %.0f" % [dmg_buffed, dmg_base])
	# Same form repeated does not add.
	c.start_skill(kit.skills[6], 6)
	await sim(0.3)
	check(kit.call("myriad_stacks", c) == 5, "same form keeps (does not add) stacks")
	# Expiry after 3 s without casting.
	await sim(3.3)
	check(kit.call("myriad_stacks", c) == 0 and is_equal_approx(float(c.stat_bonus.get("dmg_out", 0.0)), 0.0),
		"stacks expire after 3 s idle")
	check(c.kit_counter == 0, "kit_counter clears with the stacks", str(c.kit_counter))
	# A slow weave (> 3 s apart) never stacks.
	c.start_skill(kit.skills[1], 1)
	await sim(3.4)
	c.start_skill(kit.skills[3], 3)
	await sim(0.2)
	check(kit.call("myriad_stacks", c) == 0, "different form after > 3 s gives no stack")


func t_myriad_rules() -> void:
	var sc: Array = await setup_scene(2.0)
	var c: Fighter = sc[0]
	var e1: Fighter = sc[1]
	# Basic attacks never add stacks, even when alternated with other forms.
	for slot: int in [3, 0, 3, 0]:
		e1.global_position = c.global_position + Vector3(0, 0, -2.0)
		aim(c, e1)
		c.start_skill(kit.skills[slot], slot)
		await sim(0.7)
	check(kit.call("myriad_stacks", c) == 0, "basic attacks give no Myriad Forms stacks",
		str(kit.call("myriad_stacks", c)))
	await sim(3.5)
	# After the ultimate (ends in lance), Shield Attack is a real form change and stacks; a lance skill is not.
	e1.reset_for_round(c.global_position + Vector3(0, 0, -2.0))
	await sim(0.2)
	aim(c, e1)
	c.start_skill(kit.skills[7], 7)
	await sim(2.1)
	check(str(c.get_meta(&"mf_last_form", "")) == "lance", "ultimate records its final form (lance)",
		str(c.get_meta(&"mf_last_form", "")))
	var s0: int = kit.call("myriad_stacks", c)
	c.start_skill(kit.skills[6], 6)
	await sim(0.3)
	check(int(kit.call("myriad_stacks", c)) == s0 + 1, "Shield Attack after ultimate adds a stack",
		"%d -> %d" % [s0, int(kit.call("myriad_stacks", c))])
	# Idle > 3 s: stacks expire and the umbrella returns to its default look.
	await sim(3.6)
	check(kit.call("myriad_stacks", c) == 0 and c.weapon_form == "", "idle resets stacks and weapon_form",
		"stacks %d form '%s'" % [kit.call("myriad_stacks", c), c.weapon_form])


func t_mini_fight() -> void:
	await new_world()
	var c := spawn(KIT_ID, 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -2.5), PI)
	await sim(0.1)
	e.max_hp = 200000.0
	e.hp = e.max_hp
	var hp0 := e.hp
	var mp_low := c.mp
	var casts: Dictionary = {}
	var order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	var t := 0.0
	var max_stacks := 0
	var by_slot: Dictionary = {}
	var last_slot := -1
	while t < 30.0:
		var hp_before := e.hp
		aim(c, e)
		var to_e := CoreUtil.flat(e.global_position - c.global_position)
		var want_range := 2.4
		if c.state != Fighter.State.CAST and to_e.length() > want_range:
			c.input.move = to_e.normalized()
		else:
			c.input.move = Vector3.ZERO
		if c.can_act() or c.state == Fighter.State.CAST:
			for slot: int in order:
				var sk_def: SkillDef = kit.skills[slot]
				if slot != 0 and to_e.length() > sk_def.range + 0.5:
					continue
				if c.can_cast(slot) and c.try_cast(slot):
					casts[slot] = int(casts.get(slot, 0)) + 1
					last_slot = slot
					break
		await sim(0.1)
		t += 0.1
		by_slot[last_slot] = int(by_slot.get(last_slot, 0)) + int(hp_before - e.hp)
		mp_low = minf(mp_low, c.mp)
		max_stacks = maxi(max_stacks, int(kit.call("myriad_stacks", c)))
	var dmg := hp0 - e.hp
	var dps := dmg / 30.0
	print("  damage by last cast slot: %s" % str(by_slot))
	print("  mini-fight 30s: total %.0f dmg, DPS %.1f (%.2f%% of an 8000hp target per s), casts %s, min mp %.0f, max stacks %d"
		% [dmg, dps, dps / 8000.0 * 100.0, str(casts), mp_low, max_stacks])
	check(dps > 120.0, "mini-fight DPS reasonable (>120)", "%.1f" % dps)
	check(dps < 1000.0, "mini-fight DPS within class band (<1000)", "%.1f" % dps)
	check(casts.size() >= 7, "rotation used >= 7 different slots", str(casts))
	check(max_stacks >= 3, "Myriad Forms stacks build in a real rotation", str(max_stacks))
