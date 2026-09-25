# Iron Oath PBR validation evidence

## Revision and provenance

Authoring/integration source: `a14381c168a621917f6808c5f0efbbc3749b37a7`.
Generated assets: `bcd9cd61c617e975d41e77c8544ee3318f8f197c`.

Blender 5.2.0 LTS was executed in the authoring session container for geometry generation, actual selected-to-active normal/albedo/ORM baking, source saves and Cycles renders. Godot 4.7.2 imported and rendered those assets locally using software Vulkan Mobile and OpenGL Compatibility. Scripts, integration and regression tests were committed with the GitHub connector.

The [guarded authoring run](https://github.com/mightyjuke/SENJIN/actions/runs/36082687143) then repeated the same scripts with checksum-pinned Blender/Godot and committed the generated files only to the unchanged realism branch. No sources/exports were pushed to main. The temporary read-only toolchain-workspace workflows were removed.

The checked-in GLBs total **23,621,192 bytes**: polearm 5,678,076 and vanguard 17,943,116. Triangle counts are **23,968 weapon** and **65,628 combined hero**, including the 41,660-triangle body. The local high master has 2,300,928 evaluated triangles with subdivision/displacement modifiers.

The local build had identical geometry/rig/clip counts but slightly different compressed image/GLB byte sizes. This is a reproducible authoring procedure, not a claim of bit-for-bit reproduction across different Python/Pillow image encoders. Manifest SHA-256 values belong to the actual committed outputs.

## Completed checks

Both local testing and the guarded generation run passed:

- **37 raw PBR glTF checks**: embedded image/buffer data, UVs, tangent frames, normal/albedo/ORM references, geometry/rig/action contracts, hashes and file/triangle budgets.
- **174 imported PBR/rig/lighting/camera checks**: channel mapping, material flags, all 23 clips, finite poses, timing, rest-roll continuity, hitstop sockets, ground self-shadow policy, camera capsule classification and visual/simulation separation.
- **349 existing Ember asset/integration checks**.
- **103 native simulation/input/save/export-contract checks**.
- **9 GUI/touch checks**.
- Actual Godot Mobile and Compatibility hero reviews and gameplay smoke captures. Each gameplay smoke completed 480 simulated frames with 180 enemies and 98 K.O.
- Actual Godot weapon close-up and a 156-frame, 24-fps turntable (6.5 seconds), encoded as H.264 for review.

The manual route was tested separately on copied `.blend` files in the authoring session: exporting the polearm and synchronizing its embedded hero copy retained the mesh/material/triangle counts, 18-bone skin and all 23 clips. It did not overwrite the committed sources.

A local native resource-pack export also confirmed that the hero, its six runtime textures, ground/sky and MIT notice survive export while the standalone inspection weapon and bake-input/source texture maps do not. This pack check is not an APK installation test.

PR #4 runs read-only contracts/renders, existing native/browser validation and actual Android debug/unsigned iOS compilation against the checked-in assets. Consult its current check results for the platform build revision; earlier low-poly branch builds are not evidence for this change.

## Problems found during actual review

1. An initial normal bake reused overlapping source-atlas UVs on the low target. The corrected pipeline retains source UVs on the high master, uniquely unwraps the game weapon, and transfers all three maps before embedding the exact result in the hero.
2. Bright oblique ground stripes in Godot were planar self-shadow acne. The ground and repeated pavers now receive sunlight shadows but do not cast them; this is covered by a regression assertion.
3. The older vertex-paint import policy was inappropriate for textured materials. A separate PBR post-import script preserves texture color spaces, normals and ORM channel mapping instead of applying the earlier vertex-color conversion.

## Limits

These tests establish specific structural and runtime properties, not artistic quality. Proportions and existing animation remain stylized. Hand contact, armor/clothing intersections, character anatomy, realistic motion, NPC/world art, richer lighting composition and polished camera transparency still need visual acceptance. The simple camera capsule does not guarantee that every banner or long weapon is culled.

No physical iPhone/iPad/Android gameplay, sustained GPU frame time, thermal behavior, battery or VRAM certification was performed. The lossless 2k maps still require a production texture-memory/compression pass. No private signing credentials, production release build or store upload are part of this milestone.
