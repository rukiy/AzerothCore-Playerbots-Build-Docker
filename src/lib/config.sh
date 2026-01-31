#!/bin/bash

CLIENT_DATA_VERSION="v19"
CLIENT_DATA_DOWNLOAD_URL="https://github.com/wowgaming/client-data/releases/download/${CLIENT_DATA_VERSION}/data.zip"

GIT_ACORE_URL="https://github.com/liyunfan1223/azerothcore-wotlk.git"
GIT_ACORE_BRANCH="Playerbot"

GIT_ACORE_MODULE_URLS=(
    # 高度智能的 AI 机器人，让机器人模拟真实玩家进行组队、升级、任务、下副本和参与战场，显著增强单机或小规模私服的游戏体验。 
    https://github.com/liyunfan1223/mod-playerbots.git
    # 范围拾取，允许玩家一次性拾取周围一定范围内所有NPC尸体掉落的物品，极大提升了刷怪拾取效率
    https://github.com/azerothcore/mod-aoe-loot.git
    # 模拟玩家在不同扩展包和等级之间的个人进度。它强制玩家按顺序体验游戏内容，确保NPC和游戏对象根据每个玩家的进度显示
    https://github.com/ZhengPeiRu21/mod-individual-progression.git
    # 类似“大灾变”版本及之后的特性：角色在升级时会自动学会职业新技能，无需寻找训练师。 
    https://github.com/noisiver/mod-learnspells.git
    # 当玩家在服务器上升级时，会在其角色周围自动触发烟花表演，作为一种庆典效果
    https://github.com/azerothcore/mod-fireworks-on-level.git
    # 强大 Lua 脚本引擎插件。它允许服务器管理员和开发者利用 Lua 语言添加自定义游戏内容、事件和机制，无需修改核心代码
    https://github.com/azerothcore/mod-ale.git
    # 根据在线玩家数量动态调整副本和生物的难度。它通过修改生物的血量、伤害等属性，让小规模队伍甚至单人也能完成原本需要多人配合的副本任务。
    https://github.com/azerothcore/mod-autobalance.git
    # 它实现了装备幻化功能，允许玩家将任意一件装备外观变更为另一件装备的样式
    https://github.com/azerothcore/mod-transmog.git
    # 在游戏内的阵营拍卖行中自动售卖和竞标物品。它能模拟真实玩家行为，独立执行拍卖行操作，帮助保持游戏内经济活跃，特别适用于低人口服务器
    https://github.com/azerothcore/mod-ah-bot.git
    # 在服务器中添加功能性服务NPC。它通过在游戏内提供一个或多个综合NPC，实现如自动学技能、免费转种族、传送、洗天赋等功能
    https://github.com/azerothcore/mod-npc-services.git
)

# 源码目录
readonly SRC_DIR="$SCRIPT_DIR/src"

# 构建文件目录
readonly BUILD_DIR="$SCRIPT_DIR/build"
readonly BUILD_ACORE_DIR="$BUILD_DIR/azerothcore-wotlk"
readonly BUILD_CLIENT_ZIP_DIR="$BUILD_DIR"
readonly BUILD_ACORE_MOD_DIR="$BUILD_ACORE_DIR/modules"

# 运行目录
readonly WOTLK_DIR="$SCRIPT_DIR/wotlk"
readonly WOTLK_SQL_DIR="$SRC_DIR/sql"
readonly WOTLK_DB_NAMES=(
    acore_auth
    acore_world
    acore_characters
    acore_playerbots
)
readonly WOTLK_ETC_DIR="$WOTLK_DIR/etc"
readonly WOTLK_LOG_DIR="$WOTLK_DIR/logs"
readonly WOTLK_DATABASE_DIR="$WOTLK_DIR/database"
readonly WOTLK_CLIENT_DATA_DIR="$WOTLK_DIR/client"