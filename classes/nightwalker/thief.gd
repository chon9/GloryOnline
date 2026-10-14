extends ClassKit
## 盗贼 Thief (暗夜系 Nightwalker). Trapper / stealth ambusher: spike, poison, fire, shadow and ice traps,
## 潜行 Stealth and 偷袭 Ambush (double damage + long stun out of stealth). Passive 陷阱精通 Trap
## Proficiency: traps never reveal a stealthed Thief.

const SHADOW_TRAP_META: StringName = &"nw_shadow_trap"
const TRAP_KEY: String = "_nw_trap"    # stashed in trap HITs so hooks can recognise them


func define() -> void:
	id = "thief"
	name_cn = "盗贼"
	name_en = "Thief"
	group_id = "nightwalker"
	role = "control"
	weapon_type = "dagger"
	weapon_name_cn = "匕首"
	weapon_name_en = "Dagger"
	offhand = ""
	model = "thief"
	tint = Color(0.95, 0.75, 0.25)
	famous = "林枫 Lin Feng (前 方锐 Fang Rui) / 鬼迷神疑 Doubtful Demon"
	stats = {"hp": 6500.0, "mp": 1300.0, "mp_regen": 22.0, "patk": 525.0, "matk": 450.0,
		"pdef": 330.0, "mdef": 330.0, "move_speed": 6.6, "jump_velocity": 9.2, "crit": 0.12}

	# ---------------------------------------------------------------- slot 0: basic chain
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.26, &"attack_1h_1", 2.2, ["melee", "combo"],
		[{"t": 0.08, "type": "melee", "range": 2.2, "arc": 110.0, "hit": hit(0.55, {"knockback": 0.8})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.13, "chain": ["atk1", "atk2", "atk3"], "desc": "匕首快划 Quick dagger slash."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.26, &"attack_1h_2", 2.2, ["melee", "combo"],
		[{"t": 0.08, "type": "melee", "range": 2.2, "arc": 110.0, "hit": hit(0.55, {"knockback": 0.8})},
		{"t": 0.08, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.13, "desc": "反手划 Backhand slash."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.4, &"attack_stab", 2.4, ["melee", "finisher"],
		[{"t": 0.13, "type": "melee", "shape": "box", "range": 2.4, "width": 1.3, "hit": hit(0.95, {"knockback": 4.0, "hitstun": 0.45})},
		{"t": 0.13, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.12, "desc": "匕首突刺 Dagger thrust."})

	# ---------------------------------------------------------------- slot 1: launcher trap
	var spike := sk(1, "spike_trap", "陷阱扣", "Spike Trap", 5.0, 40.0, 0.3, &"throw", 8.0,
		["launcher", "cc", "zone", "ranged"],
		[{"t": 0.1, "type": "trap", "trap_id": "thorn", "at": "target", "distance": 4.0, "radius": 1.6, "arm_time": 0.15,
		"duration": 15.0, "max_active": 3, "color": Color(0.85, 0.85, 0.8),
		"hit": hit(1.2, {"launch": 10.0, "knockback": 0.3, TRAP_KEY: true}), "on_trigger_statuses": [st("root", 1.5)]},
		{"t": 0.1, "type": "sfx", "name": "trap_set"}],
		{"cancel_window": 0.12, "desc": "抛出陷阱扣，钢刺弹起挑飞并定身敌人 Toss a spike trap: steel spikes launch and root whoever steps on it."})

	# ---------------------------------------------------------------- slot 2: poison gas trap
	var poison := sk(2, "poison_gas_trap", "毒云陷阱", "Poison Gas Trap", 8.0, 50.0, 0.3, &"throw", 8.0,
		["debuff", "cc", "zone", "aoe", "ranged"],
		[{"t": 0.1, "type": "trap", "trap_id": "poison", "at": "target", "distance": 4.0, "radius": 2.2, "arm_time": 0.3,
		"duration": 15.0, "max_active": 2,
		"hit": hit(0.6, {"stun": 0.8, "hitstun": 0.3, "knockback": 0.0, "element": "poison", TRAP_KEY: true,
		"statuses": [st("poison", 6.0, 1.1)]})},
		{"t": 0.1, "type": "sfx", "name": "trap_set"}, {"t": 0.12, "type": "sfx", "name": "poison"}],
		{"desc": "毒云陷阱：剧毒持续伤害并打断 Poison cloud trap: poison damage over time and a brief stun."})

	# ---------------------------------------------------------------- slot 3: inferno trap
	var inferno := sk(3, "inferno_trap", "火焰陷阱", "Inferno Trap", 9.0, 55.0, 0.3, &"throw", 8.0,
		["aoe", "zone", "debuff", "ranged"],
		[{"t": 0.1, "type": "trap", "trap_id": "fire", "at": "target", "distance": 4.0, "radius": 2.0, "arm_time": 0.3,
		"duration": 15.0, "max_active": 2,
		"hit": hit(1.0, {"knockdown": true, "knockback": 1.5, "element": "fire", TRAP_KEY: true,
		"statuses": [st("burn", 5.0, 1.8)]})},
		{"t": 0.1, "type": "sfx", "name": "trap_set"}, {"t": 0.12, "type": "sfx", "name": "fire_cast"}],
		{"desc": "火焰陷阱：烈焰爆发并持续灼烧 Inferno trap: a burst of flame that keeps burning."})

	# ---------------------------------------------------------------- slot 4: shadow trap (teleport)
	var shadow := sk(4, "shadow_trap", "暗影陷阱", "Shadow Trap", 3.0, 30.0, 0.2, &"cast", 25.0,
		["escape", "zone"],
		[{"t": 0.05, "type": "custom", "method": "shadow_trap"}],
		{"desc": "在脚下布置暗影陷阱；再次施放时瞬移回陷阱处 Place a shadow trap at your feet; cast again to teleport back to it."})

	# ---------------------------------------------------------------- slot 5: stealth
	var stealth := sk(5, "stealth", "潜行", "Stealth", 15.0, 60.0, 0.2, &"cast", 0.0,
		["buff_self", "escape", "defensive"],
		[{"t": 0.0, "type": "vfx", "name": "smoke"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("stealth", 6.0)], "fx": "smoke"}],
		{"desc": "隐身 6 秒，攻击或受伤时现形 Turn invisible for 6 s; attacking or taking damage reveals you."})

	# ---------------------------------------------------------------- slot 6: ambush
	var ambush := sk(6, "ambush", "偷袭", "Ambush", 10.0, 60.0, 0.45, &"attack_stab", 2.4,
		["melee", "cc", "finisher"],
		[{"t": 0.0, "type": "dash", "distance": 1.2, "speed": 14.0, "direction": "target"},
		{"t": 0.15, "type": "custom", "method": "ambush"},
		{"t": 0.15, "type": "sfx", "name": "swing_dagger"}],
		{"cancel_window": 0.15, "desc": "偷袭要害；潜行中发动造成双倍伤害并眩晕 3 秒 Sneak attack; from stealth it deals double damage and stuns for 3 s."})

	# ---------------------------------------------------------------- slot 7: ultimate ice trap
	var ice := sk(7, "ice_trap", "冰霜陷阱", "Ice Trap", 50.0, 180.0, 0.7, &"throw", 9.0,
		["ultimate", "aoe", "cc", "zone", "ranged"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 0.8)]},
		{"t": 0.2, "type": "trap", "trap_id": "ice", "at": "target", "distance": 5.0, "radius": 4.5, "arm_time": 0.2,
		"duration": 8.0, "max_active": 1,
		"hit": hit(2.4, {"element": "ice", "knockback": 0.0, TRAP_KEY: true, "statuses": [st("freeze", 2.0)]})},
		{"t": 0.45, "type": "ground", "at": "target", "radius": 4.5, "duration": 4.0, "tick": 0.5, "visual": "ice",
		"hit": hit(0.25, {"element": "ice", "hitstun": 0.0, "knockback": 0.0, "juggle_cost": 2.0, TRAP_KEY: true,
		"statuses": [st("slow", 1.0, 0.5)]})},
		{"t": 0.2, "type": "sfx", "name": "freeze"}],
		{"desc": "大范围冰霜陷阱：冻结范围内敌人并留下减速寒域 Huge ice trap: freezes everyone inside and leaves a chilling slow field."})

	skills = [atk1, spike, poison, inferno, shadow, stealth, ambush, ice]

	passives = [
		{"name_cn": "陷阱精通", "name_en": "Trap Proficiency",
		"desc": "潜行中可布置陷阱，陷阱触发不会使盗贼现形 Traps can be set while stealthed and never reveal the Thief."},
	]


# ================================================================== hooks
func on_tick(f: Fighter, _delta: float) -> void:
	f.set_meta(&"nw_stealth_left", f.status.remaining(&"stealth") if f.has_status(&"stealth") else 0.0)


func on_hit_taken(f: Fighter, _src: Fighter, _h: Dictionary, dmg: float) -> float:
	# Taking damage reveals the Thief: a later trap hit this step must not restore stealth.
	f.set_meta(&"nw_stealth_left", 0.0)
	return dmg


func on_hit_dealt(f: Fighter, _victim: Fighter, h: Dictionary, _dmg: float) -> void:
	# 陷阱精通 Trap Proficiency: a trap hit does not break the Thief's stealth.
	if bool(h.get(TRAP_KEY, false)):
		var left := float(f.get_meta(&"nw_stealth_left", 0.0))
		if left > 0.05 and not f.has_status(&"stealth"):
			f.add_status(&"stealth", left, 1.0, f)


# ================================================================== custom actions
## 暗影陷阱 Shadow Trap: first cast places the marker trap, the next cast teleports to it.
func shadow_trap(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var w := f.world()
	if w == null:
		return
	# get_meta(key, null) errors on a missing key (a null default counts as "no default"), so guard with has_meta.
	var existing: Variant = f.get_meta(SHADOW_TRAP_META) if f.has_meta(SHADOW_TRAP_META) else null
	if existing != null and not is_instance_valid(existing):
		# The previous trap fired or expired and was freed: drop the stale reference.
		_clear_shadow_trap(f)
		existing = null
	if existing != null and existing is AreaEffect and (existing as AreaEffect).alive:
		var trap := existing as AreaEffect
		CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), tint, 1.0])
		CoreUtil.fx(&"play", [&"dark_burst", f.center(), f.forward(), Color(0.4, 0.2, 0.6), 0.6])
		f.global_position = w.ground_point(trap.global_position)
		f.velocity = Vector3.ZERO
		trap.finish()
		_clear_shadow_trap(f)
		CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), tint, 1.0])
		return
	var before := w.effects.size()
	runner.execute_step({"type": "trap", "trap_id": "dark", "at": "self", "radius": 1.3, "arm_time": 0.5,
		"duration": 25.0, "max_active": 1, "color": Color(0.45, 0.2, 0.7),
		"hit": hit(0.4, {"hitstun": 0.3, "knockback": 0.0, TRAP_KEY: true, "statuses": [st("blind", 2.0)]})})
	for i in range(w.effects.size() - 1, before - 1, -1):
		var e: Variant = w.effects[i]
		if e is AreaEffect and (e as AreaEffect).mode == "trap":
			f.set_meta(SHADOW_TRAP_META, e)
			break
	CoreUtil.fx(&"sfx", [&"trap_set", f.global_position])


func _clear_shadow_trap(f: Fighter) -> void:
	if f.has_meta(SHADOW_TRAP_META):
		f.remove_meta(SHADOW_TRAP_META)


## 偷袭 Ambush: double damage and a 3 s stun when launched from stealth.
func ambush(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var from_stealth := f.has_status(&"stealth") or bool(runner.vars.get("from_stealth", false))
	var h: Dictionary
	if from_stealth:
		h = hit(2.6, {"stun": 2.0, "hitstun": 0.4, "knockback": 0.3, "crit_bonus": 0.2})
	else:
		h = hit(1.3, {"stun": 1.0, "hitstun": 0.4, "knockback": 1.0})
	runner.execute_step({"type": "melee", "range": 2.4, "arc": 120.0, "hit": h, "fx": "hit_heavy"})


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if f.runner != null and skill.id == &"thief.ambush":
		f.runner.vars["from_stealth"] = f.has_status(&"stealth")
