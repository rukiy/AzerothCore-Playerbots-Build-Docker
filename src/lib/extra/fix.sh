#!/bin/bash

set -e

fix(){
    # 替换playerbots_names,playerbots_guild_names表中的名字
    playerbots_custom_sql
    # 2026年2月3日 修复mod-individual-progression 的sql错误
    # https://github.com/ZhengPeiRu21/mod-individual-progression/blob/master/data/sql/world/base/vanilla_creatures.sql#L11945C1-L11946C1
    sed -i 's|`MovementType = 0 WHERE `entry` = 7045;|`MovementType` = 0 WHERE `entry` = 7045;|g' $BUILD_ACORE_MOD_DIR/mod-individual-progression/data/sql/world/base/vanilla_creatures.sql
    sed -i 's|UPDATE `creature_template SET `MovementType` = 0 WHERE `entry` = 14278;|UPDATE `creature_template` SET `MovementType` = 0 WHERE `entry` = 14278;|g' $BUILD_ACORE_MOD_DIR/mod-individual-progression/data/sql/world/base/vanilla_creatures.sql

}