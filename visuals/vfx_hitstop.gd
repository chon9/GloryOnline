class_name VfxHitStop
extends RefCounted
## Local, cosmetic hit-stop (bible 5.3: light 3 f, medium 5 f, heavy 8 f, ultimate/finisher 12 f).
## Freezes the attacker's and the victim's CharacterVisual animation by deactivating their AnimationMixers for
## N rendered frames (plus a small shake on the victim); VFX keep animating. It never touches Engine.time_scale,
## physics or Fighter state, so the host simulation timing is unchanged; every peer runs it locally from the
## Fx events it already receives.

const FRAMES: Array[int] = [3, 5, 8, 12]

var _frozen: Dictionary = {}   # instance id -> {node, frames, mixers, jitter, base, shake_i}


static func frames_for(level: int) -> int:
	return FRAMES[clampi(level, 1, 4) - 1]


## Freezes `visual` for `frames` rendered frames (extends an ongoing freeze). jitter = victim shake in metres.
func freeze(visual: Node3D, frames: int, jitter := 0.0) -> void:
	if visual == null or not is_instance_valid(visual) or not visual.is_inside_tree() or frames <= 0:
		return
	var id := visual.get_instance_id()
	if _frozen.has(id):
		var e: Dictionary = _frozen[id]
		e["frames"] = maxi(int(e["frames"]), frames)
		e["jitter"] = maxf(float(e["jitter"]), jitter)
		return
	var mixers: Array = []
	for m in visual.find_children("*", "AnimationMixer", true, false):
		var am := m as AnimationMixer
		if am.active:
			am.active = false
			mixers.append(weakref(am))
	_frozen[id] = {"node": weakref(visual), "frames": frames, "mixers": mixers, "jitter": jitter,
		"base": visual.position, "shake_i": 0}


## Call once per rendered frame.
func tick() -> void:
	if _frozen.is_empty():
		return
	for id in _frozen.keys():
		var e: Dictionary = _frozen[id]
		var n: Node3D = (e["node"] as WeakRef).get_ref() as Node3D
		if n == null or not is_instance_valid(n):
			_frozen.erase(id)
			continue
		e["frames"] = int(e["frames"]) - 1
		var j := float(e["jitter"])
		if int(e["frames"]) <= 0:
			_release(e, n)
			_frozen.erase(id)
		elif j > 0.0:
			var i := int(e["shake_i"]) + 1
			e["shake_i"] = i
			var amp := j * clampf(float(e["frames"]) / 6.0, 0.25, 1.0)
			n.position = (e["base"] as Vector3) + Vector3(amp if i % 2 == 0 else -amp, 0.0, 0.0)


func is_frozen(visual: Node) -> bool:
	return visual != null and _frozen.has(visual.get_instance_id())


func count() -> int:
	return _frozen.size()


func release_all() -> void:
	for id in _frozen.keys():
		var e: Dictionary = _frozen[id]
		var n: Node3D = (e["node"] as WeakRef).get_ref() as Node3D
		if n != null and is_instance_valid(n):
			_release(e, n)
	_frozen.clear()


func _release(e: Dictionary, n: Node3D) -> void:
	for w: WeakRef in e["mixers"]:
		var am := w.get_ref() as AnimationMixer
		if am != null and is_instance_valid(am):
			am.active = true
	if float(e["jitter"]) > 0.0:
		n.position = e["base"]
