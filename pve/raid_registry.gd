class_name RaidRegistry
extends RefCounted
## Catalogue of raid dungeons (owner: RAID). UI / lobby lists them; MatchRaid builds them by id.

const RAIDS: Array[Dictionary] = [
	{"id": "frost_forest", "name_cn": "冰霜森林", "name_en": "Frost Forest",
		"desc": "雪林小径深处，冰霜巨人守着冰湖。两波小怪后挑战首领。 A snowed-in forest trail: two trash packs, then the Frost Golem on the frozen lake.",
		"boss_cn": "冰霜巨人", "boss_en": "Frost Golem", "map_script": "res://pve/dungeon_frost_forest.gd", "players": 5},
	{"id": "boneyard", "name_cn": "埋骨之地", "name_en": "Burial Grounds",
		"desc": "亡灵盘踞的地下墓穴，黑骑士与亡灵巫师在王座墓室等待。三波小怪后挑战首领。 An undead crypt: three trash packs, then the Black Knight and his necromancers.",
		"boss_cn": "黑骑士", "boss_en": "Black Knight", "map_script": "res://pve/dungeon_boneyard.gd", "players": 5},
]


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in RAIDS:
		out.append(r.duplicate())
	return out


static func ids() -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in RAIDS:
		out.append(str(r["id"]))
	return out


static func get_info(id: String) -> Dictionary:
	for r: Dictionary in RAIDS:
		if str(r["id"]) == id:
			return r.duplicate()
	return {}


## Creates (does not build) the dungeon map for `id`; null when unknown. Call build() before use.
static func create(id: String) -> MapBase:
	var info := get_info(id)
	if info.is_empty():
		return null
	var scr: Variant = load(str(info["map_script"]))
	if not (scr is Script):
		return null
	var m: Variant = (scr as Script).new()
	if m is MapBase:
		(m as MapBase).name = "Map_" + id
		return m
	if m is Node:
		(m as Node).free()
	return null
