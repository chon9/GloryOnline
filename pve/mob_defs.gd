extends RefCounted
## Raid mob / boss definitions (owner: RAID). Loaded by the Registry autoload through `all()`
## (format: docs/DEVIATIONS.md "Mob def format"). Skills are plain dictionaries using SkillDef field
## names; the Registry normalises them into Array[SkillDef].
##
## Extra keys used by RAID only (ignored by core):
##   role: "melee" | "ranged" | "tank" | "healer" | "elite" | "boss"   (fallback mob brain hint)
##   boss: Dictionary  (BossBrain data: phases, abilities, enrage; see pve/boss_brain.gd)
##
## Numbers: party members have ~6000-9000 hp, 200-600 def. Trash hits ~4-8% hp, elites ~10-15%,
## boss tank-busters ~15-25% of a tank (wave3 RAID-TUNE: tuned with tests/test_raid_clear.gd). Boss hp is for
## 5 players; MatchRaid scales by party size.

const ICE := Color(0.55, 0.85, 1.0)
const DARK := Color(0.55, 0.25, 0.85)
const BONE := Color(0.9, 0.85, 0.65)
const BLOOD := Color(0.85, 0.15, 0.15)
const ORC := Color(0.55, 0.8, 0.3)
const TRASH_HP: float = 2.8
## Defs only spawned as summons (their hp is the summon's, not a pack member's).
const SUMMON_ONLY: Array[String] = ["bone_minion"]
## mob id -> Vector2(body_radius, body_height) in meters (measured from the scaled visuals' torso).
const BODY: Dictionary = {
	"frost_golem": Vector2(1.3, 4.0), "black_knight": Vector2(1.2, 4.4),
	"bone_champion": Vector2(0.8, 2.8), "orc_warlord": Vector2(0.75, 2.6), "werewolf_elite": Vector2(0.7, 2.4),
}


static func hit(dmg: float, extra: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {"dmg": dmg}
	for k: Variant in extra:
		h[k] = extra[k]
	return h


static func st(id: String, dur: float, power: float = 1.0) -> Dictionary:
	return {"id": id, "dur": dur, "power": power}


## Skill dictionary (SkillDef field names).
static func sk(slot: int, id: String, cn: String, en: String, cd: float, cast: float, anim: String,
		rng: float, tags: Array, steps: Array, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"slot": slot, "id": id, "name_cn": cn, "name_en": en, "cooldown": cd, "mp_cost": 0.0,
		"cast_time": cast, "anim": anim, "range": rng, "tags": tags, "steps": steps}
	for k: Variant in extra:
		d[k] = extra[k]
	return d


static func mob(cn: String, en: String, model: String, weapon: String, offhand: String, tint: Color, scale: float,
		role: String, stats: Dictionary, skills: Array) -> Dictionary:
	return {"name_cn": cn, "name_en": en, "model": model, "weapon_type": weapon, "offhand": offhand, "tint": tint,
		"scale": scale, "role": role, "stats": stats, "skills": skills}


static func stats(hp: float, patk: float, matk: float, pdef: float, mdef: float, move: float, extra: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {"hp": hp, "mp": 1000.0, "mp_regen": 50.0, "patk": patk, "matk": matk, "pdef": pdef, "mdef": mdef,
		"move_speed": move, "jump_velocity": 8.0, "crit": 0.05}
	for k: Variant in extra:
		s[k] = extra[k]
	return s


static func all() -> Dictionary:
	var d: Dictionary = {}
	_trash_boneyard(d)
	_trash_frost(d)
	d["frost_golem"] = _frost_golem()
	d["black_knight"] = _black_knight()
	# Capsule sizes (CORE keys body_radius / body_height, meters) so players cannot stand inside the big
	# models: the default capsule is 0.4 x scale, much thinner than the Large-rig / heavy-armour meshes.
	# Trash pacing: every non-boss mob (not summons) gets TRASH_HP x its listed hp, so a 5-man pack takes
	# ~30-60 s for a bot party (listed numbers are per-mob duel-scale values).
	for id: String in d:
		var def: Dictionary = d[id]
		if str(def.get("role", "")) != "boss" and not SUMMON_ONLY.has(id):
			var st: Dictionary = def["stats"]
			st["hp"] = float(st["hp"]) * TRASH_HP
	for id: String in BODY:
		if d.has(id):
			(d[id] as Dictionary)["body_radius"] = (BODY[id] as Vector2).x
			(d[id] as Dictionary)["body_height"] = (BODY[id] as Vector2).y
	return d


# =============================================================================== trash: Burial Grounds
static func _trash_boneyard(d: Dictionary) -> void:
	# Melee grunt.
	d["skeleton_grunt"] = mob("骷髅战士", "Skeleton Warrior", "skeleton_warrior", "skeleton_axe", "", BONE, 1.0, "melee",
		stats(9000.0, 480.0, 300.0, 300.0, 250.0, 5.0), [
		sk(0, "skeleton_grunt.chop", "劈砍", "Chop", 1.4, 0.6, "attack_1h_1", 2.3, ["melee"],
			[{"t": 0.3, "type": "sfx", "name": "swing"}, {"t": 0.3, "type": "melee", "range": 2.4, "hit": hit(1.0)}]),
		sk(1, "skeleton_grunt.heavy", "重劈", "Heavy Cleave", 7.0, 1.0, "attack_2h", 2.6, ["melee", "finisher"],
			[{"t": 0.0, "type": "sfx", "name": "skeleton"}, {"t": 0.7, "type": "sfx", "name": "swing_heavy"}, {"t": 0.0, "type": "vfx", "name": "cast_glow"},
			{"t": 0.7, "type": "melee", "range": 2.8, "arc": 120.0, "hit": hit(1.8, {"knockdown": true, "knockback": 4.0})}]),
	])
	# Shield bearer: blocks frontal physical hits (attack from behind or use magic / grabs).
	d["skeleton_guard"] = mob("骷髅盾卫", "Skeleton Shieldbearer", "skeleton_warrior", "skeleton_blade", "skeleton_shield", BONE, 1.05,
		"tank", stats(13000.0, 420.0, 300.0, 520.0, 300.0, 4.6), [
		sk(0, "skeleton_guard.bash", "盾击", "Shield Bash", 1.8, 0.6, "attack_1h_2", 2.2, ["melee", "cc"],
			[{"t": 0.3, "type": "sfx", "name": "shield"}, {"t": 0.3, "type": "melee", "range": 2.3, "hit": hit(0.8, {"stun": 0.5})}]),
		sk(1, "skeleton_guard.wall", "举盾", "Raise Shield", 9.0, 0.3, "block", 0.0, ["defensive", "buff_self"],
			[{"t": 0.0, "type": "sfx", "name": "skeleton"}, {"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", 4.0, 0.75)]}]),
	])
	# Archer / crossbow.
	d["skeleton_crossbow"] = mob("骷髅弩手", "Skeleton Crossbowman", "skeleton_rogue", "skeleton_crossbow", "", BONE, 1.0,
		"ranged", stats(6500.0, 520.0, 300.0, 200.0, 220.0, 5.4), [
		sk(0, "skeleton_crossbow.shot", "弩箭", "Bolt Shot", 1.6, 0.6, "shoot_2h", 16.0, ["ranged"],
			[{"t": 0.35, "type": "projectile", "sfx": "bow_shot", "visual": "arrow", "speed": 26.0, "range": 20.0, "aim": "target", "hit": hit(0.9)}]),
		sk(1, "skeleton_crossbow.volley", "连弩齐射", "Volley", 8.0, 1.0, "shoot_2h", 14.0, ["ranged", "aoe"],
			[{"t": 0.6, "type": "projectile", "sfx": "bow_shot", "visual": "arrow", "count": 3, "spread": 24.0, "speed": 24.0, "range": 18.0,
			"aim": "target", "hit": hit(0.8)}]),
		sk(2, "skeleton_crossbow.retreat", "后撤", "Fall Back", 6.0, 0.35, "dash", 4.0, ["escape"],
			[{"t": 0.0, "type": "sfx", "name": "dash"}, {"t": 0.0, "type": "dash", "direction": "back", "distance": 5.0, "speed": 18.0}]),
	])
	# Mage caster with a telegraphed AoE.
	d["skeleton_mage"] = mob("骷髅法师", "Skeleton Mage", "skeleton_mage", "skeleton_staff", "", DARK, 1.0, "ranged",
		stats(6000.0, 300.0, 560.0, 180.0, 400.0, 5.0), [
		sk(0, "skeleton_mage.bolt", "暗影箭", "Shadow Bolt", 2.0, 0.7, "cast", 15.0, ["ranged"],
			[{"t": 0.4, "type": "projectile", "sfx": "dark", "visual": "orb", "color": DARK, "speed": 18.0, "range": 18.0, "aim": "target",
			"hit": hit(1.0, {"type": "magic", "element": "dark"})}]),
		sk(1, "skeleton_mage.pyre", "冥火柱", "Grave Pyre", 7.0, 1.0, "cast_long", 14.0, ["aoe", "ranged"],
			[{"t": 0.2, "type": "sfx", "name": "curse"}, {"t": 0.2, "type": "ground", "at": "target", "radius": 3.2, "delay": 1.2, "visual": "dark", "color": DARK,
			"hit": hit(2.2, {"type": "magic", "knockdown": true, "element": "dark"})}]),
	])
	# Rogue: blinks behind its target and backstabs (+20% back attack).
	d["skeleton_rogue"] = mob("骷髅刺客", "Skeleton Rogue", "skeleton_rogue", "skeleton_dagger", "dagger", BONE, 0.95, "melee",
		stats(7000.0, 560.0, 300.0, 220.0, 220.0, 6.5), [
		sk(0, "skeleton_rogue.stab", "刺击", "Stab", 1.0, 0.45, "attack_stab", 2.0, ["melee"],
			[{"t": 0.2, "type": "sfx", "name": "swing_dagger"}, {"t": 0.2, "type": "melee", "range": 2.1, "hit": hit(0.9)}]),
		sk(1, "skeleton_rogue.backstab", "影袭", "Shadow Backstab", 8.0, 0.6, "attack_dual", 12.0, ["gap_closer", "melee"],
			[{"t": 0.3, "type": "sfx", "name": "swing_dagger"}, {"t": 0.0, "type": "blink", "to": "behind_target", "distance": 12.0},
			{"t": 0.3, "type": "melee", "range": 2.2, "hit": hit(1.6, {"crit_bonus": 0.3, "statuses": [st("bleed", 4.0, 1.0)]})}]),
	])
	# Healer / summoner.
	d["necromancer"] = mob("亡灵巫师", "Necromancer", "necromancer", "skeleton_staff", "", DARK, 1.0, "healer",
		stats(8000.0, 300.0, 520.0, 220.0, 450.0, 5.0), [
		sk(0, "necromancer.bolt", "腐蚀箭", "Corruption Bolt", 2.2, 0.7, "cast", 15.0, ["ranged"],
			[{"t": 0.4, "type": "projectile", "sfx": "curse", "visual": "blood", "color": DARK, "speed": 18.0, "range": 18.0, "aim": "target",
			"hit": hit(0.9, {"type": "magic", "statuses": [st("poison", 4.0, 0.8)]})}]),
		sk(1, "necromancer.mend", "黑暗愈合", "Dark Mending", 6.0, 1.0, "heal", 16.0, ["heal"],
			[{"t": 0.0, "type": "sfx", "name": "curse"}, {"t": 0.6, "type": "heal", "target": "ally_lowest", "radius": 18.0, "amount": 0.12}]),
		sk(2, "necromancer.raise", "亡者复苏", "Raise Dead", 14.0, 1.2, "summon", 12.0, ["summon"],
			[{"t": 0.3, "type": "sfx", "name": "dark_chant"}, {"t": 0.8, "type": "summon", "summon_id": "bone_minion", "count": 2, "duration": 30.0, "max_active": 4, "offset": 2.0}]),
	])
	# Boss add variant (Black Knight phase 2): raises minions, never heals (a mend would heal the boss).
	d["grave_necromancer"] = mob("墓穴死灵师", "Grave Necromancer", "necromancer", "skeleton_staff", "", DARK, 1.0, "ranged",
		stats(8000.0, 300.0, 520.0, 220.0, 450.0, 5.0), [
		sk(0, "grave_necromancer.bolt", "腐蚀箭", "Corruption Bolt", 2.2, 0.7, "cast", 15.0, ["ranged"],
			[{"t": 0.4, "type": "projectile", "sfx": "curse", "visual": "blood", "color": DARK, "speed": 18.0, "range": 18.0, "aim": "target",
			"hit": hit(0.9, {"type": "magic", "statuses": [st("poison", 4.0, 0.8)]})}]),
		sk(1, "grave_necromancer.raise", "亡者复苏", "Raise Dead", 16.0, 1.2, "summon", 12.0, ["summon"],
			[{"t": 0.3, "type": "sfx", "name": "dark_chant"}, {"t": 0.8, "type": "summon", "summon_id": "bone_minion", "count": 1, "duration": 20.0, "max_active": 1, "offset": 2.0}]),
	])
	d["bone_minion"] = mob("骷髅小兵", "Bone Minion", "skeleton_minion", "skeleton_blade", "", BONE, 0.8, "melee",
		stats(2200.0, 350.0, 200.0, 150.0, 150.0, 5.6), [
		sk(0, "bone_minion.claw", "骨爪", "Bone Claw", 1.2, 0.5, "attack_1h_1", 2.0, ["melee"],
			[{"t": 0.0, "type": "sfx", "name": "skeleton"}, {"t": 0.25, "type": "sfx", "name": "swing_claw"}, {"t": 0.25, "type": "melee", "range": 2.0, "hit": hit(0.8)}]),
	])
	# Elite: Bone Champion (orc warlord type).
	d["bone_champion"] = mob("骨甲统领", "Bone Champion", "skeleton_warrior", "skeleton_mace_large", "", BONE, 1.4, "elite",
		stats(34000.0, 620.0, 400.0, 420.0, 360.0, 5.0), [
		sk(0, "bone_champion.smash", "碎骨击", "Bone Smash", 1.6, 0.8, "attack_2h", 2.8, ["melee"],
			[{"t": 0.45, "type": "sfx", "name": "swing_heavy"}, {"t": 0.45, "type": "melee", "range": 3.0, "arc": 120.0, "hit": hit(1.3, {"knockback": 3.0})}]),
		sk(1, "bone_champion.whirl", "骨刃旋风", "Bone Whirlwind", 9.0, 1.6, "attack_spin", 3.5, ["aoe", "melee"],
			[{"t": 0.1, "type": "sfx", "name": "swing_spin"}, {"t": 0.1, "type": "multi_melee", "shape": "circle", "range": 3.4, "count": 5, "interval": 0.25, "hit": hit(0.6)}],
			{"move_while_casting": true}),
		sk(2, "bone_champion.stomp", "震地", "War Stomp", 11.0, 1.4, "attack_slam", 5.0, ["aoe", "cc"],
			[{"t": 0.0, "type": "sfx", "name": "monster"}, {"t": 0.1, "type": "ground", "at": "self", "radius": 5.0, "delay": 1.0, "visual": "earth", "color": BONE,
			"hit": hit(1.6, {"stun": 1.2})}]),
		sk(3, "bone_champion.cry", "战吼", "Battle Cry", 16.0, 0.8, "taunt", 0.0, ["buff_ally"],
			[{"t": 0.3, "type": "sfx", "name": "monster"}, {"t": 0.3, "type": "buff", "target": "allies", "radius": 14.0, "statuses": [st("atk_up", 8.0, 0.25)]}]),
	])


# =============================================================================== trash: Frost Forest
static func _trash_frost(d: Dictionary) -> void:
	# Rogue type: fast wolf that leaps behind its prey.
	d["frost_wolf"] = mob("霜狼", "Frost Wolf", "werewolf", "", "", ICE, 0.95, "melee",
		stats(7000.0, 500.0, 300.0, 240.0, 260.0, 7.0), [
		sk(0, "frost_wolf.bite", "撕咬", "Bite", 1.1, 0.5, "attack", 2.0, ["melee"],
			[{"t": 0.0, "type": "sfx", "name": "wolf"}, {"t": 0.25, "type": "sfx", "name": "swing_claw"}, {"t": 0.25, "type": "melee", "range": 2.1, "hit": hit(0.9, {"statuses": [st("slow", 2.0, 0.2)]})}]),
		sk(1, "frost_wolf.flank", "包抄", "Flanking Leap", 8.0, 0.7, "leap", 12.0, ["gap_closer", "melee"],
			[{"t": 0.3, "type": "sfx", "name": "wolf"}, {"t": 0.0, "type": "blink", "to": "behind_target", "distance": 12.0},
			{"t": 0.35, "type": "melee", "range": 2.2, "hit": hit(1.5, {"crit_bonus": 0.25})}]),
	])
	# Melee grunt.
	d["orc_raider"] = mob("兽人掠夺者", "Orc Raider", "orc_raider", "orc_axe", "", ORC, 1.05, "melee",
		stats(9500.0, 500.0, 300.0, 300.0, 240.0, 5.2), [
		sk(0, "orc_raider.chop", "斧劈", "Axe Chop", 1.5, 0.6, "attack_1h_1", 2.4, ["melee"],
			[{"t": 0.3, "type": "sfx", "name": "swing"}, {"t": 0.3, "type": "melee", "range": 2.5, "hit": hit(1.0)}]),
		sk(1, "orc_raider.rush", "野蛮冲撞", "Savage Rush", 9.0, 0.8, "dash", 8.0, ["gap_closer", "melee"],
			[{"t": 0.1, "type": "sfx", "name": "orc"}, {"t": 0.1, "type": "dash", "direction": "target", "distance": 8.0, "speed": 20.0, "hit": hit(1.2, {"knockback": 5.0})}]),
	])
	# Shield bearer.
	d["orc_guard"] = mob("兽人盾卫", "Orc Shieldbearer", "orc_raider", "orc_axe", "skeleton_shield", ORC, 1.1, "tank",
		stats(13500.0, 430.0, 300.0, 540.0, 300.0, 4.6), [
		sk(0, "orc_guard.bash", "盾击", "Shield Bash", 1.8, 0.6, "attack_1h_2", 2.2, ["melee", "cc"],
			[{"t": 0.3, "type": "sfx", "name": "shield"}, {"t": 0.3, "type": "melee", "range": 2.3, "hit": hit(0.8, {"stun": 0.5})}]),
		sk(1, "orc_guard.wall", "盾墙", "Shield Wall", 9.0, 0.3, "block", 0.0, ["defensive", "buff_self"],
			[{"t": 0.0, "type": "sfx", "name": "orc"}, {"t": 0.0, "type": "buff", "target": "self", "statuses": [st("block", 4.0, 0.75)]}]),
	])
	# Archer.
	d["ice_archer"] = mob("冰霜弩手", "Frost Crossbowman", "skeleton_rogue", "skeleton_crossbow", "", ICE, 1.0, "ranged",
		stats(6500.0, 520.0, 300.0, 200.0, 240.0, 5.4), [
		sk(0, "ice_archer.shot", "冰棱箭", "Icicle Bolt", 1.6, 0.6, "shoot_2h", 16.0, ["ranged"],
			[{"t": 0.35, "type": "projectile", "sfx": "bow_shot", "visual": "arrow", "color": ICE, "speed": 26.0, "range": 20.0, "aim": "target",
			"hit": hit(0.9, {"statuses": [st("slow", 2.0, 0.2)]})}]),
		sk(1, "ice_archer.volley", "冰雨齐射", "Frost Volley", 8.0, 1.0, "shoot_2h", 14.0, ["ranged", "aoe"],
			[{"t": 0.6, "type": "projectile", "sfx": "bow_shot", "visual": "arrow", "color": ICE, "count": 3, "spread": 24.0, "speed": 24.0,
			"range": 18.0, "aim": "target", "hit": hit(0.8)}]),
	])
	# Caster + healer: telegraphed blizzard and a frost mend.
	d["frost_shaman"] = mob("冰霜祭司", "Frost Shaman", "skeleton_mage", "skeleton_staff", "", ICE, 1.0, "healer",
		stats(7000.0, 300.0, 560.0, 200.0, 420.0, 5.0), [
		sk(0, "frost_shaman.bolt", "寒冰箭", "Frost Bolt", 2.0, 0.7, "cast", 15.0, ["ranged"],
			[{"t": 0.4, "type": "projectile", "sfx": "ice_cast", "visual": "orb", "color": ICE, "speed": 18.0, "range": 18.0, "aim": "target",
			"hit": hit(1.0, {"type": "magic", "element": "ice", "statuses": [st("slow", 2.0, 0.25)]})}]),
		sk(1, "frost_shaman.blizzard", "暴风雪", "Blizzard", 8.0, 1.0, "cast_long", 14.0, ["aoe", "ranged", "zone"],
			[{"t": 0.2, "type": "sfx", "name": "ice_cast"}, {"t": 0.2, "type": "ground", "at": "target", "radius": 3.5, "delay": 1.2, "duration": 3.0, "tick": 0.5,
			"visual": "ice", "color": ICE, "hit": hit(0.5, {"type": "magic", "hitstun": 0.1, "knockback": 0.0,
			"statuses": [st("slow", 1.5, 0.35)]})}]),
		sk(2, "frost_shaman.mend", "寒霜愈合", "Frost Mend", 7.0, 1.0, "heal", 16.0, ["heal"],
			[{"t": 0.0, "type": "sfx", "name": "ice_charge"}, {"t": 0.6, "type": "heal", "target": "ally_lowest", "radius": 18.0, "amount": 0.12}]),
	])
	# Elite werewolf.
	d["werewolf_elite"] = mob("狼人首领", "Werewolf Alpha", "werewolf_man", "", "", BLOOD, 1.35, "elite",
		stats(32000.0, 620.0, 400.0, 400.0, 360.0, 6.0), [
		sk(0, "werewolf_elite.claws", "裂爪连击", "Claw Flurry", 1.6, 0.9, "punch_combo", 2.6, ["melee"],
			[{"t": 0.0, "type": "sfx", "name": "mob_snarl"}, {"t": 0.15, "type": "sfx", "name": "swing_claw"}, {"t": 0.15, "type": "multi_melee", "range": 2.8, "count": 3, "interval": 0.18, "hit": hit(0.6)}]),
		sk(1, "werewolf_elite.pounce", "扑杀", "Pounce", 9.0, 0.9, "leap", 11.0, ["gap_closer", "aoe"],
			[{"t": 0.1, "type": "sfx", "name": "growl"}, {"t": 0.1, "type": "leap", "to": "target", "distance": 11.0, "height": 3.0, "duration": 0.55,
			"land": {"radius": 2.6, "hit": hit(1.5, {"knockdown": true})}}]),
		sk(2, "werewolf_elite.howl", "嗜血嚎叫", "Blood Howl", 15.0, 0.9, "taunt", 0.0, ["buff_self"],
			[{"t": 0.3, "type": "sfx", "name": "growl"}, {"t": 0.3, "type": "buff", "target": "self", "statuses": [st("atk_up", 8.0, 0.3), st("haste", 8.0, 0.2)]}]),
		sk(3, "werewolf_elite.rend", "撕裂大地", "Rending Earth", 11.0, 1.3, "attack_slam", 4.0, ["aoe"],
			[{"t": 0.1, "type": "sfx", "name": "mob_snarl"}, {"t": 0.1, "type": "ground", "at": "self", "radius": 4.2, "delay": 0.9, "visual": "blood", "color": BLOOD,
			"hit": hit(2.0, {"launch": 7.0})}]),
	])
	# Elite orc.
	d["orc_warlord"] = mob("兽人督军", "Orc Warlord", "orc_raider", "orc_axe_large", "", ORC, 1.4, "elite",
		stats(34000.0, 630.0, 400.0, 430.0, 340.0, 5.0), [
		sk(0, "orc_warlord.cleave", "顺劈", "Cleave", 1.7, 0.8, "attack_2h", 2.8, ["melee"],
			[{"t": 0.2, "type": "sfx", "name": "orc"}, {"t": 0.45, "type": "sfx", "name": "swing_heavy"}, {"t": 0.45, "type": "melee", "range": 3.0, "arc": 130.0, "hit": hit(1.3, {"knockback": 3.0})}]),
		sk(1, "orc_warlord.whirl", "旋风斩", "Whirlwind", 9.0, 1.6, "attack_spin", 3.5, ["aoe", "melee"],
			[{"t": 0.1, "type": "sfx", "name": "swing_spin"}, {"t": 0.1, "type": "multi_melee", "shape": "circle", "range": 3.4, "count": 5, "interval": 0.25, "hit": hit(0.6)}],
			{"move_while_casting": true}),
		sk(2, "orc_warlord.stomp", "战争践踏", "War Stomp", 11.0, 1.4, "attack_slam", 5.0, ["aoe", "cc"],
			[{"t": 0.0, "type": "sfx", "name": "orc"}, {"t": 0.1, "type": "ground", "at": "self", "radius": 5.0, "delay": 1.0, "visual": "earth", "color": ORC,
			"hit": hit(1.6, {"stun": 1.2})}]),
		sk(3, "orc_warlord.cry", "战吼", "Battle Cry", 16.0, 0.8, "taunt", 0.0, ["buff_ally"],
			[{"t": 0.3, "type": "sfx", "name": "orc"}, {"t": 0.3, "type": "buff", "target": "allies", "radius": 14.0, "statuses": [st("atk_up", 8.0, 0.25)]}]),
	])


# =============================================================================== bosses
## Shared boss "animation" skills used by BossBrain for brain-run mechanics (no hit steps):
## slot 5 = telegraph cast pose, slot 6 = interruptible channel, slot 4 = roar (phase change).
static func _anim_skills(prefix: String) -> Array:
	return [
		sk(4, prefix + ".roar", "怒吼", "Roar", 0.0, 1.4, "taunt", 0.0, ["buff_self"],
			[{"t": 0.0, "type": "vfx", "name": "ultimate_flash"}, {"t": 0.2, "type": "sfx", "name": "boss_roar"}]),
		sk(5, prefix + ".invoke", "施法", "Invoke", 0.0, 1.2, "cast_long", 0.0, [],
			[{"t": 0.0, "type": "vfx", "name": "cast_glow"}]),
		sk(6, prefix + ".channel", "引导", "Channel", 0.0, 4.0, "channel", 0.0, [],
			[{"t": 0.0, "type": "vfx", "name": "cast_glow"}, {"t": 2.0, "type": "vfx", "name": "cast_glow"}]),
	]


static func _frost_golem() -> Dictionary:
	var skills: Array = [
		# Melee ranges are measured from the boss centre: body radius 1.3 + ~3.3 m of reach.
		sk(0, "frost_golem.smash", "冰拳", "Frost Smash", 0.5, 1.0, "attack_2h", 4.4, ["melee"],
			[{"t": 0.2, "type": "sfx", "name": "golem"}, {"t": 0.55, "type": "sfx", "name": "swing_heavy"}, {"t": 0.55, "type": "melee", "range": 4.6, "arc": 110.0, "hit": hit(0.8, {"knockback": 3.0, "element": "ice"})}]),
		# Tank-buster frontal cleave: a long telegraphed line toward the current threat target.
		sk(1, "frost_golem.cleave", "冰川裂斩", "Glacial Cleave", 0.5, 2.0, "attack_slam", 10.0, ["melee", "tank_buster"],
			[{"t": 0.0, "type": "sfx", "name": "golem"}, {"t": 0.0, "type": "vfx", "name": "cast_glow"},
			{"t": 0.1, "type": "ground", "at": "target", "shape": "line", "length": 12.0, "width": 5.0, "delay": 1.3,
			"visual": "ice", "color": ICE, "hit": hit(4.0, {"knockdown": true, "knockback": 6.0, "element": "ice"})}]),
		sk(2, "frost_golem.stomp", "霜震", "Frost Quake", 0.5, 1.5, "attack_slam", 6.0, ["aoe"],
			[{"t": 0.0, "type": "sfx", "name": "golem"}, {"t": 0.1, "type": "ground", "at": "self", "radius": 6.0, "delay": 0.9, "visual": "ice", "color": ICE,
			"hit": hit(1.8, {"type": "magic", "knockback": 7.0, "statuses": [st("slow", 3.0, 0.4)]})}]),
	]
	skills.append_array(_anim_skills("frost_golem"))
	var def := mob("冰霜巨人", "Frost Golem", "frost_golem", "frost_golem_axe", "", ICE, 1.35, "boss",
		stats(600000.0, 510.0, 590.0, 500.0, 450.0, 4.6, {"crit": 0.0}), skills)
	def["boss"] = {
		"arena_radius": 22.0,
		"melee_range": 3.0,
		"add_hp": 0.5,
		"add_life": 20.0,
		"add_dmg": 0.6,
		"gcd": 2.0,
		"enrage": {"hp": 0.10, "atk_up": 0.0, "haste": 0.2, "cd_mult": 0.9,
			"cn": "冰霜巨人进入红血狂暴！", "en": "Frost Golem is enraged (red blood)!"},
		"berserk": {"time": 360.0, "atk_up": 1.5, "haste": 0.5, "cn": "冰霜巨人狂暴了：极寒风暴吞没一切！", "en": "The Frost Golem goes berserk: the blizzard swallows all!"},
		"phases": [
			{"hp": 1.0, "abilities": ["cleave", "ice_zones", "smash"]},
			{"hp": 0.70, "cn": "第二阶段：冰霜巨人召唤了霜狼！", "en": "Phase 2: the Frost Golem calls the wolves!",
				"adds": ["frost_wolf", "frost_wolf"],
				"abilities": ["avalanche", "frost_bomb", "cleave", "stomp", "ice_zones", "smash"]},
			{"hp": 0.40, "cn": "第三阶段：冰封之心苏醒！", "en": "Phase 3: the Frozen Heart awakens!",
				"adds": ["ice_archer", "frost_wolf"],
				"abilities": ["frozen_heart", "ice_comet", "avalanche", "frost_bomb", "cleave", "stomp", "ice_zones", "smash"]},
		],
		"abilities": {
			"smash": {"kind": "skill", "slot": 0, "cd": 2.8, "melee": true},
			"cleave": {"kind": "skill", "slot": 1, "cd": 16.0, "first": 6.0, "melee": true,
				"cn": "冰川裂斩！坦克顶住，其他人离开正面！", "en": "Glacial Cleave! Tank it, everyone else leave the front!"},
			"stomp": {"kind": "skill", "slot": 2, "cd": 16.0, "first": 4.0, "melee": true},
			"ice_zones": {"kind": "zones", "cd": 15.0, "first": 3.0, "count": 2, "radius": 3.0, "delay": 0.9, "duration": 7.0,
				"tick": 0.5, "visual": "ice", "color": ICE,
				"hit": hit(0.08, {"type": "magic", "hitstun": 0.0, "knockback": 0.0, "statuses": [st("slow", 1.5, 0.45)]}),
				"burst": hit(1.4, {"type": "magic", "statuses": [st("freeze", 1.5)]})},
			"frost_bomb": {"kind": "spread", "cd": 26.0, "first": 8.0, "radius": 3.2, "delay": 1.3, "visual": "ice", "color": ICE,
				"hit": hit(1.8, {"type": "magic", "statuses": [st("freeze", 2.0)]}),
				"cn": "霜冻炸弹：散开！", "en": "Frost Bomb: SPREAD OUT!"},
			"avalanche": {"kind": "raid_aoe", "cd": 36.0, "first": 14.0, "delay": 2.6, "radius": 40.0, "visual": "ice", "color": ICE,
				"hit": hit(1.5, {"type": "magic", "knockdown": true, "element": "ice"}),
				"cn": "雪崩即将来临！治疗准备！", "en": "Avalanche incoming! Healers get ready!"},
			"ice_comet": {"kind": "share", "cd": 28.0, "first": 5.0, "radius": 3.5, "delay": 3.0, "min": 2, "target": "random",
				"visual": "ice", "color": Color(0.7, 0.95, 1.0), "hit": hit(7.0, {"type": "magic", "knockdown": true}),
				"fail_hit": hit(3.0, {"type": "magic", "statuses": [st("freeze", 2.0)]}),
				"cn": "冰彗星：至少两人进入光圈分担！", "en": "Ice Comet: at least 2 players soak the circle!"},
			"frozen_heart": {"kind": "channel", "cd": 40.0, "first": 10.0, "time": 4.0, "heal": 0.05,
				"fail_hit": hit(2.5, {"type": "magic", "statuses": [st("freeze", 3.0)]}),
				"cn": "冰封之心：用控制技能打断！", "en": "Frozen Heart: interrupt it with crowd control!"},
		},
	}
	return def


static func _black_knight() -> Dictionary:
	var skills: Array = [
		# Melee ranges are measured from the boss centre: body radius 1.2 + ~3.2 m of reach.
		sk(0, "black_knight.slash", "暗影斩", "Shadow Slash", 0.5, 0.9, "attack_1h_1", 4.2, ["melee"],
			[{"t": 0.5, "type": "sfx", "name": "swing_heavy"}, {"t": 0.5, "type": "melee", "range": 4.4, "arc": 120.0, "hit": hit(0.8, {"knockback": 3.0, "element": "dark"})}]),
		# Tank-buster frontal cleave.
		sk(1, "black_knight.execution", "处刑", "Execution", 0.5, 2.0, "attack_2h", 9.0, ["melee", "tank_buster"],
			[{"t": 0.0, "type": "sfx", "name": "growl"}, {"t": 0.0, "type": "vfx", "name": "cast_glow", "color": BLOOD},
			{"t": 0.1, "type": "ground", "at": "target", "shape": "line", "length": 11.0, "width": 4.0, "delay": 1.3,
			"visual": "blood", "color": BLOOD, "hit": hit(3.5, {"knockdown": true, "knockback": 6.0, "element": "dark"})}]),
		# Telegraphed charge at the farthest player.
		sk(2, "black_knight.charge", "暗影冲锋", "Shadow Charge", 0.5, 1.9, "dash", 18.0, ["gap_closer"],
			[{"t": 0.0, "type": "sfx", "name": "armor"}, {"t": 0.9, "type": "sfx", "name": "dash"}, {"t": 0.0, "type": "ground", "at": "target", "shape": "line", "length": 16.0, "width": 3.0, "delay": 0.9,
			"visual": "dark", "color": DARK, "hit": hit(2.4, {"knockdown": true, "knockback": 8.0})},
			{"t": 0.9, "type": "dash", "direction": "forward", "distance": 15.0, "speed": 30.0, "through_enemies": true}]),
	]
	skills.append_array(_anim_skills("black_knight"))
	var def := mob("黑骑士", "Black Knight", "black_knight", "black_knight_sword", "black_knight_shield", DARK, 1.35, "boss",
		stats(580000.0, 550.0, 590.0, 520.0, 460.0, 4.8, {"crit": 0.0}), skills)
	def["boss"] = {
		"arena_radius": 22.0,
		"melee_range": 3.0,
		"add_hp": 0.5,
		"add_life": 20.0,
		"add_dmg": 0.6,
		"gcd": 1.9,
		"enrage": {"hp": 0.10, "atk_up": 0.0, "haste": 0.2, "cd_mult": 0.9,
			"cn": "黑骑士进入红血狂暴！", "en": "The Black Knight is enraged (red blood)!"},
		"berserk": {"time": 300.0, "atk_up": 1.5, "haste": 0.5, "cn": "黑骑士狂暴了：死亡降临！", "en": "The Black Knight goes berserk: death descends!"},
		"phases": [
			{"hp": 1.0, "abilities": ["execution", "charge", "grave_spikes", "slash"]},
			{"hp": 0.70, "cn": "第二阶段：亡灵巫师响应召唤！", "en": "Phase 2: the necromancers answer the call!",
				"adds": ["grave_necromancer", "grave_necromancer", "bone_minion"],
				"abilities": ["death_tide", "bone_prison", "execution", "charge", "grave_spikes", "slash"]},
			{"hp": 0.40, "cn": "第三阶段：灵魂收割！", "en": "Phase 3: Soul Harvest!",
				"adds": ["skeleton_rogue", "skeleton_mage"],
				"abilities": ["soul_harvest", "death_tide", "bone_prison", "execution", "charge", "grave_spikes", "slash"]},
		],
		"abilities": {
			"slash": {"kind": "skill", "slot": 0, "cd": 2.7, "melee": true},
			"execution": {"kind": "skill", "slot": 1, "cd": 16.0, "first": 6.0, "melee": true,
				"cn": "处刑！坦克顶住，其他人离开正面！", "en": "Execution! Tank it, everyone else leave the front!"},
			"charge": {"kind": "skill", "slot": 2, "cd": 18.0, "first": 9.0, "target": "far",
				"cn": "暗影冲锋：避开路径！", "en": "Shadow Charge: get out of the path!"},
			"grave_spikes": {"kind": "cross", "cd": 16.0, "first": 3.0, "length": 18.0, "width": 2.6, "delay": 0.85,
				"waves": 2, "visual": "thorn", "color": BONE, "hit": hit(1.8, {"launch": 8.0})},
			"bone_prison": {"kind": "share", "cd": 26.0, "first": 6.0, "radius": 4.0, "delay": 2.8, "min": 3, "target": "random",
				"visual": "dark", "color": DARK, "hit": hit(7.5, {"type": "magic", "knockdown": true}),
				"fail_hit": hit(3.0, {"type": "magic", "statuses": [st("def_down", 6.0, 0.2)]}),
				"cn": "骨牢：所有人集合分担伤害！", "en": "Bone Prison: STACK to share the damage!"},
			"death_tide": {"kind": "raid_aoe", "cd": 34.0, "first": 12.0, "delay": 2.6, "radius": 40.0, "visual": "dark", "color": DARK,
				"hit": hit(1.8, {"type": "magic", "statuses": [st("bleed", 6.0, 1.0)]}),
				"cn": "死亡之潮即将来临！治疗准备！", "en": "Death Tide incoming! Healers get ready!"},
			"soul_harvest": {"kind": "channel", "cd": 38.0, "first": 8.0, "time": 4.0, "heal": 0.06,
				"fail_hit": hit(2.5, {"type": "magic", "true_damage": false, "lifesteal": 0.0, "statuses": [st("silence", 3.0)]}),
				"cn": "灵魂收割：用控制技能打断！", "en": "Soul Harvest: interrupt it with crowd control!"},
		},
	}
	return def
