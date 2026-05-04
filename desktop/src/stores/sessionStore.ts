import { create } from 'zustand'
import { sessionsApi } from '../api/sessions'
import { useSessionRuntimeStore } from './sessionRuntimeStore'
import type { SessionListItem } from '../types/session'

// Monotonic counter to invalidate stale fetchSessions responses.
// Each call increments; only the latest (highest id) gets to set state.
let _fetchRequestId = 0
// Debounce timer coalescing rapid createSession → fetchSessions calls.
let _fetchTimeout: ReturnType<typeof setTimeout> | undefined

type SessionStore = {
  sessions: SessionListItem[]
  activeSessionId: string | null
  isLoading: boolean
  error: string | null
  selectedProjects: string[]
  availableProjects: string[]
  serverReady: boolean

  fetchSessions: (project?: string) => Promise<void>
  createSession: (workDir?: string, title?: string) => Promise<string>
  deleteSession: (id: string) => Promise<void>
  renameSession: (id: string, title: string) => Promise<void>
  updateSessionTitle: (id: string, title: string) => void
  setActiveSession: (id: string | null) => void
  setSelectedProjects: (projects: string[]) => void
  setServerReady: () => void
}

export const useSessionStore = create<SessionStore>((set, get) => ({
  sessions: [],
  activeSessionId: null,
  isLoading: false,
  error: null,
  selectedProjects: [],
  availableProjects: [],
  serverReady: false,

  fetchSessions: async (project?: string) => {
    const reqId = ++_fetchRequestId
    set({ isLoading: true, error: null })
    try {
      const { sessions: raw } = await sessionsApi.list({ project, limit: 100 })
      // Stale response — a newer fetchSessions has already started
      if (reqId !== _fetchRequestId) return

      // Deduplicate by session ID — keep the most recently modified entry
      const byId = new Map<string, SessionListItem>()
      for (const s of raw) {
        const existing = byId.get(s.id)
        if (!existing || new Date(s.modifiedAt) > new Date(existing.modifiedAt)) {
          byId.set(s.id, s)
        }
      }

      // Merge with local store to prevent data loss in race conditions:
      // 1. Preserve local optimistic sessions not yet returned by server
      // 2. When a session exists in both, prefer local workDir if server's
      //    is null — this prevents losing workDir when earlier fetchSessions
      //    completes after a later one has already set it correctly
      // 3. Prefer local title if server still shows the default — this handles
      //    the case where renameSession hasn't propagated to the server yet
      const currentSessions = get().sessions
      for (const s of currentSessions) {
        if (byId.has(s.id)) {
          const serverSession = byId.get(s.id)!
          const merged = { ...serverSession }
          let changed = false
          if (!serverSession.workDir && s.workDir) {
            merged.workDir = s.workDir
            merged.workDirExists = s.workDirExists
            changed = true
          }
          if ((serverSession.title === 'Untitled Session' || serverSession.title === 'New Session') && s.title && s.title !== 'Untitled Session' && s.title !== 'New Session') {
            merged.title = s.title
            changed = true
          }
          if (changed) {
            byId.set(s.id, merged)
          }
        } else {
          byId.set(s.id, s)
        }
      }
      const sessions = [...byId.values()]
      const availableProjects = [...new Set(sessions.map((s) => s.projectPath).filter(Boolean))].sort()

      // Double-check freshness before applying state
      if (reqId !== _fetchRequestId) return
      set({ sessions, availableProjects, isLoading: false })
    } catch (err) {
      if (reqId === _fetchRequestId) {
        set({ error: (err as Error).message, isLoading: false })
      }
    }
  },

  createSession: async (workDir?: string, title?: string) => {
    const { sessionId: id } = await sessionsApi.create(workDir || undefined)
    const now = new Date().toISOString()
    const optimisticSession: SessionListItem = {
      id,
      title: title || 'New Session',
      createdAt: now,
      modifiedAt: now,
      messageCount: 0,
      projectPath: '',
      workDir: workDir ?? null,
      workDirExists: true,
    }

    set((state) => ({
      sessions: state.sessions.some((session) => session.id === id)
        ? state.sessions
        : [optimisticSession, ...state.sessions],
      activeSessionId: id,
    }))

    // Debounce: coalesce rapid createSession calls into a single fetch
    clearTimeout(_fetchTimeout)
    _fetchTimeout = setTimeout(() => get().fetchSessions(), 300)
    return id
  },

  deleteSession: async (id: string) => {
    await sessionsApi.delete(id)
    useSessionRuntimeStore.getState().clearSelection(id)
    set((s) => ({
      sessions: s.sessions.filter((session) => session.id !== id),
      activeSessionId: s.activeSessionId === id ? null : s.activeSessionId,
    }))
  },

  renameSession: async (id: string, title: string) => {
    await sessionsApi.rename(id, title)
    set((s) => ({
      sessions: s.sessions.map((session) =>
        session.id === id ? { ...session, title } : session,
      ),
    }))
  },

  updateSessionTitle: (id, title) => {
    set((s) => ({
      sessions: s.sessions.map((session) =>
        session.id === id ? { ...session, title } : session,
      ),
    }))
  },

  setActiveSession: (id) => set({ activeSessionId: id }),
  setSelectedProjects: (projects) => set({ selectedProjects: projects }),
  setServerReady: () => {
    set({ serverReady: true })
    // Server 就绪后立即加载会话列表，此时 baseUrl 已正确设置
    get().fetchSessions()
  },
}))
