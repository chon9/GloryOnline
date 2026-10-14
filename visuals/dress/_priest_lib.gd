extends RefCounted
## Shared costume helpers for the Knight / Priest family dresses (knight, cleric, paladin, exorcist) and the
## warlock. Helper file (leading "_"): skipped by the ClassDress directory scan.


## Lathe shell attached to `bone`, profile [Vector2(radius, y)] relative to `origin`. `arc` < TAU leaves an
## opening that is turned to face +Z (front) when `gap_front`, or -Z (back) otherwise.
static func shell(b: AnimeBody, bone: String, origin: Vector3, profile: Array, mat: Material, sz := 1.0, arc := TAU, gap_front := true, seg := 24) -> void:
	var m := AnimeGear.mi(AnimeGear.lathe(profile, seg, 1.0, sz, arc), mat)
	if arc < TAU:
		var gap := (TAU - arc) * 0.5
		# the lathe runs from +X toward +Z, the gap is centred at angle -gap; a node yaw of r moves angle a to
		# a - r, so r = -PI/2 - gap puts the gap at +Z (front) and r = PI/2 - gap at -Z (back)
		m.rotation.y = -PI * 0.5 - gap if gap_front else PI * 0.5 - gap
	b.attach(bone, ClassDress.wrap(m), Transform3D(Basis(), origin))


## Thin rim band (gold trim) at height y of a shell profile of radius r.
static func rim(b: AnimeBody, bone: String, origin: Vector3, r: float, y: float, mat: Material, sz := 1.0, arc := TAU, gap_front := true, h := 0.022) -> void:
	shell(b, bone, origin, [Vector2(r, y - h * 0.5), Vector2(r * 1.01, y + h * 0.5)], mat, sz, arc, gap_front)


## Hanging tabard / stole panel as a static ribbon: from `top` going down to `bottom_y`, width w0 -> w1,
## bulging forward by `bulge` (follows the thighs), `side` = width axis.
static func panel(b: AnimeBody, bone: String, top: Vector3, bottom_y: float, w0: float, w1: float, mat: Material, bulge := 0.04, out := Vector3(0, 0, 1), steps := 7, thick := 0.012) -> Array:
	var pts: Array = []
	var w: Array = []
	var sides: Array = []
	var side := Vector3.UP.cross(out).normalized()
	for i in steps:
		var t := float(i) / (steps - 1)
		var p := Vector3(top.x, lerpf(top.y, bottom_y, t), top.z) + out * (sin(t * PI * 0.8) * bulge + t * bulge * 0.6)
		pts.append(p)
		w.append(lerpf(w0, w1, t))
		sides.append(side)
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(pts, w, sides, thick), mat), Transform3D.IDENTITY)
	return pts


## Pointed hem trim under a panel built by `panel` (a gold V at the end).
static func panel_point(b: AnimeBody, bone: String, bottom: Vector3, w: float, mat: Material, out := Vector3(0, 0, 1), depth := 0.07) -> void:
	var poly := PackedVector2Array([Vector2(-w * 0.5, 0.02), Vector2(w * 0.5, 0.02), Vector2(w * 0.5, -0.005), Vector2(0, -depth), Vector2(-w * 0.5, -0.005)])
	var bs := Basis(Vector3.UP, atan2(out.x, out.z))
	b.attach(bone, AnimeGear.mi(AnimeGear.extrude(poly, 0.018, 0.003), mat), Transform3D(bs, bottom))


## Swept feather (wing piece): long pointed blade-like poly, length L.
static func feather(L: float, w: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -w * 0.4), Vector2(L * 0.35, -w * 0.5), Vector2(L * 0.8, -w * 0.25), Vector2(L, 0.0), Vector2(L * 0.75, w * 0.35), Vector2(L * 0.3, w * 0.5), Vector2(0, w * 0.4)])


## A small folded wing of `n` feathers fanning from a root, authored in the XY plane (x outward, y up).
static func wing(parent: Node3D, n: int, L: float, mat: Material, trim: Material, spread := 0.9, base_ang := 0.35, depth := 0.012) -> void:
	for k in n:
		var t := float(k) / maxf(1.0, n - 1)
		var a := base_ang + t * spread
		var l := L * lerpf(1.0, 0.55, t)
		var f := AnimeGear.mi(AnimeGear.extrude(feather(l, l * 0.22), depth, 0.003), mat if k % 2 == 0 else trim, parent)
		f.transform = Transform3D(Basis(Vector3.BACK, -a), Vector3(0, -t * L * 0.08, -k * 0.004))


## Paper talisman strip with red ink marks: a runtime cloth chain (they flutter) + returns nothing.
static func talisman(b: AnimeBody, bone: String, at: Vector3, length: float, paper: Material, dir := Vector3(0, -1, 0.1), w := 0.05) -> void:
	ClassDress.cloth(b, bone, Transform3D(Basis(), at), {
		"name": "Talisman", "length": length, "segments": 6, "width": [w, w, w * 0.95], "dir": dir,
		"side": Vector3(1, 0, 0) if absf(dir.x) < 0.7 else Vector3(0, 0, 1), "material": paper, "thickness": 0.004,
		"stiffness": 0.05, "stiffness_tip": 0.01, "gravity": 7.0, "drag": 0.08, "wind": Vector3(0.3, 0.0, -0.5),
		"colliders": [["Hips", 0.17, 0.0], ["RightUpperLeg", 0.1, -0.15], ["LeftUpperLeg", 0.1, -0.15]]})


## Diamond-shaped gem with an emissive glow.
static func gem(b: AnimeBody, bone: String, at: Vector3, col: Color, r := 0.016, energy := 1.0) -> void:
	b.attach(bone, AnimeGear.mi(AnimeGear.sphere(r, 10), AnimeGear.toon(col, {"emit": col * energy, "outline": false})), Transform3D(Basis(), at))


## Latin cross polygon (original proportions), centred on its crossing.
static func cross_poly(s: float) -> PackedVector2Array:
	var a := 0.018 * s
	return PackedVector2Array([Vector2(-a, -0.09 * s), Vector2(a, -0.09 * s), Vector2(a, -a), Vector2(0.055 * s, -a), Vector2(0.065 * s, 0.0),
		Vector2(0.055 * s, a), Vector2(a, a), Vector2(a, 0.06 * s), Vector2(0.0, 0.072 * s), Vector2(-a, 0.06 * s), Vector2(-a, a),
		Vector2(-0.055 * s, a), Vector2(-0.065 * s, 0.0), Vector2(-0.055 * s, -a), Vector2(-a, -a)])
