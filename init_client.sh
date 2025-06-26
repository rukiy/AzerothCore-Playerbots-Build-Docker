#!/bin/bash

inst_download_client_data() {
    source_file="client.tar.gz"
    target_path="wotlk"
    echo "$source_file 解压到 $target_path"
    rm -rf "$target_path"
    mkdir -p $target_path
    tar -zxvf $source_file -C $target_path
    echo "设置权限 $target_path"
    chmod -R 755 $source_file
}

function inst_download_client_data {

    echo "#######################"
    echo "客户端数据下载器"
    echo "#######################"

    # 首先检查环境变量是否存在，否则使用默认路径
    local path="wotlk"
    local zipPath="src/client.tar.gz"

    dataVersionFile="$path/client/data-version"

    if [ ! -f "$dataVersionFile" ]; then
        echo "$dataVersionFile不存在"
    else
        echo "$dataVersionFile已存在"
    fi

    [ -f "$dataVersionFile" ] && source "$dataVersionFile"

    # 如果路径不存在则创建
    mkdir -p "$path"

    if [ "$VERSION" == "$INSTALLED_VERSION" ]; then
        echo "数据版本 $VERSION 已安装。如需强制重新下载，请删除以下文件: $dataVersionFile"
        return
    fi

    echo "正在下载客户端数据到: $zipPath ..."
    curl -L https://githubfast.com/https://github.com/wowgaming/client-data/releases/download/$VERSION/data.zip > "$zipPath" \
        && echo "解压下载的文件到 $path..." && unzip -q -o "$zipPath" -d "$path/" \
        && echo "删除下载的压缩包" && rm "$zipPath" \
        && echo "INSTALLED_VERSION=$VERSION" > "$dataVersionFile"
}

inst_download_client_data