import { useTeamStore } from '../../stores/teamStore'
import { useTranslation } from '../../i18n'

export function BackToLeader() {
  const setViewingAgent = useTeamStore((s) => s.setViewingAgent)
  const t = useTranslation()

  return (
    <button
      onClick={() => setViewingAgent(null)}
      className="flex items-center gap-1 px-3 py-1.5 text-sm text-[var(--color-text-accent)] hover:underline transition-colors"
    >
      {t('teams.backToLeader')}
    </button>
  )
}
