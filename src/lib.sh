#!/bin/bash
set -e

# 获取当前脚本所在目录
readonly LIB_SCRIPT_FILE_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")
# 获取脚本所在目录的父目录
readonly WORKSPACE_SCRIPT_DIR=$(dirname "$LIB_SCRIPT_FILE_DIR")
# 导入src目录配置文件
source "$WORKSPACE_SCRIPT_DIR/src/.env"
# 导入根目录配置文件
source "$WORKSPACE_SCRIPT_DIR/ac.conf"
# 动态导入src/lib目录下所有.sh脚本（除了playerbots子目录）
for script in "$WORKSPACE_SCRIPT_DIR/src/lib"/*.sh; do
    if [ -f "$script" ]; then
        source "$script"
    fi
done
# 动态导入playerbots目录下所有.sh脚本
for script in "$WORKSPACE_SCRIPT_DIR/src/lib/extra"/*.sh; do
    if [ -f "$script" ]; then
        source "$script"
    fi
done