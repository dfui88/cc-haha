# Claude Code Haha 项目指令

## 重新构建命令（Windows 打包）

当用户输入 **重新构建** 时，自动执行以下 Windows 桌面端打包流程，严格遵循构建规则：

### 执行流程

1. **确认版本**
   - 读取 `desktop/src-tauri/tauri.conf.json` 中的当前版本号

2. **运行构建脚本**
   ```bash
   cd desktop && .\scripts\build-windows-x64.ps1
   ```
   - 脚本自动执行规则 1~6：
     - **规则 1** — 固定 `upgradeCode` 为 `5239b781-4d78-504f-8bff-4b9d88752c74`
     - **规则 2** — 智能安装：若 `node_modules` 已存在则跳过 `bun install`（设 `FORCE_INSTALL=1` 强制重装）
     - **规则 3** — 前端构建（`tsc -b && vite build`）与 sidecar 构建并行执行，通过 `build-before.mjs` 协调
     - **规则 4** — 自动将 `tauri.conf.json`、`package.json`、`Cargo.toml` 的 patch 版本 +1
     - **规则 5** — 构建完成后：播放系统通知音、弹出 Windows Toast 通知、显示绿色 BUILD COMPLETE! 横幅（含版本号和耗时）、自动打开输出目录
     - **规则 6** — 在 `build-artifacts/windows-x64/` 中生成 `fix+新版本号.txt`（中文修复说明）和 `BUILD_NOTES.txt`（英文构建笔记）。Notes 文件在 `cargo build` **之前**提前生成（防超时保险），构建完成后用实际 MSI 路径覆盖更新

3. **验证构建产物**
   - 确认 MSI 安装包已生成
   - 确认 `fix+版本号.txt` 已生成且内容正确
   - 确认版本号已递增

4. **更新说明文档（规则 8）**
   - 如果构建规则有任何变化，同步更新本文件（CLAUDE.md）和 `desktop/README.md`

### Windows 构建规则（8 条）

每次运行 `desktop/scripts/build-windows-x64.ps1` 时，自动执行以下规则：

### 1. 固定 GUID
WiX 安装包的 `upgradeCode` 始终固定为 `5239b781-4d78-504f-8bff-4b9d88752c74`，确保同一产品的所有版本使用同一个 GUID，实现无缝升级覆盖。

### 2. 智能安装跳过
若 `desktop/node_modules`、源码根目录及适配器的 `node_modules` 均已存在，则跳过 `bun install`，减少重复安装时间。设置环境变量 `FORCE_INSTALL=1` 可强制重新安装依赖。

### 3. 并行构建
通过 `desktop/scripts/build-before.mjs` 并行执行 `bun run build`（前端 `tsc -b && vite build`）和 `bun run build:sidecars`，`tauri.conf.json` 的 `beforeBuildCommand` 已改为 `node scripts/build-before.mjs`。

### 4. 构建完成通知
构建完成后执行：
- 播放系统通知音（`SystemSounds.Asterisk`）
- Windows 10/11 Toast 通知（显示版本号和耗时，5 秒自动消失）
- 控制台打印绿色 `BUILD COMPLETE!` 横幅（含版本号和耗时）
- 自动在文件管理器中打开 `build-artifacts/windows-x64/` 输出目录

### 5. MSI 自动增加版本号
每次构建前，自动将 `tauri.conf.json`、`package.json`、`Cargo.toml` 中的版本号 patch 位 +1，确保每个 MSI 安装包具有唯一的版本号，便于用户区分和 Windows 识别更新。

### 6. 自动生成修复说明（fix+版本号.txt）
构建过程中，在输出目录自动生成 `fix+版本号.txt`（例如 `fix+0.1.22.txt`），内容为中文，包含：
- 版本号、构建时间、目标平台
- Git 分支和提交信息
- 构建工具版本（Bun、Rust）
- MSI 安装包路径
- 系统要求和安装说明

Notes 文件分两阶段生成：
- **阶段 1（构建前）**：在 `cargo tauri build` 执行前先生成带有占位 MSI 路径的版本，作为超时保险
- **阶段 2（构建后）**：构建完成后用实际 MSI 路径覆盖更新文件
- 这样即使 Bash 工具 10 分钟超时杀死进程，notes 文件仍然存在

### 7. 响应超时保护
`desktop/src/stores/chatStore.ts` 中 `RESPONSE_TIMEOUT_MS` 设为 30 分钟（`1_800_000 ms`），防止长时间构建过程中因无数据返回而触发前端超时错误。

### 8. 更新项目说明文档
每次构建规则发生变化时，同步更新本文件（CLAUDE.md）以及 `desktop/README.md` 中的构建说明，保持文档与构建脚本一致。

## 注意事项（避免常见错误）

编辑 `build-windows-x64.ps1` 时务必注意以下 PowerShell 陷阱：

### 1. `try` 必须配套 `catch` 或 `finally`
PowerShell 不允许裸露的 `try { }` 块，必须在同一作用域内紧跟 `catch {}` 或 `finally {}`，否则产生语法错误：
```powershell
# 错误 — 缺少 catch/finally
try {
  Do-Something
}

# 正确
try {
  Do-Something
} catch {
  Write-Step "Error: $_"
}
```

### 2. 中文文本编辑：用数组索引而非 `-replace`
PowerShell 的 `-replace` 操作符在匹配含中文的行时可能吞掉结尾引号，导致编码损坏：
```powershell
# 错误 — 可能吞掉结尾引号
$content -replace '("version"\s*:\s*)"[\d.]+"', '$1"1.0.0"'

# 正确 — 读取为数组，按行索引替换
$lines = Get-Content $path
$lines[42] = '  "version": "1.0.0"'
$lines | Set-Content $path
```

### 3. `Read-Host` 在非交互模式下永久挂起
当 stdin 不是 TTY（如 CI、Bash 工具调用）时，`Read-Host` 不会抛出异常，而是**无限挂起**。必须在调用前确保存在环境变量兜底：
```powershell
# 前置兜底
if (-not $env:MY_INPUT) { $env:MY_INPUT = 'default' }
# 然后再调用可能用到 Read-Host 的函数
```

### 4. PowerShell cmdlet 错误：用 `-ErrorAction` 而非 `2>$null`
PowerShell cmdlet 的错误输出不经过 stderr，`2>$null` 无法抑制。必须用 `-ErrorAction SilentlyContinue`：
```powershell
# 错误 — 2>$null 无效（结合 $ErrorActionPreference = 'Stop' 会抛出终止错误）
Get-CimInstance Win32_OperatingSystem 2>$null

# 正确
Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
```

### 5. Bash 工具 10 分钟超时限制
`cargo tauri build` 接近 10 分钟，加上编译和打包后，post-build 部分经常被超时杀死。**关键文件必须在 cargo build 之前写入**，post-build 只做覆盖更新。

### 6. `Resolve-OutputDirectory` 清空输出目录
该函数会删除输出目录中所有现有文件。如果在早期生成了 notes 文件后再调用它，notes 也会被删除。确保只在 **写入 notes 之前** 调用一次 `Resolve-OutputDirectory`。
