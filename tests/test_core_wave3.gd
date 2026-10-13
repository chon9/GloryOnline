extends "res://tests/test_core_base.gd"
## CORE wave3 (integration) API tests: new statuses, gravity scale / hover, summon hits on the owner's kit,
## charge / cooldown APIs, recover_to_neutral, spawn_area / ground at "point", hit["_blocked"], replicated
## counters, body_radius, multi-victim grab offset, apply_on_hit_status, Fx cleanup paths, client smoothing.


class HookKit extends "res://tests/test_kit_dummy.gd":
	var dealt: Array = []    # [victim uid, by_summon_uid, blocked]

	func define() -> void:
		super.define()
		id = "test_hook"
		summons = {
			"wolf": {
				"name_cn": "灵狼", "name_en": "Spirit Wolf", "model": "knight", "weapon_type": "claws", "scale": 0.7,
				"stats": {"hp": 1500.0, "patk": 300.0, "pdef": 200.0, "mdef": 200.0, "move_speed": 7.0},
				"skills": [sk(0, "wolf_bite", "撕咬", "Bite", 1.2, 0.0, 0.4, &"attack", 2.0, ["melee"],
					[{"t": 0.15, "type": "melee", "range": 2.0, "hit": hit(0.8)}])],
			},
		}

	func on_hit_dealt(_f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
		dealt.append([victim.uid, int(h.get("_by_summon_uid", 0)), bool(h.get("_blocked", false))])


var hook: HookKit = null


func run_tests() -> void:
	suite_name = "wave3"
	hook = HookKit.new()
	root.get_node("Registry").call("register_kit", hook)
	await t_statuses()
	await t_gravity()
	await t_summon_hits()
	await t_charges()
	await t_recover()
	await t_spawn_area()
	await t_blocked_flag()
	await t_replicated()
	await t_body_radius()
	await t_grab_offset()
	await t_on_hit_status()
	await t_fx_cleanup()
	await t_client_smoothing()


func _pair(dist: float = 1.5, cls: String = "test_dummy") -> Array:
	await new_world()
	var a := world.spawn_fighter({"kind": "bot", "class_id": cls, "team": 0, "pos": Vector3.ZERO, "yaw": 0.0})
	var v := world.spawn_fighter({"kind": "bot", "class_id": "test_dummy", "team": 1, "pos": Vector3(0, 0, -dist), "yaw": PI})
	await sim(0.1)
	a.input.target_uid = v.uid
	await sim(DT)
	return [a, v]


func t_statuses() -> void:
	check(StatusSet.IDS.find(&"mark") == 24 and StatusSet.IDS.find(&"atk_down") == 25 and StatusSet.IDS.find(&"cast_slow") == 26,
		"atk_down / cast_slow appended after mark (bits 25, 26)")
	check(CharacterVisual.STATUS_IDS == StatusSet.IDS, "CharacterVisual.STATUS_IDS matches StatusSet.IDS")
	check(StatusSet.is_negative(&"atk_down") and StatusSet.is_negative(&"cast_slow"), "atk_down / cast_slow are NEGATIVE")
	await new_world()
	var f := spawn(0, Vector3.ZERO)
	await sim(0.05)
	var patk := f.get_stat("patk")
	var matk := f.get_stat("matk")
	var cs := f.get_stat("cast_speed")
	f.add_status(&"atk_down", 3.0, 0.2)
	f.add_status(&"cast_slow", 3.0, 0.5)
	check(approx(f.get_stat("patk"), patk * 0.8, 0.01) and approx(f.get_stat("matk"), matk * 0.8, 0.01), "atk_down lowers patk and matk")
	check(approx(f.get_stat("cast_speed"), cs * 0.5, 0.001), "cast_slow lowers cast_speed")
	check((f.status_mask >> 25) & 1 == 1 and (f.status_mask >> 26) & 1 == 1, "new statuses set their mask bits")
	var r := f.start_skill(f.find_skill(&"test_dummy.meteor"), 3)
	check(r != null and approx(r.rate, 0.5, 0.001), "cast_slow slows the skill runner rate")
	f.interrupt_cast()
	f.add_status(&"atk_up", 3.0, 0.3)
	check(approx(f.get_stat("patk"), patk * 1.3 * 0.8, 0.01), "atk_down stacks multiplicatively with atk_up")
	f.cleanse()
	check(not f.has_status(&"atk_down") and not f.has_status(&"cast_slow") and f.has_status(&"atk_up"), "cleanse removes atk_down / cast_slow only")


func t_gravity() -> void:
	await new_world()
	var a := spawn(0, Vector3(-3, 0, 0))
	var b := spawn(0, Vector3(3, 0, 0))
	await sim(0.2)
	b.gravity_scale = 0.3
	a.input.jump = true
	b.input.jump = true
	await sim(1.0)
	check(not a.is_airborne() and b.is_airborne(), "gravity_scale 0.3 keeps a jumper airborne longer")
	b.reset_for_round(Vector3(3, 0, 0))
	check(b.gravity_scale == 1.0 and b.max_fall_speed == 0.0, "reset_for_round resets gravity_scale / max_fall_speed")
	b.global_position = Vector3(3, 6, 0)
	b.set_hover(1.0, 1.0)
	await sim(0.5)
	check(b.velocity.y >= -1.01 and b.global_position.y > 5.0, "set_hover fall cap glides (vy %.2f, y %.2f)" % [b.velocity.y, b.global_position.y])
	b.clear_hover()
	check(b.gravity_scale == 1.0 and b.max_fall_speed == 0.0, "clear_hover restores gravity")


func t_summon_hits() -> void:
	var p: Array = await _pair(6.0, "test_hook")
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	hook.dealt.clear()
	var w := world.spawn_summon(a, "wolf", Vector3(0, 0, -4.8), 10.0)
	await sim(0.05)
	w.face_towards(v.global_position)
	var dmg0 := a.damage_dealt
	w.start_skill(w.get_skill(0), 0)
	await sim(0.4)
	var got := false
	for e: Array in hook.dealt:
		if e[0] == v.uid and e[1] == w.uid:
			got = true
	check(got, "summon hit calls owner.kit.on_hit_dealt with _by_summon_uid", str(hook.dealt))
	check(w.damage_dealt > 0.0 and approx(a.damage_dealt - dmg0, w.damage_dealt, 0.01), "summon damage credited to the owner too")
	# Owner's own hit: no _by_summon_uid key (the shared hit dict is cleaned up).
	hook.dealt.clear()
	a.global_position = Vector3(0, 0, -4.0)
	a.face_towards(v.global_position)
	a.start_skill(a.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.3)
	check(not hook.dealt.is_empty() and hook.dealt[0][1] == 0, "owner hits carry no _by_summon_uid")


func t_charges() -> void:
	await new_world()
	var f := spawn(0, Vector3.ZERO)
	await sim(0.05)
	check(f.max_charges(6) == 2 and f.get_charges(6) == 2, "max_charges reads SkillDef.charges")
	f.set_cooldown(2, 3.0)
	check(f.get_charges(2) == 0 and approx(f.get_cooldown(2), 3.0, 0.001) and not f.can_cast(2), "set_cooldown on a full 1-charge slot blocks it")
	await sim(1.0)
	check(approx(f.get_cooldown(2), 2.0, 0.05), "set_cooldown timer ticks")
	f.restore_charge(2)
	check(f.get_charges(2) == 1 and f.get_cooldown(2) == 0.0 and f.can_cast(2), "restore_charge refills and stops the timer")
	f.set_cooldown(6, 5.0)
	check(f.get_charges(6) == 1 and approx(f.cooldowns_packed[6], 5.0, 0.11), "set_cooldown on a 2-charge slot drops one charge")
	f.restore_charge(6, 5)
	check(f.get_charges(6) == 2 and f.charges_packed[6] == 2, "restore_charge caps at max and packs")
	f.set_cooldown(2, 4.0)
	f.set_cooldown(2, 0.0)
	check(f.get_charges(2) == 1 and f.get_cooldown(2) == 0.0, "set_cooldown(slot, 0) refills")


func t_recover() -> void:
	var p: Array = await _pair(1.5)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	a.start_skill(a.get_skill(1), 1)
	await sim(0.2)
	check(v.state == Fighter.State.LAUNCHED, "victim launched")
	check(v.recover_to_neutral(), "recover_to_neutral returns true")
	check(v.state == Fighter.State.AIR or v.state == Fighter.State.IDLE, "recover_to_neutral leaves LAUNCHED (%s)" % v.state_name())
	check(v.velocity.y <= 0.0 and v.juggle_points == 0.0, "recover_to_neutral clears launch velocity and juggle")
	await sim(1.0)
	check(v.state != Fighter.State.KNOCKDOWN and v.can_act(), "recovered fighter lands without knockdown")
	check(not v.recover_to_neutral(), "recover_to_neutral is a no-op when neutral")


func t_spawn_area() -> void:
	var p: Array = await _pair(8.0)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var r := a.start_skill(a.find_skill(&"test_dummy.two_hits"), 9)
	var hp0 := v.hp
	var area := r.spawn_area({"radius": 2.0, "hit": {"dmg": 1.0}}, v.global_position, 0.0)
	check(area is AreaEffect and world.effects.has(area), "SkillRunner.spawn_area returns a live AreaEffect")
	await sim(0.1)
	check(v.hp < hp0, "spawn_area burst hits at the explicit point")
	a.interrupt_cast()
	await sim(0.9)
	hp0 = v.hp
	var r2 := a.start_skill(a.find_skill(&"test_dummy.two_hits"), 9)
	r2.execute_step({"type": "ground", "at": "point", "pos": Vector3(5, 0, 5), "radius": 1.5, "duration": 2.0})
	var found: AreaEffect = null
	for e: Node in world.effects:
		if e is AreaEffect and (e as AreaEffect).global_position.distance_to(Vector3(5, 0, 5)) < 0.1:
			found = e
	check(found != null, "ground at:\"point\" places the area at pos")
	check(v.hp == hp0, "point area elsewhere does not hit the victim")


func t_blocked_flag() -> void:
	var p: Array = await _pair(1.5, "test_hook")
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	hook.dealt.clear()
	v.add_status(&"block", 3.0, 0.8)
	a.start_skill(a.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.3)
	check(not hook.dealt.is_empty() and hook.dealt[0][2] == true, "blocked frontal hit -> hit[\"_blocked\"] true")
	v.remove_status(&"block")
	hook.dealt.clear()
	await sim(0.3)
	a.start_skill(a.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.3)
	check(not hook.dealt.is_empty() and hook.dealt[0][2] == false, "unblocked hit -> hit[\"_blocked\"] false")


func t_replicated() -> void:
	var p: Array = await _pair(1.5)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var cfg := (a.get_node("Sync") as MultiplayerSynchronizer).replication_config
	var ok := true
	for prop: String in ["kit_counter", "kit_counter_max", "last_attacker_uid", "kills", "deaths", "net_damage_dealt",
			"net_healing_done", "net_pos", "facing_yaw"]:
		if not cfg.has_property(NodePath(".:" + prop)):
			ok = false
			print("  missing sync property: ", prop)
	check(ok, "Sync replicates kit_counter, last_attacker_uid, kills/deaths, damage/heal mirrors, net_pos")
	check(cfg.property_get_replication_mode(NodePath(".:kit_counter")) == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
		"kit_counter is ON_CHANGE")
	check(a.net_pos == a.position, "host net_pos == position")
	a.kit_counter = 3
	check(a.kit_counter == 3, "kit_counter writable")
	a.start_skill(a.find_skill(&"test_dummy.atk1"), 0)
	await sim(0.15)
	check(a.damage_dealt > 0.0 and v.last_attacker_uid == a.uid, "damage_dealt / last_attacker_uid set by a hit")
	await sim(0.3)
	check(a.net_damage_dealt == int(a.damage_dealt), "net_damage_dealt mirrors damage_dealt within 0.25 s")
	var before := a.net_damage_dealt
	a.damage_dealt += 500.0
	await sim(DT * 2)
	var throttled := a.net_damage_dealt == before or a.net_damage_dealt == int(a.damage_dealt)
	await sim(0.3)
	check(throttled and a.net_damage_dealt == int(a.damage_dealt), "damage mirror is throttled then catches up")
	v.kill(a)
	check(a.kills == 1 and v.deaths == 1, "kills / deaths counters")


func t_body_radius() -> void:
	var reg := root.get_node("Registry")
	reg.call("register_mob_def", "test_big", {"name_cn": "巨人", "name_en": "Giant", "scale": 1.35, "body_radius": 1.2,
		"body_height": 3.6, "stats": {"hp": 5000.0}, "skills": []})
	await new_world()
	var m := world.spawn_fighter({"kind": "mob", "mob_id": "test_big", "team": 1, "pos": Vector3.ZERO})
	var shape := (m.get_node("Shape") as CollisionShape3D).shape as CapsuleShape3D
	check(approx(m.radius(), 1.2, 0.001) and approx(shape.radius, 1.2, 0.001), "body_radius overrides the capsule radius")
	check(approx(m.height(), 3.6, 0.001) and approx(shape.height, 3.6, 0.001) and approx(m.center().y - m.global_position.y, 1.8, 0.001),
		"body_height overrides the capsule height and center")
	var n := spawn(0, Vector3(3, 0, 0))
	check(approx(n.radius(), Fighter.BODY_RADIUS, 0.001), "kit fighters keep the default radius")


func t_grab_offset() -> void:
	await new_world()
	var g := spawn(0, Vector3.ZERO, 0.0)
	var v1 := spawn(1, Vector3(-0.5, 0, -1.2), PI)
	var v2 := spawn(1, Vector3(0.5, 0, -1.2), PI)
	await sim(0.1)
	g.start_skill(g.find_skill(&"test_dummy.two_hits"), 9)
	var gh := {"dmg": 0.5, "grab": true, "grab_time": 0.6}
	v1.receive_hit(g, gh, g.global_position)
	v2.receive_hit(g, gh, g.global_position)
	await sim(0.1)
	check(v1.state == Fighter.State.GRABBED and v2.state == Fighter.State.GRABBED, "both victims grabbed")
	var side := absf((v1.global_position - v2.global_position).dot(g.right()))
	check(side >= v1.radius() * 2.0, "multi-victim grab spreads victims sideways (%.2f m)" % side)


func t_on_hit_status() -> void:
	var p: Array = await _pair(1.5)
	var a: Fighter = p[0]
	var v: Fighter = p[1]
	var h := Hit.normalize({"dmg": 1.0})
	check(kit.apply_on_hit_status(a, v, h, &"slow", 2.0, 0.3) and v.has_status(&"slow"), "apply_on_hit_status applies normally")
	v.remove_status(&"slow")
	var hb := h.duplicate()
	hb["_blocked"] = true
	check(not kit.apply_on_hit_status(a, v, hb, &"slow", 2.0, 0.3), "skipped when hit[\"_blocked\"]")
	v.add_status(&"block", 2.0, 0.8)
	check(not kit.apply_on_hit_status(a, v, h, &"slow", 2.0, 0.3), "skipped by the frontal block rule without _blocked")
	v.remove_status(&"block")
	v.add_status(&"super_armor", 2.0)
	check(not kit.apply_on_hit_status(a, v, h, &"stun", 1.0) and kit.apply_on_hit_status(a, v, h, &"mark", 2.0),
		"disabling status skipped under super armor, others apply")
	v.remove_status(&"super_armor")
	v.add_status(&"invuln", 1.0)
	check(not kit.apply_on_hit_status(a, v, h, &"poison", 2.0), "skipped while invulnerable")
	v.remove_status(&"invuln")
	v.receive_hit(a, {"dmg": 0.1, "knockdown": true}, a.global_position)
	await sim(DT)
	check(v.is_downed() and not kit.apply_on_hit_status(a, v, h, &"slow", 2.0) \
		and kit.apply_on_hit_status(a, v, Hit.with(h, {"otg": true}), &"slow", 2.0), "downed: needs otg")


func t_fx_cleanup() -> void:
	var fx := root.get_node_or_null("Fx")
	check(fx != null and fx.has_method("shutdown"), "Fx.shutdown exists")
	if fx == null:
		return
	var p: Array = await _pair(12.0)
	var a: Fighter = p[0]
	a.start_skill(a.get_skill(2), 2)
	await sim(0.15)
	var proj: Projectile = null
	for e: Node in world.effects:
		if e is Projectile:
			proj = e
	check(proj != null and fx._nodes.has(proj.fx_id), "projectile visual registered")
	if proj != null:
		var pv: Node = fx._nodes[proj.fx_id]
		check(pv != null and float(pv.get("homing_rate")) == proj.homing, "projectile passes homing_rate to Fx")
	var r := a.start_skill(a.find_skill(&"test_dummy.two_hits"), 9)
	var area := r.spawn_area({"radius": 2.0, "duration": 5.0}, Vector3(4, 0, 4), 0.0)
	await sim(DT)
	var pid := proj.fx_id if proj != null else -1
	var aid := area.fx_id
	check(fx._nodes.has(aid), "area visual registered")
	world.get_parent().remove_child(world)
	world.free()
	world = null
	check(not fx._nodes.has(pid) and not fx._nodes.has(aid), "freeing the World despawns live projectile/area visuals")
	fx.call("sfx", &"hit", Vector3.ZERO)
	fx.call("shutdown")
	await process_frame
	check((fx._voices as Array).is_empty() and fx._nodes.is_empty(), "Fx.shutdown frees the voice pool and visuals")
	fx.call("sfx", &"hit", Vector3.ZERO)
	check((fx._voices as Array).size() == 24, "sfx after shutdown rebuilds the voice pool")
	fx.call("shutdown")
	await process_frame


func t_client_smoothing() -> void:
	await new_world()
	var f := spawn(0, Vector3.ZERO)
	await sim(0.05)
	var now := Fighter._now_s()
	var old_delay := Fighter.interp_delay
	Fighter.interp_delay = 0.1
	f._snaps = [[now - 0.2, Vector3(0, 0, 0), 0.0], [now, Vector3(2, 0, 0), 1.0]]
	f._client_smooth()
	check(approx(f.position.x, 1.0, 0.1) and approx(f.rotation.y, 0.5, 0.06), "client renders halfway between bracketing snapshots (x %.2f)" % f.position.x)
	f._snaps = [[now + 1.0, Vector3(5, 0, 0), 0.0]]
	f._client_smooth()
	check(approx(f.position.x, 5.0, 0.001), "single snapshot holds")
	check(f.latest_net_position() == Vector3(5, 0, 0), "latest_net_position returns the newest snapshot")
	f._snaps.clear()
	f.net_pos = Vector3(1, 0, 1)
	check(f.position == Vector3(1, 0, 1) and f._snaps.is_empty(), "host: net_pos setter snaps (no buffering)")
	Fighter.interp_delay = old_delay
