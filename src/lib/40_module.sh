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
        local mod_name
        mod_name="$(basename -s .git "$GIT_ACORE_MODULE_URL")"
        local mod_dir="$BUILD_ACORE_MOD_DIR/$mod_name"

        if ! gitClone "$GIT_ACORE_MODULE_URL" "" "$mod_dir"; then
            echo "错误: 模块 $mod_name 初始化失败，脚本已终止" >&2
            exit 1
        fi

        mv "$mod_dir/$_world" "$mod_dir/$world" 2>/dev/null || :
        mv "$mod_dir/$_chars" "$mod_dir/$chars" 2>/dev/null || :
        mv "$mod_dir/$_auth" "$mod_dir/$auth" 2>/dev/null || :
    done

    while IFS= read -r mod_conf_dist_file
    do
        local mod_conf_file_name
        mod_conf_file_name="$(basename -s .dist "$mod_conf_dist_file")"
        local mod_conf_file="$WOTLK_ETC_MODULES_DIR/$mod_conf_file_name"
        if [[ ! -f "$mod_conf_file" ]]; then
            cp -p "$mod_conf_dist_file" "$mod_conf_file">/dev/null 2>&1 && \
            echo "$mod_conf_dist_file -> $mod_conf_file"
        fi
    done < <(find "$BUILD_ACORE_MOD_DIR" -name "*.conf.dist")

    # 替换 ale脚本目录
    local mod_ale_conf="$WOTLK_ETC_MODULES_DIR/mod_ale.conf"
    if [ -f "$mod_ale_conf" ]; then
        sed -i 's|ALE.ScriptPath = "lua_scripts"|ALE.ScriptPath = "/azerothcore/lua_scripts/"|g' "$mod_ale_conf"
    fi

    patch_autobalance_compatibility
}

patch_autobalance_compatibility() {
    local mod_autobalance_header="$BUILD_ACORE_MOD_DIR/mod-autobalance/src/ABAllCreatureScript.h"
    local mod_autobalance_source="$BUILD_ACORE_MOD_DIR/mod-autobalance/src/ABAllCreatureScript.cpp"

    if [ ! -f "$mod_autobalance_header" ]; then
        return 0
    fi

    if grep -q "Creature_SelectLevel" "$mod_autobalance_header"; then
        sed -i '/Creature_SelectLevel/s/[[:space:]]override//' "$mod_autobalance_header"
        echo "已修复 mod-autobalance 兼容性: $mod_autobalance_header"
    fi

    if [ -f "$mod_autobalance_source" ] && grep -q "SetModifierValue" "$mod_autobalance_source"; then
        sed -i 's/\bSetModifierValue\b/SetStatFlatModifier/g' "$mod_autobalance_source"
        echo "已修复 mod-autobalance 旧接口: $mod_autobalance_source"
    fi
}
