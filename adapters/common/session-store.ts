import * as fs from 'node:fs/promises'
import * as fsSync from 'node:fs'
import * as path from 'node:path'
import * as os from 'node:os'

export type SessionEntry = {
  sessionId: string
  workDir: string
  updatedAt: number
}

type StoreData = Record<string, SessionEntry>

function getDefaultPath(): string {
  const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude')
  return path.join(configDir, 'adapter-sessions.json')
}

export class SessionStore {
  private data: StoreData
  private filePath: string
  private dirty = false
  private saveScheduled = false

  constructor(filePath?: string) {
    this.filePath = filePath ?? getDefaultPath()
    this.data = this.loadSync()
  }

  get(chatId: string): SessionEntry | null {
    return this.data[chatId] ?? null
  }

  set(chatId: string, sessionId: string, workDir: string): void {
    this.data[chatId] = { sessionId, workDir, updatedAt: Date.now() }
    this.scheduleSave()
  }

  delete(chatId: string): void {
    delete this.data[chatId]
    this.scheduleSave()
  }

  listAll(): Array<{ chatId: string } & SessionEntry> {
    return Object.entries(this.data).map(([chatId, entry]) => ({ chatId, ...entry }))
  }

  /** Force an immediate synchronous write to disk. Use only when a crash-safe
   *  barrier is needed (e.g. before a long operation where loss is unacceptable). */
  flushSync(): void {
    if (!this.dirty) return
    this.dirty = false
    this.saveScheduled = false
    const dir = path.dirname(this.filePath)
    fsSync.mkdirSync(dir, { recursive: true })
    const tmp = `${this.filePath}.tmp.${Date.now()}`
    fsSync.writeFileSync(tmp, JSON.stringify(this.data) + '\n', 'utf-8')
    fsSync.renameSync(tmp, this.filePath)
  }

  private loadSync(): StoreData {
    try {
      return JSON.parse(fsSync.readFileSync(this.filePath, 'utf-8'))
    } catch {
      return {}
    }
  }

  private scheduleSave(): void {
    this.dirty = true
    if (this.saveScheduled) return
    this.saveScheduled = true
    queueMicrotask(() => this.flushSave())
  }

  private async flushSave(): Promise<void> {
    this.saveScheduled = false
    if (!this.dirty) return
    this.dirty = false
    try {
      const dir = path.dirname(this.filePath)
      await fs.mkdir(dir, { recursive: true }).catch(() => {})
      const tmp = `${this.filePath}.tmp.${Date.now()}`
      await fs.writeFile(tmp, JSON.stringify(this.data) + '\n', 'utf-8')
      await fs.rename(tmp, this.filePath)
    } catch {
      // Non-critical cache write; swallow errors silently.
    }
  }
}
