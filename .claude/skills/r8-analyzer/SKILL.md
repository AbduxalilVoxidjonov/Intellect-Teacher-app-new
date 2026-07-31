---
name: r8-analyzer
description: Analyzes R8 shrinker/obfuscation output (mapping.txt, seeds.txt, usage.txt, configuration.txt, build reports) for the uz.intellectcrm.teacher Android app. Use when a release build crashes only in release mode, when deciding whether to enable minification, or when investigating what R8 stripped/renamed.
---

# R8 Analyzer — uz.intellectcrm.teacher

## Current project state (check this first — it changes over time)

Read `android/app/build.gradle.kts` before doing anything else. As of the last check:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

**Minification is currently OFF.** That means there is no `mapping.txt` to analyze yet, and any "R8 stripped something" bug report is not possible under the current config — the real cause lies elsewhere (check `proguard-rules.pro` isn't even being applied, or the bug is unrelated to shrinking). Don't assume R8 output exists without confirming `isMinifyEnabled = true` first.

## Where R8 artifacts live once minification is enabled

For a Flutter/Gradle Kotlin DSL project, after running `flutter build appbundle` or `flutter build apk --release`:

```
android/app/build/outputs/mapping/release/mapping.txt      # obfuscation map (original -> renamed)
android/app/build/outputs/mapping/release/seeds.txt        # entry points R8 kept
android/app/build/outputs/mapping/release/usage.txt        # classes/members REMOVED entirely
android/app/build/outputs/mapping/release/configuration.txt # the full merged R8 rule set actually applied
```

## Workflow: release-only crash (e.g. NoSuchMethodError, ClassNotFoundException)

1. Get the obfuscated stack trace from the crash (Play Console "App bundle explorer > Deobfuscate" or `adb logcat`).
2. De-obfuscate with `retrace` (bundled with AGP): find it under the Android SDK, e.g.
   `$ANDROID_HOME/tools/proguard/bin/retrace.sh mapping.txt stacktrace.txt` (or use `re8` / `retrace.bat` on Windows).
3. Cross-reference the de-obfuscated class/method against `usage.txt` — if it appears there, R8 removed it because nothing it could see referenced it (usually a reflection, JNI, `dart:ffi`, or platform-channel callback R8 doesn't trace into).
4. Fix by adding a `-keep` rule (hand this off to the [[proguard-rules-writer]] skill), not by disabling minification.

## Workflow: "is it safe to turn minification on?"

1. Enable it: set `isMinifyEnabled = true` and `isShrinkResources = true` in the `release` block.
2. Build: `flutter build appbundle --release`.
3. Diff `usage.txt` against the app's actual dependency list in `pubspec.yaml` (dio, go_router, provider, shared_preferences, fl_chart, intl, cached_network_image, url_launcher, image_picker, firebase_core, firebase_messaging, flutter_local_notifications) — look for anything from those packages' Android plugin classes appearing in `usage.txt`, which signals a missing keep rule.
4. Actually exercise the release build (push notifications via `firebase_messaging`, local notifications, image picking, deep links via `go_router`) rather than trusting a clean build alone — R8-related breakage is runtime-only and won't show as a build error.
5. Only after a clean smoke test should this ship — coordinate with [[release-checklist]].

## Reading mapping.txt

Format per line: `original.Class -> obfuscated.Class:` then indented members `originalType originalName(args) -> obfuscatedName`. Grep for the original (non-obfuscated) name to find what it became, or vice versa for retrace.
