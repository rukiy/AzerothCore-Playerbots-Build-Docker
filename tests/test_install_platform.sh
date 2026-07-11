#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
load_installer

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

write_os_release() {
    local os_id="$1"
    local version_id="$2"

    cat > "$temp_dir/os-release" <<EOF
NAME="测试系统"
ID="$os_id"
VERSION_ID="$version_id"
EOF
    AC_OS_RELEASE_FILE="$temp_dir/os-release"
}

assert_platform() {
    local os_id="$1"
    local version_id="$2"
    local expected_manager="$3"

    write_os_release "$os_id" "$version_id"
    detect_platform
    assert_eq "$os_id" "$AC_OS_ID" "$os_id $version_id 应识别发行版"
    assert_eq "$version_id" "$AC_OS_VERSION_ID" "$os_id $version_id 应识别版本"
    assert_eq "$expected_manager" "$AC_PACKAGE_MANAGER" "$os_id $version_id 应选择包管理器"
}

assert_unsupported_platform() {
    local os_id="$1"
    local version_id="$2"
    local output
    local status

    write_os_release "$os_id" "$version_id"
    set +e
    output="$(detect_platform 2>&1)"
    status=$?
    set -e

    [ "$status" -ne 0 ] || fail "$os_id $version_id 应拒绝运行"
    assert_contains "$output" "检测到系统" "$os_id $version_id 应输出检测信息"
    assert_contains "$output" "$os_id" "$os_id $version_id 检测信息应包含发行版"
    assert_contains "$output" "$version_id" "$os_id $version_id 检测信息应包含版本"
    assert_contains "$output" "支持列表" "$os_id $version_id 应输出支持列表"
}

for version_id in 22.04 24.04; do
    assert_platform ubuntu "$version_id" apt
done
for version_id in 12 13; do
    assert_platform debian "$version_id" apt
done
for os_id in rocky almalinux; do
    for version_id in 9 10; do
        assert_platform "$os_id" "$version_id" dnf
    done
    assert_platform "$os_id" 9.6 dnf
done

assert_unsupported_platform ubuntu 20.04
assert_unsupported_platform debian 11
assert_unsupported_platform rocky 8
assert_unsupported_platform almalinux 8
assert_unsupported_platform fedora 42

AC_OS_RELEASE_FILE="$temp_dir/not-found"
set +e
missing_output="$(detect_platform 2>&1)"
missing_status=$?
set -e
[ "$missing_status" -ne 0 ] || fail "缺少 os-release 时应拒绝运行"
assert_contains "$missing_output" "无法读取系统信息" "缺少 os-release 时应输出检测失败信息"
assert_contains "$missing_output" "支持列表" "缺少 os-release 时应输出支持列表"

command_substitution_sentinel="$temp_dir/command-substitution-created"
backtick_sentinel="$temp_dir/backtick-created"
standalone_sentinel="$temp_dir/standalone-created"
cat > "$temp_dir/malicious-os-release" <<EOF
ID='ubuntu'
VERSION_ID="22.04"
NAME=\$(touch "$command_substitution_sentinel")
PRETTY_NAME=\`touch "$backtick_sentinel"\`
touch "$standalone_sentinel"
ID=debian
VERSION_ID=13
EOF
AC_OS_RELEASE_FILE="$temp_dir/malicious-os-release"
detect_platform
[ ! -e "$command_substitution_sentinel" ] || fail "不得执行 os-release 中的命令替换"
[ ! -e "$backtick_sentinel" ] || fail "不得执行 os-release 中的反引号命令"
[ ! -e "$standalone_sentinel" ] || fail "不得执行 os-release 中的独立命令"
assert_eq "ubuntu" "$AC_OS_ID" "恶意 os-release 中的首个合法 ID 应被识别"
assert_eq "22.04" "$AC_OS_VERSION_ID" "恶意 os-release 中的首个合法 VERSION_ID 应被识别"
assert_eq "apt" "$AC_PACKAGE_MANAGER" "合法平台字段应正常选择包管理器"

create_command_stub() {
    local bin_dir="$1"
    local command_name="$2"
    cat > "$bin_dir/$command_name" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$bin_dir/$command_name"
}

package_log="$temp_dir/package.log"
: > "$package_log"

create_package_manager_stub() {
    local bin_dir="$1"
    local manager="$2"
    cat > "$bin_dir/$manager" <<EOF
#!/bin/bash
printf '$manager %s\\n' "\$*" >> "\$PACKAGE_LOG"
EOF
    chmod +x "$bin_dir/$manager"
}

create_certificate_stub() {
    local bin_dir="$1"
    local checker="$2"
    local installed="$3"
    local status=1
    [ "$installed" = true ] && status=0
    if [ "$checker" = dpkg-query ]; then
        cat > "$bin_dir/$checker" <<EOF
#!/bin/bash
printf '%s' 'install ok installed'
exit $status
EOF
    else
        cat > "$bin_dir/$checker" <<EOF
#!/bin/bash
exit $status
EOF
    fi
    chmod +x "$bin_dir/$checker"
}

create_dependency_scenario() {
    local scenario="$1"
    local manager="$2"
    local certificate_installed="$3"
    shift 3
    local bin_dir="$temp_dir/$scenario/bin"
    local command_name

    mkdir -p "$bin_dir"
    create_package_manager_stub "$bin_dir" "$manager"
    if [ "$manager" = apt-get ]; then
        create_certificate_stub "$bin_dir" dpkg-query "$certificate_installed"
    else
        create_certificate_stub "$bin_dir" rpm "$certificate_installed"
    fi
    for command_name in "$@"; do
        create_command_stub "$bin_dir" "$command_name"
    done
    printf '%s\n' "$bin_dir"
}

all_commands=(curl wget unzip awk sed find free sha256sum realpath mktemp python3)
ready_bin="$(create_dependency_scenario ready apt-get true "${all_commands[@]}")"
PATH="$ready_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=apt \
    bootstrap_commands_available || fail "命令和证书齐全时应通过检查"
assert_eq "" "$(<"$package_log")" "命令和证书齐全时不应调用包管理器"

missing_cert_bin="$(create_dependency_scenario missing-cert apt-get false "${all_commands[@]}")"
if PATH="$missing_cert_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=apt bootstrap_commands_available; then
    fail "ca-certificates 缺失时不应通过基础依赖检查"
fi
PATH="$missing_cert_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=apt install_bootstrap_dependencies
assert_eq $'apt-get update\napt-get install -y --no-install-recommends ca-certificates' "$(<"$package_log")" "仅缺少证书包时 apt 应按需安装"

: > "$package_log"
apt_empty_bin="$(create_dependency_scenario apt-empty apt-get false)"
PATH="$apt_empty_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=apt install_bootstrap_dependencies
assert_eq $'apt-get update\napt-get install -y --no-install-recommends ca-certificates curl wget unzip gawk sed findutils procps coreutils python3' "$(<"$package_log")" "全部命令缺失时 apt 应安装完整基础依赖"

: > "$package_log"
dnf_empty_bin="$(create_dependency_scenario dnf-empty dnf false)"
PATH="$dnf_empty_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=dnf install_bootstrap_dependencies
assert_eq "dnf install -y ca-certificates curl wget unzip gawk sed findutils procps-ng coreutils python3" "$(<"$package_log")" "全部命令缺失时 dnf 应安装完整基础依赖"

: > "$package_log"
dnf_partial_bin="$(create_dependency_scenario dnf-partial dnf true curl wget unzip awk sed find free sha256sum mktemp python3)"
PATH="$dnf_partial_bin" PACKAGE_LOG="$package_log" AC_PACKAGE_MANAGER=dnf install_bootstrap_dependencies
assert_eq "dnf install -y coreutils" "$(<"$package_log")" "dnf 应仅安装缺失命令对应的软件包"

set +e
check_output="$(PATH="$dnf_partial_bin" AC_PACKAGE_MANAGER=dnf check_bootstrap_commands 2>&1)"
check_status=$?
set -e
[ "$check_status" -ne 0 ] || fail "安装后仍缺少命令时应返回非零"
assert_contains "$check_output" "安装后仍缺少必要命令" "应说明依赖安装后检查失败"
assert_contains "$check_output" "realpath" "应列出缺失命令"

set +e
certificate_output="$(PATH="$missing_cert_bin" AC_PACKAGE_MANAGER=apt check_bootstrap_commands 2>&1)"
certificate_status=$?
set -e
[ "$certificate_status" -ne 0 ] || fail "安装后证书包仍缺失时应返回非零"
assert_contains "$certificate_output" "ca-certificates" "应列出缺失的证书包"

echo "安装平台与基础依赖测试通过"
