class_name AnimeBody
extends Node3D
## Anime player body (ported from lookdev LdCharacter): a converted VRoid CC0 base, retargeted to
## SkeletonProfileHumanoid at import ("GeneralSkeleton"), dressed by a ClassDress entry:
##   - every VRoid material is replaced by the toon + outline shaders with per-material recolour ("dress")
##   - procedural costume pieces are attached to humanoid bones by the dress `build` callable
##   - all anime bodies share ONE AnimationLibrary (Mesh2Motion CC0 clips + KayKit gap-filler clips, both
##     retargeted at import) played by one AnimationPlayer per body
##   - VRM spring chains (hair, skirts, ribbons) run in Godot's SpringBoneSimulator3D
## The body faces +Z (VRoid after the facing fix); CharacterVisual rotates it to face -Z.
## Costume authoring space ("character space"): rest (T) pose, metres, +Y up, facing +Z, right hand at -X.

const ANIM_SOURCES: Array[String] = ["res://assets/anims/anime/human-base-animations.glb", "res://assets/anims/anime/human-addon-animations.glb"]
## KayKit Rig_Medium packs retargeted through assets/characters/anime/retarget/kaykit.tres. Their clips get the
## "kk_" prefix (KayKit and Mesh2Motion share names such as Idle_A / Death_A).
const KAYKIT_SOURCES: Array[String] = ["res://assets/anims/anime/kaykit_combat_melee.glb", "res://assets/anims/anime/kaykit_combat_ranged.glb"]
const TOON := preload("res://visuals/shaders/toon.gdshader")
const OUTLINE := preload("res://visuals/shaders/toon_outline.gdshader")
const SKIN_SHADE := Color(0.8822, 0.7270, 0.6923)   # #D9A08C / #F6DCCB

static var _lib: AnimationLibrary
## false = legacy per-bone merge (AnimeGear.merge_static per attachment); A/B switch for tools (gallery --nomerge).
static var skinned_merge := true
## Dressed body materials shared by every instance of a class ("<class>|<source material>"); face materials stay
## per instance (their head-axis uniforms are written per body every frame).
static var _mat_cache: Dictionary = {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var model: Node3D
var cfg: Dictionary
var springs: Node
var meshes: Array[MeshInstance3D] = []
var natural_height := 1.6
var _two_hand: Node3D
var _two_hand_rest: Transform3D
var _two_hand_connected := false
var face_mats: Array[ShaderMaterial] = []   # special = 2 face materials (head axes updated per frame)
var _atts: Dictionary = {}          # bone -> BoneAttachment3D (one per bone, so costume pieces merge per bone)


## Shared library: every clip of every source, track paths re-rooted to "GeneralSkeleton:<bone>", root motion
## (the Root bone) dropped. `loop_clips` are set to LOOP_LINEAR, everything else LOOP_NONE.
static func anim_library(loop_clips: Array = []) -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for path in ANIM_SOURCES + KAYKIT_SOURCES:
		var ps := load(path) as PackedScene
		if ps == null:
			push_error("AnimeBody: missing animation pack " + path)
			continue
		var kk := path in KAYKIT_SOURCES
		var src: Node = ps.instantiate()
		var ap := src.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for lib_name in ap.get_animation_library_list():
				var lib := ap.get_animation_library(lib_name)
				for an in lib.get_animation_list():
					if String(an) in ["T-Pose", "Rest Pose"]:
						continue
					var a := (lib.get_animation(an) as Animation).duplicate(true) as Animation
					for t in range(a.get_track_count() - 1, -1, -1):
						var p := String(a.track_get_path(t))
						var bone := p.get_slice(":", 1) if p.contains(":") else ""
						if bone == "" or bone == "Root":
							a.remove_track(t)
							continue
						# KayKit position keys only make sense on the hips (other bones keep the target's rest)
						if kk and a.track_get_type(t) == Animation.TYPE_POSITION_3D and bone != "Hips":
							a.remove_track(t)
							continue
						a.track_set_path(t, NodePath("GeneralSkeleton:" + bone))
					var nm := ("kk_" + String(an)) if kk else String(an)
					a.loop_mode = Animation.LOOP_LINEAR if nm in loop_clips else Animation.LOOP_NONE
					_lib.add_animation(StringName(nm), a)
		src.free()
	return _lib


func _init(config: Dictionary = {}) -> void:
	cfg = config
	name = "AnimeBody"


## Builds the body synchronously (CharacterVisual needs the skeleton right after create()).
func build(loop_clips: Array) -> void:
	var ps := load(String(cfg.get("model", ""))) as PackedScene
	if ps == null:
		push_error("AnimeBody: missing base model " + String(cfg.get("model", "")))
		return
	model = ps.instantiate() as Node3D
	model.name = "Base"
	add_child(model)
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		push_error("AnimeBody: no GeneralSkeleton in " + String(cfg.get("model", "")))
		return
	for m in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m as MeshInstance3D)
	_cull()
	_dress()
	_expressions()
	_springs()
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.root_node = anim.get_path_to(skeleton.get_parent())
	anim.add_animation_library(&"", anim_library(loop_clips))
	var prop: Array = cfg.get("proportions", [1.05, 0.95])
	proportions(float(prop[0]), float(prop[1]))
	var head := bone_pos("Head")
	natural_height = head.y + (head.y - bone_pos("Neck").y) * 2.6 + float(get_meta("leg_lift", 0.0))
	ClassDress.build_costume(self, cfg)
	_merge_floaters()
	if skinned_merge:
		_merge_costume()
	else:
		for ba in _atts.values():
			AnimeGear.merge_static(ba as Node3D)
	# costume pieces are part of the body for status overlays
	for m in skeleton.find_children("*", "MeshInstance3D", true, false):
		if not (m as MeshInstance3D) in meshes and not _is_weapon(m):
			meshes.append(m as MeshInstance3D)


## Draw-call optimisation (the big one): costume pieces are authored as dozens of small meshes on BoneAttachments.
## Every rigid piece (material_override, one surface, no children, nothing scripted above it) is baked into ONE
## skinned mesh for the whole body - one surface per material, each vertex bound 100 % to the bone its piece hung
## from (bind = inverse global rest, so skinning reproduces the BoneAttachment exactly, incl. pose scale).
## Transparent / additive materials go to a second skinned mesh without shadows. A dressed body then costs
## "base surfaces + costume materials" draws instead of "materials per bone" (~60 -> ~25 surfaces).
func _merge_costume() -> void:
	var groups: Dictionary = {}      # Material -> Array[[Mesh, Transform3D (skeleton space), bind index]]
	var order: Array = []
	var victims: Array[MeshInstance3D] = []
	var sk := Skin.new()
	var bind_of: Dictionary = {}     # bone index -> bind index
	for bone: String in _atts:
		var ba: BoneAttachment3D = _atts[bone]
		var bi := skeleton.find_bone(bone)
		if bi < 0:
			continue
		var rest := skeleton.get_bone_global_rest(bi)
		for n in ba.find_children("*", "MeshInstance3D", true, false):
			var m := n as MeshInstance3D
			if not _rigid_piece(m, ba):
				continue
			if not bind_of.has(bi):
				bind_of[bi] = sk.get_bind_count()
				sk.add_bind(bi, rest.affine_inverse())
			var mat := m.material_override
			if not groups.has(mat):
				groups[mat] = []
				order.append(mat)
			(groups[mat] as Array).append([m.mesh, rest * AnimeGear.rel_xf(m, ba), int(bind_of[bi])])
			victims.append(m)
	if victims.is_empty():
		return
	var solid := ArrayMesh.new()
	var fx := ArrayMesh.new()
	for mat: Material in order:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var idx := PackedInt32Array()
		for item: Array in groups[mat]:
			var arr := (item[0] as Mesh).surface_get_arrays(0)
			var xf: Transform3D = item[1]
			var nb := xf.basis.inverse().transposed()
			var bind: int = item[2]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: Variant = arr[Mesh.ARRAY_NORMAL]
			var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
			var ii: Variant = arr[Mesh.ARRAY_INDEX]
			var has_n := nn is PackedVector3Array and (nn as PackedVector3Array).size() == v.size()
			var has_uv := uv is PackedVector2Array and (uv as PackedVector2Array).size() == v.size()
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
				norms.append((nb * (nn as PackedVector3Array)[k]).normalized() if has_n else Vector3.UP)
				uvs.append((uv as PackedVector2Array)[k] if has_uv else Vector2.ZERO)
				bones.append(bind)
				bones.append(0)
				bones.append(0)
				bones.append(0)
				weights.append(1.0)
				weights.append(0.0)
				weights.append(0.0)
				weights.append(0.0)
			if ii is PackedInt32Array and (ii as PackedInt32Array).size() > 0:
				for k in (ii as PackedInt32Array):
					idx.append(base + k)
			else:
				for k in v.size():
					idx.append(base + k)
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = norms
		out[Mesh.ARRAY_TEX_UV] = uvs
		out[Mesh.ARRAY_BONES] = bones
		out[Mesh.ARRAY_WEIGHTS] = weights
		out[Mesh.ARRAY_INDEX] = idx
		var transparent := mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		var target := fx if transparent else solid
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		target.surface_set_material(target.get_surface_count() - 1, mat)
	for v in victims:
		v.get_parent().remove_child(v)
		v.free()
	for ba: Node in _atts.values():
		_prune_empty(ba)
	for pair: Array in [[solid, "Costume", true], [fx, "CostumeFx", false]]:
		var am: ArrayMesh = pair[0]
		if am.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = pair[1]
		mi.mesh = am
		mi.skin = sk
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pair[2] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")


func _rigid_piece(m: MeshInstance3D, ba: Node) -> bool:
	if m is AnimeCloth or m.mesh == null or m.material_override == null or m.get_child_count() > 0:
		return false
	if m.mesh.get_surface_count() != 1:
		return false
	var p: Node = m
	while p != null and p != ba:
		if p.get_script() != null or (p is Node3D and not (p as Node3D).visible):
			return false
		var nm := String(p.name)
		if nm.begins_with("Panel_") or nm.begins_with("Morph_"):
			return false
		p = p.get_parent()
	return true


## Removes plain Node3D wrappers left empty by the costume merge.
func _prune_empty(n: Node) -> void:
	for c in n.get_children():
		_prune_empty(c)
		if c.get_child_count() == 0 and c.get_class() == "Node3D" and c.get_script() == null:
			n.remove_child(c)
			c.free()


## Floaters (spinning / bobbing orbs, rune rings: dress/_swordmage_lib.gd) move, so they stay out of the skinned
## merge; their pieces are merged per floater instead (one draw per material) and do not cast shadows.
func _merge_floaters() -> void:
	for ba: Node in _atts.values():
		for f in ba.find_children("*", "Node3D", true, false):
			if not is_instance_valid(f) or f.get_script() == null or f is AnimeCloth or f is MeshInstance3D:
				continue
			var keeps := f.find_children("Keep", "", true, false)
			if keeps.is_empty():
				continue
			for k in keeps:
				k.get_parent().remove_child(k)
				k.free()
			AnimeGear.merge_static(f as Node3D)
			for m in f.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _is_weapon(n: Node) -> bool:
	var p := n
	while p != null and p != skeleton:
		if String(p.name).begins_with("Weapon_"):
			return true
		p = p.get_parent()
	return false


func bone_xf(bone: String) -> Transform3D:
	var i := skeleton.find_bone(bone)
	return skeleton.get_bone_global_rest(i) if i >= 0 else Transform3D.IDENTITY


func bone_pos(bone: String) -> Vector3:
	return bone_xf(bone).origin


## Attach a node to a humanoid bone. `model_xf` is authored in character space (rest pose, metres, +Y up,
## facing +Z, right hand at -X), so costume pieces can be placed without knowing bone axes.
func attach(bone: String, node: Node3D, model_xf := Transform3D.IDENTITY) -> Node3D:
	var ba: BoneAttachment3D = _atts.get(bone)
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = "Att_" + bone
		ba.bone_name = bone
		skeleton.add_child(ba)
		_atts[bone] = ba
	ba.add_child(node)
	node.transform = bone_xf(bone).affine_inverse() * model_xf
	return node


## Taller anime proportions (bible 2.1): longer legs, slightly smaller head. Clips only carry rotations
## (+ hips translation), so the pose scale survives playback.
func proportions(leg := 1.06, head := 0.95) -> void:
	for b in ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]:
		var i := skeleton.find_bone(b)
		if i >= 0:
			skeleton.set_bone_pose_scale(i, Vector3(1.0, leg, 1.0))
	var hi := skeleton.find_bone("Head")
	if hi >= 0:
		skeleton.set_bone_pose_scale(hi, Vector3.ONE * head)
	var leg_len := bone_pos("RightUpperLeg").y - bone_pos("RightFoot").y
	model.position.y = leg_len * (leg - 1.0)
	set_meta("leg_lift", leg_len * (leg - 1.0))
	set_meta("leg_scale", leg)


func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim and anim.has_animation(clip):
		anim.play(clip, blend, speed)


## Pose the body exactly at a time of a clip (screenshots).
func pose(clip: String, t: float) -> void:
	if not anim.has_animation(clip):
		return
	anim.play(clip, 0.0)
	anim.seek(t, true)
	anim.pause()


# ---------------------------------------------------------------- two-handed weapons

## Two-handed weapons (lance, polearms): after every skeleton update, swing the weapon about the right fist so
## its shaft passes through the left palm whenever the left hand is close to the shaft line (cheap aim IK).
func enable_two_hand(weapon: Node3D) -> void:
	_two_hand = weapon
	_two_hand_rest = weapon.transform
	if not _two_hand_connected:
		skeleton.skeleton_updated.connect(_solve_two_hand)
		_two_hand_connected = true


func disable_two_hand() -> void:
	_two_hand = null


func is_two_hand(weapon: Node3D) -> bool:
	return _two_hand == weapon and _two_hand != null


func get_two_hand_rest() -> Transform3D:
	return _two_hand_rest


## New hand-relative rest for the two-handed weapon (per-clip grip changes); the aim solve starts from it.
func set_two_hand_rest(xf: Transform3D) -> void:
	_two_hand_rest = xf
	if _two_hand:
		_two_hand.transform = xf


func _solve_two_hand() -> void:
	if _two_hand == null or not is_instance_valid(_two_hand):
		_two_hand = null
		return
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
	if tgt.dot(y) < 0.2:
		_two_hand.transform = _two_hand_rest
		return
	var b := Basis(Quaternion(y, tgt)) * w.basis
	var s := _two_hand_rest.basis.get_scale()
	var t := rh.affine_inverse() * Transform3D(b, w.origin)
	_two_hand.transform = Transform3D(t.basis.orthonormalized().scaled_local(s), t.origin)


# ---------------------------------------------------------------- materials

## Material "dress": cfg.dress maps a material-name substring to options:
##   map: [dark, mid, light]  gradient-map recolour by luminance (+ contrast)
##   hue: 0..1                hue swap of saturated pixels (+ sat, min_sat)
##   mul: Color               plain multiply      shade: Color   shadow tint (shadow = albedo * tint)
##   iris: Color              eye iris colour     hide: true     hide the surface (replaced by costume)
##   line: float              outline width px    rim_strength: float
func _dress() -> void:
	var dress: Dictionary = cfg.get("dress", {})
	var base_rim: Color = cfg.get("rim", Color(1.0, 0.89, 0.69))
	var cid := String(cfg.get("id", ""))
	for mi in meshes:
		var mesh := mi.mesh
		var face_mesh := false
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			face_mesh = face_mesh or nm.ends_with("_EYE") or nm.contains("Face_00")
			var ck := "%s|%s|%d" % [cid, nm, s]
			if cid != "" and _mat_cache.has(ck):
				mi.set_surface_override_material(s, _mat_cache[ck])
				continue
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
				hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mi.set_surface_override_material(s, hm)
				_mat_cache[ck] = hm
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
				if nm.contains("Brow") and dress.has("Brow"):
					em.albedo_color = (dress["Brow"] as Dictionary).get("color", col)
				mi.set_surface_override_material(s, em)
				_mat_cache[ck] = em
				continue
			var sm := ShaderMaterial.new()
			sm.shader = TOON
			sm.set_shader_parameter("albedo_tex", tex if tex else AnimeGear.white_tex())
			sm.set_shader_parameter("albedo_mul", opt.get("mul", col))
			sm.set_shader_parameter("alpha_cut", 0.5)
			sm.set_shader_parameter("rim_color", base_rim)
			sm.set_shader_parameter("rim_strength", opt.get("rim_strength", 0.55))
			var is_skin := nm.ends_with("_SKIN")
			var is_hair := nm.contains("HAIR")
			sm.set_shader_parameter("shade_tint", opt.get("shade", SKIN_SHADE if is_skin else (Color(0.55, 0.55, 0.8) if is_hair else Color(0.62, 0.66, 0.86))))
			if nm.contains("Face_00_SKIN"):
				# faces: one clean shadow tone driven by the head axes (toon.gdshader special 2), never mesh-normal blotches
				sm.set_shader_parameter("special", 2)
				face_mats.append(sm)
			elif is_hair:
				# hair: broken anisotropic specular streaks (special 1)
				sm.set_shader_parameter("special", 1)
				sm.set_shader_parameter("hair_spec_color", opt.get("spec", Color(1.0, 0.97, 0.9)))
				sm.set_shader_parameter("hair_spec_strength", opt.get("spec_strength", 0.55))
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
			var o := ShaderMaterial.new()
			o.shader = OUTLINE
			if opt.has("map"):
				o.set_shader_parameter("albedo_tex", AnimeGear.white_tex())
				o.set_shader_parameter("albedo_mul", (opt["map"] as Array)[1])
				o.set_shader_parameter("darken", 0.55)
			else:
				o.set_shader_parameter("albedo_tex", tex if tex else AnimeGear.white_tex())
				o.set_shader_parameter("albedo_mul", opt.get("mul", col))
				o.set_shader_parameter("darken", 0.32 if not is_skin else 0.28)
			o.set_shader_parameter("alpha_cut", 0.5)
			o.set_shader_parameter("width_px", opt.get("line", 1.7 if is_hair else 1.5))
			if not nm.contains("Mouth"):
				sm.next_pass = o
			mi.set_surface_override_material(s, sm)
			if not sm in face_mats:
				_mat_cache[ck] = sm
		# the face / eye mesh sits inside the hair: its ~9 surfaces add nothing to the shadow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if face_mesh else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Removes base-clothing triangles inside character-space boxes so they never show through costume pieces
## (e.g. the HairSample_Male hoodie hood under a mantle). cfg.cull = [{mat, min, max, bone?}, ...]:
## `mat` = material-name substring, `min`/`max` = box corners in character space (metres, rest pose, +Z forward),
## relative to the rest position of `bone` when given. A triangle is removed when all 3 vertices are inside a box.
func _cull() -> void:
	var rules: Array = cfg.get("cull", [])
	if rules.is_empty():
		return
	for mi in meshes:
		var src := mi.mesh as ArrayMesh
		if src == null:
			continue
		var hit := false
		for s in src.get_surface_count():
			var mat := src.surface_get_material(s)
			for r in rules:
				if mat and mat.resource_name.contains(String((r as Dictionary).get("mat", ""))):
					hit = true
		if not hit:
			continue
		var out := ArrayMesh.new()
		out.blend_shape_mode = src.blend_shape_mode
		for b in src.get_blend_shape_count():
			out.add_blend_shape(src.get_blend_shape_name(b))
		for s in src.get_surface_count():
			var mat := src.surface_get_material(s)
			var arrays := src.surface_get_arrays(s)
			var boxes: Array = []
			for r in rules:
				var rd := r as Dictionary
				if mat and mat.resource_name.contains(String(rd.get("mat", ""))):
					var o := bone_pos(String(rd["bone"])) if rd.has("bone") else Vector3.ZERO
					boxes.append(AABB(o + (rd["min"] as Vector3), (rd["max"] as Vector3) - (rd["min"] as Vector3)))
			if not boxes.is_empty():
				var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var keep := PackedInt32Array()
				for k in range(0, idx.size(), 3):
					var inside := false
					for bx in boxes:
						var all_in := true
						for j in 3:
							var p := v[idx[k + j]]
							# mesh space is the VRM 0.x frame (faces -Z): character space = (-x, y, -z)
							if not (bx as AABB).has_point(Vector3(-p.x, p.y, -p.z)):
								all_in = false
								break
						if all_in:
							inside = true
							break
					if not inside:
						keep.append(idx[k])
						keep.append(idx[k + 1])
						keep.append(idx[k + 2])
				arrays[Mesh.ARRAY_INDEX] = keep
			var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			out.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, src.surface_get_blend_shape_arrays(s), {}, flags)
			out.surface_set_material(s, mat)
			out.surface_set_name(s, src.surface_get_name(s))
		mi.mesh = out


## Persistent facial expression from cfg.face = {expression: weight} (VRM blendShapeMaster names stored in the
## .vrm.json sidecar: blink, blink_l, blink_r, joy, angry, sorrow, fun, surprised, a, i, u, e, o). Gives bases
## shared by several classes different faces (half-lidded, smug, stern).
func _expressions() -> void:
	var face: Dictionary = cfg.get("face", {})
	if face.is_empty():
		return
	var side_path: String = String(cfg["model"]).get_basename() + ".vrm.json"
	if not FileAccess.file_exists(side_path):
		return
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(side_path))
	if not side is Dictionary:
		return
	var ex: Dictionary = (side as Dictionary).get("expressions", {})
	for mi in meshes:
		var mesh := mi.mesh
		if mesh == null or not mesh is ArrayMesh or (mesh as ArrayMesh).get_blend_shape_count() == 0:
			continue
		var n := (mesh as ArrayMesh).get_blend_shape_count()
		for key in face:
			for bind in ex.get(String(key), []):
				var i := int(bind[1])
				if i < n:
					mi.set_blend_shape_value(i, clampf(float(face[key]) * float(bind[2]), 0.0, 1.0))


## Head axes for the face shadow (toon special 2): call every frame while visible.
func update_face() -> void:
	if face_mats.is_empty() or not is_inside_tree():
		return
	var hi := skeleton.find_bone("Head")
	var pose := skeleton.get_bone_global_pose(hi)
	var rot := pose.basis.orthonormalized() * skeleton.get_bone_global_rest(hi).basis.orthonormalized().inverse()
	var gx := skeleton.global_transform
	var center := gx * (pose.origin + rot * Vector3(0, 0.08, 0.02))
	var right := (gx.basis * (rot * Vector3(-1, 0, 0))).normalized()
	var fwd := (gx.basis * (rot * Vector3(0, 0, 1))).normalized()
	var hw := 0.075 * gx.basis.get_scale().x
	for m in face_mats:
		m.set_shader_parameter("head_center", center)
		m.set_shader_parameter("head_right", right)
		m.set_shader_parameter("head_fwd", fwd)
		m.set_shader_parameter("face_half_width", hw)


## Zone tint: every toon material of the body, costume and cloth picks up the map's rim and ambient colours.
## Costume materials are shared caches, so the zone is global by design (one map at a time).
func set_zone_tint(rim: Color, ambient: Color, rim_mix := 0.7) -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mats: Array = []
		if mi.material_override:
			mats.append(mi.material_override)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				if m == null:
					m = mi.mesh.surface_get_material(s)
				if m:
					mats.append(m)
		for m in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader == TOON:
				(m as ShaderMaterial).set_shader_parameter("zone_rim", Color(rim.r, rim.g, rim.b, rim_mix))
				(m as ShaderMaterial).set_shader_parameter("zone_ambient", ambient)


# ---------------------------------------------------------------- secondary motion

func _springs() -> void:
	if not ClassDB.class_exists(&"SpringBoneSimulator3D"):
		return
	var side_path: String = String(cfg["model"]).get_basename() + ".vrm.json"
	if not FileAccess.file_exists(side_path):
		return
	var side: Variant = JSON.parse_string(FileAccess.get_file_as_string(side_path))
	if not side is Dictionary:
		return
	var chains: Array = []
	for g in (side as Dictionary).get("springs", []):
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
	if chains.is_empty():
		return
	var sim: Node = ClassDB.instantiate(&"SpringBoneSimulator3D")
	sim.name = "Springs"
	skeleton.add_child(sim)
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


## Spring bones cost CPU per chain; CharacterVisual turns them off beyond 25 m from the camera.
func set_springs_active(on: bool) -> void:
	if springs and springs.get("active") != on:
		springs.set("active", on)
