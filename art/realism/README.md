# SENJIN Iron Oath — PBR hero, weapon and lighting milestone

This is a realism-oriented **material/geometry vertical slice**, built in Blender 5.2.0 LTS and integrated in Godot 4.7.2. It replaces the native hero and his polearm, adds a physically based sky, sunlight, shadows and ground materials, and leaves battle rules unchanged. It is based on the unmerged Ember art branch; the other characters and fortress kit still use that earlier art. This does **not** claim a photoreal human sculpt, AAA animation, or a finished realistic battlefield.

## Inspect locally

```sh
git fetch origin
git switch art/realistic-pbr-pass
/Applications/Godot.app/Contents/MacOS/Godot --path godot --editor
```

Open `godot/project.godot` and press F6/F5 as appropriate, or run without `--editor`. The default scene uses the PBR hero. Keyboard controls remain WASD/J/K/Space/L/I, Q/E orbit; a middle-mouse drag also orbits. Balanced/High enables sunlight shadows and 2x MSAA; Low disables both. Lower enemy counts remain the existing quality profiles.

The selected renderer is **Mobile** (Vulkan, Metal on iOS), with Compatibility fallback enabled. Compatibility is tested too but has visibly different light/material response. The scene does not require SDFGI, VoxelGI, SSAO, SSR or volumetric fog. The sky is a static original Blender-generated EXR, not a licensed photographic HDRI. No claim of real-time global illumination is made.

Actual Godot close-up reviews (define `GODOT` as the application binary above on macOS):

```sh
"$GODOT" --path godot --script res://tests/realism/visual.gd -- --capture=/tmp/hero.png
"$GODOT" --path godot --script res://tests/realism/visual.gd -- --weapon --capture=/tmp/weapon.png
"$GODOT" --path godot -- --smoke --touch --capture=/tmp/gameplay.png
```

`art/realism/previews/` contains real Blender and Godot captures and `hero-turntable.mp4`, not AI concept illustrations. Studio lighting and the gameplay camera are separate; a Blender beauty render is not evidence of identical mobile output.

## Authored content and budgets

- `source/vanguard.blend`: smooth curved armor shell, layered lames with rivets, rolled trim, pleated cloth, gloves/fingers, boots and an enclosed helmet. **41,660 body triangles**.
- `source/polearm.blend`: game weapon with tapered/beveled blade, fine original scroll inlay on both faces, chased socket, turned ferrules, leather wrapping, binding wire and hanging cords. **23,968 triangles**.
- `source/polearm_master.blend`: editable high-resolution displaced engraving source and low-poly bake target. This source is never included in game exports.
- `assets/realism/vanguard.glb`: combined skinned body and weapon, **65,628 triangles, 2 meshes/materials, 18 bones, 23 existing clips**.
- `assets/realism/polearm.glb`: standalone inspection/editing export; excluded from mobile application packages.
- 2048-square hero and weapon textures: sRGB albedo, linear ORM (AO/roughness/metallic), tangent-space normal maps. Ground maps are 1024-square; sky is 1024x512 half-float EXR.

The weapon has a **real selected-to-active normal bake** from subdivided/displaced geometry. The game weapon receives a unique UV unwrap before normal, albedo and ORM transfer; the high master retains its original source-atlas UVs. This avoids the invalid overlapping-target-UV bake attempted during development. The exact baked low mesh is embedded in the hero as well as exported separately.

Raw GLBs total approximately **24.1 MB** before engine import. Only one hero receives this geometry/texture budget; ordinary enemies retain the bounded nearby pool and distant MultiMeshes. Current textures prioritize review fidelity and use lossless imports, not a certified production VRAM budget. Six 2k RGBA maps with mipmaps can consume up to approximately 128 MiB uncompressed; device profiling and platform texture compression are still acceptance work. Triangle/size budgets are not phone FPS measurements.

## What did not change

Combat definitions, damage, hitboxes and simulation timing are unchanged. Existing 23 animation clips and the tested rest-bone orientation are reused. This milestone is **not a new motion-capture or hand-polished animation pass**; shoulder/hand contact, clothing intersection and broader realistic body mechanics still need visual review. Cloth folds are modeled, not simulated. Faces/hair beneath the helmet are not a detailed human head asset.

Only rendering hides soldiers that intersect a narrow camera-to-hero sight capsule. Their simulation, damage and collision remain active, and the parent renderer restores their visibility each frame. This is a simple occlusion treatment, not a polished transparency transition. Ground/pavers receive shadows but do not cast them, avoiding the planar self-shadow acne found in actual Godot review.

## Safe editing and re-export

Do not run the generator over hand-edited work. Normal `.blend` iteration uses:

```sh
blender -b --python art/realism/export_asset.py -- --root . --asset vanguard
# For weapon edits, synchronize its embedded hero copy as well:
blender -b --python art/realism/export_asset.py -- --root . --asset polearm --sync-hero
python3 art/realism/verify.py
"$GODOT" --headless --path godot --editor --import --quit
"$GODOT" --headless --path godot --script res://tests/realism/assets.gd
```

Packed image data is retained. Re-bake after UV/topology changes; the manual exporter does not pretend that stale baked maps remain valid. Preserve bone/action/socket names and the `Polearm_LOD0` / `Polearm_PBR` names used by the synchronization helper. Commit the edited sources, matching GLBs, manifests and import policies together. Godot-extracted `vanguard_*.png` and `polearm_*.png` are disposable import products, recreated from embedded GLBs; do not commit duplicate images or `.godot/` caches.

For intentional full regeneration only:

```sh
python3 art/realism/textures.py --root .  # requires NumPy and Pillow
blender -b -t 4 --python art/realism/build_realism.py -- --root . --bake --render
python3 art/realism/verify.py
```

The branch-only generation workflow repeats the locally exercised authoring pipeline with checksum-pinned tools and commits only generated art after tests pass. It refuses to overwrite a moved branch and never writes main. Disable auto-regeneration when switching to hand-maintained sources. Read-only PR tests remain suitable thereafter.

## License and readiness

`LICENSE` explicitly covers the new original geometry, surface fields, bakes, sky, source scripts and previews; the same MIT notice is bundled under `godot/assets/realism/LICENSE.txt`. Existing upstream code/engine/animation notices remain intact. No downloaded models, textures, fonts or motion capture were added. Blender is an authoring dependency and is not bundled.

Physical phone GPU/thermal/memory/visual acceptance, final art direction, realistic enemies/environment, refined animation and signed store releases remain out of scope. Successful unsigned platform compilation is not a claim that this is ready to publish.
