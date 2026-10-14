class_name MapKit
extends RefCounted
## Procedural map building helpers shared by all MAPS arenas.
## - piece(): places a KayKit glTF piece (visual only). All instances of the same mesh are batched into one
##   MultiMeshInstance3D by finish(), so a map costs one draw call per distinct mesh (+ shadows).
## - col_*(): collision on CoreUtil.LAYER_WORLD inside one StaticBody3D ("WorldCollision").
## - Higher level helpers (floor_grid, platform, ramp, wall_line, tree, rock) place visuals and the matching
##   collision together so geometry and physics always agree.
## Everything is deterministic: no randomness except an explicitly seeded RandomNumberGenerator (rng).

const ENV: String = "res://assets/env/"
const D: String = "res://assets/env/dungeon/"
const N: String = "res://assets/env/nature/"

## path -> Array of [Mesh, Transform3D] (mesh local transform inside the glTF scene)
static var _mesh_cache: Dictionary = {}
## path -> ConvexPolygonShape3D points (unscaled, piece space)
static var _hull_cache: Dictionary = {}

var root: Node3D
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
var shape_count: int = 0
var piece_count: int = 0
var _batches: Dictionary = {}          # Mesh -> Array[Transform3D]
var _batch_order: Array[Mesh] = []     # deterministic creation order
var _shadow_off: Dictionary = {}       # Mesh -> true (small props that should not cast shadows)


func _init(p_root: Node3D, seed_value: int = 1) -> void:
	root = p_root
	rng.seed = seed_value
	body = StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = CoreUtil.LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)


# ================================================================== meshes
static func meshes_of(path: String) -> Array:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var out: Array = []
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("MapKit: missing piece " + path)
		_mesh_cache[path] = out
		return out
	var s := ps.instantiate() as Node3D
	for m: Node in s.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D()
		var p: Node = mi
		while p != null and p != s:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		out.append([mi.mesh, t])
	s.free()
	_mesh_cache[path] = out
	return out


static func piece_aabb(path: String) -> AABB:
	var ab := AABB()
	var first := true
	for e: Array in meshes_of(path):
		var a: AABB = (e[1] as Transform3D) * (e[0] as Mesh).get_aabb()
		ab = a if first else ab.merge(a)
		first = false
	return ab


static func xf(pos: Vector3, yaw_deg: float = 0.0, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled_local(scl)
	return Transform3D(b, pos)


## Places a glTF piece (visual only).
func piece(path: String, pos: Vector3, yaw_deg: float = 0.0, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> void:
	piece_xf(path, xf(pos, yaw_deg, scl), shadows)


func piece_xf(path: String, t: Transform3D, shadows: bool = true) -> void:
	for e: Array in meshes_of(path):
		var mesh: Mesh = e[0]
		if not _batches.has(mesh):
			_batches[mesh] = []
			_batch_order.append(mesh)
			if not shadows:
				_shadow_off[mesh] = true
		(_batches[mesh] as Array).append(t * (e[1] as Transform3D))
	piece_count += 1


## Builds the batched visuals. Call once at the end of the map build.
func finish() -> void:
	var holder := Node3D.new()
	holder.name = "Geometry"
	root.add_child(holder)
	var i := 0
	for mesh: Mesh in _batch_order:
		var xs: Array = _batches[mesh]
		var gi: GeometryInstance3D
		if xs.size() == 1:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.transform = xs[0]
			gi = mi
		else:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xs.size()
			for k in xs.size():
				mm.set_instance_transform(k, xs[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			gi = mmi
		gi.name = "Batch%d" % i
		if _shadow_off.has(mesh):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(gi)
		i += 1
	_batches.clear()
	_batch_order.clear()


# ================================================================== collision
func col_box_xf(t: Transform3D, size: Vector3, label: String = "Box") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = t
	cs.name = "%s%d" % [label, shape_count]
	body.add_child(cs)
	shape_count += 1
	return cs


## Axis-aligned (or yawed) box given its center.
func col_box(center: Vector3, size: Vector3, yaw_deg: float = 0.0, label: String = "Box") -> CollisionShape3D:
	return col_box_xf(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), center), size, label)


## Vertical cylinder standing on `base`.
func col_cyl(base: Vector3, radius: float, height: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = base + Vector3(0, height * 0.5, 0)
	cs.name = "Cyl%d" % shape_count
	body.add_child(cs)
	shape_count += 1
	return cs


## Convex hull of a piece with the given transform (scale baked into the points).
func col_hull(path: String, t: Transform3D) -> CollisionShape3D:
	var pts: PackedVector3Array
	if _hull_cache.has(path):
		pts = _hull_cache[path]
	else:
		pts = PackedVector3Array()
		for e: Array in meshes_of(path):
			var shp := (e[0] as Mesh).create_convex_shape(true, true)
			if shp == null:
				continue
			var lt: Transform3D = e[1]
			for p: Vector3 in shp.points:
				pts.append(lt * p)
		_hull_cache[path] = pts
	var baked := PackedVector3Array()
	var basis_only := Transform3D(t.basis, Vector3.ZERO)
	for p: Vector3 in pts:
		baked.append(basis_only * p)
	var cs := CollisionShape3D.new()
	var cvx := ConvexPolygonShape3D.new()
	cvx.points = baked
	cs.shape = cvx
	cs.position = t.origin
	cs.name = "Hull%d" % shape_count
	body.add_child(cs)
	shape_count += 1
	return cs


# ================================================================== simple meshes
func box_visual(center: Vector3, size: Vector3, mat: Material, yaw_deg: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), center)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func mat(color: Color, rough: float = 0.9, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


# ================================================================== composite helpers
## Ground floor of 4 m stone tiles covering rect (XZ) with top at y; one collision slab.
## `skip` returns true for tile centers that must not be tiled (holes, lava...).
func floor_grid(rect: Rect2, y: float = 0.0, tile: String = D + "floor_tile_large.gltf", skip: Callable = Callable(),
		alt_tiles: Array = [], alt_chance: float = 0.0, collide: bool = true) -> void:
	var nx := int(ceil(rect.size.x / 4.0))
	var nz := int(ceil(rect.size.y / 4.0))
	for ix in nx:
		for iz in nz:
			var c := Vector3(rect.position.x + 2.0 + ix * 4.0, y - 0.05, rect.position.y + 2.0 + iz * 4.0)
			if skip.is_valid() and bool(skip.call(c)):
				continue
			var path := tile
			if alt_tiles.size() > 0 and rng.randf() < alt_chance:
				path = alt_tiles[rng.randi() % alt_tiles.size()]
			piece(path, c, 90.0 * (rng.randi() % 4), Vector3.ONE, false)
	if collide:
		col_box(Vector3(rect.get_center().x, y - 1.0, rect.get_center().y), Vector3(rect.size.x, 2.0, rect.size.y), 0.0, "Floor")


## Raised stone platform: foundation blocks on the edges, 2 m floor tiles on top, solid collision.
## rect is in XZ meters (multiples of 2 recommended), h = top height.
func platform(rect: Rect2, h: float, top_tile: String = D + "floor_tile_small.gltf", base_y: float = 0.0, visual: bool = true) -> void:
	if not visual:
		platform_col(rect, h, base_y)
		return
	var nx := int(round(rect.size.x / 2.0))
	var nz := int(round(rect.size.y / 2.0))
	var sy := (h - base_y) / 2.0
	for ix in nx:
		for iz in nz:
			var cx := rect.position.x + 1.0 + ix * 2.0
			var cz := rect.position.y + 1.0 + iz * 2.0
			var edge := ix == 0 or iz == 0 or ix == nx - 1 or iz == nz - 1
			if edge:
				piece(D + "floor_foundation_allsides.gltf", Vector3(cx, base_y, cz), 0.0, Vector3(1.0, sy, 1.0))
			piece(top_tile, Vector3(cx, h - 0.05, cz), 90.0 * ((ix * 7 + iz * 3) % 4), Vector3.ONE, false)
	platform_col(rect, h, base_y)


## Collision only for a raised platform (top at h).
func platform_col(rect: Rect2, h: float, base_y: float = 0.0) -> void:
	var cy := (h + base_y) * 0.5 - 0.5
	col_box(Vector3(rect.get_center().x, cy, rect.get_center().y), Vector3(rect.size.x, h - base_y + 1.0, rect.size.y), 0.0, "Plat")


## Stair ramp (KayKit long modular stairs, scaled) going from `top` (center of the upper edge, y = top height)
## down along direction yaw (degrees; 0 = towards +Z) for `length` meters to `base_y`. width multiple of 2.
## Collision is a slope plane through the step noses; slope = atan(h/length) (keep <= 35 deg).
func ramp(top: Vector3, yaw_deg: float, length: float, width: float = 4.0, base_y: float = 0.0, visual: bool = true) -> void:
	var h := top.y - base_y
	var modules := maxi(1, int(round(width / 2.0))) if visual else 0
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var right := b * Vector3.RIGHT
	for i in modules:
		var off := (float(i) - (modules - 1) * 0.5) * 2.0
		var p := Vector3(top.x, base_y, top.z) + right * off
		piece(D + "stairs_long_modular_center.gltf", p, yaw_deg, Vector3(1.0, h / 4.0, length / 8.0))
	# slope collision: box whose top face spans (z=0,y=h) .. (z=length,y=0) in ramp space
	var slope := atan2(h, length)
	var hyp := sqrt(h * h + length * length)
	var thick := 0.8
	var rb := b * Basis(Vector3.RIGHT, slope)
	var mid_local := Vector3(0, h * 0.5, length * 0.5)
	var n := rb * Vector3.UP
	var center := Vector3(top.x, base_y, top.z) + b * mid_local - n * (thick * 0.5)
	col_box_xf(Transform3D(rb, center), Vector3(width, thick, hyp + 0.2), "Ramp")
	# solid fill under the slope (stepped wedge) so nothing can walk under the stairs
	var k := 4
	for i in k:
		var z1 := length * float(i + 1) / k
		var z0 := length * float(i) / k
		var top_y := h * (1.0 - z1 / length) - 0.05
		if top_y < 0.25:
			continue
		var c := Vector3(top.x, base_y, top.z) + b * Vector3(0, top_y * 0.5, (z0 + z1) * 0.5)
		col_box_xf(Transform3D(b, c), Vector3(width, top_y, z1 - z0), "RampFill")


## Straight wall from a to b (XZ, y = base) built from 4 m KayKit wall segments, with collision.
## kinds: Array of piece names cycled deterministically (e.g. ["wall", "wall_cracked"]).
func wall_line(a: Vector3, b: Vector3, kinds: Array = ["wall"], col_height: float = 4.0, thickness: float = 1.0,
		collide: bool = true) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	if length < 0.01:
		return
	var dir := d / length
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	var n := maxi(1, int(round(length / 4.0)))
	var seg := length / n
	for i in n:
		var c := a + dir * (seg * (i + 0.5))
		var kind: String = kinds[i % kinds.size()]
		piece(D + kind + ".gltf", c, yaw, Vector3(seg / 4.0, 1.0, 1.0))
	if collide:
		var mid := (a + b) * 0.5
		col_box(Vector3(mid.x, a.y + col_height * 0.5, mid.z), Vector3(length, col_height, thickness), yaw, "Wall")


## Tree with a trunk cylinder collider.
func tree(path: String, pos: Vector3, yaw_deg: float, s: float, trunk_radius: float = 0.35) -> void:
	piece(N + path, pos, yaw_deg, Vector3.ONE * s)
	col_cyl(pos, trunk_radius * s, 3.0 * s)


## Big rock (scaled nature rock) with convex collision matching its mesh.
func rock(path: String, pos: Vector3, yaw_deg: float, s: Vector3) -> void:
	var t := xf(pos, yaw_deg, s)
	piece_xf(N + path, t)
	col_hull(N + path, t)
