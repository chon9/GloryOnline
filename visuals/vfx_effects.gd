class_name VfxEffects
extends RefCounted
## Named one-shot effects for Fx.play (ARCHITECTURE §7.3), rebuilt in the anime style of the look-dev slice
## (bible section 5): crescent smears with echo arcs, rotating glyph circles per element, cel-banded energy
## with white-hot HDR cores, shockwave rings and radial ray bursts, painted puffy dust and cel flame tongues,
## flat-shaded debris with outlines. Every piece is a pooled VfxFlash or a pooled CPUParticles3D owned by Fx.
## `fx` is the Fx autoload (flash / burst / light / ground_y / impact helpers).

const Lib := preload("res://visuals/vfx_lib.gd")

## Default palette per effect (Color.WHITE from the caller = this one).
const DEFAULT_PAL: Dictionary = {
	&"hit_spark": "phys", &"hit_heavy": "impact", &"slash_arc": "phys", &"launch_burst": "phys", &"land_dust": "dust",
	&"cast_glow": "arcane", &"heal_burst": "heal", &"buff_aura": "buff", &"debuff_puff": "dark", &"explosion": "gun",
	&"ice_burst": "ice", &"lightning_strike": "lightning", &"fire_burst": "fire", &"holy_burst": "holy",
	&"dark_burst": "dark", &"poison_cloud": "poison", &"smoke": "smoke", &"blink": "arcane", &"dash_trail": "phys",
	&"summon_circle": "arcane", &"block_spark": "phys", &"death": "frost", &"ultimate_flash": "buff",
}


## Builds effect `name`. budget: 0 = full, 1 = crowded (drop extras), 2 = over the hard cap (core piece only).
## Returns false for an unknown name.
static func play(fx: Node, name: StringName, pos: Vector3, d: Vector3, color: Color, s: float, budget: int) -> bool:
	if not DEFAULT_PAL.has(name):
		return false
	var pal: Array = Lib.pal(color, DEFAULT_PAL[name])
	var full := budget == 0
	var core_only := budget >= 2
	match name:
		&"hit_spark":
			_star(fx, pos, pal, 0.13, 0.35 * s, 1.25 * s, 3.2)
			if not core_only:
				_ray_burst(fx, pos, pal, 0.14, 1.7 * s, 0.25, 0.8, 1.4)
				fx.burst(pos, {"kind": Lib.K_STREAK, "amount": 8, "life": 0.2, "speed": [6.0, 11.0], "dir": d, "spread": 70.0,
					"size": 0.42 * s, "pal": pal, "energy": 3.0, "align": true, "quad": Vector2(0.18, 1.0), "curve": "shrink"})
		&"hit_heavy":
			_glow(fx, pos, pal, 0.07, 0.8 * s, 0.35 * s, 3.0)
			_star(fx, pos, pal, 0.17, 0.6 * s, 2.4 * s, 3.4)
			if not core_only:
				_ray_burst(fx, pos, pal, 0.2, 3.4 * s, 0.2, 0.95, 2.4)
				_shock_ring(fx, pos, d, pal, 0.24, 2.6 * s)
				fx.burst(pos, {"kind": Lib.K_STREAK, "amount": 16 if full else 8, "life": 0.28, "speed": [8.0, 15.0], "dir": d, "spread": 85.0,
					"size": 0.6 * s, "pal": pal, "energy": 3.5, "align": true, "quad": Vector2(0.16, 1.0), "curve": "shrink", "damp": 3.0})
			if full:
				fx.burst(pos, {"kind": Lib.K_MOTE, "amount": 6, "life": 0.45, "speed": [2.0, 5.0], "dir": d, "spread": 120.0,
					"size": 0.22 * s, "pal": pal, "energy": 3.0, "curve": "shrink", "damp": 4.0})
		&"slash_arc":
			_slash(fx, pos, d, pal, s, budget)
		&"launch_burst":
			var gy: float = fx.ground_y(pos)
			var g := Vector3(pos.x, gy, pos.z)
			_ground_ring(fx, g, pal, 0.32, 3.2 * s, 0.15, 0.95, 0.16, 0.0, 0.0)
			_column(fx, g, pal, 0.3, 0.22 * s, 4.2 * s)
			if not core_only:
				fx.burst(g + Vector3(0, 0.2, 0), {"kind": Lib.K_STREAK, "amount": 12 if full else 6, "life": 0.35, "speed": [10.0, 16.0],
					"dir": Vector3.UP, "spread": 10.0, "shape": "ring", "radius": 0.55 * s, "size": 0.9 * s, "pal": pal, "energy": 3.0,
					"align": true, "quad": Vector2(0.14, 1.0), "curve": "shrink"})
				_dust(fx, g, Lib.PAL["dust"], 6 if full else 3, s * 0.8)
		&"land_dust":
			var gy: float = fx.ground_y(pos, 0.6)
			var g := Vector3(pos.x, gy, pos.z)
			_dust(fx, g, pal, 9 if full else 4, s)
			if not core_only:
				_crack(fx, g, 0.9, 2.2 * s)
				_ground_ring(fx, g, Lib.PAL["dust"], 0.3, 2.4 * s, 0.2, 0.9, 0.08, 0.0, 0.0, 1.4)
		&"cast_glow":
			var gy: float = fx.ground_y(pos)
			var g := Vector3(pos.x, gy, pos.z)
			_glyph_ground(fx, g, pal, _style_for(pal, Lib.G_ARCANE), 0.75, 2.6 * s, 0.6, 0.18)
			if not core_only:
				# anticipation: motes converge on the caster, then a small vertical glyph flash in front
				fx.burst(g + Vector3(0, 0.15, 0), {"kind": Lib.K_MOTE, "amount": 12 if full else 6, "life": 0.5, "speed": [0.8, 2.2],
					"dir": Vector3.UP, "spread": 12.0, "shape": "ring", "radius": 1.2 * s, "size": 0.2 * s, "pal": pal, "energy": 3.0,
					"gravity": Vector3(0, 2.5, 0), "radial": -2.2, "curve": "pop"})
				var front := pos + d * 0.55
				_glyph_flat(fx, front, Basis.looking_at(-d, Vector3.UP), pal, _style_for(pal, Lib.G_ARCANE), 0.45, 1.4 * s, 0.08)
		&"heal_burst":
			var gy: float = fx.ground_y(pos, 0.6)
			var g := Vector3(pos.x, gy, pos.z)
			_glyph_ground(fx, g, pal, Lib.G_HOLY, 0.9, 2.4 * s, 0.9, 0.15)
			_column(fx, g, pal, 0.55, 0.36 * s, 3.2 * s)
			if not core_only:
				fx.burst(g + Vector3(0, 0.3, 0), {"kind": Lib.K_PLUS, "amount": 10 if full else 5, "life": 1.0, "speed": [1.0, 2.2],
					"dir": Vector3.UP, "spread": 18.0, "shape": "ring", "radius": 0.65 * s, "size": 0.3 * s, "pal": pal, "energy": 2.6,
					"gravity": Vector3(0, 1.2, 0), "curve": "pop", "upright": true})
				_ground_ring(fx, g, pal, 0.45, 2.8 * s, 0.25, 0.95, 0.1, 0.0, 0.0)
		&"buff_aura":
			var gy: float = fx.ground_y(pos, 0.6)
			var g := Vector3(pos.x, gy, pos.z)
			_glyph_ground(fx, g, pal, _style_for(pal, Lib.G_HOLY), 0.8, 2.2 * s, -1.0, 0.12)
			_ground_ring(fx, g, pal, 0.4, 2.6 * s, 0.25, 0.95, 0.12, 0.0, 0.0)
			if not core_only:
				fx.burst(g + Vector3(0, 0.1, 0), {"kind": Lib.K_STREAK, "amount": 14 if full else 7, "life": 0.7, "speed": [2.5, 4.5],
					"dir": Vector3.UP, "spread": 4.0, "shape": "ring", "radius": 0.75 * s, "size": 0.75 * s, "pal": pal, "energy": 2.8,
					"align": true, "quad": Vector2(0.12, 1.0), "curve": "pop"})
				# rising halo ring
				var h := _ground_ring(fx, g + Vector3(0, 0.1, 0), pal, 0.6, 1.9 * s, 0.85, 0.85, 0.1, 0.0, 0.0)
				h.vel = Vector3(0, 3.2, 0)
				h.damp = 2.0
		&"debuff_puff":
			var top := pos + Vector3(0, 0.55, 0)
			_glyph_flat(fx, top + Vector3(0, 0.25, 0), Basis.IDENTITY, pal, Lib.G_DARK, 0.6, 1.3 * s, 0.1, -1.5)
			fx.burst(top, {"kind": Lib.K_PUFF, "amount": 7 if full else 3, "life": 0.85, "speed": [0.4, 1.4], "spread": 180.0,
				"size": 0.55 * s, "pal": Lib.PAL["darksmoke"] if color == Color.WHITE else [pal[1], pal[2], pal[2].darkened(0.5)],
				"energy": 1.0, "gravity": Vector3(0, -1.6, 0), "curve": "grow", "ramp": "late"})
			if not core_only:
				fx.burst(top, {"kind": Lib.K_SPARK, "amount": 7, "life": 0.55, "speed": [1.0, 2.2], "spread": 180.0, "size": 0.26 * s,
					"pal": pal, "energy": 3.0, "gravity": Vector3(0, -3.0, 0), "curve": "shrink"})
		&"explosion":
			_explosion(fx, pos, pal, s, budget)
		&"ice_burst":
			_star(fx, pos, Lib.PAL["ice"] if color == Color.WHITE else pal, 0.16, 0.6 * s, 2.2 * s, 3.2)
			_ray_burst(fx, pos, pal, 0.18, 3.0 * s, 0.2, 0.9, 1.8)
			_ice_shards(fx, pos, pal, s, 8 if full else (4 if not core_only else 2))
			if not core_only:
				fx.burst(pos, {"kind": Lib.K_SHARD, "amount": 12 if full else 6, "life": 0.45, "speed": [5.0, 10.0], "spread": 180.0,
					"size": 0.35 * s, "pal": pal, "energy": 2.6, "align": true, "quad": Vector2(0.5, 1.0), "gravity": Vector3(0, -9, 0), "curve": "shrink"})
				fx.burst(pos, {"kind": Lib.K_PUFF, "amount": 5 if full else 2, "life": 0.7, "speed": [0.8, 2.0], "spread": 180.0,
					"size": 0.8 * s, "pal": Lib.PAL["frost"], "energy": 1.2, "curve": "grow", "damp": 3.0, "ramp": "late"})
		&"lightning_strike":
			_lightning(fx, pos, pal, s, budget)
		&"fire_burst":
			var gy: float = fx.ground_y(pos)
			var g := Vector3(pos.x, minf(gy, pos.y), pos.z)
			_glow(fx, g + Vector3(0, 0.6 * s, 0), pal, 0.22, 1.2 * s, 2.4 * s, 3.0)
			_ground_ring(fx, g, pal, 0.35, 3.0 * s, 0.2, 0.95, 0.18, 0.0, 0.0)
			fx.burst(g + Vector3(0, 0.1, 0), {"kind": Lib.K_FLAME, "amount": 14 if full else 6, "life": 0.6, "speed": [1.5, 4.5],
				"dir": Vector3.UP, "spread": 40.0, "shape": "sphere", "radius": 0.5 * s, "size": 1.0 * s, "pal": pal, "energy": 2.6,
				"gravity": Vector3(0, 3.0, 0), "curve": "shrink", "damp": 2.0, "upright": true})
			if full:
				fx.burst(g + Vector3(0, 0.4, 0), {"kind": Lib.K_MOTE, "amount": 10, "life": 0.9, "speed": [3.0, 7.0], "dir": Vector3.UP,
					"spread": 55.0, "size": 0.16 * s, "pal": pal, "energy": 3.5, "gravity": Vector3(0, -4.0, 0)})
				fx.burst(g + Vector3(0, 1.0, 0), {"kind": Lib.K_PUFF, "amount": 4, "life": 1.0, "speed": [0.8, 1.6], "dir": Vector3.UP,
					"spread": 40.0, "size": 0.9 * s, "pal": Lib.PAL["firesmoke"], "energy": 1.0, "curve": "grow", "ramp": "late"})
		&"holy_burst":
			var gy: float = fx.ground_y(pos, 0.6)
			var g := Vector3(pos.x, gy, pos.z)
			_column(fx, g, pal, 0.6, 0.45 * s, 7.0)
			_glyph_ground(fx, g, pal, Lib.G_HOLY, 0.8, 3.0 * s, 0.7, 0.12)
			if not core_only:
				_ground_ring(fx, g, pal, 0.45, 3.4 * s, 0.2, 0.95, 0.14, 1.2, 0.0)
				fx.burst(g + Vector3(0, 0.2, 0), {"kind": Lib.K_MOTE, "amount": 14 if full else 6, "life": 0.9, "speed": [1.5, 4.0],
					"dir": Vector3.UP, "spread": 22.0, "shape": "ring", "radius": 0.8 * s, "size": 0.28 * s, "pal": pal, "energy": 3.2, "curve": "pop"})
		&"dark_burst":
			# implosion: a violet ring collapses inward, dark puffs, inward streaks, then a burst
			var r := _ground_ring_bb(fx, pos, pal, 0.32, 3.6 * s, 0.95, 0.15, 0.2)
			r.scale_exp = 1.0
			_glyph_flat(fx, pos, Basis(Vector3.RIGHT, -PI / 2), pal, Lib.G_DARK, 0.5, 2.6 * s, 0.1, -2.5, true)
			_star(fx, pos, pal, 0.2, 0.3 * s, 1.8 * s, 3.5, 0.16)
			if not core_only:
				fx.burst(pos, {"kind": Lib.K_STREAK, "amount": 14 if full else 6, "life": 0.3, "speed": [-7.0, -4.0], "spread": 180.0,
					"shape": "sphere", "radius": 1.9 * s, "size": 0.55 * s, "pal": pal, "energy": 3.0, "align": true,
					"quad": Vector2(0.14, 1.0), "curve": "shrink"})
				fx.burst(pos, {"kind": Lib.K_PUFF, "amount": 6 if full else 3, "life": 0.9, "speed": [0.6, 1.6], "spread": 180.0,
					"size": 0.9 * s, "pal": Lib.PAL["darksmoke"], "energy": 1.0, "curve": "grow", "ramp": "late", "delay": 0.2})
		&"poison_cloud":
			fx.burst(pos + Vector3(0, 0.4, 0), {"kind": Lib.K_PUFF, "amount": 10 if full else 5, "life": 1.6, "speed": [0.3, 0.9],
				"spread": 180.0, "shape": "sphere", "radius": 0.9 * s, "size": 1.1 * s, "pal": [pal[0], pal[1], pal[2]] if color != Color.WHITE else Lib.PAL["poisonsmoke"],
				"energy": 1.0, "curve": "grow", "explosive": 0.6, "ramp": "pop", "flat": 0.4})
			if not core_only:
				fx.burst(pos + Vector3(0, 0.2, 0), {"kind": Lib.K_BUBBLE, "amount": 9, "life": 1.2, "speed": [0.5, 1.5], "dir": Vector3.UP,
					"spread": 30.0, "shape": "sphere", "radius": 0.8 * s, "size": 0.22 * s, "pal": pal, "energy": 2.4, "curve": "pop"})
		&"smoke":
			fx.burst(pos + Vector3(0, 0.5, 0), {"kind": Lib.K_PUFF, "amount": 11 if full else 5, "life": 1.2, "speed": [1.0, 2.4],
				"spread": 180.0, "shape": "sphere", "radius": 0.5 * s, "size": 0.95 * s, "pal": pal, "energy": 1.0, "curve": "grow",
				"damp": 2.2, "flat": 0.5, "ramp": "late"})
		&"blink":
			var c0 := pos + Vector3(0, 0.1, 0)
			var slit: VfxFlash = _energy_mesh(fx, Lib.cylinder(), c0, pal, 0.24, 4.0)
			slit.s0 = Vector3(0.9, 2.4, 0.9) * s
			slit.s1 = Vector3(0.02, 2.9, 0.02) * s
			slit.scale_exp = 0.5
			slit.set_instance_shader_parameter(&"vfade", 0.3)
			_star(fx, c0, pal, 0.18, 2.0 * s, 0.2 * s, 4.0)
			if not core_only:
				var gy: float = fx.ground_y(pos)
				_glyph_ground(fx, Vector3(pos.x, gy, pos.z), pal, _style_for(pal, Lib.G_ARCANE), 0.4, 1.8 * s, 2.0, 0.06)
				fx.burst(c0, {"kind": Lib.K_MOTE, "amount": 12 if full else 5, "life": 0.4, "speed": [2.0, 5.0], "spread": 180.0,
					"size": 0.2 * s, "pal": pal, "energy": 3.0, "curve": "shrink"})
		&"dash_trail":
			_dash(fx, pos, d, pal, s, budget)
		&"summon_circle":
			var gy: float = fx.ground_y(pos)
			var g := Vector3(pos.x, minf(gy, pos.y), pos.z)
			_glyph_ground(fx, g, pal, _style_for(pal, Lib.G_ARCANE), 1.3, 3.0 * s, 1.0, 0.3)
			_column(fx, g, pal, 0.8, 0.4 * s, 3.4)
			if not core_only:
				var inner := _glyph_flat(fx, g + Vector3(0, 0.7, 0), Basis.IDENTITY, pal, Lib.G_ARCANE, 1.0, 1.6 * s, 0.25, -1.4)
				inner.vel = Vector3(0, 1.2, 0)
				fx.burst(g, {"kind": Lib.K_MOTE, "amount": 16 if full else 8, "life": 1.0, "speed": [1.0, 3.5], "dir": Vector3.UP, "spread": 8.0,
					"shape": "ring", "radius": 1.25 * s, "size": 0.24 * s, "pal": pal, "energy": 3.0, "curve": "pop"})
		&"block_spark":
			var ward := _billboard(fx, Lib.K_HEX, pos, pal, 0.22, 1.5 * s, 1.9 * s, 1.7)
			ward.fade_tail = 0.6
			_star(fx, pos, pal, 0.12, 0.5 * s, 1.5 * s, 3.0)
			if not core_only:
				fx.burst(pos, {"kind": Lib.K_STREAK, "amount": 12 if full else 6, "life": 0.3, "speed": [5.0, 9.0], "dir": -d, "spread": 75.0,
					"size": 0.32 * s, "pal": Lib.PAL["gun"] if color == Color.WHITE else pal, "energy": 3.5, "align": true,
					"quad": Vector2(0.16, 1.0), "gravity": Vector3(0, -12, 0), "curve": "shrink"})
		&"death":
			var gy: float = fx.ground_y(pos, 0.6)
			var g := Vector3(pos.x, gy, pos.z)
			fx.burst(g + Vector3(0, 0.5, 0), {"kind": Lib.K_PUFF, "amount": 8 if full else 4, "life": 1.0, "speed": [1.0, 2.4], "spread": 180.0,
				"flat": 0.7, "size": 0.95 * s, "pal": Lib.PAL["smoke"], "energy": 1.0, "curve": "grow", "damp": 2.0, "ramp": "late"})
			if not core_only:
				fx.burst(g + Vector3(0, 0.8, 0), {"kind": Lib.K_FLAME, "amount": 4, "life": 1.4, "speed": [1.2, 2.2], "dir": Vector3.UP,
					"spread": 14.0, "size": 0.6 * s, "pal": pal, "energy": 2.2, "curve": "shrink", "upright": true})
				_ground_ring(fx, g, pal, 0.6, 2.6 * s, 0.2, 0.95, 0.1, 0.0, 0.0)
		&"ultimate_flash":
			_ultimate(fx, pos, d, pal, s, budget)
	return true


# ------------------------------------------------------------------ composite pieces

static func _style_for(pal: Array, fallback: int) -> int:
	var c: Color = pal[1]
	var h := c.h
	if c.s < 0.25:
		return fallback
	if h < 0.1 or h > 0.93:
		return Lib.G_FIRE
	if h < 0.2:
		return Lib.G_HOLY
	if h < 0.42:
		return Lib.G_NATURE
	if h < 0.56:
		return Lib.G_ICE
	if h < 0.68:
		return Lib.G_QI
	return fallback


static func _billboard(fx: Node, kind: int, pos: Vector3, pal: Array, life: float, size0: float, size1: float, energy := 2.5) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.quad(), Lib.sprite_mat(kind, 0), pos, life)
	Lib.set_pal(f, pal)
	f.set_instance_shader_parameter(&"energy", energy)
	f.set_instance_shader_parameter(&"progress", 0.0)
	f.set_instance_shader_parameter(&"seed", randf() * 10.0)
	f.s0 = Vector3.ONE * size0
	f.s1 = Vector3.ONE * size1
	return f


static func _star(fx: Node, pos: Vector3, pal: Array, life: float, size0: float, size1: float, energy: float, delay := 0.0) -> VfxFlash:
	var f := _billboard(fx, Lib.K_SPARK, pos, pal, life, size0, size1, energy)
	f.delay = delay
	f.fade_tail = 0.5
	return f


static func _glow(fx: Node, pos: Vector3, pal: Array, life: float, size0: float, size1: float, energy: float) -> VfxFlash:
	var f := _billboard(fx, Lib.K_GLOW, pos, pal, life, size0, size1, energy)
	f.fade_tail = 0.7
	return f


## Camera-facing radial streak burst (vfx_ring rays) - the anime impact "speed line" star.
static func _ray_burst(fx: Node, pos: Vector3, pal: Array, life: float, size: float, r0: float, r1: float, rays: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.quad(), Lib.ring_mat(true), pos, life)
	_ring_params(f, pal, r1, 0.0, rays, 0.0, 2.4)
	f.tween(&"radius", r0, r1, 0.4)
	f.s0 = Vector3.ONE * size * 0.7
	f.s1 = Vector3.ONE * size
	f.fade_tail = 0.6
	return f


static func _ring_params(f: VfxFlash, pal: Array, radius: float, width: float, rays: float, cracks: float, energy: float) -> void:
	Lib.set_pal(f, pal)
	f.set_instance_shader_parameter(&"energy", energy)
	f.set_instance_shader_parameter(&"radius", radius)
	f.set_instance_shader_parameter(&"width", width)
	f.set_instance_shader_parameter(&"rays", rays)
	f.set_instance_shader_parameter(&"cracks", cracks)
	f.set_instance_shader_parameter(&"seed", randf() * 50.0)


## Flat ground shockwave ring (radius r0 -> r1 of a `size` m plane). rays > 0 adds radial streaks on the ground.
static func _ground_ring(fx: Node, pos: Vector3, pal: Array, life: float, size: float, r0: float, r1: float, width: float, rays: float, cracks: float, energy := 2.2) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.plane(), Lib.ring_mat(false), pos + Vector3(0, 0.05, 0), life)
	_ring_params(f, pal, r1, width, rays, cracks, energy)
	f.tween(&"radius", r0, r1, 0.35)
	f.s0 = Vector3(size, 1.0, size)
	f.s1 = f.s0
	f.fade_tail = 0.6
	return f


## Camera-facing ring that shrinks (implosion) or grows.
static func _ground_ring_bb(fx: Node, pos: Vector3, pal: Array, life: float, size: float, r0: float, r1: float, width: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.quad(), Lib.ring_mat(true), pos, life)
	_ring_params(f, pal, r0, width, 0.0, 0.0, 2.6)
	f.tween(&"radius", r0, r1, 1.6)
	f.s0 = Vector3.ONE * size
	f.s1 = f.s0
	f.fade_tail = 0.3
	return f


## Shock ring standing perpendicular to the hit direction.
static func _shock_ring(fx: Node, pos: Vector3, d: Vector3, pal: Array, life: float, size: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.plane(), Lib.ring_mat(false), pos + d * 0.2, life)
	_ring_params(f, pal, 0.95, 0.14, 0.0, 0.0, 2.6)
	f.tween(&"radius", 0.2, 0.95, 0.35)
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(d).normalized()
	f.rot = Basis(x, d, x.cross(d)).orthonormalized()
	f.s0 = Vector3(size, 1.0, size)
	f.s1 = f.s0
	f.fade_tail = 0.6
	return f


## Painted ground cracks (vfx_ring cracks) that linger and erode.
static func _crack(fx: Node, pos: Vector3, life: float, size: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.plane(), Lib.ring_mat(false), pos + Vector3(0, 0.03, 0), life)
	_ring_params(f, Lib.PAL["dust"], 0.0, 0.0, 0.0, 1.0, 1.0)
	f.rot = Basis(Vector3.UP, randf() * TAU)
	f.s0 = Vector3(size, 1.0, size)
	f.s1 = f.s0
	f.fade_tail = 0.5
	return f


static func _glyph_params(f: VfxFlash, pal: Array, style: int, spin: float, energy := 2.6) -> void:
	Lib.set_pal(f, pal)
	f.set_instance_shader_parameter(&"energy", energy)
	f.set_instance_shader_parameter(&"spin", spin)
	f.set_instance_shader_parameter(&"style", float(style))
	f.set_instance_shader_parameter(&"seed", randf())


## Ground glyph circle: draws on from the centre over `reveal_t` (anticipation), spins, fades.
static func _glyph_ground(fx: Node, pos: Vector3, pal: Array, style: int, life: float, size: float, spin: float, reveal_t: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.plane(), Lib.glyph_mat(false), pos + Vector3(0, 0.06, 0), life)
	_glyph_params(f, pal, style, spin)
	f.tween(&"reveal", 0.0, 1.0, 0.6, clampf(reveal_t / life, 0.02, 1.0))
	f.s0 = Vector3(size * 0.85, 1.0, size * 0.85)
	f.s1 = Vector3(size, 1.0, size)
	f.fade_tail = 0.35
	return f


## Glyph circle in any orientation (vertical casting circle, overhead circle). billboard = faces the camera.
static func _glyph_flat(fx: Node, pos: Vector3, b: Basis, pal: Array, style: int, life: float, size: float, reveal_t: float, spin := 1.0, billboard := false) -> VfxFlash:
	var f: VfxFlash = fx.flash(Lib.quad() if billboard else Lib.plane(), Lib.glyph_mat(billboard), pos, life)
	_glyph_params(f, pal, style, spin, 2.8)
	f.tween(&"reveal", 0.15, 1.0, 0.6, clampf(reveal_t / life, 0.02, 1.0))
	if not billboard:
		# PlaneMesh lies in XZ: tilt it so its normal is the basis' -Z (facing the target)
		f.rot = b * Basis(Vector3.RIGHT, PI / 2) if b != Basis.IDENTITY else Basis.IDENTITY
	f.s0 = Vector3(size, 1.0, size) if not billboard else Vector3.ONE * size
	f.s1 = f.s0
	f.fade_tail = 0.4
	return f


static func _energy_mesh(fx: Node, mesh: Mesh, pos: Vector3, pal: Array, life: float, energy: float) -> VfxFlash:
	var f: VfxFlash = fx.flash(mesh, Lib.energy_mat(), pos, life)
	Lib.set_pal(f, pal)
	f.set_instance_shader_parameter(&"energy", energy)
	f.set_instance_shader_parameter(&"vfade", 0.0)
	f.set_instance_shader_parameter(&"dissolve", 0.0)
	f.set_instance_shader_parameter(&"additive", 0.6)
	return f


## Light pillar / column: cel-banded energy cylinder that narrows while it fades.
static func _column(fx: Node, ground: Vector3, pal: Array, life: float, radius: float, height: float) -> VfxFlash:
	var f := _energy_mesh(fx, Lib.cylinder(), ground + Vector3(0, height * 0.5, 0), pal, life, 1.8)
	f.set_instance_shader_parameter(&"additive", 0.8)
	f.set_instance_shader_parameter(&"vfade", 0.35)
	f.s0 = Vector3(radius * 2.0, height, radius * 2.0)
	f.s1 = Vector3(radius * 0.25, height * 1.1, radius * 0.25)
	f.scale_exp = 1.6
	f.fade_tail = 0.6
	return f


## Painted puffy dust (cel clouds) rolling outward along the ground.
static func _dust(fx: Node, g: Vector3, pal: Array, n: int, s: float) -> void:
	fx.burst(g + Vector3(0, 0.25 * s, 0), {"kind": Lib.K_PUFF, "amount": n, "life": 0.75, "speed": [1.8, 3.6], "dir": Vector3.UP,
		"spread": 88.0, "flat": 0.85, "shape": "ring", "radius": 0.35 * s, "size": 1.15 * s, "pal": pal, "energy": 1.0,
		"curve": "grow", "damp": 4.5, "ramp": "late", "gravity": Vector3(0, 0.6, 0)})


# ------------------------------------------------------------------ slash (bible 5.1 crescent + 2 echo arcs)

static func _slash(fx: Node, pos: Vector3, d: Vector3, pal: Array, s: float, budget: int) -> void:
	var f := Vector3(d.x, 0.0, d.z)
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	var right := f.cross(Vector3.UP).normalized()
	# swing plane: horizontal sweeps read best from the chase camera; mix in diagonals for combo variety
	var presets := [deg_to_rad(78.0), deg_to_rad(-78.0), deg_to_rad(38.0), deg_to_rad(-34.0), deg_to_rad(90.0)]
	var tilt: float = presets[randi() % presets.size()]
	var e2 := (Vector3.UP * cos(tilt) + right * sin(tilt)).normalized()
	var b := Basis(f, e2, f.cross(e2)).orthonormalized()
	var c := pos - f * 0.95 * s + Vector3(0, 0.05, 0)
	var n := 3 if budget == 0 else (2 if budget == 1 else 1)
	for k in n:
		var a: VfxFlash = fx.flash(Lib.arc(0.58 - k * 0.04, 1.0, deg_to_rad(112.0 - k * 6.0), deg_to_rad(-100.0 + k * 10.0)), Lib.slash_mat(), c - f * k * 0.08 * s, 0.3)
		if k == 0:
			Lib.set_pal(a, pal)
		else:
			Lib.set_pal(a, [pal[1], pal[1].lerp(pal[2], 0.4), pal[2]])
		a.set_instance_shader_parameter(&"energy", 3.2 - k * 0.8)
		a.set_instance_shader_parameter(&"alpha_mul", 1.0 - k * 0.32)
		a.tween(&"progress", 0.18, 1.0, 0.75)
		a.rot = b.rotated(f, k * 0.06)
		var r := 2.05 * s * (1.0 - k * 0.1)
		a.s0 = Vector3(r, r, r)
		a.s1 = Vector3(r, r, r) * 1.06
		a.delay = k * 0.025
		a.fade_tail = 0.15
	if budget < 2:
		# sparks thrown off the leading tip, along the swing
		var tip := c + b * (Vector3(cos(deg_to_rad(-60.0)), sin(deg_to_rad(-60.0)), 0) * 2.0 * s)
		var tangent := (b * Vector3(sin(deg_to_rad(-60.0)), -cos(deg_to_rad(-60.0)), 0)).normalized()
		fx.burst(tip, {"kind": Lib.K_STREAK, "amount": 6, "life": 0.22, "speed": [5.0, 9.0], "dir": tangent, "spread": 30.0,
			"size": 0.38 * s, "pal": pal, "energy": 3.0, "align": true, "quad": Vector2(0.16, 1.0), "curve": "shrink", "delay": 0.08})


# ------------------------------------------------------------------ explosion (LdVfx cannon blast)

static func _explosion(fx: Node, pos: Vector3, pal: Array, s: float, budget: int) -> void:
	var full := budget == 0
	var gy: float = fx.ground_y(pos)
	var g := Vector3(pos.x, minf(gy, pos.y), pos.z)
	var fire_pal := [pal[0], pal[1], pal[2]]
	# white-hot core fireball (cel-banded energy sphere) + bright star
	var ball := _energy_mesh(fx, Lib.sphere(0.5, 16), pos + Vector3(0, 0.35 * s, 0), fire_pal, 0.3, 2.6)
	ball.s0 = Vector3.ONE * 0.6 * s
	ball.s1 = Vector3.ONE * 1.8 * s
	ball.scale_exp = 0.3
	ball.fade_tail = 0.5
	ball.set_instance_shader_parameter(&"dissolve", 0.0)
	ball.tween(&"dissolve", 0.0, 0.9, 2.0)
	_star(fx, pos + Vector3(0, 0.4 * s, 0), fire_pal, 0.14, 0.8 * s, 2.8 * s, 3.2)
	if budget >= 2:
		return
	_ray_burst(fx, pos + Vector3(0, 0.6 * s, 0), fire_pal, 0.2, 4.2 * s, 0.25, 0.95, 1.4)
	_ground_ring(fx, g, fire_pal, 0.4, 6.5 * s, 0.1, 0.95, 0.2, 0.0, 0.0, 2.6)
	# cel flame tongues licking up and out
	_glow(fx, pos + Vector3(0, 0.4 * s, 0), [fire_pal[1], fire_pal[2], fire_pal[2]], 0.22, 1.2 * s, 2.0 * s, 1.0)
	fx.burst(pos + Vector3(0, 0.3 * s, 0), {"kind": Lib.K_FLAME, "amount": 12 if full else 6, "life": 0.45, "speed": [3.0, 6.5],
		"spread": 180.0, "flat": 0.3, "shape": "sphere", "radius": 0.5 * s, "size": 1.05 * s, "pal": fire_pal, "energy": 2.4,
		"curve": "shrink", "damp": 5.0, "gravity": Vector3(0, 4.0, 0), "upright": true})
	# lingering dark smoke rolls (painted puffs)
	fx.burst(pos + Vector3(0, 0.6 * s, 0), {"kind": Lib.K_PUFF, "amount": 7 if full else 3, "life": 1.2, "speed": [1.5, 3.2],
		"dir": Vector3.UP, "spread": 75.0, "size": 1.5 * s, "pal": Lib.PAL["firesmoke"], "energy": 1.0, "curve": "grow",
		"damp": 2.5, "ramp": "late", "delay": 0.15})
	if full:
		_debris(fx, pos + Vector3(0, 0.3 * s, 0), s, 7, Color("#3A3440"), Color(0.42, 0.38, 0.62), fire_pal[2])
		fx.burst(pos + Vector3(0, 0.3 * s, 0), {"kind": Lib.K_MOTE, "amount": 14, "life": 0.9, "speed": [6.0, 12.0], "dir": Vector3.UP,
			"spread": 80.0, "size": 0.18 * s, "pal": fire_pal, "energy": 3.5, "gravity": Vector3(0, -14, 0)})
		_crack(fx, g, 1.1, 3.4 * s)
		fx.light(pos + Vector3(0, 1.0, 0), fire_pal[1], 3.0, 6.0 * s, 0.35)


## Flat-shaded cel debris shards with outlines, flung out, falling, eroding away.
static func _debris(fx: Node, pos: Vector3, s: float, n: int, base: Color, shade: Color, rim: Color) -> void:
	for i in n:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.4, 1.5), randf_range(-1, 1)).normalized()
		var f: VfxFlash = fx.flash(Lib.shard(i), Lib.solid_mat(true), pos + dir * 0.2, randf_range(0.7, 1.0))
		Lib.set_solid(f, base, shade, rim, 2.4)
		f.vel = dir * randf_range(5.0, 9.0) * s
		f.grav = 16.0
		f.spin = Vector3(randf_range(-12, 12), randf_range(-8, 8), randf_range(-12, 12))
		f.rot = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, 0))
		var sz := randf_range(0.22, 0.42) * s
		f.s0 = Vector3.ONE * sz
		f.s1 = Vector3.ONE * sz
		f.fade_tail = 0.35


static func _ice_shards(fx: Node, pos: Vector3, pal: Array, s: float, n: int) -> void:
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var dir := Vector3(cos(a), randf_range(0.3, 0.9), sin(a)).normalized()
		var f: VfxFlash = fx.flash(Lib.crystal(5, i), Lib.solid_mat(true), pos + dir * 0.2, 0.7)
		Lib.set_solid(f, (pal[1] as Color).lerp(Color.WHITE, 0.45), pal[1], pal[0], 1.2, 0.55)
		f.vel = dir * randf_range(3.5, 6.5) * s
		f.grav = 9.0
		f.align_vel = true
		var sz := randf_range(0.6, 1.0) * s
		f.s0 = Vector3(sz, sz * 1.4, sz)
		f.s1 = f.s0 * 0.7
		f.fade_tail = 0.4


# ------------------------------------------------------------------ lightning

## Jagged bolt from the sky: cel energy tubes (white core, cyan mid, violet rim), a branch, a flash and a
## ground ring. Re-uses tube meshes from a small cache of pre-built bolts so strikes stay cheap.
static var _bolts: Array = []


static func _bolt_mesh() -> ArrayMesh:
	if _bolts.size() < 6:
		var pts: Array = []
		var radii: Array = []
		var top := Vector3(randf_range(-0.6, 0.6), 9.0, randf_range(-0.6, 0.6))
		var segs := 9
		for i in segs + 1:
			var t := float(i) / segs
			var p := top.lerp(Vector3.ZERO, t)
			if i > 0 and i < segs:
				p += Vector3(randf_range(-0.55, 0.55), randf_range(-0.2, 0.2), randf_range(-0.55, 0.55))
			pts.append(p)
			radii.append(lerpf(0.07, 0.16, t))
		# one side branch
		var bi := randi_range(2, 4)
		var b0: Vector3 = pts[bi]
		var bpts := [b0, b0 + Vector3(randf_range(-1.2, 1.2), -1.1, randf_range(-1.2, 1.2)), b0 + Vector3(randf_range(-2.0, 2.0), -2.4, randf_range(-2.0, 2.0))]
		var m := Lib.tube(pts, radii, 6)
		var bm := Lib.tube(bpts, [0.06, 0.045, 0.02], 5)
		var st := SurfaceTool.new()
		st.append_from(m, 0, Transform3D.IDENTITY)
		st.append_from(bm, 0, Transform3D.IDENTITY)
		_bolts.append(st.commit())
	return _bolts[randi() % _bolts.size()]


static func _lightning(fx: Node, pos: Vector3, pal: Array, s: float, budget: int) -> void:
	var gy: float = fx.ground_y(pos, 1.5)
	var g := Vector3(pos.x, minf(gy, pos.y), pos.z)
	var b := _energy_mesh(fx, _bolt_mesh(), g, pal, 0.28, 3.0)
	b.rot = Basis(Vector3.UP, randf() * TAU)
	b.s0 = Vector3(1.6 * s, 1.0, 1.6 * s)
	b.s1 = Vector3(0.6 * s, 1.0, 0.6 * s)
	b.set_instance_shader_parameter(&"additive", 0.8)
	if budget == 0:
		# second strike a frame later (flicker)
		var b2 := _energy_mesh(fx, _bolt_mesh(), g, pal, 0.16, 2.6)
		b2.rot = Basis(Vector3.UP, randf() * TAU)
		b2.s0 = Vector3(1.2 * s, 1.0, 1.2 * s)
		b2.s1 = b2.s0 * Vector3(0.5, 1.0, 0.5)
		b2.delay = 0.07
	_star(fx, g + Vector3(0, 0.4, 0), pal, 0.16, 1.2 * s, 2.4 * s, 3.2)
	if budget >= 2:
		return
	_ground_ring(fx, g, pal, 0.3, 3.2 * s, 0.1, 0.95, 0.14, 1.5, 0.0, 2.6)
	_glyph_ground(fx, g, pal, Lib.G_LIGHTNING, 0.35, 2.4 * s, 3.0, 0.05)
	fx.burst(g + Vector3(0, 0.2, 0), {"kind": Lib.K_STREAK, "amount": 12 if budget == 0 else 6, "life": 0.3, "speed": [5.0, 11.0],
		"dir": Vector3.UP, "spread": 75.0, "size": 0.45 * s, "pal": pal, "energy": 3.5, "align": true, "quad": Vector2(0.12, 1.0),
		"curve": "shrink", "gravity": Vector3(0, -10, 0)})
	if budget == 0:
		fx.light(g + Vector3(0, 1.5, 0), pal[1], 3.5, 7.0 * s, 0.2)


# ------------------------------------------------------------------ dash

static func _dash(fx: Node, pos: Vector3, d: Vector3, pal: Array, s: float, budget: int) -> void:
	var f := Vector3(d.x, 0.0, d.z)
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	var right := f.cross(Vector3.UP).normalized()
	# speed lines: thin bright streaks behind the dasher, staggered, long and razor-tipped
	var n := 7 if budget == 0 else 4
	for i in n:
		var off := right * randf_range(-0.6, 0.6) + Vector3(0, randf_range(-0.7, 0.7), 0)
		var p := pos - f * randf_range(0.8, 2.4) + off
		var st: VfxFlash = fx.flash(Lib.quad(0.12, 1.0), Lib.sprite_mat(Lib.K_STREAK, 1), p, randf_range(0.18, 0.3))
		Lib.set_pal(st, pal)
		st.set_instance_shader_parameter(&"energy", 3.0)
		st.set_instance_shader_parameter(&"progress", 0.0)
		st.set_instance_shader_parameter(&"seed", randf())
		var up := right
		st.rot = Basis(up, f, up.cross(f)).orthonormalized()
		var ln := randf_range(1.6, 3.0) * s
		st.s0 = Vector3(1.0, ln, 1.0)
		st.s1 = Vector3(0.4, ln * 1.3, 0.4)
		st.vel = -f * 2.0
		st.delay = i * 0.012
		st.fade_tail = 0.7
	if budget < 2:
		var gy: float = fx.ground_y(pos)
		fx.burst(Vector3(pos.x, gy + 0.2, pos.z), {"kind": Lib.K_PUFF, "amount": 4 if budget == 0 else 2, "life": 0.5, "speed": [1.0, 2.2],
			"dir": -f, "spread": 35.0, "size": 0.6 * s, "pal": Lib.PAL["dust"], "energy": 1.0, "curve": "grow", "ramp": "late", "damp": 3.0})


# ------------------------------------------------------------------ ultimate

static func _ultimate(fx: Node, pos: Vector3, d: Vector3, pal: Array, s: float, budget: int) -> void:
	var gy: float = fx.ground_y(pos, 0.6)
	var g := Vector3(pos.x, gy, pos.z)
	var gl := _glyph_ground(fx, g, pal, _style_for(pal, Lib.G_HOLY), 1.4, 5.2 * s, 0.6, 0.18)
	gl.set_instance_shader_parameter(&"energy", 1.7)
	_column(fx, g, pal, 0.9, 0.42 * s, 14.0)
	_star(fx, g + Vector3(0, 1.2, 0), pal, 0.22, 1.2 * s, 3.6 * s, 3.0)
	if budget >= 2:
		return
	_ground_ring(fx, g, pal, 0.7, 7.0 * s, 0.05, 0.95, 0.1, 0.0, 0.0, 2.0)
	_ray_burst(fx, g + Vector3(0, 1.2, 0), pal, 0.3, 5.5 * s, 0.2, 0.95, 2.0)
	var v := _glyph_flat(fx, g + Vector3(0, 1.3, 0) + d * 0.8, Basis.looking_at(-d if d.length_squared() > 0.01 else Vector3.BACK, Vector3.UP), pal, Lib.G_ARCANE, 0.9, 3.0 * s, 0.12, -2.0)
	v.s1 = v.s0 * 1.25
	fx.burst(g + Vector3(0, 0.5, 0), {"kind": Lib.K_STREAK, "amount": 22 if budget == 0 else 10, "life": 0.7, "speed": [5.0, 11.0],
		"spread": 180.0, "flat": 0.5, "size": 0.9 * s, "pal": pal, "energy": 3.5, "align": true, "quad": Vector2(0.14, 1.0),
		"curve": "shrink", "damp": 3.0})
	if budget == 0:
		_debris(fx, g + Vector3(0, 0.3, 0), s * 1.1, 6, Color("#3A3440"), Color(0.42, 0.38, 0.62), pal[1])
		fx.light(g + Vector3(0, 2.0, 0), pal[1], 4.0, 10.0 * s, 0.6)
