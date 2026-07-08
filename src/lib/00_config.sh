#!/bin/bash

# 源码目录
readonly SRC_DIR="$WORKSPACE_SCRIPT_DIR/src"
readonly SRC_DATA_DBC_ZIPFILE="$SRC_DIR/data/dbc.zip"
readonly SRC_LIB_DIR="$SRC_DIR/lib"
readonly SRC_LIB_EXTRA_DIR="$SRC_LIB_DIR/extra"

# 下载缓存目录
AC_DOWNLOAD_DIR="${AC_DOWNLOAD_DIR:-downloads}"
if [[ "$AC_DOWNLOAD_DIR" != /* ]]; then
    readonly DOWNLOAD_DIR="$WORKSPACE_SCRIPT_DIR/$AC_DOWNLOAD_DIR"
else
    readonly DOWNLOAD_DIR="$AC_DOWNLOAD_DIR"
fi
readonly DOWNLOAD_SOURCE_DIR="$DOWNLOAD_DIR/source"
readonly DOWNLOAD_DOCKER_IMAGE_DIR="$DOWNLOAD_DIR/docker-images"
readonly DOWNLOAD_CLIENT_DIR="$DOWNLOAD_DIR/client"

AC_DOWNLOAD_LOG_FILE="${AC_DOWNLOAD_LOG_FILE:-build/logs/downloads.log}"
if [[ "$AC_DOWNLOAD_LOG_FILE" != /* ]]; then
    readonly DOWNLOAD_LOG_FILE="$WORKSPACE_SCRIPT_DIR/$AC_DOWNLOAD_LOG_FILE"
else
    readonly DOWNLOAD_LOG_FILE="$AC_DOWNLOAD_LOG_FILE"
fi
readonly DOWNLOAD_LOG_DIR="$(dirname "$DOWNLOAD_LOG_FILE")"

AC_MIRROR_LOG_FILE="${AC_MIRROR_LOG_FILE:-build/logs/mirrors.log}"
if [[ "$AC_MIRROR_LOG_FILE" != /* ]]; then
    readonly MIRROR_LOG_FILE="$WORKSPACE_SCRIPT_DIR/$AC_MIRROR_LOG_FILE"
else
    readonly MIRROR_LOG_FILE="$AC_MIRROR_LOG_FILE"
fi
readonly MIRROR_LOG_DIR="$(dirname "$MIRROR_LOG_FILE")"

AC_MIRROR_STATE_FILE="${AC_MIRROR_STATE_FILE:-downloads/mirror-preferences.env}"
if [[ "$AC_MIRROR_STATE_FILE" != /* ]]; then
    readonly DOWNLOAD_MIRROR_STATE_FILE="$WORKSPACE_SCRIPT_DIR/$AC_MIRROR_STATE_FILE"
else
    readonly DOWNLOAD_MIRROR_STATE_FILE="$AC_MIRROR_STATE_FILE"
fi

# 构建文件目录
readonly BUILD_DIR="$WORKSPACE_SCRIPT_DIR/build"
readonly BUILD_ACORE_DIR="$BUILD_DIR/azerothcore-wotlk"
readonly BUILD_RUNTIME_DIR="$BUILD_DIR/acore-runtime"
readonly BUILD_RUNTIME_DOCKERFILE="$BUILD_RUNTIME_DIR/Dockerfile"
readonly BUILD_BUILDKIT_CONFIG_FILE="$BUILD_RUNTIME_DIR/buildkitd.toml"
readonly BUILD_CLIENT_ZIP_DIR="$DOWNLOAD_CLIENT_DIR"
readonly BUILD_ACORE_MOD_DIR="$BUILD_ACORE_DIR/modules"

# 运行目录
readonly WOTLK_DIR="$WORKSPACE_SCRIPT_DIR/wotlk"
readonly WOTLK_SQL_DIR="$SRC_DIR/sql"
readonly WOTLK_DB_NAMES=(
    acore_auth
    acore_world
    acore_characters
    acore_playerbots
)
readonly WOTLK_ETC_DIR="$WOTLK_DIR/etc"
readonly WOTLK_ETC_MODULES_DIR="$WOTLK_ETC_DIR/modules"
readonly WOTLK_LUA_SCRIPT_DIR="$WOTLK_DIR/lua_scripts"
readonly WOTLK_LOG_DIR="$WOTLK_DIR/logs"
readonly WOTLK_DATABASE_DIR="$WOTLK_DIR/database"
readonly WOTLK_DATABASE_MYSQL_CNF="$WOTLK_DATABASE_DIR/conf.d"
readonly WOTLK_DATABASE_MYSQL_DIR="$WOTLK_DATABASE_DIR/mysql"
readonly WOTLK_CLIENT_DATA_DIR="$WOTLK_DIR/client"

DOCKER_BUILDX_BUILDER_NAME="${DOCKER_BUILDX_BUILDER_NAME:-acore-builder}"
DOCKER_BUILDKIT_IMAGE="${DOCKER_BUILDKIT_IMAGE:-moby/buildkit:buildx-stable-1}"
