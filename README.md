**English** | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

# SENJIN — 先陣

SENJIN is a browser-playable voxel battlefield action prototype built with Three.js. Take the role of a lone vanguard fighter, break through dense enemy formations, defeat officers, and build the Surge gauge for a cinematic crowd-clearing special.

The project uses an original fictional battlefield presentation. It does not use characters, names, artwork, audio, logos, story material, or other game assets from third-party commercial game franchises.

## Features

- Fast polearm combat with normal strings, charge attacks, jump attacks, and dodge
- Dense voxel crowds with hundreds of enemies using `InstancedMesh`
- Enemy officers with health bars
- Surge gauge and cinematic Surge special
- Procedural battlefield, castle structures, fires, banners, and VFX
- Procedural WebAudio sound bank; no downloaded game audio
- Deterministic fixed 60 Hz simulation
- No build step: plain ES modules with Three.js r186 vendored in `vendor/three/`

## Run

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000`. A WebGL2-capable browser is required.

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD / arrow keys |
| Normal attack | J / left mouse |
| Charge attack | K / right mouse |
| Jump | Space |
| Dodge | L / Shift |
| Surge | I |
| Camera orbit | mouse drag / Q E |
| Pause / controls | Esc |
| Start | Enter / click start |

## Project layout

```
index.html      entry point, import map, HUD CSS
src/            simulation, hero, combat, crowd, surge, camera, VFX, world, audio, UI
vendor/three/   Three.js r186
LICENSES/       third-party license texts
```

## Licensing

- Original project code: MIT, see [LICENSE](LICENSE).
- Three.js: MIT; see [LICENSES/three.js-MIT.txt](LICENSES/three.js-MIT.txt).
- `src/ui/brush.woff2`: Yuji Boku subset, SIL Open Font License 1.1; see [LICENSES/Yuji-Boku-OFL-1.1.txt](LICENSES/Yuji-Boku-OFL-1.1.txt).
- Additional attribution details: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The original MIT copyright notice is retained as required by the license.
