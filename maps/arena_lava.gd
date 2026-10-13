extends ArenaMap
## 熔岩洞 Lava Cave - 40 m duel / arena map in a volcanic cavern. A lava river splits the floor; cross it
## over the raised central basalt keep (2 m high ground, ramps north and south) or the two stone bridges on
## the flanks. Lava also runs along the east and west edges - knockbacks near the walls are dangerous.
## Lava is flush with the floor: walking in it is possible but burns (host-side hazard tick).

const HALF: float = 20.0
const KEEP_H: float = 2.0
const KEEP_HALF: float = 4.0
## Fraction of max hp dealt per hazard tick and the tick period.
const LAVA_DMG: float = 0.04
const LAVA_TICK: float = 0.5

var _lava_timer: float = 0.0

const LAVA_SHADER: String = """
shader_type spatial;
render_mode cull_back;
uniform vec4 hot : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform vec4 cool : source_color = vec4(0.55, 0.06, 0.02, 1.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * 0.45;
	float t = TIME * 0.18;
	float v = n(p + vec2(t, t * 0.6)) * 0.6 + n(p * 2.3 - vec2(t * 1.3, -t)) * 0.4;
	float crack = smoothstep(0.42, 0.62, v);
	vec3 c = mix(cool.rgb * 0.6, hot.rgb, crack);
	ALBEDO = c * 0.35;
	ROUGHNESS = 0.6;
	EMISSION = c * (0.45 + 1.25 * crack);
}
"""


func _init() -> void:
	map_id = "lava_cave"
	name_cn = "熔岩洞"
	name_en = "Lava Cave"
	size = Vector2(40.0, 40.0)
	center = Vector3.ZERO


## True when an XZ position is over lava (flush with the floor).
func is_hazard(pos: Vector3) -> bool:
	return pos.y < 0.4 and is_lava(pos)


static func is_lava(p: Vector3) -> bool:
	var ax := absf(p.x)
	if ax > HALF - 2.0:
		return true
	if absf(p.z) < 2.0 and ax > KEEP_HALF and absf(ax - 12.0) > 2.0:
		return true
	return false


func _build_map() -> void:
	setup_environment({
		"sky_top": Color(0.05, 0.03, 0.03), "sky_horizon": Color(0.28, 0.08, 0.04),
		"ground": Color(0.05, 0.02, 0.02), "fog_color": Color(0.4, 0.13, 0.07), "fog_density": 0.007,
		"sun_pitch": -65.0, "sun_yaw": 20.0, "sun_energy": 0.55, "sun_color": Color(1.0, 0.6, 0.45),
		"ambient": Color(0.55, 0.42, 0.4), "ambient_energy": 0.5, "glow": 0.9,
	})
	var D := MapKit.D
	var N := MapKit.N
	# ---- cave floor: rocky tiles everywhere except lava cells (one collision slab, lava is walkable)
	var skip := func(c: Vector3) -> bool: return is_lava(c)
	kit.floor_grid(Rect2(-22, -22, 44, 44), 0.0, D + "floor_tile_large.gltf", skip,
		[D + "floor_dirt_large.gltf"], 0.3, true)
	var rock_mat := MapKit.mat(Color(0.16, 0.13, 0.12), 1.0)
	kit.box_visual(Vector3(0, -0.6, 0), Vector3(160, 1.0, 160), rock_mat, 0.0, false)
	# ---- lava (visual only; the floor slab is under it)
	var lava := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LAVA_SHADER
	lava.shader = sh
	for sx: float in [-1.0, 1.0]:
		kit.box_visual(Vector3(sx * 21.0, -0.13, 0), Vector3(6.0, 0.3, 48.0), lava, 0.0, false)
		for seg: Vector2 in [Vector2(4.0, 10.0), Vector2(14.0, 18.0)]:
			var cx := sx * (seg.x + seg.y) * 0.5
			kit.box_visual(Vector3(cx, -0.13, 0), Vector3(seg.y - seg.x, 0.3, 4.0), lava, 0.0, false)
	kit.box_visual(Vector3(0, -0.13, 0), Vector3(8.0, 0.3, 4.0), lava, 0.0, false)   # under the keep
	# glowing lava lights
	for p: Vector3 in [Vector3(-7, 0.8, 0), Vector3(7, 0.8, 0), Vector3(-19, 1.0, -9), Vector3(19, 1.0, 9),
			Vector3(-19, 1.0, 10), Vector3(19, 1.0, -10)]:
		add_omni(p, Color(1.0, 0.45, 0.15), 2.2, 9.0)
	# rock rims along the river (small, visual only)
	for i in 36:
		var x := kit.rng.randf_range(-17.5, 17.5)
		if absf(x) < 4.5 or absf(absf(x) - 12.0) < 2.3:
			continue
		var z := (2.1 + kit.rng.randf() * 0.3) * (1.0 if i % 2 == 0 else -1.0)
		kit.piece(N + "Rock_6_A_Color1.gltf", Vector3(x, 0, z), kit.rng.randf() * 360.0, Vector3.ONE * kit.rng.randf_range(1.0, 1.6), false)
	# ---- stone bridges over the river on the flanks (stone slabs, slight edge rails at the ends)
	for sx: float in [-1.0, 1.0]:
		for bz: float in [-2.6, 2.6]:
			kit.piece(D + "barrier_column.gltf", Vector3(sx * 9.6, 0, bz), 90.0, Vector3(0.5, 1.0, 1.0))
			kit.piece(D + "barrier_column.gltf", Vector3(sx * 14.4, 0, bz), 90.0, Vector3(0.5, 1.0, 1.0))
			kit.col_box(Vector3(sx * 9.6, 0.7, bz), Vector3(2.0, 1.4, 0.7), 90.0, "BridgePost")
			kit.col_box(Vector3(sx * 14.4, 0.7, bz), Vector3(2.0, 1.4, 0.7), 90.0, "BridgePost")
		add_torch(Vector3(sx * 9.6, 1.4, -2.6), false, false)
		add_torch(Vector3(sx * 14.4, 1.4, 2.6), false, false)
	# ---- the basalt keep (high ground) spanning the river
	kit.platform(Rect2(-4.0, -4.0, 8.0, 8.0), KEEP_H)
	kit.ramp(Vector3(0, KEEP_H, -4.0), 180.0, 6.0, 4.0)
	kit.ramp(Vector3(0, KEEP_H, 4.0), 0.0, 6.0, 4.0)
	for sx: float in [-1.0, 1.0]:
		kit.piece(D + "barrier_column.gltf", Vector3(sx * 3.5, KEEP_H, 0), 90.0, Vector3(1.0, 1.0, 1.0))
		kit.col_box(Vector3(sx * 3.5, KEEP_H + 0.7, 0), Vector3(4.0, 1.4, 0.7), 90.0, "KeepRail")
	kit.piece(D + "column.gltf", Vector3(-3.3, KEEP_H, -3.3))
	kit.piece(D + "column.gltf", Vector3(3.3, KEEP_H, 3.3))
	kit.col_cyl(Vector3(-3.3, KEEP_H, -3.3), 0.35, 1.4)
	kit.col_cyl(Vector3(3.3, KEEP_H, 3.3), 0.35, 1.4)
	add_torch(Vector3(-3.3, KEEP_H + 1.4, -3.3), true, false)
	add_torch(Vector3(3.3, KEEP_H + 1.4, 3.3), false, false)
	# ---- stalagmites / boulders (LOS breakers, convex collision)
	for p: Vector3 in [Vector3(-8.0, 0, -9.0), Vector3(8.0, 0, 9.0), Vector3(9.0, 0, -8.5), Vector3(-9.0, 0, 8.5)]:
		kit.rock("Rock_4_A_Color1.gltf", p, p.x * 11.0 + p.z, Vector3(4.5, 6.5, 4.5))
		kit.rock("Rock_4_B_Color1.gltf", p + Vector3(signf(p.x) * 1.4, 0, -signf(p.z) * 0.6), p.z * 13.0, Vector3(3.2, 3.5, 3.2))
	for p: Vector3 in [Vector3(-14.0, 0, -13.0), Vector3(14.0, 0, 13.0)]:
		kit.rock("Rock_3_C_Color1.gltf", p + Vector3(0, 0.6, 0), p.x * 7.0, Vector3(3.0, 3.0, 3.0))
	for p: Vector3 in [Vector3(14.0, 0, -12.5), Vector3(-14.0, 0, 12.5)]:
		kit.rock("Rock_1_D_Color1.gltf", p, p.z * 5.0, Vector3(3.0, 4.5, 3.0))
	# ---- cavern walls: invisible boundary + huge rocks outside
	for s: float in [-1.0, 1.0]:
		kit.col_box(Vector3(s * (HALF + 1.0), 10.0, 0), Vector3(2.0, 24.0, 2.0 * HALF + 4.0), 0.0, "Bound")
		kit.col_box(Vector3(0, 10.0, s * (HALF + 1.0)), Vector3(2.0 * HALF + 4.0, 24.0, 2.0), 0.0, "Bound")
	var big: Array[String] = ["Rock_1_A_Color1.gltf", "Rock_1_E_Color1.gltf", "Rock_1_H_Color1.gltf", "Rock_1_K_Color1.gltf"]
	for i in 40:
		var side := i % 4
		var along := (float(i / 4) / 9.0 * 2.0 - 1.0) * (HALF + 3.0)
		var out := HALF + 6.5 + kit.rng.randf() * 2.0
		var p: Vector3
		match side:
			0: p = Vector3(along, -0.5, -out)
			1: p = Vector3(along, -0.5, out)
			2: p = Vector3(-out, -0.5, along)
			_: p = Vector3(out, -0.5, along)
		var bs: float = kit.rng.randf_range(6.0, 8.0) / maxf(0.6, MapKit.piece_aabb(N + big[i % big.size()]).size.x)
		kit.piece(N + big[i % big.size()], p, kit.rng.randf() * 360.0, Vector3(bs, bs * kit.rng.randf_range(1.6, 2.4), bs))
	test_walks = [
		{"name": "keep ramp", "from": Vector3(0, 0, -13), "to": Vector3(0, KEEP_H, -1), "min_y": KEEP_H - 0.3},
		{"name": "flank bridge", "from": Vector3(-12, 0, -8), "to": Vector3(-12, 0, 8), "min_y": -1.0},
	]
	# ---- spawns (north blue / south red), away from the lava
	set_spawns_line(0, Vector3(0, 0, -16.0), Vector3.RIGHT, 2.2)
	set_spawns_line(1, Vector3(0, 0, 16.0), Vector3.RIGHT, 2.2)


# ================================================================== hazard (host only)
func _physics_process(delta: float) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.is_server():
		return
	_lava_timer += delta
	if _lava_timer < LAVA_TICK:
		return
	_lava_timer -= LAVA_TICK
	var w := World.get_instance()
	if w == null:
		return
	for f: Fighter in w.fighters:
		if not is_instance_valid(f) or not f.is_alive():
			continue
		var p := f.global_position
		if p.y > 0.4 or not is_lava(p):
			continue
		f.take_dot_damage(f.max_hp * LAVA_DMG, null, &"burn")
		f.add_status(&"slow", 0.6, 0.25)
		CoreUtil.fx(&"play", [&"fire_burst", p, Vector3.FORWARD, Color(1.0, 0.5, 0.15), 0.5])
