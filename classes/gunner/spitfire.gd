extends ClassKit
## 弹药专家 Spitfire (枪手系 Gunner). Automatic pistol + off-hand grenades: special bullets (float / stun / ice)
## and grenades all work on charges, so a good Spitfire paints the field with "flower" explosions.
## Famous: 张佳乐 Zhang Jiale / 百花缭乱 Dazzling Hundred Blossoms / 猎寻 Hunting Seeker.

const GU := preload("res://classes/gunner/_gunner_util.gd")

const RECOIL_UP: float = 1.8
const RECOIL_CAP: float = 3.0
const BULLET := Color(1.0, 0.85, 0.45)
const FLOWER_COLORS: Array[Color] = [Color(1.0, 0.45, 0.7), Color(1.0, 0.75, 0.2), Color(0.6, 0.85, 1.0),
	Color(0.75, 0.5, 1.0), Color(1.0, 0.35, 0.3)]


func define() -> void:
	id = "spitfire"
	name_cn = "弹药专家"
	name_en = "Spitfire"
	group_id = "gunner"
	group_cn = "枪手系"
	group_en = "Gunner"
	role = "ranged"
	weapon_type = "auto_pistol"
	weapon_name_cn = "自动手枪"
	weapon_name_en = "Automatic Pistol"
	offhand = "grenade"
	model = "spitfire"
	tint = Color(1.0, 0.75, 0.2)
	famous = "张佳乐 Zhang Jiale / 百花缭乱 Dazzling Hundred Blossoms / 猎寻 Hunting Seeker"
	stats = {"hp": 6800.0, "mp": 1300.0, "mp_regen": 20.0, "patk": 560.0, "matk": 320.0,
		"pdef": 330.0, "mdef": 380.0, "move_speed": 6.2, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: auto pistol bursts (8-shot mag)
	var b1 := sk(0, "burst_1", "普攻·点射", "Pistol Burst I", 0.0, 0.0, 0.45, &"shoot_1h", 15.0, ["ranged", "combo"],
		[_bullet(0.05, 0.16), _bullet(0.13, 0.16), {"t": 0.05, "type": "sfx", "name": "gun_pistol"}],
		{"cancel_window": 0.08, "chain": ["burst_1", "burst_2", "burst_3"],
		"desc": "自动手枪两连发。 Two-round pistol burst."})
	sk(0, "burst_2", "普攻·连射", "Pistol Burst II", 0.0, 0.0, 0.45, &"shoot_1h", 15.0, ["ranged", "combo"],
		[_bullet(0.05, 0.16), _bullet(0.13, 0.16), {"t": 0.05, "type": "sfx", "name": "gun_pistol"}],
		{"cancel_window": 0.08, "desc": "自动手枪两连发。 Two-round pistol burst."})
	sk(0, "burst_3", "普攻·扫射", "Pistol Spray", 0.0, 0.0, 0.55, &"shoot_1h", 15.0, ["ranged", "combo"],
		[_bullet(0.05, 0.15), _bullet(0.12, 0.15), _bullet(0.19, 0.15), {"t": 0.05, "type": "sfx", "name": "gun_pistol"},
		{"t": 0.19, "type": "sfx", "name": "gun_pistol"}],
		{"cancel_window": 0.1, "desc": "自动手枪三连发。 Three-round pistol spray."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher (special bullet)
	var floating := sk(1, "floating_bullet", "浮空弹", "Floating Bullet", 5.0, 30.0, 0.35, &"shoot_1h", 16.0,
		["launcher", "ranged", "combo"],
		[{"t": 0.1, "type": "projectile", "sfx": "gun_pistol_heavy", "speed": 34.0, "range": 17.0, "radius": 0.4, "aim": "target", "visual": "bullet",
		"scale": 1.5, "color": Color(0.55, 0.85, 1.0), "hit": hit(1.1, {"launch": 11.0, "knockback": 1.0, "hitstun": 0.5})},
		{"t": 0.1, "type": "sfx", "name": "gun_pistol_heavy"}],
		{"charges": 2, "cancel_window": 0.15, "desc": "特殊弹药：强力浮空弹，把敌人打上天。 Special bullet that knocks the enemy high into the air."})

	# ---------------------------------------------------------------- slot 2: impact grenade (low cd, charges)
	var grenade := sk(2, "grenade", "撞击式手雷", "Grenade", 3.0, 25.0, 0.35, &"throw", 14.0, ["aoe", "ranged", "combo"],
		[_grenade(0.12, 2.6, hit(1.2, {"knockback": 6.0, "hitstun": 0.5})), {"t": 0.12, "type": "sfx", "name": "grenade_throw"}],
		{"charges": 3, "cancel_window": 0.15, "desc": "低冷却的撞击手雷，爆炸击退。 Low-cooldown impact grenade; the blast knocks enemies back."})

	# ---------------------------------------------------------------- slot 3: stun bullet
	var stun := sk(3, "stun_bullet", "僵直弹", "Stun Bullet", 10.0, 45.0, 0.35, &"shoot_1h", 15.0, ["cc", "ranged", "interrupt"],
		[{"t": 0.1, "type": "projectile", "sfx": "gun_pistol_stun", "speed": 16.0, "range": 16.0, "radius": 0.45, "aim": "target", "visual": "bullet",
		"scale": 1.7, "color": Color(1.0, 0.95, 0.3), "hit": hit(0.8, {"stun": 1.6, "hitstun": 0.4, "knockback": 0.5})},
		{"t": 0.1, "type": "sfx", "name": "gun_pistol_stun"}],
		{"charges": 2, "cancel_window": 0.15, "desc": "特殊弹药：飞行较慢的子弹，命中造成强力眩晕。 Slow special bullet with a strong stun."})

	# ---------------------------------------------------------------- slot 4: ice bullet
	var ice := sk(4, "ice_bullet", "冰弹", "Ice Bullet", 8.0, 40.0, 0.35, &"shoot_1h", 16.0, ["cc", "ranged", "debuff"],
		[{"t": 0.1, "type": "projectile", "sfx": "ice_cast", "speed": 30.0, "range": 17.0, "radius": 0.4, "aim": "target", "visual": "bullet",
		"scale": 1.4, "color": Color(0.55, 0.9, 1.0),
		"hit": hit(0.9, {"element": "ice", "statuses": [st("slow", 3.0, 0.4)], "freeze_chance": 0.4, "hitstun": 0.4})},
		{"t": 0.1, "type": "sfx", "name": "gun_pistol"}],
		{"charges": 2, "cancel_window": 0.15, "desc": "特殊弹药：减速并有几率冰冻目标。 Special bullet that slows and may freeze the target."})

	# ---------------------------------------------------------------- slot 5: burst grenade
	var burst := sk(5, "burst_grenade", "爆缩式手雷", "Burst Grenade", 8.0, 45.0, 0.4, &"throw", 14.0, ["aoe", "ranged", "cc"],
		[_grenade(0.12, 3.2, hit(1.6, {"knockback": 11.0, "knockdown": true})), {"t": 0.12, "type": "sfx", "name": "grenade_throw"}],
		{"charges": 2, "cancel_window": 0.15, "desc": "爆缩手雷，大范围强力击飞。 Grenade whose blast hurls enemies far away."})

	# ---------------------------------------------------------------- slot 6: timed grenade
	var timed := sk(6, "timed_grenade", "定时式手雷", "Timed Grenade", 10.0, 50.0, 0.4, &"throw", 14.0, ["aoe", "ranged", "zone"],
		[{"t": 0.12, "type": "projectile", "sfx": "grenade_throw", "speed": 16.0, "gravity": 20.0, "range": 18.0, "radius": 0.35, "aim": "target",
		"visual": "grenade", "color": Color(1.0, 0.4, 0.3), "hit": hit(0.1, {"hitstun": 0.15, "knockback": 0.0})},
		{"t": 0.12, "type": "ground", "at": "target", "radius": 3.0, "delay": 1.6, "visual": "fire", "color": Color(1.0, 0.5, 0.25),
		"hit": hit(2.0, {"launch": 8.0, "knockback": 3.0})},
		{"t": 0.12, "type": "sfx", "name": "grenade_throw"}],
		{"charges": 2, "cancel_window": 0.15, "desc": "定时手雷落地后延时引爆，炸飞范围内敌人。 Grenade that detonates after a delay, blasting enemies upward."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var thunder := sk(7, "chaotic_thunder", "乱雷", "Chaotic Thunder", 60.0, 250.0, 1.2, &"throw", 14.0, ["ultimate", "aoe", "ranged"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.3)], "fx": "cast_glow"},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"}, {"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		_volley(0.2), _volley(0.45), _volley(0.7),
		{"t": 0.3, "type": "custom", "method": "flower_rain", "args": {"petals": 8, "r": 2.2, "dmg": 0.35, "delay": 0.5}},
		{"t": 0.2, "type": "sfx", "name": "throw"}, {"t": 0.45, "type": "sfx", "name": "throw"}, {"t": 0.7, "type": "sfx", "name": "throw"}],
		{"desc": "一把把手雷同时抛出，炸开漫天花火（天女散花）。 Throws handfuls of grenades at once - a field of blossoming explosions."})

	skills = [b1, floating, grenade, stun, ice, burst, timed, thunder]

	passives = [
		{"name_cn": "弹药扩充", "name_en": "Ammunition Expansion",
		"desc": "特殊弹药（浮空弹、僵直弹、冰弹）可储存 2 发，手雷可储存多枚。 Special bullets hold 2 charges; grenades hold several."},
		{"name_cn": "空中射击（后坐力）", "name_en": "Aerial Fire (Recoil)",
		"desc": "空中开枪产生少量上浮后坐力。 Shots fired in the air give a small upward recoil."},
	]


func _bullet(t: float, dmg: float) -> Dictionary:
	return {"t": t, "type": "projectile", "sfx": "gun_pistol", "speed": 40.0, "range": 16.0, "radius": 0.3, "aim": "target", "visual": "bullet",
		"color": BULLET, "hit": hit(dmg, {"hitstun": 0.25, "knockback": 0.6, "juggle_cost": 5.0})}


func _grenade(t: float, radius: float, blast: Dictionary) -> Dictionary:
	return {"t": t, "type": "projectile", "sfx": "grenade_throw", "speed": 17.0, "gravity": 20.0, "range": 18.0, "radius": 0.35, "aim": "target",
		"visual": "grenade", "color": Color(1.0, 0.55, 0.25), "hit": hit(0.2, {"hitstun": 0.2, "knockback": 0.5}),
		"explode": {"radius": radius, "hit": blast, "fx": "explosion"}}


func _volley(t: float) -> Dictionary:
	return {"t": t, "type": "projectile", "sfx": "throw", "count": 5, "spread": 70.0, "speed": 16.0, "gravity": 20.0, "range": 18.0,
		"radius": 0.35, "aim": "target", "visual": "grenade", "color": FLOWER_COLORS[int(t * 10.0) % FLOWER_COLORS.size()],
		"hit": hit(0.15, {"hitstun": 0.2, "knockback": 0.5}),
		"explode": {"radius": 1.8, "hit": hit(0.35, {"knockback": 2.0, "hitstun": 0.4, "juggle_cost": 6.0}), "fx": "fire_burst"}}


# ---------------------------------------------------------------- hooks
func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.has_tag("ranged") and skill.anim != &"throw":
		GU.air_recoil(f, RECOIL_UP, 0.0, RECOIL_CAP)


## Ice Bullet: chance to freeze (deterministic tests always freeze).
func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
	var chance := float(h.get("freeze_chance", 0.0))
	if chance <= 0.0 or victim == null or not victim.is_alive():
		return
	if bool(h.get("_blocked", false)):
		return      # a frontal block stops the freeze like any other hit CC
	var roll := 0.0 if Combat.deterministic else Combat.rng.randf()
	if roll < chance:
		apply_on_hit_status(f, victim, h, &"freeze", 1.2)


# ---------------------------------------------------------------- custom actions
## 乱雷 Chaotic Thunder: a flower of delayed grenade blasts around the target ("天女散花").
func flower_rain(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var center := GU.strike_center(runner, 18.0)
	var pts := GU.flower_points(center, int(args.get("petals", 8)), float(args.get("r", 2.2)), f.facing_yaw)
	var base_delay := float(args.get("delay", 0.5))
	for i in pts.size():
		GU.burst_at(runner, pts[i], {"radius": 2.0, "delay": base_delay + 0.06 * float(i), "visual": "fire",
			"color": FLOWER_COLORS[i % FLOWER_COLORS.size()],
			"hit": hit(float(args.get("dmg", 0.35)), {"knockback": 2.5, "hitstun": 0.45, "juggle_cost": 6.0})})
