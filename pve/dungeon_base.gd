class_name DungeonBase
extends MapBase
## Shared builder for raid dungeons (owner: RAID). A dungeon is a union of axis-aligned rectangles on a
## 4 m grid (KayKit Dungeon pieces are 4 m tiles): start hall -> corridors -> trash rooms -> boss arena,
## laid out along -Z. The builder derives the walkable cell set, puts floors on every cell and a boundary
## (walls or cliffs/trees) on every cell edge that borders a non-walkable cell, so there are no holes.
## All collision lives in one StaticBody3D on CoreUtil.LAYER_WORLD. The build is fully deterministic
## (seeded RNG from map_id, sorted iteration), so every peer builds an identical map.
##
## Subclasses override: define_layout(), build_ground(), build_boundary(), decorate(), build_lighting().

const TILE: float = 4.0
const WALL_HEIGHT: float = 6.0
const ENV: String = "res://assets/env/"

## Walkable rectangles (Rect2 in XZ meters: position = (x0, z0), size = (w, d)); multiples of TILE.
var rooms: Array[Rect2] = []
## Encounter list (see MapBase.get_encounters); extra keys: room (Rect2), spawns (Array[Vector3]).
var encounters: Array[Dictionary] = []
var spawn_center: Vector3 = Vector3(0, 0, 10)
var built: bool = false
var cells: Dictionary = {}              # Vector2i -> true
var edges: Array[Dictionary] = []       # {pos, yaw, inward, cell}
var geo: Node3D
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
## Painted environment toolkit (merged visual batches; collision still goes through add_box / body).
var env: EnvKit
var light_count: int = 0
var max_lights: int = 18

static var _scenes: Dictionary = {}


func build() -> void:
	if built:
		return
	built = true
	map_kind = "raid"
	rng.seed = hash(map_id) & 0x7fffffff
	define_layout()
	geo = Node3D.new()
	geo.name = "Geometry"
	add_child(geo)
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = CoreUtil.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	_compute_cells()
	env = EnvKit.new(self, hash(map_id + "_env") & 0x7fffffff, body)
	build_ground()
	build_boundary()
	decorate()
	build_lighting()
	env.finish(geo)


# ------------------------------------------------------------------ overridables
func define_layout() -> void:
	pass


func build_ground() -> void:
	pass


func build_boundary() -> void:
	pass


func decorate() -> void:
	pass


func build_lighting() -> void:
	pass


# ------------------------------------------------------------------ MapBase API
func get_spawn_points(team: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var c := spawn_center if team == 0 else get_checkpoint(encounters.size() - 1)
	for i in 5:
		pts.append(c + Vector3((i - 2) * 2.0, 0.5, absf(i - 2) * 1.2))
	return pts


func get_spawn_yaw(_team: int) -> float:
	return 0.0  # facing -Z, into the dungeon


func get_encounters() -> Array[Dictionary]:
	return encounters


func get_checkpoint(cleared_index: int) -> Vector3:
	if cleared_index < 0 or encounters.is_empty():
		return spawn_center
	var i := mini(cleared_index, encounters.size() - 1)
	var e: Dictionary = encounters[i]
	if bool(e.get("boss", false)) and i > 0:
		e = encounters[i - 1]
	return (e["pos"] as Vector3) + Vector3(0, 0, 3.0)


## Cell-grid helpers ------------------------------------------------------------------------------
func _compute_cells() -> void:
	cells.clear()
	for r: Rect2 in rooms:
		var x0 := floori(r.position.x / TILE)
		var z0 := floori(r.position.y / TILE)
		var x1 := floori((r.position.x + r.size.x) / TILE)
		var z1 := floori((r.position.y + r.size.y) / TILE)
		for cz in range(z0, z1):
			for cx in range(x0, x1):
				cells[Vector2i(cx, cz)] = true
	edges.clear()
	var keys: Array = cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in keys:
		var bx := c.x * TILE
		var bz := c.y * TILE
		if not cells.has(c + Vector2i(0, -1)):
			edges.append({"pos": Vector3(bx + TILE * 0.5, 0, bz), "yaw": 0.0, "inward": Vector3(0, 0, 1), "cell": c})
		if not cells.has(c + Vector2i(0, 1)):
			edges.append({"pos": Vector3(bx + TILE * 0.5, 0, bz + TILE), "yaw": PI, "inward": Vector3(0, 0, -1), "cell": c})
		if not cells.has(c + Vector2i(-1, 0)):
			edges.append({"pos": Vector3(bx, 0, bz + TILE * 0.5), "yaw": PI * 0.5, "inward": Vector3(1, 0, 0), "cell": c})
		if not cells.has(c + Vector2i(1, 0)):
			edges.append({"pos": Vector3(bx + TILE, 0, bz + TILE * 0.5), "yaw": -PI * 0.5, "inward": Vector3(-1, 0, 0), "cell": c})


func is_walkable(p: Vector3) -> bool:
	return cells.has(Vector2i(floori(p.x / TILE), floori(p.z / TILE)))


func sorted_cells() -> Array:
	var keys: Array = cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE + TILE * 0.5, 0, c.y * TILE + TILE * 0.5)


## Distance (meters, XZ) from p to the nearest walkable cell (0 inside).
func dist_to_walkable(p: Vector3) -> float:
	var best := INF
	for r: Rect2 in rooms:
		var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - (r.position.x + r.size.x))
		var dz := maxf(maxf(r.position.y - p.z, 0.0), p.z - (r.position.y + r.size.y))
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best


## Grid vertices where boundary edges turn or end (good spots for pillars / big rocks).
func corner_vertices() -> Array[Vector3]:
	var info: Dictionary = {}
	for e: Dictionary in edges:
		var p: Vector3 = e["pos"]
		var horizontal := absf((e["inward"] as Vector3).z) > 0.5
		var a: Vector3
		var b: Vector3
		if horizontal:
			a = p - Vector3(TILE * 0.5, 0, 0)
			b = p + Vector3(TILE * 0.5, 0, 0)
		else:
			a = p - Vector3(0, 0, TILE * 0.5)
			b = p + Vector3(0, 0, TILE * 0.5)
		for v: Vector3 in [a, b]:
			var k := Vector2i(roundi(v.x), roundi(v.z))
			var d: Dictionary = info.get(k, {"h": 0, "v": 0})
			if horizontal:
				d["h"] = int(d["h"]) + 1
			else:
				d["v"] = int(d["v"]) + 1
			info[k] = d
	var out: Array[Vector3] = []
	var keys: Array = info.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for k: Vector2i in keys:
		var d: Dictionary = info[k]
		var hh := int(d["h"])
		var vv := int(d["v"])
		if (hh > 0 and vv > 0) or hh + vv == 1:
			out.append(Vector3(k.x, 0, k.y))
	return out


# ------------------------------------------------------------------ building helpers
## Drops the cached env PackedScenes (scene changes / tests).
static func clear_cache() -> void:
	_scenes.clear()


static func scene(rel: String) -> PackedScene:
	if _scenes.has(rel):
		return _scenes[rel]
	var path := ENV + rel + ".gltf"
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[rel] = ps
	return ps


## Instantiates an env piece (e.g. "dungeon/wall") under the geometry root.
func piece(rel: String, pos: Vector3, yaw: float = 0.0, scl: float = 1.0, parent: Node3D = null) -> Node3D:
	var ps := scene(rel)
	if ps == null:
		CoreUtil.warn_once("raid_piece_" + rel, "DungeonBase: missing env piece " + rel)
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scl
	(parent if parent != null else geo).add_child(n)
	return n


## Like piece() but scaled so the footprint (max of x/z) is `width` m, or the height is `height` m when width <= 0.
func piece_fit(rel: String, pos: Vector3, yaw: float, width: float, height: float = 0.0) -> Node3D:
	var n := piece(rel, pos, yaw, 1.0)
	if n == null:
		return null
	var ab := local_aabb(n)
	var cur := ab.size.y if width <= 0.0 else maxf(ab.size.x, ab.size.z)
	var want := height if width <= 0.0 else width
	if cur > 0.001:
		n.scale = Vector3.ONE * (want / cur)
	return n


## Adds a collision box (center, size, yaw) to the world body.
func add_box(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	cs.rotation.y = yaw
	body.add_child(cs)


## Collision box from a placed piece's mesh bounds (shrunk a little so props do not snag).
func add_piece_collision(n: Node3D, shrink: float = 0.85, max_height: float = 6.0) -> void:
	if n == null:
		return
	var ab := local_aabb(n)
	if ab.size == Vector3.ZERO:
		return
	var s := n.scale
	var size := Vector3(ab.size.x * s.x * shrink, minf(ab.size.y * s.y, max_height), ab.size.z * s.z * shrink)
	var c_local := ab.get_center() * s
	var c := n.position + c_local.rotated(Vector3.UP, n.rotation.y)
	c.y = n.position.y + size.y * 0.5 + ab.position.y * s.y
	add_box(c, size, n.rotation.y)


## Merged AABB of all meshes under `root`, in root's local (unscaled) space.
static func local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var a: AABB = xf * m.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


static func apply_overlay(root: Node, mat: Material) -> void:
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat


static func set_shadows(root: Node, on: bool) -> void:
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One floor collision box per room (top at y = 0).
func floor_collision() -> void:
	for r: Rect2 in rooms:
		add_box(Vector3(r.position.x + r.size.x * 0.5, -0.5, r.position.y + r.size.y * 0.5), Vector3(r.size.x, 1.0, r.size.y))


## Invisible wall collision on every boundary edge.
func edge_collision() -> void:
	for e: Dictionary in edges:
		add_box((e["pos"] as Vector3) + Vector3(0, WALL_HEIGHT * 0.5, 0), Vector3(TILE + 0.02, WALL_HEIGHT, 1.0), float(e["yaw"]))


func omni(pos: Vector3, color: Color, energy: float, rng_m: float, shadows: bool = false) -> OmniLight3D:
	if light_count >= max_lights:
		return null
	light_count += 1
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	geo.add_child(l)
	return l


## Painted zone atmosphere (EnvKit presets) instead of make_environment(): WorldEnvironment + Sun + Fill.
func painted_environment(preset: String, over: Dictionary = {}) -> void:
	EnvKit.atmosphere(self, preset, over)


func make_environment(bg: Color, ambient: Color, ambient_energy: float, fog_color: Color, fog_density: float,
		sky: Sky = null) -> WorldEnvironment:
	var env := Environment.new()
	if sky != null:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	return we


func sun(rot_deg: Vector3, color: Color, energy: float, shadows: bool = true) -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.name = "Sun"
	s.rotation_degrees = rot_deg
	s.light_color = color
	s.light_energy = energy
	s.shadow_enabled = shadows
	s.directional_shadow_max_distance = 60.0
	add_child(s)
	return s


## Room rect helper: Rect2 from x range and z range.
static func rect(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	return Rect2(Vector2(minf(x0, x1), minf(z0, z1)), Vector2(absf(x1 - x0), absf(z1 - z0)))


## Encounter dictionary helper.
static func encounter(id: String, cn: String, en: String, pos: Vector3, radius: float, mobs: Array, boss: bool,
		room: Rect2) -> Dictionary:
	var m: Array[String] = []
	for x: Variant in mobs:
		m.append(str(x))
	return {"id": id, "name_cn": cn, "name_en": en, "pos": pos, "radius": radius, "mobs": m, "boss": boss, "room": room}


## Updates size/center from the room union (+ margin).
func fit_bounds(margin: float = 2.0) -> void:
	var r := rooms[0]
	for x: Rect2 in rooms:
		r = r.merge(x)
	size = Vector2(r.size.x + margin * 2.0, r.size.y + margin * 2.0)
	center = Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
