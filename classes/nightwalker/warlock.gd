extends ClassKit
## 术士 Warlock (暗夜系 Nightwalker). Cane-wielding curse caster: roots, the hexagram seal prison,
## confusion rain, homing curse arrows, life-draining ghosts and the Lv70 tentacle gate 死亡之门.
## Passive 控制术 Control Spell: dark magic hits drain the victim's mana.

const DRAIN_MP: float = 15.0
const DRAIN_INTERVAL: float = 1.0       # per-victim drain cooldown (s)
const DRAIN_RETURN: float = 0.5         # share of drained MP the Warlock gains
const CURSE_COLOR: Color = Color(0.55, 0.15, 0.85)


func define() -> void:
	id = "warlock"
	name_cn = "术士"
	name_en = "Warlock"
	group_id = "nightwalker"
	role = "control"
	weapon_type = "cane"
	weapon_name_cn = "手杖"
	weapon_name_en = "Cane"
	offhand = ""
	model = "warlock"
	tint = CURSE_COLOR
	famous = "喻文州 Yu Wenzhou / 索克萨尔 Swoksaar / 灭神的诅咒 Curse of Destruction"
	stats = {"hp": 6200.0, "mp": 1500.0, "mp_regen": 24.0, "patk": 380.0, "matk": 605.0,
		"pdef": 260.0, "mdef": 450.0, "move_speed": 5.9, "jump_velocity": 9.0, "crit": 0.08}

	# ---------------------------------------------------------------- slot 0: curse bolt chain
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.42, &"cast", 14.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "visual": "orb", "speed": 26.0, "range": 15.0, "radius": 0.35, "aim": "target",
		"color": CURSE_COLOR, "sfx": "magic", "hit": hit(0.5, {"type": "magic", "element": "dark", "knockback": 0.6})}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "手杖射出暗影弹 Cane fires a shadow bolt."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.42, &"attack_1h_2", 14.0, ["ranged", "combo"],
		[{"t": 0.12, "type": "projectile", "visual": "orb", "speed": 26.0, "range": 15.0, "radius": 0.35, "aim": "target",
		"color": CURSE_COLOR, "sfx": "magic", "hit": hit(0.5, {"type": "magic", "element": "dark", "knockback": 0.6})}],
		{"cancel_window": 0.15, "desc": "挥杖再射暗影弹 Swing and fire another shadow bolt."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.5, &"cast", 14.0, ["ranged", "finisher"],
		[{"t": 0.2, "type": "projectile", "visual": "orb", "speed": 20.0, "range": 15.0, "radius": 0.5, "scale": 1.5,
		"aim": "target", "color": Color(0.35, 0.05, 0.6), "sfx": "magic",
		"hit": hit(0.8, {"type": "magic", "element": "dark", "knockback": 3.0, "hitstun": 0.45})}],
		{"cancel_window": 0.15, "desc": "凝聚的大暗影球 Charged heavy shadow orb."})

	# ---------------------------------------------------------------- slot 1: interrupt launcher
	var soul := sk(1, "soul_strike", "击魂术", "Soul Strike", 5.0, 45.0, 0.4, &"cast", 9.0,
		["launcher", "interrupt", "ranged", "combo"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.15, "type": "ground", "at": "target", "radius": 1.6, "visual": "dark", "color": CURSE_COLOR,
		"hit": hit(1.1, {"type": "magic", "element": "dark", "launch": 10.0, "knockback": 0.3})},
		{"t": 0.15, "type": "sfx", "name": "magic"}],
		{"cancel_window": 0.2, "desc": "直击灵魂，打断施法并将敌人震飞 Strike the soul: interrupts casting and blasts the target into the air."})

	# ---------------------------------------------------------------- slot 2: root
	var bind := sk(2, "bind_spell", "束缚术", "Bind Spell", 9.0, 50.0, 0.3, &"cast", 12.0,
		["cc", "debuff", "ranged"],
		[{"t": 0.1, "type": "debuff", "target": "target", "radius": 12.0, "statuses": [st("root", 3.0)], "fx": "dark_burst",
		"color": CURSE_COLOR},
		{"t": 0.1, "type": "sfx", "name": "debuff"}],
		{"desc": "瞬发束缚，定身目标 3 秒（无伤害）Instant bind: roots the target for 3 s (no damage)."})

	# ---------------------------------------------------------------- slot 3: homing curse arrows
	var arrows := sk(3, "curse_arrow", "诅咒之箭", "Curse Arrow", 6.0, 60.0, 0.6, &"channel", 15.0,
		["ranged", "combo"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow", "scale": 1.3},
		{"t": 0.3, "type": "projectile", "visual": "arrow", "count": 7, "spread": 50.0, "speed": 20.0, "range": 17.0,
		"radius": 0.35, "homing": 5.0, "aim": "target", "color": CURSE_COLOR, "sfx": "magic",
		"hit": hit(0.3, {"type": "magic", "element": "dark", "hitstun": 0.2, "knockback": 0.4, "juggle_cost": 4.0})}],
		{"cancel_window": 0.15, "desc": "释放一簇追踪敌人的诅咒之箭 Release a fan of homing curse arrows."})

	# ---------------------------------------------------------------- slot 4: seal zone
	var prison := sk(4, "hexagram_prison", "六星光牢", "Hexagram Prison", 16.0, 80.0, 0.5, &"cast_long", 12.0,
		["cc", "zone", "aoe", "ranged"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.2, "type": "ground", "at": "target", "radius": 2.4, "duration": 4.0, "tick": 0.5, "visual": "rune",
		"color": CURSE_COLOR,
		"hit": hit(0.1, {"type": "magic", "element": "dark", "hitstun": 0.0, "knockback": 0.0, "juggle_cost": 1.0,
		"statuses": [st("root", 0.7), st("silence", 0.7)]})},
		{"t": 0.2, "type": "sfx", "name": "magic"}],
		{"desc": "紫黑色六芒星光牢，触碰者被封印（定身+沉默）Purple-black hexagram lattice: anyone touching it is sealed (rooted and silenced)."})

	# ---------------------------------------------------------------- slot 5: confusion rain
	var rain := sk(5, "chaotic_rain", "混乱之雨", "Chaotic Rain", 12.0, 70.0, 0.5, &"cast", 12.0,
		["aoe", "debuff", "zone", "ranged"],
		[{"t": 0.2, "type": "ground", "at": "target", "radius": 3.5, "duration": 3.0, "tick": 0.5, "visual": "dark",
		"color": Color(0.4, 0.15, 0.6),
		"hit": hit(0.25, {"type": "magic", "element": "dark", "hitstun": 0.15, "knockback": 0.0, "juggle_cost": 3.0,
		"statuses": [st("confusion", 2.0)]})},
		{"t": 0.2, "type": "sfx", "name": "debuff"}],
		{"desc": "降下混乱之雨，范围内敌人陷入混乱（移动反向）Rain of chaos: enemies inside are confused (movement reversed)."})

	# ---------------------------------------------------------------- slot 6: life-draining ghost
	var ghosts := sk(6, "grasping_ghosts", "鬼影缠身", "Grasping Ghosts", 9.0, 60.0, 0.4, &"cast", 14.0,
		["ranged", "aoe", "debuff"],
		[{"t": 0.15, "type": "projectile", "visual": "orb", "speed": 14.0, "range": 14.0, "radius": 0.7, "scale": 1.8,
		"pierce": true, "aim": "target", "color": Color(0.3, 0.9, 0.6), "sfx": "magic",
		"hit": hit(1.5, {"type": "magic", "element": "dark", "lifesteal": 0.33, "hitstun": 0.4, "knockback": 0.5,
		"statuses": [st("slow", 2.0, 0.3)]})}],
		{"desc": "放出鬼影穿透敌人，造成伤害并汲取 33% 生命 A ghost passes through enemies, dealing damage and draining 33% as health."})

	# ---------------------------------------------------------------- slot 7: Lv70 ultimate
	var door := sk(7, "deaths_door", "死亡之门", "Death's Door", 70.0, 220.0, 1.8, &"cast_long", 12.0,
		["ultimate", "aoe", "zone", "cc", "ranged"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.9)]},
		{"t": 0.3, "type": "custom", "method": "door_open"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 4.0, "duration": 1.2, "tick": 0.3, "visual": "dark",
		"color": Color(0.3, 0.05, 0.45),
		"hit": hit(0.35, {"type": "magic", "element": "dark", "hitstun": 0.25, "knockback": 0.0, "juggle_cost": 3.0,
		"statuses": [st("root", 0.5)]})},
		{"t": 0.6, "type": "custom", "method": "door_pull", "args": {"radius": 6.5}},
		{"t": 1.0, "type": "custom", "method": "door_pull", "args": {"radius": 6.5}},
		{"t": 1.5, "type": "ground", "at": "target", "radius": 4.5, "visual": "dark", "color": CURSE_COLOR,
		"hit": hit(2.6, {"type": "magic", "element": "dark", "launch": 10.0, "knockdown": true, "knockback": 1.0})},
		{"t": 1.5, "type": "vfx", "name": "dark_burst", "at": "target", "scale": 2.5},
		{"t": 1.5, "type": "sfx", "name": "explosion"}],
		{"desc": "开启死亡之门，触手将敌人拖入中心后爆裂 Open the gate of death: tentacles drag enemies into the center, then it bursts."})

	skills = [atk1, soul, bind, arrows, prison, rain, ghosts, door]

	passives = [
		{"name_cn": "控制术", "name_en": "Control Spell",
		"desc": "暗黑魔法命中敌人时吸取 15 点法力（每个目标每秒一次，术士回复一半） Dark magic hits drain 15 MP (once per target per second; the Warlock gains half)."},
	]


# ================================================================== hooks
func on_tick(f: Fighter, delta: float) -> void:
	f.set_meta(&"nw_clock", float(f.get_meta(&"nw_clock", 0.0)) + delta)


func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
	# 控制术 Control Spell: mana drain on dark magic hits, at most once per victim every DRAIN_INTERVAL s;
	# only half of the stolen mana flows back so the Warlock's skills stay MP-negative.
	if victim == null or str(h.get("type", "phys")) != "magic" or victim.max_mp <= 0.0:
		return
	var now := float(f.get_meta(&"nw_clock", 0.0))
	var next_ok: Dictionary = f.get_meta(&"nw_drain_next", {})
	if now < float(next_ok.get(victim.uid, -1.0)):
		return
	var take := minf(DRAIN_MP, victim.mp)
	if take <= 0.0:
		return
	next_ok[victim.uid] = now + DRAIN_INTERVAL
	f.set_meta(&"nw_drain_next", next_ok)
	victim.mp -= take
	f.mp = minf(f.max_mp, f.mp + take * DRAIN_RETURN)


# ================================================================== custom actions
## 死亡之门: remember the gate center (the target's position when the gate opens).
func door_open(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var t := f.get_target()
	var w := f.world()
	if t == null and w != null:
		t = w.nearest_enemy(f, 12.0)
	var p := t.global_position if t != null else f.global_position + f.forward() * 6.0
	runner.vars["door"] = p


## Tentacles drag enemies toward the gate center (super armor resists).
func door_pull(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := f.world()
	if w == null or not runner.vars.has("door"):
		return
	var c: Vector3 = runner.vars["door"]
	var r := float(args.get("radius", 6.0))
	for e: Fighter in w.enemies_of(f, true):
		if not e.is_hittable() or e.has_status(&"super_armor"):
			continue
		var d := CoreUtil.flat(c - e.global_position)
		if d.length() > r or d.length() < 0.6:
			continue
		var v := minf(sqrt(2.0 * Fighter.KNOCK_FRICTION_GROUND * d.length()), 14.0)
		e.apply_knockback(d, v, 0.0)
	CoreUtil.fx(&"play", [&"dark_burst", c + Vector3.UP * 0.5, Vector3.UP, Color(0.3, 0.05, 0.45), r / 4.0])
