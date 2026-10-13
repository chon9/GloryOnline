extends "res://tests/test_core_base.gd"
## CORE hit-mechanics tests: melee, chain, launch/juggle/knockdown, quick recovery, super armor, grab,
## block, back attack, downed damage, stealth, blind, death, interrupt, cancel window, requires.


func run_tests() -> void:
	suite_name = "combat"
	await t_melee_and_chain()
	await t_launch_knockdown()
	await t_juggle_protection()
	await t_quick_recovery()
	await t_super_armor_and_grab()
	await t_block_and_back()
	await t_grab_damage_once()
	await t_block_no_stun()
	await t_freed_status_source()
	await t_downed_damage()
	await t_stealth_blind()
	await t_death_signal()
	await t_interrupt_and_cancel()
	await t_requires_and_misc()


func _pair(dist: float = 1.5) -> Array:
	await new_world()
	var a := spawn(0, Vector3(0, 0, 0), 0.0)            # faces -Z
	var v := spawn(1, Vector3(0, 0, -dist), PI)         # faces +Z (toward a)
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	return [a, v]


func t_melee_and_chain() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	check(a.is_on_floor() and v.is_on_floor(), "fighters settle on the floor")
	check(a.target_uid == v.uid, "target lock resolves")
	var hp0 := v.hp
	var casted: Array[StringName] = []
	a.skill_cast.connect(func(f: Fighter, _s: int) -> void: casted.append(f.runner.skill.id if f.runner else &""))
	a.input.press(0)
	await sim(0.25)
	var dmg := hp0 - v.hp
	check(approx(dmg, expected(1.0), 1.0), "melee damage applied with formula", "dmg=%.1f exp=%.1f" % [dmg, expected(1.0)])
	check(v.state == Fighter.State.HITSTUN, "melee hit causes hitstun", v.state_name())
	# Chain: press again within cancel window / chain window.
	a.input.press(0)
	await sim(0.3)
	a.input.press(0)
	await sim(0.6)
	check(casted.size() == 3, "three basic presses cast three times", str(casted))
	if casted.size() == 3:
		check(casted[0] == &"test_dummy.atk1" and casted[1] == &"test_dummy.atk2" and casted[2] == &"test_dummy.atk3",
			"basic attack chain advances atk1->atk2->atk3", str(casted))
	await sim(1.0)
	a.input.press(0)
	await sim(DT * 2)
	check(a.runner != null and a.runner.skill.id == &"test_dummy.atk1", "chain resets after 0.6s idle")


func t_launch_knockdown() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var seen: Dictionary = {}
	a.input.press(1)
	var launched := await sim_until(func() -> bool: return v.state == Fighter.State.LAUNCHED, 0.5)
	check(launched, "launcher sets LAUNCHED")
	check(v.velocity.y > 5.0, "launch gives upward velocity", "vy=%.2f" % v.velocity.y)
	var kd := await sim_until(func() -> bool:
		seen[v.state] = true
		return v.state == Fighter.State.KNOCKDOWN, 2.0)
	check(kd, "landing from LAUNCHED goes to KNOCKDOWN")
	var up := await sim_until(func() -> bool:
		seen[v.state] = true
		return v.state == Fighter.State.IDLE, 2.0)
	check(up and seen.has(Fighter.State.GETUP), "knockdown -> getup -> idle")
	check(not a.can_cast(1) and a.cast_block_reason(1) == "cooldown", "launcher on cooldown after cast")
	check(a.mp < a.max_mp, "launcher spent mp")


func t_juggle_protection() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var h := {"dmg": 0.1, "launch": 10.0, "hitstun": 0.0, "knockback": 0.0, "juggle_cost": 30.0}
	v.receive_hit(a, h, a.global_position)
	var vy1 := v.velocity.y
	await sim(0.1)
	v.receive_hit(a, h, a.global_position)
	var vy2 := v.velocity.y
	check(v.juggle_points >= 60.0, "juggle points accumulate", "jp=%.1f" % v.juggle_points)
	check(vy2 < vy1 - 0.5, "combo protection reduces relaunch velocity", "vy1=%.2f vy2=%.2f" % [vy1, vy2])
	await sim(0.1)
	v.receive_hit(a, h, a.global_position)
	await sim(0.05)
	v.receive_hit(a, h, a.global_position)
	await sim(0.05)
	while v.juggle_points <= Fighter.JUGGLE_MAX and v.state == Fighter.State.LAUNCHED:
		v.receive_hit(a, h, a.global_position)
		await sim(0.03)
	var before := v.velocity.y
	var hp_before := v.hp
	v.receive_hit(a, h, a.global_position)
	check(v.juggle_points > Fighter.JUGGLE_MAX, "juggle points exceed cap", "jp=%.1f" % v.juggle_points)
	check(approx(v.velocity.y, before, 0.01), "above cap: no further relaunch", "before=%.2f after=%.2f" % [before, v.velocity.y])
	check(v.hp < hp_before, "above cap: still takes damage")
	var kd := await sim_until(func() -> bool: return v.state == Fighter.State.KNOCKDOWN, 2.0)
	check(kd and v.juggle_points == 0.0, "juggle points reset on landing")


func t_quick_recovery() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	v.receive_hit(a, {"dmg": 0.1, "launch": 8.0}, a.global_position)
	await sim_until(func() -> bool: return v.state == Fighter.State.KNOCKDOWN, 2.0)
	await sim(0.05)
	v.input.jump = true
	await sim(DT)
	check(v.state == Fighter.State.GETUP, "quick recovery (jump within 0.25s) skips to GETUP", v.state_name())
	check(v.has_status(&"invuln"), "getup grants invulnerability")
	var hp0 := v.hp
	v.receive_hit(a, {"dmg": 1.0}, a.global_position)
	check(v.hp == hp0, "invulnerable during getup")
	await sim(1.0)
	v.receive_hit(a, {"dmg": 0.1, "launch": 8.0, "no_recover": true}, a.global_position)
	await sim_until(func() -> bool: return v.state == Fighter.State.KNOCKDOWN, 2.0)
	v.input.jump = true
	await sim(DT)
	check(v.state == Fighter.State.KNOCKDOWN, "no_recover blocks quick recovery", v.state_name())
	await sim(1.6)
	v.receive_hit(a, {"dmg": 0.1, "launch": 8.0}, a.global_position)
	await sim_until(func() -> bool: return v.state == Fighter.State.KNOCKDOWN, 2.0)
	await sim(0.4)
	v.input.jump = true
	await sim(DT)
	check(v.state == Fighter.State.KNOCKDOWN, "late jump (>0.25s) does not recover", v.state_name())


func t_super_armor_and_grab() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	v.start_skill(skill("iron_will"))
	await sim(0.3)
	check(v.has_status(&"super_armor"), "buff applies super_armor")
	check(v.shield_hp > 0.0, "buff applies shield")
	var shield0 := v.shield_hp
	var hp0 := v.hp
	v.receive_hit(a, {"dmg": 0.5, "launch": 10.0, "knockback": 6.0}, a.global_position)
	check(v.state != Fighter.State.LAUNCHED and v.state != Fighter.State.HITSTUN, "super armor ignores launch/hitstun", v.state_name())
	check(v.shield_hp < shield0 or v.hp < hp0, "super armor still takes damage (shield absorbs first)")
	v.add_status(&"stun", 2.0, 1.0, a)
	check(not v.has_status(&"stun"), "super armor ignores stun status")
	await sim(0.2)
	v.shield_hp = 0.0
	v.remove_status(&"shield")
	hp0 = v.hp
	a.input.target_uid = v.uid
	a.input.press(4)
	var grabbed := await sim_until(func() -> bool: return v.state == Fighter.State.GRABBED, 0.5)
	check(grabbed, "grab ignores super armor (victim GRABBED)")
	check(a.state == Fighter.State.CAST, "grabber locked in CAST during grab")
	var thrown := await sim_until(func() -> bool: return v.state == Fighter.State.LAUNCHED, 1.5)
	check(thrown, "grab final hit + throw launches victim")
	check(v.hp < hp0, "grab final hit deals damage")
	var kd := await sim_until(func() -> bool: return v.state == Fighter.State.KNOCKDOWN, 2.0)
	check(kd, "thrown victim lands in knockdown")
	v.input.jump = true
	await sim(DT)
	check(v.state == Fighter.State.KNOCKDOWN, "grab throw is no_recover")


## Grab connect locks only; the HIT (damage, statuses, stun) is applied exactly once, at release.
func t_grab_damage_once() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hp0 := v.hp
	var hits: Array[float] = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: hits.append(amt))
	a.input.target_uid = v.uid
	a.input.press(4)
	var grabbed := await sim_until(func() -> bool: return v.state == Fighter.State.GRABBED, 0.5)
	check(grabbed, "grab connects")
	check(approx(v.hp, hp0, 0.01) and hits.is_empty(), "grab start deals no damage", "dmg=%.1f" % (hp0 - v.hp))
	await sim_until(func() -> bool: return v.state != Fighter.State.GRABBED, 1.5)
	await sim(0.1)
	check(hits.size() == 1, "grab applies its HIT exactly once", str(hits))
	check(approx(hp0 - v.hp, expected(1.5), 1.0), "total grab damage == expected(1.5)", "total=%.1f expected=%.1f" % [hp0 - v.hp, expected(1.5)])
	# Grab statuses/stun land once at release too.
	var p2: Array = await _pair()
	a = p2[0]
	v = p2[1]
	v.receive_hit(a, {"dmg": 0.5, "grab": true, "grab_time": 0.3, "stun": 0.5, "statuses": [{"id": "poison", "dur": 2.0, "power": 1.0}]}, a.global_position)
	check(v.state == Fighter.State.GRABBED and not v.has_status(&"poison") and not v.has_status(&"stun"), "grab start applies no statuses/stun", v.state_name())


## A guarded frontal hit chips damage only: no stun, no rider statuses.
func t_block_no_stun() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	v.add_status(&"block", 5.0, 0.6, v)
	var hp0 := v.hp
	v.receive_hit(a, {"dmg": 0.5, "stun": 1.0, "statuses": [{"id": "slow", "dur": 2.0, "power": 0.3}]}, a.global_position)
	check(v.hp < hp0, "blocked hit still chips")
	check(not v.has_status(&"stun") and v.state != Fighter.State.STUNNED, "blocked hit applies no stun", v.state_name())
	check(not v.has_status(&"slow"), "blocked hit applies no rider statuses")
	v.facing_yaw = 0.0
	v.receive_hit(a, {"dmg": 0.5, "stun": 1.0}, a.global_position)
	check(v.has_status(&"stun"), "hit from behind through block still stuns")


## A status whose source was freed keeps working and never touches the freed object.
func t_freed_status_source() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var c := spawn(0, Vector3(3, 0, 0), 0.0)
	await sim(0.1)
	v.add_status(&"poison", 3.0, 1.0, c)
	v.add_status(&"taunted", 3.0, 1.0, c)
	check(v.status.source(&"taunted") == c, "taunt source set")
	c.free()
	var hp0 := v.hp
	await sim(1.5)
	check(v.status.source(&"taunted") == null, "freed taunt source reads as null")
	check(v.hp < hp0, "poison keeps ticking after its source is freed", "%.1f -> %.1f" % [hp0, v.hp])
	check(is_instance_valid(a), "other fighters unaffected")


func t_block_and_back() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var base := v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	var front := base - v.hp
	await sim(0.1)
	v.add_status(&"block", 5.0, 0.6, v)
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0}, a.global_position)
	var blocked := base - v.hp
	check(approx(blocked, front * 0.4, 1.0), "block reduces frontal physical damage by power", "front=%.1f blocked=%.1f" % [front, blocked])
	check(v.state != Fighter.State.HITSTUN, "blocked hit causes no hitstun", v.state_name())
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0, "type": "magic", "hitstun": 0.0}, a.global_position)
	check(approx(base - v.hp, front, 1.0), "magic ignores block")
	v.receive_hit(a, {"dmg": 0.1, "grab": true, "grab_time": 0.0}, a.global_position)
	check(not v.has_status(&"block"), "grab breaks block")
	# Back attack: victim faces away from attacker.
	await sim(0.5)
	v.facing_yaw = 0.0
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	var back := base - v.hp
	check(approx(back, front * 1.2, 1.0), "back attack deals +20%", "front=%.1f back=%.1f" % [front, back])
	v.add_status(&"block", 5.0, 0.6, v)
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0, "hitstun": 0.0, "knockback": 0.0}, a.global_position)
	check(approx(base - v.hp, front * 1.2, 1.0), "block does not stop hits from behind")


func t_downed_damage() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	v.receive_hit(a, {"dmg": 0.1, "knockdown": true}, a.global_position)
	check(v.state == Fighter.State.KNOCKDOWN, "knockdown hit on grounded target -> KNOCKDOWN", v.state_name())
	var base := v.hp
	v.receive_hit(a, {"dmg": 1.0, "launch": 10.0}, a.global_position)
	check(approx(base - v.hp, expected(1.0) * 0.5, 1.0), "downed target takes 50% damage without otg")
	check(v.state == Fighter.State.KNOCKDOWN, "downed target ignores launch without otg")
	base = v.hp
	v.receive_hit(a, {"dmg": 1.0, "launch": 10.0, "otg": true}, a.global_position)
	check(approx(base - v.hp, expected(1.0), 1.0) and v.state == Fighter.State.LAUNCHED, "otg hit connects fully and relaunches")


func t_stealth_blind() -> void:
	var p: Array = await _pair(4.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	v.add_status(&"stealth", 10.0, 1.0, v)
	await sim(DT)
	check(v.is_stealthed, "stealth sets is_stealthed")
	check(world.nearest_enemy(a, 50.0) == null, "stealthed enemy is not targetable")
	check(a.get_target() == null, "lock-on drops stealthed target")
	v.receive_hit(a, {"dmg": 0.2}, a.global_position)
	await sim(DT)
	check(not v.is_stealthed and not v.has_status(&"stealth"), "stealth breaks on taking damage")
	a.add_status(&"stealth", 10.0, 1.0, a)
	v.receive_hit(a, {"dmg": 0.2}, a.global_position)
	check(not a.has_status(&"stealth"), "stealth breaks on dealing damage")
	a.add_status(&"blind", 3.0, 1.0, v)
	var base := v.hp
	v.receive_hit(a, {"dmg": 1.0}, a.global_position)
	check(v.hp == base, "blinded attacker misses (deterministic mode)")
	a.remove_status(&"blind")
	a.add_status(&"sleep", 5.0, 1.0, v)
	await sim(DT * 2)
	check(a.state == Fighter.State.STUNNED and not a.can_act(), "sleep disables the fighter")
	a.receive_hit(v, {"dmg": 0.1, "hitstun": 0.0}, v.global_position)
	await sim(DT * 2)
	check(not a.has_status(&"sleep") and a.state != Fighter.State.STUNNED, "sleep breaks on damage", a.state_name())


func t_death_signal() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var got: Array = []
	var wgot: Array = []
	v.died.connect(func(f: Fighter, k: Fighter) -> void: got.append([f, k]))
	world.fighter_died.connect(func(f: Fighter, k: Fighter) -> void: wgot.append([f, k]))
	var dmgs: Array = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: dmgs.append(amt))
	v.receive_hit(a, {"dmg": 100.0, "true_damage": true}, a.global_position)
	check(got.size() == 1 and got[0][0] == v and got[0][1] == a, "died signal emitted with killer")
	check(wgot.size() == 1, "World.fighter_died relayed")
	check(dmgs.size() == 1, "damaged signal emitted")
	check(v.state == Fighter.State.DEAD and not v.is_alive() and v.hp == 0.0, "dead state")
	check(a.kills == 1 and v.deaths == 1, "kill/death counters")
	check(not v.is_enemy(a) and not a.is_enemy(v), "dead fighters are not enemies")
	v.receive_hit(a, {"dmg": 1.0}, a.global_position)
	check(got.size() == 1, "no double death")
	v.revive(0.5)
	check(v.is_alive() and approx(v.hp, v.max_hp * 0.5, 1.0), "revive restores hp")


func t_interrupt_and_cancel() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var hits: Array = []
	v.damaged.connect(func(_f: Fighter, amt: float, _s: Fighter) -> void: hits.append(amt))
	a.start_skill(skill("two_hits"))
	await sim(0.3)
	check(hits.size() == 1, "first step of skill executed", str(hits.size()))
	a.receive_hit(v, {"dmg": 0.1, "hitstun": 0.4}, v.global_position)
	check(a.state == Fighter.State.HITSTUN and a.runner == null, "hit interrupts cast")
	await sim(0.6)
	check(hits.size() == 1, "interrupt cancels remaining steps", str(hits.size()))
	# Super armor: not interrupted.
	await sim(0.5)
	hits.clear()
	a.add_status(&"super_armor", 3.0, 1.0, a)
	a.start_skill(skill("two_hits"))
	await sim(0.3)
	a.receive_hit(v, {"dmg": 0.1, "hitstun": 0.4, "launch": 8.0}, v.global_position)
	await sim(0.6)
	check(hits.size() == 2, "super armor cast is not interrupted", str(hits.size()))
	a.remove_status(&"super_armor")
	await sim(0.5)
	# Cancel window combo flow: basic attack (cast 0.3, cancel 0.15) cancelled into launcher.
	a.input.target_uid = v.uid
	a.reset_cooldowns()
	a.input.press(0)
	await sim(0.1)
	a.input.press(1)
	await sim(DT)
	var too_early := a.runner != null and a.runner.slot == 0
	await sim(0.1)
	a.input.press(1)
	await sim(DT * 2)
	check(too_early or a.runner != null, "press outside cancel window is buffered, not cancelled")
	check(a.runner != null and a.runner.slot == 1, "cancel window allows combo into another skill",
		"slot=%d" % (a.runner.slot if a.runner else -9))


func t_requires_and_misc() -> void:
	var p: Array = await _pair()
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	# Statuses.
	var spd := a.get_stat("move_speed")
	a.add_status(&"slow", 2.0, 0.5, v)
	check(approx(a.get_stat("move_speed"), spd * 0.5, 0.01), "slow halves move speed")
	a.add_status(&"haste", 2.0, 0.5, v)
	check(approx(a.get_stat("move_speed"), spd * 0.75, 0.01), "haste stacks multiplicatively with slow")
	a.add_status(&"def_down", 2.0, 0.25, v)
	check(approx(a.get_stat("pdef"), 300.0, 0.01), "def_down reduces defense")
	check(a.status_mask & StatusSet.bit_of(&"slow") != 0, "status_mask bit set")
	await sim(2.2)
	check(not a.has_status(&"slow") and not a.has_status(&"haste"), "statuses expire")
	check(a.status_mask == 0, "status_mask cleared after expiry")
	# Stun blocks casting.
	a.add_status(&"stun", 0.5, 1.0, v)
	check(a.state == Fighter.State.STUNNED and a.cast_block_reason(1) == "busy", "stun -> STUNNED, cannot cast")
	await sim(0.6)
	check(a.state == Fighter.State.IDLE, "stun expires -> IDLE", a.state_name())
	a.add_status(&"silence", 1.0, 1.0, v)
	check(a.cast_block_reason(2) == "silenced" and a.cast_block_reason(0) == "", "silence blocks skills but not basic attack")
	a.remove_status(&"silence")
	# DoT ticks.
	var hp0 := v.hp
	a.input.target_uid = v.uid
	a.start_skill(skill("venom"))
	await sim(1.05)
	var after1 := v.hp
	check(after1 < hp0, "poison ticks damage", "hp0=%.1f hp1=%.1f" % [hp0, after1])
	check(approx(hp0 - after1, 55.0, 1.0), "DoT = power x atk x 0.1 per second", "tick=%.1f" % (hp0 - after1))
	await sim(2.5)
	check(not v.has_status(&"poison"), "poison expires")
	var hp_after := v.hp
	await sim(1.2)
	check(v.hp == hp_after or v.hp > hp_after, "no ticks after expiry")
	# requires
	check(a.find_skill(&"test_dummy.sky_cut") != null, "find_skill by id")
	var r := a.start_skill(skill("hop"))
	check(r != null, "launch_self skill starts")
	await sim(0.15)
	check(not a.is_on_floor(), "launch_self makes caster airborne")
	await sim(1.2)
	check(a.is_on_floor(), "caster lands after launch_self")
