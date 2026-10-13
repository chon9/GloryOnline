# Icon style sheet v2 (sign-off gate for all ~225 icons)

Generator: `lookdev/tools/icon_painter.py`. Spec: `lookdev/assets/icons/icons.json`. Reference set: the 8 Battle Mage skills and 7 status icons in `assets/icons/out/`. Do not start a second class until the Battle Mage set passes the human naming gate (section 6.2).

v2 replaces v1's flat 2-tone fills and single-width outlines (which read as vector clip-art) with **painted rendering**.

## 1. Per-class palette key

Every class gets one entry in `CLASS_KEYS`. **Every icon of a class uses only its key**, so a bar reads as one set.

| Slot | Role | Battle Mage (一叶之秋) |
|---|---|---|
| `ink` | ground, the darkest value | `#09080C` |
| `ink_warm` | ground near the bottom, warm dark masses | `#1B120F` |
| `metal` / `metal_hi` / `metal_sh` | class metal: collars, trim, frames | gold `#D8B25A` / `#FFE9A8` / `#8A5A2B` |
| `accent` / `accent_dk` | one signature accent | crimson gem `#D2283A` / `#4A0810` |
| `tones` | per-skill light, **all inside the key** | gold, crimson, ember, ember-white |
| `cool` | at most **one** cool accent per bar, ultimate only | ice-cyan `#7FE8FF` (rim on the 伏龙翔天 dragon) |

Skills are told apart by **composition and value**, not by hue. Status icons are a cross-class family and use `STATUS_PAL`, because their element colour carries meaning.

## 2. Painted rendering (the v2 core, in the painter's "PAINTED RENDERING CORE" section)

- **Line (`ink_line`)**: a distance-field contour whose width varies with the side. It is thick (about 2-2.6 px at 256) on the shadow side (bottom-right) and thin (0.3-0.5 px) on the lit side, where it is also **broken** in places, like a brush lifting off. Lines are coloured per material: oxblood on petals, warm brown on gold, navy on steel. Never pure black, and never one uniform width.
- **Form (`paint_form`)**: at least **3 values per material** (the ramps hold 4). Shading comes from pseudo-normals built on the shape's inner distance field. Band edges are soft and wobbled by low-frequency noise so they read as brush edges, and a value gradient runs across each form toward the key light.
- **Material cues (`MAT`)**:
  - **lacquer** (the 却邪 shaft, gauntlet plates): near-black ramp, a broad cool sheen, and hard **gloss hotspots**.
  - **gold**: a brown-to-gold ramp with a **warm-to-white specular** (a wide warm highlight, then a hard white core).
  - **steel** (blade): **brushed streaks** along the blade axis (`streak_field`), a sharp broken spec streak beside the ridge, and a honed edge line.
  - **plate, darksteel, leather, cloth, bone, petal, stone, glass** follow the same scheme.
- **Light (`soft_light`, `light_form`)**: light shapes have a feathered, painted falloff, with no hard rim edge. Their interior heats to white, and bloom does the rest. Dragons and jaws "of light" are painted as solid 4-value forms in the element ramp, with coloured tapered lines.
- **Ground (`ground` + `brush_wash`)**: 2-3 large soft value masses, then about 25 low-contrast directional brush strokes (dry-brush streaked) along the composition's main direction, then one light falloff toward the focal point, then a 45% vignette.

## 3. Light and value

- **Key light from the top-left.** Shadow sides fall bottom-right with tinted shadow ramps, never grey or black.
- **One focal point.** It is the brightest value: a white-hot core at the impact.
- **A value plan per bar.** Each icon has a different big shape in greyscale. For the Battle Mage: a diagonal stab into a ring, a vertical column, horizontal jaws, a dark hand mass, an elliptical ring, a red diagonal dragon, a horizontal dragon, and a gold S-coil.

## 4. Subjects

- **The class weapon appears in at most half the bar.** For the Battle Mage, the lance appears in only 4 of 8 icons: 突刺, 天击, 怒龙穿心 and 伏龙翔天. Where the action matters more than the weapon, show the action alone: 圆舞棍 is the swing arc, 龙牙 the jaws, 落花掌 the hand, 豪龙破军 the dragon.
- **却邪 (`lance_geom`) matches the model (lookdev_3).** The blade is 48% of the weapon (2x the v1 icon), slim, with a **back hook** at the base and **fine forward-raked serrations** along the back edge. It has a red fuller line and gold collar bands. Two black claw prongs cup a **glowing orb from below**. The orb is a radial bloom: crimson edge, hot pink-white core offset toward the light, no sclera ring and no dark centre, so it never reads as an eye.
- **Dragons are Chinese 龙.**
  - The snout is lengthened 1.35x past the eye (a 龙 muzzle, not a fox).
  - Fangs are narrow and curved, in bone material.
  - Antlers, whiskers, brow and mane are tapered strokes.
  - The head uses 3-value planar shading: lit top plane, mid side, shadowed cheek.
  - Scale rows run along the neck.
  - Each dragon skill uses a different view.
  - A red dragon sits on an ink ground; a gold dragon sits on ink or crimson, never on gold.
- **Hands are articulated.** Fingers splay at different lengths with knuckle breaks (a gold joint line at each), the thumb is clear, the palm is foreshortened and the claw tips are small.
- **Flowers.** Petals have a shallow notched tip and a vein. Full blossoms have a stamen cluster (filaments with gold anthers). Loose petals stream along the strike direction with trails.
- **Fragments.** No stamped chevrons. Armour fragments (`plate_fragment`) are curved plate pieces with a gold-trimmed original edge, a visible thickness side, a lit edge and a jagged break glowing with the skill light, at varied sizes. Debris (`stone_chip`) is angular dark stone with flat facets and a hot rim facing the energy source.

## 5. Banned

These are hard fails:

- one uniform outline width, or pure black lines
- flat 2-tone fills with no material cue
- per-pixel grain or speckle (low-frequency brush and brushed-metal streaks are allowed and wanted)
- the class weapon in more than half the bar, or an identical stamped repeat
- solid black stick figures or pictograms
- letters or glyphs as the subject, or stock silhouettes (game-icons.net, etc.)
- emoji-like single-flame or single-shape status icons
- more than one cool hue on a warm-keyed bar
- smiling, buck-toothed or boxy-toothed creatures

## 6. QA gates

### 6.1 Automatic (every run)

- **SSIM**: every skill icon is downsized to 32 px greyscale and compared pairwise across the bar. The script exits with code 2 if any pair scores above 0.60. Status icons are checked the same way.
  - Battle Mage skills, max pair: **0.196**.
  - Status icons, max pair: **0.381**.
- **QA sheet** (`[qa_sheet.png]` argument). Rows, top to bottom:
  1. native size
  2. 32 px colour
  3. 32 px greyscale
  4. **squint row**: skills at 24 px, blurred; status icons at 28 px, greyscale
- **Naming sheet** (`<qa>_naming.png`): the 8 skills at 64 px, numbered and unlabelled, for 6.2.

### 6.2 Human sign-off (the real gate)

SSIM only proves the pixels differ. It does not prove a player can tell the icons apart.

1. Show `_naming.png` and the squint row to **2-3 players from the target community** with no labels and no class context. Give them only the skill names in shuffled order.
2. Each tester names each icon.
3. The set passes when **at least 7 of 8 are named correctly by every tester**.
4. Any icon two testers confuse is redrawn, even if SSIM passes.

Record results in the table below.

| Date | Tester | Correct / 8 | Confusions |
|---|---|---|---|
| | | | (pending: first run of the v2 set) |

### 6.3 Reference check (internal only)

At 64 px, compare the bar against 3-5 real 国漫 MMO skill icons (剑网3 / 逆水寒 / 鸣潮). If ours look like clip-art next to them, the pass is not done. Reference icons stay in `scratchpad/art/ref_icons/` and are **never committed**.

## 7. Frames and badges (generator-owned, never per skill)

| Kind | Frame |
|---|---|
| Skill | Chamfered square (corner cut 7%). Thin navy/silver bevel matching the HUD panels. |
| Ultimate (觉醒) | Navy glass, a double gold line, the shared corner ornament (`hud_corner` = `LdHudWidget._filigree_corner`: two tapered gold horns along the edges and a bead, with no L bracket) and the HUD's blue diamond crystal at top centre. The 觉醒 label sits on a ribbon *above* the frame. |
| Passive | Round bronze ring. |
| Status | The same neutral ink ground for every status icon, plus one soft light mass in the element colour, inside a thin metallic polarity bevel lit top-left. Buffs are round and green-gold, debuffs a downward shield and red, CC a hexagon and purple. |

Skill icons export at 128 px plus `@2x`. Status icons export at 64 px plus `@2x`.

## 8. HUD states (`LdHudWidget._slot`)

| State | Look |
|---|---|
| Cooldown | A clockwise radial wipe from 12 o'clock shows a 45%-value, fully desaturated (neutral grey) copy of the icon, with a bright tick at the sweep edge. The number shows **whole seconds only** (Teko Bold, white, 2 px dark outline). In the last 3 s, a gold fill bar along the slot bottom empties. There are no decimals, because at slot size the point is lost inside the outline. |
| No MP | The icon stays in colour (it is *not* on cooldown). A blue inner border and a crossed-out MP droplet sit in the top-right corner. No colour wash. |
| Ready | A brief gold flash on the frame. |
| Pressed / queued | A gold stroke follows the chamfered slot, with a soft inner glow and a 1.5 px press-inset shadow. |
| Status stack | A big bold digit with a dark outline in the bottom-right corner. |
