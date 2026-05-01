# Claude Code Haha Desktop

基于 Tauri 2 + React 的桌面客户端。

## 开发

```bash
bun install
bun run tauri dev
```

## 构建

```bash
# macOS (Apple Silicon)
./scripts/build-macos-arm64.sh

# Windows (x64, MSI only)
.\scripts\build-windows-x64.ps1
```

构建产物位于 `build-artifacts/` 目录，文件名会显式包含平台、架构和包类型。

### Windows 构建规则

1. **固定 GUID** — WiX `upgradeCode` 固定为 `5239b781-4d78-504f-8bff-4b9d88752c74`，确保版本间无缝升级
2. **智能安装跳过** — `node_modules` 已存在时跳过 `bun install`（`FORCE_INSTALL=1` 强制重装）
3. **并行构建** — 前端与 sidecar 通过 `build-before.mjs` 并行构建
4. **构建完成通知** — 系统通知音 + Windows Toast 通知 + 绿色 BUILD COMPLETE! 横幅（含版本号和耗时）
5. **版本自动递增** — 每次构建自动增加 patch 版本号
6. **自动生成修复说明** — 构建前在输出目录生成中文 `fix+版本号.txt` 和英文 `BUILD_NOTES.txt`（防超时保险），构建完成后用实际 MSI 路径覆盖更新
7. **响应超时保护** — 前端超时设为 30 分钟，防止长时间构建触发超时错误

## 注意事项

编辑构建脚本时，请先阅读项目根目录 `CLAUDE.md` 的「注意事项」一节，了解 PowerShell 陷阱（`try`/`catch` 配对、中文编码处理、非交互模式挂起等）。

## 常见问题

### macOS 提示"已损坏，无法打开"

```bash
xattr -cr /Applications/Claude\ Code\ Haha.app
```
