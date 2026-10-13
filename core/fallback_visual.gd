class_name FallbackVisual
extends Node3D
## Procedural stand-in for CharacterVisual so core runs without the ASSETS module: a team-colored capsule,
## a head, and a box "weapon" with simple procedural poses for every abstract animation key (§7.1).

var _body: MeshInstance3D
var _head: MeshInstance3D
var _weapon_pivot: Node3D
var _weapon: MeshInstance3D
var _mat: StandardMaterial3D
var _wmat: StandardMaterial3D
var _base_color: Color = Color.WHITE
var _anim: StringName = &"idle"
var _anim_t: float = 0.0
var _speed: float = 1.0
var _flash: float = 0.0
var _status_mask: int = 0
var _alpha: float = 1.0


func build(team_color: Color, tint: Color, weapon_type: String) -> void:
	_base_color = team_color
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = team_color
	_mat.roughness = 0.6
	_body = MeshInstance3D.new()
	_body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.5
	_body.mesh = cap
	_body.material_override = _mat
	_body.position = Vector3(0, 0.75, 0)
	add_child(_body)
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	_head.mesh = sph
	_head.material_override = _mat
	_head.position = Vector3(0, 0.7, -0.05)
	_body.add_child(_head)
	# Nose marker so facing is readable.
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.08, 0.08, 0.15)
	nose.mesh = nb
	nose.material_override = _mat
	nose.position = Vector3(0, 0, -0.2)
	_head.add_child(nose)
	_weapon_pivot = Node3D.new()
	_weapon_pivot.name = "WeaponPivot"
	_weapon_pivot.position = Vector3(0.38, 0.3, -0.1)
	_body.add_child(_weapon_pivot)
	_wmat = StandardMaterial3D.new()
	_wmat.albedo_color = tint.lerp(Color(0.8, 0.8, 0.85), 0.4)
	_wmat.emission_enabled = true
	_wmat.emission = tint * 0.4
	_weapon = MeshInstance3D.new()
	_weapon.name = "Weapon"
	var wb := BoxMesh.new()
	var length := 1.0
	if weapon_type in ["greatsword", "great_axe", "battle_lance", "war_scythe", "staff", "staff_ring", "broom"]:
		length = 1.5
	elif weapon_type in ["gloves", "gloves_qi", "claws", "dagger", "revolver", "auto_pistol", "cross"]:
		length = 0.45
	wb.size = Vector3(0.08, 0.08, length)
	_weapon.mesh = wb
	_weapon.material_override = _wmat
	_weapon.position = Vector3(0, 0, -length * 0.5)
	_weapon_pivot.add_child(_weapon)


func play(anim_key: StringName, speed := 1.0) -> void:
	_anim = anim_key
	_speed = speed
	_anim_t = 0.0


func set_weapon(_weapon_type: String, _offhand := "") -> void:
	pass


func set_alpha(a: float) -> void:
	_alpha = a
	for m: StandardMaterial3D in [_mat, _wmat]:
		if m == null:
			continue
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = a


func set_status_visual(mask: int) -> void:
	_status_mask = mask


func flash_hit() -> void:
	_flash = 0.12


func get_hand_position(_right := true) -> Vector3:
	if _weapon_pivot != null and _weapon_pivot.is_inside_tree():
		return _weapon_pivot.global_position
	return Vector3.ZERO


func _process(delta: float) -> void:
	if _body == null:
		return
	_anim_t += delta * _speed
	var t := _anim_t
	var tilt := Vector3.ZERO
	var y := 0.75
	var swing := Vector3(-0.3, 0.0, 0.0)
	var key := str(_anim)
	if key == "run" or key == "walk":
		y += absf(sin(t * 12.0)) * 0.06
		tilt.x = -0.15
	elif key == "launched":
		tilt.x = 0.9
	elif key == "knockdown" or key == "death":
		tilt.x = minf(1.0, t * 6.0) * 1.5
		y = 0.75 - minf(1.0, t * 6.0) * 0.45
	elif key == "getup":
		tilt.x = maxf(0.0, 1.0 - t * 2.5) * 1.5
	elif key == "hit":
		tilt.x = 0.35 * maxf(0.0, 1.0 - t * 3.0)
	elif key == "stunned":
		tilt.z = sin(t * 8.0) * 0.2
	elif key == "jump":
		y += 0.05
	elif key == "block":
		swing = Vector3(0.0, 1.2, 0.0)
	elif key.begins_with("cast") or key == "channel" or key == "summon" or key == "heal":
		swing = Vector3(1.4, 0.0, 0.0)
	elif key.begins_with("attack") or key in ["punch", "punch_combo", "kick", "grab", "throw", "aerial", "dash", "leap"]:
		var k := clampf(t / 0.25, 0.0, 1.0)
		swing = Vector3(1.2 - 2.4 * k, -1.0 + 2.0 * k, 0.0)
	elif key.begins_with("shoot"):
		swing = Vector3(0.0, 0.0, 0.0)
	_body.rotation = tilt
	_body.position.y = y
	_weapon_pivot.rotation = swing
	var em := Color.BLACK
	if _flash > 0.0:
		_flash -= delta
		em = Color(1, 1, 1)
	elif (_status_mask & StatusSet.bit_of(&"freeze")) != 0:
		em = Color(0.3, 0.6, 1.0)
	elif (_status_mask & StatusSet.bit_of(&"super_armor")) != 0:
		em = Color(0.9, 0.6, 0.1) * (0.6 + 0.4 * sin(t * 10.0))
	elif (_status_mask & (StatusSet.bit_of(&"stun") | StatusSet.bit_of(&"sleep"))) != 0:
		em = Color(0.8, 0.8, 0.2) * 0.5
	elif (_status_mask & StatusSet.bit_of(&"shield")) != 0:
		em = Color(0.4, 0.8, 1.0) * 0.4
	elif (_status_mask & (StatusSet.bit_of(&"burn") | StatusSet.bit_of(&"poison") | StatusSet.bit_of(&"bleed"))) != 0:
		em = Color(0.8, 0.2, 0.1) * 0.4
	_mat.emission_enabled = em != Color.BLACK
	_mat.emission = em
