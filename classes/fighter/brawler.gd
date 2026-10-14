extends ClassKit
## 流氓 Brawler (格斗系 Fighter). Dirty-fighting melee controller: Uppercut launcher, Strangle hold that weakens,
## Brick Buster dizzy (stronger from behind), Sand Toss blind, Molotov fire bottle, Tyrannical Chain Punch pin-and-punch,
## Tooth for Tooth ultimate that throws the last skill you were hit by back at the enemy.
## Passive 涂毒 Apply Poison: claw strikes poison the target.

const POISON_DUR: float = 4.0
const POISON_POWER: float = 0.5
const CLAW_KEY: String = "brawler_claw"
const T4T_BOOST: float = 0.3
const T4T_META: StringName = &"brawler_t4t_skill"


func define() -> void:
	id = "brawler"
	name_cn = "流氓"
	name_en = "Brawler"
	group_id = "fighter"
	group_cn = "格斗系"
	group_en = "Fighter"
	role = "control"
	weapon_type = "claws"
	weapon_name_cn = "爪"
	weapon_name_en = "Claws"
	offhand = ""
	model = "brawler"
	tint = Color(0.6, 0.85, 0.25)
	famous = "唐昊 Tang Hao / 唐三打 Demon Subduer; 包荣兴 Bao Rongxing / 包子入侵 Steamed Bun Invasion"
	stats = {"hp": 7900.0, "mp": 1100.0, "mp_regen": 20.0, "patk": 600.0, "matk": 400.0,
		"pdef": 420.0, "mdef": 380.0, "move_speed": 6.4, "jump_velocity": 9.0, "atk_speed": 1.05}

	# ---------------------------------------------------------------- slot 0: basic chain 普攻
	var b1 := sk(0, "claw_swipe", "爪击", "Basic: Claw Swipe", 0.0, 0.0, 0.28, &"attack_1h_1", 2.0, ["melee", "combo"],
		[{"t": 0.09, "type": "melee", "range": 2.0, "arc": 110.0, "hit": hit(0.7, {"hitstun": 0.35, "knockback": 0.8, CLAW_KEY: true})},
		{"t": 0.05, "type": "sfx", "name": "swing_claw"}],
		{"cancel_window": 0.14, "chain": ["claw_swipe", "claw_rake", "knee_attack"], "desc": "利爪横扫 Raking claw swipe."})
	sk(0, "claw_rake", "反手爪", "Basic: Claw Rake", 0.0, 0.0, 0.3, &"attack_1h_2", 2.0, ["melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.0, "arc": 110.0, "hit": hit(0.7, {"hitstun": 0.38, "knockback": 1.0, CLAW_KEY: true})},
		{"t": 0.05, "type": "sfx", "name": "swing_claw"}],
		{"cancel_window": 0.15, "desc": "反手抓挠 Backhand claw rake."})
	sk(0, "knee_attack", "膝撞", "Basic: Knee Attack", 0.0, 0.0, 0.4, &"kick", 2.0, ["melee", "finisher"],
		[{"t": 0.15, "type": "melee", "range": 2.0, "arc": 100.0, "hit": hit(0.9, {"knockback": 4.5, "hitstun": 0.5})},
		{"t": 0.12, "type": "sfx", "name": "kick"}],
		{"cancel_window": 0.18, "desc": "膝撞收尾 Knee strike finisher."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var uppercut := sk(1, "uppercut", "勾拳", "Uppercut", 4.0, 40.0, 0.42, &"attack_2h", 2.2, ["launcher", "melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.2, "arc": 100.0, "hit": hit(1.4, {"launch": 10.5, "knockback": 0.6, CLAW_KEY: true})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.2},
		{"t": 0.08, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.22, "desc": "Lv1 上勾拳挑空 Lv1 rising uppercut that launches."})

	# ---------------------------------------------------------------- slot 2: Strangle
	var strangle := sk(2, "strangle", "锁喉", "Strangle", 10.0, 60.0, 1.0, &"grab", 1.9, ["grab", "cc", "debuff", "melee"],
		[{"t": 0.08, "type": "grab", "range": 1.9, "grab_time": 1.4, "throw": {"dir": "forward", "force": 4.0},
			"hit": hit(1.6, {"knockdown": true, "knockback": 2.0, "statuses": [st("def_down", 5.0, 0.4), st("slow", 5.0, 0.3)]})},
		{"t": 0.08, "type": "sfx", "name": "grab"}],
		{"cancel_window": 0.1, "desc": "Lv15 锁喉控住1.4秒，之后敌人防御降低40%、减速 Lv15 neck hold; afterwards the victim's defense drops 40% and it is slowed."})

	# ---------------------------------------------------------------- slot 3: Brick Buster
	var brick := sk(3, "brick_buster", "砖袭", "Brick Buster", 8.0, 55.0, 0.5, &"attack_slam", 2.2, ["cc", "melee", "interrupt"],
		[{"t": 0.2, "type": "custom", "method": "brick_buster", "args": {"range": 2.2}},
		{"t": 0.2, "type": "sfx", "name": "stomp"}],
		{"cancel_window": 0.15, "desc": "Lv20 板砖拍头造成眩晕，背后拍更久 Lv20 brick to the head: dizzy, longer from behind."})

	# ---------------------------------------------------------------- slot 4: Sand Toss
	var sand := sk(4, "sand_toss", "抛沙", "Sand Toss", 9.0, 45.0, 0.4, &"throw", 4.5, ["debuff", "cc", "aoe"],
		[{"t": 0.12, "type": "melee", "range": 4.5, "arc": 70.0, "fx": "smoke", "color": Color(0.85, 0.75, 0.5),
			"hit": hit(0.4, {"hitstun": 0.6, "knockback": 0.5, "statuses": [st("blind", 4.0)]})},
		{"t": 0.12, "type": "sfx", "name": "earth_light"}],
		{"cancel_window": 0.15, "desc": "Lv20 扬沙致盲（4秒） Lv20 throws sand in the face: blinds for 4 s."})

	# ---------------------------------------------------------------- slot 5: Molotov
	var molotov := sk(5, "molotov", "燃烧瓶", "Molotov", 9.0, 60.0, 0.45, &"throw", 12.0, ["ranged", "aoe", "debuff"],
		[{"t": 0.15, "type": "projectile", "speed": 15.0, "range": 14.0, "radius": 0.35, "gravity": 18.0, "aim": "target",
			"visual": "flask", "color": Color(1.0, 0.5, 0.15), "sfx": "throw_light",
			"hit": hit(0.8, {"knockback": 2.0, "statuses": [st("burn", 4.0, 1.0)]}),
			"explode": {"radius": 2.6, "hit": hit(0.6, {"element": "fire", "hitstun": 0.4, "statuses": [st("burn", 4.0, 1.0)]})}}],
		{"cancel_window": 0.15, "desc": "扔出燃烧瓶，爆炸并点燃范围内敌人 Thrown fire bottle that bursts and sets foes ablaze."})

	# ---------------------------------------------------------------- slot 6: Tyrannical Chain Punch
	var chain_punch := sk(6, "chain_punch", "霸王连拳", "Tyrannical Chain Punch", 11.0, 70.0, 1.35, &"punch_combo", 1.9,
		["grab", "melee", "finisher"],
		[{"t": 0.08, "type": "grab", "range": 1.9, "grab_time": 1.0, "end_on_miss": true, "throw": {"dir": "forward", "force": 6.0},
			"hit": hit(1.3, {"knockdown": true, "knockback": 3.0})},
		{"t": 0.25, "type": "multi_melee", "range": 2.0, "arc": 60.0, "count": 5, "interval": 0.15, "max_targets": 1, "fx": "hit_spark",
			"hit": hit(0.3, {"hitstun": 0.0, "knockback": 0.0, "juggle_cost": 2.0, CLAW_KEY: true})},
		{"t": 0.08, "type": "sfx", "name": "grab"}],
		{"cancel_window": 0.1, "desc": "按住敌人连续猛揍后击倒 Pins the enemy and pummels it before knocking it down."})

	# ---------------------------------------------------------------- slot 7: ultimate (Tooth for Tooth)
	var t4t := sk(7, "tooth_for_tooth", "以牙还牙", "Tooth for Tooth", 50.0, 200.0, 1.5, &"punch_combo", 3.0,
		["ultimate", "melee", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "custom", "method": "tooth_for_tooth", "args": {}},
		{"t": 0.05, "type": "buff", "target": "self", "fx": "cast_glow", "statuses": [st("super_armor", 1.6)]},
		{"t": 0.05, "type": "dash", "direction": "target", "distance": 4.0, "speed": 26.0},
		{"t": 0.3, "type": "multi_melee", "range": 2.3, "arc": 120.0, "count": 6, "interval": 0.12, "fx": "slash_arc",
			"hit": hit(0.45, {"hitstun": 0.45, "knockback": 0.3, "juggle_cost": 4.0, CLAW_KEY: true})},
		{"t": 1.1, "type": "melee", "range": 2.5, "arc": 140.0, "fx": "hit_heavy",
			"hit": hit(2.0, {"knockdown": true, "knockback": 8.0, "armor_break": true})}],
		{"cancel_window": 0.2, "desc": "Lv75 大招：以对方最后打中你的技能还击（威力+30%）；未记录时疯狂爪击 Lv75 copies the last skill that hit you and throws it back 30% stronger; otherwise a savage claw flurry."})

	skills = [b1, uppercut, strangle, brick, sand, molotov, chain_punch, t4t]
	passives = [
		{"name_cn": "涂毒", "name_en": "Apply Poison",
			"desc": "爪击附带中毒（4秒） Claw strikes poison the target for 4 s."},
		{"name_cn": "以牙还牙", "name_en": "Tooth for Tooth",
			"desc": "记住最后一个打中你的敌方技能，大招可原样奉还 Remembers the last enemy skill that hit you; the ultimate returns it."},
	]


# ================================================================== hooks
func on_hit_dealt(f: Fighter, victim: Fighter, hit_d: Dictionary, dmg: float) -> void:
	if dmg > 0.0 and bool(hit_d.get(CLAW_KEY, false)) and victim != null and victim.is_alive():
		# CORE guarded on-hit status: a frontally blocked claw does not poison.
		apply_on_hit_status(f, victim, hit_d, &"poison", POISON_DUR, POISON_POWER)


func on_hit_taken(f: Fighter, src: Fighter, _hit_d: Dictionary, dmg: float) -> float:
	if src == null or not is_instance_valid(src) or src == f or src.runner == null:
		return dmg
	var s := src.runner.skill
	if s != null and _copyable(s):
		f.set_meta(T4T_META, s)
	return dmg


## A skill can be copied when every step is a plain built-in action (no kit-specific custom/summon code).
func _copyable(s: SkillDef) -> bool:
	if s.id.begins_with(id + "."):
		return false
	for step: Dictionary in s.steps:
		var tp := str(step.get("type", ""))
		if tp == "custom" or tp == "summon" or tp == "":
			return false
		if SkillRunner.custom_actions.has(tp):
			return false
	return not s.steps.is_empty()


# ================================================================== custom actions
## 以牙还牙: replays the remembered enemy skill (boosted). Falls through to the claw flurry when nothing is stored.
func tooth_for_tooth(f: Fighter, _args: Dictionary, _runner: SkillRunner) -> void:
	if not f.has_meta(T4T_META):
		return
	var v: Variant = f.get_meta(T4T_META)
	if not (v is SkillDef):
		return
	var s: SkillDef = v
	f.remove_meta(T4T_META)
	f.add_status(&"atk_up", s.total_time() + 0.6, T4T_BOOST, f)
	f.add_status(&"super_armor", minf(s.total_time() + 0.2, 2.5), 1.0, f)
	CoreUtil.fx(&"play", [&"dark_burst", f.center(), f.forward(), tint, 1.2])
	f.start_skill(s, 7)


## 砖袭: dizzy (stun) on hit; from behind the dizzy lasts much longer.
func brick_buster(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var p := {"range": float(args.get("range", 2.2)), "arc": 90.0, "max_targets": 1}
	var fwd := f.forward()
	for e: Fighter in runner.enemies():
		var to := CoreUtil.flat(e.global_position - f.global_position)
		if to.length() - e.radius() > float(p["range"]) or absf(e.center().y - f.center().y) > 2.0:
			continue
		if to.length() > 0.7 and rad_to_deg(fwd.angle_to(to.normalized())) > float(p["arc"]) * 0.5:
			continue
		var back := Combat.is_back_attack(e, f.global_position)
		var h := hit(1.6, {"knockback": 2.0, "stun": 3.5 if back else 2.0, "hitstun": 0.4})
		runner.deal(e, Hit.normalize(h), f.global_position)
		CoreUtil.fx(&"play", [&"hit_heavy", e.center() + Vector3.UP * 0.6, fwd, Color(0.8, 0.35, 0.25), 1.0])
		break
