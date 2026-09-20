#!/usr/bin/env bash
# build-apk.sh — Fast, repeatable, incremental APK build runner for Jadwal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-env.sh"

APP_GRADLE="${ANDROID_DIR}/app/build.gradle"
APK_INTERMEDIATE_DIR="${PROJECT_ROOT}/build/app/outputs/flutter-apk"

# Default build parameters
TARGET_ARCH="arm64"      # arm64, arm32, or both
BUILD_TYPE="release"     # release or debug
COPY_ONLY=false
SHRINK_FLAG="--no-shrink"
PUB_FLAG="--no-pub"
EXTRA_FLAGS=(
    "--android-skip-build-dependency-validation"
    "--no-tree-shake-icons"
)

usage() {
    echo -e "${C_BOLD}Usage:${C_RESET} $0 [options]"
    echo ""
    echo "Architecture Options:"
    echo "  --arm64         Build arm64-v8a (64-bit) APK -> Apk files/ (default)"
    echo "  --arm32         Build armeabi-v7a (32-bit) APK -> Apk files/apk32/"
    echo "  --both          Build both arm64 and arm32 in sequence"
    echo ""
    echo "Build Mode Options:"
    echo "  --release       Release build (default)"
    echo "  --debug         Debug build"
    echo ""
    echo "Optimization & Speed Options:"
    echo "  --no-shrink     Skip R8 minification for fast ~30-60s builds (default)"
    echo "  --shrink        Enable full R8 minification"
    echo "  --no-pub        Skip flutter pub get (default)"
    echo "  --pub           Run flutter pub get before building"
    echo "  --copy-only     Only copy existing APK from build/ to destination (no rebuild)"
    echo ""
    echo "Help:"
    echo "  -h, --help      Display this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arm64)
            TARGET_ARCH="arm64"
            shift
            ;;
        --arm32)
            TARGET_ARCH="arm32"
            shift
            ;;
        --both)
            TARGET_ARCH="both"
            shift
            ;;
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --copy-only)
            COPY_ONLY=true
            shift
            ;;
        --shrink)
            SHRINK_FLAG=""
            shift
            ;;
        --no-shrink)
            SHRINK_FLAG="--no-shrink"
            shift
            ;;
        --pub)
            PUB_FLAG=""
            shift
            ;;
        --no-pub)
            PUB_FLAG="--no-pub"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Read version details
read -r APP_VER APP_BUILD <<< "$(get_project_version)"
VERSION_TAG="${APP_VER}-${APP_BUILD}"

OUT_DIR_64="${PROJECT_ROOT}/Apk files"
OUT_DIR_32="${PROJECT_ROOT}/Apk files/apk32"
mkdir -p "${OUT_DIR_64}" "${OUT_DIR_32}"

DST_APK_64="${OUT_DIR_64}/jadwal-v${VERSION_TAG}-${BUILD_TYPE}.apk"
DST_APK_32="${OUT_DIR_32}/jadwal-v${VERSION_TAG}-${BUILD_TYPE}.apk"

# Cleanup trap for ABI filter restoration
restore_arm64_abi() {
    if [ -f "${APP_GRADLE}" ]; then
        if grep -q 'abiFilters "armeabi-v7a"' "${APP_GRADLE}"; then
            sed -i 's/abiFilters "armeabi-v7a"/abiFilters "arm64-v8a"/' "${APP_GRADLE}"
            sed -i "s|exclude 'lib/arm64-v8a/\*\*|exclude 'lib/armeabi-v7a/**|g" "${APP_GRADLE}"
        fi
    fi
}
trap restore_arm64_abi EXIT INT TERM

set_arm32_abi() {
    if [ -f "${APP_GRADLE}" ]; then
        sed -i 's/abiFilters "arm64-v8a"/abiFilters "armeabi-v7a"/' "${APP_GRADLE}"
        sed -i "s|exclude 'lib/armeabi-v7a/\*\*|exclude 'lib/arm64-v8a/**|g" "${APP_GRADLE}"
    fi
}

copy_apk() {
    local src="$1"
    local dst="$2"
    local arch_name="$3"

    if [ ! -f "${src}" ]; then
        log_error "Source APK not found at ${src}"
        return 1
    fi

    cp "${src}" "${dst}"
    local size_bytes
    size_bytes="$(stat -c%s "${dst}" 2>/dev/null || stat -f%z "${dst}" 2>/dev/null || echo 0)"
    local size_mb
    size_mb="$(awk "BEGIN {printf \"%.2f\", ${size_bytes}/1048576}")"
    local sha
    sha="$(sha256sum "${dst}" | awk '{print $1}')"

    echo -e "${C_GREEN}${C_BOLD}✔ Output [${arch_name}]:${C_RESET} ${dst}"
    echo -e "  Size:   ${size_mb} MB (${size_bytes} bytes)"
    echo -e "  SHA256: ${sha}"
}

build_single_arch() {
    local arch="$1"
    local start_time
    start_time="$(date +%s)"

    local flutter_platform=""
    local dst_path=""
    local arch_label=""

    if [ "${arch}" = "arm64" ]; then
        flutter_platform="android-arm64"
        dst_path="${DST_APK_64}"
        arch_label="arm64-v8a (64-bit)"
        restore_arm64_abi
    elif [ "${arch}" = "arm32" ]; then
        flutter_platform="android-arm"
        dst_path="${DST_APK_32}"
        arch_label="armeabi-v7a (32-bit)"
        set_arm32_abi
    else
        log_error "Unknown architecture: ${arch}"
        return 1
    fi

    local src_apk="${APK_INTERMEDIATE_DIR}/app-${BUILD_TYPE}.apk"

    if [ "${COPY_ONLY}" = true ]; then
        log_info "Copying existing ${arch_label} APK without rebuild..."
        copy_apk "${src_apk}" "${dst_path}" "${arch_label}"
        return 0
    fi

    echo -e "\n${C_BOLD}======================================================${C_RESET}"
    echo -e "${C_BOLD}  Building APK: ${C_CYAN}jadwal-v${VERSION_TAG}-${BUILD_TYPE}.apk${C_RESET} [${arch_label}]"
    echo -e "${C_BOLD}======================================================${C_RESET}"

    local cmd=(
        "${FLUTTER_BIN}" "build" "apk"
        "--${BUILD_TYPE}"
        "--target-platform" "${flutter_platform}"
    )

    if [ -n "${PUB_FLAG}" ]; then cmd+=("${PUB_FLAG}"); fi
    if [ -n "${SHRINK_FLAG}" ]; then cmd+=("${SHRINK_FLAG}"); fi
    for flag in "${EXTRA_FLAGS[@]}"; do
        cmd+=("${flag}")
    done

    log_info "Executing: JAVA_HOME=${JAVA_HOME} ${cmd[*]}"

    # Execute build with discovered JAVA_HOME
    JAVA_HOME="${JAVA_HOME}" "${cmd[@]}"

    # Restore default ABI immediately
    if [ "${arch}" = "arm32" ]; then
        restore_arm64_abi
    fi

    copy_apk "${src_apk}" "${dst_path}" "${arch_label}"

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    echo -e "${C_GREEN}${C_BOLD}✔ Built ${arch_label} successfully in ${duration}s${C_RESET}\n"
}

# Run builds
case "${TARGET_ARCH}" in
    arm64)
        build_single_arch "arm64"
        ;;
    arm32)
        build_single_arch "arm32"
        ;;
    both)
        build_single_arch "arm64"
        build_single_arch "arm32"
        ;;
esac
