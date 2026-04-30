/**
 * IM 适配器公共辅助函数
 *
 * 消除 telegram 和 feishu 适配器之间重复的 ensureExistingSession、
 * buildStatusText 等逻辑。
 */

import * as path from 'node:path'
import { WsBridge, type ServerMessage } from './ws-bridge.js'
import { SessionStore } from './session-store.js'
import { AdapterHttpClient } from './http-client.js'
import { formatImStatus } from './format.js'

/** IM 适配器共享的 chat 运行时状态。 */
export type ChatRuntimeState = {
  state: 'idle' | 'thinking' | 'streaming' | 'tool_executing' | 'permission_pending'
  verb?: string
  model?: string
  pendingPermissionCount: number
}

/**
 * 确保与服务端的 WebSocket 会话已建立。
 * 幂等：已有活跃会话时直接返回。
 */
export async function ensureExistingSession(
  sessionStore: SessionStore,
  bridge: WsBridge,
  chatId: string,
  onMessage: (msg: ServerMessage) => void,
): Promise<{ sessionId: string; workDir: string } | null> {
  const stored = sessionStore.get(chatId)
  if (!stored) return null

  if (!bridge.hasSession(chatId)) {
    bridge.connectSession(chatId, stored.sessionId)
    bridge.onServerMessage(chatId, onMessage)
    const opened = await bridge.waitForOpen(chatId)
    if (!opened) return null
  }

  return stored
}

/**
 * 构建 IM 状态文字（项目名、分支、任务计数、运行时状态）。
 *
 * 由各适配器的 thin wrapper 调用，wrapper 负责提供 session 和 runtime。
 */
export async function buildStatusText(
  httpClient: AdapterHttpClient,
  stored: { sessionId: string; workDir: string } | null,
  runtime: ChatRuntimeState,
): Promise<string> {
  if (!stored) return formatImStatus(null)

  let projectName = path.basename(stored.workDir) || stored.workDir
  let branch: string | null = null

  try {
    const gitInfo = await httpClient.getGitInfo(stored.sessionId)
    projectName = gitInfo.repoName || path.basename(gitInfo.workDir) || projectName
    branch = gitInfo.branch
  } catch {
    // Ignore git lookup failures and fall back to stored workDir
  }

  let taskCounts:
    | {
        total: number
        pending: number
        inProgress: number
        completed: number
      }
    | undefined

  try {
    const tasks = await httpClient.getTasksForSession(stored.sessionId)
    if (tasks.length > 0) {
      let pending = 0
      let inProgress = 0
      let completed = 0
      for (const t of tasks) {
        if (t.status === 'pending') pending++
        else if (t.status === 'in_progress') inProgress++
        else if (t.status === 'completed') completed++
      }
      taskCounts = { total: tasks.length, pending, inProgress, completed }
    }
  } catch {
    // Ignore task lookup failures in IM status summary
  }

  return formatImStatus({
    sessionId: stored.sessionId,
    projectName,
    branch,
    model: runtime.model,
    state: runtime.state,
    verb: runtime.verb,
    pendingPermissionCount: runtime.pendingPermissionCount,
    taskCounts,
  })
}
