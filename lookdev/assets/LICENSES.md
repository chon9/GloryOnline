# Look-dev slice: asset licences and attribution

Every file under `lookdev/` that we did not write is listed here, with its source, licence and attribution.
Everything else in `lookdev/` (all `.gd` scripts, all `.gdshader` shaders, the bone maps, the procedural
environment, weapons, costume pieces, VFX, HUD drawing, the baked icon PNGs and the painted textures) is original
work for this project and ships under the repository's own licence.

No file comes from 全职高手 / The King's Avatar. No screenshot, logo, card frame or official asset was used.
The reference stills in `scratchpad/art/ref/` were only looked at and are not in the repository.

## Characters: VRoid Project CC0 sample models

| File | Source model | Licence |
|---|---|---|
| `chars/vroid_sakurada.glb` (+ `.vrm.json`) | "Sakurada Fumiriya" | CC0 1.0 (OpenGameArt). Embedded VRM meta: VRoid Hub licence, redistribution = allow, modification = allow, credit = unnecessary |
| `chars/vroid_hairsample_male.glb` (+ `.vrm.json`) | "HairSample_Male" | CC0 1.0 (OpenGameArt). Embedded VRM meta: `licenseName = CC0` |
| `chars/vroid_avatarsample_g.glb` (+ `.vrm.json`) | "AvatarSample_G" | CC0 1.0 (OpenGameArt). Embedded VRM meta: VRoid Hub licence, redistribution = allow, modification = allow, credit = unnecessary |

- Source: https://opengameart.org/content/vroid-studio-cc0-models. The OpenGameArt page says these were "explicitly released by VRoid under CC0".
- Author: VRoid Project (pixiv Inc.). Credit is optional. We give it anyway: *Character base models by VRoid Project (pixiv Inc.), CC0, via OpenGameArt.*
- **Modified.** `lookdev/tools/vrm2glb.py` converted each file from VRM 0.x to glTF binary. It dropped the thumbnail, normal, matcap and outline-width textures, downsized the rest to 1024 px or less, merged primitives that share a material, wrapped the scene in a 180-degree facing fix, and moved the VRM humanoid and spring-bone data into the `.vrm.json` sidecar. At runtime the materials are replaced with our own toon shader and recoloured.
- Licence text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

## Animation: Mesh2Motion human animation library (CC0)

| File | Source |
|---|---|
| `anims/human-base-animations.glb` | https://github.com/Mesh2Motion/mesh2motion-app/raw/main/static/animations/human-base-animations.glb |
| `anims/human-addon-animations.glb` | https://github.com/Mesh2Motion/mesh2motion-app/raw/main/static/animations/human-addon-animations.glb |

- Licence: CC0 1.0. See https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-CC0.MD: "All 3d models, blend files, rigs, animations" are CC0.
- The base set is built on Universal Animation Library 1 and 2 by Quaternius (quaternius.com), which is also CC0 1.0.
- Credit (optional): *Animations: Mesh2Motion (mesh2motion.org), CC0; includes Universal Animation Library by Quaternius, CC0.*
- These are unmodified files. They are retargeted at import time through `retarget/m2m.tres`.

## Icons and painted textures: original work

`icons/out/*.png` (8 Battle Mage skill icons and 7 status badges) and `textures/*.png` (maple leaf-card atlas,
team banner cloths, fire tongue sprite) are **original art drawn in code** by `tools/icon_painter.py` and
`tools/paint_textures.py`. The subjects (the 却邪-style lance, dragons, hand, petals, figures, badges, crest) are
vector shapes authored in those scripts. No third-party silhouettes, brushes or images are used, so these ship
under the repository's own licence and need no attribution.

The earlier iteration used game-icons.net SVGs (CC BY 3.0). They were removed from `lookdev/` together with
the old `tools/icon_forge.gd`, so nothing here carries a CC BY obligation any more.

## Fonts (SIL Open Font License 1.1)

Each font ships unmodified, with its `OFL.txt` beside it.

| File | Family | Copyright / Reserved Font Name | Source |
|---|---|---|---|
| `fonts/notosanssc/NotoSansSC[wght].ttf` | Noto Sans SC | Copyright 2014-2021 Adobe, RFN "Source" | https://github.com/google/fonts/tree/main/ofl/notosanssc |
| `fonts/mashanzheng/MaShanZheng-Regular.ttf` | Ma Shan Zheng | Copyright 2018 The Ma Shan Zheng Project Authors | https://github.com/google/fonts/tree/main/ofl/mashanzheng |
| `fonts/teko/Teko[wght].ttf` | Teko | Copyright 2023 The Teko Project Authors | https://github.com/google/fonts/tree/main/ofl/teko |
| `fonts/russoone/RussoOne-Regular.ttf` | Russo One | Copyright 2011-2012 Jovanny Lemonad, RFN "Russo" | https://github.com/google/fonts/tree/main/ofl/russoone |
| `fonts/orbitron/Orbitron[wght].ttf` | Orbitron (no longer used by the HUD, which is CN-first now; safe to drop) | Copyright 2018 The Orbitron Project Authors, RFN "Orbitron" | https://github.com/google/fonts/tree/main/ofl/orbitron |

If you subset a font to save space, the result is a Modified Version under the OFL. Do not use any Reserved Font Name on it.

## Not used and not committed

These were evaluated during research but are **not** in `lookdev/`:

- the godot-vrm addon. VRM files are converted to glTF instead, and Godot's built-in `SpringBoneSimulator3D` drives the springs.
- Kenney, KayKit and Quaternius environment kits. The environment is fully procedural.
- game-icons.net SVGs (removed in iteration 2; see above).
- Poly Haven HDRIs.
- the third-party sky and fog shaders from the eldskald demo.
