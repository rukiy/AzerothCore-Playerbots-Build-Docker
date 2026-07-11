#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
load_installer

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

assert_validation_fails() {
    local requested="$1"
    local expected_message="$2"
    local output

    if output="$(validate_install_dir "$requested" 2>&1)"; then
        fail "安装目录应被拒绝: $requested"
    fi
    assert_contains "$output" "$expected_message" "拒绝安装目录时应说明原因"
}

assert_validation_fails "relative/acore" "必须是绝对路径"

for dangerous_dir in \
    / /root /root/ /root/.. /tmp /tmp/ /etc /var /usr /home; do
    assert_validation_fails "$dangerous_dir" "安装目录不安全"
done

existing_file="$temp_dir/existing-file"
existing_dir="$temp_dir/existing-dir"
valid_link="$temp_dir/valid-link"
broken_link="$temp_dir/broken-link"
printf 'test\n' > "$existing_file"
mkdir -p "$existing_dir"
ln -s "$existing_dir" "$valid_link"
ln -s "$temp_dir/missing-target" "$broken_link"

for existing_path in "$existing_file" "$existing_dir" "$valid_link" "$broken_link"; do
    assert_validation_fails "$existing_path" "安装目录已存在"
done

for allowed_dir in /root/acore /opt/acore /srv/acore /data/acore; do
    if [ ! -e "$allowed_dir" ] && [ ! -L "$allowed_dir" ]; then
        assert_eq "$allowed_dir" "$(validate_install_dir "$allowed_dir")" "安全安装目录应原样通过"
    fi
done

normalized_dir="$temp_dir/parent/../normalized/acore"
expected_normalized="$(realpath -m -- "$normalized_dir")"
assert_eq "$expected_normalized" "$(validate_install_dir "$normalized_dir")" "应输出规范化绝对路径"

space_install_dir="$temp_dir/含 空格/项目/acore"
space_normalized="$(validate_install_dir "$space_install_dir")"
assert_eq "$(realpath -m -- "$space_install_dir")" "$space_normalized" "含空格路径应正确规范化"

dash_install_dir="$temp_dir/--选项/项目/acore"
dash_normalized="$(validate_install_dir "$dash_install_dir")"
assert_eq "$(realpath -m -- "$dash_install_dir")" "$dash_normalized" "含 -- 开头组件的路径应正确规范化"

external_dir="$temp_dir/external-fixed-dir"
mkdir -p "$external_dir"
AC_INSTALL_TMP_DIR="$external_dir"
cleanup_install_temp_dir
[ -d "$external_dir" ] || fail "外部指定的临时目录不得被清理"

nonmatching_dir="$temp_dir/not-an-installer-dir"
mkdir -p "$nonmatching_dir"
AC_INSTALL_TMP_DIR="$nonmatching_dir"
cleanup_install_temp_dir
[ -d "$nonmatching_dir" ] || fail "名称不匹配的目录不得被清理"

lookalike_dir="$temp_dir/.acore-installer.1234567"
mkdir -p "$lookalike_dir"
AC_INSTALL_TMP_DIR="$lookalike_dir"
AC_INSTALL_TMP_DIR_CREATED="$lookalike_dir"
cleanup_install_temp_dir
[ -d "$lookalike_dir" ] || fail "非六字符后缀的相似目录不得被清理"

missing_parent_install_dir="$temp_dir/父目录 不存在/--项目/acore"
create_install_temp_dir "$missing_parent_install_dir"
created_temp_dir="$AC_INSTALL_TMP_DIR"
expected_parent="$(dirname "$(realpath -m -- "$missing_parent_install_dir")")"
assert_eq "$expected_parent" "$(dirname "$created_temp_dir")" "临时目录应位于安装目标父目录"
[[ "$(basename "$created_temp_dir")" =~ ^\.acore-installer\.[[:alnum:]]{6}$ ]] || fail "临时目录名称应使用六字符专属模板"
[ -d "$created_temp_dir" ] || fail "应创建安装临时目录"

cleanup_install_temp_dir
[ ! -e "$created_temp_dir" ] || fail "应删除本次创建的安装临时目录"
cleanup_install_temp_dir

echo "安装路径与临时目录测试通过"
