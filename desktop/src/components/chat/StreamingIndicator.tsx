import { useTranslation } from '../../i18n'
import { useChatStore } from '../../stores/chatStore'
import { useTabStore } from '../../stores/tabStore'

/** Maps server status verbs to i18n keys for translation */
const SERVER_VERB_KEYS: Record<string, string> = {
  'Thinking': 'streaming.thinking',
  'Restarting session with new permissions...': 'streaming.restarting_session',
  'Switching provider and model...': 'streaming.switching_provider',
  'Task started': 'streaming.task_started',
  'Task in progress': 'streaming.task_in_progress',
}

function formatElapsed(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}m ${s}s`
}

export function StreamingIndicator() {
  const t = useTranslation()
  const activeTabId = useTabStore((s) => s.activeTabId)
  const sessionState = useChatStore((s) => activeTabId ? s.sessions[activeTabId] : undefined)
  const chatState = sessionState?.chatState ?? 'idle'
  const statusVerb = sessionState?.statusVerb ?? ''
  const elapsedSeconds = sessionState?.elapsedSeconds ?? 0
  const tokenUsage = sessionState?.tokenUsage ?? { input_tokens: 0, output_tokens: 0 }
  let verb: string
  if (statusVerb) {
    // Try to translate known server status verbs (e.g. "Task started" → "任务已启动")
    const i18nKey = SERVER_VERB_KEYS[statusVerb]
    verb = i18nKey ? t(i18nKey as any) : statusVerb
  } else {
    verb = chatState === 'thinking' ? t('streaming.thinking') : chatState === 'tool_executing' ? t('streaming.running') : t('streaming.working')
  }

  return (
    <div className="mb-2 flex w-fit items-center gap-2 rounded-full border border-[var(--color-border)]/40 bg-[var(--color-surface-container-low)] px-3 py-1">
      <span className="text-[var(--color-brand)] animate-shimmer text-xs">✦</span>
      <span className="text-xs font-medium text-[var(--color-text-secondary)]">{verb}...</span>
      {elapsedSeconds > 0 && (
        <span className="text-[10px] text-[var(--color-text-tertiary)]">
          {formatElapsed(elapsedSeconds)}
        </span>
      )}
      {tokenUsage.output_tokens > 0 && (
        <span className="text-[10px] text-[var(--color-text-tertiary)]">
          · ↓ {tokenUsage.output_tokens}
        </span>
      )}
    </div>
  )
}
