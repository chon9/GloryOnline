# Rongyao icon pipeline (`tools/icons/`)

Production port of the look-dev icon painter (`lookdev/tools/icon_painter.py`). It renders every skill icon, status
icon and class emblem as **original painted art drawn in code**: Python 3 + numpy + Pillow, nothing else. Read
`lookdev/ICON_STYLE.md` (the rules every icon must pass) and `docs/ART_BIBLE.md` section 7 first.

## Output (what the UI loads)

| Kind | Path | Size |
|---|---|---|
| Skill | `assets/icons/skills/<SkillDef id with "." -> "__">.png` (e.g. `battle_mage__sky_strike.png`) | 128 px + `@2x` |
| Status | `assets/icons/status/<status id>.png` (every id in `StatusSet.IDS`) | 64 px + `@2x` |
| Class emblem | `assets/icons/class/<class id>.png` | 128 px + `@2x` |

The UI falls back to the old procedural icon when a file is missing, so a class without comps is safe.

## Commands

Run from the repo root (`-I` = isolated Python; the bake adds its own folder to the path):

```
python -I tools/icons/bake.py --list witch                       # the class's 8 bar skills, desc, hints, comp status
python -I tools/icons/bake.py --classes witch --no-status --no-emblems --qa <dir> --jobs 6
python -I tools/icons/bake.py --only witch.sweep --no-status --no-emblems --qa <dir>   # one icon
python -I tools/icons/bake.py                                    # everything that has a comp (about 2-3 min)
python -I tools/icons/bake.py --check                            # no render: gate the PNGs already on disk
python -I tools/icons/bake.py --classes witch --update-baseline  # accept your bar's new SSIM max as the baseline
```

- `--qa DIR` receives `<prefix>_<class>.png` (+ `_naming.png`), `<prefix>_status.png`, `<prefix>_emblems.png`
  (default `<tmp>/rongyao_icons_qa`, prefix `mig_icons`). Rows: native, 32 px colour, 32 px grey, squint
  (skills 24 px blurred, status 28 px grey).
- The bake **exits 2** when a set fails: any pair inside one class bar, the status set or the emblem set above SSIM
  0.60 (32 px greyscale), or a set's max pair more than 0.05 above `ssim_baseline.json` (regression). `--strict` also
  fails on bar skills without a comp.
- After adding new PNGs, run Godot `--import` once (`K:/Godot_v4.7.2-stable_win64_console.exe --headless --path
  K:/Project/RONGYAO --import`).
- `skills.json` is generated from the live kits. Regenerate it when kits change:
  `K:/Godot_v4.7.2-stable_win64_console.exe --headless --path K:/Project/RONGYAO -s res://tools/icons/export_skills.gd`

## Layout

```
tools/icons/
  bake.py               driver: parallel render, gates, QA sheets, baseline        (shared - do not edit)
  export_skills.gd      headless Godot dump of kits + statuses -> skills.json      (shared)
  skills.json           generated spec: classes, bar skills (slot, CN/EN, desc, tags, hints from steps), statuses
  ssim_baseline.json    per-set SSIM max pair (regression gate)
  painter/              SHARED rendering package (owner: ICONS track; do not edit from a class task)
    core.py             painted rendering core: Canvas, masks, distance fields, ink_line, paint_form, MAT/material,
                        soft_light, light_form, hot_core, light_streak, ground/brush_wash, active KEY + tone()
    keys.py             CLASS_KEYS (one palette key per class, all 25), STATUS_PAL, STATUS_KIND, STATUS_NAMES
    subjects.py         look-dev library: 却邪 lance, dragon head/body/claw, gauntlet_palm, plate_fragment,
                        stone_chip, shock_ring, flare_spikes, petal, blossom
    weapons.py          class weapons: 千机伞 (umbrella_folded / umbrella_open / umbrella_gatling), light_sword (冰雨),
                        hand_cannon, star_broom, + families: sword, pole (orb/ring/crook/cross/scythe/axe), gun
                        (revolver/pistol/rifle), tonfa, claw, fist; helpers weapon_H, lpoly, lrib, lR, solid, cyl_band
    fx.py               crescent (slash smear), burst (explosion), trail (comet), smoke, sparks, speed_lines
    frames.py           skill / ultimate / passive frames, status badges, emblem crest
    qa.py               save, SSIM, gate, QA + naming sheets
    registry.py         @skill / @status / @emblem decorators, comp discovery, class_key()
    render.py           renders one icon (seed = crc32(id), order independent)
  comps/                compositions, auto-discovered (every *.py except _lib_*.py)
    _status.py          all 27 status icons (ICONS track)
    _emblems.py         all 25 class emblems (ICONS track)
    <class_id>.py       ONE FILE PER CLASS: its 8 skill compositions (a class agent owns exactly this file)
    _lib_<name>.py      optional reusable drawers a class agent adds (import it explicitly from your comps file)
```

## Recipe: add a class's 8 compositions (parallel-safe)

Each class agent creates and edits **only** `tools/icons/comps/<class_id>.py` (plus, if useful, its own
`comps/_lib_<name>.py`). Never edit `painter/*`, `bake.py`, `keys.py`, `_status.py` or `_emblems.py`; if you need a
shared change, write the drawer in your own file and note it in your report. Use `--jobs 6` when three agents bake
at once (20 cores).

1. **Read the skills.** `python -I tools/icons/bake.py --list <class_id>`. The bar is the 8 skills with `in_bar`;
   slot 0 is the basic chain head (`atk1`, `cannon_1`...), slot 7 the ultimate (gold ultimate frame, added by the
   generator). Also read the class row in `docs/ART_BIBLE.md` 2.5 / 2.6 (palette, signature weapon, silhouette hook).

2. **Write the value plan first**, as the module docstring (see `comps/launcher.py`): one line per skill naming its
   *big greyscale shape* (diagonal into a ring, vertical column, horizontal jaws, dark hand mass, ellipse ring,
   inverted fan, pinwheel...). Eight different shapes. Mark which icons show the class weapon: **at most 4 of 8**;
   the rest show the action alone (the slash, the projectile, the creature, the effect).

3. **Palette.** Your class key is in `painter/keys.py` (`CLASS_KEYS["<class_id>"]`: ink, metal, accent, 3-4 `tones`,
   one off-key `cool`). Every icon uses only those tones; skills differ by composition and value, not hue. The key's
   `cool` colour is the bar's **single** off-key accent (default: the ultimate's rim; or the one skill whose element
   demands it, e.g. the witch's lava flask uses `"fire"` from `STATUS_PAL`). To tune the key, define a full
   `CLASS_KEY = {...}` dict at the top of your comps file (do not edit keys.py).

4. **Write one function per skill:**

   ```python
   from painter import *  # noqa: F401,F403   (core, subjects, weapons, fx, frames, decorators)

   @skill("witch.sweep", tone="night")        # full SkillDef id, a tone of your key
   def sweep(cv, rng, el):                    # el == the tone; rng = seeded numpy Generator
       n = cv.n                               # 256 icon units, y down, key light from the top-left
       ground(cv, el, [(mask, 1)], focus=(x, y), focus_r=0.5, focus_k=0.6, wash=angle_deg, rng=rng)
       ...background effects, then the subject, then hot_core() at the single brightest point...
       return {"bleed": fn}                   # optional: drawing that must sit on top of the frame
   ```

   - Order: `ground()` (value masses + brush wash + focal falloff + vignette) -> background fx (speed lines, smoke,
     smears) -> the subject in **materials** (`material(cv, mask, "steel"|"gold"|"lacquer"|"plate"|"brass"|...)`,
     `paint_form` with a 3-4 value ramp, `light_form` for solid light constructs) -> one `hot_core` focal point.
   - Masks: `cv.poly(pts)`, `cv.ellipse(cx, cy, rx, ry)`, `ribbon(spline(pts), widths)`, `stroke(cv, pts, w0, w1)`,
     `union(cv, [...])`; ops `blur`, `dilate`, `toward(mask, d, LIGHT)` (rims), `shift`.
   - Weapons take a local frame: `weapon_H(butt_xy, tip_xy, width_scale)` (x 0 -> 1 along the weapon). Use
     `H_quad(...)` for perspective (see `launcher.cannon_1`).
   - Reuse before inventing: `crescent` (any slash/swing smear), `burst`, `trail`, `smoke`, `sparks`,
     `shock_ring`, `flare_spikes`, `plate_fragment`, `stone_chip`, the dragon parts, `gauntlet_palm`, `sword`, `pole`,
     `gun`... A new reusable subject goes in your own file or `comps/_lib_<name>.py`.

5. **Bake and LOOK.** `python -I tools/icons/bake.py --classes <id> --no-status --no-emblems --qa <dir> --jobs 6`,
   then open `<dir>/mig_icons_<id>.png` with the Read tool, and a 256 px view of any doubtful icon. Fix until:
   - SSIM gate passes (printed matrix; max pair <= 0.60, aim for < 0.40);
   - every icon is a different blob in the **squint row**;
   - nothing reads as clip-art. Failures actually hit while building the first bars, all fixed by redrawing:
     a crescent next to a broom read as a **scythe**; three slashes formed the **letter Z** (banned); a flat
     saturated cloth fill read as a **blue blob** (needs fold shading: `paint_form(..., field=...)`); thin feather
     spikes read as a **shuttlecock / comb**; a ring of fingers with a dark palm read as a **one-eyed spider**;
     a round white doll read as a **snowman**; additive overlapping strokes blew out to **white**; an all-light,
     no-mass bar read as **flat neon line art** (every bar needs painted solid masses, not only glows);
     a solid light-form smear read as a **red chili** (use `crescent`'s streaky smear instead).
   - Banned (ICON_STYLE 5): uniform outlines or pure black lines, flat 2-tone fills, per-pixel grain, letters/glyphs
     as subject, stock silhouettes, smiling/boxy-toothed creatures, more than one off-key accent, weapon in > 4 icons.

6. **Finish.** `python -I tools/icons/bake.py --classes <id> --no-status --no-emblems --update-baseline`, run Godot
   `--import`, and report the QA sheet path plus your value-plan table. Human naming (ICON_STYLE 6.2) is still the
   sign-off gate.

## Status icons and emblems

- Status: `@status("<id>", tone="<STATUS_PAL key>")` in `comps/_status.py`; badge kind (buff round, debuff shield,
  cc hexagon) comes from `STATUS_KIND`. All 27 ids are drawn; the set is gated together (max pair 0.60).
- Emblems: `@emblem("<class_id>")` in `comps/_emblems.py`; crest shape per group (swordsman heater shield, mage
  diamond, gunner chamfered badge, fighter medallion, nightwalker ogee kite, priest crowned shield, 散人 star
  octagon), gold double border, crystal side gems, sunburst base. The gate compares the crest interior.
