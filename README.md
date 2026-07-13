# AzerothCore + Playerbots Docker 安装脚本

[![Shell](https://img.shields.io/badge/Shell-Bash-1f425f)](#)
[![Docker](https://img.shields.io/badge/Docker-Compose%20%2B%20Buildx-2496ed)](#)
[![AzerothCore](https://img.shields.io/badge/Core-AzerothCore%20WotLK-6f42c1)](#)
[![Playerbots](https://img.shields.io/badge/Module-Playerbots-0f766e)](#)

这个项目面向想快速部署 AzerothCore WotLK + Playerbots 的 Linux 服务器用户。

执行脚本后，它会自动准备服务端源码、Playerbots 模块、客户端数据和 Docker 基础镜像，并通过 Docker Compose 完成构建、数据库初始化和服务启动。

适合想快速搭建自用 WotLK 服务端、减少手工配置步骤，并在安装过程中自动处理国内网络加速和内存规划的场景。

## 集成模块

项目默认下载、编译并启用以下 AzerothCore 模块：

| 模块 | 仓库 | 主要用途 |
| --- | --- | --- |
| Playerbots | [`liyunfan1223/mod-playerbots`](https://github.com/liyunfan1223/mod-playerbots) | 提供玩家机器人系统 |
| Player Bot Level Brackets | [`DustinHendrickson/mod-player-bot-level-brackets`](https://github.com/DustinHendrickson/mod-player-bot-level-brackets) | 按等级段管理 Playerbots |
| AoE Loot | [`azerothcore/mod-aoe-loot`](https://github.com/azerothcore/mod-aoe-loot) | 提供范围拾取功能 |
| Individual Progression | [`ZhengPeiRu21/mod-individual-progression`](https://github.com/ZhengPeiRu21/mod-individual-progression) | 提供个人进度控制功能 |
| Learn Spells | [`noisiver/mod-learnspells`](https://github.com/noisiver/mod-learnspells) | 自动学习符合条件的技能 |
| Fireworks on Level | [`azerothcore/mod-fireworks-on-level`](https://github.com/azerothcore/mod-fireworks-on-level) | 升级时播放烟花效果 |
| ALE | [`azerothcore/mod-ale`](https://github.com/azerothcore/mod-ale) | 提供 Lua 脚本扩展能力 |
| AutoBalance | [`azerothcore/mod-autobalance`](https://github.com/azerothcore/mod-autobalance) | 根据队伍和玩家数量动态调整副本难度 |
| Transmog | [`azerothcore/mod-transmog`](https://github.com/azerothcore/mod-transmog) | 提供装备幻化功能 |
| AH Bot Plus | [`NathanHandley/mod-ah-bot-plus`](https://github.com/NathanHandley/mod-ah-bot-plus) | 增强拍卖行机器人功能 |
| Congrats on Level | [`azerothcore/mod-congrats-on-level`](https://github.com/azerothcore/mod-congrats-on-level) | 玩家升级时发送祝贺消息 |
| Cross-Faction Battlegrounds | [`azerothcore/mod-cfbg`](https://github.com/azerothcore/mod-cfbg) | 支持跨阵营战场匹配 |

默认模块列表可通过 `ac.conf` 中的 `ACORE_MODULE_REPOS` 调整。

## 安装要求

支持以下 64 位 Linux 发行版：

| 发行版 | 支持版本 |
| --- | --- |
| Ubuntu | 22.04、24.04 |
| Debian | 12、13 |
| Rocky Linux | 9、10（Rocky Linux 10 容器验证使用官方 `rockylinux/rockylinux:10` 镜像） |
| AlmaLinux | 9、10 |

内存建议：

| 使用场景 | 内存 | 说明 |
| --- | --- | --- |
| 最低配置 | 4GB | 可以安装和运行，但编译并行数较低、耗时较长，不适合运行较多 Playerbots |
| 推荐配置 | 8GB | 适合个人使用及默认 500 个 Playerbots 的配置 |
| 较高负载 | 12GB～16GB | 适合更多 Playerbots、较高在线人数或同时进行编译和运行 |

安装脚本默认启用自动内存规划，会根据系统总内存和当前已用内存设置构建并行数及各容器的内存限制。4GB 是依据脚本内存规划规则给出的最低建议；宿主系统占用较高时，仍可能因可用内存不足而无法构建。

安装前请确认：

- 使用 `root` 用户执行安装脚本。
- Docker Engine 已安装并启动，同时已安装 Docker Compose v2 和 Docker Buildx。
- 安装目录是尚不存在的绝对路径。脚本不会覆盖已有目录，也不会自动备份其中的数据。
- 依赖安装使用操作系统当前配置的软件源，不会改写软件源配置。

首次运行 `install.sh` 时，安装脚本使用内置代理链下载项目源码归档；这与安装完成后用于客户端数据、源码和容器镜像下载的 `mirrors.conf` 是两套独立配置。首次安装默认先访问 GitHub 原站，失败后依次回退到 `https://gh-proxy.com/`、`https://gh.llkk.cc/`、`https://gh.idayer.com/` 和 `https://ghproxy.net/`。这些代理属于下载源的信任边界，当前下载流程没有固定摘要校验。

## 使用方法

需要 root 权限执行：

```bash
bash <(wget -qO- https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

这条命令会把项目下载到当前用户的 `~/acore`，然后自动执行安装。也可以指定安装目录：

```bash
AC_INSTALL_DIR=/opt/acore bash <(wget -qO- https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

如果服务器没有 `wget`，也可以使用 `curl`：

```bash
bash <(curl -fsSL https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

GitHub 访问较慢时，可任选一个已验证的加速地址：

```bash
# gh-proxy.com
bash <(curl -fsSL 'https://gh-proxy.com/https://raw.githubusercontent.com/rukiy/AzerothCore-Playerbots-Build-Docker/main/install.sh')

# gh.idayer.com
bash <(curl -fsSL 'https://gh.idayer.com/https://raw.githubusercontent.com/rukiy/AzerothCore-Playerbots-Build-Docker/main/install.sh')

# ghproxy.net
bash <(curl -fsSL 'https://ghproxy.net/https://raw.githubusercontent.com/rukiy/AzerothCore-Playerbots-Build-Docker/main/install.sh')
```

以上地址由第三方代理提供，代理服务属于下载源的信任边界。

高安全环境可禁止首次安装的内置代理回退，仅访问 GitHub 原站：

```bash
AC_INSTALL_DIRECT_ONLY=1 bash <(curl -fsSL https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

此模式下，项目源码归档从 GitHub 原站下载失败时会直接退出，不再尝试四个代理地址。

如果已经下载好项目，也可以在项目目录中执行：

```bash
./ac.sh install
```

常用命令：

```bash
# 安装或重新构建
./ac.sh install

# 更新并重新构建，保留运行数据
./ac.sh update

# 启动或停止数据库、认证服、世界服
./ac.sh toggle

# 单独检测 GitHub 和 Docker 加速源
./ac.sh mirrors

# 卸载安装产生的容器、镜像、构建目录和运行目录
./ac.sh uninstall
```

命令说明：

| 命令 | 说明 |
| --- | --- |
| `install` | 检查环境，准备下载缓存，规划内存，构建并启动服务 |
| `update` | 重新准备源码和构建目录，保留运行数据 |
| `toggle` | 启动或停止 `ac-database`、`ac-authserver`、`ac-worldserver` |
| `mirrors` | 手动检测加速源并写入 `downloads/mirror-preferences.env` |
| `uninstall` | 删除安装产生的容器、镜像、`build/`、`wotlk/`，不删除 `downloads/` |

安装完成后，可以进入 worldserver 控制台创建账号：

```bash
docker attach ac-worldserver
```

在控制台中执行：

```text
account create 用户名 密码
account set gmlevel 用户名 3 -1
```

退出控制台：

```text
Ctrl+p Ctrl+q
```

客户端 `realmlist.wtf` 配置为服务器地址：

```text
set realmlist 你的服务器地址
```

## 配置说明

主要配置文件有两个：

| 文件 | 说明 |
| --- | --- |
| `ac.conf` | 服务器地址、源码仓库、模块列表、下载缓存、Docker 镜像、内存、日志 |
| `mirrors.conf` | Ubuntu、GitHub、Docker 加速源 |

### ac.conf

服务器地址：

```bash
# 客户端登录后看到的服务器名称，留空默认 Azeroth。
REALMLIST_NAME=

# 客户端连接服务器使用的公网 IP 或域名，留空自动取本机内网 IP。
REALMLIST_ADDRESS=

# 局域网访问地址，留空自动取本机内网 IP。
REALMLIST_LOCAL_ADDRESS=
```

客户端数据：

```bash
# latest 表示自动解析 wowgaming/client-data 最新 release。
CLIENT_DATA_VERSION="latest"

# 自定义客户端数据包下载地址，留空时自动拼接 GitHub Release 地址。
CLIENT_DATA_DOWNLOAD_URL=
```

下载缓存：

```bash
# 下载缓存目录，uninstall 不删除。
AC_DOWNLOAD_DIR="downloads"

# 上次成功的镜像源记录文件。
AC_MIRROR_STATE_FILE="downloads/mirror-preferences.env"

# 是否启用 Docker 镜像 tar 缓存。
AC_DOCKER_IMAGE_ARCHIVE_CACHE=1
```

源码仓库：

```bash
# 主源码仓库，格式为 owner/repo。
ACORE_SOURCE_REPO="liyunfan1223/azerothcore-wotlk"

# 主源码分支。
ACORE_SOURCE_BRANCH="Playerbot"

# 模块仓库列表，格式为 owner/repo。
ACORE_MODULE_REPOS=(
    # Playerbots 主模块。
    liyunfan1223/mod-playerbots
    # Playerbots 等级段模块。
    DustinHendrickson/mod-player-bot-level-brackets
    # 范围拾取模块。
    azerothcore/mod-aoe-loot
    # 个人进度模块。
    ZhengPeiRu21/mod-individual-progression
    # 自动学习技能模块。
    noisiver/mod-learnspells
    # 升级烟花模块。
    azerothcore/mod-fireworks-on-level
    # ALE Lua 扩展模块。
    azerothcore/mod-ale
    # 自动平衡模块。
    azerothcore/mod-autobalance
    # 幻化模块。
    azerothcore/mod-transmog
    # 拍卖行机器人增强模块。
    NathanHandley/mod-ah-bot-plus
    # 升级祝贺模块。
    azerothcore/mod-congrats-on-level
    # 跨阵营战场模块。
    azerothcore/mod-cfbg
)
```

Docker 镜像：

```bash
DOCKER_BASE_IMAGES=(
    "ubuntu:24.04"
    "mysql:8.4"
    "moby/buildkit:buildx-stable-1"
)

DOCKER_BUILDX_BUILDER_NAME="acore-builder"
DOCKER_BUILDKIT_IMAGE="moby/buildkit:buildx-stable-1"

# Docker 加速源检测用的小镜像，检测成功后会删除。
DOCKER_MIRROR_PROBE_IMAGE="hello-world:latest"
DOCKER_MIRROR_PROBE_TIMEOUT=5
```

内存配置：

```bash
# 1=自动规划。
AC_MEMORY_AUTO=1

# 留空时按“当前系统已用内存 + 512MB”保留。
AC_MEMORY_RESERVED_MB=
AC_MEMORY_DYNAMIC_RESERVED_EXTRA_MB=512

# 留空时自动规划。
DOCKER_BUILD_MEMORY_LIMIT=
DOCKER_BUILD_PARALLEL_JOBS=
AC_DATABASE_MEMORY_LIMIT=
AC_WORLDSERVER_MEMORY_LIMIT=
AC_AUTHSERVER_MEMORY_LIMIT=
AC_CLIENT_DATA_INIT_MEMORY_LIMIT=
AC_DATABASE_INNODB_BUFFER_POOL_SIZE=
```

日志配置：

```bash
AC_LOG_DIR="build/logs"
AC_LOG_FILE="build/logs/ac.log"
AC_DOWNLOAD_LOG_FILE="build/logs/downloads.log"
AC_MIRROR_LOG_FILE="build/logs/mirrors.log"
```

### mirrors.conf

Ubuntu apt 镜像：

```bash
UBUNTU_MIRROR="mirrors.aliyun.com"
```

GitHub Release 文件下载代理：

```bash
GITHUB_RELEASE_ASSET_MIRRORS=(
    "https://gh-proxy.com/"
    "https://gh.llkk.cc/"
    "https://gh.idayer.com/"
    "https://ghproxy.net/"
)
```

GitHub Release latest 解析代理：

```bash
GITHUB_RELEASE_LATEST_MIRRORS=(
    "https://gh.idayer.com/"
    "https://gh-proxy.com/"
    "https://gh.llkk.cc/"
)
```

GitHub 源码压缩包代理：

```bash
GITHUB_SOURCE_ARCHIVE_MIRRORS=(
    "https://gh-proxy.com/"
    "https://gh.llkk.cc/"
    "https://gh.idayer.com/"
)
```

Docker 镜像拉取加速源：

```bash
DOCKER_IMAGE_PULL_MIRRORS=(
    "docker.m.daocloud.io"
    "docker.1ms.run"
    "docker.xuanyuan.me"
    "dockerproxy.net"
    "docker.chenby.cn"
)
```

## 主要逻辑

`install` 和 `update` 的执行顺序：

1. 检查 Docker 服务和必要命令。
2. 检查 `downloads/` 中是否已有源码包、客户端数据包和 Docker 镜像缓存。
3. 缓存缺失时检测可用加速源。
4. 下载或复用源码包、模块包、客户端数据包、Docker 镜像 tar。
5. 根据当前系统内存自动规划构建和运行内存。
6. 初始化 `build/` 和 `wotlk/`。
7. 解压源码和模块到 `build/azerothcore-wotlk`。
8. 生成构建用 Dockerfile 和 BuildKit 配置。
9. 使用 Docker Compose 构建并启动服务。
10. 初始化数据库并写入 realmlist 配置。

目录说明：

| 路径 | 说明 |
| --- | --- |
| `downloads/` | 下载缓存，`uninstall` 不删除 |
| `build/` | 构建目录和日志，`uninstall` 会删除 |
| `wotlk/` | 运行数据、数据库、配置和客户端数据，`uninstall` 会删除 |
| `build/logs/ac.log` | 主日志 |
| `build/logs/downloads.log` | 下载和缓存日志 |
| `build/logs/mirrors.log` | 加速源检测日志 |
