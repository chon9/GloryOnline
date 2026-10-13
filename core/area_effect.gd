class_name AreaEffect
extends Node3D
## Host-simulated area (ARCHITECTURE §5.1 `ground`, `beam`, `trap`). Stepped by World.step().
##
## Geometry conventions (shared with Fx.spawn_area_visual):
##  - circle: centered on position, `radius`.
##  - ring:   centered on position, hits between radius-width and radius.
##  - line:   STARTS at position and extends `length` along yaw's forward (-Z rotated by yaw), `width` wide.
## Vertical extent: targets whose center lies within [y - 1, y + area_height] are inside.

var mode: String = "zone"            # "zone" (burst or persistent), "beam", "trap"
var caster: Fighter = null
var runner: SkillRunner = null
var team: int = 0
var shape: String = "circle"
var radius: float = 3.0
var length: float = 6.0
var width: float = 2.0
var area_height: float = 3.0
var yaw: float = 0.0
var delay: float = 0.0
var duration: float = 0.0            # 0 = single burst
var tick_interval: float = 0.5
var affects: String = "enemies"      # enemies | allies | all
var hit: Dictionary = {}
var ally_effect: Dictionary = {}     # {heal: frac, matk_scale, statuses: [...], shield: frac, shield_dur, cleanse: bool}
var visual: String = "rune"
var color: Color = Color.WHITE
var follow_caster: bool = false
var follow_aim: bool = false
var blocks_cast: bool = false        # SkillRunner waits for this effect (beams)
var max_hits_per_target: int = 0     # 0 = unlimited (persistent zones)
# trap
var arm_time: float = 0.5
var trigger_statuses: Array = []
var trap_key: String = ""

var fx_id: int = 0
var alive: bool = true
var triggered: bool = false
var _t: float = 0.0
var _tick_acc: float = 0.0
var _activated: bool = false
var _hit_counts: Dictionary = {}
var _vis_pos: Vector3 = Vector3.ZERO
var _vis_yaw: float = 0.0
var _vis_timer: float = 0.0
var _debug: MeshInstance3D = null


func _ready() -> void:
	var w := World.get_instance()
	if w != null:
		fx_id = w.next_fx_id()
	_follow()
	_spawn_visual()
	if CoreUtil.fx_is_stub():
		_build_debug()


func _caster_valid() -> bool:
	return caster != null and is_instance_valid(caster)


func _spawn_visual() -> void:
	var vis_dur := duration if mode != "trap" else duration
	var vis_delay := delay
	CoreUtil.fx(&"spawn_area_visual", [fx_id, visual, shape, global_position, yaw, radius, length, width, vis_delay, vis_dur, color])
	_vis_pos = global_position
	_vis_yaw = yaw


func _follow() -> void:
	if not follow_caster or not _caster_valid():
		return
	if follow_aim and mode == "beam":
		caster.face_towards(caster.aim_point())
	yaw = caster.facing_yaw
	var base := caster.global_position
	if mode == "beam":
		base += caster.forward() * (caster.radius() + 0.2)
		base.y = caster.global_position.y + 0.3
	global_position = base


func tick(delta: float) -> void:
	if not alive:
		return
	if follow_caster:
		if not _caster_valid() or not caster.is_alive():
			finish()
			return
		_follow()
		_vis_timer -= delta
		if _vis_timer <= 0.0 and (global_position.distance_to(_vis_pos) > 0.15 or absf(angle_difference(yaw, _vis_yaw)) > deg_to_rad(3.0)):
			var fx_node := CoreUtil.autoload("Fx")
			if fx_node != null and fx_node.has_method(&"move_area_visual"):
				# Cheap unreliable move of the live visual (no restart, no reliable traffic).
				_vis_timer = 1.0 / 20.0
				CoreUtil.fx(&"move_area_visual", [fx_id, global_position, yaw])
			else:
				# Fallback for an Fx without move support: rebuild the visual, rate-limited.
				_vis_timer = 0.3 if mode != "beam" else 0.1
				CoreUtil.fx(&"despawn", [fx_id])
				var w := World.get_instance()
				if w != null:
					fx_id = w.next_fx_id()
				var remaining := maxf(0.05, duration - maxf(0.0, _t - delay))
				CoreUtil.fx(&"spawn_area_visual", [fx_id, visual, shape, global_position, yaw, radius, length, width, maxf(0.0, delay - _t), remaining, color])
			_vis_pos = global_position
			_vis_yaw = yaw
	_t += delta
	if _debug != null:
		_update_debug()
	if _t < delay:
		return
	var active_t := _t - delay
	match mode:
		"trap":
			if active_t >= duration:
				finish()
				return
			if active_t < arm_time:
				return
			var victims := _enemies_inside()
			if not victims.is_empty():
				triggered = true
				for v: Fighter in victims:
					_hit_enemy(v)
					for s: Dictionary in trigger_statuses:
						v.add_status(s["id"], float(s["dur"]), float(s["power"]), caster if _caster_valid() else null)
				CoreUtil.fx(&"play", [&"explosion", global_position, Vector3.UP, color, radius / 2.0])
				finish()
		_:
			if not _activated:
				_activated = true
				_apply()
				if duration <= 0.0:
					finish()
					return
				_tick_acc = 0.0
			else:
				_tick_acc += delta
				while _tick_acc >= tick_interval and alive:
					_tick_acc -= tick_interval
					_apply()
			if active_t >= duration:
				finish()


## True if `f`'s body overlaps this area.
func contains(f: Fighter) -> bool:
	var c := f.center()
	var y0 := global_position.y - 1.0
	if c.y < y0 or c.y > global_position.y + area_height + f.height() * 0.5:
		return false
	var to := CoreUtil.flat(f.global_position - global_position)
	var fr := f.radius()
	match shape:
		"line":
			var fwd := CoreUtil.dir_of_yaw(yaw)
			var rgt := fwd.cross(Vector3.UP)
			var z := to.dot(fwd)
			var x := to.dot(rgt)
			return z >= -fr and z <= length + fr and absf(x) <= width * 0.5 + fr
		"ring":
			var d := to.length()
			return d <= radius + fr and d >= maxf(0.0, radius - width) - fr
		_:
			return to.length() <= radius + fr


func _enemies_inside() -> Array[Fighter]:
	var out: Array[Fighter] = []
	var w := World.get_instance()
	if w == null:
		return out
	for f: Fighter in w.fighters:
		if is_instance_valid(f) and f.team != team and f.is_hittable() and contains(f):
			out.append(f)
	return out


func _allies_inside() -> Array[Fighter]:
	var out: Array[Fighter] = []
	var w := World.get_instance()
	if w == null:
		return out
	for f: Fighter in w.fighters:
		if is_instance_valid(f) and f.team == team and f.is_alive() and contains(f):
			out.append(f)
	return out


func _hit_enemy(v: Fighter) -> void:
	if hit.is_empty():
		return
	if max_hits_per_target > 0:
		var n := int(_hit_counts.get(v.uid, 0))
		if n >= max_hits_per_target:
			return
		_hit_counts[v.uid] = n + 1
	var from := caster.global_position if _caster_valid() else global_position
	if runner != null and _caster_valid():
		runner.deal(v, hit, from)
	else:
		v.receive_hit(caster if _caster_valid() else null, hit, from)


func _apply() -> void:
	if affects == "enemies" or affects == "all":
		for v: Fighter in _enemies_inside():
			_hit_enemy(v)
	if (affects == "allies" or affects == "all") and not ally_effect.is_empty():
		var src: Fighter = caster if _caster_valid() else null
		for a: Fighter in _allies_inside():
			var heal_frac := SkillRunner.pf(ally_effect, "heal", 0.0)
			var mscale := SkillRunner.pf(ally_effect, "matk_scale", 0.0)
			if heal_frac > 0.0 or mscale > 0.0:
				a.heal(heal_frac * a.max_hp + (mscale * src.get_stat("matk") if src != null else 0.0), src)
			for s: Dictionary in CoreUtil.status_list(ally_effect.get("statuses", [])):
				a.add_status(s["id"], float(s["dur"]), float(s["power"]), src)
			var sh := SkillRunner.pf(ally_effect, "shield", 0.0)
			if sh > 0.0 and src != null:
				a.add_shield(sh * src.max_hp, SkillRunner.pf(ally_effect, "shield_dur", 6.0), src)
			if SkillRunner.pb(ally_effect, "cleanse", false):
				a.cleanse()
	if mode == "zone" and duration <= 0.0:
		CoreUtil.fx(&"play", [StringName(_burst_fx()), global_position, Vector3.UP, color, radius / 2.5])


func _burst_fx() -> String:
	match visual:
		"fire":
			return "fire_burst"
		"ice":
			return "ice_burst"
		"lightning":
			return "lightning_strike"
		"holy":
			return "holy_burst"
		"dark", "blood":
			return "dark_burst"
		"poison":
			return "poison_cloud"
	return "explosion"


func finish() -> void:
	if not alive:
		return
	alive = false
	CoreUtil.fx(&"despawn", [fx_id])
	queue_free()


## Removed while still alive (World freed / round reset / parent cleared): drop the visual on every peer.
func _exit_tree() -> void:
	if alive:
		alive = false
		if fx_id != 0:
			CoreUtil.fx(&"despawn", [fx_id])


# ---------------------------------------------------------------- host debug mesh (Fx stub only)
func _build_debug() -> void:
	_debug = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.25)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if shape == "line":
		var b := BoxMesh.new()
		b.size = Vector3(width, 0.1, length)
		_debug.mesh = b
		_debug.position = Vector3(0, 0.06, -length * 0.5)
	else:
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = 0.1
		_debug.mesh = c
		_debug.position = Vector3(0, 0.06, 0)
	_debug.material_override = mat
	add_child(_debug)
	_update_debug()


func _update_debug() -> void:
	rotation.y = yaw
	var mat := _debug.material_override as StandardMaterial3D
	var a := 0.12 if _t < delay else 0.35
	if mode == "trap" and _t - delay < arm_time:
		a = 0.08
	mat.albedo_color.a = a
