# 服务端交流论坛分享帖实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 生成一篇可直接发布到服务端交流论坛的真实分享型中文帖子。

**Architecture:** 新建独立 Markdown 文档承载论坛成稿，不修改 README 和安装脚本。帖子采用普通玩家第一人称，以使用感受串联硬件要求、安装命令、模块、安装后操作和风险提醒，所有事实从当前 README 与配置文件核对。

**Tech Stack:** Markdown、PowerShell、Git

---

### Task 1: 撰写论坛成稿

**Files:**
- Create: `docs/forum-sharing-post.md`
- Reference: `README.md`
- Reference: `ac.conf`

- [x] **Step 1: 创建成稿文档**

文档使用以下固定结构：

```markdown
# 标题

开场：不懂 Docker 和编译的普通玩家为什么想搭建带 Playerbots 的自用服。

## 为什么选择这个项目
说明项目自动处理源码、模块、客户端数据、数据库、Docker 构建和国内网络加速。

## 准备条件
列出支持的 Linux 版本、root、Docker Compose v2、Buildx 和内存建议。

## 一键安装
给出 GitHub 原站命令与一个国内加速命令。

## 默认模块
以普通用户能感知的功能概括 12 个模块。

## 安装完成后
给出创建账号、配置 realmlist 和常用管理命令。

## 使用感受和注意事项
说明优点、构建耗时不固定、低内存风险、安装目录限制和第三方代理风险。

## 项目地址
给出 GitHub 仓库地址并邀请交流。
```

- [x] **Step 2: 保证命令可直接复制**

原站安装命令：

```bash
bash <(curl -fsSL https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker/raw/main/install.sh)
```

国内加速命令：

```bash
bash <(curl -fsSL 'https://gh-proxy.com/https://raw.githubusercontent.com/rukiy/AzerothCore-Playerbots-Build-Docker/main/install.sh')
```

- [x] **Step 3: 检查普通用户口吻**

确认正文使用第一人称，避免“架构、流水线、资源编排”等开发者表达；不得声称具体安装耗时、性能或不存在的亲身故障。

### Task 2: 核对事实和格式

**Files:**
- Verify: `docs/forum-sharing-post.md`
- Reference: `README.md`
- Reference: `ac.conf`

- [x] **Step 1: 检查文档格式**

Run:

```powershell
git diff --check
```

Expected: 命令退出码为 0，没有空白错误。

- [x] **Step 2: 检查关键事实**

Run:

```powershell
$text = Get-Content -Raw -Encoding UTF8 docs/forum-sharing-post.md
@('4GB', '8GB', '12GB～16GB', '500 个', 'mod-playerbots', './ac.sh update', './ac.sh toggle', '第三方代理') | ForEach-Object {
    if (-not $text.Contains($_)) { throw "缺失关键内容: $_" }
}
```

Expected: 命令退出码为 0，没有缺失提示。

- [x] **Step 3: 检查模块覆盖**

从 `ac.conf` 提取 `ACORE_MODULE_REPOS` 中的 12 个仓库名，确认每个仓库名都出现在成稿中。

### Task 3: 提交并同步

**Files:**
- Add: `docs/forum-sharing-post.md`
- Add: `docs/superpowers/plans/2026-07-14-forum-sharing-post.md`

- [ ] **Step 1: 提交文档**

Run:

```powershell
git add -- docs/forum-sharing-post.md docs/superpowers/plans/2026-07-14-forum-sharing-post.md
git -c user.name='Rukiy' -c user.email='leaftea@qq.com' commit -m 'docs: 增加论坛项目分享帖'
```

Expected: 提交成功，作者为 `Rukiy <leaftea@qq.com>`。

- [ ] **Step 2: 推送 main**

Run:

```powershell
git push origin main
```

Expected: CNB `main` 更新，并触发 GitHub 同步流水线。

- [ ] **Step 3: 验证 GitHub 同步**

Run:

```powershell
git ls-remote https://github.com/rukiy/AzerothCore-Playerbots-Build-Docker.git refs/heads/main
```

Expected: GitHub `main` 提交与本地 `HEAD` 一致。
