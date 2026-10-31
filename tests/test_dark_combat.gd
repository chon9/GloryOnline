extends "res://tests/test_core_base.gd"
## Regressions for whiff feedback, animation segments and frame-rate-independent hit-stop.

var impacts := 0

func run_tests() -> void:
	suite_name = "dark_combat"
	await new_world()
	var a := spawn(0, Vector3.ZERO)
	var victim := spawn(1, Vector3(0, 0, -20))
	await sim(0.1)
	var fx := root.get_node("Fx")
	fx.impact_fired.connect(_on_impact)
	fx.clear_all()
	var s := SkillDef.new()
	s.id = &"test.visual_timing"
	s.cast_time = 0.8
	s.anim = &"attack_stab"
	s.steps = [{"t": 0.3, "type": "anim", "anim": "attack_2h"}]
	var runner := a.start_skill(s, 0)
	check(is_equal_approx(a.anim_duration, 0.3), "first clip fits the first animation segment")
	runner.execute_step({"t": 0.3, "type": "anim", "anim": "attack_2h"})
	check(is_equal_approx(a.anim_duration, 0.5), "next clip fits the remaining cast")
	check("anim_duration" in Fighter.SYNC_ALWAYS, "clients receive the host animation duration")
	var attack := {"type": "melee", "range": 3.0, "arc": 120.0, "fx": "hit_heavy", "hit": {"dmg": 1.0}}
	impacts = 0
	var sounds_before := int(fx.sfx_stats["played"])
	runner.execute_step(attack)
	check(impacts == 0 and int(fx.sfx_stats["played"]) == sounds_before, "a whiff produces no impact or impact sound")
	victim.global_position = Vector3(0, 0, -1.5)
	await physics_frame
	var hp_before := victim.hp
	runner.execute_step(attack)
	check(victim.hp < hp_before and impacts == 1, "contact produces damage and exactly one impact")
	fx.impact_fired.disconnect(_on_impact)
	fx.clear_all()
	await test_hitstop_time()
	test_clip_timing()
	await test_lance_grip()

func _on_impact(_pos: Vector3, _level: int, _rel: int) -> void:
	impacts += 1

func test_hitstop_time() -> void:
	var node := Node3D.new()
	var mixer := AnimationPlayer.new()
	node.add_child(mixer)
	root.add_child(node)
	var stop := VfxHitStop.new()
	for fps: int in [30, 60, 144]:
		stop.freeze(node, VfxHitStop.frames_for(3), 0.025)
		var elapsed := 0.0
		while stop.is_frozen(node) and elapsed < 1.0:
			stop.tick(1.0 / fps)
			elapsed += 1.0 / fps
		check(absf(elapsed - 5.0 / 60.0) <= 1.0 / fps + 0.0001, "same heavy hit-stop duration at %d Hz" % fps)
		check(mixer.active and node.position == Vector3.ZERO, "animation and offset restored at %d Hz" % fps)
	node.queue_free()
	await process_frame

func test_clip_timing() -> void:
	var v := CharacterVisual.new()
	v.rig = "anime"
	v.anim_player = AnimationPlayer.new()
	v.add_child(v.anim_player)
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 1.6
	lib.add_animation(&"kk_Melee_1H_Attack_Stab", anim)
	v.anim_player.add_animation_library(&"", lib)
	v.play(&"attack_stab", 2.0, 0.4)
	check(is_equal_approx(v.anim_player.speed_scale, 8.0), "clip duration and attack speed each scale playback once")
	check(v.current_clip == "kk_Melee_1H_Attack_Stab", "stab resolves to a thrust clip")
	v.free()

func test_lance_grip() -> void:
	var v := CharacterVisual.create_for_class("battle_mage", "battle_lance")
	root.add_child(v)
	await process_frame
	v.pose_clip("kk_Melee_2H_Attack_Stab", 0.6, &"attack_stab")
	await process_frame
	v.body._solve_two_hand()
	var weapon: Node3D = v._mounts[0]["node"]
	check(weapon.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.5,
		"Battle Mage thrust points the lance head toward the opponent", str(weapon.global_basis.y.normalized()))
	v.queue_free()
	await process_frame
