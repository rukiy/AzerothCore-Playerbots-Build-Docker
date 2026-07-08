#!/bin/bash

set -e


function configure_database() {
    ensure_databases
    configure_realmlist
    run_custom_sql
}

function ensure_databases() {
    local db_name

    for db_name in "${WOTLK_DB_NAMES[@]}"; do
        echo "确保数据库存在: $db_name"
        docker exec -e MYSQL_PWD="${DOCKER_DB_ROOT_PASSWORD:-}" ac-database \
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$db_name\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    done
}

function configure_realmlist(){
    # 获取 realmlist address
    realmListServer
    # 更新到数据库
    execute_sql "acore_auth" "UPDATE realmlist SET name = '$(sql_escape "$REALMLIST_NAME")', address = '$(sql_escape "$REALMLIST_ADDRESS")', localAddress = '$(sql_escape "$REALMLIST_LOCAL_ADDRESS")' WHERE id = 1;"
    execute_sql "acore_auth" "SELECT id, name, address, localAddress FROM realmlist;"
}

function run_custom_sql(){
    for WOTLK_DB_NAME in "${WOTLK_DB_NAMES[@]}"; do
        local sql_files=("$WOTLK_SQL_DIR/$WOTLK_DB_NAME"/*.sql)
        execute_sql_files "$WOTLK_DB_NAME" "${sql_files[@]}"
    done
}
