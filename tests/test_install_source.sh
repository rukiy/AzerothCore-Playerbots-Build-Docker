#!/bin/bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"
cat > "$temp_dir/bin/curl" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$temp_dir/bin/curl"

set +e
output="$({
    PATH="$temp_dir/bin:/usr/bin:/bin" \
    AC_INSTALL_TMP_DIR="$temp_dir/tmp" \
    AC_INSTALL_DIR="$temp_dir/install" \
    bash -c 'source "$1"; printf "SOURCE_OK\\n"' _ "$ROOT_DIR/install.sh"
} 2>&1)"
status=$?
set -e

assert_eq "0" "$status"
assert_contains "$output" "SOURCE_OK"
echo "install.sh source 测试通过"
