# Fixes Compared with the Original Leaked Source


The leaked source could not run directly. This repository mainly fixes the following issues:

| Issue | Root cause | Fix |
|------|------|------|
| TUI does not start | The entry script routed no-argument startup to the recovery CLI | Restored the full `cli.tsx` entry |
| Startup hangs | The `verify` skill imports a missing `.md` file, causing Bun's text loader to hang indefinitely | Added stub `.md` files |
| `--print` hangs | `filePersistence/types.ts` was missing | Added type stub files |
| `--print` hangs | `ultraplan/prompt.txt` was missing | Added resource stub files |
| **Enter key does nothing** | The `modifiers-napi` native package was missing, `isModifierPressed()` threw, `handleEnter` was interrupted, and `onSubmit` never ran | Added try/catch fault tolerance |
| Setup was skipped | `preload.ts` automatically set `LOCAL_RECOVERY=1`, skipping all initialization | Removed the default setting |
| **CLI startup failure (Desktop)** | `shouldStripInheritedProviderEnv(null)` treated `null` as a valid provider ID via `providerId !== undefined`, stripping all auth env vars | Changed to `typeof providerId === 'string'` (`conversationService.ts:727`) |
| **CLI startup failure (Desktop) — root cause** | `getRuntimeSettings()` in `handler.ts` had an unresolved Git merge conflict where `providerId: activeId` was wrapped in `<<<<<<< Updated upstream / ======= / >>>>>>> Stashed changes`, so `providerId` was never returned | Removed merge conflict markers, restored `providerId: activeId` (`handler.ts:1325`) |
| **settings.json corruption** | `updateManagedSettings()` used blind `Object.assign` merge; stale keys like `ACTIVE_PROVIDER` and top-level `ANTHROPIC_*` from the raw JSON editor were persisted | Added `STALE_SETTINGS_KEYS` blacklist + auto-strip top-level `ANTHROPIC_*` keys (`providerService.ts`) |
| **Auto-update URL updated** | Desktop Tauri updater pointed to `NanmiCoder/cc-haha`, changelog fetcher pointed to `anthropics/claude-code` | All changed to `dfui88/cc-haha` (`tauri.conf.json`, `releaseNotes.ts`, `Settings.tsx`, `Sidebar.tsx`) |
