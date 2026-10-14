extends ClassKit
## 神枪手 Sharpshooter (枪手系 Gunner). Dual revolvers, aerial gun-fu: every shot fired in the air kicks the
## shooter upward (recoil), close kicks set up OTG Punisher shots, Barrett Snipe pierces the whole line.
## Famous: 周泽楷 Zhou Zekai / 一枪穿云 Cloud Piercer / 荒火 Wildfire + 碎霜 Shattered Frost.

const GU := preload("res://classes/gunner/_gunner_util.gd")
const KU := preload("res://classes/_kit_util.gd")

const RECOIL_UP: float = 4.2
const RECOIL_CAP: float = 5.0
const BULLET := Color(1.0, 0.72, 0.35)
const FROST := Color(0.7, 0.9, 1.0)


func define() -> void:
	id = "sharpshooter"
	name_cn = "神枪手"
	name_en = "Sharpshooter"
	group_id = "gunner"
	group_cn = "枪手系"
	group_en = "Gunner"
	role = "ranged"
	weapon_type = "revolver"
	weapon_name_cn = "左轮手枪（双持）"
	weapon_name_en = "Revolver (dual)"
	offhand = ""
	model = "sharpshooter"
	tint = Color(1.0, 0.45, 0.15)
	famous = "周泽楷 Zhou Zekai / 一枪穿云 Cloud Piercer / 荒火 Wildfire + 碎霜 Shattered Frost"
	stats = {"hp": 8000.0, "mp": 1200.0, "mp_regen": 20.0, "patk": 700.0, "matk": 320.0,
		"pdef": 340.0, "mdef": 340.0, "move_speed": 6.6, "jump_velocity": 9.5, "weight": 0.9,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: revolver chain (6-shot drum)
	var shot1 := sk(0, "shot_1", "普攻·右枪", "Revolver Shot I", 0.0, 0.0, 0.42, &"shoot_1h", 16.0, ["ranged", "combo"],
		[_bullet(0.08, 0.35), {"t": 0.08, "type": "sfx", "name": "gun_revolver"}],
		{"cancel_window": 0.08, "chain": ["shot_1", "shot_2", "shot_3"],
		"desc": "右手左轮点射。空中开枪产生后坐力上浮。 Right-hand revolver shot; firing in the air pushes you up."})
	sk(0, "shot_2", "普攻·左枪", "Revolver Shot II", 0.0, 0.0, 0.42, &"shoot_1h", 16.0, ["ranged", "combo"],
		[_bullet(0.08, 0.35, FROST), {"t": 0.08, "type": "sfx", "name": "gun_revolver"}],
		{"cancel_window": 0.08, "desc": "左手左轮点射。 Left-hand revolver shot."})
	sk(0, "shot_3", "普攻·双枪连射", "Twin Revolver Burst", 0.0, 0.0, 0.55, &"shoot_dual", 16.0, ["ranged", "combo"],
		[_bullet(0.08, 0.35), _bullet(0.18, 0.35, FROST), {"t": 0.08, "type": "sfx", "name": "gun_revolver"},
		{"t": 0.18, "type": "sfx", "name": "gun_revolver"}],
		{"cancel_window": 0.1, "desc": "双枪齐射两发。 Both revolvers fire in quick succession."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var knee := sk(1, "knee_attack", "膝击", "Knee Attack", 4.0, 30.0, 0.4, &"kick", 2.2, ["launcher", "melee", "combo"],
		[{"t": 0.1, "type": "melee", "range": 2.1, "arc": 120.0, "fx": "hit_heavy",
		"hit": hit(1.3, {"launch": 10.5, "knockback": 1.0, "hitstun": 0.5})},
		{"t": 0.1, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.2},
		{"t": 0.1, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.2, "desc": "近身膝撞将敌人顶上浮空，衔接空中射击。 Close knee strike that pops the enemy into the air."})

	# ---------------------------------------------------------------- slot 2: gap closer / trip
	var slide := sk(2, "slide_kick", "滑铲", "Slide Kick", 7.0, 40.0, 0.45, &"dash", 6.0, ["gap_closer", "melee", "cc", "combo"],
		[{"t": 0.0, "type": "dash", "direction": "target", "distance": 6.0, "speed": 20.0, "stop_on_hit": true, "width": 1.0,
		"hit": hit(1.2, {"knockdown": true, "knockback": 2.5})},
		{"t": 0.0, "type": "sfx", "name": "dash"}],
		{"cancel_window": 0.15, "desc": "贴地滑铲突进，铲倒敌人。 Sliding rush that trips the enemy down."})

	# ---------------------------------------------------------------- slot 3: OTG
	var punisher := sk(3, "punisher", "踏射", "Punisher", 8.0, 45.0, 0.65, &"shoot_1h", 2.6, ["finisher", "melee", "combo"],
		[{"t": 0.1, "type": "multi_melee", "shape": "circle", "range": 2.6, "count": 4, "interval": 0.12, "fx": "hit_spark",
		"hit": hit(0.5, {"otg": true, "no_recover": true, "hitstun": 0.3, "knockback": 0.3, "juggle_cost": 5.0})},
		{"t": 0.1, "type": "sfx", "name": "gun_revolver"}, {"t": 0.34, "type": "sfx", "name": "gun_revolver"}],
		{"cancel_window": 0.15, "desc": "踩住倒地的敌人连续射击，可追击倒地且令其无法受身。 Stomp-and-shoot a downed enemy; OTG, negates quick recovery."})

	# ---------------------------------------------------------------- slot 4: Lv60 random firing
	var random_fire := sk(4, "random_firing", "乱射", "Random Firing", 9.0, 60.0, 0.75, &"shoot_dual", 10.0, ["aoe", "ranged"],
		[_fan(0.1), _fan(0.32), _fan(0.54),
		{"t": 0.1, "type": "sfx", "name": "gun_revolver"}, {"t": 0.32, "type": "sfx", "name": "gun_revolver"}, {"t": 0.54, "type": "sfx", "name": "gun_revolver"}],
		{"move_while_casting": true, "cancel_window": 0.15,
		"desc": "双枪向前方乱射三轮扇形弹幕，可边移动边射击。 Three fan volleys of wild shots; can move while firing."})

	# ---------------------------------------------------------------- slot 5: semicircle kick
	var roundhouse := sk(5, "roundhouse_kick", "回旋踢", "Roundhouse Kick", 6.0, 35.0, 0.45, &"kick", 2.6, ["melee", "aoe", "cc", "escape"],
		[{"t": 0.15, "type": "melee", "range": 2.7, "arc": 220.0, "fx": "slash_arc",
		"hit": hit(1.5, {"knockdown": true, "knockback": 7.0})},
		{"t": 0.15, "type": "sfx", "name": "swing_heavy"}],
		{"cancel_window": 0.15, "desc": "半圆回旋踢踢倒并击退身边敌人。 Semicircle kick that knocks nearby enemies down and away."})

	# ---------------------------------------------------------------- slot 6: Dual Load
	var dual := sk(6, "dual_load", "双重装填", "Dual Load", 15.0, 50.0, 0.2, &"cast", 0.0, ["buff_self"],
		[{"t": 0.05, "type": "custom", "method": "dual_load", "args": {}},
		{"t": 0.05, "type": "vfx", "name": "buff_aura"}, {"t": 0.05, "type": "sfx", "name": "reload"}],
		{"desc": "重新装填：立即恢复上一个使用过的技能（不含大招）。 Reload: the last skill you used (not the ultimate) is ready again."})

	# ---------------------------------------------------------------- slot 7: Lv70 ultimate
	var barrett := sk(7, "barrett_snipe", "巴雷特狙击", "Barrett Snipe", 60.0, 250.0, 1.3, &"shoot_2h", 30.0,
		["ultimate", "ranged", "finisher"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.4)], "fx": "cast_glow"},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"}, {"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.85, "type": "projectile", "sfx": "gun_sniper", "speed": 70.0, "range": 40.0, "radius": 0.55, "pierce": true, "aim": "target",
		"visual": "bullet", "scale": 2.4, "color": Color(1.0, 0.85, 0.5),
		"hit": hit(4.6, {"knockback": 9.0, "knockdown": true, "crit_bonus": 0.3, "juggle_cost": 30.0})},
		{"t": 0.85, "type": "sfx", "name": "gun_sniper"},
		{"t": 0.9, "type": "dash", "direction": "back", "distance": 1.5, "speed": 10.0}],
		{"desc": "架起巴雷特狙击枪，霸体蓄力后射出贯穿一条直线的狙击弹。 Super-armored sniper shot that pierces every enemy in a line."})

	skills = [shot1, knee, slide, punisher, random_fire, roundhouse, dual, barrett]

	passives = [
		{"name_cn": "空中射击（后坐力）", "name_en": "Aerial Gun-Fu (Recoil)",
		"desc": "空中开枪的后坐力会把自己向上推，连续射击可长时间滞空。 Shots fired in the air push you upward; keep shooting to stay airborne."},
		{"name_cn": "速射", "name_en": "Rapid Firing", "desc": "攻击速度 +10%。 Attack speed +10%."},
		{"name_cn": "暴射", "name_en": "Burst Firing", "desc": "暴击率提高。 Higher critical chance."},
	]


func _bullet(t: float, dmg: float, color: Color = BULLET) -> Dictionary:
	return {"t": t, "type": "projectile", "sfx": "gun_revolver", "speed": 42.0, "range": 18.0, "radius": 0.3, "aim": "target", "visual": "bullet",
		"color": color, "hit": hit(dmg, {"hitstun": 0.3, "knockback": 0.8, "juggle_cost": 6.0})}


func _fan(t: float) -> Dictionary:
	return {"t": t, "type": "projectile", "sfx": "gun_revolver", "speed": 38.0, "range": 12.0, "radius": 0.3, "count": 7, "spread": 140.0,
		"aim": "target", "visual": "bullet", "color": BULLET,
		"hit": hit(0.45, {"hitstun": 0.25, "knockback": 1.0, "juggle_cost": 5.0})}


# ---------------------------------------------------------------- hooks
func on_spawn(f: Fighter) -> void:
	# Additive shares (other kits / buffs on the same keys survive).
	KU.set_bonus_share(f, "atk_speed", &"ss_rapid_share", 0.1)     # 速射 Rapid Firing
	KU.set_bonus_share(f, "crit", &"ss_burst_share", 0.6)          # 暴射 Burst Firing (0.10 -> 0.16)


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.has_tag("ranged"):
		GU.air_recoil(f, RECOIL_UP, 0.0, RECOIL_CAP)
	if skill.slot >= 1 and skill.slot <= 5:
		f.set_meta(&"ss_last_slot", skill.slot)


# ---------------------------------------------------------------- custom actions
## 双重装填 Dual Load: restores the last used normal skill (slots 1-5).
func dual_load(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var slot := int(f.get_meta(&"ss_last_slot", -1))
	if slot < 1:
		return
	if GU.restore_charge(f, slot):
		runner.vars["reloaded"] = slot
