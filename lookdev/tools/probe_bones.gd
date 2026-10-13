extends SceneTree
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var n: Node = (load(p) as PackedScene).instantiate()
		var sk := n.find_child("GeneralSkeleton", true, false) as Skeleton3D
		print(p.get_file())
		for b in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightMiddleProximal", "LeftUpperArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]:
			var x := sk.get_bone_global_rest(sk.find_bone(b))
			print("  %-20s %s  X%s Y%s Z%s" % [b, x.origin.snappedf(0.001), x.basis.x.snappedf(0.01), x.basis.y.snappedf(0.01), x.basis.z.snappedf(0.01)])
		n.free()
	quit()
