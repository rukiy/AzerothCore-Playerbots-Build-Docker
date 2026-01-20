#!/bin/bash

function init_client {
    
    readonly VERSION="$CLIENT_DATA_VERSION"
    # first check if it's defined in env, otherwise use the default
    readonly path="${WOTLK_CLIENT_DATA_DIR}"
    readonly zipPath="${SRC_ACORE_CLIENT_DIR}/data.${VERSION}.zip"
    readonly dataVersionFile="${path}/data-version"

    [ -f "$dataVersionFile" ] && source "$dataVersionFile"

    mkdir -p "$path"

    if [ "$VERSION" == "$INSTALLED_VERSION" ]; then
        echo "客户端数据 $VERSION 已存在: $dataVersionFile"
        return
    fi

    if [ ! -f "${zipPath}" ];then
        echo "未找到 data.${VERSION}.zip 开始下载: $zipPath ..."
        curl -L "${GITHUB_RELEASES_MIRROR}${CLIENT_DATA_DOWNLOAD_URL}" > "$zipPath"
    fi

    echo "解压 $path..."
    rm -rf "$path/*"
    unzip -q -o "$zipPath" -d "$path/"
    echo "INSTALLED_VERSION=$VERSION" > "$dataVersionFile"
}