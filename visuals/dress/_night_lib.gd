extends RefCounted
## Shared costume parts for the Fighter / Nightwalker dresses (grappler, brawler, assassin, ninja, thief):
## open-front lathe shells, hoods, face masks, cloth wraps, pouches, chains, straps, spikes.
## Helper file (leading "_"): skipped by the ClassDress directory scan. Everything is authored in character space
## at the rest pose (metres, +Y up, facing +Z, right hand at -X), like the dress files themselves.


## Material with the bible shadow rule (hue toward blue-violet) and a configurable rim.
static func mat(c: Color, rim := Color(1.0, 0.9, 0.75), rim_strength := 0.6) -> ShaderMaterial:
	return AnimeGear.toon(c, {"shade": AnimeGear.shade_for(c), "rim": rim, "rim_strength": rim_strength})


## Turns a lathe built with `arc` < TAU so that its gap is centred on `face` (radians; 0 = front +Z, PI/2 = the
## character's left +X) and wraps it so the attach transform can stay plain.
static func gap_to(m: MeshInstance3D, arc: float, face := 0.0) -> Node3D:
	# lathe angle t sits at (cos t, sin t) in (x, z); Basis(UP, r) maps t -> t - r. Front (+Z) is t = PI/2.
	var g := arc + (TAU - arc) * 0.5
	m.rotation.y = g - (PI * 0.5 - face)
	return ClassDress.wrap(m)


## Lathe shell with a gap (front by default) attached to `bone` at `center`.
static func shell(b: AnimeBody, bone: String, center: Vector3, prof: Array, m: Material, arc := TAU, sz := 0.85, face := 0.0, seg := 24) -> void:
	var mi := AnimeGear.mi(AnimeGear.lathe(prof, seg, 1.0, sz, arc), m)
	if arc < TAU - 0.001:
		b.attach(bone, gap_to(mi, arc, face), Transform3D(Basis(), center))
	else:
		b.attach(bone, mi, Transform3D(Basis(), center))


## Sleeve / cuff shell along a limb: radii profile over t (0 = `bone`, 1 = `to_bone`), like ClassDress.limb_guard
## but returns nothing and accepts an end extension beyond the joint.
static func sleeve(b: AnimeBody, bone: String, to_bone: String, prof: Array, m: Material, seg := 14) -> void:
	var p0 := b.bone_pos(bone)
	var p1 := b.bone_pos(to_bone)
	var L := p0.distance_to(p1)
	var out: Array = []
	for v: Vector2 in prof:
		out.append(Vector2(v.x, v.y * L))
	b.attach(bone, AnimeGear.mi(AnimeGear.lathe(out, seg), m), Transform3D(Basis(Quaternion(Vector3.UP, (p1 - p0).normalized())), p0))


## Thin wrap bands along a limb (bandages, cloth wraps): `n` slightly tilted rings between t0 and t1.
static func wraps(b: AnimeBody, bone: String, to_bone: String, r0: float, r1: float, t0: float, t1: float, n: int, m: Material, tilt := 0.22) -> void:
	var p0 := b.bone_pos(bone)
	var p1 := b.bone_pos(to_bone)
	var L := p0.distance_to(p1)
	var bs := Basis(Quaternion(Vector3.UP, (p1 - p0).normalized()))
	for i in n:
		var t := lerpf(t0, t1, (float(i) + 0.5) / n)
		var r := lerpf(r0, r1, (float(i) + 0.5) / n)
		var ring := AnimeGear.mi(AnimeGear.lathe([Vector2(r, -0.011), Vector2(r * 1.02, 0.011)], 12), m)
		b.attach(bone, ring, Transform3D(bs * Basis(Vector3.RIGHT, tilt * (1.0 if i % 2 == 0 else -1.0)), p0 + (p1 - p0) * t))


## Hood around the head: an open-front lathe dome (lining inside) with a swept-down point at the back.
## `size` scales the whole hood (1.0 fits a VRoid male head plus hair).
static func hood(b: AnimeBody, outer: Material, inner: Material, size := 1.0, tail := 0.12) -> void:
	var head := b.bone_pos("Head")
	var c := head + Vector3(0, 0.0, -0.012 * size)
	var s := size
	var prof := [Vector2(0.115 * s, -0.035 * s), Vector2(0.15 * s, 0.03 * s), Vector2(0.162 * s, 0.1 * s), Vector2(0.152 * s, 0.17 * s),
		Vector2(0.118 * s, 0.225 * s), Vector2(0.06 * s, 0.258 * s), Vector2(0.0, 0.266 * s)]
	var arc := TAU * 0.72
	shell(b, "Head", c, prof, outer, arc, 1.08, 0.0, 26)
	# inner lining slightly smaller (reads as the dark inside of the opening)
	var inner_prof: Array = []
	for v: Vector2 in prof:
		inner_prof.append(Vector2(v.x * 0.94, v.y * 0.97))
	shell(b, "Head", c, inner_prof, inner, arc + 0.25, 1.08, 0.0, 26)
	# swept back point (hood tail) reads in silhouette from behind / the side
	if tail > 0.0:
		var pts: Array = []
		var rr: Array = []
		for i in 7:
			var t := float(i) / 6.0
			pts.append(c + Vector3(0, (0.17 - t * 0.17 - t * t * 0.06) * s, (-0.1 - t * tail) * s))
			rr.append(lerpf(0.07, 0.006, pow(t, 0.8)) * s)
		b.attach("Head", AnimeGear.mi(AnimeGear.tube(pts, rr, 10), outer), Transform3D.IDENTITY)


## Lower-face mask (nose to neck), the cloth wraps round the front of the face only.
static func mask(b: AnimeBody, m: Material, size := 1.0, top := 0.065, front := 0.0) -> void:
	var head := b.bone_pos("Head")
	var s := size
	var c := head + Vector3(0, 0, 0.012 * s + front)
	var prof := [Vector2(0.07 * s, -0.07 * s), Vector2(0.078 * s, -0.02 * s), Vector2(0.085 * s, 0.02 * s), Vector2(0.088 * s, top * s)]
	var arc := TAU * 0.62
	# gap at the back (the mask is a front half-ring)
	var mi := AnimeGear.mi(AnimeGear.lathe(prof, 18, 1.0, 1.12, arc), m)
	b.attach("Head", gap_to(mi, arc, PI), Transform3D(Basis(), c))
	# nose bridge ridge so it doesn't read as a flat band
	var ridge := PackedVector2Array([Vector2(-0.03, -0.01), Vector2(0.03, -0.01), Vector2(0.0, 0.012)])
	b.attach("Head", AnimeGear.mi(AnimeGear.extrude(ridge, 0.012), m), Transform3D(Basis(), c + Vector3(0, (top - 0.008) * s, 0.098 * s)))


## Leather pouch (box + flap + brass stud) at a hip angle (`a` radians from front, + = character left).
static func pouch(b: AnimeBody, leather: Material, stud: Material, a: float, size := Vector3(0.065, 0.07, 0.04), y := -0.04, r := 0.17) -> void:
	var hips := b.bone_pos("Hips")
	var bs := Basis(Vector3.UP, a)
	var p := hips + Vector3(sin(a) * r, y, cos(a) * r * 0.82)
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(size), leather), Transform3D(bs, p))
	b.attach("Hips", AnimeGear.mi(AnimeGear.box(Vector3(size.x * 1.06, size.y * 0.42, size.z * 1.15)), leather), Transform3D(bs, p + Vector3(0, size.y * 0.32, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.sphere(0.009, 8), stud), Transform3D(bs, p + bs * Vector3(0, size.y * 0.12, size.z * 0.6)))


## Chain of small links along a polyline (lathe tori, alternating orientation).
static func chain(b: AnimeBody, bone: String, pts: Array, m: Material, link := 0.022) -> void:
	var ring := [Vector2(link * 0.5, -0.004), Vector2(link * 0.5 + 0.004, 0.0), Vector2(link * 0.5, 0.004), Vector2(link * 0.5 - 0.004, 0.0), Vector2(link * 0.5, -0.004)]
	var mesh := AnimeGear.lathe(ring, 8)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var L := a.distance_to(c)
		var n := maxi(1, int(L / (link * 0.85)))
		var d := (c - a).normalized()
		var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
		for k in n:
			var p := a.lerp(c, (float(k) + 0.5) / n)
			# torus axis (lathe +Y) perpendicular to the chain, alternating between two directions per link
			var ax := side if (k + i) % 2 == 0 else d.cross(side).normalized()
			b.attach(bone, AnimeGear.mi(mesh, m), Transform3D(Basis(d, ax, d.cross(ax).normalized()), p))


## Strap across the torso: ribbon through `pts` (character space) with the strap flat against the body.
static func strap(b: AnimeBody, bone: String, pts: Array, width: float, m: Material, thickness := 0.01) -> void:
	var w: Array = []
	var sides: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var d: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var outward := Vector3(p.x, 0, p.z).normalized() if Vector3(p.x, 0, p.z).length() > 0.01 else Vector3.BACK
		w.append(width)
		sides.append(d.cross(outward).normalized())
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(pts, w, sides, thickness), m), Transform3D.IDENTITY)


## Elliptic loop of points around the torso at height y (for straps that circle the body).
static func loop_pts(c: Vector3, rx: float, rz: float, a0: float, a1: float, n: int, dy := 0.0) -> Array:
	var out: Array = []
	for i in n:
		var t := float(i) / (n - 1)
		var a := lerpf(a0, a1, t)
		out.append(c + Vector3(sin(a) * rx, dy * t, cos(a) * rz))
	return out


## Swept spike / fin (pointed plate) - pauldron studs, knee points, elbow fins.
static func spike(len := 0.07, w := 0.022) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0), Vector2(w * 0.4, len * 0.55), Vector2(0.0, len), Vector2(-w * 0.2, len * 0.5)])


## Pointed knee / elbow guard plate on the front of a joint.
static func knee(b: AnimeBody, bone: String, m: Material, trim: Material, size := 1.0, fwd := 0.07) -> void:
	var kp := b.bone_pos(bone)
	var s := size
	var poly := PackedVector2Array([Vector2(-0.05 * s, -0.045 * s), Vector2(0.05 * s, -0.045 * s), Vector2(0.056 * s, 0.03 * s), Vector2(0.0, 0.115 * s), Vector2(-0.056 * s, 0.03 * s)])
	b.attach(bone, AnimeGear.mi(AnimeGear.extrude(poly, 0.02, 0.006), m), Transform3D(Basis(Vector3.RIGHT, -0.15), kp + Vector3(0, 0.02, fwd)))
	b.attach(bone, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.014 * s, 0.02 * s), 0.026), trim), Transform3D(Basis(), kp + Vector3(0, 0.025, fwd + 0.013)))


## Throwing star (n points) as a flat plate.
static func star(r: float, points := 4) -> PackedVector2Array:
	return AnimeGear.star_poly(r, points, 0.32)
