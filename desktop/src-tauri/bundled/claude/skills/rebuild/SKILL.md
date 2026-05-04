---
name: rebuild
description: Windows 桌面端 MSI 打包构建：版本递增、并行编译、WiX 打包、修复说明生成、超时保护
---

# 重新构建（Windows 打包）

## 用途

自动化构建 Claude Code Haha Windows 桌面端 MSI 安装包。当用户说 **"重新构建"** 时执行完整的构建流水线。

## 执行流程

### 1. 确认版本
- 读取 `desktop/src-tauri/tauri.conf.json` 中的当前版本号

### 2. 运行构建脚本
```bash
cd desktop && .\scripts\build-windows-x64.ps1
```

### 3. 验证构建产物
- 确认 MSI 安装包已生成到 `build-artifacts/windows-x64/`
- 确认 `fix+版本号.txt` 已生成且内容正确
- 确认版本号已递增（patch +1）

---

## Windows 构建规则（8 条）

### 规则 1：固定 GUID
WiX 安装包的 `upgradeCode` 始终固定为 `5239b781-4d78-504f-8bff-4b9d88752c74`，确保同一产品的所有版本使用同一个 GUID，实现无缝升级覆盖。

### 规则 2：智能安装跳过
若 `desktop/node_modules`、源码根目录及适配器的 `node_modules` 均已存在，则跳过 `bun install`。设置环境变量 `FORCE_INSTALL=1` 可强制重新安装依赖。

### 规则 3：并行构建
通过 `desktop/scripts/build-before.mjs` 并行执行 `bun run build`（前端 `tsc -b && vite build`）和 `bun run build:sidecars`。

### 规则 4：构建完成通知
构建完成后执行：
- 播放系统通知音（`SystemSounds.Asterisk`）
- Windows 10/11 Toast 通知（显示版本号和耗时，5 秒自动消失）
- 控制台打印绿色 `BUILD COMPLETE!` 横幅
- 自动打开输出目录 `build-artifacts/windows-x64/`

### 规则 5：MSI 自动增加版本号
每次构建前自动将 `tauri.conf.json`、`package.json`、`Cargo.toml` 中的 patch 版本号 +1。

### 规则 6：自动生成修复说明
构建过程中生成 `fix+版本号.txt`（中文修复说明）和 `BUILD_NOTES.txt`（英文构建笔记）：
- **阶段 1（构建前）**：在 `cargo tauri build` 前先写入占位文件（防超时保险）
- **阶段 2（构建后）**：用实际 MSI 路径覆盖更新
- 修复内容通过 `$env:FIX_NOTES` 环境变量传入（分号分隔多条）

### 规则 7：响应超时保护
`desktop/src/stores/chatStore.ts` 中 `RESPONSE_TIMEOUT_MS` 设为 30 分钟，防止长时间构建超时。

### 规则 8：更新文档
构建规则变化时同步更新 `CLAUDE.md` 和 `desktop/README.md`。

---

## 注意事项（PowerShell 陷阱）

### 1. `try` 必须配套 `catch` 或 `finally`
PowerShell 不允许裸露的 `try { }` 块：
```powershell
# 错误
try { Do-Something }
# 正确
try { Do-Something } catch { Write-Step "Error: $_" }
```

### 2. 中文文本编辑：用数组索引而非 `-replace`
PowerShell 的 `-replace` 在处理中文时可能损坏编码：
```powershell
# 正确
$lines = Get-Content $path
$lines[42] = '  "version": "1.0.0"'
$lines | Set-Content $path
```

### 3. `Read-Host` 在非交互模式下永久挂起
必须在调用前确保存在环境变量兜底：
```powershell
if (-not $env:MY_INPUT) { $env:MY_INPUT = 'default' }
```

### 4. PowerShell cmdlet 错误：用 `-ErrorAction` 而非 `2>$null`
```powershell
Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
```

### 5. Bash 工具 10 分钟超时限制
关键文件在 cargo build 之前写入，post-build 只做覆盖更新。

### 6. `Resolve-OutputDirectory` 清空输出目录
该函数会删除输出目录中所有现有文件。确保只在写入 notes 之前调用一次。

---

## 关键文件

| 文件 | 用途 |
|------|------|
| `desktop/scripts/build-windows-x64.ps1` | 主构建脚本 |
| `desktop/scripts/build-before.mjs` | 并行编译协调器 |
| `desktop/src-tauri/tauri.conf.json` | Tauri 配置（版本号、资源、GUID） |
| `desktop/src-tauri/bundled/claude/` | 打包进 MSI 的资源目录 |

## 环境变量

| 变量 | 用途 |
|------|------|
| `FIX_NOTES` | 分号分隔的修复说明 |
| `FORCE_INSTALL=1` | 强制重新安装 npm 依赖 |
| `TAURI_SIGNING_PRIVATE_KEY` | 代码签名密钥（未设置时跳过签名） |
