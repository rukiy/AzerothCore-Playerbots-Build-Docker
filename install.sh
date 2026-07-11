#!/bin/bash
set -e

AC_INSTALL_DIR="${AC_INSTALL_DIR:-$HOME/acore}"
AC_INSTALL_BRANCH="${AC_INSTALL_BRANCH:-main}"
AC_INSTALL_REPO="${AC_INSTALL_REPO:-rukiy/AzerothCore-Playerbots-Build-Docker}"
AC_INSTALL_TMP_DIR="${AC_INSTALL_TMP_DIR:-/tmp/acore-installer}"
AC_OS_RELEASE_FILE="${AC_OS_RELEASE_FILE:-/etc/os-release}"
AC_OS_ID="${AC_OS_ID:-}"
AC_OS_VERSION_ID="${AC_OS_VERSION_ID:-}"
AC_PACKAGE_MANAGER="${AC_PACKAGE_MANAGER:-}"

print_supported_platforms() {
    echo "支持列表：Ubuntu 22.04/24.04、Debian 12/13、Rocky Linux 9/10、AlmaLinux 9/10" >&2
}

detect_platform() {
    local line
    local value
    local id_found=false
    local version_found=false
    local major_version

    if [ ! -r "$AC_OS_RELEASE_FILE" ]; then
        echo "错误：无法读取系统信息文件: $AC_OS_RELEASE_FILE" >&2
        print_supported_platforms
        return 1
    fi

    AC_OS_ID=""
    AC_OS_VERSION_ID=""
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ID=*)
                [ "$id_found" = false ] || continue
                value="${line#ID=}"
                id_found=true
                ;;
            VERSION_ID=*)
                [ "$version_found" = false ] || continue
                value="${line#VERSION_ID=}"
                version_found=true
                ;;
            *)
                continue
                ;;
        esac

        value="${value%$'\r'}"
        case "$value" in
            \"*\"|\'*\')
                value="${value:1:${#value}-2}"
                ;;
        esac

        case "$line" in
            ID=*) AC_OS_ID="${value,,}" ;;
            VERSION_ID=*) AC_OS_VERSION_ID="$value" ;;
        esac
    done < "$AC_OS_RELEASE_FILE"
    major_version="${AC_OS_VERSION_ID%%.*}"

    case "$AC_OS_ID" in
        ubuntu)
            case "$AC_OS_VERSION_ID" in
                22.04|24.04) AC_PACKAGE_MANAGER="apt" ;;
                *) AC_PACKAGE_MANAGER="" ;;
            esac
            ;;
        debian)
            case "$AC_OS_VERSION_ID" in
                12|13) AC_PACKAGE_MANAGER="apt" ;;
                *) AC_PACKAGE_MANAGER="" ;;
            esac
            ;;
        rocky|almalinux)
            case "$major_version" in
                9|10) AC_PACKAGE_MANAGER="dnf" ;;
                *) AC_PACKAGE_MANAGER="" ;;
            esac
            ;;
        *)
            AC_PACKAGE_MANAGER=""
            ;;
    esac

    case "$AC_PACKAGE_MANAGER" in
        apt|dnf)
            return 0
            ;;
        *)
            echo "错误：检测到系统 $AC_OS_ID $AC_OS_VERSION_ID，当前不受支持" >&2
            print_supported_platforms
            return 1
            ;;
    esac
}

bootstrap_command_names() {
    printf '%s\n' curl wget unzip awk sed find free sha256sum realpath mktemp
}

ca_certificates_available() {
    local package_status

    case "$AC_PACKAGE_MANAGER" in
        apt)
            command -v dpkg-query >/dev/null 2>&1 || return 1
            package_status="$(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null)" || return 1
            [ "$package_status" = "install ok installed" ]
            ;;
        dnf)
            command -v rpm >/dev/null 2>&1 && rpm -q ca-certificates >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

bootstrap_commands_available() {
    local command_name

    while IFS= read -r command_name; do
        command -v "$command_name" >/dev/null 2>&1 || return 1
    done < <(bootstrap_command_names)

    ca_certificates_available
}

bootstrap_package_for_command() {
    local command_name="$1"

    case "$command_name" in
        curl|wget|unzip|sed)
            printf '%s\n' "$command_name"
            ;;
        awk)
            printf '%s\n' gawk
            ;;
        find)
            printf '%s\n' findutils
            ;;
        free)
            [ "$AC_PACKAGE_MANAGER" = apt ] && printf '%s\n' procps || printf '%s\n' procps-ng
            ;;
        sha256sum|realpath|mktemp)
            printf '%s\n' coreutils
            ;;
    esac
}

install_bootstrap_dependencies() {
    local packages=()
    local command_name
    local package_name
    local existing_package
    local found

    if ! ca_certificates_available; then
        packages+=(ca-certificates)
    fi

    while IFS= read -r command_name; do
        if command -v "$command_name" >/dev/null 2>&1; then
            continue
        fi

        package_name="$(bootstrap_package_for_command "$command_name")"
        found=false
        for existing_package in "${packages[@]}"; do
            if [ "$existing_package" = "$package_name" ]; then
                found=true
                break
            fi
        done
        [ "$found" = true ] || packages+=("$package_name")
    done < <(bootstrap_command_names)

    [ "${#packages[@]}" -gt 0 ] || return 0

    case "$AC_PACKAGE_MANAGER" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y --no-install-recommends "${packages[@]}"
            ;;
        dnf)
            dnf install -y "${packages[@]}"
            ;;
        *)
            echo "错误：未知包管理器: $AC_PACKAGE_MANAGER" >&2
            return 1
            ;;
    esac
}

check_bootstrap_commands() {
    local missing=()
    local command_name

    while IFS= read -r command_name; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done < <(bootstrap_command_names)

    ca_certificates_available || missing+=("ca-certificates")

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "错误：安装后仍缺少必要命令: ${missing[*]}" >&2
        return 1
    fi
}

print_docker_help() {
    local reason="$1"
    local diagnostic="${2:-}"

    printf '错误：%s\n' "$reason" >&2
    if [ "$#" -ge 2 ]; then
        printf '%s\n' "$diagnostic" >&2
    fi
    case "$AC_PACKAGE_MANAGER" in
        apt)
            echo "请按 Docker 官方 Ubuntu/Debian 安装文档配置 Docker Engine：" >&2
            echo "https://docs.docker.com/engine/install/ubuntu/" >&2
            echo "https://docs.docker.com/engine/install/debian/" >&2
            ;;
        dnf)
            echo "请按 Docker 官方 RHEL 安装文档配置 Docker Engine：" >&2
            echo "https://docs.docker.com/engine/install/rhel/" >&2
            ;;
    esac
    echo "完成后请确认以下命令均可正常执行：" >&2
    echo "  docker info" >&2
    echo "  docker compose version" >&2
    echo "  docker buildx version" >&2
}

check_docker_environment() {
    local info_output
    local compose_output
    local buildx_output
    local reason

    if ! command -v docker >/dev/null 2>&1; then
        print_docker_help "未找到 docker 命令"
        return 1
    fi

    if ! info_output="$(docker info 2>&1)"; then
        case "${info_output,,}" in
            *permission\ denied*|*access\ denied*)
                reason="无权访问 Docker daemon"
                ;;
            *cannot\ connect*|*is\ the\ docker\ daemon\ running\?*|*connection\ refused*|*error\ during\ connect*|*failed\ to\ connect*)
                reason="Docker daemon 未运行或 context 不可达"
                ;;
            *)
                reason="Docker daemon 访问失败"
                ;;
        esac
        print_docker_help "$reason" "$info_output"
        return 1
    fi

    if ! compose_output="$(docker compose version 2>&1)"; then
        print_docker_help "Docker Compose 不可用" "$compose_output"
        return 1
    fi

    if ! buildx_output="$(docker buildx version 2>&1)"; then
        print_docker_help "Docker Buildx 不可用" "$buildx_output"
        return 1
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

    detect_platform
    if ! bootstrap_commands_available; then
        install_bootstrap_dependencies
    fi
    check_bootstrap_commands
    check_docker_environment
    mkdir -p "$AC_INSTALL_TMP_DIR"
    download_archive "$archive_file"
    extract_archive "$archive_file" "$extract_dir"

    cd "$AC_INSTALL_DIR"
    chmod +x ./ac.sh
    ./ac.sh install
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
