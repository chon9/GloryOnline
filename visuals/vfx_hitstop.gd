class_name VfxHitStop
extends RefCounted
## Local cosmetic hit-stop, measured in seconds using a 60 Hz reference.
## Freezes the attacker's and the victim's CharacterVisual animation by deactivating their AnimationMixers for
## a short duration (plus a small shake on the victim); VFX keep animating. It never touches Engine.time_scale,
## physics or Fighter state, so the host simulation timing is unchanged; every peer runs it locally from the
## Fx events it already receives.

const FRAMES: Array[int] = [2, 3, 5, 8]

var _frozen: Dictionary = {}   # instance id -> {node, remaining, mixers, jitter, base, shake_i}


static func frames_for(level: int) -> int:
	return FRAMES[clampi(level, 1, 4) - 1]


## `frames` is a 60 Hz reference duration, independent of render FPS. jitter is in metres.
func freeze(visual: Node3D, frames: int, jitter := 0.0) -> void:
	if visual == null or not is_instance_valid(visual) or not visual.is_inside_tree() or frames <= 0:
		return
	var id := visual.get_instance_id()
	if _frozen.has(id):
		var e: Dictionary = _frozen[id]
		e["remaining"] = maxf(float(e["remaining"]), frames / 60.0)
		e["jitter"] = maxf(float(e["jitter"]), jitter)
		return
	var mixers: Array = []
	for m in visual.find_children("*", "AnimationMixer", true, false):
		var am := m as AnimationMixer
		if am.active:
			am.active = false
			mixers.append(weakref(am))
	_frozen[id] = {"node": weakref(visual), "remaining": frames / 60.0, "mixers": mixers, "jitter": jitter,
		"base": visual.position, "shake_i": 0}


## Call once per rendered frame.
func tick(delta: float = 1.0 / 60.0) -> void:
	if _frozen.is_empty():
		return
	for id in _frozen.keys():
		var e: Dictionary = _frozen[id]
		var n: Node3D = (e["node"] as WeakRef).get_ref() as Node3D
		if n == null or not is_instance_valid(n):
			_frozen.erase(id)
			continue
		e["remaining"] = float(e["remaining"]) - maxf(delta, 0.0)
		var j := float(e["jitter"])
		if float(e["remaining"]) <= 0.00001:
			_release(e, n)
			_frozen.erase(id)
		elif j > 0.0:
			var i := int(e["shake_i"]) + 1
			e["shake_i"] = i
			var amp := j * clampf(float(e["remaining"]) / 0.1, 0.25, 1.0)
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
