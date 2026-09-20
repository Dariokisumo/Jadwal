#!/usr/bin/env bash
# common-env.sh — Portable environment discovery for Android/Flutter builds

# Resolve script and project root dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ANSI formatting
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_DIM="\033[2m"
    C_RED="\033[31m"
    C_GREEN="\033[32m"
    C_YELLOW="\033[33m"
    C_BLUE="\033[34m"
    C_CYAN="\033[36m"
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
fi

log_info()    { echo -e "${C_CYAN}ℹ${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}✔${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}⚠${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}✖${C_RESET} $*" >&2; }

# -----------------------------------------------------------------------------
# 1. Project Type & Directories
# -----------------------------------------------------------------------------
IS_FLUTTER_PROJECT=false
if [ -f "${PROJECT_ROOT}/pubspec.yaml" ]; then
    IS_FLUTTER_PROJECT=true
fi

ANDROID_DIR="${PROJECT_ROOT}/android"
if [ ! -d "${ANDROID_DIR}" ] && [ -f "${PROJECT_ROOT}/build.gradle" ]; then
    ANDROID_DIR="${PROJECT_ROOT}"
fi

# -----------------------------------------------------------------------------
# 2. JDK Discovery (Prioritize JDK 17 for Gradle 8.x / AGP 8.x stability)
# -----------------------------------------------------------------------------
discover_jdk() {
    local candidate=""

    # 1. Check existing JAVA_HOME if valid and is Java 17
    if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
        if "${JAVA_HOME}/bin/java" -version 2>&1 | grep -q 'version "17'; then
            candidate="${JAVA_HOME}"
        fi
    fi

    # 2. Check Gradle cached JDKs (eclipse_adoptium-17)
    if [ -z "${candidate}" ]; then
        for dir in "${HOME}/.gradle/jdks"/eclipse_adoptium-17* /home/node/.gradle/jdks/eclipse_adoptium-17*; do
            if [ -d "${dir}" ] && [ -x "${dir}/bin/java" ]; then
                candidate="${dir}"
                break
            fi
        done
    fi

    # 3. Check system JVM directories for Java 17
    if [ -z "${candidate}" ]; then
        for dir in /usr/lib/jvm/java-17-openjdk* /usr/lib/jvm/temurin-17*; do
            if [ -d "${dir}" ] && [ -x "${dir}/bin/java" ]; then
                candidate="${dir}"
                break
            fi
        done
    fi

    # 4. Fallback to existing JAVA_HOME or system java if no Java 17 found
    if [ -z "${candidate}" ]; then
        if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
            candidate="${JAVA_HOME}"
        elif [ -d "/usr/lib/jvm/default-java" ]; then
            candidate="/usr/lib/jvm/default-java"
        elif command -v java >/dev/null 2>&1; then
            candidate="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
        fi
    fi

    echo "${candidate}"
}

JAVA_HOME="$(discover_jdk)"
export JAVA_HOME
if [ -n "${JAVA_HOME}" ] && [ -d "${JAVA_HOME}/bin" ]; then
    PATH="${JAVA_HOME}/bin:${PATH}"
fi

# -----------------------------------------------------------------------------
# 3. Android SDK Discovery
# -----------------------------------------------------------------------------
discover_android_sdk() {
    local candidate=""

    # 1. Check android/local.properties
    if [ -f "${ANDROID_DIR}/local.properties" ]; then
        candidate="$(grep '^sdk.dir=' "${ANDROID_DIR}/local.properties" 2>/dev/null | cut -d'=' -f2- | tr -d '\r' | sed 's/\\:/:/g')"
    fi

    # 2. Check environment variables
    if [ -z "${candidate}" ] || [ ! -d "${candidate}" ]; then
        if [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}" ]; then
            candidate="${ANDROID_HOME}"
        elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}" ]; then
            candidate="${ANDROID_SDK_ROOT}"
        fi
    fi

    # 3. Standard Linux / User paths
    if [ -z "${candidate}" ] || [ ! -d "${candidate}" ]; then
        for dir in "/usr/lib/android-sdk" "${HOME}/android-sdk" "${HOME}/Android/Sdk"; do
            if [ -d "${dir}" ]; then
                candidate="${dir}"
                break
            fi
        done
    fi

    echo "${candidate}"
}

ANDROID_HOME="$(discover_android_sdk)"
ANDROID_SDK_ROOT="${ANDROID_HOME}"
export ANDROID_HOME ANDROID_SDK_ROOT

# -----------------------------------------------------------------------------
# 4. Android Build Tools, Platform Tools, NDK
# -----------------------------------------------------------------------------
discover_build_tools() {
    local candidate=""
    if [ -d "${ANDROID_HOME}/build-tools" ]; then
        # Pick highest version directory
        candidate="$(find "${ANDROID_HOME}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
    fi
    echo "${candidate}"
}

BUILD_TOOLS_DIR="$(discover_build_tools)"

if [ -n "${BUILD_TOOLS_DIR}" ]; then
    AAPT2_BIN="${BUILD_TOOLS_DIR}/aapt2"
    ZIPALIGN_BIN="${BUILD_TOOLS_DIR}/zipalign"
    APKSIGNER_BIN="${BUILD_TOOLS_DIR}/apksigner"
    PATH="${BUILD_TOOLS_DIR}:${PATH}"
else
    AAPT2_BIN="$(command -v aapt2 2>/dev/null || true)"
    ZIPALIGN_BIN="$(command -v zipalign 2>/dev/null || true)"
    APKSIGNER_BIN="$(command -v apksigner 2>/dev/null || true)"
fi

if [ -d "${ANDROID_HOME}/platform-tools" ]; then
    ADB_BIN="${ANDROID_HOME}/platform-tools/adb"
    PATH="${ANDROID_HOME}/platform-tools:${PATH}"
else
    ADB_BIN="$(command -v adb 2>/dev/null || true)"
fi

discover_ndk() {
    local candidate=""
    if [ -n "${ANDROID_NDK_ROOT:-}" ] && [ -d "${ANDROID_NDK_ROOT}" ]; then
        candidate="${ANDROID_NDK_ROOT}"
    elif [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "${ANDROID_NDK_HOME}" ]; then
        candidate="${ANDROID_NDK_HOME}"
    elif [ -d "${ANDROID_HOME}/ndk" ]; then
        candidate="$(find "${ANDROID_HOME}/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
    fi
    echo "${candidate}"
}

ANDROID_NDK_ROOT="$(discover_ndk)"
export ANDROID_NDK_ROOT

# -----------------------------------------------------------------------------
# 5. Flutter SDK Discovery
# -----------------------------------------------------------------------------
discover_flutter() {
    local candidate=""

    # Check local.properties
    if [ -f "${ANDROID_DIR}/local.properties" ]; then
        candidate="$(grep '^flutter.sdk=' "${ANDROID_DIR}/local.properties" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')"
        if [ -n "${candidate}" ] && [ -x "${candidate}/bin/flutter" ]; then
            echo "${candidate}"
            return
        fi
    fi

    # Check PATH
    if command -v flutter >/dev/null 2>&1; then
        local fl_path
        fl_path="$(readlink -f "$(command -v flutter)")"
        candidate="$(dirname "$(dirname "${fl_path}")")"
        if [ -x "${candidate}/bin/flutter" ]; then
            echo "${candidate}"
            return
        fi
    fi

    # Check standard paths
    for dir in "${HOME}/.flutter" "/usr/local/flutter" "/opt/flutter"; do
        if [ -x "${dir}/bin/flutter" ]; then
            candidate="${dir}"
            break
        fi
    done

    echo "${candidate}"
}

FLUTTER_SDK="$(discover_flutter)"
if [ -n "${FLUTTER_SDK}" ]; then
    FLUTTER_BIN="${FLUTTER_SDK}/bin/flutter"
    DART_BIN="${FLUTTER_SDK}/bin/dart"
    PATH="${FLUTTER_SDK}/bin:${PATH}"
else
    FLUTTER_BIN="$(command -v flutter 2>/dev/null || true)"
    DART_BIN="$(command -v dart 2>/dev/null || true)"
fi

# -----------------------------------------------------------------------------
# 6. Gradle Wrapper Discovery
# -----------------------------------------------------------------------------
GRADLEW_BIN=""
if [ -x "${ANDROID_DIR}/gradlew" ]; then
    GRADLEW_BIN="${ANDROID_DIR}/gradlew"
elif [ -x "${PROJECT_ROOT}/gradlew" ]; then
    GRADLEW_BIN="${PROJECT_ROOT}/gradlew"
elif command -v gradle >/dev/null 2>&1; then
    GRADLEW_BIN="$(command -v gradle)"
fi

# -----------------------------------------------------------------------------
# 7. Version Helper
# -----------------------------------------------------------------------------
get_project_version() {
    local ver=""
    local bld=""

    if [ "${IS_FLUTTER_PROJECT}" = true ] && [ -f "${PROJECT_ROOT}/pubspec.yaml" ]; then
        local raw_ver
        raw_ver="$(grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | awk '{print $2}' | tr -d '\r')"
        ver="${raw_ver%+*}"
        if [[ "${raw_ver}" == *"+"* ]]; then
            bld="${raw_ver#*+}"
        fi
    elif [ -f "${ANDROID_DIR}/local.properties" ]; then
        ver="$(grep '^flutter.versionName=' "${ANDROID_DIR}/local.properties" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')"
        bld="$(grep '^flutter.versionCode=' "${ANDROID_DIR}/local.properties" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')"
    fi

    # Fallback to defaults if missing
    ver="${ver:-1.0.0}"
    bld="${bld:-1}"

    echo "${ver} ${bld}"
}
