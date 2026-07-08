#!/bin/bash

set -e

# ============================================
# 函数: initialize
# 功能: 初始化环境，根据参数决定是否清理旧数据
# 参数: $1 - 数字输入，1表示清理，其他值不清理
# ============================================
function initialize() {
    # 检查参数是否非空且等于1
    if [[ -n "$1" && "$1" -eq 1 ]]; then
        # 执行清理操作
        uninstall_all
    fi
    # 无论是否清理，都执行目录初始化
    prepare_workspace_dirs
}

# ============================================
# 函数: uninstall_all
# 功能: 清理容器和运行数据
# ============================================
function uninstall_all() {
    # 构建Docker Compose文件路径
    local DOCKER_YAML_FILE="$BUILD_ACORE_DIR/docker-compose.yml"

    # 检查Docker Compose文件是否存在
    if [ -f "$DOCKER_YAML_FILE" ]; then
        # 停止并删除容器、镜像
        local compose_down_args=()
        mapfile -t compose_down_args < <(compose_args)
        docker compose "${compose_down_args[@]}" down --rmi local
    fi

    # 删除运行目录及其内容
    echo "删除运行数据: $WOTLK_DIR" && rm -rf "$WOTLK_DIR"
    clear_docker_artifacts
    clear_build_dir
}

clear_docker_artifacts() {
    local containers images image

    mapfile -t containers < <(docker ps -a --format '{{.Names}}' | awk '/^ac-/ {print}')
    if [ "${#containers[@]}" -gt 0 ]; then
        echo "删除容器: ${containers[*]}"
        docker rm -f "${containers[@]}" >/dev/null 2>&1 || true
    fi

    mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | awk '/^acore\/ac-wotlk-/ {print}')
    for image in "${DOCKER_BASE_IMAGES[@]}"; do
        images+=("$image")
    done

    if [ "${#images[@]}" -gt 0 ]; then
        echo "删除镜像: ${images[*]}"
        docker rmi -f "${images[@]}" >/dev/null 2>&1 || true
    fi

    remove_build_builder
}

clear_build_dir() {
    echo "删除构建数据: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
}

# ============================================
# 函数: prepare_workspace_dirs
# 功能: 创建WOTLK相关的目录结构
# ============================================
function prepare_workspace_dirs() {
    # 创建构建目录
    mkdir -p "$BUILD_DIR"

    # 创建配置目录
    mkdir -p "$WOTLK_ETC_DIR"
    mkdir -p "$WOTLK_ETC_MODULES_DIR"

    # 创建日志目录并清空现有日志
    mkdir -p "$WOTLK_LOG_DIR" && rm -rf "$WOTLK_LOG_DIR"/*

    # 创建数据库目录 (注意：变量名可能有拼写错误，MYQL应为MYSQL)
    mkdir -p "$WOTLK_DATABASE_MYSQL_DIR"
    mkdir -p "$WOTLK_DATABASE_MYSQL_CNF"

    # 创建Lua脚本目录
    mkdir -p "$WOTLK_LUA_SCRIPT_DIR"

    # 为每个数据库创建自定义SQL脚本目录
    for WOTLK_DB_NAME in "${WOTLK_DB_NAMES[@]}"; do
        mkdir -p "$WOTLK_SQL_DIR/$WOTLK_DB_NAME"
    done

    # 创建客户端数据目录
    mkdir -p "$WOTLK_CLIENT_DATA_DIR"
}

install_client_data() {
    local version
    local path="$WOTLK_CLIENT_DATA_DIR"
    local zip_path
    local dbc_zh_zip_path="$SRC_DATA_DBC_ZIPFILE"
    local data_version_file="$path/data-version"
    local installed_version=""

    resolve_client_data_version
    version="$AC_CLIENT_DATA_RESOLVED_VERSION"
    zip_path="$(client_data_archive_file)"

    if [ -f "$data_version_file" ]; then
        installed_version="$(sed -n 's/^INSTALLED_VERSION=//p' "$data_version_file" | head -n 1)"
    fi

    if [ "$version" = "$installed_version" ]; then
        echo "客户端数据 $version 已存在: $data_version_file"
        return 0
    fi

    if [ ! -f "$zip_path" ]; then
        echo "错误: 客户端数据包不存在: $zip_path" >&2
        return 1
    fi

    echo "清理旧客户端数据: $path"
    rm -rf "$path"/*

    echo "解压客户端数据到: $path"
    if ! unzip -q -o "$zip_path" -d "$path/"; then
        echo "错误: 客户端数据解压失败" >&2
        return 1
    fi

    echo "解压中文 dbc 数据到: $path/dbc"
    if ! unzip -q -o "$dbc_zh_zip_path" -d "$path/dbc"; then
        echo "错误: 中文 dbc 数据解压失败" >&2
        return 1
    fi

    echo "INSTALLED_VERSION=$version" > "$data_version_file"
    echo "客户端数据 $version 安装完成"
}
