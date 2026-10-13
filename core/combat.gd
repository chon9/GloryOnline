class_name Combat
extends RefCounted
## Static damage resolution (ARCHITECTURE §4.1). Host only (uses the host RNG).

const DEF_K: float = 600.0
const CRIT_MULT: float = 1.5
const BACK_MULT: float = 1.2
const BACK_ANGLE_DEG: float = 120.0
const BLOCK_FRONT_ANGLE_DEG: float = 100.0
const BLIND_MISS: float = 0.5
const DEFAULT_ATK: float = 500.0

static var rng := RandomNumberGenerator.new()
## Tests set this: no crit (unless crit_bonus >= 1), no 0.95..1.05 variance, no blind miss roll.
static var deterministic: bool = false


static func seed_rng(s: int) -> void:
	rng.seed = s


## Angle in degrees between victim facing and the direction to `from_pos` (0 = directly in front).
static func angle_from_front(victim: Fighter, from_pos: Vector3) -> float:
	var to_src := CoreUtil.flat(from_pos - victim.global_position)
	if to_src.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(victim.forward().angle_to(to_src.normalized()))


static func is_back_attack(victim: Fighter, from_pos: Vector3) -> bool:
	return angle_from_front(victim, from_pos) > BACK_ANGLE_DEG


static func _is_pvp_fighter(f: Fighter) -> bool:
	if f == null:
		return false
	if f.kind == "player" or f.kind == "bot":
		return true
	if f.kind == "summon":
		var o := f.get_owner_fighter()
		return o != null and (o.kind == "player" or o.kind == "bot")
	return false


## True when `victim`'s block would guard this (normalised) hit from `from_pos` (same rule as compute()).
static func would_block(victim: Fighter, hit: Dictionary, from_pos: Vector3) -> bool:
	if victim == null or not victim.has_status(&"block") or Hit.is_magic(hit):
		return false
	if bool(hit.get("grab", false)) or bool(hit.get("armor_break", false)):
		return false
	return angle_from_front(victim, from_pos) <= BLOCK_FRONT_ANGLE_DEG


## Returns {amount, crit, back, blocked, miss, kind}. `hit` must be normalised.
static func compute(src: Fighter, victim: Fighter, hit: Dictionary, from_pos: Vector3) -> Dictionary:
	var res: Dictionary = {"amount": 0.0, "crit": false, "back": false, "blocked": false, "miss": false, "kind": &"phys"}
	var magic := Hit.is_magic(hit)
	res["kind"] = &"magic" if magic else &"phys"
	# Blind: 50% of outgoing hits miss.
	if src != null and src.has_status(&"blind"):
		var roll := 0.0 if deterministic else rng.randf()
		if deterministic or roll < BLIND_MISS:
			res["miss"] = true
			res["kind"] = &"miss"
			return res
	var atk := DEFAULT_ATK
	if src != null:
		atk = src.get_stat("matk" if magic else "patk")
	var amount := atk * float(hit["dmg"])
	if bool(hit["true_damage"]):
		res["kind"] = &"true"
	else:
		var def := victim.get_stat("mdef" if magic else "pdef")
		def = maxf(def, 0.0)
		amount *= 1.0 - def / (def + DEF_K)
	# Critical hit.
	var crit_chance := float(hit["crit_bonus"])
	if src != null:
		crit_chance += src.get_stat("crit")
	var crit := false
	if deterministic:
		crit = crit_chance >= 1.0
	else:
		crit = rng.randf() < crit_chance
	if crit:
		amount *= CRIT_MULT
		res["crit"] = true
		res["kind"] = &"crit"
	# Back attack.
	if is_back_attack(victim, from_pos):
		amount *= BACK_MULT
		res["back"] = true
	# Block: frontal physical hits only; grabs / armor_break are handled by the Fighter (they break block).
	if not magic and victim.has_status(&"block") and not bool(hit["grab"]) and not bool(hit["armor_break"]):
		if angle_from_front(victim, from_pos) <= BLOCK_FRONT_ANGLE_DEG:
			amount *= clampf(1.0 - victim.status.power(&"block", 0.6), 0.0, 1.0)
			res["blocked"] = true
	# PvP global scale.
	if _is_pvp_fighter(src) and _is_pvp_fighter(victim):
		amount *= float(CoreUtil.setting("pvp_damage_scale", 1.0))
	# Generic outgoing / incoming multipliers (kits can set these via stat_bonus).
	if src != null:
		amount *= maxf(0.0, 1.0 + src.stat_bonus.get("dmg_out", 0.0))
	amount *= maxf(0.0, 1.0 + victim.stat_bonus.get("dmg_in", 0.0))
	if not deterministic:
		amount *= rng.randf_range(0.95, 1.05)
	res["amount"] = maxf(0.0, amount)
	return res
