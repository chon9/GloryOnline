extends DungeonBase
## 冰霜森林 Frost Forest: a snowed-in forest trail (start camp -> wolf pack clearing -> orc camp) ending at a
## frozen lake where the Frost Golem (冰霜巨人) waits. Built from KayKit Forest Nature (frosted with a snow
## overlay) plus KayKit Dungeon props; cliff rocks and pines form the boundary over invisible walls.

const SNOW := Color(0.86, 0.9, 0.96)
const ICE_C := Color(0.55, 0.85, 1.0)
const TREES: Array[String] = ["Tree_1_A_Color1", "Tree_1_B_Color1", "Tree_2_A_Color1", "Tree_2_C_Color1", "Tree_3_A_Color1",
	"Tree_4_A_Color1", "Tree_4_B_Color1", "Tree_5_A_Color1", "Tree_6_A_Color1", "Tree_7_A_Color1", "Tree_Bare_1_A_Color1",
	"Tree_Bare_2_A_Color1", "Tree_Bare_1_B_Color1"]
const ROCKS: Array[String] = ["Rock_1_A_Color1", "Rock_1_D_Color1", "Rock_1_J_Color1", "Rock_2_A_Color1", "Rock_2_C_Color1",
	"Rock_3_A_Color1", "Rock_3_E_Color1", "Rock_4_A_Color1", "Rock_5_A_Color1", "Rock_5_C_Color1"]

const SNOW_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;
uniform vec4 snow_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);
uniform float threshold = 0.35;
varying vec3 world_n;
void vertex() {
	world_n = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	float s = smoothstep(threshold, threshold + 0.25, normalize(world_n).y);
	ALBEDO = snow_color.rgb;
	ROUGHNESS = 0.85;
	ALPHA = s * snow_color.a;
}
"""

var _frost_mat: ShaderMaterial
var _ice_mat: StandardMaterial3D
var _crystal_mat: StandardMaterial3D


func _init() -> void:
	map_id = "frost_forest"
	name_cn = "冰霜森林"
	name_en = "Frost Forest"
	map_kind = "raid"


func define_layout() -> void:
	var start := rect(-8, 8, 0, 16)
	var c1 := rect(-4, 4, -12, 0)
	var r1 := rect(-12, 12, -36, -12)
	var c2 := rect(-4, 4, -48, -36)
	var r2 := rect(-12, 12, -72, -48)
	var c3 := rect(-4, 4, -84, -72)
	var boss := rect(-20, 20, -124, -84)
	rooms = [start, c1, r1, c2, r2, c3, boss]
	spawn_center = Vector3(0, 0, 9)
	encounters = [
		encounter("wolf_pack", "冰原狼群", "Frost Wolf Pack", Vector3(0, 0, -26), 11.0,
			["frost_wolf", "frost_wolf", "orc_raider", "orc_guard", "ice_archer"], false, r1),
		encounter("orc_camp", "兽人营地", "Orc Camp", Vector3(0, 0, -62), 11.0,
			["orc_warlord", "orc_guard", "orc_raider", "ice_archer", "frost_shaman"], false, r2),
		encounter("frost_golem", "冰霜巨人", "Frost Golem", Vector3(0, 0, -108), 15.0,
			["frost_golem"], true, boss),
	]
	fit_bounds(2.0)


func _mats() -> void:
	# Snow caps: an overlay that whitens only upward-facing surfaces (rocks, trees, props keep their colour).
	var sh := Shader.new()
	sh.code = SNOW_SHADER
	_frost_mat = ShaderMaterial.new()
	_frost_mat.shader = sh
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.albedo_color = Color(0.5, 0.68, 0.82)
	_ice_mat.metallic = 0.3
	_ice_mat.roughness = 0.08
	_ice_mat.emission_enabled = true
	_ice_mat.emission = Color(0.05, 0.12, 0.2)
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.85)
	_crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.35, 0.8, 1.0)
	_crystal_mat.emission_energy_multiplier = 1.6
	_crystal_mat.roughness = 0.1


func build_ground() -> void:
	_mats()
	# One big snow plane (visual) + one big ground slab (collision) so every raycast down hits.
	var r := Rect2(Vector2(center.x - size.x * 0.5 - 30.0, center.z - size.y * 0.5 - 30.0), Vector2(size.x + 60.0, size.y + 60.0))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = SNOW
	snow.roughness = 0.95
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.89, 0.94))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	snow.albedo_texture = tex
	snow.uv1_scale = Vector3(r.size.x / 24.0, r.size.y / 24.0, 1.0)
	snow.albedo_color = Color(0.9, 0.94, 1.0)
	mi.material_override = snow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo.add_child(mi)
	add_box(Vector3(r.get_center().x, -0.5, r.get_center().y), Vector3(r.size.x, 1.0, r.size.y))
	# Packed-snow trail (slightly darker) over the walkable cells.
	var trail := StandardMaterial3D.new()
	trail.albedo_color = Color(0.86, 0.88, 0.93)
	trail.roughness = 0.9
	trail.albedo_texture = tex
	trail.uv1_scale = Vector3(0.5, 0.5, 1.0)
	for rr: Rect2 in rooms:
		var t := MeshInstance3D.new()
		var tp := PlaneMesh.new()
		tp.size = rr.size - Vector2(0.6, 0.6)
		t.mesh = tp
		t.material_override = trail
		t.position = Vector3(rr.get_center().x, 0.012, rr.get_center().y)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geo.add_child(t)
	# Frozen lake in the boss arena.
	var lake := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 15.0
	cyl.bottom_radius = 15.0
	cyl.height = 0.04
	cyl.radial_segments = 48
	lake.mesh = cyl
	lake.material_override = _ice_mat
	lake.position = Vector3(0, 0.03, -104)
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo.add_child(lake)


func build_boundary() -> void:
	edge_collision()
	for e: Dictionary in edges:
		var p: Vector3 = e["pos"]
		var out := -(e["inward"] as Vector3)
		var side := Vector3(out.z, 0, -out.x)
		# A wall of large frosted rocks right on the edge (two per tile), pines behind.
		for k in 2:
			var rp := p + side * ((k - 0.5) * 2.0 + rng.randf_range(-0.4, 0.4)) + out * rng.randf_range(0.6, 1.4)
			var rock := piece_fit("nature/" + ROCKS[rng.randi() % ROCKS.size()], rp, rng.randf() * TAU, rng.randf_range(2.4, 3.4))
			_frost(rock)
		if rng.randf() < 0.75:
			var tp := p + out * rng.randf_range(2.6, 5.5) + side * rng.randf_range(-1.5, 1.5)
			_tree(tp, rng.randf_range(5.0, 7.5))
	for v: Vector3 in corner_vertices():
		var big := piece_fit("nature/" + ROCKS[rng.randi() % ROCKS.size()], v, rng.randf() * TAU, rng.randf_range(3.2, 4.2))
		_frost(big)
	# Outer forest band so the trail feels enclosed (deterministic scatter, skipped near the trail).
	var x0 := center.x - size.x * 0.5 - 16.0
	var z0 := center.z - size.y * 0.5 - 16.0
	var z := z0
	while z < center.z + size.y * 0.5 + 16.0:
		var x := x0
		while x < center.x + size.x * 0.5 + 16.0:
			var p := Vector3(x + rng.randf_range(-2.0, 2.0), 0, z + rng.randf_range(-2.0, 2.0))
			var d := dist_to_walkable(p)
			if d > 5.0 and d < 18.0 and rng.randf() < 0.55:
				_tree(p, rng.randf_range(5.5, 9.0))
			elif d > 4.0 and d < 18.0 and rng.randf() < 0.15:
				_frost(piece("nature/Hill_8x8x4_Color1", p, rng.randf() * TAU, rng.randf_range(0.6, 1.0)))
			x += 6.0
		z += 6.0


## `h` = tree height in meters.
func _tree(p: Vector3, h: float) -> void:
	var t := piece_fit("nature/" + TREES[rng.randi() % TREES.size()], p, rng.randf() * TAU, 0.0, h)
	_frost(t)


func _frost(n: Node3D) -> void:
	if n != null:
		apply_overlay(n, _frost_mat)


func decorate() -> void:
	# Start camp: crates, barrels, a tent-like banner pair and a campfire.
	_prop("dungeon/crates_stacked", Vector3(-6, 0, 14), 0.3, true)
	_prop("dungeon/barrel_large", Vector3(6, 0, 14), 0.0, true)
	_prop("dungeon/barrel_small_stack", Vector3(6.2, 0, 11.5), 0.6, true)
	_prop("dungeon/banner_patternA_blue", Vector3(-7.4, 0, 6), PI * 0.5, false)
	_prop("dungeon/banner_patternA_blue", Vector3(7.4, 0, 6), -PI * 0.5, false)
	_campfire(Vector3(0, 0, 13.5))
	# Wolf clearing: bones and boulders.
	for p: Vector3 in [Vector3(-9.5, 0, -16), Vector3(9.5, 0, -33), Vector3(-9, 0, -33)]:
		var rk := piece_fit("nature/" + ROCKS[rng.randi() % ROCKS.size()], p, rng.randf() * TAU, 2.2)
		add_piece_collision(rk)
		_frost(rk)
	_prop("dungeon/sword_shield_broken", Vector3(5, 0, -17), 0.8, false)
	_crystals(Vector3(10, 0, -24), 3)
	_crystals(Vector3(-10, 0, -28), 2)
	# Orc camp: palisade crates, barrels, braziers, weapon racks.
	_prop("dungeon/crates_stacked", Vector3(-10, 0, -51), 0.2, true)
	_prop("dungeon/crate_large", Vector3(-10, 0, -54), 0.9, true)
	_prop("dungeon/barrel_large_decorated", Vector3(10, 0, -51), 0.0, true)
	_prop("dungeon/keg_decorated", Vector3(10, 0, -54.5), 1.2, true)
	_prop("dungeon/table_long_broken", Vector3(-9.5, 0, -68), PI * 0.5, true)
	_prop("dungeon/sword_shield", Vector3(9.5, 0, -69), -0.5, false)
	_prop("dungeon/banner_patternB_red", Vector3(-11.4, 0, -60), PI * 0.5, false)
	_prop("dungeon/banner_patternB_red", Vector3(11.4, 0, -60), -PI * 0.5, false)
	_campfire(Vector3(-6, 0, -57))
	_campfire(Vector3(6, 0, -67))
	# Boss arena: ring of ice crystals around the frozen lake, broken pillars.
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var p := Vector3(0, 0, -104) + Vector3(cos(a), 0, sin(a)) * 17.0
		if absf(p.x) < 5.0 and p.z > -100.0:
			continue  # keep the entrance clear
		_crystals(p, 3)
	for p: Vector3 in [Vector3(-17, 0, -88), Vector3(17, 0, -88), Vector3(-17, 0, -121), Vector3(17, 0, -121)]:
		var pil := _prop("dungeon/pillar", p, 0.0, true)
		_frost(pil)
	for i in 4:
		var lp := Vector3(-17 + 34 * (i % 2), 0, -96 - 16 * floori(i * 0.5))
		omni(lp + Vector3(0, 2.5, 0), ICE_C, 1.6, 12.0)
	omni(Vector3(0, 6, -104), Color(0.6, 0.85, 1.0), 2.0, 22.0)


func _prop(rel: String, pos: Vector3, yaw: float, solid: bool, scl: float = 1.0) -> Node3D:
	var n := piece(rel, pos, yaw, scl)
	if solid and n != null:
		add_piece_collision(n)
	return n


func _campfire(p: Vector3) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		_frost(piece_fit("nature/Rock_1_A_Color1", p + Vector3(cos(a), 0, sin(a)) * 0.9, a, 0.6))
	var fire := piece("dungeon/torch_lit", p + Vector3(0, 0.4, 0), 0.0, 1.3)
	if fire != null:
		fire.name = "Campfire"
	omni(p + Vector3(0, 1.4, 0), Color(1.0, 0.6, 0.25), 2.2, 10.0, false)
	add_box(p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.6))


func _crystals(p: Vector3, n: int) -> void:
	for i in n:
		var mi := MeshInstance3D.new()
		var pr := PrismMesh.new()
		var h := rng.randf_range(1.4, 3.2)
		pr.size = Vector3(rng.randf_range(0.5, 0.9), h, rng.randf_range(0.5, 0.9))
		mi.mesh = pr
		mi.material_override = _crystal_mat
		mi.position = p + Vector3(rng.randf_range(-1.0, 1.0), h * 0.5 - 0.1, rng.randf_range(-1.0, 1.0))
		mi.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
		geo.add_child(mi)
	add_box(p + Vector3(0, 1.0, 0), Vector3(1.8, 2.0, 1.8))


func build_lighting() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.45, 0.66)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_bottom_color = Color(0.5, 0.56, 0.64)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var we := make_environment(Color(0.6, 0.7, 0.85), Color(0.62, 0.7, 0.85), 0.7, Color(0.72, 0.8, 0.92), 0.007, sky)
	we.environment.fog_aerial_perspective = 0.3
	sun(Vector3(-48, 28, 0), Color(0.86, 0.92, 1.0), 1.15, true)
