#!/bin/bash

REALMLIST_ADDRESS=

# UBUNTU_MIRROR="mirrors.aliyun.com"
UBUNTU_MIRROR="mirrors.ustc.edu.cn"

# GITHUB_GIT_MIRROR=
# GITHUB_GIT_MIRROR="https://githubfast.com/"
# GITHUB_GIT_MIRROR="https://kkgithub.com/"

# GITHUB_RELEASES_MIRROR="https://ghpxy.hwinzniej.top/"
GITHUB_RELEASES_MIRROR="https://wget.la/"


CLIENT_DATA_VERSION="v19"
CLIENT_DATA_DOWNLOAD_URL="https://github.com/wowgaming/client-data/releases/download/${CLIENT_DATA_VERSION}/data.zip"

GIT_ACORE_URL="https://github.com/liyunfan1223/azerothcore-wotlk.git"
GIT_ACORE_BRANCH="Playerbot"

GIT_ACORE_MODULE_URLS=(
    https://github.com/liyunfan1223/mod-playerbots.git
    https://github.com/azerothcore/mod-aoe-loot.git
    https://github.com/ZhengPeiRu21/mod-individual-progression.git
    https://github.com/noisiver/mod-learnspells.git
    https://github.com/azerothcore/mod-fireworks-on-level.git
    https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git
    https://github.com/azerothcore/mod-ale.git
    https://github.com/azerothcore/mod-autobalance.git
    https://github.com/azerothcore/mod-transmog.git
)