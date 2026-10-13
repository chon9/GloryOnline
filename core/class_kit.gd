class_name ClassKit
extends RefCounted
## Base class for every class kit (classes/**/*.gd). Subclasses override define() and fill fields.
## All hooks run on the host only.

const DEFAULT_STATS: Dictionary = {
	"hp": 7000.0, "mp": 1000.0, "mp_regen": 12.0,
	"patk": 550.0, "matk": 550.0, "pdef": 400.0, "mdef": 400.0,
	"move_speed": 6.0, "jump_velocity": 9.0, "weight": 1.0,
	"cast_speed": 1.0, "atk_speed": 1.0, "crit": 0.10,
}

var id: String = ""
var name_cn: String = ""
var name_en: String = ""
var group_id: String = "unspecialized"
var group_cn: String = ""
var group_en: String = ""
var role: String = "melee"
var weapon_type: String = ""
var weapon_name_cn: String = ""
var weapon_name_en: String = ""
var offhand: String = ""
var model: String = ""
var tint: Color = Color.WHITE
var famous: String = ""
var stats: Dictionary = {}
var skills: Array[SkillDef] = []
var summons: Dictionary = {}
var passives: Array[Dictionary] = []

## Every SkillDef built through sk() (including chain parts not in `skills`), by full id.
var _index: Dictionary = {}


func _init() -> void:
	define()
	_finalize()


func define() -> void:
	pass


# ---------------------------------------------------------------- hooks (override as needed)
func on_spawn(_f: Fighter) -> void:
	pass


func on_tick(_f: Fighter, _delta: float) -> void:
	pass


func on_hit_dealt(_f: Fighter, _victim: Fighter, _hit: Dictionary, _dmg: float) -> void:
	pass


func on_hit_taken(_f: Fighter, _src: Fighter, _hit: Dictionary, dmg: float) -> float:
	return dmg


func on_skill_cast(_f: Fighter, _skill: SkillDef) -> void:
	pass


## Extra gate for casting (e.g. resource meters). Return false to block.
func can_cast_extra(_f: Fighter, _skill: SkillDef) -> bool:
	return true


func on_kill(_f: Fighter, _victim: Fighter) -> void:
	pass


func on_death(_f: Fighter, _killer: Fighter) -> void:
	pass


# ---------------------------------------------------------------- hook helpers
## Guarded "on-hit status" for kits that add statuses from on_hit_dealt (host). Applies status `id` to `victim`
## unless the hit was guarded (hit["_blocked"], else the frontal-block rule from `f`), the victim is dead /
## invulnerable / downed (unless hit.otg) / grabbed by someone else, or the status is disabling and the victim has
## super armor (and the hit has no armor_break). Returns true when the status was applied.
func apply_on_hit_status(f: Fighter, victim: Fighter, hit_d: Dictionary, status_id: StringName, dur: float,
		power: float = 1.0) -> bool:
	if victim == null or not is_instance_valid(victim) or not victim.is_alive() or dur <= 0.0:
		return false
	if victim.has_status(&"invuln") and StatusSet.is_negative(status_id):
		return false
	var blocked := false
	if hit_d.has("_blocked"):
		blocked = bool(hit_d["_blocked"])
	elif f != null and is_instance_valid(f):
		blocked = Combat.would_block(victim, hit_d, f.global_position)
	if blocked:
		return false
	if victim.is_downed() and not bool(hit_d.get("otg", false)):
		return false
	if victim.state == Fighter.State.GRABBED and victim._grabbed_by != f:
		return false
	if StatusSet.DISABLING.has(status_id) and victim.has_status(&"super_armor") \
			and not bool(hit_d.get("armor_break", false)):
		return false
	var src: Fighter = f if (f != null and is_instance_valid(f)) else null
	victim.add_status(status_id, dur, power, src)
	return victim.has_status(status_id)


# ---------------------------------------------------------------- builders
## Terse SkillDef builder. `id` without a dot is prefixed with "<kit id>.".
## `extra` may set any SkillDef field: cancel_window, move_while_casting, charges, requires, chain,
## anim_speed, desc, mp_cost...
@warning_ignore("shadowed_global_identifier")
func sk(slot: int, skill_id: String, cn: String, en: String, cd: float, mp: float, cast_time: float,
		anim: StringName, range: float, tags: Array, steps: Array, extra := {}) -> SkillDef:
	var s := SkillDef.new()
	s.id = StringName(full_id(skill_id))
	s.slot = slot
	s.name_cn = cn
	s.name_en = en
	s.cooldown = maxf(0.0, cd)
	s.mp_cost = maxf(0.0, mp)
	s.cast_time = maxf(0.0, cast_time)
	s.anim = anim
	s.range = range
	s.tags = PackedStringArray(tags)
	s.set_steps(steps)
	if not extra.is_empty():
		s.apply_extra(extra)
	if s.chain.size() > 0:
		var fixed: Array[StringName] = []
		for c: StringName in s.chain:
			fixed.append(StringName(full_id(str(c))))
		s.chain = fixed
	_index[s.id] = s
	return s


## Convenience HIT builder: hit(1.2, {"launch": 9}).
func hit(dmg: float, extra := {}) -> Dictionary:
	var d: Dictionary = {"dmg": dmg}
	for k: Variant in extra:
		d[k] = extra[k]
	return d


## Convenience status spec builder: st("slow", 3.0, 0.4).
func st(status_id: String, dur: float, power: float = 1.0) -> Dictionary:
	return {"id": status_id, "dur": dur, "power": power}


func full_id(skill_id: String) -> String:
	if skill_id.contains(".") or id == "":
		return skill_id
	return "%s.%s" % [id, skill_id]


# ---------------------------------------------------------------- lookup
func get_skill_by_id(skill_id: StringName) -> SkillDef:
	if _index.has(skill_id):
		return _index[skill_id]
	var full := StringName(full_id(str(skill_id)))
	if _index.has(full):
		return _index[full]
	for s: SkillDef in skills:
		if s.id == skill_id or s.id == full:
			return s
	return null


func skill_for_slot(slot: int) -> SkillDef:
	for s: SkillDef in skills:
		if s.slot == slot:
			return s
	return null


func display_name() -> String:
	return "%s %s" % [name_cn, name_en]


func get_stats() -> Dictionary:
	var out: Dictionary = DEFAULT_STATS.duplicate()
	for k: Variant in stats:
		out[k] = float(stats[k])
	return out


## Fills defaults after define() so partially written kits never crash consumers.
func _finalize() -> void:
	for s: SkillDef in skills:
		if s != null and not _index.has(s.id):
			_index[s.id] = s
	for sid: Variant in summons:
		var d: Variant = summons[sid]
		if not (d is Dictionary):
			summons[sid] = {}
			d = summons[sid]
		var sd: Dictionary = d
		if not sd.has("skills"):
			sd["skills"] = []
		for ss: Variant in sd["skills"]:
			if ss is SkillDef and not _index.has((ss as SkillDef).id):
				_index[(ss as SkillDef).id] = ss
	if group_cn == "" or group_en == "":
		var g: Dictionary = GROUP_NAMES.get(group_id, {})
		if group_cn == "":
			group_cn = str(g.get("cn", ""))
		if group_en == "":
			group_en = str(g.get("en", ""))


const GROUP_NAMES: Dictionary = {
	"swordsman": {"cn": "剑客系", "en": "Swordsman"},
	"mage": {"cn": "法师系", "en": "Mage"},
	"gunner": {"cn": "枪手系", "en": "Gunner"},
	"fighter": {"cn": "格斗系", "en": "Fighter"},
	"nightwalker": {"cn": "暗夜系", "en": "Nightwalker"},
	"priest": {"cn": "圣职系", "en": "Priest"},
	"unspecialized": {"cn": "散人", "en": "Unspecialized"},
}
