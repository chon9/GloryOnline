extends SceneTree
## ASSETS headless test: character models, animation mapping (Medium + Large rigs), weapons.
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
		check(v.anim_player != null and v.anim_player.has_animation(&"Idle_A"), cid + " animation library attached")
		check(v.rig == "medium", cid + " uses Medium rig")
		var wn := v.skeleton.find_child("Weapon_" + String(w[0]), true, false) as Node3D
		check(_weapon_ok(wn), cid + " holds weapon " + String(w[0]))
		check(v.get_hand_position(true) != Vector3.ZERO, cid + " hand position")
	var used := {}
	for cid in CLASS_IDS:
		used[CharacterVisual.CLASS_MODEL[cid]["model"]] = true
	check(used.size() == CLASS_IDS.size(), "25 distinct class bodies (got %d)" % used.size())

	# --- 2. every model incl. mobs/bosses
	for mid in CharacterVisual.MODELS.keys():
		var v := CharacterVisual.create(mid, "", "", Color.WHITE)
		root3d.add_child(v)
		check(v.skeleton != null and v.skeleton.get_bone_count() >= 21, "model %s skeleton" % mid)
		check((v.rig == "large") == (mid in CharacterVisual.LARGE_MODELS), "model %s rig detection (%s)" % [mid, v.rig])
	for mob in MOB_IDS:
		check(CharacterVisual.MODELS.has(mob), "mob/boss model id " + mob)
	check(CharacterVisual.resolve_model_id("AvianSwordsman") == "avian_swordsman", "resolve glb basename")
	check(CharacterVisual.resolve_model_id("knight") == "knight", "resolve model id")
	check(CharacterVisual.resolve_model_id("blade_master") == CharacterVisual.CLASS_MODEL["blade_master"]["model"], "resolve class id")

	# --- 3. animation keys resolve on both rigs, tracks bind to the skeleton
	for r in ["medium", "large"]:
		var lib := CharacterVisual.get_library(r)
		check(lib.get_animation_list().size() >= (90 if r == "medium" else 25), "%s library size %d" % [r, lib.get_animation_list().size()])
		for key in CONTRACT_KEYS:
			check(CharacterVisual.ANIM_MAP.has(key), "ANIM_MAP has " + key)
			var clip := CharacterVisual.resolve_clip(r, key)
			var cands: Array = CharacterVisual.ANIM_MAP.get(key, [])
			check(lib.has_animation(StringName(clip)) and clip in cands, "%s: %s -> %s" % [r, key, clip])
		for key in CONTRACT_LOOP_KEYS:
			var a := lib.get_animation(StringName(CharacterVisual.resolve_clip(r, key)))
			check(a != null and a.loop_mode == Animation.LOOP_LINEAR, "%s loop key %s loops" % [r, key])
		for key in [&"death", &"knockdown"]:
			var a2 := lib.get_animation(StringName(CharacterVisual.resolve_clip(r, key)))
			check(a2 != null and a2.loop_mode == Animation.LOOP_NONE, "%s %s is a held one-shot" % [r, key])
		var probe := CharacterVisual.create("knight" if r == "medium" else "black_knight", "", "", Color.WHITE)
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
		check(String(v2.anim_player.current_animation) == CharacterVisual.resolve_clip("medium", key, v2._stance), "medium plays " + key)
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
	v2.set_alpha(0.15)
	var any_transparent := false
	for mi in v2._meshes:
		var m := mi.get_surface_override_material(0)
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_color.a < 0.2:
			any_transparent = true
	check(any_transparent, "stealth alpha applied")
	v2.set_alpha(0.0)
	check(not v2.visible, "alpha 0 hides")
	v2.set_alpha(1.0)
	check(v2.visible and v2._meshes[0].get_surface_override_material(0) == null, "alpha 1 restores opaque materials")
	# weapons built with shared material_override must fade too (stealth)
	for wt in ["ninjato", "lightsaber", "revolver", "dual_swords"]:
		var vw := CharacterVisual.create("knight", wt)
		root.add_child(vw)
		var origs := {}
		for mi in vw._all_meshes():
			if mi.material_override != null:
				origs[mi] = mi.material_override
		vw.set_alpha(0.15)
		var opaque := 0
		for mi in origs:
			var m: Material = mi.material_override
			var faded: bool = mi.transparency > 0.5 or (m is BaseMaterial3D and m != origs[mi]  and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED  and (m as BaseMaterial3D).albedo_color.a <= 0.15 + 0.001)
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

	# --- 5. weapons
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
