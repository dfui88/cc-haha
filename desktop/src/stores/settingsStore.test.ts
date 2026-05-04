import { beforeEach, describe, expect, it, vi } from 'vitest'

const updateUserMock = vi.fn()

vi.mock('../api/settings', () => ({
  settingsApi: {
    getUser: vi.fn(),
    updateUser: (...args: unknown[]) => updateUserMock(...args),
    getPermissionMode: vi.fn(),
    setPermissionMode: vi.fn(),
    getCliLauncherStatus: vi.fn(),
  },
}))

vi.mock('../api/models', () => ({
  modelsApi: {
    list: vi.fn(),
    getCurrent: vi.fn(),
    getEffort: vi.fn(),
    setCurrent: vi.fn(),
    setEffort: vi.fn(),
  },
}))

vi.mock('./uiStore', () => ({
  useUIStore: {
    getState: () => ({ setTheme: vi.fn() }),
  },
}))

describe('settingsStore locale defaults', () => {
  beforeEach(() => {
    vi.resetModules()
    window.localStorage.clear()
    updateUserMock.mockReset()
  })

  it('defaults to Chinese when no locale is stored', async () => {
    const { useSettingsStore } = await import('./settingsStore')

    expect(useSettingsStore.getState().locale).toBe('zh')
  })

  it('keeps a stored locale override', async () => {
    window.localStorage.setItem('cc-haha-locale', 'en')

    const { useSettingsStore } = await import('./settingsStore')

    expect(useSettingsStore.getState().locale).toBe('en')
  })
})

describe('settingsStore thinkingEnabled', () => {
  beforeEach(async () => {
    vi.resetModules()
    updateUserMock.mockReset()
    updateUserMock.mockResolvedValue({ ok: true })
  })

  it('defaults to true', async () => {
    const { useSettingsStore } = await import('./settingsStore')
    expect(useSettingsStore.getState().thinkingEnabled).toBe(true)
  })

  it('setThinkingEnabled applies optimistic update and reverts on failure', async () => {
    updateUserMock.mockRejectedValueOnce(new Error('API error'))
    const { useSettingsStore } = await import('./settingsStore')

    // Initial state
    useSettingsStore.setState({ thinkingEnabled: true })

    // Optimistic update
    await useSettingsStore.getState().setThinkingEnabled(false)

    // Should have rolled back on API failure
    expect(useSettingsStore.getState().thinkingEnabled).toBe(true)
    expect(updateUserMock).toHaveBeenCalledWith({ alwaysThinkingEnabled: false })
  })

  it('setThinkingEnabled persists when API succeeds', async () => {
    updateUserMock.mockResolvedValue({ ok: true })
    const { useSettingsStore } = await import('./settingsStore')

    useSettingsStore.setState({ thinkingEnabled: true })
    await useSettingsStore.getState().setThinkingEnabled(false)

    expect(useSettingsStore.getState().thinkingEnabled).toBe(false)
  })
})

describe('settingsStore webSearch', () => {
  beforeEach(async () => {
    vi.resetModules()
    updateUserMock.mockReset()
    updateUserMock.mockResolvedValue({ ok: true })
  })

  it('has correct default', async () => {
    const { useSettingsStore } = await import('./settingsStore')
    expect(useSettingsStore.getState().webSearch).toEqual({
      mode: 'auto',
      tavilyApiKey: '',
      braveApiKey: '',
    })
  })

  it('setWebSearch applies optimistic update and reverts on failure', async () => {
    updateUserMock.mockRejectedValueOnce(new Error('API error'))
    const { useSettingsStore } = await import('./settingsStore')
    const defaultSearch = { mode: 'auto' as const, tavilyApiKey: '', braveApiKey: '' }
    useSettingsStore.setState({ webSearch: defaultSearch })

    await useSettingsStore.getState().setWebSearch({ mode: 'disabled' })

    expect(useSettingsStore.getState().webSearch).toEqual(defaultSearch)
    expect(updateUserMock).toHaveBeenCalledWith({ webSearch: { mode: 'disabled' } })
  })

  it('setWebSearch persists when API succeeds', async () => {
    const { useSettingsStore } = await import('./settingsStore')
    useSettingsStore.setState({ webSearch: { mode: 'auto', tavilyApiKey: '', braveApiKey: '' } })

    await useSettingsStore.getState().setWebSearch({ mode: 'brave', braveApiKey: 'key123' })

    expect(useSettingsStore.getState().webSearch).toEqual({ mode: 'brave', braveApiKey: 'key123' })
  })
})
