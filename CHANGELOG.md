# Changelog

> 本文件记录项目的所有版本变更。通过 `git log --oneline --all` 自动维护。
> 格式基于 [Keep a Changelog](https://keepachangelog.com/)，版本号遵循 [SemVer](https://semver.org/)。

---

## [v0.2.0] — 质量门禁与基线系统

### 新增
- 质量门禁系统 — contributor 可选择质量门禁提供商，文档化 contributor 质量门禁流程
- live agent 基线测试 — 覆盖桌面聊天和编辑场景
- 导出诊断日志 — 改善桌面故障诊断

### 修复
- Windows 上保留历史工作区变更
- 防止会话侧边栏卡顿和标题抖动
- 阻止 DeepSeek 禁用 thinking 时的 effort 冲突
- 修复暗色主题下的浅色面板问题
- PR 合并保护 — 限域质量门禁

### 其他
- 桌面 0.2.0 里程碑发布准备

---

## [v0.1.9] — 工作区文件引用回滚与 WebSearch 修复

### 新增
- 工作区文件引用成为可回滚的聊天上下文
- 当前轮次变更可审查和撤销
- 会话工作区变更可审查

### 修复
- 隐藏空白的 assistant 气泡
- 恢复每轮次的变更文件卡片
- 保持工作区变更和会话检查点可靠
- 修复 WebSearch 保存按钮换行问题
- 从开始屏幕暴露桌面工作区工具
- 保持 WebSearch 在第三方模型上可用
- 防止第三方 thinking 模式不匹配
- 保持旧桌面会话在 Provider 变更后可用
- 增加 macOS 图标尺寸
- 保留桌面窗口位置跨重启
- 保持应用在关闭后继续在系统托盘运行
- 默认空工作区变更为文件树

---

## [v0.1.8] — 远程桌面与斜杠命令

### 新增
- 收紧 Provider 设置和支持链接
- 帮助用户配置赞助商和本地 Provider
- 在桌面标签页内保持终端工作流
- ESC 键关闭斜杠命令面板
- 斜杠命令在桌面终端外可用
- 文档化仓库分支命名策略

### 修复
- 保持检查器上下文响应
- 防止会话检查器上下文卡顿
- 保持桌面会话在活跃 Provider 运行时
- 保持 Provider 会话在兼容模型能力上
- 更新 Kimi 预设为 coding 端点
- 子代理工具活动嵌套在桌面对话中
- 恢复检查器中的上下文百分比
- 防止回滚修剪错误的轮次
- 防止桌面轮次在 CLI 退出后挂起
- 收紧斜杠命令边缘情况，对齐 CLI 行为
- 处理不可用的 ripgrep 路径
- 显示桌面服务器启动诊断
- 修复飞书 HTTP 超时

### 其他
- 文档更新：README 赞助商伙伴、参考项目致谢
- 发布说明完善

---

## [v0.1.7] — 滚动位置修复与 Mermaid 改进

### 修复
- 尊重手动聊天滚动位置
- 服务端预加载 Windows 开发 CLI 宏
- 抑制 Mermaid 错误覆盖层
- 桌面端：更新前停止 sidecar 进程

---

## [v0.1.6] — Provider 运行时与终端设置

### 新增
- 桌面设置终端（安全重启切换）
- 在桌面外暴露捆绑的 CLI
- MCP 重连进度在详情视图中可见

### 修复
- 删除安装中心
- MCP 工具在首轮对话前就绪
- 防止插件详情钩子不匹配导致重载
- 保持桌面聊天在选择 Provider 运行时
- 防止任务进度更新破坏流式回复格式
- 停止 Provider 模型选择继承全局 Claude 设置
- 保持内置 Provider 预设与供应商支持的模型 ID 对齐
- 减少侧边栏控制杂乱
- 防止破坏性操作绕过确认
- 避免 MCP 列表阻塞实时健康检查
- 修复墨水瓶缩放重影（清除滚动缓冲区）
- 保持助手侧对话内容在同一轨道
- 合并分段的助手文本块
- 恢复 Python 3.8 的计算机使用设置
- 统一插件能力与桌面管理视图
- 减少设置中的扩展配置摩擦

---

## [v0.1.5] — 首 Token 延迟优化与标签页拖拽

### 新增
- 自动化发布说明摄入
- 记录 v0.1.4 发布摘要

### 修复
- 减少 SDK URL 会话的首 token 延迟
- 恢复侧边栏项目过滤元数据和下拉层级
- 防止设置竞争条件和旧会话清理
- 防止空 @-file 菜单在文件系统访问失败时误导
- 保持 AskUserQuestion 流在规划模式不卡顿
- 标签页重排独立于原生 HTML 拖拽事件
- 保持 WebFetch 在第三方 Provider 可用
- 保持轮次中工具调用与最新用户消息对齐
- 保持 CLI 任务状态与会话对齐
- 完成的任务列表不泄露到下一轮次

---

## [v0.1.4] — 计算机使用修复与侧边栏改进

### 修复
- 改进 Windows 计算机使用和桌面渲染
- 侧边栏折叠可恢复且不窃取焦点
- 修复 macOS 发布构建中的代码块渲染
- 当会话标签填满标题栏时保持窗口可拖拽

---

## [v0.1.3] — 空会话斜杠命令发现与暗色主题

### 新增
- 桌面技能发现集成
- 可切换的桌面工作区暗色主题

### 修复
- 防止桌面计算机使用因缺少批准和文本输入不稳定而卡顿
- 对齐空会话编辑器，恢复项目技能发现

---

## [v0.1.2] — 签名更新与任务修复

### 新增
- 启用签名的桌面自更新用于发布测试

### 修复
- 允许关闭已完成的会话任务
- 修正 Windows 标签栏溢出对齐

---

## [v0.1.1] — Windows 修复版本

### 修复
- 停止将 Git Bash 视为 Windows 桌面会话的硬启动依赖
- 在桌面错误卡片中暴露 raw CLI 启动详情，使 Windows 失败可诊断
- 恢复 Windows 自定义标题栏控件

---

## [v0.1.0] — 初始发布

### 说明
- 允许桌面发布在无平台签名基础设施的情况下发布
- 移除 GitHub Actions 中的 Apple 证书导入和更新签名
- 强制发布构建禁用更新器构件

---

## 后续工作

### [v0.2.0 之后] (当前分支 main)

- chore: bump version to 0.1.31 and sync Claude config to repo
- refactor: 优化构建流程（并行构建 + 超时保护）
- chore: bump version to 0.1.22 and add WiX Chinese language support
- chore: add fixtures, bundled agents, and deploy module
- fix: close window exits app instead of staying in system tray, plus P0 perf fixes
- refactor: extract shared IM helpers and optimize adapter efficiency
- fix: add missing responseTimeoutId to test mocks
- docs: update v0.1.8 release notes with 5 code review optimizations
- refactor: apply 5 code review optimizations from fork comparison
- docs: add architecture docs and auto-generate project structure

---

## 维护说明

### 更新 Changelog

每次发布新版时，在版本标签之间执行：

```bash
# 查看两个版本之间的提交
git log v0.x.x..v0.y.y --oneline --no-merges

# 按类型归类
# feat: → ### 新增
# fix:  → ### 修复
# refactor: → ### 重构
# docs: → ### 文档
# chore: → ### 其他
```

### 版本标签

| 标签 | 说明 |
|------|------|
| `v0.1.0` - `v0.1.9` | 0.1.x 系列迭代 |
| `v0.2.0` | 质量门禁里程碑 |
