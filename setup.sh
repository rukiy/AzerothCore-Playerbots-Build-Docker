#!/bin/bash
readonly SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null || dirname "${BASH_SOURCE[0]}")

source "$SCRIPT_DIR/src/.env"
source "$SCRIPT_DIR/lib/env.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/client.sh"



function init_config() {
    # 设置 realmlist address
    detectedIP
    # 设置时区
    sudo sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" $SRC_DIR/.env 2>/dev/null || true
}

function init_dir() {
    # 配置目录
    mkdir -p $WOTLK_ETC_DIR
    # 日志目录
    mkdir -p $WOTLK_LOG_DIR && rm -rf $WOTLK_LOG_DIR/*
    # 数据库目录
    mkdir -p $WOTLK_DATABASE_DIR
    # 客户端数据
    mkdir -p $WOTLK_CLIENT_DATA_DIR
}

function init_acore() {
    gitClone $GIT_ACORE_URL $GIT_ACORE_BRANCH $SRC_ACORE_DIR

    local custom_sql_dir="$WOTLK_DIR/data/sql/custom"
    local world="$custom_sql_dir/db_world"
    local chars="$custom_sql_dir/db_characters"
    local auth="$custom_sql_dir/db_auth"

    rm -rf $world/*.sql $chars/*.sql $auth/*.sql
    
    cp $SRC_DIR/.env $SRC_ACORE_DIR/
    cp $SRC_DIR/*.yml $SRC_ACORE_DIR/
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
        local mod_dir=$SRC_ACORE_MOD_DIR/$mod_name

        gitClone $GIT_ACORE_MODULE_URL "" $mod_dir

        mv $mod_dir/$_world $mod_dir/$world 2>/dev/null || :
        mv $mod_dir/$_chars $mod_dir/$chars 2>/dev/null || :
        mv $mod_dir/$_auth $mod_dir/$auth 2>/dev/null || :
    done
}

function set_mirror() {
    # dockerfile
    local DOCKERFILE_MIRROR_CMD="RUN sed -i 's\/archive.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& sed -i 's\/security.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& apt-get update"
    sed -i "s#RUN apt-get update#${DOCKERFILE_MIRROR_CMD}#g" "${SRC_ACORE_DIR}/apps/docker/Dockerfile"
}

function fix_permissions(){
    # 设置目录权限
    sudo chown -R 1000:1000 $SRC_ACORE_DIR/env/dist/etc $SRC_ACORE_DIR/env/dist/logs 2>/dev/null || chown -R 1000:1000 $SRC_ACORE_DIR/env/dist/etc $SRC_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $WOTLK_DIR 2>/dev/null || chown -R 1000:1000 $WOTLK_DIR
    sudo chown -R 1000:1000 $SRC_ACORE_DIR 2>/dev/null || chown -R 1000:1000 $SRC_ACORE_DIR
    sudo chown -R 775 $WOTLK_DATABASE_DIR 2>/dev/null || chown -R 775 $WOTLK_DATABASE_DIR
}

function build_image() {
    docker compose -f $SRC_ACORE_DIR/docker-compose.yml --compatibility up -d --build
}

# function realmlist(){
#     docker exec ac-database mysql -u root -ppassword acore_auth -e "UPDATE realmlist SET address = '$ip_address' WHERE id = 1;" 2>/dev/null && \
# }


main() {
    init_config
    init_dir
    init_client
    init_acore
    init_acore_module
    set_mirror
    fix_permissions
    build_image
}

main "$@"