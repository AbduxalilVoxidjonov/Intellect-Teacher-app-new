---
name: aab-inspector
description: Inspects built .aab/.apk bundles for the uz.intellectcrm.teacher app — size breakdown, bundletool commands, split analysis, and confirming what R8/resource shrinking actually removed. Use after a release build to check size regressions or before a Play Store upload.
---

# AAB Inspector — uz.intellectcrm.teacher

## Where the build output lands

```
build/app/outputs/bundle/release/app-release.aab   # Flutter's default AAB output
android/app/build/outputs/bundle/release/app-release.aab   # if built via Gradle directly
```

Build it with `flutter build appbundle --release` (from the `teacher/` project root, not `android/`).

## bundletool — get it first

Check for a local copy before assuming it needs installing:
```bash
find . -iname "bundletool*.jar" 2>/dev/null
which bundletool 2>/dev/null
```
If absent, download the latest release jar from the official `google/bundletool` GitHub releases page rather than guessing a version.

## Size breakdown

```bash
java -jar bundletool.jar build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=app.apks \
  --mode=universal

java -jar bundletool.jar get-size total --apks=app.apks
```

For a per-module/per-density breakdown use `get-size total --apks=app.apks --dimensions=SDK,ABI,SCREEN_DENSITY,LANGUAGE`.

## Comparing before/after a shrinking change

1. Build once with the change (e.g. `isMinifyEnabled = true`), rename the AAB (`app-release-minified.aab`).
2. Revert, build again (`app-release-baseline.aab`).
3. Run `get-size total` on both `.apks` and diff — a real R8+resource-shrink pass on this dependency set (Firebase, image_picker, fl_chart, cached_network_image) typically saves noticeable size; if the diff is near-zero, minification likely isn't actually enabled or a rule is keeping everything (see [[proguard-rules-writer]]).

## Inspecting contents directly (no install needed)

An `.aab` is a zip:
```bash
unzip -l build/app/outputs/bundle/release/app-release.aab | sort -k1 -n -r | head -30
```
Largest entries are usually `base/lib/<abi>/libflutter.so`, `base/lib/<abi>/libapp.so` (the compiled Dart AOT code — size here reflects app code + dependency count, not shrinkable by R8 since R8 only touches Java/Kotlin bytecode, not the Dart AOT snapshot), and `base/res/**` (shrinkable via `isShrinkResources`).

**Important distinction for this project**: this is a Flutter app — the bulk of business logic compiles to `libapp.so` (Dart AOT), which R8/ProGuard cannot shrink or obfuscate at all. R8 here only affects the thin Android embedding layer and native plugin Java/Kotlin code (Firebase, flutter_local_notifications, etc.). Don't expect dramatic size wins from enabling minification on a Flutter app — that's normal, not a sign something's misconfigured.

## Before a Play Store upload

Confirm signing: `unzip -p app-release.aab META-INF/*.RSA | keytool -printcert` (or check via bundletool `dump manifest`) matches the certificate registered in Play Console — a mismatch is one of the most common upload rejections. Cross-check the keystore against [[release-checklist]].
