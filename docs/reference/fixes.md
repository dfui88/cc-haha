# 相对于原始泄露源码的修复


泄露的源码无法直接运行，主要修复了以下问题：

| 问题 | 根因 | 修复 |
|------|------|------|
| TUI 不启动 | 入口脚本把无参数启动路由到了 recovery CLI | 恢复走 `cli.tsx` 完整入口 |
| 启动卡死 | `verify` skill 导入缺失的 `.md` 文件，Bun text loader 无限挂起 | 创建 stub `.md` 文件 |
| `--print` 卡死 | `filePersistence/types.ts` 缺失 | 创建类型桩文件 |
| `--print` 卡死 | `ultraplan/prompt.txt` 缺失 | 创建资源桩文件 |
| **Enter 键无响应** | `modifiers-napi` native 包缺失，`isModifierPressed()` 抛异常导致 `handleEnter` 中断，`onSubmit` 永远不执行 | 加 try-catch 容错 |
| setup 被跳过 | `preload.ts` 自动设置 `LOCAL_RECOVERY=1` 跳过全部初始化 | 移除默认设置 |
| **CLI 启动失败 (Desktop)** | `shouldStripInheritedProviderEnv(null)` 中 `providerId !== undefined` 把 `null` 当作有效 provider，清空了全部认证环境变量 | 改为 `typeof providerId === 'string'`（`conversationService.ts:727`） |
| **settings.json 被覆盖** | `updateManagedSettings()` 使用 `Object.assign` 盲目合并，前端原始 JSON 编辑器写入的 `ACTIVE_PROVIDER`、顶层 `ANTHROPIC_*` 等过期 key 被持久化到文件 | 添加 `STALE_SETTINGS_KEYS` 黑名单 + 自动剥离顶层 `ANTHROPIC_*` key（`providerService.ts`） |
| **自动更新地址更新** | Desktop Tauri 更新器指向 `NanmiCoder/cc-haha`，更新日志指向 `anthropics/claude-code` | 全部改为 `dfui88/cc-haha`（`tauri.conf.json`、`releaseNotes.ts`、`Settings.tsx`、`Sidebar.tsx`） |
