extends ClassKit
## Test / sandbox kit (NOT under res://classes). Exercises most SkillRunner action types.
## Slots: 0 basic chain, 1 launcher, 2 bolt (projectile), 3 meteor (delayed ground AoE), 4 suplex (grab),
## 5 iron will (super armor + shield), 6 spirit wolf (summon, 2 charges), 7 tempest (ultimate).
## Extra skills reachable through get_skill_by_id(): see `extras` at the bottom of define().

var custom_calls: int = 0


func define() -> void:
	id = "test_dummy"
	name_cn = "测试木人"
	name_en = "Test Dummy"
	group_id = "unspecialized"
	role = "melee"
	weapon_type = "lightsaber"
	model = "knight"
	tint = Color(0.9, 0.7, 0.3)
	famous = "测试 / Test"
	stats = {"hp": 8000.0, "mp": 1000.0, "mp_regen": 10.0, "patk": 550.0, "matk": 550.0,
		"pdef": 400.0, "mdef": 400.0, "move_speed": 6.0, "jump_velocity": 9.0}

	var atk1 := sk(0, "atk1", "斩击一", "Slash I", 0.0, 0.0, 0.3, &"attack_1h_1", 2.5, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "hit": hit(1.0)}], {"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"]})
	sk(0, "atk2", "斩击二", "Slash II", 0.0, 0.0, 0.3, &"attack_1h_2", 2.5, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "hit": hit(1.0)}], {"cancel_window": 0.15})
	sk(0, "atk3", "斩击三", "Slash III", 0.0, 0.0, 0.45, &"attack_1h_3", 2.5, ["melee", "finisher"],
		[{"t": 0.15, "type": "melee", "hit": hit(1.4, {"knockdown": true, "knockback": 5.0})}])
	var launcher := sk(1, "rising", "上挑", "Rising Slash", 3.0, 30.0, 0.4, &"attack_2h", 2.5, ["launcher", "melee"],
		[{"t": 0.1, "type": "melee", "hit": hit(1.2, {"launch": 10.0, "knockback": 0.5})}], {"cancel_window": 0.2})
	var bolt := sk(2, "bolt", "光弹", "Light Bolt", 1.0, 20.0, 0.3, &"shoot_1h", 18.0, ["ranged"],
		[{"t": 0.1, "type": "projectile", "speed": 30.0, "range": 20.0, "radius": 0.4, "aim": "target", "visual": "orb",
		"hit": hit(1.0, {"type": "magic"})}])
	var meteor := sk(3, "meteor", "陨石", "Meteor", 6.0, 60.0, 0.5, &"cast", 12.0, ["aoe", "ranged"],
		[{"t": 0.1, "type": "ground", "at": "target", "radius": 3.0, "delay": 0.8, "visual": "fire",
		"hit": hit(2.0, {"type": "magic", "knockdown": true})}])
	var suplex := sk(4, "suplex", "背摔", "Suplex", 5.0, 40.0, 0.4, &"grab", 1.8, ["grab", "melee"],
		[{"t": 0.05, "type": "grab", "range": 1.8, "grab_time": 0.6, "hit": hit(1.5), "throw": {"dir": "back", "force": 6.0}}])
	var iron := sk(5, "iron_will", "霸体", "Iron Will", 12.0, 100.0, 0.2, &"cast", 0.0, ["buff_self", "defensive"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 4.0)], "shield": 0.1}])
	var wolf := sk(6, "wolf", "灵狼", "Spirit Wolf", 10.0, 50.0, 0.4, &"summon", 8.0, ["summon"],
		[{"t": 0.2, "type": "summon", "summon_id": "wolf", "count": 1, "duration": 8.0, "max_active": 2}],
		{"charges": 2})
	var tempest := sk(7, "tempest", "风暴", "Tempest", 30.0, 200.0, 1.4, &"attack_spin", 4.0, ["ultimate", "aoe", "melee"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "dash", "distance": 4.0, "speed": 20.0, "direction": "target"},
		{"t": 0.3, "type": "multi_melee", "shape": "circle", "range": 3.0, "count": 4, "interval": 0.12, "hit": hit(0.6)},
		{"t": 1.0, "type": "ground", "at": "self", "radius": 4.0, "hit": hit(1.5, {"launch": 9.0})}])
	skills = [atk1, launcher, bolt, meteor, suplex, iron, wolf, tempest]

	# ---------------------------------------------------------------- extras (tests / sandbox)
	sk(9, "heal_wave", "治疗波", "Heal Wave", 1.0, 0.0, 0.2, &"heal", 10.0, ["heal"],
		[{"t": 0.0, "type": "heal", "target": "ally_lowest", "radius": 12.0, "amount": 0.2, "hot": {"dur": 3.0, "power": 0.01}}])
	sk(9, "rage", "狂怒", "Rage", 1.0, 0.0, 0.1, &"cast", 0.0, ["buff_self"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("atk_up", 5.0, 0.5)]}])
	sk(9, "venom", "毒雾", "Venom", 1.0, 0.0, 0.1, &"cast", 6.0, ["debuff"],
		[{"t": 0.0, "type": "debuff", "target": "target", "radius": 8.0, "statuses": [st("poison", 3.0, 1.0)]}])
	sk(9, "daze", "眩晕", "Daze", 1.0, 0.0, 0.1, &"cast", 6.0, ["cc"],
		[{"t": 0.0, "type": "debuff", "target": "enemies", "radius": 8.0, "statuses": [st("stun", 1.0)]}])
	sk(9, "provoke", "挑衅", "Provoke", 1.0, 0.0, 0.2, &"taunt", 8.0, ["cc"],
		[{"t": 0.0, "type": "taunt", "radius": 8.0, "duration": 3.0}])
	sk(9, "snare", "陷阱", "Snare Trap", 1.0, 0.0, 0.2, &"throw", 4.0, ["zone"],
		[{"t": 0.0, "type": "trap", "trap_id": "rune", "at": "self", "radius": 1.5, "arm_time": 0.3, "duration": 10.0,
		"max_active": 2, "hit": hit(1.0), "on_trigger_statuses": [st("root", 2.0)]}])
	sk(9, "vortex", "漩涡", "Vortex", 1.0, 0.0, 0.3, &"cast", 7.0, ["cc"],
		[{"t": 0.0, "type": "pull", "radius": 8.0, "strength": 10.0}])
	sk(9, "shadow_step", "影步", "Shadow Step", 1.0, 0.0, 0.1, &"dash", 8.0, ["gap_closer"],
		[{"t": 0.0, "type": "blink", "to": "behind_target", "distance": 10.0}])
	sk(9, "charge", "冲锋", "Charge", 1.0, 0.0, 0.2, &"dash", 6.0, ["gap_closer"],
		[{"t": 0.0, "type": "dash", "distance": 6.0, "speed": 24.0, "direction": "forward", "through_enemies": true, "hit": hit(0.8)}])
	sk(9, "slam", "跃击", "Leap Slam", 1.0, 0.0, 0.7, &"leap", 8.0, ["gap_closer", "aoe"],
		[{"t": 0.0, "type": "leap", "to": "target", "distance": 8.0, "height": 3.0, "duration": 0.5,
		"land": {"radius": 2.5, "hit": hit(1.2)}}])
	sk(9, "ray", "光束", "Ray", 1.0, 0.0, 0.2, &"channel", 12.0, ["ranged"],
		[{"t": 0.0, "type": "beam", "length": 12.0, "width": 1.0, "duration": 0.6, "tick": 0.15, "hit": hit(0.3, {"type": "magic", "hitstun": 0.1})}])
	sk(9, "purify", "净化", "Purify", 1.0, 0.0, 0.1, &"heal", 0.0, ["heal"],
		[{"t": 0.0, "type": "cleanse", "target": "self"}])
	sk(9, "ritual", "仪式", "Ritual", 1.0, 0.0, 0.1, &"cast", 0.0, [],
		[{"t": 0.0, "type": "custom", "method": "ritual", "args": {"n": 2}}, {"t": 0.0, "type": "anim", "anim": "taunt"},
		{"t": 0.0, "type": "sfx", "name": "ding"}, {"t": 0.0, "type": "bogus_action_xyz"}])
	sk(9, "two_hits", "二段", "Two Hits", 1.0, 0.0, 0.8, &"attack", 2.5, [],
		[{"t": 0.1, "type": "melee", "hit": hit(0.5, {"hitstun": 0.0, "knockback": 0.0})},
		{"t": 0.6, "type": "melee", "hit": hit(0.5, {"hitstun": 0.0, "knockback": 0.0})}])
	sk(9, "sky_cut", "空斩", "Sky Cut", 1.0, 0.0, 0.3, &"aerial", 2.5, [],
		[{"t": 0.0, "type": "melee", "hit": hit(1.0)}], {"requires": {"airborne": true}})
	sk(9, "hop", "跳跃", "Hop", 1.0, 0.0, 0.3, &"jump", 0.0, [],
		[{"t": 0.0, "type": "launch_self", "vertical": 8.0}])
	sk(9, "holy_ground", "圣域", "Holy Ground", 1.0, 0.0, 0.2, &"cast", 0.0, ["zone", "heal"],
		[{"t": 0.0, "type": "ground", "at": "self", "radius": 4.0, "duration": 2.0, "tick": 0.5, "affects": "allies",
		"visual": "holy", "ally_effect": {"heal": 0.02}}])
	sk(9, "lance", "地刺", "Earth Lance", 1.0, 0.0, 0.2, &"cast", 8.0, ["aoe"],
		[{"t": 0.0, "type": "ground", "at": "self", "shape": "line", "length": 8.0, "width": 1.5, "hit": hit(1.0)}])

	summons = {
		"wolf": {
			"name_cn": "灵狼", "name_en": "Spirit Wolf", "model": "knight", "weapon_type": "claws", "scale": 0.7,
			"stats": {"hp": 1500.0, "patk": 300.0, "pdef": 200.0, "mdef": 200.0, "move_speed": 7.0},
			"skills": [sk(0, "wolf_bite", "撕咬", "Bite", 1.2, 0.0, 0.4, &"attack", 2.0, ["melee"],
				[{"t": 0.15, "type": "melee", "range": 2.0, "hit": hit(0.8)}])],
		},
	}
	passives = [{"name_cn": "测试被动", "name_en": "Test Passive", "desc": "无 None"}]


## Custom action target (type "custom", method "ritual").
func ritual(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	custom_calls += int(args.get("n", 1))
	runner.vars["ritual"] = true
	f.stat_bonus["dmg_out"] = 0.0
