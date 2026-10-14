class_name ArenaMap
extends MapBase
## Shared base for the MAPS PvP arenas: environment/lighting presets, team spawn lists and markers.
## Subclasses implement _build_map() using `kit` (MapKit) and fill `spawns[0]` / `spawns[1]`.

const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.28, 0.22)]

var kit: MapKit
## Painted environment toolkit (visual batches + terrain collision into kit.body).
var env: EnvKit
## team -> Array[Vector3] (ground level + 0.3)
var spawns: Dictionary = {0: [], 1: []}
## Walk routes validated by tests/test_maps_build.gd: [{name, from, to, min_y}] (from/to at ground level).
var test_walks: Array[Dictionary] = []
var _built := false


func build() -> void:
	if _built:
		return
	_built = true
	kit = MapKit.new(self, _seed())
	env = EnvKit.new(self, _seed(), kit.body)
	_build_map()
	_build_spawn_markers()
	env.finish()
	kit.finish()


## Deterministic seed per map (all peers use the same).
func _seed() -> int:
	return hash(map_id) & 0x7fffffff


func _build_map() -> void:
	pass


## Deterministic summary of the built geometry (shape transforms + piece count); equal on every peer.
func fingerprint() -> String:
	var acc := Vector3.ZERO
	var n := 0
	if kit != null:
		for c: Node in kit.body.get_children():
			if c is CollisionShape3D:
				var t := (c as CollisionShape3D).transform
				acc += t.origin * float(n % 7 + 1) + t.basis.x * 0.5 + t.basis.z * 0.25
				n += 1
	return "%s|%d|%d|%.3f,%.3f,%.3f" % [map_id, n, kit.piece_count if kit != null else 0, acc.x, acc.y, acc.z]


func get_spawn_points(team: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector3 in spawns.get(clampi(team, 0, 1), []):
		out.append(p)
	if out.is_empty():
		return super.get_spawn_points(team)
	return out


## Faces the team towards the map center from its spawn centroid.
func get_spawn_yaw(team: int) -> float:
	var pts := get_spawn_points(team)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= maxf(1.0, pts.size())
	var d := CoreUtil.flat_dir(center - c, Vector3.FORWARD)
	return CoreUtil.yaw_of(d)


## True when standing at `pos` hurts (lava etc.). Bots should avoid such points (see DEVIATIONS Requests (MAPS)).
func is_hazard(_pos: Vector3) -> bool:
	return false


func apply_to_world(world: World) -> void:
	super.apply_to_world(world)
	world.floor_y = center.y


# ================================================================== environment presets
## Zone atmosphere (EnvKit.PRESETS: frost, glory_stage, blossom, golden_ruins, lava, moon) + overrides.
func setup_atmosphere(preset: String, over: Dictionary = {}) -> void:
	EnvKit.atmosphere(self, preset, over)


func add_omni(pos: Vector3, color: Color, energy: float = 1.5, rng_m: float = 8.0, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	add_child(l)
	return l


## Painted stone lantern with a glowing core (optional light). `solid`: thin collision post (false when it stands
## on something that already has collision).
func add_lantern(pos: Vector3, stone: Material, core_col: Color, light: bool = true, solid: bool = true) -> void:
	EnvProps.lantern(env, pos, stone, EnvKit.glow(core_col, 4.0), false, core_col)
	if solid:
		kit.col_cyl(pos, 0.25, 1.6)
	if light:
		add_omni(pos + Vector3(0, 1.6, 0), core_col, 1.4, 7.0)


# ================================================================== spawns
## Fills spawns[team] with points on an arc/line around `c` facing the center.
func set_spawns_line(team: int, c: Vector3, along: Vector3, spacing: float = 2.2, count: int = 5) -> void:
	var arr: Array = []
	# centre-out order (0, +1, -1, +2, -2, ...) so 1v1 modes using index 0 start in the middle
	for i in count:
		var off := spacing * ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
		arr.append(c + along.normalized() * off + Vector3(0, 0.3, 0))
	spawns[team] = arr


## Painted rune circles under each team spawn (team colour, additive) + one soft team light per side.
func _build_spawn_markers() -> void:
	for team in [0, 1]:
		var pts: Array = spawns[team]
		if pts.is_empty():
			continue
		var col: Color = TEAM_COLORS[team]
		var ring := EnvKit.lathe([Vector2(0.62, 0.0), Vector2(0.55, 0.0), Vector2(0.5, 0.0), Vector2(0.42, 0.0)], 32)
		var mat := EnvKit.glow(col, 1.4, true, 0.8)
		var disc_mat := EnvKit.glow(col * 0.6, 0.4, true, 0.18)
		var disc := EnvKit.cyl(0.4, 0.4, 0.01, 24)
		var c := Vector3.ZERO
		for p: Vector3 in pts:
			var root := MeshInstance3D.new()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(ring, 0, Transform3D(Basis(), Vector3(0, 0.02, 0)))
			var am := st.commit()
			am.surface_set_material(0, mat)
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			st2.append_from(disc, 0, Transform3D(Basis(), Vector3(0, 0.015, 0)))
			st2.commit(am)
			am.surface_set_material(1, disc_mat)
			root.mesh = am
			root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.position = Vector3(p.x, p.y - 0.27, p.z)
			root.name = "SpawnMarker%d_%d" % [team, get_child_count()]
			add_child(root)
			c += p
		c /= pts.size()
		add_omni(c + Vector3(0, 2.5, 0), col, 0.8, 8.0)
