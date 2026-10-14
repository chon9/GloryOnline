extends ClassKit
## 气功师 Qi Master (格斗系 Fighter). Mid-range magic fighter: Countercurrent long-range launcher, slow Qi Bullet,
## steerable Dragon Wave (debuffs enemies, empowers allies), Cloud Grasping Fist long-range grab, Nen Guard barrier,
## Spirit Reaches to the Rainbow piercing dash, Qi Blast ultimate.
## Passive 护体真气 True Qi Protection: defenses scale with current mana.

const KU := preload("res://classes/_kit_util.gd")
const QI_PROTECT_MAX: float = 0.3
const GRASP_RANGE: float = 10.0
const GRASP_CONE: float = 60.0
const QI_COLOR: Color = Color(0.5, 0.85, 1.0)


func define() -> void:
	id = "qi_master"
	name_cn = "气功师"
	name_en = "Qi Master"
	group_id = "fighter"
	group_cn = "格斗系"
	group_en = "Fighter"
	role = "ranged"
	weapon_type = "gloves_qi"
	weapon_name_cn = "拳套"
	weapon_name_en = "Gloves"
	offhand = ""
	model = "qi_master"
	tint = Color(0.45, 0.85, 1.0)
	famous = "方锐 Fang Rui / 海无量 Boundless Sea / Mirrored Moon"
	stats = {"hp": 6900.0, "mp": 1500.0, "mp_regen": 22.0, "patk": 420.0, "matk": 590.0,
		"pdef": 330.0, "mdef": 460.0, "move_speed": 6.0, "jump_velocity": 9.0, "cast_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: basic chain 普攻
	var b1 := sk(0, "palm", "气掌", "Basic: Qi Palm", 0.0, 0.0, 0.3, &"punch", 2.4, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.4, "arc": 90.0, "color": QI_COLOR, "fx": "hit_spark",
			"hit": hit(0.6, {"type": "magic", "hitstun": 0.35, "knockback": 1.0})},
		{"t": 0.06, "type": "sfx", "name": "qi"}],
		{"cancel_window": 0.14, "chain": ["palm", "palm2", "qi_push"], "desc": "裹气的掌击 Qi-wrapped palm strike."})
	sk(0, "palm2", "回身掌", "Basic: Turning Palm", 0.0, 0.0, 0.3, &"punch_combo", 2.4, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.4, "arc": 90.0, "color": QI_COLOR, "fx": "hit_spark",
			"hit": hit(0.6, {"type": "magic", "hitstun": 0.38, "knockback": 1.2})},
		{"t": 0.06, "type": "sfx", "name": "qi"}],
		{"cancel_window": 0.15, "desc": "回身第二掌 Second turning palm."})
	sk(0, "qi_push", "气劲", "Basic: Qi Push", 0.0, 0.0, 0.4, &"cast", 9.0, ["ranged", "finisher"],
		[{"t": 0.14, "type": "projectile", "sfx": "qi", "speed": 20.0, "range": 9.0, "radius": 0.45, "aim": "target", "visual": "qi",
			"color": QI_COLOR, "scale": 0.8, "hit": hit(0.75, {"type": "magic", "knockback": 4.0, "hitstun": 0.45})}],
		{"cancel_window": 0.18, "desc": "推出一团短程气劲 Pushes out a short qi burst."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var countercurrent := sk(1, "countercurrent", "逆流", "Countercurrent", 4.0, 40.0, 0.45, &"cast", 10.0,
		["launcher", "ranged", "combo"],
		[{"t": 0.1, "type": "ground", "at": "target", "distance": 9.0, "max_distance": 11.0, "radius": 1.6, "delay": 0.35,
			"visual": "wind", "color": QI_COLOR, "hit": hit(1.3, {"type": "magic", "launch": 10.5, "knockback": 0.5})},
		{"t": 0.1, "type": "sfx", "name": "qi_blast"}],
		{"cancel_window": 0.2, "desc": "Lv1 远程浮空：脚下逆流气柱，出手后不可打断 Lv1 longest-range launcher; a delayed qi geyser under the foe."})

	# ---------------------------------------------------------------- slot 2: Qi Bullet
	var qi_bullet := sk(2, "qi_bullet", "气波弹", "Qi Bullet", 3.0, 35.0, 0.4, &"cast", 15.0, ["ranged", "combo"],
		[{"t": 0.15, "type": "projectile", "sfx": "qi", "speed": 11.0, "range": 16.0, "radius": 0.6, "aim": "target", "visual": "qi",
			"color": QI_COLOR, "scale": 1.4, "hit": hit(1.5, {"type": "magic", "knockback": 3.5, "hitstun": 0.55})}],
		{"cancel_window": 0.2, "desc": "缓慢飞行的大气弹 A slow, heavy magic qi orb."})

	# ---------------------------------------------------------------- slot 3: Dragon Wave
	var dragon_wave := sk(3, "dragon_wave", "念龙波", "Dragon Wave", 9.0, 70.0, 0.55, &"channel", 16.0,
		["ranged", "debuff", "buff_ally"],
		[{"t": 0.2, "type": "projectile", "sfx": "qi_blast", "speed": 14.0, "range": 18.0, "radius": 0.7, "aim": "target", "visual": "dragon",
			"color": QI_COLOR, "scale": 1.3, "homing": 3.0, "pierce": true,
			"hit": hit(1.6, {"type": "magic", "knockback": 2.5, "hitstun": 0.5,
				"statuses": [st("def_down", 6.0, 0.15), st("slow", 4.0, 0.3)]})},
		{"t": 0.2, "type": "custom", "method": "dragon_inspire", "args": {"radius": 10.0, "dur": 8.0, "power": 0.12}},
		{"t": 0.2, "type": "sfx", "name": "wind"}],
		{"cancel_window": 0.15, "desc": "可操控的气龙：削弱敌人防御与速度，鼓舞身边队友 Steerable qi dragon: weakens foes, empowers nearby allies."})

	# ---------------------------------------------------------------- slot 4: Cloud Grasping Fist
	var cloud_grasp := sk(4, "cloud_grasp", "捉云手", "Cloud Grasping Fist", 12.0, 60.0, 0.6, &"grab", GRASP_RANGE,
		["grab", "cc", "ranged", "interrupt"],
		[{"t": 0.12, "type": "custom", "method": "cloud_grasp", "args": {"range": GRASP_RANGE}},
		{"t": 0.12, "type": "sfx", "name": "grab"}],
		{"cancel_window": 0.2, "desc": "远距离隔空抓取，将敌人拉到面前 Long-range qi grab that drags the enemy in front of you."})

	# ---------------------------------------------------------------- slot 5: Nen Guard
	var nen_guard := sk(5, "nen_guard", "念气罩", "Nen Guard", 15.0, 80.0, 0.3, &"cast", 0.0, ["buff_self", "defensive"],
		[{"t": 0.05, "type": "buff", "target": "self", "color": QI_COLOR, "shield": 0.18, "shield_dur": 10.0, "statuses": []},
		{"t": 0.05, "type": "sfx", "name": "shield_up"}],
		{"desc": "气罩吸收伤害（18%生命，10秒） Qi barrier absorbing 18% max HP for 10 s."})

	# ---------------------------------------------------------------- slot 6: Spirit Reaches to the Rainbow
	var rainbow := sk(6, "rainbow", "气贯长虹", "Spirit Reaches to the Rainbow", 10.0, 70.0, 0.55, &"dash", 9.0,
		["gap_closer", "escape", "aoe", "melee"],
		[{"t": 0.05, "type": "dash", "direction": "aim", "distance": 9.0, "speed": 26.0, "through_enemies": true,
			"color": QI_COLOR, "hit": hit(1.8, {"type": "magic", "launch": 6.0, "knockback": 6.0})},
		{"t": 0.05, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.15, "desc": "Lv55 周身裹气向前贯穿冲锋 Lv55 qi-charged dash that blasts through enemies."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var qi_blast := sk(7, "qi_blast", "气功爆破", "Qi Blast", 60.0, 220.0, 2.0, &"channel", 10.0,
		["ultimate", "ranged", "aoe", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash", "color": QI_COLOR},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "fx": "cast_glow", "color": QI_COLOR, "statuses": [st("super_armor", 2.1)]},
		{"t": 0.1, "type": "ground", "at": "target", "distance": 8.0, "radius": 3.2, "duration": 1.5, "tick": 0.25,
			"visual": "wind", "color": QI_COLOR, "hit": hit(0.3, {"type": "magic", "hitstun": 0.45, "knockback": 0.0, "juggle_cost": 3.0})},
		{"t": 1.75, "type": "ground", "at": "target", "distance": 8.0, "radius": 4.0, "visual": "lightning", "color": QI_COLOR,
			"hit": hit(2.4, {"type": "magic", "knockback": 14.0, "knockdown": true})},
		{"t": 1.75, "type": "vfx", "name": "explosion", "at": "target", "color": QI_COLOR},
		{"t": 1.75, "type": "sfx", "name": "ultimate_release"}],
		{"cancel_window": 0.15, "desc": "Lv70 大招：持续气爆伤害后巨大击飞 Lv70 sustained qi detonation, then a huge knockback."})

	skills = [b1, countercurrent, qi_bullet, dragon_wave, cloud_grasp, nen_guard, rainbow, qi_blast]
	passives = [
		{"name_cn": "护体真气", "name_en": "True Qi Protection",
			"desc": "法力越高防御越高（最高+30%） Defense scales with current mana (up to +30%)."},
	]


# ================================================================== hooks
func on_tick(f: Fighter, _delta: float) -> void:
	var frac := f.mp / maxf(1.0, f.max_mp)
	var bonus := QI_PROTECT_MAX * clampf(frac, 0.0, 1.0)
	# Additive shares: only this passive's own contribution is replaced, other pdef/mdef modifiers survive.
	KU.set_bonus_share(f, "pdef", &"qi_protect_pdef", bonus)
	KU.set_bonus_share(f, "mdef", &"qi_protect_mdef", bonus)


# ================================================================== custom actions
## 捉云手: grabs the target (or nearest enemy in front) up to `range` metres away and drags it in front.
func cloud_grasp(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var rng := float(args.get("range", GRASP_RANGE))
	var t := f.get_target()
	if t == null or not f.is_enemy(t) or t.global_position.distance_to(f.global_position) > rng:
		# No usable lock: only grab what the Qi Master is actually facing (60 deg half-cone), nearest first.
		t = null
		var best := INF
		var fwd := f.forward()
		for e: Fighter in runner.enemies():
			var to := e.global_position - f.global_position
			var d := to.length()
			if d > rng or d >= best:
				continue
			if d > 0.5 and rad_to_deg(fwd.angle_to(CoreUtil.flat_dir(to))) > GRASP_CONE:
				continue
			best = d
			t = e
	if t == null or not t.is_hittable() or t.is_downed():
		return
	if t.state == Fighter.State.LAUNCHED or t.state == Fighter.State.GRABBED or t.state == Fighter.State.DEAD:
		return
	f.face_towards(t.global_position)
	var from := t.center()
	var dest := f.global_position + f.forward() * (f.radius() + t.radius() + 0.3)
	dest = w.ground_point(w.clamp_to_bounds(dest))
	t.global_position = dest
	t.velocity = Vector3.ZERO
	CoreUtil.fx(&"play", [&"dash_trail", from, CoreUtil.flat_dir(dest - from), QI_COLOR, 1.2])
	CoreUtil.fx(&"play", [&"cast_glow", t.center(), f.forward(), QI_COLOR, 1.0])
	var h := Hit.normalize(hit(0.5, {"type": "magic", "grab": true, "grab_time": 0.45, "hitstun": 0.7, "knockback": 0.5}))
	runner.deal(t, h, f.global_position)


## 念龙波 ally empowerment: atk_up on nearby allies only (never the Qi Master himself).
func dragon_inspire(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var r := float(args.get("radius", 10.0))
	for a: Fighter in w.allies_of(f, false):
		if a.global_position.distance_to(f.global_position) <= r:
			a.add_status(&"atk_up", float(args.get("dur", 8.0)), float(args.get("power", 0.12)), f)
			CoreUtil.fx(&"play", [&"buff_aura", a.global_position, a.forward(), QI_COLOR, 0.8])
