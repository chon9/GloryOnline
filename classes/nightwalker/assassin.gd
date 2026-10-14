extends ClassKit
## 刺客 Assassin (暗夜系 Nightwalker). Dual-sword burst assassin: blinks behind targets, back-stab bonus
## (暗杀 Assassination), vital-point marks (致命要害 Vitals Strike), double jump (空跃 Air Jump) and the
## Lv75 ordered chain 裂/杀/闪/瞬/灭.

const BACK_BONUS: float = 0.20        # Assassination: extra damage from behind
const MARK_BONUS: float = 0.15        # Vitals Strike: extra damage on a marked target
const LIFE_COST: float = 0.08         # Life-Risking Strike: fraction of own max hp burned


func define() -> void:
	id = "assassin"
	name_cn = "刺客"
	name_en = "Assassin"
	group_id = "nightwalker"
	role = "melee"
	weapon_type = "dual_swords"
	weapon_name_cn = "双剑"
	weapon_name_en = "Dual Swords"
	offhand = ""
	model = "assassin"
	tint = Color(0.85, 0.15, 0.3)
	famous = "杨聪 Yang Cong / 风景杀 Scene Killer / 双剑 Dancing Shadows"
	stats = {"hp": 7000.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 620.0, "matk": 400.0,
		"pdef": 340.0, "mdef": 300.0, "move_speed": 6.6, "jump_velocity": 9.5, "crit": 0.15}

	# ---------------------------------------------------------------- slot 0: basic chain
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.28, &"attack_1h_1", 2.4, ["melee", "combo"],
		[{"t": 0.08, "type": "melee", "range": 2.3, "arc": 110.0, "hit": hit(0.62, {"knockback": 0.8})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.14, "chain": ["atk1", "atk2", "atk3", "atk4"], "desc": "双剑快斩 Quick twin-blade slash."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.28, &"attack_1h_2", 2.4, ["melee", "combo"],
		[{"t": 0.08, "type": "melee", "range": 2.3, "arc": 110.0, "hit": hit(0.62, {"knockback": 0.8})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.14, "desc": "反手斩 Backhand slash."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.34, &"attack_dual", 2.4, ["melee", "combo"],
		[{"t": 0.08, "type": "multi_melee", "range": 2.3, "arc": 110.0, "count": 2, "interval": 0.1,
		"hit": hit(0.4, {"knockback": 0.5, "juggle_cost": 6.0})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.16, "desc": "双剑交错两连斩 Crossing double slash."})
	sk(0, "atk4", "普攻·四", "Basic Attack IV", 0.0, 0.0, 0.42, &"attack_stab", 2.6, ["melee", "finisher"],
		[{"t": 0.14, "type": "melee", "shape": "box", "range": 2.6, "width": 1.4, "hit": hit(1.0, {"knockback": 4.5, "hitstun": 0.45})},
		{"t": 0.14, "type": "sfx", "name": "swing_blade"}],
		{"cancel_window": 0.12, "desc": "突刺收招 Thrusting finisher."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var leaping := sk(1, "leaping_blade", "跳刀", "Leaping Blade", 4.0, 40.0, 0.45, &"attack_2h", 3.2,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "dash", "distance": 1.8, "speed": 18.0, "direction": "target"},
		{"t": 0.12, "type": "melee", "range": 2.5, "arc": 120.0, "hit": hit(1.3, {"launch": 10.5, "knockback": 0.6})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "target"},
		{"t": 0.14, "type": "launch_self", "vertical": 6.5},
		{"t": 0.12, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.25, "desc": "跃起上挑，将敌人挑飞并随之升空 Leaping upward slash that launches the target."})

	# ---------------------------------------------------------------- slot 2: blink + stab (mark)
	var tele := sk(2, "teleporting_stab", "瞬身刺", "Teleporting Stab", 7.0, 60.0, 0.4, &"attack_stab", 10.0,
		["gap_closer", "melee", "combo", "debuff"],
		[{"t": 0.0, "type": "blink", "to": "behind_target", "distance": 10.0},
		{"t": 0.08, "type": "melee", "range": 2.3, "arc": 120.0,
		"hit": hit(1.5, {"hitstun": 0.55, "knockback": 0.6, "statuses": [st("mark", 6.0)]})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.2, "desc": "瞬移到敌人身后刺击并标记要害 Blink behind the target, stab and mark its vital point."})

	# ---------------------------------------------------------------- slot 3: fast dash with two auras
	var shining := sk(3, "shining_cut", "弧光闪", "Shining Cut", 6.0, 50.0, 0.45, &"dash", 9.0,
		["gap_closer", "melee", "combo", "aoe"],
		[{"t": 0.0, "type": "vfx", "name": "slash_arc"},
		{"t": 0.0, "type": "ground", "at": "target", "shape": "line", "length": 9.0, "width": 1.4, "visual": "wind",
		"color": Color(1.0, 0.4, 0.5), "hit": hit(0.6, {"hitstun": 0.4, "knockback": 0.3})},
		{"t": 0.02, "type": "dash", "distance": 9.0, "speed": 34.0, "direction": "target", "through_enemies": true,
		"hit": hit(1.0, {"hitstun": 0.5, "knockback": 0.5})},
		{"t": 0.02, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.15, "desc": "两道交叉剑气伴随高速突进穿过敌人 Two crossing blade auras and a lightning-fast dash through enemies."})

	# ---------------------------------------------------------------- slot 4: back stab, armor break
	var cut := sk(4, "cut_throat", "割喉", "Cut Throat", 9.0, 60.0, 0.5, &"attack_stab", 2.2,
		["melee", "cc", "finisher"],
		[{"t": 0.0, "type": "dash", "distance": 1.0, "speed": 14.0, "direction": "target"},
		{"t": 0.14, "type": "custom", "method": "cut_throat"},
		{"t": 0.14, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.15, "desc": "无视霸体的割喉，背后命中造成重创并眩晕 Armor-breaking neck slash; from behind it deals heavy damage and stuns."})

	# ---------------------------------------------------------------- slot 5: rapid stabs, long end lag
	var storm := sk(5, "blade_storm", "刺刃风暴", "Blade Storm", 10.0, 70.0, 1.1, &"attack_stab", 2.5,
		["melee", "combo", "finisher"],
		[{"t": 0.05, "type": "anim", "anim": "attack_dual", "speed": 1.6},
		{"t": 0.05, "type": "multi_melee", "range": 2.4, "arc": 100.0, "count": 8, "interval": 0.07,
		"hit": hit(0.22, {"hitstun": 0.3, "knockback": 0.6, "juggle_cost": 4.0})},
		{"t": 0.65, "type": "melee", "range": 2.6, "arc": 100.0, "hit": hit(0.5, {"knockback": 6.0, "hitstun": 0.5})},
		{"t": 0.65, "type": "vfx", "name": "slash_arc", "at": "forward", "scale": 1.3},
		{"t": 0.05, "type": "sfx", "name": "swing_spin"}],
		{"desc": "连续快刺把敌人推开，收招硬直较长 Flurry of stabs that pushes the target back; long end lag."})

	# ---------------------------------------------------------------- slot 6: hp for true damage
	var risk := sk(6, "life_risking_strike", "舍命一击", "Life-Risking Strike", 14.0, 0.0, 0.5, &"attack_slam", 2.4,
		["melee", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "dark_burst", "color": Color(0.9, 0.1, 0.15)},
		{"t": 0.18, "type": "custom", "method": "life_risking", "args": {"cost": LIFE_COST}},
		{"t": 0.18, "type": "sfx", "name": "swing_blade"}],
		{"cancel_window": 0.15, "requires": {"hp_above": 0.15},
		"desc": "燃烧自身生命，造成等量真实伤害 Burn your own HP to deal the same amount as true damage."})

	# ---------------------------------------------------------------- slot 7: Lv75 ordered chain
	var ult := sk(7, "rend_kill_dodge_flash_exterminate", "裂/杀/闪/瞬/灭", "Rend / Kill / Dodge / Flash / Exterminate",
		60.0, 200.0, 1.9, &"attack_dual", 6.0, ["ultimate", "melee", "gap_closer", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.05, "type": "dash", "distance": 6.0, "speed": 30.0, "direction": "target"},
		# 裂 Rend
		{"t": 0.25, "type": "anim", "anim": "attack_1h_1"},
		{"t": 0.25, "type": "melee", "range": 2.4, "arc": 120.0,
		"hit": hit(0.8, {"hitstun": 0.6, "knockback": 0.3, "statuses": [st("bleed", 4.0, 1.5)]})},
		# 杀 Kill
		{"t": 0.5, "type": "anim", "anim": "attack_stab"},
		{"t": 0.5, "type": "melee", "range": 2.6, "arc": 100.0, "hit": hit(1.0, {"hitstun": 0.6, "knockback": 0.3})},
		# 闪 Dodge
		{"t": 0.72, "type": "blink", "to": "back", "distance": 3.0},
		# 瞬 Flash
		{"t": 0.85, "type": "anim", "anim": "dash"},
		{"t": 0.85, "type": "dash", "distance": 7.0, "speed": 40.0, "direction": "target", "through_enemies": true,
		"hit": hit(0.9, {"hitstun": 0.7, "knockback": 0.3})},
		# 灭 Exterminate
		{"t": 1.3, "type": "blink", "to": "behind_target", "distance": 8.0},
		{"t": 1.35, "type": "anim", "anim": "attack_spin"},
		{"t": 1.35, "type": "melee", "shape": "circle", "range": 2.8, "hit": hit(1.6, {"launch": 11.0, "knockback": 1.0})},
		{"t": 1.35, "type": "vfx", "name": "launch_burst", "at": "target", "scale": 1.5},
		{"t": 1.35, "type": "sfx", "name": "ultimate_release"}],
		{"desc": "按顺序施展裂、杀、闪、瞬、灭五式连斩 The ordered five-form chain: Rend, Kill, Dodge, Flash, Exterminate."})

	skills = [atk1, leaping, tele, shining, cut, storm, risk, ult]

	passives = [
		{"name_cn": "空跃", "name_en": "Air Jump", "desc": "空中可再跳一次 Jump once more while airborne (double jump)."},
		{"name_cn": "暗杀", "name_en": "Assassination", "desc": "从背后攻击额外造成 20% 伤害 +20% damage on attacks from behind."},
		{"name_cn": "致命要害", "name_en": "Vitals Strike",
		"desc": "对被标记要害的敌人额外造成 15% 伤害 +15% damage to targets whose vital point you marked."},
	]


# ================================================================== hooks
func on_spawn(f: Fighter) -> void:
	f.set_meta(&"nw_air_jump", false)


func on_tick(f: Fighter, _delta: float) -> void:
	# 空跃 Air Jump: a second jump while airborne and free to act.
	if f.is_on_floor():
		if f.get_meta(&"nw_air_jump", false):
			f.set_meta(&"nw_air_jump", false)
		return
	if f.input != null and f.input.jump and f.state == Fighter.State.AIR and f.can_act() \
			and not f.get_meta(&"nw_air_jump", false) and not f.has_status(&"root"):
		f.set_meta(&"nw_air_jump", true)
		f.velocity.y = f.get_stat("jump_velocity") * 0.9
		CoreUtil.fx(&"play", [&"blink", f.global_position, f.forward(), tint, 0.6])
		CoreUtil.fx(&"sfx", [&"jump", f.global_position])


func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, dmg: float) -> void:
	if dmg <= 0.0 or victim == null or not victim.is_alive() or bool(h.get("true_damage", false)):
		return
	var bonus := 0.0
	if Combat.is_back_attack(victim, f.global_position):
		bonus += BACK_BONUS
	if victim.has_status(&"mark") and victim.status.source(&"mark") == f:
		bonus += MARK_BONUS
	if bonus > 0.0:
		victim.take_dot_damage(dmg * bonus, f, &"assassination")


# ================================================================== custom actions
func _front_target(f: Fighter, reach: float) -> Fighter:
	var t := f.get_target()
	if t != null and f.is_enemy(t) and t.global_position.distance_to(f.global_position) <= reach:
		return t
	var w := f.world()
	return w.nearest_enemy(f, reach) if w != null else null


## 割喉 Cut Throat: always armor-breaking; from behind it hits much harder, bleeds and stuns.
func cut_throat(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var t := _front_target(f, 3.5)
	var behind := t != null and Combat.is_back_attack(t, f.global_position)
	var h: Dictionary
	if behind:
		h = hit(2.2, {"armor_break": true, "stun": 1.2, "hitstun": 0.5, "knockback": 0.3,
			"statuses": [st("bleed", 4.0, 1.5)]})
	else:
		h = hit(1.2, {"armor_break": true, "hitstun": 0.5, "knockback": 1.5})
	runner.execute_step({"type": "melee", "range": 2.4, "arc": 130.0, "hit": h, "fx": "slash_arc"})


## 舍命一击 Life-Risking Strike: lose `cost` x max hp, the strike deals that much as true damage.
func life_risking(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var cost := minf(f.max_hp * float(args.get("cost", LIFE_COST)), f.hp - 1.0)
	if cost <= 0.0:
		return
	f.hp -= cost
	CoreUtil.fx(&"damage_number", [f.center() + Vector3.UP, cost, &"true"])
	var atk := maxf(1.0, f.get_stat("patk"))
	var mult := cost / atk
	# Equal exchange: strip the generic back-attack bonus (crit is suppressed via crit_bonus).
	var t := _front_target(f, 2.5)
	if t != null and Combat.is_back_attack(t, f.global_position):
		mult /= Combat.BACK_MULT
	var h := hit(mult, {"true_damage": true, "crit_bonus": -1.0, "hitstun": 0.5, "knockback": 3.0})
	runner.execute_step({"type": "melee", "range": 2.5, "arc": 110.0, "max_targets": 1, "hit": h, "fx": "hit_heavy"})
