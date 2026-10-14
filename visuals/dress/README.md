# Class dresses: how to add a class

Every player class renders as an anime body: a VRoid CC0 base (`assets/characters/anime/`), recoloured with the toon
shader and dressed with procedural costume pieces. `ClassDress` (`visuals/class_dress.gd`) owns the registry.
A class without a file here uses its `ClassDress.FALLBACK` row (recoloured base + belt). **To finish a class, add one
file `visuals/dress/<class_id>.gd`.** It is picked up automatically (directory scan); you never edit
`class_dress.gd`, `character_visual.gd` or another class's file.

Finished: `battle_mage`, `launcher`, `witch`, `unspecialized`, `blade_master`. Use them as references
(`battle_mage.gd` is the simplest, `unspecialized.gd` shows asymmetric plate + runtime cloth, `launcher.gd` shows how to
bury a base's dress under a new silhouette).

## 1. The file

```gdscript
extends RefCounted
## Knight 骑士, bible 2.5: tower shield + lance, heavy layered plate, team-colour tabard.

static func dress() -> Dictionary:
	return {
		"base": "base_male",            # key of ClassDress.BASES
		"height": 1.88,                  # metres; the whole body is scaled to it
		"proportions": [1.06, 0.95],     # [leg bone scale, head bone scale] (bible 2.1)
		"rim": Color(0.85, 0.92, 1.0),   # rim-light colour of the body materials
		"dress": {                       # material-name substring -> recolour (see below)
			"Tops": {"map": [Color("#2A3240"), Color("#8E9AAB"), Color("#E8EEF6")], "contrast": 1.3},
			"HAIR": {"map": [Color("#2A2018"), Color("#5A4A38"), Color("#9A8468")], "line": 1.7},
			"EyeIris": {"iris": Color(0.6, 0.75, 1.2)},
		},
		"anims": {&"idle": ["Fighting Idle"], &"attack": ["Sword_Regular_A"]},   # optional overrides
		"weapon_anims": {"umbrella_gun": {&"idle": ["Pistol_Idle"]}},             # optional, per held weapon
		"cull": [{"mat": "Tops", "bone": "Neck", "min": Vector3(-0.22, -0.16, -0.3), "max": Vector3(0.22, 0.2, -0.11)}],
		"face": {"blink": 0.3, "angry": 0.2},                                     # optional persistent expression
		"grips": {"knight_sword": {"kind": "blade", "tilt": 0.0}},                  # optional overrides
	}


static func build(b: AnimeBody) -> void:
	# costume pieces only - the weapon is mounted by CharacterVisual.set_weapon()
	...
```

Rules: `extends RefCounted`, both functions `static`, **no lambdas / Callables in the dictionary** (static caches that
hold lambdas of other scripts crash Godot on exit; `build` is found by name). File names starting with `_` are
treated as helpers and skipped, so a family can share code in e.g. `_nightwalker_parts.gd`
(`const P := preload("res://visuals/dress/_nightwalker_parts.gd")`). Tabs, static typing, no emoji.

## 2. Bases (`ClassDress.BASES`)

| key | sex | look | materials you can recolour |
|---|---|---|---|
| sakurada | m | tousled light hair, blazer + tie | Tops, Accessory (tie), Bottoms, Shoes, HAIR |
| hairsample_male | m | spiky dark hair, bulky hoodie | Tops (hoodie), Bottoms, Shoes, HAIR |
| base_male | m | buzz-cut cap hair (use with helmets/hoods) | Tops, Accessory_Tie, Bottoms, Shoes, HairBack |
| avatarsample_d | f | dark bob, school uniform | Tops, Accessory, Bottoms, Shoes, HAIR |
| avatarsample_d_darkness | f | dark gothic one-piece | Tops, Shoes, HAIR |
| avatarsample_e | f | small, brown bob, one-piece (~1.4 m natural) | Onepice, Shoes, HAIR |
| avatarsample_f | f | silver short hair, one-piece | Onepice, Shoes, HAIR |
| avatarsample_g | f | long blonde, one-piece | Onepice, Shoes, HAIR |
| base_female | f | cap hair | Tops, Accessory_Tie, Bottoms, Shoes, HairBack |
| hairsample_female | f | long hair | Tops, Shoes, HAIR |
| sendagaya_shino | f | long black hair, uniform | Tops, Accessory, Bottoms, Shoes, HAIR |

Material names contain `_SKIN`, `_CLOTH`, `_HAIR`, `_FACE`, `_EYE`; keys are substrings (`"Tops"`, `"HAIR"`,
`"EyeIris"`, `"Brow"`). Several classes may share a base: make them differ by hair colour + silhouette.

## 3. `dress` recolour options (AnimeBody._dress)

| option | effect |
|---|---|
| `map: [dark, mid, light]` (+ `contrast`) | gradient-map the source texture by luminance - the main tool; keeps the painted folds |
| `hue: 0..1` (+ `sat`, `min_sat`) | hue-swap saturated pixels only (keeps whites / skin) |
| `mul: Color` | plain multiply |
| `shade: Color` | shadow tint (shadow = albedo * tint; never grey: shift 10-20 deg toward blue/violet) |
| `iris: Color` (on `EyeIris`), `color: Color` (on `Brow`) | eye / brow colour |
| `hide: true` | hide the surface (only when a costume piece fully covers it) |
| `line: float`, `rim_strength: float` | outline width in px, rim strength |

Extra HAIR options: `spec: Color`, `spec_strength: float` (the anisotropic hair streaks, toon special 1).
Faces always use the clean head-axis shadow (toon special 2); you never set it.

**Hide base clothing** that would show through the costume with `cull`: a list of `{mat, min, max, bone}` boxes in
character space (rest pose, metres, +Z forward, right hand at -X), relative to the rest position of `bone` if given.
Every triangle of a surface whose name contains `mat` with all 3 vertices inside a box is removed at load
(e.g. the HairSample_Male hoodie hood in `witch.gd` / `unspecialized.gd`). Use `hide: true` in `dress` to drop a whole
surface. If a base keeps fighting the silhouette, pick another base.

**Faces**: `face: {expression: weight}` sets a persistent VRM expression (`blink`, `blink_l`, `blink_r`, `joy`,
`angry`, `sorrow`, `fun`, `surprised`, `a`, `i`, `u`, `e`, `o`; weights 0..1). Classes sharing a base must differ:
e.g. Battle Mage `{angry: 0.3, blink: 0.15}` (stern) vs Blade Master `{joy: 0.45, surprised: 0.15}` (grin), Unspecialized
`{blink: 0.38, fun: 0.12}` (lazy half-lidded).

Light source textures (white shirts, light hoodies) map mostly to `light`: put the colour you want to read in `mid`
**and** `light`, or darken `light` (see `unspecialized.gd`).

## 4. Costume builders (`build(b: AnimeBody)`)

Author everything in **character space at the rest (T) pose**: metres, +Y up, the character faces +Z, its right hand
is at -X. `b.bone_pos("UpperChest")`, `b.bone_xf(bone)` give rest positions; `b.attach(bone, node, xf)` parents a node
to a humanoid bone (SkeletonProfileHumanoid names: Hips, Spine, Chest, UpperChest, Neck, Head, Left/RightShoulder,
UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot, Toes).

Mesh + material helpers (`AnimeGear`): `lathe(profile, seg, sx, sz, arc)` (shells: cuirass, robe bells, collars,
cuffs; `arc < TAU` leaves an opening, rotate it to face the gap forward), `extrude(poly, depth, bevel)` (plates,
crests, fins, flames), `ribbon(points, widths, sides, thickness)` (panels, straps, laces), `tube(points, radius)`
(cords, hat cones), `box / sphere / cyl`, `star_poly`, `toon(color, {shade, rim, rim_strength, emit, outline, line})`,
`gold()`, `steel()`, `glow(color, energy, additive, alpha)`, `mi(mesh, mat, parent, xf)`.

Shared pieces (`ClassDress`): `pauldron(b, side, plate, trim, size, layers, fin)`, `coat_panel(...)` (split coat
tails), `limb_guard(b, bone, to_bone, radii, t0, t1, mat, trim)` (gauntlets, greaves, boot shafts),
`band(...)`, `diamond / flame / wing_crest` polygons, `wrap(node)`, and
`cloth(b, bone, anchor_xf, opts)` - a **runtime cloth strip** (`AnimeCloth`: verlet chain rebuilt as a toon ribbon,
sphere colliders on bones, optional `lining` material, frozen beyond 25 m). Use it for the hero silhouette element
(scarf, cape, coat tail, bustle, sash). Keep `stiffness` low (0.02-0.05, tip 0.003-0.01) or it reads as a plank.

Bible checklist per class (2.4/2.5): 2-3 dominant colours + gold `#D8B25A` or silver `#C9D3DE` trim; ONE hero
silhouette element 30-100 % of body height; layering (dark undersuit, light mid-layer, plates on shoulders, forearms,
shins); pointed swept-back plate flares; asymmetry welcome; a little Chinese seasoning (mandarin collar, red rope
sash, tassels). Hair, scarves and capes must move (VRM springs are automatic; add `cloth` for costume).

## 5. Animation and grips

- `anims`: key -> ordered clip candidates; override idle/attack per class. Clip names come from
  `CharacterVisual.get_library("anime")` (Mesh2Motion: `Fighting Idle`, `Idle_Sword`, `Spell_Simple_Idle`,
  `Pistol_Idle`, `Idle_FoldArms`, `Sword_Regular_A/B/C`, `Punch_Jab`, `Pistol_Shoot`, `Two-hand Blast`, ... and the
  retargeted KayKit `kk_*` clips). Without overrides the weapon stance decides (`ANIME_STANCE_OVERRIDES`).
- `grips`: weapon id -> `{kind, tilt, roll, yaw, pitch, offset, two_hand, scale}`. Kinds: `blade` (blade forward,
  `tilt` raises it, `yaw` turns it toward the body so it stands upright when the arm hangs), `pole` (`tilt`, `yaw`;
  `two_hand: true` aims the shaft through the left palm), `gun` / `fist` / `held`
  (along the forearm; `pitch`, `offset`, `roll` / `roll_r` / `roll_l` about the forearm), `shield` (back of the left
  forearm), `hip`. `accent_only: true` keeps only the weapon's glowing accents (your dress builds the armour).
  Per-clip / per-anim overrides: `"clips": {"<clip>": {tilt, yaw, roll}}`, `"anims": {&"<key>": {...}}` (caster poles
  are re-gripped automatically in the KayKit cast clips, `CharacterVisual.CLIP_GRIPS`).
- Cloth options (`ClassDress.cloth`): values are per 1/60 s step; `hang` (bend toward the floor), `bend`, `curl`,
  `folds`, `fold_depth`, `root_stiff` on top of the old ones. Rigid pieces are merged into one skinned mesh
  automatically; anything that must move on its own needs a script (see `_swordmage_lib.gd` floaters). Defaults come from
  `WeaponFactory.grip_kind()` and `CharacterVisual.POLE_TILT_ANIME`, so most classes need no grips entry.

## 6. Check it

```
godot --path . res://scenes/gallery.tscn -- --view=close:<class_id> --shot=<png>          # 3/4 portrait (--yaw=deg)
godot --path . res://scenes/gallery.tscn -- --view=face:<class_id> --shot=<png>           # face close-up
godot --path . res://scenes/gallery.tscn -- --view=clips --cls=<class_id> "--clips=Fighting Idle@0.5,Sword_Regular_A@0.25" --shot=<png>
godot --path . res://scenes/gallery.tscn -- --view=front --shot=<png>                     # all 25 classes
godot --headless --path . -s res://tests/test_assets_visuals.gd                           # must stay green
```

Use the non-headless console exe for shots. Compare against `lookdev/screenshots/lookdev_2.png` / `lookdev_3.png`
and the bible's do/don't table. Add `ClassDress.is_finished("<class_id>")` coverage to `tests/test_assets_visuals.gd`
only through the CHARS owner (append a request to `docs/DEVIATIONS.md` otherwise).
