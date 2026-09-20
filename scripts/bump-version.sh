#!/usr/bin/env bash
# bump-version.sh — Synchronized semantic version bumper for Jadwal (Flutter/Android)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-env.sh"

PUBSPEC="${PROJECT_ROOT}/pubspec.yaml"
APP_VERSION_DART="${PROJECT_ROOT}/lib/constants/app_version.dart"
LOCAL_PROPERTIES="${ANDROID_DIR}/local.properties"

usage() {
    echo -e "${C_BOLD}Usage:${C_RESET} $0 [patch | minor | major | set <version> [build] | get]"
    echo ""
    echo "Examples:"
    echo "  $0 patch             # Increments patch (e.g. 2.9.2+55 -> 2.9.3+56)"
    echo "  $0 minor             # Increments minor (e.g. 2.9.2+55 -> 2.10.0+56)"
    echo "  $0 major             # Increments major (e.g. 2.9.2+55 -> 3.0.0+56)"
    echo "  $0 set 2.9.3 56      # Explicitly set version and build number"
    echo "  $0 set 2.9.3+56      # Explicitly set version and build number with '+'"
    echo "  $0 get               # Display current version and build number"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

ACTION="$1"

# 1. Read Current Version
if [ -f "${PUBSPEC}" ]; then
    RAW_VER="$(grep '^version:' "${PUBSPEC}" | awk '{print $2}' | tr -d '\r')"
    CURRENT_VER="${RAW_VER%+*}"
    CURRENT_BUILD="${RAW_VER#*+}"
elif [ -f "${APP_VERSION_DART}" ]; then
    CURRENT_VER="$(grep "kAppVersion" "${APP_VERSION_DART}" | sed -E "s/.*'([^']+)'.*/\1/")"
    CURRENT_BUILD="$(grep "kAppBuildNumber" "${APP_VERSION_DART}" | sed -E "s/[^0-9]//g")"
else
    log_error "Could not find pubspec.yaml or lib/constants/app_version.dart"
    exit 1
fi

if [ "${ACTION}" = "get" ]; then
    echo -e "${C_BOLD}Current Version:${C_RESET} ${C_GREEN}${CURRENT_VER}${C_RESET} (Build ${C_CYAN}${CURRENT_BUILD}${C_RESET})"
    exit 0
fi

# Split semver
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VER}"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"
CURRENT_BUILD="${CURRENT_BUILD:-1}"

NEW_MAJOR="${MAJOR}"
NEW_MINOR="${MINOR}"
NEW_PATCH="${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))

case "${ACTION}" in
    patch)
        NEW_PATCH=$((PATCH + 1))
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_PATCH=0
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        ;;
    set)
        if [ $# -lt 2 ]; then
            log_error "Missing version argument for 'set'."
            usage
        fi
        TARGET_VAL="$2"
        if [[ "${TARGET_VAL}" == *"+"* ]]; then
            TARGET_VER="${TARGET_VAL%+*}"
            TARGET_BUILD="${TARGET_VAL#*+}"
        else
            TARGET_VER="${TARGET_VAL}"
            TARGET_BUILD="${3:-$NEW_BUILD}"
        fi
        
        IFS='.' read -r NEW_MAJOR NEW_MINOR NEW_PATCH <<< "${TARGET_VER}"
        NEW_BUILD="${TARGET_BUILD}"
        ;;
    *)
        log_error "Unknown action: ${ACTION}"
        usage
        ;;
esac

NEW_VER="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"

# Validate format
if ! [[ "${NEW_VER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Calculated version '${NEW_VER}' is not valid semver (X.Y.Z)!"
    exit 1
fi

if ! [[ "${NEW_BUILD}" =~ ^[0-9]+$ ]]; then
    log_error "Calculated build number '${NEW_BUILD}' is not an integer!"
    exit 1
fi

echo -e "${C_BOLD}Bumping version:${C_RESET} ${C_RED}${CURRENT_VER}+${CURRENT_BUILD}${C_RESET} → ${C_GREEN}${NEW_VER}+${NEW_BUILD}${C_RESET}"

# 1. Update pubspec.yaml
if [ -f "${PUBSPEC}" ]; then
    sed -i -E "s/^version: .*/version: ${NEW_VER}+${NEW_BUILD}/" "${PUBSPEC}"
    log_success "Updated ${PUBSPEC}"
fi

# 2. Update lib/constants/app_version.dart
if [ -f "${APP_VERSION_DART}" ]; then
    sed -i -E "s/const String kAppVersion = '[^']+';/const String kAppVersion = '${NEW_VER}';/" "${APP_VERSION_DART}"
    sed -i -E "s/const int kAppBuildNumber = [0-9]+;/const int kAppBuildNumber = ${NEW_BUILD};/" "${APP_VERSION_DART}"
    log_success "Updated ${APP_VERSION_DART}"
fi

# 3. Update android/local.properties if present
if [ -f "${LOCAL_PROPERTIES}" ]; then
    if grep -q '^flutter.versionName=' "${LOCAL_PROPERTIES}"; then
        sed -i -E "s/^flutter.versionName=.*/flutter.versionName=${NEW_VER}/" "${LOCAL_PROPERTIES}"
    fi
    if grep -q '^flutter.versionCode=' "${LOCAL_PROPERTIES}"; then
        sed -i -E "s/^flutter.versionCode=.*/flutter.versionCode=${NEW_BUILD}/" "${LOCAL_PROPERTIES}"
    fi
    log_success "Updated ${LOCAL_PROPERTIES}"
fi

echo -e "${C_GREEN}${C_BOLD}✔ Version successfully bumped to ${NEW_VER}+${NEW_BUILD}${C_RESET}"
