# APK Build Configuration — Jadwal

## CRITICAL: Do NOT clean caches unless explicitly approved

Running `flutter clean` or clearing `~/.gradle/caches/` / `~/.pub-cache/` forces a full
cold rebuild (~15-20 min download + compile). **Always ask the user before doing this.**

**The only** valid reason to clean: deps changed AND quick rebuild fails.

## Use Makefile (recommended)
```bash
make build          # arm64-v8a -> Apk files/ (default)
make build-arm32    # armeabi-v7a -> Apk files/apk32/
make copy           # just copy existing arm64 APK to Apk files/
make copy-arm32     # just copy existing arm32 APK to Apk files/apk32/
make clean          # flutter clean (DON'T without asking)
```

The Makefile uses `--android-skip-build-dependency-validation --no-tree-shake-icons --no-pub`.
JAVA_HOME points to **JDK 17** (`/home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2`).

## Manual Build (when Makefile not available)
```bash
cd /home/node/Documents/Lark/jadwal
# arm64 (default)
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk \
  "Apk files/jadwal-v$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')-$(grep '^version:' pubspec.yaml | sed 's/.*+//')-release.apk"

# arm32 (armeabi-v7a) -> Apk files/apk32/
flutter build apk --release --target-platform android-arm
cp build/app/outputs/flutter-apk/app-release.apk \
  "Apk files/apk32/jadwal-v$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')-$(grep '^version:' pubspec.yaml | sed 's/.*+//')-release.apk"
# Note: also swap abiFilters in android/app/build.gradle (arm64-v8a <-> armeabi-v7a)
# and packagingOptions excludes accordingly. Makefile does this automatically.
```

**No `flutter clean` or `pub get` needed** — caches persist across builds.

## Last Resort: Full Rebuild (ASK USER FIRST)
```bash
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64
# ...copy command same as above
```

## Cached Artifacts (after a successful build)

Everything is NOW cached — a second build recompiles only changed Dart (~30-60s).

### Which Gradle versions are cached

| Status | Version | Location |
|--------|---------|----------|
| ✅ Fully cached | **8.14.2** (project default) | `~/.gradle/wrapper/dists/gradle-8.14.2-all/` (224MB .zip) |
| ✅ Fully cached | **9.1.0** (fallback) | `~/.gradle/wrapper/dists/gradle-9.1.0-all/` |
| ✅ Fully cached | **9.3.1** (bin only) | `~/.gradle/wrapper/dists/gradle-9.3.1-bin/` |

### Which AGP versions are cached (`modules-2`)

| Version | Cached? | Notes |
|---------|---------|-------|
| 8.7.0 | ✅ | Project default — fully cached after first build |
| 9.0.1 | ✅ | Available as fallback if ever needed |

### Which Kotlin versions are cached

| Version | Plugin marker | Compiler |
|---------|:------------:|:--------:|
| 2.1.0 | ✅ (project default) | ✅ |
| 2.2.20 | ❌ | ✅ |
| 2.3.20 | ✅ | ✅ |
| others | ❌ | 1.7.10, 1.9.0, 1.9.10 |

**Compose plugin** (`org.jetbrains.kotlin.plugin.compose`) — NOT cached for any version.
First build will download it (~2MB). After first download it is cached.

### What's in `~/.gradle/caches/`

```
~/.gradle/caches/
├── 8.14.2/               # Gradle version-specific cache (transforms, etc.)
├── 9.1.0/                # Fallback Gradle version cache
├── modules-2/            # Shared dependency JARs/AARs (AGP, Kotlin, AndroidX, Compose, Glance)
└── jars-9/               # Gradle-internal jars
```

| Cache | Location | Purpose |
|-------|----------|---------|
| Gradle Module Cache | `~/.gradle/caches/modules-2/` | AGP, Kotlin, AndroidX, Compose, Glance — ~2GB |
| Gradle Transforms | `~/.gradle/caches/<version>/transforms/` | Processed AARs/JARs |
| Gradle Wrapper | `~/.gradle/wrapper/dists/` | Gradle binaries (8.14.2 + 9.1.0 + 9.3.1) |
| Flutter Build | `build/` | Compiled Dart AOT, merged manifests |
| Flutter SDK | `~/.flutter/bin/cache/` | Dart SDK, engine, platform files (~820MB) |
| Pub Cache | `~/.pub-cache/` | All Dart/Flutter packages (~900MB) |

## Key Paths
| Item | Path |
|------|------|
| Flutter SDK | `/home/node/.flutter/bin/flutter` |
| Android SDK | `/home/node/android-sdk` |
| Platform tools | `/home/node/android-sdk/platform-tools` |
| Platforms | 34, 35, 36 |
| Build tools | 34.0.0, 35.0.0, 36.0.0 |
| NDK | `/home/node/android-sdk/ndk/` (26.1.10909125, 28.2.13676358) |
| JDK (system) | `/usr/lib/jvm/java-21-openjdk-amd64` |
| JDK (Makefile) | `/home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2` |
| Build output | `build/app/outputs/flutter-apk/` |
| Release folder (arm64) | `Apk files/` |
| Release folder (arm32) | `Apk files/apk32/` |

## Speed Tips

- **Gradle parallel + caching** — `gradle.properties` enables `org.gradle.parallel=true` and `org.gradle.caching=true`. Parallel runs independent tasks concurrently; caching reuses unchanged task outputs across builds. Big wins (30-50% on rebuilds).
- **`-XX:+UseParallelGC`** — JVM flag in `gradle.properties` uses the parallel garbage collector (faster for batch-style Gradle work than G1GC).
- **Skip `flutter pub get`** if deps unchanged — `--no-pub` is already in the Makefile.
- **Gradle daemon** stays alive between builds — first build warms it, subsequent builds reuse it.
- **Flutter incremental** — only changed Dart files recompile (~30-60s). Avoid `flutter clean`.
- **`--android-skip-build-dependency-validation`** (in Makefile) skips AGP/Kotlin version checks — saves ~5s.
- **`--no-tree-shake-icons`** (in Makefile) skips icon tree-shaking — saves ~10s
- **`--no-shrink`** (in Makefile) skips R8/ProGuard — saves ~30-60s on release builds.
- **Lint disabled for release builds** — `checkReleaseBuilds false` in `app/build.gradle` saves ~30-60s.

## Pre-Build Warmup (critical for speed)

If the Gradle daemon is cold (e.g. after reboot or OOM kill), **always warm it first**:

```bash
cd android && ./gradlew --daemon --offline tasks > /dev/null 2>&1
```

Then build with `make build`. This cuts build time from ~3min to ~1min.

**Check daemon status:** `./gradlew --status` — should show `RUNNING`, not `STOPPED`.

## JVM Heap

`gradle.properties` must have adequate heap. **Do not go below `-Xmx8G`** — 4G causes OOM kills (exit code 143) which kills the daemon and forces a cold restart on the next build:

```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=1G -XX:+UseParallelGC
```

## Offline Build

`flutter build apk` has **no `--offline` flag**. To build offline:
- Set `org.gradle.offline=true` in `android/gradle.properties` (Gradle won't fetch deps)
- Use `--no-pub` to skip `flutter pub get`
- The Makefile relies on Gradle's offline mode via `gradle.properties`

## Pre-Build Warmup (saves ~2min)

If the Gradle daemon is cold (check with `./gradlew --status`), warm it first:

```bash
cd android && ./gradlew --daemon --offline tasks > /dev/null 2>&1
cd .. && make build
```

Cold build (no daemon): ~3min. Warm daemon + incremental: ~30-60s.

## JVM Heap — Critical

`gradle.properties` must have adequate heap. **`-Xmx4G` causes OOM kills** (exit code 143) which kills the daemon and forces a cold restart. Use at least 8G:

```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=1G -XX:+UseParallelGC
```

## Offline Build

`flutter build apk` has **no `--offline` flag**. To build fully offline:
- Set `org.gradle.offline=true` in `android/gradle.properties` (already done)
- Use `--no-pub` to skip `flutter pub get` (already in Makefile)
- Ensure all deps are cached from a previous successful build

## APK Size Reduction

Removed unused native libraries — one ABI per APK:
- **arm64** (`Apk files/`): `ndk { abiFilters "arm64-v8a" }`, `packagingOptions` excludes `lib/x86_64/**`, `lib/armeabi-v7a/**`, etc. Final: ~23.8-24.5MB
- **arm32** (`Apk files/apk32/`): `ndk { abiFilters "armeabi-v7a" }`, `packagingOptions` excludes `lib/arm64-v8a/**`, `lib/x86_64/**`, etc. Final: ~21.9MB
- `make build-arm32` swaps `abiFilters` + `packagingOptions` automatically, builds, then restores arm64 default.
- Saved ~240KB per APK vs fat build. `build.gradle` defaults to `arm64-v8a` after build.

**All Compose/Glance deps are required** — the home screen widget (`JadwalGlanceWidget.kt`) uses Glance + Compose. `coreLibraryDesugaring` is required by `flutter_local_notifications`. `uses-material-design: true` is required for 34 Material icons..

## Version

Current: `2.1.2+40` (in `pubspec.yaml`)

Edit `pubspec.yaml` line 4 — version format: `MAJOR.MINOR.PATCH+BUILD`
- Display: `MAJOR.MINOR.PATCH` (e.g. `1.8.2`)
- Build number: `+BUILD` — must increase each release (e.g. `+26`)
- Example: `1.8.1+24` → `1.8.2+25`

APK picks up version automatically from pubspec — no manual Android edits.

## Output
- `Apk files/jadwal-v2.1.2-40-release.apk` (arm64-v8a only, ~24.8MB) — `make build`
- `Apk files/apk32/jadwal-v2.1.2-40-release.apk` (armeabi-v7a only, ~22.2MB) — `make build-arm32`

## GitHub Releases & Sync Policy ("Git it")

**CRITICAL RULE:** Do NOT automatically commit, push to GitHub, or create/update releases on GitHub after code edits or builds.
Only sync with GitHub and publish releases when the user explicitly says: **"Git it"**.

When the user says **"Git it"**:
1. Commit local code changes with a clean, descriptive message.
2. Push commits and any local tags to the remote repository.
3. If new APKs exist for a bumped version, create a GitHub release with a formatted changelog and upload both the 64-bit (`arm64`) and 32-bit (`arm32`) APK assets.

## Build Issues & Fixes

### 1. Offline build fails — Gradle wrapper can't download
- **Symptoms:** `UnknownHostException: services.gradle.org` or `PluginResolutionException`
- **Root cause:** Gradle wrapper tries to download the `.zip` distribution; cached version doesn't match `gradle-wrapper.properties`
- **Fix:** Point wrapper to a cached Gradle version:
  ```bash
  # Check what's cached:
  ls ~/.gradle/wrapper/dists/
  # Edit android/gradle/wrapper/gradle-wrapper.properties:
  # distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-all.zip
  ```

### 2. Offline build fails — AGP not cached
- **Symptoms:** `Plugin [id: 'com.android.application', version: '8.7.0'] was not found`
- **Fix:** Use cached AGP version or ensure network: 
  ```bash
  # Check cached AGP:
  ls ~/.gradle/caches/modules-2/files-2.1/com.android.application/com.android.application.gradle.plugin/
  # Edit android/settings.gradle to use cached version (e.g. 9.0.1)
  ```

### 3. Offline build fails — Compose/Glance deps not cached
- **Symptoms:** Missing `androidx.compose` or `androidx.glance` artifacts
- **Root cause:** Compose/Glance are NOT in `modules-2` after fresh cache — they live in Gradle version-specific cache. First successful build downloads them.
- **Fix:** Need internet for first build after cache clean.

### 4. Offline build fails — Kotlin compose plugin not cached
- **Symptoms:** `Plugin [id: 'org.jetbrains.kotlin.plugin.compose'] was not found`
- **Root cause:** Compose plugin marker (~2MB) is never cached offline
- **Fix:** Need internet for at least one build.

### 5. DNS resolution flaky
- **Symptoms:** `plugins-artifacts.gradle.org: Name or service not known`
- **Fix:** Retry build — DNS works intermittently.
- **Workaround:** Add `--android-skip-build-dependency-validation` to skip AGP/Kotlin version checks (already in Makefile).

### 6. Gradle JDK toolchain detection failure
- **Error:** `Toolchain installation does not provide the required capabilities: [JAVA_COMPILER]`
- **Fix:** Set `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` before build.
- The Makefile uses JDK 17 which works without this issue.

### 7. ABI split conflict with NDK abiFilters
- **Fix:** Use `--target-platform android-arm64` flag (already in command).

## What to do when caches are clean (first build on fresh machine)

1. Ensure **internet is available**
2. Run `make build` (or the manual build command)
3. First build takes **5-10 min** (downloads Gradle 8.14.2, AGP 8.7.0, Kotlin 2.1.0, Compose BOM, Glance, all transitive deps)
4. Subsequent builds take **30-60s**

## What files were modified / settings
- `pubspec.yaml` — version, Compose/Glance deps (from Flutter project template)
- `android/settings.gradle` — AGP 8.7.0, Kotlin 2.1.0, Kotlin compose plugin 2.1.0, Flutter plugin loader
- `android/app/build.gradle` — release signing (debug), minification, ProGuard, lint disabled for releases (`checkReleaseBuilds false`), Compose, Glance widget deps
- `android/gradle.properties` — JVM args (8G heap, `-XX:+UseParallelGC`), parallel execution (`org.gradle.parallel=true`), build caching (`org.gradle.caching=true`), AndroidX flags
- `android/gradle/wrapper/gradle-wrapper.properties` — points to Gradle 8.14.2-all
