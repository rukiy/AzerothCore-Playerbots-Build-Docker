#!/bin/bash

set -e

function azerothcore() {
    gitClone $GIT_ACORE_URL $GIT_ACORE_BRANCH $BUILD_ACORE_DIR
    if [ $? -ne 0 ]; then
        echo "错误: AzerothCore 仓库初始化失败，脚本已终止" >&2
        exit 1
    fi
    cp $SRC_DIR/.env $BUILD_ACORE_DIR/
    cp $SRC_DIR/*.yml $BUILD_ACORE_DIR/

    cp $SRC_DIR/conf.d/*.cnf $WOTLK_DATABASE_MYSQL_CNF/

    # 设置时区
    sudo sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" $BUILD_ACORE_DIR/.env 2>/dev/null || sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" $BUILD_ACORE_DIR/.env 2>/dev/null || true

     # 设置国内镜像 dockerfile
    local DOCKERFILE_MIRROR_CMD="RUN sed -i 's\/archive.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& sed -i 's\/security.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& apt-get update"
    sed -i "s#RUN apt-get update#${DOCKERFILE_MIRROR_CMD}#g" "${BUILD_ACORE_DIR}/apps/docker/Dockerfile"
}
