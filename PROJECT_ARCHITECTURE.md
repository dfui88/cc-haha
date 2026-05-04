# 项目架构分析

> Claude Code Haha — 基于 Anthropic Claude Code CLI 的桌面端 AI 聊天客户端
> 分析日期：2026-05-04

---

## 一、整体架构（三层）

```
┌─────────────────────────────────────────────────────┐
│  Tauri 桌面壳 (Rust)                                 │
│  窗口管理 / 原生对话框 / 自动更新 / 进程生命周期       │
│  终端伪终端 / 文件对话框 / 侧边进程(Sidecar)管理       │
├─────────────────────────────────────────────────────┤
│  React 前端 (desktop/src/)                           │
│  TSX + Tailwind CSS 4 + Zustand 5 状态管理            │
│  Vite 6 构建 / 多标签页管理 / 流式渲染                  │
├─────────────────────────────────────────────────────┤
│  Bun 后端 (src/server/)                              │
│  Bun.serve() 原生 HTTP + WebSocket                   │
│  REST API (20+ 端点) + WS 实时通信                    │
│  管理 Claude CLI 子进程                               │
├─────────────────────────────────────────────────────┤
│  Claude CLI (AI 引擎)                                 │
│  实际对话处理 / 工具调用 / 流式输出                    │
│  stream-json + vscode-jsonrpc 通信                    │
└─────────────────────────────────────────────────────┘
```

---

## 二、前端技术栈

| 维度 | 技术 | 用途 |
|------|------|------|
| **UI 框架** | React 18.3 | 组件化 UI 渲染 |
| **构建工具** | Vite 6 + @vitejs/plugin-react | 开发服务器 (HMR) + 生产打包 |
| **样式方案** | Tailwind CSS 4 + @tailwindcss/vite | 原子化 CSS 工具类 |
| **状态管理** | Zustand 5 | 23 个 store，按功能拆分的状态管理 |
| **语言** | TypeScript 5.9 (strict) | 类型安全 |
| **测试** | Vitest 3 + Testing Library | 单元测试/组件测试 |
| **图标** | lucide-react | SVG 图标库 |
| **Markdown** | marked + DOMPurify + shiki | 渲染 AI 回复 + 代码高亮 |
| **图表** | mermaid | 流程图/时序图渲染 |
| **差异对比** | react-diff-viewer-continued | 文件变更对比 |
| **终端** | @xterm/xterm + @xterm/addon-fit | 内嵌命令行终端 |
| **Tauri API** | @tauri-apps/api + plugin-shell/process/dialog/updater | 原生桌面能力 |

### 前端路由设计

**无传统路由库**（无 React Router）。采用 Zustand 的 `tabStore` 管理多标签页：

```
tabStore.activeTabId → ContentRouter 组件
  ├── session-xxx → <ChatPage />        ← 聊天会话
  ├── settings    → <SettingsPage />     ← 设置
  ├── scheduled   → <ScheduledTasks />   ← 定时任务
  └── terminal    → <TerminalPage />     ← 终端
```

每个标签页独立持久化（localStorage），支持关闭恢复和标题自动生成。

---

## 三、后端技术栈

| 维度 | 技术 | 用途 |
|------|------|------|
| **运行时** | Bun | HTTP+WebSocket 服务器运行环境 |
| **HTTP 框架** | 无框架 | 直接使用 `Bun.serve()` 原生 fetch handler |
| **Schema 验证** | Zod 4 | 请求参数和配置验证 |
| **AI SDK** | @anthropic-ai/sdk 0.80 | Claude API 官方客户端 |
| **MCP** | @modelcontextprotocol/sdk 1.29 | 模型上下文协议支持 |
| **IPC** | vscode-jsonrpc | CLI 子进程 JSON-RPC 通信 |
| **HTTP 客户端** | undici (内置) + axios | 外部 API 请求 |
| **文件监控** | chokidar | 配置目录实时监听 |
| **任务调度** | 内置 cronScheduler | 定时执行 CLI 任务 |
| **遥测** | @opentelemetry/** | 日志/指标/追踪 |
| **特性开关** | @growthbook/growthbook | 功能发布控制 |
| **限流** | 内置 ProviderService | 令牌桶算法 |
| **WebSocket** | Bun 原生 + ws 库 | 双通道实时通信 |

### 后端 API 路由（20+ 端点）

| 资源 | 方法 | 说明 |
|------|------|------|
| `/api/sessions` | GET/POST | 会话 CRUD |
| `/api/sessions/:id/chat` | GET | 聊天记录 |
| `/api/sessions/:id/rename` | PUT | 重命名 |
| `/api/settings/user` | GET/PUT | 用户设置 |
| `/api/providers` | GET | AI Provider 列表 |
| `/api/models` | GET | 模型列表 |
| `/api/proxy` | POST | AI 请求代理 |
| `/api/search` | GET | Web 搜索 |
| `/api/scheduled-tasks` | GET | 定时任务 |
| `/api/skills` | GET | 技能列表 |
| `/api/plugins` | GET | 插件列表 |
| `/api/agents` | GET | Agent 列表 |
| `/api/teams` | GET | 团队列表 |
| `/api/mcp` | GET | MCP 配置 |
| `/api/diagnostics` | GET | 诊断信息 |
| `/api/computer-use` | GET | 计算机使用设置 |
| `/api/adapters` | GET | 适配器列表 |
| `/api/filesystem` | GET | 文件系统 |
| `/health` | GET | 健康检查 |

---

## 四、前后端通信方式（双通道）

### 4.1 REST API

```
前端 api.get('/api/sessions')
  → fetch('http://127.0.0.1:3456/api/sessions', { signal: AbortSignal.timeout(30000) })
  → Bun.serve() fetch handler → router.ts → API handler
  ← JSON Response
```

- **默认端口**：3456
- **超时**：30 秒
- **认证**：localhost 免认证
- **CORS**：自动附加

前端每个 API 模块独立文件：
`desktop/src/api/sessions.ts`、`settings.ts`、`tasks.ts`、`models.ts`、`plugins.ts`、`agents.ts`、`terminal.ts` 等

### 4.2 WebSocket（实时消息）

```
wsManager.connect(sessionId)
  → WebSocket('ws://127.0.0.1:3456/ws/{sessionId}')
```

**客户端功能：**
- 自动重连（指数退避 1s ~ 30s）
- 消息队列（最多缓存 500 条）
- 30 秒心跳 ping
- 每个 sessionId 独立连接

**消息类型：**

| 方向 | 类型 | 说明 |
|------|------|------|
| 客户端→服务端 | `user_message` | 发送用户消息 |
| | `stop_generation` | 停止 AI 生成 |
| | `permission_response` | 响应权限请求 |
| | `set_permission_mode` | 设置权限模式 |
| | `set_runtime_config` | 切换 Provider/Model |
| | `ping` | 心跳 |
| | `prewarm_session` | 预热会话 |
| 服务端→客户端 | `connected` | 连接成功 |
| | `content_start` | 新内容块开始 |
| | `content_delta` | 流式增量内容 |
| | `tool_use_complete` | 工具调用完成 |
| | `tool_result` | 工具执行结果 |
| | `thinking` | 思考过程 |
| | `message_complete` | 消息完成（含 Token 用量） |
| | `permission_request` | 请求用户授权 |
| | `status` | 状态更新 |
| | `error` | 错误信息 |
| | `session_title_updated` | 标题生成完成 |

---

## 五、Tauri 的连接方式

```
Tauri 主进程 (Rust)
  │
  ├── beforeBuildCommand:
  │   └── node scripts/build-before.mjs
  │       ├── tsc -b && vite build        (前端构建)
  │       └── bun run build:sidecars      (后端 sidecar 构建)
  │
  ├── 加载前端:
  │   ├── 开发模式: http://localhost:1420 (Vite HMR)
  │   └── 生产模式: ../dist (静态文件)
  │
  ├── Rust Commands (tauri::command):
  │   ├── get_server_url()     ← 返回后端地址
  │   ├── terminal_spawn()     ← 启动伪终端
  │   ├── terminal_write()     ← 写入终端
  │   ├── terminal_resize()    ← 调整终端大小
  │   └── terminal_kill()      ← 关闭终端
  │
  ├── Sidecar:
  │   ├── externalBin: ["binaries/claude-sidecar"]
  │   ├── Bun.serve() 作为独立进程运行
  │   └── 自动启动/停止/重启
  │
  ├── Resources:
  │   ├── "bundled/claude" → Claude CLI 二进制
  │   └── 打包到安装包中
  │
  └── 前端启动流程 (desktopRuntime.ts):
      1. 检测是否为 Tauri 环境
      2. invoke('get_server_url') 获取后端地址
      3. 设置 api client 的 baseUrl
      4. 轮询 /health 端点等待后端就绪
         (最多 30 次 × 250ms)
```

---

## 六、完整调用链

### 6.1 聊天消息流程

```
用户输入 → ChatInput.tsx
  │ 调用 chatStore.sendMessage()
  ▼
WebSocket → { type: 'user_message', content: '...' }
  │
  ▼
Bun 服务器 → ws/handler.ts → handleUserMessage()
  │ 确保 CLI 子进程已启动
  ▼
conversationService.sendMessage() 写入 CLI stdin
  │
  ▼
Claude CLI 子进程
  │ AI 推理 → stdout stream-json
  ▼
conversationService.onOutput() 解析输出
  │ 转换为 ServerMessage 格式
  ▼
WebSocket 推送到前端
  │ content_start → content_delta → tool_use_complete
  │ tool_result → message_complete
  ▼
chatStore.handleServerMessage()
  │ 更新 messages / streamingText
  ▼
MessageList.tsx 流式逐块渲染
```

### 6.2 工具调用流程

```
AI 决定调用工具
  │
  ▼
服务端发送 tool_use_complete (工具名 + 参数)
  │
  ▼
前端渲染 ToolCallBlock (显示"运行中...")
  │
  ▼
CLI 执行工具 (55+ 工具可用)
  │ Bash / 文件操作 / 搜索 / 任务管理 / Agent 等
  ▼
服务端发送 tool_result (执行结果)
  │
  ▼
前端 ToolResultBlock 渲染结果
  │ 输出/错误/代码/差异对比
  ▼
结果送回 AI 继续生成
```

### 6.3 AI Provider 代理流程

```
桌面端请求 (Anthropic Messages API 格式)
  │
  ▼
POST /api/proxy 或 /v1/messages
  │
  ▼
handleProxyRequest()
  ├── anthropic 格式 → 直接透传（无转换）
  ├── openai_chat → anthropicToOpenaiChat() 转换
  └── openai_responses → anthropicToOpenaiResponses() 转换
  │
  ▼
上游 AI API
  ├── Anthropic (api.anthropic.com)
  ├── OpenAI 兼容 (自定义 Provider)
  └── AWS Bedrock
  │
  ▼
响应转回 Anthropic 格式 → 返回前端
```

---

## 七、状态管理架构（23 个 Zustand Store）

| Store | 职责 | 核心数据 |
|-------|------|---------|
| **chatStore** | 聊天核心 | messages, streamingText, sessions, WebSocket |
| **sessionStore** | 会话管理 | sessions 列表, CRUD, 活跃会话 |
| **tabStore** | 标签页管理 | activeTabId, tabs 持久化/恢复 |
| **settingsStore** | 应用配置 | 用户设置, Provider 配置 |
| **uiStore** | 界面状态 | 主题, 侧边栏宽度 |
| **sessionRuntimeStore** | 运行时配置 | Provider, Model 选择 |
| **providerStore** | Provider 管理 | 自定义 Provider 列表 |
| **teamStore** | 团队协作 | Agent 团队配置 |
| **taskStore** | 任务管理 | 定时任务 CRUD |
| **cliTaskStore** | CLI 任务 | CLI 任务状态 |
| **skillStore** | 技能管理 | 技能列表 |
| **pluginStore** | 插件管理 | 插件列表/状态 |
| **mcpStore** | MCP 配置 | MCP Server 连接 |
| **agentStore** | Agent 管理 | Agent 配置 |
| **updateStore** | 自动更新 | 更新状态 |
| **hahaOAuthStore** | OAuth 认证 | Token 管理 |

---

## 八、项目目录结构

```
F:\codebuddycn\cc-haha\
├── src/                          # CLI 核心代码 (Bun)
│   ├── server/                   # HTTP/WS 服务器
│   │   ├── api/                  # 19 个 REST API handler
│   │   ├── services/             # 21 个服务模块
│   │   ├── ws/                   # WebSocket 事件处理器
│   │   ├── proxy/                # AI Provider 代理/协议转换
│   │   ├── router.ts             # 路由注册
│   │   └── index.ts              # 服务器入口
│   ├── tools/                    # 55+ 工具
│   ├── services/                 # 通用服务
│   ├── tasks/                    # 任务系统
│   └── utils/                    # 工具函数
│
├── desktop/                      # 桌面端
│   ├── src/                      # React 前端
│   │   ├── components/
│   │   │   ├── chat/             # 33 个聊天组件
│   │   │   ├── layout/           # 11 个布局组件
│   │   │   ├── shared/           # 14 个通用组件
│   │   │   ├── controls/         # 控件组件
│   │   │   ├── settings/         # 设置组件
│   │   │   ├── tasks/            # 任务组件
│   │   │   ├── teams/            # 团队组件
│   │   │   ├── plugins/          # 插件组件
│   │   │   ├── skills/           # 技能组件
│   │   │   └── markdown/         # Markdown 渲染组件
│   │   ├── stores/               # 23 个 Zustand store
│   │   ├── pages/                # 18 个页面
│   │   ├── api/                  # 前后端 API 通信
│   │   ├── types/                # 类型定义
│   │   ├── i18n/                 # 国际化 (zh/en)
│   │   └── theme/                # 主题样式
│   ├── src-tauri/                # Tauri Rust 原生代码
│   └── scripts/                  # 构建脚本
│
├── adapters/                     # AI 提供商适配器
├── runtime/                      # Python 运行时助手
├── fixtures/                     # 测试固定数据
├── docs/                         # VitePress 文档
├── scripts/                      # 工具脚本
├── .github/                      # GitHub Actions 工作流
├── reports/                      # 修改记录报告
├── CHANGELOG.md                  # 版本变更日志
├── PROJECT_OVERVIEW.md           # 项目概览
└── PROJECT_ARCHITECTURE.md       # 本文档
```

---

## 九、关键技术栈总结

| 类别 | 技术 |
|------|------|
| 桌面壳 | Tauri 2.x |
| 前端框架 | React 18.3 + TypeScript 5.9 |
| 构建工具 | Vite 6 |
| 样式方案 | Tailwind CSS 4 |
| 状态管理 | Zustand 5 |
| 后端运行时 | Bun (Bun.serve 原生) |
| 原生语言 | Rust 2021 edition |
| AI SDK | @anthropic-ai/sdk 0.80 |
| Schema | Zod 4 |
| AI Provider | Anthropic / OpenAI 兼容 / AWS Bedrock |
| 内嵌终端 | xterm.js + Tauri plugin-shell |
| 安装包 | NSIS / WiX (Windows), DMG (macOS) |
| 自动更新 | @tauri-apps/plugin-updater |
| 国际化 | 自建 i18n (zh/en) |
| 测试 | Vitest + Testing Library |

---

## 十、架构特点总结

1. **Sidecar 架构** — Bun 服务器作为独立进程运行，Tauri 管理其生命周期
2. **双通道通信** — REST API 用于数据查询，WebSocket 用于实时消息推送
3. **Provider 适配层** — 支持任意 OpenAI 兼容 API，协议自动转换
4. **流式渲染** — AI 响应通过 WebSocket 实时推送，前端逐块渲染
5. **多标签页** — 无传统路由，通过 Zustand 管理标签页，支持持久化恢复
6. **状态隔离** — 每个会话独立状态，23 个 Store 按职责拆分
7. **超时保护** — 前端 30 分钟响应超时，WebSocket 心跳保持连接
8. **CLI 子进程管理** — 自动启动/停止/重启 Claude CLI 进程
