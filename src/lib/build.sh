#!/bin/bash

function init_dir() {
    # 配置目录
    mkdir -p $WOTLK_ETC_DIR
    # 日志目录
    mkdir -p $WOTLK_LOG_DIR && rm -rf $WOTLK_LOG_DIR/*
    # 数据库目录
    mkdir -p $WOTLK_DATABASE_DIR
    # 自定义sql脚本目录
    for WOTLK_DB_NAME in "${WOTLK_DB_NAMES[@]}"; do
        mkdir -p $WOTLK_SQL_DIR/$WOTLK_DB_NAME
    done
    # 客户端数据
    mkdir -p $WOTLK_CLIENT_DATA_DIR
}

function init_acore() {
    gitClone $GIT_ACORE_URL $GIT_ACORE_BRANCH $BUILD_ACORE_DIR
    if [ $? -ne 0 ]; then
        echo "错误: AzerothCore 仓库初始化失败，脚本已终止" >&2
        exit 1
    fi
    cp $SRC_DIR/.env $BUILD_ACORE_DIR/
    cp $SRC_DIR/*.yml $BUILD_ACORE_DIR/

    # 设置时区
    sudo sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" $BUILD_ACORE_DIR/.env 2>/dev/null || sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" $BUILD_ACORE_DIR/.env 2>/dev/null || true
}

function init_acore_module() {

    local _world="data/sql/db-world"
    local _chars="data/sql/db-characters"
    local _auth="data/sql/db-auth"

    local world="data/sql/world"
    local chars="data/sql/characters"
    local auth="data/sql/auth"

    for GIT_ACORE_MODULE_URL in "${GIT_ACORE_MODULE_URLS[@]}"; do
        local mod_name=$(basename -s .git $GIT_ACORE_MODULE_URL)
        local mod_dir=$BUILD_ACORE_MOD_DIR/$mod_name

        gitClone $GIT_ACORE_MODULE_URL "" $mod_dir
        if [ $? -ne 0 ]; then
            echo "错误: 模块 $mod_name 初始化失败，脚本已终止" >&2
            exit 1
        fi

        mv $mod_dir/$_world $mod_dir/$world 2>/dev/null || :
        mv $mod_dir/$_chars $mod_dir/$chars 2>/dev/null || :
        mv $mod_dir/$_auth $mod_dir/$auth 2>/dev/null || :
    done
}

function set_mirror() {
    # dockerfile
    local DOCKERFILE_MIRROR_CMD="RUN sed -i 's\/archive.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& sed -i 's\/security.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& apt-get update"
    sed -i "s#RUN apt-get update#${DOCKERFILE_MIRROR_CMD}#g" "${BUILD_ACORE_DIR}/apps/docker/Dockerfile"
}

function fix_permissions(){
    # 设置目录权限
    # mkdir -p $BUILD_ACORE_DIR/env/dist/etc $BUILD_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $BUILD_ACORE_DIR/modules $BUILD_ACORE_DIR/env/dist/etc $BUILD_ACORE_DIR/env/dist/logs 2>/dev/null || chown -R 1000:1000 $BUILD_ACORE_DIR/modules $BUILD_ACORE_DIR/env/dist/etc $BUILD_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $WOTLK_DIR 2>/dev/null || chown -R 1000:1000 $WOTLK_DIR
    sudo chown -R 1000:1000 $BUILD_ACORE_DIR 2>/dev/null || chown -R 1000:1000 $BUILD_ACORE_DIR
}

function build_container() {
    fix_permissions
    docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml --compatibility up -d --build
    # fix_permissions
    # docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml restart ac-db-import
    sleep 15
}

function set_realmlist(){
    # 获取 realmlist address
    detectedIP
    # 更新到数据库
    execute_sql "acore_auth" "UPDATE realmlist SET address = '$REALMLIST_ADDRESS' WHERE id = 1;"
    execute_sql "acore_auth" "SELECT id, name, address FROM realmlist;"
}

function exec_custom_sql(){
    for WOTLK_DB_NAME in "${WOTLK_DB_NAMES[@]}"; do
        local sql_files=("$WOTLK_SQL_DIR/$WOTLK_DB_NAME"/*.sql)
        execute_sql_files $WOTLK_DB_NAME $sql_files
    done
}


function build() {
    init_dir
    init_client
    init_acore
    init_acore_module
    set_mirror
    build_container
    set_realmlist
    exec_custom_sql
}