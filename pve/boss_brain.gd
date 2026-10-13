class_name BossBrain
extends Node
## Raid boss AI (host only). Drives a boss Fighter through fighter.input like BotBrain (skill presses,
## move, aim, target) and runs the boss mechanics itself (telegraphed AreaEffects, soak/stack circles,
## interruptible channels, adds). Data comes from the boss mob def's "boss" dictionary (pve/mob_defs.gd):
##   phases:  [{hp, cn, en, adds: [mob ids], abilities: [ability ids in priority order]}]
##   abilities: id -> {kind, cd, first, ...}; kinds:
##     skill    - press mob-def skill `slot` (melee: only when the target is in melee range; target "far" = farthest)
##     zones    - persistent telegraphed zones under `count` random players (burst hit + lingering hit)
##     spread   - a telegraphed circle on every player at once (stacked players take several hits -> spread)
##     raid_aoe - raid-wide telegraphed blast (unavoidable; healers must top the party up)
##     cross    - lines from the boss in 4 directions, `waves` times rotated 45 degrees
##     share    - soak / stack circle: damage is split between everybody inside; fewer than `min` inside ->
##                every party member takes `fail_hit`
##     channel  - interruptible cast: a crowd-control skill landing on the boss interrupts it (and breaks the
##                boss); otherwise every party member takes `fail_hit` and the boss heals `heal`
##   enrage: {hp, atk_up, haste, cd_mult} - red blood (红血) enrage
##   berserk: {time, atk_up, haste, cn, en} - hard enrage (狂暴计时): `time` seconds after the pull the boss
##            goes berserk (warning 30 s before); parties without enough damage wipe instead of grinding on
##   add_hp: hp multiplier of phase adds (on top of the party-size scale); add_life: seconds before a phase add
##           dissolves (bots focus the boss, so adds must not outlive their phase forever)
## `casting` publishes the ability currently winding up ({id, kind, left, tank_buster}) for party AI (pre-cast
## defensives before a tank buster, pre-heal before a raid-wide blast).
## Super armor (霸体) is permanent except during a short "break" (破防) window when the stagger meter fills
## (damage + crowd control) or a channel is interrupted: then the boss can be launched / knocked down.

signal phase_changed(phase: int)
signal enraged_now()
signal broken(seconds: float)
signal mechanic_used(id: String)
signal channel_interrupted(id: String)

const STAGGER_MAX: float = 100.0
const STAGGER_PER_HP: float = 420.0     # stagger per 100% max hp of damage
const STAGGER_PER_HIT: float = 0.4
const STAGGER_PER_CC: float = 7.0
const STAGGER_DECAY: float = 2.5        # per second
const BREAK_TIME: float = 3.0
const BREAK_IMMUNITY: float = 12.0
const CC_MEMORY: float = 2.5            # a hit within this long after a cc skill cast counts as cc
const ARMOR_DUR: float = 9999.0

var fighter: Fighter
var mode: String = "boss"
## MatchRaid (or any node with send_announce(text, s) and optionally spawn_add(mob_id, pos) -> Fighter).
var match_ref: Node = null
var home: Vector3 = Vector3.ZERO
var data: Dictionary = {}
var phase: int = 0
var enraged: bool = false
var berserk: bool = false
var _berserk_warned: bool = false
var stagger: float = 0.0
var break_left: float = 0.0
var break_immunity: float = 0.0
var channel: Dictionary = {}            # {id, left, ab} while channelling
var shares: Array[Dictionary] = []      # pending soak/stack circles
var adds: Array[Fighter] = []
var casting: Dictionary = {}            # {id, kind, left, tank_buster} while an ability winds up
var last_announce: String = ""
var log_events: Array[String] = []      # for tests / debugging
var time: float = 0.0

var _cds: Dictionary = {}               # ability id -> seconds left
var _gcd: float = 2.0
var _cd_mult: float = 1.0
var _rng := RandomNumberGenerator.new()
var _last_cast: Dictionary = {}         # attacker uid -> {t, cc}
var _hooked: Dictionary = {}            # uid -> true (skill_cast connected)
var _hook_t: float = 0.0
var _target: Fighter = null
var _pending_far: int = 0
var _add_life: Dictionary = {}          # add uid -> seconds left


func setup(f: Fighter, m: String = "boss") -> void:
	fighter = f
	mode = m


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter
	if fighter == null:
		return
	data = fighter.mob_def.get("boss", {}) if fighter.mob_def.get("boss") is Dictionary else {}
	_rng.seed = 104729 + fighter.uid * 31
	if home == Vector3.ZERO:
		home = fighter.global_position
	var abilities: Dictionary = data.get("abilities", {})
	for id: Variant in abilities:
		var ab: Dictionary = abilities[id]
		_cds[str(id)] = float(ab.get("first", ab.get("cd", 5.0) * 0.5))
	_gcd = 1.5
	if not fighter.damaged.is_connected(_on_damaged):
		fighter.damaged.connect(_on_damaged)
	_ensure_armor()


func _physics_process(delta: float) -> void:
	var w := World.get_instance()
	if w != null and w.auto_step and w.is_host():
		think(delta)


# ================================================================== main loop
func think(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not fighter.is_alive():
		return
	var w := fighter.world()
	if w == null:
		return
	time += delta
	_tick_timers(delta)
	_tick_shares(delta)
	_hook_attackers(w, delta)
	_check_phase()
	_tick_break(delta)
	var inp := fighter.input
	_target = _pick_target(w)
	if _target == null:
		inp.target_uid = 0
		inp.aim_point = Vector3.ZERO
		var to_home := CoreUtil.flat(home - fighter.global_position)
		inp.move = to_home.normalized() if to_home.length() > 2.0 else Vector3.ZERO
		return
	if _pending_far > 0:
		# Keep aiming at the charge victim for the frame the press resolves.
		_pending_far -= 1
	else:
		inp.target_uid = _target.uid
		inp.aim_point = _target.center()
	if not channel.is_empty():
		inp.move = Vector3.ZERO
		_tick_channel(delta)
		return
	inp.move = Vector3.ZERO
	if not fighter.can_act():
		return
	var dist := CoreUtil.flat(_target.global_position - fighter.global_position).length() - _target.radius() - fighter.radius()
	var melee := float(data.get("melee_range", 3.5))
	if _gcd <= 0.0:
		var used := _try_abilities(w, dist, melee)
		if used:
			return
	if dist > melee * 0.85:
		inp.move = CoreUtil.flat_dir(_target.global_position - fighter.global_position, Vector3.ZERO)


func _tick_timers(delta: float) -> void:
	_gcd -= delta
	for k: Variant in _cds:
		_cds[k] = float(_cds[k]) - delta
	if not casting.is_empty():
		casting["left"] = float(casting["left"]) - delta
		if float(casting["left"]) <= 0.0:
			casting = {}
	for a: Variant in adds.duplicate():
		if not is_instance_valid(a) or not (a as Fighter).is_alive():
			adds.erase(a)
			continue
		var af := a as Fighter
		if _add_life.has(af.uid):
			_add_life[af.uid] = float(_add_life[af.uid]) - delta
			if float(_add_life[af.uid]) <= 0.0:
				_add_life.erase(af.uid)
				CoreUtil.fx(&"play", [&"smoke", af.center(), Vector3.UP, Color(0.7, 0.75, 0.85), 1.2])
				af.kill(null)
				adds.erase(af)
				log_events.append("add_expired")


func _pick_target(w: World) -> Fighter:
	if fighter.status.has(&"taunted"):
		var tt := fighter.status.source(&"taunted")
		if tt != null and tt.is_alive():
			return tt
	var top := fighter.top_threat()
	if top != null:
		return top
	var n := w.nearest_enemy(fighter, float(data.get("arena_radius", 22.0)) * 1.6)
	if n != null:
		fighter.add_threat(n, 1.0)
	return n


func current_abilities() -> Array:
	var phases: Array = data.get("phases", [])
	if phases.is_empty():
		return []
	var p: Dictionary = phases[clampi(phase, 0, phases.size() - 1)]
	return p.get("abilities", [])


func _try_abilities(w: World, dist: float, melee: float) -> bool:
	var abilities: Dictionary = data.get("abilities", {})
	for id_v: Variant in current_abilities():
		var id := str(id_v)
		if not abilities.has(id) or float(_cds.get(id, 0.0)) > 0.0:
			continue
		var ab: Dictionary = abilities[id]
		if bool(ab.get("melee", false)) and dist > melee:
			continue
		# No channels while broken: an interrupted channel would chain a second break.
		if break_left > 0.0 and str(ab.get("kind", "skill")) == "channel":
			continue
		if _use(w, id, ab):
			var kind := str(ab.get("kind", "skill"))
			if kind != "skill" or str(ab.get("slot", 0)) != "0":
				casting = {"id": id, "kind": kind, "left": float(ab.get("delay", ab.get("time", 1.4))),
					"tank_buster": kind == "skill" and int(ab.get("slot", 0)) == 1}
			_cds[id] = float(ab.get("cd", 8.0)) * _cd_mult
			_gcd = float(data.get("gcd", 1.6)) * _cd_mult
			mechanic_used.emit(id)
			log_events.append("ability:" + id)
			return true
	return false


# ================================================================== abilities
func _use(w: World, id: String, ab: Dictionary) -> bool:
	var kind := str(ab.get("kind", "skill"))
	var party := _party(w)
	if party.is_empty():
		return false
	match kind:
		"skill":
			var slot := int(ab.get("slot", 0))
			if not fighter.can_cast(slot):
				return false
			if str(ab.get("target", "")) == "far":
				var far := _farthest(party)
				if far != null:
					fighter.input.target_uid = far.uid
					fighter.input.aim_point = far.center()
					fighter.face_towards(far.global_position)
					_pending_far = 2
			fighter.input.press(slot)
			_announce_ab(ab, 2.0)
			return true
		"zones":
			var picks := _pick_random(party, int(ab.get("count", 2)))
			for p: Fighter in picks:
				var q := ab.duplicate()
				q["duration"] = 0.0
				q["hit"] = ab.get("burst", ab.get("hit", {}))
				RaidUtil.spawn_area(fighter, p.global_position, 0.0, q)
				var z := ab.duplicate()
				z["delay"] = float(ab.get("delay", 1.2))
				z["hit"] = ab.get("hit", {})
				RaidUtil.spawn_area(fighter, p.global_position, 0.0, z)
			_invoke_pose()
			_announce_ab(ab, 2.0)
			return true
		"spread":
			for p: Fighter in party:
				var q := ab.duplicate()
				q["duration"] = 0.0
				RaidUtil.spawn_area(fighter, p.global_position, 0.0, q)
			_invoke_pose()
			_announce_ab(ab, 2.5)
			return true
		"raid_aoe":
			var q := ab.duplicate()
			q["duration"] = 0.0
			q["radius"] = float(ab.get("radius", 40.0))
			RaidUtil.spawn_area(fighter, fighter.global_position, 0.0, q)
			_invoke_pose()
			_announce_ab(ab, 2.5)
			return true
		"cross":
			var waves := maxi(1, int(ab.get("waves", 1)))
			var base_yaw := fighter.facing_yaw
			for wv in waves:
				for k in 4:
					var yaw := base_yaw + PI * 0.5 * k + (PI * 0.25 if wv % 2 == 1 else 0.0)
					var q := ab.duplicate()
					q["shape"] = "line"
					q["duration"] = 0.0
					q["delay"] = float(ab.get("delay", 1.0)) + 1.0 * wv
					var start := fighter.global_position + CoreUtil.dir_of_yaw(yaw) * (fighter.radius() + 0.3)
					RaidUtil.spawn_area(fighter, start, yaw, q)
			_invoke_pose()
			_announce_ab(ab, 2.0)
			return true
		"share":
			var target: Fighter = null
			if str(ab.get("target", "random")) == "random":
				var others := party.filter(func(f: Fighter) -> bool: return f != _target)
				target = _pick_random(others if not others.is_empty() else party, 1)[0]
			else:
				target = _target
			var pos := w.ground_point(target.global_position)
			var fx_id := w.next_fx_id()
			var delay := float(ab.get("delay", 3.0))
			var radius := float(ab.get("radius", 3.5))
			CoreUtil.fx(&"spawn_area_visual", [fx_id, str(ab.get("visual", "rune")), "circle", pos, 0.0, radius, 0.0, 0.0,
				delay, 0.0, CoreUtil.to_color(ab.get("color", Color.WHITE))])
			shares.append({"id": id, "ab": ab, "pos": pos, "left": delay, "fx": fx_id})
			_invoke_pose()
			_announce_ab(ab, 3.0)
			return true
		"channel":
			_start_channel(id, ab)
			return true
	return false


func _invoke_pose() -> void:
	var s := fighter.get_skill(5)
	if s != null and fighter.can_act():
		fighter.start_skill(s, 5)


func _announce_ab(ab: Dictionary, secs: float) -> void:
	if ab.has("cn") or ab.has("en"):
		announce("%s %s" % [str(ab.get("cn", "")), str(ab.get("en", ""))], secs)


func announce(text: String, secs: float = 2.5) -> void:
	last_announce = text
	if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("send_announce"):
		match_ref.call("send_announce", text, secs)


func _party(w: World) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for e: Fighter in w.enemies_of(fighter, true):
		if e.kind != "summon" and e.is_hittable():
			out.append(e)
	return out


func _farthest(party: Array[Fighter]) -> Fighter:
	var best: Fighter = null
	var best_d := -1.0
	for p: Fighter in party:
		var d := p.global_position.distance_to(fighter.global_position)
		if d > best_d:
			best_d = d
			best = p
	return best


func _pick_random(pool: Array, n: int) -> Array[Fighter]:
	var arr: Array = pool.duplicate()
	var out: Array[Fighter] = []
	while not arr.is_empty() and out.size() < n:
		var i := _rng.randi_range(0, arr.size() - 1)
		out.append(arr[i])
		arr.remove_at(i)
	return out


# ================================================================== soak / stack
func _tick_shares(delta: float) -> void:
	var i := 0
	while i < shares.size():
		var s: Dictionary = shares[i]
		s["left"] = float(s["left"]) - delta
		if float(s["left"]) > 0.0:
			i += 1
			continue
		shares.remove_at(i)
		_resolve_share(s)


func _resolve_share(s: Dictionary) -> void:
	var w := fighter.world()
	if w == null:
		return
	var ab: Dictionary = s["ab"]
	var pos: Vector3 = s["pos"]
	var radius := float(ab.get("radius", 3.5))
	CoreUtil.fx(&"despawn", [int(s["fx"])])
	CoreUtil.fx(&"play", [&"explosion", pos, Vector3.UP, CoreUtil.to_color(ab.get("color", Color.WHITE)), radius / 2.0])
	var party := _party(w)
	var inside: Array[Fighter] = []
	for p: Fighter in party:
		if CoreUtil.flat(p.global_position - pos).length() - p.radius() <= radius and absf(p.global_position.y - pos.y) < 3.0:
			inside.append(p)
	var need := int(ab.get("min", 2))
	if not inside.is_empty():
		var h := Hit.normalize(ab.get("hit", {}))
		h["dmg"] = float(h["dmg"]) / float(inside.size())
		for p: Fighter in inside:
			p.receive_hit(fighter, h, pos)
	if inside.size() < need:
		var fh := Hit.normalize(ab.get("fail_hit", {}))
		for p: Fighter in party:
			if p.is_alive():
				p.receive_hit(fighter, fh, fighter.global_position)
		log_events.append("share_fail:" + str(s["id"]))
	else:
		log_events.append("share_ok:" + str(s["id"]))


# ================================================================== channel / interrupt
func _start_channel(id: String, ab: Dictionary) -> void:
	channel = {"id": id, "ab": ab, "left": float(ab.get("time", 4.0))}
	_cds[id] = maxf(float(_cds.get(id, 0.0)), float(ab.get("cd", 8.0)) * _cd_mult)
	var s := fighter.get_skill(6)
	if s != null:
		fighter.start_skill(s, 6)
	_announce_ab(ab, float(ab.get("time", 4.0)))


func _tick_channel(delta: float) -> void:
	channel["left"] = float(channel["left"]) - delta
	if fighter.state != Fighter.State.CAST and fighter.can_act():
		var s := fighter.get_skill(6)
		if s != null:
			fighter.start_skill(s, 6)
	if float(channel["left"]) > 0.0:
		return
	var ab: Dictionary = channel["ab"]
	var id := str(channel["id"])
	channel = {}
	fighter.interrupt_cast()
	var w := fighter.world()
	if w == null:
		return
	var fh := Hit.normalize(ab.get("fail_hit", {}))
	for p: Fighter in _party(w):
		p.receive_hit(fighter, fh, fighter.global_position)
	fighter.heal(fighter.max_hp * float(ab.get("heal", 0.0)), fighter)
	CoreUtil.fx(&"play", [&"ultimate_flash", fighter.global_position, fighter.forward(), Color(0.7, 0.9, 1.0), 3.0])
	log_events.append("channel_done:" + id)


func interrupt_channel() -> void:
	if channel.is_empty():
		return
	var id := str(channel["id"])
	channel = {}
	fighter.interrupt_cast()
	announce("打断成功！首领破防！ Interrupted! The boss is broken!", 2.5)
	channel_interrupted.emit(id)
	log_events.append("channel_interrupted:" + id)
	_start_break(BREAK_TIME + 1.0)


# ================================================================== stagger / super armor
func _ensure_armor() -> void:
	if fighter == null or not fighter.is_alive():
		return
	if break_left <= 0.0 and not fighter.status.has(&"super_armor"):
		fighter.status.add(&"super_armor", ARMOR_DUR, 1.0, fighter)
		fighter.status_mask = fighter.status.mask()


func _tick_break(delta: float) -> void:
	break_immunity = maxf(0.0, break_immunity - delta)
	stagger = maxf(0.0, stagger - STAGGER_DECAY * delta)
	if break_left > 0.0:
		break_left -= delta
		if break_left <= 0.0:
			break_left = 0.0
			break_immunity = BREAK_IMMUNITY
			stagger = 0.0
	_ensure_armor()


func _start_break(secs: float) -> void:
	if break_left > 0.0:
		# Already broken: extend, never restart (keeps the post-break immunity honest).
		break_left = maxf(break_left, secs)
		return
	break_left = secs
	stagger = 0.0
	fighter.remove_status(&"super_armor")
	fighter.add_status(&"def_down", secs, 0.2, null)
	CoreUtil.fx(&"play", [&"hit_heavy", fighter.center(), fighter.forward(), Color(1.0, 0.85, 0.3), 2.0])
	broken.emit(secs)
	log_events.append("break")


func _hook_attackers(w: World, delta: float) -> void:
	_hook_t -= delta
	if _hook_t > 0.0:
		return
	_hook_t = 1.0
	for e: Fighter in w.enemies_of(fighter, true):
		if _hooked.has(e.uid):
			continue
		_hooked[e.uid] = true
		e.skill_cast.connect(_on_enemy_skill_cast)


func _on_enemy_skill_cast(f: Fighter, slot: int) -> void:
	if f == null or not is_instance_valid(f):
		return
	var s: SkillDef = f.runner.skill if f.runner != null else f.get_skill(slot)
	_last_cast[f.uid] = {"t": time, "cc": RaidUtil.skill_is_cc(s)}


func _on_damaged(_f: Fighter, amount: float, src: Fighter) -> void:
	if fighter == null or not fighter.is_alive():
		return
	var cc := false
	if src != null and is_instance_valid(src) and _last_cast.has(src.uid):
		var lc: Dictionary = _last_cast[src.uid]
		cc = bool(lc["cc"]) and time - float(lc["t"]) <= CC_MEMORY
	if cc and not channel.is_empty():
		interrupt_channel()
		return
	if break_left > 0.0 or break_immunity > 0.0:
		return
	stagger += amount / maxf(1.0, fighter.max_hp) * STAGGER_PER_HP + STAGGER_PER_HIT + (STAGGER_PER_CC if cc else 0.0)
	if stagger >= STAGGER_MAX:
		announce("首领破防！ Boss staggered!", 2.0)
		_start_break(BREAK_TIME)


# ================================================================== phases / enrage
func _check_phase() -> void:
	var frac := fighter.hp / maxf(1.0, fighter.max_hp)
	var phases: Array = data.get("phases", [])
	var want := phase
	for i in range(phases.size()):
		if i > phase and frac <= float((phases[i] as Dictionary).get("hp", 0.0)):
			want = i
	if want != phase:
		var old_list: Array = current_abilities()
		phase = want
		var p: Dictionary = phases[phase]
		# Abilities unlocked by this phase start on their `first` timer (no burst of every new ability at once).
		var abilities: Dictionary = data.get("abilities", {})
		for id_v: Variant in p.get("abilities", []):
			var id := str(id_v)
			if not old_list.has(id_v) and abilities.has(id):
				var ab: Dictionary = abilities[id]
				_cds[id] = maxf(float(_cds.get(id, 0.0)), float(ab.get("first", float(ab.get("cd", 5.0)) * 0.5)))
		announce("%s %s" % [str(p.get("cn", "")), str(p.get("en", ""))], 3.0)
		_spawn_adds(p.get("adds", []))
		var roar := fighter.get_skill(4)
		if roar != null and fighter.can_act() and channel.is_empty():
			fighter.start_skill(roar, 4)
		_gcd = maxf(_gcd, 1.6)
		phase_changed.emit(phase)
		log_events.append("phase:%d" % phase)
	var bz: Dictionary = data.get("berserk", {})
	if not berserk and not bz.is_empty():
		var bt := float(bz.get("time", 600.0))
		if not _berserk_warned and time >= bt - 30.0:
			_berserk_warned = true
			announce("首领将在30秒后狂暴！ The boss goes berserk in 30 s!", 3.0)
		if time >= bt:
			berserk = true
			fighter.add_status(&"atk_up", ARMOR_DUR, float(bz.get("atk_up", 1.5)), fighter)
			fighter.add_status(&"haste", ARMOR_DUR, float(bz.get("haste", 0.5)), fighter)
			_cd_mult = minf(_cd_mult, 0.6)
			CoreUtil.fx(&"play", [&"ultimate_flash", fighter.global_position, fighter.forward(), Color(1.0, 0.1, 0.4), 4.0])
			announce("%s %s" % [str(bz.get("cn", "首领狂暴了！")), str(bz.get("en", "The boss has gone berserk!"))], 3.0)
			log_events.append("berserk")
	var en: Dictionary = data.get("enrage", {})
	if not enraged and not en.is_empty() and frac <= float(en.get("hp", 0.1)):
		enraged = true
		_cd_mult = float(en.get("cd_mult", 0.7))
		fighter.add_status(&"atk_up", ARMOR_DUR, float(en.get("atk_up", 0.5)), fighter)
		fighter.add_status(&"haste", ARMOR_DUR, float(en.get("haste", 0.3)), fighter)
		fighter.stat_bonus["atk_speed"] = float(fighter.stat_bonus.get("atk_speed", 0.0)) + 0.3
		fighter.stat_bonus["cast_speed"] = float(fighter.stat_bonus.get("cast_speed", 0.0)) + 0.3
		CoreUtil.fx(&"play", [&"ultimate_flash", fighter.global_position, fighter.forward(), Color(1.0, 0.15, 0.1), 3.0])
		announce("%s %s" % [str(en.get("cn", "红血狂暴！")), str(en.get("en", "Enrage!"))], 3.0)
		enraged_now.emit()
		log_events.append("enrage")


func _spawn_adds(list: Variant) -> void:
	if not (list is Array) or (list as Array).is_empty():
		return
	var w := fighter.world()
	if w == null:
		return
	var n := (list as Array).size()
	for i in n:
		var mob_id := str(list[i])
		var ang := TAU * float(i) / float(n) + fighter.facing_yaw
		var pos := w.ground_point(w.clamp_to_bounds(home + CoreUtil.dir_of_yaw(ang) * 8.0))
		var f: Fighter = null
		if match_ref != null and is_instance_valid(match_ref) and match_ref.has_method("spawn_add"):
			f = match_ref.call("spawn_add", mob_id, pos, fighter)
		else:
			f = w.spawn_fighter({"kind": "mob", "peer": 0, "mob_id": mob_id, "team": fighter.team, "pos": pos,
				"yaw": fighter.facing_yaw})
			if f != null:
				RaidUtil.attach_brain(w, f, "mob", "internal")
		if f != null:
			adds.append(f)
			if float(data.get("add_life", 0.0)) > 0.0:
				_add_life[f.uid] = float(data["add_life"])
			var near := w.nearest_enemy(f, 60.0)
			if near != null:
				f.add_threat(near, 1.0)
			CoreUtil.fx(&"play", [&"summon_circle", pos, Vector3.FORWARD, Color(0.6, 0.8, 1.0), 1.2])


## Removes every live add (boss death / encounter reset).
func despawn_adds() -> void:
	for a: Fighter in adds:
		if is_instance_valid(a) and a.is_alive():
			a.kill(null)
	adds.clear()


func _exit_tree() -> void:
	for s: Dictionary in shares:
		CoreUtil.fx(&"despawn", [int(s["fx"])])
	shares.clear()
