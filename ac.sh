#!/bin/bash

set -e

readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/ac.conf"
source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/src/lib/config.sh"
source "$SCRIPT_DIR/src/lib/utils.sh"
source "$SCRIPT_DIR/src/lib/client.sh"
source "$SCRIPT_DIR/src/lib/build.sh"
source "$SCRIPT_DIR/fix.sh"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "error: must be root to invoke $0"
	exit 1
fi

install() {
    build
}

updown() {
    containers=("ac-worldserver" "ac-authserver" "ac-database")
    all_running=true
    for container in "${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            all_running=false
            break
        fi
    done

    if $all_running; then
        echo "Stopping containers: ${containers[*]}"
        docker stop "${containers[@]}"
    else
        echo "Starting containers: ${containers[*]}"
        docker start "${containers[@]}"
    fi
}

ps() {
	docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml ps
}

clean() {
    docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml down --rmi local
	rm -rf $WOTLK_DIR
}

case "$1" in
	install|updown|ps|clean)
		"$1"
		;;

	*)
		echo "Usage $0 {install|updown|ps|clean}"
		exit 1
		;;
esac