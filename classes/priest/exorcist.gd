extends ClassKit
## 驱魔师 Exorcist (圣职系 Priest) - control / utility with a War Scythe and paper talismans.
## Signature mechanic: the loaded elemental talisman (落雷 Lightning -> 寒冰 Ice -> 烈焰 Fire) cycles every time
## the elemental talisman skill is thrown; Spirit Guidance's thrown scythe carries the loaded talisman's effect.

const TALISMAN_META: StringName = &"exorcist_talisman"
const ELEMENTS: Array[String] = ["lightning", "ice", "fire"]
const ELEMENT_NAMES: Array[String] = ["落雷符 Lightning Talisman", "寒冰符 Ice Talisman", "烈焰符 Fire Talisman"]
## Seal = CORE `atk_down` status (patk & matk x(1 - power); NEGATIVE, so cleanse removes it).
const SEAL_DMG_DOWN: float = 0.15
const ELEMENT_COLORS: Array[Color] = [Color(0.6, 0.75, 1.0), Color(0.55, 0.9, 1.0), Color(1.0, 0.5, 0.15)]


func define() -> void:
	id = "exorcist"
	name_cn = "驱魔师"
	name_en = "Exorcist"
	group_id = "priest"
	group_cn = "圣职系"
	group_en = "Priest"
	role = "control"
	weapon_type = "war_scythe"
	weapon_name_cn = "战镰"
	weapon_name_en = "War Scythe"
	offhand = ""
	model = "exorcist"
	tint = Color(0.68, 0.45, 1.0)
	famous = "田森 Tian Sen / 扫地焚香 Peaceful Hermit / 即死领悟 Death Savvy"
	stats = {"hp": 7200.0, "mp": 1300.0, "mp_regen": 21.0, "patk": 520.0, "matk": 590.0,
		"pdef": 380.0, "mdef": 460.0, "move_speed": 6.1, "jump_velocity": 9.0,
		"cast_speed": 1.0, "atk_speed": 0.9}

	# ------------------------------------------------------------ slot 0: basic chain (普攻)
	var atk1 := sk(0, "atk1", "普攻·镰斩", "Basic Attack: Scythe Reap", 0.0, 0.0, 0.38, &"attack_2h", 3.0, ["melee", "combo"],
		[{"t": 0.14, "type": "melee", "range": 3.0, "arc": 130.0, "hit": hit(0.72, {"hitstun": 0.35, "knockback": 1.0})},
		{"t": 0.12, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.15, "chain": ["atk1", "atk2", "atk3"], "desc": "战镰大弧横扫 Wide scythe reap."})
	sk(0, "atk2", "普攻·回镰", "Basic Attack: Return Reap", 0.0, 0.0, 0.38, &"attack_1h_2", 3.0, ["melee", "combo"],
		[{"t": 0.14, "type": "melee", "range": 3.0, "arc": 130.0, "hit": hit(0.72, {"hitstun": 0.35, "knockback": 1.0})},
		{"t": 0.12, "type": "sfx", "name": "swing"}],
		{"cancel_window": 0.15, "desc": "反手回镰 Backhand reap."})
	sk(0, "atk3", "普攻·旋镰", "Basic Attack: Scythe Spin", 0.0, 0.0, 0.5, &"attack_spin", 3.0, ["melee", "finisher", "aoe"],
		[{"t": 0.2, "type": "melee", "shape": "circle", "range": 3.0, "fx": "slash_arc",
		"hit": hit(0.95, {"hitstun": 0.5, "knockback": 4.0})},
		{"t": 0.18, "type": "sfx", "name": "slash"}],
		{"cancel_window": 0.12, "desc": "旋身一周的镰刃收尾 Spinning scythe finisher."})

	# ------------------------------------------------------------ slot 1: launcher (Priest Lv1)
	var rising := sk(1, "rising_emblem", "升天阵", "Rising Emblem", 6.0, 45.0, 0.4, &"cast", 9.0,
		["launcher", "aoe", "ranged", "combo", "cc"],
		[{"t": 0.12, "type": "ground", "at": "target", "radius": 2.4, "delay": 0.25, "visual": "rune",
		"color": Color(0.75, 0.6, 1.0), "hit": hit(1.15, {"type": "magic", "launch": 10.0, "knockback": 0.0, "element": "holy"})},
		{"t": 0.1, "type": "sfx", "name": "magic"}],
		{"cancel_window": 0.15, "desc": "目标脚下浮现法阵将其击飞 A rune circle erupts under the target and launches it."})

	# ------------------------------------------------------------ slot 2: grab / pull
	var hook := sk(2, "hook", "勾魂", "Hook", 9.0, 50.0, 0.45, &"grab", 3.5,
		["grab", "melee", "cc", "combo"],
		[{"t": 0.1, "type": "grab", "range": 3.5, "arc": 70.0, "grab_time": 0.5, "end_on_miss": true,
		"hit": hit(1.3, {"element": "dark", "hitstun": 0.3}), "throw": {"dir": "up", "force": 8.5}},
		{"t": 0.1, "type": "sfx", "name": "grab"}],
		{"desc": "镰刃勾住敌人魂魄拉回并挑起 Hooks the enemy's soul with the scythe and flings it up (breaks super armor)."})

	# ------------------------------------------------------------ slot 3: thrown scythe
	var spirit := sk(3, "spirit_guidance", "魂御", "Spirit Guidance", 7.0, 50.0, 0.4, &"throw", 14.0,
		["ranged", "debuff", "combo"],
		[{"t": 0.15, "type": "custom", "method": "throw_scythe", "args": {}}],
		{"cancel_window": 0.15, "desc": "掷出附带符咒的战镰，贯穿并附加当前符咒效果 Throws the scythe carrying the loaded talisman; pierces."})

	# ------------------------------------------------------------ slot 4: elemental talismans
	var elemental := sk(4, "elemental_talisman", "落雷符 / 寒冰符 / 烈焰符", "Lightning / Ice / Fire Talisman", 4.0, 40.0, 0.35, &"throw", 13.0,
		["ranged", "cc", "debuff"],
		[{"t": 0.12, "type": "custom", "method": "throw_talisman", "args": {}},
		{"t": 0.1, "type": "sfx", "name": "magic"}],
		{"cancel_window": 0.15, "desc": "依次掷出落雷/寒冰/烈焰符：麻痹、冰冻或灼烧 Throws the next talisman: lightning stun, ice freeze or fire burn."})

	# ------------------------------------------------------------ slot 5: utility talismans
	var utility := sk(5, "binding_talismans", "定身符 / 硬身符 / 加速符", "Immobilizing / Hardening / Speed Talisman", 13.0, 60.0, 0.35, &"cast", 10.0,
		["cc", "debuff", "buff_self"],
		[{"t": 0.1, "type": "debuff", "target": "target", "radius": 6.0, "statuses": [st("root", 2.5)], "fx": "debuff_puff"},
		{"t": 0.12, "type": "buff", "target": "self", "statuses": [st("super_armor", 3.0), st("haste", 4.0, 0.3)]},
		{"t": 0.1, "type": "sfx", "name": "debuff"}],
		{"desc": "定身敌人，自身贴上硬身符与加速符 Roots the target; hardening and speed talismans give self super armor and haste."})

	# ------------------------------------------------------------ slot 6: Star Fall
	var star_fall := sk(6, "star_fall", "星落", "Star Fall", 11.0, 70.0, 0.55, &"cast_long", 12.0,
		["aoe", "ranged", "cc"],
		[{"t": 0.2, "type": "projectile", "from": "sky", "sky_height": 13.0, "aim": "target", "visual": "star",
		"speed": 34.0, "range": 30.0, "radius": 0.6, "scale": 2.0, "color": Color(1.0, 0.9, 0.5),
		"hit": hit(0.4, {"type": "magic", "hitstun": 0.2}),
		"explode": {"radius": 3.2, "fx": "holy_burst",
		"hit": hit(1.6, {"type": "magic", "knockdown": true, "knockback": 3.0, "element": "holy"})}},
		{"t": 0.15, "type": "vfx", "name": "cast_glow"},
		{"t": 0.15, "type": "sfx", "name": "cast"}],
		{"cancel_window": 0.15, "desc": "召唤星辰坠落震地，击倒范围内敌人 A falling star quakes the ground and knocks foes down."})

	# ------------------------------------------------------------ slot 7: ultimate
	var seal := sk(7, "seal_talisman", "封禁符", "Seal Talisman", 75.0, 220.0, 1.5, &"cast_long", 12.0,
		["ultimate", "aoe", "ranged", "cc", "debuff"],
		[{"t": 0.0, "type": "buff", "target": "self", "statuses": [st("super_armor", 1.6)]},
		{"t": 0.0, "type": "vfx", "name": "ultimate_flash"},
		{"t": 0.0, "type": "sfx", "name": "ultimate"},
		{"t": 0.3, "type": "ground", "at": "target", "radius": 3.8, "delay": 0.3, "visual": "rune", "color": Color(0.9, 0.3, 0.3),
		"hit": hit(1.6, {"type": "magic", "hitstun": 0.6, "statuses": [st("silence", 3.0), st("weight", 8.0, 0.3)]})},
		{"t": 1.2, "type": "ground", "at": "target", "radius": 3.8, "visual": "dark", "color": Color(0.8, 0.2, 0.4),
		"hit": hit(2.1, {"type": "magic", "launch": 7.0, "armor_break": true,
		"statuses": [st("def_down", 12.0, 0.25), st("mark", 12.0), st("atk_down", 12.0, SEAL_DMG_DOWN)], "seal": 12.0})},
		{"t": 1.2, "type": "sfx", "name": "explosion"}],
		{"desc": "封禁符压制敌人装备：沉默、降防、加重并重创 Seal talisman locks enemy gear: silence, defence down, weight, heavy damage."})

	skills = [atk1, rising, hook, spirit, elemental, utility, star_fall, seal]

	passives = [
		{"name_cn": "符咒", "name_en": "Talismans",
		"desc": "元素符按落雷→寒冰→烈焰轮换；魂御掷出的战镰附带当前符咒效果 Elemental talismans cycle Lightning -> Ice -> Fire; Spirit Guidance carries the loaded talisman."},
		{"name_cn": "封禁", "name_en": "Seal",
		"desc": "被封禁符命中的敌人攻击力降低15% Enemies hit by Seal Talisman deal 15% less damage while sealed."},
	]


# ---------------------------------------------------------------- talisman helpers
func talisman_index(f: Fighter) -> int:
	return int(f.get_meta(TALISMAN_META, 0)) % ELEMENTS.size()


func _element_statuses(idx: int) -> Array:
	match ELEMENTS[idx]:
		"lightning":
			return [st("stun", 0.6)]
		"ice":
			return [st("slow", 3.0, 0.35), st("freeze", 0.7)]
		_:
			return [st("burn", 4.0, 1.0)]


## Custom action: throws the loaded elemental talisman and loads the next one.
func throw_talisman(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var idx := talisman_index(f)
	var elem := ELEMENTS[idx]
	var proj: Dictionary = {"type": "projectile", "visual": "lightning" if elem == "lightning" else "orb", "speed": 30.0,
		"range": 15.0, "radius": 0.45, "aim": "target", "color": ELEMENT_COLORS[idx], "sfx": "throw"}
	match elem:
		"lightning":
			proj["hit"] = hit(1.25, {"type": "magic", "element": "lightning", "hitstun": 0.4, "statuses": _element_statuses(idx)})
		"ice":
			proj["hit"] = hit(1.15, {"type": "magic", "element": "ice", "hitstun": 0.4, "statuses": _element_statuses(idx)})
		_:
			proj["hit"] = hit(0.6, {"type": "magic", "element": "fire", "hitstun": 0.3})
			proj["explode"] = {"radius": 2.2, "fx": "fire_burst",
				"hit": hit(0.75, {"type": "magic", "element": "fire", "knockback": 2.0, "statuses": _element_statuses(idx)})}
	runner.execute_step(proj)
	runner.vars["talisman"] = elem
	f.set_meta(TALISMAN_META, (idx + 1) % ELEMENTS.size())


## Custom action: Spirit Guidance - throws the scythe carrying the loaded talisman's statuses inside its hit.
func throw_scythe(f: Fighter, _args: Dictionary, runner: SkillRunner) -> void:
	var idx := talisman_index(f)
	runner.execute_step({"type": "projectile", "visual": "scythe", "speed": 24.0, "range": 15.0, "radius": 0.6,
		"pierce": true, "aim": "target", "scale": 1.3, "sfx": "throw",
		"hit": hit(1.4, {"hitstun": 0.45, "knockback": 1.5, "talisman_fx": idx, "statuses": _element_statuses(idx)})})


# ---------------------------------------------------------------- hooks
func on_hit_dealt(f: Fighter, victim: Fighter, h: Dictionary, _dmg: float) -> void:
	if victim == null or not is_instance_valid(victim) or not victim.is_alive():
		return
	# Visual only: the talisman / seal statuses travel in the hit itself, so CORE's block / invuln / downed gating applies.
	if h.has("talisman_fx"):
		var idx := clampi(int(h["talisman_fx"]), 0, ELEMENTS.size() - 1)
		var fx_name: StringName = [&"lightning_strike", &"ice_burst", &"fire_burst"][idx]
		CoreUtil.fx(&"play", [fx_name, victim.center(), f.forward(), ELEMENT_COLORS[idx], 0.8])
	if h.has("seal"):
		CoreUtil.fx(&"play", [&"debuff_puff", victim.center(), victim.forward(), Color(0.9, 0.3, 0.3), 1.2])
