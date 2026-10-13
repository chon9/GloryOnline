class_name StatusSet
extends RefCounted
## Timed status effects on a Fighter (ARCHITECTURE §4.2). Host-authoritative; clients only see
## Fighter.status_mask (bit i == IDS[i] active).

const IDS: Array[StringName] = [&"stun", &"freeze", &"root", &"silence", &"sleep", &"blind",
	&"confusion", &"taunted", &"slow", &"haste", &"bleed", &"poison", &"burn", &"weight",
	&"super_armor", &"stealth", &"invuln", &"block", &"atk_up", &"def_up", &"def_down",
	&"matk_up", &"regen", &"shield", &"mark", &"atk_down", &"cast_slow"]
## (wave3) atk_down (patk & matk x(1-power)) and cast_slow (cast_speed x(1-power)) are appended at the END so the
## existing status_mask bits never shift.

## Statuses removed by `cleanse` and considered debuffs by AI.
const NEGATIVE: Array[StringName] = [&"stun", &"freeze", &"root", &"silence", &"sleep", &"blind",
	&"confusion", &"taunted", &"slow", &"bleed", &"poison", &"burn", &"weight", &"def_down", &"mark",
	&"atk_down", &"cast_slow"]
## Statuses that prevent acting entirely.
const DISABLING: Array[StringName] = [&"stun", &"freeze", &"sleep"]
const DOTS: Array[StringName] = [&"bleed", &"poison", &"burn"]

const DOT_INTERVAL: float = 1.0

## id -> {dur: remaining s, total: s, power: float, src: Fighter|null, acc: float}
var entries: Dictionary = {}
var owner: Fighter


func _init(f: Fighter = null) -> void:
	owner = f


static func bit_of(id: StringName) -> int:
	var i := IDS.find(id)
	return 0 if i < 0 else (1 << i)


static func is_negative(id: StringName) -> bool:
	return NEGATIVE.has(id)


## Adds or refreshes a status. Re-applying keeps the longer remaining duration and the stronger power;
## the most recent source wins (so a new taunt redirects to the new taunter).
func add(id: StringName, duration: float, power: float = 1.0, src: Fighter = null) -> void:
	if duration <= 0.0:
		return
	if not IDS.has(id):
		CoreUtil.warn_once("status_" + str(id), "StatusSet: unknown status id '%s' (kept, no built-in effect)" % id)
	if entries.has(id):
		var e: Dictionary = entries[id]
		e["dur"] = maxf(float(e["dur"]), duration)
		e["total"] = maxf(float(e["total"]), duration)
		e["power"] = maxf(float(e["power"]), power) if id != &"taunted" else power
		if src != null:
			e["src"] = src
	else:
		entries[id] = {"dur": duration, "total": duration, "power": power, "src": src, "acc": 0.0}


func remove(id: StringName) -> void:
	entries.erase(id)


func has(id: StringName) -> bool:
	return entries.has(id)


func power(id: StringName, default_value: float = 0.0) -> float:
	if not entries.has(id):
		return default_value
	return float(entries[id]["power"])


func remaining(id: StringName) -> float:
	if not entries.has(id):
		return 0.0
	return float(entries[id]["dur"])


func source(id: StringName) -> Fighter:
	if not entries.has(id):
		return null
	var s: Variant = entries[id]["src"]
	if is_instance_valid(s) and s is Fighter:
		return s
	entries[id]["src"] = null  # source was freed; drop the stale reference
	return null


func is_disabled() -> bool:
	for id: StringName in DISABLING:
		if entries.has(id):
			return true
	return false


func clear_negative() -> int:
	var n := 0
	for id: Variant in entries.keys():
		if NEGATIVE.has(id):
			entries.erase(id)
			n += 1
	return n


func clear_all() -> void:
	entries.clear()


func mask() -> int:
	var m := 0
	for id: Variant in entries:
		m |= bit_of(id)
	return m


## Advances timers; applies DoT damage and regen on the owner. Host only.
func tick(delta: float) -> void:
	if entries.is_empty():
		return
	var expired: Array = []
	for id: Variant in entries.keys():
		if not entries.has(id):
			continue  # removed by a side effect (e.g. death) during this loop
		var e: Dictionary = entries[id]
		e["dur"] = float(e["dur"]) - delta
		if owner != null and (DOTS.has(id) or id == &"regen"):
			e["acc"] = float(e["acc"]) + delta
			while float(e["acc"]) >= DOT_INTERVAL:
				e["acc"] = float(e["acc"]) - DOT_INTERVAL
				_apply_periodic(id, e)
		if float(e["dur"]) <= 0.0:
			expired.append(id)
	for id: Variant in expired:
		entries.erase(id)
		if owner != null:
			owner._on_status_expired(id)


func _apply_periodic(id: StringName, e: Dictionary) -> void:
	if owner == null or not owner.is_alive():
		return
	var src: Fighter = null
	var s: Variant = e["src"]
	if is_instance_valid(s) and s is Fighter:
		src = s
	else:
		e["src"] = null  # freed source: keep ticking with the fallback attack value
	var p := float(e["power"])
	if id == &"regen":
		owner.heal(p * owner.max_hp * DOT_INTERVAL, src)
		return
	var atk := 500.0
	if src != null:
		atk = maxf(src.get_stat("patk"), src.get_stat("matk"))
	owner.take_dot_damage(p * atk * 0.1, src, id)
