extends ClassKit
## 拳法家 Striker (格斗系 Fighter). Shortest-range super-armor bruiser: Launching Kick -> juggle -> Eagle Stamp,
## Reinforced Iron Bones super armor, Empty-Handed Blade Block parry-counter, Ferocious Tiger Flurry ultimate.
## Passive 铁拳之势 Iron Fist Momentum: every 6 hits landed within a short window grant a brief super armor.

const MOMENTUM_HITS: int = 6
const MOMENTUM_WINDOW: float = 2.5
const PARRY_WINDOW: float = 0.65
const PARRY_REACH: float = 4.5


func define() -> void:
	id = "striker"
	name_cn = "拳法家"
	name_en = "Striker"
	group_id = "fighter"
	group_cn = "格斗系"
	group_en = "Fighter"
	role = "melee"
	weapon_type = "gloves"
	weapon_name_cn = "拳套"
	weapon_name_en = "Gloves"
	offhand = ""
	model = "striker"
	tint = Color(0.95, 0.32, 0.14)
	famous = "韩文清 Han Wenqing / 大漠孤烟 Desert Dust / 烈焰红拳 Flame Fists"
	stats = {"hp": 8400.0, "mp": 1100.0, "mp_regen": 20.0, "patk": 680.0, "matk": 400.0,
		"pdef": 480.0, "mdef": 380.0, "move_speed": 6.2, "jump_velocity": 9.0, "atk_speed": 1.05}

	# ---------------------------------------------------------------- slot 0: basic chain 普攻
	var b1 := sk(0, "jab", "刺拳", "Basic: Jab", 0.0, 0.0, 0.28, &"punch", 2.4, ["melee", "combo"],
		[{"t": 0.09, "type": "melee", "range": 2.4, "arc": 100.0, "fx": "hit_spark", "hit": hit(0.7, {"hitstun": 0.35, "knockback": 0.8})},
		{"t": 0.05, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.14, "chain": ["jab", "cross", "spin_kick"], "desc": "左右快拳起手 Quick opening jab."})
	sk(0, "cross", "直拳", "Basic: Cross", 0.0, 0.0, 0.3, &"punch_combo", 2.4, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.4, "arc": 100.0, "fx": "hit_spark", "hit": hit(0.7, {"hitstun": 0.38, "knockback": 1.0})},
		{"t": 0.05, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.15, "desc": "重直拳 Heavy cross punch."})
	sk(0, "spin_kick", "旋身踢", "Basic: Spin Kick", 0.0, 0.0, 0.42, &"kick", 2.5, ["melee", "finisher"],
		[{"t": 0.16, "type": "melee", "range": 2.5, "arc": 140.0, "hit": hit(0.9, {"knockback": 5.0, "hitstun": 0.5})},
		{"t": 0.12, "type": "sfx", "name": "hit"}],
		{"cancel_window": 0.18, "desc": "旋身踢收尾，击退 Spinning kick finisher, knocks back."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var launching_kick := sk(1, "launching_kick", "高踢", "Launching Kick", 4.0, 40.0, 0.4, &"kick", 2.2,
		["launcher", "melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.2, "arc": 100.0, "hit": hit(1.4, {"launch": 10.5, "knockback": 0.6})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.2},
		{"t": 0.08, "type": "sfx", "name": "hit_heavy"}],
		{"cancel_window": 0.22, "desc": "Lv1 高踢将敌人踢上空中 Lv1 high kick that launches the enemy."})

	# ---------------------------------------------------------------- slot 2: Straight Punch
	var straight_punch := sk(2, "straight_punch", "冲拳", "Straight Punch", 6.0, 50.0, 0.5, &"punch", 6.5,
		["gap_closer", "melee", "combo"],
		[{"t": 0.05, "type": "dash", "direction": "target", "distance": 6.0, "speed": 26.0, "stop_on_hit": true,
			"hit": hit(1.9, {"knockback": 8.0, "hitstun": 0.55})},
		{"t": 0.05, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.2, "desc": "冲刺直拳突进并击退 Dashing punch that closes distance and knocks back."})

	# ---------------------------------------------------------------- slot 3: Eagle Stamp
	var eagle_stamp := sk(3, "eagle_stamp", "鹰踏", "Eagle Stamp", 7.0, 55.0, 0.6, &"leap", 7.0,
		["gap_closer", "aoe", "finisher", "melee"],
		[{"t": 0.0, "type": "leap", "to": "target", "distance": 7.0, "height": 3.2, "duration": 0.45,
			"land": {"radius": 2.2, "fx": "land_dust", "hit": hit(2.0, {"otg": true, "knockdown": true, "knockback": 3.0, "juggle_cost": 20.0})}},
		{"t": 0.46, "type": "sfx", "name": "earth"}],
		{"cancel_window": 0.12, "desc": "跃起下踏，可踩倒地与空中敌人 Leaping stomp that hits airborne and downed foes."})

	# ---------------------------------------------------------------- slot 4: Reinforced Iron Bones
	var iron_bones := sk(4, "iron_bones", "钢筋铁骨", "Reinforced Iron Bones", 20.0, 80.0, 0.3, &"taunt", 0.0,
		["buff_self", "defensive"],
		[{"t": 0.05, "type": "buff", "target": "self", "statuses": [st("super_armor", 8.0), st("def_up", 8.0, 0.15)]},
		{"t": 0.05, "type": "sfx", "name": "buff"}],
		{"desc": "8秒霸体并提升防御 8 s super armor plus 15% defense."})

	# ---------------------------------------------------------------- slot 5: Emperor's Fist
	var emperors_fist := sk(5, "emperors_fist", "霸皇拳", "Emperor's Fist", 13.0, 90.0, 0.75, &"punch", 3.0,
		["melee", "finisher", "aoe"],
		[{"t": 0.0, "type": "buff", "target": "self", "fx": "cast_glow", "statuses": [st("super_armor", 0.8)]},
		{"t": 0.45, "type": "melee", "range": 2.6, "arc": 70.0, "fx": "hit_heavy",
			"hit": hit(1.8, {"knockback": 12.0, "knockdown": true, "armor_break": true})},
		{"t": 0.45, "type": "ground", "at": "forward", "shape": "line", "length": 7.0, "width": 2.2, "visual": "wind",
			"max_hits": 1, "hit": hit(0.7, {"knockback": 7.0, "hitstun": 0.5})},
		{"t": 0.45, "type": "sfx", "name": "hit_heavy"}],
		{"cancel_window": 0.15, "desc": "马步重拳，拳风波及前方 Horse-stance mega punch; its wind pressure hits along a line."})

	# ---------------------------------------------------------------- slot 6: Empty-Handed Blade Block
	var blade_block := sk(6, "blade_block", "空手入白刃", "Empty-Handed Blade Block", 10.0, 50.0, 0.75, &"block", 2.5,
		["defensive", "interrupt", "cc", "melee"],
		[{"t": 0.0, "type": "custom", "method": "parry_open", "args": {"window": PARRY_WINDOW}},
		{"t": 0.68, "type": "custom", "method": "parry_close", "args": {}}],
		{"cancel_window": 0.05, "desc": "Lv30 格挡近战攻击并反击擒倒；未触发则出掌 Parries a melee hit and counters; palm strike if nothing comes."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var tiger_flurry := sk(7, "tiger_flurry", "猛虎乱舞", "Ferocious Tiger Flurry", 60.0, 200.0, 1.75, &"punch_combo", 4.0,
		["ultimate", "melee", "gap_closer", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.0, "type": "buff", "target": "self", "fx": "cast_glow", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.0, "type": "dash", "direction": "target", "distance": 5.0, "speed": 28.0},
		{"t": 0.3, "type": "multi_melee", "range": 2.4, "arc": 120.0, "count": 8, "interval": 0.1, "fx": "hit_spark",
			"hit": hit(0.45, {"hitstun": 0.4, "knockback": 0.3, "juggle_cost": 4.0})},
		{"t": 1.25, "type": "anim", "anim": "kick"},
		{"t": 1.35, "type": "melee", "range": 2.6, "arc": 140.0, "fx": "hit_heavy",
			"hit": hit(1.6, {"launch": 9.0, "knockback": 7.0, "armor_break": true})},
		{"t": 1.35, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.4}],
		{"cancel_window": 0.2, "desc": "Lv70 大招：猛虎般的连环拳，最后一击挑飞 Lv70 punch rush ending in a launching blow."})

	skills = [b1, launching_kick, straight_punch, eagle_stamp, iron_bones, emperors_fist, blade_block, tiger_flurry]
	passives = [
		{"name_cn": "铁拳之势", "name_en": "Iron Fist Momentum",
			"desc": "连续命中6次获得1.2秒霸体 Landing 6 hits in quick succession grants 1.2 s super armor."},
		{"name_cn": "空手入白刃", "name_en": "Empty-Handed Blade Block",
			"desc": "格挡架势中受到近战攻击时免伤并反击 While in the parry stance, melee hits are negated and countered."},
	]


# ================================================================== hooks
func on_tick(f: Fighter, delta: float) -> void:
	restore_negated(f, &"striker_negated")
	var t := float(f.get_meta(&"striker_mom_t", 0.0))
	if t > 0.0:
		t -= delta
		f.set_meta(&"striker_mom_t", t)
		if t <= 0.0:
			f.set_meta(&"striker_mom", 0)
	var pw := float(f.get_meta(&"striker_parry", 0.0))
	if pw > 0.0:
		f.set_meta(&"striker_parry", maxf(0.0, pw - delta))


func on_hit_dealt(f: Fighter, _victim: Fighter, _hit: Dictionary, dmg: float) -> void:
	if dmg <= 0.0:
		return
	var n := int(f.get_meta(&"striker_mom", 0)) + 1
	f.set_meta(&"striker_mom_t", MOMENTUM_WINDOW)
	if n >= MOMENTUM_HITS:
		n = 0
		f.add_status(&"super_armor", 1.2, 1.0, f)
		CoreUtil.fx(&"play", [&"buff_aura", f.global_position, f.forward(), tint, 0.7])
	f.set_meta(&"striker_mom", n)


func on_hit_taken(f: Fighter, src: Fighter, hit_d: Dictionary, dmg: float) -> float:
	if float(f.get_meta(&"striker_parry", 0.0)) <= 0.0 or src == null or not is_instance_valid(src):
		return dmg
	if Hit.is_magic(hit_d) or not src.is_alive() or src == f:
		return dmg
	if src.global_position.distance_to(f.global_position) > PARRY_REACH:
		return dmg
	# Consume the window first so mirrored parries can never recurse.
	f.set_meta(&"striker_parry", 0.0)
	# The window only counts while the Blade Block stance itself is running (grabbed / interrupted = no parry).
	if f.runner == null or f.runner.skill.id != StringName(full_id("blade_block")):
		return dmg
	var counter := Hit.normalize(hit(2.2, {"launch": 9.0, "knockback": 3.0, "armor_break": true, "no_recover": true}))
	f.face_towards(src.global_position)
	f.anim_key = &"grab"
	f.anim_seq += 1
	f.runner.vars["countered"] = true
	f.runner.deal(src, counter, f.global_position)
	CoreUtil.fx(&"play", [&"block_spark", f.center(), f.forward(), tint, 1.2])
	CoreUtil.fx(&"sfx", [&"block", f.center()])
	negate_hit(f, hit_d, &"striker_negated")
	return 0.0


## Fully negates a parried HIT: receive_hit re-reads the (possibly shared) dict after on_hit_taken, so its
## riders are blanked in place and restored on this fighter's next tick (the dict may be reused by an aura,
## a piercing projectile or the rest of a multi-target melee step).
static func negate_hit(f: Fighter, hit_d: Dictionary, meta_key: StringName) -> void:
	var keys: Array[String] = ["statuses", "stun", "armor_break", "launch", "knockdown", "knockback", "pull", "hitstun"]
	var saved := {}
	for k: String in keys:
		if hit_d.has(k):
			saved[k] = hit_d[k]
	var pend: Array = f.get_meta(meta_key, [])
	pend.append([hit_d, saved])
	f.set_meta(meta_key, pend)
	hit_d["statuses"] = []
	hit_d["stun"] = 0.0
	hit_d["armor_break"] = false
	hit_d["launch"] = 0.0
	hit_d["knockdown"] = false
	hit_d["knockback"] = 0.0
	hit_d["pull"] = false
	hit_d["hitstun"] = 0.0


static func restore_negated(f: Fighter, meta_key: StringName) -> void:
	if not f.has_meta(meta_key):
		return
	for e: Array in f.get_meta(meta_key, []):
		var d: Dictionary = e[0]
		var saved: Dictionary = e[1]
		for k: Variant in saved:
			d[k] = saved[k]
	f.remove_meta(meta_key)


# ================================================================== custom actions
func parry_open(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	var w := float(args.get("window", PARRY_WINDOW))
	f.set_meta(&"striker_parry", w)
	f.add_status(&"super_armor", w, 1.0, f)
	CoreUtil.fx(&"play", [&"cast_glow", f.center(), f.forward(), tint, 0.8])


func parry_close(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	f.set_meta(&"striker_parry", 0.0)
	if bool(runner.vars.get("countered", false)):
		return
	# Nothing to parry: finish with a palm strike so the stance is never wasted.
	f.anim_key = &"punch"
	f.anim_seq += 1
	runner.execute_step({"type": "melee", "range": 2.2, "arc": 90.0, "hit": hit(1.0, {"hitstun": 0.6, "knockback": 3.0})})
