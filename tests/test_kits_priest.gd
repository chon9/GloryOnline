extends SceneTree
## KITS-priest headless tests: knight, exorcist, cleric, paladin.
## Run: Godot --headless --path K:/Project/RONGYAO -s res://tests/test_kits_priest.gd
## Metadata checks, every skill cast in a deterministic World (auto_step = false) against 2 enemy dummies
## + 1 ally dummy at 50% hp, signature mechanic checks, and a 30 s scripted duel per kit (prints dps).

const DT: float = 1.0 / 60.0
const GROUP: String = "priest"
const KIT_IDS: Array[String] = ["knight", "exorcist", "cleric", "paladin"]
const DUMMY_PATH: String = "res://tests/test_kit_dummy.gd"
const DAMAGE_TAGS: Array[String] = ["melee", "ranged", "aoe", "launcher", "cc", "grab", "finisher", "debuff"]

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
	Combat.seed_rng(4242)
	reg = root.get_node_or_null("Registry")
	if reg == null:
		check(false, "Registry autoload present")
		_finish()
		return
	var dummy: ClassKit = (load(DUMMY_PATH) as Script).new()
	reg.call("register_kit", dummy)
	for id: String in KIT_IDS:
		await t_kit(id)
	await t_knight_mechanics()
	await t_exorcist_mechanics()
	await t_cleric_mechanics()
	await t_paladin_mechanics()
	for id: String in KIT_IDS:
		await t_duel(id)
	_finish()


func _finish() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("KITS[%s] TESTS: %d passed, %d failed" % [GROUP, passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


# ================================================================== world helpers
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


## Standard scene: caster at origin facing -Z, two enemies in front, one ally behind at 50% hp.
func setup_scene(class_id: String) -> Dictionary:
	await new_world()
	var c := spawn(class_id, 0, Vector3(0, 0, 0), 0.0)
	var e1 := spawn("test_dummy", 1, Vector3(0, 0, -2.0), PI)
	var e2 := spawn("test_dummy", 1, Vector3(1.0, 0, -2.6), PI)
	var al := spawn("test_dummy", 0, Vector3(1.5, 0, 1.0), 0.0)
	await sim(0.1)
	c.input.target_uid = e1.uid
	al.hp = al.max_hp * 0.5
	await sim(DT)
	return {"c": c, "e1": e1, "e2": e2, "al": al}


# ================================================================== per-kit tests
func t_kit(id: String) -> void:
	var kit: ClassKit = reg.call("get_kit", id)
	check(kit != null, "[%s] registered in Registry" % id)
	if kit == null:
		return
	var groups: Dictionary = reg.call("kit_ids_by_group")
	check((groups.get(GROUP, []) as Array).has(id), "[%s] listed in group %s" % [id, GROUP])
	check(kit.name_cn != "" and kit.name_en != "" and kit.group_id == GROUP and kit.group_cn != "" and kit.group_en != "",
		"[%s] names/group set" % id, "%s %s %s" % [kit.name_cn, kit.name_en, kit.group_id])
	check(kit.weapon_type != "" and kit.weapon_name_cn != "" and kit.weapon_name_en != "" and kit.model != ""
		and kit.famous != "" and kit.role != "", "[%s] weapon/model/famous/role set" % id)
	var hp := float(kit.get_stats()["hp"])
	check(hp >= 6000.0 and hp <= 13000.0 and float(kit.get_stats()["mp"]) >= 1000.0, "[%s] stats in balance range" % id, str(hp))
	check(kit.passives.size() >= 1, "[%s] has passives" % id)
	check(kit.skills.size() == 8, "[%s] exactly 8 skills" % id, str(kit.skills.size()))
	var slots_ok := true
	var names_ok := true
	for i in kit.skills.size():
		var s: SkillDef = kit.skills[i]
		if s.slot != i:
			slots_ok = false
		if s.name_cn == "" or s.name_en == "" or s.desc == "":
			names_ok = false
	check(slots_ok, "[%s] skills in slots 0..7" % id)
	check(names_ok, "[%s] every skill has CN/EN name and desc" % id)
	var ult := kit.skill_for_slot(7)
	check(ult != null and ult.has_tag("ultimate") and ult.cooldown >= 40.0 and ult.cooldown <= 90.0,
		"[%s] slot 7 is a 40-90 s ultimate" % id)
	var l1 := kit.skill_for_slot(1)
	var l2 := kit.skill_for_slot(2)
	check((l1 != null and l1.has_tag("launcher")) or (l2 != null and l2.has_tag("launcher")), "[%s] launcher in slot 1 or 2" % id)
	var basic := kit.skill_for_slot(0)
	var chain_ok := basic != null and basic.chain.size() >= 2 and basic.chain.size() <= 4
	if chain_ok:
		for cid: StringName in basic.chain:
			if kit.get_skill_by_id(cid) == null:
				chain_ok = false
	check(chain_ok, "[%s] basic attack chain of 2-4 resolvable parts" % id)
	var cd_ok := true
	for s: SkillDef in kit.skills:
		if s.slot >= 1 and s.slot <= 6 and (s.cooldown < 3.0 or s.cooldown > 16.0):
			cd_ok = false
	check(cd_ok, "[%s] normal cooldowns 3-16 s" % id)
	for s: SkillDef in kit.skills:
		await t_cast(id, s)


func t_cast(id: String, s: SkillDef) -> void:
	var sc: Dictionary = await setup_scene(id)
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	var e2: Fighter = sc["e2"]
	var al: Fighter = sc["al"]
	var reviving := s.has_tag("heal") and s.has_tag("ultimate") and id == "cleric"
	if reviving:
		al.kill(null)
		await sim(DT)
	if s.has_tag("gap_closer"):
		e1.global_position = Vector3(0, 0, -6.0)
		e2.global_position = Vector3(1.0, 0, -6.6)
		await sim(DT)
	var enemies: Array[Fighter] = [e1, e2]
	var hp0: Array[float] = [e1.hp, e2.hp]
	var al_hp0 := al.hp
	var c_pos0 := c.global_position
	c.reset_cooldowns()
	c.mp = c.max_mp
	var label := "[%s] %s (slot %d)" % [id, s.display_name(), s.slot]
	var ok := c.try_cast(s.slot)
	check(ok, label + " try_cast succeeds", c.cast_block_reason(s.slot))
	var affected := false
	var launched := false
	var buffed := false
	var airborne := false
	var max_move := 0.0
	await physics_frame
	for i in roundi(3.0 / DT):
		world.step(DT)
		for k in enemies.size():
			var e: Fighter = enemies[k]
			if e.hp < hp0[k] - 0.5 or e.status_mask != 0 or (e.state != Fighter.State.IDLE and e.state != Fighter.State.MOVE):
				affected = true
			if e.state == Fighter.State.LAUNCHED:
				launched = true
		if c.status_mask != 0 or c.shield_hp > 0.0:
			buffed = true
		if not c.is_on_floor():
			airborne = true
		max_move = maxf(max_move, CoreUtil.flat(c.global_position - c_pos0).length())
	var wants_damage := false
	for t: String in DAMAGE_TAGS:
		if s.has_tag(t):
			wants_damage = true
	if wants_damage:
		check(affected, label + " affects enemies (hp/state/status)")
	if s.has_tag("launcher"):
		check(launched, label + " launches the target (LAUNCHED)")
	if s.has_tag("heal"):
		if reviving:
			check(al.is_alive() and al.hp > 0.0, label + " revives the dead ally", "hp %.0f" % al.hp)
		else:
			check(al.hp > al_hp0 + 1.0, label + " heals the ally", "%.0f -> %.0f" % [al_hp0, al.hp])
	if s.has_tag("buff_self") or (s.has_tag("defensive") and not wants_damage):
		check(buffed, label + " buffs/guards the caster")
	if s.has_tag("escape"):
		check(airborne or max_move > 1.5, label + " moves the caster away / airborne")
	if s.has_tag("gap_closer"):
		check(max_move > 0.4, label + " closes the gap", "moved %.2f" % max_move)
	check(c.is_alive() and c.runner == null, label + " cast finishes cleanly")


# ================================================================== signature mechanics
func t_knight_mechanics() -> void:
	# Shield Counter: the next hit taken is countered.
	var sc: Dictionary = await setup_scene("knight")
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	e1.input.target_uid = c.uid
	check(c.try_cast(5), "[knight] Shield Counter cast")
	await sim(0.1)
	var hp_e := e1.hp
	var hp_c := c.hp
	e1.start_skill(e1.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.5)
	check(e1.hp < hp_e - 1.0, "[knight] Shield Counter strikes the attacker back", "%.0f -> %.0f" % [hp_e, e1.hp])
	check(hp_c - c.hp < 60.0, "[knight] counter-blocked hit is mostly absorbed", "took %.0f" % (hp_c - c.hp))
	check(not c.has_meta(&"knight_counter"), "[knight] counter window consumed")
	# Spell reflect: magic projectile reflected.
	await sim(1.5)
	c.reset_cooldowns()
	check(c.try_cast(5), "[knight] Spell Reflect cast")
	await sim(0.05)
	hp_e = e1.hp
	hp_c = c.hp
	e1.reset_cooldowns()
	e1.face_towards(c.global_position)
	e1.start_skill(e1.find_skill(&"test_dummy.bolt"), 2)
	await sim(0.6)
	check(e1.hp < hp_e - 1.0 and hp_c - c.hp < 120.0, "[knight] Spell Reflect reflects magic", "e %.0f->%.0f, knight took %.0f" % [hp_e, e1.hp, hp_c - c.hp])
	# Roar: taunt + passive threat.
	sc = await setup_scene("knight")
	c = sc["c"]
	e1 = sc["e1"]
	var e2: Fighter = sc["e2"]
	check(c.try_cast(4), "[knight] Roar cast")
	await sim(0.4)
	check(e1.has_status(&"taunted") and e2.has_status(&"taunted") and e1.status.source(&"taunted") == c,
		"[knight] Roar taunts every enemy toward the knight")
	check(e1.target_uid == c.uid and e1.top_threat() == c, "[knight] taunted enemy targets the knight")
	# Passive Shield Block: frontal physical hits reduced while idle.
	sc = await setup_scene("knight")
	c = sc["c"]
	e1 = sc["e1"]
	var dmg_front := c.kit.on_hit_taken(c, e1, Hit.normalize({"dmg": 1.0}), 100.0)
	e1.global_position = Vector3(0, 0, 2.0)
	var dmg_back := c.kit.on_hit_taken(c, e1, Hit.normalize({"dmg": 1.0}), 100.0)
	var dmg_magic := c.kit.on_hit_taken(c, e1, Hit.normalize({"dmg": 1.0, "type": "magic"}), 100.0)
	e1.global_position = Vector3(0, 0, -2.0)
	check(dmg_front < 80.0 and dmg_back == 100.0 and dmg_magic == 100.0, "[knight] Shield Block passive: frontal physical only",
		"%.0f %.0f %.0f" % [dmg_front, dmg_back, dmg_magic])
	# Shield Attack daze: never through a frontal block (random roll, so run non-deterministic).
	Combat.deterministic = false
	var blk_dazed := 0
	var open_dazed := 0
	for i in 20:
		sc = await setup_scene("knight")
		c = sc["c"]
		e1 = sc["e1"]
		var blocking := i < 10
		if blocking:
			e1.add_status(&"block", 5.0, 0.9)
		c.reset_cooldowns()
		c.try_cast(1)
		var dz := false
		await physics_frame
		for k in roundi(0.8 / DT):
			world.step(DT)
			if e1.has_status(&"stun"):
				dz = true
		if dz and blocking:
			blk_dazed += 1
		elif dz:
			open_dazed += 1
	Combat.deterministic = true
	check(blk_dazed == 0, "[knight] Shield Attack never dazes a frontal blocker", "%d/10 (open %d/10)" % [blk_dazed, open_dazed])


func t_exorcist_mechanics() -> void:
	var sc: Dictionary = await setup_scene("exorcist")
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	var kit: ClassKit = c.kit
	var seen: Array[String] = []
	var expect: Array[StringName] = [&"stun", &"freeze", &"burn"]
	for i in 3:
		var idx := int(kit.call("talisman_index", c))
		check(idx == i, "[exorcist] talisman %d loaded" % i, str(idx))
		e1.reset_for_round(Vector3(0, 0, -3.0))
		c.reset_cooldowns()
		check(c.try_cast(4), "[exorcist] elemental talisman cast %d" % i)
		var got := false
		await physics_frame
		for k in roundi(1.0 / DT):
			world.step(DT)
			if e1.has_status(expect[i]):
				got = true
		check(got, "[exorcist] talisman %d applies %s" % [i, expect[i]])
		seen.append(str(expect[i]))
		await sim(1.0)
	check(int(kit.call("talisman_index", c)) == 0, "[exorcist] talismans cycle back to lightning")
	# Spirit Guidance carries the loaded (lightning) talisman.
	e1.reset_for_round(Vector3(0, 0, -4.0))
	c.reset_cooldowns()
	check(c.try_cast(3), "[exorcist] Spirit Guidance cast")
	var stunned := false
	await physics_frame
	for k in roundi(1.0 / DT):
		world.step(DT)
		if e1.has_status(&"stun"):
			stunned = true
	check(stunned, "[exorcist] thrown scythe carries the loaded talisman (stun)")
	# Spirit Guidance through a frontal block: no talisman status (CORE block gating).
	e1.reset_for_round(Vector3(0, 0, -4.0))
	e1.add_status(&"block", 5.0, 0.9)
	check(Combat.angle_from_front(e1, c.global_position) <= Combat.BLOCK_FRONT_ANGLE_DEG, "[exorcist] blocker faces the caster")
	c.reset_cooldowns()
	c.set_meta(&"exorcist_talisman", 0)
	check(c.try_cast(3), "[exorcist] Spirit Guidance cast vs blocker")
	var blk_stun := false
	await physics_frame
	for k in roundi(1.0 / DT):
		world.step(DT)
		if e1.has_status(&"stun"):
			blk_stun = true
	check(not blk_stun, "[exorcist] blocked scythe applies no talisman stun")
	# Seal Talisman lowers outgoing damage (negative atk_up on the final blast victims), then expires.
	sc = await setup_scene("exorcist")
	c = sc["c"]
	e1 = sc["e1"]
	var patk0 := e1.get_stat("patk")
	check(c.try_cast(7), "[exorcist] Seal Talisman cast")
	await sim(1.6)
	check(is_equal_approx(e1.get_stat("patk"), patk0 * 0.85), "[exorcist] sealed enemy deals -15% damage",
		"%.1f -> %.1f" % [patk0, e1.get_stat("patk")])
	check(e1.has_status(&"atk_down") and not e1.has_status(&"atk_up"), "[exorcist] seal is the CORE atk_down debuff (no negative atk_up)")
	check(is_equal_approx(float(e1.stat_bonus.get("dmg_out", 0.0)), 0.0), "[exorcist] seal leaves dmg_out untouched")
	await sim(12.0)
	check(is_equal_approx(e1.get_stat("patk"), patk0), "[exorcist] seal expires", "%.1f" % e1.get_stat("patk"))
	# Hook breaks super armor.
	sc = await setup_scene("exorcist")
	c = sc["c"]
	e1 = sc["e1"]
	e1.add_status(&"super_armor", 5.0)
	check(c.try_cast(2), "[exorcist] Hook cast")
	var grabbed := false
	await physics_frame
	for k in roundi(1.0 / DT):
		world.step(DT)
		if e1.state == Fighter.State.GRABBED:
			grabbed = true
	check(grabbed, "[exorcist] Hook grabs through super armor")


func t_cleric_mechanics() -> void:
	var sc: Dictionary = await setup_scene("cleric")
	var c: Fighter = sc["c"]
	# Angel Wings glide: airborne much longer than a plain hop.
	check(c.try_cast(6), "[cleric] Angel Wings cast")
	var air_time := 0.0
	var capped := false
	await physics_frame
	for k in roundi(4.0 / DT):
		world.step(DT)
		if not c.is_on_floor():
			air_time += DT
		capped = capped or c.max_fall_speed > 0.0
	check(air_time > 1.8, "[cleric] Angel Wings hovers (slow fall)", "air %.2f s" % air_time)
	check(capped and c.max_fall_speed == 0.0 and c.gravity_scale == 1.0,
		"[cleric] Angel Wings uses the CORE fall cap and clears it after landing")
	c.stat_bonus["mp_regen"] = float(c.stat_bonus.get("mp_regen", 0.0)) + 0.5      # foreign modifier
	# Meditation: doubled MP regen after 3 s idle.
	await sim(3.5)
	check(is_equal_approx(float(c.stat_bonus.get("mp_regen", 0.0)), 1.5), "[cleric] Meditation doubles MP regen when idle (additive share)",
		str(c.stat_bonus.get("mp_regen", 0.0)))
	c.reset_cooldowns()
	c.try_cast(0)
	await sim(DT)
	check(is_equal_approx(float(c.stat_bonus.get("mp_regen", 0.0)), 0.5), "[cleric] Meditation resets on cast (foreign share kept)",
		str(c.stat_bonus.get("mp_regen", 0.0)))
	# Hypnosis sleep breaks on damage.
	sc = await setup_scene("cleric")
	c = sc["c"]
	var e1: Fighter = sc["e1"]
	check(c.try_cast(5), "[cleric] Hypnosis cast")
	await sim(0.5)
	check(e1.has_status(&"sleep") and e1.state == Fighter.State.STUNNED, "[cleric] Hypnosis puts the target to sleep")
	e1.receive_hit(c, {"dmg": 0.2}, c.global_position)
	check(not e1.has_status(&"sleep"), "[cleric] sleep breaks on damage")
	# Sacred Fire silences.
	sc = await setup_scene("cleric")
	c = sc["c"]
	e1 = sc["e1"]
	check(c.try_cast(4), "[cleric] Sacred Fire cast")
	await sim(0.6)
	check(e1.has_status(&"silence") and e1.has_status(&"burn"), "[cleric] Sacred Fire burns and silences")


func t_paladin_mechanics() -> void:
	var sc: Dictionary = await setup_scene("paladin")
	var c: Fighter = sc["c"]
	var e1: Fighter = sc["e1"]
	var al: Fighter = sc["al"]
	check(c.try_cast(3), "[paladin] Halo Smash cast")
	await sim(0.1)
	check(c.has_status(&"super_armor"), "[paladin] Halo Smash grants super armor")
	var hp_c := c.hp
	e1.start_skill(e1.find_skill(&"test_dummy.atk3"), 0)
	await sim(0.3)
	check(c.state == Fighter.State.CAST or c.runner != null or c.hp < hp_c, "[paladin] super armor keeps casting through hits",
		c.state_name())
	await sim(1.0)
	# Guardian Light: damage dealt heals the weakest ally.
	var al_hp := al.hp
	c.reset_cooldowns()
	e1.reset_for_round(Vector3(0, 0, -2.0))
	await sim(DT)
	c.try_cast(1)
	await sim(0.6)
	check(al.hp > al_hp + 1.0, "[paladin] Guardian Light heals the weakest ally from damage dealt", "%.0f -> %.0f" % [al_hp, al.hp])
	# Angel's Might ignores super armor.
	sc = await setup_scene("paladin")
	c = sc["c"]
	e1 = sc["e1"]
	e1.add_status(&"super_armor", 5.0)
	var p0 := e1.global_position
	check(c.try_cast(7), "[paladin] Angel's Might cast")
	await sim(1.5)
	check(e1.global_position.distance_to(p0) > 2.0, "[paladin] Angel's Might pushes back through super armor",
		"moved %.2f" % e1.global_position.distance_to(p0))
	# Holy Shield fully blocks a frontal physical hit.
	sc = await setup_scene("paladin")
	c = sc["c"]
	e1 = sc["e1"]
	check(c.try_cast(5), "[paladin] Holy Shield cast")
	await sim(0.1)
	var before := c.hp + c.shield_hp
	e1.start_skill(e1.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.3)
	check(c.hp + c.shield_hp >= before - 1.0, "[paladin] Holy Shield blocks the frontal hit", "%.0f -> %.0f" % [before, c.hp + c.shield_hp])


# ================================================================== 30 s scripted duel
func t_duel(id: String) -> void:
	await new_world()
	var c := spawn(id, 0, Vector3(0, 0, 0), 0.0)
	var d := spawn("test_dummy", 1, Vector3(0, 0, -3.0), PI)
	await sim(0.1)
	var rotation_order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	var casts := 0
	var refills := 0
	await physics_frame
	var steps := roundi(30.0 / DT)
	for i in steps:
		if i % 30 == 0:
			await physics_frame
		c.input.target_uid = d.uid
		var to := CoreUtil.flat(d.global_position - c.global_position)
		c.input.move = to.normalized() if to.length() > 2.2 else Vector3.ZERO
		c.input.aim_point = d.center()
		if c.can_act() or c.state == Fighter.State.CAST:
			for slot: int in rotation_order:
				var s := c.resolve_skill(slot)
				if s == null:
					continue
				if s.range > 0.0 and s.range < to.length() - 0.5 and not s.has_tag("gap_closer"):
					continue
				if c.try_cast(slot):
					casts += 1
					break
		world.step(DT)
		if d.hp < d.max_hp * 0.25:
			d.hp = d.max_hp
			refills += 1
		if not d.is_alive():
			d.revive(1.0)
			refills += 1
	var dps := c.damage_dealt / 30.0
	print("DUEL[%s] 30s vs dummy: damage %.0f, dps %.1f, casts %d, dummy refills %d, mp left %.0f" %
		[id, c.damage_dealt, dps, casts, refills, c.mp])
	check(dps > 30.0 and casts >= 10, "[%s] 30 s duel deals damage" % id, "dps %.1f casts %d" % [dps, casts])
	check(c.is_alive(), "[%s] survives the scripted duel" % id)
