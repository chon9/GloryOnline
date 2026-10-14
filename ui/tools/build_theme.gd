extends SceneTree
## Saves ui/ui_theme.gd build() to res://ui/theme.tres.
##   godot --headless --path . -s res://ui/tools/build_theme.gd


func _initialize() -> void:
	var t: Theme = (load("res://ui/ui_theme.gd") as Script).call("build")
	var e := ResourceSaver.save(t, "res://ui/theme.tres")
	print("THEME saved: ", error_string(e))
	quit(0 if e == OK else 1)
