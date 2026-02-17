#!/bin/bash

set -e

function module() {

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

    for mod_conf_dist_file in `find $BUILD_ACORE_MOD_DIR -name "*.conf.dist"`
    do
        local mod_conf_file_name=$(basename -s .dist $mod_conf_dist_file)
        local mod_conf_file=$WOTLK_ETC_MODULES_DIR/$mod_conf_file_name
        if [[ ! -f "$mod_conf_file" ]]; then
            cp -p "$mod_conf_dist_file" "$mod_conf_file">/dev/null 2>&1 && \
            echo "$mod_conf_dist_file -> $mod_conf_file"
        fi
    done

    # 替换 ale脚本目录
    sed -i 's|ALE.ScriptPath = "lua_scripts"|ALE.ScriptPath = "/azerothcore/lua_scripts/"|g' "${WOTLK_ETC_MODULES_DIR}/mod_ale.conf"
}