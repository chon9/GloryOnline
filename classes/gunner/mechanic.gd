extends ClassKit
## 机械师 Mechanic (枪手系 Gunner). Rifle + mechanical box: bouncing mines and coils (traps), kamikaze seeker
## robots and bomber drones (summons), rotor-wing flight and an air compressor for peel.
## Famous: 肖时钦 Xiao Shiqin / 生灵灭 Life Extinguisher / Flashing Shadow (rifle).

const GU := preload("res://classes/gunner/_gunner_util.gd")

const RECOIL_UP: float = 1.6
const RECOIL_CAP: float = 3.0
const MARK_TIME: float = 4.0
const MARK_BONUS: float = 0.2
const ROTOR_LIFT: float = 0.85
const ROTOR_MAX_FALL: float = -0.45
const ROTOR_MAX_ALT: float = 3.0         # rotor flight stays within melee / ground-AoE reach
const STEEL := Color(0.3, 0.85, 1.0)


func define() -> void:
	id = "mechanic"
	name_cn = "机械师"
	name_en = "Mechanic"
	group_id = "gunner"
	group_cn = "枪手系"
	group_en = "Gunner"
	role = "support"
	weapon_type = "rifle"
	weapon_name_cn = "步枪"
	weapon_name_en = "Rifle"
	offhand = "mech_box"
	model = "mechanic"
	tint = STEEL
	famous = "肖时钦 Xiao Shiqin / 生灵灭 Life Extinguisher / Flashing Shadow"
	stats = {"hp": 7000.0, "mp": 1400.0, "mp_regen": 20.0, "patk": 690.0, "matk": 470.0,
		"pdef": 400.0, "mdef": 400.0, "move_speed": 6.0, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: penetrating rifle shots
	var r1 := sk(0, "rifle_1", "普攻·步枪", "Rifle Shot", 0.0, 0.0, 0.65, &"shoot_2h", 18.0, ["ranged", "combo"],
		[_rifle(0.15, 0.5, 1.0), {"t": 0.15, "type": "sfx", "name": "shot"}],
		{"cancel_window": 0.12, "chain": ["rifle_1", "rifle_2"],
		"desc": "步枪穿透射击，命中一条线上的敌人。 Penetrating rifle shot."})
	sk(0, "rifle_2", "普攻·步枪重击", "Rifle Heavy Shot", 0.0, 0.0, 0.75, &"shoot_2h", 18.0, ["ranged", "combo"],
		[_rifle(0.18, 0.65, 2.5), {"t": 0.18, "type": "sfx", "name": "shot"}],
		{"cancel_window": 0.15, "desc": "更重的穿透射击。 Heavier penetrating shot."})

	# ---------------------------------------------------------------- slot 1: launcher mine
	var mine := sk(1, "bouncing_mine", "跳雷", "Bouncing Mine", 5.0, 30.0, 0.35, &"throw", 10.0,
		["launcher", "ranged", "zone", "combo"],
		[{"t": 0.12, "type": "trap", "trap_id": "earth", "visual": "earth", "at": "target", "distance": 5.0, "max_distance": 12.0,
		"radius": 1.8, "arm_time": 0.35, "duration": 15.0, "max_active": 3, "color": Color(1.0, 0.7, 0.3),
		"hit": hit(1.1, {"launch": 10.5, "knockback": 0.5, "hitstun": 0.5, "gadget": true})},
		{"t": 0.12, "type": "sfx", "name": "trap"}],
		{"cancel_window": 0.15, "desc": "抛出跳雷，敌人踩中后弹起爆炸将其炸上浮空。 Pop-up mine: it springs up under the enemy and launches them."})

	# ---------------------------------------------------------------- slot 2: kamikaze robot
	var seeker := sk(2, "mechanical_seeker", "机械追踪", "Mechanical Seeker", 8.0, 40.0, 0.4, &"summon", 12.0, ["summon", "ranged"],
		[{"t": 0.15, "type": "summon", "summon_id": "seeker", "count": 1, "duration": 8.0, "offset": 1.5, "max_active": 3},
		{"t": 0.15, "type": "sfx", "name": "metal"}],
		{"charges": 2, "desc": "放出追踪机器人，冲向敌人自爆。 Releases a robot that chases the enemy and self-destructs."})

	# ---------------------------------------------------------------- slot 3: rocket punch
	var rocket := sk(3, "rocket_punch", "火箭拳", "Rocket Punch", 7.0, 40.0, 0.4, &"punch", 16.0, ["ranged", "cc"],
		[{"t": 0.12, "type": "projectile", "speed": 28.0, "range": 16.0, "radius": 0.5, "aim": "target", "visual": "missile",
		"scale": 1.4, "color": STEEL, "hit": hit(1.6, {"knockdown": true, "knockback": 8.0, "gadget": true})},
		{"t": 0.12, "type": "sfx", "name": "cannon"}],
		{"cancel_window": 0.15, "desc": "发射火箭推进的机械拳，击倒命中的敌人。 A rocket-propelled fist that knocks the enemy down."})

	# ---------------------------------------------------------------- slot 4: weight trap
	var coil := sk(4, "electromagnetic_coil", "磁场线圈", "Electromagnetic Coil", 10.0, 45.0, 0.35, &"throw", 10.0,
		["zone", "debuff", "cc", "ranged"],
		[{"t": 0.12, "type": "trap", "trap_id": "coil", "visual": "lightning", "at": "target", "distance": 5.0, "max_distance": 12.0,
		"radius": 2.2, "arm_time": 0.3, "duration": 15.0, "max_active": 2, "color": STEEL,
		"hit": hit(0.5, {"hitstun": 0.5, "knockback": 0.0, "gadget": true}),
		"on_trigger_statuses": [st("weight", 5.0, 0.5), st("slow", 5.0, 0.3)]},
		{"t": 0.12, "type": "sfx", "name": "trap"}],
		{"cancel_window": 0.15, "desc": "布置磁场线圈陷阱，触发后大幅增加敌人负重。 Coil trap that weighs down whoever triggers it."})

	# ---------------------------------------------------------------- slot 5: timed flight
	var rotor := sk(5, "rotor_wings", "机械旋翼", "Rotor Wings", 14.0, 40.0, 0.3, &"jump", 0.0, ["escape", "buff_self"],
		[{"t": 0.0, "type": "launch_self", "vertical": 8.0, "forward": 4.0},
		{"t": 0.0, "type": "custom", "method": "rotor_on", "args": {"dur": 4.0}},
		{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("haste", 4.0, 0.2)]},
		{"t": 0.0, "type": "sfx", "name": "dash"}],
		{"desc": "背上机械旋翼限时飞行，可在空中射击。 Rotor backpack: timed flight, keep shooting from the air."})

	# ---------------------------------------------------------------- slot 6: blow-away device
	var compressor := sk(6, "air_compressor", "空气压缩机", "Air Compressor", 12.0, 50.0, 0.5, &"throw", 4.0,
		["aoe", "escape", "cc", "defensive"],
		[{"t": 0.2, "type": "ground", "at": "self", "radius": 4.5, "visual": "wind", "color": Color(0.8, 0.95, 1.0),
		"hit": hit(1.2, {"knockback": 14.0, "knockdown": true, "gadget": true})},
		{"t": 0.2, "type": "sfx", "name": "explosion"}],
		{"cancel_window": 0.15, "desc": "放下空气压缩机，巨大气浪吹飞周围敌人。 A compressor blast that blows every nearby enemy away."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var air_drops := sk(7, "air_drops", "机械空投", "Air Drops", 75.0, 300.0, 1.1, &"summon", 14.0,
		["ultimate", "aoe", "summon", "ranged"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.2)], "fx": "cast_glow"},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"}, {"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.3, "type": "summon", "summon_id": "bomber", "count": 2, "duration": 10.0, "offset": 2.0, "max_active": 2},
		{"t": 0.4, "type": "custom", "method": "air_drop", "args": {"n": 8, "r": 3.0, "dmg": 0.5}}],
		{"desc": "呼叫轰炸无人机，对目标区域螺旋空投炸弹。 Calls bomber drones and a spiral carpet of air-dropped bombs."})

	skills = [r1, mine, seeker, rocket, coil, rotor, compressor, air_drops]

	summons = {
		"seeker": {
			"name_cn": "机械追踪者", "name_en": "Mechanical Seeker", "model": "robot_one", "weapon_type": "", "scale": 0.55,
			"tint": STEEL,
			"stats": {"hp": 600.0, "mp": 0.0, "patk": 560.0, "pdef": 250.0, "mdef": 250.0, "move_speed": 8.0},
			"skills": [sk(0, "seeker_blast", "自爆", "Self-Destruct", 0.5, 0.0, 0.3, &"attack", 1.8, ["melee", "aoe"],
				[{"t": 0.1, "type": "melee", "shape": "circle", "range": 2.4, "fx": "explosion",
				"hit": hit(1.6, {"knockback": 6.0, "knockdown": true})},
				{"t": 0.1, "type": "sfx", "name": "explosion"},
				{"t": 0.12, "type": "custom", "method": "seeker_detonate", "args": {}}],
				{"desc": "冲到敌人身边自爆。 Explodes next to the enemy."})],
		},
		"bomber": {
			"name_cn": "轰炸无人机", "name_en": "Bomber Drone", "model": "robot_two", "weapon_type": "", "scale": 0.6,
			"tint": STEEL,
			"stats": {"hp": 900.0, "mp": 0.0, "patk": 480.0, "pdef": 300.0, "mdef": 300.0, "move_speed": 7.0},
			"skills": [sk(0, "bomber_bomb", "空投炸弹", "Drone Bomb", 2.5, 0.0, 0.4, &"throw", 9.0, ["ranged", "aoe"],
				[{"t": 0.15, "type": "ground", "at": "target", "radius": 2.2, "delay": 0.5, "visual": "fire",
				"color": Color(1.0, 0.55, 0.2), "hit": hit(0.7, {"knockback": 3.0, "hitstun": 0.4})}],
				{"desc": "向目标投下炸弹。 Drops a bomb on the target."})],
		},
	}

	passives = [
		{"name_cn": "机械箱", "name_en": "Mechanical Box",
		"desc": "机械装置（地雷、线圈、火箭拳、压缩机）及机器人、无人机命中会标记敌人 4 秒，步枪射击被标记的敌人额外造成 20% 伤害。 Gadget, robot and drone hits mark enemies for 4 s; rifle shots deal +20% to marked enemies."},
		{"name_cn": "空中射击（后坐力）", "name_en": "Aerial Fire (Recoil)",
		"desc": "空中开枪产生少量上浮后坐力，配合机械旋翼可长时间空中作战。 Shots in the air give a small upward recoil; combine with Rotor Wings."},
	]


func _rifle(t: float, dmg: float, kb: float) -> Dictionary:
	return {"t": t, "type": "projectile", "speed": 50.0, "range": 22.0, "radius": 0.3, "pierce": true, "aim": "target",
		"visual": "bullet", "scale": 1.2, "color": Color(0.8, 0.95, 1.0),
		"hit": hit(dmg, {"hitstun": 0.35, "knockback": kb, "juggle_cost": 7.0, "rifle": true})}


# ---------------------------------------------------------------- hooks
func on_tick(f: Fighter, delta: float) -> void:
	_tick_marks(f, delta)
	var rt := float(f.get_meta(&"rotor_t", 0.0))
	if rt <= 0.0:
		return
	rt -= delta
	match f.state:
		Fighter.State.LAUNCHED, Fighter.State.HITSTUN, Fighter.State.STUNNED, Fighter.State.GRABBED, Fighter.State.KNOCKDOWN:
			rt = 0.0      # shot down
		_:
			if not f.is_on_floor():
				# Glide only while descending (CORE gravity_scale + fall cap), never extends the climb.
				if f.velocity.y <= 0.0:
					f.set_hover(1.0 - ROTOR_LIFT, -ROTOR_MAX_FALL)
				else:
					f.clear_hover()
				var w := f.world()
				if w != null and f.global_position.y - w.ground_y(f.global_position) > ROTOR_MAX_ALT:
					f.velocity.y = minf(f.velocity.y, 0.0)
			else:
				f.clear_hover()
	if rt <= 0.0:
		f.clear_hover()
	f.set_meta(&"rotor_t", maxf(rt, 0.0))


func on_skill_cast(f: Fighter, skill: SkillDef) -> void:
	if skill.has_tag("ranged") and skill.anim == &"shoot_2h":
		GU.air_recoil(f, RECOIL_UP, 0.0, RECOIL_CAP)


## 机械箱 Mechanical Box: gadget hits mark, rifle shots punish marked targets. Hits by the Mechanic's own robots
## and drones (CORE forwards summon hits with hit["_by_summon_uid"]) are machine hits too and also mark.
func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, dmg: float) -> void:
	if victim == null or not victim.is_alive():
		return
	if bool(h.get("gadget", false)) or h.has("_by_summon_uid"):
		if not apply_on_hit_status(f, victim, h, &"mark", MARK_TIME):      # visible mark (shared status id)
			return
		var marks: Dictionary = f.get_meta(&"mech_marks", {})
		marks[victim.get_instance_id()] = MARK_TIME           # own bookkeeping: only OUR gadget marks count
		f.set_meta(&"mech_marks", marks)
	elif bool(h.get("rifle", false)) and dmg > 0.0 and has_own_mark(f, victim):
		victim.take_dot_damage(dmg * MARK_BONUS, f, &"mark")


## True when `victim` carries a mark from this Mechanic's own gadgets (other classes' marks do not count).
func has_own_mark(f: Fighter, victim: Fighter) -> bool:
	var marks: Dictionary = f.get_meta(&"mech_marks", {})
	return float(marks.get(victim.get_instance_id(), 0.0)) > 0.0


func _tick_marks(f: Fighter, delta: float) -> void:
	if not f.has_meta(&"mech_marks"):
		return
	var marks: Dictionary = f.get_meta(&"mech_marks")
	for k in marks.keys():
		var left := float(marks[k]) - delta
		if left <= 0.0:
			marks.erase(k)
		else:
			marks[k] = left


# ---------------------------------------------------------------- custom actions
func rotor_on(f: Fighter, args: Dictionary, _runner: SkillRunner) -> void:
	f.set_meta(&"rotor_t", float(args.get("dur", 4.0)))


func on_death(f: Fighter, _killer: Fighter) -> void:
	f.set_meta(&"rotor_t", 0.0)
	f.clear_hover()


## Seeker robot self-destruct (called with the summon as caster; method lives on the owner's kit).
func seeker_detonate(f: Fighter, _args: Dictionary, _runner: SkillRunner) -> void:
	if f is Summon:
		(f as Summon).expire()


## 机械空投 Air Drops: a spiral carpet of delayed bombs around the target.
func air_drop(_f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var center := GU.strike_center(runner, 18.0)
	var pts := GU.spiral_points(center, int(args.get("n", 8)), float(args.get("r", 3.0)))
	for i in pts.size():
		GU.burst_at(runner, pts[i], {"radius": 2.2, "delay": 0.5 + 0.12 * float(i), "visual": "fire",
			"color": Color(1.0, 0.55, 0.2),
			"hit": hit(float(args.get("dmg", 0.5)), {"knockback": 2.5, "hitstun": 0.45, "juggle_cost": 6.0,
			"launch": 7.0 if i == 0 else 0.0})})
