extends ClassKit
## 鬼剑士 Ghostblade (剑士系 Swordsman). Tachi user with ghost-power slashes (magic) and persistent ground
## boundaries (鬼阵): 冰阵 Ice Soul, 静寂之阵 Silence Boundary, 刀阵 Sword Soul (ally buff). The ultimate
## 鬼神盛宴 Ghost Feast detonates every active boundary.
## Passive 鬼阵 Ghost Boundaries: at most 3 boundaries persist (oldest dissolves); standing inside one of your
## own boundaries empowers you (+10% damage dealt).

const KU := preload("res://classes/_kit_util.gd")
const MAX_BOUNDARIES: int = 3
const RESONANCE_BONUS: float = 0.10
const BOUNDARY_DUR: float = 10.0


func define() -> void:
	id = "ghostblade"
	name_cn = "鬼剑士"
	name_en = "Ghostblade"
	group_id = "swordsman"
	group_cn = "剑士系"
	group_en = "Swordsman"
	role = "control"
	weapon_type = "tachi"
	weapon_name_cn = "太刀"
	weapon_name_en = "Tachi"
	offhand = ""
	model = "ghostblade"
	tint = Color(0.65, 0.3, 1.0)
	famous = "李轩 Li Xuan / 逢山鬼泣 Crying Devil / Ghost Killer Seal"
	stats = {"hp": 7300.0, "mp": 1400.0, "mp_regen": 22.0, "patk": 640.0, "matk": 760.0,
		"pdef": 380.0, "mdef": 480.0, "move_speed": 6.2, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.1, "crit": 0.10}

	var c := tint
	var moon := Color(0.8, 0.85, 1.0)
	var ice := Color(0.5, 0.85, 1.0)
	# ------------------------------------------------------------ 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.32, &"attack_1h_1", 2.7, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing"},
		{"t": 0.11, "type": "melee", "range": 2.7, "arc": 110.0, "color": c, "hit": hit(0.8, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "太刀斩 Tachi slash."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.32, &"attack_1h_2", 2.7, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing"},
		{"t": 0.11, "type": "melee", "range": 2.7, "arc": 110.0, "color": c, "hit": hit(0.8, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "desc": "回斩 Return slash."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.45, &"attack_2h", 2.9, ["melee", "finisher"],
		[{"t": 0.0, "type": "sfx", "name": "slash"},
		{"t": 0.16, "type": "melee", "range": 2.9, "arc": 130.0, "color": c, "hit": hit(1.0, {"knockback": 4.0, "hitstun": 0.5})}],
		{"cancel_window": 0.18, "desc": "双手重斩 Two-handed heavy cut."})

	# ------------------------------------------------------------ 1: Lv1 launcher
	var claw := sk(1, "ghost_claw", "鬼爪", "Ghost Claw", 4.0, 30.0, 0.45, &"attack_1h_2", 3.2,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "magic"},
		{"t": 0.15, "type": "melee", "range": 3.2, "arc": 100.0, "fx": "dark_burst", "color": c,
		"hit": hit(1.1, {"type": "magic", "element": "dark", "launch": 10.0, "knockback": 0.3, "hitstun": 0.5})},
		{"t": 0.15, "type": "vfx", "name": "launch_burst", "at": "target", "color": c}],
		{"cancel_window": 0.25, "desc": "Lv1 鬼手上抓浮空 A ghostly claw rips upward and launches the target."})

	# ------------------------------------------------------------ 2: Moonlight Slash
	var moonlight := sk(2, "moonlight_slash", "月光斩", "Moonlight Slash", 5.0, 35.0, 0.45, &"attack_1h_3", 3.0,
		["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "slash"},
		{"t": 0.15, "type": "melee", "range": 3.0, "arc": 140.0, "color": moon,
		"hit": hit(1.4, {"type": "magic", "launch": 7.0, "knockback": 1.5, "hitstun": 0.5})}],
		{"cancel_window": 0.2, "desc": "月牙斩将目标挑起 Crescent slash that knocks the target up."})

	# ------------------------------------------------------------ 3: Full Moonlight Slash
	var full_moon := sk(3, "full_moonlight_slash", "满月斩", "Full Moonlight Slash", 9.0, 60.0, 0.7, &"attack_spin", 3.4,
		["finisher", "aoe", "melee"],
		[{"t": 0.0, "type": "sfx", "name": "slash"},
		{"t": 0.25, "type": "melee", "shape": "circle", "range": 3.4, "color": moon,
		"hit": hit(2.2, {"type": "magic", "knockback": 11.0, "launch": 5.0, "knockdown": true})},
		{"t": 0.25, "type": "vfx", "name": "slash_arc", "color": moon, "scale": 1.8}],
		{"cancel_window": 0.15, "desc": "满月回旋斩，强力击飞 Full-circle moon slash with a big blow-away."})

	# ------------------------------------------------------------ 4: Ice Soul (boundary)
	var ice_soul := sk(4, "ice_soul", "冰阵", "Ice Soul (Ice Boundary)", 12.0, 70.0, 0.6, &"cast", 9.0,
		["zone", "cc", "aoe", "ranged"],
		[{"t": 0.0, "type": "sfx", "name": "ice"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 4.5, "duration": BOUNDARY_DUR, "tick": 1.0, "visual": "ice",
		"color": ice, "hit": hit(0.25, {"type": "magic", "element": "ice", "hitstun": 0.0, "knockback": 0.0,
		"juggle_cost": 3.0, "statuses": [st("slow", 1.5, 0.4)], "freeze_chance": 0.12, "freeze_dur": 1.0})}],
		{"cancel_window": 0.15, "desc": "布下冰阵：区域内敌人减速并有几率冰冻 Ice boundary: enemies inside are slowed and may freeze."})

	# ------------------------------------------------------------ 5: Silence Boundary
	var silence := sk(5, "silence_boundary", "静寂之阵", "Silence Boundary", 14.0, 70.0, 0.6, &"cast", 9.0,
		["zone", "cc", "debuff", "ranged"],
		[{"t": 0.0, "type": "sfx", "name": "debuff"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 4.5, "duration": BOUNDARY_DUR, "tick": 1.0, "visual": "dark",
		"color": c, "hit": hit(0.15, {"type": "magic", "element": "dark", "hitstun": 0.0, "knockback": 0.0,
		"juggle_cost": 3.0, "statuses": [st("silence", 1.2)]})}],
		{"cancel_window": 0.15, "desc": "布下静寂之阵：区域内敌人被沉默 Silence boundary: enemies inside cannot use skills."})

	# ------------------------------------------------------------ 6: Sword Soul (ally buff boundary)
	var sword_soul := sk(6, "sword_soul", "刀阵（刀魂）", "Sword Soul (Sword Boundary)", 15.0, 60.0, 0.6, &"cast", 0.0,
		["zone", "buff_ally", "buff_self"],
		[{"t": 0.0, "type": "sfx", "name": "buff"},
		{"t": 0.3, "type": "ground", "at": "self", "radius": 4.5, "duration": BOUNDARY_DUR, "tick": 1.0, "visual": "rune",
		"color": Color(1.0, 0.75, 0.35), "affects": "allies", "ally_effect": {"statuses": [st("atk_up", 1.5, 0.15)]}}],
		{"cancel_window": 0.15, "desc": "布下刀阵：区域内友方攻击+15% Sword boundary: allies inside gain +15% attack."})

	# ------------------------------------------------------------ 7: ultimate
	var feast := sk(7, "ghost_feast", "鬼神盛宴", "Ghost Feast", 60.0, 200.0, 1.4, &"channel", 8.0,
		["ultimate", "aoe", "zone", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash", "color": c},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.6)]},
		{"t": 0.6, "type": "custom", "method": "ghost_feast", "args": {
			"boundary_hit": hit(1.2, {"type": "magic", "element": "dark", "launch": 9.0, "knockback": 4.0, "armor_break": true}),
			"self_hit": hit(1.8, {"type": "magic", "element": "dark", "launch": 8.0, "knockback": 3.0}),
			"self_radius": 5.0}},
		{"t": 0.6, "type": "sfx", "name": "explosion"}],
		{"desc": "Lv70 大招：引爆所有鬼阵并在身边爆发鬼气 Detonates every active boundary plus a ghost burst around you."})

	skills = [atk1, claw, moonlight, full_moon, ice_soul, silence, sword_soul, feast]
	passives = [
		{"name_cn": "鬼阵", "name_en": "Ghost Boundaries",
		"desc": "鬼阵为持续地面区域（最多3个）；站在自己的阵中伤害+10% Boundaries are persistent zones (max 3); +10% damage while inside your own."},
	]


# ---------------------------------------------------------------- boundaries
## Active boundary AreaEffects created by `f` (persistent zones from skills tagged "zone"), oldest first.
func boundaries_of(f: Fighter) -> Array[AreaEffect]:
	var out: Array[AreaEffect] = []
	var w := f.world()
	if w == null:
		return out
	for e: Node in w.effects:
		if not (e is AreaEffect) or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var a := e as AreaEffect
		if not a.alive or a.caster != f or a.mode != "zone" or a.duration <= 0.0 or a.runner == null:
			continue
		if a.runner.skill != null and a.runner.skill.has_tag("zone") and not a.runner.skill.is_ultimate():
			out.append(a)
	return out


# ---------------------------------------------------------------- hooks
func on_tick(f: Fighter, _delta: float) -> void:
	var list := boundaries_of(f)
	while list.size() > MAX_BOUNDARIES:
		var oldest: AreaEffect = list.pop_front()
		oldest.finish()
	var inside := false
	for a: AreaEffect in list:
		if a.contains(f):
			inside = true
			break
	_set_resonance(f, RESONANCE_BONUS if inside else 0.0)


func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
	var chance := float(h.get("freeze_chance", 0.0))
	if chance <= 0.0 or victim == null or not victim.is_alive() or bool(h.get("_blocked", false)):
		return
	if Combat.rng.randf() < chance:
		# CORE guarded on-hit status (blocked / downed / invulnerable / super-armored victims are skipped).
		apply_on_hit_status(f, victim, h, &"freeze", float(h.get("freeze_dur", 1.0)))


func on_death(f: Fighter, _killer: Fighter) -> void:
	_set_resonance(f, 0.0)


## Additive: tracks only this passive's own share of stat_bonus.dmg_out so other kits' modifiers
## (e.g. Launcher Artillery Mastery) survive.
func _set_resonance(f: Fighter, want: float) -> void:
	KU.set_bonus_share(f, "dmg_out", &"ghostblade_resonance", want)


# ---------------------------------------------------------------- custom actions
## Ghost Feast: every own boundary explodes (hits enemies inside), then a burst around the caster.
func ghost_feast(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var bh: Dictionary = Hit.normalize(args.get("boundary_hit", {}))
	var detonated := 0
	for a: AreaEffect in boundaries_of(f):
		for e: Fighter in runner.enemies():
			if a.contains(e):
				runner.deal(e, bh, a.global_position)
		CoreUtil.fx(&"play", [&"dark_burst", a.global_position, Vector3.UP, tint, a.radius / 2.0])
		a.finish()
		detonated += 1
	runner.vars["boundaries_detonated"] = detonated
	f.set_meta(&"ghostblade_last_feast", detonated)
	runner.execute_step({"type": "ground", "at": "self", "radius": float(args.get("self_radius", 5.0)), "visual": "dark",
		"color": tint, "hit": args.get("self_hit", {})})
