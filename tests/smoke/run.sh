#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
IMAGES=(
    ubuntu:22.04
    ubuntu:24.04
    debian:12
    debian:13
    rockylinux:9
    # Rocky Linux 10 使用官方 rockylinux/rockylinux 仓库。
    rockylinux/rockylinux:10
    almalinux:9
    almalinux:10
)

failed=0

echo "运行安装依赖冒烟验证"
for image in "${IMAGES[@]}"; do
    if docker run --rm \
        --mount "type=bind,source=${ROOT_DIR},target=/workspace,readonly" \
        "$image" \
        bash -c '
            set -euo pipefail
            source /workspace/install.sh
            detect_platform
            install_bootstrap_dependencies
            check_bootstrap_commands

            for command_name in curl wget unzip awk sed find free sha256sum realpath mktemp python3; do
                command -v "$command_name" >/dev/null
            done
            ca_certificates_available
        '; then
        echo "[通过] $image"
    else
        failed=1
        echo "[失败] $image" >&2
    fi
done

if [ "$failed" -ne 0 ]; then
    echo "容器冒烟验证失败" >&2
    exit 1
fi

echo "8 个容器镜像冒烟验证全部通过"
