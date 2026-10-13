class_name LdRoster
extends RefCounted
## The three hero characters of the slice and their staging per camera view.
## Staging = position on the arena, facing, and a clip (+ optional frozen time for deterministic shots).

const Y := LdEnvironment.ARENA_Y

static func spawn(root: Node3D) -> Dictionary:
	var out := {}
	for c in [LdClasses.battle_mage(), LdClasses.launcher(), LdClasses.witch()]:
		var ch := LdCharacter.new(c)
		root.add_child(ch)
		out[c["id"]] = ch
	return out


static func face(c: Node3D, target: Vector3) -> void:
	var d := target - c.global_position
	c.rotation.y = atan2(d.x, d.z)


static func stage(chars: Dictionary, mode: String) -> void:
	var bm: LdCharacter = chars["battle_mage"]
	var la: LdCharacter = chars["launcher"]
	var wi: LdCharacter = chars["witch"]
	match mode:
		"lineup":
			bm.position = Vector3(0, Y, 0)
			la.position = Vector3(1.6, Y, 0)
			wi.position = Vector3(-1.6, Y, 0)
			for c in [bm, la, wi]:
				c.rotation.y = 0.0
				c.play(c.cfg.get("idle", "Idle_A"))
		"idle", "portrait":
			bm.position = Vector3(0.0, Y, 1.5)
			la.position = Vector3(2.8, Y, -3.6)
			wi.position = Vector3(-3.4, Y, -2.6)
			face(bm, Vector3(-4.0, Y, 9.0) if mode == "portrait" else Vector3(-3.0, Y, 8.0))
			face(la, bm.position + Vector3(-1, 0, 2))
			face(wi, bm.position + Vector3(1, 0, 2))
			if mode == "portrait":
				bm.pose(bm.cfg["portrait"], 0.5)
			else:
				bm.play(bm.cfg["idle"])
			la.play("Pistol_Aim_Neutral" if mode == "idle" else la.cfg["idle"])
			wi.play(wi.cfg["idle"])
		"combat":
			bm.position = Vector3(0.0, Y, 1.5)
			la.position = Vector3(4.6, Y, -4.4)
			wi.position = Vector3(-3.4, Y, -2.4)
			face(bm, la.position + Vector3(-4.2, 0, -1.0))
			face(la, bm.position)
			face(wi, la.position)
			for c in [bm, la, wi]:
				c.pose(c.cfg["skill"], c.cfg.get("skill_t", 0.3))
