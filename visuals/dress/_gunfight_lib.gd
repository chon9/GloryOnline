extends RefCounted
## Shared costume parts for the Gunner / Fighter dresses (sharpshooter, spitfire, mechanic, striker, qi_master):
## front-open lathe shells, edge trims, mandarin collars, frog buttons, rope sashes, dress-side gauntlets with
## articulated knuckle plates, holsters, pouches, bandoliers. All positions are character space at the rest pose
## (metres, +Y up, facing +Z, right hand at -X). Helper file: skipped by the ClassDress directory scan.


static func arm(side: float) -> String:
	return "Right" if side < 0 else "Left"


## Lathe shell around a bone with an opening of `gap` (fraction of TAU) centred at the front (+Z).
## The ellipse squash (sx, sz) is applied after the opening is turned to the front.
static func shell(b: AnimeBody, bone: String, profile: Array, pos: Vector3, mat: Material, gap := 0.0, sx := 1.0, sz := 1.0, seg := 24) -> Node3D:
	var arc := TAU * (1.0 - gap)
	var m := AnimeGear.mi(AnimeGear.lathe(profile, seg, 1.0, 1.0, arc), mat)
	if gap > 0.0:
		m.rotation.y = PI * 0.5 + arc * 0.5
	var w := ClassDress.wrap(m)
	b.attach(bone, w, Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), pos))
	return w


## Strip running along one edge of a front-open shell (lapel trim). side -1 = character right edge.
static func shell_edge(b: AnimeBody, bone: String, profile: Array, pos: Vector3, gap: float, sx: float, sz: float, side: float, width: float, mat: Material, push := 0.006) -> void:
	var a := PI * 0.5 - side * gap * PI
	var pts: Array = []
	var ws: Array = []
	var ss: Array = []
	for p: Vector2 in profile:
		pts.append(pos + Vector3(cos(a) * (p.x + push) * sx, p.y, sin(a) * (p.x + push) * sz))
		ws.append(width)
		ss.append(Vector3(-sin(a) * sx, 0, cos(a) * sz))
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(pts, ws, ss, 0.008), mat), Transform3D.IDENTITY)


## Ring band (belts, hems, cuffs) as a thin lathe.
static func ring(b: AnimeBody, bone: String, pos: Vector3, r: float, h: float, mat: Material, sz := 0.82, seg := 24, gap := 0.0) -> void:
	shell(b, bone, [Vector2(r, -h * 0.5), Vector2(r * 1.01, h * 0.5)], pos, mat, gap, 1.0, sz, seg)


## Mandarin (stand-up) collar with a small front split and a trim rim.
static func mandarin_collar(b: AnimeBody, mat: Material, trim: Material, r := 0.075, h := 0.065, sz := 1.0) -> void:
	var neck := b.bone_pos("Neck")
	var prof := [Vector2(r + 0.012, -h * 0.55), Vector2(r + 0.004, 0.0), Vector2(r, h * 0.45)]
	shell(b, "Neck", prof, neck + Vector3(0, 0.0, 0.004), mat, 0.07, 1.0, sz, 20)
	shell(b, "Neck", [Vector2(r - 0.002, h * 0.42), Vector2(r - 0.002, h * 0.5)], neck + Vector3(0, 0.0, 0.004), trim, 0.07, 1.04, sz * 1.04, 20)


## Chinese frog button (盘扣): two looped cords and a knot, horizontal, on a surface facing `normal`.
static func frog(b: AnimeBody, bone: String, pos: Vector3, mat: Material, s := 1.0, normal := Vector3.BACK) -> void:
	var n := Node3D.new()
	for side: float in [-1.0, 1.0]:
		var loop := AnimeGear.mi(AnimeGear.sphere(0.012 * s, 8), mat, n)
		loop.scale = Vector3(1.9, 0.7, 0.55)
		loop.position = Vector3(side * 0.02 * s, 0, 0)
		var coil := AnimeGear.mi(AnimeGear.sphere(0.007 * s, 8), mat, n)
		coil.position = Vector3(side * 0.043 * s, 0, 0)
	AnimeGear.mi(AnimeGear.sphere(0.008 * s, 8), mat, n)
	var bs := Basis.looking_at(-normal, Vector3.UP) if absf(normal.dot(Vector3.UP)) < 0.95 else Basis()
	b.attach(bone, n, Transform3D(bs, pos))


## Twisted rope sash around the waist with a knot at `knot_side`, plus two hanging cloth tails with tassel flares.
static func rope_sash(b: AnimeBody, rope: Material, knot_side: float, rx := 0.165, rz := 0.14, dy := 0.03, tail_len := 0.55) -> void:
	var hips := b.bone_pos("Hips")
	var c := hips + Vector3(0, dy, 0.0)
	for strand in 2:
		var pts: Array = []
		for i in 49:
			var t := TAU * i / 48.0
			var tw := t * 9.0 + strand * PI
			pts.append(c + Vector3(cos(t) * (rx + cos(tw) * 0.007), sin(tw) * 0.009, sin(t) * (rz + cos(tw) * 0.007)))
		b.attach("Hips", AnimeGear.mi(AnimeGear.tube(pts, 0.011, 6), rope), Transform3D.IDENTITY)
	var kp := c + Vector3(knot_side * rx * 0.72, -0.005, rz * 0.72)
	var knot := AnimeGear.mi(AnimeGear.sphere(0.026, 10), rope)
	knot.scale = Vector3(1.3, 1.0, 0.8)
	b.attach("Hips", knot, Transform3D(Basis(), kp))
	for k in 2:
		var leg := "LeftUpperLeg" if knot_side > 0 else "RightUpperLeg"
		ClassDress.cloth(b, "Hips", Transform3D(Basis(), kp + Vector3(knot_side * 0.012 * (k * 2 - 1), -0.02, 0.012)), {
			"name": "RopeTail", "length": tail_len * (1.0 - k * 0.22), "segments": 7,
			"width": [0.026, 0.024, 0.024, 0.024, 0.03, 0.06, 0.075], "dir": Vector3(knot_side * 0.12, -1.0, 0.15),
			"side": Vector3(1, 0, 0), "material": rope, "thickness": 0.016, "stiffness": 0.05, "stiffness_tip": 0.01,
			"gravity": 9.0, "drag": 0.08, "colliders": [["Hips", 0.17, -0.04], [leg, 0.1, -0.15]]})


## Fighter / gunner gauntlet built on the arm bones (follows the curled fingers): flared bracer with a swept elbow
## fin, back-of-hand plate, knuckle bar with studs and one articulated plate per finger.
## opts: fin (bool), studs (bool), radii (bracer profile), plate_len, glow (Color or null), bracer (bool, default true),
## back (bool, default true: back-of-hand plate + knuckle bar). bracer/back false = articulated finger plates only
## (worn under a WeaponFactory fist weapon that supplies cuff and knuckles).
static func gauntlet(b: AnimeBody, side: float, plate: Material, trim: Material, opts := {}) -> void:
	var pre := arm(side)
	var la := pre + "LowerArm"
	var hd := pre + "Hand"
	var radii: Array = opts.get("radii", [0.06, 0.053, 0.048, 0.046])
	if opts.get("bracer", true):
		ClassDress.limb_guard(b, la, hd, radii, float(opts.get("t0", 0.3)), 1.0, plate, trim, 14)
	var e := b.bone_pos(la)
	var h := b.bone_pos(hd)
	var dir := (h - e).normalized()
	var up := Vector3.UP
	var across := dir.cross(up).normalized()
	# elbow cuff rim + swept fin pointing back toward the elbow
	if opts.get("fin", true):
		var fin := PackedVector2Array([Vector2(0.11, 0.0), Vector2(-0.03, 0.0), Vector2(-0.075, 0.045), Vector2(-0.035, 0.03), Vector2(0.02, 0.034)])
		var fb := Basis(dir, up, dir.cross(up))
		b.attach(la, AnimeGear.mi(AnimeGear.extrude(fin, 0.014, 0.003), trim), Transform3D(fb, e.lerp(h, 0.42) + up * 0.045))
	# back-of-hand plate (extrusion thickness along +Y)
	var hb := Basis(dir, up.cross(dir).normalized(), up)
	var hand_len := (b.bone_pos(pre + "MiddleProximal") - h).length()
	var back: bool = opts.get("back", true)
	if back:
		var pl := PackedVector2Array([Vector2(-0.015, -0.036), Vector2(hand_len * 0.92, -0.044), Vector2(hand_len * 1.1, 0.0), Vector2(hand_len * 0.92, 0.044), Vector2(-0.015, 0.036), Vector2(-0.03, 0.0)])
		b.attach(hd, AnimeGear.mi(AnimeGear.extrude(pl, 0.014, 0.003), plate), Transform3D(hb, h + up * 0.022 + across * 0.0))
		b.attach(hd, AnimeGear.mi(AnimeGear.extrude(ClassDress.diamond(0.022, 0.016), 0.02, 0.004), trim), Transform3D(hb, h + dir * hand_len * 0.45 + up * 0.03))
	# knuckle bar + studs
	var kn := h + dir * hand_len * 1.02 + up * 0.022
	if back:
		b.attach(hd, AnimeGear.mi(AnimeGear.box(Vector3(0.028, 0.096, 0.026)), trim), Transform3D(hb, kn))
	if back and opts.get("studs", true):
		for k in 4:
			var w := -0.036 + k * 0.024
			var stud := AnimeGear.mi(AnimeGear.cyl(0.001, 0.011, 0.026, 6), trim)
			b.attach(hd, stud, Transform3D(Basis(Quaternion(Vector3.UP, (up + dir * 0.6).normalized())), kn + hb.y * w + up * 0.02 + dir * 0.004))
	# one plate per finger (articulated: parented to the proximal / intermediate bones)
	for f: String in ["Index", "Middle", "Ring", "Little"]:
		var fp := pre + f + "Proximal"
		var fi := pre + f + "Intermediate"
		var p0 := b.bone_pos(fp)
		var p1 := b.bone_pos(fi)
		var fd := (p1 - p0)
		var fl := fd.length()
		var fbs := Basis(fd.normalized(), up.cross(fd.normalized()).normalized(), up)
		b.attach(fp, AnimeGear.mi(AnimeGear.box(Vector3(fl * 0.9, 0.02, 0.012)), plate), Transform3D(fbs, p0.lerp(p1, 0.55) + up * 0.014))
		var fd2 := b.bone_pos(pre + f + "Distal") - p1
		b.attach(fi, AnimeGear.mi(AnimeGear.box(Vector3(fd2.length() * 0.85, 0.018, 0.011)), plate), Transform3D(fbs, p1 + fd2 * 0.5 + up * 0.012))
	if opts.has("glow"):
		var g: Color = opts["glow"]
		b.attach(la, AnimeGear.mi(AnimeGear.box(Vector3(0.012, 0.012, 0.012)), AnimeGear.glow(g, 2.5)), Transform3D(Basis(), e.lerp(h, 0.75) + up * 0.05))
		var strip := AnimeGear.mi(AnimeGear.box(Vector3(0.12, 0.008, 0.012)), AnimeGear.glow(g, 2.2))
		b.attach(la, strip, Transform3D(Basis(dir, up, dir.cross(up)), e.lerp(h, 0.66) + up * 0.05))


## Leather holster on a thigh (right side -1) with a strap round the leg.
static func holster(b: AnimeBody, side: float, leather: Material, metal: Material) -> void:
	var ul := arm(side) + "UpperLeg"
	var ll := arm(side) + "LowerLeg"
	var p0 := b.bone_pos(ul)
	var p1 := b.bone_pos(ll)
	var mid := p0.lerp(p1, 0.38)
	b.attach(ul, AnimeGear.mi(AnimeGear.lathe([Vector2(0.088, -0.016), Vector2(0.09, 0.016)], 16), leather), Transform3D(Basis(), mid))
	var hol := AnimeGear.mi(AnimeGear.box(Vector3(0.05, 0.2, 0.09)), leather)
	b.attach(ul, hol, Transform3D(Basis(Vector3.FORWARD, side * -0.12), mid + Vector3(side * 0.095, -0.03, 0.0)))
	b.attach(ul, AnimeGear.mi(AnimeGear.box(Vector3(0.054, 0.022, 0.094)), metal), Transform3D(Basis(Vector3.FORWARD, side * -0.12), mid + Vector3(side * 0.098, 0.06, 0.0)))


## Small leather pouch (belts) at a hips-relative position, turned to face outward.
static func pouch(b: AnimeBody, bone: String, pos: Vector3, mat: Material, flap: Material, size := Vector3(0.06, 0.07, 0.04)) -> void:
	var yaw := atan2(pos.x - b.bone_pos("Hips").x, pos.z - b.bone_pos("Hips").z)
	var bs := Basis(Vector3.UP, yaw)
	b.attach(bone, AnimeGear.mi(AnimeGear.box(size), mat), Transform3D(bs, pos))
	b.attach(bone, AnimeGear.mi(AnimeGear.box(Vector3(size.x * 1.06, size.y * 0.45, size.z * 0.4)), flap), Transform3D(bs, pos + bs * Vector3(0, size.y * 0.3, size.z * 0.4)))


## Diagonal strap loop round the torso (bandolier) running over the `from_side` shoulder to the opposite hip.
## Returns [points, basis] so ammo can be placed along it (points in character space, front half = indices 1..n/2-1).
static func bandolier(b: AnimeBody, from_side: float, mat: Material, width := 0.045, rx := 0.25, rz := 0.14, tilt := 0.78, dy := -0.07) -> Array:
	var uc := b.bone_pos("UpperChest")
	var c := Vector3(0, uc.y + dy, 0.01)
	var rot := Basis(Vector3.BACK, from_side * tilt)
	var pts: Array = []
	var ws: Array = []
	var ss: Array = []
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + rot * Vector3(cos(a) * rx, 0.0, sin(a) * rz))
		ws.append(width)
		ss.append(rot * Vector3.UP)
	b.attach("UpperChest", AnimeGear.mi(AnimeGear.ribbon(pts, ws, ss, 0.012), mat), Transform3D.IDENTITY)
	return [pts, rot]


## Pushes the shoulders outward (fighter build, bible 2.1). Clips carry rotations only, so the pose offset survives.
static func broaden(b: AnimeBody, amount: float) -> void:
	var sk := b.skeleton
	for side: float in [-1.0, 1.0]:
		var i := sk.find_bone(arm(side) + "Shoulder")
		if i < 0:
			continue
		var par := sk.get_bone_parent(i)
		var pb := sk.get_bone_global_rest(par).basis if par >= 0 else Basis()
		sk.set_bone_pose_position(i, sk.get_bone_rest(i).origin + pb.inverse() * Vector3(side * amount, 0.0, 0.0))


## Hat brim: annular slab (r0..r1) whose sides curl up by `curl` and whose front/back dip by `dip` (gunslinger hat).
static func brim(r0: float, r1: float, curl: float, dip: float, thick := 0.012, seg := 36, sz := 1.12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 4
	var top: Array = []
	var bot: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var r := lerpf(r0, r1, t)
		var rt: Array = []
		var rb: Array = []
		for j in seg:
			var a := TAU * j / seg
			var c := cos(a)
			var s := sin(a)
			var y := (curl * c * c - dip * s * s) * t * t
			var p := Vector3(c * r, y, s * r * sz)
			rt.append(p + Vector3(0, thick * 0.5, 0))
			rb.append(p - Vector3(0, thick * 0.5, 0))
		top.append(rt)
		bot.append(rb)
	for i in rings:
		for j in seg:
			var j1 := (j + 1) % seg
			for v: Vector3 in [top[i][j], top[i + 1][j1], top[i + 1][j], top[i][j], top[i][j1], top[i + 1][j1]]:
				st.add_vertex(v)
			for v: Vector3 in [bot[i][j], bot[i + 1][j], bot[i + 1][j1], bot[i][j], bot[i + 1][j1], bot[i][j1]]:
				st.add_vertex(v)
	for j in seg:
		var j1 := (j + 1) % seg
		var a: Vector3 = top[rings][j]
		var b: Vector3 = top[rings][j1]
		var c2: Vector3 = bot[rings][j1]
		var d: Vector3 = bot[rings][j]
		for v: Vector3 in [a, c2, b, a, d, c2]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Chunky anime hair lock (extruded tapering blade), for bangs / sideburns poking out under hats and hoods.
static func lock(b: AnimeBody, pos: Vector3, mat: Material, length := 0.12, width := 0.035, curve := 0.02, yaw := 0.0, tilt := 0.0) -> void:
	var poly := PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0), Vector2(width * 0.3 + curve * 0.5, -length * 0.55), Vector2(curve, -length), Vector2(-width * 0.2 + curve * 0.4, -length * 0.5)])
	b.attach("Head", AnimeGear.mi(AnimeGear.extrude(poly, 0.016, 0.004), mat), Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), pos))
