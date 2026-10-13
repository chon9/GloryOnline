extends SceneTree
## KITS[swordsman] headless test: blade_master, berserker, spellblade, ghostblade.
## For every kit: Registry + metadata checks, every skill cast in a deterministic World against 2 enemy dummies
## (+1 ally dummy at 50% HP), effect assertions per tag, signature-passive checks, then a 30 s scripted mini-fight
## (prints DPS). Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_swordsman.gd

const DT: float = 1.0 / 60.0
const GROUP: String = "swordsman"
const KIT_IDS: Array[String] = ["blade_master", "berserker", "spellblade", "ghostblade"]
const DAMAGE_TAGS: Array[String] = ["melee", "ranged", "aoe", "launcher", "finisher", "grab", "cc", "debuff", "combo"]

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
	check(reg != null, "Registry autoload present")
	if reg != null:
		for kid: String in KIT_IDS:
			await test_kit(kid)
		await test_passives()
		await test_regressions()
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


func spawn(class_id: String, team: int, pos: Vector3, yaw: float) -> Fighter:
	return world.spawn_fighter({"kind": "bot", "peer": 0, "class_id": class_id, "team": team,
		"name": "%s_%d" % [class_id if class_id != "" else "dummy", team], "pos": pos, "yaw": yaw})


func sim(seconds: float) -> void:
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)


# ================================================================== per-kit tests
func test_kit(kid: String) -> void:
	print("---- %s ----" % kid)
	var kit: ClassKit = reg.call("get_kit", kid)
	check(kit != null, "%s: Registry has kit" % kid)
	if kit == null:
		return
	var ids_by_group: Dictionary = reg.call("kit_ids_by_group")
	check((ids_by_group.get(GROUP, []) as Array).has(kid), "%s: listed in group %s" % [kid, GROUP])
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == GROUP and kit.group_cn != "" and kit.group_en != "",
		"%s: names/group complete" % kid)
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != ""
		and kit.famous != "" and kit.role != "", "%s: weapon/model/famous/role set" % kid)
	check(kit.skills.size() == 8, "%s: exactly 8 skills" % kid, str(kit.skills.size()))
	var slots_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s == null or s.slot != i or s.name_cn == "" or s.name_en == "" or s.desc == "":
			slots_ok = false
	check(slots_ok, "%s: skills in slots 0..7 with CN/EN names + desc" % kid)
	check(kit.skills[7].has_tag("ultimate") and kit.skills[7].cooldown >= 40.0 and kit.skills[7].cooldown <= 90.0,
		"%s: slot 7 ultimate (40-90 s cd)" % kid)
	check(kit.skills[1].has_tag("launcher") or kit.skills[2].has_tag("launcher"), "%s: launcher in slot 1-2" % kid)
	check(kit.skills[0].chain.size() >= 2 and kit.skills[0].chain.size() <= 4, "%s: basic chain 2-4 parts" % kid)
	var chain_ok := true
	for cid: StringName in kit.skills[0].chain:
		if kit.get_skill_by_id(cid) == null or reg.call("get_skill", cid) == null:
			chain_ok = false
	check(chain_ok, "%s: chain parts resolvable" % kid)
	check(not kit.passives.is_empty(), "%s: passives listed" % kid)
	var st_ok := true
	for k: String in ["hp", "mp", "mp_regen", "patk", "matk", "pdef", "mdef", "move_speed"]:
		if not kit.stats.has(k):
			st_ok = false
	var hp := float(kit.stats.get("hp", 0.0))
	check(st_ok and hp >= 6000.0 and hp <= 9500.0 and float(kit.stats["move_speed"]) >= 5.5
		and float(kit.stats["move_speed"]) <= 6.8, "%s: stats in balance range" % kid)
	var normal_cd_ok := true
	for i in range(1, 7):
		var s: SkillDef = kit.skills[i]
		if s.cooldown < 3.0 or (s.cooldown > 15.0 and not s.has_tag("buff_self")):
			normal_cd_ok = false
	check(normal_cd_ok, "%s: normal cooldowns 3-15 s (buffs excepted)" % kid)

	await new_world()
	var caster := spawn(kid, 0, Vector3.ZERO, 0.0)
	var e1 := spawn("", 1, Vector3(0, 0, -2.0), PI)
	var e2 := spawn("", 1, Vector3(1.2, 0, -2.6), PI)
	var ally := spawn("", 0, Vector3(0, 0, 2.5), 0.0)
	await sim(0.1)
	check(caster.kit == kit and caster.max_hp == hp, "%s: fighter spawned with kit stats" % kid)
	for slot in 8:
		await cast_and_check(kid, caster, slot, e1, e2, ally)


func _reset_scene(caster: Fighter, e1: Fighter, e2: Fighter, ally: Fighter, keep_effects: bool) -> void:
	if not keep_effects:
		world.clear_effects()
	caster.reset_for_round(Vector3.ZERO)
	caster.facing_yaw = 0.0
	caster.rotation.y = 0.0
	caster.stat_bonus.clear()
	for m: StringName in [&"ghostblade_resonance", &"berserker_awaken"]:
		caster.set_meta(m, 0.0)
	e1.reset_for_round(Vector3(0, 0, -2.0))
	e2.reset_for_round(Vector3(1.2, 0, -2.6))
	ally.reset_for_round(Vector3(0, 0, 2.5))
	for e: Fighter in [e1, e2]:
		e.facing_yaw = PI
		e.rotation.y = PI
	ally.hp = ally.max_hp * 0.5
	caster.input.target_uid = e1.uid
	caster.input.aim_point = e1.center()


func cast_and_check(kid: String, caster: Fighter, slot: int, e1: Fighter, e2: Fighter, ally: Fighter) -> void:
	var gb_feast := kid == "ghostblade" and slot == 7
	_reset_scene(caster, e1, e2, ally, gb_feast)
	await sim(0.1)
	var s: SkillDef = caster.get_skill(slot)
	var label := "%s[%d] %s" % [kid, slot, s.display_name()]
	var boundaries_before := 0
	if gb_feast:
		boundaries_before = (caster.kit.call("boundaries_of", caster) as Array).size()
		check(boundaries_before >= 1, "%s: boundaries persist before Ghost Feast" % label, str(boundaries_before))
	var hp0 := [e1.hp, e2.hp]
	var ally_hp0 := ally.hp
	caster.reset_cooldowns()
	var ok := caster.try_cast(slot)
	check(ok, "%s: try_cast" % label, caster.cast_block_reason(slot))
	var damaged := false
	var launched := false
	var grabbed := false
	var statused := false
	var knocked := false
	var ally_buffed := false
	var self_block := false
	var self_buff := false
	var chain_casts := 1
	await physics_frame
	for i in roundi(3.0 / DT):
		if slot == 0 and chain_casts < caster.get_skill(0).chain.size() and caster.can_cast(0):
			if caster.try_cast(0):
				chain_casts += 1
		world.step(DT)
		for idx in 2:
			var e: Fighter = [e1, e2][idx]
			if e.hp < float(hp0[idx]) - 0.5:
				damaged = true
			if e.state == Fighter.State.LAUNCHED:
				launched = true
			if e.state == Fighter.State.GRABBED:
				grabbed = true
			if e.state == Fighter.State.KNOCKDOWN:
				knocked = true
			if e.status_mask != 0:
				statused = true
		if ally.has_status(&"atk_up") or ally.hp > ally_hp0 + 0.5 or ally.shield_hp > 0.0:
			ally_buffed = true
		if caster.has_status(&"block"):
			self_block = true
		if caster.has_status(&"atk_up") or caster.has_status(&"haste") or caster.has_status(&"super_armor"):
			self_buff = true
	var dealt := (float(hp0[0]) - e1.hp) + (float(hp0[1]) - e2.hp)
	print("  %s: dmg %.0f (%.1f%% of one dummy) launched=%s knocked=%s grabbed=%s status=%s" % [label, dealt,
		dealt / e1.max_hp * 100.0, launched, knocked, grabbed, statused])
	if slot == 0:
		check(chain_casts == caster.get_skill(0).chain.size(), "%s: full press chain cast" % label, str(chain_casts))
	var wants_damage := false
	for t: String in DAMAGE_TAGS:
		if s.has_tag(t):
			wants_damage = true
	if wants_damage:
		check(damaged or statused or launched or grabbed, "%s: affects enemies" % label)
	if s.has_tag("launcher"):
		check(launched, "%s: launcher puts target in LAUNCHED" % label)
	if s.has_tag("grab"):
		check(grabbed, "%s: grab puts target in GRABBED" % label)
	if s.has_tag("buff_ally"):
		check(ally_buffed, "%s: buffs ally" % label)
	if s.has_tag("defensive"):
		check(self_block or self_buff, "%s: defensive self status" % label)
	if s.has_tag("buff_self") and not s.has_tag("buff_ally") and not s.has_tag("defensive"):
		check(self_buff, "%s: self buff applied" % label)
	if s.has_tag("ultimate"):
		check(dealt >= e1.max_hp * 0.12, "%s: ultimate deals big damage" % label, "%.0f" % dealt)
	if s.has_tag("finisher") and slot != 0 and not s.has_tag("ultimate"):
		check(knocked or launched, "%s: finisher knocks down / blows away" % label)
	if gb_feast:
		var left := (caster.kit.call("boundaries_of", caster) as Array).size()
		check(left == 0 and int(caster.get_meta(&"ghostblade_last_feast", 0)) == boundaries_before,
			"%s: detonates all boundaries" % label, "%d -> %d" % [boundaries_before, left])
	check(caster.is_alive() and caster.state != Fighter.State.CAST, "%s: cast finished cleanly" % label, caster.state_name())


# ================================================================== signature passives
func test_passives() -> void:
	print("---- passives ----")
	# Berserker: Blood Awakening + Enrage.
	await new_world()
	var b := spawn("berserker", 0, Vector3.ZERO, 0.0)
	var d := spawn("", 1, Vector3(0, 0, -2.0), PI)
	await sim(0.1)
	b.hp = b.max_hp * 0.5
	await sim(0.1)
	var bonus := float(b.stat_bonus.get("patk", 0.0))
	check(absf(bonus - 0.2) < 0.02, "berserker: Blood Awakening +20% patk at 50% HP", "%.3f" % bonus)
	b.hp = b.max_hp
	b.input.target_uid = d.uid
	b.try_cast(6)
	await sim(0.6)
	check(bool(b.kit.call("is_berserk", b)), "berserker: Enrage enters Berserk")
	var hp_before := b.hp
	await sim(2.0)
	check(b.hp < hp_before, "berserker: Berserk drains HP", "%.0f -> %.0f" % [hp_before, b.hp])
	b.reset_cooldowns()
	b.try_cast(1)
	check(b.has_status(&"super_armor"), "berserker: Bloodthirsty Fight super armor on skill cast while Berserk")
	await sim(1.0)
	# Blood Sword costs HP.
	b.reset_cooldowns()
	await sim(0.5)
	var hp_b := b.hp
	b.try_cast(4)
	await sim(0.05)
	check(b.hp < hp_b - b.max_hp * 0.02, "berserker: Blood Sword costs HP")

	# Blade Master: Sword Mastery at 5+ combo.
	await new_world()
	var bm := spawn("blade_master", 0, Vector3.ZERO, 0.0)
	var d2 := spawn("", 1, Vector3(0, 0, -2.0), PI)
	await sim(0.1)
	bm.input.target_uid = d2.uid
	bm.combo_count = 6
	await sim(DT)
	check(float(bm.stat_bonus.get("atk_speed", 0.0)) > 0.1, "blade_master: Sword Mastery attack speed at 5+ combo")
	bm.stat_bonus["atk_speed"] = float(bm.stat_bonus.get("atk_speed", 0.0)) + 0.2      # foreign modifier
	bm.combo_count = 0
	await sim(DT)
	check(absf(float(bm.stat_bonus.get("atk_speed", 0.0)) - 0.2) < 0.001, "blade_master: Sword Mastery is an additive share",
		str(bm.stat_bonus.get("atk_speed", 0.0)))

	# Spellblade: Killing Intent stacks.
	await new_world()
	var sb := spawn("spellblade", 0, Vector3.ZERO, 0.0)
	var d3 := spawn("", 1, Vector3(0, 0, -6.0), PI)
	await sim(0.1)
	sb.input.target_uid = d3.uid
	for slot: int in [2, 1, 2]:
		sb.reset_cooldowns()
		await sim(0.05)
		sb.try_cast(slot)
		await sim(0.7)
	check(int(sb.get_meta(&"spellblade_intent_stacks", 0)) == 3 and sb.status.power(&"matk_up") > 0.11,
		"spellblade: Killing Intent stacks (3)", str(sb.get_meta(&"spellblade_intent_stacks", 0)))
	await sim(7.0)
	check(int(sb.get_meta(&"spellblade_intent_stacks", 0)) == 0 and not sb.has_status(&"matk_up"),
		"spellblade: Killing Intent expires")

	# Ghostblade: max 3 boundaries + resonance bonus.
	await new_world()
	var gb := spawn("ghostblade", 0, Vector3.ZERO, 0.0)
	var d4 := spawn("", 1, Vector3(0, 0, -5.0), PI)
	await sim(0.1)
	gb.input.target_uid = d4.uid
	for slot: int in [4, 5, 6, 4]:
		gb.reset_cooldowns()
		gb.try_cast(slot)
		await sim(0.8)
	var n := (gb.kit.call("boundaries_of", gb) as Array).size()
	check(n == 3, "ghostblade: at most 3 boundaries persist", str(n))
	check(float(gb.stat_bonus.get("dmg_out", 0.0)) > 0.05, "ghostblade: inside own boundary -> +damage")
	await sim(11.0)
	check((gb.kit.call("boundaries_of", gb) as Array).is_empty() and float(gb.stat_bonus.get("dmg_out", 0.0)) == 0.0,
		"ghostblade: boundaries expire and bonus clears")


# ================================================================== review regressions
func test_regressions() -> void:
	print("---- regressions ----")
	# Every step must run before the cancel window opens (otherwise combo-cancels skip it).
	for kid: String in KIT_IDS:
		var kit: ClassKit = reg.call("get_kit", kid)
		var late: Array[String] = []
		for s: SkillDef in _all_skills(kit):
			for stp: Dictionary in s.steps:
				if float(stp.get("t", 0.0)) > s.cast_time - s.cancel_window + 0.0001:
					late.append("%s@%.2f" % [s.id, float(stp.get("t", 0.0))])
		check(late.is_empty(), "%s: no step scheduled inside the cancel window" % kid, ", ".join(late))

	# Blade Master: Falling Phoenix Slash drives a juggled target down.
	await new_world()
	var bm := spawn("blade_master", 0, Vector3.ZERO, 0.0)
	var d := spawn("", 1, Vector3(0, 0, -2.0), PI)
	await sim(0.1)
	bm.input.target_uid = d.uid
	bm.try_cast(1)
	await sim(0.35)
	bm.reset_cooldowns()
	var cast_ok := bm.try_cast(4)
	if not cast_ok:
		await sim(0.4)
		cast_ok = bm.try_cast(4)
	var min_vy := 99.0
	var was_air := false
	for i in 40:
		world.step(DT)
		if bm.runner == null or bm.runner.elapsed > 0.33:
			if d.is_airborne():
				was_air = true
				min_vy = minf(min_vy, d.velocity.y)
		if bm.runner == null or bm.runner.elapsed > 0.45:
			break
	check(cast_ok and was_air and min_vy <= -10.0, "blade_master: Falling Phoenix Slash slams target down",
		"cast=%s vy=%.2f" % [cast_ok, min_vy])

	# Spellblade: Waltzing Wave Slash return wave fires even when combo-cancelled at the window.
	await new_world()
	var sb := spawn("spellblade", 0, Vector3.ZERO, 0.0)
	var d2 := spawn("", 1, Vector3(0, 0, -5.0), PI)
	await sim(0.1)
	sb.input.target_uid = d2.uid
	sb.try_cast(6)
	var cancelled := false
	var returned := false
	for i in 60:
		world.step(DT)
		for e: Variant in world.effects:
			if e is Projectile and (e as Projectile).caster == sb and (e as Projectile).velocity.z > 0.0:
				returned = true
		if not cancelled and sb.runner != null and sb.runner.in_cancel_window():
			sb.reset_cooldowns()
			cancelled = sb.try_cast(1)
	check(cancelled and returned, "spellblade: Waltz return wave survives a combo cancel",
		"cancel=%s return=%s" % [cancelled, returned])

	# Ghostblade: resonance is additive (keeps other kits' dmg_out modifiers, e.g. Exorcist seal -0.15).
	await new_world()
	var gb := spawn("ghostblade", 0, Vector3.ZERO, 0.0)
	await sim(0.1)
	gb.stat_bonus["dmg_out"] = float(gb.stat_bonus.get("dmg_out", 0.0)) - 0.15
	await sim(0.1)
	check(absf(float(gb.stat_bonus.get("dmg_out", 0.0)) + 0.15) < 0.001, "ghostblade: foreign dmg_out modifier preserved",
		"%.3f" % float(gb.stat_bonus.get("dmg_out", 0.0)))
	var d3 := spawn("", 1, Vector3(0, 0, -3.0), PI)
	await sim(0.1)
	gb.input.target_uid = d3.uid
	gb.try_cast(4)
	await sim(0.8)
	var with_res := float(gb.stat_bonus.get("dmg_out", 0.0))
	check(absf(with_res - (-0.15 + 0.10)) < 0.03 or with_res > -0.15 + 0.05, "ghostblade: resonance stacks on top of seal",
		"%.3f" % with_res)

	# Berserker: Berserk ends on reset_for_round.
	await new_world()
	var b := spawn("berserker", 0, Vector3.ZERO, 0.0)
	await sim(0.1)
	b.try_cast(6)
	await sim(0.6)
	var was_b := bool(b.kit.call("is_berserk", b))
	b.reset_for_round(Vector3.ZERO)
	await sim(2.0)
	check(was_b and not bool(b.kit.call("is_berserk", b)) and b.hp >= b.max_hp - 0.5,
		"berserker: Berserk cleared by reset_for_round", "hp %.0f/%.0f" % [b.hp, b.max_hp])

	# Spellblade: Killing Intent cleared by reset_for_round.
	sb = spawn("spellblade", 0, Vector3(4, 0, 0), 0.0)
	await sim(0.1)
	sb.try_cast(2)
	await sim(0.7)
	var had := int(sb.get_meta(&"spellblade_intent_stacks", 0)) > 0
	sb.reset_for_round(Vector3(4, 0, 0))
	await sim(0.1)
	check(had and int(sb.get_meta(&"spellblade_intent_stacks", 0)) == 0, "spellblade: Killing Intent cleared by reset_for_round")


func _all_skills(kit: ClassKit) -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for s: SkillDef in kit.skills:
		out.append(s)
		for cid: StringName in s.chain:
			var c := kit.get_skill_by_id(cid)
			if c != null and not out.has(c):
				out.append(c)
	return out


# ================================================================== 30 s mini fight
func mini_fight(kid: String) -> void:
	await new_world()
	var c := spawn(kid, 0, Vector3.ZERO, 0.0)
	var d := spawn("", 1, Vector3(0, 0, -3.0), PI)
	await sim(0.1)
	d.max_hp = 1000000.0
	d.hp = d.max_hp
	c.input.target_uid = d.uid
	var order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	var casts := 0
	var t := 0.0
	var hp0 := d.hp
	while t < 30.0:
		await physics_frame
		for i in 60:
			var to := CoreUtil.flat(d.global_position - c.global_position)
			var want_range := 2.2
			c.input.move = to.normalized() if to.length() > want_range else Vector3.ZERO
			c.input.aim_point = d.center()
			if c.state != Fighter.State.CAST or (c.runner != null and c.runner.in_cancel_window()):
				for slot: int in order:
					var sdef := c.get_skill(slot)
					if sdef == null or (sdef.range > 0.0 and to.length() > sdef.range + (1.0 if slot != 0 else 0.4)):
						continue
					if c.can_cast(slot) and c.try_cast(slot):
						casts += 1
						break
			world.step(DT)
			t += DT
	var dealt := hp0 - d.hp
	var dps := dealt / 30.0
	print("  MINIFIGHT %s: %d casts, %.0f damage in 30 s, DPS %.1f (~%.1f%% of a 7500-HP target per s), mp left %.0f"
		% [kid, casts, dealt, dps, dps / 7500.0 * 100.0, c.mp])
	check(dps > 100.0 and dps < 1500.0, "%s: mini-fight DPS in sane range" % kid, "%.1f" % dps)
	check(casts >= 15, "%s: rotation kept casting" % kid, str(casts))
