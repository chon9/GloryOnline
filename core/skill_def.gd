class_name SkillDef
extends RefCounted
## Data definition of a skill (ARCHITECTURE §5). Executed by SkillRunner on the host.

var id: StringName                  # "battle_mage.sky_strike"
var name_cn: String = ""
var name_en: String = ""
var desc: String = ""
var slot: int = 0                   # 0..7
var cooldown: float = 1.0
var mp_cost: float = 0.0
var cast_time: float = 0.0          # total lock duration in CAST
var move_while_casting: bool = false
var cancel_window: float = 0.0      # last N seconds of cast_time may be cancelled into another skill
var anim: StringName = &"attack"
var anim_speed: float = 1.0
@warning_ignore("shadowed_global_identifier")
var range: float = 3.0              # AI hint
var tags: PackedStringArray = PackedStringArray()
var steps: Array[Dictionary] = []
var chain: Array[StringName] = []   # slot 0 press-chain (SkillDef ids)
var charges: int = 1
var requires: Dictionary = {}
var icon: String = ""               # optional, UI may use


## Bilingual display name "中文 English".
func display_name() -> String:
	if name_cn == "":
		return name_en
	if name_en == "":
		return name_cn
	return "%s %s" % [name_cn, name_en]


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_ultimate() -> bool:
	return slot == 7 or tags.has("ultimate")


## Time of the last scheduled step.
func last_step_time() -> float:
	var t := 0.0
	for s: Dictionary in steps:
		t = maxf(t, float(s.get("t", 0.0)))
	return t


## Effective lock duration: never shorter than the last step.
func total_time() -> float:
	return maxf(cast_time, last_step_time())


## Sets a property from a loosely typed value (used by ClassKit.sk extra / mob def parsing).
func apply_extra(extra: Dictionary) -> void:
	for k: Variant in extra:
		var key := str(k)
		var v: Variant = extra[k]
		match key:
			"steps":
				if v is Array:
					set_steps(v)
			"chain":
				chain.clear()
				if v is Array or v is PackedStringArray:
					for c: Variant in v:
						chain.append(StringName(str(c)))
			"tags":
				tags = PackedStringArray(v) if (v is Array or v is PackedStringArray) else PackedStringArray()
			"requires":
				requires = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"anim":
				anim = StringName(str(v))
			"id":
				id = StringName(str(v))
			"charges":
				charges = maxi(1, int(v))
			_:
				if key in self:
					set(key, v)
				else:
					CoreUtil.warn_once("skilldef_extra_" + key, "SkillDef: unknown field '%s' ignored" % key)


func set_steps(arr: Array) -> void:
	# Stable insertion sort by "t" so steps sharing a time keep their authored order.
	steps.clear()
	for s: Variant in arr:
		if not (s is Dictionary):
			continue
		var t := float((s as Dictionary).get("t", 0.0))
		var i := steps.size()
		while i > 0 and float(steps[i - 1].get("t", 0.0)) > t:
			i -= 1
		steps.insert(i, s)


## Builds a SkillDef from a plain dictionary (used for mob/summon defs written as data).
static func from_dict(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	s.apply_extra(d)
	return s
