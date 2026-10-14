# Rongyao Arena - Asset Credits 素材致谢

Every third-party asset in `res://assets/` is free to redistribute and modify: most are **CC0 1.0**, six VRoid sample
bases use the **VRoid Hub licence** (redistribution and modification allowed, credit unnecessary), and the fonts are
**SIL OFL 1.1**. Attribution is given here gladly. License texts are in `licenses/` (release) / `assets/licenses/` (source).

| Pack | Author | License | Used for | Folder |
|---|---|---|---|---|
| VRoid Project CC0 sample models (11 bases, converted) | VRoid Project (pixiv Inc.), via OpenGameArt | CC0 1.0 (5 bases) / VRoid Hub licence (6 bases: redistribution + modification allowed, credit unnecessary) | all 25 player-class bodies | `characters/anime/` |
| Mesh2Motion human animation library (base + addon) | Mesh2Motion (mesh2motion.org), incl. Universal Animation Library by Quaternius | CC0 1.0 | player-class animations | `anims/anime/human-*.glb` |
| KayKit Character Animations 1.1 (Rig_Medium, Rig_Large) | Kay Lousberg (KayKit), www.kaylousberg.com | CC0 1.0 | mob/boss/summon animations; CombatMelee + CombatRanged copies retargeted as player gap-filler clips | `anims/`, `anims/anime/kaykit_*.glb` |
| KayKit Adventurers 2.0 (weapons) | Kay Lousberg (KayKit) | CC0 1.0 | mob weapons | `weapons/adv/` |
| KayKit Skeletons 1.1 (characters + weapons) | Kay Lousberg (KayKit) | CC0 1.0 | mobs, mob weapons | `characters/`, `weapons/special/` |
| KayKit Mystery Monthly Series 4 / 5 / 6 (characters + props) | Kay Lousberg (KayKit) | CC0 1.0 | bosses, summons, mob weapons | `characters/`, `weapons/special/` |
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
## Player bodies: anime pipeline (CharacterVisual "anime" rig, ClassDress)

All 25 classes are re-dressed VRoid CC0 bases (art migration, `docs/ART_MIGRATION.md`). The body, recolour maps,
procedural costume, proportions, clips and weapon grips of a class come from `visuals/class_dress.gd` (temporary
recolour) or its own `visuals/dress/<class_id>.gd` (hand-built). Recipe: `visuals/dress/README.md`.

| base key | file (assets/characters/anime/) | source VRM | VRM meta licence |
|---|---|---|---|
| sakurada | vroid_sakurada.glb | Sakurada Fumiriya.vrm (桜田 史利矢) | VRoid Hub: redistribution/modification allow, credit unnecessary |
| hairsample_male | vroid_hairsample_male.glb | HairSample_Male.vrm | CC0 |
| base_male | vroid_base_male.glb | Base_Male.vrm | CC0 |
| avatarsample_d | vroid_avatarsample_d.glb | AvatarSample_D.vrm (千駄ヶ谷 渋) | VRoid Hub (as above) |
| avatarsample_d_darkness | vroid_avatarsample_d_darkness.glb | AvatarSample_D_Darkness.vrm | CC0 |
| avatarsample_e | vroid_avatarsample_e.glb | AvatarSample_E.vrm (ビビ) | VRoid Hub (as above) |
| avatarsample_f | vroid_avatarsample_f.glb | AvatarSample_F.vrm (ヴィータ) | VRoid Hub (as above) |
| avatarsample_g | vroid_avatarsample_g.glb | AvatarSample_G.vrm (ヴィクトリア・ルービン) | VRoid Hub (as above) |
| base_female | vroid_base_female.glb | Base_Female.vrm | CC0 |
| hairsample_female | vroid_hairsample_female.glb | HairSample_Female.vrm | CC0 |
| sendagaya_shino | vroid_sendagaya_shino.glb | Sendagaya Shino.vrm (千駄ヶ谷 篠) | VRoid Hub (as above) |

All 11 are listed on OpenGameArt ("VRoid Studio CC0 models", explicitly released by VRoid under CC0) and every
embedded VRM meta allows redistribution and modification (checked before conversion). Converted with
`characters/anime/tools/vrm2glb.py` (512 px body / 1024 px face+hair textures), retargeted at import to
SkeletonProfileHumanoid through `characters/anime/retarget/vroid.tres` (BoneMaps generated by
`characters/anime/tools/make_bonemaps.gd`, import patched by `tools/patch_import.py`).
Licence notes: `licenses/VRoid-CC0-Sample-Models-License.txt`, `licenses/Mesh2Motion-CC0-License.txt`.

| class_id | 职业 | base | dress |
|---|---|---|---|
| battle_mage | 战斗法师 Battle Mage | sakurada | `dress/battle_mage.gd` (finished) |
| launcher | 枪炮师 Launcher | avatarsample_g | `dress/launcher.gd` (finished) |
| witch | 魔道学者 Witch | hairsample_male | `dress/witch.gd` (finished) |
| unspecialized | 散人 Unspecialized | hairsample_male | `dress/unspecialized.gd` (finished) |
| blade_master | 剑客 Blade Master | sakurada | `dress/blade_master.gd` (finished) |
| other 20 classes | | see `ClassDress.FALLBACK` | temporary recolour + belt |

KayKit bodies kept (toon-restyled at load): summons magical_girl, plant_warrior, toy_soldier, robot_one, robot_two;
mobs skeleton_minion, skeleton_warrior, skeleton_rogue, skeleton_mage, necromancer, werewolf (Werewolf_Wolf.glb),
werewolf_man, orc_raider; bosses (Large rig, ~3.5 m) black_knight, frost_golem, orc_brute, monstrosity,
skeleton_golem, clanker, barbarian_large. Suggested boss/mob weapons: `CharacterVisual.MOB_WEAPONS`.
The KayKit player bodies used before the migration were removed from `characters/`.

---------------------------------------------------------------------------------------------------
## Animation key -> clip

Anime rig (`CharacterVisual.ANIME_ANIM_MAP`; Mesh2Motion clips, `kk_` = KayKit clip retargeted through
`characters/anime/retarget/kaykit.tres`). Weapon stances (`ANIME_STANCE_OVERRIDES`) and dress `anims` override idle /
attack per class (e.g. Battle Mage idle = Fighting Idle, Launcher idle = Idle_FoldArms with the cannon on the shoulder).

| key | anime clip | key | anime clip |
|---|---|---|---|
| idle | Idle_A (stances: Fighting Idle / Spell_Simple_Idle / Pistol_Idle) | attack | Sword_Regular_A (fist: Punch_Jab, caster: Spell_Simple_Shoot) |
| run | Run_Anime | attack_1h_1 / _2 / _3 | Sword_Regular_A / B / C |
| walk | Walk | attack_2h | Sword_Regular_C |
| jump / fall / land | Jump_Start / Jump_air / Jump_Land | attack_spin | kk_Melee_2H_Attack_Spin |
| hit / launched | Hit_Chest / Hit_Knockback | attack_stab | Sword_Regular_A |
| knockdown / getup | Death_B / LayToIdle | attack_slam | Attack_Ground_Pound |
| stunned | Dizzy | attack_dual | kk_Melee_Dualwield_Attack_Slice |
| death | Death_A | kick | kk_Melee_Unarmed_Attack_Kick |
| dash | Sword_Dash_RM (root motion stripped) | punch / punch_combo | Punch_Jab / Punch_Cross |
| block | Sword_Block | shoot_1h / shoot_dual | Pistol_Shoot |
| cast | Spell_Simple_Shoot | shoot_2h | kk_Ranged_2H_Shoot |
| cast_long | kk_Ranged_Magic_Spellcasting_Long | throw | OverhandThrow |
| channel | Spell_Simple_Idle | summon / heal | kk_Ranged_Magic_Summon / kk_Ranged_Magic_Raise |
| taunt | Angry | grab | Melee_Hook |
| leap | NinjaJump_Start | aerial | kk_Melee_1H_Attack_Jump_Chop |
| victory | Victory | | |

KayKit rigs (mobs, bosses, summons) keep `CharacterVisual.ANIM_MAP` on the Rig_Medium / Rig_Large libraries
(`anims/Rig_*.glb`, one library per rig built at runtime; Rig_Large position tracks other than root/hips are
stripped, fixing the KayKit Large head offset). Main clips: idle Idle_A, run Running_A, walk Walking_A, hit Hit_A,
launched Hit_B, death Death_B, cast Ranged_Magic_Shoot, attack Melee_1H_Attack_Chop, attack_2h Melee_2H_Attack_Chop,
attack_spin Melee_2H_Attack_Spin, shoot_1h Ranged_1H_Shoot, summon Ranged_Magic_Summon, taunt Skeletons_Taunt,
victory Cheering (full table in the ANIM_MAP constant).

---------------------------------------------------------------------------------------------------
## Weapons (WeaponFactory)

Every player weapon id of ARCHITECTURE §7.2 (+ `umbrella_open`, `umbrella_gun`, `gloves_left`, `sword`, `pistol`) is
an original procedural model in `visuals/weapon_factory.gd` (toon + outline materials, HDR accents; no third-party
mesh): 却邪-style lance, 冰雨-style light sword, star broom, brass hand cannon, 千机伞-style umbrella in 3 forms, etc.
Grip convention: origin = fist, blades/shafts along +Y, firearms muzzle along +X, metres. Mob/boss weapons
(`skeleton_*`, `orc_*`, `black_knight_*`, ...) stay KayKit meshes restyled with the toon shader.

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

---------------------------------------------------------------------------------------------------
## Fonts 字体 (SIL Open Font License 1.1)

Each font ships unmodified with its `OFL.txt` beside it (copies in `licenses/OFL-<font>.txt`).

| Font | Author | License | Used for | Folder |
|---|---|---|---|---|
| Noto Sans SC (variable) | Copyright 2014-2021 Adobe, RFN "Source" (Google Fonts) | SIL OFL 1.1 | UI body text, CN/EN | `fonts/notosanssc/` |
| Ma Shan Zheng | Copyright 2018 The Ma Shan Zheng Project Authors | SIL OFL 1.1 | brush calligraphy: skill call-outs, titles | `fonts/mashanzheng/` |
| Teko (variable) | Copyright 2023 The Teko Project Authors | SIL OFL 1.1 | HUD numerals, timers, cooldowns | `fonts/teko/` |
| Russo One | Copyright 2011-2012 Jovanny Lemonad, RFN "Russo" | SIL OFL 1.1 | combo counter, scores, crits | `fonts/russoone/` |
| Orbitron (variable) | Copyright 2018 The Orbitron Project Authors, RFN "Orbitron" | SIL OFL 1.1 | broadcast captions | `fonts/orbitron/` |

---------------------------------------------------------------------------------------------------
## Environments 场景 (ENV track: painted maps and dungeons)

All six playable maps (`maps/arena_*.gd`, `pve/dungeon_frost_forest.gd`, `pve/dungeon_boneyard.gd`) are now built
procedurally by `maps/env_kit.gd` + `maps/env_props.gd` with the painted shaders in `visuals/shaders/`
(`painted_env*`, `arena_floor`, `anime_sky`, `painted_backdrop`). No third-party environment meshes are used by
them any more; the KayKit Dungeon / Forest Nature files above stay in `env/` only as legacy assets.

| File | Source | License |
|---|---|---|
| `env/painted/leaves_blossom.png`, `leaves_green.png`, `leaves_gold.png`, `leaves_violet.png` | Original art drawn in code by `env/painted/paint_env_textures.py` (Rongyao Arena project) | repository licence (original work, no attribution needed) |
| `env/painted/maple_leaves.png`, `banner_blue.png`, `banner_red.png`, `fire_tongue.png` | Copies of the look-dev textures, original art drawn in code by `lookdev/tools/paint_textures.py` (see `lookdev/assets/LICENSES.md`) | repository licence (original work) |
| `visuals/shaders/painted_env*.gdshader`, `arena_floor`, `anime_sky`, `painted_backdrop` | Original code (ported from `lookdev/shaders/`) | repository licence |

No official 全职高手 / Glory art, logo or screenshot is used; the team crest on the banners is an original design.

---------------------------------------------------------------------------------------------------
## Icons 图标 (ICONS track: skill, status and class-emblem icons)

| File | Source | License |
|---|---|---|
| `icons/skills/*.png`, `icons/status/*.png`, `icons/class/*.png` (+ `@2x`) | Original art drawn in code by `tools/icons/` (Rongyao Arena project; port of `lookdev/tools/icon_painter.py`). Python + numpy + Pillow only; no stock silhouettes (game-icons.net or other), no brushes, fonts or reference images are embedded | repository licence (original work, no attribution needed) |

No official 全职高手 / Glory icon, emblem or crest is copied or traced; the class crests, weapons, 千机伞, 冰雨, the
launcher cannon and 灭绝星尘 broom are our own drawings from the bible's written descriptions.
