#!/bin/bash

readonly PLAYERBOTS_SQL_CUSTOM_PATH="$BUILD_ACORE_MOD_DIR/mod-playerbots/data/sql/characters"


playerbots_names() {
    mkdir -p "$PLAYERBOTS_SQL_CUSTOM_PATH"
    # 替换playerbots_names表中的名字
    generate_playerbots_names_sql
    # 替换playerbots_guild_names表中的名字
    generate_playerbots_guild_names_sql
    # 替换playerbots_arena_team_names表中的名字
    playerbots_arena_team_names_sql
}


# 脚本功能：读取名字字典文件，生成SQL语句替换playerbots_names表中的名字
generate_playerbots_names_sql() {
    echo "开始生成playerbots_names表的SQL语句"
    local NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/playerbots_names/playerbots_names_dict.txt"
    local NEW_NAMES_SQL_FILE="playerbots_names_00.sql"

    generate_playerbots_fast_sql "$NAMES_DICT_FILE" "$NEW_NAMES_SQL_FILE" "playerbots_names" "$PLAYERBOTS_SQL_CUSTOM_PATH" "names"
}

# 脚本功能：替换playerbots_guild_names表中的名字
generate_playerbots_guild_names_sql() {
    echo "开始生成playerbots_guild_names表的SQL语句"
    local GUILD_NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/playerbots_names/playerbots_guild_names_dict.txt"
    local NEW_GUILD_NAMES_SQL_FILE="playerbots_guild_names_00.sql"

    generate_playerbots_fast_sql "$GUILD_NAMES_DICT_FILE" "$NEW_GUILD_NAMES_SQL_FILE" "playerbots_guild_names" "$PLAYERBOTS_SQL_CUSTOM_PATH" "guild"
}


# 脚本功能：替换playerbots_arena_team_names表中的名字
playerbots_arena_team_names_sql() {
    echo "开始生成playerbots_arena_team_names表的SQL语句"
    local ARENA_TEAM_NAMES_DICT_FILE="$SRC_LIB_EXTRA_DIR/playerbots_names/playerbots_arena_team_names_dict.txt"
    local NEW_ARENA_TEAM_NAMES_SQL_FILE="playerbots_arena_team_names_00.sql"

    generate_playerbots_fast_sql "$ARENA_TEAM_NAMES_DICT_FILE" "$NEW_ARENA_TEAM_NAMES_SQL_FILE" "playerbots_arena_team_names" "$PLAYERBOTS_SQL_CUSTOM_PATH" "arena"
}


# 快速SQL生成函数
# 参数1: 字典文件名
# 参数2: 输出SQL文件名
# 参数3: 目标表名
# 参数4: 额外复制路径
# 参数5: 类型 names|guild|arena
generate_playerbots_fast_sql() {
    local DICT_FILE="$1"
    local OUTPUT_FILE_NAME="$2"
    local TABLE_NAME="$3"
    local EXTRA_COPY_PATH="$4"
    local SQL_TYPE="$5"

    local BUILD_SQL_DIR="$BUILD_DIR/sql"
    local OUTPUT_SQL="$BUILD_SQL_DIR/$OUTPUT_FILE_NAME"
    local COUNT_FILE="$OUTPUT_SQL.count"

    if [ ! -f "$DICT_FILE" ]; then
        echo "错误：字典文件 $DICT_FILE 不存在！"
        exit 1
    fi

    mkdir -p "$BUILD_SQL_DIR"

    sort -u "$DICT_FILE" | awk -v table="$TABLE_NAME" -v type="$SQL_TYPE" -v count_file="$COUNT_FILE" -v sq="'" '
        function sql_escape(value) {
            gsub(/\\/, "\\\\", value)
            gsub(sq, sq sq, value)
            return value
        }
        function row_sql(value, id, race_gender, arena_type) {
            value = sql_escape(value)
            if (type == "names") {
                race_gender = id % 18
                return "(" id "," sq value sq "," race_gender ")"
            }
            if (type == "guild") {
                return "(NULL, " sq value sq ")"
            }
            arena_type = arena_types[(id % 4) + 1]
            return "(NULL," sq value sq "," arena_type ")"
        }
        BEGIN {
            count = 0
            arena_types[1] = 1
            arena_types[2] = 2
            arena_types[3] = 3
            arena_types[4] = 5
            print "-- Delete all existing " table
            print "DELETE FROM `" table "`;"
            print ""
            print "-- Insert Chinese " table
            print "INSERT INTO `" table "` VALUES"
        }
        NF > 0 {
            rows[count] = row_sql($0, count)
            count++
        }
        END {
            for (i = 0; i < count; i++) {
                suffix = (i == count - 1) ? "" : ","
                print rows[i] suffix
            }
            print "-- End of insert statements"
            print count > count_file
        }
    ' > "$OUTPUT_SQL"

    local count=0
    if [ -f "$COUNT_FILE" ]; then
        count="$(cat "$COUNT_FILE")"
        rm -f "$COUNT_FILE"
    fi

    echo "已成功生成SQL文件：$OUTPUT_SQL"
    echo "包含 $count 个去重后的条目"

    mkdir -p "$EXTRA_COPY_PATH"
    cp "$OUTPUT_SQL" "$EXTRA_COPY_PATH"
    echo "已拷贝到：$EXTRA_COPY_PATH"
}
