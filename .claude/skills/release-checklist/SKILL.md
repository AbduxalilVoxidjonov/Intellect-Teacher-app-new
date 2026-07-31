---
name: release-checklist
description: Walks through the full Play Store release process for uz.intellectcrm.teacher (Intellect Teacher) — versioning, signing verification, AAB build, and pre-upload checks. Use before every Play Console upload.
---

# Release Checklist — Intellect Teacher (uz.intellectcrm.teacher)

## Before every release

1. **Bump the version.** Edit `version:` in `pubspec.yaml` (currently `1.0.0+2`). The number after `+` is `versionCode` and **must be strictly higher** than the last uploaded one, or Play Console rejects the upload outright. The part before `+` is the user-facing `versionName` — bump it too if this is a real feature/fix release, not just a re-upload.
2. **Verify signing files are present and untouched:**
   - `android/key.properties` (gitignored, machine-local)
   - `android/app/upload-keystore.jks` (alias `upload`, gitignored)
   - Do **not** read or print the contents of `key.properties` — it holds the keystore password. Just confirm both files exist: `ls android/key.properties android/app/upload-keystore.jks`.
   - If either is missing, `android/app/build.gradle.kts` silently falls back to **debug signing** for the release build type (see the `if (keystorePropertiesFile.exists())` branch) — the build will succeed but produce an artifact Play Console will reject as debug-signed. Always fail loud here rather than let a debug-signed AAB reach the upload step.
3. **Decide on minification.** As of the last check, `isMinifyEnabled = false` / `isShrinkResources = false` in the `release` build type — R8 is off. If turning it on for this release, run the [[r8-analyzer]] and [[proguard-rules-writer]] workflows and fully smoke-test the release build first; don't flip it on the same release you're about to ship without a dedicated test pass.
4. **Build the bundle:**
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.
   A "failed to strip debug symbols" warning during this build is benign (missing NDK strip tool) — the AAB is still valid, just slightly larger with native debug symbols retained. Don't treat it as a build failure.
5. **Confirm the signing certificate matches Play Console's expected upload key** before uploading — SHA1 fingerprint on record: `D0:B9:0A:E7:9F:C2:76:B9:28:C8:ED:BC:E9:23:2F:E7:34:D8:52:05`. Verify with:
   ```bash
   keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
   ```
   A mismatch here means either the wrong keystore file or Play Console's expected key rotated — stop and reconcile before uploading, since uploading with the wrong key gets the whole AAB rejected.
6. **Sanity-check bundle contents/size** — hand the built `.aab` to [[aab-inspector]] if a size regression or content mismatch is suspected.
7. **Upload to Play Console** — internal/closed testing track first unless this is a hotfix to an already-live release.

## Irreplaceable assets — handle with care

The upload keystore and its password **cannot be regenerated**. If lost, the app can never be updated again under the same Play Store listing — a new listing would be required, losing all reviews/installs/ranking. Never delete, move, or overwrite `android/app/upload-keystore.jks` or `android/key.properties` without a confirmed backup already in place, and never commit either to version control (both should stay gitignored).

## Related

[[r8-analyzer]] · [[proguard-rules-writer]] · [[aab-inspector]] · [[gradle-doctor]] for build-phase issues that come up during this process.
