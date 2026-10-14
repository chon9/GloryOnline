extends Control
## Screen-space overlay for 3D things, drawn in one _draw per frame (no per-fighter nodes):
## overhead nameplates (name + hp bar, team colored, hidden for stealthed enemies), the lock-on reticle
## projected on the target, and the center crosshair.
##
## Nameplates (feelfix): anchored on the visual's head (CharacterVisual.get_head_position, at the interpolated
## render position) with a constant SCREEN offset, so plates sit on the head at any distance. Which plates show
## and whether they carry a name is decided at LAYOUT_HZ: allies, enemy players, the locked target, elites and
## engaged mobs get a full plate; idle mobs nearby get a compact bar, far idle mobs nothing. A greedy screen-space
## declutter (nearest / locked first, every frame) pushes overlapping plates up, then drops the name, then the
## plate, so text never draws over text. Plates closer than NEAR_HIDE to the camera, off screen or over the skill bar are hidden.
## HUD panels listed in `keep_out` (party / enemy frames, target frame, minimap) seed the declutter as occupied, so
## plates never draw under them. Only mobs and summons may fall back to a bare (nameless) bar; players and bots keep
## their name or lose the plate. A plate pushed off its owner gets a thin leader tick down to the head.

const HudStyle := preload("res://ui/hud_style.gd")
const HudIcons := preload("res://ui/hud_icons.gd")
const GD := preload("res://ui/glory_draw.gd")

const MAX_DIST: float = 45.0
const PLATE_W: float = 86.0
const PLATE_H: float = 7.0
const LAYOUT_HZ: float = 30.0
const NAME_DIST_MOB: float = 20.0      # idle mobs closer than this get a name
const BAR_DIST_MOB: float = 28.0       # idle mobs closer than this get a compact bar (else nothing)
const NEAR_HIDE: float = 3.0           # anchors closer to the camera than this get no plate
const HEAD_GAP_PX: float = 12.0        # screen gap between the head top and the bar
const BOTTOM_KEEP_PX: float = 150.0    # no plates over the bottom skill bar strip
const MAX_PUSH_PX: float = 64.0        # a plate never moves further than this from its owner
const MIN_ALPHA: float = 0.6
const LEADER_MIN_PX: float = 6.0       # pushed further than this -> draw a leader tick to the anchor

var world: World = null
var viewer: Fighter = null
var show_plates: bool = true
var show_crosshair: bool = true
## HUD panels plates must not draw under (set by Hud); invisible or empty ones are ignored.
var keep_out: Array[Control] = []
var _t: float = 0.0
var _lock_uid: int = 0
var _lock_anim: float = 0.0
var _layout_t: float = 0.0
## uid -> {want: wanted mode (refreshed at LAYOUT_HZ), mode: 0 hidden | 1 bar | 2 full after declutter, push: px up}
var _layout: Dictionary = {}
var _last_plates: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_layout_t -= delta
	_lock_anim = minf(1.0, _lock_anim + delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if world != null and is_instance_valid(world) and cam != null:
		if show_plates:
			_draw_plates(cam)
		_draw_reticle(cam)
	if show_crosshair:
		_draw_crosshair()


func _visible_to_viewer(f: Fighter) -> bool:
	if not f.is_stealthed:
		return true
	return viewer != null and is_instance_valid(viewer) and viewer.team == f.team


## Rendered (interpolated) world position of a fighter's origin.
static func render_pos(f: Fighter) -> Vector3:
	return f.get_global_transform_interpolated().origin


## Nameplate anchor: the top of the visual's head at the rendered position.
static func plate_anchor(f: Fighter) -> Vector3:
	var base := f.global_position
	var head := base + Vector3(0.0, f.height(), 0.0)
	if f.visual != null and is_instance_valid(f.visual) and f.visual.has_method(&"get_head_position"):
		var hv: Variant = f.visual.call(&"get_head_position")
		if hv is Vector3:
			head = hv
	return render_pos(f) + (head - base)


func _is_enemy(f: Fighter) -> bool:
	return viewer != null and is_instance_valid(viewer) and f.team != viewer.team


static func _engaged(f: Fighter) -> bool:
	return not f.threat.is_empty() or f.target_uid != 0 or f.hp < f.max_hp - 0.5


## 0 = no plate, 1 = compact bar, 2 = full plate (name + bar).
func _plate_mode(f: Fighter, dist: float, lock: Fighter) -> int:
	if f == lock:
		return 2
	if not _is_enemy(f):
		return 2
	if f.kind != "mob" and f.kind != "summon":
		return 2   # enemy players / bots: always named
	var elite := str(f.mob_def.get("role", "")) == "elite" if f.kind == "mob" else false
	var engaged := _engaged(f)
	if f.kind == "summon":
		return 2 if dist < 18.0 else (1 if engaged else 0)
	if elite and (engaged or dist < BAR_DIST_MOB):
		return 2
	if engaged:
		return 2 if dist < 35.0 else 1
	if dist < NAME_DIST_MOB:
		return 2
	if dist < BAR_DIST_MOB:
		return 1
	return 0


## Per-plate geometry at the anchor's screen point (bar bottom at sp.y - HEAD_GAP_PX).
func _plate_geo(f: Fighter, sp: Vector2, dist: float, mode: int, font: Font) -> Dictionary:
	var summon := f.kind == "summon"
	var k := clampf(18.0 / maxf(dist, 0.1), 0.72, 1.0)
	var w := PLATE_W * k * (0.7 if summon else 1.0) * (0.6 if mode == 1 else 1.0)
	var h := maxf(PLATE_H * k * (0.8 if summon else 1.0) * (0.75 if mode == 1 else 1.0), 4.0)
	var fs := int(round(clampf(14.0 * k, 11.0, 14.0))) if not summon else 11
	var bar := Rect2(Vector2(sp.x - w * 0.5, sp.y - HEAD_GAP_PX - h), Vector2(w, h))
	var rect := bar.grow_individual(4, 1, 0, 1)
	var tw := 0.0
	if mode == 2:
		tw = font.get_string_size(f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var emb := 22.0 if f.kit != null and not summon else 0.0
		var name_r := Rect2(Vector2(sp.x - tw * 0.5 - emb, bar.position.y - fs - 7.0), Vector2(tw + emb, fs + 6.0))
		rect = rect.merge(name_r)
	return {"bar": bar, "rect": rect, "fs": fs, "tw": tw, "w": w, "h": h}


func _candidates(cam: Camera3D, font: Font, lock: Fighter, full_layout: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cam_pos := cam.global_position
	for f: Fighter in world.fighters:
		if not is_instance_valid(f) or f == viewer or not f.is_inside_tree():
			continue
		if not f.is_alive() or f.kind == "boss":
			continue
		if not _visible_to_viewer(f):
			continue
		var head := plate_anchor(f)
		var dist := cam_pos.distance_to(head)
		if dist > MAX_DIST or dist < NEAR_HIDE or cam.is_position_behind(head):
			continue
		var sp := cam.unproject_position(head)
		if sp.x < -40.0 or sp.y < 30.0 or sp.x > size.x + 40.0 or sp.y > size.y - BOTTOM_KEEP_PX:
			continue
		# characters dithered out by the near-camera fade (CharacterVisual.near_fade) lose their plate too
		var nf: Variant = f.visual.get(&"near_fade") if f.visual != null and is_instance_valid(f.visual) else null
		if nf is float and float(nf) < 0.5:
			continue
		var mode: int
		if full_layout or not _layout.has(f.uid):
			mode = _plate_mode(f, dist, lock)
		else:
			mode = int((_layout[f.uid] as Dictionary)["want"])
		if mode == 0:
			continue
		out.append({"f": f, "sp": sp, "dist": dist, "want": mode, "lock": f == lock})
	return out


## Greedy declutter, nearest (and the locked target) first: push a plate up above whatever it hits; after 3
## pushes or MAX_PUSH_PX drop its name; if even the bar collides it is hidden this layout tick.
func _relayout(cands: Array[Dictionary], font: Font) -> void:
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["lock"] != b["lock"]:
			return a["lock"]
		return float(a["dist"]) < float(b["dist"]))
	var placed: Array[Rect2] = keep_out_rects()
	var seen: Dictionary = {}
	for c: Dictionary in cands:
		var f: Fighter = c["f"]
		var mode: int = c["want"]
		var push := 0.0
		var ok := false
		while mode > 0 and not ok:
			var geo := _plate_geo(f, c["sp"], c["dist"], mode, font)
			var r: Rect2 = geo["rect"]
			push = 0.0
			for i in 4:
				var hit: Variant = _first_hit(r.grow(1.0), placed)
				if hit == null:
					ok = true
					break
				var hr: Rect2 = hit
				var d := r.end.y - hr.position.y + 2.0
				push += d
				r.position.y -= d
				if push > MAX_PUSH_PX:
					break
			if ok:
				placed.append(r)
			elif c["lock"]:
				ok = true   # the locked target is always drawn
			elif mode == 2 and f.kind != "mob" and f.kind != "summon":
				mode = 0    # players / bots never show a nameless bar: whose bar it is matters
			else:
				mode -= 1
		seen[f.uid] = true
		_layout[f.uid] = {"want": c["want"], "mode": mode if ok else 0, "push": push}
	for uid: int in _layout.keys():
		if not seen.has(uid):
			_layout.erase(uid)


## Overlay-local rects of the visible keep-out panels.
func keep_out_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var origin := get_global_rect().position
	for c: Control in keep_out:
		if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		r.position -= origin
		out.append(r.grow(2.0))
	return out


static func _first_hit(r: Rect2, placed: Array[Rect2]) -> Variant:
	for p: Rect2 in placed:
		if r.intersects(p):
			return p
	return null


func _draw_plates(cam: Camera3D) -> void:
	var font := HudStyle.font(true)
	var lock := viewer.get_target() if viewer != null and is_instance_valid(viewer) else null
	var full := _layout_t <= 0.0
	if full:
		_layout_t = 1.0 / LAYOUT_HZ
	var cands := _candidates(cam, font, lock, full)
	_relayout(cands, font)
	_last_plates.clear()
	# far to near so nearer plates draw on top
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) > float(b["dist"]))
	# leaders first (under every plate), then the plates
	for pass_i in 2:
		for c: Dictionary in cands:
			var f: Fighter = c["f"]
			var lay: Dictionary = _layout.get(f.uid, {})
			var mode := int(lay.get("mode", 0))
			if mode == 0:
				continue
			var push := float(lay.get("push", 0.0))
			var sp: Vector2 = c["sp"] - Vector2(0.0, push)
			if pass_i == 0:
				if push > LEADER_MIN_PX:
					_draw_leader(c["sp"], sp, c["dist"], mode, f, font)
			else:
				_draw_one(f, sp, c["dist"], mode, f == lock, font)


## Thin leader from a pushed plate's bar down to its owner's head, ending in a small diamond tick.
func _draw_leader(anchor: Vector2, sp: Vector2, dist: float, mode: int, f: Fighter, font: Font) -> void:
	var geo := _plate_geo(f, sp, dist, mode, font)
	var bar: Rect2 = geo["bar"]
	var from := Vector2(sp.x, bar.end.y + 2.0)
	var to := Vector2(anchor.x, anchor.y - 3.0)
	if to.y - from.y < 3.0:
		return
	var col := HudStyle.C_ENEMY if _is_enemy(f) else HudStyle.C_ALLY
	var a := clampf(1.0 - (dist - 25.0) / (MAX_DIST - 25.0), MIN_ALPHA, 1.0) * 0.8
	draw_line(from, to, Color(0, 0, 0, 0.6 * a), 3.0)
	draw_line(from, to, Color(col.r, col.g, col.b, a), 1.0)
	var d := 3.0
	draw_colored_polygon(PackedVector2Array([to + Vector2(0, -d), to + Vector2(d, 0), to + Vector2(0, d), to + Vector2(-d, 0)]),
		Color(col.r, col.g, col.b, a))


func _draw_one(f: Fighter, sp: Vector2, dist: float, mode: int, is_lock: bool, font: Font) -> void:
	var enemy := _is_enemy(f)
	var col := HudStyle.C_ENEMY if enemy else HudStyle.C_ALLY
	var fade := clampf(1.0 - (dist - 25.0) / (MAX_DIST - 25.0), MIN_ALPHA, 1.0)
	var alpha := fade * (0.45 if f.is_stealthed else 1.0)
	var summon := f.kind == "summon"
	var geo := _plate_geo(f, sp, dist, mode, font)
	var bar: Rect2 = geo["bar"]
	_last_plates.append({"name": f.display_name, "rect": geo["rect"], "show_name": mode == 2, "kind": f.kind})
	if mode == 2:
		var nm := f.display_name
		var fs: int = geo["fs"]
		var tw: float = geo["tw"]
		var np := Vector2(sp.x - tw * 0.5, bar.position.y - 5.0)
		var name_col := col.lerp(Color.WHITE, 0.25 if enemy else 0.5)
		if is_lock:
			name_col = Color(1, 0.9, 0.5)
		draw_string_outline(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9 * minf(1.0, alpha + 0.2)))
		draw_string(font, np, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(name_col.r, name_col.g, name_col.b, alpha))
		# class emblem left of the name
		if f.kit != null and not summon:
			var es := float(fs) + 4.0
			var er := Rect2(Vector2(np.x - es - 4.0, np.y - es + 3.0), Vector2(es, es))
			HudIcons.draw_class_emblem(self, er, f.class_id, HudStyle.class_glyph(f), HudStyle.class_color(f))
	# slanted hp bar (team colour fill, gold frame when locked)
	var frac := clampf(f.hp / maxf(f.max_hp, 1.0), 0.0, 1.0)
	var sf := clampf(f.shield_hp / maxf(f.max_hp, 1.0), 0.0, 1.0)
	var fill_c := HudStyle.C_HP if enemy else HudStyle.C_HP_ALLY
	var frame_c := Color(1, 0.85, 0.35, alpha) if is_lock else Color(0, 0, 0, 0.85 * alpha)
	GD.bar(get_canvas_item(), bar.grow_individual(4, 1, 0, 1), frac, frac, Color(fill_c, alpha), Color(0, 0, 0, 0), frame_c, 0, sf)
	# status hint: a few dots for active debuffs/buffs (full icons live in the frames)
	if mode == 2 and f.status_mask != 0 and dist < 25.0:
		var n := 0
		for bit in HudStyle.STATUS_INFO.size():
			if (f.status_mask >> bit) & 1:
				var r := Rect2(bar.position + Vector2(n * 15.0, bar.size.y + 4.0), Vector2(14, 14))
				HudIcons.draw_status_icon(self, r, bit)
				n += 1
				if n >= 6:
					break


## Plates drawn last frame: [{name, rect (Rect2, viewport px), show_name}] (tests / diagnostics).
func debug_plates() -> Array[Dictionary]:
	return _last_plates.duplicate()


func _draw_reticle(cam: Camera3D) -> void:
	if viewer == null or not is_instance_valid(viewer):
		return
	var t := viewer.get_target()
	if t == null or not _visible_to_viewer(t):
		_lock_uid = 0
		return
	if t.uid != _lock_uid:
		_lock_uid = t.uid
		_lock_anim = 0.0
	var p := t.center() - t.global_position + render_pos(t)
	if cam.is_position_behind(p):
		return
	var sp := cam.unproject_position(p)
	var dist := cam.global_position.distance_to(p)
	var base_r := clampf(900.0 / maxf(dist, 1.0), 26.0, 90.0) * t.body_scale
	var r := base_r * (1.0 + (1.0 - _lock_anim) * 1.2)
	var a := 0.55 + 0.45 * _lock_anim
	var col := HudStyle.C_ENEMY if t.team != viewer.team else HudStyle.C_ALLY
	var gold := Color(1, 0.85, 0.35, a)
	var rot := _t * 1.2
	for i in 4:
		var ang := rot + i * PI * 0.5
		draw_arc(sp, r, ang - 0.38, ang + 0.38, 12, gold, 2.5, true)
		var tip := sp + Vector2(cos(ang), sin(ang)) * (r + 2.0)
		var inward := Vector2(cos(ang), sin(ang))
		var side := Vector2(-inward.y, inward.x)
		draw_colored_polygon(PackedVector2Array([tip - inward * 9.0, tip + side * 5.0, tip - side * 5.0]),
			Color(col.r, col.g, col.b, a))
	draw_arc(sp, r * 0.55, 0, TAU, 32, Color(1, 1, 1, 0.25 * a), 1.0, true)


func _draw_crosshair() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.85)
	var sh := Color(0, 0, 0, 0.6)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 5.0, c + d * 13.0, sh, 4.0)
		draw_line(c + d * 5.0, c + d * 13.0, col, 2.0)
	draw_circle(c, 2.5, sh)
	draw_circle(c, 1.5, col)
