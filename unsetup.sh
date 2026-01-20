#!/bin/bash
readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/client.sh"


# 源码目录
readonly SRC_DIR="$SCRIPT_DIR/src"
readonly SRC_ACORE_DIR="$SRC_DIR/azerothcore-wotlk"
readonly SRC_ACORE_CLIENT_DIR="$SRC_DIR/client"
readonly SRC_ACORE_MOD_DIR="$SRC_ACORE_DIR/modules"

# 运行目录
readonly WOTLK_DIR="$SCRIPT_DIR/wotlk"
readonly WOTLK_ETC_DIR="$WOTLK_DIR/etc"
readonly WOTLK_LOG_DIR="$WOTLK_DIR/logs"
readonly WOTLK_DATABASE_DIR="$WOTLK_DIR/database"
readonly WOTLK_CLIENT_DATA_DIR="$WOTLK_DIR/client/data"
readonly WOTLK_CLIENT_BIN_DIR="$WOTLK_DIR/client/bin"

rm -rf $WOTLK_DIR