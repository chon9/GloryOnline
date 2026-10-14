extends "res://tests/test_core_base.gd"
## Feel tests: Shift tap = dodge / hold = sprint (PlayerController detection, Fighter dodge distance / i-frames /
## cooldown / Glory lockouts, sprint speed, FighterInput wire format, bot telegraph dodge) and the movement jitter
## regression (deterministic sim: no facing / speed oscillation; host render interpolation is smooth at 165 Hz).


func run_tests() -> void:
	suite_name = "feel"
	t_tap_hold_detection()
	t_input_wire()
	await new_world()
	await t_dodge_distance_invuln_cooldown()
	await t_dodge_lockouts()
	await t_sprint()
	await t_bot_dodge()
	await t_jitter_regression()


# ------------------------------------------------------------------ helpers
func _fresh(pos: Vector3, yaw: float = 0.0, team: int = 0) -> Fighter:
	var f := spawn(team, pos, yaw)
	return f


func _settle() -> void:
	await sim(0.3)


func _clear_world() -> void:
	for f: Fighter in world.fighters.duplicate():
		if is_instance_valid(f):
			f.get_parent().remove_child(f)
			f.free()
	await physics_frame


# ------------------------------------------------------------------ tests
func t_tap_hold_detection() -> void:
	var pc := PlayerController.new()
	var dt := 1.0 / 60.0
	# quick tap: held 6 frames (0.1 s)
	var taps := 0
	var sprinted := false
	taps += int(pc.feed_dodge_key(true, true, dt))
	for i in 5:
		taps += int(pc.feed_dodge_key(true, false, dt))
		sprinted = sprinted or pc.is_sprint_held()
	taps += int(pc.feed_dodge_key(false, false, dt))
	check(taps == 1 and not sprinted, "tap (0.1 s) = one dodge, no sprint", "taps=%d sprint=%s" % [taps, sprinted])
	# hold 0.5 s: sprint after 0.2 s, no dodge on release
	taps = 0
	var sprint_frame := -1
	taps += int(pc.feed_dodge_key(true, true, dt))
	for i in 30:
		taps += int(pc.feed_dodge_key(true, false, dt))
		if sprint_frame < 0 and pc.is_sprint_held():
			sprint_frame = i + 1
	taps += int(pc.feed_dodge_key(false, false, dt))
	check(taps == 0, "hold (0.5 s) never dodges", "taps=%d" % taps)
	check(sprint_frame >= 12 and sprint_frame <= 14, "hold sprints after ~0.2 s", "frame=%d" % sprint_frame)
	check(not pc.is_sprint_held(), "release stops sprint")
	# press + release inside one physics frame
	check(pc.feed_dodge_key(false, true, dt), "sub-frame tap still dodges")
	# exactly at the threshold boundary: 0.25 s is a hold
	taps = int(pc.feed_dodge_key(true, true, dt))
	for i in 15:
		taps += int(pc.feed_dodge_key(true, false, dt))
	taps += int(pc.feed_dodge_key(false, false, dt))
	check(taps == 0, "0.25 s press is a hold, not a tap", "taps=%d" % taps)
	pc.free()
	# InputMap: Game registers dodge_sprint on Shift (left and right)
	check(InputMap.has_action("dodge_sprint"), "InputMap has dodge_sprint")
	if InputMap.has_action("dodge_sprint"):
		for loc: KeyLocation in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT]:
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_SHIFT
			ev.keycode = KEY_SHIFT
			ev.location = loc
			ev.pressed = true
			check(InputMap.event_is_action(ev, "dodge_sprint"), "Shift location %d triggers dodge_sprint" % loc)
	check(InputMap.has_action("dodge") and InputMap.action_get_events("dodge").size() >= 2,
		"InputMap has a dedicated press-to-dodge action (Alt / mouse thumb)")


func t_input_wire() -> void:
	var a := FighterInput.new()
	a.move = Vector3(0.6, 0.0, -0.8)
	a.press(0)
	a.press(14)
	a.jump = true
	a.dodge = true
	a.sprint = true
	a.held = 0b101
	a.press_id = 7
	var b := FighterInput.from_dict(a.to_dict())
	check(b.dodge and b.sprint and b.jump, "dodge / sprint / jump survive the RPC dict")
	check(b.pressed == a.pressed and b.held == 0b101, "skill bits unaffected by dodge/sprint bits",
		"p=%d h=%d" % [b.pressed, b.held])
	var c := FighterInput.from_dict({"m": Vector2(1, 0), "p": 3, "h": 2, "i": 1})
	check(not c.dodge and not c.sprint and c.pressed == 3 and c.held == 2, "old packets decode without dodge/sprint")
	b.clear_edges()
	check(not b.dodge and b.sprint, "clear_edges clears dodge, keeps sprint")


func t_dodge_distance_invuln_cooldown() -> void:
	await _clear_world()
	var f := _fresh(Vector3(0, 0.1, 0))
	await _settle()
	var p0 := f.global_position
	var inp := FighterInput.new()
	inp.move = Vector3.RIGHT
	inp.dodge = true
	inp.press_id = 1
	f.apply_input(inp)
	await sim(DT)
	check(f.state == Fighter.State.DODGE, "tap starts a dodge", f.state_name())
	check(f.has_status(&"invuln") and not f.is_hittable(), "dodge grants i-frames")
	var still := FighterInput.new()
	still.press_id = 1
	f.apply_input(still)
	await sim(0.12)
	check(f.has_status(&"invuln"), "still invulnerable at 0.13 s")
	await sim(0.1)
	check(not f.has_status(&"invuln"), "i-frames over by 0.23 s")
	await sim(0.2)
	check(f.state == Fighter.State.IDLE, "dodge ends in IDLE", f.state_name())
	var d := f.global_position - p0
	check(approx(d.x, Fighter.DODGE_DISTANCE, 0.1) and absf(d.z) < 0.05, "dodge covers %.1f m along the move direction" % Fighter.DODGE_DISTANCE,
		"d=%s" % d)
	check(approx(f.facing_yaw, CoreUtil.yaw_of(Vector3.RIGHT), 0.01), "body turns into the roll")
	check(f.dodge_cd > 0.0 and f.dodge_block_reason() == "cooldown", "cooldown after dodge", "cd=%.2f" % f.dodge_cd)
	await sim(Fighter.DODGE_COOLDOWN - 0.42 - DT + 0.05)
	check(f.dodge_block_reason() == "" and f.dodge_cd == 0.0, "dodge ready again after %.1f s" % Fighter.DODGE_COOLDOWN,
		f.dodge_block_reason())
	# backstep: no direction -> straight back, facing kept
	var yaw0 := f.facing_yaw
	var p1 := f.global_position
	var back := FighterInput.new()
	back.dodge = true
	back.press_id = 2
	f.apply_input(back)
	await sim(0.4)
	var bd := f.global_position - p1
	check(approx(bd.dot(-CoreUtil.dir_of_yaw(yaw0)), Fighter.DODGE_DISTANCE, 0.1) and approx(f.facing_yaw, yaw0, 0.01),
		"no direction = backstep, facing kept", "d=%s" % bd)
	check(f.anim_key == &"idle" or f.anim_key == &"backstep", "backstep anim key", str(f.anim_key))
	# resent packet with the same press_id does not dodge twice
	await sim(1.3)
	var r := FighterInput.new()
	r.dodge = true
	r.press_id = 3
	f.apply_input(r)
	await sim(DT)
	await sim(0.35)
	f.apply_input(r)
	await sim(DT)
	check(f.state != Fighter.State.DODGE and f.dodge_cd > 0.5, "resent press_id is not a second dodge", f.state_name())


func t_dodge_lockouts() -> void:
	await _clear_world()
	var f := _fresh(Vector3(0, 0.1, 0))
	var e := _fresh(Vector3(0, 0.1, -2.0), PI, 1)
	await _settle()
	# hitstun
	f.receive_hit(e, {"dmg": 0.05, "hitstun": 0.5, "knockback": 0.0}, e.global_position)
	check(f.state == Fighter.State.HITSTUN, "setup: hitstun", f.state_name())
	check(f.dodge_block_reason() == "busy" and not f.try_dodge(Vector3.RIGHT), "cannot dodge out of hitstun")
	await sim(0.8)
	# stun status
	f.add_status(&"stun", 0.4)
	check(f.dodge_block_reason() == "busy", "cannot dodge while stunned", f.dodge_block_reason())
	await sim(0.6)
	# launch / knockdown
	f.receive_hit(e, {"dmg": 0.05, "launch": 8.0}, e.global_position)
	await sim(0.1)
	check(not f.try_dodge(Vector3.RIGHT), "cannot dodge while launched", f.state_name())
	await sim_until(func() -> bool: return f.state == Fighter.State.KNOCKDOWN, 2.0)
	check(not f.try_dodge(Vector3.RIGHT), "cannot dodge while knocked down (quick recovery is the escape)")
	await sim(2.0)
	# basic attack recovery can be dodge-cancelled; another skill cannot
	check(f.try_cast(0), "setup: basic attack")
	check(f.state == Fighter.State.CAST and f.dodge_block_reason() == "", "basic attack can be dodge-cancelled",
		f.dodge_block_reason())
	check(f.try_dodge(Vector3.LEFT) and f.cast_slot == -1 and f.runner == null, "dodge cancels the basic attack")
	await sim(1.5)
	check(f.try_cast(3), "setup: slot 3 skill")
	check(f.dodge_block_reason() == "busy", "a non-basic skill cannot be dodge-cancelled", f.dodge_block_reason())
	await sim(2.5)
	# rooted / airborne
	f.add_status(&"root", 0.3)
	check(f.dodge_block_reason() == "rooted", "root blocks the dodge", f.dodge_block_reason())
	await sim(0.5)
	f.input.jump = true
	await sim(0.1)
	check(f.dodge_block_reason() == "airborne", "no air dodge", f.dodge_block_reason())
	await sim(1.5)
	# hit during the dodge after the i-frames: normal reactions, the dodge ends
	check(f.try_dodge(Vector3.RIGHT), "setup: dodge")
	await sim(0.22)
	f.receive_hit(e, {"dmg": 0.05, "hitstun": 0.3}, e.global_position)
	check(f.state == Fighter.State.HITSTUN, "late hit interrupts the dodge (i-frames are 0.2 s)", f.state_name())
	await sim(1.5)
	# mobs (no kit) never dodge
	var m := world.spawn_fighter({"kind": "mob", "mob_id": "__none__", "team": 1, "pos": Vector3(5, 0.1, 5)})
	await sim(0.2)
	check(m.dodge_block_reason() == "no_kit", "kit-less mobs do not dodge", m.dodge_block_reason())


func t_sprint() -> void:
	await _clear_world()
	var f := _fresh(Vector3(-20, 0.1, 0))
	var e := _fresh(Vector3(20, 0.1, 20), 0.0, 1)
	await _settle()
	var speeds := {}
	for mode: String in ["run", "sprint", "sprint_slowed"]:
		if mode == "sprint_slowed":
			f.add_status(&"slow", 5.0, 0.5)
		var inp := FighterInput.new()
		inp.move = Vector3.RIGHT
		inp.sprint = mode != "run"
		f.apply_input(inp)
		await sim(0.3)
		var x0 := f.global_position.x
		await sim(0.5)
		speeds[mode] = (f.global_position.x - x0) / 0.5
		if mode == "sprint":
			check(f.is_sprinting() and f.anim_key == &"sprint", "sprinting uses the sprint anim", str(f.anim_key))
		f.global_position = Vector3(-20, 0.1, 0)
		await sim(DT)
	f.remove_status(&"slow")
	check(approx(speeds["run"], 6.0, 0.15), "run speed 6 m/s", str(speeds["run"]))
	check(approx(speeds["sprint"], 6.0 * Fighter.SPRINT_MULT, 0.2), "sprint x%.1f" % Fighter.SPRINT_MULT, str(speeds["sprint"]))
	check(approx(speeds["sprint_slowed"], 6.0 * Fighter.SPRINT_MULT * 0.5, 0.2), "slow still applies while sprinting",
		str(speeds["sprint_slowed"]))
	# no sprint while standing, right after a hit, or while casting
	var stand := FighterInput.new()
	stand.sprint = true
	f.apply_input(stand)
	await sim(0.1)
	check(not f.is_sprinting(), "holding Shift without moving does not sprint")
	var go := FighterInput.new()
	go.move = Vector3.RIGHT
	go.sprint = true
	f.apply_input(go)
	await sim(0.1)
	f.receive_hit(e, {"dmg": 0.01, "hitstun": 0.05, "knockback": 0.0}, f.global_position + Vector3.LEFT)
	await sim(0.3)
	check(not f.is_sprinting(), "no sprinting for %.1f s after a hit" % Fighter.SPRINT_HIT_LOCK)
	await sim(1.0)
	check(f.is_sprinting(), "sprint resumes after the hit lock")
	f.try_cast(0)
	await sim(DT)
	check(not f.is_sprinting(), "casting stops the sprint")
	f.apply_input(FighterInput.new())
	await sim(1.0)


func t_bot_dodge() -> void:
	await _clear_world()
	var f := _fresh(Vector3(0, 0.1, 0))
	await _settle()
	var brain: Node = (load("res://ai/bot_brain.gd") as Script).new()
	brain.set("fighter", f)
	brain.call("set_difficulty", 3)
	brain.set("_ready_done", true)
	brain.set("_dodge_urgency", 0.35)
	brain.call("_try_escape_to", Vector3(3.5, 0, 0))
	check(f.input.dodge, "hard bot rolls out of a telegraph it cannot walk out of")
	await sim(0.5)
	check(f.global_position.x > 3.5, "bot dodge moved it out", str(f.global_position))
	brain.call("set_difficulty", 0)
	f.input.dodge = false
	await sim(1.5)
	brain.call("_try_escape_to", Vector3(7.0, 0, 0))
	check(not f.input.dodge, "easy bot does not dodge-roll")
	brain.free()


## Jitter regression: camera-relative strafe / diagonal input in a deterministic sim must give a constant per-tick
## step and a settled facing (no oscillation), and the host's drawn position (render_position) sampled at a 165 Hz
## render rate must move smoothly while the raw 60 Hz physics position saw-tooths.
func t_jitter_regression() -> void:
	await _clear_world()
	var f := _fresh(Vector3(-15, 0.1, -15))
	await _settle()
	var cam_yaw := 0.3
	var fwd := CoreUtil.dir_of_yaw(cam_yaw)
	var rgt := fwd.cross(Vector3.UP)
	var dirs := {"W": Vector2(0, -1), "A": Vector2(-1, 0), "D": Vector2(1, 0), "WA": Vector2(-1, -1).normalized(),
		"WD": Vector2(1, -1).normalized()}
	for name: String in dirs:
		var v: Vector2 = dirs[name]
		f.global_position = Vector3(-10, 0.1, -10)
		var inp := FighterInput.new()
		inp.move = (rgt * v.x - fwd * v.y).limit_length(1.0)
		f.apply_input(inp)
		await sim(0.4)                          # turn settles
		await physics_frame
		var steps: Array[float] = []
		var flips := 0
		var last_dyaw := 0.0
		var prev := f.global_position
		var yaw_prev := f.facing_yaw
		for i in 60:
			world.step(DT)
			steps.append(CoreUtil.flat(f.global_position - prev).length())
			prev = f.global_position
			var dy := angle_difference(yaw_prev, f.facing_yaw)
			if absf(dy) > 0.0001 and absf(last_dyaw) > 0.0001 and signf(dy) != signf(last_dyaw):
				flips += 1
			if absf(dy) > 0.0001:
				last_dyaw = dy
			yaw_prev = f.facing_yaw
		var mean := 0.0
		for s: float in steps:
			mean += s
		mean /= steps.size()
		var var_sum := 0.0
		for s: float in steps:
			var_sum += (s - mean) * (s - mean)
		var cv := sqrt(var_sum / steps.size()) / maxf(mean, 0.0001)
		check(cv < 0.01 and flips == 0 and approx(mean, 0.1, 0.003),
			"%s: constant step, no facing oscillation" % name, "cv=%.4f flips=%d mean=%.4f" % [cv, flips, mean])
		# Render-rate sampling (165 Hz) of the drawn position vs the raw physics position.
		var acc := 0.0
		var rdt := 1.0 / 165.0
		var drawn: Array[Vector3] = []
		var raw: Array[Vector3] = []
		for k in 165:
			acc += rdt
			while acc >= DT:
				acc -= DT
				world.step(DT)
			drawn.append(f.render_position(acc / DT))
			raw.append(f.global_position)
		var j_drawn := _jerk_rms(drawn)
		var j_raw := _jerk_rms(raw)
		check(j_drawn < 0.002 and j_raw > 0.02, "%s: drawn position smooth at 165 Hz (render interpolation)" % name,
			"drawn=%.4f m raw=%.4f m" % [j_drawn, j_raw])
	# teleports are not smoothed
	f.global_position = Vector3(10, 0.1, 10)
	check(f.render_offset(0.0) == Vector3.ZERO, "moved outside a tick: no interpolation offset")
	world.step(DT)
	check(f.render_offset(0.0).length() < 0.2, "teleport tick restarts the interpolation", str(f.render_offset(0.0)))
	f.apply_input(FighterInput.new())


func _jerk_rms(pts: Array[Vector3]) -> float:
	var s := 0.0
	var n := 0
	for i in range(1, pts.size() - 1):
		var j := pts[i + 1] - pts[i] * 2.0 + pts[i - 1]
		s += j.length_squared()
		n += 1
	return sqrt(s / maxf(1.0, float(n)))
