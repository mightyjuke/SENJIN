# Ember asset-kit validation

## Tested asset revision

Generated sources and exports: `5385525b985c296fc2ab1a16a487737d4bd89616`.
Authoring: Blender 5.2.0 LTS. Runtime/import: Godot 4.7.2.

The corrected kit contains **21 editable Blender sources and 21 GLB exports**, totaling **4,166,432 bytes of raw GLB data**. Each export has one mesh and one material. Vanguard, soldier and officer each have 18 bones and 23 clips. Counts/hashes are recorded in `godot/assets/models/manifest.json`.

| Mesh | Triangles |
|---|---:|
| Vanguard | 4,884 |
| Officer | 4,968 |
| Soldier | 3,204 |
| Distant soldier body | 284 |
| Distant soldier left leg | 44 |
| Distant soldier right leg | 44 |

## Regression-proven animation repair

A rendered animation inspection found a head/torso orientation flip between idle and running. Finite-transform and clip-duration tests alone did not catch it. The generator had used a track-Y/up-Z orientation frame for vertical bones, which did not preserve the armature's rest roll.

The correction retains each bone's authored rest basis and applies a rotation difference rather than reconstructing its roll from a singular tracking frame. Torso and head use the explicit body transform. All three rigged sources and their exports were regenerated together.

The new test compares the head's right-axis across settled Idle and Run poses. In the [repair validation run](https://github.com/mightyjuke/SENJIN/actions/runs/36075029503), it failed against **all three old exports**, then passed against the corrected exports. This establishes an actual red-to-green regression, not simply a test written after the fix.

The temporary repair workflow was removed after its reviewed source changes and generated files were committed. Future regeneration uses the permanent `blender-assets.yml` workflow and the corrected generator directly.

## Completed verification

The corrected [repair run](https://github.com/mightyjuke/SENJIN/actions/runs/36075029503) passed:

- Raw glTF contracts for all 21 exports: embedded buffers, named actions, skin attributes, vertex paint, hashes and size/triangle budgets.
- **349 asset/integration checks**, including bone-roll continuity, animation duration, finite sampled poses, weapon sockets, hitstop, nearby-pool ownership and render/simulation separation.
- **103 existing native simulation/input/save/export checks**.
- Actual Godot character rendering and a software-rendered gameplay smoke: **480 simulation frames, 180 enemies, 98 K.O.**

The [initial generation run](https://github.com/mightyjuke/SENJIN/actions/runs/36074021789) also passed the existing **9 GUI/touch checks**. The roll correction changes source/exported animation data and adds the regression; it does not change the touch implementation. Final PR checks rerun native, asset and platform-build validation on the final branch head; consult PR #3 checks for their current status.

The manual-edit route was tested separately in the authoring session: `export_blend.py` reopened the corrected `vanguard.blend` and exported a GLB retaining 4,884 triangles, 18 bones and all 23 clips. Use that route rather than regenerating the kit over hand-edited assets.

## What these checks do not establish

- Software-rendered Linux captures are not iPhone/Android performance measurements. No FPS, thermal, battery or long-session memory guarantee is made.
- The kit is original script-authored, editable stylized low-poly content, not hand-sculpted final production art. The three detailed characters share a base design and need broader silhouette variety for a finished game.
- Animation curves, posed hand contact, crowd transitions, close-camera occlusion and all combat moves still need extended visual/gameplay acceptance. The tests verify important structural properties, not artistic quality.
- Banners and brazier flames are static meshes. Props are decorative; the original circular simulation boundary remains authoritative. Sound/HUD and cinematic polish remain separate work.
- The exported `Land` clip is not a complete landing-state presentation. Death presentation is constrained by the native port's existing pause-on-defeat behavior.
- No production credentials, signed store release or store submission are part of this branch. Existing engine/runtime warnings are not evidence that a physical-device test was performed.

Previews in `art/previews/` are actual Blender/Godot outputs. `characters-godot.png` and `native-gameplay.png` were regenerated after the roll fix. The screenshots are review aids, not substitutes for playing the art branch.
