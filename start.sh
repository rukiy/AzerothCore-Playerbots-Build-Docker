#!/bin/bash
readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/client.sh"

function fix_permissions(){
    # 设置目录权限
    # mkdir -p $SRC_ACORE_DIR/env/dist/etc $SRC_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $SRC_ACORE_DIR/modules $SRC_ACORE_DIR/env/dist/etc $SRC_ACORE_DIR/env/dist/logs 2>/dev/null || chown -R 1000:1000 $SRC_ACORE_DIR/modules $SRC_ACORE_DIR/env/dist/etc $SRC_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $WOTLK_DIR 2>/dev/null || chown -R 1000:1000 $WOTLK_DIR
    sudo chown -R 1000:1000 $SRC_ACORE_DIR 2>/dev/null || chown -R 1000:1000 $SRC_ACORE_DIR
}
fix_permissions
docker compose -f $SRC_ACORE_DIR/docker-compose.yml -f $SRC_ACORE_DIR/docker-compose.override.yml --compatibility up -d
