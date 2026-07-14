# 下载阶段结果输出实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让每个下载对象成功后按统一格式进入控制台和 `ac.log`，最终失败时输出最后下载源的原始错误，同时保留 `downloads.log` 的完整记录。

**Architecture:** 在 `src/lib/02_prepare.sh` 增加成功与失败结果输出函数，使用专用文件描述符绕过下载阶段现有的静默重定向。文件、客户端版本和 Docker 下载函数各自保存最后候选源及错误；成功时立即报告实际来源，缓存命中时报告“本地缓存”。

**Tech Stack:** Bash、命令替身、文件描述符、项目现有日志函数、无外部测试框架的 Bash 回归测试。

---

## 文件结构

- 修改 `.gitignore`：允许版本控制下载结果回归测试。
- 创建 `tests/test_download_reporting.sh`：覆盖成功、缓存、最后源失败和阶段输出边界。
- 创建 `tests/run.sh`：统一运行 Bash 回归测试和语法检查。
- 修改 `src/lib/02_prepare.sh`：实现结果报告、来源追踪与重定向旁路。

### 任务 1：建立失败回归测试

**Files:**
- Modify: `.gitignore`
- Create: `tests/test_download_reporting.sh`
- Create: `tests/run.sh`
- Test: `tests/test_download_reporting.sh`

- [ ] **步骤 1：允许跟踪测试目录并创建断言辅助函数**

从 `.gitignore` 删除 `tests/`。创建测试脚本，加载真实下载函数并提供断言：

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

DOWNLOAD_LOG_DIR="$TEST_TMP_DIR/logs"
DOWNLOAD_LOG_FILE="$DOWNLOAD_LOG_DIR/downloads.log"
mkdir -p "$DOWNLOAD_LOG_DIR"
: > "$DOWNLOAD_LOG_FILE"

# shellcheck source=../src/lib/02_prepare.sh
source "$ROOT_DIR/src/lib/02_prepare.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"
    [[ "$text" == *"$expected"* ]] || fail "未找到: $expected"
}

assert_not_contains() {
    local text="$1"
    local unexpected="$2"
    [[ "$text" != *"$unexpected"* ]] || fail "不应包含: $unexpected"
}
```

- [ ] **步骤 2：编写文件下载成功、缓存命中与最终失败测试**

在测试脚本中定义可控的 `curl` 函数，验证最终格式和最后候选源错误：

```bash
curl() {
    local output_file=""
    local url=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -o)
                output_file="$2"
                shift 2
                ;;
            http*)
                url="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$url" in
        *success*)
            printf 'archive' > "$output_file"
            ;;
        *first*)
            echo "curl: (28) first source timed out" >&2
            return 28
            ;;
        *)
            echo "curl: (22) last source returned 503" >&2
            return 22
            ;;
    esac
}

target_file="$TEST_TMP_DIR/source.zip"
output="$(download_cached_file "$target_file" "" "AzerothCore 源码" \
    '|https://first.example/success.zip' 3>&1 4>&1)"
assert_contains "$output" "[OK] 下载: AzerothCore 源码 完成: https://first.example/success.zip -> $target_file"

output="$(download_cached_file "$target_file" "" "AzerothCore 源码" \
    '|https://unused.example/source.zip' 3>&1 4>&1)"
assert_contains "$output" "[OK] 下载: AzerothCore 源码 完成: 本地缓存 -> $target_file"

failed_file="$TEST_TMP_DIR/failed.zip"
if output="$(download_cached_file "$failed_file" "" "AzerothCore 源码" \
    '|https://first.example/source.zip' \
    '|https://last.example/source.zip' 3>&1 4>&1)"; then
    fail "全部候选源失败时仍返回成功"
fi
assert_contains "$output" "[ERROR] 下载失败: $failed_file"
assert_contains "$output" "最后下载源: https://last.example/source.zip"
assert_contains "$output" "curl: (22) last source returned 503"
assert_not_contains "$output" "first source timed out"

download_log_text="$(<"$DOWNLOAD_LOG_FILE")"
assert_contains "$download_log_text" "first source timed out"
assert_contains "$download_log_text" "last source returned 503"
```

- [ ] **步骤 3：编写客户端版本和 Docker 镜像最终失败测试**

继续在同一测试脚本中覆盖另外两类下载：

```bash
client_data_latest_candidates() {
    printf '%s\n' \
        '|https://first.example/releases/latest' \
        '|https://last.example/releases/latest'
}

fake_latest_curl() {
    local url="${*: -1}"
    if [[ "$url" == *first* ]]; then
        echo "curl: (28) first latest timed out" >&2
        return 28
    fi
    echo "curl: (22) last latest returned 502" >&2
    return 22
}

unset AC_CLIENT_DATA_RESOLVED_VERSION
CLIENT_DATA_VERSION=latest
AC_CURL_COMMAND=fake_latest_curl
if output="$(resolve_client_data_version 3>&1 4>&1)"; then
    fail "客户端版本全部解析失败时仍返回成功"
fi
assert_contains "$output" "最后下载源: https://last.example/releases/latest"
assert_contains "$output" "curl: (22) last latest returned 502"
assert_not_contains "$output" "first latest timed out"

dockerImagePullCandidates() {
    printf '%s\n' \
        '|mirror.example/first:latest' \
        '|mirror.example/last:latest'
}

docker() {
    case "$1" in
        image)
            return 1
            ;;
        pull)
            if [[ "$2" == *first* ]]; then
                echo "first pull timeout" >&2
            else
                echo "last pull denied" >&2
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

AC_DOCKER_IMAGE_ARCHIVE_CACHE=0
if output="$(pull_docker_image 'docker.io/library/test:latest' 3>&1 4>&1)"; then
    fail "Docker 候选镜像全部失败时仍返回成功"
fi
assert_contains "$output" "最后下载源: mirror.example/last:latest"
assert_contains "$output" "last pull denied"
assert_not_contains "$output" "first pull timeout"

dockerImagePullCandidates() {
    printf '%s\n' '|docker.io/library/test:latest'
}

docker() {
    case "$1" in
        image)
            return 1
            ;;
        pull)
            echo "pulled $2"
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

output="$(pull_docker_image 'docker.io/library/test:latest' 3>&1 4>&1)"
assert_contains "$output" "[OK] 下载: Docker 镜像 完成: docker.io/library/test:latest -> docker.io/library/test:latest"
```

- [ ] **步骤 4：创建统一测试入口**

```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/tests/test_download_reporting.sh"

while IFS= read -r shell_file; do
    bash -n "$shell_file"
done < <(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -name '*.sh' -type f -print)

echo "全部测试通过"
```

- [ ] **步骤 5：运行测试并确认 RED**

运行：

```bash
bash tests/test_download_reporting.sh
```

预期：失败，首个断言指出尚未输出 `[OK] 下载: AzerothCore 源码 完成: ...`。

- [ ] **步骤 6：提交失败测试**

```bash
git add .gitignore tests/test_download_reporting.sh tests/run.sh
git commit -m "test: 增加下载结果输出回归测试"
```

### 任务 2：实现文件下载结果报告

**Files:**
- Modify: `src/lib/02_prepare.sh:45-94`
- Modify: `src/lib/02_prepare.sh:250-305`
- Modify: `src/lib/02_prepare.sh:368-389`
- Modify: `src/lib/02_prepare.sh:586-600`
- Test: `tests/test_download_reporting.sh`

- [ ] **步骤 1：增加统一成功和失败输出函数**

在 `download_log_output` 后增加：

```bash
download_success() {
    local item_name="$1"
    local source="$2"
    local target="$3"
    printf '[OK] 下载: %s 完成: %s -> %s\n' "$item_name" "$source" "$target" >&3
}

download_failure() {
    local target="$1"
    local source="$2"
    local detail="$3"

    download_log "[ERROR] 下载失败: $target"
    {
        printf '[ERROR] 下载失败: %s\n' "$target"
        printf '最后下载源: %s\n' "$source"
        printf '具体错误:\n%s\n' "$detail"
    } >&4
}
```

- [ ] **步骤 2：让文件下载追踪名称、实际来源和最后错误**

将 `download_cached_file` 的第三个参数改为对象名称，候选源从第四个参数开始。缓存命中调用 `download_success "$item_name" "本地缓存" "$target_file"`；下载成功调用 `download_success "$item_name" "$candidate_url" "$target_file"`。每次请求失败保存 `last_source` 和 `last_error`，校验失败时将 `last_error` 设为 `下载文件校验失败`，循环结束调用：

```bash
download_failure \
    "$target_file" \
    "${last_source:-无可用下载源}" \
    "${last_error:-未配置可用下载地址}"
return 1
```

- [ ] **步骤 3：为源码和客户端数据传入稳定名称**

`download_source_archive` 根据仓库生成名称：核心仓库使用 `AzerothCore 源码`，模块使用 `$(source_repo_name "$repo") 源码`。客户端数据调用改为：

```bash
DOWNLOAD_FILE_VALIDATOR=validate_zip_file download_cached_file \
    "$archive_file" \
    AC_PREFERRED_RELEASE_ASSET_MIRROR \
    "客户端数据" \
    "${candidates[@]}"
```

- [ ] **步骤 4：运行文件下载测试并确认 GREEN**

运行：

```bash
bash tests/test_download_reporting.sh
```

预期：文件下载成功与失败断言通过；客户端版本测试仍因缺少最终错误详情而失败。

- [ ] **步骤 5：提交文件下载实现**

```bash
git add src/lib/02_prepare.sh
git commit -m "fix: 输出文件下载成功结果和最终错误"
```

### 任务 3：补齐客户端版本与 Docker 镜像报告

**Files:**
- Modify: `src/lib/02_prepare.sh:496-553`
- Modify: `src/lib/02_prepare.sh:860-920`
- Test: `tests/test_download_reporting.sh`

- [ ] **步骤 1：保存客户端版本解析的最后错误**

在 `resolve_client_data_version` 中增加 `last_source` 和 `last_error`。每次候选请求前记录 URL；请求失败时保存原始 curl 输出；响应成功但版本无效时保存 `响应头中未找到有效客户端数据版本`。最终失败改为：

```bash
download_failure \
    "客户端数据最新版本" \
    "${last_source:-无可用下载源}" \
    "${last_error:-未配置可用下载地址}"
return 1
```

镜像探测中的解析调用补充 `4>&2`，让同一个失败报告函数在探测日志重定向下也有有效的错误输出描述符：

```bash
resolve_client_data_version 4>&2 >/dev/null 2> >(mirror_log_output) || true
```

- [ ] **步骤 2：保存 Docker 拉取的实际来源和最后错误**

`pull_docker_image` 在本地镜像或 tar 缓存命中时调用：

```bash
download_success "Docker 镜像" "本地缓存" "$image"
```

拉取成功时调用：

```bash
download_success "Docker 镜像" "$candidate_ref" "$image"
```

每次 `docker pull` 失败保存候选地址与输出，全部失败后调用：

```bash
download_failure \
    "$image" \
    "${last_source:-无可用下载源}" \
    "${last_error:-未配置可用镜像地址}"
return 1
```

镜像标记失败也使用当前候选源和 `docker tag` 原始错误调用 `download_failure`。

- [ ] **步骤 3：运行专项测试并确认 GREEN**

运行：

```bash
bash tests/test_download_reporting.sh
```

预期：输出 `test_download_reporting 通过`，三类下载的最终成功和失败断言全部通过。

- [ ] **步骤 4：提交客户端与 Docker 实现**

```bash
git add src/lib/02_prepare.sh
git commit -m "fix: 输出客户端和镜像下载最终结果"
```

### 任务 4：打通下载阶段到主日志和控制台的输出边界

**Files:**
- Modify: `src/lib/02_prepare.sh:1005-1016`
- Modify: `tests/test_download_reporting.sh`
- Test: `tests/run.sh`

- [ ] **步骤 1：增加阶段重定向回归测试**

测试定义一个产生普通输出、普通错误和最终结果的阶段函数：

```bash
fake_download_stage() {
    echo "过程标准输出"
    echo "过程标准错误" >&2
    download_success "AzerothCore 源码" "https://example/source.zip" "/cache/source.zip"
}

output="$(run_download_stage fake_download_stage 2>&1)"
assert_contains "$output" "[OK] 下载: AzerothCore 源码 完成: https://example/source.zip -> /cache/source.zip"
assert_not_contains "$output" "过程标准输出"
assert_not_contains "$output" "过程标准错误"

echo "test_download_reporting 通过"
```

- [ ] **步骤 2：运行测试并确认 RED**

运行：

```bash
bash tests/test_download_reporting.sh
```

预期：失败并提示 `run_download_stage: command not found`。

- [ ] **步骤 3：实现专用文件描述符旁路**

新增阶段执行函数，并让 `prepare_downloads` 的三个阶段通过它执行：

```bash
run_download_stage() {
    "$@" 3>&1 4>&2 >/dev/null 2> >(download_log_output)
}

prepare_downloads() {
    check_environment
    ensure_download_cache_dir
    init_download_log
    init_mirror_log
    load_mirror_preferences >/dev/null 2> >(mirror_log_output)
    probe_download_mirrors_for_missing_cache
    log_selected_mirrors_to_download_log
    run_download_stage prepare_source_archives
    run_download_stage prepare_client_data_archive
    run_download_stage prepare_runtime_images
}
```

- [ ] **步骤 4：运行全部测试与语法检查**

运行：

```bash
bash tests/run.sh
```

预期：输出 `test_download_reporting 通过` 和 `全部测试通过`，所有命令退出码为 0。

- [ ] **步骤 5：检查补丁范围和空白错误**

运行：

```bash
git diff --check
git status --short
```

预期：无空白错误；仅包含计划内文件。

- [ ] **步骤 6：提交阶段输出修复**

```bash
git add src/lib/02_prepare.sh tests/test_download_reporting.sh tests/run.sh .gitignore
git commit -m "fix: 将下载结果同步到主日志和控制台"
```
