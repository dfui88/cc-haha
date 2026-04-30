# 项目目录结构

> 自动生成自 `scripts/generate-structure.mjs`
>
> 更新方式：
> - `npm run generate:structure` — 重新生成根目录结构
> - `npm run generate:structure` — 完整重新生成
> - `node scripts/generate-structure.mjs src --depth 3` — 查看子目录详情
> - `node scripts/generate-structure.mjs desktop --depth 2` — 查看桌面端
>
> 详细架构说明请参见 [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## 根目录概览

```
./
├── .github/             # CI/CD 工作流 + Issue 模板
├── adapters/            # IM 适配器（飞书、Telegram）
├── bin/                 # CLI 入口脚本
├── desktop/             # 桌面应用（Tauri + React）
├── docs/                # VitePress 文档站点
├── fixtures/            # 测试夹具数据
├── release-notes/       # 版本发布说明
├── runtime/             # Python 运行时（键盘、屏幕捕获）
├── scripts/             # 构建/发布/工具脚本
├── src/                 # 核心源码（CLI + 引擎 + 服务端）
├── stubs/               # 类型桩文件
├── .env.example         # 环境变量示例
├── package.json         # 项目配置
├── tsconfig.json        # TypeScript 配置
├── bunfig.toml          # Bun 包管理器配置
├── preload.ts           # 预加载脚本
├── ARCHITECTURE.md      # 架构文档
└── PROJECT_STRUCTURE.md # 本文件
```

---

## 核心源码 `src/`

```
src/
├── assistant/           # 助手模块（会话选择、门控）
├── bootstrap/           # 启动引导
├── bridge/              # 桥接模块（远程会话、REPL、WebSocket）
├── buddy/               # Buddy 功能（陪伴精灵）
├── cli/                 # CLI 框架（传输层、命令处理器）
├── commands/            # 100+ 个 CLI 命令实现
├── components/          # Ink React 终端 UI 组件
├── constants/           # 常量定义
├── context/             # React Context
├── coordinator/         # 协调器
├── daemon/              # 守护进程
├── environment-runner/  # 环境运行器
├── hooks/               # React Hooks + 工具权限
├── ink/                 # Ink 终端 UI 框架
├── jobs/                # 后台任务
├── keybindings/         # 快捷键绑定
├── memdir/              # 记忆目录
├── migrations/          # 数据迁移
├── native-ts/           # 原生 TypeScript 模块
├── outputStyles/        # 输出样式
├── plugins/             # 插件系统
├── proactive/           # 主动提示
├── query/               # 查询模块
├── remote/              # 远程连接
├── screens/             # Ink 屏幕组件
├── schemas/             # 数据模式
├── self-hosted-runner/  # 自托管运行器
├── server/              # HTTP/WS 服务端（详见下方）
├── server/              # HTTP/WS 服务端
├── services/            # 业务服务层
├── skills/              # 技能系统
├── ssh/                 # SSH 模块
├── state/               # 状态管理
├── tasks/               # 任务系统
├── tools/               # 80+ 工具实现
├── types/               # TypeScript 类型
├── upstreamproxy/       # 上游代理
├── utils/               # 工具函数
├── vendor/              # 第三方代码
├── vim/                 # Vim 模式
└── voice/               # 语音功能
├── voice/               # 语音功能
└── server/              # HTTP/WS 服务端（详见下方）
```

### 服务端 `src/server/`

```
src/server/
├── __tests__/           # 服务端测试（e2e、单元测试、夹具）
├── api/                 # API 路由（sessions, providers, skills...）
├── api/                 # API 路由（sessions, providers, skills, etc.）
├── backends/            # 后端实现
├── config/              # 服务端配置（providerPresets）
├── middleware/           # 中间件（auth, CORS, 错误处理）
├── proxy/               # 代理模块（协议转换、流式代理）
├── services/            # 服务（session, provider, conversation...）
├── services/            # 服务（session, provider, conversation, etc.）
├── types/               # 服务端类型
├── ws/                  # WebSocket 处理
├── router.ts            # 路由注册
├── server.ts            # HTTP 服务器入口
├── sessionManager.ts    # 会话管理器
└── types.ts             # 全局类型
```

---

## 桌面应用 `desktop/`

```
desktop/
├── public/              # 静态资源（字体、图标）
├── scripts/             # 构建脚本（Windows/Mac）
├── sidecars/            # Sidecar 入口（claude-sidecar.ts）
├── src/                 # React 前端源码
│   ├── api/             # API 调用层
│   ├── components/      # UI 组件（chat, layout, markdown...）
│   ├── config/          # 前端配置
│   ├── constants/       # 常量（modelCatalog）
│   ├── hooks/           # React Hooks
│   ├── i18n/            # 国际化（zh/en）
│   ├── lib/             # 工具库
│   ├── mocks/           # Mock 数据
│   ├── pages/           # 页面组件
│   ├── stores/          # Zustand 状态管理
│   ├── theme/           # 主题样式
│   ├── types/           # TypeScript 类型
│   ├── App.tsx          # 根组件
│   └── main.tsx         # 入口
├── src-tauri/           # Tauri Rust 后端
│   ├── capabilities/    # 权限声明
│   ├── src/             # Rust 源码（main.rs, lib.rs）
│   ├── Cargo.toml       # Rust 依赖
│   └── tauri.*.json     # Tauri 配置（多平台）
├── vite.config.ts       # Vite 构建配置
└── vitest.config.ts     # Vitest 测试配置
```

---

## 其他目录

### IM 适配器 `adapters/`

```
adapters/
├── common/       # 通用适配层（附件、消息队列、配置）
├── feishu/       # 飞书适配器（卡片、Markdown、流式）
└── telegram/     # Telegram 适配器
```

### 文档 `docs/`

```
docs/
├── agent/        # 智能体文档（中/英）
├── channel/      # IM 通道文档
├── desktop/      # 桌面端文档
├── features/     # 特性文档（Computer Use）
├── guide/        # 使用指南（中/英）
├── im/           # IM 集成
├── memory/       # 记忆系统文档（中/英）
├── reference/    # 参考文档
├── skills/       # 技能文档（中/英）
└── superpowers/  # 超级功能设计文档
```

### CI/CD `.github/`

```
.github/
├── workflows/
│   ├── build-desktop-dev.yml
│   ├── deploy-docs.yml
│   └── release-desktop.yml
└── ISSUE_TEMPLATE/  # Bug 报告、问题模板
```

---

> 运行 `npm run generate:structure` 查看自动生成的完整目录树。
> 运行 `npm run generate:structure` 重新生成本文件。
