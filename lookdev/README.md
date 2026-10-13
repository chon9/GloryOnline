# RONGYAO look-dev vertical slice

This scene tests the Art Bible v1 direction for a 全职高手 / Glory donghua look before we convert the whole game. It shows:

- **Three anime fighters**, each with its signature weapon:
  - Battle Mage 战斗法师 (一叶之秋 type) with the 却邪-style battle lance
  - Launcher 枪炮师 (沐雨橙风 type) with a brass hand cannon
  - Witch 魔道学者 (王不留行 type) with a crowned hat and a star-dust broom
- **A Frost Forest pro-league arena** (冰霜森林 · 竞技场)
- **Skill VFX** for three skills, with an impact frame and hit-stop
- **The new HUD**, using the newly generated icons

It is self-contained. Nothing in `core/`, `visuals/`, `ui/` or `classes/` was changed, and no addon was installed.

```
godot --path . res://lookdev/lookdev.tscn                      # live; keys 1-5 switch views, Space = VFX + hit-stop, H = HUD
godot --path . res://lookdev/lookdev.tscn -- --view=<v> --shot=<png>   # v = wide | gameplay | close | vfx | hud | perf
godot --path . res://lookdev/lookdev.tscn -- --view=clips --cls=launcher "--clips=Pistol_Shoot@0.1,Idle_A@0.5"   # pose contact sheet
```

Shot mode makes the window borderless at exactly 1920x1080 (a decorated window gets clipped by the taskbar). Use the non-headless console exe.

## Iteration 4 (art-director fixes, 5/10 review: icons)

**Painted icon rendering (P1).** I rewrote the painter's rendering core (`ICON_STYLE.md` v2, section 2):
- **Lines** are tapered distance-field contours: thick on the shadow side, thin and broken on the lit side, and coloured per material.
- **Shading** gives every material 4 values from pseudo-normals, with brush-wobbled band edges and a gradient toward the light.
- **Material cues**:
  - lacquer has gloss hotspots
  - gold has a warm-to-white specular
  - the steel blade has brushed streaks, a broken spec streak and a honed edge
- **Light shapes** have a soft painted falloff with no hard edge.
- **Grounds** get low-contrast dry-brush washes.
- **Check:** I compared the icons at 64 px against real 剑网3 skill icons in an internal sheet. The references stay in the scratchpad and are never committed. The new set holds up next to them instead of reading as clip-art.

**Lance (P1).** The icon lance now matches lookdev_3:
- The blade is 2x longer and slimmer, with a back hook and fine forward-raked serrations instead of a sawtooth.
- The gem is a glowing orb with a radial bloom and an off-centre hot core.
- There is no white ring and no dark centre, and two prongs cup the orb from below, so it no longer reads as an eye.

**The lance appears in 4 of the 8 icons (P1):** 突刺, 天击, 怒龙穿心 and 伏龙翔天.
- The other four show the action alone: 圆舞棍 is the swing arc, 龙牙 the jaws, 落花掌 the hand and 豪龙破军 the dragon charge.
- The QA sheet gains a squint row (24 px, blurred), and the run writes a numbered naming sheet.

**突刺, 落花掌 and 圆舞棍 were redrawn (P1).** See the bar table under Pipeline 3.

**Dragons (P2):**
- The snout is 1.35x longer.
- The fangs are narrow, curved and drawn in bone material.
- Antlers, whiskers, brow and mane are tapered strokes.
- The head has 3-value planar shading, and the neck has rows of scales.
- 怒龙穿心 now sits on an ink ground.
- 伏龙翔天's head is pulled inside the frame and sits on an ink-to-crimson ground.
- The ultimate frame no longer has L-bracket corners. The shared corner ornament, also used in the HUD, is now two tapered horns and a bead.

**Fragments (P2).** The stamped black chevrons are gone:
- `plate_fragment` draws a curved plate with a gold-trimmed edge, a visible thickness side, a lit edge and a glowing break.
- `stone_chip` draws angular stone with a hot rim.
- 天击's trapezoid slabs are now a soft volumetric column with god rays and motes.

**Status icons (P2):**
- 灼烧 is a cracked plate with ember cracks and flames licking up from them.
- 减速 is a frost-bound hourglass.
- 攻击提升 is an up-arrow blade on crimson and 霸体 a full breastplate on gold, so the two separate at 28 px.
- Every status icon, including 加速, uses the same neutral ink ground.
- 眩晕 drops the swallows for three gold stars.
- Status icons now have their own SSIM gate (max pair 0.381) and a 28 px greyscale row in the QA sheet.

**Skill bar (P2):**
- Cooldowns show whole seconds only. In the last 3 s a gold fill bar empties.
- The cooldown copy is neutral grey.
- The blue-violet Q slot was the No-MP state, not a cooldown. It now keeps the icon in colour and adds a blue inner border and a crossed-out MP droplet, so it can't be mistaken for a cooldown.

**Process (P3).** `ICON_STYLE.md` 6.2 makes human naming the sign-off gate: 2-3 players from the community, at least 7 of 8 correct each, with a results table. **This test has not been run yet.**

**Debris (P3).** The debris chips in lookdev_4 are now flat-shaded angular stone shards (`LdVfx._shard_mesh`) in dark violet-grey with a hot orange rim. They replace the rounded brown lumps.

**Not addressed in this pass** (P3, deliberately left until the icons are signed off):
- The characters are still re-dressed VRoid bases. The Launcher's white sundress is the most visible case.
- The environment props are still flat-lit primitives.

## Iteration 3 (art-director fixes, 5/10 review)

- **Icons: one class key.** All 8 Battle Mage icons now use one palette: ink ground, gold light and the crimson 却邪 gem accent. Skill tones stay within gold, crimson, ember and ember-white. The ultimate's dragon has the only cool light on the bar, an ice-cyan back rim. Skills are told apart by composition and value, not by hue. The palette lives in `CLASS_KEYS` in the painter.
- **No stick figures.**
  - 天击 shows the lance driving up out of the frame into a shattering gold-trimmed breastplate.
  - 怒龙穿心 runs the lance through a breastplate shard, and the dragon erupts out of the far side.
  - 霸体 is now a gold breastplate emblem in flame armour.
- **Dragons redesigned as Chinese 龙.**
  - The head has deer antlers, a scowling brow over a slit-pupil eye, an open maw with fangs and breath-light inside (no front teeth), whiskers, a beard, jaw fins and a flame mane. It has planar shading: a lit forehead and snout plane, and a shadowed cheek and jaw.
  - The body is an S-curve of additive light with a white-hot core, and it splits into diverging qi streaks toward the tail.
  - The claws have four toes.
  - Each of the three dragon skills uses a different view: 3/4 lunge, side-on charge, and rising seen from below.
- **Grounds.** The noise, grain and brush streaks are gone. Each ground is 2-3 flat value masses plus one smooth falloff toward one white-hot focal point.
- **突刺** is now a true head-on thrust: a faceted diamond blade tip with converging red fullers, the claw-and-gem collar behind it, a shock ring and six big burst spikes.
- **落花掌** shows an articulated 一叶之秋 gauntlet: black lacquer finger plates, gold joint trim, gold claw caps and a filigree vambrace. It has a plum (梅) sigil and plum petals with varied size, rotation and blur, plus a shock ring from the palm.
- **Lance fidelity.** The icon lance now matches the model: gold collar bands, red fuller line, three claw prongs cupping the gem, a serrated back edge and a crimson tassel.
- **Status icons** use the same painted-light grounds as the skills, inside thin metallic polarity bevels.
  - 眩晕 shows stars and swallows circling a glowing spiral.
  - 加速 is a swept wing of light.
- **Automated 32 px check.** The painter downsizes every skill icon to 32 px greyscale and computes pairwise SSIM. It fails the run if any pair scores above 0.60. The current bar's highest pair is 0.19.
- **Style sheet.** `ICON_STYLE.md` (one page) covers the palette key, light direction, value plan, banned elements, frames and HUD states.
- **Skill bar.**
  - Cooldowns use a clockwise radial wipe over a 45%-value, desaturated copy of the icon, with a bright edge tick.
  - Cooldown numbers are Teko Bold at about 40% of slot height with a 2 px outline, and show no decimals above 3 s.
  - A gold ready flash appears on the frame.
  - The pressed state is a chamfered gold stroke with an inner glow and a 1.5 px inset. The icon no longer shrinks and the square bevel is gone.
- **Ultimate.**
  - 觉醒 is on a gold ribbon above the frame. The MP bar now stops before the ultimate slot.
  - The ultimate frame's corners use the same ornament geometry as the HUD panels, and its crystal is the HUD's diamond gem.
- **Status stacks** use a big outlined digit in the bottom-right corner.
- **VFX.**
  - The alpha-scissor flame "stickers" are replaced by layered additive radial fire with a white-hot core and additive-only tongues.
  - The white dust pillows are gone. The rock chips are dark, fire-lit and carry ember streaks, and dark ground-smoke sprites have been added.
  - The callout band takes the skill's class tone (gold).

## Iteration 2 (art-director fixes)

- **Icons, rebuilt from scratch.** game-icons.net is gone. All 8 Battle Mage skill icons are original compositions built around the 却邪 lance in the action each skill names. They are cel-shaded with a hard rim and additive glow, like the characters, and each has a different camera and crop.
- **Icon frames and colours.** New frames: a navy/silver skill bevel, and a navy-glass, gold-filigree ultimate frame with one blue crystal. Physical skills are now warm white-gold, so the bar has only 2 blue icons.
- **Status icons.** Diamond/hex-style badges replace the emoji pictograms. The type is encoded by shape (round buff, down-pointed shield debuff, hex CC).
- **Skill bar.**
  - Cooldown text is small and thin over a clipped radial sweep. The stray diagonal lines were cooldown-edge segments drawn outside the slot; that is fixed.
  - Keybinds sit in a fixed tab on the frame's bottom edge.
  - The pressed state is a gold inner glow.
- **HUD text.**
  - CN-first labels; the English techno text, tool path and licence line are gone.
  - The crit-number strike was the taken-damage number drawn behind it; it has moved.
  - The HP label overlap is fixed.
- **Characters.**
  - The lance has a 1.6x modelled head (serrated blade, back hook, red gem in 3 claw prongs, energy fuller), a silver butt spike and a crimson tassel, and is held mid-shaft.
  - A two-hand aim constraint runs the shaft through the left palm.
  - The Launcher has a white blouse, leather lace-up corset, yellow capelet, orange bustle, knee boots, thigh straps and goggles.
- **Environment.**
  - Depth of field per view, plus a matte-painted backdrop.
  - Warm/cool stone with dry-brush strokes.
  - The red maple has layered painted leaf cards over dark core masses.
  - Team banners carry an original crest, gold double trim and swallow-tail cut.
- **VFX.** The cannon blast uses painted cel flame tongues with additive HDR halos and warm, fire-lit debris chips with streaks, replacing the flat puffs and grey cubes.

## Files

| Path | What it is |
|---|---|
| `lookdev.tscn`, `lookdev.gd` | Scene root, the camera views, screenshot mode and perf mode |
| `scripts/anime_character.gd` | `LdCharacter`. Loads a converted VRoid base, swaps its materials for the toon and outline shaders (with per-material recolour), shares one retargeted animation library, attaches costume and weapon pieces to humanoid bones, and drives VRM spring chains (hair, skirts) through Godot's `SpringBoneSimulator3D` |
| `scripts/classes.gd` | `LdClasses`. The per-class "dress": base model, recolour maps, procedural costume (coat tails, pauldrons, collar, robe, mantle, crowned hat, goggles, belts), clips, and grip transforms |
| `scripts/weapons.gd` | `LdWeapons`. Lance, cannon and broom. Same ids and grip convention as `visuals/weapon_factory.gd` (`battle_lance`, `hand_cannon`, `broom`), but with real silhouettes (extruded blade profiles, lathed barrels), toon materials and HDR accents |
| `scripts/gear.gd` | `LdGear`. Mesh builders (lathe, extrude, ribbon, tube), toon material factory, and the bible's shadow-tint rule |
| `scripts/environment.gd` | `LdEnvironment`. Fully procedural Frost Forest arena: terrain, rune arena, red-maple landmark, Gothic ruin, forest, pines, ice clusters, banners, mountains, snow and motes, sky, fog, grading |
| `scripts/vfx.gd` | `LdVfx`. Crescent slash with echo arcs, cannon blast (muzzle, beam, cel fire puffs, shockwave, streak burst, debris, dust), witch glyph circles and star bolts, impact frame, and the live hit-stop sequence |
| `scripts/hud.gd`, `scripts/hud_widget.gd` | `LdHud`. Navy-glass and gold HUD: player and teammate frames, live 3D portrait, holo target frame, skill bar with cooldown sweep and states, status icons, minimap, kill feed, combo counter, damage numbers, brush-calligraphy callout, and the icon design board |
| `shaders/toon.gdshader` | Character toon shader: 2-band diffuse, tinted shadow, fresnel rim, recolour (gradient map or hue swap) |
| `shaders/toon_outline.gdshader` | Inverted-hull outline with constant screen-space width (1.6 px at 1080p, thinner at distance), coloured from the albedo, never black |
| `shaders/painted_env.gdshader`, `arena_floor.gdshader`, `anime_sky.gdshader` | Painted environment look: noise-painted albedo, slope snow, strata and ashlar blocks, cyan-tinted shadows, rune floor, anime cumulus sky |
| `shaders/vfx_*.gdshader`, `screen_impact.gdshader` | Cel-banded slash and energy, rotating glyph circle, shockwave and ray burst, impact frame |
| `tools/vrm2glb.py` | VRM 0.x to slim glTF converter (Python with PIL; reads data only) |
| `tools/patch_import.py` | Writes the retarget import settings into a `.glb.import` |
| `tools/make_bonemaps.gd` | Generates `assets/retarget/vroid.tres` and `m2m.tres` |
| `tools/icon_painter.py` | Offline icon renderer v2 (spec: `assets/icons/icons.json`). It has a painted rendering core (tapered distance-field lines, material shading with 3+ values, soft light, brush-wash grounds) and per-class palette keys. All subjects are original and drawn in code: the 却邪 lance, the Chinese dragon head, body and claw, the open-palm gauntlet, blossoms, plate fragments and stone chips. Frames and badges are owned by the generator. It also writes the QA sheet with a squint row, the naming sheet, and runs the SSIM gates. |
| `ICON_STYLE.md` | One-page icon style sheet: the sign-off rules for all ~225 icons |
| `tools/paint_textures.py` | Paints the small original textures in `assets/textures/` (maple leaf cards, team banners with crest and gold trim, fire tongue sprite) with the same primitives |
| `shaders/painted_backdrop.gdshader` | Matte-painted distant mountain ranges on a far cylinder (aerial perspective without geometry) |
| `tools/probe_*.gd` | Debug probes: node tree, materials, bone axes, hand axes per pose |
| `assets/LICENSES.md` | Source, licence and attribution for every third-party file |

## Pipeline

### 1. Import a new character

1. Choose a base. Only use CC0 or redistributable VRM files, and check the embedded meta (see `LICENSES.md`). The current bases are the VRoid CC0 alpha samples: 3 male and 8 female.
2. Convert it:
   ```
   python -I lookdev/tools/vrm2glb.py <in.vrm> lookdev/assets/chars/<name>.glb [max_tex=1024]
   ```
   This drops the normal, matcap, thumbnail and outline textures, downsizes the rest, merges primitives (VRoid hair goes from 114 surfaces to 1 draw call), adds a 180-degree facing fix (VRM 0.x faces -Z), and writes `<name>.vrm.json` with the humanoid and spring data. Each file ends up at about 6-8 MB.
3. Run `godot --headless --path . --import` once. Then add the retarget settings and reimport:
   ```
   python -I lookdev/tools/patch_import.py lookdev/assets/chars/<name>.glb.import VRM0_FacingFix/Skeleton3D vroid.tres
   rm .godot/imported/<name>*        # forces Godot to reimport with the new parameters
   godot --headless --path . --import
   ```
   The skeleton becomes `GeneralSkeleton`, using SkeletonProfileHumanoid names with rest-fixer and overwrite-axis. Textures stay embedded (`embedded_image_handling=3`).
4. Add a dress entry in `classes.gd`:
   - `model`
   - `dress`: material-name substring mapped to one of `map` (gradient-map dark/mid/light), `hue` (hue swap), `mul`, `shade`, `iris`, `hide`
   - `build` callable: costume pieces authored in character space at the T-pose, plus the weapon through `grip_xf()` (melee or pole) or `gun_xf()` (firearms)
   - clips

   To pick poses, use `--view=clips`.

### 2. Retarget animations

Every clip library is imported once with `retarget/m2m.tres`. `LdCharacter.anim_library()` merges them into one shared `AnimationLibrary`, re-paths the tracks to `GeneralSkeleton:<bone>`, and strips root motion (the `Root` bone).

Because source and target share SkeletonProfileHumanoid, any humanoid clip pack works:
- Mesh2Motion (178 clips; 2 GLBs, 11 MB, committed here)
- Quaternius UAL
- KayKit (already in the repo)

For a new pack, make a BoneMap in `tools/make_bonemaps.gd`, then patch its `.import` with `patch_import.py <file> Armature/Skeleton3D <map>.tres`.

Leg-length and head-scale proportion tweaks are bone pose scales (`LdClasses._proportions`). Clips only carry rotations, so the scales survive playback.

### 3. Make icons

Icons are drawn in code; no stock silhouettes are used anywhere. Read `ICON_STYLE.md` first: it holds the rules every icon must pass.

```
python -I lookdev/tools/icon_painter.py [spec.json] [out_dir] [qa_sheet.png] [only_ids,comma,separated]
```

- A full Battle Mage run (8 skills and 7 status icons) takes about 2 minutes. Rendering is supersampled 4x with numpy and Pillow. No scipy is needed: distance fields are chamfer-propagated inside a cropped box.
- Output: skill icons at 128 px plus `@2x`; status icons at 64 px plus `@2x`.
- Each run prints the 32 px greyscale SSIM matrices, one for skills and one for status icons. A full run exits with code 2 if any pair scores above 0.60.
- The QA sheet adds a squint row: skills at 24 px blurred, status icons at 28 px greyscale. The run also writes `<qa>_naming.png` for the human naming test.
- The naming test is the real sign-off gate: every tester must name at least 7 of 8 icons correctly. See `ICON_STYLE.md` 6.2.

**What the generator owns** (shared by every class):
- `CLASS_KEYS`: one palette key per class (ink, warm ink, class metal, accent, 3-4 warm skill tones, 1 cool accent for the ultimate)
- the painted rendering core:
  - `ink_line`: a tapered contour, thick on the shadow side, thin and broken on the lit side, coloured per material
  - `paint_form`: 3-5 values from distance-field pseudo-normals, brush-wobbled band edges, a gradient toward the light, and specular layers
  - `material`: named materials (`MAT`):
    - lacquer with gloss hotspots
    - gold with a warm-to-white specular
    - brushed steel
    - plate, leather, cloth, bone, petal, stone and glass
  - `soft_light` / `light_form`: light with a feathered painted falloff, or light painted as a solid 4-value form
  - `ground` + `brush_wash`: value masses, low-contrast dry-brush strokes, a focal falloff and a vignette
- frames:
  - normal skill: navy/silver bevel
  - ultimate: gold, using the HUD's own corner ornament (tapered horns and a bead, no L bracket) and diamond crystal
  - passive: bronze ring
- status badges: one neutral ink ground for all, with a light mass in the element colour, inside a thin polarity bevel
- the QA sheet, the naming sheet and the SSIM gates

**Asset library** (reuse it across classes):
- `draw_lance`: 却邪 (`lance_geom`), matching `LdWeapons`.
  - The blade is long and slim, with a back hook and fine serrations.
  - Two prongs cup a glowing orb.
  - Draw it affine (`lance_H`) or foreshortened (`lance_persp`).
- Dragon parts, drawn in any view through a homography (`H_affine` or `H_quad`):
  - `dragon_head`: long 龙 snout, curved bone fangs, planar shading
  - `dragon_body`: a painted coil with scale rows on the neck and a qi-streak tail
  - `dragon_claw`
- Other pieces: `gauntlet_palm`, `plate_fragment`, `stone_chip`, `petal`, `blossom`, `shock_ring`, `flare_spikes`, `light_streak`, `hot_core`

**To add a class:**
1. Add its `CLASS_KEYS` entry.
2. Write its weapon asset once, matching its 3D model. The weapon may appear in at most half the bar.
3. Write one `comp_` function per skill. Each one gets a different big value shape (see the style sheet).
4. Add rows to the spec and render.
5. The set must pass the SSIM gates and the squint row, then the human naming test.

**Battle Mage bar (iteration 4).** The lance appears in 4 of the 8 icons.

| Slot | Skill | Composition (value shape) | Tone |
|---|---|---|---|
| LMB | 突刺 | 3/4 forward thrust with the blade foreshortened toward the viewer; a cone of speed lines converging on the point; a vapour cone; air-pierce shock rings at the tip (diagonal into a ring) | ember-white |
| 1 | 天击 | the lance drives up into a soft volumetric light column with god-ray streaks and rising motes; curved gold-trimmed plate fragments fly out (vertical) | gold |
| 2 | 龙牙 | the jaws alone: upper and lower dragon jaws of ember light with scale rows and gum ridges; narrow curved bone fangs snapping shut on one hot point (horizontal jaw) | ember |
| 3 | 落花掌 | an open palm thrust at the viewer in 3/4 view: splayed fingers of different lengths with knuckle breaks, a clear thumb, small gold claw tips and a blazing palm centre; notched blossoms with stamen clusters; petals streaming outward with trails (dark hand mass) | crimson |
| 4 | 圆舞棍 | the swing arc alone: a 300-degree crescent smear seen at an angle, thick and white-hot at the leading edge, dissolving into streaks at the tail; angular stone debris flung outward; a dust ring on the ground (ring) | gold |
| Q | 怒龙穿心 | on an ink ground, the lance runs through a plate fragment and a crimson dragon head in 3/4 view lunges out of the far side (diagonal) | crimson |
| E | 豪龙破军 | no lance: a side-on charging dragon with a long snout, a raking claw and a qi-streak tail; plate armour bursts ahead of it (horizontal profile) | ember |
| R | 伏龙翔天 | seen from below, a gold dragon spirals up the vertical lance on an ink-to-crimson ground; its head sits inside the frame with margin; ice-cyan rim (vertical S) | gold + the bar's one cool accent |

**Status icons** (all on the same neutral ink ground):

| Icon | Badge | Subject |
|---|---|---|
| 攻击提升 | round, green-gold | a steel up-arrow blade on crimson light, with a gold guard and rising streaks |
| 加速 | round, green-gold | a swept teal wing of light with speed streaks |
| 霸体 | round, green-gold | a full gold breastplate: shoulders, lacquer gorget, pectoral lines, centre ridge, red gem |
| 灼烧 | shield, red | a cracked dark plate with ember-hot cracks and small flames licking up out of them |
| 破防 | shield, red | a split steel shield leaking red light |
| 减速 | shield, red | a frost-bound hourglass: gold frame, ice-blue sand frozen mid-fall, ice shards and rime on the frame |
| 眩晕 | hex, purple | three gold stars circling a glowing spiral |

## Performance

Measured with `--view=perf`, which rebuilds the full VFX frame about 8 times a second. Run it with `--disable-vsync`:

```
godot --disable-vsync --path . res://lookdev/lookdev.tscn -- --view=perf --quit=1
```

With vsync on and the display idle or locked, Windows throttles presentation to about 20 FPS, which says nothing about the scene.

Setup: RTX 3080, Godot 4.7.2 Forward+, 1920x1080.

| Scene | Avg FPS | Render CPU | GPU | Draw calls | Primitives |
|---|---|---|---|---|---|
| 3 characters + all VFX + HUD + full Frost Forest environment (SSAO, volumetric fog, glow, DOF, 4-split shadows, 2,600 snow particles, painted backdrop, maple leaf cards), iteration 4 | **414** | 0.77 ms | 1.76 ms | 2,165 | 2.28 M |

Cost notes:
- **Draw calls.** Each toon surface draws twice (body plus outline), so a character costs about 30 draw calls. Most of the environment's draw calls come from unique procedural meshes (≈70 trees, ≈60 rocks and props). Before the full game, merge static props per zone (one mesh per material) or use MultiMesh, as the pines already do.
- **Characters.** A character is 25k-40k triangles and 6-8 MB with 1024 px textures. With 10 players plus mobs, cut textures to 512 px and use the LOD meshes the importer generates (`meshes/generate_lods=true`).
- **Spring bones.** Hair and skirt chains run in `SpringBoneSimulator3D`, about 10-16 chains per character. In a 10-player match, disable them beyond 25 m.

## Migration plan (full game)

The current game: 25 classes, 4 PvP maps, 2 PvE dungeons, about 200 skill icons and about 25 status icons. Gameplay code is untouched. Every step swaps visuals behind existing ids.

1. **Shaders and grading first (1-2 days).** Move `toon`, `toon_outline` and `painted_env` into `visuals/shaders/`. Give every map a WorldEnvironment preset modelled on `LdEnvironment._atmosphere` (one key light, a tinted sky ambient, fog, glow, saturation 1.2), with one preset per zone LUT from bible 4.2. On its own this removes the "flat grey" look.
2. **Characters (2-4 weeks).**
   - Replace KayKit bodies in `visuals/character_visual.gd` with an `LdCharacter`-style loader keyed by class id. Keep the `CharacterVisual` API: `replay(key)`, `set_weapon()`, `set_status_visual()`.
   - Map `CharacterVisual.ANIM_MAP` keys to Mesh2Motion clips. Example: `attack_stab` → `Sword_Regular_A`, `attack_2h` → `Sword_Regular_C`, `cast` → `Spell_Simple_Shoot`, `shoot_1h` → `Pistol_Shoot`, `run` → `Run_Anime`, `launch` → `Land_Three_Point` / `Backflip`.
   - Keep the KayKit clips as fallbacks for 2H spin and dual-wield. They use the same humanoid profile after a BoneMap.
   - Build bases: 3 male and 8 female CC0 VRoid bases. Use recolour maps plus per-class costume builders (one `_xxx_build` per class, about 150 lines each, from the bible 2.5 table). Mobs and bosses can keep KayKit meshes, but must use the toon shader and zone palettes.
   - Long term: author our own VRoid Studio bases. First confirm the built-in preset licence (see the research notes). Never use BOOTH items.
3. **Weapons (1 week).** Port `LdWeapons` into `visuals/weapon_factory.gd` per id. The grip convention matches. Add 千机伞 forms (lance, gun, shield) as animated canopy panels.
4. **Maps (1 week per map).** Re-dress each map with the `LdEnvironment` toolkit:
   - painted materials
   - landmark plus 2-3 secondaries
   - +1.5 m height change every 10-15 m
   - edge clutter and motes
   - one palette per zone

   Arena maps reuse the rune floor and plinth. Dungeons use Spider Cave (teal/torch) and Frost (this slice).
5. **VFX (1-2 weeks).** Map `autoload/fx.gd` effect names onto `LdVfx` builders:
   - `slash_arc` → crescent
   - `explosion` and `fire_burst` → cel fire puffs and shockwave
   - `cast_glow` and `summon_circle` → glyph
   - `ultimate_flash` → impact frame

   Then hook hit-stop into hit events: 3, 5, 8 or 12 frames per the bible.
6. **Icons (about 3-4 weeks for ~225, after the Battle Mage set is signed off).**
   - Sign off the 8 Battle Mage icons against `ICON_STYLE.md` first. Scaling a set that has not been approved repeats its problems 200 times.
   - Add one `CLASS_KEYS` entry per class, about 25 in total.
   - Write one weapon asset per class family: lance, umbrella, greatsword, cannon, tome, etc. That is about 20 assets, at roughly half a day each.
   - Write one `comp_` function per skill. That is about 200, at 20-40 minutes each, reusing the dragon, gauntlet, shard, petal and light library.
   - Status effects (~25) need only a subject function plus their kind; the badge comes from the generator.
   - Bake, replace `ui/icons/*.png` by id, and keep the SSIM gate (≤ 0.60) in the bake script so a regression fails the build.
   - Optionally, an illustrator can paint over the 256 px masters of the ~50 hero icons (ultimates, class emblems) later.
7. **HUD (1 week).** Rebuild `ui/` from `LdHudWidget` drawing:
   - frames, bars, slots and minimap
   - fonts: Noto Sans SC, Ma Shan Zheng, Teko, Russo One, Orbitron
   - damage numbers to bible 5.5

   Hook the cooldown sweep, stacks and durations into existing data.
8. **Licensing.** Merge `lookdev/assets/LICENSES.md` into `assets/CREDITS.md`. The icons and textures are original and carry no attribution duty; the VRoid and Mesh2Motion credits are optional; the fonts need their OFL.txt files. Before the fonts go into a release build, subset them and rename the subsets, or ship them unmodified.

## Known gaps

- Battle Mage, Witch and Launcher are re-dressed CC0 school-uniform bases. Their shapes are still VRoid moe; faces are rounder than the sharper 国漫 style. Custom bases are the long-term fix.
- The 千机伞 umbrella and the other 22 classes are not built yet.
- Mesh2Motion has no spear or cannon clips. Sword and pistol clips stand in, and some hand-to-weapon contact is approximate. A few authored spear clips would lift the Battle Mage a lot.
- Hair uses the VRoid painted textures. The bible's anisotropic hair highlight and face SDF shadow are not implemented; faces use a shifted terminator instead.
- The environment is fully procedural. It reads well at gameplay distance, but close-up props are simple. Swapping in CC0 kits (Quaternius MegaKits), restyled through `painted_env`, is the next step.
- The two-hand lance constraint (`LdCharacter.enable_two_hand`) aims the shaft through the left palm when that hand is near the shaft line. It is an aim constraint, not finger IK, so fists sit on the shaft rather than wrapping it.
- The Launcher costume (corset, capelet, bustle, boots, goggles) is built from procedural pieces over the recoloured CC0 dress. A custom base mesh would make the silhouette cleaner.
