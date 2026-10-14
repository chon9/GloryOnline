# Rongyao Arena - Asset Credits 素材致谢

Every third-party asset in `res://assets/` is free to redistribute and modify: most are **CC0 1.0**, six VRoid sample
bases use the **VRoid Hub licence** (redistribution and modification allowed, credit unnecessary), the fonts are
**SIL OFL 1.1**, and some sounds and music are **CC BY 3.0 / 4.0** (attribution required; the exact credit lines are
in the audio sections below). Attribution is given here gladly. License texts are in `licenses/` (release) / `assets/licenses/` (source).

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
| Sound effects: 375 files from Kenney, JC Sounds, Little Robot Sound Factory, rubberduck, Free Firearm Sound Library and 30 more packs | see **Sound effects 音效** below | CC0 1.0 / CC BY 3.0 / CC BY 4.0 | SFX | `sfx/<category>/` |

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
- `sfx/` - categorized SFX library (`blade/ metal/ blunt/ body/ movement/ gun/ explosion/ magic_*/ energy/ boss/ ui/
  voice/ crowd/`); `Fx.SFX_MAP` maps sound names to files. Sources and licences: **Sound effects 音效** below.

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

---------------------------------------------------------------------------------------------------
## Sound effects 音效 (SFX track: `autoload/fx.gd` `SFX_MAP`, `assets/sfx/<category>/`)

375 files. Every file was processed the same way: decoded, sliced / trimmed where noted, faded, mono for 3D
sounds (UI, announcer and crowd stay stereo), a few layered with a second CC0 sound (noted below), then normalized
per sound set: every variant of a set sits at the same loudest-50 ms level (sets ordered light < heavy, e.g.
pistol < revolver < rifle < cannon; between about -26 and -8 dBFS), transients held by a look-ahead limiter at
-1.5 dBFS, encoded as OGG Vorbis q5, 44.1 kHz, and the decoded peak checked to stay <= -1 dBFS.
The old placeholder sounds (`sfx/synth_*.wav`, generated) and the unused Kenney files were removed.
Licence texts: `licenses/CC-BY-3.0-legalcode.txt`, `licenses/CC-BY-4.0-legalcode.txt`, `licenses/CC0-1.0-legalcode.txt`,
`licenses/Kenney-*-License.txt`, `licenses/Michel-Baradari-Explosions-Notice.txt`.

### Attribution required (CC BY)

| Pack | Author | License | Attribution | Files |
|---|---|---|---|---|
| [Fantasy SFX Pack Vol 1](https://opengameart.org/content/jc-sounds-fantasy-sfx-pack-vol-1) | JC Sounds | CC BY 4.0 | "Fantasy SFX Pack Vol 1" by JC Sounds, https://opengameart.org/content/jc-sounds-fantasy-sfx-pack-vol-1, licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Credit: JC Sounds. Files were trimmed, resampled, volume-normalized and converted to OGG. | 47 |
| [Fantasy Sound Effects Library](https://opengameart.org/content/fantasy-sound-effects-library) | Little Robot Sound Factory | CC BY 3.0 | "Fantasy Sound Effects Library" by Little Robot Sound Factory (www.littlerobotsoundfactory.com), https://opengameart.org/content/fantasy-sound-effects-library, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Modified (trimmed, volume-normalized, converted to OGG). | 7 |
| [2 High Quality Explosions](https://opengameart.org/content/2-high-quality-explosions) | Michel Baradari (apollo-music.de); uploaded to OGA by qubodup | CC BY 3.0 | "2 High Quality Explosions" - sounds (c) by Michel Baradari (apollo-music.de), https://opengameart.org/content/2-high-quality-explosions, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Modified (mono, trimmed, volume-normalized, converted to OGG). | 2 |
| [Magic SFX Sample](https://opengameart.org/content/magic-sfx-sample) | ViRiX Dreamcore (David McKee) | CC BY 3.0 | Some of the sounds in this project were created by ViRiX Dreamcore (David McKee) www.soundcloud.com/virix - "Magic SFX Sample", https://opengameart.org/content/magic-sfx-sample, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Modified (mono, trimmed, volume-normalized, converted to OGG). | 5 |
| [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) | Gregor Quendel | CC BY 4.0 | "Free Crowd Cheering Sounds" by Gregor Quendel (www.gregorquendel.com), https://opengameart.org/content/free-crowd-cheering-sounds, licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Modified (4 s excerpts, faded, volume-normalized, converted to OGG). | 3 |
| [Thunder](https://opengameart.org/content/thunder) | Jerimee | CC BY 3.0 | "Thunder" by Jerimee, https://opengameart.org/content/thunder, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Modified (3.2 s excerpt, mono, volume-normalized, converted to OGG). | 1 |
| [Thunder, Very Close, Rain, 01](https://opengameart.org/content/thunder-very-close-rain-01) | InspectorJ (www.jshaw.co.uk) | CC BY 3.0 | "Thunder, Very Close, Rain, 01.wav" by InspectorJ (www.jshaw.co.uk), https://opengameart.org/content/thunder-very-close-rain-01, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Modified (3 s excerpt, mono, volume-normalized, converted to OGG). | 1 |
| [Footsteps on different surfaces](https://opengameart.org/content/footsteps-on-different-surfaces) | congusbongus (gravel derived from Ali_6868, bones from blukotek) | CC BY 3.0 | "Footsteps on different surfaces" by congusbongus, https://opengameart.org/content/footsteps-on-different-surfaces, licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/); gravel derived from Ali_6868 (CC0), bones from blukotek (CC0). Modified (trimmed, normalized, converted to OGG). | 10 |

### Public domain (CC0 1.0; credit given gladly, not required)

| Pack | Author | License | Source | Files |
|---|---|---|---|---|
| Impact Sounds | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds | 52 |
| RPG Audio | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio | 11 |
| Sci-fi Sounds | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/sci-fi-sounds | 20 |
| Interface Sounds | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/interface-sounds | 16 |
| UI Audio | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/ui-audio | 6 |
| Voiceover Pack: Fighter | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/voiceover-pack-fighter | 21 |
| Swishes Sound Pack | artisticdude | CC0 1.0 | https://opengameart.org/content/swishes-sound-pack | 6 |
| RPG Sound Pack | artisticdude | CC0 1.0 | https://opengameart.org/content/rpg-sound-pack | 21 |
| Battle Sound Effects | artisticdude (submitted by Ogrebane) | CC0 1.0 (multi-licensed; used under CC0) | https://opengameart.org/content/battle-sound-effects | 3 |
| 20 Sword Sound Effects (attacks) | StarNinjas | CC0 1.0 | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes | 3 |
| 20 Sword Sound Effects (clashes) | StarNinjas | CC0 1.0 | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes | 2 |
| Medieval sound effects - Weapon impacts (1 of 2) | Ben Jaszczak & Brian Nelson (Still North Media) | CC0 1.0 | https://opengameart.org/content/medieval-sound-effects-weapon-impacts | 10 |
| Medieval sound effects - Weapon impacts (2 of 2) | Ben Jaszczak & Brian Nelson (Still North Media) | CC0 1.0 | https://opengameart.org/content/medieval-sound-effects-weapon-impacts | 2 |
| The Free Firearm Sound Library (Prepared SFX Library) | Free Firearm Sound Library team (Ben Jaszczak et al.) | CC0 1.0 | https://opengameart.org/content/the-free-firearm-sound-library | 25 |
| 25 CC0 bang / firework SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/25-cc0-bang-firework-sfx | 10 |
| 80 CC0 RPG SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-rpg-sfx | 16 |
| 80 CC0 creature SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-creature-sfx | 5 |
| 75 CC0 breaking / falling / hit sfx | rubberduck | CC0 1.0 | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | 18 |
| 40 CC0 water / splash / slime SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx | 7 |
| 100 CC0 SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/100-cc0-sfx | 7 |
| Soundpack 03 | crazyduckgames | CC0 1.0 | https://opengameart.org/content/soundpack-03 | 3 |
| Magic Spell SFX | JaggedStone | CC0 1.0 | https://opengameart.org/content/magic-spell-sfx | 5 |
| Spell sounds | Augmentality (Brandon Morris), submitted by HaelDB | CC0 1.0 (dual OGA-BY 3.0 / CC0; used under CC0) | https://opengameart.org/content/spell-sounds | 6 |
| Monster Sound Effects Pack | Ogrebane | CC0 1.0 | https://opengameart.org/content/monster-sound-effects-pack | 4 |
| Monster or beast sounds | pauliuw | CC0 1.0 | https://opengameart.org/content/monster-or-beast-sounds | 6 |
| Monster snarls | Darsycho | CC0 1.0 | https://opengameart.org/content/monster-snarls | 3 |
| 42 Snow and Gravel Footsteps | Corsica_S (extracted by Iwan Gabovitch / qubodup) | CC0 1.0 | https://opengameart.org/content/42-snow-and-gravel-footsteps | 3 |
| Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi | CC0 1.0 | https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | 6 |
| wind whoosh loop | SketchMan3 (from JaggedStone's CC0 dungeon ambience) | CC0 1.0 | https://opengameart.org/content/wind-whoosh-loop | 2 |

### SFX file index (every file -> pack and original file)

| File (`assets/sfx/`) | Pack | Original file | Terms |
|---|---|---|---|
| `blade/swing_blade_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Swing_01.wav | CC BY 4.0 |
| `blade/swing_blade_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Swing_02.wav | CC BY 4.0 |
| `blade/swing_blade_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Swing_03.wav | CC BY 4.0 |
| `blade/swing_dagger_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Swing_01.wav | CC BY 4.0 |
| `blade/swing_dagger_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Swing_02.wav | CC BY 4.0 |
| `blade/swing_dagger_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Swing_03.wav | CC BY 4.0 |
| `blade/swing_heavy_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Heavy Sword_Swing_01.wav | CC BY 4.0 |
| `blade/swing_heavy_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Heavy Sword_Swing_02.wav | CC BY 4.0 |
| `blade/swing_heavy_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Heavy Sword_Swing_03.wav | CC BY 4.0 |
| `energy/buff_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Magic Shield_Activation_01.wav | CC BY 4.0 |
| `energy/buff_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Magic Shield_Activation_02.wav | CC BY 4.0 |
| `energy/teleport_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Teleport_In.wav | CC BY 4.0 |
| `energy/teleport_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Teleport_Out.wav | CC BY 4.0 |
| `magic_dark/chant_01.ogg` | Fantasy SFX Pack Vol 1 | Loop_Fantasy Pack Vol 1_Dark Necromancy Chant_01.wav | CC BY 4.0 |
| `magic_dark/curse_01.ogg` | Fantasy SFX Pack Vol 1 | Seq_Fantasy SFX Pack Vol 1_Mana Drain_Start.wav | CC BY 4.0 |
| `magic_dark/curse_02.ogg` | Fantasy SFX Pack Vol 1 | Seq_Fantasy SFX Pack Vol 1_Mana Drain_End.wav | CC BY 4.0 |
| `magic_fire/fire_cast_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Launch_01.wav | CC BY 4.0 |
| `magic_fire/fire_cast_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Launch_02.wav | CC BY 4.0 |
| `magic_fire/fire_cast_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Launch_03.wav | CC BY 4.0 |
| `magic_fire/fire_charge_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball_Buildup.wav | CC BY 4.0 |
| `magic_fire/fire_hit_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Impact_01.wav | CC BY 4.0 |
| `magic_fire/fire_hit_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Impact_02.wav | CC BY 4.0 |
| `magic_fire/fire_hit_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Fireball Impact_03.wav | CC BY 4.0 |
| `magic_holy/chime_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Healing Chime_01.wav | CC BY 4.0 |
| `magic_holy/chime_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Healing Chime_02.wav | CC BY 4.0 |
| `magic_ice/ice_cast_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard Projectile_Launch_01.wav | CC BY 4.0 |
| `magic_ice/ice_cast_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard Projectile_Launch_02.wav | CC BY 4.0 |
| `magic_ice/ice_cast_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard Projectile_Launch_03.wav | CC BY 4.0 |
| `magic_ice/ice_charge_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Spell_Buildup.wav | CC BY 4.0 |
| `magic_ice/ice_hit_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard  Projectile_Impact_01.wav | CC BY 4.0 |
| `magic_ice/ice_hit_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard  Projectile_Impact_02.wav | CC BY 4.0 |
| `magic_ice/ice_hit_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Ice Shard  Projectile_Impact_03.wav | CC BY 4.0 |
| `magic_lightning/zap_cast_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Launch_01.wav | CC BY 4.0 |
| `magic_lightning/zap_cast_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Launch_02.wav | CC BY 4.0 |
| `magic_lightning/zap_cast_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Launch_03.wav | CC BY 4.0 |
| `magic_lightning/zap_charge_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Buildup.wav | CC BY 4.0 |
| `magic_lightning/zap_hit_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Hit_01.wav | CC BY 4.0 |
| `magic_lightning/zap_hit_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Hit_02.wav | CC BY 4.0 |
| `magic_lightning/zap_hit_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Electric Spell_Hit_03.wav | CC BY 4.0 |
| `metal/block_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Hit_Metal_01.wav | CC BY 4.0 |
| `metal/block_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Hit_Metal_02.wav | CC BY 4.0 |
| `metal/block_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Sword_Hit_Metal_03.wav | CC BY 4.0 |
| `metal/block_04.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Heavy Sword_Hit_Metal_01.wav | CC BY 4.0 |
| `metal/block_05.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Heavy Sword_Hit_Metal_02.wav | CC BY 4.0 |
| `metal/metal_light_01.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Hit_Metal_01.wav | CC BY 4.0 |
| `metal/metal_light_02.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Hit_Metal_02.wav | CC BY 4.0 |
| `metal/metal_light_03.ogg` | Fantasy SFX Pack Vol 1 | Single_Fantasy SFX Pack Vol 1_Dagger_Hit_Metal_03.wav | CC BY 4.0 |
| `boss/roar_01.ogg` | Fantasy Sound Effects Library | Dragon_Growl_00.wav | CC BY 3.0 |
| `boss/roar_02.ogg` | Fantasy Sound Effects Library | Dragon_Growl_01.wav | CC BY 3.0 |
| `energy/spell_01.ogg` | Fantasy Sound Effects Library | Spell_00.wav | CC BY 3.0 |
| `energy/spell_02.ogg` | Fantasy Sound Effects Library | Spell_01.wav | CC BY 3.0 |
| `energy/spell_03.ogg` | Fantasy Sound Effects Library | Spell_04.wav | CC BY 3.0 |
| `energy/summon_01.ogg` | Fantasy Sound Effects Library | Spell_02.wav | CC BY 3.0 |
| `energy/summon_02.ogg` | Fantasy Sound Effects Library | Spell_03.wav | CC BY 3.0 |
| `explosion/large_01.ogg` | 2 High Quality Explosions | explode.wav | CC BY 3.0 |
| `explosion/large_02.ogg` | 2 High Quality Explosions | explodemini.wav | CC BY 3.0 |
| `energy/shimmer_01.ogg` | Magic SFX Sample | Misc 02.wav | CC BY 3.0 |
| `magic_fire/fire_big_01.ogg` | Magic SFX Sample | Fire impact 1.wav | CC BY 3.0 |
| `magic_holy/heal_full_01.ogg` | Magic SFX Sample | Healing Full.wav | CC BY 3.0 |
| `magic_ice/ice_big_01.ogg` | Magic SFX Sample | Ice attack 2.wav | CC BY 3.0 |
| `magic_wind/wind_01.ogg` | Magic SFX Sample | Wind effects 5.wav | CC BY 3.0 |
| `crowd/cheer_01.ogg` | Free Crowd Cheering Sounds | Gregor_Quendel_-_Crowd_Cheering_Sounds_-_04_-_Strong_cheering_-_II_-_Short.mp3 | CC BY 4.0 |
| `crowd/cheer_02.ogg` | Free Crowd Cheering Sounds | Gregor_Quendel_-_Crowd_Cheering_Sounds_-_03_-_Strong_cheering_-_I.mp3 | CC BY 4.0 |
| `crowd/cheer_03.ogg` | Free Crowd Cheering Sounds | Gregor_Quendel_-_Crowd_Cheering_Sounds_-_05_-_Soft_cheering_-_I.mp3 | CC BY 4.0 |
| `magic_lightning/thunder_01.ogg` | Thunder | thunderclap.wav | CC BY 3.0 |
| `magic_lightning/thunder_02.ogg` | Thunder, Very Close, Rain, 01 | thunder_very_close_rain_01.wav | CC BY 3.0 |
| `blunt/kick_01.ogg` | Impact Sounds | impactSoft_heavy_000.ogg | CC0 1.0 |
| `blunt/kick_02.ogg` | Impact Sounds | impactSoft_heavy_001.ogg | CC0 1.0 |
| `blunt/kick_03.ogg` | Impact Sounds | impactSoft_heavy_002.ogg | CC0 1.0 |
| `blunt/punch_heavy_01.ogg` | Impact Sounds | impactPunch_heavy_000.ogg | CC0 1.0 |
| `blunt/punch_heavy_02.ogg` | Impact Sounds | impactPunch_heavy_001.ogg | CC0 1.0 |
| `blunt/punch_heavy_03.ogg` | Impact Sounds | impactPunch_heavy_002.ogg | CC0 1.0 |
| `blunt/punch_heavy_04.ogg` | Impact Sounds | impactPunch_heavy_003.ogg | CC0 1.0 |
| `blunt/punch_heavy_05.ogg` | Impact Sounds | impactPunch_heavy_004.ogg | CC0 1.0 |
| `blunt/punch_light_01.ogg` | Impact Sounds | impactPunch_medium_000.ogg | CC0 1.0 |
| `blunt/punch_light_02.ogg` | Impact Sounds | impactPunch_medium_001.ogg | CC0 1.0 |
| `blunt/punch_light_03.ogg` | Impact Sounds | impactPunch_medium_002.ogg | CC0 1.0 |
| `blunt/punch_light_04.ogg` | Impact Sounds | impactPunch_medium_003.ogg | CC0 1.0 |
| `blunt/punch_light_05.ogg` | Impact Sounds | impactPunch_medium_004.ogg | CC0 1.0 |
| `blunt/wood_01.ogg` | Impact Sounds | impactWood_heavy_000.ogg | CC0 1.0 |
| `blunt/wood_02.ogg` | Impact Sounds | impactWood_heavy_001.ogg | CC0 1.0 |
| `blunt/wood_03.ogg` | Impact Sounds | impactWood_heavy_002.ogg | CC0 1.0 |
| `body/fall_01.ogg` | Impact Sounds | impactSoft_heavy_003.ogg | CC0 1.0 |
| `body/fall_02.ogg` | Impact Sounds | impactSoft_heavy_004.ogg | CC0 1.0 |
| `body/land_01.ogg` | Impact Sounds | impactSoft_medium_000.ogg | CC0 1.0 |
| `body/land_02.ogg` | Impact Sounds | impactSoft_medium_001.ogg | CC0 1.0 |
| `body/land_03.ogg` | Impact Sounds | impactSoft_medium_002.ogg | CC0 1.0 |
| `body/land_04.ogg` | Impact Sounds | impactSoft_medium_003.ogg | CC0 1.0 |
| `magic_earth/mining_01.ogg` | Impact Sounds | impactMining_000.ogg | CC0 1.0 |
| `magic_earth/mining_02.ogg` | Impact Sounds | impactMining_001.ogg | CC0 1.0 |
| `magic_earth/mining_03.ogg` | Impact Sounds | impactMining_002.ogg | CC0 1.0 |
| `magic_holy/bell_01.ogg` | Impact Sounds | impactBell_heavy_000.ogg | CC0 1.0 |
| `magic_holy/bell_02.ogg` | Impact Sounds | impactBell_heavy_001.ogg | CC0 1.0 |
| `magic_holy/bell_03.ogg` | Impact Sounds | impactBell_heavy_002.ogg | CC0 1.0 |
| `magic_ice/freeze_01.ogg` | Impact Sounds | impactGlass_light_000.ogg | CC0 1.0 |
| `magic_ice/freeze_02.ogg` | Impact Sounds | impactGlass_light_001.ogg | CC0 1.0 |
| `magic_ice/freeze_03.ogg` | Impact Sounds | impactGlass_light_002.ogg | CC0 1.0 |
| `metal/metal_heavy_01.ogg` | Impact Sounds | impactMetal_heavy_000.ogg | CC0 1.0 |
| `metal/metal_heavy_02.ogg` | Impact Sounds | impactMetal_heavy_001.ogg | CC0 1.0 |
| `metal/metal_heavy_03.ogg` | Impact Sounds | impactMetal_heavy_002.ogg | CC0 1.0 |
| `metal/metal_heavy_04.ogg` | Impact Sounds | impactMetal_heavy_003.ogg | CC0 1.0 |
| `metal/shield_01.ogg` | Impact Sounds | impactPlate_heavy_000.ogg | CC0 1.0 |
| `metal/shield_02.ogg` | Impact Sounds | impactPlate_heavy_001.ogg | CC0 1.0 |
| `metal/shield_03.ogg` | Impact Sounds | impactPlate_heavy_002.ogg | CC0 1.0 |
| `metal/shield_04.ogg` | Impact Sounds | impactPlate_heavy_003.ogg | CC0 1.0 |
| `metal/shield_05.ogg` | Impact Sounds | impactPlate_heavy_004.ogg | CC0 1.0 |
| `movement/step_grass_01.ogg` | Impact Sounds | footstep_grass_000.ogg | CC0 1.0 |
| `movement/step_grass_02.ogg` | Impact Sounds | footstep_grass_001.ogg | CC0 1.0 |
| `movement/step_grass_03.ogg` | Impact Sounds | footstep_grass_002.ogg | CC0 1.0 |
| `movement/step_grass_04.ogg` | Impact Sounds | footstep_grass_003.ogg | CC0 1.0 |
| `movement/step_grass_05.ogg` | Impact Sounds | footstep_grass_004.ogg | CC0 1.0 |
| `movement/step_snow_01.ogg` | Impact Sounds | footstep_snow_000.ogg | CC0 1.0 |
| `movement/step_snow_02.ogg` | Impact Sounds | footstep_snow_001.ogg | CC0 1.0 |
| `movement/step_snow_03.ogg` | Impact Sounds | footstep_snow_002.ogg | CC0 1.0 |
| `movement/step_stone_07.ogg` | Impact Sounds | footstep_concrete_000.ogg | CC0 1.0 |
| `movement/step_stone_08.ogg` | Impact Sounds | footstep_concrete_001.ogg | CC0 1.0 |
| `movement/step_stone_09.ogg` | Impact Sounds | footstep_concrete_002.ogg | CC0 1.0 |
| `movement/step_stone_10.ogg` | Impact Sounds | footstep_concrete_003.ogg | CC0 1.0 |
| `blade/slash_hit_01.ogg` | RPG Audio | knifeSlice.ogg | CC0 1.0 |
| `blade/slash_hit_02.ogg` | RPG Audio | knifeSlice2.ogg | CC0 1.0 |
| `body/cloth_01.ogg` | RPG Audio | cloth1.ogg | CC0 1.0 |
| `body/cloth_02.ogg` | RPG Audio | cloth2.ogg | CC0 1.0 |
| `body/cloth_03.ogg` | RPG Audio | cloth3.ogg | CC0 1.0 |
| `body/cloth_04.ogg` | RPG Audio | cloth4.ogg | CC0 1.0 |
| `body/grab_02.ogg` | RPG Audio | dropLeather.ogg | CC0 1.0 |
| `body/grab_03.ogg` | RPG Audio | handleSmallLeather.ogg | CC0 1.0 |
| `body/grab_04.ogg` | RPG Audio | clothBelt.ogg | CC0 1.0 |
| `gun/click_01.ogg` | RPG Audio | metalClick.ogg | CC0 1.0 |
| `gun/click_02.ogg` | RPG Audio | metalLatch.ogg | CC0 1.0 |
| `blunt/thump_01.ogg` | Sci-fi Sounds | lowFrequency_explosion_000.ogg | CC0 1.0 |
| `blunt/thump_02.ogg` | Sci-fi Sounds | lowFrequency_explosion_001.ogg | CC0 1.0 |
| `energy/shield_01.ogg` | Sci-fi Sounds | forceField_000.ogg | CC0 1.0 |
| `energy/shield_02.ogg` | Sci-fi Sounds | forceField_001.ogg | CC0 1.0 |
| `energy/shield_03.ogg` | Sci-fi Sounds | forceField_002.ogg | CC0 1.0 |
| `energy/telegraph_01.ogg` | Sci-fi Sounds | forceField_003.ogg | CC0 1.0 |
| `energy/telegraph_02.ogg` | Sci-fi Sounds | forceField_004.ogg | CC0 1.0 |
| `explosion/crunch_01.ogg` | Sci-fi Sounds | explosionCrunch_000.ogg | CC0 1.0 |
| `explosion/crunch_02.ogg` | Sci-fi Sounds | explosionCrunch_001.ogg | CC0 1.0 |
| `explosion/crunch_03.ogg` | Sci-fi Sounds | explosionCrunch_002.ogg | CC0 1.0 |
| `gun/laser_01.ogg` | Sci-fi Sounds | laserLarge_000.ogg | CC0 1.0 |
| `gun/laser_02.ogg` | Sci-fi Sounds | laserLarge_001.ogg | CC0 1.0 |
| `gun/laser_03.ogg` | Sci-fi Sounds | laserLarge_002.ogg | CC0 1.0 |
| `gun/laser_04.ogg` | Sci-fi Sounds | laserLarge_003.ogg | CC0 1.0 |
| `gun/laser_small_01.ogg` | Sci-fi Sounds | laserSmall_000.ogg | CC0 1.0 |
| `gun/laser_small_02.ogg` | Sci-fi Sounds | laserSmall_001.ogg | CC0 1.0 |
| `gun/laser_small_03.ogg` | Sci-fi Sounds | laserSmall_002.ogg | CC0 1.0 |
| `gun/missile_01.ogg` | Sci-fi Sounds | thrusterFire_000.ogg | CC0 1.0 |
| `gun/missile_02.ogg` | Sci-fi Sounds | thrusterFire_001.ogg | CC0 1.0 |
| `gun/missile_03.ogg` | Sci-fi Sounds | thrusterFire_002.ogg | CC0 1.0 |
| `ui/back_01.ogg` | Interface Sounds | back_001.ogg | CC0 1.0 |
| `ui/back_02.ogg` | Interface Sounds | back_002.ogg | CC0 1.0 |
| `ui/click_01.ogg` | Interface Sounds | click_001.ogg | CC0 1.0 |
| `ui/close_01.ogg` | Interface Sounds | close_001.ogg | CC0 1.0 |
| `ui/confirm_01.ogg` | Interface Sounds | confirmation_001.ogg | CC0 1.0 |
| `ui/confirm_02.ogg` | Interface Sounds | confirmation_002.ogg | CC0 1.0 |
| `ui/error_01.ogg` | Interface Sounds | error_001.ogg | CC0 1.0 |
| `ui/error_02.ogg` | Interface Sounds | error_002.ogg | CC0 1.0 |
| `ui/kill_02.ogg` | Interface Sounds | confirmation_004.ogg | CC0 1.0 |
| `ui/open_01.ogg` | Interface Sounds | open_001.ogg | CC0 1.0 |
| `ui/select_01.ogg` | Interface Sounds | select_001.ogg | CC0 1.0 |
| `ui/select_02.ogg` | Interface Sounds | select_002.ogg | CC0 1.0 |
| `ui/tick_01.ogg` | Interface Sounds | tick_001.ogg | CC0 1.0 |
| `ui/tick_02.ogg` | Interface Sounds | tick_002.ogg | CC0 1.0 |
| `ui/toggle_01.ogg` | Interface Sounds | toggle_001.ogg | CC0 1.0 |
| `ui/toggle_02.ogg` | Interface Sounds | toggle_002.ogg | CC0 1.0 |
| `ui/click_02.ogg` | UI Audio | click1.ogg | CC0 1.0 |
| `ui/click_03.ogg` | UI Audio | click2.ogg | CC0 1.0 |
| `ui/click_04.ogg` | UI Audio | click3.ogg | CC0 1.0 |
| `ui/hover_01.ogg` | UI Audio | rollover1.ogg | CC0 1.0 |
| `ui/hover_02.ogg` | UI Audio | rollover2.ogg | CC0 1.0 |
| `ui/hover_03.ogg` | UI Audio | rollover3.ogg | CC0 1.0 |
| `voice/vo_1.ogg` | Voiceover Pack: Fighter | 1.ogg | CC0 1.0 |
| `voice/vo_2.ogg` | Voiceover Pack: Fighter | 2.ogg | CC0 1.0 |
| `voice/vo_3.ogg` | Voiceover Pack: Fighter | 3.ogg | CC0 1.0 |
| `voice/vo_begin.ogg` | Voiceover Pack: Fighter | begin.ogg | CC0 1.0 |
| `voice/vo_combo.ogg` | Voiceover Pack: Fighter | combo.ogg | CC0 1.0 |
| `voice/vo_fight.ogg` | Voiceover Pack: Fighter | fight.ogg | CC0 1.0 |
| `voice/vo_final_round.ogg` | Voiceover Pack: Fighter | final_round.ogg | CC0 1.0 |
| `voice/vo_flawless_victory.ogg` | Voiceover Pack: Fighter | flawless_victory.ogg | CC0 1.0 |
| `voice/vo_game_over.ogg` | Voiceover Pack: Fighter | game_over.ogg | CC0 1.0 |
| `voice/vo_it_s_a_tie.ogg` | Voiceover Pack: Fighter | it_s_a_tie.ogg | CC0 1.0 |
| `voice/vo_multi_kill.ogg` | Voiceover Pack: Fighter | multi_kill.ogg | CC0 1.0 |
| `voice/vo_prepare_yourself.ogg` | Voiceover Pack: Fighter | prepare_yourself.ogg | CC0 1.0 |
| `voice/vo_ready.ogg` | Voiceover Pack: Fighter | ready.ogg | CC0 1.0 |
| `voice/vo_round_1.ogg` | Voiceover Pack: Fighter | round_1.ogg | CC0 1.0 |
| `voice/vo_round_2.ogg` | Voiceover Pack: Fighter | round_2.ogg | CC0 1.0 |
| `voice/vo_round_3.ogg` | Voiceover Pack: Fighter | round_3.ogg | CC0 1.0 |
| `voice/vo_sudden_death.ogg` | Voiceover Pack: Fighter | sudden_death.ogg | CC0 1.0 |
| `voice/vo_time.ogg` | Voiceover Pack: Fighter | time.ogg | CC0 1.0 |
| `voice/vo_winner.ogg` | Voiceover Pack: Fighter | winner.ogg | CC0 1.0 |
| `voice/vo_you_lose.ogg` | Voiceover Pack: Fighter | you_lose.ogg | CC0 1.0 |
| `voice/vo_you_win.ogg` | Voiceover Pack: Fighter | you_win.ogg | CC0 1.0 |
| `blade/swing_light_01.ogg` | Swishes Sound Pack | swish-1.wav | CC0 1.0 |
| `blade/swing_light_02.ogg` | Swishes Sound Pack | swish-3.wav | CC0 1.0 |
| `blade/swing_light_03.ogg` | Swishes Sound Pack | swish-5.wav | CC0 1.0 |
| `blade/swing_light_04.ogg` | Swishes Sound Pack | swish-7.wav | CC0 1.0 |
| `blade/swing_light_05.ogg` | Swishes Sound Pack | swish-9.wav | CC0 1.0 |
| `blade/swing_light_06.ogg` | Swishes Sound Pack | swish-4.wav | CC0 1.0 |
| `blade/swing_heavy_04.ogg` | RPG Sound Pack | swing.wav | CC0 1.0 |
| `blade/swing_heavy_05.ogg` | RPG Sound Pack | swing2.wav | CC0 1.0 |
| `blade/swing_heavy_06.ogg` | RPG Sound Pack | swing3.wav | CC0 1.0 |
| `blade/unsheathe_01.ogg` | RPG Sound Pack | sword-unsheathe.wav | CC0 1.0 |
| `blade/unsheathe_02.ogg` | RPG Sound Pack | sword-unsheathe2.wav | CC0 1.0 |
| `blade/unsheathe_03.ogg` | RPG Sound Pack | sword-unsheathe4.wav | CC0 1.0 |
| `body/armor_01.ogg` | RPG Sound Pack | chainmail1.wav | CC0 1.0 |
| `body/armor_02.ogg` | RPG Sound Pack | chainmail2.wav | CC0 1.0 |
| `body/grab_01.ogg` | RPG Sound Pack | cloth-heavy.wav | CC0 1.0 |
| `boss/golem_01.ogg` | RPG Sound Pack | giant1.wav | CC0 1.0 |
| `boss/golem_02.ogg` | RPG Sound Pack | giant2.wav | CC0 1.0 |
| `boss/golem_03.ogg` | RPG Sound Pack | giant3.wav | CC0 1.0 |
| `boss/golem_04.ogg` | RPG Sound Pack | giant4.wav | CC0 1.0 |
| `boss/ogre_01.ogg` | RPG Sound Pack | ogre1.wav | CC0 1.0 |
| `boss/ogre_02.ogg` | RPG Sound Pack | ogre2.wav | CC0 1.0 |
| `boss/ogre_03.ogg` | RPG Sound Pack | ogre3.wav | CC0 1.0 |
| `magic_dark/shade_01.ogg` | RPG Sound Pack | shade1.wav | CC0 1.0 |
| `magic_dark/shade_02.ogg` | RPG Sound Pack | shade2.wav | CC0 1.0 |
| `magic_dark/shade_03.ogg` | RPG Sound Pack | shade3.wav | CC0 1.0 |
| `magic_dark/shade_04.ogg` | RPG Sound Pack | shade4.wav | CC0 1.0 |
| `magic_dark/shade_05.ogg` | RPG Sound Pack | shade5.wav | CC0 1.0 |
| `movement/dash_01.ogg` | Battle Sound Effects | swish_2.wav | CC0 1.0 |
| `movement/dash_02.ogg` | Battle Sound Effects | swish_3.wav | CC0 1.0 |
| `movement/dash_03.ogg` | Battle Sound Effects | swish_4.wav | CC0 1.0 |
| `blade/swing_blade_04.ogg` | 20 Sword Sound Effects (attacks) | sword.1.ogg | CC0 1.0 |
| `blade/swing_blade_05.ogg` | 20 Sword Sound Effects (attacks) | sword.5.ogg | CC0 1.0 |
| `blade/swing_blade_06.ogg` | 20 Sword Sound Effects (attacks) | sword.7.ogg | CC0 1.0 |
| `metal/clash_07.ogg` | 20 Sword Sound Effects (clashes) | sword_clash.1.ogg | CC0 1.0 |
| `metal/clash_08.ogg` | 20 Sword Sound Effects (clashes) | sword_clash.4.ogg | CC0 1.0 |
| `metal/clash_01.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Sabre Katana Blade on Blade.wav | CC0 1.0 |
| `metal/clash_02.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Sabre Katana Blade on Blade.wav | CC0 1.0 |
| `metal/clash_03.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Norse Sword Katana Blade on Blade.wav | CC0 1.0 |
| `metal/clash_04.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Norse Sword Katana Blade on Blade.wav | CC0 1.0 |
| `metal/clash_05.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Axe Katana Blade on Blade.wav | CC0 1.0 |
| `metal/haft_02.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Axe Spear Haft on Haft.wav | CC0 1.0 |
| `metal/haft_03.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Mace Spear Haft.wav | CC0 1.0 |
| `metal/mace_01.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Mace Norse Sword Blade.wav | CC0 1.0 |
| `metal/mace_02.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Mace Spear Blade.wav | CC0 1.0 |
| `metal/mace_03.ogg` | Medieval sound effects - Weapon impacts (1 of 2) | Mace Sabre Blade.wav | CC0 1.0 |
| `metal/clash_06.ogg` | Medieval sound effects - Weapon impacts (2 of 2) | Seax Katana Blade on Blade.wav | CC0 1.0 |
| `metal/haft_01.ogg` | Medieval sound effects - Weapon impacts (2 of 2) | Spear Spear Haft on Haft.wav | CC0 1.0 |
| `gun/pistol_01.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | X_31P.wav | CC0 1.0 |
| `gun/pistol_02.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | X_31P.wav | CC0 1.0 |
| `gun/pistol_03.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | X_39P.wav | CC0 1.0 |
| `gun/pistol_04.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | X_39P.wav | CC0 1.0 |
| `gun/pistol_05.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | F_47P.wav | CC0 1.0 |
| `gun/pistol_06.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | F_47P.wav | CC0 1.0 |
| `gun/revolver_01.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | V_22P.wav | CC0 1.0 |
| `gun/revolver_02.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | V_22P.wav | CC0 1.0 |
| `gun/revolver_03.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | V_27P.wav | CC0 1.0 |
| `gun/revolver_04.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | V_27P.wav | CC0 1.0 |
| `gun/revolver_05.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | S_14P.wav | CC0 1.0 |
| `gun/rifle_01.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | T_17P.wav | CC0 1.0 |
| `gun/rifle_02.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | T_17P.wav | CC0 1.0 |
| `gun/rifle_03.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | W_29P.wav | CC0 1.0 |
| `gun/rifle_04.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | W_29P.wav | CC0 1.0 |
| `gun/rifle_05.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | D_32P.wav | CC0 1.0 |
| `gun/shotgun_01.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | H_21P.wav | CC0 1.0 |
| `gun/shotgun_02.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | O_21P.wav | CC0 1.0 |
| `gun/shotgun_03.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | K_22P.wav | CC0 1.0 |
| `gun/shotgun_04.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | N_30P.wav | CC0 1.0 |
| `gun/smg_01.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | P_30P.wav | CC0 1.0 |
| `gun/smg_02.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | P_30P.wav | CC0 1.0 |
| `gun/smg_03.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | P_30P.wav | CC0 1.0 |
| `gun/smg_04.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | P_30P.wav | CC0 1.0 |
| `gun/smg_05.ogg` | The Free Firearm Sound Library (Prepared SFX Library) | P_30P.wav | CC0 1.0 |
| `explosion/large_03.ogg` | 25 CC0 bang / firework SFX | bang_06.ogg + Sci-fi Sounds lowFrequency_explosion_000.ogg (layer, CC0 1.0) | CC0 1.0 |
| `explosion/small_01.ogg` | 25 CC0 bang / firework SFX | bang_01.ogg | CC0 1.0 |
| `explosion/small_02.ogg` | 25 CC0 bang / firework SFX | bang_03.ogg | CC0 1.0 |
| `explosion/small_03.ogg` | 25 CC0 bang / firework SFX | bang_09.ogg | CC0 1.0 |
| `explosion/small_04.ogg` | 25 CC0 bang / firework SFX | bang_07.ogg | CC0 1.0 |
| `gun/cannon_01.ogg` | 25 CC0 bang / firework SFX | cannon_01.ogg | CC0 1.0 |
| `gun/cannon_02.ogg` | 25 CC0 bang / firework SFX | cannon_02.ogg | CC0 1.0 |
| `gun/cannon_03.ogg` | 25 CC0 bang / firework SFX | cannon_03.ogg | CC0 1.0 |
| `gun/cannon_04.ogg` | 25 CC0 bang / firework SFX | cannon_04.ogg | CC0 1.0 |
| `gun/cannon_05.ogg` | 25 CC0 bang / firework SFX | cannon_05.ogg | CC0 1.0 |
| `blade/slash_hit_03.ogg` | 80 CC0 RPG SFX | blade_01.ogg | CC0 1.0 |
| `blade/slash_hit_04.ogg` | 80 CC0 RPG SFX | blade_02.ogg | CC0 1.0 |
| `blade/slash_hit_05.ogg` | 80 CC0 RPG SFX | blade_03.ogg | CC0 1.0 |
| `boss/die_01.ogg` | 80 CC0 RPG SFX | creature_die_01.ogg | CC0 1.0 |
| `boss/roar_04.ogg` | 80 CC0 RPG SFX | creature_roar_02.ogg | CC0 1.0 |
| `boss/roar_05.ogg` | 80 CC0 RPG SFX | creature_roar_03.ogg | CC0 1.0 |
| `magic_earth/stones_01.ogg` | 80 CC0 RPG SFX | stones_01.ogg | CC0 1.0 |
| `magic_earth/stones_02.ogg` | 80 CC0 RPG SFX | stones_02.ogg | CC0 1.0 |
| `magic_earth/stones_03.ogg` | 80 CC0 RPG SFX | stones_03.ogg | CC0 1.0 |
| `magic_fire/fire_burst_01.ogg` | 80 CC0 RPG SFX | spell_fire_01.ogg | CC0 1.0 |
| `magic_fire/fire_burst_02.ogg` | 80 CC0 RPG SFX | spell_fire_03.ogg | CC0 1.0 |
| `magic_fire/fire_burst_03.ogg` | 80 CC0 RPG SFX | spell_fire_05.ogg | CC0 1.0 |
| `magic_fire/fire_burst_04.ogg` | 80 CC0 RPG SFX | spell_fire_07.ogg | CC0 1.0 |
| `metal/chain_01.ogg` | 80 CC0 RPG SFX | chain_01.ogg | CC0 1.0 |
| `metal/chain_02.ogg` | 80 CC0 RPG SFX | chain_02.ogg | CC0 1.0 |
| `metal/chain_03.ogg` | 80 CC0 RPG SFX | chain_03.ogg | CC0 1.0 |
| `boss/hurt_01.ogg` | 80 CC0 creature SFX | hurt_01.ogg | CC0 1.0 |
| `boss/hurt_02.ogg` | 80 CC0 creature SFX | hurt_02.ogg | CC0 1.0 |
| `boss/hurt_03.ogg` | 80 CC0 creature SFX | hurt_03.ogg | CC0 1.0 |
| `boss/hurt_04.ogg` | 80 CC0 creature SFX | hurt_04.ogg | CC0 1.0 |
| `boss/roar_03.ogg` | 80 CC0 creature SFX | roar_02.ogg | CC0 1.0 |
| `blunt/blunt_heavy_01.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_hit_01.ogg | CC0 1.0 |
| `blunt/blunt_heavy_02.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_hit_02.ogg | CC0 1.0 |
| `blunt/blunt_heavy_03.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_hit_06.ogg | CC0 1.0 |
| `blunt/blunt_heavy_04.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_hit_07.ogg | CC0 1.0 |
| `blunt/blunt_heavy_05.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_hit_12.ogg | CC0 1.0 |
| `blunt/wood_04.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_wood_hit_01.ogg | CC0 1.0 |
| `body/fall_03.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_falling_01.ogg | CC0 1.0 |
| `body/fall_04.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_falling_02.ogg | CC0 1.0 |
| `magic_earth/rock_break_01.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_breaking_01.ogg + Sci-fi Sounds lowFrequency_explosion_001.ogg (layer, CC0 1.0) | CC0 1.0 |
| `magic_earth/rock_break_02.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_breaking_02.ogg + Sci-fi Sounds lowFrequency_explosion_001.ogg (layer, CC0 1.0) | CC0 1.0 |
| `magic_earth/rock_break_03.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_breaking_03.ogg + Sci-fi Sounds lowFrequency_explosion_001.ogg (layer, CC0 1.0) | CC0 1.0 |
| `magic_earth/rock_fall_01.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_falling_01.ogg | CC0 1.0 |
| `magic_earth/rock_fall_02.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_falling_05.ogg | CC0 1.0 |
| `magic_earth/rock_fall_03.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_rock_falling_06.ogg | CC0 1.0 |
| `magic_ice/shatter_01.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_glass_breaking_01.ogg | CC0 1.0 |
| `magic_ice/shatter_02.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_glass_breaking_02.ogg | CC0 1.0 |
| `magic_ice/shatter_03.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_glass_breaking_03.ogg | CC0 1.0 |
| `magic_ice/shatter_04.ogg` | 75 CC0 breaking / falling / hit sfx | bfh1_glass_breaking_04.ogg | CC0 1.0 |
| `magic_poison/bubble_01.ogg` | 40 CC0 water / splash / slime SFX | bubble_01.ogg | CC0 1.0 |
| `magic_poison/bubble_02.ogg` | 40 CC0 water / splash / slime SFX | bubble_02.ogg | CC0 1.0 |
| `magic_poison/bubble_03.ogg` | 40 CC0 water / splash / slime SFX | bubble_03.ogg | CC0 1.0 |
| `magic_poison/slime_01.ogg` | 40 CC0 water / splash / slime SFX | slime_01.ogg | CC0 1.0 |
| `magic_poison/slime_02.ogg` | 40 CC0 water / splash / slime SFX | slime_04.ogg | CC0 1.0 |
| `magic_poison/slime_03.ogg` | 40 CC0 water / splash / slime SFX | slime_07.ogg | CC0 1.0 |
| `magic_poison/slime_04.ogg` | 40 CC0 water / splash / slime SFX | slime_10.ogg | CC0 1.0 |
| `gun/click_03.ogg` | 100 CC0 SFX | switch_01.ogg | CC0 1.0 |
| `magic_holy/gong_01.ogg` | 100 CC0 SFX | gong_01.ogg | CC0 1.0 |
| `magic_holy/gong_02.ogg` | 100 CC0 SFX | gong_02.ogg | CC0 1.0 |
| `magic_holy/holy_hit_01.ogg` | 100 CC0 SFX | bell_01.ogg | CC0 1.0 |
| `magic_holy/holy_hit_02.ogg` | 100 CC0 SFX | bell_02.ogg | CC0 1.0 |
| `magic_holy/holy_hit_03.ogg` | 100 CC0 SFX | bell_03.ogg | CC0 1.0 |
| `ui/kill_01.ogg` | 100 CC0 SFX | bell_02.ogg | CC0 1.0 |
| `explosion/large_04.ogg` | Soundpack 03 | explosion03.ogg | CC0 1.0 |
| `explosion/small_05.ogg` | Soundpack 03 | explosion01.ogg | CC0 1.0 |
| `explosion/small_06.ogg` | Soundpack 03 | explosion02.ogg | CC0 1.0 |
| `energy/cast_01.ogg` | Magic Spell SFX | magical_1.ogg | CC0 1.0 |
| `energy/cast_02.ogg` | Magic Spell SFX | magical_2.ogg | CC0 1.0 |
| `energy/cast_03.ogg` | Magic Spell SFX | magical_3.ogg | CC0 1.0 |
| `energy/cast_04.ogg` | Magic Spell SFX | magical_4.ogg | CC0 1.0 |
| `energy/cast_05.ogg` | Magic Spell SFX | magical_5.ogg | CC0 1.0 |
| `energy/teleport_03.ogg` | Spell sounds | teleport.ogg | CC0 1.0 |
| `magic_holy/heal_01.ogg` | Spell sounds | healing.ogg | CC0 1.0 |
| `magic_holy/heal_02.ogg` | Spell sounds | healing.ogg | CC0 1.0 |
| `magic_lightning/crackle_01.ogg` | Spell sounds | electricspell.ogg | CC0 1.0 |
| `magic_lightning/crackle_02.ogg` | Spell sounds | electricspell.ogg | CC0 1.0 |
| `magic_lightning/crackle_03.ogg` | Spell sounds | electricspell.ogg | CC0 1.0 |
| `boss/die_03.ogg` | Monster Sound Effects Pack | monster-6.wav | CC0 1.0 |
| `boss/monster_01.ogg` | Monster Sound Effects Pack | monster-1.wav | CC0 1.0 |
| `boss/monster_02.ogg` | Monster Sound Effects Pack | monster-3.wav | CC0 1.0 |
| `boss/monster_03.ogg` | Monster Sound Effects Pack | monster-5.wav | CC0 1.0 |
| `boss/die_02.ogg` | Monster or beast sounds | Dieing Beast.wav | CC0 1.0 |
| `boss/growl_01.ogg` | Monster or beast sounds | Beast Growl 2.wav | CC0 1.0 |
| `boss/growl_02.ogg` | Monster or beast sounds | Beast Growl 3.wav | CC0 1.0 |
| `boss/growl_03.ogg` | Monster or beast sounds | Demon Growl.wav | CC0 1.0 |
| `magic_dark/spirit_01.ogg` | Monster or beast sounds | Spirit Shout.wav | CC0 1.0 |
| `magic_dark/spirit_02.ogg` | Monster or beast sounds | Children Spirit Sounds.wav | CC0 1.0 |
| `boss/snarl_01.ogg` | Monster snarls | monster-snarl-attack.ogg | CC0 1.0 |
| `boss/snarl_02.ogg` | Monster snarls | monster-snarl-attack.ogg | CC0 1.0 |
| `boss/snarl_03.ogg` | Monster snarls | monster-snarl-attack.ogg | CC0 1.0 |
| `movement/step_snow_04.ogg` | 42 Snow and Gravel Footsteps | Corsica_S-Walking_on_snow_covered_gravel_01.flac | CC0 1.0 |
| `movement/step_snow_05.ogg` | 42 Snow and Gravel Footsteps | Corsica_S-Walking_on_snow_covered_gravel_05.flac | CC0 1.0 |
| `movement/step_snow_06.ogg` | 42 Snow and Gravel Footsteps | Corsica_S-Walking_on_snow_covered_gravel_09.flac | CC0 1.0 |
| `movement/step_stone_01.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneL1.ogg | CC0 1.0 |
| `movement/step_stone_02.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneL2.ogg | CC0 1.0 |
| `movement/step_stone_03.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneL3.ogg | CC0 1.0 |
| `movement/step_stone_04.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneR1.ogg | CC0 1.0 |
| `movement/step_stone_05.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneR2.ogg | CC0 1.0 |
| `movement/step_stone_06.ogg` | Fantozzi's Footsteps (Grass/Sand & Stone) | Fantozzi-StoneR3.ogg | CC0 1.0 |
| `boss/bones_01.ogg` | Footsteps on different surfaces | 0.ogg | CC BY 3.0 (sources CC0) |
| `boss/bones_02.ogg` | Footsteps on different surfaces | 1.ogg | CC BY 3.0 (sources CC0) |
| `boss/bones_03.ogg` | Footsteps on different surfaces | 2.ogg | CC BY 3.0 (sources CC0) |
| `boss/bones_04.ogg` | Footsteps on different surfaces | 3.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_01.ogg` | Footsteps on different surfaces | 0.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_02.ogg` | Footsteps on different surfaces | 1.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_03.ogg` | Footsteps on different surfaces | 2.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_04.ogg` | Footsteps on different surfaces | 3.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_05.ogg` | Footsteps on different surfaces | 4.ogg | CC BY 3.0 (sources CC0) |
| `movement/step_dirt_06.ogg` | Footsteps on different surfaces | 5.ogg | CC BY 3.0 (sources CC0) |
| `magic_wind/wind_02.ogg` | wind whoosh loop | wind_woosh_loop.ogg | CC0 1.0 |
| `magic_wind/wind_03.ogg` | wind whoosh loop | wind_woosh_loop.ogg | CC0 1.0 |

---------------------------------------------------------------------------------------------------
## Music 音乐 (AUDIO track: `autoload/music.gd`, `assets/music/<slot>/`)

All music is played locally on each peer by the `Music` autoload. Every file was changed the same way unless the
row says otherwise: converted to OGG Vorbis (q5, 44.1 kHz), metadata stripped, one constant volume change for
loudness normalization (about -16 LUFS, peak <= -1.5 dBFS), with light peak limiting ("limited") on tracks that
needed more gain than their peak headroom allowed. "Trimmed" means cut to the stated length with a 2 s fade-out.
Licence texts: `licenses/CC-BY-4.0-legalcode.txt`, `licenses/CC-BY-3.0-legalcode.txt`,
`licenses/CC0-1.0-legalcode.txt`, `licenses/BiteMe-Chinese-Game-Music-CC0.txt`.

| Title | Author | License | Attribution / source | Changes | Folder |
|---|---|---|---|---|---|
| Mountain Emperor | Kevin MacLeod | CC BY 4.0 | "Mountain Emperor" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/menu/mountain_emperor.ogg` |
| Views From Atop the Jade Kings Throne | HitCtrl | CC BY 3.0 | "Views From Atop the Jade Kings Throne" by HitCtrl (https://opengameart.org/content/views-from-atop-the-jade-kings-throne), licensed under CC-BY 3.0 (https://creativecommons.org/licenses/by/3.0/) | trimmed to 3:00, volume normalized, OGG | `music/menu/jade_kings_throne.ogg` |
| Shenyang | Kevin MacLeod | CC BY 4.0 | "Shenyang" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, OGG | `music/lobby/shenyang.ogg` |
| Lotus Pond - Loop (Chinese Game Music v1.0) | BiteMe Games | CC0 1.0 | courtesy credit: "Lotus Pond" by BiteMe Games (https://bitemegames.itch.io/chinese-game-music), CC0 1.0 | volume normalized, WAV to OGG | `music/lobby/lotus_pond_loop.ogg` |
| Guzheng City | Kevin MacLeod | CC BY 4.0 | "Guzheng City" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/lobby/guzheng_city.ogg` |
| Big Mojo | Kevin MacLeod | CC BY 4.0 | "Big Mojo" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/battle_pvp/big_mojo.ogg` |
| Movement Proposition | Kevin MacLeod | CC BY 4.0 | "Movement Proposition" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, OGG | `music/battle_pvp/movement_proposition.ogg` |
| Undaunted | Kevin MacLeod | CC BY 4.0 | "Undaunted" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:00, volume normalized, limited, OGG | `music/battle_pvp/undaunted.ogg` |
| Dragon Dance - Loop (Chinese Game Music v1.0) | BiteMe Games | CC0 1.0 | courtesy credit: "Dragon Dance" by BiteMe Games (https://bitemegames.itch.io/chinese-game-music), CC0 1.0 | volume normalized, WAV to OGG | `music/battle_pvp/dragon_dance_loop.ogg` |
| Future Gladiator | Kevin MacLeod | CC BY 4.0 | "Future Gladiator" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:00, volume normalized, OGG | `music/battle_arena/future_gladiator.ogg` |
| The Complex | Kevin MacLeod | CC BY 4.0 | "The Complex" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:00, volume normalized, OGG | `music/battle_arena/the_complex.ogg` |
| The Snow Queen | Kevin MacLeod | CC BY 4.0 | "The Snow Queen" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:00, volume normalized, limited, OGG | `music/raid_explore_frost_forest/the_snow_queen.ogg` |
| RPG - Misty Mountains | HitCtrl | CC BY 3.0 | "RPG - Misty Mountains" by HitCtrl (https://opengameart.org/content/rpg-misty-mountains), licensed under CC-BY 3.0 (https://creativecommons.org/licenses/by/3.0/) | trimmed to 3:00, volume normalized, OGG | `music/raid_explore_frost_forest/misty_mountains.ogg` |
| Ossuary 6 - Air | Kevin MacLeod | CC BY 4.0 | "Ossuary 6 - Air" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:00, volume normalized, limited, OGG | `music/raid_explore_boneyard/ossuary_6_air.ogg` |
| Ossuary 1 - A Beginning | Kevin MacLeod | CC BY 4.0 | "Ossuary 1 - A Beginning" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/raid_explore_boneyard/ossuary_1_a_beginning.ogg` |
| Five Armies | Kevin MacLeod | CC BY 4.0 | "Five Armies" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, OGG | `music/raid_boss_frost_golem/five_armies.ogg` |
| Final Battle of the Dark Wizards | Kevin MacLeod | CC BY 4.0 | "Final Battle of the Dark Wizards" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | trimmed to 3:20, volume normalized, OGG | `music/raid_boss_black_knight/final_battle_of_the_dark_wizards.ogg` |
| Black Vortex | Kevin MacLeod | CC BY 4.0 | "Black Vortex" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/raid_boss_enrage/black_vortex.ogg` |
| Ishikari Lore | Kevin MacLeod | CC BY 4.0 | "Ishikari Lore" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/results/ishikari_lore.ogg` |
| 10 Fanfares (two cuts of the sequence) | Spring Spring | CC0 1.0 | courtesy credit: "10 Fanfares" by Spring Spring (https://opengameart.org/content/10-fanfares), CC0 | cut into two stingers (0:00.0-0:05.9 and 0:20.5-0:25.8, 0.3 s fade-out), volume normalized, limited, OGG | `music/victory/fanfare_a.ogg`, `fanfare_b.ogg` |
| Discovery Hit | Kevin MacLeod | CC BY 4.0 | "Discovery Hit" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, OGG | `music/victory/discovery_hit.ogg` |
| Death of a Ninja (Game Over) | Joth | CC0 1.0 | courtesy credit: "Death of a Ninja (Game Over)" by Joth (https://opengameart.org/content/death-of-a-ninja-game-over), CC0 | volume normalized, limited, OGG | `music/defeat/death_of_a_ninja.ogg` |
| Darkness Speaks | Kevin MacLeod | CC BY 4.0 | "Darkness Speaks" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/ | volume normalized, limited, OGG | `music/defeat/darkness_speaks.ogg` |

Kevin MacLeod's music is used under CC BY 4.0 as given by the incompetech.com FAQ credit template (attribution:
"Title" Kevin MacLeod (incompetech.com), Licensed under Creative Commons: By Attribution 4.0). Please support the
composers: incompetech.com, opengameart.org/users/hitctrl, bitemegames.itch.io.

---------------------------------------------------------------------------------------------------
## Ambience 环境音 (AUDIO track: `assets/ambience/`, Ambience bus, one loop per map zone)

Every file: converted to OGG Vorbis (q5, 44.1 kHz), one constant volume change to about -26 LUFS (the beds sit
under the music), looped by the engine. The JC Sounds packs are used under the CC BY 4.0 grant stated on their
OpenGameArt pages.

| File | Source | Author | License | Attribution / source |
|---|---|---|---|---|
| `ambience/arena_crowd.ogg` (Classic Arena) | Free Crowd Cheering Sounds, track 10 "Ambience" | Gregor Quendel | CC BY 4.0 | "Free Crowd Cheering Sounds" by Gregor Quendel (www.gregorquendel.com), https://opengameart.org/content/free-crowd-cheering-sounds, licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Modified (volume, converted to OGG). |
| `ambience/forest_day.ogg` (Hundred Blossoms) | Nature Ambient Pack Vol 1, "Forest Day" | JC Sounds | CC BY 4.0 | "Nature Ambient Pack Vol 1" by JC Sounds, https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1, licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Credit: JC Sounds. Modified (100 Hz high-pass filter, volume, converted to OGG). |
| `ambience/mountain_wind.ogg` (Old Castle) | Nature Ambient Pack Vol 1, "Mountain Peak" | JC Sounds | CC BY 4.0 | "Nature Ambient Pack Vol 1" by JC Sounds, https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1, licensed CC BY 4.0. Credit: JC Sounds. Modified (volume, converted to OGG). |
| `ambience/forest_night.ogg` (Burial Grounds) | Nature Ambient Pack Vol 1, "Forest Night" | JC Sounds | CC BY 4.0 | "Nature Ambient Pack Vol 1" by JC Sounds, https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1, licensed CC BY 4.0. Credit: JC Sounds. Modified (100 Hz high-pass filter, volume, converted to OGG). |
| `ambience/winter_wind.ogg` (Frost Forest) | Nature Ambient Pack Vol 1, "Winter Wind" | JC Sounds | CC BY 4.0 | "Nature Ambient Pack Vol 1" by JC Sounds, https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1, licensed CC BY 4.0. Credit: JC Sounds. Modified (volume, converted to OGG). |
| `ambience/volcano.ogg` (Lava Cave) | Ambience of a Fallen Age, "entering_the_volcano" | Umplix | CC0 1.0 | courtesy credit: Umplix (https://opengameart.org/content/ambience-of-a-fallen-age). First 64 s, volume, converted to OGG. |
