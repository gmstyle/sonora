# APK Size Baseline

Measurements taken before any packaging optimisation, to give the split-per-ABI and R8 work a
reference point.

| | |
|---|---|
| Date | 2026-09-03 |
| App version | `1.7.4+60` (from `pubspec.yaml`) |
| Flutter | 3.47.x (project pins 3.47.2 in CI) |
| Build type | `release`, debug-signed locally (`key.properties` absent) |

## Commands

```bash
# Universal (fat) APK — what release.yml currently ships
flutter build apk --release
ls -la build/app/outputs/flutter-apk/app-release.apk

# arm64 with size breakdown
flutter build apk --release --analyze-size --target-platform android-arm64
```

## Totals

| Build | APK size |
|---|---|
| Universal (`flutter build apk --release`) | **125.7 MB** (as reported by the Flutter tool) |
| `--target-platform android-arm64` | **72,104,013 bytes** (68.8 MiB) |

## Top 15 entries, arm64 build

Uncompressed sizes from `apk-code-size-analysis_01.json`. Analysed total: 71,843,456 bytes (68.5 MiB).

| Size | Entry |
|---|---|
| 15.08 MiB | `lib/x86_64/libmpv.so` |
| 11.80 MiB | `lib/arm64-v8a/libmpv.so` |
| 11.20 MiB | `lib/arm64-v8a/libflutter.so` (Flutter Engine) |
| 11.20 MiB | `lib/armeabi-v7a/libmpv.so` |
| 1.65 MiB | `lib/arm64-v8a/libsqlite3.so` |
| 0.88 MiB | `lib/arm64-v8a/libapp.so` (Dart AOT, largest single node) |
| 0.66 MiB | `classes.dex` |
| 0.52 MiB | `res/AE.png` |
| 0.37 MiB | `lib/arm64-v8a/libmediakitandroidhelper.so` |
| 0.35 MiB | `lib/x86_64/libmediakitandroidhelper.so` |
| 0.27 MiB | `lib/armeabi-v7a/libmediakitandroidhelper.so` |
| 0.27 MiB | `res/9X.png` |
| 0.21 MiB | `assets/.../LucideVariable-w300.ttf` |
| 0.21 MiB | `assets/.../LucideVariable-w200.ttf` |
| 0.20 MiB | `resources.arsc` |

## Native libraries in the universal APK

All three ABIs are shipped in full. Uncompressed, per ABI:

| Library | armeabi-v7a | arm64-v8a | x86_64 |
|---|---|---|---|
| `libmpv.so` | 11,746,532 | 12,369,680 | 15,816,336 |
| `libapp.so` (Dart AOT) | 14,746,184 | 13,304,712 | 13,697,928 |
| `libflutter.so` | 8,615,900 | 11,747,864 | 13,051,424 |
| `libsqlite3.so` | 1,713,736 | 1,732,360 | 1,709,544 |
| `libmediakitandroidhelper.so` | 286,812 | 386,696 | 367,528 |
| `libdartjni.so` | 81,444 | 131,248 | 116,640 |
| `libdatastore_shared_counter.so` | 4,416 | 7,112 | 6,224 |
| **Total** | **~35.5 MiB** | **~37.8 MiB** | **~42.7 MiB** |

Roughly 116 MiB of the 125.7 MB APK is native code for three architectures.

## Finding: `--target-platform` does not filter plugin native libraries

The arm64-targeted build still contains, as dead weight:

| Entry | Size |
|---|---|
| `lib/x86_64/libmpv.so` | 15.08 MiB |
| `lib/armeabi-v7a/libmpv.so` | 11.20 MiB |
| `lib/x86_64/libmediakitandroidhelper.so` | 0.35 MiB |
| `lib/armeabi-v7a/libmediakitandroidhelper.so` | 0.27 MiB |
| **Total waste** | **~26.9 MiB** |

`--target-platform` only constrains the Flutter-produced `libapp.so` and `libflutter.so`. Native
libraries coming from plugin AARs — here `media_kit_libs_android_video`, which supplies `libmpv.so`
and `libmediakitandroidhelper.so` — are still packaged for every ABI, because
`android/app/build.gradle.kts` declares no `abiFilters` and the build uses no ABI splits.

The practical consequence is that only `--split-per-abi` (or an explicit `abiFilters`) actually
removes foreign-architecture `libmpv.so` copies. This is what task A3 addresses.

## After: split per ABI

Same source tree, `flutter build apk --release --split-per-abi`.

| APK | Size | Flutter-reported | vs universal |
|---|---|---|---|
| `app-arm64-v8a-release.apk` | 43,617,827 bytes | 43.6 MB | −65 % |
| `app-armeabi-v7a-release.apk` | 41,108,849 bytes | 41.1 MB | −67 % |
| `app-x86_64-release.apk` | 48,706,798 bytes | 48.7 MB | not shipped (emulator-only) |

Each split now carries exactly one `libmpv.so`, for its own architecture:

| APK | `libapp.so` | `libflutter.so` | `libmpv.so` |
|---|---|---|---|
| arm64-v8a | 13,304,712 | 11,747,864 | 12,369,680 |
| armeabi-v7a | 14,746,184 | 8,615,900 | 11,746,532 |

The ~26.9 MiB of foreign-ABI duplication is gone. A user on arm64 downloads 43.6 MB instead of
125.7 MB.

## R8 / resource shrinking: already enabled, no change needed

`android/app/build.gradle.kts` does not mention `isMinifyEnabled` or `isShrinkResources`, which
suggests minification is off. It is not: the Flutter Gradle plugin turns it on for release builds.

`packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:216-226`:

```kotlin
if (FlutterPluginUtils.shouldShrinkResources(project)) {
    releaseBuildType.isMinifyEnabled = true
    releaseBuildType.isShrinkResources = FlutterPluginUtils.isBuiltAsApp(project)
    releaseBuildType.proguardFiles.add(getDefaultProguardFile("proguard-android-optimize.txt"))
    releaseBuildType.proguardFiles.add(flutterProguardRules)
    // …and android/app/proguard-rules.pro when present
}
```

`shouldShrinkResources` defaults to `true`. The project's own `proguard-rules.pro` is picked up
automatically, which is why the existing `audio_service` keep rule works without being wired up.

Measured A/B on the arm64 split, same source tree:

| Configuration | APK size |
|---|---|
| As shipped (Flutter default, R8 on) | 43,617,827 bytes (43.6 MB) |
| `isMinifyEnabled = false`, `isShrinkResources = false` | 48,823,045 bytes (48.8 MB) |

R8 is already saving about 5.2 MB per APK. Adding an explicit `isMinifyEnabled = true` block was
tried and produced a **byte-identical** APK, confirming it is a no-op that only duplicates what the
Flutter plugin already does — with the added risk of an explicit `proguardFiles(...)` call that omits
Flutter's own `flutter_proguard_rules.pro`. The change was reverted.

No action taken for this item. Extra `-keep` rules were also reverted: the app already ships with R8
enabled and only the `audio_service` rule, so adding defensive keeps would fix no observed problem
and could only grow the APK.

## Summary

| Stage | arm64 download size |
|---|---|
| Universal APK (before) | 125.7 MB |
| Split per ABI (R8 already on) | 43.6 MB |

The single effective lever was the per-ABI split. R8 was already doing its part, and the remaining
weight is native code — `libmpv.so` (11.8 MiB), `libflutter.so` (11.2 MiB) and `libapp.so`
(12.7 MiB) — which no packaging flag can shrink further.
