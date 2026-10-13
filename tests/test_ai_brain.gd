extends "res://tests/test_ai_base.gd"
## AI (BotBrain) headless tests: skill analysis, 1v1 duels resolve, 3v3 team fight resolves with focus fire,
## healer heals/revives, pet follows + attacks, mob aggro + leash, raid party (tank holds the boss, no extra
## pulls), telegraph dodging and quick recovery scale with difficulty, difficulty affects duel outcomes.


func run_tests() -> void:
	suite_name = "brain"
	if OS.get_environment("AI_ONLY") != "":
		await call("t_" + OS.get_environment("AI_ONLY"))
		return
	await t_profiles()
	await t_attach()
	await t_duels()
	await t_obstacle()
	await t_team_fight()
	await t_healer()
	await t_pet()
	await t_mob_leash()
	await t_mob_support()
	await t_focus_handover()
	await t_unavoidable_telegraph()
	await t_raid()
	await t_telegraph_dodge()
	await t_quick_recovery()
	await t_difficulty_outcome()
	# wave3 integration behaviours
	await t_hazard()
	await t_zone_avoid()
	await t_raid_goal_idle()
	await t_boss_mechanics()
	await t_parry_timing()
	await t_witch_flight()
	await t_punisher_otg()
	await t_summoner_switch()
	await t_gadget_profile()
	await t_tank_protects_healer()
	await t_revive_when_safe()
	await t_ranged_los()
	await t_lava_map()


# ---------------------------------------------------------------- analysis
func t_profiles() -> void:
	var k: ClassKit = reg.call("get_kit", "test_dummy")
	var p_launch := BotBrain.analyze_skill(k.skill_for_slot(1))
	check(bool(p_launch["launcher"]) and float(p_launch["launch"]) >= 9.0 and bool(p_launch["melee"]), "profile: launcher detected")
	var p_met := BotBrain.analyze_skill(k.skill_for_slot(3))
	check(float(p_met["delay"]) > 0.5 and bool(p_met["aimed"]) and float(p_met["reach"]) >= 8.0, "profile: telegraphed ground AoE")
	var p_grab := BotBrain.analyze_skill(k.skill_for_slot(4))
	check(bool(p_grab["grab"]) and bool(p_grab["armor_break"]), "profile: grab")
	check(bool(BotBrain.analyze_skill(k.skill_for_slot(5))["defensive"]), "profile: defensive self buff")
	check(str(BotBrain.analyze_skill(k.skill_for_slot(6))["summon"]) == "wolf", "profile: summon")
	check(bool(BotBrain.analyze_skill(k.skill_for_slot(7))["ult"]), "profile: ultimate")
	check(str(BotBrain.analyze_skill(k.get_skill_by_id(&"test_dummy.shadow_step"))["move"]) == "toward", "profile: gap closer")
	var heal := BotBrain.analyze_skill(k.get_skill_by_id(&"test_dummy.heal_wave"))
	check(float(heal["heal"]) > 0.15 and str(heal["heal_mode"]) == "ally_lowest", "profile: heal")
	check(bool(BotBrain.analyze_skill(k.get_skill_by_id(&"test_dummy.provoke"))["taunt"]), "profile: taunt")
	var parry_kit: Variant = reg.call("get_kit", "striker")
	if parry_kit is ClassKit:
		var sp := (parry_kit as ClassKit).skill_for_slot(6)
		check(sp != null and bool(BotBrain.analyze_skill(sp)["parry"]) == (sp.tags.has("defensive") and sp.tags.has("interrupt")),
			"profile: parry stance (defensive + interrupt) recognised")
	var real := 0
	for id: String in available_kits():
		var kk: ClassKit = reg.call("get_kit", id)
		for s: SkillDef in kk.skills:
			var _p := BotBrain.analyze_skill(s)
			real += 1
	check(real >= 8, "profile: every available kit skill analysed", "%d skills, kits=%s" % [real, str(available_kits())])


func t_attach() -> void:
	await new_world()
	var f := spawn("test_dummy", 0, Vector3.ZERO)
	var b: Node = world.attach_brain(f, "pvp")
	check(b is BotBrain and f.brain == b and b.get_parent() == f and (b as BotBrain).mode == "pvp", "World.attach_brain creates BotBrain")
	check((b as BotBrain).fighter == f and b.name == "Brain", "brain bound to its fighter")
	var g := root.get_node_or_null("Game")
	if g != null:
		var old: int = int(g.get("settings").get("bot_difficulty", 1))
		g.get("settings")["bot_difficulty"] = 3
		var f2 := spawn("test_dummy", 1, Vector3(0, 0, -5))
		var b2 := world.attach_brain(f2, "pvp") as BotBrain
		check(b2 != null and b2.difficulty == 3 and is_equal_approx(float(b2.cfg["react"]), 0.08), "difficulty read from Game.settings.bot_difficulty")
		g.get("settings")["bot_difficulty"] = old


# ---------------------------------------------------------------- pvp
func t_duels() -> void:
	var kits := available_kits()
	var pairs: Array = []
	var n := kits.size()
	if n <= 5:
		for i in n:
			for j in range(i, n):
				pairs.append([kits[i], kits[j]])
	else:
		for i in n:
			pairs.append([kits[i], kits[(i * 7 + 3) % n]])
			if pairs.size() >= 12:
				break
	var ended := 0
	var total_t := 0.0
	var lines := ""
	for pr: Array in pairs:
		var r: Dictionary = await duel(str(pr[0]), str(pr[1]), 2, 2, 180.0)
		if int(r["winner"]) >= 0:
			ended += 1
			total_t += float(r["time"])
		lines += " %s-vs-%s:%s@%.0fs" % [pr[0], pr[1], str(r["winner"]), float(r["time"])]
	print("  duels:" + lines)
	var frac := float(ended) / maxf(1.0, float(pairs.size()))
	check(frac >= 0.75, "1v1 bot duels end with a death within 180 s", "%d/%d, avg %.1fs" % [ended, pairs.size(), total_t / maxf(1.0, float(ended))])


## A wall square between the bot and its target: raycast steering must walk around it.
func t_obstacle() -> void:
	await new_world()
	var wall := StaticBody3D.new()
	wall.collision_layer = CoreUtil.LAYER_WORLD
	wall.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 3, 1)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 1.5, 0)
	world.add_child(wall)
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 5), 2)
	var target := spawn("test_dummy", 1, Vector3(0, 0, -5), 0.0, "player")
	await physics_frame
	await physics_frame
	var ok := await sim_until(func() -> bool:
		return CoreUtil.flat(bot.global_position - target.global_position).length() < 3.5, 15.0)
	check(ok, "bot steers around a wall to reach its target", "bot at %s" % str(bot.global_position.snapped(Vector3.ONE * 0.1)))


func t_team_fight() -> void:
	var tank := kit_for_roles(["tank"], "ai_test_tank")
	var healer := kit_for_roles(["healer"], "ai_test_healer")
	var dps := kit_for_roles(["melee", "ranged"], "test_dummy", [tank, healer])
	await new_world()
	var team0: Array[Fighter] = [spawn_bot(tank, 0, Vector3(-3, 0, 8), 2), spawn_bot(healer, 0, Vector3(0, 0, 11), 2),
		spawn_bot(dps, 0, Vector3(3, 0, 8), 2)]
	var team1: Array[Fighter] = [spawn_bot(tank, 1, Vector3(3, 0, -8), 2), spawn_bot(healer, 1, Vector3(0, 0, -11), 2),
		spawn_bot(dps, 1, Vector3(-3, 0, -8), 2)]
	var healed := [0.0]
	for f: Fighter in team0 + team1:
		f.healed.connect(func(_f: Fighter, amount: float, src: Fighter) -> void:
			if src != null and src.kit != null and src.kit.role == "healer" and src != _f:
				healed[0] += amount)
	var focus_ok := 0
	var focus_n := 0
	await physics_frame
	var steps := 0
	var done := false
	for i in roundi(240.0 / DT):
		world.step(DT)
		steps += 1
		if i % 30 == 0 and i > 120:
			var rec: Dictionary = world.get_meta("ai_focus_0", {})
			var dps_f := team0[2]
			if dps_f.is_alive() and not rec.is_empty() and world.get_fighter(int(rec["uid"])) != null \
					and not dps_f.status.has(&"taunted"):
				focus_n += 1
				if dps_f.target_uid == int(rec["uid"]):
					focus_ok += 1
				elif OS.get_environment("AI_DEBUG") != "":
					var tt := world.get_fighter(dps_f.target_uid)
					print("  focus miss: focus=%s target=%s state=%s" % [world.get_fighter(int(rec["uid"])).class_id,
						tt.class_id if tt != null else "none", dps_f.state_name()])
		if team_wiped(0) or team_wiped(1):
			done = true
			break
	var winner := 1 if team_wiped(0) else (0 if team_wiped(1) else -1)
	check(done, "3v3 team fight (tank+healer+dps) resolves within 240 s",
		"%s/%s/%s winner=%d t=%.0fs" % [tank, healer, dps, winner, float(steps) * DT])
	check(healed[0] > 0.0, "healers healed allies during the team fight", "%.0f hp" % healed[0])
	check(focus_n > 0 and float(focus_ok) / float(focus_n) >= 0.5, "team focus fire (dps follows the shared focus target)",
		"%d/%d samples" % [focus_ok, focus_n])


func t_healer() -> void:
	var healer := kit_for_roles(["healer"], "ai_test_healer")
	await new_world()
	var h := spawn_bot(healer, 0, Vector3(0, 0, 0), 2)
	var ally := spawn("test_dummy", 0, Vector3(5, 0, 0))
	await sim(0.2)
	ally.hp = ally.max_hp * 0.35
	var ok := await sim_until(func() -> bool: return ally.hp >= ally.max_hp * 0.55, 8.0)
	check(ok, "healer bot heals a damaged ally", "%s ally hp %.0f%%" % [healer, ally.hp / ally.max_hp * 100.0])
	var has_revive := false
	var hb := brain_of(h)
	for s: SkillDef in h.skills:
		if bool(hb.profile(s)["revive"]):
			has_revive = true
	if has_revive:
		ally.kill(null)
		var rev := await sim_until(func() -> bool: return ally.is_alive(), 40.0)
		check(rev, "healer bot revives a dead ally")
	else:
		print("SKIP: healer kit %s has no revive skill" % healer)


# ---------------------------------------------------------------- pet
func t_pet() -> void:
	await new_world()
	var owner_f := spawn("test_dummy", 0, Vector3(-10, 0, 0), 0.0, "player")
	await sim(0.1)
	var pet := world.spawn_summon(owner_f, "wolf", Vector3(-12, 0, 1), 0.0)
	check(pet != null and pet.brain is BotBrain and (pet.brain as BotBrain).mode == "pet", "summons get a BotBrain in pet mode")
	await physics_frame
	var max_d := 0.0
	for i in roundi(3.0 / DT):
		owner_f.input.move = Vector3(1, 0, 0)
		world.step(DT)
		if i > 60:
			max_d = maxf(max_d, pet.global_position.distance_to(owner_f.global_position))
	owner_f.input.move = Vector3.ZERO
	await sim(1.5)
	var d := pet.global_position.distance_to(owner_f.global_position)
	check(d < 4.5 and max_d < 9.0, "pet follows its owner", "final %.1f m, max %.1f m" % [d, max_d])
	var enemy := spawn("test_dummy", 1, owner_f.global_position + Vector3(6, 0, 0), PI, "player")
	await sim(0.1)
	owner_f.input.target_uid = enemy.uid
	var hp0 := enemy.hp
	await sim(5.0)
	check(enemy.hp < hp0, "pet attacks the owner's target", "%.0f -> %.0f" % [hp0, enemy.hp])
	var far := spawn("test_dummy", 1, owner_f.global_position + Vector3(0, 0, -25), 0.0, "player")
	owner_f.input.target_uid = 0
	enemy.kill(null)
	await sim(3.0)
	check(far.hp >= far.max_hp and pet.global_position.distance_to(owner_f.global_position) < 14.0,
		"pet does not chase enemies beyond its 12 m leash")


# ---------------------------------------------------------------- mob
func _register_mobs() -> void:
	reg.call("register_mob_def", "ai_test_grunt", {"name_cn": "测试兵", "name_en": "Test Grunt", "stats": {"hp": 5000.0,
		"patk": 420.0, "pdef": 300.0, "mdef": 300.0, "move_speed": 5.5},
		"skills": [{"id": "ai_test_grunt.bite", "cooldown": 0.0, "cast_time": 0.5, "range": 2.2, "tags": ["melee"],
		"steps": [{"t": 0.2, "type": "melee", "range": 2.2, "hit": {"dmg": 0.6}}]}]})
	reg.call("register_mob_def", "ai_test_boss", {"name_cn": "测试首领", "name_en": "Test Boss", "scale": 1.6,
		"stats": {"hp": 60000.0, "patk": 520.0, "matk": 520.0, "pdef": 450.0, "mdef": 450.0, "move_speed": 5.0},
		"skills": [
			{"id": "ai_test_boss.cleave", "cooldown": 0.0, "cast_time": 0.9, "range": 3.2, "tags": ["melee"],
			"steps": [{"t": 0.5, "type": "melee", "range": 3.2, "arc": 120.0, "hit": {"dmg": 0.9, "knockback": 3.0}}]},
			{"id": "ai_test_boss.slam", "cooldown": 9.0, "cast_time": 1.4, "range": 12.0, "tags": ["aoe"],
			"steps": [{"t": 0.2, "type": "ground", "at": "target", "radius": 3.5, "delay": 1.1, "visual": "earth",
			"hit": {"dmg": 1.8, "knockdown": true}}]}]})


func t_mob_leash() -> void:
	_register_mobs()
	await new_world()
	var mob := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_grunt", "team": 1, "pos": Vector3(0, 0, -5)})
	world.attach_brain(mob, "mob")
	check(mob.brain is BotBrain and (mob.brain as BotBrain).mode == "mob", "mob gets a BotBrain in mob mode")
	var pl := spawn("test_dummy", 0, Vector3(0, 0, 2), PI, "player")
	var hp0 := pl.hp
	await sim(4.0)
	check(pl.hp < hp0 and mob.top_threat() == pl, "mob aggros a nearby player and attacks (threat table)",
		"hp %.0f -> %.0f" % [hp0, pl.hp])
	var far := spawn("test_dummy", 0, Vector3(20, 0, -5), 0.0, "player")
	await sim(2.0)
	check(far.hp >= far.max_hp, "mob does not aggro players outside its aggro radius")
	mob.hp = mob.max_hp * 0.5
	# The player kites away (6 m/s) toward the far side of the arena; the mob gives chase.
	var max_d := 0.0
	await physics_frame
	var returned := false
	for i in roundi(20.0 / DT):
		if pl.global_position.z < 27.0:
			pl.global_position += Vector3(0, 0, 6.0 * DT)
		world.step(DT)
		max_d = maxf(max_d, CoreUtil.flat(mob.global_position - Vector3(0, 0, -5)).length())
		if i > 60 and CoreUtil.flat(mob.global_position - Vector3(0, 0, -5)).length() < 1.5 and mob.hp >= mob.max_hp:
			returned = true
			break
	check(returned and max_d > 15.0 and max_d < 24.0, "mob chases, leashes at 20 m and returns home with full hp",
		"max %.1f m, hp %.0f%%" % [max_d, mob.hp / mob.max_hp * 100.0])
	check(mob.threat.is_empty() or mob.top_threat() == null, "leash resets the threat table")


func _register_support_mobs() -> void:
	reg.call("register_mob_def", "ai_test_necro", {"name_cn": "测试巫师", "name_en": "Test Necromancer", "role": "healer",
		"stats": {"hp": 8000.0, "patk": 300.0, "matk": 520.0, "pdef": 220.0, "mdef": 450.0, "move_speed": 5.0},
		"skills": [
			{"id": "ai_test_necro.bolt", "slot": 0, "cooldown": 2.2, "cast_time": 0.7, "range": 15.0, "tags": ["ranged"],
			"steps": [{"t": 0.4, "type": "projectile", "speed": 18.0, "range": 18.0, "aim": "target", "hit": {"dmg": 0.9, "type": "magic"}}]},
			{"id": "ai_test_necro.mend", "slot": 1, "cooldown": 6.0, "cast_time": 1.0, "range": 16.0, "tags": ["heal"],
			"steps": [{"t": 0.6, "type": "heal", "target": "ally_lowest", "radius": 18.0, "amount": 0.12}]},
			{"id": "ai_test_necro.raise", "slot": 2, "cooldown": 14.0, "cast_time": 1.2, "range": 12.0, "tags": ["summon"],
			"steps": [{"t": 0.8, "type": "summon", "summon_id": "ai_test_grunt", "count": 2, "duration": 30.0, "max_active": 4, "offset": 2.0}]}]})
	reg.call("register_mob_def", "ai_test_guard", {"name_cn": "测试盾卫", "name_en": "Test Shieldbearer", "role": "tank",
		"stats": {"hp": 13000.0, "patk": 420.0, "matk": 300.0, "pdef": 520.0, "mdef": 300.0, "move_speed": 4.6},
		"skills": [
			{"id": "ai_test_guard.bash", "slot": 0, "cooldown": 1.8, "cast_time": 0.6, "range": 2.2, "tags": ["melee", "cc"],
			"steps": [{"t": 0.3, "type": "melee", "range": 2.3, "hit": {"dmg": 0.8, "stun": 0.5}}]},
			{"id": "ai_test_guard.wall", "slot": 1, "cooldown": 9.0, "cast_time": 0.3, "range": 0.0, "tags": ["defensive", "buff_self"],
			"steps": [{"t": 0.0, "type": "buff", "target": "self", "statuses": [{"id": "block", "dur": 4.0, "power": 0.75}]}]}]})


## Mob-mode support kits: healer mobs heal pack mates, summoner mobs raise adds, shield mobs block.
func t_mob_support() -> void:
	_register_mobs()
	_register_support_mobs()
	await new_world()
	var necro := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_necro", "team": 1, "pos": Vector3(0, 0, -6)})
	var guard := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_guard", "team": 1, "pos": Vector3(2, 0, -2)})
	var grunt := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_grunt", "team": 1, "pos": Vector3(-2, 0, -4)})
	for m: Fighter in [necro, guard, grunt]:
		world.attach_brain(m, "mob")
		var b := brain_of(m)
		if b != null:
			b.set_difficulty(2)
	var pl := spawn("test_dummy", 0, Vector3(0, 0, 0), PI, "player")
	pl.max_hp *= 20.0
	pl.hp = pl.max_hp
	await sim(0.2)
	grunt.hp = grunt.max_hp * 0.3
	var hp_low := grunt.hp
	var blocked := false
	var summoned := 0
	await physics_frame
	for i in roundi(20.0 / DT):
		grunt.hp = minf(grunt.hp, grunt.max_hp * 0.95)
		world.step(DT)
		if guard.status.has(&"block"):
			blocked = true
		summoned = maxi(summoned, world.summons_of(necro, "ai_test_grunt").size())
	check(grunt.hp > hp_low + 1.0, "healer mob (mob_def role) heals a damaged pack mate",
		"grunt %.0f%% -> %.0f%%" % [hp_low / grunt.max_hp * 100.0, grunt.hp / grunt.max_hp * 100.0])
	check(summoned > 0, "summoner mob raises its adds", "%d summons" % summoned)
	check(blocked, "shield mob raises its shield when engaged in melee")


## Focus leadership handover: a younger brain taking the lead re-evaluates the shared focus.
func t_focus_handover() -> void:
	await new_world()
	var a := spawn_bot("test_dummy", 0, Vector3(0, 0, 6), 2)
	var b := spawn_bot("test_dummy", 0, Vector3(2, 0, 6), 2)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -6), PI, "player")
	var e2 := spawn("test_dummy", 1, Vector3(3, 0, -6), PI, "player")
	e1.max_hp *= 50.0
	e1.hp = e1.max_hp
	e2.max_hp *= 50.0
	e2.hp = e2.max_hp
	await sim(30.0)
	var key := "ai_focus_0"
	# Old leader (lowest uid) loses its brain; a fresh brain (clock 0) is attached to it, as on a human leaving.
	var old := a.brain
	a.brain = null
	if old != null:
		old.queue_free()
	await physics_frame
	world.attach_brain(a, "pvp")
	await sim(0.5)
	var rec: Dictionary = world.get_meta(key, {})
	check(int(rec.get("by", 0)) == a.brain.get_instance_id() and float(rec.get("next", 99.0)) < 5.0,
		"team focus is re-stamped by a newly attached leader brain", str(rec))
	await sim(3.0)
	var rec2: Dictionary = world.get_meta(key, {})
	check(float(rec2.get("next", 0.0)) > float(rec.get("next", 0.0)), "focus keeps re-evaluating after the handover",
		"%s -> %s" % [rec.get("next"), rec2.get("next")])
	var _u := b


## Raid-wide telegraphs (radius > 15) cannot be outrun: bots keep fighting instead of freezing.
func t_unavoidable_telegraph() -> void:
	await new_world()
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 4), 3)
	var foe := spawn("test_dummy", 1, Vector3(0, 0, -2), PI, "player")
	foe.max_hp *= 50.0
	foe.hp = foe.max_hp
	var caster := spawn("test_dummy", 1, Vector3(0, 0, -20), 0.0, "player")
	var k: ClassKit = reg.call("get_kit", "test_dummy")
	var tide := k.sk(3, "ai_test_tide", "测试死潮", "Test Death Tide", 30.0, 0.0, 0.1, &"cast", 40.0, ["aoe"],
		[{"t": 0.0, "type": "ground", "at": "self", "radius": 40.0, "delay": 2.6, "visual": "dark", "hit": k.hit(0.2)}])
	await sim(2.0)
	caster.add_status(&"stealth", 999.0, 1.0, null)
	await sim(DT)
	var hp0 := foe.hp
	var p0 := bot.global_position
	caster.start_skill(tide, 3)
	await sim(2.4)
	var bb := brain_of(bot)
	check(foe.hp < hp0 and not bb._dodging, "bot keeps fighting through an un-dodgeable raid-wide telegraph",
		"foe dmg %.0f, moved %.1f m" % [hp0 - foe.hp, bot.global_position.distance_to(p0)])


# ---------------------------------------------------------------- raid
func t_raid() -> void:
	_register_mobs()
	var tank := kit_for_roles(["tank"], "ai_test_tank")
	var healer := kit_for_roles(["healer"], "ai_test_healer")
	var ranged := kit_for_roles(["ranged"], "ai_test_ranged", [tank, healer])
	var melee := kit_for_roles(["melee"], "test_dummy", [tank, healer, ranged])
	await new_world()
	var party: Array[Fighter] = [spawn_bot(tank, 0, Vector3(0, 0, 12), 2, "raid"), spawn_bot(healer, 0, Vector3(-2, 0, 15), 2, "raid"),
		spawn_bot(ranged, 0, Vector3(2, 0, 15), 2, "raid"), spawn_bot(melee, 0, Vector3(0, 0, 16), 2, "raid")]
	var boss := world.spawn_fighter({"kind": "boss", "mob_id": "ai_test_boss", "team": 1, "pos": Vector3(0, 0, -6)})
	world.attach_brain(boss, "mob")
	var grunt := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_grunt", "team": 1, "pos": Vector3(20, 0, 24)})
	world.attach_brain(grunt, "mob")
	var tank_aggro := 0
	var samples := 0
	var behind := 0
	var behind_n := 0
	var grunt_untouched := true
	await physics_frame
	for i in roundi(180.0 / DT):
		world.step(DT)
		if boss.is_alive():
			if grunt.hp < grunt.max_hp:
				grunt_untouched = false
			if i % 30 == 0 and i > 600:
				samples += 1
				if boss.target_uid == party[0].uid:
					tank_aggro += 1
				var m := party[3]
				if m.is_alive() and m.global_position.distance_to(boss.global_position) < 5.0:
					behind_n += 1
					var to := CoreUtil.flat_dir(m.global_position - boss.global_position)
					if to.dot(boss.forward()) < 0.2:
						behind += 1
		if not boss.is_alive() and not grunt.is_alive():
			break
		if world.team_alive(0) == 0:
			break
	check(not boss.is_alive(), "raid party (tank/healer/ranged/melee bots) kills the boss", "party alive %d" % world.team_alive(0))
	check(samples > 0 and float(tank_aggro) / float(samples) >= 0.6, "tank holds boss aggro", "%d/%d" % [tank_aggro, samples])
	check(behind_n == 0 or float(behind) / float(behind_n) >= 0.5, "melee dps fights from behind the boss", "%d/%d" % [behind, behind_n])
	check(grunt_untouched, "party does not pull an extra pack during the boss fight")
	check(not grunt.is_alive(), "bot-only party pulls the next pack after the boss",
		"grunt hp %.0f%%, kits %s/%s/%s/%s" % [grunt.hp / grunt.max_hp * 100.0, tank, healer, ranged, melee])


# ---------------------------------------------------------------- difficulty-scaled reflexes
func _dodge_trials(diff: int, trials: int) -> int:
	await new_world()
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 0), diff)
	var caster := spawn("test_dummy", 1, Vector3(0, 0, -12), 0.0, "player")
	var meteor: SkillDef = (reg.call("get_kit", "test_dummy") as ClassKit).skill_for_slot(3)
	var hits := 0
	for i in trials:
		caster.add_status(&"stealth", 999.0, 1.0, null)
		bot.reset_for_round(Vector3(float(i % 5) * 2.0 - 4.0, 0, float(i % 3) * 2.0 - 2.0))
		await sim(0.6)
		caster.input.target_uid = bot.uid
		await sim(DT)
		var hp0 := bot.hp
		caster.start_skill(meteor, 3)
		await sim(1.6)
		if bot.hp < hp0:
			hits += 1
		await sim(1.6)
	return hits


func t_telegraph_dodge() -> void:
	var n := 16
	var hits0: int = await _dodge_trials(0, n)
	var hits3: int = await _dodge_trials(3, n)
	check(hits3 < hits0, "telegraph dodge succeeds more often at difficulty 3 than at 0",
		"hit %d/%d at diff 0, %d/%d at diff 3" % [hits0, n, hits3, n])
	check(n - hits3 >= roundi(n * 0.6), "difficulty 3 dodges most telegraphed AoEs", "%d/%d dodged" % [n - hits3, n])


func _recovery_trials(diff: int, trials: int) -> int:
	await new_world()
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 0), diff)
	var src := spawn("test_dummy", 1, Vector3(0, 0, -20), 0.0, "player")
	var quick := 0
	for i in trials:
		bot.reset_for_round(Vector3(0, 0, 0))
		await sim(0.3)
		bot.receive_hit(src, {"dmg": 0.05, "knockdown": true, "hitstun": 0.0, "knockback": 0.0}, Vector3(0, 0, -1))
		var kd := bot.state == Fighter.State.KNOCKDOWN
		var t := 0.0
		await physics_frame
		while t < 1.5 and bot.state == Fighter.State.KNOCKDOWN:
			world.step(DT)
			t += DT
		if kd and t < 0.5:
			quick += 1
		await sim(1.0)
	return quick


func t_quick_recovery() -> void:
	var n := 16
	var q0: int = await _recovery_trials(0, n)
	var q3: int = await _recovery_trials(3, n)
	check(q3 > q0 and q3 >= roundi(n * 0.6), "quick recovery (受身) rate scales with difficulty", "%d/%d at diff 0, %d/%d at diff 3" % [q0, n, q3, n])


func t_difficulty_outcome() -> void:
	var wins3 := 0
	var wins0 := 0
	var runs := 6
	var kits := ["test_dummy", "ai_test_ranged", "ai_test_tank"]
	for i in runs:
		BotBrain.rng_seed = 1000 + i
		var k: String = kits[i % kits.size()]
		var swap := i % 2 == 1
		var r: Dictionary
		if swap:
			r = await duel(k, k, 0, 3, 180.0)
			if int(r["winner"]) == 1:
				wins3 += 1
			elif int(r["winner"]) == 0:
				wins0 += 1
		else:
			r = await duel(k, k, 3, 0, 180.0)
			if int(r["winner"]) == 0:
				wins3 += 1
			elif int(r["winner"]) == 1:
				wins0 += 1
	BotBrain.rng_seed = 4242
	check(wins3 >= runs - 1, "difficulty 3 beats difficulty 0 in mirror duels", "%d-%d of %d" % [wins3, wins0, runs])


# ================================================================== wave3 integration behaviours
func _script_node(src: String) -> Node:
	var scr := GDScript.new()
	scr.source_code = src
	scr.reload()
	return scr.new() as Node


## Map hazards (ArenaMap.is_hazard): a bot standing in the hazard walks out, and a bot chasing a target
## across a hazard strip walks around it instead of through it.
func t_hazard() -> void:
	await new_world()
	var hz := _script_node("extends Node\nfunc is_hazard(p: Vector3) -> bool:\n\treturn p.y < 0.4 and absf(p.x) < 4.0 and absf(p.z) < 1.5\n")
	hz.name = "HazardMap"
	world.add_child(hz)
	check(BotBrain.find_hazard_map(world) == hz, "hazard map found next to / under the World")
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 0), 2)
	var out := await sim_until(func() -> bool: return not bool(hz.call("is_hazard", bot.global_position)), 3.0)
	check(out, "bot standing in a hazard walks out of it", str(bot.global_position.snapped(Vector3.ONE * 0.1)))
	bot.reset_for_round(Vector3(0.5, 0, 6))
	var target := spawn("test_dummy", 1, Vector3(0, 0, -6), 0.0, "player")
	target.max_hp *= 50.0
	target.hp = target.max_hp
	var inside := 0
	await physics_frame
	var reached := false
	for i in roundi(15.0 / DT):
		world.step(DT)
		if bool(hz.call("is_hazard", bot.global_position)):
			inside += 1
		if CoreUtil.flat(bot.global_position - target.global_position).length() < 3.5:
			reached = true
			break
	check(reached and inside <= 6, "bot walks around a hazard strip to reach its target",
		"reached=%s, %d steps in hazard" % [str(reached), inside])


func _make_zone(caster: Fighter, pos: Vector3, radius: float, dur: float) -> AreaEffect:
	var a := AreaEffect.new()
	a.caster = caster
	a.team = caster.team
	a.radius = radius
	a.duration = dur
	a.tick_interval = 0.5
	a.hit = Hit.normalize({"dmg": 0.1, "hitstun": 0.0, "knockback": 0.0})
	a.mode = "zone"
	a.position = pos
	world.add_effect(a)
	return a


## Enemy persistent damaging zones: bots leave them and keep out.
func t_zone_avoid() -> void:
	await new_world()
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 0), 2)
	var foe := spawn("test_dummy", 1, Vector3(0, 0, -8), 0.0, "player")
	foe.max_hp *= 50.0
	foe.hp = foe.max_hp
	foe.add_status(&"stealth", 999.0, 1.0, null)
	await sim(0.2)
	var _z := _make_zone(foe, Vector3(0, 0, 0), 3.0, 12.0)
	var left := await sim_until(func() -> bool: return CoreUtil.flat(bot.global_position).length() > 3.0 + bot.radius(), 3.0)
	await sim(3.0)
	check(left and CoreUtil.flat(bot.global_position).length() > 3.0, "bot leaves and stays out of an enemy persistent zone",
		"%.1f m from the centre" % CoreUtil.flat(bot.global_position).length())


## Raid mode: walk to MatchRaid's raid_goal when idle; never hit an idle (unpulled) mob; fight it once pulled.
func t_raid_goal_idle() -> void:
	_register_mobs()
	await new_world()
	var bot := spawn_bot("test_dummy", 0, Vector3(0, 0, 14), 2, "raid")
	bot.set_meta("raid_goal", Vector3(0, 0, -6))
	var mob := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_grunt", "team": 1, "pos": Vector3(1.5, 0, -8)})
	var ok := await sim_until(func() -> bool: return CoreUtil.flat(bot.global_position - Vector3(0, 0, -6)).length() < 2.0, 8.0)
	await sim(2.0)
	check(ok, "raid bot walks to fighter meta raid_goal", str(bot.global_position.snapped(Vector3.ONE * 0.1)))
	check(mob.hp >= mob.max_hp, "raid bot does not attack an idle mob (no brain, empty threat table)")
	world.attach_brain(mob, "mob")
	mob.add_threat(bot, 1.0)
	var hp0 := mob.hp
	await sim(6.0)
	check(mob.hp < hp0, "raid bot attacks the mob once it is pulled", "%.0f -> %.0f" % [hp0, mob.hp])


## Raid boss mechanics read from the boss brain: soak circles (`shares`) are stacked, channels interrupted.
func t_boss_mechanics() -> void:
	_register_mobs()
	await new_world()
	var party: Array[Fighter] = []
	for i in 4:
		party.append(spawn_bot("test_dummy", 0, Vector3(float(i) * 3.0 - 4.5, 0, 6), 2, "raid"))
	var boss := world.spawn_fighter({"kind": "boss", "mob_id": "ai_test_boss", "team": 1, "pos": Vector3(0, 0, -4)})
	boss.max_hp *= 20.0
	boss.hp = boss.max_hp
	var fake := _script_node("extends Node\nvar shares: Array = []\nvar channel: Dictionary = {}\n")
	fake.name = "Brain"
	boss.brain = fake
	boss.add_child(fake)
	for f: Fighter in party:
		boss.add_threat(f, 1.0)
	await sim(3.0)
	var pos := Vector3(6, 0, 4)
	fake.set("shares", [{"id": "test", "pos": pos, "left": 3.2, "ab": {"radius": 3.5, "min": 2}}])
	await sim(3.0)
	var inside := 0
	for f: Fighter in party:
		if CoreUtil.flat(f.global_position - pos).length() - f.radius() <= 3.5:
			inside += 1
	check(inside >= 2, "raid bots stack in a boss soak circle (BossBrain.shares)", "%d/4 inside" % inside)
	fake.set("shares", [])
	await sim(1.0)
	var n0 := 0
	for f: Fighter in party:
		n0 += brain_of(f).interrupts_attempted
	fake.set("channel", {"id": "test_channel", "left": 4.0})
	await sim(3.0)
	var n1 := 0
	for f: Fighter in party:
		n1 += brain_of(f).interrupts_attempted
	check(n1 > n0, "raid bots fire crowd control into a channelling boss (BossBrain.channel)", "%d interrupts" % (n1 - n0))


func _register_slow_brute() -> void:
	reg.call("register_mob_def", "ai_test_brute", {"name_cn": "测试蛮兵", "name_en": "Test Brute", "stats": {"hp": 90000.0,
		"patk": 420.0, "pdef": 300.0, "mdef": 300.0, "move_speed": 0.0},
		"skills": [{"id": "ai_test_brute.haymaker", "cooldown": 0.0, "cast_time": 1.1, "range": 2.6, "tags": ["melee"],
		"steps": [{"t": 0.75, "type": "melee", "range": 2.8, "arc": 140.0, "hit": {"dmg": 0.8}}]}]})


## Parry stances (defensive + interrupt) are timed against enemy melee wind-ups. The brain's reactive parry is
## driven directly (no other plans), so the timing of the press and the parry outcome are measured exactly.
func t_parry_timing() -> void:
	if not bool(reg.call("has_kit", "striker")):
		print("SKIP: striker kit missing")
		return
	_register_slow_brute()
	await new_world()
	var bot := spawn("striker", 0, Vector3(0, 0, 1.6), PI, "player")
	bot.max_hp *= 20.0
	bot.hp = bot.max_hp
	var b := BotBrain.new()
	b.setup(bot, "pvp")
	b._init_brain()
	b.set_difficulty(3)
	var brute := world.spawn_fighter({"kind": "mob", "mob_id": "ai_test_brute", "team": 1, "pos": Vector3(0, 0, -0.2), "yaw": 0.0})
	var swing: SkillDef = brute.get_skill(0)
	await sim(0.3)
	var pressed_at: Array[float] = []
	var countered := 0
	for i in 8:
		bot.reset_for_round(Vector3(0, 0, 1.6))
		bot.reset_cooldowns()
		bot.face_towards(brute.global_position)
		brute.reset_for_round(Vector3(0, 0, -0.2))
		brute.add_status(&"super_armor", 999.0, 1.0, null)
		brute.input.target_uid = bot.uid
		brute.face_towards(bot.global_position)
		brute.start_skill(swing, 0)
		var p0 := b.parries_attempted
		var hp0 := bot.hp
		var t := 0.0
		await physics_frame
		while t < 1.3:
			b._clock += DT
			bot.input.target_uid = brute.uid
			b._try_parry(world)
			if b.parries_attempted > p0 and pressed_at.size() < i + 1:
				pressed_at.append(t)
			world.step(DT)
			t += DT
		if bot.hp >= hp0 and brute.state != Fighter.State.CAST:
			countered += 1
	var early := 0
	for pt: float in pressed_at:
		if pt < 0.75 - 0.6 or pt > 0.75:
			early += 1
	check(pressed_at.size() >= 6 and early == 0 and countered >= 5, "parry stance timed against enemy melee wind-ups",
		"%d parries in 8 swings, presses at %s, %d mistimed, %d countered" % [pressed_at.size(), str(pressed_at), early, countered])
	b.free()


## Witch broom flight: a pressured, low Witch double-jumps into broom flight to escape.
func t_witch_flight() -> void:
	if not bool(reg.call("has_kit", "witch")):
		print("SKIP: witch kit missing")
		return
	await new_world()
	var bot := spawn_bot("witch", 0, Vector3(0, 0, 0), 3)
	var a := spawn("test_dummy", 1, Vector3(0, 0, -1.6), 0.0, "player")
	var c := spawn("test_dummy", 1, Vector3(1.6, 0, 0), 0.0, "player")
	await sim(0.2)
	bot.hp = bot.max_hp * 0.3
	var b := brain_of(bot)
	var ok := await sim_until(func() -> bool: return b.flights_started > 0, 8.0)
	check(ok, "witch bot mounts the broom (double jump) to escape melee pressure", "%d flights" % b.flights_started)
	var _u := [a, c]


## Sharpshooter Punisher (finisher, OTG) is used on downed targets.
func t_punisher_otg() -> void:
	if not bool(reg.call("has_kit", "sharpshooter")):
		print("SKIP: sharpshooter kit missing")
		return
	await new_world()
	var bot := spawn_bot("sharpshooter", 0, Vector3(0, 0, 2.0), 3)
	var dummy := spawn("test_dummy", 1, Vector3(0, 0, 0), 0.0, "player")
	dummy.max_hp *= 50.0
	dummy.hp = dummy.max_hp
	var used := [0]
	bot.skill_cast.connect(func(_f: Fighter, slot: int) -> void:
		if slot == 3 and dummy.state == Fighter.State.KNOCKDOWN:
			used[0] += 1)
	await sim(0.3)
	for i in 6:
		dummy.reset_for_round(Vector3(0, 0, 0))
		await sim(0.6)
		dummy.receive_hit(bot, {"dmg": 0.01, "knockdown": true, "hitstun": 0.0, "knockback": 0.0}, bot.global_position)
		await sim(1.6)
		bot.reset_cooldowns()
	check(used[0] >= 2, "sharpshooter uses Punisher (OTG) on downed targets", "%d/6 knockdowns punished" % used[0])


## Summoner Switch (escape) only with a living summon far from us.
func t_summoner_switch() -> void:
	if not bool(reg.call("has_kit", "summoner")):
		print("SKIP: summoner kit missing")
		return
	await new_world()
	var bot := spawn_bot("summoner", 0, Vector3(0, 0, 0), 2)
	var b := brain_of(bot)
	var sw := -1
	for s: SkillDef in bot.skills:
		if str(s.id).ends_with("switch"):
			sw = s.slot
	await sim(0.1)
	check(sw >= 0 and not b._escape_ok(world, sw), "summoner Switch is not an option without a summon")
	var su := world.spawn_summon(bot, "goblin", Vector3(9, 0, 0), 20.0)
	await sim(0.1)
	check(su != null and b._escape_ok(world, sw), "summoner Switch becomes an escape with a distant living summon")


## Mechanic gadgets (traps thrown at the target) are ranged placements.
func t_gadget_profile() -> void:
	if not bool(reg.call("has_kit", "mechanic")):
		print("SKIP: mechanic kit missing")
		return
	var k: ClassKit = reg.call("get_kit", "mechanic")
	var p := BotBrain.analyze_skill(k.skill_for_slot(1))
	check(bool(p["trap_target"]) and bool(p["ranged"]) and float(p["reach"]) >= 8.0 and bool(p["launcher"]),
		"mechanic gadget (trap at target) analysed as a ranged launcher placement", "reach %.1f" % float(p["reach"]))
	await new_world()
	var bot := spawn_bot("mechanic", 0, Vector3(0, 0, 8), 3)
	var dummy := spawn("test_dummy", 1, Vector3(0, 0, 0), 0.0, "player")
	dummy.max_hp *= 50.0
	dummy.hp = dummy.max_hp
	var mines := [0]
	bot.skill_cast.connect(func(_f: Fighter, slot: int) -> void:
		if slot == 1 or slot == 4:
			mines[0] += 1)
	var traps_near := [0]
	await physics_frame
	for i in roundi(12.0 / DT):
		world.step(DT)
		if i % 6 == 0:
			for e: Variant in world.effects:
				if is_instance_valid(e) and e is AreaEffect and (e as AreaEffect).mode == "trap" and (e as AreaEffect).caster == bot \
						and CoreUtil.flat((e as AreaEffect).global_position - dummy.global_position).length() < 3.0:
					traps_near[0] += 1
					break
	check(mines[0] >= 1 and traps_near[0] >= 1, "mechanic places gadgets at its target",
		"%d casts, %d samples with a trap at the target" % [mines[0], traps_near[0]])


## Tank taunts an enemy that is hitting the healer.
func t_tank_protects_healer() -> void:
	var tank := kit_for_roles(["tank"], "ai_test_tank")
	var healer := kit_for_roles(["healer"], "ai_test_healer")
	await new_world()
	var tb := spawn_bot(tank, 0, Vector3(0, 0, 7), 2)
	var h := spawn(healer, 0, Vector3(0, 0, 0), 0.0, "player")
	h.max_hp *= 20.0
	h.hp = h.max_hp
	var e := spawn("test_dummy", 1, Vector3(0, 0, -1.8), 0.0, "player")
	e.max_hp *= 20.0
	e.hp = e.max_hp
	await physics_frame
	var ok := false
	for i in roundi(10.0 / DT):
		e.input.target_uid = h.uid
		if i % 20 == 0:
			e.input.press(0)
		world.step(DT)
		if e.status.has(&"taunted") and e.status.source(&"taunted") == tb:
			ok = true
			break
	check(ok, "tank taunts the enemy hitting its healer", "%s taunts=%d" % [tank, brain_of(tb).healer_taunts])


## Healers revive only when out of danger.
func t_revive_when_safe() -> void:
	var healer := kit_for_roles(["healer"], "ai_test_healer")
	await new_world()
	var hb := spawn_bot(healer, 0, Vector3(0, 0, 0), 2)
	var has_revive := false
	for s: SkillDef in hb.skills:
		if bool(brain_of(hb).profile(s)["revive"]):
			has_revive = true
	if not has_revive:
		print("SKIP: healer kit %s has no revive skill" % healer)
		return
	var ally := spawn("test_dummy", 0, Vector3(4, 0, 0))
	var foe := spawn("test_dummy", 1, Vector3(0, 0, -1.5), 0.0, "player")
	foe.max_hp *= 50.0
	foe.hp = foe.max_hp
	await sim(0.3)
	ally.kill(null)
	var early := await sim_until(func() -> bool:
		foe.global_position = hb.global_position + Vector3(0, 0, -1.5)
		return ally.is_alive(), 3.0)
	check(not early, "healer does not revive while an enemy is on it")
	foe.reset_for_round(Vector3(0, 0, -30))
	foe.add_status(&"stealth", 999.0, 1.0, null)
	var rev := await sim_until(func() -> bool: return ally.is_alive(), 20.0)
	check(rev, "healer revives once out of danger")


## Ranged bots move to keep line of sight (World.raycast) instead of shooting into walls.
func t_ranged_los() -> void:
	await new_world()
	var wall := StaticBody3D.new()
	wall.collision_layer = CoreUtil.LAYER_WORLD
	wall.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 1)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(0, 2.0, 1.5)
	world.add_child(wall)
	var bot := spawn_bot("ai_test_ranged", 0, Vector3(0, 0, 9), 2)
	var target := spawn("test_dummy", 1, Vector3(0, 0, -1.5), 0.0, "player")
	target.max_hp *= 50.0
	target.hp = target.max_hp
	var shots_blind := [0]
	bot.skill_cast.connect(func(_f: Fighter, _slot: int) -> void:
		if not world.raycast(bot.center(), target.center(), CoreUtil.LAYER_WORLD).is_empty():
			shots_blind[0] += 1)
	var hp0 := target.hp
	await sim(10.0)
	check(target.hp < hp0 and shots_blind[0] <= 1, "ranged bot finds line of sight around a wall before shooting",
		"dmg %.0f, %d casts without LOS" % [hp0 - target.hp, shots_blind[0]])


## Lava Cave (real map, ArenaMap.is_hazard): a 2v2 bot fight spends almost no time standing in lava.
func t_lava_map() -> void:
	var map: MapBase = MapRegistry.create("lava_cave")
	if map == null or not map.has_method("is_hazard"):
		print("SKIP: lava_cave map missing")
		return
	if world != null and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	root.add_child(map)
	map.build()
	map.apply_to_world(world)
	await physics_frame
	await physics_frame
	var kits := ["test_dummy", "ai_test_ranged"]
	var bots: Array[Fighter] = []
	for team in 2:
		var pts: Array[Vector3] = map.get_spawn_points(team)
		for i in 2:
			var f := spawn_bot(kits[i], team, pts[i % pts.size()], 2)
			f.max_hp *= 6.0
			f.hp = f.max_hp
			bots.append(f)
	var in_lava := 0
	var samples := 0
	await physics_frame
	for i in roundi(40.0 / DT):
		world.step(DT)
		if i % 10 == 0:
			for f: Fighter in bots:
				if f.is_alive():
					samples += 1
					if bool(map.call("is_hazard", f.global_position)):
						in_lava += 1
	var frac := float(in_lava) / maxf(1.0, float(samples))
	check(frac < 0.05, "bots avoid standing in Lava Cave lava (map is_hazard)", "%.1f%% of samples in lava" % (frac * 100.0))
	world.get_parent().remove_child(world)
	world.free()
	world = null
	map.get_parent().remove_child(map)
	map.free()
