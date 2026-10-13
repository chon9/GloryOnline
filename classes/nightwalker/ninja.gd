extends ClassKit
## 忍者 Ninja (暗夜系 Nightwalker). Ninjato trickster: shuriken, decoy clones, smoke stealth, underground
## ambush and the Lv75 cherry-blossom blade. Passive 忍法·替身草人 Body Replacement swaps with a scarecrow
## when caught in a juggle (internal cooldown).

const REPLACE_CD: float = 20.0
const REPLACE_JUGGLE: float = 15.0    # juggle points needed before the substitution fires (2nd air hit)


func define() -> void:
	id = "ninja"
	name_cn = "忍者"
	name_en = "Ninja"
	group_id = "nightwalker"
	role = "melee"
	weapon_type = "ninjato"
	weapon_name_cn = "忍刀"
	weapon_name_en = "Ninjato"
	offhand = ""
	model = "ninja"
	tint = Color(0.45, 0.55, 0.85)
	famous = "莫凡 Mo Fan / 毁人不倦 Deception / 忍刀 Sixteen Leaves"
	stats = {"hp": 6400.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 520.0, "matk": 420.0,
		"pdef": 380.0, "mdef": 320.0, "move_speed": 6.7, "jump_velocity": 9.5, "crit": 0.12}

	# ---------------------------------------------------------------- slot 0: basic chain
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.3, &"attack_1h_1", 2.5, ["melee", "combo"],
		[{"t": 0.09, "type": "melee", "range": 2.5, "arc": 110.0, "hit": hit(0.68, {"knockback": 0.8})},
		{"t": 0.09, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "忍刀横斩 Ninjato horizontal cut."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.3, &"attack_1h_2", 2.5, ["melee", "combo"],
		[{"t": 0.09, "type": "melee", "range": 2.5, "arc": 110.0, "hit": hit(0.68, {"knockback": 0.8})},
		{"t": 0.09, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.15, "desc": "回身斩 Turning cut."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.42, &"attack_spin", 2.7, ["melee", "finisher"],
		[{"t": 0.14, "type": "melee", "shape": "circle", "range": 2.6, "hit": hit(0.95, {"knockback": 4.0, "hitstun": 0.45})},
		{"t": 0.14, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.12, "desc": "旋身斩收招 Spinning finisher."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var annihilation := sk(1, "annihilation", "忍法·断灭", "Annihilation", 4.0, 40.0, 0.45, &"attack_2h", 2.8,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "dash", "distance": 1.2, "speed": 16.0, "direction": "target"},
		{"t": 0.12, "type": "melee", "range": 2.6, "arc": 120.0, "hit": hit(1.3, {"launch": 10.5, "knockback": 0.6})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "target"},
		{"t": 0.12, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.25, "desc": "自下而上的断灭斩，将敌人挑飞 Rising ninjato cut that launches the target."})

	# ---------------------------------------------------------------- slot 2: stun star
	var shuriken := sk(2, "shuriken", "手里剑", "Shuriken", 6.0, 25.0, 0.3, &"throw", 14.0,
		["ranged", "cc", "interrupt"],
		[{"t": 0.1, "type": "projectile", "visual": "shuriken", "speed": 30.0, "range": 16.0, "radius": 0.35, "aim": "target",
		"color": Color(0.8, 0.85, 1.0), "sfx": "throw", "hit": hit(0.9, {"stun": 0.4, "hitstun": 0.3, "knockback": 0.5})}],
		{"cancel_window": 0.12, "desc": "掷出手里剑，命中短暂眩晕 Throw a shuriken that briefly stuns."})

	# ---------------------------------------------------------------- slot 3: spread volley
	var storm := sk(3, "storm_shuriken", "疾风手里剑", "Storm Shuriken", 7.0, 50.0, 0.5, &"throw", 12.0,
		["ranged", "aoe", "combo"],
		[{"t": 0.1, "type": "projectile", "visual": "shuriken", "count": 5, "spread": 36.0, "speed": 28.0, "range": 14.0,
		"radius": 0.4, "aim": "target", "sfx": "throw", "hit": hit(0.25, {"hitstun": 0.3, "knockback": 0.4, "juggle_cost": 5.0})},
		{"t": 0.3, "type": "projectile", "visual": "shuriken", "count": 5, "spread": 36.0, "speed": 28.0, "range": 14.0,
		"radius": 0.4, "aim": "target", "sfx": "throw", "hit": hit(0.25, {"hitstun": 0.3, "knockback": 0.4, "juggle_cost": 5.0})}],
		{"cancel_window": 0.15, "desc": "两轮扇形手里剑齐射 Two fan-shaped shuriken volleys."})

	# ---------------------------------------------------------------- slot 4: decoy relocation
	var clone := sk(4, "shadow_clone", "忍法·影分身", "Shadow Clone Technique", 15.0, 60.0, 0.25, &"cast", 6.0,
		["escape", "summon", "defensive"],
		[{"t": 0.0, "type": "summon", "summon_id": "shadow_clone", "count": 1, "duration": 6.0, "offset": 0.6, "max_active": 2},
		{"t": 0.0, "type": "vfx", "name": "smoke"},
		{"t": 0.02, "type": "custom", "method": "decoy_taunt", "args": {"summon_id": "shadow_clone", "radius": 8.0, "dur": 1.0}},
		{"t": 0.03, "type": "blink", "to": "back", "distance": 6.0},
		{"t": 0.03, "type": "buff", "target": "self", "statuses": [st("stealth", 1.5)]}],
		{"desc": "留下吸引敌人的分身并瞬间转移、短暂隐身 Leave a decoy clone that draws enemies, relocate and vanish briefly."})

	# ---------------------------------------------------------------- slot 5: smoke bomb
	var smoke := sk(5, "smoke_bomb", "忍具·烟玉", "Smoke Bomb", 14.0, 50.0, 0.3, &"throw", 3.5,
		["escape", "debuff", "zone", "defensive"],
		[{"t": 0.08, "type": "vfx", "name": "smoke", "scale": 2.0},
		{"t": 0.08, "type": "sfx", "name": "debuff"},
		{"t": 0.08, "type": "debuff", "target": "enemies", "radius": 3.5, "statuses": [st("blind", 1.5)], "fx": "smoke"},
		{"t": 0.08, "type": "ground", "at": "self", "radius": 3.5, "duration": 4.0, "tick": 0.4, "affects": "allies",
		"visual": "wind", "color": Color(0.55, 0.55, 0.6), "ally_effect": {"statuses": [st("stealth", 0.6)]}}],
		{"desc": "烟雾遮蔽视野：致盲周围敌人，烟中友方隐身 Smoke blocks vision: blinds nearby enemies, allies inside are hidden."})

	# ---------------------------------------------------------------- slot 6: underground ambush
	var tunnel := sk(6, "underground_tunneling", "忍法·地心斩首术", "Underground Tunneling Technique", 12.0, 70.0, 0.9,
		&"leap", 12.0, ["gap_closer", "cc", "melee"],
		[{"t": 0.0, "type": "vfx", "name": "land_dust", "scale": 1.5},
		{"t": 0.0, "type": "sfx", "name": "earth"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("invuln", 0.65), st("stealth", 0.6)]},
		{"t": 0.55, "type": "blink", "to": "target", "distance": 12.0},
		{"t": 0.6, "type": "anim", "anim": "attack_slam"},
		{"t": 0.6, "type": "vfx", "name": "land_dust", "at": "target", "scale": 1.5},
		{"t": 0.62, "type": "melee", "shape": "circle", "range": 2.0,
		"hit": hit(1.3, {"stun": 1.0, "hitstun": 0.0, "knockback": 0.0, "statuses": [st("root", 2.0)]}), "fx": "hit_heavy"},
		{"t": 0.62, "type": "sfx", "name": "earth"}],
		{"cancel_window": 0.2, "desc": "遁入地下躲避攻击，从敌人脚下钻出将其困在地中 Dive underground, burst out under the target and bury it in place."})

	# ---------------------------------------------------------------- slot 7: Lv75 ultimate
	var sakura := sk(7, "moon_slaying_sakura", "忍法·樱杀碎月", "Moon-Slaying Sakura", 60.0, 200.0, 1.6, &"attack_spin", 12.0,
		["ultimate", "aoe", "finisher", "ranged"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.8)]},
		{"t": 0.25, "type": "ground", "at": "target", "shape": "line", "length": 12.0, "width": 3.0, "duration": 1.0,
		"tick": 0.2, "visual": "wind", "color": Color(1.0, 0.6, 0.8),
		"hit": hit(0.55, {"hitstun": 0.4, "knockback": 0.0, "juggle_cost": 4.0})},
		{"t": 1.35, "type": "ground", "at": "target", "shape": "line", "length": 12.0, "width": 3.4, "visual": "wind",
		"color": Color(1.0, 0.45, 0.7), "hit": hit(1.4, {"launch": 9.0, "knockback": 1.0})},
		{"t": 1.35, "type": "vfx", "name": "slash_arc", "at": "forward", "distance": 4.0, "scale": 2.0, "color": Color(1.0, 0.6, 0.8)}],
		{"desc": "刀身化为漫天樱花瓣切割前方敌人，最后汇聚爆散 The blade dissolves into cutting cherry petals that shred the line, then burst."})

	skills = [atk1, annihilation, shuriken, storm, clone, smoke, tunnel, sakura]

	summons = {
		"shadow_clone": {
			"name_cn": "影分身", "name_en": "Shadow Clone", "model": "ninja", "weapon_type": "ninjato",
			"tint": Color(0.25, 0.25, 0.4), "scale": 1.0,
			"stats": {"hp": 500.0, "mp": 0.0, "patk": 250.0, "pdef": 150.0, "mdef": 150.0, "move_speed": 0.0},
			"skills": [sk(0, "clone_slash", "分身斩", "Clone Slash", 1.2, 0.0, 0.35, &"attack_1h_1", 2.2, ["melee"],
				[{"t": 0.12, "type": "melee", "range": 2.2, "hit": hit(0.4)}])],
		},
		"scarecrow": {
			"name_cn": "替身草人", "name_en": "Scarecrow", "model": "plant_warrior", "weapon_type": "",
			"tint": Color(0.75, 0.65, 0.35), "scale": 0.9,
			"stats": {"hp": 400.0, "mp": 0.0, "patk": 0.0, "pdef": 100.0, "mdef": 100.0, "move_speed": 0.0},
			"skills": [],
		},
	}

	passives = [
		{"name_cn": "忍法·替身草人", "name_en": "Body Replacement Technique",
		"desc": "被连击挑空时自动与草人替身互换，脱离连招（20 秒冷却）When juggled, automatically swap with a scarecrow and escape the combo (20 s cooldown)."},
	]


# ================================================================== hooks
func on_spawn(f: Fighter) -> void:
	f.set_meta(&"nw_replace_cd", 0.0)


func on_tick(f: Fighter, delta: float) -> void:
	var cd := float(f.get_meta(&"nw_replace_cd", 0.0))
	if cd > 0.0:
		f.set_meta(&"nw_replace_cd", maxf(0.0, cd - delta))
		return
	if f.state == Fighter.State.LAUNCHED and f.juggle_points >= REPLACE_JUGGLE and f.kind != "summon":
		body_replacement(f)


## 忍法·替身草人 Body Replacement: leave a scarecrow, reappear a few meters away from the attacker.
func body_replacement(f: Fighter) -> void:
	var w := f.world()
	if w == null:
		return
	f.set_meta(&"nw_replace_cd", REPLACE_CD)
	var old := f.global_position
	var away := -f.forward()
	var atk := w.get_fighter(f.last_attacker_uid)
	if atk != null and is_instance_valid(atk):
		away = CoreUtil.flat_dir(old - atk.global_position, away)
	var crow_pos := w.ground_point(w.clamp_to_bounds(old))
	w.spawn_summon(f, "scarecrow", crow_pos, 2.0)
	var dest := w.ground_point(w.clamp_to_bounds(crow_pos + away * 5.0))
	CoreUtil.fx(&"play", [&"smoke", old, f.forward(), Color(0.8, 0.8, 0.8), 1.2])
	CoreUtil.fx(&"sfx", [&"wood", old])
	f.global_position = dest
	f.velocity = Vector3.ZERO
	# CORE escape helper: clears knockback / juggle and leaves LAUNCHED / HITSTUN / KNOCKDOWN for IDLE or AIR.
	f.recover_to_neutral()
	f.add_status(&"invuln", 0.5, 1.0, f)
	if atk != null and is_instance_valid(atk):
		f.face_towards(atk.global_position)
	CoreUtil.fx(&"play", [&"blink", f.center(), f.forward(), tint, 1.0])


# ================================================================== custom actions
## Enemies near the newest decoy are taunted toward it.
func decoy_taunt(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	var w := f.world()
	if w == null:
		return
	var list := w.summons_of(f, str(args.get("summon_id", "shadow_clone")))
	if list.is_empty():
		return
	var decoy: Fighter = list.back()
	var r := float(args.get("radius", 8.0))
	for e: Fighter in w.enemies_of(f, true):
		if e.kind != "summon" and e.global_position.distance_to(decoy.global_position) <= r:
			e.add_status(&"taunted", float(args.get("dur", 1.5)), 1.0, decoy)
