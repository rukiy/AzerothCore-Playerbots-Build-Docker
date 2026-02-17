#!/bin/bash

# ============================================
# 脚本: AzerothCore 服务器管理脚本
# 功能: 构建、卸载、切换服务器状态、显示信息
# 注意: 需要预先设置环境变量:
#   - BUILD_ACORE_DIR: 构建目录
#   - WOTLK_DIR: 运行数据目录
#   - REALMLIST_ADDRESS: 游戏客户端连接地址
# ============================================

# 严格模式：任何命令失败立即退出脚本
set -e

# ============================================
# 函数: build
# 功能: 执行完整的构建流程
# 参数: $1 - 初始化参数 (传递给initialize函数)
# ============================================
function build() {
    echo "开始构建流程..."

    # 1. 初始化环境 (根据参数决定是否清理旧数据)
    initialize "$1"

    # 2. 构建客户端相关组件
    client

    # 3. 构建AzerothCore核心
    azerothcore

    # 4. 构建模块
    module

    # 5. 执行额外配置
    extra

    # 6. 配置容器
    container

    # 7. 配置数据库
    database

    # 8. 显示完成信息
    printinfo
}

# ============================================
# 函数: toggle
# 功能: 切换服务状态
#     如果所有容器都在运行，则全部停止
#     如果有容器未运行，则启动所有容器
# ============================================
function toggle() {
    # 定义需要管理的容器列表
    local containers=("ac-worldserver" "ac-authserver" "ac-database")
    local all_running=true

    echo "检查容器状态..."

    # 检查每个容器是否在运行
    for container in "${containers[@]}"; do
        # 使用精确匹配检查容器是否在运行
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "容器 $container 未在运行"
            all_running=false
            break
        else
            echo "容器 $container 正在运行"
        fi
    done

    echo ""

    # 根据状态执行相应操作
    if $all_running; then
        echo "所有容器都在运行，正在停止..."
        docker stop "${containers[@]}"
        echo "所有容器已停止"
    else
        echo "检测到有容器未运行，正在启动所有容器..."
        docker start "${containers[@]}"
        echo "所有容器已启动"
    fi

    echo ""
    echo "当前容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "ac-worldserver|ac-authserver|ac-database" || echo "没有找到相关容器"
}

# ============================================
# 函数: printinfo
# 功能: 显示安装完成后的引导信息
# ============================================
function printinfo() {
    echo ""
    echo "========================================"
    echo "安装已完成！"
    echo "========================================"
    echo ""
    echo "安装成果："
    echo "- 数据库已配置在3306端口"
    echo "- 实境列表已自动配置为IP: $REALMLIST_ADDRESS"
    echo "- 500个玩家机器人已就绪，提供即时多人游戏体验"
    echo ""
    echo "后续操作指引："
    echo "1. 执行命令 'docker attach ac-worldserver'"
    echo "2. 输入 'account create 用户名 密码' 创建账户"
    echo "3. 输入 'account set gmlevel 用户名 3 -1' 设置账户为全服管理员"
    echo "4. 按下 Ctrl+p Ctrl+q 退出世界服务器控制台"
    echo "5. 编辑魔兽客户端 realmlist.wtf 文件，内容设为: $REALMLIST_ADDRESS"
    echo "6. 使用3.3.5a客户端登录游戏"
    echo "7. 所有配置文件已复制到wotlk文件夹"
    echo ""
    echo "========================================"
    echo "祝您尽情享受拥有500个AI伙伴的私人魔兽世界服务器！"
    echo "========================================"
    echo ""
}

# ============================================
# 使用示例
# ============================================
# build 1          # 构建并清理旧数据
# build 0          # 构建但不清理旧数据
# uninstall        # 完全卸载
# toggle           # 切换服务状态
