#!/bin/bash

function detectedIP() {
    if test -z "$REALMLIST_ADDRESS" 
    then
        REALMLIST_ADDRESS=$(hostname -I | awk '{print $1}')        
    fi
    echo "realmlist address: $REALMLIST_ADDRESS"
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
    
    # 如果没有提供镜像地址，使用默认的 GITHUB_MIRROR
    if [ -z "$mirror_url" ]; then
        mirror_url="$GITHUB_GIT_MIRROR"
    fi
    
    # 如果最终没有提供镜像地址,返回原始地址
    if [ -z "$mirror_url" ]; then
        echo "$original_url"
        return 0
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

# gitClone - 克隆或更新 git 仓库
# 用法: gitClone <git_url> [分支名称] [目录名称]
# 参数:
#   git_url: git 仓库地址
#   分支名称 (可选): 要克隆或切换的分支名称
#   目录名称 (可选): 克隆到的目录名称，如果不指定则从 git_url 提取
gitClone() {
    local git_url=$(gitPullMirrorUrl "$1")
    local git_name=$(basename -s .git $1)
    local branch_name="$2"
    local dir_name="$3"
    
    # 检查是否提供了 git_url
    if [ -z "$git_url" ]; then
        echo "错误: 请提供 git 地址"
        echo "用法: gitClone <git_url> [分支名称] [目录名称]"
        return 1
    fi
    
    # 参数处理逻辑
    # 如果只提供了两个参数，第二个参数可能是分支名或目录名
    if [ -n "$branch_name" ] && [ -z "$dir_name" ]; then
        # 检查第二个参数是否包含斜杠（可能是分支名）
        if [[ "$branch_name" == *"/"* ]]; then
            # 包含斜杠，可能是分支名
            dir_name=""
        else
            # 不包含斜杠，可能是目录名
            dir_name="$branch_name"
            branch_name=""
        fi
    fi
    
    # 如果没有提供目录名称，从 git_url 提取
    if [ -z "$dir_name" ]; then
        # 从 git_url 提取仓库名称 (去掉 .git 后缀)
        dir_name=$(basename "$git_url" .git)
    fi
    
    echo "处理仓库: $git_url"
    if [ -n "$branch_name" ]; then
        echo "分支: $branch_name"
    fi

    # 检查目录是否存在
    if [ ! -d "$dir_name" ]; then
        echo "目录${dir_name}不存在，开始克隆..."
        
        # 构建克隆命令
        local clone_cmd="git clone --depth 1"
        if [ -n "$branch_name" ]; then
            clone_cmd="$clone_cmd --branch $branch_name"
        fi
        clone_cmd="$clone_cmd \"$git_url\" \"$dir_name\""
        
        echo "执行: $clone_cmd"
        eval $clone_cmd
        
        if [ $? -eq 0 ]; then
            echo "${git_name}克隆成功!"
            return 0
        else
            echo "${git_name}克隆失败!"
            return 1
        fi
    else
        echo "目录${git_name}已存在，开始还原和更新..."
        
        # 进入目录
        cd "$dir_name" || return 1
        
        # 如果指定了分支，先切换到该分支
        if [ -n "$branch_name" ]; then
            echo "切换到分支: $branch_name"
            git checkout "$branch_name"
            if [ $? -ne 0 ]; then
                echo "切换分支失败!"
                cd ..
                return 1
            fi
        fi
        
        # 还原所有修改
        echo "还原修改..."
        git reset --hard
        if [ $? -ne 0 ]; then
            echo "还原失败!"
            cd ..
            return 1
        fi
        
        # 清理未跟踪的文件
        echo "清理未跟踪文件..."
        git clean -fd
        
        # 更新仓库
        echo "更新${git_name}仓库..."
        git pull
        if [ $? -eq 0 ]; then
            echo "更新${git_name}成功!"
            cd ..
            return 0
        else
            echo "更新${git_name}失败!"
            cd ..
            return 1
        fi
    fi
}
