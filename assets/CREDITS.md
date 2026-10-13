# Rongyao Arena - Asset Credits 素材致谢

Every third-party asset in `res://assets/` is released under **CC0 1.0 (public domain dedication)**.
Attribution is not required, but it is given here gladly. License texts are in `assets/licenses/`.

| Pack | Author | License | Used for | Folder |
|---|---|---|---|---|
| KayKit Character Animations 1.1 (Rig_Medium, Rig_Large) | Kay Lousberg (KayKit), www.kaylousberg.com | CC0 1.0 | all animations | `anims/` |
| KayKit Adventurers 2.0 (characters + weapons) | Kay Lousberg (KayKit) | CC0 1.0 | player bodies, weapons | `characters/`, `weapons/adv/` |
| KayKit Skeletons 1.1 (characters + weapons) | Kay Lousberg (KayKit) | CC0 1.0 | mobs, mob weapons | `characters/`, `weapons/special/` |
| KayKit Mystery Monthly Series 4 / 5 / 6 (characters + props) | Kay Lousberg (KayKit) | CC0 1.0 | player bodies, bosses, weapons | `characters/`, `weapons/special/` |
| KayKit Fantasy Weapons Bits 1.0 | Kay Lousberg (KayKit) | CC0 1.0 | weapons | `weapons/fantasy/` |
| KayKit Prototype Bits 1.1 (Gun_Pistol/Rifle/Sniper) | Kay Lousberg (KayKit) | CC0 1.0 | rifle | `weapons/guns/` |
| KayKit Dungeon Remastered 1.1 (all 283 pieces) | Kay Lousberg (KayKit) | CC0 1.0 | arenas, raid dungeon | `env/dungeon/` |
| KayKit Forest Nature Pack 1.0 (Color1 subset) | Kay Lousberg (KayKit) | CC0 1.0 | rocks, trees, bushes, cliffs | `env/nature/` |
| Kenney Particle Pack 1.1 (57 of 193 textures) | Kenney (www.kenney.nl) | CC0 1.0 | VFX sprites | `vfx/` |
| Kenney UI Pack: RPG Expansion (67 of 90 PNGs) | Kenney | CC0 1.0 | panels, bars, buttons, cursors | `ui/` |
| Kenney RPG Audio (21 of 52 sounds) | Kenney | CC0 1.0 | SFX | `sfx/*.ogg` |
| Kenney Impact Sounds (29 of 130 sounds) | Kenney | CC0 1.0 | SFX | `sfx/impact*.ogg`, `sfx/footstep_*.ogg` |
| Rongyao synthesized SFX (`sfx/synth_*.wav`, 12 files) | Rongyao Arena project (generated procedurally with numpy) | CC0 1.0 | magic, explosion, shot, cannon, heal, buff, debuff, lightning, ice, whoosh, ui click, ultimate | `sfx/synth_*.wav` |

**Important note about the KayKit "Mystery Monthly" and collection files:** the KayKit character,
animation, prop and environment files were taken from an **unofficial GitHub mirror**
(`GeorgeQLe/assets-kaykit-3d-characters`, `-props`, `-environments`) of *The Complete KayKit Collection v6*,
which is a **paid bundle**. The bundle's own license file (copied to `licenses/KayKit-CC0-License.txt`) is CC0,
so use is legal, but the Mystery Monthly packs are normally only available to paying supporters.
**Please support the author**: buy the KayKit collection / EXTRA tiers on itch.io (kaylousberg.itch.io) or join
Kay Lousberg's Patreon. The Adventurers 1.0, Skeletons 1.0 and Dungeon Remastered 1.0 packs are also available
for free from the official KayKit-Game-Assets GitHub repositories.

One texture was missing from the mirror's `OrcRaider.glb`; `characters/OrcRaider_orc_texture_A.png` comes from the
same pack's `textures/` folder and is applied at load time by `CharacterVisual.TEXTURE_FIX`.

---------------------------------------------------------------------------------------------------
## Class -> body mapping (CharacterVisual.CLASS_MODEL)

All 25 classes have a distinct KayKit Medium-rig body; `tint` is the class accent colour (VFX/UI/weapon glow).

| class_id | 职业 | model id | file |
|---|---|---|---|
| blade_master | 剑客 Blade Master | ranger | characters/Ranger.glb |
| berserker | 狂剑士 Berserker | barbarian | characters/Barbarian.glb |
| spellblade | 魔剑士 Spellblade | avian_swordsman | characters/AvianSwordsman.glb |
| ghostblade | 鬼剑士 Ghostblade | tiefling | characters/Tiefling.glb |
| battle_mage | 战斗法师 Battle Mage | protagonist_a | characters/Protagonist_A.glb |
| elementalist | 元素法师 Elementalist | mage | characters/Mage.glb |
| witch | 魔道学者 Witch | witch | characters/Witch.glb |
| summoner | 召唤师 Summoner | druid | characters/Druid.glb |
| sharpshooter | 神枪手 Sharpshooter | marksman | characters/Marksman.glb |
| spitfire | 弹药专家 Spitfire | action_figure | characters/ActionFigure.glb |
| launcher | 枪炮师 Launcher | combat_mech | characters/CombatMech.glb |
| mechanic | 机械师 Mechanic | engineer | characters/Engineer.glb |
| striker | 拳法家 Striker | superhero | characters/Superhero.glb |
| qi_master | 气功师 Qi Master | protagonist_b | characters/Protagonist_B.glb |
| grappler | 柔道 Grappler | caveman | characters/Caveman.glb |
| brawler | 流氓 Brawler | survivalist | characters/Survivalist.glb |
| assassin | 刺客 Assassin | rogue_hooded | characters/Rogue_Hooded.glb |
| ninja | 忍者 Ninja | ninja | characters/Ninja.glb |
| thief | 盗贼 Thief | hoarder | characters/Hoarder.glb |
| warlock | 术士 Warlock | vampire | characters/Vampire.glb |
| knight | 骑士 Knight | knight | characters/Knight.glb |
| exorcist | 驱魔师 Exorcist | lorekeeper | characters/Lorekeeper.glb |
| cleric | 牧师 Cleric | cleric | characters/Cleric.glb |
| paladin | 守护天使 Paladin | paladin_helmet | characters/Paladin_with_Helmet.glb |
| unspecialized | 散人 Unspecialized | rogue | characters/Rogue.glb |

Spare Medium bodies (summons, NPCs, alternates): paladin, space_ranger, hiker, magical_girl, plant_warrior,
toy_soldier, robot_one, robot_two (Mechanic robots), werewolf_man.

Mobs (Medium rig): skeleton_minion, skeleton_warrior, skeleton_rogue, skeleton_mage, necromancer,
werewolf (Werewolf_Wolf.glb), werewolf_man, orc_raider.
Bosses (Large rig, ~3.5 m): black_knight, frost_golem, orc_brute, monstrosity, skeleton_golem, clanker,
barbarian_large. Suggested boss/mob weapons: `CharacterVisual.MOB_WEAPONS`.

---------------------------------------------------------------------------------------------------
## Animation key -> clip (CharacterVisual.ANIM_MAP)

Clips come from `anims/Rig_Medium_*.glb` (MovementBasic, MovementAdvanced, General, CombatMelee, CombatRanged,
Special, Simulation) and `anims/Rig_Large_*.glb` (MovementBasic, MovementAdvanced, General, CombatMelee).
One AnimationLibrary per rig is built at runtime; Rig_Large position tracks other than root/hips are stripped
(fixes the KayKit Large head-offset, the head otherwise sinks ~0.115 m).

| key | Medium clip | Large clip | loop/hold |
|---|---|---|---|
| idle | Idle_A (2h stance: Melee_2H_Idle, unarmed: Melee_Unarmed_Idle) | Idle_A | loop |
| run | Running_A (rifle: Running_HoldingRifle) | Running_A | loop |
| walk | Walking_A | Walking_A | loop |
| jump | Jump_Start | Dodge_Forward | |
| fall | Jump_Idle | Idle_B | loop |
| land | Jump_Land | Melee_Unarmed_Idle | |
| hit | Hit_A | Hit_A | |
| launched | Hit_B | Hit_A | hold last frame |
| knockdown | Death_A | Death_A | hold last frame |
| getup | Lie_StandUp | Dodge_Backwards | |
| stunned | Idle_B | Idle_B | loop |
| death | Death_B | Death_A | hold last frame |
| dash | Dodge_Forward | Dodge_Forward | |
| block | Melee_Blocking | Melee_Blocking | loop |
| cast | Ranged_Magic_Shoot | Melee_Unarmed_Punch | |
| cast_long | Ranged_Magic_Spellcasting_Long | Melee_Block | loop |
| channel | Ranged_Magic_Spellcasting | Melee_Blocking | loop |
| attack | Melee_1H_Attack_Chop (unarmed: Punch_A) | Melee_1H_Slash | |
| attack_1h_1 | Melee_1H_Attack_Slice_Diagonal | Melee_1H_Slash | |
| attack_1h_2 | Melee_1H_Attack_Slice_Horizontal | Melee_Dualwield_Slash | |
| attack_1h_3 | Melee_1H_Attack_Chop | Melee_1H_Stab | |
| attack_2h | Melee_2H_Attack_Chop | Melee_2H_Attack | |
| attack_spin | Melee_2H_Attack_Spin | Melee_Dualwield_SlashCombo | |
| attack_stab | Melee_1H_Attack_Stab | Melee_1H_Stab | |
| attack_slam | Melee_2H_Attack_Slice | Melee_2H_Slam | |
| attack_dual | Melee_Dualwield_Attack_Slice | Melee_Dualwield_Slash | |
| kick | Melee_Unarmed_Attack_Kick | Melee_Unarmed_Kick | |
| punch | Melee_Unarmed_Attack_Punch_A | Melee_Unarmed_Punch | |
| punch_combo | Melee_Dualwield_Attack_Stab | Melee_Dualwield_SlashCombo | |
| shoot_1h | Ranged_1H_Shoot | Melee_1H_Stab | |
| shoot_2h | Ranged_2H_Shoot | Melee_Block_Attack | |
| shoot_dual | Ranged_Magic_Shoot | Melee_Dualwield_Slash | |
| throw | Throw | Melee_1H_Slash | |
| summon | Ranged_Magic_Summon | Melee_Unarmed_Smash | |
| heal | Ranged_Magic_Raise | Idle_B | |
| taunt | Skeletons_Taunt | Melee_Unarmed_Smash | |
| grab | Melee_Block_Attack | Melee_Block_Attack | |
| leap | Jump_Full_Long | Melee_2H_Slam | |
| aerial | Melee_1H_Attack_Jump_Chop | Melee_2H_Slam | |
| victory | Cheering | Melee_Unarmed_Smash | |

---------------------------------------------------------------------------------------------------
## Weapons (WeaponFactory)

Grip convention: origin = fist, blades/shafts along +Y, firearms muzzle along +X of the returned node
(KayKit handslot aim axis), KayKit model units. KayKit meshes are used where the type matches
(greatsword, short_sword = AvianSwordsman_Sword + rune glow, tachi = Ninja_Katana, battle_lance = spear_A +
red tassel, staff = staff_A + crystal, staff_ring = druid_staff + ring, broom = Witch Broom, rifle = Gun_Rifle,
gloves = fistweapon_C, gloves_qi = fistweapon_A + qi glow, dual_swords = dagger_B, dagger, cane =
Skeleton_Staff + orb, knight_sword = sword_1handed, war_scythe = scythe + talismans, great_axe =
axe_2handed, shield = shield_badge, grenade = Action Figure Grenade). Procedural stylised meshes:
lightsaber, revolver / pistol, auto_pistol, hand_cannon, tonfa, claws, ninjato, cross, mech_box,
umbrella (千机伞: `umbrella` folded, `umbrella_open` shield form, `umbrella_gun`).

---------------------------------------------------------------------------------------------------
## Folder guide for other modules

- `env/dungeon/` - the complete KayKit Dungeon Remastered 1.1 set (floors, floor foundations, walls incl.
  doorways/arches/windows/gated, pillars, columns, stairs, scaffolds, torches (`torch_lit`, `torch_mounted`),
  banners in 6 colours, barrels, crates, boxes, chests, kegs, tables, shelves, rubble, rocks, bars/gates).
  Shared texture: `env/dungeon/dungeon_texture.png`. Pieces are 4 m grid tiles.
- `env/nature/` - forest nature Color1: Rock_1..6, Tree_1..7 + Tree_Bare, Bush_1..4, Grass_2, some hills/cliffs.
- `vfx/` - Kenney particle sprites used by `Fx` (circle, dirt, fire, flame, flare, light, magic, muzzle,
  scorch, scratch, slash, smoke, spark (= lightning crackles), star, symbol, trace, twirl, window).
- `ui/` - Kenney RPG panels (`panel_*`, `panelInset_*`), bars (`bar*_horizontal*`, `bar*_vertical*`),
  buttons (`buttonLong_*`, `buttonSquare_*`, `buttonRound_*`), arrows, check/cross icons, two cursors.
- `sfx/` - see `Fx.SFX_MAP` for the name -> file table (hit, hit_heavy, slash, swing, magic, explosion, shot,
  cannon, heal, buff, debuff, block, metal, footstep, death, ui_click, lightning, ice, glass, ultimate, dash,
  jump, land, throw, grab, summon, bell, coin, earth, fire, wood, trap, book).
