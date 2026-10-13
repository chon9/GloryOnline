extends SceneTree
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var n: Node = (load(p) as PackedScene).instantiate()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				print(mi.name, " s", s, " ", mat.resource_name if mat else "-", " ", mat.get_class() if mat else "", " tex=", (mat as BaseMaterial3D).albedo_texture != null if mat is BaseMaterial3D else "")
		var sk := n.find_child("GeneralSkeleton", true, false) as Skeleton3D
		var h := sk.find_bone("RightHand")
		print("RightHand global rest: ", sk.get_bone_global_rest(h))
		print("Head global rest: ", sk.get_bone_global_rest(sk.find_bone("Head")).origin, " motion_scale ", sk.motion_scale)
		n.free()
	quit()
