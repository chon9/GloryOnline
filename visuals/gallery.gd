extends Node3D
## Asset showcase: all 25 anime class bodies with their weapons, plus toon-restyled mobs and bosses.
## Keys: Left/Right = cycle animation key, 1..4 = camera views, F = fire sample effects, S = toggle statuses.
## Screenshot mode (non-headless console exe, the window is made borderless 1920x1080):
##   godot --path . res://scenes/gallery.tscn -- --shot=<png> [--view=<view>] [--anim=<key>] [--wait=<sec>] [--status=<mask>]
## Views: front (all 25), wide, close:<class_id|i> (3/4 portrait), face:<class_id|i>, one:<i>, group:<i> (4 classes),
## hero (the finished classes side by side), gameplay (3/4 top-down camera, 10 fighters in combat loops),
## status (status visuals on 6 fighters), mobs, mobgroup:<i>, models:<page>, fx, fxclose, areas, proj,
## perf (10 animated fighters + continuous effects, prints average FPS; run with --disable-vsync).

const CLASS_ORDER: Array[String] = ["blade_master", "berserker", "spellblade", "ghostblade", "battle_mage", "elementalist",
	"witch", "summoner", "sharpshooter", "spitfire", "launcher", "mechanic", "striker", "qi_master", "grappler", "brawler",
	"assassin", "ninja", "thief", "warlock", "knight", "exorcist", "cleric", "paladin", "unspecialized"]
## Fallback weapon per class (Registry kits are authoritative when present).
const CLASS_WEAPON: Dictionary = {
	"blade_master": ["lightsaber", ""], "berserker": ["greatsword", ""], "spellblade": ["short_sword", ""], "ghostblade": ["tachi", ""],
	"battle_mage": ["battle_lance", ""], "elementalist": ["staff", ""], "witch": ["broom", ""], "summoner": ["staff_ring", ""],
	"sharpshooter": ["revolver", ""], "spitfire": ["auto_pistol", "grenade"], "launcher": ["hand_cannon", ""], "mechanic": ["rifle", "mech_box"],
	"striker": ["gloves", ""], "qi_master": ["gloves_qi", ""], "grappler": ["tonfa", ""], "brawler": ["claws", ""],
	"assassin": ["dual_swords", ""], "ninja": ["ninjato", ""], "thief": ["dagger", ""], "warlock": ["cane", ""],
	"knight": ["knight_sword", "shield"], "exorcist": ["war_scythe", ""], "cleric": ["cross", ""], "paladin": ["great_axe", ""],
	"unspecialized": ["umbrella", ""],
}
const HERO: Array[String] = ["battle_mage", "launcher", "witch", "unspecialized", "blade_master"]
const MOBS: Array[String] = ["skeleton_minion", "skeleton_warrior", "skeleton_rogue", "skeleton_mage", "necromancer", "werewolf", "orc_raider"]
const BOSSES: Array[String] = ["black_knight", "frost_golem", "orc_brute", "monstrosity", "skeleton_golem"]
const PERF_KEYS: Array[StringName] = [&"attack_1h_1", &"attack_2h", &"cast", &"run", &"punch_combo", &"shoot_1h", &"attack_spin", &"idle"]
const COMBAT_KEYS: Array[StringName] = [&"attack_1h_1", &"attack_1h_2", &"attack_1h_3", &"cast", &"shoot_1h", &"attack_stab", &"dash", &"punch"]

var visuals: Array[CharacterVisual] = []
var mob_visuals: Array[CharacterVisual] = []
var cam: Camera3D
var anim_keys: Array = []
var anim_index := 0
var status_on := false
var _args: Dictionary = {}
var _label: Label
var _perf := false
var _perf_t := 0.0
var _perf_acc := 0.0
var _perf_frames := 0
var _perf_spawn := 0.0
var _perf_id := 5000
var _combat := false
var _combat_t := 0.0
var _env: Environment


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	if _args.has("shot") or _args.get("view", "") == "perf":
		var w := get_window()
		w.borderless = true
		w.size = Vector2i(1920, 1080)
		w.position = Vector2i(0, 0)
	anim_keys = CharacterVisual.ANIME_ANIM_MAP.keys()
	if _args.has("nomerge"):
		AnimeBody.skinned_merge = false
	_build_world()
	var view: String = _args.get("view", "front")
	_build_lineup(not view.begins_with("mob") and view != "models")
	_set_view(view)
	if _args.has("anim"):
		_play_all(StringName(_args["anim"]))
	if _args.has("zone"):
		CharacterVisual.set_zone(String(_args["zone"]), get_tree())
	if _args.has("status"):
		var m := int(_args["status"])
		for v in visuals:
			v.set_status_visual(m)
	if _args.has("shot"):
		_take_shot.call_deferred()


# ---------------------------------------------------------------- world: a neutral painted stage

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color("#5F9FD6")
	ps.sky_horizon_color = Color("#DCEBF6")
	ps.ground_bottom_color = Color("#56627A")
	ps.ground_horizon_color = Color("#C9D6E4")
	ps.sun_angle_max = 20.0
	sky.sky_material = ps
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.6
	e.ambient_light_color = Color("#8FC3DD")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		e.set_glow_level(i, 1.0 if i in [2, 3, 4, 5] else 0.0)
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.4
	e.fog_enabled = true
	e.fog_light_color = Color("#B8D4EA")
	e.fog_density = 0.0012
	e.fog_aerial_perspective = 0.4
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.08
	we.environment = e
	_env = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFF1DC")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_blur = 0.6
	sun.directional_shadow_max_distance = 60.0
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	add_child(sun)
	# floor: cool stone with a darker rune disc
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#B9C7DA")
	fm.roughness = 0.9
	ground.material_override = fm
	add_child(ground)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.02
	cm.radial_segments = 64
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("#7F93B4")
	dm.roughness = 0.85
	disc.material_override = dm
	disc.position = Vector3(0, 0.005, 2.0)
	add_child(disc)
	for r: float in [8.6, 8.8, 4.0]:
		var ring := MeshInstance3D.new()
		ring.mesh = AnimeGear.lathe([Vector2(r, 0.0), Vector2(r + 0.06, 0.0)], 96)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(0.55, 0.85, 1.0)
		rm.emission_enabled = true
		rm.emission = Color(0.4, 0.8, 1.0)
		rm.emission_energy_multiplier = 1.6
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = rm
		ring.position = Vector3(0, 0.03, 2.0)
		add_child(ring)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	cl.add_child(_label)


func _class_weapon(cid: String) -> Array:
	var reg := get_node_or_null("/root/Registry")
	if reg and reg.has_method("get_kit"):
		var kit: Variant = reg.call("get_kit", cid)
		if kit is Object and kit != null:
			return [kit.get("weapon_type"), kit.get("offhand")]
	return CLASS_WEAPON[cid]


func _build_lineup(classes: bool) -> void:
	if classes:
		for i in CLASS_ORDER.size():
			var cid := CLASS_ORDER[i]
			var w := _class_weapon(cid)
			var v := CharacterVisual.create_for_class(cid, w[0], w[1])
			var row := i / 13
			var col := i % 13
			v.position = Vector3((col - 6) * 1.5 + row * 0.75, 0, row * -2.6)
			add_child(v)
			visuals.append(v)
			var lab := Label3D.new()
			lab.text = cid
			lab.font_size = 28
			lab.pixel_size = 0.004
			lab.position = Vector3(0, 0.02, 0.75)
			lab.rotation = Vector3(-PI / 2.0, 0, 0)
			lab.modulate = Color(0.1, 0.12, 0.2)
			v.add_child(lab)
	var all := MOBS + BOSSES
	for i in all.size():
		var id: String = all[i]
		var v := CharacterVisual.create(id, CharacterVisual.MOB_WEAPONS.get(id, ""), "skeleton_shield" if id == "skeleton_warrior" else ("black_knight_shield" if id == "black_knight" else ""), Color.WHITE)
		var x := -14.0 + i * 2.6 + (maxf(0, i - MOBS.size() + 1) * 2.4)
		v.position = Vector3(x, 0, -9.5)
		add_child(v)
		mob_visuals.append(v)
	# the camera looks at the fighters' faces: rotate every visual to face +Z (toward the default camera)
	for v in visuals + mob_visuals:
		v.rotation.y = PI


func _find(id: String) -> CharacterVisual:
	if id.is_valid_int():
		return visuals[clampi(int(id), 0, visuals.size() - 1)]
	var i := CLASS_ORDER.find(id)
	return visuals[maxi(i, 0)]


func _solo(vs: Array) -> void:
	for v in visuals + mob_visuals:
		v.visible = v in vs


func _set_view(view: String) -> void:
	if view == "front" or view == "wide":
		cam.fov = 54
		cam.position = Vector3(0, 2.6, 11.0)
		cam.look_at(Vector3(0, 0.9, -1.3))
		for v in mob_visuals:
			v.visible = false
	elif view == "mobs":
		cam.position = Vector3(2, 4.0, 4.0)
		cam.look_at(Vector3(2, 1.5, -9.5))
	elif view.begins_with("close:") or view.begins_with("face:") or view.begins_with("hands:"):
		var v := _find(view.get_slice(":", 1))
		_solo([v])
		v.position = Vector3(0, 0, 2.0)
		v.rotation.y = PI + deg_to_rad(float(_args.get("yaw", "-25")))
		if view.begins_with("face:"):
			cam.fov = 26
			cam.position = Vector3(0.35, 1.65, 3.6)
			cam.look_at(Vector3(0, 1.55, 2.0))
		elif view.begins_with("hands:"):
			# upper body + fists (gauntlets, held weapons)
			cam.fov = 24
			cam.position = Vector3(0.5, 1.45, 4.6)
			cam.look_at(Vector3(0, 1.2, 2.0))
		else:
			cam.fov = 32
			cam.position = Vector3(1.1, 1.45, 6.1)
			cam.look_at(Vector3(0, 1.0, 2.0))
		_env.fog_density = 0.0
	elif view.begins_with("one:"):
		var v := _find(view.substr(4))
		cam.position = v.position + Vector3(1.0, 1.4, 3.2)
		cam.look_at(v.position + Vector3(0, 0.95, 0))
	elif view == "hero":
		var vs: Array = []
		for i in HERO.size():
			var v := _find(HERO[i])
			v.position = Vector3((i - 2) * 1.35, 0, 2.0 - absf(i - 2) * 0.35)
			v.rotation.y = PI - (i - 2) * 0.12
			vs.append(v)
		_solo(vs)
		cam.fov = 30
		cam.position = Vector3(0, 1.6, 10.0)
		cam.look_at(Vector3(0, 1.0, 2.0))
	elif view.begins_with("group:") or view.begins_with("mobgroup:"):
		var src: Array[CharacterVisual] = visuals if view.begins_with("group:") else mob_visuals
		var i0 := int(view.get_slice(":", 1))
		var n := 4 if view.begins_with("group:") else 3
		var vs: Array = []
		var big := false
		for k in n:
			if i0 + k >= src.size():
				break
			var v := src[i0 + k]
			vs.append(v)
			v.position = Vector3((k - (n - 1) * 0.5) * (1.6 if n == 4 else 3.4), 0, 4.0)
			big = big or v.rig == "large"
		_solo(vs)
		var d := 6.0 if big else 5.0
		cam.fov = 40
		cam.position = Vector3(0.0, 1.7 if not big else 2.8, 4.0 + d)
		cam.look_at(Vector3(0, 0.95 if not big else 1.8, 4.0))
	elif view == "gameplay" or view == "perf":
		_arena(10)
		cam.fov = 50
		cam.position = Vector3(0, 9.5, 12.5)
		cam.look_at(Vector3(0, 0.8, 2.0))
		_combat = true
		_perf = view == "perf"
		if _perf:
			for v in visuals:
				if not v.visible:
					v.queue_free()
			for v in mob_visuals:
				v.queue_free()
			for v in visuals:
				if v.body and _args.has("nospring"):
					v.body.set_springs_active(false)
				if v.body and _args.has("nocloth"):
					for c in v.body.find_children("*", "AnimeCloth", true, false):
						(c as AnimeCloth).active = false
						(c as AnimeCloth).set_process(false)
	elif view == "status":
		var ids := ["unspecialized", "launcher", "battle_mage", "witch", "blade_master", "knight"]
		var masks := [_mask([&"freeze"]), _mask([&"burn"]), _mask([&"super_armor"]), _mask([&"shield"]), _mask([&"stun"]), _mask([&"poison", &"mark"])]
		var vs: Array = []
		for i in ids.size():
			var v := _find(ids[i])
			v.position = Vector3((i - 2.5) * 1.5, 0, 3.0)
			v.set_status_visual(masks[i])
			vs.append(v)
		var st := _find("ninja")
		st.position = Vector3(5.0, 0, 3.0)
		st.set_alpha(0.35)
		vs.append(st)
		_solo(vs)
		cam.fov = 38
		cam.position = Vector3(0.6, 2.2, 10.5)
		cam.look_at(Vector3(0.6, 1.0, 3.0))
	elif view == "clips":
		# pose contact sheet: --cls=<class> "--clips=Clip@t,Clip@t,..." (clip names from the anime library)
		_solo([])
		var cid: String = _args.get("cls", "battle_mage")
		var clips := String(_args.get("clips", "Idle_A@0.5,Idle_Sword@0.5,Fighting Idle@0.5,Pistol_Idle@0.5")).split(",")
		var w := _class_weapon(cid)
		for i in clips.size():
			var ct := clips[i].split("@")
			var v := CharacterVisual.create_for_class(cid, w[0], w[1])
			add_child(v)
			v.position = Vector3((i - (clips.size() - 1) * 0.5) * 1.5, 0, 2.0)
			v.rotation.y = PI - 0.35
			v.pose_clip(ct[0], float(ct[1]) if ct.size() > 1 else 0.3)
			var lab := Label3D.new()
			lab.text = ct[0]
			lab.font_size = 40
			lab.pixel_size = 0.004
			lab.modulate = Color(0.1, 0.12, 0.2)
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.position = Vector3(0, 2.15, 0)
			v.add_child(lab)
		cam.fov = 40
		cam.position = Vector3(0, 1.8, 2.0 + 3.2 + clips.size() * 0.9)
		cam.look_at(Vector3(0, 1.0, 2.0))
	elif view == "weapons":
		# every WeaponFactory id standing in a grid (grip at y = 1.0; firearms turned muzzle-up for comparison)
		_solo([])
		var all_ids := WeaponFactory.all_ids()
		var page := int(_args.get("page", "0"))
		var ids := all_ids.slice(page * 12, page * 12 + 12)
		var cols := 6
		for i in ids.size():
			var w := WeaponFactory.build(ids[i])
			var holder := Node3D.new()
			add_child(holder)
			holder.position = Vector3((i % cols - (cols - 1) * 0.5) * 1.35, 1.0 + (1 - i / cols) * 1.9, 2.0)
			if String(w.get_meta("grip_kind", "")) in ["gun", "fist"]:
				holder.rotation_degrees.z = 90.0
			if String(w.get_meta("units", "m")) == "kaykit":
				holder.scale = Vector3.ONE * 0.75
			holder.add_child(w)
			var lab := Label3D.new()
			lab.text = ids[i]
			lab.font_size = 28
			lab.pixel_size = 0.004
			lab.modulate = Color(0.1, 0.12, 0.2)
			lab.position = holder.position + Vector3(0, -0.72, 0.3)
			add_child(lab)
		cam.fov = 45
		cam.position = Vector3(0, 2.0, 9.0)
		cam.look_at(Vector3(0, 1.95, 2.0))
	elif view.begins_with("models"):
		for v in visuals + mob_visuals:
			v.visible = false
		var ids := CharacterVisual.MODELS.keys()
		for i in ids.size():
			var v := CharacterVisual.create(ids[i], "", "", Color.WHITE)
			v.position = Vector3((i % 7 - 3) * 2.4, 0, 6.0 - (i / 7) * 3.0)
			v.rotation.y = PI
			add_child(v)
		cam.position = Vector3(0, 5.5, 14.5)
		cam.look_at(Vector3(0, 0.5, 3.0))
	elif view == "fxclose":
		var k := visuals[0]
		_solo([k])
		k.position = Vector3(-3.0, 0, 4.0)
		k.rotation.y = -PI / 2
		k.replay(&"attack_1h_2")
		cam.position = Vector3(0, 3.2, 11.5)
		cam.look_at(Vector3(0, 1.2, 4.0))
		var fx := get_node_or_null("/root/Fx")
		if fx:
			fx.play(&"slash_arc", Vector3(-3.0, 1.1, 4.0), Vector3.RIGHT, Color.WHITE, 1.0)
			fx.play(&"hit_heavy", Vector3(-1.4, 1.1, 4.0), Vector3.RIGHT, Color.WHITE, 1.0)
			fx.play(&"explosion", Vector3(3.6, 0.0, 4.0), Vector3.UP, Color.WHITE, 1.0)
	elif view in ["fx", "areas", "proj"]:
		cam.position = Vector3(0, 7.5, 13)
		cam.look_at(Vector3(0, 0.5, 3))
		for v in visuals + mob_visuals:
			v.visible = false
		_fx_demo(view)


func _mask(ids: Array) -> int:
	var m := 0
	for id in ids:
		m |= 1 << CharacterVisual.STATUS_IDS.find(id)
	return m


## 10 fighters (5v5) facing each other across the stage, the finished classes up front.
func _arena(n: int) -> void:
	var order: Array[String] = ["battle_mage", "launcher", "witch", "unspecialized", "blade_master", "knight", "ninja", "cleric", "striker", "berserker"]
	var vs: Array = []
	for i in n:
		var v := _find(order[i])
		var team := i % 2
		var k := i / 2
		v.position = Vector3((k - 2) * 2.2 + (0.6 if team else -0.6), 0, 0.2 + team * 3.6 + (k % 2) * 0.6)
		v.rotation.y = PI if team == 0 else 0.0   # the two teams face each other
		vs.append(v)
	_solo(vs)


func _fx_demo(view: String) -> void:
	var fx := get_node_or_null("/root/Fx")
	if fx == null or not fx.has_method("play"):
		return
	if view == "fx":
		var names := ["hit_spark", "hit_heavy", "slash_arc", "launch_burst", "land_dust", "cast_glow", "heal_burst", "buff_aura",
			"debuff_puff", "explosion", "ice_burst", "lightning_strike", "fire_burst", "holy_burst", "dark_burst", "poison_cloud",
			"smoke", "blink", "dash_trail", "summon_circle", "block_spark", "death", "ultimate_flash"]
		for i in names.size():
			var p := Vector3((i % 8 - 3.5) * 2.6, 0.8, (i / 8) * 3.0)
			fx.play(StringName(names[i]), p, Vector3.FORWARD, Color.WHITE, 1.0)
	elif view == "areas":
		var vis := ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]
		for i in vis.size():
			var p := Vector3((i % 4 - 1.5) * 6.0, 0.05, (i / 4) * 5.0 - 4.0)
			fx.spawn_area_visual(100 + i, vis[i], "circle", p, 0.4, 2.2, 5.0, 1.6, 0.0, 6.0, Color.WHITE)
	elif view == "proj":
		var vis := ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi", "dragon", "lightning", "cannonball", "flask", "scythe"]
		for i in vis.size():
			var p := Vector3(-9.0, 1.2, (i - 7) * 0.9 + 2.0)
			fx.spawn_projectile_visual(200 + i, vis[i], p, Vector3(7.0, 0, 0), 0.0, Color.WHITE, 1.0, 0)


func _play_all(key: StringName) -> void:
	for v in visuals + mob_visuals:
		v.replay(key)
	_label.text = "anim: %s   (Left/Right to cycle)" % key


func _process(delta: float) -> void:
	if _combat:
		_combat_t -= delta
		if _combat_t <= 0.0:
			_combat_t = 0.35
			for v in visuals:
				if v.visible and randf() < 0.3:
					v.replay(COMBAT_KEYS[randi() % COMBAT_KEYS.size()])
	if not _perf:
		return
	_perf_t += delta
	if _perf_t > 1.0:
		_perf_acc += delta
		_perf_frames += 1
	_perf_spawn -= delta
	var fx := get_node_or_null("/root/Fx")
	if _perf_spawn <= 0.0 and fx and not _args.has("nofx"):
		_perf_spawn = 0.1
		var fxn := ["hit_spark", "slash_arc", "hit_heavy", "cast_glow", "explosion", "fire_burst", "block_spark", "lightning_strike"]
		for v in visuals:
			if not v.visible:
				continue
			if randf() < 0.5:
				fx.play(StringName(fxn[randi() % fxn.size()]), v.global_position + Vector3(0, 1, 0), Vector3.FORWARD, Color.WHITE, 1.0)
			if randf() < 0.3:
				fx.damage_number(v.global_position + Vector3(0, 2, 0), randi() % 900, &"phys" if randf() < 0.8 else &"crit")
	if _perf_t > 11.0 and _perf_frames > 0:
		print("PERF avg fps %.1f over %d frames (10 anime fighters%s) %s" % [_perf_frames / _perf_acc, _perf_frames, "" if _args.has("nofx") else " + fx", str(get_window().size)])
		print("PERF draw calls %d, primitives %d, cpu process %.2f ms" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		_perf = false
		if _args.has("quit"):
			get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_RIGHT:
				anim_index = (anim_index + 1) % anim_keys.size()
				_play_all(anim_keys[anim_index])
			KEY_LEFT:
				anim_index = (anim_index - 1 + anim_keys.size()) % anim_keys.size()
				_play_all(anim_keys[anim_index])
			KEY_1:
				_set_view("front")
			KEY_2:
				_set_view("hero")
			KEY_3:
				_set_view("close:0")
			KEY_4:
				_set_view("gameplay")
			KEY_F:
				_fx_demo("fx")
			KEY_S:
				status_on = not status_on
				for i in visuals.size():
					visuals[i].set_status_visual((1 << (i % 25)) if status_on else 0)


func _take_shot() -> void:
	var wait := float(_args.get("wait", "2.0"))
	await get_tree().create_timer(wait).timeout
	if _args.has("morph"):
		# umbrella form change caught mid-transition: --morph=<form>[@seconds]
		var ms := String(_args["morph"]).split("@")
		for v in visuals:
			if v.visible and v.weapon_type in WeaponFactory.UMBRELLA_FORMS:
				v.set_weapon(ms[0])
		await get_tree().create_timer(float(ms[1]) if ms.size() > 1 else 0.08).timeout
	if _args.has("pose"):
		# freeze every body at a clip time for comparable shots: --pose=<key>@<t>
		var kt := String(_args["pose"]).split("@")
		for v in visuals:
			if v.visible and v.anim_player:
				v.play(StringName(kt[0]))
				v.pose_clip(v.current_clip, float(kt[1]) if kt.size() > 1 else 0.3)
		await get_tree().process_frame
		await get_tree().process_frame
	# stills: let the cloth settle at the shown pose (paused poses never move it otherwise)
	for n in find_children("*", "CharacterVisual", true, false):
		var cv := n as CharacterVisual
		if cv.is_visible_in_tree() and (cv.anim_player == null or not cv.anim_player.is_playing()):
			cv.settle_cloth()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args["shot"])
	print("SHOT saved ", _args["shot"])
	get_tree().quit()
