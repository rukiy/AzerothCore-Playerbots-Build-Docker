#!/bin/bash
set -e
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")/src/lib.sh"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "error: must be root to invoke $0"
	exit 1
fi

install() {
    build 1
}

update() {
    build 0
}

case "$1" in
	install|update|toggle|uninstall)
		"$1"
		;;

	*)
		echo "Usage $0 {install|update|toggle|uninstall}"
		exit 1
		;;
esac