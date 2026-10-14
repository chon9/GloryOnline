# Contributing to Rongyao Arena 荣耀竞技场

Thanks for helping! Bug reports, balance feedback, new skills, art, sound and code are all welcome.
By contributing you agree that your contribution is licensed under the project's [MIT License](LICENSE)
(code and original assets) — or, for third-party assets, under the license you document for them.

## Reporting bugs and feedback

Open an [issue](https://github.com/chon9/GloryOnline/issues) with:
- the game version (shown in the release name, e.g. `v0.1.1-alpha`) and your Windows / GPU,
- what you did, what you expected and what happened,
- the mode, map and classes involved, and a screenshot or clip if you can.

Balance feedback is especially useful with the matchup (class vs class), bot difficulty and roughly how long fights take.

## Getting set up

1. Install **Godot 4.7.2** (standard build). The GodotSteam GDExtension is already in `addons/godotsteam`.
2. Clone the repo and open `project.godot`. Press Play to run from the main menu.
3. Steam is optional; run with `-- --no-steam` (or use LAN) to test multiplayer without it.
   Two copies on one PC can test multiplayer through **LAN** (`127.0.0.1`).

## Running the tests

Tests are headless Godot scripts in `tests/`. Run one with:

```
godot --headless --path . -s res://tests/test_core_combat.gd
```

Each suite prints `... TESTS: X passed, Y failed`. The exit code is 0 even when a script error happens, so also
check the output for `SCRIPT ERROR` or `Parse Error`. `test_core_net.gd` and `test_net_enet.gd` need two
processes (`-- --role=host` and `-- --role=client`). Please run the suites that touch your change — and add a
test for new behaviour — before opening a pull request.

## Code conventions

- GDScript with static typing where practical, tabs for indentation, no emoji in code or UI text.
- All player-facing text is bilingual, Chinese first: `"天击 Sky Strike"`.
- The host is authoritative: gameplay code that changes state must check `multiplayer.is_server()`; clients only
  send input and render. Cosmetic effects go through `Fx`, music through `Music` (local only, never networked).
- Every new script must parse (`--check-only`) and every module has headless tests in `tests/`.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) is the contract between modules and
  [`docs/DEVIATIONS.md`](docs/DEVIATIONS.md) records where the code differs from it — read both before larger changes.

## Adding or changing content

- **Skills / classes:** class kits live in `classes/<group>/<class>.gd` and describe skills as data-driven action
  timelines (see the action table in `docs/ARCHITECTURE.md` §5). Keep class names, weapons and skill names faithful
  to Glory canon (`docs/research/glory-classes-verified.json`).
- **Outfits:** one file per class in `visuals/dress/` — see `visuals/dress/README.md`.
- **Skill icons:** drawn in code by `tools/icons/` — see `tools/icons/README.md`.
- **Art direction:** follow [`docs/ART_BIBLE.md`](docs/ART_BIBLE.md) (全职高手-style anime look).

## Asset licensing (important)

This repository and its releases are public, so every asset must be redistributable:
- Accepted: CC0, CC BY 3.0/4.0, OGA-BY, SIL OFL (fonts), MIT, or original work you made and license under MIT.
- Not accepted: non-commercial (NC) or no-derivatives (ND) licenses, "free for personal use", Pixabay/Mixkit/Sonniss-style
  licenses that forbid redistributing the raw files, Mixamo or BOOTH downloads, AI output with unclear rights,
  and anything taken from the 全职高手 anime, novel or official game art.
- Add a row to [`assets/CREDITS.md`](assets/CREDITS.md) (author, title, source URL, license, exact attribution for CC BY)
  and put the license text in `assets/licenses/`.

## Pull requests

Keep pull requests focused on one change, describe what and why, list the tests you ran, and include a screenshot
for visual changes.
