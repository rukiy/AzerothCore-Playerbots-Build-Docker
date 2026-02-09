#!/bin/bash

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
