# 本地分支 vs 上游代码对比分析

> 对比时间：2026-04-30
> 本地分支：`dfui88/cc-haha` (`main`)
> 上游仓库：`NanmiCoder/cc-haha` (`upstream/main`)

---

## 总览

| 评级 | 文件数 | 占比 |
|------|--------|------|
| 本地显著更优 ⭐⭐⭐ | 4 | 21% |
| 本地更优 ⭐ | 10 | 53% |
| 混合/各有优劣 ⚖️ | 4 | 21% |
| 上游更优 | 0 | 0% |

**结论：本地分支的修改总体优于上游，建议保留全部本地修改。** 有 4 处可进一步优化的细节（见文末建议）。

---

## 1. `EmptySession.tsx` — 会话自动编号

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 新会话标题 | 全部为 "New Session" | 自动编号 `会话1`、`会话2`... |
| Tab 标题传递 | 硬编码 "New Session" | 传递编号标题到 `openTab()` |
| API 调用 | 无 | 额外调用 `sessionsApi.rename()` + `setSessionRuntime()` |

**评估：本地更优** ⭐

多标签页场景下可区分性明显提升。美中不足是 `会话{N}` 硬编码了中文，后续可接入 i18n。额外 API 调用在可接受范围内。

```diff
- const sessionId = await createSession(workDir || undefined)
+ const sessionTabs = useTabStore.getState().tabs.filter((t) => t.type === 'session').length
+ const sessionTitle = `会话${sessionTabs + 1}`
+ const sessionId = await createSession(workDir || undefined, sessionTitle)
```

---

## 2. `Settings.tsx` — API 格式自动检测 + 双重环境变量

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| API 格式检测 | 无 | 从 URL 路径自动检测（`/chat/completions` → `openai_chat`） |
| 环境变量注入 | 仅 `ANTHROPIC_AUTH_TOKEN` | `ANTHROPIC_API_KEY` + `ANTHROPIC_AUTH_TOKEN` 双注入 |
| 默认 token 处理 | 保留 preset 默认值 | 统一用 `apiKey` 覆盖 |

**评估：各有优劣** ⚖️

- ✅ `detectApiFormatFromUrl()` — 减少用户配置错误的自动检测是好功能
- ✅ 双 env 变量注入增强 Open AI 兼容提供商兼容性
- ❌ 本地版本忽略了 `selectedPreset.defaultEnv?.ANTHROPIC_AUTH_TOKEN` 回退逻辑，可能覆盖用户已有环境配置

```diff
- ANTHROPIC_AUTH_TOKEN: needsProxy
-   ? 'proxy-managed'
-   : (apiKey || selectedPreset.defaultEnv?.ANTHROPIC_AUTH_TOKEN || (selectedPreset.needsApiKey ? '(your API key)' : '')),
+ ANTHROPIC_API_KEY: needsProxy ? 'proxy-managed' : (apiKey || '(your API key)'),
+ ANTHROPIC_AUTH_TOKEN: needsProxy ? 'proxy-managed' : (apiKey || '(your API key)'),
```

> **建议**：保留双注入，但恢复 upstream 的 `ANTHROPIC_AUTH_TOKEN` 回退逻辑。

---

## 3. `chatStore.ts` — 响应超时系统

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 超时机制 | 无，可能永久挂起 | 180 秒超时 |
| 重置策略 | — | 每次服务端活动重置计数器 |
| 触发事件 | — | status / content_start / content_delta / thinking / tool_use_complete / tool_result / permission_request |
| 错误提示 | — | 中文错误："响应超时：长时间未收到数据..." |
| 清理策略 | — | message_complete / error / stop / disconnect 时清除 |

**评估：本地显著更优** ⭐⭐⭐

防止会话因服务端无响应永久挂起，这是生产级应用的必要功能。实现完整，涵盖所有关键路径：

- `scheduleResponseTimeout()` — 创建超时
- `resetResponseTimeout()` — 重置（clear + restart），在 10+ 事件处理器中调用
- `clearResponseTimeout()` — 清除，在完成/错误/断开时调用

```ts
const RESPONSE_TIMEOUT_MS = 180_000 // 3 分钟

function scheduleResponseTimeout(sessionId, get, set) {
  return setTimeout(() => {
    const store = get()
    const session = store.sessions[sessionId]
    if (!session || session.chatState === 'idle') return
    // 刷新待处理文本 → 停止生成 → 显示错误
    ...
  }, RESPONSE_TIMEOUT_MS)
}
```

---

## 4. `sessionStore.ts` — 过期请求检测与会话合并

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 并发控制 | 无 | 请求 ID 计数器（`_fetchRequestId`），忽略过期响应 |
| fetch 防抖 | 无 | 300ms `_fetchTimeout` 合并 |
| 本地数据保护 | 无 | 合并时保留 local workDir 和自定义标题 |
| 标题保护 | 无 | 服务器返回 "Untitled Session" / "New Session" 时保留本地标题 |

**评估：本地显著更优** ⭐⭐⭐

解决了三个竞态条件问题：

1. **过期响应** — 快速连续调用 `fetchSessions()` 时，早期慢响应不会覆盖最新数据
2. **防抖压缩** — 快速连续 `createSession` 合并为一次 fetch
3. **合并保护** — 服务器返回的数据不丢失本地已更新的标题/workDir

```ts
let _fetchRequestId = 0

fetchSessions: async (project?: string) => {
  const reqId = ++_fetchRequestId
  ...
  const { sessions: raw } = await sessionsApi.list(...)
  if (reqId !== _fetchRequestId) return  // 过期，丢弃
  ...
  // 合并本地 session，防止数据丢失
  for (const s of currentSessions) {
    if (byId.has(s.id)) {
      // 合并 workDir 和标题
    } else {
      byId.set(s.id, s)  // 保留本地但服务端尚未返回的 session
    }
  }
  if (reqId !== _fetchRequestId) return  // 再次检查
  set({ sessions, ... })
}
```

---

## 5. `ws/handler.ts` — Locale 透传 + JSONL 持久化

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| Locale 透传 | 无 | 三个返回路径都添加 `locale` 字段 |
| 运行时配置持久化 | 仅内存 | JSONL 文件持久化 + 启动时恢复 |
| 工作目录回退 | `os.homedir()` | 返回空字符串 `''` |
| import | `node:os` | 移除 `node:os` |

**评估：混合** ⚖️

### 值得保留的改动 ✅

- **Locale 透传** — 使服务端响应能根据用户语言设置本地化
- **JSONL 持久化** — 运行时配置跨服务重启保持，架构改进
- **移除 `node:os`** — 消除不必要的 import

### 需谨慎的改动 ❌

- **`resolveSessionWorkDir` 删除 `os.homedir()` 回退** — 上游行为更安全。返回 `''` 而非 `os.homedir()` 会让无工作目录的 CLI 子进程行为改变

```diff
- async function resolveSessionWorkDir(sessionId, fallback = os.homedir()) {
-   let workDir = fallback
+ async function resolveSessionWorkDir(sessionId) {
   try {
     const resolved = await sessionService.getSessionWorkDir(sessionId)
-    if (resolved) workDir = resolved
+    if (resolved) return resolved
   } catch (resolveErr) { ... }
-  return workDir
+  return ''  // 上游返回 os.homedir()，更安全
 }
```

> **建议**：保留 JSONL 持久化和 locale 透传，恢复 `os.homedir()` 回退。

---

## 6. `openaiChatStreamToAnthropic.ts` + `openaiResponsesStreamToAnthropic.ts` — 流超时

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 读取超时 | 无，可能永远挂起 | 60 秒无数据则超时报错 |
| 实现方式 | — | `readWithTimeout()` 包装器 |

**评估：本地显著更优** ⭐⭐⭐

防止流连接因上游无响应永久挂起。实现简洁，两个 stream 文件同步修改：

```ts
const STREAM_READ_TIMEOUT_MS = 60_000

function readWithTimeout(reader, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Proxy stream read timeout: no data received for ${timeoutMs / 1000} seconds`))
    }, timeoutMs)
    reader.read().then(
      (result) => { clearTimeout(timer); resolve(result) },
      (err) => { clearTimeout(timer); reject(err) },
    )
  })
}
```

---

## 7. `Sidebar.tsx` — 乐观删除/重命名

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 删除流程 | 等待服务器确认 → 更新 UI | 先更新 UI，再异步同步 |
| 重命名流程 | 等待服务器确认 → 更新 UI | 先更新 UI，再异步同步 |
| 错误处理 | 冒泡异常 | `catch {}` 静默吞掉 |
| 新建会话工作目录 | 仅从当前会话继承 | 当前会话 → 任意已有会话 → undefined |

**评估：本地更优** ⭐

乐观更新提供即时 UI 响应，用户体验更好。会话编号逻辑与 `EmptySession.tsx` 一致。需改进：

```diff
  try {
    await deleteSession(id)
-  } catch {
-    // 服务器同步失败，本地已清理
+  } catch (err) {
+    console.warn('[Sidebar] Failed to delete session on server:', err)
  }
```

> **建议**：添加 `console.warn` 日志，其余方案保留。

---

## 8. `ChatInput.tsx` — 会话工作目录切换

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 切换流程 | 创建新 → `moveSelection` → 断开 → 删除旧 | 6 步复杂流程：保存选择 → 从 store 移除旧 → 创建新 → 转移选择 → 删除旧 → 重新 fetch |
| 标题保留 | 无 | 保留原标题 |
| 旧会话处理 | 在 store 中残留 | 立即从 store 移除，防止重复 |

**评估：本地更优但过于复杂** ⭐

- ✅ 防止旧会话在侧边栏显示为重复项
- ✅ 保留用户自定义标题
- ❌ `clearSelection(oldId)` + `setSelection(newId, oldSelection)` 比上游的 `moveSelection(oldId, newId)` 多了一步无效操作

```diff
- useSessionRuntimeStore.getState().moveSelection(oldId, newId)
+ const oldSelection = useSessionRuntimeStore.getState().selections[oldId]
+ clearSelection(oldId)      // ❌ 多余，moveSelection 已处理
+ setSelection(newId, oldSelection)  // ❌ 可用 moveSelection 替代
```

> **建议**：恢复使用 `moveSelection`，其余方案保留。

---

## 9. `tabStore.ts` — 冷启动标题合并

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 标题恢复 | 无，显示 "Untitled Session" | 从存储的 tab 标题恢复 `会话N` |
| Session store 预填充 | 无 | 冷启动时立即填充会话信息（workDir 等） |

**评估：本地更优** ⭐

解决冷启动时 `sessionStore` 中标题和服务端标题不一致的问题。提前填充 `sessionStore` 确保 `ChatInput` 等组件从首次渲染就能获取会话信息。

```ts
// 将存储的 tab 标题合并到 session store
const sessionsWithMergedTitles = sessions.map((s) => {
  const storedTab = data.openTabs.find((t) => t.sessionId === s.id)
  if (storedTab && (s.title === 'Untitled Session' || s.title === 'New Session')) {
    return { ...s, title: storedTab.title }
  }
  return s
})
```

---

## 10. `settingsStore.ts` — 语言设置服务端持久化

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| Locale 同步 | 仅 localStorage | localStorage + 服务端 API |

**评估：概念正确但实现粗糙** ⚖️

- ✅ 跨设备同步语言设置
- ❌ `fetchAll()` 中调用 `settingsApi.updateUser()` 可能造成读写循环（读取时写入）
- ❌ `as any` 类型转换绕过了类型安全

```ts
// fetchAll() 中的代码——有问题的模式
const currentLocale = get().locale
try { await settingsApi.updateUser({ locale: currentLocale } as any) } catch { /* best effort */ }
```

> **建议**：保留 `setLocale` 中的同步，但移除 `fetchAll()` 中的写入逻辑。

---

## 11. `StreamingIndicator.tsx` — 状态动词国际化

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 状态动词 | 硬编码英文 | 映射到 i18n key，自动翻译 |

**评估：本地更优** ⭐

```ts
const SERVER_VERB_KEYS: Record<string, string> = {
  'Thinking': 'streaming.thinking',
  'Restarting session with new permissions...': 'streaming.restarting_session',
  'Task started': 'streaming.task_started',
  // ...
}
```

中文用户直接看到"思考中"而非 "Thinking"，对非英文用户友好。

---

## 12. `ThinkingBlock.tsx` — 思考块预览国际化

**评估：本地略优**

locale 为 `zh` 时显示"正在推理中..."，否则显示内容第一行。小改进但无副作用。

---

## 13. `spinnerVerbs.ts` — 中文旋转动词

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 动词数 | 187 个英文 | 187 英文 + 31 中文 |
| 选择逻辑 | 固定英文 | 根据 locale 自动选择 |

**评估：本地更优** ⭐

```ts
const SPINNER_VERBS_ZH = ['思考中', '计算中', '处理中', ..., '雕琢中']

export function randomSpinnerVerb(): string {
  const locale = useSettingsStore.getState().locale
  const list = locale === 'zh' ? SPINNER_VERBS_ZH : SPINNER_VERBS
  return list[Math.floor(Math.random() * list.length)] ?? (locale === 'zh' ? '思考中' : 'Thinking')
}
```

---

## 14. `i18n/en.ts & zh.ts` — 翻译条目补充

**评估：本地更优** ⭐

| key | 上游 | 本地分支 |
|-----|------|----------|
| `streaming.restarting_session` | 无 | ✅ 新增 |
| `streaming.switching_provider` | 无 | ✅ 新增 |
| `streaming.task_started` | 无 | ✅ 新增 |
| `streaming.task_in_progress` | 无 | ✅ 新增 |
| `thinking.preview` | 无 | ✅ 新增（en: "Reasoning...", zh: "正在推理中..."）|
| `error.WORKDIR_MISSING` | 无 | ✅ 新增（en: "Please select a project folder...", zh: "请先选择项目文件夹..."）|
| `baseUrlPlaceholder` | `/anthropic` | `/v1/chat/completions`（匹配默认格式）|

---

## 15. `proxy/handler.ts` — 灵活 URL 构建

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| URL 拼接 | 硬编码追加 `/v1/chat/completions` | 检测是否已包含路径，避免双路径 |

**评估：本地显著更优** ⭐⭐⭐

```ts
function buildUpstreamUrl(baseUrl: string, apiFormat: 'openai_chat' | 'openai_responses'): string {
  const base = baseUrl.replace(/\/+$/, '')
  if (apiFormat === 'openai_chat') {
    return base.endsWith('/chat/completions') ? base : `${base}/v1/chat/completions`
  }
  return base.endsWith('/responses') ? base : `${base}/v1/responses`
}
```

防止用户填完整 URL 时产生双路径错误 `https://example.com/v1/chat/completions/v1/chat/completions`。

---

## 16. `api/sessions.ts` — 优化 getRecentProjects

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| workDir 获取 | 每 session 调用一次 `getSessionWorkDir()`（N+1） | 直接使用 `s.workDir`（已由 `listSessions()` 返回） |

**评估：本地更优** ⭐ 消除不必要的 N+1 查询。

---

## 17. `DirectoryPicker.tsx` — 文件夹选择缓存失效

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| 选择后缓存 | 保留旧缓存 | 清空缓存并重置模式 |

**评估：本地更优** ⭐ 确保选择文件夹后下拉菜单立即显示正确内容。

---

## 18. `providerPresets.json` — 自定义预设默认格式

| 方面 | 上游 | 本地分支 |
|------|------|----------|
| Custom preset 默认格式 | `anthropic` | `openai_chat` |

**评估：有争议** ⚖️

改为 `openai_chat` 符合本项目的 DeepSeek API 使用场景，但 `Custom` 本应是通用预设，更改默认值可能让想添加 Anthropic 兼容提供商的用户困惑。

> **建议**：可保留 `openai_chat` 作为默认（因为本项目的目标用户主要使用 OpenAI 兼容 API），但需在 UI 中提示。

---

## 19. `build-windows-x64.ps1` — 时间戳修复

**评估：本地更优** ⭐ 构建产物（sidecar 和 MSI）时间戳反映实际构建时间而非编译时间。

---

## 20. `package.json` — 项目结构生成脚本

**评估：工具补充，无影响**

```json
"scripts": {
  "generate:structure": "node scripts/generate-structure.mjs --depth 2"
}
```

不影响应用功能，仅开发辅助。

---

## 优化建议汇总

| # | 文件 | 问题 | 建议 |
|---|------|------|------|
| 1 | `Settings.tsx` | `ANTHROPIC_AUTH_TOKEN` 忽略了 preset 默认值 | 恢复 upstream 的 `defaultEnv?.ANTHROPIC_AUTH_TOKEN` 回退 |
| 2 | `ws/handler.ts` | `resolveSessionWorkDir` 返回 `''` 而非 `os.homedir()` | 恢复 `os.homedir()` 回退 |
| 3 | `Sidebar.tsx` | `catch {}` 静默吞掉错误 | 添加 `console.warn` 日志 |
| 4 | `ChatInput.tsx` | `clearSelection` + `setSelection` 多余 | 恢复使用 `moveSelection` |
| 5 | `settingsStore.ts` | `fetchAll()` 中的 `updateUser()` 可能造成读写循环 | 移除 `fetchAll()` 中的写入逻辑 |
