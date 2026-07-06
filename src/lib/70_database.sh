#!/bin/bash

set -e


function database() {
    realmlist
    customsql
}

function realmlist(){
    # 获取 realmlist address
    realmListServer
    # 更新到数据库
    execute_sql "acore_auth" "UPDATE realmlist SET name = '$(sql_escape "$REALMLIST_NAME")', address = '$(sql_escape "$REALMLIST_ADDRESS")', localAddress = '$(sql_escape "$REALMLIST_LOCAL_ADDRESS")' WHERE id = 1;"
    execute_sql "acore_auth" "SELECT id, name, address, localAddress FROM realmlist;"
}

function customsql(){
    for WOTLK_DB_NAME in "${WOTLK_DB_NAMES[@]}"; do
        local sql_files=("$WOTLK_SQL_DIR/$WOTLK_DB_NAME"/*.sql)
        execute_sql_files "$WOTLK_DB_NAME" "${sql_files[@]}"
    done
}
