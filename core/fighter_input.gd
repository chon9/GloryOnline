class_name FighterInput
extends RefCounted
## One frame of intent for a Fighter. Written by PlayerController (humans, via RPC) or a brain (bots).
## `pressed`, `jump` and `dodge` are EDGE inputs: the Fighter consumes and clears them every host tick.
## `sprint` is a HELD flag (Shift held while moving).

const JUMP_BIT: int = 1 << 15
## Packed into the "p" (edges) word of to_dict(), next to JUMP_BIT.
const DODGE_BIT: int = 1 << 16
## Packed into the "h" (held) word of to_dict(); skill slots use bits 0..14.
const SPRINT_BIT: int = 1 << 16

var move: Vector3 = Vector3.ZERO        # world-space XZ, length <= 1
var aim_point: Vector3 = Vector3.ZERO   # world-space point being aimed at (ZERO = none)
var aim_dir: Vector3 = Vector3.ZERO     # world-space aim direction (camera forward), optional
var jump: bool = false                  # edge
var dodge: bool = false                 # edge (Shift tapped)
var sprint: bool = false                # held (Shift held)
var pressed: int = 0                    # bitmask of skill slots pressed this frame (edge)
var held: int = 0                       # bitmask of skill slots currently held
var target_uid: int = 0                 # desired lock-on target (0 = none)
var press_id: int = 0                   # increments whenever a new edge is produced (dedup of resends)


func press(slot: int) -> void:
	if slot >= 0 and slot < 15:
		pressed |= 1 << slot


func is_pressed(slot: int) -> bool:
	return slot >= 0 and slot < 15 and (pressed & (1 << slot)) != 0


func is_held(slot: int) -> bool:
	return slot >= 0 and slot < 15 and (held & (1 << slot)) != 0


func clear_edges() -> void:
	pressed = 0
	jump = false
	dodge = false


func copy_from(o: FighterInput) -> void:
	move = o.move
	aim_point = o.aim_point
	aim_dir = o.aim_dir
	jump = o.jump
	dodge = o.dodge
	sprint = o.sprint
	pressed = o.pressed
	held = o.held
	target_uid = o.target_uid
	press_id = o.press_id


## Compact dictionary for the submit_input RPC.
func to_dict() -> Dictionary:
	var p := pressed
	if jump:
		p |= JUMP_BIT
	if dodge:
		p |= DODGE_BIT
	var h := held & ~SPRINT_BIT
	if sprint:
		h |= SPRINT_BIT
	return {
		"m": Vector2(move.x, move.z),
		"a": aim_point,
		"d": Vector2(aim_dir.x, aim_dir.z) if aim_dir.y == 0.0 else aim_dir,
		"p": p,
		"h": h,
		"t": target_uid,
		"i": press_id,
	}


## Robust decode: missing/garbage keys fall back to neutral values. Clamps move length.
static func from_dict(d: Variant) -> FighterInput:
	var inp := FighterInput.new()
	if not (d is Dictionary):
		return inp
	var m: Variant = d.get("m", Vector2.ZERO)
	if m is Vector2:
		inp.move = Vector3((m as Vector2).x, 0.0, (m as Vector2).y).limit_length(1.0)
	elif m is Vector3:
		inp.move = CoreUtil.flat(m).limit_length(1.0)
	inp.aim_point = CoreUtil.to_vec3(d.get("a", Vector3.ZERO))
	var ad: Variant = d.get("d", Vector3.ZERO)
	if ad is Vector2:
		inp.aim_dir = Vector3((ad as Vector2).x, 0.0, (ad as Vector2).y)
	elif ad is Vector3:
		inp.aim_dir = ad
	var p: Variant = d.get("p", 0)
	var pi: int = int(p) if (p is int or p is float) else 0
	inp.jump = (pi & JUMP_BIT) != 0
	inp.dodge = (pi & DODGE_BIT) != 0
	inp.pressed = pi & ~(JUMP_BIT | DODGE_BIT)
	var h: Variant = d.get("h", 0)
	var hi: int = int(h) if (h is int or h is float) else 0
	inp.sprint = (hi & SPRINT_BIT) != 0
	inp.held = hi & ~SPRINT_BIT
	var t: Variant = d.get("t", 0)
	inp.target_uid = int(t) if (t is int or t is float) else 0
	var i: Variant = d.get("i", 0)
	inp.press_id = int(i) if (i is int or i is float) else 0
	return inp
