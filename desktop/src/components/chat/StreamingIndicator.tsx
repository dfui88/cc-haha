import { useChatStore } from '../../stores/chatStore'
import { useTranslation } from '../../i18n'
import type { TranslationKey } from '../../i18n/locales/en'

function formatElapsed(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}m ${s}s`
}

export function StreamingIndicator() {
  const { chatState, statusVerb, elapsedSeconds, tokenUsage } = useChatStore()
  const t = useTranslation()

  // Translate known server-sent verbs (e.g. "Thinking", "Task started")
  let verb: string
  if (statusVerb) {
    const serverKey = `serverVerb.${statusVerb}` as TranslationKey
    const translated = t(serverKey)
    verb = translated !== serverKey ? translated : statusVerb
  } else {
    verb = chatState === 'thinking' ? t('streaming.thinking') : chatState === 'tool_executing' ? t('streaming.running') : t('streaming.working')
  }

  return (
    <div className="mb-2 ml-10 flex w-fit items-center gap-2 rounded-full border border-[var(--color-border)]/40 bg-[var(--color-surface-container-low)] px-3 py-1">
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
