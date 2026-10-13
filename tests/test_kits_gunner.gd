extends SceneTree
## KITS-gunner headless tests: sharpshooter, spitfire, launcher, mechanic.
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_gunner.gd
## Deterministic World (auto_step = false, Combat.deterministic). Every skill of every kit is cast against
## two enemy dummies (+ one ally dummy at 50% hp), then a 30 s scripted rotation prints the dps.

const DT: float = 1.0 / 60.0
const DUMMY_PATH: String = "res://tests/test_kit_dummy.gd"
const KIT_IDS: Array[String] = ["sharpshooter", "spitfire", "launcher", "mechanic"]
## Tags that mean "this skill hurts or disables enemies".
const OFFENSIVE_TAGS: Array[String] = ["launcher", "aoe", "ranged", "melee", "cc", "finisher", "combo", "debuff",
	"grab", "ultimate", "interrupt"]

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
		var dummy: ClassKit = (load(DUMMY_PATH) as Script).new()
		reg.call("register_kit", dummy)
		for kid: String in KIT_IDS:
			await test_kit(kid)
		await test_specials()
	if world != null and is_instance_valid(world):
		world.queue_free()
	# Note: the engine may still print "N resources still in use at exit" for Fx's pooled SFX players
	# (ASSETS-side, also seen in other kit suites); requested in DEVIATIONS "Requests (KITS-gunner)".
	var fx := root.get_node_or_null("Fx")
	if fx != null and fx.has_method("clear_all"):
		fx.call("clear_all")
	await process_frame
	await process_frame
	print("KITS[gunner] TESTS: %d passed, %d failed" % [passed, failed])
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


func sim(seconds: float) -> void:
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)


## Steps `seconds` while recording what happened to `watch`: {uid: {launched, status, min_hp}}.
func sim_watch(seconds: float, watch: Array[Fighter], owner: Fighter = null) -> Dictionary:
	var rec: Dictionary = {"max_summons": 0}
	for f: Fighter in watch:
		rec[f.uid] = {"launched": false, "status": false, "downed": false, "min_hp": f.hp, "statuses": {}}
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)
		for f: Fighter in watch:
			if not is_instance_valid(f):
				continue
			var r: Dictionary = rec[f.uid]
			if f.state == Fighter.State.LAUNCHED:
				r["launched"] = true
			if f.is_downed() or f.state == Fighter.State.HITSTUN or f.state == Fighter.State.STUNNED:
				r["downed"] = true
			for sid: StringName in [&"stun", &"freeze", &"slow", &"weight", &"mark", &"burn"]:
				if f.has_status(sid):
					r["status"] = true
					(r["statuses"] as Dictionary)[sid] = true
			r["min_hp"] = minf(float(r["min_hp"]), f.hp)
		if owner != null and is_instance_valid(owner):
			rec["max_summons"] = maxi(int(rec["max_summons"]), world.summons_of(owner).size())
	return rec


func _is_offensive(s: SkillDef) -> bool:
	for t: String in OFFENSIVE_TAGS:
		if s.has_tag(t):
			return true
	return false


# ================================================================== per kit
func test_kit(kid: String) -> void:
	var kit: ClassKit = reg.call("get_kit", kid)
	check(kit != null, "%s: Registry has kit" % kid)
	if kit == null:
		return
	# ---- metadata
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == "gunner" and kit.group_cn != "" and kit.group_en != "",
		"%s: names/group set" % kid, "%s %s %s" % [kit.name_cn, kit.name_en, kit.group_id])
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != ""
		and kit.famous != "" and kit.role != "", "%s: weapon/model/famous/role set" % kid)
	check(float(kit.stats.get("hp", 0.0)) >= 6000.0 and float(kit.stats.get("hp", 0.0)) <= 9500.0, "%s: hp in balance band" % kid)
	check(kit.skills.size() == 8, "%s: exactly 8 skills" % kid, str(kit.skills.size()))
	var slots_ok := true
	var names_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s == null or s.slot != i:
			slots_ok = false
			continue
		if s.name_cn == "" or s.name_en == "" or s.desc == "":
			names_ok = false
	check(slots_ok, "%s: skills occupy slots 0..7 in order" % kid)
	check(names_ok, "%s: every skill has CN/EN name and desc" % kid)
	var s0 := kit.skill_for_slot(0)
	check(s0 != null and s0.chain.size() >= 2 and s0.chain.size() <= 4, "%s: slot 0 is a 2-4 part basic chain" % kid)
	var ult := kit.skill_for_slot(7)
	check(ult != null and ult.has_tag("ultimate") and ult.cooldown >= 40.0 and ult.cooldown <= 90.0,
		"%s: slot 7 ultimate tagged with long cooldown" % kid)
	var l1 := kit.skill_for_slot(1)
	var l2 := kit.skill_for_slot(2)
	check((l1 != null and l1.has_tag("launcher")) or (l2 != null and l2.has_tag("launcher")), "%s: launcher in slot 1 or 2" % kid)
	check(kit.passives.size() >= 1, "%s: passives listed" % kid)
	for sid: Variant in kit.summons:
		var sd: Dictionary = kit.summons[sid]
		check((sd.get("skills", []) as Array).size() >= 1 and sd.has("stats"), "%s: summon '%s' has stats + skills" % [kid, sid])
	# ---- cast every chain part of slot 0
	if s0 != null:
		for cid: StringName in s0.chain:
			var part := kit.get_skill_by_id(cid)
			check(part != null, "%s: chain part %s exists" % [kid, cid])
			if part != null:
				await cast_and_check(kit, part, true)
	# ---- cast every other skill
	for slot in range(1, 8):
		var s := kit.skill_for_slot(slot)
		if s != null:
			await cast_and_check(kit, s, false)
	# ---- 30 s scripted mini-fight
	await mini_fight(kit)


## Spawns caster + 2 enemy dummies + 1 ally dummy (50% hp), casts `s` and verifies its effect.
func cast_and_check(kit: ClassKit, s: SkillDef, chain_part: bool) -> void:
	await new_world()
	var d := clampf(s.range * 0.5, 1.4, 8.0)
	var caster := spawn(kit.id, 0, Vector3.ZERO, 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -d), PI)
	var e2 := spawn("test_dummy", 1, Vector3(1.0, 0, -d - 0.6), PI)
	var ally := spawn("test_dummy", 0, Vector3(2.5, 0, 1.5), 0.0)
	await sim(0.1)
	ally.hp = ally.max_hp * 0.5
	caster.input.target_uid = e1.uid
	caster.input.aim_point = e1.center()
	await sim(DT)
	var hp1 := e1.hp
	var hp2 := e2.hp
	var label := "%s: %s %s" % [kit.id, s.name_cn, s.name_en]
	var ok_cast := false
	if chain_part:
		ok_cast = caster.start_skill(s, 0) != null
	else:
		caster.reset_cooldowns()
		caster.mp = caster.max_mp
		ok_cast = caster.try_cast(s.slot)
	check(ok_cast, label + " casts", caster.cast_block_reason(s.slot))
	var rec: Dictionary = await sim_watch(3.0, [e1, e2] as Array[Fighter], caster)
	var r1: Dictionary = rec[e1.uid]
	var r2: Dictionary = rec[e2.uid]
	var dmg := (hp1 - float(r1["min_hp"])) + (hp2 - float(r2["min_hp"]))
	if s.has_tag("summon"):
		check(int(rec["max_summons"]) > 0, label + " spawns summons", str(rec["max_summons"]))
	elif _is_offensive(s):
		check(dmg > 0.0 or bool(r1["status"]) or bool(r2["status"]), label + " damages / disables enemies",
			"dmg %.0f" % dmg)
	if s.has_tag("launcher"):
		check(bool(r1["launched"]) or bool(r2["launched"]), label + " launches the target")
	if s.has_tag("cc") and not s.has_tag("launcher"):
		check(bool(r1["status"]) or bool(r1["downed"]) or bool(r2["status"]) or bool(r2["downed"]) or bool(r1["launched"]),
			label + " applies crowd control")
	print("  %s -> dmg %.0f (%.1f%% of dummy hp) launched=%s statuses=%s" % [label, dmg, dmg / e1.max_hp * 100.0,
		str(r1["launched"]), str((r1["statuses"] as Dictionary).keys())])
	check(caster.is_alive() and caster.state != Fighter.State.CAST, label + " cast finished cleanly", caster.state_name())


## 30 s: caster vs one (unkillable) dummy, casting skills in rotation whenever ready.
func mini_fight(kit: ClassKit) -> void:
	await new_world()
	var caster := spawn(kit.id, 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -5.0), PI)
	await sim(0.1)
	e.max_hp = 1000000.0
	e.hp = e.max_hp
	var hp0 := e.hp
	caster.input.target_uid = e.uid
	var order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	var casts := 0
	await physics_frame
	for i in roundi(30.0 / DT):
		caster.input.aim_point = e.center()
		if caster.can_act() or caster.state == Fighter.State.CAST:
			for slot: int in order:
				var sk_def := caster.get_skill(slot)
				if sk_def != null and sk_def.has_tag("buff_self") and sk_def.has_tag("escape"):
					continue
				if caster.can_cast(slot) and caster.try_cast(slot):
					casts += 1
					break
		world.step(DT)
	var dealt := hp0 - e.hp
	var dps := dealt / 30.0
	print("KITS[gunner] %s 30s mini-fight: %d casts, %.0f damage, dps %.1f (dummy 8000 hp -> %.1f s to kill)" % [
		kit.id, casts, dealt, dps, 8000.0 / maxf(dps, 0.01)])
	check(dps > 150.0 and dps < 700.0, "%s: mini-fight dps in a sane band" % kit.id, "%.1f" % dps)
	check(caster.is_alive(), "%s: caster alive after mini-fight" % kit.id)


# ================================================================== signature mechanics
func test_specials() -> void:
	# Sharpshooter aerial recoil: a shot fired while airborne pushes the shooter up.
	await new_world()
	var ss := spawn("sharpshooter", 0, Vector3.ZERO, 0.0)
	var e := spawn("test_dummy", 1, Vector3(0, 0, -8), PI)
	await sim(0.1)
	ss.input.target_uid = e.uid
	ss.velocity.y = 9.0
	await sim(0.55)
	var vy_before := ss.velocity.y
	var airborne := not ss.is_on_floor()
	ss.try_cast(0)
	check(airborne and ss.velocity.y > vy_before + 1.0, "sharpshooter: airborne shot adds upward recoil",
		"air=%s %.2f -> %.2f" % [str(airborne), vy_before, ss.velocity.y])
	# Gun-fu: keep shooting in the air -> stays up longer than a plain jump (~0.8 s).
	await new_world()
	ss = spawn("sharpshooter", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -8), PI)
	await sim(0.1)
	ss.input.target_uid = e.uid
	ss.velocity.y = 9.0
	await sim(0.2)
	var air_time := 0.0
	await physics_frame
	for i in roundi(3.0 / DT):
		ss.input.aim_point = e.center()
		if ss.can_cast(0):
			ss.try_cast(0)
		world.step(DT)
		if ss.is_on_floor():
			break
		air_time += DT
	check(air_time > 1.2, "sharpshooter: continuous fire keeps the gunner airborne", "%.2f s" % air_time)
	# Sharpshooter Dual Load restores the last used skill.
	await new_world()
	ss = spawn("sharpshooter", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -1.4), PI)
	await sim(0.1)
	ss.input.target_uid = e.uid
	check(ss.try_cast(1), "sharpshooter: knee attack cast")
	await sim(0.6)
	check(ss.get_charges(1) == 0 and ss.get_cooldown(1) > 0.0, "sharpshooter: knee attack on cooldown")
	check(ss.try_cast(6), "sharpshooter: dual load cast")
	await sim(0.3)
	check(ss.get_charges(1) == 1, "sharpshooter: dual load restores the last skill", str(ss.get_charges(1)))
	# Rapid / Burst Firing are additive stat_bonus shares (a re-run of on_spawn does not stack, foreign shares survive).
	ss.stat_bonus["crit"] = float(ss.stat_bonus.get("crit", 0.0)) + 0.25
	ss.kit.on_spawn(ss)
	check(absf(float(ss.stat_bonus.get("atk_speed", 0.0)) - 0.1) < 0.001 and absf(float(ss.stat_bonus.get("crit", 0.0)) - 0.85) < 0.001,
		"sharpshooter: firing passives are additive stat_bonus shares", str(ss.stat_bonus))
	# Spitfire: grenades and special bullets use charges; ice bullet freezes (deterministic).
	await new_world()
	var sp := spawn("spitfire", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -7), PI)
	await sim(0.1)
	sp.input.target_uid = e.uid
	check(sp.get_charges(2) == 3, "spitfire: grenade has 3 charges", str(sp.get_charges(2)))
	sp.try_cast(2)
	await sim(0.4)
	check(sp.get_charges(2) == 2 and sp.can_cast(2), "spitfire: grenade charge consumed, next charge usable at once")
	await sim(2.0)
	sp.reset_cooldowns()
	var rec: Dictionary = {}
	sp.try_cast(4)
	rec = await sim_watch(1.0, [e] as Array[Fighter])
	check((rec[e.uid]["statuses"] as Dictionary).has(&"freeze"), "spitfire: ice bullet freezes", str(rec[e.uid]["statuses"]))
	# A frontal block stops the freeze (CORE: blocked hits apply no CC).
	await new_world()
	sp = spawn("spitfire", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -7), PI)
	await sim(0.1)
	sp.input.target_uid = e.uid
	e.add_status(&"block", 10.0, 0.8, e)
	sp.try_cast(4)
	rec = await sim_watch(1.0, [e] as Array[Fighter])
	check(not (rec[e.uid]["statuses"] as Dictionary).has(&"freeze"), "spitfire: ice bullet does not freeze through a frontal block",
		str(rec[e.uid]["statuses"]))
	# Launcher: Artillery Mastery bonus grows with distance; airborne cannon recoil.
	await new_world()
	var la := spawn("launcher", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -15), PI)
	await sim(0.1)
	la.input.target_uid = e.uid
	await sim(0.05)
	check(absf(float(la.stat_bonus.get("dmg_out", 0.0)) - 0.2) < 0.001, "launcher: artillery mastery long-range bonus",
		str(la.stat_bonus.get("dmg_out", 0.0)))
	e.global_position = Vector3(0, 0, -5)
	await sim(0.05)
	check(absf(float(la.stat_bonus.get("dmg_out", 0.0)) - 0.1) < 0.001, "launcher: artillery mastery base bonus")
	la.stat_bonus["dmg_out"] = float(la.stat_bonus.get("dmg_out", 0.0)) + 0.3      # foreign modifier
	await sim(0.1)
	check(absf(float(la.stat_bonus.get("dmg_out", 0.0)) - 0.4) < 0.001, "launcher: artillery mastery keeps other dmg_out modifiers",
		str(la.stat_bonus.get("dmg_out", 0.0)))
	# Mechanic: rotor wings hover, gadget mark, seeker robot explodes.
	await new_world()
	var me := spawn("mechanic", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -6), PI)
	await sim(0.1)
	me.input.target_uid = e.uid
	check(me.try_cast(5), "mechanic: rotor wings cast")
	var max_alt := 0.0
	var y_at_1 := 0.0
	var air_at_1 := false
	var hovered := false
	await physics_frame
	for i in roundi(4.5 / DT):
		world.step(DT)
		max_alt = maxf(max_alt, me.global_position.y)
		hovered = hovered or (me.gravity_scale < 1.0 and me.max_fall_speed > 0.0)
		if i == roundi(1.0 / DT):
			y_at_1 = me.global_position.y
			air_at_1 = not me.is_on_floor()
		if i > roundi(0.4 / DT) and me.can_cast(0):
			me.try_cast(0)      # keep shooting from the air (recoil)
	check(air_at_1 and y_at_1 > 0.5, "mechanic: rotor wings keep the mechanic flying", "y=%.2f" % y_at_1)
	check(max_alt < 3.5, "mechanic: rotor flight stays in melee reach (max alt < 3.5 m)", "max=%.2f" % max_alt)
	await sim(2.0)
	check(me.is_on_floor(), "mechanic: rotor wings expire and the mechanic lands")
	check(hovered and me.gravity_scale == 1.0 and me.max_fall_speed == 0.0,
		"mechanic: rotor glide uses CORE set_hover and clears it on landing", "g %.2f" % me.gravity_scale)
	me.reset_cooldowns()
	me.try_cast(1)
	rec = await sim_watch(1.5, [e] as Array[Fighter])
	check(bool(rec[e.uid]["launched"]) and (rec[e.uid]["statuses"] as Dictionary).has(&"mark"),
		"mechanic: bouncing mine launches and marks", str(rec[e.uid]["statuses"]))
	# Foreign marks (Exorcist / Assassin) do not trigger the Mechanical Box rifle bonus.
	await new_world()
	me = spawn("mechanic", 0, Vector3.ZERO, 0.0)
	var other := spawn("test_dummy", 0, Vector3(3, 0, 0), 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -6), PI)
	await sim(0.1)
	me.input.target_uid = e.uid
	e.add_status(&"mark", 10.0, 1.0, other)
	check(not me.kit.call("has_own_mark", me, e), "mechanic: foreign mark is not a Mechanical Box mark")
	me.try_cast(3)
	await sim(0.8)
	check(me.kit.call("has_own_mark", me, e), "mechanic: gadget hit sets own mark")
	await new_world()
	me = spawn("mechanic", 0, Vector3.ZERO, 0.0)
	e = spawn("test_dummy", 1, Vector3(0, 0, -5), PI)
	await sim(0.1)
	me.input.target_uid = e.uid
	var hp0 := e.hp
	me.try_cast(2)
	await sim(0.3)
	var seekers := world.summons_of(me, "seeker")
	check(seekers.size() == 1, "mechanic: seeker robot spawned")
	await sim(4.0)
	check(e.hp < hp0, "mechanic: seeker robot reaches the enemy and explodes", "%.0f" % (hp0 - e.hp))
	check(world.summons_of(me, "seeker").is_empty(), "mechanic: seeker robot is gone after self-destruct")
	check(me.kit.call("has_own_mark", me, e), "mechanic: robot hits mark through CORE summon-hit forwarding")
