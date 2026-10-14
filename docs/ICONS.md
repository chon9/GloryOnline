# Icons (ICONS track)

Pipeline, commands and the per-class recipe: **[`tools/icons/README.md`](../tools/icons/README.md)**.
Style rules: [`lookdev/ICON_STYLE.md`](../lookdev/ICON_STYLE.md), [`docs/ART_BIBLE.md`](ART_BIBLE.md) section 7.

All icons are original art drawn in code by `tools/icons/` (no stock silhouettes, no official art); see the Icons
section of `assets/CREDITS.md`.

## Coverage

| Set | Files | Status |
|---|---|---|
| Status icons | `assets/icons/status/<id>.png` + `@2x`, 64 px | all 27 `StatusSet.IDS` (incl. `atk_down`, `cast_slow`) |
| Class emblems | `assets/icons/class/<class_id>.png` + `@2x`, 128 px | all 25 classes |
| Skill bars | `assets/icons/skills/<id with . -> __>.png` + `@2x`, 128 px | battle_mage, unspecialized, blade_master, launcher, witch (40 icons) |
| Skill bars to do | one `tools/icons/comps/<class_id>.py` each | the other 20 classes (160 icons); the UI falls back to the procedural icon meanwhile |

Only the 8 bar skills of each class get icons. Slot-0 chain parts (`atk2`, `lance_2`, ...) and summon skills
(`witch.shururu_taunt`) have no file; the HUD shows the bar skill's icon for slot 0.

## Value plans of the shipped bars

The module docstring of each `tools/icons/comps/<class_id>.py` holds its value plan (one big greyscale shape per
skill, which icons show the weapon, where the one off-key accent goes).

## Sign-off

Automatic gates pass (SSIM 32 px greyscale, max pair per set <= 0.60, regression baseline in
`tools/icons/ssim_baseline.json`). The human naming test (ICON_STYLE 6.2: 2-3 community players, >= 7/8 named each)
has **not** been run for any bar yet; record results in ICON_STYLE 6.2.
