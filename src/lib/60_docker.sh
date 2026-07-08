#!/bin/bash

function build_and_start_containers() {
    # 设置容器运行用户可写的目录权限，避免影响 MySQL 数据目录
    sudo chown -R 1000:1000 "$BUILD_ACORE_DIR/modules" "$BUILD_ACORE_DIR/env/dist/etc" "$BUILD_ACORE_DIR/env/dist/logs" 2>/dev/null || chown -R 1000:1000 "$BUILD_ACORE_DIR/modules" "$BUILD_ACORE_DIR/env/dist/etc" "$BUILD_ACORE_DIR/env/dist/logs"
    sudo chown -R 1000:1000 "$WOTLK_ETC_DIR" "$WOTLK_LOG_DIR" "$WOTLK_LUA_SCRIPT_DIR" "$WOTLK_CLIENT_DATA_DIR" 2>/dev/null || chown -R 1000:1000 "$WOTLK_ETC_DIR" "$WOTLK_LOG_DIR" "$WOTLK_LUA_SCRIPT_DIR" "$WOTLK_CLIENT_DATA_DIR"
    sudo chown -R 1000:1000 "$BUILD_ACORE_DIR" 2>/dev/null || chown -R 1000:1000 "$BUILD_ACORE_DIR"

    local compose_args=(
        --progress plain
    )
    local compose_file_args=()

    mapfile -t compose_file_args < <(compose_args)
    compose_args+=("${compose_file_args[@]}")

    docker compose "${compose_args[@]}" build \
        --builder "$DOCKER_BUILDX_BUILDER_NAME" \
        --with-dependencies \
        --build-arg "BUILD_PARALLEL_JOBS=$DOCKER_BUILD_PARALLEL_JOBS"

    docker compose "${compose_args[@]}" --compatibility up -d --no-build --force-recreate
}
