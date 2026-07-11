#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
load_installer

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

create_docker_stub() {
    local bin_dir="$1"
    local info_status="$2"
    local compose_status="$3"
    local buildx_status="$4"
    local info_error="${5:-}"

    mkdir -p "$bin_dir"
    cat > "$bin_dir/docker" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "\$DOCKER_CALL_LOG"
case "\$*" in
    info)
        [ -z '$info_error' ] || printf '%s\n' '$info_error' >&2
        exit $info_status
        ;;
    "compose version") exit $compose_status ;;
    "buildx version") exit $buildx_status ;;
    *) exit 99 ;;
esac
EOF
    chmod +x "$bin_dir/docker"
}

assert_check_fails() {
    local bin_dir="$1"
    local manager="$2"
    local expected_message="$3"
    local expected_calls="$4"
    local output
    local status

    : > "$docker_call_log"
    set +e
    output="$(
        export PATH="$bin_dir"
        export DOCKER_CALL_LOG="$docker_call_log"
        export AC_PACKAGE_MANAGER="$manager"
        hash -r
        check_docker_environment 2>&1
    )"
    status=$?
    set -e

    [ "$status" -ne 0 ] || fail "$expected_message 时应返回非零"
    assert_contains "$output" "$expected_message" "失败信息应指出具体 Docker 能力"
    assert_contains "$output" "docker info" "帮助应列出 daemon 检查命令"
    assert_contains "$output" "docker compose version" "帮助应列出 Compose 检查命令"
    assert_contains "$output" "docker buildx version" "帮助应列出 Buildx 检查命令"
    assert_eq "$expected_calls" "$(<"$docker_call_log")" "Docker 检查应按固定顺序执行并立即失败"
}

docker_call_log="$temp_dir/docker-calls.log"
: > "$docker_call_log"

no_docker_bin="$temp_dir/no-docker/bin"
mkdir -p "$no_docker_bin"
assert_check_fails "$no_docker_bin" apt "未找到 docker 命令" ""

permission_failure_bin="$temp_dir/permission-failure/bin"
create_docker_stub "$permission_failure_bin" 1 0 0 "permission denied while trying to connect to the Docker daemon socket"
assert_check_fails "$permission_failure_bin" apt "无权访问 Docker daemon" "info"

daemon_failure_bin="$temp_dir/daemon-failure/bin"
create_docker_stub "$daemon_failure_bin" 1 0 0 "Cannot connect to the Docker daemon. Is the docker daemon running?"
assert_check_fails "$daemon_failure_bin" apt "Docker daemon 未运行或 context 不可达" "info"

unknown_info_failure_bin="$temp_dir/unknown-info-failure/bin"
create_docker_stub "$unknown_info_failure_bin" 1 0 0 "测试中的未知 Docker 错误"
assert_check_fails "$unknown_info_failure_bin" apt "测试中的未知 Docker 错误" "info"

compose_failure_bin="$temp_dir/compose-failure/bin"
create_docker_stub "$compose_failure_bin" 0 1 0
assert_check_fails "$compose_failure_bin" apt "Docker Compose 不可用" $'info\ncompose version'

buildx_failure_bin="$temp_dir/buildx-failure/bin"
create_docker_stub "$buildx_failure_bin" 0 0 1
assert_check_fails "$buildx_failure_bin" dnf "Docker Buildx 不可用" $'info\ncompose version\nbuildx version'

success_bin="$temp_dir/success/bin"
create_docker_stub "$success_bin" 0 0 0
: > "$docker_call_log"
if ! (
    export PATH="$success_bin"
    export DOCKER_CALL_LOG="$docker_call_log"
    export AC_PACKAGE_MANAGER=apt
    hash -r
    check_docker_environment
); then
    fail "Docker 四项能力齐全时应通过预检"
fi
assert_eq $'info\ncompose version\nbuildx version' "$(<"$docker_call_log")" "成功场景应按固定顺序检查全部能力"

apt_help="$(AC_PACKAGE_MANAGER=apt print_docker_help "测试原因" 2>&1)"
assert_contains "$apt_help" "Ubuntu/Debian" "apt 平台应指向 Ubuntu/Debian 官方安装文档"
assert_contains "$apt_help" "docs.docker.com" "apt 平台应给出 Docker 官方文档"
assert_contains "$apt_help" "/ubuntu/" "apt 平台应给出 Ubuntu 官方安装页面"
assert_contains "$apt_help" "/debian/" "apt 平台应给出 Debian 官方安装页面"

dnf_help="$(AC_PACKAGE_MANAGER=dnf print_docker_help "测试原因" 2>&1)"
assert_contains "$dnf_help" "RHEL" "dnf 平台应指向 RHEL 官方安装文档"
assert_contains "$dnf_help" "docs.docker.com" "dnf 平台应给出 Docker 官方文档"

main_call_log="$temp_dir/main-calls.log"
export MAIN_CALL_LOG="$main_call_log"
AC_INSTALL_TMP_DIR="$temp_dir/main-tmp"
AC_INSTALL_DIR="$temp_dir/main-install"
id() { printf '%s\n' 0; }
detect_platform() { printf '%s\n' detect >> "$main_call_log"; }
bootstrap_commands_available() { return 0; }
check_bootstrap_commands() { printf '%s\n' bootstrap-check >> "$main_call_log"; }
check_docker_environment() { printf '%s\n' docker-check >> "$main_call_log"; }
download_archive() { printf '%s\n' download >> "$main_call_log"; }
extract_archive() {
    printf '%s\n' extract >> "$main_call_log"
    mkdir -p "$AC_INSTALL_DIR"
    cat > "$AC_INSTALL_DIR/ac.sh" <<'EOF'
#!/bin/bash
printf '%s\n' install >> "$MAIN_CALL_LOG"
EOF
}

main
assert_eq $'detect\nbootstrap-check\ndocker-check\ndownload\nextract\ninstall' "$(<"$main_call_log")" "main 应在基础依赖复检后、下载前执行 Docker 预检"

echo "Docker 环境预检测试通过"
