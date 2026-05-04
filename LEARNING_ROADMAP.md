# 项目拆解学习路线图

> Claude Code Haha — 从零开始掌握这个 Tauri + React + Bun + Rust 四层架构的 AI 聊天桌面应用

---

## 建议学习方式

- **边读边动手** — 每个阶段都打开实际代码对照阅读，别只看文档
- **先宏观再微观** — 先理解数据怎么流动的，再看具体实现
- **做笔记** — 画自己的数据流图，比反复读文档有效
- **按层拆解** — 别同时啃 Rust、React、Bun 三端代码，按阶段来

---

## 前置知识要求

| 知识 | 必要程度 | 用途 |
|------|----------|------|
| TypeScript 基础 | 必备 | 前后端都是 TS |
| React 基础 (hooks + 组件) | 必备 | 前端 UI |
| HTTP / WebSocket 概念 | 必备 | 前后端通信 |
| 命令行操作 | 必备 | 启动调试 |
| Rust 基础语法 | 推荐 | Tauri 壳层 |
| Python 基础 | 了解即可 | 运行时助手 |
| Tauri 概念 | 学习过程中掌握 | 原生壳层 |

---

## 学习阶段总览

```
Phase 0: 环境搭建     ─ 1 天  ─  跑起来再说
Phase 1: 宏观理解     ─ 1-2 天 ─  项目骨架与数据流
Phase 2: 前端拆解     ─ 2-3 天 ─  React 桌面 UI
Phase 3: 后端拆解     ─ 3-4 天 ─  Bun 服务与 AI 编排
Phase 4: 原生壳 + 构建 ─ 2-3 天 ─  Rust / Tauri / 打包
Phase 5: 适配器 + 运行时 ─ 1-2 天 ─  IM 通道 / Python 助手
Phase 6: 全局串联     ─ 1-2 天 ─  贯通全链路 + 动手改代码
─────────────────────────────────────
总计约: 11-17 天
```

---

## Phase 0 — 环境搭建（1 天）

目标：能在本地启动项目，观察运行状态。

### 检查工具链

```bash
node --version    # ≥ 18
bun --version     # ≥ 1.0
rustc --version   # ≥ 1.80
cargo --version
python --version  # ≥ 3.10
```

### 读取关键文档

| 文档 | 内容 |
|------|------|
| `CLAUDE.md` | 项目指令、构建规则 8 条、PS 注意事项 |
| `package.json` | 主包入口、脚本命令 |
| `desktop/package.json` | 桌面端依赖、构建命令 |
| `desktop/src-tauri/tauri.conf.json` | Tauri 窗口、应用标识、bundle 配置 |
| `.env.example` | 环境变量（API Key 等） |

### 启动与验证

```bash
# 1. 安装依赖
bun install
cd desktop && bun install && cd ..

# 2. 开发模式启动
cd desktop
bun run tauri dev

# 3. 观察输出
#  - Tauri Rust 编译
#  - sidecar 进程启动
#  - WebView 窗口弹出
#  - 后端 HTTP/WS 服务就绪
```

### 产出物

- [ ] 能在本地启动开发模式
- [ ] 能看到桌面窗口
- [ ] 了解如何停止/重启

---

## Phase 1 — 宏观理解（1-2 天）

目标：理解项目的四层架构和核心数据流，不需要深究每行代码。

### 1.1 读架构文档

| 文档 | 重点 |
|------|------|
| `ARCHITECTURE.md` | **必读** — 整体架构、启动流程、核心数据流、Proxy 转换、REST API 端点 |
| `PROJECT_OVERVIEW.md` | **必读** — 四层总览、工作流、状态管理 |
| `PROJECT_STRUCTURE_GUIDE.md` | 目录树与模块说明 |

### 1.2 理清进程关系

```
Tauri 主进程 (claude-code-desktop.exe)
  ├── 子进程: claude-sidecar.exe (Bun HTTP/WS 服务器)
  │     └── 子进程: Python 脚本 (按需)
  └── WebView 渲染进程 (React 前端)
```

理解三个问题：
1. **Tauri 怎么启动 sidecar 的？** → 看 `desktop/src-tauri/src/lib.rs`
2. **前后端怎么通信的？** → HTTP REST (127.0.0.1:3456) + WebSocket
3. **消息怎么到达 AI 的？** → React → HTTP Proxy → AI Provider

### 1.3 追踪一个完整请求（纸上画图）

```
你打字 → React ChatInput → chatStore.sendMessage()
  → HTTP POST /api/proxy → sidecar 服务器
  → Proxy 转换层 (Anthropic格式 ↔ OpenAI格式)
  → AI Provider API → 流式响应
  → WebSocket /ws → 前端逐块渲染
```

### 产出物

- [ ] 能口述四层架构和各自职责
- [ ] 理解进程关系图
- [ ] 理解一条消息从输入到输出的完整路径
- [ ] 知道 REST API 有哪些端点
- [ ] 知道 Zustand 各 Store 的职责

---

## Phase 2 — 前端拆解（2-3 天）

目标：掌握 React 桌面端的前端架构。

### 2.1 入口与初始化

**重点文件：** `desktop/src/main.tsx` → `desktop/src/App.tsx`
- React 入口、i18n 初始化、主题初始化
- Tab 恢复、Session 拉取、WebSocket 连接建立

**速通问题：**
- 启动时前端做了什么？
- i18n 怎么确定语言的？
- 标签页怎么恢复的？

### 2.2 组件树结构

| 模块 | 路径 | 重点组件 |
|------|------|----------|
| 布局 | `desktop/src/components/layout/` | 侧边栏、标签栏、主面板 |
| 聊天 | `desktop/src/components/chat/` | ChatInput、Chat、消息气泡 |
| Markdown | `desktop/src/components/markdown/` | 代码高亮、Mermaid 图表 |
| 设置 | `desktop/src/components/settings/` | 通用/Provider/Agent/MCP/技能 |
| 任务 | `desktop/src/components/tasks/` | 任务管理 UI |
| 共享 | `desktop/src/components/shared/` | 通用 UI 组件 |

**阅读方法：** 打开每个组件目录，看 `index.tsx` 或同名文件，理清 props 和 state。

### 2.3 状态管理 (Zustand)

| Store | 文件 | 核心状态 |
|-------|------|----------|
| chatStore | `desktop/src/stores/chatStore.ts` | 消息列表、流式文本、WebSocket |
| sessionStore | `desktop/src/stores/sessionStore.ts` | 会话 CRUD、活跃会话 |
| tabStore | `desktop/src/stores/tabStore.ts` | 标签页持久化/恢复 |
| settingsStore | `desktop/src/stores/settingsStore.ts` | 设置项、Provider |
| uiStore | `desktop/src/stores/uiStore.ts` | 主题、布局状态 |

**建议：** 重点看 `chatStore.ts`，它是核心枢纽 — 理解 `sendMessage()` 怎么发请求、`onWsMessage()` 怎么处理流式响应。

### 2.4 API 通信层

**重点文件：** `desktop/src/api/`
- 封装的 HTTP 客户端
- WebSocket 连接管理
- 请求/响应拦截

**速通问题：**
- 前端怎么调用后端 API 的？
- WebSocket 连接什么时候建立的？
- 流式渲染怎么实现的？

### 2.5 其他前端模块

| 模块 | 说明 |
|------|------|
| `desktop/src/hooks/` | 自定义 hooks（如 useTranslation） |
| `desktop/src/theme/` | 亮/暗主题配置 |
| `desktop/src/i18n/` | 中英文语言包 |
| `desktop/src/types/` | 类型定义 |
| `desktop/src/lib/` | 工具函数 |

### 产出物

- [ ] 能画出 React 组件树
- [ ] 理解 chatStore 的完整消息流
- [ ] 知道 WebSocket 如何管理连接
- [ ] 知道 i18n 类型安全的实现方式
- [ ] 能描述出一张新会话从创建到显示的流程

---

## Phase 3 — 后端拆解（3-4 天）

目标：掌握 Bun 后端 — 这是项目最复杂的部分。

### 3.1 Server 层

**核心入口：** `src/server/server.ts`
- HTTP 服务器启动、路由注册、中间件
- 理解 `router.ts` 的路由结构

**重点模块：**

| 模块 | 说明 |
|------|------|
| `src/server/api/` | REST API handlers — sessions、settings、diagnostics 等 |
| `src/server/ws/` | WebSocket 消息分发 |
| `src/server/middleware/` | 中间件链 |
| `src/server/services/` | 业务逻辑层 |
| `src/server/backends/` | AI Provider 后端适配 |

**建议：** 优先读 `api/sessions.ts`（会话管理）和 `ws/`（流式通信），这是最常用的路径。

### 3.2 Proxy / AI Provider 层

**核心路径：** `POST /api/proxy` → proxy handler → Provider 转换 → AI API

| 文件/目录 | 说明 |
|-----------|------|
| `src/server/proxy/` | **核心** — 协议转换、请求转发、响应流式解析 |
| `src/server/backends/` | Provider 后端适配 (Anthropic / OpenAI / Bedrock 等) |

**理解三个转换：**
1. `anthropic` 格式 → 直通（不转换）
2. `openai_chat` 格式 → `anthropicToOpenaiChat()` → OpenAI Chat Completions
3. `openai_responses` 格式 → `anthropicToOpenaiResponses()` → OpenAI Responses

### 3.3 CLI 层

| 文件 | 说明 |
|------|------|
| `src/cli/` | CLI 框架、命令处理、输出格式化 |
| `src/cli/transports/` | 传输层 (stdio / ndjson) |
| `src/cli/handlers/` | 命令处理器 |
| `src/cli/structuredIO.ts` | 结构化 IO |

**理解点：** CLI 模式和服务模式的区别、输出格式如何切换。

### 3.4 Assistant / Tools 层

| 路径 | 内容 |
|------|------|
| `src/assistant/` | 对话管理、上下文窗口、工具调度 |
| `src/tools/` | **55+ 工具实现** — 文件读写、终端、搜索、MCP |
| `src/coordinator/` | 多 Agent 协调器 |
| `src/proactive/` | AI 主动建议引擎 |

**建议：** 挑 3-5 个常用工具看源码（文件读写、终端命令、搜索），理解工具注册和执行机制。

### 3.5 关键工具函数

| 模块 | 说明 | 优先级 |
|------|------|--------|
| `src/utils/mcp/` | MCP 协议实现 — 外部工具协议 | **高** |
| `src/utils/memory/` | 持久化记忆系统 | **高** |
| `src/utils/sandbox/` | 沙箱执行环境 | 中 |
| `src/utils/permissions/` | 权限管理 | 中 |
| `src/utils/settings/` | 设置管理 | 中 |
| `src/utils/skills/` | 技能系统 | 中 |
| `src/utils/plugins/` | 插件加载 | 低 |
| `src/utils/shell/` | Shell 命令执行 | 中 |
| `src/utils/bash/` | Bash 工具 | 中 |
| `src/utils/git/` | Git 操作工具 | 低 |
| `src/utils/github/` | GitHub API 集成 | 低 |
| `src/utils/telemetry/` | 遥测统计 | 低 |
| `src/utils/secureStorage/` | 安全存储 | 中 |
| `src/utils/computerUse/` | 计算机使用 (屏幕/鼠标) | 中 |
| 其他（30+ 工具） | 按需查阅 | 低 |

### 3.6 状态管理（后端）

| 模块 | 说明 |
|------|------|
| `src/state/` | 后端状态管理 |
| `src/sessionManager.ts` | 会话管理器 |
| `src/tasks/` | 任务管理 |
| `src/jobs/` | 后台作业 |

### 3.7 测试

| 路径 | 内容 |
|------|------|
| `src/__tests__/` | 后端测试 |
| `src/server/__tests__/` | 服务器测试 |

**理解点：** 测试框架是 Vitest，看几个测试用例了解测试模式。

### 产出物

- [ ] 能画出身处后端请求处理链路
- [ ] 理解 Proxy 三种格式转换
- [ ] 知道工具如何注册和执行
- [ ] 理解 MCP 协议的集成方式
- [ ] 知道记忆系统如何工作

---

## Phase 4 — 原生壳 + 构建（2-3 天）

目标：理解 Tauri 壳层的职责和打包流程。

### 4.1 Rust 壳层

| 文件 | 内容 |
|------|------|
| `desktop/src-tauri/src/main.rs` | Tauri 应用入口 |
| `desktop/src-tauri/src/lib.rs` | **核心** — sidecar 启动、窗口管理、命令注册 |
| `desktop/src-tauri/src/deploy.rs` | 自动更新逻辑 |
| `desktop/src-tauri/Cargo.toml` | Rust 依赖 |
| `desktop/src-tauri/tauri.conf.json` | Tauri 应用配置 |

**理解点：**
- Tauri 怎么管理 WebView
- sidecar 进程怎么启动和管理
- Rust 怎么和前端通信 (invoke)

### 4.2 构建流程

**脚本：** `desktop/scripts/build-windows-x64.ps1`

```
1. 版本号 patch +1
2. 固定 WiX upgradeCode
3. 智能依赖安装
4. 并行构建 (前端 tsc+vite || sidecar bun build)
5. cargo tauri build → MSI
6. 生成构建笔记 + 通知
```

**理解点：**
- 8 条构建规则（CLAUDE.md 有详述）
- 构建产物结构
- 自动更新机制

### 4.3 CI/CD

**文件：** `.github/workflows/`
- `build-desktop-dev.yml` — 开发构建
- `release-desktop.yml` — 发布构建
- `deploy-docs.yml` — 文档部署

### 产出物

- [ ] 理解 Tauri 窗口的创建过程
- [ ] 知道 sidecar 进程的生命周期
- [ ] 能手动走一遍构建脚本
- [ ] 知道 CI/CD 流水线做什么

---

## Phase 5 — 适配器 + 运行时（1-2 天）

目标：了解 IM 通道和 Python 运行时。

### 5.1 IM 适配器

**入口：** `adapters/`

| 模块 | 说明 |
|------|------|
| `adapters/common/` | 公共层 — WebSocket 桥接、消息队列、去重、缓冲区 |
| `adapters/feishu/` | 飞书适配器 — 卡片消息、流式更新 |
| `adapters/telegram/` | Telegram 适配器 |

**理解点：**
- 适配器和主服务怎么通信 (WS Bridge)
- 消息格式怎么转换
- 流式渲染在 IM 平台怎么实现的

### 5.2 Python 运行时

**目录：** `runtime/`

- 键盘模拟、屏幕捕获、Win32 API
- 系统级自动化操作

**理解点：** 什么场景下需要 Python 运行时，和主服务怎么交互。

### 产出物

- [ ] 理解适配器架构模式
- [ ] 知道如何添加新的 IM 平台

---

## Phase 6 — 全局串联 + 动手（1-2 天）

目标：贯通全链路，通过改代码加深理解。

### 6.1 画完整数据流图

从你的操作开始，画一条链路：

```
你点击"新建会话" → React 组件 → sessionStore → HTTP POST → sidecar → 数据库 → 响应 → store 更新 → UI 重渲染
你输入消息 → ChatInput → chatStore → HTTP Proxy → AI Provider → 流式响应 → WebSocket → 前端逐块渲染
```

### 6.2 动手练习

| 练习 | 难度 | 说明 |
|------|------|------|
| 改前端某个组件的样式 | 简单 | 熟悉 React + Tailwind |
| 新增一个 REST API 端点 | 中等 | 理解前后端通信 |
| 加一个 i18n 翻译键 | 简单 | 理解类型安全 i18n |
| 加一个新工具 (tool) | 中等 | 理解工具注册机制 |
| 改 WebSocket 消息类型 | 中等 | 理解流式通信 |
| 阅读并修改一个测试 | 中等 | 理解测试模式 |

### 6.3 尝试构建

```bash
cd desktop
.\scripts\build-windows-x64.ps1
```

体验完整构建流程，观察产物。

### 产出物

- [ ] 能独立画出完整数据流
- [ ] 至少完成 2-3 个动手练习
- [ ] 项目成功打包

---

## 学习路线图总览速查

```
Phase 0 (Day 1)     ─ 环境搭建
  ↓
Phase 1 (Day 2-3)   ─ 宏观理解：读文档、理架构、画数据流
  ↓
Phase 2 (Day 4-6)   ─ 前端拆解：React 组件、Zustand、WebSocket
  ↓
Phase 3 (Day 7-10)  ─ 后端拆解：Server、Proxy、Tools、Utils
  ↓
Phase 4 (Day 11-13) ─ 原生壳 + 构建：Rust、Tauri、MSI
  ↓
Phase 5 (Day 14)    ─ 适配器 + 运行时：IM、Python
  ↓
Phase 6 (Day 15-17) ─ 全局串联：画图、动手改代码、构建
```

---

## 推荐阅读顺序（按文件）

### 核心必须读

1. `ARCHITECTURE.md` — 架构总览
2. `PROJECT_OVERVIEW.md` — 项目概览
3. `PROJECT_STRUCTURE_GUIDE.md` — 目录结构
4. `desktop/src-tauri/src/lib.rs` — Tauri 初始化
5. `desktop/src/main.tsx` — React 入口
6. `desktop/src/App.tsx` — 根组件
7. `desktop/src/stores/chatStore.ts` — 核心 Store
8. `src/server/server.ts` — 服务器入口
9. `src/server/router.ts` — 路由
10. `src/server/proxy/` — Proxy 转换层
11. `desktop/scripts/build-windows-x64.ps1` — 构建脚本

### 进阶阅读

1. `src/server/api/` — API Handlers
2. `src/server/ws/` — WebSocket
3. `src/tools/` — 工具实现
4. `src/utils/mcp/` — MCP 协议
5. `src/utils/memory/` — 记忆系统
6. `adapters/common/ws-bridge.ts` — WS 桥接

---

## 常见学习误区

| 误区 | 正解 |
|------|------|
| 一头扎进 Rust 代码 | Rust 层很薄，先理解前端和后端核心逻辑再回来看 |
| 一次性读完所有工具函数 | 30+ 个 `src/utils/` 模块，按需阅读，不用全读 |
| 试图理解每一行代码 | 先理解大图和核心链路，细节以后再补充 |
| 只看不跑 | 必须自己启动项目、改代码、看效果 |
| 不做笔记 | 画数据流图是最好的学习方法 |
