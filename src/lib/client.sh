#!/bin/bash

function init_client {
    local readonly VERSION="$CLIENT_DATA_VERSION"
    local readonly path="${WOTLK_CLIENT_DATA_DIR}"
    local readonly zipPath="${BUILD_CLIENT_ZIP_DIR}/data.${VERSION}.zip"
    local readonly dbcZhZipPath="${SRC_DATA_DBC_ZIPFILE}"
    local readonly dataVersionFile="${path}/data-version"

    # 加载已安装的版本信息
    if [ -f "$dataVersionFile" ]; then
        source "$dataVersionFile"
    fi

    # 创建必要的目录
    mkdir -p "$path" "$BUILD_CLIENT_ZIP_DIR"

    # 检查是否已安装相同版本
    if [ "$VERSION" == "$INSTALLED_VERSION" ]; then
        echo "客户端数据 $VERSION 已存在: $dataVersionFile"
        return 0
    fi

    # 下载数据包（如果不存在）
    if [ ! -f "$zipPath" ]; then
        echo "未找到 data.${VERSION}.zip，开始下载..."
        echo "源: ${GITHUB_RELEASES_MIRROR}${CLIENT_DATA_DOWNLOAD_URL}"
        echo "目标: $zipPath"
        
        if ! curl -L --fail --progress-bar "${GITHUB_RELEASES_MIRROR}${CLIENT_DATA_DOWNLOAD_URL}" -o "$zipPath"; then
            echo "错误: 下载失败"
            [ -f "$zipPath" ] && rm -f "$zipPath"
            return 1
        fi
    fi

    # 清理旧数据
    echo "清理旧数据: $path"
    rm -rf "$path"/*

    # 解压数据包
    echo "解压数据包到: $path"
    if ! unzip -q -o "$zipPath" -d "$path/"; then
        echo "错误: 解压失败"
        return 1
    fi

    echo "解压dbc数据包到: $path"
    if ! unzip -q -o "$dbcZhZipPath" -d "$path/dbc"; then
        echo "错误: 解压失败"
        return 1
    fi

    # 写入版本信息（仅在成功时）
    echo "INSTALLED_VERSION=$VERSION" > "$dataVersionFile"
    echo "客户端数据 $VERSION 安装完成"
}
