extends Node
## Fx autoload (owner: ASSETS) - cosmetic VFX/SFX spawning, network-replicated (ARCHITECTURE §7.3).
##
## Networking: when this peer is the host of a real (non-offline) multiplayer session, every public call
## is broadcast with @rpc("authority", "call_local") so all peers play it. Offline / no peer / client-side
## calls just play locally. Nothing here touches gameplay state.
##
## Conventions
## - Positions are global. `dir` / `yaw` follow Godot: forward = -Z rotated by yaw about +Y.
## - Area "line" shapes start at `pos` and extend `length` metres forward along `yaw`, `width` wide.
## - Colour Color.WHITE means "use the effect's default colour".
## - Effects are CPUParticles3D + unshaded additive meshes using Kenney particle textures; every node
##   frees itself. A soft budget (MAX_LIVE_NODES) drops cosmetic extras when the scene is crowded.

## CORE checks this to decide whether to draw its own debug meshes.
var is_stub: bool = false

const TEX_DIR := "res://assets/vfx/"
const SFX_DIR := "res://assets/sfx/"
const MAX_LIVE_NODES := 260
const MAX_VOICES := 24

const EFFECT_NAMES: Array[StringName] = [&"hit_spark", &"hit_heavy", &"slash_arc", &"launch_burst", &"land_dust", &"cast_glow",
	&"heal_burst", &"buff_aura", &"debuff_puff", &"explosion", &"ice_burst", &"lightning_strike", &"fire_burst", &"holy_burst",
	&"dark_burst", &"poison_cloud", &"smoke", &"blink", &"dash_trail", &"summon_circle", &"block_spark", &"death", &"ultimate_flash"]
const PROJECTILE_VISUALS: Array[String] = ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi",
	"dragon", "lightning", "cannonball", "flask", "scythe"]
const AREA_VISUALS: Array[String] = ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]

const AREA_COLORS: Dictionary = {
	"fire": Color(1.0, 0.45, 0.1), "ice": Color(0.5, 0.85, 1.0), "lightning": Color(0.6, 0.7, 1.0), "holy": Color(1.0, 0.88, 0.45),
	"dark": Color(0.6, 0.2, 0.95), "poison": Color(0.45, 0.95, 0.2), "wind": Color(0.7, 1.0, 0.85), "earth": Color(0.75, 0.55, 0.3),
	"blood": Color(0.95, 0.08, 0.12), "rune": Color(0.6, 0.45, 1.0), "thorn": Color(0.4, 0.8, 0.2),
}
const PROJ_COLORS: Dictionary = {
	"orb": Color(0.55, 0.6, 1.0), "bullet": Color(1.0, 0.85, 0.4), "arrow": Color(0.9, 0.9, 0.8), "grenade": Color(1.0, 0.6, 0.2),
	"shuriken": Color(0.8, 0.85, 1.0), "wave": Color(0.6, 0.85, 1.0), "missile": Color(1.0, 0.55, 0.15), "star": Color(1.0, 0.9, 0.3),
	"blood": Color(0.9, 0.05, 0.1), "qi": Color(0.5, 0.85, 1.0), "dragon": Color(1.0, 0.5, 0.15), "lightning": Color(0.6, 0.75, 1.0),
	"cannonball": Color(1.0, 0.5, 0.1), "flask": Color(0.45, 1.0, 0.4), "scythe": Color(0.7, 0.4, 1.0),
}
const NUMBER_COLORS: Dictionary = {
	&"phys": Color(1.0, 0.96, 0.88), &"magic": Color(0.75, 0.6, 1.0), &"crit": Color(1.0, 0.82, 0.1),
	&"heal": Color(0.4, 1.0, 0.45), &"miss": Color(0.75, 0.75, 0.75), &"true": Color(1.0, 0.35, 0.3),
}

## sfx name -> candidate files (one is picked at random). Unknown names fall back to "hit".
const SFX_MAP: Dictionary = {
	&"hit": ["impactPunch_medium_000.ogg", "impactPunch_medium_001.ogg", "impactPunch_medium_002.ogg"],
	&"hit_heavy": ["impactPunch_heavy_000.ogg", "impactPunch_heavy_001.ogg", "impactPunch_heavy_002.ogg"],
	&"slash": ["knifeSlice.ogg", "knifeSlice2.ogg", "drawKnife1.ogg"],
	&"swing": ["synth_whoosh.wav", "cloth1.ogg"],
	&"magic": ["synth_magic.wav"],
	&"cast": ["synth_magic.wav"],
	&"explosion": ["synth_explosion.wav"],
	&"shot": ["synth_shot.wav"],
	&"cannon": ["synth_cannon.wav"],
	&"heal": ["synth_heal.wav"],
	&"buff": ["synth_buff.wav"],
	&"debuff": ["synth_debuff.wav"],
	&"block": ["impactMetal_medium_000.ogg", "impactPlate_medium_000.ogg"],
	&"metal": ["impactMetal_heavy_000.ogg", "impactMetal_heavy_001.ogg"],
	&"footstep": ["footstep00.ogg", "footstep01.ogg", "footstep02.ogg", "footstep03.ogg"],
	&"death": ["impactSoft_heavy_000.ogg"],
	&"ui_click": ["synth_ui_click.wav"],
	&"lightning": ["synth_lightning.wav"],
	&"ice": ["synth_ice.wav", "impactGlass_light_000.ogg"],
	&"glass": ["impactGlass_heavy_000.ogg", "impactGlass_medium_000.ogg"],
	&"ultimate": ["synth_ultimate.wav"],
	&"dash": ["synth_whoosh.wav"],
	&"jump": ["cloth3.ogg"],
	&"land": ["impactSoft_medium_000.ogg"],
	&"throw": ["synth_whoosh.wav"],
	&"grab": ["impactPunch_medium_001.ogg", "dropLeather.ogg"],
	&"summon": ["synth_magic.wav"],
	&"bell": ["impactBell_heavy_000.ogg", "impactBell_heavy_001.ogg"],
	&"coin": ["handleCoins.ogg"],
	&"earth": ["impactMining_000.ogg", "impactMining_001.ogg"],
	&"fire": ["synth_whoosh.wav"],
	&"wood": ["impactWood_heavy_000.ogg"],
	&"trap": ["metalLatch.ogg", "metalClick.ogg"],
	&"book": ["bookFlip1.ogg", "bookOpen.ogg"],
}

static var _shader_flash: Shader
static var _shader_ground: Shader

var _mats: Dictionary = {}
var _tex: Dictionary = {}
var _quad_by_mat: Dictionary = {}
var _streams: Dictionary = {}
var _grad_fade: Gradient
var _grad_pop: Gradient
var _curve_shrink: Curve
var _curve_grow: Curve
var _curve_pop: Curve
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_i := 0
var _nodes: Dictionary = {}          # id -> Node3D (projectile / area visuals)
var _live := 0
var _world: Node = null
var _screen_flash: ColorRect
var _font: SystemFont
var _warned: Dictionary = {}
var _parked: Array[Dictionary] = []  # despawned AreaVis kept briefly so a follow re-spawn can reclaim them
var _world_script: Script = null
var _world_has_instance := -1       # -1 unknown, 0 no, 1 core/world.gd has static get_instance()

const AREA_PARK_MS := 150


# =============================================================================================
# Setup

func _ready() -> void:
	_grad_fade = _gradient([0.0, 0.6, 1.0], [1.0, 1.0, 0.0])
	_grad_pop = _gradient([0.0, 0.12, 0.65, 1.0], [0.0, 1.0, 1.0, 0.0])
	_curve_shrink = _curve([Vector2(0, 1), Vector2(1, 0.15)])
	_curve_grow = _curve([Vector2(0, 0.35), Vector2(1, 1.0)])
	_curve_pop = _curve([Vector2(0, 0.2), Vector2(0.2, 1.0), Vector2(1, 0.6)])
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "Arial"])
	_font.font_weight = 800
	_ensure_voices()
	var cl := CanvasLayer.new()
	cl.layer = 90
	add_child(cl)
	_screen_flash = ColorRect.new()
	_screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.color = Color(1, 1, 1, 0)
	_screen_flash.visible = false
	cl.add_child(_screen_flash)
	var tree := get_tree()
	if tree and tree.has_signal(&"scene_changed"):
		tree.scene_changed.connect(clear_all)


func _process(_delta: float) -> void:
	if _parked.is_empty():
		return
	var now := Time.get_ticks_msec()
	var i := _parked.size() - 1
	while i >= 0:
		var e: Dictionary = _parked[i]
		if now - int(e["t"]) > AREA_PARK_MS or not is_instance_valid(e["n"]):
			_parked.remove_at(i)
			_release(e["n"])
		i -= 1


func _should_broadcast() -> bool:
	if not is_inside_tree():
		return false
	var mp := multiplayer
	if mp == null or not mp.has_multiplayer_peer():
		return false
	var peer := mp.multiplayer_peer
	if peer is OfflineMultiplayerPeer:
		return false
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return mp.is_server()


# =============================================================================================
# Public API (ARCHITECTURE §7.3)

func play(name: StringName, pos: Vector3, dir := Vector3.FORWARD, color := Color.WHITE, scale := 1.0) -> void:
	if _should_broadcast():
		_rpc_play.rpc(name, pos, dir, color, scale)
	else:
		_do_play(name, pos, dir, color, scale)


## homing_rate: max turn rate in rad/s (pass the host Projectile.homing so the visual matches it);
## 0 keeps the legacy soft steering. Re-issuing the same id (e.g. on bounce) replaces the visual.
func spawn_projectile_visual(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid := 0, homing_rate := 0.0) -> void:
	if _should_broadcast():
		_rpc_projectile.rpc(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate)
	else:
		_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate)


func spawn_area_visual(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> void:
	if _should_broadcast():
		_rpc_area.rpc(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color)
	else:
		_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color)


## Moves/turns a live area visual without restarting it (for follow_caster areas and beams).
func move_area_visual(id: int, pos: Vector3, yaw: float) -> void:
	if _should_broadcast():
		_rpc_move_area.rpc(id, pos, yaw)
	else:
		_do_move_area(id, pos, yaw)


func despawn(id: int) -> void:
	if _should_broadcast():
		_rpc_despawn.rpc(id)
	else:
		_do_despawn(id)


func damage_number(pos: Vector3, amount: float, kind: StringName) -> void:
	if _should_broadcast():
		_rpc_number.rpc(pos, amount, kind)
	else:
		_do_number(pos, amount, kind)


func sfx(name: StringName, pos: Vector3) -> void:
	if _should_broadcast():
		_rpc_sfx.rpc(name, pos)
	else:
		_do_sfx(name, pos)


## Removes every live projectile/area visual (call on scene change / round reset). Local only.
func clear_all() -> void:
	for e in _parked:
		if is_instance_valid(e["n"]):
			(e["n"] as Node).queue_free()
	_parked.clear()
	for id in _nodes.keys():
		var n: Node = _nodes[id]
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_stop_voices()


## Stops every pooled SFX voice and drops its stream, so no AudioStreamPlayback outlives the current scene.
func _stop_voices() -> void:
	for v in _voices:
		if is_instance_valid(v):
			v.stop()
			v.stream = null


## Full teardown (tests / app exit): clear_all + frees the pooled AudioStreamPlayer3D voices, one-shot effect
## nodes and cached streams/materials. Safe to call more than once; the voice pool is rebuilt lazily by sfx().
func shutdown() -> void:
	clear_all()
	for v in _voices:
		if is_instance_valid(v):
			v.queue_free()
	_voices.clear()
	_voice_i = 0
	for c in get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			c.queue_free()     # live one-shot flashes / particles / numbers
	_streams.clear()


## True on the headless display server (tests, dedicated hosts): voices are prepared but never started, so no
## AudioStreamPlayback is left queued in the (Dummy) AudioServer at exit ("resources still in use" / leaks).
## Set `play_in_headless` to force playback anyway.
var play_in_headless: bool = false
var _headless := -1


func _audio_silent() -> bool:
	if play_in_headless:
		return false
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	return _headless == 1


func _ensure_voices() -> void:
	if not _voices.is_empty() or not is_inside_tree():
		return
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice%d" % i
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 12000.0
		add_child(p)
		_voices.append(p)


func _exit_tree() -> void:
	_stop_voices()
	_streams.clear()


func live_count() -> int:
	return _live


# --- RPC endpoints (host -> all peers, also run locally via call_local)

@rpc("authority", "call_local", "unreliable")
func _rpc_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float) -> void:
	_do_play(name, pos, dir, color, scale)

@rpc("authority", "call_local", "reliable")
func _rpc_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate: float) -> void:
	_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate)

@rpc("authority", "call_local", "reliable")
func _rpc_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> void:
	_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color)

@rpc("authority", "call_local", "unreliable_ordered")
func _rpc_move_area(id: int, pos: Vector3, yaw: float) -> void:
	_do_move_area(id, pos, yaw)

@rpc("authority", "call_local", "reliable")
func _rpc_despawn(id: int) -> void:
	_do_despawn(id)

@rpc("authority", "call_local", "unreliable")
func _rpc_number(pos: Vector3, amount: float, kind: StringName) -> void:
	_do_number(pos, amount, kind)

@rpc("authority", "call_local", "unreliable")
func _rpc_sfx(name: StringName, pos: Vector3) -> void:
	_do_sfx(name, pos)


# =============================================================================================
# Named effects

func _do_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float) -> void:
	if not is_inside_tree():
		return
	var crowded := _live > MAX_LIVE_NODES
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var s := maxf(scale, 0.05)
	match name:
		&"hit_spark":
			var c := _c(color, Color(1.0, 0.85, 0.45))
			_flash_billboard("star_08", pos, c, 0.14, 0.9 * s, 1.6 * s)
			_burst(pos, {"tex": "trace_01", "amount": 10, "life": 0.25, "speed": [6.0, 11.0], "spread": 180.0, "size": 0.45 * s, "color": c, "curve": _curve_shrink, "align": true})
		&"hit_heavy":
			var c := _c(color, Color(1.0, 0.7, 0.3))
			_flash_billboard("flare_01", pos, c, 0.16, 1.0 * s, 2.4 * s)
			_flash_billboard("circle_03", pos, c, 0.25, 0.4 * s, 2.6 * s)
			_burst(pos, {"tex": "trace_01", "amount": 22, "life": 0.4, "speed": [7.0, 15.0], "spread": 180.0, "size": 0.45 * s, "color": c, "curve": _curve_shrink, "align": true})
			if not crowded:
				_burst(pos, {"tex": "star_06", "amount": 6, "life": 0.35, "speed": [2.0, 5.0], "spread": 180.0, "size": 0.5 * s, "color": Color.WHITE, "curve": _curve_shrink})
		&"slash_arc":
			var c := _c(color, Color(0.75, 0.9, 1.0))
			var basis := _basis_facing(d)
			var roll := randf_range(-0.7, 0.7)
			# crescent in the plane facing the attacker (reads from a chase camera) ...
			var f := _flash_mesh(_quad_mesh(), _tex_mat("twirl_01", false), pos + d * 0.7, c, 0.22, Vector3(2.2, 2.2, 1) * s, Vector3(3.0, 3.0, 1) * s)
			f.basis = basis * Basis(Vector3.BACK, roll)
			f.spin = Vector3(0, 0, -6.0 if roll > 0.0 else 6.0)
			# ... and a flat one in the swing plane (reads from above / the side)
			var f2 := _flash_mesh(_quad_mesh(), _tex_mat("slash_02", false), pos + d * 0.6, c.lightened(0.3), 0.2, Vector3(2.4, 2.4, 1) * s, Vector3(3.0, 3.0, 1) * s)
			f2.basis = basis * Basis(Vector3.BACK, roll * 0.5) * Basis(Vector3.RIGHT, -PI / 2)
			if not crowded:
				_burst(pos + d * 1.0, {"tex": "star_04", "amount": 8, "life": 0.25, "speed": [3.0, 7.0], "dir": d, "spread": 60.0, "size": 0.25 * s, "color": c, "curve": _curve_shrink})
		&"launch_burst":
			var c := _c(color, Color(1.0, 0.9, 0.6))
			_ground_ring(pos, c, 0.35, 0.4 * s, 2.4 * s)
			_burst(pos, {"tex": "trace_01", "amount": 14, "life": 0.4, "speed": [8.0, 14.0], "dir": Vector3.UP, "spread": 20.0, "size": 0.6 * s, "color": c, "curve": _curve_shrink, "align": true})
		&"land_dust":
			var c := _c(color, Color(0.75, 0.7, 0.62))
			_burst(pos + Vector3(0, 0.1, 0), {"tex": "smoke_04", "amount": 12, "life": 0.6, "speed": [2.0, 4.0], "dir": Vector3.UP, "spread": 90.0, "flat": 0.9, "size": 0.8 * s, "color": c, "curve": _curve_grow, "add": false, "damp": 4.0})
		&"cast_glow":
			var c := _c(color, Color(0.6, 0.7, 1.0))
			var g := _flash_ground("magic_01", pos + Vector3(0, 0.05, 0), c, 0.7, 2.0 * s, 2.6 * s)
			g.spin = Vector3(0, 2.5, 0)
			_burst(pos, {"tex": "star_04", "amount": 14, "life": 0.7, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 15.0, "shape": "ring", "radius": 0.9 * s, "size": 0.25 * s, "color": c, "gravity": Vector3(0, 2, 0), "curve": _curve_shrink})
		&"heal_burst":
			var c := _c(color, Color(0.45, 1.0, 0.5))
			_ground_ring(pos + Vector3(0, 0.05, 0), c, 0.6, 0.5 * s, 2.2 * s)
			_burst(pos + Vector3(0, 0.3, 0), {"tex": "star_04", "amount": 16, "life": 1.0, "speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 25.0, "shape": "ring", "radius": 0.6 * s, "size": 0.35 * s, "color": c, "gravity": Vector3(0, 1.5, 0), "curve": _curve_pop})
			_flash_billboard("light_01", pos + Vector3(0, 1.0, 0), c, 0.4, 1.2 * s, 2.2 * s)
		&"buff_aura":
			var c := _c(color, Color(1.0, 0.85, 0.35))
			_ground_ring(pos + Vector3(0, 0.05, 0), c, 0.8, 1.6 * s, 1.0 * s)
			_burst(pos, {"tex": "trace_04", "amount": 18, "life": 0.9, "speed": [2.0, 4.0], "dir": Vector3.UP, "spread": 5.0, "shape": "ring", "radius": 0.7 * s, "size": 0.5 * s, "color": c, "curve": _curve_pop, "align": true})
		&"debuff_puff":
			var c := _c(color, Color(0.55, 0.25, 0.8))
			_burst(pos + Vector3(0, 1.4, 0), {"tex": "smoke_07", "amount": 10, "life": 0.8, "speed": [0.5, 1.5], "spread": 180.0, "size": 0.7 * s, "color": c, "gravity": Vector3(0, -1.5, 0), "curve": _curve_grow, "add": false})
			_burst(pos + Vector3(0, 1.4, 0), {"tex": "magic_04", "amount": 8, "life": 0.6, "speed": [1.0, 2.0], "spread": 180.0, "size": 0.35 * s, "color": c.lightened(0.3), "gravity": Vector3(0, -3, 0), "curve": _curve_shrink})
		&"explosion":
			_explosion(pos, _c(color, Color(1.0, 0.55, 0.15)), s, crowded)
		&"ice_burst":
			var c := _c(color, Color(0.55, 0.85, 1.0))
			_flash_billboard("flare_01", pos, c, 0.2, 1.0 * s, 2.4 * s)
			_ice_shards(pos, c, s, 7 if not crowded else 4)
			_burst(pos, {"tex": "smoke_02", "amount": 10, "life": 0.7, "speed": [1.0, 3.0], "spread": 180.0, "size": 0.9 * s, "color": c, "curve": _curve_grow, "damp": 3.0})
		&"lightning_strike":
			_lightning_bolt(pos, _c(color, Color(0.6, 0.75, 1.0)), s)
		&"fire_burst":
			var c := _c(color, Color(1.0, 0.5, 0.12))
			_flash_billboard("light_02", pos + Vector3(0, 0.5, 0), c, 0.25, 1.2 * s, 2.6 * s)
			_burst(pos, {"tex": "flame_05", "amount": 20, "life": 0.6, "speed": [2.0, 6.0], "dir": Vector3.UP, "spread": 45.0, "size": 0.9 * s, "color": c, "gravity": Vector3(0, 3, 0), "curve": _curve_shrink, "damp": 2.0})
			if not crowded:
				_burst(pos, {"tex": "star_01", "amount": 12, "life": 0.8, "speed": [3.0, 7.0], "dir": Vector3.UP, "spread": 60.0, "size": 0.3 * s, "color": Color(1.0, 0.8, 0.3), "gravity": Vector3(0, -4, 0)})
		&"holy_burst":
			var c := _c(color, Color(1.0, 0.92, 0.55))
			_pillar(pos, c, 0.55, 0.9 * s, 7.0)
			_ground_ring(pos + Vector3(0, 0.05, 0), c, 0.5, 0.6 * s, 3.0 * s)
			_burst(pos, {"tex": "star_07", "amount": 16, "life": 0.9, "speed": [1.5, 4.0], "dir": Vector3.UP, "spread": 30.0, "shape": "ring", "radius": 0.8 * s, "size": 0.35 * s, "color": c, "curve": _curve_pop})
		&"dark_burst":
			var c := _c(color, Color(0.6, 0.2, 0.95))
			var f := _flash_billboard("twirl_02", pos, c, 0.5, 2.8 * s, 0.6 * s)
			f.spin = Vector3(0, 0, -8.0)
			_burst(pos, {"tex": "magic_04", "amount": 16, "life": 0.5, "speed": [-7.0, -4.0], "spread": 180.0, "shape": "sphere", "radius": 1.8 * s, "size": 0.4 * s, "color": c, "curve": _curve_shrink})
			_burst(pos, {"tex": "smoke_08", "amount": 8, "life": 0.9, "speed": [0.5, 1.5], "spread": 180.0, "size": 1.0 * s, "color": Color(0.15, 0.03, 0.25), "curve": _curve_grow, "add": false})
		&"poison_cloud":
			var c := _c(color, Color(0.45, 0.95, 0.2))
			_burst(pos + Vector3(0, 0.6, 0), {"tex": "smoke_01", "amount": 14, "life": 1.6, "speed": [0.3, 1.0], "spread": 180.0, "shape": "sphere", "radius": 1.0 * s, "size": 1.3 * s, "color": c, "curve": _curve_pop, "add": false, "explosive": 0.6})
			_burst(pos + Vector3(0, 0.3, 0), {"tex": "circle_02", "amount": 10, "life": 1.2, "speed": [0.5, 1.5], "dir": Vector3.UP, "spread": 30.0, "shape": "sphere", "radius": 0.8 * s, "size": 0.2 * s, "color": c.lightened(0.3), "curve": _curve_pop})
		&"smoke":
			var c := _c(color, Color(0.55, 0.55, 0.58))
			_burst(pos + Vector3(0, 0.6, 0), {"tex": "smoke_04", "amount": 16, "life": 1.2, "speed": [1.0, 2.5], "spread": 180.0, "shape": "sphere", "radius": 0.6 * s, "size": 1.4 * s, "color": c, "curve": _curve_grow, "add": false, "damp": 2.0})
		&"blink":
			var c := _c(color, Color(0.7, 0.6, 1.0))
			_flash_billboard("flare_01", pos + Vector3(0, 1.0, 0), c, 0.2, 2.0 * s, 0.3 * s)
			var col := _flash_mesh(_cyl_mesh(), _flat_mat(), pos + Vector3(0, 1.0, 0), c, 0.25, Vector3(0.5, 2.2, 0.5) * s, Vector3(0.02, 2.6, 0.02) * s)
			col.position = pos + Vector3(0, 1.0, 0)
			_burst(pos + Vector3(0, 1.0, 0), {"tex": "star_04", "amount": 14, "life": 0.4, "speed": [2.0, 5.0], "spread": 180.0, "size": 0.25 * s, "color": c, "curve": _curve_shrink})
		&"dash_trail":
			var c := _c(color, Color(0.8, 0.9, 1.0))
			var back := -d
			for i in 4:
				var p := pos + back * (0.6 + i * 0.7) + Vector3(0, 1.0, 0)
				var f := _flash_mesh(_quad_mesh(), _tex_mat("trace_06", false), p, c, 0.25 + i * 0.04, Vector3(0.6, 2.0, 1) * s, Vector3(0.2, 2.0, 1) * s)
				f.basis = _basis_facing(d) * Basis(Vector3.UP, PI / 2)
			_burst(pos + Vector3(0, 0.15, 0), {"tex": "smoke_04", "amount": 6, "life": 0.4, "speed": [1.0, 2.0], "dir": back, "spread": 30.0, "size": 0.5 * s, "color": Color(0.7, 0.68, 0.62), "curve": _curve_grow, "add": false})
		&"summon_circle":
			var c := _c(color, Color(0.6, 0.45, 1.0))
			var g := _flash_ground("magic_02", pos + Vector3(0, 0.06, 0), c, 1.3, 2.4 * s, 3.0 * s, 0.25)
			g.spin = Vector3(0, 1.6, 0)
			_pillar(pos, c, 0.8, 0.8 * s, 3.0)
			_burst(pos, {"tex": "magic_05", "amount": 20, "life": 1.0, "speed": [1.0, 3.5], "dir": Vector3.UP, "spread": 10.0, "shape": "ring", "radius": 1.2 * s, "size": 0.3 * s, "color": c, "curve": _curve_pop})
		&"block_spark":
			var c := _c(color, Color(0.75, 0.9, 1.0))
			_flash_billboard("star_06", pos, c, 0.15, 1.0 * s, 1.8 * s)
			_flash_billboard("circle_03", pos, c, 0.2, 0.6 * s, 1.8 * s)
			_burst(pos, {"tex": "trace_01", "amount": 14, "life": 0.3, "speed": [5.0, 9.0], "dir": d, "spread": 70.0, "size": 0.3 * s, "color": c, "gravity": Vector3(0, -12, 0), "curve": _curve_shrink, "align": true})
		&"death":
			var c := _c(color, Color(0.85, 0.85, 1.0))
			_burst(pos + Vector3(0, 0.6, 0), {"tex": "smoke_07", "amount": 12, "life": 1.0, "speed": [1.0, 2.5], "spread": 180.0, "flat": 0.7, "size": 1.0 * s, "color": Color(0.5, 0.5, 0.55), "curve": _curve_grow, "add": false, "damp": 2.0})
			_burst(pos + Vector3(0, 0.8, 0), {"tex": "light_03", "amount": 3, "life": 1.5, "speed": [1.5, 2.5], "dir": Vector3.UP, "spread": 10.0, "size": 0.7 * s, "color": c, "curve": _curve_shrink})
			_ground_ring(pos + Vector3(0, 0.05, 0), c, 0.6, 0.4 * s, 2.4 * s)
		&"ultimate_flash":
			var c := _c(color, Color(1.0, 0.85, 0.4))
			_pillar(pos, c, 0.9, 1.6 * s, 14.0)
			_ground_ring(pos + Vector3(0, 0.06, 0), c, 0.7, 0.8 * s, 7.0 * s)
			_flash_billboard("flare_01", pos + Vector3(0, 1.2, 0), c, 0.35, 2.0 * s, 6.0 * s)
			_burst(pos + Vector3(0, 0.5, 0), {"tex": "star_08", "amount": 26, "life": 1.0, "speed": [4.0, 10.0], "spread": 180.0, "flat": 0.5, "size": 0.5 * s, "color": c, "curve": _curve_shrink, "damp": 3.0})
			_screen_flash_now(c)
		_:
			if not _warned.has(name):
				_warned[name] = true
				push_warning("Fx.play: unknown effect '%s' (using hit_spark)" % name)
			_do_play(&"hit_spark", pos, dir, color, scale)


func _explosion(pos: Vector3, c: Color, s: float, crowded: bool) -> void:
	_flash_billboard("flare_01", pos + Vector3(0, 0.4, 0), Color(1, 0.95, 0.8), 0.18, 1.5 * s, 4.0 * s)
	_ground_ring(pos + Vector3(0, 0.08, 0), c, 0.45, 0.6 * s, 4.5 * s)
	_burst(pos + Vector3(0, 0.4, 0), {"tex": "muzzle_02", "amount": 18, "life": 0.55, "speed": [3.0, 8.0], "spread": 180.0, "flat": 0.3, "size": 1.3 * s, "color": c, "curve": _curve_shrink, "damp": 6.0})
	_burst(pos + Vector3(0, 0.6, 0), {"tex": "smoke_08", "amount": 12, "life": 1.3, "speed": [1.5, 3.5], "dir": Vector3.UP, "spread": 70.0, "size": 1.6 * s, "color": Color(0.3, 0.27, 0.25), "curve": _curve_grow, "add": false, "damp": 2.5})
	if not crowded:
		_burst(pos + Vector3(0, 0.3, 0), {"tex": "star_01", "amount": 20, "life": 0.9, "speed": [6.0, 13.0], "dir": Vector3.UP, "spread": 80.0, "size": 0.35 * s, "color": Color(1.0, 0.8, 0.35), "gravity": Vector3(0, -14, 0)})


func _lightning_bolt(pos: Vector3, c: Color, s: float) -> void:
	var top := pos + Vector3(randf_range(-0.6, 0.6), 9.0, randf_range(-0.6, 0.6))
	var segs := 5
	var prev := top
	for i in segs:
		var t := float(i + 1) / segs
		var nxt := top.lerp(pos, t) + (Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7)) if i < segs - 1 else Vector3.ZERO)
		var mid := (prev + nxt) * 0.5
		var len := prev.distance_to(nxt)
		var f := _flash_mesh(_box_mesh(), _flat_mat(), mid, c.lightened(0.6), 0.25, Vector3.ONE, Vector3.ONE)
		f.basis = _basis_along((nxt - prev).normalized())
		f.s0 = Vector3(0.24 * s, len, 0.24 * s)
		f.s1 = Vector3(0.04 * s, len, 0.04 * s)
		var g := _flash_mesh(_cyl_mesh(), _beam_mat(), mid, c, 0.3, Vector3.ONE, Vector3.ONE)
		g.basis = f.basis
		g.s0 = Vector3(0.9 * s, len, 0.9 * s)
		g.s1 = Vector3(0.2 * s, len, 0.2 * s)
		prev = nxt
	_flash_billboard("flare_01", pos + Vector3(0, 0.3, 0), c, 0.2, 2.0 * s, 3.0 * s)
	_ground_ring(pos + Vector3(0, 0.06, 0), c, 0.35, 0.5 * s, 2.5 * s)
	_burst(pos + Vector3(0, 0.2, 0), {"tex": "spark_06", "amount": 16, "life": 0.35, "speed": [4.0, 10.0], "dir": Vector3.UP, "spread": 70.0, "size": 0.35 * s, "color": c, "curve": _curve_shrink, "align": true})


func _ice_shards(pos: Vector3, c: Color, s: float, n: int) -> void:
	var mat := _solid_glow_mat(c)
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var mi := Flash.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat
		mi.uses_shader = false
		var dir := Vector3(cos(a), 0.6, sin(a)).normalized()
		mi.life = 0.7
		mi.vel = dir * randf_range(3.0, 6.0)
		mi.grav = 9.0
		mi.s0 = Vector3(1, 1.2, 1) * s * randf_range(0.6, 1.0)
		mi.s1 = mi.s0 * 0.3
		mi.align_vel = true
		_add_fx(mi, pos + Vector3(0, 0.6, 0))


# =============================================================================================
# Projectile visuals

class ProjVis extends Node3D:
	var fx: Node
	var vel := Vector3.ZERO
	var grav := 0.0
	var homing_uid := 0
	var homing_rate := 0.0
	var _retry := 0.0
	var age := 0.0
	var max_life := 8.0
	var spin_node: Node3D
	var spin := Vector3.ZERO
	var trail: CPUParticles3D
	var segments: Array[Node3D] = []
	var history: Array[Vector3] = []
	var flicker: Node3D
	var _target: WeakRef

	func _process(delta: float) -> void:
		age += delta
		if age > max_life:
			fx.call("_do_despawn_node", self)
			return
		if homing_uid != 0:
			var tp: Variant = _target_pos(delta)
			if tp is Vector3:
				var want_dir: Vector3 = ((tp as Vector3) - global_position).normalized()
				if homing_rate > 0.0:
					# match the host Projectile: rotate at most homing_rate * delta per frame
					var cur := vel.normalized()
					var ang := cur.angle_to(want_dir)
					var axis := cur.cross(want_dir)
					if ang > 0.0001 and axis.length_squared() > 0.000001:
						vel = vel.rotated(axis.normalized(), minf(ang, homing_rate * delta))
				else:
					vel = vel.lerp(want_dir * vel.length(), clampf(delta * 5.0, 0.0, 1.0))
		vel.y -= grav * delta
		global_position += vel * delta
		if vel.length_squared() > 0.0001:
			var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
			look_at(global_position + vel, up)
		if spin_node:
			spin_node.rotate_object_local(Vector3.FORWARD, spin.z * delta)
			spin_node.rotate_object_local(Vector3.UP, spin.y * delta)
			spin_node.rotate_object_local(Vector3.RIGHT, spin.x * delta)
		if flicker:
			flicker.scale = Vector3.ONE * randf_range(0.7, 1.3)
			flicker.rotation.z = randf() * TAU
		if not segments.is_empty():
			history.push_front(global_position)
			if history.size() > segments.size() * 3 + 1:
				history.resize(segments.size() * 3 + 1)
			for i in segments.size():
				var hi := mini((i + 1) * 3, history.size() - 1)
				segments[i].global_position = history[hi]

	func _target_pos(delta := 0.0) -> Variant:
		var t: Node3D = _target.get_ref() if _target else null
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			t = null
			_target = null
			# back off: at most ~4 lookups per second while the target cannot be resolved
			_retry -= delta
			if _retry > 0.0:
				return null
			_retry = 0.25
			t = fx.call("_find_fighter", homing_uid)
			_target = weakref(t) if t else null
		if t == null:
			return null
		return t.global_position + Vector3(0, 1.0, 0)


func _do_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate := 0.0) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	var c := _c(color, PROJ_COLORS.get(visual, Color(0.6, 0.7, 1.0)))
	var s := maxf(scale, 0.05)
	var p := ProjVis.new()
	p.name = "Proj_%d" % id
	p.fx = self
	p.vel = vel
	p.grav = gravity
	p.homing_uid = homing_uid
	p.homing_rate = maxf(homing_rate, 0.0)
	var body := Node3D.new()
	body.name = "Body"
	p.add_child(body)
	body.scale = Vector3.ONE * s
	match visual:
		"orb":
			_mesh_child(body, _sphere_mesh(0.18), _solid_glow_mat(c.lightened(0.5)))
			_bill_child(body, "light_01", c, 1.3)
			p.trail = _trail(p, "magic_05", c, 0.35 * s, 0.35, 30)
		"bullet":
			var b := _mesh_child(body, _box_mesh(), _solid_glow_mat(c.lightened(0.4)))
			b.scale = Vector3(0.07, 0.07, 0.55)
			_bill_child(body, "flare_01", c, 0.5)
		"arrow":
			var a := _scene_child(body, "res://assets/weapons/fantasy/arrow_A.gltf")
			if a:
				a.rotation.y = PI
				a.scale = Vector3.ONE * 0.8
			p.trail = _trail(p, "trace_01", c, 0.12 * s, 0.25, 16)
		"grenade":
			var g := _scene_child(body, "res://assets/weapons/special/Grenade/Grenade.gltf")
			if g:
				g.scale = Vector3.ONE * 0.6
			p.spin_node = body
			p.spin = Vector3(9.0, 0, 0)
			p.trail = _trail(p, "smoke_04", Color(0.6, 0.6, 0.6), 0.3 * s, 0.4, 14, false)
		"shuriken":
			var sh := _scene_child(body, "res://assets/weapons/special/Ninja_Shuriken/Ninja_Shuriken.gltf")
			if sh:
				sh.scale = Vector3.ONE * 0.9
			p.spin_node = body
			p.spin = Vector3(0, 25.0, 0)
			p.trail = _trail(p, "star_04", c, 0.2 * s, 0.2, 12)
		"wave":
			var q := _mesh_child(body, _quad_mesh(), _tex_mat("slash_03", false))
			q.rotation = Vector3(-PI / 2, 0, 0)
			q.scale = Vector3(3.0, 2.2, 1.0)
			q.set_instance_shader_parameter("tint", c)
			var q2 := _mesh_child(body, _quad_mesh(), _tex_mat("slash_03", false))
			q2.rotation = Vector3(0, 0, PI / 2)
			q2.rotation = Vector3(-PI / 2, 0, 0)
			q2.position = Vector3(0, 0.2, 0.15)
			q2.scale = Vector3(2.4, 1.8, 1.0)
			q2.set_instance_shader_parameter("tint", c.lightened(0.4))
			p.trail = _trail(p, "trace_01", c, 0.4 * s, 0.3, 20)
		"missile":
			var m := _mesh_child(body, _cyl_mesh(), _plain_mat(Color(0.75, 0.75, 0.78)))
			m.rotation.x = PI / 2
			m.scale = Vector3(0.14, 0.7, 0.14)
			var nose := _mesh_child(body, _cone_mesh(), _plain_mat(Color(0.85, 0.2, 0.15)))
			nose.rotation.x = -PI / 2
			nose.position = Vector3(0, 0, -0.42)
			nose.scale = Vector3(0.14, 0.22, 0.14)
			var fl := _bill_child(body, "flare_01", c, 0.7)
			fl.position = Vector3(0, 0, 0.4)
			p.trail = _trail(p, "smoke_04", Color(0.75, 0.72, 0.7), 0.45 * s, 0.7, 28, false)
		"star":
			var st := _bill_child(body, "star_06", c, 1.1)
			p.flicker = st
			_bill_child(body, "light_01", c, 1.0)
			p.trail = _trail(p, "star_04", c, 0.25 * s, 0.4, 20)
		"blood":
			_mesh_child(body, _sphere_mesh(0.2), _solid_glow_mat(c))
			_bill_child(body, "light_02", c, 1.0)
			p.trail = _trail(p, "circle_05", c, 0.3 * s, 0.4, 20, true, Vector3(0, -6, 0))
		"qi":
			_mesh_child(body, _sphere_mesh(0.28), _solid_glow_mat(c.lightened(0.6)))
			var tw := _bill_child(body, "twirl_01", c, 1.8)
			p.flicker = tw
			_bill_child(body, "light_01", c, 1.6)
			p.trail = _trail(p, "magic_05", c, 0.5 * s, 0.35, 30)
		"dragon":
			_mesh_child(body, _sphere_mesh(0.32), _solid_glow_mat(c.lightened(0.5)))
			_bill_child(body, "light_02", c, 1.6)
			for i in 7:
				var seg := Node3D.new()
				var sm := _mesh_child(seg, _sphere_mesh(0.26 - i * 0.025), _solid_glow_mat(c))
				sm.scale = Vector3.ONE * s
				_bill_child(seg, "flame_05", c, (1.2 - i * 0.12) * s)
				p.add_child(seg)
				seg.top_level = true
				p.segments.append(seg)
			p.trail = _trail(p, "flame_05", c, 0.45 * s, 0.4, 30)
		"lightning":
			var bolt := _bill_child(body, "spark_06", c.lightened(0.4), 1.4)
			p.flicker = bolt
			_bill_child(body, "light_01", c, 1.3)
			var tr := _mesh_child(body, _box_mesh(), _solid_glow_mat(c.lightened(0.6)))
			tr.scale = Vector3(0.06, 0.06, 1.2)
			tr.position = Vector3(0, 0, 0.5)
			p.trail = _trail(p, "spark_03", c, 0.3 * s, 0.2, 24)
		"cannonball":
			_mesh_child(body, _sphere_mesh(0.3), _plain_mat(Color(0.12, 0.12, 0.13), 0.7))
			var fl := _bill_child(body, "muzzle_02", c, 1.0)
			fl.position = Vector3(0, 0, 0.25)
			p.trail = _trail(p, "flame_05", c, 0.5 * s, 0.35, 26)
		"flask":
			var f := _scene_child(body, "res://assets/weapons/adv/potion_small_green.gltf")
			if f:
				f.scale = Vector3.ONE * 0.9
			p.spin_node = body
			p.spin = Vector3(10.0, 0, 3.0)
			p.trail = _trail(p, "circle_05", c, 0.22 * s, 0.4, 14, true, Vector3(0, -5, 0))
		"scythe":
			var sc := _scene_child(body, "res://assets/weapons/special/Skeleton_Scythe/Skeleton_Scythe.gltf")
			if sc:
				sc.rotation = Vector3(PI / 2, 0, 0)
				sc.scale = Vector3.ONE * 0.6
			p.spin_node = body
			p.spin = Vector3(0, 18.0, 0)
			_bill_child(body, "light_02", c, 1.2)
			p.trail = _trail(p, "twirl_03", c, 0.5 * s, 0.25, 20)
		_:
			if not _warned.has("proj_" + visual):
				_warned["proj_" + visual] = true
				push_warning("Fx.spawn_projectile_visual: unknown visual '%s' (using orb)" % visual)
			_mesh_child(body, _sphere_mesh(0.18), _solid_glow_mat(c.lightened(0.5)))
			_bill_child(body, "light_01", c, 1.3)
	add_child(p)
	p.global_position = from
	for seg in p.segments:
		seg.global_position = from
	if vel.length_squared() > 0.0001:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
		p.look_at(from + vel, up)
	_nodes[id] = p
	_live += 1
	p.tree_exiting.connect(func() -> void: _live -= 1)


func _trail(p: Node3D, tex: String, c: Color, size: float, life: float, amount: int, add := true, gravity := Vector3.ZERO) -> CPUParticles3D:
	var t := _make_particles({"tex": tex, "amount": amount, "life": life, "speed": [0.0, 0.4], "spread": 180.0, "size": size,
		"color": c, "curve": _curve_shrink, "add": add, "gravity": gravity, "one_shot": false})
	t.local_coords = false
	t.explosiveness = 0.0
	t.emitting = true
	p.add_child(t)
	return t


func _do_despawn_node(n: Node) -> void:
	for k in _nodes.keys():
		if _nodes[k] == n:
			_nodes.erase(k)
			_release(n)
			return
	for i in _parked.size():
		if _parked[i]["n"] == n:
			_parked.remove_at(i)
			break
	_release(n)


# =============================================================================================
# Area visuals

class AreaVis extends Node3D:
	var fx: Node
	var visual := ""
	var shape := "circle"
	var radius := 3.0
	var length := 6.0
	var width := 2.0
	var delay := 0.0
	var duration := 0.0
	var color := Color.WHITE
	var age := 0.0
	var telegraph: MeshInstance3D
	var zone: MeshInstance3D
	var started := false
	var ending := false
	var end_time := 0.0
	var tick := 0.0
	var spinners: Array[Node3D] = []
	var emitters: Array[CPUParticles3D] = []
	var reclaimed := 0             # times this visual was re-used by a follow re-spawn

	func _process(delta: float) -> void:
		age += delta
		if telegraph and not started:
			var prog := clampf(age / maxf(delay, 0.001), 0.0, 1.0)
			telegraph.set_instance_shader_parameter("progress", prog)
			telegraph.set_instance_shader_parameter("alpha", 0.7 + 0.3 * sin(age * 14.0))
		if not started and age >= delay:
			started = true
			if telegraph:
				telegraph.queue_free()
				telegraph = null
			fx.call("_area_start", self)
			end_time = delay + maxf(duration, 0.6)
		if started:
			for s in spinners:
				if is_instance_valid(s):
					s.rotate_y(delta * 1.4)
			if duration > 0.0 and not ending:
				tick -= delta
				if tick <= 0.0:
					tick = 0.45
					fx.call("_area_tick", self)
			var remain := end_time - age
			if zone:
				var a := clampf(remain / 0.4, 0.0, 1.0) * clampf((age - delay) / 0.15, 0.0, 1.0)
				zone.set_instance_shader_parameter("alpha", a * (0.85 + 0.15 * sin(age * 5.0)))
			if remain <= 0.0:
				fx.call("_do_despawn_node", self)

	func line_center() -> Vector3:
		return Vector3(0, 0, -length * 0.5) if shape == "line" else Vector3.ZERO


func _do_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	if _reclaim_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color):
		return
	var a := AreaVis.new()
	a.name = "Area_%d" % id
	a.fx = self
	a.visual = visual if visual in AREA_VISUALS else "rune"
	a.shape = shape if shape in ["circle", "line", "ring"] else "circle"
	a.radius = maxf(radius, 0.2)
	a.length = maxf(length, 0.5)
	a.width = maxf(width, 0.3)
	a.delay = maxf(delay, 0.0)
	a.duration = maxf(duration, 0.0)
	a.color = _c(color, AREA_COLORS.get(a.visual, Color(0.6, 0.45, 1.0)))
	add_child(a)
	a.global_position = pos + Vector3(0, 0.04, 0)
	a.rotation.y = yaw
	if a.delay > 0.0:
		var tc := a.color.lerp(Color(1.0, 0.15, 0.1), 0.65)
		a.telegraph = _ground_shape(a, tc, 1.0, true)
	_nodes[id] = a
	_live += 1
	a.tree_exiting.connect(func() -> void: _live -= 1)


## CORE's follow_caster areas re-issue their visual as despawn(old) + spawn(new id) when the caster moves.
## A just-despawned area with the same look is re-used (moved, re-keyed, timing updated) instead of
## restarting the fade-in, spikes, flare and first tick.
func _reclaim_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> bool:
	var v := visual if visual in AREA_VISUALS else "rune"
	var sh := shape if shape in ["circle", "line", "ring"] else "circle"
	var c := _c(color, AREA_COLORS.get(v, Color(0.6, 0.45, 1.0)))
	for i in range(_parked.size() - 1, -1, -1):
		var pn: Variant = _parked[i]["n"]
		if pn == null or not is_instance_valid(pn) or not (pn is AreaVis):
			continue
		var a := pn as AreaVis
		if a.is_queued_for_deletion():
			continue
		if a.visual != v or a.shape != sh or not a.color.is_equal_approx(c):
			continue
		if absf(a.radius - maxf(radius, 0.2)) > 0.01 or absf(a.length - maxf(length, 0.5)) > 0.01 or absf(a.width - maxf(width, 0.3)) > 0.01:
			continue
		_parked.remove_at(i)
		a.name = "Area_%d" % id
		a.global_position = pos + Vector3(0, 0.04, 0)
		a.rotation.y = yaw
		var d := maxf(delay, 0.0)
		var dur := maxf(duration, 0.0)
		if not a.started:
			a.delay = a.age + d
			a.duration = dur
		elif a.duration > 0.0:
			a.end_time = a.age + d + dur
		else:
			a.end_time = maxf(a.end_time, a.age + d + dur)
		a.reclaimed += 1
		_nodes[id] = a
		return true
	return false


func _do_move_area(id: int, pos: Vector3, yaw: float) -> void:
	var n: Variant = _nodes.get(id)
	if n == null or not is_instance_valid(n) or not (n is AreaVis):
		return
	var a := n as AreaVis
	a.global_position = pos + Vector3(0, 0.04, 0)
	a.rotation.y = yaw


## Flat shape mesh (circle/ring/line) using the ground shader, child of the area node.
func _ground_shape(a: AreaVis, c: Color, alpha: float, is_telegraph: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	if a.shape == "line":
		pm.size = Vector2(a.width, a.length)
	else:
		pm.size = Vector2(a.radius * 2.0, a.radius * 2.0)
	mi.mesh = pm
	mi.material_override = _ground_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = a.line_center() + Vector3(0, 0.03 if is_telegraph else 0.02, 0)
	mi.set_instance_shader_parameter("tint", c)
	mi.set_instance_shader_parameter("shape", 1.0 if a.shape == "line" else (2.0 if a.shape == "ring" else 0.0))
	mi.set_instance_shader_parameter("inner", 0.55)
	mi.set_instance_shader_parameter("telegraph", 1.0 if is_telegraph else 0.0)
	mi.set_instance_shader_parameter("progress", 0.0 if is_telegraph else 1.0)
	mi.set_instance_shader_parameter("alpha", alpha)
	a.add_child(mi)
	return mi


func _area_emit_cfg(a: AreaVis) -> Dictionary:
	if a.shape == "line":
		return {"shape": "box", "box": Vector3(a.width * 0.5, 0.05, a.length * 0.5)}
	if a.shape == "ring":
		return {"shape": "ring", "radius": a.radius, "inner": a.radius * 0.55}
	return {"shape": "ring", "radius": a.radius * 0.95, "inner": 0.0}


func _area_area(a: AreaVis) -> float:
	if a.shape == "line":
		return a.width * a.length
	return PI * a.radius * a.radius


func _area_start(a: AreaVis) -> void:
	var c := a.color
	var persistent := a.duration > 0.0
	a.zone = _ground_shape(a, c, 0.0, false)
	var base := _area_emit_cfg(a)
	var dens := clampf(_area_area(a) / 12.0, 0.6, 3.0)
	var center := a.line_center()
	var cfg := {}
	match a.visual:
		"fire":
			cfg = {"tex": "flame_05", "amount": int(26 * dens), "life": 0.8, "speed": [1.5, 3.5], "dir": Vector3.UP, "spread": 12.0, "size": 0.9, "color": c, "gravity": Vector3(0, 2, 0), "curve": _curve_shrink}
		"ice":
			cfg = {"tex": "smoke_02", "amount": int(14 * dens), "life": 1.2, "speed": [0.3, 1.0], "dir": Vector3.UP, "spread": 30.0, "size": 1.0, "color": c, "curve": _curve_pop}
			_area_spikes(a, _solid_glow_mat(c), int(8 * dens), 1.0, 4)
		"lightning":
			cfg = {"tex": "spark_06", "amount": int(18 * dens), "life": 0.25, "speed": [0.5, 3.0], "dir": Vector3.UP, "spread": 60.0, "size": 0.5, "color": c, "curve": _curve_shrink}
		"holy":
			cfg = {"tex": "star_07", "amount": int(18 * dens), "life": 1.2, "speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 8.0, "size": 0.35, "color": c, "curve": _curve_pop}
			if a.shape != "line":
				_pillar(a.global_position, c, 0.6 if not persistent else 0.9, a.radius * 0.8, 6.0)
		"dark":
			cfg = {"tex": "magic_04", "amount": int(18 * dens), "life": 1.0, "speed": [0.5, 2.0], "dir": Vector3.UP, "spread": 20.0, "size": 0.45, "color": c, "curve": _curve_pop}
			_area_decal(a, "twirl_02", c, -1.5)
		"poison":
			cfg = {"tex": "smoke_01", "amount": int(14 * dens), "life": 1.6, "speed": [0.2, 0.8], "dir": Vector3.UP, "spread": 40.0, "size": 1.3, "color": c, "curve": _curve_pop, "add": false}
		"wind":
			cfg = {"tex": "trace_02", "amount": int(18 * dens), "life": 0.6, "speed": [4.0, 7.0], "dir": Vector3.UP, "spread": 30.0, "size": 0.7, "color": c, "curve": _curve_shrink, "align": true, "tangent": 6.0}
			_area_decal(a, "twirl_01", c, 3.5)
		"earth":
			cfg = {"tex": "dirt_01", "amount": int(16 * dens), "life": 0.7, "speed": [3.0, 6.0], "dir": Vector3.UP, "spread": 25.0, "size": 0.45, "color": c, "gravity": Vector3(0, -14, 0), "add": false}
			_area_spikes(a, _plain_mat(Color(0.5, 0.4, 0.3), 0.9), int(7 * dens), 1.2, 5)
		"blood":
			cfg = {"tex": "circle_05", "amount": int(18 * dens), "life": 0.9, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 25.0, "size": 0.3, "color": c, "gravity": Vector3(0, -6, 0), "curve": _curve_shrink}
			_area_decal(a, "scorch_02", c, 0.0)
		"rune":
			cfg = {"tex": "magic_03", "amount": int(10 * dens), "life": 1.4, "speed": [0.4, 1.2], "dir": Vector3.UP, "spread": 5.0, "size": 0.45, "color": c, "curve": _curve_pop}
			_area_decal(a, "magic_02", c, 1.0)
		"thorn":
			cfg = {"tex": "star_01", "amount": int(10 * dens), "life": 0.5, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 25.0, "size": 0.3, "color": c, "curve": _curve_shrink}
			_area_spikes(a, _plain_mat(Color(0.35, 0.55, 0.2), 0.8), int(10 * dens), 0.9, 5)
	cfg.merge(base)
	if persistent:
		cfg["one_shot"] = false
		var e := _make_particles(cfg)
		e.emitting = true
		e.position = center
		a.add_child(e)
		a.emitters.append(e)
	else:
		cfg["explosive"] = 0.85
		var e2 := _make_particles(cfg)
		e2.position = center
		a.add_child(e2)
		e2.emitting = true
		_flash_billboard("flare_01", a.global_position + a.global_basis * center + Vector3(0, 0.5, 0), c, 0.2, 1.0, maxf(a.radius, a.width) * 1.6)
	_area_tick(a)


## Periodic accents while a zone is active (lightning strikes, ember bursts...).
func _area_tick(a: AreaVis) -> void:
	if _live > MAX_LIVE_NODES:
		return
	var p := _random_point_in(a)
	match a.visual:
		"lightning":
			_lightning_bolt(p, a.color, 0.7)
		"fire":
			_burst(p, {"tex": "star_01", "amount": 6, "life": 0.6, "speed": [2.0, 5.0], "dir": Vector3.UP, "spread": 30.0, "size": 0.15, "color": Color(1.0, 0.8, 0.3), "gravity": Vector3(0, -3, 0)})
		"holy":
			_flash_billboard("light_03", p + Vector3(0, 0.8, 0), a.color, 0.5, 0.6, 1.4)
		"ice":
			_burst(p, {"tex": "star_04", "amount": 3, "life": 0.6, "speed": [0.5, 1.0], "dir": Vector3.UP, "spread": 20.0, "size": 0.25, "color": a.color.lightened(0.4), "curve": _curve_pop})


func _random_point_in(a: AreaVis) -> Vector3:
	var local := Vector3.ZERO
	if a.shape == "line":
		local = Vector3(randf_range(-a.width, a.width) * 0.5, 0, -randf() * a.length)
	elif a.shape == "ring":
		var ang := randf() * TAU
		var r := randf_range(a.radius * 0.6, a.radius)
		local = Vector3(cos(ang) * r, 0, sin(ang) * r)
	else:
		var ang2 := randf() * TAU
		var r2 := sqrt(randf()) * a.radius * 0.9
		local = Vector3(cos(ang2) * r2, 0, sin(ang2) * r2)
	return a.global_transform * local


func _area_spikes(a: AreaVis, mat: Material, n: int, h: float, sides: int) -> void:
	n = clampi(n, 3, 24)
	for i in n:
		var mi := Flash.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.22
		cm.height = 1.0
		cm.radial_segments = sides
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat
		mi.uses_shader = false
		var hh := h * randf_range(0.6, 1.3)
		mi.life = maxf(a.duration, 0.8) + 0.3
		mi.s0 = Vector3(1.0, 0.05, 1.0)
		mi.s1 = Vector3(1.0, hh, 1.0)
		mi.grow_time = 0.12
		mi.keep_scale = true
		mi.fade_tail = 0.3
		a.add_child(mi)
		mi.global_position = _random_point_in(a)
		mi.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
		mi.mark_base()
		mi.offset_half = true
		_live += 1
		mi.tree_exiting.connect(func() -> void: _live -= 1)


func _area_decal(a: AreaVis, tex: String, c: Color, spin: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var sz := Vector2(a.radius * 2.0, a.radius * 2.0) if a.shape != "line" else Vector2(a.width, a.length)
	pm.size = sz
	mi.mesh = pm
	mi.material_override = _tex_mat(tex, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = a.line_center() + Vector3(0, 0.05, 0)
	mi.set_instance_shader_parameter("tint", c)
	mi.set_instance_shader_parameter("fade", 0.9)
	a.add_child(mi)
	if spin != 0.0 and a.shape != "line":
		a.spinners.append(mi)


func _do_despawn(id: int) -> void:
	if not _nodes.has(id):
		return
	var n: Node3D = _nodes[id]
	_nodes.erase(id)
	if not is_instance_valid(n):
		return
	if n is AreaVis and not n.is_queued_for_deletion():
		# keep it alive for AREA_PARK_MS in case the host immediately re-spawns it (follow re-issue)
		_parked.append({"n": n, "t": Time.get_ticks_msec()})
		return
	_release(n)


## Frees a projectile/area visual, handing looping particle emitters to Fx so they finish instead of popping.
func _release(n: Node) -> void:
	if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	# let particle trails finish instead of popping
	for e in n.find_children("*", "CPUParticles3D", true, false):
		var cp := e as CPUParticles3D
		if cp.one_shot:
			continue
		var gp := cp.global_transform
		cp.get_parent().remove_child(cp)
		add_child(cp)
		cp.global_transform = gp
		cp.emitting = false
		_free_later(cp, cp.lifetime + 0.2)
	n.queue_free()


# =============================================================================================
# Damage numbers + SFX

class FloatText extends Label3D:
	var age := 0.0
	var life := 0.9
	var vel := Vector3(0, 2.4, 0)
	var big := false

	func _process(delta: float) -> void:
		age += delta
		var t := age / life
		global_position += vel * delta
		vel *= pow(0.05, delta)
		var pop := 1.0 + (0.6 if big else 0.25) * maxf(0.0, 1.0 - age / 0.12)
		scale = Vector3.ONE * pop
		modulate.a = clampf((1.0 - t) * 3.0, 0.0, 1.0)
		outline_modulate.a = modulate.a
		if age >= life:
			queue_free()


func _do_number(pos: Vector3, amount: float, kind: StringName) -> void:
	if not is_inside_tree():
		return
	var l := FloatText.new()
	l.font = _font
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0035
	l.outline_size = 14
	l.render_priority = 10
	l.outline_render_priority = 9
	l.double_sided = true
	var col: Color = NUMBER_COLORS.get(kind, NUMBER_COLORS[&"phys"])
	l.modulate = col
	l.outline_modulate = Color(0.05, 0.03, 0.08, 1.0)
	var n := int(round(absf(amount)))
	match kind:
		&"crit":
			l.text = "%d!" % n
			l.font_size = 104
			l.big = true
			l.life = 1.1
		&"heal":
			l.text = "+%d" % n
			l.font_size = 72
		&"miss":
			l.text = "未命中 MISS"
			l.font_size = 56
		_:
			l.text = str(n)
			l.font_size = 72
	l.vel = Vector3(randf_range(-0.6, 0.6), 2.6 if kind != &"crit" else 3.2, randf_range(-0.6, 0.6))
	add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.2, randf_range(-0.25, 0.25))


func _do_sfx(name: StringName, pos: Vector3) -> void:
	if not is_inside_tree():
		return
	_ensure_voices()
	if _voices.is_empty():
		return
	var list: Array = SFX_MAP.get(name, [])
	if list.is_empty():
		if not _warned.has("sfx_" + name):
			_warned["sfx_" + name] = true
			push_warning("Fx.sfx: unknown sound '%s' (using hit)" % name)
		list = SFX_MAP[&"hit"]
	var file: String = list[randi() % list.size()]
	var st: AudioStream = _streams.get(file)
	if st == null:
		st = load(SFX_DIR + file)
		if st == null:
			return
		_streams[file] = st
	var v := _voices[_voice_i]
	_voice_i = (_voice_i + 1) % _voices.size()
	v.stop()
	v.stream = st
	v.pitch_scale = randf_range(0.93, 1.07)
	v.volume_db = -2.0
	v.global_position = pos
	if not _audio_silent():
		v.play()


# =============================================================================================
# Building blocks

## Generic animated mesh used by most one-shot effects. Shader instance params: tint, fade.
class Flash extends MeshInstance3D:
	var life := 0.3
	var age := 0.0
	var s0 := Vector3.ONE
	var s1 := Vector3.ONE
	var tint := Color.WHITE
	var spin := Vector3.ZERO
	var vel := Vector3.ZERO
	var grav := 0.0
	var align_vel := false
	var grow_time := 0.0        # if > 0: scale s0->s1 over grow_time, then hold
	var keep_scale := false
	var fade_tail := 1.0        # fraction of life used for fading out
	var offset_half := false    # spikes: keep base on the ground while growing
	var uses_shader := true
	var _base_y := 0.0

	func _ready() -> void:
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if uses_shader and not (material_override is ShaderMaterial):
			uses_shader = false
		_apply(0.0)

	func mark_base() -> void:
		_base_y = position.y

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		if vel != Vector3.ZERO or grav != 0.0:
			vel.y -= grav * delta
			global_position += vel * delta
			if align_vel and vel.length_squared() > 0.01:
				var b := Basis(Quaternion(Vector3.UP, vel.normalized()))
				basis = b
		if spin != Vector3.ZERO:
			rotate_object_local(Vector3.UP, spin.y * delta)
			rotate_object_local(Vector3.BACK, spin.z * delta)
		_apply(age / life)

	func _apply(t: float) -> void:
		var k := t
		if grow_time > 0.0:
			k = clampf(age / grow_time, 0.0, 1.0)
		var sc := s0.lerp(s1, ease(k, 0.4))
		basis = basis.orthonormalized() * Basis.from_scale(sc.max(Vector3.ONE * 0.001))
		if offset_half:
			position.y = _base_y + sc.y * 0.5
		var f := clampf((1.0 - t) / maxf(fade_tail, 0.01), 0.0, 1.0)
		if uses_shader:
			set_instance_shader_parameter("tint", tint)
			set_instance_shader_parameter("fade", f)
		elif material_override is StandardMaterial3D:
			transparency = 1.0 - f


func _add_fx(n: Node3D, pos: Vector3) -> void:
	add_child(n)
	n.global_position = pos
	_live += 1
	n.tree_exiting.connect(func() -> void: _live -= 1)


func _flash_mesh(mesh: Mesh, mat: Material, pos: Vector3, c: Color, life: float, s0: Vector3, s1: Vector3) -> Flash:
	var f := Flash.new()
	f.mesh = mesh
	f.material_override = mat
	f.tint = c
	f.life = life
	f.s0 = s0
	f.s1 = s1
	f.uses_shader = mat is ShaderMaterial
	_add_fx(f, pos)
	return f


func _flash_billboard(tex: String, pos: Vector3, c: Color, life: float, size0: float, size1: float) -> Flash:
	return _flash_mesh(_quad_mesh(), _tex_mat(tex, true), pos, c, life, Vector3.ONE * size0, Vector3.ONE * size1)


func _flash_ground(tex: String, pos: Vector3, c: Color, life: float, size0: float, size1: float, fade_tail := 0.5) -> Flash:
	var f := _flash_mesh(_plane_mesh(), _tex_mat(tex, false), pos, c, life, Vector3.ONE * size0, Vector3.ONE * size1)
	f.fade_tail = fade_tail
	return f


func _ground_ring(pos: Vector3, c: Color, life: float, size0: float, size1: float) -> Flash:
	return _flash_ground("circle_03", pos, c, life, size0, size1, 0.8)


func _pillar(pos: Vector3, c: Color, life: float, radius: float, height: float) -> void:
	var f := _flash_mesh(_cyl_mesh(), _beam_mat(), pos + Vector3(0, height * 0.5, 0), c, life, Vector3(radius * 1.4, height, radius * 1.4), Vector3(radius * 0.2, height, radius * 0.2))
	f.fade_tail = 0.7


func _screen_flash_now(c: Color) -> void:
	if _screen_flash == null:
		return
	_screen_flash.visible = true
	_screen_flash.color = Color(c.r, c.g, c.b, 0.28)
	var tw := create_tween()
	tw.tween_property(_screen_flash, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _screen_flash.visible = false)


func _make_particles(cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, int(cfg.get("amount", 10)))
	p.lifetime = float(cfg.get("life", 0.5))
	p.one_shot = bool(cfg.get("one_shot", true))
	p.explosiveness = float(cfg.get("explosive", 1.0 if p.one_shot else 0.0))
	p.randomness = 0.5
	var additive := bool(cfg.get("add", true))
	p.mesh = _quad_for(_particle_mat(String(cfg.get("tex", "star_04")), additive))
	var sp: Array = cfg.get("speed", [2.0, 4.0])
	p.initial_velocity_min = sp[0]
	p.initial_velocity_max = sp[1]
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = float(cfg.get("spread", 45.0))
	p.flatness = float(cfg.get("flat", 0.0))
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	var size := float(cfg.get("size", 0.4))
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	if cfg.has("curve"):
		p.scale_amount_curve = cfg["curve"]
	var col: Color = cfg.get("color", Color.WHITE)
	# "add" particles are drawn alpha-blended with an HDR-boosted colour: they read on light floors
	# and still bloom with glow enabled.
	p.color = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, col.a) if additive else col
	p.color_ramp = _grad_pop if cfg.get("curve") == _curve_pop else _grad_fade
	p.damping_min = float(cfg.get("damp", 0.0))
	p.damping_max = float(cfg.get("damp", 0.0)) * 1.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	if cfg.has("tangent"):
		p.tangential_accel_min = float(cfg["tangent"])
		p.tangential_accel_max = float(cfg["tangent"]) * 1.4
	if bool(cfg.get("align", false)):
		p.particle_flag_align_y = true
	match String(cfg.get("shape", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(cfg.get("radius", 0.5))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.05
			p.emission_ring_radius = float(cfg.get("radius", 1.0))
			p.emission_ring_inner_radius = float(cfg.get("inner", 0.0))
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE * 0.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _burst(pos: Vector3, cfg: Dictionary) -> CPUParticles3D:
	if not is_inside_tree():
		return null
	var p := _make_particles(cfg)
	_add_fx(p, pos)
	p.emitting = true
	_free_later(p, p.lifetime + 0.25)
	return p


func _free_later(n: Node, t: float) -> void:
	var wr: WeakRef = weakref(n)
	get_tree().create_timer(t, false).timeout.connect(func() -> void:
		var o: Object = wr.get_ref()
		if o != null and is_instance_valid(o):
			(o as Node).queue_free())


func _mesh_child(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _bill_child(parent: Node3D, tex: String, c: Color, size: float) -> MeshInstance3D:
	var mi := _mesh_child(parent, _quad_mesh(), _tex_mat(tex, true))
	mi.scale = Vector3.ONE * size
	mi.set_instance_shader_parameter("tint", c)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


func _scene_child(parent: Node3D, path: String) -> Node3D:
	var ps: PackedScene = _tex.get(path)
	if ps == null:
		ps = load(path)
		if ps == null:
			return null
		_tex[path] = ps
	var n := ps.instantiate() as Node3D
	parent.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _find_fighter(uid: int) -> Node3D:
	var w := _get_world()
	if w == null:
		return null
	var f: Variant = null
	if w.has_method("get_fighter"):
		f = w.call("get_fighter", uid)
	if not (f is Node3D):
		f = w.get_node_or_null("Fighters/" + str(uid))
	return f as Node3D if f is Node3D else null


func _get_world() -> Node:
	if is_instance_valid(_world) and _world.is_inside_tree():
		return _world
	_world = null
	# World.get_instance() when core/world.gd exists (looked up dynamically so Fx never hard-depends on CORE)
	if _world_has_instance < 0:
		_world_has_instance = 0
		if ResourceLoader.exists("res://core/world.gd"):
			var scr: Variant = load("res://core/world.gd")
			if scr is Script and (scr as Script).get_script_method_list().any(func(m: Dictionary) -> bool: return m.get("name") == "get_instance"):
				_world_script = scr
				_world_has_instance = 1
	if _world_has_instance == 1 and _world_script != null:
		var w: Variant = _world_script.call("get_instance")
		if w is Node:
			_world = w
			return _world
	var tree := get_tree()
	if tree == null:
		return null
	var g := tree.get_first_node_in_group(&"world")
	if g:
		_world = g
		return g
	if tree.current_scene:
		_world = tree.current_scene.find_child("World", true, false)
	return _world


# =============================================================================================
# Resource caches

func _c(c: Color, default: Color) -> Color:
	return default if c == Color.WHITE else c


func _texture(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var t: Texture2D = load(TEX_DIR + name + ".png")
	_tex[name] = t
	return t


func _particle_mat(tex: String, add: bool) -> StandardMaterial3D:
	var k := "p_%s_%s" % [tex, add]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _texture(tex)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mats[k] = m
	return m


func _quad_for(mat: Material) -> QuadMesh:
	if _quad_by_mat.has(mat):
		return _quad_by_mat[mat]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	_quad_by_mat[mat] = q
	return q


func _tex_mat(tex: String, billboard: bool) -> ShaderMaterial:
	var k := "t_%s_%s" % [tex, billboard]
	if _mats.has(k):
		return _mats[k]
	if _shader_flash == null:
		_shader_flash = Shader.new()
		_shader_flash.code = """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;
uniform bool billboard = false;
uniform bool use_tex = true;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
void vertex() {
	if (billboard) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc.x, INV_VIEW_MATRIX[1] * sc.y, INV_VIEW_MATRIX[2] * sc.z, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}
void fragment() {
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	// alpha-blended with an HDR colour: visible on light floors, still blooms with glow
	ALBEDO = t.rgb * tint.rgb * 1.8;
	ALPHA = clamp(t.a * tint.a * fade, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader_flash
	m.set_shader_parameter("tex", _texture(tex))
	m.set_shader_parameter("billboard", billboard)
	_mats[k] = m
	return m


func _flat_mat() -> ShaderMaterial:
	var k := "flat"
	if _mats.has(k):
		return _mats[k]
	var m := _tex_mat("light_01", false).duplicate() as ShaderMaterial
	m.set_shader_parameter("use_tex", false)
	_mats[k] = m
	return m


func _beam_mat() -> ShaderMaterial:
	var k := "beam"
	if _mats.has(k):
		return _mats[k]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
void fragment() {
	float edge = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float v = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = mix(tint.rgb, vec3(1.0), edge * 0.6) * 1.8;
	ALPHA = clamp(edge * v * fade * tint.a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_mats[k] = m
	return m


func _ground_mat() -> ShaderMaterial:
	var k := "ground"
	if _mats.has(k):
		return _mats[k]
	if _shader_ground == null:
		_shader_ground = Shader.new()
		_shader_ground.code = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.1, 1.0);
instance uniform float progress = 1.0;
instance uniform float shape = 0.0;
instance uniform float inner = 0.55;
instance uniform float alpha = 1.0;
instance uniform float telegraph = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float outline = 0.0;
	float inside = 0.0;
	float fillmask = 0.0;
	if (shape < 0.5) {
		float d = length(p);
		inside = 1.0 - smoothstep(0.98, 1.0, d);
		outline = smoothstep(0.86, 0.95, d) * inside;
		fillmask = 1.0 - smoothstep(progress - 0.02, progress, d);
	} else if (shape < 1.5) {
		vec2 q = abs(p);
		float d = max(q.x, q.y);
		inside = 1.0 - smoothstep(0.985, 1.0, d);
		outline = max(smoothstep(0.84, 0.95, q.x), smoothstep(0.93, 0.98, q.y)) * inside;
		float along = 1.0 - UV.y;
		fillmask = 1.0 - smoothstep(progress - 0.02, progress, along);
	} else {
		float d = length(p);
		float band = (d - inner) / (1.0 - inner);
		inside = smoothstep(-0.03, 0.0, band) * (1.0 - smoothstep(0.98, 1.0, d));
		outline = (smoothstep(0.86, 0.95, d) + (1.0 - smoothstep(0.0, 0.12, band))) * inside;
		fillmask = 1.0 - smoothstep(progress - 0.02, progress, band);
	}
	float body;
	if (telegraph > 0.5) {
		body = outline * 1.2 + inside * 0.12 + fillmask * inside * 0.35;
	} else {
		float wave = 0.5 + 0.5 * sin(TIME * 4.0 - length(p) * 9.0);
		body = outline * 0.9 + inside * (0.28 + 0.12 * wave);
	}
	ALBEDO = tint.rgb * 1.5;
	ALPHA = clamp(body * alpha * tint.a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader_ground
	_mats[k] = m
	return m


func _solid_glow_mat(c: Color) -> StandardMaterial3D:
	var k := "sg_" + c.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	_mats[k] = m
	return m


func _plain_mat(c: Color, rough := 0.6) -> StandardMaterial3D:
	var k := "pl_%s_%.2f" % [c.to_html(), rough]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[k] = m
	return m


var _meshes: Dictionary = {}

func _quad_mesh() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


func _plane_mesh() -> PlaneMesh:
	if not _meshes.has("plane"):
		var q := PlaneMesh.new()
		q.size = Vector2.ONE
		_meshes["plane"] = q
	return _meshes["plane"]


func _box_mesh() -> BoxMesh:
	if not _meshes.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["box"] = b
	return _meshes["box"]


func _cyl_mesh() -> CylinderMesh:
	if not _meshes.has("cyl"):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 16
		c.rings = 1
		_meshes["cyl"] = c
	return _meshes["cyl"]


func _cone_mesh() -> CylinderMesh:
	if not _meshes.has("cone"):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 10
		c.rings = 1
		_meshes["cone"] = c
	return _meshes["cone"]


func _sphere_mesh(r: float) -> SphereMesh:
	var k := "sph_%.3f" % r
	if not _meshes.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 12
		s.rings = 6
		_meshes[k] = s
	return _meshes[k]


func _gradient(offsets: Array, alphas: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	g.colors = cols
	return g


func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c


func _basis_facing(d: Vector3) -> Basis:
	var f := Vector3(d.x, 0.0, d.z)
	if f.length_squared() < 0.0001:
		f = Vector3.FORWARD
	return Basis.looking_at(f.normalized(), Vector3.UP)


func _basis_along(dir: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, dir))
