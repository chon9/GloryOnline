extends SceneTree
## ASSETS headless test: anime class bodies (ClassDress), KayKit mob/boss models, animation mapping (anime +
## Medium + Large rigs), status visuals, weapons.
## Run: godot --headless --path . -s res://tests/test_assets_visuals.gd

const CONTRACT_KEYS: Array[StringName] = [&"idle", &"run", &"walk", &"jump", &"fall", &"land", &"hit", &"launched", &"knockdown",
	&"getup", &"stunned", &"death", &"dash", &"block", &"cast", &"cast_long", &"channel", &"attack", &"attack_1h_1", &"attack_1h_2",
	&"attack_1h_3", &"attack_2h", &"attack_spin", &"attack_stab", &"attack_slam", &"attack_dual", &"kick", &"punch", &"punch_combo",
	&"shoot_1h", &"shoot_2h", &"shoot_dual", &"throw", &"summon", &"heal", &"taunt", &"grab", &"leap", &"aerial", &"victory"]
const CONTRACT_LOOP_KEYS: Array[StringName] = [&"idle", &"run", &"walk", &"fall", &"stunned", &"block", &"channel", &"cast_long"]
const CLASS_IDS: Array[String] = ["blade_master", "berserker", "spellblade", "ghostblade", "battle_mage", "elementalist", "witch",
	"summoner", "sharpshooter", "spitfire", "launcher", "mechanic", "striker", "qi_master", "grappler", "brawler", "assassin", "ninja",
	"thief", "warlock", "knight", "exorcist", "cleric", "paladin", "unspecialized"]
const CONTRACT_WEAPONS: Array[String] = ["lightsaber", "greatsword", "short_sword", "tachi", "battle_lance", "staff", "staff_ring",
	"broom", "revolver", "auto_pistol", "hand_cannon", "rifle", "gloves", "gloves_qi", "tonfa", "claws", "dual_swords", "ninjato",
	"dagger", "cane", "knight_sword", "war_scythe", "cross", "great_axe", "umbrella"]
const CONTRACT_OFFHANDS: Array[String] = ["shield", "grenade", "mech_box", "pistol", "dagger", "sword"]
const MOB_IDS: Array[String] = ["skeleton_minion", "skeleton_warrior", "skeleton_rogue", "skeleton_mage", "necromancer", "werewolf",
	"orc_raider", "black_knight", "frost_golem", "orc_brute", "monstrosity", "skeleton_golem"]


class ErrCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		# missing autoloads owned by other modules are not ours
		if "autoload" in rationale or "autoload" in code or "autoload" in file:
			return
		errors.append("%s:%d %s %s" % [file, line, code, rationale])

	func _log_message(message: String, error: bool) -> void:
		pass


var passed := 0
var failed := 0
var errlog := ErrCounter.new()


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)


func _initialize() -> void:
	OS.add_logger(errlog)
	_run.call_deferred()


func _weapon_ok(n: Node3D) -> bool:
	if n == null:
		return false
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	var box := AABB()
	var first := true
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a := mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return not first and box.size.length() > 0.05


func _run() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var e0 := errlog.errors.size()

	# --- 1. every class body creates with its weapon
	var gal: Script = load("res://visuals/gallery.gd")
	var cw: Dictionary = gal.get_script_constant_map()["CLASS_WEAPON"]
	for cid in CLASS_IDS:
		check(CharacterVisual.CLASS_MODEL.has(cid), "CLASS_MODEL has " + cid)
		var w: Array = cw.get(cid, ["knight_sword", ""])
		var v := CharacterVisual.create_for_class(cid, w[0], w[1])
		root3d.add_child(v)
		check(v.skeleton != null, cid + " has skeleton")
		check(v.anim_player != null and v.anim_player.has_animation(&"Run_Anime"), cid + " anime animation library attached")
		check(v.rig == "anime" and v.body != null, cid + " uses the anime rig")
		check(v.height >= 1.65 and v.height <= 1.95, "%s height %.2f" % [cid, v.height])
		var springs_or_cloth := v.body.springs != null or not v.body.find_children("*", "AnimeCloth", true, false).is_empty()
		check(springs_or_cloth or cid in ["striker", "grappler", "knight"], cid + " has secondary motion (springs or cloth)")
		var wn := v.skeleton.find_child("Weapon_" + String(w[0]), true, false) as Node3D
		check(_weapon_ok(wn), cid + " holds weapon " + String(w[0]))
		check(v.get_hand_position(true) != Vector3.ZERO, cid + " hand position")
	var used := {}
	for cid in CLASS_IDS:
		used[CharacterVisual.CLASS_MODEL[cid]["model"]] = true
	check(used.size() == CLASS_IDS.size(), "25 distinct class bodies (got %d)" % used.size())
	for cid in CLASS_IDS:
		check(ClassDress.is_finished(cid), "finished dress file for " + cid)
		var vf := CharacterVisual.create_for_class(cid, "", "")
		root3d.add_child(vf)
		var costume := 0
		var loose := 0
		for m in vf.skeleton.find_children("*", "MeshInstance3D", true, false):
			var mm := m as MeshInstance3D
			if mm.mesh == null:
				continue
			if mm.name.begins_with("Costume") and mm.get_parent() == vf.skeleton:
				costume += mm.mesh.get_surface_count()
			elif mm is AnimeCloth:
				costume += 1
			elif String(mm.get_parent().name).begins_with("Att_") and mm.material_override and mm.get_child_count() == 0:
				loose += 1   # a rigid piece the skinned merge missed (floaters / cloth sit deeper)
		check(costume >= 3, "%s builds its costume (%d merged material surfaces / cloth strips)" % [cid, costume])
		var cm := vf.skeleton.get_node_or_null("Costume") as MeshInstance3D
		check(cm != null and cm.skin != null and loose == 0, "%s rigid costume pieces merged into one skinned mesh (%d loose)" % [cid, loose])
		# draw budget (perf, 10 fighters >= 144 fps): visible surfaces per dressed body incl. its class weapon
		var w2: Array = cw.get(cid, ["knight_sword", ""])
		vf.set_weapon(w2[0], w2[1])
		var surf := 0
		for m in vf.find_children("*", "MeshInstance3D", true, false):
			var mm2 := m as MeshInstance3D
			if mm2.mesh and mm2.is_visible_in_tree():
				surf += mm2.mesh.get_surface_count()
		check(surf <= 50, "%s draw budget: %d surfaces (<= 50)" % [cid, surf])
	for cid in ClassDress.class_ids():
		check(ResourceLoader.exists(String(ClassDress.get_dress(cid)["model"])), "dress base model exists for " + cid)
	var fake := CharacterVisual.create("no_such_model_xyz", "", "", Color.WHITE)
	root3d.add_child(fake)
	check(fake.rig == "anime" and fake.model_id == "knight", "unknown model falls back to the anime knight")

	# --- 2. every model incl. mobs/bosses
	for mid in CharacterVisual.MODELS.keys():
		var v := CharacterVisual.create(mid, "", "", Color.WHITE)
		root3d.add_child(v)
		check(v.skeleton != null and v.skeleton.get_bone_count() >= 21, "model %s skeleton" % mid)
		check((v.rig == "large") == (mid in CharacterVisual.LARGE_MODELS), "model %s rig detection (%s)" % [mid, v.rig])
	for mob in MOB_IDS:
		check(CharacterVisual.MODELS.has(mob), "mob/boss model id " + mob)
	check(CharacterVisual.resolve_model_id("Skeleton_Warrior") == "skeleton_warrior", "resolve glb basename")
	check(CharacterVisual.resolve_model_id("ninja") == "ninja" and CharacterVisual.is_anime_id("ninja"), "class ids resolve to anime bodies")
	check(CharacterVisual.resolve_model_id("knight") == "knight", "resolve model id")
	check(CharacterVisual.resolve_model_id("blade_master") == CharacterVisual.CLASS_MODEL["blade_master"]["model"], "resolve class id")

	# --- 3. animation keys resolve on both rigs, tracks bind to the skeleton
	for r in ["anime", "medium", "large"]:
		var lib := CharacterVisual.get_library(r)
		var min_size: int = {"anime": 150, "medium": 90, "large": 25}[r]
		check(lib.get_animation_list().size() >= min_size, "%s library size %d" % [r, lib.get_animation_list().size()])
		for key in CONTRACT_KEYS:
			check(CharacterVisual.anim_map_for(r).has(key), "%s anim map has %s" % [r, key])
			var clip := CharacterVisual.resolve_clip(r, key)
			var cands: Array = CharacterVisual.anim_map_for(r).get(key, [])
			check(lib.has_animation(StringName(clip)) and clip in cands, "%s: %s -> %s" % [r, key, clip])
		for key in CONTRACT_LOOP_KEYS:
			var a := lib.get_animation(StringName(CharacterVisual.resolve_clip(r, key)))
			check(a != null and a.loop_mode == Animation.LOOP_LINEAR, "%s loop key %s loops" % [r, key])
		for key in [&"death", &"knockdown"]:
			var a2 := lib.get_animation(StringName(CharacterVisual.resolve_clip(r, key)))
			check(a2 != null and a2.loop_mode == Animation.LOOP_NONE, "%s %s is a held one-shot" % [r, key])
		var probe := CharacterVisual.create({"anime": "battle_mage", "medium": "skeleton_warrior", "large": "black_knight"}[r], "", "", Color.WHITE)
		root3d.add_child(probe)
		var base := probe.anim_player.get_node(probe.anim_player.root_node)
		var bad := 0
		var large_pos_bad := 0
		for an in lib.get_animation_list():
			var a3 := lib.get_animation(an)
			for t in a3.get_track_count():
				var p := a3.track_get_path(t)
				var sk := base.get_node_or_null(NodePath(p.get_concatenated_names()))
				var bone := String(p.get_concatenated_subnames())
				if not (sk is Skeleton3D) or (sk as Skeleton3D).find_bone(bone) < 0:
					bad += 1
				if r == "large" and a3.track_get_type(t) == Animation.TYPE_POSITION_3D and not (bone in ["root", "hips"]):
					large_pos_bad += 1
		check(bad == 0, "%s: all track paths bind to Skeleton3D bones (%d unbound)" % [r, bad])
		if r == "large":
			check(large_pos_bad == 0, "large: head-offset fix (non root/hips position tracks stripped)")

	# --- 4. runtime: play every key, statuses, alpha, weapon swap
	var v2 := CharacterVisual.create_for_class("unspecialized", "umbrella")
	root3d.add_child(v2)
	var vb := CharacterVisual.create("frost_golem", "frost_golem_axe", "", Color.WHITE)
	root3d.add_child(vb)
	for key in CONTRACT_KEYS:
		v2.play(key, 1.2)
		vb.play(key)
		await process_frame
		check(String(v2.anim_player.current_animation) == v2.resolve_key(key), "anime plays " + key)
		check(String(vb.anim_player.current_animation) == CharacterVisual.resolve_clip("large", key, vb._stance), "large plays " + key)
	v2.play(&"attack_1h_1")
	await create_timer(0.25).timeout
	var pos_before := v2.anim_player.current_animation_position
	v2.play(&"attack_1h_1")
	await process_frame
	check(v2.anim_player.current_animation_position < pos_before, "same one-shot key restarts")
	for form in WeaponFactory.UMBRELLA_FORMS:
		v2.set_weapon(form)
		await process_frame
		check(_weapon_ok(v2.skeleton.find_child("Weapon_" + form, true, false) as Node3D), "umbrella form " + form)
	# animated 千机伞 form change: panels start at the old form and settle within ~0.2 s
	v2.set_weapon("umbrella")
	await process_frame
	v2.set_weapon("umbrella_open")
	check(not v2._morph.is_empty() and v2._morph_t < 1.0, "umbrella form change starts a panel transition (%d parts)" % v2._morph.size())
	var p0: Node3D = v2._morph[0][0] if not v2._morph.is_empty() else null
	var target: Transform3D = v2._morph[0][2] if not v2._morph.is_empty() else Transform3D.IDENTITY
	await create_timer(0.35).timeout
	check(p0 != null and v2._morph.is_empty() and p0.transform.origin.is_equal_approx(target.origin), "umbrella panels settle into the new form")
	v2.set_weapon("umbrella_gun")
	check(v2.skeleton.find_child("Morph_Barrels", true, false) != null and not v2._morph.is_empty(), "gun form grows its barrels")
	await create_timer(0.3).timeout
	# zone tint reaches body and costume toon materials
	CharacterVisual.set_zone("moon", self)
	var any_zone := false
	for mi in v2.body.meshes:
		for si in mi.mesh.get_surface_count():
			var mm := mi.get_surface_override_material(si)
			if mm is ShaderMaterial and (mm as ShaderMaterial).shader == AnimeBody.TOON and ((mm as ShaderMaterial).get_shader_parameter("zone_rim") as Color).a > 0.5:
				any_zone = true
	check(any_zone, "set_zone tints the toon materials")
	CharacterVisual.set_zone("", self)
	# base clothing cull + expressions + special shading
	var vu := CharacterVisual.create_for_class("unspecialized", "umbrella")
	root3d.add_child(vu)
	var tops_tris := -1
	for mi in vu.body.meshes:
		for si in mi.mesh.get_surface_count():
			var mt := mi.mesh.surface_get_material(si)
			if mt and mt.resource_name.contains("Tops"):
				tops_tris = (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var raw: Node3D = (load("res://assets/characters/anime/vroid_hairsample_male.glb") as PackedScene).instantiate()
	var raw_tris := 0
	for mi in raw.find_children("*", "MeshInstance3D", true, false):
		var rm := (mi as MeshInstance3D).mesh
		for si in rm.get_surface_count():
			if rm.surface_get_material(si) and rm.surface_get_material(si).resource_name.contains("Tops"):
				raw_tris = (rm.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	raw.free()
	check(tops_tris > 0 and tops_tris < raw_tris, "dress cull removes the hoodie hood (%d of %d tris kept)" % [tops_tris, raw_tris])
	var expr := false
	for mi in vu.body.meshes:
		for bi in mi.get_blend_shape_count():
			if mi.get_blend_shape_value(bi) > 0.1:
				expr = true
	check(expr, "dress face expression applied (half-lidded Unspecialized)")
	check(not vu.body.face_mats.is_empty() and int(vu.body.face_mats[0].get_shader_parameter("special")) == 2, "face uses the head-axis shadow")
	v2.set_weapon("rifle", "mech_box")
	await process_frame
	check(v2.skeleton.find_child("Weapon_mech_box", true, false) != null, "mech_box offhand at hip")
	var all_mask := (1 << CharacterVisual.STATUS_IDS.size()) - 1
	v2.set_status_visual(all_mask)
	v2.flash_hit()
	await process_frame
	check(v2._bubble != null and v2._bubble.visible, "shield bubble visible")
	check(v2._stars != null and v2._stars.visible, "stun stars visible")
	check(v2.anim_player.speed_scale == 0.0, "freeze pauses animation")
	check(v2._meshes[0].material_overlay != null, "status overlay applied")
	v2.set_status_visual(0)
	await create_timer(0.2).timeout
	check(v2._meshes[0].material_overlay == null, "overlay cleared")
	check(v2.anim_player.speed_scale > 0.0, "unfreeze resumes animation")
	var toon_before := v2._meshes[0].get_surface_override_material(0)
	v2.set_alpha(0.15)
	var all_faded := true
	for mi in v2._all_meshes():
		if mi.material_override != v2._stealth_mat:
			all_faded = false
	check(v2._stealth_mat != null and float(v2._stealth_mat.get_shader_parameter("alpha")) < 0.2, "stealth material alpha")
	check(all_faded, "stealth alpha applied to every body, costume and weapon mesh")
	v2.set_alpha(0.0)
	check(not v2.visible, "alpha 0 hides")
	v2.set_alpha(1.0)
	var all_opaque := true
	for mi in v2._all_meshes():
		if mi.material_override == v2._stealth_mat or mi.has_meta(&"_pre_stealth"):
			all_opaque = false
	check(v2.visible and all_opaque and v2._meshes[0].get_surface_override_material(0) == toon_before, "alpha 1 restores opaque toon materials")
	# status restyle: ice shell on freeze, embers on burn, stars on stun
	v2.set_status_visual((1 << CharacterVisual.STATUS_IDS.find(&"freeze")) | (1 << CharacterVisual.STATUS_IDS.find(&"burn")))
	check(v2._ice != null and v2._ice.visible and v2._embers != null and v2._embers.emitting, "freeze ice shell + burn embers")
	v2.set_status_visual(0)
	# spring bones / cloth switch off beyond 25 m from the camera
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.current = true
	var vfar := CharacterVisual.create_for_class("blade_master", "lightsaber")
	root3d.add_child(vfar)
	vfar.position = Vector3(0, 0, -40)
	cam.position = Vector3.ZERO
	await process_frame
	vfar._update_lod()
	var cloth := vfar.body.find_children("*", "AnimeCloth", true, false)
	check(not cloth.is_empty() and not (cloth[0] as AnimeCloth).active and (vfar.body.springs == null or vfar.body.springs.get("active") == false), "springs + cloth off beyond 25 m")
	vfar.position = Vector3(0, 0, -5)
	vfar._update_lod()
	check((cloth[0] as AnimeCloth).active, "springs + cloth back on near the camera")
	# weapons built with shared material_override must fade too (stealth)
	for wt in ["ninjato", "lightsaber", "revolver", "dual_swords"]:
		var vw := CharacterVisual.create("knight", wt)
		root.add_child(vw)
		var origs := {}
		for mi in vw._all_meshes():
			origs[mi] = mi.material_override
		vw.set_alpha(0.15)
		var opaque := 0
		for mi in origs:
			var m: Material = mi.material_override
			var faded: bool = m == vw._stealth_mat or mi.transparency > 0.5 or (m is BaseMaterial3D and m != origs[mi]  and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED  and (m as BaseMaterial3D).albedo_color.a <= 0.15 + 0.001)
			if not faded:
				opaque += 1
		check(opaque == 0 and (origs.size() > 0 or wt == "dual_swords"), "%s override meshes faded at alpha 0.15 (%d opaque of %d)" % [wt, opaque, origs.size()])
		vw.set_alpha(1.0)
		var restored := true
		for mi in origs:
			if mi.material_override != origs[mi] or mi.transparency != 0.0:
				restored = false
		check(restored, "%s override materials restored at alpha 1" % wt)
		vw.queue_free()
	check(v2.height > 1.6 and v2.height < 2.0, "player height ~1.8 m (%.2f)" % v2.height)

	# --- 4b. cloth: fixed-step simulation, the same drape at 30 and 144 fps; GPU-skinned (no per-frame mesh rebuild)
	var vc := CharacterVisual.create_for_class("blade_master", "lightsaber")
	root3d.add_child(vc)
	vc.position = Vector3(30, 0, 0)
	await process_frame
	var capes := vc.body.find_children("*", "AnimeCloth", true, false)
	check(not capes.is_empty() and (capes[0] as AnimeCloth).skin != null, "cloth strip is a skinned mesh")
	if not capes.is_empty():
		var cl := capes[0] as AnimeCloth
		vc.anim_player.pause()
		cl.set_process(false)
		var mesh_before := cl.mesh
		var tips: Array = []
		for fps: float in [30.0, 144.0]:
			cl.reset()
			# swing the anchor sideways for 0.5 s, then hold for 0.5 s, at this frame rate
			var t := 0.0
			while t < 1.0 - 1e-6:
				vc.position.x = 30.0 + (0.4 * sin(minf(t, 0.5) * TAU) if t < 0.5 else 0.0)
				vc.force_update_transform()
				cl._process(1.0 / fps)
				t += 1.0 / fps
			tips.append(cl._pts[cl._pts.size() - 1])
		var dtip: float = (tips[0] as Vector3).distance_to(tips[1])
		check(dtip < 0.05, "cloth tip agrees at 30 vs 144 fps (%.3f m apart)" % dtip)
		check(cl.mesh == mesh_before, "cloth mesh built once (only bone poses change)")
		var down := (cl._pts[cl._pts.size() - 1] - cl._pts[0]).normalized().dot(Vector3.DOWN)
		check(down > 0.6, "cape hangs down at rest (%.2f)" % down)
		cl.set_process(true)
		vc.anim_player.play()
	# tonfa: both rods ride the pinky (back, -Z at the T-pose) side of the forearm
	var vt := CharacterVisual.create_for_class("grappler", "tonfa")
	root3d.add_child(vt)
	for m: Dictionary in vt._mounts:
		var w: Node3D = m["node"]
		var hand := String(m["bone"])
		var xf := vt.body.bone_xf(hand) * w.transform
		var rod := xf * Vector3(-0.17, 0.0, -0.075)
		check(rod.z < vt.body.bone_pos(hand).z - 0.03, "tonfa rod on the pinky side (%s, dz %.3f)" % [hand, rod.z - vt.body.bone_pos(hand).z])
	# caster poles stay upright in the KayKit cast clips (per-clip grips)
	for cc in [["elementalist", "staff"], ["summoner", "staff_ring"], ["warlock", "cane"]]:
		var vk := CharacterVisual.create_for_class(cc[0], cc[1])
		root3d.add_child(vk)
		for clip in ["kk_Ranged_Magic_Summon", "kk_Ranged_Magic_Raise", "Power Up"]:
			vk.pose_clip(clip, 0.6 if clip == "Power Up" else 1.0)
			await process_frame
			var wk := vk.skeleton.find_child("Weapon_" + String(cc[1]), true, false) as Node3D
			var up := (wk.global_transform.basis.y.normalized()).dot(Vector3.UP) if wk else -1.0
			check(up > 0.5, "%s %s upright in %s (up %.2f)" % [cc[0], cc[1], clip, up])
		vk.pose_clip("Spell_Simple_Idle", 1.0)
		await process_frame
		var wi := vk.skeleton.find_child("Weapon_" + String(cc[1]), true, false) as Node3D
		check(wi != null and wi.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.5, "%s idle grip unchanged (upright)" % cc[0])
		vk.queue_free()
	for cid in ["elementalist", "summoner", "warlock"]:
		var vs := CharacterVisual.create_for_class(cid, "staff")
		check(vs.resolve_key(&"summon").begins_with("kk_Ranged_Magic_Summon"), "%s summons with the KayKit summon clip (%s)" % [cid, vs.resolve_key(&"summon")])
		vs.free()

	# --- 5. weapons
	# fist weapons: the flared cuff runs back along the forearm (-X), never over the fist
	for fid in ["gloves", "gloves_left", "gloves_qi", "claws"]:
		var gw := WeaponFactory.build(fid, Color.WHITE)
		var minx := 1.0
		for m in gw.find_children("*", "MeshInstance3D", true, false):
			var ab := (m as MeshInstance3D).get_aabb()
			minx = minf(minx, ab.position.x)
		check(minx < -0.2, "%s cuff extends toward the elbow (min x %.2f)" % [fid, minx])
		gw.free()
	var all_ids: Array[String] = []
	all_ids.append_array(CONTRACT_WEAPONS)
	all_ids.append_array(CONTRACT_OFFHANDS)
	all_ids.append_array(WeaponFactory.all_ids())
	var seen := {}
	for wid in all_ids:
		if seen.has(wid):
			continue
		seen[wid] = true
		var w := WeaponFactory.build(wid, Color(0.4, 0.8, 1.0))
		root3d.add_child(w)
		check(w.name == "Weapon_" + wid and _weapon_ok(w), "weapon builds non-empty: " + wid)
	for wid in CONTRACT_WEAPONS + CONTRACT_OFFHANDS:
		check(wid in WeaponFactory.all_ids(), "WeaponFactory lists " + wid)

	await create_timer(0.3).timeout
	var errs := errlog.errors.slice(e0)
	for e in errs:
		print("  ENGINE ERROR: ", e)
	check(errs.is_empty(), "no engine/script errors during visuals test (%d)" % errs.size())
	print("ASSETS TESTS: %d passed, %d failed" % [passed, failed])
	root3d.queue_free()
	quit(1 if failed > 0 else 0)
