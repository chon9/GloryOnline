extends ClassKit
## 魔道学者 Witch (法师系 Mage). Hybrid broom skirmisher: item debuffs, control, aerial combat.
## Passive: 扫把掌握 Broom Mastery - jump again while airborne to mount the broom and fly (hover/glide with
## flaps, up to 4 s per airtime, no cooldown - land to mount again); every skill can be used in flight and Magic Missile fires a 3-missile volley
## while flying. Broom Tornado ends in flight automatically.

const MU := preload("res://classes/mage/_mage_util.gd")

const C_ARCANE := Color(0.85, 0.4, 1.0)
const C_STAR := Color(1.0, 0.9, 0.35)
const C_LAVA := Color(1.0, 0.4, 0.1)
const C_DARK := Color(0.45, 0.15, 0.7)

const FLY_TIME: float = 4.0
const FLY_COOLDOWN: float = 0.0       # canon: no cooldown (re-mount after touching the ground)
const POWDER_ATK_DOWN: float = 0.2     # Disperse Powder attack down (CORE `atk_down` status power)
const POWDER_CAST_SLOW: float = 0.3    # Disperse Powder cast-speed down (CORE `cast_slow` status power)
const FLY_MAX_ALT: float = 3.2         # m above the ground (melee still reaches grounded targets)
const FLY_FALL_SPEED: float = 1.5      # glide sink speed
const FLY_GRAVITY_KEEP: float = 0.1    # fraction of gravity left while flying
const FLY_FLAP: float = 5.0
const BUFF_IDS: Array[StringName] = [&"super_armor", &"haste", &"atk_up", &"def_up", &"matk_up", &"regen", &"shield", &"block"]


func define() -> void:
	id = "witch"
	name_cn = "魔道学者"
	name_en = "Witch"
	group_id = "mage"
	group_cn = "法师系"
	group_en = "Mage"
	role = "control"
	weapon_type = "broom"
	weapon_name_cn = "扫把"
	weapon_name_en = "Broom"
	offhand = ""
	model = "witch"
	tint = Color(0.85, 0.35, 0.95)
	famous = "王杰希 Wang Jiexi / 王不留行 Vaccaria / 灭绝星尘 Stardust Extermination"
	stats = {"hp": 6600.0, "mp": 1300.0, "mp_regen": 20.0, "patk": 520.0, "matk": 520.0,
		"pdef": 330.0, "mdef": 420.0, "move_speed": 6.4, "jump_velocity": 9.0, "weight": 1.0,
		"cast_speed": 1.0, "atk_speed": 1.0}

	# ---------------------------------------------------------------- slot 0: broom chain
	var a1 := sk(0, "broom_1", "普攻·扫击", "Broom Swat", 0.0, 0.0, 0.32, &"attack_1h_1", 2.8, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_staff"},
		{"t": 0.12, "type": "melee", "range": 2.8, "arc": 120.0, "height": 2.8,
			"hit": hit(0.62, {"type": "magic", "hitstun": 0.35, "knockback": 1.0})}],
		{"cancel_window": 0.16, "chain": ["broom_1", "broom_2", "broom_3"],
		"desc": "扫把三段连击（飞行中亦可） Three-hit broom chain, usable in flight."})
	sk(0, "broom_2", "普攻·回扫", "Broom Backswing", 0.0, 0.0, 0.32, &"attack_1h_2", 2.8, ["melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_staff"},
		{"t": 0.12, "type": "melee", "range": 2.8, "arc": 120.0, "height": 2.8,
			"hit": hit(0.62, {"type": "magic", "hitstun": 0.35, "knockback": 1.0})}],
		{"cancel_window": 0.16, "desc": "回扫 Backswing."})
	sk(0, "broom_3", "普攻·旋扫", "Broom Whirl", 0.0, 0.0, 0.48, &"attack_spin", 3.0, ["melee", "finisher", "aoe"],
		[{"t": 0.0, "type": "sfx", "name": "swing_staff"},
		{"t": 0.18, "type": "melee", "shape": "circle", "range": 3.0, "height": 3.0, "fx": "slash_arc",
			"hit": hit(0.85, {"type": "magic", "knockback": 4.0, "hitstun": 0.45})}],
		{"cancel_window": 0.18, "desc": "旋转扫击，击退周围敌人 Spinning sweep that knocks back everyone around."})

	# ---------------------------------------------------------------- slot 1: Lv1 launcher
	var sweep := sk(1, "sweep", "清扫", "Sweep", 4.0, 40.0, 0.4, &"attack_2h", 3.0, ["launcher", "melee", "combo"],
		[{"t": 0.0, "type": "sfx", "name": "swing_heavy"},
		{"t": 0.12, "type": "melee", "range": 3.0, "arc": 140.0, "height": 2.8, "fx": "slash_arc",
			"hit": hit(1.2, {"type": "magic", "launch": 8.0, "knockback": 0.6, "hitstun": 0.45})},
		{"t": 0.14, "type": "vfx", "name": "launch_burst", "at": "forward", "distance": 1.5}],
		{"cancel_window": 0.22, "desc": "扫把上扫，将敌人轻微挑起 Upward broom sweep with a light knock-up."})

	# ---------------------------------------------------------------- slot 2: Magic Missile
	var missile := sk(2, "magic_missile", "魔法飞弹", "Magic Missile", 4.5, 30.0, 0.3, &"shoot_1h", 18.0, ["ranged", "combo"],
		[{"t": 0.1, "type": "projectile", "speed": 24.0, "range": 20.0, "radius": 0.4, "homing": 3.0, "aim": "target",
			"visual": "missile", "color": C_ARCANE, "scale": 0.8, "sfx": "magic_bolt",
			"hit": hit(1.3, {"type": "magic", "hitstun": 0.4, "knockback": 1.5})},
		{"t": 0.1, "type": "custom", "method": "broom_volley", "args": {}}],
		{"cancel_window": 0.15, "desc": "远程追踪魔法飞弹；飞行中一次发射三枚 Long-range homing missile; fires a 3-missile volley while flying."})

	# ---------------------------------------------------------------- slot 3: Lava Flask
	var flask := sk(3, "lava_flask", "熔岩烧瓶", "Lava Flask", 8.0, 60.0, 0.4, &"throw", 13.0, ["ranged", "aoe", "zone"],
		[{"t": 0.12, "type": "projectile", "speed": 16.0, "gravity": 18.0, "range": 16.0, "radius": 0.35, "aim": "target",
			"visual": "flask", "color": C_LAVA, "sfx": "throw_light",
			"hit": hit(0.2, {"type": "magic", "hitstun": 0.2, "knockback": 0.5}),
			"explode": {"radius": 2.2, "fx": "fire_burst",
				"hit": hit(1.0, {"type": "magic", "element": "fire", "hitstun": 0.4, "knockback": 2.0, "statuses": [st("burn", 3.0, 1.0)]})}},
		{"t": 0.12, "type": "ground", "at": "target", "radius": 2.5, "delay": 0.65, "duration": 4.0, "tick": 0.5,
			"visual": "fire", "color": C_LAVA, "max_distance": 14.0,
			"hit": hit(0.15, {"type": "magic", "element": "fire", "hitstun": 0.1, "knockback": 0.0})}],
		{"cancel_window": 0.15, "desc": "投掷熔岩瓶，爆炸后留下灼烧岩浆池 Thrown flask that explodes and leaves a burning lava pool."})

	# ---------------------------------------------------------------- slot 4: Disperse Powder
	var powder := sk(4, "disperse_powder", "驱散粉", "Disperse Powder", 12.0, 70.0, 0.4, &"throw", 6.0, ["debuff", "cc"],
		[{"t": 0.15, "type": "custom", "method": "disperse_powder", "args": {"range": 6.0, "arc": 130.0, "dur": 8.0}},
		{"t": 0.15, "type": "sfx", "name": "debuff"}],
		{"cancel_window": 0.15, "desc": "撒出驱散粉：驱散增益，降低攻击、施法速度与移速8秒 Powder cone: strips buffs, lowers attack, cast speed and move speed for 8 s."})

	# ---------------------------------------------------------------- slot 5: Shadow Cloak (wide grab)
	var cloak := sk(5, "shadow_cloak", "暗影斗篷", "Shadow Cloak", 10.0, 70.0, 0.55, &"grab", 2.8, ["grab", "cc", "melee"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 0.3)]},
		{"t": 0.05, "type": "vfx", "name": "dark_burst", "at": "forward", "distance": 1.4, "color": C_DARK},
		{"t": 0.08, "type": "grab", "range": 2.8, "arc": 200.0, "grab_time": 0.7, "end_on_miss": true,
			"hit": hit(1.8, {"type": "magic", "element": "dark", "knockback": 1.0}), "throw": {"dir": "up", "force": 7.0}},
		{"t": 0.08, "type": "sfx", "name": "curse"}],
		{"desc": "高优先级大范围暗影斗篷抓取，束缚后抛起 High-priority wide-area shadow grab: binds, then tosses the victim up."})

	# ---------------------------------------------------------------- slot 6: Doll Shururu (taunt doll)
	var doll := sk(6, "doll_shururu", "修鲁鲁", "Doll Shururu", 16.0, 80.0, 0.4, &"throw", 8.0, ["summon", "cc", "defensive"],
		[{"t": 0.15, "type": "summon", "summon_id": "shururu", "count": 1, "duration": 10.0, "max_active": 1, "offset": 2.0},
		{"t": 0.16, "type": "custom", "method": "throw_doll", "args": {"distance": 5.0}}],
		{"desc": "投出修鲁鲁玩偶，持续嘲讽周围敌人 Throws the Shururu doll, which keeps taunting nearby enemies."})

	# ---------------------------------------------------------------- slot 7: ultimate
	var ult := sk(7, "broom_tornado", "扫把旋风", "Broom Tornado", 60.0, 250.0, 1.6, &"attack_spin", 3.5,
		["ultimate", "aoe", "melee", "launcher"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.7)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate_charge"},
		{"t": 0.05, "type": "launch_self", "vertical": 6.0},
		{"t": 0.15, "type": "multi_melee", "shape": "circle", "range": 3.3, "height": 3.5, "count": 5, "interval": 0.14,
			"fx": "slash_arc", "hit": hit(0.6, {"type": "magic", "launch": 6.0, "knockback": 0.5, "juggle_cost": 6.0})},
		{"t": 1.05, "type": "anim", "anim": "attack_slam"},
		{"t": 1.1, "type": "melee", "shape": "circle", "range": 3.6, "height": 4.0, "fx": "hit_heavy",
			"hit": hit(1.8, {"type": "magic", "knockdown": true, "otg": true, "no_recover": true, "knockback": 3.0})},
		{"t": 1.1, "type": "vfx", "name": "land_dust", "at": "forward", "distance": 1.2, "scale": 2.0},
		{"t": 1.2, "type": "custom", "method": "start_flight", "args": {"dur": 3.0, "lift": 6.0}}],
		{"desc": "扫把风暴连续挑起敌人，最后将其砸向地面，并保持飞行 Storm of broom strikes that juggles, then slams targets down; ends in broom flight."})

	skills = [a1, sweep, missile, flask, powder, cloak, doll, ult]

	summons = {
		"shururu": {
			"name_cn": "修鲁鲁", "name_en": "Doll Shururu", "model": "toy_soldier", "weapon_type": "", "offhand": "",
			"tint": Color(0.95, 0.5, 0.9), "scale": 0.55,
			"stats": {"hp": 1800.0, "mp": 0.0, "patk": 100.0, "matk": 100.0, "pdef": 350.0, "mdef": 350.0,
				"move_speed": 0.0, "jump_velocity": 0.0},
			"skills": [sk(0, "shururu_taunt", "修鲁鲁嘲讽", "Shururu Taunt", 3.0, 0.0, 0.3, &"taunt", 6.0, ["cc"],
				[{"t": 0.05, "type": "taunt", "radius": 6.0, "duration": 2.5},
				{"t": 0.05, "type": "vfx", "name": "debuff_puff", "color": Color(0.95, 0.5, 0.9)}],
				{"desc": "嘲讽周围敌人 Taunts nearby enemies."})],
		},
	}

	passives = [
		{"name_cn": "扫把掌握", "name_en": "Broom Mastery",
			"desc": "空中再次跳跃骑上扫把飞行约4秒（可拍翼上升、滑翔下降，每次腾空最多4秒，无冷却，落地后可再次骑乘）；飞行中可使用所有技能，魔法飞弹变为三连发 "
				+ "Jump again in mid-air to ride the broom for ~4 s (flap up, glide down; up to 4 s per airtime, no cooldown - land to mount again). All skills work in flight and Magic Missile becomes a 3-missile volley."},
	]


# ================================================================== flight (扫把掌握 Broom Mastery)
func is_flying(f: Fighter) -> bool:
	return float(MU.getv(f, "fly_t", 0.0)) > 0.0


func start_flight(f: Fighter, args: Dictionary, _runner: SkillRunner = null) -> void:
	_begin_flight(f, float(args.get("dur", FLY_TIME)), float(args.get("lift", 0.0)))


func _begin_flight(f: Fighter, dur: float, lift: float) -> void:
	if not f.is_alive():
		return
	MU.setv(f, "fly_t", dur)
	MU.setv(f, "fly_age", 0.0)
	if lift > 0.0:
		f.velocity.y = maxf(f.velocity.y, lift)
	CoreUtil.fx(&"play", [&"dash_trail", f.center(), Vector3.UP, tint, 1.0])
	CoreUtil.fx(&"sfx", [&"jump", f.global_position])


func _end_flight(f: Fighter) -> void:
	if is_flying(f):
		MU.setv(f, "fly_t", 0.0)
		MU.setv(f, "fly_cd", FLY_COOLDOWN)
		MU.setv(f, "fly_need_land", true)
		f.clear_hover()


func on_spawn(f: Fighter) -> void:
	f.clear_hover()
	MU.setv(f, "fly_t", 0.0)
	MU.setv(f, "fly_cd", 0.0)
	MU.setv(f, "fly_need_land", false)


func on_death(f: Fighter, _killer: Fighter) -> void:
	_end_flight(f)


func on_tick(f: Fighter, delta: float) -> void:
	var cd := maxf(0.0, float(MU.getv(f, "fly_cd", 0.0)) - delta)
	MU.setv(f, "fly_cd", cd)
	var fly := float(MU.getv(f, "fly_t", 0.0))
	var inp := f.input
	if f.is_on_floor():
		MU.setv(f, "fly_need_land", false)
	var free := f.state == Fighter.State.AIR or f.state == Fighter.State.CAST or f.state == Fighter.State.IDLE \
		or f.state == Fighter.State.MOVE
	# Mount: a second jump press while airborne.
	if fly <= 0.0:
		if inp != null and inp.jump and cd <= 0.0 and not bool(MU.getv(f, "fly_need_land", false)) and free and not f.is_on_floor() and f.can_act():
			inp.jump = false
			_begin_flight(f, FLY_TIME, FLY_FLAP)
		return
	# Knocked off the broom.
	if not free:
		_end_flight(f)
		return
	var age := float(MU.getv(f, "fly_age", 0.0)) + delta
	MU.setv(f, "fly_age", age)
	fly -= delta
	MU.setv(f, "fly_t", fly)
	if fly <= 0.0 or (f.is_on_floor() and age > 0.35 and f.velocity.y <= 0.0):
		_end_flight(f)
		return
	var w := f.world()
	var alt := f.global_position.y - (w.ground_y(f.global_position) if w != null else 0.0)
	# Flap.
	if inp != null and inp.jump:
		inp.jump = false
		if alt < FLY_MAX_ALT:
			f.velocity.y = maxf(f.velocity.y, FLY_FLAP)
	# CORE gravity scale (applied after this hook): most of gravity is cancelled except while rising from a
	# flap, and the sink is capped (glide). The ceiling keeps melee reach on grounded targets.
	f.set_hover(FLY_GRAVITY_KEEP if f.velocity.y < 1.0 else 1.0, FLY_FALL_SPEED)
	if alt >= FLY_MAX_ALT and f.velocity.y > 0.0:
		f.velocity.y = 0.0
	# Light trail while flying.
	var tt := float(MU.getv(f, "trail_t", 0.0)) - delta
	if tt <= 0.0:
		tt = 0.5
		CoreUtil.fx(&"play", [&"dash_trail", f.global_position + Vector3.UP * 0.5, -f.forward(), tint, 0.6])
	MU.setv(f, "trail_t", tt)


# ================================================================== custom skills
## Magic Missile: two extra missiles while flying.
func broom_volley(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	if not is_flying(f):
		return
	runner.execute_step({"type": "projectile", "speed": 24.0, "range": 20.0, "radius": 0.4, "homing": 3.0, "aim": "target",
		"count": 2, "spread": 30.0, "visual": "missile", "color": C_STAR, "scale": 0.7, "sfx": "magic_bolt",
		"hit": hit(0.6, {"type": "magic", "hitstun": 0.3, "knockback": 1.0})})


## Disperse Powder: strip buffs + slow + attack down (CORE `atk_down`) + cast slow (CORE `cast_slow`) on every enemy
## in the cone. All three are NEGATIVE statuses, so a cleanse removes them together.
func disperse_powder(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var dur := float(args.get("dur", 8.0))
	for e: Fighter in MU.cone_targets(runner, float(args.get("range", 6.0)), float(args.get("arc", 130.0)), 3.0):
		for b: StringName in BUFF_IDS:
			if e.has_status(b):
				e.remove_status(b)
		e.add_status(&"slow", dur, 0.35, f)
		e.add_status(&"atk_down", dur, POWDER_ATK_DOWN, f)
		e.add_status(&"cast_slow", dur, POWDER_CAST_SLOW, f)
		CoreUtil.fx(&"play", [&"debuff_puff", e.center(), e.forward(), Color(0.85, 0.75, 1.0), 1.0])
	CoreUtil.fx(&"play", [&"smoke", f.center() + f.forward() * 2.5, f.forward(), Color(0.85, 0.75, 1.0), 1.2])


## Doll Shururu: the doll is thrown toward the target / aim point.
func throw_doll(f: Fighter, args: Dictionary, runner: SkillRunner) -> void:
	var w := runner.world()
	if w == null:
		return
	var dolls := w.summons_of(f, "shururu")
	if dolls.is_empty():
		return
	var doll: Fighter = dolls[dolls.size() - 1]
	var dist := float(args.get("distance", 5.0))
	var to := f.global_position + f.forward() * dist
	var t := f.get_target()
	if t != null and t.global_position.distance_to(f.global_position) < dist + 4.0:
		var d := CoreUtil.flat(t.global_position - f.global_position)
		to = f.global_position + d * clampf((d.length() - 1.5) / maxf(d.length(), 0.01), 0.0, 1.0)
	doll.global_position = w.ground_point(w.clamp_to_bounds(to))
	doll.face_towards(f.global_position + f.forward() * 20.0)
	CoreUtil.fx(&"play", [&"summon_circle", doll.global_position, f.forward(), Color(0.95, 0.5, 0.9), 0.8])


# ================================================================== Disperse Powder
## Test helper: current Disperse Powder attack-down on `e` (power of its CORE `atk_down` status).
func powder_share(e: Fighter) -> float:
	return e.status.power(&"atk_down") if is_instance_valid(e) else 0.0
