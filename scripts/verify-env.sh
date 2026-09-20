#!/usr/bin/env bash
# verify-env.sh — Verify the Android/APK build environment and all required tooling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-env.sh"

echo -e "${C_BOLD}======================================================${C_RESET}"
echo -e "${C_BOLD}     Android / APK Build Environment Audit & Verification${C_RESET}"
echo -e "${C_BOLD}======================================================${C_RESET}"

FAILURES=0
WARNINGS=0

check_pass() {
    echo -e "  [${C_GREEN}PASS${C_RESET}] $*"
}

check_warn() {
    echo -e "  [${C_YELLOW}WARN${C_RESET}] $*"
    WARNINGS=$((WARNINGS + 1))
}

check_fail() {
    echo -e "  [${C_RED}FAIL${C_RESET}] $*"
    FAILURES=$((FAILURES + 1))
}

# 1. Host Project
echo -e "\n${C_BOLD}1. Project Inspection${C_RESET}"
echo -e "  Root: ${PROJECT_ROOT}"
if [ "${IS_FLUTTER_PROJECT}" = true ]; then
    read -r APP_VER APP_BUILD <<< "$(get_project_version)"
    check_pass "Flutter project detected (Version: ${C_CYAN}${APP_VER}${C_RESET}, Build: ${C_CYAN}${APP_BUILD}${C_RESET})"
else
    check_pass "Native Android project detected"
fi

if [ -d "${ANDROID_DIR}" ]; then
    check_pass "Android module found at: ${ANDROID_DIR}"
else
    check_fail "Android directory not found!"
fi

# 2. JDK
echo -e "\n${C_BOLD}2. Java / JDK Environment${C_RESET}"
if [ -n "${JAVA_HOME}" ] && [ -d "${JAVA_HOME}" ]; then
    if [ -x "${JAVA_HOME}/bin/java" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
        JAVA_VER_STR="$("${JAVA_HOME}/bin/java" -version 2>&1 | head -n 1)"
        JAVAC_VER_STR="$("${JAVA_HOME}/bin/javac" -version 2>&1 | head -n 1)"
        check_pass "JAVA_HOME: ${JAVA_HOME}"
        check_pass "java:  ${JAVA_VER_STR}"
        check_pass "javac: ${JAVAC_VER_STR}"
        if echo "${JAVA_VER_STR}" | grep -q 'version "17'; then
            check_pass "JDK 17 verified (optimal for AGP 8.7.0 & Gradle 8.14.2)"
        else
            check_warn "Non-JDK 17 active (${JAVA_VER_STR}). JDK 17 is recommended for maximum stability."
        fi
    else
        check_fail "JAVA_HOME set (${JAVA_HOME}) but bin/java or bin/javac missing/not executable!"
    fi
else
    check_fail "No suitable JDK installation found!"
fi

# 3. Android SDK & Tools
echo -e "\n${C_BOLD}3. Android SDK & Platform Tools${C_RESET}"
if [ -n "${ANDROID_HOME}" ] && [ -d "${ANDROID_HOME}" ]; then
    check_pass "ANDROID_HOME: ${ANDROID_HOME}"
    
    # Platforms
    if [ -d "${ANDROID_HOME}/platforms" ]; then
        PLATFORMS="$(find "${ANDROID_HOME}/platforms" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')"
        if [ -n "${PLATFORMS}" ]; then
            check_pass "Platforms installed: ${PLATFORMS}"
        else
            check_fail "No Android platforms found in ${ANDROID_HOME}/platforms"
        fi
    else
        check_fail "Directory ${ANDROID_HOME}/platforms does not exist"
    fi

    # Build tools
    if [ -n "${BUILD_TOOLS_DIR}" ] && [ -d "${BUILD_TOOLS_DIR}" ]; then
        BT_VER="$(basename "${BUILD_TOOLS_DIR}")"
        check_pass "Build Tools: ${BT_VER} (${BUILD_TOOLS_DIR})"
    else
        check_fail "No Android build-tools found!"
    fi

    # aapt2
    if [ -x "${AAPT2_BIN}" ]; then
        AAPT_VER="$("${AAPT2_BIN}" version 2>&1 | head -n 1)"
        check_pass "aapt2: ${AAPT2_BIN} (${AAPT_VER})"
    else
        check_fail "aapt2 not executable or missing (${AAPT2_BIN})"
    fi

    # zipalign
    if [ -x "${ZIPALIGN_BIN}" ]; then
        check_pass "zipalign: ${ZIPALIGN_BIN}"
    else
        check_fail "zipalign not executable or missing (${ZIPALIGN_BIN})"
    fi

    # apksigner
    if [ -x "${APKSIGNER_BIN}" ]; then
        APKSIGNER_VER="$("${APKSIGNER_BIN}" --version 2>&1 | head -n 1)"
        check_pass "apksigner: ${APKSIGNER_BIN} (v${APKSIGNER_VER})"
    else
        check_fail "apksigner not executable or missing (${APKSIGNER_BIN})"
    fi

    # adb
    if [ -x "${ADB_BIN}" ]; then
        ADB_VER="$("${ADB_BIN}" --version 2>&1 | head -n 1)"
        check_pass "adb: ${ADB_BIN} (${ADB_VER})"
    else
        check_warn "adb not found in platform-tools"
    fi
else
    check_fail "Android SDK not found! Please check local.properties or ANDROID_HOME."
fi

# 4. Android NDK
echo -e "\n${C_BOLD}4. Android NDK${C_RESET}"
if [ -n "${ANDROID_NDK_ROOT}" ] && [ -d "${ANDROID_NDK_ROOT}" ]; then
    NDK_VER="$(basename "${ANDROID_NDK_ROOT}")"
    check_pass "NDK: ${NDK_VER} (${ANDROID_NDK_ROOT})"
else
    check_warn "No explicit NDK directory found (Flutter uses bundled or SDK NDK if needed)"
fi

# 5. Flutter & Dart
if [ "${IS_FLUTTER_PROJECT}" = true ]; then
    echo -e "\n${C_BOLD}5. Flutter & Dart SDK${C_RESET}"
    if [ -x "${FLUTTER_BIN}" ]; then
        FL_VER="$("${FLUTTER_BIN}" --version 2>&1 | head -n 1)"
        check_pass "Flutter: ${FL_VER}"
    else
        check_fail "Flutter binary not found or not executable (${FLUTTER_BIN})"
    fi

    if [ -x "${DART_BIN}" ]; then
        DART_VER="$("${DART_BIN}" --version 2>&1 | head -n 1)"
        check_pass "Dart: ${DART_VER}"
    else
        check_warn "Dart binary not found directly"
    fi
fi

# 6. Gradle & Gradle Daemon
echo -e "\n${C_BOLD}6. Gradle & Daemon Status${C_RESET}"
if [ -n "${GRADLEW_BIN}" ] && [ -x "${GRADLEW_BIN}" ]; then
    check_pass "Gradle wrapper: ${GRADLEW_BIN}"
    
    # Check wrapper properties
    if [ -f "${ANDROID_DIR}/gradle/wrapper/gradle-wrapper.properties" ]; then
        DIST_URL="$(grep '^distributionUrl=' "${ANDROID_DIR}/gradle/wrapper/gradle-wrapper.properties" | cut -d'=' -f2)"
        check_pass "Gradle distribution: ${DIST_URL}"
    fi

    # Daemon status
    DAEMON_OUT="$(JAVA_HOME="${JAVA_HOME}" "${GRADLEW_BIN}" --status 2>&1 || true)"
    if echo "${DAEMON_OUT}" | grep -q "IDLE\|BUSY"; then
        RUNNING_DAEMON="$(echo "${DAEMON_OUT}" | grep -E "IDLE|BUSY" | head -n 1 | awk '{print $1 " (" $2 ", " $3 ")"}')"
        check_pass "Gradle Daemon active: PID ${RUNNING_DAEMON}"
    else
        check_warn "No active Gradle daemon currently running (first build will warm it up)"
    fi
else
    check_fail "Gradle wrapper (gradlew) not found or not executable!"
fi

# 7. Cache Inventory
echo -e "\n${C_BOLD}7. Build Caches${C_RESET}"
GRADLE_CACHE_DIR="${HOME}/.gradle/caches"
if [ -d "${GRADLE_CACHE_DIR}/modules-2" ]; then
    MOD_SIZE="$(du -sh "${GRADLE_CACHE_DIR}/modules-2" 2>/dev/null | cut -f1)"
    check_pass "Gradle modules-2 dependency cache: ${MOD_SIZE}"
else
    check_warn "Gradle modules-2 cache empty or missing"
fi

if [ -d "${GRADLE_CACHE_DIR}/build-cache-1" ]; then
    BC_SIZE="$(du -sh "${GRADLE_CACHE_DIR}/build-cache-1" 2>/dev/null | cut -f1)"
    check_pass "Gradle build-cache-1: ${BC_SIZE}"
fi

if [ -d "${PROJECT_ROOT}/build" ]; then
    BLD_SIZE="$(du -sh "${PROJECT_ROOT}/build" 2>/dev/null | cut -f1)"
    check_pass "Project build/ intermediates: ${BLD_SIZE}"
fi

# 8. ABI Configuration Integrity
echo -e "\n${C_BOLD}8. ABI Configuration Integrity${C_RESET}"
APP_GRADLE="${ANDROID_DIR}/app/build.gradle"
if [ -f "${APP_GRADLE}" ]; then
    CURRENT_ABI="$(grep -o 'abiFilters "[^"]*"' "${APP_GRADLE}" | head -n 1 | cut -d'"' -f2 || true)"
    if [ "${CURRENT_ABI}" = "arm64-v8a" ]; then
        check_pass "Default ABI filter: arm64-v8a (correct)"
    elif [ "${CURRENT_ABI}" = "armeabi-v7a" ]; then
        check_warn "ABI filter currently set to armeabi-v7a (32-bit). Normal default should be arm64-v8a."
    else
        check_info="ABI filter: ${CURRENT_ABI:-None specified}"
        check_pass "${check_info}"
    fi
fi

# 9. System Resources
echo -e "\n${C_BOLD}9. System Resources${C_RESET}"
MEM_AVAIL="$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')"
MEM_TOTAL="$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')"
DISK_AVAIL="$(df -h "${PROJECT_ROOT}" 2>/dev/null | awk 'NR==2 {print $4}')"
CPUS="$(nproc 2>/dev/null || echo "1")"
check_pass "CPUs: ${CPUS} cores | RAM: ${MEM_AVAIL} available / ${MEM_TOTAL} total | Disk: ${DISK_AVAIL} free"

# Summary
echo -e "\n${C_BOLD}======================================================${C_RESET}"
if [ ${FAILURES} -eq 0 ]; then
    echo -e "${C_GREEN}${C_BOLD}✔ Environment verification PASSED (${WARNINGS} warnings). Ready for fast builds.${C_RESET}"
    exit 0
else
    echo -e "${C_RED}${C_BOLD}✖ Environment verification FAILED (${FAILURES} errors, ${WARNINGS} warnings).${C_RESET}"
    exit 1
fi
