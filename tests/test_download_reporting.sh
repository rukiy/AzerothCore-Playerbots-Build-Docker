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

successful_download_stage() {
    echo "过程标准输出"
    echo "过程标准错误" >&2
    download_success "AzerothCore 源码" "https://example/source.zip" "/cache/source.zip"
}

output="$(run_download_stage successful_download_stage 2>&1)"
assert_contains "$output" "[OK] 下载: AzerothCore 源码 完成: https://example/source.zip -> /cache/source.zip"
assert_not_contains "$output" "过程标准输出"
assert_not_contains "$output" "过程标准错误"

failed_download_stage() {
    echo "过程标准输出"
    echo "过程标准错误" >&2
    download_failure "/cache/source.zip" "https://last.example/source.zip" "curl: (22) final error"
    return 1
}

if output="$(run_download_stage failed_download_stage 2>&1)"; then
    fail "下载阶段失败时包装器仍返回成功"
fi
assert_contains "$output" "[ERROR] 下载失败: /cache/source.zip"
assert_contains "$output" "最后下载源: https://last.example/source.zip"
assert_contains "$output" "curl: (22) final error"
assert_not_contains "$output" "过程标准输出"
assert_not_contains "$output" "过程标准错误"

echo "test_download_reporting 通过"
