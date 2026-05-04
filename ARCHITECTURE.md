# Claude Code Haha 工作原理

> 项目架构与核心机制的全面说明

---

## 一、整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Tauri 原生壳 (Rust)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              React 前端 (TSX + Tailwind)              │    │
│  │                                                      │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │    │
│  │  │  侧边栏   │  │  标签栏   │  │   聊天区/输入框   │   │    │
│  │  │ Sidebar  │  │  TabBar  │  │  ChatInput/Chat  │   │    │
│  │  └──────────┘  └──────────┘  └──────────────────┘   │    │
│  │                                                      │    │
│  │  ┌──────────────────────────────────────────────┐    │    │
│  │  │          Zustand 状态管理层                     │    │    │
│  │  │  sessionStore │ tabStore │ chatStore          │    │    │
│  │  │  settingsStore │ uiStore │ sessionRuntimeStore │    │    │
│  │  └──────────────────────────────────────────────┘    │    │
│  │                                                      │    │
│  │  ┌──────────────────────────────────────────────┐    │    │
│  │  │          i18n 国际化 (zh/en)                   │    │    │
│  │  └──────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                   │
│                 HTTP REST + WebSocket 通信                    │
│                    (127.0.0.1:3456)                           │
│                           │                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │          Bun 侧边进程 (claude-sidecar.exe)            │    │
│  │                                                      │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │    │
│  │  │ API 路由  │  │ Proxy    │  │ Provider 服务     │   │    │
│  │  │ sessions │  │ 代理/转换 │  │ 管理/测试/CRUD    │   │    │
│  │  │ skills   │  │ 协议转换  │  │                  │   │    │
│  │  │ projects │  └──────────┘  └──────────────────┘   │    │
│  │  └──────────┘                                       │    │
│  │  ┌──────────────────────────────────────────────┐    │    │
│  │  │          AI 提供商适配层                       │    │    │
│  │  │  Anthropic / OpenAI / Custom / 兼容API        │    │    │
│  │  └──────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │          Python 运行时助手 (runtime/)                 │    │
│  │  键盘模拟 │ 屏幕捕获 │ AppleScript │ Win32 API       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 三层结构

| 层 | 技术 | 职责 |
|----|------|------|
| **前端层** | React + TSX + Tailwind + Zustand | 用户界面渲染、交互逻辑、本地状态管理 |
| **原生壳层** | Tauri (Rust) | 窗口管理、原生对话框、进程生命周期、自动更新 |
| **服务层** | Bun (TypeScript) | API 服务、AI 代理转发、Provider 管理、业务逻辑 |
| **助手层** | Python | 操作系统级自动化（键盘、屏幕、脚本） |

---

## 二、启动流程

```
Tauri 入口 (main.rs)
    │
    ▼
lib.rs: 启动 sidecar 进程
    │  ├── 查找空闲端口
    │  ├── 启动 claude-sidecar.exe (Bun 服务器)
    │  └── 等待 HTTP 就绪
    │
    ▼
Tauri 创建主窗口 (WebView)
    │  ├── 加载 dist/index.html
    │  └── 注入 preload.ts (TAURI API 桥接)
    │
    ▼
React 应用初始化 (main.tsx)
    │  ├── i18n 初始化 (检测系统语言 → zh/en)
    │  ├── uiStore 初始化
    │  └── 渲染 App 根组件
    │
    ▼
App 组件挂载
    │  ├── tabStore.restoreTabs()  ← 从 localStorage 恢复标签
    │  ├── sessionStore.fetchSessions()  ← 从服务器拉取会话
    │  ├── settingsStore.fetchAll()  ← 加载设置/Provider
    │  └── WebSocket 连接初始化
    │
    ▼
用户界面就绪
```

### 进程关系

```
Tauri 主进程 (claude-code-desktop.exe)
    │
    ├── 子进程: claude-sidecar.exe (Bun HTTP/WS 服务器)
    │               │
    │               └── 子进程: Python 脚本 (按需)
    │
    └── WebView 渲染进程 (React 前端)
```

---

## 三、核心数据流

### 3.1 会话生命周期

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│  侧边栏   │    │ Zustand  │    │ Sidecar  │
│  /标签栏  │    │  Store   │    │ 服务器   │
└────┬─────┘    └────┬─────┘    └────┬─────┘
     │               │               │
     │  新建会话      │               │
     │──────────────>│               │
     │               │  POST /api/sessions
     │               │──────────────>│
     │               │   返回 id     │
     │               │<──────────────│
     │               │               │
     │  乐观更新      │               │
     │  状态变更通知   │               │
     │<──────────────│               │
     │               │               │
     │               │  fetchSessions (拉取最新列表)
     │               │──────────────>│
     │               │<──────────────│
     │               │               │
     │  合并更新      │               │
     │  (保留 "会话N") │               │
     │<──────────────│               │
     │               │               │
     │  切换会话      │               │
     │──────────────>│               │
     │               │  GET /api/sessions/:id/chat
     │               │──────────────>│
     │               │<──────────────│
     │               │               │
     │  显示消息      │               │
     │<──────────────│               │
```

### 3.2 聊天请求流程

```
用户输入消息
    │
    ▼
ChatInput 组件
    │  构建消息格式
    ▼
chatStore.sendMessage()
    │  调用服务端代理 API
    ▼
Sidecar Proxy Handler
    │  根据 Provider 配置选择适配器
    ▼
┌─────────────────────────────────────────────┐
│            Proxy 转换层                       │
│                                              │
│  Anthropic 格式 ◄──► OpenAI Chat 格式        │
│  Anthropic 格式 ◄──► OpenAI Responses 格式   │
│                                              │
│  支持: text / image / tool_use /             │
│        thinking / tool_result 等块类型       │
└─────────────────────────────────────────────┘
    │
    ▼
AI 提供商 API (Anthropic / OpenAI / 兼容服务)
    │
    ▼
流式响应返回
    │  WebSocket 实时推送
    ▼
前端渲染 (流式逐块显示)
```

### 3.3 Proxy 代理转换

```
客户端请求 (Anthropic 格式)
    │
    │  POST /api/proxy 或 /v1/messages
    ▼
handleProxyRequest()
    │  判断 apiFormat
    │  ├── anthropic → 直通，不转换
    │  ├── openai_chat → anthropicToOpenaiChat()
    │  └── openai_responses → anthropicToOpenaiResponses()
    ▼
构建上游 URL
    │  buildUpstreamUrl() / buildChatUrl()
    │  ├── 已含 /chat/completions → 直接使用
    │  └── 否则 → 拼接 /v1/chat/completions
    ▼
发送到上游 API
    │
    ▼
响应转换回 Anthropic 格式 → 返回给前端
```

---

## 四、状态管理

### 4.1 Zustand Store 结构

```
useSessionStore         会话列表、增删改查、活跃会话
useTabStore             标签页管理、持久化、恢复
useChatStore            聊天消息、WebSocket、发送/接收
useSettingsStore        设置项、Provider 列表、thinkingEnabled、webSearch
useUiStore              界面状态（主题、侧边栏宽度）
useSessionRuntimeStore  会话运行时（上下文、选择器）
useUpdateStore          自动更新状态
useCliTaskStore         CLI 任务管理
```

### 4.2 数据流原则

```
用户操作 → Store action → HTTP API 调用 → 服务器响应
                                   │
                          ┌────────▼────────┐
                          │ 乐观更新 (Optimistic) │
                          │ 先更新本地状态    │
                          │ 再同步到服务器    │
                          └─────────────────┘
                                   │
                                   ▼
                          UI 自动重新渲染
```

### 4.3 会话编号机制（v0.1.8）

```
新建会话
    │
    ├── 统计当前标签数 n
    ├── 生成标题 "会话{n+1}"
    │
    ├── 1. 乐观创建 (本地)
    │   ├── sessionStore.createSession("会话N")
    │   └── tabStore.openTab(sessionId, "会话N")
    │
    ├── 2. 同步服务端
    │   ├── POST /api/sessions (创建)
    │   └── PUT rename("会话N") (重命名)
    │
    └── 3. 数据合并
        ├── fetchSessions 保留本地标题
        ├── restoreTabs 优先使用存储标题
        └── 防止服务端默认值覆盖
```

---

## 五、关键技术

### 5.1 Tauri 集成

| 特性 | 实现 |
|------|------|
| **窗口管理** | Tauri Window API，自定义标题栏 |
| **原生对话框** | `@tauri-apps/plugin-dialog`（文件选择） |
| **自动更新** | `@tauri-apps/plugin-updater`（GitHub Releases） |
| **Shell** | `@tauri-apps/plugin-shell`（打开外部 URL、sidecar 进程管理） |
| **文件系统** | `@tauri-apps/plugin-fs`（文件操作） |

### 5.2 Sidecar 通信

```
协议: HTTP REST + WebSocket
地址: 127.0.0.1:3456 (动态端口，自动查找)
格式: JSON

REST 端点:
  GET    /api/sessions                → 会话列表
  POST   /api/sessions                → 创建会话
  DELETE /api/sessions/:id            → 删除会话
  PUT    /api/sessions/:id/rename     → 重命名
  GET    /api/sessions/:id/chat       → 获取聊天记录
  POST   /api/proxy                   → 代理 AI 请求
  GET    /api/skills                  → 技能列表
  GET    /api/settings/user           → 用户设置
  PUT    /api/settings/user           → 更新用户设置
  GET    /api/diagnostics             → 诊断信息
  GET    /api/diagnostics/logs        → 日志列表
  DELETE /api/diagnostics/logs        → 清除日志
  GET    /api/diagnostics/export      → 导出诊断包

WebSocket:
  /ws → 实时消息推送
    消息类型: chat_chunk, session_update, session_title_updated
  /ws?channel=sdk → SDK 负载通道
```

### 5.3 国际化 (i18n)

```
自动检测: localStorage → 系统语言 → 默认 'zh'

语言包:
  zh.ts → 中文 (默认)  — Record<TranslationKey, string>
  en.ts → English      — as const 对象，导出 TranslationKey 类型

类型安全: TranslationKey = keyof typeof en
          确保 zh.ts 包含 en.ts 的所有键

使用:
  useTranslation() hook → t('key') → 翻译文本
  t('key', { var: value }) → 模板插值 (如 '{days}d / {size} max')

支持页面:
  Settings 通用/Provider/Agent/MCP/Skills/Diagnostics 标签
```

### 5.4 诊断系统 (Diagnostics)

```
诊断页面 (DiagnosticsSettings.tsx):
  ├── 概览信息 (版本、平台、架构、运行时间)
  ├── 事件日志 (WebSocket 事件、错误记录)
  ├── 日志管理 (查看目录、清除日志、配置保留策略)
  ├── 导出诊断包 (导出为 JSON bundle)
  └── 复制摘要 (快速复制诊断摘要到剪贴板)

数据来源:
  GET  /api/diagnostics        → 诊断概览
  GET  /api/diagnostics/logs   → 日志列表
  GET  /api/diagnostics/export → 导出诊断包
  DELETE /api/diagnostics/logs → 清除日志
```

### 5.4 智能 Provider 适配

```
用户配置 Provider 时:
  ├── 输入 Base URL
  ├── 选择 API Format (自动检测)
  │   ├── 含 /chat/completions → openai_chat
  │   ├── 含 /v1/messages      → anthropic
  │   └── 含 /responses        → openai_responses
  └── 输入 API Key / Model 映射

代理模式 (非 anthropic 格式):
  自动注入 ANTHROPIC_AUTH_TOKEN = 'proxy-managed'
  自动注入 ANTHROPIC_API_KEY = 'proxy-managed'
```

---

## 六、构建与部署

### 构建流程

```
1. build-windows-x64.ps1 编排完整流程:
   ├── 版本号 patch +1 (tauri.conf.json / package.json / Cargo.toml)
   ├── 固定 WiX upgradeCode
   ├── 智能依赖安装 (node_modules 已存在则跳过)
   ├── 生成 fix+版本号.txt / BUILD_NOTES.txt (超时保险，构建前写入)
   ├── build-before.mjs 并行执行:
   │   ├── 前端构建: tsc -b && vite build → dist/
   │   └── sidecar 构建: bun build → binaries/claude-sidecar.exe
   ├── cargo tauri build → MSI 安装包
   ├── 覆盖更新构建笔记 (写入实际 MSI 路径)
   └── 自动打开输出目录 + 系统通知
```

### 产物

```
build-artifacts/windows-x64/
  ├── Claude-Code-Haha_0.1.xx_windows_x64_msi.msi    ← 安装包
  ├── Claude-Code-Haha_0.1.xx_windows_x64_msi.msi.sig ← 签名
  ├── Claude-Code-Haha_0.1.xx_windows_x64_msi.msi.zip ← 压缩包
  ├── latest.json                                       ← 更新信息
  ├── BUILD_NOTES.txt                                   ← 英文构建笔记
  └── fix+0.1.xx.txt                                    ← 中文修复说明
```

---

## 七、项目技术栈一览

| 类别 | 技术 | 版本 |
|------|------|------|
| **桌面壳** | Tauri 2 | ^2.x |
| **前端框架** | React | ^19.x |
| **类型系统** | TypeScript | ^5.x |
| **状态管理** | Zustand | ^5.x |
| **样式** | Tailwind CSS | ^4.x |
| **构建工具** | Vite | ^6.x |
| **后端运行** | Bun | ^1.x |
| **原生语言** | Rust | edition 2021 |
| **运行时** | Python | 3.x |
| **对话框** | @tauri-apps/plugin-dialog | ^2.x |
| **自动更新** | @tauri-apps/plugin-updater | ^2.x |
| **国际化** | 自建 i18n 系统 | — |
