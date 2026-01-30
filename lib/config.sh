#!/bin/bash

REALMLIST_ADDRESS=311802.xyz

# UBUNTU_MIRROR="mirrors.aliyun.com"
UBUNTU_MIRROR="mirrors.ustc.edu.cn"

# GITHUB_GIT_MIRROR="https://githubfast.com/"
# GITHUB_GIT_MIRROR="https://kkgithub.com/"

# GITHUB_RELEASES_MIRROR="https://ghpxy.hwinzniej.top/"
# GITHUB_RELEASES_MIRROR="https://wget.la/"


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
    # 允许玩家控制小号机器人、创建随机漫游完成任务的NPC，并能组队、下副本或参与战场，实现了高度可配置的仿真 MMO 体验
    https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git
    # 强大 Lua 脚本引擎插件。它允许服务器管理员和开发者利用 Lua 语言添加自定义游戏内容、事件和机制，无需修改核心代码
    https://github.com/azerothcore/mod-ale.git
    # 根据在线玩家数量动态调整副本和生物的难度。它通过修改生物的血量、伤害等属性，让小规模队伍甚至单人也能完成原本需要多人配合的副本任务。
    https://github.com/azerothcore/mod-autobalance.git
    # 它实现了装备幻化功能，允许玩家将任意一件装备外观变更为另一件装备的样式
    https://github.com/azerothcore/mod-transmog.git
    # 在周末期间自动开启经验值加成（XP Weekend），允许服主配置倍率，以在特定时间段内增加玩家获得的经验值。
    https://github.com/azerothcore/mod-weekend-xp.git
    # 在游戏内的阵营拍卖行中自动售卖和竞标物品。它能模拟真实玩家行为，独立执行拍卖行操作，帮助保持游戏内经济活跃，特别适用于低人口服务器
    https://github.com/azerothcore/mod-ah-bot.git
    # 当玩家在副本中死亡时，自动将其传送到该副本的入口处，而不是在副本内的尸体旁复活，从而增加游戏挑战性或机制。 
    https://github.com/AnchyDev/DungeonRespawn.git
    # 自动化拍卖行机器人插件。该模组通过模拟玩家行为，自动在拍卖行发布、购买和管理商品，帮助服务器环境更加活跃，模拟真实玩家交易
    https://github.com/araxiaonline/mod-auctionator.git
    # 在服务器中添加功能性服务NPC。它通过在游戏内提供一个或多个综合NPC，实现如自动学技能、免费转种族、传送、洗天赋等功能
    https://github.com/azerothcore/mod-npc-services.git

)