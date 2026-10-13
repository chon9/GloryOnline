extends Control
## Row of status badges for a status_mask (bit order = StatusSet.IDS). Debuffs first, then buffs.
## One Control, drawn in _draw; per-icon tooltips through _get_tooltip().

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

var icon_size: float = 22.0
var spacing: float = 3.0
var max_icons: int = 12
var mask: int = -1
var _bits: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = " "   # enables _get_tooltip


func set_mask(m: int) -> void:
	if m == mask:
		return
	mask = m
	_bits.clear()
	for pass_neg: bool in [true, false]:
		for bit in HudStyle.STATUS_INFO.size():
			if (m >> bit) & 1 and HudStyle.is_negative_bit(bit) == pass_neg:
				if _bits.size() < max_icons:
					_bits.append(bit)
	custom_minimum_size = Vector2(maxf(0.0, _bits.size() * (icon_size + spacing) - spacing), icon_size)
	queue_redraw()


func bits() -> PackedInt32Array:
	return _bits


func _draw() -> void:
	for i in _bits.size():
		var r := Rect2(Vector2(i * (icon_size + spacing), 0), Vector2(icon_size, icon_size))
		HudIcons.draw_status_icon(self, r, _bits[i])


func _get_tooltip(at_position: Vector2) -> String:
	var i := int(at_position.x / (icon_size + spacing))
	if i >= 0 and i < _bits.size():
		return HudStyle.status_tooltip(_bits[i])
	return ""
