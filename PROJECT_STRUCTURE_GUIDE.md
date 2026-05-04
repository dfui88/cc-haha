# 项目目录结构与说明

> Claude Code Haha — 基于 Anthropic Claude Code CLI 的桌面端 AI 聊天客户端
>
> 技术栈：**Tauri 2.x + React 19 + Bun 1.x + Rust** | 四层架构：原生壳 / React 前端 / Bun 后端 / Python 运行时

---

## 根目录

| 路径 | 说明 |
|------|------|
| `src/` | **Bun 后端核心** — CLI、服务器、工具链、AI 编排 |
| `desktop/` | **Tauri 桌面端** — Rust 原生壳 + React 前端 |
| `adapters/` | **IM 平台适配器** — Telegram / 飞书消息通道 |
| `runtime/` | **Python 运行时助手** — 键盘模拟、屏幕捕获、Win32 API |
| `fixtures/` | 测试夹具与测试数据 |
| `stubs/` | 桩模块 / 模拟实现 |
| `docs/` | VitePress 文档站点 |
| `bin/` | CLI 启动入口 (`claude-haha`) |
| `scripts/` | 构建与工具脚本 |
| `release-notes/` | 发布说明 |
| `reports/` | 分析报告 (git-ignored) |

### 根配置文件

| 文件 | 说明 |
|------|------|
| `package.json` | 项目 `claude-code-local` — 主包配置、启动入口 |
| `bun.lock` | Bun 锁定文件 |
| `tsconfig.json` | TypeScript 根配置 |
| `CLAUDE.md` | Claude Code 项目指令（含构建规则 8 条） |
| `.env.example` | 环境变量示例 |
| `ARCHITECTURE.md` | 架构文档 |
| `CHANGELOG.md` | 变更日志 |
| `PROJECT_OVERVIEW.md` | 项目概览 |
| `PROJECT_ARCHITECTURE.md` | 项目架构详细说明 |
| `PROJECT_STRUCTURE.md` | 目录结构总览 |
| `AGENTS.md` | 代理编排说明 |

---

## `src/` — Bun 后端核心

主后端代码，负责 CLI 交互、服务器、AI 模型编排、工具执行等。

### 入口与启动

| 路径 | 说明 |
|------|------|
| `src/entrypoints/` | 应用入口点 — `cli.ts`、`daemon.ts` 等启动逻辑 |
| `src/bootstrap/` | 启动引导 — 环境检测、初始化、配置加载 |
| `src/daemon/` | 守护进程管理 — 后台服务生命周期 |

### CLI 层

| 路径 | 说明 |
|------|------|
| `src/cli/` | **CLI 核心** — 命令解析、输出格式化、终端交互 |
| `src/cli/handlers/` | CLI 命令处理函数 |
| `src/cli/transports/` | CLI 传输层（stdio / ndjson / 结构化 IO） |
| `src/cli/print.ts` | 终端打印格式化 |
| `src/cli/structuredIO.ts` | 结构化输入输出 |
| `src/cli/ndjsonSafeStringify.ts` | NDJSON 安全序列化 |
| `src/cli/remoteIO.ts` | 远程 IO 支持 |
| `src/cli/update.ts` | 自动更新逻辑 |

### 服务器层

| 路径 | 说明 |
|------|------|
| `src/server/` | **HTTP 服务器** — REST + WebSocket 服务端 |
| `src/server/api/` | REST API 路由与处理 |
| `src/server/ws/` | WebSocket 连接管理与消息分发 |
| `src/server/middleware/` | 中间件（鉴权、日志、限流等） |
| `src/server/services/` | 业务服务层 |
| `src/server/backends/` | AI 后端适配（Anthropic / OpenAI / Bedrock 等） |
| `src/server/config/` | 服务器配置 |
| `src/server/types/` | 类型定义 |
| `src/server/router.ts` | 路由注册 |
| `src/server/server.ts` | 服务器主逻辑 |
| `src/server/sessionManager.ts` | 会话管理 |
| `src/server/connectHeadless.ts` | 无头模式连接 |
| `src/server/proxy/` | 代理配置 |
| `src/server/lockfile.ts` | 锁文件管理 |

### AI 编排与工具

| 路径 | 说明 |
|------|------|
| `src/assistant/` | **AI 助手核心** — 对话管理、上下文窗口、工具调度 |
| `src/tools/` | **工具系统** — 各种工具实现（文件、终端、搜索等） |
| `src/commands/` | 内置命令实现 (`/help`, `/clear` 等) |
| `src/coordinator/` | 多 Agent 协调器 — 群组对话与分工 |
| `src/swarm/` | **Swarm 多 Agent 模式** — 并行/串行 Agent 编排 |
| `src/swarm/backends/` | Swarm 后端适配 |

### 状态与服务

| 路径 | 说明 |
|------|------|
| `src/state/` | 状态管理 — 会话状态、配置状态 |
| `src/services/` | 通用服务层 |
| `src/jobs/` | 后台任务 / 定时作业 |
| `src/tasks/` | 任务管理（Todo/Task 跟踪） |
| `src/proactive/` | 主动行为引擎（AI 主动提议） |
| `src/query/` | 查询与检索逻辑 |

### 通信与桥接

| 路径 | 说明 |
|------|------|
| `src/bridge/` | 桥接层 — 前后端 IPC 通信 |
| `src/remote/` | 远程连接管理 |
| `src/upstreamproxy/` | 上游代理配置 |
| `src/context/` | React Context 提供者 |

### 用户界面（Ink/终端）

| 路径 | 说明 |
|------|------|
| `src/ink/` | **Ink React 终端渲染** — 终端 UI 组件 |
| `src/components/` | 终端 UI 组件集合 |
| `src/screens/` | 终端屏幕布局 |
| `src/outputStyles/` | 输出样式格式化 |
| `src/keybindings/` | 快捷键绑定 |
| `src/vim/` | Vim 模式支持 |
| `src/voice/` | 语音输入支持 |
| `src/terminal-*` | 终端相关模块 |

### 工具函数库 (`src/utils/`)

| 路径 | 说明 |
|------|------|
| `src/utils/settings/` | 设置管理（含 MDM 配置） |
| `src/utils/settings/mdm/` | MDM 企业策略配置 |
| `src/utils/permissions/` | 权限管理（含 YOLO 分类器） |
| `src/utils/sandbox/` | 沙箱执行环境 |
| `src/utils/shell/` | Shell 命令执行 |
| `src/utils/bash/` | Bash 工具实现 |
| `src/utils/mcp/` | **MCP (Model Context Protocol)** — 外部工具协议 |
| `src/utils/memory/` | 记忆系统（持久化记忆） |
| `src/utils/skills/` | 技能系统管理 |
| `src/utils/plugins/` | 插件加载与管理 |
| `src/utils/files/` | 文件操作工具 |
| `src/utils/telemetry/` | 遥测与使用统计 |
| `src/utils/secureStorage/` | 安全存储（密钥、令牌） |
| `src/utils/github/` | GitHub API 集成 |
| `src/utils/git/` | Git 操作工具 |
| `src/utils/mcp/` | MCP 协议实现 |
| `src/utils/suggestions/` | 命令建议引擎 |
| `src/utils/todo/` | Todo 管理工具 |
| `src/utils/task/` | 任务管理工具 |
| `src/utils/ultraplan/` | 超规划模式 |
| `src/utils/swarm/` | Swarm 模式工具 |
| `src/utils/dxt/` | 开发者体验工具 |
| `src/utils/model/` | 模型选择与管理 |
| `src/utils/messages/` | 消息处理工具 |
| `src/utils/hooks/` | React Hooks 工具 |
| `src/utils/claudeInChrome/` | Chrome 内 Claude 集成 |
| `src/utils/nativeInstaller/` | 原生安装器工具 |
| `src/utils/background/` | 后台任务工具 |
| `src/utils/deepLink/` | 深度链接处理 |
| `src/utils/powershell/` | PowerShell 集成 |
| `src/utils/processUserInput/` | 用户输入预处理 |
| `src/utils/computerUse/` | 计算机使用（屏幕/鼠标/键盘） |
| `src/utils/filePersistence/` | 文件持久化 |
| `src/utils/teleport/` | Teleport 远程能力 |
| `src/__tests__/` | 后端单元测试 |

### 其他

| 路径 | 说明 |
|------|------|
| `src/types/` | TypeScript 类型定义 |
| `src/constants/` | 全局常量 |
| `src/schemas/` | 数据模式定义（Zod 等） |
| `src/self-hosted-runner/` | 自托管运行器 |
| `src/environment-runner/` | 环境运行器 |
| `src/fixtures/` | 测试夹具 |
| `src/migrations/` | 数据迁移 |
| `src/moreright/` | MoreRight 集成 |
| `src/buddy/` | CodeBuddy 集成 |
| `src/native-ts/` | 原生 TypeScript 模块 |
| `src/ssh/` | SSH 连接支持 |
| `src/vendor/` | 第三方供应商代码 |
| `src/vendor/computer-use-mcp/` | Computer Use MCP 供应商代码 |
| `src/memdir/` | 记忆目录管理 |

---

## `desktop/` — Tauri 桌面端

### `desktop/src-tauri/` — Rust 原生壳

| 路径 / 文件 | 说明 |
|-------------|------|
| `desktop/src-tauri/src/main.rs` | Tauri 应用入口 |
| `desktop/src-tauri/src/lib.rs` | Tauri 核心库 — 窗口管理、命令注册、菜单 |
| `desktop/src-tauri/src/deploy.rs` | 自动更新与部署逻辑 |
| `desktop/src-tauri/Cargo.toml` | Rust 依赖配置 |
| `desktop/src-tauri/tauri.conf.json` | Tauri 应用配置（窗口大小、标识、bundle） |
| `desktop/src-tauri/capabilities/` | Tauri 权限能力声明 |
| `desktop/src-tauri/icons/` | 应用图标（含 Android / iOS） |
| `desktop/src-tauri/gen/` | Tauri 生成代码 |
| `desktop/src-tauri/bundled/` | 打包资源（含 Claude bundled CLI） |
| `desktop/src-tauri/binaries/` | 二进制 sidecar 文件 |

### `desktop/src/` — React 前端

| 路径 | 说明 |
|------|------|
| `desktop/src/pages/` | **页面组件** — 主页面布局 |
| `desktop/src/components/chat/` | **聊天组件** — 消息列表、输入框、对话气泡 |
| `desktop/src/components/controls/` | **控制组件** — 按钮、开关、滑块等 UI 控件 |
| `desktop/src/components/layout/` | **布局组件** — 侧栏、顶栏、面板容器 |
| `desktop/src/components/markdown/` | **Markdown 渲染** — 代码高亮、数学公式、Mermaid 图表 |
| `desktop/src/components/plugins/` | 插件管理 UI |
| `desktop/src/components/settings/` | 设置面板 UI |
| `desktop/src/components/shared/` | 共享 UI 组件 |
| `desktop/src/components/skills/` | 技能管理 UI |
| `desktop/src/components/tasks/` | 任务管理 UI |
| `desktop/src/components/teams/` | 团队协作 UI |
| `desktop/src/stores/` | **Zustand 状态管理** — 聊天、设置、配置等 store |
| `desktop/src/api/` | API 客户端 — 与后端通信 |
| `desktop/src/hooks/` | 自定义 React Hooks |
| `desktop/src/lib/` | 工具函数库 |
| `desktop/src/theme/` | 主题配置（亮/暗模式） |
| `desktop/src/i18n/` | 国际化支持 |
| `desktop/src/i18n/locales/` | 多语言翻译文件 |
| `desktop/src/config/` | 前端配置 |
| `desktop/src/constants/` | 前端常量 |
| `desktop/src/types/` | TypeScript 类型定义 |
| `desktop/src/mocks/` | 模拟数据（开发和测试用） |
| `desktop/src/__tests__/` | 前端测试 |

### 桌面构建与产出

| 路径 | 说明 |
|------|------|
| `desktop/scripts/` | 构建脚本（`build-windows-x64.ps1` 等） |
| `desktop/sidecars/` | Sidecar 进程 |
| `desktop/dist/` | Vite 构建产出 |
| `desktop/build-artifacts/` | 构建产物（安装包） |
| `desktop/build-artifacts/windows-x64/` | Windows x64 构建产物 |
| `desktop/public/` | 静态资源（字体、图标） |

---

## `adapters/` — IM 平台适配器

| 路径 | 说明 |
|------|------|
| `adapters/common/` | **适配器公共层** — 共享接口、配置、工具函数 |
| `adapters/common/attachment/` | 附件处理（限制、存储、类型、图片监视） |
| `adapters/common/chat-queue.ts` | 聊天消息队列 |
| `adapters/common/config.ts` | 适配器配置 |
| `adapters/common/format.ts` | 格式化工具 |
| `adapters/common/http-client.ts` | HTTP 客户端封装 |
| `adapters/common/im-helpers.ts` | IM 辅助函数 |
| `adapters/common/message-buffer.ts` | 消息缓冲 |
| `adapters/common/message-dedup.ts` | 消息去重 |
| `adapters/common/pairing.ts` | 配对逻辑 |
| `adapters/common/session-store.ts` | 会话存储 |
| `adapters/common/ws-bridge.ts` | WebSocket 桥接 |
| `adapters/feishu/` | **飞书适配器** — 飞书机器人、卡片消息、流式渲染 |
| `adapters/feishu/cardkit.ts` | 飞书卡片构建器 |
| `adapters/feishu/streaming-card.ts` | 流式卡片更新 |
| `adapters/feishu/extract-payload.ts` | 消息载荷提取 |
| `adapters/feishu/markdown-style.ts` | Markdown 样式转换 |
| `adapters/feishu/media.ts` | 媒体消息处理 |
| `adapters/feishu/flush-controller.ts` | 刷新控制 |
| `adapters/feishu/card-errors.ts` | 卡片错误处理 |
| `adapters/telegram/` | **Telegram 适配器** — Telegram 机器人 |
| `adapters/telegram/media.ts` | 媒体处理 |
| `adapters/telegram/__tests__/` | 适配器测试 |

---

## `runtime/` — Python 运行时助手

| 路径 / 文件 | 说明 |
|-------------|------|
| `runtime/` | 键盘模拟、屏幕捕获、Win32 API 调用等系统级操作 |

---

## `docs/` — 文档站点 (VitePress)

| 路径 | 说明 |
|------|------|
| `docs/.vitepress/` | VitePress 配置与主题 |
| `docs/agent/` | Agent 相关文档 |
| `docs/channel/` | 渠道（Telegram/飞书）集成文档 |
| `docs/desktop/` | 桌面端文档 |
| `docs/en/` | 英文文档 |
| `docs/architecture/` | 架构文档 |

---

## 关键配置文件速查

| 文件 | 作用 |
|------|------|
| `package.json` | 主包 `claude-code-local` v999.0.0-local |
| `desktop/package.json` | 桌面端 `claude-code-desktop` v0.1.50 |
| `adapters/package.json` | 适配器 `claude-code-im-adapters` v0.1.0 |
| `desktop/src-tauri/Cargo.toml` | Rust 依赖与构建配置 |
| `desktop/src-tauri/tauri.conf.json` | Tauri 应用标识、窗口、bundle 配置 |
| `tsconfig.json` | TypeScript 编译配置 |
| `bun.lock` | Bun 依赖锁定 |

---

## 核心调用流程

```
用户输入 (React UI)
  → desktop/src/api/ (HTTP/WebSocket)
  → src/server/ (Bun HTTP Server)
  → src/server/ws/ (WebSocket 消息分发)
  → src/assistant/ (AI 助手编排)
  → src/tools/ (工具执行) / src/cli/ (CLI 回显)
  → 流式响应 → WebSocket → React 逐块渲染
```

```
IM 消息 (Telegram / 飞书)
  → adapters/ (IM 适配器)
  → adapters/common/ws-bridge.ts (WebSocket 桥接)
  → src/server/ (Bun 后端处理)
  → ...同上 AI 编排链路...
```
