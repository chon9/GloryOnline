extends Node3D
## Shared helpers for the berserker / spellblade / ghostblade / elementalist / summoner dresses
## (`const L := preload("res://visuals/dress/_swordmage_lib.gd")`). Skipped by the ClassDress scan ("_" prefix).
##
## As a node it is a tiny "floater": it spins around its local Y and bobs, carrying floating orbs, spirits and
## rune rings. Its mesh children get a "Keep" child so AnimeGear.merge_static leaves them alone (merged meshes
## would freeze in place).

var spin := 0.8
var bob := 0.025
var bob_speed := 2.0
var _t := 0.0
var _y0 := 0.0


func _ready() -> void:
	_y0 = position.y
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	rotation.y = wrapf(rotation.y + spin * delta, -PI, PI)
	position.y = _y0 + sin(_t * bob_speed) * bob


## New floater node (attach it with b.attach, then add pieces with `keep`).
static func floater(spin_speed := 0.8, bob_amp := 0.025, bob_hz := 2.0) -> Node3D:
	var f: Node3D = (load("res://visuals/dress/_swordmage_lib.gd") as GDScript).new()
	f.name = "Floater"
	f.set("spin", spin_speed)
	f.set("bob", bob_amp)
	f.set("bob_speed", bob_hz)
	return f


## Adds a mesh under a floater and protects it from the static merge.
static func keep(mesh: Mesh, mat: Material, parent: Node3D, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var m := AnimeGear.mi(mesh, mat, parent, xf)
	var k := Node3D.new()
	k.name = "Keep"
	m.add_child(k)
	return m


## A glowing orb: solid toon core + additive halo (+ optional orbiting chips of the same colour).
static func orb(parent: Node3D, pos: Vector3, col: Color, r := 0.045) -> void:
	keep(AnimeGear.sphere(r, 12), AnimeGear.toon(col.lightened(0.35), {"emit": col * 1.4, "outline": false, "rim": Color.WHITE}), parent, Transform3D(Basis(), pos))
	keep(AnimeGear.sphere(r * 2.1, 12), AnimeGear.glow(col, 1.6, true, 0.28), parent, Transform3D(Basis(), pos))


## Spiral bandage wrap from bone `bone` toward `to_bone` (t0..t1 along the bone), radius r, `turns` loops.
static func bandage(b: AnimeBody, bone: String, to_bone: String, r: float, turns: float, t0: float, t1: float, mat: Material, width := 0.035) -> void:
	var p0 := b.bone_pos(bone)
	var p1 := b.bone_pos(to_bone)
	var axis := (p1 - p0).normalized()
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	var pts: Array = []
	var ws: Array = []
	var ss: Array = []
	var n := int(turns * 14.0) + 2
	for i in n:
		var t := float(i) / (n - 1)
		var a := t * turns * TAU
		var c := p0.lerp(p1, lerpf(t0, t1, t))
		var rr := r * (1.0 + 0.06 * sin(a * 3.0))
		pts.append(c + (u * cos(a) + v * sin(a)) * rr)
		ws.append(width)
		ss.append(axis)
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(pts, ws, ss, 0.006), mat), Transform3D.IDENTITY)


## A hanging cord with a knot and a tassel (Chinese seasoning). `pos` is character space.
static func tassel(b: AnimeBody, bone: String, pos: Vector3, cord: Material, knot: Material, length := 0.22, sway := Vector3(0.0, 0.0, 0.03)) -> void:
	var pts: Array = []
	for i in 5:
		var t := float(i) / 4.0
		pts.append(pos + Vector3(0, -t * length * 0.55, 0) + sway * t)
	b.attach(bone, AnimeGear.mi(AnimeGear.tube(pts, 0.006, 6), cord), Transform3D.IDENTITY)
	var kp: Vector3 = pts[4]
	b.attach(bone, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.02, 0.026), 0.014, 0.003), knot), Transform3D(Basis(), kp))
	b.attach(bone, AnimeGear.mi(AnimeGear.lathe([Vector2(0.004, 0.0), Vector2(0.016, -0.03), Vector2(0.024, -length * 0.45), Vector2(0.0, -length * 0.47)], 8), cord), Transform3D(Basis(), kp + Vector3(0, -0.02, 0)))


## Open-front lathe shell (robe bells, coat skirts, mantles): profile in bone-local metres, `gap` = fraction of
## the circle left open, centred on the front (+Z).
static func open_shell(profile: Array, gap: float, seg := 28, sz := 0.88) -> Node3D:
	var arc := TAU * (1.0 - gap)
	var m := AnimeGear.mi(AnimeGear.lathe(profile, seg, 1.0, sz, arc), null)
	# lathe covers angles [0, arc] (x = cos, z = sin), so the gap is centred on -gap * PI; a Y rotation by r maps
	# angle a to a - r, so r = -PI / 2 - gap * PI centres the gap on +Z (the front)
	m.rotation.y = -PI * 0.5 - gap * PI
	return ClassDress.wrap(m)


static func shell(profile: Array, gap: float, mat: Material, seg := 28, sz := 0.88) -> Node3D:
	var w := open_shell(profile, gap, seg, sz)
	(w.get_child(0) as MeshInstance3D).material_override = mat
	return w


## Swept fin plate polygon (pointed, flared back): length l, height h.
static func fin(l: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(l * 0.25, h * 0.35), Vector2(l, h), Vector2(l * 0.55, h * 0.1), Vector2(l * 0.2, -h * 0.25)])


## Pointed shin plate (knee guard + greave front) polygon.
static func knee_plate(w := 0.05) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w, -0.04), Vector2(w, -0.04), Vector2(w * 1.1, 0.03), Vector2(0.0, 0.11), Vector2(-w * 1.1, 0.03)])
