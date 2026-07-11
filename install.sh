#!/bin/bash
set -e

AC_INSTALL_DIR="${AC_INSTALL_DIR:-$HOME/acore}"
AC_INSTALL_BRANCH="${AC_INSTALL_BRANCH:-main}"
AC_INSTALL_REPO="${AC_INSTALL_REPO:-rukiy/AzerothCore-Playerbots-Build-Docker}"
AC_INSTALL_TMP_DIR="${AC_INSTALL_TMP_DIR:-}"
AC_INSTALL_TMP_DIR_CREATED=""
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
    printf '%s\n' curl wget unzip awk sed find free sha256sum realpath mktemp python3
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
        python3)
            printf '%s\n' python3
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

validate_install_dir() {
    local requested="$1"
    local normalized

    case "$requested" in
        /*) ;;
        *)
            echo "错误：安装目录必须是绝对路径: $requested" >&2
            return 1
            ;;
    esac

    if [ -L "$requested" ]; then
        echo "错误：安装目录已存在: $requested" >&2
        return 1
    fi

    normalized="$(realpath -m -- "$requested")" || return 1
    case "$normalized" in
        /|/root|/home|/usr|/var|/etc|/tmp)
            echo "错误：安装目录不安全: $normalized" >&2
            return 1
            ;;
    esac

    if [ -e "$normalized" ] || [ -L "$normalized" ]; then
        echo "错误：安装目录已存在: $normalized" >&2
        return 1
    fi

    printf '%s\n' "$normalized"
}

create_install_temp_dir() {
    local install_dir="$1"
    local parent_dir
    local created_dir

    parent_dir="$(dirname -- "$install_dir")"
    prepare_install_parent "$install_dir"
    created_dir="$(mktemp -d "$parent_dir/.acore-installer.XXXXXX")"
    AC_INSTALL_TMP_DIR="$created_dir"
    AC_INSTALL_TMP_DIR_CREATED="$created_dir"
}

validate_parent_directory() {
    local parent_dir="$1"
    local owner_id
    local mode
    local permissions

    [ -d "$parent_dir" ] && [ ! -L "$parent_dir" ] || {
        echo "错误：安装父目录不是普通目录: $parent_dir" >&2
        return 1
    }
    owner_id="$(stat -c %u -- "$parent_dir")" || return 1
    [ "$owner_id" = 0 ] || {
        echo "错误：安装父目录必须由 root 拥有: $parent_dir" >&2
        return 1
    }
    mode="$(stat -c %a -- "$parent_dir")" || return 1
    permissions=$((8#$mode))
    if (( (permissions & 0022) != 0 && (permissions & 01000) == 0 )); then
        echo "错误：可写安装父目录必须启用 sticky bit: $parent_dir" >&2
        return 1
    fi
}

validate_install_parent() {
    local install_dir="$1"
    local parent_dir

    parent_dir="$(dirname -- "$install_dir")"
    parent_dir="$(realpath -e -- "$parent_dir")" || {
        echo "错误：安装父目录不存在: $parent_dir" >&2
        return 1
    }
    validate_parent_directory "$parent_dir"
}

prepare_install_parent() {
    local install_dir="$1"
    local parent_dir
    local ancestor

    parent_dir="$(dirname -- "$install_dir")"
    ancestor="$parent_dir"
    while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
        ancestor="$(dirname -- "$ancestor")"
    done
    ancestor="$(realpath -e -- "$ancestor")" || return 1
    validate_parent_directory "$ancestor"
    (umask 077 && mkdir -p -- "$parent_dir") || return $?
    validate_install_parent "$install_dir"
}

cleanup_install_temp_dir() {
    local created_dir="${AC_INSTALL_TMP_DIR_CREATED:-}"
    local created_name

    AC_INSTALL_TMP_DIR=""
    AC_INSTALL_TMP_DIR_CREATED=""
    [ -n "$created_dir" ] || return 0
    [ "$created_dir" != "/" ] || return 0
    [ "$created_dir" != "$(dirname -- "$created_dir")" ] || return 0
    [ -d "$created_dir" ] || return 0

    created_name="$(basename -- "$created_dir")"
    [[ "$created_name" =~ ^\.acore-installer\.[[:alnum:]]{6}$ ]] || return 0
    rm -rf -- "$created_dir"
}

fetch_url() {
    local url="$1"
    local output_file="$2"
    local partial_file="${output_file}.part"
    local status

    rm -f -- "$partial_file"

    if command -v curl >/dev/null 2>&1; then
        if curl -L --fail --connect-timeout 10 --max-time 300 --retry 2 --retry-delay 2 -o "$partial_file" "$url"; then
            if mv -- "$partial_file" "$output_file"; then
                return 0
            fi
            status=$?
        else
            status=$?
        fi
        rm -f -- "$partial_file"
        return "$status"
    fi

    if wget -O "$partial_file" --timeout=10 --tries=3 "$url"; then
        if mv -- "$partial_file" "$output_file"; then
            return 0
        fi
        status=$?
    else
        status=$?
    fi
    rm -f -- "$partial_file"
    return "$status"
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
    local status=1
    local last_error=""
    local attempted=()

    while IFS= read -r url; do
        [ -n "$url" ] || continue
        attempted+=("$url")
        echo "下载: $url"
        if last_error="$(fetch_url "$url" "$output_file" 2>&1)"; then
            return 0
        else
            status=$?
        fi
        echo "下载失败，切换下一个地址"
    done < <(download_candidates)

    echo "错误：源码压缩包下载失败" >&2
    echo "已尝试地址：" >&2
    printf '  %s\n' "${attempted[@]}" >&2
    printf '最后状态：%s\n' "$status" >&2
    [ -z "$last_error" ] || printf '最后一次错误：\n%s\n' "$last_error" >&2
    rm -f -- "${output_file}.part"
    return "$status"
}

extract_and_validate_archive() {
    local archive_file="$1"
    local extract_dir="$2"

    python3 - "$archive_file" "$extract_dir" <<'PY'
import os
import re
import shutil
import stat
import sys
import zipfile

archive_file, extract_dir = sys.argv[1:]
max_entries = int(os.environ.get("AC_ZIP_MAX_ENTRIES", "10000"))
max_file_size = int(os.environ.get("AC_ZIP_MAX_FILE_SIZE", str(256 * 1024 * 1024)))
max_total_size = int(os.environ.get("AC_ZIP_MAX_TOTAL_SIZE", str(1024 * 1024 * 1024)))
max_ratio = int(os.environ.get("AC_ZIP_MAX_RATIO", "200"))

def reject(message):
    raise ValueError(message)

try:
    with zipfile.ZipFile(archive_file) as archive:
        entries = archive.infolist()
        if not entries:
            reject("ZIP 为空")
        if len(entries) > max_entries:
            reject("ZIP 条目数超限")

        normalized_entries = {}
        top_levels = set()
        total_size = 0
        for entry in entries:
            name = entry.filename
            if not name:
                reject("ZIP 包含空路径")
            if "\\" in name:
                reject("ZIP 路径包含反斜杠")
            if name.startswith("/") or name.startswith("//") or re.match(r"^[A-Za-z]:", name):
                reject("ZIP 路径为绝对路径")
            if any(ord(character) < 32 or ord(character) == 127 for character in name):
                reject("ZIP 路径包含控制字符")

            directory = name.endswith("/")
            path_name = name[:-1] if directory else name
            components = path_name.split("/")
            if not path_name or any(component in ("", ".", "..") for component in components):
                reject("ZIP 路径包含异常组件")
            normalized = "/".join(components)
            if normalized in normalized_entries:
                reject("ZIP 包含重复路径")
            normalized_entries[normalized] = (entry, directory)
            top_levels.add(components[0])

            if entry.flag_bits & 0x1:
                reject("ZIP 包含加密条目")
            mode = entry.external_attr >> 16
            file_type = stat.S_IFMT(mode)
            if file_type not in (0, stat.S_IFREG, stat.S_IFDIR):
                reject("ZIP 包含非普通文件")
            if directory and file_type not in (0, stat.S_IFDIR):
                reject("ZIP 目录类型异常")
            if not directory and file_type == stat.S_IFDIR:
                reject("ZIP 文件类型异常")
            if entry.file_size > max_file_size:
                reject("ZIP 单文件展开大小超限")
            total_size += entry.file_size
            if total_size > max_total_size:
                reject("ZIP 总展开大小超限")
            if entry.file_size and entry.file_size / max(entry.compress_size, 1) > max_ratio:
                reject("ZIP 压缩比超限")

        if len(top_levels) != 1:
            reject("ZIP 必须恰好包含一个顶层目录")
        top_level = next(iter(top_levels))
        top_entry = normalized_entries.get(top_level)
        if top_entry is not None and not top_entry[1]:
            reject("ZIP 顶层不是目录")
        for required in ("ac.sh", "ac.conf", "src/lib.sh"):
            required_path = f"{top_level}/{required}"
            item = normalized_entries.get(required_path)
            if item is None or item[1]:
                reject(f"ZIP 缺少普通文件: {required}")
            mode = item[0].external_attr >> 16
            if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                reject(f"ZIP 关键文件类型异常: {required}")

        os.mkdir(extract_dir, 0o700)
        try:
            for normalized, (entry, directory) in normalized_entries.items():
                destination = os.path.join(extract_dir, *normalized.split("/"))
                if directory:
                    os.makedirs(destination, mode=0o700, exist_ok=True)
                    continue
                os.makedirs(os.path.dirname(destination), mode=0o700, exist_ok=True)
                with archive.open(entry) as source, open(destination, "xb") as target:
                    shutil.copyfileobj(source, target)
                os.chmod(destination, 0o600)

            for root, directories, files in os.walk(extract_dir, followlinks=False):
                for name in directories + files:
                    mode = os.lstat(os.path.join(root, name)).st_mode
                    if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
                        reject("解压结果包含非普通文件")
        except Exception:
            shutil.rmtree(extract_dir, ignore_errors=True)
            raise
except (OSError, ValueError, zipfile.BadZipFile, RuntimeError) as error:
    print(f"错误：源码 ZIP 校验失败: {error}", file=sys.stderr)
    sys.exit(1)

print(os.path.join(extract_dir, top_level))
PY
}

claim_install_dir() {
    local install_dir="$1"

    validate_install_parent "$install_dir" || return $?
    if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
        echo "错误：安装目录已在校验后出现: $install_dir" >&2
        return 1
    fi
    if ! mkdir -m 0700 -- "$install_dir"; then
        echo "错误：无法原子声明安装目录: $install_dir" >&2
        return 1
    fi
}

install_validated_source() {
    local source_dir="$1"
    local install_dir="$2"
    local entry
    local destination

    [ -d "$install_dir" ] && [ ! -L "$install_dir" ] || return 1
    [ "$(stat -c %u -- "$install_dir")" = 0 ] || return 1
    while IFS= read -r -d '' entry; do
        destination="$install_dir/$(basename -- "$entry")"
        [ ! -e "$destination" ] && [ ! -L "$destination" ] || return 1
        mv -T -- "$entry" "$destination" || return $?
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -print0)
}

cleanup_on_exit() {
    local status=$?

    trap - EXIT
    cleanup_install_temp_dir || true
    exit "$status"
}

main() (
    local archive_file
    local extract_dir
    local install_dir
    local source_dir
    local install_status

    if [ "$(id -u)" != 0 ]; then
        echo "错误：必须以 root 权限运行" >&2
        return 1
    fi

    detect_platform || return $?
    install_bootstrap_dependencies || return $?
    check_bootstrap_commands || return $?
    check_docker_environment || return $?
    install_dir="$(validate_install_dir "$AC_INSTALL_DIR")" || return $?
    AC_INSTALL_DIR="$install_dir"
    create_install_temp_dir "$AC_INSTALL_DIR" || return $?
    trap cleanup_on_exit EXIT
    archive_file="$AC_INSTALL_TMP_DIR/source.zip"
    extract_dir="$AC_INSTALL_TMP_DIR/source"
    download_archive "$archive_file" || return $?
    source_dir="$(extract_and_validate_archive "$archive_file" "$extract_dir")" || return $?
    claim_install_dir "$AC_INSTALL_DIR" || return $?
    install_validated_source "$source_dir" "$AC_INSTALL_DIR" || return $?

    cd "$AC_INSTALL_DIR" || return $?
    chmod +x ./ac.sh || return $?
    if ./ac.sh install; then
        install_status=0
    else
        install_status=$?
    fi
    return "$install_status"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
