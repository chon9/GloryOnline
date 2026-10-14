extends ClassKit
## 牧师 Cleric (圣职系 Priest) - the healer. Cross.
## Signature mechanics: cast-time heal + HoT (治愈术), instant burst heal (回复术), Sacred Fire silence,
## Hypnosis sleep, Angel Wings hover (slow fall), Revive ultimate that raises dead allies.

const HOVER_META: StringName = &"cleric_hover"
const IDLE_META: StringName = &"cleric_idle"
const HOVER_TIME: float = 3.0
const HOVER_FALL_SPEED: float = 1.0
const MEDITATION_DELAY: float = 3.0
const MEDITATION_BONUS: float = 1.0      # +100% mp_regen
const MEDITATION_SHARE_META: StringName = &"cleric_meditation"   # own share of stat_bonus.mp_regen
const KU := preload("res://classes/_kit_util.gd")


func define() -> void:
	id = "cleric"
	name_cn = "牧师"
	name_en = "Cleric"
	group_id = "priest"
	group_cn = "圣职系"
	group_en = "Priest"
	role = "healer"
	weapon_type = "cross"
	weapon_name_cn = "十字架"
	weapon_name_en = "Cross"
	offhand = ""
	model = "cleric"
	tint = Color(1.0, 0.94, 0.6)
	famous = "张新杰 Zhang Xinjie (霸图 Tyranny) / 石不转 Immovable Rock / 逆光十字架 Backlight Cross"
	stats = {"hp": 7100.0, "mp": 1500.0, "mp_regen": 22.0, "patk": 430.0, "matk": 620.0,
		"pdef": 340.0, "mdef": 480.0, "move_speed": 6.3, "jump_velocity": 9.2,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ------------------------------------------------------------ slot 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·十字击", "Basic Attack: Cross Strike", 0.0, 0.0, 0.34, &"attack_1h_1", 2.4, ["melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.4, "arc": 100.0, "hit": hit(0.6, {"hitstun": 0.3, "knockback": 1.0})},
		{"t": 0.1, "type": "sfx", "name": "swing_staff"}],
		{"cancel_window": 0.14, "chain": ["atk1", "atk2", "atk3"], "desc": "十字架敲击 Cross bash."})
	sk(0, "atk2", "普攻·回击", "Basic Attack: Return Strike", 0.0, 0.0, 0.34, &"attack_1h_2", 2.4, ["melee", "combo"],
		[{"t": 0.12, "type": "melee", "range": 2.4, "arc": 100.0, "hit": hit(0.6, {"hitstun": 0.3, "knockback": 1.0})},
		{"t": 0.1, "type": "sfx", "name": "swing_staff"}],
		{"cancel_window": 0.14, "desc": "反手敲击 Backhand bash."})
	sk(0, "atk3", "普攻·圣光弹", "Basic Attack: Holy Bolt", 0.0, 0.0, 0.42, &"shoot_1h", 12.0, ["ranged", "finisher"],
		[{"t": 0.15, "type": "projectile", "sfx": "magic_bolt", "visual": "orb", "speed": 26.0, "range": 13.0, "radius": 0.35, "aim": "target",
		"color": Color(1.0, 0.95, 0.65), "hit": hit(0.7, {"type": "magic", "element": "holy", "hitstun": 0.35, "knockback": 2.0})}],
		{"cancel_window": 0.12, "desc": "十字架射出圣光弹 The cross fires a small holy bolt."})

	# ------------------------------------------------------------ slot 1: launcher (Priest Lv1)
	var rising := sk(1, "rising_emblem", "升天阵", "Rising Emblem", 8.0, 45.0, 0.4, &"cast", 8.0,
		["launcher", "aoe", "ranged", "cc", "defensive"],
		[{"t": 0.12, "type": "ground", "at": "target", "radius": 2.3, "delay": 0.25, "visual": "holy",
		"hit": hit(1.0, {"type": "magic", "launch": 10.0, "knockback": 0.0, "element": "holy"})},
		{"t": 0.1, "type": "sfx", "name": "holy_cast"}],
		{"cancel_window": 0.15, "desc": "圣职基础技：法阵将敌人击飞，用于自保 Priest Lv1 rune circle that launches the enemy (self-peel)."})

	# ------------------------------------------------------------ slot 2: cast-time heal + HoT
	var heal_s := sk(2, "heal", "治愈术", "Heal (Small/Great/Holy)", 6.0, 90.0, 0.75, &"heal", 14.0,
		["heal", "buff_ally"],
		[{"t": 0.0, "type": "vfx", "name": "cast_glow"},
		{"t": 0.6, "type": "heal", "target": "ally_lowest", "radius": 15.0, "amount": 0.10, "matk_scale": 0.15,
		"hot": {"dur": 6.0, "power": 0.01}},
		{"t": 0.6, "type": "sfx", "name": "heal"}],
		{"desc": "读条治疗血量最低的队友并附加持续回复 Cast-time heal on the lowest-HP ally plus a heal over time."})

	# ------------------------------------------------------------ slot 3: instant heal
	var cure := sk(3, "cure", "回复术", "Cure (Small/Great/Holy)", 12.0, 110.0, 0.25, &"heal", 14.0,
		["heal"],
		[{"t": 0.05, "type": "heal", "target": "ally_lowest", "radius": 15.0, "amount": 0.16, "matk_scale": 0.2},
		{"t": 0.05, "type": "sfx", "name": "holy_cast"}],
		{"cancel_window": 0.1, "desc": "瞬发大量治疗，冷却较长 Instant burst heal with a long cooldown."})

	# ------------------------------------------------------------ slot 4: Sacred Fire
	var sacred := sk(4, "sacred_fire", "神圣之火", "Sacred Fire", 10.0, 70.0, 0.45, &"cast", 13.0,
		["ranged", "debuff", "interrupt"],
		[{"t": 0.18, "type": "projectile", "sfx": "fire_cast", "visual": "orb", "speed": 24.0, "range": 14.0, "radius": 0.45, "aim": "target",
		"color": Color(1.0, 0.75, 0.3), "scale": 1.3,
		"hit": hit(1.1, {"type": "magic", "element": "fire", "hitstun": 0.4,
		"statuses": [st("burn", 5.0, 1.0), st("silence", 2.0)]})},
		{"t": 0.15, "type": "sfx", "name": "fire_cast"}],
		{"cancel_window": 0.15, "desc": "圣火灼烧敌人并使其沉默 Holy fire that burns over time and silences."})

	# ------------------------------------------------------------ slot 5: Hypnosis
	var hypnosis := sk(5, "hypnosis", "催眠", "Hypnosis", 15.0, 80.0, 0.5, &"cast", 12.0,
		["cc", "debuff", "interrupt"],
		[{"t": 0.25, "type": "debuff", "target": "target", "radius": 6.5, "statuses": [st("sleep", 3.0)], "fx": "smoke"},
		{"t": 0.25, "type": "sfx", "name": "debuff"}],
		{"desc": "催眠目标使其沉睡，受到伤害会醒来 Puts the target to sleep (damage wakes it)."})

	# ------------------------------------------------------------ slot 6: Angel Wings
	var wings := sk(6, "angel_wings", "天使之翼", "Angel Wings", 14.0, 60.0, 0.3, &"jump", 0.0,
		["escape", "defensive", "buff_self"],
		[{"t": 0.0, "type": "launch_self", "vertical": 11.0, "forward": -5.0},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("haste", 4.0, 0.35)], "fx": "holy_burst"},
		{"t": 0.0, "type": "custom", "method": "angel_wings", "args": {"dur": HOVER_TIME}},
		{"t": 0.0, "type": "sfx", "name": "wind"}],
		{"desc": "展开天使之翼后跃悬空缓降，脱离近战 Spreads angel wings: leaps back and hovers, slowly gliding down."})

	# ------------------------------------------------------------ slot 7: ultimate - Revive
	var revive := sk(7, "revive", "复活术", "Revive", 90.0, 250.0, 1.6, &"cast_long", 15.0,
		["ultimate", "heal", "buff_ally"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.8)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 1.3, "type": "heal", "target": "ally_lowest", "radius": 18.0, "amount": 0.4, "revive": true},
		{"t": 1.35, "type": "ground", "at": "self", "radius": 6.0, "duration": 4.0, "tick": 0.5, "affects": "allies",
		"visual": "holy", "ally_effect": {"heal": 0.02}},
		{"t": 1.3, "type": "sfx", "name": "heal_big"}],
		{"desc": "复活倒下的队友（无阵亡时为重伤队友大量治疗）并留下治疗圣域 Revives a fallen ally (or big-heals the lowest) and leaves a healing sanctuary."})

	skills = [atk1, rising, heal_s, cure, sacred, hypnosis, wings, revive]

	passives = [
		{"name_cn": "冥想", "name_en": "Meditation",
		"desc": "3秒未施放技能时法力回复翻倍 MP regeneration doubles after 3 s without casting."},
		{"name_cn": "天使之翼", "name_en": "Angel Wings Glide",
		"desc": "天使之翼期间空中缓降并可自由移动 While Angel Wings is active the Cleric glides slowly down."},
	]


# ---------------------------------------------------------------- custom actions
func angel_wings(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	f.set_meta(HOVER_META, float(args.get("dur", HOVER_TIME)))


# ---------------------------------------------------------------- hooks
func on_skill_cast(f: Fighter, _skill: SkillDef) -> void:
	f.set_meta(IDLE_META, 0.0)
	KU.set_bonus_share(f, "mp_regen", MEDITATION_SHARE_META, 0.0)


func on_tick(f: Fighter, delta: float) -> void:
	# Meditation (additive share: other mp_regen modifiers on the Cleric survive).
	var idle := float(f.get_meta(IDLE_META, 0.0))
	if f.state != Fighter.State.CAST:
		idle += delta
	f.set_meta(IDLE_META, idle)
	KU.set_bonus_share(f, "mp_regen", MEDITATION_SHARE_META, MEDITATION_BONUS if idle >= MEDITATION_DELAY else 0.0)
	# Angel Wings glide: CORE fall-speed cap (Fighter.max_fall_speed via set_hover) while the wings are out.
	if f.has_meta(HOVER_META):
		var left := float(f.get_meta(HOVER_META)) - delta
		if left <= 0.0 or f.state == Fighter.State.LAUNCHED or f.state == Fighter.State.GRABBED \
				or (f.is_on_floor() and left < HOVER_TIME - 0.3):
			f.remove_meta(HOVER_META)
			f.clear_hover()
		else:
			f.set_meta(HOVER_META, left)
			f.set_hover(1.0, HOVER_FALL_SPEED)


func on_death(f: Fighter, _killer: Fighter) -> void:
	if f.has_meta(HOVER_META):
		f.remove_meta(HOVER_META)
	f.clear_hover()
