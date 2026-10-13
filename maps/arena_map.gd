class_name ArenaMap
extends MapBase
## Shared base for the MAPS PvP arenas: environment/lighting presets, team spawn lists and markers.
## Subclasses implement _build_map() using `kit` (MapKit) and fill `spawns[0]` / `spawns[1]`.

const TEAM_COLORS: Array[Color] = [Color(0.25, 0.55, 1.0), Color(1.0, 0.28, 0.22)]

var kit: MapKit
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
	_build_map()
	_build_spawn_markers()
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
## preset keys: sky_top, sky_horizon, ground, ambient, ambient_energy, fog_color, fog_density, sun_color,
## sun_energy, sun_pitch, sun_yaw, glow, exposure
func setup_environment(p: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = p.get("sky_top", Color(0.32, 0.5, 0.78))
	sky_mat.sky_horizon_color = p.get("sky_horizon", Color(0.72, 0.78, 0.86))
	sky_mat.ground_horizon_color = p.get("sky_horizon", Color(0.72, 0.78, 0.86))
	sky_mat.ground_bottom_color = p.get("ground", Color(0.25, 0.24, 0.22))
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.6
	e.ambient_light_color = p.get("ambient", Color(0.6, 0.62, 0.7))
	e.ambient_light_energy = float(p.get("ambient_energy", 0.8))
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = float(p.get("exposure", 1.0))
	e.glow_enabled = true
	e.glow_intensity = float(p.get("glow", 0.6))
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.0
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.2
	e.fog_enabled = true
	e.fog_light_color = p.get("fog_color", Color(0.7, 0.75, 0.82))
	e.fog_density = float(p.get("fog_density", 0.006))
	e.fog_sky_affect = 0.4
	e.fog_aerial_perspective = 0.3
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(float(p.get("sun_pitch", -50.0))), deg_to_rad(float(p.get("sun_yaw", -35.0))), 0.0)
	sun.light_color = p.get("sun_color", Color(1.0, 0.95, 0.85))
	sun.light_energy = float(p.get("sun_energy", 1.1))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.5
	add_child(sun)


func add_omni(pos: Vector3, color: Color, energy: float = 1.5, rng_m: float = 8.0, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = shadow
	add_child(l)
	return l


## Lit standing torch with an optional light. `solid`: give it a thin collision post (use false only when the
## torch sits on top of something that already has collision, e.g. a column or bridge post).
func add_torch(pos: Vector3, light: bool = true, solid: bool = true) -> void:
	kit.piece(MapKit.D + "torch_lit.gltf", pos + Vector3(0, 0.4, 0))
	if solid:
		kit.col_cyl(pos, 0.2, 1.5)
	if light:
		add_omni(pos + Vector3(0, 1.2, 0), Color(1.0, 0.62, 0.3), 1.6, 9.0)


# ================================================================== spawns
## Fills spawns[team] with points on an arc/line around `c` facing the center.
func set_spawns_line(team: int, c: Vector3, along: Vector3, spacing: float = 2.2, count: int = 5) -> void:
	var arr: Array = []
	# centre-out order (0, +1, -1, +2, -2, ...) so 1v1 modes using index 0 start in the middle
	for i in count:
		var off := spacing * ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
		arr.append(c + along.normalized() * off + Vector3(0, 0.3, 0))
	spawns[team] = arr


func _build_spawn_markers() -> void:
	for team in [0, 1]:
		var pts: Array = spawns[team]
		if pts.is_empty():
			continue
		var col: Color = TEAM_COLORS[team]
		var disc_mat := MapKit.mat(col, 0.4, col, 0.5)
		disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc_mat.albedo_color.a = 0.45
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.04
		disc.radial_segments = 24
		var c := Vector3.ZERO
		for p: Vector3 in pts:
			var mi := MeshInstance3D.new()
			mi.mesh = disc
			mi.material_override = disc_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(p.x, p.y - 0.28, p.z)
			mi.name = "SpawnMarker%d_%d" % [team, get_child_count()]
			add_child(mi)
			c += p
		c /= pts.size()
		# team-colored glow over the spawn zone
		add_omni(c + Vector3(0, 2.5, 0), col, 0.8, 8.0)
