extends SceneTree
## Debug: prints hand axes vs forearm direction for a clip/time (used to calibrate weapon grips).
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var c := LdCharacter.new(LdClasses.launcher())
	root.add_child(c)
	await process_frame
	for spec in a:
		var kv := spec.split("@")
		c.pose(kv[0], float(kv[1]))
		await process_frame
		var sk := c.skeleton
		var h := sk.get_bone_global_pose(sk.find_bone("RightHand"))
		var la := sk.get_bone_global_pose(sk.find_bone("RightLowerArm"))
		var fwd := (h.origin - la.origin).normalized()
		print(spec, " forearm=", fwd.snappedf(0.01), " handX=", h.basis.x.normalized().snappedf(0.01), " handY=", h.basis.y.normalized().snappedf(0.01), " handZ=", h.basis.z.normalized().snappedf(0.01), " hand=", h.origin.snappedf(0.01))
	quit()
