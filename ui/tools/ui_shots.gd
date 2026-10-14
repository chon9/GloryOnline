extends SceneTree
## UI screenshot driver through the REAL scenes (main menu -> solo lobby -> matches with bots -> results).
## Non-headless console exe only:
##   godot --path . -s res://ui/tools/ui_shots.gd -- --out=<dir> --res=1920x1080 [--only=menu,lobby,duel,team,raid,results,credits,help]
## Files: <out>/mig_ui_<shot>_<width>.png

var out_dir: String = "user://shots"
var res: Vector2i = Vector2i(1920, 1080)
var only: PackedStringArray = []
var game: Node


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--res="):
			var p := a.trim_prefix("--res=").split("x")
			res = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	_main.call_deferred()


func want(n: String) -> bool:
	return only.is_empty() or only.has(n)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func secs(t: float) -> void:
	await create_timer(t).timeout


func wait_until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("mig_ui_%s_%d.png" % [n, res.x])
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


func _main() -> void:
	root.borderless = true
	root.position = Vector2i.ZERO
	root.size = res
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	game.results_auto_return = 120.0
	change_scene_to_file("res://scenes/main.tscn")
	await frames(10)
	await secs(1.0)
	if want("menu"):
		await shot("menu")
	if want("credits"):
		var mm: Node = current_scene
		mm.call("_open_panel", "credits")
		await secs(0.5)
		await shot("credits")
		mm.call("_open_panel", "credits")
	if want("settings"):
		current_scene.call("_open_panel", "settings")
		await secs(0.4)
		await shot("settings")
		current_scene.call("_open_panel", "settings")
	game.start_solo()
	await frames(5)
	game.set_my_class("battle_mage")
	game.set_setting("mode", "team")
	game.set_setting("team_size", 3)
	await secs(2.5)
	if want("lobby"):
		await shot("lobby")
	if want("lobby2"):
		var lobby: Node = current_scene.get_node("Lobby")
		(lobby.get("_card") as Node).call("preview", "launcher")
		await secs(2.0)
		await shot("lobby2")
	game.set_setting("rounds_to_win", 1)
	game.set_setting("round_time", 300)
	for mode: String in ["duel", "team", "raid"]:
		if not (want(mode) or (mode == "duel" and want("results")) or (mode == "team" and (want("scoreboard") or want("help")))):
			continue
		game.set_setting("mode", mode)
		if mode == "team":
			game.set_setting("team_size", 5)
		game.set_my_class(["battle_mage", "launcher", "blade_master"][["duel", "team", "raid"].find(mode)])
		await frames(3)
		var why: String = game.start_match()
		if why != "":
			print("start failed: ", why)
			continue
		await wait_until(func() -> bool: return current_scene != null and current_scene.name == "MatchScene", 30.0)
		var scene := current_scene
		scene.set("input_enabled", false)
		var w: World = scene.get("world")
		await wait_until(func() -> bool: return w.local_fighter() != null, 20.0)
		var mnode: Node = scene.get("mode")
		var me := w.local_fighter()
		if mode == "raid":
			mnode.call("debug_skip_to", (mnode.get("encounters") as Array).size() - 1)
			await secs(1.0)
		me.kind = "bot"
		w.attach_brain(me, "raid" if mode == "raid" else "pvp")
		me.kind = "player"
		await secs(9.0 if mode != "raid" else 12.0)
		# lock on to someone for the target frame
		var foes := w.team_fighters(1)
		if not foes.is_empty() and mode != "raid":
			me.target_uid = foes[0].uid
		if want(mode):
			await shot(mode)
		var hud: Node = scene.get("hud")
		if mode == "team" and want("scoreboard"):
			hud.call("set_scoreboard_forced", true)
			await secs(0.6)
			await shot("scoreboard")
			hud.call("set_scoreboard_forced", false)
		if mode == "team" and want("help"):
			hud.call("set_help_visible", true)
			await secs(0.4)
			await shot("help")
			hud.call("set_help_visible", false)
		if mode == "duel" and want("results"):
			mnode.call("finish", 0)
			await wait_until(func() -> bool: return current_scene.has_node("Results"), 15.0)
			await secs(1.2)
			await shot("results")
		game.return_to_lobby()
		await wait_until(func() -> bool: return game.state == 1 and current_scene != null and current_scene.name == "Main", 20.0)
		await secs(1.0)
	quit(0)
