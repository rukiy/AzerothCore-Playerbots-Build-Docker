#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_FILE_LIST="$(mktemp)"
trap 'rm -f "$SHELL_FILE_LIST"' EXIT

bash "$ROOT_DIR/tests/test_download_reporting.sh"

printf '%s\0' "$ROOT_DIR/ac.sh" "$ROOT_DIR/install.sh" > "$SHELL_FILE_LIST"
find "$ROOT_DIR/src" "$ROOT_DIR/tests" -type f -name '*.sh' -print0 >> "$SHELL_FILE_LIST"

while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file"
done < "$SHELL_FILE_LIST"

echo "全部测试通过"
