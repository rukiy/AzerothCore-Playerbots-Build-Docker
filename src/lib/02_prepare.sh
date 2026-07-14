#!/bin/bash

check_required_commands() {
    local command_name
    local missing=()

    for command_name in docker curl unzip awk sed free sha256sum find du; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "错误：缺少必要命令: ${missing[*]}" >&2
        return 1
    fi
}

check_docker_service() {
    if ! docker info >/dev/null 2>&1; then
        echo "错误：Docker 服务不可用，请先启动 Docker" >&2
        return 1
    fi
}

check_environment() {
    check_required_commands
    check_docker_service
}

ensure_download_cache_dir() {
    mkdir -p "$DOWNLOAD_SOURCE_DIR" "$DOWNLOAD_DOCKER_IMAGE_DIR" "$DOWNLOAD_CLIENT_DIR" "$DOWNLOAD_LOG_DIR" "$(mirror_log_dir_path)"
    mkdir -p "$(dirname "$DOWNLOAD_MIRROR_STATE_FILE")"
}

init_download_log() {
    mkdir -p "$DOWNLOAD_LOG_DIR"
    rm -f "$DOWNLOAD_LOG_FILE"
    {
        echo "下载日志: $DOWNLOAD_LOG_FILE"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    } > "$DOWNLOAD_LOG_FILE"
}

download_log() {
    local message="$*"
    mkdir -p "$DOWNLOAD_LOG_DIR"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$DOWNLOAD_LOG_FILE"
}

mirror_log_file_path() {
    printf '%s\n' "${MIRROR_LOG_FILE:-${DOWNLOAD_LOG_DIR:-.}/mirrors.log}"
}

mirror_log_dir_path() {
    dirname "$(mirror_log_file_path)"
}

init_mirror_log() {
    local log_file

    log_file="$(mirror_log_file_path)"
    mkdir -p "$(dirname "$log_file")"
    rm -f "$log_file"
    {
        echo "镜像检测日志: $log_file"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    } > "$log_file"
}

mirror_log() {
    local message="$*"
    local log_file

    log_file="$(mirror_log_file_path)"
    mkdir -p "$(dirname "$log_file")"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$message" >> "$log_file"
}

mirror_log_output() {
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        mirror_log "$line"
    done
}

download_log_output() {
    local line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        download_log "$line"
    done
}

run_download_stage() {
    "$@" 3>&1 4>&2 >/dev/null 2> >(download_log_output)
}

download_success() {
    local item_name="$1"
    local source="$2"
    local target="$3"

    printf '[OK] 下载: %s 完成: %s -> %s\n' "$item_name" "$source" "$target" >&3
}

download_failure() {
    local target="$1"
    local last_source="$2"
    local detail="$3"

    download_log "[ERROR] 下载失败: $target"
    {
        printf '[ERROR] 下载失败: %s\n' "$target"
        printf '最后下载源: %s\n' "$last_source"
        printf '具体错误:\n'
        printf '%s\n' "$detail"
    } >&4
}

mirror_in_candidates() {
    local preferred="$1"
    shift

    local mirror
    [ -n "$preferred" ] || return 1
    preferred="${preferred%/}"
    for mirror in "$@"; do
        [ "${mirror%/}" = "$preferred" ] && return 0
    done
    return 1
}

is_client_data_version() {
    [[ "$1" =~ ^v[0-9]+$ ]]
}

ordered_mirrors() {
    local preferred="$1"
    shift

    local mirror
    if mirror_in_candidates "$preferred" "$@"; then
        printf '%s\n' "$preferred"
    fi

    for mirror in "$@"; do
        [ -n "$mirror" ] || continue
        [ "${mirror%/}" = "${preferred%/}" ] && continue
        printf '%s\n' "$mirror"
    done
}

github_candidates() {
    local preferred="$1"
    local origin_url="$2"
    shift 2

    local mirror
    if [ "$preferred" = "__ORIGIN__" ]; then
        printf '|%s\n' "$origin_url"
    fi

    if [ -n "${1:-}" ]; then
        while IFS= read -r mirror; do
            [ -n "$mirror" ] || continue
            printf '%s|%s%s\n' "${mirror%/}" "${mirror%/}/" "$origin_url"
        done < <(ordered_mirrors "$preferred" "$@")
    fi

    if [ "$preferred" != "__ORIGIN__" ]; then
        printf '|%s\n' "$origin_url"
    fi
}

probe_url() {
    local url="$1"

    "${AC_CURL_COMMAND:-curl}" -L -I --silent --show-error --fail \
        --connect-timeout "${DOWNLOAD_PROBE_CONNECT_TIMEOUT:-5}" \
        --max-time "${DOWNLOAD_PROBE_MAX_TIME:-15}" \
        "$url" >/dev/null 2>&1
}

probe_github_candidate_order() {
    local preference_var="$1"
    local label="$2"
    local origin_url="$3"
    shift 3

    local mirror candidate_url

    mirror_log "检测${label}: $origin_url"
    if probe_url "$origin_url"; then
        mirror_log "[OK] ${label}: $origin_url"
        set_mirror_preference "$preference_var" "__ORIGIN__" "$label"
        return 0
    fi
    mirror_log "[WARN] ${label}不可用: $origin_url"

    for mirror in "$@"; do
        [ -n "$mirror" ] || continue
        candidate_url="${mirror%/}/$origin_url"
        mirror_log "检测${label}: $candidate_url"
        if probe_url "$candidate_url"; then
            mirror_log "[OK] ${label}: $candidate_url"
            set_mirror_preference "$preference_var" "${mirror%/}" "$label"
            return 0
        fi
        mirror_log "[WARN] ${label}不可用: $candidate_url"
    done

    mirror_log "[WARN] ${label}检测全部失败，将按配置顺序尝试"
    return 1
}

write_mirror_preferences() {
    mkdir -p "$(dirname "$DOWNLOAD_MIRROR_STATE_FILE")"
    {
        echo "# 由 ac.sh 自动生成，记录上次成功的加速源"
        printf 'AC_PREFERRED_SOURCE_ARCHIVE_MIRROR=%q\n' "${AC_PREFERRED_SOURCE_ARCHIVE_MIRROR:-}"
        printf 'AC_PREFERRED_RELEASE_LATEST_MIRROR=%q\n' "${AC_PREFERRED_RELEASE_LATEST_MIRROR:-}"
        printf 'AC_PREFERRED_RELEASE_ASSET_MIRROR=%q\n' "${AC_PREFERRED_RELEASE_ASSET_MIRROR:-}"
        printf 'AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR=%q\n' "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}"
    } > "${DOWNLOAD_MIRROR_STATE_FILE}.tmp"
    mv "${DOWNLOAD_MIRROR_STATE_FILE}.tmp" "$DOWNLOAD_MIRROR_STATE_FILE"
}

release_latest_mirrors() {
    if declare -p GITHUB_RELEASE_LATEST_MIRRORS >/dev/null 2>&1; then
        printf '%s\n' "${GITHUB_RELEASE_LATEST_MIRRORS[@]}"
    elif declare -p GITHUB_RELEASES_MIRRORS >/dev/null 2>&1; then
        printf '%s\n' "${GITHUB_RELEASES_MIRRORS[@]}"
    fi
}

release_asset_mirrors() {
    if declare -p GITHUB_RELEASE_ASSET_MIRRORS >/dev/null 2>&1; then
        printf '%s\n' "${GITHUB_RELEASE_ASSET_MIRRORS[@]}"
    elif declare -p GITHUB_RELEASES_MIRRORS >/dev/null 2>&1; then
        printf '%s\n' "${GITHUB_RELEASES_MIRRORS[@]}"
    fi
}

load_mirror_preferences() {
    [ -f "$DOWNLOAD_MIRROR_STATE_FILE" ] || return 0

    # shellcheck disable=SC1090
    source "$DOWNLOAD_MIRROR_STATE_FILE"
    if [ -n "${AC_PREFERRED_RELEASES_MIRROR:-}" ]; then
        AC_PREFERRED_RELEASE_LATEST_MIRROR="${AC_PREFERRED_RELEASE_LATEST_MIRROR:-$AC_PREFERRED_RELEASES_MIRROR}"
        AC_PREFERRED_RELEASE_ASSET_MIRROR="${AC_PREFERRED_RELEASE_ASSET_MIRROR:-$AC_PREFERRED_RELEASES_MIRROR}"
    fi
    export AC_PREFERRED_SOURCE_ARCHIVE_MIRROR AC_PREFERRED_RELEASE_LATEST_MIRROR AC_PREFERRED_RELEASE_ASSET_MIRROR
    export AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR
    mirror_log "已加载镜像偏好: $DOWNLOAD_MIRROR_STATE_FILE"
}

set_mirror_preference() {
    local var_name="$1"
    local value="$2"
    local label="$3"
    local current_value="${!var_name:-}"

    [ -n "$value" ] || return 0
    printf -v "$var_name" '%s' "$value"
    export "$var_name"
    write_mirror_preferences

    if [ "$current_value" != "$value" ]; then
        mirror_log "后续优先使用${label}: $value"
    fi
}

download_cached_file() {
    local target_file="$1"
    local success_var="${2:-}"
    local item_name="$3"
    local success_prefix=""
    local validator="${DOWNLOAD_FILE_VALIDATOR:-}"
    local last_source="无可用下载源"
    local last_error="未配置可用下载地址"
    shift 3

    local candidate candidate_url tmp_file output size
    if [ -f "$target_file" ]; then
        download_log "已存在: $target_file"
        download_success "$item_name" "本地缓存" "$target_file"
        return 0
    fi

    mkdir -p "$(dirname "$target_file")"
    tmp_file="${target_file}.part"
    rm -f "$tmp_file"

    for candidate in "$@"; do
        [ -n "$candidate" ] || continue
        if [[ "$candidate" == *"|"* ]]; then
            success_prefix="${candidate%%|*}"
            candidate_url="${candidate#*|}"
        else
            success_prefix=""
            candidate_url="$candidate"
        fi
        download_log "下载: $candidate_url -> $target_file"
        if output="$(curl -L --fail --silent --show-error \
            --connect-timeout "${DOWNLOAD_CONNECT_TIMEOUT:-10}" \
            --max-time "${DOWNLOAD_MAX_TIME:-300}" \
            --speed-limit "${DOWNLOAD_LOW_SPEED_LIMIT:-32768}" \
            --speed-time "${DOWNLOAD_LOW_SPEED_TIME:-60}" \
            "$candidate_url" -o "$tmp_file" 2>&1)"; then
            if [ -n "$validator" ] && ! "$validator" "$tmp_file"; then
                last_source="$candidate_url"
                last_error="下载文件校验失败"
                download_log "[WARN] 下载文件校验失败，切换下一个源: $candidate_url"
                rm -f "$tmp_file"
                continue
            fi
            mv "$tmp_file" "$target_file"
            size="$(du -h "$target_file" | awk '{print $1}')"
            download_log "[OK] $target_file ($size)"
            if [ -n "$success_var" ] && [ -n "$success_prefix" ]; then
                set_mirror_preference "$success_var" "$success_prefix" "镜像"
            fi
            download_success "$item_name" "$candidate_url" "$target_file"
            return 0
        fi
        last_source="$candidate_url"
        last_error="$output"
        [ -n "$output" ] && printf '%s\n' "$output" | download_log_output
        download_log "[WARN] 下载失败或速度过低，切换下一个源: $candidate_url"
        rm -f "$tmp_file"
    done

    download_failure "$target_file" "$last_source" "$last_error"
    return 1
}

source_repo_slug() {
    local repo="$1"
    local slug

    slug="${repo#git@github.com:}"
    slug="${slug#https://github.com/}"
    slug="${slug#http://github.com/}"
    slug="${slug%.git}"
    printf '%s\n' "$slug"
}

source_repo_name() {
    local repo="$1"
    local slug

    slug="$(source_repo_slug "$repo")"
    basename "$slug"
}

source_ref_name() {
    local ref="$1"
    if [ -z "$ref" ]; then
        printf '%s\n' "HEAD"
    else
        printf '%s\n' "$ref"
    fi
}

source_archive_url() {
    local repo="$1"
    local ref
    local slug

    ref="$(source_ref_name "${2:-}")"
    slug="$(source_repo_slug "$repo")"

    if [ "$ref" = "HEAD" ]; then
        printf 'https://github.com/%s/archive/HEAD.zip\n' "$slug"
    else
        printf 'https://github.com/%s/archive/refs/heads/%s.zip\n' "$slug" "$ref"
    fi
}

source_archive_file() {
    local repo="$1"
    local ref
    local slug
    local safe_name

    ref="$(source_ref_name "${2:-}")"
    slug="$(source_repo_slug "$repo")"
    safe_name="${slug//\//_}_${ref//\//_}.zip"
    printf '%s/%s\n' "$DOWNLOAD_SOURCE_DIR" "$safe_name"
}

source_archive_download_candidates() {
    local archive_url="$1"

    github_candidates "${AC_PREFERRED_SOURCE_ARCHIVE_MIRROR:-}" "$archive_url" "${GITHUB_SOURCE_ARCHIVE_MIRRORS[@]}"
}

download_source_archive() {
    local repo="$1"
    local ref="${2:-}"
    local archive_url archive_file item_name
    local candidates=()

    archive_url="$(source_archive_url "$repo" "$ref")"
    archive_file="$(source_archive_file "$repo" "$ref")"
    mapfile -t candidates < <(source_archive_download_candidates "$archive_url")

    if [ "$repo" = "$ACORE_SOURCE_REPO" ]; then
        item_name="AzerothCore 源码"
    else
        item_name="$(source_repo_name "$repo") 源码"
    fi

    download_cached_file "$archive_file" AC_PREFERRED_SOURCE_ARCHIVE_MIRROR "$item_name" "${candidates[@]}"
}

prepare_source_archives() {
    local module_url

    download_source_archive "$ACORE_SOURCE_REPO" "$ACORE_SOURCE_BRANCH"

    for module_repo in "${ACORE_MODULE_REPOS[@]}"; do
        download_source_archive "$module_repo" "HEAD"
    done
}

source_archives_cached() {
    local module_repo archive_file

    archive_file="$(source_archive_file "$ACORE_SOURCE_REPO" "$ACORE_SOURCE_BRANCH")"
    [ -f "$archive_file" ] || return 1

    for module_repo in "${ACORE_MODULE_REPOS[@]}"; do
        archive_file="$(source_archive_file "$module_repo" "HEAD")"
        [ -f "$archive_file" ] || return 1
    done
}

client_data_archive_cached() {
    [ -f "$(client_data_archive_file)" ]
}

docker_runtime_images_cached() {
    local image archive_file

    for image in "${DOCKER_BASE_IMAGES[@]}"; do
        if [ "${AC_DOCKER_IMAGE_ARCHIVE_CACHE:-1}" = "1" ]; then
            archive_file="$(docker_image_archive_file "$image")"
            [ -f "$archive_file" ] && continue
        fi

        docker image inspect "$image" >/dev/null 2>&1 || return 1
    done
}

probe_github_source_downloads() {
    local source_probe_url
    local source_mirrors=()

    source_probe_url="$(source_archive_url "$ACORE_SOURCE_REPO" "$ACORE_SOURCE_BRANCH")"
    mapfile -t source_mirrors < <(printf '%s\n' "${GITHUB_SOURCE_ARCHIVE_MIRRORS[@]}")

    probe_github_candidate_order \
        AC_PREFERRED_SOURCE_ARCHIVE_MIRROR \
        "GitHub 源码下载" \
        "$source_probe_url" \
        "${source_mirrors[@]}" || true
}

probe_github_client_downloads() {
    local release_probe_url="https://github.com/wowgaming/client-data/releases/latest"
    local release_asset_probe_url
    local latest_mirrors=()
    local asset_mirrors=()

    mapfile -t latest_mirrors < <(release_latest_mirrors)
    mapfile -t asset_mirrors < <(release_asset_mirrors)

    if [ "${CLIENT_DATA_VERSION:-latest}" = "latest" ]; then
        probe_github_candidate_order \
            AC_PREFERRED_RELEASE_LATEST_MIRROR \
            "GitHub Release latest 解析" \
            "$release_probe_url" \
            "${latest_mirrors[@]}" || true

        resolve_client_data_version >/dev/null 2> >(mirror_log_output) 4>&2 || true
    else
        AC_CLIENT_DATA_RESOLVED_VERSION="$CLIENT_DATA_VERSION"
        export AC_CLIENT_DATA_RESOLVED_VERSION
        mirror_log "跳过GitHub Release latest 解析检测: 已指定客户端数据版本 ${CLIENT_DATA_VERSION}"
    fi

    if is_client_data_version "${AC_CLIENT_DATA_RESOLVED_VERSION:-}"; then
        release_asset_probe_url="$(client_data_download_url)"
    else
        release_asset_probe_url="https://github.com/wowgaming/client-data/releases/download/v19/data.zip"
    fi

    probe_github_candidate_order \
        AC_PREFERRED_RELEASE_ASSET_MIRROR \
        "GitHub Release 文件下载" \
        "$release_asset_probe_url" \
        "${asset_mirrors[@]}" || true
}

probe_github_downloads() {
    probe_github_source_downloads
    probe_github_client_downloads
}

probe_download_mirrors_for_missing_cache() {
    if source_archives_cached; then
        mirror_log "跳过GitHub 源码下载检测: 源码压缩包缓存已存在"
    else
        probe_github_source_downloads >/dev/null 2> >(mirror_log_output)
    fi

    if client_data_archive_cached; then
        mirror_log "跳过GitHub Release latest 解析检测: 客户端数据缓存已存在"
        mirror_log "跳过GitHub Release 文件下载检测: 客户端数据缓存已存在"
    else
        probe_github_client_downloads >/dev/null 2> >(mirror_log_output)
    fi

    if docker_runtime_images_cached; then
        mirror_log "跳过Docker 镜像源检测: Docker 镜像缓存已存在"
    else
        probe_docker_image_mirrors >/dev/null 2> >(mirror_log_output) || true
    fi
}

resolve_client_data_version() {
    local configured_version="${CLIENT_DATA_VERSION:-latest}"
    local latest_url="https://github.com/wowgaming/client-data/releases/latest"
    local headers latest_location candidate candidate_url success_prefix output
    local last_source=""
    local last_error=""

    if [ "$configured_version" != "latest" ]; then
        AC_CLIENT_DATA_RESOLVED_VERSION="$configured_version"
        export AC_CLIENT_DATA_RESOLVED_VERSION
        return 0
    fi

    if is_client_data_version "${AC_CLIENT_DATA_RESOLVED_VERSION:-}"; then
        return 0
    fi
    unset AC_CLIENT_DATA_RESOLVED_VERSION

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if [[ "$candidate" == *"|"* ]]; then
            success_prefix="${candidate%%|*}"
            candidate_url="${candidate#*|}"
        else
            success_prefix=""
            candidate_url="$candidate"
        fi
        last_source="$candidate_url"

        download_log "解析客户端数据最新版本: $candidate_url"
        if headers="$("${AC_CURL_COMMAND:-curl}" -L -I --silent --show-error --fail \
            --connect-timeout "${DOWNLOAD_CONNECT_TIMEOUT:-10}" \
            --max-time "${DOWNLOAD_MAX_TIME:-300}" \
            --speed-limit "${DOWNLOAD_LOW_SPEED_LIMIT:-32768}" \
            --speed-time "${DOWNLOAD_LOW_SPEED_TIME:-60}" \
            "$candidate_url" 2>&1)"; then
            latest_location="$(printf '%s\n' "$headers" | awk 'BEGIN { IGNORECASE=1 } /^location:/ { gsub("\r", "", $0); print $2 }' | tail -n 1)"
            AC_CLIENT_DATA_RESOLVED_VERSION="${latest_location##*/}"
            if is_client_data_version "$AC_CLIENT_DATA_RESOLVED_VERSION"; then
                if [ -n "$success_prefix" ]; then
                    set_mirror_preference AC_PREFERRED_RELEASE_LATEST_MIRROR "$success_prefix" "Release latest 镜像"
                fi
                break
            fi
            last_error="无法从响应头 Location 解析有效客户端数据版本: ${latest_location:-未返回 Location}"
            download_log "[WARN] 无法从响应头解析有效客户端数据版本: $candidate_url"
            continue
        fi

        output="$headers"
        last_error="$output"
        [ -n "$output" ] && printf '%s\n' "$output" | download_log_output
        download_log "[WARN] 解析客户端数据最新版本失败，切换下一个源: $candidate_url"
    done < <(client_data_latest_candidates "$latest_url")

    if ! is_client_data_version "${AC_CLIENT_DATA_RESOLVED_VERSION:-}"; then
        download_failure "客户端数据最新版本" "${last_source:-无可用下载源}" "${last_error:-未配置可用下载地址}"
        return 1
    fi

    export AC_CLIENT_DATA_RESOLVED_VERSION
    download_log "客户端数据最新版本: $AC_CLIENT_DATA_RESOLVED_VERSION"
}

client_data_latest_candidates() {
    local latest_url="$1"
    local mirrors=()

    mapfile -t mirrors < <(release_latest_mirrors)
    github_candidates "${AC_PREFERRED_RELEASE_LATEST_MIRROR:-}" "$latest_url" "${mirrors[@]}"
}

client_data_download_url() {
    if [ -n "${CLIENT_DATA_DOWNLOAD_URL:-}" ]; then
        printf '%s\n' "$CLIENT_DATA_DOWNLOAD_URL"
    else
        printf 'https://github.com/wowgaming/client-data/releases/download/%s/data.zip\n' "$AC_CLIENT_DATA_RESOLVED_VERSION"
    fi
}

client_data_archive_file() {
    local configured_version="${CLIENT_DATA_VERSION:-latest}"
    printf '%s/%s.zip\n' "$DOWNLOAD_CLIENT_DIR" "$configured_version"
}

client_data_download_candidates() {
    local download_url
    local mirrors=()

    download_url="$(client_data_download_url)"
    mapfile -t mirrors < <(release_asset_mirrors)

    github_candidates "${AC_PREFERRED_RELEASE_ASSET_MIRROR:-}" "$download_url" "${mirrors[@]}"
}

prepare_client_data_archive() {
    local archive_file
    local candidates=()

    archive_file="$(client_data_archive_file)"
    if [ -f "$archive_file" ]; then
        download_log "已存在: $archive_file"
        download_success "客户端数据" "本地缓存" "$archive_file"
        return 0
    fi

    resolve_client_data_version
    mapfile -t candidates < <(client_data_download_candidates)
    DOWNLOAD_FILE_VALIDATOR=validate_zip_file download_cached_file "$archive_file" AC_PREFERRED_RELEASE_ASSET_MIRROR "客户端数据" "${candidates[@]}"
}

validate_zip_file() {
    unzip -tq "$1" >/dev/null 2>&1
}

extract_source_archive() {
    local archive_file="$1"
    local target_dir="$2"
    local tmp_dir top_dir

    if [ ! -f "$archive_file" ]; then
        echo "错误: 源码压缩包不存在: $archive_file" >&2
        return 1
    fi

    tmp_dir="$(mktemp -d)"
    unzip -q -o "$archive_file" -d "$tmp_dir"
    top_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$top_dir" ]; then
        rm -rf "$tmp_dir"
        echo "错误: 源码压缩包结构异常: $archive_file" >&2
        return 1
    fi

    rm -rf "$target_dir"
    mkdir -p "$(dirname "$target_dir")"
    mv "$top_dir" "$target_dir"
    rm -rf "$tmp_dir"
}

install_source_archives() {
    local module_repo mod_name archive_file mod_dir

    echo "解压 AzerothCore 源码"
    archive_file="$(source_archive_file "$ACORE_SOURCE_REPO" "$ACORE_SOURCE_BRANCH")"
    extract_source_archive "$archive_file" "$BUILD_ACORE_DIR"

    mkdir -p "$BUILD_ACORE_MOD_DIR"
    for module_repo in "${ACORE_MODULE_REPOS[@]}"; do
        mod_name="$(source_repo_name "$module_repo")"
        mod_dir="$BUILD_ACORE_MOD_DIR/$mod_name"
        archive_file="$(source_archive_file "$module_repo" "HEAD")"
        echo "解压模块源码: $mod_name"
        extract_source_archive "$archive_file" "$mod_dir"
    done
}

dockerImagePullCandidates() {
    local image="$1"
    local mirror
    local candidates=()

    if [ "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}" = "__ORIGIN__" ]; then
        candidates+=("|$image")
    fi

    if [ -n "${DOCKER_IMAGE_PULL_MIRRORS[0]}" ]; then
        while IFS= read -r mirror; do
            if [[ "$image" == */* ]]; then
                candidates+=("${mirror%/}|${mirror%/}/${image}")
            else
                candidates+=("${mirror%/}|${mirror%/}/library/${image}")
            fi
        done < <(ordered_mirrors "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}" "${DOCKER_IMAGE_PULL_MIRRORS[@]}")
    fi

    if [ "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}" != "__ORIGIN__" ]; then
        candidates+=("|$image")
    fi
    printf '%s\n' "${candidates[@]}"
}

docker_image_ref_for_mirror() {
    local image="$1"
    local mirror="$2"

    if [ -z "$mirror" ] || [ "$mirror" = "__ORIGIN__" ]; then
        printf '%s\n' "$image"
    elif [[ "$image" == */* ]]; then
        printf '%s/%s\n' "${mirror%/}" "$image"
    else
        printf '%s/library/%s\n' "${mirror%/}" "$image"
    fi
}

probe_docker_mirror_value() {
    local mirror="$1"
    local label="$2"
    local probe_image ref

    probe_image="${DOCKER_MIRROR_PROBE_IMAGE:-hello-world:latest}"
    ref="$(docker_image_ref_for_mirror "$probe_image" "$mirror")"

    mirror_log "检测Docker 镜像源: $label -> $ref"
    if docker_probe_pull "$ref" >/dev/null 2>&1; then
        mirror_log "[OK] Docker 镜像源探测成功: $label -> $ref"
        docker_probe_cleanup "$ref"
        return 0
    fi

    mirror_log "[WARN] Docker 镜像源探测失败: $label -> $ref"
    return 1
}

docker_probe_pull() {
    local ref="$1"
    local timeout_seconds="${DOCKER_MIRROR_PROBE_TIMEOUT:-${DOWNLOAD_PROBE_MAX_TIME:-15}}"

    if declare -F docker >/dev/null 2>&1; then
        docker pull "$ref"
    elif command -v timeout >/dev/null 2>&1; then
        DOCKER_CLIENT_TIMEOUT="$timeout_seconds" timeout -k 2 "$timeout_seconds" docker pull "$ref"
    else
        docker pull "$ref"
    fi
}

docker_probe_cleanup() {
    local ref="$1"

    docker rmi -f "$ref" >/dev/null 2>&1 || true
}

probe_docker_image_mirrors() {
    local mirror

    if probe_docker_mirror_value "__ORIGIN__" "原始地址"; then
        mirror_log "[OK] Docker 镜像源: 原始地址"
        set_mirror_preference AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR "__ORIGIN__" " Docker 镜像源"
        return 0
    fi
    mirror_log "[WARN] Docker 镜像源不可用: 原始地址"

    for mirror in "${DOCKER_IMAGE_PULL_MIRRORS[@]}"; do
        [ -n "$mirror" ] || continue
        mirror="${mirror%/}"
        if probe_docker_mirror_value "$mirror" "$mirror"; then
            mirror_log "[OK] Docker 镜像源: $mirror"
            set_mirror_preference AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR "$mirror" " Docker 镜像源"
            return 0
        fi
        mirror_log "[WARN] Docker 镜像源不可用: $mirror"
    done

    mirror_log "[WARN] Docker 镜像源检测全部失败，将按配置顺序尝试"
    return 1
}

mirror_preference_label() {
    local value="$1"

    if [ "$value" = "__ORIGIN__" ]; then
        printf '%s\n' "原始地址"
    elif [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "未选定"
    fi
}

log_selected_mirrors_to_download_log() {
    download_log "镜像选择: GitHub源码=$(mirror_preference_label "${AC_PREFERRED_SOURCE_ARCHIVE_MIRROR:-}")"
    download_log "镜像选择: GitHub latest=$(mirror_preference_label "${AC_PREFERRED_RELEASE_LATEST_MIRROR:-}")"
    download_log "镜像选择: GitHub Release文件=$(mirror_preference_label "${AC_PREFERRED_RELEASE_ASSET_MIRROR:-}")"
    download_log "镜像选择: Docker=$(mirror_preference_label "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}")"
}

log_docker_mirror_candidates() {
    local image="$1"
    local candidate candidate_mirror candidate_ref

    mirror_log "Docker 镜像候选: $image"
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if [[ "$candidate" == *"|"* ]]; then
            candidate_mirror="${candidate%%|*}"
            candidate_ref="${candidate#*|}"
        else
            candidate_mirror=""
            candidate_ref="$candidate"
        fi

        if [ -n "$candidate_mirror" ]; then
            mirror_log "Docker 镜像候选: mirror=${candidate_mirror} ref=${candidate_ref}"
        else
            mirror_log "Docker 镜像候选: 原始地址 ref=${candidate_ref}"
        fi
    done < <(dockerImagePullCandidates "$image")
}

docker_image_archive_file() {
    local image="$1"
    local safe_name

    safe_name="${image//\//_}"
    safe_name="${safe_name//:/_}"
    printf '%s/%s.tar\n' "$DOWNLOAD_DOCKER_IMAGE_DIR" "$safe_name"
}

load_cached_docker_image() {
    local image="$1"
    local archive_file
    local output

    if [ "${AC_DOCKER_IMAGE_ARCHIVE_CACHE:-1}" != "1" ]; then
        return 1
    fi

    archive_file="$(docker_image_archive_file "$image")"
    if [ ! -f "$archive_file" ]; then
        return 1
    fi

    echo "加载镜像缓存: $archive_file"
    download_log "加载镜像缓存: $archive_file"
    if output=$(docker load -i "$archive_file" 2>&1) && docker image inspect "$image" >/dev/null 2>&1; then
        echo "[OK] 镜像缓存已加载: $image"
        printf '%s\n' "$output" | download_log_output
        download_log "[OK] 镜像缓存已加载: $image"
        return 0
    fi

    echo "[WARN] 镜像缓存加载失败: $archive_file" >&2
    echo "$output" >&2
    printf '%s\n' "$output" | download_log_output
    download_log "[WARN] 镜像缓存加载失败: $archive_file"
    return 1
}

save_cached_docker_image() {
    local image="$1"
    local archive_file
    local output

    if [ "${AC_DOCKER_IMAGE_ARCHIVE_CACHE:-1}" != "1" ]; then
        return 0
    fi

    archive_file="$(docker_image_archive_file "$image")"
    if [ -f "$archive_file" ]; then
        echo "镜像缓存已存在: $archive_file"
        download_log "镜像缓存已存在: $archive_file"
        return 0
    fi

    mkdir -p "$(dirname "$archive_file")"
    echo "保存镜像缓存: $archive_file"
    download_log "保存镜像缓存: $archive_file"
    if ! output=$(docker save -o "$archive_file" "$image" 2>&1); then
        echo "[WARN] 镜像缓存保存失败: $image" >&2
        echo "$output" >&2
        printf '%s\n' "$output" | download_log_output
        download_log "[WARN] 镜像缓存保存失败: $image"
        rm -f "$archive_file"
    else
        download_log "[OK] 镜像缓存已保存: $archive_file"
    fi
}

pull_docker_image() {
    local image="$1"
    local candidate
    local candidate_ref candidate_mirror
    local output
    local last_source=""
    local last_error=""

    if docker image inspect "$image" >/dev/null 2>&1; then
        echo "已存在: $image"
        download_log "镜像已存在: $image"
        save_cached_docker_image "$image"
        download_success "Docker 镜像" "本地缓存" "$image"
        return 0
    fi

    if load_cached_docker_image "$image"; then
        download_success "Docker 镜像" "本地缓存" "$image"
        return 0
    fi

    while IFS= read -r candidate; do
        if [[ "$candidate" == *"|"* ]]; then
            candidate_mirror="${candidate%%|*}"
            candidate_ref="${candidate#*|}"
        else
            candidate_mirror=""
            candidate_ref="$candidate"
        fi
        last_source="$candidate_ref"

        echo "拉取镜像: $candidate_ref"
        download_log "拉取镜像: $candidate_ref"
        if output=$(docker pull "$candidate_ref" 2>&1); then
            printf '%s\n' "$output" | download_log_output
            if [ "$candidate_ref" != "$image" ]; then
                if ! output=$(docker tag "$candidate_ref" "$image" 2>&1); then
                    last_error="$output"
                    printf '%s\n' "$output" | download_log_output
                    download_log "[ERROR] 镜像标记失败: $candidate_ref -> $image"
                    download_failure "$image" "$candidate_ref" "$last_error"
                    return 1
                fi
                if ! output=$(docker rmi "$candidate_ref" 2>&1); then
                    echo "[WARN] 加速镜像临时标签删除失败: $candidate_ref" >&2
                    echo "$output" >&2
                    printf '%s\n' "$output" | download_log_output
                    download_log "[WARN] 加速镜像临时标签删除失败: $candidate_ref"
                fi
            fi
            echo "[OK] $candidate_ref"
            download_log "[OK] $candidate_ref"
            if [ -n "$candidate_mirror" ]; then
                set_mirror_preference AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR "$candidate_mirror" " Docker 镜像源"
            fi
            save_cached_docker_image "$image"
            download_success "Docker 镜像" "$candidate_ref" "$image"
            return 0
        fi
        last_error="$output"
        printf '%s\n' "$output" | download_log_output
    done < <(dockerImagePullCandidates "$image")

    download_failure "$image" "${last_source:-无可用下载源}" "${last_error:-未配置可用镜像地址}"
    return 1
}

prepare_runtime_images() {
    local image

    for image in "${DOCKER_BASE_IMAGES[@]}"; do
        log_docker_mirror_candidates "$image"
        pull_docker_image "$image"
    done
}

write_buildkit_config() {
    local config_file="$BUILD_BUILDKIT_CONFIG_FILE"
    local mirror

    mkdir -p "$(dirname "$config_file")"
    {
        echo '# 由 ac.sh 自动生成，配置 BuildKit 标准镜像名的 registry mirror'
        echo '[registry."docker.io"]'
        echo '  mirrors = ['
        while IFS= read -r mirror; do
            [ -n "$mirror" ] || continue
            printf '    "https://%s",\n' "${mirror#https://}"
        done < <(ordered_mirrors "${AC_PREFERRED_DOCKER_IMAGE_PULL_MIRROR:-}" "${DOCKER_IMAGE_PULL_MIRRORS[@]}")
        echo '  ]'
    } > "$config_file"
}

resolve_buildkit_image() {
    echo "$DOCKER_BUILDKIT_IMAGE"
}

build_builder_names_to_remove() {
    printf '%s\n' "$DOCKER_BUILDX_BUILDER_NAME"
    if [ "$DOCKER_BUILDX_BUILDER_NAME" != "acore-lowmem" ]; then
        printf '%s\n' "acore-lowmem"
    fi
}

remove_build_builder() {
    local builder_name

    while IFS= read -r builder_name; do
        [ -n "$builder_name" ] || continue
        if docker buildx inspect "$builder_name" >/dev/null 2>&1; then
            echo "删除构建器: $builder_name"
            docker buildx rm "$builder_name" >/dev/null 2>&1 || true
        fi
    done < <(build_builder_names_to_remove)
}

ensure_build_builder() {
    local builder_name="${DOCKER_BUILDX_BUILDER_NAME}"
    local buildkit_image
    local inspect_output
    local current_config_hash desired_config_hash

    write_buildkit_config
    buildkit_image="$(resolve_buildkit_image)"
    desired_config_hash="$(sha256sum "$BUILD_BUILDKIT_CONFIG_FILE" | awk '{print $1}')"
    if inspect_output="$(docker buildx inspect "$builder_name" 2>/dev/null)"; then
        current_config_hash="$(docker exec "buildx_buildkit_${builder_name}0" sh -c 'sha256sum /etc/buildkit/buildkitd.toml 2>/dev/null | awk "{print \$1}"' 2>/dev/null || true)"
        if ! grep -q "memory=\"${DOCKER_BUILD_MEMORY_LIMIT}\"" <<< "$inspect_output" || { [ -n "$current_config_hash" ] && [ "$current_config_hash" != "$desired_config_hash" ]; }; then
            echo "重建构建器: $builder_name memory ${DOCKER_BUILD_MEMORY_LIMIT}"
            docker buildx rm "$builder_name" >/dev/null 2>&1 || true
        fi
    fi

    if ! docker buildx inspect "$builder_name" >/dev/null 2>&1; then
        echo "创建构建器: $builder_name"
        docker buildx create \
            --name "$builder_name" \
            --driver docker-container \
            --driver-opt "image=${buildkit_image}" \
            --driver-opt "memory=${DOCKER_BUILD_MEMORY_LIMIT}" \
            --buildkitd-config "$BUILD_BUILDKIT_CONFIG_FILE" \
            --use
    else
        echo "复用构建器: $builder_name"
        docker buildx use "$builder_name"
    fi

    docker buildx inspect --bootstrap >/dev/null
}

prepare_downloads() {
    check_environment
    ensure_download_cache_dir
    init_download_log
    init_mirror_log
    load_mirror_preferences >/dev/null 2> >(mirror_log_output)
    probe_download_mirrors_for_missing_cache
    log_selected_mirrors_to_download_log
    run_download_stage prepare_source_archives
    run_download_stage prepare_client_data_archive
    run_download_stage prepare_runtime_images
}

probe_mirrors_only() {
    check_environment
    ensure_download_cache_dir
    init_mirror_log
    load_mirror_preferences >/dev/null 2> >(mirror_log_output)
    probe_github_downloads
    probe_docker_image_mirrors || true
    echo "镜像检测完成: $DOWNLOAD_MIRROR_STATE_FILE"
    echo "镜像检测日志: $(mirror_log_file_path)"
}

prepare_build_tools() {
    ensure_build_builder
}
