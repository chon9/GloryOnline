# RONGYAO ARENA — Art Bible v1
### Look target: the in-game world of *Glory* (荣耀) as shown in the 全职高手 / *The King's Avatar* donghua (S1 2017 by 视美精典 / BCMAY; S2–S3 2019–2023 by 彩色铅笔 / Colored Pencil). The live-action version is out of scope.

> **Legal note.** This is a fan project in a **public** repo. We **evoke** the show's design language with original assets. We do **not** trace, ship or texture-sample official art, logos (the winged 榮耀 crest, team emblems) or screenshots. Reference stills live only in `scratchpad/art/ref/` and must never be committed. Every shipped asset needs a CC0, CC-BY, MIT/OFL or redistribution-permitting license, recorded in `assets/CREDITS.md` and `assets/licenses/`.

---

## 0. The one-paragraph pitch

Glory in the donghua uses **2D cel-shaded, tall, sharp-faced anime fighters in ornate Western-fantasy armour**, set against **richly painted, almost photographic 3D backgrounds**: warm sandstone towns, golden-hour ruins, cyan snow forests with blood-red maples, blue-violet moonlit canyons. Backgrounds are heavily depth-blurred and filled with drifting light motes. Each character is built from **2–3 saturated signature colours plus gold trim**, with one huge silhouette element: a 2 m trailing red scarf, a cape, a witch hat, a cannon. Skills read as **hot additive light** (magenta, violet, ice-cyan, gold) **with big painted debris and dust shapes**. UI is **dark navy glass with thin gold filigree, blue crystal accents and white sans text**. Readable at 10 m, gorgeous at 1 m. Our current build is the opposite of each of these points: chibi, flat-lit, grey, letter-tiled and emoji-like.

---

## 1. Reference stills studied (internal only, never ship)

All are in `C:/Users/AlexChon9/AppData/Local/Temp/claude/k--Project-RONGYAO/02f9dec6-8b63-40c7-a40a-2badcaa879c0/scratchpad/art/ref/`. The `*_v.png` files are PNG conversions. Source: the-kings-avatar.fandom.com image uploads, which are screenshots and official promo art, © Tencent / 阅文 / the studios.

| File | What it teaches |
|---|---|
| `lordgrim_card_v.png` | 君莫笑 S1 design (navy and gold plate, red scarf, white 千机伞 in spear form) and the in-show "account info" holo overlay: charcoal glass with circuit traces and white CN text. |
| `umbrella_ep1_v.png`, `umbrella_lance_ep2_v.png`, `umbrella_gatling_ep3_v.png` | 千机伞 forms: radial white canopy panels, khaki mechanical hilt, red energy seam, 6-barrel gatling form. |
| `oneautumnleaf_card_v.png` | 一叶之秋 Battle Mage: black long coat, gold armour filigree, 却邪 lance. Also the official card frame motif. |
| `troublingrain_card_v.png` | 夜雨声烦 Blade Master: silver plate, gold trim, royal-blue cape with white lining. |
| `vaccaria_card_v.png` | 王不留行 Witch: floor-length royal-blue robe, gold flame-trim mantle, crowned witch hat. |
| `dancingrain_countdown_v.png` | 沐雨橙风 Launcher: yellow/orange/white, goggles, lace-up corset, brass cannon with a glowing yellow chamber. Card frame with gold sunburst base. |
| `desertdust_v.png` | 大漠孤烟 Striker: red/black/gold, lion-head pauldron, torn white coat. |
| `ep1_1_v.png`, `ep2_1_v.png` | Glory town: warm sandstone Mediterranean/Gothic streets with painted-photo texture detail, guild signboard, crowds blurred. |
| `ep2_3_v.png`, `sumucheng_mist_ep6_v.png` | Wild map: cyan sky, snow, frost-covered bare trees, one **red maple** as the focal landmark. |
| `ep4_3_v.png` | Night canyon fight: blue-violet palette, violet additive weapon flare, rock debris, foreground dust blur. |
| `ep9_v.png` | Golden-hour Gothic ruins, dust storm, low heroic camera, scarf as a giant motion arc. |
| `ep10_v.png` | 冰霜森林-era boss/NPC: white-violet fur, crown, staff with **glowing violet rune text**. |
| `ep11_1_v.png`, `ep12_2_v.png` | Close-up face rendering: 1 shadow tone, thin dark-brown lines, sharp hair highlight streaks, backlight bloom. |
| `glory0_v.png` | Glory logo language: brushed gold, wings, crossed swords, cog. Inspires our crest, but do not copy it. |
| `s3promo_v.png` | S3 key visual: magenta/purple neon, circuit lines. This is the pro-league / esports-broadcast language. |

---

## 2. Character design language

### 2.1 Proportions and anatomy
- **7.5–8 heads tall** for adult males and **7–7.5** for females. Legs make up about 52% of height. Shoulders are 2.2–2.5 head-widths wide on males. The current KayKit models are about 2.5 heads; that is the single biggest "not Glory" signal.
- Small skull, long neck, narrow waist and long forearms. Hands are expressive, with long fingers and often gloved or clawed gauntlets.
- Heavy classes (Knight, Striker, Launcher) get bulk from **armour silhouettes**, not from body fat. Faces stay slim.
- Use a single shared base skeleton with a male body and a female body. Proportion sliders cover the rest. The camera sits at 3/4 top-down MMO distance, so **exaggerate head and hand silhouettes by about 8%** compared with the anime so they still read when small.

### 2.2 Faces and eyes
- Sharp V jaw with a small, pointed chin. The nose is a single shade wedge with a tiny highlight. The mouth is a 2–3 px line.
- **Male eyes:** narrow almond, a heavy single upper lash line (dark brown, not black), a small iris with one specular dot plus a lower-iris colour band. Expressions are lazy, smug or confident. Ye Xiu's half-lidded look is iconic.
- **Female eyes:** larger (about 1.4× male), a thick upper lash mass flicking out at the outer corner, a gradient iris (dark top to light bottom) with 2 highlights. Su Mucheng has sky-blue eyes.
- Faces use **one** shadow tone only, driven by a face SDF or edited normals so shadows never blotch. Add a nose/cheek blush stripe (`#E89A8C` at 30%) for females.

### 2.3 Hair
- **Large, chunky locks**: 8–14 big cards or shell meshes per head, each tapering to a sharp tip. Never use a helmet blob or fine strands.
- Gravity-defying volume at the crown, side bangs that cross the eyes, and an ahoge on Blade Master types (Huang Shaotian).
- **Shading:** base, one shadow band (darker and more saturated, hue-shifted toward blue/purple), plus **sharp angular specular streaks**: a broken anisotropic band of 2–4 white or pale-tinted slashes across the crown.
- Hair is **one flat, saturated colour family** per character: natural brown/black for Ye Xiu, gold for Huang Shaotian, orange-blonde for Su Mucheng, silver for Wang Jiexi, red for Han Wenqing. Fantasy colours (silver, white, violet, teal) are fine for Glory avatars.
- Hair, scarves, capes and coat tails **must move**. Use spring bones. Secondary motion is half the anime look.

### 2.4 Costume rules (all classes)
1. **2–3 dominant colours + metallic trim** (gold `#D8B25A` or silver `#C9D3DE`). Trim follows edges as **filigree and claw/flame shapes**, never plain bands.
2. **One hero silhouette element per character**, sized at 30–100% of body height: a long scarf, cape, coat tail, hat, cannon, umbrella or tome.
3. **Layering:** dark undersuit, then light mid-layer (white/cream shirt, tabard), then armour plates on shoulders, forearms and shins. Brown leather belts, straps and pouches add a lived-in feel.
4. **Asymmetry is encouraged**: one pauldron, one long glove, a single torn coat edge (Desert Dust), a scarf over one shoulder.
5. Plates have **pointed, swept-back flares**. Pauldrons and knee guards have fin-like points. Boots come to points or claws.
6. **Western fantasy** costume base (DNF/Diablo heritage) with **light Chinese seasoning**: mandarin collars, frog buttons, red rope sashes with tassels, cloud-pattern trim on Striker/Fighter types.

### 2.5 Class archetype sheet (25 classes)

Colours are suggestions. Team colour will override the accent at runtime.

| Family | Class | Silhouette hook | Default palette |
|---|---|---|---|
| **Unspecialized** | 散人 (君莫笑-type) | Long red scarf trailing 1.5–2 m with torn ends; mismatched plate; transforming umbrella | Navy `#1E2440` plate, gold trim, white/silver under-plate `#DCE2EA`, scarf red `#C8202A` |
| Swordsman | Blade Master 剑客 (夜雨声烦) | Blue cape with white lining, silver cuirass, light sword with a glowing blade | Silver `#C9D3DE`, royal blue `#1F5FBF`, gold trim, blade cyan `#7FE8FF` |
| | Berserker 狂剑士 | Huge greatsword, bare arm, tattered half-cape | Crimson `#9E1B25`, black, bronze |
| | Ghostblade 鬼剑士 | Bandaged arm, ghost runes, long coat | Black-violet `#2A1E3A`, pale violet glow `#B48CFF` |
| | Spellblade 魔剑士 | Rune-etched blade, magic circle at the hilt | Teal `#147A82`, white, gold |
| Mage | **Battle Mage 战斗法师 (一叶之秋)** | Floor-length black coat split at the hips, armoured high collar, battle lance | Black `#16161C`, gold filigree `#D8B25A`, red gem `#D2283A` |
| | Elementalist 元素法师 | Hooded robe, floating elemental orbs | Per element; robe deep plum `#3A2350` |
| | Summoner 召唤师 | Book on a chain, small floating spirits | Green-teal `#2F8F7A`, cream |
| | **Witch 魔道学者 (王不留行)** | Tall crowned witch hat, floor-trailing robe, **broom** | Royal blue `#23379A`, deep navy, gold flame trim, silver hair |
| Gunner | **Launcher 枪炮师 (沐雨橙风)** | Oversized brass cannon (longer than the torso), goggles, corset | Yellow `#F2C230`, orange `#F08A24`, white blouse, brown leather `#6B3E22`, energy yellow `#FFE45A` |
| | Sharpshooter 神枪手 | Twin revolvers, long duster coat, hat | Brown `#5A3B28`, crimson, brass |
| | Mechanic 机械师 | Backpack drone rig, goggles, tool belts | Gunmetal `#4A525C`, safety orange `#FF8A1F` |
| | Spitfire 弹药专家 | Bandolier, grenade launcher, scarf mask | Olive `#5B6235`, rust `#A4502A` |
| Fighter | **Striker 拳法家 (大漠孤烟)** | Open chest, lion pauldron, torn white long coat, red rope sash | Red `#B3262A`, black, white coat `#ECE6DA`, gold |
| | Qi Master 气功师 | Flowing sleeves, floating qi orbs | White/sky blue `#7FC4FF` |
| | Grappler 柔道 | Gi-style wrap, belt, heavy forearms | Indigo `#2B3A6E`, white |
| | Brawler 流氓 | Street jacket, brick or bag, chains | Purple `#5A2E6E`, mustard |
| Priest | Cleric 牧师 | White cape with gold cross clasp, high collar (Fang Shiqian-type) | White `#F2F0EA`, navy, gold |
| | Paladin 守护天使 | Wings motif, lance and shield | White, sky blue, gold |
| | Exorcist 驱魔师 | Censer, talismans, cross staff | Black, red, silver |
| Knight | Knight 骑士 | Tower shield + lance, heavy layered plate | Steel `#8E9AAB`, team colour tabard |
| Nightwalker | Assassin 刺客 | Short cloak, twin daggers, face mask | Charcoal, wine red `#7A1F33` |
| | Thief 盗贼 | Hood, belt pouches, shuriken | Dark green `#1F3B2D`, tan |
| | Shadow Warrior 忍者 | Ninja wrap, long scarf, ninjato | Navy, crimson scarf |
| | Warlock 术士 | Skull ornaments, cursed tome | Black, toxic green `#7CFF6B` |

### 2.6 Signature weapons
Weapons are **35–60% larger** than "realistic" and carry the **brightest values on the model**.

- **千机伞 Myriad Manifestations Umbrella.** The canopy is 8 white/silver triangular panels with fine dark rib lines. Folded, it reads as a giant faceted spear tip. The hilt is a **khaki/bone mechanical shaft** (`#CBB89A`) with claw-like guards and spikes. A **glowing red seam** (`#E0232E` emissive) runs along one edge. Forms: lance (folded), sword, gatling (6 dark barrels emerging from the canopy hub), shield (open canopy), and others. Morphs must be animated with panels folding and snapping, not swapped instantly.
- **却邪 battle lance.** A black shaft about 2.2 m long. The head is a long serrated silver blade with a back hook. A **red orb gem** in black claw prongs sits at the base of the head. The butt has a silver spike.
- **冰雨 Ice Rain.** A slim hilt with gold guard wings. The blade is a **light-saber-like translucent ice-cyan energy blade** (`#7FE8FF` core and `#2F9BFF` halo), solid core, flickering edge.
- **灭绝星尘 broom.** A long dark shaft. The bristles are a fan of **star-dust particles**: violet-blue `#6C7BFF` with white sparkle. Gold bands. It doubles as a mount (flying broom).
- **Launcher cannon.** Brass and steel `#B9944A` with hazard stripes (yellow/black) and a **glass energy chamber** glowing yellow. Long braided fuse cable.

---

## 3. Rendering spec (Godot 4.7 Forward+)

The core rule is **two shading worlds**: cel-shaded characters, VFX and props-in-hand go over **painterly-lit environments**. The donghua does exactly this, with flat 2D characters over semi-real CG backgrounds. Do not cel-shade the whole world and do not PBR the characters.

### 3.1 Characters (custom toon `ShaderMaterial`)
- **Diffuse ramp:** 2 bands (lit / shadow). Threshold `NdotL > 0.0`, edge smoothstep width **0.03–0.06** (crisp but anti-aliased). An optional 3rd "core shadow" band only on hair and big cloth folds, at 0.6× shadow.
- **Shadow colour is never black or grey.** Shadow = albedo × per-material **tint**:
  - Skin `#F6DCCB`, shadow `#D9A08C`
  - White cloth `#F2F0EA`, shadow `#A9B3D6` (cool lavender-blue)
  - Gold `#D8B25A`, shadow `#8A5A2B`
  - Navy `#1E2440`, shadow `#10122A`
  - Red `#C8202A`, shadow `#7A0F2E` (hue shifts toward magenta)
  - In general: shadow hue moves 10–20° toward blue/purple, saturation +10–20%, value −30–45%.
- **Specular:** none on skin or cloth. **Hair** uses a stepped anisotropic band. **Metal** uses a matcap-like stepped highlight with 2 hard bands plus a white glint.
- **Rim light:** a thin fresnel rim, width **0.08–0.12**, only on the lit side or the key-light-opposite side. Colour = sky/key light tint (warm `#FFE2B0` by day, cyan `#9FE6FF` at night/snow). Strength 0.6. Rim can exceed 1.0 slightly so bloom catches it on backlit shots.
- **Outline:** inverted hull, **width in screen space** (constant about **1.6 px at 1080p**, scaled by resolution, clamped thinner at distance). Use vertex colour to thin lines at fingertips and hair tips.
  - **Outline colour** = albedo × 0.3, saturation ×1.3. Typical values: dark brown `#2A1A14` on skin, navy `#0B0E1F` on navy, oxblood `#3A0A10` on red.
  - **Never use pure `#000000`.**
- **Inner lines:** baked into the texture (seams, plate edges, filigree) as 1–2 px dark lines.
- **Textures:** **hand-painted flat albedo** with only subtle gradients. No photo noise, no normal maps on cloth. A plate normal map is allowed only for the stepped specular.
- **Face:** a separate SDF shadow-threshold texture so the face never gets ugly shadow blobs. Eyes and brows render on top of hair (stencil) as the anime does.

### 3.2 Environments
- **Painted-PBR hybrid.** Use Godot `StandardMaterial3D` with **hand-painted albedo that has baked AO and value variation**. Roughness stays high (0.7–0.95), metallic is mostly 0 except real metal.
- Lighting: one strong **directional key** (warm or cold per zone), **sky/ambient** at 0.4–0.6 energy with a tinted colour, **SDFGI or baked lightmaps** for bounce, and **SSAO** at 0.6–1.0 to anchor props.
- **Atmosphere is mandatory:** depth fog (Godot volumetric fog or plain depth fog) tinted to the sky. **Aerial perspective**: anything over 60 m loses 40–60% contrast and shifts to the sky hue.
- **Depth of field:** a cinematic far DOF in menus, cutscenes and the spectator camera. In gameplay, apply only a light far blur from 80 m out.
- **Light motes:** floating additive particles everywhere (dust, snow, pollen, embers), 50–200 per screen, slow drift. Nearly every reference still has them.

### 3.3 Post-processing / grading (`WorldEnvironment`)
- Tonemap **ACES** or **AgX**, exposure 1.0, white about 6.
- **Glow/Bloom:** enabled, HDR threshold **1.0**, intensity **0.6–0.9**, bloom levels 3–6 (wide halo). VFX emissives go 2–6× HDR. Only VFX, weapon glows, rims and the sun bloom. **Characters must not bloom.**
- **Saturation 1.1–1.2, contrast 1.05–1.1.** Use an **adjustment LUT per zone**:
  - Town: warm highlights `#FFE7C2`, cool shadows `#4A5A8A`.
  - Snow: cyan shadows `#5FA8C8`, white highlights.
  - Night canyon: violet `#4B3FA0` shadows, cyan moon highlights.
  - Ruins: amber `#E0A050` highlights, dust brown haze.
- Optional subtle chromatic aberration (0.2) and vignette (0.15–0.25), mainly on hit-stop and ultimates.
- **Sun flares / god rays** in town and forest. Use volumetric fog with light shafts.

---

## 4. Environments

### 4.1 What Glory's world looks like in the show
- **Architecture is European fantasy, not Chinese.** Sandstone and limestone Mediterranean towns with arched windows, balconies, carved cornices, wooden awnings and signboards. **Gothic cathedral spires and broken flying buttresses** form the ruins. Chinese appears only in **signage** (wooden 公会 board with carved calligraphy) and occasional costume details. Keep it that way: a Western MMO world filtered through a Chinese game company.
- **Wild maps.** Snowy forests with frosted bare branches, rendered as fine dark branch silhouettes coated in white. Cyan sky. **Single saturated focal trees** (a red maple against blue/white). Rocky canyons with stratified cliffs. Desert ruins in golden haze.
- **Dungeons (冰霜森林 Frost Forest, 蜘蛛洞穴 Spider Cave, Boundary of Sea and Sky, etc.).** Mood-lit, dark, saturated, one dominant hue each, with glowing runes, crystals and ice.
- **Pro-league arena maps.** Compact, symmetrical-ish 3D maps, each with a clear **theme and landmark**: ruined city, forest temple, ice cave. Lots of verticality (stairs, bridges, cliffs) because Glory fights are about positioning.
- **Skyboxes.** Painted skies with **large stylized cumulus** shapes (anime clouds: hard-edged highlights, soft bottoms), golden-hour gradients, or starfields with nebula mist (the umbrella-lance still).
- **Vegetation.** Stylized but dense. Leaf-card clumps with painted shapes, wind sway, and gradient trees darker at the core and lighter at the edges with a rim-light catch. Grass is short, clumpy and colour-varied, with flowers in drifts.

### 4.2 Zone mood boards (each zone gets one key light, one LUT and one hero colour)
| Zone | Key light | Fill/sky | Hero accent | Notes |
|---|---|---|---|---|
| Town hub (Glory city) | Warm sun `#FFD9A0` 35° | Blue `#8EC3F0` | Red guild banners `#B3262A` | Sandstone, terracotta roofs, market awnings, crowds |
| Frost Forest 冰霜森林 | Low white-cyan `#DFF6FF` | Cyan `#5FB7D6` | **Red maple** `#E0283A` | Snow-coated branches, ice crystals, blue-shadowed snow |
| Night Canyon | Moon cyan `#8FD0FF` | Violet `#3B2E7A` | Violet magic `#B37BFF` | Stratified rock, rubble, mist pools |
| Golden Ruins | Amber `#FFB45C` 15° | Dust haze `#C99A6A` | Sky blue rift `#7FC8FF` | Gothic spires, sand drifts, flying debris |
| Spider Cave / dungeon | Torch orange `#FF9A3C` points | Teal-green `#1F4F4A` | Toxic green `#7CFF6B` | Webs, bones, glowing egg sacs |
| Pro arena "Glory Stage" | Neutral white + team colour rim | Dark | Team blue `#2F7BFF` vs red `#FF3B4A` | Clean readable floor, boundary runes, spectator holo |

### 4.3 How to avoid the "asset-flip / AI slop" look
1. **One palette per zone**, including props. Recolour every imported asset to the zone's 5–7 swatches with a palette-remap texture or material override. **Never leave a KayKit default grey.**
2. **Landmarks:** every map needs **1 primary landmark** visible from anywhere (spire, giant tree, broken colossus, red maple), plus **2–3 secondary** ones. Players navigate by silhouette.
3. **Height variation:** no flat dungeon tile grids. Every 10–15 m, include a change of **at least 1.5 m** (stairs, ledges, rubble mounds, platforms). Arenas need high ground and low ground.
4. **Composition:** frame combat spaces with dark foreground silhouettes (pillars, branches) and a bright background. **Value structure:** the playable floor sits in mid value, the background is lighter (atmosphere) and the foreground framing is darker.
5. **Set dressing density with intent:** clusters of 3–7 props at **edges and corners**, open readable floors in the middle. Every room tells a story: a broken siege engine, a frozen adventurer, a guild banner.
6. **Break tiling:** use decals (cracks, moss, snow drifts, blood, scorch), vertex-painted blends, and rotate or scale modular pieces. No visible 2 m grid repetition.
7. **Edges are soft:** grass, snow or sand creep over the bases of walls, and rubble piles up at corners.
8. **Lighting tells you where to go:** warm light marks the objective, cold light marks the danger.
9. **Life:** animated foliage, banners, falling snow, drifting motes, birds, water shimmer. A static world reads as fake.

---

## 5. Skill VFX

### 5.1 Style
- **Bold, graphic shapes.** Crescent **slash arcs** are thick at the centre, taper to razor tips, have a white-hot core, a coloured falloff and 2–3 trailing echo arcs.
- **Glyph circles:** concentric rings with **rotating rune text** (pseudo-Latin/Glory runes as in the boss staff, ep10), ticks and triangles. Use them for casts, AoE warnings, summons and buffs.
- **Painted debris:** large chunky rock shards with cel shading and outlines, plus **big puffy painted dust clouds** with hard-edged highlights. Never use smoke-texture noise blobs.
- **Light streaks and speed lines** on dashes. Ice streaks are diagonal lines (umbrella gatling still).
- **Additive cores:** a white core (HDR 4–6) plus a saturated mid colour (HDR 1.5–3) and a soft outer halo, with bloom carrying the glow.
- Each VFX is **max 3 colours**: the element colour plus white plus one accent.

### 5.2 Element / school colours
| Element / type | Core | Mid | Accent |
|---|---|---|---|
| Physical slash | `#FFFFFF` | `#CFE6FF` | `#6FA8FF` |
| Fire | `#FFF4C2` | `#FF8A1F` | `#D2283A` |
| Ice | `#FFFFFF` | `#7FE8FF` | `#2F9BFF` |
| Lightning | `#FFFFFF` | `#B8F0FF` | `#7A5CFF` |
| Shadow / dark | `#E8D8FF` | `#8A4CFF` | `#2A0F4A` |
| Holy / heal | `#FFFBE6` | `#FFD86A` | `#7CF0A0` |
| Poison | `#EFFFD6` | `#7CFF6B` | `#3A6B1F` |
| Qi / chi | `#FFFFFF` | `#7FC4FF` | `#9FFFE6` |
| Gun / explosive | `#FFF6C0` | `#FFC43A` | `#FF5A1F` |
| Unspecialized / umbrella | `#FFFFFF` | `#E0232E` | `#F2E6CF` |

### 5.3 Timing (60 fps)
- **Anticipation:** 4–10 frames, with a squash pose and a small glyph flash or charge particles converging.
- **Impact frame:** 1–2 frames of **full-screen inverse or white flash** on heavy hits and ultimates (screen tinted to the element at 30–60%), plus a radial line burst.
- **Hit-stop:** light 3 f, medium 5 f, heavy 8 f, ultimate/finisher 12 f. Freeze attacker and target, but keep VFX particles animating.
- **Follow-through:** arcs linger 6–12 f and fade with an alpha-erosion dissolve (not a linear fade). Dust settles over 30–60 f.
- **Camera:** shake (trauma model) at 0.1/0.25/0.5. Short 3–5% FOV punch-in on launches. Slow-mo is not allowed in PvP.
- **Launch/juggle:** an upward streak trail plus a ground ring on launch. On landing, a dust puff and a crack decal.

### 5.4 Screen effects
- Ultimate cast: brief letterbox bars plus a **cut-in** (character bust on a diagonal slash band, element colour, 0.6 s). Optional in PvP for spectators.
- Low HP: a desaturated, red-pulsing vignette.
- Crowd control on self: border glyph frost (ice), a jitter shake (stun), a violet edge vignette (silence).

### 5.5 Damage numbers
- Bold condensed numerals with a **2 px dark outline** and a drop shadow. They pop at 140%, settle to 100% in 6 f, and float up while fading.
- White for normal damage. **Gold `#FFC43A`, larger, with a "暴击" tag** for crits. Green `#7CF0A0` with a + sign for heals. Light blue for absorb. Grey "MISS"/"闪避" for evades. Red `#FF4A4A` for damage taken.
- Combo counter: "**12 连击**" in gold with a slash underline.

---

## 6. UI / HUD

### 6.1 Design language (derived from the show's account cards, the info overlay in `lordgrim_card` and the S3 key visual)
- **Panels:** dark navy or teal glass `#0E1A2A` at 85–92% opacity, with a faint magic-circle or circuit-trace pattern at 5–8%.
- **Borders:** **1–2 px gold** `#D8B25A` filigree with corner flourishes.
- **Accents:** **blue diamond crystals** `#3FA9FF` on the frame mid-points.
- **Ornaments:** spiky gold sunburst/crown ornaments on hero frames only (character select, MVP and ultimate slots).
- **Holo overlays** (target info, scoreboard, spectator): charcoal glass `#141820` at 70%, thin cyan `#4FD8FF` or white lines, scan-line shimmer, circuit traces, and white text in a left-aligned technical layout.
- **Pro-league broadcast:** darker with **magenta/purple neon** `#C23BFF` → `#FF3B8A` gradients, angled parallelogram name plates, team colour bands, and big condensed numerals for score and timer.

### 6.2 HUD layout (MMO action)
- **Bottom centre:** skill bar of 2×6 or 1×10 square slots (56–64 px), a slight gap and **bevelled gold frames**. Two larger slots on the right for ultimates/awakening, with an animated golden frame when ready.
- **HP/MP:** above the skill bar, or at the top-left as a portrait cluster. HP is red `#E0323C` with a darker trailing "damage taken" bar `#8A1A22`. MP is blue `#2F7BFF`. Both bars have a glossy top band and tick marks every 10%.
- **Target frame:** top centre, holo style.
- **Party/team frames:** left side.
- **Minimap:** a circular frame with a gold rim and compass ticks.
- Buffs sit above the player HP bar and debuffs on the row below, at 28–32 px.

### 6.3 Fonts (all OFL, so redistributable)
- **CN UI body:** *Noto Sans SC* / *Source Han Sans SC*.
- **CN titles / skill cut-ins:** *ZCOOL QingKe HuangYou* (blocky esports feel) or *Ma Shan Zheng* / *Zhi Mang Xing* (brush calligraphy for the logo, ultimates and the 荣耀 crest).
- **Latin/numerals:** *Rajdhani* or *Oxanium* (techy condensed) for the HUD and broadcast. *Cinzel* (serif) for fantasy item names.
- Damage numbers: *Oxanium Bold* or *Rajdhani Bold*, outlined.

---

## 7. ICONS (top priority: "so do the icons")

The current icons are a **coloured rounded square with a single CN character** (e.g. `ui/icons/status_burn.png` = 燃 on brown). This is the most visible "procedural / AI slop" tell. Replace all of them.

### 7.1 Chinese MMO skill-icon conventions (DNF, 剑网3, 天涯明月刀, 逆水寒, the 全职高手 mobile games)
- **Square, painted, illustrative.** Each icon is a **tiny painting** of the skill's *moment*: a lance thrusting with a shockwave, a cannon muzzle blast, a falling meteor, a dragon-tooth stab. It is not a symbol or a letter.
- **One subject, dynamic diagonal composition** (bottom-left to top-right), cropped tight, often breaking the frame edge.
- **High value contrast:** the brightest point (the energy core) sits near centre-right and the background corners are dark. Read the icon at 32 px with your eyes squinted.
- **Background colour = school/element**, as a radial glow behind the subject (see 5.2). Classes keep a consistent background family so players recognise them in the spectator view.
- **Frames:**
  - Normal skill: a thin bevelled **steel/silver** frame `#9AA6B8` with a 1 px inner dark line.
  - Ultimate / awakening (觉醒): a **gold ornate** frame `#D8B25A` with corner flourishes and a slow shimmer sweep.
  - Passive: a **round** icon with a bronze ring.
  - Silver/purple/orange rarity glows for items (white, green `#4FD86B`, blue `#3FA9FF`, purple `#A85CFF`, orange `#FF8A1F`, gold/银武 `#FFD86A`). These are for equipment icons only, not skills.
- **States:**
  - Cooldown: a dark 60% radial **clock sweep** with a **bright 1 px leading edge** and the remaining seconds in white, centred.
  - Ready: a white flash plus a 150 ms frame glow.
  - No MP: blue tint overlay.
  - Out of range: red tint.
  - Locked: grey desaturated with a chain glyph.
  - Queued/pressed: inner gold border, scaled to 92%.
- **Keybind:** bottom-right corner, small white text with a dark outline.

### 7.2 Status (buff/debuff) icon conventions
- **28–32 px rounded squares** (or circles for auras) with a **simple pictogram silhouette**, not a letter: flame, snowflake, broken shield, eye-with-slash for blind, droplet for bleed, chain for root, swirl stars for stun, up-arrow-sword for ATK up.
- **Frame encodes polarity:**
  - Buff: **green-gold** border `#7CD86B` → `#D8B25A`.
  - Debuff: **red** border `#E0323C`.
  - CC: **purple** border `#A85CFF`. CC must be visually loudest, and is also shown above the character's head.
- **Stack count** bottom-right. **Duration** is a clock sweep, plus blinking for the final 3 s.
- Pictograms use a 2-tone fill (light top, darker bottom), a 1 px dark outline and a soft inner glow in the element colour.

### 7.3 Production pipeline (license-safe, repo-friendly)
1. **Silhouette layer:** start from **game-icons.net** (CC BY 3.0, 4000+ SVG silhouettes; attribute each author in CREDITS) or draw originals. Never use official 全职高手/DNF icons.
2. **Offline compositor tool** (Python/PIL or a Godot `@tool` script under `tools/`; output PNGs are committed, nothing runs at runtime). For each icon, stack these layers:
   1. Radial-gradient background in the school/element colour, plus a **painterly noise/brush texture** (CC0 brush textures).
   2. A **light burst / speed-line / shockwave** layer chosen by skill tag (slash arc, cone, ring, beam).
   3. The silhouette, with an **internal vertical gradient** (light to dark), a **rim highlight** on the top-left edge, a **dark drop shadow** and an **outer glow** in the element colour.
   4. A **white-hot core spark** at the impact point.
   5. Vignette corners at 40% dark.
   6. Frame overlay (steel / gold / round passive).
3. **Hero icons hand-painted** (ultimates, 银武 weapons, class emblems): about 50 icons. Commission or self-paint at 256 px, then downscale.
4. Export at **128 px** (skill) and **64 px** (status), plus 2× for 4K. Use mipmaps off, and lossless for the UI atlas.
5. **QA test:** show all icons of one class at 32 px in a grid. Every icon must be distinguishable by **silhouette and composition alone, in greyscale**. If two read the same, redraw.

### 7.4 Class emblems
- 25 emblems: gold-on-navy crests with a stylised weapon silhouette per class inside a shield, diamond or crown shape. They are used on character select, the scoreboard and the account card.
- Emblem frames reuse the card frame language: a gold border, blue crystal side gems and a spiky sunburst base. The design must be our own, not the show's exact frame.

---

## 8. Master palette

### Characters
| Token | Hex | Use |
|---|---|---|
| skin_lit | `#F6DCCB` | skin base |
| skin_shadow | `#D9A08C` | skin shadow |
| skin_blush | `#E89A8C` | cheeks/nose |
| line_warm | `#2A1A14` | skin/hair outlines |
| line_cool | `#0B0E1F` | armour outlines |
| gold_trim | `#D8B25A` | filigree |
| gold_shadow | `#8A5A2B` | gold shade |
| silver_plate | `#C9D3DE` | plate armour |
| silver_shadow | `#7C88A0` | plate shade |
| navy_armor | `#1E2440` | dark plate / coats |
| scarf_red | `#C8202A` | Lord Grim scarf, Unspecialized accent |
| royal_blue | `#1F5FBF` | Blade Master cape |
| witch_blue | `#23379A` | Witch robe |
| launcher_yellow | `#F2C230` | Launcher |
| launcher_orange | `#F08A24` | Launcher accents |
| leather | `#6B3E22` | belts/boots |
| cloth_white | `#F2F0EA` | shirts/capes |
| cloth_white_shadow | `#A9B3D6` | cool shade on white |

### Environments
| Token | Hex | Use |
|---|---|---|
| sandstone | `#D9B98C` | town walls |
| sandstone_shadow | `#8A6E5A` | town shade |
| terracotta | `#B5583A` | roofs |
| sky_day | `#8EC3F0` | day sky |
| sky_horizon | `#E9F2F8` | haze |
| snow | `#F1F8FF` | snow lit |
| snow_shadow | `#8FC3DD` | snow shade (cyan) |
| maple_red | `#E0283A` | focal trees |
| canyon_rock | `#4A4E7A` | night rock |
| night_violet | `#3B2E7A` | night fill |
| ruin_amber | `#FFB45C` | golden-hour key |
| dust_haze | `#C99A6A` | desert atmosphere |
| foliage_lit | `#8CC56A` | foliage |
| foliage_shadow | `#2E5A4A` | foliage core (teal-shifted) |
| dungeon_teal | `#1F4F4A` | cave ambient |

### UI
| Token | Hex | Use |
|---|---|---|
| ui_panel | `#0E1A2A` (85–92%) | panels |
| ui_holo | `#141820` (70%) | holo overlays |
| ui_line_cyan | `#4FD8FF` | holo lines |
| ui_gold | `#D8B25A` | frames |
| ui_gold_hi | `#FFE9A8` | gold highlight |
| ui_crystal | `#3FA9FF` | gems/accents |
| ui_text | `#F4F6FA` | text |
| ui_text_dim | `#9AA6B8` | secondary text |
| hp | `#E0323C` / `#8A1A22` | HP / trailing damage |
| mp | `#2F7BFF` | MP |
| buff | `#7CD86B` | buff frame |
| debuff | `#E0323C` | debuff frame |
| cc | `#A85CFF` | CC frame |
| crit | `#FFC43A` | crit numbers |
| team_blue / team_red | `#2F7BFF` / `#FF3B4A` | teams |
| broadcast_neon | `#C23BFF` → `#FF3B8A` | league broadcast |

---

## 9. DO / DON'T: targeting the current build's AI-slop failure modes

| Failure mode now | DON'T | DO |
|---|---|---|
| **Chibi proportions** (KayKit) | 2.5-head bodies, giant heads, stubby limbs | 7.5–8 heads, long legs, slim faces, big shoulders on armour, flowing secondary-motion cloth |
| **Uniform lighting** | One flat ambient, no shadows, everything equally lit | One strong key per zone, tinted ambient, SSAO, fog and aerial perspective, god rays, light used to guide the player |
| **Generic grey dungeon tiles** | Untinted modular grey blocks on a flat grid | Zone palettes, hand-painted albedo, decals, height variation every 10–15 m, landmarks, edge clutter, terrain blending |
| **Flat colours on characters** | Single-colour materials, black or no shadow, black outlines | 2-band toon with **tinted** shadows, rim light, 1.6 px coloured outlines, gold filigree trim, hair specular streaks |
| **Procedural letter icons** (燃, 盲, etc.) | A CN glyph on a gradient square; the same shape for every skill | Painted illustrative skill icons, pictogram status icons, frames encoding type/polarity, cooldown sweep, a greyscale readability test |
| **Emoji-like VFX** | Small round sprites, single colour, uniform scale, no timing | Big crescent arcs, glyph circles, white HDR cores with bloom, painted debris and dust, anticipation, impact frames and hit-stop |
| **Asset-flip randomness** | Mixing art styles and props from unrelated packs | Restyle every import through the same shader and palette; reject assets that can't be made to match |
| **Generic UI** (Kenney beige panels, `iconCheck_beige.png`) | Light beige flat buttons, default Godot theme | Navy glass, gold filigree, crystal gems, holo overlays, OFL CN fonts, angled broadcast plates |
| **No hero silhouette** | Characters differ only by tint | Each class has one huge silhouette element (scarf, cape, hat, cannon, umbrella) readable at 32 px of height |
| **Static world** | No motion except characters | Wind on foliage and cloth, drifting motes, falling snow, banners, idle VFX on weapons |
| **Over-bloom / over-saturation** | Everything glowing, neon fog | Bloom only on VFX, weapons and rims; saturation 1.1–1.2; keep the floor mid-value and readable |
| **Copying the show** | Ripping screenshots, official logos or exact card frames | Original designs that rhyme with the show; the reference folder is never committed |

---

## 10. Asset acceptance checklist (every asset PR)
- [ ] The license is CC0, CC-BY, MIT, OFL or explicitly allows redistribution. Source URL, author and attribution are in `assets/CREDITS.md`, and the license text is in `assets/licenses/`.
- [ ] It uses the zone or class palette tokens (no off-palette colours above 5% of the area).
- [ ] Characters use the toon shader: tinted shadows, coloured outline, rim.
- [ ] It reads in greyscale at gameplay distance (silhouette test).
- [ ] VFX: white core plus at most 2 colours, anticipation, an impact frame, and the hit-stop value set.
- [ ] Icons: the 32 px greyscale test passes, the frame type is correct, and there is no text glyph as the subject.
- [ ] Nothing from `scratchpad/art/ref/` is included.

---

### Sources consulted
- the-kings-avatar.fandom.com (image uploads of donghua screenshots and official character cards; API listing used to locate them)
- 萌娘百科 entries: 荣耀, 君莫笑, 全职高手 (world setting: Glory is a 3D action MMO with Diablo-like worldview and DNF-derived classes, the 神之领域 zone, server structure)
- Wikipedia: *The King's Avatar (2019 TV series)* (studio/season context), Anime News Network beginner's guide (S1 studio context)
- game-icons.net (CC BY 3.0) and Google Fonts OFL families are named as pipeline candidates. Re-verify the licenses when you download them.
- Gaps: no reliable published source documents the show's in-game HUD (skill bar, HP bars). Section 6 is derived from the official card frames, the in-show account-info overlay, the S3 key visual and Chinese MMO genre conventions.
