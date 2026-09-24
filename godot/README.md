# SENJIN — native Godot client

Native GDScript / Godot 4.7.2. One project and one gameplay implementation for
Android, iPhone and iPad. No WebView, JavaScript runtime, npm package or native
plugin is required by the client. Open `godot/project.godot`, then press F6/F5.

## Scope and migration status

This is a first playable native port, **not a claim of pixel-perfect or complete
feature parity** with the browser implementation. The root browser build remains
unchanged as a historical reference. Maintain future mobile gameplay in this
Godot directory rather than building separate iOS and Android game logic.

Implemented: 60 Hz simulation; all 15 move types (six normals, six charges, dash,
air attack, air charge); buffered combos and charge branches; launch/knockback;
dodge invulnerability; jumping; four-segment Surge; enemy attack telegraphs and
limited simultaneous attackers; officers; reinforcement waves; defeat/restart;
procedural vertex-colored battlefield and articulated hero; MultiMesh crowds;
pooled particles; native synthesized effects; minimap; multi-touch movement,
look and combat; keyboard/controller support; safe-area layout; pause on focus
loss/background/Android back; versioned settings and best-score storage.

The native renderer reconstructs the scene in Godot and uses simplified
procedural animations. The source's detailed animation curves, spring cloth,
custom post-processing shaders, full procedural voice/music bank, cinematic
storm path and advanced squad director are NOT reproduced one-for-one. This
branch must be visually and mechanically reviewed on physical devices before
it is considered a release candidate. Changing comments or using MIT code is
not a trademark, patent or other IP clearance.

## Run and test

```sh
# From repository root. GODOT may be an absolute path to your 4.7.2 executable.
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --path godot --editor
"$GODOT" --headless --path godot --editor --import --quit
"$GODOT" --headless --path godot --script res://tests/run.gd
"$GODOT" --path godot -- --touch
"$GODOT" --headless --path godot --audio-driver Dummy -- --smoke
```

Movement: WASD/arrows, normal: J, charge: K, jump: Space, dodge: L/Shift,
Surge: I, orbit: Q/E or middle-mouse drag, pause: Esc. Standard gamepad uses
left/right sticks, X/Y/A/RB/B. On mobile, use the left joystick, drag unoccupied
right-side space to orbit, and press the labeled action buttons. Attack can be
held; charge is deliberately edge-triggered. Touches retain independent IDs.

## Performance policy

Compatibility renderer is intentional for initial Android coverage and iOS
simulator support. Start with 96/180 enemies; 300 is opt-in. Enemy simulation
uses packed arrays, a spatial hash and staggered 20 Hz steering; movement stays
at 60 Hz. Rendering uses three MultiMeshes instead of a node per soldier.
These are design budgets, not measured FPS guarantees. Shadows are enabled only
for High. Physical-device thermal and frame-time profiling remains necessary.

## Export

Install matching **4.7.2 standard export templates** in Godot first.

### Android

Configure OpenJDK 17 and Android SDK paths under Editor Settings > Export >
Android, following the engine's current official setup documentation. Debug
preset builds an APK (arm64 + x86_64), using your local debug keystore:

```sh
mkdir -p godot/exports/android
"$GODOT" --headless --path godot --export-debug "Android Debug"
```

For Google Play, use Android Release (AAB / arm64), install the Android build
template via Project > Install Android Build Template, and provide a release
keystore through `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. No release key or password is stored
in this repository. Choose the final package ID before store registration;
`org.mightyjuke.senjin` is a proposed development identifier, not proof of an
existing store listing. Check the current store target-API requirements before
release; a successful debug export is not store-policy certification.

### iOS

Export on macOS with Xcode installed. In the iOS preset, set your actual
10-character Apple Team ID and confirm the final bundle identifier. The checked
in Team ID is intentionally blank. The preset exports an Xcode project only;
select signing and provisioning in Xcode, then build/run on an iPhone or iPad.

```sh
mkdir -p godot/exports/ios
"$GODOT" --headless --path godot --export-debug "iOS"
```

The same scripts, scene and assets are used on both targets. Signing,
provisioning, store icons, store metadata and physical-device acceptance are
separate release steps. Do not commit `.p12`, `.mobileprovision`, `.jks`,
keystores, passwords or `export_credentials.cfg`.

## Acceptance before shipping

- Play all normals/charge branches, air moves and Surge on actual Android and iOS.
- Check simultaneous movement/look/attack with three fingers and gesture cancel.
- Check notches, rounded screens, both landscape orientations and iPad aspect ratios.
- Background during an attack, lock/unlock, interrupt audio and reconnect a controller.
- Profile 96/180/300 enemies for 15 minutes; inspect thermal throttling and memory.
- Verify store signing, installed package startup, update install and license display.
- Finish art/animation parity, accessibility and release icon/store presentation work.

Settings and best scores persist. An in-progress battle is paused while the app
is resident, but is not restored after OS process termination. No ads, IAP,
analytics, cloud saves, tracking or remote content downloads are implemented.

## Attribution and references

The original BubuAi MIT notice is preserved in `legal/NOTICE.txt`. The in-game
license window also exposes Godot's full runtime dependency notices. The native
export does not include the browser's Three.js or Yuji Boku font.

- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- https://godotengine.org/download/archive/4.7.2-stable/
