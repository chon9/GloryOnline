extends ClassKit
## 散人 Unspecialized (叶修 Ye Xiu / 君莫笑 Lord Grim / 千机伞 Myriad Manifestation Umbrella).
## Never advances past Lv20; borrows the low-level skills of other classes. Every skill first flips the umbrella
## into the matching weapon form ("f.weapon_form", replicated) through the custom step "form" at t=0, with no swap
## cooldown. Passive 千变 Myriad Forms: each skill whose form differs from the previous one, cast within 3 s of the
## previous skill, grants a stacking +5% outgoing damage (max 5 stacks); 3 s without casting resets the stacks and
## folds the umbrella back to its default look. Basic attacks (slot 0) only keep the window alive (no stacks).
## NOTE: slot 7 and 千变 Myriad Forms are design inventions (contract needs an ultimate; canon has no Lv70 skill).
## Per-fighter state is stored as metadata on the Fighter (the kit instance is shared by every Unspecialized).

## Logical form -> displayed WeaponFactory id.
const FORM_WEAPON: Dictionary = {
	"lance": "umbrella",        # battle lance / spear form (folded umbrella)
	"gun": "umbrella_gun",      # cannon / gatling form
	"shield": "umbrella_open",  # shield form (canopy open)
	"blade": "tachi",           # swordsman tachi form
	"fist": "tonfa",            # fighter tonfa form
}
const KU := preload("res://classes/_kit_util.gd")
const MF_WINDOW: float = 3.0
const MF_PER_STACK: float = 0.05
const MF_MAX: int = 5

const M_LAST_FORM: StringName = &"mf_last_form"
const M_LAST_CAST: StringName = &"mf_last_cast"
const M_CLOCK: StringName = &"mf_clock"
const M_APPLIED: StringName = &"mf_applied"
const M_LOGICAL: StringName = &"mf_form"


func define() -> void:
	id = "unspecialized"
	name_cn = "散人"
	name_en = "Unspecialized"
	group_id = "unspecialized"
	group_cn = "散人"
	group_en = "Unspecialized"
	role = "melee"
	weapon_type = "umbrella"
	weapon_name_cn = "千机伞"
	weapon_name_en = "Myriad Manifestation Umbrella"
	offhand = ""
	model = "unspecialized"
	tint = Color(0.78, 0.72, 0.95)
	famous = "叶修 Ye Xiu / 君莫笑 Lord Grim / 千机伞 Myriad Manifestation Umbrella"
	# Slightly below specialized classes (no awakening), balanced all-rounder.
	stats = {"hp": 7800.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 660.0, "matk": 620.0,
		"pdef": 380.0, "mdef": 380.0, "move_speed": 6.2, "jump_velocity": 9.2, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.05, "crit": 0.10}

	# ---------------------------------------------------------------- slot 0: basic chain (lance form)
	var atk1 := sk(0, "atk1", "普攻·伞刺", "Basic: Umbrella Thrust", 0.0, 0.0, 0.34, &"attack_stab", 2.8,
		["melee", "combo"],
		[_form("lance"),
		{"t": 0.1, "type": "melee", "range": 2.8, "arc": 70.0, "hit": hit(0.6, {"knockback": 0.6})},
		{"t": 0.1, "type": "sfx", "name": "swing_staff"}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"],
		"desc": "千机伞矛形连刺 Spear-form umbrella thrust."})
	sk(0, "atk2", "普攻·回刺", "Basic: Return Thrust", 0.0, 0.0, 0.34, &"attack_1h_2", 2.8, ["melee", "combo"],
		[_form("lance"),
		{"t": 0.1, "type": "melee", "range": 2.8, "arc": 80.0, "hit": hit(0.6, {"knockback": 0.6})},
		{"t": 0.1, "type": "sfx", "name": "swing_staff"}],
		{"cancel_window": 0.15, "desc": "第二段刺击 Second thrust."})
	sk(0, "atk3", "普攻·横扫", "Basic: Umbrella Sweep", 0.0, 0.0, 0.48, &"attack_2h", 3.0, ["melee", "finisher"],
		[_form("lance"),
		{"t": 0.16, "type": "melee", "range": 3.0, "arc": 140.0, "hit": hit(0.85, {"knockback": 4.0})},
		{"t": 0.16, "type": "vfx", "name": "slash_arc", "color": tint},
		{"t": 0.16, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.2, "desc": "横扫击退 Sweeping blow that knocks back."})

	# ---------------------------------------------------------------- slot 1: 天击 Sky Strike (Battle Mage Lv1 launcher)
	var sky := sk(1, "sky_strike", "天击", "Sky Strike", 5.0, 40.0, 0.4, &"attack_stab", 2.8,
		["launcher", "melee", "combo"],
		[_form("lance"),
		{"t": 0.12, "type": "melee", "range": 2.8, "arc": 80.0, "hit": hit(1.25, {"launch": 11.0, "knockback": 0.8})},
		{"t": 0.12, "type": "vfx", "name": "launch_burst", "at": "forward", "color": tint},
		{"t": 0.12, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.2, "desc": "矛形上挑，将目标挑飞 Lance-form upward thrust that launches the target."})

	# ---------------------------------------------------------------- slot 2: 龙牙 Dragon Tooth (Battle Mage)
	var tooth := sk(2, "dragon_tooth", "龙牙", "Dragon Tooth", 6.0, 50.0, 0.42, &"attack_stab", 4.0,
		["melee", "combo", "cc", "interrupt"],
		[_form("lance"),
		{"t": 0.02, "type": "dash", "distance": 2.2, "speed": 22.0, "direction": "target", "stop_on_hit": true},
		{"t": 0.14, "type": "melee", "range": 2.9, "arc": 60.0, "hit": hit(1.5, {"stun": 0.6, "knockback": 1.5})},
		{"t": 0.14, "type": "vfx", "name": "hit_heavy", "at": "forward", "color": tint},
		{"t": 0.14, "type": "sfx", "name": "swing_spear"}],
		{"cancel_window": 0.18, "desc": "高优先级突刺，短暂眩晕 Fast high-priority stab with a brief stun."})

	# ---------------------------------------------------------------- slot 3: 反坦克炮 Anti-Tank Missile (Launcher)
	var at_missile := sk(3, "anti_tank_missile", "反坦克炮", "Anti-Tank Missile", 9.0, 60.0, 0.55, &"shoot_2h", 14.0,
		["ranged", "cc", "aoe"],
		[_form("gun"),
		{"t": 0.18, "type": "projectile", "count": 3, "spread": 10.0, "speed": 26.0, "range": 16.0, "radius": 0.5,
		"aim": "target", "visual": "missile", "sfx": "missile",
		"explode": {"radius": 1.2, "hit": hit(0.15, {"knockback": 2.0})},
		"hit": hit(0.6, {"stun": 0.4, "knockback": 3.0})},
		{"t": 0.18, "type": "vfx", "name": "explosion", "at": "forward", "scale": 0.4}],
		{"cancel_window": 0.2, "desc": "伞化炮形，连射三发炮弹并短暂眩晕 Gun form: three shells with a brief stun."})

	# ---------------------------------------------------------------- slot 4: 拔刀斩 Sword Draw (Blade Master)
	var draw := sk(4, "sword_draw", "拔刀斩", "Sword Draw", 8.0, 55.0, 0.45, &"attack_1h_3", 3.5,
		["melee", "aoe", "combo"],
		[_form("blade"),
		{"t": 0.15, "type": "melee", "range": 3.0, "arc": 150.0, "hit": hit(1.2, {"knockback": 3.0})},
		{"t": 0.17, "type": "projectile", "speed": 24.0, "range": 8.0, "radius": 0.8, "pierce": true, "aim": "forward",
		"from": "center", "visual": "wave", "color": Color(0.75, 0.85, 1.0), "sfx": "energy_shot",
		"hit": hit(0.7, {"knockback": 2.0})},
		{"t": 0.15, "type": "vfx", "name": "slash_arc", "color": Color(0.75, 0.85, 1.0), "scale": 1.3}],
		{"cancel_window": 0.2, "desc": "刀形拔刀弧斩并放出剑气 Blade form: arc draw slash that sends out a sword aura."})

	# ---------------------------------------------------------------- slot 5: 鹰踏 Eagle Stamp (Striker)
	var stamp := sk(5, "eagle_stamp", "鹰踏", "Eagle Stamp", 8.0, 50.0, 0.65, &"leap", 7.0,
		["gap_closer", "melee", "finisher"],
		[_form("fist"),
		{"t": 0.0, "type": "leap", "to": "target", "distance": 7.0, "height": 3.0, "duration": 0.5,
		"land": {"radius": 2.0, "hit": hit(1.4, {"knockdown": true, "otg": true, "knockback": 1.0})}},
		{"t": 0.5, "type": "vfx", "name": "land_dust", "scale": 1.2},
		{"t": 0.5, "type": "sfx", "name": "stomp"}],
		{"cancel_window": 0.1, "desc": "跃起向下踩踏，可踩倒地目标 Leaping downward stomp; also hits downed foes."})

	# ---------------------------------------------------------------- slot 6: 盾击 Shield Attack (Knight)
	var bash := sk(6, "shield_attack", "盾击", "Shield Attack", 9.0, 45.0, 0.42, &"attack_1h_1", 2.4,
		["melee", "cc", "defensive", "interrupt"],
		[_form("shield"),
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", 1.2, 0.6)]},
		{"t": 0.15, "type": "melee", "range": 2.4, "arc": 100.0, "hit": hit(1.2, {"stun": 1.0, "knockback": 2.5})},
		{"t": 0.15, "type": "vfx", "name": "block_spark", "at": "forward"},
		{"t": 0.15, "type": "sfx", "name": "shield"}],
		{"cancel_window": 0.15, "desc": "伞面张开格挡并盾击眩晕 Shield form: guard, then bash that dizzies."})

	# ---------------------------------------------------------------- slot 7: 千机连携 Myriad Combo (ultimate, a string of canon Lv<=20 borrowed skills)
	var ult := sk(7, "myriad_combo", "千机连携", "Myriad Combo", 60.0, 200.0, 1.9, &"attack_spin", 4.0,
		["ultimate", "melee", "aoe", "finisher"],
		[_form("shield"),
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 2.1)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash", "color": tint},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.02, "type": "dash", "distance": 3.0, "speed": 22.0, "direction": "target", "stop_on_hit": true},
		{"t": 0.15, "type": "melee", "range": 2.6, "arc": 110.0, "hit": hit(0.55, {"stun": 0.4, "knockback": 0.5})},
		{"t": 0.15, "type": "sfx", "name": "shield"},
		# 龙牙连刺 lance flurry -> 天击 launch
		{"t": 0.38, "type": "custom", "method": "form", "args": {"form": "lance"}},
		{"t": 0.4, "type": "multi_melee", "range": 3.0, "arc": 90.0, "count": 3, "interval": 0.1,
		"hit": hit(0.4, {"knockback": 0.2, "hitstun": 0.4})},
		{"t": 0.75, "type": "melee", "range": 3.0, "arc": 100.0, "hit": hit(0.6, {"launch": 9.0, "knockback": 0.5})},
		{"t": 0.75, "type": "vfx", "name": "launch_burst", "at": "forward", "color": tint},
		# 格林机枪 Gatling Gun bursts on the airborne target
		{"t": 0.95, "type": "custom", "method": "form", "args": {"form": "gun"}},
		{"t": 1.0, "type": "projectile", "sfx": "gun_pistol", "count": 3, "spread": 6.0, "speed": 34.0, "range": 12.0, "radius": 0.45,
		"aim": "target", "visual": "bullet", "hit": hit(0.13, {"hitstun": 0.25, "knockback": 0.2})},
		{"t": 1.12, "type": "projectile", "sfx": "gun_pistol", "count": 3, "spread": 6.0, "speed": 34.0, "range": 12.0, "radius": 0.45,
		"aim": "target", "visual": "bullet", "hit": hit(0.13, {"hitstun": 0.25, "knockback": 0.2})},
		{"t": 1.24, "type": "projectile", "sfx": "gun_pistol", "count": 3, "spread": 6.0, "speed": 34.0, "range": 12.0, "radius": 0.45,
		"aim": "target", "visual": "bullet", "hit": hit(0.13, {"hitstun": 0.25, "knockback": 0.2})},
		# 拔刀斩 finishing draw
		{"t": 1.45, "type": "custom", "method": "form", "args": {"form": "blade"}},
		{"t": 1.5, "type": "melee", "shape": "circle", "range": 3.6, "hit": hit(0.9, {"knockdown": true, "knockback": 6.0, "otg": true})},
		{"t": 1.5, "type": "vfx", "name": "slash_arc", "color": Color(0.75, 0.85, 1.0), "scale": 1.8},
		{"t": 1.5, "type": "sfx", "name": "swing_heavy"},
		{"t": 1.85, "type": "custom", "method": "form", "args": {"form": "lance"}}],
		{"desc": "千机伞连换四形：盾击、龙牙连刺接天击挑空、格林机枪、拔刀斩收尾 Umbrella cycles four forms: Shield Attack, Dragon Tooth flurry into Sky Strike, 格林机枪 Gatling Gun bursts, Sword Draw finish."})

	skills = [atk1, sky, tooth, at_missile, draw, stamp, bash, ult]

	passives = [
		{"name_cn": "千变", "name_en": "Myriad Forms",
		"desc": "3秒内连续使用不同形态的技能（普攻不计），每次叠加5%伤害（最多5层） Chaining skills of different forms within 3 s (basic attacks excluded) stacks +5% damage (max 5)."},
		{"name_cn": "千机伞", "name_en": "Myriad Manifestation Umbrella",
		"desc": "银武可瞬间切换矛、炮、刀、拳、盾等形态，无换武冷却 The silver umbrella switches lance, gun, blade, fist and shield forms instantly with no swap cooldown."},
		{"name_cn": "散人", "name_en": "Unspecialized",
		"desc": "永不转职，掌握各职业20级以下技能；无觉醒，基础属性略低 Never specializes: knows every class's skills up to Lv20, no awakening, slightly lower stats."},
	]


## Step that switches the umbrella form (used at t=0 of every skill).
func _form(form: String) -> Dictionary:
	return {"t": 0.0, "type": "custom", "method": "form", "args": {"form": form}}


# ==================================================================== hooks
func on_spawn(f: Fighter) -> void:
	f.kit_counter_max = MF_MAX      # replicated: client HUDs can show Myriad Forms stack pips
	_reset_passive(f)
	f.weapon_form = ""


func on_tick(f: Fighter, delta: float) -> void:
	var clock: float = float(f.get_meta(M_CLOCK, 0.0)) + delta
	f.set_meta(M_CLOCK, clock)
	if clock - float(f.get_meta(M_LAST_CAST, -100.0)) <= MF_WINDOW or f.state == Fighter.State.CAST:
		return
	if f.kit_counter > 0:
		_set_stacks(f, 0)
	f.set_meta(M_LAST_FORM, "")
	# Idle: fold the umbrella back to its default look (also covers round resets that skip on_spawn).
	if f.weapon_form != "":
		f.weapon_form = ""


func on_death(f: Fighter, _killer: Fighter) -> void:
	_reset_passive(f)


## Custom action: switch the displayed weapon form. Every call records the logical form (so a mid-skill switch, e.g.
## the ultimate ending in lance, is what the next cast compares against); only the first call of a non-basic cast
## feeds 千变 Myriad Forms. Basic attacks (slot 0) just keep the window alive.
func form(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var logical := str(args.get("form", "lance"))
	f.weapon_form = str(FORM_WEAPON.get(logical, logical))
	f.set_meta(M_LOGICAL, logical)
	var clock: float = float(f.get_meta(M_CLOCK, 0.0))
	if runner == null:
		return
	if runner.slot == 0:
		f.set_meta(M_LAST_CAST, clock)
		return
	if runner.vars.has("mf_counted"):
		f.set_meta(M_LAST_FORM, logical)
		return
	runner.vars["mf_counted"] = true
	var last_cast: float = float(f.get_meta(M_LAST_CAST, -100.0))
	var last_form: String = str(f.get_meta(M_LAST_FORM, ""))
	var stacks: int = f.kit_counter
	if clock - last_cast > MF_WINDOW:
		stacks = 0
	elif last_form != "" and last_form != logical:
		stacks = mini(MF_MAX, stacks + 1)
		CoreUtil.fx(&"play", [&"buff_aura", f.center(), f.forward(), tint, 0.4 + 0.12 * stacks])
	f.set_meta(M_LAST_CAST, clock)
	f.set_meta(M_LAST_FORM, logical)
	_set_stacks(f, stacks)


# ==================================================================== passive helpers
## Current Myriad Forms stacks of a fighter. Stored in CORE's replicated `Fighter.kit_counter` (max in
## `kit_counter_max`), so this is valid on clients too.
func myriad_stacks(f: Fighter) -> int:
	return f.kit_counter


func _set_stacks(f: Fighter, stacks: int) -> void:
	if f.kit_counter != stacks:
		f.kit_counter = stacks
	# Additive own share of dmg_out (other modifiers survive).
	KU.set_bonus_share(f, "dmg_out", M_APPLIED, MF_PER_STACK * float(stacks))


func _reset_passive(f: Fighter) -> void:
	_set_stacks(f, 0)
	f.set_meta(M_LAST_FORM, "")
	f.set_meta(M_LAST_CAST, -100.0)
