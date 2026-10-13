class_name MapBase
extends Node3D
## Base class for every playable map (PvP arenas owned by MAPS, raid dungeons owned by RAID).
## A map builds its own geometry (collision on CoreUtil.LAYER_WORLD), lighting and WorldEnvironment
## procedurally in build(), and tells the match where teams spawn and how large the play area is.

var map_id: String = ""
var name_cn: String = ""
var name_en: String = ""
## "arena" for PvP maps, "raid" for dungeons.
var map_kind: String = "arena"
## Approximate playable size in meters, used for World.set_arena_size().
var size := Vector2(40.0, 40.0)
var center := Vector3.ZERO


## Build all geometry, lights and environment. Called once by the Match before any fighter spawns.
## Must be deterministic: every peer builds the map locally and the result must be identical.
func build() -> void:
	pass


## Spawn positions for a team (0 or 1 in PvP; 0 for raid players). At least 5 points per team.
func get_spawn_points(team: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var z := -size.y * 0.35 if team == 0 else size.y * 0.35
	for i in 5:
		pts.append(center + Vector3((i - 2) * 2.0, 0.5, z))
	return pts


## Yaw (radians) a team should face when spawning (towards the map center by default).
func get_spawn_yaw(team: int) -> float:
	return PI if team == 0 else 0.0


func get_bounds() -> AABB:
	return AABB(center - Vector3(size.x * 0.5, 10.0, size.y * 0.5), Vector3(size.x, 60.0, size.y))


## Called by the Match after build(); applies bounds to the World.
func apply_to_world(world: World) -> void:
	world.set_arena_size(size.x, size.y, center)


## Raid dungeons override these. Each encounter: {id: String, pos: Vector3, radius: float,
## mobs: Array[String] (mob ids), boss: bool, name_cn, name_en}. Encounters are triggered in order.
func get_encounters() -> Array[Dictionary]:
	return []


## Raid respawn checkpoints, index matches the last cleared encounter (-1 = start).
func get_checkpoint(cleared_index: int) -> Vector3:
	var pts := get_spawn_points(0)
	return pts[0] if pts.size() > 0 else center
