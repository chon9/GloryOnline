extends RefCounted
## Shared helpers for the mage kits (KITS-mage). Not a ClassKit: the "_" prefix makes Registry skip it.
## Kits are shared by every fighter of that class, so per-fighter state lives in Fighter metadata.


## Per-fighter scratch value (stored as Fighter metadata, key "mage_<key>").
static func getv(f: Fighter, key: String, def: Variant) -> Variant:
	var k := StringName("mage_" + key)
	return f.get_meta(k) if f.has_meta(k) else def


static func setv(f: Fighter, key: String, v: Variant) -> void:
	f.set_meta(StringName("mage_" + key), v)


## Hittable enemies of `f` inside a frontal cone (range in m, arc in degrees), nearest first.
static func cone_targets(runner: SkillRunner, rng: float, arc: float, height := 2.5) -> Array[Fighter]:
	var f := runner.caster
	var out: Array[Fighter] = []
	var fwd := f.forward()
	for e: Fighter in runner.enemies():
		if absf(e.center().y - f.center().y) > height + e.height() * 0.5:
			continue
		var to := CoreUtil.flat(e.global_position - f.global_position)
		var d := to.length()
		if d - e.radius() > rng:
			continue
		if d > 0.7 and rad_to_deg(fwd.angle_to(to / d)) > arc * 0.5:
			continue
		out.append(e)
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.global_position.distance_squared_to(f.global_position) < b.global_position.distance_squared_to(f.global_position))
	return out


## Instant burst at an explicit position: deals `hit` to every hittable enemy within `radius` and plays `fx`.
static func burst_at(runner: SkillRunner, pos: Vector3, radius: float, hit: Dictionary, fx: StringName, color: Color) -> int:
	var n := 0
	for e: Fighter in runner.enemies():
		if CoreUtil.flat(e.global_position - pos).length() - e.radius() <= radius and absf(e.global_position.y - pos.y) < 3.0:
			runner.deal(e, Hit.normalize(hit), pos)
			n += 1
	CoreUtil.fx(&"play", [fx, pos + Vector3(0, 0.5, 0), Vector3.UP, color, radius / 2.0])
	return n


## Spawns a persistent / delayed ground area (same params as a `ground` step) at an explicit position, through
## CORE's public `SkillRunner.spawn_area()` (clamped to the arena and snapped to the ground first).
static func area_at(runner: SkillRunner, pos: Vector3, p: Dictionary) -> AreaEffect:
	var w := runner.world()
	if w == null:
		return null
	return runner.spawn_area(p, w.ground_point(w.clamp_to_bounds(pos)), runner.caster.facing_yaw)
