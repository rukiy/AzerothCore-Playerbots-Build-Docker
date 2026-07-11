# 多发行版一键安装实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `install.sh` 完善为支持 Ubuntu、Debian、Rocky Linux、AlmaLinux 指定版本的安全一键安装入口。

**Architecture:** 保持单文件公开入口，按系统识别、依赖准备、Docker 预检、路径校验、下载解压和安装执行拆分 Bash 函数。快速测试通过临时 `PATH` 和临时 `os-release` 驱动真实函数，容器冒烟测试验证四类发行版的真实包管理器路径。

**Tech Stack:** Bash、Git、Docker、Docker Compose、Buildx、`apt-get`、`dnf`、`unzip`

---

## 文件结构

- 修改 `.gitignore`：让 `tests/` 正式受 Git 跟踪，继续忽略 `.worktrees/`。
- 修改 `install.sh`：实现全部引导安装行为，不把逻辑扩散到 AzerothCore 编排脚本。
- 修改 `README.md`：记录支持矩阵、Docker 前置条件和已有目录策略。
- 创建 `tests/test_helper.sh`：提供断言、临时目录、命令替身和安装器加载函数。
- 创建 `tests/test_install_source.sh`：验证脚本可安全加载并保持公开入口。
- 创建 `tests/test_install_platform.sh`：验证发行版、版本和依赖安装。
- 创建 `tests/test_install_docker.sh`：验证 Docker Engine、服务、Compose 和 Buildx。
- 创建 `tests/test_install_path.sh`：验证路径规范化、危险路径和临时目录。
- 创建 `tests/test_install_flow.sh`：验证下载回退、归档校验、成功安装和失败保留。
- 创建 `tests/run.sh`：快速测试统一入口和 Shell 语法检查。
- 创建 `tests/smoke/run.sh`：四类发行版容器冒烟测试入口。

### 任务 1：建立可跟踪的测试入口

**文件：**
- 修改：`.gitignore:4`
- 修改：`install.sh:137-141`
- 创建：`tests/test_helper.sh`
- 创建：`tests/test_install_source.sh`
- 创建：`tests/run.sh`

- [ ] **步骤 1：编写失败测试，要求加载脚本时不执行安装**

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]' "$ROOT_DIR/install.sh" || {
    echo "FAIL: install.sh 被 source 时仍会执行 main" >&2
    exit 1
}

source "$ROOT_DIR/install.sh"
declare -F main >/dev/null || {
    echo "FAIL: 缺少 main 函数" >&2
    exit 1
}

echo "test_install_source 通过"
```

- [ ] **步骤 2：运行测试并确认按预期失败**

运行：`bash tests/test_install_source.sh`

预期：失败并输出 `install.sh 被 source 时仍会执行 main`。

- [ ] **步骤 3：加入安全入口并建立测试辅助函数**

将 `install.sh` 末尾改为：

```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
```

创建 `tests/test_helper.sh`：

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    [ "$expected" = "$actual" ] || fail "$message: expected=$expected actual=$actual"
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local message="$3"
    [[ "$text" == *"$expected"* ]] || fail "$message: 缺少 $expected"
}

load_installer() {
    source "$ROOT_DIR/install.sh"
}
```

创建 `tests/run.sh`：

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for test_file in "$ROOT_DIR"/tests/test_install_*.sh; do
    [ -f "$test_file" ] || continue
    bash "$test_file"
done

for script_file in \
    "$ROOT_DIR/ac.sh" \
    "$ROOT_DIR/install.sh" \
    "$ROOT_DIR/src/lib.sh" \
    "$ROOT_DIR"/src/lib/*.sh \
    "$ROOT_DIR"/src/lib/extra/*.sh; do
    [ -f "$script_file" ] || continue
    bash -n "$script_file"
done

echo "快速测试全部通过"
```

- [ ] **步骤 4：移除测试忽略并验证测试转绿**

从 `.gitignore` 删除 `tests/`，保留：

```text
build
wotlk
agent.md
downloads/
.worktrees/
```

运行：`bash tests/run.sh`

预期：`test_install_source 通过`，Shell 语法检查通过。

- [ ] **步骤 5：提交测试入口**

```bash
git add .gitignore install.sh tests/test_helper.sh tests/test_install_source.sh tests/run.sh
git commit -m "test: 建立一键安装测试入口"
```

### 任务 2：识别发行版并安装基础依赖

**文件：**
- 修改：`install.sh:4-42`
- 创建：`tests/test_install_platform.sh`

- [ ] **步骤 1：编写发行版矩阵失败测试**

测试为每组数据创建临时 `os-release`，设置 `AC_OS_RELEASE_FILE` 后调用 `detect_platform`：

```bash
cases=(
    "ubuntu|22.04|apt"
    "ubuntu|24.04|apt"
    "debian|12|apt"
    "debian|13|apt"
    "rocky|9|dnf"
    "rocky|10|dnf"
    "almalinux|9|dnf"
    "almalinux|10|dnf"
)

for item in "${cases[@]}"; do
    IFS='|' read -r id version manager <<< "$item"
    printf 'ID=%s\nVERSION_ID="%s"\n' "$id" "$version" > "$os_release"
    AC_OS_RELEASE_FILE="$os_release" detect_platform
    assert_eq "$id" "$AC_OS_ID" "发行版识别错误"
    assert_eq "$manager" "$AC_PACKAGE_MANAGER" "包管理器识别错误"
done
```

再验证 Ubuntu 20.04、Debian 11、Rocky 8、AlmaLinux 8、Fedora 及缺少 `os-release` 时返回非零状态并包含支持列表。

- [ ] **步骤 2：运行测试并确认缺少 `detect_platform`**

运行：`bash tests/test_install_platform.sh`

预期：失败并输出 `detect_platform: command not found`。

- [ ] **步骤 3：实现系统识别**

在 `install.sh` 增加：

```bash
detect_platform() {
    local os_release_file="${AC_OS_RELEASE_FILE:-/etc/os-release}"
    local major_version

    [ -r "$os_release_file" ] || {
        echo "错误：无法读取系统信息文件 $os_release_file" >&2
        return 1
    }

    AC_OS_ID="$(sed -n 's/^ID=//p' "$os_release_file" | tr -d '"' | head -n1)"
    AC_OS_VERSION_ID="$(sed -n 's/^VERSION_ID=//p' "$os_release_file" | tr -d '"' | head -n1)"
    major_version="${AC_OS_VERSION_ID%%.*}"

    case "$AC_OS_ID:$major_version" in
        ubuntu:22|ubuntu:24|debian:12|debian:13)
            AC_PACKAGE_MANAGER="apt"
            ;;
        rocky:9|rocky:10|almalinux:9|almalinux:10)
            AC_PACKAGE_MANAGER="dnf"
            ;;
        *)
            echo "错误：不支持的系统: ID=$AC_OS_ID VERSION_ID=$AC_OS_VERSION_ID" >&2
            echo "支持 Ubuntu 22.04/24.04、Debian 12/13、Rocky Linux 9/10、AlmaLinux 9/10" >&2
            return 1
            ;;
    esac
}
```

- [ ] **步骤 4：编写依赖安装失败测试**

通过临时 `PATH` 放置 `apt-get`、`dnf` 命令替身并记录参数。验证：全部命令存在时不调用包管理器；缺少命令时 `apt-get update` 后执行 `apt-get install -y --no-install-recommends ca-certificates curl wget unzip gawk sed findutils procps coreutils`；DNF 执行 `dnf install -y ca-certificates curl wget unzip gawk sed findutils procps-ng coreutils`。

- [ ] **步骤 5：实现最小依赖安装逻辑并验证**

新增以下函数；依赖安装完成后重新检查命令，仍缺失时列出命令并返回非零状态：

```bash
bootstrap_commands_available() {
    local command_name
    for command_name in curl wget unzip awk sed find free sha256sum realpath mktemp; do
        command -v "$command_name" >/dev/null 2>&1 || return 1
    done
}

install_bootstrap_dependencies() {
    bootstrap_commands_available && return 0

    case "$AC_PACKAGE_MANAGER" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y --no-install-recommends \
                ca-certificates curl wget unzip gawk sed findutils procps coreutils
            ;;
        dnf)
            dnf install -y \
                ca-certificates curl wget unzip gawk sed findutils procps-ng coreutils
            ;;
        *)
            echo "错误：未知包管理器: $AC_PACKAGE_MANAGER" >&2
            return 1
            ;;
    esac
}

check_bootstrap_commands() {
    local command_name
    local missing=()

    for command_name in curl wget unzip awk sed find free sha256sum realpath mktemp; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "错误：安装基础依赖后仍缺少命令: ${missing[*]}" >&2
        return 1
    fi
}
```

运行：`bash tests/test_install_platform.sh`

预期：所有平台与依赖测试通过。

- [ ] **步骤 6：提交发行版支持**

```bash
git add install.sh tests/test_install_platform.sh
git commit -m "feat: 支持多发行版基础依赖准备"
```

### 任务 3：增加 Docker 能力预检

**文件：**
- 修改：`install.sh`
- 创建：`tests/test_install_docker.sh`

- [ ] **步骤 1：编写四类 Docker 失败测试**

使用临时 `PATH` 中的 `docker` 替身分别模拟：命令不存在、`docker info` 失败、`docker compose version` 失败、`docker buildx version` 失败。每种情况调用 `check_docker_environment`，断言返回非零且错误信息包含缺失能力和以下命令之一：

```text
docker info
docker compose version
docker buildx version
```

- [ ] **步骤 2：运行测试并确认缺少检查函数**

运行：`bash tests/test_install_docker.sh`

预期：失败并输出 `check_docker_environment: command not found`。

- [ ] **步骤 3：实现顺序预检和发行版提示**

```bash
check_docker_environment() {
    command -v docker >/dev/null 2>&1 || {
        print_docker_help "未安装 Docker Engine"
        return 1
    }
    docker info >/dev/null 2>&1 || {
        print_docker_help "Docker 服务不可用，请检查 docker info"
        return 1
    }
    docker compose version >/dev/null 2>&1 || {
        print_docker_help "缺少 Docker Compose 插件，请检查 docker compose version"
        return 1
    }
    docker buildx version >/dev/null 2>&1 || {
        print_docker_help "缺少 Docker Buildx 插件，请检查 docker buildx version"
        return 1
    }
}
```

`print_docker_help` 根据 `AC_PACKAGE_MANAGER` 输出以下提示，但不得执行包管理器和 `systemctl`：

```bash
print_docker_help() {
    local reason="$1"
    echo "错误：$reason" >&2
    case "$AC_PACKAGE_MANAGER" in
        apt)
            echo "请按 Docker 官方 Ubuntu/Debian 文档安装 Docker Engine、Compose 和 Buildx 插件。" >&2
            ;;
        dnf)
            echo "请按 Docker 官方 RHEL 文档安装 Docker Engine、Compose 和 Buildx 插件。" >&2
            ;;
    esac
    echo "检查命令: docker info" >&2
    echo "检查命令: docker compose version" >&2
    echo "检查命令: docker buildx version" >&2
}
```

- [ ] **步骤 4：运行快速测试并提交**

运行：`bash tests/run.sh`

预期：平台测试和 Docker 测试全部通过。

```bash
git add install.sh tests/test_install_docker.sh
git commit -m "feat: 增加 Docker 环境预检"
```

### 任务 4：收紧安装路径和临时目录

**文件：**
- 修改：`install.sh:82-110`
- 创建：`tests/test_install_path.sh`

- [ ] **步骤 1：编写路径校验失败测试**

验证 `validate_install_dir` 拒绝相对路径、已有文件、已有目录、符号链接以及以下等价危险路径：

```text
/
/root
/root/
/root/..
/tmp
/tmp/
/etc
/var
/usr
/home
```

同时验证 `/root/acore`、`/opt/acore`、`/srv/acore` 和 `/data/acore` 可通过，并返回规范化绝对路径。

- [ ] **步骤 2：运行测试并确认当前黑名单可被绕过**

运行：`bash tests/test_install_path.sh`

预期：至少 `/root/` 或 `/root/..` 用例失败，证明现有字符串比较不安全。

- [ ] **步骤 3：实现规范化校验**

```bash
validate_install_dir() {
    local requested="$1"
    local normalized

    case "$requested" in
        /*) ;;
        *) echo "错误：安装目录必须是绝对路径: $requested" >&2; return 1 ;;
    esac

    normalized="$(realpath -m -- "$requested")" || return 1
    case "$normalized" in
        /|/root|/home|/usr|/var|/etc|/tmp)
            echo "错误：安装目录不安全: $normalized" >&2
            return 1
            ;;
    esac

    if [ -e "$normalized" ] || [ -L "$normalized" ]; then
        echo "错误：安装目录已存在: $normalized" >&2
        return 1
    fi

    printf '%s\n' "$normalized"
}
```

- [ ] **步骤 4：测试并实现同文件系统临时目录**

测试 `create_install_temp_dir /data/apps/acore` 会先创建 `/data/apps`，再通过 `mktemp -d /data/apps/.acore-installer.XXXXXX` 创建临时目录；清理函数只删除该目录。

实现：

```bash
create_install_temp_dir() {
    local install_dir="$1"
    local parent_dir
    parent_dir="$(dirname "$install_dir")"
    mkdir -p "$parent_dir"
    AC_INSTALL_TMP_DIR="$(mktemp -d "$parent_dir/.acore-installer.XXXXXX")"
}

cleanup_install_temp_dir() {
    [ -n "${AC_INSTALL_TMP_DIR:-}" ] || return 0
    [ -d "$AC_INSTALL_TMP_DIR" ] || return 0
    rm -rf -- "$AC_INSTALL_TMP_DIR"
}
```

- [ ] **步骤 5：运行快速测试并提交**

运行：`bash tests/run.sh`

预期：所有路径测试通过，工作区外无残留 `.acore-installer.*`。

```bash
git add install.sh tests/test_install_path.sh
git commit -m "fix: 收紧一键安装目录安全规则"
```

### 任务 5：完成下载、归档校验和安装执行

**文件：**
- 修改：`install.sh`
- 创建：`tests/test_install_flow.sh`

- [ ] **步骤 1：编写下载回退失败测试**

使用 `curl` 替身让原站和前两个代理失败、第三个代理成功，调用 `download_archive` 后断言调用顺序为原站、`gh-proxy.com`、`gh.llkk.cc`、`gh.idayer.com`，并确认成功文件被写入指定路径。再验证所有地址失败时返回非零。

- [ ] **步骤 2：运行测试并观察当前行为差异**

运行：`bash tests/test_install_flow.sh`

预期：因新的函数参数和错误汇总尚未实现而失败。

- [ ] **步骤 3：实现可靠下载**

`fetch_url` 先写入 `$output_file.part`，成功后 `mv` 到最终文件；失败时删除 `.part`。`download_archive` 逐项打印 `下载: URL`，保留最后一次下载错误并在全部失败后列出所有已尝试地址。

- [ ] **步骤 4：编写归档结构和执行失败测试**

测试创建四种本地 ZIP：损坏文件、多个顶层目录、缺少 `ac.sh`、完整项目。完整项目中的 `ac.sh` 写入调用标记并根据 `AC_TEST_INSTALL_EXIT_CODE` 返回指定状态。

断言：前三种不会创建目标目录；完整项目成功时收到参数 `install`；返回 23 时 `main` 返回 23、目标项目目录和日志标记仍存在。

- [ ] **步骤 5：实现归档校验和主流程**

新增 `extract_and_validate_archive`，要求 ZIP 只有一个顶层项目目录并包含 `ac.sh`、`ac.conf`、`src/lib.sh`。主流程固定为：

```bash
main() {
    local archive_file install_dir source_dir

    [ "$(id -u)" = 0 ] || {
        echo "错误：必须以 root 权限运行" >&2
        return 1
    }

    detect_platform
    install_bootstrap_dependencies
    check_bootstrap_commands
    check_docker_environment
    install_dir="$(validate_install_dir "$AC_INSTALL_DIR")"
    create_install_temp_dir "$install_dir"
    trap cleanup_install_temp_dir EXIT
    archive_file="$AC_INSTALL_TMP_DIR/source.zip"
    download_archive "$archive_file"
    source_dir="$(extract_and_validate_archive "$archive_file" "$AC_INSTALL_TMP_DIR/source")"
    mv -- "$source_dir" "$install_dir"
    cd "$install_dir"
    chmod +x ./ac.sh
    ./ac.sh install
}
```

- [ ] **步骤 6：运行全量快速测试并提交**

运行：`bash tests/run.sh`

预期：下载、归档、状态码透传和目录保留测试全部通过。

```bash
git add install.sh tests/test_install_flow.sh
git commit -m "feat: 完成一键下载与安装流程"
```

### 任务 6：增加容器冒烟测试并更新文档

**文件：**
- 创建：`tests/smoke/run.sh`
- 修改：`README.md:13-45`

- [ ] **步骤 1：编写容器冒烟测试入口**

`tests/smoke/run.sh` 依次运行以下镜像：

```bash
images=(
    "ubuntu:22.04"
    "ubuntu:24.04"
    "debian:12"
    "debian:13"
    "rockylinux:9"
    "rockylinux:10"
    "almalinux:9"
    "almalinux:10"
)
```

每个容器挂载当前仓库，只执行系统识别和基础依赖安装，然后确认 `curl wget unzip awk sed find free sha256sum realpath mktemp` 均可用。Docker 预检单元测试继续使用替身，不把宿主 Docker Socket 挂载进容器。

- [ ] **步骤 2：运行四类发行版冒烟测试**

运行：`bash tests/smoke/run.sh`

预期：8 个镜像均输出 `通过`。若镜像标签不存在，先核对发行版官方镜像的对应稳定标签并同步修正设计文档、计划和测试数组后重跑，不得跳过该发行版。

- [ ] **步骤 3：更新中文 README**

在使用方法前补充支持矩阵，并明确：

```text
一键安装支持 Ubuntu 22.04/24.04、Debian 12/13、Rocky Linux 9/10、AlmaLinux 9/10。
执行前必须已安装并启动 Docker Engine，同时提供 Docker Compose 与 Buildx 插件。
安装目录必须是尚不存在的绝对路径；脚本不会覆盖或备份已有目录。
脚本使用系统现有软件源，不会自动改写软件源配置。
```

- [ ] **步骤 4：执行最终验证**

运行：

```bash
bash tests/run.sh
bash tests/smoke/run.sh
git diff --check
git status --short
```

预期：快速测试和 8 个容器测试全部通过，`git diff --check` 无输出，状态中只包含本任务预期文件。

- [ ] **步骤 5：提交文档和冒烟测试**

```bash
git add README.md tests/smoke/run.sh
git commit -m "test: 增加多发行版安装冒烟验证"
```

### 任务 7：分支验收与推送

**文件：**
- 验证全部已修改文件

- [ ] **步骤 1：核对提交和主分支隔离**

运行：

```bash
git status --short --branch
git log --oneline main..feature/one-command-install
git -C /data/acore status --short --branch
```

预期：功能 worktree 干净；提交说明均为中文；`/data/acore` 位于 `main` 且工作区干净。

- [ ] **步骤 2：重新运行全部验证**

运行：

```bash
bash tests/run.sh
bash tests/smoke/run.sh
bash -n install.sh
```

预期：全部返回 0。

- [ ] **步骤 3：推送功能分支**

```bash
git push origin feature/one-command-install
```

预期：远端功能分支更新成功，不合并到 `main`。
