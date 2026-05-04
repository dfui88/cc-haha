---
name: document-skills
description: 关于skills的文档和系统说明，帮助理解skill系统如何工作。关键词：skill文档、skill系统、SKILL.md、frontmatter、trigger rules、skill-rules.json、skill开发
---

# Skill 系统文档

## 结构
```
.claude/
├── skills/
│   ├── skill-rules.json    # 主配置文件
│   ├── {skill-name}/
│   │   └── SKILL.md        # skill 内容
│   └── README.md
└── hooks/
    ├── skill-activation-prompt.ts  # 触发钩子
    └── skill-verification-guard.ts # 拦截钩子
```

## SKILL.md 格式
```markdown
---
name: skill-name
description: 描述 + 触发关键词
---

# 标题

## 内容
...
```

## skill-rules.json 结构
- `skills.{name}` — skill 定义
- `type` — domain / guardrail
- `enforcement` — suggest / block / warn
- `priority` — critical / high / medium / low
- `promptTriggers` — 关键词和意图模式
- `fileTriggers` — 文件路径和内容匹配

## 触发机制
- **UserPromptSubmit**: 用户输入时，匹配关键词和意图
- **PreToolUse**: 编辑文件时，匹配文件路径和内容
