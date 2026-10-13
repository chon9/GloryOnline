extends ClassKit
## 骑士 Knight (圣职系 Priest) - main tank. Knight's Sword + Plate Shield.
## Signature mechanics: taunts ([牺牲]吼叫 Roar), Shield Counter / Spell Reflect, frontal shield block
## passive, extra threat on every hit, super-armored Crusader's Trial ultimate.

const COUNTER_META: StringName = &"knight_counter"
const COUNTER_WINDOW: float = 1.3
const SHIELD_BLOCK_ARC: float = 55.0        # degrees from front
const SHIELD_BLOCK_REDUCTION: float = 0.30  # passive frontal physical damage reduction while not attacking
const DIZZY_CHANCE: float = 0.30



func define() -> void:
	id = "knight"
	name_cn = "骑士"
	name_en = "Knight"
	group_id = "priest"
	group_cn = "圣职系"
	group_en = "Priest"
	role = "tank"
	weapon_type = "knight_sword"
	weapon_name_cn = "骑士剑"
	weapon_name_en = "Knight's Sword"
	offhand = "shield"
	model = "knight"
	tint = Color(0.45, 0.65, 1.0)
	famous = "独活 Angelica (微草 Tiny Herb) / 叹息之墙 Wall of Sigh"
	stats = {"hp": 11500.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 620.0, "matk": 480.0,
		"pdef": 640.0, "mdef": 520.0, "move_speed": 5.6, "jump_velocity": 8.6, "weight": 1.3,
		"cast_speed": 1.0, "atk_speed": 0.95}

	# ------------------------------------------------------------ slot 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·剑击", "Basic Attack: Sword Cut", 0.0, 0.0, 0.34, &"attack_1h_1", 2.6, ["melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.6, "arc": 110.0, "hit": hit(0.62, {"hitstun": 0.35, "knockback": 1.0})},
		{"t": 0.1, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.14, "chain": ["atk1", "atk2", "atk3"], "desc": "骑士剑横斩 A level sword cut."})
	sk(0, "atk2", "普攻·回斩", "Basic Attack: Back Cut", 0.0, 0.0, 0.34, &"attack_1h_2", 2.6, ["melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.6, "arc": 110.0, "hit": hit(0.62, {"hitstun": 0.35, "knockback": 1.0})},
		{"t": 0.1, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.14, "desc": "反手回斩 Backhand return cut."})
	sk(0, "atk3", "普攻·盾推", "Basic Attack: Shield Shove", 0.0, 0.0, 0.48, &"attack_1h_3", 2.4, ["melee", "finisher"],
		[{"t": 0.18, "type": "melee", "range": 2.4, "arc": 90.0, "fx": "hit_heavy",
		"hit": hit(0.85, {"hitstun": 0.5, "knockback": 5.0})},
		{"t": 0.18, "type": "sfx", "name": "block"}],
		{"cancel_window": 0.12, "desc": "盾牌猛推收尾 Shield shove finisher that pushes the foe back."})

	# ------------------------------------------------------------ slot 1: launcher
	var shield_attack := sk(1, "shield_attack", "盾击", "Shield Attack", 5.0, 40.0, 0.42, &"attack_slam", 2.4,
		["launcher", "melee", "combo", "cc"],
		[{"t": 0.14, "type": "melee", "range": 2.4, "arc": 90.0, "fx": "launch_burst",
		"hit": hit(1.3, {"launch": 9.5, "knockback": 0.8, "dizzy_chance": DIZZY_CHANCE})},
		{"t": 0.14, "type": "sfx", "name": "metal"}],
		{"cancel_window": 0.2, "desc": "上挑盾击将敌人击飞，几率眩晕 Upward shield bash that launches, with a chance to daze."})

	# ------------------------------------------------------------ slot 2: gap closer
	var charge := sk(2, "charge", "[英勇]冲锋", "Charge", 8.0, 50.0, 0.55, &"dash", 9.0,
		["gap_closer", "melee", "cc", "combo"],
		[{"t": 0.0, "type": "vfx", "name": "dash_trail"},
		{"t": 0.02, "type": "dash", "distance": 9.0, "speed": 26.0, "direction": "target", "stop_on_hit": true, "width": 1.3,
		"hit": hit(1.2, {"hitstun": 0.7, "knockback": 3.0})},
		{"t": 0.02, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.2, "desc": "举盾冲锋撞击，命中硬直 Shield-first charge that staggers the first enemy hit."})

	# ------------------------------------------------------------ slot 3: knockback shove
	var repel := sk(3, "repel", "击退", "Repel", 7.0, 45.0, 0.45, &"attack_1h_3", 2.6,
		["melee", "cc", "interrupt", "defensive"],
		[{"t": 0.16, "type": "melee", "range": 2.6, "arc": 120.0, "fx": "hit_heavy",
		"hit": hit(1.4, {"hitstun": 0.6, "knockback": 11.0, "armor_break": false})},
		{"t": 0.16, "type": "sfx", "name": "hit_heavy"}],
		{"cancel_window": 0.15, "desc": "强力推击将敌人远远击退 Powerful shove that knocks enemies far back."})

	# ------------------------------------------------------------ slot 4: AoE taunt
	var roar := sk(4, "roar", "[牺牲]吼叫", "Roar", 12.0, 60.0, 0.5, &"taunt", 8.0,
		["cc", "aoe", "defensive", "buff_self"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 0.6), st("def_up", 6.0, 0.25)]},
		{"t": 0.15, "type": "taunt", "radius": 9.0, "duration": 4.0},
		{"t": 0.15, "type": "vfx", "name": "buff_aura", "scale": 2.0},
		{"t": 0.15, "type": "sfx", "name": "buff"}],
		{"desc": "怒吼嘲讽周围所有敌人并提升防御 Bellow that taunts all nearby enemies and raises defence."})

	# ------------------------------------------------------------ slot 5: counter / reflect
	var counter := sk(5, "shield_counter", "盾反 / 法术反射", "Shield Counter / Spell Reflect", 10.0, 50.0, 0.3, &"block", 4.0,
		["defensive", "buff_self", "interrupt"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", COUNTER_WINDOW, 0.9)], "fx": "block_spark"},
		{"t": 0.0, "type": "custom", "method": "counter_stance", "args": {"window": COUNTER_WINDOW}},
		{"t": 0.0, "type": "sfx", "name": "block"}],
		{"desc": "举盾架势：受到攻击时反击并反射法术 Guard stance: the next hit taken is countered and spells are reflected."})

	# ------------------------------------------------------------ slot 6: leap smash
	var leap := sk(6, "heroic_leap", "[公正的]英勇跳跃", "Heroic Leap", 12.0, 70.0, 0.75, &"leap", 10.0,
		["gap_closer", "aoe", "cc", "melee"],
		[{"t": 0.0, "type": "leap", "to": "target", "distance": 10.0, "height": 3.5, "duration": 0.6,
		"land": {"radius": 3.0, "fx": "land_dust", "hit": hit(1.8, {"stun": 1.2, "hitstun": 0.4, "knockback": 2.0})}},
		{"t": 0.6, "type": "vfx", "name": "launch_burst", "scale": 1.5},
		{"t": 0.6, "type": "sfx", "name": "earth"}],
		{"cancel_window": 0.1, "desc": "跃向目标重砸地面，眩晕落点敌人 Leaps onto the target and smashes the ground, stunning foes."})

	# ------------------------------------------------------------ slot 7: ultimate
	var trial := sk(7, "crusaders_trial", "十字军审判", "Crusader's Trial", 60.0, 200.0, 1.7, &"attack_1h_1", 3.5,
		["ultimate", "melee", "finisher", "combo"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 2.0)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.05, "type": "dash", "distance": 4.0, "speed": 22.0, "direction": "target"},
		{"t": 0.3, "type": "melee", "range": 3.0, "arc": 120.0, "hit": hit(0.6, {"hitstun": 0.5, "knockback": 0.3})},
		{"t": 0.55, "type": "anim", "anim": "attack_1h_2"},
		{"t": 0.6, "type": "melee", "range": 3.0, "arc": 120.0, "hit": hit(0.8, {"hitstun": 0.5, "knockback": 0.3})},
		{"t": 0.85, "type": "anim", "anim": "attack_1h_3"},
		{"t": 0.9, "type": "melee", "range": 3.0, "arc": 120.0, "hit": hit(1.0, {"hitstun": 0.6, "knockback": 0.3})},
		{"t": 1.15, "type": "anim", "anim": "attack_slam"},
		{"t": 1.3, "type": "ground", "at": "forward", "distance": 1.8, "radius": 3.2, "visual": "holy",
		"color": Color(0.7, 0.85, 1.0), "hit": hit(1.7, {"launch": 8.0, "knockback": 3.0, "armor_break": true})},
		{"t": 1.3, "type": "sfx", "name": "metal"}],
		{"desc": "十字军连斩，一击强过一击，最后圣光重砸 Escalating crusader strikes ending in a holy smash (super armor)."})

	skills = [atk1, shield_attack, charge, repel, roar, counter, leap, trial]

	passives = [
		{"name_cn": "盾牌格挡", "name_en": "Shield Block",
		"desc": "未攻击时正面受到的物理伤害降低30% Frontal physical damage -30% while not attacking."},
		{"name_cn": "守护者仇恨", "name_en": "Guardian Threat",
		"desc": "骑士的攻击造成双倍仇恨 Knight hits generate double threat (aggro)."},
	]


# ---------------------------------------------------------------- custom actions
func counter_stance(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	f.set_meta(COUNTER_META, float(args.get("window", COUNTER_WINDOW)))


# ---------------------------------------------------------------- hooks
func on_tick(f: Fighter, delta: float) -> void:
	if f.has_meta(COUNTER_META):
		var left := float(f.get_meta(COUNTER_META)) - delta
		if left <= 0.0:
			f.remove_meta(COUNTER_META)
		else:
			f.set_meta(COUNTER_META, left)


func on_hit_taken(f: Fighter, src: Fighter, h: Dictionary, dmg: float) -> float:
	if src == null or not is_instance_valid(src) or src == f:
		return dmg
	var magic := str(h.get("type", "phys")) == "magic"
	# Shield Counter / Spell Reflect window: consume it, reflect spells, strike back.
	if f.has_meta(COUNTER_META) and not bool(h.get("grab", false)):
		f.remove_meta(COUNTER_META)
		if magic:
			dmg *= 0.25
		var reach := f.global_position.distance_to(src.global_position)
		if src.is_alive() and (magic or reach <= 4.5):
			var ch := hit(1.5, {"type": "magic" if magic else "phys", "stun": 0.8, "hitstun": 0.5,
				"knockback": 4.0, "element": "holy" if magic else "", "threat": 2.0})
			CoreUtil.fx(&"play", [&"block_spark", f.center(), f.forward(), tint, 1.4])
			src.receive_hit(f, ch, f.global_position)
		return dmg
	# Passive Shield Block: frontal physical hits while not attacking.
	if not magic and not bool(h.get("grab", false)) and not bool(h.get("armor_break", false)) \
			and (f.state == Fighter.State.IDLE or f.state == Fighter.State.MOVE) \
			and Combat.angle_from_front(f, src.global_position) <= SHIELD_BLOCK_ARC:
		dmg *= 1.0 - SHIELD_BLOCK_REDUCTION
	return dmg


func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, dmg: float) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	victim.add_threat(f, dmg)   # Guardian Threat: doubles the threat of every hit
	var dz := float(h.get("dizzy_chance", 0.0))
	if dz <= 0.0 or not victim.is_alive():
		return
	# CORE flags guarded frontal hits (hit["_blocked"]); a blocked hit applies no stun, so do not even roll.
	if bool(h.get("_blocked", false)):
		return
	if Combat.deterministic or Combat.rng.randf() >= dz:
		return
	# No daze on an already-juggled victim (avoids STUNNED + LAUNCHED stacking mid-combo).
	if victim.state == Fighter.State.LAUNCHED:
		return
	# CORE guarded on-hit status: skips blocked / downed / invulnerable / super-armored victims.
	apply_on_hit_status(f, victim, h, &"stun", 0.8)
