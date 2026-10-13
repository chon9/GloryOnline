extends RefCounted
## Shared helpers for the gunner kits (KITS-gunner). Not a ClassKit: the "_" prefix makes Registry skip it.
## Kits preload this script and call the static functions.


## Glory gun recoil (枪械后坐力): firing while airborne pushes the shooter up (and optionally back), so a
## gunner can keep himself floating with a stream of shots ("aerial gun-fu"). Host only.
static func air_recoil(f: Fighter, up: float, back: float, cap: float) -> void:
	if f == null or not is_instance_valid(f) or not f.is_alive():
		return
	if f.is_on_floor() or f.state == Fighter.State.LAUNCHED or f.state == Fighter.State.GRABBED:
		return
	f.velocity.y = minf(maxf(f.velocity.y, 0.0) + up, cap)
	if back > 0.0:
		f.apply_knockback(-f.forward(), back, 0.0)


## True when `victim` frontally blocked this hit from `f`. Uses CORE's `hit["_blocked"]` flag (set on every hit
## passed to on_hit_dealt) and falls back to `Combat.would_block()` for hand-built hit dicts.
static func was_blocked(f: Fighter, victim: Fighter, h: Dictionary) -> bool:
	if h.has("_blocked"):
		return bool(h["_blocked"])
	if victim == null or f == null or not is_instance_valid(f):
		return false
	return Combat.would_block(victim, h, f.global_position)


## Spawns a ground burst / zone (same params as a `ground` step) at an explicit world position through CORE's
## public `SkillRunner.spawn_area()` (clamped to the arena and snapped to the ground first).
## Used for patterned bombardments (flower grenades, stingers, air drops) that `ground` cannot place.
static func burst_at(runner: SkillRunner, pos: Vector3, p: Dictionary) -> AreaEffect:
	if runner == null or runner.caster == null or not is_instance_valid(runner.caster):
		return null
	var w := runner.world()
	if w == null:
		return null
	return runner.spawn_area(p, w.ground_point(w.clamp_to_bounds(pos)), runner.caster.facing_yaw)


## Center of a bombardment: the locked target (within max_dist) or the clamped aim point.
static func strike_center(runner: SkillRunner, max_dist: float) -> Vector3:
	return runner.resolve_point("target", minf(8.0, max_dist), max_dist)


## Deterministic flower pattern: the center plus `petals` points on a circle of radius `r`.
static func flower_points(center: Vector3, petals: int, r: float, phase: float = 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = [center]
	for i in petals:
		var a := phase + TAU * float(i) / float(maxi(1, petals))
		out.append(center + Vector3(sin(a), 0.0, cos(a)) * r)
	return out


## Deterministic spiral pattern (air drops): `n` points spiralling outwards from the center to radius `r`.
static func spiral_points(center: Vector3, n: int, r: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		var k := float(i) / float(maxi(1, n - 1))
		var a := float(i) * 2.399
		out.append(center + Vector3(sin(a), 0.0, cos(a)) * r * k)
	return out


## Restores one charge of `slot` (Sharpshooter Dual Load) through CORE's public `Fighter.restore_charge()`.
## Returns false when the slot has no skill or is already full.
static func restore_charge(f: Fighter, slot: int) -> bool:
	if f == null or f.get_skill(slot) == null:
		return false
	if f.get_charges(slot) >= f.max_charges(slot):
		return false
	f.restore_charge(slot, 1)
	return true
