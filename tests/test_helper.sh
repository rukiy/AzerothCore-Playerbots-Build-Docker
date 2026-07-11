#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "测试失败: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    [ "$expected" = "$actual" ] || fail "期望 [$expected]，实际 [$actual]"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]] || fail "[$haystack] 不包含 [$needle]"
}

load_installer() {
    # 测试调用方需自行设置环境变量，避免加载时触发真实安装。
    source "$ROOT_DIR/install.sh"
}
