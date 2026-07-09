#!/bin/bash
set -e

AC_INSTALL_DIR="${AC_INSTALL_DIR:-$HOME/acore}"
AC_INSTALL_BRANCH="${AC_INSTALL_BRANCH:-main}"
AC_INSTALL_REPO="${AC_INSTALL_REPO:-rukiy/AzerothCore-Playerbots-Build-Docker}"
AC_INSTALL_TMP_DIR="${AC_INSTALL_TMP_DIR:-/tmp/acore-installer}"

install_bootstrap_dependencies() {
    if ! command -v apt-get >/dev/null 2>&1; then
        return 1
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl wget unzip
}

need_command() {
    local missing=()
    local command_name

    if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
        install_bootstrap_dependencies || true
    fi

    for command_name in unzip awk sed; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing+=("curl或wget")
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "错误：缺少必要命令: ${missing[*]}" >&2
        echo "请先安装依赖，例如: apt-get update && apt-get install -y curl wget unzip" >&2
        exit 1
    fi
}

fetch_url() {
    local url="$1"
    local output_file="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --connect-timeout 10 --max-time 300 --retry 2 --retry-delay 2 -o "$output_file" "$url"
        return $?
    fi

    wget -O "$output_file" --timeout=10 --tries=3 "$url"
}

download_candidates() {
    local origin_url="https://github.com/${AC_INSTALL_REPO}/archive/refs/heads/${AC_INSTALL_BRANCH}.zip"
    local mirrors=(
        "https://gh-proxy.com/"
        "https://gh.llkk.cc/"
        "https://gh.idayer.com/"
        "https://ghproxy.net/"
    )
    local mirror

    printf '%s\n' "$origin_url"
    for mirror in "${mirrors[@]}"; do
        printf '%s%s\n' "$mirror" "$origin_url"
    done
}

download_archive() {
    local output_file="$1"
    local url

    while IFS= read -r url; do
        [ -n "$url" ] || continue
        echo "下载: $url"
        if fetch_url "$url" "$output_file"; then
            return 0
        fi
        echo "下载失败，切换下一个地址"
    done < <(download_candidates)

    echo "错误：源码压缩包下载失败" >&2
    return 1
}

extract_archive() {
    local archive_file="$1"
    local extract_dir="$2"
    local source_dir
    local backup_dir

    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    unzip -q "$archive_file" -d "$extract_dir"

    source_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    if [ -z "$source_dir" ]; then
        echo "错误：源码压缩包内容不正确" >&2
        return 1
    fi

    mkdir -p "$(dirname "$AC_INSTALL_DIR")"
    case "$AC_INSTALL_DIR" in
        ""|"/"|"/root"|"/home"|"/usr"|"/var"|"/etc"|"/tmp")
            echo "错误：安装目录不安全: $AC_INSTALL_DIR" >&2
            return 1
            ;;
    esac

    if [ -e "$AC_INSTALL_DIR" ]; then
        backup_dir="${AC_INSTALL_DIR}.backup.$(date '+%Y%m%d%H%M%S')"
        echo "备份已有目录: $AC_INSTALL_DIR -> $backup_dir"
        mv "$AC_INSTALL_DIR" "$backup_dir"
    fi

    mv "$source_dir" "$AC_INSTALL_DIR"
}

main() {
    local archive_file="$AC_INSTALL_TMP_DIR/source.zip"
    local extract_dir="$AC_INSTALL_TMP_DIR/source"

    if [ "$(id -u)" != 0 ]; then
        echo "错误：必须以 root 权限运行" >&2
        exit 1
    fi

    need_command
    mkdir -p "$AC_INSTALL_TMP_DIR"
    download_archive "$archive_file"
    extract_archive "$archive_file" "$extract_dir"

    cd "$AC_INSTALL_DIR"
    chmod +x ./ac.sh
    ./ac.sh install
}

main "$@"
