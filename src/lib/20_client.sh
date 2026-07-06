#!/bin/bash

set -e

function client {
    local readonly VERSION="$CLIENT_DATA_VERSION"
    local readonly path="${WOTLK_CLIENT_DATA_DIR}"
    local readonly zipPath="${BUILD_CLIENT_ZIP_DIR}/data.${VERSION}.zip"
    local readonly dbcZhZipPath="${SRC_DATA_DBC_ZIPFILE}"
    local readonly dataVersionFile="${path}/data-version"

    # 加载已安装的版本信息
    if [ -f "$dataVersionFile" ]; then
        INSTALLED_VERSION="$(sed -n 's/^INSTALLED_VERSION=//p' "$dataVersionFile" | head -n 1)"
    fi

    # 创建必要的目录
    mkdir -p "$path" "$BUILD_CLIENT_ZIP_DIR"

    # 检查是否已安装相同版本
    if [ "$VERSION" = "$INSTALLED_VERSION" ]; then
        echo "客户端数据 $VERSION 已存在: $dataVersionFile"
        return 0
    fi

    # 下载数据包（如果不存在）
    if [ ! -f "$zipPath" ]; then
        echo "未找到 data.${VERSION}.zip，开始下载..."
        echo "目标: $zipPath"

        local download_url
        local download_ok=false
        local release_mirrors=("${GITHUB_RELEASES_MIRRORS[@]}")
        release_mirrors+=("")
        for mirror in "${release_mirrors[@]}"; do
            download_url="${mirror}${CLIENT_DATA_DOWNLOAD_URL}"
            echo "源: $download_url"
            if curl -L --fail --silent --show-error \
                --speed-limit "${DOWNLOAD_LOW_SPEED_LIMIT:-32768}" \
                --speed-time "${DOWNLOAD_LOW_SPEED_TIME:-60}" \
                "$download_url" -o "$zipPath"; then
                echo "[OK] 下载完成: $zipPath ($(du -h "$zipPath" | awk '{print $1}'))"
                download_ok=true
                break
            fi
            echo "[WARN] 下载失败或速度过低，切换下一个源: $download_url" >&2
            [ -f "$zipPath" ] && rm -f "$zipPath"
        done

        if [ "$download_ok" != true ]; then
            echo "错误: 下载失败"
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
