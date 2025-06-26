#!/bin/bash

player_names_csv_file="src/player_names_test.csv"

temp_sql_str="INSERT INTO playerbots_names VALUES "

index=0
while IFS=',' read -r col1
do
  # 处理引号包围的字段
  name=$(echo ${col1} | tr -d '\r\n' | cut -d , -f 1) 
  temp_sql_str="${temp_sql_str} (${index}, '${name}', $(( $RANDOM % 2 ))), "
  index=$((index+1))
done < "$player_names_csv_file"

echo ${temp_sql_str%??} > tmp.sql
temp_sql_str="${temp_sql_str};"
# docker cp tmp.sql ac-database:/tmp/tmp.sql
docker exec ac-database mysql -u root -ppassword acore_characters < test.sql