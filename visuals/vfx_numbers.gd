class_name VfxDamageNumber
extends Label3D
## Damage number (bible 5.5): bold condensed numerals (Teko) with a dark outline and a drop shadow; pops at
## 140% and settles to 100% in 6 frames, then floats up while fading. Crits are gold, bigger, with a "暴击" tag;
## heals green with "+"; misses grey "MISS" with "闪避"; true damage red. Pooled by Fx.

const COLORS: Dictionary = {
	&"phys": Color("#FFFFFF"), &"magic": Color("#E4D6FF"), &"crit": Color("#FFC43A"),
	&"heal": Color("#7CF0A0"), &"miss": Color("#B4B8C0"), &"true": Color("#FF4A4A"), &"absorb": Color("#8FD8FF"),
}

var age := 0.0
var life := 0.9
var vel := Vector3(0, 2.4, 0)
var big := false
var pop := 0.4
var _shadow: Label3D
var _tag: Label3D


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	pixel_size = 0.0034
	render_priority = 10
	outline_render_priority = 9
	double_sided = true
	outline_modulate = Color("#120A16")
	_shadow = Label3D.new()
	_shadow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shadow.no_depth_test = true
	_shadow.pixel_size = pixel_size
	_shadow.render_priority = 8
	_shadow.outline_render_priority = 7
	_shadow.offset = Vector2(5, -6)
	_shadow.modulate = Color(0.0, 0.0, 0.02, 0.55)
	_shadow.outline_modulate = Color(0.0, 0.0, 0.02, 0.55)
	add_child(_shadow)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.pixel_size = pixel_size
	_tag.render_priority = 10
	_tag.outline_render_priority = 9
	_tag.outline_modulate = Color("#120A16")
	add_child(_tag)


func setup(kind: StringName, amount: float, num_font: Font, tag_font: Font) -> void:
	age = 0.0
	big = false
	pop = 0.4
	font = num_font
	_shadow.font = num_font
	_tag.font = tag_font
	var col: Color = COLORS.get(kind, COLORS[&"phys"])
	var n := int(round(absf(amount)))
	var tag := ""
	var fs := 84
	life = 0.9
	match kind:
		&"crit":
			text = str(n)
			fs = 124
			big = true
			pop = 0.6
			life = 1.15
			tag = "暴击"
		&"heal":
			text = "+%d" % n
			fs = 84
		&"miss":
			text = "MISS"
			fs = 68
			tag = "闪避"
		&"true":
			text = str(n)
			fs = 90
			tag = "真实"
		_:
			text = str(n)
	font_size = fs
	outline_size = maxi(10, fs / 6)
	modulate = col
	_shadow.text = text
	_shadow.font_size = fs
	_shadow.outline_size = outline_size
	_tag.visible = tag != ""
	_tag.text = tag
	_tag.font_size = int(fs * 0.36)
	_tag.outline_size = 8
	_tag.modulate = col.lerp(Color.WHITE, 0.25)
	_tag.offset = Vector2(0, fs * 0.62)
	vel = Vector3(randf_range(-0.5, 0.5), 2.2 if not big else 2.6, randf_range(-0.5, 0.5))
	_apply()


## Advances the number; false when it is done.
func step(delta: float) -> bool:
	age += delta
	if age >= life:
		return false
	global_position += vel * delta
	vel *= pow(0.04, delta)
	_apply()
	return true


func _apply() -> void:
	# 140% -> 100% in 6 frames (0.1 s), crits pop harder
	var k := clampf(age / 0.1, 0.0, 1.0)
	var s := 1.0 + pop * (1.0 - k * k)
	scale = Vector3.ONE * s
	var a := clampf((life - age) / (life * 0.4), 0.0, 1.0)
	modulate.a = a
	outline_modulate.a = a
	_shadow.modulate.a = a * 0.55
	_shadow.outline_modulate.a = a * 0.55
	_tag.modulate.a = a
	_tag.outline_modulate.a = a
