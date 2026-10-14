extends SubViewportContainer
## Character showcase for menus (class picker, main menu): own World3D with a key/rim light set, a gold rune
## pedestal and CharacterVisual.create_for_class(class_id) slowly turning on it. Transparent background so the
## navy UI shows through. Rebuilds only when the class changes.

const GD := preload("res://ui/glory_draw.gd")

var class_id: String = ""
## true: head-and-shoulders bust for HUD portraits (no turning, no pedestal)
var head_shot: bool = false
var turn_speed: float = 0.35
var yaw: float = 0.45
var cam_dist: float = 4.2
var vp: SubViewport
var cam: Camera3D
var pivot: Node3D
var visual: Node3D = null
var _pedestal: MeshInstance3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.85)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-38), deg_to_rad(35), 0)
	key.light_energy = 1.35
	key.light_color = Color(1.0, 0.94, 0.84)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
	rim.light_energy = 1.6
	rim.light_color = Color(0.45, 0.7, 1.0)
	vp.add_child(rim)
	pivot = Node3D.new()
	vp.add_child(pivot)
	_pedestal = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.7
	cyl.height = 0.1
	_pedestal.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.05, 0.07, 0.13)
	pm.metallic = 0.2
	pm.roughness = 0.7
	_pedestal.material_override = pm
	_pedestal.position = Vector3(0, -0.05, 0)
	vp.add_child(_pedestal)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.64
	tm.outer_radius = 0.68
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.8, 0.4)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.75, 0.3)
	rm.emission_energy_multiplier = 1.5
	ring.material_override = rm
	ring.position = Vector3(0, 0.005, 0)
	vp.add_child(ring)
	cam = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)


func set_class(id: String) -> void:
	if id == class_id and visual != null:
		return
	class_id = id
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	visual = null
	var kit := CoreUtil.get_kit(id)
	if kit == null:
		return
	if DisplayServer.get_name() == "headless":
		return   # nothing is rendered; keep headless tests fast
	var v: Variant = CharacterVisual.create_for_class(id, kit.weapon_type, kit.offhand)
	if v is Node3D:
		visual = v
		pivot.add_child(visual)
	_frame()


func _frame() -> void:
	# fit the whole figure (weapon included) from its mesh bounds; one frame later the skeleton has posed
	var h := 1.8
	if visual != null and "height" in visual:
		h = float(visual.get("height"))
	_aim(Vector3(0, h * 0.5, 0), h)
	if visual != null:
		_refit.call_deferred()


func _refit() -> void:
	if visual == null or not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if visual == null or not is_instance_valid(visual):
		return
	var box := AABB()
	var first := true
	for n: Node in visual.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi == null or not vi.visible or vi is GPUParticles3D:
			continue
		var b := vi.global_transform * vi.get_aabb()
		if b.size.length() > 40.0:
			continue
		box = b if first else box.merge(b)
		first = false
	if head_shot and visual.has_method("get_head_position"):
		var hp: Vector3 = visual.call("get_head_position")
		var eye := hp - Vector3(0, 0.22, 0)
		cam.fov = 26.0
		# the anime rigs face -Z in their own space: shoot the bust from the front, a little off-axis
		cam.position = eye + Vector3(-0.3, 0.05, -1.05)
		cam.look_at(eye + Vector3(0, -0.04, 0), Vector3.UP)
		return
	if first:
		return
	var top := maxf(box.end.y, 0.5)
	var center := Vector3(0, top * 0.5, 0)
	_aim(center, top)


func _aim(center: Vector3, tall: float) -> void:
	var fit_h := tall * 1.18 + 0.2
	cam_dist = fit_h / (2.0 * tan(deg_to_rad(cam.fov * 0.5)))
	cam.position = Vector3(0, center.y + tall * 0.06, cam_dist)
	cam.look_at(center + Vector3(0, tall * 0.02, 0), Vector3.UP)


func set_head_shot(on: bool) -> void:
	head_shot = on
	turn_speed = 0.0 if on else turn_speed
	yaw = 0.0 if on else yaw
	pivot.rotation.y = yaw
	_pedestal.visible = not on
	for c: Node in vp.get_children():
		if c is MeshInstance3D and c != _pedestal and (c as MeshInstance3D).mesh is TorusMesh:
			(c as MeshInstance3D).visible = not on
	vp.size = Vector2i(192, 192) if on else Vector2i(512, 512)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or head_shot:
		return
	yaw += delta * turn_speed
	pivot.rotation.y = yaw
