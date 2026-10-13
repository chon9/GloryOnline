extends ClassKit
## 召唤师 Summoner (法师系 Mage). Pet controller: goblins, elemental spirits and demon flowers fight for you.
## Passives: 强化生物 Strengthen Creature (your summons get +15% attack and defense) and 跟随 Follow (summons
## that stray more than 16 m are recalled next to you).

const MU := preload("res://classes/mage/_mage_util.gd")

const C_NATURE := Color(0.35, 0.9, 0.5)
const SPIRIT_ORDER: Array[String] = ["thunder_spirit", "fire_spirit", "ice_spirit", "dark_spirit"]
const SPIRIT_COLORS: Dictionary = {
	"thunder_spirit": Color(0.6, 0.72, 1.0),
	"fire_spirit": Color(1.0, 0.45, 0.12),
	"ice_spirit": Color(0.5, 0.88, 1.0),
	"dark_spirit": Color(0.6, 0.2, 0.95),
}
const FOLLOW_LEASH: float = 16.0
const STRENGTHEN: float = 0.15
const MARK_TIME: float = 8.0          # matches the Mark projectile's `mark` status
const MARK_PET_BONUS: float = 0.2     # Mark: pet hits on the marked enemy deal +20%


func define() -> void:
	id = "summoner"
	name_cn = "召唤师"
	name_en = "Summoner"
	group_id = "mage"
	group_cn = "法师系"
	group_en = "Mage"
	role = "summoner"
	weapon_type = "staff_ring"
	weapon_name_cn = "法杖"
	weapon_name_en = "Staff"
	offhand = ""
	model = "summoner"
	tint = Color(0.35, 0.9, 0.5)
	famous = "罗辑 Luo Ji / 昧光 Concealed Light"
	stats = {"hp": 5800.0, "mp": 1400.0, "mp_regen": 22.0, "patk": 450.0, "matk": 470.0,
		"pdef": 300.0, "mdef": 420.0, "move_speed": 6.2, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: staff bolts
	var b1 := sk(0, "staff_1", "普攻·法弹", "Staff Bolt", 0.0, 0.0, 0.35, &"cast", 15.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "speed": 24.0, "range": 16.0, "radius": 0.35, "aim": "target", "visual": "orb",
			"color": C_NATURE, "sfx": "magic", "hit": hit(0.38, {"type": "magic", "hitstun": 0.2, "knockback": 0.8})}],
		{"cancel_window": 0.05, "chain": ["staff_1", "staff_2", "staff_3"],
		"desc": "法杖三段魔法弹 Three-shot staff bolt chain."})
	sk(0, "staff_2", "普攻·法弹二", "Staff Bolt II", 0.0, 0.0, 0.35, &"attack_1h_2", 15.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "speed": 24.0, "range": 16.0, "radius": 0.35, "aim": "target", "visual": "orb",
			"color": C_NATURE, "sfx": "magic", "hit": hit(0.38, {"type": "magic", "hitstun": 0.2, "knockback": 0.8})}],
		{"cancel_window": 0.05, "desc": "第二发魔法弹 Second bolt."})
	sk(0, "staff_3", "普攻·法杖重击", "Staff Smite", 0.0, 0.0, 0.45, &"cast", 15.0, ["ranged", "finisher"],
		[{"t": 0.15, "type": "projectile", "speed": 22.0, "range": 16.0, "radius": 0.45, "aim": "target", "visual": "orb",
			"color": C_NATURE, "scale": 1.3, "sfx": "magic", "hit": hit(0.55, {"type": "magic", "hitstun": 0.3, "knockback": 3.5})}],
		{"cancel_window": 0.15, "desc": "较强的第三发法弹 Stronger third bolt with knockback."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var thorn := sk(1, "thorn", "藤刺", "Thorn", 4.0, 40.0, 0.45, &"cast", 12.0, ["launcher", "ranged", "combo"],
		[{"t": 0.05, "type": "vfx", "name": "cast_glow"},
		{"t": 0.15, "type": "ground", "at": "target", "radius": 1.8, "delay": 0.3, "visual": "thorn", "color": C_NATURE,
			"hit": hit(1.2, {"type": "magic", "launch": 10.0, "knockback": 0.3, "element": "poison"})},
		{"t": 0.45, "type": "sfx", "name": "earth", "at": "target"}],
		{"cancel_window": 0.2, "desc": "地面钻出藤刺，将目标挑飞 Thorns burst from the ground and launch the target."})

	# ---------------------------------------------------------------- slot 2: Goblin
	var goblin := sk(2, "goblin", "哥布林", "Goblin", 10.0, 70.0, 0.45, &"summon", 10.0, ["summon"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.2, "type": "summon", "summon_id": "goblin", "count": 1, "duration": 30.0, "max_active": 1, "offset": 2.0},
		{"t": 0.2, "type": "sfx", "name": "summon"}],
		{"desc": "召唤哥布林近战宠物（最多1只） Summons a melee Goblin pet (max 1)."})

	# ---------------------------------------------------------------- slot 3: elemental spirits (rotation)
	var spirit := sk(3, "elemental_spirit", "雷精灵 / 火精灵 / 冰精灵 / 暗精灵", "Thunder / Fire / Ice / Dark Spirit",
		11.0, 60.0, 0.4, &"summon", 12.0, ["summon", "ranged"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.2, "type": "custom", "method": "summon_spirit", "args": {"duration": 18.0}},
		{"t": 0.2, "type": "sfx", "name": "summon"}],
		{"desc": "依次召唤雷/火/冰/暗精灵：眩晕、灼烧、减速、破防 Summons the next spirit in the cycle: Thunder (stagger), Fire (burn), Ice (slow), Dark (defense down)."})

	# ---------------------------------------------------------------- slot 4: Demon World Flowers
	var flower := sk(4, "demon_flowers", "魔界之花", "Demon World Flowers", 14.0, 90.0, 0.5, &"summon", 9.0,
		["summon", "zone", "cc"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.25, "type": "summon", "summon_id": "demon_flower", "count": 1, "duration": 15.0, "max_active": 2, "offset": 2.0},
		{"t": 0.26, "type": "custom", "method": "plant_flower", "args": {"distance": 4.0}},
		{"t": 0.25, "type": "sfx", "name": "summon"}],
		{"desc": "在前方种下魔界之花炮台：毒液与藤蔓定身 Plants a static flower turret ahead: poison spit and rooting vines."})

	# ---------------------------------------------------------------- slot 5: Mark
	var mark := sk(5, "mark", "印记", "Mark", 8.0, 50.0, 0.3, &"cast", 14.0, ["debuff", "ranged", "buff_ally"],
		[{"t": 0.1, "type": "projectile", "speed": 30.0, "range": 16.0, "radius": 0.45, "aim": "target", "visual": "star",
			"color": Color(1.0, 0.35, 0.3), "sfx": "magic",
			"hit": hit(0.5, {"type": "magic", "hitstun": 0.2, "knockback": 0.3,
				"statuses": [st("mark", 8.0), st("def_down", 8.0, 0.15)]})},
		{"t": 0.1, "type": "custom", "method": "command_mark", "args": {"dur": 5.0}}],
		{"desc": "标记目标（防御-15%），所有宠物集火并加速，宠物攻击被标记目标额外造成20%伤害 Marks the target (-15% defense); every pet focuses it with a speed boost and pet hits on it deal +20%."})

	# ---------------------------------------------------------------- slot 6: Switch
	var swap := sk(6, "switch", "交替", "Switch", 10.0, 50.0, 0.15, &"cast", 0.0, ["escape", "defensive"],
		[{"t": 0.0, "type": "custom", "method": "switch_places", "args": {}}],
		{"desc": "与最远的召唤物交换位置 Swaps places with your farthest summon."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var ult := sk(7, "spirit_sacrifice", "精灵献祭", "Spirit Sacrifice", 70.0, 250.0, 1.2, &"cast", 10.0,
		["ultimate", "aoe", "ranged"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.3)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 4.0, "delay": 0.4, "visual": "rune", "color": C_NATURE,
			"hit": hit(2.6, {"type": "magic", "launch": 9.0, "knockback": 1.0})},
		{"t": 0.75, "type": "custom", "method": "sacrifice_spirits", "args": {"radius": 4.0, "dmg": 1.4, "extra_dmg": 0.3}},
		{"t": 0.75, "type": "sfx", "name": "explosion", "at": "target"}],
		{"desc": "引爆目标处魔阵并献祭所有元素精灵引发爆炸 Detonates a rune at the target and sacrifices every elemental spirit in explosions (full damage once per enemy)."})

	skills = [b1, thorn, goblin, spirit, flower, mark, swap, ult]

	# ---------------------------------------------------------------- summon definitions
	summons = {
		"goblin": {
			"name_cn": "哥布林", "name_en": "Goblin", "model": "orc_raider", "weapon_type": "orc_axe", "offhand": "",
			"tint": Color(0.5, 0.8, 0.3), "scale": 0.65,
			"stats": {"hp": 1000.0, "mp": 0.0, "patk": 300.0, "matk": 200.0, "pdef": 320.0, "mdef": 250.0, "move_speed": 6.6},
			"skills": [sk(0, "goblin_club", "哥布林重击", "Goblin Club", 1.5, 0.0, 0.45, &"attack_1h_1", 2.0, ["melee"],
				[{"t": 0.2, "type": "melee", "range": 2.0, "hit": hit(0.5, {"hitstun": 0.25, "knockback": 1.0})}],
				{"desc": "棍棒击打 Club strike."})],
		},
		"thunder_spirit": _spirit_def("雷精灵", "Thunder Spirit", "thunder_spirit", "lightning",
			{"hitstun": 0.4, "element": "lightning"}),
		"fire_spirit": _spirit_def("火精灵", "Fire Spirit", "fire_spirit", "orb",
			{"element": "fire", "statuses": [st("burn", 3.0, 1.0)]}),
		"ice_spirit": _spirit_def("冰精灵", "Ice Spirit", "ice_spirit", "orb",
			{"element": "ice", "statuses": [st("slow", 2.0, 0.3)]}),
		"dark_spirit": _spirit_def("暗精灵", "Dark Spirit", "dark_spirit", "orb",
			{"element": "dark", "statuses": [st("def_down", 4.0, 0.15)]}),
		"demon_flower": {
			"name_cn": "魔界之花", "name_en": "Demon World Flower", "model": "plant_warrior", "weapon_type": "", "offhand": "",
			"tint": Color(0.75, 0.25, 0.6), "scale": 0.8,
			"stats": {"hp": 900.0, "mp": 0.0, "patk": 200.0, "matk": 330.0, "pdef": 350.0, "mdef": 350.0,
				"move_speed": 0.0, "jump_velocity": 0.0},
			"skills": [
				sk(0, "flower_spit", "毒液", "Poison Spit", 1.5, 0.0, 0.35, &"cast", 9.0, ["ranged"],
					[{"t": 0.15, "type": "projectile", "speed": 18.0, "range": 10.0, "radius": 0.35, "aim": "target",
						"visual": "flask", "color": Color(0.5, 1.0, 0.3), "sfx": "magic",
						"hit": hit(0.3, {"type": "magic", "element": "poison", "hitstun": 0.25, "statuses": [st("poison", 3.0, 1.0)]})}],
					{"desc": "喷吐毒液 Poison spit."}),
				sk(1, "flower_vines", "藤蔓缠绕", "Vine Bind", 7.0, 0.0, 0.4, &"cast", 8.0, ["cc"],
					[{"t": 0.1, "type": "ground", "at": "target", "radius": 1.6, "delay": 0.4, "visual": "thorn",
						"color": Color(0.4, 0.8, 0.2), "max_distance": 9.0,
						"hit": hit(0.4, {"type": "magic", "hitstun": 0.2, "knockback": 0.0, "statuses": [st("root", 1.5)]})}],
					{"desc": "藤蔓定身 Vines root the target."}),
			],
		},
	}

	passives = [
		{"name_cn": "强化生物", "name_en": "Strengthen Creature",
			"desc": "召唤物攻击与防御+15% Your summons have +15% attack and defense."},
		{"name_cn": "跟随", "name_en": "Follow",
			"desc": "离你超过16米的召唤物会被召回身边 Summons more than 16 m away are recalled to your side."},
	]


func _spirit_def(cn: String, en: String, sid: String, visual: String, rider: Dictionary) -> Dictionary:
	var h := hit(0.3, {"type": "magic", "hitstun": 0.2, "knockback": 0.5})
	for k: Variant in rider:
		h[k] = rider[k]
	var c: Color = SPIRIT_COLORS.get(sid, tint)
	return {
		"name_cn": cn, "name_en": en, "model": "magical_girl", "weapon_type": "wand", "offhand": "",
		"tint": c, "scale": 0.5,
		"stats": {"hp": 600.0, "mp": 0.0, "patk": 200.0, "matk": 320.0, "pdef": 220.0, "mdef": 300.0, "move_speed": 7.0},
		"skills": [sk(0, sid + "_bolt", cn + "弹", en + " Bolt", 1.8, 0.0, 0.35, &"cast", 10.0, ["ranged"],
			[{"t": 0.15, "type": "projectile", "speed": 24.0, "range": 11.0, "radius": 0.35, "aim": "target",
				"visual": visual, "color": c, "scale": 0.7, "sfx": "magic", "hit": h}],
			{"desc": en})],
	}


# ================================================================== hooks
func on_spawn(f: Fighter) -> void:
	MU.setv(f, "spirit_i", 0)
	MU.setv(f, "pet_t", 0.0)


func can_cast_extra(f: Fighter, skill: SkillDef) -> bool:
	if skill.slot == 6:
		var w := f.world()
		return w != null and not w.summons_of(f).is_empty()
	return true


func on_tick(f: Fighter, delta: float) -> void:
	var mt := float(MU.getv(f, "mark_t", 0.0))
	if mt > 0.0:
		MU.setv(f, "mark_t", maxf(0.0, mt - delta))
	var t := float(MU.getv(f, "pet_t", 0.0)) - delta
	if t > 0.0:
		MU.setv(f, "pet_t", t)
		return
	MU.setv(f, "pet_t", 1.0)
	var w := f.world()
	if w == null:
		return
	for s: Fighter in w.summons_of(f):
		if not s.is_alive():
			continue
		# 强化生物 Strengthen Creature.
		s.add_status(&"atk_up", 1.5, STRENGTHEN, f)
		s.add_status(&"def_up", 1.5, STRENGTHEN, f)
		# 跟随 Follow (only when the pet is free to move).
		if s.global_position.distance_to(f.global_position) > FOLLOW_LEASH and s.can_act():
			var to := f.global_position - f.forward() * 1.5 + f.right() * randf_range(-1.5, 1.5)
			s.global_position = w.ground_point(w.clamp_to_bounds(to))
			CoreUtil.fx(&"play", [&"blink", s.center(), s.forward(), tint, 0.7])


## 印记 Mark (pet passive): hits by this Summoner's pets (CORE forwards summon hits with hit["_by_summon_uid"]) on the
## enemy marked by Mark deal +20% extra as a true-damage rider. The Summoner's own hits are unaffected.
func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, dmg: float) -> void:
	if not h.has("_by_summon_uid") or dmg <= 0.0 or victim == null or not victim.is_alive():
		return
	if is_marked_by(f, victim):
		victim.take_dot_damage(dmg * MARK_PET_BONUS, f, &"mark")
		MU.setv(f, "mark_pet_hits", int(MU.getv(f, "mark_pet_hits", 0)) + 1)


## True when `victim` is the live target of this Summoner's Mark (and still carries a `mark` status).
func is_marked_by(f: Fighter, victim: Fighter) -> bool:
	return float(MU.getv(f, "mark_t", 0.0)) > 0.0 and int(MU.getv(f, "mark_uid", -1)) == victim.uid 		and victim.has_status(&"mark")


# ================================================================== custom skills
## Elemental spirits are summoned in a fixed rotation (one of each element may be active).
func summon_spirit(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var i := int(MU.getv(f, "spirit_i", 0))
	var sid := SPIRIT_ORDER[posmod(i, SPIRIT_ORDER.size())]
	MU.setv(f, "spirit_i", i + 1)
	runner.execute_step({"type": "summon", "summon_id": sid, "count": 1, "duration": float(args.get("duration", 25.0)),
		"max_active": 1, "offset": 1.8, "color": SPIRIT_COLORS.get(sid, tint)})


func plant_flower(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var list := w.summons_of(f, "demon_flower")
	if list.is_empty():
		return
	var fl: Fighter = list[list.size() - 1]
	var to := f.global_position + f.forward() * float(args.get("distance", 4.0))
	var t := f.get_target()
	if t != null:
		var d := CoreUtil.flat(t.global_position - f.global_position)
		if d.length() < 12.0:
			to = f.global_position + d * clampf((d.length() - 3.0) / maxf(d.length(), 0.01), 0.0, 1.0)
	fl.global_position = w.ground_point(w.clamp_to_bounds(to))
	CoreUtil.fx(&"play", [&"summon_circle", fl.global_position, f.forward(), Color(0.75, 0.25, 0.6), 0.8])


## Mark: every pet locks onto the marked target and gets a short haste (鞭挞-style command).
func command_mark(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	var t := f.get_target()
	if w == null:
		return
	if t == null:
		t = w.nearest_enemy(f, 16.0)
	if t != null:
		MU.setv(f, "mark_uid", t.uid)
		MU.setv(f, "mark_t", MARK_TIME)
	for s: Fighter in w.summons_of(f):
		if not s.is_alive():
			continue
		s.add_status(&"haste", float(args.get("dur", 5.0)), 0.3, f)
		if t != null:
			# Pet brains follow a taunt source first, so this keeps them focused on the mark for `dur`.
			s.add_status(&"taunted", float(args.get("dur", 5.0)), 1.0, t)
			if s.input != null:
				s.input.target_uid = t.uid
				s.input.aim_point = t.center()
		CoreUtil.fx(&"play", [&"buff_aura", s.global_position, s.forward(), Color(1.0, 0.35, 0.3), 0.6])


## Switch: swap positions with the farthest living summon.
func switch_places(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var best: Fighter = null
	var best_d := -1.0
	for s: Fighter in w.summons_of(f):
		if not s.is_alive():
			continue
		var d := s.global_position.distance_to(f.global_position)
		if d > best_d:
			best_d = d
			best = s
	if best == null:
		return
	var a := f.global_position
	var b := best.global_position
	CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), tint, 1.0])
	f.global_position = b
	f.velocity = Vector3.ZERO
	best.global_position = a
	CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), tint, 1.0])


## Spirit Sacrifice: each living elemental spirit (not goblins / flowers) explodes where it stands, then is
## consumed. An enemy takes the full blast only once; further blasts on the same enemy deal a small fraction.
func sacrifice_spirits(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var r := float(args.get("radius", 4.0))
	var full := Hit.normalize(hit(float(args.get("dmg", 1.4)), {"type": "magic", "launch": 7.0, "knockback": 3.0}))
	var extra := Hit.normalize(hit(float(args.get("extra_dmg", 0.3)), {"type": "magic", "knockback": 1.0, "hitstun": 0.2}))
	var struck: Dictionary = {}
	for s: Fighter in w.summons_of(f):
		if not s.is_alive() or not SPIRIT_ORDER.has(String(s.mob_id)):
			continue
		var pos := s.global_position
		for e: Fighter in runner.enemies():
			if CoreUtil.flat(e.global_position - pos).length() - e.radius() > r or absf(e.global_position.y - pos.y) >= 3.0:
				continue
			runner.deal(e, extra if struck.has(e.uid) else full, pos)
			struck[e.uid] = true
		CoreUtil.fx(&"play", [&"explosion", pos + Vector3(0, 0.5, 0), Vector3.UP, SPIRIT_COLORS.get(String(s.mob_id), tint), r / 2.0])
		if s is Summon:
			(s as Summon).expire()
		else:
			s.kill(null)
