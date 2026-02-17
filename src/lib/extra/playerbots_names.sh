#!/bin/bash

readonly PLAYERBOTS_SQL_CUSTOM_PATH="$BUILD_ACORE_MOD_DIR/mod-playerbots/data/sql/characters"


playerbots_custom_sql() {
    mkdir -p $PLAYERBOTS_SQL_CUSTOM_PATH
    # 替换playerbots_names表中的名字
    generate_playerbots_names_sql
    # 替换playerbots_guild_names表中的名字
    generate_playerbots_guild_names_sql
    # 替换playerbots_arena_team_names表中的名字
    playerbots_arena_team_names_sql
}



# 脚本功能：读取名字字典文件，生成SQL语句替换playerbots_names表中的名字

# 自定义处理函数：为名字分配ID和随机性别
playerbots_names_custom_handler() {
    local NAME="$1"
    local OUTPUT_SQL="$2"
    local gender=$((RANDOM % 2))  # 随机分配性别：0或1
    echo "($playerbots_name_id,'$NAME',$gender)," >> "$OUTPUT_SQL"
    playerbots_name_id=$((playerbots_name_id + 1))
}

generate_playerbots_names_sql() {
    echo "开始生成playerbots_names表的SQL语句"
    local NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/dict/playerbots_names_dict.txt"
    local NEW_NAMES_SQL_FILE="playerbots_names_00.sql"
    local TABLE_NAME="playerbots_names"    
    # 初始化ID
    playerbots_name_id=0
    
    generate_playerbots_custom_sql "$NAMES_DICT_FILE" "$NEW_NAMES_SQL_FILE" "$TABLE_NAME" "playerbots_names_custom_handler" "$PLAYERBOTS_SQL_CUSTOM_PATH"
}

# 脚本功能：替换playerbots_guild_names表中的名字

# 自定义处理函数：为公会名称生成SQL语句
playerbots_guild_names_custom_handler() {
    local GUILD_NAME="$1"
    local OUTPUT_SQL="$2"
    echo "(NULL, '$GUILD_NAME')," >> "$OUTPUT_SQL"
}

generate_playerbots_guild_names_sql() {
    echo "开始生成playerbots_guild_names表的SQL语句"
    local GUILD_NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/dict/playerbots_guild_names_dict.txt"
    local NEW_GUILD_NAMES_SQL_FILE="playerbots_guild_names_00.sql"
    local TABLE_NAME="playerbots_guild_names"

    generate_playerbots_custom_sql "$GUILD_NAMES_DICT_FILE" "$NEW_GUILD_NAMES_SQL_FILE" "$TABLE_NAME" "playerbots_guild_names_custom_handler" "$PLAYERBOTS_SQL_CUSTOM_PATH"
}


# 脚本功能：替换playerbots_arena_team_names表中的名字
# 自定义处理函数：为竞技场团队名称生成SQL语句
playerbots_arena_team_names_custom_handler() {
    local name="$1"
    local OUTPUT_SQL="$2"

    # 随机选择一个数字
    numbers=(1 2 3 5)
    random_index=$((RANDOM % ${#numbers[@]}))
    local type=${numbers[$random_index]}
    echo "(NULL,'$name',$type)," >> "$OUTPUT_SQL"
}

playerbots_arena_team_names_sql() {
    echo "开始生成playerbots_arena_team_names表的SQL语句"
    local ARENA_TEAM_NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/dict/playerbots_arena_team_names_dict.txt"
    local NEW_ARENA_TEAM_NAMES_SQL_FILE="playerbots_arena_team_names_00.sql"
    local TABLE_NAME="playerbots_arena_team_names"

    generate_playerbots_custom_sql "$ARENA_TEAM_NAMES_DICT_FILE" "$NEW_ARENA_TEAM_NAMES_SQL_FILE" "$TABLE_NAME" "playerbots_arena_team_names_custom_handler" "$PLAYERBOTS_SQL_CUSTOM_PATH"
}



# 通用SQL生成函数
# 参数1: 字典文件名
# 参数2: 输出SQL文件名
# 参数3: 目标表名
# 参数4: 自定义处理函数名（可选）
# 参数5: 额外复制路径（可选）
generate_playerbots_custom_sql() {
    local DICT_FILE="$1"
    local OUTPUT_FILE_NAME="$2"
    local TABLE_NAME="$3"
    local CUSTOM_HANDLER="$4"
    local EXTRA_COPY_PATH="$5"
    
    local BUILD_SQL_DIR="$BUILD_DIR/sql"
    local OUTPUT_SQL="$BUILD_SQL_DIR/$OUTPUT_FILE_NAME"

    # 检查字典文件是否存在
    if [ ! -f "$DICT_FILE" ]; then
        echo "错误：字典文件 $DICT_FILE 不存在！"
        exit 1
    fi
    
    # 创建SQL目录
    mkdir -p "$BUILD_SQL_DIR"    
    # 开始生成SQL文件
    cat > "$OUTPUT_SQL" << EOF
-- Delete all existing $TABLE_NAME
DELETE FROM \`$TABLE_NAME\`;

-- Insert Chinese $TABLE_NAME
INSERT INTO \`$TABLE_NAME\` VALUES
EOF
    
    # 读取字典文件，去重并生成INSERT语句
    # 使用进程替换避免子shell问题
    local count=0
    while read -r ITEM; do
        # 强制使用自定义处理函数
        $CUSTOM_HANDLER "$ITEM" "$OUTPUT_SQL"
        count=$((count + 1))
    done < <(uniq "$DICT_FILE")
    
    # 移除最后一行的逗号
    sed -i '$s/,$//' "$OUTPUT_SQL"
    
    # 添加结束语句
    echo "-- End of insert statements" >> "$OUTPUT_SQL"
    
    # 显示结果
    echo "已成功生成SQL文件：$OUTPUT_SQL"
    echo "包含 $count 个去重后的条目"
    
    cp "$OUTPUT_SQL" "$EXTRA_COPY_PATH"
    echo "已拷贝到：$EXTRA_COPY_PATH"
  
}