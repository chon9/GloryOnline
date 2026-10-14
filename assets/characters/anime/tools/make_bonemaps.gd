extends SceneTree
## Generates the BoneMap resources used by the retarget import settings:
##   vroid.tres  - VRoid / VRM 0.x J_Bip_* skeleton -> SkeletonProfileHumanoid
##   m2m.tres    - Mesh2Motion / Quaternius UE-style skeleton -> SkeletonProfileHumanoid
##   kaykit.tres - KayKit Rig_Medium (23 bones, no neck/shoulders) -> SkeletonProfileHumanoid (gap-filler clips)
## Run: godot --headless --path . -s res://assets/characters/anime/tools/make_bonemaps.gd
const OUT := "res://assets/characters/anime/retarget/"

func _save(pairs: Dictionary, file: String) -> void:
	var bm := BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for k in pairs:
		bm.set_skeleton_bone_name(k, pairs[k])
	print(file, " -> ", ResourceSaver.save(bm, OUT + file))

func _init() -> void:
	var v := {"Hips": "J_Bip_C_Hips", "Spine": "J_Bip_C_Spine", "Chest": "J_Bip_C_Chest", "UpperChest": "J_Bip_C_UpperChest",
		"Neck": "J_Bip_C_Neck", "Head": "J_Bip_C_Head", "LeftEye": "J_Adj_L_FaceEye", "RightEye": "J_Adj_R_FaceEye"}
	var m := {"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03", "Neck": "neck_01", "Head": "head"}
	for s: String in ["Left", "Right"]:
		var c := s.substr(0, 1)
		var x := c.to_lower()
		v[s + "Shoulder"] = "J_Bip_%s_Shoulder" % c
		v[s + "UpperArm"] = "J_Bip_%s_UpperArm" % c
		v[s + "LowerArm"] = "J_Bip_%s_LowerArm" % c
		v[s + "Hand"] = "J_Bip_%s_Hand" % c
		v[s + "UpperLeg"] = "J_Bip_%s_UpperLeg" % c
		v[s + "LowerLeg"] = "J_Bip_%s_LowerLeg" % c
		v[s + "Foot"] = "J_Bip_%s_Foot" % c
		v[s + "Toes"] = "J_Bip_%s_ToeBase" % c
		v[s + "ThumbMetacarpal"] = "J_Bip_%s_Thumb1" % c
		v[s + "ThumbProximal"] = "J_Bip_%s_Thumb2" % c
		v[s + "ThumbDistal"] = "J_Bip_%s_Thumb3" % c
		m[s + "Shoulder"] = "clavicle_" + x
		m[s + "UpperArm"] = "upperarm_" + x
		m[s + "LowerArm"] = "lowerarm_" + x
		m[s + "Hand"] = "hand_" + x
		m[s + "UpperLeg"] = "thigh_" + x
		m[s + "LowerLeg"] = "calf_" + x
		m[s + "Foot"] = "foot_" + x
		m[s + "Toes"] = "ball_" + x
		m[s + "ThumbMetacarpal"] = "thumb_01_" + x
		m[s + "ThumbProximal"] = "thumb_02_" + x
		m[s + "ThumbDistal"] = "thumb_03_" + x
		for f in [["Index", "Index", "index"], ["Middle", "Middle", "middle"], ["Ring", "Ring", "ring"], ["Little", "Little", "pinky"]]:
			var seg: Array = ["Proximal", "Intermediate", "Distal"]
			for i in 3:
				v[s + f[0] + seg[i]] = "J_Bip_%s_%s%d" % [c, f[1], i + 1]
				m[s + f[0] + seg[i]] = "%s_0%d_%s" % [f[2], i + 1, x]
	var k := {"Root": "root", "Hips": "hips", "Spine": "spine", "Chest": "chest", "Head": "head"}
	for s: String in ["Left", "Right"]:
		var x := s.substr(0, 1).to_lower()
		k[s + "UpperArm"] = "upperarm." + x
		k[s + "LowerArm"] = "lowerarm." + x
		k[s + "Hand"] = "wrist." + x
		k[s + "UpperLeg"] = "upperleg." + x
		k[s + "LowerLeg"] = "lowerleg." + x
		k[s + "Foot"] = "foot." + x
		k[s + "Toes"] = "toes." + x
	_save(k, "kaykit.tres")
	_save(v, "vroid.tres")
	_save(m, "m2m.tres")
	quit()
