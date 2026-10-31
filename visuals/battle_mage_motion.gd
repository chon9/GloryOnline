extends RefCounted
## Original spear choreography, authored in skeleton space (+Z forward).
## Times are gameplay contact times, not rescaled generic sword clips. Two-bone
## arm/leg solves keep the hands on the shaft and the feet under the weight shift.

const LENGTHS := {"bm_guard": 1.6, "bm_thrust": 0.32, "bm_sweep": 0.32,
	"bm_finish": 0.5, "bm_sky": 0.45, "bm_tooth": 0.35, "bm_palm": 0.45,
	"bm_circle": 0.8, "bm_pierce": 0.5, "bm_charge": 0.7, "bm_dragon": 1.8}
const ACTIVE := {"bm_thrust": Vector2(0.07, 0.17), "bm_sweep": Vector2(0.06, 0.19),
	"bm_finish": Vector2(0.09, 0.22), "bm_sky": Vector2(0.06, 0.23),
	"bm_tooth": Vector2(0.07, 0.17), "bm_circle": Vector2(0.18, 0.57),
	"bm_pierce": Vector2(0.12, 0.28), "bm_charge": Vector2(0.05, 0.42),
	"bm_dragon": Vector2(0.56, 0.78)}

var sk: Skeleton3D
var base: Array[Transform3D] = []
var poses: Array[Transform3D] = []

func build(skeleton: Skeleton3D) -> AnimationLibrary:
	sk = skeleton
	for i in sk.get_bone_count():
		var rest := sk.get_bone_rest(i)
		rest.basis = rest.basis.scaled_local(sk.get_bone_pose_scale(i))
		base.append(rest)
	var library := AnimationLibrary.new()
	for key: String in LENGTHS:
		var anim := Animation.new()
		anim.length = LENGTHS[key]
		if key == "bm_guard":
			anim.loop_mode = Animation.LOOP_LINEAR
		for i in base.size():
			_track(anim, Animation.TYPE_ROTATION_3D, NodePath("GeneralSkeleton:" + sk.get_bone_name(i)))
		var hips_track := _track(anim, Animation.TYPE_POSITION_3D, NodePath("GeneralSkeleton:Hips"))
		var weapon_samples: Array[Transform3D] = []
		var frames := ceili(anim.length * 120.0)
		for frame in frames + 1:
			var t := minf(frame / 120.0, anim.length)
			var weapon := _pose(key, t)
			for i in base.size():
				anim.rotation_track_insert_key(i, t, poses[i].basis.get_rotation_quaternion())
			anim.position_track_insert_key(hips_track, t, poses[sk.find_bone("Hips")].origin)
			var hand := _global(sk.find_bone("RightHand"))
			var local := hand.affine_inverse() * weapon
			weapon_samples.append(local)
		anim.set_meta("weapon_samples", weapon_samples)
		library.add_animation(StringName(key), anim)
	return library

func _track(anim: Animation, type: Animation.TrackType, path: NodePath) -> int:
	var i := anim.add_track(type)
	anim.track_set_path(i, path)
	return i

## [time, shaft yaw, shaft pitch, grip forward, torso yaw, crouch, palm extension]
func keys(key: String) -> Array:
	var guard := [0.0, 28.0, 7.0, -0.10, -12.0, 0.09, 0.0]
	var end: Array = guard.duplicate()
	end[0] = LENGTHS[key]
	match key:
		"bm_thrust": return [guard, [0.065, 22, 4, -0.22, -26, 0.12, 0], [0.12, 0, 2, 0.16, 12, 0.14, 0], [0.17, 0, 2, 0.16, 12, 0.14, 0], end]
		"bm_sweep": return [guard, [0.06, -60, 6, -0.06, -36, 0.13, 0], [0.12, 0, 4, 0.07, 0, 0.16, 0], [0.19, 64, 8, -0.03, 34, 0.13, 0], end]
		"bm_finish": return [guard, [0.09, 12, 0, -0.23, -30, 0.16, 0], [0.15, 0, 0, 0.22, 20, 0.18, 0], [0.23, 0, 0, 0.22, 20, 0.18, 0], end]
		"bm_sky": return [guard, [0.06, -12, -32, -0.08, -28, 0.22, 0], [0.12, 0, 14, 0.05, 8, 0.12, 0], [0.23, 8, 62, 0.02, 22, 0.03, 0], end]
		"bm_tooth": return [guard, [0.07, 4, -2, -0.25, -32, 0.13, 0], [0.12, 0, 0, 0.20, 18, 0.17, 0], [0.155, 0, 0, 0.20, 18, 0.17, 0], [0.24, 18, 3, -0.17, -18, 0.10, 0], end]
		"bm_palm": return [guard, [0.08, -75, 66, -0.15, 25, 0.16, 0.1], [0.15, -80, 70, -0.16, -22, 0.18, 1], [0.24, -80, 70, -0.16, -22, 0.18, 1], end]
		"bm_circle": return [guard, [0.12, 0, 0, 0.15, 15, 0.17, 0], [0.23, -34, 47, 0.0, -25, 0.08, 0], [0.36, -115, 65, -0.10, -70, 0.04, 0], [0.47, -200, 34, -0.08, -105, 0.12, 0], [0.56, -250, -24, 0.0, -70, 0.24, 0], end]
		"bm_pierce": return [guard, [0.12, 2, 0, -0.25, -36, 0.20, 0], [0.20, 0, 0, 0.23, 22, 0.22, 0], [0.28, 0, 0, 0.23, 22, 0.22, 0], end]
		"bm_charge": return [guard, [0.05, 0, 0, 0.05, -12, 0.23, 0], [0.40, 0, 0, 0.05, -12, 0.23, 0], [0.5, 14, 10, 0.0, 8, 0.25, 0], end]
		"bm_dragon": return [guard, [0.25, -60, 28, -0.24, -40, 0.19, 0], [0.55, -20, 5, -0.25, -38, 0.22, 0], [0.68, 0, 6, 0.23, 24, 0.23, 0], [0.93, 0, 16, 0.23, 24, 0.17, 0], [1.3, 8, 26, 0.03, 5, 0.12, 0], end]
	return [guard, [0.8, 29, 8, -0.10, -12, 0.08, 0], end]

func _pose(key: String, t: float) -> Transform3D:
	poses = base.duplicate()
	var timeline := keys(key)
	var row: Array = timeline[0].duplicate()
	for j in range(1, timeline.size()):
		var a: Array = timeline[j - 1]
		var b: Array = timeline[j]
		if t <= float(b[0]) + 0.00001:
			var u := clampf((t - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			for k in range(1, row.size()):
				row[k] = lerpf(float(a[k]), float(b[k]), u)
			break
	var yaw := deg_to_rad(float(row[1]))
	var pitch := deg_to_rad(float(row[2]))
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var hip := sk.find_bone("Hips")
	poses[hip].origin += Vector3(0, -float(row[5]), maxf(0.0, float(row[3])) * 0.45)
	poses[hip].basis = Basis(Vector3.UP, deg_to_rad(float(row[4]) * 0.45)) * base[hip].basis
	var chest := sk.find_bone("Chest")
	poses[chest].basis = base[chest].basis * Basis(Vector3.UP, deg_to_rad(float(row[4]) * 0.55)) * Basis(Vector3.RIGHT, 0.06 + float(row[5]) * 0.25)
	# Legs brace on opposite sides of the thrust line, with a forward lead foot.
	_limb("RightUpperLeg", "RightLowerLeg", "RightFoot", Vector3(-0.18, 0.12, -0.19), Vector3(0, 0, 1), sk.get_bone_global_rest(sk.find_bone("RightFoot")).basis)
	_limb("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", Vector3(0.18, 0.12, 0.25), Vector3(0, 0, 1), sk.get_bone_global_rest(sk.find_bone("LeftFoot")).basis)
	var origin := Vector3(-0.21, 1.28 - float(row[5]) * 0.3, float(row[3]))
	var right_basis := _hand_basis(direction, false)
	var left_basis := _hand_basis(direction, true)
	var right_target := origin - right_basis.y * 0.075
	var left_target := origin + direction * 0.30 - left_basis.y * 0.075
	var palm := float(row[6])
	if palm > 0:
		left_basis = left_basis.slerp(Basis(Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1)), palm)
		left_target = left_target.lerp(Vector3(0.17, 1.40 - float(row[5]), 0.47), palm)
	_limb("RightUpperArm", "RightLowerArm", "RightHand", right_target, Vector3(-1, -0.6, -0.1), right_basis)
	_limb("LeftUpperArm", "LeftLowerArm", "LeftHand", left_target, Vector3(1, -0.6, -0.1), left_basis)
	# Grip fingers; the off-hand releases and opens for the palm strike.
	for i in base.size():
		var n := String(sk.get_bone_name(i))
		if "Thumb" in n or not ("Index" in n or "Middle" in n or "Ring" in n or "Little" in n):
			continue
		var curl := 0.95 * (1.0 - palm if n.begins_with("Left") else 1.0)
		poses[i].basis = base[i].basis * Basis(Vector3.RIGHT, curl)
	# Anchor to the solved rear palm; unreachable poses cannot detach the weapon.
	var right := _global(sk.find_bone("RightHand"))
	origin = right.origin + right.basis.y * 0.075
	var x := Vector3.UP.cross(direction).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT
	return Transform3D(Basis(x, direction, x.cross(direction)).orthonormalized(), origin)

func _hand_basis(direction: Vector3, left: bool) -> Basis:
	var x := direction * (-1.0 if left else 1.0)
	var y := (Vector3.DOWN - x * Vector3.DOWN.dot(x)).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()

func _global(index: int) -> Transform3D:
	var parent := sk.get_bone_parent(index)
	return poses[index] if parent < 0 else _global(parent) * poses[index]

func _set_basis(index: int, basis: Basis) -> void:
	var parent := sk.get_bone_parent(index)
	var parent_basis := Basis.IDENTITY if parent < 0 else _global(parent).basis
	poses[index].basis = (parent_basis.inverse() * basis).orthonormalized().scaled_local(base[index].basis.get_scale())

func _limb(upper_name: String, lower_name: String, end_name: String, target: Vector3, pole: Vector3, end_basis: Basis) -> void:
	var upper := sk.find_bone(upper_name)
	var lower := sk.find_bone(lower_name)
	var end := sk.find_bone(end_name)
	var a := _global(upper)
	var b := _global(lower)
	var c := _global(end)
	var l1 := a.origin.distance_to(b.origin)
	var l2 := b.origin.distance_to(c.origin)
	var axis := (target - a.origin).normalized()
	var distance := clampf(target.distance_to(a.origin), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var along := (l1 * l1 + distance * distance - l2 * l2) / (2.0 * distance)
	var bend := (pole - axis * pole.dot(axis)).normalized()
	var elbow := a.origin + axis * along + bend * sqrt(maxf(0.0, l1 * l1 - along * along))
	_set_basis(upper, Basis(Quaternion((b.origin - a.origin).normalized(), (elbow - a.origin).normalized())) * a.basis)
	b = _global(lower)
	c = _global(end)
	_set_basis(lower, Basis(Quaternion((c.origin - b.origin).normalized(), (a.origin + axis * distance - b.origin).normalized())) * b.basis)
	_set_basis(end, end_basis)
