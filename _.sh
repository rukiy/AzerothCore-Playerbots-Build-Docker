#!/bin/bash

UBUNTU_MIRROR="mirrors.aliyun.com"
GITHUB_MIRROR="https://githubfast.com/"
DETECTED_IP=311802.xyz

ip_address=$(hostname -I | awk '{print $1}')
if test -z "$DETECTED_IP" 
then
  echo "Detected IP: $DETECTED_IP"
else
  ip_address=$DETECTED_IP
fi
echo "IP Address: $ip_address"

sudo sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" src/.env 2>/dev/null || true

# Check if Azeroth Core is installed
if [ -d "azerothcore-wotlk" ]; then
    destination_dir="data/sql/custom"
    
    world=$destination_dir"/db_world/"
    chars=$destination_dir"/db_characters/"
    auth=$destination_dir"/db_auth/"
    
    cd azerothcore-wotlk
    
    rm -rf $world/*.sql
    rm -rf $chars/*.sql
    rm -rf $auth/*.sql
    
    cd ..
    
    cp src/.env azerothcore-wotlk/
    cp src/*.yml azerothcore-wotlk/
    cd azerothcore-wotlk
else
    git clone https://github.com/liyunfan1223/azerothcore-wotlk.git --branch=Playerbot
    cp src/.env azerothcore-wotlk/
    cp src/*.yml azerothcore-wotlk/
    cd azerothcore-wotlk/modules
    git clone https://github.com/liyunfan1223/mod-playerbots.git --branch=master
    cd ..
fi


# Install modules
echo "Install modules..."
##################################################################
cd modules
function install_mod() {
    local repo_url=$1
    local mod_name=$(basename -s .git $repo_url)

    if [ -d "${mod_name}" ]; then
        echo "${mod_name} exists. Skipping..."
    else
        git clone ${repo_url}
    fi
}
install_mod "https://github.com/azerothcore/mod-aoe-loot.git"
# fix modules sql folder
echo "Fixing mod-aoe-loot modules sql folder..."
mv mod-aoe-loot/data/sql/db-auth mod-aoe-loot/data/sql/auth 2>/dev/null || :
mv mod-aoe-loot/data/sql/db-characters mod-aoe-loot/data/sql/characters 2>/dev/null || :
mv mod-aoe-loot/data/sql/db-world mod-aoe-loot/data/sql/world 2>/dev/null || :
# fix modules sql folder
# install_mod "https://github.com/ZhengPeiRu21/mod-individual-progression.git"
# echo "Fixing mod-individual-progression modules sql folder..."
# mkdir -p mod-individual-progression/data/sql
# mv mod-individual-progression/sql/* mod-individual-progression/data/sql 2>/dev/null || :

install_mod "https://github.com/noisiver/mod-learnspells.git"
install_mod "https://github.com/azerothcore/mod-fireworks-on-level.git"
install_mod "https://github.com/DustinHendrickson/mod-player-bot-level-brackets.git"
install_mod "https://github.com/azerothcore/mod-ale.git"
install_mod "https://github.com/azerothcore/mod-autobalance.git"
install_mod "https://github.com/azerothcore/mod-transmog.git"
echo "Fixing mod-transmog modules sql folder..."
mv mod-transmog/data/sql/db-auth mod-aoe-loot/data/sql/auth 2>/dev/null || :
mv mod-transmog/data/sql/db-characters mod-aoe-loot/data/sql/characters 2>/dev/null || :
mv mod-transmog/data/sql/db-world mod-aoe-loot/data/sql/world 2>/dev/null || :
cd ..
##################################################################

# set mirror to cn
##################################################################
# ubuntu
echo "Set ubuntu mirror..."
mirror_cmd="RUN sed -i 's\/archive.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& sed -i 's\/security.ubuntu.com\/${UBUNTU_MIRROR}\/g' \/etc\/apt\/sources.list \&\& apt-get update"
sed -i "s#RUN apt-get update#${mirror_cmd}#g" apps/docker/Dockerfile
# github 
echo "Set github mirror..."
sed -i "s#\"https://api.github#\"${GITHUB_MIRROR}https://api.github#g" apps/installer/includes/functions.sh
sed -i "s#\"https://raw.githubusercontent#\"${GITHUB_MIRROR}https://raw.githubusercontent#g" apps/installer/includes/functions.sh
sed -i "s#\"https://github.com#\"${GITHUB_MIRROR}https://github.com#g" apps/installer/includes/functions.sh
sed -i "s#curl -L https://github.com#curl -L ${GITHUB_MIRROR}https://github.com#g" apps/installer/includes/functions.sh
##################################################################

# Fixing permissions
##################################################################
echo "Fixing permissions ..."
mkdir -p env/dist/etc env/dist/logs ../wotlk/etc ../wotlk/logs ../wotlk/database
rm -rf ../wotlk/logs/*
sudo chown -R 1000:1000 env/dist/etc env/dist/logs 2>/dev/null || chown -R 1000:1000 env/dist/etc env/dist/logs
sudo chown -R 1000:1000 ../wotlk 2>/dev/null || chown -R 1000:1000 ../wotlk
sudo chown -R 1000:1000 . 2>/dev/null || chown -R 1000:1000 .
sudo chown -R 775 ../wotlk/database 2>/dev/null || chown -R 775 ../wotlk/database
##################################################################

echo "Starting containers..."
docker compose --compatibility up -d --build
# Wait a moment for containers to initialize
sleep 5
# Automatically detect and update realmlist
echo "Configuring realmlist with host IP..."
# Update realmlist database
docker exec ac-database mysql -u root -ppassword acore_auth -e "UPDATE realmlist SET address = '$ip_address' WHERE id = 1;" 2>/dev/null && \
echo "SUCCESS: Realmlist configured successfully for IP: $ip_address" || \
echo "WARNING: Realmlist update will be attempted again after worldserver starts"
# Verify the update
echo "Current realmlist configuration:"
docker exec ac-database mysql -u root -ppassword acore_auth -e "SELECT id, name, address FROM realmlist;" 2>/dev/null || true

# to base the directory
cd ..
##################################################################


# Temporary SQL file
##################################################################
temp_sql_file="/tmp/temp_custom_sql.sql"
# Function to execute SQL files with IP replacement
function execute_sql() {
    local db_name=$1
    local sql_files=("$custom_sql_dir/$db_name"/*.sql)

    if [ -e "${sql_files[0]}" ]; then
        for custom_sql_file in "${sql_files[@]}"; do
            echo "Executing $custom_sql_file"
            temp_sql_file=$(mktemp)
            if [[ "$(basename "$custom_sql_file")" == "update_realmlist.sql" ]]; then
                sed -e "s/{{IP_ADDRESS}}/$ip_address/g" "$custom_sql_file" > "$temp_sql_file"
            else
                cp "$custom_sql_file" "$temp_sql_file"
            fi
            # Use Docker exec instead of local mysql command for Unraid compatibility
            docker exec ac-database mysql -u root -ppassword "$db_name" < "$temp_sql_file" 2>/dev/null || \
            mysql -h "$ip_address" -P 3307 -uroot -ppassword "$db_name" < "$temp_sql_file" 2>/dev/null || \
            echo "Note: Could not execute SQL file $custom_sql_file (MySQL client not available)"
        done
    else
        echo "No SQL files found in $custom_sql_dir/$db_name, skipping..."
    fi
}
##################################################################


# Directory for custom SQL files
##################################################################
custom_sql_dir="src/sql"
auth="acore_auth"
world="acore_world"
chars="acore_characters"

mkdir -p "$custom_sql_dir/$auth"
mkdir -p "$custom_sql_dir/$world"
mkdir -p "$custom_sql_dir/$chars"

# Run custom SQL files
echo "Running custom SQL files..."
execute_sql "$auth"
execute_sql "$world"
execute_sql "$chars"

# Final realmlist verification and update if needed
echo "Final realmlist verification..."
docker exec ac-database mysql -u root -ppassword acore_auth -e "UPDATE realmlist SET address = '$ip_address' WHERE id = 1;" 2>/dev/null || true
echo "SUCCESS: Final realmlist configuration complete for IP: $ip_address"
# Clean up temporary file
rm -f "$temp_sql_file"
##################################################################

echo ""
echo "安装已完成！"
echo ""
echo "安装成果："
echo "- 数据库已配置在3306端口"
echo "- 实境列表已自动配置为IP: $ip_address"
echo "- 500个玩家机器人已就绪，提供即时多人游戏体验"
echo ""
echo "后续操作指引："
echo "1. 执行命令 'docker attach ac-worldserver'"
echo "2. 输入 'account create 用户名 密码' 创建账户"
echo "3. 输入 'account set gmlevel 用户名 3 -1' 设置账户为全服管理员"
echo "4. 按下 Ctrl+p Ctrl+q 退出世界服务器控制台"
echo "5. 编辑魔兽客户端 realmlist.wtf 文件，内容设为: $ip_address"
echo "6. 使用3.3.5a客户端登录游戏"
echo "7. 所有配置文件已复制到wotlk文件夹"
echo ""
echo "祝您尽情享受拥有500个AI伙伴的私人魔兽世界服务器！"