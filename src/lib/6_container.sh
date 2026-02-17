#!/bin/bash

function container() {
     # 设置目录权限
    sudo chown -R 1000:1000 $BUILD_ACORE_DIR/modules $BUILD_ACORE_DIR/env/dist/etc $BUILD_ACORE_DIR/env/dist/logs 2>/dev/null || chown -R 1000:1000 $BUILD_ACORE_DIR/modules $BUILD_ACORE_DIR/env/dist/etc $BUILD_ACORE_DIR/env/dist/logs
    sudo chown -R 1000:1000 $WOTLK_DIR 2>/dev/null || chown -R 1000:1000 $WOTLK_DIR
    sudo chown -R 1000:1000 $BUILD_ACORE_DIR 2>/dev/null || chown -R 1000:1000 $BUILD_ACORE_DIR

    docker compose -f $BUILD_ACORE_DIR/docker-compose.yml -f $BUILD_ACORE_DIR/docker-compose.override.yml --compatibility up -d --build
}