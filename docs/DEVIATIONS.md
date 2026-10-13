# Deviations from ARCHITECTURE.md

Append-only. Each module documents its own deviations under its heading.

## CORE

### Additions (superset of the contract; nothing in §4-§6 was removed or renamed)
- **Simulation driver**: the host simulation is driven by `World._physics_process -> World.step(delta)`, which calls
  `Fighter.host_tick(delta)` for every fighter, then `tick(delta)` on every Projectile/AreaEffect. Fighters do not use
  their own `_physics_process`. `World.auto_step = false` + manual `World.step()` gives deterministic tests; in that mode
  `World.step` also calls `brain.think(delta)` if the brain has it.
- **Extra replicated properties** on Fighter (ON_CHANGE): `charges_packed: PackedInt32Array` (charges left per slot;
  `cooldowns_packed` = seconds until the next charge) and `anim_seq: int` (bumped whenever an animation must restart
  with the same key, e.g. consecutive chain swings; the visual is re-`play()`ed when key, speed or seq change).
- **Extra signals**: `Fighter.healed(f, amount, src)`; `World.fighter_spawned(f)`, `World.fighter_died(f, killer)`,
  `World.fighter_removed(f)`.
- **Spawn data**: optional key `"yaw"` (float). For summons: `class_id` = owner's class id, `mob_id` = summon id,
  `owner_uid` = owner. World helpers: `spawn_summon(owner, summon_id, pos, duration)`, `attach_brain(f, mode)`,
  `summons_of(owner, summon_id="")`, `team_fighters(team)`, `local_fighter()`, `raycast()`, `ground_y()`,
  `ground_point()`, `clamp_to_bounds()`, `set_arena_size(x, z)`, `next_fx_id()`, `add_effect()`, `clear_effects()`.
  `World.bounds` defaults to a 60x60 AABB centred on the origin; `World.floor_y` is the ground fallback.
- **Fighter extra API** (host unless noted): `start_skill(skill, slot=-1)` (cast without costs; kits/brains/tests),
  `resolve_skill(slot)` (resolves the slot-0 press chain), `cast_block_reason(slot)` -> "" | dead | no_skill | silenced |
  busy | cooldown | mp | requires | kit, `get_skill(slot)`, `find_skill(id)`, `get_cooldown(slot)`, `get_charges(slot)`,
  `reset_cooldowns()`, `reset_for_round(pos=null)`, `revive(frac)`, `kill(killer)`, `add_shield(amount, dur)`,
  `cleanse()`, `take_dot_damage()`, `apply_input(FighterInput)`, `threat` dict + `add_threat()` + `top_threat()`,
  `center()`, `radius()`, `height()`, `hand_position()`, `is_hittable()`, `is_downed()`, `is_airborne()`,
  `is_ally()`, `state_name()`, `stat_bonus` (key -> additive fraction, incl. "dmg_out"/"dmg_in"), counters
  `kills/deaths/damage_dealt/healing_done`, `juggle_points`.
- **Input**: `FighterInput.pressed`/`held` are int bitmasks (`press(slot)`, `is_pressed(slot)`), plus `press_id`
  (incremented by the controller on each new edge; the host de-duplicates resent packets by it). Edges are consumed
  and cleared by the Fighter every host tick. Presses that fail only because the fighter is busy are buffered 0.25 s.
- **SkillRunner extensions**: extra action types `face`, `end`, `wait`, `stop`; `SkillRunner.register_action(type,
  Callable(runner, params))` lets kits add types globally; `runner.vars` scratch dict, `runner.hits_landed`,
  `runner.victims`, `runner.deal(victim, hit, from_pos)`, `runner.execute_step(dict)`, `runner.end_now()`.
  Extra optional params: melee `fx`; ground `max_distance`, `offset` (line), `height`, `max_hits`; trap `distance`;
  grab `arc`, `end_on_miss`; launch_self `forward`; buff `shield_dur`; projectile `sky_height`, `sfx`;
  vfx/sfx `at` ("self"|"target"|"aim_point"|"forward").
  Ground `at` default is "target" (falls back to the aim point; both clamped to `max_distance` =
  max(distance*2, skill.range, 8)). `ground` lines start at the caster and extend toward the aim (same convention as
  Fx: line pos = start point, extends `length` along yaw). `ally_effect` = `{heal (frac of target max hp),
  matk_scale, statuses, shield (frac of caster max hp), shield_dur, cleanse}`.
- **ClassKit extras**: helpers `hit(dmg, extra)`, `st(id, dur, power)`, `get_skill_by_id()`, `skill_for_slot()`,
  `get_stats()` (DEFAULT_STATS merged), hooks `can_cast_extra(f, skill) -> bool`, `on_kill(f, victim)`,
  `on_death(f, killer)`. `sk()` prefixes ids without a dot with "<kit id>." (also inside `chain`); every SkillDef
  built through `sk()` is indexed even if not in `skills` (chain parts, summon skills). Custom action methods may live
  on the owner's kit for summons. DEFAULT_STATS adds `crit` (0.10 chance).
- **Statuses**: re-applying keeps the longer duration and the stronger power (taunt: latest source). `atk_up` raises
  patk AND matk; `matk_up` only matk; `mark` has no built-in effect (kits use it in hooks). DoTs use
  max(src.patk, src.matk). stun/freeze/sleep are ignored under super_armor; negative statuses ignored while invuln.
  A taunt puts the taunter on top of the victim's threat table.
- **Hit details**: block protects a 100 degree frontal arc; grabs and `armor_break` remove `block`; a hit with
  launch 0 on a LAUNCHED target pops it 3 m/s (scaled by combo protection); `hit.throw` {dir, force} is honoured by
  grab hits; unknown HIT keys are preserved by `Hit.normalize` (kits can stash data for hooks).
- **Combat**: `Combat.deterministic` (tests: no crit/variance, blind always misses) and `Combat.seed_rng()`.
- **Physics layers**: layer 1 (bit 1) world, layer 2 (bit 2) fighters; fighters mask only the world and use a soft
  separation push. Constants in `CoreUtil.LAYER_WORLD/LAYER_FIGHTERS`.
- **Registry**: `register_kit(kit)` (kits outside res://classes, e.g. tests/sandbox), `register_mob_def(id, def)`,
  `kit_ids()`, `has_kit()`, `get_mob_def()`. `kit_ids_by_group()` returns an ordered Dictionary
  group_id -> Array[String] (all 7 groups always present). Scripts whose file name starts with "_" or that are not
  ClassKits are skipped as helpers.
- **Fallback visual**: when res://visuals/character_visual.gd is absent, `FallbackVisual` (core) is used.
  Fighters without a kit/def model pass `model = ""` to CharacterVisual.create.

- **Review fixes (CORE)**: a grab HIT that connects only locks the victim (no damage/statuses/stun at grab start);
  the full HIT is applied once at release. A blocked frontal hit applies no `stun` and no `hit.statuses` (chip damage
  and reduced knockback only). `cooldowns_packed` is rounded up to 0.1 s. Fighter `Sync` uses
  `replication_interval = 1/60`, `delta_interval = 1/30`. Follow-caster areas/beams move their visual with
  `Fx.move_area_visual` (unreliable) instead of despawn + respawn. Registry never instantiates scripts that do not
  extend ClassKit.

### Mob def format (pve/mob_defs.gd, owner RAID)
`static func all() -> Dictionary` returning `mob_id -> def`, where def =
`{name_cn, name_en, model, weapon_type, offhand, tint: Color, scale: float, stats: {same keys as ClassKit.stats},
skills: Array[SkillDef] or Array[Dictionary]}`. Skill dictionaries use SkillDef field names (`id, slot, cooldown,
mp_cost, cast_time, anim, range, tags, steps, cancel_window, requires, ...`); `slot` defaults to the array index.
Summon defs in `ClassKit.summons` use the same shape. Registry normalises both into `Array[SkillDef]`.

### Requests
- **AI (BotBrain)**: core attaches brains through `World.attach_brain(f, mode)`: it instantiates
  res://ai/bot_brain.gd, sets properties `mode` and `fighter` if they exist, calls `setup(f)` or `setup(f, mode)` if
  defined, names it "Brain", assigns `f.brain` and adds it as a child of the fighter (host only). Brains drive the
  fighter only through `f.input` (FighterInput: move, aim_point, target_uid, press(slot), jump) - edges are consumed
  each host tick. Optional `think(delta)` is used by deterministic tests (World.auto_step = false).
- **NET (Game)**: core reads `Game.settings.pvp_damage_scale`. The CORE stub of game.gd registers the §2 InputMap
  actions at runtime; the real Game must keep doing so. The net.gd/game.gd stubs start with "# STUB - owned by NET".

## ASSETS

### Conventions chosen (contract left them to ASSETS)
- **Model ids** (`CharacterVisual.MODELS`): snake_case ids (`knight`, `avian_swordsman`, `skeleton_warrior`,
  `black_knight`, ...), full table + class mapping in `assets/CREDITS.md`. `CharacterVisual.create(model_id, ...)`
  also accepts a **class id** (`"blade_master"` -> its CLASS_MODEL body), a glb basename in any case
  (`"AvianSwordsman"`), and `""` (-> knight, silently) via `CharacterVisual.resolve_model_id()`.
- **Scale/facing**: every model is scaled by `CharacterVisual.MODEL_SCALE = 0.75` (Medium chibis ~1.8 m incl. the
  big head, Large bosses ~3.5 m); the visual faces -Z. `CharacterVisual.height` gives the visual height.
- **Weapon grip** (`WeaponFactory.build`): origin = fist on the handslot bone, blades/shafts along +Y, firearms muzzle
  along **+X** of the returned node (the KayKit handslot aim axis, verified by rendering Ranged_1H/2H_Shoot), units are
  unscaled KayKit units. Staves/cross/umbrella get a built-in tilt pivot so their heads read upward.
- **Area line shape**: starts at `pos`, extends `length` along yaw-forward, `width` wide (same as CORE's AreaEffect).

### Additions (superset; nothing removed)
- `CharacterVisual`: `create_for_class(class_id, weapon_type, offhand="", tint)`, `replay(key, speed)`,
  `resolve_model_id(id)`, `resolve_clip(rig, key, stance)`, `get_library(rig)`, `get_head_position()`,
  `has_clip_for(key)`, constants `CLASS_MODEL`, `MODELS`, `LARGE_MODELS`, `MOB_WEAPONS`, `ANIM_MAP`, `LOOP_KEYS`,
  `HOLD_KEYS`, `STATUS_IDS`, `MODEL_SCALE`.
- `play(key, speed)` semantics: loop keys and death/knockdown do not restart when requested again; every other key
  (including `launched`) restarts from frame 0 on each call (works with CORE's `anim_seq` retrigger). A finished one-shot
  settles back into idle on its own. Weapon stance overrides: 2h weapons use `Melee_2H_Idle`, unarmed/fist weapons
  use `Melee_Unarmed_Idle`, rifles run with `Running_HoldingRifle`.
- `launched` is listed as a loop key in §7.1; it plays `Hit_B` and **holds its last frame** (a held airborne
  flinch) instead of cycling, so juggles do not visibly "twitch-loop"; a re-request (anim_seq bump on a new juggle
  hit) replays the flinch.
- Rig_Large has no jump/cast/ranged clips; those keys fall back to the melee/dodge clips listed in CREDITS.md.
- Status visuals: freeze = icy overlay + animation paused; burn = flickering orange overlay; poison = green overlay;
  super_armor = golden rim; mark = red rim; shield (and invuln) = translucent bubble; stun/sleep/confusion = rotating
  stars above the head; stealth via `set_alpha`.
- `WeaponFactory`: extra ids `umbrella_open` (shield form), `umbrella_gun` (gun form), `gloves_left`, mob/boss
  weapons (`skeleton_blade/axe/dagger/staff/crossbow/shield/shield_large/scythe`, `orc_axe`, `orc_axe_large`,
  `black_knight_sword/shield`, `frost_golem_axe`, `skeleton_golem_axe`, `skeleton_mace_large`,
  `monstrosity_pitchfork`, `great_axe_large`, `crossbow`, `wand`, `spellbook`, `magic_wand`), `all_ids()`,
  `left_variant()`. `umbrella` itself is the folded spear/sword form. Dual weapons (dual_swords, gloves, gloves_qi,
  tonfa, claws, revolver) get a mirrored left-hand copy automatically when `offhand == ""`.
- `Fx`: `is_stub = false`, `clear_all()` (local, for scene changes), `live_count()`. Unknown effect / sound / visual
  names fall back (hit_spark / hit / orb) with a one-time warning. Extra sfx names: see `Fx.SFX_MAP`.
- `Fx.move_area_visual(id, pos, yaw)` (host broadcast, `unreliable_ordered`): moves/turns a live area visual
  without restarting it. `Fx.spawn_projectile_visual(..., homing_uid := 0, homing_rate := 0.0)`: `homing_rate` (rad/s)
  makes the visual turn exactly like the host Projectile (max `homing * delta` per frame toward target + 1 m); 0 keeps
  the legacy soft steering. Re-issuing an existing projectile id replaces that visual (use it on bounce).
- Despawned area visuals are parked for 150 ms; a `spawn_area_visual` with the same visual/shape/size/color in that
  window re-uses the node (re-keyed to the new id, moved, timing updated) instead of restarting fade-in, spikes,
  pillar, flare and the first tick. This makes CORE's current despawn+respawn follow path flicker-free.
- `Fx.clear_all()` is connected to `SceneTree.scene_changed`.
- `CharacterVisual.set_alpha` also fades meshes that use `material_override` (procedural weapons) via per-mesh
  duplicates (originals stored in meta `_orig_override`, restored at alpha 1); shared materials are never mutated.

### Requests
- **KITS**: set `kit.model` to the CLASS_MODEL body (or simply to the class id; both resolve). Unspecialized form
  switches: call `visual.set_weapon("umbrella" | "umbrella_open" | "umbrella_gun" | any weapon id)`.
- **CORE**: when a kit/def has no model, passing the class id (instead of `""`) to `CharacterVisual.create` gives the
  right body automatically.
- **RAID**: mob/boss bodies and weapons: `CharacterVisual.MODELS` + `MOB_WEAPONS`. Boss scale 1.0 is already ~3.5 m.
- **CORE** (`core/area_effect.gd` follow_caster/beam): call `Fx.move_area_visual(fx_id, global_position, yaw)` instead
  of `despawn` + `spawn_area_visual` with a new id when the caster moves/turns (saves 2 reliable RPCs per re-issue;
  the despawn+respawn path still works and is now flicker-free, see Additions).
- **CORE** (`core/area_effect.gd`, `core/projectile.gd`): call `Fx.despawn(fx_id)` from `_exit_tree()` while still
  alive, so round resets inside the same scene do not leave traps/zones/projectile visuals behind (scene changes are
  already handled by `clear_all`).
- **CORE** (`core/projectile.gd`): pass `homing` as the new 9th arg `homing_rate` of `spawn_projectile_visual`, and on
  each bounce re-issue `spawn_projectile_visual` with the same `fx_id` and the new position/velocity.

## LEAD

- `Fighter.weapon_form: String` (replicated ON_CHANGE) added by lead: host sets it to switch the displayed weapon
  (Unspecialized umbrella forms); "" restores the kit weapon + offhand.
- Lead added shared base classes: `maps/map_base.gd` (MapBase) and `modes/match.gd` (Match). Subclass them; do not
  edit them (append requests here).

## KITS (unspecialized)
- `classes/unspecialized.gd`: every skill starts with a t=0 `custom` step `form` (kit method `form(f, args, runner)`)
  that sets `f.weapon_form` from logical forms: lance -> `umbrella`, gun -> `umbrella_gun`, shield -> `umbrella_open`,
  blade -> `tachi`, fist -> `tonfa`. The ultimate re-calls `form` mid-skill to cycle 4 forms.
- Passive 千变 Myriad Forms state is per fighter in Fighter metadata (`mf_stacks`, `mf_last_form`, `mf_last_cast`,
  `mf_clock`, `mf_applied`) because kit instances are shared. The bonus is applied additively to
  `f.stat_bonus["dmg_out"]` (only its own contribution is added/removed). `kit.myriad_stacks(f) -> int` for UI/tests
  is HOST-ONLY (metadata and stat_bonus are not replicated; a client HUD reads 0 until CORE adds a replicated
  per-fighter counter, see Requests (KITS-unspecialized)).
- Basic attacks (slot 0) do not add Myriad Forms stacks or change the last form; they only keep the 3 s window alive.
  Every `form` call records the last logical form, so the ultimate (ending in lance) counts as lance.
- After 3 s without casting, stacks clear and `f.weapon_form` is reset to "" (default umbrella look). This also covers
  `reset_for_round()` / non-full-reset bout swaps, which do not call `on_spawn`.
- Canon note: slot 7 `千机连携 Myriad Combo` and the passive `千变 Myriad Forms` are design inventions (the contract needs
  an ultimate; canon Unspecialized only has Lv<=20 skills). The ultimate is a string of canon borrowed skills
  (盾击 Shield Attack, 龙牙 Dragon Tooth, 天击 Sky Strike, 格林机枪 Gatling Gun, 拔刀斩 Sword Draw). The basic-chain
  labels (普攻·伞刺/回刺/横扫) are descriptive, not canon skill names. The canon "+1 SP per umbrella form" is not modelled
  (no SP system); no-swap-cooldown is modelled by the instant `form` step.

## KITS-priest

- Files: `classes/priest/{knight,exorcist,cleric,paladin}.gd`, `tests/test_kits_priest.gd`.
- **Launchers**: the research lists no explicit knock-up for Cleric/Paladin; they use the Priest base Lv1 skill
  `升天阵 Rising Emblem` (listed under Exorcist; learnable by every priest per the "Lv20-or-below skills before class
  change" rule). Knight's launcher is `盾击 Shield Attack` (upward bash, 30% daze), Paladin's slot 1 is `圣光打 Holy Light
  Strike` (phys launch + holy follow-up) and slot 2 Rising Emblem.
- **Paladin ultimate**: the research has no Lv70/75 Paladin skill; `天使威光 Angel's Might` (360-degree push-back that
  ignores super armor) is used as slot 7 (3 pulses + ally heal). `光环砸击 Halo Smash` uses the given unverified CN name.
- **Grouped canon skills**: Exorcist `落雷符 / 寒冰符 / 烈焰符` is one skill that throws the next loaded talisman
  (cycles lightning stun -> ice freeze/slow -> fire burn AoE); `定身符 / 硬身符 / 加速符` is one skill (root target + self
  super armor + haste). Knight `盾反 / 法术反射` is one counter stance (block 0.9 + next hit countered, magic reflected).
- Omitted canon skills (8-slot limit): Knight 骑士精神 Knight's Spirit, [荣誉]挑衅 Provoke (Roar covers taunting);
  Exorcist 飞火流星 Flying Meteorite; Cleric 祈愿 Wish Prayer, 圣诫之光 Holy Commandment Light.
- Passives (all via hooks): Knight Shield Block (-30% frontal phys while not attacking) + Guardian Threat (double
  threat); Exorcist Talismans (Spirit Guidance's scythe carries the loaded talisman's statuses) + Seal (-15% patk/matk
  for 12 s on enemies hit by Seal Talisman's final blast: a NEGATIVE `atk_up` status (power -0.15) inside that hit's
  `statuses`, same convention as Witch; no `stat_bonus` writes, CORE gates it on block/invuln/downed). Talisman / seal
  statuses travel in the hit dicts (Spirit Guidance builds its projectile in custom `throw_scythe`), so blocked frontal
  hits apply none of them; `on_hit_dealt` only plays fx. Knight Shield Attack 30% daze rolls `Combat.rng` (never under
  `Combat.deterministic`) and is skipped vs downed / invuln / frontal-blocking / already-launched victims; Cleric Meditation (+100% mp_regen after 3 s without casting, via `stat_bonus["mp_regen"]`) + Angel
  Wings glide (fall speed clamped to 1 m/s for 3 s in `on_tick`); Paladin super armor on heavy skills (`on_skill_cast`)
  + Guardian Light (12% of damage dealt heals the weakest ally within 10 m).
- Per-fighter kit state uses Node meta keys: `knight_counter`, `exorcist_talisman`, `cleric_hover`,
  `cleric_idle`.

### Requests (KITS-priest)
- **CORE** (nice to have): a per-fighter gravity scale (e.g. `Fighter.gravity_scale`) would let flight/hover skills
  (Cleric Angel Wings, Witch broom) avoid clamping `velocity.y` in `on_tick`; please add an `atk_down` status
  (NEGATIVE list, so cleanse removes it and AI treats it as a debuff). Until then the Exorcist seal is a negative
  `atk_up`; known gap: StatusSet.add keeps the max power, so a sealed enemy that already has / later gains a real
  `atk_up` buff ignores the seal, and cleanse does not remove it (atk_up is not in NEGATIVE).
- **CORE** (nice to have): KitBase-level guarded "on-hit status" helper -- kits that add statuses from
  `on_hit_dealt` must re-implement the blocked/downed/invuln gating (Knight daze does it by hand).
- **All kits writing `stat_bonus["dmg_out"]` / `patk` / `matk`**: write additively (track your own share), never
  assign absolutely -- shared keys are clobbered otherwise (KITS-swordsman already fixed; KITS-gunner launcher.gd
  `dmg_out` please check).

## KITS-swordsman

- Files: `classes/swordsman/{blade_master,berserker,spellblade,ghostblade}.gd` (no class_name), test `tests/test_kits_swordsman.gd`.
- Per-fighter passive state lives on the Fighter (kits are shared instances): `set_meta` keys
  `berserker_rage_left`, `spellblade_intent_stacks`/`spellblade_intent_left`, `ghostblade_last_feast`.
- Passive stat changes never overwrite shared keys (fix round): berserker `patk` (Blood Awakening) and ghostblade
  `dmg_out` (boundary resonance) are additive -- each tracks its own share in meta (`berserker_awaken`,
  `ghostblade_resonance`) and applies `bonus - applied + want`, so other kits' modifiers (e.g. Exorcist seal) survive.
  Blade Master `atk_speed` is still written absolutely (no other kit uses it). Spellblade Killing Intent is a
  `matk_up` self status (power 0.04/stack) instead of a stat_bonus write.
- Berserk (meta `berserker_rage_left`) also requires the Enrage `atk_up` self status, so `reset_for_round`
  (status.clear_all) or a dispel ends it; Killing Intent stacks likewise drop when `matk_up` is gone.
- Falling Phoenix Slash slam = custom step `slam_victims` placed right after the melee (same t) so it runs after
  `_apply_reactions`; the old `slam_down` HIT key was removed. All steps are scheduled before each skill's cancel window
  (enforced by the test).
- Ghostblade boundaries = persistent `ground` zones from its skills tagged `zone`; found by scanning `World.effects` for
  AreaEffects whose `caster` is the Ghostblade (`kit.boundaries_of(f)`); max 3 (oldest `finish()`ed). Ghost Feast
  (ultimate) hits enemies inside each boundary, finishes them, then bursts around the caster.
- Spellblade Waltzing Wave Slash spawns its returning wave as a `Projectile` built in the kit (same fields SkillRunner sets).
- Spellblade has no Lv1 skill in the research JSON; slot 1 launcher is the canon 地裂波动剑 Earthquake Sword (upward swing).
  Canon CN names marked unverified are used without the annotation (裂波斩, 嗜血狂战).
- Basic attacks are named 普攻·一/二/三 Basic Attack I/II/III (not canon skills).

## KITS-fighter

- Files: `classes/fighter/striker.gd`, `qi_master.gd`, `grappler.gd`, `brawler.gd`, `tests/test_kits_fighter.gd`
  (none use `class_name`).
- Canon gaps: the research JSON has no Lv70/75 skill for 柔道 Grappler, so **旋投 Spinning Throw** is its slot 7
  ultimate. Grappler has no explicit Lv1 skill, so **抛投 Toss** (grab, throw dir "up") is its slot 1 launcher.
  **Fling** has no CN name in the research ("（中文名未核实）"); the kit shows the placeholder CN **甩投** (unverified).
  Silver weapon names without a CN source are shown in English only (Qi Master "Mirrored Moon").
- Passives without a canon name are labelled as mechanics: Striker 铁拳之势 Iron Fist Momentum (6 quick hits -> 1.2 s
  super armor), Grappler 擒拿 Grappling Mastery (completed throw -> +30 MP, 0.6 s super armor). Canon ones:
  Qi Master 护体真气 True Qi Protection (`stat_bonus.pdef/mdef` = 0.3 x mp fraction, written every tick),
  Brawler 涂毒 Apply Poison (claw hits poison; done as a passive instead of an active buff).
- Per-fighter kit state lives in Fighter metadata (`striker_parry`, `striker_mom`, `striker_mom_t`,
  `grappler_counter`, `brawler_t4t_skill`), because one kit instance is shared by every fighter of that class.
- Parry / counter-grab (Empty-Handed Blade Block, Receiving Throw) are implemented in `on_hit_taken`: a non-magic hit
  from within 3.5-4.5 m during the window returns 0 damage and counters (Striker: launch; Grappler: grab with
  throw back). The window also gives super armor so the parried hit causes no hitstun. Hit keys stashed for hooks:
  `grappler_throw`, `brawler_claw`.
- 以牙还牙 Tooth for Tooth: `on_hit_taken` remembers the attacker's current `runner.skill` (only skills whose steps are all
  built-in actions: no `custom`, `summon` or registered custom actions). The ultimate's first step calls
  `f.start_skill(copied, 7)` with +30% `atk_up` and super armor; with nothing stored it runs its own claw flurry.
- 捉云手 Cloud Grasping Fist teleports the victim in front of the caster (up to 10 m) and then applies a 0.45 s grab.

### Requests (KITS-fighter)
- **CORE** (optional): a grabber can hold several victims at once (Grappler 双手飞 Flying Hands grabs two), but
  `_tick_grabbed` places every victim at the same spot in front of the grabber; a small sideways offset per extra
  victim would look better.
- **AI**: the `defensive` + `interrupt` skills (Striker slot 6, Grappler slot 3) are parry stances. They work best when
  cast just before an enemy melee swing lands (0.65-0.7 s window).

## KITS-nightwalker

### Choices / deviations
- **No canon Lv1 launcher in research for Thief and Warlock**: Thief slot 1 = 陷阱扣 Spike Trap (thrown at the target,
  0.15 s arm, spikes launch + root); Warlock slot 1 = 击魂术 Soul Strike (interrupt, implemented as a dark burst that
  launches). Both tagged `launcher`.
- **No canon Thief ultimate in research**: slot 7 = 冰霜陷阱（中文名未核实）Ice Trap promoted to a 50 s big AoE freeze
  trap + slow field. Assassin ult = 裂/杀/闪/瞬/灭 as one scripted 5-form cast; Ninja ult = 忍法·樱杀碎月; Warlock ult =
  死亡之门 (Lv70) with super armor (canon: cancelled by damage).
- Passives implemented in hooks (per-fighter state in `Fighter` meta keys prefixed `nw_`):
  Assassin 空跃 Air Jump (double jump in on_tick from `input.jump` edge), 暗杀 Assassination (+20% from behind) and
  致命要害 Vitals Strike (+15% on targets carrying the assassin's `mark`) as an extra `take_dot_damage` tick in
  on_hit_dealt; Ninja 忍法·替身草人 Body Replacement as an automatic 20 s-ICD escape when juggled (scarecrow summon,
  relocate 5 m, invuln 0.5 s); Thief 陷阱精通 Trap Proficiency (trap HITs carry key `_nw_trap`; stealth is restored
  after a trap hit); Warlock 控制术 Control Spell used as a passive rider (magic hits drain 15 MP).
- Thief 暗影陷阱 Shadow Trap: first cast places a marker trap, the next cast teleports to it (custom action).
- Ninja summons: `shadow_clone` (stationary decoy that taunts nearby enemies 1.5 s) and `scarecrow` (model
  `plant_warrior`).

### Requests (KITS-nightwalker)
- **CORE**: a public `Fighter.recover_to_neutral()` (clear `_knock_vel`, leave LAUNCHED/HITSTUN to AIR/IDLE) for escape
  passives. Ninja's Body Replacement currently sets `_knock_vel` via `set()` and calls `_to_neutral()` (guarded by
  `has_method`/`in`).

## KITS-mage

- Files: `classes/mage/battle_mage.gd`, `elementalist.gd`, `witch.gd`, `summoner.gd`, helper `classes/mage/_mage_util.gd`
  (skipped by Registry), test `tests/test_kits_mage.gd`.
- Kits are shared instances, so per-fighter passive state lives in Fighter metadata (`mage_*` keys, `_mage_util.gd`
  getv/setv), never on the kit.
- Battle Mage 炫纹 Chasers: CHASER_FROM maps skills to elements (Dragon Tooth neutral, Falling Flower Palm fire,
  Circle Swing shadow, Furious Dragon light, Dragon Breaks the Ranks ice); max 7; fired (custom `fire_chasers`) by the
  basic-attack 3rd hit and the ultimate. 斗者意志 Battle Spirit writes `stat_bonus` keys `atk_speed`, `move_speed`,
  `patk` (owned by this kit for battle_mage fighters).
- Witch 扫把掌握 Broom Mastery flight: on_tick reads `f.input.jump` (on_tick runs before `_consume_input`), mounts on
  a mid-air jump, and counteracts gravity by adding to `velocity.y` before `_physics_move` (no gravity-scale API).
  Broom Tornado ends in flight. Flight has no cooldown (canon) but is capped at 4 s per airtime: once it ends the
  witch must touch the ground before mounting again (the 4 s cap is a balance addition, not canon).
  Disperse Powder "attack down" (-20%) is written to the victim's `stat_bonus` `patk`/`matk` (only this skill's share,
  victim meta `mage_powder_share`; expiry tracked in the caster's meta, removed on expiry / victim death / caster
  death, and when the paired `slow` is cleansed). No negative `atk_up` is used.
- Summoner: elemental spirits are 4 summon defs cycled by one skill (canon entry "雷精灵 / 火精灵 / 冰精灵 / 暗精灵").
  Follow + Strengthen Creature are passives in on_tick. Switch is gated by `can_cast_extra` (needs a living summon).
  精灵献祭 Spirit Sacrifice detonates only the 4 elemental spirits (goblins / flowers survive); each enemy takes the
  full blast (1.4 matk) once and 0.3 matk from further blasts (rune 2.6 + spirits ~= 20% hp). 印记 Mark keeps pets on
  the marked enemy by giving each pet a 5 s `taunted` status sourced from that enemy (both pet brains honour taunt).
  Ranged basic chains tuned down (Elementalist 0.4/0.4/0.6 + matk 570, Summoner 0.38/0.38/0.55 + matk 550; bolt 1/2 cancel_window 0.05; goblin max 1, flower spit 0.3).

## Requests (KITS-mage)
- **CORE**: a per-fighter gravity scale (e.g. `Fighter.gravity_scale` or a `float`/`hover` status) would let the
  Witch broom flight drop its velocity hack in on_tick.
- **CORE**: there is no cast-speed debuff status; Witch 驱散粉 Disperse Powder (canon: lowers cast speed) only slows
  movement and attack. A `cast_slow` status (cast_speed x(1-power)) would complete it.
- **CORE**: `on_hit_dealt` is only called on `src.kit`; hits by summons (kit == null) never reach the owner's kit.
  Calling `owner.kit.on_hit_dealt(owner_summon...)` (or a separate `on_summon_hit`) would allow pet-based passives.
- **AI (BotBrain)**: Witch flight is mounted by a second jump press in mid-air; bots that never double-jump only fly
  after Broom Tornado. Summoner slot 6 (Switch, tag escape) needs a living summon (can_cast_extra blocks otherwise).
- **CORE**: an `atk_down` status (patk/matk x(1-power), in StatusSet.NEGATIVE so cleanse removes it) would let Witch
  Disperse Powder drop its stat_bonus bookkeeping (same request as KITS-priest).

## KITS-gunner

- Files: `classes/gunner/sharpshooter.gd`, `spitfire.gd`, `launcher.gd`, `mechanic.gd` (all `extends ClassKit`) plus the
  helper `classes/gunner/_gunner_util.gd` (static funcs, skipped by Registry because of the `_` prefix; preloaded
  by the kits as `GU`). Test: `tests/test_kits_gunner.gd`.
- **Gun recoil (shared gunner passive)**: `on_skill_cast` of a `ranged` skill while airborne adds upward velocity
  (Sharpshooter +4.2 m/s capped at 5 = sustained aerial gun-fu; Launcher also shoves the caster back 2.5 m/s;
  Spitfire/Mechanic small). Grenade throws (anim `throw`) do not recoil.
- **Patterned bombardments**: Spitfire Chaotic Thunder (flower of 9 blasts), Launcher Stinger (8+1 stingers) and
  Satellite Beam (6 rotating beams), Mechanic Air Drops (spiral of 8 bombs) spawn AreaEffects at explicit points
  through `GU.burst_at(runner, pos, ground_params)`, which calls `SkillRunner._make_area()` and `World.add_effect()`.
  Patterns are deterministic (no RNG).
- **Per-fighter kit state lives in Fighter meta** (kits are shared): `ss_last_slot` (Sharpshooter Dual Load),
  `rotor_t` (Mechanic Rotor Wings hover seconds left), `mech_marks` (Mechanic: victim instance id -> own mark seconds
  left), `la_art` (Launcher Artillery Mastery's current dmg_out share). Rotor Wings = `launch_self` (vertical 8) +
  `on_tick` glide for 4 s: 85% gravity compensation only while descending (fall capped at -0.45 m/s), and vertical
  speed clamped to <= 0 above 3 m over ground, so the Mechanic stays within melee / ground-AoE reach (fix round);
  being hit (launched/hitstun/stun/grab/knockdown) ends the flight.
- Unknown HIT keys used by hooks: `freeze_chance` (Spitfire Ice Bullet, `on_hit_dealt` rolls `Combat.rng`; always
  freezes when `Combat.deterministic`), `gadget` (Mechanic: gadget hits add `mark` 4 s) and `rifle` (Mechanic rifle
  shots on a target carrying the Mechanic's OWN gadget mark -- tracked in `mech_marks`, foreign `mark`s from Exorcist /
  Assassin do not count -- deal +20% extra through `take_dot_damage`, shown as a true-damage number).
- Hook-applied CC respects blocks (fix round): `GU.was_blocked()` mirrors Combat.compute's frontal-block rule, so
  Ice Bullet freeze and the gadget mark are skipped on a frontally blocked physical hit.
- Launcher Artillery Mastery writes `stat_bonus["dmg_out"]` additively every tick (own share in meta `la_art`;
  +10%, +20% vs a target >= 12 m away), so other dmg_out modifiers survive.
  Sharpshooter Rapid Firing / Burst Firing set `stat_bonus["atk_speed"] = 0.1` and `stat_bonus["crit"] = 0.6` on spawn.
- Mechanic Lv1: canon data does not name the Mechanic's Lv1 skill; slot 1 uses 跳雷 Bouncing Mine (canon "pop-up
  mine, knock-up") as the launcher. It is a `trap` placed at the target (arms in 0.35 s), so it launches a standing
  target immediately and otherwise waits as a mine. Mechanic role is `support`.
- Spitfire passive 弹药扩充 Ammunition Expansion: the CN name is marked unverified in the research JSON; the UI shows it
  without the annotation (same convention as Sharpshooter 双重装填 and the swordsman kits).
- Basic attack chains are rapid low-damage bullets (~1-3% hp per press) rather than 3-4% single hits, so the
  static-dummy dps of gun classes stays ~400-600 (30 s rotation test).

## Requests (KITS-gunner)
- **CORE**: a public `Fighter.restore_charge(slot)` / `set_cooldown(slot, t)`. Sharpshooter Dual Load currently
  edits `Fighter._charges/_cd` and calls `_pack_cooldowns()` directly (`GU.restore_charge`).
- **CORE**: a public `SkillRunner.spawn_area(p, pos, yaw)` (or `at: "point"` + `pos` for `ground`) so kits do not call
  the private `_make_area()` for patterned bombardments.
- **CORE**: `on_hit_dealt` for summon hits on the owner's kit (same as the KITS-mage request) would let the Mechanic's
  robots/drones apply the Mechanical Box mark.
- **AI (BotBrain)**: Rotor Wings is tagged `escape`/`buff_self`; Mechanic gadgets (`trap` at target) are tagged
  `zone` + `launcher`/`cc`; Sharpshooter Punisher (`finisher`, OTG) is best used on a downed target.
- **CORE**: pass a `blocked` flag to `kit.on_hit_dealt` (e.g. stash `hit["_blocked"]`), so kits need not mirror the
  block rule (`GU.was_blocked`).
- **ASSETS (Fx)**: headless test runs end with "WARNING: N ObjectDB instances were leaked" / "ERROR: N resources still
  in use at exit" from Fx's pooled SFX players/playbacks (e.g. synth_whoosh.wav, impactMetal_heavy_000.ogg; also seen
  in test_kits_swordsman). Please make `Fx.clear_all()` free the pooled AudioStreamPlayer3D nodes and their playbacks,
  so tests can call it at exit and grepping for "ERROR:" stays meaningful.

## Requests (KITS-unspecialized)
- **CORE**: replicate a small per-fighter `kit_counter: int` (add to Fighter.SYNC_ON_CHANGE) so kits can expose
  counters such as Unspecialized Myriad Forms stacks to client HUDs. Until then `the unspecialized kit's myriad_stacks()`
  is host-only.

## MAPS

### Additions (superset; MapBase untouched)
- `MapRegistry` (class_name, `maps/map_registry.gd`): `list(kind := "arena")` (`"arena"` | `"raid"` | `"all"`, raid
  entries come from `res://pve/raid_registry.gd list()` when it exists), `create(id) -> MapBase` (not built yet; call
  `build()` then `apply_to_world(world)`; unknown ids are delegated to `raid_registry.gd create(id)`, else null +
  warning), plus helpers `for_mode(mode)`, `has(id)`, `info(id)`, `default_id(mode)`.
- Map ids: `classic_arena` 竞技场 (36x36 round duel), `hundred_blossoms` 百花谷 (50x50, plateaus 4.5 m + bridge),
  `old_castle` 古堡 (55x55, walls/gates/keep 3 m/flank corridors), `lava_cave` 熔岩洞 (40x40, lava river + edges,
  keep 2 m). classic/blossoms/lava support duel, arena and team; old_castle team and arena only.
- `ArenaMap.is_hazard(pos) -> bool` (virtual; lava_cave: lava below y 0.4) for bots to avoid hazards.
- `ArenaMap` (class_name, `maps/arena_map.gd`, extends MapBase): shared base of the arenas. `spawns[team]`,
  `get_spawn_yaw()` faces the map center from the team's spawn centroid, `apply_to_world()` also sets
  `world.floor_y`, `fingerprint()` (deterministic geometry hash, used by tests), `test_walks` (designer routes the
  tests walk a Fighter along), `TEAM_COLORS` (0 blue, 1 red). Spawn markers are nodes named `SpawnMarker<team>_*`.
  Team 0 always spawns on the -Z side, team 1 on +Z. Spawn point y = ground + 0.3.
- `MapKit` (class_name, `maps/map_kit.gd`): procedural builder (KayKit pieces batched into MultiMeshInstance3D per
  mesh, collision shapes in one StaticBody3D `WorldCollision` on LAYER_WORLD, helpers floor_grid/platform/ramp/
  wall_line/tree/rock). RAID may reuse it for dungeons.
- Lava Cave hazard (host only, `arena_lava.gd _physics_process`): fighters standing in lava take
  `take_dot_damage(4% max hp)` every 0.5 s + `slow` 0.25 and an Fx `fire_burst`. `is_lava(pos)` is a static func of res://maps/arena_lava.gd.
- Outer boundaries: a visible wall (classic, castle) or rocks/cliffs (blossoms, lava) backed by a tall collision wall
  (24 m) just outside `size`; no other invisible collision.
- `scenes/map_preview.tscn` (+ `maps/map_preview.gd`): fly-cam preview, `-- --map=<id>`; screenshot mode
  `--shot=<prefix> --views=overview,tps,tps_red,side,high,top`.

## HUD

- `ui/hud.gd` `class_name Hud extends CanvasLayer` (layer 10). API: `bind(world, match_node, local_uid)` (match_node may be
  null; `local_uid` 0 = auto `world.local_fighter()`), `set_local_uid(uid)`. Extra public helpers: `get_local_fighter()`,
  `is_spectating()`, `find_boss()`, `refresh()` (data pass, normally 25 Hz from `_process`), `announce(text, sec)`,
  `toggle_help()` / `set_help_visible(on)` (F1), `set_scoreboard_forced(on)` (scoreboard otherwise shows while the
  `scoreboard` action / backtick is held, and automatically after `match_ended`). Widgets are public fields
  (`player_frame, target_frame, skill_bar, team_frames, enemy_frames, boss_bar, combo, announce_banner, kill_feed,
  scoreboard, help, top_bar, spectate_label, defeat_overlay, result_panel`).
- Helper widgets are plain scripts loaded with `preload` (no extra global class names): `ui/hud_style.gd` (theme, fonts,
  palette, status table in `StatusSet.IDS` order), `hud_icons.gd` (procedural skill/status/portrait drawing),
  `hud_bar.gd`, `hud_status_row.gd`, `hud_unit_frame.gd`, `hud_skill_slot.gd`, `hud_skill_bar.gd`, `hud_team_frames.gd`,
  `hud_boss_bar.gd`, `hud_world_overlay.gd` (nameplates + lock-on reticle + crosshair, one `_draw`), `hud_combo.gd`,
  `hud_announce.gd`, `hud_kill_feed.gd`, `hud_scoreboard.gd`, `hud_help.gd`, `hud_top.gd`.
- Theme: loads `res://ui/theme.tres` when it exists (duplicated, HUD adds label outlines), else builds one with the
  §10 SystemFont list. Icons are drawn procedurally at runtime; `ui/icons/status_<id>.png` (25 files) are exported
  from the same code by `scenes/hud_preview.tscn -- --state=icons --shot=<png>` for other UIs that want textures.
- Kill feed: host uses `World.fighter_died` (with killer; a summon's kill is credited to its owner). Clients never
  get `died`, so the HUD also polls `is_alive()` at 25 Hz and reports "X 阵亡 Fell" (killer = `last_attacker_uid`,
  which is 0 on clients). A polled death waits a 0.4 s grace so a later `kill_event` (Match signal) can name the
  killer first. Each death is reported once (re-armed when the fighter is alive again).
- Score display (`score_changed`): team values are read from keys `0/1`, `"0"/"1"`, `"team0"/"team1"`, `"t0"/"t1"`,
  `"wins0"/"wins1"` or `wins: [a, b]`; optional extras `text` (free caption), `remaining: [a, b]` or `remaining0/remaining1`
  (arena roster left), `round`, raid `encounter` (0-based) + `encounters` + `name_cn/name_en`, `phase` (int, 0-based,
  raid) / `boss_phase` (1-based), `enraged` / `boss_enraged`, `boss_uid`, `clear_time`, `stats`. Raid
  (`settings.mode == "raid"`) shows the clear timer from `timer_changed` (MatchRaid sends `clear_time` there),
  interpolated locally between updates; it starts on the first timer/score update.
- Boss bar: shown for any fighter with `kind == "boss"`; the target frame hides when the lock-on target is that boss.
  Boss = fighter `score.boss_uid` if present. Phase shown = `boss.brain.phase + 1` (host; BossBrain.phase is 0-based)
  else `score.phase + 1` (raid int) else `score.boss_phase` else `mob_def.boss.phases` hp thresholds (entries i > 0)
  else thirds of HP. Enrage = hp <= 10 % or `score.enraged` / `score.boss_enraged` or `boss.brain.enraged`.
- Scoreboard reads Fighter counters (`kills/deaths/damage_dealt/healing_done`) merged with `Match.stats`,
  `score.stats` and the `match_ended` `result.stats` (max of each counter per uid), so clients see final stats.

### Requests (HUD)
- **NET (Match subclasses)**: Fighter kill/death/damage/healing counters are host-only (not replicated), so client
  scoreboards show zeros. Please mirror `Match.stats` to clients (e.g. a periodic reliable RPC or inside `score`
  as `score.stats`); the HUD already merges `match_node.stats` when it is filled on the client.
- **NET / CORE**: for client kill-feed killers, broadcast deaths with the killer uid (e.g. `Match` RPC
  `kill_event(victim_uid, killer_uid)` re-emitted as a signal, or replicate `Fighter.last_attacker_uid`). If NET adds a
  `kill_event(victim_uid: int, killer_uid: int)` signal on Match, the HUD will use it (append here when done).
- **RAID (BossBrain)**: done -- `phase` (0-based) / `enraged` on the brain and `score.phase` / `score.enraged`; the
  HUD reads both.
- **NET (match scene)**: create the Hud with `Hud.new()`, add it to the match scene, call `bind(world, match, 0)` after
  the World exists; call `set_local_uid(uid)` when spectating another fighter.

## AI

### Implementation notes (ai/bot_brain.gd, class BotBrain)
- Attached by `World.attach_brain(f, mode)` (`setup(f, mode)`); modes `pvp`, `raid`, `pet`, `mob`. Drives the fighter
  only through `f.input` (move, aim_point, target_uid, press(slot), jump). `think(delta)` does work at 20 Hz; in game it
  runs from the brain's own `_physics_process` when `World.auto_step` is true (host only).
- Difficulty = `Game.settings.bot_difficulty` (0..3) read once at attach; `brain.set_difficulty(d)` overrides it.
  Table `BotBrain.DIFF`: decision delay 0.45/0.30/0.16/0.08 s, aim scatter, projectile lead, combo follow-up chance,
  telegraph-dodge chance 20/45/70/90 %, quick-recovery (受身) chance 15/40/70/90 %, skill usage, spacing/parry chance.
  Static `BotBrain.rng_seed` / `difficulty_override` exist for deterministic tests.
- Skills are understood from their **steps** (`BotBrain.analyze_skill(skill)` -> profile dict: damage, launch, reach,
  aimed, delay, move toward/away, heal/revive, taunt, summon, cleanse, defensive, parry, ...), with tags as fallback.
  `custom` steps are inspected for embedded `args.step(s)` / `args.hit` / `args.dmg`; a custom skill whose damage is
  invisible still counts as an attack when tagged launcher/finisher/combo/melee/ranged/aoe/grab.
  Kits get correct AI by: accurate `range`, real step data where possible, and tags `escape`, `gap_closer`,
  `defensive`, `buff_self`, `buff_ally`, `interrupt`, `parry`/`counter` (or `defensive`+`interrupt` = parry stance:
  cast only reactively when an enemy melee wind-up targets the bot).
- Free aim: for aimed skills (non-homing projectiles, ground AoEs at target) the brain clears `input.target_uid` for that
  press and sets `input.aim_point` to a led/scattered point (difficulty), exactly like a human free-aiming.
- Team focus fire: the lowest-uid bot of a team stores the shared focus in `world.get_meta("ai_focus_<team>")`
  (`{uid, next}`), lowest effective hp with healer priority, re-evaluated every 1 s with hysteresis.
- `mob` mode (trash mobs, `kind` mob): proximity aggro 9 m (adds 1 threat), social aggro 8 m, targets
  `top_threat()`, leash 20 m from spawn (or target > 26 m from spawn) -> walks home, clears `fighter.threat` and calls
  `fighter.heal(max_hp)` on arrival. These two calls are the only non-input writes the brain makes (spec'd leash reset).
- `raid` mode: target = engaged boss > tank's target > engaged mob; "engaged" = the enemy targets or has threat from
  the party. The tank stands on the far side of the boss from the party (boss faces away), melee behind the boss,
  ranged behind/side at range. Human leader -> bots never pull; bot-only party -> the leader (tank or lowest uid)
  pulls the nearest pack after the current one is dead.
- Dodging: reads `World.effects` AreaEffects (enemy team, `_t < delay` telegraphs, persistent damaging zones, traps)
  with the same geometry as `AreaEffect.contains`; picks the nearest safe point (16 directions), uses an escape /
  defensive skill when walking out would be too slow. Higher difficulties also sidestep incoming projectiles.

### Requests (AI)
- **RAID**: BossBrain is RAID's; trash mobs can use `world.attach_brain(mob, "mob")`. Raid party bots use mode "raid".
- **NET/Match**: duel/arena/team bots use mode "pvp" (default of `Match.spawn_slot`), summons are attached as "pet" by
  CORE already.
- **KITS-mage**: Witch broom flight (double jump in mid-air) is not used by bots (they only fly after Broom Tornado).
- **Balance (lead)**: `tests/test_ai_matrix.gd` (difficulty 2, 90 s cap) currently shows average TTKs of 10-26 s,
  far below the 60-120 s target in ARCHITECTURE §6; consider `pvp_damage_scale` or kit numbers.

## NET

### Additions / conventions (superset of §3, §9; stub API kept: `Game.settings` keys, runtime InputMap, `Net.steam_ok`)
- **Net** (`autoload/net.gd`) is transport only. Signals: `hosted(transport)`, `connected`, `connection_failed(reason)`,
  `disconnected(reason)`, `lobby_ready(id)`, `lobby_list_received(Array of {id,name,mode,members,max,owner})`,
  `lobby_members_changed`, `peer_joined(id)`, `peer_left(id)`. API: `host_steam(name, max, friends_only)`,
  `refresh_lobbies()`, `join_lobby(id)`, `host_enet(port=27777)`, `join_enet(addr, port)`, `go_offline()`, `leave()`
  (-> OfflineMultiplayerPeer), `kick(peer)`, `invite_friends()`, `lobby_members()`, `set_lobby_data()`,
  `steam_call(method, args)`, `transport` ("offline"|"steam"|"enet"), `steam_status`, `local_name()`, `is_host()`,
  `is_online()`. All Steam access is dynamic (`Engine.get_singleton("Steam")`, `ClassDB.instantiate("SteamMultiplayerPeer")`),
  so nothing breaks without GodotSteam. User arg `--no-steam` skips Steam init (tests / LAN-only runs).
  Lobby data keys: `game=rongyao_arena`, `ver`, `name`, `mode`.
- **Game** (`autoload/game.gd`): `state` (enum State MENU/LOBBY/LOADING/MATCH) + `state_changed`, `roster_changed`,
  `message(text)`, `prefs_changed`. Extra settings keys `team_size` (team mode, 1..5); `rounds_to_win` default **2**
  (best of 3). Roster ops all go through `Game.request(op, args)` -> host `apply_op(sender, op, args)`
  (ops: hello, set_setting, add_bot, remove_slot, set_class, swap_team, set_ready, set_name) -> `_rpc_sync(get_state())`.
  Wrappers: `set_setting, add_bot, remove_slot, set_slot_class, set_my_class, swap_team, set_ready`. Queries:
  `my_slot(), slot_of_peer(), find_slot(), team_slots(), team_capacity(), team_count(), can_start(), class_label()`.
  Modes fill their capacity with bots automatically (duel 1v1, arena 3v3, team `team_size` v `team_size`, raid party of
  5 on team 0); a joining human replaces a bot. Prefs (`Game.prefs`: volume, mouse_sensitivity multiplier,
  bot_difficulty, player_name, class_id) live in user://settings.cfg (`load_prefs/save_prefs/apply_prefs`,
  `mouse_sensitivity()` returns the CameraRig value).
- **Match flow**: `Game.start_match()` -> RPC everyone to `scenes/match.tscn`; `modes/match_scene.gd` (root `MatchScene`,
  children `Map`, `World`, `Mode`, `Controller`, `SpectateCam`, `Hud`, `PauseMenu`, `Results`) calls
  `Game.on_match_scene_ready(self)`; once every human peer reported (25 s timeout) the host calls `begin_match()` ->
  `Mode.begin()`. `Game.return_to_lobby()` (host) brings everyone back to `scenes/main.tscn` (main menu shows the lobby
  while `Game.state == LOBBY`). `Game.results_auto_return` (default 30 s) auto-returns from the results screen.
  Clients change scene 0.5 s after the host so its despawn packets still find their nodes.
- **Map choice**: PvP uses `MapRegistry.create(settings.map_id)` (host fixes an unknown/empty id with
  `MapRegistry.default_id(mode)`); raid uses `RaidRegistry.create(settings.raid_id)` (default: first id). The scene
  calls `map.build()` only if the created map has no children yet. Missing registries -> built-in flat 40x40 map.
- **Mode nodes** are named `Mode` and use `process_physics_priority = -10` (they run before World). Countdown freeze =
  match-level input lock: while `frozen`, every fighter's FighterInput (move/pressed/held/jump) is wiped before
  `World.step`, so humans and bots are both frozen without statuses.
- `match_pvp.gd` (duel/team): score `{mode, phase, round, wins:[a,b], rounds_to_win}`; max rounds `2*rounds_to_win+1`
  (then most wins / draw -1); timeout -> higher team hp% wins the round. Extra signal `kill_event(victim_uid,
  killer_uid)` (all peers; summon kills credit the owner) and `Match.stats` mirrored to clients every 1 s and on every
  death (`_rpc_stats`), per the HUD request.
- `match_arena.gd` (extends match_pvp.gd): `queues`, `current`, `remaining(team)`; score adds `remaining:[a,b]`,
  `bout`, `current:[uid,uid]`. Waiting fighters are not spawned; dead ones are freed 2 s after the bout (stats kept).
  Bout timeout eliminates the lower hp% fighter (both when equal).
- A human leaving mid-match: their roster slot gets `peer 0` and name + " (AI)", `MatchScene.on_peer_left(peer)` sets
  the fighter's `peer = 0`, `kind = "bot"` (host-side only) and attaches `World.attach_brain(f, "pvp"|"raid")`.
- HUD binding: `Hud.bind(world, mode, 0)` and `set_local_uid(uid)` while spectating (0 when back on own fighter).
- `MatchScene.input_enabled = false` disables the local PlayerController (tests drive input themselves); the pause menu
  and results also disable it and send one neutral input so the fighter stops.
- UI scripts never use autoload identifiers directly (`Game.`/`Net.` fail `--check-only`); they resolve
  `/root/Game` and `/root/Net` at runtime. No NET script declares a `class_name`.

### Requests (NET)
- None blocking. Note for KITS-nightwalker: a 5v5 bot match with random real kits logged
  `ERROR: The object does not have any 'meta' values with the key 'nw_shadow_trap'` (probably `remove_meta(&"nw_shadow_trap")` on a fighter without it, classes/nightwalker/thief.gd:140/149; guard with `has_meta`).

## RAID

### Conventions / additions
- **Files**: `pve/mob_defs.gd` (17 defs: trash for both dungeons, elites, bone_minion summon, 2 bosses), `pve/boss_brain.gd`
  (BossBrain), `pve/raid_mob_brain.gd` (RaidMobBrain: fallback brain for modes "mob" and "raid"), `pve/raid_util.gd`
  (RaidUtil helpers), `pve/dungeon_base.gd` (DungeonBase extends MapBase), `pve/dungeon_frost_forest.gd`,
  `pve/dungeon_boneyard.gd`, `pve/raid_registry.gd` (RaidRegistry), `modes/match_raid.gd` (MatchRaid),
  `pve/raid_sandbox.gd` + `scenes/raid_sandbox.tscn`, `tests/test_raid_core.gd`.
- **Mob def extra keys**: `role` ("melee"|"ranged"|"tank"|"healer"|"elite"|"boss", AI hint) and, on bosses, `boss`
  (BossBrain data: phases/abilities/enrage). Boss skills slot 4/5/6 are animation-only skills (roar / invoke / channel)
  that BossBrain starts with `start_skill`; boss SkillDef cooldowns are tiny because BossBrain owns the rotation timers.
- **Raid ids**: `frost_forest` (冰霜森林, boss 冰霜巨人 Frost Golem) and `boneyard` (埋骨之地 Burial Grounds, boss 黑骑士
  Black Knight). `RaidRegistry.list()` -> [{id, name_cn, name_en, desc, boss_cn, boss_en, map_script, players}],
  `RaidRegistry.create(id) -> MapBase` (not built yet), `RaidRegistry.ids()`, `get_info(id)`.
- **Encounter dict** (MapBase.get_encounters) adds `room: Rect2` and optional `spawns: Array[Vector3]`.
  `get_checkpoint(i)` returns the cleared room centre; the boss index returns the previous room.
- **MatchRaid**: `setup()` creates and builds the dungeon itself when `p_map == null` and `settings.raid_id` is set
  (adds it next to the World), and builds a DungeonBase that is not built yet. The raid timer counts UP: MatchRaid
  overrides `_physics_process` (no base countdown) and broadcasts the clear time through `_rpc_timer` / `timer_changed`
  every 0.25 s. `score` (via `score_changed`) = {mode "raid", raid_id, encounter, encounters, state, name_cn, name_en,
  boss_uid, phase, enraged, wipes, clear_time, best_time}. Result of `match_ended` adds raid_id, best_time,
  new_record, wipes. Records: `user://records.json` keys `raid_best` {raid_id: seconds} and `raid_clears`
  {raid_id: count}; other keys in that file are preserved. Signals: encounter_started/encounter_cleared(index),
  raid_wiped(count), raid_cleared(time). Debug: `debug_skip_to(index)`. `brain_policy` "auto"|"internal",
  `auto_tick` (tests call `host_tick` manually).
- Mobs spawn idle (no brain) one encounter at a time; the brain is attached when a party member enters the encounter
  radius or hits a mob. Mob/boss hp scales by party size on team 0 (n/5, min 0.25). Party bots get fighter meta
  `raid_goal` (Vector3) = where to walk next. Fallen party members are revived (50% hp) when an encounter is cleared;
  out of combat the party regenerates 8%/s hp+mp.
- **BossBrain**: permanent `super_armor` except during a 3 s "break" (stagger meter from damage/hits, or a channel
  interrupted). A hit counts as crowd control when its source cast a skill that `RaidUtil.skill_is_cc()` (cc/launcher/
  grab tags, stun/launch/knockdown/grab hits, cc statuses) within the last 2.5 s (BossBrain connects to the party's
  `skill_cast` signals). Mechanics are BossBrain-run AreaEffects (`RaidUtil.spawn_area`) plus Fx area visuals for
  soak/stack circles.

### Requests (RAID)
- **AI (BotBrain)**: in mode "raid", when no engaged enemy is near, walk to `fighter.get_meta("raid_goal")` (Vector3,
  set every tick by MatchRaid; formation offset already included) so bots progress through the dungeon; do not attack
  mobs that have no brain and an empty threat table (idle, not pulled). In mode "mob", read `fighter.mob_def.role`.
  Dodge enemy AreaEffects still in their `delay` (raid-wide ones with radius > 15 cannot be dodged). When BotBrain is
  missing or fails to load, RAID uses its own `RaidMobBrain`.
- **CORE**: big boss bodies use `body_scale` 1.35, so their capsule (r 0.54) is much thinner than the Large-rig mesh
  and players can stand inside the model. An optional mob def key such as `body_radius` (capsule radius override)
  would fix this.
- **NET/UI**: for mode "raid", instantiate `modes/match_raid.gd` and either pass `RaidRegistry.create(settings.raid_id)`
  (built) as the map or pass null and let MatchRaid create it; HUD can show the boss bar from `score.boss_uid`, the phase
  from `score.phase`, and the up-counting clear time from `timer_changed`.

## Requests (MAPS)
- **AI** (BotBrain): `ArenaMap.is_hazard(pos: Vector3) -> bool` (virtual, false by default; `lava_cave` returns true for
  lava below y 0.4). Please look up the map (e.g. the World parent's / World's `Map` child, guarded with
  `has_method("is_hazard")`), reject probe points with `is_hazard(probe)` in `_probe_ok`, and treat "standing in a
  hazard" like `in_danger` so bots walk out of it. Without this, bots fight in the Lava Cave lava and burn.
- **NET** (`Game._ensure_map`): also require `id in MapRegistry.for_mode(mode)` ids, else fall back to
  `MapRegistry.default_id(mode)` (old_castle is not a duel map).
- **UI** (lobby map list): use `MapRegistry.for_mode(mode)` instead of `list("arena")` so only maps valid for the
  chosen mode are offered.
- Note: `hundred_blossoms` plateaus/bridge are 4.5 m high (was 3 m) so `World.ground_y()` (+4 m probe) under the bridge
  returns the valley floor. Map spawn index 0 is the centre of each team's spawn line (centre-out ordering).
  Floor torches now have a thin collision post (r 0.2, 1.5 m).

## wave3 CORE-FX

New public APIs (all backward compatible; old private workarounds such as `_charges/_cd/_pack_cooldowns()`,
`_to_neutral()`, `_knock_vel`, `SkillRunner._make_area()`, negative `atk_up` keep working until kits migrate).
- **Statuses** `atk_down` (patk & matk x(1-power), applied after atk_up/matk_up) and `cast_slow` (cast_speed x(1-power),
  so SkillRunner.rate of non-basic skills drops) appended at the END of `StatusSet.IDS` (bits 25, 26; every older bit is
  unchanged) and added to `StatusSet.NEGATIVE` (cleanse removes them, AI sees debuffs). `CharacterVisual.STATUS_IDS`
  updated (no dedicated visual yet).
- **Fighter.gravity_scale** (float, default 1) multiplies gravity, **Fighter.max_fall_speed** (> 0 caps fall speed,
  glide). Both are ignored while LAUNCHED (juggles stay consistent) and reset by `reset_for_round()`. Helpers
  `set_hover(gscale, fall_cap := 0.0)` / `clear_hover()`. Kits still own when to clear them (e.g. on being hit).
- **Summon hits**: when a fighter with `kind == "summon"` (kit null) deals a hit, CORE calls
  `owner.kit.on_hit_dealt(owner, victim, hit, dmg)` with `hit["_by_summon_uid"] = summon uid` (key removed after the
  call); only when the owner is valid, alive and has a kit. Summon damage/healing is added to the summon's own
  `damage_dealt`/`healing_done` AND to the owner's (scoreboards). Kits whose on_hit_dealt must ignore pet hits check
  `hit.has("_by_summon_uid")`.
- **hit["_blocked"]** (bool) is set on every hit passed to `on_hit_dealt` (true = guarded frontal hit).
  `Combat.would_block(victim, hit, from_pos) -> bool` exposes the rule.
- **ClassKit.apply_on_hit_status(f, victim, hit, id, dur, power := 1.0) -> bool**: guarded on-hit status for
  on_hit_dealt hooks; skips blocked hits (`_blocked`, else the block rule from `f`), dead/invuln victims (negative
  ids), downed victims unless `hit.otg`, victims grabbed by someone else, and disabling ids under super armor.
- **Charges/cooldowns**: `Fighter.max_charges(slot)`, `restore_charge(slot, n := 1)` (capped; a full slot stops its
  timer), `set_cooldown(slot, t)` (t > 0 = seconds until the next charge, a full slot loses one charge so the timer
  runs; t <= 0 refills the slot). Both repack `cooldowns_packed`/`charges_packed`.
- **Fighter.recover_to_neutral() -> bool**: clears knockback/juggle/no-recover, cancels upward launch velocity and
  leaves LAUNCHED / HITSTUN / KNOCKDOWN / GETUP / GRABBED for IDLE or AIR (STUNNED if a disabling status remains).
- **SkillRunner.spawn_area(params, pos, yaw) -> AreaEffect** (ground-style zone at an explicit point, no ground snap;
  follow_caster areas are bound to the cast). `ground` and `trap` steps accept `at: "point"` + `pos: Vector3`
  (clamped to bounds, snapped to the ground; ground lines start at `pos` along optional `yaw`).
- **Replicated (ON_CHANGE)**: `kit_counter: int`, `kit_counter_max: int` (0 = no max; host writes them for HUD stacks),
  `last_attacker_uid`, `kills`, `deaths`, and `net_damage_dealt` / `net_healing_done` (int mirrors of
  damage_dealt / healing_done pushed at most 4 Hz by `host_tick`; `Fighter.sync_stats()` pushes immediately). On
  clients the setters write `damage_dealt` / `healing_done`, so HUD code reading those fields works on every peer.
- **Mob / summon def keys** `body_radius` and `body_height` (meters, absolute; override `BODY_RADIUS * scale` /
  `BODY_HEIGHT * scale`) set the capsule, `radius()`, `height()` and `center()`. Height is at least 2 x radius.
- **Multi-victim grab**: victims held by one grabber are spread along the grabber's right axis (ordered by uid,
  spacing 2 x radius + 0.2 m).
- **Kit fighters with an empty `kit.model`** pass the class id to `CharacterVisual.create` (ASSETS request).
- **Client smoothing**: position is replicated as `net_pos` (getter = `position`; `facing_yaw` is listed first in
  `SYNC_ALWAYS` so every snapshot carries its yaw). Clients buffer snapshots and render the body
  `Fighter.interp_delay` (static, default 0.1 s) in the past, interpolating position and `rotation.y` between the two
  bracketing snapshots (holds the newest when late; jumps > 4 m snap = blink/reset). `facing_yaw`/`velocity` keep the
  latest values for logic; `latest_net_position()` returns the newest snapshot. `Fighter.client_smoothing = false`
  restores snapping. The host simulation is unchanged (host never buffers).
- **Fx lifecycle**: AreaEffect / Projectile call `Fx.despawn(fx_id)` from `_exit_tree()` while still alive (World freed,
  round reset); `World._exit_tree` finishes effects still in the tree and clears `effects`/traps. Projectile passes
  `homing` as `homing_rate` and re-issues `spawn_projectile_visual` (same id, new position/velocity) on every bounce.
  `Fx.clear_all()` now also stops every pooled voice and drops its stream; new `Fx.shutdown()` (clear_all + frees the
  voice pool, live one-shot nodes and the stream cache; the pool is rebuilt lazily by `sfx()`), and Fx `_exit_tree`
  stops voices. On the headless display server Fx prepares voices but never starts playback (`Fx.play_in_headless`
  to force), which removes the "ObjectDB instances were leaked" / "resources still in use at exit" lines from
  headless test runs (verified: test_kits_* / test_core_* tails are clean). `tests/test_core_base.gd` calls
  `Fx.shutdown()` before quitting.
- Tests: `tests/test_core_wave3.gd` (65 checks for all of the above). `tests/test_core_net.gd` now detaches Game from
  Net's session signals (the NET lobby handshake rejects + kicks a peer whose hello arrives outside LOBBY, which
  disconnected the raw CORE test client after ~1.5 s) and checks client snapshot buffering, replicated
  `last_attacker_uid` and the damage mirror.

RESOLVED (wave3): KITS-priest/KITS-mage gravity scale -> `Fighter.gravity_scale`, `max_fall_speed`, `set_hover()/clear_hover()`.
RESOLVED (wave3): KITS-priest/KITS-mage `atk_down` status -> added (NEGATIVE, bit 25).
RESOLVED (wave3): KITS-mage `cast_slow` status -> added (NEGATIVE, bit 26).
RESOLVED (wave3): KITS-priest KitBase guarded on-hit status helper -> `ClassKit.apply_on_hit_status()`.
RESOLVED (wave3): KITS-mage/KITS-gunner summon hits reach the owner's kit -> `on_hit_dealt(owner, ...)` + `hit["_by_summon_uid"]`.
RESOLVED (wave3): KITS-gunner `restore_charge` / `set_cooldown` -> `Fighter.restore_charge(slot, n)`, `set_cooldown(slot, t)`.
RESOLVED (wave3): KITS-gunner public `spawn_area` / ground at point -> `SkillRunner.spawn_area()`, `at: "point"` + `pos`.
RESOLVED (wave3): KITS-gunner blocked flag -> `hit["_blocked"]` in on_hit_dealt, `Combat.would_block()`.
RESOLVED (wave3): KITS-gunner/ASSETS Fx pooled SFX leaks at exit -> Fx.clear_all stops voices, Fx.shutdown, headless never starts playback.
RESOLVED (wave3): KITS-unspecialized replicated per-fighter counter -> `Fighter.kit_counter` (+ `kit_counter_max`).
RESOLVED (wave3): KITS-nightwalker `recover_to_neutral()` -> added.
RESOLVED (wave3): KITS-fighter multi-victim grab offset -> sideways spread in `_tick_grabbed`.
RESOLVED (wave3): RAID `body_radius` -> mob/summon def keys `body_radius` / `body_height`.
RESOLVED (wave3): HUD client kill-feed killer -> `last_attacker_uid` replicated ON_CHANGE; kills/deaths + damage/heal mirrors replicated.
RESOLVED (wave3): ASSETS CORE requests (move_area_visual for followers [already done], despawn from `_exit_tree`, homing_rate + bounce re-issue, class id as model) -> done.

## Requests (wave3 CORE-FX)
- **HUD** (`ui/hud_style.gd`): `StatusSet.IDS` gained bit 25 `atk_down` and bit 26 `cast_slow` (both negative). Please
  append two rows to `STATUS_INFO` (e.g. `["弱", "攻击降低", "Attack Down", Color(0.75, 0.35, 0.3), "物理与法术攻击降低",
  "Physical and magic attack reduced"]` and `["迟", "施法减速", "Cast Slow", Color(0.55, 0.5, 0.8), "施法速度降低",
  "Cast speed reduced"]`), add 25 and 26 to `NEGATIVE_BITS`, and give `hud_icons.gd` / the `ui/icons/status_<id>.png`
  export a glyph for them. Until then the badges are simply not shown (loops are bounded by STATUS_INFO.size()).
- **HUD**: `Fighter.kit_counter` / `kit_counter_max` (replicated) can be shown on the player frame (e.g. stack pips when
  `kit_counter_max > 0`); `last_attacker_uid`, `kills`, `deaths`, `damage_dealt`, `healing_done` are now valid on clients.
- **KITS** (migration, optional): Witch broom / Cleric wings / Mechanic rotor -> `gravity_scale` or `set_hover()`;
  Exorcist seal / Witch powder -> `atk_down`, Witch powder cast slow -> `cast_slow`; Sharpshooter Dual Load ->
  `restore_charge`; gunner bombardments -> `runner.spawn_area`; `GU.was_blocked` / Knight daze -> `hit["_blocked"]` or
  `apply_on_hit_status`; Ninja Body Replacement -> `recover_to_neutral()`; Unspecialized Myriad stacks ->
  `f.kit_counter`; Summoner / Mechanic pet passives -> `on_hit_dealt` with `_by_summon_uid`.
- **NET**: the lobby hello/reject path kicks any peer whose hello arrives while `Game.state != LOBBY` (including
  raw-ENet test clients); `test_core_net.gd` now detaches Game from Net's signals to stay independent.

## NET-HUD (wave3)
- Verified in code and end to end: `match_pvp.gd` / `match_arena.gd` publish `kill_event(victim_uid, killer_uid)` (all
  peers; summon kills credit the owner) and mirror `Match.stats` to clients every 1 s and on each death; the HUD
  consumes both (client kill feed names the killer; scoreboard merges `Match.stats`). Fighter counters
  (kills/deaths/damage_dealt/healing_done) are still host-only in `Fighter.SYNC_ON_CHANGE`, so the stats mirror stays the
  client source; the HUD already merges the Fighter counters too if CORE-FX replicates them later.
- `MatchScene` builds the HUD itself (`Hud.new()` via ui/hud.gd, `bind(world, mode, 0)`, `set_local_uid(uid)` while
  spectating, back to 0 on the own fighter) and now hides it while the results screen is shown.
- New suite `tests/test_net_e2e.gd`: main menu + lobby load, class picker shows all 25 classes (CN + EN), lobby map list
  per mode == `MapRegistry.for_mode` / `RaidRegistry.ids()`, then duel / arena / team 5v5 / raid each run to completion
  with bots only (Engine.time_scale 4, round_time 30), checking HUD bind, kill_event count == deaths, boss bar,
  result data on the results screen and the return to the lobby. The raid uses a temp records path.
- UI fixes from the e2e screenshots: class picker is one row per group (all 25 classes visible at 1600x900, dark chips
  with the class tint stripe instead of tinted text on grey); lobby teams are stacked so slot rows keep the player
  name (it was clipped to nothing); long one-line bilingual HUD announcements split into a CN headline + EN sub
  line (no longer run over the party frames); results screen uses a darker dim, hides the HUD, and labels raid rows
  "队伍 Party"; HUD raid clear timer updates immediately on `timer_changed` / `score.clear_time` (fixed a timing-flaky
  test_hud_basic check); team frame captions are no longer bold 13 px (were mushy).
- RESOLVED (wave3): MAPS request "Game._ensure_map: require id in MapRegistry.for_mode(mode)" -> `_ensure_map` keeps
  `map_id` only if it is in `for_mode(mode)`, else `default_id(mode)` (or the first valid map); `raid_id` must be in
  `RaidRegistry.ids()`, else the first raid.
- RESOLVED (wave3): MAPS request "lobby map list per mode" -> lobby already filters `list("arena")` by each entry's
  `modes` (identical to `for_mode`); verified by test_net_e2e for all four modes.
- RESOLVED (wave3): HUD request "mirror Match.stats to clients" -> `_rpc_stats` (1 s + on death), checked on the ENet
  client in test_net_enet.
- RESOLVED (wave3): HUD request "kill_event(victim_uid, killer_uid) on Match" -> present on match_pvp/arena; ENet client
  test now also checks the HUD kill feed names the host killer.
- RESOLVED (wave3): HUD request "Hud.new() / bind / set_local_uid in the match scene" -> done by modes/match_scene.gd,
  checked by test_net_e2e for every mode.
- RESOLVED (wave3): RAID request "NET/UI raid wiring" -> MatchScene creates `RaidRegistry.create(raid_id)` + builds it
  and instantiates modes/match_raid.gd; lobby lists raids; HUD boss bar from `score.boss_uid/phase/enraged` and the
  clear time from `timer_changed`; results show clear time / record / wipes. Verified end to end.

## Requests (wave3 NET-HUD)
- **RAID / AI (balance)**: a bots-only party (difficulty 3, random real classes) reaches the Frost Golem naturally in
  ~50 s but cannot kill it: test_net_e2e runs ~720 sim s at the boss with 11-18 wipes and the boss still at 73-95% hp
  (the test then finishes the boss and prints a NOTE). Boss hp 320k (party-size scaled) vs ~2-5k damage per bot per
  attempt; consider lower boss hp / mechanics damage for bot parties or better raid-mode bot survival.
- **KITS-nightwalker** (repeat of the NET note): `ERROR: The object does not have any 'meta' values with the key
  'nw_shadow_trap'` still appears in bot matches (thief.gd remove_meta without has_meta).

## AI (wave3)
- `ai/bot_brain.gd` integration additions (all through `fighter.input`, nothing else written except the spec'd mob leash):
  - **Raid mode**: idle mobs (kind mob/boss, no brain, empty threat table) are never targeted, assisted or used for
    pulls (`_is_idle_mob`); party bots with fighter meta `raid_goal` walk to it when no engaged enemy exists (a living
    human party member is still followed instead, so bots never pull ahead of a human). Without `raid_goal` the old
    leader pull applies, restricted to brained enemies. Pets also ignore idle mobs.
  - **Boss mechanics** are read duck-typed from the boss's brain (`boss.brain.get("shares")` / `get("channel")`,
    RAID BossBrain): soak circles -> the `min + 1` party members nearest to the circle (tank ranked last) walk in and
    do not start casts until inside; channels -> crowd-control skills (damaging + cc/launcher/knockdown/grab/pull/
    disable) are planned and fired into the boss (`interrupts_attempted`). Raid-wide telegraphs make the healer top
    everyone up (threshold 0.92). Threat discipline: non-tank bots stop attacking a boss while their threat is >= 85%
    of the tank's (or the tank has not opened yet). Tanks use defensive cooldowns while the boss is on them; healers
    stay 8-14 m from the boss and never melee it; non-tank bots step out of a boss's front cone.
  - **Mob mode**: role from `mob_def.role` (`elite`/`boss` act as melee; `ranged`/`healer` mobs keep their distance).
  - **Hazards**: `BotBrain.find_hazard_map(world)` = World / its parent / a sibling / a child with `is_hazard(pos)`
    (re-scanned every 2 s until found). Probe points (centre + both shoulders) inside a hazard are rejected, the
    hazard counts as danger for goals / safe-point search, and standing in a hazard triggers a walk-out dodge.
  - **Zones**: enemy persistent damaging zones were already avoided; checked by a new test.
  - **Parry stances** (`defensive` + `interrupt`, or `parry`/`counter` tags): pressed when an enemy melee cast aimed at
    us (or within 3 m) will land within 0.45 s (`BotBrain.time_to_strike(e)` reads the enemy runner's next
    melee/multi_melee/grab/dash-hit step) and we are inside its reach; perception delay = 0.6 x react, chance =
    difficulty `dodge`. While a parryable swing is < 1 s away the bot does not start new attacks (difficulty >= 1).
    One reaction per enemy cast (runners are reused, so keyed on enemy uid + cast start).
  - **Witch broom flight**: kits with `is_flying(f)` get a flight driver (jump, then a second jump press in mid-air
    mounts; flaps below 1.8 m). Used to escape when low / swarmed in melee and to cross hazards that block the path.
  - **OTG**: a downed target is punished with an OTG damaging skill castable in range (Sharpshooter Punisher); the
    OTG skill plan approaches instead of hovering at 2.6 m.
  - **Summoner Switch** (any skill with a custom step whose method contains "switch"): only chosen when a living summon
    is >= 5 m away with no enemy within 4 m of it (on top of the kit's `can_cast_extra`).
  - **Gadgets**: `trap` steps with `at` "target"/"aim_point" are analysed as ranged placements (reach = min(max_distance,
    skill range)), pressed with the lock-on kept, so Mechanic mines/coils land on the target.
  - **Team play**: tanks taunt an enemy whose lock-on (or top threat for mobs) is our healer (`healer_taunts`);
    healers revive only when safe (no telegraph/zone/hazard on them, no raid-wide hit < 2 s, hp > 35%, no enemy within
    4 m of them or of the corpse, no living ally < 25% hp); ranged bots that lose line of sight (World.raycast) move to
    the nearest band point that sees the target (also for raid positions).
  - Counters for tests: `flights_started`, `parries_attempted`, `interrupts_attempted`, `healer_taunts`.
- Tests: `tests/test_ai_brain.gd` +21 checks (hazard, zone, raid_goal/idle mobs, soak + interrupt, parry timing, witch
  flight, punisher OTG, summoner switch, gadgets, tank peel, safe revive, LOS, Lava Cave). New `tests/test_ai_raid.gd`:
  full MatchRaid runs (brain_policy "auto", real kits knight/cleric/elementalist/blade_master/sharpshooter) on every
  raid, reports clear times, wipes per encounter, boss hp at each wipe, boss events and party deaths by source
  (env AI_RAID_IDS / AI_RAID_CAP / AI_RAID_PARTY / AI_RAID_DIFF / AI_RAID_STRICT / AI_RAID_DEBUG).
RESOLVED (wave3): RAID "raid mode walks to raid_goal when idle, never attacks unpulled idle mobs" -> done (see above).
RESOLVED (wave3): RAID "mob mode reads fighter.mob_def.role" -> done (elite/boss -> melee, ranged/healer kite).
RESOLVED (wave3): RAID "dodge enemy AreaEffects in their delay; raid-wide (radius > 15) ones are not dodged" -> already
  in place, kept (defensives / pre-heals react instead).
RESOLVED (wave3): MAPS "is_hazard in _probe_ok + standing in a hazard = danger" -> done (map lookup via World parent /
  sibling / child).
RESOLVED (wave3): KITS-mage "Witch broom flight (mid-air double jump) unused by bots" -> flight driver (escape / hazards).
RESOLVED (wave3): KITS-mage "Summoner Switch needs a living summon" -> gated (living summon >= 5 m away, safe).
RESOLVED (wave3): KITS-fighter "parry stances timed before an enemy melee swing" -> strike-time based parry.
RESOLVED (wave3): KITS-gunner "Punisher on downed targets; gadgets at the target; Rotor Wings escape" -> OTG punish,
  trap-at-target analysis (Rotor Wings already an escape via its tags).
RESOLVED (wave3): NET-HUD "better raid-mode bot survival" -> soak stacking, interrupts, threat discipline, tank
  defensives, healer spacing, front-cone avoidance (bosses still not killable, see Requests (wave3 AI)).

## Requests (wave3 AI)
- **RAID (balance)**: with the AI above, a real-kit bot party (knight/cleric/elementalist/blade_master/sharpshooter)
  clears all trash on both raids without a wipe (frost_forest trash done at ~54 s, boneyard at ~66-72 s) and passes
  most soaks (boneyard bone_prison 5 ok / 4 fail at difficulty 2, 7 ok / 1 fail at difficulty 3, per 600 s; was
  0 ok / 8 fail), but neither boss dies: Frost Golem wipes 7 times per 600 s with the boss at 60-72% (always around
  the 70% phase-2 transition: avalanche + wolves + frost bomb), Black Knight 6 times per 600 s at 62-93%. Boss damage on the tank (~600 dps incl. Glacial Cleave 6.5x) exceeds one
  Cleric's sustained healing (~280-400 hps: Heal 6 s cd + Cure 12 s cd), and party dps (~1% boss hp/s) needs ~100+ s.
  Suggest lower boss hp (e.g. 50-60%) and/or tank-buster / smash damage for 5-man parties, or a soft "bot party"
  multiplier. Probe: `tests/test_ai_raid.gd` (AI_RAID_DEBUG=1 prints per-second boss target / party hp / deaths).
- **RAID (nice to have)**: expose the current ability telegraph intent on BossBrain (e.g. `next_ability` / `casting`)
  so tanks can pre-cast defensives before tank busters; bots currently only react to the AreaEffect telegraph.
- **KITS-nightwalker** (repeat): matrix runs still log `ERROR: ... 'meta' values with the key 'nw_shadow_trap'`
  (thief.gd remove_meta without has_meta).

## KITS-MIGRATE (wave3)
- All 25 kits now use the wave3 CORE APIs; the private workarounds (`Fighter._charges/_cd/_pack_cooldowns()`,
  `_to_neutral()`, `_knock_vel`, `SkillRunner._make_area()`, negative `atk_up`, `velocity.y` gravity hacks, absolute
  `stat_bonus` writes) are gone from `classes/`. Superseded notes in the KITS-* sections above (Exorcist seal as a
  negative `atk_up`, Witch powder `stat_bonus` bookkeeping + `mage_powder_share`, Witch / Cleric / Mechanic gravity
  hacks, `GU.restore_charge` touching `_charges`, Unspecialized host-only `myriad_stacks`) no longer describe the code.
- New shared helper `classes/_kit_util.gd` (`KU.set_bonus_share(f, key, share_meta, want)`; `_` prefix so Registry skips
  it): additive own-share `stat_bonus` writes. Used by Sharpshooter (Rapid/Burst Firing atk_speed/crit), Launcher
  (Artillery Mastery dmg_out), Battle Mage (Battle Spirit atk_speed/move_speed/patk, also reset on spawn), Qi Master
  (True Qi Protection pdef/mdef), Blade Master (Sword Mastery atk_speed), Cleric (Meditation mp_regen), Berserker,
  Ghostblade, Unspecialized.
- `GU.was_blocked()` reads `hit["_blocked"]` (falls back to `Combat.would_block()`); `GU.burst_at()` and
  `MU.area_at()` call `SkillRunner.spawn_area()`; `GU.restore_charge()` calls `Fighter.restore_charge()`.
- On-hit statuses go through `ClassKit.apply_on_hit_status()`: Knight Shield Attack daze, Spitfire Ice Bullet freeze,
  Mechanic gadget mark, Brawler claw poison (now blocked by a frontal guard), Ghostblade / Spellblade freeze riders.
  Rolls are skipped on `_blocked` hits before consuming `Combat.rng`.
- Pet passives through summon-hit forwarding (`hit["_by_summon_uid"]`): Mechanic seeker robots / bomber drones now
  apply the Mechanical Box mark like gadgets; Summoner 印记 Mark: pet hits on the Summoner's marked enemy deal +20%
  (true-damage rider, owner-credited; `kit.is_marked_by(f, e)`, counter meta `mage_mark_pet_hits`). Desc texts updated.
- Witch 驱散粉 Disperse Powder = `atk_down` 0.2 + `cast_slow` 0.3 + `slow` 0.35 (8 s), all cleansable;
  `powder_share(e)` now returns the `atk_down` power. Broom flight / Cleric Angel Wings / Mechanic Rotor Wings use
  `set_hover()` / `clear_hover()` (cleared on landing, knock-off, expiry and death).
- Unspecialized 千变 Myriad Forms stacks live in `Fighter.kit_counter` (`kit_counter_max` = 5), so `myriad_stacks()`
  and HUD pips work on clients.
- Canon audit vs `docs/research/glory-classes-verified.json` (names CN/EN, weapons, famous players for all 25): two
  slips fixed -- Berserker weapon `重剑` -> canon `大剑` (Greatsword); Striker basic finisher `回旋踢` (that is the
  Sharpshooter's canon 回旋踢 Roundhouse Kick) renamed `旋身踢` (descriptive basic, not canon).
RESOLVED (wave3): CORE-FX "KITS migration" (gravity_scale / set_hover, atk_down, cast_slow, restore_charge, spawn_area,
  _blocked / apply_on_hit_status, recover_to_neutral, kit_counter, summon on_hit_dealt) -> done in all kits (above).
RESOLVED (wave3): KITS-priest "all kits writing stat_bonus: write additively" -> every absolute write converted (KU helper).
RESOLVED (wave3): AI / NET-HUD "thief.gd nw_shadow_trap meta error" -> root cause was `get_meta(key, null)` (a null
  default counts as no default and errors on a missing key); now `has_meta`-guarded get + `_clear_shadow_trap()`.
  test_ai_matrix (300 fights) logs no ERROR line.

## wave3 RAID-TUNE
- **Boss / elite capsules**: mob defs carry CORE's `body_radius` / `body_height` (table `BODY` in pve/mob_defs.gd):
  frost_golem 1.3 / 4.0, black_knight 1.2 / 4.4, bone_champion 0.8 / 2.8, orc_warlord 0.75 / 2.6, werewolf_elite 0.7 / 2.4.
  Boss melee step ranges are measured from the centre, so they grew by the radius (smash 4.6, slash 4.4); BossBrain
  `melee_range` (surface gap) is 3.0.
- **Pacing / numbers** (bot party of 5, real kits): `TRASH_HP` = 2.8 x listed hp for every non-boss, non-summon def
  (packs take ~40-60 s); Frost Golem 600k hp, Black Knight 580k; boss patk/matk lowered (510/590, 550/590), tank
  autos 0.8x, tank busters 4.0 / 3.5x, raid-wide 1.5x / 1.8x; dodgeable mechanics keep their bite (frost bomb 1.8x,
  ice-zone burst 1.4x, stomp 1.8x, grave spikes 1.8x, charge 2.4x) and have shorter telegraphs (0.85-1.3 s), so bot
  difficulty matters. Red-blood enrage is haste / cooldowns only (no damage buff).
- **BossBrain additions**: `berserk {time, atk_up, haste}` hard enrage (Frost Golem 360 s, Black Knight 300 s after the
  pull; 30 s warning) -> `log_events` "berserk"; `add_hp` / `add_dmg` / `add_life` (phase adds spawn at 50% hp, deal
  60% damage and dissolve after 20 s, "add_expired"), because party bots always focus the boss; abilities unlocked by a
  phase start on their `first` timer (no burst of every new ability at the 70% transition); `casting` dictionary
  `{id, kind, left, tank_buster}` while a non-auto ability winds up (for AI pre-casting defensives / pre-heals).
- Boss adds: Black Knight phase 2 uses the new `grave_necromancer` (raises 1 minion, no heal: the trash necromancer's
  12%-of-max-hp mend healed the boss for ~40k); Frost Golem phase 3 uses ice_archer + frost_wolf (frost_shaman's mend
  healed the boss the same way).
- **MatchRaid**: trash / add brains are pinned to `MOB_DIFFICULTY` 2 (`set_difficulty`), so encounter difficulty does
  not follow the party bot difficulty setting; raid supplies `RAID_MP_REGEN_BONUS` (+100% mp_regen, additive
  `stat_bonus`, own share in fighter meta `raid_mp_regen`) -- PvP-sized mana pools ran dry 90 s into a boss and healing
  stopped; `spawn_add` applies the boss's add_hp / add_dmg; `format_time` no longer prints "14:60.00".
- New test `tests/test_raid_clear.gd` (deterministic full dungeon clears with real kits + BotBrain; default both
  dungeons diff 3 tank+healer with strict checks; `-- --quick` Frost Forest only; `-- --matrix` diff 1/3 x
  {tank+healer, no healer}; `--seed=N`, `--diff`, `--party`, `--cap`, `--verbose`). Reports clear time, wipes per
  encounter, boss ability usage counts, soak / interrupt results, party deaths by source and a stuck watchdog.
  `tests/test_raid_core.gd` updated for the new hp band / capsules / add rules.
- Results (seed 0, cap 20 min sim): Frost Forest diff3 tank+healer clear 6:08 0 wipes; diff1 fail (3 wipes at 20/4/11%);
  no healer fail at diff 3 and 1 (8-9 wipes at ~50-60%). Burial Grounds diff3 clear 6:58 0 wipes; diff1 clear 17:31
  with 2 wipes; no healer fail (9 wipes). Over seeds 0-5 diff3 wipes were 0-1 per dungeon (FF 0,0,0,0,1,1; BY
  0,0,0,0,0,1).
RESOLVED (wave3): CORE `body_radius` -> applied to bosses and elites (see above).
RESOLVED (wave3): AI "RAID (balance): bosses not killable by a real-kit bot party" -> retuned; diff-3 tank+healer
  parties clear both dungeons (test_raid_clear).
RESOLVED (wave3): AI "RAID (nice to have): expose the current ability telegraph" -> `BossBrain.casting`.
RESOLVED (wave3): NET-HUD "RAID / AI balance: bot party cannot kill the Frost Golem" -> retuned (see results).

## Requests (wave3 RAID-TUNE)
- **AI (BotBrain)**: in raid mode bots always target the boss while it is engaged, so boss adds are only peeled by the
  tank; RAID now makes adds weak and timed (`add_life`). Killing adds first (dps switch to living adds of the boss,
  `boss.brain.adds`) would let RAID give adds real teeth again. `BossBrain.casting` (`tank_buster` true) can drive
  pre-cast tank defensives; `kind == "raid_aoe"` can drive pre-heals.
- **AI / CORE (info)**: one in ~16 concurrent headless raid runs ended in a silent crash (once at exit, once mid-run at
  the start of a new raid in the same process); not reproducible on rerun with the same seed. Watch for it in
  long multi-raid suites.

## wave3 BALANCE
- `pvp_damage_scale` stays at 0.25 (from the interrupted first BALANCE pass); average 1v1 TTK at difficulty 2 is ~78 s,
  so all further tuning was per kit (numbers only, launch / juggle values untouched).
- Per-kit changes this pass (on top of the committed first-pass stat edits):
  - unspecialized: basics 0.36/0.36/0.5 -> 0.6/0.6/0.85 with cast 0.45/0.45/0.6 -> 0.34/0.34/0.48; skills x~1.35
    (sky 1.25, tooth 1.5, missile 0.6, draw 1.2 + wave 0.7, stamp 1.4, bash 1.2, ult hits x1.4); cooldowns sky 7->5,
    tooth 8->6, missile 11->9 (mp 70->60), draw 10->8, stamp 11->8, bash 12->9; stats hp 8000->7800, patk 700->660,
    matk 660->620. Its multipliers were about half of every other melee kit (9% win rate).
  - ghostblade: hp 7300->8200, pdef/mdef 380/480->440/500; basics 0.8/0.8/1.0->0.95/0.95/1.15; claw 1.1->1.3,
    moonlight 1.4->1.7, full moon 2.2->2.5 (cast 0.7->0.55, cd 9->7); ice / silence boundary ticks 0.25/0.15->0.45/0.3,
    cd 12/14->10/12. Slots 4-6 barely connecting is placement (boundary dropped where the target stood, it walks out),
    not range / radius numbers.
  - summoner: hp 5800, matk 510->470; spirit cd 6->11, life 25->18 s, spirit bolt 0.42->0.3 hitstun 0.3->0.2
    (thunder 0.6->0.4); goblin hp 1900->1000 patk 340->300 club 0.6->0.5 hitstun 0.35->0.25; flower hp 1600->900
    matk 380->330; spirits hp 1000->600 matk 360->320; staff bolt hitstun 0.3/0.4->0.2/0.3. Pets were soaking enemy
    damage and hit-stunning melee for ~35% of the fight (94% win rate).
  - ninja: hp 6800->6400; basics 0.75/1.05->0.68/0.95; shuriken cd 4->6, stun 0.6->0.4; smoke blind 2.5->1.5 s;
    tunnel stun 1.6->1.0; shadow clone cd 12->15, clone hp 900->500, decoy taunt 1.5->1.0 s.
  - elementalist: matk 520->450; bolt hitstun 0.3/0.4->0.2/0.3 (ranged basic chains were stun-locking melee).
  - witch: matk 545->520; broom basics 0.7/0.95->0.62/0.85; Magic Missile cd 3->4.5.
  - thief: hp 6800->6500; basics 0.65->0.55; poison trap poison power 1.5->1.1; ambush stun 3.0->2.0.
  - striker: basic reach 2.0/2.2->2.4/2.5 (melee range + skill range; was the shortest melee reach in the game),
    jab/cross arc 90->100.
  - sharpshooter: hp 7600->8000; revolver bullets 0.25->0.35.
  - knight: hp 11500->13000, patk 620->640, pdef/mdef 640/520->760/600 (patk kept low so the raid clear time stays
    inside RAID's 330 s floor).
  - cleric: hp 6200->7100, pdef 300->340.
  - mechanic patk/matk 640/440->690/470; grappler patk 680->720; launcher patk 690->720; exorcist patk/matk
    520/590->540/620.
- Tests: `test_kits_priest` hp band 9600 -> 13000 (tanks); `test_kits_unspecialized` mini-fight DPS ceiling 550 -> 1000
  (same band style as the swordsman suite); `test_ai_matrix` gained `--only=a,b` (pairings that include those kits)
  and `--strict` skips kits with no fights.
- Final matrix (difficulty 2, 25 kits, 300 pairings x 4 reps mirrored, before the last elementalist / cleric touch-up):
  avg TTK 77.7 s, every kit 30-71% except elementalist 70.8% and cleric 24.0%; after matk 450 / cleric hp 7100 a
  focused re-run (`--only=elementalist,cleric`, 188 fights) gives 67.7% / 29.2%.
- 3v3 (`--team`, 4 support comps x 4 dps comps x 4 reps): avg resolve ~80 s (target 60-150 met) but the support comps
  win ~80% (target 35-70% NOT met). Nerfing cleric heals (cd 6->7, cure 0.16->0.14, revive 0.4->0.3) or knight's
  taunt (4->2.5 s) moved it by at most 5 points, so the edge is not in heal / taunt numbers; changes reverted.

## Requests (wave3 BALANCE)
- **AI (BotBrain)**: 3v3 support comps (tank + healer + dps) beat 3-dps comps ~80% of the time. Likely target choice:
  dps bots spend their damage on the tank (taunt / nearest) while the healer is untouched. Suggest dps bots prefer
  the healer / squishiest enemy when not taunted and only obey taunt for its duration. Re-check with
  `test_ai_matrix.gd -- --team --reps=4` (shard with `--shard=i/n`).
- **AI**: `test_ai_brain` "witch bot mounts the broom (double jump) to escape melee pressure" fails (0 flights) at the
  committed HEAD too (checked on a HEAD copy of classes/), so it predates this pass; the test does not reseed
  `Combat.rng` / `BotBrain` before it, so the duels earlier in the suite change its outcome.
- **CORE (tests)**: `test_core_combat` (4 fails) and `test_core_skills` (3 fails) expect 1.0x damage, but they run
  with the shipped `pvp_damage_scale` 0.25 (default since the first BALANCE pass). They should pin
  `Game.settings.pvp_damage_scale = 1.0` (or not be in PvP mode).
- **RAID**: test_raid_clear's 330 s floor sits right at HEAD's own Frost Forest time (5:37). The default suite passes
  (5:34 / 6:10, 0 wipes), but over seeds 0-5 two seeds clear in 5:21-5:24 and fail the floor. A few % more trash /
  boss hp, or a slightly lower floor, would give kit tuning room.
