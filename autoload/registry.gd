extends Node
## Registry autoload (owner: CORE). Loads every ClassKit under res://classes and mob defs from
## res://pve/mob_defs.gd (expected: `static func all() -> Dictionary` of mob_id -> def dict, see
## docs/DEVIATIONS.md "CORE"). Works with an empty or missing classes/ directory.

const CLASSES_DIR: String = "res://classes"
const MOB_DEFS_PATH: String = "res://pve/mob_defs.gd"
const GROUP_ORDER: Array[String] = ["swordsman", "mage", "gunner", "fighter", "nightwalker", "priest", "unspecialized"]
## Canonical roster order inside each group (ARCHITECTURE §6); unknown ids sort after, alphabetically.
const ROSTER_ORDER: Array[String] = [
	"blade_master", "berserker", "spellblade", "ghostblade",
	"battle_mage", "elementalist", "witch", "summoner",
	"sharpshooter", "spitfire", "launcher", "mechanic",
	"striker", "qi_master", "grappler", "brawler",
	"assassin", "ninja", "thief", "warlock",
	"knight", "exorcist", "cleric", "paladin",
	"unspecialized",
]

var kits: Dictionary = {}           # id -> ClassKit
var mob_defs: Dictionary = {}       # mob_id -> def Dictionary (skills normalised to Array[SkillDef])
var _skill_index: Dictionary = {}   # skill id -> SkillDef
var load_errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	kits.clear()
	_skill_index.clear()
	load_errors.clear()
	for path: String in _scan(CLASSES_DIR):
		_load_kit(path)
	_load_mob_defs()


# ---------------------------------------------------------------- scanning
## Returns script paths under `dir` recursively. Exported builds list "x.gd.remap" / "x.gdc"; both
## map back to the loadable "x.gd" path. Files starting with "_" are treated as helpers and skipped.
func _scan(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var da := DirAccess.open(dir)
	if da == null:
		return out
	var subdirs: Array[String] = []
	var files: Array[String] = []
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if da.current_is_dir():
			if not fname.begins_with("."):
				subdirs.append(fname)
		else:
			var base := fname
			if base.ends_with(".remap"):
				base = base.trim_suffix(".remap")
			if base.ends_with(".gdc"):
				base = base.trim_suffix(".gdc") + ".gd"
			if base.ends_with(".gd") and not base.begins_with("_") and not files.has(base):
				files.append(base)
		fname = da.get_next()
	da.list_dir_end()
	files.sort()
	subdirs.sort()
	for f: String in files:
		out.append(dir.path_join(f))
	for s: String in subdirs:
		out.append_array(_scan(dir.path_join(s)))
	return out


func _load_kit(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var scr: Variant = load(path)
	if not (scr is Script) or not (scr as Script).can_instantiate():
		load_errors.append("cannot load " + path)
		return
	if not _extends_class_kit(scr as Script):
		return  # helper script, not a kit: never instantiated (no _init side effects, no orphan nodes)
	var inst: Variant = (scr as Script).new()
	if not (inst is ClassKit):
		if inst is Object and not (inst is RefCounted) and is_instance_valid(inst):
			(inst as Object).free()
		return
	var kit: ClassKit = inst
	if kit.id == "":
		kit.id = path.get_file().get_basename()
	register_kit(kit)


static func _extends_class_kit(scr: Script) -> bool:
	var s: Script = scr
	while s != null:
		if s.get_global_name() == &"ClassKit":
			return true
		s = s.get_base_script()
	return false


## Registers (or replaces) a kit. Also used by tests/sandboxes for kits outside res://classes.
func register_kit(kit: ClassKit) -> void:
	if kit == null or kit.id == "":
		return
	if kit.skills.size() != 8:
		CoreUtil.warn_once("kit_skills_" + kit.id, "Registry: kit '%s' has %d skills (expected 8)" % [kit.id, kit.skills.size()])
	kits[kit.id] = kit
	for sid: Variant in kit._index:
		_skill_index[sid] = kit._index[sid]
	for s: SkillDef in kit.skills:
		_skill_index[s.id] = s


func _load_mob_defs() -> void:
	mob_defs.clear()
	if not ResourceLoader.exists(MOB_DEFS_PATH):
		return
	var scr: Variant = load(MOB_DEFS_PATH)
	if not (scr is Script):
		return
	var has_all := false
	for m: Dictionary in (scr as Script).get_script_method_list():
		if str(m.get("name", "")) == "all":
			has_all = true
	var raw: Variant = null
	if has_all:
		raw = (scr as Script).call("all")
	elif (scr as Script).can_instantiate():
		var inst: Variant = (scr as Script).new()
		if inst != null and inst is Object and (inst as Object).has_method("all"):
			raw = (inst as Object).call("all")
	if not (raw is Dictionary):
		push_warning("Registry: %s has no usable all() -> Dictionary" % MOB_DEFS_PATH)
		return
	for id: Variant in raw:
		if raw[id] is Dictionary:
			register_mob_def(str(id), raw[id])


## Normalises and registers a mob def: fills defaults and converts skill dicts to SkillDefs.
func register_mob_def(id: String, def: Dictionary) -> void:
	var d: Dictionary = def.duplicate()
	d["id"] = id
	if not d.has("name_cn"):
		d["name_cn"] = id
	if not d.has("name_en"):
		d["name_en"] = id
	if not (d.get("stats") is Dictionary):
		d["stats"] = {}
	var skills: Array[SkillDef] = []
	var raw: Variant = d.get("skills", [])
	if raw is Array:
		for s: Variant in raw:
			var sd: SkillDef = null
			if s is SkillDef:
				sd = s
			elif s is Dictionary:
				sd = SkillDef.from_dict(s)
			if sd != null:
				if str(sd.id) == "":
					sd.id = StringName("%s.skill%d" % [id, skills.size()])
				if not (s is Dictionary and (s as Dictionary).has("slot")) and not (s is SkillDef):
					sd.slot = skills.size()
				skills.append(sd)
				_skill_index[sd.id] = sd
	d["skills"] = skills
	mob_defs[id] = d


# ---------------------------------------------------------------- queries
func get_kit(id: String) -> ClassKit:
	var k: Variant = kits.get(id)
	return k if k is ClassKit else null


func has_kit(id: String) -> bool:
	return kits.has(id)


## Ordered {group_id: [kit ids]} following GROUP_ORDER (plus any unknown groups at the end).
func kit_ids_by_group() -> Dictionary:
	var out: Dictionary = {}
	for g: String in GROUP_ORDER:
		out[g] = []
	for id: Variant in kits:
		var g := (kits[id] as ClassKit).group_id
		if not out.has(g):
			out[g] = []
		(out[g] as Array).append(str(id))
	for g: Variant in out:
		(out[g] as Array).sort_custom(_roster_less)
	return out


static func _roster_less(a: String, b: String) -> bool:
	var ia := ROSTER_ORDER.find(a)
	var ib := ROSTER_ORDER.find(b)
	if ia < 0:
		ia = 1000
	if ib < 0:
		ib = 1000
	if ia != ib:
		return ia < ib
	return a < b


## All kit ids in group/roster order.
func kit_ids() -> Array[String]:
	var out: Array[String] = []
	var by := kit_ids_by_group()
	for g: Variant in by:
		for id: Variant in by[g]:
			out.append(str(id))
	return out


func get_skill(id: StringName) -> SkillDef:
	var s: Variant = _skill_index.get(id)
	if s is SkillDef:
		return s
	var sid := str(id)
	var dot := sid.find(".")
	if dot > 0:
		var k := get_kit(sid.substr(0, dot))
		if k != null:
			return k.get_skill_by_id(id)
	return null


func get_mob_def(id: String) -> Dictionary:
	var d: Variant = mob_defs.get(id)
	return d if d is Dictionary else {}
