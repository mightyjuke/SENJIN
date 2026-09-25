# Android completion: compiled Vulkan feature contract

## Failure found during the realism-branch handoff

The prebuilt-APK path at `5194612fabd9c723961f622724d36ebd731001ed` produced a signed APK but failed strict manifest validation in run `36083789221`, Android job `107911137983`.

`aapt dump badging` reported `android:required: attribute is not an integer value`. Inspection of the actual APK's binary XML confirmed both injected Vulkan `required` and `version` attributes had `TYPE_STRING` (0x03). The GLES declaration already used correctly typed values. This was not a texture, mesh, shader, JavaScript or GDScript error, and a valid APK signature did not establish a valid manifest.

## Repair

Both Android presets now use the normal Godot Gradle build path. The matching 4.7.2 Android source template and Gradle/AAPT2 compile the manifest before packaging/signing. There is no post-signature mutation, ad-hoc APK patching, disabled validation, or forced downgrade to Compatibility rendering.

CI installs SDK 36, Build Tools 36.1.0 and NDK 29.0.14206865, matching the pinned engine's `platform/android/java/app/config.gradle`. It retains the strict `aapt` check, verifies the APK signature, architectures and attribution, and additionally reads the actual compiled manifest with `.github/scripts/verify_android_manifest.py`.

The validator requires compiled boolean/integer types, the expected application ID and Vulkan level/version, and optional Vulkan requirements so the configured OpenGL ES 3 Compatibility fallback remains possible. Twelve SDK-independent fixtures exercise malformed values, missing/duplicate features, unexpected package IDs, fallback declarations and both string-pool encodings.

The new validator was run against the downloaded failing APK and rejected its string-typed `required` attribute. PR #4 records the final rebuilt APK and platform-run results after verification. No claim of phone installation, thermal performance or production signing is made.

## Local Android export

Install the same Godot 4.7.2 export templates and configure Java/Android SDK paths in Godot. Install the Android Gradle build template from the Project menu once, or on a clean checkout use:

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
mkdir -p godot/exports/android
"$GODOT" --headless --path godot --install-android-build-template --export-debug 'Android Debug'
python3 .github/scripts/verify_android_manifest.py godot/exports/android/senjin-debug.apk
```

After template installation, ordinary exports can omit `--install-android-build-template`. Do not reinstall the template over a hand-modified Gradle project. Android AAB release signing still requires the owner's real release keystore; CI uses disposable debug keys only. Merely opening or playing the Godot project does not require the Android SDK or Blender.
