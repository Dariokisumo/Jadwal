#!/usr/bin/env bash
# apk-info.sh — Inspect APK badging, package, version, ABIs, and signature verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-env.sh"

APK_FILE="${1:-}"

if [ -z "${APK_FILE}" ]; then
    # Auto-detect newest APK in Apk files/
    APK_FILE="$(find "${PROJECT_ROOT}/Apk files" -maxdepth 2 -type f -name "*.apk" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)"
fi

if [ -z "${APK_FILE}" ] || [ ! -f "${APK_FILE}" ]; then
    log_error "No APK file found or specified."
    echo "Usage: $0 [path/to/app.apk]"
    exit 1
fi

echo -e "${C_BOLD}======================================================${C_RESET}"
echo -e "${C_BOLD}                   APK Inspection                     ${C_RESET}"
echo -e "${C_BOLD}======================================================${C_RESET}"

SIZE_BYTES="$(stat -c%s "${APK_FILE}" 2>/dev/null || stat -f%z "${APK_FILE}" 2>/dev/null || echo 0)"
SIZE_MB="$(awk "BEGIN {printf \"%.2f\", ${SIZE_BYTES}/1048576}")"
SHA="$(sha256sum "${APK_FILE}" | awk '{print $1}')"

echo -e "File:   ${C_CYAN}${APK_FILE}${C_RESET}"
echo -e "Size:   ${C_BOLD}${SIZE_MB} MB${C_RESET} (${SIZE_BYTES} bytes)"
echo -e "SHA256: ${SHA}"

# aapt2 badging
if [ -x "${AAPT2_BIN}" ]; then
    echo -e "\n${C_BOLD}Package & Version (aapt2):${C_RESET}"
    BADGING="$("${AAPT2_BIN}" dump badging "${APK_FILE}" 2>/dev/null || true)"
    if [ -n "${BADGING}" ]; then
        PKG_LINE="$(echo "${BADGING}" | grep "^package:" || true)"
        echo -e "  ${PKG_LINE}"
        
        SDK_MIN="$(echo "${BADGING}" | grep "^sdkVersion:" || true)"
        SDK_TGT="$(echo "${BADGING}" | grep "^targetSdkVersion:" || true)"
        echo -e "  ${SDK_MIN} | ${SDK_TGT}"

        NATIVE="$(echo "${BADGING}" | grep "^native-code:" || true)"
        if [ -n "${NATIVE}" ]; then
            echo -e "  ${C_GREEN}${NATIVE}${C_RESET}"
        fi

        APP_LABEL="$(echo "${BADGING}" | grep "^application-label:" || true)"
        echo -e "  ${APP_LABEL}"
    fi
fi

# apksigner verification
if [ -x "${APKSIGNER_BIN}" ]; then
    echo -e "\n${C_BOLD}Signature Verification (apksigner):${C_RESET}"
    VERIFY_OUT="$("${APKSIGNER_BIN}" verify --verbose "${APK_FILE}" 2>&1 || true)"
    if echo "${VERIFY_OUT}" | grep -q "Verifies"; then
        V1="$(echo "${VERIFY_OUT}" | grep "Verified using v1 scheme" || true)"
        V2="$(echo "${VERIFY_OUT}" | grep "Verified using v2 scheme" || true)"
        V3="$(echo "${VERIFY_OUT}" | grep "Verified using v3 scheme" || true)"
        echo -e "  ${C_GREEN}✔ Signature Verified Successfully${C_RESET}"
        if [ -n "${V1}" ]; then echo -e "  ${V1}"; fi
        if [ -n "${V2}" ]; then echo -e "  ${V2}"; fi
        if [ -n "${V3}" ]; then echo -e "  ${V3}"; fi
    else
        log_warn "Signature verification warnings/issues:\n${VERIFY_OUT}"
    fi
fi

echo -e "\n${C_BOLD}======================================================${C_RESET}"
