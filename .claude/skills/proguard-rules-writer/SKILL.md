---
name: proguard-rules-writer
description: Writes and maintains R8/ProGuard keep rules for the uz.intellectcrm.teacher Android app's Flutter plugin dependencies. Use when enabling minification, when a release build crashes with ClassNotFoundException/NoSuchMethodError, or when adding a new native/platform-channel plugin.
---

# ProGuard/R8 Rules Writer — uz.intellectcrm.teacher

## Where the rules file goes

This project has **no `android/app/proguard-rules.pro` yet** (confirmed absent as of last check — re-verify with `find android -iname "*.pro"`). To wire one up:

1. Create `android/app/proguard-rules.pro`.
2. Reference it in `android/app/build.gradle.kts` inside the `release` build type:
   ```kotlin
   release {
       isMinifyEnabled = true
       isShrinkResources = true
       proguardFiles(
           getDefaultProguardFile("proguard-android-optimize.txt"),
           "proguard-rules.pro"
       )
   }
   ```
   (This block doesn't exist yet either — `isMinifyEnabled`/`isShrinkResources` are currently `false` with no `proguardFiles(...)` call at all.)

## Baseline keep rules for this project's exact dependency set

Cross-check `pubspec.yaml` before trusting this list — it drifts. As of last check the deps needing R8 attention are:

```proguard
# Firebase Messaging / Core — reflection-based service discovery
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# flutter_local_notifications — uses reflection for scheduled notification receivers
-keep class com.dexterous.** { *; }

# Play Core split-install (referenced by Flutter's deferred components support even if unused)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Gson/JSON reflection used transitively by several plugins (image_picker, url_launcher)
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-keep class * implements java.io.Serializable { *; }
```

Most other packages in this project (`dio`, `go_router`, `provider`, `shared_preferences`, `fl_chart`, `intl`, `cached_network_image`, `url_launcher`, `image_picker`, `cupertino_icons`) are pure-Dart or thin platform-channel wrappers with no reflection-heavy Android code and typically need no extra rule — don't add speculative keep rules for them without first seeing them in `usage.txt` (see [[r8-analyzer]]).

## Workflow

1. Run a release build with minification on, then hand `usage.txt`/crash stack traces to [[r8-analyzer]] to find exactly what got stripped.
2. For each genuinely-needed rule, add the **narrowest** keep that fixes it — prefer `-keep class com.example.Foo { <init>(...); }` over `-keep class com.example.** { *; }` where possible, since broad rules defeat the point of shrinking.
3. Re-build, re-verify the specific crash is gone, and confirm APK/AAB size actually shrank (see [[aab-inspector]]) — a rule that's too broad silently un-shrinks large chunks of the app.
4. Never add `-dontobfuscate` or `-dontshrink` as a fix — that disables R8 entirely and defeats minification; fix the specific missing rule instead.
