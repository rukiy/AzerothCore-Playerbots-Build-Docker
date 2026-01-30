#!/bin/bash
readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/client.sh"

rm -rf $WOTLK_DIR

docker compose -f $SRC_ACORE_DIR/docker-compose.yml down
docker rmi acore/ac-wotlk-authserver:master acore/ac-wotlk-client-data:master acore/ac-wotlk-db-import:master acore/ac-wotlk-worldserver:master