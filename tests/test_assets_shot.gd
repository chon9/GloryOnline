extends SceneTree
## ASSETS visual check helper (needs a display; skips in --headless):
##   godot --path . -s res://tests/test_assets_shot.gd -- --scene=res://scenes/sandbox_core.tscn --shot=<png> [--wait=2]
## Loads a scene, waits, saves a screenshot of the viewport, quits.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	if DisplayServer.get_name() == "headless":
		print("ASSETS TESTS: 0 passed, 0 failed (screenshot skipped: headless)")
		quit()
		return
	var ps: PackedScene = load(String(args.get("scene", "res://scenes/gallery.tscn")))
	root.add_child(ps.instantiate())
	await create_timer(float(args.get("wait", "2.0"))).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var out := String(args.get("shot", "user://assets_shot.png"))
	img.save_png(out)
	print("SHOT saved ", out)
	quit()
