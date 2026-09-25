#!/usr/bin/env bash
# Read-only validation of the checked-in asset kit (import caches are disposable).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="${1:-$ROOT/artifacts/realism}"
mkdir -p "$OUT"
export GODOT_SILENCE_ROOT_WARNING=1
export LIBGL_ALWAYS_SOFTWARE=1
python3 art/realism/verify.py --root "$ROOT" | tee "$OUT/contracts.log"
timeout 240 godot --headless --path godot --editor --import --quit 2>&1 | tee "$OUT/import.log"
timeout 150 godot --headless --path godot --script res://tests/realism/assets.gd 2>&1 | tee "$OUT/pbr.log"
grep -q SENJIN_REALISM_TESTS_PASS "$OUT/pbr.log"
timeout 150 godot --headless --path godot --script res://tests/assets.gd 2>&1 | tee "$OUT/legacy-assets.log"
grep -q SENJIN_ASSET_TESTS_PASS "$OUT/legacy-assets.log"
timeout 150 godot --headless --path godot --script res://tests/run.gd 2>&1 | tee "$OUT/native.log"
grep -q SENJIN_TESTS_PASS "$OUT/native.log"
timeout 150 xvfb-run -a godot --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/touch_ui.gd 2>&1 | tee "$OUT/touch.log"
grep -q SENJIN_TOUCH_UI_PASS "$OUT/touch.log"
for renderer in mobile gl_compatibility; do
  timeout 300 xvfb-run -a godot --path godot --rendering-method "$renderer" --audio-driver Dummy --script res://tests/realism/visual.gd -- "--capture=$OUT/hero-$renderer.png" 2>&1 | tee "$OUT/hero-$renderer.log"
  grep -q "SENJIN_REALISM_VISUAL_PASS $renderer" "$OUT/hero-$renderer.log"
  test -s "$OUT/hero-$renderer.png"
  timeout 300 xvfb-run -a godot --path godot --rendering-method "$renderer" --audio-driver Dummy -- --smoke --touch "--capture=$OUT/gameplay-$renderer.png" 2>&1 | tee "$OUT/gameplay-$renderer.log"
  grep -q SENJIN_SMOKE_PASS "$OUT/gameplay-$renderer.log"
  test -s "$OUT/gameplay-$renderer.png"
done
timeout 180 xvfb-run -a godot --path godot --rendering-method mobile --audio-driver Dummy --script res://tests/realism/visual.gd -- --weapon "--capture=$OUT/weapon-mobile.png" 2>&1 | tee "$OUT/weapon.log"
grep -q 'SENJIN_REALISM_VISUAL_PASS mobile' "$OUT/weapon.log"
if grep -E 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT"/*.log; then exit 1; fi
echo SENJIN_REALISM_VALIDATION_PASS
