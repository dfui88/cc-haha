---
name: ui-ux-pro-max
description: "UI/UX 设计智能。67种风格、96个调色板、57种字体搭配、25种图表、13个技术栈。功能：设计、构建、审查、优化 UI/UX。风格：玻璃拟态、极简、暗黑模式等。集成 shadcn/ui MCP。"
---
# UI/UX Pro Max - 设计智能

Web 和移动应用综合设计指南。包含 67 种风格、96 个调色板、57 种字体搭配、99 条 UX 指南和 25 种图表类型，覆盖 13 个技术栈。基于优先级的可搜索推荐数据库。

## 何时使用

在以下场景参考这些指南：
- 设计新的 UI 组件或页面
- 选择调色板和字体
- 审查代码中的 UX 问题
- 构建落地页或仪表盘
- 实现无障碍需求

## 按优先级分类的规则

| 优先级 | 类别 | 影响 | 领域 |
|----------|----------|--------|--------|
| 1 | 无障碍 | 关键 | `ux` |
| 2 | 触摸与交互 | 关键 | `ux` |
| 3 | 性能 | 高 | `ux` |
| 4 | 布局与响应式 | 高 | `ux` |
| 5 | 排版与色彩 | 中 | `typography`, `color` |
| 6 | 动画 | 中 | `ux` |
| 7 | 风格选择 | 中 | `style`, `product` |
| 8 | 图表与数据 | 低 | `chart` |

## 快速参考

### 1. 无障碍（关键）

- `color-contrast` - 普通文本至少 4.5:1 对比度
- `focus-states` - 交互元素可见焦点环
- `alt-text` - 有意义图片的描述性 alt 文本
- `aria-labels` - 纯图标按钮使用 aria-label
- `keyboard-nav` - Tab 顺序与视觉顺序一致
- `form-labels` - 使用带 for 属性的 label

### 2. 触摸与交互（关键）

- `touch-target-size` - 触摸目标最小 44x44px
- `hover-vs-tap` - 主要交互使用点击/触摸
- `loading-buttons` - 异步操作时禁用按钮
- `error-feedback` - 在问题附近显示清晰错误
- `cursor-pointer` - 可点击元素添加 cursor-pointer

### 3. 性能（高）

- `image-optimization` - 使用 WebP、srcset、懒加载
- `reduced-motion` - 检查 prefers-reduced-motion
- `content-jumping` - 为异步内容预留空间

### 4. 布局与响应式（高）

- `viewport-meta` - width=device-width initial-scale=1
- `readable-font-size` - 移动端正文最小 16px
- `horizontal-scroll` - 内容不超出视口宽度
- `z-index-management` - 定义 z-index 层级 (10, 20, 30, 50)

### 5. 排版与色彩（中）

- `line-height` - 正文字号使用 1.5-1.75 行高
- `line-length` - 每行限制 65-75 字符
- `font-pairing` - 标题/正文字体风格匹配

### 6. 动画（中）

- `duration-timing` - 微交互使用 150-300ms
- `transform-performance` - 使用 transform/opacity，不用 width/height
- `loading-states` - 骨架屏或加载动画

### 7. 风格选择（中）

- `style-match` - 风格匹配产品类型
- `consistency` - 所有页面风格一致
- `no-emoji-icons` - 使用 SVG 图标，不用 emoji

### 8. 图表与数据（低）

- `chart-type` - 图表类型匹配数据类型
- `color-guidance` - 使用无障碍调色板
- `data-table` - 提供表格便于无障碍访问

## 使用方法

使用下面的 CLI 工具搜索特定领域。

---


## 前置条件

检查 Python 是否已安装：

```bash
python3 --version || python --version
```

如果未安装 Python，根据系统安装：

**macOS:**
```bash
brew install python3
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install python3
```

**Windows:**
```powershell
winget install Python.Python.3.12
```

---

## 如何使用本技能

当用户请求 UI/UX 工作时（设计、构建、创建、实现、审查、修复、改进），按以下工作流程执行：

### 第 1 步：分析用户需求

从用户请求中提取关键信息：
- **产品类型**：SaaS、电商、作品集、仪表盘、落地页等
- **风格关键词**：极简、活泼、专业、优雅、暗黑模式等
- **行业**：医疗、金融科技、游戏、教育等
- **技术栈**：React、Vue、Next.js，默认使用 `html-tailwind`

### 第 2 步：生成本地系统（必需）

**始终以 `--design-system` 开头**，获取带理由的全面推荐：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<产品类型> <行业> <关键词>" --design-system [-p "项目名称"]
```

该命令：
1. 并行搜索 5 个领域（产品、风格、色彩、落地页、排版）
2. 应用来自 `ui-reasoning.csv` 的推理规则以选择最佳匹配
3. 返回完整设计系统：模式、风格、色彩、排版、效果
4. 包含需避免的反模式

**示例：**
```bash
python3 skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness service" --design-system -p "Serenity Spa"
```

### 第 2b 步：持久化设计系统（主文件 + 覆盖模式）

要跨会话保存设计系统以便分层检索，添加 `--persist`：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<查询>" --design-system --persist -p "项目名称"
```

这将创建：
- `design-system/MASTER.md` — 全局设计规则真理源
- `design-system/pages/` — 页面级覆盖文件夹

**带页面级覆盖：**
```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<查询>" --design-system --persist -p "项目名称" --page "dashboard"
```

额外创建：
- `design-system/pages/dashboard.md` — 页面级与主文件的偏差

**分层检索工作原理：**
1. 构建特定页面时（如"结算页"），先检查 `design-system/pages/checkout.md`
2. 如果页面文件存在，其规则**覆盖**主文件
3. 如果不存在，则仅使用 `design-system/MASTER.md`

### 第 3 步：补充详细搜索（按需）

获得设计系统后，使用领域搜索获取额外细节：

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<关键词>" --domain <领域> [-n <最大结果数>]
```

**何时使用详细搜索：**

| 需要 | 领域 | 示例 |
|------|--------|---------|
| 更多风格选项 | `style` | `--domain style "glassmorphism dark"` |
| 图表推荐 | `chart` | `--domain chart "real-time dashboard"` |
| UX 最佳实践 | `ux` | `--domain ux "animation accessibility"` |
| 替代字体 | `typography` | `--domain typography "elegant luxury"` |
| 落地页结构 | `landing` | `--domain landing "hero social-proof"` |

### 第 4 步：技术栈指南（默认：html-tailwind）

获取特定技术栈的最佳实践。如果用户未指定技术栈，**默认使用 `html-tailwind`**。

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "<关键词>" --stack html-tailwind
```

可用技术栈：`html-tailwind`、`react`、`nextjs`、`vue`、`svelte`、`swiftui`、`react-native`、`flutter`、`shadcn`、`jetpack-compose`

---

## 搜索参考

### 可用领域

| 领域 | 用途 | 示例关键词 |
|--------|---------|------------------|
| `product` | 产品类型推荐 | SaaS、电商、作品集、医疗、美容、服务 |
| `style` | UI 风格、色彩、效果 | 玻璃拟态、极简主义、暗黑模式、粗野主义 |
| `typography` | 字体搭配、Google Fonts | 优雅、活泼、专业、现代 |
| `color` | 按产品类型的调色板 | saas、电商、医疗、美容、金融科技、服务 |
| `landing` | 页面结构、CTA 策略 | 首屏、首屏聚焦、推荐、定价、社交证明 |
| `chart` | 图表类型、库推荐 | 趋势、对比、时间线、漏斗、饼图 |
| `ux` | 最佳实践、反模式 | 动画、无障碍、z-index、加载 |
| `react` | React/Next.js 性能 | 瀑布流、打包、Suspense、memo、重渲染、缓存 |
| `web` | Web 界面指南 | aria、焦点、键盘、语义化、虚拟化 |
| `prompt` | AI 提示词、CSS 关键词 | （风格名称） |

### 可用技术栈

| 技术栈 | 重点 |
|-------|-------|
| `html-tailwind` | Tailwind 工具类、响应式、无障碍（默认） |
| `react` | 状态、hooks、性能、模式 |
| `nextjs` | SSR、路由、图片、API 路由 |
| `vue` | Composition API、Pinia、Vue Router |
| `svelte` | Runes、stores、SvelteKit |
| `swiftui` | 视图、状态、导航、动画 |
| `react-native` | 组件、导航、列表 |
| `flutter` | 微件、状态、布局、主题 |
| `shadcn` | shadcn/ui 组件、主题、表单、模式 |
| `jetpack-compose` | Composable、Modifier、状态提升、重组 |

---

## 示例工作流

**用户请求：** "为专业护肤服务制作落地页"

### 第 1 步：分析需求
- 产品类型：美容/水疗服务
- 风格关键词：优雅、专业、柔和
- 行业：美容/健康
- 技术栈：html-tailwind（默认）

### 第 2 步：生成本地系统（必需）

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness service elegant" --design-system -p "Serenity Spa"
```

**输出：** 完整设计系统，包含模式、风格、色彩、排版、效果和反模式。

### 第 3 步：补充详细搜索（按需）

```bash
# 获取动画和无障碍的 UX 指南
python3 skills/ui-ux-pro-max/scripts/search.py "animation accessibility" --domain ux

# 获取备选排版方案
python3 skills/ui-ux-pro-max/scripts/search.py "elegant luxury serif" --domain typography
```

### 第 4 步：技术栈指南

```bash
python3 skills/ui-ux-pro-max/scripts/search.py "layout responsive form" --stack html-tailwind
```

**然后：** 综合设计系统 + 详细搜索，实现设计。

---

## 输出格式

`--design-system` 标志支持两种输出格式：

```bash
# ASCII 框（默认）- 适合终端显示
python3 skills/ui-ux-pro-max/scripts/search.py "fintech crypto" --design-system

# Markdown - 适合文档
python3 skills/ui-ux-pro-max/scripts/search.py "fintech crypto" --design-system -f markdown
```

---

## 获得更好结果的技巧

1. **关键词要具体** - "医疗 SaaS 仪表盘" 优于 "应用"
2. **多次搜索** - 不同关键词揭示不同洞察
3. **组合领域** - 风格 + 排版 + 色彩 = 完整设计系统
4. **始终检查 UX** - 搜索 "animation"、"z-index"、"accessibility" 以发现常见问题
5. **使用技术栈标志** - 获取特定技术栈的最佳实践
6. **迭代** - 如果首次搜索不匹配，尝试不同关键词

---

## 专业 UI 通用规则

以下是常被忽略、导致 UI 显不专业的问题：

### 图标与视觉元素

| 规则 | 正确做法 | 错误做法 |
|------|----|----- |
| **不使用 emoji 图标** | 使用 SVG 图标（Heroicons、Lucide、Simple Icons） | 使用 🎨 🚀 ⚙️ 等 emoji 作为 UI 图标 |
| **稳定的悬停状态** | 悬停时使用颜色/透明度过渡 | 使用导致布局移位的缩放变换 |
| **正确的品牌标志** | 从 Simple Icons 查找官方 SVG | 猜测或使用错误标志路径 |
| **一致的图标尺寸** | 使用固定 viewBox（24x24）配合 w-6 h-6 | 随机混用不同图标尺寸 |

### 交互与光标

| 规则 | 正确做法 | 错误做法 |
|------|----|----- |
| **光标指针** | 所有可点击/可悬停卡片添加 `cursor-pointer` | 交互元素保留默认光标 |
| **悬停反馈** | 提供视觉反馈（颜色、阴影、边框） | 无任何交互元素指示 |
| **平滑过渡** | 使用 `transition-colors duration-200` | 状态突变或过渡太慢（>500ms） |

### 亮色/暗黑模式对比度

| 规则 | 正确做法 | 错误做法 |
|------|----|----- |
| **亮色模式玻璃卡片** | 使用 `bg-white/80` 或更高透明度 | 使用 `bg-white/10`（太透明） |
| **亮色模式文字对比** | 文字使用 `#0F172A`（slate-900） | 正文使用 `#94A3B8`（slate-400） |
| **亮色模式弱化文字** | 最低使用 `#475569`（slate-600） | 使用 gray-400 或更浅 |
| **边框可见性** | 亮色模式使用 `border-gray-200` | 使用 `border-white/10`（不可见） |

### 布局与间距

| 规则 | 正确做法 | 错误做法 |
|------|----|----- |
| **浮动导航栏** | 添加 `top-4 left-4 right-4` 间距 | 导航栏紧贴 `top-0 left-0 right-0` |
| **内容内边距** | 为固定导航栏高度留出空间 | 内容隐藏在固定元素后 |
| **一致的最大宽度** | 统一使用 `max-w-6xl` 或 `max-w-7xl` | 混用不同容器宽度 |

---

## 交付前检查清单

在交付 UI 代码前，验证以下项目：

### 视觉质量
- [ ] 不使用 emoji 作为图标（改用 SVG）
- [ ] 所有图标来自一致图标集（Heroicons/Lucide）
- [ ] 品牌标志正确（已从 Simple Icons 验证）
- [ ] 悬停状态不导致布局移位
- [ ] 直接使用主题色（bg-primary）而非 var() 包装

### 交互
- [ ] 所有可点击元素有 `cursor-pointer`
- [ ] 悬停状态提供清晰视觉反馈
- [ ] 过渡平滑（150-300ms）
- [ ] 焦点状态对键盘导航可见

### 亮色/暗黑模式
- [ ] 亮色模式文字有足够对比度（最低 4.5:1）
- [ ] 玻璃/透明元素在亮色模式下可见
- [ ] 边框在两种模式下均可见
- [ ] 交付前测试两种模式

### 布局
- [ ] 浮动元素与边缘有适当间距
- [ ] 无内容隐藏在固定导航栏后
- [ ] 在 375px、768px、1024px、1440px 下响应式
- [ ] 移动端无水平滚动

### 无障碍
- [ ] 所有图片有 alt 文本
- [ ] 表单输入有标签
- [ ] 颜色不是唯一指示符
- [ ] 尊重 `prefers-reduced-motion`
