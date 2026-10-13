extends "res://tests/test_core_base.gd"
## CORE skill/action tests: projectile, ground AoE delay, zones, beam, trap, pull, dash/blink/leap, heal/buff,
## taunt, summon lifecycle, cooldowns/MP/charges, custom/unknown actions, data helpers, Registry.


func run_tests() -> void:
	suite_name = "skills"
	await t_data_helpers()
	await t_projectile()
	await t_ground_delay()
	await t_zones_and_line()
	await t_beam()
	await t_trap()
	await t_pull_dash_blink_leap()
	await t_heal_buff()
	await t_taunt()
	await t_summon()
	await t_cooldowns()
	await t_custom_and_requires()
	await t_ultimate()


func _pair(dist: float = 1.5) -> Array:
	await new_world()
	var a := spawn(0, Vector3(0, 0, 0), 0.0)
	var v := spawn(1, Vector3(0, 0, -dist), PI)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	return [a, v]


func t_data_helpers() -> void:
	var h := Hit.normalize({"dmg": 2, "type": "magic", "statuses": [{"id": "slow", "dur": 2}]})
	var all_keys := true
	for k: String in Hit.DEFAULTS:
		if not h.has(k):
			all_keys = false
	check(all_keys, "Hit.normalize fills every default key")
	check(h["dmg"] == 2.0 and h["type"] == "magic" and h["hitstun"] == 0.35 and h["juggle_cost"] == 10.0,
		"Hit.normalize keeps overrides and defaults")
	check((h["statuses"] as Array).size() == 1 and (h["statuses"][0] as Dictionary)["power"] == 1.0, "Hit statuses normalised")
	var junk := Hit.normalize({"dmg": "abc", "launch": null, "statuses": 5})
	check(junk["dmg"] == 1.0 and junk["launch"] == 0.0 and (junk["statuses"] as Array).is_empty(), "Hit.normalize survives junk")
	var inp := FighterInput.new()
	inp.move = Vector3(0.6, 0, -0.8)
	inp.aim_point = Vector3(1, 2, 3)
	inp.press(3)
	inp.jump = true
	inp.held = 5
	inp.target_uid = 42
	inp.press_id = 7
	var back := FighterInput.from_dict(inp.to_dict())
	check(back.move.is_equal_approx(inp.move) and back.aim_point == inp.aim_point and back.pressed == inp.pressed
		and back.jump and back.held == 5 and back.target_uid == 42 and back.press_id == 7, "FighterInput dict round-trip")
	var bad := FighterInput.from_dict({"m": "x", "p": "y"})
	check(bad.move == Vector3.ZERO and bad.pressed == 0, "FighterInput.from_dict survives junk")
	var reg := root.get_node("Registry")
	check(reg.call("get_kit", "test_dummy") == kit, "Registry.register_kit / get_kit")
	check(reg.call("get_skill", &"test_dummy.atk2") != null, "Registry.get_skill finds chain parts")
	var groups: Dictionary = reg.call("kit_ids_by_group")
	check(groups.keys().slice(0, 7) == ["swordsman", "mage", "gunner", "fighter", "nightwalker", "priest", "unspecialized"],
		"kit_ids_by_group ordered groups", str(groups.keys()))
	reg.call("register_mob_def", "test_slime", {"name_cn": "史莱姆", "name_en": "Slime", "stats": {"hp": 2000.0},
		"skills": [{"id": "test_slime.bump", "cooldown": 1.0, "cast_time": 0.3, "range": 2.0,
		"steps": [{"t": 0.1, "type": "melee", "hit": {"dmg": 0.5}}]}]})
	await new_world()
	var m := world.spawn_fighter({"kind": "mob", "mob_id": "test_slime", "team": 1, "pos": Vector3(0, 0, -2)})
	check(m != null and m.max_hp == 2000.0 and m.kit == null and m.get_skill(0) != null, "mob spawns from registered mob def")
	check(m.name == str(m.uid) and world.get_fighter(m.uid) == m, "node name == uid and uid lookup")
	check(m.has_node("Sync") and m.get_node("Sync") is MultiplayerSynchronizer, "MultiplayerSynchronizer 'Sync' built")
	var cfg := (m.get_node("Sync") as MultiplayerSynchronizer).replication_config
	check(cfg.has_property(NodePath(".:cooldowns_packed")) and cfg.has_property(NodePath(".:facing_yaw")), "replication config has properties")


func t_projectile() -> void:
	var p: Array = await _pair(12.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hp0 := v.hp
	a.input.press(2)
	await sim(0.2)
	check(world.effects.size() >= 1 and world.effects[0] is Projectile, "projectile spawned")
	await sim(0.8)
	check(v.hp < hp0, "projectile hits at range (12m)")
	check(approx(hp0 - v.hp, expected(1.0, true), 1.0), "projectile magic damage", "%.1f" % (hp0 - v.hp))
	check(world.effects.is_empty(), "non-piercing projectile removed after hit")
	# Out of range: 30 m away.
	await new_world()
	a = spawn(0, Vector3(0, 0, 0), 0.0)
	v = spawn(1, Vector3(0, 0, -30), PI)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	hp0 = v.hp
	a.input.press(2)
	await sim(2.0)
	check(v.hp == hp0, "projectile expires at max range (20m)")
	check(world.effects.is_empty(), "expired projectile cleaned up")


func t_ground_delay() -> void:
	var p: Array = await _pair(8.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hp0 := v.hp
	a.input.press(3)
	await sim(0.6)
	check(v.hp == hp0, "delayed ground AoE does not hit before delay")
	check(not world.effects.is_empty() and world.effects[0] is AreaEffect, "ground AoE (telegraph) exists")
	await sim(0.5)
	check(v.hp < hp0, "delayed ground AoE hits after delay")
	check(approx(hp0 - v.hp, expected(2.0, true), 1.0), "ground AoE damage", "%.1f" % (hp0 - v.hp))
	check(v.state == Fighter.State.LAUNCHED or v.state == Fighter.State.KNOCKDOWN, "ground knockdown hit", v.state_name())
	# Out of radius: victim steps out before detonation.
	await new_world()
	a = spawn(0, Vector3(0, 0, 0), 0.0)
	v = spawn(1, Vector3(0, 0, -8), PI)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	hp0 = v.hp
	a.input.press(3)
	await sim(0.2)
	v.global_position = Vector3(6, 0, -8)
	await sim(1.2)
	check(v.hp == hp0, "dodging the telegraph avoids the hit")


func t_zones_and_line() -> void:
	var p: Array = await _pair(5.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hp0 := v.hp
	a.start_skill(skill("lance"))
	await sim(0.1)
	check(v.hp < hp0, "line ground AoE hits target in front")
	var ally := spawn(0, Vector3(2, 0, 0), 0.0)
	await sim(0.1)
	ally.hp = ally.max_hp * 0.5
	a.hp = a.max_hp * 0.5
	var ahp := ally.hp
	var ehp := v.hp
	a.start_skill(skill("holy_ground"))
	await sim(2.2)
	check(ally.hp > ahp and a.hp > a.max_hp * 0.5, "ally zone heals allies over time")
	check(approx(ally.hp - ahp, ally.max_hp * 0.02 * 5.0, ally.max_hp * 0.021), "zone ticks (~5 ticks over 2s)", "%.1f" % (ally.hp - ahp))
	check(v.hp == ehp, "ally zone does not affect enemies")
	check(world.effects.is_empty(), "zone expires after duration")


func t_beam() -> void:
	var p: Array = await _pair(6.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hits: Array = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: hits.append(amt))
	a.start_skill(skill("ray"))
	await sim(0.3)
	check(a.state == Fighter.State.CAST, "caster held in CAST during beam")
	await sim(0.5)
	check(hits.size() >= 4, "beam ticks hit repeatedly", str(hits.size()))
	await sim(0.3)
	check(a.state != Fighter.State.CAST and world.effects.is_empty(), "beam ends and releases caster")
	# Interrupted beam is removed.
	a.start_skill(skill("ray"))
	await sim(0.1)
	a.receive_hit(v, {"dmg": 0.1, "hitstun": 0.3}, v.global_position)
	await sim(DT * 2)
	check(world.effects.is_empty(), "interrupt removes attached beam", "state=%s eff=%s" % [a.state_name(), str(world.effects)])


func t_trap() -> void:
	var p: Array = await _pair(6.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	a.start_skill(skill("snare"))
	await sim(0.1)
	var trap := world.effects[0] as AreaEffect
	check(trap != null and trap.mode == "trap", "trap placed")
	var hp0 := v.hp
	await sim(0.5)
	check(v.hp == hp0 and is_instance_valid(trap) and trap.alive, "trap waits for an enemy")
	v.global_position = Vector3(0.5, 0, 0)
	await sim(0.1)
	check(v.hp < hp0, "trap triggers on enemy entry")
	check(v.has_status(&"root"), "trap applies on_trigger_statuses")
	check(world.effects.is_empty(), "trap triggers once and is removed")
	# max_active
	await sim(0.1)
	a.global_position = Vector3(-10, 0, 10)
	v.global_position = Vector3(10, 0, -10)
	for i in 3:
		a.start_skill(skill("snare"))
		await sim(0.3)
		a.global_position += Vector3(3, 0, 0)
	var traps := 0
	for e: Node in world.effects:
		if e is AreaEffect and (e as AreaEffect).mode == "trap" and (e as AreaEffect).alive:
			traps += 1
	check(traps == 2, "trap max_active per caster enforced", str(traps))


func t_pull_dash_blink_leap() -> void:
	var p: Array = await _pair(6.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var d0 := a.global_position.distance_to(v.global_position)
	a.start_skill(skill("vortex"))
	await sim(0.6)
	var d1 := a.global_position.distance_to(v.global_position)
	check(d1 < d0 - 2.0, "pull draws enemies toward caster", "%.2f -> %.2f" % [d0, d1])
	# Dash forward through enemy, hitting it once.
	await new_world()
	a = spawn(0, Vector3(0, 0, 0), 0.0)
	v = spawn(1, Vector3(0, 0, -3), PI)
	await sim(0.1)
	var hits: Array = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: hits.append(amt))
	a.start_skill(skill("charge"))
	await sim(0.6)
	check(a.global_position.z < -5.0, "dash moves caster forward ~6m", "z=%.2f" % a.global_position.z)
	check(hits.size() == 1, "dash hit applied once per target", str(hits.size()))
	# Blink behind target.
	await new_world()
	a = spawn(0, Vector3(0, 0, 0), 0.0)
	v = spawn(1, Vector3(0, 0, -6), PI)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	a.start_skill(skill("shadow_step"))
	await sim(DT)
	check(a.global_position.z < v.global_position.z - 0.5, "blink behind_target puts caster behind victim", "a=%s v=%s" % [a.global_position, v.global_position])
	var base := v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	check(approx(base - v.hp, expected(1.0) * 1.2, 1.0), "attack after blink is a back attack")
	# Leap slam.
	await new_world()
	a = spawn(0, Vector3(0, 0, 0), 0.0)
	v = spawn(1, Vector3(0, 0, -7), PI)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	var hp0 := v.hp
	a.start_skill(skill("slam"))
	await sim(0.25)
	check(a.global_position.y > 1.0, "leap arcs upward", "y=%.2f" % a.global_position.y)
	await sim(0.5)
	check(a.global_position.distance_to(v.global_position) < 2.0, "leap lands next to target")
	check(v.hp < hp0, "leap landing AoE hits")


func t_heal_buff() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var ally := spawn(0, Vector3(3, 0, 0), 0.0)
	await sim(0.1)
	ally.hp = ally.max_hp * 0.3
	var h0 := ally.hp
	a.start_skill(skill("heal_wave"))
	await sim(DT)
	check(approx(ally.hp - h0, ally.max_hp * 0.2, 1.0), "heal targets lowest ally for 20%", "%.1f" % (ally.hp - h0))
	check(ally.has_status(&"regen"), "heal applies hot (regen)")
	var h1 := ally.hp
	await sim(1.05)
	check(ally.hp > h1, "regen ticks")
	check(a.healing_done > 0.0, "healing_done tracked")
	# atk_up buff raises damage.
	var base := v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	var normal := base - v.hp
	a.start_skill(skill("rage"))
	await sim(0.2)
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	check(approx(base - v.hp, normal * 1.5, 1.0), "atk_up buff +50% damage", "%.1f vs %.1f" % [base - v.hp, normal])
	# Shield absorbs.
	v.add_shield(300.0, 5.0)
	base = v.hp
	v.receive_hit(a, {"dmg": 0.5, "hitstun": 0.0}, a.global_position)
	check(v.hp == base and v.shield_hp < 300.0, "shield absorbs damage first")
	# Cleanse.
	a.add_status(&"poison", 5.0, 1.0, v)
	a.add_status(&"slow", 5.0, 0.3, v)
	a.add_status(&"atk_up", 5.0, 0.3, a)
	a.start_skill(skill("purify"))
	await sim(DT)
	check(not a.has_status(&"poison") and not a.has_status(&"slow") and a.has_status(&"atk_up"), "cleanse removes only negatives")


func t_taunt() -> void:
	var p: Array = await _pair(4.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var other := spawn(0, Vector3(4, 0, 0), 0.0)
	await sim(0.1)
	v.input.target_uid = other.uid
	await sim(DT)
	check(v.target_uid == other.uid, "victim initially targets other")
	a.start_skill(skill("provoke"))
	await sim(DT * 2)
	check(v.has_status(&"taunted") and v.status.source(&"taunted") == a, "taunt applies taunted with src")
	check(v.target_uid == a.uid, "taunt forces lock-on to taunter")
	check(v.top_threat() == a, "taunt puts taunter at top of threat")
	await sim(3.2)
	check(not v.has_status(&"taunted") and v.target_uid == other.uid, "taunt expires and target returns")


func t_summon() -> void:
	var p: Array = await _pair(8.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	a.input.press(6)
	await sim(0.4)
	var s := world.summons_of(a, "wolf")
	check(s.size() == 1, "summon spawned", str(s.size()))
	if s.size() == 1:
		var w: Fighter = s[0]
		check(w is Summon and w.kind == "summon" and w.owner_uid == a.uid, "summon kind/owner")
		check(w.team == a.team, "summon inherits owner team")
		check(w.max_hp == 1500.0 and w.get_skill(0) != null, "summon uses kit.summons def stats/skills")
		check(w.brain != null, "summon has a pet brain")
		var hp0 := v.hp
		await sim(3.0)
		check(v.hp < hp0, "pet brain attacks the enemy", "hp %.0f -> %.0f" % [hp0, v.hp])
		await sim(5.5)
		check(not is_instance_valid(w) or not w.is_alive(), "summon expires after duration")
		await sim(1.5)
		await process_frame
		check(not is_instance_valid(w), "expired summon freed")
	# max_active + owner death removes summons.
	a.reset_cooldowns()
	a.input.press(6)
	await sim(0.5)
	a.input.press(6)
	await sim(0.5)
	a.reset_cooldowns()
	a.input.press(6)
	await sim(0.5)
	check(world.summons_of(a, "wolf").size() == 2, "summon max_active enforced", str(world.summons_of(a, "wolf").size()))
	a.kill(v)
	await sim(DT * 2)
	check(world.summons_of(a, "").is_empty(), "owner death expires summons")


func t_cooldowns() -> void:
	var p: Array = await _pair(8.0)
	var a: Fighter = p[0]
	check(a.try_cast(3), "cast meteor")
	await sim(0.6)
	check(a.cast_block_reason(3) == "cooldown", "meteor on cooldown")
	check(a.cooldowns_packed[3] > 4.0 and a.cooldowns_packed[3] <= 6.0, "cooldowns_packed reports remaining", str(a.cooldowns_packed[3]))
	await sim(5.6)
	check(a.can_cast(3), "meteor ready after 6s")
	var mp0 := a.mp
	a.try_cast(3)
	check(approx(mp0 - a.mp, 60.0, 0.5), "mp cost deducted")
	await sim(0.7)
	a.mp = 10.0
	check(a.cast_block_reason(5) == "mp", "insufficient mp blocks cast")
	await sim(1.0)
	check(a.mp > 10.0, "mp regenerates")
	a.mp = a.max_mp
	# Charges (slot 6: 2 charges, cd 10).
	a.reset_cooldowns()
	check(a.get_charges(6) == 2, "charges start full")
	check(a.try_cast(6), "charge 1")
	await sim(0.5)
	check(a.try_cast(6), "charge 2")
	await sim(0.5)
	check(a.cast_block_reason(6) == "cooldown" and a.get_charges(6) == 0, "no charges left")
	await sim(9.2)
	check(a.get_charges(6) == 1 and a.can_cast(6), "one charge restored after cooldown")
	await sim(10.2)
	check(a.get_charges(6) == 2, "second charge restored")
	check(a.charges_packed[6] == 2, "charges_packed replicated value")


func t_custom_and_requires() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var calls0: int = kit.get("custom_calls")
	var r := a.start_skill(skill("ritual"))
	check(int(kit.get("custom_calls")) == calls0 + 2 and r.vars.get("ritual", false), "custom action calls kit method with args/runner")
	check(a.anim_key == &"taunt", "anim action switches animation")
	await sim(0.2)
	check(a.is_alive(), "unknown action type does not crash (warned once)")
	var base_sk := skill("sky_cut")
	check(a.find_skill(base_sk.id) == base_sk, "requires skill lookup")
	# requires airborne: inject sky_cut into slot 3 temporarily.
	var saved := a.skills[3]
	var sc := SkillDef.from_dict({"id": "tmp.sky", "slot": 3, "cooldown": 0.5, "cast_time": 0.2, "requires": {"airborne": true},
		"steps": [{"t": 0.0, "type": "melee"}]})
	a.skills[3] = sc
	check(a.cast_block_reason(3) == "requires", "requires airborne blocks on ground")
	a.input.jump = true
	await sim(0.15)
	check(a.can_cast(3), "requires airborne satisfied in the air")
	a.skills[3] = saved
	await sim(1.0)


func t_ultimate() -> void:
	var p: Array = await _pair(4.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hits: Array = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: hits.append(amt))
	check(a.try_cast(7), "ultimate cast")
	await sim(1.6)
	check(hits.size() >= 5, "ultimate dash + multi_melee + ground all hit", str(hits.size()))
	check(a.runner == null and a.state != Fighter.State.CAST, "ultimate finished")
