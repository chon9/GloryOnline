extends SceneTree
## RAID module headless tests: mob defs, dungeon builds + collision, deterministic raid run (5 bots clear
## trash encounter 1), boss phases / enrage / interrupt, wipe + respawn, victory + records file.
##   godot --headless --path . -s res://tests/test_raid_core.gd

const DT: float = 1.0 / 60.0
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"
const RECORDS: String = "user://test_raid_records.json"

var passed: int = 0
var failed: int = 0
var world: World = null
var map: MapBase = null
var match_node: MatchRaid = null


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	Combat.seed_rng(777)
	var reg := root.get_node_or_null("Registry")
	if reg == null:
		check(false, "Registry autoload present")
	else:
		reg.call("register_kit", (load(KIT_PATH) as Script).new())
	await test_mob_defs()
	await test_dungeons()
	await test_raid_run()
	await test_boneyard_boss()
	_teardown()
	DungeonBase.clear_cache()
	await process_frame
	print("RAID TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


func sim(seconds: float) -> void:
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)
		if match_node != null:
			match_node.host_tick(DT)


func sim_until(cond: Callable, timeout: float) -> bool:
	await physics_frame
	for i in roundi(timeout / DT):
		world.step(DT)
		if match_node != null:
			match_node.host_tick(DT)
		if cond.call():
			return true
	return false


# ---------------------------------------------------------------- mob defs
func test_mob_defs() -> void:
	var reg := root.get_node_or_null("Registry")
	var defs: Dictionary = reg.get("mob_defs") if reg != null else {}
	var needed := ["skeleton_grunt", "skeleton_guard", "skeleton_crossbow", "skeleton_mage", "skeleton_rogue", "necromancer",
		"bone_minion", "bone_champion", "frost_wolf", "orc_raider", "orc_guard", "ice_archer", "frost_shaman",
		"werewolf_elite", "orc_warlord", "frost_golem", "black_knight"]
	var missing: Array = []
	var bad_skills: Array = []
	var bad_models: Array = []
	for id: String in needed:
		if not defs.has(id):
			missing.append(id)
			continue
		var d: Dictionary = defs[id]
		var sk: Variant = d.get("skills")
		if not (sk is Array) or (sk as Array).is_empty() or not ((sk as Array)[0] is SkillDef):
			bad_skills.append(id)
		if not CharacterVisual.MODELS.has(str(d.get("model", ""))):
			bad_models.append(id)
	check(missing.is_empty(), "all raid mob defs registered", str(missing))
	check(bad_skills.is_empty(), "mob skills normalised to SkillDef", str(bad_skills))
	check(bad_models.is_empty(), "mob models exist in CharacterVisual.MODELS", str(bad_models))
	for b: String in ["frost_golem", "black_knight"]:
		var bd: Dictionary = defs.get(b, {}).get("boss", {})
		var phases: Array = bd.get("phases", [])
		check(phases.size() == 3, "%s has 3 phases" % b)
		check(is_equal_approx(float(bd.get("enrage", {}).get("hp", 0.0)), 0.1), "%s enrages at 10%% (red blood)" % b)
		var kinds: Dictionary = {}
		for k: Variant in bd.get("abilities", {}):
			kinds[str(bd["abilities"][k]["kind"])] = true
		check(kinds.has("raid_aoe") and kinds.has("share") and kinds.has("channel"), "%s has raid aoe, soak/stack, interrupt" % b, str(kinds.keys()))
		var hp := float(defs.get(b, {}).get("stats", {}).get("hp", 0.0))
		# wave3 RAID-TUNE: tuned for ~4-5 min bot-party boss fights (see tests/test_raid_clear.gd).
		check(hp >= 500000.0 and hp <= 800000.0, "%s hp in 500k-800k for 5 players" % b, str(hp))
		check(float(defs.get(b, {}).get("body_radius", 0.0)) >= 1.0, "%s has a boss-sized capsule (body_radius)" % b)
	var gs: SkillDef = (defs.get("skeleton_guard", {}).get("skills", []) as Array)[1]
	check(RaidUtil.skill_is_cc((defs.get("skeleton_guard", {}).get("skills", []) as Array)[0]), "shield bash counts as cc")
	check(not RaidUtil.skill_is_cc(gs), "raise shield is not cc")


# ---------------------------------------------------------------- dungeons
func _ray_down(p: Vector3) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 5, 0), p + Vector3(0, -5, 0), CoreUtil.LAYER_WORLD)
	return space.intersect_ray(q)


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, CoreUtil.LAYER_WORLD)
	return space.intersect_ray(q)


func test_dungeons() -> void:
	var list := RaidRegistry.list()
	check(list.size() >= 2, "raid registry lists 2 dungeons")
	for info: Dictionary in list:
		var id := str(info["id"])
		var m := RaidRegistry.create(id)
		check(m != null and m is DungeonBase, "%s created" % id)
		if m == null:
			continue
		root.add_child(m)
		var t0 := Time.get_ticks_msec()
		m.build()
		print("  %s built in %d ms" % [id, Time.get_ticks_msec() - t0])
		check(m.map_kind == "raid", "%s map_kind raid" % id)
		await physics_frame
		await physics_frame
		var pts: Array[Vector3] = []
		pts.append_array(m.get_spawn_points(0))
		var encs := m.get_encounters()
		check(encs.size() >= 3 and bool(encs[encs.size() - 1].get("boss", false)), "%s: trash encounters then a boss" % id)
		for i in encs.size():
			pts.append(encs[i]["pos"])
			pts.append(m.get_checkpoint(i))
		pts.append(m.get_checkpoint(-1))
		var bad: Array = []
		for p: Vector3 in pts:
			var r := _ray_down(Vector3(p.x, 0, p.z))
			if r.is_empty() or absf((r["position"] as Vector3).y) > 0.3:
				bad.append(p)
		check(bad.is_empty(), "%s: floor under spawn / encounter / checkpoints" % id, str(bad))
		# Walls: from every encounter centre a horizontal ray sideways must hit the boundary.
		var open: Array = []
		for e: Dictionary in encs:
			var c: Vector3 = (e["pos"] as Vector3) + Vector3(0, 1.0, 0)
			for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
				if _ray(c, c + dir * 40.0).is_empty():
					open.append([e["id"], dir])
		check(open.is_empty(), "%s: rooms enclosed by collision" % id, str(open))
		# Whole route walkable: rays along the centreline from start to boss all hit floor.
		var holes: Array = []
		var z := m.get_checkpoint(-1).z
		var zb: float = (encs[encs.size() - 1]["pos"] as Vector3).z
		while z > zb:
			var r := _ray_down(Vector3(0, 0, z))
			if r.is_empty() or absf((r["position"] as Vector3).y) > 0.3:
				holes.append(z)
			z -= 1.0
		check(holes.is_empty(), "%s: centreline floor continuous" % id, str(holes))
		var dm := m as DungeonBase
		check(dm.light_count <= dm.max_lights, "%s: sparse lights (%d)" % [id, dm.light_count])
		check(m.find_child("WorldEnvironment", false, false) != null, "%s: has WorldEnvironment" % id)
		m.queue_free()
		await process_frame


# ---------------------------------------------------------------- raid run
func _new_raid(raid_id: String) -> void:
	_teardown()
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	map = RaidRegistry.create(raid_id)
	root.add_child(map)
	map.build()
	match_node = MatchRaid.new()
	match_node.name = "MatchRaid"
	match_node.brain_policy = "internal"
	match_node.auto_tick = false
	match_node.records_path = RECORDS
	root.add_child(match_node)
	var roster: Array = []
	for i in 5:
		roster.append({"slot": i, "team": 0, "peer": 0, "name": "Bot%d" % i, "class_id": "test_dummy", "ready": true})
	match_node.setup(world, map, {"mode": "raid", "raid_id": raid_id}, roster)
	await physics_frame
	await physics_frame
	match_node.begin()


func _teardown() -> void:
	for n: Node in [match_node, map, world]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	match_node = null
	map = null
	world = null


func test_raid_run() -> void:
	if FileAccess.file_exists(RECORDS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	await _new_raid("frost_forest")
	var started: Array = []
	var cleared: Array = []
	match_node.encounter_started.connect(func(i: int) -> void: started.append(i))
	match_node.encounter_cleared.connect(func(i: int) -> void: cleared.append(i))
	check(match_node.party().size() == 5, "5 party members spawned")
	var mobs0: Array = match_node.enc_mobs.get(0, [])
	check(mobs0.size() == 5 and match_node.enc_state[0] == "idle", "encounter 1 spawned idle")
	var all_idle := true
	for f: Fighter in mobs0:
		if f.brain != null:
			all_idle = false
	check(all_idle, "idle mobs have no brain before the pull")
	await sim(1.0)
	check(match_node.enc_state[0] == "idle", "encounter not triggered from the start camp")
	var t_start := match_node.clear_time
	var ok := await sim_until(func() -> bool: return match_node.enc_state[0] == "cleared", 150.0)
	check(started.has(0), "encounter 1 triggered by the party walking in")
	check(ok and cleared.has(0), "5 bots clear trash encounter 1 within 150 s", "state=%s t=%.1f" % [match_node.enc_state[0], match_node.clear_time])
	print("  trash 1 cleared at %.1f s sim (from %.1f)" % [match_node.clear_time, t_start])
	check(match_node.current == 1 and match_node.enc_state[1] == "idle", "encounter 2 spawned after the clear")
	check(match_node.party_alive() == 5, "fallen party members revived out of combat")
	# ---- boss: phases, enrage, interrupt
	match_node.debug_skip_to(2)
	await sim(0.2)
	var boss := match_node.boss
	check(boss != null and boss.kind == "boss" and boss.mob_id == "frost_golem", "frost golem spawned")
	if boss == null:
		return
	var def_hp := float((boss.mob_def.get("stats", {}) as Dictionary).get("hp", 0.0))
	check(is_equal_approx(boss.max_hp, def_hp), "boss hp scaled for a party of 5", "%.0f vs %.0f" % [boss.max_hp, def_hp])
	check(boss.radius() >= 1.0 and boss.height() >= 3.5, "boss capsule matches the big model", "r %.2f h %.2f" % [boss.radius(), boss.height()])
	match_node._activate(2, match_node.party()[0])
	var bb := match_node.boss_brain
	check(bb != null, "BossBrain attached on pull")
	await sim(0.5)
	check(boss.has_status(&"super_armor"), "boss has permanent super armor")
	await sim(18.0)
	var abil := bb.log_events.filter(func(s: String) -> bool: return s.begins_with("ability:"))
	check(abil.size() >= 3, "boss uses its rotation", str(bb.log_events))
	boss.hp = boss.max_hp * 0.75
	await sim(0.3)
	check(bb.phase == 0, "no phase change above 70%")
	boss.hp = boss.max_hp * 0.69
	await sim(0.3)
	check(bb.phase == 1, "phase 2 at 70%", "phase=%d" % bb.phase)
	check(bb.adds.size() >= 2, "phase 2 adds spawned", str(bb.adds.size()))
	check(bb.last_announce.contains("第二阶段"), "phase announcement sent", bb.last_announce)
	boss.hp = boss.max_hp * 0.39
	await sim(0.3)
	check(bb.phase == 2, "phase 3 at 40%", "phase=%d" % bb.phase)
	check(not bb.enraged, "not enraged above 10%")
	# Interrupt: a cc skill landing during the channel breaks the boss.
	var ab: Dictionary = bb.data["abilities"]["frozen_heart"]
	bb._start_channel("frozen_heart", ab)
	var member: Fighter = match_node.party()[0]
	if not member.is_alive():
		member.revive(1.0)
	await sim(0.1)
	member.start_skill(member.get_skill(1), 1)   # test kit slot 1 = launcher (cc) -> skill_cast hook
	boss.receive_hit(member, {"dmg": 0.05}, member.global_position)
	check(bb.channel.is_empty() and bb.log_events.has("channel_interrupted:frozen_heart"), "cc interrupts the channel")
	check(bb.break_left > 0.0 and not boss.has_status(&"super_armor"), "interrupted boss is broken (no super armor)")
	await sim(4.5)
	check(boss.has_status(&"super_armor"), "super armor returns after the break")
	boss.hp = boss.max_hp * 0.09
	await sim(0.3)
	check(bb.enraged and boss.has_status(&"atk_up"), "red blood enrage at 10%")
	# ---- wipe -> respawn at checkpoint with encounter reset
	for f: Fighter in match_node.party():
		f.kill(null)
	await sim(0.1)
	check(match_node.wipe_timer > 0.0 and match_node.wipes == 1, "wipe detected")
	await sim(5.2)
	var alive := match_node.party_alive()
	check(alive == 5, "everyone respawned after the wipe", str(alive))
	var cp := map.get_checkpoint(match_node.last_cleared)
	var near := true
	for f: Fighter in match_node.party():
		if CoreUtil.flat(f.global_position - cp).length() > 6.0:
			near = false
	check(near, "respawned at the last checkpoint")
	var boss2 := match_node.boss
	check(boss2 != null and boss2 != boss and is_equal_approx(boss2.hp, boss2.max_hp) and match_node.enc_state[2] == "idle",
		"boss encounter reset to full hp")
	# ---- victory + records
	match_node._activate(2, match_node.party()[0])
	await sim(0.5)
	var results: Array = []
	match_node.match_ended.connect(func(r: Dictionary) -> void: results.append(r))
	match_node.boss.kill(match_node.party()[0])
	await sim(0.3)
	check(match_node.victory and match_node.ended, "boss kill ends the raid")
	check(not results.is_empty() and int(results[0].get("winner_team", -1)) == 0 and float(results[0].get("clear_time", 0.0)) > 0.0,
		"match_ended result has clear_time")
	check(FileAccess.file_exists(RECORDS), "records file written")
	var rec := match_node.load_records()
	check(float(rec.get("raid_best", {}).get("frost_forest", 0.0)) > 0.0, "best clear time stored", str(rec))


func test_boneyard_boss() -> void:
	await _new_raid("boneyard")
	check(match_node.encounters.size() == 4, "boneyard has 3 trash encounters + boss")
	match_node.debug_skip_to(3)
	await sim(0.2)
	var boss := match_node.boss
	check(boss != null and boss.mob_id == "black_knight", "black knight spawned")
	if boss == null:
		return
	match_node._activate(3, match_node.party()[0])
	await sim(12.0)
	var bb := match_node.boss_brain
	check(bb != null and bb.log_events.size() >= 2, "black knight rotation runs", str(bb.log_events if bb != null else []))
	boss.hp = boss.max_hp * 0.65
	await sim(0.5)
	var necro := 0
	for a: Fighter in bb.adds:
		if a.mob_id == "grave_necromancer":
			necro += 1
	check(bb.phase == 1 and necro == 2, "phase 2 summons the necromancers")
	# wave3 RAID-TUNE: weaker, timed adds; abilities unlocked by a phase start on their `first` timer.
	var add_ok := not bb.adds.is_empty()
	for a: Fighter in bb.adds:
		var base := float((a.mob_def.get("stats", {}) as Dictionary).get("hp", 0.0))
		if not is_equal_approx(a.max_hp, base * 0.5) or float(a.stat_bonus.get("dmg_out", 0.0)) > -0.3:
			add_ok = false
	check(add_ok, "boss adds spawn with add_hp / add_dmg scaling")
	var tide: Dictionary = bb.data["abilities"]["death_tide"]
	check(float(bb._cds.get("death_tide", 0.0)) > float(tide.get("first", 0.0)) - 1.0, "phase-2 ability starts on its first timer",
		str(bb._cds.get("death_tide", 0.0)))
	check(float(match_node.party()[0].stat_bonus.get("mp_regen", 0.0)) >= MatchRaid.RAID_MP_REGEN_BONUS - 0.001,
		"party gets the raid mana-regen supply bonus")
	await sim(8.0)
	await sim(float(bb.data.get("add_life", 20.0)) - 7.0)
	check(bb.log_events.has("add_expired"), "phase adds dissolve after add_life seconds")
	check(true, "boneyard boss fight simulated without crashing")
	if FileAccess.file_exists(RECORDS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
