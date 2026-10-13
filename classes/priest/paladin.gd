extends ClassKit
## 守护天使 Paladin (圣职系 Priest) - off-tank / hybrid healer with a two-handed Axe.
## Signature mechanics: super armor on its heavy axe skills, Holy Shield full block, heal-over-time
## support (恢复术 / 生命激活), damage dealt splashes healing on the weakest nearby ally, and Angel's Might,
## a 360-degree push-back aura that ignores super armor.

const HOLY_LIGHT_FRACTION: float = 0.12      # share of damage dealt that heals the weakest ally nearby
const HOLY_LIGHT_RADIUS: float = 10.0
const ARMORED_SKILLS: Array[String] = ["paladin.holy_light_strike", "paladin.halo_smash", "paladin.atk3", "paladin.angels_might"]


func define() -> void:
	id = "paladin"
	name_cn = "守护天使"
	name_en = "Paladin"
	group_id = "priest"
	group_cn = "圣职系"
	group_en = "Priest"
	role = "tank"
	weapon_type = "great_axe"
	weapon_name_cn = "巨斧"
	weapon_name_en = "Axe (two-handed)"
	offhand = ""
	model = "paladin"
	tint = Color(1.0, 0.82, 0.32)
	famous = "徐景熙 Xu Jingxi (轮回 Samsara) / 灵魂语者 Soul Speaker"
	stats = {"hp": 8800.0, "mp": 1300.0, "mp_regen": 20.0, "patk": 540.0, "matk": 520.0,
		"pdef": 520.0, "mdef": 520.0, "move_speed": 5.8, "jump_velocity": 8.8, "weight": 1.2,
		"cast_speed": 1.0, "atk_speed": 0.85}

	# ------------------------------------------------------------ slot 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·斧劈", "Basic Attack: Axe Chop", 0.0, 0.0, 0.42, &"attack_2h", 2.8, ["melee", "combo"],
		[{"t": 0.16, "type": "melee", "range": 2.8, "arc": 110.0, "hit": hit(0.85, {"hitstun": 0.4, "knockback": 1.2})},
		{"t": 0.14, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "巨斧下劈 Heavy axe chop."})
	sk(0, "atk2", "普攻·横扫", "Basic Attack: Axe Sweep", 0.0, 0.0, 0.42, &"attack_1h_2", 2.8, ["melee", "combo"],
		[{"t": 0.16, "type": "melee", "range": 2.8, "arc": 140.0, "hit": hit(0.85, {"hitstun": 0.4, "knockback": 1.2})},
		{"t": 0.14, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.15, "desc": "巨斧横扫 Wide axe sweep."})
	sk(0, "atk3", "普攻·重砸", "Basic Attack: Axe Slam", 0.0, 0.0, 0.58, &"attack_slam", 2.6, ["melee", "finisher"],
		[{"t": 0.26, "type": "melee", "range": 2.6, "arc": 90.0, "fx": "hit_heavy",
		"hit": hit(1.15, {"knockdown": true, "knockback": 3.0})},
		{"t": 0.26, "type": "sfx", "name": "hit_heavy"}],
		{"cancel_window": 0.12, "desc": "霸体重砸击倒 Super-armored overhead slam that knocks down."})

	# ------------------------------------------------------------ slot 1: launcher
	var holy_strike := sk(1, "holy_light_strike", "圣光打", "Holy Light Strike", 6.0, 45.0, 0.5, &"attack_2h", 2.8,
		["launcher", "melee", "combo"],
		[{"t": 0.16, "type": "melee", "range": 2.8, "arc": 100.0, "fx": "launch_burst",
		"hit": hit(0.85, {"launch": 9.5, "knockback": 0.6})},
		{"t": 0.3, "type": "melee", "range": 3.0, "arc": 100.0, "fx": "holy_burst",
		"hit": hit(0.7, {"type": "magic", "element": "holy", "knockback": 0.4})},
		{"t": 0.16, "type": "sfx", "name": "metal"}],
		{"cancel_window": 0.18, "desc": "物理挑斩接圣光追击，将敌人击飞 Physical upswing plus a holy follow-up that launches."})

	# ------------------------------------------------------------ slot 2: Rising Emblem (Priest Lv1)
	var rising := sk(2, "rising_emblem", "升天阵", "Rising Emblem", 8.0, 45.0, 0.4, &"cast", 8.0,
		["launcher", "aoe", "ranged", "combo"],
		[{"t": 0.12, "type": "ground", "at": "target", "radius": 2.3, "delay": 0.25, "visual": "holy",
		"hit": hit(1.05, {"type": "magic", "launch": 10.0, "knockback": 0.0, "element": "holy"})},
		{"t": 0.1, "type": "sfx", "name": "magic"}],
		{"cancel_window": 0.15, "desc": "圣职基础技：法阵将敌人击飞 Priest Lv1 rune circle that launches the target."})

	# ------------------------------------------------------------ slot 3: Halo Smash
	var halo := sk(3, "halo_smash", "光环砸击", "Halo Smash", 8.0, 55.0, 0.6, &"attack_slam", 3.2,
		["melee", "aoe", "finisher", "cc"],
		[{"t": 0.3, "type": "ground", "at": "forward", "distance": 1.6, "radius": 3.0, "visual": "holy",
		"hit": hit(1.9, {"knockdown": true, "knockback": 3.5, "otg": true})},
		{"t": 0.3, "type": "sfx", "name": "earth"}],
		{"cancel_window": 0.15, "desc": "霸体光环重砸地面，击倒范围敌人（可追打倒地）Super-armored halo slam that knocks down (hits downed foes)."})

	# ------------------------------------------------------------ slot 4: Recovery (HoT)
	var recovery := sk(4, "recovery", "恢复术", "Recovery", 10.0, 70.0, 0.35, &"heal", 12.0,
		["heal", "buff_ally"],
		[{"t": 0.15, "type": "heal", "target": "ally_lowest", "radius": 12.0, "amount": 0.05, "hot": {"dur": 18.0, "power": 0.0045}},
		{"t": 0.15, "type": "sfx", "name": "heal"}],
		{"cancel_window": 0.1, "desc": "为血量最低的队友施加18秒持续恢复 Heal over time on the lowest-HP ally for 18 s."})

	# ------------------------------------------------------------ slot 5: Holy Shield
	var holy_shield := sk(5, "holy_shield", "圣盾术", "Holy Shield", 14.0, 60.0, 0.2, &"block", 0.0,
		["defensive", "buff_self"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", 2.0, 1.0)], "shield": 0.08, "shield_dur": 2.5,
		"fx": "holy_burst"},
		{"t": 0.0, "type": "sfx", "name": "block"}],
		{"desc": "短暂完全格挡正面攻击并获得圣光护盾 Brief full frontal block plus a holy shield."})

	# ------------------------------------------------------------ slot 6: Life Activation
	var life := sk(6, "life_activation", "生命激活", "Life Activation", 16.0, 80.0, 0.4, &"heal", 10.0,
		["heal", "buff_ally", "buff_self"],
		[{"t": 0.15, "type": "buff", "target": "allies", "radius": 10.0, "statuses": [st("regen", 8.0, 0.010), st("def_up", 8.0, 0.1)]},
		{"t": 0.15, "type": "vfx", "name": "heal_burst", "scale": 2.0},
		{"t": 0.15, "type": "sfx", "name": "buff"}],
		{"desc": "激活周围队友生命力，持续回血并小幅提升防御 Allies nearby regenerate HP and gain a little defence."})

	# ------------------------------------------------------------ slot 7: ultimate - Angel's Might
	var might := sk(7, "angels_might", "天使威光", "Angel's Might", 50.0, 200.0, 1.3, &"cast_long", 5.0,
		["ultimate", "aoe", "cc", "defensive", "interrupt", "heal"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.6)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.3, "type": "ground", "at": "self", "radius": 4.5, "visual": "holy",
		"hit": hit(1.4, {"type": "magic", "element": "holy", "knockback": 9.0, "hitstun": 0.6, "armor_break": true})},
		{"t": 0.75, "type": "ground", "at": "self", "radius": 5.5, "visual": "holy",
		"hit": hit(1.4, {"type": "magic", "element": "holy", "knockback": 11.0, "hitstun": 0.6, "armor_break": true})},
		{"t": 1.1, "type": "ground", "at": "self", "radius": 6.5, "visual": "holy",
		"hit": hit(1.6, {"type": "magic", "element": "holy", "knockback": 13.0, "launch": 6.0, "armor_break": true})},
		{"t": 1.1, "type": "heal", "target": "allies", "radius": 8.0, "amount": 0.08},
		{"t": 1.1, "type": "sfx", "name": "explosion"}],
		{"desc": "360度天使威光三连震，无视霸体推开敌人并治疗周围队友 Three 360-degree holy pulses that push back through super armor and heal allies."})

	skills = [atk1, holy_strike, rising, halo, recovery, holy_shield, life, might]

	passives = [
		{"name_cn": "霸体", "name_en": "Super Armor",
		"desc": "圣光打、光环砸击、重砸与天使威光施放期间霸体 Holy Light Strike, Halo Smash, Axe Slam and Angel's Might are cast with super armor."},
		{"name_cn": "守护之光", "name_en": "Guardian Light",
		"desc": "造成伤害的12%治疗附近血量最低的队友 12% of damage dealt heals the weakest nearby ally."},
	]


# ---------------------------------------------------------------- hooks
func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if ARMORED_SKILLS.has(str(skill.id)):
		f.add_status(&"super_armor", skill.total_time() + 0.1, 1.0, f)


func on_hit_dealt(f: Fighter, _victim: Fighter, _h: Dictionary, dmg: float) -> void:
	if dmg <= 0.0 or not f.is_alive():
		return
	var w := f.world()
	var best: Fighter = f
	var best_v := f.hp / f.max_hp
	if w != null:
		for a: Fighter in w.allies_of(f, true):
			if a.kind == "summon" or a.global_position.distance_to(f.global_position) > HOLY_LIGHT_RADIUS:
				continue
			var v := a.hp / a.max_hp
			if v < best_v:
				best_v = v
				best = a
	if best.hp < best.max_hp:
		best.heal(dmg * HOLY_LIGHT_FRACTION, f)
