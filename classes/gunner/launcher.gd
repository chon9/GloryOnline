extends ClassKit
## 枪炮师 Launcher (枪手系 Gunner). Hand cannon artillery with the longest range in the game: shells, missiles,
## lasers and a satellite strike. Heavy recoil shoves the gunner back (and up when airborne).
## Famous: 苏沐橙 Su Mucheng / 沐雨橙风 Dancing Rain / 吞日 Devouring Sun.

const GU := preload("res://classes/gunner/_gunner_util.gd")
const KU := preload("res://classes/_kit_util.gd")

const RECOIL_UP: float = 2.6
const RECOIL_BACK: float = 2.5
const RECOIL_CAP: float = 3.5
const LONG_RANGE: float = 12.0
const SHELL := Color(1.0, 0.6, 0.15)
const LASER := Color(1.0, 0.8, 0.45)


func define() -> void:
	id = "launcher"
	name_cn = "枪炮师"
	name_en = "Launcher"
	group_id = "gunner"
	group_cn = "枪手系"
	group_en = "Gunner"
	role = "ranged"
	weapon_type = "hand_cannon"
	weapon_name_cn = "手炮"
	weapon_name_en = "Hand Cannon"
	offhand = ""
	model = "launcher"
	tint = Color(1.0, 0.6, 0.1)
	famous = "苏沐橙 Su Mucheng / 沐雨橙风 Dancing Rain / 吞日 Devouring Sun"
	stats = {"hp": 7000.0, "mp": 1400.0, "mp_regen": 22.0, "patk": 720.0, "matk": 350.0,
		"pdef": 300.0, "mdef": 350.0, "move_speed": 5.8, "jump_velocity": 8.8, "weight": 1.1,
		"cast_speed": 1.0, "atk_speed": 0.95}

	# ---------------------------------------------------------------- slot 0: cannon shots (single shot, slow)
	var shell1 := sk(0, "cannon_1", "普攻·炮击", "Cannon Shot", 0.0, 0.0, 0.75, &"shoot_2h", 22.0, ["ranged", "combo"],
		[_shell(0.18, 0.4, 2.5), {"t": 0.18, "type": "sfx", "name": "cannon"}],
		{"cancel_window": 0.12, "chain": ["cannon_1", "cannon_2"],
		"desc": "手炮单发炮弹，落点小范围爆炸。 Single cannon shell with a small blast."})
	sk(0, "cannon_2", "普攻·重炮", "Heavy Cannon Shot", 0.0, 0.0, 0.85, &"shoot_2h", 22.0, ["ranged", "combo"],
		[_shell(0.22, 0.5, 4.0), {"t": 0.22, "type": "sfx", "name": "cannon"}],
		{"cancel_window": 0.12, "desc": "装填后的重炮，击退更强。 Heavier follow-up shell with stronger knockback."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var swing := sk(1, "swing", "拔击", "Swing", 4.0, 30.0, 0.45, &"attack_2h", 2.4, ["launcher", "melee", "combo"],
		[{"t": 0.15, "type": "melee", "range": 2.4, "arc": 140.0, "fx": "slash_arc",
		"hit": hit(1.2, {"launch": 10.0, "knockback": 1.5, "hitstun": 0.5})},
		{"t": 0.15, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.2},
		{"t": 0.15, "type": "sfx", "name": "hit_heavy"}],
		{"cancel_window": 0.2, "desc": "抡起手炮上挑，把贴身的敌人砸上浮空。 Upward cannon swing that launches a close enemy."})

	# ---------------------------------------------------------------- slot 2: anti-tank missiles
	var atm := sk(2, "anti_tank_missile", "反坦克炮", "Anti-Tank Missile", 7.0, 45.0, 0.6, &"shoot_2h", 22.0,
		["ranged", "cc", "combo"],
		[_missile(0.12), _missile(0.27), _missile(0.42), {"t": 0.12, "type": "sfx", "name": "cannon"},
		{"t": 0.42, "type": "sfx", "name": "cannon"}],
		{"cancel_window": 0.15, "desc": "连射三发反坦克炮弹，每发造成短暂眩晕。 Three anti-tank shells, each with a brief stun."})

	# ---------------------------------------------------------------- slot 3: Lv30 laser
	var laser := sk(3, "laser_rifle", "激光炮", "Laser Rifle", 10.0, 60.0, 0.95, &"shoot_2h", 20.0, ["ranged", "aoe"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow", "at": "forward", "distance": 1.0},
		{"t": 0.25, "type": "beam", "length": 22.0, "width": 1.3, "duration": 0.6, "tick": 0.15, "follow_aim": true,
		"visual": "lightning", "color": LASER, "hit": hit(0.36, {"hitstun": 0.3, "knockback": 1.2, "juggle_cost": 4.0})},
		{"t": 0.25, "type": "sfx", "name": "lightning"},
		{"t": 0.86, "type": "dash", "direction": "back", "distance": 2.5, "speed": 14.0}],
		{"cancel_window": 0.1, "desc": "发射贯穿直线的激光炮，强大后坐力把自己推后。 Piercing laser beam; the heavy recoil shoves you backward."})

	# ---------------------------------------------------------------- slot 4: stinger
	var stinger := sk(4, "stinger", "毒刺", "Stinger", 9.0, 50.0, 0.5, &"shoot_2h", 20.0, ["aoe", "ranged"],
		[{"t": 0.15, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.0},
		{"t": 0.15, "type": "sfx", "name": "cannon"},
		{"t": 0.15, "type": "custom", "method": "stinger_rain", "args": {"petals": 8, "r": 1.6, "dmg": 0.24}}],
		{"cancel_window": 0.15, "desc": "炮弹在目标上空分裂成 8 枚毒刺落下。 A shell that splits into 8 stingers raining on the target area."})

	# ---------------------------------------------------------------- slot 5: gatling
	var gatling_steps: Array = []
	for i in 8:
		gatling_steps.append({"t": 0.15 + 0.09 * float(i), "type": "projectile", "speed": 44.0, "range": 20.0, "radius": 0.3,
			"aim": "target", "visual": "bullet", "color": Color(1.0, 0.85, 0.4),
			"hit": hit(0.24, {"hitstun": 0.25, "knockback": 0.4, "juggle_cost": 3.0})})
		if i % 2 == 0:
			gatling_steps.append({"t": 0.15 + 0.09 * float(i), "type": "sfx", "name": "shot"})
	var gatling := sk(5, "gatling_gun", "格林机枪", "Gatling Gun", 8.0, 45.0, 0.9, &"shoot_2h", 18.0, ["ranged", "combo"],
		gatling_steps, {"cancel_window": 0.15, "desc": "手炮切换机枪模式倾泻弹流。 A stream of machine-gun bullets."})

	# ---------------------------------------------------------------- slot 6: heat-seeking missile
	var hsm := sk(6, "heat_seeking_missile", "热感飞弹", "Heat-Seeking Missile", 10.0, 55.0, 0.5, &"shoot_2h", 26.0,
		["ranged", "aoe"],
		[{"t": 0.0, "type": "vfx", "name": "debuff_puff", "at": "target"},
		{"t": 0.2, "type": "projectile", "speed": 18.0, "range": 32.0, "radius": 0.45, "homing": 3.5, "aim": "target",
		"visual": "missile", "scale": 1.3, "color": SHELL, "hit": hit(0.3, {"hitstun": 0.3}),
		"explode": {"radius": 3.5, "hit": hit(1.4, {"knockdown": true, "knockback": 5.0}), "fx": "explosion"}},
		{"t": 0.2, "type": "sfx", "name": "cannon"}],
		{"cancel_window": 0.15, "desc": "打响指锁定目标，发射追踪飞弹大范围爆炸。 Snap-lock a target and fire a homing missile with a wide blast."})

	# ---------------------------------------------------------------- slot 7: Lv70 ultimate
	var satellite := sk(7, "satellite_beam", "卫星射线", "Satellite Beam", 70.0, 300.0, 1.2, &"cast_long", 26.0,
		["ultimate", "aoe", "ranged", "zone"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.4)], "fx": "cast_glow"},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"}, {"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 4.0, "delay": 0.6, "duration": 2.4, "tick": 0.3,
		"visual": "lightning", "color": LASER, "hit": hit(0.3, {"hitstun": 0.3, "knockback": 0.0, "juggle_cost": 4.0})},
		{"t": 0.3, "type": "custom", "method": "satellite_beams", "args": {"beams": 6, "r": 2.0, "dmg": 0.35}},
		{"t": 0.9, "type": "sfx", "name": "lightning", "at": "target"}],
		{"desc": "召唤卫星射线：六道旋转光柱轰击目标区域。 Six rotating satellite beams bombard the target area."})

	skills = [shell1, swing, atm, laser, stinger, gatling, hsm, satellite]

	passives = [
		{"name_cn": "火炮掌握", "name_en": "Artillery Mastery",
		"desc": "伤害 +10%，远距离（12米以上）目标再 +10%。 Damage +10%, another +10% against targets 12 m or farther."},
		{"name_cn": "炮火后坐力", "name_en": "Cannon Recoil",
		"desc": "空中开炮会把自己向后上方推开，可用于空中位移。 Firing in the air kicks you back and up - use it to move in mid-air."},
	]


func _shell(t: float, dmg: float, kb: float) -> Dictionary:
	return {"t": t, "type": "projectile", "speed": 30.0, "range": 24.0, "radius": 0.45, "aim": "target", "visual": "cannonball",
		"color": SHELL, "hit": hit(0.15, {"hitstun": 0.3, "knockback": 1.0}),
		"explode": {"radius": 1.6, "hit": hit(dmg, {"knockback": kb, "hitstun": 0.4}), "fx": "explosion"}}


func _missile(t: float) -> Dictionary:
	return {"t": t, "type": "projectile", "speed": 32.0, "range": 24.0, "radius": 0.4, "aim": "target", "visual": "missile",
		"color": SHELL, "hit": hit(0.2, {"hitstun": 0.3, "knockback": 0.5}),
		"explode": {"radius": 1.8, "hit": hit(0.45, {"stun": 0.35, "knockback": 2.0, "hitstun": 0.4}), "fx": "explosion"}}


# ---------------------------------------------------------------- hooks
func on_tick(f: Fighter, _delta: float) -> void:
	# 火炮掌握 Artillery Mastery.
	var bonus := 0.1
	var t := f.get_target()
	if t != null and t.global_position.distance_to(f.global_position) >= LONG_RANGE:
		bonus += 0.1
	# Additive own-share: only this passive's contribution is replaced, other dmg_out modifiers survive.
	KU.set_bonus_share(f, "dmg_out", &"la_art", bonus)


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.has_tag("ranged"):
		GU.air_recoil(f, RECOIL_UP, RECOIL_BACK, RECOIL_CAP)


# ---------------------------------------------------------------- custom actions
## 毒刺 Stinger: the shell splits over the target and 8 stingers fall around it (plus one in the middle).
func stinger_rain(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var center := GU.strike_center(runner, 22.0)
	var pts := GU.flower_points(center, int(args.get("petals", 8)), float(args.get("r", 1.6)), f.facing_yaw)
	for i in pts.size():
		GU.burst_at(runner, pts[i], {"radius": 1.3, "delay": 0.45 + 0.04 * float(i), "visual": "thorn", "color": SHELL,
			"hit": hit(float(args.get("dmg", 0.28)), {"hitstun": 0.35, "knockback": 1.0, "juggle_cost": 5.0})})


## 卫星射线 Satellite Beam: six beams strike in a rotating hexagon around the target.
func satellite_beams(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var center := GU.strike_center(runner, 26.0)
	var n := int(args.get("beams", 6))
	var r := float(args.get("r", 2.0))
	for k in n:
		var a := f.facing_yaw + TAU * float(k) / float(n) + deg_to_rad(20.0) * float(k)
		var pos := center + Vector3(sin(a), 0.0, cos(a)) * r
		GU.burst_at(runner, pos, {"radius": 2.0, "delay": 0.6 + 0.3 * float(k), "visual": "lightning", "color": LASER,
			"hit": hit(float(args.get("dmg", 0.35)), {"hitstun": 0.4, "knockback": 0.0, "launch": 5.0 if k == 0 else 0.0,
			"juggle_cost": 6.0})})
