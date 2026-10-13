extends SceneTree
## Prints the node tree of an imported scene (used to find the Skeleton3D path for retarget import settings).
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var n: Node = (load(p) as PackedScene).instantiate()
		_dump(n, 0)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			print("  anims: ", ap.get_animation_list().size())
		n.free()
	quit()
func _dump(n: Node, d: int) -> void:
	if d > 3: return
	var extra := ""
	if n is Skeleton3D: extra = " bones=%d first=%s" % [(n as Skeleton3D).get_bone_count(), (n as Skeleton3D).get_bone_name(0)]
	print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children(): _dump(c, d + 1)
