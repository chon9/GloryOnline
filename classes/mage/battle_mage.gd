extends ClassKit
## 战斗法师 Battle Mage (法师系 Mage). Battle lance brawler: launcher -> juggle -> finisher.
## Passives: 炫纹 Chasers (skills spawn up to 7 orbiting elemental orbs; the basic-attack finisher and the
## ultimate fire them as homing magic projectiles, each with its own rider/buff) and 斗者意志 Battle Spirit
## (7 stages driven by the combo counter: attack speed, move speed, physical attack).

const MU := preload("res://classes/mage/_mage_util.gd")
const KU := preload("res://classes/_kit_util.gd")

const MAX_CHASERS: int = 7
## Skill (short id) -> chaser element it generates.
const CHASER_FROM: Dictionary = {
	"dragon_tooth": "neutral",
	"falling_flower_palm": "fire",
	"circle_swing": "shadow",
	"furious_dragon": "light",
	"dragon_breaks_ranks": "ice",
}
const CHASER_COLORS: Dictionary = {
	"neutral": Color(0.85, 0.85, 1.0),
	"ice": Color(0.45, 0.85, 1.0),
	"fire": Color(1.0, 0.45, 0.12),
	"light": Color(1.0, 0.95, 0.45),
	"shadow": Color(0.6, 0.2, 0.95),
}
const SPIRIT_STAGES: int = 7
const SPIRIT_COMBO_PER_STAGE: int = 3


func define() -> void:
	id = "battle_mage"
	name_cn = "战斗法师"
	name_en = "Battle Mage"
	group_id = "mage"
	group_cn = "法师系"
	group_en = "Mage"
	role = "melee"
	weapon_type = "battle_lance"
	weapon_name_cn = "战矛"
	weapon_name_en = "Battle Lance"
	offhand = ""
	model = "battle_mage"
	tint = Color(0.95, 0.4, 0.3)
	famous = "叶修 Ye Xiu / 一叶之秋 One Autumn Leaf / 却邪 Evil Annihilation"
	stats = {"hp": 7600.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 600.0, "matk": 520.0,
		"pdef": 420.0, "mdef": 380.0, "move_speed": 6.4, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: basic lance chain
	var a1 := sk(0, "lance_1", "普攻·突刺", "Lance Thrust", 0.0, 0.0, 0.32, &"attack_stab", 3.0, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_spear"},
		{"t": 0.12, "type": "melee", "range": 3.0, "arc": 60.0, "hit": hit(0.75, {"hitstun": 0.35, "knockback": 1.0})}],
		{"cancel_window": 0.16, "chain": ["lance_1", "lance_2", "lance_3"],
		"desc": "战矛三段连击，第三段发射全部炫纹 Three-hit lance chain; the third hit fires all Chasers."})
	sk(0, "lance_2", "普攻·横扫", "Lance Sweep", 0.0, 0.0, 0.32, &"attack_1h_2", 3.0, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_spear"},
		{"t": 0.12, "type": "melee", "range": 3.0, "arc": 110.0, "hit": hit(0.75, {"hitstun": 0.35, "knockback": 1.0})}],
		{"cancel_window": 0.16, "desc": "横扫 Sweeping second hit."})
	sk(0, "lance_3", "普攻·炫纹突", "Chaser Thrust", 0.0, 0.0, 0.5, &"attack_2h", 3.2, ["melee", "finisher"],
		[{"t": 0.0, "type": "sfx", "name": "swing_spear"},
		{"t": 0.15, "type": "melee", "range": 3.2, "arc": 80.0, "hit": hit(1.0, {"knockback": 4.0, "hitstun": 0.45})},
		{"t": 0.2, "type": "custom", "method": "fire_chasers", "args": {"count": MAX_CHASERS}}],
		{"cancel_window": 0.2, "desc": "重刺并发射全部炫纹 Heavy thrust that launches every stored Chaser."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var sky := sk(1, "sky_strike", "天击", "Sky Strike", 4.0, 40.0, 0.45, &"attack_2h", 2.8,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.12, "type": "melee", "range": 2.8, "arc": 90.0, "fx": "slash_arc",
			"hit": hit(1.4, {"launch": 11.0, "knockback": 0.8, "hitstun": 0.5})},
		{"t": 0.14, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.6}],
		{"cancel_window": 0.25, "desc": "向前突刺并斜向上挑，将目标挑飞 Diagonal upward thrust that launches the target."})

	# ---------------------------------------------------------------- slot 2: Dragon Tooth (stun, neutral chaser)
	var tooth := sk(2, "dragon_tooth", "龙牙", "Dragon Tooth", 5.0, 50.0, 0.35, &"attack_stab", 3.4,
		["melee", "cc", "combo", "interrupt"],
		[{"t": 0.0, "type": "dash", "distance": 1.5, "speed": 20.0, "direction": "target"},
		{"t": 0.12, "type": "melee", "range": 3.4, "arc": 50.0, "fx": "hit_heavy",
			"hit": hit(1.6, {"stun": 0.8, "knockback": 1.0, "hitstun": 0.4})},
		{"t": 0.12, "type": "sfx", "name": "swing_spear"}],
		{"cancel_window": 0.2, "desc": "快速前刺，短暂眩晕，生成无属性炫纹 Fast high-priority stab that stuns briefly; adds a Neutral Chaser."})

	# ---------------------------------------------------------------- slot 3: Falling Flower Palm (blow-away, fire chaser)
	var palm := sk(3, "falling_flower_palm", "落花掌", "Falling Flower Palm", 7.0, 60.0, 0.45, &"punch", 2.6,
		["melee", "finisher", "combo"],
		[{"t": 0.15, "type": "custom", "method": "falling_flower", "args": {"range": 2.6, "arc": 100.0}},
		{"t": 0.15, "type": "sfx", "name": "qi_blast"}],
		{"cancel_window": 0.15, "desc": "掌击将目标击飞，对空中目标伤害更高；生成火炫纹 Palm blast that blows the target away, stronger vs airborne; adds a Fire Chaser."})

	# ---------------------------------------------------------------- slot 4: Circle Swing (360 knockdown, shadow chaser)
	var circle := sk(4, "circle_swing", "圆舞棍", "Circle Swing", 9.0, 70.0, 0.6, &"attack_spin", 3.4,
		["melee", "aoe", "cc"],
		[{"t": 0.0, "type": "sfx", "name": "swing_spin"},
		{"t": 0.2, "type": "melee", "shape": "circle", "range": 3.4, "fx": "slash_arc",
			"hit": hit(1.9, {"knockdown": true, "knockback": 5.0, "armor_break": true})}],
		{"cancel_window": 0.2, "desc": "360度横扫，范围击倒，可破霸体；生成暗炫纹 360-degree sweep that knocks down and breaks super armor; adds a Shadow Chaser."})

	# ---------------------------------------------------------------- slot 5: Furious Dragon Strikes the Heart (piercing lightning spear)
	var furious := sk(5, "furious_dragon", "怒龙穿心", "Furious Dragon Strikes the Heart", 10.0, 80.0, 0.5, &"attack_stab", 6.0,
		["melee", "combo", "aoe"],
		[{"t": 0.05, "type": "vfx", "name": "cast_glow"},
		{"t": 0.2, "type": "ground", "shape": "line", "at": "target", "length": 6.5, "width": 1.4, "visual": "lightning",
			"color": Color(0.6, 0.75, 1.0),
			"hit": hit(2.2, {"type": "magic", "element": "lightning", "knockback": 6.0, "hitstun": 0.55})},
		{"t": 0.2, "type": "vfx", "name": "lightning_strike", "at": "forward", "distance": 3.5},
		{"t": 0.2, "type": "sfx", "name": "lightning_cast"}],
		{"cancel_window": 0.2, "desc": "雷电长矛贯穿前方5米直线 Piercing lightning spear thrust along a 6 m line; adds a Light Chaser."})

	# ---------------------------------------------------------------- slot 6: Dragon Breaks the Ranks (long charge)
	var ranks := sk(6, "dragon_breaks_ranks", "豪龙破军", "Dragon Breaks the Ranks", 13.0, 90.0, 0.7, &"dash", 10.0,
		["gap_closer", "melee", "finisher"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 0.8)]},
		{"t": 0.05, "type": "dash", "distance": 10.0, "speed": 28.0, "direction": "target", "through_enemies": true,
			"hit": hit(2.6, {"knockback": 9.0, "knockdown": true, "hitstun": 0.6})},
		{"t": 0.05, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.1, "desc": "最强物理冲锋，长距离突进击倒 Strongest physical hit: long armored charge that knocks down; adds an Ice Chaser."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var ult := sk(7, "rising_dragon", "伏龙翔天", "Rising Dragon Soars the Sky", 60.0, 250.0, 1.8, &"attack_spin", 4.0,
		["ultimate", "aoe", "melee", "launcher"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.9)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.2, "type": "melee", "shape": "circle", "range": 3.5, "fx": "slash_arc", "hit": hit(1.2, {"launch": 7.0, "knockback": 1.0})},
		{"t": 0.55, "type": "anim", "anim": "attack_2h"},
		{"t": 0.55, "type": "melee", "shape": "circle", "range": 3.5, "height": 3.5, "fx": "slash_arc", "hit": hit(1.2, {"launch": 8.0, "knockback": 1.0})},
		{"t": 1.0, "type": "anim", "anim": "attack_slam"},
		{"t": 1.0, "type": "ground", "at": "self", "radius": 4.5, "visual": "lightning", "height": 4.0,
			"hit": hit(2.4, {"type": "magic", "launch": 10.0, "armor_break": true, "no_recover": true, "element": "lightning"})},
		{"t": 1.05, "type": "custom", "method": "fire_chasers", "args": {"count": MAX_CHASERS}}],
		{"desc": "两段物理挑击后魔法爆炸（带抓取效果），并发射全部炫纹 Two launching sweeps, then an armor-breaking magic explosion; fires all Chasers. Long end lag."})

	skills = [a1, sky, tooth, palm, circle, furious, ranks, ult]

	passives = [
		{"name_cn": "炫纹", "name_en": "Chasers",
			"desc": "龙牙/落花掌/圆舞棍/怒龙穿心/豪龙破军生成元素炫纹（最多7个）环绕自身；普攻第三段与大招将其作为追踪魔法弹发射：无属性=攻击提升、冰=减速、火=灼烧、光=加速、暗=破防 "
				+ "Skills spawn elemental orbs (max 7) that orbit you; the basic finisher and the ultimate fire them as homing magic bolts: Neutral = attack up, Ice = slow, Fire = burn, Light = haste, Shadow = defense down."},
		{"name_cn": "斗者意志", "name_en": "Battle Spirit",
			"desc": "连击数每3击提升一阶（最多7阶），每阶攻速+4%、移速+2%、物攻+3% Every 3 combo hits raise a stage (max 7): +4% attack speed, +2% move speed, +3% physical attack per stage."},
	]


# ================================================================== hooks
func on_spawn(f: Fighter) -> void:
	MU.setv(f, "chasers", [])
	MU.setv(f, "orbit_t", 0.0)
	MU.setv(f, "stage", 0)
	_spirit_bonus(f, 0)


## 斗者意志 Battle Spirit stat shares, written additively (only this passive's own share of each key).
func _spirit_bonus(f: Fighter, stage: int) -> void:
	KU.set_bonus_share(f, "atk_speed", &"mage_bm_spirit_aspd", 0.04 * stage)
	KU.set_bonus_share(f, "move_speed", &"mage_bm_spirit_move", 0.02 * stage)
	KU.set_bonus_share(f, "patk", &"mage_bm_spirit_patk", 0.03 * stage)


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	var short := str(skill.id).trim_prefix(id + ".")
	if CHASER_FROM.has(short):
		add_chaser(f, str(CHASER_FROM[short]))


func on_tick(f: Fighter, delta: float) -> void:
	# 斗者意志 Battle Spirit: stage from the live combo counter.
	var stage := clampi(f.combo_count / SPIRIT_COMBO_PER_STAGE, 0, SPIRIT_STAGES)
	if stage != int(MU.getv(f, "stage", 0)):
		MU.setv(f, "stage", stage)
		_spirit_bonus(f, stage)
		if stage > 0 and stage % 2 == 1:
			CoreUtil.fx(&"play", [&"buff_aura", f.global_position, f.forward(), tint, 0.5 + 0.08 * stage])
	# 炫纹 Chasers orbit visual (one cheap cosmetic event every 0.6 s while orbs are held).
	var chasers: Array = MU.getv(f, "chasers", [])
	if chasers.is_empty():
		return
	var t := float(MU.getv(f, "orbit_t", 0.0)) - delta
	if t <= 0.0:
		t = 0.6
		var el := str(chasers[chasers.size() - 1])
		var ang := f._time * 3.0
		var pos := f.center() + Vector3(cos(ang), 0.35, sin(ang)) * 0.9
		CoreUtil.fx(&"play", [&"cast_glow", pos, Vector3.UP, CHASER_COLORS.get(el, tint), 0.35 + 0.06 * chasers.size()])
	MU.setv(f, "orbit_t", t)


func on_death(f: Fighter, _killer: Fighter) -> void:
	MU.setv(f, "chasers", [])


# ================================================================== chasers
func chaser_count(f: Fighter) -> int:
	var c: Array = MU.getv(f, "chasers", [])
	return c.size()


func add_chaser(f: Fighter, element: String) -> void:
	var c: Array = (MU.getv(f, "chasers", []) as Array).duplicate()
	if c.size() >= MAX_CHASERS:
		c.pop_front()
	c.append(element)
	MU.setv(f, "chasers", c)
	CoreUtil.fx(&"play", [&"cast_glow", f.center() + Vector3.UP * 0.4, Vector3.UP, CHASER_COLORS.get(element, tint), 0.4])


## Custom action: fires up to args.count stored chasers as homing magic projectiles.
func fire_chasers(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var c: Array = (MU.getv(f, "chasers", []) as Array).duplicate()
	var n := mini(int(args.get("count", 1)), c.size())
	if n <= 0:
		return
	for i in n:
		var el := str(c.pop_front())
		var h := hit(0.5, {"type": "magic", "hitstun": 0.2, "knockback": 0.5, "juggle_cost": 4.0, "chaser": el})
		match el:
			"ice":
				h["statuses"] = [st("slow", 3.0, 0.5)]
				h["element"] = "ice"
			"fire":
				h["statuses"] = [st("burn", 3.0, 1.0)]
				h["element"] = "fire"
			"shadow":
				h["statuses"] = [st("def_down", 5.0, 0.15)]
				h["element"] = "dark"
			"light":
				h["element"] = "holy"
		runner.execute_step({"type": "projectile", "speed": 20.0, "range": 18.0, "radius": 0.45, "homing": 7.0,
			"aim": "target", "from": "center", "visual": "orb", "color": CHASER_COLORS.get(el, tint), "scale": 0.6,
			"spread": 0.0, "sfx": "fire_cast", "hit": h})
		# Self buff granted by firing the orb.
		match el:
			"neutral":
				f.add_status(&"atk_up", 5.0, 0.1, f)
			"light":
				f.add_status(&"haste", 4.0, 0.2, f)
	MU.setv(f, "chasers", c)


# ================================================================== custom skills
## 落花掌 Falling Flower Palm: blow-away palm, extra damage against airborne targets.
func falling_flower(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var targets := MU.cone_targets(runner, float(args.get("range", 2.6)), float(args.get("arc", 100.0)))
	for e: Fighter in targets:
		var air := e.is_airborne()
		var h := hit(2.6 if air else 1.8, {"knockback": 12.0, "launch": 4.0, "knockdown": true, "hitstun": 0.5})
		runner.deal(e, h, f.global_position)
	CoreUtil.fx(&"play", [&"hit_heavy", f.center() + f.forward() * 1.5, f.forward(), Color(1.0, 0.6, 0.6), 1.2])
