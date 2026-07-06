#!/bin/bash

dockerImagePullCandidates() {
    local image="$1"
    local mirror
    local candidates=()

    if [ -n "${DOCKER_IMAGE_PULL_MIRRORS[0]}" ]; then
        for mirror in "${DOCKER_IMAGE_PULL_MIRRORS[@]}"; do
            if [[ "$image" == */* ]]; then
                candidates+=("${mirror%/}/${image}")
            else
                candidates+=("${mirror%/}/library/${image}")
            fi
        done
    fi

    candidates+=("$image")
    printf '%s\n' "${candidates[@]}"
}

dockerImageMirrorRef() {
    local image="$1"
    printf '%s\n' "$image"
}

check_required_commands() {
    local command_name
    local missing=()

    for command_name in docker git curl unzip; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "错误：缺少必要命令: ${missing[*]}" >&2
        return 1
    fi
}

ensure_prepared_environment() {
    check_required_commands
    mkdir -p "$BUILD_DIR"
    mkdir -p "$WOTLK_DIR"
}

pull_docker_image() {
    local image="$1"
    local candidate
    local output

    if docker image inspect "$image" >/dev/null 2>&1; then
        echo "已存在: $image"
        return 0
    fi

    while IFS= read -r candidate; do
        echo "拉取镜像: $candidate"
        if output=$(docker pull "$candidate" 2>&1); then
            if [ "$candidate" != "$image" ]; then
                if ! output=$(docker tag "$candidate" "$image" 2>&1); then
                    echo "[ERROR] 镜像标记失败: $candidate -> $image" >&2
                    echo "$output" >&2
                    return 1
                fi
                if ! output=$(docker rmi "$candidate" 2>&1); then
                    echo "[WARN] 加速镜像临时标签删除失败: $candidate" >&2
                    echo "$output" >&2
                fi
            fi
            echo "[OK] $candidate"
            return 0
        fi
        echo "$output" >&2
    done < <(dockerImagePullCandidates "$image")

    echo "[ERROR] 镜像拉取失败: $image" >&2
    return 1
}

prepare_runtime_images() {
    local image

    for image in "${DOCKER_BASE_IMAGES[@]}"; do
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
        for mirror in "${DOCKER_IMAGE_PULL_MIRRORS[@]}"; do
            [ -n "$mirror" ] || continue
            printf '    "https://%s",\n' "${mirror#https://}"
        done
        echo '  ]'
    } > "$config_file"
}

builder_config_hash() {
    {
        printf 'memory=%s\n' "$DOCKER_BUILD_MEMORY_LIMIT"
        [ -f "$BUILD_BUILDKIT_CONFIG_FILE" ] && cat "$BUILD_BUILDKIT_CONFIG_FILE"
    } | sha256sum | awk '{print $1}'
}

ensure_low_memory_builder() {
    local builder_name="${DOCKER_BUILDX_BUILDER_NAME}"
    local inspect_output
    local current_config_hash desired_config_hash

    write_buildkit_config
    desired_config_hash="$(sha256sum "$BUILD_BUILDKIT_CONFIG_FILE" | awk '{print $1}')"
    if inspect_output="$(docker buildx inspect "$builder_name" 2>/dev/null)"; then
        current_config_hash="$(docker exec "buildx_buildkit_${builder_name}0" sh -c 'sha256sum /etc/buildkit/buildkitd.toml 2>/dev/null | awk "{print \\$1}"' 2>/dev/null || true)"
        if ! grep -q "memory=\"${DOCKER_BUILD_MEMORY_LIMIT}\"" <<< "$inspect_output" || { [ -n "$current_config_hash" ] && [ "$current_config_hash" != "$desired_config_hash" ]; }; then
            echo "重建低内存构建器: $builder_name memory ${DOCKER_BUILD_MEMORY_LIMIT}"
            docker buildx rm "$builder_name" >/dev/null 2>&1 || true
        fi
    fi

    if ! docker buildx inspect "$builder_name" >/dev/null 2>&1; then
        echo "创建低内存构建器: $builder_name"
        docker buildx create \
            --name "$builder_name" \
            --driver docker-container \
            --driver-opt "image=${DOCKER_BUILDKIT_IMAGE}" \
            --driver-opt "memory=${DOCKER_BUILD_MEMORY_LIMIT}" \
            --buildkitd-config "$BUILD_BUILDKIT_CONFIG_FILE" \
            --use
    else
        echo "复用低内存构建器: $builder_name"
        docker buildx use "$builder_name"
    fi

    docker buildx inspect --bootstrap >/dev/null
}

prepare_build_environment() {
    ensure_prepared_environment
    prepare_memory_plan
    print_memory_plan
    prepare_runtime_images
    ensure_low_memory_builder
}
