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
        wlk_clear
    fi
    # 无论是否清理，都执行目录初始化
    wotlk_dir
}

# ============================================
# 函数: wlk_clear
# 功能: 清理容器和运行数据
# ============================================
function wlk_clear() {
    # 构建Docker Compose文件路径
    local DOCKER_YAML_FILE="$BUILD_ACORE_DIR/docker-compose.yml"

    # 检查Docker Compose文件是否存在
    if [ -f "$DOCKER_YAML_FILE" ]; then
        # 停止并删除容器、镜像
        docker compose -f "$DOCKER_YAML_FILE" -f "$BUILD_ACORE_DIR/docker-compose.override.yml" down --rmi local
    fi

    # 删除运行目录及其内容
    echo "删除运行数据: $WOTLK_DIR" && rm -rf "$WOTLK_DIR"
}

# ============================================
# 函数: wotlk_dir
# 功能: 创建WOTLK相关的目录结构
# ============================================
function wotlk_dir() {
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
