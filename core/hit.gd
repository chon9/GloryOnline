class_name Hit
extends RefCounted
## Static helpers for HIT dictionaries (ARCHITECTURE §5.2).

const DEFAULTS: Dictionary = {
	"dmg": 1.0,
	"type": "phys",
	"hitstun": 0.35,
	"launch": 0.0,
	"knockback": 2.0,
	"pull": false,
	"knockdown": false,
	"stun": 0.0,
	"statuses": [],
	"armor_break": false,
	"grab": false,
	"grab_time": 0.0,
	"otg": false,
	"no_recover": false,
	"juggle_cost": 10.0,
	"crit_bonus": 0.0,
	"element": "",
	"true_damage": false,
	"lifesteal": 0.0,
	"threat": 1.0,
}

const _FLOAT_KEYS: Array[String] = ["dmg", "hitstun", "launch", "knockback", "stun", "grab_time",
	"juggle_cost", "crit_bonus", "lifesteal", "threat"]
const _BOOL_KEYS: Array[String] = ["pull", "knockdown", "armor_break", "grab", "otg", "no_recover", "true_damage"]


## Returns a new dictionary with every key from DEFAULTS present and correctly typed.
## Unknown keys are preserved (kits may stash extra data for their hooks). Never crashes on junk.
static func normalize(d: Variant) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	if d is Dictionary:
		if (d as Dictionary).get("_normalized", false):
			return d
		for k: Variant in d:
			out[k] = d[k]
	for k: String in _FLOAT_KEYS:
		var v: Variant = out[k]
		out[k] = float(v) if (v is float or v is int) else float(DEFAULTS[k])
	for k: String in _BOOL_KEYS:
		out[k] = bool(out[k]) if (out[k] is bool or out[k] is int) else false
	var t := str(out["type"])
	out["type"] = "magic" if t == "magic" or t == "mag" else "phys"
	out["element"] = str(out["element"])
	out["statuses"] = CoreUtil.status_list(out["statuses"])
	out["_normalized"] = true
	return out


## Shallow merge of overrides onto a hit, re-normalised.
static func with(hit: Dictionary, overrides: Dictionary) -> Dictionary:
	var d: Dictionary = hit.duplicate(true)
	d.erase("_normalized")
	for k: Variant in overrides:
		d[k] = overrides[k]
	return normalize(d)


static func is_magic(hit: Dictionary) -> bool:
	return str(hit.get("type", "phys")) == "magic"
