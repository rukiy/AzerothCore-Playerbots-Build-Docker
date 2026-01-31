#!/bin/bash

set -e

readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/ac.conf"
source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/src/lib/config.sh"
source "$SCRIPT_DIR/src/lib/utils.sh"
source "$SCRIPT_DIR/src/lib/client.sh"
source "$SCRIPT_DIR/src/lib/build.sh"

if [ "$(id -u)" != 0 ]; then
	echo >&2 "error: must be root to invoke $0"
	exit 1
fi

function testa(){
    for distFile in `find $BUILD_ACORE_MOD_DIR -name "*.conf.dist"`
    do
        local newFileName=$(basename -s .dist $distFile)
        local newFile=$WOTLK_ETC_MODULES_DIR/$newFileName
        if [[ ! -f "$newFile" ]]; then
            cp -p "$distFile" "$newFile">/dev/null 2>&1
            echo "$distFile -> $newFile"
        fi
    done ;
}

testa