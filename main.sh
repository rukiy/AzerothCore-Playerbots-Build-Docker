#!/bin/bash

set -e

readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/setting.conf"
source "$SCRIPT_DIR/src/lib/config.sh"
source "$SCRIPT_DIR/src/lib/utils.sh"
source "$SCRIPT_DIR/src/lib/client.sh"
source "$SCRIPT_DIR/src/lib/build.sh"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "error: must be root to invoke $0"
	exit 1
fi

install() {
    build
}

start() {
	docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml --compatibility up -d
}

stop() {
	docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml down
}

restart() {
	stop
	start
}

ps() {
	docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml ps
}

clean() {
    docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml down --rmi local
	rm -rf $WOTLK_DIR
}

case "$1" in
	install|start|stop|restart|ps|clean)
		"$1"
		;;

	*)
		echo "Usage $0 {install|start|stop|restart|ps|clean}"
		exit 1
		;;
esac