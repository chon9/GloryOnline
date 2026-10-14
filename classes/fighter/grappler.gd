extends ClassKit
## 柔道 Grappler (格斗系 Fighter). Grab specialist: every throw breaks super armor and denies quick recovery.
## Toss launcher (grab that tosses the foe upward), Back Throw with landing shockwave, Receiving Throw counter-grab,
## Fling, Double Flying Hands, Aerial Twist anti-air, Spinning Throw ultimate.
## Passive 擒拿 Grappling Mastery: each completed throw refunds MP and grants a short super armor.

const COUNTER_WINDOW: float = 0.7
const COUNTER_REACH: float = 3.5
const THROW_KEY: String = "grappler_throw"


func define() -> void:
	id = "grappler"
	name_cn = "柔道"
	name_en = "Grappler"
	group_id = "fighter"
	group_cn = "格斗系"
	group_en = "Fighter"
	role = "control"
	weapon_type = "tonfa"
	weapon_name_cn = "东方棍"
	weapon_name_en = "Tonfa"
	offhand = ""
	model = "grappler"
	tint = Color(0.95, 0.85, 0.35)
	famous = "李亦辉 Li Yihui / 沾衣乱飞 Flying Drops"
	stats = {"hp": 9000.0, "mp": 1100.0, "mp_regen": 20.0, "patk": 720.0, "matk": 400.0,
		"pdef": 500.0, "mdef": 420.0, "move_speed": 6.2, "jump_velocity": 9.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: basic chain 普攻
	var b1 := sk(0, "tonfa_strike", "棍击", "Basic: Tonfa Strike", 0.0, 0.0, 0.3, &"attack_1h_1", 2.2, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.2, "arc": 100.0, "hit": hit(0.7, {"hitstun": 0.35, "knockback": 0.8})},
		{"t": 0.06, "type": "sfx", "name": "swing_fist"}],
		{"cancel_window": 0.14, "chain": ["tonfa_strike", "tonfa_return", "foot_sweep"], "desc": "东方棍快打 Quick tonfa strike."})
	sk(0, "tonfa_return", "回棍", "Basic: Tonfa Return", 0.0, 0.0, 0.3, &"attack_1h_2", 2.2, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.2, "arc": 100.0, "hit": hit(0.7, {"hitstun": 0.38, "knockback": 1.0})},
		{"t": 0.06, "type": "sfx", "name": "swing_fist"}],
		{"cancel_window": 0.15, "desc": "反手回棍 Backhand tonfa return."})
	sk(0, "foot_sweep", "扫腿", "Basic: Foot Sweep", 0.0, 0.0, 0.42, &"kick", 2.2, ["melee", "finisher"],
		[{"t": 0.16, "type": "melee", "range": 2.2, "arc": 140.0, "hit": hit(0.9, {"knockdown": true, "knockback": 2.0})},
		{"t": 0.12, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.15, "desc": "扫腿绊倒 Sweeping kick that trips the foe."})

	# ---------------------------------------------------------------- slot 1: launcher (Toss)
	var toss := sk(1, "toss", "抛投", "Toss", 4.0, 40.0, 0.5, &"grab", 1.9, ["launcher", "grab", "melee", "combo"],
		[{"t": 0.08, "type": "grab", "range": 1.9, "grab_time": 0.3, "throw": {"dir": "up", "force": 11.0},
			"hit": hit(1.4, {"knockback": 0.5, THROW_KEY: true})},
		{"t": 0.08, "type": "sfx", "name": "grab"},
		{"t": 0.4, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.0}],
		{"cancel_window": 0.15, "desc": "优先级极高的抓取，将敌人抛上空中 High-priority grab that tosses the enemy into the air."})

	# ---------------------------------------------------------------- slot 2: Back Throw
	var back_throw := sk(2, "back_throw", "背摔", "Back Throw", 7.0, 60.0, 0.95, &"grab", 1.9,
		["grab", "cc", "finisher", "aoe", "melee"],
		[{"t": 0.08, "type": "grab", "range": 1.9, "grab_time": 0.55, "throw": {"dir": "back", "force": 3.0},
			"hit": hit(2.0, {"knockdown": true, "knockback": 1.0, THROW_KEY: true})},
		{"t": 0.08, "type": "sfx", "name": "grab"},
		{"t": 0.66, "type": "anim", "anim": "attack_slam"},
		{"t": 0.72, "type": "ground", "at": "self", "radius": 2.6, "visual": "earth", "max_hits": 1,
			"hit": hit(0.7, {"otg": true, "knockdown": true, "knockback": 4.0})},
		{"t": 0.72, "type": "vfx", "name": "land_dust", "scale": 1.6},
		{"t": 0.72, "type": "sfx", "name": "stomp"}],
		{"cancel_window": 0.15, "desc": "过肩背摔落地冲击波，破霸体且无法受身 Over-the-shoulder slam with a shockwave; breaks super armor."})

	# ---------------------------------------------------------------- slot 3: Receiving Throw
	var receiving := sk(3, "receiving_throw", "接投", "Receiving Throw", 9.0, 50.0, 0.8, &"block", 2.0,
		["defensive", "interrupt", "grab", "cc", "melee"],
		[{"t": 0.0, "type": "custom", "method": "counter_open", "args": {"window": COUNTER_WINDOW}},
		{"t": 0.7, "type": "custom", "method": "counter_close", "args": {}}],
		{"cancel_window": 0.1, "desc": "Lv20 接住来招扛肩摔到身后；未触发则直接抓取 Lv20 catches an incoming melee attack and slams the attacker behind you."})

	# ---------------------------------------------------------------- slot 4: Fling
	var fling := sk(4, "fling", "甩投", "Fling", 6.0, 45.0, 0.6, &"throw", 1.9, ["grab", "cc", "melee"],
		[{"t": 0.08, "type": "grab", "range": 1.9, "grab_time": 0.3, "throw": {"dir": "forward", "force": 14.0},
			"hit": hit(1.6, {"knockdown": true, "knockback": 4.0, THROW_KEY: true})},
		{"t": 0.08, "type": "sfx", "name": "throw"}],
		{"cancel_window": 0.15, "desc": "抓住敌人向前远远甩出 Grabs and flings the enemy far ahead."})

	# ---------------------------------------------------------------- slot 5: Flying Hands
	var flying_hands := sk(5, "flying_hands", "双手飞", "Flying Hands", 9.0, 65.0, 0.75, &"grab", 2.0,
		["grab", "cc", "aoe", "melee"],
		[{"t": 0.1, "type": "grab", "range": 2.0, "arc": 140.0, "grab_time": 0.5, "throw": {"dir": "forward", "force": 7.0},
			"hit": hit(1.7, {"knockdown": true, THROW_KEY: true})},
		{"t": 0.1, "type": "grab", "range": 2.0, "arc": 140.0, "grab_time": 0.5, "throw": {"dir": "forward", "force": 7.0},
			"hit": hit(1.7, {"knockdown": true, THROW_KEY: true})},
		{"t": 0.1, "type": "sfx", "name": "grab"}],
		{"cancel_window": 0.15, "desc": "双手各抓一人摔倒（双手飞） Grabs up to two enemies at once and throws them down."})

	# ---------------------------------------------------------------- slot 6: Aerial Twist
	var aerial_twist := sk(6, "aerial_twist", "空绞杀", "Aerial Twist", 8.0, 55.0, 0.75, &"leap", 5.0,
		["gap_closer", "grab", "cc", "finisher"],
		[{"t": 0.0, "type": "leap", "to": "target", "distance": 5.0, "height": 2.4, "duration": 0.38},
		{"t": 0.4, "type": "custom", "method": "aerial_twist", "args": {"reach": 2.4}},
		{"t": 0.4, "type": "anim", "anim": "aerial"}],
		{"cancel_window": 0.15, "desc": "跃起剪刀腿绞住敌人摔倒，可抓空中目标 Leaping leg-scissor that drags even airborne foes down."})

	# ---------------------------------------------------------------- slot 7: ultimate (Spinning Throw)
	var spinning := sk(7, "spinning_throw", "旋投", "Spinning Throw", 55.0, 200.0, 1.9, &"attack_spin", 2.0,
		["ultimate", "grab", "aoe", "melee", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "fx": "cast_glow", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.08, "type": "grab", "range": 2.0, "arc": 120.0, "grab_time": 1.45, "throw": {"dir": "forward", "force": 16.0},
			"hit": hit(2.8, {"knockdown": true, "knockback": 6.0, THROW_KEY: true})},
		{"t": 0.25, "type": "multi_melee", "shape": "circle", "range": 3.0, "count": 6, "interval": 0.2, "fx": "slash_arc",
			"hit": hit(0.35, {"hitstun": 0.0, "knockback": 6.0, "juggle_cost": 3.0})},
		{"t": 1.5, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.5},
		{"t": 1.5, "type": "sfx", "name": "boss_stomp"}],
		{"cancel_window": 0.15, "desc": "大招：抓住敌人旋转，甩飞周围的人后全力抛出 Ultimate: spins the grabbed foe like a hammer, bowling others away, then hurls it."})

	skills = [b1, toss, back_throw, receiving, fling, flying_hands, aerial_twist, spinning]
	passives = [
		{"name_cn": "擒拿", "name_en": "Grappling Mastery",
			"desc": "完成投技回复30法力并获得0.6秒霸体；投技无视霸体且不可受身 Each completed throw refunds 30 MP and grants 0.6 s super armor; throws ignore super armor and deny quick recovery."},
	]


# ================================================================== hooks
func on_tick(f: Fighter, delta: float) -> void:
	_restore_negated(f)
	var w := float(f.get_meta(&"grappler_counter", 0.0))
	if w > 0.0:
		f.set_meta(&"grappler_counter", maxf(0.0, w - delta))


func on_hit_dealt(f: Fighter, _victim: Fighter, hit_d: Dictionary, _dmg: float) -> void:
	if bool(hit_d.get(THROW_KEY, false)):
		f.mp = minf(f.max_mp, f.mp + 30.0)
		f.add_status(&"super_armor", 0.6, 1.0, f)


func on_hit_taken(f: Fighter, src: Fighter, hit_d: Dictionary, dmg: float) -> float:
	if float(f.get_meta(&"grappler_counter", 0.0)) <= 0.0 or src == null or not is_instance_valid(src):
		return dmg
	if Hit.is_magic(hit_d) or not src.is_alive() or src == f or bool(hit_d.get("grab", false)):
		return dmg
	if src.global_position.distance_to(f.global_position) > COUNTER_REACH:
		return dmg
	f.set_meta(&"grappler_counter", 0.0)
	if f.runner == null or f.runner.skill.id != StringName(full_id("receiving_throw")):
		return dmg
	f.runner.vars["countered"] = true
	f.face_towards(src.global_position)
	f.anim_key = &"grab"
	f.anim_seq += 1
	var h := Hit.normalize(hit(2.4, {"knockdown": true, "knockback": 2.0, THROW_KEY: true, "grab": true, "grab_time": 0.5,
		"throw": {"dir": "back", "force": 5.0}}))
	f.runner.deal(src, h, f.global_position)
	CoreUtil.fx(&"play", [&"block_spark", f.center(), f.forward(), tint, 1.2])
	CoreUtil.fx(&"sfx", [&"grab", f.center()])
	_negate_hit(f, hit_d)
	return 0.0


## Fully negates the countered HIT: receive_hit re-reads the (possibly shared) dict after on_hit_taken, so its
## riders are blanked in place and restored on this fighter's next tick.
func _negate_hit(f: Fighter, hit_d: Dictionary) -> void:
	var keys: Array[String] = ["statuses", "stun", "armor_break", "launch", "knockdown", "knockback", "pull", "hitstun"]
	var saved := {}
	for k: String in keys:
		if hit_d.has(k):
			saved[k] = hit_d[k]
	var pend: Array = f.get_meta(&"grappler_negated", [])
	pend.append([hit_d, saved])
	f.set_meta(&"grappler_negated", pend)
	hit_d["statuses"] = []
	hit_d["stun"] = 0.0
	hit_d["armor_break"] = false
	hit_d["launch"] = 0.0
	hit_d["knockdown"] = false
	hit_d["knockback"] = 0.0
	hit_d["pull"] = false
	hit_d["hitstun"] = 0.0


func _restore_negated(f: Fighter) -> void:
	if not f.has_meta(&"grappler_negated"):
		return
	for e: Array in f.get_meta(&"grappler_negated", []):
		var d: Dictionary = e[0]
		var saved: Dictionary = e[1]
		for k: Variant in saved:
			d[k] = saved[k]
	f.remove_meta(&"grappler_negated")


# ================================================================== custom actions
func counter_open(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	var w := float(args.get("window", COUNTER_WINDOW))
	f.set_meta(&"grappler_counter", w)
	f.add_status(&"super_armor", w, 1.0, f)
	CoreUtil.fx(&"play", [&"cast_glow", f.center(), f.forward(), tint, 0.8])


func counter_close(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	f.set_meta(&"grappler_counter", 0.0)
	if bool(runner.vars.get("countered", false)):
		return
	# Nobody attacked: step in and take the grab anyway.
	f.anim_key = &"grab"
	f.anim_seq += 1
	runner.execute_step({"type": "grab", "range": 2.0, "grab_time": 0.45, "throw": {"dir": "back", "force": 4.0},
		"hit": hit(1.8, {"knockdown": true, THROW_KEY: true})})


## 空绞杀: grabs a grounded foe (grab -> knockdown) or scissors an airborne one straight into the floor.
func aerial_twist(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var reach := float(args.get("reach", 2.4))
	var best: Fighter = null
	var best_d := INF
	for e: Fighter in runner.enemies():
		if e.is_downed() or e.state == Fighter.State.GRABBED:
			continue
		var d := CoreUtil.flat(e.global_position - f.global_position).length() - e.radius() - f.radius()
		if d > reach or absf(e.global_position.y - f.global_position.y) > 4.0:
			continue
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	f.face_towards(best.global_position)
	if best.is_airborne():
		var h := Hit.normalize(hit(2.0, {"knockdown": true, "no_recover": true, "armor_break": true, "knockback": 1.0,
			"juggle_cost": 30.0, THROW_KEY: true}))
		runner.deal(best, h, f.global_position)
		if best.is_alive():
			best.velocity.y = -14.0
		CoreUtil.fx(&"play", [&"hit_heavy", best.center(), f.forward(), tint, 1.0])
	else:
		var g := Hit.normalize(hit(2.0, {"knockdown": true, "grab": true, "grab_time": 0.4, "knockback": 1.0, THROW_KEY: true,
			"throw": {"dir": "forward", "force": 3.0}}))
		runner.deal(best, g, f.global_position)
		CoreUtil.fx(&"play", [&"hit_heavy", best.center(), f.forward(), tint, 0.8])
