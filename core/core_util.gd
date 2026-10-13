class_name CoreUtil
extends RefCounted
## Small static helpers shared by core scripts. Autoloads are accessed dynamically so core keeps
## working when an autoload is a stub, missing, or (in headless -s tests) not yet ready.

const LAYER_WORLD: int = 1          # bit value of physics layer 1 (static world)
const LAYER_FIGHTERS: int = 2       # bit value of physics layer 2 (fighters)

static var _warned: Dictionary = {}


static func root() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func autoload(autoload_name: String) -> Node:
	var r := root()
	if r == null:
		return null
	return r.get_node_or_null(autoload_name)


static func registry() -> Node:
	return autoload("Registry")


## Calls a method on the Fx autoload if it exists and implements it. Never errors.
static func fx(method: StringName, args: Array = []) -> void:
	var f := autoload("Fx")
	if f != null and f.has_method(method):
		f.callv(method, args)


## True when Fx is missing or is the CORE stub -> core draws its own debug meshes on the host.
static func fx_is_stub() -> bool:
	var f := autoload("Fx")
	if f == null:
		return true
	var s: Variant = f.get("is_stub")
	return s is bool and s


static func setting(key: String, default_value: Variant) -> Variant:
	var g := autoload("Game")
	if g == null:
		return default_value
	var s: Variant = g.get("settings")
	if s is Dictionary:
		return (s as Dictionary).get(key, default_value)
	return default_value


static func get_kit(kit_id: String) -> ClassKit:
	if kit_id == "":
		return null
	var r := registry()
	if r != null and r.has_method("get_kit"):
		var k: Variant = r.call("get_kit", kit_id)
		if k is ClassKit:
			return k
	return null


static func get_mob_def(mob_id: String) -> Dictionary:
	if mob_id == "":
		return {}
	var r := registry()
	if r != null:
		var defs: Variant = r.get("mob_defs")
		if defs is Dictionary and (defs as Dictionary).has(mob_id):
			var d: Variant = defs[mob_id]
			if d is Dictionary:
				return d
	return {}


## push_warning only the first time a given key is seen (avoids log spam every frame).
static func warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)


static func to_vec3(v: Variant, default_value := Vector3.ZERO) -> Vector3:
	if v is Vector3:
		return v
	if v is Vector2:
		return Vector3((v as Vector2).x, 0.0, (v as Vector2).y)
	return default_value


static func to_color(v: Variant, default_value := Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return default_value


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func flat_dir(v: Vector3, fallback := Vector3.FORWARD) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	if f.length_squared() < 0.000001:
		return fallback
	return f.normalized()


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func dir_of_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Normalises a list of status specs ({id, dur, power}) – accepts Arrays, single dicts, or nothing.
static func status_list(v: Variant) -> Array:
	var out: Array = []
	if v is Dictionary:
		v = [v]
	if not (v is Array):
		return out
	for s: Variant in v:
		if s is Dictionary and (s as Dictionary).has("id"):
			out.append({
				"id": StringName(str(s["id"])),
				"dur": float((s as Dictionary).get("dur", (s as Dictionary).get("duration", 3.0))),
				"power": float((s as Dictionary).get("power", 1.0)),
			})
		elif s is String or s is StringName:
			out.append({"id": StringName(s), "dur": 3.0, "power": 1.0})
	return out
