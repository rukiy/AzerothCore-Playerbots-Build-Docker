#!/bin/bash
set -e

readonly LIB_SCRIPT_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_SCRIPT_DIR="$(dirname "$LIB_SCRIPT_FILE_DIR")"
readonly SRC_ENV_FILE="$WORKSPACE_SCRIPT_DIR/src/.env"
readonly ROOT_CONF_FILE="$WORKSPACE_SCRIPT_DIR/ac.conf"
readonly MIRRORS_CONF_FILE="$WORKSPACE_SCRIPT_DIR/mirrors.conf"

if [ ! -f "$SRC_ENV_FILE" ]; then
    echo "错误：缺少配置文件 $SRC_ENV_FILE" >&2
    exit 1
fi

if [ ! -f "$ROOT_CONF_FILE" ]; then
    echo "错误：缺少配置文件 $ROOT_CONF_FILE" >&2
    exit 1
fi

if [ ! -f "$MIRRORS_CONF_FILE" ]; then
    echo "错误：缺少镜像配置文件 $MIRRORS_CONF_FILE" >&2
    exit 1
fi

source "$SRC_ENV_FILE"
source "$ROOT_CONF_FILE"
source "$MIRRORS_CONF_FILE"

for script in "$WORKSPACE_SCRIPT_DIR/src/lib"/*.sh; do
    [ -f "$script" ] || continue
    source "$script"
done

for script in "$WORKSPACE_SCRIPT_DIR/src/lib/extra"/*.sh; do
    [ -f "$script" ] || continue
    source "$script"
done
