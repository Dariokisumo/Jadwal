#!/usr/bin/env bash
# diagnose.sh — Comprehensive diagnostics and recovery utility for APK builds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-env.sh"

APP_GRADLE="${ANDROID_DIR}/app/build.gradle"
GRADLE_PROPS="${ANDROID_DIR}/gradle.properties"

WARMUP=false
FIX_ABI=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --warmup)
            WARMUP=true
            shift
            ;;
        --fix-abi)
            FIX_ABI=true
            shift
            ;;
        *)
            echo "Usage: $0 [--warmup] [--fix-abi]"
            exit 1
            ;;
    esac
done

echo -e "${C_BOLD}======================================================${C_RESET}"
echo -e "${C_BOLD}         Build Diagnostics & Health Check${C_RESET}"
echo -e "${C_BOLD}======================================================${C_RESET}"

# 1. ABI Check and Fix
echo -e "\n${C_BOLD}1. ABI Filter State:${C_RESET}"
if [ -f "${APP_GRADLE}" ]; then
    CURRENT_ABI="$(grep -o 'abiFilters "[^"]*"' "${APP_GRADLE}" | head -n 1 | cut -d'"' -f2 || true)"
    echo "  Current ABI in build.gradle: ${CURRENT_ABI}"
    if [ "${CURRENT_ABI}" = "armeabi-v7a" ]; then
        log_warn "ABI is stuck on 32-bit (armeabi-v7a)!"
        if [ "${FIX_ABI}" = true ]; then
            sed -i 's/abiFilters "armeabi-v7a"/abiFilters "arm64-v8a"/' "${APP_GRADLE}"
            sed -i "s|exclude 'lib/arm64-v8a/\*\*|exclude 'lib/armeabi-v7a/**|g" "${APP_GRADLE}"
            log_success "Restored default arm64-v8a in ${APP_GRADLE}"
        else
            echo -e "  ${C_YELLOW}→ Run: $0 --fix-abi to reset to arm64-v8a${C_RESET}"
        fi
    else
        log_success "ABI configuration is clean (${CURRENT_ABI})"
    fi
fi

# 2. Gradle Properties Check
echo -e "\n${C_BOLD}2. Gradle Configuration Tuning:${C_RESET}"
if [ -f "${GRADLE_PROPS}" ]; then
    JVM_ARGS="$(grep '^org.gradle.jvmargs=' "${GRADLE_PROPS}" | cut -d'=' -f2- || true)"
    PARALLEL="$(grep '^org.gradle.parallel=' "${GRADLE_PROPS}" | cut -d'=' -f2- || true)"
    CACHING="$(grep '^org.gradle.caching=' "${GRADLE_PROPS}" | cut -d'=' -f2- || true)"
    OFFLINE="$(grep '^org.gradle.offline=' "${GRADLE_PROPS}" | cut -d'=' -f2- || true)"

    echo "  JVM Args: ${JVM_ARGS}"
    if echo "${JVM_ARGS}" | grep -q "Xmx8G"; then
        log_success "JVM heap is 8GB (prevents exit code 143 OOM kills)"
    else
        log_warn "JVM heap is less than 8GB. Recommend setting -Xmx8G to prevent daemon OOM crashes."
    fi

    if [ "${PARALLEL}" = "true" ]; then
        log_success "Parallel execution enabled"
    else
        log_warn "Parallel execution not enabled"
    fi

    if [ "${CACHING}" = "true" ]; then
        log_success "Build caching enabled"
    else
        log_warn "Build caching not enabled"
    fi

    if [ "${OFFLINE}" = "true" ]; then
        log_success "Offline build enabled (skips online dependency resolution)"
    fi
fi

# 3. Gradle Daemon Status & Warmup
echo -e "\n${C_BOLD}3. Gradle Daemon Status:${C_RESET}"
if [ -n "${GRADLEW_BIN}" ] && [ -x "${GRADLEW_BIN}" ]; then
    DAEMON_OUT="$(JAVA_HOME="${JAVA_HOME}" "${GRADLEW_BIN}" --status 2>&1 || true)"
    echo "${DAEMON_OUT}"
    
    if echo "${DAEMON_OUT}" | grep -q "IDLE\|BUSY"; then
        log_success "Daemon is warm and ready."
    else
        log_warn "Daemon is cold or stopped."
        if [ "${WARMUP}" = true ]; then
            log_info "Warming up daemon now..."
            (cd "${ANDROID_DIR}" && JAVA_HOME="${JAVA_HOME}" "${GRADLEW_BIN}" --daemon --offline tasks >/dev/null 2>&1)
            log_success "Daemon warmed up successfully!"
        else
            echo -e "  ${C_YELLOW}→ Run: $0 --warmup to start and warm up the daemon (saves ~2 min on first build)${C_RESET}"
        fi
    fi
fi

# 4. Critical Dependencies Check (Compose / Glance / AGP)
echo -e "\n${C_BOLD}4. Cached Dependencies Check:${C_RESET}"
MOD_CACHE="${HOME}/.gradle/caches/modules-2/files-2.1"
if [ -d "${MOD_CACHE}" ]; then
    HAS_AGP="$(find "${MOD_CACHE}" -name "*gradle-8.7.0*" 2>/dev/null | head -n 1 || true)"
    HAS_GLANCE="$(find "${MOD_CACHE}" -name "*glance-appwidget*" 2>/dev/null | head -n 1 || true)"
    HAS_COMPOSE="$(find "${MOD_CACHE}" -name "*compose-bom*" 2>/dev/null | head -n 1 || true)"

    if [ -n "${HAS_AGP}" ]; then
        log_success "AGP 8.7.0 cached"
    else
        log_warn "AGP 8.7.0 not found in modules-2"
    fi

    if [ -n "${HAS_GLANCE}" ]; then
        log_success "Glance AppWidget cached"
    else
        log_warn "Glance AppWidget not found in modules-2"
    fi

    if [ -n "${HAS_COMPOSE}" ]; then
        log_success "Compose BOM cached"
    else
        log_warn "Compose BOM not found in modules-2"
    fi
fi

# 5. Output Directories
echo -e "\n${C_BOLD}5. Output APK Directories:${C_RESET}"
OUT_64="${PROJECT_ROOT}/Apk files"
OUT_32="${PROJECT_ROOT}/Apk files/apk32"
echo "  arm64: ${OUT_64} ($(ls -1 "${OUT_64}"/*.apk 2>/dev/null | wc -l) APKs present)"
echo "  arm32: ${OUT_32} ($(ls -1 "${OUT_32}"/*.apk 2>/dev/null | wc -l) APKs present)"

echo -e "\n${C_BOLD}======================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}Diagnostics complete.${C_RESET}"
