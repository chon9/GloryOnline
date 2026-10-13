class_name MapRegistry
extends RefCounted
## Catalogue of playable maps. PvP arenas live here (owner MAPS); raid dungeons are delegated to
## res://pve/raid_registry.gd (owner RAID) when that script exists.

const RAID_REGISTRY: String = "res://pve/raid_registry.gd"

const ARENAS: Array[Dictionary] = [
	{"id": "classic_arena", "name_cn": "竞技场", "name_en": "Classic Arena",
		"modes": ["duel", "arena", "team"], "script": "res://maps/arena_classic.gd"},
	{"id": "hundred_blossoms", "name_cn": "百花谷", "name_en": "Hundred Blossoms Valley",
		"modes": ["team", "arena", "duel"], "script": "res://maps/arena_blossoms.gd"},
	{"id": "old_castle", "name_cn": "古堡", "name_en": "Old Castle",
		"modes": ["team", "arena"], "script": "res://maps/arena_castle.gd"},
	{"id": "lava_cave", "name_cn": "熔岩洞", "name_en": "Lava Cave",
		"modes": ["duel", "arena", "team"], "script": "res://maps/arena_lava.gd"},
]


## kind: "arena" (PvP maps), "raid" (dungeons from RAID), "all".
static func list(kind: String = "arena") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == "arena" or kind == "all":
		for d: Dictionary in ARENAS:
			out.append(d.duplicate(true))
	if kind == "raid" or kind == "all":
		var rr := _raid_registry()
		if rr != null and rr.has_method("list"):
			var v: Variant = rr.call("list")
			if v is Array:
				for d: Variant in v:
					if d is Dictionary:
						out.append(d)
	return out


## Maps usable for a match mode ("duel" | "arena" | "team").
static func for_mode(mode: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in list("arena"):
		if mode in d["modes"]:
			out.append(d)
	return out


static func has(id: String) -> bool:
	for d: Dictionary in ARENAS:
		if d["id"] == id:
			return true
	return false


static func info(id: String) -> Dictionary:
	for d: Dictionary in ARENAS:
		if d["id"] == id:
			return d.duplicate(true)
	return {}


static func default_id(mode: String = "duel") -> String:
	return "old_castle" if mode == "team" else "classic_arena"


## Creates (but does not build) the map. Unknown ids are delegated to the raid registry; returns null if
## nobody knows the id.
static func create(id: String) -> MapBase:
	for d: Dictionary in ARENAS:
		if d["id"] == id:
			var scr := load(str(d["script"])) as Script
			if scr == null:
				push_error("MapRegistry: cannot load " + str(d["script"]))
				return null
			var m := scr.new() as MapBase
			m.name = "Map"
			return m
	var rr := _raid_registry()
	if rr != null and rr.has_method("create"):
		var v: Variant = rr.call("create", id)
		if v is MapBase:
			return v
	push_warning("MapRegistry: unknown map id '%s'" % id)
	return null


static func _raid_registry() -> Script:
	if not ResourceLoader.exists(RAID_REGISTRY):
		return null
	return load(RAID_REGISTRY) as Script
