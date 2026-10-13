class_name World
extends Node3D
## Holds all Fighters (replicated through $Spawner), host-only effects, uid allocation and spatial helpers.
## The host drives the whole simulation from World._physics_process -> step(delta) (set auto_step=false
## and call step() yourself for deterministic tests).

signal fighter_spawned(f: Fighter)
signal fighter_died(f: Fighter, killer: Fighter)
signal fighter_removed(f: Fighter)

const PET_BRAIN_PATH: String = "res://ai/bot_brain.gd"

static var _instance: World = null

var fighters: Array[Fighter] = []
var by_uid: Dictionary = {}
var effects: Array[Node] = []
var bounds: AABB = AABB(Vector3(-30.0, -20.0, -30.0), Vector3(60.0, 80.0, 60.0))
var floor_y: float = 0.0                 # fallback ground height when the ground raycast hits nothing
var auto_step: bool = true

var fighters_root: Node3D
var spawner: MultiplayerSpawner
var effects_root: Node3D

var _uid_counter: int = 0
var _fx_counter: int = 0
var _traps: Dictionary = {}              # trap key -> Array[AreaEffect]


static func get_instance() -> World:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	return null


func _init() -> void:
	if name == "" or name.begins_with("@"):
		name = "World"
	fighters_root = Node3D.new()
	fighters_root.name = "Fighters"
	add_child(fighters_root)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("../Fighters")
	spawner.spawn_function = _spawn_fighter
	add_child(spawner)
	effects_root = Node3D.new()
	effects_root.name = "Effects"
	add_child(effects_root)


func _enter_tree() -> void:
	_instance = self


func _exit_tree() -> void:
	# Effects are children (Effects/), so they leave the tree first and despawn their Fx visuals in their own
	# _exit_tree; drop our references so nothing keeps stepping or finishing them.
	for e: Variant in effects:
		if is_instance_valid(e) and (e as Node).is_inside_tree():
			if (e as Node).has_method("finish"):
				(e as Node).call("finish")
	effects.clear()
	_traps.clear()
	if _instance == self:
		_instance = null


func is_host() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if auto_step and is_host():
		step(delta)


## Advances the whole host simulation by one step: fighters, then projectiles/areas.
func step(delta: float) -> void:
	for f: Fighter in fighters.duplicate():
		if is_instance_valid(f) and f.is_inside_tree() and not f.is_queued_for_deletion():
			if not auto_step and f.brain != null and is_instance_valid(f.brain) and f.brain.has_method("think"):
				f.brain.call("think", delta)
			f.host_tick(delta)
	for e: Variant in effects.duplicate():
		if is_instance_valid(e) and not (e as Node).is_queued_for_deletion():
			(e as Node).call("tick", delta)
	_prune_effects()


func _prune_effects() -> void:
	var live: Array[Node] = []
	for e: Variant in effects:
		if is_instance_valid(e) and not (e as Node).is_queued_for_deletion():
			live.append(e)
	effects = live


# ================================================================== spawning
func next_uid() -> int:
	_uid_counter += 1
	while by_uid.has(_uid_counter):
		_uid_counter += 1
	return _uid_counter


func next_fx_id() -> int:
	_fx_counter += 1
	return _fx_counter


static func make_spawn_data(data: Dictionary) -> Dictionary:
	return {
		"uid": int(data.get("uid", 0)),
		"kind": str(data.get("kind", "bot")),
		"peer": int(data.get("peer", 0)),
		"class_id": str(data.get("class_id", "")),
		"mob_id": str(data.get("mob_id", "")),
		"team": int(data.get("team", 0)),
		"name": str(data.get("name", "")),
		"pos": CoreUtil.to_vec3(data.get("pos", Vector3.ZERO)),
		"owner_uid": int(data.get("owner_uid", 0)),
		"yaw": float(data.get("yaw", 0.0)),
	}


## Host only. Spawns a Fighter on every peer (through $Spawner when networking is available).
func spawn_fighter(data: Dictionary) -> Fighter:
	var d := make_spawn_data(data)
	if int(d["uid"]) <= 0:
		d["uid"] = next_uid()
	else:
		_uid_counter = maxi(_uid_counter, int(d["uid"]))
	var f: Fighter = null
	if spawner.is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		f = spawner.spawn(d) as Fighter
	if f == null:
		f = _spawn_fighter(d) as Fighter
		fighters_root.add_child(f, true)
	return f


## Spawn function (runs on every peer).
func _spawn_fighter(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var f: Fighter = Summon.new() if str(d.get("kind", "")) == "summon" else Fighter.new()
	f.setup(make_spawn_data(d))
	return f


## Host: spawns a summon for `owner` with its kit (or mob def) definition `summon_id`.
func spawn_summon(owner: Fighter, summon_id: String, pos: Vector3, duration: float) -> Fighter:
	var f := spawn_fighter({
		"kind": "summon", "peer": 0, "class_id": owner.class_id, "mob_id": summon_id,
		"team": owner.team, "name": "", "pos": pos, "owner_uid": owner.uid, "yaw": owner.facing_yaw,
	})
	if f is Summon:
		(f as Summon).life_left = duration if duration > 0.0 else -1.0
	attach_brain(f, "pet")
	return f


## Host: attaches an AI brain. Uses res://ai/bot_brain.gd when present, else SimplePetBrain for pets.
func attach_brain(f: Fighter, mode: String) -> Node:
	if f == null or (f.brain != null and is_instance_valid(f.brain)):
		return f.brain if f != null else null
	var b: Node = null
	if ResourceLoader.exists(PET_BRAIN_PATH):
		var scr: Variant = load(PET_BRAIN_PATH)
		if scr is Script and (scr as Script).can_instantiate():
			var inst: Variant = (scr as Script).new()
			if inst is Node:
				b = inst
				if "mode" in b:
					b.set("mode", mode)
				if "fighter" in b:
					b.set("fighter", f)
				var argc := -1
				for m: Dictionary in (scr as Script).get_script_method_list():
					if str(m.get("name", "")) == "setup":
						argc = (m.get("args", []) as Array).size()
				if argc == 1:
					b.call("setup", f)
				elif argc >= 2:
					b.call("setup", f, mode)
			elif inst is RefCounted:
				pass
	if b == null and mode == "pet":
		b = SimplePetBrain.new()
	if b == null:
		return null
	b.name = "Brain"
	f.brain = b
	f.add_child(b)
	return b


func _register(f: Fighter) -> void:
	if fighters.has(f):
		return
	fighters.append(f)
	by_uid[f.uid] = f
	_uid_counter = maxi(_uid_counter, f.uid)
	if not f.died.is_connected(_on_fighter_died):
		f.died.connect(_on_fighter_died)
	fighter_spawned.emit(f)


func _unregister(f: Fighter) -> void:
	fighters.erase(f)
	if by_uid.get(f.uid) == f:
		by_uid.erase(f.uid)
	fighter_removed.emit(f)


func _on_fighter_died(f: Fighter, killer: Fighter) -> void:
	fighter_died.emit(f, killer)
	# Owner death takes its summons with it.
	for s: Fighter in summons_of(f, ""):
		if s is Summon:
			(s as Summon).expire()


func add_effect(n: Node) -> void:
	effects_root.add_child(n, true)
	effects.append(n)


func register_trap(key: String, trap: AreaEffect, max_active: int) -> void:
	var arr: Array = _traps.get(key, [])
	var live: Array = []
	for t: Variant in arr:
		if is_instance_valid(t) and (t as AreaEffect).alive:
			live.append(t)
	live.append(trap)
	while live.size() > max_active:
		var old: AreaEffect = live.pop_front()
		old.finish()
	_traps[key] = live


func clear_effects() -> void:
	for e: Variant in effects:
		if is_instance_valid(e):
			if e.has_method("finish"):
				e.call("finish")
			else:
				e.queue_free()
	effects.clear()
	_traps.clear()


# ================================================================== lookup
func get_fighter(uid: int) -> Fighter:
	var f: Variant = by_uid.get(uid)
	if f != null and is_instance_valid(f):
		return f
	return null


func fighters_in_radius(pos: Vector3, r: float, alive_only := true) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for f: Fighter in fighters:
		if not is_instance_valid(f) or (alive_only and not f.is_alive()):
			continue
		if CoreUtil.flat(f.global_position - pos).length() - f.radius() <= r:
			out.append(f)
	return out


## Living enemies of `f`. Stealthed enemies are excluded unless include_stealthed (AoE logic includes them).
func enemies_of(f: Fighter, include_stealthed := false) -> Array[Fighter]:
	var out: Array[Fighter] = []
	if f == null:
		return out
	for o: Fighter in fighters:
		if is_instance_valid(o) and o.team != f.team and o.is_alive() and (include_stealthed or not o.is_stealthed):
			out.append(o)
	return out


func allies_of(f: Fighter, include_self := true, include_dead := false) -> Array[Fighter]:
	var out: Array[Fighter] = []
	if f == null:
		return out
	for o: Fighter in fighters:
		if not is_instance_valid(o) or o.team != f.team or (not include_dead and not o.is_alive()):
			continue
		if o == f and not include_self:
			continue
		out.append(o)
	return out


## Nearest visible (non-stealthed) living enemy within max_dist.
func nearest_enemy(f: Fighter, max_dist := INF) -> Fighter:
	var best: Fighter = null
	var best_d := max_dist
	for o: Fighter in enemies_of(f, false):
		var d := o.global_position.distance_to(f.global_position)
		if d <= best_d:
			best_d = d
			best = o
	return best


## Number of living non-summon fighters on `team`.
func team_alive(team: int) -> int:
	var n := 0
	for f: Fighter in fighters:
		if is_instance_valid(f) and f.team == team and f.kind != "summon" and f.is_alive():
			n += 1
	return n


func team_fighters(team: int, include_summons := false) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for f: Fighter in fighters:
		if is_instance_valid(f) and f.team == team and (include_summons or f.kind != "summon"):
			out.append(f)
	return out


## Living summons owned by `owner` (optionally of one summon id), oldest first.
func summons_of(owner: Fighter, summon_id := "") -> Array[Fighter]:
	var out: Array[Fighter] = []
	if owner == null:
		return out
	for f: Fighter in fighters:
		if is_instance_valid(f) and f.kind == "summon" and f.owner_uid == owner.uid and f.is_alive() \
				and (summon_id == "" or f.mob_id == summon_id):
			out.append(f)
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.uid < b.uid)
	return out


## The fighter controlled by this machine's human player (or null).
func local_fighter() -> Fighter:
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return null
	var me := multiplayer.get_unique_id()
	for f: Fighter in fighters:
		if is_instance_valid(f) and f.kind == "player" and f.peer == me:
			return f
	return null


# ================================================================== spatial helpers
func raycast(from: Vector3, to: Vector3, mask: int = CoreUtil.LAYER_WORLD, exclude: Array[RID] = []) -> Dictionary:
	if not is_inside_tree() or from.is_equal_approx(to):
		return {}
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	q.collide_with_areas = false
	return space.intersect_ray(q)


## Ground height under `pos` (world layer); falls back to floor_y.
func ground_y(pos: Vector3) -> float:
	var r := raycast(pos + Vector3(0, 4.0, 0), pos + Vector3(0, -40.0, 0))
	if r.is_empty():
		return floor_y
	return (r["position"] as Vector3).y


func ground_point(pos: Vector3) -> Vector3:
	return Vector3(pos.x, ground_y(pos), pos.z)


func clamp_to_bounds(p: Vector3) -> Vector3:
	var lo := bounds.position
	var hi := bounds.end
	return Vector3(clampf(p.x, lo.x, hi.x), minf(p.y, hi.y), clampf(p.z, lo.z, hi.z))


## Sets bounds to a centered square arena of `size` meters (default 60x60).
func set_arena_size(size_x: float, size_z: float, center := Vector3.ZERO) -> void:
	bounds = AABB(Vector3(center.x - size_x * 0.5, -20.0, center.z - size_z * 0.5), Vector3(size_x, 80.0, size_z))
