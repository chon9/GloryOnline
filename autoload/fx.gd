extends Node
## Fx autoload (owner: VFX track) - cosmetic VFX/SFX spawning, network-replicated (ARCHITECTURE §7.3).
##
## Networking: when this peer is the host of a real (non-offline) multiplayer session, every public call
## is broadcast with @rpc("authority", "call_local") so all peers play it. Offline / no peer / client-side
## calls just play locally. Nothing here touches gameplay state (hit-stop only pauses CharacterVisual
## AnimationMixers locally, never Engine.time_scale or physics).
##
## Conventions
## - Positions are global. `dir` / `yaw` follow Godot: forward = -Z rotated by yaw about +Y.
## - Area "line" shapes start at `pos` and extend `length` metres forward along `yaw`, `width` wide.
## - Colour Color.WHITE means "use the effect's default (element) colour".
##
## Look (art bible section 5, ported from the look-dev slice LdVfx): crescent slash smears with echo arcs,
## rotating glyph circles per element, cel-banded energy with white-hot HDR cores, shockwave rings and radial
## ray bursts, painted puffy dust / cel flame tongues, flat-shaded debris with outlines, light-streak ribbons,
## impact frames and hit-stop. Recipes live in res://visuals/vfx_*.gd, shaders in res://visuals/shaders/.
##
## Performance: every one-shot piece is a pooled VfxFlash / CPUParticles3D / damage number stepped by this
## node's single _process loop; all pieces of one shader share a single material (per-effect values are
## instance uniforms). A soft budget (MAX_LIVE_NODES) drops cosmetic extras, a hard one keeps only core pieces.

## CORE checks this to decide whether to draw its own debug meshes.
var is_stub: bool = false

const Lib := preload("res://visuals/vfx_lib.gd")
const Effects := preload("res://visuals/vfx_effects.gd")
const Projectiles := preload("res://visuals/vfx_projectiles.gd")
const Ground := preload("res://visuals/vfx_ground.gd")
const HitStop := preload("res://visuals/vfx_hitstop.gd")
const DamageNumber := preload("res://visuals/vfx_numbers.gd")
const FlashNode := preload("res://visuals/vfx_flash.gd")
const Ribbon := preload("res://visuals/vfx_ribbon.gd")

const SFX_DIR := "res://assets/sfx/"
const MAX_LIVE_NODES := 260
const HARD_LIVE_NODES := 560
const MAX_VOICES := 24
const POOL_FLASH := 360
const POOL_BURST := 160
const POOL_NUMBERS := 48
const MAX_LIGHTS := 6

const EFFECT_NAMES: Array[StringName] = [&"hit_spark", &"hit_heavy", &"slash_arc", &"launch_burst", &"land_dust", &"cast_glow",
	&"heal_burst", &"buff_aura", &"debuff_puff", &"explosion", &"ice_burst", &"lightning_strike", &"fire_burst", &"holy_burst",
	&"dark_burst", &"poison_cloud", &"smoke", &"blink", &"dash_trail", &"summon_circle", &"block_spark", &"death", &"ultimate_flash"]
const PROJECTILE_VISUALS: Array[String] = ["orb", "bullet", "arrow", "grenade", "shuriken", "wave", "missile", "star", "blood", "qi",
	"dragon", "lightning", "cannonball", "flask", "scythe"]
const AREA_VISUALS: Array[String] = ["fire", "ice", "lightning", "holy", "dark", "poison", "wind", "earth", "blood", "rune", "thorn"]

## Default zone colours (bible 5.2 element mid colours).
const AREA_COLORS: Dictionary = {
	"fire": Color("#FF8A1F"), "ice": Color("#7FE8FF"), "lightning": Color("#B8F0FF"), "holy": Color("#FFD86A"),
	"dark": Color("#8A4CFF"), "poison": Color("#7CFF6B"), "wind": Color("#B8FFE0"), "earth": Color("#C08A4A"),
	"blood": Color("#E0232E"), "rune": Color("#8A4CFF"), "thorn": Color("#7CCB3A"),
}
## Default projectile colours (mid colour of each visual's palette).
const PROJ_COLORS: Dictionary = {
	"orb": Color("#8A4CFF"), "bullet": Color("#FFC43A"), "arrow": Color("#CFE6FF"), "grenade": Color("#FFC43A"),
	"shuriken": Color("#CFE6FF"), "wave": Color("#CFE6FF"), "missile": Color("#FFC43A"), "star": Color("#FFD86A"),
	"blood": Color("#E0232E"), "qi": Color("#7FC4FF"), "dragon": Color("#FF8A1F"), "lightning": Color("#B8F0FF"),
	"cannonball": Color("#FFC43A"), "flask": Color("#7CFF6B"), "scythe": Color("#8A4CFF"),
}
const NUMBER_COLORS: Dictionary = DamageNumber.COLORS

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

## Hit-stop (bible 5.3) from Fx events: hit_spark/block_spark 3 f, crit numbers 5 f, hit_heavy 8 f,
## ultimate_flash 12 f, plus explicit impact() calls. Local, cosmetic; set false to disable.
var hitstop_enabled: bool = true
## Fx events trigger hit-stop automatically (false = only explicit impact() calls do).
var auto_hitstop: bool = true
## Impact frames (screen_impact shader) on heavy hits near the camera and on ultimates.
var screen_impact_enabled: bool = true

## Emitted locally (every peer) for each impact / hit-stop event, so the local CameraRig can add shake and a FOV
## punch. level 1..4 (light / medium / heavy / ultimate), rel = REL_* of the effect's caster to the local player.
signal impact_fired(pos: Vector3, level: int, rel: int)

## --- Effect intensity by caster ownership (readability in 5v5 / raids; local prefs, never replicated) ---
## Every effect-spawning call can carry the caster's fighter uid (optional trailing `caster` argument; when 0 the
## host-side `context_caster` set by World.step is used and forwarded to clients). On each peer the effect is then
## scaled (alpha / emission / particle count / lights) by the caster's relation to the local player. Telegraphs of
## enemies (incl. bosses) always stay at full strength; damage numbers are never scaled.
const REL_UNKNOWN := -1
const REL_OWN := 0
const REL_ALLY := 1
const REL_ENEMY := 2
var own_intensity: float = 1.0
var ally_intensity: float = 0.5
var enemy_intensity: float = 0.7
## Fades effect pieces closer than `near_fade_dist` metres to the camera (caps additive overdraw / white-out).
var near_camera_fade: bool = true
var near_fade_dist: float = 2.0
## Host: uid of the fighter (or effect owner) currently being simulated; used when a call passes no caster.
var context_caster: int = 0

var _cur_k := 1.0                    # intensity of the effect being built right now
var _cur_rel := REL_UNKNOWN
var _cam_pos := Vector3.ZERO
var _cam_ok := false

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_i := 0
var _nodes: Dictionary = {}          # id -> Node3D (projectile / area visuals)
var _world: Node = null
var _warned: Dictionary = {}
var _parked: Array[Dictionary] = []  # despawned AreaVis kept briefly so a follow re-spawn can reclaim them
var _world_script: Script = null
var _world_has_instance := -1       # -1 unknown, 0 no, 1 core/world.gd has static get_instance()

var _clock := 0.0
var _flashes: Array = []            # active VfxFlash
var _flash_pool: Array = []
var _bursts: Array = []             # [CPUParticles3D, t_end, pooled]
var _burst_pool: Array = []
var _pending: Array = []            # [t_start, pos, cfg] delayed bursts
var _numbers: Array = []
var _number_pool: Array = []
var _lights: Array = []             # [OmniLight3D, t0, life, energy]
var _light_pool: Array = []
var _dying: Array = []              # detached VfxRibbon trails
var _curves: Dictionary = {}
var _ramps: Dictionary = {}
var _hitstop: VfxHitStop = HitStop.new()
var _impact_layer: CanvasLayer
var _impact_rect: ColorRect
var _impact_frame := -1
var _impact_total := 0
var _impact_lvl := 0
var _impact_last := -10.0

const AREA_PARK_MS := 150


# =============================================================================================
# Setup

func _ready() -> void:
	_ensure_voices()
	_impact_layer = CanvasLayer.new()
	_impact_layer.layer = 90
	add_child(_impact_layer)
	_impact_rect = ColorRect.new()
	_impact_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_impact_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Lib.IMPACT
	_impact_rect.material = m
	_impact_rect.visible = false
	_impact_layer.add_child(_impact_rect)
	var tree := get_tree()
	if tree and tree.has_signal(&"scene_changed"):
		tree.scene_changed.connect(clear_all)


func _process(delta: float) -> void:
	_clock += delta
	_hitstop.tick()
	_tick_impact()
	var cam0 := _camera()
	_cam_ok = cam0 != null and near_camera_fade
	if _cam_ok:
		_cam_pos = cam0.global_position
	# flashes (swap-remove)
	var i := _flashes.size() - 1
	while i >= 0:
		var f: Variant = _flashes[i]
		if not is_instance_valid(f) or (f as VfxFlash).is_queued_for_deletion():
			_flashes[i] = _flashes[_flashes.size() - 1]
			_flashes.pop_back()
		elif not (f as VfxFlash).step(delta):
			_flashes[i] = _flashes[_flashes.size() - 1]
			_flashes.pop_back()
			_retire_flash(f)
		else:
			_dim_flash(f as VfxFlash)
		i -= 1
	i = _bursts.size() - 1
	while i >= 0:
		var e: Array = _bursts[i]
		var p: Variant = e[0]
		if not is_instance_valid(p) or _clock >= float(e[1]):
			_bursts[i] = _bursts[_bursts.size() - 1]
			_bursts.pop_back()
			if is_instance_valid(p):
				_retire_burst(p, bool(e[2]))
		i -= 1
	i = _pending.size() - 1
	while i >= 0:
		var pe: Array = _pending[i]
		if _clock >= float(pe[0]):
			_pending.remove_at(i)
			var cfg: Dictionary = pe[2]
			cfg.erase("delay")
			burst(pe[1], cfg)
		i -= 1
	i = _numbers.size() - 1
	while i >= 0:
		var n: Variant = _numbers[i]
		if not is_instance_valid(n):
			_numbers.remove_at(i)
		elif not (n as VfxDamageNumber).step(delta):
			_numbers.remove_at(i)
			_retire_number(n)
		elif _cam_ok:
			# numbers spawned right at the lens would cover the screen: fade them inside ~3 m
			var nt := 1.0 - clampf((_cam_pos.distance_to((n as Node3D).global_position) - 1.0) / 2.0, 0.0, 1.0)
			if nt > 0.0 or (n as GeometryInstance3D).transparency > 0.0:
				(n as GeometryInstance3D).transparency = nt
				for c in (n as Node).get_children():
					if c is GeometryInstance3D:
						(c as GeometryInstance3D).transparency = nt
		i -= 1
	i = _lights.size() - 1
	while i >= 0:
		var le: Array = _lights[i]
		var l: Variant = le[0]
		var t := (_clock - float(le[1])) / float(le[2])
		if not is_instance_valid(l) or t >= 1.0:
			_lights.remove_at(i)
			if is_instance_valid(l):
				l.visible = false
				_light_pool.append(l)
		else:
			(l as OmniLight3D).light_energy = float(le[3]) * (1.0 - t) * (1.0 - t)
		i -= 1
	if not _dying.is_empty():
		var cam := _camera()
		i = _dying.size() - 1
		while i >= 0:
			var r: Variant = _dying[i]
			if not is_instance_valid(r) or not (r as VfxRibbon).tick(delta, cam):
				_dying.remove_at(i)
				if is_instance_valid(r):
					r.queue_free()
			i -= 1
	if _parked.is_empty():
		return
	var now := Time.get_ticks_msec()
	i = _parked.size() - 1
	while i >= 0:
		var pk: Dictionary = _parked[i]
		if now - int(pk["t"]) > AREA_PARK_MS or not is_instance_valid(pk["n"]):
			_parked.remove_at(i)
			_release(pk["n"])
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

## caster: uid of the fighter that caused the effect (0 = Fx.context_caster); scales it by ownership on each peer.
func play(name: StringName, pos: Vector3, dir := Vector3.FORWARD, color := Color.WHITE, scale := 1.0, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_play.rpc(name, pos, dir, color, scale, cu)
	else:
		_do_play(name, pos, dir, color, scale, cu)


## homing_rate: max turn rate in rad/s (pass the host Projectile.homing so the visual matches it);
## 0 keeps the legacy soft steering. Re-issuing the same id (e.g. on bounce) replaces the visual.
func spawn_projectile_visual(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid := 0, homing_rate := 0.0, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_projectile.rpc(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, cu)
	else:
		_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, cu)


func spawn_area_visual(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_area.rpc(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, cu)
	else:
		_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, cu)


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


## Impact frame + hit-stop at `pos` (the victim's centre). strength: 1 light (3 f), 2 medium (5 f),
## 3 heavy (8 f), 4 ultimate / finisher (12 f). dir = attacker -> victim (finds the attacker to freeze too).
## Cosmetic and local on every peer (never touches Engine.time_scale or the simulation).
func impact(pos: Vector3, strength := 2.0, dir := Vector3.ZERO, caster := 0) -> void:
	var cu := caster if caster != 0 else context_caster
	if _should_broadcast():
		_rpc_impact.rpc(pos, strength, dir, cu)
	else:
		_rpc_impact_local(pos, strength, dir, cu)


## Removes every live projectile/area visual and one-shot piece (call on scene change / round reset). Local only.
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
	for f in _flashes:
		if is_instance_valid(f):
			_retire_flash(f)
	_flashes.clear()
	for e in _bursts:
		if is_instance_valid(e[0]):
			_retire_burst(e[0], bool(e[2]))
	_bursts.clear()
	_pending.clear()
	for n in _numbers:
		if is_instance_valid(n):
			_retire_number(n)
	_numbers.clear()
	for le in _lights:
		if is_instance_valid(le[0]):
			(le[0] as OmniLight3D).visible = false
			_light_pool.append(le[0])
	_lights.clear()
	for r in _dying:
		if is_instance_valid(r):
			r.queue_free()
	_dying.clear()
	_hitstop.release_all()
	_impact_frame = -1
	if _impact_rect:
		_impact_rect.visible = false
	_stop_voices()


## Stops every pooled SFX voice and drops its stream, so no AudioStreamPlayback outlives the current scene.
func _stop_voices() -> void:
	for v in _voices:
		if is_instance_valid(v):
			v.stop()
			v.stream = null


## Full teardown (tests / app exit): clear_all + frees the pooled AudioStreamPlayer3D voices, the VFX pools and
## cached streams. Safe to call more than once; pools are rebuilt lazily.
func shutdown() -> void:
	clear_all()
	for v in _voices:
		if is_instance_valid(v):
			v.queue_free()
	_voices.clear()
	_voice_i = 0
	for arr in [_flash_pool, _burst_pool, _number_pool, _light_pool]:
		for n in arr:
			if is_instance_valid(n):
				(n as Node).queue_free()
		arr.clear()
	for c in get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			c.queue_free()
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
	_hitstop.release_all()


## Live cosmetic pieces (one-shot flashes, particle bursts, numbers, lights, trails, projectile/area visuals).
func live_count() -> int:
	return _flashes.size() + _bursts.size() + _pending.size() + _numbers.size() + _lights.size() + _dying.size() + _nodes.size()


## 0 = full detail, 1 = crowded (drop extras), 2 = over the hard cap (core pieces only).
func budget() -> int:
	var n := live_count()
	if n > HARD_LIVE_NODES:
		return 2
	if n > MAX_LIVE_NODES:
		return 1
	return 0


# --- RPC endpoints (host -> all peers, also run locally via call_local)

@rpc("authority", "call_local", "unreliable")
func _rpc_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float, caster: int) -> void:
	_do_play(name, pos, dir, color, scale, caster)

@rpc("authority", "call_local", "reliable")
func _rpc_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate: float, caster: int) -> void:
	_do_projectile(id, visual, from, vel, gravity, color, scale, homing_uid, homing_rate, caster)

@rpc("authority", "call_local", "reliable")
func _rpc_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster: int) -> void:
	_do_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color, caster)

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

@rpc("authority", "call_local", "unreliable")
func _rpc_impact(pos: Vector3, strength: float, dir: Vector3, caster: int) -> void:
	_rpc_impact_local(pos, strength, dir, caster)


func _rpc_impact_local(pos: Vector3, strength: float, dir: Vector3, caster: int) -> void:
	_begin_ctx(caster, false)
	_do_impact(pos, strength, dir)
	_end_ctx()


# =============================================================================================
# Named effects

func _do_play(name: StringName, pos: Vector3, dir: Vector3, color: Color, scale: float, caster := 0) -> void:
	if not is_inside_tree():
		return
	_begin_ctx(caster, false)
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var s := maxf(scale, 0.05)
	# other players' effects at reduced intensity also drop their cosmetic extras
	var bud := budget()
	if _cur_k < 0.6:
		bud = maxi(bud, 1)
	if not Effects.play(self, name, pos, d, color, s, bud):
		if not _warned.has(name):
			_warned[name] = true
			push_warning("Fx.play: unknown effect '%s' (using hit_spark)" % name)
		Effects.play(self, &"hit_spark", pos, d, color, s, bud)
		name = &"hit_spark"
	if auto_hitstop:
		match name:
			&"hit_spark", &"block_spark":
				_do_impact(pos, 1.0, d)
			&"hit_heavy":
				_do_impact(pos, 3.0, d, Lib.pal(color, "impact")[1])
			&"ultimate_flash":
				_do_impact(pos + Vector3(0, 1.0, 0), 4.0, Vector3.ZERO, Lib.pal(color, "buff")[1])
	_end_ctx()


# =============================================================================================
# Hit-stop + impact frames

func _do_impact(pos: Vector3, strength: float, dir: Vector3, tint := Color(1.0, 0.9, 0.7)) -> void:
	if not is_inside_tree():
		return
	var lvl := clampi(int(round(strength)), 1, 4)
	if hitstop_enabled:
		var frames := HitStop.frames_for(lvl)
		var cands := _hitstop_candidates()
		var victim: Node3D = null
		var best := 1.8
		for c: Node3D in cands:
			var dd := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
			if dd < best:
				best = dd
				victim = c
		if victim:
			_hitstop.freeze(victim, frames, 0.025 * lvl if lvl >= 2 and lvl < 4 else 0.0)
		var fd := Vector2(dir.x, dir.z)
		if lvl < 4 and fd.length_squared() > 0.0001:
			fd = fd.normalized()
			var attacker: Node3D = null
			var best_a := 5.0
			for c: Node3D in cands:
				if c == victim:
					continue
				var rel := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z)
				var dist := rel.length()
				if dist < best_a and dist > 0.05 and rel.normalized().dot(-fd) > 0.25:
					best_a = dist
					attacker = c
			if attacker:
				_hitstop.freeze(attacker, frames)
	if lvl >= 3 and screen_impact_enabled and _impact_frame_allowed(pos, lvl):
		_screen_impact(pos, lvl, tint)
	impact_fired.emit(pos, lvl, _cur_rel)


## Full-screen impact frames only for the local player's own hits, hits on the local player, and (dimmed)
## ultimates of others; in a 10-fighter brawl everyone else's heavy hits would strobe the screen.
func _impact_frame_allowed(pos: Vector3, lvl: int) -> bool:
	if _cur_rel == REL_OWN or _cur_rel == REL_UNKNOWN:
		return true
	var me := _local_fighter()
	if me != null and Vector2(me.global_position.x - pos.x, me.global_position.z - pos.z).length() < 1.8:
		return true
	return lvl >= 4 and _clock - _impact_last >= 1.2 and _cur_k >= 0.45


func _hitstop_candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var w := _get_world()
	if w:
		var fr := w.get_node_or_null("Fighters")
		if fr:
			for f in fr.get_children():
				var v: Variant = f.get("visual")
				if v is Node3D and is_instance_valid(v) and (v as Node3D).is_visible_in_tree():
					out.append(v)
	var tree := get_tree()
	if tree:
		for n in tree.get_nodes_in_group(&"fx_hitstop"):
			if n is Node3D and not out.has(n):
				out.append(n)
	return out


func _screen_impact(pos: Vector3, lvl: int, tint: Color) -> void:
	var cam := _camera()
	if cam == null or _impact_rect == null:
		return
	if lvl < 4 and _clock - _impact_last < 0.45:
		return
	var dist := cam.global_position.distance_to(pos)
	if dist > (14.0 if lvl < 4 else 40.0) or cam.is_position_behind(pos):
		return
	_impact_last = _clock
	var vp := get_viewport().get_visible_rect().size
	var m := _impact_rect.material as ShaderMaterial
	m.set_shader_parameter("focus", cam.unproject_position(pos) / vp)
	m.set_shader_parameter("tint", tint)
	var kk := 1.0 if (_cur_rel == REL_OWN or _cur_rel == REL_UNKNOWN) else clampf(_cur_k, 0.3, 1.0) * 0.6
	m.set_shader_parameter("flash", (0.1 if lvl < 4 else 0.35) * kk)
	m.set_shader_parameter("lines", (0.38 if lvl < 4 else 0.8) * kk)
	m.set_shader_parameter("seed", randf())
	_impact_lvl = lvl if kk >= 0.99 else mini(lvl, 3)
	_impact_frame = 0
	_impact_total = 7 if lvl < 4 else 10
	_impact_rect.visible = true
	_tick_impact_params()


func _tick_impact() -> void:
	if _impact_frame < 0:
		return
	_impact_frame += 1
	if _impact_frame >= _impact_total:
		_impact_frame = -1
		_impact_rect.visible = false
		return
	_tick_impact_params()


func _tick_impact_params() -> void:
	var m := _impact_rect.material as ShaderMaterial
	# 1-2 full impact frames (ultimates open with an inverse frame), then a quick fade
	var st := 1.0 if _impact_frame < 2 else 1.0 - float(_impact_frame - 2) / float(maxi(_impact_total - 2, 1))
	m.set_shader_parameter("strength", st)
	m.set_shader_parameter("invert", 0.85 if (_impact_lvl >= 4 and _impact_frame == 0) else 0.0)


# =============================================================================================
# Pooled building blocks (used by res://visuals/vfx_effects.gd, vfx_projectiles.gd, vfx_ground.gd)

## Acquires a pooled VfxFlash (global position `pos`), registered for stepping. parent != null makes an unpooled
## child of that node (area spikes) that is freed with it.
func flash(mesh: Mesh, mat: Material, pos: Vector3, life: float, parent: Node = null) -> VfxFlash:
	var f: VfxFlash
	if parent != null:
		f = FlashNode.new()
		parent.add_child(f)
	elif not _flash_pool.is_empty():
		f = _flash_pool.pop_back()
	else:
		f = FlashNode.new()
		f.pooled = true
		add_child(f)
	f.reset_state()
	f.mesh = mesh
	f.material_override = mat
	f.life = maxf(life, 0.01)
	f.transparency = 0.0
	if parent == null:
		f.position = pos
	f.set_instance_shader_parameter(&"fade", 1.0)
	f.visible = true
	# opaque cel solids (debris, spikes) fade by noise erosion: dimming them would only dither them, so skip
	var solid := _is_solid(mat)
	f.set_meta(&"fx_solid", solid)
	f.set_meta(&"fx_k", 1.0 if solid else _cur_k)
	f.apply(0.0)
	_dim_flash(f)
	_flashes.append(f)
	return f


## Applies the ownership intensity (meta fx_k, set at spawn) and the near-camera fade on top of the fade the
## piece computed this frame (VfxFlash.apply() rewrites it every step, so this never compounds).
func _dim_flash(f: VfxFlash) -> void:
	if bool(f.get_meta(&"fx_solid", false)):
		return
	var k := float(f.get_meta(&"fx_k", 1.0))
	if _cam_ok:
		k *= _near_fade(f.global_position)
	if k >= 0.999:
		return
	if f.uses_shader:
		var cur: Variant = f.get_instance_shader_parameter(&"fade")
		f.set_instance_shader_parameter(&"fade", (float(cur) if cur != null else 1.0) * k)
	else:
		f.transparency = 1.0 - (1.0 - f.transparency) * k


static func _is_solid(mat: Material) -> bool:
	return mat is ShaderMaterial and ((mat as ShaderMaterial).shader == Lib.SOLID or (mat as ShaderMaterial).shader == Lib.OUTLINE)


func _near_fade(p: Vector3) -> float:
	var d := _cam_pos.distance_to(p)
	if d >= near_fade_dist:
		return 1.0
	return clampf((d - 0.5) / maxf(near_fade_dist - 0.5, 0.01), 0.0, 1.0)


func _retire_flash(f: VfxFlash) -> void:
	if f.pooled and f.get_parent() == self and _flash_pool.size() < POOL_FLASH:
		f.visible = false
		f.tweens = []
		_flash_pool.append(f)
	else:
		f.queue_free()


## One-shot particle burst at `pos` (pooled CPUParticles3D). See make_particles() for the cfg keys.
func burst(pos: Vector3, cfg: Dictionary) -> CPUParticles3D:
	if not is_inside_tree():
		return null
	var dl := float(cfg.get("delay", 0.0))
	if dl > 0.0:
		var dc := cfg.duplicate()
		dc["_k"] = _cur_k
		_pending.append([_clock + dl, pos, dc])
		return null
	var p: CPUParticles3D
	if not _burst_pool.is_empty():
		p = _burst_pool.pop_back()
	else:
		p = CPUParticles3D.new()
		add_child(p)
	_configure(p, cfg)
	var bk := float(cfg.get("_k", _cur_k)) * (_near_fade(pos) if _cam_ok else 1.0)
	if bk < 0.999:
		_dim_particles(p, bk)
	p.position = pos
	p.visible = true
	p.restart()
	p.emitting = true
	_bursts.append([p, _clock + p.lifetime * (1.0 + p.lifetime_randomness) + 0.1, true])
	return p


func _retire_burst(p: CPUParticles3D, pooled: bool) -> void:
	p.emitting = false
	if pooled and p.get_parent() == self and _burst_pool.size() < POOL_BURST:
		p.visible = false
		_burst_pool.append(p)
	else:
		p.queue_free()


## New (unpooled) particle emitter. cfg keys: kind (VfxLib.K_*), pal [core, mid, accent], energy, amount,
## life, speed [min, max], dir, spread, flat, gravity, size, curve ("shrink" | "grow" | "pop"), ramp ("fade" |
## "pop" | "late"), damp, align (streak along velocity), quad (Vector2 quad size), upright (no random
## rotation), tangent, radial, shape ("point" | "sphere" | "ring" | "box") + radius / inner / box, explosive,
## one_shot, color (per-particle tint multiplier).
func make_particles(cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_configure(p, cfg)
	return p


func _configure(p: CPUParticles3D, cfg: Dictionary) -> void:
	var kind := int(cfg.get("kind", Lib.K_SPARK))
	var align := bool(cfg.get("align", false))
	var bb := int(cfg.get("bb", 1 if align else 0))
	var q: Vector2 = cfg.get("quad", Vector2.ONE)
	p.mesh = Lib.particle_quad(kind, bb, q.x, q.y)
	var amt := maxi(1, int(cfg.get("amount", 10)))
	if p.amount != amt:
		p.amount = amt
	p.lifetime = maxf(float(cfg.get("life", 0.5)), 0.02)
	p.one_shot = bool(cfg.get("one_shot", true))
	p.explosiveness = float(cfg.get("explosive", 1.0 if p.one_shot else 0.0))
	p.randomness = 0.5
	p.lifetime_randomness = 0.25
	p.local_coords = false
	var sp: Array = cfg.get("speed", [2.0, 4.0])
	p.initial_velocity_min = sp[0]
	p.initial_velocity_max = sp[1]
	var dir: Vector3 = cfg.get("dir", Vector3.UP)
	p.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	p.spread = float(cfg.get("spread", 45.0))
	p.flatness = float(cfg.get("flat", 0.0))
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	var size := float(cfg.get("size", 0.4))
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = _curve_named(String(cfg.get("curve", "")))
	p.color = cfg.get("color", Color.WHITE)
	p.color_ramp = _ramp_named(String(cfg.get("ramp", "pop" if cfg.get("curve", "") == "pop" else "fade")))
	var dmp := float(cfg.get("damp", 0.0))
	p.damping_min = dmp
	p.damping_max = dmp * 1.3
	if bool(cfg.get("upright", false)) or align:
		p.angle_min = 0.0
		p.angle_max = 0.0
	else:
		p.angle_min = 0.0
		p.angle_max = 360.0
	var tg := float(cfg.get("tangent", 0.0))
	p.tangential_accel_min = tg
	p.tangential_accel_max = tg * 1.4
	var rd := float(cfg.get("radial", 0.0))
	p.radial_accel_min = rd
	p.radial_accel_max = rd * 1.3
	p.particle_flag_align_y = align
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	match String(cfg.get("shape", "point")):
		"sphere":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = float(cfg.get("radius", 0.5))
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_height = 0.05
			p.emission_ring_radius = maxf(float(cfg.get("radius", 1.0)), 0.01)
			p.emission_ring_inner_radius = float(cfg.get("inner", 0.0))
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = cfg.get("box", Vector3.ONE * 0.5)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pal: Array = cfg.get("pal", Lib.PAL["phys"])
	Lib.set_pal(p, pal)
	p.set_instance_shader_parameter(&"energy", float(cfg.get("energy", 2.5)))
	p.set_instance_shader_parameter(&"fade", 1.0)
	p.set_instance_shader_parameter(&"progress", 0.0)
	p.set_instance_shader_parameter(&"seed", randf() * 10.0)


func _curve_named(n: String) -> Curve:
	if n == "":
		return null
	if _curves.has(n):
		return _curves[n]
	var pts: Array = {"shrink": [Vector2(0, 1), Vector2(1, 0.15)], "grow": [Vector2(0, 0.45), Vector2(1, 1.0)],
		"pop": [Vector2(0, 0.2), Vector2(0.2, 1.0), Vector2(1, 0.6)]}.get(n, [Vector2(0, 1), Vector2(1, 1)])
	var c := Curve.new()
	for pt: Vector2 in pts:
		c.add_point(pt)
	_curves[n] = c
	return c


func _ramp_named(n: String) -> Gradient:
	if _ramps.has(n):
		return _ramps[n]
	var spec: Array = {"fade": [[0.0, 0.6, 1.0], [1.0, 1.0, 0.0]], "pop": [[0.0, 0.12, 0.65, 1.0], [0.0, 1.0, 1.0, 0.0]],
		"late": [[0.0, 0.8, 1.0], [1.0, 1.0, 0.0]]}.get(n, [[0.0, 1.0], [1.0, 0.0]])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(spec[0])
	var cols := PackedColorArray()
	for a: float in spec[1]:
		cols.append(Color(1, 1, 1, a))
	g.colors = cols
	_ramps[n] = g
	return g


## Short-lived pooled point light (explosions, lightning, ultimates); at most MAX_LIGHTS at once.
func light(pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	if _lights.size() >= MAX_LIGHTS or budget() > 0 or _cur_k < 0.6:
		return
	energy *= _cur_k * _cur_k
	var l: OmniLight3D
	if not _light_pool.is_empty():
		l = _light_pool.pop_back()
	else:
		l = OmniLight3D.new()
		l.shadow_enabled = false
		add_child(l)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.visible = true
	_lights.append([l, _clock, maxf(life, 0.05), energy])


## Ground height under `pos` (ray down up to max_drop). Without a hit: pos.y - 0.9 for centre-height positions
## (max_drop >= 1) or pos.y for feet positions (max_drop < 1).
func ground_y(pos: Vector3, max_drop := 2.5) -> float:
	var fallback := pos.y - (0.9 if max_drop >= 1.0 else 0.0)
	var vp := get_viewport()
	if vp == null:
		return fallback
	var w3 := vp.find_world_3d()
	if w3 == null:
		return fallback
	var space := w3.direct_space_state
	if space == null:
		return fallback
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.1, 0), pos - Vector3(0, max_drop, 0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return float((hit["position"] as Vector3).y)


func _camera() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp else null


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
	var ribbon: VfxRibbon
	var segments: Array[Node3D] = []
	var history: Array[Vector3] = []
	var flicker: Node3D
	var _target: WeakRef
	var _flick_base := Vector3.ONE

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
			if _flick_base == Vector3.ONE:
				_flick_base = flicker.scale
			flicker.scale = _flick_base * randf_range(0.75, 1.25)
		if ribbon:
			ribbon.push(global_position)
			ribbon.tick(delta, get_viewport().get_camera_3d())
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


func _do_projectile(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid: int, homing_rate := 0.0, caster := 0) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	_begin_ctx(caster, false)
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
	if not visual in PROJECTILE_VISUALS and not _warned.has("proj_" + visual):
		_warned["proj_" + visual] = true
		push_warning("Fx.spawn_projectile_visual: unknown visual '%s' (using orb)" % visual)
	Projectiles.build(self, p, body, visual if visual in PROJECTILE_VISUALS else "orb", color, s)
	if _cur_k < 0.999:
		_dim_tree(p, _cur_k)
	_end_ctx()
	add_child(p)
	p.global_position = from
	for seg in p.segments:
		seg.global_position = from
	if p.ribbon:
		p.ribbon.global_transform = Transform3D.IDENTITY
		p.ribbon.push(from)
	if vel.length_squared() > 0.0001:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
		p.look_at(from + vel, up)
	_nodes[id] = p


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
	var decals: Array = []          # glyph circles fading with the zone
	var reclaimed := 0             # times this visual was re-used by a follow re-spawn
	var caster := 0                # fighter uid that owns the area (ownership intensity)
	var k := 1.0                   # zone intensity (Fx ownership scaling)
	var tk := 1.0                  # telegraph intensity (enemy telegraphs stay 1.0)

	func _process(delta: float) -> void:
		age += delta
		if telegraph and not started:
			var prog := clampf(age / maxf(delay, 0.001), 0.0, 1.0)
			telegraph.set_instance_shader_parameter(&"progress", prog)
			# pulses faster as the impact approaches
			telegraph.set_instance_shader_parameter(&"alpha", (0.78 + 0.22 * sin(age * lerpf(10.0, 26.0, prog))) * tk)
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
				zone.set_instance_shader_parameter(&"alpha", a * (0.85 + 0.15 * sin(age * 5.0)) * k)
				for dcl in decals:
					if is_instance_valid(dcl):
						(dcl as GeometryInstance3D).set_instance_shader_parameter(&"fade", a * k)
			if remain <= 0.0:
				fx.call("_do_despawn_node", self)

	func line_center() -> Vector3:
		return Vector3(0, 0, -length * 0.5) if shape == "line" else Vector3.ZERO


func _do_area(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color, caster := 0) -> void:
	if not is_inside_tree():
		return
	_do_despawn(id)
	if _reclaim_area(id, visual, shape, pos, yaw, radius, length, width, delay, duration, color):
		return
	_begin_ctx(caster, false)
	var zk := _cur_k
	_end_ctx()
	_begin_ctx(caster, true)
	var tkk := _cur_k
	_end_ctx()
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
	a.caster = caster
	a.k = zk
	a.tk = tkk
	add_child(a)
	a.global_position = pos + Vector3(0, 0.04, 0)
	a.rotation.y = yaw
	if a.delay > 0.0:
		# warning colour: the element pushed toward hot red-orange so it always reads as danger
		var tc := a.color.lerp(Color(1.0, 0.22, 0.12), 0.65)
		a.telegraph = Ground.shape_mesh(a, tc, 1.0, true)
	_nodes[id] = a


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


func _area_start(a: AreaVis) -> void:
	_cur_k = a.k
	a.zone = Ground.shape_mesh(a, a.color, 0.0, false)
	Ground.start(self, a)
	if a.k < 0.999:
		for e in a.emitters:
			if is_instance_valid(e):
				_dim_particles(e, a.k)
	_cur_k = 1.0


## Periodic accents while a zone is active (lightning strikes, ember bursts...).
func _area_tick(a: AreaVis) -> void:
	_cur_k = a.k
	Ground.tick(self, a)
	_cur_k = 1.0


# =============================================================================================
# Ownership intensity

func _begin_ctx(caster: int, telegraph: bool) -> void:
	_cur_rel = _rel_of(caster)
	_cur_k = intensity_for(_cur_rel, telegraph)


func _end_ctx() -> void:
	_cur_k = 1.0
	_cur_rel = REL_UNKNOWN


## Intensity multiplier for an effect whose caster has relation `rel` (REL_*) to the local player.
func intensity_for(rel: int, telegraph := false) -> float:
	match rel:
		REL_OWN:
			return clampf(own_intensity, 0.0, 1.0)
		REL_ALLY:
			return maxf(clampf(ally_intensity, 0.0, 1.0), 0.6) if telegraph else clampf(ally_intensity, 0.0, 1.0)
		REL_ENEMY:
			return 1.0 if telegraph else clampf(enemy_intensity, 0.0, 1.0)
	return 1.0


func _local_fighter() -> Node3D:
	var w := _get_world()
	if w == null or not w.has_method("local_fighter"):
		return null
	var f: Variant = w.call("local_fighter")
	return f as Node3D if f is Node3D and is_instance_valid(f) else null


## Relation of fighter `uid` (summons resolve to their owner) to the local player.
func _rel_of(uid: int) -> int:
	if uid <= 0:
		return REL_UNKNOWN
	var f := _find_fighter(uid)
	if f == null:
		return REL_UNKNOWN
	if str(f.get("kind")) == "summon" and f.has_method("get_owner_fighter"):
		var o: Variant = f.call("get_owner_fighter")
		if o is Node3D and is_instance_valid(o):
			f = o
	var me := _local_fighter()
	if me == null:
		return REL_ENEMY   # spectator without a fighter: every effect is "someone else's"
	if f == me:
		return REL_OWN
	return REL_ALLY if f.get("team") == me.get("team") else REL_ENEMY


func _dim_particles(p: CPUParticles3D, k: float) -> void:
	var c := p.color
	c.a *= k
	p.color = c
	var amt := maxi(1, int(round(float(p.amount) * lerpf(0.45, 1.0, k))))
	if amt != p.amount:
		p.amount = amt
	var e: Variant = p.get_instance_shader_parameter(&"energy")
	if e != null:
		p.set_instance_shader_parameter(&"energy", float(e) * lerpf(0.6, 1.0, k))


## Dims a freshly built projectile visual (particles + mesh `fade`; pooled VfxFlash pieces are handled by meta).
func _dim_tree(n: Node, k: float) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		if c is CPUParticles3D:
			_dim_particles(c, k)
		elif c is VfxFlash:
			continue
		else:
			var gi := c as GeometryInstance3D
			if _is_solid(gi.material_override):
				continue
			var cur: Variant = gi.get_instance_shader_parameter(&"fade")
			if cur != null:
				gi.set_instance_shader_parameter(&"fade", float(cur) * k)
			elif gi.material_override is ShaderMaterial:
				gi.set_instance_shader_parameter(&"fade", k)


func _random_point_in(a: Node3D) -> Vector3:
	var local := Vector3.ZERO
	var shape: String = a.get("shape")
	var radius := float(a.get("radius"))
	if shape == "line":
		var w := float(a.get("width"))
		local = Vector3(randf_range(-w, w) * 0.5, 0, -randf() * float(a.get("length")))
	elif shape == "ring":
		var ang := randf() * TAU
		var r := randf_range(radius * 0.6, radius)
		local = Vector3(cos(ang) * r, 0, sin(ang) * r)
	else:
		var ang2 := randf() * TAU
		var r2 := sqrt(randf()) * radius * 0.9
		local = Vector3(cos(ang2) * r2, 0, sin(ang2) * r2)
	return a.global_transform * local


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


## Frees a projectile/area visual, handing looping particle emitters and ribbon trails to Fx so they finish
## instead of popping.
func _release(n: Node) -> void:
	if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	for e in n.find_children("*", "CPUParticles3D", true, false):
		var cp := e as CPUParticles3D
		if cp.one_shot:
			continue
		var gp := cp.global_transform
		cp.get_parent().remove_child(cp)
		add_child(cp)
		cp.global_transform = gp
		cp.emitting = false
		_bursts.append([cp, _clock + cp.lifetime + 0.2, false])
	for r in n.find_children("*", "MeshInstance3D", true, false):
		if r is VfxRibbon:
			var rb := r as VfxRibbon
			rb.get_parent().remove_child(rb)
			add_child(rb)
			rb.global_transform = Transform3D.IDENTITY
			rb.detach()
			_dying.append(rb)
	n.queue_free()


# =============================================================================================
# Damage numbers + SFX

func _do_number(pos: Vector3, amount: float, kind: StringName) -> void:
	if not is_inside_tree():
		return
	var l: VfxDamageNumber
	if not _number_pool.is_empty():
		l = _number_pool.pop_back()
	else:
		l = DamageNumber.new()
		add_child(l)
	l.setup(kind, amount, Lib.number_font("num"), Lib.number_font("tag"))
	l.visible = true
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.2, randf_range(-0.25, 0.25))
	_numbers.append(l)
	if kind == &"crit" and auto_hitstop:
		_do_impact(pos - Vector3(0, 0.9, 0), 2.0, Vector3.ZERO)


func _retire_number(n: VfxDamageNumber) -> void:
	if n.get_parent() == self and _number_pool.size() < POOL_NUMBERS:
		n.visible = false
		_number_pool.append(n)
	else:
		n.queue_free()


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
# World lookup

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


func _c(c: Color, default: Color) -> Color:
	return default if c == Color.WHITE else c
