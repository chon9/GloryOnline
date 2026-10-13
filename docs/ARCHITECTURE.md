# Rongyao Arena — Architecture Contract

A Godot 4.7.2 (GDScript) 3D recreation of **Glory (荣耀)** from 全职高手 / The King's Avatar:
class-based, team-oriented arena combat. Modes: PvP (Individual 1v1, Group Arena 3v3 winner-stays,
Team Battle 5v5) and PvE Raid (5-player dungeon with trash + boss). **No leveling, no XP, no loot
progression.** Every character is "max level" from the start. AI bots fill any empty slot.
Multiplayer runs through Steam lobbies on app 480 (Spacewar) via GodotSteam, with ENet/LAN fallback,
plus fully offline play against bots.

This file is the contract between modules. If you implement a module, implement exactly the
names/signatures here. If something here is impossible, implement the closest thing and document the
deviation in `docs/DEVIATIONS.md` (append, never rewrite other sections).

Reference material (read what your module needs):
- `docs/research/glory-classes-verified.json` — canon classes, weapons, skills, core mechanics (UTF-8).
- `docs/research/godot-steam.md` — verified Godot 4.7.2 + GodotSteam 4.23.1 API reference + gotchas.
- `docs/research/assets-verified.json` — CC0 asset packs (KayKit, Kenney) and paths in the scratchpad.

Tooling:
- Headless console Godot: `K:/Godot_v4.7.2-stable_win64_console.exe`
- Refresh class cache after adding/removing `class_name` scripts:
  `& K:/Godot_v4.7.2-stable_win64_console.exe --headless --path K:/Project/RONGYAO --import`
- Parse-check: `... --headless --path K:/Project/RONGYAO --check-only -s res://path.gd`
- Smoke run a scene: `... --headless --path K:/Project/RONGYAO --quit-after 300 res://scene.tscn 2>&1`
  Exit code is 0 even on SCRIPT ERROR — grep output for `SCRIPT ERROR|Parse Error|ERROR:`.
- Always kill any Godot processes you launched before finishing.

---------------------------------------------------------------------------------------------------
## 1. Directory layout and ownership

```
res://
  project.godot                  (owner: lead; autoloads listed in §2)
  addons/godotsteam/             (third-party, do not edit)
  assets/                        (owner: ASSETS) imported CC0 art/audio
    characters/ anims/ weapons/ env/ vfx/ ui/ sfx/ fonts/
    CREDITS.md
  autoload/
    net.gd          Net          (owner: NET)
    game.gd         Game         (owner: NET)   match settings, roster, scene flow, input map
    registry.gd     Registry     (owner: CORE)  loads all ClassKits / mob defs
    fx.gd           Fx           (owner: ASSETS) cosmetic VFX/SFX spawning, network-replicated
  core/                          (owner: CORE)
    fighter.gd          class_name Fighter        extends CharacterBody3D
    fighter_input.gd    class_name FighterInput   extends RefCounted
    skill_def.gd        class_name SkillDef       extends RefCounted
    class_kit.gd        class_name ClassKit       extends RefCounted
    skill_runner.gd     class_name SkillRunner    extends RefCounted
    hit.gd              class_name Hit            extends RefCounted  (static helpers for HIT dicts)
    combat.gd           class_name Combat         extends RefCounted  (static damage resolution)
    status.gd           class_name StatusSet      extends RefCounted
    projectile.gd       class_name Projectile     extends Node3D      (host-simulated hit logic)
    area_effect.gd      class_name AreaEffect     extends Node3D      (ground AoE / zones / traps / beams)
    summon.gd           class_name Summon         (a Fighter subclass or Fighter with kind="summon")
    player_controller.gd class_name PlayerController extends Node    (local human input -> FighterInput)
    camera_rig.gd       class_name CameraRig      extends Node3D     (third-person camera, lock-on)
    world.gd            class_name World          extends Node3D     (spawning, fighter lookup, teams)
  classes/                       (owner: KITS) one file per class, extends ClassKit
    swordsman/ blade_master.gd berserker.gd spellblade.gd ghostblade.gd
    mage/      battle_mage.gd elementalist.gd witch.gd summoner.gd
    gunner/    sharpshooter.gd spitfire.gd launcher.gd mechanic.gd
    fighter/   striker.gd qi_master.gd grappler.gd brawler.gd
    nightwalker/ assassin.gd ninja.gd thief.gd warlock.gd
    priest/    knight.gd exorcist.gd cleric.gd paladin.gd
    unspecialized.gd             (散人 Lord Grim style, Myriad Manifestation Umbrella)
  visuals/                       (owner: ASSETS)
    character_visual.gd class_name CharacterVisual extends Node3D
    weapon_factory.gd   class_name WeaponFactory   extends RefCounted
  ai/                            (owner: AI)
    bot_brain.gd        class_name BotBrain        extends Node   (drives a Fighter like a player)
  pve/                           (owner: RAID)
    mob_defs.gd  boss_brain.gd  raid_director.gd  dungeon_frost_forest.gd ...
  modes/                         (owner: NET)
    match.gd            class_name Match           extends Node   (base: rounds, win checks)
    match_pvp.gd  match_arena.gd  match_raid.gd
  maps/                          (owner: MAPS)
    map_base.gd (class_name MapBase) + arena maps, built procedurally from KayKit dungeon pieces
  ui/                            (owner: UI)
    main_menu.tscn/.gd  lobby.tscn/.gd  hud.gd  results.gd  theme.tres
  scenes/
    main.tscn            entry (run/main_scene) -> main menu
    match.tscn           World + map + HUD
  tests/                         headless test scripts (anyone may add test_<module>_*.gd)
```

Ownership means "who creates and edits it". Do not edit files owned by another module; if you need a
change there, document the need in `docs/DEVIATIONS.md` under a `## Requests` heading and work around it.

---------------------------------------------------------------------------------------------------
## 2. Autoloads (order matters; already registered in project.godot by the lead)

1. `Net`      res://autoload/net.gd
2. `Registry` res://autoload/registry.gd
3. `Fx`       res://autoload/fx.gd
4. `Game`     res://autoload/game.gd

Input actions are registered **at runtime** by `Game._ready()` via `InputMap` (not in project.godot):

| action | default | meaning |
|---|---|---|
| move_forward/back/left/right | W S A D | movement (camera relative) |
| jump | Space | jump; when landing from knockdown = quick recovery 受身 |
| skill_0 | Mouse Left | basic attack chain (普攻) |
| skill_1 | Mouse Right | class secondary (block/aim/launcher etc.) |
| skill_2..skill_5 | Q E R F | skills |
| skill_6 | 1 | skill |
| skill_7 | 2 | ultimate (大招) |
| target_cycle | Tab | cycle enemy lock-on |
| target_clear | Escape-free: Middle mouse | toggle lock-on |
| scoreboard | ` (backtick) / hold | show scoreboard |
| menu | Escape | pause/menu |
| camera_zoom_in/out | wheel | zoom |

---------------------------------------------------------------------------------------------------
## 3. Networking model (host-authoritative)

- The host (`multiplayer.is_server()`) simulates **everything** that matters: fighter movement,
  skills, hits, statuses, AI, summons, projectiles, AoEs, match rules.
- Offline play uses the default `OfflineMultiplayerPeer` (is_server()==true, id 1) — same code path.
- Clients only: (a) send input every physics frame, (b) render replicated state, (c) play cosmetic FX.
- `World` owns a `MultiplayerSpawner` (`$Spawner`, spawn_path `../Fighters`) with
  `spawn_function = World._spawn_fighter(data: Dictionary) -> Fighter`. Only host calls `World.spawn_fighter(data)`.
  Spawn data dictionary (all keys always present):
  `{ "uid": int, "kind": "player"|"bot"|"mob"|"boss"|"summon", "peer": int, "class_id": String,
     "mob_id": String, "team": int, "name": String, "pos": Vector3, "owner_uid": int }`
  Node name = `str(uid)` (deterministic). `uid` is allocated by World on host (`World.next_uid()`).
- Each Fighter has a `MultiplayerSynchronizer` named `Sync` (authority 1) built in code with a
  `SceneReplicationConfig`, replicating: `position`, `rotation:y` (via `facing_yaw` property),
  `velocity`, `hp`, `max_hp`, `mp`, `max_mp`, `state`, `anim_key`, `anim_speed`, `status_mask`,
  `shield_hp`, `team`, `combo_count`, `target_uid`, `cooldowns_packed` (PackedFloat32Array, remaining cd per slot),
  `cast_slot`, `is_stealthed`. Position/velocity/yaw/anim: ALWAYS; the rest ON_CHANGE.
- Client input: `Fighter.submit_input.rpc_id(1, packed: PackedByteArray|Dictionary)` unreliable_ordered every
  physics frame from the owning peer. Host validates `multiplayer.get_remote_sender_id() == peer`.
- One-shot cosmetic events go through `Fx` RPCs (`Fx.play(...)` on host broadcasts with call_local).
  Projectile/AoE visuals: host spawns hit-logic node locally and calls `Fx.spawn_projectile_visual(...)`
  / `Fx.spawn_area_visual(...)` which replicate to clients as purely visual nodes that simulate the same
  trajectory (and get a `Fx.despawn(id)` when the host node dies).
- Lobby/roster sync is done by `Game` via RPCs (host is source of truth): `Game.roster` Array of slot dicts.

---------------------------------------------------------------------------------------------------
## 4. Fighter (core/fighter.gd) — the central API

```gdscript
class_name Fighter extends CharacterBody3D
signal died(f: Fighter, killer: Fighter)
signal damaged(f: Fighter, amount: float, src: Fighter)
signal skill_cast(f: Fighter, slot: int)

enum State { IDLE, MOVE, AIR, CAST, HITSTUN, LAUNCHED, KNOCKDOWN, GETUP, GRABBED, STUNNED, DEAD }

# identity (set from spawn data)
var uid: int; var kind: String; var peer: int; var team: int; var display_name: String
var class_id: String; var kit: ClassKit           # null for mobs that use mob defs (see §8)
var owner_uid: int = 0                            # for summons
# replicated state
var hp: float; var max_hp: float; var mp: float; var max_mp: float
var state: int = State.IDLE; var anim_key: StringName = &"idle"; var anim_speed := 1.0
var status_mask: int = 0; var shield_hp := 0.0; var combo_count := 0; var target_uid := 0
var facing_yaw := 0.0; var cooldowns_packed := PackedFloat32Array(); var cast_slot := -1; var is_stealthed := false
# stats (from kit.stats or mob def), modified by statuses
var stats: Dictionary   # keys: hp, mp, mp_regen, patk, matk, pdef, mdef, move_speed, jump_velocity, weight, cast_speed, atk_speed
var status: StatusSet
var input: FighterInput   # latest input (host)
var brain: Node           # BotBrain / BossBrain / null for humans

func setup(data: Dictionary) -> void
func is_alive() -> bool
func is_enemy(other: Fighter) -> bool          # different team and both alive; summons inherit owner team
func get_stat(key: String) -> float            # base * status multipliers
func can_act() -> bool                         # not in hitstun/launched/knockdown/stun/freeze/sleep/grabbed/dead
func can_cast(slot: int) -> bool               # can_act (or in CAST and the current skill allows cancel), cd<=0, mp, not silenced
func try_cast(slot: int) -> bool               # host only
func receive_hit(src: Fighter, hit: Dictionary, from_pos: Vector3) -> float   # host only; returns dmg dealt
func heal(amount: float, src: Fighter) -> void
func add_status(id: StringName, duration: float, power: float = 1.0, src: Fighter = null) -> void
func remove_status(id: StringName) -> void
func has_status(id: StringName) -> bool
func apply_knockback(dir: Vector3, horizontal: float, vertical: float) -> void
func forward() -> Vector3                      # facing direction (XZ, normalized)
func aim_point() -> Vector3                    # input aim point (or target position for bots)
func get_target() -> Fighter                   # current lock-on target or null
func face_towards(p: Vector3) -> void
@rpc("any_peer", "call_local", "unreliable_ordered") func submit_input(d: Dictionary) -> void
```

Movement physics (host): gravity 24 m/s², base move_speed 6.0, jump_velocity 9.0.
Facing: humans face camera/aim direction while casting, movement direction otherwise. Bots face their target.

### 4.1 Hit reactions / Glory mechanics (implemented in Fighter.receive_hit + Combat)
- **Hitstun** (硬直): `hit.hitstun` seconds (default 0.35) in State.HITSTUN; can't act.
- **Launch** (浮空): `hit.launch > 0` → vertical velocity = launch, State.LAUNCHED until landing. While
  airborne, further hits re-launch (juggle). On landing from LAUNCHED → KNOCKDOWN.
- **Combo protection / 保护机制**: per-victim `juggle_points` (reset when it lands or after 1.2 s
  without being hit). Each airborne hit adds `hit.juggle_cost` (default 10). Launch velocity is scaled by
  `clamp(1 - juggle_points/120, 0.25, 1)` and above 120 points the victim falls with gravity ×1.6 and
  becomes untargetable for further launches (still takes damage).
- **Knockdown** (倒地): lasts 0.9 s, then GETUP 0.4 s with invulnerability (`invuln` status 0.6 s).
  Pressing **jump** within 0.25 s of touching ground = **quick recovery 受身**: skip to GETUP immediately.
  `hit.no_recover` (grabs, some skills) disables quick recovery. `hit.otg` lets the hit connect on a
  downed target (otherwise downed targets take hits but with 50% damage and no extra reactions).
- **Super armor** (霸体, status `super_armor`): take damage but ignore hitstun/launch/knockback/stun.
  `hit.armor_break` (grabs, specific skills) ignores super armor.
- **Grab** (抓取, `hit.grab = true`): victim enters GRABBED for `hit.grab_time`, ignores super armor,
  attacker is locked in CAST during it; the final hit of the grab applies the rest of the HIT.
- **Block / Guard** (格挡): status `block` with power p (0..1): frontal physical hits reduced by p and
  no hitstun; magic ignores block; grabs break it.
- **Back attack**: hits from behind (angle > 120° from victim's facing) deal +20% (背击).
- **Stealth**: status `stealth` → enemies cannot target/see (visual alpha 0.15 for allies, hidden for enemies);
  broken when dealing or taking damage.
- **Taunt**: status `taunted` with src → bots must target src; humans' lock-on is forced to src.
- Damage formula (Combat.compute): `base = (hit.type=="magic" ? src.matk : src.patk) * hit.dmg`,
  `mitig = def / (def + 600)`, `final = base * (1 - mitig) * crit * back * status mods * rng(0.95..1.05)`.
  Typical numbers: hp 6000–9000, patk/matk 450–650, def 200–600. A basic hit ~4% hp, a big skill 12–20%.
  PvP total multiplier `Game.settings.pvp_damage_scale` (default 1.0).

### 4.2 Status ids (StatusSet; each has duration, power, src; bit in status_mask in this order)
`stun, freeze, root, silence, sleep, blind, confusion, taunted, slow, haste, bleed, poison, burn,
weight, super_armor, stealth, invuln, block, atk_up, def_up, def_down, matk_up, regen, shield, mark`
- DoTs (bleed/poison/burn) tick every 1 s for `power` × src.patk|matk × 0.1.
- slow/haste: move_speed ×(1-power)/(1+power). weight: move & jump ×(1-power).
- freeze/stun/sleep: cannot act; sleep breaks on damage; freeze shows ice visual.
- blind: outgoing hits 50% miss. confusion: movement input inverted.
- atk_up/def_up/def_down/matk_up: ±power fraction.
- regen: heal power × max_hp per s. shield: absorb `shield_hp` (set by action).

---------------------------------------------------------------------------------------------------
## 5. Skills: SkillDef + action timeline (data-driven)

```gdscript
class_name SkillDef extends RefCounted
var id: StringName            # "battle_mage.sky_strike"
var name_cn: String; var name_en: String; var desc: String
var slot: int                 # 0..7 (see input table)
var cooldown := 1.0; var mp_cost := 0.0
var cast_time := 0.0          # total lock duration in CAST (seconds) — fighter cannot move unless move_while_casting
var move_while_casting := false
var cancel_window := 0.0      # last N seconds of cast_time may be cancelled into another skill (combo flow)
var anim: StringName = &"attack"   # abstract animation key (see §7)
var anim_speed := 1.0
var range := 3.0              # AI hint: effective range in meters
var tags: PackedStringArray   # AI hints: launcher, combo, gap_closer, escape, cc, aoe, ranged, melee, heal,
                              # buff_self, buff_ally, debuff, grab, finisher, summon, zone, defensive, ultimate
var steps: Array[Dictionary]  # action timeline, executed by SkillRunner on the host
var chain: Array[StringName]  # for slot 0 basic attack: list of SkillDef ids forming the press-chain (optional)
var charges := 1              # e.g. Spitfire grenades; cooldown restores one charge at a time
var requires: Dictionary = {} # e.g. {"airborne": true} or {"grounded": true} or {"target_downed": true}
```

Each step: `{ "t": float (seconds after cast start), "type": String, ...params }`. SkillRunner runs them
on the host in order at their time; the cast is interrupted (remaining steps cancelled) if the caster is
hit into hitstun/launch/stun (unless super_armor). Common params: `"hit": HIT` (dictionary, §5.2).

### 5.1 Action types (SkillRunner must implement ALL of these)
| type | params (defaults) | behavior |
|---|---|---|
| `melee` | shape "arc"\|"circle"\|"box" ("arc"), range 2.5, arc 100 (deg), width 1.5, height 2.0, offset 0.0 (forward), max_targets 99, hit | instant hitbox in front of caster; each target hit once per step |
| `multi_melee` | as melee + count 3, interval 0.12 | repeated melee hits |
| `projectile` | speed 22, range 18, radius 0.35, count 1, spread 0 (deg), homing 0.0 (turn rate rad/s), pierce false, gravity 0.0, bounce 0, visual "orb"\|"bullet"\|"arrow"\|"grenade"\|"shuriken"\|"wave"\|"missile"\|"star"\|"blood"\|"qi"\|"dragon"\|"lightning"\|"cannonball"\|"flask"\|"scythe", color Color, scale 1.0, explode {radius, hit} (optional), from "hand"\|"center"\|"sky" ("hand"), aim "forward"\|"target"\|"aim_point", hit | spawns Projectile node |
| `ground` | at "target"\|"aim_point"\|"self"\|"forward", distance 6, radius 3, delay 0.0 (telegraph), duration 0 (0 = single burst), tick 0.5, shape "circle"\|"line"\|"ring", length (line), width (line), visual "fire"\|"ice"\|"lightning"\|"holy"\|"dark"\|"poison"\|"wind"\|"earth"\|"blood"\|"rune"\|"thorn", color, affects "enemies"\|"allies"\|"all", follow_caster false, hit | spawns AreaEffect (bursts or persistent zones; ally-affecting zones apply `ally_effect`) |
| `beam` | length 14, width 0.8, duration 0.6, tick 0.15, follow_aim true, visual, color, hit | line hitbox attached to caster |
| `dash` | distance 6, speed 24, through_enemies false, hit (optional, applied once per target along the path), stop_on_hit false, direction "forward"\|"back"\|"aim"\|"target" | moves caster |
| `blink` | distance 8, to "aim_point"\|"behind_target"\|"back"\|"target" | instant teleport (clamped to map, NavMesh-free raycast) |
| `leap` | distance 6, height 4, duration 0.6, to "target"\|"aim_point"\|"forward", land: {radius, hit} | jump arc then optional landing AoE |
| `launch_self` | vertical 9 | caster jumps (for aerial skills) |
| `buff` | target "self"\|"allies"\|"ally_lowest"\|"target_ally", radius 10, statuses [{id, dur, power}], shield 0.0 (absorb amount as fraction of caster max_hp) | applies statuses |
| `debuff` | target "target"\|"enemies", radius 6, statuses [...] | applies statuses to enemies (no damage) |
| `heal` | target "self"\|"ally_lowest"\|"allies"\|"target_ally", radius 12, amount 0.15 (fraction of target max_hp) + matk_scale 0.0, hot {dur, power} optional, revive false | heals |
| `summon` | summon_id, count 1, duration 20, offset 2.0, max_active 3 | spawns Fighter(kind="summon") using `kit.summons[summon_id]` def (§6) with a BotBrain in "pet" mode |
| `grab` | range 1.8, grab_time 0.8, hit (final), throw {dir "forward"\|"back"\|"up", force} | grab first enemy in front |
| `taunt` | radius 8, duration 3 | taunts enemies in radius toward caster |
| `trap` | trap_id visual, radius 1.5, arm_time 0.5, duration 20, max_active 3, at "self"\|"aim_point", hit, on_trigger_statuses | AreaEffect that triggers once when an enemy enters |
| `pull` | radius 7, strength 10, hit | pulls enemies toward caster |
| `cleanse` | target "self"\|"allies", radius | removes negative statuses |
| `custom` | method String, args Dictionary | calls `kit.<method>(caster: Fighter, args: Dictionary, runner: SkillRunner)` |
| `anim` | anim StringName, speed | switch animation mid-skill |
| `sfx` / `vfx` | name | cosmetic (Fx) |

### 5.2 HIT dictionary (all optional; Hit.normalize(d) fills defaults)
```
dmg 1.0 (multiplier of patk/matk), type "phys"|"magic", hitstun 0.35, launch 0.0 (vertical m/s),
knockback 2.0 (horizontal m/s away from source), pull false, knockdown false, stun 0.0 (seconds),
statuses [] (array of {id, dur, power}), armor_break false, grab false, grab_time 0.0, otg false,
no_recover false, juggle_cost 10, crit_bonus 0.0, element ""|"fire"|"ice"|"lightning"|"dark"|"holy"|"poison",
true_damage false, lifesteal 0.0, threat 1.0 (aggro multiplier)
```

---------------------------------------------------------------------------------------------------
## 6. ClassKit (classes/*.gd)

```gdscript
class_name ClassKit extends RefCounted
var id: String            # "battle_mage" (snake_case English)
var name_cn: String       # "战斗法师"
var name_en: String       # "Battle Mage"
var group_id: String      # "mage"|"swordsman"|"gunner"|"fighter"|"nightwalker"|"priest"|"unspecialized"
var group_cn: String; var group_en: String
var role: String          # "melee"|"ranged"|"tank"|"healer"|"support"|"control"|"summoner"
var weapon_type: String   # see WeaponFactory ids in §7.2
var weapon_name_cn: String; var weapon_name_en: String
var offhand: String = ""  # e.g. "shield", "grenade", "mech_box", "pistol" (dual), "dagger"
var model: String         # CharacterVisual model id (§7.1)
var tint: Color           # accent color for VFX/UI
var famous: String        # e.g. "叶修 / 一叶之秋 / 却邪"
var stats: Dictionary     # hp, mp, mp_regen, patk, matk, pdef, mdef, move_speed, jump_velocity, weight, cast_speed, atk_speed
var skills: Array[SkillDef]   # exactly 8, slot 0..7, slot 7 = ultimate
var summons: Dictionary = {}  # summon_id -> {name_cn, name_en, model, weapon_type, stats, skills: Array[SkillDef] (AI uses them), scale}
var passives: Array[Dictionary] = []   # [{name_cn, name_en, desc}] shown in UI; implemented in hooks
func _init() -> void: define()
func define() -> void: pass          # subclasses fill everything
# hooks (host only), all optional:
func on_spawn(f: Fighter) -> void: pass
func on_tick(f: Fighter, delta: float) -> void: pass             # passives (chasers, berserker blood, regen…)
func on_hit_dealt(f: Fighter, victim: Fighter, hit: Dictionary, dmg: float) -> void: pass
func on_hit_taken(f: Fighter, src: Fighter, hit: Dictionary, dmg: float) -> float: return dmg  # may modify
func on_skill_cast(f: Fighter, skill: SkillDef) -> void: pass
# helper builders (implemented in ClassKit base, used by kits to stay terse):
func sk(slot: int, id: String, cn: String, en: String, cd: float, mp: float, cast_time: float,
        anim: StringName, range: float, tags: Array, steps: Array, extra := {}) -> SkillDef
```

`Registry` loads every `res://classes/**/*.gd` (excluding helpers) at startup, instantiates it, and exposes:
`Registry.kits: Dictionary` (id -> ClassKit), `Registry.get_kit(id)`, `Registry.kit_ids_by_group()`,
`Registry.mob_defs` (from pve/mob_defs.gd), `Registry.get_skill(id)`.

Class roster (id → CN / EN / weapon_type / role):
- swordsman: blade_master 剑客 Blade Master / lightsaber / melee; berserker 狂剑士 Berserker / greatsword / melee;
  spellblade 魔剑士 Spellblade / short_sword / melee-mid; ghostblade 鬼剑士 Ghostblade / tachi / control
- mage: battle_mage 战斗法师 Battle Mage / battle_lance / melee; elementalist 元素法师 Elementalist / staff / ranged;
  witch 魔道学者 Witch / broom / control; summoner 召唤师 Summoner / staff_ring / summoner
- gunner: sharpshooter 神枪手 Sharpshooter / revolver (dual) / ranged; spitfire 弹药专家 Spitfire / auto_pistol + grenade / ranged;
  launcher 枪炮师 Launcher / hand_cannon / ranged; mechanic 机械师 Mechanic / rifle + mech_box / support
- fighter: striker 拳法家 Striker / gloves / melee (bruiser); qi_master 气功师 Qi Master / gloves_qi / ranged-mid;
  grappler 柔道 Grappler / tonfa / control (grabs); brawler 流氓 Brawler / claws / control
- nightwalker: assassin 刺客 Assassin / dual_swords / melee; ninja 忍者 Ninja / ninjato / melee; thief 盗贼 Thief / dagger / control (traps);
  warlock 术士 Warlock / cane / control
- priest: knight 骑士 Knight / knight_sword + shield / tank; exorcist 驱魔师 Exorcist / war_scythe / control;
  cleric 牧师 Cleric / cross / healer; paladin 守护天使 Paladin / great_axe / tank-healer
- unspecialized: unspecialized 散人 Unspecialized / umbrella (千机伞, switches form per skill) / hybrid

Skill selection rule for kits: 8 skills per class, all canon names from the research JSON; slot 1 or 2 is the
class's Lv1 launcher (every Glory class's Lv1 skill is a launcher); slot 7 is the Lv70/75 ultimate.
Kit numbers are tuned so a full rotation is ~10–14 s and an average PvP 1v1 lasts 60–120 s.

---------------------------------------------------------------------------------------------------
## 7. Visuals (visuals/, autoload/fx.gd)

### 7.1 CharacterVisual
```gdscript
class_name CharacterVisual extends Node3D
static func create(model_id: String, weapon_type: String, offhand: String, tint: Color) -> CharacterVisual
func play(anim_key: StringName, speed := 1.0) -> void   # abstract key -> real clip, with blend; loops for loop keys
func set_weapon(weapon_type: String, offhand := "") -> void   # Unspecialized umbrella form switch
func set_alpha(a: float) -> void           # stealth
func set_status_visual(mask: int) -> void  # freeze tint, burning, super armor glow, shield bubble, stun stars
func flash_hit() -> void
func get_hand_position(right := true) -> Vector3
```
Model ids are the character file basenames chosen by ASSETS (documented in `assets/CREDITS.md` and in
`CharacterVisual.MODELS`), plus mob/boss models. Characters are KayKit Rig_Medium (shared 23-bone rig);
bosses Rig_Large. Scale so a player character is ~1.8 m.

**Abstract animation keys** (CharacterVisual must map ALL of these to real clips, falling back sensibly):
`idle, run, walk, jump, fall, land, hit, launched, knockdown, getup, stunned, death, dash, block, cast,
cast_long, channel, attack (generic), attack_1h_1, attack_1h_2, attack_1h_3, attack_2h, attack_spin,
attack_stab, attack_slam, attack_dual, kick, punch, punch_combo, shoot_1h, shoot_2h, shoot_dual, throw,
summon, heal, taunt, grab, leap, aerial, victory`.
Loop keys: idle, run, walk, fall, stunned, block, channel, cast_long, launched.

### 7.2 WeaponFactory
`static func build(weapon_type: String, tint := Color.WHITE) -> Node3D` returns a weapon node whose origin is
the grip, pointing along -Z... (ASSETS decides and documents). Must support every weapon_type above:
`lightsaber, greatsword, short_sword, tachi, battle_lance, staff, staff_ring, broom, revolver, auto_pistol,
hand_cannon, rifle, gloves, gloves_qi, tonfa, claws, dual_swords, ninjato, dagger, cane, knight_sword,
war_scythe, cross, great_axe, umbrella` and offhands `shield, grenade, mech_box, pistol, dagger, sword`.
Use KayKit meshes where they match; otherwise build stylized procedural meshes (e.g. lightsaber = hilt +
emissive blade; hand_cannon = large barrel; cross = two boxes; umbrella = cone canopy + shaft).

### 7.3 Fx autoload (cosmetic only, replicated)
```gdscript
func play(name: StringName, pos: Vector3, dir := Vector3.FORWARD, color := Color.WHITE, scale := 1.0) -> void       # host calls; rpc to all
func spawn_projectile_visual(id: int, visual: String, from: Vector3, vel: Vector3, gravity: float, color: Color, scale: float, homing_uid := 0) -> void
func spawn_area_visual(id: int, visual: String, shape: String, pos: Vector3, yaw: float, radius: float, length: float, width: float, delay: float, duration: float, color: Color) -> void
func despawn(id: int) -> void
func damage_number(pos: Vector3, amount: float, kind: StringName) -> void   # kind: phys, magic, crit, heal, miss, true
func sfx(name: StringName, pos: Vector3) -> void
```
Named effects needed: hit_spark, hit_heavy, slash_arc, launch_burst, land_dust, cast_glow, heal_burst,
buff_aura, debuff_puff, explosion, ice_burst, lightning_strike, fire_burst, holy_burst, dark_burst,
poison_cloud, smoke, blink, dash_trail, summon_circle, block_spark, death, levelup-free "ultimate_flash".

---------------------------------------------------------------------------------------------------
## 8. AI (ai/bot_brain.gd), mobs and bosses (pve/)

- `BotBrain` attaches to a Fighter (host only) and writes `fighter.input` each physics frame exactly like
  a human would (move vector, aim point, skill presses) — it never calls damage APIs directly.
  Modes: "pvp" (duel/team fight), "raid" (party member vs mobs/boss), "pet" (summon follows owner).
  Uses `kit.role` + skill `tags`/`range` to decide: tank (taunt/hold boss, face away from party),
  healer (keep allies alive, kite), melee (gap-close, launcher → combo chain → finisher), ranged (keep
  distance, kite), control (cc priority targets, interrupt casts). Difficulty `Game.settings.bot_difficulty`
  0..3 controls reaction time (0.45 s → 0.08 s), combo accuracy, and dodge of telegraphed AoEs.
  Team play: focus fire on the lowest-hp / the healer, peel for the healer, retreat when low.
- Mobs/bosses are Fighters with `kind` "mob"/"boss", `kit = null`, `mob_def` from `pve/mob_defs.gd`
  (same SkillDef format), driven by `BossBrain` (phases at hp thresholds, telegraphed attacks via `ground`
  delay>0, enrage at 10% "red blood"), and a threat table (aggro) — damage × hit.threat, taunt forces top.

---------------------------------------------------------------------------------------------------
## 9. Game flow & modes

`Game.settings` (synced to clients): `{ mode: "duel"|"arena"|"team"|"raid", map_id, bot_difficulty,
  pvp_damage_scale, round_time 180, rounds_to_win 1, raid_id }`.
`Game.roster`: Array of `{ slot, team, peer (0 = bot), name, class_id, ready }`.
- duel (个人赛 Individual): 1v1, best-of-3 rounds.
- arena (擂台赛 Group Arena): 3 per team, 1v1 at a time, winner stays with remaining HP; team that
  eliminates all 3 wins.
- team (团体赛 Team Battle): up to 5v5 simultaneous, round ends when one team is wiped; best of 3.
- raid (副本): up to 5 players vs dungeon (trash packs + boss); wipe = retry from checkpoint; timer shows
  clear time (速通 record stored locally in user://records.json).
Scene flow: main.tscn → main menu → lobby → match.tscn (World + map + HUD + Match node) → results → lobby.
Match scenes are changed via `Game.start_match()` (host RPC to all: change scene; when all peers report
`client_ready`, host spawns fighters).

---------------------------------------------------------------------------------------------------
## 10. Coding conventions

- GDScript with static typing where practical. Tabs for indentation. No emoji in code/UI text.
- All user-facing text bilingual: Chinese first then English, e.g. `"天击 Sky Strike"`.
- UI font: `SystemFont` with names ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"].
- Never use `Date.now`-style nondeterminism in sync-critical code; RNG on host only.
- Host-only code paths must check `multiplayer.is_server()`; never call host-only APIs on clients.
- Every new script must parse (`--check-only`). Every module ships at least one headless test in `tests/`.
