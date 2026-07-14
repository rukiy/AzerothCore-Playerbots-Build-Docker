#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

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

run_logged_case() (
    local case_name="$1"
    local main_log="$2"
    local download_log_file="$3"
    local stage_status

    DOWNLOAD_LOG_DIR="$(dirname "$download_log_file")"
    DOWNLOAD_LOG_FILE="$download_log_file"
    mkdir -p "$DOWNLOAD_LOG_DIR" "$(dirname "$main_log")"
    : > "$DOWNLOAD_LOG_FILE"
    : > "$main_log"

    success_stage() {
        echo "成功过程标准输出"
        echo "成功过程标准错误" >&2
        download_success \
            "AzerothCore 源码" \
            "https://success.example/source.zip" \
            "/cache/source.zip"
    }

    failure_stage() {
        echo "失败过程标准输出"
        echo "失败过程标准错误" >&2
        download_failure \
            "/cache/failed.zip" \
            "https://last.example/source.zip" \
            "curl: (22) last source returned 503"
        return 1
    }

    exec 7>&1 8>&2
    exec > >(tee -a "$main_log") 2>&1

    set +e
    run_download_stage "${case_name}_stage"
    stage_status=$?
    set -e

    exec 1>&7 2>&8
    exec 7>&- 8>&-
    wait
    return "$stage_status"
)

success_console="$TEST_TMP_DIR/success.console.log"
success_main_log="$TEST_TMP_DIR/success.ac.log"
success_download_log="$TEST_TMP_DIR/success.downloads.log"
run_logged_case success "$success_main_log" "$success_download_log" \
    > "$success_console" 2>&1

success_result="[OK] 下载: AzerothCore 源码 完成: https://success.example/source.zip -> /cache/source.zip"
success_console_text="$(<"$success_console")"
success_main_text="$(<"$success_main_log")"
success_download_text="$(<"$success_download_log")"

assert_contains "$success_console_text" "$success_result"
assert_contains "$success_main_text" "$success_result"
assert_not_contains "$success_console_text" "成功过程标准输出"
assert_not_contains "$success_console_text" "成功过程标准错误"
assert_not_contains "$success_main_text" "成功过程标准输出"
assert_not_contains "$success_main_text" "成功过程标准错误"
assert_contains "$success_download_text" "成功过程标准错误"

failure_console="$TEST_TMP_DIR/failure.console.log"
failure_main_log="$TEST_TMP_DIR/failure.ac.log"
failure_download_log="$TEST_TMP_DIR/failure.downloads.log"
if run_logged_case failure "$failure_main_log" "$failure_download_log" \
    > "$failure_console" 2>&1; then
    fail "下载阶段失败状态未透传"
fi

failure_console_text="$(<"$failure_console")"
failure_main_text="$(<"$failure_main_log")"
failure_download_text="$(<"$failure_download_log")"

for result_text in "$failure_console_text" "$failure_main_text"; do
    assert_contains "$result_text" "[ERROR] 下载失败: /cache/failed.zip"
    assert_contains "$result_text" "最后下载源: https://last.example/source.zip"
    assert_contains "$result_text" "curl: (22) last source returned 503"
    assert_not_contains "$result_text" "失败过程标准输出"
    assert_not_contains "$result_text" "失败过程标准错误"
done
assert_contains "$failure_download_text" "失败过程标准错误"

echo "test_download_logging_integration 通过"
