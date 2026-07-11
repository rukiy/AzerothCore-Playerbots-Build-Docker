#!/bin/bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

entry_guard='if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then'
if ! grep -Fq "$entry_guard" "$ROOT_DIR/install.sh"; then
    fail "install.sh 缺少 source 入口保护"
fi

load_installer

declare -F main >/dev/null || fail "source install.sh 后未定义 main 函数"
echo "install.sh source 测试通过"
