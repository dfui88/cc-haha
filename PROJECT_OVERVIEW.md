# Claude Code Haha 项目概览

> 基于 Anthropic Claude Code CLI 的桌面端 AI 聊天客户端

---

## 一、架构总览（四层）

```
┌──────────────────────────────────────────┐
│  Tauri 原生壳 (Rust)                      │
│  窗口管理 / 原生对话框 / 自动更新 / 进程管理  │
├──────────────────────────────────────────┤
│  React 前端 (desktop/src/)                │
│  TSX + Tailwind CSS + Zustand 状态管理     │
├──────────────────────────────────────────┤
│  Bun 后端 (src/server/)                   │
│  HTTP REST + WebSocket + CLI 子进程管理    │
├──────────────────────────────────────────┤
│  Python 运行时助手 (runtime/)              │
│  键盘模拟 / 屏幕捕获 / Win32 API           │
└──────────────────────────────────────────┘
```

---

## 二、核心工作流

### 消息发送与流式响应

```
用户输入 → WebSocket → 服务端写入 CLI stdin
  → Claude CLI 推理 → stdout stream-json
  → 解析推送到前端 → 逐块渲染
```

### 工具调用

```
AI 决定调用工具 → 前端显示执行状态
  → CLI 执行工具 → 返回结果
  → 结果送回 AI 继续生成
```

### AI Provider 代理

```
Anthropic 格式请求 → 协议转换层
  → Anthropic(直连) / OpenAI(格式转换)
  → 转回 Anthropic 格式返回
```

---

## 三、目录结构

```
src/                  # CLI 核心代码
├── server/           # HTTP/WS 服务器
│   ├── api/          # REST API handler
│   ├── services/     # 服务模块
│   ├── ws/           # WebSocket
│   └── proxy/        # AI Provider 代理
├── tools/            # 55+ 工具
└── utils/            # 工具函数

desktop/              # 桌面端
├── src/              # React 前端
│   ├── components/   # 组件
│   │   ├── chat/     # 聊天组件
│   │   ├── layout/   # 布局组件
│   │   ├── shared/   # 通用组件
│   │   └── tasks/    # 任务组件
│   ├── stores/       # Zustand 状态管理
│   ├── pages/        # 页面
│   ├── types/        # 类型定义
│   └── i18n/         # 国际化
├── src-tauri/        # Tauri Rust 代码
└── scripts/          # 构建脚本

adapters/             # AI 提供商适配器
runtime/              # Python 运行时
fixtures/             # 测试数据
docs/                 # 文档
```

---

## 四、状态管理 (Zustand)

| Store | 职责 |
|-------|------|
| chatStore | 聊天消息、WebSocket、流式文本 |
| sessionStore | 会话 CRUD |
| tabStore | 标签页持久化 |
| settingsStore | 应用设置 |
| uiStore | 主题、布局 |
| taskStore | 任务管理 |
| teamStore | 团队协作 |
| providerStore | AI Provider |

---

## 五、关键技术栈

| 类别 | 技术 |
|------|------|
| 桌面壳 | Tauri 2.x |
| 前端 | React 18 + TypeScript 5 + Zustand 5 |
| 样式 | Tailwind CSS 4 |
| 构建 | Vite 6 |
| 后端 | Bun |
| 原生 | Rust 2021 |
| AI | Anthropic / OpenAI |
| 测试 | Vitest |
| 图标 | Lucide React |
