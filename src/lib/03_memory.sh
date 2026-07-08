#!/bin/bash

read_system_memory_mb() {
    local total_mb

    total_mb="$(free -m 2>/dev/null | awk '/^Mem:/ {print $2; exit}')"
    if [ -z "$total_mb" ]; then
        echo "错误：无法读取系统内存信息" >&2
        return 1
    fi

    echo "$total_mb"
}

read_system_memory_used_mb() {
    local used_mb

    used_mb="$(free -m 2>/dev/null | awk '/^Mem:/ {print $3; exit}')"
    if [ -z "$used_mb" ]; then
        echo "错误：无法读取系统已用内存信息" >&2
        return 1
    fi

    echo "$used_mb"
}

memory_min() {
    [ "$1" -le "$2" ] && echo "$1" || echo "$2"
}

memory_max() {
    [ "$1" -ge "$2" ] && echo "$1" || echo "$2"
}

memory_clamp() {
    local value="$1"
    local min="$2"
    local max="$3"

    value="$(memory_max "$value" "$min")"
    value="$(memory_min "$value" "$max")"
    echo "$value"
}

memory_round_down() {
    local value="$1"
    local step="$2"

    if [ "$value" -lt "$step" ]; then
        echo "$value"
        return 0
    fi

    echo $((value / step * step))
}

detect_cpu_count() {
    if [ -n "${AC_CPU_COUNT:-}" ]; then
        echo "$AC_CPU_COUNT"
        return 0
    fi

    nproc 2>/dev/null || echo 1
}

set_default_if_empty() {
    local name="$1"
    local value="$2"

    if [ -z "${!name:-}" ]; then
        printf -v "$name" '%s' "$value"
    fi
}

prepare_memory_plan() {
    if [ "${AC_MEMORY_PLAN_READY:-0}" = "1" ] && [ "${AC_MEMORY_PLAN_FORCE:-0}" != "1" ]; then
        return 0
    fi

    local total_mb used_mb cpu_count reserved_mb dynamic_reserved_mb reserved_extra_mb build_reserved_mb build_limit_mb build_memory_per_job_mb
    local runtime_reserved_mb runtime_budget_mb database_mb world_mb auth_mb client_init_mb runtime_used_mb
    local build_jobs max_jobs

    total_mb="$(read_system_memory_mb)"
    used_mb="$(read_system_memory_used_mb)"
    cpu_count="$(detect_cpu_count)"

    if [ "${AC_MEMORY_AUTO:-1}" = "0" ]; then
        AC_MEMORY_TOTAL_MB="$total_mb"
        AC_MEMORY_USED_MB="$used_mb"
        set_default_if_empty DOCKER_BUILD_MEMORY_LIMIT "4g"
        set_default_if_empty DOCKER_BUILD_PARALLEL_JOBS "2"
        set_default_if_empty AC_DATABASE_MEMORY_LIMIT "1536m"
        set_default_if_empty AC_WORLDSERVER_MEMORY_LIMIT "3072m"
        set_default_if_empty AC_AUTHSERVER_MEMORY_LIMIT "384m"
        set_default_if_empty AC_CLIENT_DATA_INIT_MEMORY_LIMIT "512m"
        set_default_if_empty AC_DATABASE_INNODB_BUFFER_POOL_SIZE "768M"
        AC_MEMORY_PLAN_READY=1
        export AC_MEMORY_TOTAL_MB AC_MEMORY_USED_MB DOCKER_BUILD_MEMORY_LIMIT DOCKER_BUILD_PARALLEL_JOBS
        export DOCKER_BUILDKIT_MAX_PARALLELISM AC_DATABASE_MEMORY_LIMIT
        export AC_WORLDSERVER_MEMORY_LIMIT AC_AUTHSERVER_MEMORY_LIMIT AC_CLIENT_DATA_INIT_MEMORY_LIMIT
        export AC_DATABASE_INNODB_BUFFER_POOL_SIZE AC_MEMORY_PLAN_READY
        return 0
    fi

    reserved_extra_mb="${AC_MEMORY_DYNAMIC_RESERVED_EXTRA_MB:-512}"
    dynamic_reserved_mb=$((used_mb + reserved_extra_mb))
    reserved_mb="${AC_MEMORY_RESERVED_MB:-$dynamic_reserved_mb}"

    if [ "$reserved_mb" -ge "$((total_mb - 1024))" ]; then
        echo "错误：当前可用于构建的内存不足。总内存=${total_mb}MB，当前已用=${used_mb}MB，保留=${reserved_mb}MB" >&2
        return 1
    fi

    runtime_reserved_mb="$reserved_mb"
    runtime_reserved_mb="$(memory_min "$runtime_reserved_mb" "$((total_mb - 1024))")"

    build_reserved_mb="$reserved_mb"
    build_reserved_mb="$(memory_min "$build_reserved_mb" "$((total_mb - 1024))")"
    build_limit_mb=$((total_mb - build_reserved_mb))
    build_limit_mb="$(memory_clamp "$build_limit_mb" 1024 "$((total_mb - 512))")"

    runtime_budget_mb=$((total_mb - runtime_reserved_mb))
    runtime_budget_mb="$(memory_clamp "$runtime_budget_mb" 1024 "$((total_mb - 512))")"

    database_mb=$((runtime_budget_mb * 30 / 100))
    world_mb=$((runtime_budget_mb * 60 / 100))
    auth_mb=$((runtime_budget_mb * 8 / 100))
    client_init_mb=$((runtime_budget_mb * 12 / 100))

    database_mb="$(memory_clamp "$database_mb" 768 4096)"
    world_mb="$(memory_clamp "$world_mb" 1024 8192)"
    auth_mb="$(memory_clamp "$auth_mb" 256 1024)"
    client_init_mb="$(memory_clamp "$client_init_mb" 512 2048)"

    database_mb="$(memory_round_down "$database_mb" 128)"
    world_mb="$(memory_round_down "$world_mb" 128)"
    auth_mb="$(memory_round_down "$auth_mb" 128)"
    client_init_mb="$(memory_round_down "$client_init_mb" 128)"

    runtime_used_mb=$((database_mb + world_mb + auth_mb + client_init_mb))
    if [ "$runtime_used_mb" -gt "$runtime_budget_mb" ]; then
        world_mb=$((world_mb - (runtime_used_mb - runtime_budget_mb)))
        world_mb="$(memory_max "$world_mb" 1024)"
    fi

    if [ "$total_mb" -lt 4096 ]; then
        max_jobs=1
    elif [ -n "${DOCKER_BUILD_MEMORY_PER_JOB_MB:-}" ]; then
        build_memory_per_job_mb="$DOCKER_BUILD_MEMORY_PER_JOB_MB"
        max_jobs=$((build_limit_mb / build_memory_per_job_mb))
        max_jobs="$(memory_clamp "$max_jobs" 1 "$cpu_count")"
    else
        max_jobs="$cpu_count"
    fi
    build_jobs="$max_jobs"

    AC_MEMORY_TOTAL_MB="$total_mb"
    AC_MEMORY_USED_MB="$used_mb"
    AC_BUILD_RESERVED_MB="$build_reserved_mb"
    AC_RUNTIME_RESERVED_MB="$runtime_reserved_mb"
    AC_RUNTIME_MEMORY_BUDGET_MB="$runtime_budget_mb"

    set_default_if_empty DOCKER_BUILD_MEMORY_LIMIT "${build_limit_mb}m"
    set_default_if_empty DOCKER_BUILD_PARALLEL_JOBS "$build_jobs"
    set_default_if_empty AC_DATABASE_MEMORY_LIMIT "${database_mb}m"
    set_default_if_empty AC_WORLDSERVER_MEMORY_LIMIT "${world_mb}m"
    set_default_if_empty AC_AUTHSERVER_MEMORY_LIMIT "${auth_mb}m"
    set_default_if_empty AC_CLIENT_DATA_INIT_MEMORY_LIMIT "${client_init_mb}m"
    set_default_if_empty AC_DATABASE_INNODB_BUFFER_POOL_SIZE "$((database_mb / 2))M"

    AC_MEMORY_PLAN_READY=1
    export AC_MEMORY_TOTAL_MB AC_MEMORY_USED_MB AC_BUILD_RESERVED_MB AC_RUNTIME_RESERVED_MB AC_RUNTIME_MEMORY_BUDGET_MB
    export DOCKER_BUILD_MEMORY_LIMIT DOCKER_BUILD_PARALLEL_JOBS DOCKER_BUILDKIT_MAX_PARALLELISM
    export AC_DATABASE_MEMORY_LIMIT AC_WORLDSERVER_MEMORY_LIMIT AC_AUTHSERVER_MEMORY_LIMIT
    export AC_CLIENT_DATA_INIT_MEMORY_LIMIT
    export AC_DATABASE_INNODB_BUFFER_POOL_SIZE AC_MEMORY_PLAN_READY
}

print_memory_plan() {
    prepare_memory_plan
    echo "内存规划: 总内存=${AC_MEMORY_TOTAL_MB}MB 当前已用=${AC_MEMORY_USED_MB:-未知}MB 构建保留=${AC_BUILD_RESERVED_MB:-手动}MB 构建=${DOCKER_BUILD_MEMORY_LIMIT} 构建并行=${DOCKER_BUILD_PARALLEL_JOBS} 运行预算=${AC_RUNTIME_MEMORY_BUDGET_MB:-自动}MB"
    echo "运行限制: database=${AC_DATABASE_MEMORY_LIMIT} worldserver=${AC_WORLDSERVER_MEMORY_LIMIT} authserver=${AC_AUTHSERVER_MEMORY_LIMIT} client-data-init=${AC_CLIENT_DATA_INIT_MEMORY_LIMIT} innodb_buffer_pool=${AC_DATABASE_INNODB_BUFFER_POOL_SIZE}"
}

write_managed_env_values() {
    local env_file="$1"
    local tmp_file

    prepare_memory_plan
    mkdir -p "$(dirname "$env_file")"
    touch "$env_file"

    tmp_file="$(mktemp)"
    awk '
        /^# BEGIN ACORE AUTO MEMORY$/ { skip = 1; next }
        /^# END ACORE AUTO MEMORY$/ { skip = 0; next }
        skip != 1 { print }
    ' "$env_file" > "$tmp_file"

    cat >> "$tmp_file" <<EOF
# BEGIN ACORE AUTO MEMORY
AC_MEMORY_TOTAL_MB=${AC_MEMORY_TOTAL_MB}
AC_MEMORY_USED_MB=${AC_MEMORY_USED_MB:-}
AC_BUILD_RESERVED_MB=${AC_BUILD_RESERVED_MB:-}
AC_RUNTIME_RESERVED_MB=${AC_RUNTIME_RESERVED_MB:-}
AC_DATABASE_MEMORY_LIMIT=${AC_DATABASE_MEMORY_LIMIT}
AC_WORLDSERVER_MEMORY_LIMIT=${AC_WORLDSERVER_MEMORY_LIMIT}
AC_AUTHSERVER_MEMORY_LIMIT=${AC_AUTHSERVER_MEMORY_LIMIT}
AC_CLIENT_DATA_INIT_MEMORY_LIMIT=${AC_CLIENT_DATA_INIT_MEMORY_LIMIT}
AC_DATABASE_INNODB_BUFFER_POOL_SIZE=${AC_DATABASE_INNODB_BUFFER_POOL_SIZE}
AC_RUNTIME_DOCKERFILE=${BUILD_RUNTIME_DOCKERFILE:-}
# END ACORE AUTO MEMORY
EOF

    mv "$tmp_file" "$env_file"
}

write_mysql_memory_config() {
    local cnf_file="$1"
    local tmp_file

    prepare_memory_plan
    if [ ! -f "$cnf_file" ]; then
        echo "错误：MySQL 配置文件不存在: $cnf_file" >&2
        return 1
    fi

    tmp_file="$(mktemp)"
    awk -v pool_size="$AC_DATABASE_INNODB_BUFFER_POOL_SIZE" '
        BEGIN { updated = 0 }
        /^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=/ {
            print "innodb_buffer_pool_size = " pool_size
            updated = 1
            next
        }
        { print }
        END {
            if (updated == 0) {
                print "innodb_buffer_pool_size = " pool_size
            }
        }
    ' "$cnf_file" > "$tmp_file"
    mv "$tmp_file" "$cnf_file"
    chmod 644 "$cnf_file"
}
