class_name VfxFlash
extends MeshInstance3D
## One animated VFX piece (arc, glyph, ring, billboard, shard, pillar...). Pooled and stepped by Fx (one loop
## for every live piece, no per-node _process). Drives the `fade` instance uniform (alpha-erosion / fade out)
## and any number of instance-uniform tweens, plus scale, spin and simple ballistic motion.

var life := 0.3
var age := 0.0
var delay := 0.0              # hidden until age >= delay (anticipation staggering)
var s0 := Vector3.ONE
var s1 := Vector3.ONE
var scale_exp := 0.4          # ease() exponent for s0 -> s1
var rot := Basis.IDENTITY     # orientation (scale is applied on top every frame)
var spin := Vector3.ZERO      # rad/s around local X/Y/Z
var vel := Vector3.ZERO
var grav := 0.0
var damp := 0.0
var align_vel := false
var grow_time := 0.0          # > 0: scale s0 -> s1 over grow_time, then hold
var keep_scale := false       # legacy flag (kept for compatibility)
var fade_tail := 1.0          # fraction of the life used for fading out
var fade_in := 0.0            # seconds of fade-in after delay
var offset_half := false      # spikes: keep the base on the ground while growing
var uses_shader := true       # drives the `fade` instance uniform (all VFX shaders have it)
var tint := Color.WHITE       # legacy (instance colours are set by the builders)
var tweens: Array = []        # [param: StringName, from: float, to: float, exp: float, t_end: float]
var pooled := false
var _base_y := 0.0


func reset_state() -> void:
	life = 0.3
	age = 0.0
	delay = 0.0
	s0 = Vector3.ONE
	s1 = Vector3.ONE
	scale_exp = 0.4
	rot = Basis.IDENTITY
	spin = Vector3.ZERO
	vel = Vector3.ZERO
	grav = 0.0
	damp = 0.0
	align_vel = false
	grow_time = 0.0
	keep_scale = false
	fade_tail = 1.0
	fade_in = 0.0
	offset_half = false
	uses_shader = true
	tweens = []
	_base_y = 0.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func mark_base() -> void:
	_base_y = position.y


## Tweens an instance uniform from -> to over the first `t_end` fraction of the life (ease exponent exp_k).
func tween(param: StringName, from: float, to: float, exp_k := 1.0, t_end := 1.0) -> VfxFlash:
	tweens.append([param, from, to, exp_k, maxf(t_end, 0.001)])
	set_instance_shader_parameter(param, from)
	return self


## Advances the piece; false when its life is over.
func step(delta: float) -> bool:
	age += delta
	if age >= life + delay:
		return false
	if age < delay:
		visible = false
		return true
	visible = true
	var la := age - delay
	if vel != Vector3.ZERO or grav != 0.0:
		vel.y -= grav * delta
		if damp > 0.0:
			vel *= maxf(0.0, 1.0 - damp * delta)
		position += vel * delta
		if align_vel and vel.length_squared() > 0.01:
			rot = Basis(Quaternion(Vector3.UP, vel.normalized()))
	if spin != Vector3.ZERO:
		if spin.y != 0.0:
			rot = rot * Basis(Vector3.UP, spin.y * delta)
		if spin.z != 0.0:
			rot = rot * Basis(Vector3.BACK, spin.z * delta)
		if spin.x != 0.0:
			rot = rot * Basis(Vector3.RIGHT, spin.x * delta)
	apply(la / life)
	return true


func apply(t: float) -> void:
	var k := t
	if grow_time > 0.0:
		k = clampf((age - delay) / grow_time, 0.0, 1.0)
	var sc := s0.lerp(s1, ease(clampf(k, 0.0, 1.0), scale_exp))
	basis = rot.orthonormalized() * Basis.from_scale(sc.max(Vector3.ONE * 0.001))
	if offset_half:
		position.y = _base_y + sc.y * 0.5
	var f := clampf((1.0 - t) / maxf(fade_tail, 0.01), 0.0, 1.0)
	if fade_in > 0.0:
		f *= clampf((age - delay) / fade_in, 0.0, 1.0)
	if uses_shader:
		set_instance_shader_parameter(&"fade", f)
	else:
		transparency = 1.0 - f
	for tw: Array in tweens:
		set_instance_shader_parameter(tw[0], lerpf(tw[1], tw[2], ease(clampf(t / float(tw[4]), 0.0, 1.0), tw[3])))
