extends DungeonBase
## 埋骨之地 Burial Grounds (Boneyard): a torch-lit crypt of the undead. Gate hall -> graveyard gate ->
## altar of the dead -> the Bone Champion's hall -> the throne crypt of the Black Knight (黑骑士), who is
## served by necromancers. Built from KayKit Dungeon Remastered pieces (floors, walls, pillars, torches,
## banners, rubble), lit sparsely by torches and a sickly green fog.

const TORCH_C := Color(1.0, 0.62, 0.3)
const SOUL_C := Color(0.45, 1.0, 0.6)
const WALLS: Array[String] = ["wall", "wall", "wall", "wall_cracked", "wall", "wall_window_closed", "wall_cracked", "wall_arched"]
const BANNERS: Array[String] = ["banner_patternA_green", "banner_thin_green", "banner_patternC_white", "banner_shield_green",
	"banner_patternB_brown"]

var _torch_edges: Dictionary = {}


func _init() -> void:
	map_id = "boneyard"
	name_cn = "埋骨之地"
	name_en = "Burial Grounds"
	map_kind = "raid"


func define_layout() -> void:
	var start := rect(-8, 8, 0, 16)
	var c1 := rect(-4, 4, -12, 0)
	var r1 := rect(-12, 12, -36, -12)
	var c2 := rect(-4, 4, -48, -36)
	var r2 := rect(-16, 16, -72, -48)
	var c3 := rect(-4, 4, -84, -72)
	var r3 := rect(-12, 12, -108, -84)
	var c4 := rect(-4, 4, -120, -108)
	var boss := rect(-20, 20, -160, -120)
	rooms = [start, c1, r1, c2, r2, c3, r3, c4, boss]
	spawn_center = Vector3(0, 0, 9)
	encounters = [
		encounter("graveyard_gate", "墓园之门", "Graveyard Gate", Vector3(0, 0, -26), 11.0,
			["skeleton_guard", "skeleton_grunt", "skeleton_grunt", "skeleton_crossbow"], false, r1),
		encounter("altar_of_dead", "亡灵祭坛", "Altar of the Dead", Vector3(0, 0, -62), 12.0,
			["skeleton_guard", "skeleton_rogue", "skeleton_mage", "necromancer", "skeleton_crossbow"], false, r2),
		encounter("bone_champion", "骨甲统领", "Bone Champion", Vector3(0, 0, -98), 11.0,
			["bone_champion", "skeleton_crossbow", "skeleton_mage", "skeleton_rogue"], false, r3),
		encounter("black_knight", "黑骑士", "Black Knight", Vector3(0, 0, -144), 16.0,
			["black_knight"], true, boss),
	]
	fit_bounds(2.0)


func build_ground() -> void:
	floor_collision()
	var boss_r := rooms[rooms.size() - 1]
	for c: Vector2i in sorted_cells():
		var p := cell_center(c)
		var corridor := absf(p.x) < 4.0 and not _in_any_room(p)
		var rel := "dungeon/floor_tile_large"
		var roll := rng.randf()
		if corridor:
			rel = "dungeon/floor_dirt_large" if roll < 0.5 else "dungeon/floor_tile_large_rocks"
		elif boss_r.has_point(Vector2(p.x, p.z)) and absf(p.x) < 6.0 and p.z < -124.0:
			rel = "dungeon/floor_tile_large_rocks" if roll < 0.2 else "dungeon/floor_tile_large"
		elif roll < 0.18:
			rel = "dungeon/floor_tile_large_rocks"
		piece(rel, p + Vector3(0, -0.05, 0), PI * 0.5 * float(rng.randi() % 4))
	# Dark void below the walls so no sky gap shows at the base.
	var under := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size + Vector2(40, 40)
	under.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.06)
	under.material_override = m
	under.position = Vector3(center.x, -0.12, center.z)
	geo.add_child(under)


func _in_any_room(p: Vector3) -> bool:
	for i in rooms.size():
		var r := rooms[i]
		if r.size.x > 8.0 and r.has_point(Vector2(p.x, p.z)):
			return true
	return false


func build_boundary() -> void:
	edge_collision()
	var i := 0
	for e: Dictionary in edges:
		var p: Vector3 = e["pos"]
		var rel := "dungeon/" + WALLS[rng.randi() % WALLS.size()]
		piece(rel, p, float(e["yaw"]))
		# Upper course so the crypt feels tall from the third-person camera.
		piece("dungeon/wall", p + Vector3(0, 4.0, 0), float(e["yaw"]))
		var inward: Vector3 = e["inward"]
		var face := p + inward * 0.5
		var yaw_in := atan2(inward.x, inward.z)
		if i % 3 == 1 and _wide_room(p):
			piece("dungeon/torch_mounted", face + Vector3(0, 2.1, 0), yaw_in)
			_torch_edges[i] = true
			if i % 6 == 1:
				omni(face + inward * 0.6 + Vector3(0, 2.6, 0), TORCH_C, 1.8, 10.0)
		elif i % 5 == 3 and _wide_room(p):
			piece("dungeon/" + BANNERS[rng.randi() % BANNERS.size()], face + Vector3(0, 0.5, 0) - inward * 0.38, yaw_in)
		i += 1
	for v: Vector3 in corner_vertices():
		piece("dungeon/pillar", v, 0.0)
		piece("dungeon/pillar", v + Vector3(0, 4.0, 0), 0.0)
		add_box(v + Vector3(0, WALL_HEIGHT * 0.5, 0), Vector3(1.4, WALL_HEIGHT, 1.4))


func _wide_room(p: Vector3) -> bool:
	return absf(p.x) > 5.0 or p.z > 0.0 or p.z < -120.0


func decorate() -> void:
	# Gate hall.
	_prop("dungeon/barrel_large", Vector3(-6.3, 0, 14), 0.0)
	_prop("dungeon/crates_stacked", Vector3(6.2, 0, 14), 0.4)
	_prop("dungeon/rubble_half", Vector3(5.5, 0, 2.5), -0.3)
	# Graveyard gate: rubble heaps and broken weapons.
	_prop("dungeon/rubble_large", Vector3(-8.5, 0, -15), 0.2, 0.7)
	_prop("dungeon/rocks_decorated", Vector3(9.5, 0, -33.5), 0.5)
	_prop("dungeon/sword_shield_broken", Vector3(8.5, 0, -15.5), 1.2, 1.0, false)
	_prop("dungeon/barrier_column", Vector3(-10, 0, -33), 0.0)
	# Altar of the dead: four decorated pillars around a candle-lit altar.
	for p: Vector3 in [Vector3(-8, 0, -54), Vector3(8, 0, -54), Vector3(-8, 0, -68), Vector3(8, 0, -68)]:
		_prop("dungeon/pillar_decorated", p, 0.0)
	_prop("dungeon/table_long_tablecloth_decorated_A", Vector3(-13.6, 0, -60), PI * 0.5)
	for z: float in [-58.0, -60.0, -62.0]:
		_prop("dungeon/candle_triple", Vector3(-15.2, 0, z), PI * 0.5, 1.0, false)
	omni(Vector3(-12.5, 2.0, -60), SOUL_C, 2.2, 11.0)
	_prop("dungeon/bookcase_double_decoratedA", Vector3(15.2, 0, -60), -PI * 0.5)
	_prop("dungeon/shelf_small_candles", Vector3(15.2, 0, -55), -PI * 0.5)
	# Bone Champion's hall: weapon racks and coffers.
	_prop("dungeon/chest_large", Vector3(-10, 0, -86.2), 0.0)
	_prop("dungeon/chest", Vector3(10, 0, -86.2), 0.0)
	_prop("dungeon/rubble_half", Vector3(-10, 0, -105), 0.6)
	_prop("dungeon/barrel_small_stack", Vector3(10.3, 0, -105.5), 0.0)
	# Throne crypt: ring of pillars, soul braziers, the throne steps at the back.
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var p := Vector3(0, 0, -140) + Vector3(cos(a) * 15.0, 0, sin(a) * 15.0)
		_prop("dungeon/pillar", p, 0.0)
	for p: Vector3 in [Vector3(-9, 0, -126), Vector3(9, 0, -126), Vector3(-9, 0, -154), Vector3(9, 0, -154)]:
		_brazier(p)
	_prop("dungeon/stairs_wide", Vector3(0, 0, -158.2), 0.0, 1.0, false)
	piece("dungeon/banner_triple_green", Vector3(0, 4.2, -159.4), 0.0)
	_prop("dungeon/rubble_large", Vector3(-15, 0, -157), 0.0, 0.6)
	_prop("dungeon/rubble_large", Vector3(15, 0, -123), PI, 0.6)


func _prop(rel: String, pos: Vector3, yaw: float, scl: float = 1.0, solid: bool = true) -> Node3D:
	var n := piece(rel, pos, yaw, scl)
	if solid and n != null:
		add_piece_collision(n)
	return n


func _brazier(p: Vector3) -> void:
	_prop("dungeon/column", p, 0.0)
	piece("dungeon/torch_lit", p + Vector3(0, 1.45, 0), 0.0, 1.2)
	omni(p + Vector3(0, 2.6, 0), SOUL_C, 2.0, 11.0)


func build_lighting() -> void:
	make_environment(Color(0.02, 0.025, 0.035), Color(0.36, 0.38, 0.48), 0.75, Color(0.1, 0.16, 0.12), 0.018)
	sun(Vector3(-62, -30, 0), Color(0.55, 0.62, 0.8), 0.45, true)
