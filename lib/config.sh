#!/bin/bash

REALMLIST_ADDRESS=1.1.1.1
UBUNTU_MIRROR="mirrors.aliyun.com"
# GITHUB_MIRROR=
# GITHUB_MIRROR="https://githubfast.com/"
GITHUB_GIT_MIRROR="https://kkgithub.com/"
GITHUB_RELEASES_MIRROR="https://ghpxy.hwinzniej.top/"

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