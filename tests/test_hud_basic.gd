extends SceneTree
## HUD headless tests: binding, per-frame updates, skill bar cooldowns/charges/MP, statuses, target frame,
## boss bar + enrage, kill feed (signal + client-style polling), scoreboard, Match signals, combo, help,
## spectating, defeat overlay, null match_node.
## Run: godot --headless --path K:/Project/RONGYAO -s res://tests/test_hud_basic.gd

const DT: float = 1.0 / 60.0
const KIT_PATH: String = "res://tests/test_kit_dummy.gd"

var passed: int = 0
var failed: int = 0
var world: World = null
var hud: Hud = null
var kit: ClassKit = null


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	Combat.deterministic = true
	Combat.seed_rng(7)
	kit = (load(KIT_PATH) as Script).new()
	var reg := root.get_node_or_null("Registry")
	if reg != null:
		reg.call("register_kit", kit)
		reg.call("register_mob_def", "hud_test_boss", {"name_cn": "测试魔王", "name_en": "Test Overlord",
			"model": "black_knight", "weapon_type": "black_knight_sword", "scale": 1.0, "tint": Color(0.8, 0.3, 0.2),
			"stats": {"hp": 50000.0, "mp": 0.0, "patk": 600.0, "pdef": 500.0, "mdef": 500.0}, "skills": []})
	else:
		check(false, "Registry autoload present")
	await run_tests()
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	if world != null and is_instance_valid(world):
		world.queue_free()
	await process_frame
	print("HUD TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		print("FAIL: " + label + ("" if detail == "" else "  (" + detail + ")"))


func new_world() -> void:
	world = World.new()
	world.auto_step = false
	root.add_child(world)
	var body := StaticBody3D.new()
	body.collision_layer = CoreUtil.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	world.add_child(body)
	await physics_frame


func spawn(team: int, pos: Vector3, kind: String = "bot", name_s: String = "", class_id: String = "test_dummy",
		mob_id: String = "") -> Fighter:
	return world.spawn_fighter({"kind": kind, "peer": root.multiplayer.get_unique_id() if kind == "player" else 0,
		"class_id": class_id, "mob_id": mob_id, "team": team, "name": name_s, "pos": pos, "yaw": 0.0})


func sim(seconds: float) -> void:
	await physics_frame
	for i in maxi(1, roundi(seconds / DT)):
		world.step(DT)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func run_tests() -> void:
	await new_world()
	var me := spawn(0, Vector3(0, 0, 4), "player", "玩家 Hero")
	var ally := spawn(0, Vector3(2, 0, 4), "bot", "队友 Ally")
	var e1 := spawn(1, Vector3(0, 0, -2), "bot", "敌人一 Foe A")
	var e2 := spawn(1, Vector3(3, 0, -2), "bot", "敌人二 Foe B")
	await sim(0.1)

	hud = Hud.new()
	root.add_child(hud)
	await process_frame
	hud.bind(world, null, 0)
	check(hud.get_local_fighter() == me, "auto local fighter = this peer's player")
	var rc := hud.refresh_count
	for i in 40:
		world.step(DT)
		await process_frame
	check(hud.refresh_count > rc + 5, "hud refreshes over frames", "count %d -> %d" % [rc, hud.refresh_count])
	check(hud.player_frame.visible and hud.player_frame.name_label.text.begins_with("玩家 Hero"), "player frame shows local name",
		hud.player_frame.name_label.text)
	check(hud.player_frame.class_label.text.contains("测试木人"), "player frame shows class CN/EN", hud.player_frame.class_label.text)
	check(not hud.is_spectating() and not hud.spectate_label.visible, "not spectating own fighter")
	check(hud.team_frames.visible and (hud.team_frames.rows[0].uid == ally.uid), "party frame lists the ally")
	check(hud.enemy_frames.visible and hud.enemy_frames.rows[1].uid == e2.uid, "enemy summary lists both enemies in PvP")
	check(not hud.boss_bar.visible, "no boss bar without a boss")

	# ---- skill bar
	var slot2 = hud.skill_bar.slots[2]
	check(slot2.skill != null and str(slot2.skill.id) == "test_dummy.bolt", "slot 2 bound to Light Bolt")
	check(hud.skill_bar.slots[0].key_label == "LMB" and hud.skill_bar.slots[7].key_label == "2", "key labels LMB..2")
	me.target_uid = e1.uid
	check(me.try_cast(2), "cast bolt")
	await sim(0.05)
	hud.refresh()
	check(slot2.cd > 0.5 and slot2.charges == 0, "slot 2 shows cooldown after cast", "cd %.2f ch %d" % [slot2.cd, slot2.charges])
	await sim(1.2)
	hud.refresh()
	check(slot2.cd <= 0.0 and slot2.charges == 1, "slot 2 cooldown clears", "cd %.2f" % slot2.cd)
	var slot6 = hud.skill_bar.slots[6]
	check(slot6.max_charges == 2 and slot6.charges == 2, "slot 6 shows 2 charges")
	me.try_cast(6)
	await sim(0.5)
	hud.refresh()
	check(slot6.charges == 1 and slot6.cd > 0.0, "slot 6 charge consumed (1 left, recharging)", "ch %d cd %.2f" % [slot6.charges, slot6.cd])
	me.mp = 10.0
	hud.refresh()
	check(hud.skill_bar.slots[3].no_mp and not hud.skill_bar.slots[0].no_mp, "MP-insufficient greying on costly slot only")
	me.mp = me.max_mp
	# cast bar for a long cast (tempest 1.4 s)
	me.reset_cooldowns()
	await sim(0.3)
	me.try_cast(7)
	await sim(0.1)
	hud.refresh()
	check(hud.skill_bar.slots[7].casting, "ultimate slot highlighted while casting")
	check(hud.skill_bar.cast_panel.visible and hud.skill_bar.cast_label.text.contains("风暴"), "cast bar shows long cast",
		hud.skill_bar.cast_label.text)
	await sim(2.0)
	hud.refresh()
	check(not hud.skill_bar.cast_panel.visible, "cast bar hides after the cast")

	# ---- statuses + target
	me.add_status(&"burn", 5.0, 1.0, e1)
	me.add_status(&"haste", 5.0, 0.3)
	me.add_status(&"slow", 5.0, 0.3)
	await sim(0.05)
	hud.refresh()
	var bits: PackedInt32Array = hud.player_frame.status_row.bits()
	check(bits.has(12) and bits.has(9) and bits.has(8), "player status row shows burn/haste/slow", str(bits))
	check(bits.find(8) < bits.find(9), "debuffs listed before buffs")
	me.target_uid = e1.uid
	hud.refresh()
	check(hud.target_frame.visible and hud.target_frame.fighter_uid == e1.uid, "target frame follows lock-on")
	e1.add_status(&"def_up", 3.0, 0.2)
	await sim(0.05)
	me.target_uid = e1.uid   # no input source in tests: the host tick clears lock-on
	hud.refresh()
	check(hud.target_frame.status_row.bits().has(19), "target frame shows target statuses", "mask %d alive %s state %s bits %s" % [e1.status_mask, e1.is_alive(), e1.state_name(), str(hud.target_frame.status_row.bits())])

	# ---- combo
	me.combo_count = 7
	hud.refresh()
	check(hud.combo.is_showing() and hud.combo.count == 7, "combo counter shows 7 hits")

	# ---- kill feed (host signal path)
	var before := hud.kill_feed.entry_count()
	e2.kill(me)
	await process_frame
	check(hud.kill_feed.entry_count() == before + 1 and hud.kill_feed.entry_text(0).contains("击败"), "kill feed entry on death",
		hud.kill_feed.entry_text(0))
	check(hud.kill_feed.entry_text(0).contains("玩家 Hero") and hud.kill_feed.entry_text(0).contains("敌人二"), "kill feed names killer and victim")
	hud.refresh()
	check(hud.kill_feed.entry_count() == before + 1, "no duplicate entry from death polling")
	# client-style death (no signal): polled
	ally.hp = 0.0
	ally.state = Fighter.State.DEAD
	hud.refresh()
	check(hud.kill_feed.entry_count() == before + 1, "polled death waits a grace period for kill_event")
	hud.flush_pending_deaths(0.5)
	check(hud.kill_feed.entry_count() == before + 2, "kill feed polls deaths without signals (clients)")
	# client-style death followed by a reliable kill_event naming the killer
	e1.hp = 0.0
	e1.state = Fighter.State.DEAD
	hud.refresh()
	hud._on_kill_event(e1.uid, me.uid)
	check(hud.kill_feed.entry_count() == before + 3 and hud.kill_feed.entry_text(0).contains("玩家 Hero"),
		"late kill_event still names the killer", hud.kill_feed.entry_text(0))
	hud.flush_pending_deaths(1.0)
	check(hud.kill_feed.entry_count() == before + 3, "no duplicate after kill_event")
	e1.revive(1.0)
	hud.refresh()
	check(hud.team_frames.rows[0].hp.dead, "dead ally frame greyed")

	# ---- scoreboard
	hud.set_scoreboard_forced(true)
	await frames(3)
	check(hud.scoreboard.visible and hud.scoreboard.row_count == 4, "scoreboard populates all players", "rows %d" % hud.scoreboard.row_count)
	var k_text: String = hud.scoreboard.cells[0][0][2].text
	check(k_text == "1", "scoreboard shows the player's kill", k_text)
	hud.set_scoreboard_forced(false)
	await frames(2)
	check(not hud.scoreboard.visible, "scoreboard hides when released")

	# ---- help
	hud.set_help_visible(true)
	check(hud.help.visible and (hud.help.skill_rows[2][1] as RichTextLabel).text.contains("光弹"), "help lists class skills")
	hud.set_help_visible(false)

	# ---- boss
	var boss := spawn(1, Vector3(0, 0, -8), "boss", "", "", "hud_test_boss")
	await sim(0.05)
	hud.refresh()
	check(hud.boss_bar.visible and hud.boss_bar.name_label.text.contains("测试魔王"), "boss bar appears for kind boss",
		hud.boss_bar.name_label.text)
	check(not hud.enemy_frames.visible, "enemy summary hidden in PvE")
	boss.hp = boss.max_hp * 0.05
	hud.refresh()
	check(hud.boss_bar.is_enraged() and hud.boss_bar.enrage_label.text.contains("狂暴"), "boss enrage indicator under 10%")
	check(hud.boss_bar.phase_label.text.contains("Phase"), "boss phase shown")
	# client: MatchRaid score.phase is 0-based
	boss.hp = boss.max_hp * 0.68
	hud.score = {"mode": "raid", "phase": 1, "enraged": false, "boss_uid": boss.uid}
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 2", "client phase from score.phase (0-based)", hud.boss_bar.phase_label.text)
	hud.score = {"mode": "raid", "phase": 2, "enraged": true}
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 3" and hud.boss_bar.is_enraged(), "score.enraged shows enrage")
	# host: BossBrain.phase is 0-based
	var gs := GDScript.new()
	gs.source_code = "extends Node
var phase: int = 1
var enraged: bool = false
"
	gs.reload()
	var fake_brain: Node = gs.new()
	boss.add_child(fake_brain)
	var old_brain := boss.brain
	boss.brain = fake_brain
	hud.score = {}
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 2", "host brain phase 1 shows Phase 2", hud.boss_bar.phase_label.text)
	fake_brain.set("phase", 0)
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 1", "host brain phase 0 shows Phase 1")
	boss.brain = old_brain
	fake_brain.queue_free()
	# static fallback: mob_def.boss.phases, first entry (hp 1.0) does not count
	var old_def := boss.mob_def
	boss.mob_def = {"boss": {"phases": [{"hp": 1.0}, {"hp": 0.7}, {"hp": 0.4}]}}
	boss.hp = boss.max_hp
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 1", "fallback full hp = Phase 1", hud.boss_bar.phase_label.text)
	boss.hp = boss.max_hp * 0.68
	hud.refresh()
	check(hud.boss_bar.phase_label.text == "阶段 Phase 2", "fallback 68% = Phase 2", hud.boss_bar.phase_label.text)
	boss.mob_def = old_def
	boss.hp = boss.max_hp * 0.05

	# ---- spectating + defeat
	hud.set_local_uid(e1.uid)
	check(hud.spectate_label.visible and hud.player_frame.fighter_uid == e1.uid, "spectating switches frames")
	hud.set_local_uid(0)
	me.kill(e1)
	await process_frame
	hud.refresh()
	check(hud.defeat_overlay.visible, "defeat overlay when local player dies")
	me.revive(1.0)
	hud.refresh()
	check(not hud.defeat_overlay.visible, "defeat overlay hides after revive")

	# ---- Match signals
	var m := Match.new()
	m.name = "Match"
	m.settings = {"mode": "team"}
	root.add_child(m)
	hud.bind(world, m, 0)
	m.announce.emit("第一局 Round 1", 2.0)
	check(hud.announce_banner.current_text() == "第一局 Round 1", "announce banner shows Match announce")
	m.timer_changed.emit(65.0)
	check(hud.top_bar.timer_label.text == "01:05", "round timer from Match", hud.top_bar.timer_label.text)
	m.score_changed.emit({0: 2, 1: 1})
	check(hud.top_bar.left_score.text == "2" and hud.top_bar.right_score.text == "1", "team score from Match")
	check(hud.top_bar.mode_label.text.contains("团体赛"), "mode caption")
	m.match_ended.emit({"winner_team": 0, "mode": "team", "mvp_uid": me.uid, "stats": {}})
	check(hud.result_panel.visible and hud.result_title.text.contains("胜利"), "victory result on match_ended")
	await frames(2)
	check(hud.scoreboard.visible, "scoreboard shown after match end")
	# client-style end: match_node.stats empty, result.stats carries the counters
	hud.bind(world, m, 0)
	m.match_ended.emit({"winner_team": 0, "mode": "team", "mvp_uid": -1,
		"stats": {ally.uid: {"name": ally.display_name, "team": 0, "kills": 7, "deaths": 2, "damage": 12345.0, "healing": 0.0}}})
	await frames(3)
	var found := false
	for t in 2:
		for r in hud.scoreboard.cells[t].size():
			var row: Array = hud.scoreboard.cells[t][r]
			if row[0].visible and str(row[0].text).contains("队友") and row[2].text == "7":
				found = true
	check(found, "scoreboard uses match_ended result.stats (clients)")
	# arena remaining + raid progress formats
	m.score_changed.emit({"mode": "arena", "remaining": [2, 1], "round": 2})
	check(hud.top_bar.extra_label.text.contains("2 : 1"), "arena remaining array shown", hud.top_bar.extra_label.text)
	# raid clear timer
	var m2 := Match.new()
	m2.settings = {"mode": "raid"}
	root.add_child(m2)
	hud.bind(world, m2, 0)
	m2.score_changed.emit({"mode": "raid", "encounter": 0, "encounters": 3, "name_cn": "冰霜巨人", "name_en": "Frost Golem"})
	check(hud.top_bar.extra_label.text.contains("1 / 3") and hud.top_bar.extra_label.text.contains("冰霜巨人"),
		"raid progress 1-based with total", hud.top_bar.extra_label.text)
	m2.timer_changed.emit(83.0)
	for i in 3:
		await process_frame
	check(hud.top_bar.timer_label.text == "01:23", "raid clear timer follows timer_changed", hud.top_bar.timer_label.text)
	check(hud.result_panel.visible == false, "rebind clears the result panel")

	# ---- null world safety
	hud.bind(null, null, 0)
	hud.refresh()
	check(not hud.player_frame.visible and not hud.skill_bar.visible, "hud survives a null world")
	m.queue_free()
	m2.queue_free()
