#!/bin/bash

set -e

function azerothcore() {
    if ! gitClone "$GIT_ACORE_URL" "$GIT_ACORE_BRANCH" "$BUILD_ACORE_DIR"; then
        echo "错误: AzerothCore 仓库初始化失败，脚本已终止" >&2
        exit 1
    fi
    cp "$SRC_DIR/conf.d"/*.cnf "$WOTLK_DATABASE_MYSQL_CNF/"
    write_mysql_memory_config "$WOTLK_DATABASE_MYSQL_CNF/performance.cnf"
    chmod 644 "$WOTLK_DATABASE_MYSQL_CNF"/*.cnf

    # 设置时区
    local timezone
    timezone="$(cat /etc/timezone)"
    sudo sed -i "s|^TZ=.*$|TZ=${timezone}|" "$SRC_DIR/.env" 2>/dev/null || sed -i "s|^TZ=.*$|TZ=${timezone}|" "$SRC_DIR/.env" 2>/dev/null || true

    write_managed_env_values "$SRC_DIR/.env"
    configure_dockerfile_mirror "$BUILD_ACORE_DIR/apps/docker/Dockerfile" "$BUILD_RUNTIME_DOCKERFILE"
}

configure_dockerfile_mirror() {
    local source_dockerfile="$1"
    local output_dockerfile="${2:-$1}"

    if [ ! -f "$source_dockerfile" ]; then
        echo "错误: Dockerfile 不存在: $source_dockerfile" >&2
        return 1
    fi

    local ubuntu_version
    ubuntu_version="$(sed -n 's/^ARG UBUNTU_VERSION=//p' "$source_dockerfile" | head -n1 | awk '{print $1}')"
    ubuntu_version="${ubuntu_version:-24.04}"

    local standard_ref="ubuntu:${ubuntu_version}"

    local mirror_host="${UBUNTU_MIRROR%/}"
    mirror_host="http://${mirror_host}/ubuntu/"

    local tmp_file
    tmp_file="$(mktemp)"
    mkdir -p "$(dirname "$output_dockerfile")"

    awk \
        -v standard_ref="$standard_ref" \
        -v mirror_host="$mirror_host" \
        -v mirror_raw="$UBUNTU_MIRROR" '
        {
            if ($0 ~ /^FROM ubuntu:\$UBUNTU_VERSION([[:space:]]+#.*)?[[:space:]]+AS[[:space:]]+skeleton$/ || $0 ~ /^FROM ubuntu:\$UBUNTU_VERSION([[:space:]]+#.*)?$/) {
                print "FROM " standard_ref " AS skeleton"
                next
            }

            if ($0 ~ /^[[:space:]]*RUN[[:space:]]+apt-get update([[:space:]]*\\|[[:space:]]*&&.*)$/) {
                print "RUN mirror=\"" mirror_host "\"; \\"
                print "    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then sed -i \"s|http://archive.ubuntu.com/ubuntu/|${mirror}|g; s|http://security.ubuntu.com/ubuntu/|${mirror}|g\" /etc/apt/sources.list.d/ubuntu.sources; fi; \\"
                print "    if [ -f /etc/apt/sources.list ]; then sed -i \"s|http://archive.ubuntu.com/ubuntu/|${mirror}|g; s|http://security.ubuntu.com/ubuntu/|${mirror}|g; s|archive.ubuntu.com|" mirror_raw "|g; s|security.ubuntu.com|" mirror_raw "|g\" /etc/apt/sources.list; fi; \\"
                sub(/^[[:space:]]*RUN[[:space:]]+apt-get update[[:space:]]*/, "    apt-get update ", $0)
                print $0
                next
            }

            if ($0 ~ /^[[:space:]]*apt-get update([[:space:]]*\\|[[:space:]]*&&.*)$/) {
                print "    mirror=\"" mirror_host "\"; \\"
                print "    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then sed -i \"s|http://archive.ubuntu.com/ubuntu/|${mirror}|g; s|http://security.ubuntu.com/ubuntu/|${mirror}|g\" /etc/apt/sources.list.d/ubuntu.sources; fi; \\"
                print "    if [ -f /etc/apt/sources.list ]; then sed -i \"s|http://archive.ubuntu.com/ubuntu/|${mirror}|g; s|http://security.ubuntu.com/ubuntu/|${mirror}|g; s|archive.ubuntu.com|" mirror_raw "|g; s|security.ubuntu.com|" mirror_raw "|g\" /etc/apt/sources.list; fi; \\"
                if ($0 ~ /&&/) {
                    sub(/^[[:space:]]*apt-get update[[:space:]]*/, "    apt-get update ", $0)
                    print $0
                } else {
                    print "    apt-get update \\"
                }
                next
            }

            print
        }
    ' "$source_dockerfile" > "$tmp_file"

    perl -0pi -e 's/\Q-j $(($(nproc) + 1))\E/-j '"${DOCKER_BUILD_PARALLEL_JOBS}"'/g' "$tmp_file"

    mv "$tmp_file" "$output_dockerfile"
}
