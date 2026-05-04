# 项目代码优化建议报告

> 审查日期：2026-05-04 | 项目：Claude Code Haha
> 审查范围：全部源码、配置、文档、构建脚本、CI/CD
> **说明：本报告仅列出问题和建议，未更改任何代码，方便您审阅后决定是否采纳。**

---

## 目录

- [A. 架构层面](#a-架构层面)
- [B. 后端代码质量](#b-后端代码质量-srcserver)
- [C. 前端代码质量](#c-前端代码质量-desktopsrc)
- [D. Rust / Tauri 壳层](#d-rust--tauri-壳层)
- [E. 构建脚本与 CI/CD](#e-构建脚本与-cicd)
- [F. IM 适配器](#f-im-适配器)
- [G. 依赖管理](#g-依赖管理)
- [H. 配置文件](#h-配置文件)
- [I. 文档问题](#i-文档问题)
- [J. 安全审核](#j-安全审核)
- [K. 速查表：按优先级排序](#k-速查表按优先级排序)

---

## A. 架构层面

### A-1 [CRITICAL] Sidecar 进程无自动重启机制

整个桌面应用的 AI 交互完全依赖 `claude-sidecar.exe`（Bun 服务器）进程。如果该进程崩溃，所有 WebSocket 连接断开，所有会话丢失。

- **文件**: `desktop/src-tauri/src/lib.rs`（sidecar 启动逻辑，约 664-730 行）
- **影响**: sidecar 崩溃后整个应用无法使用 AI 功能，用户必须重启桌面应用
- **建议**:
  - 在 Rust 层添加 sidecar 进程监控，崩溃后自动重启
  - 重启时保留会话状态（从磁盘恢复）
  - 前端 WebSocket 断线时自动重连并显示重连状态

### A-2 [HIGH] CLI 子进程崩溃无自动恢复

`conversationService` 管理的 Claude CLI 子进程如果崩溃，当前没有自动重启机制。

- **文件**: `src/server/services/conversationService.ts`
- **建议**: 添加子进程健康检查和自动重启逻辑，崩溃时通知前端显示"正在重新连接..."

### A-3 [HIGH] 23 个 Zustand Store 的跨 Store 耦合风险

虽然职责隔离是好的，但 23 个 Store 可能导致跨 Store 依赖。例如 `sessionStore` 和 `chatStore` 都操作会话数据，`teamStore.ts` 中直接调用 `useChatStore.setState(...)` 操作其他 store 状态。

- **文件**: `desktop/src/stores/teamStore.ts:100-118`
- **建议**: 为跨 Store 操作定义明确的接口，减少直接调用 `setState`，考虑引入事件总线模式

### A-4 [MEDIUM] 乐观更新回滚机制不完整

前端采用乐观更新（先更新本地状态再同步服务端），但部分 Store 的回滚逻辑不完整。

- **文件**: `desktop/src/stores/settingsStore.ts:104-108`（`setModel` 缺少回滚）
- **建议**: 统一所有 Store 的乐观更新模式，确保每个 setter 都有回滚逻辑

---

## B. 后端代码质量（`src/server/`）

### B-1 [HIGH] `translateCliMessage()` — 365 行巨型函数

函数签名 `translateCliMessage(cliMsg: any, ...)` 中的 `any` 使整个翻译管道失去类型安全。

- **文件**: `src/server/ws/handler.ts:831-1196`
- **严重程度**: 高
- **建议**: 
  - 每个 switch-case（assistant/user/stream_event/control_request/result/system）拆分为独立函数
  - 定义 `CliSdkMessage` 联合类型替代 `any`

### B-2 [HIGH] `startSession()` — 174 行复杂函数

包含 launch info 检查、placeholder 替换、workDir 验证、Bun.spawn、startup grace period、stderr 日志写入、锁清理重试等多重职责。

- **文件**: `src/server/services/conversationService.ts:111-284`
- **严重程度**: 高
- **建议**: 拆分为 `validateStartupPreconditions()`、`spawnCliProcess()`、`waitForStartup()`、`handleStartupFailure()` 等

### B-3 [MEDIUM] Proxy 中 auth 检查代码三处重复

`server.ts` 中 `/ws/`、`/api/`、`/proxy/` 三条路径重复了完全相同的 auth 检查逻辑（~10 行）。

- **文件**: `src/server/server.ts:85-94`, `155-164`, `188-197`
- **建议**: 提取 `checkAuth(req, origin): Response | null` 辅助函数

### B-4 [MEDIUM] `tool_choice` 转换逻辑重复

`anthropicToOpenaiChat.ts` 和 `anthropicToOpenaiResponses.ts` 各实现了一个完全相同的 `convertToolChoice()` 函数。

- **文件**:
  - `src/server/proxy/transform/anthropicToOpenaiChat.ts:195-207`
  - `src/server/proxy/transform/anthropicToOpenaiResponses.ts:156-168`
- **建议**: 提取到共享 `transformUtils.ts`

### B-5 [MEDIUM] provider env keys 列表在多个文件中重复

`providerService.ts` 定义了 `MANAGED_ENV_KEYS` 列表，`conversationService.ts` 中多处重复相同的 ANTHROPIC_* 键名列表。

- **文件**:
  - `src/server/services/providerService.ts:38-49`
  - `src/server/services/conversationService.ts:706-718`, `828-841`, `871-878`
- **建议**: 提取为共享常量模块

### B-6 [MEDIUM] 深层嵌套 — handler.ts 中的多个 5-6 层嵌套

`translateCliMessage()` 中 `assistant` case 的 `streamState.hasReceivedStreamEvents` 分支嵌套达到 5-6 层。

- **文件**: `src/server/ws/handler.ts:845-884`
- **建议**: 块处理逻辑提取到 `processAssistantBlock()`、`processStreamEventBlock()` 等函数，用 async/await 替代 `.then()` 链

### B-7 [MEDIUM] `handleUserMessage()` 中 `allUserMessages` 数组无上限

`sessionTitleState` 中的 `allUserMessages: string[]` 随着用户持续发送消息会无限增长。

- **文件**: `src/server/ws/handler.ts:316`
- **建议**: 标题生成只用到前几条消息，建议只保留最近 5-10 条消息或设置最大上限

### B-8 [MEDIUM] SDK 消息 `pendingPermissionRequests` Map 无清理机制

长时间运行的会话中，`pendingPermissionRequests` 的 requestId 如果未被响应会导致内存泄漏。

- **文件**: `src/server/services/conversationService.ts:500-502`
- **建议**: 添加超时清理机制

### B-9 [MEDIUM] `readProcessOutputStream()` 空的 catch 块

第 593-595 行的 `catch {}` 完全吞掉了 stream read 错误，文件描述符泄漏或 OOM 将完全不可见。

- **文件**: `src/server/services/conversationService.ts:593-595`
- **建议**: 至少用 `console.warn` 或记录到 `diagnosticsService`

### B-10 [MEDIUM] `getRuntimeSettings()` 中重复调用 `listProviders()` 和 `getUserSettings()`

每次用户消息都重复调用这两个函数（通过多个代码路径）。

- **文件**: `src/server/ws/handler.ts:1303-1434`
- **建议**: 对 `listProviders()` 和 `getUserSettings()` 的结果做短时间缓存（5-10 秒）

### B-11 [LOW] 死代码 — `useArrayContent` 变量始终为 false

`convertAssistantMessage()` 中第 154 行的 `let useArrayContent = false` 从未被赋值为 `true`。

- **文件**: `src/server/proxy/transform/anthropicToOpenaiChat.ts:154, 182-186`
- **建议**: 移除 `useArrayContent` 变量和相关死代码分支

### B-12 [LOW] 代码整洁小问题

| 问题 | 文件 | 建议 |
|------|------|------|
| `startSession()` 中重复的 SESSION_DELETED 检查 | `conversationService.ts:117-135` | 删除第二处重复检查 |
| `handlePrewarmSession()` 嵌套 `.then()` 链 | `ws/handler.ts:391-411` | 改用 async/await |
| sessionCleanupTimers 超时值与注释不一致 | `ws/handler.ts:37, 224` | 统一为常量 |
| `handleStopGeneration()` 中的 `3_000` 魔术数字 | `ws/handler.ts:619` | 提取为命名常量 |
| `shutdown` 失败后仍 `process.exit(0)` | `server.ts:142-149` | flush 失败应 `exit(1)` |

---

## C. 前端代码质量（`desktop/src/`）

### C-1 [HIGH] `Settings.tsx` — 1931 行超长文件

包含 12 个子组件（ProviderSettings、PermissionSettings、GeneralSettings 等）全放在同一个文件里。

- **文件**: `desktop/src/pages/Settings.tsx:1-1931`
- **建议**: 每个设置标签页拆分为独立文件（如 `SettingsGeneral.tsx`、`SettingsProvider.tsx` 等），主文件只做导入和布局

### C-2 [HIGH] `McpSettings.tsx` — 1024 行超长文件

编辑/创建/详情模式全在同一个文件中。

- **文件**: `desktop/src/pages/McpSettings.tsx:1-1024`
- **建议**: 拆分 MCP 编辑、创建和详情组件为独立文件

### C-3 [MEDIUM] `LocalSlashCommandPanel.tsx` — 1045 行

4 个面板（MCP/Skills/Help/Status）+ 3 个折叠状态在同一个文件。

- **文件**: `desktop/src/components/chat/LocalSlashCommandPanel.tsx:1-1045`
- **建议**: 每个面板类型拆为独立文件

### C-4 [MEDIUM] `ChatInput.tsx` — 787 行

弹出菜单处理、文件上传、粘贴处理、快捷键等混在一起。

- **文件**: `desktop/src/components/chat/ChatInput.tsx:1-787`
- **建议**: 拆分弹出菜单、文件上传逻辑到独立 hook/组件

### C-5 [MEDIUM] `ToolCallGroup.tsx` — 623 行嵌套 AgentToolGroup

- **文件**: `desktop/src/components/chat/ToolCallGroup.tsx:1-623`
- **建议**: 将 AgentToolGroup（~200行）提取到独立文件

### C-6 [MEDIUM] `MessageList.tsx` — 590 行

包含 rewind 模态框的内部 JSX。

- **文件**: `desktop/src/components/chat/MessageList.tsx:1-590`
- **建议**: 提取 RewindModal 为独立组件

### C-7 [MEDIUM] 其他超 400 行的文件

| 文件 | 行数 | 建议 |
|------|------|------|
| `layout/Sidebar.tsx` | 558 | 拆分搜索/右键/拖拽逻辑 |
| `chat/MermaidRenderer.tsx` | 362 | 可拆分渲染引擎 |
| `layout/TabBar.tsx` | 425 | — |
| `layout/ProjectFilter.tsx` | 368 | — |

### C-8 [MEDIUM] `ChatInput.tsx` 中 10 个 `useEffect` 处理点击外部关闭

每个菜单（plusMenu/slashMenu/localSlashPanel/fileSearch）各自有独立 `useEffect` + `document.addEventListener('mousedown', ...)`。

- **文件**: `desktop/src/components/chat/ChatInput.tsx:141-199`
- **建议**: 提取 `useClickOutside(ref, callback)` 自定义 hook，或使用单个事件监听器分发

### C-9 [MEDIUM] `DirectoryPicker.onChange` 中代码重复

步骤注释出现两次，`disconnectSession` 和 `replaceTabSession` + `connectToSession` 各调用了两次。

- **文件**: `desktop/src/components/chat/ChatInput.tsx:738-778`
- **建议**: 移除重复调用和错误的步骤注释

### C-10 [MEDIUM] `teamStore.ts` 中脆弱的轮询模式

`handleTeamCreated` 在 1.5s、4s、8s 后连续三次调用 `fetchTeamDetail`。

- **文件**: `desktop/src/stores/teamStore.ts:291-293`
- **建议**: 应基于 WebSocket 就绪状态而非基于时间的硬编码 setTimeout

### C-11 [MEDIUM] `chatStore.ts` 模块级可变状态

`pendingDelta`、`flushTimer`、`pendingTaskToolUseIds` 散落在模块作用域中，不通过 Zustand 管理。

- **文件**: `desktop/src/stores/chatStore.ts:214-216`, `126-127`
- **建议**: 移至 Zustand 或使用 ref，避免多会话间状态泄漏风险

### C-12 [MEDIUM] `appendAssistantTextMessage` 违反不可变约定

第 240 行可变地更新最后一条消息 `last.content += content`，与文件其余部分的不可变风格不一致。

- **文件**: `desktop/src/stores/chatStore.ts:240`
- **建议**: 使用 `{ ...last, content: last.content + content }`

### C-13 [LOW] `chatStore.ts` 中 `loadHistory` 和 `reloadHistory` 逻辑重复

两者都调用 `fetchAndMapSessionHistory`，然后执行相同的 `lastTodos` 和 `hasMessagesAfterTaskCompletion` 处理。

- **文件**: `desktop/src/stores/chatStore.ts:533-607`
- **建议**: 提取共同部分为内部辅助方法

### C-14 [LOW] 死代码清理

| 问题 | 文件 | 建议 |
|------|------|------|
| `getDefaultBaseUrl()` 导出但未使用 | `desktop/src/api/client.ts:32-34` | 移除或标记 |
| `handleServerMessage` 中空的 `task_update` case | `desktop/src/stores/chatStore.ts:885-886` | 移除空 case 或加注释 |
| `msgCounter` 在 `disconnectSession` 后不重置 | `desktop/src/stores/chatStore.ts:129` | 加注释说明意图 |

### C-15 [LOW] `MessageList.tsx` 中每次滚动触发 `updateAutoScrollState`

- **文件**: `desktop/src/components/chat/MessageList.tsx:297`
- **建议**: 对 `onScroll` 防抖处理，或使用 `IntersectionObserver`

---

## D. Rust / Tauri 壳层

### D-1 [MEDIUM] `lib.rs` 整体偏长 — sidecar 管理逻辑集中

- **文件**: `desktop/src-tauri/src/lib.rs`
- **建议**: 将 sidecar 启动/停止/监控逻辑拆分到独立模块（如 `sidecar.rs`）

### D-2 [MEDIUM] Adapter sidecar 同样无自动重启（同 A-1）

`spawn_and_track_adapters_sidecar` 只启动一次，崩溃后不会恢复。

- **文件**: `desktop/src-tauri/src/lib.rs:857-870`
- **建议**: 添加自动重启逻辑

### D-3 [LOW] sidecar 启动超时仅 10 秒

轮询间隔 150ms，对于冷启动时 Bun 需要编译 JIT 的场景可能不够。

- **文件**: `desktop/src-tauri/src/lib.rs:599-615`
- **建议**: 将超时调整为 30 秒，或根据平台条件调整

### D-4 [LOW] `kill_windows_sidecars` 过于暴力

直接用 `taskkill /F /T /IM` 杀掉所有匹配进程名。多实例运行时可能误杀。

- **文件**: `desktop/src-tauri/src/lib.rs:884-897`
- **建议**: 改用更精确的进程匹配（如 PID 白名单）

### D-5 [LOW] `Cargo.toml` 缺少依赖审计

有 6 个 Tauri 插件和多个关键依赖，但没有 `deny.toml` 配置。

- **文件**: `desktop/src-tauri/Cargo.toml`
- **建议**: 添加 `cargo deny` 和 `deny.toml` 配置审计依赖许可和 CVE

---

## E. 构建脚本与 CI/CD

### E-1 [MEDIUM] 构建脚本中无内联错误处理

`build-windows-x64.ps1` 如果某个步骤失败（如 `cargo tauri build` 失败），后续步骤（通知、生成 notes）可能不会执行。

- **文件**: `desktop/scripts/build-windows-x64.ps1`
- **建议**: 使用 `trap` 或 `$ErrorActionPreference = 'Stop'` 确保失败时执行清理

### E-2 [MEDIUM] CI 中缺少 Windows 构建测试

`build-desktop-dev.yml` 和 `release-desktop.yml` 都只在 `ubuntu-latest` 上运行 tauri build，没有 Windows runner 来验证 MSI 构建。

- **文件**: `.github/workflows/*.yml`
- **建议**: 在关键 PR 中添加 Windows 构建验证

### E-3 [LOW] CI 缺少缓存策略

releases workflow 中每次运行都重新编译所有 Rust 依赖。

- **文件**: `.github/workflows/release-desktop.yml`
- **建议**: 添加 `actions/cache` 缓存 `target/` 目录

### E-4 [LOW] `build-before.mjs` 缺少错误处理

如果并行构建的一个分支失败，另一个分支可能继续运行。

- **文件**: `desktop/scripts/build-before.mjs`
- **建议**: 使用 `Promise.allSettled` 确保所有分支都完成后再判断整体成功/失败

### E-5 [LOW] 脚本中 PowerShell 注意事项已有文档

当前 `CLAUDE.md` 已经记录了 6 条 PowerShell 注意事项（try/catch、中文编辑、Read-Host 等），建议将其直接引用到脚本的开头注释中。

---

## F. IM 适配器

### F-1 [LOW] `adapters/package.json` 中 `bun-types` 使用 `"latest"`

会导致每次 `bun install` 产生不同的锁定文件。

- **文件**: `adapters/package.json`
- **建议**: 固定到具体版本号

### F-2 [LOW] `adapters/feishu/` 流式渲染复杂度过高

流式卡片更新逻辑较复杂，如果飞书 API 有变化需要调整多处。

- **建议**: 将卡片渲染逻辑和 API 调用逻辑分离，降低耦合

### F-3 [LOW] 适配器缺少连接健康检查

如果 WebSocket 桥接断开，当前没有显式的重连逻辑和状态通知。

- **建议**: 添加心跳和自动重连机制

---

## G. 依赖管理

### G-1 [MEDIUM] `@types/dompurify` 放在 `dependencies` 而非 `devDependencies`

- **文件**: `desktop/package.json`
- **建议**: 类型定义包应移到 `devDependencies`

### G-2 [MEDIUM] `marked` 在根和 desktop 中同时声明但版本不同

根使用 `^17.0.5`，desktop 使用 `^15.0.7`。

- **建议**: 统一版本并考虑使用 `overrides`/`resolutions` 对齐

### G-3 [MEDIUM] 架构文档技术版本与实际严重不符

- `ARCHITECTURE.md` 写 TypeScript `^5.x`，实际已升级到 `6.0.3`
- `PROJECT_ARCHITECTURE.md` 写 React `18.3`，实际已升级到 `19.2.5`
- **建议**: 批量更新架构文档中的版本号

### G-4 [LOW] `anyhow` 固定到 `1.0.102`

无法接收小版本安全更新。

- **文件**: `desktop/src-tauri/Cargo.toml`
- **建议**: 改为 `"1"` 以接收 patch 更新

### G-5 [LOW] 根 tsconfig 缺少 `strict: true`

desktop 的 tsconfig 已启用，但根没有。

- **建议**: 在根 tsconfig 中启用 `strict` 模式

### G-6 [LOW] 根 tsconfig 中 `allowJs: true` 已不需要

项目已全部使用 TypeScript。

- **建议**: 移除 `allowJs: true`

---

## H. 配置文件

### H-1 [MEDIUM] `.env.example` 缺少必需变量说明

全部环境变量都被注释掉，没有标明哪些是**必需**的。缺少 `SERVER_PORT`、`CLAUDE_CODE_FORCE_RECOVERY_CLI`、`ADAPTER_SERVER_URL` 等变量说明。

- **文件**: `.env.example`
- **建议**: 明确区分"必需"和"可选"变量，标注默认值和用途

### H-2 [LOW] `.gitignore` 完善但可补充

建议添加 `*.log`、`desktop/build-artifacts/` 的显式条目。

- **文件**: `.gitignore`
- **建议**: 添加上述忽略条目

---

## I. 文档问题

### I-1 [HIGH] `ARCHITECTURE.md` 与 `PROJECT_ARCHITECTURE.md` 严重重复

两份文档（各 ~400 行）内容高度重叠：架构图、启动流程、数据流、Store 列表、API 端点、Proxy 转换流程、技术栈表格几乎完全一致。

- **影响**: 读者不知道读哪个，两个都可能过时，维护成本翻倍
- **建议**: 合并为一个文件，或在其中一个引用另一个

### I-2 [HIGH] `PROJECT_STRUCTURE.md` 与 `PROJECT_STRUCTURE_GUIDE.md` 重复且有生成错误

`PROJECT_STRUCTURE.md` 中有明显重复行（`server/` 出现多次），由 `scripts/generate-structure.mjs` 生成。

- **建议**: 合并两份文档，修复生成脚本的重复条目问题

### I-3 [MEDIUM] 根目录文档过多（14 个 .md 文件）

CLAUDE.md、AGENTS.md、ARCHITECTURE.md、CHANGELOG.md、LEARNING_ROADMAP.md、PROJECT_ARCHITECTURE.md、PROJECT_OVERVIEW.md、PROJECT_STRUCTURE.md、PROJECT_STRUCTURE_GUIDE.md、README.md、README.en.md

- **建议**: 合并冗余文档到 `ARCHITECTURE.md`，将学习路线和指南移至 `docs/` 目录

### I-4 [MEDIUM] `CLAUDE.md` 中构建规则编号不一致

第 4 条规则在 CLAUDE.md 的执行流程中用"规则 5"引用，但规则列表中编号为 4。

- **文件**: `CLAUDE.md`
- **建议**: 统一编号

### I-5 [MEDIUM] `ARCHITECTURE.md` 5.4 节编号重复

"5.4 诊断系统"和"5.4 智能 Provider 适配"使用了相同的节号。

- **建议**: 修正为 5.4 和 5.5

---

## J. 安全审核

### J-1 [MEDIUM] API Key 日志暴露风险

`handleProxyRequest` 中 `console.error(err)` 可能暴露 `err` 消息。虽然当前 key 在 header 中不在 message 里，但需要确认。

- **文件**: `src/server/proxy/handler.ts:92`
- **建议**: 在日志输出前过滤敏感字段，或使用结构化日志

### J-2 [MEDIUM] WebSocket 和 HTTP 全链路未加密

虽然绑定在 127.0.0.1（合理），但 API Key 通过 HTTP 明文传输。如果有人通过远程桌面或调试工具访问了该端口，可无认证控制。

- **文件**: 全栈涉及
- **建议**: 考虑添加 localhost 密钥对或支持 TLS 选项（低优先级，仅对高安全需求场景）

### J-3 [LOW] 认证使用环境变量中的 ANTHROPIC_API_KEY

auth 对比 Bearer token 是否等于 `process.env.ANTHROPIC_API_KEY`。建议使用独立的 server-only auth token。

- **文件**: `src/server/middleware/auth.ts:21-27`
- **建议**: 引入 `SERVER_AUTH_TOKEN` 环境变量，与 ANTHROPIC_API_KEY 分离

### J-4 [LOW] Adapter sidecar 的 WsBridge URL 通过环境变量传递

`ADAPTER_SERVER_URL` 环境变量可能被子进程读取。

- **建议**: 风险较低（localhost 限制），但可考虑通过命令行参数传递

---

## K. 速查表：按优先级排序

### 必须修复 (Critical)

| ID | 问题 | 影响 |
|----|------|------|
| A-1 | Sidecar 进程无自动重启 | sidecar 崩溃后应用不可用 |
| A-2 | CLI 子进程崩溃无恢复 | 运行中会话中断 |

### 建议尽快修复 (High)

| ID | 问题 | 影响 |
|----|------|------|
| A-3 | 23 个 Store 跨 Store 耦合 | 状态一致性问题 |
| B-1 | `translateCliMessage()` 365 行 | 可维护性、类型安全 |
| B-2 | `startSession()` 174 行 | 可维护性 |
| C-1 | `Settings.tsx` 1931 行 | 极端难以维护 |
| C-2 | `McpSettings.tsx` 1024 行 | 难以维护 |
| I-1 | 两份架构文档严重重复 | 维护成本翻倍、文档过时 |
| I-2 | 两份目录结构文档重复+生成错误 | 混淆、信息不一致 |

### 值得修复 (Medium)

| ID | 问题 | 影响 |
|----|------|------|
| B-3/B-4/B-5 | 后端代码重复（auth/convert/env keys） | 维护成本 |
| B-6/B-7/B-8 | 深层嵌套/无上限数组/Map 泄漏 | 内存/可维护性 |
| B-9/B-10 | 空的 catch 块/重复调用 | 调试困难/性能 |
| C-3~C-12 | 前端文件过大/重复代码/轮询/可变状态 | 可维护性/一致性 |
| D-1/D-2 | lib.rs 管理逻辑集中/adapter 无重启 | 可维护性/可靠性 |
| E-1/E-2 | 构建脚本错误处理/CI 无 Windows 测试 | 构建可靠性 |
| G-1/G-2/G-3 | 依赖分类错误/版本分裂/文档陈旧 | 构建正确性 |
| H-1 | `.env.example` 缺少必需变量说明 | 新手上手 |
| I-3/I-4/I-5 | 文档过多/编号错误/节号重复 | 信息查找 |
| J-1/J-2 | API Key 日志暴露/全链路未加密 | 安全 |

### 锦上添花 (Low)

B-11~B-12、C-13~C-15、D-3~D-5、E-3~E-5、F-1~F-3、G-4~G-6、H-2、J-3~J-4

---

## 总结统计

| 严重级别 | 数量 | 说明 |
|---------|------|------|
| **CRITICAL** | 2 | Sidecar/CLI 崩溃无恢复 — 影响核心功能可用性 |
| **HIGH** | 8 | 巨型函数/超长文件/文档重复 — 影响可维护性 |
| **MEDIUM** | 22 | 代码重复/性能/配置/安全 — 值得修复 |
| **LOW** | 15+ | 代码整洁/死代码/小优化 — 锦上添花 |

**最值得优先投入的工作：**

1. **Sidecar 自动重启** — 修复单点故障，提升稳定性
2. **4 个超大文件拆分**（Settings.tsx、McpSettings.tsx、LocalSlashCommandPanel.tsx、translateCliMessage）
3. **后端 3 处代码重复提取**（auth 检查、tool_choice 转换、provider env keys）
4. **文档合并**（两份架构文档合并、两份目录结构文档合并）
5. **依赖版本统一和类型包分类修正**
