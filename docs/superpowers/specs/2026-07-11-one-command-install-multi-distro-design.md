# 多发行版一键安装设计

## 目标

完善 `install.sh`，让用户能够通过一条 Bash 命令在受支持的 Linux 服务器上完成项目下载、环境预检和 AzerothCore 安装启动。

首批支持以下系统：

| 发行版 | 支持版本 | 包管理器 |
| --- | --- | --- |
| Ubuntu | 22.04、24.04 | `apt-get` |
| Debian | 12、13 | `apt-get` |
| Rocky Linux | 9、10 | `dnf` |
| AlmaLinux | 9、10 | `dnf` |

## 非目标

- 不自动安装 Docker Engine、Docker Compose 或 Buildx。
- 不修改 `/etc/apt`、`/etc/yum.repos.d` 等系统软件源配置。
- 不覆盖、移动或删除已有安装目录。
- 不在本轮整合 `dev` 分支的 CNB 在线构建和运行包发布功能。
- 不修改 AzerothCore、Playerbots 或其他模块源码。

## 总体结构

继续使用单个 `install.sh` 作为公开入口，不为不同发行版复制独立安装脚本。脚本内部按职责拆分函数：

- 系统识别：读取 `/etc/os-release`，识别发行版和主版本。
- 依赖准备：选择 `apt-get` 或 `dnf`，安装基础命令。
- Docker 预检：验证 Engine、Compose、Buildx 和 Docker 服务。
- 路径校验：规范化并校验安装目录，拒绝危险路径和已有路径。
- 项目下载：按原站优先、国内代理回退的顺序下载源码 ZIP。
- 归档安装：校验 ZIP 内容，原子移动到目标目录并调用 `ac.sh install`。

现有 `ac.sh` 和 `src/lib/` 继续负责源码、客户端数据、镜像、构建、数据库和运行服务，不把这些编排逻辑复制到引导脚本。

## 执行流程

1. 验证当前用户为 `root`。
2. 读取系统信息并校验支持矩阵。
3. 使用系统现有软件源安装 `ca-certificates`、`curl`、`wget`、`unzip`、`awk`、`sed`、`find`、`procps` 等基础依赖。
4. 验证 `docker` 命令、Docker 服务、`docker compose` 和 `docker buildx`。
5. 使用 `realpath -m` 规范化 `AC_INSTALL_DIR`，要求它是绝对路径且尚不存在。
6. 使用 `mktemp -d` 创建本次执行专属临时目录，并注册退出清理函数。
7. 下载 `AC_INSTALL_REPO` 的 `AC_INSTALL_BRANCH` 源码 ZIP；GitHub 原站失败时依次尝试国内代理。
8. 解压到临时目录并验证归档中存在 `ac.sh`、`ac.conf` 和 `src/lib.sh`。
9. 将已验证的项目目录移动到目标路径。
10. 进入目标目录执行 `./ac.sh install`，原样返回安装结果。

## 配置接口

保留以下环境变量：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `AC_INSTALL_DIR` | `$HOME/acore` | 目标安装目录 |
| `AC_INSTALL_BRANCH` | `main` | 下载的源码分支 |
| `AC_INSTALL_REPO` | `rukiy/AzerothCore-Playerbots-Build-Docker` | GitHub 仓库 |

测试所需的系统信息文件和命令替身通过测试进程的临时 `PATH` 与环境变量注入，不改变公开使用方式。

## 安全边界

安装目录必须满足以下条件：

- 输入值必须是绝对路径；拒绝 `.`、`..` 和其他相对路径。
- 校验前使用 `realpath -m` 消除尾部斜杠、父目录和重复分隔符。
- 拒绝 `/`、`/root`、`/home`、`/usr`、`/var`、`/etc`、`/tmp` 以及它们的等价写法。
- 目标路径只要已经存在，无论是文件、目录还是符号链接，都立即退出。
- 下载和解压发生在临时目录；归档通过结构校验前不得创建目标目录。
- 临时目录由 `mktemp -d` 创建，退出时只清理本次生成的已知路径。

脚本不自动安装 Docker。Docker 前置条件不满足时，仅输出当前发行版对应的处理方向和以下检查命令：

```bash
docker info
docker compose version
docker buildx version
```

## 错误处理

- 不支持的发行版或版本：输出检测到的 `ID`、`VERSION_ID` 和支持列表，返回非零状态。
- 系统依赖安装失败：保留包管理器错误输出，提示当前软件源不可用，不修改软件源配置。
- Docker 能力缺失：指出缺失项后退出，不继续下载源码。
- 所有下载地址失败：输出已尝试的地址和最后一次下载错误，返回非零状态。
- ZIP 无效或缺少关键文件：清理临时目录，不创建安装目录。
- `ac.sh install` 失败：保留已经解压的项目目录及其日志，返回原始非零状态，便于继续排查。

## 测试设计

将 `tests/` 从 `.gitignore` 中移除并纳入版本控制，提供统一快速测试入口 `tests/run.sh`。

快速测试覆盖：

- 8 个受支持系统版本的识别结果和包管理器选择。
- 未支持发行版、低版本和未知版本的失败信息。
- `apt-get`、`dnf` 安装命令以及依赖已存在时不重复安装。
- Docker Engine、服务、Compose、Buildx 四类失败路径。
- 危险路径、相对路径、等价路径、符号链接和已有目标路径。
- GitHub 原站失败后的代理回退顺序。
- 损坏 ZIP、错误目录结构和缺少关键文件的 ZIP。
- 使用本地测试归档完成黑盒引导，并确认调用 `ac.sh install`。
- `ac.sh install` 失败时状态码透传且项目目录保留。
- 所有 Shell 文件通过 `bash -n`。

另提供独立的容器冒烟测试，分别使用 Ubuntu、Debian、Rocky Linux 和 AlmaLinux 镜像验证真实包管理器路径。冒烟测试不修改宿主机软件源，不作为每次快速测试的强制依赖。

## 验收标准

- `tests/run.sh` 全部通过。
- 四类发行版容器冒烟测试全部通过。
- 隔离目录中的本地归档黑盒安装测试通过。
- `main` 工作区在开发期间保持干净。
- 功能分支只修改项目安装入口、测试和相关中文文档。
- README 的公开一键安装命令仅在功能合并到 `main` 后作为正式入口使用。
