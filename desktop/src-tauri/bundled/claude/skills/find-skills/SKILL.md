---
name: find-skills
description: 在 Claude Code 中查找和发现可用的 skills。关键词：find skill、search skill、list skill、discover skill、skill查找、可用skill
---

# 查找 Skills

## 查看所有可用 skills
skills 列表中会显示所有可用的 skill。

## 关键词搜索
直接提你需要做的事，相关的 skill 会自动提示。

## Skill 类型

| 类型 | 说明 |
|------|------|
| `suggest` | 主动建议，不强制 |
| `block` | 阻止操作，需先使用 skill |
| `warn` | 警告提示 |

## Skill 状态说明
- 已注册：在 skill-rules.json 中有配置
- 已激活：满足触发条件时自动提醒
- 已使用：本会话中已调用过
