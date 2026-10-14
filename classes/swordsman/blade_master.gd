extends ClassKit
## 剑客 Blade Master (剑士系 Swordsman). Lightsaber duelist: fast chains, dashing slashes, aerial slam,
## Guard, and the Lv70 flurry 幻影无形剑 Formless Phantom Blade.
## Passive 剑术精通 Sword Mastery: lightsaber attack speed; +15% attack speed while the combo counter is 5+.

const KU := preload("res://classes/_kit_util.gd")
const MASTERY_COMBO: int = 5
const MASTERY_ATK_SPEED: float = 0.15


func define() -> void:
	id = "blade_master"
	name_cn = "剑客"
	name_en = "Blade Master"
	group_id = "swordsman"
	group_cn = "剑士系"
	group_en = "Swordsman"
	role = "melee"
	weapon_type = "lightsaber"
	weapon_name_cn = "光剑"
	weapon_name_en = "Lightsaber"
	offhand = ""
	model = "blade_master"
	tint = Color(0.55, 0.85, 1.0)
	famous = "黄少天 Huang Shaotian / 夜雨声烦 Troubling Rain / 冰雨 Ice Rain"
	stats = {"hp": 7400.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 620.0, "matk": 380.0,
		"pdef": 420.0, "mdef": 360.0, "move_speed": 6.5, "jump_velocity": 9.5, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.1, "crit": 0.12}

	var c := tint
	# ------------------------------------------------------------ 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·一", "Basic Attack I", 0.0, 0.0, 0.3, &"attack_1h_1", 2.6, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_saber"},
		{"t": 0.1, "type": "melee", "range": 2.6, "arc": 110.0, "color": c, "hit": hit(0.6, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "光剑快斩 Quick lightsaber slash."})
	sk(0, "atk2", "普攻·二", "Basic Attack II", 0.0, 0.0, 0.3, &"attack_1h_2", 2.6, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_saber"},
		{"t": 0.1, "type": "melee", "range": 2.6, "arc": 110.0, "color": c, "hit": hit(0.6, {"knockback": 1.0})}],
		{"cancel_window": 0.15, "desc": "回手斩 Backhand slash."})
	sk(0, "atk3", "普攻·三", "Basic Attack III", 0.0, 0.0, 0.42, &"attack_stab", 2.8, ["melee", "finisher"],
		[{"t": 0.0, "type": "sfx", "name": "swing_saber"},
		{"t": 0.14, "type": "melee", "shape": "box", "range": 2.8, "width": 1.4, "color": c,
		"hit": hit(0.9, {"knockback": 4.0, "hitstun": 0.5})}],
		{"cancel_window": 0.18, "desc": "突刺收尾 Finishing thrust that pushes back."})

	# ------------------------------------------------------------ 1: Lv1 launcher
	var upward := sk(1, "upward_slash", "上挑", "Upward Slash", 4.0, 30.0, 0.4, &"attack_1h_2", 2.6,
		["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_saber"},
		{"t": 0.12, "type": "melee", "range": 2.6, "arc": 120.0, "color": c,
		"hit": hit(1.1, {"launch": 10.5, "knockback": 0.8, "hitstun": 0.5})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "target"}],
		{"cancel_window": 0.25, "desc": "Lv1 上挑浮空 Rising slash that launches the target."})

	# ------------------------------------------------------------ 2: Triple Slash (gap closer)
	var triple := sk(2, "triple_slash", "三段斩", "Triple Slash", 8.0, 60.0, 0.95, &"dash", 6.0,
		["gap_closer", "combo", "melee"],
		[{"t": 0.0, "type": "anim", "anim": "attack_1h_1"},
		{"t": 0.0, "type": "dash", "direction": "target", "distance": 4.5, "speed": 26.0, "color": c,
		"hit": hit(0.55, {"knockback": 1.0, "hitstun": 0.45})},
		{"t": 0.3, "type": "anim", "anim": "attack_1h_2"},
		{"t": 0.3, "type": "dash", "direction": "aim", "distance": 3.5, "speed": 26.0, "through_enemies": true,
		"color": c, "hit": hit(0.55, {"knockback": 1.0, "hitstun": 0.45})},
		{"t": 0.6, "type": "anim", "anim": "attack_1h_3"},
		{"t": 0.6, "type": "dash", "direction": "aim", "distance": 3.5, "speed": 26.0, "through_enemies": true,
		"color": c, "hit": hit(0.7, {"knockback": 4.0, "hitstun": 0.5})},
		{"t": 0.6, "type": "sfx", "name": "swing_saber"}],
		{"cancel_window": 0.2, "desc": "三次冲刺斩，可变向 Three dashing slashes; re-aims between dashes."})

	# ------------------------------------------------------------ 3: Sword Draw (arc + sword aura)
	var draw := sk(3, "sword_draw", "拔刀斩", "Sword Draw", 7.0, 50.0, 0.5, &"attack_spin", 9.0,
		["melee", "ranged", "aoe"],
		[{"t": 0.0, "type": "sfx", "name": "swing_saber"},
		{"t": 0.15, "type": "melee", "range": 3.0, "arc": 170.0, "color": c, "hit": hit(1.0, {"knockback": 3.0})},
		{"t": 0.2, "type": "projectile", "visual": "wave", "speed": 24.0, "range": 10.0, "radius": 0.7, "pierce": true,
		"aim": "target", "from": "center", "color": c, "scale": 1.3, "sfx": "energy_shot",
		"hit": hit(0.9, {"knockback": 2.5, "hitstun": 0.45})}],
		{"cancel_window": 0.15, "desc": "圆弧拔刀斩并放出剑气 Arc draw-slash that releases a piercing sword aura."})

	# ------------------------------------------------------------ 4: Falling Phoenix Slash (aerial slam)
	var phoenix := sk(4, "falling_phoenix_slash", "落凤斩", "Falling Phoenix Slash", 9.0, 60.0, 0.7, &"aerial", 3.5,
		["finisher", "melee", "combo"],
		[{"t": 0.0, "type": "launch_self", "vertical": 6.5, "forward": 3.0},
		{"t": 0.32, "type": "anim", "anim": "attack_slam"},
		{"t": 0.32, "type": "melee", "range": 2.9, "arc": 150.0, "height": 3.0, "color": c,
		"hit": hit(1.7, {"knockdown": true, "otg": true, "hitstun": 0.5, "knockback": 1.0, "juggle_cost": 20.0})},
		{"t": 0.32, "type": "custom", "method": "slam_victims", "args": {"v": 16.0}},
		{"t": 0.36, "type": "stop"},
		{"t": 0.36, "type": "vfx", "name": "land_dust", "at": "forward", "distance": 1.5},
		{"t": 0.36, "type": "sfx", "name": "stomp"}],
		{"cancel_window": 0.15, "desc": "空中下劈将目标砸地 Aerial down-slash that slams the target to the ground."})

	# ------------------------------------------------------------ 5: Lunge (multi-stab)
	var lunge := sk(5, "lunge", "连突刺", "Lunge", 6.0, 40.0, 0.7, &"attack_stab", 5.0,
		["gap_closer", "melee", "combo"],
		[{"t": 0.0, "type": "dash", "direction": "target", "distance": 3.5, "speed": 22.0, "color": c},
		{"t": 0.12, "type": "multi_melee", "shape": "box", "range": 3.0, "width": 1.4, "count": 4, "interval": 0.1,
		"color": c, "fx": "hit_spark", "hit": hit(0.35, {"hitstun": 0.35, "knockback": 0.6, "juggle_cost": 6.0})},
		{"t": 0.55, "type": "melee", "shape": "box", "range": 3.2, "width": 1.4, "color": c,
		"hit": hit(0.5, {"knockback": 6.0, "hitstun": 0.5})},
		{"t": 0.55, "type": "sfx", "name": "swing_saber"}],
		{"cancel_window": 0.15, "desc": "前冲连续突刺后击退 Forward dash into rapid stabs, ending in a knockback."})

	# ------------------------------------------------------------ 6: Guard (block)
	var guard := sk(6, "guard", "格挡", "Guard", 8.0, 20.0, 0.25, &"block", 0.0,
		["defensive", "buff_self"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", 1.6, 0.75)], "fx": "block_spark"},
		{"t": 0.0, "type": "sfx", "name": "block"}],
		{"cancel_window": 0.25, "desc": "格挡正面物理攻击，大幅减伤 Blocks frontal physical attacks (-75% damage)."})

	# ------------------------------------------------------------ 7: ultimate
	var phantom := sk(7, "formless_phantom_blade", "幻影无形剑", "Formless Phantom Blade (Mirage Blade)", 60.0, 200.0, 1.9,
		&"attack_spin", 6.0, ["ultimate", "melee", "aoe", "finisher", "gap_closer"],
		[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.05, "type": "dash", "direction": "target", "distance": 7.0, "speed": 30.0, "color": c},
		{"t": 0.3, "type": "multi_melee", "shape": "circle", "range": 3.2, "count": 8, "interval": 0.12, "color": c,
		"hit": hit(0.36, {"hitstun": 0.4, "knockback": 0.3, "juggle_cost": 4.0})},
		{"t": 1.35, "type": "anim", "anim": "attack_stab"},
		{"t": 1.45, "type": "melee", "range": 3.5, "arc": 170.0, "color": c,
		"hit": hit(1.6, {"knockback": 14.0, "launch": 7.0, "knockdown": true, "armor_break": true})},
		{"t": 1.45, "type": "vfx", "name": "hit_heavy", "at": "target", "scale": 1.6},
		{"t": 1.45, "type": "sfx", "name": "ultimate_release"}],
		{"desc": "Lv70 大招：无形剑影连斩，终结强力击飞 Phantom flurry of slashes ending in a huge blow-away."})

	skills = [atk1, upward, triple, draw, phoenix, lunge, guard, phantom]
	passives = [
		{"name_cn": "剑术精通", "name_en": "Sword Mastery",
		"desc": "光剑攻速提升；连击数≥5时攻速再+15% Lightsaber attack speed up; +15% attack speed at 5+ combo."},
	]


# ---------------------------------------------------------------- hooks
func on_tick(f: Fighter, _delta: float) -> void:
	var want := MASTERY_ATK_SPEED if f.combo_count >= MASTERY_COMBO else 0.0
	# Additive share: other atk_speed modifiers on the Blade Master survive.
	KU.set_bonus_share(f, "atk_speed", &"bm_mastery_share", want)


# ---------------------------------------------------------------- custom actions
## Falling Phoenix Slash: runs after the melee step (same t, stable order) so hit reactions have already
## resolved; drives every airborne victim of this cast straight into the ground.
func slam_victims(_f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var v := float(args.get("v", 16.0))
	for victim: Fighter in runner.victims:
		if victim != null and is_instance_valid(victim) and victim.is_alive() and victim.is_airborne() 				and not victim.has_status(&"super_armor"):
			victim.velocity.y = minf(victim.velocity.y, -v)
