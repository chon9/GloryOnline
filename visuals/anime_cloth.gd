class_name AnimeCloth
extends MeshInstance3D
## Runtime cloth strip for hero silhouettes (bible 2.3 / 2.4: scarves, capes and coat tails MUST move): a verlet
## chain hanging from its parent node (a BoneAttachment child), drawn as a thick toon slab with a curved cross
## section so it gets the same outline as the body.
##
## Cost model: the slab mesh is built ONCE and skinned to a private Skeleton3D with one bone per chain point; per
## frame the strip only writes `segments` bone poses (GPU skinning does the rest). The simulation runs at a fixed
## 60 Hz (frame-rate independent stiffness / damping / gravity) and is interpolated between steps for rendering.
## CharacterVisual turns it off (rigid rest shape, still drawn) beyond 25 m.
##
## Options (lengths in character-space metres, scaled by the anchor's global scale):
##   length, segments, width (float or Array sampled along the strip), thickness, dir (rest direction in anchor
##   space), side (width axis in anchor space), gravity, drag (velocity loss per 1/60 s step), stiffness (pull toward
##   the rest shape per step at the root, fading to stiffness_tip), root_stiff (extra pull on the first segments so
##   the top follows the body), hang (0..1: how much the rest shape bends from `dir` toward world-down along the
##   strip, so capes hang instead of sticking out with the hips in bent idles), bend (0..1 smoothing toward a
##   continuous curve), curl (cross-section bow as a fraction of the width, edges toward the body; default by width),
##   wind, material, lining (material of the inner face), lining_side (inner side in anchor space; default = toward
##   the hips), colliders: [[bone, radius, offset_y], ...]

const STEP := 1.0 / 60.0
const MAX_STEPS := 4
const ITERATIONS := 3

var opts: Dictionary
var active := true
var _pts := PackedVector3Array()     # simulated positions (current step)
var _prev := PackedVector3Array()    # verlet previous positions
var _last := PackedVector3Array()    # positions at the previous step (render interpolation)
var _rest := PackedVector3Array()
var _n := 12
var _seg := 0.1
var _time := 0.0
var _acc := 0.0
var _skel: Skeleton3D
var _hips := -1
var _colliders: Array = []    # [bone_idx, radius, offset]
var _col_pos: Array = []
var _ready_sim := false
var _rig: Skeleton3D
var _anchor_prev := Transform3D.IDENTITY
var _rest_far := Transform3D()      # anchor transform of the last rigid (far) update
# option cache
var _len := 1.2
var _dir := Vector3(0, -1, -0.15)
var _side := Vector3.RIGHT
var _g := 9.0
var _drag := 0.08
var _k0 := 0.12
var _k1 := 0.02
var _kroot := 0.25
var _hang := 0.55
var _bend := 0.25
var _wind := Vector3(0.6, 0, 0.3)
var _inner: Variant = null


func _init(o: Dictionary = {}) -> void:
	opts = o
	name = String(o.get("name", "Cloth"))
	_n = maxi(3, int(o.get("segments", 12)))
	_len = float(o.get("length", 1.2))
	_dir = (o.get("dir", Vector3(0, -1, -0.15)) as Vector3).normalized()
	_side = (o.get("side", Vector3.RIGHT) as Vector3).normalized()
	_g = float(o.get("gravity", 9.0))
	_drag = clampf(float(o.get("drag", 0.08)), 0.0, 0.9)
	_k0 = float(o.get("stiffness", 0.12))
	_k1 = float(o.get("stiffness_tip", 0.02))
	_kroot = float(o.get("root_stiff", 0.25))
	_hang = clampf(float(o.get("hang", 0.55)), 0.0, 1.0)
	_bend = clampf(float(o.get("bend", 0.25)), 0.0, 0.9)
	_wind = o.get("wind", Vector3(0.6, 0, 0.3))
	_inner = o.get("lining_side", null)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh = _build_mesh()
	var mat: Material = o.get("material", AnimeGear.toon(Color("#C8202A")))
	set_surface_override_material(0, mat)
	set_surface_override_material(1, o.get("lining", mat))


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var p := get_parent()
	while p != null and not (p is Skeleton3D):
		p = p.get_parent()
	_skel = p as Skeleton3D
	if _skel:
		_hips = _skel.find_bone("Hips")
		for c in opts.get("colliders", []):
			var bi := _skel.find_bone(String(c[0]))
			if bi >= 0:
				_colliders.append([bi, float(c[1]), float(c[2]) if (c as Array).size() > 2 else 0.0])
	_rig = Skeleton3D.new()
	_rig.name = "ClothRig"
	add_child(_rig)
	_rig.top_level = true
	_rig.global_transform = Transform3D.IDENTITY
	var sk := Skin.new()
	for i in _n:
		_rig.add_bone("p%d" % i)
		sk.add_bind(i, Transform3D.IDENTITY)
	skin = sk
	skeleton = get_path_to(_rig)
	reset()


func _anchor() -> Transform3D:
	return (get_parent() as Node3D).global_transform


func _width_at(t: float) -> float:
	var wv: Variant = opts.get("width", 0.18)
	return float(wv) if not (wv is Array) else _sample(wv as Array, t)


## Rest chain: starts along `dir` (anchor space) and bends toward world-down by `hang` along the strip.
func _rest_chain(a: Transform3D) -> void:
	var s := a.basis.get_scale().x
	_seg = _len * s / (_n - 1)
	var d0 := (a.basis * _dir).normalized()
	_rest.resize(_n)
	_rest[0] = a.origin
	for i in range(1, _n):
		var t := float(i) / (_n - 1)
		var d := d0.lerp(Vector3.DOWN, _hang * pow(t, 0.8)).normalized()
		_rest[i] = _rest[i - 1] + d * _seg


func reset() -> void:
	if not is_inside_tree():
		return
	var a := _anchor()
	_rest_chain(a)
	_pts = _rest.duplicate()
	_prev = _rest.duplicate()
	_last = _rest.duplicate()
	_anchor_prev = a
	_rest_far = a
	_acc = 0.0
	_ready_sim = true
	_pose(_pts, a)


## Simulates `seconds` at the current anchor pose immediately (screenshots of paused poses, spawn-in).
func settle(seconds := 1.5) -> void:
	if not _ready_sim:
		return
	var a := _anchor()
	_anchor_prev = a
	for _i in int(seconds / STEP):
		_step(a)
	_last = _pts.duplicate()
	_acc = 0.0
	_pose(_pts, a)


func _process(delta: float) -> void:
	if not _ready_sim or not is_visible_in_tree():
		return
	var a := _anchor()
	if not active:
		# far away: rigidly follow the anchor in the rest shape (no simulation)
		if not a.is_equal_approx(_rest_far):
			_rest_far = a
			_rest_chain(a)
			_pts = _rest.duplicate()
			_prev = _rest.duplicate()
			_last = _rest.duplicate()
			_pose(_pts, a)
		_anchor_prev = a
		return
	if a.origin.distance_to(_pts[0]) > 3.0:
		reset()
		return
	_acc += minf(delta, 0.1)
	var steps := int(_acc / STEP)
	if steps > 0:
		var k := mini(steps, MAX_STEPS)
		for j in k:
			_last = _pts.duplicate()
			_step(_anchor_prev.interpolate_with(a, float(j + 1) / k))
		_acc -= steps * STEP
		_anchor_prev = a
	# render between the last two steps; shift the strip so its root sits exactly on the anchor (fading to the tip)
	var alpha := clampf(_acc / STEP, 0.0, 1.0)
	var rp := PackedVector3Array()
	rp.resize(_n)
	for i in _n:
		rp[i] = _last[i].lerp(_pts[i], alpha)
	var fix := a.origin - rp[0]
	for i in _n:
		rp[i] += fix * (1.0 - float(i) / (_n - 1))
	_pose(rp, a)


func _step(a: Transform3D) -> void:
	_time += STEP
	var s := a.basis.get_scale().x
	_rest_chain(a)
	var g := _g * s
	var wind := _wind * s
	var gust := sin(_time * 1.7) * 0.6 + sin(_time * 3.1 + 1.3) * 0.4
	var sidev := (a.basis * _side).normalized()
	var dt2 := STEP * STEP
	_pts[0] = a.origin
	_prev[0] = a.origin
	for i in range(1, _n):
		var p := _pts[i]
		var v := (p - _prev[i]) * (1.0 - _drag)
		_prev[i] = p
		var t := float(i) / (_n - 1)
		var flutter := sidev * sin(_time * 7.0 - t * 6.0) * 0.25 * t * s
		p += v + (Vector3(0, -g, 0) + wind * gust + flutter) * dt2
		var k := lerpf(_k0, _k1, t) + _kroot * pow(1.0 - t, 4.0)
		p += (_rest[i] - p) * clampf(k, 0.0, 1.0)
		_pts[i] = p
	_update_colliders(s)
	for _it in ITERATIONS:
		for i in range(1, _n):
			var d := _pts[i] - _pts[i - 1]
			var L := d.length()
			if L > 1e-5:
				_pts[i] = _pts[i - 1] + d / L * _seg
		if _bend > 0.0:
			for i in range(1, _n - 1):
				var mid := (_pts[i - 1] + _pts[i + 1]) * 0.5
				_pts[i] += (mid - _pts[i]) * (_bend * 0.5)
		_collide()


func _update_colliders(s: float) -> void:
	_col_pos.resize(_colliders.size())
	if _skel == null:
		return
	var sx := _skel.global_transform
	for ci in _colliders.size():
		var c: Array = _colliders[ci]
		_col_pos[ci] = [sx * _skel.get_bone_global_pose(int(c[0])).origin + Vector3(0, float(c[2]) * s, 0), float(c[1]) * s]


func _collide() -> void:
	for cp: Array in _col_pos:
		var bp: Vector3 = cp[0]
		var r: float = cp[1]
		for i in range(1, _n):
			var d := _pts[i] - bp
			var L := d.length()
			if L < r and L > 1e-5:
				_pts[i] = bp + d / L * r


## Writes the bone frames: origin = chain point, X = width axis, Y = along the strip, Z = toward the body.
func _pose(pts: PackedVector3Array, a: Transform3D) -> void:
	if _rig == null:
		return
	var s := a.basis.get_scale().x
	var sidev := (a.basis * _side).normalized()
	var inner: Vector3
	if _inner != null:
		inner = (a.basis * (_inner as Vector3)).normalized()
	elif _skel and _hips >= 0:
		inner = (_skel.global_transform * _skel.get_bone_global_pose(_hips).origin) - a.origin
		inner.y = 0.0
		inner = inner.normalized() if inner.length() > 0.02 else (a.basis * Vector3.BACK).normalized()
	else:
		inner = (a.basis * Vector3.BACK).normalized()
	var last_y := Vector3.DOWN
	for i in _n:
		var y := pts[mini(i + 1, _n - 1)] - pts[maxi(i - 1, 0)]
		y = y.normalized() if y.length() > 1e-5 else last_y
		last_y = y
		var x := sidev - y * sidev.dot(y)
		x = x.normalized() if x.length() > 0.01 else y.cross(inner).normalized()
		var z := x.cross(y)
		if z.dot(inner) < 0.0:
			x = -x
			z = -z
		_rig.set_bone_pose(i, Transform3D(Basis(x * s, y * s, z * s), pts[i]))


## The slab, built once in bone-local frames: ring i is bound to bone i. Surface 0 = outer face + edges,
## surface 1 = inner face (lining). Cross section bows its edges toward the body (+Z) by `curl` * width.
func _build_mesh() -> ArrayMesh:
	var th := float(opts.get("thickness", 0.012))
	var wmax := 0.0
	for i in _n:
		wmax = maxf(wmax, _width_at(float(i) / (_n - 1)))
	var curl := float(opts.get("curl", 0.2 if wmax >= 0.25 else (0.14 if wmax >= 0.14 else (0.08 if wmax >= 0.08 else 0.0))))
	# vertical folds (ripples across the width, deepening toward the hem) so wide panels read as fabric
	var folds := int(opts.get("folds", roundi(wmax / 0.1) if wmax >= 0.2 else 0))
	var fold_d := float(opts.get("fold_depth", clampf(wmax * 0.07, 0.012, 0.035)))
	var cols := clampi(int(wmax / 0.04) + 2, 2, 7) if folds == 0 else folds * 4 + 1
	# plain Arrays while building (packed arrays are copy-on-write values in GDScript)
	var surf: Array = [[[], [], [], [], [], []], [[], [], [], [], [], []]]
	# per ring: outer[cols], inner[cols], rimL[2], rimR[2] -> indices into their surfaces
	var rings_o: Array = []
	var rings_i: Array = []
	var rims: Array = []
	for i in _n:
		var t := float(i) / (_n - 1)
		var w := _width_at(t)
		var ro: Array = []
		var ri: Array = []
		var ct := curl * lerpf(1.0, 0.5, t)
		var amp := fold_d * lerpf(0.25, 1.0, t) if folds > 0 else 0.0
		for j in cols:
			var u := lerpf(-1.0, 1.0, float(j) / (cols - 1))
			var ph := (u + 1.0) * folds * PI
			var bow := ct * w * u * u + amp * (0.5 - 0.5 * cos(ph))
			var slope := 4.0 * ct * u + (amp * 0.5 * sin(ph) * folds * PI * 2.0 / maxf(w, 0.01))
			ro.append(_vert(surf[0], Vector3(u * w * 0.5, 0.0, bow - th * 0.5), Vector3(slope, 0, -1).normalized(), Vector2(float(j) / (cols - 1), t), i))
			ri.append(_vert(surf[1], Vector3(u * w * 0.5, 0.0, bow + th * 0.5), Vector3(-slope, 0, 1).normalized(), Vector2(float(j) / (cols - 1), t), i))
		var edge := ct * w
		var rl := [_vert(surf[0], Vector3(-w * 0.5, 0, edge - th * 0.5), Vector3.LEFT, Vector2(0, t), i), _vert(surf[0], Vector3(-w * 0.5, 0, edge + th * 0.5), Vector3.LEFT, Vector2(0, t), i)]
		var rr := [_vert(surf[0], Vector3(w * 0.5, 0, edge - th * 0.5), Vector3.RIGHT, Vector2(1, t), i), _vert(surf[0], Vector3(w * 0.5, 0, edge + th * 0.5), Vector3.RIGHT, Vector2(1, t), i)]
		rings_o.append(ro)
		rings_i.append(ri)
		rims.append([rl, rr])
	for i in _n - 1:
		for j in cols - 1:
			_quad(surf[0], rings_o[i][j], rings_o[i][j + 1], rings_o[i + 1][j + 1], rings_o[i + 1][j], Vector3(0, 0, -1))
			_quad(surf[1], rings_i[i][j], rings_i[i][j + 1], rings_i[i + 1][j + 1], rings_i[i + 1][j], Vector3(0, 0, 1))
		_quad(surf[0], rims[i][0][0], rims[i][0][1], rims[i + 1][0][1], rims[i + 1][0][0], Vector3.LEFT)
		_quad(surf[0], rims[i][1][0], rims[i][1][1], rims[i + 1][1][1], rims[i + 1][1][0], Vector3.RIGHT)
	var m := ArrayMesh.new()
	for sd: Array in surf:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(sd[0])
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(sd[1])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(sd[2])
		arr[Mesh.ARRAY_BONES] = PackedInt32Array(sd[3])
		arr[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array(sd[4])
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array(sd[5])
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _vert(sd: Array, p: Vector3, n: Vector3, uv: Vector2, bone: int) -> int:
	(sd[0] as Array).append(p)
	(sd[1] as Array).append(n)
	(sd[2] as Array).append(uv)
	(sd[3] as Array).append_array([bone, 0, 0, 0])
	(sd[4] as Array).append_array([1.0, 0.0, 0.0, 0.0])
	return (sd[0] as Array).size() - 1


## Quad a-b-c-d (a-b on ring i, d-c on ring i + 1) wound so its front face looks along `out` (Godot: clockwise
## front faces, i.e. (b - a) x (c - a) points away from the viewer).
static func _quad(sd: Array, a: int, b: int, c: int, d: int, out: Vector3) -> void:
	var v: Array = sd[0]
	# every ring is authored at y = 0 of its own bone; ring i + 1 lies further along the bone +Y (down the strip)
	var pa: Vector3 = v[a]
	var pb: Vector3 = v[b]
	var pc: Vector3 = v[c] + Vector3(0, 1, 0)
	var cr := (pb - pa).cross(pc - pa)
	if cr.dot(out) < 0.0:
		(sd[5] as Array).append_array([a, b, c, a, c, d])
	else:
		(sd[5] as Array).append_array([a, c, b, a, d, c])


static func _sample(arr: Array, t: float) -> float:
	var f := t * (arr.size() - 1)
	var i := mini(int(f), arr.size() - 2)
	return lerpf(float(arr[i]), float(arr[i + 1]), f - i)
