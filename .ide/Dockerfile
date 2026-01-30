# .ide/Dockerfile
# 可根据需要指定基础镜像
FROM debian:13

# 设置软件源(apt-get 源)
RUN sed -Ei "s/(deb|security).debian.org/mirrors.cloud.tencent.com/g" /etc/apt/sources.list.d/debian.sources
# 1 安装 ssh 服务，用于支持 VSCode 客户端通过 Remote-SSH 访问开发环境
# 2 安装常用工具软件, 如 git, wget, unzip
RUN apt-get update \
    && apt-get upgrade -y \
    && echo "Asia/Shanghai" >/etc/timezone \
    && apt-get install -y curl jq wget unzip git openssh-server \
    && apt-get autoclean \
    && apt-get clean \
    && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf  /var/log/*.log \
    && rm -rf  /var/cache/apt/* \
    && echo "安装初始工具完毕"

# 复制 vscode 自定义到容器中
COPY .ide/settings.json /root/.local/share/code-server/User/settings.json
COPY .ide/settings.json /root/.local/share/code-server/Machine/settings.json

# 安装 code-server 和 vscode 常用插件
RUN curl -fsSL https://code-server.dev/install.sh | sh \
  && code-server --install-extension dracula-theme.theme-dracula \
  && code-server --install-extension ms-ceintl.vscode-language-pack-zh-hans \
  && code-server --install-extension njzy.stats-bar \
  && code-server --install-extension redhat.vscode-yaml \
  && code-server --install-extension ms-azuretools.vscode-docker \
  && code-server --install-extension cloudstudio.live-server \
  && echo "扩展安装完毕"

# 生成中文插件必要的配置文件
COPY .ide/create_languagepacks /tmp/create_languagepacks 
RUN chmod +x /tmp/create_languagepacks  \
    && /tmp/create_languagepacks \
    && rm -f /tmp/create_languagepacks \
    && echo "切换为中文完毕"

# 指定字符集支持命令行输入中文（根据需要选择字符集）
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8