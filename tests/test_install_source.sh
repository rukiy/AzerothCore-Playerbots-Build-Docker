#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

entry_guard='if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then'
if ! grep -Fq "$entry_guard" "$ROOT_DIR/install.sh"; then
    fail "install.sh 缺少 source 入口保护"
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"
side_effect_log="$temp_dir/side-effects.log"
: > "$side_effect_log"

for command_name in id curl wget apt-get unzip awk sed mkdir find mv chmod rm date dirname; do
    cat > "$temp_dir/bin/$command_name" <<'EOF'
#!/bin/bash
printf '%s\n' "${0##*/} $*" >> "$SIDE_EFFECT_LOG"
exit 97
EOF
    chmod +x "$temp_dir/bin/$command_name"
done

bash_bin="$(command -v bash)"
set +e
output="$({
    SIDE_EFFECT_LOG="$side_effect_log" \
    PATH="$temp_dir/bin" \
    AC_INSTALL_DIR="$temp_dir/install" \
    AC_INSTALL_TMP_DIR="$temp_dir/tmp" \
    "$bash_bin" -c '
        source "$1"
        declare -F main >/dev/null || exit 98
        printf "MAIN_DEFINED\n"
    ' _ "$ROOT_DIR/install.sh"
} 2>&1)"
status=$?
set -e

assert_eq "0" "$status" "source install.sh 应成功返回"
assert_contains "$output" "MAIN_DEFINED" "source 后应定义 main 函数"
assert_eq "" "$(<"$side_effect_log")" "source install.sh 不应调用任何副作用命令"
echo "install.sh source 测试通过"
