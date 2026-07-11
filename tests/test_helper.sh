#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "测试失败: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    [ "$expected" = "$actual" ] || fail "$message：期望 [$expected]，实际 [$actual]"
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local message="$3"
    [[ "$text" == *"$expected"* ]] || fail "$message：[$text] 不包含 [$expected]"
}

load_installer() {
    # 仅供已确认入口安全后的函数级测试全局加载；source 安全测试必须使用独立子进程。
    source "$ROOT_DIR/install.sh"
}
