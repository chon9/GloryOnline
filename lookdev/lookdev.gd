extends Node3D
## RONGYAO look-dev vertical slice (Art Bible v1).
## Run:   godot --path . res://lookdev/lookdev.tscn
## Shots: godot --path . --resolution 1920x1080 res://lookdev/lookdev.tscn -- --view=<view> --shot=<png> [--wait=<s>]
## Views: wide | gameplay | close | vfx | hud | test | perf (prints FPS; add --static=1 to skip VFX rebuilds,
##        --nodof=1 to drop depth of field; run with --disable-vsync for uncapped numbers)
## Keys:  1..5 switch views, Space = fire the VFX sequence (with hit-stop), H = toggle HUD.

var env_root: Node3D
var cam: Camera3D
var chars: Dictionary = {}
var vfx: LdVfx
var hud: CanvasLayer
var _args: Dictionary = {}
var _perf := {"on": false, "t": 0.0, "frames": 0, "acc": 0.0}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var view: String = _args.get("view", "gameplay")
	if _args.has("shot"):
		# exact 1920x1080 framebuffer for screenshots (a decorated window gets clipped by the taskbar)
		get_window().borderless = true
		get_window().position = Vector2i.ZERO
		get_window().size = Vector2i(1920, 1080)
	LdClasses.gun_pitch = float(_args.get("gunpitch", str(LdClasses.gun_pitch)))
	env_root = LdEnvironment.build(self)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	chars = LdRoster.spawn(self)
	vfx = LdVfx.new()
	add_child(vfx)
	hud = LdHud.build(self)
	hud.visible = view in ["gameplay", "hud", "perf"]
	_set_view(view)
	if _args.has("shot"):
		_take_shot.call_deferred()


func _set_view(view: String) -> void:
	var bm: Node3D = chars["battle_mage"]
	var staging := {"wide": "idle", "close": "portrait", "test": "lineup"}
	LdRoster.stage(chars, staging.get(view, "combat"))
	# depth of field (bible 3.2): cinematic far blur for wide / close / VFX views, only a light far blur in play
	var dof := {"wide": [30.0, 45.0, 0.07], "close": [5.5, 9.0, 0.09], "vfx": [16.0, 22.0, 0.07], "gameplay": [45.0, 50.0, 0.05], "hud": [45.0, 50.0, 0.05], "perf": [45.0, 50.0, 0.05]}
	if dof.has(view) and not _args.has("nodof"):
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = dof[view][0]
		ca.dof_blur_far_transition = dof[view][1]
		ca.dof_blur_amount = dof[view][2]
		cam.attributes = ca
	match view:
		"wide":
			cam.fov = 42.0
			cam.position = Vector3(-11.0, 2.6, 14.0)
			cam.look_at(Vector3(2.5, 4.6, -6.0))
		"gameplay", "perf":
			_third_person(bm)
			await vfx.combat_moment(chars, 0.45)
			LdHud.place_numbers(hud, cam, vfx.impact_points)
			LdHud.aim_portrait(hud, bm)
			_perf["on"] = view == "perf"
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		"close":
			await get_tree().process_frame
			var f := bm.global_basis.z.normalized()
			var sd := bm.global_basis.x.normalized()
			cam.fov = 30.0
			cam.position = bm.global_position + f * 2.7 - sd * 0.8 + Vector3.UP * 1.45
			cam.look_at(bm.global_position + Vector3.UP * 1.42 - sd * 0.12)
		"vfx":
			var vf := bm.global_basis.z.normalized()
			var vs := bm.global_basis.x.normalized()
			cam.fov = 44.0
			cam.position = bm.global_position - vs * 6.2 + vf * 1.2 + Vector3.UP * 1.9
			cam.look_at(bm.global_position + vf * 1.6 + Vector3.UP * 1.3)
			await vfx.combat_moment(chars, float(_args.get("t", "0.45")))
			vfx.impact_frame(cam, vfx.impact_points.get("blast", Vector3.ZERO), Color(1.0, 0.85, 0.6))
		"hud":
			_third_person(bm)
			await vfx.combat_moment(chars, 0.45)
			LdHud.aim_portrait(hud, bm)
			LdHud.show_sheet(hud)
		"clips":
			# debug contact sheet: --cls=<class id> --clips=Clip@time,Clip@time,...
			for c in chars.values():
				c.visible = false
			var list: PackedStringArray = String(_args.get("clips", "Idle_A@0.5")).split(",")
			var cls: String = _args.get("cls", "battle_mage")
			for i in list.size():
				var ch := LdCharacter.new(LdClasses.battle_mage() if cls == "battle_mage" else (LdClasses.launcher() if cls == "launcher" else LdClasses.witch()))
				add_child(ch)
				ch.position = Vector3((i - (list.size() - 1) * 0.5) * 1.9, LdEnvironment.ARENA_Y, 3.0)
				var kv := list[i].split("@")
				ch.pose(kv[0], float(kv[1]))
			cam.fov = 40.0
			cam.position = Vector3(0, 2.6, 3.0 + list.size() * 1.25 + 1.5)
			cam.look_at(Vector3(0, 2.0, 3.0))
		"test":
			cam.fov = 35.0
			cam.position = Vector3(0, 1.3, 8.0)
			cam.look_at(Vector3(0, 1.0, 0))


## MMO third-person camera: behind and above the player, ~35 deg down, looking a few metres ahead.
func _third_person(p: Node3D) -> void:
	var fwd := p.global_basis.z.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	cam.fov = 55.0
	cam.position = p.global_position - fwd * 5.6 + Vector3.UP * 4.1 - side * 0.9
	cam.look_at(p.global_position + fwd * 3.2 + Vector3.UP * 0.9)


func _process(delta: float) -> void:
	if not _perf["on"]:
		return
	_perf["t"] += delta
	if _perf["t"] > 2.0:
		_perf["acc"] += delta
		_perf["frames"] += 1
	if _perf["t"] > 2.0 and int(_perf["t"] * 10.0) % 12 == 0 and not _args.has("static"):
		vfx.combat_moment(chars, 0.0)
	if _perf["t"] > 12.0:
		var vr := get_viewport().get_viewport_rid()
		print("PERF lookdev avg fps %.1f over %d frames (3 characters + VFX + HUD), render cpu %.2f ms, gpu %.2f ms, draw calls %d, primitives %d" % [
			_perf["frames"] / _perf["acc"], _perf["frames"],
			RenderingServer.viewport_get_measured_render_time_cpu(vr), RenderingServer.viewport_get_measured_render_time_gpu(vr),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		_perf["on"] = false
		if _args.has("quit"):
			get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_1: _set_view("wide")
			KEY_2: _set_view("gameplay")
			KEY_3: _set_view("close")
			KEY_4: _set_view("vfx")
			KEY_5: _set_view("hud")
			KEY_SPACE: vfx.play_sequence(chars)
			KEY_H: hud.visible = not hud.visible


func _take_shot() -> void:
	var wait := float(_args.get("wait", "2.5"))
	await get_tree().create_timer(wait).timeout
	if _args.has("freeze"):
		LdRoster.stage(chars, _args.get("freeze"))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args["shot"])
	print("SHOT saved ", _args["shot"], " ", img.get_size())
	get_tree().quit()
