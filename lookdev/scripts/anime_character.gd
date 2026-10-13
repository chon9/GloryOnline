class_name LdCharacter
extends Node3D
## Anime character for the look-dev slice:
##   VRoid CC0 base (converted by tools/vrm2glb.py, retargeted to SkeletonProfileHumanoid at import)
##   + toon/outline materials with per-material recolour ("dress")
##   + procedural costume pieces and weapon attached to humanoid bones
##   + Mesh2Motion CC0 clips (retargeted at import) played through one AnimationPlayer
##   + VRM spring-bone chains (hair, skirt) driven by Godot's SpringBoneSimulator3D.

const ANIM_SOURCES := ["res://lookdev/assets/anims/human-base-animations.glb", "res://lookdev/assets/anims/human-addon-animations.glb"]
const TOON := preload("res://lookdev/shaders/toon.gdshader")
const OUTLINE := preload("res://lookdev/shaders/toon_outline.gdshader")

static var _lib: AnimationLibrary

var skeleton: Skeleton3D
var anim: AnimationPlayer
var model: Node3D
var cfg: Dictionary
var springs: Node
var _queue: Array = []
var _two_hand: Node3D
var _two_hand_rest: Transform3D


static func anim_library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for path in ANIM_SOURCES:
		var src: Node = (load(path) as PackedScene).instantiate()
		var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for an in lib.get_animation_list():
				var a := (lib.get_animation(an) as Animation).duplicate(true) as Animation
				for t in range(a.get_track_count() - 1, -1, -1):
					var p := String(a.track_get_path(t))
					# root motion off: the Root bone and Hips horizontal travel are dropped / kept in place by the game
					if p.ends_with(":Root") or not p.contains(":"):
						a.remove_track(t)
						continue
					a.track_set_path(t, NodePath(p.replace("Armature/GeneralSkeleton", "GeneralSkeleton")))
				_lib.add_animation(StringName(an), a)
		src.free()
	return _lib


func _init(config: Dictionary) -> void:
	cfg = config
	name = config.get("name", "Character")


func _ready() -> void:
	model = (load(cfg["model"]) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.find_child("GeneralSkeleton", true, false)
	_dress()
	_springs()
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = anim.get_path_to(skeleton.get_parent())
	anim.add_animation_library(&"", anim_library())
	if cfg.has("build"):
		(cfg["build"] as Callable).call(self)
	play(cfg.get("idle", "Idle_A"))


func play(clip: String, blend := 0.15, speed := 1.0, loop := true) -> void:
	if not anim.has_animation(clip):
		push_warning("LdCharacter: missing clip " + clip)
		return
	var a := anim.get_animation(clip)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(clip, blend, speed)


## Pose the character exactly at a given time of a clip (used for screenshots).
func pose(clip: String, t: float) -> void:
	play(clip, 0.0, 1.0, false)
	anim.seek(t, true)
	anim.pause()


func bone_xf(bone: String) -> Transform3D:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone))


## Attach a node to a humanoid bone. `model_xf` is authored in character space (rest pose, metres, +Y up,
## character facing +Z), so costume pieces can be placed without knowing bone axes.
func attach(bone: String, node: Node3D, model_xf := Transform3D.IDENTITY) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	ba.add_child(node)
	node.transform = bone_xf(bone).affine_inverse() * model_xf
	return node


## Two-handed weapons (lance, polearms): after every skeleton update, swing the weapon about the right
## fist so its shaft passes through the left palm whenever the left hand is close to the shaft line.
## Cheap aim-constraint "IK" that keeps both fists on the shaft without authored spear clips.
func enable_two_hand(weapon: Node3D) -> void:
	_two_hand = weapon
	_two_hand_rest = weapon.transform
	skeleton.skeleton_updated.connect(_solve_two_hand)


func _solve_two_hand() -> void:
	var rh := skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
	var lh := skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand"))
	var w := rh * _two_hand_rest
	var y := w.basis.y.normalized()
	var palm := lh.origin + lh.basis.y.normalized() * 0.075
	var d := palm - w.origin
	var L := d.length()
	if L < 0.1 or L > 0.8:
		_two_hand.transform = _two_hand_rest
		return
	var tgt := d / L
	if tgt.dot(y) < 0.0:
		tgt = -tgt
	if tgt.dot(y) < 0.2:      # left hand is busy elsewhere (casting, swinging wide): keep the authored grip
		_two_hand.transform = _two_hand_rest
		return
	var b := Basis(Quaternion(y, tgt)) * w.basis
	_two_hand.transform = rh.affine_inverse() * Transform3D(b, w.origin)


func bone_pos(bone: String) -> Vector3:
	return bone_xf(bone).origin


# ---------------------------------------------------------------- materials

func _dress() -> void:
	var dress: Dictionary = cfg.get("dress", {})
	var base_rim: Color = cfg.get("rim", Color(1.0, 0.89, 0.69))
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			var tex := src.albedo_texture
			var col := src.albedo_color
			var opt: Dictionary = {}
			for key in dress:
				if nm.contains(key):
					opt = dress[key]
					break
			if opt.get("hide", false):
				var hm := StandardMaterial3D.new()
				hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				hm.albedo_color = Color(0, 0, 0, 0)
				(m as MeshInstance3D).set_surface_override_material(s, hm)
				continue
			if nm.ends_with("_EYE") or (nm.ends_with("_FACE") and not nm.contains("Mouth")):
				# eyes, lashes, brows: flat anime paint, no lighting, no outline
				var em := StandardMaterial3D.new()
				em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				em.albedo_texture = tex
				em.albedo_color = opt.get("color", col)
				em.transparency = src.transparency
				em.alpha_scissor_threshold = src.alpha_scissor_threshold
				em.render_priority = 1 + s
				if nm.contains("Highlight") or nm.contains("EyeExtra"):
					em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if nm.contains("EyeExtra") else BaseMaterial3D.BLEND_MODE_MIX
				if nm.contains("Iris") and opt.has("iris"):
					em.albedo_color = opt["iris"]
				(m as MeshInstance3D).set_surface_override_material(s, em)
				continue
			var sm := ShaderMaterial.new()
			sm.shader = TOON
			sm.set_shader_parameter("albedo_tex", tex if tex else LdGear.white_tex())
			sm.set_shader_parameter("albedo_mul", opt.get("mul", col))
			sm.set_shader_parameter("alpha_cut", 0.5)
			sm.set_shader_parameter("rim_color", base_rim)
			sm.set_shader_parameter("rim_strength", opt.get("rim_strength", 0.55))
			var is_skin := nm.ends_with("_SKIN")
			var is_hair := nm.contains("HAIR")
			sm.set_shader_parameter("shade_tint", opt.get("shade", Color("#D9A08C") / Color("#F6DCCB") if is_skin else (Color(0.55, 0.55, 0.8) if is_hair else Color(0.62, 0.66, 0.86))))
			if nm.contains("Face_00_SKIN"):
				sm.set_shader_parameter("shade_shift", 0.45)   # faces stay clean: shadow only at grazing angles
			if opt.has("map"):
				var mp: Array = opt["map"]
				sm.set_shader_parameter("recolor_mode", 1)
				sm.set_shader_parameter("map_dark", mp[0])
				sm.set_shader_parameter("map_mid", mp[1])
				sm.set_shader_parameter("map_light", mp[2])
				sm.set_shader_parameter("map_contrast", opt.get("contrast", 1.4))
				sm.set_shader_parameter("albedo_mul", Color.WHITE)
			elif opt.has("hue"):
				sm.set_shader_parameter("recolor_mode", 2)
				sm.set_shader_parameter("hue_target", opt["hue"])
				sm.set_shader_parameter("hue_sat_boost", opt.get("sat", 1.2))
				sm.set_shader_parameter("hue_min_sat", opt.get("min_sat", 0.18))
			# outline (coloured, never black)
			var o := ShaderMaterial.new()
			o.shader = OUTLINE
			if opt.has("map"):
				o.set_shader_parameter("albedo_tex", LdGear.white_tex())
				o.set_shader_parameter("albedo_mul", (opt["map"] as Array)[1])
				o.set_shader_parameter("darken", 0.55)
			else:
				o.set_shader_parameter("albedo_tex", tex if tex else LdGear.white_tex())
				o.set_shader_parameter("albedo_mul", opt.get("mul", col))
				o.set_shader_parameter("darken", 0.32 if not is_skin else 0.28)
			o.set_shader_parameter("alpha_cut", 0.5)
			o.set_shader_parameter("width_px", opt.get("line", 1.7 if is_hair else 1.5))
			if not nm.contains("Mouth"):
				sm.next_pass = o
			(m as MeshInstance3D).set_surface_override_material(s, sm)
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# ---------------------------------------------------------------- secondary motion

func _springs() -> void:
	if not ClassDB.class_exists(&"SpringBoneSimulator3D"):
		return
	var side_path: String = String(cfg["model"]).get_basename() + ".vrm.json"
	if not FileAccess.file_exists(side_path):
		return
	var side: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(side_path))
	var sim: Node = ClassDB.instantiate(&"SpringBoneSimulator3D")
	skeleton.add_child(sim)
	var chains: Array = []
	for g in side.get("springs", []):
		for root in g["bones"]:
			var ri := skeleton.find_bone(root)
			if ri < 0:
				continue
			var end := ri
			while skeleton.get_bone_children(end).size() > 0:
				end = skeleton.get_bone_children(end)[0]
			if end == ri:
				continue
			chains.append([ri, end, g])
	sim.set("setting_count", chains.size())
	for i in chains.size():
		var g: Dictionary = chains[i][2]
		sim.call("set_root_bone", i, chains[i][0])
		sim.call("set_end_bone", i, chains[i][1])
		sim.call("set_extend_end_bone", i, true)
		sim.call("set_end_bone_length", i, 0.05)
		sim.call("set_stiffness", i, clampf(float(g.get("stiffness", 1.0)) * 0.5, 0.1, 4.0))
		sim.call("set_drag", i, clampf(float(g.get("drag", 0.4)), 0.05, 1.0))
		sim.call("set_gravity", i, clampf(float(g.get("gravity", 0.0)), 0.0, 1.0))
		sim.call("set_radius", i, clampf(float(g.get("radius", 0.02)), 0.005, 0.1))
	springs = sim
