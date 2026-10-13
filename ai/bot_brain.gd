class_name BotBrain
extends Node
## AI brain (ARCHITECTURE §8). Drives a Fighter exactly like a human would, only through `fighter.input`
## (move, aim_point, target_uid, press(slot), jump). Host only; attached by World.attach_brain(f, mode).
##
## Modes:
##  "pvp"  - duels and team fights (role-aware: melee / ranged / healer / tank / control / summoner).
##  "raid" - party member vs mobs/boss (tank holds the boss facing away, dps behind it, healer heals).
##  "pet"  - summon: follows its owner, attacks the owner's target or the nearest enemy within the leash.
##  "mob"  - trash mob: threat-table targeting, skills on cooldown, leashes home (20 m) with a full heal.
##
## Two-layer timing:
##  - think(delta) runs every physics step but only does work at ~20 Hz (THINK_INTERVAL): steering,
##    executing the current plan, combo follow-ups in cancel windows, telegraph dodging.
##  - decisions (target selection, which skill to use next, positioning style) only update every
##    `react` seconds (difficulty dependent), so lower difficulties feel slower and are beatable.
## Quick recovery (受身) is checked every step because its window is only 0.25 s.

const THINK_INTERVAL: float = 0.05
const PET_FOLLOW_DIST: float = 3.0
const PET_LEASH: float = 12.0
const MOB_LEASH: float = 20.0
const MOB_AGGRO: float = 9.0
const MOB_SOCIAL: float = 8.0
const FOCUS_INTERVAL: float = 1.0
const LOOK_AHEAD: float = 1.6
const RAID_ENGAGE_RANGE: float = 80.0          # bot-only parties: leader pulls the nearest pack

## Difficulty table (Game.settings.bot_difficulty 0..3).
## react: decision delay (s). aim_err: aim scatter (m). lead: projectile/telegraph lead factor.
## combo: chance a decision window allows cancel-window follow-ups. dodge: telegraph dodge chance.
## recover: quick recovery chance; rec_lo/rec_hi: delay range after landing (window is 0.25 s).
## skill_use: chance a decision considers non-basic skills. spacing: chance to back out of enemy swings.
## proj_dodge: chance to sidestep an incoming projectile.
const DIFF: Array[Dictionary] = [
	{"react": 0.45, "aim_err": 1.8, "lead": 0.0, "combo": 0.30, "dodge": 0.20, "recover": 0.15,
		"rec_lo": 0.10, "rec_hi": 0.40, "skill_use": 0.65, "spacing": 0.0, "proj_dodge": 0.0, "ult_hp": 0.30},
	{"react": 0.30, "aim_err": 1.1, "lead": 0.35, "combo": 0.55, "dodge": 0.45, "recover": 0.40,
		"rec_lo": 0.06, "rec_hi": 0.30, "skill_use": 0.85, "spacing": 0.15, "proj_dodge": 0.10, "ult_hp": 0.40},
	{"react": 0.16, "aim_err": 0.5, "lead": 0.70, "combo": 0.82, "dodge": 0.70, "recover": 0.70,
		"rec_lo": 0.03, "rec_hi": 0.20, "skill_use": 0.95, "spacing": 0.35, "proj_dodge": 0.35, "ult_hp": 0.45},
	{"react": 0.08, "aim_err": 0.15, "lead": 1.0, "combo": 0.96, "dodge": 0.90, "recover": 0.90,
		"rec_lo": 0.02, "rec_hi": 0.12, "skill_use": 1.0, "spacing": 0.60, "proj_dodge": 0.60, "ult_hp": 0.50},
]

## Tests can force a seed / difficulty for every new brain.
static var rng_seed: int = 0
static var difficulty_override: int = -1

var fighter: Fighter = null
var mode: String = "pvp"
var difficulty: int = 1
var cfg: Dictionary = {}
## Statistics (tests / debugging).
var dodges_attempted: int = 0
var recoveries_attempted: int = 0

var _rng := RandomNumberGenerator.new()
var _ready_done: bool = false
var _clock: float = 0.0
var _think_acc: float = 0.0
var _decide_left: float = 0.0
var _role: String = "melee"
var _ranged_style: bool = false
var _pref_range: float = 2.5
var _profiles: Dictionary = {}           # SkillDef id -> profile Dictionary

# current decision
var _target: Fighter = null
var _plan_slot: int = -1
var _plan_ally: Fighter = null
var _plan_escape: bool = false
var _plan_healer_taunt_flag: bool = false
var _hold_fire: bool = false             # raid threat discipline: let the tank build aggro first
var _style: String = "approach"          # approach | band | point | hold
var _want_dist: float = 2.0
var _band_lo: float = 4.0
var _band_hi: float = 10.0
var _goal: Vector3 = Vector3.ZERO
var _combo_ok: bool = false
var _skills_ok: bool = true

# movement
var _move: Vector3 = Vector3.ZERO
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _backstep_left: float = 0.0
var _sidestep_left: float = 0.0
var _sidestep_dir: Vector3 = Vector3.ZERO
var _seen_events: Dictionary = {}
var _detour_sign: float = 0.0
var _detour_left: float = 0.0

# dangers
var _tele: Dictionary = {}               # area instance id -> {dodge: bool, at: float}
var _avoid: Array[AreaEffect] = []       # active enemy zones / traps to keep out of
var _threats: Array[AreaEffect] = []     # areas (telegraphs/zones) currently on us that we decided to leave
var _dodging: bool = false
var _dodge_point: Vector3 = Vector3.ZERO
var _dodge_urgency: float = 9.0
var _unavoid_left: float = 9.0          # time to an un-dodgeable (raid-wide) telegraph; 9 = none

# quick recovery
var _prev_state: int = -1
var _kd_jump_at: float = -1.0

# mob
var _home: Vector3 = Vector3.ZERO
var _returning: bool = false

# map hazards (ArenaMap.is_hazard, e.g. Lava Cave lava)
var _hazard_map: Node = null
var _hazard_scan_at: float = -99.0
var _in_hazard: bool = false
var _hazard_blocked: bool = false        # steering refused a straight path because of a hazard

# broom flight (Witch: second jump in mid-air mounts the broom)
var _can_fly: bool = false
var _want_fly: bool = false
var _fly_phase: int = 0                  # 0 grounded, 1 jumped (waiting to mount), 2 flying
var _fly_t: float = 0.0
var _fly_next_ok: float = 0.0
var flights_started: int = 0

# boss mechanics read from the boss's brain (RAID BossBrain: `shares` soak circles, `channel` interrupts)
var _boss: Fighter = null
var _share_pos: Vector3 = Vector3.INF
var _share_r: float = 0.0
var _share_left: float = 0.0
var interrupts_attempted: int = 0
var parries_attempted: int = 0
var healer_taunts: int = 0
var _parry_wait: bool = false
var _parry_seen: Dictionary = {}         # enemy uid -> start time of the last cast we reacted to            # an enemy strike we intend to parry is imminent


func _init() -> void:
	set_physics_process(true)


## Called by World.attach_brain.
func setup(f: Fighter, p_mode: String = "pvp") -> void:
	fighter = f
	mode = p_mode
	_ready_done = false


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter
	_init_brain()


func _init_brain() -> void:
	if _ready_done or fighter == null:
		return
	_ready_done = true
	var d := difficulty_override
	if d < 0:
		d = int(CoreUtil.setting("bot_difficulty", 1))
	set_difficulty(d)
	_rng.seed = hash([rng_seed, fighter.uid, mode])
	_strafe_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_home = fighter.global_position
	_role = fighter.kit.role if fighter.kit != null else str(fighter.mob_def.get("role", "melee"))
	if _role in ["elite", "boss", "", "mob"]:
		_role = "melee"
	_can_fly = fighter.kit != null and fighter.kit.has_method("is_flying") and mode != "pet"
	_analyze_kit()
	_decide_left = _rng.randf_range(0.0, float(cfg["react"]))


func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, DIFF.size() - 1)
	cfg = DIFF[difficulty]


func _physics_process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	var w := fighter.world()
	if w != null and w.auto_step and w.is_host():
		think(delta)


# ================================================================== main loop
func think(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	if not _ready_done:
		_init_brain()
	_clock += delta
	var inp := fighter.input
	if not fighter.is_alive():
		inp.move = Vector3.ZERO
		_move = Vector3.ZERO
		_prev_state = fighter.state
		return
	_tick_recovery(inp)
	_think_acc += delta
	if _think_acc < THINK_INTERVAL:
		return
	var dt := _think_acc
	_think_acc = 0.0
	var w := fighter.world()
	if w == null:
		return
	_strafe_timer -= dt
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(1.2, 3.0)
		_strafe_sign = -_strafe_sign
	_backstep_left = maxf(0.0, _backstep_left - dt)
	_detour_left = maxf(0.0, _detour_left - dt)
	_sidestep_left = maxf(0.0, _sidestep_left - dt)
	if _target != null and not _usable(w, _target):
		_target = null
	_hazard_source(w)
	_scan_dangers(w)
	if mode == "raid":
		_scan_boss_mechanics(w)
	_decide_left -= dt
	if _decide_left <= 0.0:
		_decide_left = maxf(THINK_INTERVAL, float(cfg["react"]) * _rng.randf_range(0.8, 1.2))
		_decide(w)
	_act(w, dt)


func _tick_recovery(inp: FighterInput) -> void:
	var s := fighter.state
	if s == Fighter.State.KNOCKDOWN and _prev_state != Fighter.State.KNOCKDOWN:
		_kd_jump_at = -1.0
		if _rng.randf() < float(cfg["recover"]):
			_kd_jump_at = _clock + _rng.randf_range(float(cfg["rec_lo"]), float(cfg["rec_hi"]))
	if s == Fighter.State.KNOCKDOWN and _kd_jump_at >= 0.0 and _clock >= _kd_jump_at:
		inp.jump = true
		_kd_jump_at = -1.0
		recoveries_attempted += 1
	if s != Fighter.State.KNOCKDOWN:
		_kd_jump_at = -1.0
	_prev_state = s


# ================================================================== skill profiles
func _analyze_kit() -> void:
	_profiles.clear()
	var reaches: Array[float] = []
	for s: SkillDef in fighter.skills:
		var p := profile(s)
		if float(p["dmg"]) > 0.0 and (bool(p["ranged"]) or not bool(p["melee"])):
			reaches.append(float(p["reach"]))
		elif float(p["dmg"]) > 0.0:
			reaches.append(float(p["reach"]))
	reaches.sort()
	var med := 2.5
	if not reaches.is_empty():
		med = reaches[int(reaches.size() / 2.0)]
	var basic := fighter.get_skill(0)
	var basic_ranged := basic != null and bool(profile(fighter.resolve_skill(0))["ranged"])
	_ranged_style = _role in ["ranged", "healer", "summoner"] or (basic_ranged and med >= 6.0) \
		or (_role in ["control", "support"] and med >= 7.0)
	if mode == "pet":
		_ranged_style = basic_ranged
	elif mode == "mob":
		# Mob defs carry an AI role hint (mob_def.role): ranged / healer mobs keep their distance.
		_ranged_style = basic_ranged or (_role in ["ranged", "healer", "summoner"] and med >= 5.0)
	_pref_range = clampf(med * 0.7, 4.5, 13.0) if _ranged_style else 2.0


## Cached analysis of a SkillDef's steps (works with any kit, independent of tags).
func profile(s: SkillDef) -> Dictionary:
	if s == null:
		return _empty_profile()
	if _profiles.has(s.id):
		return _profiles[s.id]
	var p := analyze_skill(s)
	_profiles[s.id] = p
	return p


static func _empty_profile() -> Dictionary:
	return {
		"dmg": 0.0, "launch": 0.0, "knockdown": false, "disable": false, "cc": false, "grab": false,
		"otg": false, "armor_break": false, "reach": 0.0, "melee": false, "ranged": false, "aimed": false,
		"proj_speed": 0.0, "self_aoe": false, "aoe": false, "move": "", "move_dist": 0.0, "move_aim": false,
		"heal": 0.0, "heal_mode": "", "revive": false, "heal_radius": 12.0, "ally_zone": false,
		"defensive": false, "stealth": false, "buff_ally": false, "buff_self": false, "taunt": false,
		"taunt_radius": 0.0, "summon": "", "summon_max": 0, "cleanse": false, "delay": 0.0, "pull": false,
		"debuff": false, "ult": false, "finisher": false, "combo": false, "launcher": false, "trap": false,
		"mp": 0.0, "cd": 0.0, "time": 0.0, "custom": false, "parry": false, "trap_target": false,
	}


static func analyze_skill(s: SkillDef) -> Dictionary:
	var p := _empty_profile()
	if s == null:
		return p
	p["ult"] = s.is_ultimate()
	p["mp"] = s.mp_cost
	p["cd"] = s.cooldown
	p["time"] = s.total_time()
	for st: Dictionary in s.steps:
		_analyze_step(p, st, s, 0)
	var reach := float(p["reach"])
	var tags := s.tags
	if tags.has("launcher"):
		p["launcher"] = true
		if float(p["launch"]) <= 0.0:
			p["launch"] = 8.0
	if float(p["launch"]) > 0.0:
		p["launcher"] = true
	if tags.has("finisher") or bool(p["knockdown"]):
		p["finisher"] = true
	if tags.has("combo"):
		p["combo"] = true
	if tags.has("gap_closer") and str(p["move"]) == "":
		p["move"] = "toward"
		p["move_dist"] = maxf(s.range, 5.0)
	if tags.has("escape") and str(p["move"]) == "":
		p["move"] = "away"
		p["move_dist"] = maxf(s.range, 5.0)
	if tags.has("escape") and str(p["move"]) == "toward":
		p["move_aim"] = true
	if tags.has("defensive"):
		p["defensive"] = true
	# Parry / counter stances: only worth casting right before an enemy swing lands.
	if tags.has("defensive") and tags.has("interrupt") or tags.has("parry") or tags.has("counter"):
		p["parry"] = true
	if tags.has("buff_self") and not bool(p["defensive"]):
		p["buff_self"] = true
	if tags.has("buff_ally"):
		p["buff_ally"] = true
	if tags.has("cc") or tags.has("interrupt"):
		p["cc"] = true
	if tags.has("heal") and float(p["heal"]) <= 0.0 and not bool(p["cleanse"]):
		p["heal"] = 0.15
		p["heal_mode"] = "ally_lowest"
	if tags.has("grab"):
		p["grab"] = true
	if tags.has("ranged"):
		p["ranged"] = true
	if tags.has("aoe"):
		p["aoe"] = true
	# Damage hidden in kit code: trust offensive tags so the skill still gets used.
	if float(p["dmg"]) <= 0.0 and float(p["heal"]) <= 0.0 and str(p["summon"]) == "" and not bool(p["taunt"]):
		var offensive := false
		for tg: String in ["launcher", "finisher", "combo", "melee", "ranged", "aoe", "grab"]:
			if tags.has(tg):
				offensive = true
		if offensive or (bool(p["custom"]) and bool(p["ult"])):
			p["dmg"] = 1.5 if bool(p["ult"]) else 1.0
			if not bool(p["melee"]) and not bool(p["ranged"]):
				if s.range >= 5.0:
					p["ranged"] = true
				else:
					p["melee"] = true
	if reach <= 0.0:
		reach = s.range
	if not bool(p["ranged"]) and float(p["dmg"]) > 0.0 and s.range > 0.0:
		reach = minf(reach, maxf(s.range, 1.5)) if bool(p["melee"]) else maxf(reach, s.range)
	p["reach"] = reach
	return p


static func _analyze_step(p: Dictionary, st: Dictionary, s: SkillDef, depth: int) -> void:
	var typ := str(st.get("type", ""))
	match typ:
		"melee", "multi_melee":
			var n := int(st.get("count", 3)) if typ == "multi_melee" else 1
			_add_hit(p, st.get("hit", {}), n)
			p["melee"] = true
			var shape := str(st.get("shape", "arc"))
			var r := float(st.get("range", 2.5)) + float(st.get("offset", 0.0))
			if shape == "circle":
				p["self_aoe"] = true
			p["reach"] = maxf(float(p["reach"]), r)
		"projectile":
			var n := maxi(1, int(st.get("count", 1)))
			var spread := float(st.get("spread", 0.0))
			_add_hit(p, st.get("hit", {}), 1 if spread > 25.0 else n)
			var ex: Variant = st.get("explode", {})
			if ex is Dictionary and not (ex as Dictionary).is_empty():
				_add_hit(p, (ex as Dictionary).get("hit", {}), 1)
				p["aoe"] = true
			p["ranged"] = true
			var homing := float(st.get("homing", 0.0))
			p["aimed"] = homing < 1.0
			p["proj_speed"] = float(st.get("speed", 22.0))
			p["reach"] = maxf(float(p["reach"]), float(st.get("range", 18.0)) * 0.9)
		"ground":
			var at := str(st.get("at", "target"))
			var aff := str(st.get("affects", "enemies"))
			var dur := float(st.get("duration", 0.0))
			var tick := maxf(0.05, float(st.get("tick", 0.5)))
			var shape := str(st.get("shape", "circle"))
			var rad := float(st.get("radius", 3.0))
			var size := rad if shape != "line" else float(st.get("length", maxf(rad * 2.0, 6.0)))
			var ae: Variant = st.get("ally_effect", {})
			if (aff == "allies" or aff == "all") and ae is Dictionary and not (ae as Dictionary).is_empty():
				var ticks := 1.0 + (dur / tick if dur > 0.0 else 0.0)
				var h := float((ae as Dictionary).get("heal", 0.0)) + float((ae as Dictionary).get("matk_scale", 0.0)) * 0.08
				if h > 0.0:
					p["heal"] = float(p["heal"]) + h * ticks
					p["ally_zone"] = true
					p["heal_mode"] = "zone_self" if at == "self" else "zone_target"
					p["heal_radius"] = rad
				if float((ae as Dictionary).get("shield", 0.0)) > 0.0 or (ae as Dictionary).has("statuses"):
					p["buff_ally"] = true
			if aff != "allies" and st.has("hit"):
				var n := 1
				if dur > 0.0:
					n = clampi(int(dur / tick), 1, 6)
				_add_hit(p, st.get("hit", {}), n)
				p["aoe"] = true
				if at == "self" or at == "forward" or shape == "line":
					p["self_aoe"] = at == "self" and shape != "line"
					p["reach"] = maxf(float(p["reach"]), size * 0.9 if shape != "line" else size * 0.95)
					if shape == "line" or at == "forward":
						p["ranged"] = true
				else:
					p["ranged"] = true
					p["aimed"] = true
					p["reach"] = maxf(float(p["reach"]), maxf(s.range, float(st.get("distance", 6.0))))
				p["delay"] = maxf(float(p["delay"]), float(st.get("delay", 0.0)))
		"beam":
			var dur := float(st.get("duration", 0.6))
			var tick := maxf(0.05, float(st.get("tick", 0.15)))
			_add_hit(p, st.get("hit", {}), clampi(int(dur / tick), 1, 8))
			p["ranged"] = true
			p["reach"] = maxf(float(p["reach"]), float(st.get("length", 14.0)) * 0.9)
		"dash":
			var dirm := str(st.get("direction", "forward"))
			p["move"] = "away" if dirm == "back" else "toward"
			p["move_aim"] = dirm == "aim" or dirm == "forward"
			p["move_dist"] = maxf(float(p["move_dist"]), float(st.get("distance", 6.0)))
			if st.has("hit"):
				_add_hit(p, st.get("hit", {}), 1)
				p["reach"] = maxf(float(p["reach"]), float(st.get("distance", 6.0)))
		"blink":
			var to := str(st.get("to", "aim_point"))
			if to == "back":
				p["move"] = "away"
			elif to == "behind_target" or to == "target":
				p["move"] = "toward"
			else:
				p["move"] = "toward"
				p["move_aim"] = true
			p["move_dist"] = maxf(float(p["move_dist"]), float(st.get("distance", 8.0)))
		"leap":
			var to := str(st.get("to", "target"))
			p["move"] = "toward"
			p["move_aim"] = to != "target"
			p["move_dist"] = maxf(float(p["move_dist"]), float(st.get("distance", 6.0)))
			var land: Variant = st.get("land", {})
			if land is Dictionary and (land as Dictionary).has("hit"):
				_add_hit(p, (land as Dictionary).get("hit", {}), 1)
				p["aoe"] = true
				p["reach"] = maxf(float(p["reach"]), float(st.get("distance", 6.0)))
		"buff":
			var tgt := str(st.get("target", "self"))
			var defensive := float(st.get("shield", 0.0)) > 0.0
			var offensive := false
			for x: Dictionary in CoreUtil.status_list(st.get("statuses", [])):
				var sid := StringName(x["id"])
				if sid in [&"super_armor", &"invuln", &"block", &"def_up", &"shield", &"regen"]:
					defensive = true
				elif sid == &"stealth":
					p["stealth"] = true
				elif sid in [&"atk_up", &"matk_up", &"haste"]:
					offensive = true
			if tgt == "self":
				p["defensive"] = bool(p["defensive"]) or defensive
				p["buff_self"] = bool(p["buff_self"]) or offensive
			else:
				p["buff_ally"] = true
				p["defensive"] = bool(p["defensive"]) or defensive
		"debuff":
			var dis := false
			for x: Dictionary in CoreUtil.status_list(st.get("statuses", [])):
				var sid := StringName(x["id"])
				if StatusSet.DISABLING.has(sid) or sid in [&"root", &"silence", &"confusion"]:
					dis = true
			if dis:
				p["cc"] = true
				p["disable"] = true
			else:
				p["debuff"] = true
			p["reach"] = maxf(float(p["reach"]), float(st.get("radius", 6.0)) * (1.0 if str(st.get("target", "target")) == "enemies" else 1.6))
			if str(st.get("target", "target")) == "enemies":
				p["self_aoe"] = true
		"heal":
			var amt := float(st.get("amount", 0.15)) + float(st.get("matk_scale", 0.0)) * 0.08
			var hot: Variant = st.get("hot", {})
			if hot is Dictionary and not (hot as Dictionary).is_empty():
				amt += float((hot as Dictionary).get("dur", 5.0)) * float((hot as Dictionary).get("power", 0.02))
			p["heal"] = float(p["heal"]) + amt
			p["heal_mode"] = str(st.get("target", "self"))
			p["heal_radius"] = float(st.get("radius", 12.0))
			if bool(st.get("revive", false)):
				p["revive"] = true
		"summon":
			p["summon"] = str(st.get("summon_id", ""))
			p["summon_max"] = maxi(1, int(st.get("max_active", 3)))
		"grab":
			p["grab"] = true
			p["armor_break"] = true
			_add_hit(p, st.get("hit", {}), 1)
			p["reach"] = maxf(float(p["reach"]), float(st.get("range", 1.8)) + 0.5)
		"taunt":
			p["taunt"] = true
			p["taunt_radius"] = float(st.get("radius", 8.0))
			p["reach"] = maxf(float(p["reach"]), float(p["taunt_radius"]) * 0.9)
		"trap":
			p["trap"] = true
			_add_hit(p, st.get("hit", {}), 1)
			var sts := CoreUtil.status_list(st.get("on_trigger_statuses", []))
			if not sts.is_empty():
				p["cc"] = true
			var tat := str(st.get("at", "self"))
			if tat == "target" or tat == "aim_point":
				# Gadgets thrown at the lock-on target (Mechanic mines / coils): a ranged placement.
				p["ranged"] = true
				p["trap_target"] = true
				var md := float(st.get("max_distance", maxf(s.range, float(st.get("distance", 5.0)) * 2.0)))
				p["reach"] = maxf(float(p["reach"]), minf(md, s.range if s.range > 0.0 else md))
			else:
				p["reach"] = maxf(float(p["reach"]), 2.5)
		"pull":
			p["pull"] = true
			if st.has("hit"):
				_add_hit(p, st.get("hit", {}), 1)
			p["reach"] = maxf(float(p["reach"]), float(st.get("radius", 7.0)) * 0.9)
			p["self_aoe"] = true
		"cleanse":
			p["cleanse"] = true
		"custom":
			# Kit logic: look inside the args for embedded steps / hits / damage multipliers.
			p["custom"] = true
			p["reach"] = maxf(float(p["reach"]), s.range)
			var args: Variant = st.get("args", {})
			if args is Dictionary and depth < 3:
				var ad: Dictionary = args
				if ad.get("step") is Dictionary:
					_analyze_step(p, ad["step"], s, depth + 1)
				if ad.get("steps") is Array:
					for sub: Variant in ad["steps"]:
						if sub is Dictionary:
							_analyze_step(p, sub, s, depth + 1)
				if ad.get("hit") is Dictionary:
					_add_hit(p, ad["hit"], 1)
				var dm: Variant = ad.get("dmg")
				if dm is float or dm is int:
					var cnt := 1
					for ck: String in ["count", "hits", "petals", "beams", "waves"]:
						if ad.get(ck) is int:
							cnt = maxi(cnt, int(ad[ck]))
					p["dmg"] = float(p["dmg"]) + float(dm) * float(mini(cnt, 6))


static func _add_hit(p: Dictionary, h: Variant, n: int) -> void:
	if not (h is Dictionary):
		return
	var d: Dictionary = h
	p["dmg"] = float(p["dmg"]) + float(d.get("dmg", 1.0)) * float(n)
	p["launch"] = maxf(float(p["launch"]), float(d.get("launch", 0.0)))
	if bool(d.get("knockdown", false)):
		p["knockdown"] = true
	if float(d.get("stun", 0.0)) > 0.0:
		p["disable"] = true
		p["cc"] = true
	for x: Dictionary in CoreUtil.status_list(d.get("statuses", [])):
		var sid := StringName(x["id"])
		if StatusSet.DISABLING.has(sid) or sid in [&"root", &"silence"]:
			p["disable"] = true
			p["cc"] = true
	if bool(d.get("otg", false)):
		p["otg"] = true
	if bool(d.get("armor_break", false)) or bool(d.get("grab", false)):
		p["armor_break"] = true


# ================================================================== perception helpers
func _enemies(w: World) -> Array[Fighter]:
	return w.enemies_of(fighter, false)


func _flat_dist(a: Fighter, b: Fighter) -> float:
	return CoreUtil.flat(a.global_position - b.global_position).length()


## Edge-to-edge distance (what melee hitboxes use).
func _surf(t: Fighter) -> float:
	return maxf(0.0, _flat_dist(fighter, t) - t.radius())


func _hp_frac(f: Fighter) -> float:
	return (f.hp + f.shield_hp) / maxf(1.0, f.max_hp)


static func _role_of(f: Fighter) -> String:
	if f == null:
		return ""
	if f.kit != null:
		return f.kit.role
	if f.kind == "boss":
		return "boss"
	return f.kind


func _is_launched(t: Fighter) -> bool:
	return t.state == Fighter.State.LAUNCHED


func _is_downed(t: Fighter) -> bool:
	return t.state == Fighter.State.KNOCKDOWN


func _untouchable(t: Fighter) -> bool:
	return t.status.has(&"invuln") or t.state == Fighter.State.GETUP


func _line_of_sight(w: World, t: Fighter) -> bool:
	var r := w.raycast(fighter.center(), t.center(), CoreUtil.LAYER_WORLD)
	return r.is_empty()


## Line of sight from a standing point `p` (our chest height there) to the target (World.raycast, world layer).
func _los_from(w: World, p: Vector3, t: Fighter) -> bool:
	var eye := Vector3(p.x, p.y, p.z) + (fighter.center() - fighter.global_position)
	return w.raycast(eye, t.center(), CoreUtil.LAYER_WORLD).is_empty()


## Nearest point around `t` at ~`dist` m (edge to edge) that is in bounds, out of danger and sees the target.
func _find_los_point(w: World, t: Fighter, dist: float) -> Vector3:
	var me := fighter.global_position
	var base := CoreUtil.flat_dir(me - t.global_position, fighter.forward() * -1.0)
	var best := Vector3.INF
	var best_c := INF
	for ring: float in [1.0, 0.6]:
		for i in 12:
			var dir := base.rotated(Vector3.UP, TAU * float(i) / 12.0)
			var p := t.global_position + dir * (t.radius() + maxf(2.0, dist * ring))
			p.y = me.y
			if not _in_bounds(w, p, 1.0) or _danger_at(p, fighter.radius() + 0.2):
				continue
			if not _los_from(w, p, t):
				continue
			var c := CoreUtil.flat(p - me).length()
			if c < best_c:
				best_c = c
				best = p
		if best != Vector3.INF:
			break
	return best


func _ehp(t: Fighter) -> float:
	var def := (t.get_stat("pdef") + t.get_stat("mdef")) * 0.5
	return (t.hp + t.shield_hp) / maxf(0.2, 1.0 - def / (def + 600.0))


func _enemy_profile_now(t: Fighter) -> Dictionary:
	if t.state != Fighter.State.CAST or t.runner == null or t.runner.skill == null:
		return {}
	return profile(t.runner.skill)


func _is_heal_role(f: Fighter) -> bool:
	return _role_of(f) == "healer"


# ================================================================== dangers (telegraphs / zones / traps)
func _scan_dangers(w: World) -> void:
	_avoid.clear()
	_threats.clear()
	var me := fighter.global_position
	var r_me := fighter.radius()
	var urgency := 9.0
	_unavoid_left = 9.0
	for e: Variant in w.effects:
		if not is_instance_valid(e) or not (e is AreaEffect):
			continue
		var a := e as AreaEffect
		if not a.alive or a.team == fighter.team:
			continue
		if a.affects == "allies":
			continue
		if a.mode == "trap":
			_avoid.append(a)
			continue
		if a.mode == "beam" or a.follow_caster:
			continue
		var left := a.delay - a._t
		var key := a.get_instance_id()
		if left > 0.0:
			# Raid-wide circles cannot be outrun: keep fighting, let defensives react instead.
			if a.shape == "circle" and a.radius > 15.0:
				if area_contains_point(a, me, r_me):
					_unavoid_left = minf(_unavoid_left, left)
				continue
			if not _tele.has(key):
				var ok := _rng.randf() < float(cfg["dodge"])
				_tele[key] = {"dodge": ok, "at": _clock + float(cfg["react"]) * _rng.randf_range(0.5, 0.9)}
			var info: Dictionary = _tele[key]
			if bool(info["dodge"]) and _clock >= float(info["at"]) and area_contains_point(a, me, r_me + 0.35):
				_threats.append(a)
				urgency = minf(urgency, left)
			_avoid.append(a)
		elif a.duration > 0.0 and not a.hit.is_empty():
			_avoid.append(a)
			if not _tele.has(key):
				_tele[key] = {"dodge": true, "at": _clock + float(cfg["react"])}
			if _clock >= float(_tele[key]["at"]) and area_contains_point(a, me, r_me + 0.2):
				_threats.append(a)
	if _tele.size() > 64:
		var live := {}
		for e: Variant in w.effects:
			if is_instance_valid(e) and _tele.has((e as Object).get_instance_id()):
				live[(e as Object).get_instance_id()] = _tele[(e as Object).get_instance_id()]
		_tele = live
	# Standing in a map hazard (lava) is a danger like a damaging zone: walk out of it.
	_in_hazard = _hazard_at(me)
	if _in_hazard:
		urgency = minf(urgency, 1.0)
	if _threats.is_empty() and not _in_hazard:
		_dodging = false
		return
	if not _dodging or _danger_at(_dodge_point, 0.45):
		var sp := _find_safe_point(w)
		if CoreUtil.flat(sp - me).length() < 0.5:
			# No reachable safe spot: do not freeze in place, fight on and use defensives.
			_unavoid_left = minf(_unavoid_left, urgency)
			_threats.clear()
			_dodging = false
			return
		_dodge_point = sp
		if not _dodging:
			dodges_attempted += 1
	_dodging = true
	_dodge_urgency = urgency


## Geometry identical to AreaEffect.contains, for an arbitrary point with an extra margin.
static func area_contains_point(a: AreaEffect, p: Vector3, margin: float) -> bool:
	var to := CoreUtil.flat(p - a.global_position)
	match a.shape:
		"line":
			var fwd := CoreUtil.dir_of_yaw(a.yaw)
			var rgt := fwd.cross(Vector3.UP)
			var z := to.dot(fwd)
			var x := to.dot(rgt)
			return z >= -margin and z <= a.length + margin and absf(x) <= a.width * 0.5 + margin
		"ring":
			var d := to.length()
			return d <= a.radius + margin and d >= maxf(0.0, a.radius - a.width) - margin
		_:
			return to.length() <= a.radius + margin


func _danger_at(p: Vector3, margin: float) -> bool:
	if _hazard_at(p):
		return true
	for a: AreaEffect in _avoid:
		if is_instance_valid(a) and a.alive and area_contains_point(a, p, margin):
			return true
	return false


## Map hazard lookup (ArenaMap.is_hazard): the World itself, its parent, a sibling or a child that
## implements is_hazard(pos). Re-scanned every 2 s while none is found (maps may be added after the brain).
func _hazard_source(w: World) -> Node:
	if _hazard_map != null and is_instance_valid(_hazard_map) and _hazard_map.is_inside_tree():
		return _hazard_map
	_hazard_map = null
	if _clock < _hazard_scan_at:
		return null
	_hazard_scan_at = _clock + 2.0
	_hazard_map = find_hazard_map(w)
	return _hazard_map


static func find_hazard_map(w: World) -> Node:
	if w == null:
		return null
	if w.has_method("is_hazard"):
		return w
	var p := w.get_parent()
	if p != null:
		if p.has_method("is_hazard"):
			return p
		for c: Node in p.get_children():
			if c != w and c.has_method("is_hazard"):
				return c
	for c: Node in w.get_children():
		if c.has_method("is_hazard"):
			return c
	return null


func _hazard_at(p: Vector3) -> bool:
	if _hazard_map == null or not is_instance_valid(_hazard_map):
		return false
	return bool(_hazard_map.call("is_hazard", p))


## Raid boss mechanics published by the boss's brain (duck-typed, RAID's BossBrain):
##  - `shares`: [{pos, left, ab{radius, min}}] soak/stack circles: the party members nearest to the circle
##    (the tank last) step inside so at least `min` (+1 spare) share the hit.
##  - `channel`: non-empty while an interruptible channel runs (handled by _try_interrupt).
func _scan_boss_mechanics(w: World) -> void:
	_share_pos = Vector3.INF
	if _boss != null and not _usable(w, _boss):
		_boss = null
	if _boss == null:
		for e: Fighter in _enemies(w):
			if e.kind == "boss" and e.brain != null and is_instance_valid(e.brain):
				_boss = e
				break
	if _boss == null or _boss.brain == null or not is_instance_valid(_boss.brain):
		return
	var shares: Variant = _boss.brain.get("shares")
	if not (shares is Array) or (shares as Array).is_empty():
		return
	var party: Array[Fighter] = []
	for a: Fighter in w.allies_of(fighter, true):
		if a.kind != "summon" and a.is_alive():
			party.append(a)
	var best_left := INF
	for sv: Variant in shares:
		if not (sv is Dictionary):
			continue
		var sd: Dictionary = sv
		var pos: Variant = sd.get("pos")
		if not (pos is Vector3):
			continue
		var ab: Dictionary = sd.get("ab", {}) if sd.get("ab") is Dictionary else {}
		var need := int(ab.get("min", 2)) + 1
		var r := float(ab.get("radius", 3.5))
		var ppos: Vector3 = pos
		var ranked := party.duplicate()
		ranked.sort_custom(func(a: Fighter, b: Fighter) -> bool:
			var da := CoreUtil.flat(a.global_position - ppos).length() + (40.0 if _role_of(a) == "tank" else 0.0)
			var db := CoreUtil.flat(b.global_position - ppos).length() + (40.0 if _role_of(b) == "tank" else 0.0)
			return da < db)
		var idx := ranked.find(fighter)
		if idx < 0 or idx >= need:
			continue
		var left := float(sd.get("left", 3.0))
		if left < best_left:
			best_left = left
			_share_pos = ppos
			_share_r = r
			_share_left = left


func _find_safe_point(w: World) -> Vector3:
	var me := fighter.global_position
	var best := me
	var best_cost := INF
	var enemy_c := Vector3.ZERO
	var t := _target
	if t != null and is_instance_valid(t):
		enemy_c = t.global_position
	var margin := fighter.radius() + 0.5
	for i in 16:
		var ang := TAU * float(i) / 16.0
		var dir := CoreUtil.dir_of_yaw(ang)
		var dist := 0.75
		while dist <= 9.0:
			var p := me + dir * dist
			if _in_bounds(w, p, 1.0) and not _danger_at(p, margin):
				var cost := dist
				if t != null and is_instance_valid(t):
					var td := CoreUtil.flat(p - enemy_c).length()
					cost += absf(td - _pref_range) * 0.15
				if cost < best_cost:
					best_cost = cost
					best = p
				break
			dist += 0.75
	return best


func _in_bounds(w: World, p: Vector3, inset: float) -> bool:
	var lo := w.bounds.position
	var hi := w.bounds.end
	return p.x > lo.x + inset and p.x < hi.x - inset and p.z > lo.z + inset and p.z < hi.z - inset


func _scan_projectiles(w: World) -> void:
	if _sidestep_left > 0.0 or float(cfg["proj_dodge"]) <= 0.0:
		return
	var me := fighter.center()
	for e: Variant in w.effects:
		if not is_instance_valid(e) or not (e is Projectile):
			continue
		var pr := e as Projectile
		if not pr.alive or pr.team == fighter.team:
			continue
		var key := pr.get_instance_id()
		if _seen_events.has(key):
			continue
		var to := me - pr.global_position
		var dist := to.length()
		if dist > 14.0 or dist < 2.0:
			continue
		var v := pr.velocity
		if v.length() < 1.0 or v.normalized().dot(to.normalized()) < 0.93:
			continue
		_seen_events[key] = true
		if _rng.randf() < float(cfg["proj_dodge"]) and pr.homing < 1.0:
			var side := CoreUtil.flat(v).normalized().cross(Vector3.UP) * _strafe_sign
			_sidestep_dir = side
			_sidestep_left = clampf(dist / v.length(), 0.2, 0.45)
	if _seen_events.size() > 64:
		_seen_events.clear()


# ================================================================== decisions
func _decide(w: World) -> void:
	_plan_slot = -1
	_plan_ally = null
	_plan_escape = false
	_plan_healer_taunt_flag = false
	_hold_fire = false
	_want_fly = false
	_combo_ok = _rng.randf() < float(cfg["combo"])
	_skills_ok = _rng.randf() < float(cfg["skill_use"])
	match mode:
		"pet":
			_decide_pet(w)
		"mob":
			_decide_mob(w)
		"raid":
			_decide_raid(w)
		_:
			_decide_pvp(w)


# ---------------------------------------------------------------- pvp
func _decide_pvp(w: World) -> void:
	var enemies := _enemies(w)
	_target = _pick_target_pvp(w, enemies)
	# Healer duties come first (revive, heal, cleanse).
	if _support_duties(w, enemies):
		return
	if _target == null:
		_regroup(w)
		return
	var t := _target
	var hpf := _hp_frac(fighter)
	# Defensive / escape decisions.
	if _defensive_choice(w, enemies, hpf):
		return
	if _role == "tank" and _plan_healer_taunt(w, enemies):
		return
	var slot := _best_skill(w, t, false)
	_plan_slot = slot
	_set_combat_style(w, t, slot)


## An enemy (not a summon) whose lock-on / top threat is our healer and that is close to it.
func _healer_attacker(w: World, enemies: Array[Fighter]) -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for a: Fighter in w.allies_of(fighter, false):
		if a.kind == "summon" or not _is_heal_role(a):
			continue
		for e: Fighter in enemies:
			if e.kind == "summon" or _is_idle_mob(e):
				continue
			var on_it := e.target_uid == a.uid
			if not on_it and (e.kind == "mob" or e.kind == "boss"):
				on_it = e.top_threat() == a
			if not on_it or _flat_dist(e, a) > 9.0:
				continue
			var d := _flat_dist(fighter, e)
			if d < best_d:
				best_d = d
				best = e
	return best


## Tank: taunt an enemy that is hitting our healer (closing in first when the taunt does not reach yet).
func _plan_healer_taunt(w: World, enemies: Array[Fighter]) -> bool:
	if not _skills_ok:
		return false
	var e := _healer_attacker(w, enemies)
	if e == null or e.status.has(&"taunted") and e.status.source(&"taunted") == fighter:
		return false
	var slot := _find_ready(func(p: Dictionary) -> bool: return bool(p["taunt"]))
	if slot < 0:
		return false
	var p := profile(fighter.resolve_skill(slot))
	_target = e
	_plan_slot = slot
	_plan_healer_taunt_flag = true
	_style = "approach"
	_want_dist = maxf(1.0, float(p["taunt_radius"]) * 0.6)
	return true


func _pick_target_pvp(w: World, enemies: Array[Fighter]) -> Fighter:
	if enemies.is_empty():
		return null
	# Always refresh the shared focus first (the leader may itself be busy peeling or taunted).
	var focus := _team_focus(w, enemies)
	if fighter.status.has(&"taunted"):
		var src := fighter.status.source(&"taunted")
		if src != null and src.is_alive():
			return src
	# Tank: peel enemies diving our squishies (the healer first).
	if _role == "tank":
		var on_healer := _healer_attacker(w, enemies)
		if on_healer != null:
			return on_healer
		var peel := _peel_target(w, enemies)
		if peel != null:
			return peel
	# Control: interrupt casters within reach.
	if _role == "control" or _role == "support":
		for e: Fighter in enemies:
			if e.state == Fighter.State.CAST and e.runner != null and _flat_dist(fighter, e) < 12.0:
				var rem := (e.runner.duration - e.runner.elapsed) / maxf(0.25, e.runner.rate)
				if rem > 0.4 and e.runner.skill.total_time() >= 0.6:
					return e
	var nearest: Fighter = null
	var nd := INF
	for e: Fighter in enemies:
		var d := _flat_dist(fighter, e)
		if d < nd:
			nd = d
			nearest = e
	if focus == null:
		return nearest
	var fd := _flat_dist(fighter, focus)
	# Melee does not run across the map past someone hitting it.
	if not _ranged_style and fd > 12.0 and nd < 4.0:
		return nearest
	if _ranged_style and nd < 3.0 and fd > _pref_range * 1.6:
		return nearest
	return focus


func _peel_target(w: World, enemies: Array[Fighter]) -> Fighter:
	var best: Fighter = null
	var best_s := 0.0
	for a: Fighter in w.allies_of(fighter, false):
		if a.kind == "summon":
			continue
		var weight := 2.0 if _is_heal_role(a) else (1.0 + (1.0 - _hp_frac(a)))
		for e: Fighter in enemies:
			var d := _flat_dist(a, e)
			if d > 6.0:
				continue
			var s := weight * (7.0 - d)
			if e.target_uid == a.uid:
				s *= 1.6
			if s > best_s:
				best_s = s
				best = e
	return best


## Shared per-team focus target, chosen by the lowest-uid bot of the team (deterministic).
func _team_focus(w: World, enemies: Array[Fighter]) -> Fighter:
	var key := "ai_focus_%d" % fighter.team
	var rec: Dictionary = w.get_meta(key, {})
	var cur: Fighter = w.get_fighter(int(rec.get("uid", 0))) if not rec.is_empty() else null
	if cur != null and (not cur.is_alive() or cur.is_stealthed or cur.team == fighter.team):
		cur = null
	if _is_team_leader(w):
		# "next" lives in the writing brain's clock: re-evaluate whenever leadership changed hands
		# (a younger brain's clock would otherwise freeze the record) or the stamp is implausible.
		var nxt := float(rec.get("next", 0.0))
		var due := cur == null or _clock >= nxt or nxt - _clock > FOCUS_INTERVAL \
			or int(rec.get("by", 0)) != get_instance_id()
		if due:
			var centroid := _team_centroid(w)
			var best: Fighter = null
			var best_s := INF
			var cur_s := INF
			for e: Fighter in enemies:
				if e.kind == "summon":
					continue
				var s := _ehp(e) * (0.65 if _is_heal_role(e) else 1.0)
				s *= 1.0 + CoreUtil.flat(e.global_position - centroid).length() * 0.04
				if e.status.has(&"invuln"):
					s *= 1.5
				if e == cur:
					cur_s = s
				if s < best_s:
					best_s = s
					best = e
			if best == null:
				for e: Fighter in enemies:
					best = e
					break
			if cur != null and cur_s <= best_s * 1.25:
				best = cur
			cur = best
			w.set_meta(key, {"uid": cur.uid if cur != null else 0, "next": _clock + FOCUS_INTERVAL, "by": get_instance_id()})
	return cur


func _is_team_leader(w: World) -> bool:
	for f: Fighter in w.team_fighters(fighter.team, false):
		if f.uid < fighter.uid and f.is_alive() and f.brain != null and is_instance_valid(f.brain) \
				and f.brain is BotBrain and (f.brain as BotBrain).mode == mode:
			return false
	return true


func _team_centroid(w: World) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for f: Fighter in w.team_fighters(fighter.team, false):
		if f.is_alive():
			c += f.global_position
			n += 1
	return c / float(n) if n > 0 else fighter.global_position


func _regroup(w: World) -> void:
	var anchor := _team_centroid(w)
	_style = "point"
	_goal = anchor
	if CoreUtil.flat(anchor - fighter.global_position).length() < 3.0:
		_style = "hold"


## Heals, revives, cleanses, summons and self-buffs. Returns true when a support plan was chosen.
func _support_duties(w: World, enemies: Array[Fighter]) -> bool:
	if not _skills_ok and _role != "healer":
		return false
	var allies := w.allies_of(fighter, true, true)
	var heal_thresh := 0.72 if _role == "healer" else 0.4
	if _role == "healer" and _unavoid_left < 4.0:
		heal_thresh = 0.92            # top everyone up before an un-dodgeable raid-wide hit lands
	# Revive dead allies first whenever it is safe: we are not standing in / threatened by an AoE, not
	# being dived, not low ourselves, and no living ally is about to die (that one gets healed first).
	var critical := false
	for a: Fighter in allies:
		if a.is_alive() and a.kind != "summon" and _hp_frac(a) < 0.25 and _flat_dist(fighter, a) < 22.0:
			critical = true
	var safe := _threats.is_empty() and not _in_hazard and _unavoid_left > 2.0 and _hp_frac(fighter) > 0.35 \
		and _no_enemy_within(enemies, fighter.global_position, 4.0)
	for a: Fighter in allies:
		if a.is_alive() or a == fighter or a.kind == "summon" or not safe or critical:
			continue
		if not _usable(w, a, true):
			continue
		var slot := _find_ready(func(p: Dictionary) -> bool: return bool(p["revive"]))
		if slot >= 0 and _no_enemy_within(enemies, a.global_position, 4.0) and not _danger_at(a.global_position, 0.5):
			_plan_slot = slot
			_plan_ally = a
			_style = "point"
			_goal = a.global_position
			_want_dist = 3.0
			return true
	# Heal the lowest ally.
	var low: Fighter = null
	var low_v := heal_thresh
	for a: Fighter in allies:
		if not a.is_alive() or a.kind == "summon":
			continue
		if _flat_dist(fighter, a) > 22.0:
			continue
		var v := _hp_frac(a)
		if a.status.has(&"taunted") or a == fighter:
			v -= 0.02
		if v < low_v:
			low_v = v
			low = a
	if low != null:
		var slot := _best_heal_slot(low)
		if slot >= 0:
			_plan_slot = slot
			_plan_ally = low
			var p := profile(fighter.resolve_skill(slot))
			_style = "point"
			_goal = low.global_position
			_want_dist = maxf(1.5, float(p["heal_radius"]) * 0.6) if str(p["heal_mode"]) != "target_ally" else 14.0
			if low == fighter or str(p["heal_mode"]) == "self":
				_style = "band" if _target != null else "hold"
				_set_band()
			return true
	# Cleanse a disabled ally (self included).
	for a: Fighter in allies:
		if not a.is_alive() or a.kind == "summon":
			continue
		if a.status.is_disabled() or a.status.has(&"silence") or a.status.has(&"root"):
			var slot := _find_ready(func(p: Dictionary) -> bool: return bool(p["cleanse"]))
			if slot >= 0 and (a == fighter or _flat_dist(fighter, a) < 8.0):
				_plan_slot = slot
				_plan_ally = a
				_style = "hold"
				return true
	# Keep summons up.
	var sslot := _find_ready(func(p: Dictionary) -> bool:
		return str(p["summon"]) != "" and w.summons_of(fighter, str(p["summon"])).size() < int(p["summon_max"]))
	if sslot >= 0 and (_target != null or _role == "summoner"):
		if _target != null and _flat_dist(fighter, _target) < 25.0:
			_plan_slot = sslot
			_set_combat_style(w, _target, sslot)
			return true
	# Ally buffs when a fight is on.
	if _target != null and _flat_dist(fighter, _target) < 14.0:
		var bslot := _find_ready(func(p: Dictionary) -> bool:
			return bool(p["buff_ally"]) and float(p["dmg"]) <= 0.0 and float(p["heal"]) <= 0.0)
		if bslot >= 0 and _rng.randf() < 0.5:
			_plan_slot = bslot
			_set_combat_style(w, _target, bslot)
			return true
	return false


func _no_enemy_within(enemies: Array[Fighter], p: Vector3, r: float) -> bool:
	for e: Fighter in enemies:
		if CoreUtil.flat(e.global_position - p).length() < r:
			return false
	return true


func _find_ready(pred: Callable) -> int:
	for s: SkillDef in fighter.skills:
		var reason := fighter.cast_block_reason(s.slot)
		if reason != "" and reason != "busy":
			continue
		if pred.call(profile(fighter.resolve_skill(s.slot))) and _escape_ok(fighter.world(), s.slot):
			return s.slot
	return -1


func _best_heal_slot(ally: Fighter) -> int:
	var best := -1
	var best_s := 0.0
	var missing := 1.0 - _hp_frac(ally)
	for s: SkillDef in fighter.skills:
		var reason := fighter.cast_block_reason(s.slot)
		if reason != "" and reason != "busy":
			continue
		var p := profile(fighter.resolve_skill(s.slot))
		var h := float(p["heal"])
		if h <= 0.0:
			continue
		# Revive-capable skills are saved for revives unless the ally is about to die.
		if bool(p["revive"]) and _hp_frac(ally) > 0.2:
			continue
		var mode_h := str(p["heal_mode"])
		if mode_h == "self" and ally != fighter:
			continue
		if mode_h == "zone_self" and ally != fighter and _flat_dist(fighter, ally) > float(p["heal_radius"]) + 4.0:
			continue
		var sc := minf(h, missing + 0.1) * 10.0
		if bool(p["ult"]):
			sc *= 0.5 if missing < 0.6 else 1.3
		sc -= float(p["mp"]) / 400.0
		if sc > best_s:
			best_s = sc
			best = s.slot
	return best


func _defensive_choice(w: World, enemies: Array[Fighter], hpf: float) -> bool:
	if not _skills_ok:
		return false
	var close := 0
	var nearest := INF
	for e: Fighter in enemies:
		var d := _flat_dist(fighter, e)
		nearest = minf(nearest, d)
		if d < 4.5:
			close += 1
	var under_threat := (not _threats.is_empty() and _dodge_urgency < 0.6) or _unavoid_left < 0.8
	# Defensive self-buffs (super armor, shields, block) when low, swarmed or about to be blown up.
	if hpf < 0.4 or close >= 2 or under_threat:
		var slot := _find_ready(func(p: Dictionary) -> bool:
			return bool(p["defensive"]) and float(p["heal"]) <= 0.0 and str(p["move"]) == "" \
				and float(p["dmg"]) <= 0.5 and not bool(p["ult"]) and str(p["summon"]) == "" and not bool(p["parry"]))
		if slot >= 0:
			_plan_slot = slot
			_set_combat_style(w, _target, slot)
			return true
	# Escapes: squishies peel off divers, everyone escapes when low and pressed.
	var squishy := _ranged_style or _role == "healer"
	if (squishy and nearest < 3.2) or (hpf < 0.25 and nearest < 3.0 and _has_healer_ally(w)):
		var slot := _find_ready(func(p: Dictionary) -> bool:
			if bool(p["stealth"]):
				return true
			return (str(p["move"]) == "away" or bool(p["move_aim"])) and float(p["move_dist"]) >= 3.0)
		if slot >= 0 and _rng.randf() < 0.7:
			_plan_slot = slot
			_plan_escape = true
			_style = "band"
			_set_band()
			return true
	# Broom flight (Witch): take off and glide away from melee pressure when low or swarmed.
	if _can_fly and nearest < 3.5 and (hpf < 0.45 or close >= 2) and not _is_flying() and _clock >= _fly_next_ok:
		_want_fly = true
		_style = "point"
		_goal = _escape_point(w)
		_plan_slot = -1
		return true
	# Retreat toward the healer when low (team fights only).
	if hpf < 0.25 and _has_healer_ally(w) and nearest < 6.0 and _role != "healer":
		var healer := _healer_ally(w)
		if healer != null and _flat_dist(fighter, healer) > 4.0:
			_style = "point"
			_goal = healer.global_position
			_plan_slot = _best_skill(w, _target, true)
			return true
	return false


func _is_flying() -> bool:
	return _can_fly and fighter.kit != null and bool(fighter.kit.call("is_flying", fighter))


## Broom flight driver: jump, then a second jump press in mid-air mounts the broom (kit passive reads
## input.jump in on_tick); while flying, flap to hold a little altitude. Used to escape melee pressure and
## to cross map hazards (lava) that block the straight path.
func _tick_flight(w: World) -> void:
	if not _can_fly:
		return
	var inp := fighter.input
	var flying := _is_flying()
	match _fly_phase:
		0:
			if flying:
				_fly_phase = 2
				_fly_t = _clock
				return
			var want := _want_fly or (_hazard_blocked and _move.length() > 0.3)
			if want and _clock >= _fly_next_ok and fighter.is_on_floor() and fighter.can_act() \
					and fighter.state != Fighter.State.CAST and not fighter.status.has(&"root"):
				inp.jump = true
				_fly_phase = 1
				_fly_t = _clock
		1:
			if flying:
				_fly_phase = 2
				_fly_t = _clock
				flights_started += 1
			elif _clock - _fly_t > 0.9 or (fighter.is_on_floor() and _clock - _fly_t > 0.3) or not fighter.can_act():
				_fly_phase = 0
				_fly_next_ok = _clock + 1.0
			elif not fighter.is_on_floor() and _clock - _fly_t >= 0.15:
				inp.jump = true
		2:
			if not flying:
				_fly_phase = 0
				_fly_next_ok = _clock + 1.5
				return
			var alt := fighter.global_position.y - w.ground_y(fighter.global_position)
			if alt < 1.8 and fighter.velocity.y <= 0.5 and _clock - _fly_t > 0.35:
				inp.jump = true
				_fly_t = _clock


func _has_healer_ally(w: World) -> bool:
	return _healer_ally(w) != null


func _healer_ally(w: World) -> Fighter:
	for a: Fighter in w.allies_of(fighter, false):
		if _is_heal_role(a):
			return a
	return null


func _set_band() -> void:
	_band_lo = maxf(3.0, _pref_range * 0.65)
	_band_hi = maxf(_band_lo + 2.0, _pref_range * 1.1)


func _set_combat_style(w: World, t: Fighter, slot: int) -> void:
	if t == null:
		_style = "hold"
		return
	var p := profile(fighter.resolve_skill(slot)) if slot >= 0 else _empty_profile()
	if slot >= 0 and float(p["dmg"]) <= 0.0 and not bool(p["cc"]) and not bool(p["taunt"]) and str(p["move"]) != "toward":
		# Summons / buffs are cast from anywhere: keep the basic-attack spacing.
		slot = 0
		p = profile(fighter.resolve_skill(0))
	var reach := float(p["reach"])
	if _role == "tank" and mode == "pvp":
		# Hold the front: stand between the focus and our backline.
		_style = "approach"
		_want_dist = maxf(0.8, minf(reach, 2.5) * 0.7)
		return
	if _ranged_style:
		_style = "band"
		_set_band()
		if slot >= 0 and float(p["dmg"]) > 0.0 and reach > 0.0:
			if (bool(p["melee"]) and not bool(p["ranged"])) or bool(p["self_aoe"]):
				_style = "approach"
				_want_dist = maxf(0.6, reach * 0.7)
			else:
				_band_hi = minf(_band_hi, reach * 0.95)
				_band_lo = minf(_band_lo, _band_hi - 1.5)
		if _style == "band" and not _line_of_sight(w, t):
			# Never shoot into walls: move to the nearest spot in the band that sees the target.
			var lp := _find_los_point(w, t, clampf((_band_lo + _band_hi) * 0.5, 3.0, 14.0))
			if lp != Vector3.INF:
				_style = "point"
				_goal = lp
			else:
				_style = "approach"
				_want_dist = 2.5
		return
	_style = "approach"
	if slot >= 0 and str(p["move"]) == "toward" and float(p["dmg"]) <= 0.0:
		_want_dist = maxf(2.0, float(p["move_dist"]) * 0.8)
	elif slot >= 0 and reach > 0.0:
		_want_dist = maxf(0.6, reach * 0.72)
	else:
		_want_dist = 1.6
	if _is_downed(t) and slot >= 0 and bool(p["otg"]):
		_want_dist = maxf(0.6, reach * 0.6)     # OTG punish: step right onto the downed target
	elif _untouchable(t) or _is_downed(t):
		# Don't waste the combo on a getting-up target: hover just outside its reach.
		_want_dist = maxf(_want_dist, 2.6)
	if _want_dist > 3.0 and not _line_of_sight(w, t):
		_want_dist = 2.0


## Picks the best skill against `t`. When now_only, only skills castable right now and in range.
func _best_skill(w: World, t: Fighter, now_only: bool) -> int:
	if t == null:
		return -1
	var best := -1
	var best_s := 0.0
	var dist := _surf(t)
	var enemies_near_t := 0
	var enemies_near_me := 0
	for e: Fighter in _enemies(w):
		if CoreUtil.flat(e.global_position - t.global_position).length() < 4.0:
			enemies_near_t += 1
		if _flat_dist(fighter, e) < 4.5:
			enemies_near_me += 1
	for s: SkillDef in fighter.skills:
		var slot := s.slot
		var reason := fighter.cast_block_reason(slot)
		if now_only:
			if reason != "":
				continue
		elif reason != "" and reason != "busy":
			continue
		if slot != 0 and not _skills_ok and not now_only:
			continue
		var rs := fighter.resolve_skill(slot)
		var p := profile(rs)
		var in_range := _in_range(w, p, t, dist)
		if now_only and not in_range:
			continue
		var sc := _score(p, slot, t, dist, in_range, enemies_near_t, enemies_near_me)
		if sc <= 0.0:
			continue
		sc *= _rng.randf_range(0.88, 1.12)
		if sc > best_s:
			best_s = sc
			best = slot
	return best


func _in_range(w: World, p: Dictionary, t: Fighter, dist: float) -> bool:
	var reach := float(p["reach"])
	var mv := str(p["move"])
	if float(p["dmg"]) <= 0.0 and not bool(p["cc"]) and not bool(p["taunt"]):
		if mv == "toward":
			return dist >= 2.0 and dist <= float(p["move_dist"]) + 2.0
		return true
	if mv == "toward" and float(p["move_dist"]) > reach:
		return dist <= float(p["move_dist"]) + 1.5
	if bool(p["grab"]):
		return dist <= reach and absf(t.global_position.y - fighter.global_position.y) < 1.0
	if bool(p["ranged"]) and not bool(p["self_aoe"]):
		return dist <= reach and (reach < 4.0 or _line_of_sight(w, t))
	return dist <= reach * 0.95


func _score(p: Dictionary, slot: int, t: Fighter, dist: float, in_range: bool, near_t: int, near_me: int) -> float:
	var dmg := float(p["dmg"])
	var sc := 0.0
	var launched := _is_launched(t)
	var downed := _is_downed(t)
	var untouchable := _untouchable(t)
	var armored := t.status.has(&"super_armor")
	var blocking := t.status.has(&"block")
	var mv := str(p["move"])
	var hpf := _hp_frac(fighter)
	if bool(p["parry"]):
		return 0.0                     # cast reactively by _try_parry only
	# Pure utility skills.
	if dmg <= 0.0:
		if bool(p["taunt"]):
			if _role == "tank" or mode == "raid":
				return 3.0 if dist <= float(p["taunt_radius"]) * 0.9 and not t.status.has(&"taunted") else 0.0
			return 0.0
		if bool(p["cc"]):
			if untouchable or armored or t.status.is_disabled():
				return 0.0
			sc = 1.6 if _role in ["control", "support"] else 1.0
			if t.state == Fighter.State.CAST:
				sc *= 2.0
			return sc if in_range else sc * 0.6
		if bool(p["debuff"]):
			return 0.7 if not untouchable else 0.0
		if mv == "toward":
			if _ranged_style:
				return 0.0
			return 2.2 if dist > 4.0 and dist <= float(p["move_dist"]) + 2.0 else 0.0
		if bool(p["buff_self"]):
			return 1.2 if dist < maxf(5.0, _pref_range * 1.3) else 0.0
		return 0.0
	if untouchable:
		return 0.0
	sc = dmg
	if slot == 0:
		sc = minf(dmg, 1.2) * 0.55 + 0.3
	# Big cooldown skills are worth more than their raw multiplier suggests (opportunity).
	sc *= 1.0 + clampf(float(p["cd"]) / 30.0, 0.0, 0.5)
	if bool(p["ult"]):
		var ok := _hp_frac(t) < float(cfg["ult_hp"]) or near_t >= 2 or launched
		if not ok:
			return 0.0
		sc *= 1.6
	if downed:
		sc *= 1.5 if bool(p["otg"]) else (0.6 if slot == 0 else 0.15)
	elif launched:
		if bool(p["grab"]):
			return 0.0
		if t.juggle_points > 85.0:
			sc *= 2.0 if bool(p["finisher"]) else 0.7
		elif bool(p["combo"]) or slot == 0:
			sc *= 1.7
		elif bool(p["launcher"]):
			sc *= 1.3
		if bool(p["ranged"]):
			sc *= 1.4
	else:
		if bool(p["launcher"]) and not armored:
			sc *= 1.9 if not _ranged_style else 1.3
		if bool(p["grab"]):
			sc *= 2.6 if (armored or blocking) else 1.0
		elif armored and not bool(p["armor_break"]):
			sc *= 0.6
		if blocking and not bool(p["armor_break"]) and not bool(p["grab"]) and not bool(p["ranged"]):
			sc *= 0.4
		if bool(p["cc"]) and t.state == Fighter.State.CAST:
			sc *= 1.8
		if bool(p["disable"]) and _role in ["control", "support"]:
			sc *= 1.4
	if bool(p["aoe"]) and near_t >= 2:
		sc *= 1.3
	if bool(p["self_aoe"]) and near_me >= 2:
		sc *= 1.25
	if bool(p["defensive"]) and (hpf < 0.5 or near_me >= 2):
		sc *= 1.3
	if mv == "toward":
		if dist > 4.0 and not _ranged_style:
			sc *= 2.0
		elif _ranged_style and dist < 6.0:
			sc *= 0.3
	if mv == "away" and not _ranged_style and dist > 2.5:
		sc *= 0.4
	if float(p["delay"]) > 0.0 and not (downed or launched or t.status.is_disabled()):
		sc *= 0.75 if difficulty >= 2 else 0.9
	if not in_range:
		var mvd := float(p["move_dist"]) if mv == "toward" else 0.0
		var gap := dist - maxf(float(p["reach"]), mvd)
		sc *= clampf(1.0 - gap / 12.0, 0.15, 0.85)
		if _ranged_style and bool(p["melee"]) and not bool(p["ranged"]):
			sc *= 0.4
	# Healers keep mana for heals.
	if _role == "healer" and fighter.mp - float(p["mp"]) < fighter.max_mp * 0.35:
		sc *= 0.3
	if fighter.mp - float(p["mp"]) < fighter.max_mp * 0.1 and slot != 0:
		sc *= 0.6
	return sc


# ---------------------------------------------------------------- raid (party member)
func _decide_raid(w: World) -> void:
	var enemies := _enemies(w)
	var party := w.allies_of(fighter, true)
	var human: Fighter = null
	var tank: Fighter = null
	for a: Fighter in party:
		if a.kind == "player" and human == null:
			human = a
		if _role_of(a) == "tank" and (tank == null or a.uid < tank.uid):
			tank = a
	var engaged: Array[Fighter] = []
	var boss: Fighter = null
	for e: Fighter in enemies:
		if _is_engaged_with_party(w, e):
			engaged.append(e)
			if e.kind == "boss":
				boss = e
	var leader := human if human != null else (tank if tank != null else _lowest_uid_bot(party))
	var i_lead := leader == fighter
	var has_goal := fighter.has_meta("raid_goal")
	# Leaders of a bot-only party pull the nearest active (brained) enemy, one pack at a time. Under
	# MatchRaid (raid_goal published) walking to the goal pulls the encounter instead, and idle mobs
	# (no brain, empty threat table) are never attacked.
	if engaged.is_empty() and i_lead and human == null and not has_goal:
		var n: Fighter = null
		var nd := RAID_ENGAGE_RANGE
		for e: Fighter in enemies:
			if _is_idle_mob(e):
				continue
			var d := _flat_dist(fighter, e)
			if d < nd:
				nd = d
				n = e
		if n != null:
			engaged.append(n)
	# Assist a human's explicit target (once it is pulled).
	if human != null and human != fighter:
		var ht := human.get_target()
		if ht != null and fighter.is_enemy(ht) and not engaged.has(ht) and not _is_idle_mob(ht):
			engaged.append(ht)
	var t: Fighter = null
	if fighter.status.has(&"taunted"):
		t = fighter.status.source(&"taunted")
	if t == null:
		if boss != null:
			t = boss
		elif tank != null and tank != fighter and tank.get_target() != null and engaged.has(tank.get_target()):
			t = tank.get_target()
		else:
			var best_v := INF
			for e: Fighter in engaged:
				var v := e.hp + _flat_dist(fighter, e) * 60.0
				if _role == "tank":
					# Tanks grab mobs that are hitting someone else first.
					var top := e.top_threat()
					if top != null and top != fighter:
						v -= 100000.0
				if v < best_v:
					best_v = v
					t = e
	if _role == "tank" and not fighter.status.has(&"taunted"):
		var on_healer := _healer_attacker(w, engaged)
		if on_healer != null:
			t = on_healer
	_target = t
	if _support_duties(w, enemies):
		return
	if _role == "tank" and t != null and _plan_healer_taunt(w, engaged):
		return
	if t == null:
		# Follow a human leader; otherwise walk to MatchRaid's raid_goal (formation slot at the next
		# encounter); otherwise follow the party anchor. Never wander into packs.
		var anchor := leader if leader != null and leader != fighter else null
		if (human == null or human == fighter or not human.is_alive()) and has_goal:
			var goal: Variant = fighter.get_meta("raid_goal")
			if goal is Vector3:
				_goal = goal
				_style = "point" if CoreUtil.flat(_goal - fighter.global_position).length() > 1.5 else "hold"
				return
		if anchor != null:
			var idx := party.find(fighter)
			var off := CoreUtil.dir_of_yaw(anchor.facing_yaw + PI + (float(idx) - 2.0) * 0.6) * 3.5
			_goal = anchor.global_position + off
			_style = "point" if CoreUtil.flat(_goal - fighter.global_position).length() > 1.5 else "hold"
		else:
			_style = "hold"
		return
	if _defensive_choice(w, enemies, _hp_frac(fighter)):
		return
	_plan_slot = _best_skill(w, t, false)
	if t == _boss and _boss_channeling(w):
		# Interrupt duty: bring a crowd-control skill to the channelling boss.
		var cs := _find_ready(func(p: Dictionary) -> bool: return is_cc_profile(p))
		if cs >= 0:
			_plan_slot = cs
	elif t.kind == "boss" and _role != "tank" and tank != null and tank != fighter and tank.is_alive():
		# Threat discipline: never out-threat the tank on a boss (and wait for the tank to open).
		var tt := float(t.threat.get(tank.uid, 0.0))
		var mt := float(t.threat.get(fighter.uid, 0.0))
		if (tt <= 0.0 and _flat_dist(tank, t) > 4.0) or (mt > 0.0 and mt >= tt * 0.85):
			_hold_fire = true
			if _plan_slot >= 0 and float(profile(fighter.resolve_skill(_plan_slot))["heal"]) <= 0.0:
				_plan_slot = -1
	if _role == "tank" and t.get_target() == fighter and _hp_frac(fighter) < 0.85 and _skills_ok:
		# Tanking: spend defensive cooldowns proactively while the enemy is on us.
		var ds := _find_ready(func(p: Dictionary) -> bool:
			return bool(p["defensive"]) and float(p["heal"]) <= 0.0 and str(p["move"]) == "" \
				and not bool(p["ult"]) and str(p["summon"]) == "" and not bool(p["parry"]))
		if ds >= 0:
			_plan_slot = ds
	if _role == "healer" and _plan_slot >= 0:
		var hp_ := profile(fighter.resolve_skill(_plan_slot))
		if bool(hp_["melee"]) and not bool(hp_["ranged"]):
			_plan_slot = -1             # healers do not walk into the boss to melee it
	# Raid positioning around the target.
	var centroid := Vector3.ZERO
	var n_c := 0
	for a: Fighter in party:
		if a != fighter and a != tank and a.is_alive():
			centroid += a.global_position
			n_c += 1
	centroid = centroid / float(n_c) if n_c > 0 else fighter.global_position
	var away := CoreUtil.flat_dir(t.global_position - centroid, -t.forward())
	var p := profile(fighter.resolve_skill(_plan_slot)) if _plan_slot >= 0 else _empty_profile()
	var reach := float(p["reach"]) if _plan_slot >= 0 else (_pref_range if _ranged_style else 2.0)
	var tr := t.radius()
	if _role == "tank":
		_style = "point"
		_goal = t.global_position + away * (tr + maxf(0.8, minf(reach, 2.5) * 0.7))
		if t.top_threat() != fighter and t.top_threat() != null:
			_style = "approach"
			_want_dist = maxf(0.8, minf(reach, 2.5) * 0.7)
		return
	var behind := t.global_position - t.forward() * 1.0
	var side := t.forward().cross(Vector3.UP) * (float(fighter.uid % 3) - 1.0)
	if _ranged_style:
		var r := clampf(minf(reach, _pref_range), 4.0, 14.0)
		if _role == "healer" or _hold_fire:
			r = clampf(maxf(r, 8.0), 8.0, 14.0)   # out of cleaves / stomps, still in heal range
		var dir := CoreUtil.flat_dir(-t.forward() + side * 0.6 - away * 0.3, -away)
		_goal = t.global_position + dir * (tr + r)
		_style = "point"
		if not _los_from(w, Vector3(_goal.x, fighter.global_position.y, _goal.z), t):
			var lp := _find_los_point(w, t, r)
			if lp != Vector3.INF:
				_goal = lp
	else:
		var r := maxf(0.6, minf(reach, 2.5) * 0.7)
		_goal = behind + CoreUtil.flat_dir(-t.forward() + side * 0.4) * (tr + r - 1.0)
		_style = "point"
	if _danger_at(_goal, fighter.radius() + 0.3):
		_style = "approach" if not _ranged_style else "band"
		_want_dist = maxf(0.8, reach * 0.7)
		_set_band()


## A dungeon mob that has not been pulled yet: no brain and an empty threat table (MatchRaid spawns
## encounters idle and attaches brains on the pull). Attacking it would pull the pack early.
func _is_idle_mob(e: Fighter) -> bool:
	if e == null or (e.kind != "mob" and e.kind != "boss"):
		return false
	return (e.brain == null or not is_instance_valid(e.brain)) and e.threat.is_empty()


func _is_engaged_with_party(w: World, e: Fighter) -> bool:
	if _is_idle_mob(e):
		return false
	if e.target_uid != 0:
		var tf := w.get_fighter(e.target_uid)
		if tf != null and tf.team == fighter.team:
			return true
	for k: Variant in e.threat:
		var f := w.get_fighter(int(k))
		if f != null and f.team == fighter.team and f.is_alive():
			return true
	return false


func _lowest_uid_bot(party: Array[Fighter]) -> Fighter:
	var best: Fighter = null
	for a: Fighter in party:
		if a.kind == "summon":
			continue
		if best == null or a.uid < best.uid:
			best = a
	return best


# ---------------------------------------------------------------- pet
func _decide_pet(w: World) -> void:
	var owner_f := fighter.get_owner_fighter()
	var anchor := owner_f.global_position if owner_f != null else fighter.global_position
	var t: Fighter = null
	if fighter.status.has(&"taunted"):
		t = fighter.status.source(&"taunted")
	if t == null and owner_f != null:
		var ot := owner_f.get_target()
		if ot != null and fighter.is_enemy(ot) and (not _is_idle_mob(ot) or owner_f.kind == "player") and CoreUtil.flat(ot.global_position - anchor).length() <= PET_LEASH + 4.0:
			t = ot
	if t == null:
		var best_d := PET_LEASH
		for e: Fighter in _enemies(w):
			if _is_idle_mob(e):
				continue
			var d := CoreUtil.flat(e.global_position - anchor).length()
			if d < best_d:
				best_d = d
				t = e
	# Leash: never get dragged away from the owner.
	if t != null and owner_f != null and _flat_dist(fighter, owner_f) > PET_LEASH + 3.0:
		t = null
	_target = t
	if t == null:
		var to := CoreUtil.flat(anchor - fighter.global_position)
		if owner_f != null and to.length() > PET_FOLLOW_DIST:
			_style = "point"
			var side := owner_f.right() * (1.2 if fighter.uid % 2 == 0 else -1.2)
			_goal = anchor - owner_f.forward() * 1.5 + side
		else:
			_style = "hold"
		return
	_plan_slot = _best_skill(w, t, false)
	_set_combat_style(w, t, _plan_slot)


# ---------------------------------------------------------------- mob
func _decide_mob(w: World) -> void:
	var home_d := CoreUtil.flat(fighter.global_position - _home).length()
	if _returning:
		_target = null
		_style = "point"
		_goal = _home
		if home_d < 1.2:
			_returning = false
			fighter.threat.clear()
			fighter.heal(fighter.max_hp, null)
			_style = "hold"
		return
	var t := fighter.top_threat()
	if fighter.status.has(&"taunted"):
		var src := fighter.status.source(&"taunted")
		if src != null and src.is_alive():
			t = src
	if t != null and not _usable(w, t):
		t = null
	if t == null:
		# Proximity aggro and social aggro (pack members assist each other).
		var n := w.nearest_enemy(fighter, MOB_AGGRO)
		if n != null and _line_of_sight(w, n):
			fighter.add_threat(n, 1.0)
			t = n
		else:
			for a: Fighter in w.allies_of(fighter, false):
				if a.kind != "mob" and a.kind != "boss":
					continue
				if _flat_dist(fighter, a) > MOB_SOCIAL:
					continue
				var at := a.top_threat()
				if at != null:
					fighter.add_threat(at, 1.0)
					t = at
					break
	if t != null and (home_d > MOB_LEASH or CoreUtil.flat(t.global_position - _home).length() > MOB_LEASH + 6.0):
		_returning = true
		_target = null
		_style = "point"
		_goal = _home
		return
	_target = t
	if t == null:
		if home_d > 1.5:
			_style = "point"
			_goal = _home
			if home_d > 3.0 and fighter.hp < fighter.max_hp:
				_returning = true
		else:
			_style = "hold"
		return
	# Healer / summoner / shield mobs use their support and defensive kit (role from mob_def).
	var enemies := _enemies(w)
	if _support_duties(w, enemies):
		return
	var hpf := _hp_frac(fighter)
	if _role == "tank" and _flat_dist(fighter, t) < 4.5:
		hpf = minf(hpf, 0.39)   # guards raise shields when engaged in melee
	if _defensive_choice(w, enemies, hpf):
		return
	_plan_slot = _best_skill(w, t, false)
	_set_combat_style(w, t, _plan_slot)


# ================================================================== acting
## A cached fighter reference that is still safe to query (valid, in tree, registered, alive).
## Raid resets remove living mobs from the tree in the same frame the brains run.
func _usable(w: World, f: Fighter, allow_dead: bool = false) -> bool:
	if f == null or not is_instance_valid(f) or f.is_queued_for_deletion() or not f.is_inside_tree():
		return false
	if w != null and w.get_fighter(f.uid) != f:
		return false
	return allow_dead or f.is_alive()


func _act(w: World, dt: float) -> void:
	var inp := fighter.input
	var t := _target
	if t != null and (not _usable(w, t) or (t.is_stealthed and t.team != fighter.team)):
		t = null
		_target = null
	inp.target_uid = t.uid if t != null else 0
	inp.aim_point = t.center() if t != null else Vector3.ZERO
	if _plan_ally != null and not _usable(w, _plan_ally, true):
		_plan_ally = null
	if difficulty >= 1 and t != null:
		_scan_projectiles(w)
	# ------------------------------------------------ movement
	var desired := _desired_move(w, t)
	var steered := _steer(w, desired)
	_move = _move.lerp(steered, clampf(dt * 10.0, 0.0, 1.0))
	if _move.length() > 1.0:
		_move = _move.normalized()
	if steered == Vector3.ZERO and _move.length() < 0.2:
		_move = Vector3.ZERO
	inp.move = _move
	_tick_flight(w)
	if not fighter.can_act() and fighter.state != Fighter.State.CAST:
		return
	# ------------------------------------------------ skills
	if _dodging and _dodge_urgency < 0.45:
		_try_escape_to(_dodge_point)
		return
	if _share_pos != Vector3.INF and CoreUtil.flat(_share_pos - fighter.global_position).length() > _share_r * 0.6:
		return                         # walking into a soak circle: do not lock ourselves in a cast
	if _try_interrupt(w):
		return
	if _try_parry(w):
		return
	if _parry_wait and difficulty >= 1:
		return                         # keep the parry stance free for the incoming swing
	if _plan_slot >= 0:
		var rs := fighter.resolve_skill(_plan_slot)
		var p := profile(rs)
		if fighter.can_cast(_plan_slot) and _plan_ready(w, p, t) and _escape_ok(w, _plan_slot):
			_press(w, _plan_slot, p, t)
			if _plan_healer_taunt_flag and bool(p["taunt"]):
				healer_taunts += 1
				_plan_healer_taunt_flag = false
			if _plan_slot != 0:
				_plan_slot = -1
			return
	if _hold_fire:
		return
	# OTG: a downed target is punished with an off-the-ground skill (Sharpshooter Punisher) before it gets up.
	if t != null and _is_downed(t) and mode != "mob" and fighter.is_enemy(t):
		var so := _otg_slot_now(w, t)
		if so >= 0:
			_press(w, so, profile(fighter.resolve_skill(so)), t)
			return
	# Combo flow: chain follow-ups inside cancel windows / while the target is helpless.
	if _combo_ok and t != null and mode != "mob":
		var helpless := _is_launched(t) or t.state == Fighter.State.HITSTUN or t.state == Fighter.State.STUNNED \
			or t.state == Fighter.State.GRABBED
		if fighter.state == Fighter.State.CAST or helpless:
			var s2 := _best_skill(w, t, true)
			if s2 >= 0:
				_press(w, s2, profile(fighter.resolve_skill(s2)), t)
				return
	# Filler: basic attack when in range and nothing else planned.
	if t != null and fighter.is_enemy(t) and _plan_slot < 0 and not _untouchable(t):
		var p0 := profile(fighter.resolve_skill(0))
		if fighter.can_cast(0) and _in_range(w, p0, t, _surf(t)) and (not _is_downed(t) or _rng.randf() < 0.3):
			_press(w, 0, p0, t)


static func is_cc_profile(p: Dictionary) -> bool:
	return float(p["dmg"]) > 0.0 and (bool(p["cc"]) or bool(p["launcher"]) or bool(p["knockdown"]) \
		or bool(p["grab"]) or bool(p["pull"]) or bool(p["disable"]))


func _boss_channeling(w: World) -> bool:
	if _boss == null or not _usable(w, _boss) or _boss.brain == null or not is_instance_valid(_boss.brain):
		return false
	var ch: Variant = _boss.brain.get("channel")
	return ch is Dictionary and not (ch as Dictionary).is_empty()


## Raid: a boss channel (BossBrain.channel) is interrupted by a crowd-control skill that hits the boss.
func _try_interrupt(w: World) -> bool:
	if mode != "raid" or not _boss_channeling(w):
		return false
	var dist := _surf(_boss)
	for s: SkillDef in fighter.skills:
		if not fighter.can_cast(s.slot):
			continue
		var p := profile(fighter.resolve_skill(s.slot))
		if not is_cc_profile(p) or not _in_range(w, p, _boss, dist):
			continue
		var inp := fighter.input
		inp.target_uid = _boss.uid
		inp.aim_point = _boss.center()
		inp.press(s.slot)
		interrupts_attempted += 1
		return true
	return false


## An OTG-capable damaging skill castable right now that reaches the downed target, or -1.
func _otg_slot_now(w: World, t: Fighter) -> int:
	var dist := _surf(t)
	for s: SkillDef in fighter.skills:
		if not fighter.can_cast(s.slot):
			continue
		var p := profile(fighter.resolve_skill(s.slot))
		if bool(p["otg"]) and float(p["dmg"]) > 0.0 and not bool(p["ult"]) and _in_range(w, p, t, dist):
			return s.slot
	return -1


## Escape skills that need a setup: Summoner Switch (custom step swapping with the farthest summon) is only
## worth it with a living summon far from us and away from the enemies. Everything else is always ok.
func _escape_ok(w: World, slot: int) -> bool:
	var s := fighter.resolve_skill(slot)
	if s == null:
		return false
	var swaps := false
	for st: Dictionary in s.steps:
		if str(st.get("type", "")) == "custom" and str(st.get("method", "")).contains("switch"):
			swaps = true
	if not swaps:
		return true
	var enemies := _enemies(w)
	for su: Fighter in w.summons_of(fighter):
		if not su.is_alive() or _flat_dist(fighter, su) < 5.0:
			continue
		if _no_enemy_within(enemies, su.global_position, 4.0):
			return true
	return false


## Seconds (real time) until the next damaging melee/grab step of an enemy cast lands, or -1 when none is left.
static func time_to_strike(e: Fighter) -> float:
	if e == null or e.runner == null or e.runner.skill == null:
		return -1.0
	var r := e.runner
	var best := INF
	for st: Dictionary in r.skill.steps:
		var typ := str(st.get("type", ""))
		if not (typ in ["melee", "multi_melee", "grab"] or (typ == "dash" and st.has("hit"))):
			continue
		var t0 := float(st.get("t", 0.0))
		var t1 := t0
		if typ == "multi_melee":
			t1 = t0 + float(st.get("interval", 0.12)) * float(maxi(0, int(st.get("count", 3)) - 1))
		if r.elapsed > t1 + 0.001:
			continue
		best = minf(best, maxf(0.0, t0 - r.elapsed) / maxf(0.25, r.rate))
	return best if best < INF else -1.0


## Parry / counter stances (defensive + interrupt): timed against an enemy melee wind-up aimed at us -- the
## enemy is casting a melee skill, we are inside its reach, and its strike lands within the stance window.
## Perception is delayed by the difficulty's reaction time and the success chance is difficulty gated.
func _try_parry(w: World) -> bool:
	_parry_wait = false
	if not fighter.can_act() and fighter.state != Fighter.State.CAST:
		return false
	var slot := -1
	for s: SkillDef in fighter.skills:
		if bool(profile(fighter.resolve_skill(s.slot))["parry"]) and fighter.get_cooldown(s.slot) <= 0.0 				and fighter.mp >= fighter.resolve_skill(s.slot).mp_cost:
			slot = s.slot
			break
	if slot < 0:
		return false
	var react := float(cfg["react"]) * 0.6
	for e: Fighter in _enemies(w):
		if e.state != Fighter.State.CAST or e.runner == null or e.runner.skill == null:
			continue
		if e.get_target() != fighter and _flat_dist(fighter, e) > 3.0:
			continue
		var ep := profile(e.runner.skill)
		if not bool(ep["melee"]) or bool(ep["ranged"]) or float(ep["dmg"]) <= 0.0:
			continue
		if _surf(e) > float(ep["reach"]) + 0.5:
			continue
		# One reaction per enemy cast (runners are reused, so key on the enemy + the cast start time).
		var start := _clock - e.runner.real_elapsed
		if absf(float(_parry_seen.get(e.uid, -99.0)) - start) < 0.12:
			continue
		if e.runner.real_elapsed < react:
			continue
		var hit_in := time_to_strike(e)
		if hit_in < 0.0:
			_parry_seen[e.uid] = start
			continue
		if hit_in > 0.45:
			# Too early: the stance would close before the swing lands. Do not start a new attack meanwhile.
			if hit_in < 1.0:
				_parry_wait = true
			continue
		if not fighter.can_cast(slot):
			_parry_wait = true         # mid-swing: wait for the cancel window / end of our own cast
			continue
		_parry_seen[e.uid] = start
		if _rng.randf() < clampf(float(cfg["dodge"]), 0.0, 0.95):
			fighter.input.target_uid = e.uid
			fighter.input.aim_point = e.center()
			fighter.input.press(slot)
			parries_attempted += 1
			return true
	return false


func _plan_ready(w: World, p: Dictionary, t: Fighter) -> bool:
	if _plan_escape:
		return true
	if _plan_ally != null:
		var mode_h := str(p["heal_mode"])
		if bool(p["revive"]) or mode_h == "target_ally":
			return _flat_dist(fighter, _plan_ally) <= maxf(4.0, float(p["heal_radius"]) * 0.9)
		if mode_h == "zone_self" or mode_h == "allies" or mode_h == "ally_lowest" or mode_h == "zone_target":
			return _plan_ally == fighter or _flat_dist(fighter, _plan_ally) <= float(p["heal_radius"]) * 0.85
		return true
	if float(p["dmg"]) <= 0.0 and not bool(p["cc"]) and not bool(p["taunt"]) and str(p["move"]) != "toward":
		return true
	if t == null:
		return false
	if _untouchable(t) and float(p["dmg"]) > 0.0:
		return false
	return _in_range(w, p, t, _surf(t))


func _press(w: World, slot: int, p: Dictionary, t: Fighter) -> void:
	var inp := fighter.input
	if _plan_ally != null and (float(p["heal"]) > 0.0 or bool(p["revive"]) or bool(p["cleanse"]) or bool(p["buff_ally"])):
		inp.target_uid = _plan_ally.uid
		inp.aim_point = _plan_ally.center()
	elif _plan_escape and (bool(p["move_aim"]) or str(p["move"]) == "toward"):
		var away := _escape_point(w)
		inp.target_uid = 0
		inp.aim_point = away + Vector3(0, 0.9, 0)
	elif t != null and bool(p["aimed"]) and float(p["dmg"]) > 0.0:
		_apply_aim(inp, p, t)
	inp.press(slot)


## Aimed skills: lead the target (scaled by difficulty) and add scatter. Clears the lock-on for this press
## so the skill uses the aim point (exactly like a human free-aiming).
func _apply_aim(inp: FighterInput, p: Dictionary, t: Fighter) -> void:
	var lead_t := 0.0
	if float(p["proj_speed"]) > 0.0:
		lead_t = _flat_dist(fighter, t) / float(p["proj_speed"])
	lead_t += float(p["delay"]) + float(p["time"]) * 0.15
	var helpless := t.status.is_disabled() or t.state in [Fighter.State.KNOCKDOWN, Fighter.State.GRABBED,
		Fighter.State.STUNNED, Fighter.State.CAST]
	var v := CoreUtil.flat(t.velocity)
	var pred := t.center() + (v * lead_t * float(cfg["lead"]) if not helpless else Vector3.ZERO)
	var err := float(cfg["aim_err"])
	if err > 0.0:
		var ang := _rng.randf() * TAU
		pred += CoreUtil.dir_of_yaw(ang) * _rng.randf() * err * (0.5 if helpless else 1.0)
	if pred.distance_to(t.center()) < 0.05:
		return
	inp.target_uid = 0
	inp.aim_point = pred


func _try_escape_to(point: Vector3) -> void:
	var to := CoreUtil.flat(point - fighter.global_position)
	if to.length() < 0.5:
		return
	var need := to.length() / maxf(1.0, fighter.get_stat("move_speed"))
	if need < _dodge_urgency * 0.9:
		return
	for s: SkillDef in fighter.skills:
		if not fighter.can_cast(s.slot) or not _escape_ok(fighter.world(), s.slot):
			continue
		var p := profile(fighter.resolve_skill(s.slot))
		if float(p["move_dist"]) < 2.5:
			continue
		var mv := str(p["move"])
		if bool(p["move_aim"]) or (mv == "away" and _target != null):
			var inp := fighter.input
			if bool(p["move_aim"]):
				inp.target_uid = 0
				inp.aim_point = fighter.global_position + to.normalized() * float(p["move_dist"]) + Vector3(0, 0.9, 0)
			inp.press(s.slot)
			return
		if bool(p["defensive"]):
			fighter.input.press(s.slot)
			return


func _escape_point(w: World) -> Vector3:
	var me := fighter.global_position
	var push := Vector3.ZERO
	for e: Fighter in _enemies(w):
		var d := CoreUtil.flat(me - e.global_position)
		var l := maxf(0.5, d.length())
		if l < 10.0:
			push += d / (l * l)
	var healer := _healer_ally(w)
	if healer != null:
		push += CoreUtil.flat_dir(healer.global_position - me, Vector3.ZERO) * 0.3
	if push.length() < 0.01:
		push = -fighter.forward()
	var dir := push.normalized()
	var p := me + dir * 8.0
	if not _in_bounds(w, p, 2.0):
		p = me + dir.rotated(Vector3.UP, PI * 0.5 * _strafe_sign) * 8.0
	return p


func _desired_move(w: World, t: Fighter) -> Vector3:
	var me := fighter.global_position
	# Raid soak circle: stack inside it (unless a telegraph lands on us before the soak resolves).
	if _share_pos != Vector3.INF and not (_dodging and _dodge_urgency < _share_left):
		var ts := CoreUtil.flat(_share_pos - me)
		if ts.length() > maxf(0.4, _share_r * 0.45):
			return ts.normalized()
		return Vector3.ZERO
	if _dodging:
		var to := CoreUtil.flat(_dodge_point - me)
		if to.length() > 0.2:
			return to.normalized()
		return Vector3.ZERO
	if _sidestep_left > 0.0 and _sidestep_dir != Vector3.ZERO:
		return _sidestep_dir
	# Back out of an enemy's melee swing (spacing) - only when we are not mid-combo ourselves.
	if t != null and _backstep_left > 0.0:
		return CoreUtil.flat_dir(me - t.global_position, -fighter.forward())
	if t != null and fighter.state != Fighter.State.CAST and float(cfg["spacing"]) > 0.0 and _style == "approach" \
			and _backstep_left <= 0.0:
		var ep := _enemy_profile_now(t)
		if not ep.is_empty() and bool(ep["melee"]) and not bool(ep["ranged"]) and _surf(t) < float(ep["reach"]) + 0.6 \
				and t.runner != null and t.runner.elapsed < 0.12 and not fighter.status.has(&"super_armor"):
			if _rng.randf() < float(cfg["spacing"]):
				_backstep_left = 0.35
				return CoreUtil.flat_dir(me - t.global_position, -fighter.forward())
	# Raid: never stand in front of a boss that is not targeting us (cleaves / frontal swings).
	if mode == "raid" and t != null and t.kind == "boss" and _role != "tank" and t.target_uid != fighter.uid:
		var rel := CoreUtil.flat(me - t.global_position)
		var fwd := t.forward()
		if rel.length() < t.radius() + 5.0 and rel.length() > 0.05 and rel.normalized().dot(fwd) > 0.25:
			var rgt := fwd.cross(Vector3.UP)
			var side := 1.0 if rel.dot(rgt) >= 0.0 else -1.0
			return (rgt * side * 1.0 - fwd * 0.6 + rel.normalized() * 0.2).normalized()
	match _style:
		"hold":
			return Vector3.ZERO
		"point":
			var to := CoreUtil.flat(_goal - me)
			var stop := 0.8
			if _plan_ally != null and _plan_slot >= 0:
				stop = maxf(0.8, _want_dist)
				to = CoreUtil.flat(_plan_ally.global_position - me)
			if to.length() > stop:
				return to.normalized()
			if t != null and mode == "raid" and _ranged_style:
				return _strafe(t) * 0.35
			return Vector3.ZERO
		"band":
			if t == null:
				return Vector3.ZERO
			var to := CoreUtil.flat(t.global_position - me)
			var d := to.length() - t.radius()
			var dir := to.normalized() if to.length() > 0.01 else fighter.forward()
			if d < _band_lo:
				return (-dir * 1.0 + _strafe(t) * 0.45).normalized()
			if d > _band_hi:
				return (dir + _strafe(t) * 0.2).normalized()
			return _strafe(t) * (0.8 if difficulty >= 2 else 0.5)
		_:
			if t == null:
				return Vector3.ZERO
			var to := CoreUtil.flat(t.global_position - me)
			var d := to.length() - t.radius()
			var dir := to.normalized() if to.length() > 0.01 else fighter.forward()
			if _role == "tank" and mode == "pvp":
				# Hold the front between the target and our backline.
				var back := _backline_point(w)
				if back != Vector3.INF and d > _want_dist + 0.4:
					var ideal := t.global_position + CoreUtil.flat_dir(back - t.global_position, -dir) * (t.radius() + _want_dist)
					var ti := CoreUtil.flat(ideal - me)
					if ti.length() > 0.6:
						return ti.normalized()
			if d > _want_dist + 0.35:
				# Close in on a slight curve so two melee bots don't run a perfectly straight line.
				return (dir + _strafe(t) * (0.25 if d > 5.0 else 0.0)).normalized()
			if d < _want_dist - 1.2 and not _is_launched(t):
				return -dir * 0.6
			if _untouchable(t) or _is_downed(t):
				return _strafe(t) * 0.6
			return Vector3.ZERO


func _strafe(t: Fighter) -> Vector3:
	var to := CoreUtil.flat_dir(t.global_position - fighter.global_position, fighter.forward())
	return to.cross(Vector3.UP) * _strafe_sign


func _backline_point(w: World) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for a: Fighter in w.allies_of(fighter, false):
		if a.kind == "summon":
			continue
		c += a.global_position
		n += 1
	return c / float(n) if n > 0 else Vector3.INF


## Obstacle (world raycast), arena-edge and danger-zone avoidance on top of a desired direction.
func _steer(w: World, desired: Vector3) -> Vector3:
	if desired.length() < 0.05:
		_hazard_blocked = false
		return Vector3.ZERO
	var dir := desired.normalized()
	var origin := fighter.global_position + Vector3(0, 0.6, 0)
	var me := fighter.global_position
	var in_danger := _danger_at(me, fighter.radius())
	var scale := minf(desired.length(), 1.0)
	if _probe_ok(w, origin, me, dir, in_danger):
		_detour_left = 0.0
		_hazard_blocked = false
		return dir * scale
	_hazard_blocked = not _in_hazard and _hazard_at(me + dir * LOOK_AHEAD)
	# Blocked: commit to one side for a while so we walk around the obstacle instead of dithering.
	if _detour_left <= 0.0:
		_detour_sign = 0.0
		for o: float in [0.45, 0.9, 1.4, 2.0]:
			var r_ok := _probe_ok(w, origin, me, dir.rotated(Vector3.UP, o), in_danger)
			var l_ok := _probe_ok(w, origin, me, dir.rotated(Vector3.UP, -o), in_danger)
			if r_ok and l_ok:
				_detour_sign = _strafe_sign
			elif r_ok:
				_detour_sign = 1.0
			elif l_ok:
				_detour_sign = -1.0
			if _detour_sign != 0.0:
				break
		if _detour_sign == 0.0:
			_detour_sign = _strafe_sign
		_detour_left = 1.2
	for o: float in [0.45, 0.9, 1.4, 2.0, 2.6]:
		var d := dir.rotated(Vector3.UP, o * _detour_sign)
		if _probe_ok(w, origin, me, d, in_danger):
			return d * scale
	for o: float in [0.45, 0.9, 1.4, 2.0, 2.6]:
		var d := dir.rotated(Vector3.UP, -o * _detour_sign)
		if _probe_ok(w, origin, me, d, in_danger):
			return d * scale
	# Fully boxed in: push along the original direction anyway (bounds clamp handles edges).
	return dir * scale


func _probe_ok(w: World, origin: Vector3, me: Vector3, d: Vector3, in_danger: bool) -> bool:
	var probe := me + d * LOOK_AHEAD
	if not _in_bounds(w, probe, 0.6):
		return false
	if not _in_hazard:
		var sh := d.cross(Vector3.UP) * fighter.radius()
		if _hazard_at(probe) or _hazard_at(probe + sh) or _hazard_at(probe - sh):
			return false
	if not _dodging and not in_danger and _danger_at(probe, fighter.radius() + 0.2):
		return false
	# Body-width probe: centre ray plus one per shoulder, so corners are not clipped.
	var side := d.cross(Vector3.UP) * (fighter.radius() + 0.1)
	for off: Vector3 in [Vector3.ZERO, side, -side]:
		var r := w.raycast(origin + off, origin + off + d * LOOK_AHEAD, CoreUtil.LAYER_WORLD)
		if not r.is_empty():
			var n: Vector3 = r.get("normal", Vector3.ZERO)
			if absf(n.y) < 0.6:
				return false
	return true
