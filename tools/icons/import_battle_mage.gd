extends SceneTree
## Resize imagegen masters for the HUD. Run with -- <absolute master directory>.
## Source filenames are recorded in the adjacent provenance.json.

func _initialize() -> void:
	var dir := "res://assets/icons/skills/battle_mage_painted/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "provenance.json"))
	var args := OS.get_cmdline_user_args()
	for entry: Dictionary in data["assets"]:
		var source: String = entry["source"]
		if not args.is_empty():
			source = args[0].path_join(source.replace("\\", "/").get_file())
		var original := Image.load_from_file(source)
		if original == null or original.is_empty():
			push_error("Missing imagegen master: " + source)
			quit(1)
			return
		for size: int in [128, 256]:
			var img := original.duplicate() as Image
			img.resize(size, size, Image.INTERPOLATE_LANCZOS)
			var suffix := "@2x" if size == 256 else ""
			var result := img.save_png(dir + str(entry["id"]) + suffix + ".png")
			if result != OK:
				quit(1)
				return
	print("Imported 8 Battle Mage illustrations at 128 and 256 pixels")
	quit()
