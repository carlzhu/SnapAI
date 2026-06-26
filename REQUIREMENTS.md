# SnapAI - 菜单栏 AI 快捷助手

> 版本：1.0 | 最后更新：2026-06-24

## 项目概述

基于 [mac-status](https://github.com/AF-lmf/mac-status) 二次开发的 macOS 菜单栏 AI 工具集。复用其菜单栏图标、弹窗窗口、设置窗口等基础设施，替换内容为 AI 任务处理。

## 核心定位

菜单栏常驻的 AI 快捷工具集。点击菜单栏图标弹出面板（或切换到浮窗模式），选择任务类别，输入文本，调用云端 AI 处理，直接在面板内显示结果并一键复制。

**目标**：消灭"为了一次翻译/润色打开整个 AI 网页"的流程。

## 当前功能状态

### ✅ 已实现

#### 1. 菜单栏 Popover 模式
- 点击菜单栏图标弹出 NSPopover 面板
- 右键菜单：偏好设置、退出
- 底部"浮窗"按钮切换到独立窗口模式

#### 2. 浮窗模式
- 独立 FloatingWindow（NSWindow 子类），始终置顶
- 初始大小 420×600，支持拖拽缩放
- 输入框使用 NSTextView 包装，支持 ⌘V 粘贴等所有键盘快捷键
- 输出区域动态跟随窗口大小调整
- 窗口位置和大小自动记忆

#### 3. 类别系统
- **内置 7 个类别**：常规、翻译、润色、改写、总结、代码、纠错
- 前 3 个固定显示（常规、翻译、润色）
- 下拉菜单选择其余类别，选中后自动占据第 4 个位置
- 支持自定义类别（设置中添加/删除）
- 类别切换时整个按钮区域可点击（contentShape 修复）

#### 4. AI 服务
- 支持 4 个 Provider：DashScope、OpenAI、DeepSeek、Ollama
- OpenAI Compatible API 格式，流式输出
- 首次启动自动读取 `QWEN_API_KEY` 环境变量
- 设置中可随时切换 Provider、修改端点/模型/API Key
- API Key 输入支持明文/密文切换 + 粘贴
- 每次修改自动保存，显示"✓ 已保存"提示
- 底部状态栏显示当前 Provider + 模型名称

#### 5. 翻译学习模式（浮窗专属）
- 翻译类别下，标题栏显示 📖 `book.pages` 按钮（展开时变蓝色）
- 点击后右侧滑入学习面板（内嵌，非独立窗口）
- **一次 API 请求**同时完成翻译 + 学习分析（用分隔符拆分）
  - 左侧：标准翻译结果（纯文本）
  - 右侧：断句分析（Markdown 渲染）
- 学习面板内容：逐句拆分（原文 → 译文 → 怎么译的）
- 切换离开翻译类别时自动收起学习面板
- 窗口宽度自动扩展（420px → 840px），带滑入动画

#### 6. Markdown 渲染
- 引入 `swift-markdown-ui` 库
- 自定义 `Theme.snapAI` 主题，深色/浅色模式自适应
- H1/H2 标题带底部分隔线、代码块圆角半透明背景、引用块左侧蓝色竖线
- 所有文字颜色使用 `.primary`，跟随系统主题

#### 7. 历史记录
- 自动保存每次执行结果（类别、输入、输出、时间）
- 最近 100 条
- 支持清空

#### 8. 设置窗口
- AI 服务配置（Provider、端点、API Key、模型）
- 自定义类别管理（添加/删除）
- 历史记录管理
- 关于信息

### ⏳ 待实现

- 全局快捷键呼出（选中文本自动填入）
- 自动从剪贴板填充输入（用户选择关闭了此功能）
- 离线模式（本地 Ollama 完整支持）
- 模板导入导出
- 结果自动回填剪贴板

## 项目结构

```
SnapAI/
├── Package.swift                          # SPM 配置 + MarkdownUI 依赖
├── Sources/SnapAI/
│   ├── App/
│   │   ├── main.swift                     # 入口，纯菜单栏应用
│   │   └── AppDelegate.swift              # 应用生命周期 + 自监控
│   ├── Models/
│   │   ├── AIConfig.swift                 # AI Provider 枚举 + 配置
│   │   ├── Category.swift                 # 任务类别模型 + 内置类别
│   │   └── HistoryItem.swift              # 历史记录模型
│   ├── Services/
│   │   └── AIService.swift                # AI 流式调用（OpenAI Compatible）
│   ├── Storage/
│   │   ├── CategoryStore.swift            # 类别持久化（UserDefaults）
│   │   └── HistoryStore.swift             # 历史记录持久化（UserDefaults）
│   ├── UI/
│   │   ├── StatusBarManager.swift         # 菜单栏图标管理
│   │   ├── PopoverManager.swift           # Popover 弹窗管理
│   │   ├── FloatingWindowManager.swift    # 浮窗 + 学习面板 + NativeTextEditor + Markdown 主题
│   │   └── Views/
│   │       ├── AITaskView.swift           # Popover 主视图
│   │       └── SettingsView.swift         # 设置窗口
│   └── Utils/
│       └── NSColor+Hex.swift              # 颜色转换工具
└── Tests/
```

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI + AppKit（NSHostingController） |
| 最低系统 | macOS 14+ (Sonoma) |
| 构建 | Swift Package Manager |
| 依赖 | swift-markdown-ui 2.4.1（Markdown 渲染） |
| 复用来源 | mac-status（菜单栏、Popover、设置窗口框架） |

## AI 服务配置

### 支持的 Provider

| Provider | 默认端点 | 默认模型 |
|----------|----------|----------|
| DashScope | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen3.7-max |
| OpenAI | https://api.openai.com/v1 | gpt-4o-mini |
| DeepSeek | https://api.deepseek.com | deepseek-v4-flash |
| Ollama | http://localhost:11434/v1 | qwen2.5:7b |

### 环境变量
- `QWEN_API_KEY` — 首次启动时自动读取，配置 DashScope API Key

## 预置类别与 Prompt

| 类别 | 图标 | System Prompt |
|------|------|---------------|
| 常规 | bubble.left | 你是一个有帮助的AI助手，请准确回答用户的问题。 |
| 翻译 | globe | 你是专业翻译。自动检测输入语言，中文译为英文，其他语言译为中文。保持原文格式，只输出翻译结果。 |
| 润色 | wand.and.stars | 请优化以下文本的表达，使其更流畅自然，不改变原意。只输出优化后的文本。 |
| 改写 | arrow.triangle.2.circlepath | 请用不同的表达方式重写以下内容，保持意思一致。只输出改写后的文本。 |
| 总结 | doc.text | 请用3-5句话总结以下内容的核心要点。 |
| 代码 | chevron.left.forwardslash.chevron.right | 请为以下代码添加中文注释并简要解释其功能。 |
| 纠错 | checkmark.circle | 请检查以下文本的语法和拼写错误，给出修正建议和修正后的文本。 |

### 翻译学习模式 Prompt（追加在翻译 Prompt 之后）

```
翻译完成后，输出一行 "---SNAP_LEARN---"，然后输出断句分析：

按句子拆分原文，每句格式：
- **原文：** 原始句子
- **译文：** 对应翻译
- **怎么译的：** 一句话说清楚为什么这样翻译，关键选择是什么

极简，不要废话，不要额外章节。
```

## UI 布局

### Popover 模式
```
┌─────────────────────────────────────┐
│ [常规] [翻译] [润色] [⋯▾]          │  ← 类别标签栏
├─────────────────────────────────────┤
│ 输入                                │
│ ┌─────────────────────────────────┐ │
│ │ (TextEditor)         [清空]     │ │
│ └─────────────────────────────────┘ │
│ [▶ 执行]                            │
│ 输出                                │
│ ┌─────────────────────────────────┐ │
│ │ (纯文本输出)           [复制]    │ │
│ └─────────────────────────────────┘ │
│ Provider(Model)      [🕐历史] [📌浮窗]│
└─────────────────────────────────────┘
```

### 浮窗模式
```
┌─ SnapAI ────────────────────────────┐
│ [常规] [翻译] [润色] [⋯▾]          │
├─────────────────────────────────────┤
│ 输入                    [清空]      │
│ ┌─────────────────────────────────┐ │
│ │ (NSTextView)                    │ │
│ └─────────────────────────────────┘ │
│ [▶ 执行]                            │
│ 输出                    [复制]      │
│ ┌─────────────────────────────────┐ │
│ │ (纯文本，动态高度)               │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│ Provider(Model)            [🕐历史] │
└─────────────────────────────────────┘
```

### 浮窗 + 学习面板（翻译类别下）
```
┌─ SnapAI ──────────┬─ 📖 学习详情 ───┐
│ [常规] [翻译] [润色]│                  │
├──────────────────┼──────────────────┤
│ 输入              │ 📝 逐句拆分      │
│ ┌──────────────┐ │ - **原文：** ... │
│ │ NSTextView   │ │ - **译文：** ... │
│ └──────────────┘ │ - **怎么译的：** │
│ [▶ 执行]         │   一句话说明     │
│ 输出              │                  │
│ ┌──────────────┐ │ ...              │
│ │ 纯文本翻译    │ │                  │
│ └──────────────┘ │                  │
│ DashScope(...)   │                  │
└──────────────────┴──────────────────┘
         420px              420px
```

## 安装

```bash
# 构建 release
cd /Users/x/Documents/dev/code/ai-suit/SnapAI
swift build -c release

# 安装到 Applications
cp .build/release/SnapAI /Applications/SnapAI.app/Contents/MacOS/SnapAI
codesign -f -s - /Applications/SnapAI.app
xattr -dr com.apple.quarantine /Applications/SnapAI.app
open /Applications/SnapAI.app
```

## 已知问题与注意事项

1. **浮窗大小记忆** — `setFrameAutosaveName` 会保存窗口大小，如果之前拖小过，需要清除 `defaults delete SnapAI "NSWindow Frame SnapAIFloatingWindow"`
2. **NSTextView** — 浮窗输入框使用 NSTextView 包装以支持 ⌘V 等键盘快捷键
3. **Markdown 渲染** — 仅在浮窗学习面板使用，主输出区为纯文本
4. **一次请求** — 翻译学习模式用 `---SNAP_LEARN---` 分隔符将翻译和学习分析合并在一次 API 请求中
