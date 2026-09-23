#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# shellcheck source=../install.sh
source "$ROOT_DIR/install.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_platform() {
    local os_id="$1"
    local version_id="$2"
    local expected_manager="$3"

    AC_OS_RELEASE_FILE="$TEST_TMP_DIR/os-release"
    printf 'ID=%s\nVERSION_ID="%s"\n' "$os_id" "$version_id" > "$AC_OS_RELEASE_FILE"
    AC_PACKAGE_MANAGER=""

    detect_platform || fail "$os_id $version_id 应受支持"
    [ "$AC_PACKAGE_MANAGER" = "$expected_manager" ] || \
        fail "$os_id $version_id 应使用 $expected_manager，实际为 ${AC_PACKAGE_MANAGER:-空}"
}

assert_platform ubuntu 26.04 apt
assert_platform ubuntu future apt
assert_platform debian 99 apt
assert_platform rocky 42 dnf
assert_platform almalinux rolling dnf

AC_OS_RELEASE_FILE="$TEST_TMP_DIR/unsupported-os-release"
printf 'ID=fedora\nVERSION_ID="99"\n' > "$AC_OS_RELEASE_FILE"
if detect_platform >/dev/null 2>&1; then
    fail "未知发行版不应通过平台检测"
fi

echo "test_platform_detection 通过"
