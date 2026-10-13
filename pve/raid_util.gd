class_name RaidUtil
extends RefCounted
## Shared static helpers for the PvE raid module (BossBrain, RaidMobBrain, MatchRaid, dungeons).

const FALLBACK_BRAIN_PATH: String = "res://pve/raid_mob_brain.gd"
const CC_TAGS: Array[String] = ["cc", "launcher", "grab", "control", "interrupt", "stun"]
const CC_STATUSES: Array[String] = ["stun", "freeze", "sleep", "silence", "root"]


## Spawns a host-simulated ground AreaEffect owned by `caster` (same fields SkillRunner._make_area sets).
## p: shape, radius, length, width, height, delay, duration, tick, affects, hit, visual, color, max_hits.
static func spawn_area(caster: Fighter, pos: Vector3, yaw: float, p: Dictionary) -> AreaEffect:
	if caster == null or not is_instance_valid(caster):
		return null
	var w := caster.world()
	if w == null:
		return null
	var a := AreaEffect.new()
	a.caster = caster
	a.team = caster.team
	a.shape = SkillRunner.ps(p, "shape", "circle")
	a.radius = SkillRunner.pf(p, "radius", 3.0)
	a.length = SkillRunner.pf(p, "length", maxf(a.radius * 2.0, 6.0))
	a.width = SkillRunner.pf(p, "width", 2.0 if a.shape != "ring" else 1.0)
	a.area_height = SkillRunner.pf(p, "height", 3.0)
	a.delay = maxf(0.0, SkillRunner.pf(p, "delay", 0.0))
	a.duration = maxf(0.0, SkillRunner.pf(p, "duration", 0.0))
	a.tick_interval = maxf(0.05, SkillRunner.pf(p, "tick", 0.5))
	a.affects = SkillRunner.ps(p, "affects", "enemies")
	a.hit = Hit.normalize(p.get("hit", {}))
	a.visual = SkillRunner.ps(p, "visual", "rune")
	a.color = CoreUtil.to_color(p.get("color", Color(1, 0.9, 0.6)), Color(1, 0.9, 0.6))
	a.max_hits_per_target = SkillRunner.pi(p, "max_hits", 0)
	a.mode = "zone"
	a.position = w.ground_point(pos)
	a.yaw = yaw
	w.add_effect(a)
	return a


## True when `skill` counts as crowd control for boss interrupt / stagger purposes.
static func skill_is_cc(skill: SkillDef) -> bool:
	if skill == null:
		return false
	for t: String in CC_TAGS:
		if skill.tags.has(t):
			return true
	for s: Dictionary in skill.steps:
		var type := str(s.get("type", ""))
		if type == "grab" or type == "pull":
			return true
		if type == "debuff" and _statuses_cc(s.get("statuses", [])):
			return true
		for key: String in ["hit", "land"]:
			var h: Variant = s.get(key)
			if key == "land" and h is Dictionary:
				h = (h as Dictionary).get("hit")
			if h is Dictionary and hit_is_cc(h):
				return true
	return false


static func hit_is_cc(h: Dictionary) -> bool:
	if float(h.get("stun", 0.0)) > 0.0 or float(h.get("launch", 0.0)) > 0.0:
		return true
	if bool(h.get("knockdown", false)) or bool(h.get("grab", false)):
		return true
	return _statuses_cc(h.get("statuses", []))


static func _statuses_cc(list: Variant) -> bool:
	for s: Dictionary in CoreUtil.status_list(list):
		if CC_STATUSES.has(str(s["id"])):
			return true
	return false


## Attaches the RAID fallback brain (RaidMobBrain) in `mode` ("mob" | "raid").
static func attach_fallback_brain(f: Fighter, mode: String) -> Node:
	if f == null:
		return null
	if f.brain != null and is_instance_valid(f.brain):
		return f.brain
	var scr: Variant = load(FALLBACK_BRAIN_PATH)
	if not (scr is Script):
		return null
	var b: Node = (scr as Script).new()
	b.set("mode", mode)
	b.set("fighter", f)
	b.name = "Brain"
	f.brain = b
	f.add_child(b)
	return b


## Attaches a brain: the AI module's BotBrain through World.attach_brain when policy == "auto" and it
## loads, else the RAID fallback brain.
static func attach_brain(w: World, f: Fighter, mode: String, policy: String = "auto") -> Node:
	if f == null:
		return null
	if policy == "auto" and w != null:
		var b := w.attach_brain(f, mode)
		if b != null:
			return b
	return attach_fallback_brain(f, mode)


static func living_party(w: World, team: int = 0) -> Array[Fighter]:
	var out: Array[Fighter] = []
	if w == null:
		return out
	for f: Fighter in w.team_fighters(team):
		if f.is_alive():
			out.append(f)
	return out


static func font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	return f
