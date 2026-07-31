---
name: gradle-doctor
description: Diagnoses Gradle/Android build failures for the uz.intellectcrm.teacher Flutter/Android project — dependency conflicts, AGP/Kotlin/Gradle version mismatches, build.gradle.kts errors. Use when `flutter build` or `flutter run` fails during the Android Gradle phase.
---

# Gradle Doctor — uz.intellectcrm.teacher

## Known-good versions for this project (re-check if a build starts failing after an update)

From `android/gradle/wrapper/gradle-wrapper.properties` and `android/settings.gradle.kts`:

| Component | Version |
|---|---|
| Gradle | 9.1.0 |
| Android Gradle Plugin (AGP) | 9.0.1 |
| Kotlin | 2.3.20 |
| Java (source/target compat) | 17 |
| google-services plugin | 4.4.2 |

These must stay mutually compatible — check the [AGP release notes](https://developer.android.com/build/releases/gradle-plugin) compatibility table before bumping any one of them independently. AGP 9.x requires JDK 17+, so also verify `JAVA_HOME` / the JDK Gradle is using if you see bytecode-version errors.

## First triage steps for any Gradle failure

1. Re-run with full output: `flutter build apk --release -v 2>&1 | tail -100` (or `apkbundle`/`apk --debug`) — Flutter swallows Gradle's real error in the default summary.
2. Isolate whether it's Flutter or pure Gradle: `cd android && ./gradlew assembleRelease --stacktrace`.
3. Clear stale state before assuming a real bug: `flutter clean && cd android && ./gradlew clean`.

## Common failure classes and where to look in this project

- **Duplicate class / dependency resolution conflict** — usually a transitive version clash between `firebase_core`/`firebase_messaging` and Google Play services. Run `cd android && ./gradlew :app:dependencies --configuration releaseRuntimeClasspath` and grep for the conflicting artifact to find which plugin pulled which version.
- **`local.properties` / `flutter.sdk` not set** — `android/settings.gradle.kts` reads `flutter.sdk` from `android/local.properties`; this file is gitignored and machine-specific, so a fresh checkout needs `flutter pub get` (which regenerates it) run first, not a manual edit.
- **`google-services.json` missing/mismatched** — required by the `com.google.gms.google-services` plugin (`android/app/build.gradle.kts:9`). Must live at `android/app/google-services.json` and its `package_name` must match `applicationId = "uz.intellectcrm.teacher"` exactly, or the plugin fails at sync time with a clear "No matching client found" error.
- **Signing config errors during a release build** — `android/app/build.gradle.kts` reads `android/key.properties`; if that file or `android/app/upload-keystore.jks` is missing/malformed, the build type falls back to the debug signing config silently rather than failing loudly (see the `if (keystorePropertiesFile.exists())` branch) — check [[release-checklist]] if a release build succeeds but produces a debug-signed artifact unexpectedly.
- **Kotlin/AGP version mismatch after a Flutter upgrade** — `flutter upgrade` can bump `flutter.compileSdkVersion`/`minSdkVersion`/`ndkVersion` (read from the Flutter Gradle plugin, not hardcoded here) out of step with the pinned AGP/Kotlin versions above; check `flutter --version` against the AGP compatibility table.

## Don't

- Don't blanket-suggest deleting `~/.gradle` or `$GRADLE_USER_HOME` as a first move — it forces a full re-download and rarely fixes anything `flutter clean` + `./gradlew clean` doesn't already fix.
- Don't bump AGP/Kotlin/Gradle versions in this file's table without also updating this SKILL.md — it will go stale otherwise.
