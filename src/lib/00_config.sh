#!/bin/bash

# 源码目录
readonly SRC_DIR="$WORKSPACE_SCRIPT_DIR/src"
readonly SRC_DATA_DBC_ZIPFILE="$SRC_DIR/data/dbc.zip"
readonly SRC_LIB_DIR="$SRC_DIR/lib"
readonly SRC_LIB_EXTRA_DIR="$SRC_LIB_DIR/extra"

# 构建文件目录
readonly BUILD_DIR="$WORKSPACE_SCRIPT_DIR/build"
readonly BUILD_ACORE_DIR="$BUILD_DIR/azerothcore-wotlk"
readonly BUILD_RUNTIME_DIR="$BUILD_DIR/acore-runtime"
readonly BUILD_RUNTIME_DOCKERFILE="$BUILD_RUNTIME_DIR/Dockerfile"
readonly BUILD_BUILDKIT_CONFIG_FILE="$BUILD_RUNTIME_DIR/buildkitd.toml"
readonly BUILD_CLIENT_ZIP_DIR="$BUILD_DIR"
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

DOCKER_BUILDX_BUILDER_NAME="${DOCKER_BUILDX_BUILDER_NAME:-acore-lowmem}"
DOCKER_BUILDKIT_IMAGE="${DOCKER_BUILDKIT_IMAGE:-moby/buildkit:buildx-stable-1}"
GIT_LS_REMOTE_TIMEOUT="${GIT_LS_REMOTE_TIMEOUT:-20}"
GIT_CLONE_TIMEOUT="${GIT_CLONE_TIMEOUT:-180}"
GIT_PULL_TIMEOUT="${GIT_PULL_TIMEOUT:-120}"
