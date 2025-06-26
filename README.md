# AzerothCore 带玩家机器人模块的 Docker 部署方案（安装脚本）

用于在 Docker 上安装 AzerothCore 及玩家机器人模块的脚本

> 注意：这不是一个分支！这只是管理游戏的脚本

包含内容：
- [MariaDB 客户端](https://mariadb.com)（仅当未安装 `mysql` 命令时才会安装）
- [Docker](https://docker.com)（若未安装 Docker 则自动安装）
- [Azeroth Core - Playerbots分支](https://github.com/liyunfan1223/azerothcore-wotlk.git)
- [mod-playerbots](https://github.com/liyunfan1223/mod-playerbots)
- [mod-aoe-loot](https://github.com/azerothcore/mod-aoe-loot)（可选）
- [mod-learn-spells](https://github.com/noisiver/mod-learn-spells)（可选）
- [mod-fireworks-on-level](https://github.com/azerothcore/mod-fireworks-on-level.git)（可选）
- [mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression.git)（可选）

前置要求：
  1. Debian 12 Bookworm 系统

参考资料：
[Azeroth Core 官方文档](https://www.azerothcore.org/wiki/home)

---

### 安装步骤：

1.
> 开始前请确保已正确设置 Debian 系统时区
```bash
git clone https://github.com/rukiy/AzerothCore-with-Playerbots-Docker-Setup.git \
&& cd AzerothCore-with-Playerbots-Docker-Setup && chmod +x *.sh && ./setup.sh
```


2. 
```
注意：

1. 执行 'docker attach ac-worldserver'
2. 'account create username password' 创建一个账户。
3. 'account set gmlevel username 3 -1' 将账户设置为所有服务器的GM。
4. Ctrl+p Ctrl+q 将退出世界控制台。
5. 现在可以通过 $(hostname -I | awk '{print $1}') 使用 3.3.5a 客户端登录 WoW！
6. 所有服务器和模块的配置文件都复制到名为 wotlk 的文件夹中。这是您编辑玩家机器人和服务器配置的地方。
```

3.

```shell
AC> account create username password
AC> account set gmlevel username 3 -1
```

4.
编辑您的 wow_client_3.3.5a\Data\enUS\realmlist.wtf 文件并输入安装结束时显示的 IP 地址...
`set realmlist dockerhost_ip`

**将 dockerhost_ip 替换为运行 Docker 容器的机器 IP**

要卸载并重新开始，请运行 `./uninstall.sh`

要清除 `data/sql/custom` 文件夹，请运行 `./clear_custom_sql.sh`

## 使用说明

### 更新操作

- 要更新到最新版本，可以运行 `./uninstall.sh` 不删除数据卷后再次运行 `./setup.sh`.
系统会提示您是否要删除数据卷。（不用担心警告信息）

- 您可以通过滚动到 `setup.sh` 文件的 "install_mod" 部分添加条目来添加模块。或者手动将模块文件夹放入 `azerothcore-wotlk/modules` 文件夹进行安装。`setup.sh` 会自动添加 SQL 文件。更多信息请参阅 如何安装模块?

- 运行 `setup.sh` 不会重复安装已有内容，除非您事先删除了模块文件夹或 `azerothcore-wotlk` 文件夹。您可以仅运行该脚本来安装新增的模块，如果已经下载过相关仓库，脚本会自动跳过。

- 如果您删除了模块，请记得先运行 `clear_custom_sql.sh` 并从数据库中删除相应的表。

### 备份与恢复

- 通过运行 `./sqldump.sh` 可以备份和恢复数据库。备份文件将保存在 `sql_dumps` 文件夹中... 恢复时，系统会提示您输入日期（假设每天最多进行一次备份）。

---                                                                                                             
