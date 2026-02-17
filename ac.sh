#!/bin/bash
set -e
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")/src/lib.sh"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "错误：必须以root权限运行 $0"
	exit 1
fi

install() {
    build 1
}

update() {
    build 0
}

uninstall(){
    wlk_clear
}

case "$1" in
	install|update|toggle|uninstall)
		"$1"
		;;

	*)
		echo "用法：$0 {install|update|toggle|uninstall}"
		exit 1
		;;
esac
