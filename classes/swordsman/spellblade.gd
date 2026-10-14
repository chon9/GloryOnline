extends ClassKit
## 魔剑士 Spellblade (剑士系 Swordsman). Short-sword mid-range wave caster: ground-crack launcher, elemental
## wave swords, a chanted lightning formation, a returning wave and the Lv75 Nebula Wave Slash.
## Passive 杀意波动 Killing Intent Wave: every wave skill adds a stack (+4% magic attack each, max 5, 6 s).
## Ice waves have a freeze chance (HIT key "freeze_chance").

const META_STACKS: StringName = &"spellblade_intent_stacks"
const META_TIMER: StringName = &"spellblade_intent_left"
const INTENT_MAX: int = 5
const INTENT_PER: float = 0.04
const INTENT_DUR: float = 6.0

const NEBULA_ELEMENTS: Array[Dictionary] = [
	{"element": "fire", "color": Color(1.0, 0.45, 0.1), "status": {"id": "burn", "dur": 3.0, "power": 0.8}},
	{"element": "ice", "color": Color(0.5, 0.85, 1.0), "status": {"id": "slow", "dur": 2.5, "power": 0.35}},
	{"element": "lightning", "color": Color(0.6, 0.7, 1.0), "status": {"id": "slow", "dur": 1.0, "power": 0.2}},
	{"element": "dark", "color": Color(0.6, 0.2, 0.95), "status": {"id": "blind", "dur": 1.5, "power": 1.0}},
]


func define() -> void:
	id = "spellblade"
	name_cn = "魔剑士"
	name_en = "Spellblade"
	group_id = "swordsman"
	group_cn = "剑士系"
	group_en = "Swordsman"
	role = "melee"
	weapon_type = "short_sword"
	weapon_name_cn = "短剑"
	weapon_name_en = "Short Sword"
	offhand = ""
	model = "spellblade"
	tint = Color(0.45, 0.6, 1.0)
	famous = "江波涛 Jiang Botao / 无浪 Empty Waves / Divine Chain"
	stats = {"hp": 7000.0, "mp": 1400.0, "mp_regen": 22.0, "patk": 500.0, "matk": 600.0,
		"pdef": 380.0, "mdef": 450.0, "move_speed": 6.3, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.05, "crit": 0.10}

	var c := tint
	var fire := Color(1.0, 0.45, 0.1)
	var ice := Color(0.5, 0.85, 1.0)
	var bolt := Color(0.6, 0.7, 1.0)
	# ------------------------------------------------------------ 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.32, &"attack_1h_1", 2.5, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_blade"},
		{"t": 0.1, "type": "melee", "range": 2.5, "arc": 110.0, "color": c, "hit": hit(0.85, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "短剑斩 Short-sword slash."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.32, &"attack_1h_2", 2.5, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_blade"},
		{"t": 0.1, "type": "melee", "range": 2.5, "arc": 110.0, "color": c, "hit": hit(0.85, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "desc": "回斩 Return slash."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.45, &"attack_1h_3", 6.0, ["melee", "ranged", "finisher"],
		[{"t": 0.0, "type": "sfx", "name": "swing_blade"},
		{"t": 0.15, "type": "melee", "range": 2.6, "arc": 120.0, "color": c, "hit": hit(0.6, {"knockback": 2.0})},
		{"t": 0.17, "type": "projectile", "visual": "wave", "speed": 22.0, "range": 7.0, "radius": 0.5, "pierce": true,
		"aim": "target", "from": "center", "color": c, "scale": 0.8, "sfx": "energy_shot",
		"hit": hit(0.5, {"type": "magic", "knockback": 2.5})}],
		{"cancel_window": 0.18, "desc": "斩出小型波动剑气 Slash that releases a small wave."})

	# ------------------------------------------------------------ 1: launcher (upward swing + ground crack)
	var quake := sk(1, "earthquake_sword", "地裂波动剑", "Earthquake Sword", 4.5, 40.0, 0.5, &"attack_2h", 7.0,
		["launcher", "aoe", "ranged", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "earth"},
		{"t": 0.2, "type": "ground", "shape": "line", "at": "target", "length": 8.0, "width": 1.8, "visual": "earth",
		"hit": hit(1.15, {"type": "magic", "launch": 10.0, "knockback": 0.5, "hitstun": 0.5})},
		{"t": 0.2, "type": "vfx", "name": "launch_burst", "at": "target"}],
		{"cancel_window": 0.25, "desc": "双手上挑震出地裂冲击波并浮空 Upward swing sending a ground-crack shockwave that launches."})

	# ------------------------------------------------------------ 2: Wave Splitting Sword
	var split := sk(2, "wave_splitting_sword", "裂波斩", "Wave Splitting Sword", 5.0, 35.0, 0.45, &"attack_1h_2", 12.0,
		["ranged", "combo"],
		[{"t": 0.15, "type": "projectile", "visual": "wave", "speed": 26.0, "range": 13.0, "radius": 0.6, "pierce": true,
		"aim": "target", "from": "center", "color": c, "scale": 1.2, "sfx": "energy_shot",
		"hit": hit(1.4, {"type": "magic", "knockback": 3.0, "hitstun": 0.45})}],
		{"cancel_window": 0.2, "desc": "挥出穿透波动剑气 Fires a piercing wave slash."})

	# ------------------------------------------------------------ 3: Fire Wave Sword
	var fire_wave := sk(3, "fire_wave_sword", "烈焰波动剑", "Fire Wave Sword", 9.0, 70.0, 0.6, &"attack_1h_3", 8.0,
		["aoe", "ranged", "finisher"],
		[{"t": 0.0, "type": "sfx", "name": "fire_cast"},
		{"t": 0.25, "type": "ground", "shape": "line", "at": "target", "length": 9.0, "width": 2.6, "visual": "fire",
		"color": fire, "hit": hit(2.0, {"type": "magic", "element": "fire", "knockback": 5.0, "knockdown": true,
		"statuses": [st("burn", 3.0, 1.0)]})}],
		{"cancel_window": 0.2, "desc": "高伤害烈焰波动，击倒并灼烧 High-damage fire wave that knocks down and burns."})

	# ------------------------------------------------------------ 4: Ice Wave Sword
	var ice_wave := sk(4, "ice_wave_sword", "冰刃波动剑", "Ice Wave Sword", 8.0, 55.0, 0.5, &"attack_1h_1", 11.0,
		["ranged", "cc"],
		[{"t": 0.0, "type": "sfx", "name": "swing_blade"},
		{"t": 0.2, "type": "projectile", "visual": "wave", "speed": 22.0, "range": 12.0, "radius": 0.7, "pierce": true,
		"aim": "target", "from": "center", "color": ice, "scale": 1.3, "sfx": "ice_cast",
		"hit": hit(1.3, {"type": "magic", "element": "ice", "knockback": 1.5, "hitstun": 0.5,
		"statuses": [st("slow", 3.0, 0.35)], "freeze_chance": 0.35, "freeze_dur": 1.2})}],
		{"cancel_window": 0.2, "desc": "冰刃波动减速并有几率冰冻 Ice wave that slows with a chance to freeze."})

	# ------------------------------------------------------------ 5: Electric Wave Formation (chanted zone)
	var formation := sk(5, "electric_wave_formation", "电光波动阵", "Electric Wave Formation", 12.0, 80.0, 0.7, &"cast", 10.0,
		["aoe", "zone", "cc", "ranged"],
		[{"t": 0.0, "type": "sfx", "name": "lightning_charge"},
		{"t": 0.0, "type": "vfx", "name": "cast_glow", "color": bolt},
		{"t": 0.4, "type": "ground", "at": "target", "radius": 3.5, "duration": 4.0, "tick": 0.5, "visual": "lightning",
		"color": bolt, "hit": hit(0.28, {"type": "magic", "element": "lightning", "hitstun": 0.4, "knockback": 0.0,
		"juggle_cost": 5.0})},
		{"t": 0.4, "type": "sfx", "name": "lightning_cast"}],
		{"desc": "咏唱电光波动阵，持续电击区域内敌人 Chanted lightning field that repeatedly shocks enemies inside."})

	# ------------------------------------------------------------ 6: Waltzing Wave Slash (returns from behind)
	var waltz := sk(6, "waltzing_wave_slash", "圆旋波动剑", "Waltzing Wave Slash", 7.0, 50.0, 0.6, &"attack_spin", 9.0,
		["ranged", "combo"],
		[{"t": 0.15, "type": "projectile", "visual": "wave", "speed": 20.0, "range": 9.0, "radius": 0.6, "pierce": true,
		"aim": "target", "from": "center", "color": c, "sfx": "energy_shot",
		"hit": hit(0.8, {"type": "magic", "knockback": 1.0, "hitstun": 0.45})},
		{"t": 0.4, "type": "custom", "method": "waltz_return", "args": {"behind": 3.5, "speed": 18.0,
		"hit": hit(0.9, {"type": "magic", "hitstun": 0.5, "knockback": 1.5})}}],
		{"cancel_window": 0.15, "desc": "剑气绕行后从目标背后折返（背击） Wave arcs around and returns from behind the target (back attack)."})

	# ------------------------------------------------------------ 7: ultimate
	var nebula := sk(7, "nebula_wave_slash", "星云波动剑", "Nebula Wave Slash", 65.0, 220.0, 1.8, &"cast_long", 10.0,
		["ultimate", "ranged", "aoe", "finisher"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.3, "type": "custom", "method": "nebula_wave", "args": {"dmg": 0.3}},
		{"t": 0.6, "type": "custom", "method": "nebula_wave", "args": {"dmg": 0.3}},
		{"t": 0.9, "type": "custom", "method": "nebula_wave", "args": {"dmg": 0.3}},
		{"t": 1.2, "type": "custom", "method": "nebula_wave", "args": {"dmg": 0.3}},
		{"t": 1.5, "type": "ground", "at": "target", "radius": 4.5, "visual": "rune", "color": Color(0.7, 0.55, 1.0),
		"hit": hit(1.0, {"type": "magic", "launch": 8.0, "knockback": 5.0})},
		{"t": 1.5, "type": "sfx", "name": "ultimate_release"}],
		{"desc": "Lv75 大招：随机元素星云波动连发后爆裂 Volleys of random-element waves ending in a nebula burst."})

	skills = [atk1, quake, split, fire_wave, ice_wave, formation, waltz, nebula]
	passives = [
		{"name_cn": "杀意波动", "name_en": "Killing Intent Wave",
		"desc": "每次施放波动剑技能叠加杀意，每层魔攻+4%（最多5层，6秒） Each wave skill adds a stack: +4% magic attack (max 5, 6 s)."},
	]


# ---------------------------------------------------------------- hooks
func on_spawn(f: Fighter) -> void:
	f.set_meta(META_STACKS, 0)
	f.set_meta(META_TIMER, 0.0)


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.slot <= 0:
		return
	var n := mini(INTENT_MAX, int(f.get_meta(META_STACKS, 0)) + 1)
	f.set_meta(META_STACKS, n)
	f.set_meta(META_TIMER, INTENT_DUR)
	# Killing Intent lives in a matk_up self status, so dispels and reset_for_round
	# (status.clear_all) end it and nothing is written to stat_bonus.
	f.add_status(&"matk_up", INTENT_DUR, INTENT_PER * float(n), f)


func on_tick(f: Fighter, delta: float) -> void:
	if int(f.get_meta(META_STACKS, 0)) <= 0:
		return
	var left := maxf(0.0, float(f.get_meta(META_TIMER, 0.0)) - delta)
	f.set_meta(META_TIMER, left)
	if left <= 0.0 or not f.has_status(&"matk_up"):
		f.set_meta(META_STACKS, 0)
		f.set_meta(META_TIMER, 0.0)


func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
	var chance := float(h.get("freeze_chance", 0.0))
	if chance <= 0.0 or victim == null or not victim.is_alive() or bool(h.get("_blocked", false)):
		return
	if Combat.rng.randf() < chance:
		# CORE guarded on-hit status (blocked / downed / invulnerable / super-armored victims are skipped).
		apply_on_hit_status(f, victim, h, &"freeze", float(h.get("freeze_dur", 1.0)))


func on_death(f: Fighter, _killer: Fighter) -> void:
	f.set_meta(META_STACKS, 0)
	f.set_meta(META_TIMER, 0.0)


# ---------------------------------------------------------------- custom actions
## Waltzing Wave Slash: a second wave appears behind the target and flies back toward the caster.
func waltz_return(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := f.world()
	if w == null:
		return
	var t := f.get_target()
	if t == null:
		t = w.nearest_enemy(f, 12.0)
	var anchor := f.global_position + f.forward() * 6.0
	if t != null:
		anchor = t.global_position
	var dir := CoreUtil.flat_dir(anchor - f.global_position, f.forward())
	var start := anchor + dir * float(args.get("behind", 3.5)) + Vector3(0, f.height() * 0.5, 0)
	var speed := float(args.get("speed", 18.0))
	var pr := Projectile.new()
	pr.caster = f
	pr.team = f.team
	pr.velocity = -dir * speed
	pr.radius = 0.6
	pr.max_range = float(args.get("behind", 3.5)) + 4.0
	pr.pierce = true
	pr.hit = Hit.normalize(args.get("hit", {}))
	pr.visual = "wave"
	pr.color = tint
	pr.visual_scale = 1.1
	pr.runner = runner
	pr.position = start
	w.add_effect(pr)
	CoreUtil.fx(&"play", [&"blink", start, -dir, tint, 0.8])


## Nebula Wave Slash volley: 3 waves of one random element.
func nebula_wave(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var e: Dictionary = NEBULA_ELEMENTS[Combat.rng.randi_range(0, NEBULA_ELEMENTS.size() - 1)]
	var h := hit(float(args.get("dmg", 0.3)), {"type": "magic", "element": e["element"], "hitstun": 0.4,
		"knockback": 1.0, "juggle_cost": 5.0, "statuses": [e["status"]]})
	if e["element"] == "ice":
		h["freeze_chance"] = 0.15
		h["freeze_dur"] = 0.8
	runner.execute_step({"type": "projectile", "visual": "wave", "count": 3, "spread": 30.0, "speed": 24.0,
		"range": 12.0, "radius": 0.7, "pierce": true, "aim": "target", "from": "center", "color": e["color"],
		"scale": 1.2, "sfx": "energy_shot", "hit": h})
	f.face_towards(f.aim_point())
