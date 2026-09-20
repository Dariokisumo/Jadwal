# APK Build Configuration & Automation Guide — Jadwal

This document is the authoritative APK build guide, environment record, optimization reference, and automation specification for the **Jadwal** project.

> **CRITICAL RULES:**
> 1. **Do NOT build APKs automatically.** Only build an APK when the user explicitly requests/instructs it.
> 2. **Build both ABIs:** Whenever asked to build an APK (e.g. "build apk"), build **both** 64-bit (`arm64-v8a`) and 32-bit (`armeabi-v7a`) APKs using `make build-both` (or `make build` + `make build-arm32`), unless a specific ABI is explicitly requested.
> 3. **Check `apk.md` before building.** Always review this guide before triggering any build.
> 4. **Do NOT run `flutter clean` or wipe `~/.gradle/caches/`** unless explicitly approved by the user. Caches persist across builds and allow consecutive incremental builds to finish in **12–30 seconds**. A cold rebuild from scratch takes **15–20 minutes**.

---

## 1. Environment Record

All tool paths, environment variables, and versions have been verified and dynamically mapped.

### Verified Tooling & Paths

| Component | Path / Discovery Priority | Version | Notes |
| :--- | :--- | :--- | :--- |
| **JDK (Target)** | `/home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2` | Temurin OpenJDK 17.0.19+10 | Required for AGP 8.7.0 & Gradle 8.14.2 stability |
| **JDK (System)** | `/usr/lib/jvm/java-21-openjdk-amd64` | OpenJDK 21.0.12 | Available system-wide |
| **`java`** | `${JAVA_HOME}/bin/java` | 17.0.19 / 21.0.12 | Pre-tested and verified executable |
| **`javac`** | `${JAVA_HOME}/bin/javac` | 17.0.19 / 21.0.12 | Pre-tested and verified executable |
| **Android SDK** | `/usr/lib/android-sdk` (`sdk.dir` in `local.properties`) | SDK 34, 35, 36 | Secondary at `/home/node/android-sdk` |
| **Build Tools** | `/usr/lib/android-sdk/build-tools/36.0.0` | 36.0.0 (also 35, 34, 33) | In `PATH` |
| **Platform Tools** | `/usr/lib/android-sdk/platform-tools/adb` | 1.0.41 (SDK 37.0.0) | In `PATH` |
| **Android NDK** | `/usr/lib/android-sdk/ndk/28.2.13676358` | 28.2, 27.1, 26.3, 26.1 | Multiple NDK revisions available |
| **Gradle Wrapper** | `android/gradlew` | Gradle 8.14.2-all | Wrapper dist cached locally in `~/.gradle/wrapper/dists/` |
| **Android Gradle Plugin** | Plugin `com.android.application` in `android/settings.gradle` | 8.7.0 | Fully cached in `modules-2` |
| **Kotlin** | Plugin `org.jetbrains.kotlin.android` | 2.1.0 | Compose plugin `2.1.0` applied |
| **Flutter SDK** | `/home/node/.flutter/bin/flutter` | 3.44.2 stable | Framework rev `c9a6c48423`, Engine `04efd7c093` |
| **Dart SDK** | `/home/node/.flutter/bin/dart` | 3.12.2 stable | Linux x64 |
| **`aapt2`** | `/usr/lib/android-sdk/build-tools/36.0.0/aapt2` | 2.20-13193326 | Asset packaging tool |
| **`zipalign`** | `/usr/lib/android-sdk/build-tools/36.0.0/zipalign` | 36.0.0 | APK alignment tool |
| **`apksigner`** | `/usr/lib/android-sdk/build-tools/36.0.0/apksigner` | 0.9 (v2 scheme) | APK signing and verification tool |

### Environment Variables

The portable scripts automatically discover and export:

```bash
export JAVA_HOME="/home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2"
export ANDROID_HOME="/usr/lib/android-sdk"
export ANDROID_SDK_ROOT="/usr/lib/android-sdk"
export ANDROID_NDK_ROOT="/usr/lib/android-sdk/ndk/28.2.13676358"
export PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/build-tools/36.0.0:${ANDROID_HOME}/platform-tools:${PATH}"
```

---

## 2. Build Architecture

- **Root Project**: `/home/node/Documents/Lark/Jadwal`
- **Host Module**: `android/` (with main application module `android/app`)
- **Bytecode Target**: Java 11 (`sourceCompatibility = JavaVersion.VERSION_11`, `targetCompatibility = JavaVersion.VERSION_11`)
- **Desugaring**: `com.android.tools:desugar_jdk_libs:2.0.4` enabled for backward-compatible `java.time` APIs used by `flutter_local_notifications`.
- **Compose & Glance**:
  - `androidx.glance:glance-appwidget:1.1.1` & `glance-material3:1.1.1` for native home screen widgets (`JadwalGlanceWidget.kt`).
  - `androidx.compose:compose-bom:2024.12.01`.
- **Target Platforms / ABIs**:
  - **arm64-v8a** (Primary 64-bit release target): `--target-platform android-arm64` (~24.5 MB).
  - **armeabi-v7a** (32-bit release target): `--target-platform android-arm` (~22.1 MB).
  - Native libraries for other ABIs (`x86`, `x86_64`) are excluded in `android/app/build.gradle` to minimize APK payload size.
- **Signing**: Release builds use debug keystore signing (`signingConfigs.debug`) for straightforward direct APK side-loading and GitHub release distribution.
- **Output Directories**:
  - 64-bit APKs: `Apk files/jadwal-v<VERSION>-<BUILD>-release.apk`
  - 32-bit APKs: `Apk files/apk32/jadwal-v<VERSION>-<BUILD>-release.apk`

---

## 3. Cache Strategy & Reusable State

### Cache Inventory

| Cache | Location | Size | Strategy |
| :--- | :--- | :--- | :--- |
| **Gradle Dependency Cache** | `~/.gradle/caches/modules-2/` | ~2.0 GB | **PRESERVE**: Contains AGP, Kotlin, Compose, Glance, AndroidX |
| **Gradle Transforms / Daemon Cache** | `~/.gradle/caches/8.14.2/` | ~2.8 GB | **PRESERVE**: Transformed AARs, execution history, incremental metadata |
| **Gradle Build Cache** | `~/.gradle/caches/build-cache-1/` | ~168 MB | **PRESERVE**: Reusable task output artifacts across builds |
| **Gradle Wrapper Distributions** | `~/.gradle/wrapper/dists/` | ~300 MB | **PRESERVE**: Cached Gradle 8.14.2 binaries |
| **Flutter Build Intermediates** | `build/` | ~570 MB | **PRESERVE**: Compiled Dart kernel snapshot and merged Android intermediates |
| **Pub Cache** | `~/.pub-cache/` | ~900 MB | **PRESERVE**: Downloaded Dart package sources |

### Rules for Caches
1. **Never delete `~/.gradle/` or `build/`** during regular development.
2. The Gradle Daemon remains running (`PID 229052` or newest) in the background. It keeps JVM JIT optimizations warm.
3. Clean builds (`flutter clean`) should only be run if dependencies changed and an incremental build failed with an unresolvable corruption.

---

## 4. Build Optimizations Applied

The following optimizations are actively configured:

1. **Gradle Parallel Execution (`org.gradle.parallel=true`)**: Concurrently runs independent subproject tasks.
2. **Gradle Build Caching (`org.gradle.caching=true`)**: Reuses outputs from previous task executions.
3. **Configure on Demand (`org.gradle.configureondemand=true`)**: Only configures projects relevant to the requested task.
4. **Offline Mode (`org.gradle.offline=true`)**: Skips outbound network calls to repository mirrors on every build.
5. **High JVM Heap (`org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=1G -XX:+UseParallelGC`)**: Prevents OOM kills (exit code 143) and uses the high-throughput parallel garbage collector.
6. **Skip Pub Resolution (`--no-pub`)**: Prevents `flutter build` from re-analyzing `pubspec.lock` on every compile.
7. **Skip Icon Tree-Shaking (`--no-tree-shake-icons`)**: Cuts icon raster analysis time (~10s savings).
8. **Skip AGP Validation (`--android-skip-build-dependency-validation`)**: Skips redundant version checking (~5s savings).
9. **Skip R8 Shrinking (`--no-shrink`)**: Enabled by default in development/release builds for blazing **12–20s rebuild times**.
10. **Release Lint Check Disabled (`checkReleaseBuilds false`)**: Saves 30–60s on every release assemble pass.

---

## 5. Shell Automation Scripts (`scripts/`)

All build operations are automated via robust, portable bash scripts in `scripts/`:

### `scripts/common-env.sh`
- **Purpose**: Sourced by all scripts. Dynamically locates the JDK, Android SDK, build tools, NDK, Flutter SDK, Gradlew, and version info without hardcoding fragile absolute paths.
- **Portability**: Adapts to any environment with standard search orders.

### `scripts/verify-env.sh`
- **Purpose**: Pre-flight audit that validates all tools, executables, paths, Gradle daemon state, ABI filter consistency, and RAM/disk availability.
- **Run**:
  ```bash
  ./scripts/verify-env.sh
  # or via Makefile
  make verify
  ```

### `scripts/build-apk.sh`
- **Purpose**: Primary incremental build engine.
- **Flags**:
  - `--arm64`: Build 64-bit APK (`Apk files/`) [default]
  - `--arm32`: Build 32-bit APK (`Apk files/apk32/`)
  - `--both`: Build both arm64 and arm32 in sequence
  - `--copy-only`: Instant copy of existing built APK without invoking Gradle
  - `--no-shrink`: Skip R8 minification for fast builds [default]
  - `--shrink`: Enable R8 minification
  - `--pub`: Run `flutter pub get` before build
- **Safety Trap**: Automatically registers a `trap` for `--arm32` builds to guarantee `android/app/build.gradle` is reverted back to `arm64-v8a` even if interrupted (Ctrl+C) or errored.
- **Run**:
  ```bash
  ./scripts/build-apk.sh --arm64       # Fast 64-bit build
  ./scripts/build-apk.sh --arm32       # Fast 32-bit build
  ./scripts/build-apk.sh --both        # Sequential build for both ABIs
  ./scripts/build-apk.sh --copy-only   # Instant copy existing artifact
  ```

### `scripts/bump-version.sh`
- **Purpose**: Synchronously bumps semantic versioning across both `pubspec.yaml` and `lib/constants/app_version.dart`.
- **Run**:
  ```bash
  ./scripts/bump-version.sh patch      # e.g. 2.9.2+55 -> 2.9.3+56
  ./scripts/bump-version.sh minor      # e.g. 2.9.2+55 -> 2.10.0+56
  ./scripts/bump-version.sh major      # e.g. 2.9.2+55 -> 3.0.0+56
  ./scripts/bump-version.sh set 2.9.3 56
  ./scripts/bump-version.sh get
  ```

### `scripts/diagnose.sh`
- **Purpose**: Diagnostic tool to detect stuck ABI filters, cold daemons, memory constraints, and missing cached artifacts.
- **Flags**:
  - `--warmup`: Warms up the Gradle daemon in background
  - `--fix-abi`: Forces `android/app/build.gradle` back to `arm64-v8a`
- **Run**:
  ```bash
  ./scripts/diagnose.sh
  ./scripts/diagnose.sh --warmup
  ```

### `scripts/apk-info.sh`
- **Purpose**: Inspects generated APK badging, version codes, native ABIs, and cryptographically verifies signature schemes using `aapt2` and `apksigner`.
- **Run**:
  ```bash
  ./scripts/apk-info.sh                # Inspects newest built APK
  ./scripts/apk-info.sh "Apk files/jadwal-v2.9.2-55-release.apk"
  ```

---

## 6. Makefile Command Reference

The `Makefile` preserves 100% backward compatibility with previous workflows:

```bash
make build          # Build arm64-v8a APK -> Apk files/ (~12-30s)
make build-arm32    # Build armeabi-v7a APK -> Apk files/apk32/ (~40-60s)
make build-both     # Build arm64 and arm32 sequentially
make copy           # Instant copy existing arm64 build to Apk files/
make copy-arm32     # Instant copy existing arm32 build to Apk files/apk32/
make verify         # Run complete build environment verification
make diagnose       # Run diagnostics and daemon health check
make info           # Inspect latest generated APK with aapt2 and apksigner
make bump-patch     # Bump patch version in pubspec.yaml and app_version.dart
make bump-minor     # Bump minor version in pubspec.yaml and app_version.dart
make bump-major     # Bump major version in pubspec.yaml and app_version.dart
make clean          # flutter clean (ASK FIRST per critical rule!)
```

---

## 7. Versioning Workflow

Version information is maintained in two synchronized files:
1. `pubspec.yaml` line 4: `version: MAJOR.MINOR.PATCH+BUILD` (e.g. `2.9.2+55`)
2. `lib/constants/app_version.dart`:
   ```dart
   const String kAppVersion = '2.9.2';
   const int kAppBuildNumber = 55;
   ```

### Version Bumping Rules
- **Patch** (`1.0.X`): Bug fixes, layout tweaks, performance adjustments.
- **Minor** (`1.X.0`): New features, UI redesigns, theme updates.
- **Major** (`X.0.0`): Architecture changes, schema migrations.
- Always run `make bump-patch` or `make bump-minor` before building release APKs.

---

## 8. Build Workflow & Speed Comparison

### Cold vs. Warm Performance

| Scenario | Duration | Tasks |
| :--- | :--- | :--- |
| **Cold Build (Clean cache / no daemon)** | ~15–20 min | Downloads Gradle, AGP, Kotlin, Compose, compiles from scratch |
| **Warm Daemon (First build after edit)** | ~50–70s | Compiles changed Dart + reassembles APK |
| **Consecutive Rebuild (Warm cache & daemon)** | **12–14s** | Incremental Dart rebuild + APK packaging |
| **Copy existing build (`make copy`)** | **< 1s** | Direct file copy |

---

## 9. Diagnostics & Troubleshooting Matrix

### 1. `Toolchain installation does not provide the required capabilities: [JAVA_COMPILER]`
- **Cause**: Gradle attempting to use an incompatible system JDK (e.g. JDK 21 toolchain mismatch).
- **Fix**: The scripts automatically set `JAVA_HOME=/home/node/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2`. Run `./scripts/verify-env.sh` to confirm.

### 2. Gradle Daemon OOM (Exit code 143)
- **Cause**: Daemon heap too low for Compose/Glance compiler plugins.
- **Fix**: Ensure `android/gradle.properties` has `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=1G -XX:+UseParallelGC`. Do not lower below 8G.

### 3. ABI stuck on `armeabi-v7a`
- **Cause**: Previous arm32 build was killed before restoration.
- **Fix**: Run `./scripts/diagnose.sh --fix-abi`.

### 4. Gradle Wrapper fails to download in offline mode
- **Cause**: `distributionUrl` pointing to a version not cached in `~/.gradle/wrapper/dists/`.
- **Fix**: Ensure `gradle-8.14.2-all.zip` is specified in `android/gradle/wrapper/gradle-wrapper.properties`.

---

## 10. GitHub Releases Policy ("Git it")

**CRITICAL RULE:** Do NOT commit, push to GitHub, or create/update GitHub releases automatically after code edits.
Only update GitHub and its releases section when the user explicitly gives the command: **"Git it"**.

When the user says **"Git it"**:
1. Stage and commit the changed code with a clear descriptive commit message.
2. Push the commit(s) and any new tags to the remote repository (`origin main`).
3. If new APKs were built for a new version, publish the GitHub release with the changelog and upload both the 64-bit (`arm64`) and 32-bit (`arm32`) APK assets.
