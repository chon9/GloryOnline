extends ClassKit
## 狂剑士 Berserker (剑士系 Swordsman). Greatsword bruiser that trades HP for damage.
## Passives: 血气唤醒 Blood Awakening (attack rises as HP drops) and 嗜血狂战 Bloodthirsty Fight
## (while Berserk: skills grant brief super armor, hits lifesteal). 暴走 Enrage toggles Berserk for 12 s
## (drains HP; Backwards Slash gains reach, Collapsing Mountain gains super armor).

const KU := preload("res://classes/_kit_util.gd")
const META_BERSERK: StringName = &"berserker_rage_left"
const AWAKEN_MAX: float = 0.4          # +40% patk at 0 HP (linear with missing HP)
const BERSERK_DRAIN: float = 0.006     # fraction of max HP per second while Berserk
const BERSERK_DRAIN_FLOOR: float = 0.2 # drain never takes HP below 20%
const BERSERK_LIFESTEAL: float = 0.05
const BERSERK_ARMOR: float = 0.6
const BERSERK_REACH: float = 1.5
## Berserk lives as long as the Enrage self buff; status.clear_all (reset_for_round, dispels) ends it.
const BERSERK_STATUS: StringName = &"atk_up"


func define() -> void:
	id = "berserker"
	name_cn = "狂剑士"
	name_en = "Berserker"
	group_id = "swordsman"
	group_cn = "剑士系"
	group_en = "Swordsman"
	role = "melee"
	weapon_type = "greatsword"
	weapon_name_cn = "大剑"
	weapon_name_en = "Greatsword"
	offhand = ""
	model = "berserker"
	tint = Color(0.9, 0.12, 0.12)
	famous = "孙哲平 Sun Zheping / 落花狼藉 Blossoming Chaos / Burial Blossoms"
	stats = {"hp": 8200.0, "mp": 1100.0, "mp_regen": 18.0, "patk": 670.0, "matk": 300.0,
		"pdef": 480.0, "mdef": 360.0, "move_speed": 6.0, "jump_velocity": 8.8, "weight": 1.2,
		"cast_speed": 1.0, "atk_speed": 0.85, "crit": 0.10}

	var c := tint
	var blood := Color(0.95, 0.08, 0.12)
	# ------------------------------------------------------------ 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.45, &"attack_2h", 3.0, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.18, "type": "melee", "range": 3.0, "arc": 130.0, "color": c, "hit": hit(0.75, {"knockback": 1.5, "hitstun": 0.4})}],
		{"cancel_window": 0.18, "chain": ["atk1", "atk2", "atk3"], "desc": "大剑横斩 Heavy horizontal cleave."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.5, &"attack_slam", 3.0, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.2, "type": "melee", "range": 3.0, "arc": 110.0, "color": c, "hit": hit(0.8, {"knockback": 1.5, "hitstun": 0.45})}],
		{"cancel_window": 0.2, "desc": "下劈 Overhead chop."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.6, &"attack_spin", 3.0, ["melee", "finisher", "aoe"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.25, "type": "melee", "shape": "circle", "range": 3.0, "color": c,
		"hit": hit(1.05, {"knockback": 5.0, "hitstun": 0.6})}],
		{"cancel_window": 0.2, "desc": "回旋斩 Spinning cleave that knocks back."})

	# ------------------------------------------------------------ 1: Lv1 launcher
	var backslash := sk(1, "backwards_slash", "倒斩", "Backwards Slash", 4.0, 30.0, 0.45, &"attack_2h", 2.8,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.15, "type": "custom", "method": "rage_step", "args": {"reach": BERSERK_REACH, "step":
			{"type": "melee", "range": 2.8, "arc": 120.0, "color": c,
			"hit": hit(1.2, {"launch": 12.5, "knockback": 0.5, "hitstun": 0.6})}}},
		{"t": 0.15, "type": "vfx", "name": "launch_burst", "at": "target"}],
		{"cancel_window": 0.25, "desc": "Lv1 最高浮空的上挑斩，暴走时距离更长 Launcher with the highest knock-up; longer reach while Berserk."})

	# ------------------------------------------------------------ 2: Collapsing Mountain
	var mountain := sk(2, "collapsing_mountain", "崩山击", "Collapsing Mountain", 8.0, 60.0, 0.85, &"leap", 6.0,
		["gap_closer", "aoe", "melee"],
		[{"t": 0.0, "type": "custom", "method": "berserk_armor", "args": {"dur": 0.9}},
		{"t": 0.0, "type": "leap", "to": "target", "distance": 6.0, "height": 3.0, "duration": 0.5,
		"land": {"radius": 3.2, "fx": "explosion", "hit": hit(1.9, {"knockdown": true, "knockback": 3.0})}},
		{"t": 0.45, "type": "anim", "anim": "attack_slam"},
		{"t": 0.5, "type": "sfx", "name": "stomp"}],
		{"cancel_window": 0.2, "desc": "跃起砸地冲击波，暴走时霸体 Leaping ground slam shockwave; super armor while Berserk."})

	# ------------------------------------------------------------ 3: Gore Cross
	var gore := sk(3, "gore_cross", "十字斩", "Gore Cross", 7.0, 45.0, 0.55, &"attack_2h", 3.0,
		["melee", "combo", "debuff"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.15, "type": "melee", "range": 3.0, "arc": 120.0, "color": blood,
		"hit": hit(0.8, {"hitstun": 0.45, "knockback": 0.5, "statuses": [st("bleed", 5.0, 0.6)]})},
		{"t": 0.32, "type": "anim", "anim": "attack_slam"},
		{"t": 0.32, "type": "melee", "range": 3.0, "arc": 120.0, "color": blood,
		"hit": hit(0.9, {"hitstun": 0.5, "knockback": 3.0, "statuses": [st("bleed", 5.0, 0.6)]})}],
		{"cancel_window": 0.2, "desc": "X形十字斩，造成流血 X-shaped slash that inflicts Bleed."})

	# ------------------------------------------------------------ 4: Blood Sword (ranged poke)
	var blood_sword := sk(4, "blood_sword", "血剑", "Blood Sword", 6.0, 30.0, 0.45, &"throw", 14.0,
		["ranged", "debuff"],
		[{"t": 0.0, "type": "custom", "method": "blood_price", "args": {"frac": 0.03}},
		{"t": 0.0, "type": "vfx", "name": "dark_burst", "color": blood, "scale": 0.5},
		{"t": 0.2, "type": "projectile", "visual": "blood", "speed": 28.0, "range": 16.0, "radius": 0.45, "aim": "target",
		"color": blood, "scale": 1.2, "sfx": "blood",
		"hit": hit(1.4, {"knockback": 2.0, "statuses": [st("bleed", 3.0, 1.0)]})}],
		{"cancel_window": 0.15, "desc": "割手放出血箭（消耗3%生命） Cuts own hand (3% HP) to fire a blood arrow."})

	# ------------------------------------------------------------ 5: Soul-Devouring Crimson Grip
	var grip := sk(5, "crimson_grip", "噬魂血手", "Soul-Devouring Crimson Grip", 12.0, 70.0, 0.9, &"grab", 6.0,
		["grab", "cc", "aoe", "melee"],
		[{"t": 0.0, "type": "sfx", "name": "grab"},
		{"t": 0.1, "type": "vfx", "name": "dark_burst", "color": blood, "scale": 1.5},
		{"t": 0.15, "type": "pull", "radius": 6.5, "strength": 12.0, "color": blood,
		"hit": hit(0.6, {"hitstun": 0.7})},
		{"t": 0.4, "type": "grab", "range": 2.4, "arc": 160.0, "grab_time": 0.6,
		"hit": hit(1.4, {"lifesteal": 0.3}), "throw": {"dir": "up", "force": 7.0}}],
		{"desc": "血手将周围敌人拉近并抓取吸血 Crimson hand pulls nearby foes in, then grabs and drains one."})

	# ------------------------------------------------------------ 6: Enrage (Berserk)
	var enrage := sk(6, "enrage", "暴走", "Enrage (Berserk)", 30.0, 50.0, 0.4, &"taunt", 0.0,
		["buff_self"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("atk_up", 12.0, 0.2), st("haste", 12.0, 0.15)],
		"color": blood},
		{"t": 0.0, "type": "custom", "method": "enter_berserk", "args": {"dur": 12.0}},
		{"t": 0.0, "type": "sfx", "name": "growl"}],
		{"cancel_window": 0.3, "desc": "暴走12秒：攻击+20%、移速+15%，持续流失生命 Berserk 12 s: +20% attack, +15% speed, drains HP."})

	# ------------------------------------------------------------ 7: ultimate
	var storm := sk(7, "crimson_storm", "怒血狂涛", "Crimson Storm", 70.0, 220.0, 1.6, &"attack_slam", 5.0,
		["ultimate", "aoe", "melee", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash", "color": blood},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.8)]},
		{"t": 0.35, "type": "ground", "at": "self", "radius": 4.0, "visual": "blood", "color": blood,
		"hit": hit(1.1, {"launch": 8.0, "knockback": 1.0})},
		{"t": 0.75, "type": "ground", "at": "self", "radius": 5.5, "visual": "blood", "color": blood,
		"hit": hit(1.3, {"launch": 9.0, "knockback": 1.0})},
		{"t": 1.1, "type": "anim", "anim": "attack_slam"},
		{"t": 1.15, "type": "ground", "at": "self", "radius": 7.0, "visual": "blood", "color": blood,
		"hit": hit(1.6, {"launch": 6.0, "knockdown": true, "knockback": 9.0, "statuses": [st("bleed", 6.0, 1.2)]})},
		{"t": 1.15, "type": "sfx", "name": "ultimate_release"}],
		{"desc": "Lv70 大招：三重血浪爆发 Three expanding blood explosions around the Berserker."})

	skills = [atk1, backslash, mountain, gore, blood_sword, grip, enrage, storm]
	passives = [
		{"name_cn": "血气唤醒", "name_en": "Blood Awakening",
		"desc": "生命越低攻击越高（最高+40%） Attack rises as HP drops (up to +40%)."},
		{"name_cn": "嗜血狂战", "name_en": "Bloodthirsty Fight",
		"desc": "暴走时施放技能获得短暂霸体，伤害吸血5% While Berserk, skills grant brief super armor and 5% lifesteal."},
	]


# ---------------------------------------------------------------- helpers
func is_berserk(f: Fighter) -> bool:
	return float(f.get_meta(META_BERSERK, 0.0)) > 0.0 and f.has_status(BERSERK_STATUS)


## Additive stat_bonus write: only this kit's own share (stored in meta) is replaced.
func _set_bonus(f: Fighter, key: String, meta: StringName, want: float) -> void:
	KU.set_bonus_share(f, key, meta, want)


# ---------------------------------------------------------------- hooks
func on_spawn(f: Fighter) -> void:
	f.set_meta(META_BERSERK, 0.0)


func on_tick(f: Fighter, delta: float) -> void:
	# Blood Awakening: patk bonus scales with missing HP.
	var missing := 1.0 - clampf(f.hp / maxf(1.0, f.max_hp), 0.0, 1.0)
	_set_bonus(f, "patk", &"berserker_awaken", AWAKEN_MAX * missing)
	var left := float(f.get_meta(META_BERSERK, 0.0))
	# Berserk is tied to its own status; reset_for_round (status.clear_all) ends it.
	if left > 0.0 and not f.has_status(BERSERK_STATUS):
		left = 0.0
		f.set_meta(META_BERSERK, 0.0)
	if left > 0.0:
		left = maxf(0.0, left - delta)
		f.set_meta(META_BERSERK, left)
		var floor_hp := f.max_hp * BERSERK_DRAIN_FLOOR
		if f.hp > floor_hp:
			f.hp = maxf(floor_hp, f.hp - f.max_hp * BERSERK_DRAIN * delta)


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.slot != 0 and is_berserk(f):
		f.add_status(&"super_armor", BERSERK_ARMOR, 1.0, f)


func on_hit_dealt(f: Fighter, _victim: Fighter, _h: Dictionary, dmg: float) -> void:
	if dmg > 0.0 and is_berserk(f):
		f.heal(dmg * BERSERK_LIFESTEAL, f)


func on_death(f: Fighter, _killer: Fighter) -> void:
	f.set_meta(META_BERSERK, 0.0)
	_set_bonus(f, "patk", &"berserker_awaken", 0.0)


# ---------------------------------------------------------------- custom actions
## Runs args.step; melee reach is extended by args.reach while Berserk.
func rage_step(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var step: Dictionary = (args.get("step", {}) as Dictionary).duplicate(true)
	if is_berserk(f):
		step["range"] = float(step.get("range", 2.5)) + float(args.get("reach", BERSERK_REACH))
		step["color"] = Color(0.95, 0.08, 0.12)
	runner.execute_step(step)


## Super armor for args.dur seconds, only while Berserk.
func berserk_armor(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	if is_berserk(f):
		f.add_status(&"super_armor", float(args.get("dur", 0.8)), 1.0, f)


## Pays args.frac of max HP (never lethal).
func blood_price(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	var cost := f.max_hp * float(args.get("frac", 0.03))
	f.hp = maxf(1.0, f.hp - cost)


func enter_berserk(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	f.set_meta(META_BERSERK, float(args.get("dur", 12.0)))
	CoreUtil.fx(&"play", [&"buff_aura", f.global_position, f.forward(), Color(0.95, 0.08, 0.12), 1.4])
