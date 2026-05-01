// Runs frontend build (tsc + vite) and sidecar build in parallel.
// Called by Tauri's beforeBuildCommand hook.
// Cross-platform: works on Windows, macOS, Linux (requires Node.js).

import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(__dirname, '..')

function run(label, command) {
  return new Promise((resolve) => {
    console.log(`[build-before] Starting: ${label}`)
    const proc = spawn(command, {
      cwd: projectRoot,
      stdio: 'inherit',
      shell: true,
    })
    const start = Date.now()
    proc.on('exit', (code) => {
      const elapsed = ((Date.now() - start) / 1000).toFixed(1)
      if (code === 0) {
        console.log(`[build-before] Completed: ${label} (${elapsed}s)`)
      } else {
        console.error(`[build-before] FAILED: ${label} (exit ${code}, ${elapsed}s)`)
      }
      resolve(code ?? 1)
    })
  })
}

const exitCodes = await Promise.all([
  run('sidecar build', 'bun run build:sidecars'),
  run('frontend build', 'bun run build'),
])

const maxExit = Math.max(...exitCodes)
if (maxExit !== 0) {
  console.error(`[build-before] One or more builds failed (exit codes: ${exitCodes.join(', ')})`)
}
process.exit(maxExit)
