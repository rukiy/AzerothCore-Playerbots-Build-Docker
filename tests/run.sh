#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/tests/test_download_reporting.sh"

while IFS= read -r shell_file; do
    bash -n "$shell_file"
done < <(find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -name '*.sh' -type f -print)

echo "全部测试通过"
