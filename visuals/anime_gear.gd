class_name AnimeGear
extends RefCounted
## Procedural mesh + material helpers for anime costume pieces, weapons and props (ported from lookdev LdGear).
## Everything is authored in metres. Meshes are generated once and cached by key.
## Materials: every solid piece uses the toon shader + screen-space outline (same as the characters),
## so props in hand never look like a different art style.

const TOON := preload("res://visuals/shaders/toon.gdshader")
const OUTLINE := preload("res://visuals/shaders/toon_outline.gdshader")

static var _white: ImageTexture
static var _mats: Dictionary = {}
static var _spark: ImageTexture


static func white_tex() -> ImageTexture:
	if _white == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(im)
	return _white


## Shadow tint rule from the bible: hue shifts 10-20 deg toward blue/purple, saturation up, value down 30-45%.
static func shade_for(c: Color) -> Color:
	var h := c.h
	var target := 0.7  # blue-violet
	var dh := wrapf(target - h, -0.5, 0.5)
	var nh := wrapf(h + clampf(dh, -0.05, 0.05), 0.0, 1.0)
	var s := clampf(c.s * 1.15 + 0.08, 0.0, 1.0)
	var v := c.v * 0.62
	var sc := Color.from_hsv(nh, s, v)
	# express as multiplier tint (shadow = albedo * tint)
	return Color(clampf(sc.r / maxf(c.r, 0.02), 0.2, 1.0), clampf(sc.g / maxf(c.g, 0.02), 0.2, 1.0), clampf(sc.b / maxf(c.b, 0.02), 0.2, 1.0))


static func toon(col: Color, opts := {}) -> ShaderMaterial:
	var key := "t" + col.to_html() + str(opts)
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo_tex", opts.get("tex", white_tex()))
	m.set_shader_parameter("albedo_mul", col)
	m.set_shader_parameter("shade_tint", opts.get("shade", shade_for(col)))
	m.set_shader_parameter("rim_color", opts.get("rim", Color(1.0, 0.9, 0.75)))
	m.set_shader_parameter("rim_strength", opts.get("rim_strength", 0.6))
	m.set_shader_parameter("emission_col", opts.get("emit", Color.BLACK))
	m.set_shader_parameter("band_soft", opts.get("band_soft", 0.045))
	if opts.get("outline", true):
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("albedo_tex", white_tex())
		o.set_shader_parameter("albedo_mul", col)
		o.set_shader_parameter("width_px", opts.get("line", 1.6))
		o.set_shader_parameter("darken", opts.get("darken", 0.3))
		m.next_pass = o
	_mats[key] = m
	return m


static func glow(col: Color, energy := 3.0, additive := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "g%s%.2f%s%.2f" % [col.to_html(), energy, additive, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	if additive or alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_mats[key] = m
	return m


static func mi(mesh: Mesh, mat: Material, parent: Node3D = null, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.transform = xf
	if parent:
		parent.add_child(n)
	return n


# ---------------------------------------------------------------- mesh builders

## Surface of revolution around +Y. profile = [Vector2(radius, y), ...] bottom -> top.
static func lathe(profile: Array, seg := 16, sx := 1.0, sz := 1.0, arc := TAU) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for j in seg:
			var t0 := arc * j / seg
			var t1 := arc * (j + 1) / seg
			var p00 := Vector3(cos(t0) * a.x * sx, a.y, sin(t0) * a.x * sz)
			var p01 := Vector3(cos(t1) * a.x * sx, a.y, sin(t1) * a.x * sz)
			var p10 := Vector3(cos(t0) * b.x * sx, b.y, sin(t0) * b.x * sz)
			var p11 := Vector3(cos(t1) * b.x * sx, b.y, sin(t1) * b.x * sz)
			st.set_uv(Vector2(float(j) / seg, float(i) / profile.size()))
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p10)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p11)
	st.generate_normals()
	return st.commit()


## Flat polygon (x, y) extruded along Z by `depth`, centred on z = 0. Edge bevel via a slight inset on the faces.
static func extrude(poly: PackedVector2Array, depth: float, bevel := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	var face := poly
	if bevel > 0.0:
		var off := Geometry2D.offset_polygon(poly, -bevel)
		if off.size() > 0 and off[0].size() >= 3:
			face = _align_ring(off[0], poly)
			idx = Geometry2D.triangulate_polygon(face)
	if idx.is_empty():
		face = poly
		idx = Geometry2D.triangulate_polygon(poly)
	for side: float in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for k in range(0, idx.size(), 3):
			var order := [idx[k], idx[k + 1], idx[k + 2]] if side < 0 else [idx[k], idx[k + 2], idx[k + 1]]
			for o in order:
				var p: Vector2 = face[o]
				st.set_uv(p)
				st.add_vertex(Vector3(p.x, p.y, side * hz))
	# walls (with bevel: slanted from outer poly at z=0 to the inset faces)
	var n := poly.size()
	var ccw := _area(poly) > 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if bevel > 0.0 and face.size() == n:
			var fa := face[i]
			var fb := face[(i + 1) % n]
			for side: float in [1.0, -1.0]:
				var q := [Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(fb.x, fb.y, side * hz), Vector3(fa.x, fa.y, side * hz)]
				_quad(st, q, (side > 0) == ccw)
		else:
			var q := [Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3(b.x, b.y, hz), Vector3(a.x, a.y, hz)]
			_quad(st, q, ccw)
	st.generate_normals()
	return st.commit()


## offset_polygon may return the inset ring reversed and starting anywhere: match the outline's orientation and
## start vertex so bevel wall i joins poly[i] -> face[i] (otherwise the walls twist into bow-ties).
static func _align_ring(ring: PackedVector2Array, poly: PackedVector2Array) -> PackedVector2Array:
	if ring.size() != poly.size():
		return ring
	var r := ring
	if (_area(r) > 0.0) != (_area(poly) > 0.0):
		r.reverse()
	var best := 0
	var bd := INF
	for i in r.size():
		var d := r[i].distance_squared_to(poly[0])
		if d < bd:
			bd = d
			best = i
	var out := PackedVector2Array()
	for i in r.size():
		out.append(r[(best + i) % r.size()])
	return out


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _quad(st: SurfaceTool, q: Array, flip: bool) -> void:
	var order := [0, 1, 2, 0, 2, 3] if not flip else [0, 2, 1, 0, 3, 2]
	for o in order:
		st.set_uv(Vector2(o % 2, o / 2))
		st.add_vertex(q[o])


## Ribbon / panel along a polyline. pts: centre line, widths: per point, side: per point "width direction".
## thickness > 0 makes it a closed slab (no back-face problems for outlines).
static func ribbon(pts: Array, widths: Array, sides: Array, thickness := 0.012) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var L: Array = []
	var R: Array = []
	var nrm: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var s: Vector3 = (sides[i] as Vector3).normalized() * float(widths[i]) * 0.5
		var tng: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var nn := tng.cross(s).normalized()
		L.append(p - s)
		R.append(p + s)
		nrm.append(nn)
	var h := thickness * 0.5
	for i in n - 1:
		var v := float(i) / (n - 1)
		var v1 := float(i + 1) / (n - 1)
		for side: float in [1.0, -1.0]:
			var a: Vector3 = L[i] + nrm[i] * h * side
			var b: Vector3 = R[i] + nrm[i] * h * side
			var c: Vector3 = R[i + 1] + nrm[i + 1] * h * side
			var d: Vector3 = L[i + 1] + nrm[i + 1] * h * side
			var q := [a, b, c, d]
			var uvs := [Vector2(0, v), Vector2(1, v), Vector2(1, v1), Vector2(0, v1)]
			# Godot front faces are clockwise ((b - a) x (c - a) points away from the viewer)
			var order := [0, 2, 1, 0, 3, 2] if side < 0 else [0, 1, 2, 0, 2, 3]
			for o in order:
				st.set_uv(uvs[o])
				st.add_vertex(q[o])
		# rims
		for e: Array in [[L, -1.0], [R, 1.0]]:
			var arr: Array = e[0]
			var q2 := [arr[i] + nrm[i] * h, arr[i + 1] + nrm[i + 1] * h, arr[i + 1] - nrm[i + 1] * h, arr[i] - nrm[i] * h]
			var order2 := [0, 2, 1, 0, 3, 2] if e[1] > 0 else [0, 1, 2, 0, 2, 3]
			for o in order2:
				st.set_uv(Vector2(0.5, v))
				st.add_vertex(q2[o])
	st.generate_normals()
	return st.commit()


## Tube along a polyline (cables, fuses, rope). radius can be float or Array.
static func tube(pts: Array, radius: Variant, seg := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var rings: Array = []
	var up := Vector3.UP
	for i in n:
		var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if absf(t.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var bx := t.cross(up).normalized()
		var by := bx.cross(t).normalized()
		var r: float = radius[i] if radius is Array else radius
		var ring: Array = []
		for j in seg:
			var a := TAU * j / seg
			ring.append((pts[i] as Vector3) + (bx * cos(a) + by * sin(a)) * r)
		rings.append(ring)
	for i in n - 1:
		for j in seg:
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][(j + 1) % seg]
			var c: Vector3 = rings[i + 1][(j + 1) % seg]
			var d: Vector3 = rings[i + 1][j]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(r: float, seg := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func cyl(r_top: float, r_bot: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## Soft four-point sparkle sprite (star dust, glints).
static func spark_tex() -> ImageTexture:
	if _spark:
		return _spark
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var a := exp(-r * r * 9.0) + exp(-absf(u) * 22.0) * exp(-absf(v) * 3.0) * 0.6 + exp(-absf(v) * 22.0) * exp(-absf(u) * 3.0) * 0.6
			im.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	_spark = ImageTexture.create_from_image(im)
	return _spark


## n-pointed star outline (outer radius r, inner radius r * inner), first point up.
static func star_poly(r: float, points := 5, inner := 0.45) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in points * 2:
		var a := PI * 0.5 + PI * i / points
		var rr := r if i % 2 == 0 else r * inner
		p.append(Vector2(cos(a) * rr, sin(a) * rr))
	return p


## Gold trim / filigree material (bible: gold #D8B25A with #8A5A2B shadow).
static func gold(rim := Color("#FFE9A8")) -> ShaderMaterial:
	return toon(Color("#D8B25A"), {"shade": Color("#8A5A2B") / Color("#D8B25A"), "rim": rim})


## Polished blade steel with a bright white rim (bible 3.1 metal: stepped, white glint).
static func steel(col := Color("#D5DCE6")) -> ShaderMaterial:
	return toon(col, {"shade": Color("#7C88A0") / Color("#C9D3DE"), "rim": Color.WHITE, "rim_strength": 1.0})


## Mesh helper: extruded polygon placed with a transform.
static func plate(parent: Node3D, poly: PackedVector2Array, depth: float, mat: Material, xf := Transform3D.IDENTITY, bevel := 0.0) -> MeshInstance3D:
	return mi(extrude(poly, depth, bevel), mat, parent, xf)


## Transform of `n` relative to its ancestor `root` (works outside the scene tree).
static func rel_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Nodes named "Panel_*" or under a "Morph_*" node stay separate (animated umbrella form changes).
static func _keep_separate(n: Node, root: Node) -> bool:
	var p := n
	while p != null and p != root:
		var nm := String(p.name)
		if nm.begins_with("Panel_") or nm.begins_with("Morph_"):
			return true
		p = p.get_parent()
	return false


## Draw-call optimisation: merges every static MeshInstance3D under `root` (material_override set, no children,
## not an AnimeCloth) into one "Merged" mesh (one surface per material, casts shadows) plus one "MergedFx" mesh for
## transparent / additive materials (no shadows). Costume pieces and weapons are built from dozens of small
## primitives; merged, a character costs a few surfaces per bone instead of ~150 draw calls.
static func merge_static(root: Node3D) -> void:
	var groups: Dictionary = {}      # Material -> Array[[Mesh, Transform3D]]
	var order: Array = []
	var victims: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m is AnimeCloth or m.mesh == null or m.material_override == null or m.get_child_count() > 0:
			continue
		if _keep_separate(m, root):
			continue
		if not m.visible or m.mesh.get_surface_count() != 1:
			continue
		var mat := m.material_override
		if not groups.has(mat):
			groups[mat] = []
			order.append(mat)
		(groups[mat] as Array).append([m.mesh, rel_xf(m, root)])
		victims.append(m)
	if victims.size() < 2:
		return
	var solid := ArrayMesh.new()
	var fx := ArrayMesh.new()
	for mat in order:
		# manual merge (positions, normals, UVs, indices): SurfaceTool.append_from garbles meshes whose vertex
		# formats differ (PrimitiveMesh tangents vs SurfaceTool lathes)
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		for pair in groups[mat]:
			var arr := (pair[0] as Mesh).surface_get_arrays(0)
			var xf: Transform3D = pair[1]
			var nb := xf.basis.inverse().transposed()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: Variant = arr[Mesh.ARRAY_NORMAL]
			var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
			var ii: Variant = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
				norms.append((nb * (nn as PackedVector3Array)[k]).normalized() if nn is PackedVector3Array and (nn as PackedVector3Array).size() == v.size() else Vector3.UP)
				uvs.append((uv as PackedVector2Array)[k] if uv is PackedVector2Array and (uv as PackedVector2Array).size() == v.size() else Vector2.ZERO)
			if ii is PackedInt32Array and (ii as PackedInt32Array).size() > 0:
				for k in (ii as PackedInt32Array):
					idx.append(base + k)
			else:
				for k in v.size():
					idx.append(base + k)
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = norms
		out[Mesh.ARRAY_TEX_UV] = uvs
		out[Mesh.ARRAY_INDEX] = idx
		var transparent := mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		var target := fx if transparent else solid
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		target.surface_set_material(target.get_surface_count() - 1, mat)
	for v in victims:
		v.get_parent().remove_child(v)
		v.free()
	if solid.get_surface_count() > 0:
		var a := MeshInstance3D.new()
		a.name = "Merged"
		a.mesh = solid
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(a)
	if fx.get_surface_count() > 0:
		var b := MeshInstance3D.new()
		b.name = "MergedFx"
		b.mesh = fx
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b)
