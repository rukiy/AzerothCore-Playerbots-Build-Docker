#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for test_file in "$ROOT_DIR"/tests/test_install_*.sh; do
    [ -f "$test_file" ] || continue
    bash "$test_file"
done

for script in \
    "$ROOT_DIR/ac.sh" \
    "$ROOT_DIR/install.sh" \
    "$ROOT_DIR/src/lib.sh" \
    "$ROOT_DIR"/src/lib/*.sh \
    "$ROOT_DIR"/src/lib/extra/*.sh; do
    [ -f "$script" ] || continue
    bash -n "$script"
done

echo "快速测试全部通过"
