extends ClassKit
## 元素法师 Elementalist (法师系 Mage). Long-range magic artillery and zone control.
## Passive: 移动施法 Mobile Cast - every skill can be cast while moving (move_while_casting).

const C_FIRE := Color(1.0, 0.45, 0.12)
const C_ICE := Color(0.5, 0.85, 1.0)
const C_BOLT := Color(0.6, 0.72, 1.0)
const C_ARCANE := Color(0.75, 0.55, 1.0)


func define() -> void:
	id = "elementalist"
	name_cn = "元素法师"
	name_en = "Elementalist"
	group_id = "mage"
	group_cn = "法师系"
	group_en = "Mage"
	role = "ranged"
	weapon_type = "staff"
	weapon_name_cn = "法杖"
	weapon_name_en = "Magic Staff"
	offhand = ""
	model = "elementalist"
	tint = Color(1.0, 0.5, 0.15)
	famous = "楚云秀 Chu Yunxiu / 风城烟雨 Windy Rain / 银武法杖 Ravaging Wind"
	stats = {"hp": 6200.0, "mp": 1500.0, "mp_regen": 22.0, "patk": 450.0, "matk": 450.0,
		"pdef": 280.0, "mdef": 450.0, "move_speed": 6.0, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	var mob := {"move_while_casting": true}

	# ---------------------------------------------------------------- slot 0: staff bolts
	var b1 := sk(0, "bolt_1", "普攻·法弹", "Staff Bolt", 0.0, 0.0, 0.35, &"cast", 16.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "speed": 26.0, "range": 17.0, "radius": 0.35, "aim": "target", "visual": "orb",
			"color": C_ARCANE, "sfx": "magic_bolt", "hit": hit(0.4, {"type": "magic", "hitstun": 0.2, "knockback": 0.8})}],
		_x(mob, {"cancel_window": 0.05, "chain": ["bolt_1", "bolt_2", "bolt_3"],
		"desc": "法杖三段魔法弹，可移动施放 Three-shot magic bolt chain, castable while moving."}))
	sk(0, "bolt_2", "普攻·法弹二", "Staff Bolt II", 0.0, 0.0, 0.35, &"attack_1h_2", 16.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "speed": 26.0, "range": 17.0, "radius": 0.35, "aim": "target", "visual": "orb",
			"color": C_ARCANE, "sfx": "magic_bolt", "hit": hit(0.4, {"type": "magic", "hitstun": 0.2, "knockback": 0.8})}],
		_x(mob, {"cancel_window": 0.05, "desc": "第二发魔法弹 Second bolt."}))
	sk(0, "bolt_3", "普攻·爆裂法弹", "Bursting Bolt", 0.0, 0.0, 0.45, &"cast", 16.0, ["ranged", "finisher"],
		[{"t": 0.15, "type": "projectile", "speed": 24.0, "range": 17.0, "radius": 0.45, "aim": "target", "visual": "orb",
			"color": C_FIRE, "scale": 1.4, "sfx": "magic_bolt",
			"hit": hit(0.6, {"type": "magic", "hitstun": 0.3, "knockback": 4.0, "element": "fire"})}],
		_x(mob, {"cancel_window": 0.15, "desc": "较大的爆裂法弹，击退 Bigger bursting bolt with knockback."}))

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var power := sk(1, "elemental_power", "元素之力", "Elemental Power", 4.0, 40.0, 0.5, &"cast", 12.0,
		["launcher", "ranged", "combo", "aoe"],
		[{"t": 0.05, "type": "vfx", "name": "cast_glow"},
		{"t": 0.15, "type": "ground", "at": "target", "radius": 2.2, "delay": 0.35, "visual": "rune", "color": C_ARCANE,
			"hit": hit(1.3, {"type": "magic", "launch": 10.0, "knockback": 0.3})}],
		_x(mob, {"cancel_window": 0.2, "desc": "在目标处生成元素力场，延迟后将敌人挑飞 Slow-cast element field that knocks enemies up."}))

	# ---------------------------------------------------------------- slot 2: Piercing Lightning
	var pierce := sk(2, "piercing_lightning", "雷电贯穿", "Piercing Lightning", 5.0, 50.0, 0.35, &"shoot_1h", 18.0,
		["ranged", "combo", "interrupt"],
		[{"t": 0.1, "type": "projectile", "speed": 45.0, "range": 19.0, "radius": 0.5, "pierce": true, "aim": "target",
			"visual": "lightning", "color": C_BOLT, "sfx": "lightning_cast",
			"hit": hit(1.6, {"type": "magic", "element": "lightning", "hitstun": 0.5, "knockback": 1.5})}],
		_x(mob, {"cancel_window": 0.15, "desc": "快速直线闪电，贯穿路径上所有敌人 Fast straight lightning bolt that pierces every enemy in line."}))

	# ---------------------------------------------------------------- slot 3: Raging Flames
	var flames := sk(3, "raging_flames", "烈焰冲击", "Raging Flames", 7.0, 70.0, 0.5, &"cast", 12.0,
		["ranged", "launcher", "combo", "aoe"],
		[{"t": 0.05, "type": "vfx", "name": "cast_glow", "color": C_FIRE},
		{"t": 0.15, "type": "ground", "at": "target", "radius": 1.6, "delay": 0.25, "visual": "fire", "color": C_FIRE,
			"hit": hit(1.9, {"type": "magic", "element": "fire", "launch": 9.0, "knockback": 0.3, "statuses": [st("burn", 3.0, 1.0)]})},
		{"t": 0.4, "type": "sfx", "name": "fire_cast", "at": "target"}],
		_x(mob, {"cancel_window": 0.2, "desc": "目标处喷发3米火柱，挑飞并灼烧 Fire column at the target point that launches and burns."}))

	# ---------------------------------------------------------------- slot 4: Blizzard
	var blizzard := sk(4, "blizzard", "暴风雪", "Blizzard", 12.0, 100.0, 0.6, &"cast", 12.0,
		["ranged", "aoe", "zone", "cc"],
		[{"t": 0.05, "type": "vfx", "name": "cast_glow", "color": C_ICE},
		{"t": 0.2, "type": "ground", "at": "target", "radius": 4.0, "duration": 4.0, "tick": 1.0, "visual": "ice", "color": C_ICE,
			"hit": hit(0.5, {"type": "magic", "element": "ice", "hitstun": 0.2, "knockback": 0.0, "statuses": [st("slow", 2.0, 0.5)]})},
		{"t": 0.2, "type": "sfx", "name": "ice_cast", "at": "target"}],
		_x(mob, {"cancel_window": 0.25, "desc": "4秒冰雹区域，每秒伤害并减速 4 s hail zone: damage every second and 50% slow."}))

	# ---------------------------------------------------------------- slot 5: Ice Line
	var ice_line := sk(5, "ice_line", "冰线", "Ice Line", 10.0, 70.0, 0.4, &"cast", 9.0,
		["ranged", "zone", "cc"],
		[{"t": 0.15, "type": "ground", "shape": "line", "at": "target", "length": 9.0, "width": 1.0, "duration": 5.0, "tick": 0.2,
			"max_hits": 1, "visual": "ice", "color": C_ICE,
			"hit": hit(0.8, {"type": "magic", "element": "ice", "hitstun": 0.1, "knockback": 0.0, "statuses": [st("freeze", 1.5)]})},
		{"t": 0.15, "type": "sfx", "name": "ice_cast"}],
		_x(mob, {"cancel_window": 0.2, "desc": "画出持续5秒的冰线，触碰者被冻结 Draws a 5 s ice line; anyone touching it is frozen."}))

	# ---------------------------------------------------------------- slot 6: Teleport
	var tele := sk(6, "teleport", "瞬间移动", "Teleport", 12.0, 60.0, 0.15, &"dash", 8.0,
		["escape", "defensive"],
		[{"t": 0.0, "type": "blink", "to": "back", "distance": 8.0},
		{"t": 0.0, "type": "sfx", "name": "blink"}],
		_x(mob, {"desc": "瞬移拉开距离 Instant blink away to reset spacing."}))

	# ---------------------------------------------------------------- slot 7: ultimate
	var ult := sk(7, "heaven_earth", "天雷地火", "Heavenly Lightning Earthen Fire", 75.0, 300.0, 1.6, &"cast", 12.0,
		["ultimate", "aoe", "ranged", "zone"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.7)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 5.0, "duration": 3.0, "tick": 0.5, "visual": "fire", "color": C_FIRE,
			"hit": hit(0.3, {"type": "magic", "element": "fire", "hitstun": 0.15, "knockback": 0.0, "statuses": [st("burn", 3.0, 1.0)]})},
		{"t": 0.4, "type": "ground", "at": "target", "radius": 3.5, "delay": 0.3, "visual": "lightning", "color": C_BOLT,
			"hit": hit(0.9, {"type": "magic", "element": "lightning", "hitstun": 0.5, "knockback": 1.0})},
		{"t": 0.8, "type": "ground", "at": "target", "radius": 3.5, "delay": 0.3, "visual": "lightning", "color": C_BOLT,
			"hit": hit(0.9, {"type": "magic", "element": "lightning", "hitstun": 0.5, "knockback": 1.0})},
		{"t": 1.2, "type": "ground", "at": "target", "radius": 3.5, "delay": 0.3, "visual": "lightning", "color": C_BOLT,
			"hit": hit(0.9, {"type": "magic", "element": "lightning", "launch": 7.0, "knockback": 1.0})},
		{"t": 1.5, "type": "sfx", "name": "thunder", "at": "target"}],
		_x(mob, {"desc": "大范围天降雷击与地火灼烧 Huge area: three sky lightning strikes over a field of earthen fire."}))

	skills = [b1, power, pierce, flames, blizzard, ice_line, tele, ult]

	passives = [
		{"name_cn": "移动施法", "name_en": "Mobile Cast",
			"desc": "所有技能可边移动边施放（施法时移速70%） Every skill can be cast while moving (70% move speed while casting)."},
	]


## Merge helper for the shared "extra" flags.
func _x(base: Dictionary, more: Dictionary) -> Dictionary:
	var d := base.duplicate()
	for k: Variant in more:
		d[k] = more[k]
	return d


# ================================================================== hooks
## 移动施法 Mobile Cast is data-driven (move_while_casting on every skill); this guard keeps it true even if a
## skill def is edited later, so the passive cannot silently regress.
func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if not skill.move_while_casting:
		skill.move_while_casting = true
	if skill.slot == 6:
		CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), C_ARCANE, 1.0])
