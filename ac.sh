#!/bin/bash
set -e

readonly AC_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s\n' "${BASH_SOURCE[0]}")"
readonly AC_SCRIPT_DIR="$(cd "$(dirname "$AC_SCRIPT_PATH")" && pwd)"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "错误：必须以root权限运行 $0"
	exit 1
fi

source "$AC_SCRIPT_DIR/src/lib.sh"

setup_logging() {
    local command_name="$1"
    local log_dir log_file

    log_dir="${AC_LOG_DIR:-build/logs}"
    if [[ "$log_dir" != /* ]]; then
        log_dir="$AC_SCRIPT_DIR/$log_dir"
    fi
    mkdir -p "$log_dir"

    log_file="${AC_LOG_FILE:-$log_dir/ac.log}"
    if [[ "$log_file" != /* ]]; then
        log_file="$AC_SCRIPT_DIR/$log_file"
    fi
    mkdir -p "$(dirname "$log_file")"
    rm -f "$log_file"

    export AC_ACTIVE_LOG_FILE="$log_file"
    exec > >(tee -a "$log_file") 2>&1
    echo "日志文件: $log_file"
    echo "执行命令: $command_name"
}

install() {
    build 0
}

update() {
    build 0
}

uninstall(){
    wlk_clear
}

case "$1" in
	install|update|toggle|uninstall)
        setup_logging "$1"
		"$1"
		;;

	*)
		echo "用法：$0 {install|update|toggle|uninstall}"
		exit 1
		;;
esac
