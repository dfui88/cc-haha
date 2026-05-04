// Source: src/server/api/models.ts, src/server/api/settings.ts

export type PermissionMode = 'default' | 'acceptEdits' | 'plan' | 'bypassPermissions' | 'dontAsk'

export type EffortLevel = 'low' | 'medium' | 'high' | 'max'
export type ThemeMode = 'light' | 'dark'

export type WebSearchMode = 'auto' | 'tavily' | 'brave' | 'anthropic' | 'disabled'

export type WebSearchSettings = {
  mode: WebSearchMode
  tavilyApiKey?: string
  braveApiKey?: string
}

export type ModelInfo = {
  id: string
  name: string
  description: string
  context: string
}

export type UserSettings = {
  model?: string
  modelContext?: string
  effort?: EffortLevel
  permissionMode?: PermissionMode
  theme?: ThemeMode
  skipWebFetchPreflight?: boolean
  alwaysThinkingEnabled?: boolean
  webSearch?: WebSearchSettings
  [key: string]: unknown
}
