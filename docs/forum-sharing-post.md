# [分享] 不懂 Docker 也能搭：一条命令安装 AzerothCore + 500 个 Playerbots

最近想搭一个自己玩的巫妖王之怒服务器，最好还能带机器人。人少的时候可以和机器人组队下副本、打战场，不用为了凑人一直等。

我不懂源码编译，对 Docker 也只是知道名字。以前看到搭建教程里一大串数据库、编译参数和配置文件，基本看几页就放弃了。后来找到这个 AzerothCore + Playerbots Docker 安装项目，实际使用思路很简单：先准备一台符合要求的 Linux 服务器和 Docker，然后用 root 执行一条安装命令，剩下的下载、编译、数据库初始化和启动都交给脚本处理。

项目地址：

https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker

## 它帮我省掉了哪些步骤

按照项目说明，脚本会自动准备 AzerothCore Playerbot 分支、Playerbots 和其他模块、服务端需要的客户端数据、MySQL 以及 Docker 构建环境。安装过程中还会检测 GitHub 和 Docker 加速地址，并根据服务器当前内存自动分配编译和运行内存。

对我这种不懂技术的人来说，最大的好处不是完全不需要准备环境，而是不再需要自己研究怎么编译核心、导入数据库、放置模块和拼 Docker 配置。

安装完成以后，常用操作也集中在 `ac.sh` 里。更新、启停、检测镜像和卸载都有固定命令，不用记一堆 Docker 参数。

## 安装前要准备什么

目前支持以下 64 位 Linux 系统：

- Ubuntu 22.04、24.04
- Debian 12、13
- Rocky Linux 9、10
- AlmaLinux 9、10

服务器上需要提前安装并启动 Docker Engine，同时要有 Docker Compose v2 和 Docker Buildx。安装命令需要使用 root 用户执行。

内存方面，我按照项目给出的建议理解：

- 4GB 是最低建议，可以安装和运行，但编译慢，不适合放很多 Playerbots。
- 8GB 是推荐配置，适合自用和默认 500 个 Playerbots。
- 12GB～16GB 更适合更多机器人、较高在线人数，或者边运行边编译。

4GB 并不代表任何时候都一定够。如果系统本身已经占用了很多内存，脚本仍可能提示可用内存不足。有条件的话，我会直接从 8GB 起步。

## 一键安装

切换到 root 用户后，执行下面这条命令：

```bash
bash <(curl -fsSL https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

默认安装到当前用户的 `~/acore`。如果 GitHub 访问比较慢，可以换成这个加速地址：

```bash
bash <(curl -fsSL 'https://gh-proxy.com/https://raw.githubusercontent.com/rukiy/AzerothCore-Playerbots-Build-Docker/main/install.sh')
```

加速地址是第三方代理，介意安全边界的话就使用上面的 GitHub 原站命令。安装目录必须是一个尚不存在的绝对路径，脚本不会覆盖已有目录。

第一次安装要下载源码、模块、客户端数据和 Docker 镜像，还要编译服务端，所以具体耗时会受服务器性能和网络速度影响。这个过程不是下载完立刻就能进游戏，看到脚本正在下载或编译时耐心等即可。

## 默认集成的模块

这个项目不只是装了一个空的 AzerothCore，默认还集成了下面 12 个模块：

- `liyunfan1223/mod-playerbots`：玩家机器人，是这个项目最主要的功能。
- `DustinHendrickson/mod-player-bot-level-brackets`：按等级段管理 Playerbots。
- `azerothcore/mod-aoe-loot`：范围拾取，清怪以后捡东西方便很多。
- `ZhengPeiRu21/mod-individual-progression`：个人进度控制。
- `noisiver/mod-learnspells`：自动学习符合条件的技能。
- `azerothcore/mod-fireworks-on-level`：升级时播放烟花效果。
- `azerothcore/mod-ale`：提供 Lua 脚本扩展能力。
- `azerothcore/mod-autobalance`：根据队伍和人数动态调整副本难度。
- `azerothcore/mod-transmog`：装备幻化。
- `NathanHandley/mod-ah-bot-plus`：增强拍卖行机器人功能。
- `azerothcore/mod-congrats-on-level`：升级时发送祝贺消息。
- `azerothcore/mod-cfbg`：支持跨阵营战场匹配。

我比较看重的是 Playerbots、自动平衡、范围拾取、幻化和拍卖行机器人。一个人或者几个人玩时，这些功能比单纯把服务端跑起来实用得多。默认模块也不是写死的，懂配置以后可以在 `ac.conf` 的 `ACORE_MODULE_REPOS` 里调整。

## 安装完成后怎么进游戏

安装完成后，先进入世界服控制台：

```bash
docker attach ac-worldserver
```

然后创建账号并设置 GM 权限：

```text
account create 用户名 密码
account set gmlevel 用户名 3 -1
```

退出控制台时不要直接按 `Ctrl+C`，使用：

```text
Ctrl+p Ctrl+q
```

最后把客户端的 `realmlist.wtf` 改成服务器地址：

```text
set realmlist 你的服务器地址
```

## 平时会用到的命令

进入项目目录后，主要记住下面几个就够了：

```bash
# 更新并重新构建，保留运行数据
./ac.sh update

# 启动或停止数据库、认证服和世界服
./ac.sh toggle

# 检测 GitHub 和 Docker 加速源
./ac.sh mirrors

# 卸载容器、镜像、构建目录和运行目录
./ac.sh uninstall
```

需要注意，`uninstall` 会删除运行数据目录 `wotlk/`，不是普通的停止服务。只是暂时关服应该用 `./ac.sh toggle`。

## 我的感受和一些提醒

这个项目比较适合想搭自用服、朋友服，又不想从源码编译开始学的人。它没有把所有前置条件都变没，Docker 还是要先准备好，服务器配置和网络也会影响安装，但最麻烦、最容易出错的步骤已经被串起来了。

准备尝试的话，我建议先看一遍项目 README，确认系统版本、内存和安装目录都符合要求。重要数据也要自己做备份，不要把“一键安装”理解成以后完全不用维护。

我把项目地址再放一次：

https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker

同样在玩 AzerothCore 或 Playerbots 的朋友，可以交流一下实际使用情况和配置经验。
