# Art Migration Brief (lookdev -> full game)

The user approved the look-dev slice (`lookdev/screenshots/lookdev_2.png`, `lookdev_3.png`) as the target for the
whole game, and chose to build the 25 classes by re-dressing the 11 CC0 VRoid bases. Gameplay code stays as is;
every step swaps visuals behind existing ids and APIs.

Read before working: `docs/ART_BIBLE.md` (style rules), `lookdev/README.md` (pipeline, migration plan, gaps),
`lookdev/ICON_STYLE.md` (icon rules), `lookdev/assets/LICENSES.md`, `docs/ARCHITECTURE.md` + `docs/DEVIATIONS.md`
(game contracts). The look-dev code under `lookdev/` is the reference implementation to port.

## Hard rules
- Public repo: every shipped file needs a CC0 / CC-BY / MIT / OFL (or redistribution-permitting) license recorded in
  `assets/CREDITS.md` (+ license text in `assets/licenses/`). Never commit anything from `scratchpad/art/ref/`
  (copyrighted show stills), no official logos/crests, no BOOTH or Mixamo files.
- Keep the public APIs the game uses: `CharacterVisual` (create / create_for_class / play / replay / set_weapon /
  set_alpha / set_status_visual / flash_hit / get_hand_position / get_head_position / has_clip_for, ANIM keys and
  STATUS bit order), `WeaponFactory.build(id, tint)` with every id in ARCHITECTURE §7.2, every `Fx` method and effect
  name in §7.3 + DEVIATIONS, `Hud.bind(world, match, local_uid)` / `set_local_uid`, `MapBase` interface.
- Existing test suites must keep passing (`tests/test_assets_*`, `test_core_*`, `test_kits_*`, `test_maps_*`,
  `test_hud_*`, `test_raid_*`, `test_net_*`). If a test asserts an old visual detail (e.g. a KayKit clip name), update
  that assertion to the new equivalent rather than deleting coverage.
- Verify visually: render screenshots with the non-headless console exe (technique in `visuals/gallery.gd` /
  `lookdev/lookdev.gd`) into `<scratchpad>/shots/mig_<track>_*.png` and LOOK at them with the Read tool. Compare
  against `lookdev/screenshots/`. The bar is "matches or beats the look-dev slice", judged against the bible's
  do/don't list.
- Performance budget: team 5v5 (10 characters + VFX + HUD) must hold 60 fps at 1080p on the dev machine (RTX 3080);
  use 512 px character textures, merged static meshes / MultiMesh, spring bones off beyond 25 m.
- Godot: `K:/Godot_v4.7.2-stable_win64_console.exe`. Other agents run Godot concurrently: never kill all Godot
  processes, only PIDs you started. Run `--import` after adding assets or class_name scripts. Do not git commit.
- Tabs, static typing, no emoji, bilingual UI text "中文 English".

## Shared conventions (all tracks)
- Shared shaders move to `visuals/shaders/` (toon, toon_outline, painted_env, arena_floor, anime_sky,
  painted_backdrop, vfx_*, screen_impact). Owner: CHARS track creates `toon*`; ENV creates `painted_env`,
  `arena_floor`, `anime_sky`, `painted_backdrop`; VFX creates `vfx_*`, `screen_impact`. Copy from `lookdev/shaders/`.
- Fonts move to `assets/fonts/` (owner: UI track) with OFL.txt for each.
- Icons: skill icons at `res://assets/icons/skills/<skill_id>.png` where `<skill_id>` is the full SkillDef id with
  the dot replaced by `__` (e.g. `battle_mage__sky_strike.png`), 128 px + `@2x` variant; status icons at
  `res://assets/icons/status/<status_id>.png` (64 px + `@2x`); class emblems at `res://assets/icons/class/<class_id>.png`.
  Owner: ICONS track. The UI track loads by these paths and falls back to the old procedural icon if a file is
  missing.
- Characters: anime bases in `assets/characters/anime/`, retarget maps in `assets/characters/anime/retarget/`,
  Mesh2Motion clips in `assets/anims/anime/`. Owner: CHARS track.
- `lookdev/` stays as the reference slice; do not delete it.

## Tracks and file ownership
| Track | Owns |
|---|---|
| CHARS | `visuals/character_visual.gd`, `visuals/weapon_factory.gd`, new `visuals/anime_*.gd`, `visuals/class_dress*.gd`, `visuals/shaders/toon*`, `assets/characters/anime/**`, `assets/anims/anime/**`, `tests/test_assets_visuals.gd`, `visuals/gallery.gd` |
| ENV | `maps/*.gd` (not `map_base.gd`), `pve/dungeon_*.gd`, new `maps/env_kit*.gd`, `visuals/shaders/{painted_env,arena_floor,anime_sky,painted_backdrop}*`, `assets/env/**` (new subfolders), `tests/test_maps_*.gd` |
| VFX | `autoload/fx.gd`, new `visuals/vfx_*.gd`, `visuals/shaders/{vfx_*,screen_impact}*`, `assets/vfx/**`, `tests/test_assets_fx.gd` |
| UI | `ui/**` (except `ui/icons/` which stays as fallback), `assets/fonts/**`, `tests/test_hud_*.gd`, UI parts of `tests/test_net_*.gd` |
| ICONS | `tools/icons/**` (ported generator), `assets/icons/**`, `docs/ICONS.md` |
| LEAD | everything else; integration |

If you need a change in a file you don't own, append a request to `docs/DEVIATIONS.md` under
`## Requests (art <TRACK>)` and work around it.
