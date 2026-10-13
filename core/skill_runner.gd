class_name SkillRunner
extends RefCounted
## Executes a SkillDef's step timeline on the host (ARCHITECTURE §5.1). One runner per active cast.
##
## Each step is {"t": seconds, "type": String, ...params}; every param has a sensible default and
## missing/garbage keys never crash. Unknown types push_warning once. Kits may add their own action
## types globally with SkillRunner.register_action("type", func(runner, params): ...).

static var custom_actions: Dictionary = {}       # type -> Callable(runner: SkillRunner, p: Dictionary)

var caster: Fighter
var skill: SkillDef
var slot: int = -1
var elapsed: float = 0.0           # skill time (scaled by rate)
var real_elapsed: float = 0.0      # wall time since start
var duration: float = 0.0
var rate: float = 1.0
var finished: bool = false
var interrupted: bool = false
var vars: Dictionary = {}          # scratch storage for kit custom methods
var hits_landed: int = 0           # number of successful hits by this cast (kits can read)
var victims: Array[Fighter] = []   # every fighter hit by this cast

var _next_step: int = 0
var _hold: float = 0.0
var _actions: Array[Dictionary] = []    # ongoing timed actions (dash, leap, multi_melee, follow)
var _attached: Array[Node] = []         # effects bound to this cast (beams); killed on interrupt/cancel


static func register_action(type: String, handler: Callable) -> void:
	custom_actions[type] = handler


func _init(f: Fighter, s: SkillDef, sl: int) -> void:
	caster = f
	skill = s
	slot = sl
	duration = s.total_time()
	var sp := f.get_stat("atk_speed") if sl == 0 else f.get_stat("cast_speed")
	rate = clampf(sp, 0.25, 4.0)


# ================================================================== lifecycle
func start() -> void:
	_run_due_steps()
	_check_done()


func tick(delta: float) -> void:
	if finished:
		return
	elapsed += delta * rate
	real_elapsed += delta
	_run_due_steps()
	if finished:
		return
	_tick_actions(delta)
	_hold = maxf(0.0, _hold - delta)
	_check_done()


func _check_done() -> void:
	if finished:
		return
	if _next_step < skill.steps.size() or elapsed < duration or _hold > 0.0 or not _actions.is_empty():
		return
	for n: Variant in _attached:
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion() and (n as Node).get("blocks_cast") == true:
			return
	finished = true


func hold_for(t: float) -> void:
	_hold = maxf(_hold, t)


func is_holding() -> bool:
	return _hold > 0.0 or not _actions.is_empty()


func in_cancel_window() -> bool:
	if finished:
		return true
	if skill.cancel_window <= 0.0 or _hold > 0.0:
		return false
	for a: Dictionary in _actions:
		if str(a.get("kind")) in ["dash", "leap"]:
			return false
	return elapsed >= duration - skill.cancel_window


func can_cancel_into(new_slot: int) -> bool:
	if not in_cancel_window():
		return false
	return new_slot != slot or slot == 0


## Hit/stun interrupt: remaining steps cancelled, attached effects removed.
func interrupt() -> void:
	interrupted = true
	_stop()


## Cancelled by casting another skill in the cancel window.
func cancel() -> void:
	_stop()


## Ends the skill early (usable from kit custom methods).
func end_now() -> void:
	_next_step = skill.steps.size()
	_actions.clear()
	_hold = 0.0
	elapsed = maxf(elapsed, duration)
	_check_done()


func _stop() -> void:
	finished = true
	_next_step = skill.steps.size()
	_actions.clear()
	_hold = 0.0
	if caster != null and is_instance_valid(caster):
		caster.skill_velocity = Vector3.ZERO
		caster.ghost = false
	for n: Variant in _attached:
		if is_instance_valid(n):
			if (n as Node).has_method("finish"):
				(n as Node).call("finish")
			else:
				(n as Node).queue_free()
	_attached.clear()


func _run_due_steps() -> void:
	while not finished and _next_step < skill.steps.size():
		var st: Dictionary = skill.steps[_next_step]
		if float(st.get("t", 0.0)) > elapsed + 0.0001:
			break
		_next_step += 1
		execute_step(st)
		if caster == null or not is_instance_valid(caster) or not caster.is_alive():
			_stop()
			return


## Executes one action dictionary immediately (kits may call this from custom methods).
func execute_step(p: Dictionary) -> void:
	var type := str(p.get("type", ""))
	if custom_actions.has(type):
		var c: Callable = custom_actions[type]
		if c.is_valid():
			c.call(self, p)
			return
	var m := "_act_" + type
	if type != "" and has_method(m):
		call(m, p)
	else:
		CoreUtil.warn_once("action_" + type, "SkillRunner: unknown action type '%s' in skill %s" % [type, skill.id])


# ================================================================== param helpers
static func pf(p: Dictionary, key: String, def: float) -> float:
	var v: Variant = p.get(key, def)
	return float(v) if (v is float or v is int) else def


static func pi(p: Dictionary, key: String, def: int) -> int:
	var v: Variant = p.get(key, def)
	return int(v) if (v is float or v is int) else def


static func pb(p: Dictionary, key: String, def: bool) -> bool:
	var v: Variant = p.get(key, def)
	return bool(v) if (v is bool or v is int) else def


static func ps(p: Dictionary, key: String, def: String) -> String:
	var v: Variant = p.get(key, def)
	return str(v) if (v is String or v is StringName) else def


static func pd(p: Dictionary, key: String) -> Dictionary:
	var v: Variant = p.get(key, {})
	return v if v is Dictionary else {}


func phit(p: Dictionary, key := "hit") -> Dictionary:
	return Hit.normalize(p.get(key, {}))


func world() -> World:
	return caster.world() if caster != null else World.get_instance()


func has_hit_param(p: Dictionary, key := "hit") -> bool:
	return p.get(key) is Dictionary


func _color(p: Dictionary) -> Color:
	var def := caster.kit.tint if caster.kit != null else Color(1, 0.9, 0.6)
	return CoreUtil.to_color(p.get("color", def), def)


## Deals a hit and records it on this cast.
func deal(victim: Fighter, hit: Dictionary, from_pos: Vector3) -> float:
	if victim == null or not victim.is_hittable():
		return 0.0
	var before := victim.hp + victim.shield_hp
	var d := victim.receive_hit(caster, hit, from_pos)
	if d > 0.0 or victim.hp + victim.shield_hp < before or victim.state == Fighter.State.GRABBED:
		hits_landed += 1
		if not victims.has(victim):
			victims.append(victim)
	return d


func enemies() -> Array[Fighter]:
	var out: Array[Fighter] = []
	var w := world()
	if w == null:
		return out
	for f: Fighter in w.enemies_of(caster, true):
		if f.is_hittable():
			out.append(f)
	return out


## Resolves a placement point: "self", "forward", "target", "aim_point".
func resolve_point(at: String, distance: float, max_distance: float) -> Vector3:
	var origin := caster.global_position
	var p := origin
	match at:
		"self":
			p = origin
		"forward":
			p = origin + caster.forward() * distance
		"target":
			var t := caster.get_target()
			if t != null and t.global_position.distance_to(origin) <= max_distance:
				p = t.global_position
			else:
				p = _clamped_aim(max_distance, distance)
		_:
			p = _clamped_aim(max_distance, distance)
	var w := world()
	if w != null:
		p = w.clamp_to_bounds(p)
		p = w.ground_point(p)
	return p


func _clamped_aim(max_distance: float, fallback_distance: float) -> Vector3:
	var origin := caster.global_position
	var ap := caster.aim_point()
	var d := CoreUtil.flat(ap - origin)
	if d.length() < 0.1:
		return origin + caster.forward() * fallback_distance
	if d.length() > max_distance:
		d = d.normalized() * max_distance
	return origin + d


# ================================================================== melee
func _act_melee(p: Dictionary) -> void:
	var hit := phit(p)
	melee_hit(p, hit)
	CoreUtil.fx(&"play", [StringName(ps(p, "fx", "slash_arc")), caster.center() + caster.forward() * pf(p, "range", 2.5) * 0.5,
		caster.forward(), _color(p), pf(p, "range", 2.5) / 2.5])


## Instant hitbox in front of the caster. Returns fighters hit.
func melee_hit(p: Dictionary, hit: Dictionary) -> Array[Fighter]:
	var shape := ps(p, "shape", "arc")
	var rng := pf(p, "range", 2.5)
	var arc := pf(p, "arc", 100.0)
	var width := pf(p, "width", 1.5)
	var height := pf(p, "height", 2.0)
	var offset := pf(p, "offset", 0.0)
	var max_targets := pi(p, "max_targets", 99)
	var fwd := caster.forward()
	var rgt := caster.right()
	var origin := caster.global_position + fwd * offset
	var cy := caster.center().y
	var cands: Array[Fighter] = enemies()
	cands.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	var out: Array[Fighter] = []
	for e: Fighter in cands:
		if out.size() >= max_targets:
			break
		if absf(e.center().y - cy) > height + e.height() * 0.5:
			continue
		var to := CoreUtil.flat(e.global_position - origin)
		var dist := to.length()
		var ok := false
		match shape:
			"circle":
				ok = dist - e.radius() <= rng
			"box":
				var z := to.dot(fwd)
				var x := to.dot(rgt)
				ok = z >= -e.radius() and z <= rng + e.radius() and absf(x) <= width * 0.5 + e.radius()
			_:
				if dist - e.radius() <= rng:
					ok = dist < 0.7 or rad_to_deg(fwd.angle_to(to / maxf(dist, 0.0001))) <= arc * 0.5
		if ok:
			out.append(e)
			deal(e, hit, caster.global_position)
	return out


func _act_multi_melee(p: Dictionary) -> void:
	var count := maxi(1, pi(p, "count", 3))
	var interval := maxf(0.01, pf(p, "interval", 0.12))
	_act_melee(p)
	if count > 1:
		_actions.append({"kind": "multi_melee", "p": p, "left": count - 1, "interval": interval, "timer": interval})


# ================================================================== projectile
func _act_projectile(p: Dictionary) -> void:
	var w := world()
	if w == null:
		return
	var count := maxi(1, pi(p, "count", 1))
	var spread := pf(p, "spread", 0.0)
	var speed := maxf(0.1, pf(p, "speed", 22.0))
	var gravity := pf(p, "gravity", 0.0)
	var from_mode := ps(p, "from", "hand")
	var aim := ps(p, "aim", "aim_point")
	var target := caster.get_target()
	var from := caster.hand_position(true)
	if from_mode == "center":
		from = caster.center() + caster.forward() * 0.4
	var aim_pt := caster.aim_point()
	if aim == "target" and target != null:
		aim_pt = target.center()
	if from_mode == "sky":
		from = aim_pt + Vector3(0, pf(p, "sky_height", 12.0), 0) - caster.forward() * 2.0
	var dir := caster.forward()
	if aim != "forward" or from_mode == "sky":
		var d := aim_pt - from
		if d.length() > 0.2:
			dir = d.normalized()
		if from_mode != "sky" and aim != "forward":
			# Never shoot backwards: aim points behind the caster collapse to forward.
			if CoreUtil.flat(dir).dot(caster.forward()) < -0.2 and target == null:
				dir = caster.forward()
	var homing_target: Fighter = null
	if pf(p, "homing", 0.0) > 0.0:
		homing_target = target if (target != null and caster.is_enemy(target)) else w.nearest_enemy(caster, pf(p, "range", 18.0) + 4.0)
	for i in count:
		var yaw_off := 0.0
		if count > 1 and spread > 0.0:
			yaw_off = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1)))
		var d2 := dir.rotated(Vector3.UP, yaw_off)
		var vel := d2 * speed
		if gravity > 0.0 and aim != "forward" and from_mode != "sky":
			vel = _ballistic(from, aim_pt if count == 1 else from + CoreUtil.flat(d2) * CoreUtil.flat(aim_pt - from).length(), speed, gravity)
		var pr := Projectile.new()
		pr.caster = caster
		pr.team = caster.team
		pr.velocity = vel
		pr.gravity = gravity
		pr.radius = pf(p, "radius", 0.35)
		pr.max_range = pf(p, "range", 18.0)
		pr.pierce = pb(p, "pierce", false)
		pr.bounce = pi(p, "bounce", 0)
		pr.homing = pf(p, "homing", 0.0)
		pr.homing_target = homing_target
		pr.hit = phit(p)
		pr.explode = pd(p, "explode")
		pr.visual = ps(p, "visual", "orb")
		pr.color = _color(p)
		pr.visual_scale = pf(p, "scale", 1.0)
		pr.runner = self
		pr.position = from
		w.add_effect(pr)
	CoreUtil.fx(&"sfx", [StringName(ps(p, "sfx", "shot")), from])


static func _ballistic(from: Vector3, to: Vector3, speed: float, g: float) -> Vector3:
	var flat := CoreUtil.flat(to - from)
	var dist := flat.length()
	if dist < 0.1:
		return Vector3(0, speed, 0)
	var t := maxf(0.35, dist / speed)
	var vy := ((to.y - from.y) + 0.5 * g * t * t) / t
	return flat / dist * (dist / t) + Vector3(0, vy, 0)


# ================================================================== ground / beam / trap
func _make_area(p: Dictionary, pos: Vector3, yaw: float) -> AreaEffect:
	var a := AreaEffect.new()
	a.caster = caster
	a.team = caster.team
	a.shape = ps(p, "shape", "circle")
	a.radius = pf(p, "radius", 3.0)
	a.length = pf(p, "length", maxf(a.radius * 2.0, 6.0))
	a.width = pf(p, "width", 2.0 if a.shape != "ring" else 1.0)
	a.area_height = pf(p, "height", 3.0)
	a.delay = maxf(0.0, pf(p, "delay", 0.0))
	a.duration = maxf(0.0, pf(p, "duration", 0.0))
	a.tick_interval = maxf(0.05, pf(p, "tick", 0.5))
	a.affects = ps(p, "affects", "enemies")
	a.hit = phit(p) if has_hit_param(p) else (Hit.normalize({}) if a.affects != "allies" else {})
	a.ally_effect = pd(p, "ally_effect")
	a.visual = ps(p, "visual", "rune")
	a.color = _color(p)
	a.follow_caster = pb(p, "follow_caster", false)
	a.max_hits_per_target = pi(p, "max_hits", 0)
	a.runner = self
	a.position = pos
	a.yaw = yaw
	return a


## Public: spawns a `ground`-style AreaEffect from step params `p` at an explicit `pos` / `yaw` (patterned
## bombardments). `pos` is used as given (no ground snap). Follow-caster areas are bound to this cast.
func spawn_area(p: Dictionary, pos: Vector3, yaw: float) -> AreaEffect:
	var w := world()
	if w == null:
		return null
	var a := _make_area(p, pos, yaw)
	a.mode = "zone"
	w.add_effect(a)
	if a.follow_caster:
		_attached.append(a)
	return a


## `at: "point"` + `pos` (Vector3): an explicit world point (clamped to the arena, snapped to the ground).
func _explicit_point(p: Dictionary) -> Vector3:
	var pos := CoreUtil.to_vec3(p.get("pos", caster.global_position), caster.global_position)
	var w := world()
	if w != null:
		pos = w.ground_point(w.clamp_to_bounds(pos))
	return pos


func _act_ground(p: Dictionary) -> void:
	var w := world()
	if w == null:
		return
	var at := ps(p, "at", "target")
	var distance := pf(p, "distance", 6.0)
	var max_d := pf(p, "max_distance", maxf(maxf(distance * 2.0, skill.range), 8.0))
	var shape := ps(p, "shape", "circle")
	var pos: Vector3
	var yaw := caster.facing_yaw
	if at == "point":
		# Explicit point; optional `yaw` (lines start at `pos` and extend along it, default caster facing).
		if p.has("yaw") and (p["yaw"] is float or p["yaw"] is int):
			yaw = float(p["yaw"])
		pos = _explicit_point(p)
		var a0 := _make_area(p, pos, yaw)
		a0.mode = "zone"
		w.add_effect(a0)
		if a0.follow_caster:
			_attached.append(a0)
		return
	if shape == "line":
		# Lines start at the caster (plus offset) and extend toward the aim/target.
		var aimp := resolve_point(at, distance, max_d) if at != "self" and at != "forward" else caster.global_position + caster.forward() * 5.0
		var d := CoreUtil.flat(aimp - caster.global_position)
		if d.length() > 0.2:
			yaw = CoreUtil.yaw_of(d.normalized())
		pos = w.ground_point(caster.global_position + CoreUtil.dir_of_yaw(yaw) * pf(p, "offset", 0.3))
	else:
		pos = resolve_point(at, distance, max_d)
	var a := _make_area(p, pos, yaw)
	a.mode = "zone"
	w.add_effect(a)
	if a.follow_caster:
		_attached.append(a)


func _act_beam(p: Dictionary) -> void:
	var w := world()
	if w == null:
		return
	var q := p.duplicate()
	q["shape"] = "line"
	q["length"] = pf(p, "length", 14.0)
	q["width"] = pf(p, "width", 0.8)
	q["duration"] = maxf(0.05, pf(p, "duration", 0.6))
	q["tick"] = pf(p, "tick", 0.15)
	q["delay"] = 0.0
	if not q.has("visual"):
		q["visual"] = "lightning"
	var a := _make_area(q, caster.global_position, caster.facing_yaw)
	a.mode = "beam"
	a.follow_caster = true
	a.follow_aim = pb(p, "follow_aim", true)
	a.blocks_cast = true
	a.area_height = pf(p, "height", 2.5)
	w.add_effect(a)
	_attached.append(a)


func _act_trap(p: Dictionary) -> void:
	var w := world()
	if w == null:
		return
	var q := p.duplicate()
	q["shape"] = "circle"
	q["radius"] = pf(p, "radius", 1.5)
	q["duration"] = pf(p, "duration", 20.0)
	if not q.has("visual"):
		q["visual"] = ps(p, "trap_id", "rune")
	var pos := _explicit_point(p) if ps(p, "at", "self") == "point" \
		else resolve_point(ps(p, "at", "self"), pf(p, "distance", 3.0), pf(p, "max_distance", maxf(skill.range, 10.0)))
	var a := _make_area(q, pos, caster.facing_yaw)
	a.mode = "trap"
	a.arm_time = maxf(0.0, pf(p, "arm_time", 0.5))
	a.trigger_statuses = CoreUtil.status_list(p.get("on_trigger_statuses", []))
	a.follow_caster = false
	a.trap_key = "%d:%s:%s" % [caster.uid, str(skill.id), ps(p, "trap_id", "trap")]
	w.add_effect(a)
	w.register_trap(a.trap_key, a, maxi(1, pi(p, "max_active", 3)))


# ================================================================== movement
func _act_dash(p: Dictionary) -> void:
	var distance := pf(p, "distance", 6.0)
	var speed := maxf(1.0, pf(p, "speed", 24.0))
	var dir := caster.forward()
	match ps(p, "direction", "forward"):
		"back":
			dir = -caster.forward()
		"aim":
			dir = CoreUtil.flat_dir(caster.aim_point() - caster.global_position, caster.forward())
		"target":
			var t := caster.get_target()
			if t == null and world() != null:
				t = world().nearest_enemy(caster, distance + 4.0)
			if t != null:
				var d := CoreUtil.flat(t.global_position - caster.global_position)
				dir = CoreUtil.flat_dir(d, caster.forward())
				if not pb(p, "through_enemies", false):
					distance = clampf(d.length() - (t.radius() + caster.radius() + 0.3), 0.0, distance)
	if ps(p, "direction", "forward") != "back":
		caster.face_towards(caster.global_position + dir)
	caster.ghost = pb(p, "through_enemies", false)
	_actions.append({"kind": "dash", "dir": dir, "speed": speed, "left": distance, "hit": phit(p) if has_hit_param(p) else {},
		"stop_on_hit": pb(p, "stop_on_hit", false), "hit_set": {}, "last": caster.global_position, "stuck": 0,
		"width": pf(p, "width", 1.2)})
	CoreUtil.fx(&"play", [&"dash_trail", caster.center(), dir, _color(p), 1.0])


func _act_blink(p: Dictionary) -> void:
	var w := world()
	var distance := pf(p, "distance", 8.0)
	var origin := caster.global_position
	var dest := origin + caster.forward() * distance
	var t := caster.get_target()
	var face_target := false
	match ps(p, "to", "aim_point"):
		"back":
			dest = origin - caster.forward() * distance
		"behind_target", "target":
			if t == null and w != null:
				t = w.nearest_enemy(caster, distance + 6.0)
			if t != null:
				var off := t.radius() + caster.radius() + 0.5
				if ps(p, "to", "") == "behind_target":
					dest = t.global_position - t.forward() * off
				else:
					dest = t.global_position - CoreUtil.flat_dir(t.global_position - origin) * off
				face_target = true
		_:
			dest = _clamped_aim(distance, distance)
	CoreUtil.fx(&"play", [&"blink", caster.center(), caster.forward(), _color(p), 1.0])
	if w != null:
		dest = w.clamp_to_bounds(dest)
		var c0 := caster.center()
		var c1 := dest + Vector3(0, caster.height() * 0.5, 0)
		var r := w.raycast(c0, c1, CoreUtil.LAYER_WORLD)
		if not r.is_empty():
			var hp_: Vector3 = r["position"]
			dest = hp_ - (c1 - c0).normalized() * (caster.radius() + 0.2)
			dest.y = origin.y
		dest = w.ground_point(dest)
	caster.global_position = dest
	caster.velocity = Vector3.ZERO
	if face_target and t != null:
		caster.face_towards(t.global_position)
	CoreUtil.fx(&"play", [&"blink", caster.center(), caster.forward(), _color(p), 1.0])


func _act_leap(p: Dictionary) -> void:
	var w := world()
	var distance := pf(p, "distance", 6.0)
	var origin := caster.global_position
	var to := origin + caster.forward() * distance
	match ps(p, "to", "target"):
		"forward":
			to = origin + caster.forward() * distance
		"aim_point":
			to = _clamped_aim(distance, distance)
		_:
			var t := caster.get_target()
			if t == null and w != null:
				t = w.nearest_enemy(caster, distance + 2.0)
			if t != null:
				var d := CoreUtil.flat(t.global_position - origin)
				var reach := minf(distance, maxf(0.0, d.length() - (t.radius() + caster.radius() + 0.2)))
				to = origin + CoreUtil.flat_dir(d, caster.forward()) * reach
			else:
				to = _clamped_aim(distance, distance)
	if w != null:
		to = w.ground_point(w.clamp_to_bounds(to))
	caster.face_towards(to)
	_actions.append({"kind": "leap", "from": origin, "to": to, "height": pf(p, "height", 4.0),
		"duration": maxf(0.05, pf(p, "duration", 0.6)), "t": 0.0, "land": pd(p, "land"), "p": p})


func _act_launch_self(p: Dictionary) -> void:
	caster.velocity.y = pf(p, "vertical", 9.0)
	var fwd := pf(p, "forward", 0.0)
	if fwd != 0.0:
		caster.skill_velocity = caster.forward() * fwd


# ================================================================== support
func _ally_targets(mode: String, radius: float, include_dead := false) -> Array[Fighter]:
	var out: Array[Fighter] = []
	var w := world()
	match mode:
		"self":
			out.append(caster)
		"allies", "all_allies":
			if w != null:
				for f: Fighter in w.allies_of(caster, true, include_dead):
					if f.global_position.distance_to(caster.global_position) <= radius:
						out.append(f)
			else:
				out.append(caster)
		"target_ally":
			var t: Fighter = null
			if w != null and caster.input != null and caster.input.target_uid != 0:
				t = w.get_fighter(caster.input.target_uid)
			if t != null and t.team == caster.team and (t.is_alive() or include_dead):
				out.append(t)
			else:
				out.append(_lowest_ally(radius, include_dead))
		_:
			out.append(_lowest_ally(radius, include_dead))
	return out


func _lowest_ally(radius: float, include_dead := false) -> Fighter:
	var w := world()
	var best: Fighter = caster
	var best_v := caster.hp / caster.max_hp
	if w == null:
		return best
	for f: Fighter in w.allies_of(caster, true, include_dead):
		if f.global_position.distance_to(caster.global_position) > radius:
			continue
		var v := f.hp / f.max_hp if f.is_alive() else -1.0
		if v < best_v:
			best_v = v
			best = f
	return best


func _apply_status_list(f: Fighter, list: Variant) -> void:
	for s: Dictionary in CoreUtil.status_list(list):
		f.add_status(s["id"], float(s["dur"]), float(s["power"]), caster)


func _act_buff(p: Dictionary) -> void:
	var targets := _ally_targets(ps(p, "target", "self"), pf(p, "radius", 10.0))
	var statuses := CoreUtil.status_list(p.get("statuses", []))
	var shield := pf(p, "shield", 0.0)
	var shield_dur := pf(p, "shield_dur", 0.0)
	if shield_dur <= 0.0:
		shield_dur = 8.0
		for s: Dictionary in statuses:
			shield_dur = maxf(shield_dur, float(s["dur"]))
	for f: Fighter in targets:
		if not f.is_alive():
			continue
		for s: Dictionary in statuses:
			f.add_status(s["id"], float(s["dur"]), float(s["power"]), caster)
		if shield > 0.0:
			f.add_shield(shield * caster.max_hp, shield_dur, caster)
		CoreUtil.fx(&"play", [StringName(ps(p, "fx", "buff_aura")), f.global_position, f.forward(), _color(p), 1.0])


func _act_debuff(p: Dictionary) -> void:
	var radius := pf(p, "radius", 6.0)
	var targets: Array[Fighter] = []
	var w := world()
	if ps(p, "target", "target") == "enemies":
		for e: Fighter in enemies():
			if e.global_position.distance_to(caster.global_position) <= radius:
				targets.append(e)
	else:
		var t := caster.get_target()
		if t != null and caster.is_enemy(t) and t.global_position.distance_to(caster.global_position) <= radius * 2.0:
			targets.append(t)
		elif w != null:
			var n := w.nearest_enemy(caster, radius)
			if n != null:
				targets.append(n)
	for e: Fighter in targets:
		if not e.is_hittable():
			continue
		_apply_status_list(e, p.get("statuses", []))
		CoreUtil.fx(&"play", [StringName(ps(p, "fx", "debuff_puff")), e.center(), e.forward(), _color(p), 1.0])


func _act_heal(p: Dictionary) -> void:
	var revive := pb(p, "revive", false)
	var targets := _ally_targets(ps(p, "target", "self"), pf(p, "radius", 12.0), revive)
	var frac := pf(p, "amount", 0.15)
	var mscale := pf(p, "matk_scale", 0.0)
	var hot := pd(p, "hot")
	for f: Fighter in targets:
		if not f.is_alive():
			if revive:
				f.revive(maxf(frac, 0.1))
			continue
		f.heal(frac * f.max_hp + mscale * caster.get_stat("matk"), caster)
		if not hot.is_empty():
			f.add_status(&"regen", pf(hot, "dur", 5.0), pf(hot, "power", 0.02), caster)
		CoreUtil.fx(&"play", [&"heal_burst", f.global_position, f.forward(), Color(0.6, 1.0, 0.6), 1.0])


func _act_cleanse(p: Dictionary) -> void:
	var mode := ps(p, "target", "self")
	var targets := _ally_targets("self" if mode == "self" else "allies", pf(p, "radius", 10.0))
	for f: Fighter in targets:
		f.cleanse()
		CoreUtil.fx(&"play", [&"holy_burst", f.global_position, f.forward(), Color(1, 1, 0.8), 0.6])


func _act_summon(p: Dictionary) -> void:
	var w := world()
	if w == null:
		return
	var sid := ps(p, "summon_id", "")
	var count := maxi(1, pi(p, "count", 1))
	var offset := pf(p, "offset", 2.0)
	var dur := pf(p, "duration", 20.0)
	var max_active := maxi(1, pi(p, "max_active", 3))
	for i in count:
		var existing := w.summons_of(caster, sid)
		while existing.size() >= max_active:
			var oldest: Fighter = existing.pop_front()
			if oldest is Summon:
				(oldest as Summon).expire()
			else:
				oldest.kill(null)
		var ang := caster.facing_yaw + PI * 0.5 + (TAU * float(i) / float(count)) if count > 1 else caster.facing_yaw + PI * 0.75
		var pos := caster.global_position + CoreUtil.dir_of_yaw(ang) * offset
		pos = w.ground_point(w.clamp_to_bounds(pos))
		w.spawn_summon(caster, sid, pos, dur)
		CoreUtil.fx(&"play", [&"summon_circle", pos, caster.forward(), _color(p), 1.0])


func _act_grab(p: Dictionary) -> void:
	var rng := pf(p, "range", 1.8)
	var fwd := caster.forward()
	var best: Fighter = null
	var best_d := INF
	for e: Fighter in enemies():
		if e.state == Fighter.State.LAUNCHED or e.is_downed() or e.state == Fighter.State.GRABBED:
			continue
		var to := CoreUtil.flat(e.global_position - caster.global_position)
		var d := to.length() - e.radius() - caster.radius()
		if d > rng or absf(e.global_position.y - caster.global_position.y) > 1.2:
			continue
		if to.length() > 0.5 and rad_to_deg(fwd.angle_to(to.normalized())) > pf(p, "arc", 90.0) * 0.5:
			continue
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		if pb(p, "end_on_miss", false):
			end_now()
		return
	var h := phit(p)
	h["grab"] = true
	h["grab_time"] = maxf(0.05, pf(p, "grab_time", 0.8))
	var throw_d := pd(p, "throw")
	if not throw_d.is_empty():
		h["throw"] = throw_d
	h["_normalized"] = true
	caster.face_towards(best.global_position)
	deal(best, h, caster.global_position)
	CoreUtil.fx(&"play", [&"hit_heavy", best.center(), fwd, _color(p), 0.8])


func _act_taunt(p: Dictionary) -> void:
	var radius := pf(p, "radius", 8.0)
	var dur := pf(p, "duration", 3.0)
	for e: Fighter in enemies():
		if e.global_position.distance_to(caster.global_position) <= radius:
			e.add_status(&"taunted", dur, 1.0, caster)
	CoreUtil.fx(&"play", [&"ultimate_flash" if skill.is_ultimate() else &"buff_aura", caster.global_position, caster.forward(), Color(1, 0.4, 0.2), radius / 4.0])


func _act_pull(p: Dictionary) -> void:
	var radius := pf(p, "radius", 7.0)
	var strength := pf(p, "strength", 10.0)
	var has_h := has_hit_param(p)
	var h := Hit.with(phit(p), {"knockback": 0.0}) if has_h else {}
	for e: Fighter in enemies():
		var d := CoreUtil.flat(caster.global_position - e.global_position)
		if d.length() > radius:
			continue
		if has_h:
			deal(e, h, caster.global_position)
		if not e.is_alive() or (e.has_status(&"super_armor") and not bool(h.get("armor_break", false))):
			continue
		var gap := maxf(0.0, d.length() - (caster.radius() + e.radius() + 0.6))
		var v := minf(sqrt(2.0 * Fighter.KNOCK_FRICTION_GROUND * gap), strength * 2.0)
		e.apply_knockback(d, v, 0.0)
	CoreUtil.fx(&"play", [&"dark_burst", caster.center(), caster.forward(), _color(p), radius / 4.0])


func _act_custom(p: Dictionary) -> void:
	var method := ps(p, "method", "")
	var args := pd(p, "args")
	var target: Object = caster.kit
	if target == null or not target.has_method(method):
		var o := caster.get_owner_fighter()
		if o != null and o.kit != null and o.kit.has_method(method):
			target = o.kit
	if target != null and method != "" and target.has_method(method):
		target.call(method, caster, args, self)
	else:
		CoreUtil.warn_once("custom_" + method, "SkillRunner: custom method '%s' not found for skill %s" % [method, skill.id])


func _act_anim(p: Dictionary) -> void:
	caster.anim_key = StringName(ps(p, "anim", str(skill.anim)))
	caster.anim_speed = pf(p, "speed", 1.0) * rate
	caster.anim_seq += 1


func _fx_pos(p: Dictionary) -> Vector3:
	match ps(p, "at", "self"):
		"target":
			var t := caster.get_target()
			if t != null:
				return t.center()
		"aim_point":
			return caster.aim_point()
		"forward":
			return caster.center() + caster.forward() * pf(p, "distance", 2.0)
	return caster.center()


func _act_sfx(p: Dictionary) -> void:
	CoreUtil.fx(&"sfx", [StringName(ps(p, "name", "swing")), _fx_pos(p)])


func _act_vfx(p: Dictionary) -> void:
	CoreUtil.fx(&"play", [StringName(ps(p, "name", "cast_glow")), _fx_pos(p), caster.forward(), _color(p), pf(p, "scale", 1.0)])


## Extra convenience actions (not in the contract table, harmless for kits to use).
func _act_face(_p: Dictionary) -> void:
	caster.face_towards(caster.aim_point())


func _act_end(_p: Dictionary) -> void:
	end_now()


func _act_wait(_p: Dictionary) -> void:
	pass


func _act_stop(_p: Dictionary) -> void:
	caster.skill_velocity = Vector3.ZERO
	caster.velocity = Vector3(0, minf(caster.velocity.y, 0.0), 0)


# ================================================================== ongoing actions
func _tick_actions(delta: float) -> void:
	var i := 0
	while i < _actions.size():
		var a: Dictionary = _actions[i]
		var done := false
		match str(a["kind"]):
			"multi_melee":
				a["timer"] = float(a["timer"]) - delta * rate
				if float(a["timer"]) <= 0.0:
					_act_melee(a["p"])
					a["left"] = int(a["left"]) - 1
					a["timer"] = float(a["interval"])
				done = int(a["left"]) <= 0
			"dash":
				done = _tick_dash(a, delta)
			"leap":
				done = _tick_leap(a, delta)
			_:
				done = true
		if finished:
			return
		if done:
			_actions.remove_at(i)
		else:
			i += 1


func _tick_dash(a: Dictionary, delta: float) -> bool:
	if a.has("ticked"):
		var moved := CoreUtil.flat(caster.global_position - (a["last"] as Vector3)).length()
		a["left"] = float(a["left"]) - moved
		if moved < float(a.get("expected", 0.0)) * 0.25:
			a["stuck"] = int(a["stuck"]) + 1
		else:
			a["stuck"] = 0
	a["ticked"] = true
	a["last"] = caster.global_position
	var left := float(a["left"])
	var h: Dictionary = a["hit"]
	if not h.is_empty():
		var hs: Dictionary = a["hit_set"]
		var reach := caster.radius() + float(a["width"])
		for e: Fighter in enemies():
			if hs.has(e.uid):
				continue
			if CoreUtil.flat(e.global_position - caster.global_position).length() - e.radius() <= reach 					and absf(e.center().y - caster.center().y) < 2.0:
				hs[e.uid] = true
				deal(e, h, caster.global_position - (a["dir"] as Vector3))
				if bool(a["stop_on_hit"]):
					caster.skill_velocity = Vector3.ZERO
					caster.ghost = false
					return true
	if left <= 0.01 or int(a["stuck"]) >= 3:
		caster.skill_velocity = Vector3.ZERO
		caster.ghost = false
		return true
	var step_speed := minf(float(a["speed"]), left / maxf(delta, 0.0001))
	caster.skill_velocity = (a["dir"] as Vector3) * step_speed
	a["expected"] = step_speed * delta
	return false


func _tick_leap(a: Dictionary, delta: float) -> bool:
	a["t"] = float(a["t"]) + delta
	var dur := float(a["duration"])
	var k := clampf(float(a["t"]) / dur, 0.0, 1.0)
	var from: Vector3 = a["from"]
	var to: Vector3 = a["to"]
	var pos := from.lerp(to, k) + Vector3(0, 4.0 * float(a["height"]) * k * (1.0 - k), 0)
	caster.global_position = pos
	caster.motion_override = true
	if k < 1.0:
		return false
	var land: Dictionary = a["land"]
	if not land.is_empty():
		var r := pf(land, "radius", 2.5)
		var h := phit(land)
		for e: Fighter in enemies():
			if CoreUtil.flat(e.global_position - to).length() - e.radius() <= r and absf(e.global_position.y - to.y) < 2.5:
				deal(e, h, to)
		CoreUtil.fx(&"play", [StringName(ps(land, "fx", "land_dust")), to, caster.forward(), _color(a["p"]), r / 2.0])
	return true
