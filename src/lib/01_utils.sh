#!/bin/bash

function realmListServer() {
    if test -z "$REALMLIST_NAME"
    then
        REALMLIST_NAME="Azeroth"
    fi
    if test -z "$REALMLIST_LOCAL_ADDRESS"
    then
        REALMLIST_LOCAL_ADDRESS="$(hostname -I | awk '{print $1}')"
    fi
    if test -z "$REALMLIST_ADDRESS"
    then
        REALMLIST_ADDRESS="$REALMLIST_LOCAL_ADDRESS"
    fi
    echo "realmlist address: $REALMLIST_ADDRESS  localaddress: $REALMLIST_LOCAL_ADDRESS"
}

function execute_sql() {
    local db_name="$1"
    local sql="$2"
    docker exec -e MYSQL_PWD="$DOCKER_DB_ROOT_PASSWORD" ac-database mysql -u root "$db_name" -e "$sql"
}

function execute_sql_files() {
    local db_name="$1"
    shift

    local custom_sql_file
    for custom_sql_file in "$@"; do
        [ -f "$custom_sql_file" ] || continue
        echo "执行sql文件 $custom_sql_file"
        docker exec -i -e MYSQL_PWD="$DOCKER_DB_ROOT_PASSWORD" ac-database mysql -u root "$db_name" < "$custom_sql_file"
    done
}

function sql_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\'/\'\'}"
    printf '%s' "$value"
}

compose_args() {
    printf '%s\n' \
        --env-file "$SRC_DIR/.env" \
        -f "$BUILD_ACORE_DIR/docker-compose.yml" \
        -f "$SRC_DIR/docker-compose.override.yml"
}
