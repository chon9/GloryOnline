extends RefCounted
## Shared helpers for every class kit (KITS). Not a ClassKit: the "_" prefix makes Registry skip it.
## Kits are shared by every fighter of that class, so per-fighter state lives in Fighter metadata.


## Additive `stat_bonus` write: this caller's share of `key` (remembered in Fighter meta `share_meta`) is replaced by
## `want`, so modifiers that other kits / statuses put on the same key survive. Never assigns the key absolutely.
static func set_bonus_share(f: Fighter, key: String, share_meta: StringName, want: float) -> void:
	if f == null or not is_instance_valid(f):
		return
	var applied := float(f.get_meta(share_meta, 0.0))
	if is_equal_approx(applied, want) and f.stat_bonus.has(key):
		return
	f.stat_bonus[key] = float(f.stat_bonus.get(key, 0.0)) - applied + want
	f.set_meta(share_meta, want)


## This caller's current share of `key` (0 when never written).
static func bonus_share(f: Fighter, share_meta: StringName) -> float:
	return float(f.get_meta(share_meta, 0.0)) if f != null and is_instance_valid(f) else 0.0
