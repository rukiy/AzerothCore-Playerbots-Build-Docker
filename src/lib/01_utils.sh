#!/bin/bash

function realmListServer() {
    if test -z "$REALMLIST_NAME"
    then
        REALMLIST_NAME="Azeroth"
    fi
    if test -z "$REALMLIST_LOCAL_ADDRESS"
    then
        REALMLIST_LOCAL_ADDRESS="$(hostname -I | awk '{print $1}')"
    fi
    if test -z "$REALMLIST_ADDRESS"
    then
        REALMLIST_ADDRESS="$REALMLIST_LOCAL_ADDRESS"
    fi
    echo "realmlist address: $REALMLIST_ADDRESS  localaddress: $REALMLIST_LOCAL_ADDRESS"
}

function execute_sql() {
    local db_name="$1"
    local sql="$2"
    docker exec -e MYSQL_PWD="$DOCKER_DB_ROOT_PASSWORD" ac-database mysql -u root "$db_name" -e "$sql"
}

function execute_sql_files() {
    local db_name="$1"
    shift

    local custom_sql_file
    for custom_sql_file in "$@"; do
        [ -f "$custom_sql_file" ] || continue
        echo "执行sql文件 $custom_sql_file"
        docker exec -i -e MYSQL_PWD="$DOCKER_DB_ROOT_PASSWORD" ac-database mysql -u root "$db_name" < "$custom_sql_file"
    done
}

function sql_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\'/\'\'}"
    printf '%s' "$value"
}

compose_args() {
    printf '%s\n' \
        --env-file "$SRC_DIR/.env" \
        -f "$BUILD_ACORE_DIR/docker-compose.yml" \
        -f "$SRC_DIR/docker-compose.override.yml"
}

run_with_timeout() {
    local seconds="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
    else
        "$@"
    fi
}

# gitMirrorUrl - 处理 git 地址的镜像替换
# 用法: gitMirrorUrl <原始git地址> [镜像地址]
# 参数:
#   原始git地址: 原始的 git 仓库地址
#   镜像地址 (可选): 镜像服务器地址，例如 https://githubfast.com/
# 返回: 处理后的 git 地址
gitPullMirrorUrl() {
    local original_url="$1"
    local mirror_url="$2"
    
    # 检查是否提供了原始地址
    if [ -z "$original_url" ]; then
        echo "错误: 请提供 git 地址"
        echo "用法: gitMirrorUrl <原始git地址> [镜像地址]"
        return 1
    fi
    
    # 如果没有提供镜像地址，使用默认镜像列表的第一个
    if [ -z "$mirror_url" ]; then
        mirror_url="${GITHUB_GIT_MIRRORS[0]}"
    fi
    
    # 检查镜像地址是否以 / 结尾，如果不是则添加
    if [ -n "$mirror_url" ] && [[ "$mirror_url" != */ ]]; then
        mirror_url="$mirror_url/"
    fi
    
    # 判断原始地址是否包含 github.com
    if [[ "$original_url" == *"github.com"* ]]; then
        # 替换 github.com 为镜像地址
        # 处理多种格式的 git 地址
        local result=""

        if [[ "$mirror_url" == *"https://github.com/"* ]]; then
            if [[ "$original_url" =~ ^https://github\.com/(.*)$ ]]; then
                result="${mirror_url}${BASH_REMATCH[1]}"
            else
                result="$original_url"
            fi
            echo "$result"
            return 0
        fi

        if [[ "$mirror_url" == *"gitclone.com/github.com/"* ]]; then
            if [[ "$original_url" =~ ^https://github\.com/(.*)$ ]]; then
                result="${mirror_url}${BASH_REMATCH[1]}"
            elif [[ "$original_url" =~ ^http://github\.com/(.*)$ ]]; then
                result="${mirror_url}${BASH_REMATCH[1]}"
            elif [[ "$original_url" =~ ^git@github\.com:(.*)$ ]]; then
                result="${mirror_url}${BASH_REMATCH[1]}"
            else
                result="$original_url"
            fi
            echo "$result"
            return 0
        fi
        
        # 处理 https://github.com/owner/repo.git 格式
        if [[ "$original_url" =~ ^https://github\.com/(.*)$ ]]; then
            result="${mirror_url}${BASH_REMATCH[1]}"
        # 处理 git@github.com:owner/repo.git 格式
        elif [[ "$original_url" =~ ^git@github\.com:(.*)$ ]]; then
            result="${mirror_url}${BASH_REMATCH[1]}"
        # 处理 http://github.com/owner/repo.git 格式
        elif [[ "$original_url" =~ ^http://github\.com/(.*)$ ]]; then
            result="${mirror_url}${BASH_REMATCH[1]}"
        else
            # 如果格式不匹配，直接替换 github.com
            result="${original_url/github.com/${mirror_url%/}}"
        fi
        
        echo "$result"
        return 0
    else
        # 不包含 github.com，返回原始地址
        echo "$original_url"
        return 0
    fi
}

gitCandidateIsValid() {
    local candidate_url="$1"
    local output

    if output=$(GIT_TERMINAL_PROMPT=0 run_with_timeout "$GIT_LS_REMOTE_TIMEOUT" git ls-remote --heads "$candidate_url" HEAD 2>&1); then
        return 0
    fi

    echo "[WARN] Git 候选地址不可用或超时: $candidate_url" >&2
    echo "$output" >&2
    return 1
}

gitMirrorCandidates() {
    local source_url="$1"
    local mirror
    local candidates=()

    if [ -n "${GITHUB_GIT_MIRRORS[0]}" ]; then
        for mirror in "${GITHUB_GIT_MIRRORS[@]}"; do
            candidates+=("$(gitPullMirrorUrl "$source_url" "$mirror")")
        done
    fi

    candidates+=("$source_url")
    printf '%s\n' "${candidates[@]}"
}

# gitClone - 克隆或更新 git 仓库
# 用法: gitClone <git_url> [分支名称] [目录名称]
# 参数:
#   git_url: git 仓库地址
#   分支名称 (可选): 要克隆或切换的分支名称
#   目录名称 (可选): 克隆到的目录名称，如果不指定则从 git_url 提取
gitClone() {
    local git_url
    git_url="$(gitPullMirrorUrl "$1")"
    local git_name
    git_name="$(basename -s .git "$1")"
    local branch_name="$2"
    local dir_name="$3"
    local original_pwd
    original_pwd="$(pwd)"
    local source_url="$1"
    
    # 参数验证
    if [ -z "$git_url" ]; then
        echo "错误: 请提供 git 地址" >&2
        echo "用法: gitClone <git_url> [分支名称] [目录名称]" >&2
        return 1
    fi
    
    # 智能参数处理
    if [ -n "$branch_name" ] && [ -z "$dir_name" ]; then
        if [[ "$branch_name" == *"/"* ]]; then
            dir_name=""
        else
            dir_name="$branch_name"
            branch_name=""
        fi
    fi
    
    # 自动提取目录名
    if [ -z "$dir_name" ]; then
        dir_name=$(basename "$git_url" .git)
    fi
    
    # 检查目录是否存在
    if [ ! -d "$dir_name" ]; then
        # 克隆仓库
        echo "正在克隆: $git_name"
        local clone_args=("--depth" "1")
        if [ -n "$branch_name" ]; then
            clone_args+=("--branch" "$branch_name")
        fi

        local candidate_url clone_output
        while IFS= read -r candidate_url; do
            if ! gitCandidateIsValid "$candidate_url"; then
                continue
            fi

            echo "尝试克隆镜像: $candidate_url"
            if clone_output=$(GIT_TERMINAL_PROMPT=0 run_with_timeout "$GIT_CLONE_TIMEOUT" git clone "${clone_args[@]}" "$candidate_url" "$dir_name" 2>&1); then
                echo "[OK] $git_name 克隆完成"
                return 0
            fi
            echo "[WARN] $git_name 克隆失败或超时: $candidate_url" >&2
            echo "$clone_output" >&2
            rm -rf "$dir_name"
        done < <(gitMirrorCandidates "$source_url")

        echo "[ERROR] $git_name 克隆失败" >&2
        echo "错误原因: $clone_output" >&2
        echo "提示: 请检查网络连接或仓库地址" >&2
        return 1
    else
        # 更新现有仓库
        echo "正在更新: $git_name"
        
        # 进入目录
        if ! cd "$dir_name"; then
            echo "[ERROR] 无法进入目录: $dir_name" >&2
            return 1
        fi

        local abs_path
        abs_path="$(pwd)"
        git config --global --add safe.directory "$abs_path" >/dev/null 2>&1 || true
        
        local error_msg=""
        
        # 强制还原所有修改（在切换分支前）
        local reset_output
        if ! reset_output=$(git reset --hard 2>&1); then
            error_msg="强制还原失败: $reset_output"
        fi
        
        # 清理未跟踪的文件
        if [ -z "$error_msg" ]; then
            git clean -fd >/dev/null 2>&1
        fi
        
        # 切换分支（如果指定）
        if [ -z "$error_msg" ] && [ -n "$branch_name" ]; then
            local checkout_output
            if ! checkout_output=$(git checkout "$branch_name" 2>&1); then
                error_msg="分支切换失败: $checkout_output"
            fi
        fi
        
        # 再次强制还原（切换分支后可能有状态变化）
        if [ -z "$error_msg" ]; then
            if ! reset_output=$(git reset --hard 2>&1); then
                error_msg="二次还原失败: $reset_output"
            fi
        fi
        
        # 更新
        if [ -z "$error_msg" ]; then
            local pull_output
            if pull_output=$(GIT_TERMINAL_PROMPT=0 run_with_timeout "$GIT_PULL_TIMEOUT" git pull 2>&1); then
                echo "[OK] $git_name 更新完成"
                cd "$original_pwd" >/dev/null 2>&1 || true
                return 0
            fi
            error_msg="更新失败: $pull_output"
        fi

        # 处理错误
        echo "[ERROR] $git_name 更新失败" >&2
        echo "错误原因: $error_msg" >&2
        cd "$original_pwd" >/dev/null 2>&1 || true
        return 1
    fi
}
